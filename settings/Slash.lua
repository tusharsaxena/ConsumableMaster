-- Slash.lua — the /cm dispatcher: COMMANDS, the LibKa0s-Slash-1.0 instance,
-- the About-panel rows, and KCM:OnSlashCommand.
--
-- Split out of core/SlashCommands.lua for CM-47: slash-commands-§1 names
-- settings/Slash.lua as the place the dispatcher is wired, and core/ was also
-- the repo's largest file at 1408 LOC (advisory CM-54).
--
-- The division of labour across the two files:
--   * core/SlashCommands.lua owns the VERB BODIES — the priority / stat / aio /
--     bar namespaces, the dump targets, and their sub-command tables. It
--     publishes the five entry points on KCM.SlashCommands.Verbs and knows
--     nothing about how they are dispatched.
--   * this file owns the DISPATCH — the ordered COMMANDS table, the library
--     descriptor and instance, and the two public entry points the rest of the
--     addon calls (KCM.SlashCommands.GetLandingRows, KCM:OnSlashCommand).
--
-- Load order (layout-§1) puts settings/ after core/, so the verbs table exists
-- by the time COMMANDS is built. Nothing here is read at load time by anything
-- else: settings/Panel.lua calls GetLandingRows when it builds the About page,
-- and AceConsole resolves "OnSlashCommand" by name when a command is typed.

local _, NS = ...
local KCM = NS

-- Same secret-safe seam as the verb file (core/Constants.lua): the [CM] tag is
-- unconditional and a combat "secret" can never raise mid-line.
local say = KCM.Say

-- The verb bodies, owned by core/SlashCommands.lua. Resolved once here rather
-- than per call: settings/ loads after core/, so the table is already populated,
-- and a missing key would be a load-order bug worth failing loudly on.
local V = KCM.SlashCommands.Verbs

-- Addon version for the `version` verb and the help header. Read from the TOC
-- metadata (the packaged manifest) with the in-code constant as fallback, so it
-- can't drift from what actually shipped (slash-commands-§3). The ladder that
-- used to sit here is core/EnvSetup.lua's now -- one of two inline copies, and
-- the library's business rather than this file's.
local addonVersion = KCM.Version

-- ---------------------------------------------------------------------------
-- Schema-driven /cm list / get / set
-- ---------------------------------------------------------------------------
--
-- Every row in KCM.Settings.Schema (declared in settings/Panel.lua) automatically
-- gets `/cm get <path>` and `/cm set <path> <value>` for free, plus shows up
-- in `/cm list`. Adding a new scalar setting = one schema row.

local function helpers()
    return KCM.Settings and KCM.Settings.Helpers
end

-- Bound at the foot of this file, once the Slash instance exists.
local cliList, cliGet, cliSet, cliReset

-- ---------------------------------------------------------------------------
-- Top-level COMMANDS table + dispatcher
-- ---------------------------------------------------------------------------

local printHelp  -- forward decl (printed by COMMANDS[1].fn)

-- Backwards-compat: `/cm rewrite` → `/cm rewritemacros`. The original handler
-- accepted both spellings; this preserves that without bloating COMMANDS. Held
-- as a file local rather than inline in the library descriptor because the
-- degraded dispatcher at the foot of this file applies the same map, and two
-- alias tables for one addon is exactly the drift LIBKA0S-13 collapsed.
local ALIASES = { rewrite = "rewritemacros" }

-- The verbs that actually ROUTE THROUGH LibKa0s, and therefore stop answering
-- when it is absent (slash-commands-§1). `help` and the four schema CLI verbs
-- go to LibKa0s-Slash-1.0; `perf` goes to LibKa0s-Perf-1.0 by way of
-- core/PerfSetup.lua, which never publishes KCM.Perf on a build without it.
--
-- Every OTHER verb in COMMANDS is the host's own and keeps working, which is
-- the whole point: this table exists so the degraded notice can name what is
-- gone by reading COMMANDS rather than by repeating a hand-written list that a
-- new verb would silently fall out of. `perf` still DISPATCHES on the degraded
-- path — it answers "perf capture unavailable." itself — it is only kept off
-- the "these still work" half of the notice.
local LIB_BACKED_VERBS = {
    help = true, list = true, get = true, set = true, reset = true, perf = true,
}

local COMMANDS = {
    {"help",          "Show this help",
        function() printHelp() end},
    {"config",        "Open the settings panel",
        function()
            if not (KCM.Options and KCM.Options.Open and KCM.Options.Open()) then
                say("Settings panel unavailable.")
            end
        end},
    {"version",       "Print addon version",
        function() say("v" .. addonVersion()) end},
    {"perf",          "A/B performance capture — `/cm perf` opens the step panel",
        function(rest)
            -- Resolved at call time, exactly as `bar` does: on a build without
            -- LibKa0s-Perf, core/PerfSetup.lua never publishes KCM.Perf at all.
            -- (This file is in settings/, so PerfSetup loads long before it —
            -- the call-time resolve is about the degraded build, not order.)
            if not (KCM.Perf and KCM.Perf.OnCommand) then
                return say("perf capture unavailable.")
            end
            for _, line in ipairs(KCM.Perf.OnCommand(rest)) do say(line) end
        end},
    {"debug",         "Toggle the debug window; `on`/`off` set logging — `/cm debug [on|off]`",
        function(rest)
            local arg = (rest or ""):match("^(%S*)"):lower()
            local DL = KCM.DebugLog
            if arg == "on" or arg == "off" then
                -- DL.SetEnabled is the single seam: it owns the chat ack, the
                -- console transition line, and the options-panel refresh (§5).
                local want = (arg == "on")
                if DL and DL.SetEnabled then
                    DL.SetEnabled(want)
                    if want and DL.Show then DL.Show() end
                elseif KCM.State then
                    KCM.State.debug = want
                end
            else
                -- Bare `/cm debug` toggles the window only; the flag is untouched
                -- (debug-logging-§5), so capture can be armed independently.
                if DL and DL.Toggle_Window then
                    DL.Toggle_Window()
                else
                    say("Debug console unavailable.")
                end
            end
        end},
    {"resync",        "Force macros to resync from bags",
        function()
            if InCombatLockdown and InCombatLockdown() then
                say("in combat — picks computed now; macro writes will apply when combat ends.")
            end
            if KCM.TooltipCache and KCM.TooltipCache.InvalidateAll then
                KCM.TooltipCache.InvalidateAll()
            end
            if KCM.Pipeline and KCM.Pipeline.RunAutoDiscovery then
                local n = KCM.Pipeline.RunAutoDiscovery("manual_resync")
                say(("auto-discovery found %d new item(s)"):format(n))
            end
            if KCM.Pipeline and KCM.Pipeline.Recompute then
                KCM.Pipeline.Recompute("manual_resync")
                say("recomputed all categories.")
            end
        end},
    {"rewritemacros", "Force a full rewrite of every KCM macro (icon + body)",
        function()
            if InCombatLockdown and InCombatLockdown() then
                say("in combat — picks computed now; macro writes will apply when combat ends.")
            end
            if KCM.MacroManager and KCM.MacroManager.InvalidateState then
                KCM.MacroManager.InvalidateState()
            end
            if KCM.Pipeline and KCM.Pipeline.Recompute then
                KCM.Pipeline.Recompute("manual_rewrite")
                say("rewrote all macros (body + icon). If action bar icons still look stale, /reload to force the bars to refresh.")
            end
        end},
    -- BREAKING, 2026-08-01 (LIBKA0S-12, issue #27). `reset` used to be this pair's second
    -- entry — the confirm-gated global wipe. It is now the library's
    -- path-scoped reset, matching `/at reset <path>` and `/kcd reset <path>`,
    -- and the wipe moved down one row to `resetall` with its popup intact.
    -- A bare `/cm reset` cannot silently do the smaller thing: USAGE_RESET is
    -- overridden below to name `resetall` explicitly.
    {"reset",         "Reset ONE setting to its default — `/cm reset <path>`",
        function(rest) cliReset(rest) end},
    {"resetall",      "Reset every priority list and stat override to defaults (asks first)",
        function()
            if StaticPopup_Show then
                StaticPopup_Show("KCM_CONFIRM_RESET")
            else
                say("StaticPopup unavailable.")
            end
        end},
    {"list",          "List every schema setting and its current value",
        function() cliList() end},
    {"get",           "Print a setting's current value — `/cm get <path>`",
        function(rest) cliGet(rest) end},
    {"set",           "Set a setting — `/cm set <path> <value>` (try /cm list)",
        function(rest) cliSet(rest) end},
    {"bar",           "Macro bar — `/cm bar [on|off|lock|unlock|reset]` (bare toggles it)",
        function(rest) V.RunBar(rest) end},
    {"priority",      "Per-category priority list editor — try `/cm priority` for the list",
        function(rest) V.RunPriority(rest) end},
    {"stat",          "Per-spec stat priority editor — try `/cm stat` for the list",
        function(rest) V.RunStat(rest) end},
    {"aio",           "Composite-category editor (HP_AIO, MP_AIO) — try `/cm aio` for the list",
        function(rest) V.RunAIO(rest) end},
    {"dump",          "Dump internal state — try `/cm dump` for the list",
        function(rest) V.Dump(rest) end},
}

-- Publish the command table so the About panel and any future consumer read
-- the same source of truth as the /cm dispatcher (slash-commands-§4).
KCM.COMMANDS = COMMANDS

-- ---------------------------------------------------------------------
-- LibKa0s-Slash-1.0 — the dispatcher
-- ---------------------------------------------------------------------
--
-- Everything above is this addon's: seventeen verbs, five sub-command tables
-- with three different handler arities, the dump targets, and the schema CLI.
-- What the library takes is the part that is the same in every Ka0s addon —
-- trim, split, lowercase the verb only, apply the alias, find the entry, call
-- it; plus the help header and rows.
--
-- The COMMANDS table is PASSED IN, not owned. That is the library's own design
-- note and it matters here: KCM.SlashCommands.GetLandingRows below renders the
-- same table onto the About panel, and that page must not acquire a dependency
-- on the slash library to do it -- it asks THIS file, and this file asks the
-- library.
--
-- The schema CLI (Sl:CliList / CliGet / CliSet) IS adopted, since LIBKA0S-02 (issue #25)
-- fixed both blockers upstream: lib.FormatValue reads this addon's positional
-- { r, g, b, a } colors directly, and the enum reader takes the ordered
-- { value =, text = } array rather than the tostring'd keys of a map. The
-- codecs below are what keep a `/cm set` round-trip in the addon's own shape.

-- The strings whose wording the addon already shipped. A plain table,
-- deliberately NOT KCM.L: Sl:Text resolves through rawget precisely so a
-- key-echoing locale table falls through, which also means KCM.L could never
-- supply these.
local SLASH_STRINGS = {
    HELP_HEADER     = "|cffffd100Ka0s Consumable Master|r v%s \226\128\148 slash commands",
    -- The library passes (alias, slash); this addon has only ever named the
    -- alias, so the second is unused and string.format drops it.
    HELP_ALIAS      = " (alias: |cffffff00%s|r)",
    UNKNOWN_COMMAND = "Unknown command: |cffffff00%s|r",
    -- ONE %s, not two. Sl:CliGet formats this with (d.slash) alone, so a
    -- second placeholder is not "unused" the way HELP_ALIAS's is — it is a
    -- missing argument, and string.format RAISES on that. A bare `/cm get`
    -- threw a Lua error in game for exactly as long as this line had two.
    -- The hint therefore carries the command literally; it is the same "/cm"
    -- declared as `slash` twenty lines below.
    USAGE_GET       = "Usage: %s get <path>  (try /cm list)",
    -- The deprecation notice for LIBKA0S-12 (issue #27), and the only place a user who
    -- has `/cm reset` in a macro finds out the verb changed meaning. The
    -- library's stock line is a bare "Usage: %s reset <path>", which would let
    -- a global wipe quietly become a one-row reset. Same arity as the stock
    -- string — Sl:CliReset formats it with (d.slash) alone, so ONE %s, and
    -- `resetall` is spelled literally for the same reason USAGE_GET is.
    USAGE_RESET     = "Usage: %s reset <path> \226\128\148 this resets ONE setting. " ..
                      "The old global wipe is now |cffffff00/cm resetall|r, " ..
                      "which still asks before it wipes.",
    -- These three are DEAD and kept only as a record of the wording they were
    -- meant to restore. The parsers that emit them are lib-level (Slash.lua's
    -- parseBool / allowedText / parseColor sit above lib:New), so they read
    -- lib.STRINGS directly and never pass through Sl:Text — an instance
    -- override cannot reach them. Reported upstream rather than worked around
    -- here; see LIBKA0S-09 (issue #16).
    ERR_BOOL        = "expected true/false/on/off/1/0",
    ERR_ALLOWED     = "Allowed values: %s",
    ERR_COLOR       = "expected: r g b [a] (each 0-1 or 0-255)",
}

local slashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local Sl

if slashLib then
    Sl = slashLib:New({
        slash        = "/cm",
        -- Only [1] is ever named, in the help header's alias clause.
        slashAliases = { "/consumablemaster" },
        commands     = COMMANDS,
        aliases      = ALIASES,
        version      = addonVersion,
        -- A thunk, not `say` bare: the library snapshots the printer at :New.
        -- Same note as core/CoreSetup.lua's sink and core/DebugLogSetup.lua's
        -- print.
        print        = function(line) KCM.Say(line) end,
        L            = SLASH_STRINGS,

        -- The schema half. Every one of these resolves through KCM.Settings at
        -- CALL time: settings/Panel.lua loads long after this file, and the
        -- rows themselves are appended by the four page files after that.
        get          = function(path) local H = helpers(); return H and H.Get(path) end,
        set          = function(path, value)
            local H = helpers()
            if H then H.SetAndRefresh(path, value) end
        end,
        findRow      = function(path) local H = helpers(); return H and H.FindSchema(path) end,
        allRows      = function() return (KCM.Settings and KCM.Settings.Schema) or {} end,
        applyDefault = function(row)
            local H = helpers()
            if H and row.default ~= nil then H.SetAndRefresh(row.path, row.default) end
        end,
        -- Rows carry `panel`, not the library's default `page`.
        groupKey     = function(row) return row.panel or "?" end,

        -- Colors are stored POSITIONALLY here — { r, g, b, a } — which is what
        -- the Ka0s options color widget writes. The library reads that shape
        -- directly when rendering, but the codec is what makes a `/cm set`
        -- WRITE land in it rather than in the named-key form.
        colorDecode  = function(c)
            c = type(c) == "table" and c or {}
            return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
        end,
        colorEncode  = function(r, g, b, a) return { r, g, b, a or 1 } end,
    })
    -- The instance, so the suite can assert identity rather than lookalike
    -- behavior. Mirrors KCM.DebugLog.instance and Settings.Helpers.instance.
    KCM.SlashCommands.instance = Sl

    printHelp = function() Sl:PrintHelp() end
    cliList   = function() Sl:CliList() end
    cliGet    = function(rest) Sl:CliGet(rest) end
    cliSet    = function(rest) Sl:CliSet(rest) end
    -- Sl:CliReset only, never Sl:CliResetAll: the library's resetall walks the
    -- schema rows, and this addon's global reset is KCM.ResetAllToDefaults,
    -- which also wipes the priority lists and the stat overrides — data the
    -- schema does not describe. `/cm resetall` keeps the host body.
    cliReset  = function(rest) Sl:CliReset(rest) end
else
    -- LibKa0s is vendored, so this is a tampered install rather than a
    -- supported state. The dispatcher is still not re-implemented here — see
    -- degradedDispatch at the foot of this file, which is a verb lookup in
    -- COMMANDS and nothing else.
    --
    -- What degrades is exactly the half that WENT to the library. The old line
    -- said "/cm is unavailable", which was not true of eleven of the seventeen
    -- verbs and told the user to stop typing commands that worked.
    local function sayDegraded()
        local live = {}
        for _, entry in ipairs(COMMANDS) do
            if not LIB_BACKED_VERBS[entry[1]] then live[#live + 1] = entry[1] end
        end
        say((KCM.LIBKA0S_MISSING or "The LibKa0s library is missing") ..
            ", so /cm help, list, get, set and reset are unavailable. " ..
            "These still work: " .. table.concat(live, ", ") .. ".")
    end
    -- Not latched: a degraded install that explains itself once and then goes
    -- silent is worse than one that answers every time (options-ui-§1's sibling
    -- rule for the panel seam is the said-once one, and it is said-once because
    -- it fires unprompted; this one only ever fires because the user typed).
    printHelp = sayDegraded
    cliList, cliGet, cliSet, cliReset = sayDegraded, sayDegraded, sayDegraded, sayDegraded
end

-- The About panel's command rows, RENDERED -- convergence #2 (LIBKA0S-13).
--
-- The panel used to format these itself, with two spaces either side of the em
-- dash, the dash white-wrapped and the description bare, while the chat half
-- had already moved to lib.FormatRow. Two formatters for one table of data
-- inside one addon is exactly the drift the convergence exists to collapse --
-- and it survived this long because the panel reaches its rows through THIS
-- file rather than by naming COMMANDS, so a grep for the obvious name never
-- saw it.
--
-- It sits behind this function rather than settings/Panel.lua calling Sl
-- directly: the panel talks to this module, this module talks to the library.
-- That is the seam the rest of the addon already uses, and it keeps the About
-- page free of a LibKa0s lookup of its own -- which is what the note above
-- lib:New asks for.
--
-- This REPLACED a GetCommandSummary() that handed back the unrendered
-- { name =, desc = } view. Keeping both was the plan for about a day; the data
-- view had no caller left in the addon once the panel stopped formatting rows
-- itself, and an export with no caller is the next person's invitation to
-- format a command row somewhere new. The suite reads the rendered rows now,
-- which is what ships.
--
-- Empty rather than a host-formatted fallback when the library is absent: with
-- LibKa0s missing the settings panel is not registered at all
-- (settings/Panel.lua, registerPanel), so there is no About page to render into
-- and a second formatter kept alive "just in case" would be the divergence
-- coming straight back.
function KCM.SlashCommands.GetLandingRows()
    if not Sl then return {} end
    return Sl:LandingRows()
end

-- The degraded dispatcher (slash-commands-§1, CM-A-32).
--
-- `if not Sl then return printHelp() end` used to stand in for the whole of
-- OnSlash, so with libs/LibKa0s/ absent every one of the seventeen verbs — all
-- eleven of which are the host's own and never touched the library — answered
-- one "unavailable" line. A stub that blacks out the whole command surface is
-- non-compliant: the host verbs keep working, so they must keep answering.
--
-- Deliberately NOT a second dispatcher: no help renderer, no sub-command
-- tables, no landing rows. It trims, splits, lowercases the verb, applies the
-- one alias and looks the verb up in COMMANDS — the same five steps the
-- library's own OnSlash takes, because doing fewer would change what the same
-- typed line means depending on whether the library loaded.
local function degradedDispatch(msg)
    local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
    if raw == "" then return printHelp() end

    -- Only the verb is lowercased. `rest` keeps its case because schema paths
    -- are case-sensitive, and its internal spacing because a color is several
    -- tokens. Same split as the library's.
    local cmd, rest = raw:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    cmd = ALIASES[cmd] or cmd

    for _, entry in ipairs(COMMANDS) do
        if entry[1] == cmd then return entry[3](rest or "") end
    end

    say(SLASH_STRINGS.UNKNOWN_COMMAND:format(cmd))
    return printHelp()
end

function KCM:OnSlashCommand(msg)
    if not Sl then return degradedDispatch(msg) end
    return Sl:OnSlash(msg)
end
