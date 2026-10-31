-- settings/CategoryComposite.lua — the Macros page's composite tabs (HP_AIO / MP_AIO).
--
-- What this file owns: a composite category's whole tab. The "Macro" section,
-- the legend, the two combat-state sections with their sub-category rows and
-- drag lists, and the inline reset.
--
-- WHY IT IS ITS OWN FILE. It was a block inside settings/Category.lua until
-- 2026-10-31 (issue #43), the seam that file has after the Add-by-ID line:
-- Category.lua stood at 1186 lines in layout-§1's on-notice band, and this is
-- the one layout it draws that shares nothing with a single category's list.
-- Every line moved WHOLE -- no comparison, constant or comment changed in the cut.
--
-- THE SEAM, both ways:
--   * Inward, this file takes the page's own helpers and row measurements off
--     KCM.Settings.MacrosPage, published by settings/Category.lua, which the TOC
--     loads immediately before settings/CategoryAddByID.lua and this file.
--   * Outward, it publishes ONE entry point, KCM.Settings.CategoryComposite.Render,
--     which settings/Category.lua's renderMacros calls at RENDER time.
--
-- ITEM_ROW_RW_COMPOSITE and CHECK_W came across with the block because it is
-- their only reader. HANDLE_ICON is restated, as on every page with a drag list,
-- because tests/test_mediasetup.lua resolves a KCM.Icon constant per file.

local addonName, NS = ...
local KCM = NS
local L = KCM.L
local H = KCM.Settings.Helpers

local Page = KCM.Settings.MacrosPage
local ROW_H, ROW_GAP, ROW_STRIDE = Page.ROW_H, Page.ROW_GAP, Page.ROW_STRIDE
local OWNED_ICON          = Page.OWNED_ICON
local NOT_OWNED_ICON      = Page.NOT_OWNED_ICON
local newRow              = Page.NewRow
local afterMutation       = Page.AfterMutation
local isOwned             = Page.IsOwned
local warnText            = Page.WarnText
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

local HANDLE_ICON           = "segment"
local ITEM_ROW_RW_COMPOSITE = 0.72
local CHECK_W               = 78

-- The glyph legend, in the flavor a COMPOSITE page needs: the owned swatch and
-- nothing else. A composite row draws no pick star -- makeItemRow is passed
-- `isPick = false` and neither hand flag, because every row on the tab is a
-- category whose pick goes into the macro, so a star on all of them would say
-- nothing -- and a key naming a glyph that cannot appear on the page it heads is
-- a key that teaches the wrong thing.
--
-- IT IS HERE AT ALL because the swatches are the same two the single-category
-- tabs explain and the composite tabs explained neither: a player who had not
-- opened Food first met a red cross beside Healthstone with nothing on the page
-- saying what it meant.
local function renderCompositeLegend(ctx)
    H.Label(ctx,
        (L["%s in bags    %s not in bags"]):format(OWNED_ICON, NOT_OWNED_ICON),
        "medium")
end

-- One sub-category row of a composite section: the drag handle's slot, the pick,
-- and the Enabled checkbox.
--
-- THE UP AND DOWN ARROWS ARE GONE, for the same reason they went from the
-- priority rows: two buttons that each moved a row one place could not express
-- "put this one third" without being clicked until it was, and every click was a
-- macro rebuild. `Selector.MoveCompositeRef` says it in one call and the drag is
-- how a player says it (options-ui-§18, anti-patterns #75).
--
-- Extracted out of renderComposite rather than left inlined: the loop body was
-- four widget declarations with closures over the same locals, and the whole
-- function sat at CCN 18 with it.
local function renderCompositeRow(scroll, catKey, cfg, ref, list)
    local refCat   = KCM.Categories.Get(ref)
    local refLabel = refCat and refCat.displayName or ref
    local pick     = (KCM.Selector and KCM.Selector.PickBestForCategory)
        and KCM.Selector.PickBestForCategory(ref) or nil

    local row = newRow(scroll, ROW_H)
    -- HANDLE FIRST, at the left edge, then the item, then the checkbox. Flow places its children in
    -- the order they are added, so this order IS the layout.
    local slot = list and renderRowHandle(row) or nil
    makeItemRow(row, {
        itemID       = pick,
        owned        = isOwned(pick),
        isPick       = false,
        fallbackName = refLabel,
    }, ITEM_ROW_RW_COMPOSITE)
    makeCheckbox(row, {
        label    = L["In macro"],
        tooltip  = (L["Include %s in the macro body."]):format(refLabel),
        value    = (cfg.enabled == nil) or (cfg.enabled[ref] ~= false),
        width    = CHECK_W,
        -- The whole flag map with this sub-category's flag replaced, through the
        -- `categories.<KEY>.enabled` row.
        onChange = function(v)
            local flags = {}
            for k, flag in pairs(cfg.enabled or {}) do flags[k] = flag end
            flags[ref] = v and true or false
            if KCM.Schema and KCM.Schema:Set(("categories.%s.enabled"):format(catKey), flags) then
                afterMutation("options_aio_toggle")
            end
        end,
    })

    -- Registered LAST, once the item cell has resolved the name the carried copy reads. The slot it
    -- goes into was claimed before any of this, so the layout is unaffected by the order these two
    -- things happen in.
    if slot then
        -- NO `parent`, for the reason renderPriorityRow gives: the box belongs behind the whole
        -- row, and naming the handle's slot boxed the gutter alone.
        list:AddRow(row.frame, {
            ghostText = refLabel,
            height    = ROW_H,
        })
    end

    -- The gap, for the reason renderPriorityRow's states: a taller row is a taller box, not a
    -- space between two boxes.
    H.AddSpacer(scroll, ROW_GAP)
end

-- The two combat-state sections a composite is made of. Sub-categories are
-- LOCKED to their section, so this is a fixed pair, not user data.
local AIO_SECTIONS = {
    { orderField = "orderInCombat",    label = L["In combat"]     },
    { orderField = "orderOutOfCombat", label = L["Out of combat"] },
}

-- ONE CONTROLLER PER SECTION, and that is the shape the DATA has: the two sections are two
-- SEPARATE stored arrays, so they are two flat lists rather than one list with a boundary. A drag
-- therefore cannot cross between In Combat and Out of Combat, which is exactly right -- a
-- sub-category is locked to its section and a gesture that appeared to move one across would be a
-- gesture with nothing to save.
local function renderCompositeSection(ctx, catKey, scroll, cfg, section)
    H.Section(ctx, section.label)
    local orderArr = cfg[section.orderField] or {}
    if #orderArr == 0 then
        H.Label(ctx, warnText(L["(no sub-categories)"]), "medium")
        return
    end

    local W = reorderWidgets()
    local list = trackReorder(ctx, W and W.ReorderList({
        stride        = ROW_STRIDE,
        -- The skin owner (skinning-§1): this addon's folder, so the list's boxes, drop line, ghost
        -- and handle tints come from the skin it wears (WidgetsReorder minor 2), and its
        -- minor-1 colors while the Scope ignores the settings panel (panel-scoped by default, minor 3).
        owner         = addonName,

        handleIcon    = KCM.Icon and KCM.Icon(HANDLE_ICON) or nil,
        handleTooltip = L["Drag to reorder"],
        onMove        = function(from, to)
            -- A splice to index, one write and one re-render -- never a run of adjacent swaps.
            if KCM.Selector and KCM.Selector.MoveCompositeRef
                and KCM.Selector.MoveCompositeRef(catKey, section.orderField, from, to) then
                afterMutation("options_aio_move_drag")
            end
        end,
        debug         = (KCM.State and KCM.State.debug and KCM.Debug)
            and function(fmt, ...) KCM.Debug("Prio", fmt, ...) end or nil,
    }) or nil)

    for _, ref in ipairs(orderArr) do
        renderCompositeRow(scroll, catKey, cfg, ref, list)
    end

    -- The insertion line lives on what every row in THIS section shares as an ancestor. Each
    -- controller gets its own call, so neither section inherits the other's.
    if list then list:Finish(scroll.content or scroll.frame) end
end

local function renderComposite(ctx, cat)
    local keepScroll = scrollOffset(ctx)
    cancelReorder(ctx)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    local cfg = KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[cat.key]
    if not cfg then return end

    -- The "Macro" section (item 020, CON-L18): drag icon, description and legend,
    -- the same heading a single tab opens on.
    H.Section(ctx, L["Macro"])
    makeMacroDragIcon(scroll, cat.macroName)
    H.AddSpacer(scroll, 6)

    H.Label(ctx,
        L["Composite macro. Toggle and order the contributing categories below — each category's own ranking and pick logic is edited on its own tab."],
        "medium")
    -- Above the first section, not inside one: it keys the glyphs on BOTH of them. Spaced off the
    -- sentence above it as well as off the section below -- a key butted straight against the
    -- paragraph reads as a fourth line of it.
    H.AddSpacer(scroll, 6)
    renderCompositeLegend(ctx)
    H.AddSpacer(scroll, 4)

    for _, section in ipairs(AIO_SECTIONS) do
        renderCompositeSection(ctx, cat.key, scroll, cfg, section)
    end

    -- Inline reset
    H.AddSpacer(scroll, 12)
    H.Button(ctx, {
        text    = L["Reset category…"],
        tooltip = L["Put back the shipped In macro ticks and the order of both sections."],
        onClick = function() promptResetCategory(cat) end,
    })

    if scroll.DoLayout then scroll:DoLayout() end
    -- AFTER the layout, or it is restored onto content that is not there yet and clamped back to
    -- zero for its trouble.
    restoreScroll(ctx, keepScroll)
end

-- The one entry point. settings/Category.lua's renderMacros calls it for a
-- category with `composite` set.
KCM.Settings.CategoryComposite = KCM.Settings.CategoryComposite or {}
KCM.Settings.CategoryComposite.Render = renderComposite
