-- tests/test_macrobar_buttons.lua -- the Macro Bar page's Buttons tab: one draggable
-- list over the bar's slots, MultiMeters' Columns shape.
--
-- Shown slots first, in their stored order, each with a drag handle; hidden slots
-- after a rule, dimmed and not draggable. A drag within the shown group is a SPLICE
-- (remove, then insert) and writes `macroBar.order` once. The tick is a move too:
-- unticking sends a slot to the TOP of the hidden group, ticking a hidden one sends
-- it to the END of the shown group, and it writes `macroBar.shown` then
-- `macroBar.order`. Both rows are unchanged in shape: the list is only ever the
-- stored order, partitioned.
--
-- Its own suite rather than more cases in tests/test_macrobar.lua, which is already
-- over the 1500-line cap (docs/ARCHITECTURE.md's census, issue #32).

local h = _G.KCM_TEST
local test = h.test

local function shipped(KCM) return KCM.dbDefaults.profile.macroBar.order end

--- Every ReorderList the page builds, with the spec of every row it registered and
--- whether it was canceled. The library is rebuilt per case, so the wrap dies with it.
local function captureLists()
    local W = LibStub("LibKa0s-Widgets-1.0")
    local real = W.ReorderList
    local lists = {}
    W.ReorderList = function(opts)
        local list = real(opts)
        local rec = { opts = opts, specs = {} }
        lists[#lists + 1] = rec
        local add, cancel = list.AddRow, list.Cancel
        list.AddRow = function(self, frame, spec)
            rec.specs[#rec.specs + 1] = spec
            return add(self, frame, spec)
        end
        list.Cancel = function(self, ...)
            rec.canceled = true
            if rec.onCancel then rec.onCancel() end
            return cancel(self, ...)
        end
        return list
    end
    return lists
end

--- Build the Macro Bar page, mark it on screen, and draw the Buttons tab.
local function openButtons(KCM)
    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders.macrobar({})
    local ctx = UI.__panelFor("macrobar")
    ctx.panel.IsShown = function() return true end
    ctx.activeTab = "Buttons"
    KCM.Settings.Helpers.RefreshAllPanels()
    return ctx
end

local function rowKeys(ctx)
    local keys = {}
    for i, row in ipairs(ctx.kcmSlotRows or {}) do keys[i] = row.kcmSlot end
    return keys
end

local function rowFor(ctx, key)
    for _, row in ipairs(ctx.kcmSlotRows or {}) do
        if row.kcmSlot == key then return row end
    end
end

--- The shipped order with `hidden` pulled out and appended in the given order.
local function shownThen(KCM, hidden)
    local skip, out = {}, {}
    for _, k in ipairs(hidden) do skip[k] = true end
    for _, k in ipairs(shipped(KCM)) do
        if not skip[k] then out[#out + 1] = k end
    end
    for _, k in ipairs(hidden) do out[#out + 1] = k end
    return out
end

--- The body of every [Set] line in the console, in order.
local function setLines(KCM)
    local out = {}
    for _, line in ipairs(KCM.DebugLog.instance.buffer) do
        local body = line:match("%[Set%] (.*)$")
        if body then out[#out + 1] = body end
    end
    return out
end

local function armLog(KCM)
    KCM.State.debug = true
    KCM.DebugLog.instance:Clear()
end

-- ---------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------

-- red under: a list drawn in raw stored order (hidden slots interleaved), hidden
-- rows given a handle or an undimmed box, or a boundary that is not the shown count.
test("Buttons: shown slots first in order, then hidden ones dimmed and handle-less, boundary = shown count",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local lists = captureLists()
        KCM.db.profile.macroBar.shown = { DRINK = false, HS = false }
        local ctx = openButtons(KCM)

        t.eqList(rowKeys(ctx), shownThen(KCM, { "DRINK", "HS" }),
            "thirteen shown slots in the bar's order, then the two hidden in theirs")
        local rec = lists[#lists]
        t.truthy(rec, "the tab drew a reorder list")
        t.eq(rec.opts.boundary, 13, "the boundary is the shown count, so a drag cannot cross it")
        t.eq(rec.opts.handleSize, nil, "the handle gutter is the library's (options-ui-§18)")
        t.eq(#rec.specs, 15, "every slot is a row of the list, hidden ones included")
        for i, spec in ipairs(rec.specs) do
            local shown = i <= 13
            t.eq(spec.draggable, shown, "row " .. i .. (shown and " has" or " has no") .. " handle")
            t.eq(spec.dimmed, not shown, "row " .. i .. (shown and " is not" or " is") .. " dimmed")
        end
        t.eq(rowFor(ctx, "DRINK").kcmShown, false, "a hidden row's tick reads hidden")
        t.eq(rowFor(ctx, "FOOD").kcmShown, true, "a shown row's reads shown")
    end)

-- red under: a move written as a pairwise swap (MacroBarModel.Swap), or one that
-- loses the hidden slots' place, or a drop on the same row that still writes.
test("Buttons: a drag splices the shown group and writes the order once; a drop in place writes nothing",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local lists = captureLists()
        KCM.db.profile.macroBar.shown = { DRINK = false }
        openButtons(KCM)

        armLog(KCM)
        t.truthy(lists[#lists].opts.onMove(1, 4), "the move is applied")
        KCM.State.debug = false

        -- FOOD, the first shown slot, dragged to fourth: a splice, so everything it
        -- passed shifts up one -- a swap would have moved only HS.
        local want = shownThen(KCM, { "DRINK" })
        table.insert(want, 4, table.remove(want, 1))
        t.eqList(KCM.db.profile.macroBar.order, want, "the shown group spliced, the hidden slot after it")
        local lines = setLines(KCM)
        t.eq(#lines, 1, "one [Set] line for the act")
        t.truthy(lines[1] and lines[1]:find("^macroBar%.order = "), "and it is the order: " .. tostring(lines[1]))

        armLog(KCM)
        local before = table.concat(KCM.db.profile.macroBar.order, ",")
        t.falsy(lists[#lists].opts.onMove(2, 2), "a drop where the drag began is no move")
        t.falsy(lists[#lists].opts.onMove(1, 15), "nor is a target past the shown group")
        KCM.State.debug = false
        t.eq(table.concat(KCM.db.profile.macroBar.order, ","), before, "the order is untouched")
        t.eqList(setLines(KCM), {}, "and nothing was logged")
    end)

-- red under: unticking a slot anywhere but the top of the hidden group, ticking one
-- back anywhere but the end of the shown group, or the two rows written in the
-- other order.
test("Buttons: untick goes to the top of the hidden group, tick to the end of the shown group",
    function(t)
        local KCM = h.loader.loadFullAddon()
        KCM.db.profile.macroBar.shown = { HS = false }
        local ctx = openButtons(KCM)

        armLog(KCM)
        rowFor(ctx, "DRINK").kcmGlyph:_run("OnClick")
        KCM.State.debug = false
        local c = KCM.db.profile.macroBar
        t.eq(c.shown.DRINK, false, "unticking hides the slot with a real false")
        t.eqList(c.order, shownThen(KCM, { "DRINK", "HS" }), "and puts it at the top of the hidden group")
        local lines = setLines(KCM)
        t.eq(#lines, 2, "two rows written, two [Set] lines")
        t.truthy(lines[1] and lines[1]:find("^macroBar%.shown = "), "the visibility first: " .. tostring(lines[1]))
        t.truthy(lines[2] and lines[2]:find("^macroBar%.order = "), "then the place it moved to: " .. tostring(lines[2]))
        t.eqList(rowKeys(ctx), c.order, "the list redrew in the new order")

        rowFor(ctx, "HS").kcmGlyph:_run("OnClick")
        t.eq(c.shown.HS, true, "ticking a hidden slot shows it with a real true")
        local want = shownThen(KCM, { "DRINK", "HS" })
        table.remove(want)                     -- HS out of the hidden group...
        table.insert(want, #want, "HS")        -- ...and in at the end of the shown one, before DRINK
        t.eqList(c.order, want, "at the end of the shown group, ahead of the still-hidden slot")
    end)

-- The checkboxes this list replaced let a player untick all fifteen; the bar then
-- collapses to an empty backdrop (docs/smoke-tests.md §11a step 11). Kept.
test("Buttons: every slot can be hidden, as the checkboxes allowed", function(t)
    local KCM = h.loader.loadFullAddon()
    local ctx = openButtons(KCM)
    local said = #h.loader.mock.output
    for _, key in ipairs(shipped(KCM)) do rowFor(ctx, key).kcmGlyph:_run("OnClick") end

    local hidden = 0
    for _, flag in pairs(KCM.db.profile.macroBar.shown) do
        if flag == false then hidden = hidden + 1 end
    end
    t.eq(hidden, #shipped(KCM), "every slot is hidden")
    t.eqList(KCM.MacroBarModel.Visible(), {}, "and the bar carries none")
    t.eq(#h.loader.mock.output, said, "with nothing refused on the way")
end)

-- options-ui-§18: the controller is canceled at the TOP of the render, before the
-- scroll hands its containers back to AceGUI's pool with live handles on them.
--
-- red under: a render that clears the scroll first, or never cancels the last
-- render's controller.
test("Buttons: the last render's controller is canceled before the scroll is cleared", function(t)
    local KCM = h.loader.loadFullAddon()
    local lists = captureLists()
    local ctx = openButtons(KCM)
    local H = KCM.Settings.Helpers

    local seq = {}
    local first = lists[#lists]
    first.onCancel = function() seq[#seq + 1] = "cancel" end
    local realReset = H.ResetScroll
    H.ResetScroll = function(...) seq[#seq + 1] = "reset"; return realReset(...) end
    H.RefreshAllPanels()
    H.ResetScroll = realReset

    t.truthy(first.canceled, "a repaint cancels the previous controller")
    t.eq(seq[1], "cancel", "and does it before the scroll is cleared")
    t.truthy(lists[#lists] ~= first, "the repaint built a controller of its own")

    local second = lists[#lists]
    ctx.activeTab = "General"
    H.RefreshAllPanels()
    t.truthy(second.canceled, "leaving the tab cancels it too")
end)

-- MB.SwapSlots' rule and MultiMeters' commit(): a refused write repaints nothing,
-- so the page is never drawn from a state that was not stored.
--
-- red under: writing in combat, or repainting after the refusal.
test("Buttons: in combat a drag and a tick are refused, write nothing and repaint nothing", function(t)
    local KCM = h.loader.loadFullAddon()
    local lists = captureLists()
    local ctx = openButtons(KCM)
    local H = KCM.Settings.Helpers

    local updates, refreshes, writes = 0, 0, 0
    KCM.MacroBar.Update = function() updates = updates + 1 end
    local realRefresh, realSet = H.RefreshAllPanels, H.Set
    H.RefreshAllPanels = function(...) refreshes = refreshes + 1; return realRefresh(...) end
    H.Set = function(...) writes = writes + 1; return realSet(...) end
    local realCombat = _G.InCombatLockdown
    _G.InCombatLockdown = function() return true end
    local said = #h.loader.mock.output

    local moved = lists[#lists].opts.onMove(1, 2)
    rowFor(ctx, "FOOD").kcmGlyph:_run("OnClick")

    _G.InCombatLockdown = realCombat
    H.RefreshAllPanels, H.Set = realRefresh, realSet
    t.falsy(moved, "the drag reports it did not apply")
    t.eq(writes, 0, "nothing was written")
    t.eq(refreshes, 0, "nothing was repainted")
    t.eq(updates, 0, "the bar was not re-applied")
    t.eqList(KCM.db.profile.macroBar.order, shipped(KCM), "the order is as it was")
    t.eq(KCM.db.profile.macroBar.shown.FOOD, nil, "and so is the slot's visibility")
    t.eq(#h.loader.mock.output - said, 2, "each refusal said why, once")
    t.truthy((h.loader.mock.output[#h.loader.mock.output] or ""):find("combat", 1, true),
        "and the reason names combat")
end)

-- The bar is what the player is arranging, so each act must reach it -- once, not
-- once per row the act wrote -- and the panel must be rebuilt once.
--
-- red under: each row firing its own bar re-apply, or a move that does not reach
-- the bar at all.
test("Buttons: each act re-applies the bar once, and the bar carries the new order and set", function(t)
    local KCM = h.loader.loadFullAddon()
    local lists = captureLists()
    local ctx = openButtons(KCM)
    local H = KCM.Settings.Helpers
    local updates, refreshes = 0, 0
    local realUpdate, realRefresh = KCM.MacroBar.Update, H.RefreshAllPanels
    KCM.MacroBar.Update = function(...) updates = updates + 1; return realUpdate(...) end
    H.RefreshAllPanels = function(...) refreshes = refreshes + 1; return realRefresh(...) end

    lists[#lists].opts.onMove(2, 1)
    t.eq(updates, 1, "a drag re-applies the bar once")
    t.eq(refreshes, 1, "and rebuilds the page once")
    local want = shipped(KCM)
    want = { want[2], want[1], select(3, unpack(want)) }
    t.eqList(KCM.MacroBarModel.Visible(), want, "the bar shows the dragged order")

    rowFor(ctx, "FOOD").kcmGlyph:_run("OnClick")
    t.eq(updates, 2, "a tick writes two rows and still re-applies the bar once")
    t.eq(refreshes, 2, "and rebuilds the page once")
    table.remove(want, 2)
    t.eqList(KCM.MacroBarModel.Visible(), want, "and the bar no longer carries the hidden slot")
    H.RefreshAllPanels = realRefresh
end)

-- ---------------------------------------------------------------------------
-- #35: every writer of the two rows goes through the schema helper
-- ---------------------------------------------------------------------------

-- Moved here, reshaped, from tests/test_macrobar.lua, where it pinned the
-- checkboxes this list replaced.
--
-- red under: SwapSlots, the list's drag or its tick writing their field directly.
test("macrobar: the slot swap, the list's drag and its tick write through the schema helper", function(t)
    local KCM = h.loader.loadFullAddon()
    local lists = captureLists()
    local H = KCM.Settings.Helpers
    local paths, realSet = {}, H.Set
    H.Set = function(path, value) paths[#paths + 1] = path; return realSet(path, value) end

    KCM.MacroBar.SwapSlots("FOOD", "DRINK")
    local ctx = openButtons(KCM)
    lists[#lists].opts.onMove(1, 2)
    rowFor(ctx, "HS").kcmGlyph:_run("OnClick")
    H.Set = realSet

    t.eqList(paths, { "macroBar.order", "macroBar.order", "macroBar.shown", "macroBar.order" },
        "a swap and a drag are one whole-order write each, a tick the map and then the order")
    t.eq(KCM.db.profile.macroBar.shown.HS, false, "and the tick's write landed as a real boolean")
end)
