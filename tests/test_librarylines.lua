-- tests/test_librarylines.lua — the lines LibKa0s writes into THIS addon's log
-- (debug-logging-§4, "The library's own lines", LibKa0s v1.65.0).
--
-- The slash dispatcher, the stand-down latch, the options panel's combat lock
-- and the launcher each decide something a support read of the log needs, and
-- from v1.65.0 each writes that decision itself, through the gated sink the
-- host hands its descriptor as `debug`. Two things can go wrong on the host's
-- side and neither shows up anywhere but here:
--
--   * the host forgets to pass `debug` (or passes the ungated append, or a
--     captured nil), and the library's line is simply never written; the
--     library's own suite cannot see that, because it builds its own sink;
--   * the host keeps the line it used to write for the same decision, and every
--     refusal or edge is two lines, one of them in a shape nobody documents.
--
-- So every case reads the REAL console buffer of a full load -- the library's
-- line has to arrive through core/Debug.lua's KCM.Debug, into
-- core/DebugLogSetup.lua's instance -- and counts: the library's line once, and
-- the host's old line not at all.

local h = _G.KCM_TEST
local test = h.test

-- A full load with logging on and an empty console. The flag is flipped
-- directly rather than through SetEnabled so the session bracket and the
-- [Init] summary are not in the buffer the case counts.
local function build()
    local KCM = h.loader.loadFullAddon()
    local D = KCM.DebugLog.instance
    KCM.State = KCM.State or {}
    KCM.State.debug = true
    D:Clear()
    return KCM, D, h.loader.mock
end

-- The buffer as "[Tag] message" lines, the timestamp column dropped.
local function lines(D)
    local out = {}
    for _, l in ipairs(D.buffer) do
        out[#out + 1] = (l:gsub("^.- | ", "", 1))
    end
    return out
end

local function count(D, needle)
    local n = 0
    for _, l in ipairs(lines(D)) do
        if l:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function dump(D) return table.concat(lines(D), " || ") end

-- ---------------------------------------------------------------------------
-- Slash (minor 18): the dispatcher's refusals
-- ---------------------------------------------------------------------------

-- red under: settings/Slash.lua's descriptor passing no `debug`. The refusal
-- reached chat and nothing else, so the log showed `/cm bar on` and then nothing.
test("Library lines: a feature verb refused while disabled is one [Cmd] refused line", function(t)
    local KCM, D = build()
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)
    D:Clear()
    KCM:OnSlashCommand("bar on")
    t.eq(count(D, "[Cmd] refused bar: disabled"), 1, "the library's line, guard named: " .. dump(D))
    t.eq(count(D, "[Cmd] "), 2, "the command as typed and the refusal, nothing else: " .. dump(D))
    KCM.Settings.Helpers.SetAndRefresh("enabled", true)
end)

test("Library lines: an unknown verb is one [Cmd] refused line", function(t)
    local KCM, D = build()
    KCM:OnSlashCommand("frobnicate")
    t.eq(count(D, "[Cmd] refused frobnicate: unknown verb"), 1, dump(D))
end)

-- red under: the `set` thunk keeping its own `<path> refused: <why>` line. The
-- dispatcher writes the refusal now, so the host's copy made every refused
-- write two lines.
test("Library lines: a write the seam refuses under /cm set is the library's line alone", function(t)
    local KCM, D = build()
    local S = KCM.Settings.Helpers.schema
    local realSet = S.Set
    S.Set = function(path) return false, "Invalid value for " .. path .. ".", "a test rule" end
    local ok, err = pcall(KCM.OnSlashCommand, KCM, "set enabled false")
    S.Set = realSet
    t.truthy(ok, tostring(err))
    t.eq(count(D, "[Cmd] refused set enabled: write refused"), 1, dump(D))
    t.eq(count(D, "enabled refused:"), 0, "no host copy of the refusal: " .. dump(D))
end)

test("Library lines: a value /cm set cannot parse is one [Cmd] refused line", function(t)
    local KCM, D = build()
    KCM:OnSlashCommand("set enabled perhaps")
    t.eq(count(D, "[Cmd] refused set enabled: parse"), 1, dump(D))
    t.eq(count(D, "[Cmd] "), 2, "the command as typed and the refusal: " .. dump(D))
end)

-- ---------------------------------------------------------------------------
-- Lifecycle (minor 3): the stand-down and stand-up edges
-- ---------------------------------------------------------------------------

-- red under: core/LifecycleSetup.lua's descriptor passing no `debug` (no edge
-- line at all), or its standDown / standUp keeping their own [State] edge line
-- (two lines per edge).
test("Library lines: disable and enable are one [Lifecycle] line each, and no host edge line", function(t)
    local KCM, D = build()
    KCM.OnEnabledChanged(false)
    KCM.OnEnabledChanged(true)
    t.eq(count(D, "[Lifecycle] stood down: added disabled (holds: disabled)"), 1, dump(D))
    t.eq(count(D, "[Lifecycle] stood up: released disabled (holds: none)"), 1, dump(D))
    t.eq(count(D, "[Lifecycle] "), 2, "one line per edge")
    t.eq(count(D, "[State] stood"), 0, "the host writes no edge line of its own: " .. dump(D))
end)

test("Library lines: a call that changes no edge writes no [Lifecycle] line", function(t)
    local KCM, D = build()
    KCM.OnEnabledChanged(true)          -- already up
    KCM.ReevaluateEnabled()             -- the profile agrees
    t.eq(count(D, "[Lifecycle] "), 0, dump(D))
end)

-- The one stand-down line that stays the host's: the latch cannot know this
-- addon's teardown waits for combat to end.
test("Library lines: a stand-down in combat is the library's edge, then the host's held line", function(t)
    local KCM, D, mock = build()
    mock.setCombat(true)
    KCM.OnEnabledChanged(false)
    mock.setCombat(false)
    local l = lines(D)
    local edge, held
    for i, line in ipairs(l) do
        if line:find("[Lifecycle] stood down: added disabled", 1, true) then edge = edge or i end
        if line:find("[State] stood down: bar teardown held for combat", 1, true) then held = held or i end
    end
    t.truthy(edge, "the library's edge: " .. dump(D))
    t.truthy(held, "the host's held line: " .. dump(D))
    t.truthy(edge and held and edge < held, "the edge first, then what the host held")
    KCM:OnRegenEnabled("PLAYER_REGEN_ENABLED")
    KCM.OnEnabledChanged(true)
end)

-- ---------------------------------------------------------------------------
-- Options (minor 27): the combat lock's refusals
-- ---------------------------------------------------------------------------

-- red under: settings/OptionsSetup.lua's descriptor passing no `debug`. The
-- lock refused the click with one gray chat notice and the log said nothing.
test("Library lines: a page's Defaults refused under the combat lock is one [Cfg] line", function(t)
    local KCM, D, mock = build()
    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders["general"]({})
    local panel = UI.__panelFor("general").panel
    t.truthy(type(panel.OnDefault) == "function", "the page carries the library's Defaults forwarder")
    mock.setCombat(true)
    panel.OnDefault()
    panel.OnDefault()
    mock.setCombat(false)
    t.eq(count(D, "refused (in combat)"), 1, "once per combat, however often it is clicked: " .. dump(D))
    t.eq(count(D, "[Cfg] defaults "), 1, "the library's line names the act: " .. dump(D))
    t.eq(count(D, "Defaults refused: in combat"), 0, "and no host copy: " .. dump(D))
end)

-- ---------------------------------------------------------------------------
-- Launcher (minor 5): the registration state, held until logging is turned on
-- ---------------------------------------------------------------------------

-- red under: core/LauncherSetup.lua's descriptor passing no `debugAtEnable`.
-- Register runs at OnInitialize, with the session-only flag off, so its state
-- lines went to the gated `debug` and never landed at all.
test("Library lines: the launcher's registration lands when logging is first turned on", function(t)
    local KCM = h.loader.loadFullAddon()
    local D = KCM.DebugLog.instance
    t.falsy(KCM.State and KCM.State.debug, "logging was off when Register ran")
    D:Clear()
    KCM.DebugLog.SetEnabled(true)
    local l = lines(D)
    local init, reg
    for i, line in ipairs(l) do
        if line:find("[Init] ", 1, true) then init = init or i end
        if line:find("[Launcher] registered", 1, true) then reg = reg or i end
    end
    t.truthy(reg, "the held line is written on the enable edge: " .. dump(D))
    t.truthy(init and reg and init < reg, "after the [Init] summary")
    t.eq(count(D, "[Launcher] registered"), 1, "once")
    -- One-shot: the next logging window does not repeat a state line it already showed.
    KCM.DebugLog.SetEnabled(false)
    D:Clear()
    KCM.DebugLog.SetEnabled(true)
    t.eq(count(D, "[Launcher] registered"), 0, "not held again: " .. dump(D))
    KCM.DebugLog.SetEnabled(false)
end)
