-- tests/test_sample_names.lua — one source of sample names (FB2-CM-01, LibKa0s#104).
--
-- WHY. The Ka0s collection keeps every named sample person a test mode, sim, preview or sample
-- line draws in the library: LibKa0s-Sim-1.0's `Sample()` protagonists and, from v1.113.0,
-- `SampleCrowd()`. The convention's rule 6 ("roster pools do not converge") is retired, so an
-- addon's own `Sample*`/`Mock*` list is now drift (standard v2.120.0, decision D1 of the
-- 2026-11-24 feedback batch).
--
-- THIS ADDON DRAWS NO SAMPLE PERSON. It shows consumables, and the unlocked macro bar is its
-- preview (the options-ui-§15 exemption), so it has nothing to move onto the library. This gate
-- keeps it that way: a `Sample*`/`Mock*` name literal (`Sample` or `Mock` then lowercase letters,
-- the convention's name shape, `Samplerealm` and `Mockrealm` among them) may live only under
-- `tests/`. `libs/` is the library's own, and the frozen bundles under `docs/` are history.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK: no io.popen, no git, or no tracked file.

local h = _G.KCM_TEST
local test, fail = h.test, h.fail
local ROOT = _G.KCM_TEST_ROOT or "."

local SKIPPED_PREFIXES = {
    "tests/", "libs/",
    "docs/audits/", "docs/reviews/", "docs/automated-tests/", "docs/perf-analysis/",
    "docs/revendor/", "docs/superpowers/",
}

-- Text files only: the binaries (art, fonts) carry no names and would only slow the scan.
local TEXT_EXTENSIONS = { lua = true, toc = true, xml = true, md = true, txt = true, json = true }

--- Every `Sample*`/`Mock*` name literal in `text`, in order.
local function sampleNames(text)
    local found = {}
    for word in text:gmatch("%f[%w_]%u%l+") do
        if word:match("^Sample%l+$") or word:match("^Mock%l+$") then found[#found + 1] = word end
    end
    return found
end

local function skipped(path)
    for _, prefix in ipairs(SKIPPED_PREFIXES) do
        if path:sub(1, #prefix) == prefix then return true end
    end
    local ext = path:match("%.([%w]+)$")
    return not (ext and TEXT_EXTENSIONS[ext:lower()])
end

--- Every tracked text path outside the skipped trees.
local function trackedText()
    if not io.popen then
        fail("sample names gate: io.popen is unavailable, so this gate cannot run", 2)
    end
    local pipe = io.popen("git -C '" .. ROOT .. "' ls-files -z")
    if not pipe then
        fail("sample names gate: io.popen returned no handle for `git ls-files`, so this gate cannot run", 2)
    end
    local blob = pipe:read("*a") or ""
    pipe:close()
    local paths = {}
    for path in blob:gmatch("([^%z]+)") do
        if not skipped(path) then paths[#paths + 1] = path end
    end
    if #paths == 0 then
        fail("sample names gate: `git ls-files` reported no file, so this gate cannot run", 2)
    end
    return paths
end

test("sample names: the matcher sees the convention's names and nothing else", function(t)
    local found = sampleNames('local a = "Samplewarrior-Samplerealm"; local b = { "Mockpriest" }')
    t.eqList(found, { "Samplewarrior", "Samplerealm", "Mockpriest" },
        "a planted name, its realm and a Mock name are each flagged")
    t.eq(#sampleNames("Sim.Sample(client), Sim.SampleCrowd(client, 8, 1), Sample, Mock, SAMPLE"), 0,
        "the library's own calls and the bare words are not names")
    t.eq(#sampleNames("ExampleSamplewarrior unSamplewarrior"), 0, "a name inside a word is not a literal")
end)

test("sample names: no Sample*/Mock* name lives outside tests/ (LibKa0s#104)", function(t)
    local hits = {}
    for _, path in ipairs(trackedText()) do
        local fh = io.open(ROOT .. "/" .. path, "r")
        if not fh then
            fail("sample names gate: git tracks " .. path .. " but it could not be opened", 2)
        end
        local lineNo = 0
        for line in fh:lines() do
            lineNo = lineNo + 1
            for _, name in ipairs(sampleNames(line)) do
                hits[#hits + 1] = path .. ":" .. lineNo .. " " .. name
            end
        end
        fh:close()
    end
    t.eq(#hits, 0, "every sample person comes from LibKa0s Sim.Sample()/SampleCrowd(), never a literal: "
        .. table.concat(hits, ", "))
end)
