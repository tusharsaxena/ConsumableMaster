-- defaults/Defaults_Healthstone.lua — Seed list for KCM_HS.
--
-- Warlock Healthstones. The modern ranked healthstone (224464) auto-upgrades
-- with warlock level; 5512 is the classic evergreen id kept as a safety net.
-- Source: Wowhead, 2026-04.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.HS = KCM.PerClient({
    retail = {
        224464,  -- Healthstone (modern Dragonflight+)
        5512,    -- Healthstone (legacy; compatibility fallback)
    },
    -- Empty by decision: step 2, owner ruling 2026-11-08. No Retail ID is a Forever candidate;
    -- on WoW Forever every candidate comes from the bag scan. core/Classifier.lua's HS whitelist
    -- still names 5512, vanilla's Minor Healthstone, so that one is discovered; the other
    -- vanilla ranks wait for step 2.
    forever = {},
})
