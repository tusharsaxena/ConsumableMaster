-- test_skin_hud.lua — the macro bar's HUD style, read from the skin (skinning-§6; CM-03 of the
-- 2026-10-29 skinning rollout).
--
-- What CM-03 owes, and each case below is red under its loss:
--   * three HUD style settings follow the skin while their `<key>FromSkin` companion is on: the
--     bar's (and the flyout panel's) border style from `bar.borderStyle`, the buttons' border
--     style AND thickness from the icon family (`icon.borderStyle`, `icon.borderSize`), the label
--     face from `hud.font`; with the companion off, the player's own pick draws (X4: the colors,
--     sizes, flags and offset are never the skin's);
--   * the count text takes the skin's HUD face and outline at its font object's size (D6), the
--     unlocked wash `menu.hover` (D4) and the flyout arrow `icon.arrow` (D9);
--   * a skin switch repaints a built bar (OnLooksChanged);
--   * the companions are composed rows (the composer's `fromSkin`), default TRUE (X3);
--   * the one-time reset (O2) is a per-profile v4 migration step through Skin.ResetToSkin that
--     turns the three companions on once, writes no sentinel and keeps a later "off".

local h = _G.KCM_TEST
local test = h.test

local OWNER = "ConsumableMaster"
local OXANIUM = "Ka0s Oxanium SemiBold"

local support = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua")

local function skinLib() return LibStub("LibKa0s-Skin-1.0", true) end

-- A frame that records every call, as tests/test_macrobar_chrome.lua's recFrame does. `font` is
-- what GetFont answers: the face and the size a font object gave the string.
local function recFrame(name, font)
    local f = { _name = name or "MockFrame", calls = {}, _shown = false }
    local special = {
        GetName        = function() return f._name end,
        GetFrameLevel  = function() return 1 end,
        GetStringWidth = function() return 0 end,
        GetFont        = function() return "Fonts\\ARIALN.TTF", font end,
        IsShown        = function() return f._shown end,
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

-- The bar's stored style as a profile carries it, over the shipped defaults.
local function barCfg(KCM, over)
    local c = {}
    for k, v in pairs(KCM.dbDefaults.profile.macroBar) do c[k] = v end
    c.buttonLabel = true
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

-- The LibSharedMedia fake knows the client's own media only; the library's registration of its
-- shipped faces is a no-op there. Teach it the HUD face for one case, and take it back after.
local function withHudFace(fn)
    local LSM = LibStub("LibSharedMedia-3.0")
    local fonts = LSM.media.font
    fonts[#fonts + 1] = OXANIUM
    local ok, err = pcall(fn)
    for i = #fonts, 1, -1 do if fonts[i] == OXANIUM then table.remove(fonts, i) end end
    local Skin = skinLib()
    if Skin then Skin:SetChoice(OWNER, "ka0s", "ka0s") end
    return ok, err
end

-- ---------------------------------------------------------------------------
-- What the HUD draws
-- ---------------------------------------------------------------------------

-- red under: the button border reading its stored style while the companion is on, the bar's
-- family in place of the icon one, or the thickness left the player's under the icon family.
test("Skin HUD: the buttons' border follows the skin's icon family while its companion is on", function(t)
    local KCM = h.loader.loadFullAddon()
    local BB = KCM.MacroBarButton
    local followed = styleButton()
    BB.ApplyStyle(followed, barCfg(KCM))
    local bd = lastCall(followed.border, "SetBackdrop")
    t.truthy(bd, "the border is drawn")
    t.eq(bd and bd[2].edgeFile, [[Interface\Buttons\WHITE8X8]],
        "Ka0s Default: icon.borderStyle 'Solid', the flat edge")
    t.eq(bd and bd[2].edgeSize, 2, "at icon.borderSize, not the stored 4")
    local col = lastCall(followed.border, "SetBackdropBorderColor")
    t.eq(col and col[2], 1, "the color stays the player's white (X4)")

    local own = styleButton()
    BB.ApplyStyle(own, barCfg(KCM, { buttonBorderStyleFromSkin = false }))
    local mine = lastCall(own.border, "SetBackdrop")
    t.eq(mine and mine[2].edgeFile, "border:Blizzard Tooltip", "companion off: the stored style")
    t.eq(mine and mine[2].edgeSize, 4, "and the stored thickness")
end)

-- red under: a skin's "None" drawn as a texture rather than as no edge.
test("Skin HUD: a border style of None hides the button edge", function(t)
    local KCM = h.loader.loadFullAddon()
    local btn = styleButton()
    KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM, {
        buttonBorderStyleFromSkin = false, buttonBorderStyle = "None",
    }))
    t.falsy(btn.border._shown, "no edge, so the border child is hidden")
    t.falsy(lastCall(btn.border, "SetBackdrop"), "and no backdrop is applied to it")
end)

-- red under: the flyout panel (and so the bar, which shares the reader) drawing its stored edge
-- while the bar's companion is on.
test("Skin HUD: the flyout panel's edge follows the skin's bar border style", function(t)
    local KCM = h.loader.loadFullAddon()
    local flyout = { bg = recFrame("bg") }
    KCM.MacroBarFlyout.ApplyBackdrop(flyout, barCfg(KCM))
    local bd = lastCall(flyout.bg, "SetBackdrop")
    t.eq(bd and bd[2].edgeFile, nil, "Ka0s Default: bar.borderStyle 'None', no edge")
    t.eq(bd and bd[2].edgeSize, 4, "the thickness stays the player's")
    local fill = lastCall(flyout.bg, "SetBackdropColor")
    t.eq(fill and fill[5], 0.85, "the fill is the player's swatch (X4)")

    KCM.MacroBarFlyout.ApplyBackdrop(flyout, barCfg(KCM, { barBorderStyleFromSkin = false }))
    bd = lastCall(flyout.bg, "SetBackdrop")
    t.eq(bd and bd[2].edgeFile, "border:Blizzard Tooltip", "companion off: the stored style")
end)

-- red under: the label face read from the stored pick while its companion is on, or the count
-- text left on its font object's face, or its size compounded pass over pass.
test("Skin HUD: the label and count faces are the skin's HUD font", function(t)
    local KCM = h.loader.loadFullAddon()
    local ok, err = withHudFace(function()
        local btn = styleButton()
        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM))
        local label = lastCall(btn.label, "SetFont")
        t.eq(label and label[2], "font:" .. OXANIUM, "Ka0s Default: the label in hud.font")
        t.eq(label and label[4], "OUTLINE", "with the player's flags")
        local count = lastCall(btn.count, "SetFont")
        t.eq(count and count[2], "font:" .. OXANIUM, "the count in hud.font too")
        t.eq(count and count[3], 14, "at the size its font object gave it")
        t.eq(count and count[4], "OUTLINE", "with hud.outline")
        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM))
        t.eq(lastCall(btn.count, "SetFont")[3], 14, "a second pass keeps the size")

        local own = styleButton()
        KCM.MacroBarButton.ApplyStyle(own, barCfg(KCM, { labelFontFromSkin = false }))
        t.eq(lastCall(own.label, "SetFont")[2], "font:Friz Quadrata TT",
            "companion off: the stored face")
    end)
    t.truthy(ok, tostring(err))
end)

-- red under: the appliers reading the skin once and caching it, so another skin draws Ka0s
-- Default's border.
test("Skin HUD: another skin's icon border reaches the buttons", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    local ok, err = withHudFace(function()
        Skin:SetChoice(OWNER, "ka0s", "wow")
        local btn = styleButton()
        KCM.MacroBarButton.ApplyStyle(btn, barCfg(KCM))
        local bd = lastCall(btn.border, "SetBackdrop")
        local style, size = KCM.Skin.Token("icon.borderStyle"), KCM.Skin.Token("icon.borderSize")
        t.eq(style, "Blizzard Tooltip", "WoW Default's icon border is the tooltip edge")
        t.eq(bd and bd[2].edgeFile, "border:" .. style, "and the button draws it")
        t.eq(bd and bd[2].edgeSize, size, "at that skin's thickness")
    end)
    t.truthy(ok, tostring(err))
end)

-- red under: the arrow left untinted, or tinted from a literal.
test("Skin HUD: the flyout arrow takes icon.arrow", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    mock.setItem(seed[1], { name = "Pot", subType = "Potions" })
    mock.setBag(seed[1], 3)
    local button = recFrame("KCMMacroBarButton1")
    button.catKey = "HP_POT"
    local flyout = recFrame("KCMMacroBarFlyout1")
    flyout.bg, flyout.entries = recFrame("bg"), {}
    flyout.GetAttribute, flyout.SetAttribute = function() return 0 end, function() end
    local ind = recFrame("KCMMacroBarFlyout1Indicator")
    ind.shade, ind.arrow = recFrame("shade"), recFrame("arrow")
    ind.SetAttribute = function() end
    button.flyout, button.indicator = flyout, ind
    KCM.MacroBarFlyout.Apply(button, support.fcfg{ flyout = true })
    local tint = lastCall(ind.arrow, "SetVertexColor")
    t.truthy(tint, "the arrow is tinted")
    t.eq(tint and tint[2], 1, "Ka0s Default: icon.arrow's gold, red")
    t.eq(tint and tint[3], 0.82, "green")
    t.eq(tint and tint[4], 0, "blue")
end)

-- red under: the wash typed again, or painted once at build so a skin switch leaves it stale;
-- or a built bar not re-applied on a skin change.
test("Skin HUD: the unlocked wash is menu.hover and a skin switch repaints the bar", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    local _, bar = support.buildBar(KCM)
    local wash = bar.moveHint.tex
    local painted = {}
    wash.SetColorTexture = function(_, ...) painted[#painted + 1] = { ... } end
    local backdrops = 0
    bar.SetBackdrop = function() backdrops = backdrops + 1 end
    KCM.MacroBar.ApplyLock()
    local c = painted[#painted]
    t.eq(c and c[1], 1, "Ka0s Default: the gold wash")
    t.eq(c and c[2], 0.82, "green")
    t.eq(c and c[4], 0.15, "at 0.15, today's pixel exactly")

    local before = #painted
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    t.truthy(#painted > before, "the skin switch repainted the wash")
    t.truthy(backdrops > 0, "and re-applied the bar's backdrop")
    local want = { KCM.Skin.Color("menu.hover") }
    c = painted[#painted]
    t.eq(c and c[4], want[4], "in Obsidian's own hover wash")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
end)

-- ---------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------

-- red under: a companion with no row (so no `/cm set` and no checkbox to turn it off), a
-- default of false (a new profile back on the pre-skin look, X3), or a picker it does not govern.
test("Skin HUD: the three companions are composed rows, on by default, governing their pickers", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    for _, pair in ipairs({
        { "macroBar.barBorderStyleFromSkin", "macroBar.barBorderStyle" },
        { "macroBar.buttonBorderStyleFromSkin", "macroBar.buttonBorderStyle" },
        { "macroBar.buttonBorderStyleFromSkin", "macroBar.buttonBorderSize" },
        { "macroBar.labelFontFromSkin", "macroBar.labelFont" },
    }) do
        local companion, picker = H.FindSchema(pair[1]), H.FindSchema(pair[2])
        t.truthy(companion, pair[1] .. " is a schema row")
        t.eq(companion and companion.type, "bool", pair[1] .. " is a bool")
        t.eq(companion and companion.default, true, pair[1] .. " defaults on (X3)")
        t.eq(picker and picker.disabledIf, pair[1], pair[2] .. " is governed by it")
    end
    t.eq(H.FindSchema("macroBar.barBorderSize").disabledIf, nil,
        "the bar family governs no thickness: the bar's stays the player's")
    t.truthy(KCM.Schema:Set("macroBar.labelFontFromSkin", false), "a bare /cm set is accepted")
    t.eq(KCM.db.profile.macroBar.labelFontFromSkin, false, "and stored")
end)

-- ---------------------------------------------------------------------------
-- The one-time reset (O2): the v4 migration step
-- ---------------------------------------------------------------------------

local COMPANIONS = { "barBorderStyleFromSkin", "buttonBorderStyleFromSkin", "labelFontFromSkin" }

-- red under: the step missing, gated on anything but the profile's stamp, or listing a key that
-- is not a border style or a face.
test("Skin HUD: the v4 step puts the HUD style back on the skin and keeps the picks", function(t)
    local KCM = h.loader.loadFullAddon()
    local p = KCM.db.profile
    p.schemaVersion = 3
    for _, k in ipairs(COMPANIONS) do p.macroBar[k] = false end
    p.macroBar.barBorderStyle, p.macroBar.labelFont = "Blizzard Dialog", "JetBrains Mono"
    p.macroBar.labelShadow, p.macroBar.barBorderSize = false, 7
    KCM.Database.RunMigrations()
    for _, k in ipairs(COMPANIONS) do t.eq(p.macroBar[k], true, k .. " is on after the reset") end
    t.eq(p.macroBar.barBorderStyle, "Blizzard Dialog", "the stored pick is kept, not overwritten")
    t.eq(p.macroBar.labelFont, "JetBrains Mono", "the stored face too")
    t.eq(p.macroBar.labelShadow, false, "a bool style key is not switched on")
    t.eq(p.macroBar.barBorderSize, 7, "a size is not reset")
    t.eq(p.schemaVersion, 4, "the profile is stamped v4")
end)

-- red under: the step running again on a profile already at v4, stomping a deliberate "off".
test("Skin HUD: the reset runs once, and a later pick is kept", function(t)
    local KCM = h.loader.loadFullAddon()
    local p = KCM.db.profile
    p.schemaVersion = 3
    KCM.Database.RunMigrations()
    t.eq(p.schemaVersion, 4, "walked to v4")
    p.macroBar.labelFontFromSkin = false
    p.macroBar.barBorderStyleFromSkin = false
    KCM.Database.RunMigrations()
    KCM.Database.RunMigrations()
    t.eq(p.macroBar.labelFontFromSkin, false, "the player's later 'off' survives every login")
    t.eq(p.macroBar.barBorderStyleFromSkin, false, "on every companion")
end)

-- red under: ResetToSkin handed a key whose companion it cannot see, so the FROM_SKIN sentinel
-- lands in an LSM key no picker can show.
test("Skin HUD: the reset writes no sentinel into a raw profile", function(t)
    local KCM = h.loader.loadPure()
    local raw = { macroBar = { barBorderStyle = "Blizzard Tooltip", buttonBorderStyle = "None",
                               labelFont = "Friz Quadrata TT" } }
    t.eq(KCM.Database.MigrateHudSkinV4(raw), true, "the step reports done")
    t.eq(raw.macroBar.barBorderStyle, "Blizzard Tooltip", "the style key keeps its pick")
    t.eq(raw.macroBar.buttonBorderStyle, "None", "on every key")
    t.eq(raw.macroBar.labelFont, "Friz Quadrata TT", "the face too")
    for _, k in ipairs(COMPANIONS) do t.eq(raw.macroBar[k], true, k .. " is on") end
    t.eq(KCM.Database.MigrateHudSkinV4({}), false, "a profile with no bar table is left alone")
end)

-- red under: the degraded arm (no library, so no ResetToSkin) raising or skipping the reset.
test("Skin HUD: the reset runs without the library too", function(t)
    local KCM = h.loader.loadPureDegraded()
    local raw = { macroBar = { labelFont = "Friz Quadrata TT" } }
    t.eq(KCM.Database.MigrateHudSkinV4(raw), true, "the step reports done")
    for _, k in ipairs(COMPANIONS) do t.eq(raw.macroBar[k], true, k .. " is on") end
    t.eq(raw.macroBar.labelFont, "Friz Quadrata TT", "and the pick is kept")
end)

-- red under: the degraded facade's Resolve answering nil for a followed style, so a no-library
-- install draws the bar with no border at all.
test("Skin HUD: without the library the bar draws the player's stored style", function(t)
    local full = h.loader.loadFullAddon(true)
    t.eq(full.Skin.Resolve("icon.borderStyle", "Blizzard Tooltip", true), nil,
        "the degraded facade carries no HUD strings")
    t.eq(full.MacroBarButton.Follow("icon.borderStyle", "Blizzard Tooltip", true), "Blizzard Tooltip",
        "so BB.Follow falls back on the stored pick")
    t.eq(full.MacroBarButton.Follow("hud.font", full.Skin.FROM_SKIN, false), nil,
        "and a stored sentinel with no token answers nil, the reader's own default")
end)
