-- Debug.lua — conditional logging gated on the session-only KCM.State.debug.
--
-- The enabled flag lives in KCM.State (session-only, default off, never
-- persisted — debug-logging-§5) and is owned by DebugLog. Emitted diagnostics go
-- to the on-screen DebugLog console (debug-logging); if the console module
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
-- core/DebugLogSetup.lua in the TOC and a file-scope capture would bind nil
-- forever; and a degraded install, where the console module publishes no
-- instance at all. Both fall through to chat, which is the behavior those
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

-- The console's change gates and at-enable queue (LibKa0s-DebugLog-1.0's
-- DebugLogGates.lua, from LibKa0s v1.65.0), reached through the same probe as
-- the sink above and for the same reason: this file loads before the console
-- exists. A "log once" line goes through KCM.DebugOnce, a "log when it
-- changes" line through KCM.DebugChanged, and both are gated and formatted as
-- KCM.Debug is and re-armed by the console itself, on Clear() and on turning
-- logging on (debug-logging-§9). A STATE line written while logging is off
-- (the launcher's registration) goes through KCM.DebugAtEnable, which holds it
-- until logging is turned on (debug-logging-§8).
--
-- With no console -- early boot, or a degraded install that publishes no
-- instance -- each answers false and writes nothing, as the standard's
-- DebugLog stub does (debug-logging-§7). They are NOT the chat fallback the
-- sink takes: a gate exists because its path repeats, and a repeating line
-- with no memory behind it would flood the chat frame.
local function gates()
    local DL = KCM.DebugLog
    local D = DL and DL.instance
    if D and D.DebugOnce then return D end
    return nil
end

function KCM.DebugOnce(key, tag, fmt, ...)
    local D = gates()
    if not D then return false end
    return D.DebugOnce(key, tag, fmt, ...)
end

function KCM.DebugChanged(key, tag, fmt, ...)
    local D = gates()
    if not D then return false end
    return D.DebugChanged(key, tag, fmt, ...)
end

function KCM.DebugForget(key)
    local D = gates()
    if D then D.DebugForget(key) end
end

function KCM.DebugAtEnable(tag, fmt, ...)
    local D = gates()
    if not D then return false end
    return D.DebugAtEnable(tag, fmt, ...)
end
