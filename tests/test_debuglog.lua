-- test_debuglog.lua — pure formatters + enabled-state API of the debug console.
--
-- DebugLog.lua is not yet in the TOC (another process wires it in), so we load
-- it directly onto the mocked namespace rather than via loadFullAddon.

local h = require("harness")

h.suite("DebugLog formatters", function(t)
    local KCM = h.loader.loadPure()
    if not KCM.State then
        assert(loadfile("core/State.lua"))("ConsumableMaster", KCM)
    end
    assert(loadfile("modules/DebugLog.lua"))("ConsumableMaster", KCM)
    assert(loadfile("core/Debug.lua"))("ConsumableMaster", KCM)
    local DL = KCM.DebugLog

    -- Standard line shape (debug-logging-§3): "<ts> | [<tag>] <msg>".
    -- FormatPlain: no colour escapes.
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

    -- FormatColored: steel-blue (6f8faf) timestamp, tan/gold (c9a66b) [tag],
    -- default-white msg; "||" renders one literal pipe separator.
    t.eq(DL.FormatColored("12:00:01", "Ranker", "hello"),
        "|cff6f8faf12:00:01|r || |cffc9a66b[Ranker]|r hello", "colored full")
    t.eq(DL.FormatColored("12:00:01", nil, "hello"),
        "|cff6f8faf12:00:01|r || hello", "colored nil tag omits [tag] segment")
    t.eq(DL.FormatColored("12:00:01", "Ranker", nil),
        "|cff6f8faf12:00:01|r || |cffc9a66b[Ranker]|r ", "colored nil msg empty")

    -- Enabled-state API drives KCM.State.debug through the single SetEnabled seam.
    DL.SetEnabled(false)
    t.falsy(DL.IsEnabled(), "disabled reads false")
    t.falsy(KCM.State.debug, "SetEnabled(false) clears State.debug")

    t.eq(DL.SetEnabled(true), true, "SetEnabled returns new state")
    t.truthy(DL.IsEnabled(), "enabled reads true")
    t.truthy(KCM.State.debug, "SetEnabled(true) sets State.debug")

    t.eq(DL.Toggle(), false, "Toggle flips true -> false")
    t.falsy(KCM.State.debug, "Toggle wrote State.debug false")
    t.eq(DL.Toggle(), true, "Toggle flips false -> true")
    t.truthy(KCM.State.debug, "Toggle wrote State.debug true")

    -- KCM.SafeToString — secret-safe stringify
    t.eq(KCM.SafeToString(42), "42", "SafeToString number")
    t.eq(KCM.SafeToString("x"), "x", "SafeToString string")
    t.eq(KCM.SafeToString(nil), "nil", "SafeToString nil")
    local boom = setmetatable({}, { __tostring = function() error("secret") end })
    t.eq(KCM.SafeToString(boom), "<secret>", "SafeToString swallows a raising tostring")

    -- Callable sink: gated + routes tag/msg through DebugLog.AddLine
    do
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
    end

    t.eq(KCM.Pipeline.CalcSummary("bag_update_delayed", 3, 10, 7),
        "reason=bag_update_delayed rewrote 3/10 (skipped 7)",
        "CalcSummary formats reason + rewrite/skip tally")

    -- debug-logging-§5 (v1.12.0): colour-coded chat ack + [Init] summary on enable.
    do
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
    end
end)
