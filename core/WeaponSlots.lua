-- core/WeaponSlots.lua — equipped-weapon affinity for the Weapon Enchant
-- category. Maps the main-hand (16) / off-hand (17) weapon's numeric weapon
-- subClassID to "bladed" (whetstone) / "blunt" (weightstone) / nil (not
-- enhanceable). Keys on the locale-independent classID / subClassID from
-- GetItemInfoInstant, never the localized subType display string (Ka0s
-- Standard localization-§4 / anti-pattern #37).

local _, NS = ...
local KCM = NS
KCM.WeaponSlots = KCM.WeaponSlots or {}
local W = KCM.WeaponSlots

-- Enum.ItemClass.Weapon and Enum.ItemWeaponSubclass values.
local CLASS_WEAPON = 2
local BLADED = {   -- swords, axes, daggers, polearms, fists, warglaives
    [0] = true, [1] = true,   -- One-/Two-Handed Axes
    [7] = true, [8] = true,   -- One-/Two-Handed Swords
    [15] = true,              -- Daggers
    [6] = true,               -- Polearms
    [13] = true,              -- Fist Weapons (Unarmed)
    [9] = true,               -- Warglaives
}
local BLUNT = {
    [4] = true, [5] = true,   -- One-/Two-Handed Maces
    [10] = true,              -- Staves
}

-- slot: 16 (main hand) or 17 (off hand). Returns "bladed" | "blunt" | nil.
function W.SlotAffinity(slot)
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not itemID then return nil end
    local classID, subClassID
    if C_Item and C_Item.GetItemInfoInstant then
        local _; _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    else
        local _; _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemID)
    end
    -- Only actual weapons are enhanceable; a Shield / Held-in-off-hand is Armor,
    -- whose subclass numbers collide with weapon subclasses (Armor 6 = Shield
    -- vs Weapon 6 = Polearm), so gate on the class before reading the subclass.
    if classID ~= CLASS_WEAPON then return nil end
    if BLADED[subClassID] then return "bladed" end
    if BLUNT[subClassID]  then return "blunt"  end
    return nil
end
