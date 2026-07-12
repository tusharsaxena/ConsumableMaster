-- tests/run.lua — headless test entry point.
--
-- Usage (from the addon root):   lua5.1 tests/run.lua
-- Discovers every tests/test_*.lua, runs it under the WoW mock, and exits
-- non-zero if any assertion failed (so it can gate commits / CI).

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

for _, name in ipairs(suites) do
    require(name)
end

local ok = h.report()
os.exit(ok and 0 or 1)
