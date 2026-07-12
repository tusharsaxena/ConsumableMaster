-- Debug.lua — conditional logging gated on the session-only KCM.State.debug.
--
-- The enabled flag lives in KCM.State (session-only, default off, never
-- persisted — standard §12.5) and is owned by DebugLog. Emitted diagnostics go
-- to the on-screen DebugLog console (standard §12); if the console module
-- hasn't loaded yet (very early boot) they fall back to the chat frame.

local _, NS = ...
local KCM = NS
KCM.Debug = KCM.Debug or {}

local PREFIX = KCM.PREFIX .. " "

function KCM.Debug.IsOn()
    if KCM.DebugLog and KCM.DebugLog.IsEnabled then return KCM.DebugLog.IsEnabled() end
    return KCM.State and KCM.State.debug == true
end

function KCM.Debug.Toggle()
    local on
    if KCM.DebugLog and KCM.DebugLog.Toggle then
        on = KCM.DebugLog.Toggle()
    else
        KCM.State = KCM.State or {}
        KCM.State.debug = not KCM.State.debug
        on = KCM.State.debug
    end
    local state = on and "|cff00ff00ON|r" or "|cffff5555OFF|r"
    print(PREFIX .. "Debug mode " .. state)
    if KCM.Options and KCM.Options.Refresh then
        KCM.Options.Refresh()
    end
    return on
end

-- Zero-alloc gate BEFORE any string.format (standard §12). Diagnostics route
-- to the console; the optional `tag` groups related lines there.
local function emit(tag, fmt, ...)
    if not KCM.Debug.IsOn() then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    if KCM.DebugLog and KCM.DebugLog.AddLine then
        KCM.DebugLog.AddLine(tag, msg)
    else
        print(PREFIX .. (tag and ("[" .. tag .. "] ") or "") .. msg)
    end
end

-- Legacy tagless entry used across the addon.
function KCM.Debug.Print(fmt, ...)
    return emit(nil, fmt, ...)
end

-- Tag-first entry (standard §12): KCM.Debug.Log("pipeline", "%s -> %s", a, b).
function KCM.Debug.Log(tag, fmt, ...)
    return emit(tag, fmt, ...)
end
