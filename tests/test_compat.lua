-- test_compat.lua — the spec + spell client-API seam (KCM.Compat).
--
-- The mock provides only the legacy globals (no C_SpecializationInfo), so these
-- exercise Compat's fallback chain down to GetSpecialization* / GetSpellInfo.

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadPure()
    return KCM.Compat, h.loader.mock
end

test("Compat.GetSpecialization returns the live spec index", function(t)
    local C, mock = load()
    t.eq(C.GetSpecialization(), 1, "default index")
    mock.setSpec(7, 3, 263, "Enhancement")
    t.eq(C.GetSpecialization(), 3, "reflects respec")
end)

test("Compat.GetSpecializationInfo maps an index to specID + name", function(t)
    local C = load()
    local id, name = C.GetSpecializationInfo(1)
    t.eq(id, 263, "specID")
    t.eq(name, "Enhancement", "name")
    t.eq(C.GetSpecializationInfo(nil), nil, "nil index -> nil")
    t.eq((C.GetSpecializationInfo(2)), nil, "unknown index -> nil")
end)

test("Compat.GetNumSpecializationsForClassID delegates to the client", function(t)
    local C = load()
    t.eq(C.GetNumSpecializationsForClassID(7), 1, "one spec in mock")
end)

test("Compat.GetSpecializationInfoForClassID maps (class,index) to a spec", function(t)
    local C = load()
    local id, name = C.GetSpecializationInfoForClassID(7, 1)
    t.eq(id, 263, "specID")
    t.eq(name, "Enhancement", "name")
    t.eq((C.GetSpecializationInfoForClassID(1, 1)), nil, "wrong class -> nil")
end)

test("Compat.GetSpellName resolves known spells and nil otherwise", function(t)
    local C, mock = load()
    mock.setSpell(5512, { name = "Healthstone" })
    t.eq(C.GetSpellName(5512), "Healthstone", "known spell name")
    t.eq(C.GetSpellName(nil), nil, "nil id -> nil")
    t.eq(C.GetSpellName(999999), nil, "unknown spell -> nil")
end)
