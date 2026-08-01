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
--
-- Delegates to the console instance's own gated sink when there IS one, so the
-- gate, the secret-safe formatting and the append are the library's single
-- implementation rather than a second copy that agrees today.
--
-- The probe stays host-side and cannot move, which is why this is a wrapper
-- rather than a bare binding to D.Debug. Two paths reach here with no instance
-- to delegate to: early boot, because core/Debug.lua sits 37 lines above
-- modules/DebugLog.lua in the TOC and a file-scope capture would bind nil
-- forever; and a degraded install, where the console module publishes no
-- instance at all. Both fall through to chat, which is the behaviour those
-- paths have always had.
local mt = {
    __call = function(_, tag, fmt, ...)
        local DL = KCM.DebugLog
        local D  = DL and DL.instance
        if D then return D.Debug(tag, fmt, ...) end

        -- No console: gate here, then say it. The gate is duplicated on this
        -- path alone, and only because there is nothing yet to ask.
        if not KCM.Debug.IsOn() then return end
        local n = select("#", ...)
        local msg = fmt
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = KCM.SafeToString((select(i, ...))) end
            msg = tostring(fmt):format(unpack(parts))
        end
        KCM.Say("[" .. KCM.SafeToString(tag) .. "] " .. msg)
    end,
}
setmetatable(KCM.Debug, mt)
