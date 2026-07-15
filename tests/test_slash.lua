-- test_slash.lua — /cm dispatcher + parsers, exercised through the public
-- KCM:OnSlashCommand seam (the parsers themselves are file-local). Loads the
-- full addon so SlashCommands + the settings schema are present.

local h = require("harness")
local test = h.test

local function load()
    local KCM = h.loader.loadFullAddon()
    return KCM, h.loader.mock
end

local function say(KCM, mock, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return table.concat(mock.output, "\n")
end

local function effectiveSet(KCM, catKey)
    local set = {}
    for _, id in ipairs(KCM.Selector.GetEffectivePriority(catKey)) do set[id] = true end
    return set
end

test("/cm set toggles a bool setting through the schema", function(t)
    local KCM, mock = load()
    KCM:OnSlashCommand("set enabled false")
    t.eq(KCM.db.profile.enabled, false, "enabled set to false via schema")
    KCM:OnSlashCommand("set enabled true")
    t.eq(KCM.db.profile.enabled, true, "enabled set to true via schema")
end)

test("/cm priority add then remove edits the FOOD candidate set", function(t)
    local KCM = load()
    KCM:OnSlashCommand("priority food add 987654")
    t.truthy(effectiveSet(KCM, "FOOD")[987654], "added item present")
    KCM:OnSlashCommand("priority food remove 987654")
    t.falsy(effectiveSet(KCM, "FOOD")[987654], "removed/blocked item gone")
end)

test("/cm priority add accepts a spell sentinel (s:ID)", function(t)
    local KCM = load()
    KCM:OnSlashCommand("priority food add s:5512")
    local found = false
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        if KCM.ID.IsSpell(id) and KCM.ID.SpellID(id) == 5512 then found = true end
    end
    t.truthy(found, "spell entry added via s: syntax")
end)

test("/cm stat primary sets the current spec's primary stat", function(t)
    local KCM = load()
    KCM:OnSlashCommand("stat primary INT")
    local _, _, key = KCM.SpecHelper.GetCurrent()   -- "7_263"
    t.eq(KCM.db.profile.statPriority[key].primary, "INT", "primary set for current spec")
end)

test("/cm stat primary resolves a CLASS:SPEC token", function(t)
    local KCM = load()
    KCM:OnSlashCommand("stat primary STR SHAMAN:ENHANCEMENT")   -- 7:263
    t.eq(KCM.db.profile.statPriority["7_263"].primary, "STR", "CLASS:SPEC token resolved")
end)

test("/cm with an unknown command reports it and prints help", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "frobnicate")
    t.truthy(text:find("Unknown command", 1, true), "reports the unknown command")
    t.truthy(text:find("/cm", 1, true), "prints the help listing")
end)

test("/cm dump pick renders a category's effective priority and marks owned picks", function(t)
    local KCM, mock = load()
    -- Own the first item (positive-id) seed FOOD candidate so a pick exists.
    local seedFood
    for _, id in ipairs(KCM.SEED and KCM.SEED.FOOD or {}) do
        if type(id) == "number" and id > 0 then seedFood = id; break end
    end
    t.truthy(seedFood, "FOOD ships at least one item seed")
    mock.setBag(seedFood, 1)
    local text = say(KCM, mock, "dump pick food")
    t.truthy(text:find("effective priority", 1, true), "renders the effective priority list")
    t.truthy(text:find(tostring(seedFood), 1, true), "lists the owned candidate")
    t.truthy(text:find("owned", 1, true), "marks it owned")
end)

test("/cm rewrite is a back-compat alias for rewritemacros", function(t)
    local KCM, mock = load()
    local text = say(KCM, mock, "rewrite")
    t.truthy(text:find("rewrote all macros", 1, true), "alias routes to rewritemacros")
end)
