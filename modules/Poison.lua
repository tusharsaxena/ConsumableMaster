-- modules/Poison.lua — the rogue poison category, KCM_POISON (issue #47).
--
-- ONE category key on both clients, TWO models, and the model is data
-- (KCM.POISON_MODEL, defaults/Defaults_Poison.lua, picked once at load by
-- KCM.PerClient), so nothing here asks which client it is on (clients-§3, §5):
--
--   hands   WoW Forever. Poisons are items, applied per weapon hand. Each hand
--           names a FAMILY (categories.POISON.mainHand / offHand); the hand
--           takes the best owned, usable rank of that family, in the category's
--           effective priority (the Ranker orders ranks by required level), and
--           falls back to the best owned poison of any family when it has none.
--           The body is the Weapon Enchant shape, written by
--           MacroManager.SetWeaponEnchantMacro: reused, not forked.
--
--   spells  Retail. A poison is a rogue class spell that coats both weapons. The
--           player orders a Lethal and a Non-lethal list (categories.POISON.lethal /
--           nonLethal, with `enabled` flags); the WANTED set is the first one known
--           lethal (two with Dragon-Tempered Blades) and the first one known
--           non-lethal (two with it), and the macro casts the first wanted poison
--           whose buff is MISSING, lethals first. With every wanted poison up the
--           body is the idle line; with none known (any non-rogue), the empty-state
--           line.
--
-- AURA READS ARE OUT OF COMBAT ONLY. A macro cannot be edited in combat anyway,
-- and an aura read there may be restricted (docs/midnight-quirks.md, the secret
-- family; docs/forever-quirks.md, the aura reader that RAISES): every read goes
-- through pcall and Compat.IsSecret, and an unreadable aura answers "unknown",
-- which keeps the macro as it is. In combat the recompute does not read at all
-- and answers "unchanged". The rebuild triggers are core/ConsumableMaster.lua's:
-- UNIT_AURA (player) and the regen edge through P.AuraChanged, which asks for a
-- recompute only when the next cast actually moved, and TRAIT_CONFIG_UPDATED /
-- the spec and learned-spell events for a talent change.

local _, NS = ...
local KCM = NS
KCM.Poison = KCM.Poison or {}
local P = KCM.Poison

local CAT_KEY = "POISON"
local MAIN_HAND, OFF_HAND = 16, 17

local function model()
    return KCM.POISON_MODEL or {}
end

--- "hands" (WoW Forever), "spells" (Retail) or nil.
function P.Model()
    return model().kind
end

local function bucket()
    local cats = KCM.db and KCM.db.profile and KCM.db.profile.categories
    return cats and cats[CAT_KEY] or nil
end

local function isSpell(id) return KCM.ID and KCM.ID.IsSpell(id) end

local function available(id)
    local S = KCM.Selector
    return (S and S.IsAvailable and S.IsAvailable(id)) and true or false
end

local function effectivePriority(scoreCache)
    local S = KCM.Selector
    return (S and S.GetEffectivePriority and S.GetEffectivePriority(CAT_KEY, nil, scoreCache)) or {}
end

-- ---------------------------------------------------------------------------
-- Families
-- ---------------------------------------------------------------------------

-- A discovered rank the seed does not name takes its family from its name. English, like every
-- other tooltip-text read in this addon (docs/ARCHITECTURE.md's localization-§4 deviation).
local NAME_FAMILIES = {
    { "^instant poison",      "INSTANT" },
    { "^deadly poison",       "DEADLY" },
    { "^crippling poison",    "CRIPPLING" },
    { "^mind%-numbing poison", "MINDNUMBING" },
    { "^wound poison",        "WOUND" },
}

local function nameOf(id)
    local tt = KCM.TooltipCache and KCM.TooltipCache.Get(id)
    local name = tt and tt.itemName
    if not name and KCM.Compat and KCM.Compat.GetItemInfo then name = KCM.Compat.GetItemInfo(id) end
    return type(name) == "string" and name or nil
end

--- The family token of a poison entry: the seed's, else the item name's, else nil.
function P.FamilyOf(id)
    local seeded = KCM.SEED and KCM.SEED.POISON_FAMILY and KCM.SEED.POISON_FAMILY[id]
    if seeded then return seeded end
    if not id or isSpell(id) then return nil end
    local name = nameOf(id)
    if not name then return nil end
    local low = name:lower()
    for _, row in ipairs(NAME_FAMILIES) do
        if low:find(row[1]) then return row[2] end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- hands (WoW Forever)
-- ---------------------------------------------------------------------------

--- The family a hand is set to: the stored choice, else the shipped default.
function P.HandFamily(slot)
    local b = bucket()
    local field = (slot == OFF_HAND) and "offHand" or "mainHand"
    local stored = b and b[field]
    if stored then return stored end
    local d = KCM.dbDefaults and KCM.dbDefaults.profile and KCM.dbDefaults.profile.categories
    d = d and d[CAT_KEY]
    return d and d[field] or nil
end

--- The poison a weapon hand takes: the best owned rank of its family, else the best owned poison
--- of any family, else nil. nil for a hand that holds no weapon (core/WeaponSlots.lua's nil).
function P.PickForHand(slot, scoreCache)
    local WS = KCM.WeaponSlots
    if not (WS and WS.SlotAffinity and WS.SlotAffinity(slot)) then return nil end
    local family = P.HandFamily(slot)
    local fallback
    for _, id in ipairs(effectivePriority(scoreCache)) do
        if not isSpell(id) and available(id) then
            if P.FamilyOf(id) == family then return id end
            fallback = fallback or id
        end
    end
    return fallback
end

local function handPicks(scoreCache)
    return P.PickForHand(MAIN_HAND, scoreCache), P.PickForHand(OFF_HAND, scoreCache)
end
P.HandPicks = handPicks

-- ---------------------------------------------------------------------------
-- spells (Retail)
-- ---------------------------------------------------------------------------

-- token -> spell sentinel, from the seed's family map (the one place the IDs are written).
local function spellOf(token)
    for id, fam in pairs((KCM.SEED and KCM.SEED.POISON_FAMILY) or {}) do
        if fam == token and isSpell(id) then return id end
    end
    return nil
end
P.SpellOf = spellOf

-- How many of each kind a rogue may keep: two with Dragon-Tempered Blades, else one.
local function perKind()
    local talent = model().doubleTalent
    if talent and IsPlayerSpell and IsPlayerSpell(talent) then return 2 end
    return 1
end

-- The first `limit` tokens of a stored order that are enabled and known.
local function wantedFrom(order, enabled, limit, out)
    local taken = 0
    for _, token in ipairs(order or {}) do
        if taken >= limit then return end
        local id = spellOf(token)
        if id and enabled[token] ~= false and available(id) then
            out[#out + 1] = id
            taken = taken + 1
        end
    end
end

--- The poison spells the macro keeps up, in the order it applies them: the wanted lethals, then
--- the wanted non-lethals. Empty for a character that knows none (any non-rogue).
function P.Wanted()
    local b = bucket() or {}
    local m = model()
    local enabled = b.enabled or {}
    local limit = perKind()
    local out = {}
    wantedFrom(b.lethal or m.lethal, enabled, limit, out)
    wantedFrom(b.nonLethal or m.nonLethal, enabled, limit, out)
    return out
end

-- true: the buff is up; false: it is not; nil: it cannot be read now (combat, a secret, an API
-- that raised or is missing). Out of combat only.
local function buffUp(spellID)
    if InCombatLockdown and InCombatLockdown() then return nil end
    local auras = C_UnitAuras
    local get = auras and auras.GetPlayerAuraBySpellID
    if not get then return nil end
    local ok, aura = pcall(get, spellID)
    if not ok then return nil end
    local C = KCM.Compat
    if C and C.IsSecret and C.IsSecret(aura) then return nil end
    return aura ~= nil
end

--- What the Retail macro should do now: (spell sentinel, "cast"), (nil, "idle") when every wanted
--- poison is up, (nil, "none") when there is nothing to want, (nil, "unknown") when a buff cannot
--- be read (in combat, or a restricted read), which leaves the macro as it is.
function P.NextCast()
    local wanted = P.Wanted()
    if #wanted == 0 then return nil, "none" end
    for _, id in ipairs(wanted) do
        local up = buffUp(KCM.ID.SpellID(id))
        if up == nil then return nil, "unknown" end
        if not up then return id, "cast" end
    end
    return nil, "idle"
end

-- The last answer the macro was built from: so an aura event that does not move it costs no pass,
-- and so a pass in combat can re-say it without reading an aura.
local lastState, lastPick, lastKind

local function stateKey(pick, state)
    return tostring(state) .. ":" .. tostring(pick)
end

--- Has the Retail macro's next cast moved since it was last built? Out of combat only; false on
--- WoW Forever, whose body does not depend on what is applied. The event layer asks this on
--- UNIT_AURA (player) and on the regen edge, and requests a recompute only on true.
function P.AuraChanged()
    if P.Model() ~= "spells" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local pick, state = P.NextCast()
    if state == "unknown" then return false end
    return stateKey(pick, state) ~= lastState
end

-- ---------------------------------------------------------------------------
-- The pipeline's entry, and the flyout's
-- ---------------------------------------------------------------------------

local function recomputeHands(cat, scoreCache)
    local MM = KCM.MacroManager
    local mh, oh = handPicks(scoreCache)
    return MM.SetWeaponEnchantMacro(cat, mh, oh)
end

local function recomputeSpells(cat)
    -- No aura read in combat. The pass re-says the last answer instead, so a forced rewrite
    -- (MacroManager.MarkAllStale) still queues this macro with the rest; before any answer it
    -- leaves the macro as it is. The regen edge (P.AuraChanged) asks for the pass that catches up.
    local pick, state = lastPick, lastKind
    if not (InCombatLockdown and InCombatLockdown()) then
        pick, state = P.NextCast()
        if state ~= "unknown" then
            lastState, lastPick, lastKind = stateKey(pick, state), pick, state
        end
    end
    if state == nil or state == "unknown" then return "unchanged" end
    return KCM.MacroManager.SetPoisonMacro(cat, pick, state == "idle")
end

--- Core.Pipeline's call for a `poison` category (core/ConsumableMaster.lua, RecomputeOne).
function P.Recompute(cat, scoreCache)
    if not (cat and KCM.MacroManager) then return nil end
    local kind = P.Model()
    if kind == "hands" then return recomputeHands(cat, scoreCache) end
    if kind == "spells" then return recomputeSpells(cat) end
    return KCM.MacroManager.SetMacro(cat.macroName, nil, cat.key)
end

local function listHands(scoreCache)
    local out = {}
    local WS = KCM.WeaponSlots
    local armed = WS and WS.SlotAffinity and (WS.SlotAffinity(MAIN_HAND) or WS.SlotAffinity(OFF_HAND))
    if not armed then return out end
    for _, id in ipairs(effectivePriority(scoreCache)) do
        if not isSpell(id) and available(id) then out[#out + 1] = id end
    end
    return out
end

local function listSpells()
    local b, m = bucket() or {}, model()
    local enabled, out = b.enabled or {}, {}
    for _, order in ipairs({ b.lethal or m.lethal or {}, b.nonLethal or m.nonLethal or {} }) do
        for _, token in ipairs(order) do
            local id = spellOf(token)
            if id and enabled[token] ~= false and available(id) then out[#out + 1] = id end
        end
    end
    return out
end

--- Every poison the macro bar's flyout offers: Forever's owned poisons (with a weapon equipped),
--- Retail's known and enabled poison spells in list order.
function P.ListAvailable(scoreCache)
    local kind = P.Model()
    if kind == "hands" then return listHands(scoreCache) end
    if kind == "spells" then return listSpells() end
    return {}
end

-- ---------------------------------------------------------------------------
-- `/cm dump pick poison`
-- ---------------------------------------------------------------------------

local function entryName(id)
    if not id then return "-" end
    if isSpell(id) then
        local name = KCM.Compat and KCM.Compat.GetSpellName and KCM.Compat.GetSpellName(KCM.ID.SpellID(id))
        return ("spell:%d %s"):format(KCM.ID.SpellID(id), tostring(name or "?"))
    end
    return ("%d %s"):format(id, tostring(nameOf(id) or "?"))
end

local function handLines(out)
    for _, hand in ipairs({ { MAIN_HAND, "main hand" }, { OFF_HAND, "off hand" } }) do
        out[#out + 1] = ("  %s: family %s -> %s"):format(hand[2], tostring(P.HandFamily(hand[1])),
            entryName(P.PickForHand(hand[1])))
    end
end

local function spellLines(out)
    local names = {}
    for i, id in ipairs(P.Wanted()) do names[i] = entryName(id) end
    out[#out + 1] = ("  wanted (%d of each kind): %s"):format(perKind(),
        #names > 0 and table.concat(names, ", ") or "none")
    local pick, state = P.NextCast()
    out[#out + 1] = ("  next: %s (%s)"):format(entryName(pick), state)
end

--- The poison report's own lines: each hand's family and pick (Forever), or the wanted spells
--- and the next cast (Retail).
function P.DumpLines()
    local out = { ("  poison model: %s"):format(tostring(P.Model())) }
    local kind = P.Model()
    if kind == "hands" then handLines(out) elseif kind == "spells" then spellLines(out) end
    return out
end

-- Test seam: forget the last-built state, as a /reload does.
function P._ResetState() lastState, lastPick, lastKind = nil, nil, nil end
