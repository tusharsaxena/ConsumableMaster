-- TooltipCache.lua — Lazy tooltip parsing + session-scoped cache.
--
-- Retail Midnight uses C_TooltipInfo.GetItemByID(itemID) to fetch structured
-- tooltip data without showing a real tooltip frame. We parse each line's
-- leftText with Lua patterns and also fetch static fields (minLevel, name)
-- from GetItemInfo.
--
-- Entry fields (all optional unless noted):
--   -- Healing / Mana (flat)
--   healValue, healValueAvg        -- HP pots, flat-value food
--   manaValue, manaValueAvg        -- MP pots, flat-value drink
--   -- Healing / Mana (Midnight %-based food & drink)
--   healPct, manaPct               -- % of max per tick (e.g. 7 for "7%")
--   isPctPerSecond                 -- true if "every second" appears alongside pct
--   pctOverDurationSec             -- duration of the % regen (distinct from buff)
--   -- Heal / mana over time (flat HOT pots: "Restores N health over X sec")
--   healOverSec, manaOverSec       -- duration of the flat HOT effect in seconds
--   -- Stat buffs
--   statBuffs = { {stat="MASTERY", amount=935}, ... }
--   hasStatBuff                    -- true if any statBuffs captured
--   -- Metadata
--   buffDurationSec                -- Well-Fed / flask / stat-buff duration
--   isConjured, isFeast, isWeaponEnhance  -- classifier flags
--   isAugmentRune                  -- true if tooltip carries the "Augment Rune" marker
--   weaponAffinity                 -- "bladed" | "blunt" | "any" (weapon enhance only)
--   minLevel                       -- required player level (0 if none)
--   maxLevel                       -- maximum player level the item/effect works at,
--                                     parsed from tooltip text; nil when uncapped
--   itemName                       -- plain name for friendly dumps
--   pending = true                 -- tooltip data not loaded yet; retry later
--
-- When C_TooltipInfo returns nothing yet, the entry is marked `pending` and
-- the itemID is added to a pending set. Core (M5) wires GET_ITEM_INFO_RECEIVED
-- to call Invalidate(itemID) + request a recompute.

local _, NS = ...
local KCM = NS
KCM.TooltipCache = KCM.TooltipCache or {}
local TC = KCM.TooltipCache

-- ---------------------------------------------------------------------------
-- Patterns (English-only per project scope)
-- ---------------------------------------------------------------------------

local PATTERNS = {
    -- Flat heal / mana (legacy / classic)
    healRange = "Restores ([%d,]+) to ([%d,]+) health",
    healFlat  = "Restores ([%d,]+) health",
    manaRange = "Restores ([%d,]+) to ([%d,]+) mana",
    manaFlat  = "Restores ([%d,]+) mana",
    -- Combined flat food-and-drink, e.g. "Restores 35,000 health and 30,000
    -- mana over 20 sec" (Chalcocite Lava Cake). The mana clause is introduced
    -- by "and", not "Restores", so `manaFlat`'s "Restores"-anchored pattern
    -- misses it. The health side is still captured by `healFlat`'s prefix
    -- match; this pattern recovers the mana side so the item classifies as
    -- both Food and Drink.
    manaCombinedFlat = "health and ([%d,]+) mana",

    -- Midnight %-based food/drink. Test combined first because
    -- "...of your maximum health and mana" contains "...of your maximum health"
    -- as a prefix.
    pctCombined = "Restores%s+([%d%.]+)%%%s+of your maximum health and mana",
    pctHealth   = "Restores%s+([%d%.]+)%%%s+of your maximum health",
    pctMana     = "Restores%s+([%d%.]+)%%%s+of your maximum mana",

    -- Flags
    conjuredExact = "^Conjured Item$",
    feastSubstr   = "Feast",
    perSecond     = "every second",
    cooldownSub   = "Cooldown",     -- skip duration parse on cooldown lines

    -- Maximum-level caps. Two real phrasings: the self-restriction ("Cannot be
    -- used by players higher than level 90." — Emergency Soul Link) and the
    -- drums' affect cap ("Does not affect allies above level 50."). Both
    -- reduce to a bare number after a "higher than level" / "above level"
    -- lead-in, so match that much and stay indifferent to the rest of the
    -- sentence.
    maxLevelHigher = "higher than level (%d+)",
    maxLevelAbove  = "above level (%d+)",


    -- Duration tokens (lenient — match "N unit" anywhere in the line so that
    -- phrasings like "for 30 sec", "over 20 sec", "for the next 1 hour",
    -- "for 1 hrs", and "lasts 30 min" all work). `durHr` handles the "hr" /
    -- "hrs" abbreviation Midnight uses; `durHour` still handles the full
    -- word "hour" / "hours" from legacy tooltips. Prefix matching means
    -- "min" / "mins" / "minutes" and "sec" / "secs" / "seconds" all resolve.
    durHour = "([%d,]+)%s+hour",
    durHr   = "([%d,]+)%s+hr",
    durMin  = "([%d,]+)%s+min",
    durSec  = "([%d,]+)%s+sec",
}

-- Stat names in tooltip text → canonical tag used by Ranker + StatPriority.
-- Longest token first to avoid any sub-token shadowing.
local STAT_TOKENS = {
    { token = "Critical Strike", tag = "CRIT"        },
    { token = "Attack Power",    tag = "AP"          },
    { token = "Spell Power",     tag = "SP"          },
    { token = "Primary Stat",    tag = "PRIMARY"     },
    { token = "Versatility",     tag = "VERSATILITY" },
    { token = "Intellect",       tag = "INT"         },
    { token = "Strength",        tag = "STR"         },
    { token = "Mastery",         tag = "MASTERY"     },
    { token = "Agility",         tag = "AGI"         },
    { token = "Haste",           tag = "HASTE"       },
}

local function toNumberCommas(s)
    if not s then return nil end
    return tonumber((s:gsub(",", "")))
end

-- Whether a line carries one of the negation words that both confirmed
-- max-level-cap phrasings use ("Cannot be used by...", "Does not affect...").
-- Required alongside maxLevelHigher/maxLevelAbove — see the comment on those
-- patterns for why a bare "above level N" / "higher than level N" substring
-- is not enough on its own.
local function hasNegation(line)
    return line:find("[Cc]annot ", 1, false) ~= nil
        or line:find("[Dd]oes not ", 1, false) ~= nil
        or line:find("[Cc]an't ", 1, false) ~= nil
        or line:find("[Dd]oesn't ", 1, false) ~= nil
end

-- WoW tooltips can include two things that break naive pattern matching:
--   1. Non-breaking space (U+00A0, bytes 0xC2 0xA0) between number and unit.
--      Lua's %s class does NOT match NBSP, so we normalize it to a space.
--   2. Grammar-number escape "|4<singular>:<plural>;" which the client
--      normally substitutes based on the preceding count — but
--      C_TooltipInfo returns the RAW template. E.g. "for 1 |4hour:hrs;"
--      needs to become "for 1 hrs" so our duration patterns ("[%d,]+%s+hr"
--      etc.) match. We always pick the plural side; both singular and
--      plural forms share the same prefix our patterns care about
--      (hr/min/sec).
local function normalizeTooltipText(s)
    s = s:gsub("\194\160", " ")
    s = s:gsub("|4([^:]-):([^;]-);", "%2")
    return s
end

-- ---------------------------------------------------------------------------
-- Cache state
-- ---------------------------------------------------------------------------

local cache = {}
local pendingIDs = {}

function TC.Invalidate(itemID)
    cache[itemID] = nil
    pendingIDs[itemID] = nil
end

function TC.InvalidateAll()
    cache = {}
    pendingIDs = {}
end

-- ---------------------------------------------------------------------------
-- Line-level parsers
-- ---------------------------------------------------------------------------

local function parseStatBuffs(line, result)
    local seen = {}  -- dedupe per-line per-stat
    for _, entry in ipairs(STAT_TOKENS) do
        if not seen[entry.tag] then
            local tok = entry.token
            local forward = tok .. "[^%d]+([%d,]+)"        -- "Mastery ... 935"
            local reverse = "([%d,]+)%s+" .. tok           -- "935 Mastery"
            local amt = line:match(forward) or line:match(reverse)
            if amt then
                local n = toNumberCommas(amt)
                if n and n > 0 then
                    table.insert(result.statBuffs, { stat = entry.tag, amount = n })
                    result.hasStatBuff = true
                    seen[entry.tag] = true
                end
            end
        end
    end

    -- Wildcard: "<amount> of your highest secondary stat". The stat is
    -- resolved at score time from the active spec's secondary priority, so
    -- we record a synthetic TOP_SECONDARY entry rather than a concrete
    -- stat tag. Ranker.statWeight knows how to weight it.
    local wild = line:match("([%d,]+)%s+of your highest secondary stat")
    if wild then
        local n = toNumberCommas(wild)
        if n and n > 0 then
            table.insert(result.statBuffs, { stat = "TOP_SECONDARY", amount = n })
            result.hasStatBuff = true
        end
    end
end

-- Strip any balanced-parentheses block that mentions "cooldown" (any case).
-- Flask / potion tooltips commonly render buff duration and cooldown on a
-- single line, e.g.
--   "Increase your Critical Strike by 1515 for 1 hour. (3 Sec Cooldown)"
-- If we don't remove the paren block, we either skip the whole line (losing
-- "1 hour") or mis-parse "3 sec" as the buff duration.
local function stripCooldownNotes(line)
    return (line:gsub("%b()", function(group)
        if group:lower():find("cooldown", 1, true) then return "" end
        return group
    end))
end

local function parseDuration(line, result)
    local cleaned = stripCooldownNotes(line)
    -- Any remaining bare "cooldown" (no parens) means this is a standalone
    -- cooldown line — skip it.
    if cleaned:lower():find("cooldown", 1, true) then return end

    local h = cleaned:match(PATTERNS.durHour) or cleaned:match(PATTERNS.durHr)
    if h then
        local n = toNumberCommas(h) * 3600
        -- Prefer the longest duration seen (flasks: 1 hour vs unrelated "30 sec" elsewhere).
        if not result.buffDurationSec or n > result.buffDurationSec then
            result.buffDurationSec = n
        end
        return
    end
    local m = cleaned:match(PATTERNS.durMin)
    if m then
        local n = toNumberCommas(m) * 60
        if not result.buffDurationSec or n > result.buffDurationSec then
            result.buffDurationSec = n
        end
        return
    end
    local s = cleaned:match(PATTERNS.durSec)
    if s then
        local n = toNumberCommas(s)
        -- "over N sec" always indicates channel / regen duration, not a
        -- buff. Keep it out of buffDurationSec; record as pctOverDurationSec
        -- for %-based regen and as healOverSec / manaOverSec for flat-value
        -- HOT pots ("Restores 265,420 health over 20 sec") so the Ranker can
        -- distinguish immediate-heal vs heal-over-time pots.
        if cleaned:find("over ", 1, true) then
            if result.healPct or result.manaPct then
                result.pctOverDurationSec = n
            end
            if result.healValue or result.healValueAvg then
                result.healOverSec = n
            end
            if result.manaValue or result.manaValueAvg then
                result.manaOverSec = n
            end
            return
        end
        if not result.buffDurationSec or n > result.buffDurationSec then
            result.buffDurationSec = n
        end
    end
end

local function parsePctHealth(line, result)
    if line:find(PATTERNS.perSecond, 1, true) then result.isPctPerSecond = true end

    local combined = line:match(PATTERNS.pctCombined)
    if combined then
        local n = tonumber(combined)
        if n then
            result.healPct = n
            result.manaPct = n
        end
        return true
    end

    local h = line:match(PATTERNS.pctHealth)
    if h then
        local n = tonumber(h)
        if n then result.healPct = n end
    end
    local m = line:match(PATTERNS.pctMana)
    if m then
        local n = tonumber(m)
        if n then result.manaPct = n end
    end
    return (h ~= nil) or (m ~= nil)
end

local function parseFlatHeal(line, result)
    local lo, hi = line:match(PATTERNS.healRange)
    if lo then
        local a, b = toNumberCommas(lo), toNumberCommas(hi)
        if a and b then result.healValueAvg = (a + b) / 2 end
        return
    end
    local v = line:match(PATTERNS.healFlat)
    if v then result.healValue = toNumberCommas(v) end
end

local function parseFlatMana(line, result)
    local lo, hi = line:match(PATTERNS.manaRange)
    if lo then
        local a, b = toNumberCommas(lo), toNumberCommas(hi)
        if a and b then result.manaValueAvg = (a + b) / 2 end
        return
    end
    local v = line:match(PATTERNS.manaCombinedFlat) or line:match(PATTERNS.manaFlat)
    if v then result.manaValue = toNumberCommas(v) end
end

local function parseLines(lines)
    local result = { statBuffs = {} }
    for _, line in ipairs(lines) do
        local txt = normalizeTooltipText(line.leftText or "")
        if txt ~= "" then
            local pctHit = parsePctHealth(txt, result)
            if not pctHit then
                -- Only try flat-value patterns if this line didn't express a
                -- percentage form. A combined-pct line contains the word
                -- "health" / "mana" without a preceding flat number anyway,
                -- so this check is belt-and-braces.
                parseFlatHeal(txt, result)
                parseFlatMana(txt, result)
            end

            if txt:match(PATTERNS.conjuredExact) then result.isConjured = true end
            if txt:find(PATTERNS.feastSubstr, 1, true) then result.isFeast = true end

            -- Only accept a captured cap when the same line also carries a
            -- negation word (see hasNegation's comment) — a floor phrased as
            -- "...above level N" without one is not a cap.
            local cap = txt:match(PATTERNS.maxLevelHigher) or txt:match(PATTERNS.maxLevelAbove)
            if cap and hasNegation(txt) then result.maxLevel = tonumber(cap) end

            -- Augment runes carry an "Augment Rune" category tag. In-game it
            -- renders as a sentence at the END of the Use line, e.g.
            --   "Use: Increases Strength by 25 for 1 hrs.  Augment Rune."
            -- and on some items as its own line. Match either the whole line
            -- or the marker sentence at end-of-line (preceded by the period
            -- that closes the Use sentence). The leading period keeps the
            -- item's NAME line — "Ethereal Augment Rune" — from tripping it.
            if txt:match("^Augment Rune%.?%s*$")
                or txt:match("%.%s*Augment Rune%.?%s*$") then
                result.isAugmentRune = true
            end

            -- Temporary weapon enhancement application. Oils "Coat", whetstones
            -- "Sharpen", weightstones "Weight" — the common thread is "your
            -- <weapon>" with an optional weapon adjective ("bladed"/"blunt"/
            -- "two-handed"). Captured on lowercased text (letters/space/hyphen
            -- only, so a comma or clause break stops the run and prevents
            -- over-matching) so the adjective itself can be inspected for
            -- affinity ("bladed" -> whetstone, "blunt" -> weightstone,
            -- anything else -> "any", e.g. plain oils).
            local wmid = txt:lower():match("your ([%a%s%-]-)weapon")
            if wmid then
                result.isWeaponEnhance = true
                if wmid:find("bladed", 1, true) then result.weaponAffinity = "bladed"
                elseif wmid:find("blunt", 1, true) then result.weaponAffinity = "blunt"
                elseif not result.weaponAffinity then result.weaponAffinity = "any" end
            end

            parseDuration(txt, result)
            parseStatBuffs(txt, result)
        end
    end
    return result
end

-- Whether a parsed tooltip carries any recognizable consumable effect. Used
-- to tell a fully-loaded tooltip from one still missing its "Use:" line.
local function hasParsedEffect(p)
    return p.hasStatBuff == true
        or p.healValue ~= nil or p.healValueAvg ~= nil or p.healPct ~= nil
        or p.manaValue ~= nil or p.manaValueAvg ~= nil or p.manaPct ~= nil
        or (p.buffDurationSec or 0) > 0
        or p.isWeaponEnhance == true
        or p.isAugmentRune == true
        or p.isConjured == true
        or p.isFeast == true
        or p.maxLevel ~= nil
end

-- Consumables (classID 0) are the only items expected to carry a "Use:"
-- effect, so only they get held pending on an effectless parse. GetItemInfoInstant
-- is synchronous (client-side) and has existed since Legion; if it is somehow
-- unavailable, assume consumable so a real consumable is never stranded.
local function isConsumableItem(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
        return classID == 0
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Public Get(itemID)
-- ---------------------------------------------------------------------------

function TC.Get(itemID)
    if not itemID then return nil end
    local hit = cache[itemID]
    if hit and not hit.pending then return hit end

    if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then
        local stub = { pending = true, unsupported = true, statBuffs = {} }
        cache[itemID] = stub
        return stub
    end

    local data = C_TooltipInfo.GetItemByID(itemID)
    if not data or not data.lines or #data.lines == 0 then
        local stub = { pending = true, statBuffs = {} }
        cache[itemID] = stub
        pendingIDs[itemID] = true
        return stub
    end

    -- Static item-info fields. We use name + minLevel. If GetItemInfo
    -- returns nil, the item's basic data hasn't loaded yet — and in
    -- practice C_TooltipInfo may also be returning only a partial tooltip
    -- (just the name line, without the Use: effect). Treat that whole
    -- state as pending; on the next call we'll re-fetch and usually get
    -- the full text. Otherwise the Ranker scores the item as if it had
    -- no stat buff / heal value / duration.
    local name, _, _, _, minLevel = GetItemInfo(itemID)
    if not name then
        local stub = { pending = true, statBuffs = {} }
        cache[itemID] = stub
        pendingIDs[itemID] = true
        return stub
    end

    local parsed = parseLines(data.lines)

    -- Partial-tooltip guard. The item's basic info (name) can resolve before
    -- C_TooltipInfo delivers the "Use:" effect line — so a name-only tooltip
    -- parses no effect. Caching that as final would strand the item at score 0
    -- forever: GET_ITEM_INFO_RECEIVED does not re-fire for an item whose basic
    -- info was already cached, so nothing would ever refresh it. For a
    -- Consumable with no parsed effect, stay pending so a later Get() re-parses
    -- once the body arrives. (This was the augment-rune mis-ranking: every rune
    -- read as amount 0, leaving only the reusable bonus to sort them.)
    if not hasParsedEffect(parsed) and isConsumableItem(itemID) then
        local stub = { pending = true, statBuffs = {} }
        cache[itemID] = stub
        pendingIDs[itemID] = true
        return stub
    end

    parsed.itemName = name
    parsed.minLevel = minLevel or 0

    cache[itemID] = parsed
    pendingIDs[itemID] = nil
    return parsed
end

-- ---------------------------------------------------------------------------
-- Usability vs player level
-- ---------------------------------------------------------------------------

function TC.IsUsableByPlayer(itemID)
    local entry = TC.Get(itemID)
    if not entry or entry.pending then return false, "pending" end
    local have = UnitLevel("player") or 0
    local need = entry.minLevel or 0
    if have < need then
        return false, ("level %d < %d"):format(have, need)
    end
    -- Upper bound. Old drums keep working as items but stop affecting anyone
    -- past their expansion's cap, so on a max-level character they are dead
    -- weight the picker must not choose.
    local cap = entry.maxLevel
    if cap and have > cap then
        return false, ("level %d > %d"):format(have, cap)
    end
    return true, nil
end
