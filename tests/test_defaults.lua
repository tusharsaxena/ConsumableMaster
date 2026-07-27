-- tests/test_defaults.lua — integrity of the shipped data tables.
--
-- defaults/ is data, not code: nothing executes it at load beyond building
-- tables, so a typo (a duplicate itemID, a macro name over Blizzard's 16-char
-- limit, a composite pointing at a category that no longer exists, a stat
-- priority naming a stat the Ranker doesn't weight) fails silently in game and
-- only shows up as a macro that never resolves. These cases are the guard rail
-- for hand-maintained seed data.

local h = require("harness")
local test = h.test

-- Blizzard truncates macro names past 16 characters, and GetMacroIndexByName
-- then never finds ours again.
local MACRO_NAME_LIMIT = 16

local VALID_PRIMARY   = { STR = true, AGI = true, INT = true }
local VALID_SECONDARY = { HASTE = true, CRIT = true, MASTERY = true, VERSATILITY = true }

local ITEM_SEED_KEYS = {
    "FOOD", "DRINK", "STAT_FOOD", "HP_POT", "MP_POT", "HS",
    "CMBT_POT", "FLASK", "VANTUS", "WPN_ENCH", "AUG_RUNE",
}

-- ---------------------------------------------------------------------------
-- Category metadata
-- ---------------------------------------------------------------------------

test("Categories: every row has a unique key and BY_KEY resolves it", function(t)
    local KCM = h.loader.loadPure()
    local seen = {}
    for _, row in ipairs(KCM.Categories.LIST) do
        t.truthy(row.key, "row has a key")
        t.falsy(seen[row.key], "key '" .. tostring(row.key) .. "' appears once")
        seen[row.key] = true
        t.eq(KCM.Categories.Get(row.key), row, "Categories.Get('" .. row.key .. "') returns the row")
    end
end)

test("Categories: Get returns nil for a key that isn't registered", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Categories.Get("NOT_A_CATEGORY"), nil, "unknown key resolves to nil")
    t.eq(KCM.Categories.Get(nil), nil, "nil key is a safe lookup")
end)

test("Categories: every macro name is unique, KCM_-prefixed, and within 16 chars", function(t)
    local KCM = h.loader.loadPure()
    local seen = {}
    for _, row in ipairs(KCM.Categories.LIST) do
        local name = row.macroName
        t.truthy(name, row.key .. " has a macroName")
        t.falsy(seen[name], "macro name '" .. tostring(name) .. "' is unique")
        seen[name] = true
        t.eq(name:sub(1, 4), "KCM_", name .. " is namespaced")
        t.truthy(#name <= MACRO_NAME_LIMIT,
            name .. " is " .. #name .. " chars (Blizzard truncates past " .. MACRO_NAME_LIMIT .. ")")
    end
end)

test("Categories: every row carries a display name and an empty-state body", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        t.truthy(row.displayName and #row.displayName > 0, row.key .. " has a displayName")
        t.truthy(row.emptyText, row.key .. " has emptyText")
        t.truthy(row.emptyText:find("/run print(", 1, true),
            row.key .. " emptyText is a runnable chat line")
        t.truthy(row.emptyText:find(KCM.PREFIX, 1, true),
            row.key .. " emptyText carries the shared [CM] prefix, not an inline literal")
    end
end)

test("Categories: single-pick rows declare both a classifier and a ranker key", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        if not row.composite then
            t.truthy(row.classifier, row.key .. " has a classifier hint")
            t.truthy(row.rankerKey, row.key .. " has a ranker key")
        end
    end
end)

test("Categories: composite rows carry components and no ranker/classifier hint", function(t)
    local KCM = h.loader.loadPure()
    local composites = 0
    for _, row in ipairs(KCM.Categories.LIST) do
        if row.composite then
            composites = composites + 1
            t.truthy(row.components, row.key .. " has a components table")
            t.truthy(row.components.inCombat, row.key .. " has an inCombat section")
            t.truthy(row.components.outOfCombat, row.key .. " has an outOfCombat section")
            t.falsy(row.rankerKey, row.key .. " has no ranker key — picks come from its parts")
            t.falsy(row.classifier, row.key .. " has no classifier — nothing classifies INTO a composite")
        end
    end
    t.truthy(composites >= 1, "at least one composite ships (HP_AIO / MP_AIO)")
end)

test("Categories: every composite component names a real single-pick category", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        if row.composite then
            for _, section in ipairs({ "inCombat", "outOfCombat" }) do
                for _, ref in ipairs(row.components[section]) do
                    local sub = KCM.Categories.Get(ref)
                    t.truthy(sub, row.key .. "." .. section .. " -> '" .. ref .. "' exists")
                    t.falsy(sub and sub.composite,
                        row.key .. "." .. section .. " -> " .. ref .. " is not itself composite")
                end
            end
        end
    end
end)

test("Categories: only the Weapon Enchant row is per-hand, and it is spec-aware", function(t)
    local KCM = h.loader.loadPure()
    local perHand = {}
    for _, row in ipairs(KCM.Categories.LIST) do
        if row.perHand then perHand[#perHand + 1] = row.key end
    end
    t.eqList(perHand, { "WPN_ENCH" }, "WPN_ENCH is the only per-hand category")
    t.eq(KCM.Categories.Get("WPN_ENCH").specAware, true, "and it ranks against the active spec")
end)

-- ---------------------------------------------------------------------------
-- Category metadata vs. the DB defaults
-- ---------------------------------------------------------------------------

test("Defaults: every category has a profile bucket of the right shape", function(t)
    local KCM = h.loader.loadPure()
    local buckets = KCM.db.profile.categories
    for _, row in ipairs(KCM.Categories.LIST) do
        local b = buckets[row.key]
        t.truthy(b, row.key .. " has a profile bucket")
        if row.composite then
            t.truthy(b.enabled, row.key .. " bucket has an enabled map")
            t.truthy(b.orderInCombat, row.key .. " bucket has orderInCombat")
            t.truthy(b.orderOutOfCombat, row.key .. " bucket has orderOutOfCombat")
        elseif row.specAware then
            t.truthy(b.bySpec, row.key .. " bucket is per-spec")
        else
            t.truthy(b.added and b.blocked and b.pins and b.discovered,
                row.key .. " bucket has the four item sub-tables")
        end
    end
end)

test("Defaults: no profile bucket exists for a category that was removed", function(t)
    local KCM = h.loader.loadPure()
    for key in pairs(KCM.db.profile.categories) do
        t.truthy(KCM.Categories.Get(key), "profile bucket '" .. key .. "' still has a category row")
    end
end)

test("Defaults: composite default order matches the category's declared components", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        if row.composite then
            local b = KCM.db.profile.categories[row.key]
            t.eqList(b.orderInCombat, row.components.inCombat,
                row.key .. " default in-combat order matches components")
            t.eqList(b.orderOutOfCombat, row.components.outOfCombat,
                row.key .. " default out-of-combat order matches components")
        end
    end
end)

test("Defaults: every composite sub-category ships enabled", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        if row.composite then
            local b = KCM.db.profile.categories[row.key]
            for _, section in ipairs({ "inCombat", "outOfCombat" }) do
                for _, ref in ipairs(row.components[section]) do
                    t.eq(b.enabled[ref], true, row.key .. "." .. ref .. " defaults to enabled")
                end
            end
        end
    end
end)

test("Defaults: the addon ships enabled with an empty user-override state", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.db.profile.enabled, true, "master switch defaults on")
    t.eq(next(KCM.db.profile.statPriority), nil, "no seeded stat-priority overrides — seeds live in KCM.SEED")
    t.eq(next(KCM.db.profile.macroState), nil, "no macro state before the first recompute")
    t.eq(KCM.db.global.schemaVersion, 1, "schema version is account-wide, not per profile")
end)

-- ---------------------------------------------------------------------------
-- Seed item lists
-- ---------------------------------------------------------------------------

test("Defaults: every single-pick category ships a non-empty seed list", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        if not row.composite then
            local seed = KCM.SEED[row.key]
            t.truthy(seed, row.key .. " has a KCM.SEED entry")
            t.truthy(seed and #seed > 0, row.key .. " seed is non-empty")
        end
    end
end)

test("Defaults: no seed list ships a duplicate entry", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs(ITEM_SEED_KEYS) do
        local seen = {}
        for _, id in ipairs(KCM.SEED[key]) do
            t.falsy(seen[id], key .. " entry " .. tostring(id) .. " appears once")
            seen[id] = true
        end
    end
end)

test("Defaults: every seed entry is a non-zero integer ID", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs(ITEM_SEED_KEYS) do
        for _, id in ipairs(KCM.SEED[key]) do
            t.eq(type(id), "number", key .. " entry is numeric")
            t.ne(id, 0, key .. " entry is non-zero (0 is neither item nor spell)")
            t.eq(id, math.floor(id), key .. " entry " .. tostring(id) .. " is an integer")
        end
    end
end)

test("Defaults: every seed entry classifies as either an item or a spell sentinel", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs(ITEM_SEED_KEYS) do
        for _, id in ipairs(KCM.SEED[key]) do
            t.truthy(KCM.ID.IsItem(id) or KCM.ID.IsSpell(id),
                key .. " entry " .. tostring(id) .. " lands on one side of the sign convention")
        end
    end
end)

test("Defaults: no seed list is shared by reference between two categories", function(t)
    local KCM = h.loader.loadPure()
    local seen = {}
    for _, key in ipairs(ITEM_SEED_KEYS) do
        local list = KCM.SEED[key]
        t.falsy(seen[list], key .. " has its own table (a shared one would alias user edits)")
        seen[list] = key
    end
end)

-- An item may legitimately appear in two seeds only when it restores both
-- health and mana (a conjured mana bun is food AND drink; a combined potion is
-- an HP_POT AND an MP_POT). Any other overlap is a paste error — a flask ID
-- landing in the stat-food list, say — which would make one category outrank
-- itself with a consumable it can never use.
local DUAL_PURPOSE_PAIRS = {
    ["DRINK|FOOD"]     = true,
    ["HP_POT|MP_POT"]  = true,
}

test("Defaults: a seeded itemID is shared only across a health/mana sibling pair", function(t)
    local KCM = h.loader.loadPure()
    local owner = {}
    for _, key in ipairs(ITEM_SEED_KEYS) do
        for _, id in ipairs(KCM.SEED[key]) do
            if KCM.ID.IsItem(id) then
                local prev = owner[id]
                if prev then
                    local a, b = prev, key
                    if a > b then a, b = b, a end
                    t.truthy(DUAL_PURPOSE_PAIRS[a .. "|" .. b],
                        "item " .. tostring(id) .. " shared between " .. a .. " and " .. b
                            .. " is a recognised dual-purpose pairing")
                end
                owner[id] = key
            end
        end
    end
end)

test("Defaults: the FOOD seed carries the conjured-food spell as a sentinel", function(t)
    local KCM = h.loader.loadPure()
    local spells = 0
    for _, id in ipairs(KCM.SEED.FOOD) do
        if KCM.ID.IsSpell(id) then
            spells = spells + 1
            t.truthy(KCM.ID.SpellID(id) > 0, "sentinel " .. id .. " recovers a positive spellID")
        end
    end
    t.truthy(spells >= 1, "at least one spell entry (Recuperate) rides alongside the items")
end)

test("Defaults: the Healthstone seed is item-only", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(#KCM.SEED.HS >= 1, "healthstones are seeded")
    for _, id in ipairs(KCM.SEED.HS) do
        t.truthy(KCM.ID.IsItem(id), id .. " is an item — the stone is used, not cast")
    end
end)

test("Defaults: every reusable augment rune the Classifier knows is in the seed", function(t)
    local KCM = h.loader.loadPure()
    -- Mirrors REUSABLE_AUG_IDS in core/Classifier.lua, which the seed file's
    -- header promises to keep in sync.
    local reusable = { 243191, 211495, 190384, 174906, 153023 }
    local seeded = {}
    for _, id in ipairs(KCM.SEED.AUG_RUNE) do seeded[id] = true end
    for _, id in ipairs(reusable) do
        t.truthy(KCM.Classifier.IsReusableAugRune(id), id .. " is flagged reusable by the Classifier")
        t.truthy(seeded[id], id .. " is present in the AUG_RUNE seed")
    end
end)

test("Defaults: a consumed augment rune is not flagged reusable", function(t)
    local KCM = h.loader.loadPure()
    t.falsy(KCM.Classifier.IsReusableAugRune(259085), "Void-Touched (Midnight) is consumed on use")
    t.falsy(KCM.Classifier.IsReusableAugRune(140587), "Defiled (Legion) is consumed on use")
end)

-- ---------------------------------------------------------------------------
-- Stat priority seeds
-- ---------------------------------------------------------------------------

test("Defaults: every stat-priority key is a well-formed classID_specID pair", function(t)
    local KCM = h.loader.loadPure()
    for key in pairs(KCM.SEED.STAT_PRIORITY) do
        local classID, specID = key:match("^(%d+)_(%d+)$")
        t.truthy(classID, "'" .. key .. "' is <classID>_<specID>")
        if classID then
            t.eq(KCM.SpecHelper.MakeKey(tonumber(classID), tonumber(specID)), key,
                "'" .. key .. "' round-trips through SpecHelper.MakeKey")
        end
    end
end)

test("Defaults: stat priority covers all thirteen classes", function(t)
    local KCM = h.loader.loadPure()
    local byClass = {}
    for key in pairs(KCM.SEED.STAT_PRIORITY) do
        byClass[tonumber(key:match("^(%d+)_"))] = true
    end
    for classID = 1, 13 do
        t.truthy(byClass[classID], "classID " .. classID .. " has at least one seeded spec")
    end
end)

test("Defaults: every seeded spec names a primary stat the Ranker weights", function(t)
    local KCM = h.loader.loadPure()
    for key, row in pairs(KCM.SEED.STAT_PRIORITY) do
        t.truthy(VALID_PRIMARY[row.primary],
            key .. " primary '" .. tostring(row.primary) .. "' is STR/AGI/INT")
    end
end)

test("Defaults: every seeded secondary list is ordered, valid, and duplicate-free", function(t)
    local KCM = h.loader.loadPure()
    for key, row in pairs(KCM.SEED.STAT_PRIORITY) do
        t.truthy(row.secondary, key .. " has a secondary list")
        local seen = {}
        for _, stat in ipairs(row.secondary or {}) do
            t.truthy(VALID_SECONDARY[stat], key .. " secondary '" .. tostring(stat) .. "' is a real stat")
            t.falsy(seen[stat], key .. " lists '" .. tostring(stat) .. "' once")
            seen[stat] = true
        end
    end
end)

test("Defaults: a seeded spec resolves through SpecHelper without falling back", function(t)
    local KCM = h.loader.loadPure()
    for key, row in pairs(KCM.SEED.STAT_PRIORITY) do
        local resolved = KCM.SpecHelper.GetStatPriority(key)
        t.eq(resolved.primary, row.primary, key .. " resolves to its seeded primary")
        t.eqList(resolved.secondary, row.secondary, key .. " resolves to its seeded secondary order")
    end
end)
