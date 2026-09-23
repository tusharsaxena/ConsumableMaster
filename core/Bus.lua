-- core/Bus.lua — the closed cross-module message bus (architecture-§4).
--
-- Modules never reach into each other's tables to trigger work; instead the
-- event layer and the pipeline publish named messages on KCM.bus, and each
-- consumer subscribes on its OWN target (KCM.NewBusTarget()) — never two
-- receivers on one target (anti-pattern #32).
--
-- Message catalog (also documented in docs/ARCHITECTURE.md):
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
--   Ka0s_ConsumableMaster_ProfileChanged(reason) — profile handler → the macro
--       bar, the options panel and the Profiles page. AceDB switched, copied or
--       reset the profile, so every stored value is different at once. Sent by
--       the ONE reaction KCM.RegisterProfileCallbacks installs, after the resync
--       has rewritten the macros; `reason` is profile_changed / profile_copied /
--       profile_reset. Separate from MacroBarRefresh because a repaint re-reads
--       icons and counts only, and a new profile needs the bar re-applied whole
--       (anchor, grid, order, shown slots, lock, enabled).

local addonName, NS = ...
local KCM = NS

local AceEvent = LibStub("AceEvent-3.0")

KCM.bus = KCM.bus or {}
AceEvent:Embed(KCM.bus)

-- THE STAND-DOWN RECORD IS LibKa0s-Bus-1.0's (LibKa0s v1.55.0). Every target
-- KCM.NewBusTarget hands out is a TRACKED target: the library wraps its six
-- register/unregister members and keeps a record of what it holds, so
-- KCM.Bus.StandDown takes every registration down -- messages and events, on
-- every target, whether or not it came with a subscribe function -- and
-- KCM.Bus.StandUp replays the record as it is NOW. A registration made while
-- the bus is down is recorded and goes live at the stand-up, so "a stood-down
-- addon registers nothing" holds for every receiver rather than for the ones
-- that remembered to hand in a function (slash-commands-§7).
--
-- With the major absent (a partial or missing libs/LibKa0s/, which
-- core/CoreSetup.lua already announces) this file takes the untracked-target
-- stub the Bus API document's "Worked example" prints and options-ui-§1 names:
-- each receiver still gets a private AceEvent target, but nothing is recorded,
-- so on that install a disable leaves the bus registrations live
-- (docs/ARCHITECTURE.md, Known Limitations).
local Bus = LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
    Bus = {
        New = function(_, d)
            return {
                name = d and d.name,
                NewTarget = function()
                    local ace = LibStub("AceEvent-3.0", true)
                    if not ace then return nil end
                    local t = {}
                    ace:Embed(t)
                    return t
                end,
                StandDown = function() return 0 end,
                StandUp   = function() return 0, {} end,
            }
        end,
        Catalog = function(_, messages) return messages end,
    }
end
-- Published so tests/test_surface_parity.lua can hold the stub to the live
-- surface; nothing in the addon reads it.
KCM._BusLib = Bus

-- The record asks the latch through a closure: core/LifecycleSetup.lua builds
-- KCM.IsStoodDown, and this file runs before anything can call it. Inside the
-- latch's own standUp callback the latch has already recorded the edge, so the
-- replay proceeds; anywhere else while a hold is taken, a bare stand-up of the
-- registrations is refused.
KCM.busRecord = Bus:New({
    name   = addonName,
    isDown = function() return KCM.IsStoodDown ~= nil and KCM.IsStoodDown() end,
})

-- Each receiver owns its own embedded target so unregister is isolated and no
-- two subscriptions ever share one table.
--
-- The subscribe function is optional and kept for the call sites that already
-- hand one in: it runs once, now, on the new target. It is no longer what makes
-- the stand-down reversible -- the record is -- so a receiver that registers on
-- its target later, inline, is taken down and brought back like any other.
function KCM.NewBusTarget(subscribe)
    local t = KCM.busRecord:NewTarget()
    if type(subscribe) == "function" and t then subscribe(t) end
    return t
end

KCM.Bus = KCM.Bus or {}

--- Drop every registration the addon's bus targets hold. Called from the
--- latch's standDown (core/LifecycleSetup.lua), never directly, and never gated:
--- an early-returning handler is a draw gate, not a stand-down (anti-pattern
--- #85). Answers the number of recorded registrations it took down.
function KCM.Bus.StandDown()
    return KCM.busRecord:StandDown()
end

--- Re-install them from the record as it is now, in creation order. An entry
--- the client refuses on the replay is dropped and named on the debug console
--- rather than raised, so the rest of the latch's standUp still runs. Answers
--- the number of registrations made live.
function KCM.Bus.StandUp()
    local replayed, rejected = KCM.busRecord:StandUp()
    if rejected and #rejected > 0 and KCM.Debug then
        KCM.Debug("Bus", "rejected on stand-up: %s", table.concat(rejected, ", "))
    end
    return replayed
end

-- The declare-once table (architecture-§4), validated at load by the library's
-- Catalog: every wire name carries the Ka0s_ConsumableMaster_ prefix and a
-- PascalCase event, and no two keys share one. What comes back is STRICT: reading
-- a key that is not declared raises at the call site, for a publisher as well as
-- a subscriber.
KCM.MSG = Bus.Catalog(addonName, {
    RECOMPUTE         = "Ka0s_ConsumableMaster_Recompute",
    PANEL_REFRESH     = "Ka0s_ConsumableMaster_PanelRefresh",
    SPEC_CHANGED      = "Ka0s_ConsumableMaster_SpecChanged",
    MACROBAR_REFRESH  = "Ka0s_ConsumableMaster_MacroBarRefresh",
    PROFILE_CHANGED   = "Ka0s_ConsumableMaster_ProfileChanged",
})

-- The pipeline owns the ONLY subscription to RECOMPUTE and forwards it to the
-- frame-coalescing entry point. Registered at load so it is live before the
-- first PLAYER_ENTERING_WORLD (OnEnable) fires.
--
-- A function handler registered with no `arg` is called as fn(message, ...) --
-- CallbackHandler stores it as-is and dispatches (eventname, ...) -- so the
-- reason is the SECOND parameter. It read the third until #38 put the suite on
-- the kit's AceEvent: the old harness called fn(target, message, ...), which no
-- client does, and every bus-routed pass logged its reason as "unknown".
local pipelineTarget = KCM.NewBusTarget(function(t)
    t:RegisterMessage(KCM.MSG.RECOMPUTE, function(_, reason)
        if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
            KCM.Pipeline.RequestRecompute(reason)
        end
    end)
end)
KCM._pipelineBusTarget = pipelineTarget
