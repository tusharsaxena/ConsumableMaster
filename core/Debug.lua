-- Debug.lua — conditional logging gated on the session-only KCM.State.debug.
--
-- The enabled flag lives in KCM.State (session-only, default off, never
-- persisted — standard §12.5) and is owned by DebugLog. Emitted diagnostics go
-- to the on-screen DebugLog console (standard §12); if the console module
-- hasn't loaded yet (very early boot) they fall back to the chat frame.
--
-- KCM.Debug is itself callable: KCM.Debug("Tag", "%s -> %s", a, b). KCM.Debug.Log
-- is a tag-first alias of the same callable.

local _, NS = ...
local KCM = NS
KCM.Debug = KCM.Debug or {}

local PREFIX = KCM.PREFIX .. " "

function KCM.Debug.IsOn()
    if KCM.DebugLog and KCM.DebugLog.IsEnabled then return KCM.DebugLog.IsEnabled() end
    return KCM.State and KCM.State.debug == true
end

function KCM.Debug.Toggle()
    -- Route through the DebugLog seam, which owns the single write path: flip the
    -- flag → refresh header → chat ack → console transition line → options refresh
    -- (standard debug-logging-§5). Don't ack again here or the line prints twice.
    if KCM.DebugLog and KCM.DebugLog.Toggle then
        return KCM.DebugLog.Toggle()
    end
    -- Fallback before the console module has loaded (very early boot): flip the
    -- flag and ack to chat so the toggle still does something.
    KCM.State = KCM.State or {}
    KCM.State.debug = not KCM.State.debug
    local on = KCM.State.debug
    print(PREFIX .. "Debug mode " .. (on and "|cff00ff00ON|r" or "|cffff5555OFF|r"))
    if KCM.Options and KCM.Options.Refresh then
        KCM.Options.Refresh()
    end
    return on
end

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
            print(PREFIX .. "[" .. tostring(tag) .. "] " .. tostring(msg))
        end
    end,
}
setmetatable(KCM.Debug, mt)

-- Tag-first alias (retained for already-tagged call sites and tests).
function KCM.Debug.Log(tag, fmt, ...)
    return KCM.Debug(tag, fmt, ...)
end
