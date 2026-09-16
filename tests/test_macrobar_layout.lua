-- tests/test_macrobar_layout.lua — the macro bar's pure geometry:
-- core/MacroBarLayout.lua's grid, label anchoring and sizing, flyout placement,
-- and the label's clearance around the flyout indicator.
--
-- Peeled out of tests/test_macrobar.lua at the seam issue #32 named, which the
-- cap census in docs/ARCHITECTURE.md carried: four sections that load only the
-- pure layer and call a resolver on a config table. Nothing here builds a frame,
-- so nothing here can need one. The rest of the macro bar's coverage stays in
-- tests/test_macrobar.lua (model, display, cooldowns, schema rows, the flyout's
-- candidate list, master controls) and in tests/test_macrobar_button.lua (the
-- chrome appliers and the flyout's bind/apply pass).
--
-- Every case moved whole: not one assertion changed in the peel.

local h = _G.KCM_TEST
local test = h.test

-- `fcfg` is shared rather than copied — tests/macrobar_support.lua says why.
local fcfg = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua").fcfg

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
    -- This exercises MacroBarLayout.lua's OWN `perRow = ... or N` fallback
    -- (the `perRow` clamp inside `normalize`), kept in step with the category count by
    -- the "macrobar defaults: perRow tracks the number of managed
    -- categories" case below. 2 slots stay on one row under any fallback
    -- value that has ever shipped, so this assertion doesn't move.
    t.eq(g.rows, 1, "2 slots stay on one row under the fallback perRow")
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
    local point, relPoint, dx, dy, rotation, bandW, bandH, glyph =
        KCM.MacroBarLayout.IndicatorAnchor(fcfg())
    -- Same point on both sides = flush inside that edge, not hanging off it.
    t.eq(point, "TOP", "band's top...")
    t.eq(relPoint, "TOP", "...on the button's top, so it overlays the artwork")
    t.eq(dx, 0, "no horizontal offset")
    t.eq(dy, 0, "no vertical offset")
    -- The source texture points RIGHT at rest, so "up" is a quarter turn.
    t.near(rotation, math.pi / 2, 1e-9, "arrow rotated to point up")
    t.eq(bandW, 40, "spans the button's width")
    t.eq(bandH, 8, "as thick as configured")
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
    local point, relPoint, dx, dy, _, bandW, bandH =
        KCM.MacroBarLayout.IndicatorAnchor(fcfg{ flyoutPoint = "LEFT" })
    t.eq(point, "LEFT", "band's left...")
    t.eq(relPoint, "LEFT", "...on the button's left")
    t.eq(dx, 0, "no horizontal offset")
    t.eq(dy, 0, "no vertical offset")
    t.eq(bandW, 8, "thickness on the x axis now")
    t.eq(bandH, 40, "spans the button's height")
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
    local labelCfg = { flyout = true, buttonSize = 40, flyoutIndicatorScale = 20,
                       labelPlacement = "INSIDE" }
    labelCfg.flyoutPoint, labelCfg.labelPoint = "BOTTOM", "BOTTOM_CENTER"
    local _, _, _, down = KCM.MacroBarLayout.LabelAnchor(labelCfg)
    t.eq(down, 9, "a bottom label is pushed up")
    labelCfg.flyoutPoint, labelCfg.labelPoint = "LEFT", "LEFT"
    local _, _, left = KCM.MacroBarLayout.LabelAnchor(labelCfg)
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
