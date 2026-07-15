-- tests/harness.lua — tiny assertion + suite framework shared by every suite.
--
-- A suite file does:
--     local h = require("harness")
--     h.suite("name", function(t)
--         local KCM = h.loader.loadPure()
--         t.eq(actual, expected, "message")
--     end)
-- Assertions accumulate failures (they don't abort the suite) so one run
-- surfaces every problem. run.lua calls h.report() at the end.

local H = {}
-- Captured before any suite installs the mock (which clobbers global print to
-- capture addon chat output). Harness reporting must use this real print.
local realprint = print
H.print = realprint
H.loader = require("loader")

H._suites = {}
-- Set by run.lua to the current suite file (e.g. "test_bus.lua") around each
-- require, so H.suite can stamp every registered test with its origin file.
H._currentFile = nil
local current

local function fail(msg)
    if current then current.failures[#current.failures + 1] = msg end
end

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(val) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local T = {}

function T.eq(a, b, msg)
    if a ~= b then fail((msg or "eq") .. ": expected " .. fmt(b) .. ", got " .. fmt(a)) end
end

function T.ne(a, b, msg)
    if a == b then fail((msg or "ne") .. ": expected not " .. fmt(b)) end
end

function T.truthy(v, msg)
    if not v then fail((msg or "truthy") .. ": expected truthy, got " .. fmt(v)) end
end

function T.falsy(v, msg)
    if v then fail((msg or "falsy") .. ": expected falsy, got " .. fmt(v)) end
end

function T.near(a, b, eps, msg)
    eps = eps or 1e-9
    if type(a) ~= "number" or math.abs(a - b) > eps then
        fail((msg or "near") .. ": expected ~" .. fmt(b) .. ", got " .. fmt(a))
    end
end

-- Assert that array `a` equals array `b` element-by-element.
function T.eqList(a, b, msg)
    a, b = a or {}, b or {}
    if #a ~= #b then
        fail((msg or "eqList") .. ": length " .. #a .. " ~= " .. #b
            .. " (got " .. fmt(a) .. ", want " .. fmt(b) .. ")")
        return
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            fail((msg or "eqList") .. "[" .. i .. "]: got " .. fmt(a[i]) .. ", want " .. fmt(b[i]))
        end
    end
end

function T.contains(list, val, msg)
    for _, v in ipairs(list or {}) do if v == val then return end end
    fail((msg or "contains") .. ": " .. fmt(val) .. " not in " .. fmt(list))
end

-- Register a suite. Execution is deferred to H.run so a non-executing --list
-- pass can enumerate every suite without running any test body.
function H.suite(name, fn)
    H._suites[#H._suites + 1] = {
        name = name,
        fn = fn,
        suite = H._currentFile,
        failures = {},
    }
end

-- Run every registered suite in registration (require) order.
function H.run()
    for _, s in ipairs(H._suites) do
        current = s
        local ok, err = pcall(s.fn, T)
        if not ok then
            current.failures[#current.failures + 1] = "ERROR: " .. tostring(err)
        end
        current = nil
    end
end

-- Render the docs/test-cases.md body from a list of registered tests. Each
-- record carries `.suite` (the file it loaded from) and `.name` (the case).
-- Suites are grouped in first-seen order; cases keep registration order.
function H.formatInventory(suites)
    local order, byFile = {}, {}
    for _, s in ipairs(suites or {}) do
        local file = s.suite or "(unknown)"
        if not byFile[file] then
            byFile[file] = {}
            order[#order + 1] = file
        end
        local cases = byFile[file]
        cases[#cases + 1] = s.name
    end

    local out = {}
    out[#out + 1] = "# Test Cases"
    out[#out + 1] = ""
    out[#out + 1] = "_Generated — do not hand-edit. Regenerate with_ "
        .. "`lua tests/run.lua --list > docs/test-cases.md`."
    out[#out + 1] = ""

    local total = 0
    for _, file in ipairs(order) do
        local cases = byFile[file]
        total = total + #cases
        out[#out + 1] = string.format("### %s (%d)", file, #cases)
        out[#out + 1] = ""
        for _, name in ipairs(cases) do
            out[#out + 1] = "- " .. name
        end
        out[#out + 1] = ""
    end

    out[#out + 1] = "## Totals"
    out[#out + 1] = ""
    out[#out + 1] = "| Suite | Cases |"
    out[#out + 1] = "|-------|-------|"
    for _, file in ipairs(order) do
        out[#out + 1] = string.format("| %s | %d |", file, #byFile[file])
    end
    out[#out + 1] = string.format("| **Total** | **%d** |", total)
    out[#out + 1] = ""

    return table.concat(out, "\n")
end

function H.report()
    local passed, failed = 0, 0
    realprint("")
    for _, s in ipairs(H._suites) do
        if #s.failures == 0 then
            passed = passed + 1
            realprint(string.format("  \27[32mPASS\27[0m  %s", s.name))
        else
            failed = failed + 1
            realprint(string.format("  \27[31mFAIL\27[0m  %s", s.name))
            for _, f in ipairs(s.failures) do
                realprint("          " .. f)
            end
        end
    end
    realprint("")
    realprint(string.format("  %d passed, %d failed, %d total", passed, failed, passed + failed))
    return failed == 0
end

return H
