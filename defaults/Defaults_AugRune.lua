-- defaults/Defaults_AugRune.lua — Seed list for KCM_AUG_RUNE.
--
-- Augment runes — a one-active-at-a-time primary-stat buff (1 hour, lost on
-- death). "Permanent" runes (Ethereal, Dreambound) are not permanently
-- buffed; they are simply NOT consumed on use, so they're reusable. The
-- Ranker ranks by primary-stat amount and breaks ties toward reusable runes
-- (see REUSABLE_AUG_IDS in core/Classifier.lua). Runes report a generic
-- subType, so the Classifier keys on the tooltip's "Augment Rune" marker
-- (tt.isAugmentRune) to auto-discover any not seeded here.
--
-- Seed spans Dragonflight (10.x), The War Within (11.x), Midnight (12.x).
-- Source: Wowhead / Warcraft Wiki, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.AUG_RUNE = {
    -- Midnight (12.x)
    259085,  -- Void-Touched Augment Rune
    -- The War Within (11.x)
    243191,  -- Ethereal Augment Rune      (reusable)
    246492,  -- Soulgorged Augment Rune
    224572,  -- Crystallized Augment Rune
    -- Dragonflight (10.x)
    211495,  -- Dreambound Augment Rune    (reusable)
    201325,  -- Draconic Augment Rune
}
