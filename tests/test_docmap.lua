-- tests/test_docmap.lua — the Tier 2 documentation map says what docs/ actually holds.
--
-- WHAT IT PROVES. That every row in ARCHITECTURE.md's `### Conditional (documentation-§3, Tier 2)`
-- table agrees with the directory: a row filed **Present** names a file that exists, and a row filed
-- **Not applicable** names one that does not.
--
-- WHY IT EXISTS. `documentation-§3` makes *Not applicable* a valid state that MUST be stated rather
-- than left to an empty directory listing, and that is the right rule — an audit reading `ls docs/`
-- alone cannot tell "this addon does not need the page" from "nobody has written it yet". The cost
-- is that the row is now the only witness, and a wrong row is worse than a missing one. This repo
-- carried two: `compat-layer.md` filed as "no addon-specific shim to document separately" against
-- six shims in core/Compat.lua, and `slash-dispatch.md` filed as "a flat set with no subcommand
-- tree" against seventeen verbs and five sub-command tables. Both survived every audit that read the
-- register, because the register was the thing being read.
--
-- WHAT IT DELIBERATELY DOES NOT CHECK. Whether the trigger has fired. That is prose — "beyond what
-- LibKa0s supplies", "of the addon's own" — and it stays a human's to read. The STATUS is not prose,
-- and this is the half a machine can hold.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. An unreadable ARCHITECTURE.md, or a Conditional
-- section this parser cannot find, is a failure and not a skip: a gate that goes quiet when it is
-- blind reports success. Same bargain tests/test_prose.lua and tests/_kit/test_eol.lua strike.

local h = _G.KCM_TEST
local test, fail = h.test, h.fail
local ROOT = _G.KCM_TEST_ROOT or "."

local function readFile(path)
    local fh = io.open(ROOT .. "/" .. path, "r")
    if not fh then
        fail("doc-map gate: cannot open " .. path .. "; this gate cannot run and must not be "
            .. "reported as passing", 3)
    end
    local body = fh:read("*a") or ""
    fh:close()
    return body
end

local function exists(path)
    local fh = io.open(ROOT .. "/" .. path, "r")
    if fh then fh:close() return true end
    return false
end

test("docmap: every Tier 2 row agrees with what docs/ holds", function(t)
    local body = readFile("docs/ARCHITECTURE.md"):gsub("\r\n", "\n")
    local section = body:match("### Conditional[^\n]*\n(.-)\n###")
    if not section then
        fail("doc-map gate: docs/ARCHITECTURE.md has no `### Conditional ... Tier 2` section "
            .. "followed by another `###` heading, so the rows cannot be read", 2)
    end

    local rows, offenders = 0, {}
    for doc, status in section:gmatch("|%s*`([^`]+)`%s*|%s*([^|]-)%s*|") do
        if status == "Present" or status == "Not applicable" then
            rows = rows + 1
            local present = exists("docs/" .. doc)
            if status == "Present" and not present then
                offenders[#offenders + 1] = doc .. ": filed Present, docs/" .. doc .. " does not exist"
            elseif status == "Not applicable" and present then
                offenders[#offenders + 1] = doc .. ": filed Not applicable, docs/" .. doc .. " exists"
            end
        end
    end

    t.truthy(rows >= 5, "read " .. rows .. " Tier 2 rows; the table shape changed and this parser "
        .. "is now measuring nothing")

    if #offenders > 0 then
        fail(#offenders .. " Tier 2 documentation-map row(s) disagree with the directory. The row "
            .. "is the only thing an auditor reads, so a wrong one is worse than a missing page:\n"
            .. "          " .. table.concat(offenders, "\n          "), 2)
    end
end)
