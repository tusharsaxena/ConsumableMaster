-- core/DebugLogSetup.lua — the addon's half of LibKa0s-DebugLog-1.0.
--
-- The console window itself — the drag bar, the flat Copy/Clear/× buttons, the
-- ScrollingMessageFrame, the hand-driven scrollbar, the line counter, the copy
-- box, the Debug: ON/OFF header toggle — used to live here in full. It exists in
-- every Ka0s addon, hand-transcribed, drifting one hex digit at a time, so it is
-- libs/LibKa0s/DebugLog.lua now and this file is only the part that is ours:
-- which font it renders in, where the enable flag actually lives, what the
-- [Init] summary says, who gets repainted when the window opens, and what
-- happens when the library is not installed.
--
-- KCM.DebugLog keeps its exact current shape — a flat table of DOT-callable
-- functions. The library speaks methods (D:Add), and three of its names either
-- collide with ours or inverts one: its `Toggle` flips the WINDOW while ours
-- flips the FLAG. Publishing the instance directly would silently invert
-- `/cm debug`, so the forwarders below are an explicit facade rather than an
-- alias table. ~180 call sites and the whole suite depend on the flat shape.
--
-- Register the shipped monospace font with LibSharedMedia (optional dependency).
--
-- Standard-compliant, not a deviation (Ka0s debug-logging-§2 + docs/scope.md): the
-- standard REQUIRES a shipped monospace font for the debug console and names
-- JetBrains Mono the reference font. The addon is otherwise Blizzard-default in all
-- styling; this developer-facing console needs a fixed-width font for the aligned
-- `<HH:MM:SS> | [tag] …` columns and Blizzard ships no monospace font object, so the
-- standard marks the shipped console font a sanctioned styling exception (audits MUST
-- NOT flag it). Not user-configurable and no LSM picker by design (the LibSharedMedia
-- registration lives in core/MediaSetup.lua now and exists only to expose the face to
-- other addons). FONT_FALLBACK below is Blizzard's own font for the no-library path —
-- the library has no fallback of its own, it calls SetFont on whatever path the
-- descriptor hands it.

local addonName, NS = ...
local KCM = NS
KCM.DebugLog = KCM.DebugLog or {}
local DL = KCM.DebugLog

-- THE BYTES ARE THE LIBRARY'S NOW. This file used to ship its own copy of the
-- face under a media folder of its own and register it with LibSharedMedia
-- against a hardcoded absolute path into this addon. LibKa0s carries the same
-- face and registers the same key against its own copy, and core/MediaSetup.lua
-- loads first — so this file's registration was quietly overwriting the
-- library's on every login with a path only this addon had. One key, one set of
-- bytes, one owner; the registration moved to the seam and the local copy is
-- gone.
local FONT_NAME     = "JetBrains Mono"
-- A REAL CLIENT FONT, and that is the entire point of this rung. SetFont accepts
-- a path to a file that is not there, fails to load it, and the text simply does
-- not draw — no error, no console. Blizzard's narrow Arial is the nearest thing
-- the client ships to fixed width, so a degraded install loses the column
-- alignment and keeps every line on screen.
local FONT_FALLBACK = [[Fonts\ARIALN.TTF]]
local FONT_SIZE     = 10   -- standard reference size (debug-logging-§2)

local function fontPath()
    return (KCM.MediaFont and KCM.MediaFont(FONT_NAME)) or FONT_FALLBACK
end

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
    -- No console, but the addon still has to answer `/cm debug`, still has to
    -- arm logging, and the options panel still calls in on every refresh. The
    -- cause clause is core/CoreSetup.lua's (one absence, said the same way
    -- everywhere); this seam appends only what is unavailable HERE.
    local announced = false
    local function notice()
        if announced then return end
        announced = true
        if KCM.Say then
            KCM.Say(KCM.LIBKA0S_MISSING ..
                ", so the on-screen debug console is unavailable; diagnostics go to chat.")
        end
    end

    function DL.IsEnabled() return KCM.State and KCM.State.debug == true end

    function DL.SetEnabled(on)
        on = on and true or false
        if KCM.State then KCM.State.debug = on end
        if KCM.Say then
            KCM.Say("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
        end
        if on then notice() end
        if KCM.Options and KCM.Options.Refresh then KCM.Options.Refresh() end
        return on
    end

    function DL.Toggle() return DL.SetEnabled(not DL.IsEnabled()) end

    -- Show and Toggle_Window are the two entry points a user reaches for on
    -- purpose, so they are the two that explain themselves. Hide and
    -- IsWindowShown stay SILENT: `settings/General.lua:79` calls Hide from the
    -- Defaults action, and IsWindowShown is a bare status query with no
    -- production caller at all (only the suites read it), so a notice on
    -- either would announce a window the user never asked to see. The
    -- [Debug console] checkbox does not route through this seam either:
    -- `settings/General.lua:121-127` builds it from
    -- `DL.instance:ConsoleCheckbox()`, and this path publishes no instance, so
    -- the checkbox is simply not built.
    function DL.Show() notice() end
    function DL.Toggle_Window() notice() end
    function DL.Hide() end
    function DL.IsWindowShown() return false end

    -- Deliberately publishes NO instance and NO AddLine. core/Debug.lua's
    -- emitter probes `DL and DL.instance` (`core/Debug.lua:39-40`) to decide
    -- whether a console exists, and falls back to the chat frame when it does
    -- not — withholding the instance is exactly what re-arms that fallback.
    -- AddLine is withheld for the matching reason: its one production caller is
    -- `core/PerfSetup.lua:98`, inside a table that file only ever builds when
    -- the LibKa0s Perf major loaded (`core/PerfSetup.lua:46` returns
    -- otherwise), so a no-op here would swallow diagnostics rather than degrade
    -- anything. Same for Clear / ShowCopy / RefreshHeader / UpdateScrollBar /
    -- UpdateStatus / the formatters: no consumer outside this file, so there is
    -- nothing to degrade.
    return
end

local D = lib:New({
    -- Seeds the frame globals: <name>DebugWindow. Exactly reproduces the old
    -- WIN_NAME, which is what /framestack and any user layout addon knows —
    -- the vararg IS "ConsumableMaster", and taking it from the vararg is what
    -- keeps a folder rename from silently desyncing the frame names.
    name  = addonName,

    -- NOT a duplicate of `name`, and deliberately beside it: `name` seeds frame
    -- globals, `addonName` is the addon FOLDER the library builds its texture
    -- paths from. Same string here, different questions everywhere, and a
    -- library that is vendored cannot work the second one out for itself. With
    -- it the console's title bar draws the shared copy, clear and close marks on
    -- both windows; without it the library falls back to word buttons and a
    -- multiplication sign, which is exactly what a degraded install should get.
    addonName = addonName,

    -- The library appends its own " — Debug", composing today's literal title.
    title = "Consumable Master",

    -- Resolved EAGERLY and as a string, never lazily: lib:New type-checks the
    -- field and raises at construction, which would abort this whole file's
    -- load rather than just the window. Safe here — LibSharedMedia is vendored
    -- far above us in the TOC and the Register call is directly overhead.
    font     = fontPath(),
    fontSize = FONT_SIZE,

    -- The library stores no flag; these two closures ARE the single truth, and
    -- they read and write exactly what core/Debug.lua's gate reads, so the sink
    -- and the console can never disagree.
    isEnabled  = function() return KCM.State and KCM.State.debug == true end,
    setEnabled = function(on)
        if KCM.State then KCM.State.debug = on end
        -- The one thing the library's own SetEnabled has no hook for. Resolved
        -- at call time: settings/Panel.lua creates KCM.Options long after this
        -- file loads.
        if KCM.Options and KCM.Options.Refresh then KCM.Options.Refresh() end
    end,

    -- A thunk, not `KCM.Say` bare. The library snapshots the printer once at
    -- :New, so a captured value would freeze the load-time function object and
    -- every later swap of KCM.Say — including the suite's — would go unseen.
    -- core/CoreSetup.lua's `sink` carries the identical note.
    print = function(line) KCM.Say(line) end,

    -- The CONTENT of the session summary; the library owns when it is emitted
    -- (on enable, after the bracket line — the flag is session-only and off at
    -- login, so a load-time summary would always be gated off). Returns nil
    -- rather than a '?'-filled line when there is no DB yet: the library emits
    -- whatever it is handed, so a partial line would appear where none does now.
    initSummary = function()
        if not (KCM.db and KCM.db.global) then return nil end
        local s = KCM.SafeToString or tostring
        local profileKey = KCM.db.GetCurrentProfile and KCM.db:GetCurrentProfile() or "?"
        return ("%s v%s, schema v%s, profile '%s'"):format(
            "Consumable Master", s(KCM.VERSION), s(KCM.db.global.schemaVersion), s(profileKey))
    end,

    -- Fires on both OnShow and OnHide. Mandatory, not decorative: Escape and the
    -- × both hide the window WITHOUT going through the options checkbox's own
    -- set(), so without this the panel's [Debug console] row stays checked over
    -- a closed console.
    onVisibilityChanged = function()
        if KCM.Options and KCM.Options.Refresh then KCM.Options.Refresh() end
    end,

    -- Composes the library's console-checkbox tooltip. Inert today —
    -- settings/General.lua still renders its own checkbox — but passed so the
    -- descriptor is already right if that is adopted, and because omitting it
    -- silently selects the no-slash wording.
    slash = "/cm",

    -- `skin` is deliberately NOT passed: Core.SKIN IS the shared Ka0s window edge
    -- that every Ka0s window wears (standalone-windows), so taking the
    -- library's is the whole point — a table of our own would draw a console that
    -- matched this addon and no other, and a plain backdrop table would also drop
    -- the bg / border / innerBorder / divider / title arrays ApplySkin guards for.
    -- Nor `L` (the library's English already matches ours) nor `safeToString` (it
    -- defaults to Core's, which is the same function object KCM.SafeToString is
    -- bound to).
})

-- The public surface, unchanged in name, arity and return value. Plain
-- functions, not methods: core/Debug.lua (IsEnabled), core/PerfSetup.lua
-- (AddLine, Show) and settings/General.lua (SetEnabled, Hide) all dot-call,
-- and three suites reach KCM.DebugLog.AddLine as their interception seam.
function DL.AddLine(tag, msg)  D:Add(tag, msg) end
function DL.IsEnabled()        return D:IsEnabled() end
function DL.Show()             D:Show() end
function DL.Hide()             D:Hide() end
function DL.Clear()            D:Clear() end
function DL.ShowCopy()         D:ShowCopy() end
function DL.RefreshHeader()    D:RefreshHeader() end
function DL.UpdateScrollBar()  D:UpdateScrollBar() end
function DL.UpdateStatus()     D:UpdateStatus() end

-- Window, not flag. The library spells this one `Toggle`; ours has always meant
-- the other thing (below), and a name-for-name alias would invert `/cm debug`.
function DL.Toggle_Window()    D:Toggle() end
function DL.IsWindowShown()    return D:IsShown() end

-- The library's SetEnabled returns nothing; ours has always answered the new
-- flag, and the slash layer and the suite both read it.
function DL.SetEnabled(on)
    D:SetEnabled(on)
    return not not on
end

-- Flag, not window. Deliberately NOT bound to the library's `Toggle`.
function DL.Toggle() return DL.SetEnabled(not DL.IsEnabled()) end

DL.FormatPlain, DL.FormatColored = lib.FormatPlain, lib.FormatColored

-- The instance itself, so the suite can assert IDENTITY against the library
-- rather than lookalike behavior, and so D:FindLine / D:BufferSize / D:CopyText
-- are reachable without monkeypatching the forwarders they bypass.
DL.instance = D
