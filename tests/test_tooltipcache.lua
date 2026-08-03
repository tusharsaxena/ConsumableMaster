-- tests/test_tooltipcache.lua — real TooltipCache parser coverage.
--
-- Unlike the classifier/ranker suites (which inject a `tt` table straight
-- through the loader's TooltipCache stub), this suite loads the REAL
-- TooltipCache.lua and feeds it structured C_TooltipInfo lines, so the Lua
-- pattern parsing itself is exercised. Guards the flat "Restores X health and
-- Y mana" combined phrasing used by Midnight food-and-drink items such as
-- Chalcocite Lava Cake (227326), which must populate BOTH healValue and
-- manaValue so it classifies as Food AND Drink.

local h = require("harness")
local test = h.test

-- Load Namespace + the real parser onto a fresh mocked namespace.
local function newTC()
    local KCM  = h.loader.loadFiles({ "Namespace.lua", "TooltipCache.lua" })
    return KCM.TooltipCache, h.loader.mock
end

-- Feed structured tooltip lines for `id`, give it a name (so GetItemInfo
-- resolves and Get() doesn't mark the entry pending), then re-parse.
local function parse(TC, mock, id, lines)
    mock.setItem(id, { subType = "Food & Drink" })
    _G.C_TooltipInfo.GetItemByID = function(qid)
        if qid ~= id then return nil end
        local out = {}
        for i, txt in ipairs(lines) do out[i] = { leftText = txt } end
        return { lines = out }
    end
    TC.Invalidate(id)
    return TC.Get(id)
end

-- ---- Combined flat "health and mana" — the reported bug ------------------
test("TooltipCache: parses combined flat 'health and mana' into both values", function(t)
    local TC, mock = newTC()
    local cake = parse(TC, mock, 227326, {
        "Chalcocite Lava Cake",
        "Use: Restores 35,000 health and 30,000 mana over 20 sec. Must remain seated while eating.",
    })
    t.eq(cake.healValue, 35000, "combined flat: healValue parsed")
    t.eq(cake.manaValue, 30000, "combined flat: manaValue parsed")
end)

-- ---- Regression: plain health-only food ---------------------------------
test("TooltipCache: parses health-only food with no manaValue", function(t)
    local TC, mock = newTC()
    local food = parse(TC, mock, 1001, { "Use: Restores 90,000 health over 20 sec." })
    t.eq(food.healValue, 90000, "health-only: healValue parsed")
    t.falsy(food.manaValue, "health-only: no manaValue")
end)

-- ---- Regression: plain mana-only drink ----------------------------------
test("TooltipCache: parses mana-only drink with no healValue", function(t)
    local TC, mock = newTC()
    local drink = parse(TC, mock, 1002, { "Use: Restores 90,000 mana over 20 sec." })
    t.eq(drink.manaValue, 90000, "mana-only: manaValue parsed")
    t.falsy(drink.healValue, "mana-only: no healValue")
end)

-- ---- Weapon enhancements: oils "Coat", whetstones "Sharpen" --------------
test("TooltipCache: flags weapon enhancements via the 'your <weapon>' effect", function(t)
    local TC, mock = newTC()
    -- Real Thalassian Phoenix Oil (243733): "Coat your weapon with …".
    local oil = parse(TC, mock, 243733, {
        "Thalassian Phoenix Oil",
        "Use: Coat your weapon with Thalassian Phoenix Oil, increasing your Critical Strike and Haste by 13 for 120 min.",
    })
    t.truthy(oil.isWeaponEnhance, "oil: isWeaponEnhance set from 'Coat your weapon'")
    t.truthy(oil.hasStatBuff, "oil: hasStatBuff set from the CRIT/HASTE buff")
    t.eq(oil.buffDurationSec, 7200, "oil: 120 min -> 7200s buff duration")

    -- Whetstone phrasing puts an adjective between "your" and "weapon".
    local stone = parse(TC, mock, 237370, {
        "Refulgent Whetstone",
        "Use: Sharpens your bladed weapon, increasing Attack Power by 10 for 2 hours.",
    })
    t.truthy(stone.isWeaponEnhance, "whetstone: isWeaponEnhance set from 'your bladed weapon'")
    t.eq(stone.buffDurationSec, 7200, "whetstone: 2 hours -> 7200s buff duration")
end)

-- ---- Regression: combined percentage form (already worked) --------------
test("TooltipCache: parses combined percentage 'health and mana' form", function(t)
    local TC, mock = newTC()
    local pct = parse(TC, mock, 1003, { "Use: Restores 5% of your maximum health and mana every second." })
    t.eq(pct.healPct, 5, "combined pct: healPct parsed")
    t.eq(pct.manaPct, 5, "combined pct: manaPct parsed")
end)

-- ---- Attack Power and Spell Power parsing ------------------------------------
test("TooltipCache: parses Attack Power and Spell Power as AP/SP stats", function(t)
    local TC, mock = newTC()
    local stone = parse(TC, mock, 237370, {
        "Refulgent Whetstone",
        "Use: Sharpens your bladed weapon, increasing Attack Power by 10 for 2 hours.",
    })
    t.eq(#stone.statBuffs, 1, "one stat buff parsed")
    t.eq(stone.statBuffs[1].stat, "AP", "Attack Power -> AP")
    t.eq(stone.statBuffs[1].amount, 10, "AP amount")

    local sp = parse(TC, mock, 999001, { "X", "Use: increasing Spell Power by 42 for 1 hour." })
    t.eq(sp.statBuffs[1].stat, "SP", "Spell Power -> SP")
    t.eq(sp.statBuffs[1].amount, 42, "SP amount")
end)

test("TooltipCache: weaponAffinity from bladed/blunt/plain phrasing", function(t)
    local TC, mock = newTC()
    local wh = parse(TC, mock, 237370, { "W", "Use: Sharpens your bladed weapon, increasing Attack Power by 10 for 2 hours." })
    t.eq(wh.weaponAffinity, "bladed", "bladed -> bladed")
    local we = parse(TC, mock, 237369, { "W", "Use: Balances your blunt weapon, increasing Attack Power by 15 for 2 hours." })
    t.eq(we.weaponAffinity, "blunt", "blunt -> blunt")
    local oil = parse(TC, mock, 243733, { "O", "Use: Coat your weapon in oil, increasing your Critical Strike and Haste by 13 for 120 min." })
    t.eq(oil.weaponAffinity, "any", "plain 'your weapon' -> any")
end)

test("TooltipCache: parses 'Primary Stat' as a PRIMARY stat buff", function(t)
    local TC, mock = newTC()
    local rune = parse(TC, mock, 243191, {
        "Ethereal Augment Rune",
        "Use: Increases Primary Stat by 733 for 1 hour.",
        "Augment Rune",
    })
    t.eq(#rune.statBuffs, 1, "one stat buff parsed")
    t.eq(rune.statBuffs[1].stat, "PRIMARY", "Primary Stat -> PRIMARY")
    t.eq(rune.statBuffs[1].amount, 733, "PRIMARY amount")
    t.truthy(rune.hasStatBuff, "hasStatBuff set")
end)

test("TooltipCache: sets isAugmentRune from the category marker line", function(t)
    local TC, mock = newTC()
    local rune = parse(TC, mock, 259085, {
        "Void-Touched Augment Rune",
        "Use: Increases Primary Stat by 900 for 1 hour.",
        "Augment Rune",
    })
    t.truthy(rune.isAugmentRune, "marker line -> isAugmentRune")

    -- Negative: a flask that merely NAMES a stat is not an augment rune.
    local flask = parse(TC, mock, 212283, {
        "Flask of Tempered Aggression",
        "Use: Increases your Strength by 1,000 for 1 hour.",
    })
    t.falsy(flask.isAugmentRune, "no marker line -> not an augment rune")
end)

-- ---- Bug A: real runes carry the marker INLINE on the Use line ------------
-- In-game (dump of 259085) the effect line is:
--   "Use: Increases Strength by 25 for 1 hrs.  Augment Rune."
-- The marker is a suffix of the Use sentence, not a standalone line, so the
-- old exact-line match ^Augment Rune%.?$ never fired -> classified: (none).
test("TooltipCache: isAugmentRune fires on an inline 'Augment Rune' marker", function(t)
    local TC, mock = newTC()
    local rune = parse(TC, mock, 259085, {
        "Void-Touched Augment Rune",
        "Use: Increases Strength by 25 for 1 hrs.  Augment Rune.",
        "\"Can be bought and sold on the auction house.\"",
    })
    t.truthy(rune.isAugmentRune, "inline marker -> isAugmentRune")
    t.eq(rune.statBuffs[1].stat, "STR", "STR parsed from inline line")
    t.eq(rune.statBuffs[1].amount, 25, "STR amount 25")

    -- Negative: an ordinary flask (no 'Augment Rune' text anywhere) is not one.
    local flask = parse(TC, mock, 212283, {
        "Flask of Tempered Aggression",
        "Use: Increases your Strength by 1,000 for 1 hour.",
    })
    t.falsy(flask.isAugmentRune, "no marker text -> not an augment rune")
end)

-- ---- Bug B: a partial (still-loading) consumable tooltip must stay pending -
-- When only the name line has arrived, parseLines finds no effect. Caching
-- that as final would strand the item at amount 0 forever (Ranker sees empty
-- statBuffs), because GET_ITEM_INFO_RECEIVED does not re-fire for items whose
-- basic info was already cached. So Get() must return pending until the body
-- (the "Use:" effect line) arrives.
test("TooltipCache: partial consumable tooltip stays pending until body loads", function(t)
    local TC, mock = newTC()
    mock.setItem(259085, { subType = "Other", classID = 0 })  -- Consumable

    local function feed(lines)
        _G.C_TooltipInfo.GetItemByID = function(qid)
            if qid ~= 259085 then return nil end
            local out = {}
            for i, txt in ipairs(lines) do out[i] = { leftText = txt } end
            return { lines = out }
        end
        TC.Invalidate(259085)
    end

    -- Stage 1: only the name line has arrived -> no effect parsed -> pending.
    feed({ "Void-Touched Augment Rune" })
    local partial = TC.Get(259085)
    t.truthy(partial.pending, "partial consumable tooltip -> pending")

    -- Stage 2: body arrives -> re-parse yields the real stat buff, not pending.
    feed({
        "Void-Touched Augment Rune",
        "Use: Increases Strength by 25 for 1 hrs.  Augment Rune.",
    })
    local full = TC.Get(259085)
    t.falsy(full.pending, "complete tooltip -> not pending")
    t.eq(full.statBuffs[1].amount, 25, "STR amount now parsed")
end)

-- Non-consumables (armor/weapons/etc.) legitimately have no consumable effect,
-- so they must NOT be held pending — that would churn every discovery pass.
test("TooltipCache: effectless NON-consumable is cached, not pending", function(t)
    local TC, mock = newTC()
    mock.setItem(770001, { subType = "Plate", classID = 4 })  -- Armor
    _G.C_TooltipInfo.GetItemByID = function(qid)
        if qid ~= 770001 then return nil end
        return { lines = { { leftText = "Some Plate Boots" }, { leftText = "Item Level 600" } } }
    end
    TC.Invalidate(770001)
    local tt = TC.Get(770001)
    t.falsy(tt.pending, "non-consumable with no effect is final, not pending")
end)

-- ---- Maximum-level caps ---------------------------------------------------
-- Note: these use newTC()/parse() — the pre-existing helpers at the top of
-- this file that load the REAL TooltipCache.lua and install a local
-- C_TooltipInfo.GetItemByID override for the given lines — rather than
-- h.loader.loadPure(), which backs KCM.TooltipCache with the mock-`tt` stub
-- and never loads the real parser (see this file's header note). That keeps
-- these cases exercising the actual pattern match, same as every other case
-- in this suite.
test("TooltipCache: parses a 'cannot be used by players higher than level' cap", function(t)
    local TC, mock = newTC()
    local rez = parse(TC, mock, 2401, {
        "Emergency Soul Link",
        "Use: Convince a dead ally that being alive is much more fun.",
        "Cannot be used by players higher than level 90.",
    })
    t.eq(rez.maxLevel, 90, "the self-restriction cap is parsed")
end)

test("TooltipCache: parses a drums 'above level' affect cap", function(t)
    local TC, mock = newTC()
    local drums = parse(TC, mock, 2402, {
        "Drums of Rage",
        "Use: Increases Haste by 15% for all party and raid members.",
        "Does not affect allies above level 50.",
    })
    t.eq(drums.maxLevel, 50, "the affect cap is parsed")
end)

test("TooltipCache: a floor phrasing without a negation does NOT produce a maxLevel", function(t)
    local TC, mock = newTC()
    -- "above level 50" with no "Cannot"/"Does not" etc. is a FLOOR ("you must
    -- be at least this level"), not a ceiling. Accepting it would silently
    -- make the item permanently unpickable for a high-level character.
    local usable = parse(TC, mock, 2405, {
        "Use: Restores 500 health.",
        "Usable by players above level 50.",
    })
    t.eq(usable.maxLevel, nil, "a floor phrasing without a negation is not treated as a cap")
end)

test("TooltipCache: an uncapped item reports no maxLevel", function(t)
    local TC, mock = newTC()
    local pot = parse(TC, mock, 2403, { "Use: Restores 500 health." })
    t.eq(pot.maxLevel, nil, "no cap line means no cap")
end)

test("TooltipCache.IsUsableByPlayer rejects an over-cap item and accepts at the cap", function(t)
    local TC, mock = newTC()
    parse(TC, mock, 2404, {
        "Drums of Rage",
        "Use: Increases Haste by 15%.",
        "Does not affect allies above level 50.",
    })
    mock.setPlayerLevel(80)
    local ok, why = TC.IsUsableByPlayer(2404)
    t.falsy(ok, "an 80 cannot use a level-50-capped drum")
    t.eq(why, "level 80 > 50", "the reason names both levels")

    mock.setPlayerLevel(50)
    t.truthy(TC.IsUsableByPlayer(2404), "usable at exactly the cap")
end)
