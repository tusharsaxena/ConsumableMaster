-- core/MacroBarLayout.lua — pure grid math for the macro bar.
--
-- No frames, no globals, no db reads: given a slot count and a layout config
-- it returns each slot's offset from the container's TOPLEFT plus the
-- container's size. modules/MacroBar.lua feeds the result straight into
-- SetPoint/SetSize, which keeps every "why is my bar the wrong shape" question
-- answerable headlessly (tests/test_macrobar.lua).
--
-- Coordinate space matches WoW's: x grows right, y grows DOWN as a negative
-- offset, so a slot is anchored `SetPoint("TOPLEFT", bar, "TOPLEFT", x, y)`.
--
-- `orientation` decides which axis fills first and what `perRow` counts:
--   HORIZONTAL — perRow is buttons per ROW; slot order runs across a row,
--                then wraps to the next row.
--   VERTICAL   — perRow is buttons per COLUMN; slot order runs down a column,
--                then wraps to the next column.
-- `growthH` / `growthV` then mirror the grid so the bar grows away from its
-- anchor in the requested direction (RIGHT/LEFT, DOWN/UP).

local _, NS = ...
local KCM = NS
KCM.MacroBarLayout = KCM.MacroBarLayout or {}
local BL = KCM.MacroBarLayout

local floor, ceil, max = math.floor, math.ceil, math.max

BL.ORIENTATIONS = { "HORIZONTAL", "VERTICAL" }
BL.GROWTH_H     = { "RIGHT", "LEFT" }
BL.GROWTH_V     = { "DOWN", "UP" }

-- Fill in anything the caller left out so the layout never divides by nil.
-- Mirrors the dbDefaults.profile.macroBar values; the panel clamps to the same
-- ranges via its schema rows.
local function normalize(cfg)
    cfg = cfg or {}
    return {
        buttonSize  = max(1, tonumber(cfg.buttonSize) or 36),
        spacing     = max(0, tonumber(cfg.spacing) or 4),
        padding     = max(0, tonumber(cfg.padding) or 4),
        perRow      = max(1, floor(tonumber(cfg.perRow) or 13)),
        orientation = cfg.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL",
        growthH     = cfg.growthH == "LEFT" and "LEFT" or "RIGHT",
        growthV     = cfg.growthV == "UP"   and "UP"   or "DOWN",
    }
end
BL._normalize = normalize   -- test seam

-- Grid dimensions for `count` slots. The wrap axis is whichever one
-- `orientation` names; the other grows without limit.
function BL.Dimensions(count, cfg)
    local c = normalize(cfg)
    count = max(0, floor(tonumber(count) or 0))
    if count == 0 then return 0, 0 end
    local along = c.perRow < count and c.perRow or count
    local across = ceil(count / c.perRow)
    if c.orientation == "VERTICAL" then
        return across, along          -- cols, rows
    end
    return along, across              -- cols, rows
end

-- Full layout for `count` slots:
--   positions — array of { x = , y = } TOPLEFT offsets, one per slot index
--   width / height — container size including padding on all four sides
--   cols / rows    — grid dimensions
-- A zero count still reports a 1x1-cell container so the frame never gets a
-- zero dimension (WoW warns on SetSize(0, 0)).
function BL.Grid(count, cfg)
    local c = normalize(cfg)
    count = max(0, floor(tonumber(count) or 0))
    local cols, rows = BL.Dimensions(count, cfg)
    local step = c.buttonSize + c.spacing

    local positions = {}
    for i = 1, count do
        local row, col
        if c.orientation == "VERTICAL" then
            col = floor((i - 1) / c.perRow)
            row = (i - 1) % c.perRow
        else
            row = floor((i - 1) / c.perRow)
            col = (i - 1) % c.perRow
        end
        if c.growthH == "LEFT" then col = cols - 1 - col end
        if c.growthV == "UP"   then row = rows - 1 - row end
        positions[i] = {
            x =  c.padding + col * step,
            y = -(c.padding + row * step),
        }
    end

    local vcols, vrows = max(1, cols), max(1, rows)
    return {
        positions = positions,
        cols      = cols,
        rows      = rows,
        width     = c.padding * 2 + vcols * c.buttonSize + (vcols - 1) * c.spacing,
        height    = c.padding * 2 + vrows * c.buttonSize + (vrows - 1) * c.spacing,
    }
end

-- ---------------------------------------------------------------------------
-- Button labels
-- ---------------------------------------------------------------------------

BL.LABEL_POINTS = {
    "TOP_LEFT", "TOP_CENTER", "TOP_RIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOM_LEFT", "BOTTOM_CENTER", "BOTTOM_RIGHT",
}

-- point / relPoint pairs per label position. INSIDE anchors the label's own
-- corner to the matching corner of the button; OUTSIDE flips the label's anchor
-- across that edge so it sits just beyond the button.
local LABEL_ANCHORS = {
    TOP_LEFT      = { inside = { "TOPLEFT",     "TOPLEFT"     }, outside = { "BOTTOMLEFT",  "TOPLEFT"     }, justify = "LEFT"   },
    TOP_CENTER    = { inside = { "TOP",         "TOP"         }, outside = { "BOTTOM",      "TOP"         }, justify = "CENTER" },
    TOP_RIGHT     = { inside = { "TOPRIGHT",    "TOPRIGHT"    }, outside = { "BOTTOMRIGHT", "TOPRIGHT"    }, justify = "RIGHT"  },
    LEFT          = { inside = { "LEFT",        "LEFT"        }, outside = { "RIGHT",       "LEFT"        }, justify = "LEFT"   },
    CENTER        = { inside = { "CENTER",      "CENTER"      }, outside = { "CENTER",      "CENTER"      }, justify = "CENTER" },
    RIGHT         = { inside = { "RIGHT",       "RIGHT"       }, outside = { "LEFT",        "RIGHT"       }, justify = "RIGHT"  },
    BOTTOM_LEFT   = { inside = { "BOTTOMLEFT",  "BOTTOMLEFT"  }, outside = { "TOPLEFT",     "BOTTOMLEFT"  }, justify = "LEFT"   },
    BOTTOM_CENTER = { inside = { "BOTTOM",      "BOTTOM"      }, outside = { "TOP",         "BOTTOM"      }, justify = "CENTER" },
    BOTTOM_RIGHT  = { inside = { "BOTTOMRIGHT", "BOTTOMRIGHT" }, outside = { "TOPRIGHT",    "BOTTOMRIGHT" }, justify = "RIGHT"  },
}

-- Which button edge a label position sits on ("TOP" / "BOTTOM" / "LEFT" /
-- "RIGHT"), or nil for the ones that touch no edge.
local LABEL_EDGE = {
    TOP_LEFT = "TOP", TOP_CENTER = "TOP", TOP_RIGHT = "TOP",
    BOTTOM_LEFT = "BOTTOM", BOTTOM_CENTER = "BOTTOM", BOTTOM_RIGHT = "BOTTOM",
    LEFT = "LEFT", RIGHT = "RIGHT",
}

-- Extra offset that keeps a label clear of the flyout indicator when the two
-- share an edge. The indicator is a shaded band drawn INSIDE that edge of the
-- icon, so the label has to clear its whole thickness (plus a pixel of air).
-- Returns dx, dy — both 0 whenever there's no collision, so this is safe to add
-- unconditionally.
--
-- Automatic rather than a knob: the user can move either the label or the
-- indicator, and the clearance has to hold for every combination.
function BL.IndicatorClearance(cfg)
    cfg = cfg or {}
    if not cfg.flyout then return 0, 0 end
    -- An OUTSIDE label sits past the button edge entirely, so the band can't
    -- reach it; leave that case to the user's own offsets.
    if cfg.labelPlacement == "OUTSIDE" then return 0, 0 end
    local edge = LABEL_EDGE[cfg.labelPoint or "TOP_CENTER"]
    if not edge or edge ~= (cfg.flyoutPoint or "TOP") then return 0, 0 end
    local clear = max(0, tonumber(cfg.flyoutIndicatorSize) or 12) + 1
    if edge == "TOP"    then return 0, -clear end
    if edge == "BOTTOM" then return 0,  clear end
    if edge == "LEFT"   then return  clear, 0 end
    return -clear, 0                              -- RIGHT
end

-- Resolve a label position into everything SetPoint / SetJustifyH need:
--   point, relPoint, x, y, justifyH
-- Unknown positions fall back to TOP_CENTER (the shipped default) rather than
-- erroring, so a hand-edited SavedVariables value can't break the bar. The
-- returned offsets already include indicator clearance.
function BL.LabelAnchor(cfg)
    cfg = cfg or {}
    local a = LABEL_ANCHORS[cfg.labelPoint] or LABEL_ANCHORS.TOP_CENTER
    local pair = (cfg.labelPlacement == "OUTSIDE") and a.outside or a.inside
    local cx, cy = BL.IndicatorClearance(cfg)
    return pair[1], pair[2],
        (tonumber(cfg.labelOffsetX) or 0) + cx,
        (tonumber(cfg.labelOffsetY) or 0) + cy,
        a.justify
end

-- ---------------------------------------------------------------------------
-- Flyout
-- ---------------------------------------------------------------------------

BL.FLYOUT_POINTS = { "TOP", "BOTTOM", "LEFT", "RIGHT" }

-- Per edge: where the flyout container attaches, which way it grows, where the
-- shaded indicator band sits INSIDE the icon, and the arrow rotation (radians)
-- that points it away from the button.
--   anchor  = { container point, button point }   -- container hangs off the edge
--   band    = { band point, button point }        -- band hugs the edge, inside
--   axis    = "V" | "H"          -- which axis the flyout stacks along
--   sign    = +1 | -1            -- direction along that axis, in WoW offsets
--   rotation                     -- arrow texture rotation, CCW radians
--
-- The rotations assume a source texture that points RIGHT in its natural
-- orientation (ChatFrameExpandArrow does). If the arrow texture is ever swapped
-- for one with a different rest orientation, THIS TABLE is the thing to fix —
-- getting it wrong shows up as an up-arrow that points sideways.
local FLYOUT_EDGES = {
    TOP    = { anchor = { "BOTTOM", "TOP"    }, band = { "TOP",    "TOP"    }, axis = "V", sign =  1, rotation =  math.pi / 2 },
    BOTTOM = { anchor = { "TOP",    "BOTTOM" }, band = { "BOTTOM", "BOTTOM" }, axis = "V", sign = -1, rotation = -math.pi / 2 },
    LEFT   = { anchor = { "RIGHT",  "LEFT"   }, band = { "LEFT",   "LEFT"   }, axis = "H", sign = -1, rotation =  math.pi },
    RIGHT  = { anchor = { "LEFT",   "RIGHT"  }, band = { "RIGHT",  "RIGHT"  }, axis = "H", sign =  1, rotation =  0 },
}

local function flyoutEdge(cfg)
    return FLYOUT_EDGES[(cfg or {}).flyoutPoint] or FLYOUT_EDGES.TOP
end

-- Indicator geometry: point, relPoint, x, y, rotation, plus the band's width and
-- height and the arrow glyph's square size.
--
-- The band is a shaded strip drawn INSIDE the icon, hugging its chosen edge and
-- spanning that edge fully — part of the icon, not an ornament hanging off it.
-- The arrow is a SQUARE glyph centerd on the band: stretching it to the band's
-- full width is what made the first attempt look smeared.
function BL.IndicatorAnchor(cfg)
    cfg = cfg or {}
    local e = flyoutEdge(cfg)
    local span = max(1, tonumber(cfg.buttonSize) or 36)
    -- Never let the band swallow more than half the icon, however big the
    -- configured thickness or however small the button.
    local thickness = max(2, tonumber(cfg.flyoutIndicatorSize) or 12)
    if thickness > span / 2 then thickness = max(2, floor(span / 2)) end

    local w, h = span, thickness
    if e.axis == "H" then w, h = thickness, span end
    -- Arrow is sized from the band rather than pinned to it, so it can be made
    -- deliberately larger than the band (the default) and read clearly at small
    -- button sizes. Overflowing onto the icon is fine — it draws on OVERLAY.
    local scale = max(25, tonumber(cfg.flyoutArrowScale) or 100)
    local glyph = max(6, floor(thickness * scale / 100 + 0.5))
    return e.band[1], e.band[2], 0, 0, e.rotation, w, h, glyph
end

-- Flyout button positions, as offsets from the FLYOUT CONTAINER's own anchor
-- corner, plus the container's size and where it attaches to the button.
--
-- Entry 1 is always the closest to the button — the top-ranked candidate —
-- unless `flyoutInvert` reverses the caller's list.
--
-- `flyoutGap` separates the first entry from the button so a thick or offset
-- button border can't overlap it. Note WHERE that gap lives: the returned
-- positions are offsets inside the CONTAINER, and the container itself still
-- anchors flush to the button's edge (see MacroBarFlyout.Apply). So the gap is
-- covered by the container's own mouse-enabled area rather than being dead
-- space — which matters, because dead space between the band and the strip
-- would fire the secure `_onleave` mid-journey and close the flyout just as the
-- user reached for it.
function BL.Flyout(count, cfg)
    cfg = cfg or {}
    count = max(0, floor(tonumber(count) or 0))
    local e = flyoutEdge(cfg)
    local size    = max(1, floor((tonumber(cfg.buttonSize) or 36)
        * (tonumber(cfg.flyoutScale) or 100) / 100 + 0.5))
    local spacing = max(0, tonumber(cfg.flyoutSpacing) or 2)
    local lead    = max(0, tonumber(cfg.flyoutGap) or 4)

    local step = size + spacing
    local run  = count > 0 and (count * size + (count - 1) * spacing) or 0

    -- Container anchors its near edge to the button's edge; positions inside it
    -- always run away from that edge, so the maths below is edge-independent.
    local positions = {}
    for i = 1, count do
        local along = lead + (i - 1) * step
        if e.axis == "V" then
            positions[i] = { x = 0, y = e.sign * along }
        else
            positions[i] = { x = e.sign * along, y = 0 }
        end
    end

    local w, h
    if e.axis == "V" then
        w, h = size, lead + run
    else
        w, h = lead + run, size
    end

    return {
        positions = positions,
        size      = size,
        width     = max(1, w),
        height    = max(1, h),
        point     = e.anchor[1],     -- container's own edge...
        relPoint  = e.anchor[2],     -- ...pinned to this edge of the button
        axis      = e.axis,
    }
end

-- Label font size in points, derived from the button size so a label always
-- scales with its button. `labelScale` is a percentage of the button's edge;
-- the result is clamped to a legible range because WoW renders sub-6pt text as
-- an unreadable smudge and anything past 24pt can't fit a 64px button.
function BL.LabelFontSize(buttonSize, labelScale)
    local size = max(1, tonumber(buttonSize) or 36)
    local pct  = tonumber(labelScale) or 26
    local pts  = floor(size * pct / 100 + 0.5)
    if pts < 6  then pts = 6  end
    if pts > 24 then pts = 24 end
    return pts
end
