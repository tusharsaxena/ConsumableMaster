-- tests/test_events.lua — the client-event layer in core/ConsumableMaster.lua.
--
-- Every handler is a thin router: it must do its own small piece of work and
-- then hand off through Pipeline.RequestRecompute / the bus, never touch a
-- protected macro API itself. These cases pin the routing — which event causes
-- a recompute, which deliberately does NOT (the GET_ITEM_INFO_RECEIVED burst
-- guard), what reason each pass carries, and the OnEnable registration table.

local h = _G.KCM_TEST
local test = h.test

-- Load the pure layer and replace the pipeline's terminal entry point with a
-- recorder, so a handler's routing is observable without running a real
-- recompute. Returns KCM, the mock, and the list of recompute reasons seen.
local function loadRouted()
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local reasons = {}
    KCM.Pipeline.RequestRecompute = function(reason) reasons[#reasons + 1] = reason end
    return KCM, mock, reasons
end

-- Own a classifiable bag item that no seed ships, so discovery has work to do.
local function ownFood(mock, id)
    mock.setItem(id, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(id, 1)
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

test("OnEnable registers every client event the addon reacts to", function(t)
    local KCM = h.loader.loadPure()
    local registered = {}
    KCM.RegisterEvent = function(_, event, handler) registered[event] = handler end
    KCM:OnEnable()

    local expected = {
        PLAYER_ENTERING_WORLD         = "OnPlayerEnteringWorld",
        BAG_UPDATE_DELAYED            = "OnBagUpdateDelayed",
        PLAYER_SPECIALIZATION_CHANGED = "OnSpecChanged",
        PLAYER_REGEN_ENABLED          = "OnRegenEnabled",
        GET_ITEM_INFO_RECEIVED        = "OnItemInfoReceived",
        LEARNED_SPELL_IN_SKILL_LINE   = "OnLearnedSpell",
        PLAYER_EQUIPMENT_CHANGED      = "OnEquipmentChanged",
    }
    for event, handler in pairs(expected) do
        t.eq(registered[event], handler, event .. " is wired to " .. handler)
    end
end)

test("OnEnable registers no event without a matching handler method", function(t)
    local KCM = h.loader.loadPure()
    local registered = {}
    KCM.RegisterEvent = function(_, event, handler) registered[event] = handler end
    KCM:OnEnable()
    for event, handler in pairs(registered) do
        t.eq(type(KCM[handler]), "function",
            event .. " names a real method (a typo here fails silently in game)")
    end
end)

-- ---------------------------------------------------------------------------
-- Login / bag / spec
-- ---------------------------------------------------------------------------

test("PLAYER_ENTERING_WORLD discovers, sweeps, then recomputes in that order", function(t)
    local KCM, mock, reasons = loadRouted()
    -- The handler calls the file-local discovery pass directly, so observe it
    -- at its own seam: the discovery pass is what marks an item discovered.
    local order = {}
    local realMark = KCM.Selector.MarkDiscovered
    KCM.Selector.MarkDiscovered = function(...)
        if order[#order] ~= "discover" then order[#order + 1] = "discover" end
        return realMark(...)
    end
    KCM.Selector.SweepStaleDiscovered = function() order[#order + 1] = "sweep" end
    KCM.Pipeline.RequestRecompute = function(r) order[#order + 1] = "recompute"; reasons[#reasons + 1] = r end

    ownFood(mock, 910001)
    KCM:OnPlayerEnteringWorld()

    t.eqList(order, { "discover", "sweep", "recompute" },
        "the sweep sees freshly-bumped timestamps and the recompute sees the cleaned set")
    t.eqList(reasons, { "player_entering_world" }, "one pass, tagged with the login reason")
end)

test("PLAYER_ENTERING_WORLD picks up a bag item that no seed ships", function(t)
    local KCM, mock = loadRouted()
    ownFood(mock, 910002)
    KCM:OnPlayerEnteringWorld()
    local found = false
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        if id == 910002 then found = true end
    end
    t.truthy(found, "the login discovery pass added it to the FOOD candidates")
end)

test("BAG_UPDATE_DELAYED rediscovers and recomputes with the bag reason", function(t)
    local KCM, mock, reasons = loadRouted()
    ownFood(mock, 910003)
    KCM:OnBagUpdateDelayed()
    t.eqList(reasons, { "bag_update_delayed" }, "one recompute request, tagged as a bag update")
    local found = false
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        if id == 910003 then found = true end
    end
    t.truthy(found, "the newly-looted item is discovered on the same pass")
end)

test("PLAYER_SPECIALIZATION_CHANGED recomputes and tells the panel to retrack", function(t)
    local KCM, _, reasons = loadRouted()
    local specChanges = 0
    local target = KCM.NewBusTarget()
    target:RegisterMessage(KCM.MSG.SPEC_CHANGED, function() specChanges = specChanges + 1 end)

    KCM:OnSpecChanged()

    t.eqList(reasons, { "spec_changed" }, "picks are re-evaluated against the new spec")
    t.eq(specChanges, 1,
        "the Stat Priority page retracks via its own SPEC_CHANGED receiver (architecture-§4)")
end)

test("LEARNED_SPELL_IN_SKILL_LINE recomputes so a late-known spell can be picked", function(t)
    local KCM, _, reasons = loadRouted()
    KCM:OnLearnedSpell()
    t.eqList(reasons, { "learned_spell" }, "closes the window where the spell book had not hydrated")
end)

-- ---------------------------------------------------------------------------
-- Equipment
-- ---------------------------------------------------------------------------

test("PLAYER_EQUIPMENT_CHANGED recomputes for a main-hand or off-hand swap", function(t)
    local KCM, _, reasons = loadRouted()
    KCM:OnEquipmentChanged("PLAYER_EQUIPMENT_CHANGED", 16)
    KCM:OnEquipmentChanged("PLAYER_EQUIPMENT_CHANGED", 17)
    t.eqList(reasons, { "equip", "equip" }, "both weapon slots drive the per-hand enchant pick")
end)

test("PLAYER_EQUIPMENT_CHANGED ignores every non-weapon slot", function(t)
    local KCM, _, reasons = loadRouted()
    for _, slot in ipairs({ 1, 5, 15, 18, nil }) do
        KCM:OnEquipmentChanged("PLAYER_EQUIPMENT_CHANGED", slot)
    end
    t.eq(#reasons, 0, "swapping a helm cannot change a weapon enchant, so nothing runs")
end)

-- ---------------------------------------------------------------------------
-- Combat regen
-- ---------------------------------------------------------------------------

test("PLAYER_REGEN_ENABLED flushes the macro writes deferred during combat", function(t)
    local KCM = h.loader.loadPure()
    local flushes = 0
    KCM.MacroManager.FlushPending = function() flushes = flushes + 1; return 2 end
    KCM:OnRegenEnabled()
    t.eq(flushes, 1, "the queue is drained exactly once on leaving combat")
end)

test("PLAYER_REGEN_ENABLED is safe before the macro layer has loaded", function(t)
    local KCM = h.loader.loadPure()
    local saved = KCM.MacroManager
    KCM.MacroManager = nil
    KCM:OnRegenEnabled()
    KCM.MacroManager = saved
    t.truthy(true, "an early regen event does not raise")
end)

-- ---------------------------------------------------------------------------
-- GET_ITEM_INFO_RECEIVED — the burst guard
-- ---------------------------------------------------------------------------

test("GET_ITEM_INFO_RECEIVED ignores a failed or id-less delivery", function(t)
    local KCM, _, reasons = loadRouted()
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 910010, false)
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", nil, true)
    t.eq(#reasons, 0, "nothing is recomputed off data that never arrived")
end)

test("GET_ITEM_INFO_RECEIVED for a bag item invalidates its cached tooltip", function(t)
    local KCM, mock, _ = loadRouted()
    local invalidated = {}
    KCM.TooltipCache.Invalidate = function(id) invalidated[#invalidated + 1] = id end
    ownFood(mock, 910011)
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 910011, true)
    t.eqList(invalidated, { 910011 }, "the stale parse is dropped so the new data is read")
end)

test("GET_ITEM_INFO_RECEIVED for a bag item discovers it and recomputes", function(t)
    local KCM, mock, reasons = loadRouted()
    ownFood(mock, 910012)
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 910012, true)
    t.eqList(reasons, { "item_info_received" }, "a bag item can change a pick, so the pipeline runs")
    local found = false
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        if id == 910012 then found = true end
    end
    t.truthy(found, "the retry path classifies an item whose tooltip only just loaded")
end)

test("GET_ITEM_INFO_RECEIVED for a non-bag item refreshes the panel but never recomputes", function(t)
    local KCM, mock, reasons = loadRouted()
    local refreshes = 0
    local target = KCM.NewBusTarget()
    target:RegisterMessage(KCM.MSG.PANEL_REFRESH, function() refreshes = refreshes + 1 end)

    -- A priority-list row the player does NOT own — the shape of the ~150-item
    -- burst fired the first time the options panel opens.
    mock.setItem(910013, { subType = "Food & Drink", tt = { healValue = 500 } })
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 910013, true)

    t.eq(#reasons, 0, "macros only pick from bags, so a non-bag item cannot change one")
    t.eq(refreshes, 1, "the row still gets a debounced refresh to swap in the real name")
end)

test("GET_ITEM_INFO_RECEIVED never discovers an item the player does not own", function(t)
    local KCM, mock = loadRouted()
    mock.setItem(910014, { subType = "Food & Drink", tt = { healValue = 500 } })
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 910014, true)
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        t.ne(id, 910014, "an unowned item stays out of the discovered set")
    end
end)

-- ---------------------------------------------------------------------------
-- Recompute request plumbing
-- ---------------------------------------------------------------------------

test("RequestRecompute keeps the latest reason across a coalesced burst", function(t)
    local KCM = h.loader.loadPure()
    local scheduled = {}
    _G.C_Timer.After = function(_, fn) scheduled[#scheduled + 1] = fn end
    local seen
    KCM.Pipeline.Recompute = function(reason) seen = reason end

    KCM.Pipeline.RequestRecompute("bag_update_delayed")
    KCM.Pipeline.RequestRecompute("equip")
    scheduled[1]()
    t.eq(seen, "equip", "the burst reports the most recent trigger, not the first")
end)

test("RequestRecompute falls back to a placeholder reason when given none", function(t)
    local KCM = h.loader.loadPure()
    local scheduled = {}
    _G.C_Timer.After = function(_, fn) scheduled[#scheduled + 1] = fn end
    local seen
    KCM.Pipeline.Recompute = function(reason) seen = reason end

    KCM.Pipeline.RequestRecompute()
    scheduled[1]()
    t.eq(seen, "unknown", "debug lines always carry a reason field")
end)

test("RequestRecompute re-arms after its frame callback has fired", function(t)
    local KCM = h.loader.loadPure()
    local scheduled = {}
    _G.C_Timer.After = function(_, fn) scheduled[#scheduled + 1] = fn end
    local runs = 0
    KCM.Pipeline.Recompute = function() runs = runs + 1 end

    KCM.Pipeline.RequestRecompute("first")
    scheduled[1]()
    KCM.Pipeline.RequestRecompute("second")
    t.eq(#scheduled, 2, "a later event schedules a fresh frame callback")
    scheduled[2]()
    t.eq(runs, 2, "and runs the pipeline again")
end)

test("RequestRecompute's frame callback is inert if the request was already served", function(t)
    local KCM = h.loader.loadPure()
    local scheduled = {}
    _G.C_Timer.After = function(_, fn) scheduled[#scheduled + 1] = fn end
    local runs = 0
    KCM.Pipeline.Recompute = function() runs = runs + 1 end

    KCM.Pipeline.RequestRecompute("once")
    scheduled[1]()
    scheduled[1]()      -- a stale duplicate callback
    t.eq(runs, 1, "the pending flag stops a second run on the same request")
end)
