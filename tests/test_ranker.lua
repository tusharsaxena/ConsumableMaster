-- tests/test_ranker.lua — unit suite for Ranker.lua scoring + sorting.

local h = require("harness")
local test = h.test

local SPELL_SCORE     = 1e9
local CONJURED_BONUS  = 1e6
local IMMEDIATE_BONUS = 1e8

test("Ranker: spell sentinel scores SPELL_SCORE for any category", function(t)
    local KCM = h.loader.loadPure()
    local R   = KCM.Ranker
    local spell = KCM.ID.AsSpell(1231411)
    t.eq(R.Score("FOOD",   spell, nil, nil), SPELL_SCORE, "spell sentinel -> SPELL_SCORE (FOOD)")
    t.eq(R.Score("HP_POT", spell, nil, nil), SPELL_SCORE, "spell sentinel -> SPELL_SCORE (HP_POT)")
    t.eq(R.Score("FLASK",  spell, nil, nil), SPELL_SCORE, "spell sentinel -> SPELL_SCORE (FLASK)")
end)

test("Ranker: nil/unknown guards score 0", function(t)
    local KCM = h.loader.loadPure()
    local R   = KCM.Ranker
    t.eq(R.Score(nil, 1, nil, nil), 0, "nil catKey -> 0")
    t.eq(R.Score("FOOD", nil, nil, nil), 0, "nil itemID -> 0")
    t.eq(R.Score("NOPE", 1, nil, nil), 0, "unknown category -> 0")
end)

test("Ranker: FOOD conjured bonus beats higher flat-value non-conjured", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    -- Non-conjured with high flat heal vs conjured with tiny flat heal:
    -- conjured (1e6) must win despite a much larger raw value.
    mock.setItem(2001, { subType = "Food & Drink", quality = 4, ilvl = 50,
        tt = { healValue = 50000 } })                                  -- big non-conjured
    mock.setItem(2002, { subType = "Food & Drink", quality = 1, ilvl = 1,
        tt = { healValue = 100, isConjured = true } })                 -- tiny conjured

    local sBig  = R.Score("FOOD", 2001, nil, nil)
    local sConj = R.Score("FOOD", 2002, nil, nil)
    -- 50000 + 50 + 4*100 = 50450 ; 100 + 1e6 + 1 + 100 = 1000201
    t.eq(sBig, 50000 + 50 + 400, "FOOD flat-value additive score")
    t.eq(sConj, 100 + CONJURED_BONUS + 1 + 100, "FOOD conjured additive score")
    t.truthy(sConj > sBig, "conjured food beats higher flat-value non-conjured")
end)

test("Ranker: FOOD healPct dominates and healValue+healValueAvg are additive", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    -- healPct dominates flat tiers (pct * 1e4)
    mock.setItem(2003, { subType = "Food & Drink", quality = 1, ilvl = 1,
        tt = { healPct = 60 } })
    t.eq(R.Score("FOOD", 2003, nil, nil), 60 * 1e4 + 1 + 100, "FOOD pct weighting")

    -- healValue + healValueAvg both contribute
    mock.setItem(2004, { subType = "Food & Drink", quality = 1, ilvl = 1,
        tt = { healValue = 200, healValueAvg = 300 } })
    t.eq(R.Score("FOOD", 2004, nil, nil), 200 + 300 + 1 + 100, "FOOD healValue + healValueAvg")
end)

test("Ranker: DRINK conjured bonus beats higher flat-value non-conjured", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    -- DRINK mirror: conjured drink beats high flat-mana non-conjured
    mock.setItem(2101, { subType = "Food & Drink", quality = 3, ilvl = 20,
        tt = { manaValue = 40000 } })
    mock.setItem(2102, { subType = "Food & Drink", quality = 1, ilvl = 1,
        tt = { manaValue = 50, isConjured = true } })
    local dBig  = R.Score("DRINK", 2101, nil, nil)
    local dConj = R.Score("DRINK", 2102, nil, nil)
    t.eq(dBig, 40000 + 20 + 300, "DRINK flat additive score")
    t.eq(dConj, 50 + CONJURED_BONUS + 1 + 100, "DRINK conjured additive score")
    t.truthy(dConj > dBig, "conjured drink beats higher flat-value non-conjured")
end)

test("Ranker: immediate HP pot outranks similar-amount HOT pot", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    -- Immediate pot vs a heal-over-time pot of similar amount. HOT is gated:
    -- it only earns the immediate bonus if its amount exceeds the best
    -- immediate by > 20%. Similar amount => HOT loses.
    mock.setItem(3001, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { healValue = 10000 } })                                  -- immediate
    mock.setItem(3002, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { healValue = 10000, healOverSec = 5 } })                 -- HOT, similar amount

    local hpIds = R.SortCandidates("HP_POT", { 3001, 3002 }, nil, nil)
    t.eqList(hpIds, { 3001, 3002 }, "immediate HP pot outranks similar-amount HOT pot")

    -- Verify the bonus is actually the differentiator via explicit ctx.
    local hpCtx = R.BuildContext("HP_POT", { 3001, 3002 }, nil, nil)
    t.eq(hpCtx.bestImmediateAmount, 10000, "bestImmediateAmount from immediate pot")
    local sImm = R.Score("HP_POT", 3001, hpCtx, nil)
    local sHot = R.Score("HP_POT", 3002, hpCtx, nil)
    t.eq(sImm, 10000 + IMMEDIATE_BONUS + 10 + 200, "immediate pot gets immediate bonus")
    t.eq(sHot, 10000 + 10 + 200, "similar HOT pot denied immediate bonus")
    t.truthy(sImm > sHot, "immediate HP pot scores above HOT")
end)

test("Ranker: HOT HP pot earns immediate bonus only past the 20% threshold", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(3001, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { healValue = 10000 } })                                  -- immediate baseline
    -- A HOT pot whose amount clears the 20% threshold DOES earn the bonus.
    mock.setItem(3003, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { healValue = 100000, healOverSec = 5 } })                -- HOT >> best immediate
    local ctxBig = R.BuildContext("HP_POT", { 3001, 3003 }, nil, nil)
    t.eq(R._qualifiesForImmediateBonus({ healValue = 100000, healOverSec = 5 }, "HP", ctxBig),
        true, "large HOT pot clears 20% threshold")
    t.eq(R._qualifiesForImmediateBonus({ healValue = 10000, healOverSec = 5 }, "HP", ctxBig),
        false, "similar HOT pot fails 20% threshold")
end)

test("Ranker: immediate MP pot outranks similar-amount HOT pot", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(3101, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { manaValue = 8000 } })
    mock.setItem(3102, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { manaValue = 8000, manaOverSec = 6 } })
    local mpIds = R.SortCandidates("MP_POT", { 3101, 3102 }, nil, nil)
    t.eqList(mpIds, { 3101, 3102 }, "immediate MP pot outranks similar-amount HOT pot")
end)

test("Ranker: HS preference table prefers modern stone and sorts it first", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(224464, { subType = "Potions", quality = 3, ilvl = 40 })
    mock.setItem(5512,    { subType = "Potions", quality = 1, ilvl = 5 })
    t.eq(R.Score("HS", 224464, nil, nil), 1000 + 40, "HS modern preference + ilvl")
    t.eq(R.Score("HS", 5512, nil, nil), 100 + 5, "HS legacy preference + ilvl")
    t.truthy(R.Score("HS", 224464, nil, nil) > R.Score("HS", 5512, nil, nil),
        "224464 outranks 5512")
    local hsIds = R.SortCandidates("HS", { 5512, 224464 }, nil, nil)
    t.eqList(hsIds, { 224464, 5512 }, "HS sort puts modern first")
end)

test("Ranker: _statWeight ranks stats by spec priority", function(t)
    local KCM = h.loader.loadPure()
    local R   = KCM.Ranker
    local sp = { primary = "AGI", secondary = { "CRIT", "HASTE", "MASTERY" } }  -- N = 3
    t.eq(R._statWeight("AGI", sp), 1000, "primary -> 1000")
    t.eq(R._statWeight("CRIT", sp), 300, "secondary[1] -> 100*N")
    t.eq(R._statWeight("HASTE", sp), 200, "secondary[2] -> 100*(N-1)")
    t.eq(R._statWeight("MASTERY", sp), 100, "secondary[3] -> 100*(N-2)")
    t.eq(R._statWeight("TOP_SECONDARY", sp), 300, "TOP_SECONDARY -> 100*N")
    t.eq(R._statWeight("VERS", sp), 0, "unranked stat -> 0")
    t.eq(R._statWeight(nil, sp), 0, "nil stat -> 0")
    t.eq(R._statWeight("AGI", nil), 0, "nil specPriority -> 0")
    t.eq(R._statWeight("CRIT", { primary = "STR" }), 0, "no secondary table -> 0")
    t.eq(R._statWeight("TOP_SECONDARY", { primary = "STR", secondary = {} }), 0,
        "TOP_SECONDARY with empty secondary -> 0")
end)

test("Ranker: FLASK stat-aware primary buff outweighs equal-amount secondary", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    local sp = { primary = "AGI", secondary = { "CRIT", "HASTE", "MASTERY" } }  -- N = 3
    mock.setItem(4001, { subType = "Flasks & Phials", quality = 4, ilvl = 30,
        tt = { statBuffs = { { stat = "AGI", amount = 5 } } } })
    mock.setItem(4002, { subType = "Flasks & Phials", quality = 4, ilvl = 30,
        tt = { statBuffs = { { stat = "CRIT", amount = 5 } } } })
    local ctxSpec = { specPriority = sp }
    local flaskPrim = R.Score("FLASK", 4001, ctxSpec, nil)
    local flaskSec  = R.Score("FLASK", 4002, ctxSpec, nil)
    t.eq(flaskPrim, 1000 * 5 + 30 + 400, "FLASK primary buff score")
    t.eq(flaskSec, 300 * 5 + 30 + 400, "FLASK secondary buff score")
    t.truthy(flaskPrim > flaskSec, "primary-stat flask beats equal-amount secondary buff")
end)

test("Ranker: WPN_ENCH stat-aware primary buff outweighs equal-amount secondary", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    local sp = { primary = "STR", secondary = { "CRIT", "HASTE", "MASTERY" } }  -- N = 3
    mock.setItem(4301, { subType = "Other", quality = 4, ilvl = 30,
        tt = { statBuffs = { { stat = "STR",  amount = 5 } } } })
    mock.setItem(4302, { subType = "Other", quality = 4, ilvl = 30,
        tt = { statBuffs = { { stat = "CRIT", amount = 5 } } } })
    local ctxSpec = { specPriority = sp }
    local prim = R.Score("WPN_ENCH", 4301, ctxSpec, nil)
    local sec  = R.Score("WPN_ENCH", 4302, ctxSpec, nil)
    t.eq(prim, 1000 * 5 + 30 + 400, "WPN_ENCH primary buff score")
    t.eq(sec,  300 * 5 + 30 + 400, "WPN_ENCH secondary buff score")
    t.truthy(prim > sec, "primary-stat weapon enchant beats equal-amount secondary")
end)

test("Ranker: VANTUS prefers higher ilvl (current tier) then quality", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(4401, { subType = "Other", quality = 4, ilvl = 600, tt = {} })  -- current tier
    mock.setItem(4402, { subType = "Other", quality = 4, ilvl = 500, tt = {} })  -- old tier
    local cur = R.Score("VANTUS", 4401, nil, nil)
    local old = R.Score("VANTUS", 4402, nil, nil)
    t.eq(cur, 600 + 400, "VANTUS current-tier score = ilvl + quality*100")
    t.eq(old, 500 + 400, "VANTUS old-tier score")
    t.truthy(cur > old, "higher-ilvl vantus rune wins")
end)

test("Ranker: SortCandidates orders by score desc, ties by id asc", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    -- Same base (quality 1 -> 100, ilvl 1) so only healValue drives score.
    mock.setItem(10, { subType = "Food & Drink", tt = { healValue = 1000 } })
    mock.setItem(20, { subType = "Food & Drink", tt = { healValue = 2000 } })
    mock.setItem(30, { subType = "Food & Drink", tt = { healValue = 2000 } })  -- tie w/ 20
    mock.setItem(40, { subType = "Food & Drink", tt = { healValue = 500 } })
    local ids, rows = R.SortCandidates("FOOD", { 40, 10, 30, 20 }, nil, nil)
    -- 20 & 30 tie at 2000 -> id asc -> 20,30 ; then 10 ; then 40
    t.eqList(ids, { 20, 30, 10, 40 }, "sorted score desc, ties by id asc")
    t.eq(#rows, 4, "rows parallel to ids")
    t.truthy(rows[1].score >= rows[2].score, "rows[1] >= rows[2] score")
    t.eq(rows[1].id, 20, "rows carry id")
end)

test("Ranker: spell sentinel sorts first and empty input is safe", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    local AsSpell = KCM.ID.AsSpell
    mock.setItem(10, { subType = "Food & Drink", tt = { healValue = 1000 } })
    mock.setItem(20, { subType = "Food & Drink", tt = { healValue = 2000 } })

    -- Spell sentinel outranks every item in a sorted list.
    local sIds = R.SortCandidates("FOOD", { 20, AsSpell(999), 10 }, nil, nil)
    t.eq(sIds[1], AsSpell(999), "spell sentinel sorts first")

    -- Empty input is safe.
    local eIds, eRows = R.SortCandidates("FOOD", {}, nil, nil)
    t.eq(#eIds, 0, "empty candidate set -> empty ids")
    t.eq(#eRows, 0, "empty candidate set -> empty rows")
end)

test("Ranker: AP weights as primary for STR/AGI specs, 0 for INT; SP mirrors", function(t)
    local KCM = h.loader.loadPure()
    local W = KCM.Ranker._statWeight
    t.eq(W("AP", { primary = "STR" }), 1000, "AP -> primary for STR")
    t.eq(W("AP", { primary = "AGI" }), 1000, "AP -> primary for AGI")
    t.eq(W("AP", { primary = "INT" }), 0, "AP -> 0 for INT")
    t.eq(W("SP", { primary = "INT" }), 1000, "SP -> primary for INT")
    t.eq(W("SP", { primary = "STR" }), 0, "SP -> 0 for STR")
end)

test("Ranker: AUG_RUNE ranks by amount, reusable breaks ties, amount dominates", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker

    -- Ethereal (reusable) vs Crystallized (consumable), both 733 primary.
    mock.setItem(243191, { subType = "Other", quality = 4, ilvl = 1, tt = { statBuffs = { { stat = "PRIMARY", amount = 733 } } } })
    mock.setItem(224572, { subType = "Other", quality = 4, ilvl = 1, tt = { statBuffs = { { stat = "PRIMARY", amount = 733 } } } })
    local eth = R.Score("AUG_RUNE", 243191, nil, nil)
    local cry = R.Score("AUG_RUNE", 224572, nil, nil)
    t.eq(eth, 733 * 1e4 + 1e3 + 1 + 400, "Ethereal = amount + reusable + ilvl + quality")
    t.eq(cry, 733 * 1e4 + 0   + 1 + 400, "Crystallized = amount + ilvl + quality")
    t.truthy(eth > cry, "reusable breaks the 733 tie")

    -- Void-Touched (consumable, larger) beats Ethereal (reusable, 733).
    mock.setItem(259085, { subType = "Other", quality = 4, ilvl = 1, tt = { statBuffs = { { stat = "PRIMARY", amount = 900 } } } })
    t.truthy(R.Score("AUG_RUNE", 259085, nil, nil) > eth, "larger amount dominates reusable bonus")

    -- Quality can NOT override the reusable bonus at equal amount: the
    -- consumable epic (q4) 733 (Crystallized, cry above) must still lose to
    -- the reusable Ethereal. cry already carries the max quality contribution
    -- (q4 -> 400), so eth > cry proves REUSABLE_BONUS (1e3) outranks it.
    t.truthy(eth - cry == 1e3, "reusable bonus (1e3) is exactly the gap; outranks max quality (500)")

    -- Dragonflight phrasing: STR/AGI/INT triplet -> amount = max of them.
    mock.setItem(201325, { subType = "Other", quality = 3, ilvl = 1, tt = { statBuffs = {
        { stat = "STR", amount = 80 }, { stat = "AGI", amount = 80 }, { stat = "INT", amount = 80 } } } })
    t.eq(R.Score("AUG_RUNE", 201325, nil, nil), 80 * 1e4 + 0 + 1 + 300, "DF rune amount = max(STR,AGI,INT)")

    -- Pending tooltip (no statBuffs) -> amount 0, degrades to reusable-first.
    mock.setItem(800001, { subType = "Other", quality = 1, ilvl = 1, tt = { statBuffs = {} } })
    t.eq(R.Score("AUG_RUNE", 800001, nil, nil), 0 + 0 + 1 + 100, "no stat -> base score only")
end)

test("Ranker: BLOODLUST prefers a higher affect-cap, and an uncapped drum outranks every capped one", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(5001, { subType = "Other", quality = 3, ilvl = 200, tt = { maxLevel = 60 } })   -- old, capped
    mock.setItem(5002, { subType = "Other", quality = 3, ilvl = 200, tt = { maxLevel = 80 } })   -- newer, capped
    mock.setItem(5003, { subType = "Other", quality = 3, ilvl = 200, tt = {} })                  -- uncapped
    local old     = R.Score("BLOODLUST", 5001, nil, nil)
    local newer   = R.Score("BLOODLUST", 5002, nil, nil)
    local uncapped = R.Score("BLOODLUST", 5003, nil, nil)
    t.eq(old, 60 * 1e4 + 200 + 300, "BLOODLUST score = maxLevel * CAP_WEIGHT + ilvl + quality*100")
    t.eq(newer, 80 * 1e4 + 200 + 300, "BLOODLUST score for the newer drum")
    t.eq(uncapped, 9999 * 1e4 + 200 + 300, "BLOODLUST uncapped drum uses the 9999 sentinel")
    t.truthy(uncapped > newer, "uncapped drum outranks every capped one")
    t.truthy(newer > old, "higher affect-cap outranks a lower one")

    -- Spell forms still outrank every drum via SPELL_SCORE.
    local spell = KCM.ID.AsSpell(2825)
    t.truthy(R.Score("BLOODLUST", spell, nil, nil) > uncapped, "Bloodlust the spell outranks any drum")
end)

test("Ranker: BLOODLUST's cap term is weighted above ilvl (a lower-ilvl higher-cap drum wins)", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    -- Real drums span ilvl ~70-600; a higher cap must not be swamped by that
    -- range. Low ilvl + high cap vs. high ilvl + low cap: the cap decides.
    mock.setItem(5004, { subType = "Other", quality = 3, ilvl = 70,  tt = { maxLevel = 80 } })   -- lower ilvl, higher cap
    mock.setItem(5005, { subType = "Other", quality = 3, ilvl = 600, tt = { maxLevel = 50 } })   -- higher ilvl, lower cap
    local higherCap = R.Score("BLOODLUST", 5004, nil, nil)
    local higherIlvl = R.Score("BLOODLUST", 5005, nil, nil)
    t.truthy(higherCap > higherIlvl,
        "the lower-ilvl, higher-cap drum outranks the higher-ilvl, lower-cap one")
end)

test("Ranker: BLOODLUST Explain reports the actual cap and only notes 'no cap' when uncapped", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(5001, { subType = "Other", quality = 3, ilvl = 200, tt = { maxLevel = 60 } })   -- capped
    mock.setItem(5003, { subType = "Other", quality = 3, ilvl = 200, tt = {} })                  -- uncapped

    local capped = R.Explain("BLOODLUST", 5001, nil)
    local capRow
    for _, s in ipairs(capped.signals) do
        if s.label == "affects up to level x10000" then capRow = s end
    end
    t.truthy(capRow, "capped drum has an 'affects up to level x10000' signal")
    t.eq(capRow.value, 60 * 1e4, "capped drum's signal reports its weighted cap contribution")
    t.eq(capRow.note, "cap 60", "capped drum's note names the actual cap")
    t.eq(capped.score, 60 * 1e4 + 200 + 300, "BLOODLUST Explain score matches the scorer")

    local uncapped = R.Explain("BLOODLUST", 5003, nil)
    local uncapRow
    for _, s in ipairs(uncapped.signals) do
        if s.label == "affects up to level x10000" then uncapRow = s end
    end
    t.truthy(uncapRow, "uncapped drum has an 'affects up to level x10000' signal")
    t.eq(uncapRow.value, 9999 * 1e4, "uncapped drum's signal reports the weighted 9999 sentinel")
    t.eq(uncapRow.note, "no cap", "uncapped drum DOES carry the 'no cap' note")
    t.eq(uncapped.score, 9999 * 1e4 + 200 + 300, "BLOODLUST Explain score matches the scorer for the uncapped item")
end)

test("Ranker: BATTLE_REZ Explain reports ilvl and quality signals with the scorer's score", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(248486, { subType = "Other", quality = 4, ilvl = 30, tt = {} })
    local result = R.Explain("BATTLE_REZ", 248486, nil)
    t.eq(result.score, 30 + 400, "BATTLE_REZ Explain score = ilvl + quality*100")
    local labels = {}
    for _, s in ipairs(result.signals) do labels[s.label] = s.value end
    t.eq(labels.ilvl, 30, "BATTLE_REZ Explain reports the ilvl signal")
    t.eq(labels["quality x100"], 400, "BATTLE_REZ Explain reports the quality signal")
end)

test("Ranker: BATTLE_REZ ranks the lone seeded item by ilvl and quality", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(248486, { subType = "Other", quality = 4, ilvl = 30, tt = {} })
    t.eq(R.Score("BATTLE_REZ", 248486, nil, nil), 30 + 400, "BATTLE_REZ score = ilvl + quality*100")

    local spell = KCM.ID.AsSpell(20484)
    t.truthy(R.Score("BATTLE_REZ", spell, nil, nil) > R.Score("BATTLE_REZ", 248486, nil, nil),
        "Rebirth the spell outranks the soul link item")
end)

test("Ranker: PRIMARY token does not change FLASK score (statWeight stays 0)", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker

    -- statWeight must return 0 for PRIMARY so aug-rune parsing never leaks
    -- into spec-aware categories.
    t.eq(R._statWeight("PRIMARY", { primary = "STR", secondary = { "CRIT" } }), 0,
        "PRIMARY weighted 0 regardless of spec primary")

    -- A flask whose tooltip (hypothetically) also mentions Primary Stat scores
    -- only from its secondary buff — the PRIMARY entry contributes nothing.
    local spec = { primary = "AGI", secondary = { "CRIT", "HASTE" } }
    mock.setItem(500001, { subType = "Flasks & Phials", quality = 4, ilvl = 1, tt = { statBuffs = {
        { stat = "CRIT", amount = 100 }, { stat = "PRIMARY", amount = 733 } } } })
    -- CRIT is secondary[1] of 2 -> weight 100*2 = 200; contrib 100*200 = 20000.
    t.eq(R.Score("FLASK", 500001, { specPriority = spec }, nil), 20000 + 1 + 400,
        "FLASK score = CRIT contribution + ilvl + quality; PRIMARY adds nothing")
end)
