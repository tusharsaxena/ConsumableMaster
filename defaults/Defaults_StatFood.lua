-- defaults/Defaults_StatFood.lua — Seed list for KCM_STAT_FOOD.
--
-- Midnight cooked stat meals. Stat-per-spec is resolved by Ranker via
-- Defaults_StatPriority + parsed tooltip stat buffs. Feasts (single-serve
-- and raid-wide) are deliberately NOT seeded here — they're classified
-- out of STAT_FOOD via TooltipCache `isFeast` detection.
--
-- "Hearty" variants (tier 35+ of the same recipe) share the subType and
-- stat profile; they're auto-discovered from bags and sorted by the
-- Ranker. We only seed the base-tier IDs for a clean default priority.
--
-- Source: Method.gg Midnight consumables list + Warcraft Wiki cooking
-- recipes, 2026-04-22. See defaults/README.md to re-run.
-- Validated: 2026-11-15 against Retail 12.1.5.70783 on wago.tools (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-15-retail/, issue #49).
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.STAT_FOOD = KCM.PerClient({
    retail = {
        -- Master tier (primary stat, highest amount)
        242275,  -- Royal Roast                    (primary stat)
        255847,  -- Impossibly Royal Roast         (primary stat, top tier)

        -- Intermediate / Advanced single-stat
        242283,  -- Sun-Seared Lumifin             (CRIT)
        242286,  -- Fel-Kissed Filet               (HASTE)
        242278,  -- Tasty Smoked Tetra             (CRIT)
        242277,  -- Crimson Calamari               (HASTE)
        242282,  -- Null and Void Plate            (HASTE)
        242281,  -- Glitter Skewers                (MASTERY)
        242285,  -- Warped Wise Wings              (MASTERY)
        242284,  -- Void-Kissed Fish Rolls         (VERSATILITY)
        242280,  -- Buttered Root Crab             (VERSATILITY)
        242276,  -- Braised Blood Hunter           (VERSATILITY)
        242294,  -- Felberry Figs                  (VERSATILITY)

        -- Primary-stat starter/intermediate
        242288,  -- Twilight Angler's Medley       (primary stat)
        242289,  -- Spellfire Filet                (primary stat)
        242302,  -- Bloom Skewers                  (primary stat)
        242303,  -- Mana-Infused Stew              (primary stat)

        -- Dual-stat combined (Intermediate tier)
        242290,  -- Wise Tails                     (CRIT + VERS)
        242291,  -- Fried Bloomtail                (MASTERY + VERS)
        242292,  -- Eversong Pudding               (MASTERY + CRIT)
        242293,  -- Sunwell Delight                (VERS + HASTE)
        242295,  -- Hearthflame Supper             (CRIT + HASTE)
        242296,  -- Bloodthistle-Wrapped Cutlets   (MASTERY + HASTE)

        -- Dual-stat Starter tier (smaller amount)
        242304,  -- Spiced Biscuits                (CRIT + VERS)
        242305,  -- Silvermoon Standard            (MASTERY + VERS)
        242306,  -- Forager's Medley               (MASTERY + CRIT)
        242307,  -- Quick Sandwich                 (VERS + HASTE)
        242308,  -- Portable Snack                 (CRIT + HASTE)
        242309,  -- Farstrider Rations             (MASTERY + HASTE)
        242287,  -- Arcano Cutlets; added from the 2026-11-15 wago.tools validation (12.1.5.70783)
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        724,  -- Goretusk Liver Pie; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        1017,  -- Seasoned Wolf Kabob; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (object, quest, recipe), AH, probe (ah), DB2 (crafted)
        1082,  -- Redridge Goulash; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        2684,  -- Coyote Steak; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        2685,  -- Succulent Pork Ribs; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        3665,  -- Curiously Tasty Omelet; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        3728,  -- Tasty Lion Steak; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        4457,  -- Barbecued Buzzard Wing; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        4592,  -- Longjaw Mud Snapper; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted)
        5095,  -- Rainbow Fin Albacore; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        5479,  -- Crispy Lizard Tail; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        6038,  -- Giant Clam Scorcho; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        8364,  -- Mithril Head Trout; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, object, recipe), AH, probe (ah), DB2 (crafted)
        12210,  -- Roast Raptor; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        12212,  -- Jungle Stew; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        12218,  -- Monster Omelet; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13928,  -- Grilled Squid; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13932,  -- Poached Sunscale Salmon; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13933,  -- Lobster Stew; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13934,  -- Mightfish Steak; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        18254,  -- Runn Tum Tuber Surprise; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        20452,  -- Smoked Desert Dumplings; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, DB2 (crafted)
        21072,  -- Smoked Sagefish; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        21217,  -- Sagefish Delight; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        249866,  -- Royal Tea; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249867,  -- Root Tea; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        249868,  -- Triage Tea; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249869,  -- Sunny Tea; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249870,  -- Sage's Tea; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249872,  -- Slimy Smoothie; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249873,  -- Mrrggl Smrrthle; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        249874,  -- Calcified Smoothie; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249875,  -- Spicy Smoothie; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        249876,  -- Wicked Smoothie; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250065,  -- Savory Stag Sliders; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250067,  -- Bat Hachee; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250068,  -- Savory Turtle Stew; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250069,  -- Flank au Poivre; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250074,  -- Bear Brisket; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        274971,  -- Briny Seafood Stew; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        286152,  -- Plated Armorfish; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
    },
})
