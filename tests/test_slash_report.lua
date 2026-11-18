-- test_slash_report.lua — the report routing: every multi-line read-out the
-- player asks for goes to the debug console, not chat (the owner's ruling of
-- 2026-11-08, ahead of a standard rule and a LibKa0s implementation).
--
-- A report (`/cm dump <target>`, `/cm priority <cat> list`, `/cm aio <key> list`)
-- writes its body through KCM.DebugLog.Report (core/DebugLogSetup.lua): ungated,
-- so it lands with logging off; the console is revealed if hidden; chat gets
-- exactly one pointer line. Usage and refusal lines stay in chat and write no
-- report. Help, `/cm list` and the bare `/cm dump` listing are not reports.
-- Library-absent, a report falls back to chat with no pointer line. The content
-- of each report is pinned in tests/test_slash.lua, which reads the console.

local h = _G.KCM_TEST
local test = h.test

local POINTER = "^|cff00ffff%[CM%]|r (.-): (%d+) lines written to the debug console%. Use Copy to share it%.$"

local function load(degraded)
    local KCM = h.loader.loadFullAddon(degraded)
    if degraded then KCM.Say("warm") end   -- spend the said-once library notice
    return KCM, h.loader.mock
end

-- Run one line; answer the chat lines and the console lines it appended.
local function run(KCM, mock, line)
    local D = KCM.DebugLog.instance
    local from = D and #D.buffer or 0
    mock.output = {}
    KCM:OnSlashCommand(line)
    local console = {}
    if D then
        for i = from + 1, #D.buffer do console[#console + 1] = D.buffer[i] end
    end
    return mock.output, console
end

local REPORTS = {
    { line = "dump categories",   title = "dump categories",   tag = "Dump" },
    { line = "dump statpriority", title = "dump statpriority", tag = "Dump" },
    { line = "dump bags",         title = "dump bags",         tag = "Dump" },
    { line = "dump item 960010",  title = "dump item",         tag = "Dump" },
    { line = "dump 960010",       title = "dump item",         tag = "Dump" },
    { line = "dump pick food",    title = "dump pick",         tag = "Dump" },
    { line = "dump pick hp_aio",  title = "dump pick",         tag = "Dump" },
    { line = "dump events",       title = "dump events",       tag = "Dump" },
    { line = "priority food list", title = "priority food list", tag = "Priority" },
    { line = "priority food",     title = "priority food list", tag = "Priority" },
    { line = "priority hp_aio list", title = "priority hp_aio list", tag = "Priority" },
    { line = "aio hp_aio list",   title = "aio hp_aio list",   tag = "AIO" },
    { line = "aio hp_aio",        title = "aio hp_aio list",   tag = "AIO" },
}

test("Report: every report verb writes to the console with logging off and says one chat line", function(t)
    local KCM, mock = load()
    mock.setItem(960010, { name = "Report Snack", subType = "Food & Drink", tt = { healValue = 10 } })
    mock.setBag(960010, 2)
    t.falsy(KCM.DebugLog.IsEnabled(), "trace logging is off")
    for _, r in ipairs(REPORTS) do
        local chat, console = run(KCM, mock, r.line)
        t.eq(#chat, 1, "/cm " .. r.line .. ": exactly one chat line: " .. table.concat(chat, " | "))
        local title, n = tostring(chat[1]):match(POINTER)
        t.eq(title, r.title, "/cm " .. r.line .. ": the pointer names the report")
        t.eq(tonumber(n), #console, "/cm " .. r.line .. ": and counts the lines it wrote")
        t.truthy(#console >= 2, "/cm " .. r.line .. ": a header and a body")
        t.truthy(tostring(console[1]):find("[" .. r.tag .. "] /cm " .. r.title, 1, true),
            "/cm " .. r.line .. ": the header names the command under its tag: " .. tostring(console[1]))
        for i, l in ipairs(console) do
            t.truthy(l:find("| [" .. r.tag .. "] ", 1, true), "/cm " .. r.line .. ": line " .. i .. " is tagged")
        end
    end
end)

test("Report: a hidden console is revealed, a shown one stays shown", function(t)
    local KCM, mock = load()
    KCM.DebugLog.Hide()
    t.falsy(KCM.DebugLog.IsWindowShown(), "hidden before the report")
    run(KCM, mock, "dump bags")
    t.truthy(KCM.DebugLog.IsWindowShown(), "the report reveals the console")
    run(KCM, mock, "dump events")
    t.truthy(KCM.DebugLog.IsWindowShown(), "and a second report leaves it shown")
end)

test("Report: the bags dump renders through the serializer, not DevTools_Dump", function(t)
    local KCM, mock = load()
    mock.setBag(960015, 4)
    local printed = 0
    local saved = _G.DevTools_Dump
    _G.DevTools_Dump = function() printed = printed + 1 end
    local chat, console = run(KCM, mock, "dump bags")
    _G.DevTools_Dump = saved
    t.eq(printed, 0, "DevTools_Dump is never called: it prints to the chat frame")
    t.eq(#chat, 1, "chat holds the pointer line only")
    t.truthy(table.concat(console, "\n"):find("[Dump]   [960015] = 4", 1, true),
        "the tally is a console line: " .. table.concat(console, " | "))
end)

local REFUSALS = {
    { line = "dump item",               says = "usage: /cm dump item <itemID>" },
    { line = "dump pick",               says = "usage: /cm dump pick <catKey>" },
    { line = "dump pick frobnicate",    says = "unknown category:" },
    { line = "dump frobnicate",         says = "Unknown dump target" },
    { line = "priority frobnicate list", says = "unknown category 'frobnicate'" },
    { line = "aio food list",           says = "unknown composite category 'food'" },
}

test("Report: a usage or refusal line goes to chat and writes no report", function(t)
    local KCM, mock = load()
    for _, r in ipairs(REFUSALS) do
        local chat, console = run(KCM, mock, r.line)
        local text = table.concat(chat, "\n")
        t.truthy(text:find(r.says, 1, true), "/cm " .. r.line .. ": the refusal is in chat: " .. text)
        t.falsy(text:find("written to the debug console", 1, true), "/cm " .. r.line .. ": no pointer line")
        t.eq(#console, 0, "/cm " .. r.line .. ": nothing written to the console")
    end
end)

test("Report: a spec-aware list with no spec refuses in chat and writes no report", function(t)
    local KCM, mock = load()
    local getCurrent = KCM.SpecHelper.GetCurrent
    KCM.SpecHelper.GetCurrent = function() return nil, nil, nil, nil end
    local chat, console = run(KCM, mock, "priority flask list")
    KCM.SpecHelper.GetCurrent = getCurrent
    t.truthy(table.concat(chat, "\n"):find("spec-aware category but no active spec", 1, true), "the refusal is in chat")
    t.eq(#chat, 1, "and it is the only chat line")
    t.eq(#console, 0, "nothing written to the console")
end)

test("Report: help, /cm list and the bare /cm dump listing stay in chat", function(t)
    local KCM, mock = load()
    for _, line in ipairs({ "help", "list", "dump", "priority", "aio", "stat list" }) do
        local chat, console = run(KCM, mock, line)
        t.truthy(#chat > 1 or (line == "stat list" and #chat > 0), "/cm " .. line .. ": printed to chat")
        t.falsy(table.concat(chat, "\n"):find("written to the debug console", 1, true), "/cm " .. line .. ": no pointer line")
        t.eq(#console, 0, "/cm " .. line .. ": nothing written to the console")
    end
end)

test("Report: without the library a report prints to chat as before, with no pointer", function(t)
    local KCM, mock = load(true)
    t.eq(KCM.DebugLog.instance, nil, "the degraded console stub")
    mock.setBag(960015, 4)
    local chat = run(KCM, mock, "dump bags")
    local text = table.concat(chat, "\n")
    -- Re-pinned at AD-79-CM: the serializer is the library's now, so without the
    -- library a table renders as the stub's one `<table>` line, not its rows.
    t.truthy(text:find("  <table>", 1, true), "the report body is in chat: " .. text)
    t.falsy(text:find("written to the debug console", 1, true), "and there is no pointer line")
    local refusal = run(KCM, mock, "dump item")
    t.eq(#refusal, 1, "a refusal is still its one chat line")
end)

test("Report: the serializer sorts keys, indents nested tables and stays bounded", function(t)
    local KCM = load()
    local lines = {}
    local function out(l) lines[#lines + 1] = l end
    local cyc = { name = "loop" }
    cyc.self = cyc
    local n = KCM.SlashDump.Serialize(out, {
        b = "two\nlines", a = 1, [2] = true, [1] = { z = {}, y = 3 }, c = cyc, f = print,
    })
    t.eq(n, #lines, "answers the line count it wrote")
    t.eqList(lines, {
        "  [1] = {",
        "    y = 3",
        "    z = {}",
        "  }",
        "  [2] = true",
        "  a = 1",
        '  b = "two\\nlines"',
        "  c = {",
        '    name = "loop"',
        "    self = <cycle>",
        "  }",
        "  f = <function>",
    }, "numbers first, then strings; nested tables indented; one line per value")
    local big, wide = {}, {}
    for i = 1, 1000 do big[i] = i end
    KCM.SlashDump.Serialize(function(l) wide[#wide + 1] = l end, big)
    t.eq(#wide, 401, "a huge table stops at the cap, plus the truncation line")
    t.truthy(wide[#wide]:find("truncated at 400 lines", 1, true), "and says so")
end)

-- LibKa0s#79 adoption (AD-79-CM): the two addon-local halves lifted into the
-- library now forward to it. Red under the local bodies: they never reach the
-- instance's Report / Serialize, and a raising body escaped DL.Report.
test("Report: DL.Report is the library's D:Report, called with the tag, title and body", function(t)
    local KCM = load()
    local D = KCM.DebugLog.instance
    local real, seen = D.Report, nil
    D.Report = function(self, tag, title, fn)
        seen = { self = self, tag = tag, title = title, fn = fn }
        return real(self, tag, title, fn)
    end
    local body = function(out) out("one") end
    local n = KCM.DebugLog.Report("Dump", "dump lift", body)
    D.Report = real
    t.truthy(seen, "the library's D:Report ran")
    t.eq(seen.self, D, "on the addon's own console")
    t.eq(seen.tag, "Dump", "with the tag")
    t.eq(seen.title, "dump lift", "with the title")
    t.eq(seen.fn, body, "with the body unwrapped")
    t.eq(n, 2, "and answers its line count, the header included")
end)

test("Report: a body that raises keeps what it wrote, adds one failed line and still points", function(t)
    local KCM, mock = load()
    local D = KCM.DebugLog.instance
    local from = #D.buffer
    mock.output = {}
    local n = KCM.DebugLog.Report("Dump", "dump boom", function(out)
        out("before")
        error("kaboom", 0)
    end)
    local console = {}
    for i = from + 1, #D.buffer do console[#console + 1] = D.buffer[i] end
    t.eq(n, 3, "the header, the line before the raise and the failed line")
    t.eq(#console, 3, "all three are console lines")
    t.truthy(console[2]:find("[Dump] before", 1, true), "the collected line is kept: " .. tostring(console[2]))
    t.truthy(console[3]:find("[Dump] dump boom failed: kaboom", 1, true), "the failure is one line: " .. tostring(console[3]))
    t.eq(#mock.output, 1, "one chat line")
    local title, count = tostring(mock.output[1]):match(POINTER)
    t.eq(title, "dump boom", "the pointer names the report")
    t.eq(tonumber(count), 3, "and counts the failed line")
end)

test("Report: SlashDump.Serialize renders through the library's D:Serialize", function(t)
    local KCM = load()
    local D = KCM.DebugLog.instance
    local real, seen = D.Serialize, nil
    D.Serialize = function(self, value, opts)
        seen = { self = self, value = value, opts = opts }
        return real(self, value, opts)
    end
    local lines = {}
    local value = { a = 1 }
    local n = KCM.SlashDump.Serialize(function(l) lines[#lines + 1] = l end, value, "    ")
    D.Serialize = real
    t.truthy(seen, "the library's serializer ran")
    t.eq(seen.self, D, "on the addon's own console")
    t.eq(seen.value, value, "with the value")
    t.eq(seen.opts and seen.opts.indent, "    ", "and the caller's indent")
    t.eqList(lines, { "    a = 1" }, "its lines go through out")
    t.eq(n, 1, "and the line count is answered")
end)

test("Report: without the library the serializer answers one line, as the library's stub does", function(t)
    local KCM = load(true)
    local lines = {}
    local n = KCM.SlashDump.Serialize(function(l) lines[#lines + 1] = l end, { a = 1 })
    t.eqList(lines, { "  <table>" }, "a table is one placeholder line at the indent")
    t.eq(n, 1, "and counts it")
    lines = {}
    KCM.SlashDump.Serialize(function(l) lines[#lines + 1] = l end, 7)
    t.eqList(lines, { "  7" }, "a scalar is its text")
end)
