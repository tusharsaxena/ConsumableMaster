-- defaults/Defaults_WpnEnch.lua — Seed list for KCM_WPN_ENCH.
--
-- Temporary weapon enhancements — Enchanting oils and Blacksmithing whetstones
-- / weightstones. Spec-aware: the Ranker weights the enhancement's secondary
-- stat against the active spec's stat priority, so a caster's oil and a plate
-- spec's whetstone sort correctly from one list. These items report subType
-- "Other", so the Classifier keys on the tooltip's weapon-application effect
-- ("your <weapon>", tt.isWeaponEnhance) to auto-discover any not seeded here.
--
-- Retail's seed spans the last two expansions (Midnight 12.x, The War Within
-- 11.x). WoW Forever's seeds one per weapon kind (blade stone, weightstone,
-- wizard or mana oil, proc oil) per ~10-level band; rogue poisons belong to
-- the poison category, never here.
-- Source: Wowhead, 2026-07.
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.WPN_ENCH = KCM.PerClient({
    retail = {
        -- Midnight (12.x)
        243733,  -- Thalassian Phoenix Oil   (CRIT + HASTE)
        243735,  -- Oil of Dawn              (healer)
        237370,  -- Refulgent Whetstone      (bladed weapons)
        237369,  -- Refulgent Weightstone    (blunt weapons)
        -- The War Within (11.x)
        224107,  -- Algari Mana Oil          (caster)
        224113,  -- Oil of Deep Toxins
        224110,  -- Oil of Beledar's Grace
        222504,  -- Ironclaw Whetstone       (bladed weapons)
        222508,  -- Ironclaw Weightstone     (blunt weapons)
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        2863,  -- Coarse Sharpening Stone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest), AH, probe (ah), DB2 (crafted)
        2871,  -- Heavy Sharpening Stone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        3240,  -- Coarse Weightstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (quest), AH, probe (ah), DB2 (crafted)
        3241,  -- Heavy Weightstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        3824,  -- Shadow Oil; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        3829,  -- Frost Oil; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, recipe), AH, probe (ah), DB2 (crafted)
        7964,  -- Solid Sharpening Stone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        7965,  -- Solid Weightstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        12404,  -- Dense Sharpening Stone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container), AH, DB2 (crafted)
        12643,  -- Dense Weightstone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, DB2 (crafted)
        18262,  -- Elemental Sharpening Stone; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), DB2 (crafted)
        20744,  -- Minor Wizard Oil; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        20745,  -- Minor Mana Oil; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        20748,  -- Brilliant Mana Oil; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), DB2 (crafted)
        20750,  -- Wizard Oil; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
    },
})
