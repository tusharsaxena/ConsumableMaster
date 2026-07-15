-- tests/test_runner_list.lua — the runner's non-executing --list inventory mode.

local h = require("harness")
local test = h.test

test("formatInventory groups cases by suite file with counts", function(t)
    local sample = {
        { suite = "test_bus.lua", name = "bus publishes" },
        { suite = "test_bus.lua", name = "bus routes recompute" },
        { suite = "test_id.lua", name = "AsSpell negates" },
    }
    local body = h.formatInventory(sample)
    t.truthy(body:find("# Test Cases", 1, true), "has # Test Cases header")
    t.truthy(body:find("run.lua --list > docs/test-cases.md", 1, true), "has regen note")
    t.truthy(body:find("### test_bus.lua (2)", 1, true), "bus section counts 2")
    t.truthy(body:find("### test_id.lua (1)", 1, true), "id section counts 1")
    t.truthy(body:find("- bus publishes", 1, true), "lists case as bullet")
    t.truthy(body:find("- AsSpell negates", 1, true), "lists id case as bullet")
end)

test("formatInventory emits a Totals table summing all cases", function(t)
    local sample = {
        { suite = "test_bus.lua", name = "a" },
        { suite = "test_bus.lua", name = "b" },
        { suite = "test_id.lua", name = "c" },
    }
    local body = h.formatInventory(sample)
    t.truthy(body:find("## Totals", 1, true), "has Totals section")
    t.truthy(body:find("| **Total** | **3** |", 1, true), "total row = 3")
end)

test("--list prints the inventory and runs no tests", function(t)
    -- Safe from recursion: in --list mode the subprocess registers cases but
    -- runs none, so it never re-enters this case.
    local root = _G.KCM_TEST_ROOT or "."
    local cmd = "lua5.1 " .. root .. "/tests/run.lua --list"
    local pipe = io.popen(cmd .. " 2>&1")
    local out = pipe:read("*a") or ""
    pipe:close()
    t.truthy(out:find("# Test Cases", 1, true), "--list prints the inventory")
    t.truthy(out:find("## Totals", 1, true), "--list prints the totals table")
    t.falsy(out:find("passed,", 1, true), "--list runs no tests")
end)

test("--list exits 0 without running the suite", function(t)
    local root = _G.KCM_TEST_ROOT or "."
    -- os.execute returns the raw exit status in Lua 5.1.
    local code = os.execute("lua5.1 " .. root .. "/tests/run.lua --list > /dev/null 2>&1")
    t.eq(code, 0, "--list exits 0")
end)
