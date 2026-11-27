-- settings/CategoryPoison.lua — the Macros page's Poison tab, per client (issue #47).
--
-- What this file owns: the Poison category's schema rows and the part of its tab
-- that differs by model (KCM.POISON_MODEL, defaults/Defaults_Poison.lua):
--
--   hands   (WoW Forever) the two family dropdowns, Main hand and Off hand, drawn
--           ABOVE the usual single-category tab (settings/Category.lua's
--           renderSingle calls RenderHands): the Add-by-ID line and the priority
--           list are the ranks the hands pick from.
--   spells  (Retail) the whole tab: the Macro section, then a Lethal and a
--           Non-lethal section, each a draggable list of the poison spells with an
--           In macro check box, the composite tabs' shape (settings/CategoryComposite.lua).
--
-- The rows are DECLARED FOR THE RUNNING MODEL ONLY, at load: a Forever profile has
-- no lethal order and a Retail one no hand family, so neither client registers a
-- row it cannot use (clients-§4). Every control writes through the row
-- (KCM.Schema:Set), so `/cm get|set|reset categories.POISON.<field>` is the same
-- write as the widget.
--
-- THE SEAM. Inward it takes the page's helpers off KCM.Settings.MacrosPage, which
-- settings/Category.lua publishes at load (the TOC loads this file after it).
-- Outward it publishes KCM.Settings.CategoryPoison: RenderHands, OwnsTab, Render
-- and Reset, which Category.lua reaches at render time.

local addonName, NS = ...
local KCM = NS
local L = KCM.L
local H = KCM.Settings.Helpers
local AceGUI = LibStub("AceGUI-3.0", true)

local Page = KCM.Settings.MacrosPage
local ROW_H, ROW_GAP, ROW_STRIDE = Page.ROW_H, Page.ROW_GAP, Page.ROW_STRIDE
local OWNED_ICON          = Page.OWNED_ICON
local NOT_OWNED_ICON      = Page.NOT_OWNED_ICON
local newRow              = Page.NewRow
local afterMutation       = Page.AfterMutation
local isOwned             = Page.IsOwned
local makeItemRow         = Page.MakeItemRow
local makeCheckbox        = Page.MakeCheckbox
local makeMacroDragIcon   = Page.MakeMacroDragIcon
local reorderWidgets      = Page.ReorderWidgets
local cancelReorder       = Page.CancelReorder
local trackReorder        = Page.TrackReorder
local renderRowHandle     = Page.RenderRowHandle
local scrollOffset        = Page.ScrollOffset
local restoreScroll       = Page.RestoreScroll
local promptResetCategory = Page.PromptResetCategory

local CAT_KEY               = "POISON"
local HANDLE_ICON           = "segment"
local ITEM_ROW_RW_POISON    = 0.72
local CHECK_W               = 78

local MODEL = KCM.POISON_MODEL or {}
local DEFAULTS = (KCM.dbDefaults and KCM.dbDefaults.profile and KCM.dbDefaults.profile.categories
    and KCM.dbDefaults.profile.categories[CAT_KEY]) or {}

-- What a family token reads as, in the dropdowns and on the lists.
local FAMILY_LABELS = {
    INSTANT     = L["Instant"],
    DEADLY      = L["Deadly"],
    CRIPPLING   = L["Crippling"],
    MINDNUMBING = L["Mind-numbing"],
    WOUND       = L["Wound"],
    AMPLIFYING  = L["Amplifying"],
    NUMBING     = L["Numbing"],
    ATROPHIC    = L["Atrophic"],
}

local function familyValues()
    local out = {}
    for i, token in ipairs(MODEL.families or {}) do
        out[i] = { value = token, text = FAMILY_LABELS[token] or token }
    end
    return out
end

local function bucket()
    local cats = KCM.db and KCM.db.profile and KCM.db.profile.categories
    return cats and cats[CAT_KEY] or nil
end

-- ---------------------------------------------------------------------
-- The schema rows (architecture-§5), this model's only
-- ---------------------------------------------------------------------

local function recomputeAfterRow()
    if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute("options_poison_setting")
    end
end

local function poisonRow(field, spec)
    spec.path    = ("categories.%s.%s"):format(CAT_KEY, field)
    spec.panel   = "macros"
    spec.section = "macros"
    spec.group   = CAT_KEY
    spec.default = DEFAULTS[field]
    spec.apply   = recomputeAfterRow
    H.AddRow(spec)
end

local function allSpellTokens()
    local out = {}
    for _, list in ipairs({ MODEL.lethal or {}, MODEL.nonLethal or {} }) do
        for _, token in ipairs(list) do out[#out + 1] = token end
    end
    return out
end

local HAND_TOOLTIP = L["The poison family this hand takes. The best rank of it you carry is used; with none, the best poison you carry of any family."]

if KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(CAT_KEY) then
    if MODEL.kind == "hands" then
        poisonRow("mainHand", { type = "string", values = familyValues(),
            label = L["Main hand poison"], tooltip = HAND_TOOLTIP })
        poisonRow("offHand", { type = "string", values = familyValues(),
            label = L["Off hand poison"], tooltip = HAND_TOOLTIP })
    elseif MODEL.kind == "spells" then
        poisonRow("lethal", { type = "order", members = MODEL.lethal or {},
            label   = L["Poison: Lethal order"],
            tooltip = L["The order the macro tries the lethal poisons in. The first one you know is kept up (two with Dragon-Tempered Blades)."] })
        poisonRow("nonLethal", { type = "order", members = MODEL.nonLethal or {},
            label   = L["Poison: Non-lethal order"],
            tooltip = L["The order the macro tries the non-lethal poisons in. The first one you know is kept up (two with Dragon-Tempered Blades)."] })
        poisonRow("enabled", { type = "map", valueType = "bool", members = allSpellTokens(),
            label   = L["Poison: poisons in the macro"],
            tooltip = L["Which poisons the macro may cast. One this does not name may be cast."] })
    end
end

local function setRow(field, value, reason)
    if KCM.Schema and KCM.Schema:Set(("categories.%s.%s"):format(CAT_KEY, field), value) then
        afterMutation(reason)
    end
end

-- ---------------------------------------------------------------------
-- hands (WoW Forever): the two dropdowns above the list
-- ---------------------------------------------------------------------

local function makeDropdown(parent, opts)
    local dd = KCM.SkinAcquire(AceGUI, "Dropdown")
    dd:SetLabel(opts.label)
    local list, order = {}, {}
    for i, v in ipairs(familyValues()) do list[v.value] = v.text; order[i] = v.value end
    dd:SetList(list, order)
    dd:SetRelativeWidth(0.45)
    dd:SetValue(opts.value)
    dd:SetCallback("OnValueChanged", function(_, _, v) opts.onChange(v) end)
    H.AttachTooltip(dd, opts.label, HAND_TOOLTIP)
    parent:AddChild(dd)
    return dd
end

--- The Forever header: a Main hand and an Off hand family dropdown, on one row.
local function renderHands(ctx, scroll)
    local P = KCM.Poison
    local row = newRow(scroll)
    for _, hand in ipairs({ { 16, "mainHand", L["Main hand poison"] }, { 17, "offHand", L["Off hand poison"] } }) do
        makeDropdown(row, {
            label    = hand[3],
            value    = P and P.HandFamily and P.HandFamily(hand[1]) or DEFAULTS[hand[2]],
            onChange = function(v) setRow(hand[2], v, "options_poison_hand") end,
        })
    end
    H.AddSpacer(scroll, 6)
    H.Label(ctx, L["Each hand takes the best rank of its family you carry, and the best poison you carry of any family when you have none of it."], "medium")
    H.AddSpacer(scroll, 4)
end

-- ---------------------------------------------------------------------
-- spells (Retail): the whole tab
-- ---------------------------------------------------------------------

local SPELL_SECTIONS = {
    { orderField = "lethal",    label = L["Lethal"],     members = MODEL.lethal or {} },
    { orderField = "nonLethal", label = L["Non-lethal"], members = MODEL.nonLethal or {} },
}

local function renderSpellRow(scroll, cfg, token, list)
    local P = KCM.Poison
    local id = P and P.SpellOf and P.SpellOf(token) or nil
    local label = FAMILY_LABELS[token] or token

    local row = newRow(scroll, ROW_H)
    local slot = list and renderRowHandle(row) or nil
    makeItemRow(row, {
        itemID       = id,
        owned        = isOwned(id),
        isPick       = false,
        fallbackName = label,
    }, ITEM_ROW_RW_POISON)
    makeCheckbox(row, {
        label    = L["In macro"],
        tooltip  = (L["Let the macro cast %s."]):format(label),
        value    = (cfg.enabled == nil) or (cfg.enabled[token] ~= false),
        width    = CHECK_W,
        onChange = function(v)
            local flags = {}
            for k, flag in pairs(cfg.enabled or {}) do flags[k] = flag end
            flags[token] = v and true or false
            setRow("enabled", flags, "options_poison_toggle")
        end,
    })
    if slot then list:AddRow(row.frame, { ghostText = label, height = ROW_H }) end
    H.AddSpacer(scroll, ROW_GAP)
end

local function renderSpellSection(ctx, scroll, cfg, section)
    H.Section(ctx, section.label)
    local orderArr = cfg[section.orderField] or section.members
    local W = reorderWidgets()
    local list = trackReorder(ctx, W and W.ReorderList({
        stride        = ROW_STRIDE,
        owner         = addonName,
        handleIcon    = KCM.Icon and KCM.Icon(HANDLE_ICON) or nil,
        handleTooltip = L["Drag to reorder"],
        onMove        = function(from, to)
            -- The composite sections' splice, on this category's order row.
            if KCM.Selector and KCM.Selector.MoveCompositeRef
                and KCM.Selector.MoveCompositeRef(CAT_KEY, section.orderField, from, to) then
                afterMutation("options_poison_move_drag")
            end
        end,
    }) or nil)
    for _, token in ipairs(orderArr) do renderSpellRow(scroll, cfg, token, list) end
    if list then list:Finish(scroll.content or scroll.frame) end
end

local function renderSpells(ctx, cat)
    local keepScroll = scrollOffset(ctx)
    cancelReorder(ctx)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)
    local cfg = bucket()
    if not cfg then return end

    H.Section(ctx, L["Macro"])
    makeMacroDragIcon(scroll, cat.macroName)
    H.AddSpacer(scroll, 6)
    H.Label(ctx, L["Out of combat, the macro casts the first poison below that you know and that is not on your weapons: lethal first, then non-lethal. One of each is kept up, two with Dragon-Tempered Blades. With all of them up it does nothing."], "medium")
    H.AddSpacer(scroll, 6)
    H.Label(ctx, (L["%s known    %s not known"]):format(OWNED_ICON, NOT_OWNED_ICON), "medium")
    H.AddSpacer(scroll, 4)

    for _, section in ipairs(SPELL_SECTIONS) do renderSpellSection(ctx, scroll, cfg, section) end

    H.AddSpacer(scroll, 12)
    H.Button(ctx, {
        text    = L["Reset category…"],
        tooltip = L["Put back the shipped order of both lists and let the macro cast every poison."],
        onClick = function() promptResetCategory(cat) end,
    })
    if scroll.DoLayout then scroll:DoLayout() end
    restoreScroll(ctx, keepScroll)
end

-- ---------------------------------------------------------------------
-- Reset
-- ---------------------------------------------------------------------

local RESET_FIELDS = {
    hands  = { "mainHand", "offHand" },
    spells = { "lethal", "nonLethal", "enabled" },
}

--- The tab's reset: the model's rows back to the shipped values as ONE batch, and on Forever the
--- item list's own edits too (Selector.ResetBucket, which keeps what the bags discovered).
local function resetPoison()
    local entries = {}
    for i, field in ipairs(RESET_FIELDS[MODEL.kind] or {}) do
        entries[i] = { path = ("categories.%s.%s"):format(CAT_KEY, field), value = DEFAULTS[field] }
    end
    if MODEL.kind == "hands" and KCM.Selector and KCM.Selector.ResetBucket then
        KCM.Selector.ResetBucket(CAT_KEY)
    end
    H.SetManyAndRefresh(entries, {
        onChange   = recomputeAfterRow,
        structural = true,
        bulk       = { act = "reset", scope = "category " .. CAT_KEY },
    })
end

KCM.Settings.CategoryPoison = {
    RenderHands = function(ctx, scroll) if MODEL.kind == "hands" then renderHands(ctx, scroll) end end,
    --- Retail's tab is this file's whole; Forever's is the single-category tab plus RenderHands.
    OwnsTab     = function() return MODEL.kind == "spells" end,
    Render      = renderSpells,
    Reset       = resetPoison,
}
