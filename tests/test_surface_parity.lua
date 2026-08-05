-- tests/test_surface_parity.lua — one stub-surface parity case per adopted
-- LibKa0s seam (testing-§8, anti-pattern #56).
--
-- THE CLASS OF BUG. A degradation stub is written once, against the surface the
-- seam had that day, and then the live half grows a member. Nothing notices: the
-- live path has it, every green case runs on the live path, and the stub's caller
-- only ever raises on the one path the stub exists to survive. Three of this
-- collection's surviving High findings are exactly one omitted stub member.
--
-- HOW EACH ARM IS PRODUCED, and why it matters:
--   * the LIVE arm is a real load with libs/LibKa0s/ present;
--   * the DEGRADED arm is a real load of the SAME partial file list with the
--     library absent (tests/run.lua's `omitLibs`), so every setup file runs its
--     own fallback for real. It is never hand-stubbed — a test that writes the
--     stub it then asserts on is testing its own typing.
--   * the MEMBER LIST comes from a grep, named above each case, so a reader can
--     re-run it and see for themselves that the list is the whole seam.
--
-- Kit.assertSurfaceParity reports EVERY divergence in one message, and treats a
-- key that is a function live but anything else degraded as a divergence — the
-- `X = UI and UI.X` shape yields nil when UI is absent and `false` when the guard
-- is falsy, and only the second survives an "is the key set?" check.
--
-- `ignore` encodes "live-only, on purpose" as DATA. Every entry below carries the
-- file and line that argues for it; an intentional omission and a bug are
-- otherwise indistinguishable, and the usual resolution for that is to delete the
-- case.

local h = _G.KCM_TEST
local test = h.test

-- Read a named member list off a real namespace. Reads THROUGH the metatable, so
-- the live Settings.Helpers yields the library members it delegates to rather
-- than only its own keys.
local function project(tbl, keys)
    local out = {}
    for _, k in ipairs(keys) do out[k] = tbl and tbl[k] end
    return out
end

-- ── LibKa0s-Core-1.0, at core/CoreSetup.lua ────────────────────────────────
--
-- Member list produced by:
--     grep -n '^KCM\.[A-Za-z0-9_]* =\|^function KCM\.' core/CoreSetup.lua
-- which is the seam's live surface: LIBKA0S_MISSING (:30), IsConcatSafe (:73),
-- SafeToString (:74), Say (:99). The degraded branch re-declares the last three
-- as real fallbacks and shares the first.
local CORE_SEAM = { "LIBKA0S_MISSING", "IsConcatSafe", "SafeToString", "Say" }

test("Parity: the LibKa0s-Core stub carries the whole live seam", function(t)
    local live     = h.loader.loadPure()
    local degraded = h.loader.loadPureDegraded()
    h.assertSurfaceParity(project(live, CORE_SEAM), degraded, "KCM Core seam")
    -- 177 call sites reach KCM.Say, and core/SlashCommands.lua captures it at
    -- FILE SCOPE, so a nil Say takes the whole of /cm down with it rather than
    -- one line. Worth stating separately from the set assertion.
    t.eq(type(degraded.Say), "function", "KCM.Say survives a degraded load")
end)

-- ── LibKa0s-DebugLog-1.0, at modules/DebugLog.lua ──────────────────────────
--
-- Member list produced by:
--     grep -n '^function DL\.\|^DL\.' modules/DebugLog.lua
-- which is the live surface (:181-:211). The degraded branch (:57-:104)
-- publishes seven of them.
local DEBUGLOG_SEAM = {
    "AddLine", "IsEnabled", "Show", "Hide", "Clear", "ShowCopy", "RefreshHeader",
    "UpdateScrollBar", "UpdateStatus", "Toggle_Window", "IsWindowShown",
    "SetEnabled", "Toggle", "FormatPlain", "FormatColored", "instance",
}

-- Live-only ON PURPOSE, each argued at modules/DebugLog.lua:102-114:
--   * `instance` is WITHHELD, and that is the load-bearing one: core/Debug.lua's
--     emitter probes `DL and DL.instance` (`core/Debug.lua:39-40`) to decide
--     whether a console exists and falls back to the chat frame when it does not.
--   * AddLine is withheld too. Its one production caller is
--     `core/PerfSetup.lua:98`, which that file only builds when the LibKa0s Perf
--     major loaded, so a no-op AddLine would swallow diagnostics rather than
--     degrade anything.
--   * Clear / ShowCopy / RefreshHeader / UpdateScrollBar / UpdateStatus and the
--     two formatters have no consumer outside that file, so there is nothing to
--     degrade — confirmed by
--         grep -rn 'DebugLog\.\(Clear\|ShowCopy\|RefreshHeader\|UpdateScrollBar\|UpdateStatus\|FormatPlain\|FormatColored\)' core/ modules/ settings/
--     which returns nothing at all: even modules/DebugLog.lua reaches them as
--     `DL.`, so there is no caller anywhere left raising.
--     (`instance` itself is the library object; there is no library to publish.)
local DEBUGLOG_LIVE_ONLY = {
    "AddLine", "Clear", "ShowCopy", "RefreshHeader", "UpdateScrollBar",
    "UpdateStatus", "FormatPlain", "FormatColored", "instance",
}

test("Parity: the LibKa0s-DebugLog stub carries the whole live seam", function(t)
    local live     = h.loader.loadConsole()
    local degraded = h.loader.loadConsole(true)
    h.assertSurfaceParity(project(live.DebugLog, DEBUGLOG_SEAM), degraded.DebugLog,
        "KCM.DebugLog seam", DEBUGLOG_LIVE_ONLY)
    -- The two withheld members, asserted as withheld rather than left to the
    -- ignore list to imply it: core/Debug.lua's chat fallback is re-armed by the
    -- ABSENCE of `instance`, so a well-meaning stub added later has to fail
    -- something.
    t.eq(degraded.DebugLog.instance, nil,
        "instance stays absent so core/Debug.lua falls back to chat")
    t.eq(degraded.DebugLog.AddLine, nil,
        "AddLine stays absent rather than silently swallowing the perf log")
end)

-- ── LibKa0s-Slash-1.0, at settings/Slash.lua ───────────────────────────────
--
-- Member list produced by:
--     grep -rhno 'SlashCommands\.[A-Za-z_]*' core/ modules/ settings/ | sort -u
-- (which also matches the filename core/SlashCommands.lua; ignore that row)
-- plus KCM:OnSlashCommand, the entry point AceConsole is handed. `Verbs` is
-- core/SlashCommands.lua's and never went to the library; `GetLandingRows` and
-- `OnSlashCommand` are settings/Slash.lua's and must answer on both paths —
-- slash-commands-§1: the host verbs never went to the library, so a stub that
-- blacks out the whole command surface is non-compliant.
local SLASH_SEAM = { "Verbs", "GetLandingRows" }

-- `instance` is the library object, published at settings/Slash.lua:305 purely so
-- the suite can assert identity rather than lookalike behavior.
local SLASH_LIVE_ONLY = { "instance" }

test("Parity: the LibKa0s-Slash stub carries the whole live seam", function(t)
    local live     = h.loader.loadFullAddon()
    local degraded = h.loader.loadFullAddon(true)
    h.assertSurfaceParity(project(live.SlashCommands, SLASH_SEAM), degraded.SlashCommands,
        "KCM.SlashCommands seam", SLASH_LIVE_ONLY)
    t.eq(type(degraded.OnSlashCommand), "function",
        "KCM:OnSlashCommand survives a degraded load")
    -- GetLandingRows returns {} degraded rather than raising — the About page it
    -- feeds is never built, and a second host-side formatter kept alive "just in
    -- case" is the divergence coming straight back (settings/Slash.lua's note).
    t.eqList(degraded.SlashCommands.GetLandingRows(), {},
        "the degraded landing rows are empty, not absent")
end)

-- ── LibKa0s-Options-1.0, at settings/OptionsSetup.lua ──────────────────────
--
-- Member list produced by:
--     grep -rhno 'Helpers\.[A-Za-z_]*' core/ modules/ settings/ | sort -u
-- i.e. every member the addon actually calls on the seam. That is the right list
-- here rather than the assignments in settings/Panel.lua, because the live half
-- publishes most of them by settings/OptionsSetup.lua's
-- `setmetatable(Helpers, { __index = UI })` and an assignment grep would miss
-- exactly the delegated members.
local OPTIONS_SEAM = {
    "BuildAboutContent", "Button", "ButtonPair", "CreatePanel", "CustomCheckbox",
    "EnumValues", "FindSchema", "Get", "Grid", "LSMValues", "Label",
    "RefreshAllPanels", "RefreshScalars", "RenderField", "ResetScroll", "Resolve",
    "Section", "Set", "SetAndRefresh", "SetRenderer", "ValidateSchema",
    "ValidateSchemaValue", "instance",
}

-- Live-only ON PURPOSE. With the library absent the panel is not registered AT
-- ALL — settings/Panel.lua's registerPanel returns before a single page renders
-- — so every member below is unreachable degraded by construction, and supplying
-- it would mean keeping a verbatim copy of the chrome the adoption removed. Each
-- of the five is a library member bound off the instance (ResetScroll, Grid and
-- CustomCheckbox in settings/Panel.lua; RenderField / SetRenderer through
-- __index); `instance` is the library object itself.
--
-- What is NOT on this list is the point of the case: RefreshAllPanels and
-- RefreshScalars are called UNCONDITIONALLY on paths a degraded install reaches
-- (SetAndRefresh after every schema write, O.Refresh off the PANEL_REFRESH bus
-- message), so they must be real no-ops on both arms — which is the finding this
-- seam actually had.
local OPTIONS_LIVE_ONLY = {
    "CustomCheckbox", "Grid", "RenderField", "ResetScroll", "SetRenderer",
    "instance",
}

test("Parity: the LibKa0s-Options stub carries the whole live seam", function(t)
    local live     = h.loader.loadWithSchema()
    local degraded = h.loader.loadWithSchemaDegraded()
    h.assertSurfaceParity(project(live.Settings.Helpers, OPTIONS_SEAM),
        degraded.Settings.Helpers, "KCM.Settings.Helpers seam", OPTIONS_LIVE_ONLY)
    -- The two refresh tiers, called unconditionally after a degraded write. Bound
    -- as `UI and UI.X` they read back nil and the bare call raised AFTER the
    -- write had already landed, so a pcall'ing caller saw a failure over a
    -- mutation that had persisted.
    local H = degraded.Settings.Helpers
    t.eq(type(H.RefreshAllPanels), "function", "RefreshAllPanels is callable degraded")
    t.eq(type(H.RefreshScalars), "function", "RefreshScalars is callable degraded")
end)
