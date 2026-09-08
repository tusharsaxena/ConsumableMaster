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
--
-- WHY ALL FOUR CASES KEEP THE FOUR-ARGUMENT FORM, and not the by-name factory the
-- kit grew at revision 15. `assertSurfaceParity(stub, majorName, ignore)` looks the
-- LIVE half up through Kit.setSurfaceSource and compares Kit.publicMembers of it.
-- That is the right shape for a stub that mirrors a LIBRARY SURFACE member for
-- member — AbsorbTracker's three do, and they moved — and none of this addon's
-- four does. The difference is structural, not a matter of taste, so it is written
-- down here rather than re-litigated by the next reader:
--
--   * Core is not a major's surface at all. Its two halves are two blocks of
--     core/CoreSetup.lua and what they have in common is a set of names hung on
--     KCM. There is no name for the kit to look up.
--   * KCM.DebugLog is a host WRAPPER over the instance, not the instance.
--     core/DebugLogSetup.lua renames three members ON PURPOSE and says so where it
--     does it: AddLine over the library's Add, Toggle_Window over its Toggle,
--     IsWindowShown over its IsShown — and this addon's `Toggle` means the FLAG,
--     deliberately not bound to the library's. Named to the kit,
--     "LibKa0s-DebugLog-1.0" resolves the instance, and this case would go red on
--     Add, Toggle, IsShown, FindLine, BufferSize, CopyText and Text — seven
--     members the wrapper was never meant to carry.
--   * KCM.SlashCommands is the host's own table (core/SlashCommands.lua:19),
--     holding Verbs, GetLandingRows and the library object under `instance`. The
--     degraded arm of settings/Slash.lua publishes NOTHING onto it — it rebinds
--     file-scope locals and installs degradedDispatch — so what this case pins is
--     slash-commands-§1's rule that the host-owned half keeps answering. That is a
--     host fact about a host table, and no major's surface states it.
--   * KCM.Settings.Helpers is the near miss, and it is the one worth measuring.
--     It is a host table DELEGATING to the instance through
--     `setmetatable(Helpers, { __index = UI })` (settings/OptionsSetup.lua:178),
--     where AbsorbTracker's NS.Helpers IS the instance, decorated in place. pairs()
--     does not walk __index, so Kit.publicMembers sees one half or the other and
--     never the union this case needs. Measured on today's tree:
--     publicMembers(Settings.optionsUI) is 51 members, of which the degraded stub
--     carries 8 — so the by-name form would pin 8 behind a 43-entry ignore list,
--     32 of those entries new, and every one of them saying "this addon never
--     calls it" rather than recording a degradation decision. OPTIONS_SEAM below
--     pins 22 and grows only when the ADDON starts calling something; a by-name
--     ignore list here would grow on every re-vendor that adds a library member.
--     That is the maintenance burden the factory exists to remove, inverted.
--
-- What the by-name form does buy is that it resolves the live half FOR REAL, so a
-- stale seam name cannot be silently dropped. That half is taken, in `project`
-- below — it is the part of the factory these four seams can actually use.

local h = _G.KCM_TEST
local test = h.test

-- Read a named member list off a real namespace. Reads THROUGH the metatable, so
-- the live Settings.Helpers yields the library members it delegates to rather
-- than only its own keys.
--
-- A name that does not resolve on the LIVE arm is a FAILURE, not an omission.
-- This was `out[k] = tbl and tbl[k]`, and a nil simply left the key off the
-- projection: assertSurfaceParity walks `pairs(live)`, so a seam entry the
-- library had renamed — or one typed wrong — quietly stopped being checked, and
-- the case stayed green over a list that got shorter with every re-vendor.
-- Nothing said so and nothing could: the failure mode of a hand-written member
-- list is that it degrades in silence, which is the same shape of bug this whole
-- file exists to catch one level down. Measured against today's tree all four
-- lists resolve whole, so this reddens nothing now — it is what keeps the lists
-- above from quietly meaning less than they say later.
local function project(tbl, keys, label)
    local out, absent = {}, {}
    for _, k in ipairs(keys) do
        local v = tbl and tbl[k]
        if v == nil then absent[#absent + 1] = k else out[k] = v end
    end
    if #absent > 0 then
        h.fail(("%s: %d name(s) do not resolve on the LIVE arm, so they are not being "
            .. "checked at all — %s"):format(label, #absent, table.concat(absent, ", ")), 2)
    end
    return out
end

-- ── LibKa0s-Core-1.0, at core/CoreSetup.lua ────────────────────────────────
--
-- Member list produced by:
--     grep -n '^KCM\.[A-Za-z0-9_]* =\|^function KCM\.' core/CoreSetup.lua
-- which is the seam's live surface, whole: LIBKA0S_MISSING (:30), ColorDecode
-- (:54), IsConcatSafe (:118), SafeToString (:119), SwatchColor (:141), Say
-- (:169), MakeCloseButton (:186). The grep is the list, and the list is every
-- row it returns — a member the grep finds and this table omits is an
-- omission encoded by SILENCE, which is the one thing the header above says
-- this file exists to stop.
--
-- Where each comes from, because the branch at core/CoreSetup.lua:66 is not the
-- whole story: LIBKA0S_MISSING and ColorDecode sit ABOVE the branch, so both
-- arms share the same object — they are this addon's own message and its own
-- storage contract, not anything the library owns. IsConcatSafe, SafeToString,
-- SwatchColor and Say are re-declared inside the degraded arm as real
-- fallbacks. MakeCloseButton is published PAST the branch's `return`, so the
-- degraded arm has none, on purpose — see CORE_LIVE_ONLY.
local CORE_SEAM = {
    "LIBKA0S_MISSING", "ColorDecode", "IsConcatSafe", "MakeCloseButton",
    "SafeToString", "Say", "SwatchColor",
}

-- Live-only ON PURPOSE, argued at core/CoreSetup.lua:171-188 and pinned by
-- tests/test_coresetup.lua:200-207. KCM.MakeCloseButton has NO caller in this
-- addon today: it exists so a future modal or copy window draws the shared
-- close mark without anyone remembering that lib.MakeCloseButton wants the
-- addon FOLDER name as its third argument (anti-pattern #64). With nothing to
-- degrade, absence is the honest degraded answer rather than a stub that builds
-- no button, and the entry here is what makes that a DECISION on the record
-- instead of a hole — the whole point of `ignore` per the header.
--
-- Deliberate deadness is the reason this is on a list rather than deleted
-- (CONSUMABLEMASTER-R-10, folded into -R-03): a wrapper with the right
-- signature and no caller is cheaper to keep than a two-argument passthrough
-- someone writes later, which is green in every suite and wrong on screen.
local CORE_LIVE_ONLY = { "MakeCloseButton" }

test("Parity: the LibKa0s-Core stub carries the whole live seam", function(t)
    local live     = h.loader.loadPure()
    local degraded = h.loader.loadPureDegraded()
    h.assertSurfaceParity(project(live, CORE_SEAM, "CORE_SEAM"), degraded, "KCM Core seam",
        CORE_LIVE_ONLY)
    -- SwatchColor is called on every repaint of every button (three files reach
    -- it), so a nil one would take the macro bar's whole appearance pass down.
    -- The class color needs the library; the swatch does not, which is why the
    -- degraded arm answers the stored color rather than nothing.
    t.eq(type(degraded.SwatchColor), "function", "KCM.SwatchColor survives a degraded load")
    -- 177 call sites reach KCM.Say, and core/SlashCommands.lua captures it at
    -- FILE SCOPE, so a nil Say takes the whole of /cm down with it rather than
    -- one line. Worth stating separately from the set assertion.
    t.eq(type(degraded.Say), "function", "KCM.Say survives a degraded load")
end)

-- ── LibKa0s-DebugLog-1.0, at core/DebugLogSetup.lua ──────────────────────────
--
-- Member list produced by:
--     grep -n '^function DL\.\|^DL\.' core/DebugLogSetup.lua
-- which is the live surface (:181-:211). The degraded branch (:57-:104)
-- publishes seven of them.
local DEBUGLOG_SEAM = {
    "AddLine", "IsEnabled", "Show", "Hide", "Clear", "ShowCopy", "RefreshHeader",
    "UpdateScrollBar", "UpdateStatus", "Toggle_Window", "IsWindowShown",
    "SetEnabled", "Toggle", "FormatPlain", "FormatColored", "instance",
}

-- Live-only ON PURPOSE, each argued at core/DebugLogSetup.lua:102-114:
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
--     which returns nothing at all: even core/DebugLogSetup.lua reaches them as
--     `DL.`, so there is no caller anywhere left raising.
--     (`instance` itself is the library object; there is no library to publish.)
local DEBUGLOG_LIVE_ONLY = {
    "AddLine", "Clear", "ShowCopy", "RefreshHeader", "UpdateScrollBar",
    "UpdateStatus", "FormatPlain", "FormatColored", "instance",
}

test("Parity: the LibKa0s-DebugLog stub carries the whole live seam", function(t)
    local live     = h.loader.loadConsole()
    local degraded = h.loader.loadConsole(true)
    h.assertSurfaceParity(project(live.DebugLog, DEBUGLOG_SEAM, "DEBUGLOG_SEAM"), degraded.DebugLog,
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
    h.assertSurfaceParity(project(live.SlashCommands, SLASH_SEAM, "SLASH_SEAM"), degraded.SlashCommands,
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
-- The grep is over BOTH spellings, because the page files alias the table:
--     grep -rhno 'Helpers\.[A-Za-z_]*' core/ modules/ settings/ | sort -u
--     grep -rhno '\bH\.[A-Za-z_]*'    settings/                | sort -u
-- The second is the one that grew with this adoption -- the composers, the row
-- engine and the strip are all reached as `H.` from a page file.
--
-- LSMValues came OFF this list at M4-C1, and how it left matters, because the
-- grep as written would have kept it: the grep matches an ASSIGNMENT as readily
-- as a call, and the only hit it had left was settings/Panel.lua defining the
-- host wrapper. Delete the wrapper -- which M4-C1 did, its last real caller
-- having gone with M3-04's issue-#15 cleanup -- and the grep falls silent. That
-- is the right answer here rather than an omission: the name still resolves
-- through __index to the library's, but nothing on this side of the seam calls
-- it, and a degraded install has no instance to resolve to, so listing it would
-- demand a stub for a member no page reads.
local OPTIONS_SEAM = {
    "AddSpacer", "AttachTooltip", "BUTTON_PAIR_REL", "BorderGroup",
    "BuildAboutContent", "Button", "ButtonPair", "CLASS_COLOR_NOTE",
    "ColorDecode", "ColorPair",
    "CreatePanel", "CustomCheckbox", "EnsureScroll", "EnumValues", "FindSchema",
    "FontGroup", "Get", "Grid", "Label", "MasterControls",
    "PageBanner", "RefreshAllPanels", "RefreshScalars", "RegisterRows",
    "RenderField", "RenderRows", "ResetScroll", "Resolve", "SECTION_HEADING_H",
    "SESSION_PATHS", "Section", "Set", "SetAndRefresh", "SetRenderer", "TabStrip",
    "ValidateSchema", "ValidateSchemaValue", "instance",
}

-- Live-only ON PURPOSE. With the library absent the panel is not registered AT
-- ALL — settings/Panel.lua's registerPanel returns before a single page renders —
-- so every member below is unreachable degraded by construction, and supplying it
-- would mean keeping a verbatim copy of the chrome the adoption removed.
--
-- What is NOT on this list is the point of the case: RefreshAllPanels and
-- RefreshScalars are called UNCONDITIONALLY on paths a degraded install reaches
-- (SetAndRefresh after every schema write, O.Refresh off the PANEL_REFRESH bus
-- message), so they must be real no-ops on both arms — which is the finding this
-- seam actually had.
--
-- The FOUR COMPOSERS are deliberately NOT on this list. They are called inside
-- schema-row literals at FILE LOAD, which is the one position options-ui-§1 says
-- a stub must cover, so settings/OptionsSetup.lua's degraded arm publishes them
-- answering an empty row list. What that costs is measured, not assumed —
-- tests/test_settingsui.lua compares the schema row count on both arms.
local OPTIONS_LIVE_ONLY = {
    "AddSpacer", "AttachTooltip", "BUTTON_PAIR_REL", "CLASS_COLOR_NOTE",
    "CustomCheckbox", "EnsureScroll", "Grid", "PageBanner", "RenderField",
    "RenderRows", "ResetScroll", "SECTION_HEADING_H", "SetRenderer", "TabStrip",
    "instance",
}

test("Parity: the LibKa0s-Options stub carries the whole live seam", function(t)
    local live     = h.loader.loadWithSchema()
    local degraded = h.loader.loadWithSchemaDegraded()
    h.assertSurfaceParity(project(live.Settings.Helpers, OPTIONS_SEAM, "OPTIONS_SEAM"),
        degraded.Settings.Helpers, "KCM.Settings.Helpers seam", OPTIONS_LIVE_ONLY)
    -- The two refresh tiers, called unconditionally after a degraded write. Bound
    -- as `UI and UI.X` they read back nil and the bare call raised AFTER the
    -- write had already landed, so a pcall'ing caller saw a failure over a
    -- mutation that had persisted.
    local H = degraded.Settings.Helpers
    t.eq(type(H.RefreshAllPanels), "function", "RefreshAllPanels is callable degraded")
    t.eq(type(H.RefreshScalars), "function", "RefreshScalars is callable degraded")
end)
