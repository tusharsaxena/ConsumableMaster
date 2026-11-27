-- defaults/Defaults_Elixir.lua — Seed list for KCM_ELIXIR (WoW Forever only).
--
-- Vanilla elixirs, consumable subclass 2 (core/Classifier.lua matches the
-- subclass alone). Spec-aware: the Ranker weights each elixir's stat against
-- the active spec's stat priority. One elixir per stat per ~10-level band, the
-- top tier of each by item level; utility elixirs (water breathing, detect
-- undead or demons, giant growth) are left out, as Defaults_CombatPot.lua
-- leaves utility potions out. Auto-discovery takes every other elixir.
--
-- Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied),
-- the owner's Auctionator and /cm probe seed stores (issue #46).
-- Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139
-- (tools/seeds/seeds.py, docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.ELIXIR = KCM.PerClient({
    -- The category is WoW Forever's alone (defaults/Categories.lua, clients-§4).
    retail = {},
    forever = {
        2457,  -- Elixir of Minor Agility; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        2458,  -- Elixir of Minor Fortitude; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest), AH, probe (ah), DB2 (crafted)
        3382,  -- Minor Troll's Blood Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest), AH, probe (ah), DB2 (crafted)
        3383,  -- Elixir of Wisdom; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        3388,  -- Lesser Troll's Blood Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        3389,  -- Elixir of Lesser Defense; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        3390,  -- Elixir of Lesser Agility; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        3391,  -- Elixir of Ogre Strength; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        3825,  -- Elixir of Lesser Fortitude; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        3826,  -- Troll's Blood Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        5997,  -- Elixir of Minor Defense; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        6373,  -- Elixir of Fire Power; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        6662,  -- Elixir of Giant Growth; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        8949,  -- Elixir of Agility; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        8951,  -- Elixir of Defense; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container), AH, probe (ah), DB2 (crafted)
        9088,  -- Gift of Arthas; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        9155,  -- Arcane Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop), AH, probe (ah), DB2 (crafted)
        9179,  -- Elixir of Greater Intellect; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop), AH, probe (ah), DB2 (crafted)
        9187,  -- Elixir of Greater Agility; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop), AH, probe (ah), DB2 (crafted)
        9264,  -- Elixir of Shadow Power; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
        12820,  -- Winterfall Firewater; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop), AH
        13445,  -- Elixir of Greater Defense; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13452,  -- Elixir of the Mongoose; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, quest, recipe), AH, DB2 (crafted)
        13453,  -- Elixir of Brute Force; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13454,  -- Greater Arcane Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
        21546,  -- Elixir of Holy Power; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        247754,  -- Minor Arcane Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        247755,  -- Elixir of Minor Force; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        250328,  -- Elixir of Cunning; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250329,  -- Elixir of the Phalanx; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250330,  -- Minor Cleric's Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250331,  -- Lesser Cleric's Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250332,  -- Cleric's Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250333,  -- Greater Cleric's Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250334,  -- Elixir of Fortitude; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250337,  -- Elixir of the Owl; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250338,  -- Elixir of Sages; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250339,  -- Minor Mageblood Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        250340,  -- Lesser Mageblood Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250341,  -- Greater Mageblood Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250342,  -- Lesser Arcane Elixir; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250343,  -- Elixir of Nature Power; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250344,  -- Elixir of Minor Spirit; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted)
        250345,  -- Elixir of Lesser Spirit; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250346,  -- Elixir of Spirit; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250351,  -- Elixir of the Grizzly; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250353,  -- Elixir of Lesser Intellect; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250354,  -- Elixir of Intellect; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
    },
})
