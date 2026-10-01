-- test_slash_degraded.lua — the library-absent build's composed-row verbs
-- (options-ui-§1 route (b), slash-commands-§1; CM-18), and the pin on the live
-- disabled refusal's format. Split from tests/test_slash.lua, which sits at the
-- layout-§1 line cap.

local h = _G.KCM_TEST
local test = h.test

-- The profile, serialized with sorted keys, so "unchanged store" is one compare.
local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- ---------------------------------------------------------------------------
-- Library-absent composed-row verbs: route (b) of options-ui-§1 (WS-02, CM-18)
-- ---------------------------------------------------------------------------
--
-- On a build with libs/LibKa0s/ missing the Master controls rows -- `enabled`
-- and `macroBar.locked` among them -- do not exist (the composers answer {}),
-- and there is no Lifecycle latch (core/LifecycleSetup.lua returns early), so a
-- stored addon switch would not be obeyed this session. Every verb whose write
-- targets one of those rows therefore refuses on the ONE library-absent line
-- for its verb, raises nothing, and leaves the store alone. The route is
-- recorded as a Documented deviation (docs/ARCHITECTURE.md, options-ui-§1).
--
-- The line is WS-02's sentence, byte for byte, through the host's locale. The
-- Slash version-15 doc's "The degradation stub" section publishes no library
-- member for it (the sentence is the host's, not a lib.STRINGS entry), so it is
-- pinned against the standard's text here rather than through
-- assertLibraryConstant.
local LIBRARY_ABSENT_LINE = "%s is unavailable: the LibKa0s library did not load."

local function absentLine(KCM, verb)
    return KCM.PREFIX .. " " .. LIBRARY_ABSENT_LINE:format("/cm " .. verb)
end

-- A degraded build with the said-once "library is missing" notice already
-- spent: it rides on the session's first KCM.Say, so a line count taken
-- without this would be the verb's plus the notice.
local function degraded()
    local KCM = h.loader.loadFullAddon(true)
    KCM.Say("warm")
    h.loader.mock.output = {}
    return KCM, h.loader.mock
end

local function runVerb(KCM, mock, verb)
    mock.output = {}
    local ok, err = pcall(KCM.OnSlashCommand, KCM, verb)
    return ok, err, mock.output
end

test("Slash: the library-absent line is WS-02's sentence, through the locale", function(t)
    local KCM = degraded()
    t.eq(KCM.L[LIBRARY_ABSENT_LINE], LIBRARY_ABSENT_LINE,
        "one sentence, one placeholder, byte for byte")
end)

-- Red before CM-18: `enable` printed "settings unavailable." and `lock` printed
-- "macro bar locked" over a write the seam refused.
local COMPOSED_ROW_VERBS = { "enable", "disable", "lock", "unlock", "bar lock", "bar unlock" }

for _, verb in ipairs(COMPOSED_ROW_VERBS) do
    test("Slash: with LibKa0s absent, /cm " .. verb .. " prints the library-absent line and writes nothing",
        function(t)
            local KCM, mock = degraded()
            local before = ser(KCM.db.profile)
            local ok, err, out = runVerb(KCM, mock, verb)
            t.truthy(ok, "no Lua error: " .. tostring(err))
            t.eq(#out, 1, "exactly one line: " .. table.concat(out, " | "))
            t.eq(out[1], absentLine(KCM, verb), "the library-absent line for the verb")
            t.eq(ser(KCM.db.profile), before, "and an unchanged store")
        end)
end

-- `macroBar.enabled` is NOT a composed row: settings/MacroBar.lua declares it by
-- hand, so the degraded seam validates the write, it lands, and the host's bar
-- obeys it. `/cm bar`, `bar on` and `bar off` therefore keep working here, and
-- their success line is true -- what they must not do is print it over a write
-- that did NOT land (the next case).
for _, spec in ipairs({ { "bar on", true }, { "bar off", false }, { "bar", false } }) do
    local verb, want = spec[1], spec[2]
    test("Slash: with LibKa0s absent, /cm " .. verb .. " lands on the hand-declared row and says so once",
        function(t)
            local KCM, mock = degraded()
            local ok, err, out = runVerb(KCM, mock, verb)
            t.truthy(ok, "no Lua error: " .. tostring(err))
            t.eq(#out, 1, "exactly one line: " .. table.concat(out, " | "))
            t.eq(KCM.db.profile.macroBar.enabled, want, "the write landed")
            t.eq(out[1], KCM.PREFIX .. " macro bar " .. (want and "|cff00ff00ON|r" or "|cffff5555OFF|r"),
                "and the line says what landed")
        end)
end

-- `/cm profile` is LibKa0s-Slash-1.0's verb (minor 17), so with the library absent
-- there is no store adapter to trust and it takes route (b) like the composed-row
-- verbs: the one library-absent line for `/cm profile`, whatever followed the verb,
-- and no switch. AceDB would CREATE a typed name, so switching here unguarded is
-- the worse failure, not a kinder one. The published ProfileSwitch says the same.
--
-- red under: routing the degraded verb to db:SetProfile, or leaving it unbound (a
-- Lua error on a nil upvalue).
test("Slash: with LibKa0s absent, /cm profile prints the library-absent line and switches nothing",
    function(t)
        local KCM, mock = degraded()
        local names = {}
        for name in pairs(KCM.db.profiles) do names[#names + 1] = name end
        for _, line in ipairs({ "profile", "profile Alt", "profile \"My Main\"" }) do
            local ok, err, out = runVerb(KCM, mock, line)
            t.truthy(ok, "no Lua error: " .. tostring(err))
            t.eqList(out, { absentLine(KCM, "profile") }, "/cm " .. line .. ": the one line")
        end
        mock.output = {}
        t.eq(KCM.SlashCommands.ProfileSwitch("Alt"), false, "ProfileSwitch answers false")
        t.eqList(mock.output, { absentLine(KCM, "profile") }, "with the same line")
        t.eq(KCM.db:GetCurrentProfile(), "Default", "nothing switched")
        local after = {}
        for name in pairs(KCM.db.profiles) do after[#after + 1] = name end
        t.eq(#after, #names, "and nothing was created")
    end)

-- Red under: printing the success line without checking SetEnabled's verdict.
test("Slash: /cm bar on over a refused write never says ON", function(t)
    local KCM, mock = degraded()
    KCM.MacroBar.SetEnabled = function() return false end
    local before = ser(KCM.db.profile)
    local ok, err, out = runVerb(KCM, mock, "bar on")
    t.truthy(ok, "no Lua error: " .. tostring(err))
    t.eq(#out, 1, "exactly one line: " .. table.concat(out, " | "))
    t.eq(out[1], absentLine(KCM, "bar on"), "the library-absent line, not 'macro bar ON'")
    t.eq(ser(KCM.db.profile), before, "and an unchanged store")
end)

-- THE DISABLED REFUSAL HAS NO HOST COPY, and that is the point of this pin.
-- `git grep DISABLED_LINE_FORMAT -- core settings` is empty: the degraded arm has
-- no latch, so it has no disabled state to refuse, and the live arm's line is
-- the library's own cli:DisabledLine(). What IS pinned is that the live line is
-- built from the library's format verbatim: substitute the two arguments back
-- out of the line and the format that remains must be DISABLED_LINE_FORMAT, byte
-- for byte.
test("Slash: the live disabled refusal is built from the library's DISABLED_LINE_FORMAT", function(t)
    local KCM = h.loader.loadFullAddon()
    local line = KCM.SlashCommands.instance:DisabledLine()
    local brand, verb = "Ka0s Consumable Master", "/cm enable"
    local b = line:find(brand, 1, true)
    t.truthy(b, "the line carries the brand: " .. line)
    local format = line:sub(1, b - 1) .. "%s" .. line:sub(b + #brand)
    local v = format:find(verb, 1, true)
    t.truthy(v, "and the verb: " .. line)
    format = format:sub(1, v - 1) .. "%s" .. format:sub(v + #verb)
    h.assertLibraryConstant(format, "LibKa0s-Slash-1.0", "DISABLED_LINE_FORMAT")
end)

-- ---------------------------------------------------------------------------
-- The sub-command namespaces, library absent (ConsumableMaster#44)
-- ---------------------------------------------------------------------------
--
-- priority / stat / aio / bar are host verbs, so degradedDispatch still reaches
-- them and their sub-help and sub-dispatch must keep answering.
local SUB_HELP = {
    { line = "priority", prefix = "/cm priority <cat>",
      verbs = { "list", "add", "remove", "up", "down", "reset" } },
    { line = "stat",     prefix = "/cm stat",
      verbs = { "list", "primary", "secondary", "reset" } },
    { line = "aio",      prefix = "/cm aio <key>",
      verbs = { "list", "toggle", "up", "down", "reset" } },
    { line = "bar help", prefix = "/cm bar",
      verbs = { "on", "off", "lock", "unlock", "reset" } },
}

test("Slash: with LibKa0s absent, every sub-help still answers", function(t)
    local KCM, mock = degraded()
    for _, spec in ipairs(SUB_HELP) do
        local ok, err, out = runVerb(KCM, mock, spec.line)
        t.truthy(ok, "/cm " .. spec.line .. ": no Lua error: " .. tostring(err))
        local text = table.concat(out, "\n")
        for _, verb in ipairs(spec.verbs) do
            t.truthy(text:find(spec.prefix .. " " .. verb, 1, true),
                "/cm " .. spec.line .. " names " .. spec.prefix .. " " .. verb)
        end
    end
end)

test("Slash: with LibKa0s absent, a sub-verb still dispatches", function(t)
    local KCM, mock = degraded()
    local function effective()
        local set = {}
        for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do set[id] = true end
        return set
    end
    local ok, err = runVerb(KCM, mock, "priority food add 987654")
    t.truthy(ok, "no Lua error: " .. tostring(err))
    t.truthy(effective()[987654], "the added item is present")
    runVerb(KCM, mock, "priority food remove 987654")
    t.falsy(effective()[987654], "the removed item is gone")
    -- An explicit specKey: the current-spec read goes through KCM.Compat's
    -- spec ladder, which is library-backed and answers nothing on this arm.
    ok, err = runVerb(KCM, mock, "stat primary INT 7_263")
    t.truthy(ok, "no Lua error: " .. tostring(err))
    t.eq(KCM.db.profile.statPriority["7_263"].primary, "INT", "the primary stat is set")
end)
