-- test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; CM-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row right after `config` runs KCM.RunSkinVerb, which hands O.SkinVerb the spec the
-- first-run start builds, so `/cm skin` shows the picker a new profile shows whatever
-- skin.pickerSeen says. Refused while the addon is disabled (the dispatcher's gate), a gray line on
-- every call in combat (the library's), and the library-absent line without LibKa0s.
-- LibKa0sSkinTester e21689f is the reference.

local h = _G.KCM_TEST
local test = h.test

local function load()
    local KCM = h.loader.loadFullAddon()
    KCM.HideSkinPicker()
    return KCM, h.loader.mock
end

local function say(KCM, mock, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return table.concat(mock.output, "\n")
end

local function strings() return LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

--- The picker up on screen is this addon's (the library's one queue across every Ka0s addon).
local function upHere(KCM)
    local q = LibStub("LibKa0s-Options-1.0").__pickerQueue
    local UI = KCM.Settings.Helpers.instance
    return (q and q.current and q.current.inst == UI) and true or false
end

--- A profile that has closed the first-run picker, so only the verb can bring it back.
local function seenProfile()
    local KCM, mock = load()
    KCM.db.profile.skin.pickerSeen = true
    return KCM, mock
end

-- red under: no row, a row anywhere but after config, or help words of the addon's own.
test("Skin verb: the row sits right after config, with the library's help words", function(t)
    local KCM = load()
    local at
    for i, c in ipairs(KCM.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    t.truthy(at, "a skin row")
    t.eq(at and KCM.COMMANDS[at - 1][1], "config", "right after config")
    t.eq(at and KCM.COMMANDS[at][2], strings().VERB_HELP, "one wording for every host")
end)

-- red under: no skin row (the dispatcher answers "unknown command"), or a verb that reads pickerSeen.
test("Skin verb: /cm skin shows the picker on a profile that has closed it", function(t)
    local KCM, mock = seenProfile()
    t.falsy(upHere(KCM), "the first-run picker is down")
    local out = say(KCM, mock, "skin")
    t.truthy(upHere(KCM), "the picker is up")
    t.falsy(out:lower():find("unknown", 1, true), "a known verb: " .. out)
    t.eq(KCM.db.profile.skin.pickerSeen, true, "and showing it writes nothing")
    KCM.HideSkinPicker()
end)

-- red under: a verb that builds a spec of its own (the gear, the close and the seams would differ).
test("Skin verb: KCM.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function(t)
    local KCM = seenProfile()
    local UI = KCM.Settings.Helpers.instance
    local live, seen = UI.SkinVerb, nil
    UI.SkinVerb = function(spec) seen = spec; return nil, "queued" end
    local ok, win, why = pcall(KCM.RunSkinVerb)
    UI.SkinVerb = live
    t.truthy(ok, tostring(win))
    t.eq(seen and seen.owner, "ConsumableMaster", "the owner")
    t.truthy(seen and rawequal(seen.set, KCM.WriteSkinChoice), "the write seam")
    t.eq(seen and seen.page, "general", "the gear's page")
    t.eq(seen and seen.tab, "Appearance", "and tab")
    t.eq(win, nil, "nothing shown")
    t.eq(why, "queued", "the library's reason, passed on")
end)

-- red under: the host's own combat gate (a print once per combat, or silence).
test("Skin verb: in combat every call prints the library's gray line and shows nothing", function(t)
    local KCM, mock = seenProfile()
    mock.setCombat(true)
    local first = say(KCM, mock, "skin")
    local second = say(KCM, mock, "skin")
    mock.setCombat(false)
    t.falsy(upHere(KCM), "no picker mid-combat")
    t.truthy(first:find(strings().VERB_COMBAT, 1, true), "the first call says why: " .. first)
    t.truthy(second:find(strings().VERB_COMBAT, 1, true), "and so does every later one: " .. second)
end)

-- red under: `skin` on the live set (it would show a picker on a stood-down addon).
test("Skin verb: refused while the addon is disabled, and no picker shows", function(t)
    local KCM, mock = seenProfile()
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)
    local out = say(KCM, mock, "skin")
    t.truthy(out:find(KCM.SlashCommands.instance:DisabledLine(), 1, true), "the disabled line: " .. out)
    t.eq(select(2, out:gsub("\n", "")), 0, "exactly one line")
    t.falsy(upHere(KCM), "no picker")
    KCM.Settings.Helpers.SetAndRefresh("enabled", true)
end)

-- red under: a degraded arm with no row (unknown command) or one that raises on the stub's nil, "absent".
test("Skin verb: without LibKa0s the verb prints the library-absent line", function(t)
    local KCM, mock = h.loader.loadFullAddon(true), h.loader.mock
    t.falsy(LibStub("LibKa0s-Options-1.0", true), "the library really is absent")
    local out = say(KCM, mock, "skin")
    t.truthy(out:find("/cm skin is unavailable: the LibKa0s library did not load.", 1, true),
        "names the verb: " .. out)
    local win, why = KCM.RunSkinVerb()
    t.eq(win, nil, "nothing shown")
    t.eq(why, "absent", "the stub's reason")
end)
