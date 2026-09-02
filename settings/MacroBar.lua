-- settings/MacroBar.lua — Macro Bar page.
--
-- Eight TABS on a pinned strip (options-ui-§13), not eight scrolling sections:
-- General (enable + reset slot order), Layout (grid + geometry), Bar appearance
-- and Button appearance (chrome + colors), Labels, Flyout, Visibility (combat
-- driver + hover fade), and Contents (which macros occupy a slot). A tab IS a
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
    spec.onChange = spec.onChange or applyBar
    KCM.Settings.Schema[#KCM.Settings.Schema + 1] = spec
    collect(spec)
    return spec
end

-- A COMPOSED block: registered through the shared splice (which stamps `panel`,
-- `section` and this addon's per-row extras) and then collected in the same
-- order, so a composed block and a hand-written row are indistinguishable to the
-- renderer below.
local function block(rows, decorate)
    for _, r in ipairs(rows) do
        r.onChange = r.onChange or applyBar
    end
    H.RegisterRows(rows, "macrobar", "macrobar", decorate)
    for _, r in ipairs(rows) do
        r.onChange = r.onChange or applyBar
        collect(r)
    end
    return rows
end

-- THE MEDIA-LIST WORKAROUND, and it is a LIBRARY DEFECT worked around rather
-- than a preference. OptionsCompose minor 1 emits its media rows as
-- `values = function() return O.LSMValues("border") end` — but `O.LSMValues`
-- already RETURNS the deferred closure, so the row's `values()` answers a
-- function and the flow engine's enumList, which accepts a table or a function
-- returning one, sees neither and renders an EMPTY dropdown. Reported upstream;
-- until it is fixed there, the row's list is replaced here with this addon's own
-- ordered `{ value =, text = }` reader, which is the shape every other media row
-- on this page already declares.
--
-- FILED: LibKa0s issue #15. This function and the three `values = lsmValues(...)`
-- overrides below come out in the same change as the re-vendor that carries the
-- fix -- they are a workaround with an end condition, not a preference.
local function lsmValues(mediaType)
    return function() return H.LSMValues(mediaType) end
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
        values  = lsmValues("border"),
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
        values  = lsmValues("border"),
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
        values  = lsmValues("font"),
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

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

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
-- pages' settings are untouched — including `macroBar.locked`, which is stored
-- here but is the General page's row now and comes back with its own page.
local function doResetPage()
    if not (KCM.db and KCM.db.profile) then return end
    local locked = KCM.db.profile.macroBar and KCM.db.profile.macroBar.locked
    KCM.db.profile.macroBar = CopyTable(BAR_DEFAULTS)
    KCM.db.profile.macroBar.locked = locked
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
-- sits with them), Flyout (its own surface), Visibility, and Contents last: what
-- is ON the bar is set once and left.
--
-- Two renames. "Bar" became "General" because on a page called Macro Bar the
-- word carried nothing and it collided with "Bar appearance" two tabs along.
-- "Macros on the bar" became "Contents" for the same reason — every tab here is
-- about the bar. "Bar appearance" and "Button appearance" KEEP their qualifiers:
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
    { group = "Layout",            label = L["Layout"],            draw = drawGroup("Layout") },
    { group = "Bar appearance",    label = L["Bar appearance"],    draw = drawGroup("Bar appearance") },
    { group = "Button appearance", label = L["Button appearance"], draw = drawGroup("Button appearance") },
    { group = "Labels",            label = L["Labels"],            draw = drawGroup("Labels") },
    { group = "Flyout",            label = L["Flyout"],            draw = drawGroup("Flyout") },
    { group = "Visibility",        label = L["Visibility"],        draw = drawGroup("Visibility") },
    { group = "Contents",          label = L["Contents"],          draw = drawContents },
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
