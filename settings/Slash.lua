-- Slash.lua — the /cm dispatcher: COMMANDS, the LibKa0s-Slash-1.0 instance,
-- the About-panel rows, and KCM:OnSlashCommand.
--
-- Split out of core/SlashCommands.lua for CM-47: slash-commands-§1 names
-- settings/Slash.lua as the place the dispatcher is wired, and core/ was also
-- the repo's largest file at 1408 LOC (advisory CM-54).
--
-- The division of labor across the two files:
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

-- Same secret-safe seam as the verb file (KCM.Say, defined in
-- core/CoreSetup.lua): the [CM] tag is unconditional and a combat "secret" can never raise mid-line.
local say = KCM.Say

-- The locale seam (localization-§1) is no longer reached from this file. The one
-- string that went through it was the disabled-verb refusal, and that line is the
-- LIBRARY's now: slash-commands-§7 fixes one shape collection-wide and forbids
-- re-spelling it per addon, so an `L` override could only ever make this addon's
-- copy disagree with the other ten. The rest of the `/cm` surface is the CLI
-- SURFACE residue tests/test_locale.lua registers, which is one decision about the
-- whole command listing rather than a string-by-string one.

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

-- The LibKa0s-Schema-1.0 instance settings/Panel.lua builds (or its stub).
local function schema()
    local H = helpers()
    return H and H.schema
end

-- Bound at the foot of this file, once the Slash instance exists.
local cliList, cliGet, cliSet, cliReset

-- ---------------------------------------------------------------------------
-- Top-level COMMANDS table + dispatcher
-- ---------------------------------------------------------------------------

local printHelp  -- forward decl (printed by COMMANDS[1].fn)

-- ---------------------------------------------------------------------------
-- `enable` / `disable` — ALIASES for the Enable row, never a second switch
-- ---------------------------------------------------------------------------
--
-- slash-commands-§2 reserves both verbs across the collection and fixes what
-- they mean: they write the SAME stored path the addon-wide `Enable Consumable
-- Master` checkbox writes — the first row of General → Master controls
-- (options-ui-§15) — through the SAME single write seam. They hold no state of
-- their own: no second key, no session flag, no `KCM.enabled` local. That is the
-- whole rule, and it is why this is four lines rather than a feature: the
-- checkbox and the verbs cannot show the player two different answers, and the
-- row's own apply (settings/General.lua's KCM.OnEnabledChanged call) runs
-- whichever surface was used. That row says nothing itself (CM-R-12): the
-- `enabled = <bool>` echo below is the verbs' one reply.
--
-- THE WRITE IS THE HOST'S, not the library's CliSet, and the difference is the
-- DISABLED state slash-commands-§2 is actually about. Routing it through `Sl:CliSet` would have
-- made `enable` a LIB_BACKED_VERB alongside list / get / set / reset, and the
-- degraded notice at the foot of this file would then be telling a player who
-- had just disabled the addon that the verb which turns it back on is one of the
-- unavailable ones. The write goes to the host seam instead; the canonical
-- `path = value` echo (slash-commands-§5) is the library's, taken from the one
-- shared formatter `list` / `get` / `set` / `reset` all use so `/cm enable`
-- cannot drift from `/cm set enabled true`.
--
-- THE LIBRARY-ABSENT BUILD TAKES ROUTE (b) (options-ui-§1, WS-02; CM-18). On a
-- build with `libs/LibKa0s/` missing there is no `enabled` ROW -- the Master
-- controls block is composed by the library and its degradation stub emits
-- nothing (settings/OptionsSetup.lua) -- and there is no Lifecycle latch either
-- (core/LifecycleSetup.lua returns early), so a stored `enabled` would not be
-- obeyed this session. Route (a), a `writeThrough` path on the seam, would store
-- the switch and acknowledge it, which is acknowledging a switch nothing honors.
-- So the verb refuses on the one library-absent line, `/cm enable is
-- unavailable: the LibKa0s library did not load.`, writes nothing and raises
-- nothing. options-ui-§1 SHOULDs route (a) for this pair, so taking (b) is a
-- recorded deviation (docs/ARCHITECTURE.md, Documented deviations).
local ENABLED_PATH = "enabled"

-- The line's one owner is core/SlashCommands.lua, which says it for the macro
-- bar's composed-row verbs too.
local refuseLibraryAbsent = KCM.SlashCommands.SayLibraryAbsent

-- Bound beside cliGet on the live arm. Unreachable on the degraded one -- the
-- guard below returns before it, because a build with no schema row is the same
-- build with no Sl.
local echoEnabled

local function setEnabled(on)
    local H = helpers()
    if not (H and H.FindSchema and H.FindSchema(ENABLED_PATH)) then
        return refuseLibraryAbsent(on and "enable" or "disable")
    end
    -- SetAndRefresh reports its own refusal; a false here is not a second
    -- failure to announce.
    if H.SetAndRefresh(ENABLED_PATH, on and true or false) and echoEnabled then
        echoEnabled()
    end
end

-- Published beside the verbs core/SlashCommands.lua owns, for ONE other caller:
-- the launcher menu's *Enabled* entry (core/LauncherSetup.lua's setEnabled,
-- launcher-§2), which is `/cm enable` / `/cm disable` with a mouse and so runs
-- this body rather than a second copy of the write and the echo.
V.SetEnabled = setEnabled

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
-- new verb would silently fall out of. `perf` and `diagnostics` still DISPATCH
-- on the degraded path — `perf` answers "perf capture unavailable." itself and
-- `diagnostics` reaches core/DebugLogSetup.lua's stub, which says the report is
-- unavailable — they are only kept off the "these still work" half of the notice.
local LIB_BACKED_VERBS = {
    help = true, list = true, get = true, set = true, reset = true, perf = true,
    diagnostics = true,
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
    {"enable",        "Turn the addon on — the same switch as the Enable checkbox",
        function() setEnabled(true) end},
    {"disable",       "Turn the addon off — `/cm enable` turns it back on",
        function() setEnabled(false) end},
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
    {"debug",         "Toggle the debug window; `on`/`off` set logging — `/cm debug [on|off|diagnostics]`",
        function(rest)
            local arg = (rest or ""):match("^(%S*)"):lower()
            local DL = KCM.DebugLog
            -- `diagnostics` is tested FIRST, in any case, before on/off and before the
            -- window toggle (debug-logging-§14). It is the report's one other spelling;
            -- `diag`, `dump` and every other word fall through to the toggle below, as
            -- any unknown word does. No short alias exists or may (slash-commands-§2).
            if arg == "diagnostics" then
                DL.RunDiagnostics()
            elseif arg == "on" or arg == "off" then
                -- DL.SetEnabled is the single seam: it owns the chat ack, the
                -- console transition line, and the options-panel refresh (debug-logging-§5).
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
    -- The diagnostics report (debug-logging-§14): appended to the debug console after
    -- whatever trace is there, never gated on the logging flag, and on LIVE_VERBS below
    -- so it answers while the addon is disabled. The sections are core/Diagnostics.lua's;
    -- on a library-absent build core/DebugLogSetup.lua's stub says the report cannot run.
    {"diagnostics",   "Write a diagnostics report to the debug console, for a bug report",
        function() KCM.DebugLog.RunDiagnostics() end},
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
    {"resetall",      "Reset this profile to the addon's defaults — every setting and list (asks first)",
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
    -- THE CANONICAL SPELLING OF THE LOCK, and `/cm bar lock|unlock` is kept beside
    -- it rather than retired: `/pfe lock` and `/pfe unlock` are what the rest of the
    -- collection answers to, and `/cm unlock` is what a player reaches for after
    -- reading the bar's tooltip. Both spellings share one body (V.RunLock), so this
    -- is a second door onto the same room and not a second implementation.
    --
    -- Deliberately NOT in LIVE_VERBS below: they drive what the addon draws, so a
    -- disabled addon refuses them on the dispatcher's one line instead of moving a
    -- bar the player cannot see.
    {"lock",          "Lock the macro bar in place",
        function() V.RunLock(true) end},
    {"unlock",        "Unlock the macro bar so it can be dragged",
        function() V.RunLock(false) end},
    {"priority",      "Per-category priority list editor — try `/cm priority` for the list",
        function(rest) V.RunPriority(rest) end},
    {"stat",          "Per-spec stat priority editor — try `/cm stat` for the list",
        function(rest) V.RunStat(rest) end},
    {"aio",           "Composite-category editor (HP_AIO, MP_AIO) — try `/cm aio` for the list",
        function(rest) V.RunAIO(rest) end},
    {"dump",          "Dump internal state — try `/cm dump` for the list",
        function(rest) V.Dump(rest) end},
}

-- ---------------------------------------------------------------------------
-- The disabled state: a feature verb refuses, ONCE, in one place
-- ---------------------------------------------------------------------------
--
-- slash-commands-§2: a verb that DRIVES THE ADDON'S FEATURES answers, while
-- `enabled` is false, on ONE tagged line naming `/cm enable`, and does nothing
-- else -- acting, or a silent no-op, both leave the player with no clue why.
--
-- The gate is LibKa0s-Slash-1.0's (see "THE GATE IS THE LIBRARY'S NOW" below),
-- so a verb is gated unless its name is in the live set below, which is the
-- direction an omission should fail in. It covers the library's OnSlash only:
-- degradedDispatch, the library-absent arm at the foot of this file, has no gate.
--
-- THE LIVE SET, NAMED ONCE AS DATA. slash-commands-§2 fixes thirteen of these, and
-- the reasoning is that a player must be able to READ AND REPAIR SETTINGS and to
-- REACH THE PANEL while the addon is off -- which is precisely when they are most
-- likely to need to -- and `enable` above all, or the pair is one-way. `debug`,
-- `perf` and `diagnostics` are diagnostics rather than features: the usual reason
-- to reach for any of them is that the addon is misbehaving. `diagnostics` joined
-- the set with Slash minor 16 (LibKa0s v1.60.0, debug-logging-§14); a literal
-- array does not inherit the library's default, so it is added here by hand.
--
-- `dump` IS THIS ADDON'S FOURTEENTH, and it is a judgment rather than a quote.
-- It is read-only by construction -- core/SlashDump.lua's five targets print what
-- they find and write nothing, recompute nothing and invalidate nothing -- so it
-- does not drive a feature; it reports on one, which is what `debug` and `perf`
-- are live for. Refusing it would take the diagnostic away at the one moment
-- somebody is asking why the addon is quiet.
--
-- THE SET IS AN ARRAY BECAUSE IT IS HANDED TO THE LIBRARY as the descriptor's
-- `liveVerbs` (Slash minor 13). Passing it WIDENS lib.LIVE_VERBS by this addon's
-- one extra verb; it must never be used to NARROW it. v2.56.0 of the standard cut
-- the disabled surface to `enable` and `help`, the owner tested that and reversed
-- it at v2.57.0 -- `/cm` on a disabled addon answered with a refusal instead of
-- opening the settings panel, which is the one surface a player uses to switch it
-- back on by hand. Every reserved verb answers here, and the bare `/cm` opens the
-- panel exactly as it does when the addon is running.
local LIVE_VERBS = {
    "help", "config", "version", "enable", "disable", "debug",
    "perf", "diagnostics", "get", "set", "list", "reset", "resetall",
    "dump",
}

-- Read through the same seam the checkbox and `/cm get enabled` read, never a
-- local of its own (slash-commands-§2's "no state of their own"): Helpers.Get
-- resolves `enabled` out of db.profile whether or not a schema row exists, so
-- this answers on the degraded arm too. A nil -- no db yet -- reads as ENABLED,
-- matching core/ConsumableMaster.lua's `enabled == false` test, because the
-- addon's default is on and a verb typed before login should not be refused.
local function addonEnabled()
    local H = helpers()
    return not (H and H.Get(ENABLED_PATH) == false)
end

-- THE GATE IS THE LIBRARY'S NOW, and the wrap that used to sit here is gone.
--
-- It was written against Slash minor 11, which had no gate at all, and it did the
-- job: it refused at the table rather than in six verb bodies, and it covered both
-- dispatch arms. Minor 12 added the gate and minor 13 settled its shape, so
-- keeping the wrap would be a second gate beside it -- and the two would then have
-- to agree about which verbs are live and about how the refusal is worded, which
-- is the drift the shared dispatcher exists to end. `isEnabled`, `brandName` and
-- `liveVerbs` on the descriptor below are the whole of the host's half.
--
-- WHAT MOVED WITH IT IS THE WORDING. This addon printed its own sentence --
-- `disabled — /cm enable turns it back on`. slash-commands-§7 fixes one shape
-- collection-wide, built by `cli:DisabledLine()` from the brand name, and says it
-- MUST NOT be re-spelled per addon, per verb or per call site. So the line is the
-- library's. (The launcher stopped printing it at LibKa0s v1.58.0: its menu grays
-- the feature entries while disabled instead of refusing, launcher-§2.)
--
-- The `L` seam went with the string, which is the right answer rather than a loss:
-- the line is the collection's, not this addon's, and the library's own note says
-- an `L` override does not reach it.

-- Publish the command table so the About panel and any future consumer read
-- the same source of truth as the /cm dispatcher (slash-commands-§4).
KCM.COMMANDS = COMMANDS

-- ---------------------------------------------------------------------
-- LibKa0s-Slash-1.0 — the dispatcher
-- ---------------------------------------------------------------------
--
-- Everything above is this addon's: twenty-two verbs, five sub-command tables
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

-- The whole-value rows' `/cm set` forms (architecture-§5). The library has no
-- type for them, so the descriptor's `parse` answers these two and hands every
-- other row to the library's own parser. An order is its keys, comma- or
-- space-separated and case-folded: the keys named lead, in the order given, and
-- every other key follows in its CURRENT stored order, so a slot nobody named
-- keeps its place relative to the rest. The row's normalizer then drops strangers
-- and appends any member the stored order has never seen. A flag map is
-- KEY=on|off pairs MERGED over the current stored map: a key the pairs do not
-- name keeps its stored flag, so hiding one button never un-hides another. A map
-- with its own normalizer (stat priority's) has an editor of its own, which the
-- refusal names.
local function parseKeyList(row, text)
    local out, named = {}, {}
    for tok in (text or ""):gmatch("[^,%s]+") do
        local k = tok:upper()
        if not named[k] then named[k] = true; out[#out + 1] = k end
    end
    if #out == 0 then return nil, "expected a comma-separated list of keys" end
    local H = helpers()
    local stored = H and H.Get(row.path)
    for _, k in ipairs(type(stored) == "table" and stored or {}) do
        if not named[k] then named[k] = true; out[#out + 1] = k end
    end
    return out
end

local function parseFlagMap(row, text)
    local out, n = {}, 0
    local H = helpers()
    local stored = H and H.Get(row.path)
    for k, v in pairs(type(stored) == "table" and stored or {}) do out[k] = v end
    for pair in (text or ""):gmatch("[^,%s]+") do
        local k, word = pair:match("^([^=]+)=(.+)$")
        local v = word and slashLib.ParseBool(word)
        if v == nil then return nil, "expected KEY=on|off pairs, comma-separated" end
        out[k:upper()] = v
        n = n + 1
    end
    if n == 0 then return nil, "expected KEY=on|off pairs, comma-separated" end
    return out
end

local function parseValue(row, text)
    if row and row.type == "order" then return parseKeyList(row, text) end
    if row and row.type == "map" then
        if row.valueType == "bool" then return parseFlagMap(row, text) end
        return nil, ("edited with %s, not with /cm set"):format(tostring(row.cliHint))
    end
    return slashLib.ParseValue(row, text)
end

-- The descriptor's `format`, which outranks the color codec, so it decodes a
-- color itself exactly as the library would. The whole-value rows render through
-- KCM.FormatSchemaValue, the addon's own renderer (core/SlashCommands.lua).
local function formatValue(row, value)
    if row and (row.type == "order" or row.type == "map") then
        return KCM.FormatSchemaValue(row, value)
    end
    if row and row.type == "color" and type(value) == "table" then
        local r, g, b, a = KCM.ColorDecode(value)
        return slashLib.FormatValue(row, { r = r, g = g, b = b, a = a })
    end
    return slashLib.FormatValue(row, value)
end

if slashLib then
    Sl = slashLib:New({
        slash        = "/cm",
        -- Only [1] is ever named, in the help header's alias clause.
        slashAliases = { "/consumablemaster" },
        commands     = COMMANDS,
        aliases      = ALIASES,
        version      = addonVersion,

        -- THE DISABLED GATE (Slash minor 13, slash-commands-§2 and slash-commands-§7). Three
        -- fields, and the library does the rest: the twelve reserved verbs and
        -- the bare `/cm` answer normally while the addon is off -- a player must
        -- be able to read and repair settings and to REACH THE PANEL then, which
        -- is precisely when they are most likely to need to, and `enable` above
        -- all, or the pair is one-way -- while this addon's own feature verbs
        -- answer the one refusal line and do nothing else.
        --
        -- `isEnabled` is asked at DISPATCH time and never cached, so the command
        -- after an `/cm enable` works. It reads through the same seam the
        -- checkbox and `/cm get enabled` read (slash-commands-§2's "no state of
        -- their own").
        isEnabled    = addonEnabled,
        -- The brand name in plain text, and the SAME string core/LauncherSetup.lua
        -- gives the LDB object as `label` (launcher-§1 forbids escapes in that
        -- field, which is what makes it safe to drop into a colored line). Spelled
        -- as a literal in both places and pinned against each other by
        -- tests/test_disabled.lua, rather than one file reaching into the other.
        brandName    = "Ka0s Consumable Master",
        -- WIDENS the library's thirteen by this addon's read-only `dump`; it must
        -- never narrow them. See LIVE_VERBS above.
        liveVerbs    = LIVE_VERBS,
        -- A thunk, not `say` bare: the library snapshots the printer at :New.
        -- Same note as core/CoreSetup.lua's sink and core/DebugLogSetup.lua's
        -- print.
        print        = function(line) KCM.Say(line) end,
        L            = SLASH_STRINGS,

        -- The schema half. Every one of these resolves through KCM.Settings at
        -- CALL time, so the rows the page files append after settings/Panel.lua
        -- built the seam are all there by the first command.
        --
        -- `set` is the seam's own Set, not SetAndRefresh: it answers
        -- `false, err, why` on a refusal (Slash minor 15), so CliSet prints the
        -- library's INVALID line and the reason ONCE, and the host prints no
        -- second line of its own. `applyDefault` is the seam's ApplyDefault,
        -- whose exact `false` for a row with no default is the NO_DEFAULT line.
        get          = function(path) local H = helpers(); return H and H.Get(path) end,
        set          = function(path, value)
            local S = schema()
            if not S then return false end
            return S.Set(path, value)
        end,
        findRow      = function(path) local S = schema(); return S and S.FindRow(path) end,
        allRows      = function() return (KCM.Settings and KCM.Settings.Schema) or {} end,
        applyDefault = function(row)
            local S = schema()
            if not S then return false end
            return S.ApplyDefault(row)
        end,
        -- Rows carry `panel`, not the library's default `page`.
        groupKey     = function(row) return row.panel or "?" end,

        -- Colors are stored POSITIONALLY here — { r, g, b, a } — which is what
        -- the Ka0s options color widget writes. The library reads that shape
        -- directly when rendering, but the codec is what makes a `/cm set`
        -- WRITE land in it rather than in the named-key form.
        --
        -- KCM.ColorDecode bare, with NO fallback supplied
        -- (CONSUMABLEMASTER-R-05). This surface used to answer `c[1] or 0`
        -- while settings/OptionsSetup.lua answered `c[1] or 1`, so one stored
        -- value read black here and white in the panel. Handing on the
        -- decoder's nil is not a gap: lib.FormatValue fills an absent channel
        -- from its own COLOR_KEYS (in libs/LibKa0s/Slash.lua) with exactly
        -- these numbers, so what the user sees is unchanged and the addon
        -- carries one fewer copy of them.
        colorDecode  = KCM.ColorDecode,
        colorEncode  = function(r, g, b, a) return { r, g, b, a or 1 } end,

        -- The whole-value rows' reader and renderer (see parseValue / formatValue).
        parse        = parseValue,
        format       = formatValue,
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
    -- The `set` shape read back from the STORE, which is what slash-commands-§5
    -- asks a set to echo — CliGet renders the stored value through the one shared
    -- formatter `list` / `get` / `set` / `reset` all use, so `/cm enable` cannot
    -- drift from `/cm set enabled true`.
    echoEnabled = function() Sl:CliGet(ENABLED_PATH) end
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
local function findCommand(cmd)
    for _, entry in ipairs(COMMANDS) do
        if entry[1] == cmd then return entry end
    end
end

local function degradedDispatch(msg)
    local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
    -- Bare /cm runs `config`, as the library's OnSlash does since Slash minor
    -- 11 (slash-commands-§4); `help` prints the index. `config` is a host verb,
    -- so on this path it reaches KCM.Options.Open, which says the panel is
    -- unavailable. With no `config` row it falls back to help, as the library does.
    if raw == "" then
        local config = findCommand("config")
        if config then return config[3]("") end
        return printHelp()
    end

    -- Only the verb is lowercased. `rest` keeps its case because schema paths
    -- are case-sensitive, and its internal spacing because a color is several
    -- tokens. Same split as the library's.
    local cmd, rest = raw:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    cmd = ALIASES[cmd] or cmd

    local entry = findCommand(cmd)
    if entry then return entry[3](rest or "") end

    say(SLASH_STRINGS.UNKNOWN_COMMAND:format(cmd))
    return printHelp()
end

function KCM:OnSlashCommand(msg)
    if not Sl then return degradedDispatch(msg) end
    return Sl:OnSlash(msg)
end
