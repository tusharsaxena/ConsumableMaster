-- defaults/Defaults_Drink.lua — Seed list for KCM_DRINK (mana-recovery
-- drink, no stat buff).
--
-- Midnight cooking produces five tea drinks (Argentleaf, Azeroot, Mana
-- Lily, Sanguithorn, Tranquility Bloom). They may grant profession-stat
-- buffs rather than pure mana regen — auto-discovery sorts them out by
-- tooltip content. Conjured Refreshment (mage) auto-discovers from bags
-- at runtime. The seed below is the Silvermoon innkeeper's drink stock so
-- the macro is usable before the first bag scan.
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

KCM.SEED.DRINK = KCM.PerClient({
    retail = {
        113509,  -- Conjured Mana Bun (mage conjured food) — top by default via the
                 -- Ranker's conjured-bonus layer; user can demote / remove.
        260261,  -- Bloom Nectar
        260260,  -- Springrunner Sparkling
        260259,  -- Everspring Water
        260258,  -- Purified Cordial
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        1179,  -- Ice Cold Milk; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor)
        1205,  -- Melon Juice; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor)
        1645,  -- Moonberry Juice; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah, vendor)
        1708,  -- Sweet Nectar; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah, vendor)
        8079,  -- Conjured Crystal Water; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (vendor), DB2 (crafted)
        13724,  -- Enriched Manna Biscuit; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (drop, vendor), AH
    },
})
