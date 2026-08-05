-- Namespace.lua — private addon namespace bootstrap.
--
-- WoW passes the same private table as the second vararg to every file in this
-- addon. This bootstrap is loaded first so the AceAddon promotion in
-- ConsumableMaster (Core) and every module can rely on the
-- `local addonName, NS = ...` header with no global `_G.KCM` (architecture-§1).
--
-- The per-file transition alias `local KCM = NS` keeps the addon's ~1000
-- internal `KCM.*` references untouched during the migration; `KCM` is simply a
-- local handle on `NS`.

local addonName, NS = ...
NS.name = addonName
