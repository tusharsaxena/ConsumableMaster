-- core/MacroDisplay.lua — read-only display resolution for a KCM macro.
--
-- One place that answers "what icon / tooltip / count / cooldown belongs to
-- KCM_FOOD right now", shared by the macro-bar buttons (modules/MacroBar*.lua)
-- and the per-category drag icon (modules/KCMMacroDragIcon.lua). Read-only by
-- design: it never touches a protected macro API, so it stays on the same
-- taint-free footing as the rest of the pure layer (MacroManager remains the
-- sole caller of CreateMacro / EditMacro).
--
-- The pick itself comes from `db.profile.macroState[macroName].lastItemID`,
-- which MacroManager stamps on every write. That value is an opaque KCM ID:
-- positive = itemID, negative = spell sentinel (see KCM.ID). Active macros
-- store the `?` icon sentinel so `#showtooltip` can drive an action-bar button,
-- which is meaningless for a custom frame — hence resolving the real texture
-- from the pick here instead of reading the stored macro icon first.

local _, NS = ...
local KCM = NS
KCM.MacroDisplay = KCM.MacroDisplay or {}
local MD = KCM.MacroDisplay

-- Cooking pot — matches MacroManager.DEFAULT_ICON, the icon an empty-state
-- macro stores.
MD.FALLBACK_ICON = 7704166

function MD.MacroIndex(macroName)
    if not (macroName and GetMacroIndexByName) then return 0 end
    return GetMacroIndexByName(macroName) or 0
end

-- The opaque KCM ID the macro currently resolves to, or nil for an empty-state
-- macro (no item in bags) or one that has never been written.
function MD.PickID(macroName)
    if not macroName then return nil end
    local state = KCM.db and KCM.db.profile and KCM.db.profile.macroState
    local entry = state and state[macroName]
    return entry and entry.lastItemID or nil
end

-- Texture for a pick: item icon, spell icon, or nil when the ID can't be
-- resolved yet (item data not hydrated).
function MD.TextureForID(id)
    local ID = KCM.ID
    if not (id and ID) then return nil end
    if ID.IsSpell(id) then
        if C_Spell and C_Spell.GetSpellTexture then
            return C_Spell.GetSpellTexture(ID.SpellID(id))
        end
        return nil
    end
    local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return getIcon and getIcon(id) or nil
end

-- Icon for a macro, resolved pick-first and degrading to the stored macro icon
-- and then the cooking pot, so a button always has something to draw.
function MD.Texture(macroName)
    local tex = MD.TextureForID(MD.PickID(macroName))
    if tex then return tex end
    local idx = MD.MacroIndex(macroName)
    if idx ~= 0 and GetMacroInfo then
        local _, icon = GetMacroInfo(idx)
        if icon then return icon end
    end
    return MD.FALLBACK_ICON
end

-- Owned count for an opaque KCM ID, or nil when a count is meaningless (spells).
-- Returns nil rather than 0 so callers can tell "nothing to show" from "you have
-- zero left".
function MD.CountForID(id)
    local ID = KCM.ID
    if not (id and ID and ID.IsItem(id)) then return nil end
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not getCount then return nil end
    return getCount(id)
end

-- Cooldown triple (start, duration, enable) for an opaque KCM ID, or nil.
-- Items and spells report through different APIs; both are read-only.
function MD.CooldownForID(id)
    local ID = KCM.ID
    if not (id and ID) then return nil end
    if ID.IsSpell(id) then
        local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(ID.SpellID(id))
        if info then return info.startTime, info.duration, info.isEnabled end
        return nil
    end
    local getCD = (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
    if not getCD then return nil end
    return getCD(id)
end

-- Point GameTooltip at one opaque KCM ID. Used by the flyout, where the entry
-- is a specific candidate rather than "whatever the macro resolves to".
function MD.SetTooltipForID(owner, id)
    if not (GameTooltip and owner and id) then return end
    local ID = KCM.ID
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if ID and ID.IsSpell(id) and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(ID.SpellID(id))
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(id)
    end
    GameTooltip:Show()
end

-- The same three, keyed by macro name (i.e. against whatever the macro
-- currently resolves to) for the main bar buttons and the panel drag icon.
function MD.Count(macroName)
    return MD.CountForID(MD.PickID(macroName))
end

function MD.Cooldown(macroName)
    return MD.CooldownForID(MD.PickID(macroName))
end

-- Point GameTooltip at whatever the macro currently resolves to. Item and spell
-- picks get their real in-game tooltip; anything unresolved falls back to the
-- macro name plus its body so the button is never a mystery.
function MD.SetTooltip(owner, macroName)
    if not (GameTooltip and owner) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local id = MD.PickID(macroName)
    local ID = KCM.ID
    if ID and id and ID.IsSpell(id) and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(ID.SpellID(id))
    elseif ID and id and ID.IsItem(id) and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(id)
    else
        GameTooltip:SetText(macroName or "", 1, 0.82, 0)
        local idx = MD.MacroIndex(macroName)
        if idx ~= 0 and GetMacroInfo then
            local _, _, body = GetMacroInfo(idx)
            if body and body ~= "" then
                GameTooltip:AddLine(body, 1, 1, 1, true)
            end
        end
    end
    GameTooltip:Show()
end
