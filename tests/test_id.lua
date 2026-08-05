-- test_id.lua — opaque ID sentinel helpers (KCM.ID.*).

local h = _G.KCM_TEST
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

test("ID.AsSpell/SpellID round-trips", function(t)
    local I = ID()
    t.eq(I.SpellID(I.AsSpell(1231411)), 1231411, "round-trip")
end)

test("ID predicates reject non-numeric input rather than raising", function(t)
    local KCM = h.loader.loadPure()
    for _, v in ipairs({ "5512", true, {} }) do
        t.eq(KCM.ID.IsSpell(v), false, "IsSpell(" .. type(v) .. ") is false")
        t.eq(KCM.ID.IsItem(v), false, "IsItem(" .. type(v) .. ") is false")
        t.eq(KCM.ID.SpellID(v), nil, "SpellID(" .. type(v) .. ") is nil")
    end
    t.eq(KCM.ID.IsSpell(nil), false, "IsSpell(nil) is false")
    t.eq(KCM.ID.IsItem(nil), false, "IsItem(nil) is false")
end)

test("ID treats zero as neither an item nor a spell", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.ID.IsItem(0), false, "0 is not an itemID")
    t.eq(KCM.ID.IsSpell(0), false, "0 is not a spell sentinel")
    t.eq(KCM.ID.SpellID(0), nil, "0 recovers no spellID")
end)

test("ID: item and spell ranges are disjoint for every real id", function(t)
    local KCM = h.loader.loadPure()
    for _, itemID in ipairs({ 1, 5512, 224464, 259085 }) do
        local sentinel = KCM.ID.AsSpell(itemID)
        t.truthy(KCM.ID.IsItem(itemID) and not KCM.ID.IsSpell(itemID), itemID .. " is item-only")
        t.truthy(KCM.ID.IsSpell(sentinel) and not KCM.ID.IsItem(sentinel),
            "its sentinel " .. sentinel .. " is spell-only")
    end
end)
