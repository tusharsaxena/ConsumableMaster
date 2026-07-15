-- test_spechelper.lua — spec identity + stat-priority resolution (KCM.SpecHelper).

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadPure()
    return KCM, h.loader.mock
end

test("SpecHelper.MakeKey joins classID_specID, nil on missing parts", function(t)
    local KCM = load()
    local S = KCM.SpecHelper
    t.eq(S.MakeKey(7, 263), "7_263", "joins with underscore")
    t.eq(S.MakeKey(nil, 263), nil, "nil classID -> nil")
    t.eq(S.MakeKey(7, nil), nil, "nil specID -> nil")
end)

test("SpecHelper.GetCurrent reads the live spec and re-reads on respec", function(t)
    local KCM, mock = load()
    local classID, specID, key, name = KCM.SpecHelper.GetCurrent()
    t.eq(classID, 7, "default mock class is Shaman(7)")
    t.eq(specID, 263, "default mock spec is Enhancement(263)")
    t.eq(key, "7_263", "key composed")
    t.eq(name, "Enhancement", "spec name")

    mock.setSpec(5, 1, 256, "Discipline")
    local c2, s2, k2, n2 = KCM.SpecHelper.GetCurrent()
    t.eq(c2, 5, "respec class")
    t.eq(s2, 256, "respec specID")
    t.eq(k2, "5_256", "respec key")
    t.eq(n2, "Discipline", "respec name")
end)

test("SpecHelper.GetCurrent returns classID-only when no spec is chosen", function(t)
    local KCM, mock = load()
    mock.setSpec(7, nil, nil, nil)   -- low-level character: no spec index yet
    local classID, specID, key, name = KCM.SpecHelper.GetCurrent()
    t.eq(classID, 7, "class still known")
    t.eq(specID, nil, "no specID")
    t.eq(key, nil, "no key")
    t.eq(name, nil, "no name")
end)

test("SpecHelper.GetStatPriority honours a user override", function(t)
    local KCM = load()
    KCM.db.profile.statPriority = KCM.db.profile.statPriority or {}
    KCM.db.profile.statPriority["99_1"] = { primary = "INT", secondary = { "CRIT", "HASTE" } }
    local p = KCM.SpecHelper.GetStatPriority("99_1")
    t.eq(p.primary, "INT", "override primary")
    t.eqList(p.secondary, { "CRIT", "HASTE" }, "override secondary")
end)

test("SpecHelper.GetStatPriority falls back to class primary, never nil", function(t)
    local KCM = load()
    local S = KCM.SpecHelper
    -- unknown spec for a known class -> class-primary fallback, empty secondary
    local mage = S.GetStatPriority("8_9999")   -- classID 8 = Mage -> INT
    t.eq(mage.primary, "INT", "Mage(8) fallback -> INT")
    t.eqList(mage.secondary, {}, "fallback secondary empty")
    -- unresolvable class token -> STR default
    t.eq(S.GetStatPriority("bogus").primary, "STR", "unknown class token -> STR")
    -- never returns nil, even for a nil key
    t.eq(type(S.GetStatPriority(nil)), "table", "nil key still returns a table")
end)

test("SpecHelper.GetStatPriority returns a well-formed seed default for a real spec", function(t)
    local KCM = load()
    local p = KCM.SpecHelper.GetStatPriority("7_263")   -- Enhancement
    local primaryOK = (p.primary == "STR" or p.primary == "AGI" or p.primary == "INT")
    t.truthy(primaryOK, "seed primary is a valid stat")
    t.eq(type(p.secondary), "table", "seed secondary is a list")
end)

test("SpecHelper.AllSpecs enumerates specs including the current one", function(t)
    local KCM = load()
    local all = KCM.SpecHelper.AllSpecs()
    t.truthy(#all >= 1, "at least one spec enumerated")
    local current
    for _, s in ipairs(all) do if s.specKey == "7_263" then current = s end end
    t.truthy(current, "current spec present in enumeration")
    t.eq(current.specName, "Enhancement", "carries the spec name")
end)
