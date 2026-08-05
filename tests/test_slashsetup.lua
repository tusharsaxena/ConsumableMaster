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
    -- schema row, and bare they must say where the old behavior went. The
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
    -- Both would ship GREEN if they regressed — the color one because nothing else
    -- asserts a rendered color's value, the enum one by quietly restoring the clamp
    -- that commit 6a92e63 removed.
    mock.output = {}
    KCM:OnSlashCommand("set macroBar.orientation sideways")
    local text = table.concat(mock.output, "\n")
    t.truthy(text:lower():find("allowed values: horizontal, vertical", 1, true),
        "an ordered-array enum lists its real values, not the array's 1, 2 keys: " .. text)

    -- Round-trip a color: written through the codec into the addon's positional
    -- shape, and read back out of it for the echo.
    mock.output = {}
    KCM:OnSlashCommand("set macroBar.barBackdropColor 0.25 0.5 0.75 1")
    local stored = KCM.Settings.Helpers.Get("macroBar.barBackdropColor")
    t.truthy(type(stored) == "table" and stored[1], "stored positionally, as the widget writes it")
    t.eq(stored.r, nil, "and not in the library's named-key form")
    t.truthy(table.concat(mock.output, "\n"):find("{0.25, 0.50, 0.75, 1.00}", 1, true),
        "the echo renders it back through the same codec")
end)

-- ── the degraded path (CM-A-32, CM-R-03) ──────────────────────────────────
--
-- KCM:OnSlashCommand used to read `if not Sl then return printHelp() end`, so
-- with libs/LibKa0s/ absent all seventeen verbs collapsed into one
-- "/cm is unavailable" line — including the eleven that never touched the
-- library at all. Loaded for real with the libs omitted, so settings/Slash.lua
-- takes its own degraded arm rather than a hand-written stub (testing-§8).

local function loadDegraded()
    local KCM = h.loader.loadFullAddon(true)
    return KCM, h.loader.mock
end

-- The verbs slash-commands-§1 calls host-owned: they are implemented in this
-- addon and reach nothing in LibKa0s, so a degraded install must keep them.
local HOST_VERBS = {
    "config", "version", "debug", "resync", "rewritemacros", "resetall",
    "bar", "priority", "stat", "aio", "dump",
}

test("Slash: with the library absent every host-owned verb still dispatches", function(t)
    local KCM, mock = loadDegraded()
    t.falsy(LibStub("LibKa0s-Slash-1.0", true), "the major really is absent")

    -- Dispatch is proved by the verb BODY running, not by what it prints: two
    -- of these eleven print nothing on a fresh profile, and asserting on chat
    -- would let "it printed the unavailable line instead" hide behind that.
    --
    -- red under: restoring `if not Sl then return printHelp() end` — all eleven
    -- report fired = 0.
    for _, verb in ipairs(HOST_VERBS) do
        local entry
        for _, c in ipairs(KCM.COMMANDS) do
            if c[1] == verb then entry = c end
        end
        t.truthy(entry, verb .. " is in COMMANDS")

        local fired, real = 0, entry[3]
        entry[3] = function(rest) fired = fired + 1; return real(rest) end
        mock.output = {}
        local ok, err = pcall(function() KCM:OnSlashCommand(verb) end)
        entry[3] = real

        t.truthy(ok, "/cm " .. verb .. " does not raise: " .. tostring(err))
        t.eq(fired, 1, "/cm " .. verb .. " reaches its host body")
        t.falsy(table.concat(mock.output, "\n"):find("are unavailable", 1, true),
            "/cm " .. verb .. " is not answered with the degraded notice")
    end
end)

test("Slash: with the library absent only the five library-backed verbs degrade", function(t)
    local KCM, mock = loadDegraded()
    -- help/list/get/set/reset are the schema CLI plus the help renderer, and
    -- all five live in LibKa0s-Slash-1.0. They are the ones that must say so.
    --
    -- red under: dispatching them to a host re-implementation, or restoring the
    -- blanket printHelp (which takes the host verbs down with them).
    for _, verb in ipairs({ "help", "list", "get enabled", "set enabled false", "reset enabled" }) do
        mock.output = {}
        KCM:OnSlashCommand(verb)
        local text = table.concat(mock.output, "\n")
        t.truthy(text:find("help, list, get, set and reset are unavailable", 1, true),
            "/cm " .. verb .. " says which verbs are gone: " .. text)
    end

    -- And the same line names what survived, read off COMMANDS rather than
    -- hand-listed, so a new verb cannot fall out of it.
    mock.output = {}
    KCM:OnSlashCommand("list")
    local text = table.concat(mock.output, "\n")
    for _, verb in ipairs(HOST_VERBS) do
        t.truthy(text:find(verb, 1, true), "the notice names " .. verb .. ": " .. text)
    end
    t.falsy(text:find("perf", 1, true),
        "…and not perf, which needs LibKa0s-Perf to answer: " .. text)
end)

test("Slash: a bare /cm degrades without latching, and an unknown verb still reports", function(t)
    local KCM, mock = loadDegraded()
    -- A degraded install that explains itself once and then goes silent is
    -- worse than an error, so this must answer every time.
    --
    -- red under: guarding sayDegraded with an `announced` latch.
    for i = 1, 3 do
        mock.output = {}
        KCM:OnSlashCommand("")
        t.truthy(table.concat(mock.output, "\n"):find("are unavailable", 1, true),
            "bare /cm answers on invocation " .. i)
    end

    mock.output = {}
    KCM:OnSlashCommand("frobnicate")
    local text = table.concat(mock.output, "\n")
    t.truthy(text:lower():find("unknown command", 1, true),
        "an unknown verb is still named: " .. text)
end)

test("Slash: the degraded path keeps the library's parse — verb only is lowercased", function(t)
    local KCM = loadDegraded()
    -- The same typed line must mean the same thing either way, so the degraded
    -- split matches Sl:OnSlash's: lowercase the verb, leave `rest` alone.
    --
    -- red under: lowercasing the whole message, or dropping the alias map.
    local seen
    for _, c in ipairs(KCM.COMMANDS) do
        if c[1] == "dump" then
            local real = c[3]
            c[3] = function(rest) seen = rest; return real(rest) end
            KCM:OnSlashCommand("DuMp Item 241304")
            c[3] = real
        end
    end
    t.eq(seen, "Item 241304", "the verb is lowercased and the rest is not")

    local ran = 0
    for _, c in ipairs(KCM.COMMANDS) do
        if c[1] == "rewritemacros" then
            local real = c[3]
            c[3] = function(rest) ran = ran + 1; return real(rest) end
            KCM:OnSlashCommand("rewrite")
            c[3] = real
        end
    end
    t.eq(ran, 1, "/cm rewrite is still the back-compat alias for rewritemacros")
end)

test("Slash: the panel's degraded advice agrees with what /cm actually answers", function(t)
    -- CM-R-03. settings/Panel.lua used to end its notice with "every setting is
    -- still reachable with /cm list, /cm get and /cm set" — the three verbs
    -- that answer "unavailable" on exactly the path that notice fires on.
    --
    -- red under: restoring that sentence.
    local KCM, mock = loadDegraded()
    mock.output = {}
    KCM.Settings.Register()
    local advice = table.concat(mock.output, "\n")
    t.truthy(advice:find("settings panel is unavailable", 1, true),
        "the panel still says it is unavailable: " .. advice)

    for _, verb in ipairs({ "/cm list", "/cm get", "/cm set" }) do
        mock.output = {}
        KCM:OnSlashCommand(verb:sub(5))
        local answer = table.concat(mock.output, "\n")
        t.truthy(answer:find("are unavailable", 1, true),
            verb .. " answers unavailable")
        -- So the advice must not send the user at it as a way to reach a
        -- setting. Naming it as ALSO unavailable is what it does instead.
        t.truthy(advice:find("and so are /cm list, /cm get and /cm set", 1, true),
            "the advice names " .. verb .. " as unavailable rather than recommending it")
    end
end)
