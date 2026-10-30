-- test_skin.lua — the LibKa0s-Skin-1.0 seam, core/SkinSetup.lua (skinning-§1/§2/§3).
--
-- What CM-01 of the 2026-10-29 skinning rollout owes: the owner registered at FILE LOAD under the
-- folder name, with this addon's owner tokens; a degraded facade that answers every vocabulary
-- name and Ka0s Default's values; the skin.* rows written only through the schema seam, each
-- moving its own half of the applied choice; the profile's choice re-applied at login and on
-- every profile event; and the owner handed to every library factory that takes one.

local h = _G.KCM_TEST
local test = h.test

local ROOT = _G.KCM_TEST_ROOT or "."
local OWNER = "ConsumableMaster"

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

local function skinLib() return LibStub("LibKa0s-Skin-1.0", true) end

-- red under: a registration moved to PLAYER_LOGIN or keyed by anything but the folder.
test("Skin: the owner is registered at file load under the addon's folder", function(t)
    local KCM = h.loader.loadPure()
    local Skin = skinLib()
    t.truthy(Skin, "the Skin major is vendored and loads")
    t.truthy(Skin and Skin:IsOwner(OWNER), "ConsumableMaster is a registered skin owner")
    t.eq(KCM.Skin and KCM.Skin.owner, OWNER, "KCM.Skin is the owner's facade")
    t.eq(Skin and Skin:OwnerLabel(OWNER), "Ka0s Consumable Master", "the tab and the copy print the brand")
    local source, skin = Skin:GetChoice(OWNER)
    t.eq(source, "ka0s", "a fresh profile's source is the Ka0s skins")
    t.eq(skin, "ka0s", "and its skin is Ka0s Default")
end)

-- red under: an owner token snapped to a library token (a Ka0s Default pixel moved), a token
-- refused for its name, or a follow that does not reach another skin.
test("Skin: the owner tokens draw today's pixels on Ka0s Default and follow their role elsewhere",
    function(t)
        local KCM = h.loader.loadPure()
        local Skin = skinLib()
        for name, def in pairs(KCM.SKIN_TOKENS) do
            local r, g, b, a = KCM.Skin.Color(name)
            t.eq(r, def.default[1], name .. ": red is today's")
            t.eq(g, def.default[2], name .. ": green is today's")
            t.eq(b, def.default[3], name .. ": blue is today's")
            t.eq(a, def.default[4], name .. ": alpha is today's")
        end
        Skin:SetChoice(OWNER, "ka0s", "obsidian")
        local obsidian = Skin:ResolveSkin("obsidian")
        for name, def in pairs(KCM.SKIN_TOKENS) do
            local want = obsidian[def.follow]
            local r, g, b = KCM.Skin.Color(name)
            t.truthy(want ~= nil, name .. " follows a token Obsidian sets (" .. def.follow .. ")")
            t.eq(r, want and want[1], name .. " takes " .. def.follow .. "'s red under Obsidian")
            t.eq(g, want and want[2], name .. " takes " .. def.follow .. "'s green under Obsidian")
            t.eq(b, want and want[3], name .. " takes " .. def.follow .. "'s blue under Obsidian")
        end
        Skin:SetChoice(OWNER, "ka0s", "ka0s")
    end)

test("Skin: SkinColor keeps a call site's arity and SkinEscape its bytes", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SkinEscape("cm.warn"), "|cffff8800", "the warning escape is the |cffff8800 it replaces")
    t.eq(KCM.SkinEscape("cm.tipNote"), "|cff888888", "the note gray keeps its bytes")
    t.eq(KCM.SkinEscape("cm.tipSummary"), "|cffaaaaaa", "and the summary gray")
    t.eq(select("#", KCM.SkinColor("cm.warn")), 3, "an opaque color answers three components")
    t.eq(select("#", KCM.SkinColor("cm.iconHover")), 4, "a translucent one answers four")
end)

-- red under: a vocabulary name the degraded facade lacks, so a primitive call raises on an
-- install without the library.
test("Skin: the degraded facade answers every name the live facade carries", function(t)
    local live = h.loader.loadPure()
    local degraded = h.loader.loadPureDegraded()
    t.eq(degraded.Skin and degraded.Skin.owner, OWNER, "the degraded facade names the owner")
    h.assertSurfaceParity(live.Skin, degraded.Skin, "Skin facade vs host stub", {})
end)

test("Skin: the seam publishes the same KCM members on both paths", function(t)
    local live = h.loader.loadPure()
    local degraded = h.loader.loadPureDegraded()
    local missing = {}
    for _, name in ipairs({
        "Skin", "SkinChoice", "WriteSkinChoice", "SkinOverride", "ApplySkinChoice", "ApplySkinIgnore",
        "ApplySkinOverride", "SKIN_SOURCE_OPTIONS", "SKIN_OPTIONS", "SKIN_TOKENS", "SKIN_FALLBACK",
        "SkinColor", "SkinEscape", "SkinPaintAce", "SkinPaintAceTree", "SkinOnRelease",
        "SkinAcquire", "MaybeShowSkinPicker", "HideSkinPicker", "SkinPickerSpec",
    }) do
        if live[name] == nil then missing[#missing + 1] = "live " .. name end
        if degraded[name] == nil then missing[#missing + 1] = "degraded " .. name end
        if live[name] ~= nil and degraded[name] ~= nil and type(live[name]) ~= type(degraded[name]) then
            missing[#missing + 1] = name .. " differs in type"
        end
    end
    t.eq(table.concat(missing, "; "), "", "every seam member on both arms")
end)

-- red under: a host copy of a Ka0s Default value that drifted from the library's.
test("Skin: the degraded facade's Ka0s Default values are the live facade's", function(t)
    local live = h.loader.loadPure()
    local degraded = h.loader.loadPureDegraded()
    local drift = {}
    for name in pairs(degraded.SKIN_FALLBACK) do
        local lr, lg, lb, la = live.Skin.Color(name)
        local dr, dg, db, da = degraded.Skin.Color(name)
        if lr ~= dr or lg ~= dg or lb ~= db or la ~= da then drift[#drift + 1] = name end
    end
    t.eq(table.concat(drift, ", "), "", "every fallback entry equals the live Ka0s Default")
end)

-- red under: a row stored outside the schema seam, or an apply that does not move the skin.
test("Skin: the skin rows write through the seam and move the applied skin", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    local H = KCM.Settings.Helpers
    for _, path in ipairs({ "skin.source", "skin.skin", "skin.ignorePanel", "skin.ignoreFonts",
                            "skin.font", "skin.texture", "skin.pickerSeen" }) do
        local row = H.FindSchema(path)
        t.truthy(row, path .. " is a schema row")
        t.eq(row and row.skipRender, true, path .. " is drawn by the Skin tab, not the row engine")
        t.eq(row and row.page, "general", path .. " is on the General page")
        t.eq(row and row.group, "Appearance", path .. " is the Skin tab's group")
    end
    t.truthy(KCM.Schema:Set("skin.skin", "obsidian"), "a bare /cm set path is accepted")
    t.eq(KCM.db.profile.skin.skin, "obsidian", "and stored in the profile")
    t.eq(select(2, Skin:GetChoice(OWNER)), "obsidian", "and repaints: the applied skin moved")
    t.falsy(KCM.Schema:Set("skin.skin", "no-such-skin"), "a key no skin carries is refused")
    t.eq(KCM.db.profile.skin.skin, "obsidian", "and stores nothing")

    KCM.WriteSkinChoice("ka0s", "ember", { panel = false, fonts = true }, { font = false, texture = "Solid" })
    local p = KCM.db.profile.skin
    t.eq(p.skin, "ember", "WriteSkinChoice stores the skin")
    t.eq(p.ignorePanel, false, "the Scope's panel half")
    t.eq(p.ignoreFonts, true, "and its fonts half")
    t.eq(p.font, "", "an override back to the skin's own is stored as empty")
    t.eq(p.texture, "Solid", "a texture override is its LSM key")
    t.eq(select(2, KCM.SkinChoice()), "ember", "SkinChoice reads the stored pair back")
end)

-- red under: a profile event that leaves the previous profile's skin on screen.
test("Skin: the profile's skin is applied at login and on every profile event", function(t)
    local KCM = h.loader.loadFullAddon()
    local Skin = skinLib()
    KCM.db:SetProfile("Alt")
    KCM.db.profile.skin.skin = "glass"
    KCM.db:SetProfile("Default")
    t.eq(select(2, Skin:GetChoice(OWNER)), "ka0s", "a switch back applies Default's Ka0s Default")
    KCM.db:SetProfile("Alt")
    t.eq(select(2, Skin:GetChoice(OWNER)), "glass", "a switch applies the new profile's skin")
    KCM.db:ResetProfile()
    t.eq(select(2, Skin:GetChoice(OWNER)), "ka0s", "a reset puts Ka0s Default back on")

    local src = readFile(ROOT .. "/core/ConsumableMaster.lua") or ""
    local init = src:match("function KCM:OnInitialize%(%)(.-)\nend")
    t.truthy(init and init:find("KCM.ApplySkinChoice()", 1, true),
        "OnInitialize applies the stored choice once AceDB exists")
end)

-- red under: a factory that takes an owner called without one, which draws Ka0s Default under
-- every skin (skinning-§1).
test("Skin: every library factory that takes an owner is handed this addon's", function(t)
    local sites = {
        { "modules/MacroBar.lua", "Widgets.DragHandle(frame, {", 1 },
        { "settings/Category.lua", "W.ReorderList({", 2 },
        { "settings/MacroBar.lua", "W.ReorderList({", 1 },
        { "settings/StatPriority.lua", "W.ReorderList({", 1 },
    }
    for _, site in ipairs(sites) do
        local src = readFile(ROOT .. "/" .. site[1]) or ""
        local calls, owned = 0, 0
        local from = 1
        while true do
            local s, e = src:find(site[2], from, true)
            if not s then break end
            calls = calls + 1
            local body = src:sub(e, (src:find("\n%s*}%)", e) or #src))
            -- A settings page's list takes the owner plainly: ReorderList is panel-scoped by
            -- default (WidgetsReorder minor 3), so it draws minor 1's colors while the Scope
            -- ignores the settings panel.
            if body:find("owner%s*=%s*addonName") then
                owned = owned + 1
            end
            from = e + 1
        end
        t.eq(calls, site[3], site[1] .. " makes " .. site[3] .. " " .. site[2] .. " call(s)")
        t.eq(owned, calls, site[1] .. ": every call passes this addon as its owner")
    end
end)

-- red under: the seam loaded after a frame-building file, or EllesmereUI missing from the deps.
test("Skin: the TOC loads the seam before every frame and lists EllesmereUI as optional", function(t)
    local files = h.loader.tocFiles()
    local at = {}
    for i, rel in ipairs(files) do at[rel] = i end
    t.truthy(at["core/SkinSetup.lua"], "core/SkinSetup.lua is in the TOC")
    t.truthy(at["core/SkinSetup.lua"] > at["core/CoreSetup.lua"], "after core/CoreSetup.lua")
    for _, later in ipairs({ "core/LauncherSetup.lua", "core/DebugLogSetup.lua", "modules/MacroBar.lua",
                             "settings/OptionsSetup.lua", "settings/General.lua" }) do
        t.truthy(at["core/SkinSetup.lua"] < at[later], "before " .. later)
    end
    local toc = readFile(ROOT .. "/ConsumableMaster.toc") or ""
    local deps = toc:match("## OptionalDeps:([^\r\n]*)") or ""
    t.truthy(deps:find("EllesmereUI", 1, true), "## OptionalDeps lists EllesmereUI (skinning-§5)")
    t.falsy(toc:find("## Dependencies:[^\r\n]*EllesmereUI"), "and never as a hard dependency")
end)
