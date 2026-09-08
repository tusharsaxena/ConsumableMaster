-- tests/test_layout_cap.lua — the 1500-line cap gate (layout-§1).
--
-- WHAT IT PROVES. That no authored `.lua` file this repository tracks sits over layout-§1's
-- 1500-line cap without a disposition, and that no disposition outlives the breach it was written
-- for. It reads the tracked set from git and the census table from docs/ARCHITECTURE.md, and
-- compares the two in BOTH directions.
--
-- WHY IT EXISTS, in this repo specifically. `tests/test_settingsui.lua` crossed the cap at 1528 in
-- `393102f`, three commits into the very remediation cycle that was meant to settle this, and
-- nothing anywhere said so. The 2026-09-07 audit had measured it at 1461 and was right to file
-- nothing; `docs/automated-tests/RESULTS.md`'s band table still reads `tests/test_macrobar.lua`
-- at 1688 against 1904 today and does not know the second file exists at all. That is exactly the
-- state layout-§1 refuses — "the count sitting in a bundle manifest that no document reads" — and
-- a census written once and never re-checked would become the same thing within a month. This is
-- the thing that watches.
--
-- WHAT IT DOES NOT ASSERT: the line figures printed in the census. They are dated measurements,
-- and pinning them would redden the suite on every ordinary edit to a large file — a gate with a
-- standing reason to be switched off stops being run. Membership is the invariant; the numbers are
-- prose.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No `io.popen`, no git, no ARCHITECTURE.md, no
-- census heading — every one of those is a failure, not a skip. A gate that goes quiet when it is
-- blind reports success, which is worse than not existing. Same bargain tests/_kit/test_eol.lua
-- strikes.

local h = _G.KCM_TEST
local test, fail = h.test, h.fail
local ROOT = _G.KCM_TEST_ROOT or "."

local CAP = 1500
local ARCHITECTURE = "/docs/ARCHITECTURE.md"
local CENSUS_HEADING = "### Files over the 1500-line cap"

--- Split a NUL-delimited blob. `git ls-files -z` because a path may contain anything but NUL, and
--- the line-oriented form quotes such a path instead of printing it — a quoted path would not
--- match a file on disk, and this gate would then report a breach that is really a parse failure.
local function splitNul(blob)
    local out, start = {}, 1
    while true do
        local i = blob:find("\0", start, true)
        if not i then break end
        if i > start then out[#out + 1] = blob:sub(start, i - 1) end
        start = i + 1
    end
    return out
end

--- Every authored `.lua` path git tracks, in git's order.
---
--- The tracked set rather than a directory walk: Lua 5.1 has no directory API, and an untracked
--- scratch file is not something the cap has an opinion about. `libs/` and `tests/_kit/` are
--- dropped because they are the one carve-out that reaches this repository — vendored code arrives
--- by whole-folder copy and is audited where it is written, so the cap does not bind a file this
--- repo MUST NOT edit (`tests/test_vendor_sync.lua` is what holds that line). The second carve-out,
--- generated non-shipping data, has no instance here; if one ever arrives it needs a rule in this
--- function, and a red is the prompt to write it.
local function trackedAuthoredLua()
    if not io.popen then
        fail("layout cap gate: io.popen is unavailable, so the tracked set cannot be read and this "
            .. "gate must not be reported as passing", 2)
    end
    local pipe = io.popen("git -C '" .. ROOT .. "' ls-files -z -- '*.lua'")
    if not pipe then
        fail("layout cap gate: io.popen returned no handle for `git ls-files`, so this gate cannot "
            .. "run and must not be reported as passing", 2)
    end
    local blob = pipe:read("*a") or ""
    pipe:close()

    local paths = {}
    for _, path in ipairs(splitNul(blob)) do
        if not (path:find("^libs/") or path:find("^tests/_kit/")) then
            paths[#paths + 1] = path
        end
    end
    if #paths == 0 then
        fail("layout cap gate: `git ls-files` reported no tracked .lua files, which cannot be true "
            .. "here — either git is unavailable or this is not a repository; this gate cannot run, "
            .. "and must not be reported as passing", 2)
    end
    return paths
end

--- Lines in `path`, counted as `wc -l` counts them, plus a final unterminated line if there is one.
--- Returns nil when the file cannot be opened, which the callers report rather than skip.
---
--- Counted on LF alone. The working tree is pinned CRLF (line-endings-§2) so every terminator here
--- is `\r\n`, and counting the `\n` of each pair gives the same figure `wc -l` prints.
local function countLines(path)
    local fh = io.open(ROOT .. "/" .. path, "r")
    if not fh then return nil end
    local body = fh:read("*a") or ""
    fh:close()
    if body == "" then return 0 end
    local n = 0
    for _ in body:gmatch("\n") do n = n + 1 end
    if body:sub(-1) ~= "\n" then n = n + 1 end
    return n
end

--- The census table under CENSUS_HEADING in docs/ARCHITECTURE.md, as { path, disposition } rows.
---
--- A row is a table line whose first cell is a single backticked path; the heading row and the
--- `|---|` separator carry no backticks and fall out on their own. Reading stops at the next
--- heading of any level, so a later section growing a table of its own cannot leak into this one.
local function censusRows()
    local fh = io.open(ROOT .. ARCHITECTURE, "r")
    if not fh then
        fail("layout cap gate: docs/ARCHITECTURE.md could not be opened, so the census cannot be "
            .. "read and this gate must not be reported as passing", 2)
    end
    local body = fh:read("*a") or ""
    fh:close()

    local text = body:gsub("\r\n", "\n")
    local rows, inside, found = {}, false, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line == CENSUS_HEADING then
            inside, found = true, true
        elseif inside and line:sub(1, 1) == "#" then
            break
        elseif inside then
            local path, _, disposition = line:match("^|%s*`([^`]+)`%s*|%s*(.-)%s*|%s*(.-)%s*|%s*$")
            if path then
                rows[#rows + 1] = { path = path, disposition = disposition }
            end
        end
    end

    if not found then
        fail("layout cap gate: docs/ARCHITECTURE.md carries no '" .. CENSUS_HEADING .. "' section. "
            .. "The cap census is where every breach is remarked on and it must not be removed or "
            .. "renamed without moving CENSUS_HEADING here in the same change", 2)
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- The two directions
-- ---------------------------------------------------------------------------

test("layoutcap: every authored file over 1500 lines is named in the ARCHITECTURE.md census", function()
    local listed = {}
    for _, row in ipairs(censusRows()) do listed[row.path] = true end

    local unremarked = {}
    for _, path in ipairs(trackedAuthoredLua()) do
        local n = countLines(path)
        if n == nil then
            fail("layout cap gate: git tracks " .. path .. " but it cannot be opened", 2)
        elseif n > CAP and not listed[path] then
            unremarked[#unremarked + 1] = path .. " (" .. n .. ")"
        end
    end

    if #unremarked > 0 then
        -- Name every one of them rather than the first: a stale census is found all at once, and
        -- clearing it a red run at a time is the slowest possible way to learn how many there were.
        fail("over layout-§1's " .. CAP .. "-line cap and remarked on nowhere: "
            .. table.concat(unremarked, ", ")
            .. " — peel it, open an issue naming the seam it would peel on, or ratify a deviation "
            .. "row with a re-check trigger; then add the row to docs/ARCHITECTURE.md's census", 2)
    end
end)

test("layoutcap: no census row outlives the breach it records", function()
    local spent = {}
    for _, row in ipairs(censusRows()) do
        local n = countLines(row.path)
        if n == nil then
            spent[#spent + 1] = row.path .. " (no such file)"
        elseif n <= CAP then
            spent[#spent + 1] = row.path .. " (" .. n .. ", under the cap)"
        end
    end

    if #spent > 0 then
        fail("docs/ARCHITECTURE.md's cap census carries rows for files that no longer breach: "
            .. table.concat(spent, ", ")
            .. " — delete the row, and close the issue or retire the deviation row that backs it. "
            .. "The census must not become a graveyard", 2)
    end
end)

test("layoutcap: every census row carries a disposition that can be followed", function()
    local rows = censusRows()
    if #rows == 0 then
        fail("layout cap gate: the census table under '" .. CENSUS_HEADING .. "' has no rows. If "
            .. "this repository really has no breach left, delete the section rather than leaving "
            .. "an empty table behind", 2)
    end

    local unfollowable = {}
    for _, row in ipairs(rows) do
        -- layout-§1's second and third terminal states, and nothing else: an issue number to open,
        -- or a deviation row to read. A disposition cell that names neither is a note, and a note
        -- is what this whole section exists to stop being enough.
        if not (row.disposition:find("#%d") or row.disposition:find("[Dd]eviation")) then
            unfollowable[#unfollowable + 1] = row.path
        end
    end

    if #unfollowable > 0 then
        fail("cap census rows whose disposition names neither an issue nor a deviation row: "
            .. table.concat(unfollowable, ", "), 2)
    end
end)
