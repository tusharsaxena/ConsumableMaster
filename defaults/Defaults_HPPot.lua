-- defaults/Defaults_HPPot.lua — Seed list for KCM_HP_POT.
--
-- Direct-heal potions (subType = "Potions", restores flat HP, no stat buff).
-- Refreshing Serum (241306) restores both HP and mana, so it appears in both
-- KCM.SEED.HP_POT and KCM.SEED.MP_POT; the Classifier matches it for both.
-- Shield / absorb potions (e.g. Light's Preservation) are classified outside
-- HP_POT and are not eligible here.
--
-- Source: Method.gg Midnight consumables list + Wowhead item database,
-- cross-checked via in-game /cm dump item on a level-90 character.
-- Last refresh: 2026-04-22. See defaults/README.md to re-run.
-- Validated: 2026-11-15 against Retail 12.1.5.70783 on wago.tools (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-15-retail/, issue #49).
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.HP_POT = KCM.PerClient({
    retail = {
        241304,  -- Silvermoon Health Potion (Midnight)
        241298,  -- Amani Extract
        241306,  -- Refreshing Serum (also restores mana)
        271884,  -- Concentrated Silvermoon Health Potion; added from the 2026-11-15 wago.tools validation (12.1.5.70783)
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        929,  -- Healing Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, quest, vendor), AH, probe (ah), DB2 (crafted)
        1710,  -- Greater Healing Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted)
        2456,  -- Minor Rejuvenation Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest), AH, probe (ah), DB2 (crafted)
        3928,  -- Superior Healing Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, quest, recipe, vendor), AH, probe (ah), DB2 (crafted)
        13446,  -- Major Healing Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, quest, recipe, vendor), AH, DB2 (crafted)
        18253,  -- Major Rejuvenation Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest, recipe), AH, DB2 (crafted)
    },
})
