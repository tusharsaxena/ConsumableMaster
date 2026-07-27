-- Debug.lua — conditional logging gated on the session-only KCM.State.debug.
--
-- The enabled flag lives in KCM.State (session-only, default off, never
-- persisted — standard §12.5) and is owned by DebugLog. Emitted diagnostics go
-- to the on-screen DebugLog console (standard §12); if the console module
-- hasn't loaded yet (very early boot) they fall back to the chat frame.
--
-- KCM.Debug is itself callable: KCM.Debug("Tag", "%s -> %s", a, b).

local _, NS = ...
local KCM = NS
KCM.Debug = KCM.Debug or {}

function KCM.Debug.IsOn()
    if KCM.DebugLog and KCM.DebugLog.IsEnabled then return KCM.DebugLog.IsEnabled() end
    return KCM.State and KCM.State.debug == true
end

-- There is deliberately no KCM.Debug.Toggle here: `DebugLog.SetEnabled` is the
-- single write path for the flag (debug-logging-§5), and every toggle entry
-- point — `/cm debug on|off`, the console header button, the options checkbox —
-- routes straight to it. A second wrapper could only diverge from that seam.

-- Callable sink (debug-logging-§4): KCM.Debug("Tag", "%s -> %s", a, b).
-- Zero-alloc gate is the FIRST statement; every vararg is stringified through
-- the secret-safe KCM.SafeToString so a combat "secret" can't raise here, which
-- is why all call-site placeholders are %s (never %d/%f).
local mt = {
    __call = function(_, tag, fmt, ...)
        if not KCM.Debug.IsOn() then return end
        local n = select("#", ...)
        local msg = fmt
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = KCM.SafeToString((select(i, ...))) end
            msg = tostring(fmt):format(unpack(parts))
        end
        if KCM.DebugLog and KCM.DebugLog.AddLine then
            KCM.DebugLog.AddLine(tag, msg)
        else
            KCM.Say("[" .. KCM.SafeToString(tag) .. "] " .. msg)
        end
    end,
}
setmetatable(KCM.Debug, mt)
