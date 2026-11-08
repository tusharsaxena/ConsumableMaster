-- SeedProbeStore.lua -- the seed probe's store and the record it keeps per item.
--
-- The seed probe (`/cm probe seed ...`, core/SeedProbe.lua) captures everything
-- needed to build the seed lists (defaults/Defaults_*.lua) from a live client, on
-- Retail and on WoW Forever, into ITS OWN SavedVariables global,
-- ConsumableMasterProbeDB. That third global is an accepted deviation from
-- toc-file-§2 and savedvariables-§4 (docs/ARCHITECTURE.md, Documented deviations;
-- the owner's ruling of 2026-11-08). It is never AceDB's: nothing here touches
-- ConsumableMasterDB, the macros or the picks, and a profile copy, reset or switch
-- never reaches it. The record shape is written up in docs/seed-probe.md.
--
-- This file is the half with no events and no timers: the store, the capture of
-- one item into its record, and the merge of one source into it. Everything that
-- decides WHEN to capture is core/SeedProbe.lua's.
--
-- Every client value goes through `clean` before it is kept: a secret value
-- (Midnight, events-frames-taint-§8) cannot be compared, concatenated or saved, so
-- it is dropped rather than stored.

local _, NS = ...
local KCM = NS
KCM.SeedProbe = KCM.SeedProbe or {}
local SP = KCM.SeedProbe

SP.SCHEMA_VERSION = 1

local function isSecret(v)
    return KCM.Compat and KCM.Compat.IsSecret and KCM.Compat.IsSecret(v) or false
end

-- A client value the store may keep: nil for a secret.
local function clean(v)
    if v == nil or isSecret(v) then return nil end
    return v
end
SP.Clean = clean

local function now()
    return time and time() or 0
end
SP.Now = now

-- The store, built on first use. Defensive on every field, because the file is
-- hand-editable and a broken one must not take the probe down with it.
function SP.Store()
    local db = ConsumableMasterProbeDB
    if type(db) ~= "table" then
        db = { schemaVersion = SP.SCHEMA_VERSION, items = {} }
        ConsumableMasterProbeDB = db
    end
    if type(db.items) ~= "table" then db.items = {} end
    db.schemaVersion = db.schemaVersion or SP.SCHEMA_VERSION
    return db
end

-- Called from KCM:OnInitialize (core/ConsumableMaster.lua), the first moment the
-- client has read the SavedVariables file.
SP.InitStore = SP.Store

function SP.Count()
    local n = 0
    for _ in pairs(SP.Store().items) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Capture: one item into its record
-- ---------------------------------------------------------------------------

-- A plain copy of the parsed tooltip entry, never a reference into
-- core/TooltipCache.lua's session cache. Bounded, and drops what a SavedVariables
-- file cannot hold.
local function copyPlain(value, depth)
    if type(value) ~= "table" then
        local tv = type(value)
        if tv == "function" or tv == "userdata" or tv == "thread" then return nil end
        return clean(value)
    end
    if depth > 4 then return nil end
    local out = {}
    for k, v in pairs(value) do
        local ck = clean(k)
        if ck ~= nil then out[ck] = copyPlain(v, depth + 1) end
    end
    return out
end
SP.CopyPlain = function(value) return copyPlain(value, 1) end

local function set(rec, field, value)
    value = clean(value)
    if value ~= nil then rec[field] = value end
end

local function captureBuild(rec)
    local C = KCM.Compat
    rec.client = (C and C.ClientKey and C.ClientKey()) or KCM.SEED_CLIENT
    if GetBuildInfo then
        local version, build, _, interface = GetBuildInfo()
        set(rec, "version", version)
        set(rec, "build", build)
        set(rec, "interface", interface)
    end
end

-- GetItemInfoInstant answers from the client's own files, so these fields are
-- there even for an item the server has not sent yet.
local function captureInstant(rec, id)
    if not (C_Item and C_Item.GetItemInfoInstant) then return end
    local _, iType, iSubType, equipLoc, icon, classID, subClassID = C_Item.GetItemInfoInstant(id)
    set(rec, "type", iType)
    set(rec, "subType", iSubType)
    set(rec, "equipLoc", equipLoc)
    set(rec, "icon", icon)
    set(rec, "classID", classID)
    set(rec, "subClassID", subClassID)
end

-- GetItemInfo answers nil until the item has loaded. Answers whether it had.
local function captureInfo(rec, id, link)
    set(rec, "link", link)
    local name, ilink, quality, itemLevel, minLevel, _, _, stackCount, _, _, sellPrice =
        KCM.Compat.GetItemInfo(id)
    name = clean(name)
    if not name then return false end
    rec.name = name
    if not rec.link then set(rec, "link", ilink) end
    set(rec, "quality", quality)
    set(rec, "itemLevel", itemLevel)
    set(rec, "minLevel", minLevel)
    set(rec, "stackCount", stackCount)
    set(rec, "sellPrice", sellPrice)
    return true
end

local function captureSpell(rec, id)
    if not (C_Item and C_Item.GetItemSpell) then return end
    local spellName, spellID = C_Item.GetItemSpell(id)
    set(rec, "spellName", spellName)
    set(rec, "spellID", spellID)
    spellID = clean(spellID)
    if spellID and C_Spell and C_Spell.GetSpellDescription then
        local text = clean(C_Spell.GetSpellDescription(spellID))
        if text and text ~= "" then rec.spellDescription = text end
    end
end

-- The raw tooltip, the ground truth the parse is read against. Kept only when the
-- client answered lines, so a cold read never wipes a warm one.
local function captureTooltipLines(rec, id)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return false end
    local data = C_TooltipInfo.GetItemByID(id)
    local lines = data and data.lines
    if type(lines) ~= "table" or #lines == 0 then return false end
    local out = {}
    for i, line in ipairs(lines) do
        local left, right = clean(line.leftText), clean(line.rightText)
        out[i] = { left = left or "" }
        if right and right ~= "" then out[i].right = right end
    end
    rec.tooltip = out
    return true
end

-- What the addon itself makes of the item today: the parsed entry
-- (TooltipCache.Get, copied), the usability verdict `/cm dump item` prints, and
-- the categories the Classifier claims it for.
--
-- `loaded` says the item's data is all there (a name and tooltip lines). The
-- cache still answers pending for such an item when its tooltip parses to no
-- effect (TooltipCache's partial-tooltip guard: a Craftsman's Writ, wrapping
-- paper, an Iron Shield Spike). For the probe that is a finished read, not a
-- loading one: the record keeps `parsed = nil` and `noEffect = true`, and is
-- complete. A read that has not loaded leaves an earlier parse alone.
local function captureParse(rec, id, loaded)
    local TC = KCM.TooltipCache
    local entry = TC and TC.Get and TC.Get(id)
    if entry and not entry.pending then
        rec.parsed = SP.CopyPlain(entry)
        rec.noEffect = nil
        local ok, reason = TC.IsUsableByPlayer(id)
        rec.usable = ok and true or false
        rec.unusableReason = (not ok) and clean(reason) or nil
    elseif loaded then
        rec.parsed, rec.usable, rec.unusableReason = nil, nil, nil
        rec.noEffect = true
    end
    local hits = KCM.Classifier and KCM.Classifier.MatchAny and KCM.Classifier.MatchAny(id) or {}
    local classified = {}
    for i, key in ipairs(hits) do classified[i] = key end
    rec.classified = classified
end

local function captureSeenBy(rec)
    local seen = {}
    if KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
        local classID, specID, specKey = KCM.SpecHelper.GetCurrent()
        seen.classID, seen.specID, seen.specKey = clean(classID), clean(specID), clean(specKey)
    end
    seen.level = clean(UnitLevel and UnitLevel("player"))
    rec.seenBy = seen
end

--- Capture item `id` into its record, creating it on first sight. A later capture
--- refreshes the identity, instant, use-effect, tooltip and classifier fields and
--- leaves the sources alone (SP.MergeSource adds to them).
--- Answers the record and whether it is complete: the item had loaded (a
--- GetItemInfo name) and the client answered tooltip lines. A tooltip that loaded
--- but parses to nothing is complete (captureParse). An incomplete record carries
--- `pending = true` until a later capture completes it.
function SP.Capture(id, link)
    local items = SP.Store().items
    local rec = items[id]
    if not rec then
        rec = { id = id, firstSeen = now(), sources = {} }
        items[id] = rec
    end
    rec.id = id
    captureBuild(rec)
    captureInstant(rec, id)
    local loaded = captureInfo(rec, id, link)
    captureSpell(rec, id)
    local hasLines = captureTooltipLines(rec, id)
    local complete = loaded and hasLines
    captureParse(rec, id, complete)
    captureSeenBy(rec)
    rec.lastSeen = now()
    rec.pending = (not complete) or nil
    return rec, complete
end

-- ---------------------------------------------------------------------------
-- Sources, merged across probes
-- ---------------------------------------------------------------------------

-- Each merge takes the source's current row (nil on first sight) and answers the
-- new one.
local MERGE = {}

function MERGE.mouseover(prev)
    local row = prev or { count = 0 }
    row.count = (row.count or 0) + 1
    row.last = now()
    return row
end

-- One row per vendor NPC; a later visit to the same vendor replaces its row.
function MERGE.vendor(prev, npcID, data)
    local rows = prev or {}
    data.last = now()
    rows[npcID] = data
    return rows
end

-- The latest scan's listings and lowest unit buyout, and how many scans saw it.
function MERGE.auctionhouse(prev, _, data)
    data.scans = ((prev and prev.scans) or 0) + 1
    data.lastScan = now()
    return data
end

--- Merge one source into a record: `kind` is mouseover, vendor or auctionhouse
--- (the `auction` verb's data key, kept from the store's first schema);
--- `key` is the vendor's NPC ID; `data` is the source's row.
function SP.MergeSource(rec, kind, key, data)
    local merge = MERGE[kind]
    if not merge then return end
    rec.sources = rec.sources or {}
    rec.sources[kind] = merge(rec.sources[kind], key, data)
end
