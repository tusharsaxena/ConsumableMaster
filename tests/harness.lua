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

function H.suite(name, fn)
    current = { name = name, failures = {} }
    H._suites[#H._suites + 1] = current
    local ok, err = pcall(fn, T)
    if not ok then
        current.failures[#current.failures + 1] = "ERROR: " .. tostring(err)
    end
    current = nil
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
