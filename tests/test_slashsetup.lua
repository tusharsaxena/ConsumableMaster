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

test("Slash: the About panel's rows go through the SAME formatter, un-indented", function(t)
    -- Convergence #2 (LIBKA0S-13). The case above pinned the chat half from the
    -- day of the adoption; the panel half kept its own format string for
    -- another release, because settings/Panel.lua reaches these rows through
    -- GetLandingRows rather than by naming COMMANDS, so nothing that grepped
    -- for the obvious name ever saw the second formatter. This is the other
    -- half of that pin: two formatters for one table cannot come back without
    -- a red case.
    local KCM = load()
    local lib = LibStub("LibKa0s-Slash-1.0")
    local rows = KCM.SlashCommands.GetLandingRows()
    t.eq(#rows, #KCM.COMMANDS, "one rendered row per command")
    local first = KCM.COMMANDS[1]
    t.eq(rows[1], lib.FormatRow("/cm " .. first[1], first[2]),
        "the panel row is lib.FormatRow's output with no indent")
    -- ...and the two halves differ ONLY by the chat indent, which is exactly
    -- what the convergence claims.
    t.eq("  " .. rows[1], KCM.SlashCommands.instance:HelpRows()[1],
        "chat and panel render one string, differing only by the leading indent")
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

test("Slash: every rendered string resolves to prose, not to its own key", function(t)
    local KCM = load()
    local Sl = KCM.SlashCommands.instance
    -- The L trap. `L = SLASH_STRINGS` in core/SlashCommands.lua is a plain
    -- table of literals; hand that field KCM.L -- or, the form the current
    -- library cannot defend against, a plain table whose values were read OUT
    -- of KCM.L by library key -- and every string here renders as its own
    -- SCREAMING_SNAKE key. It fails for all of them at once and only in game.
    --
    -- Asserted on what the instance actually rendered, and deliberately NOT
    -- guarded on `if header then`: a renamed accessor has to fail here rather
    -- than pass with nothing checked.
    local header = Sl:HelpHeader()
    t.falsy(header:match("^[A-Z][A-Z0-9_]+$"),
        "the help header resolved to prose, not to its own key: " .. header)

    -- The other side of the same seam. LIST_HEADER is the library's own
    -- string, which SLASH_STRINGS deliberately does not override, so this one
    -- still fires when the override table itself is intact and the resolver
    -- behind it is not.
    local listHeader = Sl:BuildListLines()[1]
    t.falsy(listHeader:match("^[A-Z][A-Z0-9_]+$"),
        "the settings-list header resolved to prose, not to its own key: " .. listHeader)
end)

test("Slash: a bare /cm get answers with its usage line rather than raising", function(t)
    local KCM, mock = load()
    -- Sl:CliGet formats USAGE_GET with (d.slash) alone. This addon's override
    -- carried two %s for one argument, and string.format RAISES on the second
    -- -- so the one verb a user reaches for when they do not know the path
    -- threw a Lua error. Nothing else in the suite calls the verb with no
    -- argument, which is why it shipped.
    mock.output = {}
    local ok, err = pcall(function() KCM:OnSlashCommand("get") end)
    t.truthy(ok, "the verb answers instead of erroring: " .. tostring(err))
    local text = table.concat(mock.output, "\n")
    t.truthy(text:find("Usage: /cm get <path>", 1, true),
        "…and names the command it is the usage for: " .. text)
end)

test("Slash: a bare /cm reset points at /cm resetall rather than wiping", function(t)
    local KCM, mock = load()
    -- The break notice for LIBKA0S-12. Anyone with `/cm reset` in a macro was
    -- triggering a confirm-gated global wipe; the same keystrokes now reset one
    -- schema row, and bare they must say where the old behaviour went. The
    -- library's stock USAGE_RESET is "Usage: %s reset <path>" and says nothing
    -- about resetall, so an override dropped here regresses silently.
    mock.output = {}
    local shown
    local saved = _G.StaticPopup_Show
    _G.StaticPopup_Show = function(which) shown = which end
    local ok, err = pcall(function() KCM:OnSlashCommand("reset") end)
    _G.StaticPopup_Show = saved
    t.truthy(ok, "the verb answers instead of erroring: " .. tostring(err))
    t.eq(shown, nil, "a bare /cm reset no longer reaches the destructive popup")

    local text = table.concat(mock.output, "\n")
    t.truthy(text:find("/cm reset <path>", 1, true),
        "it states the new, path-scoped shape: " .. text)
    t.truthy(text:find("/cm resetall", 1, true),
        "…and names the verb that kept the global wipe: " .. text)
end)

test("Slash: the schema CLI reads the addon's shapes through the library", function(t)
    local KCM, mock = load()
    -- The two shapes that blocked this adoption until LIBKA0S-02 fixed them upstream.
    -- Both would ship GREEN if they regressed — the colour one because nothing else
    -- asserts a rendered colour's value, the enum one by quietly restoring the clamp
    -- that commit 6a92e63 removed.
    mock.output = {}
    KCM:OnSlashCommand("set macroBar.orientation sideways")
    local text = table.concat(mock.output, "\n")
    t.truthy(text:lower():find("allowed values: horizontal, vertical", 1, true),
        "an ordered-array enum lists its real values, not the array's 1, 2 keys: " .. text)

    -- Round-trip a colour: written through the codec into the addon's positional
    -- shape, and read back out of it for the echo.
    mock.output = {}
    KCM:OnSlashCommand("set macroBar.barBackdropColor 0.25 0.5 0.75 1")
    local stored = KCM.Settings.Helpers.Get("macroBar.barBackdropColor")
    t.truthy(type(stored) == "table" and stored[1], "stored positionally, as the widget writes it")
    t.eq(stored.r, nil, "and not in the library's named-key form")
    t.truthy(table.concat(mock.output, "\n"):find("{0.25, 0.50, 0.75, 1.00}", 1, true),
        "the echo renders it back through the same codec")
end)
