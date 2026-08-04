-- Selector.lua — candidate-set construction, effective priority, and best-owned
-- item picking. Pure over (KCM.SEED, KCM.db.profile.categories, bag state,
-- optional ranking ctx). No Blizzard protected APIs; safe to call in combat.
--
-- Backing data model (see TECHNICAL_DESIGN §4):
--   seed[cat]      : flat array of itemIDs in KCM.SEED[catKey]
--   added[cat]     : set  KCM.db.profile.categories[cat].added[itemID] = true
--   blocked[cat]   : set  KCM.db.profile.categories[cat].blocked[itemID] = true
--   discovered[cat]: map  KCM.db.profile.categories[cat].discovered[itemID] = unixTimestamp
--                    (v1.0.0 stored `true`; reader treats both as "present")
--   pins[cat]      : array of { itemID = X, position = N }
--
-- Spec-aware categories (STAT_FOOD, CMBT_POT, FLASK, WPN_ENCH) swap the four fields for
-- a bySpec[<classID>_<specID>] sub-table holding the same shape.

local _, NS = ...
local KCM = NS
KCM.Selector = KCM.Selector or {}
local S = KCM.Selector

-- ---------------------------------------------------------------------------
-- Bucket resolution
-- ---------------------------------------------------------------------------
-- Returns the { added, blocked, pins, discovered } table for `catKey`, lazily
-- initializing the spec sub-table for spec-aware categories. `specKey`
-- defaults to the current spec for spec-aware categories; ignored for
-- non-spec-aware categories.
--
-- Returns nil if the category doesn't exist or if a spec-aware category is
-- asked for with no resolvable spec (e.g. low-level character under level 10).

local BUCKET_FIELDS = { "added", "blocked", "pins", "discovered" }

local function emptyBucket()
    return { added = {}, blocked = {}, pins = {}, discovered = {} }
end

-- AceDB defaults guarantee these fields exist, but be defensive. Fills them on
-- the LIVE table and returns it — callers mutate the bucket in place, so this
-- must never hand back a copy.
local function ensureBucketFields(t)
    for _, f in ipairs(BUCKET_FIELDS) do
        t[f] = t[f] or {}
    end
    return t
end

-- The category row and its saved-variables root, or nil when either is missing.
local function categoryRoot(catKey)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    if not cat then return nil end
    local root = KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[catKey]
    if not root then return nil end
    return cat, root
end

-- The caller's spec key, or the character's current one. nil when no spec can
-- be resolved (e.g. a character under level 10).
local function currentSpecKey(specKey)
    if specKey then return specKey end
    if KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
        local _, _, key = KCM.SpecHelper.GetCurrent()
        return key
    end
    return nil
end

function S.GetBucket(catKey, specKey)
    local cat, root = categoryRoot(catKey)
    if not cat then return nil end

    if not cat.specAware then
        return ensureBucketFields(root)
    end

    -- Spec-aware: resolve spec key, lazy-init sub-table.
    specKey = currentSpecKey(specKey)
    if not specKey then return nil end

    root.bySpec = root.bySpec or {}
    local bucket = root.bySpec[specKey]
    if not bucket then
        bucket = emptyBucket()
        root.bySpec[specKey] = bucket
    end
    return ensureBucketFields(bucket)
end

-- ---------------------------------------------------------------------------
-- Candidate set
-- ---------------------------------------------------------------------------
-- Returns an array of itemIDs forming (seed ∪ added ∪ discovered) − blocked.
-- Order inside the returned array is seed-first (stable, by seed order), then
-- added/discovered in numeric order for determinism. Ranking is a separate
-- step — this function's only job is set membership.

function S.BuildCandidateSet(catKey, specKey)
    local bucket = S.GetBucket(catKey, specKey)
    if not bucket then return {} end

    local blocked = bucket.blocked or {}
    local seen = {}
    local result = {}

    local function push(id)
        if not id or blocked[id] or seen[id] then return end
        seen[id] = true
        table.insert(result, id)
    end

    local seed = KCM.SEED and KCM.SEED[catKey] or {}
    for _, id in ipairs(seed) do push(id) end

    local extras = {}
    for id in pairs(bucket.added or {}) do table.insert(extras, id) end
    for id in pairs(bucket.discovered or {}) do
        if not bucket.added or not bucket.added[id] then
            table.insert(extras, id)
        end
    end
    table.sort(extras)
    for _, id in ipairs(extras) do push(id) end

    return result
end

-- ---------------------------------------------------------------------------
-- Pin merge
-- ---------------------------------------------------------------------------
-- See TECHNICAL_DESIGN §5.3. Given an auto-ranked list and a pins array of
-- { itemID, position } entries, produce a final list where each pin lands at
-- its requested 1-based position and non-pinned items fill the remaining
-- slots in auto-rank order.
--
-- Rules:
--   - Pins for items not in the candidate set are ignored (set by autoSet).
--   - If two pins collide on the same position, ties are broken by the order
--     they appear in the pins array (stable).
--   - Positions past the end clamp to the last available slot.

local function mergePins(autoRanked, pins)
    if not pins or #pins == 0 then return autoRanked end

    local autoSet = {}
    for _, id in ipairs(autoRanked) do autoSet[id] = true end

    -- Copy + sort pins by position ascending, dropping any pin whose item
    -- isn't a candidate anymore.
    local active = {}
    for i, p in ipairs(pins) do
        if p.itemID and autoSet[p.itemID] and p.position then
            table.insert(active, { itemID = p.itemID, position = p.position, _order = i })
        end
    end
    if #active == 0 then return autoRanked end
    table.sort(active, function(a, b)
        if a.position == b.position then return a._order < b._order end
        return a.position < b.position
    end)

    -- Strip pinned IDs from autoRanked, preserving order.
    local pinnedSet = {}
    for _, p in ipairs(active) do pinnedSet[p.itemID] = true end
    local rest = {}
    for _, id in ipairs(autoRanked) do
        if not pinnedSet[id] then table.insert(rest, id) end
    end

    -- Interleave: fill slot 1..N, inserting a pin when its position matches,
    -- otherwise the next item from `rest`. Pins whose position overshoots are
    -- appended at the end.
    local result = {}
    local pinIdx, restIdx = 1, 1
    local slot = 1
    while slot <= #autoRanked do
        if pinIdx <= #active and active[pinIdx].position == slot then
            table.insert(result, active[pinIdx].itemID)
            pinIdx = pinIdx + 1
        else
            if restIdx <= #rest then
                table.insert(result, rest[restIdx])
                restIdx = restIdx + 1
            else
                -- ran out of non-pinned items; remaining pins go here.
                break
            end
        end
        slot = slot + 1
    end
    -- Overshoot / leftover pins.
    while pinIdx <= #active do
        table.insert(result, active[pinIdx].itemID)
        pinIdx = pinIdx + 1
    end
    -- Leftover rest (shouldn't happen if autoRanked was the union, but guard).
    while restIdx <= #rest do
        table.insert(result, rest[restIdx])
        restIdx = restIdx + 1
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Effective priority
-- ---------------------------------------------------------------------------
-- Full pipeline: candidate set → Ranker.SortCandidates (spec-aware ctx for
-- STAT_FOOD / CMBT_POT / FLASK / WPN_ENCH) → pin merge. Returns an array of itemIDs
-- ordered by effective rank (best first).

function S.GetEffectivePriority(catKey, specKey, scoreCache)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    if not cat then return {} end

    local bucket = S.GetBucket(catKey, specKey)
    if not bucket then return {} end

    local candidates = S.BuildCandidateSet(catKey, specKey)
    if #candidates == 0 then return {} end

    local ctx
    if cat.specAware and KCM.SpecHelper then
        local key = specKey
        if not key then
            local _, _, cur = KCM.SpecHelper.GetCurrent()
            key = cur
        end
        if key then
            ctx = { specPriority = KCM.SpecHelper.GetStatPriority(key) }
        end
    end

    local sorted = candidates
    if KCM.Ranker and KCM.Ranker.SortCandidates then
        sorted = KCM.Ranker.SortCandidates(catKey, candidates, ctx, scoreCache) or candidates
    end

    return mergePins(sorted, bucket.pins)
end

-- ---------------------------------------------------------------------------
-- Pick best owned
-- ---------------------------------------------------------------------------
-- Walks the effective priority list and returns the first itemID the player
-- has in bags, or nil if none are owned. Bag lookup goes through BagScanner
-- if available, otherwise falls back to C_Item.GetItemCount so the function
-- remains usable in unit tests with a stubbed environment.

-- True when the player's level definitively rules this item out.
--
-- IsUsableByPlayer reports `false, "pending"` for an item whose tooltip hasn't
-- hydrated, and the discovery/recompute passes run during exactly that race —
-- so only a level verdict may drop a candidate. "Don't know yet" keeps it.
local function levelBlocked(id)
    local TC = KCM.TooltipCache
    if not (TC and TC.IsUsableByPlayer) then return false end
    local ok, reason = TC.IsUsableByPlayer(id)
    return (not ok) and reason ~= "pending"
end

-- Spell availability: the spellbook first, then a seed-declared class gate.
--
-- Some seeded abilities are not in the PLAYER's spellbook at all — Primal Rage
-- lives in the hunter pet's — so IsPlayerSpell reports false even for the class
-- that has it. The gate names the class that can cast it; the entry is then
-- available for that class and nobody else. Data, not code: a future
-- pet-granted ability needs only a seed edit.
--
-- UnitClass's SECOND return is the locale-independent class file ("HUNTER");
-- the first is the localized display name and must never be matched.
local function spellAvailable(id)
    local spellID = KCM.ID and KCM.ID.SpellID(id)
    if not spellID then return false end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    local gate = KCM.SEED and KCM.SEED.CLASS_GATE and KCM.SEED.CLASS_GATE[id]
    if not gate then return false end
    local _, classFile = UnitClass("player")
    return classFile == gate
end

function S.PickBestForCategory(catKey, specKey, scoreCache)
    local priority = S.GetEffectivePriority(catKey, specKey, scoreCache)
    if #priority == 0 then return nil end

    local hasItem = KCM.BagScanner and KCM.BagScanner.HasItem
    for _, id in ipairs(priority) do
        if KCM.ID and KCM.ID.IsSpell(id) then
            if spellAvailable(id) then return id end
        elseif hasItem and hasItem(id) and not levelBlocked(id) then
            return id
        end
    end
    return nil
end

-- Best owned enhancement for one weapon slot (16 main / 17 off). Filters the
-- effective priority list to enhancements whose weaponAffinity matches the
-- equipped weapon ("any" always matches); returns nil when the slot holds no
-- enhanceable weapon or the player owns no eligible enhancement.
function S.PickBestForSlot(catKey, slot, scoreCache)
    local affinity = KCM.WeaponSlots and KCM.WeaponSlots.SlotAffinity(slot)
    if not affinity then return nil end
    local hasItem = KCM.BagScanner and KCM.BagScanner.HasItem
    for _, id in ipairs(S.GetEffectivePriority(catKey, nil, scoreCache)) do
        if not (KCM.ID and KCM.ID.IsSpell(id)) then
            local tt  = KCM.TooltipCache and KCM.TooltipCache.Get(id)
            local aff = (tt and tt.weaponAffinity) or "any"
            if (aff == "any" or aff == affinity) and hasItem and hasItem(id) and not levelBlocked(id) then
                return id
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- List every available candidate (macro-bar flyout)
-- ---------------------------------------------------------------------------
-- Same walk as PickBestForCategory, but it collects EVERY owned item / known
-- spell instead of stopping at the first, keeping the effective priority order
-- (top-ranked first). Pure and combat-safe like the rest of this file; the
-- flyout that renders it is the part that has to respect the lockdown.
--
-- Three category shapes, three rules:
--   * single-pick   — the effective priority list, filtered to what's owned.
--   * per-hand      — filtered to enhancements that fit an EQUIPPED weapon
--                     (union of main hand + off hand, deduped, rank order
--                     preserved), so nothing unusable on your current weapons
--                     is ever offered.
--   * composite     — concatenation of each ENABLED sub-category's own list, in
--                     the composite's configured order (in-combat sections
--                     first, then out-of-combat), deduped. An AIO flyout is
--                     therefore the whole health / mana toolkit.

local function isAvailable(id)
    if KCM.ID and KCM.ID.IsSpell(id) then
        return spellAvailable(id)
    end
    local hasItem = KCM.BagScanner and KCM.BagScanner.HasItem
    return (hasItem and hasItem(id) and not levelBlocked(id)) and true or false
end

-- Enhancements that fit either equipped weapon, in rank order without repeats.
local function availableForHands(catKey, scoreCache)
    local out, seen = {}, {}
    local affinities = {}
    for _, slot in ipairs({ 16, 17 }) do
        local aff = KCM.WeaponSlots and KCM.WeaponSlots.SlotAffinity(slot)
        if aff then affinities[aff] = true end
    end
    if not next(affinities) then return out end
    for _, id in ipairs(S.GetEffectivePriority(catKey, nil, scoreCache)) do
        if not (KCM.ID and KCM.ID.IsSpell(id)) and not seen[id] then
            local tt  = KCM.TooltipCache and KCM.TooltipCache.Get(id)
            local aff = (tt and tt.weaponAffinity) or "any"
            if (aff == "any" or affinities[aff]) and isAvailable(id) then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    return out
end

-- Sub-category refs of a composite in body order, honoring the user's
-- enabled / reorder state (same precedence MacroManager uses).
local function compositeRefs(cat)
    local cfg = KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[cat.key]
    local enabled  = (cfg and cfg.enabled) or {}
    local orderIn  = (cfg and cfg.orderInCombat)    or cat.components.inCombat    or {}
    local orderOut = (cfg and cfg.orderOutOfCombat) or cat.components.outOfCombat or {}
    local refs = {}
    for _, list in ipairs({ orderIn, orderOut }) do
        for _, ref in ipairs(list) do
            if enabled[ref] ~= false then refs[#refs + 1] = ref end
        end
    end
    return refs
end

function S.ListAvailable(catKey, specKey, scoreCache)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    if not cat then return {} end

    if cat.composite and cat.components then
        local out, seen = {}, {}
        for _, ref in ipairs(compositeRefs(cat)) do
            for _, id in ipairs(S.ListAvailable(ref, specKey, scoreCache)) do
                if not seen[id] then
                    seen[id] = true
                    out[#out + 1] = id
                end
            end
        end
        return out
    end

    if cat.perHand then
        return availableForHands(catKey, scoreCache)
    end

    local out = {}
    for _, id in ipairs(S.GetEffectivePriority(catKey, specKey, scoreCache)) do
        if isAvailable(id) then out[#out + 1] = id end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- DB-mutating operations
-- ---------------------------------------------------------------------------
-- All mutations go through GetBucket so spec-aware categories land in the
-- correct bySpec[specKey] sub-table. After any mutation we return true on
-- success so callers (Options UI, slash commands) can chain a recompute.
-- Callers are responsible for invoking KCM.Pipeline.RequestRecompute — these
-- functions stay pure with respect to events to keep them unit-testable.

local function findPinIndex(pins, itemID)
    for i, p in ipairs(pins) do
        if p.itemID == itemID then return i end
    end
    return nil
end

-- Normalize pins to 1..N contiguous positions after a move. Input/output
-- order is the display order; positions are rewritten to 1,2,3,... so that
-- subsequent swaps are unambiguous.
local function renumberPins(pins)
    table.sort(pins, function(a, b) return (a.position or 0) < (b.position or 0) end)
    for i, p in ipairs(pins) do p.position = i end
end

-- Add a user-supplied itemID (or spell sentinel via KCM.ID.AsSpell) to the
-- candidate set. Also clears a blocklist entry if present so the add is
-- always visible. Returns true if either the unblock or the add changed
-- state — callers gate recompute on this, so unblocking a previously-blocked
-- item must return true even when `added[itemID]` was already set.
function S.AddItem(catKey, itemID, specKey)
    local bucket = S.GetBucket(catKey, specKey)
    if not bucket or not itemID then return false end
    local changed = false
    if bucket.blocked[itemID] then
        bucket.blocked[itemID] = nil
        changed = true
    end
    if not bucket.added[itemID] then
        bucket.added[itemID] = true
        changed = true
    end
    if changed and KCM.State and KCM.State.debug then
        KCM.Debug("Prio", "add %s id=%s%s", catKey, itemID,
            specKey and (" spec=" .. tostring(specKey)) or "")
    end
    return changed
end

-- Mark an item as blocked so it's excluded from the candidate set. Also drops
-- any matching pin (a blocked item can't be pinned). Returns true if the
-- block flag was newly set.
function S.Block(catKey, itemID, specKey)
    local bucket = S.GetBucket(catKey, specKey)
    if not bucket or not itemID then return false end
    local pinIdx = findPinIndex(bucket.pins, itemID)
    if pinIdx then
        table.remove(bucket.pins, pinIdx)
        renumberPins(bucket.pins)
    end
    if bucket.blocked[itemID] then return false end
    bucket.blocked[itemID] = true
    if KCM.State and KCM.State.debug then
        KCM.Debug("Prio", "block %s id=%s%s", catKey, itemID,
            specKey and (" spec=" .. tostring(specKey)) or "")
    end
    return true
end

-- Record that an item was seen in bags (auto-discovery). Spells can't be
-- bag-discovered; guard anyway. Blocked items are never promoted to
-- discovered (user intent overrides). The stored value is a unix timestamp
-- used by SweepStaleDiscovered's 30-day TTL; legacy `true` values from v1.0.0
-- are overwritten on next sighting. Returns true only when the entry is
-- newly created — timestamp bumps return false so callers don't trigger a
-- spurious UI refresh on every bag scan.
function S.MarkDiscovered(catKey, itemID, specKey, nowUnix)
    local bucket = S.GetBucket(catKey, specKey)
    if not bucket or not itemID then return false end
    if KCM.ID and KCM.ID.IsSpell(itemID) then return false end
    if bucket.blocked[itemID] then return false end
    nowUnix = nowUnix or time()
    local current = bucket.discovered[itemID]
    if current == nil then
        bucket.discovered[itemID] = nowUnix
        return true
    end
    -- Legacy `true` or an older timestamp → bump to now. Idempotent for
    -- already-current entries so we don't dirty SavedVariables every scan.
    if current == true or (type(current) == "number" and current < nowUnix) then
        bucket.discovered[itemID] = nowUnix
    end
    return false
end

-- TTL garbage collection for `discovered` entries. Called from PEW after
-- auto-discovery and before the first recompute (see Core.lua). Items still
-- in bags have their timestamp bumped to now; otherwise entries older than
-- DISCOVERED_TTL_SEC are deleted. `added` and `blocked` are user-intentional
-- and never touched here.
local DISCOVERED_TTL_SEC = 30 * 86400

-- A discovered entry the classifier would no longer admit. Only a DEFINITE
-- negative counts: Classifier.IsConsumable returns nil while the client is
-- still resolving the item, and the sweep runs inside exactly that load race,
-- so `not IsConsumable(id)` would collect good entries.
--
-- This exists so profiles carrying an entry misfiled before the classID gate
-- self-heal on the next PLAYER_ENTERING_WORLD. The TTL alone never reclaimed
-- them: the item is in bags, so the branch below keeps bumping its timestamp
-- forever.
local function noLongerEligible(id)
    local C = KCM.Classifier
    return C and C.IsConsumable and C.IsConsumable(id) == false
end

local function sweepBucket(bucket, bagCounts, nowUnix, cutoff)
    if not (bucket and bucket.discovered) then return 0 end
    local swept = 0
    for id, value in pairs(bucket.discovered) do
        if noLongerEligible(id) then
            bucket.discovered[id] = nil
            swept = swept + 1
        elseif bagCounts[id] and bagCounts[id] > 0 then
            bucket.discovered[id] = nowUnix
        else
            local staleTs = (value == true) and 0 or (type(value) == "number" and value or 0)
            if staleTs < cutoff then
                bucket.discovered[id] = nil
                swept = swept + 1
            end
        end
    end
    return swept
end

function S.SweepStaleDiscovered(nowUnix)
    if not (KCM.db and KCM.db.profile and KCM.db.profile.categories) then
        return 0, 0
    end
    nowUnix = nowUnix or time()
    local cutoff = nowUnix - DISCOVERED_TTL_SEC
    local bagCounts = (KCM.BagScanner and KCM.BagScanner.Scan and KCM.BagScanner.Scan()) or {}
    local totalSwept, touchedCats = 0, 0
    for _, root in pairs(KCM.db.profile.categories) do
        local catSwept = 0
        if root.bySpec then
            for _, specBucket in pairs(root.bySpec) do
                catSwept = catSwept + sweepBucket(specBucket, bagCounts, nowUnix, cutoff)
            end
        else
            catSwept = catSwept + sweepBucket(root, bagCounts, nowUnix, cutoff)
        end
        if catSwept > 0 then
            totalSwept = totalSwept + catSwept
            touchedCats = touchedCats + 1
        end
    end
    if totalSwept > 0 and KCM.State and KCM.State.debug then
        KCM.Debug("GC", "swept %s entries across %s categories", totalSwept, touchedCats)
    end
    return totalSwept, touchedCats
end

-- Internal helper: given the current effective priority and a direction (-1
-- for up, +1 for down), swap `itemID` with its neighbor by emitting pins at
-- the new positions. If the item isn't in the priority list, no-op.
local function movePinned(catKey, itemID, delta, specKey)
    local bucket = S.GetBucket(catKey, specKey)
    if not bucket or not itemID then return false end

    local priority = S.GetEffectivePriority(catKey, specKey)
    local curIdx
    for i, id in ipairs(priority) do
        if id == itemID then curIdx = i; break end
    end
    if not curIdx then return false end

    local newIdx = curIdx + delta
    if newIdx < 1 or newIdx > #priority then return false end

    -- Strategy: rebuild the pins array as the full re-ordered priority list
    -- with the two affected slots swapped. This is O(N) but N <= ~30 per
    -- category and only runs on explicit user reorder clicks. It guarantees
    -- deterministic behavior regardless of how ranker scores break ties.
    priority[curIdx], priority[newIdx] = priority[newIdx], priority[curIdx]
    local newPins = {}
    for i, id in ipairs(priority) do
        table.insert(newPins, { itemID = id, position = i })
    end
    bucket.pins = newPins
    if KCM.State and KCM.State.debug then
        KCM.Debug("Prio", "%s %s id=%s", delta < 0 and "move-up" or "move-down", catKey, itemID)
    end
    return true
end

function S.MoveUp(catKey, itemID, specKey)
    return movePinned(catKey, itemID, -1, specKey)
end

function S.MoveDown(catKey, itemID, specKey)
    return movePinned(catKey, itemID, 1, specKey)
end
