-- modules/MacroBarButton.lua — one macro-bar slot.
--
-- A SecureActionButtonTemplate button whose `macro` attribute is set ONCE at
-- creation and never changes: a slot belongs to its category for the frame's
-- whole life. That is what makes the bar combat-safe — reordering moves anchors
-- (an out-of-combat operation) and never rewrites a secure attribute, and the
-- macro body auto-rewriting underneath needs no involvement from the bar at
-- all. Clicking runs the macro through Blizzard's own secure path, so no
-- protected API is ever called from addon code.
--
-- Icon / count / cooldown come from core/MacroDisplay.lua, which reads the pick
-- MacroManager recorded in db.profile.macroState. Cooldown/count styling is
-- deliberately stock Blizzard (CooldownFrameTemplate swipe honoring the
-- countdown-numbers CVar, NumberFontNormal count) — see the tracking issue for
-- configurable styling.
--
-- The slot also owns a hover flyout (modules/MacroBarFlyout.lua) listing every
-- currently-usable candidate in its category. Created here, out of combat,
-- alongside the button; its content is rebuilt by MacroBar.Refresh.
--
-- Drag model:
--   * OnDragStart  -> PickupMacro, so a slot can be dragged onto a normal
--                     Blizzard action bar. Taint-free at any time, exactly like
--                     the settings panel's KCMMacroDragIcon.
--   * OnReceiveDrag -> if the cursor holds a KCM macro, swap the two slots.
--                     Anything else is ignored and the cursor is left untouched,
--                     which is what keeps this bar CM-only.

local _, NS = ...
local KCM = NS
KCM.MacroBarButton = KCM.MacroBarButton or {}
local BB = KCM.MacroBarButton

local CreateFrame = CreateFrame
local PUSHED_TEXTURE    = [[Interface\Buttons\UI-Quickslot-Depress]]
local HIGHLIGHT_TEXTURE = [[Interface\Buttons\ButtonHilight-Square]]
local BORDER_FALLBACK   = [[Interface\Tooltips\UI-Tooltip-Border]]

local function macroName(catKey)
    return KCM.MacroBarModel and KCM.MacroBarModel.MacroName(catKey) or nil
end

-- Resolve a LibSharedMedia border name to its edge texture, falling back to the
-- Blizzard tooltip border if LSM is absent or the name isn't registered (a
-- profile can name a border a since-uninstalled addon supplied).
local function borderTexture(name)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Fetch then
        local tex = LSM:Fetch("border", name or "Blizzard Tooltip", true)
        if tex then return tex end
    end
    return BORDER_FALLBACK
end
BB.BorderTexture = borderTexture   -- shared with modules/MacroBar.lua's backdrop

-- Resolve whatever the cursor is holding to a KCM category key, or nil.
-- GetCursorInfo returns ("macro", macroIndex) for a picked-up macro.
local function cursorCatKey()
    if not GetCursorInfo then return nil end
    local kind, index = GetCursorInfo()
    if kind ~= "macro" or not index then return nil end
    if not GetMacroInfo then return nil end
    local name = GetMacroInfo(index)
    return KCM.MacroBarModel and KCM.MacroBarModel.KeyForMacroName(name) or nil
end

-- ---------------------------------------------------------------------------
-- Display refresh
-- ---------------------------------------------------------------------------

function BB.RefreshIcon(btn)
    if not (btn and btn.catKey) then return end
    local MD = KCM.MacroDisplay
    if not MD then return end
    local name = macroName(btn.catKey)
    btn.icon:SetTexture(MD.Texture(name))

    -- Consumables are worth counting even at 1 — "you have exactly one potion
    -- left" is the case a user most wants to see. Spell picks and empty-state
    -- macros report no count at all.
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
    local count = MD.Count(name)
    if count and count > 0 and not (cfg and cfg.showCount == false) then
        btn.count:SetText(count)
        btn.count:Show()
    else
        btn.count:SetText("")
        btn.count:Hide()
    end
end

function BB.RefreshCooldown(btn)
    if not (btn and btn.catKey and btn.cooldown) then return end
    local MD = KCM.MacroDisplay
    if not MD then return end
    local start, duration, enable = MD.Cooldown(macroName(btn.catKey))
    if start and duration and duration > 0 then
        btn.cooldown:SetCooldown(start, duration, enable)
    else
        btn.cooldown:Clear()
    end
end

function BB.Refresh(btn)
    BB.RefreshIcon(btn)
    BB.RefreshCooldown(btn)
end

-- Label text. AUTO measures the full display name against the space available
-- and falls back to the category's short form only when it genuinely doesn't
-- fit — measuring the real FontString beats guessing at a character budget,
-- since the answer depends on the font, the size and the string.
local function applyLabelText(btn, cfg, fontSize)
    local full, short = KCM.MacroBarModel.Labels(btn.catKey)
    local mode = cfg.labelText or "AUTO"
    if mode == "SHORT" then
        btn.label:SetText(short)
        return
    end
    btn.label:SetText(full)
    if mode == "FULL" or full == short then return end
    -- An outside label may overflow the button freely; an inside one has only
    -- the button's own width (minus a hair of breathing room) to work with.
    if cfg.labelPlacement == "OUTSIDE" then return end
    local avail = (tonumber(cfg.buttonSize) or 36) - 2
    if btn.label:GetStringWidth() > avail then
        btn.label:SetText(short)
    end
    -- Wrapping is off (SetWordWrap(false) at construction), so an over-long
    -- short form is clipped rather than pushed onto a second line, which would
    -- desync the label from the button's height. fontSize is passed for future
    -- shrink-to-fit; unused today.
    local _ = fontSize
end

local function applyLabel(btn, cfg)
    if not cfg.buttonLabel then
        btn.label:Hide()
        return
    end
    local BL = KCM.MacroBarLayout
    local pts = BL.LabelFontSize(cfg.buttonSize, cfg.labelScale)
    -- Flags are set explicitly, never carried over from GetFont(): re-using the
    -- current flags would make the outline sticky, since the previous pass had
    -- already written "OUTLINE" into them.
    local fontPath = btn.label:GetFont()
    if fontPath then
        btn.label:SetFont(fontPath, pts, cfg.labelOutline ~= false and "OUTLINE" or "")
    end
    local point, relPoint, dx, dy, justify = BL.LabelAnchor(cfg)
    btn.label:ClearAllPoints()
    btn.label:SetPoint(point, btn, relPoint, dx, dy)
    btn.label:SetJustifyH(justify)
    local c = cfg.labelColor or {}
    btn.label:SetTextColor(c[1] or 1, c[2] or 0.82, c[3] or 0, c[4] or 1)
    applyLabelText(btn, cfg, pts)
    btn.label:Show()
end

-- Apply the size + chrome settings from db.profile.macroBar. Called on every
-- layout pass so a slider drag repaints without rebuilding the button.
function BB.ApplyStyle(btn, cfg)
    if not (btn and cfg) then return end
    local size = tonumber(cfg.buttonSize) or 36
    btn:SetSize(size, size)

    -- Border is its own BackdropTemplate child rather than a texture on the
    -- button, so `buttonBorderOffset` can push the edge slices OUTWARD off the
    -- icon. The old action-button slot art was a fixed 64px frame drawn over a
    -- 36px well, which is exactly why it bled across the icon at every size.
    if cfg.buttonBorder ~= false then
        local off  = tonumber(cfg.buttonBorderOffset) or 0
        local edge = math.max(1, tonumber(cfg.buttonBorderSize) or 4)
        btn.border:ClearAllPoints()
        btn.border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -off,  off)
        btn.border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  off, -off)
        btn.border:SetBackdrop({
            edgeFile = borderTexture(cfg.buttonBorderStyle),
            edgeSize = edge,
        })
        local c = cfg.buttonBorderColor or {}
        btn.border:SetBackdropBorderColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
        btn.border:Show()
    else
        btn.border:Hide()
    end

    btn.icon:ClearAllPoints()
    btn.icon:SetAllPoints(btn)
    -- Icon zoom crops the texture symmetrically, which trims the dark edge
    -- baked into most item icons so it doesn't read as a second border.
    local zoom = tonumber(cfg.iconZoom) or 0
    if zoom < 0 then zoom = 0 elseif zoom > 40 then zoom = 40 end
    local z = zoom / 100
    btn.icon:SetTexCoord(z, 1 - z, z, 1 - z)

    local bg = cfg.buttonBackdropColor or {}
    btn.backdropTex:SetColorTexture(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.6)
    if cfg.buttonBackdrop then btn.backdropTex:Show() else btn.backdropTex:Hide() end

    applyLabel(btn, cfg)

    -- NB: the flyout is deliberately NOT rebuilt here. MacroBar.Refresh owns
    -- that, and Update calls it immediately after this pass — doing it in both
    -- places rebuilt every flyout twice per settings change.

    -- Count visibility is owned by RefreshIcon (it depends on the live pick as
    -- well as the setting), so re-run it rather than toggling the fontstring here.
    BB.RefreshIcon(btn)
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- Build the slot for `catKey`. MUST be called out of combat: creating a frame
-- from a secure template and stamping its attributes is a protected-frame
-- operation. modules/MacroBar.lua owns that guard.
function BB.Create(parent, catKey, index)
    local name = macroName(catKey)
    if not name then return nil end

    local btn = CreateFrame("Button", "KCMMacroBarButton" .. index, parent,
        "SecureActionButtonTemplate")
    btn.catKey = catKey
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macro", name)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")

    btn.backdropTex = btn:CreateTexture(nil, "BACKGROUND")
    btn.backdropTex:SetAllPoints(btn)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)

    btn:SetPushedTexture(PUSHED_TEXTURE)
    btn:SetHighlightTexture(HIGHLIGHT_TEXTURE)
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)

    -- Border sits above the icon AND the cooldown swipe; the text overlay sits
    -- above the border so a corner count / label is never sliced by an edge
    -- texture. Three explicit levels beat relying on draw-layer ordering,
    -- because Cooldown is a frame, not a layer on this button.
    local level = btn:GetFrameLevel()
    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetFrameLevel(level + 2)

    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints(btn)
    overlay:SetFrameLevel(level + 3)
    btn.overlay = overlay

    btn.count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.count:SetJustifyH("RIGHT")

    btn.label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetWordWrap(false)
    btn.label:Hide()

    btn:SetScript("OnEnter", function(self)
        local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
        if cfg and cfg.tooltips == false then return end
        if KCM.MacroDisplay then KCM.MacroDisplay.SetTooltip(self, macroName(self.catKey)) end
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    btn:SetScript("OnDragStart", function(self)
        local idx = KCM.MacroDisplay and KCM.MacroDisplay.MacroIndex(macroName(self.catKey)) or 0
        if idx ~= 0 and PickupMacro then PickupMacro(idx) end
    end)

    btn:SetScript("OnReceiveDrag", function(self)
        local fromKey = cursorCatKey()
        -- Not one of ours (or nothing there): leave the cursor alone. Rejecting
        -- silently is what makes this a CM-only bar.
        if not fromKey or fromKey == self.catKey then return end
        if KCM.MacroBar and KCM.MacroBar.SwapSlots then
            if KCM.MacroBar.SwapSlots(fromKey, self.catKey) and ClearCursor then
                ClearCursor()
            end
        end
    end)

    -- Hover flyout: the indicator + secure container. Created here (out of
    -- combat, with the button) so opening it later never needs frame creation.
    if KCM.MacroBarFlyout then KCM.MacroBarFlyout.Create(btn, catKey, index) end

    BB.Refresh(btn)
    return btn
end
