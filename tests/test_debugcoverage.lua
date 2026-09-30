-- tests/test_debugcoverage.lua — what the debug log carries, and what it does not
-- (debug-logging-§8's diagnosis list, §9's quiet steady state).
--
-- The flows each have their own suite (test_events, test_macromanager,
-- test_pipeline, test_bulklog). This one pins the lines a support read of the
-- log leans on that no single flow owns: the addon's own stand-down edges, held
-- work and its flush, refusals naming their guard, errors caught once, the
-- dependency and stand-down clauses of [Init] -- and, from the other side, that
-- a repeating path whose summary did not move writes nothing.

local h = _G.KCM_TEST
local test = h.test

-- Record every KCM.Debug line as "[Tag] message", formatted as the sink formats
-- it (each argument stringified first). A pure load has no sink, so install
-- one; the full load's call sites reach KCM.Debug at call time too, so the same
-- recorder captures them. The quiet gate is reset so each case starts clean.
local function record(KCM)
    local lines = {}
    KCM.State = KCM.State or {}
    KCM.State.debug = true
    KCM.Debug = setmetatable({ IsOn = function() return true end }, {
        __call = function(_, tag, fmt, ...)
            local n = select("#", ...)
            local args = { ... }
            for i = 1, n do args[i] = tostring(args[i]) end
            lines[#lines + 1] = "[" .. tostring(tag) .. "] " .. tostring(fmt):format(unpack(args, 1, n))
        end,
    })
    KCM.DebugQuiet.Reset()
    return lines
end

local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function find(lines, needle)
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then return l end
    end
    return nil
end

local function ownFood(mock, id)
    mock.setItem(id, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(id, 1)
end

-- ---------------------------------------------------------------------------
-- The quiet gate itself
-- ---------------------------------------------------------------------------

test("DebugQuiet.Changed answers nil on a repeat and the unlogged count on the next change", function(t)
    local KCM = h.loader.loadPure()
    local Q = KCM.DebugQuiet
    Q.Reset()
    t.eq(Q.Changed("k", "a"), 0, "the first summary logs, with nothing unlogged before it")
    t.eq(Q.Changed("k", "a"), nil, "the same summary again does not")
    t.eq(Q.Changed("k", "a"), nil, "nor a third time")
    t.eq(Q.Changed("k", "b"), 2, "a change logs, and says two passes went unlogged")
    t.eq(Q.Suffix(2), " (after 2 unchanged pass(es))", "the suffix a change-gated line carries")
    t.eq(Q.Suffix(0), "", "and none when nothing was held back")
    Q.Forget("k")
    t.eq(Q.Changed("k", "b"), 0, "a forgotten key logs whatever it says next")
    t.truthy(Q.First("e"), "First is true the first time")
    t.falsy(Q.First("e"), "and false after")
end)

-- ---------------------------------------------------------------------------
-- Quiet steady state (debug-logging-§9)
-- ---------------------------------------------------------------------------

-- red under: traceScan / traceCalc logging every pass. Five bag updates that
-- change nothing were five [Scan] and five [Calc] lines, which a dungeon turns
-- into hundreds and which evict the lines that matter from the buffer.
test("repeated bag-update passes that change nothing log one [Scan] and one [Calc] line", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 950001)
    KCM.Pipeline.RunAutoDiscovery("setup")   -- discover it and write every macro once, logging off
    KCM.Pipeline.Recompute("setup")
    local lines = record(KCM)
    for _ = 1, 5 do
        KCM.Pipeline.RunAutoDiscovery("bag_update_delayed")
        KCM.Pipeline.Recompute("bag_update_delayed")
    end
    t.eq(count(lines, "[Scan] "), 1, "one [Scan] line for five identical passes")
    t.eq(count(lines, "[Calc] "), 1, "one [Calc] line for five no-write passes")

    -- A new item is a change, and the line that reports it says how many
    -- identical passes it follows.
    ownFood(mock, 950002)
    KCM.Pipeline.RunAutoDiscovery("bag_update_delayed")
    t.eq(count(lines, "[Scan] "), 2, "a pass that finds a new item is logged")
    t.truthy(find(lines, "(after 4 unchanged pass(es))"), "and names the passes left unlogged")
end)

test("a pass that writes, or a pass on an edge reason, always logs its [Calc] line", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 950003)
    local lines = record(KCM)
    KCM.Pipeline.Recompute("bag_update_delayed")     -- first pass writes every macro
    KCM.Pipeline.Recompute("spec_changed")           -- an edge, even with nothing to write
    KCM.Pipeline.Recompute("spec_changed")
    t.eq(count(lines, "[Calc] reason=bag_update_delayed rewrote"), 1, "the writing pass")
    t.eq(count(lines, "[Calc] reason=spec_changed"), 2, "each edge pass, unchanged or not")
end)

test("a gated line logs again after logging is switched off and back on", function(t)
    local KCM = h.loader.loadConsole()
    local DL = KCM.DebugLog
    local lines = record(KCM)
    KCM.Pipeline.RunAutoDiscovery("bag_update_delayed")
    KCM.Pipeline.RunAutoDiscovery("bag_update_delayed")
    t.eq(count(lines, "[Scan] "), 1, "the repeat is held back")
    DL.SetEnabled(false)
    DL.SetEnabled(true)
    KCM.Pipeline.RunAutoDiscovery("bag_update_delayed")
    -- red under: setEnabled not resetting KCM.DebugQuiet, so a fresh logging
    -- window hides the current state as "the same as an earlier window's line".
    t.eq(count(lines, "[Scan] "), 2, "a fresh logging window shows the current state")
    DL.SetEnabled(false)
end)

-- ---------------------------------------------------------------------------
-- Deferred work: held for combat, then flushed (debug-logging-§8)
-- ---------------------------------------------------------------------------

-- red under: the per-macro "deferred <macro> (combat)" line. A forced rewrite
-- in combat marks every macro stale, and the old line fired once per macro per
-- pass: fifteen lines at once, then fifteen more on every pass until regen.
test("a forced rewrite in combat is one held line, quiet on repeat, and a flush line at regen", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 950004)
    KCM.Pipeline.Recompute("setup")
    local total = #KCM.Categories.LIST
    local lines = record(KCM)

    mock.setCombat(true)
    KCM.MacroManager.MarkAllStale()
    KCM.Pipeline.Recompute("restriction_lifted")
    KCM.Pipeline.Recompute("bag_update_delayed")
    KCM.Pipeline.Recompute("bag_update_delayed")
    t.eq(count(lines, "deferred "), 0, "no per-macro deferral line")
    t.eq(count(lines, "[Macro] held "), 1, "one held line for three passes over the same queue")
    t.truthy(find(lines, ("[Macro] held %d write(s) for combat: "):format(total)),
        "naming how many writes wait")
    t.truthy(find(lines, ("[Calc] reason=restriction_lifted rewrote 0/%d (skipped 0, held %d)"):format(total, total)),
        "the pass's own line counts them as held, not as rewritten")

    mock.setCombat(false)
    KCM:OnRegenEnabled("PLAYER_REGEN_ENABLED")
    t.truthy(find(lines, ("flushed=%d held=0"):format(total)),
        "regen says how many it flushed and that none are left held")
end)

-- ---------------------------------------------------------------------------
-- Errors caught once per distinct error
-- ---------------------------------------------------------------------------

-- red under: runMacroPass logging its pcall's error on every pass.
test("a category whose recompute raises on every pass is one line per distinct error", function(t)
    local KCM = h.loader.loadPure()
    local real = KCM.Pipeline.RecomputeOne
    KCM.Pipeline.RecomputeOne = function(catKey, ...)
        if catKey == "FOOD" then error("scorer broke", 0) end
        return real(catKey, ...)
    end
    local lines = record(KCM)
    for _ = 1, 4 do KCM.Pipeline.Recompute("bag_update_delayed") end
    t.eq(count(lines, "FOOD recompute failed: scorer broke"), 1, "four passes, one line")
    KCM.Pipeline.RecomputeOne = real
end)

-- ---------------------------------------------------------------------------
-- The addon's own state edges and refusals
-- ---------------------------------------------------------------------------

-- red under: standDown / standUp writing no line. Without them a log shows the
-- addon going quiet with nothing to say why.
test("disable and enable each leave one [State] line naming the holds", function(t)
    local KCM = h.loader.loadPure()
    local lines = record(KCM)
    KCM.OnEnabledChanged(false)
    KCM.OnEnabledChanged(true)
    t.truthy(find(lines, "[State] stood down (holds: disabled)"), "the stand-down, and why")
    t.truthy(find(lines, "[State] stood up (holds: none)"), "and the stand-up")
    t.eq(count(lines, "[State] "), 2, "one line per edge")
end)

test("a stand-down in combat says its bar teardown is held, and regen says it finished", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local lines = record(KCM)
    mock.setCombat(true)
    KCM.OnEnabledChanged(false)
    mock.setCombat(false)
    KCM:OnRegenEnabled("PLAYER_REGEN_ENABLED")
    t.truthy(find(lines, "stood down (holds: disabled); bar teardown held for combat"), "the hold")
    t.truthy(find(lines, "stood down: held bar teardown finished"), "and its finish")
end)

-- red under: KCM.ResetAllToDefaults refusing silently in the log.
test("a reset refused in combat names the guard", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local lines = record(KCM)
    mock.setCombat(true)
    local ok = KCM.ResetAllToDefaults("test")
    mock.setCombat(false)
    t.falsy(ok, "refused")
    t.truthy(find(lines, "[Cmd] reset profile refused: in combat"), "and the log says why")
end)

test("a refused settings write names the rule, under [Cmd] and never [Set]", function(t)
    local KCM = h.loader.loadFullAddon()
    local lines = record(KCM)
    t.falsy(KCM.Settings.Helpers.SetAndRefresh("enabled", "yes please"), "refused")
    t.truthy(find(lines, "[Cmd] enabled refused: expected boolean"), "the path and the rule")
    t.eq(count(lines, "[Set] "), 0, "a refusal wrote nothing, so no [Set] line")
end)

test("every slash command leaves one [Cmd] line as typed", function(t)
    local KCM = h.loader.loadFullAddon()
    local lines = record(KCM)
    KCM:OnSlashCommand("  version  ")
    t.truthy(find(lines, "[Cmd] /cm version"), "the command, trimmed")
end)

-- ---------------------------------------------------------------------------
-- The macro bar: held work, and the flyout cap
-- ---------------------------------------------------------------------------

test("the macro bar's combat hold is one line however often it is asked, and its flush one more", function(t)
    local KCM, mock = h.loader.loadFullAddon(), h.loader.mock
    local lines = record(KCM)
    mock.setCombat(true)
    KCM.MacroBar.Update()
    KCM.MacroBar.Update()
    KCM.MacroBar.Update()
    mock.setCombat(false)
    KCM.MacroBar.FlushPending()
    t.eq(count(lines, "[Bar] update held for combat"), 1, "the hold, on its edge only")
    t.eq(count(lines, "[Bar] flushed the held update"), 1, "and the release")
end)

-- red under: FO.Candidates logging the cap on every call. Every bar refresh
-- re-runs it for every slot, so an unchanged cap repeated after each bag update.
test("a flyout cap is logged once while it holds, and again when it moves", function(t)
    local KCM = h.loader.loadFullAddon()
    local realList = KCM.Selector.ListAvailable
    KCM.Selector.ListAvailable = function() return { 1, 2, 3, 4 } end
    local lines = record(KCM)
    for _ = 1, 3 do KCM.MacroBarFlyout.Candidates("FOOD", { flyoutMax = 2 }) end
    KCM.MacroBarFlyout.Candidates("FOOD", { flyoutMax = 3 })
    KCM.Selector.ListAvailable = realList
    t.eq(count(lines, "FOOD flyout capped at 2 of 4"), 1, "three identical refreshes, one line")
    t.eq(count(lines, "FOOD flyout capped at 3 of 4"), 1, "a new cap is a change")
end)

-- ---------------------------------------------------------------------------
-- [Init]: the stand-down and the dependencies (debug-logging-§8)
-- ---------------------------------------------------------------------------

-- red under: initSummary naming neither. Logging is off every session, so a
-- stand-down taken before it was switched on has no edge line: only the
-- summary can say the addon is down, and which optional library is missing.
test("[Init] names a stand-down and a missing optional library, and neither when all is well", function(t)
    local KCM = h.loader.loadConsole()
    local D = KCM.DebugLog.instance
    -- The [Init] line the next enable writes.
    local function initLine()
        D:Clear()
        KCM.DebugLog.SetEnabled(true)
        local found = ""
        for _, l in ipairs(D.buffer) do
            if l:find("[Init] ", 1, true) then found = l end
        end
        KCM.DebugLog.SetEnabled(false)
        return found
    end
    local healthy = initLine()
    t.falsy(healthy:find("stood down", 1, true), "no stand-down clause on a live addon")

    KCM.OnEnabledChanged(false)
    local realStub = _G.LibStub
    _G.LibStub = setmetatable({}, {
        __index = realStub,
        __call = function(_, major, silent)
            if major == "LibDBIcon-1.0" then return nil end
            return realStub(major, silent)
        end,
    })
    local line = initLine()
    _G.LibStub = realStub
    KCM.OnEnabledChanged(true)
    t.truthy(line:find("stood down (holds: disabled)", 1, true), line)
    t.truthy(line:find("missing libraries: ", 1, true) and line:find("LibDBIcon-1.0", 1, true), line)
end)
