-- defaults/Defaults_BattleRez.lua — Seed list for KCM_BATTLE_REZ.
--
-- Combat resurrection, spell forms first, then the item any class can carry.
--
-- Soulstone is included deliberately even though it is pre-cast on a LIVING
-- ally rather than pressed when someone dies — it is what a warlock brings, and
-- the category's targeting clause uses `help` without `dead` precisely so the
-- one body works for it as well as for the rezzes.
--
-- The Gnomish Army Knife / Goblin Jumper Cables line is deliberately absent:
-- those are out-of-combat only, so they would resolve to a button that cannot
-- be pressed when it matters.
--
-- Sources: warcraft.wiki.gg, 2026-08. IDs pending in-game confirmation.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.BATTLE_REZ = {
    KCM.ID.AsSpell(20484),   -- Rebirth       (Druid)
    KCM.ID.AsSpell(61999),   -- Raise Ally    (Death Knight)
    KCM.ID.AsSpell(391054),  -- Intercession  (Paladin)
    KCM.ID.AsSpell(20707),   -- Soulstone     (Warlock; pre-cast on a living ally)
    248486,                  -- Emergency Soul Link (Midnight; usable by anyone, in combat)
}
