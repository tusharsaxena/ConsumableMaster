-- test_debuglog.lua — pure formatters + enabled-state API of the debug console.
--
-- DebugLog.lua is not yet in the TOC (another process wires it in), so we load
-- it directly onto the mocked namespace rather than via loadFullAddon.

local h = require("harness")
local test = h.test

-- Fresh KCM with DebugLog + Debug wired onto it; returns (KCM, DebugLog).
local function load()
    local KCM = h.loader.loadPure()
    if not KCM.State then
        assert(loadfile("core/State.lua"))("ConsumableMaster", KCM)
    end
    assert(loadfile("modules/DebugLog.lua"))("ConsumableMaster", KCM)
    assert(loadfile("core/Debug.lua"))("ConsumableMaster", KCM)
    return KCM, KCM.DebugLog
end

-- Standard line shape (debug-logging-§3): "<ts> | [<tag>] <msg>".
-- FormatPlain: no colour escapes.
test("DebugLog: FormatPlain renders the plain line shape with no colour codes", function(t)
    local _, DL = load()
    t.eq(DL.FormatPlain("12:00:01", "Ranker", "hello"),
        "12:00:01 | [Ranker] hello", "plain full")
    t.eq(DL.FormatPlain("12:00:01", nil, "hello"),
        "12:00:01 | hello", "plain nil tag omits [tag] segment")
    t.eq(DL.FormatPlain("12:00:01", "", "hello"),
        "12:00:01 | hello", "plain empty tag omits [tag] segment")
    t.eq(DL.FormatPlain("12:00:01", "Ranker", nil),
        "12:00:01 | [Ranker] ", "plain nil msg treated as empty")
    t.falsy(DL.FormatPlain("12:00:01", "Ranker", "hello"):find("|c", 1, true),
        "plain has no color codes")
end)

-- FormatColored: steel-blue (6f8faf) timestamp, tan/gold (c9a66b) [tag],
-- default-white msg; "||" renders one literal pipe separator.
test("DebugLog: FormatColored colours timestamp/tag and handles nil tag/msg", function(t)
    local _, DL = load()
    t.eq(DL.FormatColored("12:00:01", "Ranker", "hello"),
        "|cff6f8faf12:00:01|r || |cffc9a66b[Ranker]|r hello", "colored full")
    t.eq(DL.FormatColored("12:00:01", nil, "hello"),
        "|cff6f8faf12:00:01|r || hello", "colored nil tag omits [tag] segment")
    t.eq(DL.FormatColored("12:00:01", "Ranker", nil),
        "|cff6f8faf12:00:01|r || |cffc9a66b[Ranker]|r ", "colored nil msg empty")
end)

-- Enabled-state API drives KCM.State.debug through the single SetEnabled seam.
test("DebugLog: SetEnabled/IsEnabled drive State.debug", function(t)
    local KCM, DL = load()
    DL.SetEnabled(false)
    t.falsy(DL.IsEnabled(), "disabled reads false")
    t.falsy(KCM.State.debug, "SetEnabled(false) clears State.debug")

    t.eq(DL.SetEnabled(true), true, "SetEnabled returns new state")
    t.truthy(DL.IsEnabled(), "enabled reads true")
    t.truthy(KCM.State.debug, "SetEnabled(true) sets State.debug")
end)

test("DebugLog: Toggle flips State.debug both directions", function(t)
    local KCM, DL = load()
    DL.SetEnabled(true)
    t.eq(DL.Toggle(), false, "Toggle flips true -> false")
    t.falsy(KCM.State.debug, "Toggle wrote State.debug false")
    t.eq(DL.Toggle(), true, "Toggle flips false -> true")
    t.truthy(KCM.State.debug, "Toggle wrote State.debug true")
end)

-- KCM.SafeToString — secret-safe stringify. Detection MUST probe table.concat,
-- not tostring/`..` (events-frames-taint-§8): a real combat "secret" SURVIVES
-- tostring() and `..` but RAISES in table.concat, so a tostring probe would
-- wave it through.
test("DebugLog: SafeToString stringifies safely and catches concat-hostile values", function(t)
    local KCM = load()
    t.eq(KCM.SafeToString(42), "42", "SafeToString number")
    t.eq(KCM.SafeToString("x"), "x", "SafeToString string")
    t.eq(KCM.SafeToString(nil), "nil", "SafeToString nil")
    t.eq(KCM.SafeToString(true), "true", "SafeToString boolean")

    -- The real "secret" shape: SURVIVES tostring() (returns a value) but a real
    -- table.concat rejects it. The old pcall(tostring) probe let such a value
    -- through; the table.concat probe substitutes "<secret>".
    local concatHostile = setmetatable({}, { __tostring = function() return "looks-safe" end })
    t.eq(tostring(concatHostile), "looks-safe", "sanity: value survives tostring")
    t.eq(KCM.SafeToString(concatHostile), "<secret>",
        "a value that survives tostring but a real concat rejects yields <secret>")
    t.truthy(KCM.IsConcatSafe("plain"), "IsConcatSafe true for a plain string")
    t.falsy(KCM.IsConcatSafe(concatHostile), "IsConcatSafe false for a concat-hostile value")

    -- A raising __tostring is still swallowed (concat rejects the table first).
    local boom = setmetatable({}, { __tostring = function() error("secret") end })
    t.eq(KCM.SafeToString(boom), "<secret>", "SafeToString catches a raising tostring too")
end)

-- Callable sink: gated + routes tag/msg through DebugLog.AddLine
test("DebugLog: Debug sink is gated and routes tag/msg through AddLine", function(t)
    local KCM = load()
    local captured = {}
    local realAdd = KCM.DebugLog.AddLine
    KCM.DebugLog.AddLine = function(tag, msg) captured[#captured + 1] = { tag = tag, msg = msg } end

    KCM.State.debug = false
    KCM.Debug("Test", "should not fire %s", "x")
    t.eq(#captured, 0, "sink is gated off when State.debug is false")

    KCM.State.debug = true
    KCM.Debug("Test", "value=%s", 7)
    t.eq(#captured, 1, "sink fires when enabled")
    t.eq(captured[1].tag, "Test", "sink passes the tag verbatim")
    t.eq(captured[1].msg, "value=7", "sink formats with SafeToString args")

    KCM.DebugLog.AddLine = realAdd
    KCM.State.debug = false
end)

test("DebugLog: Pipeline.CalcSummary formats reason + rewrite/skip tally", function(t)
    local KCM = load()
    t.eq(KCM.Pipeline.CalcSummary("bag_update_delayed", 3, 10, 7),
        "reason=bag_update_delayed rewrote 3/10 (skipped 7)",
        "CalcSummary formats reason + rewrite/skip tally")
end)

-- debug-logging-§5 (v1.12.0): colour-coded chat ack + [Init] summary on enable.
test("DebugLog: enable emits [Debug]+[Init] brackets and coloured ON/OFF acks", function(t)
    local KCM, DL = load()
    local captured = {}
    local realAdd = KCM.DebugLog.AddLine
    KCM.DebugLog.AddLine = function(tag, msg) captured[#captured + 1] = { tag = tag, msg = msg } end
    local acks = {}
    local realSay = KCM.Say
    KCM.Say = function(msg) acks[#acks + 1] = msg end

    DL.SetEnabled(true)
    -- Console order: the [Debug] "logging enabled" bracket, THEN the [Init] summary.
    local dbgIdx, initIdx
    for i, c in ipairs(captured) do
        if c.tag == "Debug" and c.msg == "logging enabled" then dbgIdx = i end
        if c.tag == "Init" then initIdx = i end
    end
    t.truthy(dbgIdx, "enable emits the [Debug] logging enabled bracket")
    t.truthy(initIdx, "enable emits an [Init] session summary")
    t.truthy(dbgIdx and initIdx and initIdx > dbgIdx, "[Init] follows the bracket on enable")
    local initMsg = initIdx and captured[initIdx].msg or ""
    t.truthy(initMsg:find("Consumable Master v", 1, true), "[Init] names addon + version")
    t.truthy(initMsg:find("schema v", 1, true), "[Init] carries the schema version")
    t.truthy(initMsg:find("profile ", 1, true), "[Init] carries the active profile")
    t.truthy((acks[#acks] or ""):find("|cff40ff40ON|r", 1, true), "enable ack colour-codes ON green")

    for i = #captured, 1, -1 do captured[i] = nil end
    DL.SetEnabled(false)
    local sawInit = false
    for _, c in ipairs(captured) do if c.tag == "Init" then sawInit = true end end
    t.falsy(sawInit, "disable emits no [Init] summary")
    t.truthy((acks[#acks] or ""):find("|cffff4040OFF|r", 1, true), "disable ack colour-codes OFF red")

    KCM.DebugLog.AddLine = realAdd
    KCM.Say = realSay
    KCM.State.debug = false
end)

-- Window visibility is a SEPARATE concern from the enabled flag (debug-logging-§5):
-- the options-panel [Debug console] checkbox drives Show/Hide via IsWindowShown and
-- must never move KCM.State.debug. (The mocked frame's IsShown always reads truthy,
-- so shown-vs-hidden itself can't be asserted headlessly — only the flag invariant
-- and the pre-build false, which the real in-game frame extends to true separation.)
test("DebugLog: Show/Hide toggle the window without touching the enabled flag", function(t)
    local KCM, DL = load()
    t.falsy(DL.IsWindowShown(), "no window built yet -> IsWindowShown false")

    DL.SetEnabled(true)
    DL.Hide()
    t.truthy(DL.IsEnabled(), "Hide() leaves logging enabled")
    DL.Show()
    t.truthy(DL.IsEnabled(), "Show() leaves logging enabled")

    DL.SetEnabled(false)
    DL.Show()
    t.falsy(DL.IsEnabled(), "Show() does not arm logging")

    KCM.State.debug = false
end)
