-- test_pipeline.lua — the recompute pipeline: coalescing, auto-discovery, and
-- the macro-write loop (KCM.Pipeline in core/ConsumableMaster.lua).

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadPure()
    return KCM, h.loader.mock
end

-- A Food & Drink heal item that is NOT in any shipped seed, so discovery has
-- something new to find.
local function ownFood(mock, id)
    mock.setItem(id, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(id, 1)
end

local function effectiveSet(KCM, catKey)
    local set = {}
    for _, id in ipairs(KCM.Selector.GetEffectivePriority(catKey)) do set[id] = true end
    return set
end

test("Pipeline.RequestRecompute coalesces a burst into a single run", function(t)
    local KCM = h.loader.loadPure()
    -- Capture the frame callback instead of firing it (the mock's C_Timer.After
    -- runs synchronously), so we can observe the coalescing gate.
    local scheduled = {}
    _G.C_Timer.After = function(_, fn) scheduled[#scheduled + 1] = fn end
    local runs = 0
    KCM.Pipeline.Recompute = function() runs = runs + 1 end

    KCM.Pipeline.RequestRecompute("a")
    KCM.Pipeline.RequestRecompute("b")
    KCM.Pipeline.RequestRecompute("c")
    t.eq(#scheduled, 1, "only one timer scheduled for the whole burst")
    t.eq(runs, 0, "nothing runs until the frame fires")

    scheduled[1]()   -- fire the end-of-frame callback
    t.eq(runs, 1, "the burst collapsed into a single recompute")
end)

test("Pipeline.RunAutoDiscovery adds a classifiable bag item to its category", function(t)
    local KCM, mock = load()
    ownFood(mock, 900001)
    local n = KCM.Pipeline.RunAutoDiscovery("test")
    t.truthy(n >= 1, "reported at least one discovery")
    t.truthy(effectiveSet(KCM, "FOOD")[900001], "discovered item joined FOOD candidates")
end)

test("Pipeline.RunAutoDiscovery keeps a user-blocked item out of candidates", function(t)
    local KCM, mock = load()
    ownFood(mock, 900002)
    KCM.Selector.Block("FOOD", 900002)   -- user blocked it before discovery ran
    KCM.Pipeline.RunAutoDiscovery("test")
    t.falsy(effectiveSet(KCM, "FOOD")[900002], "blocked item stays out of candidates")
end)

test("Pipeline.Recompute writes a macro body pointing at the owned pick", function(t)
    local KCM, mock = load()
    ownFood(mock, 900003)
    KCM.Pipeline.RunAutoDiscovery("test")
    KCM.Pipeline.Recompute("test")
    local m = mock.macros["KCM_FOOD"]
    t.truthy(m, "KCM_FOOD macro created")
    t.truthy(m.body and m.body:find("900003", 1, true), "body points at the owned item")
end)

test("Pipeline.Recompute skips macro writes when the addon is disabled", function(t)
    local KCM, mock = load()
    ownFood(mock, 900004)
    KCM.Pipeline.RunAutoDiscovery("test")
    KCM.db.profile.enabled = false
    KCM.Pipeline.Recompute("test")
    t.eq(mock.macros["KCM_FOOD"], nil, "no macro written while disabled")
end)

test("Pipeline.RecomputeOne routes a perHand category through SetWeaponEnchantMacro", function(t)
    local KCM, mock = load()
    local S = KCM.Selector

    -- A bladed whetstone the player owns; equipped weapons are both bladed
    -- so the main-hand pick resolves to this item.
    mock.setItem(6201, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    S.AddItem("WPN_ENCH", 6201)
    mock.setBag(6201, 1)

    mock.setItem(6300, { subType = "One-Handed Swords" }); mock.setEquipped(16, 6300)
    mock.setItem(6301, { subType = "One-Handed Swords" }); mock.setEquipped(17, 6301)

    KCM.Pipeline.RecomputeOne("WPN_ENCH", nil, "test")

    local state = KCM.db.profile.macroState["KCM_WPN_ENCH"]
    t.truthy(state and state.lastBody, "WPN_ENCH macro body was written")
    t.truthy(state.lastBody:find("/use 16", 1, true), "body applies the main-hand enchant")
    t.truthy(state.lastBody:find("6201", 1, true), "body references the bladed pick")
end)
