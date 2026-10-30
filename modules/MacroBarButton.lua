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
--   * OnDragStart  -> MacroDisplay.Pickup, so a slot can be dragged onto a
--                     normal Blizzard action bar. Taint-free, and refused with
--                     a chat line in combat (PickupMacro is protected) —
--                     exactly like the settings panel's KCMMacroDragIcon.
--   * OnReceiveDrag -> if the cursor holds a KCM macro, swap the two slots.
--                     Anything else is ignored and the cursor is left untouched,
--                     which is what keeps this bar CM-only.

local _, NS = ...
local KCM = NS
KCM.MacroBarButton = KCM.MacroBarButton or {}
local BB = KCM.MacroBarButton

local CreateFrame = CreateFrame
-- Every level below is an offset over the slot, named once in core/Constants.lua.
local LEVEL = KCM.Constants.LAYERS.LEVEL
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

-- ---------------------------------------------------------------------------
-- The skin's HUD style (skinning-§6; CM-03 of the 2026-10-29 skinning rollout)
--
-- Three HUD style settings follow the skin while their `<key>FromSkin`
-- companion is on, which it is by default (the rollout's X3) and after the
-- one-time v4 reset (core/Database.lua, the owner's O2): the bar's border
-- style (`bar.borderStyle`, shared by the flyout panel), the buttons' border
-- style and thickness (the icon family, `icon.borderStyle` / `icon.borderSize`)
-- and the label face (`hud.font`). Only texture, border and font follow (X4):
-- every HUD COLOR stays the player's swatch, and the sizes, flags, shadow and
-- offset stay the player's too (the inventory's D1). The count text has no
-- setting, so it simply takes the skin's HUD face and outline (D6).
--
-- Read per call through KCM.Skin.Resolve, a table read that allocates nothing:
-- these appliers run per button per layout pass, so S.BarStyle (a fresh table)
-- is never called here.
-- ---------------------------------------------------------------------------

local SOLID_EDGE = [[Interface\Buttons\WHITE8X8]]

--- A HUD style setting as drawn: the skin's token `kind` while `fromSkin` is on
--- or the stored value is the FROM_SKIN sentinel, else the stored value. A token
--- the facade cannot answer (the degraded facade carries no HUD strings) falls
--- back on the stored value, so nothing draws blank; a stored sentinel with no
--- token answers nil, which every reader below takes as its own shipped default.
function BB.Follow(kind, stored, fromSkin)
    local S = KCM.Skin
    if not (S and S.Resolve) then return stored end
    local v = S.Resolve(kind, stored, fromSkin)
    if v == nil or v == S.FROM_SKIN then
        if stored == S.FROM_SKIN then return nil end
        return stored
    end
    return v
end

--- A border style as a backdrop edgeFile: nil for "None" (no edge at all), the
--- flat white texture for "Solid" (the name the skin's icon family gives the
--- flat edge, SkinDefs minor 15; LibSharedMedia registers no border by it), and
--- any other name through LibSharedMedia.
function BB.EdgeFile(style)
    if style == "None" then return nil end
    if style == "Solid" then return SOLID_EDGE end
    return borderTexture(style)
end

--- A macroBar setting's shipped default (defaults/Profile.lua), the fallback a
--- swatch reads when its stored color is absent or short a component (the
--- inventory's D2: the default lives in one place, never re-typed here).
local NO_DEFAULT = {}
function BB.StyleDefault(key)
    local d = KCM.dbDefaults and KCM.dbDefaults.profile and KCM.dbDefaults.profile.macroBar
    return (d and d[key]) or NO_DEFAULT
end

-- The face each count string's font object gave it (its font object, and its
-- path, size and flags), recorded on the first pass so a later one never
-- compounds the size and the Scope's Ignore fonts can put it back. Weak-keyed:
-- the strings are the frames'.
local countFace = setmetatable({}, { __mode = "k" })

--- `obj` when it is a font object a string can be handed back: a global name or
--- a named object other than the string itself (an anonymous one goes back by
--- path instead).
local function namedFontObject(fs, obj)
    if type(obj) == "string" then return obj ~= "" and obj or nil end
    if type(obj) ~= "table" or obj == fs or type(obj.GetName) ~= "function" then return nil end
    local ok, name = pcall(obj.GetName, obj)
    if ok and type(name) == "string" and name ~= "" then return obj end
    return nil
end

--- Put a count the skin's face reached back on the face its font object gave it.
--- A count never skinned is left alone: it is still on its font object.
local function restoreCountFont(fs)
    local f = countFace[fs]
    if not f then return end
    if f.obj and fs.SetFontObject then
        fs:SetFontObject(f.obj)
    elseif f.path then
        fs:SetFont(f.path, f.size, f.flags or "")
    end
end

--- The count text in the skin's HUD face and outline, at the size its font
--- object gave it. While the skin names no face it is put back on the face its
--- font object gave it (a count never skinned is left alone): the degraded facade,
--- and the Scope's Ignore fonts, under which the library's hud.font token answers
--- nil (Skin minor 8). The count has no setting of its own, so its fallback is its
--- font object's face, and this SetFont is not a recorded paint, so the put-back
--- is this addon's to make.
function BB.ApplyCountFont(fs)
    if not (fs and fs.SetFont and fs.GetFont) then return end
    local S = KCM.Skin
    local face = S and S.Token and S.Token("hud.font")
    if type(face) ~= "string" then return restoreCountFont(fs) end
    local rec = countFace[fs]
    if not rec then
        local path, got, flags = fs:GetFont()
        if not tonumber(got) then return end
        rec = { obj = namedFontObject(fs, fs.GetFontObject and fs:GetFontObject()),
                path = path, size = tonumber(got), flags = flags }
        countFace[fs] = rec
    end
    -- The skin's face, so the skin's HUD size scales it (S.HudFontSize, LibKa0s
    -- v1.82.0, ruling D-09) from the recorded size, which is never written back.
    local size = S.HudFontSize and S.HudFontSize(rec.size, true) or rec.size
    local path = BB.FontFile(face, nil)
    if not path then return end
    local outline = S.Token("hud.outline")
    fs:SetFont(path, size, type(outline) == "string" and outline or "OUTLINE")
end

--- The label's face as drawn: the skin's `hud.font` while its companion is on,
--- the player's stored pick otherwise AND while the Scope's Ignore fonts is on
--- (the library's Resolve answers the stored value then, Skin minor 8; a stored
--- FROM_SKIN sentinel answers nil, the shipped default face).
function BB.LabelFace(cfg)
    return BB.Follow("hud.font", cfg.labelFont, cfg.labelFontFromSkin)
end

--- The label as drawn, size and flags (LibKa0s v1.82.0, rulings D-07 and D-09): the
--- stored size `pts` scaled by the skin's HUD size while the label uses the skin's
--- face (S.HudFontSize; as stored with its own face or under Ignore fonts), and the
--- stored flags through S.FontFlags, so From skin follows the Font outline and a
--- picked flag wins. Neither stored value is ever rewritten.
function BB.LabelFont(cfg, pts)
    local S = KCM.Skin
    local fromSkin = cfg.labelFontFromSkin == true
        or (S ~= nil and S.FROM_SKIN ~= nil and cfg.labelFont == S.FROM_SKIN)
    local size = (S and S.HudFontSize) and S.HudFontSize(pts, fromSkin) or pts
    local flags = cfg.labelFlags
    if S and S.FontFlags then
        flags = S.FontFlags(flags)
    elseif flags == nil then
        flags = "OUTLINE"
    end
    return size, flags
end

-- Resolve a LibSharedMedia font name to its file, falling back to whatever face
-- the FontString already carries. Same ladder and the same reason as
-- borderTexture above: a profile can name a face a since-uninstalled addon
-- supplied, and a nil path handed to SetFont makes the text vanish rather than
-- raise.
local function fontFile(name, current)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Fetch then
        local path = LSM:Fetch("font", name or "Friz Quadrata TT", true)
        if path then return path end
    end
    return current
end
BB.FontFile = fontFile

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

-- GCD-swipe suppression curve, built once and lazily (mirrors KickCD's own
-- `buildGcdSuppressCurve`, in its modules/IconGrid_Render.lua — same
-- pattern, deliberately duplicated rather than shared via LibKa0s; see
-- closed issue #26 (GCD-01)).
--
-- Under Midnight a spell cooldown's start/duration are SECRET once combat
-- begins, so Lua may not compare "is this just the GCD" itself (see the
-- header on `MD.CooldownForID`, in core/MacroDisplay.lua). The trick is to never
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
-- flyout's entries -- `FO.RefreshCooldown` in modules/MacroBarFlyout.lua calls
-- straight into this -- so the same item never renders differently in the two
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

-- A stored swatch resolved through its "use class color" companion
-- (options-ui-§17), over its shipped default component by component: a stored
-- color may be absent entirely or short a component, and each missing slot
-- falls back on its own. Returns four values and allocates nothing — this runs
-- on every layout pass. The resolver is the addon's one (core/CoreSetup.lua);
-- the default is the setting's own, read from defaults/Profile.lua.
local function swatch(stored, useClass, default)
    default = default or NO_DEFAULT
    return KCM.SwatchColor(stored, useClass,
        default[1], default[2], default[3], default[4])
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
    local fontPath = fontFile(BB.LabelFace(cfg), btn.label:GetFont())
    if fontPath then
        -- `labelFlags` is the canonical font-flags STRING (options-ui-§16); "" is
        -- a real stored value and means no flags at all, and "@skin" (From skin)
        -- resolves through the Font outline (BB.LabelFont).
        local size, flags = BB.LabelFont(cfg, pts)
        btn.label:SetFont(fontPath, size, flags)
    end
    -- Font shadow. Cleared explicitly when off, never left to whatever the last
    -- pass wrote: a shadow set once and not cleared is as sticky as the outline
    -- flags above were.
    if btn.label.SetShadowOffset and btn.label.SetShadowColor then
        if cfg.labelShadow then
            btn.label:SetShadowColor(0, 0, 0, 1)
            btn.label:SetShadowOffset(1, -1)
        else
            btn.label:SetShadowColor(0, 0, 0, 0)
            btn.label:SetShadowOffset(0, 0)
        end
    end
    local point, relPoint, dx, dy, justify = BL.LabelAnchor(cfg)
    btn.label:ClearAllPoints()
    btn.label:SetPoint(point, btn, relPoint, dx, dy)
    btn.label:SetJustifyH(justify)
    btn.label:SetTextColor(swatch(cfg.labelColor, cfg.useClassColorLabel,
        BB.StyleDefault("labelColor")))
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

-- Border is its own BackdropTemplate child rather than a texture on the
-- button, so `buttonBorderOffset` can push the edge slices OUTWARD off the
-- icon. The old action-button slot art was a fixed 64px frame drawn over a
-- 36px well, which is exactly why it bled across the icon at every size.
function BB.ApplyBorder(frame, anchorTo, cfg)
    local fromSkin = cfg.buttonBorderStyleFromSkin
    local edge = BB.EdgeFile(BB.Follow("icon.borderStyle", cfg.buttonBorderStyle, fromSkin))
    if cfg.buttonBorder == false or edge == nil then
        frame:Hide()
        return
    end
    local off = tonumber(cfg.buttonBorderOffset) or 0
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",     anchorTo, "TOPLEFT",     -off,  off)
    frame:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT",  off, -off)
    local size = BB.Follow("icon.borderSize", cfg.buttonBorderSize, fromSkin)
    frame:SetBackdrop({
        edgeFile = edge,
        edgeSize = math.max(1, tonumber(size) or 4),
    })
    frame:SetBackdropBorderColor(swatch(cfg.buttonBorderColor,
        cfg.useClassColorButtonBorder, BB.StyleDefault("buttonBorderColor")))
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
    tex:SetColorTexture(swatch(cfg.buttonBackdropColor,
        cfg.useClassColorButtonBackdrop, BB.StyleDefault("buttonBackdropColor")))
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
    BB.ApplyCountFont(btn.count)

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
    -- Pin the secure handler to the release we registered for. Left unset, it
    -- falls back to the ActionButtonUseKeyDown cvar (on by default), acts only
    -- on the DOWN half, and silently ignores every mouse click on this slot.
    btn:SetAttribute("useOnKeyDown", false)
    btn:RegisterForDrag("LeftButton")

    btn.backdropTex = btn:CreateTexture(nil, "BACKGROUND")
    btn.backdropTex:SetAllPoints(btn)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)

    btn:SetPushedTexture(PUSHED_TEXTURE)
    btn:SetHighlightTexture(HIGHLIGHT_TEXTURE)
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end

    -- The slot's ladder (KCM.Constants.LAYERS.LEVEL): the swipe over the icon,
    -- the flyout indicator over the swipe (modules/MacroBarFlyout.lua), the
    -- border over both, and the text overlay over the border so a corner count
    -- or label is never sliced by an edge texture. Every rung is an explicit
    -- level, the swipe included: a child left at the default parent + 1 ties
    -- with any sibling given + 1, and the client breaks that tie by creation
    -- order (frame-layering-§3).
    local level = btn:GetFrameLevel()
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetFrameLevel(level + LEVEL.FILL)

    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetFrameLevel(level + LEVEL.BORDER)

    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints(btn)
    overlay:SetFrameLevel(level + LEVEL.OVERLAY)
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
        if KCM.MacroDisplay then KCM.MacroDisplay.Pickup(macroName(self.catKey)) end
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
