-- tests/run.lua — headless test entry point.
--
-- Usage (from the addon root):   lua5.1 tests/run.lua
--                                lua5.1 tests/run.lua --list
-- Discovers every tests/test_*.lua, runs it under the WoW mock, and exits
-- non-zero if any assertion failed (so it can gate commits).
--
-- With --list, loads every suite but runs nothing: prints the docs/test-cases.md
-- inventory body to stdout and exits 0. Regenerate the inventory with:
--     lua tests/run.lua --list > docs/test-cases.md

local function scriptDir()
    local src = arg and arg[0] or "tests/run.lua"
    return (src:match("^(.*)[/\\]tests[/\\]run%.lua$")) or "."
end

local ROOT = scriptDir()
_G.KCM_TEST_ROOT = ROOT
package.path = ROOT .. "/tests/?.lua;" .. package.path

local h = require("harness")

-- Discover test_*.lua deterministically without relying on LuaFileSystem:
-- shell out to `ls` (portable enough for this WSL/Linux dev env), fall back to
-- an explicit list if that fails.
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

local listMode = false
for _, a in ipairs(arg or {}) do
    if a == "--list" then listMode = true end
end

for _, name in ipairs(suites) do
    h._currentFile = name .. ".lua"
    require(name)
end
h._currentFile = nil

if listMode then
    io.write(h.formatInventory(h._suites))
    os.exit(0)
end

h.run()
local ok = h.report()
os.exit(ok and 0 or 1)
