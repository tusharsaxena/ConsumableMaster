-- test_bus.lua — the closed message bus (CM-03).
--
-- Verifies the (message, target)-keyed bus: senders publish on KCM.bus, each
-- receiver subscribes on its own NewBusTarget(), and a RECOMPUTE message routes
-- through to the pipeline's coalescing entry point.

local h = _G.KCM_TEST
local test = h.test

test("bus, NewBusTarget, and message catalog are published", function(t)
    local KCM = h.loader.loadPure()

    t.truthy(KCM.bus, "KCM.bus published")
    t.truthy(KCM.NewBusTarget, "NewBusTarget published")
    t.truthy(KCM.MSG and KCM.MSG.RECOMPUTE, "message catalog published")
end)

test("a target hears a message, then goes silent after unregister", function(t)
    local KCM = h.loader.loadPure()

    -- A receiver on its own target hears a message sent on KCM.bus.
    local got = {}
    local target = KCM.NewBusTarget()
    -- CallbackHandler calls a function handler as fn(message, ...).
    target:RegisterMessage(KCM.MSG.PANEL_REFRESH, function(_, tag)
        got[#got + 1] = tag or "(none)"
    end)
    KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH, "hello")
    t.eqList(got, { "hello" }, "receiver heard the PANEL_REFRESH message")

    -- Unregister isolates: after unregister the receiver is silent.
    target:UnregisterMessage(KCM.MSG.PANEL_REFRESH)
    KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH, "again")
    t.eqList(got, { "hello" }, "unregistered receiver goes silent")
end)

test("RECOMPUTE routes to Pipeline.RequestRecompute", function(t)
    local KCM = h.loader.loadPure()

    -- The pipeline's RECOMPUTE receiver (registered by Bus.lua) forwards to
    -- RequestRecompute. Stub RequestRecompute to capture the reason.
    local seen
    KCM.Pipeline.RequestRecompute = function(reason) seen = reason end
    KCM.bus:SendMessage(KCM.MSG.RECOMPUTE, "unit_test")
    t.eq(seen, "unit_test", "RECOMPUTE routes to Pipeline.RequestRecompute")
end)

test("bus: every message name is namespaced and distinct", function(t)
    local KCM = h.loader.loadPure()

    local seen = {}
    for name, msg in pairs(KCM.MSG) do
        t.eq(msg:sub(1, 22), "Ka0s_ConsumableMaster_",
            name .. " is namespaced so it cannot collide with another addon's bus")
        t.falsy(seen[msg], name .. " has its own message string")
        seen[msg] = true
    end
    t.truthy(KCM.MSG.PANEL_REFRESH and KCM.MSG.SPEC_CHANGED,
        "the documented catalog is complete")
end)

test("bus: NewBusTarget hands out a fresh, independently-embedded table", function(t)
    local KCM = h.loader.loadPure()

    local a, b = KCM.NewBusTarget(), KCM.NewBusTarget()
    t.ne(a, b, "each receiver gets its own table (anti-pattern #32)")
    t.eq(type(a.RegisterMessage), "function", "target can subscribe")
    t.eq(type(a.SendMessage), "function", "target can publish")
end)

test("bus: one message fans out to every subscribed target", function(t)
    local KCM = h.loader.loadPure()

    local heard = {}
    for i = 1, 3 do
        local target = KCM.NewBusTarget()
        target:RegisterMessage(KCM.MSG.PANEL_REFRESH, function() heard[#heard + 1] = i end)
    end
    KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH)
    t.eq(#heard, 3, "all three receivers ran")
end)

test("bus: unregistering one target leaves the others subscribed", function(t)
    local KCM = h.loader.loadPure()

    local aHeard, bHeard = 0, 0
    local a, b = KCM.NewBusTarget(), KCM.NewBusTarget()
    a:RegisterMessage(KCM.MSG.SPEC_CHANGED, function() aHeard = aHeard + 1 end)
    b:RegisterMessage(KCM.MSG.SPEC_CHANGED, function() bHeard = bHeard + 1 end)

    a:UnregisterMessage(KCM.MSG.SPEC_CHANGED)
    KCM.bus:SendMessage(KCM.MSG.SPEC_CHANGED)
    t.eq(aHeard, 0, "the unregistered target is silent")
    t.eq(bHeard, 1, "its neighbor on a separate target still hears the message")
end)

test("bus: a message nobody subscribes to is a silent no-op", function(t)
    local KCM = h.loader.loadPure()
    KCM.bus:SendMessage(KCM.MSG.SPEC_CHANGED, "nobody listening")
    t.truthy(true, "publishing into an empty registry does not raise")
end)

test("bus: the pipeline subscribes on its own target, never on KCM.bus", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM._pipelineBusTarget, "the pipeline's target is published for inspection")
    t.ne(KCM._pipelineBusTarget, KCM.bus,
        "the sender table is not also a receiver table (anti-pattern #32)")
end)

test("bus: RECOMPUTE with no reason still reaches the pipeline", function(t)
    local KCM = h.loader.loadPure()
    local calls = 0
    KCM.Pipeline.RequestRecompute = function(reason)
        calls = calls + 1
        t.eq(reason, nil, "a reason-less publish forwards nil, not a stale value")
    end
    KCM.bus:SendMessage(KCM.MSG.RECOMPUTE)
    t.eq(calls, 1, "the forward still fires")
end)

test("bus: RECOMPUTE is inert while the pipeline entry point is missing", function(t)
    local KCM = h.loader.loadPure()
    KCM.Pipeline.RequestRecompute = nil
    KCM.bus:SendMessage(KCM.MSG.RECOMPUTE, "very_early_boot")
    t.truthy(true, "the guard keeps a pre-pipeline publish from raising")
end)

-- ---------------------------------------------------------------------------
-- Characterization, written BEFORE core/Bus.lua moved onto LibKa0s-Bus-1.0
-- (docs/revendor/2026-09-23/04_EXECUTION_PLAN.md). The output a stand-down
-- record produces is the REGISTRATION SET, so that is what is pinned, by name.
-- ---------------------------------------------------------------------------

--- Every live bus-message registration, as sorted names.
local function messages()
    local out = {}
    for _, r in ipairs(h.mock.base.__registrations()) do
        if r.kind == "message" then out[#out + 1] = tostring(r.event) end
    end
    table.sort(out)
    return out
end

test("bus: StandDown drops every subscribed message and StandUp restores the same set", function(t)
    local KCM = h.loader.loadFullAddon()
    local before = messages()
    t.truthy(#before > 0, "the loaded addon holds bus subscriptions to take down")
    for _, name in ipairs({ KCM.MSG.RECOMPUTE, KCM.MSG.MACROBAR_REFRESH }) do
        t.contains(before, name, name .. " is subscribed at load")
    end
    KCM.Bus.StandDown()
    t.eqList(messages(), {}, "stood down: no bus message is registered")
    KCM.Bus.StandUp()
    t.eqList(messages(), before, "stood up: exactly the set that was taken down, by name")
end)

test("bus: a subscribe function runs once, on the target NewBusTarget returns", function(t)
    local KCM = h.loader.loadPure()
    local runs, seen = 0, nil
    local target = KCM.NewBusTarget(function(x) runs = runs + 1; seen = x end)
    t.eq(runs, 1, "the subscribe function ran exactly once at creation")
    t.eq(seen, target, "and it was handed the very target the caller gets back")
end)

test("bus: RECOMPUTE still reaches the pipeline after a stand-down round trip", function(t)
    local KCM = h.loader.loadPure()
    local seen = {}
    KCM.Pipeline.RequestRecompute = function(reason) seen[#seen + 1] = reason end
    KCM.Bus.StandDown()
    KCM.bus:SendMessage(KCM.MSG.RECOMPUTE, "while_down")
    KCM.Bus.StandUp()
    KCM.bus:SendMessage(KCM.MSG.RECOMPUTE, "after_up")
    t.eqList(seen, { "after_up" }, "silent while down, and forwarding the reason once back up")
end)

-- ---------------------------------------------------------------------------
-- LibKa0s-Bus-1.0 (v1.55.0): what moving onto the major changed, on purpose.
--
-- The closure-less targets the cases above build are TRACKED now (they were
-- deliberately unrecorded before). Each case loads a fresh namespace, so no
-- other case's stand-down ever sees them.
-- ---------------------------------------------------------------------------

-- red under: the host's closure list, which recorded only targets built WITH a
-- subscribe function -- a receiver registering inline survived every stand-down.
test("bus: a target built without a subscribe function is taken down and brought back", function(t)
    local KCM = h.loader.loadPure()
    local heard = 0
    local target = KCM.NewBusTarget()
    target:RegisterMessage(KCM.MSG.SPEC_CHANGED, function() heard = heard + 1 end)
    KCM.Bus.StandDown()
    KCM.bus:SendMessage(KCM.MSG.SPEC_CHANGED)
    t.eq(heard, 0, "stood down: the inline registration is gone too")
    local listed = false
    for _, name in ipairs(messages()) do
        if name == KCM.MSG.SPEC_CHANGED then listed = true end
    end
    t.falsy(listed, "and it is not in the registration set")
    KCM.Bus.StandUp()
    KCM.bus:SendMessage(KCM.MSG.SPEC_CHANGED)
    t.eq(heard, 1, "stood up: replayed from the record")
end)

-- red under: the host's NewBusTarget, which ran every registration immediately
-- whatever the latch said.
test("bus: a registration made while down is recorded and goes live only at stand-up", function(t)
    local KCM = h.loader.loadPure()
    KCM.Bus.StandDown()
    local heard = 0
    KCM.NewBusTarget(function(target)
        target:RegisterMessage(KCM.MSG.PANEL_REFRESH, function() heard = heard + 1 end)
    end)
    KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH)
    t.eq(heard, 0, "not live while the bus is down")
    KCM.Bus.StandUp()
    KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH)
    t.eq(heard, 1, "live once it is up")
end)

-- red under: the host's StandUp, which re-ran every closure whenever it was
-- called. The latch's own standUp is the one door back up (slash-commands-§7).
test("bus: a bare StandUp is refused while the latch still holds the addon down", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM:OnEnable()
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)
    t.truthy(KCM.IsStoodDown(), "the disabled hold is taken")
    t.eq(KCM.Bus.StandUp(), 0, "the replay is refused")
    t.eqList(messages(), {}, "and no bus message came back")
end)

test("bus: KCM.MSG is strict, so a mistyped key raises instead of going quiet", function(t)
    local KCM = h.loader.loadPure()
    local ok, err = pcall(function() return KCM.MSG.PANEL_REFERSH end)
    t.falsy(ok, "reading an undeclared key raises")
    t.truthy(tostring(err):find("PANEL_REFERSH", 1, true), "and names the key")
    local n = 0
    for _ in pairs(KCM.MSG) do n = n + 1 end
    t.eq(n, 5, "pairs still walks the five declared messages")
end)

-- The degraded load: libs/LibKa0s/ skipped for real (testing-§8). The
-- untracked-target stub (options-ui-§1): every receiver still gets a private
-- target and hears its messages, nothing is recorded, so StandDown takes nothing
-- down -- the Known Limitation docs/ARCHITECTURE.md states.
test("bus degraded: receivers still subscribe; the stand-down record is empty", function(t)
    local KCM = h.loader.loadPureDegraded()
    local ran, heard = 0, 0
    local target = KCM.NewBusTarget(function(x)
        ran = ran + 1
        x:RegisterMessage(KCM.MSG.SPEC_CHANGED, function() heard = heard + 1 end)
    end)
    t.truthy(target and target.RegisterMessage, "a private AceEvent target, not nil")
    t.eq(ran, 1, "the subscribe function ran")
    t.ne(target, KCM.NewBusTarget(), "each receiver gets its own table")
    t.eq(KCM.Bus.StandDown(), 0, "StandDown answers 0: nothing was recorded")
    KCM.bus:SendMessage(KCM.MSG.SPEC_CHANGED)
    t.eq(heard, 1, "so the registration is still live after it")
    t.eq(KCM.Bus.StandUp(), 0, "StandUp answers 0")
    t.eq(KCM.MSG.NOT_DECLARED, nil, "and KCM.MSG is the plain declared table")
    t.eq(KCM.MSG.RECOMPUTE, "Ka0s_ConsumableMaster_Recompute", "with the same wire names")
end)
