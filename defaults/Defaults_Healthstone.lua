-- defaults/Defaults_Healthstone.lua — Seed list for KCM_HS.
--
-- Warlock Healthstones. On Retail the modern ranked healthstone (224464)
-- auto-upgrades with warlock level; 5512 is the classic evergreen id kept as
-- a safety net. On WoW Forever every vanilla rank is seeded (below).
-- Source: Wowhead, 2026-04.
-- Validated: 2026-11-15 against Retail 12.1.5.70783 on wago.tools (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-15-retail/, issue #49).
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.HS = KCM.PerClient({
    retail = {
        224464,  -- Demonic Healthstone (modern Dragonflight+)
        5512,    -- Healthstone (legacy; compatibility fallback)
    },
    -- WoW Forever: every vanilla rank, Minor to Major, with its two Improved Healthstone variants
    -- (issue #46; the owner lifted the 2026-11-08 "empty by decision" ruling on 2026-11-27). HS
    -- matches on core/Classifier.lua's HEALTHSTONE_IDS alone, so its Forever block carries the same
    -- ranks; a warlock conjures them, which DB2's create-item effect records (Evidence: DB2).
    forever = {
        5509,  -- Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        5510,  -- Greater Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        5511,  -- Lesser Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        5512,  -- Minor Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        9421,  -- Major Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19004,  -- Minor Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19005,  -- Minor Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19006,  -- Lesser Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19007,  -- Lesser Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19008,  -- Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19009,  -- Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19010,  -- Greater Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19011,  -- Greater Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19012,  -- Major Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
        19013,  -- Major Healthstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: DB2 (crafted)
    },
})
