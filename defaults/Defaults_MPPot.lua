-- defaults/Defaults_MPPot.lua — Seed list for KCM_MP_POT.
--
-- Direct mana-restore potions (subType = "Potions", restores mana, no stat
-- buff). Refreshing Serum (241306) also restores HP and appears in both
-- KCM.SEED.HP_POT and KCM.SEED.MP_POT.
--
-- Source: Method.gg Midnight consumables list + Wowhead item database.
-- Last refresh: 2026-04-22. See defaults/README.md to re-run.
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.MP_POT = KCM.PerClient({
    retail = {
        241300,  -- Lightfused Mana Potion (Midnight)
        241294,  -- Potion of Devoured Dreams
        241306,  -- Refreshing Serum (also restores health)
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        2455,  -- Minor Mana Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, quest, vendor), AH, probe (ah), DB2 (crafted)
        3385,  -- Lesser Mana Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah), DB2 (crafted)
        3827,  -- Mana Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah), DB2 (crafted)
        9144,  -- Wildvine Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, recipe), AH, probe (ah), DB2 (crafted)
        13444,  -- Major Mana Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, quest, recipe, vendor), AH, DB2 (crafted)
        18253,  -- Major Rejuvenation Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, DB2 (crafted)
    },
})
