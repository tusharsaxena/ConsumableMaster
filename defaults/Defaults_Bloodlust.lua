-- defaults/Defaults_Bloodlust.lua — Seed list for KCM_BLOODLUST.
--
-- The raid haste effect, spell forms first. Every class reaches it by a
-- different name, so the roster is a union and Selector resolves whichever the
-- character actually has; the drums are the item fallback for classes that
-- bring none.
--
-- Drums stop AFFECTING players past their expansion's cap, so an old drum in
-- bags is dead weight at max level. The whole line ships anyway: TooltipCache
-- parses the cap and Selector filters on it, which leaves them usable while
-- levelling and in Timewalking. See docs/superpowers/specs/2026-08-03-*.
--
-- Sources: warcraft.wiki.gg "Bloodlust effect", 2026-08. IDs pending in-game
-- confirmation via /cm dump item.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.BLOODLUST = {
    KCM.ID.AsSpell(2825),    -- Bloodlust            (Shaman, Horde)
    KCM.ID.AsSpell(32182),   -- Heroism              (Shaman, Alliance)
    KCM.ID.AsSpell(80353),   -- Time Warp            (Mage)
    KCM.ID.AsSpell(390386),  -- Fury of the Aspects  (Evoker)
    KCM.ID.AsSpell(466904),  -- Harrier's Cry        (Hunter, Marksmanship)
    KCM.ID.AsSpell(272678),  -- Primal Rage          (Hunter, Ferocity pet — class-gated below)
    244639,                  -- Void-Touched Drums          (Midnight)
    -- Superseded drums, kept for levelling and Timewalking; the level-cap
    -- filter removes them at max level.
    -- (The War Within / Dragonflight / Shadowlands / BfA / Legion / WoD / MoP / TBC
    --  itemIDs go here, newest first, once confirmed with /cm dump item.)
}

-- Abilities that are NOT in the player's own spellbook, so IsPlayerSpell
-- reports false even for the class that has them. Primal Rage lives in the
-- hunter pet's book. Keyed by the same sentinel the roster uses; the value is
-- the locale-independent class file from UnitClass's second return.
KCM.SEED.CLASS_GATE = KCM.SEED.CLASS_GATE or {}
KCM.SEED.CLASS_GATE[KCM.ID.AsSpell(272678)] = "HUNTER"
