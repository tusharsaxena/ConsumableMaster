-- test_skin_flip.lua — the macro bar's colors and shadow follow the skin (FS-CM-FLIP, causes D2, D4
-- and D6 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING).
--
-- What this addon owes (LibKa0s Options doc, "Moving to this version"): each color and the shadow
-- have a "Use the skin's ..." companion, default on, drawn after the class color and before the
-- stored swatch; Ka0s Default keeps this addon's pixels through its owner tokens; and the one
-- per-profile step moves existing profiles onto the skin, naming companions and the From skin
-- flags only, so every stored pick and color survives for a player who turns a companion off.
--
-- Skin-switch cases spy on the drawing setters: a getter compared with itself proves nothing.

local h = _G.KCM_TEST
local test = h.test

local OWNER = "ConsumableMaster"
local support = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua")

local function skinLib() return LibStub("LibKa0s-Skin-1.0", true) end

-- A frame that records every call, as tests/test_skin_hud.lua's does. The FontString answer
-- matters: S.HudFont asks what the target is.
local function recFrame(name, font)
    local f = { _name = name or "MockFrame", calls = {}, _shown = false }
    local special = {
        GetName        = function() return f._name end,
        GetFrameLevel  = function() return 1 end,
        GetStringWidth = function() return 0 end,
        GetFont        = function() return "Fonts\\ARIALN.TTF", font end,
        GetObjectType  = function() return "FontString" end,
        IsShown        = function() return f._shown end,
    }
    setmetatable(f, { __index = function(_, key)
        if special[key] then return special[key] end
        return function(_, ...)
            f.calls[#f.calls + 1] = { key, ... }
            return f
        end
    end })
    return f
end

local function lastCall(f, name)
    for i = #f.calls, 1, -1 do
        if f.calls[i][1] == name then return f.calls[i] end
    end
    return nil
end

local function styleButton()
    local btn = recFrame("KCMMacroBarButton1")
    btn.catKey      = "FOOD"
    btn.border      = recFrame("border")
    btn.icon        = recFrame("icon")
    btn.backdropTex = recFrame("backdropTex")
    btn.count       = recFrame("count", 14)
    btn.label       = recFrame("label")
    return btn
end

local function indicator()
    local ind = recFrame("indicator")
    ind.shade, ind.arrow = recFrame("shade"), recFrame("arrow")
    return ind
end

local function barCfg(KCM, over)
    local c = {}
    for k, v in pairs(KCM.dbDefaults.profile.macroBar) do c[k] = v end
    c.buttonLabel = true
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

--- Every draw this addon's flipped surfaces make, read off the spies: name -> { r, g, b, a }.
local function drawn(KCM, cfg)
    local out = {}
    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, cfg)
    local function take(name, frame, setter)
        local c = lastCall(frame, setter)
        out[name] = c and { c[2], c[3], c[4], c[5] } or false
    end
    take("buttonBorder", btn.border, "SetBackdropBorderColor")
    take("buttonBackdrop", btn.backdropTex, "SetColorTexture")
    take("label", btn.label, "SetTextColor")
    take("count", btn.count, "SetTextColor")
    local flyout = { bg = recFrame("bg") }
    KCM.MacroBarFlyout.ApplyBackdrop(flyout, cfg)
    take("flyoutBackdrop", flyout.bg, "SetBackdropColor")
    take("flyoutBorder", flyout.bg, "SetBackdropBorderColor")
    local button = recFrame("KCMMacroBarButton1")
    button.indicator = indicator()
    button.flyout = recFrame("flyout")
    button.flyout.entries, button.flyout.bg = {}, recFrame("bg")
    pcall(KCM.MacroBarFlyout.Apply, button, cfg, {})
    take("shade", button.indicator.shade, "SetColorTexture")
    return out
end

local function barDraws(KCM)
    local _, bar = support.buildBar(KCM)
    local seen = {}
    bar.SetBackdropColor = function(_, ...) seen.fill = { ... } end
    bar.SetBackdropBorderColor = function(_, ...) seen.edge = { ... } end
    bar.SetBackdrop = function(_, t) seen.backdrop = t end
    return bar, seen
end

local function rgba(c) return c and table.concat({ c[1], c[2], c[3], c[4] or 1 }, ",") or "nil" end

local function dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys, out = {}, {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. dump(v[k]) end
    return "{" .. table.concat(out, ";") .. "}"
end

local COLOR_COMPANIONS = {
    { "barBackdropColorFromSkin", "barBackdropColor", "Bar appearance", "Background" },
    { "barBorderColorFromSkin", "barBorderColor", "Bar appearance", "Border" },
    { "buttonBackdropColorFromSkin", "buttonBackdropColor", "Button appearance", "Background" },
    { "buttonBorderColorFromSkin", "buttonBorderColor", "Button appearance", "Border" },
    { "labelColorFromSkin", "labelColor", "Labels", "Font" },
    { "labelShadowFromSkin", "labelShadow", "Labels", "Font" },
    { "flyoutBackdropColorFromSkin", "flyoutBackdropColor", "Flyout", "Background" },
    { "flyoutShadeColorFromSkin", "flyoutShadeColor", "Flyout", "Indicator" },
}

-- ---------------------------------------------------------------------------
-- The rows and the defaults
-- ---------------------------------------------------------------------------

-- red under: a companion with no row, a default on one side only, or a tooltip that hides which
-- row it stops reading.
test("Skin flip: every color and shadow companion is a bool row defaulting on, in both places", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    for _, c in ipairs(COLOR_COMPANIONS) do
        local row = H.FindSchema("macroBar." .. c[1])
        t.truthy(row, c[1] .. " is a schema row")
        t.eq(row and row.type, "bool", c[1])
        t.eq(row and row.default, true, c[1] .. " defaults on on the row")
        t.eq(KCM.dbDefaults.profile.macroBar[c[1]], true, c[1] .. " defaults on in AceDB")
        t.eq(row and row.group, c[3], c[1] .. " sits on its swatch's tab")
        t.eq(row and row.subgroup, KCM.L[c[4]], c[1] .. " sits under its swatch's heading")
        t.truthy(row and row.tooltip and row.tooltip:find("not read while this is on", 1, true),
            c[1] .. "'s tooltip says the row it governs is not read")
        t.eq(H.FindSchema("macroBar." .. c[2]).disabledIf, nil,
            c[2] .. " stays live: no disabledIf on a composed swatch")
    end
end)

-- red under: a `labelFont`, `labelFlags` or thickness default left where it was.
test("Skin flip: the pick's default moved, and the bar family holds the thickness", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    t.eq(KCM.dbDefaults.profile.macroBar.labelFont, "Ka0s Prototype", "AceDB's default face")
    t.eq(H.FindSchema("macroBar.labelFont").default, "Ka0s Prototype", "the row's")
    t.eq(H.FindSchema("macroBar.labelFlags").default, "@skin", "the flags row's")
    t.eq(H.FindSchema("macroBar.barBorderSize").disabledIf, "macroBar.barBorderStyleFromSkin",
        "the border's companion governs the thickness")
end)

test("Skin flip: the record is in the AceDB defaults, with no schema row a Defaults could walk", function(t)
    local KCM = h.loader.loadFullAddon()
    t.eq(KCM.dbDefaults.profile.skin.fullSkinReset, false, "false until the step ran")
    t.eq(KCM.Settings.Helpers.FindSchema("skin.fullSkinReset"), nil,
        "no row: nothing draws or sets it but the step")
end)

-- ---------------------------------------------------------------------------
-- What the bar draws
-- ---------------------------------------------------------------------------

-- red under: an owner token that lost a Ka0s Default pixel.
test("Skin flip: Ka0s Default keeps this addon's pixels", function(t)
    local KCM = h.loader.loadFullAddon()
    local got = drawn(KCM, barCfg(KCM))
    t.eq(rgba(got.buttonBorder), "1,1,1,1", "the white button edge")
    t.eq(rgba(got.buttonBackdrop), "0,0,0,0.6", "the button fill")
    t.eq(rgba(got.label), "1,0.82,0,1", "the gold label")
    t.eq(rgba(got.count), "1,1,1,1", "the count: NumberFontNormal's white")
    t.eq(rgba(got.flyoutBackdrop), "0,0,0,0.85", "the flyout fill")
    t.eq(rgba(got.flyoutBorder), "0.25,0.25,0.25,1", "the flyout edge")
    t.eq(rgba(got.shade), "0,0,0,0.8", "the shaded band")
    local bar, seen = barDraws(KCM)
    KCM.MacroBar.Update()
    t.truthy(bar, "the bar built")
    t.eq(rgba(seen.fill), "0,0,0,0.5", "the bar fill")
    t.eq(rgba(seen.edge), "0.25,0.25,0.25,1", "the bar edge")
end)

-- red under: any flipped surface still reading its stored swatch; `bar.bg` is the same in every
-- skin, so the bar's own fill is pinned against a spied token below rather than here.
test("Skin flip: a skin switch changes what each flipped surface draws", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    local before = drawn(KCM, barCfg(KCM))
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local after = drawn(KCM, barCfg(KCM))
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    for _, name in ipairs({ "buttonBorder", "buttonBackdrop", "label", "flyoutBackdrop",
        "flyoutBorder", "shade", "count" }) do
        t.truthy(rgba(before[name]) ~= rgba(after[name]),
            name .. " draws something else under Obsidian (" .. rgba(after[name]) .. ")")
    end
end)

test("Skin flip: the bar's fill and edge draw the skin's tokens, and a skin switch repaints them", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    local _, seen = barDraws(KCM)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    t.truthy(seen.fill, "the skin change reached the bar's fill")
    local real, asked = KCM.Skin.Color, {}
    KCM.Skin.Color = function(name)
        asked[name] = true
        if name == "bar.bg" then return 0.1, 0.2, 0.3, 0.4 end
        return real(name)
    end
    KCM.MacroBar.Update()
    KCM.Skin.Color = real
    t.eq(rgba(seen.fill), "0.1,0.2,0.3,0.4", "the bar's fill is bar.bg")
    t.truthy(asked["cm.barBorder"], "the edge reads its owner token")
end)

-- red under: the swatch unread with the companion off, so a player's own color is lost.
test("Skin flip: a companion off draws the stored color, under any skin", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local stored = { 0.11, 0.22, 0.33, 0.44 }
    local got = drawn(KCM, barCfg(KCM, {
        buttonBorderColorFromSkin = false, buttonBorderColor = stored,
        buttonBackdropColorFromSkin = false, buttonBackdropColor = stored,
        labelColorFromSkin = false, labelColor = stored,
        flyoutBackdropColorFromSkin = false, flyoutBackdropColor = stored,
        barBorderColorFromSkin = false, barBorderColor = stored,
        flyoutShadeColorFromSkin = false, flyoutShadeColor = stored,
    }))
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    for _, name in ipairs({ "buttonBorder", "buttonBackdrop", "label", "flyoutBackdrop",
        "flyoutBorder", "shade" }) do
        t.eq(rgba(got[name]), "0.11,0.22,0.33,0.44", name)
    end
end)

-- red under: the companion checked before the class color (MC: a class color is never the skin's).
test("Skin flip: a class color comes first, whatever the companion says", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local real, classed = KCM.SwatchColor, 0
    KCM.SwatchColor = function(_, useClass)
        if useClass then classed = classed + 1 end
        return 0.5, 0.25, 0.125, 1
    end
    local got = drawn(KCM, barCfg(KCM, {
        useClassColorButtonBorder = true, useClassColorButtonBackdrop = true,
        useClassColorLabel = true, useClassColorFlyoutBackdrop = true,
        useClassColorBarBorder = true, useClassColorFlyoutShade = true,
    }))
    KCM.SwatchColor = real
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    for _, name in ipairs({ "buttonBorder", "buttonBackdrop", "label", "flyoutBackdrop",
        "flyoutBorder", "shade" }) do
        t.eq(rgba(got[name]), "0.5,0.25,0.125,1", name)
    end
    t.truthy(classed >= 6, "the class branch ran for each")
end)

-- red under: the thickness read from the stored size while the companion is on.
test("Skin flip: the bar's thickness is the skin's while the border's companion is on", function(t)
    local KCM = h.loader.loadFullAddon()
    local _, seen = barDraws(KCM)
    KCM.db.profile.macroBar.barBorderSize = 9
    KCM.MacroBar.Update()
    t.eq(seen.backdrop and seen.backdrop.edgeSize, 1, "bar.borderSize under Ka0s Default")
    KCM.db.profile.macroBar.barBorderStyleFromSkin = false
    KCM.MacroBar.Update()
    t.eq(seen.backdrop and seen.backdrop.edgeSize, 9, "companion off: the stored size")
    local flyout = { bg = recFrame("bg") }
    KCM.MacroBarFlyout.ApplyBackdrop(flyout, barCfg(KCM, { barBorderSize = 9 }))
    t.eq(lastCall(flyout.bg, "SetBackdrop")[2].edgeSize, 1, "the flyout's edge shares it")
end)

-- A 12.0.7 client draws only a font object's shadow, so the label wears one. Each case fakes
-- CreateFont and spies on the object.
local function fontObjects()
    local made = {}
    local real = _G.CreateFont
    _G.CreateFont = function(name)
        local o = { name = name, calls = {} }
        for _, m in ipairs({ "SetFont", "SetShadowColor", "SetShadowOffset" }) do
            o[m] = function(_, ...) o.calls[m] = { ... } end
        end
        made[#made + 1] = o
        return o
    end
    return made, function() _G.CreateFont = real end
end

-- red under: a host that keeps its own SetShadow calls on the FontString, which the client ignores.
test("Skin flip: the label's shadow lands on a font object, the skin's while the companion is on", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    local made, restore = fontObjects()
    local cleanup = function()
        restore()
        Skin:SetChoice(OWNER, "ka0s", "ka0s")
    end
    local ok, err = pcall(function()
        Skin:SetChoice(OWNER, "ka0s", "obsidian")
        local btn = styleButton()
        Skin.__hudFonts[btn.label] = nil
        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM))
        t.truthy(lastCall(btn.label, "SetFontObject"), "the string wears the object")
        t.eq(lastCall(btn.label, "SetShadowOffset"), nil, "no shadow set on the string itself")
        local o = made[#made]
        local x, y, r, g, b, a = KCM.Skin.HudShadow()
        t.truthy(x, "Obsidian states a shadow")
        t.eq(table.concat(o.calls.SetShadowOffset, ","), x .. "," .. y, "the skin's offset")
        t.eq(table.concat(o.calls.SetShadowColor, ","), table.concat({ r, g, b, a }, ","), "and color")

        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM, { labelShadowFromSkin = false, labelShadow = true }))
        t.eq(table.concat(made[#made].calls.SetShadowOffset, ","), "1,-1", "companion off: the stored row")

        Skin:SetChoice(OWNER, "ka0s", "ka0s")
        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM, { labelShadow = true }))
        t.eq(table.concat(made[#made].calls.SetShadowOffset, ","), "0,0",
            "Ka0s Default draws no shadow, whatever the stored row says")

        Skin:SetIgnore(OWNER, nil, true)
        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM, { labelShadow = true }))
        Skin:SetIgnore(OWNER, nil, false)
        t.eq(table.concat(made[#made].calls.SetShadowOffset, ","), "1,-1",
            "Ignore fonts: the stored row stands")
    end)
    cleanup()
    if not ok then error(err, 0) end
end)

-- red under: the degraded facade's token answers drawing an owner token over the stored color.
test("Skin flip: without the library the stored colors draw and the label keeps its face", function(t)
    local KCM = h.loader.loadFullAddon(true)
    local btn = styleButton()
    local stored = { 0.11, 0.22, 0.33, 0.44 }
    KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM, {
        buttonBorderColor = stored, buttonBackdropColor = stored, labelColor = stored,
    }))
    t.eq(rgba({ unpack(lastCall(btn.border, "SetBackdropBorderColor"), 2) }), "0.11,0.22,0.33,0.44", "border")
    t.eq(rgba({ unpack(lastCall(btn.backdropTex, "SetColorTexture"), 2) }), "0.11,0.22,0.33,0.44", "backdrop")
    t.eq(rgba({ unpack(lastCall(btn.label, "SetTextColor"), 2) }), "0.11,0.22,0.33,0.44", "label")
    t.truthy(lastCall(btn.label, "SetFont"), "S.HudFont's stub gives the label its face")
end)

-- ---------------------------------------------------------------------------
-- The one step onto the skin
-- ---------------------------------------------------------------------------

local function partialProfile()
    return { macroBar = {
        barBackdropColor = { 0.1, 0.2 },                  -- one key short
        barBorderColor = { 0.3, 0.3, 0.3, 1 },
        labelColor = { 0.9, 0.1, 0.1, 1 },
        labelFont = "JetBrains Mono",
        barBorderStyle = "Blizzard Dialog",
        barBorderSize = 7, labelScale = 30, labelShadow = true,
        labelFlags = "THICKOUTLINE",
        useClassColorLabel = true,
        -- some companions stored off, some absent
        labelColorFromSkin = false, barBorderStyleFromSkin = false,
    }, skin = { ignorePanel = true, ignoreFonts = false } }
end

-- red under: a key listed by its color or pick, a sentinel in a swatch, or a key left out.
test("Skin flip: the step moves every listed key, byte-identical picks and colors", function(t)
    local KCM = h.loader.loadPure()
    local D = KCM.Database
    local p = partialProfile()
    local snapshot = {}
    for k, v in pairs(p.macroBar) do
        if not k:find("FromSkin$") and k ~= "labelFlags" then snapshot[k] = dump(v) end
    end
    t.eq(D.FollowSkinV6(p), true, "the step ran")
    for _, c in ipairs(COLOR_COMPANIONS) do t.eq(p.macroBar[c[1]], true, c[1]) end
    for _, k in ipairs({ "barBorderStyleFromSkin", "buttonBorderStyleFromSkin", "labelFontFromSkin" }) do
        t.eq(p.macroBar[k], true, k)
    end
    t.eq(p.macroBar.labelFlags, "@skin", "the flags key is on S.FontFlags, so it is listed")
    for k, was in pairs(snapshot) do t.eq(dump(p.macroBar[k]), was, k .. " is byte-identical") end
    for k, v in pairs(p.macroBar) do
        if k ~= "labelFlags" then t.truthy(v ~= "@skin", k .. " holds no sentinel") end
    end
    t.eq(p.macroBar.useClassColorLabel, true, "a class toggle is untouched")
    t.eq(p.skin.ignorePanel, true, "skin.ignorePanel is untouched")
    t.eq(p.skin.ignoreFonts, false, "skin.ignoreFonts is untouched")
    t.eq(p.skin.fullSkinReset, true, "the record")
end)

test("Skin flip: the step lists no size, class toggle, Scope key or bare color", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs(KCM.Database.SKIN_FOLLOW_KEYS) do
        t.truthy(key:find("FromSkin$") or key == "macroBar.labelFlags", key .. " is a companion or the flags")
        t.truthy(key:find("^macroBar%."), key .. " is a path from the profile root")
    end
end)

test("Skin flip: a second run writes nothing, and a companion turned off afterwards stays off", function(t)
    local KCM = h.loader.loadPure()
    local D = KCM.Database
    local p = partialProfile()
    t.eq(D.FollowSkinV6(p), true, "first run")
    p.macroBar.labelColorFromSkin = false
    p.macroBar.labelFlags = "OUTLINE"
    local before = dump(p)
    t.eq(D.FollowSkinV6(p), false, "second run")
    t.eq(dump(p), before, "wrote nothing")
end)

test("Skin flip: a missing sub-table is skipped and the record's table created", function(t)
    local KCM = h.loader.loadPure()
    local p = {}
    t.eq(KCM.Database.FollowSkinV6(p), true, "ran")
    t.eq(p.macroBar, nil, "no macroBar table conjured")
    t.eq(p.skin.fullSkinReset, true, "the one table the step may create")
    t.eq(KCM.Database.FollowSkinV6("nope"), false, "a bad profile is refused")
end)

test("Skin flip: the step is the same write with the library absent", function(t)
    local KCM = h.loader.loadPureDegraded()
    local D = KCM.Database
    local p = partialProfile()
    local color = dump(p.macroBar.labelColor)
    t.eq(D.FollowSkinV6(p), true, "ran")
    for _, c in ipairs(COLOR_COMPANIONS) do t.eq(p.macroBar[c[1]], true, c[1]) end
    t.eq(p.macroBar.labelFlags, "@skin", "the flags")
    t.eq(dump(p.macroBar.labelColor), color, "the stored color")
    t.eq(p.skin.fullSkinReset, true, "the record, written by hand")
    p.macroBar.labelColorFromSkin = false
    t.eq(D.FollowSkinV6(p), false, "gated on the record")
    t.eq(p.macroBar.labelColorFromSkin, false, "so an off stays off")
    local bare = {}
    t.eq(D.FollowSkinV6(bare), true, "ran on a bare profile")
    t.eq(bare.macroBar, nil, "no table on the way")
end)

-- red under: the step gated on the stamp alone, so a restored profile never moves.
test("Skin flip: past the stamp the runner still moves an active profile with no record", function(t)
    local KCM = h.loader.loadFullAddon()
    local p = KCM.db.profile
    p.schemaVersion = KCM.Database.CURRENT_SCHEMA
    p.skin.fullSkinReset = false
    p.macroBar.labelColorFromSkin = false
    KCM.Database.RunMigrations()
    t.eq(p.macroBar.labelColorFromSkin, true, "moved")
    t.eq(p.skin.fullSkinReset, true, "and recorded")
end)

-- The pilot's bug: a Defaults that walks the record re-runs the step over companions turned off.
test("Skin flip: the page Defaults leaves the record alone, so a later run keeps a turned-off companion", function(t)
    local KCM = h.loader.loadFullAddon()
    local p = KCM.db.profile
    KCM.Database.RunMigrations()
    t.eq(p.skin.fullSkinReset, true, "through the step")
    local H = KCM.Settings.Helpers
    KCM.MacroBar.Update = function() end
    for _, page in ipairs({ "macrobar", "general" }) do
        KCM.Settings.builders[page]({})
        local reset = H.instance.__panelFor(page).panel.defaultsOnClick
        p.macroBar.labelFlags = "OUTLINE"
        reset()
        t.eq(p.skin.fullSkinReset, true, page .. "'s Defaults keeps the record")
        p.macroBar.labelColorFromSkin = false
        p.macroBar.labelFlags = "OUTLINE"
        KCM.Database.RunMigrations()
        t.eq(p.macroBar.labelColorFromSkin, false, "the next run leaves the companion off: " .. page)
        t.eq(p.macroBar.labelFlags, "OUTLINE", "and a flag picked since: " .. page)
    end
end)

test("Skin flip: a profile reset re-runs the step against defaults, moving nothing a player sees", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.Database.RunMigrations()
    KCM.db:ResetProfile()
    KCM.Database.RunMigrations()
    local p = KCM.db.profile
    t.eq(p.skin.fullSkinReset, true, "recorded again")
    t.eq(p.macroBar.labelFlags, "@skin", "the shipped flags")
    t.eq(rgba(p.macroBar.labelColor), "1,0.82,0,1", "the shipped swatch")
end)

test("Skin flip: a profile switched to later moves on arrival", function(t)
    local KCM = h.loader.loadFullAddon()
    local p = KCM.db.profile
    KCM.Database.RunMigrations()
    p.skin.fullSkinReset = true
    p.macroBar.labelFlags = "OUTLINE"
    local other = partialProfile()
    KCM.db.profile = other
    KCM.Database.RunMigrations()
    t.eq(other.macroBar.labelColorFromSkin, true, "the arriving profile moved")
    t.eq(p.macroBar.labelFlags, "OUTLINE", "the one left behind did not")
    KCM.db.profile = p
end)
