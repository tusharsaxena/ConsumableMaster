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
    -- Empty by decision: step 2, owner ruling 2026-11-08. No Retail ID is a Forever candidate;
    -- on WoW Forever every candidate comes from the bag scan.
    forever = {},
})
