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

-- GCD-swipe suppression curve, built once and lazily (mirrors KickCD's
-- buildGcdSuppressCurve, modules/IconGrid_Render.lua ~line 84 there — same
-- pattern, deliberately duplicated rather than shared via LibKa0s; see
-- closed issue #26 (GCD-01)).
--
-- Under Midnight a spell cooldown's start/duration are SECRET once combat
-- begins, so Lua may not compare "is this just the GCD" itself (see the
-- comment block at core/MacroDisplay.lua:79-99). The trick is to never
-- compare the secret in Lua: build a step curve once and hand it to
-- EvaluateRemainingDuration, which runs C-side and accepts a secret-tainted
-- duration object. The curve steps from 0 (hide) to 1 (show) at
-- KCM.GCD_UPPER, and SetAlphaFromBoolean(true, value, 0) applies whichever
-- the client resolves — also a C method, also safe to call with a
-- secret-derived value.
--
-- Accepted limitation (do not try to fix): the curve evaluates REMAINING
-- duration, which can't distinguish a 1.5s GCD from the last 1.5s of a 60s
-- cooldown — that would need the TOTAL duration, which is also secret. A real
-- cooldown's swipe therefore vanishes for its own final ~1.6s instead of
-- visibly counting down to zero. Matches KickCD; see docs/macro-bar.md.
local gcdSuppressCurve

local function buildGcdSuppressCurve()
    if gcdSuppressCurve then return end
    if not (_G.C_CurveUtil and _G.C_CurveUtil.CreateCurve) then return end
    local upper = KCM.GCD_UPPER or 1.6
    local curve = _G.C_CurveUtil.CreateCurve()
    if curve.SetType and Enum and Enum.LuaCurveType then
        curve:SetType(Enum.LuaCurveType.Linear)
    end
    curve:AddPoint(0,             0)   -- remaining <= GCD  -> hide
    curve:AddPoint(upper,         0)
    curve:AddPoint(upper + 0.001, 1)   -- remaining >  GCD  -> show
    curve:AddPoint(3600,          1)
    gcdSuppressCurve = curve
end

-- Drive one Cooldown frame from MacroDisplay's cooldown state. Shared with the
-- flyout's entries (modules/MacroBarFlyout.lua:413), which paint the same
-- way — one applier so the same item never renders differently in the two
-- places.
--
-- Whether there IS a cooldown is decided upstream from data that is safe to
-- inspect (see MD.CooldownForID); all this does is pick a setter. A duration
-- object is the only thing that survives combat, because it is what the client
-- lets a tainted caller hand over when the times inside it are secret. The raw
-- pair is the fallback for a client without duration objects, where nothing is
-- secret and SetCooldown still works.
function BB.ApplyCooldown(cd, active, durationObject, start, duration)
    if not cd then return end

    -- showGCD defaults to false, i.e. suppression is ON out of the box.
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
    local suppress = not (cfg and cfg.showGCD == true)

    -- The bling (the sparkle CooldownFrameTemplate plays on completion) is not
    -- covered by the frame's alpha the way the swipe and edge are — confirmed
    -- in-game: fading the frame via SetAlphaFromBoolean below suppresses the
    -- swipe correctly, but the bling still fires. It needs its own explicit
    -- suppression via SetDrawBling. Do not delete this call as redundant with
    -- the alpha fade; it is the only thing that stops the bling.
    --
    -- SetDrawBling takes a plain boolean, unlike SetAlphaFromBoolean /
    -- SetCooldownFromDurationObject, which accept a secret-tainted value and
    -- resolve it C-side — so this must key off the non-secret `suppress` flag
    -- rather than the curve's output, which cannot be compared or branched on
    -- in Lua. Applied before the `not active` early return: the setting can
    -- change while a cooldown is inactive, and without this a frame would
    -- keep a stale bling setting until its next activation.
    if cd.SetDrawBling then
        cd:SetDrawBling(not suppress)
    end

    if not active then
        cd:Clear()
        return
    end
    if durationObject and cd.SetCooldownFromDurationObject then
        cd:SetCooldownFromDurationObject(durationObject)
    elseif start and duration then
        cd:SetCooldown(start, duration)
    else
        cd:Clear()
    end

    buildGcdSuppressCurve()
    if suppress and durationObject and gcdSuppressCurve and cd.SetAlphaFromBoolean then
        cd:SetAlphaFromBoolean(true, durationObject:EvaluateRemainingDuration(gcdSuppressCurve), 0)
    else
        -- Load-bearing, do not delete: without this reset, a frame left
        -- faded during a GCD would stay faded forever once the user turns
        -- showGCD on, or if the curve/API degrades mid-session — nothing
        -- else ever restores full alpha.
        cd:SetAlpha(1)
    end
end

function BB.RefreshCooldown(btn)
    if not (btn and btn.catKey and btn.cooldown) then return end
    local MD = KCM.MacroDisplay
    if not MD then return end
    BB.ApplyCooldown(btn.cooldown, MD.Cooldown(macroName(btn.catKey)))
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

-- ---------------------------------------------------------------------------
-- Chrome appliers
--
-- Exported on BB because the flyout's entries take the SAME appearance block
-- (modules/MacroBarFlyout.lua's bindEntry) — the two used to be verbatim copies
-- of each other and had to be kept in sync by hand. One applier means the same
-- item can never render differently in the two places, and the zoom clamp's
-- bounds are shared rather than repeated.
-- ---------------------------------------------------------------------------

local EMPTY_COLOR           = {}
local BORDER_COLOR_DEFAULT  = { 1, 1, 1, 1 }
local BACKDROP_FILL_DEFAULT = { 0, 0, 0, 0.6 }

-- Unpack a saved {r,g,b,a} over its default, component by component. A stored
-- color may be absent entirely or short a component, and each missing slot
-- falls back on its own. Returns four values and allocates nothing — this runs
-- on every layout pass.
local function rgba(stored, default)
    stored = stored or EMPTY_COLOR
    return stored[1] or default[1], stored[2] or default[2],
           stored[3] or default[3], stored[4] or default[4]
end

-- Border is its own BackdropTemplate child rather than a texture on the
-- button, so `buttonBorderOffset` can push the edge slices OUTWARD off the
-- icon. The old action-button slot art was a fixed 64px frame drawn over a
-- 36px well, which is exactly why it bled across the icon at every size.
function BB.ApplyBorder(frame, anchorTo, cfg)
    if cfg.buttonBorder == false then
        frame:Hide()
        return
    end
    local off = tonumber(cfg.buttonBorderOffset) or 0
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",     anchorTo, "TOPLEFT",     -off,  off)
    frame:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT",  off, -off)
    frame:SetBackdrop({
        edgeFile = borderTexture(cfg.buttonBorderStyle),
        edgeSize = math.max(1, tonumber(cfg.buttonBorderSize) or 4),
    })
    frame:SetBackdropBorderColor(rgba(cfg.buttonBorderColor, BORDER_COLOR_DEFAULT))
    frame:Show()
end

-- Icon zoom crops the texture symmetrically, which trims the dark edge
-- baked into most item icons so it doesn't read as a second border. Anchoring
-- the icon is the caller's business — the flyout's entries are anchored once at
-- creation and only ever re-cropped.
function BB.ApplyIconZoom(icon, cfg)
    local zoom = tonumber(cfg.iconZoom) or 0
    if zoom < 0 then zoom = 0 elseif zoom > 40 then zoom = 40 end
    local z = zoom / 100
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
end

function BB.ApplyBackdropTex(tex, cfg)
    tex:SetColorTexture(rgba(cfg.buttonBackdropColor, BACKDROP_FILL_DEFAULT))
    if cfg.buttonBackdrop then tex:Show() else tex:Hide() end
end

-- Apply the size + chrome settings from db.profile.macroBar. Called on every
-- layout pass so a slider drag repaints without rebuilding the button.
function BB.ApplyStyle(btn, cfg)
    if not (btn and cfg) then return end
    local size = tonumber(cfg.buttonSize) or 36
    btn:SetSize(size, size)

    BB.ApplyBorder(btn.border, btn, cfg)

    btn.icon:ClearAllPoints()
    btn.icon:SetAllPoints(btn)
    BB.ApplyIconZoom(btn.icon, cfg)

    BB.ApplyBackdropTex(btn.backdropTex, cfg)

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
