-- settings/General.lua — General page.
--
-- Two sections:
--   * General      — paired [Enable] | [Debug] checkboxes (both schema-driven;
--                    same rows /cm get/set enabled and /cm get/set debug use).
--   * Maintenance  — Row 1: Force resync | Force rewrite macros (paired 50/50).
--                    Row 2: Reset all priorities (full-width, StaticPopup-confirmed).
--
-- Every execute path is shared with the slash commands so behaviour stays
-- identical regardless of entry point.

local _, NS = ...
local KCM = NS
local L      = KCM.L
local H      = KCM.Settings.Helpers

local function inCombatNotice(label)
    print((KCM.PREFIX .. " in combat — %s deferred until regen."):format(label))
end

local function doForceResync()
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("resync")
    end
    if KCM.TooltipCache and KCM.TooltipCache.InvalidateAll then
        KCM.TooltipCache.InvalidateAll()
    end
    if KCM.Pipeline and KCM.Pipeline.RunAutoDiscovery then
        KCM.Pipeline.RunAutoDiscovery("options_resync")
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute("options_resync")
    end
    H.RefreshAllPanels()
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
    print(KCM.PREFIX .. " rewrote all macros. If action bar icons still look stale, /reload to force the bars to refresh.")
    H.RefreshAllPanels()
end

local function doResetAll()
    -- Combat-guarded to match the Maintenance section's sibling buttons; the
    -- DB wipe itself is combat-safe (MacroManager defers macro writes to
    -- regen), but blocking here keeps the section's behaviour uniform.
    if InCombatLockdown and InCombatLockdown() then
        return inCombatNotice("reset")
    end
    if KCM.ResetAllToDefaults then
        KCM.ResetAllToDefaults("options_reset")
    end
    H.RefreshAllPanels()
end

-- Top-right Defaults button (standard §6.5) resets THIS page only: the
-- persisted master enable back to its default, and the session-only debug
-- console off. The account-wide "reset everything" is the separate inline
-- button in Maintenance, behind its own confirmation popup.
local function doResetGeneralPage()
    local defaults = KCM.dbDefaults and KCM.dbDefaults.profile or {}
    if KCM.db and KCM.db.profile then
        KCM.db.profile.enabled = defaults.enabled ~= false
    end
    if KCM.DebugLog and KCM.DebugLog.SetEnabled then
        KCM.DebugLog.SetEnabled(false)
    elseif KCM.State then
        KCM.State.debug = false
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute("options_general_defaults")
    end
    H.RefreshAllPanels()
end

StaticPopupDialogs["KCM_RESET_ALL"] = {
    text         = L["Reset ALL ConsumableMaster customization to defaults? This wipes every category's added/blocked/pinned items and all stat-priority overrides, and re-enables the addon. Your macros stay in place, and items currently in your bags are re-discovered automatically. This cannot be undone."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function() doResetAll() end,
}

local function render(ctx)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    -- General: two-column paired grid (standard §6.6). [Enable] is the
    -- schema-backed master toggle; [Debug console] is a session-only State
    -- checkbox (KCM.State.debug, never persisted) that also opens the console.
    H.Section(ctx, L["General"])
    local enabledDef = H.FindSchema("enabled")
    local debugConsole = {
        make = function(c, parent, relW)
            H.CustomCheckbox(c, parent, relW, {
                label   = L["Debug console"],
                tooltip = L["Open the on-screen debug console and stream diagnostics to it. Session-only — resets to off every login. Same as /cm debug."],
                get     = function() return KCM.DebugLog and KCM.DebugLog.IsEnabled() end,
                set     = function(v)
                    if KCM.DebugLog and KCM.DebugLog.SetEnabled then
                        KCM.DebugLog.SetEnabled(v)
                        if v and KCM.DebugLog.Show then KCM.DebugLog.Show() end
                    else
                        KCM.State = KCM.State or {}
                        KCM.State.debug = v
                    end
                end,
            })
        end,
    }
    H.Grid(ctx, { enabledDef, debugConsole })

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
        tooltip = L["Wipe all added/blocked/pinned items and stat-priority overrides. Seed defaults are restored. This cannot be undone."],
        onClick = function() StaticPopup_Show("KCM_RESET_ALL") end,
    })

    if scroll.DoLayout then scroll:DoLayout() end
end

local function Build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local ctx = H.CreatePanel("KCMGeneralPanel", L["General"], {
        panelKey = "general",
        -- Top-right Defaults button (standard §6.5) → resets this page only
        -- (master enable + session debug console), NOT the whole DB.
        defaultsAction = doResetGeneralPage,
    })
    H.SetRenderer(ctx, render)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

if KCM.Settings and KCM.Settings.RegisterTab then
    KCM.Settings.RegisterTab("general", Build)
end
