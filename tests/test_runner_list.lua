-- tests/test_runner_list.lua — the runner's non-executing --list inventory mode.
local h = require("harness")

h.suite("runner --list inventory", function(t)
    -- formatInventory groups registered tests by their `suite` field (the file
    -- they loaded from), in first-seen order, counts cases per suite, and emits
    -- the docs/test-cases.md body.
    local sample = {
        { suite = "test_bus.lua", name = "message bus", failures = {} },
        { suite = "test_bus.lua", name = "bus retry", failures = {} },
        { suite = "test_id.lua", name = "ID sentinels", failures = {} },
    }
    local body = h.formatInventory(sample)
    t.truthy(body, "formatInventory returns a body")
    t.truthy(body:find("# Test Cases", 1, true), "has # Test Cases header")
    t.truthy(body:find("run.lua --list > docs/test-cases.md", 1, true), "has regen note")
    t.truthy(body:find("### test_bus.lua (2)", 1, true), "bus section counts 2")
    t.truthy(body:find("### test_id.lua (1)", 1, true), "id section counts 1")
    t.truthy(body:find("- message bus", 1, true), "lists case as bullet")
    t.truthy(body:find("- bus retry", 1, true), "lists second bus case")
    t.truthy(body:find("## Totals", 1, true), "has Totals section")
    t.truthy(body:find("| **Total** | **3** |", 1, true), "total row = 3")
end)

h.suite("runner --list is non-executing", function(t)
    -- Shelling out is safe: the subprocess registers suites but runs none in
    -- --list mode, so it never re-enters this suite (no recursion).
    local root = _G.KCM_TEST_ROOT or "."
    local cmd = "lua5.1 " .. root .. "/tests/run.lua --list"

    local pipe = io.popen(cmd .. " 2>&1")
    local out = pipe:read("*a") or ""
    pipe:close()
    t.truthy(out:find("# Test Cases", 1, true), "--list prints the inventory")
    t.truthy(out:find("## Totals", 1, true), "--list prints the totals table")
    t.falsy(out:find("passed,", 1, true), "--list runs no tests")

    -- os.execute returns the raw exit status in Lua 5.1.
    local code = os.execute(cmd .. " > /dev/null 2>&1")
    t.eq(code, 0, "--list exits 0")
end)
