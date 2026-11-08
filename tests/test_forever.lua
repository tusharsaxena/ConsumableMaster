-- tests/test_forever.lua -- the WoW Forever port, step 1 (docs/superpowers/specs/
-- 2026-11-08-forever-port-design.md): which categories exist on which client, the
-- empty-by-decision Forever seeds, the four Forever-only categories and Forever's
-- three new consumable subclasses.
--
-- Every case names its client and runs as that client under BOTH kit profiles
-- (h.loader.withClient), so the retail profile proves Forever's shape and the
-- forever profile proves Retail's (clients-§6). The addon reads the client at
-- LOAD -- the category gate in defaults/Categories.lua, the seed selection in
-- defaults/Defaults_*.lua, the subclass lists in core/Classifier.lua -- so each
-- case builds its namespace inside the client it names.

local h = _G.KCM_TEST
local test = h.test

local function asForever(fn) return function(t) h.loader.withClient("forever", function() fn(t) end) end end
local function asRetail(fn) return function(t) h.loader.withClient("retail", function() fn(t) end) end end

local RETAIL_KEYS = {
    "FOOD", "DRINK", "HP_POT", "MP_POT", "HS", "VANTUS", "FLASK", "CMBT_POT", "STAT_FOOD",
    "WPN_ENCH", "AUG_RUNE", "BLOODLUST", "BATTLE_REZ", "HP_AIO", "MP_AIO",
}
local FOREVER_KEYS = {
    "FOOD", "DRINK", "HP_POT", "MP_POT", "HS", "BANDAGE", "FLASK", "ELIXIR", "CMBT_POT",
    "PROT_POT", "STAT_FOOD", "SCROLL", "WPN_ENCH", "HP_AIO", "MP_AIO",
}
local RETAIL_ONLY  = { "VANTUS", "AUG_RUNE", "BLOODLUST", "BATTLE_REZ" }
local FOREVER_ONLY = { "ELIXIR", "BANDAGE", "SCROLL", "PROT_POT" }

local function listKeys(KCM)
    local out = {}
    for i, row in ipairs(KCM.Categories.LIST) do out[i] = row.key end
    return out
end

local function contains(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end

-- ---------------------------------------------------------------------------
-- The category gate (clients-§4)
-- ---------------------------------------------------------------------------

test("Forever: the category list is exactly its fifteen keys", asForever(function(t)
    local KCM = h.loader.loadPure()
    t.eqList(listKeys(KCM), FOREVER_KEYS, "Forever's fifteen, in LIST order")
    for _, key in ipairs(RETAIL_ONLY) do
        t.eq(KCM.Categories.Get(key), nil, key .. " is not registered on Forever")
    end
end))

test("Forever: an empty macro's icon is the note Forever ships, never Retail's cooking pot", asForever(function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.EMPTY_ICON, 134328, "inv_misc_note_02: the Forever client has no file 7704166")
    if KCM.MacroDisplay then t.eq(KCM.MacroDisplay.FALLBACK_ICON, 134328, "the bar's fallback follows") end
end))

test("Retail: an empty macro's icon stays the cooking pot", asRetail(function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.EMPTY_ICON, 7704166, "the cooking pot, unchanged by the port")
    if KCM.MacroDisplay then t.eq(KCM.MacroDisplay.FALLBACK_ICON, 7704166, "the bar's fallback follows") end
end))

test("Retail: the category list is exactly its fifteen keys", asRetail(function(t)
    local KCM = h.loader.loadPure()
    t.eqList(listKeys(KCM), RETAIL_KEYS, "Retail's fifteen, unchanged by the port")
    for _, key in ipairs(FOREVER_ONLY) do
        t.eq(KCM.Categories.Get(key), nil, key .. " is not registered on Retail")
    end
end))

test("Degraded: without the library the categories and seeds are Retail's", function(t)
    -- Compat's stub answers as Retail (core/Compat.lua): the addon shipped Retail-only, so that
    -- is the build a degraded install was already running, on either kit profile.
    local KCM = h.loader.loadPureDegraded()
    t.eqList(listKeys(KCM), RETAIL_KEYS, "Retail's fifteen")
    t.eq(KCM.SEED_CLIENT, "retail", "the seed selection reads Retail's lists")
    t.truthy(#KCM.SEED.FOOD > 0, "and they are Retail's, not empty")
end)

test("Forever: every row declares only known client tokens, and ALL keeps all nineteen", asForever(function(t)
    local KCM = h.loader.loadPure()
    t.eq(#KCM.Categories.ALL, 19, "fifteen Retail rows plus Forever's four")
    for _, row in ipairs(KCM.Categories.ALL) do
        for _, token in ipairs(row.clients or {}) do
            t.truthy(token == "retail" or token == "forever", row.key .. " names a known client")
        end
    end
end))

test("Forever: a Retail-only category has no bucket, slot, tab, schema row, verb or macro",
    asForever(function(t)
        local KCM, mock = h.loader.loadFullAddon(), h.loader.mock
        local d = KCM.dbDefaults.profile
        for _, key in ipairs(RETAIL_ONLY) do
            t.eq(d.categories[key], nil, key .. ": no profile bucket")
            t.eq(KCM.db.profile.categories[key], nil, key .. ": none on a fresh profile")
            t.falsy(contains(d.macroBar.order, key), key .. ": no macro-bar slot")
            t.falsy(contains(KCM.MacroBarModel.Order(), key), key .. ": none in the bar's order")
            t.falsy(contains(KCM.Settings.macroOrder, key:lower()), key .. ": no settings tab")
            for _, tab in ipairs(KCM.Options.MacroTabs()) do
                t.truthy(tab.key ~= key, key .. ": not on the Macros strip")
            end
            mock.output = {}
            KCM:OnSlashCommand("priority " .. key:lower() .. " list")
            local out = table.concat(mock.output, "\n")
            t.truthy(out:find("unknown category", 1, true), key .. ": the verb does not know it")
            t.falsy(out:find("known cats:[^\n]*" .. key:lower()), key .. ": nor lists it")
        end
        t.eq(KCM.Settings.Helpers.FindSchema("categories.BATTLE_REZ.mouseover"), nil,
            "Battle Rez's mouseover row is not registered")
        t.eq(d.macroBar.perRow, 15, "one row of Forever's fifteen")
        KCM.Pipeline.Recompute("test")
        for _, key in ipairs(RETAIL_ONLY) do
            t.eq(mock.macros["KCM_" .. key], nil, key .. ": no macro written")
        end
        for _, key in ipairs(FOREVER_ONLY) do
            t.truthy(mock.macros["KCM_" .. key], key .. ": its macro is written")
        end
    end))

test("Retail: a Forever-only category has no bucket, slot, tab, schema row, verb or macro",
    asRetail(function(t)
        local KCM, mock = h.loader.loadFullAddon(), h.loader.mock
        local d = KCM.dbDefaults.profile
        for _, key in ipairs(FOREVER_ONLY) do
            t.eq(d.categories[key], nil, key .. ": no profile bucket")
            t.falsy(contains(d.macroBar.order, key), key .. ": no macro-bar slot")
            t.falsy(contains(KCM.Settings.macroOrder, key:lower()), key .. ": no settings tab")
            mock.output = {}
            KCM:OnSlashCommand("priority " .. key:lower() .. " list")
            t.truthy(table.concat(mock.output, "\n"):find("unknown category", 1, true),
                key .. ": the verb does not know it")
        end
        t.truthy(KCM.Settings.Helpers.FindSchema("categories.BATTLE_REZ.mouseover"),
            "Battle Rez's mouseover row is registered on Retail")
        KCM.Pipeline.Recompute("test")
        for _, key in ipairs(FOREVER_ONLY) do
            t.eq(mock.macros["KCM_" .. key], nil, key .. ": no macro written")
        end
    end))

test("Forever: the four new categories have buckets, slots and tabs beside their kin", asForever(function(t)
    local KCM = h.loader.loadFullAddon()
    local d = KCM.dbDefaults.profile
    t.eqList(d.macroBar.order, {
        "FOOD", "DRINK", "HP_POT", "MP_POT", "HS", "BANDAGE", "HP_AIO", "MP_AIO",
        "FLASK", "ELIXIR", "CMBT_POT", "PROT_POT", "STAT_FOOD", "SCROLL", "WPN_ENCH",
    }, "the slot order")
    t.truthy(d.categories.ELIXIR.bySpec and d.categories.SCROLL.bySpec, "elixir and scroll are per spec")
    t.truthy(d.categories.BANDAGE.added and d.categories.PROT_POT.added, "bandage and protection potion are not")
    local tabs = {}
    for i, tab in ipairs(KCM.Options.MacroTabs()) do tabs[i] = tab.key end
    t.eqList(tabs, d.macroBar.order, "the Macros strip runs in the slot order")
    for _, key in ipairs(FOREVER_ONLY) do
        local row = KCM.Categories.Get(key)
        t.eq(row.macroName, "KCM_" .. key, key .. "'s macro name")
        t.truthy(#row.macroName <= 16, key .. "'s macro name fits")
        t.truthy(row.emptyText:find("[CM]", 1, true), key .. " has an empty-state body")
    end
end))

-- ---------------------------------------------------------------------------
-- The seed lists (clients-§5)
-- ---------------------------------------------------------------------------

test("Forever: every seed list is empty by decision", asForever(function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.SEED_CLIENT, "forever", "Forever's lists are the ones chosen")
    local n = 0
    for name, list in pairs(KCM.SEED) do
        n = n + 1
        t.eq(next(list), nil, name .. " is empty on Forever")
    end
    -- Thirteen item lists, the stat priorities and the class gate. The four Forever-only
    -- categories ship no seed file: the Selector reads a missing list as empty.
    t.eq(n, 15, "every seed table is declared, the stat priorities and class gate included")
end))

test("Forever: no Retail item ID is a candidate, so every candidate comes from the bags", asForever(function(t)
    local KCM = h.loader.loadPure()
    local retail
    h.loader.withClient("retail", function() retail = h.loader.loadPure().SEED end)
    local retailIds = {}
    for name, list in pairs(retail) do
        if name ~= "STAT_PRIORITY" and name ~= "CLASS_GATE" then
            for _, id in ipairs(list) do retailIds[id] = true end
        end
    end
    t.truthy(next(retailIds), "the Retail seeds are not empty")
    for _, row in ipairs(KCM.Categories.LIST) do
        if not row.composite then
            for _, id in ipairs(KCM.Selector.BuildCandidateSet(row.key) or {}) do
                t.falsy(retailIds[id], row.key .. ": " .. tostring(id) .. " is a Retail seed")
            end
        end
    end
end))

test("Forever: with no stat-priority seed a spec ranks by its class's primary stat", asForever(function(t)
    local KCM = h.loader.loadPure()
    local p = KCM.SpecHelper.GetStatPriority("4_259")
    t.eq(p.primary, "AGI", "a rogue's primary stat is Agility")
    t.eqList(p.secondary, {}, "and there is no secondary order")
end))

-- ---------------------------------------------------------------------------
-- Classification on Forever's subclasses
-- ---------------------------------------------------------------------------

local function item(mock, id, sub, tt)
    mock.setItem(id, { classID = 0, subClassID = sub, tt = tt or {} })
end

test("Forever: elixirs, scrolls and bandages classify by their subclass", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 9001, 2, { statBuffs = { { stat = "AGI", amount = 25 } }, hasStatBuff = true })
    item(mock, 9002, 4, { effectValue = 60 })
    item(mock, 9003, 7, { healValue = 1104, healOverSec = 8 })
    t.eqList(C.MatchAny(9001), { "ELIXIR" }, "subclass 2 is an elixir")
    t.eqList(C.MatchAny(9002), { "SCROLL" }, "subclass 4 is a scroll")
    t.eqList(C.MatchAny(9003), { "BANDAGE" }, "subclass 7 is a bandage")
    -- Subclass alone, as FLASK: a tooltip still loading does not hold the item back.
    mock.setItem(9004, { classID = 0, subClassID = 2, pending = true })
    t.truthy(C.Match("ELIXIR", 9004), "an elixir classifies before its tooltip arrives")
end))

test("Forever: a draught is matched like a potion", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 9011, 13, { healValueAvg = 520 })
    item(mock, 9012, 13, { manaValueAvg = 800 })
    item(mock, 9013, 13, { buffDurationSec = 20, statBuffs = { { stat = "STR", amount = 60 } }, hasStatBuff = true })
    item(mock, 9014, 13, { absorbValue = 2600, absorbSchool = "fire", buffDurationSec = 3600 })
    t.eqList(C.MatchAny(9011), { "HP_POT" }, "a healing draught")
    t.eqList(C.MatchAny(9012), { "MP_POT" }, "a mana draught")
    t.eqList(C.MatchAny(9013), { "CMBT_POT" }, "a combat draught")
    t.eqList(C.MatchAny(9014), { "PROT_POT" }, "a protection draught")
end))

test("Forever: a protection potion is PROT_POT and never a combat potion", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 9021, 1, { absorbValue = 2600, absorbSchool = "fire", buffDurationSec = 3600 })
    item(mock, 9022, 1, { absorbValue = 900, absorbSchool = "shadow", buffDurationSec = 30 })
    t.eqList(C.MatchAny(9021), { "PROT_POT" }, "an hour-long fire protection potion")
    t.eqList(C.MatchAny(9022), { "PROT_POT" }, "a short one is still not a combat potion")
    item(mock, 9023, 1, { buffDurationSec = 15 })
    t.eqList(C.MatchAny(9023), { "CMBT_POT" }, "a short potion with no absorb stays a combat potion")
end))

test("Forever: a temporary item enhancement is a weapon enchant; a permanent one (6) is not", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 9031, 15, { buffDurationSec = 1800, weaponWordAffinity = "bladed" })
    item(mock, 9032, 6, { buffDurationSec = 1800 })
    item(mock, 9033, 14, { buffDurationSec = 30 })
    t.eqList(C.MatchAny(9031), { "WPN_ENCH" }, "subclass 15, vanilla wording")
    t.eqList(C.MatchAny(9032), {}, "subclass 6 is Forever's Permanent (the Light Armor Kit, 2304), never a weapon enchant")
    t.eqList(C.MatchAny(9033), {}, "a device (14) joins nothing")
end))

test("Retail: Forever's subclasses classify exactly as before the port", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 9041, 13, { healValueAvg = 520 })
    item(mock, 9042, 15, { buffDurationSec = 1800 })
    item(mock, 9043, 6, { buffDurationSec = 1800 })
    item(mock, 9044, 2, { hasStatBuff = true, statBuffs = { { stat = "AGI", amount = 25 } } })
    item(mock, 9045, 1, { absorbValue = 2600, absorbSchool = "fire", buffDurationSec = 3600 })
    t.eqList(C.MatchAny(9041), {}, "subclass 13 is no potion on Retail")
    t.eqList(C.MatchAny(9042), {}, "subclass 15 is no weapon enchant on Retail")
    t.eqList(C.MatchAny(9043), {}, "nor is subclass 6 without the tooltip flag")
    t.eqList(C.MatchAny(9044), {}, "an elixir has no category on Retail")
    t.eqList(C.MatchAny(9045), {}, "an hour-long absorb potion is nothing on Retail, as before")
end))

-- ---------------------------------------------------------------------------
-- Vanilla tooltip wording (the real parser)
-- ---------------------------------------------------------------------------

local function newTC()
    local KCM = h.loader.loadFiles({ "Namespace.lua", "Compat.lua", "TooltipCache.lua" })
    return KCM.TooltipCache, h.loader.mock
end

local function parse(TC, mock, id, lines)
    mock.setItem(id, { subType = "Consumable" })
    _G.C_TooltipInfo.GetItemByID = function(qid)
        if qid ~= id then return nil end
        local out = {}
        for i, txt in ipairs(lines) do out[i] = { leftText = txt } end
        return { lines = out }
    end
    TC.Invalidate(id)
    return TC.Get(id)
end

test("TooltipCache: vanilla stat wording gives the stat, the hour and the value", function(t)
    local TC, mock = newTC()
    local e = parse(TC, mock, 9101, { "Elixir of the Mongoose", "Use: Increases Agility by 25 for 1 hr." })
    t.eq(e.statBuffs[1] and e.statBuffs[1].stat, "AGI", "Agility")
    t.eq(e.statBuffs[1] and e.statBuffs[1].amount, 25, "by 25")
    t.eq(e.buffDurationSec, 3600, "for an hour")
    t.eq(e.effectValue, 25, "and its value")
end)

-- The owner's Forever dump of 2026-11-08, verbatim (build 70862).
test("TooltipCache: Forever's well-fed food reads the stat amount, not the buff's minutes (CM-F9)", function(t)
    local TC, mock = newTC()
    local e = parse(TC, mock, 4592, { "Longjaw Mud Snapper",
        "Use: Restores 530 health over 24 sec.  Must remain seated while eating. If you spend at least 10 sec eating, "
        .. "you will become well fed and gain 10 Attack Power for 15 min. Additionally, experience gained from kills "
        .. "is increased by 5%. (1 |4Sec:Sec; Cooldown)", "Requires Level 5" })
    t.eq(e.statBuffs[1] and e.statBuffs[1].stat, "AP", "Attack Power")
    t.eq(e.statBuffs[1] and e.statBuffs[1].amount, 10, "10, not the 15 of 'for 15 min'")
    t.eq(e.buffDurationSec, 900, "the 15 minutes are the duration")
    t.eq(e.healValue, 530, "and the heal")
end)

-- The owner's report of 2026-11-08: Forever's Bristle Whisker Catfish is Well Fed, with a buff no
-- stat token reads, and must be Stat Food (CM-F12).
local CATFISH = { "Bristle Whisker Catfish",
    "Use: Restores 530 health over 24 sec.  Must remain seated while eating. If you spend at least 10 sec eating, "
    .. "you will become well fed and gain 8 Fishing Skill for 15 min. Additionally, experience gained from kills "
    .. "is increased by 5%. (1 |4Sec:Sec; Cooldown)", "Requires Level 15" }

test("TooltipCache: a Well Fed line is flagged whatever its buff", function(t)
    local TC, mock = newTC()
    local e = parse(TC, mock, 4593, CATFISH)
    t.truthy(e.isWellFed, "become well fed")
    t.falsy(e.hasStatBuff, "Fishing Skill is no stat token")
    t.eq(e.healValue, 530, "the heal still reads")
end)

test("Forever: a Well Fed food with no stat token is Stat Food, not Food", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 4593, 5, { healValue = 530, isWellFed = true, buffDurationSec = 900 })
    item(mock, 9301, 5, { healValue = 243 })
    item(mock, 9302, 5, { manaValue = 400, isWellFed = true })
    t.eqList(C.MatchAny(4593), { "STAT_FOOD" }, "the catfish")
    t.eqList(C.MatchAny(9301), { "FOOD" }, "a plain food stays Food")
    t.eqList(C.MatchAny(9302), { "STAT_FOOD" }, "a Well Fed drink is Stat Food too")
end))

test("Retail: a Well Fed flag with no stat token classifies as before", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 9303, 5, { healValue = 530, isWellFed = true, buffDurationSec = 900 })
    t.eqList(C.MatchAny(9303), { "FOOD" }, "Retail reads the stat tokens alone")
end))

test("TooltipCache: Retail's forward stat wording still reads its amount", function(t)
    local TC, mock = newTC()
    local e = parse(TC, mock, 9110, { "Some Flask", "Use: Increases your Mastery by 935 for 1 hour." })
    t.eq(e.statBuffs[1] and e.statBuffs[1].amount, 935, "the forward form, untouched")
end)

test("TooltipCache: a no-stat scroll or elixir keeps its value", function(t)
    local TC, mock = newTC()
    local s = parse(TC, mock, 9102, { "Scroll of Protection IV", "Use: Increases armor by 240 for 30 min." })
    t.falsy(s.hasStatBuff, "armor is not a stat token")
    t.eq(s.effectValue, 240, "the armor value")
    local e = parse(TC, mock, 9103, { "Arcane Elixir", "Use: Increases spell damage by up to 20 for 30 min." })
    t.eq(e.effectValue, 20, "'by up to N'")
end)

test("TooltipCache: a bandage's heal over time is a flat heal", function(t)
    local TC, mock = newTC()
    local b = parse(TC, mock, 9104, { "Heavy Runecloth Bandage", "Use: Heals 2000 damage over 8 sec." })
    t.eq(b.healValue, 2000, "the heal")
    t.eq(b.healOverSec, 8, "over 8 seconds")
    t.falsy(b.pending, "and the tooltip is final, not held pending")
end)

test("TooltipCache: a protection potion's absorb names its school", function(t)
    local TC, mock = newTC()
    local p = parse(TC, mock, 9105, { "Greater Fire Protection Potion",
        "Use: Absorbs 1950 to 3250 fire damage. Lasts 1 hr." })
    t.eq(p.absorbValue, 2600, "the range's average")
    t.eq(p.absorbSchool, "fire", "the school")
    t.eq(p.buffDurationSec, 3600, "for an hour")
    local f = parse(TC, mock, 9106, { "Use: Absorbs 675 shadow damage." })
    t.eq(f.absorbValue, 675, "a flat absorb")
    t.eq(f.absorbSchool, "shadow", "and its school")
    local n = parse(TC, mock, 9107, { "Use: Absorbs 500 damage. Lasts 30 sec." })
    t.eq(n.absorbSchool, nil, "no school, no protection potion")
end)

test("TooltipCache: vanilla weapon wording gives the affinity and leaves Retail's flags alone", function(t)
    local TC, mock = newTC()
    local sharp = parse(TC, mock, 9108, { "Dense Sharpening Stone",
        "Use: Increase sharp weapon damage by 8 for 30 minutes." })
    t.eq(sharp.weaponWordAffinity, "bladed", "sharp reads bladed")
    t.eq(sharp.isWeaponEnhance, nil, "the Retail flag is not set by vanilla wording")
    t.eq(sharp.weaponAffinity, nil, "nor the Retail affinity")
    local blunt = parse(TC, mock, 9109, { "Dense Weightstone",
        "Use: Increase the damage of a blunt weapon by 8 for 30 minutes." })
    t.eq(blunt.weaponWordAffinity, "blunt", "blunt reads blunt")
    local oil = parse(TC, mock, 9110, { "Brilliant Wizard Oil",
        "Use: While applied to target weapon it increases spell damage by up to 36 for 30 minutes." })
    t.eq(oil.weaponWordAffinity, nil, "an oil names no affinity, so it fits either hand")
    local retail = parse(TC, mock, 9111, { "Use: Sharpens your bladed weapon, increasing Critical Strike by 50 for 1 hour." })
    t.eq(retail.weaponAffinity, "bladed", "Retail's wording reads as before")
    t.eq(retail.weaponWordAffinity, nil, "and takes no vanilla affinity")
end)

-- ---------------------------------------------------------------------------
-- Ranking the new categories
-- ---------------------------------------------------------------------------

local AGI_SPEC = { primary = "AGI", secondary = {} }

test("Forever: elixirs and scrolls rank a weighed stat first, the rest by their value", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = AGI_SPEC }
    item(mock, 9201, 2, { statBuffs = { { stat = "AGI", amount = 25 } }, hasStatBuff = true, effectValue = 25 })
    item(mock, 9202, 2, { statBuffs = { { stat = "STR", amount = 25 } }, hasStatBuff = true, effectValue = 25 })
    item(mock, 9203, 2, { effectValue = 120 })
    local order = R.SortCandidates("ELIXIR", { 9202, 9203, 9201 }, ctx)
    t.eqList(order, { 9201, 9203, 9202 }, "Agility for an Agility spec, then the bigger value")
    item(mock, 9204, 4, { statBuffs = { { stat = "AGI", amount = 5 } }, hasStatBuff = true, effectValue = 5 })
    item(mock, 9205, 4, { effectValue = 240 })
    item(mock, 9206, 4, { effectValue = 60 })
    t.eqList(R.SortCandidates("SCROLL", { 9206, 9205, 9204 }, ctx), { 9204, 9205, 9206 },
        "a stat scroll, then the no-stat scrolls by value")
    local ex = R.Explain("SCROLL", 9205, ctx)
    t.eq(ex.score, R.Score("SCROLL", 9205, ctx), "the explanation adds up to the score")
end))

test("Forever: bandages rank by the heal and protection potions by the absorb", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    item(mock, 9211, 7, { healValue = 2000, healOverSec = 8 })
    item(mock, 9212, 7, { healValue = 640, healOverSec = 8 })
    t.eqList(R.SortCandidates("BANDAGE", { 9212, 9211 }, {}), { 9211, 9212 }, "the bigger heal first")
    item(mock, 9213, 1, { absorbValue = 2600, absorbSchool = "fire" })
    item(mock, 9214, 1, { absorbValue = 1300, absorbSchool = "frost" })
    t.eqList(R.SortCandidates("PROT_POT", { 9214, 9213 }, {}), { 9213, 9214 }, "the bigger absorb first")
    for _, pair in ipairs({ { "BANDAGE", 9211 }, { "PROT_POT", 9213 } }) do
        local ex = R.Explain(pair[1], pair[2], {})
        t.eq(ex.score, R.Score(pair[1], pair[2], {}), pair[1] .. ": the explanation adds up")
    end
end))

test("Forever: a vanilla stone goes to the hand its wording names", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    item(mock, 9221, 15, { buffDurationSec = 1800, weaponWordAffinity = "blunt" })
    mock.setBag(9221, 1)
    KCM.Pipeline.RunAutoDiscovery("test")
    mock.setItem(9222, { subType = "One-Handed Maces" })
    mock.setItem(9223, { subType = "One-Handed Swords" })
    mock.setEquipped(16, 9222)
    mock.setEquipped(17, 9223)
    t.eq(KCM.Selector.PickBestForSlot("WPN_ENCH", 16), 9221, "the mace takes the weightstone")
    t.eq(KCM.Selector.PickBestForSlot("WPN_ENCH", 17), nil, "the sword does not")
end))

-- ---------------------------------------------------------------------------
-- Forever's stones, weightstones and oils: subclass 8, worded (the owner's dump, build 70862)
-- ---------------------------------------------------------------------------

-- Verbatim Use: lines. Each row: id, name, line, expected value (nil for a proc oil).
local STONES = {
    { 2862, "Rough Sharpening Stone",  "Use: Increase sharp weapon damage by 2 for 30 minutes.", 2 },
    { 2863, "Coarse Sharpening Stone", "Use: Increase sharp weapon damage by 3 for 30 minutes.", 3 },
    { 2871, "Heavy Sharpening Stone",  "Use: Increase sharp weapon damage by 4 for 30 minutes.", 4 },
    { 7964, "Solid Sharpening Stone",  "Use: Increase sharp weapon damage by 6 for 30 minutes.", 6 },
}
local WEIGHTSTONES = {
    { 3239, "Rough Weightstone",  "Use: Increase the damage of a blunt weapon by 2 for 30 minutes.", 2 },
    { 3240, "Coarse Weightstone", "Use: Increase the damage of a blunt weapon by 3 for 30 minutes.", 3 },
    { 3241, "Heavy Weightstone",  "Use: Increase the damage of a blunt weapon by 4 for 30 minutes.", 4 },
    { 7965, "Solid Weightstone",  "Use: Increase the damage of a blunt weapon by 6 for 30 minutes.", 6 },
}
local OILS = {
    { 20744, "Minor Wizard Oil", "Use: While applied to target weapon it increases spell damage and healing by up "
        .. "to 8. Lasts for 30 minutes.", 8 },
    { 20745, "Minor Mana Oil", "Use: While applied to target weapon it restores 5 mana to the caster every 5 "
        .. "seconds and increases healing done by up to 10. Lasts for 30 minutes.", 10 },
    { 3824, "Shadow Oil", "Use: When applied to a melee weapon it gives a 15% chance of casting Shadowbolt III at "
        .. "the opponent when it hits.  Lasts 30 minutes.", nil },
    { 3829, "Frost Oil", "Use: When applied to a melee weapon it gives a 10% chance of casting Frostbolt at the "
        .. "opponent when it hits.  Lasts 30 minutes.", nil },
}
local POISONS = {
    { 6947, "Instant Poison" }, { 2892, "Deadly Poison" }, { 3775, "Crippling Poison" },
    { 5237, "Mind-numbing Poison" },
}
local POISON_LINES = { "Use: Coats a weapon with poison that lasts for 30 minutes.",
    "Each strike has a 20% chance of poisoning the enemy." }
local CHAIN_LINE = "Use: Attaches a chain to your weapon, making it impossible to disarm."

-- The real parser's entry for each row, read before the client's namespace is built.
local function parsedRows(rows, extra)
    local TC, mock = newTC()
    local out = {}
    for i, row in ipairs(rows) do
        local lines = { row[2] }
        if row[3] then lines[#lines + 1] = row[3] end
        for _, l in ipairs(extra or {}) do lines[#lines + 1] = l end
        out[i] = { id = row[1], name = row[2], value = row[4], tt = parse(TC, mock, row[1], lines) }
    end
    return out
end

test("TooltipCache: Forever's stone, weightstone and oil wording sets the Forever flag and its value", function(t)
    for _, set in ipairs({ { STONES, "bladed" }, { WEIGHTSTONES, "blunt" }, { OILS, nil } }) do
        for _, r in ipairs(parsedRows(set[1])) do
            t.eq(r.tt.isVanillaWeaponEnhance, true, r.name .. ": the Forever flag")
            t.eq(r.tt.weaponEnhanceValue, r.value, r.name .. ": its value")
            t.eq(r.tt.weaponWordAffinity, set[2], r.name .. ": its hand")
            t.eq(r.tt.isWeaponEnhance, nil, r.name .. ": Retail's flag is not set")
            t.eq(r.tt.weaponAffinity, nil, r.name .. ": nor Retail's affinity")
            t.falsy(r.tt.pending, r.name .. ": and the tooltip is final")
        end
    end
end)

test("TooltipCache: a poison is never read as a weapon enhancement", function(t)
    for _, r in ipairs(parsedRows(POISONS, POISON_LINES)) do
        t.eq(r.tt.isVanillaWeaponEnhance, nil, r.name .. ": no Forever flag")
        t.eq(r.tt.isWeaponEnhance, nil, r.name .. ": no Retail flag")
        t.eq(r.tt.weaponEnhanceValue, nil, r.name .. ": no value")
    end
end)

test("TooltipCache: Retail's weapon wording sets no Forever flag", function(t)
    local TC, mock = newTC()
    local e = parse(TC, mock, 9301, { "Use: Sharpens your bladed weapon, increasing Critical Strike by 50 for 1 hour." })
    t.eq(e.isWeaponEnhance, true, "Retail's flag")
    t.eq(e.isVanillaWeaponEnhance, nil, "and no Forever flag")
    t.eq(e.weaponEnhanceValue, nil, "nor its value")
end)

test("Forever: subclass-8 stones and oils are weapon enchants; poisons and a weapon chain (6) are not",
    asForever(function(t)
        local rows = parsedRows(STONES)
        for _, r in ipairs(parsedRows(WEIGHTSTONES)) do rows[#rows + 1] = r end
        for _, r in ipairs(parsedRows(OILS)) do rows[#rows + 1] = r end
        local poisons = parsedRows(POISONS, POISON_LINES)
        local chain = parsedRows({ { 6041, "Steel Weapon Chain", CHAIN_LINE } })[1]
        t.eq(chain.tt.isWeaponEnhance, true, "the chain's tooltip does carry Retail's flag")
        local KCM, mock = h.loader.loadPure(), h.loader.mock
        local C = KCM.Classifier
        for _, r in ipairs(rows) do
            item(mock, r.id, 8, r.tt)
            t.eqList(C.MatchAny(r.id), { "WPN_ENCH" }, r.name .. " (subclass 8)")
        end
        for _, r in ipairs(poisons) do
            item(mock, r.id, 8, r.tt)
            t.eqList(C.MatchAny(r.id), {}, r.name .. " is held out (rogue-only)")
        end
        item(mock, 6041, 6, chain.tt)
        t.eqList(C.MatchAny(6041), {}, "Steel Weapon Chain: subclass 6 is Permanent, never WPN_ENCH")
        item(mock, 6042, 6, { isVanillaWeaponEnhance = true, weaponEnhanceValue = 4 })
        t.falsy(C.Match("WPN_ENCH", 6042), "nor with the Forever flag")
    end))

test("Retail: Forever's stone wording is no weapon enchant and the weapon chain still is", asRetail(function(t)
    local stone = parsedRows({ STONES[1] })[1]
    local chain = parsedRows({ { 6041, "Steel Weapon Chain", CHAIN_LINE } })[1]
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local C = KCM.Classifier
    item(mock, 2862, 8, stone.tt)
    t.eqList(C.MatchAny(2862), {}, "the Forever flag is not read on Retail")
    item(mock, 6041, 6, chain.tt)
    t.eqList(C.MatchAny(6041), { "WPN_ENCH" }, "Retail's tooltip flag decides, as before the port")
end))

-- A stone's "by N" outranks ilvl and quality: the weaker stone is given the higher ilvl.
local function rankSeries(t, R, mock, rows, label)
    local ids, scores = {}, {}
    for i, r in ipairs(rows) do
        item(mock, r.id, 8, r.tt)
        mock.items[r.id].ilvl = 60 - 10 * i
        ids[#ids + 1] = r.id
    end
    local order = R.SortCandidates("WPN_ENCH", ids, {})
    local want = {}
    for i = #ids, 1, -1 do want[#want + 1] = ids[i] end
    t.eqList(order, want, label .. ": the bigger value first, whatever the ilvl")
    for _, r in ipairs(rows) do
        scores[r.id] = R.Score("WPN_ENCH", r.id, {})
        t.eq(R.Explain("WPN_ENCH", r.id, {}).score, scores[r.id], label .. " " .. r.id .. ": the explanation adds up")
    end
    return scores
end

test("Forever: stones and weightstones rank by their 'by N', oils by their 'up to N'", asForever(function(t)
    local stones, weights = parsedRows(STONES), parsedRows(WEIGHTSTONES)
    local oils = parsedRows({ OILS[1], OILS[2] })
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local s = rankSeries(t, R, mock, stones, "sharpening stones")
    rankSeries(t, R, mock, weights, "weightstones")
    rankSeries(t, R, mock, oils, "oils")
    -- 2 x 1000 + ilvl 50 + quality 1 x 100, and so on down the series.
    t.eq(s[2862], 2150, "Rough Sharpening Stone")
    t.eq(s[2863], 3140, "Coarse Sharpening Stone")
    t.eq(s[2871], 4130, "Heavy Sharpening Stone")
    t.eq(s[7964], 6120, "Solid Sharpening Stone")
end))

test("Retail: a WPN_ENCH score and its explanation are unchanged without the Forever value", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    mock.setItem(9311, { subType = "Other", ilvl = 40, quality = 2,
        tt = { isWeaponEnhance = true, weaponAffinity = "bladed" } })
    t.eq(R.Score("WPN_ENCH", 9311, {}), 240, "ilvl + quality, as before")
    local ex = R.Explain("WPN_ENCH", 9311, {})
    t.eq(ex.summary, "Primary-stat buffs outweigh any secondary; secondary ranks by priority position.",
        "the stat-buff summary")
    for _, sig in ipairs(ex.signals) do t.truthy(sig.label ~= "enhance value", "no enhance-value signal") end
end))

-- ---------------------------------------------------------------------------
-- A profile written on the other client
-- ---------------------------------------------------------------------------

test("Forever: a Retail profile's Vantus data loads, is not read, and survives a return to Retail",
    function(t)
        local stored = {
            categories = { VANTUS = { added = { 245880 }, blocked = {}, pins = {}, discovered = { [245880] = 1 } } },
            macroBar = { order = { "VANTUS", "FOOD" } },
        }
        h.loader.withClient("forever", function()
            local KCM = h.loader.loadFullAddon()
            KCM.db.profiles.Retail = stored
            local ok, err = pcall(function()
                KCM.db:SetProfile("Retail")
                KCM.Pipeline.Recompute("test")
                KCM.Selector.SweepStaleDiscovered(4e9)
                KCM.MacroBarModel.Order()
            end)
            t.truthy(ok, "loading it on Forever raises nothing: " .. tostring(err))
            t.eq(KCM.db.profile.categories.VANTUS.added[1], 245880, "the Vantus data is kept as it was")
            t.eq(KCM.db.profile.categories.VANTUS.discovered[245880], 1, "the sweep leaves it alone")
            t.falsy(contains(KCM.MacroBarModel.Order(), "VANTUS"), "and the bar does not read it")
            KCM.db:SetProfile("Default")
        end)
        h.loader.withClient("retail", function()
            local KCM = h.loader.loadFullAddon()
            KCM.db.profiles.Retail = stored
            KCM.db:SetProfile("Retail")
            t.eq(KCM.db.profile.categories.VANTUS.added[1], 245880, "back on Retail the rune is still added")
            t.eq(KCM.MacroBarModel.Order()[1], "VANTUS", "and the bar's order is the player's")
        end)
    end)
