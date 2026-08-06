-- Compat.lua — a single seam over the spec + spell client APIs.
--
-- Midnight is mid-migration from the flat GetSpecialization* / GetSpellInfo
-- globals to the C_SpecializationInfo / C_Spell namespaces. Rather than scatter
-- "modern first, legacy fallback" chains across SpecHelper, SlashCommands,
-- MacroManager, the widgets, and the settings tabs, every caller goes through
-- KCM.Compat so a future rename is one edit here (compat).
--
-- Loaded right after Constants so all downstream modules can rely on it.

local _, NS = ...
local KCM = NS
KCM.Compat = KCM.Compat or {}
local Compat = KCM.Compat

-- Current player specialization index (1..N), or nil if none chosen yet.
function Compat.GetSpecialization()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    if GetSpecialization then return GetSpecialization() end
    return nil
end

-- specID, specName, description, icon, role, ... for a spec index.
function Compat.GetSpecializationInfo(index)
    if not index then return nil end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        return C_SpecializationInfo.GetSpecializationInfo(index)
    end
    if GetSpecializationInfo then return GetSpecializationInfo(index) end
    return nil
end

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
function Compat.IsSecret(value)
    if issecretvalue then return issecretvalue(value) and true or false end
    return false
end

-- Localized spell name for a spellID: modern C_Spell.GetSpellName, then the
-- C_Spell.GetSpellInfo shape, then the deprecated GetSpellInfo global. Returns
-- nil when unresolvable so callers can pick their own placeholder.
function Compat.GetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellID)
        if n and n ~= "" then return n end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name and info.name ~= "" then return info.name end
    end
    if GetSpellInfo then
        local n = GetSpellInfo(spellID)
        if n and n ~= "" then return n end
    end
    return nil
end
