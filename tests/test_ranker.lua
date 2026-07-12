-- tests/test_ranker.lua — unit suite for Ranker.lua scoring + sorting.

local h = require("harness")

h.suite("ranker", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    local AsSpell = KCM.ID.AsSpell

    local SPELL_SCORE      = 1e9
    local CONJURED_BONUS   = 1e6
    local IMMEDIATE_BONUS  = 1e8

    -- ---- spell sentinel scores SPELL_SCORE for any category ---------------
    local spell = AsSpell(1231411)
    t.eq(R.Score("FOOD",  spell, nil, nil), SPELL_SCORE, "spell sentinel -> SPELL_SCORE (FOOD)")
    t.eq(R.Score("HP_POT", spell, nil, nil), SPELL_SCORE, "spell sentinel -> SPELL_SCORE (HP_POT)")
    t.eq(R.Score("FLASK", spell, nil, nil), SPELL_SCORE, "spell sentinel -> SPELL_SCORE (FLASK)")
    -- nil guards
    t.eq(R.Score(nil, 1, nil, nil), 0, "nil catKey -> 0")
    t.eq(R.Score("FOOD", nil, nil, nil), 0, "nil itemID -> 0")
    t.eq(R.Score("NOPE", 1, nil, nil), 0, "unknown category -> 0")

    -- ---- FOOD / DRINK additive scoring + conjured bonus -------------------
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

    -- healPct dominates flat tiers (pct * 1e4)
    mock.setItem(2003, { subType = "Food & Drink", quality = 1, ilvl = 1,
        tt = { healPct = 60 } })
    t.eq(R.Score("FOOD", 2003, nil, nil), 60 * 1e4 + 1 + 100, "FOOD pct weighting")

    -- healValue + healValueAvg both contribute
    mock.setItem(2004, { subType = "Food & Drink", quality = 1, ilvl = 1,
        tt = { healValue = 200, healValueAvg = 300 } })
    t.eq(R.Score("FOOD", 2004, nil, nil), 200 + 300 + 1 + 100, "FOOD healValue + healValueAvg")

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

    -- ---- HP_POT / MP_POT immediate bonus ---------------------------------
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

    -- A HOT pot whose amount clears the 20% threshold DOES earn the bonus.
    mock.setItem(3003, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { healValue = 100000, healOverSec = 5 } })                -- HOT >> best immediate
    local ctxBig = R.BuildContext("HP_POT", { 3001, 3003 }, nil, nil)
    t.eq(R._qualifiesForImmediateBonus({ healValue = 100000, healOverSec = 5 }, "HP", ctxBig),
        true, "large HOT pot clears 20% threshold")
    t.eq(R._qualifiesForImmediateBonus({ healValue = 10000, healOverSec = 5 }, "HP", ctxBig),
        false, "similar HOT pot fails 20% threshold")

    -- MP pot mirror.
    mock.setItem(3101, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { manaValue = 8000 } })
    mock.setItem(3102, { subType = "Potions", quality = 2, ilvl = 10,
        tt = { manaValue = 8000, manaOverSec = 6 } })
    local mpIds = R.SortCandidates("MP_POT", { 3101, 3102 }, nil, nil)
    t.eqList(mpIds, { 3101, 3102 }, "immediate MP pot outranks similar-amount HOT pot")

    -- ---- HS preference table ---------------------------------------------
    mock.setItem(224464, { subType = "Potions", quality = 3, ilvl = 40 })
    mock.setItem(5512,    { subType = "Potions", quality = 1, ilvl = 5 })
    t.eq(R.Score("HS", 224464, nil, nil), 1000 + 40, "HS modern preference + ilvl")
    t.eq(R.Score("HS", 5512, nil, nil), 100 + 5, "HS legacy preference + ilvl")
    t.truthy(R.Score("HS", 224464, nil, nil) > R.Score("HS", 5512, nil, nil),
        "224464 outranks 5512")
    local hsIds = R.SortCandidates("HS", { 5512, 224464 }, nil, nil)
    t.eqList(hsIds, { 224464, 5512 }, "HS sort puts modern first")

    -- ---- R._statWeight ---------------------------------------------------
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

    -- Stat-aware scorer wiring (FLASK): primary buff outweighs secondary.
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

    -- ---- SortCandidates ordering: score desc, ties by id asc -------------
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

    -- Spell sentinel outranks every item in a sorted list.
    local sIds = R.SortCandidates("FOOD", { 20, AsSpell(999), 10 }, nil, nil)
    t.eq(sIds[1], AsSpell(999), "spell sentinel sorts first")

    -- Empty input is safe.
    local eIds, eRows = R.SortCandidates("FOOD", {}, nil, nil)
    t.eq(#eIds, 0, "empty candidate set -> empty ids")
    t.eq(#eRows, 0, "empty candidate set -> empty rows")
end)
