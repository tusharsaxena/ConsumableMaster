-- defaults/Categories.lua — Category metadata. Each row describes one managed macro.
--
-- Fields (single-category):
--   key         : internal identifier, matches AceDB profile.categories[key]
--   macroName   : global macro name (<=16 chars, GetMacroIndexByName lookup)
--   displayName : human-readable label for settings UI
--   specAware   : if true, priority list is per-spec (uses bySpec sub-table)
--   rankerKey   : hint for Ranker module (Milestone 4)
--   classifier  : hint for Classifier module (Milestone 4)
--   emptyText   : fallback macro body when category has no resolvable items
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
-- there is no inline chat-tag literal here (standard section 7.4).
local function emptyMacro(msg)
    return ("/run print('%s %s')"):format(KCM.PREFIX, msg)
end

KCM.Categories.LIST = {
    {
        key         = "FOOD",
        macroName   = "KCM_FOOD",
        displayName = "Food",
        specAware   = false,
        rankerKey   = "FOOD_BASIC",
        classifier  = "FOOD_BASIC",
        emptyText   = emptyMacro("no food in bags"),
    },
    {
        key         = "DRINK",
        macroName   = "KCM_DRINK",
        displayName = "Drink",
        specAware   = false,
        rankerKey   = "DRINK",
        classifier  = "DRINK",
        emptyText   = emptyMacro("no drink in bags"),
    },
    {
        key         = "HP_POT",
        macroName   = "KCM_HP_POT",
        displayName = "Healing Potion",
        specAware   = false,
        rankerKey   = "HP_POT",
        classifier  = "HP_POT",
        emptyText   = emptyMacro("no healing potion in bags"),
    },
    {
        key         = "MP_POT",
        macroName   = "KCM_MP_POT",
        displayName = "Mana Potion",
        specAware   = false,
        rankerKey   = "MP_POT",
        classifier  = "MP_POT",
        emptyText   = emptyMacro("no mana potion in bags"),
    },
    {
        key         = "HS",
        macroName   = "KCM_HS",
        displayName = "Healthstone",
        specAware   = false,
        rankerKey   = "HS",
        classifier  = "HS",
        emptyText   = emptyMacro("no healthstone in bags"),
    },
    {
        key         = "VANTUS",
        macroName   = "KCM_VANTUS",
        displayName = "Vantus Rune",
        specAware   = false,
        rankerKey   = "VANTUS",
        classifier  = "VANTUS",
        emptyText   = emptyMacro("no vantus rune in bags"),
    },
    {
        key         = "FLASK",
        macroName   = "KCM_FLASK",
        displayName = "Flask",
        specAware   = true,
        rankerKey   = "FLASK",
        classifier  = "FLASK",
        emptyText   = emptyMacro("no flask for this spec"),
    },
    {
        key         = "CMBT_POT",
        macroName   = "KCM_CMBT_POT",
        displayName = "Combat Potion",
        specAware   = true,
        rankerKey   = "CMBT_POT",
        classifier  = "CMBT_POT",
        emptyText   = emptyMacro("no combat potion for this spec"),
    },
    {
        key         = "STAT_FOOD",
        macroName   = "KCM_STAT_FOOD",
        displayName = "Stat Food",
        specAware   = true,
        rankerKey   = "STAT_FOOD",
        classifier  = "STAT_FOOD",
        emptyText   = emptyMacro("no stat food for this spec"),
    },
    {
        key         = "WPN_ENCH",
        macroName   = "KCM_WPN_ENCH",
        displayName = "Weapon Enchant",
        specAware   = true,
        perHand     = true,
        rankerKey   = "WPN_ENCH",
        classifier  = "WPN_ENCH",
        emptyText   = emptyMacro("no weapon enchant for this spec"),
    },
    {
        key         = "HP_AIO",
        macroName   = "KCM_HP_AIO",
        displayName = "AIO Health",
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
        composite   = true,
        components  = {
            inCombat    = { "MP_POT" },
            outOfCombat = { "DRINK" },
        },
        emptyText   = emptyMacro("no AIO mana option available"),
    },
}

KCM.Categories.BY_KEY = {}
for _, row in ipairs(KCM.Categories.LIST) do
    KCM.Categories.BY_KEY[row.key] = row
end

function KCM.Categories.Get(key)
    return KCM.Categories.BY_KEY[key]
end

function KCM.Categories.All()
    return KCM.Categories.LIST
end
