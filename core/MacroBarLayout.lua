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

-- Resolve a label position into everything SetPoint / SetJustifyH need:
--   point, relPoint, x, y, justifyH
-- Unknown positions fall back to TOP_CENTER (the shipped default) rather than
-- erroring, so a hand-edited SavedVariables value can't break the bar.
function BL.LabelAnchor(cfg)
    cfg = cfg or {}
    local a = LABEL_ANCHORS[cfg.labelPoint] or LABEL_ANCHORS.TOP_CENTER
    local pair = (cfg.labelPlacement == "OUTSIDE") and a.outside or a.inside
    return pair[1], pair[2], tonumber(cfg.labelOffsetX) or 0,
        tonumber(cfg.labelOffsetY) or 0, a.justify
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
