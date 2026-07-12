-- Constants.lua — shared literals and the chat-output seam.
--
-- Loaded immediately after Core.lua so KCM.PREFIX exists before any module
-- (or category emptyText) references it.

local _, NS = ...
local KCM = NS

-- Cyan [CM] chat prefix — the single source of truth (standard §7.4). Every
-- chat line and every macro-body `/run print(...)` references this instead of
-- a hand-written literal. No trailing space; KCM.Say adds the separator.
KCM.PREFIX = "|cff00ffff[CM]|r"

-- Chat-output seam. All one-shot addon chat routes through here so the [CM]
-- tag is unconditional. Debug (gated) has its own path in Debug.lua.
function KCM.Say(msg)
    print(KCM.PREFIX .. " " .. tostring(msg))
end
