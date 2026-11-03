-- test_icon_rule.lua — the icon rule on this addon's settings pages (R5-ICON of Ka0sAddonsCommonTasks
-- docs/2026-11-03-SMOKE_ROUND5, the lead's call 9; the rule is LibKa0s docs/api/README.md's
-- "Icon art: the rule").
--
-- WHAT IT PROVES. Every Blizzard icon art on a settings page is cropped by at least 0.07 a side and,
-- while the settings panel is skinned, edged 1 px in `icon.outline`, the window outline, never the
-- HUD's `icon.border`. The edge is a plain frame the widget owns, laid over the icon, never a record
-- on the art itself, so a pooled widget hands it back at release. The two framed icons are an item
-- row's item or spell icon (modules/KCMItemRow.lua) and the Macros page's drag icon
-- (modules/KCMMacroDragIcon.lua). The Stat Priority spec label's inline icon is markup, so it is
-- cropped to 5..59 of 64 and takes no edge. The icon buttons and the score button draw an atlas and
-- a Ka0s catalog mark, which the rule exempts; the macro bar and its flyout are HUD, cropped by the
-- player's icon zoom and edged by the bar's own border.

local h = _G.KCM_TEST
local test = h.test

local ROOT = _G.KCM_TEST_ROOT or "."
local OWNER = "ConsumableMaster"
local buildWidget = dofile(ROOT .. "/tests/skin_widget_support.lua")

local function rgba(c) return c and ("%.3f,%.3f,%.3f,%.3f"):format(c[1], c[2], c[3], c[4] or 1) or "nil" end

local function scope(skin, panelIgnored)
    local Skin = LibStub("LibKa0s-Skin-1.0", true)
    Skin:SetIgnore(OWNER, panelIgnored, false)
    Skin:SetChoice(OWNER, "ka0s", skin)
    return Skin
end

--- The 0.07 crop on all four sides, with float slack.
local function cropped(t, tex, what)
    local l, top, _, _, _, _, r, b = tex:GetTexCoord()
    t.truthy(l >= 0.07 - 1e-6 and top >= 0.07 - 1e-6, what .. ": cropped from the top left, got " .. l .. "," .. top)
    t.truthy(r <= 0.93 + 1e-6 and b <= 0.93 + 1e-6, what .. ": cropped from the bottom right, got " .. r .. "," .. b)
end

--- The color S.IconBorder drew on `frame`'s top edge, or nil when nothing edged it.
local function edgeColor(Skin, frame)
    local rec = Skin.painted[frame]
    if not (rec and rec.calls.IconBorder) then return nil end
    local top = rec.regions.edgeTop
    return top and rgba(top.__color)
end

--- The harness's plain frame answers every method with a chaining no-op, so its shown state is not
--- kept; give the edge frame a real one before the widget is drawn.
local function trackShown(f)
    if not f then return f end
    rawset(f, "__shown", true)
    rawset(f, "Show", function(self) rawset(self, "__shown", true) end)
    rawset(f, "Hide", function(self) rawset(self, "__shown", false) end)
    rawset(f, "SetShown", function(self, v) rawset(self, "__shown", not not v) end)
    rawset(f, "IsShown", function(self) return rawget(self, "__shown") end)
    return f
end

local WIDGETS = {
    { file = "modules/KCMItemRow.lua", type = "KCMItemRow", icon = "itemTex", edge = "itemEdge",
      fill = function(w) w:SetCustomData({ itemID = 191381, owned = true }) end },
    { file = "modules/KCMMacroDragIcon.lua", type = "KCMMacroDragIcon", icon = "icon", edge = "iconEdge",
      fill = function(w) w:SetCustomData({ macroName = "KCM_FLASK" }) end },
}

-- red under: an item row's or the drag icon's art drawn whole, with Blizzard's bevelled corners.
test("Icon rule: a settings page's item and macro icons are cropped by 0.07, skinned or not", function(t)
    local KCM = h.loader.loadPure()
    for _, c in ipairs(WIDGETS) do
        local w, _, cleanup = buildWidget(KCM, c.file, c.type)
        if w then trackShown(w[c.edge]) end
        local ok, err = pcall(function()
            for _, ignored in ipairs({ false, true }) do
                scope("ka0s", ignored)
                w:OnAcquire()
                c.fill(w)
                cropped(t, w[c.icon], c.type .. (ignored and " (panel ignored)" or " (panel skinned)"))
            end
        end)
        cleanup()
        t.truthy(ok, tostring(err))
    end
end)

-- red under: no edge, the HUD's black, or an edge drawn on the pooled art itself.
test("Icon rule: with the panel skinned the icon wears the window outline, on a frame of its own", function(t)
    local KCM = h.loader.loadPure()
    for _, c in ipairs(WIDGETS) do
        local w, _, cleanup = buildWidget(KCM, c.file, c.type)
        if w then trackShown(w[c.edge]) end
        local ok, err = pcall(function()
            for _, skin in ipairs({ "ka0s", "forever" }) do
                local Skin = scope(skin, false)
                w:OnAcquire()
                c.fill(w)
                local e = w[c.edge]
                t.truthy(e, c.type .. " has an edge frame")
                t.truthy(e and e:IsShown(), c.type .. ": the edge shows under " .. skin)
                local got = e and edgeColor(Skin, e)
                t.eq(got, rgba(KCM.Skin.Token("icon.outline")), c.type .. ": icon.outline under " .. skin)
                t.truthy(got ~= rgba(KCM.Skin.Token("icon.border")) or skin ~= "ka0s",
                    c.type .. ": never the HUD's black under Ka0s Default")
                t.falsy(Skin.painted[w[c.icon]], c.type .. ": nothing recorded on the art itself")
            end
        end)
        cleanup()
        t.truthy(ok, tostring(err))
    end
end)

-- red under: an edge left standing around a stock settings page.
test("Icon rule: with the panel ignored the edge is hidden and the crop stays", function(t)
    local KCM = h.loader.loadPure()
    for _, c in ipairs(WIDGETS) do
        local w, _, cleanup = buildWidget(KCM, c.file, c.type)
        if w then trackShown(w[c.edge]) end
        local ok, err = pcall(function()
            scope("ka0s", false)
            w:OnAcquire()
            c.fill(w)
            scope("ka0s", true)
            w:OnAcquire()
            c.fill(w)
            local e = w[c.edge]
            t.truthy(e and not e:IsShown(), c.type .. ": no edge on the stock page")
            cropped(t, w[c.icon], c.type)
        end)
        cleanup()
        scope("ka0s", false)
        t.truthy(ok, tostring(err))
    end
end)

-- red under: a released widget's edge still recorded, so a skin switch repaints a widget in the pool.
test("Icon rule: a pooled widget's edge leaves the skin's record at release", function(t)
    local KCM = h.loader.loadPure()
    for _, c in ipairs(WIDGETS) do
        local w, _, cleanup = buildWidget(KCM, c.file, c.type)
        if w then trackShown(w[c.edge]) end
        local ok, err = pcall(function()
            local Skin = scope("obsidian", false)
            w:OnAcquire()
            c.fill(w)
            t.truthy(Skin.painted[w[c.edge]], c.type .. ": the edge is recorded")
            w:OnRelease()
            t.falsy(Skin.painted[w[c.edge]], c.type .. ": the edge left at release")
        end)
        cleanup()
        t.truthy(ok, tostring(err))
    end
end)

-- red under: the spec label's inline icon drawn whole (`|T<icon>:16|t`).
test("Icon rule: the Stat Priority spec label's icon markup is cropped to 5..59 of 64", function(t)
    local KCM = h.loader.loadFullAddon()
    local C = KCM.Compat
    local savedN, savedInfo = C.GetNumSpecializationsForClassID, C.GetSpecializationInfoForClassID
    C.GetNumSpecializationsForClassID = function() return 1 end
    C.GetSpecializationInfoForClassID = function() return 262, "Elemental", nil, 136048 end
    local ok, err = pcall(function()
        local label = KCM.Options.FormatSpec("7_262")
        t.truthy(label:find("|T136048:16:16:0:0:64:64:5:59:5:59|t", 1, true), "cropped markup: " .. label)
    end)
    C.GetNumSpecializationsForClassID, C.GetSpecializationInfoForClassID = savedN, savedInfo
    t.truthy(ok, tostring(err))
end)
