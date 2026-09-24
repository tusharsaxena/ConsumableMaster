-- Compat.lua — a single seam over the spec, spell and item client APIs.
--
-- Midnight is mid-migration from the flat GetSpecialization* / GetSpellInfo /
-- GetItemInfo globals to the C_SpecializationInfo / C_Spell / C_Item
-- namespaces. Rather than scatter "modern first, legacy fallback" chains across
-- SpecHelper, SlashCommands, MacroManager, the Ranker, the tooltip cache, the
-- widgets, and the settings tabs, every caller goes through KCM.Compat so a
-- future rename is one edit here (compat).
--
-- Loaded right after Constants so all downstream modules can rely on it.
--
-- FOUR MEMBERS ARE LibKa0s-Compat-1.0's (LibKa0s v1.55.0): GetSpecialization,
-- GetSpecializationInfo, GetSpellName and IsSecret. The call surface did not
-- move -- every caller and every test still reaches KCM.Compat.X -- only the
-- definitions did. The two class-ID spec readers below have one consumer in the
-- collection, this addon, so they stay host code (the major takes a member only
-- when two addons agreed on it). GetItemInfo, at the bottom, is host code too.
--
-- With the major absent (a partial or missing libs/LibKa0s/, which
-- core/CoreSetup.lua already announces) each wired member takes the arm the
-- major's API document prescribes, LibKa0s docs/api/Compat/version-1-docs.md,
-- "Degradation" (options-ui-§1 names both arms):
--   * a READER answers the documented absent value, nil, and copies nothing;
--   * the GUARD re-implements its one-rung body, because "the library is
--     absent" is not "the client has no secrets": a guard answering false on a
--     12.x client would send a secret into a comparison in combat.

local _, NS = ...
local KCM = NS
KCM.Compat = KCM.Compat or {}
local Compat = KCM.Compat

local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

local function absent() return nil end

-- Current player specialization index (1..N), or nil if none chosen yet.
Compat.GetSpecialization = CompatLib and CompatLib.GetSpecialization or absent

-- specID, specName, description, icon, role, ... for a spec index; nil for a
-- nil index, without calling the client with it.
Compat.GetSpecializationInfo = CompatLib and CompatLib.GetSpecializationInfo or absent

-- Number of specs for a classID (used by the per-spec editors).
function Compat.GetNumSpecializationsForClassID(classID)
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
    end
    if GetNumSpecializationsForClassID then return GetNumSpecializationsForClassID(classID) end
    return 0
end

-- specID, specName, ... for a (classID, index) pair.
function Compat.GetSpecializationInfoForClassID(classID, index)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID then
        return C_SpecializationInfo.GetSpecializationInfoForClassID(classID, index)
    end
    if GetSpecializationInfoForClassID then return GetSpecializationInfoForClassID(classID, index) end
    return nil
end

-- True when the client handed us a SECRET value.
--
-- Midnight wraps combat-restricted data — cooldown times among them — in opaque
-- "secret" values. Tainted (addon) code may pass one straight back into a client
-- API that accepts it, but comparing it or doing arithmetic on it is a hard
-- error, so every gate over client data has to ask first. issecretvalue is the
-- client's own test; on a client that predates it nothing is ever secret.
--
-- The fallback is a DELIBERATE DUPLICATION of the library's one-rung body, and
-- runs only while the major is absent: see LibKa0s
-- docs/api/Compat/version-1-docs.md, "Degradation" (the guard arm).
Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(value)
    if issecretvalue then return issecretvalue(value) and true or false end
    return false
end

-- Localized spell name for a spellID: modern C_Spell.GetSpellName, then the
-- C_Spell.GetSpellInfo shape, then the deprecated GetSpellInfo global; the first
-- rung that ANSWERS wins, so a nil or "" (data still streaming in) falls through.
-- A secret name is returned untouched and never compared with "". Returns nil
-- when unresolvable so callers can pick their own placeholder.
Compat.GetSpellName = CompatLib and CompatLib.GetSpellName or absent

-- Item info for an itemID, link or name: every return the client gives.
--
-- The flat GetItemInfo global is deprecated in favor of C_Item.GetItemInfo;
-- whether a 12.x patch still ships it is unverified, so the namespaced call is
-- tried first and the global is only a guarded fallback (anti-pattern #10).
-- Read at call time, not captured at load, so neither rung is pinned to what
-- the client carried when this file ran. Returns nil when the client has
-- neither, or when the item's data has not streamed in yet.
function Compat.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(item) end
    if GetItemInfo then return GetItemInfo(item) end
    return nil
end
