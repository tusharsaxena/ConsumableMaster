-- settings/MacroBar.lua — Macro Bar page.
--
-- Eight TABS on a pinned strip (options-ui-§13), not eight scrolling sections:
-- General (enable + reset slot order), Layout (grid + geometry), Bar appearance
-- and Button appearance (chrome + colors), Labels, Flyout, Visibility (combat
-- driver + hover fade), and Buttons (which macros occupy a slot). A tab IS a
-- schema row `group`, so the strip cannot drift from the rows it partitions.
--
-- FOUR OF THE TABS MIX CONTROL TYPES, so each block inside them carries a
-- `subgroup` heading (options-ui-§7): a tab holding a background block, a border
-- block and an icon block is three subjects under one label, and a player
-- scanning it has no way to tell where one ends. The heading is declared by the
-- row exactly as the tab is, so nothing here draws one.
--
-- THE BORDER, BACKGROUND AND FONT BLOCKS ARE COMPOSED (options-ui-§16), not
-- typed out: H.BorderGroup, H.ColorPair and H.FontGroup emit the mandated rows in
-- the mandated order with the class-color companion beside every swatch, and
-- nine addons cannot drift into nine orders. `keys` and `defaults` are what keep
-- the STORED side of this page byte-identical to what it has always written --
-- the composer changes what is DECLARED, never what is stored.
--
-- WHAT IS NOT HERE ANY MORE. `Lock position` and `Reset position` moved to the
-- General page's Master controls tab (options-ui-§15) and were DELETED here: two
-- controls over one setting is exactly what that rule removes. Their stored paths
-- did not move -- `macroBar.locked` is still `macroBar.locked`.
--
-- Every setting is a KCM.Settings.Schema row, so each one is simultaneously a
-- widget here and a `/cm get|set macroBar.<field>` path — one definition, both
-- surfaces. Two of them are WHOLE-VALUE rows the row engine does not draw
-- (architecture-§5): `macroBar.order` and `macroBar.shown`. The Buttons tab draws
-- both as ONE draggable list -- shown slots first, each with a drag handle, then
-- the hidden ones, dimmed -- where a drag splices the order and a tick moves a
-- slot across the rule. Dropping one button onto another on the bar itself still
-- swaps the two (MacroBar.SwapSlots), and the General tab's Reset slot order puts
-- the shipped order back.

local _, NS = ...
local KCM = NS
local L = KCM.L
local H = KCM.Settings.Helpers
-- Silent-mode (library-stack-§4). Only the Buttons tab's row slots reach it, and a
-- load without AceGUI registers no page to draw them on.
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

local BAR_DEFAULTS = KCM.dbDefaults and KCM.dbDefaults.profile
    and KCM.dbDefaults.profile.macroBar or {}

-- Re-apply the whole bar after any setting changes. MacroBar.Update is
-- idempotent and self-defers in combat, so every row can share one apply.
local function applyBar()
    if KCM.MacroBar and KCM.MacroBar.Update then KCM.MacroBar.Update() end
end

-- The sentence a color swatch's tooltip has to end with, appended rather than
-- replaced (options-ui-§17): the swatch is NEVER disabled while its companion is
-- on, because its ALPHA is still read, so the honest thing is to say so in words.
-- `H.CLASS_COLOR_NOTE` is the library's one wording; nil on a degraded load,
-- where the composed rows do not exist to carry a tooltip anyway.
local function swatchTip(text)
    local note = H.CLASS_COLOR_NOTE
    return note and (text .. " " .. note) or text
end

-- ---------------------------------------------------------------------------
-- Schema rows
-- ---------------------------------------------------------------------------
-- `row()` appends to KCM.Settings.Schema AND to this page's per-group bucket, so
-- the strip's draw is "render this group's rows, in declaration order" rather
-- than a second hand-written layout that can disagree with the schema. Defaults
-- are sourced from dbDefaults, never duplicated as literals (architecture-§5).

local GROUP_ORDER = {}
local groupRows   = {}

local function collect(spec)
    local list = groupRows[spec.group]
    if not list then
        list = {}
        groupRows[spec.group]   = list
        GROUP_ORDER[#GROUP_ORDER + 1] = spec.group
    end
    list[#list + 1] = spec
end

local function row(spec)
    local field = spec.path:match("([^.]+)$")
    spec.panel    = "macrobar"
    spec.section  = "macrobar"
    spec.default  = BAR_DEFAULTS[field]
    spec.apply    = spec.apply or applyBar
    H.AddRow(spec)
    collect(spec)
    return spec
end

-- A COMPOSED block: registered through the shared splice (which stamps `panel`,
-- `section` and this addon's per-row extras) and then collected in the same
-- order, so a composed block and a hand-written row are indistinguishable to the
-- renderer below.
local function block(rows, decorate)
    H.RegisterRows(rows, "macrobar", "macrobar", decorate)
    for _, r in ipairs(rows) do
        r.apply = r.apply or applyBar
        collect(r)
    end
    return rows
end

local function enum(...)
    local out = {}
    for i = 1, select("#", ...), 2 do
        out[#out + 1] = { value = select(i, ...), text = select(i + 1, ...) }
    end
    return out
end

-- ── General ────────────────────────────────────────────────────────────────

row{
    path = "macroBar.enabled", type = "bool", group = "General",
    label = L["Enable macro bar"],
    tooltip = L["Show a dedicated bar holding your ConsumableMaster macros. Only CM macros can occupy it. On by default; turning it off hides the bar and stops all its work until you turn it back on."],
    -- Apply-only, and deliberately so (CM-R-05): the write has already landed
    -- by the time an apply runs. MB.ApplyEnabled re-reads the flag and
    -- reconciles the frames, and it owns the in-combat "will appear/hide when
    -- combat ends" notice — which is why `/cm bar on|off` routes back through
    -- Schema:Set to this same row rather than applying on its own.
    apply = function()
        if KCM.MacroBar and KCM.MacroBar.ApplyEnabled then
            KCM.MacroBar.ApplyEnabled()
        end
    end,
}

-- ── Layout ─────────────────────────────────────────────────────────────────

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
-- The BAR's own scale, not the addon's. The General page's Master scale is a
-- separate, addon-wide setting and the two compose (options-ui-§15); neither is
-- the other's duplicate and neither may be conflated with it.
row{
    path = "macroBar.scale", type = "number", min = 0.5, max = 2.0, step = 0.05, group = "Layout",
    label = L["Bar scale"],
    tooltip = L["Scales this bar, buttons and backdrop together. Multiplied by the addon-wide Master scale on the General page."],
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

-- ── Bar appearance ─────────────────────────────────────────────────────────
--
-- A BACKGROUND, NOT A BAR (options-ui-§16). The macro bar is a button container
-- with a backdrop and no fill texture, so it takes a swatch and its class-color
-- companion and nothing else; a "bar texture" picker here would be a control
-- wired to nothing. That is why the swatch is composed with H.ColorPair and the
-- bar composer is not called anywhere in this addon.

-- `Opacity`, not `Bar`: a subsection heading names the KIND of control under it and
-- never repeats the tab it sits on (options-ui-§13), and this tab is already called
-- "Bar appearance". Its sibling tab reads the same way -- "Button appearance" opens
-- on `Background`, not on `Button`.
row{
    path = "macroBar.alpha", type = "number", min = 0.1, max = 1.0, step = 0.05,
    group = "Bar appearance", subgroup = L["Opacity"],
    label = L["Bar opacity"],
    tooltip = L["Opacity of the whole bar when it is not faded out. Multiplied by the addon-wide Master alpha on the General page."],
}
row{
    path = "macroBar.barBackdrop", type = "bool",
    group = "Bar appearance", subgroup = L["Background"], startsLine = true,
    label = L["Bar background"],
    tooltip = L["Draw a filled backdrop behind the buttons."],
}
block(H.ColorPair{
    page = "macrobar", group = "Bar appearance", subgroup = L["Background"],
    prefix = "macroBar.",
    key = "barBackdropColor", companionKey = "useClassColorBarBackdrop",
    label = L["Bar background color"],
    defaults = {
        barBackdropColor         = BAR_DEFAULTS.barBackdropColor,
        useClassColorBarBackdrop = BAR_DEFAULTS.useClassColorBarBackdrop,
    },
    -- PLAYER, not a tracked unit: this bar describes nothing but the player's own
    -- macros, and modules/MacroBar.lua's applyBackdrop resolves it with a nil unit
    -- through KCM.SwatchColor.
    classColor = { source = "player" },
}, {
    ["macroBar.barBackdropColor"] = {
        tooltip = swatchTip(L["Color and opacity of the bar's backdrop."]),
    },
})
block(H.BorderGroup{
    page = "macrobar", group = "Bar appearance", subgroup = L["Border"],
    show = true, prefix = "macroBar.",
    keys = {
        borderShow          = "barBorder",
        borderStyle         = "barBorderStyle",
        borderSize          = "barBorderSize",
        borderColor         = "barBorderColor",
        useClassColorBorder = "useClassColorBarBorder",
    },
    labels = { borderShow = L["Bar border"] },
    defaults = {
        borderShow          = BAR_DEFAULTS.barBorder,
        borderStyle         = BAR_DEFAULTS.barBorderStyle,
        borderSize          = BAR_DEFAULTS.barBorderSize,
        borderColor         = BAR_DEFAULTS.barBorderColor,
        useClassColorBorder = BAR_DEFAULTS.useClassColorBarBorder,
    },
    classColor = { source = "player" },
}, {
    ["macroBar.barBorderStyle"] = {
        tooltip = L["LibSharedMedia border texture used for the bar's edge. Any border another addon registers shows up here too."],
    },
    ["macroBar.barBorderSize"] = {
        min = 1, max = 16, step = 1,
        tooltip = L["Thickness of the bar border's edge slices, in pixels."],
    },
    ["macroBar.barBorderColor"] = {
        tooltip = swatchTip(L["Color and opacity of the bar's border."]),
    },
})

-- ── Button appearance ──────────────────────────────────────────────────────

row{
    path = "macroBar.buttonBackdrop", type = "bool",
    group = "Button appearance", subgroup = L["Background"], startsLine = true,
    label = L["Button background"],
    tooltip = L["Fill each button behind its icon. Visible mainly while an icon is still loading."],
}
block(H.ColorPair{
    page = "macrobar", group = "Button appearance", subgroup = L["Background"],
    prefix = "macroBar.",
    key = "buttonBackdropColor", companionKey = "useClassColorButtonBackdrop",
    label = L["Button background color"],
    defaults = {
        buttonBackdropColor         = BAR_DEFAULTS.buttonBackdropColor,
        useClassColorButtonBackdrop = BAR_DEFAULTS.useClassColorButtonBackdrop,
    },
    classColor = { source = "player" },
}, {
    ["macroBar.buttonBackdropColor"] = {
        tooltip = swatchTip(L["Color and opacity of each button's fill."]),
    },
})
-- `buttonBorderOffset` is a legitimate extra of the same kind, so it goes in
-- `extra` and is appended AFTER the mandated four — never interleaved with them
-- (options-ui-§16).
block(H.BorderGroup{
    page = "macrobar", group = "Button appearance", subgroup = L["Border"],
    show = true, prefix = "macroBar.",
    keys = {
        borderShow          = "buttonBorder",
        borderStyle         = "buttonBorderStyle",
        borderSize          = "buttonBorderSize",
        borderColor         = "buttonBorderColor",
        useClassColorBorder = "useClassColorButtonBorder",
    },
    labels = { borderShow = L["Button border"] },
    defaults = {
        borderShow          = BAR_DEFAULTS.buttonBorder,
        borderStyle         = BAR_DEFAULTS.buttonBorderStyle,
        borderSize          = BAR_DEFAULTS.buttonBorderSize,
        borderColor         = BAR_DEFAULTS.buttonBorderColor,
        useClassColorBorder = BAR_DEFAULTS.useClassColorButtonBorder,
    },
    classColor = { source = "player" },
    extra = {
        {
            path = "macroBar.buttonBorderOffset", type = "number",
            min = 0, max = 16, step = 1,
            label = L["Border offset (px)"],
            tooltip = L["Pushes the border outward, away from the icon. Raise this if a thick border is bleeding over the artwork; 0 draws it centered on the button's edge."],
            default = BAR_DEFAULTS.buttonBorderOffset,
        },
    },
}, {
    ["macroBar.buttonBorderStyle"] = {
        tooltip = L["LibSharedMedia border texture used for each button's edge. Any border another addon registers shows up here too."],
    },
    ["macroBar.buttonBorderSize"] = {
        min = 1, max = 16, step = 1,
        tooltip = L["Thickness of the button border's edge slices, in pixels."],
    },
    ["macroBar.buttonBorderColor"] = {
        tooltip = swatchTip(L["Tints the button border texture."]),
    },
})
row{
    path = "macroBar.iconZoom", type = "number", min = 0, max = 40, step = 1,
    group = "Button appearance", subgroup = L["Icon"], startsLine = true,
    label = L["Icon zoom (%)"],
    tooltip = L["Crops this percentage off each side of the icon. A little zoom trims the dark edge baked into most item icons so it doesn't read as a second border."],
}
row{
    path = "macroBar.showCount", type = "bool",
    group = "Button appearance", subgroup = L["Icon"],
    label = L["Show stack count"],
    tooltip = L["Show how many of the picked item you're carrying in the bottom-right corner of each button."],
}
row{
    path = "macroBar.tooltips", type = "bool",
    group = "Button appearance", subgroup = L["Icon"],
    label = L["Show tooltips"],
    tooltip = L["Show the picked item's or spell's tooltip when you hover a button."],
}
row{
    path = "macroBar.showGCD", type = "bool",
    group = "Button appearance", subgroup = L["Icon"],
    label = L["Show GCD swipe"],
    tooltip = L["Off by default: hides the roughly 1.5-second global-cooldown swipe and completion sparkle that would otherwise flash across every button whenever you cast anything. A real cooldown's swipe still shows, but it vanishes for its own final second or so instead of visibly counting down to zero, and its completion sparkle is hidden along with the GCD's — the button can't tell a lone GCD from the last moment of a long cooldown."],
}

-- ── Labels ─────────────────────────────────────────────────────────────────
--
-- Three blocks, three headings: what the label SAYS, where it SITS, and how it is
-- DRAWN. The last of those is the canonical font group (options-ui-§16), composed.

row{
    path = "macroBar.buttonLabel", type = "bool",
    group = "Labels", subgroup = L["Text"], startsLine = true,
    label = L["Show button labels"],
    tooltip = L["Label each button with its category name. The text scales with the button size."],
}
row{
    path = "macroBar.labelText", type = "string", group = "Labels", subgroup = L["Text"],
    values = enum(
        "AUTO",  L["Auto (shorten to fit)"],
        "FULL",  L["Always full name"],
        "SHORT", L["Always short name"]),
    label = L["Label text"],
    tooltip = L["Auto uses the full category name and falls back to a short form only when the full one won't fit inside the button."],
}
row{
    path = "macroBar.labelPoint", type = "string",
    group = "Labels", subgroup = L["Layout"], startsLine = true,
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
    path = "macroBar.labelPlacement", type = "string", group = "Labels", subgroup = L["Layout"],
    values = enum("INSIDE", L["Inside the button"], "OUTSIDE", L["Outside the button"]),
    label = L["Label placement"],
    tooltip = L["Inside draws the label over the icon; Outside pushes it just beyond that edge of the button. Outside labels can overlap a neighboring button when spacing is tight."],
}
row{
    path = "macroBar.labelOffsetX", type = "number", min = -20, max = 20, step = 1,
    group = "Labels", subgroup = L["Layout"],
    label = L["Label offset X (px)"],
    tooltip = L["Nudge the label horizontally from its anchor."],
}
row{
    path = "macroBar.labelOffsetY", type = "number", min = -20, max = 20, step = 1,
    group = "Labels", subgroup = L["Layout"],
    label = L["Label offset Y (px)"],
    tooltip = L["Nudge the label vertically from its anchor. Negative moves it down."],
}
block(H.FontGroup{
    page = "macrobar", group = "Labels", subgroup = L["Font"], prefix = "macroBar.",
    keys = {
        font              = "labelFont",
        -- The canonical `Font size` row, stored as this addon's `labelScale`. The
        -- size is a PERCENTAGE of the button rather than a point height, so the
        -- labels keep their proportions when the bar is resized — which is why the
        -- label is overridden below and the range restored to the shipped 10-50.
        fontSize          = "labelScale",
        fontColor         = "labelColor",
        useClassColorFont = "useClassColorLabel",
        fontFlags         = "labelFlags",
        fontShadow        = "labelShadow",
    },
    -- Keyed by the composer's LEAF name, not by this addon's stored key: `keys`
    -- renames the path, `defaults` fills the row the leaf names.
    defaults = {
        font              = BAR_DEFAULTS.labelFont,
        fontSize          = BAR_DEFAULTS.labelScale,
        fontColor         = BAR_DEFAULTS.labelColor,
        useClassColorFont = BAR_DEFAULTS.useClassColorLabel,
        fontFlags         = BAR_DEFAULTS.labelFlags,
        fontShadow        = BAR_DEFAULTS.labelShadow,
    },
    classColor = { source = "player" },
}, {
    ["macroBar.labelFont"] = {
        tooltip = L["LibSharedMedia font face the button labels are drawn in. Any face another addon registers shows up here too."],
    },
    -- The composer's spec carries no range field, and its 6-32 default would
    -- silently CLAMP a profile that had already stored 40%. So the shipped range
    -- is restored here, with the label saying what the number means.
    ["macroBar.labelScale"] = {
        label   = L["Font size (% of button)"],
        min = 10, max = 50, step = 1,
        tooltip = L["Label font size as a percentage of the button's size, so labels stay proportional when you resize the bar. Clamped to a legible 6-24pt."],
    },
    ["macroBar.labelColor"] = {
        tooltip = swatchTip(L["Color and opacity of the button labels."]),
    },
    ["macroBar.labelFlags"] = {
        tooltip = L["Outline and monochrome rendering. An outline keeps the label readable over a bright icon."],
    },
    ["macroBar.labelShadow"] = {
        tooltip = L["Draw a soft shadow behind the label, for legibility over busy artwork."],
    },
})

-- ── Flyout ─────────────────────────────────────────────────────────────────

row{
    path = "macroBar.flyout", type = "bool",
    group = "Flyout", subgroup = L["Layout"], startsLine = true,
    label = L["Enable flyout"],
    tooltip = L["Put a small arrow on each button; hovering it opens a strip holding every item or spell in that category you can actually use right now. Only the macro bar has flyouts — a KCM macro dragged onto a Blizzard action bar stays an ordinary macro."],
}
row{
    path = "macroBar.flyoutPoint", type = "string", group = "Flyout", subgroup = L["Layout"],
    values = enum("TOP", L["Top"], "BOTTOM", L["Bottom"], "LEFT", L["Left"], "RIGHT", L["Right"]),
    label = L["Flyout side"],
    tooltip = L["Which edge the arrow sits on, and the direction the flyout grows from there."],
}
row{
    path = "macroBar.flyoutInvert", type = "bool", group = "Flyout", subgroup = L["Layout"],
    label = L["Reverse flyout order"],
    tooltip = L["By default the highest-ranked item sits closest to the button. Turn this on to put it furthest away."],
}
row{
    path = "macroBar.flyoutMax", type = "number", min = 1, max = 16, step = 1,
    group = "Flyout", subgroup = L["Layout"],
    label = L["Maximum flyout entries"],
    tooltip = L["Longest flyout to build. Categories with more available items than this show the top-ranked ones. The cap exists because flyout buttons can only be created out of combat."],
}
row{
    path = "macroBar.flyoutScale", type = "number", min = 40, max = 150, step = 5,
    group = "Flyout", subgroup = L["Layout"],
    label = L["Flyout button size (% of button)"],
    tooltip = L["Flyout entry size as a percentage of the main button size."],
}
row{
    path = "macroBar.flyoutSpacing", type = "number", min = 0, max = 16, step = 1,
    group = "Flyout", subgroup = L["Layout"],
    label = L["Flyout spacing (px)"],
    tooltip = L["Gap between flyout entries, in pixels."],
}
row{
    path = "macroBar.flyoutPadding", type = "number", min = 0, max = 16, step = 1,
    group = "Flyout", subgroup = L["Layout"],
    label = L["Flyout padding (px)"],
    tooltip = L["Inset between the flyout's entries and the edge of its panel, in pixels."],
}
row{
    path = "macroBar.flyoutGap", type = "number", min = 0, max = 20, step = 1,
    group = "Flyout", subgroup = L["Layout"],
    label = L["Gap from button (px)"],
    tooltip = L["Gap between the macro button and the first flyout entry. Raise it if a thick or offset button border overlaps the flyout. Hovering still works across the gap."],
}
row{
    path = "macroBar.flyoutAutoClose", type = "number", min = 0, max = 30, step = 0.5,
    group = "Flyout", subgroup = L["Layout"],
    label = L["Auto-close after (seconds)"],
    tooltip = L["Close an open flyout after this many seconds without interaction. 0 keeps it open until you move the mouse away or click something. Moving the mouse off it, and clicking either the macro or a flyout entry, always close it immediately."],
}
row{
    path = "macroBar.flyoutBackdrop", type = "bool",
    group = "Flyout", subgroup = L["Background"], startsLine = true,
    label = L["Flyout background"],
    tooltip = L["Draw a panel behind the flyout. Worth keeping on: without it, a flyout opening over a second row of bar buttons looks just like more bar."],
}
block(H.ColorPair{
    page = "macrobar", group = "Flyout", subgroup = L["Background"],
    prefix = "macroBar.",
    key = "flyoutBackdropColor", companionKey = "useClassColorFlyoutBackdrop",
    label = L["Flyout background color"],
    defaults = {
        flyoutBackdropColor         = BAR_DEFAULTS.flyoutBackdropColor,
        useClassColorFlyoutBackdrop = BAR_DEFAULTS.useClassColorFlyoutBackdrop,
    },
    classColor = { source = "player" },
}, {
    ["macroBar.flyoutBackdropColor"] = {
        tooltip = swatchTip(L["Color and opacity of the flyout's panel. Its border matches the bar's own border style, thickness and color."]),
    },
})
row{
    path = "macroBar.flyoutIndicatorScale", type = "number", min = 5, max = 50, step = 1,
    group = "Flyout", subgroup = L["Icon"], startsLine = true,
    label = L["Shaded band thickness (% of icon)"],
    tooltip = L["How deep the shaded strip across the icon is, as a percentage of the button — so it keeps its proportions when you resize the bar. Raise it for an easier hover target; it is capped at half the button, and the button label automatically moves clear when the two share an edge."],
}
row{
    path = "macroBar.flyoutArrowScale", type = "number", min = 25, max = 250, step = 5,
    group = "Flyout", subgroup = L["Icon"],
    label = L["Arrow size (% of band)"],
    tooltip = L["Arrow size as a percentage of the shaded band's thickness. Over 100% the arrow deliberately overflows the band onto the icon, which keeps it readable on small buttons."],
}
block(H.ColorPair{
    page = "macrobar", group = "Flyout", subgroup = L["Icon"],
    prefix = "macroBar.",
    key = "flyoutShadeColor", companionKey = "useClassColorFlyoutShade",
    label = L["Shaded band color"],
    defaults = {
        flyoutShadeColor         = BAR_DEFAULTS.flyoutShadeColor,
        useClassColorFlyoutShade = BAR_DEFAULTS.useClassColorFlyoutShade,
    },
    classColor = { source = "player" },
}, {
    ["macroBar.flyoutShadeColor"] = {
        tooltip = swatchTip(L["Color and opacity of the strip drawn across the icon. Lower the opacity to let more of the artwork through."]),
    },
})

-- ── Visibility ─────────────────────────────────────────────────────────────

row{
    path = "macroBar.combatMode", type = "string", group = "Visibility",
    values = enum(
        "ALWAYS",          L["Always visible"],
        "HIDE_IN_COMBAT",  L["Hide in combat"],
        "ONLY_IN_COMBAT",  L["Only in combat"]),
    label = L["Combat visibility"],
    tooltip = L["Combat-based hiding is handed to Blizzard's secure visibility driver, so it takes effect the instant combat starts or ends — including mid-fight. Intersected with the addon-wide General visibility on the General page: the bar shows only where both say show."],
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

-- ── Buttons ────────────────────────────────────────────────────────────────
--
-- The two WHOLE-VALUE rows behind the Buttons tab (architecture-§5). A list over
-- a FIXED member set -- the shipped categories -- that the player only reorders
-- or toggles is a value, written whole through the helper like any other row.
-- The row engine draws neither: the tab draws them as one draggable list (see
-- "The Buttons tab" below), a length no schema knows, and a drag on the bar
-- itself writes the order too. Being rows is what puts every write -- the list's
-- drag and tick, the bar's swap, Reset slot order, the page's Defaults, `/cm set`
-- -- through one seam.
local function slotKeys()
    return KCM.MacroBarModel and KCM.MacroBarModel.AllKeys() or {}
end
row{
    path = "macroBar.order", type = "order", group = "Buttons", members = slotKeys,
    label = L["Slot order"],
    tooltip = L["The order the macros sit in on the bar. Drag a button by its handle on the Buttons tab, or drop one button onto another on the bar itself to swap the two; Reset slot order puts the shipped order back."],
}
row{
    path = "macroBar.shown", type = "map", group = "Buttons", members = slotKeys, valueType = "bool",
    label = L["Buttons on the bar"],
    tooltip = L["Which macros have a button on the bar. A macro this does not name has one."],
}

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

-- Through the schema helper: `macroBar.order` is a row, its validator stores a
-- copy of the shipped order, and its apply re-applies the bar.
local function doResetOrder()
    if not (KCM.Schema and KCM.Schema:Set("macroBar.order", BAR_DEFAULTS.order or {})) then return end
    H.RefreshAllPanels()
    KCM.Say("macro bar slot order reset.")
end

-- Top-right Defaults button (options-ui-§5): every setting on THIS PAGE back to
-- its shipped value, plus the bar's position, slot order and per-macro
-- visibility. Other pages' settings are untouched — including
-- `macroBar.locked`, which is stored in the same table but is the General page's
-- row now and comes back with its own page.
--
-- EVERY ROW THROUGH THE SCHEMA HELPER, IN PLACE (architecture-§5). This used to
-- replace the whole `macroBar` table with a copy of the defaults, which skipped
-- every row's validation and left anything holding the old table reading a stale
-- one. It is one batch, so the bar is still re-applied once and the page still
-- rebuilt once, as the whole-table write did. It is a bulk reset, so it logs one
-- `[Set] reset Macro Bar page: N rows` line and no row of its own
-- (debug-logging-§10).
--
-- A table default (every color) goes in as a COPY: a row's `default` IS the
-- dbDefaults table, and storing it would alias the defaults into the profile.
local function doResetPage()
    local cfg = KCM.db and KCM.db.profile and KCM.db.profile.macroBar
    if not cfg then return end
    -- The slot order and visibility ARE rows, so the walk resets them with
    -- everything else.
    local entries = {}
    for _, def in ipairs(KCM.Settings.Schema) do
        if def.panel == "macrobar" and def.default ~= nil then
            local v = def.default
            entries[#entries + 1] = { path = def.path, value = type(v) == "table" and CopyTable(v) or v }
        end
    end
    -- The batch is all or nothing, so it runs FIRST: a refused batch writes no
    -- row, and the position must not move on its own either.
    if not H.SetManyAndRefresh(entries, {
        onChange = applyBar, structural = true,
        bulk = { act = "reset", scope = "Macro Bar page" },
    }) then
        KCM.Say(L["Macro bar defaults were not applied; the bar's position was left as it was."])
        return
    end
    -- The drag-written position has no row, so it goes back through the one
    -- function that owns it.
    if KCM.MacroBar and KCM.MacroBar.ResetPosition then KCM.MacroBar.ResetPosition() end
end

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
-- bar collapses to its backdrop rather than erroring (docs/smoke-tests.md §11a).
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
    GameTooltip:AddLine(slotRow.kcmShown and L["Click to take this button off the bar"]
        or L["Click to put this button back on the bar"], 1, 1, 1)
    GameTooltip:AddLine(L["A hidden button waits below the line, and one you put back joins the end of the bar."],
        1, 1, 1, true)
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
    -- and aiming at it is how you put the button back.
    if shown then
        slotRow.kcmLabel:SetTextColor(1, 0.82, 0)
    else
        slotRow.kcmLabel:SetTextColor(0.5, 0.5, 0.5)
    end
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
    local slot = AceGUI:Create("SimpleGroup")
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
            ghostTextColor = shown and { 1, 0.82, 0 } or { 0.5, 0.5, 0.5 },
            height         = SLOT_ROW_H,
            draggable      = shown,
            dimmed         = not shown,
        })
    end
end

--- The rule under the last shown slot, when there is a divide to mark.
local function addBoundaryRule(scroll)
    local rule = AceGUI:Create("Heading")
    rule:SetText("")
    rule:SetFullWidth(true)
    rule:SetHeight(12)
    scroll:AddChild(rule)
end

local function renderSlotList(ctx, scroll)
    local order, shown = slotState()
    if not order then return end
    local on, off = partitionSlots(order, shown)

    -- Parked on the ctx so the NEXT render can hand them back, and so a case can
    -- reach a row.
    ctx.kcmSlotRows = {}

    local W = reorderWidgets()
    local list = trackReorder(ctx, W and W.ReorderList({
        -- The STRIDE, not the row height: the drop arithmetic is top of row to top
        -- of row.
        stride        = SLOT_ROW_STRIDE,
        boundary      = #on,
        handleIcon    = KCM.Icon and KCM.Icon(SLOT_HANDLE_ICON) or nil,
        handleTooltip = L["Drag to reorder"],
        onMove        = moveSlot,
        debug         = (KCM.State and KCM.State.debug and KCM.Debug)
            and function(fmt, ...) KCM.Debug("Bar", fmt, ...) end or nil,
    }) or nil)

    for _, key in ipairs(on) do renderSlotRow(ctx, scroll, list, key, true) end
    if #on > 0 and #off > 0 then addBoundaryRule(scroll) end
    for _, key in ipairs(off) do renderSlotRow(ctx, scroll, list, key, false) end

    -- The insertion line lives on what every row shares as an ancestor.
    if list then list:Finish(scroll.content or scroll.frame) end
end

-- ---------------------------------------------------------------------------
-- Renderer
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- The tab strip (options-ui-§13)
-- ---------------------------------------------------------------------------
--
-- Eight sections, one scroll: the page was a wall a player had to read past to
-- reach the one setting they came for. Each section is a tab now, and only the
-- active one draws.
--
-- One entry per tab, and the `group` string IS the partition key its rows carry
-- — there is no second field naming the tab, for the reason options-ui-§13 gives
-- against one: a tab list declared apart from the rows goes stale the first time
-- a section is renamed and nothing says so. tests/test_schema.lua pins the two
-- against each other.
--
-- Order: General first (the master toggle for this bar and the slot-order reset),
-- then the three geometry-and-paint tabs in the order a bar is built (Layout, Bar
-- appearance, Button appearance), then Labels (which is about the buttons, so it
-- sits with them), Flyout (its own surface), Visibility, and Buttons last: what
-- is ON the bar is set once and left.
--
-- Two renames. "Bar" became "General" because on a page called Macro Bar the
-- word carried nothing and it collided with "Bar appearance" two tabs along.
-- "Macros on the bar" became "Buttons" for the same reason — every tab here is
-- about the bar, and what the tab actually lists is one entry per BUTTON the bar
-- can carry. It read "Contents" for one release; "Buttons" names the things on
-- screen rather than the abstraction, and it is the word the rest of the page
-- already uses (Button appearance). "Bar appearance" and "Button appearance" KEEP their qualifiers:
-- two surfaces coexist on this page, each with its own backdrop and border, so
-- there the word is doing real work.
--
-- EVERY SCHEMA-BACKED TAB DRAWS THROUGH THE LIBRARY'S ROW ENGINE. Declaration
-- order IS the layout — the pairing, the `startsLine` flushes and the subsection
-- headings are all read off the rows — so there is no second, hand-written
-- ordering here that could disagree with the schema the strip partitions.

local function drawGroup(group)
    return function(ctx)
        H.RenderRows(ctx, groupRows[group] or {}, nil, nil, { noHeadings = true })
    end
end

local function drawGeneral(ctx)
    drawGroup("General")(ctx)
    H.Button(ctx, {
        text    = L["Reset slot order"],
        tooltip = L["Restore the default left-to-right slot order, undoing any drag-and-drop rearranging."],
        onClick = doResetOrder,
    })
end

local function drawButtons(ctx)
    H.Label(ctx, L["Drag a button by its handle to change its place, here or on the bar itself. Click its tick to take it off the bar: hidden buttons wait below the line, and one you put back joins the end of the bar."],
        "medium")
    local scroll = H.EnsureScroll(ctx)
    H.AddSpacer(scroll, 8)
    renderSlotList(ctx, scroll)
end

-- `group` is the schema partition key AND the tab key; `label` is what the strip
-- shows. Buttons is the one tab whose rows the row engine does not draw -- its two
-- whole-value rows are one draggable list, a length no schema knows -- and
-- tests/test_schema.lua exempts it BY NAME rather than by relaxing the rule.
local TABS = {
    { group = "General",           label = L["General"],           draw = drawGeneral },
    { group = "Layout",            label = L["Layout"],            draw = drawGroup("Layout") },
    { group = "Bar appearance",    label = L["Bar appearance"],    draw = drawGroup("Bar appearance") },
    { group = "Button appearance", label = L["Button appearance"], draw = drawGroup("Button appearance") },
    { group = "Labels",            label = L["Labels"],            draw = drawGroup("Labels") },
    { group = "Flyout",            label = L["Flyout"],            draw = drawGroup("Flyout") },
    { group = "Visibility",        label = L["Visibility"],        draw = drawGroup("Visibility") },
    { group = "Buttons",           label = L["Buttons"],           draw = drawButtons },
}
KCM.Settings.MACROBAR_TABS = TABS
-- Published for the suite, which has no other way to read back the order a tab's
-- rows are declared in without re-deriving it from the whole schema.
KCM.Settings.MACROBAR_GROUP_ROWS  = groupRows
KCM.Settings.MACROBAR_GROUP_ORDER = GROUP_ORDER

local function activeTab(ctx)
    for _, tab in ipairs(TABS) do
        if tab.group == ctx.activeTab then return tab end
    end
    ctx.activeTab = TABS[1].group
    return TABS[1]
end

local function render(ctx)
    -- BEFORE ResetScroll and before the first widget, on every tab -- see
    -- cancelReorder.
    cancelReorder(ctx)
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
