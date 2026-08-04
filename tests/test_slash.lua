-- test_slash.lua — /cm dispatcher + parsers, exercised through the public
-- KCM:OnSlashCommand seam (the parsers themselves are file-local). Loads the
-- full addon so SlashCommands + the settings schema are present.

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadFullAddon()
    return KCM, h.loader.mock
end

local function say(KCM, mock, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return table.concat(mock.output, "\n")
end

local function effectiveSet(KCM, catKey)
    local set = {}
    for _, id in ipairs(KCM.Selector.GetEffectivePriority(catKey)) do set[id] = true end
    return set
end

test("/cm set toggles a bool setting through the schema", function(t)
    local KCM, mock = load()
    KCM:OnSlashCommand("set enabled false")
    t.eq(KCM.db.profile.enabled, false, "enabled set to false via schema")
    KCM:OnSlashCommand("set enabled true")
    t.eq(KCM.db.profile.enabled, true, "enabled set to true via schema")
end)

test("/cm priority add then remove edits the FOOD candidate set", function(t)
    local KCM = load()
    KCM:OnSlashCommand("priority food add 987654")
    t.truthy(effectiveSet(KCM, "FOOD")[987654], "added item present")
    KCM:OnSlashCommand("priority food remove 987654")
    t.falsy(effectiveSet(KCM, "FOOD")[987654], "removed/blocked item gone")
end)

test("/cm priority add accepts a spell sentinel (s:ID)", function(t)
    local KCM = load()
    KCM:OnSlashCommand("priority food add s:5512")
    local found = false
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        if KCM.ID.IsSpell(id) and KCM.ID.SpellID(id) == 5512 then found = true end
    end
    t.truthy(found, "spell entry added via s: syntax")
end)

test("/cm stat primary sets the current spec's primary stat", function(t)
    local KCM = load()
    KCM:OnSlashCommand("stat primary INT")
    local _, _, key = KCM.SpecHelper.GetCurrent()   -- "7_263"
    t.eq(KCM.db.profile.statPriority[key].primary, "INT", "primary set for current spec")
end)

test("/cm stat primary resolves a CLASS:SPEC token", function(t)
    local KCM = load()
    KCM:OnSlashCommand("stat primary STR SHAMAN:ENHANCEMENT")   -- 7:263
    t.eq(KCM.db.profile.statPriority["7_263"].primary, "STR", "CLASS:SPEC token resolved")
end)

test("/cm version prints the canonical v<version> line, not 'version <v>'", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "version")
    t.truthy(text:find("v" .. tostring(KCM.VERSION), 1, true),
        "version verb prints v<version>")
    t.falsy(text:find("version " .. tostring(KCM.VERSION), 1, true),
        "no 'version <v>' wording — canonical single-line form")
end)

test("/cm list colors the header, page group, and key=value rows (no trailing colon)", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "list")
    t.truthy(text:find("|cff33ff99Available settings|r", 1, true), "green Available settings header")
    t.truthy(text:find("|cff3399ff[general]|r", 1, true), "azure [page] group header")
    -- Case-insensitive on the escape: the shared formatter is LibKa0s-Slash-1.0's now and spells
    -- its hex in upper case, which WoW parses identically. What is pinned is the SHAPE — gold key,
    -- ` = `, white value, no trailing colon — not which case the digits happen to be in.
    t.truthy(text:lower():find("|cffffff00enabled|r = |cffffffff", 1, true),
        "gold key + white value via the shared FormatKV")
    t.falsy(text:find("Available settings:", 1, true), "header carries no trailing colon")
end)

test("/cm get echoes the same colored key=value form as list", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "get enabled")
    t.truthy(text:lower():find("|cffffff00enabled|r = |cffffffff", 1, true),
        "get reuses the shared gold-key / white-value formatter")
end)

test("/cm with an unknown command reports it and prints help", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "frobnicate")
    t.truthy(text:find("Unknown command", 1, true), "reports the unknown command")
    t.truthy(text:find("/cm", 1, true), "prints the help listing")
end)

test("/cm dump pick renders a category's effective priority and marks owned picks", function(t)
    local KCM, mock = load()
    -- Own the first item (positive-id) seed FOOD candidate so a pick exists.
    local seedFood
    for _, id in ipairs(KCM.SEED and KCM.SEED.FOOD or {}) do
        if type(id) == "number" and id > 0 then seedFood = id; break end
    end
    t.truthy(seedFood, "FOOD ships at least one item seed")
    mock.setBag(seedFood, 1)
    local text = say(KCM, mock, "dump pick food")
    t.truthy(text:find("effective priority", 1, true), "renders the effective priority list")
    t.truthy(text:find(tostring(seedFood), 1, true), "lists the owned candidate")
    t.truthy(text:find("owned", 1, true), "marks it owned")
end)

test("/cm rewrite is a back-compat alias for rewritemacros", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "rewrite")
    t.truthy(text:find("rewrote all macros", 1, true), "alias routes to rewritemacros")
end)

-- ---------------------------------------------------------------------------
-- Dispatcher
-- ---------------------------------------------------------------------------

test("/cm with no argument prints the help table", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "")
    -- Driven from the dispatcher table itself, which is the thing that must be
    -- fully covered — a view of it could agree with the help output while both
    -- disagreed with what actually dispatches.
    for _, entry in ipairs(KCM.COMMANDS) do
        t.truthy(text:find("/cm " .. entry[1], 1, true), "help lists /cm " .. entry[1])
    end
end)

test("/cm lower-cases only the verb, leaving arguments alone", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "VERSION")
    t.truthy(text:find("v" .. tostring(KCM.VERSION), 1, true), "an upper-case verb still dispatches")

    KCM:OnSlashCommand("STAT PRIMARY int SHAMAN:ENHANCEMENT")
    t.eq(KCM.db.profile.statPriority["7_263"].primary, "INT",
        "argument casing is normalized by the handler, not by the dispatcher")
end)

test("/cm tolerates surrounding whitespace", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "   version   ")
    t.truthy(text:find("v" .. tostring(KCM.VERSION), 1, true), "padding is trimmed before dispatch")
end)

test("/cm help and the About panel read the same command table", function(t)
    -- Was written against a { name =, desc = } data view of COMMANDS. Since
    -- LIBKA0S-13 the panel renders through the library's formatter, so the view
    -- had no caller left in the addon and went; this now asks the rows the
    -- panel actually draws. Same claim — one row per command, in order, from
    -- the dispatcher table — one step closer to the screen.
    local KCM = load()
    local rows = KCM.SlashCommands.GetLandingRows()
    t.eq(#rows, #KCM.COMMANDS, "one rendered row per command")
    for i, entry in ipairs(KCM.COMMANDS) do
        t.truthy(rows[i]:find("/cm " .. entry[1], 1, true),
            "row " .. i .. " names the dispatcher's verb")
        t.truthy(rows[i]:find(entry[2], 1, true),
            "row " .. i .. " carries the dispatcher's description")
    end
end)

-- ---------------------------------------------------------------------------
-- /cm reset (one path) and /cm resetall (the guarded global wipe)
--
-- LIBKA0S-12. `/cm reset` used to BE the global wipe; it now resets one schema
-- row and the wipe moved to `/cm resetall` with its confirmation intact. The
-- three cases below are the guard on both halves of that swap: the destructive
-- verb must still ask, and the path verb must still be surgical.
-- ---------------------------------------------------------------------------

test("/cm resetall asks for confirmation instead of wiping immediately", function(t)
    local KCM = load()
    local shown
    local saved = _G.StaticPopup_Show
    _G.StaticPopup_Show = function(which) shown = which end
    KCM.Selector.AddItem("FOOD", 960001)
    KCM:OnSlashCommand("resetall")
    _G.StaticPopup_Show = saved
    t.eq(shown, "KCM_CONFIRM_RESET", "a destructive reset goes through a confirmation popup")
    t.truthy(KCM.Selector.GetBucket("FOOD").added[960001], "nothing is wiped until the user confirms")
end)

test("/cm resetall's confirmation still performs the full wipe when accepted", function(t)
    local KCM, mock = load()
    -- The half the popup-was-shown case cannot see. Moving the verb without
    -- moving the body would leave a dialog that asks and then does nothing;
    -- moving the body without the dialog would wipe on the spot. This drives
    -- the registered OnAccept, so it fails either way.
    KCM.Selector.AddItem("FOOD", 960001)
    KCM.db.profile.enabled = false
    mock.output = {}
    local dialog = _G.StaticPopupDialogs and _G.StaticPopupDialogs["KCM_CONFIRM_RESET"]
    t.truthy(dialog and dialog.OnAccept, "the popup is still registered with an accept handler")
    dialog.OnAccept()
    t.falsy(KCM.Selector.GetBucket("FOOD").added[960001], "the added item is gone once confirmed")
    t.eq(KCM.db.profile.enabled, true, "…and the master enable is restored with it")
    t.truthy(table.concat(mock.output, "\n"):find("Reset complete", 1, true),
        "…and the user is told: " .. table.concat(mock.output, "\n"))
end)

test("/cm reset <path> restores exactly that row and leaves its neighbors alone", function(t)
    local KCM, mock = load()
    -- Surgical, not global. Two rows are moved off their defaults and only one
    -- is named; a `reset` that still wipes everything fails on the neighbor.
    KCM.Selector.AddItem("FOOD", 960001)
    KCM:OnSlashCommand("set macroBar.orientation VERTICAL")
    KCM:OnSlashCommand("set macroBar.enabled false")
    t.eq(KCM.db.profile.macroBar.orientation, "VERTICAL", "precondition: the row is off its default")
    t.eq(KCM.db.profile.macroBar.enabled, false, "precondition: the neighbor is off its default too")

    mock.output = {}
    KCM:OnSlashCommand("reset macroBar.orientation")
    t.eq(KCM.db.profile.macroBar.orientation, "HORIZONTAL", "the named row is back at its default")
    t.eq(KCM.db.profile.macroBar.enabled, false, "the row nobody named is untouched")
    t.truthy(KCM.Selector.GetBucket("FOOD").added[960001],
        "and the priority lists — what the OLD /cm reset wiped — are not in scope at all")
    t.truthy(table.concat(mock.output, "\n"):find("macroBar.orientation", 1, true),
        "…and the echo names the path that moved: " .. table.concat(mock.output, "\n"))
end)

test("/cm config reports when the settings panel cannot be opened", function(t)
    local KCM, mock = load()
    KCM.Options.Open = function() return false end
    local text = say(KCM, mock, "config")
    t.truthy(text:find("unavailable", 1, true), "the user is told rather than left with silence")
end)

-- ---------------------------------------------------------------------------
-- /cm priority
-- ---------------------------------------------------------------------------

test("/cm priority with no category prints the sub-verbs and known categories", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "priority")
    for _, verb in ipairs({ "list", "add", "remove", "up", "down", "reset" }) do
        t.truthy(text:find("/cm priority <cat> " .. verb, 1, true), verb .. " is documented")
    end
    t.truthy(text:find("known cats:", 1, true), "and the category keys are listed")
end)

test("/cm priority with an unknown category reports it and prints help", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "priority frobnicate list")
    t.truthy(text:find("unknown category 'frobnicate'", 1, true), "names the bad token")
    t.truthy(text:find("known cats:", 1, true), "and shows the valid ones")
end)

test("/cm priority <cat> with no sub-verb defaults to the list", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "priority food")
    t.truthy(text:find("FOOD:", 1, true), "the effective list is printed")
    t.truthy(text:find("entries", 1, true), "with an entry count")
end)

test("/cm priority list marks ownership and the current pick", function(t)
    local KCM, mock = load()
    local seed
    for _, id in ipairs(KCM.SEED.FOOD) do
        if KCM.ID.IsItem(id) then seed = id; break end
    end
    mock.setItem(seed, { subType = "Food & Drink", tt = { healValue = 900 } })
    mock.setBag(seed, 1)
    local text = say(KCM, mock, "priority food list")
    t.truthy(text:find("[owned]", 1, true), "owned entries are tagged")
    t.truthy(text:find("<-- pick", 1, true), "and the winning entry is called out")
end)

-- The row shape itself is the contract users read at a glance: a 2-wide index,
-- the ownership tag (whose not-owned form pads with two trailing spaces so the
-- ID column still lines up), a 12-wide ID and the name. Pinned here so the
-- formatter can move without the columns shifting.
test("/cm priority list renders item and spell rows in the same columns", function(t)
    local KCM, mock = load()
    KCM:OnSlashCommand("priority food add s:5512")
    local text = say(KCM, mock, "priority food list")
    t.truthy(text:find("|cff888888[---]  |r", 1, true), "the not-owned tag keeps its two-space pad")
    t.truthy(text:match("  %d+%. |cff%x+%[[^%]]+%][^|]*|r s:5512 "),
        "a spell entry renders as s:<id> in the 12-wide ID column")
end)

test("/cm priority on a spec-aware category with no spec explains the refusal", function(t)
    local KCM, mock = load()
    local getCurrent = KCM.SpecHelper.GetCurrent
    KCM.SpecHelper.GetCurrent = function() return nil, nil, nil, nil end
    local text = say(KCM, mock, "priority flask list")
    KCM.SpecHelper.GetCurrent = getCurrent
    t.truthy(text:find("spec-aware category but no active spec", 1, true),
        "the user is told why, rather than shown an empty list")
end)

test("/cm priority rejects an unparseable id with a usage line", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "priority food add notanid")
    t.truthy(text:find("Usage: /cm priority <cat> add", 1, true), "usage is echoed rather than failing silently")
end)

test("/cm priority reset clears the user's edits but keeps discoveries", function(t)
    local KCM, mock = load()
    KCM.Selector.MarkDiscovered("FOOD", 960002)
    KCM:OnSlashCommand("priority food add 960003")
    KCM:OnSlashCommand("priority food remove 960004")

    local text = say(KCM, mock, "priority food reset")
    local bucket = KCM.Selector.GetBucket("FOOD")
    t.eq(next(bucket.added), nil, "added cleared")
    t.eq(next(bucket.blocked), nil, "blocked cleared")
    t.eq(next(bucket.pins), nil, "pins cleared")
    t.truthy(bucket.discovered[960002], "auto-discovered items survive a priority reset")
    t.truthy(text:find("discovered items preserved", 1, true), "and the message says so")
end)

test("/cm priority up reorders the list by pinning", function(t)
    local KCM, mock = load()
    local before = KCM.Selector.GetEffectivePriority("FOOD")
    local second = before[2]
    local text = say(KCM, mock, "priority food up " .. second)
    t.truthy(text:find("moved up", 1, true), "the move is acknowledged")
    t.eq(KCM.Selector.GetEffectivePriority("FOOD")[1], second, "the entry is now first")
end)

test("/cm priority up on the top entry reports the edge instead of reordering", function(t)
    local KCM, mock = load()
    local first = KCM.Selector.GetEffectivePriority("FOOD")[1]
    local text = say(KCM, mock, "priority food up " .. first)
    t.truthy(text:find("already at edge", 1, true), "no silent no-op")
end)

test("/cm priority on a composite category points at the aio editor", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "priority hp_aio add 12345")
    t.truthy(text:find("composite category", 1, true), "explains why the verb does not apply")
    t.truthy(text:find("/cm aio hp_aio", 1, true), "and names the command that does")
end)

test("/cm priority with an unknown sub-verb reports it", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "priority food frobnicate")
    t.truthy(text:find("unknown priority subcommand 'frobnicate'", 1, true), "names the bad sub-verb")
end)

-- ---------------------------------------------------------------------------
-- /cm stat
-- ---------------------------------------------------------------------------

test("/cm stat with no sub-verb prints the stat help", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat")
    for _, verb in ipairs({ "list", "primary", "secondary", "reset" }) do
        t.truthy(text:find("/cm stat " .. verb, 1, true), verb .. " is documented")
    end
    t.truthy(text:find("CLASS:SPEC", 1, true), "the spec-key syntax is explained")
end)

test("/cm stat list prints the resolved priority for the current spec", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat list")
    local p = KCM.SpecHelper.GetStatPriority("7_263")
    t.truthy(text:find("primary:   " .. p.primary, 1, true), "primary is shown")
    t.truthy(text:find("secondary:", 1, true), "secondary list is shown")
end)

test("/cm stat primary rejects a stat that is not a primary", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat primary CRIT")
    t.truthy(text:find("Usage: /cm stat primary", 1, true), "CRIT is a secondary stat, not a primary")
    t.eq(KCM.db.profile.statPriority["7_263"], nil, "nothing is written")
end)

test("/cm stat secondary stores an ordered, deduplicated list", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat secondary HASTE,CRIT,HASTE")
    t.eqList(KCM.db.profile.statPriority["7_263"].secondary, { "HASTE", "CRIT" },
        "the duplicate is dropped so the Ranker cannot weight one stat twice")
    t.truthy(text:find("HASTE, CRIT", 1, true), "the stored order is echoed back")
end)

test("/cm stat secondary rejects the whole list if any stat is unknown", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat secondary CRIT,BOGUS")
    t.truthy(text:find("Unknown secondary stat(s): BOGUS", 1, true), "names the offender")
    t.eq(KCM.db.profile.statPriority["7_263"], nil, "and writes nothing at all")
end)

test("/cm stat secondary preserves the existing primary", function(t)
    local KCM = load()
    KCM:OnSlashCommand("stat primary AGI")
    KCM:OnSlashCommand("stat secondary CRIT")
    t.eq(KCM.db.profile.statPriority["7_263"].primary, "AGI",
        "editing one half of the override does not blank the other")
end)

test("/cm stat reset drops the override and falls back to the seed", function(t)
    local KCM, mock = load()
    KCM:OnSlashCommand("stat primary STR")
    local text = say(KCM, mock, "stat reset")
    t.eq(KCM.db.profile.statPriority["7_263"], nil, "the override row is removed")
    t.truthy(text:find("falling back to seed/class default", 1, true), "and the fallback is explained")
end)

test("/cm stat reset on a spec with no override says there is nothing to do", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat reset")
    t.truthy(text:find("nothing to reset", 1, true), "no phantom success message")
end)

test("/cm stat with an unknown sub-verb reports it", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "stat frobnicate")
    t.truthy(text:find("unknown stat subcommand 'frobnicate'", 1, true), "names the bad sub-verb")
end)

-- ---------------------------------------------------------------------------
-- /cm aio
-- ---------------------------------------------------------------------------

test("/cm aio with no key prints the sub-verbs and the composite keys", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "aio")
    t.truthy(text:find("known composites:", 1, true), "the composite keys are listed")
    t.truthy(text:find("hp_aio", 1, true), "including HP_AIO")
end)

test("/cm aio on a single-pick category is rejected", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "aio food list")
    t.truthy(text:find("unknown composite category 'food'", 1, true), "FOOD is not a composite")
end)

test("/cm aio list shows both sections with their on/off state", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "aio hp_aio list")
    t.truthy(text:find("In Combat", 1, true), "in-combat section header")
    t.truthy(text:find("Out of Combat", 1, true), "out-of-combat section header")
    t.truthy(text:find("[on]", 1, true), "sub-categories ship enabled")
end)

test("/cm aio toggle flips a sub-category and back", function(t)
    local KCM = load()
    KCM:OnSlashCommand("aio hp_aio toggle HS")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, false, "toggled off")
    KCM:OnSlashCommand("aio hp_aio toggle HS")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, true, "and back on")
end)

test("/cm aio toggle honors an explicit on/off argument", function(t)
    local KCM = load()
    KCM:OnSlashCommand("aio hp_aio toggle HS off")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, false, "explicit off")
    KCM:OnSlashCommand("aio hp_aio toggle HS off")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, false, "an idempotent off stays off")
    KCM:OnSlashCommand("aio hp_aio toggle HS yes")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, true, "'yes' is accepted as on")
end)

test("/cm aio toggle on a ref with no stored flag flips it OFF, not on", function(t)
    local KCM = load()
    local cfg = KCM.db.profile.categories.HP_AIO
    cfg.enabled.HS = nil                       -- never written: the unset case
    KCM:OnSlashCommand("aio hp_aio toggle HS")
    t.eq(cfg.enabled.HS, false,
        "unset reads as currently-on (the body builder's `~= false` default), so a flip is off")
end)

test("/cm aio toggle writes a real boolean, never a string or nil", function(t)
    local KCM = load()
    KCM:OnSlashCommand("aio hp_aio toggle HS 1")
    t.eq(type(KCM.db.profile.categories.HP_AIO.enabled.HS), "boolean", "'1' stores true, not \"1\"")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, true, "and it is on")
    KCM:OnSlashCommand("aio hp_aio toggle HS 0")
    t.eq(type(KCM.db.profile.categories.HP_AIO.enabled.HS), "boolean", "'0' stores false, not \"0\"")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, false, "and it is off")
end)

test("/cm aio toggle with an unrecognized word falls through to a flip", function(t)
    local KCM, mock = load()
    KCM.db.profile.categories.HP_AIO.enabled.HS = true
    local text = say(KCM, mock, "aio hp_aio toggle HS maybe")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.HS, false, "a junk word is not an explicit value")
    t.truthy(text:find("HP_AIO.enabled.HS = false", 1, true), "and the new value is echoed")
end)

test("/cm aio toggle rejects a ref that is not part of the composite", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "aio hp_aio toggle DRINK")
    t.truthy(text:find("is not part of HP_AIO", 1, true), "DRINK belongs to MP_AIO")
    t.eq(KCM.db.profile.categories.HP_AIO.enabled.DRINK, nil, "and nothing is written")
end)

test("/cm aio down reorders within a section", function(t)
    local KCM = load()
    local cfg = KCM.db.profile.categories.HP_AIO
    local first, second = cfg.orderInCombat[1], cfg.orderInCombat[2]
    KCM:OnSlashCommand("aio hp_aio down " .. first)
    t.eq(cfg.orderInCombat[1], second, "the neighbor moved up")
    t.eq(cfg.orderInCombat[2], first, "and the target moved down")
end)

test("/cm aio up at the top of a section reports the edge", function(t)
    local KCM, mock = load()
    local first = KCM.db.profile.categories.HP_AIO.orderInCombat[1]
    local text = say(KCM, mock, "aio hp_aio up " .. first)
    t.truthy(text:find("already at top edge of In Combat", 1, true), "names the section it is pinned to")
end)

test("/cm aio reset restores both the enabled flags and the section order", function(t)
    local KCM = load()
    local cfg = KCM.db.profile.categories.HP_AIO
    local defaults = KCM.dbDefaults.profile.categories.HP_AIO
    KCM:OnSlashCommand("aio hp_aio toggle HS off")
    KCM:OnSlashCommand("aio hp_aio down " .. cfg.orderInCombat[1])

    KCM:OnSlashCommand("aio hp_aio reset")
    t.eq(cfg.enabled.HS, true, "enabled flags restored")
    t.eqList(cfg.orderInCombat, defaults.orderInCombat, "section order restored")
end)

test("/cm aio with an unknown sub-verb reports it", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "aio hp_aio frobnicate")
    t.truthy(text:find("unknown aio subcommand 'frobnicate'", 1, true), "names the bad sub-verb")
end)

-- ---------------------------------------------------------------------------
-- /cm dump
-- ---------------------------------------------------------------------------

test("/cm dump with no target lists every dump target", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump")
    for _, name in ipairs({ "categories", "statpriority", "bags", "item", "pick" }) do
        t.truthy(text:find(name, 1, true), "dump target " .. name .. " is listed")
    end
end)

test("/cm dump with an unknown target reports it and lists the valid ones", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump frobnicate")
    t.truthy(text:find("Unknown dump target", 1, true), "names the bad target")
    t.truthy(text:find("dump targets", 1, true), "and prints the list")
end)

test("/cm dump <itemID> is a shortcut for the item target", function(t)
    local KCM, mock = load()
    mock.setItem(960010, { name = "Shortcut Snack", subType = "Food & Drink", tt = { healValue = 10 } })
    local text = say(KCM, mock, "dump 960010")
    t.truthy(text:find("960010", 1, true), "a bare numeric argument dumps that item")
end)

test("/cm dump bags lists each owned itemID and its count", function(t)
    local KCM, mock = load()
    mock.setBag(960015, 4)
    local text = say(KCM, mock, "dump bags")
    t.truthy(text:find("960015 x 4", 1, true), "the scanned tally is rendered as id x count")
end)

test("/cm dump pick on a composite renders the assembled macro body", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump pick hp_aio")
    t.truthy(text:find("In Combat", 1, true), "sections are rendered")
    t.truthy(text:find("empty-state stub", 1, true) or text:find("macro body", 1, true),
        "and either the body or the empty-state explanation is shown")
end)

test("/cm dump statpriority prints the current spec's resolved stats", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump statpriority")
    t.truthy(#text > 0, "the target produces output")
end)

-- The dump targets below are section-level characterization: `item` and `pick`
-- are the two biggest report builders in the addon, and each assembles several
-- independent blocks in a fixed ORDER. These pin every block and that order, so
-- a split into per-block printers cannot silently drop or reshuffle one.

test("/cm dump item without an itemID prints its usage line", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump item")
    t.truthy(text:find("usage: /cm dump item <itemID>", 1, true), "the usage line names the argument")
end)

-- The whole report for a hydrated item, in order: header, instant info,
-- classification, usability, raw lines. Driving the REAL TooltipCache off a
-- stubbed C_TooltipInfo is what makes the non-pending arm reachable at all.
test("/cm dump item reports header, instant info, classification and usability in that order", function(t)
    local KCM, mock = load()
    mock.setItem(960031, { name = "Char Snack", subType = "Potions" })
    local saved = _G.C_TooltipInfo
    _G.C_TooltipInfo = {
        GetItemByID = function()
            return { lines = { { leftText = "Char Snack" }, { leftText = "Restores 100 health." } } }
        end,
    }
    KCM.TooltipCache.InvalidateAll()
    local text = say(KCM, mock, "dump item 960031")
    _G.C_TooltipInfo = saved
    local header     = text:find("item 960031  (Char Snack)", 1, true)
    local instant    = text:find('instant: type="Consumable"  subType="Potions"  classID=0  subClassID=1', 1, true)
    local classified = text:find("classified: HP_POT", 1, true)
    local usable     = text:find("usable: yes  (minLevel=0, you=80)", 1, true)
    local raw        = text:find("raw tooltip lines (2)", 1, true)
    t.truthy(header, "header carries the resolved name")
    t.truthy(instant, "the GetItemInfoInstant block is rendered")
    t.truthy(classified, "the Classifier's matches are rendered")
    t.truthy(usable, "the usability verdict is rendered")
    t.truthy(raw, "the raw tooltip lines are rendered")
    t.truthy(header < instant and instant < classified and classified < usable and usable < raw,
        "and the five blocks come out in that order")
end)

test("/cm dump item on an unclassifiable item says (none) in red", function(t)
    local KCM, mock = load()
    mock.setItem(960035, { name = "Mystery Thing", subType = "Other" })
    local text = say(KCM, mock, "dump item 960035")
    t.truthy(text:find("classified: |cffff4444(none)|r", 1, true), "no category match is called out")
end)

test("/cm dump item on a pending tooltip says pending and asks no usability question", function(t)
    local KCM, mock = load()
    mock.setItem(960032, { name = "Not Loaded Yet", subType = "Potions", pending = true })
    local text = say(KCM, mock, "dump item 960032")
    t.truthy(text:find("pending: tooltip data not yet loaded", 1, true), "the load race is reported")
    t.falsy(text:find("usable:", 1, true),
        "and IsUsableByPlayer is never consulted — its answer would be wrong while pending")
end)

test("/cm dump item renders every raw tooltip line, splitting left from right", function(t)
    local KCM, mock = load()
    mock.setItem(960034, { name = "Two Column", subType = "Potions", tt = {} })
    local saved = _G.C_TooltipInfo
    _G.C_TooltipInfo = {
        GetItemByID = function()
            return { lines = { { leftText = "Two Column" }, { leftText = "Level", rightText = "80" } } }
        end,
    }
    local text = say(KCM, mock, "dump item 960034")
    _G.C_TooltipInfo = saved
    t.truthy(text:find("raw tooltip lines (2)", 1, true), "the line count heads the block")
    t.truthy(text:find('[ 1] "Two Column"', 1, true), "a left-only line renders bare")
    t.truthy(text:find('[ 2] L="Level"  R="80"', 1, true), "a two-column line renders L= / R=")
end)

test("/cm dump pick without a category prints usage and the known keys", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump pick")
    t.truthy(text:find("usage: /cm dump pick <catKey>", 1, true), "the usage line names the argument")
    t.truthy(text:find("known: ", 1, true), "and the known keys follow it")
    t.truthy(text:find("food", 1, true), "lower-cased, e.g. food")
end)

test("/cm dump pick on an unknown category names the bad key", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "dump pick frobnicate")
    t.truthy(text:find("unknown category: |cffffff00frobnicate|r", 1, true), "echoes what was typed")
end)

test("/cm dump pick on a composite renders both sections with on/off tags", function(t)
    local KCM, mock = load()
    KCM:OnSlashCommand("aio hp_aio toggle HS off")
    local text = say(KCM, mock, "dump pick hp_aio")
    t.truthy(text:find("HP_AIO (composite)", 1, true), "the composite header")
    t.truthy(text:find("  In Combat", 1, true), "the In Combat section")
    t.truthy(text:find("  Out of Combat", 1, true), "the Out of Combat section")
    t.truthy(text:find("|cff888888[off]|r HS -> ", 1, true), "a disabled ref carries the gray [off] tag")
    t.truthy(text:find("|cff44ff44[on]|r  HP_POT -> ", 1, true), "an enabled one the green [on] tag")
    t.truthy(text:find("(no pick)", 1, true), "and a ref with nothing owned resolves to (no pick)")
end)

test("/cm dump pick on a spec-aware category prints the spec context first", function(t)
    local KCM, mock = load()
    local _, _, specKey, specName = KCM.SpecHelper.GetCurrent()
    local text = say(KCM, mock, "dump pick flask")
    t.truthy(text:find(("FLASK for spec %s (%s)"):format(specName or "?", specKey), 1, true),
        "the spec line heads the report")
    t.truthy(text:find("  primary=", 1, true), "with the resolved stat priority under it")
    t.truthy(text:find("effective priority", 1, true), "and the priority rows after that")
end)

-- ---------------------------------------------------------------------------
-- /cm resync, rewritemacros, debug
-- ---------------------------------------------------------------------------

test("/cm resync rediscovers, recomputes, and reports the count", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "resync")
    t.truthy(text:match("auto%-discovery found %d+ new item%(s%)"),
        "reports how many new items the discovery pass found")
    t.truthy(text:find("recomputed all categories", 1, true), "and that macros were rebuilt")
end)

test("/cm resync warns that macro writes are deferred while in combat", function(t)
    local KCM, mock = load()
    mock.setCombat(true)
    local text = say(KCM, mock, "resync")
    t.truthy(text:find("in combat", 1, true), "the user is told the writes will land after combat")
end)

test("/cm resync drops cached tooltip parses first", function(t)
    local KCM = load()
    local invalidated = 0
    KCM.TooltipCache.InvalidateAll = function() invalidated = invalidated + 1 end
    KCM:OnSlashCommand("resync")
    t.eq(invalidated, 1, "stale parses cannot survive an explicit resync")
end)

test("/cm rewritemacros clears the fingerprint cache before recomputing", function(t)
    local KCM, mock = load()
    mock.setItem(960021, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(960021, 1)
    KCM.Pipeline.RunAutoDiscovery("test")
    KCM.Pipeline.Recompute("test")
    t.truthy(next(KCM.db.profile.macroState), "a macro fingerprint exists")

    local order = {}
    local realInvalidate = KCM.MacroManager.InvalidateState
    KCM.MacroManager.InvalidateState = function() order[#order + 1] = "invalidate"; realInvalidate() end
    local realRecompute = KCM.Pipeline.Recompute
    KCM.Pipeline.Recompute = function(r) order[#order + 1] = "recompute"; realRecompute(r) end
    say(KCM, mock, "rewritemacros")
    KCM.MacroManager.InvalidateState = realInvalidate
    KCM.Pipeline.Recompute = realRecompute

    t.eqList(order, { "invalidate", "recompute" },
        "the cache is dropped first, otherwise the recompute would report 'unchanged'")
end)

test("/cm debug on and off drive the logging flag through the DebugLog seam", function(t)
    local KCM = load()
    KCM:OnSlashCommand("debug on")
    t.eq(KCM.DebugLog.IsEnabled(), true, "logging armed")
    KCM:OnSlashCommand("debug off")
    t.eq(KCM.DebugLog.IsEnabled(), false, "logging disarmed")
end)

test("/cm debug with no argument toggles the window and leaves the flag alone", function(t)
    local KCM = load()
    local toggles = 0
    KCM.DebugLog.Toggle_Window = function() toggles = toggles + 1 end
    KCM:OnSlashCommand("debug on")
    KCM:OnSlashCommand("debug")
    t.eq(toggles, 1, "the window was toggled")
    t.eq(KCM.DebugLog.IsEnabled(), true,
        "capture stays armed independently of window visibility (debug-logging-§5)")
end)

-- ---------------------------------------------------------------------------
-- /cm get / set / list
-- ---------------------------------------------------------------------------

test("/cm set reports an unknown setting path", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "set no.such.path true")
    t.truthy(#text > 0, "the user gets feedback rather than silence")
    t.falsy(text:find("|cffffff00no.such.path|r = ", 1, true), "and no value is echoed as if it were set")
end)

test("/cm get reports an unknown setting path", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "get no.such.path")
    t.truthy(#text > 0, "unknown paths produce a message")
end)

test("/cm set rejects a non-boolean value for a bool setting", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "set enabled maybe")
    t.eq(KCM.db.profile.enabled, true, "the setting is untouched")
    t.truthy(#text > 0, "and the rejection is reported")
end)

-- Numeric dropdowns (review 2026-05-02, F-021/LLD-19). The schema ships no
-- numeric `values` row today, so these tests synthesize one on an existing
-- number row to pin the behavior before the first real one lands.
local function asNumericDropdown(KCM, path, values)
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.path == path then
            row.values = {}
            for i, v in ipairs(values) do row.values[i] = { value = v, text = tostring(v) } end
            return row
        end
    end
    error("no schema row for " .. path)
end

test("/cm set on a numeric dropdown accepts a listed value as a number", function(t)
    local KCM, mock = load()
    asNumericDropdown(KCM, "macroBar.perRow", { 1, 4, 13 })
    say(KCM, mock, "set macroBar.perRow 4")
    t.eq(KCM.db.profile.macroBar.perRow, 4, "the listed value is stored as a number, not a string")
end)

test("/cm set on a numeric dropdown rejects a value outside the list", function(t)
    local KCM, mock = load()
    asNumericDropdown(KCM, "macroBar.perRow", { 1, 4, 13 })
    local before = KCM.db.profile.macroBar.perRow
    local text = say(KCM, mock, "set macroBar.perRow 7")
    t.eq(KCM.db.profile.macroBar.perRow, before, "an unlisted value is not written")
    t.truthy(text:lower():find("allowed values", 1, true), "and the allowed list is reported")
    t.truthy(text:find("1, 4, 13", 1, true), "with the numeric entries rendered readably")
end)

test("/cm set on a plain number row still clamps to min/max", function(t)
    local KCM, mock = load()
    say(KCM, mock, "set macroBar.perRow 999")
    -- perRow's max is derived from #KCM.Categories.LIST (settings/MacroBar.lua),
    -- not a literal, so this clamps to whatever the category count is today.
    t.eq(KCM.db.profile.macroBar.perRow, #KCM.Categories.LIST,
        "no values list means clamping, not rejection")
end)

test("/cm set on a string dropdown still matches by text", function(t)
    local KCM, mock = load()
    say(KCM, mock, "set macroBar.orientation VERTICAL")
    t.eq(KCM.db.profile.macroBar.orientation, "VERTICAL", "a listed string value is accepted")
    local text = say(KCM, mock, "set macroBar.orientation SIDEWAYS")
    t.eq(KCM.db.profile.macroBar.orientation, "VERTICAL", "an unlisted string value is rejected")
    t.truthy(text:lower():find("allowed values", 1, true), "and the allowed list is reported")
end)

test("/cm list covers every row in the settings schema", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "list")
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(text:find(row.path, 1, true), "schema row '" .. row.path .. "' appears in /cm list")
    end
end)
