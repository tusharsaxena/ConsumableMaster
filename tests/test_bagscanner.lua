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
