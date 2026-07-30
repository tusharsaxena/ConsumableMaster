-- settings/MacroBar.lua — Macro Bar page.
--
-- Seven sections: Bar (enable / lock / reset), Layout (grid + geometry), Bar
-- appearance and Button appearance (chrome + colors), Labels, Flyout, Visibility
-- (combat driver + hover fade), and Macros (which macros occupy a slot).
--
-- Every scalar is a KCM.Settings.Schema row, so each one is simultaneously a
-- widget here and a `/cm get|set macroBar.<field>` path — one definition, both
-- surfaces. The per-macro checkboxes are the exception: they're a dynamic list
-- keyed by category, so they use the CustomCheckbox escape hatch with a get/set
-- pair onto db.profile.macroBar.shown.
--
-- Slot ORDER is not edited here — it's changed by dragging slots on the bar
-- itself (swap-on-drop). This page only offers "Reset order".

local _, NS = ...
local KCM = NS
local L = KCM.L
local H = KCM.Settings.Helpers

local BAR_DEFAULTS = KCM.dbDefaults and KCM.dbDefaults.profile
    and KCM.dbDefaults.profile.macroBar or {}

-- Re-apply the whole bar after any setting changes. MacroBar.Update is
-- idempotent and self-defers in combat, so every row can share one onChange.
local function applyBar()
    if KCM.MacroBar and KCM.MacroBar.Update then KCM.MacroBar.Update() end
end

-- ---------------------------------------------------------------------------
-- Schema rows
-- ---------------------------------------------------------------------------
-- `row()` appends to KCM.Settings.Schema and hands the def back so the renderer
-- below can place it in a grid without a second FindSchema lookup. Defaults are
-- sourced from dbDefaults, never duplicated as literals (standard §4.5).

local defs = {}

local function row(spec)
    local field = spec.path:match("([^.]+)$")
    spec.panel    = "macrobar"
    spec.section  = "macrobar"
    spec.default  = BAR_DEFAULTS[field]
    spec.onChange = spec.onChange or applyBar
    KCM.Settings.Schema[#KCM.Settings.Schema + 1] = spec
    defs[field] = spec
    return spec
end

local function enum(...)
    local out = {}
    for i = 1, select("#", ...), 2 do
        out[#out + 1] = { value = select(i, ...), text = select(i + 1, ...) }
    end
    return out
end

row{
    path = "macroBar.enabled", type = "bool", group = "Bar",
    label = L["Enable macro bar"],
    tooltip = L["Show a dedicated bar holding your ConsumableMaster macros. Only CM macros can occupy it. On by default; turning it off hides the bar and stops all its work until you turn it back on."],
    onChange = function(v)
        if KCM.MacroBar and KCM.MacroBar.SetEnabled then
            -- SetEnabled re-reads the flag we just wrote; it exists so the
            -- slash path and this row share the in-combat notice.
            KCM.MacroBar.SetEnabled(v)
        end
    end,
}
row{
    path = "macroBar.locked", type = "bool", group = "Bar",
    label = L["Lock position"],
    tooltip = L["When unlocked the bar is tinted gold and can be dragged anywhere on screen; its position is saved automatically. Lock it again to click through the empty space around the buttons."],
}
row{
    path = "macroBar.perRow", type = "number", min = 1, max = 13, step = 1, group = "Layout",
    label = L["Buttons per row"],
    tooltip = L["How many buttons fit along the axis the bar fills first — a row when the orientation is Horizontal, a column when it is Vertical. 13 puts every macro on one line."],
}
row{
    path = "macroBar.buttonSize", type = "number", min = 16, max = 64, step = 1, group = "Layout",
    label = L["Button size"],
    tooltip = L["Width and height of each button, in pixels."],
}
row{
    path = "macroBar.spacing", type = "number", min = 0, max = 24, step = 1, group = "Layout",
    label = L["Button spacing"],
    tooltip = L["Gap between adjacent buttons, in pixels."],
}
row{
    path = "macroBar.padding", type = "number", min = 0, max = 24, step = 1, group = "Layout",
    label = L["Bar padding"],
    tooltip = L["Inset between the outer buttons and the edge of the bar's backdrop, in pixels."],
}
row{
    path = "macroBar.scale", type = "number", min = 0.5, max = 2.0, step = 0.05, group = "Layout",
    label = L["Bar scale"],
    tooltip = L["Scales the whole bar, buttons and backdrop together."],
}
row{
    path = "macroBar.orientation", type = "string", group = "Layout",
    values = enum("HORIZONTAL", L["Horizontal (fill rows)"], "VERTICAL", L["Vertical (fill columns)"]),
    label = L["Orientation"],
    tooltip = L["Which axis the buttons fill first. Horizontal runs along a row then wraps to the next row; Vertical runs down a column then wraps to the next column."],
}
row{
    path = "macroBar.growthH", type = "string", group = "Layout",
    values = enum("RIGHT", L["Right"], "LEFT", L["Left"]),
    label = L["Horizontal growth"],
    tooltip = L["Whether the first button sits at the left or the right edge of the bar."],
}
row{
    path = "macroBar.growthV", type = "string", group = "Layout",
    values = enum("DOWN", L["Down"], "UP", L["Up"]),
    label = L["Vertical growth"],
    tooltip = L["Whether the first row sits at the top or the bottom of the bar."],
}
row{
    path = "macroBar.barBackdrop", type = "bool", group = "Bar appearance",
    label = L["Bar background"],
    tooltip = L["Draw a filled backdrop behind the buttons."],
}
row{
    path = "macroBar.barBackdropColor", type = "color", group = "Bar appearance",
    label = L["Bar background color"],
    tooltip = L["Color and opacity of the bar's backdrop."],
}
row{
    path = "macroBar.barBorder", type = "bool", group = "Bar appearance",
    label = L["Bar border"],
    tooltip = L["Draw a border around the bar."],
}
row{
    path = "macroBar.barBorderStyle", type = "string", lsm = "border", group = "Bar appearance",
    values = function() return H.LSMValues("border") end,
    label = L["Bar border style"],
    tooltip = L["LibSharedMedia border texture used for the bar's edge. Any border another addon registers shows up here too."],
}
row{
    path = "macroBar.barBorderSize", type = "number", min = 1, max = 16, step = 1, group = "Bar appearance",
    label = L["Bar border thickness (px)"],
    tooltip = L["Thickness of the bar border's edge slices, in pixels."],
}
row{
    path = "macroBar.barBorderColor", type = "color", group = "Bar appearance",
    label = L["Bar border color"],
    tooltip = L["Color and opacity of the bar's border."],
}
row{
    path = "macroBar.buttonBackdrop", type = "bool", group = "Button appearance",
    label = L["Button background"],
    tooltip = L["Fill each button behind its icon. Visible mainly while an icon is still loading."],
}
row{
    path = "macroBar.buttonBackdropColor", type = "color", group = "Button appearance",
    label = L["Button background color"],
    tooltip = L["Color and opacity of each button's fill."],
}
row{
    path = "macroBar.buttonBorder", type = "bool", group = "Button appearance",
    label = L["Button border"],
    tooltip = L["Draw a border around each button. Turn off for a flat, borderless grid of icons."],
}
row{
    path = "macroBar.buttonBorderStyle", type = "string", lsm = "border", group = "Button appearance",
    values = function() return H.LSMValues("border") end,
    label = L["Button border style"],
    tooltip = L["LibSharedMedia border texture used for each button's edge. Any border another addon registers shows up here too."],
}
row{
    path = "macroBar.buttonBorderSize", type = "number", min = 1, max = 16, step = 1, group = "Button appearance",
    label = L["Button border thickness (px)"],
    tooltip = L["Thickness of the button border's edge slices, in pixels."],
}
row{
    path = "macroBar.buttonBorderOffset", type = "number", min = 0, max = 16, step = 1, group = "Button appearance",
    label = L["Button border offset (px)"],
    tooltip = L["Pushes the border outward, away from the icon. Raise this if a thick border is bleeding over the artwork; 0 draws it centerd on the button's edge."],
}
row{
    path = "macroBar.buttonBorderColor", type = "color", group = "Button appearance",
    label = L["Button border color"],
    tooltip = L["Tints the button border texture."],
}
row{
    path = "macroBar.iconZoom", type = "number", min = 0, max = 40, step = 1, group = "Button appearance",
    label = L["Icon zoom (%)"],
    tooltip = L["Crops this percentage off each side of the icon. A little zoom trims the dark edge baked into most item icons so it doesn't read as a second border."],
}
row{
    path = "macroBar.showCount", type = "bool", group = "Button appearance",
    label = L["Show stack count"],
    tooltip = L["Show how many of the picked item you're carrying in the bottom-right corner of each button."],
}
row{
    path = "macroBar.tooltips", type = "bool", group = "Button appearance",
    label = L["Show tooltips"],
    tooltip = L["Show the picked item's or spell's tooltip when you hover a button."],
}
row{
    path = "macroBar.alpha", type = "number", min = 0.1, max = 1.0, step = 0.05, group = "Bar appearance",
    label = L["Bar opacity"],
    tooltip = L["Opacity of the whole bar when it is not faded out."],
}
row{
    path = "macroBar.buttonLabel", type = "bool", group = "Labels",
    label = L["Show button labels"],
    tooltip = L["Label each button with its category name. The text scales with the button size."],
}
row{
    path = "macroBar.labelText", type = "string", group = "Labels",
    values = enum(
        "AUTO",  L["Auto (shorten to fit)"],
        "FULL",  L["Always full name"],
        "SHORT", L["Always short name"]),
    label = L["Label text"],
    tooltip = L["Auto uses the full category name and falls back to a short form only when the full one won't fit inside the button."],
}
row{
    path = "macroBar.labelPoint", type = "string", group = "Labels",
    values = enum(
        "TOP_LEFT",      L["Top left"],
        "TOP_CENTER",    L["Top center"],
        "TOP_RIGHT",     L["Top right"],
        "LEFT",          L["Left"],
        "CENTER",        L["Center"],
        "RIGHT",         L["Right"],
        "BOTTOM_LEFT",   L["Bottom left"],
        "BOTTOM_CENTER", L["Bottom center"],
        "BOTTOM_RIGHT",  L["Bottom right"]),
    label = L["Label position"],
    tooltip = L["Which part of the button the label anchors to."],
}
row{
    path = "macroBar.labelPlacement", type = "string", group = "Labels",
    values = enum("INSIDE", L["Inside the button"], "OUTSIDE", L["Outside the button"]),
    label = L["Label placement"],
    tooltip = L["Inside draws the label over the icon; Outside pushes it just beyond that edge of the button. Outside labels can overlap a neighboring button when spacing is tight."],
}
row{
    path = "macroBar.labelScale", type = "number", min = 10, max = 50, step = 1, group = "Labels",
    label = L["Label size (% of button)"],
    tooltip = L["Label font size as a percentage of the button's size, so labels stay proportional when you resize the bar. Clamped to a legible 6-24pt."],
}
row{
    path = "macroBar.labelOffsetX", type = "number", min = -20, max = 20, step = 1, group = "Labels",
    label = L["Label offset X (px)"],
    tooltip = L["Nudge the label horizontally from its anchor."],
}
row{
    path = "macroBar.labelOffsetY", type = "number", min = -20, max = 20, step = 1, group = "Labels",
    label = L["Label offset Y (px)"],
    tooltip = L["Nudge the label vertically from its anchor. Negative moves it down."],
}
row{
    path = "macroBar.labelOutline", type = "bool", group = "Labels",
    label = L["Outline label text"],
    tooltip = L["Draw a black outline around the label so it stays readable over a bright icon."],
}
row{
    path = "macroBar.labelColor", type = "color", group = "Labels",
    label = L["Label color"],
    tooltip = L["Color and opacity of the button labels."],
}
row{
    path = "macroBar.flyout", type = "bool", group = "Flyout",
    label = L["Enable flyout"],
    tooltip = L["Put a small arrow on each button; hovering it opens a strip holding every item or spell in that category you can actually use right now. Only the macro bar has flyouts — a KCM macro dragged onto a Blizzard action bar stays an ordinary macro."],
}
row{
    path = "macroBar.flyoutPoint", type = "string", group = "Flyout",
    values = enum("TOP", L["Top"], "BOTTOM", L["Bottom"], "LEFT", L["Left"], "RIGHT", L["Right"]),
    label = L["Flyout side"],
    tooltip = L["Which edge the arrow sits on, and the direction the flyout grows from there."],
}
row{
    path = "macroBar.flyoutInvert", type = "bool", group = "Flyout",
    label = L["Reverse flyout order"],
    tooltip = L["By default the highest-ranked item sits closest to the button. Turn this on to put it furthest away."],
}
row{
    path = "macroBar.flyoutMax", type = "number", min = 1, max = 16, step = 1, group = "Flyout",
    label = L["Maximum flyout entries"],
    tooltip = L["Longest flyout to build. Categories with more available items than this show the top-ranked ones. The cap exists because flyout buttons can only be created out of combat."],
}
row{
    path = "macroBar.flyoutScale", type = "number", min = 40, max = 150, step = 5, group = "Flyout",
    label = L["Flyout button size (% of button)"],
    tooltip = L["Flyout entry size as a percentage of the main button size."],
}
row{
    path = "macroBar.flyoutSpacing", type = "number", min = 0, max = 16, step = 1, group = "Flyout",
    label = L["Flyout spacing (px)"],
    tooltip = L["Gap between flyout entries, in pixels."],
}
row{
    path = "macroBar.flyoutGap", type = "number", min = 0, max = 20, step = 1, group = "Flyout",
    label = L["Gap from button (px)"],
    tooltip = L["Gap between the macro button and the first flyout entry. Raise it if a thick or offset button border overlaps the flyout. Hovering still works across the gap."],
}
row{
    path = "macroBar.flyoutIndicatorSize", type = "number", min = 4, max = 24, step = 1, group = "Flyout",
    label = L["Shaded band thickness (px)"],
    tooltip = L["How deep the shaded strip across the icon is. Raise it to make an easier hover target; it is capped at half the button, and the button label automatically moves clear when the two share an edge."],
}
row{
    path = "macroBar.flyoutArrowScale", type = "number", min = 25, max = 250, step = 5, group = "Flyout",
    label = L["Arrow size (% of band)"],
    tooltip = L["Arrow size as a percentage of the shaded band's thickness. Over 100% the arrow deliberately overflows the band onto the icon, which keeps it readable on small buttons."],
}
row{
    path = "macroBar.flyoutShadeColor", type = "color", group = "Flyout",
    label = L["Shaded band color"],
    tooltip = L["Color and opacity of the strip drawn across the icon. Lower the opacity to let more of the artwork through."],
}
row{
    path = "macroBar.flyoutAutoClose", type = "number", min = 0, max = 30, step = 0.5, group = "Flyout",
    label = L["Auto-close after (seconds)"],
    tooltip = L["Close an open flyout after this many seconds without interaction. 0 keeps it open until you move the mouse away or click something. Moving the mouse off it, and clicking either the macro or a flyout entry, always close it immediately."],
}
row{
    path = "macroBar.combatMode", type = "string", group = "Visibility",
    values = enum(
        "ALWAYS",          L["Always visible"],
        "HIDE_IN_COMBAT",  L["Hide in combat"],
        "ONLY_IN_COMBAT",  L["Only in combat"]),
    label = L["Combat visibility"],
    tooltip = L["Combat-based hiding is handed to Blizzard's secure visibility driver, so it takes effect the instant combat starts or ends — including mid-fight."],
}
row{
    path = "macroBar.fadeUnlessHover", type = "bool", group = "Visibility",
    label = L["Fade unless hovered"],
    tooltip = L["Keep the bar faded until you move the mouse over it. Faded buttons still work — this only changes opacity."],
}
row{
    path = "macroBar.fadeAlpha", type = "number", min = 0.0, max = 1.0, step = 0.05, group = "Visibility",
    label = L["Faded opacity"],
    tooltip = L["Opacity of the bar while faded out. 0 makes it invisible until hovered."],
}

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

local function doResetPosition()
    if KCM.MacroBar and KCM.MacroBar.ResetPosition then
        KCM.MacroBar.ResetPosition()
        KCM.Say("macro bar position reset.")
    end
end

local function doResetOrder()
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
    if not cfg then return end
    cfg.order = CopyTable(BAR_DEFAULTS.order or {})
    applyBar()
    H.RefreshAllPanels()
    KCM.Say("macro bar slot order reset.")
end

-- Top-right Defaults button (standard §6.5): every macroBar setting back to
-- its shipped value, including position, order and per-macro visibility. Other
-- pages' settings are untouched.
local function doResetPage()
    if not (KCM.db and KCM.db.profile) then return end
    KCM.db.profile.macroBar = CopyTable(BAR_DEFAULTS)
    applyBar()
    H.RefreshAllPanels()
end

-- ---------------------------------------------------------------------------
-- Renderer
-- ---------------------------------------------------------------------------

-- One checkbox per managed macro, in the bar's current slot order so the panel
-- reads the same way the bar looks.
local function macroToggles(ctx)
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
    if not cfg then return end
    local items = {}
    for _, key in ipairs(KCM.MacroBarModel.Order()) do
        local cat = KCM.Categories.Get(key)
        items[#items + 1] = {
            make = function(c, parent, relW)
                H.CustomCheckbox(c, parent, relW, {
                    label   = cat and cat.displayName or key,
                    tooltip = (L["Show %s on the macro bar."]):format(cat and cat.macroName or key),
                    get     = function()
                        cfg.shown = cfg.shown or {}
                        return cfg.shown[key] ~= false
                    end,
                    set     = function(v)
                        cfg.shown = cfg.shown or {}
                        cfg.shown[key] = v and true or false
                        applyBar()
                    end,
                })
            end,
        }
    end
    H.Grid(ctx, items)
end

local function render(ctx)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    H.Section(ctx, L["Bar"])
    H.Grid(ctx, { defs.enabled, defs.locked })
    H.ButtonPair(ctx,
        {
            text    = L["Reset position"],
            tooltip = L["Move the bar back to the middle of the screen."],
            onClick = doResetPosition,
        },
        {
            text    = L["Reset slot order"],
            tooltip = L["Restore the default left-to-right slot order, undoing any drag-and-drop rearranging."],
            onClick = doResetOrder,
        })

    H.Section(ctx, L["Layout"])
    H.Grid(ctx, {
        defs.perRow, defs.buttonSize,
        defs.spacing, defs.padding,
        defs.scale, defs.orientation,
        defs.growthH, defs.growthV,
    })

    H.Section(ctx, L["Bar appearance"])
    H.Grid(ctx, {
        defs.barBackdrop, defs.barBackdropColor,
        defs.barBorder, defs.barBorderColor,
        defs.barBorderStyle, defs.barBorderSize,
        defs.alpha,
    })

    H.Section(ctx, L["Button appearance"])
    H.Grid(ctx, {
        defs.buttonBackdrop, defs.buttonBackdropColor,
        defs.buttonBorder, defs.buttonBorderColor,
        defs.buttonBorderStyle, defs.buttonBorderSize,
        defs.buttonBorderOffset, defs.iconZoom,
        defs.showCount, defs.tooltips,
    })

    H.Section(ctx, L["Labels"])
    H.Grid(ctx, {
        defs.buttonLabel, defs.labelOutline,
        defs.labelText, defs.labelColor,
        defs.labelPoint, defs.labelPlacement,
        defs.labelScale,
        defs.labelOffsetX, defs.labelOffsetY,
    })

    H.Section(ctx, L["Flyout"])
    H.Grid(ctx, {
        defs.flyout, defs.flyoutInvert,
        defs.flyoutPoint, defs.flyoutAutoClose,
        defs.flyoutIndicatorSize, defs.flyoutArrowScale,
        defs.flyoutShadeColor,
        defs.flyoutScale, defs.flyoutSpacing,
        defs.flyoutGap, defs.flyoutMax,
    })

    H.Section(ctx, L["Visibility"])
    H.Grid(ctx, { defs.combatMode, defs.fadeUnlessHover, defs.fadeAlpha })

    H.Section(ctx, L["Macros on the bar"])
    H.Label(ctx, L["Drag a button on the bar itself onto another to swap their places."])
    macroToggles(ctx)

    if scroll.DoLayout then scroll:DoLayout() end
end

local function Build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local ctx = H.CreatePanel("KCMMacroBarPanel", L["Macro Bar"], {
        panelKey       = "macrobar",
        defaultsAction = doResetPage,
    })
    H.SetRenderer(ctx, render)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Macro Bar"])
end

if KCM.Settings and KCM.Settings.RegisterTab then
    KCM.Settings.RegisterTab("macrobar", Build)
end
