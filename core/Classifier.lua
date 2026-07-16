-- Classifier.lua — Per-category match predicates.
--
-- Given an itemID, decide which of the 11 managed categories (if any) it
-- belongs to. Used by:
--   * Selector (M5) — auto-discover bag items and slot them into categories.
--   * SlashCommands (/cm dump / /cm rank) — debug introspection.
--
-- Every predicate reads from TooltipCache (parsed tooltip) plus the numeric
-- classID / subClassID from GetItemInfoInstant (Consumable=0; subclass
-- Potion=1, Flask/Phial=3, Food & Drink=5). Those numbers are
-- locale-independent, so the category gate works on every client; the item's
-- subType DISPLAY string is localized and is deliberately NOT matched (Ka0s
-- Standard localization-§4). Healthstones are identified by hard-coded itemIDs
-- because they share the Potion subclass with everything else.
--
-- NOTE: the remaining English dependency is TooltipCache's tooltip-TEXT
-- parsing (heal/mana/stat magnitudes, the "Augment Rune" marker, weapon-
-- application effect). That is the addon's tracked English-only deviation
-- (docs/scope.md); this classifier no longer contributes to it.

local _, NS = ...
local KCM = NS
KCM.Classifier = KCM.Classifier or {}
local C = KCM.Classifier

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

-- Consumable subclasses. GetItemInfoInstant returns a locale-independent
-- numeric classID / subClassID alongside the item's subType DISPLAY string.
-- The display string is localized ("Potions" → "Tränke"/"Pociones"/…), so
-- matching it against English literals only works on an enUS client (Ka0s
-- Standard localization-§4 / anti-pattern #37). We key on the numbers instead.
-- classID 0 = Consumable; subclass 1 = Potion, 3 = Flask/Phial, 5 = Food & Drink.
local CLASS_CONSUMABLE = 0
local SC_POTION    = 1
local SC_FLASK     = 3
local SC_FOODDRINK = 5

-- Healthstones look like potions subtype-wise but are always warlock-only.
-- Kept as a whitelist rather than a rule so classification stays O(1).
local HEALTHSTONE_IDS = {
    [5512]   = true,  -- Classic healthstone (legacy fallback)
    [224464] = true,  -- Modern healthstone (auto-scales with warlock level)
}

-- Vantus runes share a generic subType, so match by itemID like healthstones.
-- One universal rune per raid tier; keep in sync with Defaults_Vantus.lua.
local VANTUS_IDS = {
    [245880] = true,  -- Vantus Rune: Radiant
}

-- Augment runes carry an "Augment Rune" tooltip marker (tt.isAugmentRune),
-- so match by tooltip like weapon enhancements — this auto-discovers future
-- runes. Reusable ("permanent") runes are NOT tooltip-distinguishable, so
-- they're an explicit set, mirroring VANTUS_IDS. Keep in sync with
-- Defaults_AugRune.lua.
local REUSABLE_AUG_IDS = {
    [243191] = true,  -- Ethereal Augment Rune        (TWW 11.2)
    [211495] = true,  -- Dreambound Augment Rune      (DF 10.2)
    [190384] = true,  -- Eternal Augment Rune         (SL 9.2)
    [174906] = true,  -- Lightning-Forged Augment Rune (BfA 8.3)
    [153023] = true,  -- Lightforged Augment Rune     (Legion 7.3)
}

-- Combat potions have a short buff (≤60s). Flasks/elixirs run for minutes
-- to hours. This threshold separates "use-in-fight" from "pre-buff".
local CMBT_POT_MAX_DURATION = 60

-- ---------------------------------------------------------------------------
-- Tooltip helpers
-- ---------------------------------------------------------------------------

local function hasHeal(tt)
    return (tt.healValue and tt.healValue > 0)
        or (tt.healValueAvg and tt.healValueAvg > 0)
        or (tt.healPct and tt.healPct > 0)
end

local function hasMana(tt)
    return (tt.manaValue and tt.manaValue > 0)
        or (tt.manaValueAvg and tt.manaValueAvg > 0)
        or (tt.manaPct and tt.manaPct > 0)
end

-- ---------------------------------------------------------------------------
-- Matchers — keyed by category key (uppercase, matches Categories.LIST).
-- Signature: (itemID, tt, sub) -> boolean, where `sub` is the item's
-- consumable subClassID (or nil if the item isn't a Consumable).
-- ---------------------------------------------------------------------------

local matchers = {
    FOOD = function(_, tt, sub)
        return sub == SC_FOODDRINK and hasHeal(tt) and not tt.hasStatBuff
    end,
    DRINK = function(_, tt, sub)
        return sub == SC_FOODDRINK and hasMana(tt) and not tt.hasStatBuff
    end,
    STAT_FOOD = function(_, tt, sub)
        return sub == SC_FOODDRINK and tt.hasStatBuff and not tt.isFeast
    end,
    HP_POT = function(_, tt, sub)
        return sub == SC_POTION and hasHeal(tt) and not tt.hasStatBuff
    end,
    MP_POT = function(_, tt, sub)
        return sub == SC_POTION and hasMana(tt) and not tt.hasStatBuff
    end,
    HS = function(itemID)
        return HEALTHSTONE_IDS[itemID] == true
    end,
    -- Combat potion = Potion subtype + short buff + not healing/mana. We
    -- deliberately do NOT require `hasStatBuff`: Midnight potions like
    -- "Potion of Recklessness" describe their effect as "increases damage
    -- dealt" rather than a stat rating, so the tooltip stat parser finds
    -- nothing. Any short-duration Potion that doesn't restore HP/mana is a
    -- combat potion by elimination.
    CMBT_POT = function(_, tt, sub)
        return sub == SC_POTION
           and not hasHeal(tt)
           and not hasMana(tt)
           and (tt.buffDurationSec or 0) > 0
           and tt.buffDurationSec <= CMBT_POT_MAX_DURATION
    end,
    FLASK = function(_, _, sub)
        return sub == SC_FLASK
    end,
    -- Weapon enhancements (oils, whetstones, weightstones) all report subclass
    -- 8 (classID 0 / "Other"), a catch-all too broad to key on. They
    -- are identified by the tooltip's weapon-application effect — "Coat your
    -- weapon", "Sharpens your bladed weapon", "Weights your … weapon" — captured
    -- as tt.isWeaponEnhance by TooltipCache. Covers stat and proc effects.
    WPN_ENCH = function(_, tt)
        return tt and tt.isWeaponEnhance == true
    end,
    AUG_RUNE = function(_, tt)
        return tt and tt.isAugmentRune == true
    end,
    VANTUS = function(itemID)
        return VANTUS_IDS[itemID] == true
    end,
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- HS matches by itemID alone — returns true even before tooltip data loads.
-- Useful because the auto-discovery pass wants to pick up healthstones the
-- moment they land in bags.
local function isHealthstone(itemID)
    return HEALTHSTONE_IDS[itemID] == true
end

function C.Match(catKey, itemID)
    if not catKey or not itemID then return false end
    local fn = matchers[catKey]
    if not fn then return false end

    if catKey == "HS" then
        return isHealthstone(itemID)
    end
    if catKey == "VANTUS" then
        return VANTUS_IDS[itemID] == true
    end

    -- GetItemInfoInstant is synchronous and returns the item's numeric
    -- classID / subClassID from the client's item DB without waiting on a
    -- server round-trip. GetItemInfo would work too (its classID/subClassID
    -- are the 12th/13th returns), but can briefly return nil for items whose
    -- full metadata hasn't arrived yet — and discovery runs on
    -- PLAYER_ENTERING_WORLD when that race is live. We key on the numbers, not
    -- the localized subType display string (localization-§4).
    local classID, subClassID
    if C_Item and C_Item.GetItemInfoInstant then
        local _
        _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    else
        local _
        _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemID)
    end
    if not classID then return false end
    -- subClassID is only meaningful within its classID (Armor subclass 6 is a
    -- Shield; Weapon subclass 6 is a Polearm), so scope it: the consumable
    -- matchers see the subClassID only for a Consumable, nil otherwise.
    local sub = (classID == CLASS_CONSUMABLE) and subClassID or nil

    -- FLASK classification reads the subclass only, so skip the tooltip gate.
    -- On /reload, C_TooltipInfo.GetItemByID can return empty lines for
    -- seconds even after GetItemInfoInstant already resolves the class, and
    -- GET_ITEM_INFO_RECEIVED does not fire for items the client already
    -- had cached — so the bulk PEW / BAG_UPDATE_DELAYED passes would both
    -- skip the item and never retry. Classifying on the subclass alone makes
    -- FLASK discovery deterministic on the first bag scan. WPN_ENCH can't use
    -- this shortcut — its subclass 8 ("Other") is uninformative — so it flows
    -- to the tooltip-gated path below and hydrates through the same retry seam.
    if catKey == "FLASK" then
        return fn(itemID, nil, sub) == true
    end

    local tt = KCM.TooltipCache and KCM.TooltipCache.Get(itemID)
    if not tt or tt.pending then return false end

    return fn(itemID, tt, sub) == true
end

function C.MatchAny(itemID)
    local hits = {}
    if not itemID or not KCM.Categories or not KCM.Categories.LIST then
        return hits
    end
    -- Composite categories (HP_AIO, MP_AIO) compose other categories' picks
    -- and don't have matchers; skipping them avoids a wasted C.Match per
    -- bag item per discovery pass.
    for _, cat in ipairs(KCM.Categories.LIST) do
        if not cat.composite and C.Match(cat.key, itemID) then
            table.insert(hits, cat.key)
        end
    end
    return hits
end

-- Reusable augment runes are not consumed on use. The Ranker uses this to
-- break score ties toward the reusable rune. Explicit set — no tooltip signal.
function C.IsReusableAugRune(itemID)
    return REUSABLE_AUG_IDS[itemID] == true
end
