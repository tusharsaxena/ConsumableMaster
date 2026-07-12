-- test_id.lua — opaque ID sentinel helpers (KCM.ID.*).

local h = require("harness")

h.suite("ID sentinels", function(t)
    local KCM = h.loader.loadPure()
    local ID = KCM.ID

    t.eq(ID.AsSpell(5512), -5512, "AsSpell negates")
    t.truthy(ID.IsSpell(-5512), "negative is spell")
    t.falsy(ID.IsSpell(5512), "positive is not spell")
    t.falsy(ID.IsSpell("x"), "non-number is not spell")

    t.truthy(ID.IsItem(171267), "positive is item")
    t.falsy(ID.IsItem(-1), "negative is not item")

    t.eq(ID.SpellID(-5512), 5512, "SpellID recovers magnitude")
    t.eq(ID.SpellID(5512), nil, "SpellID nil for item")
    t.eq(ID.ItemID(171267), 171267, "ItemID passthrough")
    t.eq(ID.ItemID(-5512), nil, "ItemID nil for spell")

    -- Round-trip
    t.eq(ID.SpellID(ID.AsSpell(1231411)), 1231411, "AsSpell/SpellID round-trip")
end)
