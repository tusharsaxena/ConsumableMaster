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

    --- A flyout ENTRY's region `key` (SD-SK-CM.2): FO.Apply binds one entry the way the bar's
    --- refresh does, through the bar buttons' own appliers, on an entry the pool already holds (the
    --- pool's creation is secure-template work no paint depends on).
    local function onEntry(key, setter)
        local button
        local function apply() pcall(KCM.MacroBarFlyout.Apply, button, bar(), {}) end
        return function()
            local FO = KCM.MacroBarFlyout
            local candidates = FO.Candidates
            FO.Candidates = function() return { 6948 } end
            cleanups[#cleanups + 1] = function() FO.Candidates = candidates end
            local entry = fake("Button")
            entry.backdropTex, entry.icon, entry.border = fake("Texture"), fake("Texture"), fake("Frame")
            entry.count, entry.cooldown = fake("FontString", 14), fake("Cooldown")
            button = fake("Button")
            button.catKey = "FOOD"
            button.indicator = fake("Frame")
            button.indicator.shade, button.indicator.arrow = fake("Texture"), fake("Texture")
            button.flyout = fake("Frame")
            button.flyout.entries, button.flyout.bg = { entry }, fake("Frame")
            local sink = isolate(entry[key], setter)
            apply()
            return sink
        end, apply
    end

    --- The macro bar's fallback tooltip (core/MacroDisplay.lua, a macro with no pick): its title and
    --- body lines written into GameTooltip in `gtip.title` and `gtip.value` (skinning-§7: the lines,
    --- never the frame). Read on every hover, so the paint is the next hover.
    local function onBarTooltip()
        local slot = fake("Button")
        local function hover() KCM.MacroDisplay.SetTooltip(slot, "KCM_FOOD") end
        return function()
            local MD, tip, info = KCM.MacroDisplay, rawget(_G, "GameTooltip"), rawget(_G, "GetMacroInfo")
            local pick, index = MD.PickID, MD.MacroIndex
            MD.PickID = function() return nil end
            MD.MacroIndex = function() return 1 end
            _G.GetMacroInfo = function() return "KCM_FOOD", 134400, "/use Conjured Mana Bun" end
            _G.GameTooltip = fake("GameTooltip")
            cleanups[#cleanups + 1] = function()
                MD.PickID, MD.MacroIndex, _G.GameTooltip, _G.GetMacroInfo = pick, index, tip, info
            end
            hover()
            return _G.GameTooltip
        end, hover
    end

    --- A string the settings pages write with a color escape: `text()` re-run as a page re-render
    --- writes it. `kind` and `setter` name the region and how the line goes on.
    local function onEscape(kind, setter, text)
        local obj
        local function draw() obj[setter](obj, text()) end
        return function()
            obj = fake(kind)
            draw()
            return obj
        end, draw
    end

    local function warnLine()
        return KCM.Settings.MacrosPage.WarnText("(empty)")
    end

    local function scoreDesc()
        return KCM.Settings.MacrosPage.ScoreTooltipDesc({
            signals = { { label = "Healing", value = 1234, note = "per second" } },
            summary = "Ranked first",
        })
    end

    --- A reorder row's carried copy, dressed from what the Stat Priority and Buttons lists hand the
    --- library's ReorderList (settings/StatPriority.lua, settings/MacroBarSlots.lua): the icon's
    --- tint from KCM.SkinPanelGhost and the text in the row's role color, set the way the library's
    --- raiseGhost sets them. The pages hand them again on every render.
    local function onGhost(part)
        local obj
        local function draw()
            if part == "icon" then
                local _, c = KCM.SkinPanelGhost("Interface\\Buttons\\UI-CheckBox-Check", "confirm", "sem.good")
                c = c or { 1, 1, 1 }
                obj:SetVertexColor(c[1], c[2], c[3])
            else
                obj:SetTextColor(KCM.SkinPanelColor("text.accent"))
            end
        end
        return function()
            obj = fake(part == "icon" and "Texture" or "FontString")
            draw()
            return obj
        end, draw
    end

    --- The icon button's hover wash (modules/KCMIconButton.lua, `cm.iconHover`), read at hover time.
    local function onIconHover()
        local w
        local function hover() w.frame:GetScript("OnEnter")(w.frame) end
        return function()
            local widget, _, cleanup = buildWidget(KCM, "modules/KCMIconButton.lua", "KCMIconButton")
            w = widget
            cleanups[#cleanups + 1] = cleanup
            w:OnAcquire()
            hover()
            return w.frame.hoverBG
        end, hover
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

    --- A settings icon's edge (R5-ICON, KCM.SkinPanelIcon): S.IconBorder draws it on a holder of the
    --- widget's edge frame, which the harness's plain frame does not list as a child, so the surface
    --- is the edge's own top line, read off the library's record of that frame (as
    --- tests/test_icon_rule.lua reads its color).
    local function onIconEdge(rel, widgetType, key, setup)
        local widget = onWidget(rel, widgetType, key, setup)
        return function()
            local edgeFrame = widget()
            local rec = LibStub("LibKa0s-Skin-1.0").painted[edgeFrame]
            return rec and rec.regions.edgeTop
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

    --- A settings description (settings/Panel.lua's Helpers.Label, "medium"), drawn as a page
    --- re-render draws it: the pool hands the same Label back, KCM.SkinAcquire paints it, and the
    --- font goes on through the widget (SD-SK-CM.1). The widget is AceGUI's Label in shape: its
    --- SetFontObject sets its `label` FontString's, as AceGUIWidget-Label.lua's does.
    local function onDescription()
        local w
        local function draw()
            local AceGUI = LibStub("AceGUI-3.0")
            local create = AceGUI.Create
            AceGUI.Create = function() return w end
            local ok, err = pcall(KCM.Settings.Helpers.Label, { scroll = { AddChild = function() end } },
                "x", "medium")
            AceGUI.Create = create
            if not ok then error(err, 0) end
        end
        return function()
            local font = rawget(_G, "GameFontHighlight")
            _G.GameFontHighlight = font or fake("Font")
            cleanups[#cleanups + 1] = function() _G.GameFontHighlight = font end
            local label = fake("FontString", 12)
            w = setmetatable({ type = "Label", frame = fake("Frame"), label = label }, {
                __index = function() return function(me) return me end end })
            w.SetFontObject = function(me, obj) me.label:SetFontObject(obj or _G.GameFontHighlight); return me end
            draw()
            return label
        end, draw
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
    -- Each edge STYLE is a border texture from the skin (bar.borderStyle, icon.borderStyle), so it
    -- declares the texture family (kit revision 58): a style that stopped following would pass on
    -- its tint otherwise.
    local function edge(name, key, build, paint)
        add(name, build, paint, { companion = companion(key), expect = "texture" })
    end
    edge("the bar's edge style", "barBorderStyleFromSkin", onBar("SetBackdrop"))
    add("the unlocked wash", washTexture, repaintBar)
    hud("a button's backdrop", "buttonBackdropColorFromSkin", onButton("backdropTex", "SetColorTexture"))
    hud("a button's edge color", "buttonBorderColorFromSkin", onButton("border", "SetBackdropBorderColor"))
    edge("a button's edge style", "buttonBorderStyleFromSkin", onButton("border", "SetBackdrop"))
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
    edge("the flyout's edge style", "barBorderStyleFromSkin", onFlyout("SetBackdrop"))
    hud("the flyout indicator's shade", "flyoutShadeColorFromSkin", onIndicator("shade", "SetColorTexture"))
    hud("the flyout indicator's arrow", nil, onIndicator("arrow", "SetVertexColor"))
    hud("a flyout entry's backdrop", "buttonBackdropColorFromSkin", onEntry("backdropTex", "SetColorTexture"))
    hud("a flyout entry's edge color", "buttonBorderColorFromSkin", onEntry("border", "SetBackdropBorderColor"))
    edge("a flyout entry's edge style", "buttonBorderStyleFromSkin", onEntry("border", "SetBackdrop"))
    hud("a flyout entry's stack count color", nil, onEntry("count", "SetTextColor"))
    do
        local build, paint = onEntry("count", "SetFont")
        add("a flyout entry's stack count face", build, paint, { scope = "fonts" })
    end
    do
        local build, paint = onBarTooltip()
        add("the macro bar's tooltip lines", build, paint)
    end

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
    do
        local build, paint = onDescription()
        add("a settings description", build, paint, panel)
    end
    do
        local build, paint = onIconHover()
        add("the icon button's hover wash", build, paint, panel)
    end
    add("the drag icon's hover flash", onWidget("modules/KCMMacroDragIcon.lua", "KCMMacroDragIcon", "highlight"), nil, panel)
    add("the drag icon's edge", onIconEdge("modules/KCMMacroDragIcon.lua", "KCMMacroDragIcon", "iconEdge"), nil, panel)
    add("an item row's icon edge", onIconEdge("modules/KCMItemRow.lua", "KCMItemRow", "itemEdge", itemMarks), nil, panel)
    for _, s in ipairs({
        { "a settings warning line", "FontString", "SetText", warnLine },
        { "the score tooltip's note and summary", "GameTooltip", "AddLine", scoreDesc },
    }) do
        local build, paint = onEscape(s[2], s[3], s[4])
        add(s[1], build, paint, panel)
    end
    for _, part in ipairs({ "icon", "text" }) do
        local build, paint = onGhost(part)
        add("a reorder row's carried " .. part, build, paint, panel)
    end

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
