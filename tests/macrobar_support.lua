-- tests/macrobar_support.lua — the one fixture the macro-bar peel leaves on both
-- sides of a seam.
--
-- tests/test_macrobar.lua was 2229 lines against layout-§1's 1500-line cap, and
-- issue #32 named two cuts: the pure-geometry sections out to
-- tests/test_macrobar_layout.lua and the chrome appliers plus the flyout's
-- bind/apply pass out to tests/test_macrobar_chrome.lua. `fcfg` — the flyout's
-- config table, defaults merged under an override — is read on all three sides:
-- by the geometry cases that left, by the click-gating case that stayed
-- (MacroBarFlyout.Apply), and by the bind/apply pass that left the other way.
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

_G.__KCM_MACROBAR_SUPPORT = S
return S
