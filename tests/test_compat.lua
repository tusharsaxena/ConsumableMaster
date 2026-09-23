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

-- ---------------------------------------------------------------------------
-- Characterization, written BEFORE core/Compat.lua moved onto
-- LibKa0s-Compat-1.0 (docs/revendor/2026-09-23-v1.55.0/04_EXECUTION_PLAN.md). Each pins
-- an output the host code produced, so the adoption has to reproduce it: return
-- arity, the spec multi-return passed through untouched, and a guard that
-- answers a real boolean.
-- ---------------------------------------------------------------------------

test("Compat.GetSpellName answers exactly one value on every rung and on a miss", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setSpell(8110, { name = "Arity" })
    t.eq(select("#", KCM.Compat.GetSpellName(8110)), 1, "top rung: one value")
    local savedName = _G.C_Spell.GetSpellName
    _G.C_Spell.GetSpellName = nil
    local mid = select("#", KCM.Compat.GetSpellName(8110))
    _G.C_Spell.GetSpellName = savedName
    t.eq(mid, 1, "middle rung: one value")
    local savedSpell = _G.C_Spell
    _G.C_Spell = nil
    local legacy = select("#", KCM.Compat.GetSpellName(8110))
    _G.C_Spell = savedSpell
    t.eq(legacy, 1, "legacy rung: one value, never the global's rank or icon")
    t.eq(select("#", KCM.Compat.GetSpellName(8111)), 1, "a miss is one nil")
    t.eq(select("#", KCM.Compat.GetSpellName(nil)), 1, "a nil id is one nil")
end)

test("Compat.GetSpecializationInfo passes the rung's whole multi-return through", function(t)
    local KCM = h.loader.loadPure()
    _G.C_SpecializationInfo = {
        GetSpecializationInfo = function(i)
            return 1000 + i, "Modern", "desc", 136000, "DAMAGER", 4
        end,
    }
    local out = { KCM.Compat.GetSpecializationInfo(2) }
    local n = select("#", KCM.Compat.GetSpecializationInfo(2))
    _G.C_SpecializationInfo = nil
    t.eq(n, 6, "every value the client returned, no more and no fewer")
    t.eqList(out, { 1002, "Modern", "desc", 136000, "DAMAGER", 4 }, "in the client's order")
end)

test("Compat.IsSecret normalizes the client's answer to a real boolean", function(t)
    local KCM = h.loader.loadPure()
    _G.issecretvalue = function(v) if v == "s" then return 1 end return nil end
    local yes, no = KCM.Compat.IsSecret("s"), KCM.Compat.IsSecret("p")
    _G.issecretvalue = nil
    t.eq(yes, true, "a truthy non-boolean answer becomes true")
    t.eq(no, false, "a nil answer becomes false, not nil")
end)

-- ---------------------------------------------------------------------------
-- LibKa0s-Compat-1.0 (v1.55.0): what moving onto the major changed, on purpose
-- ---------------------------------------------------------------------------

-- red under: the host's own ladder, which compared every rung's answer with ""
-- (the defect compat.md section 2.2 row 5 names). The fixture's secret is the
-- plain string "" so the comparison the host made is observable: the host read
-- it as "no answer yet" and fell through to the next rung, where a real 12.x
-- client raises instead, in combat.
test("Compat.GetSpellName returns a secret name untouched and ends the ladder", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setSpell(8120, { name = "Plain Name" })
    local SECRET = ""
    local savedName = _G.C_Spell.GetSpellName
    _G.C_Spell.GetSpellName = function() return SECRET end
    _G.issecretvalue = function(v) return v == SECRET end
    local name = KCM.Compat.GetSpellName(8120)
    _G.issecretvalue = nil
    _G.C_Spell.GetSpellName = savedName
    t.eq(name, SECRET, "the secret is the answer; the next rung is never asked")
end)

test("Compat.GetSpellName answers nil for an id outside the client's domain, asking no rung", function(t)
    local KCM = h.loader.loadPure()
    local calls = 0
    local savedName = _G.C_Spell.GetSpellName
    _G.C_Spell.GetSpellName = function() calls = calls + 1; return "Called" end
    local tbl, bool = KCM.Compat.GetSpellName({}), KCM.Compat.GetSpellName(true)
    _G.C_Spell.GetSpellName = savedName
    t.eq(tbl, nil, "a table id answers nil")
    t.eq(bool, nil, "a boolean id answers nil")
    t.eq(calls, 0, "and the client was never called with either")
end)

-- The degraded load: libs/LibKa0s/ skipped for real (testing-§8), never
-- the member stubbed. Readers answer the absent table (LibKa0s
-- docs/api/Compat/version-1-docs.md, "The absent table"); the guard answers what
-- the library answers under the same issecretvalue fixture; the two host-only
-- class-ID readers are untouched by the library's absence.
test("Compat degraded: readers answer nil, the guard still asks the client", function(t)
    local live     = h.loader.loadPure()
    local token    = {}
    _G.issecretvalue = function(v) return v == token end
    local liveHit, liveMiss = live.Compat.IsSecret(token), live.Compat.IsSecret(300)
    _G.issecretvalue = nil

    local KCM  = h.loader.loadPureDegraded()
    local mock = h.loader.mock
    mock.setSpell(8130, { name = "Would Resolve" })
    local C = KCM.Compat
    t.eq(C.GetSpecialization(), nil, "GetSpecialization: the absent value")
    t.eq(select("#", C.GetSpecializationInfo(1)), 1, "GetSpecializationInfo: one value")
    t.eq(C.GetSpecializationInfo(1), nil, "and it is nil")
    t.eq(C.GetSpellName(8130), nil, "GetSpellName: nil, though the client would have answered")
    t.eq(C.GetNumSpecializationsForClassID(7), 1, "the host-only spec count still reads the client")
    t.eq((C.GetSpecializationInfoForClassID(7, 1)), 263, "and so does the host-only per-class reader")

    t.eq(C.IsSecret(300), false, "the guard with no secrets system answers false")
    _G.issecretvalue = function(v) return v == token end
    local hit, miss = C.IsSecret(token), C.IsSecret(300)
    _G.issecretvalue = nil
    t.eq(hit, liveHit, "the guard arm agrees with the library on a secret")
    t.eq(miss, liveMiss, "and on a plain value")
    t.eq(hit, true, "which is true for the secret")
end)
