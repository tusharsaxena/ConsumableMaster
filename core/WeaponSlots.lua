-- core/WeaponSlots.lua — equipped-weapon affinity for the Weapon Enchant
-- category. Maps the main-hand (16) / off-hand (17) weapon's English subType to
-- "bladed" (whetstone) / "blunt" (weightstone) / nil (not enhanceable). English
-- subtype strings per project scope; update the maps if Blizzard renames them.

local _, NS = ...
local KCM = NS
KCM.WeaponSlots = KCM.WeaponSlots or {}
local W = KCM.WeaponSlots

local BLADED = {
    ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true,
    ["One-Handed Axes"]   = true, ["Two-Handed Axes"]   = true,
    ["Daggers"]           = true, ["Polearms"]          = true,
    ["Fist Weapons"]      = true, ["Warglaives"]        = true,
}
local BLUNT = {
    ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
    ["Staves"]           = true,
}

-- slot: 16 (main hand) or 17 (off hand). Returns "bladed" | "blunt" | nil.
function W.SlotAffinity(slot)
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not itemID then return nil end
    local subType
    if C_Item and C_Item.GetItemInfoInstant then
        local _; _, _, subType = C_Item.GetItemInfoInstant(itemID)
    else
        local _; _, _, _, _, _, _, subType = GetItemInfo(itemID)
    end
    if not subType then return nil end
    if BLADED[subType] then return "bladed" end
    if BLUNT[subType]  then return "blunt"  end
    return nil
end
