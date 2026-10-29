-- test_skin_surfaces.lua — the surfaces this addon draws, painted from the skin (skinning-§1,
-- anti-pattern #107; CM-02 of the 2026-10-29 skinning rollout).
--
-- WHAT IT PROVES. Two things:
--
--   1. THE LITERAL GATE (LootHistory's tests/test_skin_literals.lua, the reference adopter's). No
--      color this addon draws is a literal the skin cannot reach. Two shapes are caught in every
--      tracked .lua file under core/, modules/ and settings/:
--        * a NUMERIC LITERAL IN A COLOR POSITION of a paint call: the r, g or b of SetTextColor,
--          SetColorTexture, SetVertexColor, SetBackdropColor and SetBackdropBorderColor, the r, g, b
--          after AddLine's and GameTooltip:SetText's text, and AddDoubleLine's two triples. An ALPHA
--          literal over token components (`SetVertexColor(r, g, b, DISABLED_ALPHA)`) is opacity,
--          the same under every skin, and is left alone on purpose;
--        * a `|cff` escape in code, markup naming a color byte for byte. KCM.SkinEscape builds the
--          escapes a token feeds. Comments are stripped first.
--      core/SkinSetup.lua is out of scope: it IS the seam, and its host copy of the Ka0s Default
--      values is what every other file reads through. Each allow-list entry names a file, a plain
--      substring the offending line carries, and why it is not chrome; an entry that matches
--      nothing fails, so the list cannot outlive what it excuses.
--
--      THE HUD IS NOT YET IN SCOPE. The macro bar's three files paint the player's HUD style
--      settings and become skin reads in CM-03 (S.Resolve, the fromSkin companions, the one-time
--      reset); HUD_PENDING holds them out until then, and CM-03 empties it.
--
--   2. THE CUSTOM WIDGETS PAINT THEMSELVES. No library painter knows KCMIconButton, KCMItemRow or
--      the score button, so each reads its colors from KCM.Skin: built under the kit's paint
--      recorder (tests/_kit/mock_paint.lua), they draw Ka0s Default's exact pixels and another
--      skin's own.

local h = _G.KCM_TEST
local test = h.test

local ROOT = _G.KCM_TEST_ROOT or "."
local OWNER = "ConsumableMaster"
local SEAM = "core/SkinSetup.lua"

local HUD_PENDING = {
    ["modules/MacroBar.lua"] = true,
    ["modules/MacroBarButton.lua"] = true,
    ["modules/MacroBarFlyout.lua"] = true,
}

-- call name -> the argument positions that hold color components.
local COLOR_ARGS = {
    SetTextColor = { 1, 2, 3 }, SetColorTexture = { 1, 2, 3 }, SetVertexColor = { 1, 2, 3 },
    SetBackdropColor = { 1, 2, 3 }, SetBackdropBorderColor = { 1, 2, 3 },
    AddLine = { 2, 3, 4 }, AddDoubleLine = { 3, 4, 5, 6, 7, 8 }, SetText = { 2, 3, 4 },
}

local ALLOW = {
    { file = "core/Constants.lua", find = "KCM.PREFIX",
      why = "the chat prefix: chat output, not a skinned surface (chat-output's cyan brand, X7)" },
    { file = "core/DebugLogSetup.lua", find = "debug logging",
      why = "the debug ON/OFF line: chat output (X7)" },
    { file = "core/SlashDump.lua", find = "|cff",
      why = "/cm dump's tags and highlights: chat output (X7)" },
    { file = "core/SlashCommands.lua", find = "|cff",
      why = "the /cm verbs' tags and highlights: chat output (X7)" },
    { file = "settings/Slash.lua", find = "|cff",
      why = "the slash help descriptor's header, alias and command highlights: chat output (X7, X9)" },
    { file = "settings/Panel.lua", find = "schema error",
      why = "the schema-error line: chat output (X7)" },
    { file = "modules/KCMIconButton.lua", find = "SetVertexColor(1, 1, 1, 1)",
      why = "the enabled icon's untinted vertex: no color, the art as the client draws it" },
    { file = "modules/KCMScoreButton.lua", find = "SetVertexColor(1, 1, 1, 1)",
      why = "the enabled icon's untinted vertex: no color, the art as the client draws it" },
}

--- Strip a line's trailing comment. `--` never occurs inside a string in these files' color code.
local function code(line) return (line:gsub("%-%-.*$", "")) end

--- Split a call's argument list at its top-level commas (parens, braces and quotes nest).
local function splitArgs(s)
    local args, depth, buf, quote = {}, 0, {}, nil
    local i = 1
    while i <= #s do
        local c = s:sub(i, i)
        if quote then
            buf[#buf + 1] = c
            if c == "\\" then buf[#buf + 1] = s:sub(i + 1, i + 1); i = i + 1
            elseif c == quote then quote = nil end
        elseif c == '"' or c == "'" then quote = c; buf[#buf + 1] = c
        elseif c == "(" or c == "{" or c == "[" then depth = depth + 1; buf[#buf + 1] = c
        elseif c == ")" or c == "}" or c == "]" then depth = depth - 1; buf[#buf + 1] = c
        elseif c == "," and depth == 0 then args[#args + 1] = table.concat(buf); buf = {}
        else buf[#buf + 1] = c end
        i = i + 1
    end
    args[#args + 1] = table.concat(buf)
    return args
end

local function isNumber(arg) return arg:match("^%s*%-?%d*%.?%d+%s*$") ~= nil end

--- Every offending line of one source text: { line = n, text = what was found }.
local function scan(src)
    local lines, hits = {}, {}
    for ln in (src .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = code(ln) end
    local stripped = table.concat(lines, "\n")
    for name, positions in pairs(COLOR_ARGS) do
        local init = 1
        while true do
            local s, e, args = stripped:find("[:%.]" .. name .. "%s*(%b())", init)
            if not s then break end
            init = e + 1
            local list = splitArgs(args:sub(2, -2))
            for _, p in ipairs(positions) do
                if list[p] and isNumber(list[p]) then
                    local n = select(2, stripped:sub(1, s):gsub("\n", "")) + 1
                    hits[#hits + 1] = { line = n, text = lines[n] }
                    break
                end
            end
        end
    end
    for n, ln in ipairs(lines) do
        if ln:find("|c[fF][fF]") then hits[#hits + 1] = { line = n, text = ln } end
    end
    return hits
end

local function allowed(file, text, used)
    for i, a in ipairs(ALLOW) do
        if a.file == file and text:find(a.find, 1, true) then used[i] = true; return true end
    end
    return false
end

-- Fails rather than passes when it cannot look: no io.popen, no git, or an empty list.
local function trackedSources(t)
    t.truthy(io.popen ~= nil, "io.popen is available, so the literal gate can list the sources")
    if not io.popen then return {} end
    local p = io.popen("git -C '" .. ROOT .. "' ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 2>/dev/null")
    local files = {}
    if p then
        for path in p:lines() do
            if path ~= SEAM and not HUD_PENDING[path] then files[#files + 1] = path end
        end
        p:close()
    end
    t.truthy(#files > 0, "git listed the sources, so something was scanned")
    return files
end

local function readAll(path)
    local f = io.open(ROOT .. "/" .. path, "rb")
    if not f then return "" end
    local s = f:read("*a")
    f:close()
    return s
end

-- red under: a color typed at a call site (anti-pattern #107), or an allow-list entry that outlived
-- the literal it excused.
test("Skin surfaces: no color literal outside the seam, the pending HUD and the allow-list", function(t)
    local bad, used = {}, {}
    for _, path in ipairs(trackedSources(t)) do
        for _, hit in ipairs(scan(readAll(path))) do
            if not allowed(path, hit.text, used) then
                bad[#bad + 1] = ("%s:%d: %s"):format(path, hit.line, (hit.text:gsub("^%s+", "")))
            end
        end
    end
    t.eq(table.concat(bad, "\n  "), "", "hard-coded colors the skin cannot reach (read a token "
        .. "through KCM.Skin / KCM.SkinColor / KCM.SkinEscape, or add an allow-list entry with its reason)")
    for i, a in ipairs(ALLOW) do
        t.truthy(used[i], ("the allow-list entry %s %q still matches a line"):format(a.file, a.find))
    end
end)

test("Skin surfaces: every allow-list entry carries its reason", function(t)
    for _, a in ipairs(ALLOW) do
        t.truthy(type(a.why) == "string" and #a.why > 10, a.file .. " " .. a.find .. " says why")
    end
end)

test("Skin surfaces: the literal gate is falsifiable", function(t)
    local planted = table.concat({
        "local x = 1",
        "fs:SetTextColor(0.85, 0.85, 0.85)",
        "tex:SetColorTexture(r, g,",
        "  0.5, 1)",
        'GameTooltip:AddLine("n records", 1, 1, 1, true)',
        'GameTooltip:SetText(name, 1, 0.82, 0)',
        'local s = "|cff808080(none)|r"',
        'fs:SetTextColor(KCM.SkinColor("text.body"))   -- 0.9, 0.9, 0.9 in a comment',
        "tex:SetVertexColor(r, g, b, 0.5)",
        "-- |cffffffff in a comment",
    }, "\n")
    local lines = {}
    for _, hit in ipairs(scan(planted)) do lines[#lines + 1] = hit.line end
    table.sort(lines)
    t.eq(table.concat(lines, ","), "2,3,5,6,7",
        "the literal lines and only those (a token call, an alpha literal and a comment pass)")
end)

-- red under: a converted escape that moved a Ka0s Default byte.
test("Skin surfaces: the escapes built from tokens keep Ka0s Default's bytes", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SkinEscape("gtip.value"), "|cffffffff", "the score tooltip's value white")
    t.eq(KCM.SkinEscape("cm.tipNote"), "|cff888888", "its note gray")
    t.eq(KCM.SkinEscape("cm.tipSummary"), "|cffaaaaaa", "its summary gray")
    t.eq(KCM.SkinEscape("cm.warn"), "|cffff8800", "the pages' warning orange")
end)

-- red under: a converted surface reading a token the degraded facade cannot answer, so an install
-- without the library would draw that surface in no color at all.
test("Skin surfaces: the degraded facade answers every token the surfaces read", function(t)
    local degraded = h.loader.loadPureDegraded()
    local missing = {}
    for _, name in ipairs({ "text.accent", "text.disabled", "text.highlight", "sem.unknown",
                            "gtip.title", "gtip.value", "cm.iconHover", "cm.warn", "cm.tipNote",
                            "cm.tipSummary" }) do
        if degraded.Skin.Color(name) == nil then missing[#missing + 1] = name end
    end
    t.eq(table.concat(missing, ", "), "", "every token a converted surface reads has a host value")
end)

-- ---------------------------------------------------------------------------
-- The custom widgets, built under the paint recorder
-- ---------------------------------------------------------------------------

local installPaint = dofile(ROOT .. "/tests/_kit/mock_paint.lua")

--- Load one widget file under the recorder and return a fresh widget of its type, the recorder's
--- survey, and a cleanup that puts CreateFrame back and the skin on Ka0s Default.
local function buildWidget(KCM, rel, widgetType)
    local M = { CreateFrame = _G.CreateFrame }
    local restore = installPaint(M)
    local savedCreate, savedLibStub = _G.CreateFrame, _G.LibStub
    _G.CreateFrame = M.CreateFrame
    local ctor
    local AceGUI = setmetatable({
        RegisterWidgetType = function(_, ty, constructor) if ty == widgetType then ctor = constructor end end,
        GetWidgetVersion = function() return 0 end,
        -- AceGUI's own base methods, the two the widgets call on themselves.
        RegisterAsWidget = function(_, w)
            w.SetHeight = function(self, v) self.frame:SetHeight(v) end
            w.SetWidth = function(self, v) self.frame:SetWidth(v) end
            return w
        end,
        ClearFocus = function() end,
    }, { __index = function() return function() end end })
    _G.LibStub = function(name, ...)
        if name == "AceGUI-3.0" then return AceGUI end
        return savedLibStub(name, ...)
    end
    local chunk = assert(loadfile(ROOT .. "/" .. rel))
    chunk(OWNER, KCM)
    _G.LibStub = savedLibStub
    local widget = ctor and ctor()
    if widget then
        widget.Fire = function() end
        widget.frame.obj = widget
    end
    local function cleanup()
        _G.CreateFrame = savedCreate
        restore()
        local Skin = LibStub("LibKa0s-Skin-1.0", true)
        if Skin then Skin:SetChoice(OWNER, "ka0s", "ka0s") end
    end
    return widget, M.__paint, cleanup
end

local function same(got, want)
    if type(got) ~= "table" or type(want) ~= "table" then return false end
    for i = 1, 3 do
        if math.abs((got[i] or -1) - (want[i] or -2)) > 1e-6 then return false end
    end
    return true
end

local function rgba(...) return { ... } end

-- red under: the hover wash typed again, or read once at build so a skin switch leaves it stale.
test("Skin surfaces: the icon button's hover wash is cm.iconHover, read at hover time", function(t)
    local KCM = h.loader.loadPure()
    local Skin = LibStub("LibKa0s-Skin-1.0", true)
    local w, paint, cleanup = buildWidget(KCM, "modules/KCMIconButton.lua", "KCMIconButton")
    local ok, err = pcall(function()
        t.truthy(w, "the widget builds under the recorder")
        w:OnAcquire()
        local onEnter = w.frame:GetScript("OnEnter")
        onEnter(w.frame)
        local c = paint(w.hoverBG).color
        t.truthy(same(c, { 1, 0.82, 0 }), "Ka0s Default: the gold wash it drew before skins")
        t.eq(c and c[4], 0.25, "at a quarter alpha")
        t.truthy(same(paint(w.label).textColor, { 1, 1, 1 }), "the enabled label is today's white")

        Skin:SetChoice(OWNER, "ka0s", "obsidian")
        onEnter(w.frame)
        local want = rgba(KCM.Skin.Color("cm.iconHover"))
        t.truthy(same(paint(w.hoverBG).color, want), "Obsidian: the wash its role token gives")
        t.truthy(same(paint(w.label).textColor, rgba(KCM.Skin.Color("text.highlight"))),
            "and the label replays in Obsidian's highlight text")

        w:SetDisabled(true)
        t.truthy(same(paint(w.label).textColor, rgba(KCM.Skin.Color("text.disabled"))),
            "a disabled label takes the skin's disabled text")
        local v = paint(w.image).vertex
        t.truthy(same(v, rgba(KCM.Skin.Color("text.disabled"))), "and the art its disabled gray")
        t.eq(v and v[4], 0.5, "at AceGUI's stock half alpha")
    end)
    cleanup()
    t.truthy(ok, tostring(err))
end)

-- red under: the item row's label or hand tag back on a template color the skin cannot reach.
test("Skin surfaces: the item row's name and hand tag take the skin's text", function(t)
    local KCM = h.loader.loadPure()
    local Skin = LibStub("LibKa0s-Skin-1.0", true)
    local w, paint, cleanup = buildWidget(KCM, "modules/KCMItemRow.lua", "KCMItemRow")
    local ok, err = pcall(function()
        t.truthy(w, "the widget builds under the recorder")
        w.RefreshDisplay = function() end   -- the item lookups are not under test here
        w:OnAcquire()
        t.truthy(same(paint(w.label).textColor, { 1, 1, 1 }), "Ka0s Default: the name in today's white")
        t.truthy(same(paint(w.handTag).textColor, { 1, 0.82, 0 }), "and the hand tag in today's gold")
        Skin:SetChoice(OWNER, "ka0s", "azeroth")
        t.truthy(same(paint(w.label).textColor, rgba(KCM.Skin.Color("text.highlight"))),
            "Azeroth: the name replays in its highlight text")
        t.truthy(same(paint(w.handTag).textColor, rgba(KCM.Skin.Color("text.accent"))),
            "and the hand tag in its accent")
    end)
    cleanup()
    t.truthy(ok, tostring(err))
end)

-- red under: the score button's disabled art typed again.
test("Skin surfaces: the score button's disabled art is the skin's disabled gray", function(t)
    local KCM = h.loader.loadPure()
    local w, paint, cleanup = buildWidget(KCM, "modules/KCMScoreButton.lua", "KCMScoreButton")
    local ok, err = pcall(function()
        t.truthy(w, "the widget builds under the recorder")
        w:OnAcquire()
        w:SetDisabled(true)
        local v = paint(w.image).vertex
        t.truthy(same(v, { 0.5, 0.5, 0.5 }), "Ka0s Default: today's gray")
        t.eq(v and v[4], 0.5, "at half alpha")
        w:SetDisabled(false)
        t.truthy(same(paint(w.image).vertex, { 1, 1, 1 }), "enabled art is untinted")
    end)
    cleanup()
    t.truthy(ok, tostring(err))
end)
