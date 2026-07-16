-- tests/test_weaponslots.lua — equipped-weapon affinity mapping.

local h = require("harness")
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
