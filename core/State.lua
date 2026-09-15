-- core/State.lua — session-only runtime state.
--
-- Anything here is deliberately NOT persisted to SavedVariables: it resets to
-- these defaults every login / reload (debug-logging-§5). The debug-console flag
-- lives here (not in profile) so a session left with debug on doesn't leak
-- verbose logging into the next login.

local _, NS = ...
local KCM = NS
KCM.State = KCM.State or {}

-- Debug console + verbose logging enabled flag. Default off; /cm debug and the
-- console header toggle both route through DebugLog:SetEnabled which sets this.
if KCM.State.debug == nil then KCM.State.debug = false end
