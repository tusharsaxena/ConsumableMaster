-- SlashCommands.lua — /cm (and /consumablemaster) dispatcher.
--
-- Two ordered tables drive the slash UX:
--   * COMMANDS — top-level subcommands. Each row is {name, description, fn}.
--     The dispatcher prints the help index when invoked bare, looks up by
--     name, and re-prints help on an unknown name. Help text is generated
--     from the same table, so adding a command = adding a single row.
--   * the `/cm dump <target>` namespace lives in core/SlashDump.lua (CM-54).
--
-- /cm list / get / set are schema-driven via KCM.Settings.Helpers (see
-- settings/Panel.lua). /cm priority|stat|aio are dedicated verb namespaces
-- for the list-shaped state that doesn't fit a flat scalar schema.
--
-- KickCD's slash handler (core/KickCD.lua) is the design reference.

local _, NS = ...
local KCM = NS
KCM.SlashCommands = {}

local L = KCM.L

-- Every chat line we emit goes through the shared secret-safe seam (KCM.Say,
-- core/Constants.lua) so the [CM] tag is unconditional and a combat "secret"
-- can never raise mid-line — including dump body rows and help-table rows that
-- don't manually prepend the tag.
local say = KCM.Say


-- Shared confirmation popup for /cm resetall. preferredIndex = 3 dodges the
-- taint cascade that affects popup slots 1/2 when other addons have used
-- them earlier in the session (a well-known Ace3 footgun around any
-- StaticPopup that mutates SavedVariables).
--
-- It hangs off the global StaticPopupDialogs at file scope and is reached by
-- name through StaticPopup_Show, so which VERB raises it is the only thing
-- that ever moved: `/cm reset` used to, `/cm resetall` does now (LIBKA0S-12, issue #27).
-- The dialog, its wording and its body are untouched by that swap — the
-- destructive path keeps the confirmation it has always had.
StaticPopupDialogs["KCM_CONFIRM_RESET"] = {
    -- Same wording as the Options panel's KCM_RESET_ALL so both global-reset
    -- entry points describe identical scope (they share KCM.ResetAllToDefaults).
    -- THE COLLECTION'S ONE WORDING (options-ui-§12), verbatim, and the same string
    -- settings/General.lua's popup carries -- one act, one wording, whichever door
    -- the player came through.
    text = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if KCM.ResetAllToDefaults and KCM.ResetAllToDefaults("slash_resetall") then
            say("Reset complete — defaults restored.")
        else
            say("Reset failed (DB not ready).")
        end
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ---------------------------------------------------------------------------
-- Common parser / dispatcher helpers
-- ---------------------------------------------------------------------------

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function tokenize(s)
    local out = {}
    for w in (s or ""):gmatch("%S+") do out[#out + 1] = w end
    return out
end

local function lowerFirst(rest)
    local first, remainder = (rest or ""):match("^(%S*)%s*(.*)$")
    return (first or ""):lower(), remainder or ""
end

local function findCommand(list, name)
    for _, entry in ipairs(list) do
        if entry[1] == name then return entry end
    end
end

-- Every panel mutation funnels through here: request a pipeline recompute so
-- the macro bodies catch up, then redraw the open panel. Mirrors the
-- afterMutation helpers in settings/General.lua / StatPriority.lua /
-- Category.lua so a CLI mutation looks identical to a panel-driven one
-- downstream.
local function afterMutation(reason)
    if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute(reason or "slash_mutation")
    end
    if KCM.Options and KCM.Options.Refresh then
        KCM.Options.Refresh()
    end
end

-- ---------------------------------------------------------------------------
-- Spec-key resolution (for /cm stat)
-- ---------------------------------------------------------------------------
--
-- Accepts:
--   * "<classID>_<specID>" — canonical key matching db.profile.statPriority.
--   * "CLASS:SPEC"         — friendly form, e.g. SHAMAN:ENHANCEMENT.
--                            Class token matches UnitClass()'s file token
--                            (uppercase, no whitespace). Spec token matches
--                            the spec name with whitespace stripped and
--                            uppercased (BEASTMASTERY for "Beast Mastery").
--   * nil / empty          — falls back to the player's current spec.

local CLASS_FILES = {
    [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE",
    [5] = "PRIEST",  [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE",
    [9] = "WARLOCK", [10] = "MONK", [11] = "DRUID", [12] = "DEMONHUNTER",
    [13] = "EVOKER",
}

local function normSpecToken(s)
    if not s then return nil end
    return (s:gsub("%s+", "")):upper()
end

local function classIDFromFile(token)
    if not token then return nil end
    local up = token:upper()
    for id, file in pairs(CLASS_FILES) do
        if file == up then return id end
    end
    return nil
end

local function specIDFromToken(classID, specToken)
    if not (classID and specToken and KCM.Compat.GetNumSpecializationsForClassID
            and KCM.Compat.GetSpecializationInfoForClassID) then
        return nil
    end
    local want = normSpecToken(specToken)
    for i = 1, (KCM.Compat.GetNumSpecializationsForClassID(classID) or 0) do
        local sid, name = KCM.Compat.GetSpecializationInfoForClassID(classID, i)
        if sid and normSpecToken(name) == want then return sid end
    end
    return nil
end

local function resolveSpecKey(token)
    if not token or token == "" then
        if KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
            local _, _, key = KCM.SpecHelper.GetCurrent()
            return key
        end
        return nil
    end
    -- canonical "<classID>_<specID>" form
    if token:match("^%d+_%d+$") then return token end
    -- friendly "CLASS:SPEC" form
    local cls, spc = token:match("^([^:]+):([^:]+)$")
    if cls and spc then
        local classID = classIDFromFile(cls)
        local specID  = specIDFromToken(classID, spc)
        if classID and specID and KCM.SpecHelper and KCM.SpecHelper.MakeKey then
            return KCM.SpecHelper.MakeKey(classID, specID)
        end
    end
    return nil
end

-- Pretty spec label for output: "Shaman — Enhancement (7_263)".
local function describeSpec(specKey)
    if not specKey then return "(no spec)" end
    local classID, specID = specKey:match("^(%d+)_(%d+)$")
    classID, specID = tonumber(classID), tonumber(specID)
    local className = (classID and GetClassInfo and GetClassInfo(classID)) or tostring(classID)
    local specName
    if classID and specID and KCM.Compat.GetNumSpecializationsForClassID and KCM.Compat.GetSpecializationInfoForClassID then
        for i = 1, (KCM.Compat.GetNumSpecializationsForClassID(classID) or 0) do
            local sid, name = KCM.Compat.GetSpecializationInfoForClassID(classID, i)
            if sid == specID then specName = name; break end
        end
    end
    return ("%s — %s (%s)"):format(className, specName or tostring(specID), specKey)
end

-- ---------------------------------------------------------------------------
-- ID parsing for /cm priority
-- ---------------------------------------------------------------------------
-- Accepts:
--   * "12345"        — itemID
--   * "s:5512"       — spell sentinel (composed via KCM.ID.AsSpell)
-- Returns the stored opaque ID (positive itemID or negative spell sentinel)
-- or nil if unparseable.

local function parsePriorityID(token)
    if not token then return nil end
    local sid = token:match("^s:(%d+)$") or token:match("^S:(%d+)$")
    if sid then
        local n = tonumber(sid)
        if not n then return nil end
        return KCM.ID and KCM.ID.AsSpell and KCM.ID.AsSpell(n) or -n
    end
    return tonumber(token)
end

local function nameForStoredID(id)
    if not id then return "?" end
    if KCM.ID and KCM.ID.IsSpell(id) then
        local sid = KCM.ID.SpellID(id)
        if C_Spell and C_Spell.GetSpellName then
            return C_Spell.GetSpellName(sid) or "?"
        end
        return "?"
    end
    if KCM.TooltipCache and KCM.TooltipCache.Get then
        local tt = KCM.TooltipCache.Get(id)
        if tt and tt.itemName then return tt.itemName end
    end
    if C_Item and C_Item.GetItemNameByID then
        return C_Item.GetItemNameByID(id) or "?"
    end
    return "?"
end

local function displayID(id)
    if not id then return "?" end
    if KCM.ID and KCM.ID.IsSpell(id) then
        return ("s:%d"):format(KCM.ID.SpellID(id) or 0)
    end
    return tostring(id)
end



-- Shared, type-aware, unit-annotated value formatter (slash-commands-§5). The
-- single source of truth for both `/cm list` rows and the `get`/`set` echo, so
-- the two paths can never diverge.
function KCM.FormatSchemaValue(def, v)
    if v == nil then return "nil" end
    if def.type == "color" and type(v) == "table" then
        return ("{%.2f, %.2f, %.2f, %.2f}")
            :format(v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 1)
    end
    if def.type == "number" and def.fmt then
        return def.fmt:format(v)
    end
    return tostring(v)
end
-- KCM.FormatSchemaValue above stays a published export — tests/test_schema.lua
-- pins it by name, and it is the addon's own renderer for anywhere outside the
-- CLI. What went with the CLI are its private companions: the key=value
-- formatter, the dropdown allowed-list reader and its message builder. All
-- three are LibKa0s-Slash-1.0's now, and the library reads the addon's ordered
-- {value=, text=} enum shape natively rather than needing a translation here.

-- The schema CLI is LibKa0s-Slash-1.0's. Forward-declared and bound at the
-- bottom of this file, where the instance is built: COMMANDS is declared above
-- that point and its handlers close over these names.
--
-- What the library gained that made this possible is recorded as LIBKA0S-02 (issue #25) —
-- it now reads the ordered {value=, text=} enum shape this addon declares, and
-- takes a color codec so a positional { r, g, b, a } round-trips. Before that,
-- adopting it would have rendered all seven color rows as {0.00, 0.00, 0.00,
-- 1.00} and offered "1, 2" as the allowed values for a dropdown — both
-- silently, and both green.
--
-- One thing arrives free: colors may now be given as 0-255 as well as 0-1, and
-- a mixed-scale triple rescales jointly rather than per channel.


-- ---------------------------------------------------------------------------
-- /cm priority <catKey> <subverb> ...
-- ---------------------------------------------------------------------------
--
-- CLI parity for the per-category Priority list editor. Every mutation goes
-- through KCM.Selector so the panel and slash paths share one write surface;
-- afterMutation kicks Pipeline.RequestRecompute and refreshes any open panel.

local function resolveCatKey(token)
    if not token or token == "" then return nil end
    if not (KCM.Categories and KCM.Categories.Get) then return nil end
    return KCM.Categories.Get(token:upper()) and token:upper() or nil
end

local function categorySpec(cat)
    -- Spec-aware single categories operate on the player's current spec.
    -- (CLI does not currently expose a "viewed spec" override the way the
    -- panel does — keeping the surface narrow; specify per-spec ops via the
    -- panel until a use-case argues for it on the CLI.)
    if not (cat and cat.specAware) then return nil end
    if KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
        local _, _, key = KCM.SpecHelper.GetCurrent()
        return key
    end
    return nil
end

-- Does the player have this stored ID right now? Spells answer from the
-- spellbook, items from the bag scan; both arms fall back to false when the
-- client API or the scanner is missing, so a degraded load renders "not owned"
-- rather than erroring mid-list.
local function ownsID(id)
    if KCM.ID and KCM.ID.IsSpell(id) then
        return (IsPlayerSpell and KCM.ID.SpellID and IsPlayerSpell(KCM.ID.SpellID(id))) or false
    end
    return KCM.BagScanner and KCM.BagScanner.HasItem and KCM.BagScanner.HasItem(id) or false
end

-- One rendered row of the priority list. The not-owned tag pads with two
-- trailing spaces so the ID column lines up under the owned one.
local function priorityRow(i, id, pick)
    local haveTag = ownsID(id) and "|cff44ff44[owned]|r" or "|cff888888[---]  |r"
    local pickTag = (id == pick) and "  |cffffd100<-- pick|r" or ""
    return ("  %2d. %s %-12s %s%s"):format(i, haveTag, displayID(id), nameForStoredID(id), pickTag)
end

local function priorityList(cat, _rest)
    if cat.composite then
        return KCM.SlashDump.TARGETS.pick.run(cat.key:lower())
    end
    if not (KCM.Selector and KCM.Selector.GetEffectivePriority) then
        return say("Selector not loaded.")
    end
    local specKey = categorySpec(cat)
    if cat.specAware and not specKey then
        return say("spec-aware category but no active spec — try again after picking a spec.")
    end
    local priority = KCM.Selector.GetEffectivePriority(cat.key, specKey)
    local pick     = KCM.Selector.PickBestForCategory(cat.key, specKey)
    say(("%s: %d entries"):format(cat.key, #priority))
    for i, id in ipairs(priority) do
        say(priorityRow(i, id, pick))
    end
end

local function rejectComposite(cat, verb)
    if cat.composite then
        say(("%s is a composite category — use `/cm aio %s %s` instead.")
            :format(cat.key, cat.key:lower(), verb))
        return true
    end
    return false
end

local function priorityAdd(cat, rest)
    if rejectComposite(cat, "...") then return end
    local args = tokenize(rest)
    local id = parsePriorityID(args[1])
    if not id then
        return say("Usage: /cm priority <cat> add <itemID|s:spellID>")
    end
    local specKey = categorySpec(cat)
    if cat.specAware and not specKey then
        return say("spec-aware category but no active spec.")
    end
    if KCM.Selector and KCM.Selector.AddItem
       and KCM.Selector.AddItem(cat.key, id, specKey) then
        say(("added %s to %s"):format(displayID(id), cat.key))
        afterMutation("slash_priority_add")
    else
        say(("could not add %s to %s (already present, or not allowed for this cat)")
            :format(displayID(id), cat.key))
    end
end

local function priorityRemove(cat, rest)
    if rejectComposite(cat, "...") then return end
    local args = tokenize(rest)
    local id = parsePriorityID(args[1])
    if not id then
        return say("Usage: /cm priority <cat> remove <itemID|s:spellID>")
    end
    local specKey = categorySpec(cat)
    if KCM.Selector and KCM.Selector.Block
       and KCM.Selector.Block(cat.key, id, specKey) then
        say(("removed/blocked %s from %s"):format(displayID(id), cat.key))
        afterMutation("slash_priority_remove")
    else
        say(("could not remove %s from %s"):format(displayID(id), cat.key))
    end
end

local function priorityMove(cat, rest, dir)
    if rejectComposite(cat, dir) then return end
    local args = tokenize(rest)
    local id = parsePriorityID(args[1])
    if not id then
        return say(("Usage: /cm priority <cat> %s <itemID|s:spellID>"):format(dir))
    end
    local specKey = categorySpec(cat)
    local fn = (dir == "up") and (KCM.Selector and KCM.Selector.MoveUp)
                              or (KCM.Selector and KCM.Selector.MoveDown)
    if fn and fn(cat.key, id, specKey) then
        say(("%s %s in %s"):format(displayID(id), (dir == "up" and "moved up" or "moved down"), cat.key))
        afterMutation("slash_priority_" .. dir)
    else
        say(("could not move %s %s in %s (already at edge or not pinned)")
            :format(displayID(id), dir, cat.key))
    end
end

local function priorityReset(cat)
    if rejectComposite(cat, "reset") then return end
    local specKey = categorySpec(cat)
    local bucket = KCM.Selector and KCM.Selector.GetBucket
        and KCM.Selector.GetBucket(cat.key, specKey)
    if not bucket then
        return say("could not reach category bucket.")
    end
    bucket.added   = {}
    bucket.blocked = {}
    bucket.pins    = {}
    if KCM.State and KCM.State.debug then KCM.Debug("Prio", "reset %s", cat.key) end
    say(("reset %s%s — added/blocked/pins cleared (discovered items preserved).")
        :format(cat.key, cat.specAware and (" (spec " .. tostring(specKey) .. ")") or ""))
    afterMutation("slash_priority_reset")
end

local PRIORITY_COMMANDS = {
    {"list",   "Print effective priority + ownership/pick — `/cm priority <cat> list`",
        function(cat, rest) priorityList(cat, rest) end},
    {"add",    "Add an item or spell — `/cm priority <cat> add <itemID|s:spellID>`",
        function(cat, rest) priorityAdd(cat, rest) end},
    {"remove", "Block from candidate set — `/cm priority <cat> remove <itemID|s:spellID>`",
        function(cat, rest) priorityRemove(cat, rest) end},
    {"up",     "Pin higher in priority — `/cm priority <cat> up <itemID|s:spellID>`",
        function(cat, rest) priorityMove(cat, rest, "up") end},
    {"down",   "Pin lower in priority — `/cm priority <cat> down <itemID|s:spellID>`",
        function(cat, rest) priorityMove(cat, rest, "down") end},
    {"reset",  "Clear added/blocked/pins for this cat — `/cm priority <cat> reset`",
        function(cat) priorityReset(cat) end},
}

local function priorityHelp()
    say("priority subcommands")
    for _, entry in ipairs(PRIORITY_COMMANDS) do
        say(("  |cffffff00/cm priority <cat> %s|r — |cffffffff%s|r"):format(entry[1], entry[2]))
    end
    if KCM.Categories and KCM.Categories.LIST then
        local keys = {}
        for _, c in ipairs(KCM.Categories.LIST) do keys[#keys + 1] = c.key:lower() end
        say("  known cats: " .. table.concat(keys, ", "))
    end
end

local function runPriority(rest)
    local catTok, rem = lowerFirst(rest)
    if catTok == "" then return priorityHelp() end
    local catKey = resolveCatKey(catTok)
    if not catKey then
        say("unknown category '" .. catTok .. "'.")
        return priorityHelp()
    end
    local cat = KCM.Categories.Get(catKey)
    local sub, tail = lowerFirst(rem)
    if sub == "" then
        -- bare `/cm priority <cat>` defaults to list
        return priorityList(cat, "")
    end
    local entry = findCommand(PRIORITY_COMMANDS, sub)
    if entry then return entry[3](cat, tail) end
    say("unknown priority subcommand '" .. sub .. "'")
    priorityHelp()
end

-- ---------------------------------------------------------------------------
-- /cm stat <subverb> ...
-- ---------------------------------------------------------------------------

local PRIMARY_STATS = { STR = true, AGI = true, INT = true }
local SECONDARY_STATS = {
    CRIT = true, HASTE = true, MASTERY = true, VERSATILITY = true,
}

local function statList(rest)
    local args = tokenize(rest)
    local specKey = resolveSpecKey(args[1])
    if not specKey then
        return say("could not resolve spec — pass <classID>_<specID> or CLASS:SPEC")
    end
    if not (KCM.SpecHelper and KCM.SpecHelper.GetStatPriority) then
        return say("SpecHelper not loaded.")
    end
    local p = KCM.SpecHelper.GetStatPriority(specKey)
    say(("spec: %s"):format(describeSpec(specKey)))
    say(("  primary:   %s"):format(tostring(p.primary)))
    say(("  secondary: %s"):format(table.concat(p.secondary or {}, ", ")))
end

local function statPrimary(rest)
    local args = tokenize(rest)
    local stat = (args[1] or ""):upper()
    local specKey = resolveSpecKey(args[2])
    if not PRIMARY_STATS[stat] then
        return say("Usage: /cm stat primary <STR|AGI|INT> [specKey]")
    end
    if not specKey then return say("could not resolve spec.") end
    KCM.db.profile.statPriority = KCM.db.profile.statPriority or {}
    local cur = KCM.SpecHelper.GetStatPriority(specKey)
    KCM.db.profile.statPriority[specKey] = {
        primary   = stat,
        secondary = cur.secondary or {},
    }
    say(("statpriority.%s.primary = %s"):format(specKey, stat))
    afterMutation("slash_stat_primary")
end

local function statSecondary(rest)
    local args = tokenize(rest)
    if not args[1] then
        return say("Usage: /cm stat secondary <CSV> [specKey]  (e.g. CRIT,HASTE,MASTERY,VERSATILITY)")
    end
    local specKey = resolveSpecKey(args[2])
    if not specKey then return say("could not resolve spec.") end
    local list, seen, bad = {}, {}, {}
    for token in (args[1]):gmatch("[^,]+") do
        local up = trim(token):upper()
        if up == "" then
            -- skip empty CSV slots
        elseif not SECONDARY_STATS[up] then
            bad[#bad + 1] = up
        elseif not seen[up] then
            -- Dedupe: a duplicate would weight the same stat twice in
            -- Ranker.Score. First occurrence wins; later duplicates are
            -- silently dropped.
            seen[up] = true
            list[#list + 1] = up
        end
    end
    if #bad > 0 then
        return say(("Unknown secondary stat(s): %s.  Allowed: CRIT, HASTE, MASTERY, VERSATILITY")
            :format(table.concat(bad, ", ")))
    end
    KCM.db.profile.statPriority = KCM.db.profile.statPriority or {}
    local cur = KCM.SpecHelper.GetStatPriority(specKey)
    KCM.db.profile.statPriority[specKey] = {
        primary   = cur.primary or "STR",
        secondary = list,
    }
    say(("statpriority.%s.secondary = %s"):format(specKey, table.concat(list, ", ")))
    afterMutation("slash_stat_secondary")
end

local function statReset(rest)
    local args = tokenize(rest)
    local specKey = resolveSpecKey(args[1])
    if not specKey then return say("could not resolve spec.") end
    if not (KCM.db and KCM.db.profile) then return say("DB not ready.") end
    KCM.db.profile.statPriority = KCM.db.profile.statPriority or {}
    if KCM.db.profile.statPriority[specKey] == nil then
        return say(("no override for %s; nothing to reset."):format(specKey))
    end
    KCM.db.profile.statPriority[specKey] = nil
    say(("dropped stat-priority override for %s — falling back to seed/class default.")
        :format(specKey))
    afterMutation("slash_stat_reset")
end

local STAT_COMMANDS = {
    {"list",      "Print stat priority — `/cm stat list [specKey]`",
        function(rest) statList(rest) end},
    {"primary",   "Set primary stat — `/cm stat primary <STR|AGI|INT> [specKey]`",
        function(rest) statPrimary(rest) end},
    {"secondary", "Set secondary list — `/cm stat secondary <CSV> [specKey]`",
        function(rest) statSecondary(rest) end},
    {"reset",     "Drop user override — `/cm stat reset [specKey]`",
        function(rest) statReset(rest) end},
}

local function statHelp()
    say("stat subcommands")
    for _, entry in ipairs(STAT_COMMANDS) do
        say(("  |cffffff00/cm stat %s|r — |cffffffff%s|r"):format(entry[1], entry[2]))
    end
    say("  specKey: <classID>_<specID> (e.g. 7_263) or CLASS:SPEC (e.g. SHAMAN:ENHANCEMENT). Defaults to current spec.")
end

local function runStat(rest)
    local sub, tail = lowerFirst(rest)
    if sub == "" then return statHelp() end
    local entry = findCommand(STAT_COMMANDS, sub)
    if entry then return entry[3](tail) end
    say("unknown stat subcommand '" .. sub .. "'")
    statHelp()
end

-- ---------------------------------------------------------------------------
-- /cm aio <key> <subverb> ...
-- ---------------------------------------------------------------------------
--
-- CLI parity for the composite-category panel (HP_AIO, MP_AIO). State lives
-- in db.profile.categories[<key>].{ enabled, orderInCombat, orderOutOfCombat }.
-- Sub-categories are locked to their section, so the up/down handlers infer
-- the section from where the ref appears and reject refs not present in the
-- composite at all.

local AIO_SECTIONS = { "orderInCombat", "orderOutOfCombat" }
local AIO_SECTION_LABEL = {
    orderInCombat    = "In Combat",
    orderOutOfCombat = "Out of Combat",
}

local function compositeCfg(cat)
    return KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[cat.key]
end

local function findInSection(arr, ref)
    for i, v in ipairs(arr or {}) do
        if v == ref then return i end
    end
    return nil
end

-- Locate a ref across both sections of a composite. Returns
-- (sectionField, index) — first hit wins; aio components are locked to one
-- section so there's no ambiguity.
local function locateAIORef(cfg, ref)
    for _, field in ipairs(AIO_SECTIONS) do
        local idx = findInSection(cfg[field], ref)
        if idx then return field, idx end
    end
    return nil, nil
end

local function aioList(cat)
    local cfg = compositeCfg(cat)
    if not cfg then return say("no DB bucket for " .. cat.key) end
    say(("%s"):format(cat.key))
    for _, field in ipairs(AIO_SECTIONS) do
        say(("  %s"):format(AIO_SECTION_LABEL[field]))
        local arr = cfg[field] or {}
        if #arr == 0 then
            say("    (none)")
        else
            for i, ref in ipairs(arr) do
                local enabled = not (cfg.enabled and cfg.enabled[ref] == false)
                local tag = enabled and "|cff44ff44[on]|r " or "|cff888888[off]|r"
                local refCat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(ref)
                local label  = refCat and refCat.displayName or ref
                say(("    %d. %s %-10s — %s"):format(i, tag, ref, label))
            end
        end
    end
end

-- The words `toggle` accepts as an explicit value. Values are strictly
-- booleans, so a nil lookup means "no explicit value given" — never "given but
-- false" — and the flip path can key off that without a second test.
local AIO_BOOL_WORDS = {
    on = true,  ["true"]  = true,  ["1"] = true,  yes = true,
    off = false, ["false"] = false, ["0"] = false, no  = false,
}

-- Shared preamble for the ref-taking aio sub-verbs (toggle, up, down): the ref
-- token, the composite's DB bucket, and where the ref sits inside it. Says the
-- matching rejection and returns nil if any of the three is missing, so a
-- caller's whole guard is `if not cfg then return end`.
local function requireAIORef(cat, args, usage)
    local ref = args[1] and args[1]:upper() or nil
    if not ref then
        say(usage)
        return nil
    end
    local cfg = compositeCfg(cat)
    if not cfg then
        say("no DB bucket for " .. cat.key)
        return nil
    end
    local field, idx = locateAIORef(cfg, ref)
    if not field then
        say(("ref '%s' is not part of %s"):format(ref, cat.key))
        return nil
    end
    return cfg, ref, field, idx
end

local function aioToggle(cat, rest)
    local args = tokenize(rest)
    local cfg, ref = requireAIORef(cat, args, "Usage: /cm aio <key> toggle <ref> [on|off]")
    if not cfg then return end
    cfg.enabled = cfg.enabled or {}
    local newVal = AIO_BOOL_WORDS[(args[2] or ""):lower()]
    if newVal == nil then
        -- No explicit word: flip the current value. An unset ref counts as ON,
        -- matching the composite body builder's `enabled[ref] ~= false` default,
        -- so the first toggle of an untouched ref turns it off.
        local cur = cfg.enabled[ref]
        if cur == nil then cur = true end
        newVal = not cur
    end
    -- Always a real boolean — the body builder tests `~= false`, so a string or
    -- a nil here would silently re-enable the ref.
    cfg.enabled[ref] = newVal
    say(("%s.enabled.%s = %s"):format(cat.key, ref, tostring(newVal)))
    afterMutation("slash_aio_toggle")
end

local function aioMove(cat, rest, dir)
    local args = tokenize(rest)
    local cfg, ref, field, idx = requireAIORef(cat, args,
        ("Usage: /cm aio <key> %s <ref>"):format(dir))
    if not cfg then return end
    local arr = cfg[field]
    local target = (dir == "up") and (idx - 1) or (idx + 1)
    if target < 1 or target > #arr then
        return say(("'%s' already at %s edge of %s"):format(
            ref, (dir == "up" and "top" or "bottom"), AIO_SECTION_LABEL[field]))
    end
    arr[idx], arr[target] = arr[target], arr[idx]
    say(("%s.%s: %s moved %s (now position %d)")
        :format(cat.key, field, ref, dir, target))
    afterMutation("slash_aio_move_" .. dir)
end

local function aioReset(cat)
    local defaults = KCM.dbDefaults and KCM.dbDefaults.profile
        and KCM.dbDefaults.profile.categories
        and KCM.dbDefaults.profile.categories[cat.key]
    if not defaults then return say("no defaults registered for " .. cat.key) end
    local cfg = compositeCfg(cat)
    if not cfg then return say("no DB bucket for " .. cat.key) end
    cfg.enabled          = CopyTable(defaults.enabled or {})
    cfg.orderInCombat    = CopyTable(defaults.orderInCombat or {})
    cfg.orderOutOfCombat = CopyTable(defaults.orderOutOfCombat or {})
    say(("reset %s — enabled flags + section order restored."):format(cat.key))
    afterMutation("slash_aio_reset")
end

local AIO_COMMANDS = {
    {"list",   "Print configuration — `/cm aio <key> list`",
        function(cat, _rest) aioList(cat) end},
    {"toggle", "Flip enabled — `/cm aio <key> toggle <ref> [on|off]`",
        function(cat, rest) aioToggle(cat, rest) end},
    {"up",     "Move higher in section — `/cm aio <key> up <ref>`",
        function(cat, rest) aioMove(cat, rest, "up") end},
    {"down",   "Move lower in section — `/cm aio <key> down <ref>`",
        function(cat, rest) aioMove(cat, rest, "down") end},
    {"reset",  "Restore enabled + order to defaults — `/cm aio <key> reset`",
        function(cat) aioReset(cat) end},
}

local function aioHelp()
    say("aio subcommands")
    for _, entry in ipairs(AIO_COMMANDS) do
        say(("  |cffffff00/cm aio <key> %s|r — |cffffffff%s|r"):format(entry[1], entry[2]))
    end
    if KCM.Categories and KCM.Categories.LIST then
        local keys = {}
        for _, c in ipairs(KCM.Categories.LIST) do
            if c.composite then keys[#keys + 1] = c.key:lower() end
        end
        say("  known composites: " .. table.concat(keys, ", "))
    end
end

local function runAIO(rest)
    local keyTok, rem = lowerFirst(rest)
    if keyTok == "" then return aioHelp() end
    local catKey = resolveCatKey(keyTok)
    local cat = catKey and KCM.Categories.Get(catKey)
    if not (cat and cat.composite) then
        say("unknown composite category '" .. keyTok .. "'.")
        return aioHelp()
    end
    local sub, tail = lowerFirst(rem)
    if sub == "" then return aioList(cat) end
    local entry = findCommand(AIO_COMMANDS, sub)
    if entry then return entry[3](cat, tail) end
    say("unknown aio subcommand '" .. sub .. "'")
    aioHelp()
end

-- ---------------------------------------------------------------------------
-- /cm bar [on|off|lock|unlock|reset]
-- ---------------------------------------------------------------------------
--
-- CLI parity for the Macro Bar page's Bar section. Every mutation goes through
-- KCM.MacroBar so the panel and slash paths share one apply seam (which owns
-- the combat deferral); the finer-grained layout/appearance settings are
-- reachable as schema paths via `/cm set macroBar.<field>`.

local BAR_COMMANDS = {
    {"on",     "Show the macro bar",
        function() KCM.MacroBar.SetEnabled(true);  say("macro bar |cff00ff00ON|r") end},
    {"off",    "Hide the macro bar",
        function() KCM.MacroBar.SetEnabled(false); say("macro bar |cffff5555OFF|r") end},
    {"lock",   "Lock the bar in place",
        function() KCM.MacroBar.SetLocked(true);   say("macro bar locked") end},
    {"unlock", "Unlock the bar so it can be dragged",
        function() KCM.MacroBar.SetLocked(false);  say("macro bar unlocked — drag it, then /cm bar lock") end},
    {"reset",  "Move the bar back to the center of the screen",
        function() KCM.MacroBar.ResetPosition();   say("macro bar position reset") end},
}

local function barHelp()
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config() or {}
    say(("macro bar: %s, %s"):format(
        cfg.enabled and "|cff00ff00ON|r" or "|cffff5555OFF|r",
        cfg.locked  and "locked" or "unlocked"))
    for _, entry in ipairs(BAR_COMMANDS) do
        say(("  |cffffff00/cm bar %s|r — |cffffffff%s|r"):format(entry[1], entry[2]))
    end
    say("  layout / appearance: |cffffff00/cm set macroBar.<field>|r (see /cm list)")
end

local function runBar(rest)
    if not (KCM.MacroBar and KCM.MacroBarModel and KCM.MacroBarModel.Config()) then
        return say("macro bar unavailable.")
    end
    local sub = lowerFirst(rest)
    -- Bare `/cm bar` toggles, matching how `/cm debug` reads as a switch.
    if sub == "" then
        local on = not KCM.MacroBarModel.IsEnabled()
        KCM.MacroBar.SetEnabled(on)
        return say("macro bar " .. (on and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
    end
    if sub == "help" then return barHelp() end
    local entry = findCommand(BAR_COMMANDS, sub)
    if entry then return entry[3]() end
    say("unknown bar subcommand '" .. sub .. "'")
    barHelp()
end

-- ---------------------------------------------------------------------------
-- Published verb entry points
-- ---------------------------------------------------------------------------
--
-- settings/Slash.lua assembles these into the ordered COMMANDS table and hands
-- that to LibKa0s-Slash-1.0 (CM-47). They are published rather than dispatched
-- here so this file stays "what the verbs do" and never grows a second opinion
-- about how /cm is parsed.

KCM.SlashCommands.Verbs = {
    RunBar      = runBar,
    RunPriority = runPriority,
    RunStat     = runStat,
    RunAIO      = runAIO,
    Dump        = KCM.SlashDump.Dispatch,
}
