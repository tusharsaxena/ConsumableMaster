-- SpecHelper.lua — Spec identity + stat-priority resolution.
--
-- Keys are "<classID>_<specID>", matching Defaults_StatPriority.lua. The
-- Blizzard API id for the player's class does not change, but spec id does
-- when the player respecs; GetCurrent() is the authoritative live reading.

local _, NS = ...
local KCM = NS
KCM.SpecHelper = KCM.SpecHelper or {}
local SpecHelper = KCM.SpecHelper

-- Class id → primary stat fallback used when a per-spec priority is missing.
-- Matches Blizzard primary stat assignment for each class's DPS / Tank specs.
local CLASS_PRIMARY_FALLBACK = {
    [1]  = "STR", -- Warrior
    [2]  = "STR", -- Paladin (Holy overridden by spec-level entry)
    [3]  = "AGI", -- Hunter
    [4]  = "AGI", -- Rogue
    [5]  = "INT", -- Priest
    [6]  = "STR", -- Death Knight
    [7]  = "INT", -- Shaman (Enhancement overridden)
    [8]  = "INT", -- Mage
    [9]  = "INT", -- Warlock
    [10] = "AGI", -- Monk  (Mistweaver overridden)
    [11] = "INT", -- Druid (Feral/Guardian overridden)
    [12] = "AGI", -- Demon Hunter
    [13] = "INT", -- Evoker
}

-- ---------------------------------------------------------------------------
-- The stat model, per client (clients-§5: picked ONCE, here, by KCM.PerClient)
-- ---------------------------------------------------------------------------
--
-- Which stats a priority can name on this client, and the SHAPE a priority takes:
--
--   retail  : `{ primary = "STR"|"AGI"|"INT", secondary = { ... } }` -- a primary
--             stat and an ordered list over the four secondaries. Unchanged.
--   forever : `{ ranked = { ... } }` -- ONE ordered list over every stat Forever's
--             consumables grant, no primary (issue #48, owner ruling 2026-11-27).
--             A stat missing from the list is excluded: it weighs nothing.
--
-- Every reader -- the Ranker, the settings page, `/cm stat`, the diagnostics --
-- asks this table, never the client. `stats` is the canonical order: the order an
-- excluded tail is shown in.
--
-- Forever's set, and why each is in it (docs/schema.md -> statPriority):
--   STR AGI INT STA SPI    the five vanilla attributes
--   AP                     attack power ("gain 6 Attack Power", Frenzy potions)
--   SP                     spell damage / spell power, school-agnostic
--   FIRE_SP FROST_SP SHADOW_SP
--                          ONE school's spell damage ("Increases spell fire damage
--                          by up to 10"). Kept apart from SP on purpose: Elixir of
--                          Fire Power is worth nothing to a frost mage, so folding it
--                          into SP would rank it for every caster. Only the three
--                          schools vanilla consumables grant.
--   HEAL                   healing done by spells ("Healing Power", "Spell Healing")
--   HIT CRIT               hit and critical strike chance (percent amounts)
--   ARMOR                  armor (Elixir of Defense, Scroll of Protection, Stoneshield)
--   HEALTH MANA            maximum health / mana (Elixir of Fortitude, Flask of the
--                          Titans; Flask of Distilled Wisdom)
--   MANA_REGEN             mana every 5 sec (Mageblood)
SpecHelper.STATS = KCM.PerClient({
    retail = {
        ranked    = false,
        primaries = { "STR", "AGI", "INT" },
        stats     = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" },
    },
    forever = {
        ranked = true,
        stats  = {
            "STR", "AGI", "INT", "STA", "SPI", "AP", "SP", "FIRE_SP", "FROST_SP", "SHADOW_SP",
            "HEAL", "HIT", "CRIT", "ARMOR", "HEALTH", "MANA", "MANA_REGEN",
        },
    },
})

local RANKED_STAT = {}
for _, stat in ipairs(SpecHelper.STATS.ranked and SpecHelper.STATS.stats or {}) do RANKED_STAT[stat] = true end

--- A ranked list cleaned the way every reader and writer agrees on: only this
--- client's stats, each once, in the order given. A new table; a non-table reads
--- as empty.
function SpecHelper.CleanRanked(list)
    local out, seen = {}, {}
    if type(list) ~= "table" then return out end
    for _, stat in ipairs(list) do
        if RANKED_STAT[stat] and not seen[stat] then
            seen[stat] = true
            out[#out + 1] = stat
        end
    end
    return out
end

--- Whether a stored `statPriority` entry is an override this client reads. A
--- Retail entry names a primary; a Forever entry carries a `ranked` list. A
--- Retail-shaped entry on Forever (the pre-#48 page offered Retail's stats there)
--- is NOT one: it reads as no override, so the spec takes its shipped Forever
--- order, and nothing is written until the player edits.
function SpecHelper.IsOverride(entry)
    if type(entry) ~= "table" then return false end
    if SpecHelper.STATS.ranked then return type(entry.ranked) == "table" end
    return entry.primary ~= nil
end

--- One line for a resolved priority, for `/cm stat list`, `/cm dump` and the
--- diagnostics report. Retail's reads exactly as it always did.
function SpecHelper.DescribePriority(p)
    p = p or {}
    if p.ranked then return ("ranked=%s"):format(table.concat(p.ranked, ">")) end
    return ("primary=%s secondary=%s"):format(tostring(p.primary), table.concat(p.secondary or {}, ">"))
end

function SpecHelper.MakeKey(classID, specID)
    if not classID or not specID then return nil end
    return tostring(classID) .. "_" .. tostring(specID)
end

-- Returns: classID, specID, specKey ("<classID>_<specID>"), specName
-- Nil for all if the player has not chosen a spec yet (low-level characters).
function SpecHelper.GetCurrent()
    local _, _, classID = UnitClass("player")
    if not classID then return nil end

    local specIndex = KCM.Compat.GetSpecialization()
    if not specIndex then return classID, nil, nil, nil end

    local specID, specName = KCM.Compat.GetSpecializationInfo(specIndex)
    if not specID then return classID, nil, nil, nil end

    return classID, specID, SpecHelper.MakeKey(classID, specID), specName
end

-- Iterates every spec of every class. Yields: classID, specID, specKey, specName.
-- Used by the settings UI to show per-spec priority editors even for classes
-- the player has not logged into yet.
function SpecHelper.AllSpecs()
    local results = {}
    for classID = 1, GetNumClasses() do
        local numSpecs = KCM.Compat.GetNumSpecializationsForClassID(classID)
        for specIndex = 1, (numSpecs or 0) do
            local specID, specName = KCM.Compat.GetSpecializationInfoForClassID(classID, specIndex)
            if specID then
                table.insert(results, {
                    classID  = classID,
                    specID   = specID,
                    specKey  = SpecHelper.MakeKey(classID, specID),
                    specName = specName,
                })
            end
        end
    end
    return results
end

-- Resolve stat priority for a given specKey. Order of precedence:
--   1. user override in db.profile.statPriority[specKey]
--   2. seed default in KCM.SEED.STAT_PRIORITY[specKey]
--   3. class-primary fallback (secondary list empty; tooltip parsing remains
--      usable but with no secondary-stat tiebreak guidance)
--
-- Returns a table { primary = "STR"|"AGI"|"INT", secondary = { ... } } on Retail,
-- and { ranked = { ... } } on WoW Forever (SpecHelper.STATS). Never returns nil
-- so callers don't need to nil-check every field.

-- Forever's resolution: the override's list, else the seed's, else the class's
-- primary stat alone -- the same three steps, in the same order, as Retail's.
local function getRankedPriority(specKey)
    local db = KCM.db and KCM.db.profile
    local user = db and db.statPriority and db.statPriority[specKey]
    if SpecHelper.IsOverride(user) then
        return { ranked = SpecHelper.CleanRanked(user.ranked) }
    end
    local seed = KCM.SEED and KCM.SEED.STAT_PRIORITY and KCM.SEED.STAT_PRIORITY[specKey]
    if seed and seed.ranked then
        return { ranked = SpecHelper.CleanRanked(seed.ranked) }
    end
    local classID = type(specKey) == "string" and tonumber(specKey:match("^(%d+)_"))
    return { ranked = { (classID and CLASS_PRIMARY_FALLBACK[classID]) or "STR" } }
end

function SpecHelper.GetStatPriority(specKey)
    if SpecHelper.STATS.ranked then return getRankedPriority(specKey) end
    local db = KCM.db and KCM.db.profile
    if db and db.statPriority and db.statPriority[specKey] then
        local user = db.statPriority[specKey]
        if user.primary then
            return {
                primary   = user.primary,
                secondary = user.secondary or {},
            }
        end
    end

    local seed = KCM.SEED and KCM.SEED.STAT_PRIORITY and KCM.SEED.STAT_PRIORITY[specKey]
    if seed then
        return {
            primary   = seed.primary,
            secondary = seed.secondary or {},
        }
    end

    local classID = specKey and tonumber(specKey:match("^(%d+)_"))
    return {
        primary   = (classID and CLASS_PRIMARY_FALLBACK[classID]) or "STR",
        secondary = {},
    }
end

--- The whole `statPriority` map with ONE spec's override replaced -- or dropped,
--- for a nil entry. A new table: `statPriority` is a whole-value schema row
--- (architecture-§5), so every writer builds the map and hands it to the helper
--- rather than editing the stored one. Pure: it reads the profile and writes
--- nothing.
function SpecHelper.WithStatPriority(specKey, entry)
    local out = {}
    local cur = KCM.db and KCM.db.profile and KCM.db.profile.statPriority
    for k, v in pairs(cur or {}) do out[k] = v end
    if specKey then out[specKey] = entry end
    return out
end
