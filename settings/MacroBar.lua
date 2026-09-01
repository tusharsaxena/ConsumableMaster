-- settings/MacroBar.lua — Macro Bar page.
--
-- Eight TABS on a pinned strip (options-ui-§13), not eight scrolling sections:
-- General (enable / lock / reset), Layout (grid + geometry), Bar appearance and
-- Button appearance (chrome + colors), Labels, Flyout, Visibility (combat driver
-- + hover fade), and Contents (which macros occupy a slot). A tab IS a schema
-- row `group`, so the strip cannot drift from the rows it partitions.
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
-- sourced from dbDefaults, never duplicated as literals (architecture-§5).

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
    path = "macroBar.enabled", type = "bool", group = "General",
    label = L["Enable macro bar"],
    tooltip = L["Show a dedicated bar holding your ConsumableMaster macros. Only CM macros can occupy it. On by default; turning it off hides the bar and stops all its work until you turn it back on."],
    -- Apply-only, and deliberately so (CM-R-05): the write has already landed
    -- by the time an onChange runs. MB.ApplyEnabled re-reads the flag and
    -- reconciles the frames, and it owns the in-combat "will appear/hide when
    -- combat ends" notice — which is why `/cm bar on|off` routes back through
    -- Schema:Set to this same row rather than applying on its own.
    onChange = function()
        if KCM.MacroBar and KCM.MacroBar.ApplyEnabled then
            KCM.MacroBar.ApplyEnabled()
        end
    end,
}
row{
    path = "macroBar.locked", type = "bool", group = "General",
    label = L["Lock position"],
    tooltip = L["When unlocked the bar is tinted gold and can be dragged anywhere on screen; its position is saved automatically. Lock it again to click through the empty space around the buttons."],
    -- The row had NO onChange, which meant `/cm set macroBar.locked true`
    -- wrote the flag and nothing on screen changed until the next full apply
    -- pass (CM-R-05). Same shape as `macroBar.enabled` above: apply-only, and
    -- the single write path for the flag is Schema:Set.
    onChange = function()
        if KCM.MacroBar and KCM.MacroBar.ApplyLock then
            KCM.MacroBar.ApplyLock()
        end
    end,
}
-- `max` is derived rather than a literal: it's the slot count, and a
-- hardcoded number is exactly what just went stale (13 -> 15 when this
-- branch added two categories). settings/ loads after defaults/ in
-- ConsumableMaster.toc, so KCM.Categories.LIST already exists here.
row{
    path = "macroBar.perRow", type = "number", min = 1,
    max = KCM.Categories and KCM.Categories.LIST and #KCM.Categories.LIST or 13,
    step = 1, group = "Layout",
    label = L["Buttons per row"],
    tooltip = L["How many buttons fit along the axis the bar fills first — a row when the orientation is Horizontal, a column when it is Vertical. The maximum puts every macro on one line."],
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
    path = "macroBar.barBorderStyle", type = "string", dialogControl = "LSM30_Border", group = "Bar appearance",
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
-- Declared HERE, with the rest of its group, rather than four rows down among the
-- button rows where it used to sit. A tab strip partitions the page by `group` in
-- DECLARATION order, so a row filed under a group the page has already left is a
-- second, later copy of that tab. Nothing moves on screen: the renderer has always
-- drawn it at the end of the Bar appearance grid.
row{
    path = "macroBar.alpha", type = "number", min = 0.1, max = 1.0, step = 0.05, group = "Bar appearance",
    label = L["Bar opacity"],
    tooltip = L["Opacity of the whole bar when it is not faded out."],
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
    path = "macroBar.buttonBorderStyle", type = "string", dialogControl = "LSM30_Border", group = "Button appearance",
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
    tooltip = L["Pushes the border outward, away from the icon. Raise this if a thick border is bleeding over the artwork; 0 draws it centered on the button's edge."],
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
    path = "macroBar.showGCD", type = "bool", group = "Button appearance",
    label = L["Show GCD swipe"],
    tooltip = L["Off by default: hides the roughly 1.5-second global-cooldown swipe and completion sparkle that would otherwise flash across every button whenever you cast anything. A real cooldown's swipe still shows, but it vanishes for its own final second or so instead of visibly counting down to zero, and its completion sparkle is hidden along with the GCD's — the button can't tell a lone GCD from the last moment of a long cooldown."],
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
    path = "macroBar.flyoutBackdrop", type = "bool", group = "Flyout",
    label = L["Flyout background"],
    tooltip = L["Draw a panel behind the flyout. Worth keeping on: without it, a flyout opening over a second row of bar buttons looks just like more bar."],
}
row{
    path = "macroBar.flyoutBackdropColor", type = "color", group = "Flyout",
    label = L["Flyout background color"],
    tooltip = L["Color and opacity of the flyout's panel. Its border matches the bar's own border style, thickness and color."],
}
row{
    path = "macroBar.flyoutPadding", type = "number", min = 0, max = 16, step = 1, group = "Flyout",
    label = L["Flyout padding (px)"],
    tooltip = L["Inset between the flyout's entries and the edge of its panel, in pixels."],
}
row{
    path = "macroBar.flyoutGap", type = "number", min = 0, max = 20, step = 1, group = "Flyout",
    label = L["Gap from button (px)"],
    tooltip = L["Gap between the macro button and the first flyout entry. Raise it if a thick or offset button border overlaps the flyout. Hovering still works across the gap."],
}
row{
    path = "macroBar.flyoutIndicatorScale", type = "number", min = 5, max = 50, step = 1, group = "Flyout",
    label = L["Shaded band thickness (% of icon)"],
    tooltip = L["How deep the shaded strip across the icon is, as a percentage of the button — so it keeps its proportions when you resize the bar. Raise it for an easier hover target; it is capped at half the button, and the button label automatically moves clear when the two share an edge."],
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

-- Top-right Defaults button (options-ui-§5): every macroBar setting back to
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

-- ---------------------------------------------------------------------------
-- The tab strip (options-ui-§13)
-- ---------------------------------------------------------------------------
--
-- Eight sections, fifty-four rows, one scroll: the page was a wall a player had
-- to read past to reach the one setting they came for. Each section is a tab
-- now, and only the active one draws.
--
-- One entry per tab, and the `group` string IS the partition key its rows carry
-- — there is no second field naming the tab, for the reason options-ui-§13 gives
-- against one: a tab list declared apart from the rows goes stale the first time
-- a section is renamed and nothing says so. tests/test_schema.lua pins the two
-- against each other.
--
-- Order: General first (the master toggle and the two reset buttons — what a
-- player reaches for on opening), then the three geometry-and-paint tabs in the
-- order a bar is built (Layout, Bar appearance, Button appearance), then Labels
-- (which is about the buttons, so it sits with them), Flyout (its own surface),
-- Visibility, and Contents last: what is ON the bar is set once and left.
--
-- Two renames. "Bar" became "General" because on a page called Macro Bar the
-- word carried nothing and it collided with "Bar appearance" two tabs along.
-- "Macros on the bar" became "Contents" for the same reason — every tab here is
-- about the bar. "Bar appearance" and "Button appearance" KEEP their qualifiers:
-- two surfaces coexist on this page, each with its own backdrop and border, so
-- there the word is doing real work.

local function drawGeneral(ctx)
    H.Grid(ctx, { defs.enabled, defs.locked })
    H.ButtonPair(ctx,
        {
            text    = L["Reset position"],
            tooltip = L["Move the bar back to the center of the screen."],
            onClick = doResetPosition,
        },
        {
            text    = L["Reset slot order"],
            tooltip = L["Restore the default left-to-right slot order, undoing any drag-and-drop rearranging."],
            onClick = doResetOrder,
        })
end

local function drawLayout(ctx)
    H.Grid(ctx, {
        defs.perRow, defs.buttonSize,
        defs.spacing, defs.padding,
        defs.scale, defs.orientation,
        defs.growthH, defs.growthV,
    })
end

local function drawBarAppearance(ctx)
    H.Grid(ctx, {
        defs.barBackdrop, defs.barBackdropColor,
        defs.barBorder, defs.barBorderColor,
        defs.barBorderStyle, defs.barBorderSize,
        defs.alpha,
    })
end

local function drawButtonAppearance(ctx)
    -- Deliberately the same shape as drawBarAppearance above, line for line:
    -- [fill toggle] [fill color] / [border toggle] [border color] /
    -- [border style] [border size]. Two tabs describing the same three things
    -- about two surfaces should not be read in two different orders.
    H.Grid(ctx, {
        defs.buttonBackdrop, defs.buttonBackdropColor,
        defs.buttonBorder, defs.buttonBorderColor,
        defs.buttonBorderStyle, defs.buttonBorderSize,
        defs.buttonBorderOffset, defs.iconZoom,
        defs.showCount, defs.tooltips,
        defs.showGCD,
    })
end

local function drawLabels(ctx)
    -- Reordered so each line is one question. The master toggle leads the thing
    -- it governs ([show labels] [what they say]); the two anchors pair; the two
    -- offsets pair, which is the comparison someone nudging a label actually
    -- makes; then how it is drawn. It used to open [show labels] [outline],
    -- which put the least-used control on the same line as the master switch and
    -- split labelText from the toggle that turns it on.
    H.Grid(ctx, {
        defs.buttonLabel, defs.labelText,
        defs.labelPoint, defs.labelPlacement,
        defs.labelOffsetX, defs.labelOffsetY,
        defs.labelScale, defs.labelColor,
        defs.labelOutline,
    })
end

local function drawFlyout(ctx)
    H.Grid(ctx, {
        defs.flyout, defs.flyoutInvert,
        defs.flyoutPoint, defs.flyoutAutoClose,
        defs.flyoutIndicatorScale, defs.flyoutArrowScale,
        defs.flyoutShadeColor,
        defs.flyoutBackdrop, defs.flyoutBackdropColor,
        defs.flyoutScale, defs.flyoutSpacing,
        defs.flyoutPadding, defs.flyoutGap,
        defs.flyoutMax,
    })
end

local function drawVisibility(ctx)
    H.Grid(ctx, { defs.combatMode, defs.fadeUnlessHover, defs.fadeAlpha })
end

local function drawContents(ctx)
    H.Label(ctx, L["Drag a button on the bar itself onto another to swap their places."])
    macroToggles(ctx)
end

-- `group` is the schema partition key AND the tab key; `label` is what the strip
-- shows. Contents is the one tab with no schema rows behind it — its controls
-- are one checkbox per managed macro, a length no schema knows — and
-- tests/test_schema.lua exempts it BY NAME rather than by relaxing the rule.
local TABS = {
    { group = "General",           label = L["General"],           draw = drawGeneral },
    { group = "Layout",            label = L["Layout"],            draw = drawLayout },
    { group = "Bar appearance",    label = L["Bar appearance"],    draw = drawBarAppearance },
    { group = "Button appearance", label = L["Button appearance"], draw = drawButtonAppearance },
    { group = "Labels",            label = L["Labels"],            draw = drawLabels },
    { group = "Flyout",            label = L["Flyout"],            draw = drawFlyout },
    { group = "Visibility",        label = L["Visibility"],        draw = drawVisibility },
    { group = "Contents",          label = L["Contents"],          draw = drawContents },
}
KCM.Settings.MACROBAR_TABS = TABS

local function activeTab(ctx)
    for _, tab in ipairs(TABS) do
        if tab.group == ctx.activeTab then return tab end
    end
    ctx.activeTab = TABS[1].group
    return TABS[1]
end

local function render(ctx)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    local tab = activeTab(ctx)
    local strip = {}
    for i, entry in ipairs(TABS) do
        strip[i] = { key = entry.group, label = entry.label }
    end
    H.TabStrip(ctx, {
        tabs     = strip,
        value    = ctx.activeTab,
        onSelect = function(key)
            if key == ctx.activeTab then return end
            ctx.activeTab = key
            render(ctx)
        end,
    })

    tab.draw(ctx)

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
