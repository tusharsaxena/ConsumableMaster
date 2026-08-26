-- ConsumableMaster.lua — AceAddon entry point, DB bootstrap, slash registration.

local addonName, NS = ...
local KCM = NS

local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceConsole-3.0")
NS.addon = addon

-- The perf probe (the LibKa0s-Perf instance built in core/PerfSetup.lua), taken
-- as a LOAD-TIME upvalue rather than looked up through KCM on every call
-- (performance-§2). PerfSetup sits immediately after core/Namespace.lua in the
-- TOC, ahead of this file, precisely so this binding is the real instance.
-- It is nil-tolerant because the pure test layer and a build with the vendored
-- library omitted both load without PerfSetup publishing anything, and an
-- absent diagnostics harness must not break the addon's own function.
local Perf = KCM.Perf

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

-- KCM.dbDefaults — the AceDB defaults tree — used to be declared here. It is
-- defaults/Profile.lua now (savedvariables-§2: one declaration site, and it is
-- the file whose name says what it holds). Nothing in this file needs it at
-- load: OnInitialize below reads it at PLAYER_LOGIN time, long after the whole
-- TOC has loaded.

function KCM:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ConsumableMasterDB", KCM.dbDefaults, true)
    if KCM.Database and KCM.Database.RunMigrations then
        KCM.Database.RunMigrations()
    end

    -- PROFILE CALLBACKS (options-ui-§12). Defined below, beside `afterReset` --
    -- the resync they run -- and reached as a FIELD so the call resolves at run
    -- time rather than needing the local in lexical scope up here.
    if KCM.RegisterProfileCallbacks then KCM.RegisterProfileCallbacks(self) end
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
-- scheduling a single `C_Timer.After(0, ...)` (see docs/data-flow.md,
-- "Pull-based, frame-coalesced").
--
-- Recompute itself walks KCM.Categories.LIST, asks Selector for the best-owned
-- item, and passes the result to MacroManager. MacroManager handles early-out
-- (unchanged body), combat deferral, and the actual Blizzard API calls.

KCM.Pipeline = KCM.Pipeline or {}
local P = KCM.Pipeline

-- The session debug gate, in one place instead of once per log site. It stays a
-- PREDICATE rather than a logging wrapper on purpose: KCM.Debug's arguments
-- (tostring calls, CalcSummary) must not be evaluated when debug is off, which
-- is the debug-logging-§4 zero-alloc rule these paths are written to. It also reads
-- KCM.State directly, exactly as the inline sites did — not KCM.Debug.IsOn,
-- which consults the DebugLog console first and is therefore a different gate.
local function isDebugOn()
    if KCM.State and KCM.State.debug then return true end
    return false
end

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

-- Master enable. It gates only the macro write loop — the panel refresh runs
-- either way (see Recompute).
local function macrosEnabled()
    return not (KCM.db and KCM.db.profile and KCM.db.profile.enabled == false)
end

-- One write pass over every category, returning the tally the Calc line reports.
local function runMacroPass(reason)
    -- Per-pass score cache. `fields[id]` memoizes GetItemInfo +
    -- TooltipCache.Get so items appearing across multiple categories
    -- (pot HOT scans, overlapping seeds) don't re-parse tooltips.
    -- `[catKey][id]` memoizes the per-category score. Passing nil (as
    -- /cm dump / panel renders do) falls back to the uncached path.
    local scoreCache = { fields = {} }
    local rewrote, skipped, total = 0, 0, 0
    for _, cat in ipairs(KCM.Categories.LIST) do
        -- Isolate each category so one bad scorer can't break the other
        -- fourteen macros. One pcall per category per recompute (15 per
        -- frame at peak — `KCM.Categories.LIST` in defaults/Categories.lua
        -- carries 13 consumable categories plus HP_AIO and MP_AIO) is cheap.
        total = total + 1
        local ok, res = pcall(P.RecomputeOne, cat.key, scoreCache, reason)
        if not ok then
            if isDebugOn() then KCM.Debug("Macro", "%s recompute failed: %s", cat.key, tostring(res)) end
        elseif res == "unchanged" then
            skipped = skipped + 1
        elseif res ~= nil then
            rewrote = rewrote + 1   -- created / edited / deferred
        end
    end
    return rewrote, skipped, total
end

-- Tell the panel and the macro bar the pass is done.
--
-- Pipeline → panel refresh crosses a feature boundary, so it is published
-- on the bus (architecture-§4); the options layer owns the sole PANEL_REFRESH
-- receiver and debounces the rebuild so a burst of GET_ITEM_INFO_RECEIVED
-- events collapses into one rebuild. Falls back to a direct call if the bus
-- hasn't loaded (defensive; Bus.lua loads before any event fires).
local function publishRefresh()
    if KCM.bus and KCM.bus.SendMessage then
        KCM.bus:SendMessage(KCM.MSG.PANEL_REFRESH)
        -- Macro bar repaint rides its own message: it is undebounced (a live
        -- on-screen bar should track the macro it just rewrote) and it must not
        -- be coupled to whether a settings page happens to be open.
        KCM.bus:SendMessage(KCM.MSG.MACROBAR_REFRESH)
    elseif KCM.Options and KCM.Options.RequestRefresh then
        KCM.Options.RequestRefresh()
    elseif KCM.Options and KCM.Options.Refresh then
        KCM.Options.Refresh()
    end
end

function P.Recompute(reason)
    if not KCM.Categories or not KCM.Categories.LIST then return end
    -- Perf bucket. One bracket around the whole pass — at most one call per
    -- frame, since RequestRecompute coalesces — covering the 15-category walk,
    -- the composite re-picks and every macro write. Gated the same way the
    -- cooldown bracket is, and for the same reason: Note() records whether or
    -- not a capture is open.
    local perfT0 = (Perf and Perf.on) and debugprofilestop() or nil
    -- Master enable gates only the macro write loop. The panel refresh
    -- below still runs so that opening the panel while the addon is off
    -- hydrates priority-list rows from item-info events (otherwise rows
    -- whose data hadn't loaded sit on `[Loading]` until re-enable). Macros
    -- keep their last-written body until the off→on transition kicks a
    -- recompute via the toggle's onChange in settings/Panel.lua.
    if macrosEnabled() then
        local rewrote, skipped, total = runMacroPass(reason)
        if isDebugOn() then
            KCM.Debug("Calc", "%s", KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped))
        end
    elseif isDebugOn() then
        KCM.Debug("Calc", "skipped writes (disabled): reason=%s", tostring(reason))
    end
    publishRefresh()
    if perfT0 then Perf.Note("recompute", debugprofilestop() - perfT0) end
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
-- Is this item already in the category's shipped seed? Seeds are small arrays,
-- so a linear scan beats building a set per pass.
local function isSeeded(catKey, itemID)
    local seed = KCM.SEED and KCM.SEED[catKey] or {}
    for _, sid in ipairs(seed) do
        if sid == itemID then return true end
    end
    return false
end

-- The spec key a discovery is filed under, resolved PER CATEGORY: only
-- spec-aware categories get one, and a non-spec-aware category must file at the
-- category root (nil).
local function discoverySpecKey(cat)
    if cat and cat.specAware and KCM.SpecHelper then
        local _, _, key = KCM.SpecHelper.GetCurrent()
        return key
    end
    return nil
end

-- Record one discovery, reporting 1 if it was new. When `outNew` is passed
-- (bulk pass) we collect discovered IDs there for the pass summary; when it's
-- nil (standalone item_info_received retry) we print the per-item line.
local function recordDiscovery(catKey, itemID, specKey, reason, nowUnix, outNew)
    if not KCM.Selector.MarkDiscovered(catKey, itemID, specKey, nowUnix) then return 0 end
    if outNew then
        outNew[#outNew + 1] = itemID
    elseif isDebugOn() then
        KCM.Debug("Scan", "discovered %s id=%s (reason=%s)",
            catKey, itemID, tostring(reason))
    end
    return 1
end

local function discoverOne(itemID, reason, nowUnix, outNew)
    if not (itemID and KCM.Classifier and KCM.Classifier.MatchAny
            and KCM.Selector and KCM.Selector.MarkDiscovered) then
        return 0
    end
    local added = 0
    local hits = KCM.Classifier.MatchAny(itemID)
    -- Zero-hit (item isn't a consumable we manage) is the common case on every
    -- bag update and is intentionally NOT logged per-item — the bulk pass in
    -- runAutoDiscovery emits one summary line instead.
    --
    -- `nowUnix` defaults once, before the loop, so every bucket touched in one
    -- pass carries the same timestamp.
    nowUnix = nowUnix or time()
    for _, catKey in ipairs(hits) do
        if not isSeeded(catKey, itemID) then
            local specKey = discoverySpecKey(KCM.Categories.Get(catKey))
            added = added + recordDiscovery(catKey, itemID, specKey, reason, nowUnix, outNew)
        end
    end
    return added
end

local function runAutoDiscovery(reason)
    if not (KCM.BagScanner and KCM.Classifier) then return 0 end
    local counts = KCM.BagScanner.Scan()
    local discovered = 0
    local nowUnix = time()
    -- Only build the scanned/new lists when debug is on (debug-logging-§4 zero-alloc
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

-- Wipe every user customization and restore from dbDefaults — category
-- buckets, stat-priority overrides, and the master enable flag. Preserves
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
-- The DB half of the reset: every persisted customization back to its shipped
-- value. CopyTable, never an alias — aliasing dbDefaults would let a later user
-- edit corrupt the defaults for the rest of the session.
-- `restoreProfileDefaults` USED TO LIVE HERE, naming three profile keys by hand:
-- categories, statPriority and the master enable. That was the whole profile as
-- this addon knew it when the function was written, and it is the shape that
-- quietly stops being true -- anything a later version stores beside them
-- survived a reset that took everything around it.
--
-- The reset is `db:ResetProfile()` now (options-ui-§12). AceDB empties the profile
-- IN PLACE, so anything holding KCM.db.profile keeps the live table, and merges
-- KCM.dbDefaults.profile back over it -- which restores those three and everything
-- else, without a list here to keep current.

-- The resync half. Order matters: invalidate → discover → recompute, so
-- discovery sees a cleared cache and recompute sees the refreshed discovered
-- set. Deliberately three explicit guarded calls rather than a data-driven
-- loop — InvalidateAll takes no argument while the other two take `reason`.
local function afterReset(reason)
    if KCM.TooltipCache and KCM.TooltipCache.InvalidateAll then
        KCM.TooltipCache.InvalidateAll()
    end
    if KCM.Pipeline and KCM.Pipeline.RunAutoDiscovery then
        KCM.Pipeline.RunAutoDiscovery(reason)
    end
    if KCM.Pipeline and KCM.Pipeline.Recompute then
        KCM.Pipeline.Recompute(reason)
    end
end

--- Register the profile callbacks. This addon had none.
---
--- Every macro this addon writes is computed from db.profile. Switching, copying
--- or resetting a profile replaces every stored value at once and nothing here
--- reacted: the macros on the player's bars stayed the OUTGOING profile's until
--- something else happened to trigger a recompute, and the migrations never ran on
--- an incoming profile a copy could have authored at an older schema version. It
--- went unnoticed because nothing in this addon switched profiles -- until
--- options-ui-§12 made the GLOBAL RESET a profile reset, which fires the same event
--- and needs the same reaction.
---
--- `afterReset` above is the resync, and it is the whole reaction an incoming
--- profile needs -- which is why KCM.ResetAllToDefaults no longer calls it
--- directly. One path, not two.
function KCM.RegisterProfileCallbacks(target)
    local db = target and target.db
    if not (db and db.RegisterCallback) then return end

    local function reload(reason)
        return function()
            if KCM.Database and KCM.Database.RunMigrations then
                KCM.Database.RunMigrations()
            end
            afterReset(reason)
        end
    end

    db.RegisterCallback(target, "OnProfileChanged", reload("profile_changed"))
    db.RegisterCallback(target, "OnProfileCopied",  reload("profile_copied"))
    db.RegisterCallback(target, "OnProfileReset",   reload("profile_reset"))
end

--- Reset the ACTIVE PROFILE to the shipped defaults, and the same act as
--- AceDBOptions' own Reset Profile (options-ui-§12).
---
--- The resync is NOT called from here any more. `db:ResetProfile()` fires
--- OnProfileReset, and the handler KCM:OnInitialize registers runs `afterReset` --
--- so the invalidate → discover → recompute pass happens on exactly one path,
--- which is the path a profile SWITCH takes too. Calling it here as well would run
--- the pipeline twice for one action.
function KCM.ResetAllToDefaults(reason)
    if not (KCM.db and KCM.db.ResetProfile) then return false end
    reason = reason or "reset_all"
    if isDebugOn() then KCM.Debug("Prio", "reset all (reason=%s)", tostring(reason)) end
    KCM.db:ResetProfile()
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
    -- Build / re-show the optional macro bar. A no-op when it's disabled, which
    -- is the default, so nothing is created for users who never enable it.
    if KCM.MacroBar and KCM.MacroBar.Update then
        KCM.MacroBar.Update()
    end
end

-- Cooldown ticks are bar-only: the swipe animates itself once SetCooldown is
-- called, so these events exist purely to catch the START of a cooldown. Cheap
-- early-out when the bar is off.
function KCM:OnCooldownUpdate()
    if KCM.MacroBar and KCM.MacroBarModel and KCM.MacroBarModel.IsEnabled() then
        KCM.MacroBar.RefreshCooldowns()
    end
end

function KCM:OnBagUpdateDelayed()
    runAutoDiscovery("bag_update_delayed")
    requestRecompute("bag_update_delayed")
end

function KCM:OnSpecChanged()
    requestRecompute("spec_changed")
    -- The Stat Priority page's retrack-to-current-spec behavior is a panel
    -- concern, so it is published as SPEC_CHANGED and handled by the options
    -- layer's own receiver rather than reached into from here (architecture-§4).
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
    -- Any macro-bar work requested during the fight (build, relayout, restyle)
    -- was deferred because it anchors protected frames. Apply it now.
    if KCM.MacroBar and KCM.MacroBar.FlushPending then
        KCM.MacroBar.FlushPending()
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
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN",         "OnCooldownUpdate")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN",           "OnCooldownUpdate")
end
