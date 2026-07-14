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
end)
