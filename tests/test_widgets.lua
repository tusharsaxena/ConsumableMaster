-- tests/test_widgets.lua — the custom AceGUI widgets in modules/KCM*.lua.
--
-- Their frames can only be exercised in-client (see docs/smoke-tests.md), but
-- the registration contract is pure and is exactly where these files break
-- silently: a widget that fails to register leaves the settings page calling
-- AceGUI:Create on a type nobody defined, and a widget whose Version was not
-- bumped is quietly ignored in favour of a stale copy already in memory.

local h = require("harness")
local test = h.test

local WIDGETS = {
    { file = "modules/KCMIconButton.lua",   type = "KCMIconButton" },
    { file = "modules/KCMScoreButton.lua",  type = "KCMScoreButton" },
    { file = "modules/KCMMacroDragIcon.lua", type = "KCMMacroDragIcon" },
    { file = "modules/KCMItemRow.lua",      type = "KCMItemRow" },
}

-- Load the widget files against a recording AceGUI stub. `installedVersion` is
-- what the stub reports as already registered for every type, which is what
-- each file's version guard compares against.
local function loadWidgets(installedVersion)
    local KCM  = h.loader.loadPure()
    local root = _G.KCM_TEST_ROOT or "."
    local registered = {}

    local AceGUI = setmetatable({
        RegisterWidgetType = function(_, widgetType, constructor, version)
            registered[widgetType] = { constructor = constructor, version = version }
        end,
        GetWidgetVersion = function(_, _) return installedVersion or 0 end,
        Create = function() return h.loader.mock.makeStub() end,
        ClearFocus = function() end,
        RegisterLayout = function() end,
    }, { __index = function() return function() return h.loader.mock.makeStub() end end })

    local realLibStub = _G.LibStub
    _G.LibStub = function(name, ...)
        if name == "AceGUI-3.0" then return AceGUI end
        return realLibStub(name, ...)
    end
    for _, w in ipairs(WIDGETS) do
        local chunk = assert(loadfile(root .. "/" .. w.file))
        chunk("ConsumableMaster", KCM)
    end
    _G.LibStub = realLibStub

    return registered
end

test("Widgets: every custom widget registers itself with AceGUI", function(t)
    local registered = loadWidgets(0)
    for _, w in ipairs(WIDGETS) do
        t.truthy(registered[w.type], w.type .. " registered its type")
    end
end)

test("Widgets: each registration supplies a constructor function", function(t)
    local registered = loadWidgets(0)
    for _, w in ipairs(WIDGETS) do
        t.eq(type(registered[w.type].constructor), "function",
            w.type .. " registers a constructor AceGUI:Create can call")
    end
end)

test("Widgets: each registration declares a positive integer version", function(t)
    local registered = loadWidgets(0)
    for _, w in ipairs(WIDGETS) do
        local version = registered[w.type].version
        t.eq(type(version), "number", w.type .. " declares a numeric version")
        t.truthy(version >= 1, w.type .. " version is at least 1")
        t.eq(version, math.floor(version), w.type .. " version is a whole number")
    end
end)

test("Widgets: the version guard skips a widget already registered at that version", function(t)
    -- AceGUI reports a newer copy is already loaded — every file must bail out
    -- before registering, or a downgrade would win the last-writer race.
    local registered = loadWidgets(99)
    for _, w in ipairs(WIDGETS) do
        t.eq(registered[w.type], nil, w.type .. " left the newer registration alone")
    end
end)

test("Widgets: no two widgets claim the same type name", function(t)
    local seen = {}
    for _, w in ipairs(WIDGETS) do
        t.falsy(seen[w.type], w.type .. " is claimed once")
        seen[w.type] = true
    end
    local registered = loadWidgets(0)
    local count = 0
    for _ in pairs(registered) do count = count + 1 end
    t.eq(count, #WIDGETS, "one registration per widget file")
end)

test("Widgets: every widget name used by the settings pages is registered", function(t)
    local registered = loadWidgets(0)
    local root = _G.KCM_TEST_ROOT or "."
    -- Scan the settings sources for AceGUI:Create("KCM...") call sites; each
    -- must correspond to a widget one of the modules registers.
    for _, page in ipairs({ "settings/Category.lua", "settings/StatPriority.lua",
                            "settings/General.lua", "settings/Panel.lua" }) do
        local f = io.open(root .. "/" .. page, "r")
        if f then
            local src = f:read("*a")
            f:close()
            for widgetType in src:gmatch('Create%(%s*"(KCM[%w_]*)"') do
                t.truthy(registered[widgetType],
                    page .. " creates '" .. widgetType .. "', which is a registered widget")
            end
        end
    end
end)
