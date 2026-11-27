-- defaults/Defaults_Food.lua — Seed list for KCM_FOOD (basic "Well Fed" food,
-- no stat buff).
--
-- Midnight cooking does not produce basic (non-stat) food — every crafted
-- dish grants a stat buff and is classified as STAT_FOOD. Basic food in
-- Midnight comes from the Silvermoon innkeeper; the IDs below are that
-- vendor's stock so the macro is usable before the first bag scan.
-- Auto-discovery still picks up anything else the player carries.
--
-- Spell entries (KCM.ID.AsSpell) live alongside items in the seed. Ranker
-- assigns them a huge baseline score so they rank above items by default;
-- the user can demote or remove them via the Options panel exactly like
-- any other row.
--
-- Source: in-game Silvermoon innkeeper vendor stock (Midnight 12.0).
-- Last refresh: 2026-04-23. See defaults/README.md to re-run.
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.FOOD = KCM.PerClient({
    retail = {
        KCM.ID.AsSpell(1231411),  -- Recuperate (spell) — always preferred for Food
        113509,  -- Conjured Mana Bun (mage conjured food)
        260264,  -- Quel'Danas Rations
        260263,  -- Silvermoon Soiree Spread
        260262,  -- Fairbreeze Feast
        260257,  -- Ghostlands Pepper
        260256,  -- Luxurious Omelette
        260255,  -- Managi Roll
        260254,  -- Kale'thas Sunsalad
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        414,  -- Dalaran Sharp; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, object, quest, vendor), AH, probe (ah)
        422,  -- Dwarven Mild; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, quest, vendor), AH, probe (ah)
        1707,  -- Stormwind Brie; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        3927,  -- Fine Aged Cheddar; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        13724,  -- Enriched Manna Biscuit; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, vendor), AH
        22895,  -- Conjured Cinnamon Roll; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (vendor), DB2 (crafted)
    },
})
