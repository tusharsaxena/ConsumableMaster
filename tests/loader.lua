-- tests/loader.lua — loads addon source files under the headless mock.
--
-- Works across the namespace migration: each chunk is called with the WoW
-- addon vararg convention `("ConsumableMaster", NS)`. Pre-migration files read
-- `_G.KCM` (which the mock's AceAddon:NewAddon returns as the same NS table);
-- post-migration files read the vararg. Either way every module lands on one
-- shared namespace table.

local mock = require("wow_mock")

local ROOT = _G.KCM_TEST_ROOT or "."
local ADDON_NAME = "ConsumableMaster"

local L = { mock = mock }

-- Central source-path list. Paths are updated once when the modular folder move
-- lands (Sprint 2) — every suite goes through PURE_LAYER so there is a single
-- place to re-point.
--
-- Resolved lazily so the file can tolerate either the flat (pre-move) or
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
-- are: the TOC names one aggregate XML, and `loadFullAddon` skips `libs\`
-- outright. Getting this list wrong is silent — a module whose dependency is
-- absent returns BEFORE LibStub:NewLibrary, so the major is never registered,
-- the host's setup file takes its degradation stub, and the suite happily
-- measures the stub while staying green (Ka0s standard testing-§9).
-- tests/test_load.lua pins this list against the XML.
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

-- Compiled once and re-executed per load. Every suite rebuilds its whole
-- environment (mock.install wipes the LibStub registry), so the chunks have to
-- run again on each build — but they only have to be READ from disk once, and
-- these eight files run several hundred times across the suite.
local libChunks
local function loadLibs()
    if not libChunks then
        libChunks = {}
        for _, rel in ipairs(L.LIB_FILES) do
            local path = ROOT .. "/" .. rel
            local chunk, err = loadfile(path)
            if not chunk then
                error("loader: could not load " .. path .. ": " .. tostring(err))
            end
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
        local path = resolve(rel)
        local chunk, err = loadfile(path)
        if not chunk then
            error("loader: could not load " .. path .. ": " .. tostring(err))
        end
        chunk(ADDON_NAME, NS)
    end
    local KCM = NS
    -- The pipeline expects a db; simulate AceDB:New so KCM.db.profile exists.
    if not KCM.db and KCM.OnInitialize then
        pcall(function() KCM:OnInitialize() end)
    end
    -- The pure layer never loads the real TooltipCache (its parser needs live
    -- C_TooltipInfo data). Back Classifier/Ranker with a stub sourced from the
    -- mock's injected `tt` tables so suites control parsed-tooltip inputs.
    if not KCM.TooltipCache then
        KCM.TooltipCache = {
            Get = function(id)
                local it = mock.items[id]
                if not it then return { pending = true } end
                local tt = {}
                for k, v in pairs(it.tt or {}) do tt[k] = v end
                tt.itemName = tt.itemName or it.name
                return tt
            end,
            Invalidate = function() end,
            InvalidateAll = function() end,
            IsUsableByPlayer = function() return true end,
        }
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

-- Load the ENTIRE addon in the exact order the TOC declares (skipping the
-- libs XML, which the mock provides). This is the headless proxy for an
-- in-game load — it catches load-order breaks (a file referencing another's
-- symbols before it loads) that the pure-layer subset can't.
function L.loadFullAddon(omitLibs)
    return L.loadFiles(L.tocFiles(), omitLibs)
end

-- The addon's own files, in the TOC's order. Derived rather than
-- hand-maintained, so a file added to the TOC cannot go untested.
function L.tocFiles()
    local toc = ROOT .. "/ConsumableMaster.toc"
    local files = {}
    for line in io.lines(toc) do
        line = line:gsub("\r", ""):gsub("%s+$", "")
        -- Skip comments, non-.lua entries, and vendored libs (libs\… — the
        -- mock provides LibStub/Ace). Libs are listed directly in the TOC, so
        -- the skip keys on the path, not on the .xml extension.
        if not line:match("^#") and line:match("%.lua$")
            and not line:match("^[Ll]ibs[/\\]") then
            files[#files + 1] = line:gsub("\\", "/")
        end
    end
    return files
end

-- Pure layer + the settings schema (Panel.lua), for schema tests.
function L.loadWithSchema()
    local files = {}
    for _, f in ipairs(L.PURE_LAYER) do files[#files + 1] = f end
    files[#files + 1] = "settings/Panel.lua"
    return L.loadFiles(files)
end

return L
