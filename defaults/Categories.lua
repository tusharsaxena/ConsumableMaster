-- defaults/Categories.lua — Category metadata. Each row describes one managed macro.
--
-- Fields (single-category):
--   key         : internal identifier, matches AceDB profile.categories[key]
--   macroName   : global macro name (<=16 chars, GetMacroIndexByName lookup)
--   displayName : human-readable label for settings UI
--   shortName   : abbreviated label for tight spaces (macro-bar button labels).
--                 Falls back to displayName when omitted.
--   specAware   : if true, priority list is per-spec (uses bySpec sub-table)
--   rankerKey   : hint for Ranker module (Milestone 4)
--   classifier  : hint for Classifier module (Milestone 4)
--   emptyText   : fallback macro body when category has no resolvable items
--   clients     : the game clients the category exists on (clients-§4):
--                 { "retail" } or { "forever" }; omitted, it serves both.
--                 A row the running client is not in is DROPPED from LIST
--                 and BY_KEY below, once, at load, so it has no macro, no
--                 settings tab, no macro-bar slot, no slash name and no
--                 profile bucket on that client. It is never registered and
--                 then hidden.
--
-- Fields (composite — composite=true):
--   composite   : true marks this row as an aggregator; the pipeline routes
--                 it through MacroManager.SetCompositeMacro instead of the
--                 single-pick path.
--   components  : { inCombat = { catKey, ... }, outOfCombat = { catKey, ... } }
--                 The default sub-categories assigned to each combat-state
--                 section; user toggles + reorder live in
--                 db.profile.categories[<key>].enabled / orderInCombat /
--                 orderOutOfCombat. Sub-categories are locked to their
--                 section.
--
-- Fields (per-hand — perHand=true):
--   perHand     : true routes the pipeline through Selector.PickBestForSlot
--                 (main hand = 16, off hand = 17) and
--                 MacroManager.SetWeaponEnchantMacro instead of the
--                 single-pick path, so each hand gets an affinity-matched
--                 weapon enchant.

local _, NS = ...
local KCM = NS
KCM.Categories = KCM.Categories or {}

-- Build a category's empty-state macro body from the shared KCM.PREFIX so
-- there is no inline chat-tag literal here (slash-commands-§4).
local function emptyMacro(msg)
    return ("/run print('%s %s')"):format(KCM.PREFIX, msg)
end

KCM.Categories.LIST = {
    {
        key         = "FOOD",
        macroName   = "KCM_FOOD",
        displayName = "Food",
        shortName   = "Food",
        specAware   = false,
        rankerKey   = "FOOD_BASIC",
        classifier  = "FOOD_BASIC",
        emptyText   = emptyMacro("no food in bags"),
    },
    {
        key         = "DRINK",
        macroName   = "KCM_DRINK",
        displayName = "Drink",
        shortName   = "Drink",
        specAware   = false,
        rankerKey   = "DRINK",
        classifier  = "DRINK",
        emptyText   = emptyMacro("no drink in bags"),
    },
    {
        key         = "HP_POT",
        macroName   = "KCM_HP_POT",
        displayName = "Healing Potion",
        shortName   = "HP Pot",
        specAware   = false,
        rankerKey   = "HP_POT",
        classifier  = "HP_POT",
        emptyText   = emptyMacro("no healing potion in bags"),
    },
    {
        key         = "MP_POT",
        macroName   = "KCM_MP_POT",
        displayName = "Mana Potion",
        shortName   = "MP Pot",
        specAware   = false,
        rankerKey   = "MP_POT",
        classifier  = "MP_POT",
        emptyText   = emptyMacro("no mana potion in bags"),
    },
    {
        key         = "HS",
        macroName   = "KCM_HS",
        displayName = "Healthstone",
        shortName   = "Stone",
        specAware   = false,
        rankerKey   = "HS",
        classifier  = "HS",
        emptyText   = emptyMacro("no healthstone in bags"),
    },
    -- WoW Forever only (owner ruling 2026-11-08): vanilla's first-aid bandages,
    -- consumable subclass 7, ranked by the heal.
    {
        key         = "BANDAGE",
        clients     = { "forever" },
        macroName   = "KCM_BANDAGE",
        displayName = "Bandage",
        shortName   = "Bandage",
        specAware   = false,
        rankerKey   = "BANDAGE",
        classifier  = "BANDAGE",
        emptyText   = emptyMacro("no bandage in bags"),
    },
    {
        key         = "VANTUS",
        clients     = { "retail" },
        macroName   = "KCM_VANTUS",
        displayName = "Vantus Rune",
        shortName   = "Vantus",
        specAware   = false,
        rankerKey   = "VANTUS",
        classifier  = "VANTUS",
        emptyText   = emptyMacro("no vantus rune in bags"),
    },
    {
        key         = "FLASK",
        macroName   = "KCM_FLASK",
        displayName = "Flask",
        shortName   = "Flask",
        specAware   = true,
        rankerKey   = "FLASK",
        classifier  = "FLASK",
        emptyText   = emptyMacro("no flask for this spec"),
    },
    -- WoW Forever only: vanilla's elixirs, consumable subclass 2. Spec-aware
    -- like FLASK and ranked by the same stat-priority model.
    {
        key         = "ELIXIR",
        clients     = { "forever" },
        macroName   = "KCM_ELIXIR",
        displayName = "Elixir",
        shortName   = "Elixir",
        specAware   = true,
        rankerKey   = "ELIXIR",
        classifier  = "ELIXIR",
        emptyText   = emptyMacro("no elixir for this spec"),
    },
    {
        key         = "CMBT_POT",
        macroName   = "KCM_CMBT_POT",
        displayName = "Combat Potion",
        shortName   = "Combat",
        specAware   = true,
        rankerKey   = "CMBT_POT",
        classifier  = "CMBT_POT",
        emptyText   = emptyMacro("no combat potion for this spec"),
    },
    -- WoW Forever only: a potion that absorbs one magic school's damage
    -- ("Absorbs 1950 to 3250 fire damage."), ranked by the absorb amount.
    -- CMBT_POT never takes one.
    {
        key         = "PROT_POT",
        clients     = { "forever" },
        macroName   = "KCM_PROT_POT",
        displayName = "Protection Potion",
        shortName   = "Prot",
        specAware   = false,
        rankerKey   = "PROT_POT",
        classifier  = "PROT_POT",
        emptyText   = emptyMacro("no protection potion in bags"),
    },
    {
        key         = "STAT_FOOD",
        macroName   = "KCM_STAT_FOOD",
        displayName = "Stat Food",
        shortName   = "Stat",
        specAware   = true,
        rankerKey   = "STAT_FOOD",
        classifier  = "STAT_FOOD",
        emptyText   = emptyMacro("no stat food for this spec"),
    },
    -- WoW Forever only: vanilla's scrolls, consumable subclass 4. Spec-aware and
    -- ranked like ELIXIR; a scroll with no stat (Protection) ranks after the
    -- stat scrolls, by its value.
    {
        key         = "SCROLL",
        clients     = { "forever" },
        macroName   = "KCM_SCROLL",
        displayName = "Scroll",
        shortName   = "Scroll",
        specAware   = true,
        rankerKey   = "SCROLL",
        classifier  = "SCROLL",
        emptyText   = emptyMacro("no scroll for this spec"),
    },
    {
        key         = "WPN_ENCH",
        macroName   = "KCM_WPN_ENCH",
        displayName = "Weapon Enchant",
        shortName   = "Weapon",
        specAware   = true,
        perHand     = true,
        rankerKey   = "WPN_ENCH",
        classifier  = "WPN_ENCH",
        emptyText   = emptyMacro("no weapon enchant for this spec"),
    },
    {
        key         = "AUG_RUNE",
        clients     = { "retail" },
        macroName   = "KCM_AUG_RUNE",
        displayName = "Augment Rune",
        shortName   = "Rune",
        specAware   = false,
        rankerKey   = "AUG_RUNE",
        classifier  = "AUG_RUNE",
        emptyText   = emptyMacro("no augment rune in bags"),
    },
    {
        key         = "BLOODLUST",
        clients     = { "retail" },
        macroName   = "KCM_BLOODLUST",
        displayName = "Bloodlust",
        shortName   = "Lust",
        specAware   = false,
        rankerKey   = "BLOODLUST",
        emptyText   = emptyMacro("no bloodlust available"),
    },
    {
        key         = "BATTLE_REZ",
        clients     = { "retail" },
        macroName   = "KCM_BATTLE_REZ",
        displayName = "Battle Rez",
        shortName   = "Brez",
        specAware   = false,
        rankerKey   = "BATTLE_REZ",
        -- Acts on someone else, unlike every other category. `help` without
        -- `dead` so the one clause also serves Soulstone, which is cast on a
        -- LIVING ally. MacroManager reads db.profile…BATTLE_REZ.mouseover to
        -- let the user turn it off.
        targeted    = "[@mouseover,help][@target,help]",
        emptyText   = emptyMacro("no battle rez available"),
    },
    {
        key         = "HP_AIO",
        macroName   = "KCM_HP_AIO",
        displayName = "AIO Health",
        shortName   = "AIO HP",
        composite   = true,
        components  = {
            inCombat    = { "HS", "HP_POT" },
            outOfCombat = { "FOOD" },
        },
        emptyText   = emptyMacro("no AIO health option available"),
    },
    {
        key         = "MP_AIO",
        macroName   = "KCM_MP_AIO",
        displayName = "AIO Mana",
        shortName   = "AIO MP",
        composite   = true,
        components  = {
            inCombat    = { "MP_POT" },
            outOfCombat = { "DRINK" },
        },
        emptyText   = emptyMacro("no AIO mana option available"),
    },
}

-- The client gate (clients-§4), applied ONCE, here, at load: LIST and BY_KEY
-- hold only the rows the running client is declared for. Every reader -- the
-- pipeline, the macro manager, the settings tabs, the macro bar, the slash and
-- dump verbs, the profile defaults (defaults/Profile.lua builds its buckets
-- from BY_KEY) -- sees this client's set and nothing else. ALL keeps every row
-- for the docs and the tests; no feature code reads it.
KCM.Categories.ALL = KCM.Categories.LIST
do
    -- core/Compat.lua loads in the # Core block, long before this file.
    local admit = KCM.Compat.ForClient
    local list = {}
    for _, row in ipairs(KCM.Categories.ALL) do
        if admit(row.clients) then list[#list + 1] = row end
    end
    KCM.Categories.LIST = list
end

KCM.Categories.BY_KEY = {}
for _, row in ipairs(KCM.Categories.LIST) do
    KCM.Categories.BY_KEY[row.key] = row
end

function KCM.Categories.Get(key)
    return KCM.Categories.BY_KEY[key]
end
