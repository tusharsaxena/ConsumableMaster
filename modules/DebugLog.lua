-- modules/DebugLog.lua — on-screen debug console (standard §12).
--
-- A movable, Escape-closable window with a ScrollingMessageFrame that mirrors
-- gated debug output on screen, plus Copy (dumps a plain-text buffer into an
-- EditBox for Ctrl-C) and Clear controls. The two FormatPlain/FormatColored
-- helpers are PURE (no frame/global touch, timestamp passed in) so they unit
-- test headlessly; the window is built lazily on first show and cached.

local _, NS = ...
local KCM = NS
KCM.DebugLog = KCM.DebugLog or {}
local DL = KCM.DebugLog

-- Register the shipped monospace font with LibSharedMedia (optional dependency).
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    LSM:Register(LSM.MediaType.FONT, "JetBrains Mono",
        [[Interface\AddOns\ConsumableMaster\media\fonts\JetBrainsMono-Regular.ttf]])
end

local FONT_NAME     = "JetBrains Mono"
local FONT_FALLBACK = [[Fonts\ARIALN.TTF]]
local FONT_SIZE     = 12
local WIN_NAME      = "ConsumableMasterDebugWindow"
local MAX_LINES     = 500

-- Cached window widgets, nil until first build.
local win

-- Accumulated plain-text lines for the Copy buffer.
local buffer = {}

local function now()
    return (date and date("%H:%M:%S")) or ""
end

-- ---------------------------------------------------------------------------
-- Pure formatters (unit-tested; must not touch frames or globals)
-- ---------------------------------------------------------------------------

function DL.FormatPlain(tag, msg, timeStr)
    timeStr, msg = timeStr or "", msg or ""
    if tag ~= nil then
        return timeStr .. " [" .. tostring(tag) .. "] " .. msg
    end
    return timeStr .. " " .. msg
end

function DL.FormatColored(tag, msg, timeStr)
    timeStr, msg = timeStr or "", msg or ""
    local time = "|cff808080" .. timeStr .. "|r"
    if tag ~= nil then
        return time .. " |cff00ffff[" .. tostring(tag) .. "]|r " .. msg
    end
    return time .. " " .. msg
end

-- ---------------------------------------------------------------------------
-- Enabled state (mirrors KCM.State.debug)
-- ---------------------------------------------------------------------------

local function headerText()
    return DL.IsEnabled() and "Debug: |cff00ff00ON|r" or "Debug: |cffff5555OFF|r"
end

function DL.IsEnabled()
    return KCM.State and KCM.State.debug == true
end

function DL.SetEnabled(on)
    on = on and true or false
    if KCM.State then KCM.State.debug = on end
    if win and win.header then
        win.header:SetText(headerText())
    end
    return on
end

function DL.Toggle()
    return DL.SetEnabled(not DL.IsEnabled())
end

-- ---------------------------------------------------------------------------
-- Lazy window construction (all frame work guarded for headless load)
-- ---------------------------------------------------------------------------

local function fontPath()
    if LSM then
        local ok, p = pcall(function() return LSM:Fetch(LSM.MediaType.FONT, FONT_NAME) end)
        if ok and p then return p end
    end
    return FONT_FALLBACK
end

local function buildWindow()
    if win then return win end
    if not CreateFrame then return nil end

    local f = CreateFrame("Frame", WIN_NAME, UIParent, "BackdropTemplate")
    win = { frame = f }

    f:SetFrameStrata("DIALOG")
    f:SetSize(700, 344)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = [[Interface\DialogFrame\UI-DialogBox-Background]],
            edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    f:Hide()

    -- Escape closes it.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, WIN_NAME)
    end

    -- Draggable title region.
    local title = CreateFrame("Frame", nil, f)
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetPoint("TOPRIGHT", -12, -12)
    title:SetHeight(20)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() f:StartMoving() end)
    title:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    -- Header label reflecting KCM.State.debug.
    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("LEFT", title, "LEFT", 0, 0)
    header:SetText(headerText())
    win.header = header

    -- Close button.
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() DL.Hide() end)

    -- Toggle button flips KCM.State.debug.
    local toggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    toggle:SetSize(70, 20)
    toggle:SetPoint("RIGHT", title, "RIGHT", -24, 0)
    toggle:SetText("Toggle")
    toggle:SetScript("OnClick", function() DL.Toggle() end)

    -- Scrolling message frame.
    local smf = CreateFrame("ScrollingMessageFrame", nil, f)
    smf:SetPoint("TOPLEFT", 14, -38)
    smf:SetPoint("BOTTOMRIGHT", -14, 34)
    smf:SetFontObject("GameFontHighlightSmall")
    if smf.SetFont then smf:SetFont(fontPath(), FONT_SIZE, "") end
    smf:SetMaxLines(MAX_LINES)
    smf:SetJustifyH("LEFT")
    smf:SetFading(false)
    smf:SetInsertMode("BOTTOM")
    smf:EnableMouseWheel(true)
    smf:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then smf:ScrollUp() else smf:ScrollDown() end
    end)
    win.smf = smf

    -- Copy: dump the plain buffer into a multiline EditBox for Ctrl-C.
    local copyBox = CreateFrame("EditBox", nil, f)
    copyBox:SetMultiLine(true)
    copyBox:SetAutoFocus(false)
    copyBox:SetFontObject("GameFontHighlightSmall")
    if copyBox.SetFont then copyBox:SetFont(fontPath(), FONT_SIZE, "") end
    copyBox:SetPoint("TOPLEFT", 14, -38)
    copyBox:SetPoint("BOTTOMRIGHT", -14, 34)
    copyBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus(); eb:Hide() end)
    copyBox:Hide()
    win.copyBox = copyBox

    local copy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copy:SetSize(70, 20)
    copy:SetPoint("BOTTOMLEFT", 14, 8)
    copy:SetText("Copy")
    copy:SetScript("OnClick", function()
        if copyBox:IsShown() then
            copyBox:Hide()
        else
            copyBox:SetText(table.concat(buffer, "\n"))
            copyBox:Show()
            copyBox:HighlightText()
            copyBox:SetFocus()
        end
    end)

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(70, 20)
    clear:SetPoint("BOTTOMLEFT", 90, 8)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function() DL.Clear() end)

    return win
end

-- ---------------------------------------------------------------------------
-- Public logging + visibility API
-- ---------------------------------------------------------------------------

function DL.AddLine(tag, msg)
    -- Zero-alloc gate BEFORE any formatting.
    if not DL.IsEnabled() then return end
    local timeStr = now()
    if not buildWindow() then return end
    buffer[#buffer + 1] = DL.FormatPlain(tag, msg, timeStr)
    if win and win.smf then
        win.smf:AddMessage(DL.FormatColored(tag, msg, timeStr))
    end
end

function DL.Clear()
    for i = #buffer, 1, -1 do buffer[i] = nil end
    if win and win.smf then win.smf:Clear() end
    if win and win.copyBox then win.copyBox:SetText(""); win.copyBox:Hide() end
end

function DL.Show()
    if not buildWindow() then return end
    if win.header then win.header:SetText(headerText()) end
    win.frame:Show()
end

function DL.Hide()
    if win and win.frame then win.frame:Hide() end
end

function DL.Toggle_Window()
    if win and win.frame and win.frame:IsShown() then
        DL.Hide()
    else
        DL.Show()
    end
end

-- `DL.Toggle` flips the enabled flag (standard API). Window visibility toggling
-- lives on DL.Toggle_Window so the two concerns don't collide.
