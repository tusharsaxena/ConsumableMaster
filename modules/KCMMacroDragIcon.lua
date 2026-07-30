-- KCMMacroDragIcon.lua — Custom AceGUI widget rendering a draggable macro
-- button with an inline "Drag to action bar →" label. Used at the top of each
-- category panel so users can place the auto-managed KCM_* macro on an action
-- bar without opening the macro UI.
--
-- Drag / click behaviour is the standard Blizzard macro-pickup pattern:
-- PickupMacro(index) on OnDragStart + left-click, which puts the macro on the
-- cursor. Dropping on an action slot calls Blizzard's own PlaceAction flow —
-- no protected-API call from us, so this stays taint-free even mid-combat.
--
-- Acquired via `AceGUI:Create("KCMMacroDragIcon")` in settings/Category.lua,
-- then configured with `:SetCustomData({ macroName = "KCM_FOO" })`. Icon and
-- tooltip are pulled fresh on each refresh so they track the current macro
-- body (which auto-rewrites as bags change).

local _, NS = ...
local KCM = NS

local Type, Version = "KCMMacroDragIcon", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs = pairs
local CreateFrame, UIParent = CreateFrame, UIParent
local GameTooltip = GameTooltip

local ICON_SIZE      = 36
local ROW_HEIGHT     = 40
local LABEL_GAP      = 8

-- Icon / tooltip resolution (pick-first, degrading to the stored macro icon and
-- then the cooking pot) lives in core/MacroDisplay.lua so this widget and the
-- macro bar's buttons can't drift apart.
local function macroIndex(name)
    return KCM.MacroDisplay and KCM.MacroDisplay.MacroIndex(name) or 0
end

local function macroIcon(macroName)
    return KCM.MacroDisplay and KCM.MacroDisplay.Texture(macroName) or nil
end

local function showMacroTooltip(owner, macroName)
    if KCM.MacroDisplay then KCM.MacroDisplay.SetTooltip(owner, macroName) end
end

local methods = {
    ["OnAcquire"] = function(self)
        self.macroName = nil
        self.frame.height = ROW_HEIGHT
        self:SetHeight(ROW_HEIGHT)
        self:SetWidth(220)
        self:RefreshDisplay()
    end,

    -- No-op stubs so the widget tolerates any AceGUI consumer that
    -- pre-emptively calls SetText / SetFontObject on every child. The
    -- widget builds its own label.
    ["SetText"]       = function(self, _) end,
    ["SetFontObject"] = function(self, _) end,

    ["SetCustomData"] = function(self, data)
        if type(data) ~= "table" then return end
        self.macroName = data.macroName
        self:RefreshDisplay()
    end,

    ["RefreshDisplay"] = function(self)
        local idx = macroIndex(self.macroName)
        self.icon:SetTexture(macroIcon(self.macroName))
        if idx == 0 then
            self.label:SetText("|cff999999Macro not created yet|r")
            self.frame:Disable()
        else
            self.label:SetText("|cffffd100Drag to action bar|r")
            self.frame:Enable()
        end
    end,
}

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()
    frame:SetHeight(ROW_HEIGHT)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:RegisterForDrag("LeftButton")

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 0, 0)

    -- Subtle button-press highlight so the icon reads as interactive.
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(icon)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", icon, "RIGHT", LABEL_GAP, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")

    local widget = {
        frame = frame,
        icon  = icon,
        label = label,
        type  = Type,
    }

    local function pickup()
        if not widget.macroName then return end
        local idx = macroIndex(widget.macroName)
        if idx == 0 then return end
        if PickupMacro then PickupMacro(idx) end
    end

    frame:SetScript("OnClick", pickup)
    frame:SetScript("OnDragStart", pickup)

    frame:SetScript("OnEnter", function(self)
        if not widget.macroName then return end
        showMacroTooltip(self, widget.macroName)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
