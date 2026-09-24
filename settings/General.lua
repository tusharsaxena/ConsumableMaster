-- settings/General.lua — General page.
--
-- TWO TABS on a pinned strip (options-ui-§13):
--
--   * Master controls — the canonical eight (options-ui-§15), COMPOSED by the
--     library's MasterControls rather than typed out here, and closed by the
--     [Reset position] | [Reset all settings] button pair. It is the FIRST tab
--     on the page, which is the whole rule: the one thing every player looks for
--     first is in the same place, under the same words, in every Ka0s addon.
--
--   * Maintenance — the three targeted verbs this addon has and no other Ka0s
--     addon does: force a resync, force a macro rewrite, and drop every priority
--     override. None of them is a setting, so none of them is a row.
--
-- THE MAINTENANCE TAB WAS FOLDED AWAY AND CAME BACK. Between 2026-09-03 and
-- 2026-09-09 its three buttons were a SUBSECTION appended after the canonical
-- block, on the reasoning that a whole tab over three buttons pressed about once
-- a month was not worth the strip position. 1.6.0 restored the tab. Nothing
-- moved in storage either way — none of the three is a setting — and the page's
-- Defaults button, which walks `masterRows`, was unaffected by both changes.
--
-- A ONE-SECTION PAGE STILL DRAWS A STRIP (options-ui-§13). The rule is not a size
-- threshold: a player who has learned one Ka0s page has learned all of them, and
-- a page that drops its chrome for being small teaches the opposite.
--
-- THE TWO RESETS ARE DIFFERENT ACTS and are deliberately on different tabs.
-- [Reset all settings] is options-ui-§12's global reset — a profile reset, the
-- same act as Profiles → Reset Profile, behind the collection's one wording.
-- It raises core/SlashCommands.lua's KCM_CONFIRM_RESET, the popup `/cm resetall`
-- raises, and the combat refusal and repaint are KCM.ResetAllToDefaults' own, so
-- this door adds nothing of its own (ConsumableMaster-R-08).
-- [Reset all priorities] is targeted: it clears the added / blocked / pinned
-- items and the stat-priority overrides and leaves every other setting standing.
-- The button that used to sit here said the second and did the first.
--
-- Every execute path is shared with the slash commands so behavior stays
-- identical regardless of entry point.

local _, NS = ...
local KCM = NS
local L      = KCM.L
local H      = KCM.Settings.Helpers

-- Defaults come from KCM.dbDefaults, never a second literal (architecture-§5),
-- and they are handed to the composer so it emits THIS addon's shipped values
-- rather than its own generic ones.
local PROFILE_DEFAULTS = (KCM.dbDefaults and KCM.dbDefaults.profile) or {}
local BAR_DEFAULTS     = PROFILE_DEFAULTS.macroBar or {}

-- The minimap button's stored path, named ONCE. It is spelled in three places
-- otherwise — the composer spec below, the `neverReset` stamp beside it and the
-- page reset's carve-out — and settings/OptionsSetup.lua deliberately does not
-- hold a fourth copy (its veto reads the row's flag, not its path).
--
-- The PATH reads in the row's own sense -- SHOWN, like its label and like the
-- `/cm get` answer -- while the STORE stays LibDBIcon's `db.global.minimap.hide`
-- (WS-06). The path names the row, not the key: the row's get/set below invert
-- onto `hide`, so no SavedVariables moved with the rename and no `shown` key is
-- ever written beside it (anti-pattern #81). The old path, ending in `.hide`, is
-- no row any more and answers "Setting not found".
local MINIMAP_PATH = "global.minimap.shown"

-- The debug console row's path, named once for the same reason: the composer
-- spec and the store stamped on the row below.
local DEBUG_CONSOLE_PATH = "state.debugConsole"

-- The row no reset may reach (launcher-§3). Resolved at load, which is safe:
-- settings/OptionsSetup.lua publishes it above its library branch and the TOC
-- loads that file immediately before settings/Panel.lua and this one.
local neverReset = KCM.Settings.VetoedFromEveryReset

local function inCombatNotice(label)
    KCM.Say("in combat — %s deferred until regen.", label)
end

-- Invalidate what is cached, re-read the bags, recompute every pick, repaint.
-- Shared by the Force resync button and by the priority reset below, which needs
-- the same tail for the same reason -- and having it once is also what keeps
-- either of them under the complexity cap, since each guard in the ladder counts
-- as a decision (performance-§10).
local function resyncPipeline(reason)
    if KCM.TooltipCache and KCM.TooltipCache.InvalidateAll then
        KCM.TooltipCache.InvalidateAll()
    end
    if KCM.Pipeline and KCM.Pipeline.RunAutoDiscovery then
        KCM.Pipeline.RunAutoDiscovery(reason)
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute(reason)
    end
    H.RefreshAllPanels()
end

local function doForceResync()
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("resync")
    end
    resyncPipeline("options_resync")
end

local function doForceRewriteMacros()
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("macro writes")
    end
    if KCM.MacroManager and KCM.MacroManager.InvalidateState then
        KCM.MacroManager.InvalidateState()
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute("options_rewrite")
    end
    KCM.Say("rewrote all macros. If action bar icons still look stale, /reload to force the bars to refresh.")
    H.RefreshAllPanels()
end

-- The TARGETED reset the old "Reset all priorities" button claimed and did not
-- do: every category's added / blocked / pinned items and every spec's stat
-- priority override, and nothing else — the macro bar's appearance, the master
-- controls and the composite section orders are all left standing.
--
-- The item lists are the structural registry, so clearing them is the registry
-- writer's reset verb (architecture-§5): Selector.ResetAllBuckets, which walks
-- the stored shape, spec buckets included, and keeps `discovered`.
local function doResetAllPriorities()
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("reset")
    end
    if not (KCM.db and KCM.db.profile) then return end

    if KCM.Selector and KCM.Selector.ResetAllBuckets then
        KCM.Selector.ResetAllBuckets()
    end
    -- The stat overrides are a SETTING, not registry membership: `statPriority`
    -- is a whole-value row, emptied through the schema helper like every other
    -- stat-priority write.
    if KCM.Schema then KCM.Schema:Set("statPriority", {}) end

    resyncPipeline("options_reset_priorities")
end
KCM.ResetAllPriorities = doResetAllPriorities

-- A SECOND popup, because it warns about a genuinely narrower act. Sharing the
-- global reset's text would be the same lie the shared BUTTON was: a player told
-- "everything you have configured is discarded" and then finding their macro bar
-- untouched learns not to trust the warning.
StaticPopupDialogs["KCM_RESET_PRIORITIES"] = {
    text         = L["Wipe every category's added, blocked and pinned items and every spec's stat priority? Nothing else is changed, and discovered items are kept."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function() doResetAllPriorities() end,
}

-- ---------------------------------------------------------------------
-- The Master controls tab — COMPOSED, never typed out (options-ui-§15)
-- ---------------------------------------------------------------------
--
-- Eight rows, two per line, in the canonical order, closed by the two resets as
-- a button pair. Nine addons emit them from this one declaration, which is what
-- makes the order, the labels and the ranges identical without nine people
-- agreeing to be careful.
--
-- NOT frameless: modules/MacroBar.lua's buildBar calls SetMovable(true) on the
-- bar's container, so all four frame-only rows apply and none is omitted.
--
-- `keys` and `defaults` are what keep the STORED side unchanged. `Lock frame`
-- has always been `macroBar.locked` and stays there — the setting moved tabs, not
-- storage — and every default is read out of KCM.dbDefaults rather than restated.
--
-- MASTER SCALE, MASTER ALPHA and GENERAL VISIBILITY ARE NEW, and they are the
-- ADDON-WIDE ones. The macro bar's own `Bar scale`, `Bar opacity` and
-- `Combat visibility` stay on its page and are a different setting; the two
-- compose (modules/MacroBar.lua's masterScale / masterAlpha, and
-- MacroBarModel.ResolveVisibility for the intersection of the two visibilities).

local function applyBar()
    if KCM.MacroBar and KCM.MacroBar.Update then KCM.MacroBar.Update() end
end

local masterRows, masterTail = H.MasterControls{
    prefix    = "",
    page      = "general",
    addonName = "Consumable Master",
    -- Verbatim and unprefixed, because the console's visibility is SESSION state
    -- and lives outside the profile. The row's own get/set, stamped below, is
    -- what stores it.
    debugConsolePath = DEBUG_CONSOLE_PATH,
    -- Verbatim and unprefixed for the same reason, and for a different store:
    -- the minimap button's table is LibDBIcon's own and launcher-§3 fixes it in
    -- the GLOBAL store, outside this block's profile prefix. The row's own
    -- get/set, stamped below, is what stores it, and it is where the row's
    -- SHOWN/HIDDEN inversion lives -- the label says shown, the key says hidden.
    --
    -- Emitting this row also moves *Test mode* off `startsLine` inside the
    -- composer so the two pair as `[Minimap button] [Test mode]`; this addon has
    -- no test-mode row (its preview switch is Lock frame, the options-ui-§15
    -- exemption), so the minimap row opens its own line here.
    minimapPath = MINIMAP_PATH,
    keys      = { locked = "macroBar.locked" },
    defaults  = {
        enabled    = PROFILE_DEFAULTS.enabled,
        visibility = PROFILE_DEFAULTS.visibility,
        scale      = PROFILE_DEFAULTS.scale,
        alpha      = PROFILE_DEFAULTS.alpha,
        locked     = BAR_DEFAULTS.locked,
        -- NOT read out of KCM.dbDefaults, and it is the one default here that is a
        -- literal: the console's visibility is session state and has no home in the
        -- profile to read it from. Declared all the same, because it is what makes the
        -- row RESETTABLE -- the global reset's session sweep
        -- (core/ConsumableMaster.lua's restoreSessionRows), this page's Defaults
        -- button and `/cm reset general` all key on `default ~= nil`, and the composer
        -- emits the row without one. Closed at login is the state a fresh session has.
        debugConsole = false,
    },
    onResetPosition = function()
        if KCM.MacroBar and KCM.MacroBar.ResetPosition then
            KCM.MacroBar.ResetPosition()
            KCM.Say("macro bar position reset.")
        end
    end,
    onResetAll = function() StaticPopup_Show("KCM_CONFIRM_RESET") end,
}

-- The debug console's visibility (options-ui-§15). SESSION state: a console
-- left open is not a setting the next character inherits (debug-logging), so
-- the row is `sessionOnly` and its store is the console itself. It never arms
-- LOGGING (KCM.State.debug), which stays the separate flag it has always been
-- (debug-logging-§5); this is the show/hide a bare `/cm debug` performs.
local debugConsoleRow = {
    sessionOnly = true,
    get = function()
        local DL = KCM.DebugLog
        return (DL and DL.IsWindowShown and DL.IsWindowShown()) and true or false
    end,
    set = function(v)
        local DL = KCM.DebugLog
        if not DL then return end
        if v then
            if DL.Show then DL.Show() end
        elseif DL.Hide then
            DL.Hide()
        end
    end,
}

-- The minimap button's visibility: STORED, but in db.global rather than the
-- profile, because launcher-§3 fixes LibDBIcon's table in the global store -- a
-- button belongs to the installation, so a profile switch must not move it and
-- the global reset (a profile reset by definition) must not un-hide it.
--
-- THE INVERSION LIVES HERE, in the row's own store, exactly as launcher-§3 says
-- it should. The label says SHOWN; LibDBIcon's key says HIDDEN. That is the
-- cost of storing the library's own key rather than a second boolean beside it
-- -- LibDBIcon writes `hide` itself from the button's own menu, and a parallel
-- `show` would be free to disagree with it (anti-pattern #81). The `set` calls
-- the launcher afterwards so the button follows the checkbox at once.
local function minimapTable()
    return KCM.db and KCM.db.global and KCM.db.global.minimap
end

local minimapRow = {
    -- THE ONE ROW NO RESET MAY REACH (launcher-§3). The composer emits it with
    -- `default = true` -- SHOWN -- because a fresh install shows the button, and
    -- that default is what `/cm reset global.minimap.shown` restores when the
    -- player asks for it by name. What the flag stops is a RESET reaching it:
    -- the Defaults button below walks every row on this page carrying a default,
    -- and without the stamp a player who had hidden the button got it back at
    -- LibDBIcon's default angle from a click about the master controls. The
    -- predicate is settings/OptionsSetup.lua's, beside the global reset's veto,
    -- and settings/Panel.lua hands the same flag to the seam's resetExempt.
    neverReset = true,
    -- Shown is the answer when there is no table yet: that is what a fresh
    -- install ships as, and it is what the button does.
    get = function()
        local t = minimapTable()
        return not (t and t.hide)
    end,
    set = function(v)
        local t = minimapTable()
        if not t then return end
        t.hide = not v
        if KCM.Launcher then KCM.Launcher:SetShown(v and true or false) end
    end,
}

H.RegisterRows(masterRows, "general", "general", {
    enabled = {
        apply = function(v)
            -- THE ONE REACTION, AND IT IS THE LATCH'S (slash-commands-§7).
            -- This row is the addon-wide switch, so `/cm enable`, `/cm disable`,
            -- `/cm set enabled true` and the checkbox all arrive here, and from
            -- here they all reach KCM.OnEnabledChanged.
            --
            -- The off→on recompute this used to kick is the latch's `standUp`
            -- now, along with re-registering the nine events and re-applying the
            -- bar -- none of which this row did, which is exactly why `/cm
            -- disable` did not take the macro bar down through 1.6.2.
            if KCM.OnEnabledChanged then KCM.OnEnabledChanged(v and true or false) end
        end,
    },
    -- The three addon-wide display rows all reach the same apply pass: the macro
    -- bar is the only thing this addon draws, and Update is idempotent and
    -- self-defers in combat.
    visibility = { apply = applyBar },
    scale      = { apply = applyBar },
    alpha      = { apply = applyBar },
    -- Apply-only, exactly as it was on the Macro Bar page: the write has already
    -- landed by the time an apply runs, and Schema:Set is still the single
    -- write path both `/cm bar lock` and this checkbox take (CM-R-05).
    ["macroBar.locked"] = {
        apply = function()
            if KCM.MacroBar and KCM.MacroBar.ApplyLock then
                KCM.MacroBar.ApplyLock()
            end
        end,
    },
    [DEBUG_CONSOLE_PATH] = debugConsoleRow,
    [MINIMAP_PATH] = minimapRow,
})

-- Top-right Defaults button (options-ui-§5) resets THIS PAGE, and its blast
-- radius does not narrow to the visible tab (options-ui-§13). Derived from the
-- rows rather than from a hand-written list, so a row added to the block is
-- covered without anyone remembering to add it here.
--
-- A bulk reset: one `[Set] reset General page: N rows` line, and each row's own
-- apply still runs (debug-logging-§10). The bracket closes BEFORE the console
-- is disarmed below, so the line is not lost to it.
--
-- ONE ROW IS EXEMPT and it is the minimap button's (launcher-§3). Through 1.6.2
-- this loop wrote it like any other: the composed row carries `default = true`,
-- so a Defaults press un-hid a button the player had deliberately hidden and put
-- it back at LibDBIcon's default angle. The exemption is the row's `neverReset`
-- stamp, read through the same predicate settings/OptionsSetup.lua's global-reset
-- veto reads, so there is one register rather than a second list here.
local function doResetGeneralPage()
    H.Bulk("reset", "General page", function()
        for _, row in ipairs(masterRows) do
            if row.default ~= nil and not neverReset(row) then
                H.SetAndRefresh(row.path, row.default)
            end
        end
    end)
    -- The console back to its LOGIN state, which is more than the row's default:
    -- logging off AND the window hidden. The row only owns the window.
    if KCM.DebugLog and KCM.DebugLog.SetEnabled then
        KCM.DebugLog.SetEnabled(false)
        if KCM.DebugLog.Hide then KCM.DebugLog.Hide() end
    elseif KCM.State then
        KCM.State.debug = false
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute("options_general_defaults")
    end
    H.RefreshAllPanels()
end

-- ---------------------------------------------------------------------
-- The tab strip (options-ui-§13)
-- ---------------------------------------------------------------------
--
-- Drawn by the library's RenderTabbedSchema (LibKa0s-Options-1.0, OptionsTabs
-- minor 4). The strip is partitioned from this page's schema rows by `group`, so
-- Master controls -- the one group they declare -- is the first tab, its rows go
-- through the row engine with the heading suppressed (the tab carries the name),
-- and the closing button pair is that group's afterGroup hook. The Maintenance
-- tab is a HOST tab (`opts.tabs`): it declares no rows at all, because its three
-- controls are acts rather than settings, so the library places it after the
-- schema tab and calls drawMaintenance to fill it. A tab click is the library's
-- own ClearScroll-and-re-render; nothing on this page holds a widget across it.

-- The three targeted verbs, on their OWN TAB beside Master controls.
--
-- They were a subsection under the canonical block until 2026-09-09, on the
-- reasoning that a whole tab over three buttons pressed about once a month cost
-- a click to reach them. The owner asked for the tab back, and the trade reads
-- the other way round from inside the panel: Master controls is the one tab
-- everybody opens, so hanging three destructive-ish acts off the bottom of it
-- means the rows a player came for are no longer the whole of what they see.
--
-- Permitted, and worth saying why, because §15 is strict about this page: it
-- forbids reordering, renaming or splitting the CANONICAL SET across tabs, and
-- these three were never part of it. Master controls stays the first tab and
-- still carries the canonical rows and nothing else.
--
-- No H.Section heading any more: the tab strip carries the name, and a heading
-- repeating it is two labels for one thing.
local function drawMaintenance(ctx)
    H.ButtonPair(ctx,
        {
            text    = L["Force resync"],
            tooltip = L["Invalidate the tooltip cache, re-run auto-discovery against your bags, and recompute every category's pick. Same as /cm resync. Blocked in combat."],
            onClick = doForceResync,
        },
        {
            text    = L["Force rewrite macros"],
            tooltip = L["Clear cached macro fingerprints and re-issue every KCM macro (body + stored icon). Use this if a macro's action-bar icon looks stale. Same as /cm rewritemacros. Blocked in combat."],
            onClick = doForceRewriteMacros,
        })
    H.Button(ctx, {
        text    = L["Reset all priorities"],
        tooltip = L["Wipe every category's added, blocked and pinned items and every spec's stat-priority override. Discovered items and every other setting are kept — for the whole-profile reset, use Reset all settings on the Master controls tab."],
        onClick = function() StaticPopup_Show("KCM_RESET_PRIORITIES") end,
    })
end

-- Master controls FIRST, and that is §15's requirement rather than a habit: every addon's General
-- page must open on it, under exactly that name. It is first because it is the page's first (and
-- only) schema group and the host tab carries no `before`, so the library appends Maintenance.
local AFTER_GROUP = { ["Master controls"] = masterTail }
local TAB_OPTS = {
    tabs = {
        { key = "Maintenance", label = L["Maintenance"], render = drawMaintenance },
    },
}

local function render(ctx)
    H.ResetScroll(ctx)
    H.RenderTabbedSchema(ctx, "general", AFTER_GROUP, nil, TAB_OPTS)
end

local function Build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local ctx = H.CreatePanel("KCMGeneralPanel", L["General"], {
        panelKey = "general",
        -- Top-right Defaults button (options-ui-§5) → resets this page only,
        -- every tab of it, NOT the whole DB.
        defaultsAction = doResetGeneralPage,
    })
    H.SetRenderer(ctx, render)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

if KCM.Settings and KCM.Settings.RegisterTab then
    KCM.Settings.RegisterTab("general", Build)
end
