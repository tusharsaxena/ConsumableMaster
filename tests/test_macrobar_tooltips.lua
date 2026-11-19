-- tests/test_macrobar_tooltips.lua — where the macro bar's own tooltips open (AD-92-CM,
-- LibKa0s#92; WowAddonStandards standalone-windows, *Tooltip placement*).
--
-- The bar is a HUD display. A slot and a flyout entry are BODY elements: their tooltip opens beside
-- the WHOLE display (the bar, its drag strip and every open flyout, registered as one window group
-- with LibKa0s-Tooltip-1.0's SetGroup), right when it fits and otherwise left, its top level with the
-- hovered element's top, never at the cursor and never at a corner of the slot. The drag strip is
-- CHROME and its four tooltips are tests/test_macrobar_chrome.lua's.
--
-- THE SCREEN. The kit's opt-in fake screen (tests/_kit/mock_screen.lua, kit revision 57) answers
-- UIParent's geometry and records the tooltip's points; `place` below gives the addon's own frames
-- (built by the real addon code) the same edge reads. The CreateFrame wrapper records each frame's
-- parent, which this repo's stub does not, so the library's GroupOf can walk up from a slot to the
-- bar. It is installed in loadFiles' `mutate` window, because modules/MacroBarButton.lua and
-- modules/MacroBarFlyout.lua cache CreateFrame at load.
--
-- THE GUARD at the bottom holds the addon's own code to no cursor anchor at all, and the
-- `ANCHOR_RIGHT` sites to the Settings-canvas pages the rule does not bind (docs/ARCHITECTURE.md,
-- *Tooltip placement*).

local h = _G.KCM_TEST
local test = h.test
local ROOT = _G.KCM_TEST_ROOT or "."

local support = dofile(ROOT .. "/tests/macrobar_support.lua")

local SCREEN_W, SCREEN_H = 1920, 1080
local GAP = 2   -- LibKa0s-Tooltip-1.0's TIP_GAP

--- The full addon with parent-aware, show-aware frames, its bar built and unlocked.
local function loadBar()
    local KCM = h.loader.loadFiles(h.loader.tocFiles(), nil, function()
        local base = _G.CreateFrame
        _G.CreateFrame = function(kind, name, parent, template)
            local f = base(kind, name, parent, template)
            local p = parent
            rawset(f, "GetParent", function() return p end)
            rawset(f, "SetParent", function(_, np) p = np end)
            if name then _G[name] = f end   -- the client publishes a named frame
            rawset(f, "Show", function(self) rawset(self, "__shown", true) end)
            rawset(f, "Hide", function(self) rawset(self, "__shown", false) end)
            rawset(f, "SetShown", function(self, on) rawset(self, "__shown", on and true or false) end)
            rawset(f, "IsShown", function(self) return rawget(self, "__shown") == true end)
            -- The frame's own flag stands in for IsVisible: the stub's catch-all answered a table, so
            -- every built flyout (unplaced, its edges reading 0) joined the bar's window group.
            rawset(f, "IsVisible", function(self) return rawget(self, "__shown") == true end)
            return f
        end
    end)
    KCM.db.profile.macroBar.enabled = true
    KCM.db.profile.macroBar.locked  = false
    KCM.MacroBar.Update()
    return KCM, _G.KCMMacroBar
end

--- Give an addon-built frame edge reads, in its own units at effective scale `s` (1 unless given).
local function place(f, l, b, w, hgt, s)
    rawset(f, "GetLeft", function() return l end)
    rawset(f, "GetBottom", function() return b end)
    rawset(f, "GetRight", function() return l + w end)
    rawset(f, "GetTop", function() return b + hgt end)
    rawset(f, "GetWidth", function() return w end)
    rawset(f, "GetHeight", function() return hgt end)
    rawset(f, "GetEffectiveScale", function() return s or 1 end)
    return f
end

--- The fake screen and a recording GameTooltip 250 x 90 on it. This repo's mock
--- (tests/wow_mock.lua) publishes UIParent and CreateFrame as globals rather than as the kit
--- base's `M.UIParent` / `M.CreateFrame`, so the installer is handed those two by name.
local function screen()
    local shim = { UIParent = _G.UIParent, CreateFrame = _G.CreateFrame }
    local scr = dofile(ROOT .. "/tests/_kit/mock_screen.lua")(shim,
        { width = SCREEN_W, height = SCREEN_H })
    local tip = scr.tooltip{ width = 250, height = 90 }
    _G.GameTooltip = tip
    return scr, tip
end

--- Every anchor the tooltip was owned at, in order.
local function ownerAnchors(tip)
    local out = {}
    for _, e in ipairs(tip.__log) do
        if e.op == "SetOwner" then out[#out + 1] = e.anchor end
    end
    return out
end

--- The hover's common assertions: owned once, at ANCHOR_NONE (so never at the cursor nor at a
--- corner of the slot), and placed by one absolute point on UIParent's BOTTOMLEFT.
local function assertPlacedBeside(t, tip, what)
    local anchors = ownerAnchors(tip)
    t.eq(#anchors, 1, what .. ": owned once")
    t.eq(anchors[1], "ANCHOR_NONE", what .. ": never the cursor, never a corner anchor")
    local p = tip.__point
    t.truthy(p, what .. ": placed")
    t.truthy(p and rawequal(p.rel, _G.UIParent), what .. ": one absolute point on UIParent")
    t.eq(p and p.relPoint, "BOTTOMLEFT", what)
end

--- A slot on the bar, placed: the bar at `barL`, 400 x 44 at y 500, the slot its first 40 px.
local function slotOnBar(KCM, bar, barL)
    place(bar, barL, 500, 400, 44)
    local btn = KCM.MacroBarButton.Create(bar, "FOOD", 99)
    place(btn, barL + 4, 502, 40, 40)
    if btn.flyout then btn.flyout:Hide() end
    if bar.handle then bar.handle:Hide() end
    return btn
end

-- red under: MD.SetTooltip owning the slot's tooltip at ANCHOR_RIGHT (its bottom-left on the
-- slot's top-right corner, over the next slot), or a placement beside the slot alone.
test("bar tooltip: a slot's tooltip opens right of the whole bar, top level with the slot", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local btn = slotOnBar(KCM, bar, 800)
    btn:GetScript("OnEnter")(btn)
    assertPlacedBeside(t, tip, "slot")
    t.eq(tip.__point and tip.__point.point, "TOPLEFT", "its top-left")
    local l, _, _, top = scr.rectOf(tip)
    t.eq(l, 1200 + GAP, "outside the bar's right edge, by the gap -- not beside the slot (844)")
    t.eq(top, 542, "top level with the slot's top")
    t.eq(rawget(tip, "__anchorType"), "ANCHOR_RIGHT", "comparison tooltips open further out on the same side")
    scr.restore()
end)

-- red under: a placement that always opens right (1900 + 2 + 250 runs off a 1920 px screen).
test("bar tooltip: a slot's tooltip flips to the bar's left when the right side has no room", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local btn = slotOnBar(KCM, bar, 1500)
    btn:GetScript("OnEnter")(btn)
    assertPlacedBeside(t, tip, "slot at the right edge")
    t.eq(tip.__point and tip.__point.point, "TOPRIGHT", "its top-right")
    local _, _, r, top = scr.rectOf(tip)
    t.eq(r, 1500 - GAP, "outside the bar's left edge, by the gap")
    t.eq(top, 542, "top level with the slot's top")
    scr.restore()
end)

-- red under: a bar not registered as a window group (SetGroup), whose GroupOf is the bar alone,
-- so the tooltip would land over the open flyout that reaches past the bar's right edge.
test("bar tooltip: an open flyout and the drag strip count as the bar's window group", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local btn = slotOnBar(KCM, bar, 800)
    t.truthy(btn.flyout, "the slot built its flyout")
    place(btn.flyout, 1150, 400, 120, 40)
    btn.flyout:Show()
    btn:GetScript("OnEnter")(btn)
    local l = scr.rectOf(tip)
    t.eq(l, 1270 + GAP, "beyond the open flyout, never over it")

    btn.flyout:Hide()
    t.truthy(bar.handle, "the strip was drawn")
    place(bar.handle, 750, 546, 520, 16)
    bar.handle:Show()
    btn:GetScript("OnEnter")(btn)
    l = scr.rectOf(tip)
    t.eq(l, 1270 + GAP, "beyond the drag strip, which is wider than the bar here")

    bar.handle:Hide()
    btn:GetScript("OnEnter")(btn)
    l = scr.rectOf(tip)
    t.eq(l, 1200 + GAP, "a hidden flyout and a hidden strip drop out of the group")
    scr.restore()
end)

-- red under: MD.SetTooltipForID owning at ANCHOR_RIGHT on the entry, or a right preference forced
-- on every member. Re-pinned by the AD-92-CM review fixes to the rule's companion side: a flyout
-- is a panel docked to the bar, and this one (over the bar's first slot, its center left of the
-- bar's) opens its entries' tooltips on its own side, left, outside the whole group.
test("bar tooltip: a flyout entry's tooltip opens beside the group, outside the flyout", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local btn = slotOnBar(KCM, bar, 800)
    place(btn.flyout, 804, 546, 40, 130)
    btn.flyout:Show()
    -- An entry as FO's createEntry parents it: a child of the flyout.
    local entry = place(_G.CreateFrame("Button", nil, btn.flyout), 804, 636, 40, 40)
    KCM.MacroDisplay.SetTooltipForID(entry, 1234)
    assertPlacedBeside(t, tip, "flyout entry")
    t.eq(tip.__point and tip.__point.point, "TOPRIGHT", "its top-right")
    local _, _, r, top = scr.rectOf(tip)
    t.eq(r, 800 - GAP, "outside the whole group's left edge, the flyout's side, not on the entry's corner")
    t.eq(top, 676, "top level with the entry's top")
    scr.restore()
end)

--- A slot on the bar with its flyout open at (fl, fb, fw, fh) and one entry in it at (el, eb).
local function entryInFlyout(KCM, bar, fl, fb, fw, fh, el, eb)
    local btn = slotOnBar(KCM, bar, 800)
    place(btn.flyout, fl, fb, fw, fh)
    btn.flyout:Show()
    return place(_G.CreateFrame("Button", nil, btn.flyout), el, eb, 40, 40)
end

-- red under: a right preference forced on a flyout entry (PREFER_RIGHT until the AD-92-CM review
-- fixes), which opened a Left flyout's entry tooltips right of the bar, the side of the main
-- window, against body rule 1's companion side.
test("bar tooltip: a Left flyout's entry tooltip opens left, beyond the flyout", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local entry = entryInFlyout(KCM, bar, 620, 502, 180, 40, 620, 502)
    KCM.MacroDisplay.SetTooltipForID(entry, 1234)
    assertPlacedBeside(t, tip, "Left flyout entry")
    local _, _, r, top = scr.rectOf(tip)
    t.eq(r, 620 - GAP, "outside the open flyout's left edge, away from the bar")
    t.eq(top, 542, "top level with the entry's top")
    scr.restore()
end)

test("bar tooltip: a Right flyout's entry tooltip opens right, beyond the flyout", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local entry = entryInFlyout(KCM, bar, 1200, 502, 180, 40, 1340, 502)
    KCM.MacroDisplay.SetTooltipForID(entry, 1234)
    assertPlacedBeside(t, tip, "Right flyout entry")
    local l = scr.rectOf(tip)
    t.eq(l, 1380 + GAP, "outside the open flyout's right edge, away from the bar")
    scr.restore()
end)

-- A companion's side that has no room: the tooltip goes outside the group's other edge.
test("bar tooltip: a Left flyout at the screen's left edge opens its entry tooltip right of the bar", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    local entry = entryInFlyout(KCM, bar, 20, 502, 130, 40, 20, 502)
    place(bar, 150, 500, 400, 44)   -- the whole group at the left edge: 20 - 2 - 250 < 0
    KCM.MacroDisplay.SetTooltipForID(entry, 1234)
    assertPlacedBeside(t, tip, "Left flyout entry, left edge")
    local l = scr.rectOf(tip)
    t.eq(l, 550 + GAP, "outside the group's right edge, never over the flyout")
    scr.restore()
end)

-- The real entry's OnEnter, through FO.Apply's own build. Retail only: the HP_POT seed the case
-- stocks is Retail's.
h.retailTest("bar tooltip: a built flyout entry's hover places beside the group", function(t)
    local KCM, bar = loadBar()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    mock.setItem(seed[1], { name = "Pot", subType = "Potions" })
    mock.setBag(seed[1], 1)
    local scr, tip = screen()
    place(bar, 800, 500, 400, 44)
    if bar.handle then bar.handle:Hide() end   -- unplaced, the strip would read 0 and widen the group
    local btn = KCM.MacroBarButton.Create(bar, "HP_POT", 98)
    place(btn, 804, 502, 40, 40)
    KCM.MacroBarFlyout.Apply(btn, support.fcfg{ flyout = true })
    local e = btn.flyout.entries[1]
    t.truthy(e, "an entry was built")
    place(btn.flyout, 804, 546, 40, 44)
    btn.flyout:Show()
    place(e, 804, 548, 40, 40)
    e:GetScript("OnEnter")(e)
    assertPlacedBeside(t, tip, "built entry")
    -- Re-pinned by the AD-92-CM review fixes: the flyout (over the bar's first slot) is a companion
    -- left of the bar's center, so its entry's tooltip opens on its side, outside the group's left.
    local _, _, r, top = scr.rectOf(tip)
    t.eq(r, 800 - GAP, "beside the group, on the flyout's side")
    t.eq(top, 588, "top level with the entry")
    scr.restore()
end)

-- red under: a fallback that re-owns at the cursor, or one that guesses a point.
test("bar tooltip: unreadable geometry attaches above the slot, never the cursor", function(t)
    local KCM, bar = loadBar()
    local scr, tip = screen()
    -- Never placed: every edge reads nil, as a frame the client has not laid out does. This repo's
    -- frame stub answers 0 for an edge it was never given, so the nils are set here.
    local btn = KCM.MacroBarButton.Create(bar, "FOOD", 97)
    for _, m in ipairs({ "GetLeft", "GetBottom", "GetRight", "GetTop" }) do
        rawset(btn, m, function() return nil end)
    end
    btn:GetScript("OnEnter")(btn)
    local anchors = ownerAnchors(tip)
    t.eq(#anchors, 1, "owned once")
    t.eq(anchors[1], "ANCHOR_NONE", "never re-owned at the cursor")
    local p = tip.__point
    t.truthy(p, "the fallback anchors it")
    t.eq(p and p.point, "BOTTOM", "its bottom")
    t.truthy(p and rawequal(p.rel, btn), "on the slot")
    t.eq(p and p.relPoint, "TOP", "above it")
    t.eq(p and p.y, GAP, "by the gap")
    scr.restore()
end)

-- The Settings-canvas drag icon shares MD.SetTooltip and keeps the canvas's own anchor: the rule
-- does not bind a Settings canvas page (standalone-windows, *What it does not bind*).
test("bar tooltip: MD.SetTooltip with no placer keeps the Settings canvas's anchor", function(t)
    local KCM = loadBar()
    local scr, tip = screen()
    KCM.MacroDisplay.SetTooltip(h.loader.mock.makeStub(), "KCM_FOOD")
    t.eqList(ownerAnchors(tip), { "ANCHOR_RIGHT" }, "the canvas page's convention, out of scope")
    t.falsy(tip.__point, "and no placement")
    scr.restore()
end)

-- ---------------------------------------------------------------------------
-- The guard: no cursor anchor in the addon's own code, and ANCHOR_RIGHT only on the
-- Settings-canvas pages the rule does not bind.
-- ---------------------------------------------------------------------------

-- The closed list of the own code lines that still own a tooltip at ANCHOR_RIGHT, each a Settings
-- canvas page's (docs/ARCHITECTURE.md, *Tooltip placement*, out of scope): per file, the one
-- allowed line, whitespace-trimmed. A file may carry that line once and no other ANCHOR_RIGHT, so a
-- HUD path added to a file that also serves the canvas (core/MacroDisplay.lua) is still caught.
local CANVAS_RIGHT = {
    -- MD.SetTooltip's no-placer branch: the Macros page's drag icon
    ["core/MacroDisplay.lua"]      =
        'if place then ownForPlacement(owner) else GameTooltip:SetOwner(owner, "ANCHOR_RIGHT") end',
    -- a priority row on the Macros page
    ["modules/KCMItemRow.lua"]     = 'GameTooltip:SetOwner(self, "ANCHOR_RIGHT")',
    -- a slot row's tick on the Macro Bar page's Buttons tab
    ["settings/MacroBarSlots.lua"] = 'GameTooltip:SetOwner(glyph, "ANCHOR_RIGHT")',
    -- a stat row's tick on the Stat Priority page
    ["settings/StatPriority.lua"]  = 'GameTooltip:SetOwner(self, "ANCHOR_RIGHT")',
}

--- Every ANCHOR_RIGHT site in `code` (comments stripped) that the allow-list does not cover for
--- `rel`: a list of trimmed lines, empty when the file is clean.
local function strayRight(rel, code)
    local allowed, seen, out = CANVAS_RIGHT[rel], 0, {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        if line:find("ANCHOR_RIGHT", 1, true) then
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed == allowed and seen == 0 then
                seen = 1
            else
                out[#out + 1] = trimmed
            end
        end
    end
    return out
end

--- The addon's own Lua files, from its TOC (the vendored libraries are not its own).
local function ownFiles()
    local out = {}
    for _, rel in ipairs(h.loader.tocFiles()) do
        if rel:match("^core/") or rel:match("^modules/") or rel:match("^settings/")
                or rel:match("^locales/") then
            out[#out + 1] = rel
        end
    end
    return out
end

--- `src` with every `--` comment removed, so a comment naming an anchor is not a site.
local function codeOf(src)
    local out = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = (line:gsub("%-%-.*$", ""))
    end
    return table.concat(out, "\n")
end

test("bar tooltip guard: no own file anchors a tooltip at the cursor or a corner of a HUD element",
    function(t)
        local files = ownFiles()
        t.truthy(#files > 20, "the walk found the addon's files")
        local right = {}
        for _, rel in ipairs(files) do
            local fh = io.open(ROOT .. "/" .. rel, "rb")
            local code = codeOf(fh:read("*a")); fh:close()
            t.falsy(code:find("ANCHOR_CURSOR", 1, true), rel .. ": no ANCHOR_CURSOR(_RIGHT)")
            t.falsy(code:find("GetCursorPosition", 1, true), rel .. ": no cursor-following tooltip")
            for _, a in ipairs({ "ANCHOR_TOPRIGHT", "ANCHOR_TOPLEFT", "ANCHOR_TOP\"", "ANCHOR_LEFT",
                                 "ANCHOR_BOTTOM", "ANCHOR_PRESERVE" }) do
                t.falsy(code:find(a, 1, true), rel .. ": no " .. a)
            end
            for _, line in ipairs(strayRight(rel, code)) do right[#right + 1] = rel .. ": " .. line end
        end
        t.eqList(right, {}, "no ANCHOR_RIGHT outside the Settings canvas's allowed lines")
        for rel in pairs(CANVAS_RIGHT) do
            local fh = io.open(ROOT .. "/" .. rel, "rb")
            local code = codeOf(fh:read("*a")); fh:close()
            t.truthy(code:find(CANVAS_RIGHT[rel], 1, true), rel .. ": the allowed line is still there")
        end
    end)

-- The guard can fail: a planted cursor anchor and a HUD ANCHOR_RIGHT are both caught.
test("bar tooltip guard: the check is falsifiable", function(t)
    local planted = codeOf('GameTooltip:SetOwner(self, "ANCHOR_CURSOR") -- ANCHOR_NONE')
    t.truthy(planted:find("ANCHOR_CURSOR", 1, true), "a planted cursor anchor is seen")
    t.eq(#strayRight("modules/MacroBarButton.lua", 'GameTooltip:SetOwner(self, "ANCHOR_RIGHT")'), 1,
        "a slot's ANCHOR_RIGHT would be flagged")
    -- A HUD path owning at ANCHOR_RIGHT in the file that also serves the canvas.
    local mixed = CANVAS_RIGHT["core/MacroDisplay.lua"] .. "\n"
        .. '    GameTooltip:SetOwner(entry, "ANCHOR_RIGHT")'
    t.eqList(strayRight("core/MacroDisplay.lua", mixed), { 'GameTooltip:SetOwner(entry, "ANCHOR_RIGHT")' },
        "a second ANCHOR_RIGHT in a mixed file is caught")
    t.eq(#strayRight("core/MacroDisplay.lua", CANVAS_RIGHT["core/MacroDisplay.lua"] .. "\n"
        .. CANVAS_RIGHT["core/MacroDisplay.lua"]), 1, "and so is the allowed line twice")
    t.eq(#strayRight("core/MacroDisplay.lua", CANVAS_RIGHT["core/MacroDisplay.lua"]), 0,
        "the canvas branch alone passes")
    t.falsy(codeOf("-- ANCHOR_CURSOR in a comment"):find("ANCHOR_CURSOR", 1, true),
        "a comment is not a site")
end)
