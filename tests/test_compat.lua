-- test_compat.lua — the spec + spell client-API seam (KCM.Compat).
--
-- The mock provides only the legacy globals (no C_SpecializationInfo), so these
-- exercise Compat's fallback chain down to GetSpecialization* / GetSpellInfo.

local h = _G.KCM_TEST
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

test("Compat.IsSecret defers to the client's own issecretvalue", function(t)
    local KCM   = h.loader.loadPure()
    local token = {}
    _G.issecretvalue = function(v) return v == token end
    local hit, miss = KCM.Compat.IsSecret(token), KCM.Compat.IsSecret(300)
    _G.issecretvalue = nil
    t.eq(hit, true, "a secret is reported as one")
    t.eq(miss, false, "a plain number is not")
end)

test("Compat.IsSecret reports nothing secret on a pre-Midnight client", function(t)
    local KCM = h.loader.loadPure()
    t.eq(_G.issecretvalue, nil, "the mock client predates secret values")
    t.eq(KCM.Compat.IsSecret(300), false,
        "so every gate over client data takes its normal, comparing path")
end)

test("Compat prefers C_SpecializationInfo over the legacy spec globals", function(t)
    local KCM = h.loader.loadPure()
    _G.C_SpecializationInfo = {
        GetSpecialization = function() return 99 end,
        GetSpecializationInfo = function(i) return 1000 + i, "Modern" end,
        GetNumSpecializationsForClassID = function() return 4 end,
        GetSpecializationInfoForClassID = function(_, i) return 2000 + i, "ModernForClass" end,
    }
    t.eq(KCM.Compat.GetSpecialization(), 99, "index comes from the namespaced API")
    local specID, name = KCM.Compat.GetSpecializationInfo(1)
    t.eq(specID, 1001, "spec id comes from the namespaced API")
    t.eq(name, "Modern", "and so does the name")
    t.eq(KCM.Compat.GetNumSpecializationsForClassID(7), 4, "spec count comes from the namespaced API")
    t.eq((KCM.Compat.GetSpecializationInfoForClassID(7, 1)), 2001, "per-class lookup too")
    _G.C_SpecializationInfo = nil
end)

test("Compat falls back to the flat globals when the namespace is absent", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    t.eq(_G.C_SpecializationInfo, nil, "the mock client exposes only the legacy globals")
    t.eq(KCM.Compat.GetSpecialization(), mock.spec.specIndex, "legacy GetSpecialization is used")
end)

test("Compat.GetSpecializationInfo guards a nil index", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Compat.GetSpecializationInfo(nil), nil,
        "a specless character short-circuits before hitting the client API")
end)

test("Compat.GetNumSpecializationsForClassID reports zero when no API answers", function(t)
    local KCM = h.loader.loadPure()
    local saved = _G.GetNumSpecializationsForClassID
    _G.GetNumSpecializationsForClassID = nil
    local n = KCM.Compat.GetNumSpecializationsForClassID(7)
    _G.GetNumSpecializationsForClassID = saved
    t.eq(n, 0, "zero, so the caller's `for i = 1, n` loop simply does not run")
end)

test("Compat.GetSpecializationInfoForClassID returns nil for an unknown pair", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Compat.GetSpecializationInfoForClassID(99, 99), nil, "no such class/spec")
end)

test("Compat.GetSpellName guards a nil spellID before touching the client", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Compat.GetSpellName(nil), nil, "nil in, nil out")
end)

test("Compat.GetSpellName treats an empty name as unresolved and keeps looking", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setSpell(8100, { name = "Real Name" })
    -- The modern call answers with "" (item data still streaming in); the
    -- fallback chain must not accept that as an answer.
    local savedName = _G.C_Spell.GetSpellName
    _G.C_Spell.GetSpellName = function() return "" end
    local name = KCM.Compat.GetSpellName(8100)
    _G.C_Spell.GetSpellName = savedName
    t.eq(name, "Real Name", "an empty string falls through to the next API in the chain")
end)

test("Compat.GetSpellName falls back to the C_Spell.GetSpellInfo shape", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setSpell(8101, { name = "Info Shape" })
    local saved = _G.C_Spell.GetSpellName
    _G.C_Spell.GetSpellName = nil
    local name = KCM.Compat.GetSpellName(8101)
    _G.C_Spell.GetSpellName = saved
    t.eq(name, "Info Shape", "the info-table form answers when the direct getter is gone")
end)

test("Compat.GetSpellName falls back to the deprecated global last", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setSpell(8102, { name = "Legacy" })
    local saved = _G.C_Spell
    _G.C_Spell = nil
    local name = KCM.Compat.GetSpellName(8102)
    _G.C_Spell = saved
    t.eq(name, "Legacy", "a pre-namespace client still resolves the name")
end)

test("Compat.GetSpellName returns nil when nothing can resolve the id", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Compat.GetSpellName(8103), nil,
        "callers pick their own placeholder rather than being handed a fake name")
end)
