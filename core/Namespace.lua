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

-- The version string lives HERE, in the bootstrap, rather than in
-- core/ConsumableMaster.lua where it used to sit. core/PerfSetup.lua reads it
-- at LOAD time for the perf record's `version` field, and performance-§1 puts
-- PerfSetup ahead of every file that takes `local Perf = NS.Perf` as a
-- load-time upvalue -- which includes core/ConsumableMaster.lua. The version
-- therefore has to be set before either of them, and the bootstrap is the only
-- file that runs earlier. (AbsorbTracker carries `NS.version` in its own
-- core/Namespace.lua for exactly this reason.)
NS.VERSION = "1.5.0"
