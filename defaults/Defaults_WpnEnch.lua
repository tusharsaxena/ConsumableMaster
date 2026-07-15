-- defaults/Defaults_WpnEnch.lua — Seed list for KCM_WPN_ENCH.
--
-- Temporary weapon enhancements — Enchanting oils and Blacksmithing whetstones
-- / weightstones. Spec-aware: the Ranker weights the enhancement's secondary
-- stat against the active spec's stat priority, so a caster's oil and a plate
-- spec's whetstone sort correctly from one list. These items report subType
-- "Other", so the Classifier keys on the tooltip's weapon-application effect
-- ("your <weapon>", tt.isWeaponEnhance) to auto-discover any not seeded here.
--
-- Seed spans the last two expansions (Midnight 12.x, The War Within 11.x).
-- Source: Wowhead, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.WPN_ENCH = {
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
}
