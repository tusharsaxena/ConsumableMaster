-- defaults/Defaults_ProtPot.lua — Seed list for KCM_PROT_POT (WoW Forever only).
--
-- Protection potions: a potion or draught (subclass 1 or 13) that absorbs one
-- magic school's damage, ranked by the absorb. One potion per school per
-- ~10-level band, the top tier of each by item level (the Greater tier where
-- it exists); auto-discovery takes the rest. Greater Stoneshield (armor, no
-- absorb) is a combat potion's shape, not this one.
--
-- Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied),
-- the owner's Auctionator and /cm probe seed stores (issue #46).
-- Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139
-- (tools/seeds/seeds.py, docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.PROT_POT = KCM.PerClient({
    -- The category is WoW Forever's alone (defaults/Categories.lua, clients-§4).
    retail = {},
    forever = {
        6048,  -- Shadow Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        6049,  -- Fire Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        6050,  -- Frost Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        6051,  -- Holy Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        6052,  -- Nature Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        13456,  -- Greater Frost Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
        13457,  -- Greater Fire Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
        13458,  -- Greater Nature Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
        13459,  -- Greater Shadow Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
        13461,  -- Greater Arcane Protection Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, recipe), AH, DB2 (crafted)
    },
})
