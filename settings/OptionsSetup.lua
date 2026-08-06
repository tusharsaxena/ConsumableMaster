-- settings/OptionsSetup.lua — the LibKa0s-Options-1.0 seam.
--
-- options-ui-§1 wants the library seam in its own file, named for what it does,
-- so a reader can answer "what does this addon take from the options library,
-- and what does it keep?" without reading a thousand-line panel framework. This
-- file is that answer, and it is the ONLY place the library is constructed
-- (CM-A-14).
--
-- The split is by ownership, not by convenience:
--   * HERE — the library instance: the panel factory, the lazy Defaults button,
--     the scroll container, the always-visible scrollbar patch, the row makers,
--     and the codecs/thunks that teach the library this addon's conventions.
--   * settings/Panel.lua — the addon's own half: the schema rows, Resolve /
--     Get / Set / FindSchema / ValidateSchema, the SetAndRefresh write seam, the
--     wrappers that shadow a library member, and the registration bootstrap.
--
-- What this file publishes, and all that settings/Panel.lua reads back:
--   KCM.Settings.Helpers      — the shared table, with the instance installed as
--                               its __index when the library is present.
--   KCM.Settings.optionsUI    — the instance itself, or nil on a degraded load.
--   KCM.Settings.PANEL_TITLE  — the breadcrumb's left half, shared so the two
--                               files cannot disagree about the brand string.
--
-- Loads BEFORE settings/Panel.lua (see the TOC's `# Settings` block): Panel.lua
-- takes the instance as a file-scope local, so the instance has to exist first.

local _, NS = ...
local KCM = NS
local L = KCM.L

-- Silent-mode, like every other LibStub call in this addon (library-stack-§4).
-- AceGUI is an OptionalDep: on an install that lacks it the hard form raises
-- during load and takes the whole addon down, where the silent form yields nil
-- and lets the degraded arm below do its job.
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

KCM.Settings = KCM.Settings or {}

-- Created here rather than in settings/Panel.lua because this file loads first;
-- Panel.lua's `KCM.Settings.Helpers or {}` then picks up this same table, which
-- is what keeps the `get`/`set` thunks below pointed at the live Helpers.
local Helpers = KCM.Settings.Helpers or {}
KCM.Settings.Helpers = Helpers

local PANEL_TITLE = L["Ka0s Consumable Master"]
KCM.Settings.PANEL_TITLE = PANEL_TITLE

-- ---------------------------------------------------------------------
-- LibKa0s-Options-1.0
-- ---------------------------------------------------------------------
--
-- What the library supplies is chrome: the panel factory, the lazy Defaults
-- button, the scroll container and the always-visible scrollbar patch. That
-- last block was hand-transcribed from KickCD — the comment above it said so
-- outright — and sits in the same shape in every Ka0s addon, which is the drift
-- the library exists to end. The metrics were compared constant by constant
-- before the swap (padding, header height, the three section spacers, the 0.492
-- button-pair inset, the scroll insets, the 20px gutter, the thumb tints, the
-- breadcrumb atlas) and they are identical, so nothing moves on screen.
--
-- Adopted in PARTS, deliberately. The schema-row widget makers in
-- settings/Panel.lua are NOT the library's: its dropdown reads `values` as a key
-- map where ours is an ordered array of { value =, text = }, its color picker
-- defaults hasAlpha to false where ours defaults it to true (all seven pickers
-- would lose their alpha slider), and its slider commits on mouse-up where ours
-- commits live — which is the whole point of the Macro Bar page's drag preview.
-- Recorded in closed issue #22 (LIBKA0S-04).

local optionsLib = LibStub and LibStub("LibKa0s-Options-1.0", true)
local UI

-- AceGUI is a conjunct, not an afterthought: the instance hands widgets back on
-- every draw path, so an instance built without one would publish a seam that
-- raises on first use instead of degrading at load.
if optionsLib and AceGUI then
    UI = optionsLib:New({
        -- The one field lib:New validates, and it raises rather than warns: an
        -- anonymous canvas is one /framestack cannot attribute and two addons
        -- can collide on, with nothing visible in game. Reproduces the frame
        -- name this panel has always carried.
        mainPanelName = "KCMMainPanel",

        -- The breadcrumb's left half, so a sub-page reads "<brand> > <page>".
        parentTitle = PANEL_TITLE,

        -- A thunk, not `KCM.Say` bare: the library snapshots the printer at
        -- :New, so a captured value would freeze the load-time function object.
        -- Same note as core/CoreSetup.lua's sink and core/DebugLogSetup.lua's
        -- print. Inert in the adopted scope — both lines that reach it live in
        -- the panel-registry half we do not use — but passed so a later step
        -- cannot leak an untagged line.
        print = function(line) KCM.Say(line) end,

        -- The row makers are the library's now (LIBKA0S-04, issue #22), so it needs the
        -- two things this addon's own makers knew and it could not guess.
        --
        -- Colors are stored POSITIONALLY — { r, g, b, a } — which is the shape
        -- the Ka0s options color widget has always written. The library's
        -- default codec is the named-key form, so without this every picker
        -- would read white and write a table nothing here can unpack.
        colorDecode = function(c)
            c = type(c) == "table" and c or {}
            return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
        end,
        colorEncode = function(r, g, b, a) return { r, g, b, a or 1 } end,

        -- Sliders commit on the drag, not just on release. The Macro Bar page's
        -- number rows drive the bar itself — button size, spacing, scale,
        -- alpha — so the live preview IS the feature. Release-only is the
        -- library's default and would have taken it away silently.
        sliderCommit = "change",

        -- Resolved at CALL time, never captured: LibSharedMedia is optional and
        -- other addons register media into it after this file loads, so a list
        -- read once at :New would freeze whatever happened to exist first.
        getLSM = function() return LibStub and LibStub("LibSharedMedia-3.0", true) end,

        -- Both resolved off the shared Helpers table at CALL time, because the
        -- functions they name are declared in settings/Panel.lua, which has not
        -- loaded yet when this runs.
        get = function(path) return Helpers.Get(path) end,
        set = function(path, value) Helpers.SetAndRefresh(path, value) end,
    })

    -- Restated because the library resolves AceGUI once at :New and re-resolves
    -- it only inside its own CreateOptionsPanel, which this addon never calls.
    UI.AceGUI = AceGUI

    -- THE binding, replacing the hand-written re-export list. Every member the
    -- library publishes — AttachTooltip, EnsureScroll, PatchAlwaysShowScrollbar,
    -- SetRenderer, AddSpacer, RenderField, RefreshAllPanels, RefreshScalars and
    -- the rest — is now reachable on Helpers without being copied, so the two
    -- tables cannot drift and no member can be silently absent. The addon's own
    -- wrappers stay OWN keys on Helpers and shadow the library's same-named
    -- function, which is what keeps Section / CreatePanel / LSMValues able to
    -- call the instance's version without recursing into themselves.
    setmetatable(Helpers, { __index = UI })

    -- The instance, so the suite can assert IDENTITY against the library rather
    -- than lookalike behavior. Mirrors KCM.DebugLog.instance.
    Helpers.instance = UI
else
    -- Degraded install: there is no instance to delegate to, and every
    -- library-owned member stays absent — a page cannot be built without the
    -- library's chrome, so nothing that would draw one is reachable anyway.
    --
    -- The two refresh tiers are the exception, and they are supplied as real
    -- no-ops rather than left nil because they are called UNCONDITIONALLY on
    -- paths a degraded install still reaches: Helpers.SetAndRefresh calls
    -- RefreshScalars after every schema write, and O.Refresh calls
    -- RefreshAllPanels off the PANEL_REFRESH bus message that Pipeline fires on
    -- every recompute. Bound to `UI and UI.X` they read back nil and the bare
    -- call raised "attempt to call field 'RefreshAllPanels' (a nil value)" —
    -- in SetAndRefresh's case AFTER the write had already landed, so a pcall'ing
    -- caller saw a failure over a mutation that had persisted. With nothing on
    -- screen there is nothing to refresh, so doing nothing is the correct body.
    Helpers.RefreshAllPanels = function() end
    Helpers.RefreshScalars   = function() end
end

-- nil on a degraded load, which is exactly what settings/Panel.lua derives its
-- `libAbsent` from — one source of truth for "can a panel be built at all?".
KCM.Settings.optionsUI = UI
