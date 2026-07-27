-- test_bagscanner.lua — bag enumeration + ownership (KCM.BagScanner).

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadPure()
    return KCM.BagScanner, h.loader.mock
end

test("BagScanner.Scan is empty when bags are empty", function(t)
    local BS = load()
    t.eq(next(BS.Scan()), nil, "no items")
end)

test("BagScanner.Scan aggregates distinct items to itemID -> count", function(t)
    local BS, mock = load()
    mock.setBag(100, 3)
    mock.setBag(200, 1)
    local counts = BS.Scan()
    t.eq(counts[100], 3, "item 100 count")
    t.eq(counts[200], 1, "item 200 count")
end)

test("BagScanner.Scan sums separate stacks of the same item", function(t)
    local BS, mock = load()
    mock.setBag(100, 3)
    mock.setBag(100, 2)   -- a second stack of the same item in another slot
    t.eq(BS.Scan()[100], 5, "stacks summed across slots")
end)

test("BagScanner.HasItem reports ownership and count", function(t)
    local BS, mock = load()
    mock.setBag(100, 4)
    local owned, n = BS.HasItem(100)
    t.truthy(owned, "owned when in bags")
    t.eq(n, 4, "returns the count")
    local no, z = BS.HasItem(300)
    t.falsy(no, "not owned when absent")
    t.eq(z, 0, "zero count when absent")
end)

test("BagScanner.HasItem is false for a nil id", function(t)
    local BS = load()
    local owned, n = BS.HasItem(nil)
    t.falsy(owned, "nil id -> not owned")
    t.eq(n, 0, "nil id -> zero count")
end)

test("BagScanner.Scan treats a slot with no stackCount as a single item", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    -- A container slot the client reported without a stack size.
    mock.bagSlots[#mock.bagSlots + 1] = { itemID = 777001 }
    t.eq(KCM.BagScanner.Scan()[777001], 1, "missing stackCount counts as one")
end)

test("BagScanner.Scan skips empty slots without inventing entries", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setBag(777002, 3)
    mock.bagSlots[#mock.bagSlots + 1] = {}          -- an empty slot
    local counts = KCM.BagScanner.Scan()
    t.eq(counts[777002], 3, "the real item is still counted")
    local n = 0
    for _ in pairs(counts) do n = n + 1 end
    t.eq(n, 1, "the empty slot contributed nothing")
end)

test("BagScanner.Scan returns an empty table when the container API is absent", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setBag(777003, 1)
    local saved = _G.C_Container
    _G.C_Container = nil
    local counts = KCM.BagScanner.Scan()
    _G.C_Container = saved
    t.eq(next(counts), nil, "a missing C_Container degrades to 'own nothing', not an error")
end)

test("BagScanner.Scan walks the reagent bag slot, not just the backpack", function(t)
    local KCM = h.loader.loadPure()
    local visited = {}
    local saved = _G.C_Container
    _G.C_Container = {
        GetContainerNumSlots = function(bag) visited[bag] = true; return 0 end,
        GetContainerItemInfo = function() return nil end,
    }
    KCM.BagScanner.Scan()
    _G.C_Container = saved
    t.truthy(visited[0], "backpack scanned")
    t.truthy(visited[_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS],
        "the last equipped bag index is inclusive, so the reagent bag is scanned")
end)

test("BagScanner.HasItem answers from Blizzard's tally, not a full bag walk", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setBag(777004, 2)
    local scans = 0
    local realScan = KCM.BagScanner.Scan
    KCM.BagScanner.Scan = function() scans = scans + 1; return realScan() end
    local owned, count = KCM.BagScanner.HasItem(777004)
    KCM.BagScanner.Scan = realScan
    t.eq(owned, true, "owned")
    t.eq(count, 2, "count comes straight from GetItemCount")
    t.eq(scans, 0, "no O(bags*slots) walk on this hot path")
end)

test("BagScanner.HasItem counts bank stacks in via the includeBank flag", function(t)
    local KCM = h.loader.loadPure()
    local args
    local saved = _G.C_Item.GetItemCount
    _G.C_Item.GetItemCount = function(...) args = { ... }; return 5 end
    local owned, count = KCM.BagScanner.HasItem(777005)
    _G.C_Item.GetItemCount = saved
    t.eq(owned, true, "reported owned")
    t.eq(count, 5, "count passed through")
    t.eq(args[4], true, "reagent-bank stacks are included in the tally")
end)

test("BagScanner.HasItem reports not-owned when the item count API is absent", function(t)
    local KCM = h.loader.loadPure()
    local saved = _G.C_Item
    _G.C_Item = nil
    local owned, count = KCM.BagScanner.HasItem(777006)
    _G.C_Item = saved
    t.eq(owned, false, "degrades to not-owned")
    t.eq(count, 0, "with a zero count rather than nil")
end)
