-- test_bus.lua — the closed message bus (CM-03).
--
-- Verifies the (message, target)-keyed bus: senders publish on KCM.bus, each
-- receiver subscribes on its own NewBusTarget(), and a RECOMPUTE message routes
-- through to the pipeline's coalescing entry point.

local h = require("harness")

h.suite("message bus", function(t)
    local KCM = h.loader.loadPure()

    t.truthy(KCM.bus, "KCM.bus published")
    t.truthy(KCM.NewBusTarget, "NewBusTarget published")
    t.truthy(KCM.MSG and KCM.MSG.RECOMPUTE, "message catalogue published")

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

    -- The pipeline's RECOMPUTE receiver (registered by Bus.lua) forwards to
    -- RequestRecompute. Stub RequestRecompute to capture the reason.
    local seen
    KCM.Pipeline.RequestRecompute = function(reason) seen = reason end
    KCM.bus:SendMessage(KCM.MSG.RECOMPUTE, "unit_test")
    t.eq(seen, "unit_test", "RECOMPUTE routes to Pipeline.RequestRecompute")
end)
