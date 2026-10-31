-- test_skin_outline.lua — the Font outline (LibKa0s v1.82.0, Skin minor 9; CM-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as
-- skin.outline ("all", "hud", the default, "off"), written only through the skin write seam
-- (KCM.WriteSkinChoice's `media.outline`), and applied with Skin:SetOutline at load, on every
-- profile event and on the row's own write. LibKa0sSkinTester 7d736c2 is the reference.

local h = _G.KCM_TEST
local test = h.test

local OWNER = "ConsumableMaster"

local function skinLib() return LibStub("LibKa0s-Skin-1.0", true) end

local function load()
    local KCM = h.loader.loadFullAddon()
    KCM.HideSkinPicker()
    return KCM
end

-- red under: no skin.outline key, or a default other than the library's.
test("Skin outline: a fresh profile stores HUD text only, the library's default", function(t)
    local KCM = load()
    local Skin = skinLib()
    t.eq(KCM.db.profile.skin.outline, "hud", "the profile's default")
    t.eq(KCM.db.profile.skin.outline, Skin.OUTLINE_DEFAULT, "is the library's OUTLINE_DEFAULT")
    t.eq(Skin:GetOutline(OWNER), "hud", "and it is applied")
end)

-- red under: a row the row engine draws (the Skin tab draws it), or values out of the library's order.
test("Skin outline: the schema row offers the library's three modes, on the Skin tab", function(t)
    local KCM = load()
    local row = KCM.Settings.Helpers.FindSchema("skin.outline")
    t.truthy(row, "skin.outline is a schema row")
    t.eq(row and row.skipRender, true, "drawn by the Skin tab, not the row engine")
    t.eq(row and row.group, "Appearance", "the Skin tab's group")
    local got = {}
    for _, opt in ipairs(row and row.values or {}) do got[#got + 1] = opt.value end
    t.eq(table.concat(got, ","), table.concat(skinLib().OUTLINE_MODES, ","), "the library's modes, in order")
end)

-- red under: KCM.WriteSkinChoice dropping media.outline, so the Skin tab's Font outline and the
-- copy move the look and never store it.
test("Skin outline: the write seam stores media.outline, and leaves it alone when it is nil", function(t)
    local KCM = load()
    KCM.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    t.eq(KCM.db.profile.skin.outline, "hud", "stored")
    KCM.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
    t.eq(KCM.db.profile.skin.outline, "hud", "a media without outline leaves it")
    KCM.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    t.eq(KCM.db.profile.skin.outline, "off", "and a second write moves it")
end)

-- red under: another addon's copy (Skin:WriteChoice) not reaching this owner's store.
test("Skin outline: another addon's copy reaches the store through WriteChoice", function(t)
    local KCM = load()
    skinLib():WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    t.eq(KCM.db.profile.skin.outline, "off", "the copy's outline is stored")
end)

-- red under: a row whose apply does not reach Skin:SetOutline (a bare /cm set would store the mode
-- and leave the old outline on screen).
test("Skin outline: the row's write applies the mode live", function(t)
    local KCM = load()
    local Skin = skinLib()
    t.truthy(KCM.Schema:Set("skin.outline", "hud"), "a bare /cm set path is accepted")
    t.eq(Skin:GetOutline(OWNER), "hud", "applied")
    t.eq(KCM.Skin.Token("font.outline"), "", "window text loses its outline")
    t.eq(KCM.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    KCM.Schema:Set("skin.outline", "off")
    t.eq(KCM.Skin.Token("hud.outline"), "", "Off takes both")
    KCM.Schema:Set("skin.outline", "all")
    t.eq(KCM.Skin.Token("font.outline"), "OUTLINE", "All puts it back")
end)

-- red under: a schema row with no values list (any word would be stored).
test("Skin outline: /cm set refuses a mode the library does not know", function(t)
    local KCM = load()
    t.falsy(KCM.Schema:Set("skin.outline", "thick"), "refused")
    t.eq(KCM.db.profile.skin.outline, "hud", "and nothing stored")
end)

-- red under: KCM.ApplySkinChoice's whole-pair path (OnInitialize's call) not applying the stored mode.
test("Skin outline: the whole-choice apply (the load's) applies the stored mode", function(t)
    local KCM = load()
    local Skin = skinLib()
    KCM.db.profile.skin.outline = "off"
    t.eq(Skin:GetOutline(OWNER), "hud", "a raw store write moves nothing yet")
    KCM.ApplySkinChoice()
    t.eq(Skin:GetOutline(OWNER), "off", "the load's apply reads the stored mode")
end)

-- red under: a re-default that rewrites a stored mode (D-10: a stored choice stays).
test("Skin outline: a stored All text stays under the new default", function(t)
    local KCM = load()
    local Skin = skinLib()
    KCM.db.profile.skin.outline = "all"
    KCM.ApplySkinChoice()
    t.eq(KCM.db.profile.skin.outline, "all", "the stored mode is not migrated")
    t.eq(Skin:GetOutline(OWNER), "all", "and it is what is applied")
    t.eq(KCM.Skin.Token("font.outline"), "OUTLINE", "window text keeps its outline")
end)

-- red under: a profile event that leaves the previous profile's outline applied.
test("Skin outline: a profile switch applies the incoming profile's mode, and back", function(t)
    local KCM = load()
    local Skin = skinLib()
    KCM.Schema:Set("skin.outline", "off")
    KCM.db:SetProfile("Alt")
    t.eq(Skin:GetOutline(OWNER), "hud", "Alt keeps the default")
    KCM.db:SetProfile("Default")
    t.eq(Skin:GetOutline(OWNER), "off", "Default's is back")
end)

-- red under: a degraded arm missing the seam member, or one that raises.
test("Skin outline: without the skin engine the apply is a quiet no-op", function(t)
    local KCM = h.loader.loadPureDegraded()
    t.eq(KCM.ApplySkinOutline(), false, "the degraded arm answers false")
    t.eq(KCM.ApplySkinOutline("off"), false, "for a mode too")
end)
