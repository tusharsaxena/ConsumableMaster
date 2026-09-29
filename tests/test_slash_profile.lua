-- tests/test_slash_profile.lua -- `/cm profile`, the host half of LibKa0s-Slash-1.0
-- minor 17's shared profile verb.
--
-- The library owns what the verb does (the list, the switch, the refusals, the
-- quote stripping) and pins it in its own suite. What this addon owns is the row,
-- where it sits, the descriptor's `profiles` field and what a switch reaches once
-- AceDB has made it: the profile handler in core/ConsumableMaster.lua, which logs
-- the one [Profile] line (debug-logging-§10), re-reads the stand-down latch and
-- repaints. So these cases drive `/cm profile` end to end through
-- KCM:OnSlashCommand against the real AceDB fake and read the store, the chat and
-- the debug console, rather than re-testing the library's branches one by one.
--
-- The disabled-state pin is tests/test_disabled.lua's (Disabled 7f), and the
-- library-absent arm is tests/test_slash_degraded.lua's.

local h = _G.KCM_TEST
local test = h.test

local DESCRIPTION = "List profiles, or switch to one: profile <name>"

local function load()
    local KCM = h.loader.loadFullAddon()
    return KCM, h.loader.mock
end

--- The lines one `/cm` line printed.
local function run(KCM, mock, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return mock.output
end

--- The same lines with the [CM] tag taken off, which every one must carry.
local function bodies(KCM, t, out)
    local stripped = {}
    for i, line in ipairs(out) do
        local tag = KCM.PREFIX .. " "
        t.eq(line:sub(1, #tag), tag, "line " .. i .. " carries the [CM] tag: " .. line)
        stripped[i] = line:sub(#tag + 1)
    end
    return stripped
end

local function profileNames(KCM)
    local names = {}
    for name in pairs(KCM.db.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

--- The [Profile] lines in the debug console.
local function profileLines(KCM)
    local out = {}
    for _, line in ipairs(KCM.DebugLog.instance.buffer) do
        local body = line:match("%[Profile%] (.*)$")
        if body then out[#out + 1] = body end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------

-- red under: the row missing, renamed, reworded, or moved out of the settings verbs.
test("/cm profile: the row sits after set, closing the settings verbs", function(t)
    local KCM = load()
    local at = {}
    for i, entry in ipairs(KCM.COMMANDS) do at[entry[1]] = i end
    t.truthy(at.profile, "profile is in COMMANDS")
    t.eq(at.profile, at.set + 1, "it follows set")
    t.eq(KCM.COMMANDS[at.profile + 1][1], "bar", "and the feature verbs start after it")
    t.eq(#KCM.COMMANDS, 23, "twenty-three verbs")
    t.eq(KCM.COMMANDS[at.profile][2], DESCRIPTION, "the collection's description, word for word")
end)

-- red under: a help index or About page that drops or re-renders the row.
test("/cm profile: help and the About page both list it through the library's formatter", function(t)
    local KCM, mock = load()
    local lib = LibStub("LibKa0s-Slash-1.0")
    local row = lib.FormatRow("/cm profile", DESCRIPTION)
    local help = table.concat(run(KCM, mock, "help"), "\n")
    t.truthy(help:find(row, 1, true), "/cm help prints the row: " .. help)
    local found = false
    for _, landing in ipairs(KCM.SlashCommands.GetLandingRows()) do
        if landing == row then found = true end
    end
    t.truthy(found, "the About page carries the same row")
end)

-- ---------------------------------------------------------------------------
-- The verb
-- ---------------------------------------------------------------------------

-- red under: no `profiles` on the descriptor (every call answers "Profiles are not
-- available."), or a descriptor handing over anything but the live db.
test("/cm profile: bare lists every profile, current marked, then the hint", function(t)
    local KCM, mock = load()
    KCM.db:SetProfile("main")
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    local out = bodies(KCM, t, run(KCM, mock, "profile"))
    t.eqList(out, {
        "|cff33ff99Profiles|r",
        "  Alt",
        "  Default (current)",
        "  main",
        "/cm profile <name> switches profile",
    }, "the header, the rows sorted case-insensitively, the hint")
    t.eq(KCM.db:GetCurrentProfile(), "Default", "listing switches nothing")
end)

-- red under: a switch that bypasses AceDB (no handler, no [Profile] line), or a
-- verb that logs a line of its own beside the handler's.
test("/cm profile <name>: switches to an existing profile and the handler runs", function(t)
    local KCM, mock = load()
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    local changed = 0
    local listener = KCM.NewBusTarget()
    listener:RegisterMessage(KCM.MSG.PROFILE_CHANGED, function() changed = changed + 1 end)
    KCM.State.debug = true
    KCM.DebugLog.instance:Clear()

    local out = bodies(KCM, t, run(KCM, mock, "profile Alt"))
    KCM.State.debug = false
    t.eqList(out, { "Switched to profile 'Alt'." }, "one line in chat")
    t.eq(KCM.db:GetCurrentProfile(), "Alt", "AceDB switched")
    t.eq(changed, 1, "the profile handler published PROFILE_CHANGED")
    t.eqList(profileLines(KCM), { "switched to 'Alt'" },
        "and logged its one [Profile] line, with nothing from the verb beside it")
end)

-- red under: a verb that calls SetProfile for any name (AceDB creates what it is handed).
test("/cm profile <name>: an unknown name is refused and no profile is created", function(t)
    local KCM, mock = load()
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    local before = profileNames(KCM)

    local out = bodies(KCM, t, run(KCM, mock, "profile Nope"))
    t.eq(out[1], "No profile named 'Nope'.", "the refusal names what was typed")
    t.eq(out[2], "|cff33ff99Profiles|r", "then the list")
    t.eq(KCM.db:GetCurrentProfile(), "Default", "nothing switched")
    t.eqList(profileNames(KCM), before, "and nothing was created")

    out = bodies(KCM, t, run(KCM, mock, "profile alt"))
    t.eqList({ out[1], out[2] }, { "No profile named 'alt'.", "Did you mean 'Alt'?" },
        "a case slip is refused too, with the one near match offered")
    t.eqList(profileNames(KCM), before, "still nothing created")
end)

-- red under: a verb that takes the first word only, folds case, or keeps the quotes.
test("/cm profile \"name\": quotes are stripped, case and inner spaces kept", function(t)
    local KCM, mock = load()
    KCM.db:SetProfile("My Main")
    KCM.db:SetProfile("Default")

    local out = bodies(KCM, t, run(KCM, mock, "profile \"My Main\""))
    t.eqList(out, { "Switched to profile 'My Main'." }, "double quotes")
    t.eq(KCM.db:GetCurrentProfile(), "My Main", "switched to the spaced name")

    KCM.db:SetProfile("Default")
    out = bodies(KCM, t, run(KCM, mock, "PROFILE   'My Main'  "))
    t.eqList(out, { "Switched to profile 'My Main'." }, "single quotes, the verb in any case")

    out = bodies(KCM, t, run(KCM, mock, "profile My Main"))
    t.eqList(out, { "Already on profile 'My Main'." }, "unquoted, the whole rest is the name")
end)

-- red under: a switch that ignores InCombatLockdown.
test("/cm profile <name>: refused in combat, and the list still answers", function(t)
    local KCM, mock = load()
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    mock.setCombat(true)
    local out = bodies(KCM, t, run(KCM, mock, "profile Alt"))
    local listed = bodies(KCM, t, run(KCM, mock, "profile"))
    mock.setCombat(false)
    t.eqList(out, { "Can't switch profiles in combat." }, "the combat refusal, alone")
    t.eq(KCM.db:GetCurrentProfile(), "Default", "nothing switched")
    t.eq(listed[1], "|cff33ff99Profiles|r", "the bare list is not a switch and still answers")
end)

-- red under: no line at all for a same-name switch (AceDB's own SetProfile is silent).
test("/cm profile <name>: the current profile answers that it already is", function(t)
    local KCM, mock = load()
    local out = bodies(KCM, t, run(KCM, mock, "profile Default"))
    t.eqList(out, { "Already on profile 'Default'." }, "one line")
end)

-- The degraded-arm pair the Slash parity case pins (tests/test_surface_parity.lua):
-- on the live arm both members reach the library instance.
--
-- red under: publishing either member bound to the library-absent line on a live load.
test("/cm profile: the published CliProfile and ProfileSwitch reach the library", function(t)
    local KCM, mock = load()
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    mock.output = {}
    t.eq(KCM.SlashCommands.ProfileSwitch("Alt"), true, "ProfileSwitch answers true when it switched")
    t.eq(KCM.db:GetCurrentProfile(), "Alt", "and it did")
    mock.output = {}
    KCM.SlashCommands.CliProfile("")
    local out = bodies(KCM, t, mock.output)
    t.eq(out[1], "|cff33ff99Profiles|r", "CliProfile lists")
end)
