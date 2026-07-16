-- defaults/Defaults_AugRune.lua — Seed list for KCM_AUG_RUNE.
--
-- Augment runes — a one-active-at-a-time primary-stat buff (1 hour, lost on
-- death). "Permanent" runes (Ethereal, Dreambound, Eternal, Lightning-Forged,
-- Lightforged) are not permanently buffed; they are simply NOT consumed on
-- use, so they're reusable. The Ranker ranks by primary-stat amount and breaks
-- ties toward reusable runes (see REUSABLE_AUG_IDS in core/Classifier.lua —
-- keep the reusable-flagged IDs below in sync with it). Runes report a generic
-- subType, so the Classifier keys on the tooltip's "Augment Rune" marker
-- (tt.isAugmentRune) to auto-discover any not seeded here.
--
-- Seed spans Legion (7.x) through Midnight (12.x), newest expansion first.
-- Ranking is by primary-stat amount, not seed order, so order is cosmetic —
-- the ancient low-stat runes simply sort to the bottom. Pre-Legion (Warlords
-- garrison) runes are a different, obsolete mechanic and are not seeded.
-- Source: Wowhead / Warcraft Wiki, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.AUG_RUNE = {
    -- Midnight (12.x)
    259085,  -- Void-Touched Augment Rune
    -- The War Within (11.x)
    243191,  -- Ethereal Augment Rune         (reusable)
    246492,  -- Soulgorged Augment Rune
    224572,  -- Crystallized Augment Rune
    -- Dragonflight (10.x)
    211495,  -- Dreambound Augment Rune        (reusable)
    201325,  -- Draconic Augment Rune
    -- Shadowlands (9.x)
    190384,  -- Eternal Augment Rune           (reusable)
    181468,  -- Veiled Augment Rune
    -- Battle for Azeroth (8.x)
    174906,  -- Lightning-Forged Augment Rune  (reusable)
    160053,  -- Battle-Scarred Augment Rune
    -- Legion (7.x)
    153023,  -- Lightforged Augment Rune       (reusable)
    140587,  -- Defiled Augment Rune
}
