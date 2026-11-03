-- tests/skin_widget_support.lua — one custom widget built under the kit's paint recorder, shared by
-- tests/test_skin_surfaces.lua and the switch test's surfaces (tests/skin_switch_facts.lua).

local ROOT = _G.KCM_TEST_ROOT or "."
local OWNER = "ConsumableMaster"
local installPaint = dofile(ROOT .. "/tests/_kit/mock_paint.lua")

--- Load one widget file under the recorder and return a fresh widget of its type, the recorder's
--- survey, and a cleanup that puts CreateFrame back and the skin on Ka0s Default.
return function(KCM, rel, widgetType)
    local M = { CreateFrame = _G.CreateFrame }
    local restore = installPaint(M)
    -- The client hands a string built from a template that template's font object, which the
    -- library's put-back restores under the Scope; the recorder keeps only the template's name.
    local paintCreate = M.CreateFrame
    M.CreateFrame = function(...)
        local f = paintCreate(...)
        local createFS = rawget(f, "CreateFontString")
        if createFS then
            rawset(f, "CreateFontString", function(self, name, layer, template)
                local fs = createFS(self, name, layer, template)
                if type(template) == "string" and template ~= "" then fs:SetFontObject(template) end
                return fs
            end)
        end
        return f
    end
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
