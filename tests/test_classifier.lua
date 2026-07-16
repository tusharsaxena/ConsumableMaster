-- tests/test_classifier.lua — Classifier.Match / Classifier.MatchAny coverage.

local h = require("harness")
local test = h.test

-- ---- FOOD: Food & Drink + heal, not hasStatBuff ----------------------------
test("classifier: FOOD matches Food & Drink with heal and no stat buff", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1001, { subType = "Food & Drink", tt = { healValue = 500 } })
    t.truthy(C.Match("FOOD", 1001), "FOOD positive (healValue)")
    t.eqList(C.MatchAny(1001), { "FOOD" }, "MatchAny food -> {FOOD}")

    mock.setItem(1002, { subType = "Food & Drink", tt = { healPct = 30 } })
    t.truthy(C.Match("FOOD", 1002), "FOOD positive via healPct")

    -- negative: heal food that also carries a stat buff is not plain FOOD
    mock.setItem(1003, { subType = "Food & Drink", tt = { healValue = 500, hasStatBuff = true } })
    t.falsy(C.Match("FOOD", 1003), "FOOD negative when hasStatBuff")
    -- negative: no heal at all
    mock.setItem(1004, { subType = "Food & Drink", tt = {} })
    t.falsy(C.Match("FOOD", 1004), "FOOD negative when no heal")
    -- negative: wrong subtype
    mock.setItem(1005, { subType = "Potions", tt = { healValue = 500 } })
    t.falsy(C.Match("FOOD", 1005), "FOOD negative when subtype is Potions")
end)

-- ---- DRINK: Food & Drink + mana, not hasStatBuff ---------------------------
test("classifier: DRINK matches Food & Drink with mana and no stat buff", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1101, { subType = "Food & Drink", tt = { manaValue = 800 } })
    t.truthy(C.Match("DRINK", 1101), "DRINK positive (manaValue)")
    t.eqList(C.MatchAny(1101), { "DRINK" }, "MatchAny drink -> {DRINK}")

    mock.setItem(1102, { subType = "Food & Drink", tt = { manaPct = 50 } })
    t.truthy(C.Match("DRINK", 1102), "DRINK positive via manaPct")

    mock.setItem(1103, { subType = "Food & Drink", tt = { manaValue = 800, hasStatBuff = true } })
    t.falsy(C.Match("DRINK", 1103), "DRINK negative when hasStatBuff")
    mock.setItem(1104, { subType = "Food & Drink", tt = { healValue = 500 } })
    t.falsy(C.Match("DRINK", 1104), "DRINK negative when only heal")
end)

-- ---- STAT_FOOD: Food & Drink + hasStatBuff, not isFeast --------------------
test("classifier: STAT_FOOD matches stat-buff food and excludes feast", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1201, { subType = "Food & Drink", tt = { hasStatBuff = true } })
    t.truthy(C.Match("STAT_FOOD", 1201), "STAT_FOOD positive")

    -- negative: feast is excluded
    mock.setItem(1202, { subType = "Food & Drink", tt = { hasStatBuff = true, isFeast = true } })
    t.falsy(C.Match("STAT_FOOD", 1202), "STAT_FOOD negative when isFeast")
    -- negative: no stat buff
    mock.setItem(1203, { subType = "Food & Drink", tt = { healValue = 500 } })
    t.falsy(C.Match("STAT_FOOD", 1203), "STAT_FOOD negative when no stat buff")

    -- A stat food that also lists a heal matches both FOOD? No — FOOD requires
    -- NOT hasStatBuff, so a stat-buffed heal food is STAT_FOOD only.
    mock.setItem(1204, { subType = "Food & Drink", tt = { healValue = 500, hasStatBuff = true } })
    t.eqList(C.MatchAny(1204), { "STAT_FOOD" }, "MatchAny stat food -> {STAT_FOOD}")
end)

-- ---- HP_POT: Potions + heal, not hasStatBuff ------------------------------
test("classifier: HP_POT matches healing potions without a stat buff", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1301, { subType = "Potions", tt = { healValue = 4000 } })
    t.truthy(C.Match("HP_POT", 1301), "HP_POT positive")
    t.eqList(C.MatchAny(1301), { "HP_POT" }, "MatchAny hp pot -> {HP_POT}")

    mock.setItem(1302, { subType = "Potions", tt = { healValue = 4000, hasStatBuff = true } })
    t.falsy(C.Match("HP_POT", 1302), "HP_POT negative when hasStatBuff")
    mock.setItem(1303, { subType = "Potions", tt = { manaValue = 4000 } })
    t.falsy(C.Match("HP_POT", 1303), "HP_POT negative when only mana")
end)

-- ---- MP_POT: Potions + mana, not hasStatBuff ------------------------------
test("classifier: MP_POT matches mana potions without a stat buff", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1401, { subType = "Potions", tt = { manaValue = 4000 } })
    t.truthy(C.Match("MP_POT", 1401), "MP_POT positive")
    t.eqList(C.MatchAny(1401), { "MP_POT" }, "MatchAny mp pot -> {MP_POT}")

    mock.setItem(1402, { subType = "Potions", tt = { manaValue = 4000, hasStatBuff = true } })
    t.falsy(C.Match("MP_POT", 1402), "MP_POT negative when hasStatBuff")
    mock.setItem(1403, { subType = "Food & Drink", tt = { manaValue = 4000 } })
    t.falsy(C.Match("MP_POT", 1403), "MP_POT negative when subtype is food")
end)

-- ---- HS: hard-coded itemIDs 5512 & 224464 regardless of tt ----------------
test("classifier: HS matches hard-coded healthstone IDs regardless of item data", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    -- No setItem call needed — HS matches by ID before any tooltip/subtype read.
    t.truthy(C.Match("HS", 5512), "HS positive 5512 (no item data)")
    t.truthy(C.Match("HS", 224464), "HS positive 224464 (no item data)")
    -- still matches even with unrelated item data injected
    mock.setItem(5512, { subType = "Potions", tt = { healValue = 1 } })
    t.truthy(C.Match("HS", 5512), "HS positive 5512 with item data")
    -- negative: a normal potion id is not a healthstone
    mock.setItem(1501, { subType = "Potions", tt = { healValue = 4000 } })
    t.falsy(C.Match("HS", 1501), "HS negative for ordinary potion")
    -- HS shows up in MatchAny for a healthstone id
    t.contains(C.MatchAny(224464), "HS", "MatchAny includes HS for 224464")
end)

-- ---- CMBT_POT: Potions, no heal/mana, buffDurationSec in 1..60 ------------
test("classifier: CMBT_POT matches buff potions with 1..60s duration and no heal/mana", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1601, { subType = "Potions", tt = { buffDurationSec = 25 } })
    t.truthy(C.Match("CMBT_POT", 1601), "CMBT_POT positive (25s)")
    mock.setItem(1602, { subType = "Potions", tt = { buffDurationSec = 60 } })
    t.truthy(C.Match("CMBT_POT", 1602), "CMBT_POT positive at boundary 60s")
    mock.setItem(1603, { subType = "Potions", tt = { buffDurationSec = 1 } })
    t.truthy(C.Match("CMBT_POT", 1603), "CMBT_POT positive at 1s")

    -- negative: duration > 60 is a pre-buff flask/elixir, not a combat pot
    mock.setItem(1604, { subType = "Potions", tt = { buffDurationSec = 61 } })
    t.falsy(C.Match("CMBT_POT", 1604), "CMBT_POT negative when >60s")
    mock.setItem(1605, { subType = "Potions", tt = { buffDurationSec = 3600 } })
    t.falsy(C.Match("CMBT_POT", 1605), "CMBT_POT negative when 3600s")
    -- negative: 0/absent duration
    mock.setItem(1606, { subType = "Potions", tt = {} })
    t.falsy(C.Match("CMBT_POT", 1606), "CMBT_POT negative when no duration")
    -- negative: has heal (it's a healing pot, not combat)
    mock.setItem(1607, { subType = "Potions", tt = { buffDurationSec = 25, healValue = 500 } })
    t.falsy(C.Match("CMBT_POT", 1607), "CMBT_POT negative when heals")
    -- negative: has mana
    mock.setItem(1608, { subType = "Potions", tt = { buffDurationSec = 25, manaValue = 500 } })
    t.falsy(C.Match("CMBT_POT", 1608), "CMBT_POT negative when restores mana")
    -- MatchAny for a clean combat pot -> exactly {CMBT_POT}
    t.eqList(C.MatchAny(1601), { "CMBT_POT" }, "MatchAny combat pot -> {CMBT_POT}")
end)

-- ---- FLASK: matches on subType alone, even with empty tt ------------------
test("classifier: FLASK matches on subtype alone", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1701, { subType = "Flasks & Phials", tt = {} })
    t.truthy(C.Match("FLASK", 1701), "FLASK positive with empty tt")
    t.eqList(C.MatchAny(1701), { "FLASK" }, "MatchAny flask -> {FLASK}")

    -- negative: potion subtype is not a flask
    mock.setItem(1702, { subType = "Potions", tt = { buffDurationSec = 25 } })
    t.falsy(C.Match("FLASK", 1702), "FLASK negative for potion subtype")
end)

-- ---- MatchAny never includes composite categories ------------------------
test("classifier: MatchAny never yields composite categories", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    -- HP_AIO components include HS/HP_POT/FOOD; MP_AIO include MP_POT/DRINK.
    -- Even for items that satisfy those, MatchAny must not emit the composites.
    mock.setItem(1001, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setItem(1101, { subType = "Food & Drink", tt = { manaValue = 800 } })
    mock.setItem(1301, { subType = "Potions", tt = { healValue = 4000 } })
    mock.setItem(1401, { subType = "Potions", tt = { manaValue = 4000 } })
    mock.setItem(1601, { subType = "Potions", tt = { buffDurationSec = 25 } })
    mock.setItem(1701, { subType = "Flasks & Phials", tt = {} })
    for _, id in ipairs({ 1001, 1101, 1301, 1401, 1601, 1701, 224464 }) do
        for _, hit in ipairs(C.MatchAny(id)) do
            t.ne(hit, "HP_AIO", "MatchAny never yields HP_AIO (id " .. id .. ")")
            t.ne(hit, "MP_AIO", "MatchAny never yields MP_AIO (id " .. id .. ")")
        end
    end
end)

-- ---- Unrecognized subType + empty tt matches nothing ---------------------
test("classifier: unrecognized subtype with empty tt matches nothing", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1801, { subType = "Junk", tt = {} })
    t.eqList(C.MatchAny(1801), {}, "MatchAny unknown subtype -> {}")
    t.falsy(C.Match("FOOD", 1801), "unknown subtype not FOOD")
    t.falsy(C.Match("CMBT_POT", 1801), "unknown subtype not CMBT_POT")
    t.falsy(C.Match("FLASK", 1801), "unknown subtype not FLASK")
end)

-- ---- WPN_ENCH: weapon enhancements flagged by the tooltip's weapon effect -
test("classifier: WPN_ENCH matches weapon enhancements by the isWeaponEnhance flag", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    -- Weapon enhancements (oils/whetstones/weightstones) report subType "Other";
    -- they are identified by the weapon-application effect (tt.isWeaponEnhance),
    -- not subType.
    mock.setItem(1901, { subType = "Other", tt = { isWeaponEnhance = true, hasStatBuff = true } })
    t.truthy(C.Match("WPN_ENCH", 1901), "WPN_ENCH positive via isWeaponEnhance")
    t.eqList(C.MatchAny(1901), { "WPN_ENCH" }, "MatchAny weapon enhancement -> {WPN_ENCH}")

    -- negative: a plain "Other" consumable without the weapon-enhance effect
    mock.setItem(1902, { subType = "Other", tt = { hasStatBuff = true } })
    t.falsy(C.Match("WPN_ENCH", 1902), "WPN_ENCH negative for Other without isWeaponEnhance")
    -- negative: a flask is not a weapon enchant
    mock.setItem(1903, { subType = "Flasks & Phials", tt = {} })
    t.falsy(C.Match("WPN_ENCH", 1903), "WPN_ENCH negative for flask")
end)

-- ---- VANTUS: hard-coded itemIDs regardless of tt -------------------------
test("classifier: VANTUS matches whitelisted rune IDs regardless of item data", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    t.truthy(C.Match("VANTUS", 245880), "VANTUS positive 245880 (no item data)")
    t.contains(C.MatchAny(245880), "VANTUS", "MatchAny includes VANTUS for 245880")

    -- negative: an ordinary item id is not a vantus rune
    mock.setItem(1951, { subType = "Potions", tt = { healValue = 4000 } })
    t.falsy(C.Match("VANTUS", 1951), "VANTUS negative for ordinary potion")
end)

-- ---- Guard / edge cases --------------------------------------------------
test("classifier: guard and edge cases for nil/unknown inputs", function(t)
    local KCM  = h.loader.loadPure()
    local C    = KCM.Classifier

    t.falsy(C.Match(nil, 1001), "Match nil catKey -> false")
    t.falsy(C.Match("FOOD", nil), "Match nil itemID -> false")
    t.falsy(C.Match("NOPE", 1001), "Match unknown catKey -> false")
    -- unknown itemID (no data): non-HS matchers false; MatchAny empty
    t.falsy(C.Match("FOOD", 99999), "Match unknown itemID -> false (no subtype)")
    t.eqList(C.MatchAny(99999), {}, "MatchAny unknown itemID -> {}")
    t.eqList(C.MatchAny(nil), {}, "MatchAny nil -> {}")
end)

-- ---- AUG_RUNE: tooltip marker, plus reusable-ID helper --------------------
test("classifier: AUG_RUNE matches any augment-rune tooltip; reusable helper", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    -- Seeded consumable rune.
    mock.setItem(224572, { subType = "Other", tt = { isAugmentRune = true } })
    t.truthy(C.Match("AUG_RUNE", 224572), "AUG_RUNE positive via marker")
    t.contains(C.MatchAny(224572), "AUG_RUNE", "MatchAny includes AUG_RUNE")

    -- Unseeded future rune — auto-discovered by the same marker.
    mock.setItem(999999, { subType = "Other", tt = { isAugmentRune = true } })
    t.truthy(C.Match("AUG_RUNE", 999999), "AUG_RUNE positive for unseeded rune")

    -- Negative: ordinary flask is not an augment rune.
    mock.setItem(1961, { subType = "Flasks & Phials", tt = {} })
    t.falsy(C.Match("AUG_RUNE", 1961), "AUG_RUNE negative for flask")

    -- Reusable helper: explicit set, not tooltip-driven.
    t.truthy(C.IsReusableAugRune(243191), "Ethereal is reusable")
    t.truthy(C.IsReusableAugRune(211495), "Dreambound is reusable")
    t.truthy(C.IsReusableAugRune(190384), "Eternal is reusable (SL)")
    t.truthy(C.IsReusableAugRune(174906), "Lightning-Forged is reusable (BfA)")
    t.truthy(C.IsReusableAugRune(153023), "Lightforged is reusable (Legion)")
    t.falsy(C.IsReusableAugRune(224572), "Crystallized is consumable")
    t.falsy(C.IsReusableAugRune(160053), "Battle-Scarred is consumable")
    t.falsy(C.IsReusableAugRune(nil), "nil is not reusable")
end)
