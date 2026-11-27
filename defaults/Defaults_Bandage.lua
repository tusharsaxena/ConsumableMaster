-- defaults/Defaults_Bandage.lua — Seed list for KCM_BANDAGE (WoW Forever only).
--
-- First Aid bandages, consumable subclass 7 (core/Classifier.lua matches the
-- subclass alone), ranked by the heal. One bandage per ~10-level band, the
-- top tier of each by item level; auto-discovery takes the Heavy variants
-- and every other tier from the bags.
--
-- Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied),
-- the owner's Auctionator and /cm probe seed stores (issue #46).
-- Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139
-- (tools/seeds/seeds.py, docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.BANDAGE = KCM.PerClient({
    -- The category is WoW Forever's alone (defaults/Categories.lua, clients-§4).
    retail = {},
    forever = {
        2581,  -- Heavy Linen Bandage; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        3531,  -- Heavy Wool Bandage; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        6451,  -- Heavy Silk Bandage; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        8545,  -- Heavy Mageweave Bandage; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, DB2 (crafted)
        14530,  -- Heavy Runecloth Bandage; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (vendor), AH, DB2 (crafted)
    },
})
