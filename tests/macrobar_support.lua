-- tests/macrobar_support.lua — the fixtures the macro-bar peel leaves on both
-- sides of a seam.
--
-- tests/test_macrobar.lua was 2229 lines against layout-§1's 1500-line cap, and
-- issue #32 named two cuts: the pure-geometry sections out to
-- tests/test_macrobar_layout.lua and the chrome appliers plus the flyout's
-- bind/apply pass out to tests/test_macrobar_chrome.lua. `fcfg` — the flyout's
-- config table, defaults merged under an override — is read on all three sides:
-- by the geometry cases that left, by the click-gating case that stayed
-- (MacroBarFlyout.Apply; since CM-ATS-02 it lives in
-- tests/test_macrobar_flyout.lua), and by the bind/apply pass that left the
-- other way.
--
-- SHARED, not copied, and the distinction is the point. It is stateless today,
-- so three copies would be correct today; a copy is simply the shape that stops
-- being correct the first time anyone gives it state, and three suites would
-- then disagree about the fixture in silence. The rawget guard makes every
-- dofile after the first hand back the first instance, so there is exactly one
-- table shape in the run no matter which suite loads first.

if rawget(_G, "__KCM_MACROBAR_SUPPORT") then
    return rawget(_G, "__KCM_MACROBAR_SUPPORT")
end

local S = {}

--- The flyout geometry/apply config, with `over` merged over the shipped shape.
function S.fcfg(over)
    local c = { buttonSize = 40, flyoutScale = 100, flyoutSpacing = 2,
                flyoutGap = 4, flyoutPadding = 0, flyoutIndicatorScale = 20,
                flyoutPoint = "TOP" }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

--- The bar frame, its drag handle, and a record of the four things the lock
--- drives.
---
--- The container is a file-local in modules/MacroBar.lua, built lazily by the
--- first MB.Update() — so the only way to reach the frame the user actually
--- sees is to watch CreateFrame across that first build. Hands back that
--- record, the bar and the handle; the handle carries the widget's help mark
--- as `handle.help`, which is the frame the second tooltip hangs off.
---
--- Shared for the same reason `fcfg` is. tests/test_macrobar.lua drives it for
--- the lock's visible consequences and tests/test_macrobar_chrome.lua drives
--- it for the drag handle's two tooltips; a copy is the shape that stops being
--- correct the first time one side is taught something the other is not.
function S.buildBar(KCM)
    local mock = _G.KCM_TEST.loader.mock
    local seen = {}
    local realCreate = _G.CreateFrame
    local frames = {}
    _G.CreateFrame = function(kind, name, parent, template)
        local f = realCreate(kind, name, parent, template)
        if name then frames[name] = f end
        if name == "KCMMacroBar" then
            -- wow_mock's CreateTexture answers from the frame's own metatable and
            -- hands the FRAME back, so `bar.moveHint` would BE `bar` and the gold
            -- unlocked wash could not be told apart from the bar's own
            -- visibility. Hand out a distinct object for this one frame.
            f.CreateTexture = function()
                local tex = mock.makeStub()
                tex.Show = function() seen.hintShown = true end
                tex.Hide = function() seen.hintShown = false end
                return tex
            end
        end
        return f
    end
    KCM.MacroBar.Update()
    _G.CreateFrame = realCreate

    local bar, handle = frames.KCMMacroBar, frames.KCMMacroBarHandle
    bar.EnableMouse = function(_, on) seen.mouseEnabled = on and true or false end
    bar.Show        = function() seen.barVisible = true end
    bar.Hide        = function() seen.barVisible = false end
    handle.SetShown = function(_, on) seen.handleShown = on and true or false end
    return seen, bar, handle
end

_G.__KCM_MACROBAR_SUPPORT = S
return S
