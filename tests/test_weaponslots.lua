-- tests/test_weaponslots.lua — equipped-weapon affinity mapping.

local h = _G.KCM_TEST
local test = h.test

test("WeaponSlots: maps equipped weapon subtype to bladed/blunt/nil", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local W    = KCM.WeaponSlots

    mock.setItem(5001, { subType = "Two-Handed Swords" })
    mock.setEquipped(16, 5001)
    t.eq(W.SlotAffinity(16), "bladed", "2H sword -> bladed")

    mock.setItem(5002, { subType = "One-Handed Maces" })
    mock.setEquipped(17, 5002)
    t.eq(W.SlotAffinity(17), "blunt", "1H mace -> blunt")

    mock.setItem(5003, { subType = "Shields" })
    mock.setEquipped(17, 5003)
    t.eq(W.SlotAffinity(17), nil, "shield -> nil (not enhanceable)")

    mock.setEquipped(16, nil)
    t.eq(W.SlotAffinity(16), nil, "empty slot -> nil")
end)

-- Locale-independence: affinity keys on the weapon subClassID, not the
-- localized subType, and the classID gate stops Armor subclasses from
-- colliding with weapon subclasses (localization-§4 / anti-pattern #37).
test("WeaponSlots: keys on weapon subClassID, not the localized subType", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local W    = KCM.WeaponSlots

    -- 2H sword on a deDE client: subType localized, classID 2 / subClassID 8.
    mock.setItem(6001, { subType = "Zweihandschwerter", classID = 2, subClassID = 8 })
    mock.setEquipped(16, 6001)
    t.eq(W.SlotAffinity(16), "bladed", "2H sword via subClassID 8 despite non-English subType")

    -- Shield is Armor(4)/subclass 6; must NOT collide with Polearm (Weapon/6).
    mock.setItem(6002, { subType = "Bouclier", classID = 4, subClassID = 6 })
    mock.setEquipped(17, 6002)
    t.eq(W.SlotAffinity(17), nil, "armor subclass 6 (shield) is not a polearm (classID gate)")
end)

-- The full weapon-subclass matrix. Every bladed subclass takes a whetstone and
-- every blunt one a weightstone; anything else (ranged, wands, armor) takes
-- neither, so the Weapon Enchant category must not offer that hand a stone.
local BLADED_SUBCLASSES = {
    [0]  = "One-Handed Axes",   [1]  = "Two-Handed Axes",
    [7]  = "One-Handed Swords", [8]  = "Two-Handed Swords",
    [15] = "Daggers",           [6]  = "Polearms",
    [13] = "Fist Weapons",      [9]  = "Warglaives",
}
local BLUNT_SUBCLASSES = {
    [4]  = "One-Handed Maces",  [5]  = "Two-Handed Maces",
    [10] = "Staves",
}
-- Weapon subclasses that take no temporary enhancement.
local UNENHANCEABLE_SUBCLASSES = {
    [2]  = "Bows",   [3]  = "Guns",  [18] = "Crossbows",
    [16] = "Thrown", [19] = "Wands", [11] = "Bear Claws (unused)",
}

test("WeaponSlots: every bladed weapon subclass reports bladed affinity", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local id   = 7000
    for subClassID, label in pairs(BLADED_SUBCLASSES) do
        id = id + 1
        mock.setItem(id, { subType = label, classID = 2, subClassID = subClassID })
        mock.setEquipped(16, id)
        t.eq(KCM.WeaponSlots.SlotAffinity(16), "bladed", label .. " takes a whetstone")
    end
end)

test("WeaponSlots: every blunt weapon subclass reports blunt affinity", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local id   = 7100
    for subClassID, label in pairs(BLUNT_SUBCLASSES) do
        id = id + 1
        mock.setItem(id, { subType = label, classID = 2, subClassID = subClassID })
        mock.setEquipped(16, id)
        t.eq(KCM.WeaponSlots.SlotAffinity(16), "blunt", label .. " takes a weightstone")
    end
end)

test("WeaponSlots: ranged and wand subclasses take no stone at all", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local id   = 7200
    for subClassID, label in pairs(UNENHANCEABLE_SUBCLASSES) do
        id = id + 1
        mock.setItem(id, { subType = label, classID = 2, subClassID = subClassID })
        mock.setEquipped(16, id)
        t.eq(KCM.WeaponSlots.SlotAffinity(16), nil, label .. " has no affinity")
    end
end)

test("WeaponSlots: main hand and off hand are read independently", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setItem(7301, { subType = "Daggers" })
    mock.setItem(7302, { subType = "One-Handed Maces" })
    mock.setEquipped(16, 7301)
    mock.setEquipped(17, 7302)
    t.eq(KCM.WeaponSlots.SlotAffinity(16), "bladed", "main hand dagger")
    t.eq(KCM.WeaponSlots.SlotAffinity(17), "blunt", "off hand mace — each hand resolves on its own")
end)

test("WeaponSlots: an off-hand holdable (armor) is not enhanceable", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    -- Held In Off-hand is Armor(4) / subclass 0 — which as a WEAPON subclass
    -- would be a One-Handed Axe. The class gate is what keeps them apart.
    mock.setItem(7401, { subType = "Miscellaneous", classID = 4, subClassID = 0 })
    mock.setEquipped(17, 7401)
    t.eq(KCM.WeaponSlots.SlotAffinity(17), nil, "armor never resolves to a weapon affinity")
end)

test("WeaponSlots: an unknown item in the slot yields no affinity", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setEquipped(16, 999999)     -- equipped, but item data has not arrived
    t.eq(KCM.WeaponSlots.SlotAffinity(16), nil, "unresolvable item data is not guessed at")
end)

test("WeaponSlots: a slot the client cannot report is safe to query", function(t)
    local KCM = h.loader.loadPure()
    local saved = _G.GetInventoryItemID
    _G.GetInventoryItemID = nil
    local affinity = KCM.WeaponSlots.SlotAffinity(16)
    _G.GetInventoryItemID = saved
    t.eq(affinity, nil, "a missing inventory API degrades to nil, not an error")
end)
