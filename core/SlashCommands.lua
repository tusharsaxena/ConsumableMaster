-- SlashCommands.lua — /cm (and /consumablemaster) dispatcher.
--
-- Two ordered tables drive the slash UX:
--   * COMMANDS — top-level subcommands. Each row is {name, description, fn}.
--     The dispatcher prints the help index when invoked bare, looks up by
--     name, and re-prints help on an unknown name. Help text is generated
--     from the same table, so adding a command = adding a single row.
--   * DUMP_TARGETS — `/cm dump <target>` namespace, kept for diagnostics.
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

-- Addon version for the `version` verb and the help header. Read from the TOC
-- metadata (the packaged manifest) with the in-code constant as fallback, so it
-- can't drift from what actually shipped (slash-commands-§3).
local function addonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local v = get and get(KCM.name or "ConsumableMaster", "Version")
    if v and v ~= "" then return v end
    return KCM.VERSION or "?"
end

-- Shared confirmation popup for /cm resetall. preferredIndex = 3 dodges the
-- taint cascade that affects popup slots 1/2 when other addons have used
-- them earlier in the session (a well-known Ace3 footgun around any
-- StaticPopup that mutates SavedVariables).
--
-- It hangs off the global StaticPopupDialogs at file scope and is reached by
-- name through StaticPopup_Show, so which VERB raises it is the only thing
-- that ever moved: `/cm reset` used to, `/cm resetall` does now (LIBKA0S-12).
-- The dialog, its wording and its body are untouched by that swap — the
-- destructive path keeps the confirmation it has always had.
StaticPopupDialogs["KCM_CONFIRM_RESET"] = {
    -- Same wording as the Options panel's KCM_RESET_ALL so both global-reset
    -- entry points describe identical scope (they share KCM.ResetAllToDefaults).
    text = L["Reset ALL ConsumableMaster customization to defaults? This wipes every category's added/blocked/pinned items and all stat-priority overrides, and re-enables the addon. Your macros stay in place, and items currently in your bags are re-discovered automatically. This cannot be undone."],
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

-- ---------------------------------------------------------------------------
-- Dump targets: single source of truth. Each entry has a one-line summary
-- (shown in help) and a handler. Add new dump targets here and they appear
-- in both `/cm` and `/cm dump` help output automatically.
-- ---------------------------------------------------------------------------

local DUMP_TARGETS = {}

DUMP_TARGETS.categories = {
    summary = "category metadata table",
    run = function()
        if not (KCM.Categories and KCM.Categories.LIST) then
            say("KCM.Categories.LIST not loaded.")
            return
        end
        if DevTools_Dump then
            DevTools_Dump(KCM.Categories.LIST)
        else
            for i, row in ipairs(KCM.Categories.LIST) do
                say(("  [%d] %s  macro=%s  display=%q  specAware=%s")
                    :format(i, row.key, row.macroName, row.displayName, tostring(row.specAware)))
            end
        end
    end,
}

DUMP_TARGETS.statpriority = {
    summary = "stat priority for current spec",
    run = function()
        if not (KCM.SpecHelper and KCM.SpecHelper.GetCurrent) then
            say("KCM.SpecHelper not loaded.")
            return
        end
        local classID, specID, specKey, specName = KCM.SpecHelper.GetCurrent()
        if not specKey then
            say("No active spec (low-level character?).")
            return
        end
        local priority = KCM.SpecHelper.GetStatPriority(specKey)
        say(("spec: %s  (classID=%s  specID=%s  key=%s)")
            :format(specName or "?", tostring(classID), tostring(specID), specKey))
        if DevTools_Dump then
            DevTools_Dump(priority)
        else
            say(("  primary: %s"):format(tostring(priority.primary)))
            say(("  secondary: %s"):format(table.concat(priority.secondary or {}, ", ")))
        end
    end,
}

DUMP_TARGETS.bags = {
    summary = "bag contents as itemID -> count",
    run = function()
        if not (KCM.BagScanner and KCM.BagScanner.Scan) then
            say("KCM.BagScanner not loaded.")
            return
        end
        local counts = KCM.BagScanner.Scan()
        if DevTools_Dump then
            DevTools_Dump(counts)
        else
            for id, n in pairs(counts) do
                say(("  %d x %d"):format(id, n))
            end
        end
    end,
}

DUMP_TARGETS.item = {
    summary = "parsed tooltip + raw lines for <itemID> (e.g. /cm dump item 241304)",
    usage   = "item <itemID>",
    run = function(arg)
        local id = tonumber(arg or "")
        if not id then
            say("usage: /cm dump item <itemID>")
            return
        end
        if not (KCM.TooltipCache and KCM.TooltipCache.Get) then
            say("KCM.TooltipCache not loaded.")
            return
        end
        local entry = KCM.TooltipCache.Get(id)
        local name = (entry and entry.itemName)
            or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
            or "?"
        say(("item %d  (%s)"):format(id, tostring(name)))

        if C_Item and C_Item.GetItemInfoInstant then
            local _, iType, iSubType, _, _, iClass, iSub = C_Item.GetItemInfoInstant(id)
            say(("  instant: type=%q  subType=%q  classID=%s  subClassID=%s")
                :format(tostring(iType), tostring(iSubType),
                        tostring(iClass), tostring(iSub)))
            local hits = KCM.Classifier and KCM.Classifier.MatchAny
                and KCM.Classifier.MatchAny(id) or {}
            if #hits > 0 then
                say(("  classified: %s"):format(table.concat(hits, ", ")))
            else
                say("  classified: |cffff4444(none)|r")
            end
        end

        if entry and entry.pending then
            say("  pending: tooltip data not yet loaded — try again in a moment.")
        elseif entry then
            local ok, reason = KCM.TooltipCache.IsUsableByPlayer(id)
            local playerLvl = UnitLevel("player") or 0
            if ok then
                say(("  usable: yes  (minLevel=%d, you=%d)"):format(entry.minLevel or 0, playerLvl))
            else
                say(("  usable: no   (%s)"):format(tostring(reason)))
            end
        end
        if DevTools_Dump then
            DevTools_Dump(entry)
        end

        if C_TooltipInfo and C_TooltipInfo.GetItemByID then
            local data = C_TooltipInfo.GetItemByID(id)
            if data and data.lines and #data.lines > 0 then
                say(("  raw tooltip lines (%d)"):format(#data.lines))
                for i, line in ipairs(data.lines) do
                    local left = line.leftText or ""
                    local right = line.rightText or ""
                    if right ~= "" then
                        say(("    [%2d] L=%q  R=%q"):format(i, left, right))
                    else
                        say(("    [%2d] %q"):format(i, left))
                    end
                end
            end
        end
    end,
}

DUMP_TARGETS.pick = {
    summary = "effective priority (with scores) + best-owned pick for a category",
    usage   = "pick <catKey>",
    run = function(arg)
        arg = (arg or ""):match("^(%S*)") or ""
        if arg == "" then
            say("usage: /cm dump pick <catKey>  (e.g. flask, hp_pot, stat_food)")
            if KCM.Categories and KCM.Categories.LIST then
                local keys = {}
                for _, cat in ipairs(KCM.Categories.LIST) do
                    table.insert(keys, cat.key:lower())
                end
                say("  known: " .. table.concat(keys, ", "))
            end
            return
        end
        local catKey = arg:upper()
        local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
        if not cat then
            say("unknown category: |cffffff00" .. arg .. "|r")
            return
        end
        if not (KCM.Selector and KCM.Selector.GetEffectivePriority) then
            say("KCM.Selector not loaded.")
            return
        end

        if cat.composite then
            say(("%s (composite)"):format(catKey))
            local cfg = KCM.db and KCM.db.profile and KCM.db.profile.categories
                and KCM.db.profile.categories[cat.key]
            if not cfg then
                say("no DB bucket for composite category.")
                return
            end
            local function describePick(refKey)
                local pick = KCM.Selector.PickBestForCategory(refKey)
                if not pick then return "(no pick)" end
                if KCM.ID and KCM.ID.IsSpell(pick) then
                    local sid = KCM.ID.SpellID(pick)
                    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)) or "?"
                    return ("spell:%d %s"):format(sid or 0, name)
                end
                local tt = KCM.TooltipCache and KCM.TooltipCache.Get(pick)
                local name = (tt and tt.itemName)
                    or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(pick))
                    or "?"
                return ("%d %s"):format(pick, name)
            end
            local sections = {
                { label = "In Combat",     orderField = "orderInCombat"    },
                { label = "Out of Combat", orderField = "orderOutOfCombat" },
            }
            for _, section in ipairs(sections) do
                say(("  %s"):format(section.label))
                local arr = cfg[section.orderField] or {}
                if #arr == 0 then
                    say("    (none)")
                else
                    for i, ref in ipairs(arr) do
                        local enabled = not (cfg.enabled and cfg.enabled[ref] == false)
                        local tag = enabled and "|cff44ff44[on]|r " or "|cff888888[off]|r"
                        say(("    %d. %s %s -> %s"):format(i, tag, ref, describePick(ref)))
                    end
                end
            end
            if KCM.MacroManager and KCM.MacroManager.BuildCompositeBody then
                local body = KCM.MacroManager.BuildCompositeBody(cat,
                    function(refKey) return KCM.Selector.PickBestForCategory(refKey) end)
                if body then
                    say("  macro body")
                    for line in body:gmatch("[^\n]+") do
                        say("    " .. line)
                    end
                else
                    say("no usable picks — macro would show empty-state stub.")
                end
            end
            return
        end

        local ctx
        if cat.specAware and KCM.SpecHelper then
            local _, _, specKey, specName = KCM.SpecHelper.GetCurrent()
            if specKey then
                ctx = { specPriority = KCM.SpecHelper.GetStatPriority(specKey) }
                say(("%s for spec %s (%s)"):format(catKey, specName or "?", specKey))
                say(("  primary=%s  secondary=%s"):format(
                    tostring(ctx.specPriority.primary),
                    table.concat(ctx.specPriority.secondary or {}, ">")))
            else
                say(("%s (no active spec)"):format(catKey))
            end
        else
            say(("%s"):format(catKey))
        end

        local priority = KCM.Selector.GetEffectivePriority(catKey)
        local pick = KCM.Selector.PickBestForCategory(catKey)
        if KCM.Ranker and KCM.Ranker.BuildContext then
            ctx = KCM.Ranker.BuildContext(catKey, priority, ctx)
        end

        say(("  effective priority (%d entries)"):format(#priority))
        for i, id in ipairs(priority) do
            local name, did, have
            if KCM.ID and KCM.ID.IsSpell(id) then
                local sid = KCM.ID.SpellID(id)
                did = ("spell:%d"):format(sid or 0)
                if C_Spell and C_Spell.GetSpellName then
                    name = C_Spell.GetSpellName(sid)
                end
                name = name or "?"
                have = sid and IsPlayerSpell and IsPlayerSpell(sid) or false
            else
                did = tostring(id)
                local tt = KCM.TooltipCache and KCM.TooltipCache.Get(id)
                name = (tt and tt.itemName)
                    or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
                    or "?"
                have = KCM.BagScanner and KCM.BagScanner.HasItem and KCM.BagScanner.HasItem(id) or false
            end
            local score = (KCM.Ranker and KCM.Ranker.Score and KCM.Ranker.Score(catKey, id, ctx)) or 0
            local haveTag = have and "|cff44ff44[owned]|r" or "|cff888888[---]|r"
            local pickTag = (id == pick) and "  |cffffd100<-- pick|r" or ""
            say(("  %2d. %s %8.1f  %s  %s%s"):format(i, haveTag, score, did, name, pickTag))
        end
        if not pick then
            say("no owned item — macro would show empty-state stub.")
        end
    end,
}

-- Ordered keys so help output is stable. Add new dump names here in the
-- order you want them shown.
local DUMP_ORDER = { "categories", "statpriority", "bags", "item", "pick" }

local function printDumpLines(prefix)
    for _, name in ipairs(DUMP_ORDER) do
        local target = DUMP_TARGETS[name]
        if target then
            local label = target.usage or name
            say(("  |cffffff00%s%s|r%s |cffffffff%s|r")
                :format(prefix, label, string.rep(" ", math.max(1, 18 - #label)), target.summary))
        end
    end
end

local function dumpHelp()
    say("dump targets")
    printDumpLines("/cm dump ")
end

local function dumpDispatch(rest)
    rest = rest or ""
    local head, tail = rest:match("^(%S*)%s*(.-)$")
    head = (head or ""):lower()
    if head == "" then
        dumpHelp()
        return
    end
    -- Shortcut: `/cm dump <itemID>` routes to the `item` target.
    if tonumber(head) then
        DUMP_TARGETS.item.run(head)
        return
    end
    local target = DUMP_TARGETS[head]
    if target then
        target.run(tail)
        return
    end
    say("Unknown dump target: |cffffff00" .. head .. "|r")
    dumpHelp()
end

-- ---------------------------------------------------------------------------
-- Schema-driven /cm list / get / set
-- ---------------------------------------------------------------------------
--
-- Every row in KCM.Settings.Schema (declared in settings/Panel.lua) automatically
-- gets `/cm get <path>` and `/cm set <path> <value>` for free, plus shows up
-- in `/cm list`. Adding a new scalar setting = one schema row.

local function helpers()
    return KCM.Settings and KCM.Settings.Helpers
end

-- Bound at the foot of this file, once the Slash instance exists.
local cliList, cliGet, cliSet, cliReset

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
-- What the library gained that made this possible is recorded as LIBKA0S-02 —
-- it now reads the ordered {value=, text=} enum shape this addon declares, and
-- takes a colour codec so a positional { r, g, b, a } round-trips. Before that,
-- adopting it would have rendered all seven colour rows as {0.00, 0.00, 0.00,
-- 1.00} and offered "1, 2" as the allowed values for a dropdown — both
-- silently, and both green.
--
-- One thing arrives free: colours may now be given as 0-255 as well as 0-1, and
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

local function priorityList(cat, _rest)
    if cat.composite then
        return DUMP_TARGETS.pick.run(cat.key:lower())
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
        local owned
        if KCM.ID and KCM.ID.IsSpell(id) then
            owned = (IsPlayerSpell and KCM.ID.SpellID and IsPlayerSpell(KCM.ID.SpellID(id))) or false
        else
            owned = KCM.BagScanner and KCM.BagScanner.HasItem and KCM.BagScanner.HasItem(id) or false
        end
        local haveTag = owned and "|cff44ff44[owned]|r" or "|cff888888[---]  |r"
        local pickTag = (id == pick) and "  |cffffd100<-- pick|r" or ""
        say(("  %2d. %s %-12s %s%s"):format(i, haveTag, displayID(id), nameForStoredID(id), pickTag))
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

local function aioToggle(cat, rest)
    local args = tokenize(rest)
    local ref = args[1] and args[1]:upper() or nil
    if not ref then
        return say("Usage: /cm aio <key> toggle <ref> [on|off]")
    end
    local cfg = compositeCfg(cat)
    if not cfg then return say("no DB bucket for " .. cat.key) end
    if not locateAIORef(cfg, ref) then
        return say(("ref '%s' is not part of %s"):format(ref, cat.key))
    end
    cfg.enabled = cfg.enabled or {}
    local explicit = (args[2] or ""):lower()
    local newVal
    if explicit == "on" or explicit == "true" or explicit == "1" or explicit == "yes" then
        newVal = true
    elseif explicit == "off" or explicit == "false" or explicit == "0" or explicit == "no" then
        newVal = false
    else
        local cur = cfg.enabled[ref]
        if cur == nil then cur = true end
        newVal = not cur
    end
    cfg.enabled[ref] = newVal and true or false
    say(("%s.enabled.%s = %s"):format(cat.key, ref, tostring(newVal)))
    afterMutation("slash_aio_toggle")
end

local function aioMove(cat, rest, dir)
    local args = tokenize(rest)
    local ref = args[1] and args[1]:upper() or nil
    if not ref then
        return say(("Usage: /cm aio <key> %s <ref>"):format(dir))
    end
    local cfg = compositeCfg(cat)
    if not cfg then return say("no DB bucket for " .. cat.key) end
    local field, idx = locateAIORef(cfg, ref)
    if not field then
        return say(("ref '%s' is not part of %s"):format(ref, cat.key))
    end
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
-- Top-level COMMANDS table + dispatcher
-- ---------------------------------------------------------------------------

local printHelp  -- forward decl (printed by COMMANDS[1].fn)

local COMMANDS = {
    {"help",          "Show this help",
        function() printHelp() end},
    {"config",        "Open the settings panel",
        function()
            if not (KCM.Options and KCM.Options.Open and KCM.Options.Open()) then
                say("Settings panel unavailable.")
            end
        end},
    {"version",       "Print addon version",
        function() say("v" .. addonVersion()) end},
    {"perf",          "A/B performance capture — `/cm perf` opens the step panel",
        function(rest)
            -- Resolved at call time, exactly as `bar` does: modules/PerfSetup.lua
            -- loads after this file, and on a build without LibKa0s-Perf it
            -- never publishes KCM.Perf at all.
            if not (KCM.Perf and KCM.Perf.OnCommand) then
                return say("perf capture unavailable.")
            end
            for _, line in ipairs(KCM.Perf.OnCommand(rest)) do say(line) end
        end},
    {"debug",         "Toggle the debug window; `on`/`off` set logging — `/cm debug [on|off]`",
        function(rest)
            local arg = (rest or ""):match("^(%S*)"):lower()
            local DL = KCM.DebugLog
            if arg == "on" or arg == "off" then
                -- DL.SetEnabled is the single seam: it owns the chat ack, the
                -- console transition line, and the options-panel refresh (§5).
                local want = (arg == "on")
                if DL and DL.SetEnabled then
                    DL.SetEnabled(want)
                    if want and DL.Show then DL.Show() end
                elseif KCM.State then
                    KCM.State.debug = want
                end
            else
                -- Bare `/cm debug` toggles the window only; the flag is untouched
                -- (debug-logging-§5), so capture can be armed independently.
                if DL and DL.Toggle_Window then
                    DL.Toggle_Window()
                else
                    say("Debug console unavailable.")
                end
            end
        end},
    {"resync",        "Force macros to resync from bags",
        function()
            if InCombatLockdown and InCombatLockdown() then
                say("in combat — picks computed now; macro writes will apply when combat ends.")
            end
            if KCM.TooltipCache and KCM.TooltipCache.InvalidateAll then
                KCM.TooltipCache.InvalidateAll()
            end
            if KCM.Pipeline and KCM.Pipeline.RunAutoDiscovery then
                local n = KCM.Pipeline.RunAutoDiscovery("manual_resync")
                say(("auto-discovery found %d new item(s)"):format(n))
            end
            if KCM.Pipeline and KCM.Pipeline.Recompute then
                KCM.Pipeline.Recompute("manual_resync")
                say("recomputed all categories.")
            end
        end},
    {"rewritemacros", "Force a full rewrite of every KCM macro (icon + body)",
        function()
            if InCombatLockdown and InCombatLockdown() then
                say("in combat — picks computed now; macro writes will apply when combat ends.")
            end
            if KCM.MacroManager and KCM.MacroManager.InvalidateState then
                KCM.MacroManager.InvalidateState()
            end
            if KCM.Pipeline and KCM.Pipeline.Recompute then
                KCM.Pipeline.Recompute("manual_rewrite")
                say("rewrote all macros (body + icon). If action bar icons still look stale, /reload to force the bars to refresh.")
            end
        end},
    -- BREAKING, 2026-08-01 (LIBKA0S-12). `reset` used to be this pair's second
    -- entry — the confirm-gated global wipe. It is now the library's
    -- path-scoped reset, matching `/at reset <path>` and `/kcd reset <path>`,
    -- and the wipe moved down one row to `resetall` with its popup intact.
    -- A bare `/cm reset` cannot silently do the smaller thing: USAGE_RESET is
    -- overridden below to name `resetall` explicitly.
    {"reset",         "Reset ONE setting to its default — `/cm reset <path>`",
        function(rest) cliReset(rest) end},
    {"resetall",      "Reset every priority list and stat override to defaults (asks first)",
        function()
            if StaticPopup_Show then
                StaticPopup_Show("KCM_CONFIRM_RESET")
            else
                say("StaticPopup unavailable.")
            end
        end},
    {"list",          "List every schema setting and its current value",
        function() cliList() end},
    {"get",           "Print a setting's current value — `/cm get <path>`",
        function(rest) cliGet(rest) end},
    {"set",           "Set a setting — `/cm set <path> <value>` (try /cm list)",
        function(rest) cliSet(rest) end},
    {"bar",           "Macro bar — `/cm bar [on|off|lock|unlock|reset]` (bare toggles it)",
        function(rest) runBar(rest) end},
    {"priority",      "Per-category priority list editor — try `/cm priority` for the list",
        function(rest) runPriority(rest) end},
    {"stat",          "Per-spec stat priority editor — try `/cm stat` for the list",
        function(rest) runStat(rest) end},
    {"aio",           "Composite-category editor (HP_AIO, MP_AIO) — try `/cm aio` for the list",
        function(rest) runAIO(rest) end},
    {"dump",          "Dump internal state — try `/cm dump` for the list",
        function(rest) dumpDispatch(rest) end},
}

-- Publish the command table so the About panel and any future consumer read
-- the same source of truth as the /cm dispatcher (standard §7.4).
KCM.COMMANDS = COMMANDS

-- ---------------------------------------------------------------------
-- LibKa0s-Slash-1.0 — the dispatcher
-- ---------------------------------------------------------------------
--
-- Everything above is this addon's: seventeen verbs, five sub-command tables
-- with three different handler arities, the dump targets, and the schema CLI.
-- What the library takes is the part that is the same in every Ka0s addon —
-- trim, split, lowercase the verb only, apply the alias, find the entry, call
-- it; plus the help header and rows.
--
-- The COMMANDS table is PASSED IN, not owned. That is the library's own design
-- note and it matters here: KCM.SlashCommands.GetCommandSummary below renders
-- the same table onto the About panel, and that page must not acquire a
-- dependency on the slash library to do it.
--
-- The schema CLI (Sl:CliList / CliGet / CliSet) IS adopted, since LIBKA0S-02
-- fixed both blockers upstream: lib.FormatValue reads this addon's positional
-- { r, g, b, a } colors directly, and the enum reader takes the ordered
-- { value =, text = } array rather than the tostring'd keys of a map. The
-- codecs below are what keep a `/cm set` round-trip in the addon's own shape.

-- The strings whose wording the addon already shipped. A plain table,
-- deliberately NOT KCM.L: Sl:Text resolves through rawget precisely so a
-- key-echoing locale table falls through, which also means KCM.L could never
-- supply these.
local SLASH_STRINGS = {
    HELP_HEADER     = "|cffffd100Ka0s Consumable Master|r v%s \226\128\148 slash commands",
    -- The library passes (alias, slash); this addon has only ever named the
    -- alias, so the second is unused and string.format drops it.
    HELP_ALIAS      = " (alias: |cffffff00%s|r)",
    UNKNOWN_COMMAND = "Unknown command: |cffffff00%s|r",
    -- ONE %s, not two. Sl:CliGet formats this with (d.slash) alone, so a
    -- second placeholder is not "unused" the way HELP_ALIAS's is — it is a
    -- missing argument, and string.format RAISES on that. A bare `/cm get`
    -- threw a Lua error in game for exactly as long as this line had two.
    -- The hint therefore carries the command literally; it is the same "/cm"
    -- declared as `slash` twenty lines below.
    USAGE_GET       = "Usage: %s get <path>  (try /cm list)",
    -- The deprecation notice for LIBKA0S-12, and the only place a user who
    -- has `/cm reset` in a macro finds out the verb changed meaning. The
    -- library's stock line is a bare "Usage: %s reset <path>", which would let
    -- a global wipe quietly become a one-row reset. Same arity as the stock
    -- string — Sl:CliReset formats it with (d.slash) alone, so ONE %s, and
    -- `resetall` is spelled literally for the same reason USAGE_GET is.
    USAGE_RESET     = "Usage: %s reset <path> \226\128\148 this resets ONE setting. " ..
                      "The old global wipe is now |cffffff00/cm resetall|r, " ..
                      "which still asks before it wipes.",
    -- These three are DEAD and kept only as a record of the wording they were
    -- meant to restore. The parsers that emit them are lib-level (Slash.lua's
    -- parseBool / allowedText / parseColor sit above lib:New), so they read
    -- lib.STRINGS directly and never pass through Sl:Text — an instance
    -- override cannot reach them. Reported upstream rather than worked around
    -- here; see LIBKA0S-09.
    ERR_BOOL        = "expected true/false/on/off/1/0",
    ERR_ALLOWED     = "Allowed values: %s",
    ERR_COLOR       = "expected: r g b [a] (each 0-1 or 0-255)",
}

local slashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local Sl

if slashLib then
    Sl = slashLib:New({
        slash        = "/cm",
        -- Only [1] is ever named, in the help header's alias clause.
        slashAliases = { "/consumablemaster" },
        commands     = COMMANDS,
        -- Backwards-compat: `/cm rewrite` → `/cm rewritemacros`. The original
        -- handler accepted both spellings; this preserves that without
        -- bloating COMMANDS.
        aliases      = { rewrite = "rewritemacros" },
        version      = addonVersion,
        -- A thunk, not `say` bare: the library snapshots the printer at :New.
        -- Same note as core/CoreSetup.lua's sink and modules/DebugLog.lua's
        -- print.
        print        = function(line) KCM.Say(line) end,
        L            = SLASH_STRINGS,

        -- The schema half. Every one of these resolves through KCM.Settings at
        -- CALL time: settings/Panel.lua loads long after this file, and the
        -- rows themselves are appended by the four page files after that.
        get          = function(path) local H = helpers(); return H and H.Get(path) end,
        set          = function(path, value)
            local H = helpers()
            if H then H.SetAndRefresh(path, value) end
        end,
        findRow      = function(path) local H = helpers(); return H and H.FindSchema(path) end,
        allRows      = function() return (KCM.Settings and KCM.Settings.Schema) or {} end,
        applyDefault = function(row)
            local H = helpers()
            if H and row.default ~= nil then H.SetAndRefresh(row.path, row.default) end
        end,
        -- Rows carry `panel`, not the library's default `page`.
        groupKey     = function(row) return row.panel or "?" end,

        -- Colours are stored POSITIONALLY here — { r, g, b, a } — which is what
        -- the Ka0s options colour widget writes. The library reads that shape
        -- directly when rendering, but the codec is what makes a `/cm set`
        -- WRITE land in it rather than in the named-key form.
        colorDecode  = function(c)
            c = type(c) == "table" and c or {}
            return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
        end,
        colorEncode  = function(r, g, b, a) return { r, g, b, a or 1 } end,
    })
    -- The instance, so the suite can assert identity rather than lookalike
    -- behavior. Mirrors KCM.DebugLog.instance and Settings.Helpers.instance.
    KCM.SlashCommands.instance = Sl

    printHelp = function() Sl:PrintHelp() end
    cliList   = function() Sl:CliList() end
    cliGet    = function(rest) Sl:CliGet(rest) end
    cliSet    = function(rest) Sl:CliSet(rest) end
    -- Sl:CliReset only, never Sl:CliResetAll: the library's resetall walks the
    -- schema rows, and this addon's global reset is KCM.ResetAllToDefaults,
    -- which also wipes the priority lists and the stat overrides — data the
    -- schema does not describe. `/cm resetall` keeps the host body.
    cliReset  = function(rest) Sl:CliReset(rest) end
else
    -- LibKa0s is vendored, so this is a tampered install rather than a
    -- supported state. Say so instead of re-implementing the dispatcher.
    printHelp = function()
        say((KCM.LIBKA0S_MISSING or "The LibKa0s library is missing") ..
            ", so /cm is unavailable.")
    end
    cliList, cliGet, cliSet, cliReset = printHelp, printHelp, printHelp, printHelp
end

-- Read-only view of the COMMANDS table for the About panel. Each row is
-- {name, summary} — same data the in-chat help table uses, so the panel and
-- /cm help stay in lock-step automatically.
--
-- Kept for callers that want the DATA. What the About panel wants is the
-- rendered line, and that is GetLandingRows below.
function KCM.SlashCommands.GetCommandSummary()
    local out = {}
    for i, entry in ipairs(COMMANDS) do
        out[i] = { name = entry[1], desc = entry[2] }
    end
    return out
end

-- The About panel's command rows, RENDERED -- convergence #2 (LIBKA0S-13).
--
-- The panel used to format these itself, with two spaces either side of the em
-- dash, the dash white-wrapped and the description bare, while the chat half
-- had already moved to lib.FormatRow. Two formatters for one table of data
-- inside one addon is exactly the drift the convergence exists to collapse --
-- and it survived this long because the panel reaches its rows through THIS
-- file rather than by naming COMMANDS, so a grep for the obvious name never
-- saw it.
--
-- It sits behind this function rather than settings/Panel.lua calling Sl
-- directly: the panel talks to this module, this module talks to the library.
-- That is the seam the rest of the addon already uses, and it keeps the About
-- page free of a LibKa0s lookup of its own -- which is what the note above
-- lib:New asks for.
--
-- Empty rather than a host-formatted fallback when the library is absent: with
-- LibKa0s missing the settings panel is not registered at all
-- (settings/Panel.lua, registerPanel), so there is no About page to render into
-- and a second formatter kept alive "just in case" would be the divergence
-- coming straight back.
function KCM.SlashCommands.GetLandingRows()
    if not Sl then return {} end
    return Sl:LandingRows()
end

function KCM:OnSlashCommand(msg)
    if not Sl then return printHelp() end
    return Sl:OnSlash(msg)
end
