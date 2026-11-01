-- tests/skin_switch_facts.lua — Kit.skinSwitch: what this addon paints, for the kit's switch test
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). Coverage is this list: a surface
-- left out is not tested, and an audit reads it.
--
-- ONE SETTER PER SURFACE. The kit calls a surface changed when anything it draws moved, so the bar's
-- edge style moving would hide a border color that stayed put. `isolate` hands the kit a sink holding
-- only the setter under test, which is what makes a stuck color fail here.
--
-- A FRESH ADDON PER CASE. `facts.skin` is read once per case, and every mock.install wipes LibStub,
-- so it builds the addon each surface then draws on. Building installs the mock's chat capture as
-- print; the real one goes back, as in the runner.
--
-- COMPANIONS. A surface with one is on the skin only while it is on, so `companion` writes it and
-- the kit's second pass leaves the surface out. The rest (the wash, the flyout's arrow, the count's
-- color) have no setting and must follow under an ignored Scope too; the count's face and shadow are
-- `scope = "fonts"`, the settings surfaces `scope = "panel"`.

local ROOT = _G.KCM_TEST_ROOT or "."

local buildWidget = dofile(ROOT .. "/tests/skin_widget_support.lua")
local support = dofile(ROOT .. "/tests/macrobar_support.lua")

--- A stand-in for a client object: every method is a no-op answering the object.
local function fake(kind, fontSize)
    local f = {}
    local special = {
        GetObjectType = function() return kind end,
        GetFont = function() return "Fonts\\ARIALN.TTF", fontSize end,
        GetFrameLevel = function() return 1 end,
        GetStringWidth = function() return 0 end,
        GetShadowOffset = function() return 1, -1 end,
        GetShadowColor = function() return 0, 0, 0, 1 end,
    }
    return setmetatable(f, { __index = function(_, key)
        return special[key] or function() return f end
    end })
end

--- `frame`'s calls to `setter`, on an object that has no other: see the note above.
local function isolate(frame, setter)
    local sink = { [setter] = function() end }
    rawset(frame, setter, function(_, ...) return sink[setter](sink, ...) end)
    return sink
end

return function(L, owner, realprint)
    local KCM
    local cleanups = {}

    local function bar()
        return KCM.db.profile.macroBar
    end

    local function repaintBar() KCM.MacroBar.Update() end

    --- The real bar's `setter`.
    local function onBar(setter)
        return function()
            local _, frame = support.buildBar(KCM)
            return isolate(frame, setter)
        end, repaintBar
    end

    local function washTexture()
        local _, frame = support.buildBar(KCM)
        return isolate(frame.moveHint.tex, "SetColorTexture")
    end

    --- A button's region `key`, drawn through the appearance pass the bar runs.
    local function onButton(key, setter)
        local btn
        return function()
            btn = fake("Button")
            btn.catKey = "FOOD"
            btn.border, btn.icon, btn.backdropTex = fake("Frame"), fake("Texture"), fake("Texture")
            btn.count, btn.label = fake("FontString", 14), fake("FontString")
            local sink = isolate(btn[key], setter)
            KCM.MacroBarButton.ApplyStyle(btn, bar())
            return sink
        end, function() KCM.MacroBarButton.ApplyStyle(btn, bar()) end
    end

    --- The flyout's panel.
    local function onFlyout(setter)
        local flyout
        return function()
            flyout = { bg = fake("Frame") }
            local sink = isolate(flyout.bg, setter)
            KCM.MacroBarFlyout.ApplyBackdrop(flyout, bar())
            return sink
        end, function() KCM.MacroBarFlyout.ApplyBackdrop(flyout, bar()) end
    end

    --- The flyout's indicator part `key`.
    local function onIndicator(key, setter)
        local button
        return function()
            button = fake("Button")
            button.indicator = fake("Frame")
            button.indicator.shade, button.indicator.arrow = fake("Texture"), fake("Texture")
            button.flyout = fake("Frame")
            button.flyout.entries, button.flyout.bg = {}, fake("Frame")
            local sink = isolate(button.indicator[key], setter)
            pcall(KCM.MacroBarFlyout.Apply, button, bar(), {})
            return sink
        end, function() pcall(KCM.MacroBarFlyout.Apply, button, bar(), {}) end
    end

    local function companion(key)
        return function(on) KCM.db.profile.macroBar[key] = on end
    end

    --- One custom settings widget's region, as it draws on acquire.
    local function onWidget(rel, widgetType, key, setup)
        return function()
            local w, _, cleanup = buildWidget(KCM, rel, widgetType)
            cleanups[#cleanups + 1] = cleanup
            w:OnAcquire()
            if setup then setup(w) end
            return w[key]
        end
    end

    local function iconMark(w)
        w:SetMark(KCM.SkinPanelMarkOpts("atlas:transmog-icon-remove", "close", "btn.icon"))
    end

    local function itemMarks(w)
        w.owned, w.isPick = true, true
        w:RefreshDisplay()
    end

    local function panelGlyph()
        local tex = fake("Texture")
        local button = fake("Button")
        button.GetNormalTexture = function() return tex end
        KCM.SkinPanelGlyph(button, "Interface\\Buttons\\UI-CheckBox-Check", "confirm", "sem.good")
        return isolate(tex, "SetVertexColor")
    end

    local surfaces = {}

    local function add(name, build, paint, extra)
        local s = { name = name, build = build, paint = paint }
        for k, v in pairs(extra or {}) do s[k] = v end
        surfaces[#surfaces + 1] = s
    end

    local function hud(name, key, build, paint)
        add(name, build, paint, key and { companion = companion(key) } or nil)
    end

    hud("the bar's fill", "barBackdropColorFromSkin", onBar("SetBackdropColor"))
    hud("the bar's edge color", "barBorderColorFromSkin", onBar("SetBackdropBorderColor"))
    hud("the bar's edge style", "barBorderStyleFromSkin", onBar("SetBackdrop"))
    add("the unlocked wash", washTexture, repaintBar)
    hud("a button's backdrop", "buttonBackdropColorFromSkin", onButton("backdropTex", "SetColorTexture"))
    hud("a button's edge color", "buttonBorderColorFromSkin", onButton("border", "SetBackdropBorderColor"))
    hud("a button's edge style", "buttonBorderStyleFromSkin", onButton("border", "SetBackdrop"))
    hud("a button's label color", "labelColorFromSkin", onButton("label", "SetTextColor"))
    hud("a button's label face", "labelFontFromSkin", onButton("label", "SetFont"))
    hud("a button's label shadow", "labelShadowFromSkin", onButton("label", "SetShadowColor"))
    hud("the stack count's color", nil, onButton("count", "SetTextColor"))
    do
        local build, paint = onButton("count", "SetFont")
        add("the stack count's face", build, paint, { scope = "fonts" })
        build, paint = onButton("count", "SetShadowColor")
        add("the stack count's shadow", build, paint, { scope = "fonts" })
    end
    hud("the flyout's fill", "flyoutBackdropColorFromSkin", onFlyout("SetBackdropColor"))
    hud("the flyout's edge color", "barBorderColorFromSkin", onFlyout("SetBackdropBorderColor"))
    hud("the flyout's edge style", "barBorderStyleFromSkin", onFlyout("SetBackdrop"))
    hud("the flyout indicator's shade", "flyoutShadeColorFromSkin", onIndicator("shade", "SetColorTexture"))
    hud("the flyout indicator's arrow", nil, onIndicator("arrow", "SetVertexColor"))

    local panel = { scope = "panel" }
    add("the icon button's mark", onWidget("modules/KCMIconButton.lua", "KCMIconButton", "image", iconMark), nil, panel)
    add("the icon button's label", onWidget("modules/KCMIconButton.lua", "KCMIconButton", "label"), nil, panel)
    add("the score button's mark", onWidget("modules/KCMScoreButton.lua", "KCMScoreButton", "image", iconMark), nil, panel)
    add("an item row's owned mark", onWidget("modules/KCMItemRow.lua", "KCMItemRow", "ownedTex", itemMarks), nil, panel)
    add("an item row's pick mark", onWidget("modules/KCMItemRow.lua", "KCMItemRow", "pickTex", itemMarks), nil, panel)
    add("an item row's name", onWidget("modules/KCMItemRow.lua", "KCMItemRow", "label"), nil, panel)
    add("an item row's hand tag", onWidget("modules/KCMItemRow.lua", "KCMItemRow", "handTag"), nil, panel)
    add("the drag icon's label", onWidget("modules/KCMMacroDragIcon.lua", "KCMMacroDragIcon", "label"), nil, panel)
    add("a reorder row's glyph", panelGlyph, nil, panel)

    return {
        owner = owner,
        skin = function()
            KCM = L.loadFullAddon()
            _G.print = realprint
            return LibStub("LibKa0s-Skin-1.0")
        end,
        reset = function()
            for i = #cleanups, 1, -1 do
                cleanups[i]()
                cleanups[i] = nil
            end
        end,
        surfaces = surfaces,
    }
end
