-- test_id.lua — opaque ID sentinel helpers (KCM.ID.*).

local h = require("harness")
local test = h.test

local function ID() return h.loader.loadPure().ID end

test("ID.AsSpell negates the spellID into a sentinel", function(t)
    t.eq(ID().AsSpell(5512), -5512, "AsSpell negates")
end)

test("ID.IsSpell is true for negatives, false otherwise", function(t)
    local I = ID()
    t.truthy(I.IsSpell(-5512), "negative is spell")
    t.falsy(I.IsSpell(5512), "positive is not spell")
    t.falsy(I.IsSpell("x"), "non-number is not spell")
end)

test("ID.IsItem is true for positives, false for negatives", function(t)
    local I = ID()
    t.truthy(I.IsItem(171267), "positive is item")
    t.falsy(I.IsItem(-1), "negative is not item")
end)

test("ID.SpellID recovers magnitude for spells, nil for items", function(t)
    local I = ID()
    t.eq(I.SpellID(-5512), 5512, "SpellID recovers magnitude")
    t.eq(I.SpellID(5512), nil, "SpellID nil for item")
end)

test("ID.ItemID passes through items, nil for spells", function(t)
    local I = ID()
    t.eq(I.ItemID(171267), 171267, "ItemID passthrough")
    t.eq(I.ItemID(-5512), nil, "ItemID nil for spell")
end)

test("ID.AsSpell/SpellID round-trips", function(t)
    local I = ID()
    t.eq(I.SpellID(I.AsSpell(1231411)), 1231411, "round-trip")
end)
