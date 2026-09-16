-- tests/test_macrobar_button.lua — the macro bar's chrome appliers
-- (MacroBarButton.ApplyStyle), the flyout's bind/apply pass, and the
-- options-ui-§15/§16/§17 rows those appliers are what honors.
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
local fcfg = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua").fcfg

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
    t.eq(col[3], 1, "a missing green falls back on its own")
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

test("macrobar flyout: Apply binds an owned item entry with its chrome", function(t)
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
    t.eq(firstCall(e.border, "SetBackdropBorderColor")[2], 1, "border color defaults to white")
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
-- options-ui-§15 / §16 / §17 — the settings that were ADDED, and the code that
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
