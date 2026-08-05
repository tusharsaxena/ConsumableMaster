-- tests/test_runner_list.lua — the runner's non-executing --list inventory mode.
--
-- The renderer is the vendored kit's (tests/_kit/framework.lua), not a private one,
-- so these cases assert on what the runner actually PRINTS rather than on a
-- renderer function called with a hand-built registry. That is the stronger check
-- either way: docs/test-cases.md is regenerated from exactly this stdout, so what
-- is asserted here is the artifact itself, not a stand-in for it.

local h = _G.KCM_TEST
local test = h.test

-- One subprocess, memoised across the cases below. Safe from recursion: in --list
-- mode the child registers cases but runs none, so it never re-enters this file's
-- bodies.
local listing
local function listOutput()
    if not listing then
        local root = _G.KCM_TEST_ROOT or "."
        local pipe = io.popen("lua5.1 " .. root .. "/tests/run.lua --list 2>&1")
        listing = pipe:read("*a") or ""
        pipe:close()
    end
    return listing
end

test("--list groups cases by suite file with counts", function(t)
    local out = listOutput()
    t.truthy(out:find("# Test Cases", 1, true), "has # Test Cases header")
    t.truthy(out:find("run.lua --list > docs/test-cases.md", 1, true), "has regen note")
    t.truthy(out:find("### test_bus.lua (", 1, true), "bus section carries a count")
    t.truthy(out:find("### test_id.lua (", 1, true), "id section carries a count")
    t.truthy(out:find("\n- ", 1, true), "cases are listed as bullets")
end)

test("--list emits a Totals table summing all cases", function(t)
    local out = listOutput()
    t.truthy(out:find("## Totals", 1, true), "has Totals section")
    local total = tonumber(out:match("|%s*%*%*Total%*%*%s*|%s*%*%*(%d+)%*%*%s*|"))
    t.truthy(total, "the Totals row reports a number")
    local sum = 0
    for n in out:gmatch("### test_[%w_]+%.lua %((%d+)%)") do sum = sum + tonumber(n) end
    t.truthy(sum > 0, "at least one suite section was counted")
    t.eq(total, sum, "the Totals row is the sum of the per-suite counts")
end)

test("--list prints the inventory and runs no tests", function(t)
    local out = listOutput()
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
