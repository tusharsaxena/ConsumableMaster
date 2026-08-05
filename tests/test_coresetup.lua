-- test_coresetup.lua — core/CoreSetup.lua: the addon's half of
-- LibKa0s-Core-1.0.
--
-- tests/test_constants.lua already pins what KCM.Say and KCM.SafeToString
-- RENDER, byte for byte, and those cases are deliberately left alone: they were
-- written against the host implementation and they are the oracle for the swap.
-- What this suite adds is the part they cannot see — that the rendering is now
-- coming from the library rather than from a host copy that happens to agree,
-- and that the addon still speaks when the library is not installed.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

-- The vendored Core source, for the library tripwire at the foot of this file.
local function readCoreSource()
    local root = _G.KCM_TEST_ROOT or "."
    local f = assert(io.open(root .. "/libs/LibKa0s/Core.lua", "r"),
        "cannot open libs/LibKa0s/Core.lua (tests run from the repo root)")
    local src = f:read("*a")
    f:close()
    return src
end

test("CoreSetup: the addon's stringifier IS the library's, not a lookalike", function(t)
    local KCM = loader.loadPure()
    local core = LibStub("LibKa0s-Core-1.0")
    t.truthy(core, "LibKa0s-Core-1.0 registered")
    -- Identity, not equivalence. Two functions that agree today are exactly the
    -- seven-way drift the extraction exists to end, and a behavioral assertion
    -- passes just as happily against a host copy left in place — which is what
    -- "the swap silently no-opped" looks like from the outside.
    t.eq(KCM.SafeToString, core.SafeToString, "KCM.SafeToString is the library function object")
    t.eq(KCM.IsConcatSafe, core.IsConcatSafe, "KCM.IsConcatSafe is the library function object")
end)

test("CoreSetup: the secret sentinel is the library's, so the docs cannot drift from it", function(t)
    local KCM = loader.loadPure()
    local core = LibStub("LibKa0s-Core-1.0")
    local hostile = setmetatable({}, { __tostring = function() return "hostile" end })
    t.eq(KCM.SafeToString(hostile), core.SECRET, "an unrenderable value renders as lib.SECRET")
    t.eq(core.SECRET, "<secret>", "and lib.SECRET is still the spelling the suites assert on")
end)

test("CoreSetup: the prefix is re-read on every line, not frozen at load", function(t)
    local KCM  = loader.loadPure()
    local mock = loader.mock
    -- The printer is built ONCE, at load. Passing the tag as a value would
    -- freeze it there; passing a function is what keeps KCM.PREFIX the single
    -- source of truth the macro bodies and the category emptyText also read.
    local original = KCM.PREFIX
    KCM.PREFIX = "|cff00ffff[ZZ]|r"
    mock.output = {}
    KCM.Say("after")
    KCM.PREFIX = original
    t.eq(mock.output[1], "|cff00ffff[ZZ]|r after", "the line carries the CURRENT prefix")
end)

test("CoreSetup: chat still lands in the global print, which is where the harness listens",
    function(t)
        local KCM  = loader.loadPure()
        local mock = loader.mock
        -- The library's default sink is DEFAULT_CHAT_FRAME:AddMessage, which
        -- this addon has never used and the mock does not record. Without an
        -- explicit sink every chat assertion in the suite would go silent
        -- rather than red — 180-odd call sites' worth.
        mock.output = {}
        KCM.Say("routed")
        t.eq(#mock.output, 1, "exactly one captured line")
    end)

test("CoreSetup: with the library absent the addon still prints, and says why once", function(t)
    -- Loaded for real with libs/LibKa0s/ omitted, so core/CoreSetup.lua takes
    -- its own fallback. A test that hand-stubs the member it then asserts on
    -- proves only that the test can write a table (testing-§8).
    local KCM  = loader.loadPureDegraded()
    local mock = loader.mock
    t.falsy(LibStub("LibKa0s-Core-1.0"), "the major really is absent")
    mock.output = {}
    KCM.Say("first")
    KCM.Say("second")
    t.truthy(#mock.output >= 3, "the notice plus both lines")
    local joined = table.concat(mock.output, "\n")
    t.truthy(joined:find("LibKa0s", 1, true), "the notice names the missing library")
    t.eq(mock.output[#mock.output], KCM.PREFIX .. " second", "ordinary lines still render normally")
    -- Once, not per call. A degraded install is still an install someone plays.
    local notices = 0
    for _, line in ipairs(mock.output) do
        if line:find("LibKa0s", 1, true) then notices = notices + 1 end
    end
    t.eq(notices, 1, "the missing-library notice is said exactly once")
end)

test("CoreSetup: the degraded stringifier answers the same sentinel as the library", function(t)
    local KCM = loader.loadPureDegraded()
    local hostile = setmetatable({}, { __tostring = function() return "hostile" end })
    -- The fallback is the pre-library implementation, kept short. It may not
    -- copy the library's FORMATTERS, but the sentinel is a contract the rest of
    -- the addon and its suites read, so it has to be the same spelling.
    t.eq(KCM.SafeToString(hostile), "<secret>", "the fallback masks an unrenderable value")
    t.eq(KCM.SafeToString(nil), "nil", "and still renders nil as the literal")
    t.eq(KCM.SafeToString(false), "false", "and does not mask a boolean")
end)

-- ── the L trap, such as it applies to Core ─────────────────────────────────────
--
-- Every other adopted major in this addon carries a case proving its rendered
-- strings resolve to prose rather than to their own keys. Core cannot: it has no
-- STRINGS table and reads no descriptor `L`, so there is no fall-through to
-- assert on. Writing one anyway would be a case that could never fail, which is
-- worse than no case at all (testing-§8).
--
-- So the guard points at the LIBRARY instead of at this addon. The day Core
-- grows a user-visible string, this goes red and whoever bumps that minor writes
-- the real fall-through assertion the other four majors already have. The same
-- substitute AbsorbTracker and KickCD wrote for the same structurally-empty cell.

test("CoreSetup: LibKa0s-Core-1.0 still has no user-visible strings to trap", function(t)
    -- red under: adding a `lib.STRINGS = { ... }` table or a `d.L` read to
    -- libs/LibKa0s/Core.lua
    loader.loadPure()   -- registers the vendored majors; LibStub is empty before this
    local core = LibStub("LibKa0s-Core-1.0")
    t.truthy(core, "the vendored Core major must be registered")
    t.falsy(core.STRINGS,
        "Core now ships STRINGS — this major needs an L-trap assertion of its own")

    local src = readCoreSource()
    t.falsy(src:match("STRINGS"), "Core.lua now names STRINGS")
    t.falsy(src:match("d%.L[^%w_]"), "Core.lua now reads a descriptor L")
end)

test("CoreSetup: the prefix is the only library-rendered fragment, and it is prose", function(t)
    -- The rendered half, such as it is. The prefix is the one string the library
    -- puts on screen in this major and it is ours, so pin that it is prose and
    -- nothing key-shaped leaks into it.
    -- red under: KCM.PREFIX = "ADDON_PREFIX" in core/Constants.lua
    local KCM  = loader.loadPure()
    local mock = loader.mock
    mock.output = {}
    KCM.Say("hello")
    local line = mock.output[#mock.output]
    t.truthy(line, "the printer rendered a line")
    -- Strip color codes before testing the shape: |cff...|r is not prose but it
    -- is not a key either.
    local bare = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local tag = bare:match("^(%S+)")
    t.truthy(tag, "the line carries a prefix tag")
    t.falsy(tag:match("^[A-Z][A-Z0-9_]+$"),
        "the prefix resolved to prose, not to a SCREAMING_SNAKE key: " .. tostring(tag))
end)
