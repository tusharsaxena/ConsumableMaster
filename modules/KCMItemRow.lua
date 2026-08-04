-- KCMItemRow.lua — Custom AceGUI widget for a single priority-list row.
--
-- Renders [owned icon] [item icon] [quality glyph?] [item name] [pick star] on
-- a mouse-enabled frame, with GameTooltip:SetItemByID on hover. The custom
-- widget exists so the row can:
--   1. Show the real in-game item tooltip on hover.
--   2. Surface the item's crafting-quality tier as a glyph (the same one
--      Blizzard puts inline in consumable tooltips), when applicable.
--   3. Surface a "currently picked" glyph without leaning on `<- pick` text.
--
-- Acquired via `AceGUI:Create("KCMItemRow")` in settings/Category.lua, then
-- configured with `:SetCustomData({ itemID, owned, isPick, pickMH, pickOH,
-- applicable, fallbackName })`.
-- The SetText / SetFontObject methods are no-op stubs so the widget tolerates
-- any AceGUI consumer that pre-emptively calls them on every child.

local _, NS = ...
local KCM = NS

local Type, Version = "KCMItemRow", 3
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs = pairs
local CreateFrame, UIParent = CreateFrame, UIParent
local GameTooltip = GameTooltip

local OWNED_TEX     = "Interface\\RaidFrame\\ReadyCheck-Ready"
local NOT_OWNED_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local PICK_TEX      = "Interface\\COMMON\\FavoritesIcon"
local FALLBACK_ICON = 134400 -- INV_Misc_QuestionMark

local ROW_HEIGHT    = 26
-- Item icon (real item texture) at full row size. Owned glyph runs ~10%
-- smaller because ReadyCheck-Ready/NotReady are full-bleed textures with
-- no transparent padding — at the same pixel size they read as visually
-- larger than the padded button glyphs (info / remove) on the right side
-- of the row. Trimming OWNED_ICON_SIZE evens out the perceived size.
local ICON_SIZE       = 22
local OWNED_ICON_SIZE = 20
local ICON_GAP      = 4
local QUALITY_GAP   = 1  -- tighter gap between quality glyph and name
-- Pick star lives on the padded side (FavoritesIcon has significant
-- transparent padding around the glyph) so it needs a slightly larger box
-- than OWNED_ICON_SIZE to read the same visible size as ICON_SIZE / the
-- padded row buttons (score / delete, both 22).
local PICK_SIZE     = 22
local QUALITY_SIZE  = 14
local HAND_TAG_GAP   = 2
-- Reserved width budget for handTag ("MH+OH" is the widest string it shows)
-- so applyLabelWidth can keep the label from overlapping it on perHand rows.
local HAND_TAG_WIDTH = 40
local NOT_APPLICABLE_ALPHA = 0.4

local function iconForItem(itemID)
    if not itemID or not (C_Item and C_Item.GetItemInfoInstant) then
        return FALLBACK_ICON
    end
    local _, _, _, _, tex = C_Item.GetItemInfoInstant(itemID)
    return tex or FALLBACK_ICON
end

local function iconForSpell(spellID)
    if not spellID then return FALLBACK_ICON end
    if C_Spell and C_Spell.GetSpellTexture then
        local t = C_Spell.GetSpellTexture(spellID)
        if t then return t end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.iconID then return info.iconID end
    end
    return FALLBACK_ICON
end

local function spellDisplayName(spellID)
    if not spellID then return "[Loading]" end
    local name = KCM and KCM.Compat and KCM.Compat.GetSpellName and KCM.Compat.GetSpellName(spellID)
    return name or "[Loading]"
end

local function itemDisplayName(itemID)
    if not itemID then return "[Loading]" end
    if C_Item and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(itemID)
        if n then return n end
    end
    if _G.GetItemInfo then
        local n = _G.GetItemInfo(itemID)
        if n then return n end
    end
    return "[Loading]"
end

local function isSpellEntry(id)
    return KCM and KCM.ID and KCM.ID.IsSpell(id)
end

local function spellIDFromEntry(id)
    return KCM and KCM.ID and KCM.ID.SpellID(id) or nil
end

-- Sets label width to the exact pixel gap between the left edge (item icon
-- or quality glyph, if shown) and the pick star. Without this, a long name
-- overflows its LEFT+RIGHT anchors and shoves the row's trailing widgets
-- (and the buttons on the next Flow-layout cell) to the next line.
local function applyLabelWidth(widget)
    local frame = widget.frame
    if not frame then return end
    local w = frame.width or frame:GetWidth() or 0
    if w <= 0 then return end
    local leftOffset = OWNED_ICON_SIZE + ICON_GAP + ICON_SIZE + ICON_GAP
    if widget.qualityTex and widget.qualityTex:IsShown() then
        leftOffset = leftOffset + QUALITY_SIZE + QUALITY_GAP
    end
    local rightOffset = PICK_SIZE + ICON_GAP
    if widget.handTag and widget.handTag:IsShown() then
        rightOffset = rightOffset + HAND_TAG_WIDTH + HAND_TAG_GAP
    end
    widget.label:SetWidth(math.max(20, w - leftOffset - rightOffset))
end

-- Returns the small-variant quality-glyph atlas name for itemID, or nil if
-- the item has no crafting quality. The atlas string is obtained directly
-- from C_TradeSkillUI.GetItem{Crafted,Reagent}QualityInfo — the same API
-- Blizzard uses to render the "Quality:" line in item tooltips — so we
-- don't have to guess atlas naming conventions (which differ across
-- DF/TWW/Midnight). Tries Crafted first (for crafted consumables) then
-- Reagent (for reagent-typed consumables).
local function craftingQualityAtlas(itemID)
    if not itemID or not _G.GetItemInfo then return nil end
    local _, link = _G.GetItemInfo(itemID)
    if not link then return nil end
    local tsi = C_TradeSkillUI
    if not tsi then return nil end
    local getters = { tsi.GetItemCraftedQualityInfo, tsi.GetItemReagentQualityInfo }
    for _, fn in ipairs(getters) do
        if fn then
            local info = fn(link)
            if info then
                local atlas = info.iconSmall or info.icon
                if atlas and atlas ~= "" then return atlas end
            end
        end
    end
    return nil
end

-- RefreshDisplay, split by concern. It was one 53-NLOC anonymous table value doing icon, glyph,
-- anchor, tag and text in a single body, which is the combination that makes a stack trace
-- useless: every frame error in a row pointed at "function <KCMItemRow.lua:193>". Each half is
-- now named, and the layout decisions (which texture, which anchor) are separable from the text
-- decisions.

-- Owned swatch plus the "picked in macro" star. The star shows for any pick flavor, so a
-- per-hand row that is picked for either hand still gets it.
local function refreshPickIndicators(self)
    self.ownedTex:SetTexture(self.owned and OWNED_TEX or NOT_OWNED_TEX)
    if self.isPick or self.pickMH or self.pickOH then
        self.pickTex:Show()
    else
        self.pickTex:Hide()
    end
end

-- The MH / OH / MH+OH tag. ASCII rather than a middle-dot glyph: WoW's default font (Friz
-- Quadrata TT) has narrow Unicode coverage and renders unsupported glyphs as tofu dots (see
-- feedback notes on WoW glyph rendering). ASCII is guaranteed to render.
local function refreshHandTag(self)
    if self.pickMH and self.pickOH then
        self.handTag:SetText("MH+OH")
    elseif self.pickMH then
        self.handTag:SetText("MH")
    elseif self.pickOH then
        self.handTag:SetText("OH")
    else
        self.handTag:Hide()
        return
    end
    self.handTag:Show()
end

local function refreshIcon(self, spellID)
    if spellID then
        self.itemTex:SetTexture(iconForSpell(spellID))
    else
        self.itemTex:SetTexture(iconForItem(self.itemID))
    end
end

-- Crafting-quality glyph, and the label anchor that depends on whether it is showing. Only
-- applies to items; spells never carry one.
local function refreshQualityGlyph(self, spellID)
    local qualityAtlas = (not spellID) and craftingQualityAtlas(self.itemID) or nil
    self.label:ClearAllPoints()
    -- LEFT anchor only — width is enforced by applyLabelWidth's SetWidth.
    -- Setting both LEFT and RIGHT alongside SetWidth made truncation
    -- unreliable on some layout passes.
    -- Pass useAtlasSize=false so SetAtlas respects our SetSize(14,14);
    -- without it the texture snaps to the atlas's native size.
    if qualityAtlas then
        self.qualityTex:SetAtlas(qualityAtlas, false)
        self.qualityTex:Show()
        self.label:SetPoint("LEFT", self.qualityTex, "RIGHT", QUALITY_GAP, 0)
    else
        self.qualityTex:Hide()
        self.label:SetPoint("LEFT", self.itemTex, "RIGHT", ICON_GAP, 0)
    end
end

local function refreshLabelText(self, spellID)
    if spellID then
        self.label:SetText(spellDisplayName(spellID))
    elseif self.itemID then
        local name = itemDisplayName(self.itemID)
        local count = (self.itemID and _G.GetItemCount) and _G.GetItemCount(self.itemID) or 0
        if count and count > 0 then
            self.label:SetText(("[%d] %s"):format(count, name))
        else
            self.label:SetText(name)
        end
    elseif self.fallbackName then
        -- AIO panel rows pass their sub-category displayName here so a
        -- row with no current pick still reads as "Healthstone" rather
        -- than the generic "[Loading]" placeholder.
        self.label:SetText(self.fallbackName)
    else
        self.label:SetText("[Loading]")
    end
end

local function refreshDisplay(self)
    refreshPickIndicators(self)
    refreshHandTag(self)
    self.frame:SetAlpha(self.applicable and 1.0 or NOT_APPLICABLE_ALPHA)

    local spellID = isSpellEntry(self.itemID) and spellIDFromEntry(self.itemID) or nil
    refreshIcon(self, spellID)
    refreshQualityGlyph(self, spellID)
    refreshLabelText(self, spellID)
    applyLabelWidth(self)
end

local methods = {
    ["OnAcquire"] = function(self)
        self.itemID = nil
        self.owned  = false
        self.isPick = false
        self.pickMH = false
        self.pickOH = false
        self.applicable = true
        self.fallbackName = nil
        self.frame.height = ROW_HEIGHT
        self:SetHeight(ROW_HEIGHT)
        self:SetWidth(300)
        self:RefreshDisplay()
    end,

    -- No-op stubs so the widget tolerates any AceGUI consumer that
    -- pre-emptively calls SetText / SetFontObject on every child. The widget
    -- builds its own label from itemID and uses a fixed font.
    ["SetText"]       = function(self, _) end,
    ["SetFontObject"] = function(self, _) end,

    -- Receives the option table's `arg` field. Expected shape:
    --   { itemID = <number>, owned = <bool>, isPick = <bool>,
    --     pickMH = <bool?>, pickOH = <bool?>, applicable = <bool?>,
    --     fallbackName = <string?> }
    -- fallbackName is rendered when itemID is nil, so a row that's logically
    -- "for the Healthstone sub-category but currently has no pick" still
    -- identifies itself instead of showing "[Loading]".
    -- pickMH/pickOH are the per-hand pick flags used by perHand categories
    -- (Weapon Enchant); non-perHand pages leave them nil and rely solely on
    -- isPick, preserving the original single-star behavior. applicable
    -- defaults to true so non-perHand rows never dim.
    ["SetCustomData"] = function(self, data)
        if type(data) ~= "table" then return end
        self.itemID = data.itemID
        self.owned  = data.owned  and true or false
        self.isPick = data.isPick and true or false
        self.pickMH = data.pickMH and true or false
        self.pickOH = data.pickOH and true or false
        self.applicable = (data.applicable == nil) and true or (data.applicable and true or false)
        self.fallbackName = data.fallbackName
        self:RefreshDisplay()
    end,

    ["RefreshDisplay"] = refreshDisplay,

    ["OnWidthSet"] = function(self, width)
        self.frame.width = width
        applyLabelWidth(self)
    end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:EnableMouse(true)
    frame:SetHeight(ROW_HEIGHT)

    local ownedTex = frame:CreateTexture(nil, "ARTWORK")
    ownedTex:SetSize(OWNED_ICON_SIZE, OWNED_ICON_SIZE)
    ownedTex:SetPoint("LEFT", 0, 0)

    local itemTex = frame:CreateTexture(nil, "ARTWORK")
    itemTex:SetSize(ICON_SIZE, ICON_SIZE)
    itemTex:SetPoint("LEFT", ownedTex, "RIGHT", ICON_GAP, 0)

    -- Crafting-quality tier glyph. Pinned to the item icon; the label anchors
    -- past this texture only when it's visible (see RefreshDisplay).
    local qualityTex = frame:CreateTexture(nil, "ARTWORK")
    qualityTex:SetSize(QUALITY_SIZE, QUALITY_SIZE)
    qualityTex:SetPoint("LEFT", itemTex, "RIGHT", ICON_GAP, 0)
    qualityTex:Hide()

    local pickTex = frame:CreateTexture(nil, "ARTWORK")
    pickTex:SetTexture(PICK_TEX)
    pickTex:SetSize(PICK_SIZE, PICK_SIZE)
    pickTex:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    pickTex:Hide()

    -- Per-hand marker ("MH" / "OH" / "MH+OH") for perHand categories (Weapon
    -- Enchant). Sits just left of pickTex; hidden for every non-perHand page
    -- since RefreshDisplay only shows it when pickMH/pickOH is set.
    local handTag = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    handTag:SetPoint("RIGHT", pickTex, "LEFT", -HAND_TAG_GAP, 0)
    handTag:Hide()

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetHeight(ROW_HEIGHT)
    -- Truncate long names instead of wrapping — a wrapped row would blow out
    -- the row height and break Flow layout alignment with the buttons.
    -- LEFT+RIGHT SetPoints alone weren't reliably bounding the label's
    -- natural width, so we ALSO set an explicit SetWidth in applyLabelWidth
    -- and use SetMaxLines(1) as a hard cap.
    label:SetWordWrap(false)
    label:SetNonSpaceWrap(false)
    if label.SetMaxLines then label:SetMaxLines(1) end
    -- Anchors are set each RefreshDisplay based on qualityTex visibility.

    local widget = {
        frame      = frame,
        ownedTex   = ownedTex,
        itemTex    = itemTex,
        qualityTex = qualityTex,
        pickTex    = pickTex,
        handTag    = handTag,
        label      = label,
        type       = Type,
    }

    -- Direct frame script — bypasses the AceGUI "OnEnter" callback chain
    -- so we can drive the real in-game item / spell tooltip ourselves
    -- instead of whatever generic tooltip a callback consumer might
    -- attach.
    frame:SetScript("OnEnter", function(self)
        if not widget.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local spellID = isSpellEntry(widget.itemID) and spellIDFromEntry(widget.itemID) or nil
        if spellID then
            GameTooltip:SetSpellByID(spellID)
        else
            GameTooltip:SetItemByID(widget.itemID)
        end
        GameTooltip:Show()
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
