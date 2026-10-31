-- settings/MacroBarSlots.lua — the Macro Bar page's Buttons tab list.
--
-- What this file owns: the one draggable list the Buttons tab draws over the
-- `macroBar.order` and `macroBar.shown` rows, its two moves and their one write,
-- the pooled slot rows and the reorder controllers' lifetime.
--
-- WHY IT IS ITS OWN FILE. It was a block inside settings/MacroBar.lua until
-- 2026-10-31. That file stood at 1231 lines with its Accepted shelf life nearly
-- spent (automated-tests-§4), and this is the one thing it drew by hand: the rest
-- of the page is schema rows. Every line moved WHOLE -- no comparison, constant
-- or comment changed in the cut.
--
-- THE SEAM. The rows themselves stay in settings/MacroBar.lua, so nothing here
-- has to exist for the schema to be whole. This file publishes
-- KCM.Settings.MacroBarSlots, and the page calls its Render and Cancel at RENDER
-- time, so the page has no load-order dependency on this file.

local addonName, NS = ...
local KCM = NS
local L = KCM.L
local H = KCM.Settings.Helpers
-- Silent-mode (library-stack-§4). Only the Buttons tab's row slots reach it, and a
-- load without AceGUI registers no page to draw them on.
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

-- ---------------------------------------------------------------------------
-- The Buttons tab: one draggable list (MultiMeters' Columns shape)
-- ---------------------------------------------------------------------------
--
-- Shown slots first, in the bar's order, each with the library's drag handle;
-- then a rule; then the hidden slots, dimmed and not draggable. The list is the
-- stored `macroBar.order` PARTITIONED -- shown, then hidden, each keeping its
-- stored order -- so neither row changes shape: the list is a view over the two
-- rows, not a third store.
--
-- TWO ACTS, AND BOTH ARE MOVES.
--   * A drag within the shown group is a SPLICE -- remove, then insert -- and
--     writes `macroBar.order` once: the new shown order, then the hidden slots in
--     the order they already had. NOT MacroBarModel.Swap, which is the BAR's own
--     gesture: dropping one button onto another swaps the two, where dragging a
--     row past three others shifts all three.
--   * The tick. Unticking sends a slot to the TOP of the hidden group, the
--     shortest travel there is; ticking a hidden one sends it to the END of the
--     shown group, which is where a button you just put back belongs. It writes
--     `macroBar.shown` and then `macroBar.order` as ONE batch: two `[Set]` lines,
--     because a toggle is not a bulk copy or reset (debug-logging-§10), one bar
--     re-apply (the two rows share their apply) and one page rebuild.
--
-- `boundary` is the shown count, so a drag cannot cross the rule: crossing it
-- would be a visibility change made by a gesture that means "move".
--
-- EVERY SLOT MAY BE HIDDEN. The checkboxes this list replaced allowed it, and the
-- bar collapses to its backdrop rather than erroring (docs/smoke-tests.md BAR-18).
-- MultiMeters refuses to hide a window's last column, because a meter window with
-- no columns shows nothing it can be told apart by; a bar with no buttons is an
-- odd choice but a legible one, and turning the bar off is one tab away.
--
-- REFUSED IN COMBAT, like MacroBar.SwapSlots: both writes re-apply the bar, which
-- anchors protected frames. A refused act writes nothing and repaints nothing, so
-- the page is never redrawn from a state that was not stored.
--
-- THE ROWS ARE POOLED RAW FRAMES, for the reason settings/StatPriority.lua gives
-- (and MultiMeters paid for first): H.ResetScroll hands every AceGUI container on
-- the page back to AceGUI's process-wide pool, and a raw frame parented to one
-- rides it into whatever asks for a SimpleGroup next. Every script reads its slot
-- off the row at fire time (`row.kcmSlot`), never off an upvalue.

-- ROW_H is the box, ROW_STRIDE top-of-row to top-of-row: the library's drop is
-- arithmetic on the stride, so the two are declared together (options-ui-§18).
-- The same numbers and the same two glyphs as the Stat Priority list.
local SLOT_ROW_H        = 28
local SLOT_ROW_STRIDE   = SLOT_ROW_H + 4
local SLOT_HANDLE_ICON  = "segment"
local SLOT_GLYPH_GAP    = 12
local SLOT_GLYPH_SIZE   = 18
local SLOT_LABEL_INSET  = 12
local SHOWN_TEX         = "Interface\\RaidFrame\\ReadyCheck-Ready"
local HIDDEN_TEX        = "Interface\\RaidFrame\\ReadyCheck-NotReady"
-- The handle's gutter is the LIBRARY'S (lib.ROW_BOX.HANDLE_W), read and never
-- restated, and `handleSize` is not passed; this is only the rung for a library
-- too old to publish it.
local HANDLE_W_FALLBACK = 30

local function reorderWidgets()
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    return (W and W.ReorderList) and W or nil
end

local function handleGutter()
    local W = reorderWidgets()
    local box = W and W.ROW_BOX
    return (box and box.HANDLE_W) or HANDLE_W_FALLBACK
end

local function indexOf(list, key)
    for i, k in ipairs(list) do
        if k == key then return i end
    end
    return nil
end

--- The stored order, split into the slots the bar shows and the ones it hides,
--- each in stored order. Pure. An unset flag means shown.
local function partitionSlots(order, shown)
    local on, off = {}, {}
    for _, key in ipairs(order or {}) do
        if shown and shown[key] == false then off[#off + 1] = key else on[#on + 1] = key end
    end
    return on, off
end

local function joinSlots(on, off)
    local out = {}
    for _, key in ipairs(on) do out[#out + 1] = key end
    for _, key in ipairs(off) do out[#out + 1] = key end
    return out
end

--- The order after dragging shown row `from` to `to`, or nil when that is no move.
--- Pure, and a splice.
local function movedOrder(order, shown, from, to)
    local on, off = partitionSlots(order, shown)
    if from == to or not (on[from] and on[to]) then return nil end
    table.insert(on, to, table.remove(on, from))
    return joinSlots(on, off)
end

--- The shown map and the order after ticking or unticking `key`, or nil for a slot
--- the order does not hold. Pure; both answers are fresh tables.
local function toggledSlot(order, shown, key)
    local on, off = partitionSlots(order, shown)
    local nextShown = {}
    for k, flag in pairs(shown or {}) do nextShown[k] = flag end
    local i = indexOf(on, key)
    if i then
        table.remove(on, i)
        table.insert(off, 1, key)
        nextShown[key] = false
    else
        local j = indexOf(off, key)
        if not j then return nil end
        table.remove(off, j)
        on[#on + 1] = key
        nextShown[key] = true
    end
    return nextShown, joinSlots(on, off)
end

-- Published for the suite, which pins the two moves' arithmetic on its own.
KCM.Settings.MacroBarSlots = {
    Partition = partitionSlots, Moved = movedOrder, Toggled = toggledSlot,
}

--- The order the bar is drawn in (repaired on read) and its shown map, read NOW --
--- never captured by a render, since a profile switch swaps the table out.
local function slotState()
    local model = KCM.MacroBarModel
    local cfg = model and model.Config()
    if not cfg then return nil end
    return model.Order(), cfg.shown
end

--- THE one write for both acts: refused in combat, otherwise one batch through
--- the schema helper, rebuilt structurally because rows moved. Answers the
--- helper's verdict, and a refusal repaints nothing.
local function commitSlots(entries)
    if InCombatLockdown and InCombatLockdown() then
        H.TraceCombatRefused("macroBar.order/shown")
        KCM.Say(L["in combat — macro bar buttons cannot be moved or hidden until combat ends."])
        return false
    end
    if not (KCM.Schema and KCM.Schema.SetMany) then return false end
    return KCM.Schema:SetMany(entries, { structural = true }) and true or false
end

--- The list's onMove: one splice, one write.
local function moveSlot(from, to)
    local order, shown = slotState()
    if not order then return false end
    local nextOrder = movedOrder(order, shown, from, to)
    if not nextOrder then return false end
    return commitSlots({ { path = "macroBar.order", value = nextOrder } })
end

--- A tick: the visibility first, then the place the slot moved to.
local function toggleSlot(key)
    local order, shown = slotState()
    if not order then return false end
    local nextShown, nextOrder = toggledSlot(order, shown, key)
    if not nextShown then return false end
    return commitSlots({
        { path = "macroBar.shown", value = nextShown },
        { path = "macroBar.order", value = nextOrder },
    })
end

local function slotLabel(key)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(key)
    return cat and cat.displayName or key
end

-- ---------------------------------------------------------------------------
-- The row frames, and their pool
-- ---------------------------------------------------------------------------

local slotPool, slotAttic = {}, nil

local function attic()
    if not slotAttic then
        slotAttic = CreateFrame("Frame", nil, UIParent)
        slotAttic:Hide()
    end
    return slotAttic
end

--- Give every row from the previous render back to the free list.
local function releaseSlotRows(ctx)
    local live = ctx and ctx.kcmSlotRows
    if not live then return end
    for i = #live, 1, -1 do
        local slotRow = live[i]
        live[i] = nil
        slotRow.kcmSlot = nil
        slotRow:Hide()
        slotRow:ClearAllPoints()
        slotRow:SetParent(attic())
        slotPool[#slotPool + 1] = slotRow
    end
end

--- WHAT THE CLICK WILL DO, read off the row at hover time so a recycled row never
--- offers the last render's promise.
local function showGlyphTip(glyph, slotRow)
    if not GameTooltip then return end
    GameTooltip:SetOwner(glyph, "ANCHOR_RIGHT")
    local r, g, b = KCM.SkinPanelColor("gtip.value")
    GameTooltip:AddLine(slotRow.kcmShown and L["Click to take this button off the bar"]
        or L["Click to put this button back on the bar"], r, g, b)
    GameTooltip:AddLine(L["A hidden button waits below the line, and one you put back joins the end of the bar."],
        r, g, b, true)
    GameTooltip:Show()
end

-- The row frames are named `slotRow` throughout, never `row`, because `row` is this
-- file's schema-row declarer above and a local of that name would shadow it.
local function buildSlotRow(parent)
    local slotRow = CreateFrame("Frame", nil, parent)
    slotRow:SetHeight(SLOT_ROW_H)

    -- The tick. A BUTTON with two textures, the glyph MultiMeters' columns and this
    -- addon's Stat Priority list wear, rather than a checkbox with a label beside it.
    local glyph = CreateFrame("Button", nil, slotRow)
    glyph:SetSize(SLOT_GLYPH_SIZE, SLOT_GLYPH_SIZE)
    glyph:SetPoint("LEFT", slotRow, "LEFT", handleGutter() + SLOT_GLYPH_GAP, 0)
    glyph:EnableMouse(true)
    glyph:SetScript("OnClick", function()
        if slotRow.kcmSlot then toggleSlot(slotRow.kcmSlot) end
    end)
    glyph:SetScript("OnEnter", function(self) showGlyphTip(self, slotRow) end)
    glyph:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    slotRow.kcmGlyph = glyph

    slotRow.kcmLabel = slotRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotRow.kcmLabel:SetPoint("RIGHT", slotRow, "RIGHT", -SLOT_LABEL_INSET, 0)
    slotRow.kcmLabel:SetJustifyH("RIGHT")
    return slotRow
end

--- One row frame, from the free list or newly built, filling `parent` horizontally.
local function acquireSlotRow(parent)
    local slotRow = table.remove(slotPool) or buildSlotRow(parent)
    slotRow:SetParent(parent)
    slotRow:ClearAllPoints()
    slotRow:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    slotRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    return slotRow
end

--- Re-point one row at the slot it serves THIS render.
local function applySlotRow(slotRow, key, shown)
    slotRow.kcmSlot  = key
    slotRow.kcmShown = shown and true or false
    slotRow.kcmGlyphTexture = shown and SHOWN_TEX or HIDDEN_TEX
    slotRow.kcmGlyph:SetNormalTexture(slotRow.kcmGlyphTexture)
    slotRow.kcmLabel:SetText(slotLabel(key))
    -- Grayed rather than hidden: a name you cannot read is a row you cannot aim at,
    -- and aiming at it is how you put the button back. The skin's accent and disabled
    -- text, through KCM.SkinPanelText (S.Text, which records the label for the skin's
    -- replay; the stock look while the Scope ignores the settings panel).
    KCM.SkinPanelText(slotRow.kcmLabel, shown and "accent" or "disabled")
    slotRow:SetHeight(SLOT_ROW_H)
    slotRow:Show()
end

-- ---------------------------------------------------------------------------
-- The controller's lifetime (settings/Category.lua's pattern)
-- ---------------------------------------------------------------------------

--- Stop the previous render's drag and give its handles, row boxes and row frames
--- back. CALLED AT THE TOP OF EVERY RENDER, on every tab, BEFORE H.ResetScroll:
--- releasing a handle is what takes it off the AceGUI container it sits on, and
--- ResetScroll hands those containers to AceGUI's process-wide pool, where the next
--- thing to ask for a SimpleGroup would get one with a live handle still on it.
local function cancelReorder(ctx)
    releaseSlotRows(ctx)
    local lists = ctx and ctx.kcmReorder
    if not lists then return end
    for _, list in ipairs(lists) do list:Cancel() end
    ctx.kcmReorder = nil
end

--- Remember one controller for the cancel above. Nil-tolerant: with
--- LibKa0s-Widgets absent there is no controller, and the list draws without
--- handles, its ticks still working (options-ui-§18).
local function trackReorder(ctx, list)
    if not list then return nil end
    ctx.kcmReorder = ctx.kcmReorder or {}
    ctx.kcmReorder[#ctx.kcmReorder + 1] = list
    return list
end

-- ---------------------------------------------------------------------------
-- Drawing the list
-- ---------------------------------------------------------------------------

--- One slot's row. The SLOT is an AceGUI SimpleGroup a stride tall and the row
--- frame inside it is ROW_H tall, anchored to its top; the difference is the gap.
local function renderSlotRow(ctx, scroll, list, key, shown)
    local slot = KCM.SkinAcquire(AceGUI, "SimpleGroup")
    slot:SetLayout(nil)
    slot:SetFullWidth(true)
    slot:SetHeight(SLOT_ROW_STRIDE)
    scroll:AddChild(slot)

    local slotRow = acquireSlotRow(slot.frame or slot.content)
    applySlotRow(slotRow, key, shown)
    ctx.kcmSlotRows[#ctx.kcmSlotRows + 1] = slotRow

    if list then
        -- NO `parent`: the box and the handle default to the whole row, as on every
        -- other draggable list in the collection. A hidden slot is registered all
        -- the same -- it still counts for indices and still anchors the line -- but
        -- with no handle and in the library's muted box.
        list:AddRow(slotRow, {
            ghostText      = slotLabel(key),
            ghostIcon      = slotRow.kcmGlyphTexture,
            ghostTextColor = { KCM.SkinPanelColor(shown and "text.accent" or "text.disabled") },
            height         = SLOT_ROW_H,
            draggable      = shown,
            dimmed         = not shown,
        })
    end
end

--- The rule under the last shown slot, when there is a divide to mark.
local function addBoundaryRule(scroll)
    local rule = KCM.SkinAcquire(AceGUI, "Heading")
    rule:SetText("")
    rule:SetFullWidth(true)
    rule:SetHeight(12)
    scroll:AddChild(rule)
end

--- The list's `[Bar]` sink while logging is on, else nil (the library logs nothing).
local function slotListDebug()
    if not (KCM.State and KCM.State.debug and KCM.Debug) then return nil end
    return function(fmt, ...) KCM.Debug("Bar", fmt, ...) end
end

--- The reorder controller for `shownCount` draggable slots, or nil with
--- LibKa0s-Widgets absent (the rows then draw without handles).
local function newSlotList(shownCount)
    local W = reorderWidgets()
    if not W then return nil end
    return W.ReorderList({
        -- The STRIDE, not the row height: the drop arithmetic is top of row to top
        -- of row.
        stride        = SLOT_ROW_STRIDE,
        boundary      = shownCount,
        -- The skin owner (skinning-§1): this addon's folder, so the list's boxes, drop line, ghost
        -- and handle tints come from the skin it wears (WidgetsReorder minor 2), and its
        -- minor-1 colors while the Scope ignores the settings panel (panel-scoped by default, minor 3).
        owner         = addonName,

        handleIcon    = KCM.Icon and KCM.Icon(SLOT_HANDLE_ICON) or nil,
        handleTooltip = L["Drag to reorder"],
        onMove        = moveSlot,
        debug         = slotListDebug(),
    })
end

local function renderSlotList(ctx, scroll)
    local order, shown = slotState()
    if not order then return end
    local on, off = partitionSlots(order, shown)

    -- Parked on the ctx so the NEXT render can hand them back, and so a case can
    -- reach a row.
    ctx.kcmSlotRows = {}

    local list = trackReorder(ctx, newSlotList(#on))

    for _, key in ipairs(on) do renderSlotRow(ctx, scroll, list, key, true) end
    if #on > 0 and #off > 0 then addBoundaryRule(scroll) end
    for _, key in ipairs(off) do renderSlotRow(ctx, scroll, list, key, false) end

    -- The insertion line lives on what every row shares as an ancestor.
    if list then list:Finish(scroll.content or scroll.frame) end
end

-- The page's two reaches, at render time: draw the list on the Buttons tab, and
-- give the last render's controllers and rows back at the top of every tab.
KCM.Settings.MacroBarSlots.Render = renderSlotList
KCM.Settings.MacroBarSlots.Cancel = cancelReorder
