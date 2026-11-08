-- defaults/Defaults_Vantus.lua — Seed list for KCM_VANTUS.
--
-- Universal per-raid Versatility rune (Inscription, weekly). One current rune
-- per raid tier; extend as new tiers ship. Confirm new itemIDs in-game via
-- `/cm dump item <id>` and add them to VANTUS_IDS in core/Classifier.lua too.
-- Source: Wowhead, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.VANTUS = KCM.PerClient({
    retail = {
        245880,  -- Vantus Rune: Radiant
    },
    -- Empty by decision: step 2, owner ruling 2026-11-08. The category is absent on WoW Forever
    -- (defaults/Categories.lua, clients-§4), so nothing reads this list there.
    forever = {},
})
