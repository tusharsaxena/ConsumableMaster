-- tests/test_macrobar.lua — the macro bar's pure layer: grid + label + flyout
-- geometry (core/MacroBarLayout.lua), slot bookkeeping (core/MacroBarModel.lua),
-- display resolution (core/MacroDisplay.lua), the flyout's candidate list
-- (MacroBarFlyout.Candidates, which is pure over Selector + config), and the
-- Macro Bar page's schema rows.
--
-- The rest of the frame layer (modules/MacroBar*.lua) is deliberately not
-- exercised here — it is a thin apply pass over these, and secure-frame
-- behavior can only be validated in-game (docs/smoke-tests.md). The flyout's
-- candidate SOURCE is covered in tests/test_selector.lua
-- (Selector.ListAvailable).
local h = require("harness")
local test = h.test

local function cfg(over)
    local c = {
        buttonSize = 30, spacing = 5, padding = 4, perRow = 13,
        orientation = "HORIZONTAL", growthH = "RIGHT", growthV = "DOWN",
    }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

test("macrobar layout: one row of 13 reports 13 columns and one row", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(13, cfg())
    t.eq(g.cols, 13, "cols")
    t.eq(g.rows, 1, "rows")
    t.eq(#g.positions, 13, "one position per slot")
    -- padding*2 + 13 buttons + 12 gaps
    t.eq(g.width, 4 * 2 + 13 * 30 + 12 * 5, "width")
    t.eq(g.height, 4 * 2 + 30, "height")
end)

test("macrobar layout: first slot sits at the padding offset", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(13, cfg())
    t.eq(g.positions[1].x, 4, "x = padding")
    t.eq(g.positions[1].y, -4, "y = -padding (WoW y grows downward as negative)")
end)

test("macrobar layout: slots step by size + spacing along the row", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(13, cfg())
    t.eq(g.positions[2].x, 4 + 35, "second slot x")
    t.eq(g.positions[2].y, -4, "second slot stays on row 1")
end)

test("macrobar layout: 13 slots at 7 per row wrap into two rows", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(13, cfg{ perRow = 7 })
    t.eq(g.cols, 7, "cols")
    t.eq(g.rows, 2, "rows")
    t.eq(g.positions[8].x, 4, "slot 8 wraps to the first column")
    t.eq(g.positions[8].y, -(4 + 35), "slot 8 drops to row 2")
end)

test("macrobar layout: growth LEFT mirrors the columns", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(3, cfg{ perRow = 3, growthH = "LEFT" })
    t.eq(g.positions[1].x, 4 + 2 * 35, "first slot sits at the right edge")
    t.eq(g.positions[3].x, 4, "last slot sits at the left edge")
end)

test("macrobar layout: growth UP mirrors the rows", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(4, cfg{ perRow = 2, growthV = "UP" })
    t.eq(g.rows, 2, "rows")
    t.eq(g.positions[1].y, -(4 + 35), "first row sits at the bottom")
    t.eq(g.positions[3].y, -4, "second row sits at the top")
end)

test("macrobar layout: VERTICAL orientation fills columns first", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(4, cfg{ perRow = 2, orientation = "VERTICAL" })
    t.eq(g.cols, 2, "cols")
    t.eq(g.rows, 2, "rows")
    t.eq(g.positions[2].x, 4, "slot 2 stays in column 1")
    t.eq(g.positions[2].y, -(4 + 35), "slot 2 drops one row")
    t.eq(g.positions[3].x, 4 + 35, "slot 3 starts column 2")
    t.eq(g.positions[3].y, -4, "slot 3 is back at the top")
end)

test("macrobar layout: zero slots still reports a non-zero container", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(0, cfg())
    t.eq(#g.positions, 0, "no positions")
    t.eq(g.width, 4 * 2 + 30, "width falls back to one cell")
    t.eq(g.height, 4 * 2 + 30, "height falls back to one cell")
end)

test("macrobar layout: missing config falls back to shipped defaults", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(2, nil)
    t.eq(g.rows, 1, "default perRow of 13 keeps 2 slots on one row")
    t.eq(g.positions[2].x, 4 + 36 + 4, "default size 36 + spacing 4")
end)

test("macrobar layout: perRow below 1 is clamped rather than dividing by zero", function(t)
    local KCM = h.loader.loadPure()
    local g = KCM.MacroBarLayout.Grid(3, cfg{ perRow = 0 })
    t.eq(g.cols, 1, "cols clamps to 1")
    t.eq(g.rows, 3, "every slot gets its own row")
end)

-- ---------------------------------------------------------------------------
-- Label geometry + sizing
-- ---------------------------------------------------------------------------

test("macrobar label: inside anchors the label's own corner to the button's", function(t)
    local KCM = h.loader.loadPure()
    local point, relPoint, x, y, justify = KCM.MacroBarLayout.LabelAnchor{
        labelPoint = "TOP_LEFT", labelPlacement = "INSIDE",
    }
    t.eq(point, "TOPLEFT", "label point")
    t.eq(relPoint, "TOPLEFT", "button point")
    t.eq(x, 0, "no x offset")
    t.eq(y, 0, "no y offset")
    t.eq(justify, "LEFT", "left-aligned text")
end)

test("macrobar label: outside flips the anchor across that edge", function(t)
    local KCM = h.loader.loadPure()
    local point, relPoint = KCM.MacroBarLayout.LabelAnchor{
        labelPoint = "TOP_CENTER", labelPlacement = "OUTSIDE",
    }
    t.eq(point, "BOTTOM", "label's bottom edge...")
    t.eq(relPoint, "TOP", "...sits on the button's top edge")
end)

test("macrobar label: offsets pass through and CENTER never flips", function(t)
    local KCM = h.loader.loadPure()
    local point, relPoint, x, y = KCM.MacroBarLayout.LabelAnchor{
        labelPoint = "CENTER", labelPlacement = "OUTSIDE",
        labelOffsetX = 3, labelOffsetY = -7,
    }
    t.eq(point, "CENTER", "center stays centered")
    t.eq(relPoint, "CENTER", "even when placement says outside")
    t.eq(x, 3, "x offset")
    t.eq(y, -7, "y offset")
end)

test("macrobar label: an unknown position falls back to the shipped default", function(t)
    local KCM = h.loader.loadPure()
    local point, relPoint = KCM.MacroBarLayout.LabelAnchor{ labelPoint = "SIDEWAYS" }
    t.eq(point, "TOP", "falls back to TOP_CENTER")
    t.eq(relPoint, "TOP", "falls back to TOP_CENTER")
end)

test("macrobar label: every declared label position resolves to an anchor", function(t)
    local KCM = h.loader.loadPure()
    for _, pos in ipairs(KCM.MacroBarLayout.LABEL_POINTS) do
        for _, placement in ipairs({ "INSIDE", "OUTSIDE" }) do
            local point, relPoint, _, _, justify =
                KCM.MacroBarLayout.LabelAnchor{ labelPoint = pos, labelPlacement = placement }
            t.truthy(point, pos .. "/" .. placement .. " point")
            t.truthy(relPoint, pos .. "/" .. placement .. " relPoint")
            t.truthy(justify, pos .. "/" .. placement .. " justify")
        end
    end
end)

test("macrobar label: font size scales with the button and clamps to legible", function(t)
    local KCM = h.loader.loadPure()
    local F = KCM.MacroBarLayout.LabelFontSize
    t.eq(F(50, 26), 13, "26% of a 50px button")
    t.eq(F(16, 26), 6,  "tiny button clamps up to 6pt")
    t.eq(F(64, 50), 24, "huge label clamps down to 24pt")
    t.eq(F(nil, nil), 9, "defaults to 26% of the default 36px button")
end)

test("macrobar label: every category supplies both a full and a short label", function(t)
    local KCM = h.loader.loadPure()
    for _, row in ipairs(KCM.Categories.LIST) do
        local full, short = KCM.MacroBarModel.Labels(row.key)
        t.eq(full, row.displayName, row.key .. " full label is the display name")
        t.truthy(short and short ~= "", row.key .. " has a short label")
        t.truthy(#short <= #full, row.key .. " short label is no longer than the full one")
    end
end)

test("macrobar label: an unknown category degrades to its key", function(t)
    local KCM = h.loader.loadPure()
    local full, short = KCM.MacroBarModel.Labels("NOPE")
    t.eq(full, "NOPE", "full")
    t.eq(short, "NOPE", "short")
end)

-- ---------------------------------------------------------------------------
-- Flyout geometry
-- ---------------------------------------------------------------------------

local function fcfg(over)
    local c = { buttonSize = 40, flyoutScale = 100, flyoutSpacing = 2,
                flyoutGap = 4, flyoutPadding = 0, flyoutIndicatorScale = 20,
                flyoutPoint = "TOP" }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

test("macrobar flyout: entry 1 sits one gap off the button", function(t)
    local KCM = h.loader.loadPure()
    local f = KCM.MacroBarLayout.Flyout(3, fcfg())
    t.eq(f.point, "BOTTOM", "container's bottom edge...")
    t.eq(f.relPoint, "TOP", "...pins to the button's top edge")
    -- The gap is an inset INSIDE the container (which stays flush to the
    -- button), so it clears the button border without becoming dead space that
    -- would fire the secure _onleave as the mouse crossed it.
    t.eq(f.positions[1].y, 4, "first entry stands off by flyoutGap")
    t.eq(f.positions[1].x, 0, "no lateral drift")
end)

test("macrobar flyout: the gap is configurable and can be closed to zero", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroBarLayout.Flyout(1, fcfg{ flyoutGap = 12 }).positions[1].y, 12, "wider gap")
    t.eq(KCM.MacroBarLayout.Flyout(1, fcfg{ flyoutGap = 0 }).positions[1].y, 0, "flush again")
    -- The container grows by the gap, so its hit area still reaches the button.
    t.eq(KCM.MacroBarLayout.Flyout(1, fcfg{ flyoutGap = 12 }).height, 12 + 40,
        "container covers the gap plus the entry")
end)

test("macrobar flyout: entries step by size + spacing away from the button", function(t)
    local KCM = h.loader.loadPure()
    local f = KCM.MacroBarLayout.Flyout(3, fcfg())
    t.eq(f.positions[2].y, 4 + 42, "second entry")
    t.eq(f.positions[3].y, 4 + 84, "third entry")
    t.eq(f.size, 40, "entry size matches the button at 100%")
end)

test("macrobar flyout: growing downward mirrors the offsets", function(t)
    local KCM = h.loader.loadPure()
    local f = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPoint = "BOTTOM" })
    t.eq(f.point, "TOP", "container's top edge...")
    t.eq(f.relPoint, "BOTTOM", "...pins to the button's bottom edge")
    t.eq(f.positions[1].y, -4, "first entry sits below the button")
    t.eq(f.positions[2].y, -(4 + 42), "and the strip grows further down")
end)

test("macrobar flyout: horizontal sides stack along x instead of y", function(t)
    local KCM = h.loader.loadPure()
    local right = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPoint = "RIGHT" })
    t.eq(right.axis, "H", "horizontal axis")
    t.eq(right.positions[2].x, 4 + 42, "grows rightward")
    t.eq(right.positions[2].y, 0, "stays on the button's center line")
    local left = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPoint = "LEFT" })
    t.eq(left.positions[2].x, -(4 + 42), "grows leftward")
end)

test("macrobar flyout: container is sized to the run of entries", function(t)
    local KCM = h.loader.loadPure()
    local f = KCM.MacroBarLayout.Flyout(3, fcfg())
    t.eq(f.width, 40, "one entry wide")
    t.eq(f.height, 4 + 3 * 40 + 2 * 2, "button gap + 3 entries + 2 inter-entry gaps")
end)

test("macrobar flyout: scale shrinks entries independently of the button", function(t)
    local KCM = h.loader.loadPure()
    local f = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutScale = 50 })
    t.eq(f.size, 20, "half-size entries")
    t.eq(f.positions[2].y, 4 + 22, "step follows the smaller size")
end)

test("macrobar flyout: an empty flyout still reports a usable frame size", function(t)
    local KCM = h.loader.loadPure()
    local f = KCM.MacroBarLayout.Flyout(0, fcfg())
    t.eq(#f.positions, 0, "no entries")
    t.truthy(f.width >= 1 and f.height >= 1, "never a zero dimension")
end)

test("macrobar flyout: padding insets the strip inside its panel", function(t)
    local KCM = h.loader.loadPure()
    local bare = KCM.MacroBarLayout.Flyout(2, fcfg())
    local pad  = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPadding = 5 })
    -- Along the axis the padding pushes entries out past the button gap...
    t.eq(pad.positions[1].y, bare.positions[1].y + 5, "first entry moves by the padding")
    -- ...and the container grows on both ends, plus both cross-axis sides, so the
    -- backdrop reads as a frame around the entries rather than flush to them.
    t.eq(pad.height, bare.height + 10, "panel grows at both ends of the axis")
    t.eq(pad.width, bare.width + 10, "and on both sides across it")
end)

test("macrobar flyout: padding leaves entries centered on the cross axis", function(t)
    local KCM = h.loader.loadPure()
    -- Entries share the container's anchor point, so cross-axis centering is
    -- automatic — no per-entry offset to get wrong.
    local f = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPadding = 5 })
    t.eq(f.positions[1].x, 0, "no lateral offset on a vertical flyout")
    local side = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPadding = 5, flyoutPoint = "RIGHT" })
    t.eq(side.positions[1].y, 0, "nor vertical offset on a horizontal one")
end)

test("macrobar flyout: the indicator band sits inside the icon's edge", function(t)
    local KCM = h.loader.loadPure()
    local point, relPoint, dx, dy, rotation, w, h, glyph =
        KCM.MacroBarLayout.IndicatorAnchor(fcfg())
    -- Same point on both sides = flush inside that edge, not hanging off it.
    t.eq(point, "TOP", "band's top...")
    t.eq(relPoint, "TOP", "...on the button's top, so it overlays the artwork")
    t.eq(dx, 0, "no horizontal offset")
    t.eq(dy, 0, "no vertical offset")
    -- The source texture points RIGHT at rest, so "up" is a quarter turn.
    t.near(rotation, math.pi / 2, 1e-9, "arrow rotated to point up")
    t.eq(w, 40, "spans the button's width")
    t.eq(h, 8, "as thick as configured")
    t.eq(glyph, 8, "square glyph filling the band at the default 100% — never stretched")
end)

test("macrobar flyout: each side rotates the arrow to point away from the button", function(t)
    local KCM = h.loader.loadPure()
    local function rot(side)
        local _, _, _, _, rotation = KCM.MacroBarLayout.IndicatorAnchor(fcfg{ flyoutPoint = side })
        return rotation
    end
    -- Source texture rests pointing RIGHT, hence RIGHT is the unrotated case.
    t.near(rot("RIGHT"),  0,            1e-9, "right needs no rotation")
    t.near(rot("TOP"),    math.pi / 2,  1e-9, "up is a quarter turn")
    t.near(rot("BOTTOM"), -math.pi / 2, 1e-9, "down is a quarter turn the other way")
    t.near(rot("LEFT"),   math.pi,      1e-9, "left is a half turn")
end)

test("macrobar flyout: arrow size scales off the band and never vanishes", function(t)
    local KCM = h.loader.loadPure()
    local function glyphFor(over)
        local _, _, _, _, _, _, _, g = KCM.MacroBarLayout.IndicatorAnchor(fcfg(over))
        return g
    end
    -- 30% of the 40px button in fcfg is a 12px band.
    t.eq(glyphFor{ flyoutIndicatorScale = 30, flyoutArrowScale = 150 }, 18, "150% overflows the band")
    t.eq(glyphFor{ flyoutIndicatorScale = 30, flyoutArrowScale = 100 }, 12, "100% fills the band")
    t.eq(glyphFor{ flyoutIndicatorScale = 10, flyoutArrowScale = 25 },  6,  "clamped to a visible floor")
end)

test("macrobar flyout: a side band swaps its span and thickness", function(t)
    local KCM = h.loader.loadPure()
    local point, relPoint, dx, dy, _, w, h =
        KCM.MacroBarLayout.IndicatorAnchor(fcfg{ flyoutPoint = "LEFT" })
    t.eq(point, "LEFT", "band's left...")
    t.eq(relPoint, "LEFT", "...on the button's left")
    t.eq(dx, 0, "no horizontal offset")
    t.eq(dy, 0, "no vertical offset")
    t.eq(w, 8, "thickness on the x axis now")
    t.eq(h, 40, "spans the button's height")
end)

test("macrobar flyout: band thickness is a ratio of the button, capped at half", function(t)
    local KCM = h.loader.loadPure()
    local T = KCM.MacroBarLayout.IndicatorThickness
    t.eq(T{ buttonSize = 40, flyoutIndicatorScale = 25 }, 10, "25% of a 40px button")
    t.eq(T{ buttonSize = 60, flyoutIndicatorScale = 25 }, 15, "and it scales with the button")
    t.eq(T{ buttonSize = 20, flyoutIndicatorScale = 90 }, 10, "clamped to half a 20px button")
    t.eq(T{ buttonSize = 3,  flyoutIndicatorScale = 90 }, 2,  "never below the 2px floor")
    t.eq(T{}, 12, "defaults to 33% of the default 36px button")
end)

test("macrobar flyout: every flyout side resolves geometry", function(t)
    local KCM = h.loader.loadPure()
    for _, side in ipairs(KCM.MacroBarLayout.FLYOUT_POINTS) do
        local f = KCM.MacroBarLayout.Flyout(2, fcfg{ flyoutPoint = side })
        t.truthy(f.point and f.relPoint, side .. " container anchor")
        t.eq(#f.positions, 2, side .. " positions")
        local point = KCM.MacroBarLayout.IndicatorAnchor(fcfg{ flyoutPoint = side })
        t.truthy(point, side .. " indicator anchor")
    end
end)

-- ---------------------------------------------------------------------------
-- Label clearance around the indicator
-- ---------------------------------------------------------------------------

test("macrobar flyout: a label sharing the band's edge is pushed clear", function(t)
    local KCM = h.loader.loadPure()
    local _, _, _, y = KCM.MacroBarLayout.LabelAnchor{
        flyout = true, flyoutPoint = "TOP", buttonSize = 40, flyoutIndicatorScale = 20,
        labelPoint = "TOP_CENTER", labelPlacement = "INSIDE", labelOffsetY = -2,
    }
    t.eq(y, -2 - 9, "user offset plus the whole band thickness and a pixel")
end)

test("macrobar flyout: clearance follows the band to another edge", function(t)
    local KCM = h.loader.loadPure()
    local cfg = { flyout = true, buttonSize = 40, flyoutIndicatorScale = 20,
                  labelPlacement = "INSIDE" }
    cfg.flyoutPoint, cfg.labelPoint = "BOTTOM", "BOTTOM_CENTER"
    local _, _, _, down = KCM.MacroBarLayout.LabelAnchor(cfg)
    t.eq(down, 9, "a bottom label is pushed up")
    cfg.flyoutPoint, cfg.labelPoint = "LEFT", "LEFT"
    local _, _, left = KCM.MacroBarLayout.LabelAnchor(cfg)
    t.eq(left, 9, "a left label is pushed right")
end)

test("macrobar flyout: a label on a different edge is left alone", function(t)
    local KCM = h.loader.loadPure()
    local dx, dy = KCM.MacroBarLayout.IndicatorClearance{
        flyout = true, flyoutPoint = "TOP",
        labelPoint = "BOTTOM_CENTER", labelPlacement = "INSIDE",
    }
    t.eq(dx, 0, "no x clearance")
    t.eq(dy, 0, "no y clearance")
end)

test("macrobar flyout: no clearance when the flyout is off or the label is outside", function(t)
    local KCM = h.loader.loadPure()
    local _, offDy = KCM.MacroBarLayout.IndicatorClearance{
        flyout = false, flyoutPoint = "TOP", labelPoint = "TOP_CENTER", labelPlacement = "INSIDE",
    }
    t.eq(offDy, 0, "flyout disabled")
    local _, outDy = KCM.MacroBarLayout.IndicatorClearance{
        flyout = true, flyoutPoint = "TOP", labelPoint = "TOP_CENTER", labelPlacement = "OUTSIDE",
    }
    t.eq(outDy, 0, "an outside label owns its own offsets")
end)

test("macrobar flyout: clearance scales with the band thickness", function(t)
    local KCM = h.loader.loadPure()
    local _, thin = KCM.MacroBarLayout.IndicatorClearance{
        flyout = true, flyoutPoint = "TOP", labelPoint = "TOP_CENTER",
        labelPlacement = "INSIDE", buttonSize = 40, flyoutIndicatorScale = 10,
    }
    local _, fat = KCM.MacroBarLayout.IndicatorClearance{
        flyout = true, flyoutPoint = "TOP", labelPoint = "TOP_CENTER",
        labelPlacement = "INSIDE", buttonSize = 40, flyoutIndicatorScale = 50,
    }
    t.eq(thin, -5, "a thin band needs little room")
    t.eq(fat, -21, "a deep band pushes the label further in")
end)

-- ---------------------------------------------------------------------------
-- Model
-- ---------------------------------------------------------------------------

test("macrobar model: AllKeys covers every managed category", function(t)
    local KCM = h.loader.loadPure()
    t.eq(#KCM.MacroBarModel.AllKeys(), #KCM.Categories.LIST, "one key per category")
end)

test("macrobar model: NormalizeOrder leaves a complete order untouched", function(t)
    local KCM = h.loader.loadPure()
    local all = KCM.MacroBarModel.AllKeys()
    local out, changed = KCM.MacroBarModel.NormalizeOrder(all)
    t.falsy(changed, "nothing changed")
    t.eqList(out, all, "order preserved")
end)

test("macrobar model: NormalizeOrder drops unknown keys", function(t)
    local KCM = h.loader.loadPure()
    local out, changed = KCM.MacroBarModel.NormalizeOrder({ "FOOD", "NOT_A_CATEGORY" })
    t.truthy(changed, "reports a change")
    t.eq(out[1], "FOOD", "known key kept first")
    for _, k in ipairs(out) do t.ne(k, "NOT_A_CATEGORY", "unknown key dropped") end
end)

test("macrobar model: NormalizeOrder appends categories missing from a saved order", function(t)
    local KCM = h.loader.loadPure()
    local out, changed = KCM.MacroBarModel.NormalizeOrder({ "VANTUS" })
    t.truthy(changed, "reports a change")
    t.eq(out[1], "VANTUS", "saved key keeps its position")
    t.eq(#out, #KCM.Categories.LIST, "every other category appended")
end)

test("macrobar model: NormalizeOrder de-duplicates a repeated key", function(t)
    local KCM = h.loader.loadPure()
    local out = KCM.MacroBarModel.NormalizeOrder({ "FOOD", "FOOD", "DRINK" })
    local seen = 0
    for _, k in ipairs(out) do if k == "FOOD" then seen = seen + 1 end end
    t.eq(seen, 1, "FOOD appears once")
end)

test("macrobar model: Swap exchanges two slots", function(t)
    local KCM = h.loader.loadPure()
    local order = { "FOOD", "DRINK", "HS" }
    t.truthy(KCM.MacroBarModel.Swap(order, "FOOD", "HS"), "swap succeeds")
    t.eqList(order, { "HS", "DRINK", "FOOD" }, "endpoints exchanged")
end)

test("macrobar model: Swap refuses an absent or self-referential key", function(t)
    local KCM = h.loader.loadPure()
    local order = { "FOOD", "DRINK" }
    t.falsy(KCM.MacroBarModel.Swap(order, "FOOD", "FLASK"), "absent key rejected")
    t.falsy(KCM.MacroBarModel.Swap(order, "FOOD", "FOOD"), "self-swap rejected")
    t.eqList(order, { "FOOD", "DRINK" }, "order untouched")
end)

test("macrobar model: VisibleKeys hides only slots explicitly set to false", function(t)
    local KCM = h.loader.loadPure()
    local order = { "FOOD", "DRINK", "HS" }
    local out = KCM.MacroBarModel.VisibleKeys(order, { DRINK = false, HS = true })
    t.eqList(out, { "FOOD", "HS" }, "unset stays visible, false is hidden")
end)

test("macrobar model: MacroName and KeyForMacroName round-trip", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroBarModel.MacroName("FOOD"), "KCM_FOOD", "key to macro name")
    t.eq(KCM.MacroBarModel.KeyForMacroName("KCM_FOOD"), "FOOD", "macro name to key")
    t.falsy(KCM.MacroBarModel.KeyForMacroName("SomeOtherMacro"), "foreign macro rejected")
    t.falsy(KCM.MacroBarModel.MacroName("NOPE"), "unknown key has no macro name")
end)

test("macrobar model: the bar ships centered on screen at 36px buttons", function(t)
    local KCM = h.loader.loadPure()
    local d = KCM.dbDefaults.profile.macroBar
    t.eq(d.point, "CENTER", "anchored by its center...")
    t.eq(d.relPoint, "CENTER", "...to the screen's center")
    t.eq(d.x, 0, "no horizontal offset")
    t.eq(d.y, 0, "no vertical offset either, so it lands dead center")
    t.eq(d.buttonSize, 36, "standard action-button size")
end)

test("macrobar model: the bar ships on and unlocked so it is discoverable", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.MacroBarModel.IsEnabled(), "macroBar.enabled defaults to true")
    t.eq(KCM.db.profile.macroBar.locked, false,
        "unlocked by default, so the drag handle is there to place it")
end)

test("macrobar model: the shipped default order needs no repair", function(t)
    local KCM = h.loader.loadPure()
    local _, changed = KCM.MacroBarModel.NormalizeOrder(
        KCM.dbDefaults.profile.macroBar.order)
    t.falsy(changed, "default order is complete, unique and all-known")
end)

test("macrobar model: Order repairs and writes back a damaged saved order", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.order = { "FOOD", "BOGUS" }
    local out = KCM.MacroBarModel.Order()
    t.eq(#out, #KCM.Categories.LIST, "returned order is complete")
    t.eq(#KCM.db.profile.macroBar.order, #KCM.Categories.LIST, "repair persisted to the db")
end)

test("macrobar model: Visible reflects the shown map over the saved order", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.shown = { FOOD = false }
    local out = KCM.MacroBarModel.Visible()
    t.eq(#out, #KCM.Categories.LIST - 1, "one slot hidden")
    for _, k in ipairs(out) do t.ne(k, "FOOD", "FOOD is not rendered") end
end)

-- ---------------------------------------------------------------------------
-- MacroDisplay
-- ---------------------------------------------------------------------------

test("macrodisplay: an unwritten macro falls back to the cooking-pot icon", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroDisplay.Texture("KCM_FOOD"), KCM.MacroDisplay.FALLBACK_ICON,
        "no macroState, no macro -> fallback")
end)

test("macrodisplay: an item pick resolves to the item's icon and count", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setItem(1234, { name = "Bread", subType = "Food & Drink" })
    h.loader.mock.setBag(1234, 7)
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = 1234 }
    t.eq(KCM.MacroDisplay.PickID("KCM_FOOD"), 1234, "pick id")
    t.eq(KCM.MacroDisplay.Texture("KCM_FOOD"), "icon:1234", "item icon")
    t.eq(KCM.MacroDisplay.Count("KCM_FOOD"), 7, "owned count")
end)

test("macrodisplay: a spell pick resolves to the spell icon and has no count", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setSpell(999, { name = "Recuperate", known = true })
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = KCM.ID.AsSpell(999) }
    t.eq(KCM.MacroDisplay.Texture("KCM_FOOD"), "spellicon:999", "spell icon")
    t.falsy(KCM.MacroDisplay.Count("KCM_FOOD"), "spells have no stack count")
end)

test("macrodisplay: item and spell cooldowns both report active plus a span", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setItem(1234, { name = "Potion", subType = "Potions" })
    h.loader.mock.setCooldown(1234, 100, 300)
    KCM.db.profile.macroState["KCM_HP_POT"] = { lastItemID = 1234 }
    local active, obj, start, duration = KCM.MacroDisplay.Cooldown("KCM_HP_POT")
    t.eq(active, true, "item cooldown is running")
    t.eq(start, 100, "item cooldown start")
    t.eq(duration, 300, "item cooldown duration")
    t.eq(obj.duration, 300, "and the same span reaches the duration object")

    h.loader.mock.setSpell(999, { name = "Recuperate", known = true })
    h.loader.mock.setCooldown(KCM.ID.AsSpell(999), 50, 120)
    KCM.db.profile.macroState["KCM_HS"] = { lastItemID = KCM.ID.AsSpell(999) }
    local sActive, sObj, sStart, sDuration = KCM.MacroDisplay.Cooldown("KCM_HS")
    t.eq(sActive, true, "spell cooldown is running")
    t.eq(sStart, 50, "spell cooldown start")
    t.eq(sDuration, 120, "spell cooldown duration")
    t.eq(sObj.duration, 120, "the client's own duration object is passed through")
end)

test("macrodisplay: an empty-state macro reports no pick, count or cooldown", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = nil }
    t.falsy(KCM.MacroDisplay.PickID("KCM_FOOD"), "no pick")
    t.falsy(KCM.MacroDisplay.Count("KCM_FOOD"), "no count")
    t.falsy(KCM.MacroDisplay.Cooldown("KCM_FOOD"), "no cooldown")
end)

-- ---------------------------------------------------------------------------
-- Cooldown application (modules/MacroBarButton.lua — secret-value safe)
-- ---------------------------------------------------------------------------

local function fakeCooldownFrame()
    local cd = {}
    function cd:SetCooldown(s, d) self.start, self.duration = s, d end
    function cd:SetCooldownFromDurationObject(obj) self.durationObject = obj end
    function cd:Clear() self.cleared = true end
    return cd
end

test("macrobar cooldowns: an active cooldown paints from the duration object", function(t)
    local KCM = h.loader.loadFullAddon()
    local obj = h.loader.mock.makeDuration(100, 300)
    local cd  = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, true, obj, 100, 300)
    t.eq(cd.durationObject, obj, "the object setter wins over the raw-number one")
    t.falsy(cd.duration, "so SetCooldown is never reached")
    t.falsy(cd.cleared, "and the swipe is not cleared")
end)

test("macrobar cooldowns: an inactive cooldown clears the swipe", function(t)
    local KCM = h.loader.loadFullAddon()
    local cd  = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, false, h.loader.mock.makeDuration(0, 0), 0, 0)
    t.truthy(cd.cleared, "nothing running means an empty frame")
    t.falsy(cd.durationObject, "and no setter is called at all")
end)

test("macrobar cooldowns: a client without duration objects falls back to numbers", function(t)
    local KCM = h.loader.loadFullAddon()
    local cd  = fakeCooldownFrame()
    cd.SetCooldownFromDurationObject = nil
    KCM.MacroBarButton.ApplyCooldown(cd, true, h.loader.mock.makeDuration(100, 300), 100, 300)
    t.eq(cd.start, 100, "the raw pair drives the swipe instead")
    t.eq(cd.duration, 300, "duration too")
end)

test("macrobar cooldowns: restricted cooldowns are never compared or set as numbers", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    -- The shipped crash: mid-fight C_Spell.GetSpellCooldown returns SECRET
    -- numbers, so `duration > 0` errored — and once that was removed, so did
    -- SetCooldown, which refuses a secret from a tainted caller.
    mock.setSpell(999, { name = "Recuperate", known = true })
    mock.setCooldown(KCM.ID.AsSpell(999), 50, 120)
    KCM.db.profile.macroState["KCM_HS"] = { lastItemID = KCM.ID.AsSpell(999) }
    mock.setCooldownsRestricted(true)

    local btn = { catKey = "HS", cooldown = fakeCooldownFrame() }
    local ok, err = pcall(KCM.MacroBarButton.RefreshCooldown, btn)
    mock.setCooldownsRestricted(false)

    t.truthy(ok, "the in-combat refresh tick does not error: " .. tostring(err))
    t.truthy(btn.cooldown.durationObject, "the swipe still runs, via the duration object")
    t.falsy(btn.cooldown.duration, "and no secret number is handed to SetCooldown")
end)

test("macrobar cooldowns: a restricted spell still reports whether it is running", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    mock.setSpell(999, { name = "Recuperate", known = true })
    mock.setCooldown(KCM.ID.AsSpell(999), 50, 120)
    KCM.db.profile.macroState["KCM_HS"] = { lastItemID = KCM.ID.AsSpell(999) }
    mock.setCooldownsRestricted(true)

    local active, obj, start, duration = KCM.MacroDisplay.Cooldown("KCM_HS")
    mock.setCooldownsRestricted(false)

    t.eq(active, true, "isActive is NeverSecret, so it survives the restriction")
    t.truthy(obj, "and a duration object is still available")
    t.falsy(start, "but the secret start is withheld from callers")
    t.falsy(duration, "and so is the secret duration")
end)

-- ---------------------------------------------------------------------------
-- Schema rows (settings/MacroBar.lua — needs the full addon load)
-- ---------------------------------------------------------------------------

test("macrobar schema: every macroBar row validates and resolves against the db", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    t.eq(H.ValidateSchema(), 0, "no schema errors")
    local rows = 0
    for _, def in ipairs(KCM.Settings.Schema) do
        if def.path:match("^macroBar%.") then
            rows = rows + 1
            t.ne(H.Get(def.path), nil, def.path .. " resolves in db.profile")
            t.ne(def.default, nil, def.path .. " has a default sourced from dbDefaults")
        end
    end
    t.truthy(rows >= 20, "the Macro Bar page registered its rows (" .. rows .. ")")
end)

test("macrobar schema: enum rows reject a value outside their list", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.orientation")
    t.truthy(def, "orientation row exists")
    t.eq(H.ValidateSchemaValue(def, "VERTICAL"), "VERTICAL", "listed value accepted")
    t.falsy(H.ValidateSchemaValue(def, "SIDEWAYS"), "unlisted value rejected")
end)

test("macrobar schema: number rows clamp to their declared range", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.buttonSize")
    t.eq(H.ValidateSchemaValue(def, 9999), def.max, "clamped to max")
    t.eq(H.ValidateSchemaValue(def, -5), def.min, "clamped to min")
end)

test("macrobar schema: the default slot order matches the settings tab order", function(t)
    local KCM = h.loader.loadFullAddon()
    -- The bar's default order is the cosmetic panel order. dbDefaults can't
    -- reference KCM.Settings.order (Panel.lua loads much later), so this case is
    -- the drift guard for the duplicated literal.
    local want = {}
    for _, key in ipairs(KCM.Settings.order) do
        if key ~= "general" and key ~= "statpriority" and key ~= "macrobar" then
            want[#want + 1] = key:upper()
        end
    end
    t.eqList(KCM.dbDefaults.profile.macroBar.order, want,
        "macroBar.order mirrors KCM.Settings.order")
end)

test("macrobar schema: border rows are populated from LibSharedMedia", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.buttonBorderStyle")
    t.truthy(def, "button border style row exists")
    t.eq(def.lsm, "border", "declared as an LSM border row so it gets the preview widget")
    -- `values` must stay a FUNCTION: other addons register media after our
    -- schema is declared, so the list has to be re-queried at click time.
    t.eq(type(def.values), "function", "values is lazily evaluated")
    local names = {}
    for _, item in ipairs(H.EnumValues(def)) do names[#names + 1] = item.value end
    t.contains(names, "Blizzard Tooltip", "LSM's own borders are offered")
    t.eq(H.ValidateSchemaValue(def, "Blizzard Tooltip"), "Blizzard Tooltip", "registered border accepted")
    t.falsy(H.ValidateSchemaValue(def, "Not A Border"), "unregistered border rejected")
end)

test("macrobar schema: LSMValues never hands back an empty list", function(t)
    local KCM = h.loader.loadFullAddon()
    local out = KCM.Settings.Helpers.LSMValues("nosuchmediatype")
    t.eq(#out, 1, "one placeholder row")
    t.eq(out[1].value, "None", "placeholder is None")
end)

-- ---------------------------------------------------------------------------
-- Flyout candidate list (modules/MacroBarFlyout.lua — cap + invert)
-- ---------------------------------------------------------------------------

test("macrobar flyout: candidates come back in rank order, best first", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    for i = 1, 3 do mock.setBag(seed[i], 1) end
    local out = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12 })
    t.eq(#out, 3, "all three owned entries")
    t.eq(out[1], KCM.Selector.PickBestForCategory("HP_POT"),
        "entry 1 is the macro's pick, so it renders closest to the button")
end)

test("macrobar flyout: invert reverses the order without dropping anything", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    for i = 1, 3 do mock.setBag(seed[i], 1) end
    local normal   = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12 })
    local inverted = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12, flyoutInvert = true })
    t.eq(#inverted, #normal, "same number of entries")
    t.eq(inverted[1], normal[#normal], "first becomes last")
    t.eq(inverted[#inverted], normal[1], "and last becomes first")
end)

test("macrobar flyout: the list is capped to flyoutMax, keeping the top ranks", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    -- Own every seeded potion, whatever the seed's length happens to be.
    for _, id in ipairs(KCM.SEED.HP_POT) do mock.setBag(id, 1) end
    local full   = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12 })
    local capped = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 2 })
    t.truthy(#full > 2, "more owned than the cap under test")
    t.eq(#capped, 2, "capped to flyoutMax")
    t.eq(capped[1], full[1], "keeps the top-ranked entry")
    t.eq(capped[2], full[2], "and the runner-up")
end)

test("macrobar flyout: the cap is bounded by the pool ceiling, not just the setting", function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.MacroBarFlyout.MAX_ENTRIES >= 1, "a hard ceiling exists")
    -- The pool can only grow out of combat, so flyoutMax must never exceed it.
    local def = KCM.Settings.Helpers.FindSchema("macroBar.flyoutMax")
    t.truthy(def.max <= KCM.MacroBarFlyout.MAX_ENTRIES,
        "the slider cannot ask for more entries than the pool allows")
end)

test("macrobar flyout: it ships on, opening upward, closing after 3s", function(t)
    local KCM = h.loader.loadPure()
    local d = KCM.dbDefaults.profile.macroBar
    t.eq(d.flyout, true, "flyout enabled by default")
    t.eq(d.flyoutPoint, "TOP", "opens to the top by default")
    t.eq(d.flyoutInvert, false, "best-first by default")
    t.eq(d.labelText, "SHORT", "labels use the category short form by default")
    t.eq(d.labelScale, 25, "label text is a quarter of the button")
    t.eq(d.flyoutAutoClose, 1, "idles closed after a second")
    t.eq(d.flyoutIndicatorScale, 33, "band is a third of the icon")
    t.eq(d.flyoutBackdrop, true, "the strip gets a panel so it can't be mistaken for more bar")
    t.eq(d.flyoutShadeColor[4], 0.8, "the band is mostly opaque so the arrow reads clearly")
    t.eq(d.flyoutArrowScale, 100, "and the arrow fills the band")
end)

test("macrobar flyout: auto-close is configurable and 0 means never", function(t)
    local KCM = h.loader.loadFullAddon()
    local def = KCM.Settings.Helpers.FindSchema("macroBar.flyoutAutoClose")
    t.truthy(def, "auto-close is a schema row, so /cm set reaches it")
    t.eq(def.type, "number", "seconds")
    t.eq(def.min, 0, "0 is allowed, and means never auto-close")
    t.truthy(def.max >= 3, "and the default sits inside the range")
end)

test("macrobar flyout: Create wires the secure frames without erroring", function(t)
    local KCM = h.loader.loadFullAddon()
    -- Regression guard for two shipped crashes, both "attempt to call a nil
    -- value" on a frame whose template didn't grant the method: SetFrameRef on a
    -- plain SecureActionButton, and again on a container whose secure template
    -- was combined with BackdropTemplate (which dropped the injection). The mock
    -- now withholds template-gated methods, so this case fails if either returns.
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "FOOD"
    local flyout = KCM.MacroBarFlyout.Create(button, "FOOD", 1)
    t.truthy(flyout, "Create returns the container")
    t.truthy(flyout.SetFrameRef, "the container is a secure handler")
    t.truthy(flyout.bg and flyout.bg.SetBackdrop,
        "and its panel is a separate BackdropTemplate child, not the handler itself")
end)

test("macrobar flyout: ApplyBackdrop paints the panel child, not the container", function(t)
    local KCM = h.loader.loadFullAddon()
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "FOOD"
    local flyout = KCM.MacroBarFlyout.Create(button, "FOOD", 1)
    -- The container has no SetBackdrop at all, so painting it would error.
    t.falsy(flyout.SetBackdrop, "container cannot take a backdrop")
    KCM.MacroBarFlyout.ApplyBackdrop(flyout, KCM.db.profile.macroBar)
    t.truthy(true, "ApplyBackdrop completes against the child")
end)

test("macrobar flyout: leaving hands off to the countdown, and says so securely", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    for _, id in ipairs(seed) do mock.setBag(id, 1) end

    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "HP_POT"
    local flyout = KCM.MacroBarFlyout.Create(button, "HP_POT", 1)

    -- The _onleave snippet cannot call InCombatLockdown, so the Lua side has to
    -- put the delay where the snippet can read it. Without kcmGrace the snippet
    -- closes on leave and the auto-close setting has no observable effect at all.
    KCM.db.profile.macroBar.flyoutAutoClose = 2
    KCM.MacroBarFlyout.Apply(button, KCM.db.profile.macroBar)
    t.eq(flyout:GetAttribute("kcmGrace"), 2, "the grace period reaches the snippet")

    KCM.db.profile.macroBar.flyoutAutoClose = 0
    KCM.MacroBarFlyout.Apply(button, KCM.db.profile.macroBar)
    t.eq(flyout:GetAttribute("kcmGrace"), 0, "zero means the snippet closes on leave")
end)

test("macrobar flyout: combat state is driven into the snippet, not polled", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "FOOD"
    local flyout = KCM.MacroBarFlyout.Create(button, "FOOD", 1)

    -- In combat the insecure idle poll can't hide anything, so the snippet must
    -- close on leave instead of waiting for a countdown that will never fire.
    -- It learns the combat state from an attribute driver.
    local drivers = mock.attributeDrivers[flyout] or {}
    t.truthy(drivers.kcmCombat, "an attribute driver feeds kcmCombat")
    t.truthy(tostring(drivers.kcmCombat):find("combat", 1, true),
        "and it is driven off the [combat] conditional")
end)

test("macrobar flyout: the idle clock resets while the mouse is on the strip", function(t)
    local KCM  = h.loader.loadFullAddon()
    h.loader.mock.setCombat(false)
    local hidden, hovered = false, true
    local flyout = {
        IsMouseOver = function() return hovered end,
        Hide        = function() hidden = true end,
    }
    -- flyoutAutoClose measures time spent OFF the flyout, so hovering must keep
    -- resetting it however long the flyout has been open.
    for _ = 1, 20 do KCM.MacroBarFlyout.IdleTick(flyout, 0.5, 1) end
    t.falsy(hidden, "never closes while hovered")
    t.eq(flyout.awayFor, 0, "and the clock stays at zero")

    hovered = false
    t.falsy(KCM.MacroBarFlyout.IdleTick(flyout, 0.4, 1), "0.4s away is not yet idle enough")
    t.truthy(KCM.MacroBarFlyout.IdleTick(flyout, 0.7, 1), "1.1s away closes it")
    t.truthy(hidden, "and the strip is hidden")
end)

test("macrobar flyout: hovering the band alone also holds the flyout open", function(t)
    local KCM = h.loader.loadFullAddon()
    h.loader.mock.setCombat(false)
    -- The band is not a child of the strip, so one IsMouseOver can't see both.
    local hidden = false
    local flyout = {
        IsMouseOver  = function() return false end,
        Hide         = function() hidden = true end,
        kcmIndicator = { IsMouseOver = function() return true end },
    }
    KCM.MacroBarFlyout.IdleTick(flyout, 5, 1)
    t.falsy(hidden, "still open while the band is hovered")
end)

test("macrobar flyout: the idle clock stands down in combat", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local hidden = false
    local flyout = { IsMouseOver = function() return false end,
                     Hide = function() hidden = true end }
    mock.setCombat(true)
    KCM.MacroBarFlyout.IdleTick(flyout, 5, 1)
    t.falsy(hidden, "no hide attempted mid-fight")
    mock.setCombat(false)
    KCM.MacroBarFlyout.IdleTick(flyout, 5, 1)
    t.truthy(hidden, "closes once combat ends")
end)

test("macrobar flyout: an auto-close of 0 never closes on idle", function(t)
    local KCM = h.loader.loadFullAddon()
    h.loader.mock.setCombat(false)
    local hidden = false
    local flyout = { IsMouseOver = function() return false end,
                     Hide = function() hidden = true end }
    KCM.MacroBarFlyout.IdleTick(flyout, 999, 0)
    t.falsy(hidden, "0 means stay open until hover-out or a click")
end)

test("macrobar flyout: Close hides the strip and stands down in combat", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local hidden = false
    local flyout = { Hide = function() hidden = true end }

    -- Close is what the PostClick hooks on the slot and on every entry call.
    -- It is ordinary insecure Lua, so mid-fight it declines rather than
    -- attempting a hide the client may refuse; the secure _onleave covers that
    -- case the moment the cursor moves.
    mock.setCombat(true)
    KCM.MacroBarFlyout.Close(flyout)
    t.falsy(hidden, "no hide attempted in combat")

    mock.setCombat(false)
    KCM.MacroBarFlyout.Close(flyout)
    t.truthy(hidden, "closes out of combat")
end)

test("macrobar flyout: Close tolerates a nil flyout", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.MacroBarFlyout.Close(nil)
    t.truthy(true, "no error")
end)

test("macrobar schema: the bar publishes its own bus message", function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.MSG.MACROBAR_REFRESH, "MACROBAR_REFRESH is in the catalog")
    t.truthy(KCM._macroBarBusTarget, "the bar registered a receiver on its own target")
end)
