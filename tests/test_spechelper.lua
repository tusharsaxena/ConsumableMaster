-- test_spechelper.lua — spec identity + stat-priority resolution (KCM.SpecHelper).

local h = _G.KCM_TEST
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

test("SpecHelper.GetStatPriority honors a user override", function(t)
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

test("SpecHelper.MakeKey is stable regardless of numeric or string inputs", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SpecHelper.MakeKey(7, 263), "7_263", "numbers join with an underscore")
    t.eq(KCM.SpecHelper.MakeKey("7", "263"), "7_263", "pre-stringified ids produce the same key")
end)

test("SpecHelper.GetCurrent returns nothing when the client has no class yet", function(t)
    local KCM = h.loader.loadPure()
    local saved = _G.UnitClass
    _G.UnitClass = function() return nil, nil, nil end
    local classID = KCM.SpecHelper.GetCurrent()
    _G.UnitClass = saved
    t.eq(classID, nil, "no class means no spec identity at all")
end)

test("SpecHelper.GetCurrent stops at the classID when the spec id is unresolvable", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local saved = _G.GetSpecializationInfo
    _G.GetSpecializationInfo = function() return nil end
    local classID, specID, specKey = KCM.SpecHelper.GetCurrent()
    _G.GetSpecializationInfo = saved
    t.eq(classID, mock.spec.classID, "the class is still reported")
    t.eq(specID, nil, "but no spec id is invented")
    t.eq(specKey, nil, "and no key is built from a missing half")
end)

test("SpecHelper.GetStatPriority ignores a user row that names no primary", function(t)
    local KCM = h.loader.loadPure()
    local key = "7_263"
    KCM.db.profile.statPriority[key] = { secondary = { "CRIT" } }   -- half-written row
    local seeded = KCM.SEED.STAT_PRIORITY[key]
    local got = KCM.SpecHelper.GetStatPriority(key)
    t.eq(got.primary, seeded.primary, "falls through to the seed rather than returning a nil primary")
end)

test("SpecHelper.GetStatPriority defaults a user override's secondary list to empty", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.statPriority["7_263"] = { primary = "AGI" }
    local got = KCM.SpecHelper.GetStatPriority("7_263")
    t.eq(got.primary, "AGI", "the override's primary wins")
    t.eqList(got.secondary, {}, "and the missing secondary list is an empty table, never nil")
end)

test("SpecHelper.GetStatPriority falls back on class primary for an unseeded spec", function(t)
    local KCM = h.loader.loadPure()
    -- classID 8 is Mage; a spec id that does not exist forces the class fallback.
    local got = KCM.SpecHelper.GetStatPriority("8_99999")
    t.eq(got.primary, "INT", "class-primary fallback keyed off the classID prefix")
    t.eqList(got.secondary, {}, "with no secondary guidance")
end)

test("SpecHelper.GetStatPriority never returns nil, even for a malformed key", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs({ "not_a_key", "", "999_1" }) do
        local got = KCM.SpecHelper.GetStatPriority(key)
        t.truthy(got and got.primary, "'" .. key .. "' still yields a usable primary")
        t.truthy(got.secondary, "'" .. key .. "' still yields a secondary table")
    end
    local nilKey = KCM.SpecHelper.GetStatPriority(nil)
    t.eq(nilKey.primary, "STR", "a nil key lands on the last-resort default")
end)

test("SpecHelper.AllSpecs yields fully-formed rows keyed the same way as GetCurrent", function(t)
    local KCM = h.loader.loadPure()
    local all = KCM.SpecHelper.AllSpecs()
    t.truthy(#all >= 1, "at least one spec is enumerated")
    for _, row in ipairs(all) do
        t.truthy(row.classID and row.specID, "row carries both ids")
        t.eq(row.specKey, KCM.SpecHelper.MakeKey(row.classID, row.specID),
            "row key matches MakeKey, so it indexes the same tables GetCurrent does")
    end
end)

test("SpecHelper.AllSpecs skips classes the client reports no specs for", function(t)
    local KCM = h.loader.loadPure()
    local saved = _G.GetNumSpecializationsForClassID
    _G.GetNumSpecializationsForClassID = function() return 0 end
    local all = KCM.SpecHelper.AllSpecs()
    _G.GetNumSpecializationsForClassID = saved
    t.eq(#all, 0, "an empty enumeration is returned rather than raising on a nil count")
end)
