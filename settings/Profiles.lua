-- settings/Profiles.lua — the Profiles page.
--
-- AceDBOptions' create / switch / copy / reset / delete UI, plus its per-character
-- / per-class / per-realm / per-faction / default scope choices, hosted inside
-- this addon's own canvas. Every setting ConsumableMaster stores is in db.profile
-- -- the master controls, every category's lists and composite sections, the stat
-- priorities, the macro bar and its slot order, even the macro fingerprints -- so
-- this page reaches all of it. The perf capture ring is a SavedVariable of its
-- own, and the debug console's visibility is session state; neither is in a
-- profile, and neither moves when one does.
--
-- ---------------------------------------------------------------------------
-- THE ONE PLACE AceConfig IS USED (options-ui-§3, library-stack-§2)
-- ---------------------------------------------------------------------------
--
-- Every other page is drawn by this addon from KCM.Settings.Schema, and AceConfig
-- is not in the picture at all. This page is the exception for one reason: the
-- options table is not ours. AceDBOptions generates it, and re-expressing it as
-- schema rows would mean keeping a copy of AceDB's own profile model that goes
-- stale the first time AceDB adds a scope. The exception is scoped to CONTENT:
-- the canvas, the header, the breadcrumb and the combat refusal are
-- Helpers.CreatePanel and Helpers.SetRenderer, as on every other page.
--
-- It carries no schema rows, so it draws no tab strip -- it is one of the two
-- pages options-ui-§13 exempts, the landing page being the other.
--
-- ---------------------------------------------------------------------------
-- NO DEFAULTS BUTTON
-- ---------------------------------------------------------------------------
--
-- "Restore defaults" here would mean deleting the player's profiles. The panel
-- is created with no `defaultsAction`, which is what makes Helpers.CreatePanel
-- ask the library for `defaultsButton = false`, and the same rule is enforced a
-- second time by the global reset's veto (KCM.Settings.VetoedFromResetAll,
-- settings/OptionsSetup.lua).
--
-- ---------------------------------------------------------------------------
-- WHEN THE PAGE REDRAWS
-- ---------------------------------------------------------------------------
--
-- The widget tree is AceConfigDialog's, and it re-reads the active profile only
-- when the dialog is fed again. A change made ON this page needs nothing --
-- AceConfigDialog re-opens its container after every control it activates. A
-- profile changed from anywhere else -- `/cm resetall`, Reset all settings, a
-- `/run` -- lands on the profile handler's one PROFILE_CHANGED, and the private
-- listener at the foot of Build turns that into a redraw: now if the page is on
-- screen, on its next show if not (H.RefreshPanel).
--
-- It redraws on THAT and on nothing else. SetRenderer puts the page on the
-- library's structural fan-out, and the pipeline publishes a debounced
-- PANEL_REFRESH after every recompute -- every loot, every bag change. A renderer
-- that re-Opened on each of those would tear AceConfigDialog's tree down under an
-- open dropdown (options-ui-§11: re-render only when what invalidates the layout
-- changed). So the renderer draws once per profile event, counted.

local _, NS = ...
local KCM = NS
local L = KCM.L

local PAGE = "profiles"
local APP  = "ConsumableMaster-Profiles"

-- Bumped by every PROFILE_CHANGED. A page redraws when the count it last drew at
-- is behind this one; first show counts as behind.
local profileEvents = 0

--- The four libraries this page needs, or nil when any is missing. Silent-mode,
--- every one (library-stack-§4): a build without the AceConfig payload loses this
--- page and nothing else.
local function aceLibs()
    if not LibStub then return nil end
    local libs = {
        dbOptions = LibStub("AceDBOptions-3.0",    true),
        config    = LibStub("AceConfig-3.0",       true),
        dialog    = LibStub("AceConfigDialog-3.0", true),
        gui       = LibStub("AceGUI-3.0",          true),
    }
    if not (libs.dbOptions and libs.config and libs.dialog and libs.gui) then return nil end
    return libs
end

--- The settings helpers this page is built from, or nil on a degraded load.
local function helpers()
    local H = KCM.Settings and KCM.Settings.Helpers
    if not (H and H.CreatePanel and H.SetRenderer and H.RefreshPanel) then return nil end
    return H
end

--- An AceGUI SimpleGroup parented to the page body. AceConfigDialog:Open accepts
--- any AceGUI container as its target, so the AceDBOptions widgets land inside
--- this canvas instead of a second floating window over the Settings panel.
local function newContainer(AceGUI, ctx)
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Fill")
    container.frame:SetParent(ctx.body)
    container.frame:ClearAllPoints()
    container.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      8, -8)
    container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8,  8)
    -- SHOWN EXPLICITLY. A SimpleGroup's frame starts out shown only when AceGUI
    -- constructs it; AceGUI:Release hides a frame before pooling it, and neither
    -- AceGUI:Create nor the widget's OnAcquire shows a pooled one again, nor does
    -- AceConfigDialog:Open. So whenever the process-wide SimpleGroup pool is
    -- non-empty -- any AceGUI page, in any addon, released one earlier -- this
    -- container comes back hidden and AceConfigDialog fills a frame nobody can
    -- see: a blank Profiles page.
    container.frame:Show()
    return container
end

--- The draw PROFILE_CHANGED asks for. A PRIVATE bus target: CallbackHandler keys a
--- callback by (message, target), so a second PROFILE_CHANGED receiver on a shared
--- object would silently replace the first (architecture-§4, anti-pattern #32).
local function listen(H, ctx)
    local bus = KCM.NewBusTarget and KCM.NewBusTarget()
    if not (bus and KCM.MSG and KCM.MSG.PROFILE_CHANGED) then return end
    bus:RegisterMessage(KCM.MSG.PROFILE_CHANGED, function()
        profileEvents = profileEvents + 1
        H.RefreshPanel(ctx, true)
    end)
end

local function Build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local libs, H = aceLibs(), helpers()
    if not (libs and H) then return nil end

    -- An options table built over a nil db raises inside AceDBOptions instead of
    -- here, so a db that failed to initialize costs this page, not the panel.
    if not (KCM.db and KCM.db.profile) then return nil end

    -- Registered once per build. The table AceDBOptions returns reads KCM.db live,
    -- so a profile change does not need it rebuilt -- only redrawn.
    libs.config:RegisterOptionsTable(APP, libs.dbOptions:GetOptionsTable(KCM.db))

    local ctx = H.CreatePanel("KCMProfilesPanel", L["Profiles"], { panelKey = PAGE })
    local container = newContainer(libs.gui, ctx)

    local drawnAt
    H.SetRenderer(ctx, function()
        if drawnAt == profileEvents then return end
        drawnAt = profileEvents
        libs.dialog:Open(APP, container)
    end)
    listen(H, ctx)

    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Profiles"])
end

if KCM.Settings and KCM.Settings.RegisterTab then
    KCM.Settings.RegisterTab(PAGE, Build)
end
