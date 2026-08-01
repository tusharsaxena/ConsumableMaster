-- tests/test_debug.lua — core/Debug.lua: the gated diagnostic sink.
--
-- Debug.lua is the seam every module logs through. Its contract has three
-- halves: the zero-cost gate (nothing is formatted while debug is off), the
-- console-vs-chat routing (DebugLog when loaded, KCM.Say during early boot),
-- and the secret-safe formatting it inherits from KCM.SafeToString
-- (debug-logging-§4/§5).
--
-- The suites load the pure layer PLUS State + Debug but deliberately WITHOUT
-- modules/DebugLog.lua, so the early-boot fallback path is the default and the
-- console path is opted into per case by installing a stub console.

local h = require("harness")
local test = h.test

local function loadDebug()
    local files = {}
    for _, f in ipairs(h.loader.PURE_LAYER) do files[#files + 1] = f end
    files[#files + 1] = "core/State.lua"
    files[#files + 1] = "core/Debug.lua"
    return h.loader.loadFiles(files), h.loader.mock
end

-- Install a recording stand-in for the console module.
--
-- It publishes an `instance`, because that is the seam core/Debug.lua reaches
-- for now: the gated sink delegates to the library instance's own D.Debug when
-- there is one. The stub records what it was HANDED rather than what it would
-- render — the rendering is the library's, tested in the library's own suite,
-- and a stub that re-implemented it would only ever assert itself.
local function stubConsole(KCM, enabled)
    local lines = {}
    KCM.DebugLog = {
        IsEnabled = function() return enabled end,
        AddLine   = function(tag, msg) lines[#lines + 1] = { tag = tag, msg = msg } end,
        instance  = {
            Debug = function(tag, fmt, ...)
                if not enabled then return end
                lines[#lines + 1] = { tag = tag, fmt = fmt, n = select("#", ...) }
            end,
        },
    }
    return lines
end

local function concatHostile()
    return setmetatable({}, { __tostring = function() return "hostile" end })
end

test("Debug: the sink is published and callable", function(t)
    local KCM = loadDebug()
    t.truthy(KCM.Debug, "KCM.Debug published")
    local mt = getmetatable(KCM.Debug)
    t.eq(type(mt and mt.__call), "function", "KCM.Debug is callable via __call")
    t.eq(type(KCM.Debug.IsOn), "function", "and still a table carrying IsOn/Toggle")
end)

test("Debug: IsOn is false by default (State.debug is never persisted on)", function(t)
    local KCM = loadDebug()
    t.eq(KCM.State.debug, false, "session flag defaults off")
    t.eq(KCM.Debug.IsOn(), false, "so the sink reports off")
end)

test("Debug: IsOn tracks State.debug when no console module has loaded", function(t)
    local KCM = loadDebug()
    KCM.State.debug = true
    t.eq(KCM.Debug.IsOn(), true, "early-boot gate reads State.debug directly")
end)

test("Debug: IsOn defers to DebugLog.IsEnabled once the console owns the flag", function(t)
    local KCM = loadDebug()
    KCM.State.debug = false
    stubConsole(KCM, true)
    t.eq(KCM.Debug.IsOn(), true, "the console seam wins over the raw State read")
end)

test("Debug: a call while gated off emits nothing", function(t)
    local KCM, mock = loadDebug()
    mock.output = {}
    KCM.Debug("Tag", "%s", "payload")
    t.eq(#mock.output, 0, "no chat line while debug is off")
end)

test("Debug: a call while gated off never reaches the console either", function(t)
    local KCM = loadDebug()
    local lines = stubConsole(KCM, false)
    KCM.Debug("Tag", "message")
    t.eq(#lines, 0, "the gate is the first statement — nothing is formatted or routed")
end)

test("Debug: an enabled call is handed to the console instance's own sink", function(t)
    -- Delegation, not re-implementation. The gate, the secret-safe formatting
    -- and the append are LibKa0s-DebugLog-1.0's single implementation; what
    -- this addon owns is choosing between that and the chat fallback.
    local KCM = loadDebug()
    local lines = stubConsole(KCM, true)
    KCM.Debug("Pipeline", "recomputed %s", "FOOD")
    t.eq(#lines, 1, "exactly one console call")
    t.eq(lines[1].tag, "Pipeline", "tag passed through untouched")
    t.eq(lines[1].fmt, "recomputed %s", "and the format string, unformatted")
    t.eq(lines[1].n, 1, "with its varargs intact for the library to render")
end)

test("Debug: with no console loaded an enabled call falls back to tagged chat", function(t)
    local KCM, mock = loadDebug()
    KCM.State.debug = true
    mock.output = {}
    KCM.Debug("Init", "booting")
    t.eq(#mock.output, 1, "one chat line during early boot")
    t.eq(mock.output[1], KCM.PREFIX .. " [Init] booting",
        "chat fallback wraps the tag in brackets behind the [CM] prefix")
end)

-- The three cases below pin the CHAT-fallback formatting, which is still this
-- addon's own code: early boot and a degraded install both reach it, and both
-- are paths where there is no instance to hand the work to.
test("Debug: a message with no format args is emitted verbatim", function(t)
    local KCM, mock = loadDebug()
    KCM.State.debug = true
    mock.output = {}
    KCM.Debug("Tag", "100% done")
    t.truthy((mock.output[1] or ""):find("100% done", 1, true),
        "no varargs means no :format pass, so a bare % cannot raise")
end)

test("Debug: every format arg goes through the secret guard", function(t)
    local KCM, mock = loadDebug()
    KCM.State.debug = true
    mock.output = {}
    KCM.Debug("Tag", "id=%s", concatHostile())
    t.truthy((mock.output[1] or ""):find("id=<secret>", 1, true),
        "a combat secret logs as <secret> instead of raising")
end)

test("Debug: a nil format arg renders as 'nil' rather than shifting later args", function(t)
    local KCM, mock = loadDebug()
    KCM.State.debug = true
    mock.output = {}
    KCM.Debug("Tag", "a=%s b=%s", nil, "two")
    t.truthy((mock.output[1] or ""):find("a=nil b=two", 1, true),
        "positions are preserved across a nil")
end)

test("Debug: the chat fallback stringifies a hostile tag safely", function(t)
    local KCM, mock = loadDebug()
    KCM.State.debug = true
    mock.output = {}
    KCM.Debug(concatHostile(), "body")
    t.eq(mock.output[1], KCM.PREFIX .. " [<secret>] body",
        "the tag is guarded on the fallback path too")
end)

test("Debug: the sink publishes no Toggle of its own", function(t)
    local KCM = loadDebug()
    -- DebugLog.SetEnabled is the single write path for the flag
    -- (debug-logging-§5). A second toggle wrapper here could only diverge
    -- from it, so core/Debug.lua deliberately does not ship one.
    t.eq(KCM.Debug.Toggle, nil, "no Debug.Toggle wrapper beside the DebugLog seam")
    t.eq(type(KCM.Debug.IsOn), "function", "the read-side gate is still published")
end)
