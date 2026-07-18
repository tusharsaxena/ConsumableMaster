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

-- Secret-safe stringifier (events-frames-taint-§8 / debug-logging-§4). A
-- combat-protected "secret" value SURVIVES tostring() and the `..` operator
-- (both silently propagate secretness) but RAISES the instant it reaches
-- table.concat / string.format. So detection MUST probe a real table.concat —
-- a `..`/tostring probe reports a secret as safe and lets it slip through to
-- the concat that finally raises. Substitute "<secret>" for anything a concat
-- would reject; this is the single guard every chat/debug line inherits.
local function probeConcat(v) return table.concat({ v }) end
function KCM.IsConcatSafe(v) return (pcall(probeConcat, v)) end
function KCM.SafeToString(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end   -- never secret; concat rejects it anyway
    if KCM.IsConcatSafe(v) then return tostring(v) end
    return "<secret>"
end

-- Chat-output seam. All one-shot addon chat routes through here so the [CM]
-- tag is unconditional and every argument is secret-safe (events-frames-taint-§8):
-- a combat "secret" logs as "<secret>" instead of raising. Debug (gated) has its
-- own path in Debug.lua. Two call forms:
--   KCM.Say("plain finished line")     -- single string, secret-stringified
--   KCM.Say("value=%s -> %s", a, b)    -- format string + args (each secret-safe)
function KCM.Say(fmt, ...)
    local n = select("#", ...)
    local line
    if n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = KCM.SafeToString((select(i, ...))) end
        line = tostring(fmt):format(unpack(parts))
    else
        line = KCM.SafeToString(fmt)
    end
    print(KCM.PREFIX .. " " .. line)
end
