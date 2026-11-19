-- tests/test_macrobar_chrome.lua — the macro bar's chrome appliers
-- (MacroBarButton.ApplyStyle), the flyout's bind/apply pass, and the
-- options-ui-§15/options-ui-§16/options-ui-§17 rows those appliers are what honors.
-- Since the drag-handle adoption it also carries the unlocked strip's own
-- chrome: the three tooltips the strip and its marks draw (attached above the strip), the mark's
-- hover tint, and the close mark that hides the bar (X-01, X-02, X-05).
--
-- Peeled out of tests/test_macrobar.lua at the seam issue #32 named, which the
-- cap census in docs/ARCHITECTURE.md carried. NOT the same suite as
-- tests/test_macrobar_buttons.lua (plural), which is the Macro Bar page's
-- Buttons TAB — the reorder list over the bar's slots. This one is the drawing
-- code that paints a single button.
--
-- Every case moved whole: not one assertion changed in the peel.

local h = _G.KCM_TEST
local test = h.test

-- `fcfg` is shared rather than copied — tests/macrobar_support.lua says why.
local support = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua")
local fcfg = support.fcfg

-- ---------------------------------------------------------------------------
-- Chrome appliers (MacroBarButton.ApplyStyle) and the flyout's bind/apply pass
--
-- The mock's generic frame stub answers every method with itself, so it cannot
-- say WHICH setter ran with WHICH arguments — and that is exactly what these
-- appliers own. `recFrame` records every call instead, which is enough to pin
-- the defaulting, the clamps and the show/hide decisions headlessly. The
-- secure-frame behavior around them stays an in-game smoke test.
-- ---------------------------------------------------------------------------

local function recFrame(name)
    local f = { _name = name or "MockFrame", calls = {}, _attrs = {}, _shown = false }
    local special = {
        GetName        = function() return f._name end,
        GetFrameLevel  = function() return 1 end,
        GetStringWidth = function() return 0 end,
        GetFont        = function() return "Fonts\\FRIZQT__.TTF" end,
        IsShown        = function() return f._shown end,
        SetAttribute   = function(_, k, v) f._attrs[k] = v end,
        GetAttribute   = function(_, k) return f._attrs[k] end,
    }
    setmetatable(f, { __index = function(_, key)
        if special[key] then return special[key] end
        return function(_, ...)
            f.calls[#f.calls + 1] = { key, ... }
            if key == "Show" then f._shown = true elseif key == "Hide" then f._shown = false end
            return f
        end
    end })
    return f
end

-- First recorded call named `name`, as { name, arg1, arg2, ... }, or nil.
local function firstCall(f, name)
    for _, c in ipairs(f.calls) do
        if c[1] == name then return c end
    end
    return nil
end

-- Every recorded call named `name`, in order.
local function allCalls(f, name)
    local out = {}
    for _, c in ipairs(f.calls) do
        if c[1] == name then out[#out + 1] = c end
    end
    return out
end

local function styleButton()
    local btn = recFrame("KCMMacroBarButton1")
    btn.catKey      = "FOOD"
    btn.border      = recFrame("border")
    btn.icon        = recFrame("icon")
    btn.backdropTex = recFrame("backdropTex")
    btn.count       = recFrame("count")
    btn.label       = recFrame("label")
    return btn
end

test("macrobar button: ApplyStyle sizes the slot and paints the border child", function(t)
    local KCM = h.loader.loadFullAddon()
    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, {
        buttonSize = 44, buttonBorderOffset = 3, buttonBorderSize = 6,
        buttonBorderStyle = "Blizzard Tooltip", buttonBorderColor = { 0.2 },
    })
    local size = firstCall(btn, "SetSize")
    t.eq(size[2], 44, "width from buttonSize")
    t.eq(size[3], 44, "height from buttonSize")

    local pts = allCalls(btn.border, "SetPoint")
    -- The offset pushes the edge slices OUTWARD, so the two corners take
    -- opposite signs.
    t.eq(pts[1][2], "TOPLEFT", "border anchors top-left first")
    t.eq(pts[1][5], -3, "top-left x is -offset")
    t.eq(pts[1][6], 3, "top-left y is +offset")
    t.eq(pts[2][5], 3, "bottom-right x is +offset")
    t.eq(pts[2][6], -3, "bottom-right y is -offset")

    local bd = firstCall(btn.border, "SetBackdrop")
    t.eq(bd[2].edgeSize, 6, "edge thickness from buttonBorderSize")
    t.truthy(bd[2].edgeFile, "an edge texture is resolved")

    local col = firstCall(btn.border, "SetBackdropBorderColor")
    t.eq(col[2], 0.2, "the stored red component is used")
    t.eq(col[3], 0, "a missing green falls back on its own, to the shipped dark edge (SF1-CM)")
    t.eq(col[5], 1, "a missing alpha falls back on its own")
    t.truthy(btn.border._shown, "the border is shown")
end)

test("macrobar button: ApplyStyle hides the border child when the border is off", function(t)
    local KCM = h.loader.loadFullAddon()
    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, { buttonSize = 36, buttonBorder = false })
    t.falsy(btn.border._shown, "border hidden")
    t.falsy(firstCall(btn.border, "SetBackdrop"), "and no backdrop is applied to it")
end)

test("macrobar button: ApplyStyle floors the edge thickness at one pixel", function(t)
    local KCM = h.loader.loadFullAddon()
    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, { buttonSize = 36, buttonBorderSize = 0 })
    t.eq(firstCall(btn.border, "SetBackdrop")[2].edgeSize, 1, "0 clamps to 1")
end)

test("macrobar button: ApplyStyle clamps the icon zoom to 0..40 percent", function(t)
    local KCM = h.loader.loadFullAddon()

    local hi = styleButton()
    KCM.MacroBarButton.ApplyStyle(hi, { buttonSize = 36, iconZoom = 90 })
    local c = firstCall(hi.icon, "SetTexCoord")
    t.eq(c[2], 0.4, "left crop clamped to 40%")
    t.eq(c[3], 0.6, "right crop mirrors it")

    local lo = styleButton()
    KCM.MacroBarButton.ApplyStyle(lo, { buttonSize = 36, iconZoom = -10 })
    local d = firstCall(lo.icon, "SetTexCoord")
    t.eq(d[2], 0, "negative zoom clamped to 0")
    t.eq(d[3], 1, "so the icon is uncropped")
end)

test("macrobar button: ApplyStyle fills the backdrop and follows its toggle", function(t)
    local KCM = h.loader.loadFullAddon()
    local on = styleButton()
    KCM.MacroBarButton.ApplyStyle(on, { buttonSize = 36, buttonBackdrop = true })
    local fill = firstCall(on.backdropTex, "SetColorTexture")
    t.eq(fill[2], 0, "default fill is black...")
    t.eq(fill[5], 0.6, "...at 60% alpha")
    t.truthy(on.backdropTex._shown, "backdrop shown when enabled")

    local off = styleButton()
    KCM.MacroBarButton.ApplyStyle(off, { buttonSize = 36, buttonBackdrop = false })
    t.falsy(off.backdropTex._shown, "backdrop hidden when disabled")

    local custom = styleButton()
    KCM.MacroBarButton.ApplyStyle(custom, {
        buttonSize = 36, buttonBackdropColor = { 0.1, 0.2, 0.3, 0.4 },
    })
    local c = firstCall(custom.backdropTex, "SetColorTexture")
    t.eq(c[2], 0.1, "stored red")
    t.eq(c[5], 0.4, "stored alpha")
end)

-- --- The flyout's apply pass -----------------------------------------------

local function flyoutEntry(name)
    local e = recFrame(name)
    e.icon        = recFrame("icon")
    e.count       = recFrame("count")
    e.backdropTex = recFrame("backdropTex")
    e.border      = recFrame("border")
    e.cooldown    = recFrame("cooldown")
    return e
end

-- A bar slot with its flyout already built, and `n` entries already pooled as
-- recording frames, so the chrome calls below can be asserted. The real create
-- path is exercised by the "macrobar click" cases above.
local function flyoutButton(catKey, n)
    local button = recFrame("KCMMacroBarButton1")
    button.catKey = catKey
    local flyout = recFrame("KCMMacroBarFlyout1")
    flyout.bg = recFrame("bg")
    flyout.entries = {}
    for i = 1, n do flyout.entries[i] = flyoutEntry("Entry" .. i) end
    local ind = recFrame("KCMMacroBarFlyout1Indicator")
    ind.shade = recFrame("shade")
    ind.arrow = recFrame("arrow")
    button.flyout    = flyout
    button.indicator = ind
    return button, flyout, ind
end

test("macrobar flyout: Apply tears the strip down when the feature is off", function(t)
    local KCM = h.loader.loadFullAddon()
    local button, flyout, ind = flyoutButton("HP_POT", 2)
    flyout.entries[1]:Show()

    t.eq(KCM.MacroBarFlyout.Apply(button, fcfg{ flyout = false }), true, "reports handled")
    t.falsy(flyout._shown, "container hidden")
    t.falsy(ind._shown, "indicator hidden")
    t.falsy(flyout.entries[1]._shown, "pooled entries hidden, never released")
    t.eq(flyout:GetAttribute("kcmEntries"), 0, "the snippet sees an empty flyout")
    t.eq(ind:GetAttribute("kcmEntries"), 0, "on the indicator too")
end)

h.retailTest("macrobar flyout: Apply binds an owned item entry with its chrome", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    mock.setItem(seed[1], { name = "Pot", subType = "Potions" })
    mock.setBag(seed[1], 3)

    local button, flyout = flyoutButton("HP_POT", 3)
    KCM.MacroBarFlyout.Apply(button, fcfg{
        flyout = true, iconZoom = 90, buttonBackdrop = true,
        buttonBorderOffset = 2, buttonBorderSize = 5,
    })

    local e = flyout.entries[1]
    t.eq(e.kcmID, seed[1], "entry 1 points at the owned candidate")
    t.eq(e:GetAttribute("type"), "item", "items click through the item attribute")
    t.eq(e:GetAttribute("item"), "item:" .. seed[1],
        "by id, so a localized name cannot break it")
    t.eq(firstCall(e.icon, "SetTexCoord")[2], 0.4, "the entry takes the same 40% zoom clamp")
    t.eq(firstCall(e.count, "SetText")[2], 3, "the owned count is shown")
    t.eq(firstCall(e.backdropTex, "SetColorTexture")[5], 0.6, "default backdrop alpha")
    t.truthy(e.backdropTex._shown, "backdrop shown with the setting on")
    t.eq(allCalls(e.border, "SetPoint")[1][5], -2, "border offset pushes outward")
    t.eq(firstCall(e.border, "SetBackdrop")[2].edgeSize, 5, "border thickness")
    t.eq(firstCall(e.border, "SetBackdropBorderColor")[2], 0, "border color defaults to the dark edge (SF1-CM)")
    t.truthy(e._shown, "entry shown")

    t.falsy(flyout.entries[2]._shown, "surplus entries stay hidden")
    t.eq(flyout:GetAttribute("kcmEntries"), 1, "the snippet is told how many entries there are")
    t.eq(flyout:GetAttribute("kcmGrace"), 0, "and what the leave grace period is")
end)

test("macrobar flyout: Apply binds a known spell entry by name", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local SPELL_ID = 1231411
    mock.setSpell(SPELL_ID, { name = "Healthstone", known = true })
    KCM.Selector.AddItem("HP_POT", KCM.ID.AsSpell(SPELL_ID))

    local button, flyout = flyoutButton("HP_POT", 2)
    KCM.MacroBarFlyout.Apply(button, fcfg{ flyout = true })

    local e = flyout.entries[1]
    t.eq(e:GetAttribute("type"), "spell", "spells click through the spell attribute")
    t.eq(e:GetAttribute("spell"), "Healthstone", "by NAME, which is what the attribute takes")
    t.falsy(firstCall(e.count, "Show"), "a spell carries no stack count")
end)

test("macrobar flyout: Apply hides everything when nothing is available", function(t)
    local KCM = h.loader.loadFullAddon()
    local button, flyout, ind = flyoutButton("HP_POT", 1)

    t.eq(KCM.MacroBarFlyout.Apply(button, fcfg{ flyout = true }), true, "reports handled")
    t.eq(flyout:GetAttribute("kcmEntries"), 0, "no entries to open with")
    t.falsy(flyout._shown, "container hidden")
    t.falsy(ind._shown, "and no arrow teasing an empty popup")
end)

test("macrobar flyout: Apply declines in combat", function(t)
    local KCM = h.loader.loadFullAddon()
    local button = flyoutButton("HP_POT", 1)
    h.loader.mock.setCombat(true)
    t.eq(KCM.MacroBarFlyout.Apply(button, fcfg{ flyout = true }), false,
        "false is the signal callers defer on")
end)

-- ---------------------------------------------------------------------------
-- options-ui-§15 / options-ui-§16 / options-ui-§17 — the settings that were ADDED, and the code that
-- honors them
-- ---------------------------------------------------------------------------
--
-- A setting that is declared and not honored is worse than one that is absent,
-- so every row this adoption added is pinned against the drawing code that reads
-- it rather than against the schema that declares it.

test("macrobar label: the font FACE, FLAGS and SHADOW reach the FontString", function(t)
    -- The canonical font block (options-ui-§16) mandates a face, a flags string
    -- and a shadow; this addon had none of the three and a hard-wired
    -- `labelOutline ~= false and "OUTLINE" or ""`.
    --
    -- red under: reverting applyLabel to the boolean, dropping the fontFile
    -- resolver so the stored face is ignored, or clearing the shadow branch (the
    -- "off" half is what stops a shadow set once from being sticky).
    local KCM = h.loader.loadFullAddon()

    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, {
        buttonSize = 36, buttonLabel = true, labelScale = 25,
        labelFlags = "THICKOUTLINE", labelShadow = true,
    })
    local font = firstCall(btn.label, "SetFont")
    t.truthy(font, "the label's font is set")
    t.eq(font[4], "THICKOUTLINE", "the stored flags string is what is applied, verbatim")
    local offset = firstCall(btn.label, "SetShadowOffset")
    t.truthy(offset, "a shadow offset is written")
    t.ne(offset[2], 0, "and it is a real offset while the shadow is on")

    -- "" is a REAL stored value — the one the "None" label names — and must not
    -- fall through to the default the way nil does.
    local plain = styleButton()
    KCM.MacroBarButton.ApplyStyle(plain, {
        buttonSize = 36, buttonLabel = true, labelScale = 25,
        labelFlags = "", labelShadow = false,
    })
    t.eq(firstCall(plain.label, "SetFont")[4], "",
        "an empty flags string means no flags, not 'fall back to OUTLINE'")
    t.eq(firstCall(plain.label, "SetShadowOffset")[2], 0,
        "and the shadow is CLEARED rather than left from a previous pass")

    -- A cfg with no labelFlags at all -- which AceDB never hands the drawing code,
    -- since defaults/Profile.lua ships one, but a direct caller can -- keeps the
    -- outline, because that is what the setting always was before v3.
    local legacy = styleButton()
    KCM.MacroBarButton.ApplyStyle(legacy, { buttonSize = 36, buttonLabel = true, labelScale = 25 })
    t.eq(firstCall(legacy.label, "SetFont")[4], "OUTLINE",
        "an absent flags string keeps the shipped outline")
end)

test("macrobar label: the class-color companion repaints the label, alpha and all", function(t)
    -- options-ui-§17: the stored ALPHA survives the mode, because no class-color
    -- source carries one — which is also why the swatch is never disabled.
    --
    -- red under: resolving the label color with the raw stored table again, or
    -- letting the class color carry its own alpha through.
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    _G.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    mock.setPlayerClass("MAGE")
    local Core = LibStub("LibKa0s-Core-1.0")
    Core.__ResetClassColor()

    local off = styleButton()
    KCM.MacroBarButton.ApplyStyle(off, {
        buttonSize = 36, buttonLabel = true, labelScale = 25,
        labelColor = { 1, 0.82, 0, 0.4 }, useClassColorLabel = false,
    })
    local c = firstCall(off.label, "SetTextColor")
    t.near(c[2], 1, 0.001, "the swatch paints while the companion is off")
    t.near(c[5], 0.4, 0.001, "with its stored alpha")

    Core.__ResetClassColor()
    local on = styleButton()
    KCM.MacroBarButton.ApplyStyle(on, {
        buttonSize = 36, buttonLabel = true, labelScale = 25,
        labelColor = { 1, 0.82, 0, 0.4 }, useClassColorLabel = true,
    })
    local cc = firstCall(on.label, "SetTextColor")
    t.near(cc[2], 0.25, 0.001, "the class color replaces the stored rgb")
    t.near(cc[5], 0.4, 0.001, "and the stored alpha is still what is applied")

    Core.__ResetClassColor()
    _G.RAID_CLASS_COLORS = nil
end)

test("macrobar button: an unresolvable class falls through to the stored swatch", function(t)
    -- Not to white, not to gray, and not to a tenth color invented for the
    -- occasion (options-ui-§17).
    --
    -- red under: making KCM.SwatchColor answer a substitute hue when
    -- LibKa0s-Core cannot resolve a class.
    local KCM = h.loader.loadFullAddon()
    _G.RAID_CLASS_COLORS = nil
    LibStub("LibKa0s-Core-1.0").__ResetClassColor()

    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, {
        buttonSize = 36, buttonBackdrop = true,
        buttonBackdropColor = { 0.1, 0.2, 0.3, 0.7 }, useClassColorButtonBackdrop = true,
    })
    local fill = firstCall(btn.backdropTex, "SetColorTexture")
    t.near(fill[2], 0.1, 0.001, "the stored red survives an unresolvable class")
    t.near(fill[3], 0.2, 0.001, "…and the green")
    t.near(fill[5], 0.7, 0.001, "…and the alpha, which always applies")
    LibStub("LibKa0s-Core-1.0").__ResetClassColor()
end)

-- ---------------------------------------------------------------------------
-- The drag handle's three tooltips, where they sit, and the mark's tint
--
-- The strip above the bar is `LibKa0s-Widgets-1.0`'s `DragHandle`, and this
-- addon is the host whose separate descriptors the widget's shape was drawn
-- around: `tooltip` for the strip, `helpTooltip` for the ? mark and
-- `closeTooltip` for the X, each with its own title and body.
--
-- WHERE they sit (AD-92-CM, LibKa0s#92): the strip is the bar's title bar, a
-- CHROME element (WowAddonStandards standalone-windows, *Tooltip placement*), so
-- every one of its tooltips is ATTACHED to the strip: centered on it, 2 px
-- (TIP_GAP) above it, flipped below only when the screen has no room above,
-- never at the cursor and never at a corner offset. The widget places them
-- itself (WidgetsDragHandleTip minor 1, LibKa0s-Tooltip-1.0's PlaceAttached on
-- the strip): one absolute point on UIParent's BOTTOMLEFT in screen units. The
-- spec hands it no `tooltipPlace` hook.
--
-- What is observed is what a hover puts on screen -- the frame the tooltip is
-- owned BY, where it is anchored, and its lines in order -- rather than the
-- shape of the table handed to the widget.
-- ---------------------------------------------------------------------------

local TIP_GAP = 2   -- LibKa0s-Tooltip-1.0's TIP_GAP

--- A GameTooltip that records which setter fired with which arguments, and
--- answers the reads the placement makes: its width (`width`, 200 unless given),
--- its height (80) and its effective scale (1). The shared frame stub answers
--- every method with itself, so it can say a tooltip was built but not what it
--- says, who owns it or where it sits.
local function recordingTooltip(width)
    local gt = { calls = {}, points = {} }
    local function record(name)
        return function(_, ...) gt.calls[#gt.calls + 1] = { name, ... } end
    end
    gt.SetOwner = record("SetOwner")
    gt.SetText  = record("SetText")
    gt.AddLine  = record("AddLine")
    gt.Show     = record("Show")
    gt.ClearAllPoints    = function() gt.points = {} end
    gt.SetPoint          = function(_, ...) gt.points[#gt.points + 1] = { ... } end
    gt.GetWidth          = function() return width or 200 end
    gt.GetHeight         = function() return 80 end
    gt.GetEffectiveScale = function() return 1 end
    return gt
end

--- Give the placement real numbers to read: a 1000 x 800 screen at scale 1 and
--- the strip at `g.left`, `g.bottom`, `g.width` x `g.height` in its own units at
--- effective scale `g.scale` (1 unless given). By default the strip sits
--- mid-screen, 400..600 x 500..516, with room above it.
local function armGeometry(handle, g)
    g = g or {}
    local l, b = g.left or 400, g.bottom or 500
    local w, hgt = g.width or 200, g.height or 16
    _G.UIParent.GetWidth          = function() return 1000 end
    _G.UIParent.GetHeight         = function() return 800 end
    _G.UIParent.GetRight          = function() return 1000 end
    _G.UIParent.GetTop            = function() return 800 end
    _G.UIParent.GetEffectiveScale = function() return 1 end
    handle.GetLeft           = function() return l end
    handle.GetBottom         = function() return b end
    handle.GetRight          = function() return l + w end
    handle.GetTop            = function() return b + hgt end
    handle.GetEffectiveScale = function() return g.scale or 1 end
end

--- The full addon, its bar built, and the strip's geometry armed (`g`, as
--- armGeometry's).
-- On Ka0s Default by name: the handle's tints below are its values, and the forever kit profile's
-- default skin is WoW Forever (skinning-§2).
local function bench(g)
    local KCM = h.loader.wearKa0s(h.loader.loadFullAddon())
    local _, _, handle = support.buildBar(KCM)
    armGeometry(handle, g)
    return KCM, handle
end

--- Hover `frame` and read back every owner it was given, the last one, the
--- point it was anchored at, and the lines it ended up with, title first. The
--- widget reads its descriptor on every OnEnter, so each call is a fresh answer
--- rather than a replay of the first.
local function hover(frame)
    _G.GameTooltip = recordingTooltip()
    frame:GetScript("OnEnter")(frame)
    local rec = { lines = {}, owners = {} }
    for _, c in ipairs(_G.GameTooltip.calls) do
        if c[1] == "SetOwner" then
            rec.owner, rec.anchor = c[2], c[3]
            rec.owners[#rec.owners + 1] = c[3]
        elseif c[1] == "SetText" or c[1] == "AddLine" then
            rec.lines[#rec.lines + 1] = c[2]
        elseif c[1] == "Show" then
            rec.shown = true
        end
    end
    rec.point = _G.GameTooltip.points[1]
    return rec
end

local function hasLine(rec, needle)
    for _, l in ipairs(rec.lines) do if l == needle then return true end end
    return false
end

--- Assert `rec` is a chrome tooltip attached ABOVE the default mid-screen strip:
--- owned once, by UIParent at ANCHOR_NONE, its BOTTOM on one absolute point of
--- UIParent's BOTTOMLEFT, centered on the strip (x 500) and TIP_GAP over its top
--- (516 + 2).
local function assertAboveStrip(t, rec, what)
    t.eq(#rec.owners, 1, what .. ": owned once")
    t.eq(rec.owner, _G.UIParent, what .. ": owned by UIParent")
    t.eq(rec.anchor, "ANCHOR_NONE", what .. ": never the cursor, never a corner anchor")
    t.truthy(rec.point, what .. ": anchored")
    t.eq(rec.point and rec.point[1], "BOTTOM", what .. ": its bottom edge")
    t.truthy(rec.point and rawequal(rec.point[2], _G.UIParent), what .. ": one absolute point")
    t.eq(rec.point and rec.point[3], "BOTTOMLEFT", what)
    t.eq(rec.point and rec.point[4], 500, what .. ": centered on the strip, not on the frame hovered")
    t.eq(rec.point and rec.point[5], 516 + TIP_GAP, what .. ": the gap above the strip's top")
end

local MARK_BODY   = "Drag a button onto another to swap them."
local MARK_FOOTER = "Only Consumable Master macros can sit on this bar."
local LOCKED_LINE = "Locked. Unlock the bar to drag this handle — /cm unlock."
local UNLOCK_LINE = "Lock the bar to hide this handle — /cm lock."

-- RE-PINNED by AD-92-CM (this case and the mark's, the X's and the settings
-- mark's below): they asserted the tooltip TOPLEFT on the strip's TOPRIGHT, the
-- beside-the-strip placement of MB.PlaceTooltipBeside (TP-CM-02); the rule now
-- reads that as a body placement on a chrome element.
-- red under: dropping `tooltip` so the mark's descriptor is drawn for both, or a
-- spec that hands the widget a beside-the-strip `tooltipPlace` again.
test("macrobar handle: the strip's tooltip is the addon's, attached above the strip",
    function(t)
        local _, handle = bench()
        local rec = hover(handle)
        t.eq(rec.lines[1], "Consumable Master", "the addon's name heads the strip's tooltip")
        assertAboveStrip(t, rec, "strip")
        t.truthy(rec.shown, "the tooltip is actually shown")
    end)

-- red under: dropping `helpTooltip`, which would fall the mark back to the
-- strip's descriptor -- same title, none of the long-form help -- or a mark
-- whose tooltip is attached to the mark rather than to its strip.
test("macrobar handle: the mark's tooltip is the bar's, attached above the strip",
    function(t)
        local _, handle = bench()
        local help = handle.help
        t.truthy(help, "the widget drew the help mark")
        local rec = hover(help)
        t.eq(rec.lines[1], "Macro bar", "the mark carries its own title")
        assertAboveStrip(t, rec, "? mark")
        t.truthy(hasLine(rec, MARK_BODY), "…with the mark's own body")
        t.truthy(hasLine(rec, MARK_FOOTER), "…and its own footer")
    end)

-- The descriptors exist to be different in what they SAY; where they sit is
-- one rule. Asserting each alone would pass a build where one quietly became
-- the other.
test("macrobar handle: the strip and the mark draw two distinct tooltips in one place",
    function(t)
        local _, handle = bench()
        local strip = hover(handle)
        local mark  = hover(handle.help)
        t.ne(strip.lines[1], mark.lines[1], "two titles")
        t.falsy(hasLine(strip, MARK_BODY), "the strip does not carry the mark's body")
        t.truthy(#mark.lines > #strip.lines, "the mark is the long-form one of the pair")
        t.truthy(strip.point, "the strip's tooltip was placed")
        t.eqList(strip.point, mark.point, "one position for the strip and its mark, not two")
    end)

-- ---------------------------------------------------------------------------
-- Where the strip's tooltips sit: the chrome rule (AD-92-CM, LibKa0s#92)
--
-- RE-PINNED by AD-92-CM. Until then the strip handed the widget
-- MB.PlaceTooltipBeside (TP-CM-02) as its `tooltipPlace`, and six cases drove
-- that function directly: right when it fits, left near the screen's right edge,
-- a mark resolving to its strip, screen pixels on a scaled strip, a secret read
-- and a nil read. The function is retired, and the six became the cases below,
-- one for one, driven through a real hover: above mid-screen, below at the
-- screen's top, every mark placed by its strip, screen units on a scaled strip,
-- and a secret and a nil read falling back to the widget's attached point; plus
-- the hook being gone.
-- ---------------------------------------------------------------------------

test("macrobar handle: the retired beside-the-strip hook is gone", function(t)
    local KCM = bench()
    t.eq(KCM.MacroBar.PlaceTooltipBeside, nil, "MB.PlaceTooltipBeside is retired")
end)

-- red under: the retired beside placement (TOPLEFT on the strip's TOPRIGHT).
test("macrobar handle: mid-screen, the strip's tooltip sits centered above the strip",
    function(t)
        local _, handle = bench()
        local rec = hover(handle)
        t.eq(rec.point and rec.point[1], "BOTTOM")
        t.eq(rec.point and rec.point[4], 500, "centered on the strip's 400..600")
        t.eq(rec.point and rec.point[5], 518, "its bottom TIP_GAP over the strip's top (516)")
    end)

-- red under: a placement that always opens above (778 + 80 runs off an 800 px
-- screen).
test("macrobar handle: at the screen's top, the strip's tooltip flips below the strip",
    function(t)
        local _, handle = bench({ bottom = 760 })
        local rec = hover(handle)
        t.eq(rec.point and rec.point[1], "TOP", "its top edge")
        t.truthy(rec.point and rawequal(rec.point[2], _G.UIParent), "one absolute point")
        t.eq(rec.point and rec.point[4], 500, "still centered on the strip")
        t.eq(rec.point and rec.point[5], 760 - TIP_GAP, "TIP_GAP under the strip's bottom")
    end)

-- The widget hands the placement the strip whichever of its frames is hovered:
-- one position for the strip and all three marks, not four. The marks' own
-- edges read 0 here, so a mark placed by itself would land at x 100.
test("macrobar handle: every mark's tooltip is placed by its strip", function(t)
    local _, handle = bench()
    local strip = hover(handle)
    for _, key in ipairs({ "help", "close", "settings" }) do
        local mark = handle[key]
        t.truthy(mark, key .. " mark drawn")
        if mark then
            t.eqList(hover(mark).point, strip.point, key .. " mark: placed by the strip")
        end
    end
end)

-- red under: reading the strip's raw edges (its own units) as screen units. At
-- scale 2 a strip of 200..300 x 250..258 own units spans 400..600 x 500..516 on
-- screen, the default strip's place. The bar takes the master scale and the
-- strip inherits it.
test("macrobar handle: a scaled strip is placed in screen units", function(t)
    local _, handle = bench({ left = 200, bottom = 250, width = 100, height = 8, scale = 2 })
    assertAboveStrip(t, hover(handle), "scaled strip")
end)

--- Assert `rec` fell back to the widget's own attached point: the tooltip's
--- BOTTOM on the strip's TOP, TIP_GAP up, owned by UIParent at ANCHOR_NONE.
local function assertFallbackAbove(t, rec, handle, what)
    t.truthy(rawequal(rec.owner, _G.UIParent), what .. ": still owned by UIParent")
    t.eq(rec.anchor, "ANCHOR_NONE", what .. ": at ANCHOR_NONE")
    for _, a in ipairs(rec.owners) do
        t.truthy(a ~= "ANCHOR_CURSOR", what .. ": never re-owned at the cursor")
    end
    t.eqList(rec.point, { "BOTTOM", handle, "TOP", 0, TIP_GAP }, what .. ": attached above the strip")
    t.truthy(rec.shown, what .. ": and shown")
end

test("macrobar handle: a secret strip read falls back to the attached point, never a guess",
    function(t)
        local _, handle = bench()
        local secret = {}
        handle.GetTop = function() return secret end
        local prior = rawget(_G, "issecretvalue")
        _G.issecretvalue = function(v) return rawequal(v, secret) end
        local rec = hover(handle)
        _G.issecretvalue = prior
        assertFallbackAbove(t, rec, handle, "secret top")
    end)

test("macrobar handle: a nil strip read falls back to the attached point", function(t)
    -- A strip not yet laid out answers nil for its edges in the client.
    local _, handle = bench()
    handle.GetTop = function() return nil end
    assertFallbackAbove(t, hover(handle), handle, "nil top")
end)

-- A hover whose placement cannot read the strip still shows its tooltip: the
-- widget falls back to its own placement with the same lines. Through LibKa0s
-- v1.104.0 that fallback re-owned the tooltip at the cursor (WidgetsDragHandle 4);
-- since v1.105.0 (WidgetsDragHandleTip 1, LibKa0s#92) it is never the cursor: the
-- tooltip stays owned by UIParent at ANCHOR_NONE and attaches to the strip
-- (anti-pattern #119): above it, centered, since the re-cut v1.105.0 (smoke
-- round 1, SR-L1; it was below at the first cut), and below only without room.
-- red under: a placement that anchors on a guess and answers true anyway.
test("macrobar handle: an unreadable strip falls back above the strip with the same tooltip",
    function(t)
        local _, handle = bench()
        handle.GetRight = function() return nil end
        local rec = hover(handle)
        t.truthy(rawequal(rec.owner, _G.UIParent), "still owned by UIParent")
        t.eq(rec.anchor, "ANCHOR_NONE", "at ANCHOR_NONE")
        for _, a in ipairs(rec.owners) do
            t.truthy(a ~= "ANCHOR_CURSOR", "never re-owned at the cursor")
        end
        t.truthy(rec.point ~= nil, "the library's fallback anchors it")
        t.eq(rec.point and rec.point[1], "BOTTOM", "its bottom edge")
        t.truthy(rec.point and rawequal(rec.point[2], handle), "to the strip")
        t.eq(rec.point and rec.point[3], "TOP", "above it, not beside a strip it could not read")
        t.truthy(hasLine(rec, "Consumable Master"), "the same tooltip, still shown")
        t.truthy(rec.shown, "and shown")
    end)

-- The lock can change between two hovers of the same strip, which is why both
-- lock-dependent lines are written as FUNCTIONS in the descriptor. A plain
-- string would be resolved once, at build, and then be wrong for the rest of
-- the session.
--
-- red under: writing either line as a string computed when the handle is built.
test("macrobar handle: the mark's lock line is re-read on every hover", function(t)
    local KCM, handle = bench()
    local help = handle.help

    KCM.MacroBar.SetLocked(true)
    local locked = hover(help)
    KCM.MacroBar.SetLocked(false)
    local unlocked = hover(help)

    t.truthy(hasLine(locked, LOCKED_LINE), "locked, the footer says how to unlock")
    t.falsy(hasLine(locked, UNLOCK_LINE), "and not the other way round")
    t.truthy(hasLine(unlocked, UNLOCK_LINE), "unlocked, it says how to put the strip away")
    t.falsy(hasLine(unlocked, LOCKED_LINE), "the first hover's line did not survive the second")
end)

-- The mark brightens under the cursor only where a right-click is wired, and
-- nothing is wired here: `DragHandle` is handed no `onRightClick`, so the
-- widget registers no click at all. At LibKa0s v1.48.0 the brighten was
-- unconditional, so this addon's mark lit up and then did nothing — a control
-- advertising itself and then declining. v1.48.1 chooses the over-tint from
-- `spec.onRightClick`, and this is the host that case was found on.
--
-- red under: an unconditional HELP_TINT_OVER on OnEnter, or an `onRightClick`
-- added here without the affordance that a click deserves.
test("macrobar handle: the mark holds its resting gray, because no click is wired here",
    function(t)
        local _, handle = bench()
        local help = handle.help
        -- The mock's CreateTexture hands the FRAME back, so the widget's icon IS
        -- `help`; recording on it records every tint the mark takes.
        local tints = {}
        help.SetVertexColor = function(_, r, g, b) tints[#tints + 1] = { r, g, b } end

        _G.GameTooltip = recordingTooltip()
        help:GetScript("OnEnter")(help)
        t.eq(#tints, 1, "the hover tinted the art once")
        t.eqList(tints[1], { 0.7, 0.7, 0.72 }, "…to the resting gray, not to full white")

        help:GetScript("OnLeave")(help)
        t.eqList(tints[2], { 0.7, 0.7, 0.72 }, "and leaving it leaves the same tint behind")
    end)

-- The strip's fit (LibKa0s#68). `applyLayout` moves the bar's scale and width, and the strip measures
-- its title at that scale (WidgetsDragHandle minor 10), so a fit taken before the layout pass is stale
-- until the next show. `MB.Update` is applyLayout's one caller, and it runs applyLock straight after.
--
-- red under: dropping applyLock from MB.Update, or running it ahead of applyLayout.
test("macrobar handle: a layout pass while unlocked refits the strip at the new scale and width",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local _, bar, handle = support.buildBar(KCM)
        local c = KCM.db.profile.macroBar
        c.locked = false

        local log, width = {}, nil
        bar.SetScale = function(_, v) log[#log + 1] = "scale " .. v end
        bar.SetSize  = function(_, w) width = w; log[#log + 1] = "size" end
        bar.GetWidth = function() return width end
        handle.ApplyWidth = function(_, w) log[#log + 1] = "fit " .. tostring(w) end

        c.scale = 1.5
        KCM.MacroBar.Update()

        t.truthy(width and width > 0, "the pass sized the bar")
        t.eqList(log, { "scale 1.5", "size", "fit " .. width },
            "the strip is fitted once, after the scale and the width, floored at the new width")
    end)

-- ---------------------------------------------------------------------------
-- The drag handle's close mark (X-01, X-02, X-05)
--
-- The X turns off the smallest thing the strip drags: the macro bar, through
-- `macroBar.enabled` and the same seam as `/cm bar off` and the Macro Bar
-- page's Enabled row. Never `profile.enabled` -- that would stop the macro
-- writes the player's action bars rely on -- never the lock, and never the
-- position, so `/cm bar on` puts the bar back where it was.
-- ---------------------------------------------------------------------------

local X_ACK  = "Macro bar hidden. /cm bar on brings it back."
local X_BACK = "/cm bar on brings it back."

--- Every path written through the schema seam while `fn` runs, in order.
local function recordWrites(KCM, fn)
    local paths = {}
    local realSet = KCM.Schema.Set
    KCM.Schema.Set = function(self, path, ...)
        paths[#paths + 1] = path
        return realSet(self, path, ...)
    end
    fn()
    KCM.Schema.Set = realSet
    return paths
end

local function clickX(handle)
    handle.close:GetScript("OnClick")(handle.close, "LeftButton")
end

-- red under: a strip built without `onClose`, or an X that writes
-- `profile.enabled`, the lock or the position, or writes the flag by hand.
test("macrobar handle: the X hides the bar through macroBar.enabled and says the way back",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local seen, _, handle = support.buildBar(KCM)
        t.truthy(handle.close, "the strip carries a close mark")
        local c = KCM.db.profile.macroBar
        local pos = { c.point, c.relPoint, c.x, c.y }
        local locked = c.locked
        h.loader.mock.output = {}

        local paths = recordWrites(KCM, function() clickX(handle) end)

        t.eqList(paths, { "macroBar.enabled" }, "exactly the bar's enable row, through the seam")
        t.eq(c.enabled, false, "the bar's flag is off")
        t.eq(KCM.db.profile.enabled, true, "the addon stays on: its macros are still written")
        t.eq(c.locked, locked, "the lock is untouched")
        t.eqList({ c.point, c.relPoint, c.x, c.y }, pos, "the position is untouched")
        t.eq(seen.barVisible, false, "the bar left the screen")
        local said = table.concat(h.loader.mock.output, "\n")
        t.truthy(said:find(X_ACK, 1, true), "the chat line names the way back")

        KCM.MacroBar.SetEnabled(true)
        t.eq(seen.barVisible, true, "/cm bar on brings it back")
        t.eqList({ c.point, c.relPoint, c.x, c.y }, pos, "…where it was")
    end)

-- red under: dropping `closeTooltip` (the X would show the strip's tooltip)
-- or a tooltip that no longer names the way back.
test("macrobar handle: the X's tooltip says what the click does and the way back", function(t)
    local _, handle = bench()
    local rec = hover(handle.close)
    t.eq(rec.lines[1], "Hide the macro bar", "the X carries its own title")
    assertAboveStrip(t, rec, "X mark")
    t.truthy(hasLine(rec, "Click to hide the macro bar. Its layout and position are kept."),
        "…says what the click does")
    t.truthy(hasLine(rec, X_BACK), "…and carries the chat line's way back")
end)

-- The X and the settings mark widen the strip: the widget reserves each mark's
-- frame on both sides of the label (Widgets 10.3, `handle:Reserve()`; the
-- settings mark's share since DragHandle minor 14, AD-86-CM). This addon pins
-- no Measure literal; the reserve is read from the library's own constants.
-- RE-PINNED at AD-86-CM: it was RESERVE + one mark's frame (the X alone).
test("macrobar handle: the X and the settings mark widen the label's reserve by a frame each",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local _, _, handle = support.buildBar(KCM)
        local D = LibStub("LibKa0s-Widgets-1.0").DRAG_HANDLE
        t.eq(handle:Reserve(), D.RESERVE + 2 * (D.HELP_HIT + D.CLOSE_GAP),
            "the reserve is the strip's with a close mark and a settings mark")
    end)

-- ---------------------------------------------------------------------------
-- The drag handle's settings mark (AD-86-CM, LibKa0s#86, DragHandle minor 14)
--
-- The strip opts in with `settings = true`: no onSettings of its own, so a
-- click goes through LibKa0s-Core-1.0's registry by the strip's owner, which
-- is this addon's folder -- the same key the launcher registers its opener
-- under (core/LauncherSetup.lua's `name`). One opener, two doors.
-- ---------------------------------------------------------------------------

-- red under: a strip built without `settings`.
test("macrobar handle: the strip carries a settings mark left of the X", function(t)
    local KCM = h.loader.loadFullAddon()
    local _, _, handle = support.buildBar(KCM)
    t.truthy(handle.settings, "the widget drew the settings mark")
    t.truthy(handle.settings ~= handle.close and handle.settings ~= handle.help,
        "…as its own frame, not the X or the ?")
end)

-- red under: a strip without `settings`, or one whose click opens anything but
-- the launcher's opener (KCM.Options.Open, the published panel seam).
test("macrobar handle: the settings mark's left click opens Consumable Master's settings",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local _, _, handle = support.buildBar(KCM)
        local opens = 0
        KCM.Options.Open = function() opens = opens + 1; return true end
        t.truthy(handle.settings, "the strip carries a settings mark")
        local c = KCM.db.profile.macroBar
        local enabled, locked = c.enabled, c.locked
        handle.settings:GetScript("OnClick")(handle.settings, "LeftButton")
        t.eq(opens, 1, "the panel was asked to open, once")
        t.eq(c.enabled, enabled, "the bar is not hidden")
        t.eq(c.locked, locked, "the lock is untouched")
    end)

-- red under: dropping `settingsTooltip` (the mark would show the strip's
-- tooltip, titled for the addon, with the drag line).
test("macrobar handle: the settings mark's tooltip says what the click does", function(t)
    local _, handle = bench()
    t.truthy(handle.settings, "the strip carries a settings mark")
    local rec = hover(handle.settings)
    t.eq(rec.lines[1], "Open settings", "the mark carries its own title")
    assertAboveStrip(t, rec, "settings mark")
    t.truthy(hasLine(rec, "Click to open Consumable Master's settings."),
        "…says what the click does")
end)

-- The bar is a secure frame: its hide waits for PLAYER_REGEN_ENABLED, through
-- the same deferral `/cm bar off` takes. The flag lands at once.
--
-- red under: an X that hides the frame directly, or one that drops the write
-- in combat instead of letting the apply seam defer it.
test("macrobar handle: in combat the X stores the flag and the bar hides at combat end",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local seen, _, handle = support.buildBar(KCM)
        seen.barVisible = true
        h.loader.mock.setCombat(true)
        clickX(handle)
        t.eq(KCM.db.profile.macroBar.enabled, false, "the flag is written at once")
        t.eq(seen.barVisible, true, "the secure bar is not hidden mid-combat")
        h.loader.mock.setCombat(false)
        KCM.MacroBar.FlushPending()
        t.eq(seen.barVisible, false, "the bar hides when combat ends")
    end)
