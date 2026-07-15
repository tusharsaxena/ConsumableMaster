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
