-- test_libka0s.lua — the vendoring itself, not any one module's wiring.
--
-- Three things go wrong silently when an addon vendors a multi-file LibStub
-- library, and none of them shows up in a pass/fail line on its own:
--
--   * a library file left out of the harness's load list makes the dependent
--     module refuse to register (its guard returns BEFORE LibStub:NewLibrary),
--     so the host's setup file falls back to its stub and the suite happily
--     measures the stub — green, and testing nothing (Ka0s standard
--     testing-§9);
--   * a SHELL file that arrives without its attach file registers normally and
--     `:New` still succeeds, handing back an instance whose attached members
--     are simply missing — a failure that surfaces at CALL time, a panel build
--     away (anti-patterns #48);
--   * an attach file paired against a shell from a DIFFERENT vendored copy,
--     which is the exact skew the one-major-per-module layout exists to
--     prevent (library-stack-§7).
--
-- The per-module wiring lives in each module's own suite. This one is about
-- the copy.

local h = require("harness")
local test = h.test
local loader = h.loader

local ROOT = _G.KCM_TEST_ROOT or "."

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

-- Every major this addon vendors, with the files that belong to it and how a
-- secondary file records which primary it attached to. Declared as a table
-- rather than spelled out inline so a module added to LibKa0s.xml and
-- forgotten here surfaces as a failure rather than as silence.
local MAJORS = {
    { major = "LibKa0s-Core-1.0",     files = { "Core" } },
    { major = "LibKa0s-DebugLog-1.0", files = { "DebugLog" } },
    { major = "LibKa0s-Slash-1.0",    files = { "Slash" } },
    {
        major = "LibKa0s-Options-1.0",
        files = { "Options", "OptionsWidgets", "OptionsScroll" },
        primary = "Options",
        paired = {
            { file = "OptionsWidgets", minor = "__widgetsMinor", shell = "__widgetsShellMinor" },
            { file = "OptionsScroll",  minor = "__scrollMinor",  shell = "__scrollShellMinor" },
        },
    },
    {
        major = "LibKa0s-Perf-1.0",
        files = { "Perf", "PerfPanel" },
        primary = "Perf",
        paired = {
            { file = "PerfPanel", minor = "__panelMinor", shell = "__panelProbeMinor" },
        },
    },
}

test("LibKa0s: the harness load list matches libs/LibKa0s/LibKa0s.xml exactly", function(t)
    local xml = readFile(ROOT .. "/libs/LibKa0s/LibKa0s.xml")
    t.truthy(xml, "libs/LibKa0s/LibKa0s.xml is vendored")
    local fromXml = {}
    for file in (xml or ""):gmatch('<Script%s+file="([^"]+)"') do
        fromXml[#fromXml + 1] = "libs/LibKa0s/" .. file
    end
    t.truthy(#fromXml > 0, "the XML names at least one script")
    -- The list is hand-maintained because the TOC names one aggregate XML and
    -- the TOC-derived addon list skips libs\ outright. This case is what makes
    -- the hand-maintenance safe: a file added to the library shows up here.
    t.eqList(loader.LIB_FILES, fromXml, "LIB_FILES is the XML's file list, in the XML's order")
end)

test("LibKa0s: every vendored library file the loader names exists on disk", function(t)
    for _, rel in ipairs(loader.LIB_FILES) do
        t.truthy(readFile(ROOT .. "/" .. rel) ~= nil, rel .. " is present under libs/")
    end
end)

test("LibKa0s: the TOC loads the library through its own packaged XML", function(t)
    local toc = readFile(ROOT .. "/ConsumableMaster.toc") or ""
    t.truthy(toc:find("libs\\LibKa0s\\LibKa0s.xml", 1, true) ~= nil,
        "TOC lists libs\\LibKa0s\\LibKa0s.xml")
    -- Naming module files individually is partial vendoring spelled
    -- differently, and it drifts the moment the library gains a file.
    t.falsy(toc:find("libs\\LibKa0s\\Core.lua", 1, true),
        "TOC does not name individual LibKa0s module files")
end)

test("LibKa0s: every declared major registers, and reports the minor of every one of its files",
    function(t)
        loader.loadPure()
        local missing = {}
        for _, spec in ipairs(MAJORS) do
            local lib = LibStub(spec.major)
            if not lib then
                missing[#missing + 1] = spec.major .. " (major absent)"
            else
                for _, file in ipairs(spec.files) do
                    local minor = lib.MODULES and lib.MODULES[file]
                    if type(minor) ~= "number" or minor < 1 or minor ~= math.floor(minor) then
                        missing[#missing + 1] = spec.major .. "." .. file ..
                            " minor = " .. tostring(minor)
                    end
                end
                local primaryMinor = lib.MODULES and lib.MODULES[spec.primary or spec.files[1]]
                if primaryMinor ~= lib.MINOR then
                    missing[#missing + 1] = spec.major .. ": MODULES." ..
                        (spec.primary or spec.files[1]) .. " (" .. tostring(primaryMinor) ..
                        ") disagrees with lib.MINOR (" .. tostring(lib.MINOR) .. ")"
                end
            end
        end
        -- Collected rather than asserted inside the loop: aborting on the first
        -- gap leaves the rest unchecked, which is how this shape of suite hides
        -- its second failure behind its first.
        t.eq(table.concat(missing, "; "), "", "every major registered with all of its files")
    end)

test("LibKa0s: no file registers under a major it does not belong to", function(t)
    loader.loadPure()
    local strays = {}
    for _, spec in ipairs(MAJORS) do
        local lib = LibStub(spec.major)
        local owned = {}
        for _, file in ipairs(spec.files) do owned[file] = true end
        for file in pairs((lib and lib.MODULES) or {}) do
            if not owned[file] then
                strays[#strays + 1] = spec.major .. " reports " .. file
            end
        end
    end
    t.eq(table.concat(strays, "; "), "", "each MODULES registry holds only its own major's files")
end)

test("LibKa0s: each attach file is paired to the shell minor it actually attached to", function(t)
    loader.loadPure()
    -- A secondary attached to a primary from a DIFFERENT vendored copy is the
    -- failure the per-module-major layout exists to prevent, and it is
    -- invisible without this: both files load, the major registers, and the
    -- instance looks whole.
    --
    -- Assert the PAIRING, not the number. Comparing MODULES[file] against the
    -- guard's own minor would be a tautology in a single-copy vendoring — both
    -- are written from the same constant three lines apart — and a tautology
    -- that reads as coverage is worse than no case at all (testing-§12).
    -- What can genuinely differ is whether the attach file ran (its guard
    -- field is set) and which shell it attached to.
    local bad = {}
    for _, spec in ipairs(MAJORS) do
        local lib = LibStub(spec.major)
        for _, pair in ipairs(spec.paired or {}) do
            local minor = lib[pair.minor]
            if type(minor) ~= "number" or minor < 1 then
                bad[#bad + 1] = pair.file .. " never attached (" .. pair.minor .. " = " ..
                    tostring(minor) .. ")"
            end
            if lib[pair.shell] ~= lib.MINOR then
                bad[#bad + 1] = pair.file .. " attached to shell minor " ..
                    tostring(lib[pair.shell]) .. ", but the live shell is " .. tostring(lib.MINOR)
            end
        end
    end
    t.eq(table.concat(bad, "; "), "", "every paired secondary names the live shell's minor")
end)

test("LibKa0s: library file basenames are unique across every vendored major", function(t)
    -- LibKa0s's own changelog check plain-searches one file for
    -- "<Basename> minor <N>", so two majors owning a same-named file would
    -- satisfy each other's assertion. The uniqueness holds downstream too:
    -- it is why the Options module ships OptionsWidgets.lua rather than the
    -- bare Widgets.lua a future window module would also want.
    local seen, dupes = {}, {}
    for _, spec in ipairs(MAJORS) do
        for _, file in ipairs(spec.files) do
            if seen[file] then dupes[#dupes + 1] = file end
            seen[file] = true
        end
    end
    t.eq(table.concat(dupes, ", "), "", "no basename is claimed by two majors")
end)

test("LibKa0s: omitting the vendored files leaves every major absent, not half-wired", function(t)
    -- The degraded scenario is loadable rather than hypothetical: four of the
    -- five majors return BEFORE LibStub:NewLibrary when Core is missing, so
    -- feeding the loader a deliberately partial file list is exactly the
    -- install a user with no libs/LibKa0s/ has. Every setup file's fallback is
    -- proven against this, not against a hand-written stub.
    loader.loadPureDegraded()
    for _, spec in ipairs(MAJORS) do
        t.falsy(LibStub(spec.major), spec.major .. " is absent when the files are not loaded")
    end
end)
