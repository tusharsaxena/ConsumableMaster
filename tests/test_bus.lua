-- test_bus.lua — the closed message bus (CM-03).
--
-- Verifies the (message, target)-keyed bus: senders publish on KCM.bus, each
-- receiver subscribes on its own NewBusTarget(), and a RECOMPUTE message routes
-- through to the pipeline's coalescing entry point.

local h = require("harness")
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
    target:RegisterMessage(KCM.MSG.PANEL_REFRESH, function(_, _, tag)
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
