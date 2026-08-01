-- test_slashsetup.lua — the addon's half of LibKa0s-Slash-1.0.
--
-- tests/test_slash.lua drives all 15 verbs through KCM:OnSlashCommand and reads
-- the emitted chat, and every one of those cases is deliberately left alone:
-- they were written against the host dispatcher and they are the oracle for the
-- swap. What this suite adds is the part they cannot see — that the dispatch is
-- coming from the library rather than from a host copy that happens to agree.

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadFullAddon()
    return KCM, h.loader.mock
end

test("Slash: the dispatcher IS the library's instance, not a host lookalike", function(t)
    local KCM = load()
    local lib = LibStub("LibKa0s-Slash-1.0")
    t.truthy(lib, "LibKa0s-Slash-1.0 registered")
    local Sl = KCM.SlashCommands.instance
    t.truthy(Sl and Sl.OnSlash and Sl.PrintHelp and Sl.HelpRows,
        "the instance is published for the suite to reach")
end)

test("Slash: /cm routes through the instance rather than a parallel path", function(t)
    local KCM = load()
    local Sl = KCM.SlashCommands.instance
    -- The identity case with teeth. Asserting on help TEXT would pass just as
    -- happily against a host dispatcher left in place, which is exactly what
    -- "the swap silently no-opped" looks like from the outside.
    local fired = 0
    local real = Sl.PrintHelp
    Sl.PrintHelp = function(self) fired = fired + 1; return real(self) end
    KCM:OnSlashCommand("")
    Sl.PrintHelp = real
    t.eq(fired, 1, "a bare /cm reaches the library's own help")
end)

test("Slash: the library reads the addon's live COMMANDS table, not a copy", function(t)
    local KCM = load()
    -- The library's contract is that the verb table is PASSED IN, not owned —
    -- which is what lets the About panel render the same table without that
    -- page depending on the slash library. Appending after load proves it, and
    -- would catch a future refactor that copied the table into the descriptor.
    local ran = 0
    KCM.COMMANDS[#KCM.COMMANDS + 1] = { "zzztest", "probe", function() ran = ran + 1 end }
    KCM:OnSlashCommand("zzztest")
    KCM.COMMANDS[#KCM.COMMANDS] = nil
    t.eq(ran, 1, "a verb added after load still dispatches")
end)

test("Slash: help rows are rendered by the library's own formatter", function(t)
    local KCM = load()
    local lib = LibStub("LibKa0s-Slash-1.0")
    local first = KCM.COMMANDS[1]
    t.eq(KCM.SlashCommands.instance:HelpRows()[1],
        "  " .. lib.FormatRow("/cm " .. first[1], first[2]),
        "the first help row is lib.FormatRow's output, indented")
end)

test("Slash: the addon's own shipped wording survives the library's strings", function(t)
    local KCM, mock = load()
    -- The regression guard on the L override. Drop that table and three
    -- user-visible strings silently change wording: the library's own header
    -- is a bare "v%s — slash commands" with no brand, its alias clause reads
    -- "(X is an alias for Y)", and its unknown-verb line is lowercase
    -- "unknown command 'x'".
    mock.output = {}
    KCM:OnSlashCommand("")
    local header = mock.output[1] or ""
    t.truthy(header:find("|cffffd100Ka0s Consumable Master|r", 1, true),
        "the header still carries the addon's gold brand")
    t.truthy(header:find(" (alias: |cffffff00/consumablemaster|r)", 1, true),
        "…and names the alias the way it always has")

    mock.output = {}
    KCM:OnSlashCommand("frobnicate")
    t.truthy((mock.output[1] or ""):find("Unknown command: |cffffff00frobnicate|r", 1, true),
        "the unknown-verb line keeps its capital U and its gold verb")
end)

test("Slash: the schema CLI is still the addon's, colors and enums intact", function(t)
    local KCM, mock = load()
    -- Deliberately NOT adopted (LIBKA0S-02): the library formats a color from
    -- { r =, g =, b =, a = } where this addon stores { r, g, b, a }
    -- positionally, and reads enum `values` as a key map where ours is an
    -- ordered array. Both would ship green — the color one because nothing
    -- asserts the rendered value, the enum one by regressing 6a92e63. These
    -- two assertions are what would go red the day someone wires them up.
    mock.output = {}
    KCM:OnSlashCommand("set macroBar.orientation sideways")
    local text = table.concat(mock.output, "\n")
    t.truthy(text:find("Allowed values: HORIZONTAL, VERTICAL", 1, true),
        "a bad enum still lists the real allowed values, not the array's 1, 2 keys")

    local color = KCM.Settings.Helpers.FindSchema("macroBar.barBackdropColor")
    t.truthy(color, "the color row exists")
    t.eq(KCM.FormatSchemaValue(color, { 0.25, 0.5, 0.75, 1 }), "{0.25, 0.50, 0.75, 1.00}",
        "colors still render from the addon's positional storage")
end)
