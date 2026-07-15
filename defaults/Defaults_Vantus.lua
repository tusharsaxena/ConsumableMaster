-- defaults/Defaults_Vantus.lua — Seed list for KCM_VANTUS.
--
-- Universal per-raid Versatility rune (Inscription, weekly). One current rune
-- per raid tier; extend as new tiers ship. Confirm new itemIDs in-game via
-- `/cm dump item <id>` and add them to VANTUS_IDS in core/Classifier.lua too.
-- Source: Wowhead, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.VANTUS = {
    245880,  -- Vantus Rune: Radiant
}
