-- tests/harness.lua — headless test framework shared by every suite.
--
-- Fleet test() model (mirrors the Ka0s reference runner): a suite file does
--     local h = require("harness")
--     local test = h.test
--     test("case name", function(t)
--         local KCM = h.loader.loadPure()   -- fresh, fully-reset mock per case
--         t.eq(actual, expected)            -- assertions error on first failure
--     end)
-- run.lua stamps every registered case with its origin file, then runs one
-- pcall per case so each is an independently-counted PASS/FAIL. `--list`
-- enumerates every case into docs/test-cases.md.

local H = {}
-- Captured before any suite installs the mock (which clobbers global print to
-- capture addon chat output). Harness output must use this real print.
local realprint = print
H.print = realprint
H.loader = require("loader")

H._tests = {}
-- Set by run.lua to the current suite file (e.g. "test_bus.lua") around each
-- require, so every case registered by that file is stamped with its origin.
H._currentFile = nil

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(val) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

-- Build an assertion table whose failures route to `onFail(msg)`. Test cases
-- get an error-raising table (first failure aborts the case); the legacy
-- h.suite shim gets an accumulating one (collects every failure).
local function makeAssertions(onFail)
    local A = {}
    function A.eq(a, b, msg)
        if a ~= b then onFail((msg or "eq") .. ": expected " .. fmt(b) .. ", got " .. fmt(a)) end
    end
    function A.ne(a, b, msg)
        if a == b then onFail((msg or "ne") .. ": expected not " .. fmt(b)) end
    end
    function A.truthy(v, msg)
        if not v then onFail((msg or "truthy") .. ": expected truthy, got " .. fmt(v)) end
    end
    function A.falsy(v, msg)
        if v then onFail((msg or "falsy") .. ": expected falsy, got " .. fmt(v)) end
    end
    function A.near(a, b, eps, msg)
        eps = eps or 1e-9
        if type(a) ~= "number" or math.abs(a - b) > eps then
            onFail((msg or "near") .. ": expected ~" .. fmt(b) .. ", got " .. fmt(a))
        end
    end
    -- Assert array `a` equals array `b` element-by-element.
    function A.eqList(a, b, msg)
        a, b = a or {}, b or {}
        if #a ~= #b then
            onFail((msg or "eqList") .. ": length " .. #a .. " ~= " .. #b
                .. " (got " .. fmt(a) .. ", want " .. fmt(b) .. ")")
            return
        end
        for i = 1, #a do
            if a[i] ~= b[i] then
                onFail((msg or "eqList") .. "[" .. i .. "]: got " .. fmt(a[i]) .. ", want " .. fmt(b[i]))
            end
        end
    end
    function A.contains(list, val, msg)
        for _, v in ipairs(list or {}) do if v == val then return end end
        onFail((msg or "contains") .. ": " .. fmt(val) .. " not in " .. fmt(list))
    end
    return A
end

-- Error-style assertions handed to every test() case.
local T = makeAssertions(function(msg) error(msg, 2) end)
H.T = T

-- ── skip: the third case status ────────────────────────────────────────────
--
-- A case that CANNOT look — no sibling checkout, no git, a fixture this
-- platform cannot produce — used to be written as a bare `return`, which
-- registers as PASS. That is a gate reporting "checked, fine" for a check that
-- never ran. `H.skip(reason)` raises a sentinel instead, so it can be called
-- from any depth inside a case body (inside a helper, inside a loop) without
-- restructuring the case into a predicate plus a body.
--
-- Two properties, both non-negotiable, both mirroring tests/_kit/framework.lua:
--   * a skip is NEVER folded into `passed` — the README [tests] badge and
--     docs/test-cases.md count passes, and a skip counted as one is the
--     original lie in a new place;
--   * a skip NEVER changes the exit code. A skip is "not evaluated", which is
--     a fact for the release flow to judge, not a failure re-litigated here.
--
-- This is the private harness's half of the contract tests/_kit/vendor_sync.lua
-- depends on; it goes away with the harness itself when the kit becomes the
-- runner.
local SKIP = {}

--- Abandon the current case with a reason, reported as SKIP rather than PASS or FAIL.
function H.skip(reason)
    error(setmetatable({ reason = tostring(reason or "no reason given") }, SKIP), 0)
end
T.skip = H.skip

--- The reason, if `err` is a skip sentinel; nil for any other error value.
local function skipReasonOf(err)
    if type(err) == "table" and getmetatable(err) == SKIP then return err.reason end
    return nil
end

-- Register one test case. Execution is deferred to H.run so a non-executing
-- --list pass can enumerate cases without running them.
function H.test(name, fn)
    H._tests[#H._tests + 1] = { name = name, fn = fn, suite = H._currentFile }
end

-- Legacy shim: an old h.suite(name, fn) becomes a single case running all its
-- accumulate-style assertions, failing if any did. Lets suites migrate to
-- test() incrementally while the gate stays green. Removed once none remain.
function H.suite(name, fn)
    H._tests[#H._tests + 1] = {
        name = name,
        suite = H._currentFile,
        fn = function()
            local fails = {}
            local A = makeAssertions(function(msg) fails[#fails + 1] = msg end)
            fn(A)
            if #fails > 0 then error(table.concat(fails, "\n          "), 2) end
        end,
    }
end

-- Run every registered case in registration order; one pcall per case.
function H.run()
    local passed, failed, skipped = 0, 0, 0
    realprint("")
    for _, tc in ipairs(H._tests) do
        local ok, err = pcall(tc.fn, T)
        local reason = (not ok) and skipReasonOf(err) or nil
        if reason then
            skipped = skipped + 1
            realprint(string.format("  \27[33mSKIP\27[0m  %s — %s", tc.name, reason))
        elseif ok then
            passed = passed + 1
            realprint(string.format("  \27[32mPASS\27[0m  %s", tc.name))
        else
            failed = failed + 1
            realprint(string.format("  \27[31mFAIL\27[0m  %s", tc.name))
            realprint("          " .. tostring(err))
        end
    end
    realprint("")
    -- The skipped column appears only when something was skipped. The vendored
    -- tests/_kit/run-automated-tests.sh scrapes this line with
    -- `[0-9]+ passed, [0-9]+ failed(, [0-9]+ total)?`, so an unconditional
    -- column would cost every ordinary run its recorded total.
    if skipped > 0 then
        realprint(string.format("  %d passed, %d failed, %d skipped, %d total",
            passed, failed, skipped, passed + failed + skipped))
    else
        realprint(string.format("  %d passed, %d failed, %d total", passed, failed, passed + failed))
    end
    return failed == 0
end

-- Render the docs/test-cases.md body from the registered cases, grouped by
-- suite file. Format mirrors the Ka0s fleet runner so every addon's inventory
-- reads alike. Suites appear in first-seen order; cases keep registration order.
--
-- CRLF-terminated HERE rather than left to a `| sed 's/$/\r/'` on the command
-- line: .gitattributes pins `*.md text eol=crlf`, a plain redirect writes LF,
-- and the file then sits in the working tree on the wrong side of the policy
-- while `git status` stays clean — which is invisible until a byte-level diff
-- somewhere else has to explain itself. tests/_kit/framework.lua's own
-- renderer carries the same note; this one had drifted from it.
function H.formatInventory(tests)
    local order, byFile = {}, {}
    for _, tc in ipairs(tests or {}) do
        local file = tc.suite or "(unknown)"
        if not byFile[file] then byFile[file] = {}; order[#order + 1] = file end
        local cases = byFile[file]
        cases[#cases + 1] = tc.name
    end

    local out, total = {}, 0
    local function line(s) out[#out + 1] = s end
    line("# Test Cases")
    line("")
    line("The full inventory of every headless test case, grouped by suite. This file is the")
    line("**authoritative pass count** for the addon.")
    line("")
    line("**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`")
    line("whenever the suite changes.")
    line("")
    for _, file in ipairs(order) do
        local cases = byFile[file]
        total = total + #cases
        line(string.format("### %s (%d)", file, #cases))
        line("")
        for _, name in ipairs(cases) do line("- " .. name) end
        line("")
    end
    line("## Totals")
    line("")
    line("| Suite | Cases |")
    line("|-------|------:|")
    for _, file in ipairs(order) do
        line(string.format("| %s | %d |", file, #byFile[file]))
    end
    line(string.format("| **Total** | **%d** |", total))
    line("")
    return table.concat(out, "\r\n")
end

return H
