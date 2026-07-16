-- Core.lua — AceAddon entry point, DB bootstrap, slash registration.

local addonName, NS = ...
local KCM = NS

local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceConsole-3.0")
NS.addon = addon

KCM.VERSION = "1.5.0"

-- Priority-list entries are opaque numeric IDs. Positive = itemID; negative
-- is a spell-sentinel whose absolute value is the spellID. Using a disjoint
-- numeric range lets every candidate-set / pins / blocked table stay keyed
-- by plain numbers — no schema change — while MacroManager, Ranker, and the
-- UI fork on the sign to render "/use item:<id>" vs "/cast <spell>".
--
-- Seed files compose spell entries with KCM.ID.AsSpell(spellID) for
-- readability, e.g. `KCM.ID.AsSpell(1231411)` for Recuperate.
KCM.ID = KCM.ID or {}
function KCM.ID.AsSpell(spellID) return -spellID end
function KCM.ID.IsSpell(id) return type(id) == "number" and id < 0 end
function KCM.ID.IsItem(id)  return type(id) == "number" and id > 0 end
function KCM.ID.SpellID(id) return (type(id) == "number" and id < 0) and -id or nil end
function KCM.ID.ItemID(id)  return (type(id) == "number" and id > 0) and  id or nil end

KCM.dbDefaults = {
    -- Schema shape is account-wide, so its version lives in `global`, not
    -- `profile` (standard §2.2 / §5.1). Database.RunMigrations reads it.
    global = {
        schemaVersion = 1,
    },
    profile = {
        enabled = true,    -- master enable; when false the recompute pipeline early-returns
        -- NB: the debug flag is session-only (KCM.State.debug), never persisted.
        categories = {
            FOOD      = { added = {}, blocked = {}, pins = {}, discovered = {} },
            DRINK     = { added = {}, blocked = {}, pins = {}, discovered = {} },
            HP_POT    = { added = {}, blocked = {}, pins = {}, discovered = {} },
            MP_POT    = { added = {}, blocked = {}, pins = {}, discovered = {} },
            HS        = { added = {}, blocked = {}, pins = {}, discovered = {} },
            VANTUS    = { added = {}, blocked = {}, pins = {}, discovered = {} },
            AUG_RUNE  = { added = {}, blocked = {}, pins = {}, discovered = {} },
            STAT_FOOD = { bySpec = {} },
            CMBT_POT  = { bySpec = {} },
            FLASK     = { bySpec = {} },
            WPN_ENCH  = { bySpec = {} },
            -- Composite categories. No item buckets (added/blocked/pins/
            -- discovered) — picks come from the underlying single categories
            -- at recompute time. `enabled[ref]` toggles a sub-category in/out
            -- of the macro body; `orderInCombat` / `orderOutOfCombat` are the
            -- sub-category refs in the order they appear in the macro body
            -- (also drives the row order in the panel). Sub-categories are
            -- locked to their section: HS+HP_POT/MP_POT only ever go into
            -- inCombat, FOOD/DRINK only ever go into outOfCombat.
            HP_AIO    = {
                enabled = { HS = true, HP_POT = true, FOOD = true },
                orderInCombat = { "HS", "HP_POT" },
                orderOutOfCombat = { "FOOD" },
            },
            MP_AIO    = {
                enabled = { MP_POT = true, DRINK = true },
                orderInCombat = { "MP_POT" },
                orderOutOfCombat = { "DRINK" },
            },
        },
        statPriority = {}, -- [specKey] = { primary = "AGI", secondary = {...} }  -- user overrides only
        macroState = {},
    },
}

function KCM:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ConsumableMasterDB", KCM.dbDefaults, true)
    if KCM.Database and KCM.Database.RunMigrations then
        KCM.Database.RunMigrations()
    end
    self:RegisterChatCommand("cm", "OnSlashCommand")
    self:RegisterChatCommand("consumablemaster", "OnSlashCommand")
    -- Panel registration is driven by the PLAYER_LOGIN / ADDON_LOADED
    -- bootstrap in settings/Panel.lua. AceAddon OnInitialize runs before
    -- PLAYER_LOGIN, so Settings.RegisterAddOnCategory may not be ready
    -- here on every client build — relying on the bootstrap is more robust.
    --
    -- No boot summary is emitted here: the debug flag is session-only and off at
    -- login, so a load-time line would be gated off and never render. The
    -- lifecycle summary rides the DebugLog.SetEnabled seam instead, as the [Init]
    -- line emitted on debug-enable (debug-logging-§5/§8).
end

-- ---------------------------------------------------------------------------
-- Pipeline — orchestrates Selector → MacroManager for every category.
-- ---------------------------------------------------------------------------
-- All event handlers enqueue a recompute via RequestRecompute; RequestRecompute
-- coalesces calls within the same frame by gating on `_recomputePending` and
-- scheduling a single `C_Timer.After(0, ...)` (see TECHNICAL_DESIGN §6.2).
--
-- Recompute itself walks KCM.Categories.LIST, asks Selector for the best-owned
-- item, and passes the result to MacroManager. MacroManager handles early-out
-- (unchanged body), combat deferral, and the actual Blizzard API calls.

KCM.Pipeline = KCM.Pipeline or {}
local P = KCM.Pipeline

function P.RecomputeOne(catKey, scoreCache, reason)
    if not KCM.Categories or not KCM.Selector or not KCM.MacroManager then
        return
    end
    local cat = KCM.Categories.Get and KCM.Categories.Get(catKey)
    if not cat then return end
    if cat.composite then
        -- Composite categories don't pick from their own bag set; their
        -- macro body is assembled from the picks the underlying single
        -- categories already produced (Selector.PickBestForCategory is pure
        -- and idempotent, so calling it again per sub-cat inside
        -- SetCompositeMacro is fine — and the same scoreCache flows through
        -- so any item that overlaps multiple categories isn't re-parsed).
        return KCM.MacroManager.SetCompositeMacro(cat, scoreCache)
    end
    if cat.perHand then
        -- Per-hand categories (weapon enchants) don't have one "best" pick;
        -- each equipped weapon gets its own affinity-filtered pick and the
        -- two feed a single macro body (main hand = slot 16, off hand = 17).
        local mh = KCM.Selector.PickBestForSlot(catKey, 16, scoreCache)
        local oh = KCM.Selector.PickBestForSlot(catKey, 17, scoreCache)
        return KCM.MacroManager.SetWeaponEnchantMacro(cat, mh, oh)
    end
    local pick = KCM.Selector.PickBestForCategory(catKey, nil, scoreCache)
    return KCM.MacroManager.SetMacro(cat.macroName, pick, catKey)
end

function P.Recompute(reason)
    if not KCM.Categories or not KCM.Categories.LIST then return end
    -- Master enable gates only the macro write loop. The panel refresh
    -- below still runs so that opening the panel while the addon is off
    -- hydrates priority-list rows from item-info events (otherwise rows
    -- whose data hadn't loaded sit on `[Loading]` until re-enable). Macros
    -- keep their last-written body until the off→on transition kicks a
    -- recompute via the toggle's onChange in settings/Panel.lua.
    local enabled = not (KCM.db and KCM.db.profile and KCM.db.profile.enabled == false)
    if enabled then
        -- Per-pass score cache. `fields[id]` memoizes GetItemInfo +
        -- TooltipCache.Get so items appearing across multiple categories
        -- (pot HOT scans, overlapping seeds) don't re-parse tooltips.
        -- `[catKey][id]` memoizes the per-category score. Passing nil (as
        -- /cm dump / panel renders do) falls back to the uncached path.
        local scoreCache = { fields = {} }
        local rewrote, skipped, total = 0, 0, 0
        for _, cat in ipairs(KCM.Categories.LIST) do
            -- Isolate each category so one bad scorer can't break the
            -- other seven macros. One pcall per category per recompute
            -- (8 per frame at peak) is cheap.
            total = total + 1
            local ok, res = pcall(P.RecomputeOne, cat.key, scoreCache, reason)
            if not ok then
                if KCM.State and KCM.State.debug then KCM.Debug("Macro", "%s recompute failed: %s", cat.key, tostring(res)) end
            elseif res == "unchanged" then
                skipped = skipped + 1
            elseif res ~= nil then
                rewrote = rewrote + 1   -- created / edited / deferred
            end
        end
        if KCM.State and KCM.State.debug then
            KCM.Debug("Calc", "%s", KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped))
        end
    elseif KCM.State and KCM.State.debug then
        KCM.Debug("Calc", "skipped writes (disabled): reason=%s", tostring(reason))
    end
    -- Pipeline → panel refresh crosses a feature boundary, so it is published
    -- on the bus (standard §4.4); the options layer owns the sole PANEL_REFRESH
    -- receiver and debounces the rebuild so a burst of GET_ITEM_INFO_RECEIVED
    -- events collapses into one rebuild. Falls back to a direct call if the bus
    -- hasn't loaded (defensive; Bus.lua loads before any event fires).
    if KCM.bus and KCM.bus.SendMessage then
        KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH)
    elseif KCM.Options and KCM.Options.RequestRefresh then
        KCM.Options.RequestRefresh()
    elseif KCM.Options and KCM.Options.Refresh then
        KCM.Options.Refresh()
    end
end

-- Event/UI → pipeline recompute goes over the bus. Falls back to the direct
-- coalescing entry if the bus is somehow absent.
local function requestRecompute(reason)
    if KCM.bus and KCM.bus.SendMessage then
        KCM.bus:SendMessage(KCM.MSG.RECOMPUTE, reason)
    elseif KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute(reason)
    end
end

function P.RequestRecompute(reason)
    KCM._recomputePending = true
    KCM._recomputeReason  = reason or KCM._recomputeReason or "unknown"
    if KCM._recomputeScheduled then return end
    KCM._recomputeScheduled = true
    -- C_Timer.After(0, ...) defers to the end of the current frame, which
    -- collapses a flurry of events (e.g. multiple BAG_UPDATE_DELAYED during
    -- loot) into a single pipeline run.
    C_Timer.After(0, function()
        KCM._recomputeScheduled = false
        if KCM._recomputePending then
            local r = KCM._recomputeReason
            KCM._recomputePending = false
            KCM._recomputeReason  = nil
            P.Recompute(r)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------
-- All handlers route through Pipeline.RequestRecompute; none of them touch
-- macro APIs directly. This keeps Selector/Ranker/Classifier on the
-- unprotected path and leaves MacroManager as the sole caller of
-- CreateMacro/EditMacro.

-- Classify one bag item into any matching categories and, for each match
-- that isn't already in the shipped seed, record it in the bucket's
-- `discovered` set. Shared between the bulk bag pass (PEW,
-- BAG_UPDATE_DELAYED) and the per-item retry triggered by
-- GET_ITEM_INFO_RECEIVED — which exists because `Classifier.Match` returns
-- false for items whose tooltip isn't loaded yet. Without the retry, an
-- item present in bags from /reload silently gets skipped on first
-- discovery pass and never re-enters the candidate set until bags change.
local function discoverOne(itemID, reason, nowUnix, outNew)
    if not (itemID and KCM.Classifier and KCM.Classifier.MatchAny
            and KCM.Selector and KCM.Selector.MarkDiscovered) then
        return 0
    end
    local added = 0
    local hits = KCM.Classifier.MatchAny(itemID)
    -- Zero-hit (item isn't a consumable we manage) is the common case on every
    -- bag update and is intentionally NOT logged per-item — the bulk pass in
    -- runAutoDiscovery emits one summary line instead. When `outNew` is passed
    -- (bulk pass) we collect discovered IDs there for that summary; when it's
    -- nil (standalone item_info_received retry) we print the per-item line.
    nowUnix = nowUnix or time()
    for _, catKey in ipairs(hits) do
        local cat = KCM.Categories.Get(catKey)
        local inSeed = false
        local seed = KCM.SEED and KCM.SEED[catKey] or {}
        for _, sid in ipairs(seed) do
            if sid == itemID then inSeed = true; break end
        end
        if not inSeed then
            local specKey
            if cat and cat.specAware and KCM.SpecHelper then
                local _, _, key = KCM.SpecHelper.GetCurrent()
                specKey = key
            end
            if KCM.Selector.MarkDiscovered(catKey, itemID, specKey, nowUnix) then
                added = added + 1
                if outNew then
                    outNew[#outNew + 1] = itemID
                elseif KCM.State and KCM.State.debug then
                    KCM.Debug("Scan", "discovered %s id=%s (reason=%s)",
                        catKey, itemID, tostring(reason))
                end
            end
        end
    end
    return added
end

local function runAutoDiscovery(reason)
    if not (KCM.BagScanner and KCM.Classifier) then return 0 end
    local counts = KCM.BagScanner.Scan()
    local discovered = 0
    local nowUnix = time()
    -- Only build the scanned/new lists when debug is on (standard §12 zero-alloc
    -- gate) — this runs on every BAG_UPDATE_DELAYED. `newIds`, when non-nil, is
    -- the accumulator discoverOne fills instead of printing per-item lines.
    local debugOn = KCM.Debug and KCM.Debug.IsOn and KCM.Debug.IsOn()
    local scanned = debugOn and {} or nil
    local newIds  = debugOn and {} or nil
    for id in pairs(counts) do
        if scanned then scanned[#scanned + 1] = id end
        discovered = discovered + discoverOne(id, reason, nowUnix, newIds)
    end
    if debugOn and KCM.Debug then
        table.sort(scanned)
        table.sort(newIds)
        KCM.Debug("Scan", "reason=%s scanned %s items, %s new. Scanned=[%s]. New=[%s]",
            reason, #scanned, #newIds, table.concat(scanned, ","), table.concat(newIds, ","))
    end
    return discovered
end

-- Expose for manual invocation from /cm resync and tests.
KCM.Pipeline.RunAutoDiscovery = runAutoDiscovery

-- Pure recompute-summary formatter (debug-logging-§8/§9, unit-tested).
function KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped)
    return ("reason=%s rewrote %s/%s (skipped %s)"):format(
        tostring(reason), tostring(rewrote), tostring(total), tostring(skipped))
end

-- Wipe every user customization and restore from dbDefaults. Preserves
-- macroState so live macros aren't orphaned. Shared by the Options panel's
-- "Reset all priorities" execute and the /cm reset StaticPopup — both
-- paths land here to keep semantics identical regardless of entry point.
--
-- After the DB wipe we drive a full resync (not just a RequestRecompute):
-- tooltip cache invalidation, auto-discovery pass, then an immediate
-- Recompute. The cache invalidation clears any stale `pending` entries
-- from the prior session, auto-discovery re-fills the `discovered` set
-- which we just wiped, and Recompute rewrites every macro body.
--
-- Why Recompute (immediate) and not RequestRecompute (next-frame): the user
-- just clicked "reset" and expects the panel and macros to refresh now. The
-- combat-guard contract is upheld transitively — Recompute → MacroManager,
-- and MacroManager.SetMacro / SetCompositeMacro are the only protected-API
-- callers and they early-out on InCombatLockdown(), enqueuing the write for
-- PLAYER_REGEN_ENABLED to flush. If a future module ever calls a protected
-- API outside MacroManager, this path becomes a taint hazard and the choice
-- of immediate-vs-deferred recompute would need to be re-evaluated.
--
-- Returns true if the DB was mutated; callers that want user feedback
-- should print their own confirmation message.
function KCM.ResetAllToDefaults(reason)
    if not (KCM.db and KCM.db.profile) then return false end
    local defaults = KCM.dbDefaults and KCM.dbDefaults.profile or {}
    KCM.db.profile.categories   = CopyTable(defaults.categories or {})
    KCM.db.profile.statPriority = CopyTable(defaults.statPriority or {})
    reason = reason or "reset_all"
    if KCM.State and KCM.State.debug then KCM.Debug("Prio", "reset all (reason=%s)", tostring(reason)) end
    if KCM.TooltipCache and KCM.TooltipCache.InvalidateAll then
        KCM.TooltipCache.InvalidateAll()
    end
    if KCM.Pipeline and KCM.Pipeline.RunAutoDiscovery then
        KCM.Pipeline.RunAutoDiscovery(reason)
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute(reason)
    end
    return true
end

function KCM:OnPlayerEnteringWorld()
    -- Fires on login and /reload. Discover + recompute everything.
    -- Sweep runs after discovery so bumped timestamps are seen by the sweep
    -- and before recompute so the cleaned-up discovered set feeds the first
    -- pick.
    runAutoDiscovery("player_entering_world")
    if KCM.Selector and KCM.Selector.SweepStaleDiscovered then
        KCM.Selector.SweepStaleDiscovered(time())
    end
    requestRecompute("player_entering_world")
end

function KCM:OnBagUpdateDelayed()
    runAutoDiscovery("bag_update_delayed")
    requestRecompute("bag_update_delayed")
end

function KCM:OnSpecChanged()
    requestRecompute("spec_changed")
    -- The Stat Priority page's retrack-to-current-spec behaviour is a panel
    -- concern, so it is published as SPEC_CHANGED and handled by the options
    -- layer's own receiver rather than reached into from here (standard §4.4).
    if KCM.bus and KCM.bus.SendMessage then
        KCM.bus:SendMessage(KCM.MSG.SPEC_CHANGED)
    end
end

function KCM:OnRegenEnabled()
    if KCM.MacroManager and KCM.MacroManager.FlushPending then
        local n = KCM.MacroManager.FlushPending()
        if n > 0 and KCM.State and KCM.State.debug then
            KCM.Debug("Macro", "flushed %s pending macro(s) on regen", n)
        end
    end
end

function KCM:OnItemInfoReceived(event, itemID, success)
    if not success or not itemID then return end
    if KCM.TooltipCache and KCM.TooltipCache.Invalidate then
        KCM.TooltipCache.Invalidate(itemID)
    end
    -- Split bag vs non-bag events. First opening the options panel accesses
    -- ~150 priority-list items that aren't in bags, each firing an event as
    -- its data hydrates from the server. A full Pipeline.Recompute on each
    -- (160 TC.Get calls × many events/sec) tanks FPS for 5-10 seconds; but
    -- those items can't affect macro picks (macros only select from bag
    -- items), so the recompute is pure waste. Only bag items need the full
    -- pipeline; everything else just triggers a debounced panel refresh so
    -- rows can swap "?" for the real name once data arrives.
    if KCM.BagScanner and KCM.BagScanner.HasItem and KCM.BagScanner.HasItem(itemID) then
        discoverOne(itemID, "item_info_received")
        requestRecompute("item_info_received")
    elseif KCM.bus and KCM.bus.SendMessage then
        KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH)
    end
end

function KCM:OnLearnedSpell()
    -- Closes the narrow window where spellNameFor() returned nil during a
    -- macro write because the spell book hadn't hydrated yet, but the spell
    -- becomes known later in the same session without a spec change or bag
    -- event. Coalesced through RequestRecompute → one frame, one pipeline.
    requestRecompute("learned_spell")
end

function KCM:OnEquipmentChanged(event, slotID)
    -- Only main hand (16) / off hand (17) swaps affect the per-hand weapon
    -- enchant pick; every other equipment slot is a no-op here.
    if slotID == 16 or slotID == 17 then
        requestRecompute("equip")
    end
end

function KCM:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD",         "OnPlayerEnteringWorld")
    self:RegisterEvent("BAG_UPDATE_DELAYED",            "OnBagUpdateDelayed")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED",          "OnRegenEnabled")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED",        "OnItemInfoReceived")
    self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE",   "OnLearnedSpell")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED",      "OnEquipmentChanged")
end
