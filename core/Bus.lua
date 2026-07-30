-- core/Bus.lua — the closed cross-module message bus (standard §4.4).
--
-- Modules never reach into each other's tables to trigger work; instead the
-- event layer and the pipeline publish named messages on KCM.bus, and each
-- consumer subscribes on its OWN target (KCM.NewBusTarget()) — never two
-- receivers on one target (anti-pattern #32).
--
-- Message catalogue (also documented in docs/ARCHITECTURE.md):
--   Ka0s_ConsumableMaster_Recompute(reason)  — event/UI layer → pipeline.
--       Coalesced into one pipeline pass per frame by RequestRecompute.
--   Ka0s_ConsumableMaster_PanelRefresh()      — pipeline → options panel.
--       Debounced rebuild of any open settings page.
--   Ka0s_ConsumableMaster_SpecChanged()       — spec change → options panel.
--       Retracks the Stat Priority page to the new spec when auto-tracking.
--   Ka0s_ConsumableMaster_MacroBarRefresh()   — pipeline → macro bar.
--       Repaint slot icons / counts after macro bodies were rewritten. Separate
--       from PanelRefresh because the bar is live during play (and cheap to
--       repaint) while the panel rebuild is debounced and only matters when
--       open.

local _, NS = ...
local KCM = NS

local AceEvent = LibStub("AceEvent-3.0")

KCM.bus = KCM.bus or {}
AceEvent:Embed(KCM.bus)

-- Each receiver owns its own embedded target so unregister is isolated and no
-- two subscriptions ever share one table.
function KCM.NewBusTarget()
    local t = {}
    AceEvent:Embed(t)
    return t
end

KCM.MSG = {
    RECOMPUTE         = "Ka0s_ConsumableMaster_Recompute",
    PANEL_REFRESH     = "Ka0s_ConsumableMaster_PanelRefresh",
    SPEC_CHANGED      = "Ka0s_ConsumableMaster_SpecChanged",
    MACROBAR_REFRESH  = "Ka0s_ConsumableMaster_MacroBarRefresh",
}

-- The pipeline owns the ONLY subscription to RECOMPUTE and forwards it to the
-- frame-coalescing entry point. Registered at load so it is live before the
-- first PLAYER_ENTERING_WORLD (OnEnable) fires.
local pipelineTarget = KCM.NewBusTarget()
KCM._pipelineBusTarget = pipelineTarget
pipelineTarget:RegisterMessage(KCM.MSG.RECOMPUTE, function(_, _, reason)
    if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute(reason)
    end
end)
