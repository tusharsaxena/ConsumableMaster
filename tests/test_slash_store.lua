-- test_slash_store.lua — the /cm verbs held to what they leave in the store:
-- the #35 characterization of the /cm stat and /cm aio writers, the list-shaped
-- rows /cm get|set|list|reset reach through the schema, the macro bar's
-- /cm lock and /cm unlock, the /cm enable and /cm disable aliases, and the
-- disabled state's feature-verb refusal (slash-commands-§2).
--
-- Peeled out of tests/test_slash.lua (1426) for layout-§1's 1000-1500 band
-- (CM-ATS-02, ATS-14), on the seam the file already drew: every section from
-- the #35 characterization down asserts a STORED value or a written path, not
-- only the chat line, while what stays in tests/test_slash.lua is the dispatcher
-- and each namespace's parsing and replies. Every case moved whole: not one
-- assertion changed, and the two files together register exactly the cases the
-- one did. `load`, `say` and `effectiveSet` are the same three-line wrappers
-- tests/test_slash.lua keeps, stated again rather than shared.

local h = _G.KCM_TEST
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

-- ---------------------------------------------------------------------------
-- #35 characterization: what the /cm stat and /cm aio writers leave behind
-- ---------------------------------------------------------------------------
--
-- Written against the direct field writes BEFORE they moved onto the schema
-- helper, so the move is held to the stored shape each verb always produced.

local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

test("/cm stat primary, secondary and reset leave exactly the stored map they always did", function(t)
    local KCM = load()
    local other = { primary = "INT", secondary = { "MASTERY" } }
    KCM.db.profile.statPriority = { ["8_262"] = CopyTable(other) }
    local seed = KCM.SpecHelper.GetStatPriority("7_263")

    KCM:OnSlashCommand("stat primary AGI")
    t.eq(ser(KCM.db.profile.statPriority),
        ser({ ["8_262"] = other, ["7_263"] = { primary = "AGI", secondary = seed.secondary or {} } }),
        "primary: the current spec gains an override carrying its resolved secondaries")

    KCM:OnSlashCommand("stat secondary HASTE,CRIT,HASTE")
    t.eq(ser(KCM.db.profile.statPriority),
        ser({ ["8_262"] = other, ["7_263"] = { primary = "AGI", secondary = { "HASTE", "CRIT" } } }),
        "secondary: the ordered, deduplicated list, the primary kept")

    KCM:OnSlashCommand("stat reset")
    t.eq(ser(KCM.db.profile.statPriority), ser({ ["8_262"] = other }),
        "reset: the current spec's override is gone and no other spec's is touched")
end)

test("/cm aio toggle, down and reset leave exactly the stored sections they always did", function(t)
    local KCM = load()
    local cfg = KCM.db.profile.categories.HP_AIO
    local d = KCM.dbDefaults.profile.categories.HP_AIO

    KCM:OnSlashCommand("aio hp_aio toggle HP_POT off")
    t.eq(ser(cfg.enabled), ser({ HS = true, HP_POT = false, FOOD = true }), "toggle writes one flag")
    KCM:OnSlashCommand("aio hp_aio down HS")
    t.eq(ser(cfg.orderInCombat), ser({ "HP_POT", "HS" }), "down swaps within the section")
    t.eq(ser(cfg.orderOutOfCombat), ser(d.orderOutOfCombat), "and leaves the other section alone")

    KCM:OnSlashCommand("aio hp_aio reset")
    for _, f in ipairs({ "enabled", "orderInCombat", "orderOutOfCombat" }) do
        t.eq(ser(cfg[f]), ser(d[f]), "reset restores " .. f)
        t.falsy(cfg[f] == d[f], f .. " comes back as a copy of the defaults")
    end
end)

-- ---------------------------------------------------------------------------
-- #35: the list-shaped settings are rows, so /cm get|set|list|reset reach them
-- ---------------------------------------------------------------------------

-- Every path the write seam is asked to write (tests/run.lua's spy).
local function recordSets(KCM)
    return (h.loader.spySeamWrites(KCM))
end

test("/cm get and list render the list-shaped rows as text, never a table address", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "get macroBar.order")
    t.truthy(text:find("FOOD, DRINK", 1, true), "the slot order reads as a list: " .. text)
    text = say(KCM, mock, "get categories.HP_AIO.enabled")
    t.truthy(text:find("HS=true", 1, true), "a flag map reads key=value: " .. text)
    KCM:OnSlashCommand("stat primary AGI")
    text = say(KCM, mock, "get statPriority")
    t.truthy(text:find("7_263", 1, true) and text:find("AGI", 1, true),
        "a stat override reads by spec: " .. text)
    text = say(KCM, mock, "list")
    t.falsy(text:find("table: ", 1, true), "no row in /cm list renders as a table address")
    t.truthy(text:find("categories.BATTLE_REZ.mouseover", 1, true), "and mouseover is listed")
end)

test("/cm set and reset reach the slot order, a flag map and mouseover", function(t)
    local KCM, mock = load()
    local c = KCM.db.profile.macroBar
    KCM:OnSlashCommand("set macroBar.order drink,food")
    t.eq(c.order[1], "DRINK", "the named slots lead, case-folded")
    t.eq(c.order[2], "FOOD", "in the order given")
    t.eq(#c.order, #KCM.Categories.LIST, "and every other slot follows, so none is lost")
    KCM:OnSlashCommand("set macroBar.shown FOOD=off")
    t.eq(ser(c.shown), "{FOOD=false}", "a flag map is written whole from key=value pairs")
    KCM:OnSlashCommand("set categories.BATTLE_REZ.mouseover off")
    t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, false, "mouseover is an ordinary bool row")
    KCM:OnSlashCommand("reset categories.BATTLE_REZ.mouseover")
    t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, true, "and resets to its default")
    KCM:OnSlashCommand("reset macroBar.order")
    t.eq(ser(c.order), ser(KCM.dbDefaults.profile.macroBar.order), "the order resets")
    t.falsy(c.order == KCM.dbDefaults.profile.macroBar.order,
        "to a copy of the default, never the defaults' own table")
    local text = say(KCM, mock, "set statPriority AGI")
    t.truthy(text:find("/cm stat", 1, true),
        "stat priority is edited by /cm stat, and the refusal says so: " .. text)
end)

-- red under: the order parse handing the validator the named keys alone, which
-- then appends the rest in category-list order and moves the AIO slots to the end.
test("/cm set on an order keeps every unnamed key in its current stored order", function(t)
    local KCM = load()
    local c = KCM.db.profile.macroBar
    local function without(list, drop)
        local out = {}
        for _, k in ipairs(list) do if not drop[k] then out[#out + 1] = k end end
        return out
    end
    local before = {}
    for i, k in ipairs(c.order) do before[i] = k end
    KCM:OnSlashCommand("set macroBar.order DRINK,FOOD")
    local want = { "DRINK", "FOOD" }
    for _, k in ipairs(without(before, { DRINK = true, FOOD = true })) do want[#want + 1] = k end
    t.eqList(c.order, want, "the named slots lead and the rest keep the shipped order")

    -- A customized stored order: the tail follows IT, not the member set.
    local custom = {}
    for i = #before, 1, -1 do custom[#custom + 1] = before[i] end
    KCM.Schema:Set("macroBar.order", custom)
    KCM:OnSlashCommand("set macroBar.order hs")
    want = { "HS" }
    for _, k in ipairs(without(custom, { HS = true })) do want[#want + 1] = k end
    t.eqList(c.order, want, "the rest keep the player's own stored order")

    -- The AIO sections take the same rule. Two members a section cannot show
    -- the tail's order, so the test pins that the parse reads the stored value.
    local H, gets, realGet = KCM.Settings.Helpers, {}, KCM.Settings.Helpers.Get
    H.Get = function(path) gets[path] = true; return realGet(path) end
    KCM:OnSlashCommand("set categories.HP_AIO.orderInCombat hp_pot")
    KCM:OnSlashCommand("set categories.HP_AIO.orderOutOfCombat food")
    H.Get = realGet
    t.truthy(gets["categories.HP_AIO.orderInCombat"], "the in-combat order parse reads the stored order")
    t.truthy(gets["categories.HP_AIO.orderOutOfCombat"], "and so does the out-of-combat one")
    t.eqList(KCM.db.profile.categories.HP_AIO.orderInCombat, { "HP_POT", "HS" },
        "and the section is written with the named key first")
end)

-- red under: the flag-map parse answering only the pairs given, which the
-- whole-value write then stores as the entire map, un-hiding every other slot.
test("/cm set on a flag map merges the pairs given over the stored map", function(t)
    local KCM = load()
    local c = KCM.db.profile.macroBar
    KCM.Schema:Set("macroBar.shown", { DRINK = false })
    KCM:OnSlashCommand("set macroBar.shown FOOD=off")
    t.eq(ser(c.shown), "{DRINK=false,FOOD=false}", "a hidden slot stays hidden")
    KCM:OnSlashCommand("set macroBar.shown drink=on")
    t.eq(ser(c.shown), "{DRINK=true,FOOD=false}", "and one pair changes only its own key")

    local aio = KCM.db.profile.categories.HP_AIO
    KCM:OnSlashCommand("aio hp_aio toggle HS off")
    KCM:OnSlashCommand("set categories.HP_AIO.enabled HP_POT=off")
    t.eq(ser(aio.enabled), ser({ HS = false, HP_POT = false, FOOD = true }),
        "a composite's enabled map keeps the flags nobody named")
end)

-- red under: any of these verbs writing its field directly again.
test("every /cm stat and /cm aio write goes through the schema helper", function(t)
    local KCM = load()
    local paths = recordSets(KCM)
    KCM:OnSlashCommand("stat primary AGI")
    KCM:OnSlashCommand("stat secondary CRIT")
    KCM:OnSlashCommand("stat reset")
    KCM:OnSlashCommand("aio hp_aio toggle HS off")
    KCM:OnSlashCommand("aio hp_aio down HS")
    KCM:OnSlashCommand("aio hp_aio reset")
    t.eqList(paths, {
        "statPriority", "statPriority", "statPriority",
        "categories.HP_AIO.enabled", "categories.HP_AIO.orderInCombat",
        "categories.HP_AIO.enabled", "categories.HP_AIO.orderInCombat",
        "categories.HP_AIO.orderOutOfCombat",
    }, "one helper write per verb, and the section reset writes its three rows")
end)

-- ---------------------------------------------------------------------------
-- `/cm lock` and `/cm unlock` — the macro bar's own verbs
-- ---------------------------------------------------------------------------
--
-- The lock was reachable only as `/cm bar unlock`, and `/cm unlock` — which is
-- what the collection's other addons answer to, and what a player types — fell
-- through findCommand's exact match to "unknown command". These assert the
-- STORED FLAG rather than the printed line, because a handler that says "macro
-- bar unlocked" and writes nothing prints exactly the same thing.

test("/cm unlock and /cm lock write the macro bar's stored lock flag", function(t)
    local KCM = load()
    KCM:OnSlashCommand("set macroBar.locked true")
    t.eq(KCM.db.profile.macroBar.locked, true, "precondition: the bar starts locked")
    KCM:OnSlashCommand("unlock")
    t.eq(KCM.db.profile.macroBar.locked, false, "/cm unlock clears the flag")
    KCM:OnSlashCommand("lock")
    t.eq(KCM.db.profile.macroBar.locked, true, "/cm lock sets it again")
end)

test("/cm bar lock and /cm bar unlock land on the same stored flag", function(t)
    local KCM = load()
    KCM:OnSlashCommand("bar unlock")
    t.eq(KCM.db.profile.macroBar.locked, false, "the sub-verb still unlocks")
    KCM:OnSlashCommand("bar lock")
    t.eq(KCM.db.profile.macroBar.locked, true, "the sub-verb still locks")
end)

-- Unlocking a bar that is switched OFF still writes the flag -- the player may be
-- about to turn it on and wants it draggable when it appears -- but "drag it" is
-- a promise about a bar they cannot see. So the line says the bar is off and how
-- to show it, and both spellings share the one body, so they say the same thing
-- (ConsumableMaster-R-11).
local OFF_UNLOCK = "macro bar unlocked (the bar is off \226\128\148 /cm bar on to show it)"

test("/cm unlock on a switched-off bar says the bar is off", function(t)
    local KCM, mock = load()
    KCM.Settings.Helpers.SetAndRefresh("macroBar.enabled", false)
    KCM.Settings.Helpers.SetAndRefresh("macroBar.locked", true)
    local line = say(KCM, mock, "unlock")
    t.eq(KCM.db.profile.macroBar.locked, false, "the write still lands")
    t.truthy(line:find(OFF_UNLOCK, 1, true) ~= nil, "and it says the bar is off: " .. line)
    t.truthy(line:find("drag it", 1, true) == nil, "and never asks for a drag: " .. line)
end)

test("/cm bar unlock on a switched-off bar says the same line", function(t)
    local KCM, mock = load()
    KCM.Settings.Helpers.SetAndRefresh("macroBar.enabled", false)
    local line = say(KCM, mock, "bar unlock")
    t.eq(KCM.db.profile.macroBar.locked, false, "the sub-verb still unlocks")
    t.truthy(line:find(OFF_UNLOCK, 1, true) ~= nil, "one body, one wording: " .. line)
end)

test("/cm unlock on a shown bar keeps the drag wording", function(t)
    local KCM, mock = load()
    KCM.Settings.Helpers.SetAndRefresh("macroBar.enabled", true)
    local line = say(KCM, mock, "unlock")
    t.truthy(line:find("macro bar unlocked \226\128\148 drag it, then /cm lock", 1, true) ~= nil,
        "a visible bar is still told to drag: " .. line)
    line = say(KCM, mock, "lock")
    t.truthy(line:find("macro bar locked", 1, true) ~= nil, "and lock is unchanged: " .. line)
end)

-- A bare `/cm bar` is the player's own switch, so it flips the STORED flag. It
-- used to flip MacroBarModel.IsEnabled(), which also answers false under any
-- stand-down hold -- a perf capture's suspended arm included -- so during a
-- capture a bar that was on read as off and every bare `/cm bar` wrote true.
test("bare /cm bar toggles the stored flag during a perf hold", function(t)
    local KCM, mock = load()
    KCM.Settings.Helpers.SetAndRefresh("macroBar.enabled", true)
    KCM.Perf.Suspend()
    t.falsy(KCM.MacroBarModel.IsEnabled(), "precondition: the hold makes IsEnabled answer false")

    local line = say(KCM, mock, "bar")
    t.eq(KCM.db.profile.macroBar.enabled, false, "the first bare /cm bar turns the stored flag off")
    t.truthy(line:find("OFF", 1, true) ~= nil, "and says OFF: " .. line)

    line = say(KCM, mock, "bar")
    t.eq(KCM.db.profile.macroBar.enabled, true, "the second turns it back on")
    t.truthy(line:find("ON", 1, true) ~= nil, "and says ON: " .. line)
    KCM.Perf.Resume()
end)

test("/cm lock and /cm unlock write through the schema helper, not the table", function(t)
    local KCM = load()
    local paths = recordSets(KCM)
    KCM:OnSlashCommand("unlock")
    KCM:OnSlashCommand("lock")
    KCM:OnSlashCommand("bar unlock")
    t.eqList(paths, { "macroBar.locked", "macroBar.locked", "macroBar.locked" },
        "every route is one helper write to the one row")
end)

test("/cm lock and /cm unlock are in the published command table", function(t)
    local KCM = load()
    local seen = {}
    for _, entry in ipairs(KCM.COMMANDS) do seen[entry[1]] = true end
    t.truthy(seen.lock, "lock is a verb /cm help renders")
    t.truthy(seen.unlock, "unlock is a verb /cm help renders")
end)

-- ---------------------------------------------------------------------------
-- `/cm enable` and `/cm disable` — aliases, never a second switch
-- ---------------------------------------------------------------------------

test("Slash: enable / disable write the Enable row's own path", function(t)
    local KCM = load()

    local writes = {}
    local H = KCM.Settings.Helpers
    local realSet = H.SetAndRefresh
    H.SetAndRefresh = function(path, value)
        writes[#writes + 1] = path .. "=" .. tostring(value)
        return realSet(path, value)
    end

    KCM:OnSlashCommand("disable")
    t.eq(KCM.db.profile.enabled, false, "the addon is off")
    KCM:OnSlashCommand("enable")
    t.eq(KCM.db.profile.enabled, true, "and back on")
    t.eqList(writes, { "enabled=false", "enabled=true" },
        "both verbs wrote the Master controls row's path through its seam")

    H.SetAndRefresh = realSet
end)

test("Slash: enable / disable hold no state of their own", function(t)
    local KCM = load()
    local H = KCM.Settings.Helpers

    -- Flipped by the OTHER surface — the checkbox's seam — and the verbs must
    -- read it rather than a copy, or the panel and the chat line answer
    -- differently (slash-commands-§2).
    H.SetAndRefresh("enabled", false)
    t.eq(H.Get("enabled"), false, "the row reads off")
    KCM:OnSlashCommand("enable")
    t.eq(H.Get("enabled"), true, "and the verb moved that same row")
    t.eq(KCM.enabled, nil, "there is no second flag on the namespace")
end)

test("Slash: the dispatcher still answers while the addon is disabled", function(t)
    local KCM = load()
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)

    -- The switch must never be one-way (slash-commands-§2). Disabled means the
    -- addon stands its features down — here, the macro write loop early-returns
    -- — not that it drops its chat command or its COMMANDS table.
    t.truthy(say(KCM, h.loader.mock, "version"):find("v", 1, true) ~= nil,
        "version still answers")
    t.truthy(say(KCM, h.loader.mock, "help"):find("enable", 1, true) ~= nil,
        "help still lists the verb that turns it back on")
    KCM:OnSlashCommand("enable")
    t.eq(KCM.db.profile.enabled, true, "and enable turns it back on")
end)

test("Slash: enable echoes the stored value in the canonical set shape", function(t)
    local KCM = load()
    -- slash-commands-§5: a set reads back the STORED value after writing, through
    -- the one formatter list / get / set / reset share, so `/cm enable` and
    -- `/cm set enabled true` cannot print two different things for one write.
    -- The verb's own line is the LAST one it prints: the row's onChange announces
    -- the master switch first (settings/General.lua), exactly as it does when the
    -- checkbox is clicked.
    local function lastLine(line) return (say(KCM, h.loader.mock, line):match("[^\n]*$")) end
    local viaVerb = lastLine("disable")
    KCM.Settings.Helpers.SetAndRefresh("enabled", true)
    local viaSet = lastLine("set enabled false")
    t.truthy(viaVerb:find("enabled", 1, true) ~= nil, "the verb names the path: " .. viaVerb)
    t.truthy(viaVerb:find("false", 1, true) ~= nil, "and the value it stored")
    t.eq(viaVerb, viaSet, "the long name prints the very same line")
end)

-- ---------------------------------------------------------------------------
-- The disabled state: a feature verb refuses (slash-commands-§2)
-- ---------------------------------------------------------------------------
--
-- EVERY CASE HERE ASSERTS BOTH HALVES -- that the verb said so AND that it did
-- not act. A case that only reads the chat line passes over a verb that printed
-- the refusal and then did the thing anyway, which is the one failure mode worth
-- having these at all for: the no-op this rule replaces was already silent (the
-- macro write pass early-returns on `enabled`), so a half-checked gate would look
-- exactly like the bug.

-- The refusal VERBATIM, not a substring of it: `/cm help` prints the `disable`
-- row, whose description also names `/cm enable`, so a loose match would call the
-- help index a refusal and the sweep below would report the live set as gated.
--
-- TAKEN FROM THE LIBRARY'S OWN BUILDER rather than typed here. The wording is the
-- COLLECTION's (slash-commands-§7), fixed in one place and forbidden to be
-- re-spelled per addon, so a literal in this file would be a second copy of it --
-- and the first thing to go stale the day the shape moves. What this suite is
-- for is that the addon REFUSES and does not act; which sentence it refuses with
-- is the library's business and tests/test_disabled.lua is where the shape itself
-- is pinned.
local function refusalLine(KCM)
    local Sl = KCM.SlashCommands and KCM.SlashCommands.instance
    return Sl and Sl:DisabledLine() or "<no dispatcher>"
end

test("Slash: a disabled addon refuses a feature verb and does not act on it", function(t)
    local KCM, mock = load()
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)

    local before = effectiveSet(KCM, "FOOD")[987654]
    local line = say(KCM, mock, "priority food add 987654")
    t.truthy(line:find(refusalLine(KCM), 1, true) ~= nil, "it refuses, in the shape the collection uses: " .. line)
    t.eq(effectiveSet(KCM, "FOOD")[987654], before, "and the item was NOT added")
    -- One line, nothing else (slash-commands-§2): no partial work, no second line.
    t.eq(select(2, line:gsub("\n", "")), 0, "one line and no more")
end)

test("Slash: a disabled addon refuses the macro-bar verb without touching the bar", function(t)
    local KCM, mock = load()
    local H = KCM.Settings.Helpers
    H.SetAndRefresh("macroBar.enabled", false)
    H.SetAndRefresh("enabled", false)

    local line = say(KCM, mock, "bar on")
    t.truthy(line:find(refusalLine(KCM), 1, true) ~= nil, "it refuses: " .. line)
    t.eq(KCM.db.profile.macroBar.enabled, false, "and the bar stayed off")
end)

test("Slash: a disabled addon refuses resync rather than reporting a pass that wrote nothing",
    function(t)
        local KCM, mock = load()
        -- The case for the rule, in one assertion. `macrosEnabled()` already gates
        -- the macro write loop, so before this gate `/cm resync` ran the pipeline
        -- and then announced "recomputed all categories." over a pass that wrote
        -- no macro at all.
        local ran = 0
        local realRecompute = KCM.Pipeline.Recompute
        KCM.Pipeline.Recompute = function(...) ran = ran + 1; return realRecompute(...) end
        KCM.Settings.Helpers.SetAndRefresh("enabled", false)

        local line = say(KCM, mock, "resync")
        KCM.Pipeline.Recompute = realRecompute
        t.truthy(line:find(refusalLine(KCM), 1, true) ~= nil, "it refuses: " .. line)
        t.eq(ran, 0, "and the pipeline never ran")
        t.eq(line:find("recomputed", 1, true), nil, "nothing claims a recompute happened")
    end)

-- red under: a guard pasted into some verb bodies and not others, which is what
-- the table-level wrap exists to make impossible. The list is DERIVED from
-- KCM.COMMANDS rather than typed, so a verb added tomorrow is covered by this
-- case on the day it is declared.
test("Slash: every verb outside the live set refuses while disabled, and every live one answers",
    function(t)
        local KCM, mock = load()
        -- slash-commands-§2's live set, verbatim, plus this addon's read-only
        -- `dump` -- a diagnostic like `debug` and `perf`, writing nothing.
        -- `diagnostics` joined the set with Slash minor 16 (debug-logging-§14).
        local LIVE = {
            help = true, config = true, version = true, enable = true, disable = true,
            debug = true, perf = true, diagnostics = true,
            get = true, set = true, list = true, reset = true, resetall = true,
            dump = true,
        }
        local refused, answered = {}, {}
        for _, entry in ipairs(KCM.COMMANDS) do
            KCM.Settings.Helpers.SetAndRefresh("enabled", false)
            local line = say(KCM, mock, entry[1])
            -- EXACTLY ONE LINE, not merely containing the sentence. `/cm help`
            -- prints the same line under its header and then the whole index
            -- (Slash minor 13), which is not a refusal OF help -- the player has
            -- to be able to SEE `enable` in the list -- so a containment test
            -- alone would file `help` as gated.
            local isRefusal = line:find(refusalLine(KCM), 1, true) ~= nil
                and select(2, line:gsub("\n", "")) == 0
            if isRefusal then refused[#refused + 1] = entry[1]
            else answered[#answered + 1] = entry[1] end
        end
        for _, name in ipairs(refused) do
            t.falsy(LIVE[name], "'" .. name .. "' is a feature verb and refuses")
        end
        for _, name in ipairs(answered) do
            t.truthy(LIVE[name], "'" .. name .. "' is on the live list and still answers")
        end
        t.eq(#refused + #answered, #KCM.COMMANDS, "every verb was driven")
        t.truthy(#refused > 0, "and the gate is actually on")
    end)

test("Slash: enable itself still works while disabled, or the pair is one-way", function(t)
    local KCM = load()
    local H = KCM.Settings.Helpers
    H.SetAndRefresh("enabled", false)
    KCM:OnSlashCommand("enable")
    t.eq(H.Get("enabled"), true, "the one verb that must never refuse turned it back on")
end)

test("Slash: with LibKa0s absent there is no refusal to print, and the verb acts", function(t)
    -- THE DEGRADED ARM DOES NOT REFUSE, and that is a decision rather than a gap.
    --
    -- The gate is the dispatcher library's from Slash minor 13, and so is the
    -- refusal line: slash-commands-§7 fixes ONE shape collection-wide and says it
    -- MUST NOT be re-spelled per addon, per verb or per call site. With
    -- libs/LibKa0s/ absent there is no builder to call and no format string to
    -- read, so the only way to refuse here would be to hand-copy the sentence --
    -- which is precisely the drift the one-place rule exists to stop, and it would
    -- be a copy that only ever ran on a tampered install.
    --
    -- Nothing is owed. The feature-verb refusal is slash-commands-§2's SHOULD, an addon that
    -- declines it is not deviating and owes no register row, and this build has
    -- already told the player on its own line that half the surface is missing.
    -- The stand-down is a MUST and is NOT what is skipped here: that arm has no
    -- LibKa0s-Lifecycle-1.0 either, so a build with no library keeps the old
    -- stored-flag behavior in full -- it is a tampered install, not a supported
    -- state (see tests/test_disabled.lua, which runs against the live arm).
    local KCM = h.loader.loadFullAddon(true)
    KCM.Settings.Helpers.Set("enabled", false)
    local line = say(KCM, h.loader.mock, "priority food add 987654")
    t.eq(line:find("is disabled", 1, true), nil, "no hand-copied refusal was printed: " .. line)
    t.truthy(effectiveSet(KCM, "FOOD")[987654], "and the verb acted, as it always did here")
end)
