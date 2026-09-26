-- core/Diagnostics.lua -- the sections of the diagnostics report (debug-logging-§14, DX-CM).
--
-- `/cm diagnostics` and `/cm debug diagnostics` write one report into the debug
-- console, after whatever trace the player just reproduced, so one Copy carries
-- both. This file is the ConsumableMaster half of it.
--
-- WHAT IS OURS AND WHAT IS NOT. The markers, the identity header (the [Init]
-- summary, the client build, the locale, the logging flag, the two combat reads
-- and the running LibKa0s minors), the per-section pcall, the cap, the escape
-- strip and the append are LibKa0s-DebugLog-1.0's (DebugLogDiagnostics.lua);
-- core/DebugLogSetup.lua hands Sections() to it through the descriptor's
-- `diagnostics` field, at run time. What is here is what only this addon knows:
-- the spec and stat priority, what each category would pick and what its macro
-- actually carries, the combat queue, the macro bar, the tooltip cache, the bags
-- and the client events.
--
-- THE REPORT IS A READ. Nothing below writes the profile, a macro, a frame or a
-- hold: no setter, no Show/Hide, no MacroBar.Update or Refresh, no EditMacro, no
-- Recompute. Three reads the pipeline makes are deliberately NOT made here:
--   * Selector.PickBestForCategory / PickBestForSlot. Their level gate asks
--     TooltipCache.IsUsableByPlayer of entries that may still be pending, which
--     DX-CM rules out. The pick is reported as the macro WROTE it (macroState).
--   * Selector.GetBucket on a spec-aware category with no bucket for the current
--     spec. It creates one in the profile, so a report would write. That case is
--     ranked from the seed list here, which is what GetEffectivePriority would
--     answer for an empty bucket, without the lazy init.
--   * Spell cooldown numbers, which are secret in combat and say nothing a bug
--     report needs.
-- tests/test_diagnostics.lua pins all of it: a stored-tree compare and a spy on
-- every write seam and on the two pick functions.
--
-- The report body is English diagnostic text and does not go through KCM.L, like
-- every trace line (debug-logging-§14); the one chat line the library prints
-- after it is the localizable one.

local _, NS = ...
local KCM = NS

KCM.Diagnostics = KCM.Diagnostics or {}
local Dx = KCM.Diagnostics

-- DX-CM's always-print rows: printed whatever their value, because they are the
-- first things a maintainer asks about a ConsumableMaster bug report and they
-- sit at their defaults on most installs. The minimap row's schema path is
-- `global.minimap.shown` (settings/General.lua), the SHOWN view of the stored
-- `global.minimap.hide`.
local ALWAYS = { "enabled", "macroBar.enabled", "macroBar.locked", "global.minimap.shown" }

-- How much of a category's priority the report prints. DX-CM rules out the full
-- lists: the header counts every entry, and the top five are what decides a pick.
local TOP = 5

-- The account macro cap modules/MacroManager.lua writes against.
local MAX_ACCOUNT_MACROS = 120

local WEAPON_SLOTS = { { 16, "main hand" }, { 17, "off hand" } }

local BAR_NAME = "KCMMacroBar"   -- modules/MacroBar.lua's container frame

-- ---------------------------------------------------------------------------
-- Small readers
-- ---------------------------------------------------------------------------

local function yn(v) return v and "yes" or "no" end

local function profile()
    return KCM.db and KCM.db.profile or {}
end

local function macroStates()
    return profile().macroState or {}
end

local function countKeys(t)
    local n = 0
    for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end
    return n
end

-- Numbers before strings, each in its own order, so a set of ids reads sorted.
local function idLess(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
end

local function isSpell(id)
    return KCM.ID and KCM.ID.IsSpell and KCM.ID.IsSpell(id)
end

-- A priority id as a player would type it: an item id, or `spell:<id>` for the
-- negative spell sentinel.
local function describeId(id)
    if type(id) == "number" and isSpell(id) then
        return "spell:" .. tostring(KCM.ID.SpellID(id))
    end
    return tostring(id)
end

-- The truthy keys of a set-shaped table (`added`, `blocked`), sorted, described.
local function setIds(set)
    local ids = {}
    for id, on in pairs(type(set) == "table" and set or {}) do
        if on then ids[#ids + 1] = id end
    end
    table.sort(ids, idLess)
    for i, id in ipairs(ids) do ids[i] = describeId(id) end
    return ids
end

-- A pins array of { itemID, position } as `id@position`.
local function pinList(pins)
    local out = {}
    for _, p in ipairs(type(pins) == "table" and pins or {}) do
        out[#out + 1] = describeId(p.itemID) .. "@" .. tostring(p.position)
    end
    return out
end

-- ---------------------------------------------------------------------------
-- state: the switch, the latch, the schema and the perf harness
-- ---------------------------------------------------------------------------

local function holds()
    local LC = KCM.Lifecycle
    if not (LC and LC.Holds) then return "-" end
    local list = LC:Holds()
    return #list > 0 and table.concat(list, ",") or "-"
end

local function perfLine(out)
    local P = KCM.Perf
    if type(P) ~= "table" then
        out:add("State", "perf: unavailable")
        return
    end
    out:add("State", "perf: on=%s run=%s armed=%s recording=%s label=%s",
        P.on, P.run, P.armed, P.recording, P.label)
end

local function state(out)
    local p = profile()
    local db = KCM.db
    local global = db and db.global or {}
    out:add("State", "state: enabled(stored)=%s stood down=%s holds=%s",
        yn(p.enabled ~= false), yn(KCM.IsStoodDown and KCM.IsStoodDown()), holds())
    local profileKey = db and db.GetCurrentProfile and db:GetCurrentProfile() or "?"
    out:add("State", "schema: global=%s profile=%s code=%s, profile '%s'", global.schemaVersion,
        p.schemaVersion, KCM.Database and KCM.Database.CURRENT_SCHEMA, profileKey)
    perfLine(out)
    out:list("State", "rejected events:", KCM.RejectedEvents)
end

-- ---------------------------------------------------------------------------
-- settings: what moved from its default
-- ---------------------------------------------------------------------------

local function settings(out)
    local H = KCM.Settings and KCM.Settings.Helpers
    local S = H and H.schema
    if not (S and S.AllRows) then
        out:add("Set", "settings: the schema is unavailable")
        return
    end
    local rows = S.AllRows()
    out:add("Set", "schema rows: %s; changed rows and the always-printed ones follow", #rows)
    out:nonDefaults(rows, function(row) return S.Get(row.path) end, nil, nil, { always = ALWAYS })
end

-- ---------------------------------------------------------------------------
-- spec: the context every spec-aware category ranks by
-- ---------------------------------------------------------------------------

local function spec(out)
    local SH = KCM.SpecHelper
    local classID, specID, specKey, specName = SH.GetCurrent()
    out:add("Spec", "spec: class=%s spec=%s key=%s name=%s", classID, specID, specKey, specName)
    local stored = profile().statPriority
    out:add("Spec", "stat priority overrides stored: %s spec(s)", countKeys(stored))
    if not specKey then
        out:add("Spec", "stat priority: no active spec")
        return
    end
    local pri = SH.GetStatPriority(specKey)
    local override = type(stored) == "table" and type(stored[specKey]) == "table"
        and stored[specKey].primary ~= nil
    out:add("Spec", "stat priority: primary=%s secondary=%s override=%s",
        pri.primary, table.concat(pri.secondary or {}, ">"), yn(override))
end

-- ---------------------------------------------------------------------------
-- categories: edits, priority, and the pick as written
-- ---------------------------------------------------------------------------

-- The bucket a category's edits live in, WITHOUT Selector.GetBucket's lazy init.
local function storedBucket(cat, root, specKey)
    if not cat.specAware then return root end
    local bySpec = root.bySpec
    return specKey and type(bySpec) == "table" and bySpec[specKey] or nil
end

-- Every field GetBucket would otherwise create. With all four present,
-- GetEffectivePriority reads and writes nothing.
local function bucketReady(b)
    return type(b) == "table" and type(b.added) == "table" and type(b.blocked) == "table"
        and type(b.pins) == "table" and type(b.discovered) == "table"
end

local function rankContext(cat, specKey)
    if not (cat.specAware and specKey) then return nil end
    return { specPriority = KCM.SpecHelper.GetStatPriority(specKey) }
end

-- The effective priority, read only. A category with no stored bucket for this
-- spec is ranked from its seed list, which is what GetEffectivePriority answers
-- for an empty bucket.
local function priorityOf(cat, bucket, specKey)
    if bucketReady(bucket) then
        return KCM.Selector.GetEffectivePriority(cat.key, cat.specAware and specKey or nil) or {}
    end
    local seed = {}
    for i, id in ipairs(KCM.SEED and KCM.SEED[cat.key] or {}) do seed[i] = id end
    if #seed == 0 or not (KCM.Ranker and KCM.Ranker.SortCandidates) then return seed end
    return (KCM.Ranker.SortCandidates(cat.key, seed, rankContext(cat, specKey)))
end

local function ownedOf(id)
    if isSpell(id) then
        local sid = KCM.ID.SpellID(id)
        return sid and IsPlayerSpell and IsPlayerSpell(sid) or false
    end
    local BS = KCM.BagScanner
    return BS and BS.HasItem and (BS.HasItem(id)) or false
end

local function scoreText(out, catKey, id, ctx)
    local R = KCM.Ranker
    if not (R and R.Score) then return "-" end
    local score = R.Score(catKey, id, ctx)
    if not out:readable(score) then return out:str(score) end
    return ("%.1f"):format(score)
end

local function priorityRows(out, cat, bucket, specKey)
    local priority = priorityOf(cat, bucket, specKey)
    out:add("Cat", "  priority: %s entries", #priority)
    local ctx
    if KCM.Ranker and KCM.Ranker.BuildContext then
        ctx = KCM.Ranker.BuildContext(cat.key, priority, rankContext(cat, specKey))
    end
    for i = 1, math.min(TOP, #priority) do
        local id = priority[i]
        out:add("Cat", "    %s. %s score=%s owned=%s", i, describeId(id),
            scoreText(out, cat.key, id, ctx), yn(ownedOf(id)))
    end
end

local function edits(out, cat, root, bucket)
    if cat.specAware then
        out:add("Cat", "  specs with a stored bucket: %s", countKeys(root.bySpec))
    end
    if type(bucket) ~= "table" then
        out:add("Cat", "  edits: no stored bucket for the current spec")
        return
    end
    out:add("Cat", "  edits: added=%s blocked=%s pins=%s discovered=%s", countKeys(bucket.added),
        countKeys(bucket.blocked), #(type(bucket.pins) == "table" and bucket.pins or {}),
        countKeys(bucket.discovered))
    out:list("Cat", "  added:", setIds(bucket.added))
    out:list("Cat", "  blocked:", setIds(bucket.blocked))
    out:list("Cat", "  pins:", pinList(bucket.pins))
end

-- A composite's two ordered ref lists, each ref marked when it is switched off.
local function compositeRefs(root, field)
    local refs = {}
    local enabled = type(root.enabled) == "table" and root.enabled or {}
    for i, ref in ipairs(type(root[field]) == "table" and root[field] or {}) do
        refs[i] = enabled[ref] == false and (tostring(ref) .. "(off)") or tostring(ref)
    end
    return refs
end

local function pickLine(out, cat)
    local ms = macroStates()[cat.macroName]
    local written = type(ms) == "table" and ms.lastItemID
    out:add("Cat", "  pick (as written): %s", written and describeId(written) or "-")
end

local function categoryBlock(out, cat, specKey)
    out:add("Cat", "%s (%s) macro=%s specAware=%s composite=%s", cat.key, cat.displayName,
        cat.macroName, yn(cat.specAware), yn(cat.composite))
    local cats = profile().categories
    local root = type(cats) == "table" and cats[cat.key] or nil
    if type(root) ~= "table" then
        out:add("Cat", "  no stored settings")
    elseif cat.composite then
        out:joined("Cat", "  in combat:", compositeRefs(root, "orderInCombat"))
        out:joined("Cat", "  out of combat:", compositeRefs(root, "orderOutOfCombat"))
    else
        local bucket = storedBucket(cat, root, specKey)
        edits(out, cat, root, bucket)
        priorityRows(out, cat, bucket, specKey)
    end
    pickLine(out, cat)
end

local function categories(out)
    local _, _, specKey = KCM.SpecHelper.GetCurrent()
    for _, cat in ipairs(KCM.Categories.LIST) do
        out:section("category " .. tostring(cat.key), categoryBlock, cat, specKey)
    end
end

-- ---------------------------------------------------------------------------
-- weapon enchant: what each hand holds, and what the macro applies to it
-- ---------------------------------------------------------------------------

-- `item:<id> -> <slot>` for every `/use item:<id>` followed by `/use <slot>` in
-- a written weapon-enchant body (MacroManager's buildWeaponEnchantBody shape).
local function enchantUses(body)
    local uses = {}
    if type(body) ~= "string" then return uses end
    for item, slot in body:gmatch("/use item:(%d+)%s*\n/use (%d+)") do
        uses[#uses + 1] = "item:" .. item .. " -> " .. slot
    end
    return uses
end

local function weaponEnchant(out)
    local W = KCM.WeaponSlots
    for _, s in ipairs(WEAPON_SLOTS) do
        local itemID = GetInventoryItemID and GetInventoryItemID("player", s[1])
        local affinity = W and W.SlotAffinity and W.SlotAffinity(s[1])
        out:add("Wpn", "slot %s (%s): weapon=%s affinity=%s", s[1], s[2], itemID or "-", affinity or "-")
    end
    local cat = KCM.Categories.Get and KCM.Categories.Get("WPN_ENCH")
    local ms = cat and macroStates()[cat.macroName]
    out:list("Wpn", "as written:", enchantUses(type(ms) == "table" and ms.lastBody or nil))
end

-- ---------------------------------------------------------------------------
-- macros: slots, what each managed macro carries, and the combat queue
-- ---------------------------------------------------------------------------

local function slotUsage(out)
    local account, perChar = GetNumMacros()
    if not out:readable(account) then
        out:add("Macro", "account macro slots: unreadable")
        return
    end
    out:add("Macro", "account macro slots: %s of %s used, per-character: %s", account,
        MAX_ACCOUNT_MACROS, out:readable(perChar) and perChar or "-")
end

local function macroRow(out, cat)
    local idx = GetMacroIndexByName and GetMacroIndexByName(cat.macroName)
    local exists = out:readable(idx) and idx > 0
    local ms = macroStates()[cat.macroName]
    if type(ms) ~= "table" then
        out:add("Macro", "%s: exists=%s index=%s, never written this profile", cat.macroName,
            yn(exists), idx)
        return
    end
    out:add("Macro", "%s: exists=%s index=%s item=%s icon=%s cat=%s body=%s bytes", cat.macroName,
        yn(exists), idx, ms.lastItemID and describeId(ms.lastItemID) or "-", ms.lastIcon,
        ms.lastCat, type(ms.lastBody) == "string" and #ms.lastBody or 0)
end

-- NOT under a nested pcall: a raise in the queue readers costs this whole
-- section one line, which is what the section pcall is for.
local function combatQueue(out)
    local MM = KCM.MacroManager
    local rows = MM.PendingSnapshot()
    out:add("Macro", "combat queue: %s pending write(s)", #rows)
    for _, r in ipairs(rows) do
        out:add("Macro", "  pending %s cat=%s item=%s attempts=%s composite=%s bytes=%s", r.name,
            r.catKey, r.itemID and describeId(r.itemID) or "-", r.attempts, yn(r.composite), r.bytes)
    end
    local tracking = MM.WriteTracking()
    out:list("Macro", "oversized (warned this session):", tracking.oversized)
    local gaveUp = {}
    for i, g in ipairs(tracking.gaveUp or {}) do
        gaveUp[i] = tostring(g.name) .. " x" .. tostring(g.attempts)
    end
    out:list("Macro", "gave up:", gaveUp)
    out:add("Macro", "recompute debounce: pending=%s", yn(KCM._recomputePending))
end

local function macros(out)
    slotUsage(out)
    for _, cat in ipairs(KCM.Categories.LIST) do macroRow(out, cat) end
    combatQueue(out)
end

-- ---------------------------------------------------------------------------
-- macro bar: why it is (or is not) on screen, and where
-- ---------------------------------------------------------------------------

-- One frame method, pcall'd: its value, "-" when the frame lacks it.
local function frameRead(frame, method)
    local fn = frame[method]
    if type(fn) ~= "function" then return "-" end
    local ok, a, b, c, d, e = pcall(fn, frame, 1)
    if not ok then return "unreadable" end
    return a, b, c, d, e
end

local function barHidden(out, c)
    local BM = KCM.MacroBarModel
    if BM.IsEnabled() then
        out:add("Bar", "bar enabled: shown when its visibility allows")
    elseif KCM.IsStoodDown and KCM.IsStoodDown() then
        out:add("Bar", "bar hidden: the addon is stood down")
    elseif not c.enabled then
        out:add("Bar", "bar hidden: macroBar.enabled is off")
    end
end

local function barFrame(out, c)
    local frame = _G[BAR_NAME]
    out:add("Bar", "point: saved=%s %s %s,%s", c.point, c.relPoint, c.x, c.y)
    if type(frame) ~= "table" then
        out:add("Bar", "frame: built=no")
        return
    end
    out:add("Bar", "frame: built=yes shown=%s visible=%s scale=%s alpha=%s",
        frameRead(frame, "IsShown"), frameRead(frame, "IsVisible"), frameRead(frame, "GetScale"),
        frameRead(frame, "GetAlpha"))
    local point, _, relPoint, x, y = frameRead(frame, "GetPoint")
    out:add("Bar", "point: live=%s %s %s,%s", point, relPoint, x, y)
end

local function macroBar(out)
    local BM, MB = KCM.MacroBarModel, KCM.MacroBar
    local c = BM.Config() or {}
    barHidden(out, c)
    barFrame(out, c)
    out:add("Bar", "deferred apply: pending=%s", yn(MB and MB.IsUpdatePending and MB.IsUpdatePending()))
    out:add("Bar", "visibility: master=%s combatMode=%s fade=%s locked=%s", profile().visibility,
        c.combatMode, yn(c.fadeUnlessHover), yn(c.locked))
    out:list("Bar", "slots (order):", BM.Order())
    out:list("Bar", "slots (shown):", BM.Visible())
end

-- ---------------------------------------------------------------------------
-- tooltip cache, bags and events
-- ---------------------------------------------------------------------------

local function tooltipCache(out)
    local snap = KCM.TooltipCache.Snapshot()
    out:add("Tip", "tooltip cache: %s entries, %s pending, %s unsupported", snap.total,
        snap.pending, snap.unsupported)
    out:list("Tip", "pending ids:", snap.pendingIds)
end

local function bags(out)
    local counts = KCM.BagScanner.Scan()
    local distinct, total = 0, 0
    for _, n in pairs(counts) do
        distinct = distinct + 1
        if out:readable(n) then total = total + n end
    end
    out:add("Bags", "bags: %s distinct item(s), %s item(s) in all", distinct, total)
end

-- The `/cm dump events` body, from the same rows (core/SlashDump.lua).
local function events(out)
    local rows, rejected = KCM.SlashDump.EventStates()
    out:add("Events", "events: %s client events, %s rejected", #rows, rejected)
    for _, r in ipairs(rows) do
        out:add("Events", "  %s %s -> %s", r.event, r.state, r.handler)
    end
end

--- The report's host sections, in order, as { name, fn } pairs.
function Dx.Sections()
    return {
        { "state",          state },
        { "settings",       settings },
        { "spec",           spec },
        -- Before categories: ranking scores every candidate through TooltipCache.Get,
        -- which re-fetches a pending entry and may resolve it, so the cache is read
        -- here first, as the player's session left it.
        { "tooltip cache",  tooltipCache },
        { "categories",     categories },
        { "weapon enchant", weaponEnchant },
        { "macros",         macros },
        { "macro bar",      macroBar },
        { "bags",           bags },
        { "events",         events },
    }
end
