-- modules/DebugLog.lua — on-screen debug console (standard debug-logging).
--
-- A movable, Escape-closable window styled like the addon's own frames: a
-- draggable title bar with flat text buttons, a 1px divider, and a
-- ScrollingMessageFrame that mirrors gated debug output in a monospace font.
-- A left-aligned Debug: ON/OFF toggle flips the session-only enabled flag
-- (green ON / red OFF), and Copy opens a separate read-through EditBox window
-- for Ctrl-C. The two FormatPlain/FormatColored helpers are PURE (no frame or
-- global touch, timestamp passed in) so they unit-test headlessly; both the
-- window and the copy window build lazily on first use and cache.
--
-- Layout note (why buttons parent to the title bar): every title-bar control is
-- a CHILD of `titleBar`, and a child frame always receives mouse input above its
-- parent. The earlier layout parented the toggle as a SIBLING of the draggable,
-- mouse-enabled title frame, so the title swallowed the click and the toggle was
-- dead. Parenting to the bar is what makes the toggle (and Copy/Clear/close)
-- clickable while the empty stretch of the bar still drags the window.

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
local FONT_SIZE     = 10   -- standard reference size (debug-logging-§2)
local WIN_NAME      = "ConsumableMasterDebugWindow"
local MAX_LINES     = 500

-- Cached window widgets, nil until first build.
local win
local copyWin

-- Accumulated plain-text lines for the Copy buffer (capped like the log).
local buffer = {}

local function now()
    return (date and date("%H:%M:%S")) or ""
end

-- ---------------------------------------------------------------------------
-- Pure formatters (unit-tested; must not touch frames or globals)
-- ---------------------------------------------------------------------------
--
-- Standard line shape (debug-logging-§3): `<HH:MM:SS> | [<Tag>] <content>`.
-- Console view: timestamp muted steel-blue (6f8faf), [tag] muted tan/gold
-- (c9a66b); the `|` separator and content stay default white. (`||` renders one
-- literal pipe inside a colour-coded string.) The plain Copy buffer mirrors the
-- same line with no colour codes. A nil/empty tag omits the `[tag]` segment so
-- any untagged line still reads cleanly rather than as `[]`, even though every
-- call site today passes a functional-area tag.

local function hasTag(tag)
    return tag ~= nil and tag ~= ""
end

function DL.FormatPlain(ts, tag, msg)
    ts, msg = tostring(ts or ""), tostring(msg or "")
    if hasTag(tag) then
        return ("%s | [%s] %s"):format(ts, tostring(tag), msg)
    end
    return ("%s | %s"):format(ts, msg)
end

function DL.FormatColored(ts, tag, msg)
    ts, msg = tostring(ts or ""), tostring(msg or "")
    if hasTag(tag) then
        return ("|cff6f8faf%s|r || |cffc9a66b[%s]|r %s"):format(ts, tostring(tag), msg)
    end
    return ("|cff6f8faf%s|r || %s"):format(ts, msg)
end

-- ---------------------------------------------------------------------------
-- Enabled state (mirrors KCM.State.debug — session-only, default off)
-- ---------------------------------------------------------------------------

function DL.IsEnabled()
    return KCM.State and KCM.State.debug == true
end

-- Repaint the header toggle to match the flag (green ON / red OFF).
function DL.RefreshHeader()
    if not (win and win.toggleFS) then return end
    local on = DL.IsEnabled()
    win.toggleFS:SetText(on and "Debug: ON" or "Debug: OFF")
    if on then
        win.toggleFS:SetTextColor(0.30, 0.85, 0.30)
    else
        win.toggleFS:SetTextColor(0.90, 0.30, 0.30)
    end
end

-- Single seam for changing debug state (debug-logging-§5). The slash command,
-- the panel checkbox, and the header toggle all route through here so the chat
-- ack, the header label, and the panel can't diverge: set flag → refresh header
-- → chat ack → console line at BOTH transitions → refresh the open options panel.
function DL.SetEnabled(on)
    on = on and true or false
    if KCM.State then KCM.State.debug = on end
    DL.RefreshHeader()
    -- Colour-coded chat ack through the shared [CM] printer (debug-logging-§5):
    -- ON green (40ff40) / OFF red (ff4040), mirroring the title-bar Debug: ON/OFF
    -- toggle so the flag reads identically in chat and on the console header.
    if KCM.Say then
        KCM.Say("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
    end
    -- Bracket every capture session at both ends. Written through the raw
    -- append (DL.AddLine is ungated), so the "logging disabled" line still lands
    -- after KCM.State.debug has flipped off — the flag-gated sink would swallow it.
    DL.AddLine("Debug", on and "logging enabled" or "logging disabled")
    -- On enable, emit a one-line [Init] session summary immediately after the
    -- bracket (debug-logging-§5/§8): addon + version, schema version, active
    -- profile, so a pasted log self-identifies which build/schema/profile it came
    -- from. Written through the raw DL.AddLine (not the gated KCM.Debug sink) so it
    -- lands the instant debug turns on. It rides the SetEnabled seam, not login,
    -- because the session-only flag is off at login — a load-time summary would be
    -- gated off and never render. Every value goes through the secret-safe
    -- stringifier per debug-logging-§4 (version/schema/profile are all plain).
    if on and KCM.db and KCM.db.global then
        local s = KCM.SafeToString or tostring
        local profileKey = KCM.db.GetCurrentProfile and KCM.db:GetCurrentProfile() or "?"
        DL.AddLine("Init", ("%s v%s, schema v%s, profile '%s'"):format(
            "Consumable Master", s(KCM.VERSION), s(KCM.db.global.schemaVersion), s(profileKey)))
    end
    if KCM.Options and KCM.Options.Refresh then KCM.Options.Refresh() end
    return on
end

-- Flip the enabled flag. Window visibility toggling lives on DL.Toggle_Window so
-- the two concerns don't collide.
function DL.Toggle()
    return DL.SetEnabled(not DL.IsEnabled())
end

-- ---------------------------------------------------------------------------
-- Skin + flat title-bar buttons (shared with the copy window)
-- ---------------------------------------------------------------------------

local function fontPath()
    if LSM then
        local ok, p = pcall(function() return LSM:Fetch(LSM.MediaType.FONT, FONT_NAME) end)
        if ok and p then return p end
    end
    return FONT_FALLBACK
end

-- Dark skin so the console reads like the addon's own frames (debug-logging-§1).
local BACKDROP = {
    bgFile   = [[Interface\Buttons\WHITE8x8]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}
local function applySkin(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Small flat text button for the title bar (Copy / Clear): muted resting colour,
-- gold on hover.
local function makeTextButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function makeCloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER")
    fs:SetText("\195\151")  -- multiplication sign ×
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.3, 0.3) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- ---------------------------------------------------------------------------
-- Lazy window construction (all frame work guarded for headless load)
-- ---------------------------------------------------------------------------

local function buildWindow()
    if win then return win end
    if not CreateFrame then return nil end

    local f = CreateFrame("Frame", WIN_NAME, UIParent, "BackdropTemplate")
    win = { frame = f }

    f:SetSize(700, 344)
    f:SetPoint("CENTER", 220, -80)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    -- Draggable title bar. Every control below parents to THIS frame so its
    -- clicks land above the drag region (see the header note).
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText("Consumable Master \226\128\148 Debug")
    win.title = title

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0, 0, 0, 1)

    local close = makeCloseButton(titleBar, function() DL.Hide() end)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local clear = makeTextButton(titleBar, "Clear", 42, function() DL.Clear() end)
    clear:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local copy = makeTextButton(titleBar, "Copy", 40, function() DL.ShowCopy() end)
    copy:SetPoint("RIGHT", clear, "LEFT", -6, 0)

    -- Left-aligned Debug: ON/OFF state toggle. Resting colour reflects the flag
    -- (green ON / red OFF); clicking flips it through the shared SetEnabled seam.
    local toggleBtn = CreateFrame("Button", nil, titleBar)
    toggleBtn:SetSize(80, 18)
    toggleBtn:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    local toggleFS = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toggleFS:SetPoint("LEFT")
    toggleBtn:SetScript("OnEnter", function() toggleFS:SetTextColor(1, 0.82, 0) end)
    toggleBtn:SetScript("OnLeave", function() DL.RefreshHeader() end)
    toggleBtn:SetScript("OnClick", function() DL.SetEnabled(not DL.IsEnabled()) end)
    win.toggleBtn = toggleBtn
    win.toggleFS  = toggleFS

    -- Scrolling message frame (monospace, 10pt).
    local smf = CreateFrame("ScrollingMessageFrame", nil, f)
    smf:SetPoint("TOPLEFT", 8, -(26 + 6))
    smf:SetPoint("BOTTOMRIGHT", -8, 14)
    if smf.SetFont then smf:SetFont(fontPath(), FONT_SIZE, "") end
    smf:SetJustifyH("LEFT")
    smf:SetFading(false)
    smf:SetMaxLines(MAX_LINES)
    smf:EnableMouseWheel(true)
    smf:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    win.smf = smf

    applySkin(f)
    if f.HookScript then f:HookScript("OnShow", function() DL.RefreshHeader() end) end
    DL.RefreshHeader()

    f:Hide()
    -- Escape closes it.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, WIN_NAME)
    end
    return win
end

-- Separate Copy window: a read-through multiline EditBox holding the whole log
-- as plain text (debug-logging-§6). WoW exposes no clipboard API, so the user's
-- Ctrl+C inside the EditBox is the only copy path; a separate window avoids the
-- colour escapes that copying the live ScrollingMessageFrame would drag along.
local function buildCopyWindow()
    if copyWin then return copyWin end
    if not CreateFrame then return nil end

    local f = CreateFrame("Frame", WIN_NAME .. "Copy", UIParent, "BackdropTemplate")
    copyWin = { frame = f }

    f:SetSize(560, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    local tbar = CreateFrame("Frame", nil, f)
    tbar:SetPoint("TOPLEFT", 1, -1)
    tbar:SetPoint("TOPRIGHT", -1, -1)
    tbar:SetHeight(26)
    tbar:EnableMouse(true)
    tbar:RegisterForDrag("LeftButton")
    tbar:SetScript("OnDragStart", function() f:StartMoving() end)
    tbar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER")
    t:SetText("Copy log \226\128\148 Ctrl+C, then Esc")

    local cclose = makeCloseButton(tbar, function() f:Hide() end)
    cclose:SetPoint("RIGHT", tbar, "RIGHT", -6, 0)

    local scroll = CreateFrame("ScrollFrame", WIN_NAME .. "CopyScroll", f,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    copyWin.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    if edit.SetFont then edit:SetFont(fontPath(), FONT_SIZE, "") end
    edit:SetAutoFocus(false)
    edit:SetWidth(510)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    scroll:SetScrollChild(edit)
    copyWin.edit = edit

    applySkin(f)
    f:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, WIN_NAME .. "Copy")
    end
    return copyWin
end

-- ---------------------------------------------------------------------------
-- Public logging + visibility API
-- ---------------------------------------------------------------------------

-- Raw append — NOT gated on the enabled flag. The zero-alloc gate lives in the
-- sink (KCM.Debug, core/Debug.lua) which is the sole ordinary caller; SetEnabled
-- also calls this directly to record the enable/disable transition lines.
function DL.AddLine(tag, msg)
    local timeStr = now()
    buffer[#buffer + 1] = DL.FormatPlain(timeStr, tag, msg)
    if #buffer > MAX_LINES then table.remove(buffer, 1) end
    local w = buildWindow()
    if w and w.smf then
        w.smf:AddMessage(DL.FormatColored(timeStr, tag, msg))
    end
end

function DL.Clear()
    for i = #buffer, 1, -1 do buffer[i] = nil end
    if win and win.smf then win.smf:Clear() end
    if copyWin and copyWin.edit then copyWin.edit:SetText("") end
end

function DL.ShowCopy()
    local c = buildCopyWindow()
    if not c then return end
    local w = c.scroll:GetWidth()
    c.edit:SetWidth((w and w > 0) and w or 510)
    c.edit:SetText(table.concat(buffer, "\n"))
    c.edit:SetCursorPosition(0)
    c.frame:Show()
    c.edit:SetFocus()
    c.edit:HighlightText()
end

function DL.Show()
    local w = buildWindow()
    if not w then return end
    DL.RefreshHeader()
    w.frame:Show()
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
