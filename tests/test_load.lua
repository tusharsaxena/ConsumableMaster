-- test_load.lua — loads the entire addon in TOC order under the mock.
--
-- This is the headless stand-in for an in-game load: it proves every file
-- parses and that the declared load order satisfies each file's load-time
-- dependencies (no module reaching for another's symbols before it loads).
-- It is the regression guard for the modular folder move + namespace migration.

local h = _G.KCM_TEST
local test = h.test

test("full addon loads in TOC order and publishes core handles", function(t)
    local ok, err = pcall(h.loader.loadFullAddon)
    t.truthy(ok, "addon loads in TOC order without error: " .. tostring(err))
    if ok then
        local KCM = _G.KCM
        t.truthy(KCM, "namespace published")
        t.truthy(KCM and KCM.Categories and KCM.Categories.LIST, "categories loaded")
        t.truthy(KCM and KCM.PREFIX, "prefix constant loaded")
        t.truthy(KCM and KCM.Compat and KCM.Compat.GetSpellName, "compat loaded")
        t.truthy(KCM and KCM.Settings and KCM.Settings.Schema, "settings schema loaded")
        t.truthy(KCM and KCM.SlashCommands, "slash commands loaded")
        t.truthy(KCM and KCM.State ~= nil, "session state loaded")
        t.truthy(KCM and KCM.L, "locale table loaded")
    end
end)
