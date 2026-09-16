-- core/LifecycleSetup.lua — the addon's half of LibKa0s-Lifecycle-1.0: ONE latch,
-- two named holds, one way down and one way back up (slash-commands-§7).
--
-- IT SITS SECOND IN THE TOC, between core/Namespace.lua and core/PerfSetup.lua,
-- and the position is load-bearing in one direction: Perf.lua minor 12 REQUIRES
-- `descriptor.lifecycle`, so the instance has to exist by the time PerfSetup
-- builds its probe. Everything it reaches outward through -- the bus, the event
-- list, the macro bar, the printer -- is a call-time thunk, so loading this early
-- costs nothing.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS REPLACES, AND WHY IT IS NOT A SECOND TEARDOWN PATH
-- ---------------------------------------------------------------------------
--
-- `disabled` used to be a DRAW GATE and nothing more: `db.profile.enabled` had
-- exactly ONE consumer -- `macrosEnabled()` in core/ConsumableMaster.lua, read
-- once to skip the macro write pass. Nine game events stayed registered, the bus
-- stayed subscribed, the macro bar stayed on screen with its fade tick running,
-- and `/cm disable` did not take the bar down at all. The client went on walking
-- this addon's registration list on every BAG_UPDATE_COOLDOWN in a fight: the
-- addon had not stopped watching, it had stopped reacting, which is the whole of
-- anti-pattern #85.
--
-- The cure is NOT a teardown path written beside the perf harness's. That is the
-- anti-pattern the standard names: two mechanisms that both mean "be inert"
-- drift, and the day they disagree the addon is half down -- some events
-- unregistered, some frames still drawn -- a state nobody designed and no test
-- covers. `suspend` and `resume` below ARE the pair core/PerfSetup.lua used to
-- pass to LibKa0s-Perf-1.0; they moved here unchanged in substance and grew the
-- parts the perf arm never needed (the bus, the pending combat completion).
-- Perf.lua minor 12 no longer calls them -- it takes the `perf` hold on this
-- latch instead, and the latch calls them.
--
-- ---------------------------------------------------------------------------
-- TWO HOLDS, AND RELEASING ONE MUST NOT RESURRECT THE ADDON
-- ---------------------------------------------------------------------------
--
-- `disabled` is taken from the stored `enabled` path and is PERSISTED in the
-- sense that surviving a /reload is the whole point of that setting -- it is
-- re-taken at load, never written here. `perf` is taken by the harness for
-- Experiment B and is SESSION-ONLY. A player can disable the addon mid-capture
-- and re-enable it there, so neither release may stand the addon up on its own:
-- the latch stands it up only when the LAST hold goes, which is why there is no
-- `StandUp()` to call and why nothing in this addon calls `standUp` directly.

local addonName, NS = ...
local KCM = NS

local lib = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

-- No stub, exactly as core/PerfSetup.lua and core/LauncherSetup.lua publish
-- none: an absent major is an absent feature. Every caller below reaches the
-- latch through KCM.Lifecycle and is written nil-tolerantly, so a build with
-- libs/LibKa0s/ missing keeps the addon working -- with the stand-down reduced
-- to what the stored flag alone can do, which is what a tampered install gets.
if not lib then return end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

-- ---------------------------------------------------------------------------
-- STAND DOWN — every registration gone, every frame hidden at the SOURCE
-- ---------------------------------------------------------------------------
--
-- Order matters. The bar is taken down BEFORE the events are dropped, because
-- the combat carve-out needs an event to come back on: MB.Update refuses to
-- touch protected frames in combat and parks itself on `pendingUpdate`, and the
-- one registration a disabled addon is permitted to keep is the
-- PLAYER_REGEN_ENABLED that finishes the job (slash-commands-§7).
local function standDown()
    -- Every message registration this addon owns, actually unregistered.
    if KCM.Bus and KCM.Bus.StandDown then KCM.Bus.StandDown() end

    -- The frame-coalescing recompute is disarmed by clearing what its body
    -- reads. C_Timer.After hands back no handle to cancel -- it is a one-shot
    -- that fires at the end of THIS frame and then is gone, not a ticker that
    -- re-arms -- so the flag is the only lever the API leaves, and an at-most-
    -- one-frame-old closure that finds nothing pending is not a survivor.
    KCM._recomputePending = false
    KCM._recomputeReason  = nil

    -- Hidden at the SOURCE, never imperatively: MacroBarModel.IsEnabled() now
    -- answers false while the latch is down, so the bar's own show ladder hides
    -- it and a combat transition, a settings change or a profile switch cannot
    -- re-show it behind the switch's back (performance-§6).
    if KCM.MacroBar and KCM.MacroBar.Update then KCM.MacroBar.Update() end

    -- Every game event this addon registered. `UnregisterAllEvents` rather than
    -- a copy of OnEnable's list read backwards: a tenth event added there cannot
    -- be forgotten here.
    if KCM.UnregisterAllEvents then KCM:UnregisterAllEvents() end

    -- THE ONE REGISTRATION A DISABLED ADDON KEEPS, and only when it is owed one.
    -- Secure work -- the bar's state driver, its anchors, a macro rewrite -- MUST
    -- NOT be attempted under lockdown, so the stand-down is held pending and
    -- completed on regen. KCM:OnRegenEnabled releases it the moment it fires.
    if inCombat() then
        KCM:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    end
end

-- ---------------------------------------------------------------------------
-- STAND UP — rebuilt from the settings AS THEY ARE NOW
-- ---------------------------------------------------------------------------
--
-- Never from a snapshot taken on the way down (performance-§6): a setting can be
-- changed while the addon is off -- the whole schema CLI answers while disabled
-- (slash-commands-§2) -- and the rebuild has to reflect it.
local function standUp()
    if KCM.Bus and KCM.Bus.StandUp then KCM.Bus.StandUp() end
    -- KCM:OnEnable's own list, CALLED rather than copied, for the same reason
    -- the teardown does not copy it.
    if KCM.OnEnable then KCM:OnEnable() end
    if KCM.MacroBar and KCM.MacroBar.Update then KCM.MacroBar.Update() end
    if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute("stand_up")
    end
end

KCM.Lifecycle = lib:New({
    name      = addonName,
    standDown = standDown,
    standUp   = standUp,
    -- A thunk, never bare: lib:New snapshots it, and core/CoreSetup.lua has not
    -- run yet at this point in the TOC. Read only by :PrintHolds().
    print     = function(line) KCM.Say(line) end,
})

--- Is the addon stood down right now -- for either reason?
---
--- The one question every show ladder and every gate in this addon asks, so that
--- `disabled` and `perf-suspended` cannot be two different answers. Written
--- nil-tolerantly because a build with no LibKa0s has no latch at all.
function KCM.IsStoodDown()
    return (KCM.Lifecycle and KCM.Lifecycle:IsDown()) and true or false
end

--- Is the addon DISABLED specifically -- the `disabled` hold, not the latch as a
--- whole.
---
--- Almost everything asks KCM.IsStoodDown, because almost everything cares only
--- whether the addon is inert. The launcher's left click is the exception
--- slash-commands-§7 writes out by name: it refuses while the addon is DISABLED,
--- and a perf capture's suspended arm is not that -- it is a diagnostic the player
--- started and did not switch anything off for.
function KCM.IsAddonDisabled()
    return (KCM.Lifecycle and KCM.Lifecycle:IsHeld(lib.HOLD_DISABLED)) and true or false
end

--- The `enabled` row's onChange, `/cm enable`, `/cm disable` and the load-time
--- read all land here (slash-commands-§2's "no state of their own"). One call,
--- written once in the library's shape rather than as a branch each surface
--- writes for itself.
function KCM.OnEnabledChanged(enabled)
    if not KCM.Lifecycle then return end
    KCM.Lifecycle:Set(lib.HOLD_DISABLED, not enabled)
end

--- A profile switch, copy or reset can flip the stored path with no verb and no
--- checkbox being touched, so the profile handler re-reads it and asks the latch
--- to re-decide. `Reevaluate` fires a callback only on an actual edge, so a
--- profile that agrees with the outgoing one costs nothing.
function KCM.ReevaluateEnabled()
    if not KCM.Lifecycle then return end
    local enabled = not (KCM.db and KCM.db.profile and KCM.db.profile.enabled == false)
    KCM.Lifecycle:Set(lib.HOLD_DISABLED, not enabled)
    KCM.Lifecycle:Reevaluate()
end
