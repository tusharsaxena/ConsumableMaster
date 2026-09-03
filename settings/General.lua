-- settings/General.lua — General page.
--
-- ONE TAB on a pinned strip (options-ui-§13), where there used to be two:
--
--   * Master controls — the canonical eight (options-ui-§15), COMPOSED by the
--     library's MasterControls rather than typed out here, and closed by the
--     [Reset position] | [Reset all settings] button pair. It is the FIRST tab
--     on the page, which is the whole rule: the one thing every player looks for
--     first is in the same place, under the same words, in every Ka0s addon.
--     Under the canonical block, a `Maintenance` SUBSECTION carries the three
--     targeted verbs this addon has and no other Ka0s addon does: force a
--     resync, force a macro rewrite, and drop every priority override. None of
--     them is a setting, so none of them is a row.
--
-- THE MAINTENANCE TAB IS GONE and its three buttons are that subsection. It was
-- a whole tab over three buttons a player presses about once a month, sitting
-- beside the one tab everybody actually opens. They are appended AFTER the
-- canonical block rather than interleaved into it (options-ui-§16: anything
-- extra goes after the block), under a heading, because the tab now mixes
-- settings rows with acts and §7 wants each kind named. Nothing here is a
-- setting, so nothing moved in storage, and the page's Defaults button — which
-- walks `masterRows` — is unaffected by the fold.
--
-- A ONE-SECTION PAGE STILL DRAWS A STRIP (options-ui-§13). The rule is not a size
-- threshold: a player who has learned one Ka0s page has learned all of them, and
-- a page that drops its chrome for being small teaches the opposite.
--
-- THE TWO RESETS ARE DIFFERENT ACTS and are deliberately on different tabs.
-- [Reset all settings] is options-ui-§12's global reset — a profile reset, the
-- same act as Profiles → Reset Profile, behind the collection's one wording.
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

-- The GLOBAL reset (options-ui-§12): the session-only rows restored by hand, then
-- a profile reset — the same act AceDBOptions' own Reset Profile performs. BOTH
-- halves are KCM.ResetAllToDefaults', not this button's, because `/cm resetall`
-- is the same act through another door and the two must not drift. The resync is
-- in neither half: it happens on the OnProfileReset callback, which is the one
-- path a profile SWITCH takes too.
local function doResetAll()
    -- Combat-guarded to match the Maintenance subsection's siblings; the
    -- DB wipe itself is combat-safe (MacroManager defers macro writes to
    -- regen), but blocking here keeps the page's behavior uniform.
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("reset")
    end
    if KCM.ResetAllToDefaults then
        KCM.ResetAllToDefaults("options_reset")
    end
    H.RefreshAllPanels()
end

-- The bucket fields a priority reset clears. `discovered` is deliberately not
-- among them: auto-discovery findings are what the bags say, not what the player
-- chose, and they survive exactly as they survive a per-category reset.
local PRIORITY_FIELDS = { "added", "blocked", "pins" }

local function clearBucket(bucket)
    if type(bucket) ~= "table" then return end
    for _, field in ipairs(PRIORITY_FIELDS) do
        if type(bucket[field]) == "table" then bucket[field] = {} end
    end
end

-- The TARGETED reset the old "Reset all priorities" button claimed and did not
-- do: every category's added / blocked / pinned items and every spec's stat
-- priority override, and nothing else — the macro bar's appearance, the master
-- controls and the composite section orders are all left standing.
--
-- Driven off the SHAPE of what is stored rather than off a list of category
-- keys: a spec-aware category keeps its buckets under `bySpec`, and a list of
-- keys written here is a list that goes stale the first time a category is
-- added.
local function doResetAllPriorities()
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("reset")
    end
    local profile = KCM.db and KCM.db.profile
    if not profile then return end

    for _, bucket in pairs(profile.categories or {}) do
        clearBucket(bucket)
        if type(bucket) == "table" and type(bucket.bySpec) == "table" then
            for _, specBucket in pairs(bucket.bySpec) do clearBucket(specBucket) end
        end
    end
    profile.statPriority = {}

    resyncPipeline("options_reset_priorities")
end
KCM.ResetAllPriorities = doResetAllPriorities

StaticPopupDialogs["KCM_RESET_ALL"] = {
    -- THE COLLECTION'S ONE WORDING (options-ui-§12), verbatim. Addon-agnostic on
    -- purpose: the old text enumerated this addon's own nouns, which is exactly
    -- what eight addons each did differently. What it used to promise about
    -- macros surviving is still true and is now the tooltip's job, not the
    -- confirmation's -- a popup that lists reassurances buries the warning.
    text         = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function() doResetAll() end,
}

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
    -- and lives outside the profile. settings/Panel.lua's SESSION_PATHS is what
    -- resolves it.
    debugConsolePath = "state.debugConsole",
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
    onResetAll = function() StaticPopup_Show("KCM_RESET_ALL") end,
}

H.RegisterRows(masterRows, "general", "general", {
    enabled = {
        onChange = function(v)
            local state = v and "|cff00ff00ON|r" or "|cffff5555OFF|r"
            KCM.Say("Master enable " .. state)
            -- Off→on: kick a recompute so macros refresh against the current
            -- bag / spec state immediately rather than waiting for the next
            -- event. Off→off is harmless (RequestRecompute schedules a run
            -- which the gate in Pipeline.Recompute then skips).
            if v and KCM.Pipeline and KCM.Pipeline.RequestRecompute then
                KCM.Pipeline.RequestRecompute("master_enable")
            end
        end,
    },
    -- The three addon-wide display rows all reach the same apply pass: the macro
    -- bar is the only thing this addon draws, and Update is idempotent and
    -- self-defers in combat.
    visibility = { onChange = applyBar },
    scale      = { onChange = applyBar },
    alpha      = { onChange = applyBar },
    -- Apply-only, exactly as it was on the Macro Bar page: the write has already
    -- landed by the time an onChange runs, and Schema:Set is still the single
    -- write path both `/cm bar lock` and this checkbox take (CM-R-05).
    ["macroBar.locked"] = {
        onChange = function()
            if KCM.MacroBar and KCM.MacroBar.ApplyLock then
                KCM.MacroBar.ApplyLock()
            end
        end,
    },
})

-- Top-right Defaults button (options-ui-§5) resets THIS PAGE, and its blast
-- radius does not narrow to the visible tab (options-ui-§13). Derived from the
-- rows rather than from a hand-written list, so a row added to the block is
-- covered without anyone remembering to add it here.
local function doResetGeneralPage()
    for _, row in ipairs(masterRows) do
        if row.default ~= nil then H.SetAndRefresh(row.path, row.default) end
    end
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
-- Hand-drawn rather than handed to RenderTabbedSchema. The tab's ROWS are
-- rendered by the library's row engine (RenderRows, with the group heading
-- suppressed because the tab already carries the name), so the rows, their order,
-- their pairing and the closing button pair are all the library's; what the
-- library cannot derive is the Maintenance subsection under them, which declares
-- no rows at all -- its three controls are acts, not settings.

-- The three targeted verbs, under their own heading beneath the canonical block.
-- Its own function rather than inlined into drawMaster: the two halves answer
-- different questions -- what this addon stores, and what it can be told to do.
local function drawMaintenance(ctx)
    H.Section(ctx, L["Maintenance"])
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
        tooltip = L["Wipe every category's added, blocked and pinned items and every spec's stat-priority override. Discovered items and every other setting are kept — for the whole-profile reset, use Reset all settings above."],
        onClick = function() StaticPopup_Show("KCM_RESET_PRIORITIES") end,
    })
end

local function drawMaster(ctx)
    H.RenderRows(ctx, masterRows, { ["Master controls"] = masterTail }, nil,
        { noHeadings = true })
    drawMaintenance(ctx)
end

local TABS = {
    { group = "Master controls", label = L["Master controls"], draw = drawMaster },
}
KCM.Settings.GENERAL_TABS = TABS

local function activeTab(ctx)
    for _, tab in ipairs(TABS) do
        if tab.group == ctx.activeTab then return tab end
    end
    ctx.activeTab = TABS[1].group
    return TABS[1]
end

local function render(ctx)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    local tab = activeTab(ctx)
    local strip = {}
    for i, entry in ipairs(TABS) do
        strip[i] = { key = entry.group, label = entry.label }
    end
    H.TabStrip(ctx, {
        tabs     = strip,
        value    = ctx.activeTab,
        onSelect = function(key)
            if key == ctx.activeTab then return end
            ctx.activeTab = key
            render(ctx)
        end,
    })

    tab.draw(ctx)

    if scroll.DoLayout then scroll:DoLayout() end
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
