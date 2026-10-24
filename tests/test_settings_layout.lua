-- test_settings_layout.lua — item 020 (settings layout), the words and headings the
-- General, Macros and Stat Priority pages draw after the layout pass (CM-LY).
--
-- The Macro Bar half lives beside the strip it rearranged (tests/test_settingsui.lua,
-- tests/test_schema.lua), and tests/test_schema.lua's layout-pass guard pins that
-- no stored path, default, range or enum value moved. This file pins the rest:
-- what each page SAYS, because a relabel is the whole of the change and a revert
-- is otherwise invisible to every other suite.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

-- Render one page (on `tab` when it is the Macros page) with spies on the shared
-- helpers the page builders call, and hand back what they drew: every AceGUI
-- widget's text and label, every button spec, every tab strip and banner spec.
local function renderPage(KCM, page, tab)
    local H = KCM.Settings.Helpers
    local UI = H.instance
    local AceGUI = LibStub("AceGUI-3.0")
    local got = { buttons = {}, strips = {}, banners = {}, sections = {} }
    local realButton, realSection = H.Button, H.Section
    local realStrip, realBanner = UI.TabStrip, UI.PageBanner
    H.Button = function(ctx, spec) got.buttons[#got.buttons + 1] = spec; return realButton(ctx, spec) end
    H.Section = function(ctx, text, ...)
        got.sections[#got.sections + 1] = text
        return realSection(ctx, text, ...)
    end
    UI.TabStrip = function(ctx, spec) got.strips[#got.strips + 1] = spec; return realStrip(ctx, spec) end
    UI.PageBanner = function(ctx, spec) got.banners[#got.banners + 1] = spec; return realBanner(ctx, spec) end
    local before = #AceGUI.__created
    local ok, err = pcall(function()
        if not UI.__panelFor(page) then KCM.Settings.builders[page]({}) end
        local ctx = UI.__panelFor(page)
        if tab then KCM.Options.SetMacroTab(tab) end
        ctx.panel.IsShown = function() return true end
        H.RefreshAllPanels()
        ctx.panel.IsShown = function() return false end
    end)
    H.Button, H.Section, UI.TabStrip, UI.PageBanner = realButton, realSection, realStrip, realBanner
    if not ok then error(err, 0) end
    got.texts, got.labels = {}, {}
    for i = before + 1, #AceGUI.__created do
        local w = AceGUI.__created[i]
        if w.__text then got.texts[#got.texts + 1] = w.__text end
        if w.__label then got.labels[#got.labels + 1] = w.__label end
    end
    return got
end

local function has(list, want)
    for _, v in ipairs(list) do if v == want then return true end end
    return false
end

local function buttonNamed(got, text)
    for _, b in ipairs(got.buttons) do if b.text == text then return b end end
    return nil
end

-- ── General page, Master controls (CON-L15) ────────────────────────────────

-- red under: dropping lockIsPreview or the notes, or a host rewrite of a composed
-- tooltip in their place.
test("Layout: Master controls takes the preview Lock frame tooltip and the two Macro Bar notes", function(t)
    local KCM = loader.loadFullAddon()
    local F = KCM.Settings.Helpers.FindSchema
    local lock = F("macroBar.locked").tooltip
    t.truthy(lock:find("this is the addon's test mode", 1, true), "Lock frame says unlocking is the preview")
    t.falsy(lock:find("combat", 1, true), "and adds no combat clause: the lock is honored in combat")
    t.truthy(F("scale").tooltip:find(" Multiplies the Macro Bar page's Bar scale.", 1, true),
        "Master scale names the row it multiplies")
    t.truthy(F("alpha").tooltip:find(" Multiplies the Macro Bar page's Bar opacity and Faded opacity.", 1, true),
        "Master opacity names both rows it multiplies")
    t.eq(F("alpha").label, "Master opacity", "the composer's label, untouched")
end)

-- red under: the confirm-gated Maintenance button losing its ellipsis.
test("Layout: Reset all priorities… ends in an ellipsis because it raises a popup", function(t)
    local KCM = loader.loadFullAddon()
    KCM.Settings.builders.general({})
    KCM.Settings.Helpers.instance.__panelFor("general").activeTab = "Maintenance"
    local got = renderPage(KCM, "general")
    local b = buttonNamed(got, "Reset all priorities…")
    t.truthy(b, "the button is drawn under its new name")
    t.truthy(b and b.tooltip:find("the General page > Master controls", 1, true),
        "its tooltip names the whole-profile reset by its location string")
end)

-- ── Macros page (CON-L01, L16-L18, L21, L22, L25, L31, L32, L-new3) ────────

test("Layout: a single Macros tab reads Macro, Add an item or spell, Priority list", function(t)
    local KCM = loader.loadFullAddon()
    local got = renderPage(KCM, "macros", "FOOD")
    t.eqList(got.sections, { "Macro", "Add an item or spell", "Priority list" }, "the headings, in order")
    t.truthy(buttonNamed(got, "Reset category…"), "Reset category raises a popup, so it ends in an ellipsis")
    local tips = {}
    for _, entry in ipairs(got.strips[1] and got.strips[1].tabs or {}) do tips[entry.key] = entry.tooltip end
    t.eq(tips.FOOD, "Add-by-ID and the priority list for the KCM_FOOD macro.", "a single tab's tooltip")
    t.eq(tips.HP_AIO, "Which categories the KCM_HP_AIO macro uses, in and out of combat, and their order.",
        "a composite tab's tooltip")
end)

test("Layout: a spec-aware tab says where its spec is changed", function(t)
    local KCM = loader.loadFullAddon()
    KCM.Options._viewedSpec, KCM.Options._viewedSpecAuto = "8_262", false
    local got = renderPage(KCM, "macros", "FLASK")
    local line
    for _, s in ipairs(got.texts) do
        if s:find("^Spec%-aware%.") then line = s end
    end
    t.truthy(line and line:find("^Spec%-aware%. Showing the list for .+%. Change the spec in the Stat Priority page's banner%.$"),
        "the spec line: " .. tostring(line))
end)

test("Layout: the Macros empty states say where to fix them", function(t)
    local KCM = loader.loadFullAddon()
    KCM.Options._viewedSpec, KCM.Options._viewedSpecAuto = nil, true
    local realGetCurrent = KCM.SpecHelper.GetCurrent
    KCM.SpecHelper.GetCurrent = function() return nil, nil, nil end
    local ok, got = pcall(renderPage, KCM, "macros", "FLASK")
    KCM.SpecHelper.GetCurrent = realGetCurrent
    if not ok then error(got, 0) end
    t.truthy(has(got.texts, "|cffff8800No active spec.|r Pick one in the Stat Priority page's banner to see this list."),
        "no spec: points at the banner")

    -- No candidates at all: the list the page draws is the Selector's answer.
    local realPriority = KCM.Selector.GetEffectivePriority
    KCM.Selector.GetEffectivePriority = function() return {} end
    ok, got = pcall(renderPage, KCM, "macros", "FOOD")
    KCM.Selector.GetEffectivePriority = realPriority
    if not ok then error(got, 0) end
    local empty = "|cffff8800(empty)|r — no candidates yet. Add an item or spell above, or pick up a matching item to trigger auto-discovery."
    t.truthy(has(got.texts, empty), "the empty list names an item or a spell")
end)

test("Layout: a composite tab reads Macro, In combat, Out of combat, with In macro ticks", function(t)
    local KCM = loader.loadFullAddon()
    local got = renderPage(KCM, "macros", "HP_AIO")
    t.eqList(got.sections, { "Macro", "In combat", "Out of combat" }, "the headings, sentence case")
    local n = 0
    for _, l in ipairs(got.labels) do if l == "In macro" then n = n + 1 end end
    t.eq(n, 3, "one In macro checkbox per sub-category (HS, HP_POT, FOOD)")
    t.falsy(has(got.labels, "Enabled"), "no row checkbox reads Enabled any more")
    local b = buttonNamed(got, "Reset category…")
    t.eq(b and b.tooltip, "Put back the shipped In macro ticks and the order of both sections.",
        "the composite reset names the ticks by their label")
end)

-- ── Stat Priority page (CON-L03, L24, L25) ─────────────────────────────────

test("Layout: the Stat Priority banner lists the spec-aware tabs in strip order", function(t)
    local KCM = loader.loadFullAddon()
    KCM.Options._viewedSpec, KCM.Options._viewedSpecAuto = "8_262", false
    local got = renderPage(KCM, "statpriority")
    local tip = got.banners[1] and got.banners[1].tooltip or ""
    t.truthy(tip:find("the Macros page's Flask, Combat Potion, Stat Food and Weapon Enchant tabs.", 1, true),
        "Flask, Combat Potion, Stat Food, Weapon Enchant: " .. tip)
    t.truthy(buttonNamed(got, "Reset this spec's stat priority"), "the reset says its scope, with no ellipsis")
    t.eq(KCM.Options.FormatSpec(nil), "(no spec)", "the picker's empty placeholder")
end)
