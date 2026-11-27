-- tests/test_statpriority.lua -- issue #48: the stat priority per client.
--
-- Retail keeps its shape (a primary stat and four ranked secondaries) and its
-- scoring, unchanged; WoW Forever ranks ONE list over every stat its consumables
-- grant, scored position weight x amount. Every case names its client and runs as
-- that client under BOTH kit profiles (h.loader.withClient, clients-§6): the addon
-- reads the client at LOAD (SpecHelper.STATS, the TooltipCache parser, the
-- settings page's shape, the /cm stat verbs), so each case builds its namespace
-- inside the client it names.
--
-- The tooltip fixtures are real WoW Forever tooltips (ConsumableMasterProbeDB,
-- 2026-11-27), item text only.

local h = _G.KCM_TEST
local test = h.test

local function asForever(fn) return function(t) h.loader.withClient("forever", function() fn(t) end) end end
local function asRetail(fn) return function(t) h.loader.withClient("retail", function() fn(t) end) end end

local FOREVER_STATS = {
    "STR", "AGI", "INT", "STA", "SPI", "AP", "SP", "FIRE_SP", "FROST_SP", "SHADOW_SP",
    "HEAL", "HIT", "CRIT", "ARMOR", "HEALTH", "MANA", "MANA_REGEN",
}

-- Forever's nine classes, one spec each (owner, 2026-11-27).
local FOREVER_SPECS = {
    "1_1491", "2_1486", "3_1485", "4_1488", "5_1487", "7_1489", "8_1482", "9_1490", "11_1484",
}

local function item(mock, id, sub, tt, ilvl)
    mock.setItem(id, { classID = 0, subClassID = sub, tt = tt or {}, ilvl = ilvl })
end

local function buff(stat, amount) return { stat = stat, amount = amount } end

local function stats(...)
    return { statBuffs = { ... }, hasStatBuff = true }
end

-- ---------------------------------------------------------------------------
-- The stat model (core/SpecHelper.lua SpecHelper.STATS)
-- ---------------------------------------------------------------------------

test("Forever: the stat model is one ranked list over Forever's stats", asForever(function(t)
    local KCM = h.loader.loadPure()
    local M = KCM.SpecHelper.STATS
    t.eq(M.ranked, true, "the ranked shape")
    t.eqList(M.stats, FOREVER_STATS, "every Forever stat, in the canonical order")
    t.eq(M.primaries, nil, "no primary stat")
end))

test("Retail: the stat model is the primary and the four secondaries, unchanged", asRetail(function(t)
    local KCM = h.loader.loadPure()
    local M = KCM.SpecHelper.STATS
    t.eq(M.ranked, false, "not ranked")
    t.eqList(M.primaries, { "STR", "AGI", "INT" }, "three primaries")
    t.eqList(M.stats, { "CRIT", "HASTE", "MASTERY", "VERSATILITY" }, "four secondaries")
end))

test("Degraded: without the library the stat model is Retail's", function(t)
    local KCM = h.loader.loadPureDegraded()
    t.eq(KCM.SpecHelper.STATS.ranked, false, "a degraded install reads Retail's shape")
end)

-- ---------------------------------------------------------------------------
-- The shipped orders (defaults/Defaults_StatPriority.lua)
-- ---------------------------------------------------------------------------

test("Forever: every class ships a ranked order of real, distinct stats", asForever(function(t)
    local KCM = h.loader.loadPure()
    local valid = {}
    for _, s in ipairs(FOREVER_STATS) do valid[s] = true end
    local n = 0
    for _ in pairs(KCM.SEED.STAT_PRIORITY) do n = n + 1 end
    t.eq(n, #FOREVER_SPECS, "one entry per Forever class, nothing else")
    for _, key in ipairs(FOREVER_SPECS) do
        local row = KCM.SEED.STAT_PRIORITY[key]
        t.truthy(row and row.ranked, key .. " is seeded with a ranked list")
        t.eq(row and row.primary, nil, key .. " names no primary")
        local seen = {}
        for _, stat in ipairs(row and row.ranked or {}) do
            t.truthy(valid[stat], key .. ": '" .. tostring(stat) .. "' is a Forever stat")
            t.falsy(seen[stat], key .. ": '" .. tostring(stat) .. "' is listed once")
            seen[stat] = true
        end
        -- The issue's complaint was a page that started all-excluded.
        t.truthy(#(row and row.ranked or {}) >= 8, key .. " ranks at least eight stats")
        t.eqList(KCM.SpecHelper.GetStatPriority(key).ranked, row.ranked, key .. " resolves to its seed")
    end
end))

test("Forever: each class's order leads with its role's stat", asForever(function(t)
    local KCM = h.loader.loadPure()
    local lead = {
        ["1_1491"] = "STR", ["3_1485"] = "AGI", ["4_1488"] = "AGI", ["8_1482"] = "SP", ["9_1490"] = "SP",
    }
    for key, stat in pairs(lead) do
        t.eq(KCM.SEED.STAT_PRIORITY[key].ranked[1], stat, key .. " leads with " .. stat)
    end
    local function has(list, s) for _, v in ipairs(list) do if v == s then return true end end return false end
    t.falsy(has(KCM.SEED.STAT_PRIORITY["1_1491"].ranked, "INT"), "a warrior does not rank Intellect")
    t.falsy(has(KCM.SEED.STAT_PRIORITY["3_1485"].ranked, "STR"), "a hunter does not rank Strength")
    t.falsy(has(KCM.SEED.STAT_PRIORITY["8_1482"].ranked, "SHADOW_SP"), "a mage does not rank shadow damage")
end))

-- ---------------------------------------------------------------------------
-- Resolution and migration (SpecHelper.GetStatPriority)
-- ---------------------------------------------------------------------------

test("Forever: a ranked override wins and is cleaned on read", asForever(function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.statPriority["3_1485"] = { ranked = { "AP", "MASTERY", "AGI", "AP", "BOGUS" } }
    t.eqList(KCM.SpecHelper.GetStatPriority("3_1485").ranked, { "AP", "AGI" },
        "Retail-only, unknown and repeated stats are dropped, the order kept")
end))

test("Forever: a Retail-shaped override reads as none, takes the seed, and writes nothing",
    asForever(function(t)
        local KCM = h.loader.loadPure()
        local legacy = { primary = "AGI", secondary = { "MASTERY", "VERSATILITY", "HASTE", "CRIT" } }
        KCM.db.profile.statPriority["3_1485"] = legacy
        local p = KCM.SpecHelper.GetStatPriority("3_1485")
        t.eqList(p.ranked, KCM.SEED.STAT_PRIORITY["3_1485"].ranked, "the shipped Forever order")
        t.eq(p.primary, nil, "no primary leaks through")
        t.eq(KCM.db.profile.statPriority["3_1485"], legacy, "the stored entry is untouched on read")
        t.falsy(KCM.SpecHelper.IsOverride(legacy), "and it is not an override on Forever")
        t.eq(KCM.SpecHelper.DescribePriority(p):sub(1, 7), "ranked=", "the one-line form names the list")
    end))

test("Retail: a ranked entry is no override there, and the Retail resolver is unchanged", asRetail(function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.statPriority["7_263"] = { ranked = { "AGI" } }
    local p = KCM.SpecHelper.GetStatPriority("7_263")
    t.eq(p.primary, KCM.SEED.STAT_PRIORITY["7_263"].primary, "the seed, as for any entry without a primary")
    t.eq(p.ranked, nil, "and no ranked list")
    t.eq(KCM.SpecHelper.DescribePriority({ primary = "AGI", secondary = { "CRIT", "HASTE" } }),
        "primary=AGI secondary=CRIT>HASTE", "Retail's one-line form is what the dumps always printed")
end))

test("Forever: the statPriority row keeps ranked entries and drops the Retail shape on a write",
    asForever(function(t)
        local KCM = h.loader.loadFullAddon()
        KCM.db.profile.statPriority = {
            ["8_1482"] = { primary = "INT", secondary = { "CRIT" } },
        }
        KCM.Schema:Set("statPriority", KCM.SpecHelper.WithStatPriority("3_1485",
            { ranked = { "AGI", "HASTE", "AP", "AGI" } }))
        local stored = KCM.db.profile.statPriority
        t.eqList(stored["3_1485"].ranked, { "AGI", "AP" }, "the edited spec, cleaned")
        t.eq(stored["8_1482"], nil, "the inert Retail-shaped entry goes with the first write")
    end))

test("Retail: the statPriority row still drops an entry with no primary", asRetail(function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.Schema:Set("statPriority", { ["7_263"] = { ranked = { "AGI" } },
        ["7_262"] = { primary = "INT", secondary = { "CRIT", "HASTE" } } })
    local stored = KCM.db.profile.statPriority
    t.eq(stored["7_263"], nil, "a ranked entry is not a Retail override")
    t.eqList(stored["7_262"].secondary, { "CRIT", "HASTE" }, "a Retail entry is kept as before")
end))

-- ---------------------------------------------------------------------------
-- Scoring (modules/Ranker.lua)
-- ---------------------------------------------------------------------------

test("Retail: stat weights and stat-category scores are exactly what they were", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local spec = { primary = "AGI", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } }
    t.eq(R._statWeight("AGI", spec), 1000, "primary: the flat floor")
    t.eq(R._statWeight("CRIT", spec), 400, "secondary 1 of 4: 100 x 4")
    t.eq(R._statWeight("VERSATILITY", spec), 100, "secondary 4 of 4: 100 x 1")
    t.eq(R._statWeight("TOP_SECONDARY", spec), 400, "the wildcard weighs like secondary 1")
    t.eq(R._statWeight("AP", spec), 1000, "attack power stands in for an agility primary")
    t.eq(R._statWeight("SP", spec), 0, "spell power does not")
    t.eq(R._statWeight("STA", spec), 0, "a Forever-only stat weighs nothing on Retail")
    item(mock, 9501, 5, stats(buff("CRIT", 50), buff("AGI", 10)), 600)
    mock.setItem(9502, { classID = 0, subClassID = 3, tt = stats(buff("MASTERY", 935)), ilvl = 600, quality = 3 })
    local ctx = { specPriority = spec }
    -- 50 x 400 + 10 x 1000 + ilvl 600 + quality 1 x 100
    t.eq(R.Score("STAT_FOOD", 9501, ctx), 20000 + 10000 + 600 + 100, "STAT_FOOD: the sum, no tier term")
    -- 935 x 200 + 600 + 3 x 100
    t.eq(R.Score("FLASK", 9502, ctx), 187000 + 600 + 300, "FLASK: the sum, no tier term")
    t.eq(R.Explain("FLASK", 9502, ctx).summary,
        "Primary-stat buffs outweigh any secondary; secondary ranks by priority position.", "the same summary")
    t.eq(R.Explain("FLASK", 9502, ctx).signals[1].note, "amount 935 x weight 200", "the same note")
end))

test("Forever: a ranked stat weighs RANK_BASE^(N - k), and an unranked one nothing", asForever(function(t)
    local KCM = h.loader.loadPure()
    local R = KCM.Ranker
    local spec = { ranked = { "AGI", "AP", "STA" } }
    t.eq(R._statWeight("AGI", spec), R.RANK_BASE ^ 2, "first of three")
    t.eq(R._statWeight("AP", spec), R.RANK_BASE, "second of three")
    t.eq(R._statWeight("STA", spec), 1, "last")
    t.eq(R._statWeight("INT", spec), 0, "excluded")
    t.eq(R._statWeight("AP", { ranked = {} }), 0, "an empty list weighs nothing, and is not a primary alias")
end))

test("Forever: one place up outweighs any amount; within a stat the bigger amount wins", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = { ranked = { "AGI", "ARMOR", "HEALTH" } } }
    item(mock, 9511, 2, stats(buff("AGI", 4)), 5)          -- Elixir of Minor Agility
    item(mock, 9512, 2, stats(buff("ARMOR", 250)), 39)     -- Elixir of Defense
    item(mock, 9513, 2, stats(buff("HEALTH", 120)), 30)    -- Elixir of Lesser Fortitude
    item(mock, 9514, 2, stats(buff("AGI", 25)), 48)        -- Elixir of Greater Agility
    item(mock, 9515, 2, { effectValue = 1 }, 60)           -- Elixir of Minor Force (no stat)
    t.eqList(R.SortCandidates("ELIXIR", { 9515, 9513, 9512, 9511, 9514 }, ctx),
        { 9514, 9511, 9512, 9513, 9515 }, "Agility by amount, then armor, then health, then the rest")
end))

test("Forever: Stat Food, Flask and Combat Potion rank a ranked stat above item level", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = { ranked = { "AP", "AGI", "STA" } } }
    item(mock, 9521, 5, stats(buff("STA", 1)), 10)                       -- Herb Baked Egg
    item(mock, 9522, 5, { isWellFed = true, healValue = 530 }, 55)        -- a Fishing Skill food
    item(mock, 9523, 5, stats(buff("AP", 6)), 15)                         -- Slitherskin Mackerel
    item(mock, 9524, 5, stats(buff("AGI", 10)), 45)                       -- Tasty Lion Steak
    t.eqList(R.SortCandidates("STAT_FOOD", { 9522, 9521, 9524, 9523 }, ctx), { 9523, 9524, 9521, 9522 },
        "attack power, agility, then the lowest-ranked stamina, and only then the unweighed higher-ilvl food")
    item(mock, 9525, 3, stats(buff("HEALTH", 1200)), 60)                  -- Flask of the Titans
    item(mock, 9526, 3, stats(buff("AP", 2)), 1)
    t.eqList(R.SortCandidates("FLASK", { 9525, 9526 }, ctx), { 9526, 9525 }, "a ranked stat beats an unranked one")
    item(mock, 9527, 1, stats(buff("AP", 12)), 25)                        -- Minor Frenzy Potion
    item(mock, 9528, 1, stats(buff("AP", 40)), 50)                        -- Greater Frenzy Potion
    t.eqList(R.SortCandidates("CMBT_POT", { 9527, 9528 }, ctx), { 9528, 9527 }, "the bigger amount")
    for _, pair in ipairs({ { "STAT_FOOD", 9521 }, { "STAT_FOOD", 9522 }, { "FLASK", 9526 }, { "CMBT_POT", 9528 } }) do
        local ex = R.Explain(pair[1], pair[2], ctx)
        t.eq(ex.score, R.Score(pair[1], pair[2], ctx), pair[1] .. " " .. pair[2] .. ": the explanation adds up")
    end
end))

test("Forever: a penalty subtracts, and the explanation still adds up", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    item(mock, 9531, 5, stats(buff("INT", 4), buff("STA", -5)), 18)   -- Raptor Punch
    local intFirst = { specPriority = { ranked = { "INT", "STA" } } }
    local staFirst = { specPriority = { ranked = { "STA", "INT" } } }
    t.truthy(R.Score("STAT_FOOD", 9531, intFirst) > R.Score("STAT_FOOD", 9531, staFirst),
        "the drink is worth more to a player who ranks Intellect over Stamina")
    for _, ctx in ipairs({ intFirst, staFirst }) do
        local ex = R.Explain("STAT_FOOD", 9531, ctx)
        t.eq(ex.score, R.Score("STAT_FOOD", 9531, ctx), "the explanation adds up")
    end
    local ex = R.Explain("STAT_FOOD", 9531, intFirst)
    t.eq(ex.signals[2].note, "amount -5 x weight 1", "the penalty is a signal, printed with %g")
end))

-- A ranked score at the top of a long list is ~1e4^16 x amount: far past SPELL_SCORE (1e9), and
-- far past where a double can still add an ilvl to it. Order must not depend on either.
test("Forever: a spell still outranks every item under a long ranked list", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = { ranked = FOREVER_STATS } }
    item(mock, 9551, 5, stats(buff("STR", 30)), 60)
    item(mock, 9552, 3, stats(buff("STR", 75)), 60)
    t.truthy(R.Score("STAT_FOOD", 9551, ctx) > 1e9, "the item's ranked score is past the spell sentinel")
    t.eqList(R.SortCandidates("STAT_FOOD", { 9551, -433 }, ctx), { -433, 9551 }, "the spell first, all the same")
    t.eqList(R.SortCandidates("FLASK", { 9552, -433, 9551 }, ctx), { -433, 9552, 9551 },
        "the spell first, then the items by their stat")
end))

test("Forever: item level and quality still break a tie a long ranked list rounds away", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = { ranked = FOREVER_STATS } }
    -- The same buff, the higher-ilvl food on the higher id, so an id tie-break would invert them.
    mock.setItem(9561, { classID = 0, subClassID = 5, tt = stats(buff("STR", 6)), ilvl = 20, quality = 1 })
    mock.setItem(9562, { classID = 0, subClassID = 5, tt = stats(buff("STR", 6)), ilvl = 45, quality = 1 })
    t.eq(R.Score("STAT_FOOD", 9561, ctx), R.Score("STAT_FOOD", 9562, ctx), "the two scores round to one")
    t.eqList(R.SortCandidates("STAT_FOOD", { 9561, 9562 }, ctx), { 9562, 9561 }, "the higher item level first")
    mock.setItem(9563, { classID = 0, subClassID = 2, tt = stats(buff("AGI", 8)), ilvl = 30, quality = 1 })
    mock.setItem(9564, { classID = 0, subClassID = 2, tt = stats(buff("AGI", 8)), ilvl = 30, quality = 2 })
    t.eqList(R.SortCandidates("ELIXIR", { 9563, 9564 }, ctx), { 9564, 9563 }, "the better quality first")
end))

-- WPN_ENCH is outside #48's ruling (Stat Food, Elixir, Scroll, Flask): on Forever it keeps
-- ranking by the stone's or oil's own value. The vanilla parser now reads an oil's "spell damage
-- and healing" as SP and HEAL, and a ranked weight on them would put a wizard oil over every
-- sharpening stone for any class that ranks SP at all -- a Paladin's or a Shaman's seed does.
test("Forever: Weapon Enhancement still ranks by the stone's or oil's value", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = KCM.SpecHelper.GetStatPriority("2_1486") }   -- Paladin ranks SP and HEAL
    local oil = stats(buff("SP", 8), buff("HEAL", 8))
    oil.weaponEnhanceValue = 8                                                -- Minor Wizard Oil
    item(mock, 9581, 8, oil, 5)
    item(mock, 9582, 8, { weaponEnhanceValue = 12 }, 45)                       -- a sharpening stone
    t.eqList(R.SortCandidates("WPN_ENCH", { 9581, 9582 }, ctx), { 9582, 9581 }, "the stronger stone first")
    t.eq(R.Score("WPN_ENCH", 9581, ctx), 8 * 1e3 + 5 + 100, "the oil's value, ilvl and quality, no stat weight")
    local ex = R.Explain("WPN_ENCH", 9581, ctx)
    t.eq(ex.score, R.Score("WPN_ENCH", 9581, ctx), "the explanation adds up")
end))

test("Retail: a score tie still goes to the lower id, whatever the item level", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = { primary = "AGI", secondary = { "CRIT" } } }
    -- 10 x 1000 + ilvl 200 + quality 3 x 100 = 10,500 = 10 x 1000 + ilvl 400 + quality 1 x 100.
    mock.setItem(9571, { classID = 0, subClassID = 5, tt = stats(buff("AGI", 10)), ilvl = 200, quality = 3 })
    mock.setItem(9572, { classID = 0, subClassID = 5, tt = stats(buff("AGI", 10)), ilvl = 400, quality = 1 })
    t.eq(R.Score("STAT_FOOD", 9571, ctx), R.Score("STAT_FOOD", 9572, ctx), "a true tie")
    t.eqList(R.SortCandidates("STAT_FOOD", { 9572, 9571 }, ctx), { 9571, 9572 }, "the lower id, as before #48")
end))

test("Forever: Stat Food ranks by the shipped order once a spec resolves", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local R = KCM.Ranker
    local ctx = { specPriority = KCM.SpecHelper.GetStatPriority("4_1488") }   -- Rogue: AGI, AP, ...
    item(mock, 9541, 5, stats(buff("STR", 10)), 55)
    item(mock, 9542, 5, stats(buff("AGI", 3)), 20)
    item(mock, 9543, 5, stats(buff("INT", 10)), 60)
    t.eqList(R.SortCandidates("STAT_FOOD", { 9543, 9541, 9542 }, ctx), { 9542, 9541, 9543 },
        "Agility first, Strength next, and Intellect -- excluded for a rogue -- last, whatever its ilvl")
end))

-- ---------------------------------------------------------------------------
-- The parser (core/TooltipCache.lua)
-- ---------------------------------------------------------------------------

local function newTC()
    local KCM = h.loader.loadFiles({ "Namespace.lua", "Compat.lua", "TooltipCache.lua" })
    return KCM.TooltipCache, h.loader.mock
end

local nextId = 9600
local function parse(TC, mock, lines)
    nextId = nextId + 1
    local id = nextId
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

local function buffsOf(e)
    local out = {}
    for _, sb in ipairs(e.statBuffs or {}) do out[#out + 1] = sb.stat .. "=" .. tostring(sb.amount) end
    table.sort(out)
    return table.concat(out, " ")
end

-- Real Forever tooltips (the Use: line, verbatim) and the buffs they must read.
local FOREVER_FIXTURES = {
    { "Use: Increases Strength by 4 for 1 |4hour:hrs;.", "STR=4" },
    { "Use: Increases the target's Stamina by 4 for 30 min. (1 |4Sec:Sec; Cooldown)", "STA=4" },
    { "Use: Increases the target's Spirit by 3 for 30 min. (1 |4Sec:Sec; Cooldown)", "SPI=3" },
    { "Use: Drink to increase your Spirit by 10. Lasts for 30 min.", "SPI=10" },
    { "Use: Increases spell damage by up to 20 for 30 min.", "SP=20" },
    { "Use: Increases spell fire damage by up to 10 for 30 min.", "FIRE_SP=10" },
    { "Use: Imbue a staff with magic for 1 hour, increasing damage done by Frost spells and effects by up to 8.",
        "FROST_SP=8" },
    { "Use: Drink to increase healing done by spells and effects by up to 20. Lasts 30 min.", "HEAL=20" },
    { "Use: Increases Spell Healing by 13 for 30 sec. (2 |4Min:Min; Cooldown)", "HEAL=13" },
    { "Use: Increases armor by 150 for 1 |4hour:hrs;.", "ARMOR=150" },
    { "Use: Increases the target's Armor by 120 for 30 min. (1 |4Sec:Sec; Cooldown)", "ARMOR=120" },
    { "Use: Increases armor by 1,000 for 1.5 min.", "ARMOR=1000" },
    { "Use: Increases the player's maximum health by 27 for 1 |4hour:hrs;.", "HEALTH=27" },
    { "Use: Drink to regenerate 3 mana every 5 sec. Lasts for 30 min.", "MANA_REGEN=3" },
    { "Use: Increases Attack Power by 12 for 30 sec. (2 |4Min:Min; Cooldown)", "AP=12" },
    { "Use: Restores 234 health over 21 sec.  Must remain seated while eating. If you spend at least 10 sec "
        .. "eating, you will become well fed and gain 6 Attack Power for 15 min. Additionally, experience gained "
        .. "from kills is increased by 5%. (1 |4Sec:Sec; Cooldown)", "AP=6" },
    { "Use: Restores 1,338 health over 30 sec.  Must remain seated while eating. If you spend at least 10 sec "
        .. "eating, you will become well fed and gain 22 Spell Damage for 15 min.", "SP=22" },
    { "Use: Restores 530 health over 24 sec.  Must remain seated while eating.  If you spend at least 10 seconds "
        .. "eating you will become well fed and gain 6 Stamina and Spirit for 15 min. (1 |4Sec:Sec; Cooldown)",
        "SPI=6 STA=6" },
    { "Use: Increases your Intellect by 4 and decreases your Stamina by 5 for 5 min.", "INT=4 STA=-5" },
    { "Use: While applied to target weapon it increases spell damage and healing by up to 8. Lasts for 30 "
        .. "minutes. (1 |4Sec:Sec; Cooldown)", "HEAL=8 SP=8" },
    { "Use: Imbue a staff with magic for 1 hour, increasing your chance to hit with spells by 0.5%.", "HIT=0.5" },
    { "Use: Increases Agility by 25 and chance to get a critical strike by 2% for 1 hr.", "AGI=25 CRIT=2" },
    { "Use: Summons an enchanted lute that allows you and others sitting nearby to gain 71 Armor and 2 "
        .. "increase to all stats, mutually exclusive with Mark of the Wild.", "ARMOR=71" },
    { "Use: Increases the player's maximum mana by 2000 for 2 hrs.", "MANA=2000" },
    { "Use: Increases damage done by magical spells and effects by up to 150 for 2 hrs.", "SP=150" },
}

test("TooltipCache (Forever): vanilla wording reads every Forever stat", asForever(function(t)
    local TC, mock = newTC()
    for _, fx in ipairs(FOREVER_FIXTURES) do
        local e = parse(TC, mock, { "Some Consumable", fx[1] })
        t.eq(buffsOf(e), fx[2], fx[1]:sub(1, 60))
    end
end))

test("TooltipCache (Forever): a protection potion's school and a fishing buff are no stat", asForever(function(t)
    local TC, mock = newTC()
    t.eq(buffsOf(parse(TC, mock, { "Use: Absorbs 1950 to 3250 fire damage. Lasts 1 hr." })), "",
        "an absorb names no spell, so it is no fire spell damage")
    local fish = parse(TC, mock, { "Use: Restores 530 health over 24 sec. If you spend at least 10 sec eating, "
        .. "you will become well fed and gain 8 Fishing Skill for 15 min." })
    t.falsy(fish.hasStatBuff, "Fishing Skill is no stat")
    t.truthy(fish.isWellFed, "and the food is still Well Fed")
    t.eq(buffsOf(parse(TC, mock, { "Use: Restores 151 mana over 18 sec.  Must remain seated while drinking." })),
        "", "a drink's restore is no mana regen")
end))

test("TooltipCache (Forever): holy, nature and arcane spell damage are no SP; fire, frost, shadow keep their tag",
    asForever(function(t)
    local TC, mock = newTC()
    local expect = {
        ["Use: Increases spell Holy damage by up to 30 for 30 min."]              = "",
        ["Use: Drink to increase nature spell damage by up to 55."]              = "",
        ["Use: Increases spell arcane damage by up to 20 for 30 min."]           = "",
        ["Use: Increases spell fire damage by up to 10 for 30 min."]             = "FIRE_SP=10",
        ["Use: Increases spell frost damage by up to 15 for 30 min."]            = "FROST_SP=15",
        ["Use: Drink to increase shadow spell damage by up to 40."]              = "SHADOW_SP=40",
    }
    for line, want in pairs(expect) do
        t.eq(buffsOf(parse(TC, mock, { "Some Consumable", line })), want, line:sub(1, 60))
    end
end))

test("TooltipCache (Retail): Forever's wording reads exactly as it did before #48", asRetail(function(t)
    local TC, mock = newTC()
    local expect = {
        ["Use: Increases Strength by 4 for 1 |4hour:hrs;."] = "STR=4",
        ["Use: Increases the target's Stamina by 4 for 30 min. (1 |4Sec:Sec; Cooldown)"] = "",
        ["Use: Increases armor by 150 for 1 |4hour:hrs;."] = "",
        ["Use: Increases spell fire damage by up to 10 for 30 min."] = "",
        ["Use: Increases Attack Power by 12 for 30 sec. (2 |4Min:Min; Cooldown)"] = "AP=12",
    }
    for line, want in pairs(expect) do
        t.eq(buffsOf(parse(TC, mock, { "Some Consumable", line })), want, line:sub(1, 60))
    end
    local e = parse(TC, mock, { "Use: Grants 935 of your highest secondary stat for 30 sec." })
    t.eq(buffsOf(e), "TOP_SECONDARY=935", "Retail's wildcard is still read")
end))

-- ---------------------------------------------------------------------------
-- The settings page (settings/StatPriority.lua) and /cm stat
-- ---------------------------------------------------------------------------

local function openPage(KCM, specKey)
    local UI = KCM.Settings.Helpers.instance
    KCM.Options._viewedSpec     = specKey
    KCM.Options._viewedSpecAuto = false
    KCM.Settings.builders.statpriority({})
    local ctx = UI.__panelFor("statpriority")
    ctx.panel.IsShown = function() return true end
    KCM.Settings.Helpers.RefreshAllPanels()
    return ctx
end

test("Forever: the page draws one row per Forever stat, the shipped order first", asForever(function(t)
    local KCM = h.loader.loadFullAddon()
    local ctx = openPage(KCM, "4_1488")
    local rows = ctx.kcmStatRows
    t.eq(rows and #rows, #FOREVER_STATS, "every Forever stat is a row")
    local seed = KCM.SEED.STAT_PRIORITY["4_1488"].ranked
    for i, stat in ipairs(seed) do
        t.eq(rows[i].kcmStat, stat, "row " .. i .. " is the shipped order's " .. stat)
        t.truthy(rows[i].kcmIncluded, stat .. " is included")
    end
    t.falsy(rows[#seed + 1].kcmIncluded, "the rest are the excluded tail")
    for _, row in ipairs(rows) do
        t.truthy(row.kcmStat ~= "MASTERY" and row.kcmStat ~= "HASTE", "no Retail-only stat is offered")
    end
end))

-- Every Dropdown label the page sets while it renders.
local function dropdownLabels(KCM, specKey)
    local labels = {}
    local AceGUI = _G.LibStub("AceGUI-3.0")
    local realCreate = AceGUI.Create
    AceGUI.Create = function(self, kind, ...)
        local w = realCreate(self, kind, ...)
        if kind == "Dropdown" and w and w.SetLabel then
            local set = w.SetLabel
            w.SetLabel = function(me, text) labels[#labels + 1] = text; return set(me, text) end
        end
        return w
    end
    local ok, err = pcall(openPage, KCM, specKey)
    AceGUI.Create = realCreate
    if not ok then error(err, 0) end
    local set = {}
    for _, label in ipairs(labels) do set[label] = true end
    return set
end

test("Forever: the page draws no primary-stat dropdown", asForever(function(t)
    local KCM = h.loader.loadFullAddon()
    t.falsy(dropdownLabels(KCM, "4_1488")["Primary stat"], "no dropdown is the primary stat")
end))

test("Retail: the page still draws its primary-stat dropdown", asRetail(function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(dropdownLabels(KCM, "7_263")["Primary stat"], "the primary stat dropdown, as before")
end))

test("Forever: unticking and re-ticking a stat writes the ranked list", asForever(function(t)
    local KCM = h.loader.loadFullAddon()
    local ctx = openPage(KCM, "4_1488")
    ctx.kcmStatRows[1].kcmGlyph:_run("OnClick")   -- AGI out
    local seed = KCM.SEED.STAT_PRIORITY["4_1488"].ranked
    local want = {}
    for i = 2, #seed do want[#want + 1] = seed[i] end
    t.eqList(KCM.db.profile.statPriority["4_1488"].ranked, want, "Agility leaves the ranking")
    t.eq(KCM.db.profile.statPriority["4_1488"].primary, nil, "and no primary is written")
    local agi
    for _, row in ipairs(ctx.kcmStatRows) do if row.kcmStat == "AGI" then agi = row end end
    agi.kcmGlyph:_run("OnClick")
    want[#want + 1] = "AGI"
    t.eqList(KCM.db.profile.statPriority["4_1488"].ranked, want, "and comes back at the end")
end))

test("Forever: the split runs over Forever's stats", asForever(function(t)
    local KCM = h.loader.loadFullAddon()
    local included, excluded = KCM.Options.SplitSecondaries({ "AP", "MASTERY", "STA", "AP" })
    t.eqList(included, { "AP", "STA" }, "stored order, Retail-only and repeated stats dropped")
    t.eq(#excluded, #FOREVER_STATS - 2, "every other Forever stat is offered")
    t.eq(excluded[1], "STR", "in the canonical order")
end))

local function say(KCM, mock, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return table.concat(mock.output, "\n")
end

test("Forever: /cm stat order writes the ranked list; primary and secondary are absent", asForever(function(t)
    local KCM, mock = h.loader.loadFullAddon(), h.loader.mock
    say(KCM, mock, "stat order agi,ap,hit,ap 4_1488")
    t.eqList(KCM.db.profile.statPriority["4_1488"].ranked, { "AGI", "AP", "HIT" }, "upper-cased, deduplicated")
    local out = say(KCM, mock, "stat order agi,mastery 4_1488")
    t.truthy(out:find("MASTERY", 1, true), "a Retail-only stat is refused by name")
    t.eqList(KCM.db.profile.statPriority["4_1488"].ranked, { "AGI", "AP", "HIT" }, "and nothing is written")
    t.truthy(say(KCM, mock, "stat list 4_1488"):find("ranked:    AGI, AP, HIT", 1, true), "list prints the order")
    local help = say(KCM, mock, "stat")
    t.truthy(help:find("order", 1, true), "the help names order")
    t.falsy(help:find("stat primary", 1, true), "and not primary")
    t.falsy(help:find("stat secondary", 1, true), "nor secondary")
    t.truthy(say(KCM, mock, "stat primary AGI 4_1488"):find("unknown stat subcommand", 1, true),
        "primary is no verb on Forever")
end))

test("Retail: /cm stat has no order verb", asRetail(function(t)
    local KCM, mock = h.loader.loadFullAddon(), h.loader.mock
    t.falsy(say(KCM, mock, "stat"):find("stat order", 1, true), "the help does not name order")
    t.truthy(say(KCM, mock, "stat order CRIT"):find("unknown stat subcommand", 1, true), "order is no verb on Retail")
end))
