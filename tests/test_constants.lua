-- tests/test_constants.lua — core/Constants.lua: the chat prefix, the
-- secret-safe stringifier, and the KCM.Say chat seam.
--
-- Every one-shot chat line in the addon funnels through KCM.Say, so its two
-- call forms and the secret guard it inherits from KCM.SafeToString are the
-- single most load-bearing formatting contract in the addon
-- (events-frames-taint-§8 / standard §7.4).

local h = require("harness")
local test = h.test

-- A value that survives tostring()/`..` but raises the moment it reaches
-- table.concat — the headless stand-in for a combat-protected "secret".
local function concatHostile()
    return setmetatable({}, { __tostring = function() return "hostile" end })
end

test("Constants: PREFIX is the cyan [CM] tag with no trailing space", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.PREFIX, "|cff00ffff[CM]|r", "PREFIX is the single source of truth for the chat tag")
    t.falsy(KCM.PREFIX:find("%s$"), "no trailing space — Say adds the separator")
end)

test("Constants: IsConcatSafe accepts strings and numbers", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.IsConcatSafe("plain"), "a string is concat-safe")
    t.truthy(KCM.IsConcatSafe(42), "a number is concat-safe")
end)

test("Constants: IsConcatSafe rejects a value table.concat would raise on", function(t)
    local KCM = h.loader.loadPure()
    t.falsy(KCM.IsConcatSafe(concatHostile()),
        "detection probes a real table.concat, not tostring/..")
end)

test("Constants: SafeToString renders nil as the literal 'nil'", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SafeToString(nil), "nil", "nil never reaches concat as a nil")
end)

test("Constants: SafeToString passes booleans through, which concat itself rejects", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SafeToString(true), "true", "true stringifies")
    t.eq(KCM.SafeToString(false), "false", "false stringifies (not treated as absent)")
end)

test("Constants: SafeToString passes strings and numbers through unchanged", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SafeToString("hello"), "hello", "string round-trips")
    t.eq(KCM.SafeToString(7), "7", "number stringifies")
end)

test("Constants: SafeToString substitutes <secret> for a concat-hostile value", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SafeToString(concatHostile()), "<secret>",
        "a value a concat would reject never reaches the concat")
end)

test("Constants: Say prints one prefixed line in the single-string form", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.output = {}
    KCM.Say("finished")
    t.eq(#mock.output, 1, "exactly one chat line")
    t.eq(mock.output[1], KCM.PREFIX .. " finished", "tag, one space, then the line")
end)

test("Constants: Say interpolates the format-string call form", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.output = {}
    KCM.Say("%s -> %s", "before", "after")
    t.eq(mock.output[1], KCM.PREFIX .. " before -> after", "args substituted in order")
end)

test("Constants: Say stringifies every format arg through the secret guard", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.output = {}
    KCM.Say("value=%s", concatHostile())
    t.eq(mock.output[1], KCM.PREFIX .. " value=<secret>",
        "a secret arg logs as <secret> instead of raising")
end)

test("Constants: Say renders a nil format arg as 'nil' rather than dropping it", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.output = {}
    KCM.Say("a=%s b=%s", nil, 2)
    t.eq(mock.output[1], KCM.PREFIX .. " a=nil b=2",
        "select('#') counts the nil so later args keep their positions")
end)

test("Constants: Say guards the single-string form too", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.output = {}
    KCM.Say(concatHostile())
    t.eq(mock.output[1], KCM.PREFIX .. " <secret>",
        "a bare secret argument is stringified, not concatenated raw")
end)
