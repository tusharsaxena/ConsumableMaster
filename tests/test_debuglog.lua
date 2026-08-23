-- test_debuglog.lua — the addon's half of the debug console.
--
-- The window is LibKa0s-DebugLog-1.0's now; core/DebugLogSetup.lua is the setup
-- file that builds one instance and publishes the flat KCM.DebugLog.* surface
-- the addon has always called. These cases are the oracle for that swap: they
-- were written against the host implementation, so what they still pin is that
-- the addon's own contract — the flat names, the flag's home, the return
-- values, the [Debug]/[Init] brackets — survived it.

local h = _G.KCM_TEST
local test = h.test

-- Fresh KCM with DebugLog + Debug wired onto it; returns (KCM, DebugLog).
local function load()
    local KCM = h.loader.loadConsole()
    return KCM, KCM.DebugLog
end

-- Standard line shape (debug-logging-§3): "<ts> | [<tag>] <msg>".
-- FormatPlain: no color escapes.
--
-- The degenerate rows below changed when the formatters became the library's.
-- The addon used to omit the whole `[tag]` segment for a nil or empty tag and
-- render a nil message as blank; the library always emits the bracket and
-- renders a nil message as the literal "nil". Nothing in the addon can reach
-- either shape — every call site tags its line, and the library's own Add
-- stringifies the message before it gets here — so the change is pinned rather
-- than worked around. See the LibKa0s adoption commit for the decision.
test("DebugLog: FormatPlain renders the plain line shape with no color codes", function(t)
    local _, DL = load()
    t.eq(DL.FormatPlain("12:00:01", "Ranker", "hello"),
        "12:00:01 | [Ranker] hello", "plain full")
    t.eq(DL.FormatPlain("12:00:01", nil, "hello"),
        "12:00:01 | [] hello", "plain nil tag renders an empty bracket")
    t.eq(DL.FormatPlain("12:00:01", "", "hello"),
        "12:00:01 | [] hello", "plain empty tag renders an empty bracket")
    t.eq(DL.FormatPlain("12:00:01", "Ranker", nil),
        "12:00:01 | [Ranker] nil", "plain nil msg renders the literal")
    t.falsy(DL.FormatPlain("12:00:01", "Ranker", "hello"):find("|c", 1, true),
        "plain has no color codes")
end)

-- FormatColored: steel-blue (6f8faf) timestamp, tan/gold (c9a66b) [tag],
-- default-white msg; "||" renders one literal pipe separator.
test("DebugLog: FormatColored colors timestamp/tag and handles nil tag/msg", function(t)
    local _, DL = load()
    t.eq(DL.FormatColored("12:00:01", "Ranker", "hello"),
        "|cff6f8faf12:00:01|r || |cffc9a66b[Ranker]|r hello", "colored full")
    t.eq(DL.FormatColored("12:00:01", nil, "hello"),
        "|cff6f8faf12:00:01|r || |cffc9a66b[]|r hello", "colored nil tag renders an empty bracket")
    t.eq(DL.FormatColored("12:00:01", "Ranker", nil),
        "|cff6f8faf12:00:01|r || |cffc9a66b[Ranker]|r nil", "colored nil msg renders the literal")
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
test("DebugLog: the Debug sink is gated, and formats into the console buffer", function(t)
    -- Read off the instance's own buffer rather than by intercepting AddLine.
    -- core/Debug.lua delegates to the instance's gated sink now, which appends
    -- through the library's Add directly — the addon's forwarder is not on that
    -- path, so a stub on it would capture nothing and the case would fail for
    -- the wrong reason.
    local KCM = load()
    local D = KCM.DebugLog.instance

    D:Clear()
    KCM.State.debug = false
    KCM.Debug("Test", "should not fire %s", "x")
    t.eq(D:BufferSize(), 0, "sink is gated off when State.debug is false")

    KCM.State.debug = true
    KCM.Debug("Test", "value=%s", 7)
    t.eq(D:BufferSize(), 1, "sink fires when enabled")
    t.truthy(D:LastLine():find("[Test] value=7", 1, true),
        "tag passed through and args formatted through the secret guard")

    KCM.State.debug = false
end)

test("DebugLog: Pipeline.CalcSummary formats reason + rewrite/skip tally", function(t)
    local KCM = load()
    t.eq(KCM.Pipeline.CalcSummary("bag_update_delayed", 3, 10, 7),
        "reason=bag_update_delayed rewrote 3/10 (skipped 7)",
        "CalcSummary formats reason + rewrite/skip tally")
end)

-- debug-logging-§5 (v1.12.0): color-coded chat ack + [Init] summary on enable.
--
-- Read off the console's own buffer rather than by intercepting DL.AddLine. The
-- enable seam writes these two lines through the instance directly and never
-- through the addon's forwarder, so a stub on the forwarder would capture
-- nothing and the case would pass for the wrong reason — or fail for one.
test("DebugLog: enable emits [Debug]+[Init] brackets and colored ON/OFF acks", function(t)
    local KCM, DL = load()
    local D = DL.instance
    local acks = {}
    local realSay = KCM.Say
    KCM.Say = function(msg) acks[#acks + 1] = msg end

    D:Clear()
    DL.SetEnabled(true)
    -- Console order: the [Debug] "logging enabled" bracket, THEN the [Init] summary.
    local dbgIdx, initIdx
    for i, line in ipairs(D.buffer) do
        if line:find("[Debug] logging enabled", 1, true) then dbgIdx = i end
        if line:find("[Init] ", 1, true) then initIdx = i end
    end
    t.truthy(dbgIdx, "enable emits the [Debug] logging enabled bracket")
    t.truthy(initIdx, "enable emits an [Init] session summary")
    t.truthy(dbgIdx and initIdx and initIdx > dbgIdx, "[Init] follows the bracket on enable")
    local initMsg = initIdx and D.buffer[initIdx] or ""
    t.truthy(initMsg:find("Consumable Master v", 1, true), "[Init] names addon + version")
    t.truthy(initMsg:find("schema v", 1, true), "[Init] carries the schema version")
    t.truthy(initMsg:find("profile ", 1, true), "[Init] carries the active profile")
    t.truthy((acks[#acks] or ""):find("|cff40ff40ON|r", 1, true), "enable ack color-codes ON green")

    D:Clear()
    DL.SetEnabled(false)
    t.falsy(D:FindLine("[Init] "), "disable emits no [Init] summary")
    t.truthy(D:FindLine("[Debug] logging disabled"), "disable still brackets the session")
    t.truthy((acks[#acks] or ""):find("|cffff4040OFF|r", 1, true), "disable ack color-codes OFF red")

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

-- Scrollbar + line counter (debug-logging-§11). The scroll sync drives the log
-- through the Lua ScrollingMessageFrameMixin API (GetMaxScrollRange /
-- GetScrollOffset / SetScrollOffset) and MUST stay a clean no-op headlessly:
-- the mock's stub frame returns non-numbers, which the numeric-return guard in
-- DL.UpdateScrollBar catches. This test proves the append/clear/sync paths run
-- without raising (the "attempt to call a nil value" trap of anti-pattern #41).
test("DebugLog: scrollbar + counter sync run headlessly without error", function(t)
    local KCM, DL = load()
    DL.Show()                       -- build the window (installs scrollBar + lineCount)
    DL.UpdateScrollBar()            -- guarded no-op under the mock (non-numeric returns)
    DL.UpdateStatus()               -- counter repaint (SetText on the stub is a no-op)
    DL.AddLine("Test", "line one")  -- append path also runs the two syncs
    DL.AddLine("Test", "line two")
    DL.Clear()                      -- clear path resets the counter + syncs the bar
    t.truthy(true, "AddLine/Clear/UpdateScrollBar/UpdateStatus never raise headlessly")

    KCM.State.debug = false
end)

-- ---------------------------------------------------------------------------
-- The swap itself (LibKa0s-DebugLog-1.0)
-- ---------------------------------------------------------------------------
--
-- Everything above pins the addon's CONTRACT and would pass just as happily
-- against the old host implementation left in place — which is precisely what
-- "the swap silently no-opped" looks like from the outside. These assert
-- identity against the library instead.

test("DebugLog: the console IS the library's instance, not a host lookalike", function(t)
    local _, DL = load()
    local lib = LibStub("LibKa0s-DebugLog-1.0")
    t.truthy(lib, "LibKa0s-DebugLog-1.0 registered")
    t.eq(DL.FormatPlain, lib.FormatPlain, "FormatPlain is the library function object")
    t.eq(DL.FormatColored, lib.FormatColored, "FormatColored is the library function object")
    t.truthy(DL.instance and DL.instance.Add and DL.instance.SetEnabled,
        "the instance is published for the suite to reach")
    -- The forwarder appends to the instance's own buffer, so the flat name and
    -- the library's are two doors onto one console rather than two consoles.
    DL.instance:Clear()
    DL.AddLine("X", "y")
    t.eq(DL.instance:BufferSize(), 1, "DL.AddLine lands in the instance buffer")
    t.truthy(DL.instance:LastLine():find("[X] y", 1, true), "…rendered through the library")
end)

test("DebugLog: the descriptor reproduces the addon's window identity", function(t)
    local _, DL = load()
    local lib = LibStub("LibKa0s-DebugLog-1.0")
    DL.Show()
    -- frame.titleText is the one thing about the composed title a test can read
    -- back — a font string is write-only through the frame API — and composing
    -- it from `title` plus the library's own suffix is exactly what changed.
    t.eq(DL.instance._frameForTest.titleText, "Consumable Master \226\128\148 Debug",
        "the title composes to the addon's own literal")
    -- The frame global itself is out of reach headlessly (the mock's CreateFrame
    -- returns a stub without publishing the name), but the library derives the
    -- Esc registration from that same `name`, so this pins it by proxy.
    local registered = false
    for _, n in ipairs(UISpecialFrames) do
        if n == "ConsumableMasterDebugWindow" then registered = true end
    end
    t.truthy(registered, "the derived frame name is preserved, and Esc closes it")
    t.eq(lib.MAX_BUFFER, 500, "the buffer cap still matches the old MAX_LINES")
end)

test("DebugLog: the console's own strings resolve to prose, not to their own keys", function(t)
    local _, DL = load()
    local D = DL.instance
    -- The L trap. core/DebugLogSetup.lua omits `L` deliberately -- the library's
    -- English already matches this addon's -- and this case is what stops one
    -- being added later. KCM.L answers every key with the key, so a descriptor
    -- handed it (or handed a plain table whose values were read out of it by
    -- library key) renders the whole console in SCREAMING_SNAKE, for every
    -- string at once and only in game.
    --
    -- Driven through ConsoleCheckbox because that is the real accessor:
    -- settings/General.lua renders exactly this spec on the General page, so
    -- these two strings are the ones a user reads. Not guarded on
    -- `if spec then` -- a spec that stopped being built has to fail here.
    local spec = D:ConsoleCheckbox()
    t.falsy(spec.label:match("^[A-Z][A-Z0-9_]+$"),
        "the checkbox label resolved to prose, not to its own key: " .. spec.label)
    t.falsy(spec.tooltip:match("^[A-Z][A-Z0-9_]+$"),
        "the checkbox tooltip resolved to prose, not to its own key: " .. spec.tooltip)

    -- The chat half of the same seam, and a composed string rather than a bare
    -- one: ACK is a format whose one argument is STATE_ON. Unresolved, the
    -- format loses its %s and the whole line collapses to the key.
    local mock = h.loader.mock
    mock.output = {}
    D:SetEnabled(true)
    D:SetEnabled(false)
    local ack = (mock.output[1] or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    ack = ack:gsub("^%[CM%]%s*", "")
    t.falsy(ack:match("^[A-Z][A-Z0-9_]+$"),
        "the enable acknowledgment resolved to prose, not to its own key: " .. ack)
end)

test("DebugLog: the flag lives in KCM.State, not in the library", function(t)
    local KCM, DL = load()
    local D = DL.instance
    -- Driven through the INSTANCE, not the forwarders, so what is under test is
    -- the isEnabled/setEnabled pair the descriptor handed the library.
    KCM.State.debug = true
    t.truthy(D:IsEnabled(), "the library reads the host's flag")
    D:SetEnabled(false)
    t.falsy(KCM.State.debug, "the library writes the host's flag")
    -- The header toggle is the third entry point onto the same seam. The mock's
    -- GetScript is a catch-all no-op, so the library's own test seam is the only
    -- way to drive the button.
    D._toggleClickForTest()
    t.truthy(KCM.State.debug, "the header toggle routes through the same seam")

    KCM.State.debug = false
end)

test("DebugLog: with the library absent the console degrades and chat still answers", function(t)
    -- Loaded for real with libs/LibKa0s/ omitted, so core/DebugLogSetup.lua takes
    -- its own stub rather than a hand-written one (testing-§8).
    local KCM  = h.loader.loadConsole(true)
    local DL   = KCM.DebugLog
    local mock = h.loader.mock
    t.falsy(LibStub("LibKa0s-DebugLog-1.0", true), "the major really is absent")

    -- The load-bearing omission: no AddLine is published, which is exactly what
    -- re-arms core/Debug.lua's chat fallback. A no-op one would send every
    -- diagnostic into a black hole while the addon looked healthy.
    t.eq(DL.AddLine, nil, "no console sink is published")
    t.falsy(DL.IsWindowShown(), "the settings panel can still ask, and gets false")

    mock.output = {}
    KCM.State.debug = true
    KCM.Debug("Init", "booting")
    t.eq(mock.output[#mock.output], KCM.PREFIX .. " [Init] booting",
        "diagnostics fall back to chat")

    mock.output = {}
    t.eq(DL.SetEnabled(true), true, "SetEnabled still answers the new flag")
    t.truthy(KCM.State.debug, "…and still writes it")
    DL.Show()
    DL.Toggle_Window()
    local notices = 0
    for _, line in ipairs(mock.output) do
        if line:find("debug console is unavailable", 1, true) then notices = notices + 1 end
    end
    t.eq(notices, 1, "the missing-console notice is said exactly once")

    KCM.State.debug = false
end)

-- ── the descriptor field the title bar's art hangs on ─────────────────────────
--
-- TEST THE ARGUMENT, NOT THE APPEARANCE. LibKa0s-DebugLog draws the catalog's
-- copy, clear and close marks on both console windows only when the descriptor
-- tells it which addon FOLDER to build a texture path from; without it the
-- library falls back to word buttons and a multiplication sign. Every one of
-- those is a working control that raises nothing, so what is worth pinning
-- headlessly is the field, not the pixels.

test("DebugLogSetup: the descriptor passes addonName BESIDE name, not instead of it", function(t)
    -- red under: deleting the addonName line, or "fixing" the pair by folding
    -- them into one key. `name` seeds the frame globals — /framestack and any
    -- user layout addon know ConsumableMasterDebugWindow — while `addonName` is
    -- the folder LibKa0s-Media builds a texture path from. Same string here,
    -- two different questions everywhere, and a wrong path draws nothing.
    local root = _G.KCM_TEST_ROOT or "."
    local f = assert(io.open(root .. "/core/DebugLogSetup.lua", "r"),
        "cannot open core/DebugLogSetup.lua (tests run from the repo root)")
    local src = f:read("*a")
    f:close()
    t.truthy(src:find("addonName%s*=%s*addonName"),
        "the lib:New descriptor no longer passes addonName")
    t.truthy(src:find("name%s*=%s*addonName"),
        "the descriptor's `name` is no longer the vararg — a folder rename would "
        .. "silently desync the frame globals")
    t.truthy(src:find("^local addonName, NS = %.%.%.", 1) or
             src:find("\nlocal addonName, NS = %.%.%."),
        "the file discards its first vararg, so both fields above are nil")
end)

test("DebugLogSetup: the folder name the descriptor carries names art that exists", function(t)
    -- The string is only half the fact. The catalog lives in another repo, so
    -- this asks whether the three marks the title bars draw resolve in THIS
    -- build's vendored payload.
    local KCM = h.loader.loadConsole()
    local media = LibStub("LibKa0s-Media-1.0")
    t.truthy(media, "the vendored Media major registered")
    for _, name in ipairs({ "copy", "clear", "close" }) do
        t.eq(media.Icon("ConsumableMaster", name), KCM.Icon(name),
            "the descriptor's folder name and the media seam's disagree for " .. name)
        t.truthy(KCM.Icon(name), "the console's " .. name .. " mark does not resolve")
    end
end)

test("DebugLogSetup: the console's font comes out of the payload, with a real client fallback",
    function(t)
        -- SetFont takes a path to a file that is not there, fails to load it, and
        -- the text simply does not draw — no error, no chat line, an empty
        -- console. So the fallback rung has to be a face the client itself ships,
        -- never the old media/fonts/ path this addon no longer carries.
        local KCM = h.loader.loadConsole()
        t.eq(KCM.MediaFont("JetBrains Mono"),
            "Interface\\AddOns\\ConsumableMaster\\libs\\LibKa0s\\media\\fonts\\JetBrainsMono-Regular.ttf",
            "the console's face no longer resolves into the vendored payload")

        local root = _G.KCM_TEST_ROOT or "."
        local f = assert(io.open(root .. "/core/DebugLogSetup.lua", "r"))
        local src = f:read("*a")
        f:close()
        t.truthy(src:find("Fonts\\ARIALN.TTF", 1, true),
            "the fallback is no longer one of the client's own fonts")
        t.falsy(src:find("ConsumableMaster\\media\\fonts", 1, true),
            "the deleted media/fonts/ path is named here again")
    end)
