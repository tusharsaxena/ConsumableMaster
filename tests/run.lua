-- tests/run.lua — headless test entry point, running on the vendored LibKa0s testkit.
--
-- Usage (from the addon root):   lua5.1 tests/run.lua
--                                lua5.1 tests/run.lua --list
-- Runs every tests/test_*.lua under the WoW mock and exits non-zero if any
-- assertion failed (so it can gate commits).
--
-- With --list, loads every suite but runs nothing: prints the docs/test-cases.md
-- inventory body to stdout and exits 0. Regenerate the inventory with:
--     lua tests/run.lua --list > docs/test-cases.md
--
-- THE KIT IS THE HARNESS (testing-§1). Three vendored files do the work that
-- three private ones used to:
--   * tests/_kit/framework.lua — the case registry, the assertion set, the
--     runner and the --list renderer (was tests/harness.lua);
--   * tests/_kit/loader.lua    — reading source off disk and calling each chunk
--     with the client's ("ConsumableMaster", NS) vararg (was tests/loader.lua);
--   * tests/_kit/mock_base.lua — the universal half of the WoW mock, extended
--     by this addon's own tests/wow_mock.lua.
-- Never edit tests/_kit/ here: a kit problem is a finding to fix in LibKa0s and
-- re-vendor, and tests/test_vendor_sync.lua fails on a local patch.
--
-- What stays in this file is what is genuinely per-addon: the vendored-library
-- and source load lists, the namespace builders every suite calls, and the
-- suite list.

local function scriptDir()
    local src = arg and arg[0] or "tests/run.lua"
    return (src:match("^(.*)[/\\]tests[/\\]run%.lua$")) or "."
end

local ROOT = scriptDir()
_G.KCM_TEST_ROOT = ROOT

local Kit      = dofile(ROOT .. "/tests/_kit/framework.lua")
local Loader   = dofile(ROOT .. "/tests/_kit/loader.lua")
local mockBase = dofile(ROOT .. "/tests/_kit/mock_base.lua")
local mock     = dofile(ROOT .. "/tests/wow_mock.lua")(mockBase)

local ADDON_NAME = "ConsumableMaster"

-- ---------------------------------------------------------------------------
-- Assertions
-- ---------------------------------------------------------------------------
--
-- The kit's assertion set under the case-local names every suite in this repo
-- already uses, so adopting the kit changed no suite body: t.eq / t.truthy /
-- t.falsy / t.near ARE Kit.assertEqual / assertTrue / assertFalse / assertNear.
-- Only `ne`, `eqList` and `contains` are written here — the kit does not carry
-- them — and they report through Kit.fail so a failure blames the caller's line
-- exactly like every kit assertion does.

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(val) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local T = {
    eq     = Kit.assertEqual,
    truthy = Kit.assertTrue,
    falsy  = Kit.assertFalse,
    near   = Kit.assertNear,
    skip   = Kit.skip,
}

function T.ne(a, b, msg)
    if a == b then Kit.fail((msg or "ne") .. ": expected not " .. fmt(b), 2) end
end

--- Assert array `a` equals array `b` element-by-element.
function T.eqList(a, b, msg)
    a, b = a or {}, b or {}
    if #a ~= #b then
        Kit.fail((msg or "eqList") .. ": length " .. #a .. " ~= " .. #b
            .. " (got " .. fmt(a) .. ", want " .. fmt(b) .. ")", 2)
        return
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            Kit.fail((msg or "eqList") .. "[" .. i .. "]: got " .. fmt(a[i])
                .. ", want " .. fmt(b[i]), 2)
        end
    end
end

function T.contains(list, val, msg)
    for _, v in ipairs(list or {}) do if v == val then return end end
    Kit.fail((msg or "contains") .. ": " .. fmt(val) .. " not in " .. fmt(list), 2)
end

-- ---------------------------------------------------------------------------
-- Source loading
-- ---------------------------------------------------------------------------
--
-- Works across the namespace migration: each chunk is called with the WoW addon
-- vararg convention ("ConsumableMaster", NS), which Loader.addonName turns on.
-- Pre-migration files read `_G.KCM` (the mock's AceAddon:NewAddon returns it as
-- the same NS table); post-migration files read the vararg. Either way every
-- module lands on one shared namespace table.

Loader.addonName = ADDON_NAME

local L = { mock = mock }

-- Resolved lazily so a path tolerates either the flat (pre-move) or
-- core/modules (post-move) layout: each entry is tried at its listed path and,
-- failing that, at the alternate location.
local function resolve(rel)
    local candidates = {
        ROOT .. "/" .. rel,
        ROOT .. "/core/" .. rel,
        ROOT .. "/modules/" .. rel,
    }
    -- also try basename under core/ and modules/ for moved files
    local base = rel:match("([^/]+)$")
    candidates[#candidates + 1] = ROOT .. "/core/" .. base
    candidates[#candidates + 1] = ROOT .. "/modules/" .. base
    for _, p in ipairs(candidates) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return ROOT .. "/" .. rel
end

-- The vendored library files, spelled out in the order libs/LibKa0s/LibKa0s.xml
-- uses them. They cannot be derived from the TOC the way the addon's own files
-- are: the TOC names one aggregate XML, and Loader.tocFiles skips `libs\`
-- outright. Getting this list wrong is silent — a module whose dependency is
-- absent returns BEFORE LibStub:NewLibrary, so the major is never registered,
-- the host's setup file takes its degradation stub, and the suite happily
-- measures the stub while staying green (Ka0s standard testing-§9).
-- tests/test_libka0s.lua pins this list against the XML.
L.LIB_FILES = {
    "libs/LibKa0s/Core.lua",
    "libs/LibKa0s/DebugLog.lua",
    "libs/LibKa0s/Slash.lua",
    "libs/LibKa0s/Options.lua",
    "libs/LibKa0s/OptionsWidgets.lua",
    "libs/LibKa0s/OptionsScroll.lua",
    "libs/LibKa0s/Perf.lua",
    "libs/LibKa0s/PerfPanel.lua",
}

-- Compiled once and re-executed per build. Every suite rebuilds its whole
-- environment (mock.install wipes the LibStub registry), so the chunks have to
-- run again on each build — but they only have to be READ from disk once, and
-- these eight files run several hundred times across the suite. They run in the
-- kit loader's environment, exactly as Loader.load would run them, so the two
-- paths cannot drift; only the disk read is hoisted.
local libChunks
local libEnv = Loader.makeEnv({})
local function loadLibs()
    if not libChunks then
        libChunks = {}
        for _, rel in ipairs(L.LIB_FILES) do
            local path = ROOT .. "/" .. rel
            local chunk, err = loadfile(path)
            if not chunk then
                error("loader: could not load " .. path .. ": " .. tostring(err))
            end
            setfenv(chunk, libEnv)
            libChunks[#libChunks + 1] = chunk
        end
    end
    for _, chunk in ipairs(libChunks) do chunk() end
end

L.PURE_LAYER = {
    "locales/enUS.lua",
    "Namespace.lua",
    "ConsumableMaster.lua",
    "Bus.lua",
    "Constants.lua",
    "core/CoreSetup.lua",
    "Compat.lua",
    "Database.lua",
    "defaults/Categories.lua",
    "defaults/Defaults_StatPriority.lua",
    "defaults/Defaults_Food.lua",
    "defaults/Defaults_Drink.lua",
    "defaults/Defaults_StatFood.lua",
    "defaults/Defaults_HPPot.lua",
    "defaults/Defaults_MPPot.lua",
    "defaults/Defaults_Healthstone.lua",
    "defaults/Defaults_CombatPot.lua",
    "defaults/Defaults_Flask.lua",
    "defaults/Defaults_Vantus.lua",
    "defaults/Defaults_WpnEnch.lua",
    "defaults/Defaults_AugRune.lua",
    "defaults/Defaults_Bloodlust.lua",
    "defaults/Defaults_BattleRez.lua",
    "SpecHelper.lua",
    "core/WeaponSlots.lua",
    "Classifier.lua",
    "Ranker.lua",
    "Selector.lua",
    "MacroManager.lua",
    "BagScanner.lua",
    "core/MacroDisplay.lua",
    "core/MacroBarModel.lua",
    "core/MacroBarLayout.lua",
}

-- Load an explicit list of source files onto a fresh mocked namespace.
-- Returns the namespace table (KCM / NS).
--
-- `omitLibs` deliberately skips the vendored LibKa0s files, which is how the
-- degraded path is exercised: the addon is loaded FOR REAL with the library
-- absent and each setup file takes its own fallback, rather than a test
-- hand-stubbing the namespace member it then asserts on (testing-§8).
--
-- A PARTIAL FILE LIST is the other half of that: `files` is an arbitrary subset,
-- so a caller can build the same seam twice — once with the library and once
-- without — and compare the two surfaces (Kit.assertSurfaceParity) without
-- either arm being hand-written.
function L.loadFiles(files, omitLibs)
    local NS = {}
    mock.install(NS)
    if not omitLibs then loadLibs() end
    -- WoW hands every file in an addon the SAME private table as its second
    -- vararg. Model that exactly by threading one fresh `NS` to every chunk —
    -- and clear any `_G.KCM` a prior suite's mock left behind so nothing stale
    -- leaks in before ConsumableMaster's AceAddon promotion runs.
    _G.KCM = nil
    for _, rel in ipairs(files) do
        Loader.load(resolve(rel), NS, {})
    end
    local KCM = NS
    -- The pipeline expects a db; simulate AceDB:New so KCM.db.profile exists.
    if not KCM.db and KCM.OnInitialize then
        pcall(function() KCM:OnInitialize() end)
    end
    -- The pure layer never loads the real TooltipCache's Get() (its parser
    -- needs live C_TooltipInfo data). But IsUsableByPlayer's level-verdict
    -- logic — the pending check, the min/max compare, the reason strings —
    -- is pure Lua with no client dependency, and Selector's levelBlocked()
    -- gate has to be exercised against the REAL thing, not a hand-rolled
    -- copy that can silently drift from it. So load the real
    -- core/TooltipCache.lua onto this NS (giving it real Get/IsUsableByPlayer/
    -- Invalidate/InvalidateAll) and then swap ONLY Get() for one sourced from
    -- the mock's injected `tt` tables. IsUsableByPlayer keeps calling
    -- `TC.Get(itemID)` through the shared KCM.TooltipCache table, so it runs
    -- unmodified against mock data. If core/TooltipCache.lua's IsUsableByPlayer
    -- ever changes, this picks it up for free — nothing here to keep in sync.
    if not KCM.TooltipCache then
        Loader.load(resolve("core/TooltipCache.lua"), KCM, {})
        KCM.TooltipCache.Get = function(id)
            local it = mock.items[id]
            if not it then return { pending = true } end
            local tt = {}
            for k, v in pairs(it.tt or {}) do tt[k] = v end
            tt.itemName = tt.itemName or it.name
            if it.pending then tt.pending = true end
            return tt
        end
    end
    return KCM
end

-- The common case: the pure logic layer with a live db.profile.
function L.loadPure()
    return L.loadFiles(L.PURE_LAYER)
end

-- The pure layer with libs/LibKa0s/ absent, so every setup file runs its
-- degradation stub for real.
function L.loadPureDegraded()
    return L.loadFiles(L.PURE_LAYER, true)
end

-- Pure layer + the debug console and its gated sink, in TOC order.
--
-- modules/DebugLog.lua is deliberately NOT in PURE_LAYER: tests/test_debug.lua
-- builds the sink WITHOUT the console on purpose, to exercise the chat-fallback
-- path. `omitLibs` runs the whole stack with libs/LibKa0s/ absent so
-- modules/DebugLog.lua takes its real degradation stub rather than a
-- hand-written one (testing-§8).
function L.loadConsole(omitLibs)
    local files = {}
    for _, f in ipairs(L.PURE_LAYER) do files[#files + 1] = f end
    files[#files + 1] = "core/State.lua"
    files[#files + 1] = "modules/DebugLog.lua"
    files[#files + 1] = "core/Debug.lua"
    return L.loadFiles(files, omitLibs)
end

-- The addon's own files, in the TOC's order. Derived rather than
-- hand-maintained, so a file added to the TOC cannot go untested.
function L.tocFiles()
    return Loader.tocFiles(ROOT .. "/" .. ADDON_NAME .. ".toc")
end

-- Load the ENTIRE addon in the exact order the TOC declares (skipping the
-- libs XML, which the mock provides). This is the headless proxy for an
-- in-game load — it catches load-order breaks (a file referencing another's
-- symbols before it loads) that the pure-layer subset can't.
function L.loadFullAddon(omitLibs)
    return L.loadFiles(L.tocFiles(), omitLibs)
end

-- Pure layer + the settings schema (Panel.lua), for schema tests.
--
-- `omitLibs` runs it with libs/LibKa0s/ absent, so settings/Panel.lua takes its
-- real degradation path — no panel registered — rather than a hand-stubbed one
-- (testing-§8). The schema half of the file is declared above that seam and
-- keeps working either way, which is what the degraded suite pins.
function L.loadWithSchema(omitLibs)
    local files = {}
    for _, f in ipairs(L.PURE_LAYER) do files[#files + 1] = f end
    files[#files + 1] = "settings/Panel.lua"
    return L.loadFiles(files, omitLibs)
end

function L.loadWithSchemaDegraded()
    return L.loadWithSchema(true)
end

-- ---------------------------------------------------------------------------
-- The test global
-- ---------------------------------------------------------------------------
--
-- Kit.expose merges the kit's registry and assertions into this repo's own test
-- table, so the global keeps the loader and the mock every suite reaches for.
-- `test` is wrapped rather than taken straight from the kit for one reason: this
-- repo's cases are written `function(t) ... end` and take their assertions as an
-- argument, so the wrapper threads T in.

local KCM_TEST = Kit.expose({ loader = L, T = T, mock = mock })

-- Captured before any case installs the mock. `mock.install` replaces _G.print
-- with the chat-output capture the suites assert on, and the kit's runner prints
-- its PASS/FAIL/SKIP lines through the global — so the first case would silently
-- swallow the entire run's report. Restoring it on the way out of every body,
-- pass or fail, is the whole fix: the mock still owns `print` for the duration of
-- the case, and nothing else ever sees the capture.
local realprint = print

function KCM_TEST.test(name, fn, skipReason)
    Kit.test(name, fn and function()
        local ok, err = pcall(fn, T)
        _G.print = realprint
        -- Level 0: `err` is either a message that already carries its position
        -- or the kit's skip sentinel, and re-stamping either is wrong.
        if not ok then error(err, 0) end
    end or nil, skipReason)
end

_G.KCM_TEST = KCM_TEST

-- ---------------------------------------------------------------------------
-- The suite list
-- ---------------------------------------------------------------------------

-- Discover test_*.lua deterministically without relying on LuaFileSystem:
-- shell out to `ls` (portable enough for this WSL/Linux dev env).
local function discover()
    local names = {}
    local pipe = io.popen and io.popen("ls " .. ROOT .. "/tests/test_*.lua 2>/dev/null")
    if pipe then
        for line in pipe:lines() do
            local base = line:match("([^/\\]+)%.lua$")
            if base then names[#names + 1] = base end
        end
        pipe:close()
    end
    table.sort(names)
    return names
end

local suites = discover()
if #suites == 0 then
    print("run.lua: no test_*.lua suites found under " .. ROOT .. "/tests/")
    os.exit(1)
end

-- `suiteInventory = false` because the list above is DISCOVERED: asserting a
-- discovered list against the directory it was discovered from is a gate that
-- cannot fire. It switches on with a declared list.
Kit.run({ dir = ROOT .. "/tests/", suites = suites, suiteInventory = false })
