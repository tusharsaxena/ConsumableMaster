-- tests/test_diagnostics.lua -- the addon's own sections of the diagnostics report
-- (debug-logging-§14, DX-CM), built by core/Diagnostics.lua.
--
-- WHAT IS HERE AND WHAT IS NOT. The dispatcher half of the rule (both forms, while
-- disabled, append, ungated, the markers, `diag` not running it) is the kit's shared
-- case, tests/_kit/test_diagnostics_contract.lua, wired in tests/run.lua against this
-- addon's own /cm dispatcher. What one report writes around the host sections (the
-- identity header, the per-section pcall, the cap and the truncated line) is the
-- library's own suite's business. These cases are the domain half: which sections
-- this addon supplies, what they say, and that saying it changes nothing.
--
-- Every case reads the report through the instance's BuildDiagnostics, which is the
-- same report RunDiagnostics writes, as data.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader
local mock = h.mock

--- The whole addon, enabled and past OnEnable, as a player would have it.
local function build()
    local KCM = loader.loadFullAddon()
    KCM:OnEnable()
    return KCM, KCM.Settings.Helpers
end

--- The report as `[Tag] message` strings, plus the raw report.
local function report(KCM)
    local r = KCM.DebugLog.instance:BuildDiagnostics()
    local text = {}
    for i, line in ipairs(r.lines) do text[i] = "[" .. line[1] .. "] " .. line[2] end
    return text, r
end

local function find(lines, needle, from)
    for i = from or 1, #lines do
        if lines[i]:find(needle, 1, true) then return i, lines[i] end
    end
    return nil
end

local function failedLines(lines)
    local out = {}
    for _, line in ipairs(lines) do
        if line:find("section .- failed:") then out[#out + 1] = line end
    end
    return out
end

--- A stable dump of the stored tree, so "the report wrote nothing" is one string compare.
local function dump(v, out)
    out = out or {}
    if type(v) ~= "table" then
        out[#out + 1] = tostring(v)
        return table.concat(out, "\1")
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
        out[#out + 1] = k .. "="
        local value = v[k]
        if value == nil then value = v[tonumber(k)] end
        dump(value, out)
    end
    out[#out + 1] = "}"
    return table.concat(out, "\1")
end

local function stored(KCM)
    return dump({ profile = KCM.db.profile, global = KCM.db.global })
end

-- ---------------------------------------------------------------------------
-- The sections
-- ---------------------------------------------------------------------------

local SECTIONS = {
    "state", "settings", "spec", "categories", "weapon enchant", "macros",
    "macro bar", "tooltip cache", "bags", "events",
}

test("Diagnostics: the DX-CM sections are supplied in order, and every one runs", function(t)
    local KCM = build()
    local names = {}
    for i, entry in ipairs(KCM.Diagnostics.Sections()) do names[i] = entry[1] end
    t.eqList(names, SECTIONS, "the section list")

    local lines = report(KCM)
    t.eq(#failedLines(lines), 0, "no section failed: " .. table.concat(failedLines(lines), " | "))
    -- One tag per section, so a paste reads as blocks. Order is the section order.
    local at = 0
    for _, tag in ipairs({ "[State]", "[Set]", "[Spec]", "[Cat]", "[Wpn]", "[Macro]", "[Bar]",
                           "[Tip]", "[Bags]", "[Events]" }) do
        local i = find(lines, tag, at + 1)
        t.truthy(i, tag .. " lines follow the section before")
        at = i or at
    end
end)

test("Diagnostics: the descriptor names the brand and the sections", function(t)
    local KCM = build()
    local _, r = report(KCM)
    t.eq(r.lines[1][2], "==== Ka0s Consumable Master diagnostics begin ====", "the begin marker")
    t.truthy(#r.lines > 40, "the host sections are in the report, not only the header: "
        .. #r.lines .. " lines")
end)

test("Diagnostics: the always-print rows print at their defaults", function(t)
    local KCM = build()
    local lines = report(KCM)
    for _, path in ipairs({ "enabled", "macroBar.enabled", "macroBar.locked", "global.minimap.shown" }) do
        t.truthy(find(lines, "[Set] " .. path .. " = "), path .. " printed whatever its value")
    end
end)

test("Diagnostics: a changed setting prints as path = value (default)", function(t)
    local KCM, H = build()
    H.SetAndRefresh("macroBar.buttonSize", 40)
    local lines = report(KCM)
    local _, line = find(lines, "[Set] macroBar.buttonSize = ")
    t.truthy(line, "the changed row is in the report")
    t.truthy(line and line:find("= 40 (", 1, true), "value then default: " .. tostring(line))
    t.falsy(find(lines, "[Set] macroBar.spacing = "), "an unchanged row is not")
end)

-- ---------------------------------------------------------------------------
-- Read only
-- ---------------------------------------------------------------------------

test("Diagnostics: the report writes nothing and calls no setter, macro write or probe", function(t)
    local KCM = build()
    local before = stored(KCM)
    local calls = {}
    local function spy(owner, name, label)
        local real = owner[name]
        owner[name] = function(...)
            calls[#calls + 1] = label
            return real(...)
        end
    end
    spy(_G, "EditMacro", "EditMacro")
    spy(_G, "CreateMacro", "CreateMacro")
    spy(KCM.MacroBar, "Update", "MacroBar.Update")
    spy(KCM.MacroBar, "Refresh", "MacroBar.Refresh")
    spy(KCM.MacroBar, "SetEnabled", "MacroBar.SetEnabled")
    spy(KCM.Pipeline, "Recompute", "Pipeline.Recompute")
    spy(KCM.Pipeline, "RequestRecompute", "Pipeline.RequestRecompute")
    -- red under: reading the current pick through Selector.PickBestForCategory, whose
    -- level gate asks IsUsableByPlayer of entries that may still be pending (DX-CM "never").
    spy(KCM.TooltipCache, "IsUsableByPlayer", "TooltipCache.IsUsableByPlayer")
    spy(KCM.Selector, "PickBestForCategory", "Selector.PickBestForCategory")
    spy(KCM.Selector, "PickBestForSlot", "Selector.PickBestForSlot")

    report(KCM)
    t.eq(table.concat(calls, ", "), "", "nothing was called")
    -- red under: Selector.GetBucket on a spec-aware category with no bucket yet, which
    -- creates one in the profile.
    t.eq(stored(KCM), before, "the stored profile and global are unchanged")
end)

test("Diagnostics: while stood down every section still runs and says so", function(t)
    local KCM, H = build()
    H.SetAndRefresh("enabled", false)
    local lines = report(KCM)
    t.eq(#failedLines(lines), 0, "no section failed: " .. table.concat(failedLines(lines), " | "))
    t.truthy(find(lines, "stood down=yes"), "the state line says the addon is stood down")
    t.truthy(find(lines, "[Bar] bar hidden: the addon is stood down"), "the bar says why it is hidden")
    t.truthy(find(lines, "[Events]") and find(lines, "off (addon disabled)"),
        "the events section reports the stood-down registrations")
    t.truthy(find(lines, "[Cat] FOOD"), "and the categories still report")
end)

-- ---------------------------------------------------------------------------
-- The domain sections
-- ---------------------------------------------------------------------------

test("Diagnostics: the combat queue, the oversize gate and the give-up record are reported", function(t)
    local KCM = build()
    local MM = KCM.MacroManager
    MM.PendingSnapshot = function()
        return { { name = "KCM_FLASK", catKey = "FLASK", itemID = 212283, attempts = 2,
                   composite = false, bytes = 31 } }
    end
    MM.WriteTracking = function()
        return { oversized = { "HP_AIO" }, gaveUp = { { name = "KCM_FLASK", attempts = 3 } } }
    end
    local lines = report(KCM)
    t.truthy(find(lines, "[Macro] combat queue: 1 pending write(s)"), "the queue is counted")
    local _, row = find(lines, "pending KCM_FLASK")
    t.truthy(row and row:find("item=212283", 1, true) and row:find("attempts=2", 1, true)
        and row:find("bytes=31", 1, true), "the queued write by size, not text: " .. tostring(row))
    t.truthy(find(lines, "oversized (warned this session): HP_AIO"), "the oversize gate")
    t.truthy(find(lines, "gave up: KCM_FLASK x3"), "the give-up record")
end)

test("Diagnostics: the tooltip cache reports its pending ids from the snapshot", function(t)
    local KCM = build()
    KCM.TooltipCache.Snapshot = function()
        return { total = 3, pending = 2, unsupported = 0, pendingIds = { 111, 222 } }
    end
    local lines = report(KCM)
    t.truthy(find(lines, "[Tip] tooltip cache: 3 entries, 2 pending, 0 unsupported"), "the counts")
    t.truthy(find(lines, "pending ids: 111, 222"), "the pending ids")
end)

test("Diagnostics: the macro bar reports an apply deferred by combat, and where it is", function(t)
    local KCM = build()
    mock.setCombat(true)
    KCM.MacroBar.Update()
    mock.setCombat(false)
    local lines = report(KCM)
    -- red under: no read of MacroBar's pendingUpdate, which is file-local.
    t.truthy(find(lines, "[Bar] deferred apply: pending=yes"), "the queued Update is reported")
    t.truthy(find(lines, "[Bar] point: saved=CENTER CENTER 0,0"), "the saved point")
    t.truthy(find(lines, "[Bar] frame: built="), "and the frame")
end)

test("Diagnostics: a category reports its top five of the priority, never the whole list", function(t)
    local KCM = build()
    local long = { 101, 102, 103, 104, 105, 106, 107, 108 }
    KCM.Selector.GetEffectivePriority = function(catKey)
        if catKey == "FOOD" then return long end
        return {}
    end
    local lines = report(KCM)
    local i = find(lines, "[Cat]   priority: 8 entries")
    t.truthy(i, "the header counts the whole list")
    local rows = 0
    for j = (i or #lines) + 1, #lines do
        if not lines[j]:find("^%[Cat%]%s+%d+%. ") then break end
        rows = rows + 1
    end
    t.eq(rows, 5, "and five rows follow it")
    t.falsy(find(lines, " 106 "), "the sixth entry is not printed")
end)

test("Diagnostics: a category reports the stored edits and the pick as written", function(t)
    local KCM = build()
    local root = KCM.db.profile.categories.FOOD
    root.added[4001] = true
    root.blocked[4002] = true
    KCM.db.profile.macroState = KCM.db.profile.macroState or {}
    KCM.db.profile.macroState.KCM_FOOD = { lastItemID = 4001, lastBody = "#showtooltip\n/use item:4001",
                                           lastIcon = 134400, lastCat = "FOOD" }
    local lines = report(KCM)
    t.truthy(find(lines, "[Cat]   added: 4001"), "the added id")
    t.truthy(find(lines, "[Cat]   blocked: 4002"), "the blocked id")
    t.truthy(find(lines, "[Cat]   pick (as written): 4001"), "the pick the macro carries")
end)

test("Diagnostics: a secret macro count does not raise", function(t)
    local KCM = build()
    mock.setCooldownsRestricted(true)
    _G.GetNumMacros = function() return mock.secret(40), mock.secret(3) end
    local ok, lines = pcall(report, KCM)
    mock.setCooldownsRestricted(false)
    t.truthy(ok, "the report built: " .. tostring(lines))
    t.eq(#failedLines(lines), 0, "no section failed: " .. table.concat(failedLines(lines), " | "))
    t.truthy(find(lines, "[Macro] account macro slots:"), "the slot line still lands")
end)

test("Diagnostics: a raising section costs one line and the next still runs", function(t)
    local KCM = build()
    KCM.MacroManager.PendingSnapshot = function() error("boom") end
    local lines = report(KCM)
    local failed = failedLines(lines)
    t.eq(#failed, 1, "exactly one failure line: " .. table.concat(failed, " | "))
    t.truthy(failed[1] and failed[1]:find("section macros failed", 1, true), "naming the section")
    t.truthy(find(lines, "[Bar]"), "and the macro bar section after it still ran")
end)

-- ---------------------------------------------------------------------------
-- The debug word
-- ---------------------------------------------------------------------------

test("Diagnostics: `debug diagnostics` runs the report before the window toggle", function(t)
    local KCM = build()
    local DL = KCM.DebugLog
    local ran, toggled = 0, 0
    local realRun, realToggle = DL.RunDiagnostics, DL.Toggle_Window
    DL.RunDiagnostics = function(...) ran = ran + 1; return realRun(...) end
    DL.Toggle_Window = function(...) toggled = toggled + 1; return realToggle(...) end
    KCM:OnSlashCommand("debug diagnostics")
    KCM:OnSlashCommand("debug Diagnostics")
    t.eq(ran, 2, "both spellings ran the report")
    -- red under: the diagnostics branch placed after the toggle fallback
    t.eq(toggled, 0, "and neither toggled the window")
    KCM:OnSlashCommand("debug diag")
    t.eq(ran, 2, "`debug diag` is an ordinary unknown word")
    t.eq(toggled, 1, "which toggles the window, as any unknown word does")
    DL.RunDiagnostics, DL.Toggle_Window = realRun, realToggle
end)

test("Diagnostics: `diagnostics` is a COMMANDS row right after `debug`", function(t)
    local KCM = build()
    local at = {}
    for i, entry in ipairs(KCM.COMMANDS) do at[entry[1]] = i end
    t.truthy(at.diagnostics, "the row exists")
    t.eq(at.diagnostics, (at.debug or 0) + 1, "and sits after debug in the help index")
    for _, word in ipairs({ "diag", "dx" }) do
        t.falsy(at[word], "no `" .. word .. "` row")
    end
end)
