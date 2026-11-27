-- defaults/Defaults_CombatPot.lua — Seed list for KCM_CMBT_POT.
--
-- Combat potions: subType = "Potions" + short buff duration (≤60s) + no
-- heal/mana. Spec-specific fit is resolved by Ranker via Defaults_StatPriority
-- and parsed stat buffs. Utility potions (invisibility, slow fall, absorb,
-- water breathing) are intentionally NOT seeded here — they'd confuse
-- rank output even though the Classifier may still match them as CMBT_POT
-- when auto-discovered.
--
-- Stat tags recorded here are what the tooltip describes in natural
-- language; TooltipCache translates "highest secondary stat" phrasing into
-- the synthetic TOP_SECONDARY stat which Ranker scores against the spec's
-- top secondary.
--
-- Source: Method.gg Midnight consumables list, 2026-04-22.
-- Validated: 2026-11-15 against Retail 12.1.5.70783 on wago.tools (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-15-retail/, issue #49).
-- See defaults/README.md to re-run the refresh.
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.CMBT_POT = KCM.PerClient({
    retail = {
        241308,  -- Light's Potential           (primary stat, 30s)
        241288,  -- Potion of Recklessness      (top secondary stat, 30s)
        241292,  -- Draught of Rampant Abandon  (primary stat + void zone, 30s)
        241296,  -- Potion of Zealotry          (stacking Holy damage on target)
        271887,  -- Liquid Luster; added from the 2026-11-15 wago.tools validation (12.1.5.70783)
        271890,  -- Alluring Nostrum; added from the 2026-11-15 wago.tools validation (12.1.5.70783)
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        13442,  -- Mighty Rage Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250932,  -- Minor Spellblasting Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250933,  -- Lesser Spellblasting Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250934,  -- Spellblasting Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250935,  -- Greater Spellblasting Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250936,  -- Superior Spellblasting Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250937,  -- Major Spellblasting Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250938,  -- Minor Frenzy Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250939,  -- Lesser Frenzy Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250940,  -- Frenzy Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250941,  -- Greater Frenzy Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250942,  -- Superior Frenzy Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250943,  -- Major Frenzy Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250944,  -- Minor Mender's Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250945,  -- Lesser Mender's Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted)
        250946,  -- Mender's Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250947,  -- Greater Mender's Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah), DB2 (crafted)
        250948,  -- Superior Mender's Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        250949,  -- Major Mender's Potion; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
    },
})
