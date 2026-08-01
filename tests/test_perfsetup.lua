-- test_perfsetup.lua — the addon's half of LibKa0s-Perf-1.0.
--
-- Unlike the other three LibKa0s seams, this one replaced nothing: there is no
-- host implementation and no oracle suite. So what these cases pin is the
-- WIRING rather than the behaviour — the behaviour is the library's, and
-- libs/ is not this repo's to test. Specifically: that the instance came from
-- the library, that the panel half attached, that the descriptor answered the
-- fields whose defaults are silently wrong, that the SavedVariables global is
-- actually declared, and that the instrumentation is inert when no capture is
-- running.

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadFullAddon()
    return KCM, h.loader.mock
end

test("Perf: the harness IS the library's instance, not a lookalike", function(t)
    local KCM = load()
    local lib = LibStub("LibKa0s-Perf-1.0")
    t.truthy(lib, "LibKa0s-Perf-1.0 registered")
    t.truthy(KCM.Perf, "KCM.Perf is published")
    -- Function-object identity against what the library mirrors onto every
    -- instance. KCM.Perf is the instance itself rather than a facade — three of
    -- the members the brackets read are plain boolean FIELDS the library
    -- writes, and a forwarder cannot mirror a field.
    t.eq(KCM.Perf.EncodeJSON, lib.EncodeJSON, "EncodeJSON is the library function object")
    t.eq(KCM.Perf.SCHEMA, lib.SCHEMA, "the record schema is the library's")
end)

test("Perf: the panel half attached to the instance", function(t)
    local KCM = load()
    -- Perf.lua ships no-op panel fallbacks, so a copy vendored without
    -- PerfPanel.lua would leave a working harness with a dead /cm perf and no
    -- error anywhere. Seven steps is PerfPanel's own list; the fallback leaves
    -- STEPS empty.
    t.eq(#KCM.Perf.STEPS, 7, "the panel contributed its seven steps")
    t.truthy(KCM.Perf.ShowPanel, "and its show entry point")
end)

test("Perf: every panel step's label resolves to prose, not to its own key", function(t)
    local KCM = load()
    local P = KCM.Perf
    -- The L trap, on the module that actually shipped it: a sibling addon's
    -- perf panel rendered PANEL_TITLE_SUFFIX / STEP_START / STEP_MEASURE_A as
    -- raw keys because its descriptor was handed the addon's locale table,
    -- whose metatable answers every key with the key. modules/PerfSetup.lua
    -- passes no L at all, and this case is what stops one being added.
    --
    -- P.STEPS[i].label is the string PerfPanel resolved and each row actually
    -- draws -- re-resolved on every repaint -- so it is the rendered text
    -- rather than the descriptor or a constant. The count is re-asserted
    -- first on purpose: an empty STEPS would otherwise make an unguarded loop
    -- pass with nothing checked, which is the vacuous shape this case exists
    -- to avoid.
    t.eq(#P.STEPS, 7, "all seven rows are present to check")
    for _, step in ipairs(P.STEPS) do
        t.falsy(step.label:match("^[A-Z][A-Z0-9_]+$"),
            "step '" .. step.key .. "' resolved to prose, not to its own key: " .. step.label)
    end
end)

test("Perf: the descriptor answers the fields whose defaults are silently wrong", function(t)
    local KCM = load()
    local P = KCM.Perf
    -- The library defaults slash to "/" .. name:lower() — "/consumablemaster",
    -- which is a real alias but not the one anyone types, and every panel row
    -- and usage line would teach it.
    t.eq(P.slash, "/cm", "the panel teaches the command people actually use")
    t.eq(P.name, "ConsumableMaster", "frame globals match the debug console's naming")
    t.eq(P.title, "Consumable Master", "the panel title is the addon's")
    t.eq(P.descriptor.sv, "ConsumableMasterPerfDB", "captures get their own global")
end)

test("Perf: the SavedVariables global the harness writes is actually declared", function(t)
    local KCM = load()
    local sv = KCM.Perf.descriptor.sv
    -- The single highest-value case here: without the TOC line the library
    -- writes a global Blizzard never persists, while `finish` still announces
    -- the capture as saved. Green tests, working panel, data gone. Read the TOC
    -- as text, the way the vendoring suite does.
    local declared = false
    for line in io.lines((_G.KCM_TEST_ROOT or ".") .. "/ConsumableMaster.toc") do
        if line:match("^## SavedVariables:") and line:find(sv, 1, true) then
            declared = true
        end
    end
    t.truthy(declared, "## SavedVariables names " .. sv)
end)

test("Perf: /cm perf is a published verb and reaches the harness", function(t)
    local KCM, mock = load()
    local row
    for _, entry in ipairs(KCM.COMMANDS) do
        if entry[1] == "perf" then row = entry end
    end
    t.truthy(row, "perf is in the COMMANDS table")
    -- Which also means it reaches /cm help and the About page's command list —
    -- one table, and since LIBKA0S-13 one formatter, so asking the rendered
    -- rows is the same question as asking the data used to be, one step closer
    -- to the screen.
    local inLanding = false
    for _, line in ipairs(KCM.SlashCommands.GetLandingRows()) do
        if line:find("/cm perf", 1, true) then inLanding = true end
    end
    t.truthy(inLanding, "…so the About page and /cm help stay in lock-step")

    local reached = 0
    local real = KCM.Perf.OnCommand
    KCM.Perf.OnCommand = function(rest) reached = reached + 1; return real(rest) end
    mock.output = {}
    KCM:OnSlashCommand("perf")
    KCM.Perf.OnCommand = real
    t.eq(reached, 1, "the verb dispatches into the library's command surface")
end)

test("Perf: the capture flag is the library's alone, with no second home", function(t)
    local KCM = load()
    t.eq(KCM.Perf.on, false, "no capture is running at load")
    t.eq(KCM.Perf.suspended, false, "and the addon is not suspended")
    -- KCM.State is where the session-only debug flag lives, and it would be the
    -- obvious place to mirror this one. It must not be: the library flips
    -- P.on directly when a window opens, so a mirror would go stale
    -- immediately. Same for the profile — a persisted "suspended" restored
    -- across a reload would leave the addon inert with no way back.
    t.eq(KCM.State.perf, nil, "no session mirror of the capture flag")
    t.eq(KCM.db.profile.perf, nil, "and nothing persisted into the profile")
end)

test("Perf: the instrumentation records nothing while no capture is running", function(t)
    local KCM = load()
    -- The negative pin on the two brackets. Note() records unconditionally, so
    -- an ungated bracket would accumulate outside any window and poison the
    -- next report — this is the case that fails if a gate is ever dropped.
    KCM.Pipeline.Recompute("test")
    if KCM.MacroBar and KCM.MacroBar.RefreshCooldowns then
        KCM.MacroBar.RefreshCooldowns()
    end
    local buckets = KCM.Perf.__buckets()
    local n = 0
    for _ in pairs(buckets) do n = n + 1 end
    t.eq(n, 0, "no bucket accrued with the harness idle")
end)

test("Perf: every Note call site sits in a file that gates on the capture flag", function(t)
    -- Blunt on purpose, and cheap. The failure it guards is the one the library
    -- warns about in its own header: an ungated bracket records forever. A file
    -- that calls Note without ever reading `.on` cannot be correctly gated.
    local root = (_G.KCM_TEST_ROOT or ".")
    local function readAll(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local body = f:read("*a")
        f:close()
        return body
    end
    local sites = 0
    for line in io.lines(root .. "/ConsumableMaster.toc") do
        local rel = line:match("^(core\\[%w_]+%.lua)") or line:match("^(modules\\[%w_]+%.lua)")
        if rel then
            local body = readAll(root .. "/" .. rel:gsub("\\", "/"))
            if body and body:find("%.Note%(") then
                sites = sites + 1
                t.truthy(body:find("%.on%s") or body:find("%.on%)"),
                    rel .. " gates its Note call on the capture flag")
            end
        end
    end
    t.truthy(sites >= 2, "both instrumented files were found and checked")
end)

test("Perf: with the library absent the feature is absent, and /cm perf says so", function(t)
    -- Loaded for real with libs/LibKa0s/ omitted. No fallback is wanted here —
    -- nothing in the addon reads KCM.Perf, so an absent major means an absent
    -- feature rather than a re-implementation.
    local KCM  = h.loader.loadFullAddon(true)
    local mock = h.loader.mock
    t.falsy(LibStub("LibKa0s-Perf-1.0", true), "the major really is absent")
    t.eq(KCM.Perf, nil, "no harness is published")

    -- Driven through the COMMANDS row rather than through /cm: with libs
    -- omitted the slash DISPATCHER is absent too, so the verb never routes.
    -- What is under test is the handler's own call-time guard.
    local handler
    for _, entry in ipairs(KCM.COMMANDS) do
        if entry[1] == "perf" then handler = entry[3] end
    end
    t.truthy(handler, "the verb is still declared")
    mock.output = {}
    handler("")
    t.truthy(table.concat(mock.output, "\n"):find("perf capture unavailable", 1, true),
        "and answers rather than erroring on a nil harness")
end)
