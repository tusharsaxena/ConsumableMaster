-- Constants.lua — shared literals.
--
-- Loaded early so KCM.PREFIX exists before any module (or category emptyText)
-- references it, and immediately before core/CoreSetup.lua, which builds the
-- chat printer this tag goes on.
--
-- The secret-safe stringifier and the KCM.Say chat seam used to live here.
-- They are LibKa0s-Core-1.0 now (libs/LibKa0s/Core.lua), wired up in
-- core/CoreSetup.lua — see that file for why the tag is handed over as a
-- function rather than as a value.

local _, NS = ...
local KCM = NS

-- Cyan [CM] chat prefix — the single source of truth (standard §7.4). Every
-- chat line and every macro-body `/run print(...)` references this instead of
-- a hand-written literal. No trailing space; KCM.Say adds the separator.
KCM.PREFIX = "|cff00ffff[CM]|r"

