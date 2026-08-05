-- defaults/Profile.lua — KCM.dbDefaults, the AceDB defaults tree.
--
-- THE declaration site for every shipped default value (savedvariables-§2). A
-- default restated anywhere else — a schema row's `default`, a settings page's
-- fallback, a migration's seed — is a second copy that drifts, so every one of
-- those reads through KCM.dbDefaults instead. `tests/test_schema.lua` pins that
-- rule for the schema rows.
--
-- Loaded FIRST in the TOC's `# Defaults` block, which puts it in exactly the
-- position it occupied when it lived at the top of core/ConsumableMaster.lua:
-- after the whole `# Core` block, before defaults/Categories.lua. That matters
-- for one literal — see `perRow` below.
--
-- What is NOT here: defaults/Categories.lua (the category REGISTRY — keys,
-- labels, macro names, the `targeted` flag) and the fifteen defaults/Defaults_*
-- files (the shipped item/spell seed lists). Those describe what the addon
-- knows about the game; this file describes what a fresh profile looks like.

local _, NS = ...
local KCM = NS

KCM.dbDefaults = {
    -- Schema shape is account-wide, so its version lives in `global`, not
    -- `profile` (savedvariables-§1). Database.RunMigrations reads it.
    global = {
        -- Deliberately the ORIGINAL version, not Database.CURRENT_SCHEMA (which
        -- isn't loaded yet anyway): an account with no stored version is treated
        -- as pre-migration, and RunMigrations walks it forward. Every step is
        -- idempotent, so a genuinely fresh account passing through them is a
        -- no-op that just stamps the current version.
        schemaVersion = 1,
    },
    profile = {
        enabled = true,    -- master enable; when false the recompute pipeline early-returns
        -- NB: the debug flag is session-only (KCM.State.debug), never persisted.
        categories = {
            FOOD      = { added = {}, blocked = {}, pins = {}, discovered = {} },
            DRINK     = { added = {}, blocked = {}, pins = {}, discovered = {} },
            HP_POT    = { added = {}, blocked = {}, pins = {}, discovered = {} },
            MP_POT    = { added = {}, blocked = {}, pins = {}, discovered = {} },
            HS        = { added = {}, blocked = {}, pins = {}, discovered = {} },
            VANTUS    = { added = {}, blocked = {}, pins = {}, discovered = {} },
            AUG_RUNE  = { added = {}, blocked = {}, pins = {}, discovered = {} },
            BLOODLUST  = { added = {}, blocked = {}, pins = {}, discovered = {} },
            -- `mouseover` drives the targeting clause MacroManager splices into
            -- the body; see defaults/Categories.lua's `targeted` field.
            BATTLE_REZ = { added = {}, blocked = {}, pins = {}, discovered = {}, mouseover = true },
            STAT_FOOD = { bySpec = {} },
            CMBT_POT  = { bySpec = {} },
            FLASK     = { bySpec = {} },
            WPN_ENCH  = { bySpec = {} },
            -- Composite categories. No item buckets (added/blocked/pins/
            -- discovered) — picks come from the underlying single categories
            -- at recompute time. `enabled[ref]` toggles a sub-category in/out
            -- of the macro body; `orderInCombat` / `orderOutOfCombat` are the
            -- sub-category refs in the order they appear in the macro body
            -- (also drives the row order in the panel). Sub-categories are
            -- locked to their section: HS+HP_POT/MP_POT only ever go into
            -- inCombat, FOOD/DRINK only ever go into outOfCombat.
            HP_AIO    = {
                enabled = { HS = true, HP_POT = true, FOOD = true },
                orderInCombat = { "HS", "HP_POT" },
                orderOutOfCombat = { "FOOD" },
            },
            MP_AIO    = {
                enabled = { MP_POT = true, DRINK = true },
                orderInCombat = { "MP_POT" },
                orderOutOfCombat = { "DRINK" },
            },
        },
        statPriority = {}, -- [specKey] = { primary = "AGI", secondary = {...} }  -- user overrides only
        macroState = {},
        -- The CM-only macro bar (modules/MacroBar.lua). On and UNLOCKED out of
        -- the box so the feature is discoverable — a bar the user never sees is
        -- a bar they never configure, and unlocked means the drag handle is
        -- right there to place it. Turning it off tears the frames down (they
        -- are never created again until re-enabled), so opting out costs
        -- nothing. Existing profiles get the same treatment once, via the
        -- schema-v2 step in core/Database.lua.
        --
        -- Every scalar here has a matching KCM.Settings.Schema row, which is
        -- what gives it a widget on the Macro Bar tab AND
        -- `/cm get|set macroBar.<field>` for free.
        macroBar = {
            enabled  = true,
            locked   = false,
            -- Anchor is always relative to UIParent; the bar persists its own
            -- point after a drag (MacroBar.savePosition).
            point    = "CENTER",
            relPoint = "CENTER",
            x        = 0,
            y        = 0,          -- dead center of the screen
            scale    = 1.0,
            alpha    = 1.0,
            -- Grid. `perRow` counts buttons along the axis `orientation` fills
            -- first (row for HORIZONTAL, column for VERTICAL); 15 = one row of
            -- every managed macro. This CANNOT be `#KCM.Categories.LIST`: this
            -- file loads immediately before defaults/Categories.lua in
            -- ConsumableMaster.toc, so that table doesn't exist yet when this
            -- literal is evaluated. Must be kept equal to the category count by
            -- hand; the drift test in tests/test_macrobar.lua enforces it.
            buttonSize  = 36,
            spacing     = 4,
            padding     = 4,
            perRow      = 15,
            orientation = "HORIZONTAL",   -- HORIZONTAL | VERTICAL
            growthH     = "RIGHT",        -- RIGHT | LEFT
            growthV     = "DOWN",         -- DOWN | UP
            -- Chrome. Border styles are LibSharedMedia "border" names, drawn as
            -- the edgeFile of a BackdropTemplate; `buttonBorderOffset` pushes
            -- the button's edge slices outward so they don't bleed over the
            -- icon (the old fixed action-button slot art always did).
            barBackdrop         = true,
            barBackdropColor    = { 0, 0, 0, 0.5 },
            barBorder           = true,
            barBorderStyle      = "Blizzard Tooltip",
            barBorderSize       = 4,
            barBorderColor      = { 0.25, 0.25, 0.25, 1 },
            buttonBackdrop      = true,
            buttonBackdropColor = { 0, 0, 0, 0.6 },
            buttonBorder        = true,
            buttonBorderStyle   = "Blizzard Tooltip",
            buttonBorderSize    = 4,
            buttonBorderOffset  = 2,
            buttonBorderColor   = { 1, 1, 1, 1 },
            iconZoom            = 8,     -- % crop per side; trims the icon's own dark edge
            showCount           = true,
            tooltips            = true,
            -- OFF suppresses the ~1.5s global-cooldown swipe on every button
            -- (default OFF, i.e. suppression is ON out of the box). A REAL
            -- cooldown's swipe is unaffected either way. See
            -- modules/MacroBarButton.lua's GCD-suppress curve.
            showGCD             = false,
            -- Per-button labels. On by default, tucked just under the bottom
            -- edge so they never fight the icon or the flyout band on top, and
            -- using each category's shortName (defaults/Categories.lua) so a
            -- 13-slot bar stays readable without per-label measuring.
            buttonLabel    = true,
            labelText      = "SHORT",           -- AUTO | FULL | SHORT
            labelPoint     = "BOTTOM_CENTER",   -- 9-way grid; see MacroBarLayout.LABEL_POINTS
            labelPlacement = "OUTSIDE",         -- INSIDE | OUTSIDE
            labelScale     = 25,                -- % of button size, clamped to 6-24pt
            labelOffsetX   = 0,
            labelOffsetY   = 3,                 -- positive nudges it back up over the edge
            labelOutline   = true,
            labelColor     = { 1, 0.82, 0, 1 },
            -- Hover flyout (modules/MacroBarFlyout.lua). On by default.
            -- `flyoutPoint` sets BOTH the indicator's edge and the direction the
            -- flyout grows; entry 1 (the top-ranked candidate) always sits
            -- closest to the button unless `flyoutInvert` reverses the list.
            -- `flyoutMax` is capped again by MacroBarFlyout.MAX_ENTRIES, since
            -- the button pool can only grow out of combat.
            flyout              = true,
            flyoutPoint         = "TOP",   -- TOP | BOTTOM | LEFT | RIGHT
            flyoutInvert        = false,
            flyoutMax           = 12,
            flyoutSpacing       = 2,
            flyoutPadding       = 3,       -- inset around the strip, inside its backdrop
            flyoutBackdrop      = true,
            flyoutBackdropColor = { 0, 0, 0, 0.85 },
            -- Gap between the button and the first entry, so a thick or offset
            -- button border can't overlap it. Lives inside the flyout's own
            -- (mouse-enabled) frame, so it is not dead space for the hover.
            flyoutGap           = 4,
            flyoutScale         = 100,     -- % of buttonSize
            -- The indicator is a shaded band INSIDE the icon along `flyoutPoint`'s
            -- edge, carrying a small arrow. Thickness is clamped to half the
            -- button so it can never swallow the artwork.
            -- Band thickness is a PERCENTAGE of the button, so it keeps its
            -- proportions when the bar is resized (capped at half the icon).
            flyoutIndicatorScale = 33,
            flyoutShadeColor    = { 0, 0, 0, 0.8 },
            flyoutArrowScale    = 100,     -- arrow size as % of band thickness
            -- Seconds of no interaction before an open flyout closes itself.
            -- 0 = never (hover-out and clicking still close it).
            flyoutAutoClose     = 1,
            -- Visibility. combatMode is handed to a secure state driver so it
            -- works mid-combat; fadeUnlessHover is a plain alpha fade.
            combatMode      = "ALWAYS",   -- ALWAYS | HIDE_IN_COMBAT | ONLY_IN_COMBAT
            fadeUnlessHover = false,
            fadeAlpha       = 0.15,
            -- Slot order. Mirrors the cosmetic settings-tab order in
            -- KCM.Settings.order (settings/Panel.lua) — which can't be
            -- referenced from here because Panel.lua loads much later — so
            -- tests/test_macrobar.lua asserts the two never drift.
            order = {
                "FOOD", "DRINK", "HP_POT", "MP_POT", "HS",
                "HP_AIO", "MP_AIO",
                "FLASK", "CMBT_POT", "STAT_FOOD", "WPN_ENCH", "AUG_RUNE", "VANTUS",
                "BLOODLUST", "BATTLE_REZ",
            },
            -- [catKey] = false hides that slot. Unset means visible, so a
            -- category shipped after the profile was written appears by default.
            shown = {},
        },
    },
}
