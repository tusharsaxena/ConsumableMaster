-- tests/test_macrobar_layers.lua — where every frame the addon draws sits: the one layers
-- table (KCM.Constants.LAYERS, core/Constants.lua) and the strata, level, clamp and parent
-- alpha of each frame class the macro bar builds (frame-layering-§1 to §5, item 030).
--
-- THE RECORDER. The kit's opt-in frame-layer recorder (tests/_kit/mock_layers.lua) answers
-- strata and level back, inherited through parents, where this repo's stub answers 0 for every
-- level and stores nothing. It wraps a CreateFrame and reads each frame's `__parent`, which this
-- repo's stub does not record, so `withLayers` hands it a CreateFrame that does. It is installed
-- through loadFiles' `mutate` window -- after the mock, before the addon's own files --
-- because modules/MacroBarButton.lua and modules/MacroBarFlyout.lua cache CreateFrame at load.
-- The same wrapper records the three things the recorder does not: mouse, shown and the
-- strata writes, so "set once at construction" is a count, not a reading.

local h = _G.KCM_TEST
local test = h.test
local ROOT = _G.KCM_TEST_ROOT or "."

local support = dofile(ROOT .. "/tests/macrobar_support.lua")
local fcfg = support.fcfg

local function withLayers()
    local survey
    local KCM = h.loader.loadFiles(h.loader.tocFiles(), nil, function()
        local base = _G.CreateFrame
        local M = { UIParent = _G.UIParent }
        M.CreateFrame = function(kind, name, parent, template)
            local f = base(kind, name, parent, template)
            rawset(f, "__parent", parent)
            if name then _G[name] = f end   -- the client publishes a named frame
            rawset(f, "__strataWrites", 0)
            rawset(f, "EnableMouse", function(self, on) rawset(self, "__mouse", on and true or false) end)
            rawset(f, "Show", function(self) rawset(self, "__shown", true) end)
            rawset(f, "Hide", function(self) rawset(self, "__shown", false) end)
            rawset(f, "SetShown", function(self, on) rawset(self, "__shown", on and true or false) end)
            rawset(f, "IsShown", function(self) return rawget(self, "__shown") == true end)
            return f
        end
        dofile(ROOT .. "/tests/_kit/mock_layers.lua")(M)
        -- Count strata writes on top of the recorder's own method.
        local recCreate = M.CreateFrame
        _G.CreateFrame = function(...)
            local f = recCreate(...)
            local set = rawget(f, "SetFrameStrata")
            rawset(f, "SetFrameStrata", function(self, s)
                rawset(self, "__strataWrites", (rawget(self, "__strataWrites") or 0) + 1)
                return set(self, s)
            end)
            return f
        end
        survey = M.__layers
    end)
    return KCM, survey
end

local function bar(KCM)
    KCM.db.profile.macroBar.enabled = true
    KCM.db.profile.macroBar.locked = false
    KCM.MacroBar.Update()
    return _G.KCMMacroBar
end

local function lvl(f) return f:GetFrameLevel() end

-- ---------------------------------------------------------------------------
-- The table
-- ---------------------------------------------------------------------------

test("layers: one table names the strata by the standard's tier keys", function(t)
    local KCM = withLayers()
    local L = KCM.Constants and KCM.Constants.LAYERS
    t.truthy(L, "KCM.Constants.LAYERS exists (frame-layering-§5)")
    t.eq(L.STRATA.HUD, "MEDIUM", "the macro bar is a T1 HUD display")
    t.eq(L.STRATA.HUD_POPUP, "DIALOG", "the flyout keeps DIALOG (CON-Z01 not taken)")
end)

test("layers: the in-button ladder is ordered fill < indicator < border < overlay < wash", function(t)
    local KCM = withLayers()
    local V = KCM.Constants.LAYERS.LEVEL
    t.eq(V.PANEL, 0, "the flyout panel sits at the container's own level")
    t.truthy(V.FILL >= 1, "the cooldown swipe is above the icon")
    t.truthy(V.FILL < V.INDICATOR, "the flyout indicator clears the swipe (CON-Z03)")
    t.truthy(V.INDICATOR < V.BORDER, "the border clears the indicator")
    t.truthy(V.BORDER < V.OVERLAY, "text draws over the border")
    t.truthy(1 + V.OVERLAY < V.WASH, "the unlock wash is above every slot's top rung (CON-Z06)")
end)

-- ---------------------------------------------------------------------------
-- The bar, its wash and its handle
-- ---------------------------------------------------------------------------

test("layers: the bar root states MEDIUM and is clamped", function(t)
    local KCM, survey = withLayers()
    local b = bar(KCM)
    local s = survey(b)
    t.eq(s.strata, KCM.Constants.LAYERS.STRATA.HUD, "HUD strata on the root")
    t.eq(s.clamped, true, "clamped to the screen")
    t.eq(s.toplevel, false, "a HUD bar is not toplevel")
end)

test("layers: the unlock wash is a mouse-off child frame over every slot band", function(t)
    local KCM, survey = withLayers()
    local b = bar(KCM)
    local wash = b.moveHint
    t.truthy(wash and wash ~= b, "the wash is its own frame, not a texture on the bar")
    t.eq(wash:GetParent(), b, "parented to the bar")
    t.eq(lvl(wash), lvl(b) + KCM.Constants.LAYERS.LEVEL.WASH, "relative to the bar")
    t.eq(rawget(wash, "__mouse"), false, "takes no mouse, so drag-swap and the slots still work")
    t.eq(survey(wash).strata, "MEDIUM", "inherits the bar's strata")
    t.eq(wash:IsShown(), true, "shown while unlocked")
    KCM.MacroBar.SetLocked(true)
    t.eq(wash:IsShown(), false, "hidden once locked")
end)

test("layers: the drag handle ignores the bar's alpha and keeps its default level", function(t)
    local KCM, survey = withLayers()
    local b = bar(KCM)
    local handle = _G.KCMMacroBarHandle
    t.truthy(handle, "the strip was built")
    t.eq(survey(handle).ignoreParentAlpha, true, "a faded bar does not fade its strip (CON-Z10)")
    t.eq(lvl(handle), lvl(b) + 1, "level untouched: CON-Z08 was not taken")
end)

-- ---------------------------------------------------------------------------
-- A slot and its flyout
-- ---------------------------------------------------------------------------

local function slot(KCM, catKey)
    local b = bar(KCM)
    return KCM.MacroBarButton.Create(b, catKey or "WPN_ENCH", 1), b
end

test("layers: a slot layers cooldown < indicator < border < overlay, each explicit", function(t)
    local KCM = withLayers()
    local btn = slot(KCM)
    local V = KCM.Constants.LAYERS.LEVEL
    local base = lvl(btn)
    t.eq(rawget(btn.cooldown, "__level"), base + V.FILL, "the swipe has an explicit level")
    t.eq(lvl(btn.border), base + V.BORDER, "border")
    t.eq(lvl(btn.overlay), base + V.OVERLAY, "text overlay")
    KCM.MacroBarFlyout.Apply(btn, fcfg{ flyout = true })
    t.eq(lvl(btn.indicator), base + V.INDICATOR, "the indicator no longer ties with the swipe")
end)

test("layers: the flyout is DIALOG and clamped from construction, set once", function(t)
    local KCM, survey = withLayers()
    local btn = slot(KCM)
    local flyout = btn.flyout
    local s = survey(flyout)
    t.eq(s.strata, KCM.Constants.LAYERS.STRATA.HUD_POPUP, "strata set in Create (CON-Z02)")
    t.eq(s.clamped, true, "clamped like the bar (CON-Z07)")
    t.eq(rawget(flyout, "__strataWrites"), 1, "one write at construction")
    KCM.MacroBarFlyout.Apply(btn, fcfg{ flyout = true })
    KCM.MacroBarFlyout.Apply(btn, fcfg{ flyout = true })
    t.eq(rawget(flyout, "__strataWrites"), 1, "no strata write per refresh")
    t.eq(lvl(flyout.bg), lvl(flyout) + KCM.Constants.LAYERS.LEVEL.PANEL,
        "the panel sits at the container's level through the named band (CON-Z09)")
end)

test("layers: a flyout entry uses the slot's ladder (CON-Z04)", function(t)
    local KCM  = withLayers()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    mock.setItem(seed[1], { name = "Pot", subType = "Potions" })
    mock.setBag(seed[1], 1)
    local btn = slot(KCM, "HP_POT")
    KCM.MacroBarFlyout.Apply(btn, fcfg{ flyout = true })
    local e = btn.flyout.entries[1]
    t.truthy(e, "an entry was built")
    local V = KCM.Constants.LAYERS.LEVEL
    local base = lvl(e)
    t.eq(rawget(e.cooldown, "__level"), base + V.FILL, "explicit swipe level")
    t.eq(lvl(e.border), base + V.BORDER, "the border clears the swipe")
    t.eq(lvl(e.overlay), base + V.OVERLAY, "and the count clears the border")
end)

-- ---------------------------------------------------------------------------
-- The static pin: every strata and level write reads the table
-- ---------------------------------------------------------------------------

test("layers: no strata literal and no unnamed level offset in core, modules or settings", function(t)
    local files = {}
    for _, rel in ipairs(h.loader.tocFiles()) do
        if rel:match("^core/") or rel:match("^modules/") or rel:match("^settings/") then
            files[#files + 1] = rel
        end
    end
    t.truthy(#files > 10, "the TOC's own files were read")
    local bad = {}
    for _, rel in ipairs(files) do
        local fh = io.open(ROOT .. "/" .. rel, "r")
        if fh then
            local n = 0
            for line in fh:lines() do
                n = n + 1
                local code = line:gsub("%-%-.*$", "")
                if code:find('SetFrameStrata%(%s*"') then
                    bad[#bad + 1] = rel .. ":" .. n .. " strata literal"
                end
                local arg = code:match("SetFrameLevel%((.*)%)")
                if arg and not arg:find("LEVEL%.") then
                    bad[#bad + 1] = rel .. ":" .. n .. " level without a LAYERS.LEVEL name"
                end
            end
            fh:close()
        end
    end
    t.eq(table.concat(bad, "; "), "", "every write names the table (frame-layering-§5)")
end)
