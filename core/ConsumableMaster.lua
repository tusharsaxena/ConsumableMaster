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

    -- THE `disabled` HOLD, TAKEN FROM THE STORED PATH, and taken HERE because
    -- this is the first moment the path can be read: AceDB built the profile one
    -- line above. It is not a special case -- it is the same call the checkbox
    -- and `/cm disable` make (core/LifecycleSetup.lua's KCM.OnEnabledChanged),
    -- which is what stops "disabled at login" and "disabled by the player" being
    -- two code paths that can disagree.
    --
    -- BEFORE AceAddon calls KCM:OnEnable, which is what makes the guard at the
    -- foot of this file the whole of the login story: a player who logs in with
    -- the addon off never registers an event in the first place.
    if KCM.OnEnabledChanged then
        KCM.OnEnabledChanged(not (self.db.profile and self.db.profile.enabled == false))
    end

    -- PROFILE CALLBACKS (options-ui-§12). Defined below, beside `afterReset` --
    -- the resync they run -- and reached as a FIELD so the call resolves at run
    -- time rather than needing the local in lexical scope up here.
    if KCM.RegisterProfileCallbacks then KCM.RegisterProfileCallbacks(self) end

    -- The launcher, AFTER the db exists and the migrations have run
    -- (launcher-§1). core/LauncherSetup.lua hands the library a THUNK for
    -- `db.global.minimap` precisely so this is the moment the table is read:
    -- AceDB built it three lines above and a table captured at file load would
    -- be one this one replaced. Idempotent by the library's own contract, so a
    -- second call from a login handler cannot draw a second button.
    --
    -- Nil on a degraded install -- core/LauncherSetup.lua publishes no stub,
    -- exactly as core/PerfSetup.lua publishes none.
    if KCM.Launcher then KCM.Launcher:Register() end
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

-- Master enable, ASKED OF THE LATCH rather than of the stored flag.
--
-- Through 1.6.2 this function was the stored flag's ONLY consumer in the whole
-- addon, which is what made `disabled` a draw gate: nine events stayed
-- registered, the bus stayed subscribed and the macro bar stayed on screen,
-- while this one read skipped the macro write pass (anti-pattern #85). The flag
-- now drives core/LifecycleSetup.lua's latch, and by the time a recompute could
-- reach here while disabled there is no longer a bus subscription to carry it.
--
-- It is kept, and it reads the LATCH, so that the `perf` hold gates the write
-- pass too: a capture's suspended arm must not rewrite macros either, and one
-- question with one answer is the whole point of the latch. The stored-flag read
-- stays as the fallback for a build with no LibKa0s and therefore no latch.
local function macrosEnabled()
    if KCM.IsStoodDown and KCM.IsStoodDown() then return false end
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
-- buckets, stat-priority overrides, and the master enable flag. The profile
-- reset empties macroState with everything else; the resync below re-issues
-- every macro, which rebuilds each fingerprint, so live macros stay valid.
-- Shared by the Options panel's
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
---
--- ONE REACTION, FOR ALL THREE EVENTS, in this order:
---
---   1. the act's one log line (below);
---   2. the migrations, for an incoming profile an older build wrote;
---   3. on a switch or a copy, the macro FINGERPRINTS are forgotten. The macros
---      are account-wide and `macroState` is per profile, so the incoming
---      profile's fingerprints describe the bodies IT last wrote -- not what the
---      account's macros hold now, which is the outgoing profile's. Where the two
---      happen to agree, MacroManager's "unchanged" early-out would skip the write
---      and leave the outgoing profile's body live. A reset needs nothing here: it
---      empties `macroState` with the rest of the profile;
---   4. the resync, which rewrites every macro against the incoming profile;
---   5. PROFILE_CHANGED on the bus, the message this addon's surfaces rebuild off
---      (options-ui-§12). AFTER the resync, so the macro bar re-applies itself
---      against macros that already carry the incoming profile's bodies. The
---      pipeline's MACROBAR_REFRESH is not enough on its own: it repaints icons
---      and counts, and a new profile brings a new anchor, grid, slot order,
---      shown set, lock and enable state, which only MacroBar.Update applies.
function KCM.RegisterProfileCallbacks(target)
    local db = target and target.db
    if not (db and db.RegisterCallback) then return end

    -- The one log line a profile-wide act gets (debug-logging-§10): AceDB replaced
    -- the whole profile, which is not a batch through the helper, so the HANDLER
    -- logs it, worded by the event. Its line is the whole act, so it silences any
    -- Helpers.Bulk bracket open around it: one line in total, never this one plus
    -- an `outer: N rows`. A reset and a copy replace the profile's rows and carry
    -- the [Set] tag; a switch rewrites no rows and takes the `[Profile]` trace
    -- MultiMeters and KickCD carry.
    --
    -- No row count on the reset: N means the rows the reset actually changed,
    -- which needs their values from before it. AceDB has already replaced the
    -- profile when OnProfileReset fires, and AceDBOptions' Reset Profile button
    -- gives no earlier hook to take them from.
    local function trace(event, d, key)
        local H = KCM.Settings and KCM.Settings.Helpers
        if H and H.SilenceOpenBulk then H.SilenceOpenBulk() end
        if not isDebugOn() then return end
        local name = d and d.GetCurrentProfile and d:GetCurrentProfile()
        if event == "OnProfileReset" then
            KCM.Debug("Set", "reset profile '%s' to defaults", tostring(name))
        elseif event == "OnProfileCopied" then
            KCM.Debug("Set", "copied profile '%s' → '%s'", tostring(key), tostring(name))
        else
            KCM.Debug("Profile", "switched to '%s'", tostring(name))
        end
    end

    local FORGETS_FINGERPRINTS = { OnProfileChanged = true, OnProfileCopied = true }

    local function reload(reason)
        return function(event, d, key)
            trace(event, d, key)
            -- THE LATCH FIRST, because the incoming profile can carry a
            -- different `enabled` and everything below it is a feature: the
            -- resync writes macros and the bus message repaints surfaces, and
            -- neither may run for a profile that arrives switched off. A switch
            -- INTO an enabled profile stands the addon up here, so the resync
            -- below runs against live registrations rather than into the void
            -- (slash-commands-§7's "the AceDB profile callbacks survive").
            if KCM.ReevaluateEnabled then KCM.ReevaluateEnabled() end
            if KCM.Database and KCM.Database.RunMigrations then
                KCM.Database.RunMigrations()
            end
            if FORGETS_FINGERPRINTS[event] and KCM.MacroManager and KCM.MacroManager.InvalidateState then
                KCM.MacroManager.InvalidateState()
            end
            afterReset(reason)
            if KCM.bus and KCM.bus.SendMessage and KCM.MSG then
                KCM.bus:SendMessage(KCM.MSG.PROFILE_CHANGED, reason)
            end
        end
    end

    db.RegisterCallback(target, "OnProfileChanged", reload("profile_changed"))
    db.RegisterCallback(target, "OnProfileCopied",  reload("profile_copied"))
    db.RegisterCallback(target, "OnProfileReset",   reload("profile_reset"))
end

--- Restore every SESSION-ONLY schema row to its default.
---
--- options-ui-§12 makes this half of the global reset a MUST, and it is the half a
--- profile reset by construction cannot do: a session-only row's storage is its own
--- `set()` (settings/Panel.lua's SESSION_PATHS), not the db, so `db:ResetProfile()`
--- cannot reach it and the row outlives a reset that took everything around it. The
--- debug console's visibility is the addon's only such row today, and the sweep is
--- written off the `sessionOnly` FLAG rather than off that one path so a second one
--- is covered the day it is declared.
---
--- Reached through KCM.Settings at CALL time and silent when it is not there: this
--- file loads long before settings/, and on a degraded load (no LibKa0s / AceGUI)
--- there is no schema to walk and nothing session-only to restore.
---
--- WHICH ROWS is the shared veto's call, not this loop's: settings/OptionsSetup.lua
--- names it once as KCM.Settings.VetoedFromResetAll and hands the same function to
--- the library as its descriptor's `skipRestoreAll` (options-ui-§3). It refuses
--- the Profiles page and every profile-resident row, which leaves exactly the
--- session rows. This is the only reset loop the addon runs, on the degraded arm
--- as on the live one, so it is the one the rule's "shared with the degradation
--- stub's own reset loop" means.
local function restoreSessionRows()
    local S = KCM.Settings
    local H = S and S.Helpers
    local vetoed = S and S.VetoedFromResetAll
    if not (H and H.Set and S.Schema and vetoed) then return end
    for _, row in ipairs(S.Schema) do
        if not vetoed(row) and row.default ~= nil then
            H.Set(row.path, row.default)
        end
    end
end

--- Reset the ACTIVE PROFILE to the shipped defaults, and the same act as
--- AceDBOptions' own Reset Profile (options-ui-§12).
---
--- The resync is NOT called from here any more. `db:ResetProfile()` fires
--- OnProfileReset, and the handler KCM:OnInitialize registers runs `afterReset` --
--- so the invalidate → discover → recompute pass happens on exactly one path,
--- which is the path a profile SWITCH takes too. Calling it here as well would run
--- the pipeline twice for one action.
---
--- THE SESSION SWEEP RUNS FIRST, and it lives HERE rather than at either door so the
--- two doors cannot diverge: the Master controls tab's [Reset all settings] and
--- `/cm resetall` are one act, and the addon's own note in settings/General.lua that
--- "every execute path is shared with the slash commands" is only true while the
--- whole act is behind this one function. First, not last, for the reason the
--- library's own `O.RestoreAllDefaults` orders it that way (libs/LibKa0s/Options.lua):
--- ResetProfile fires OnProfileReset, whose handler repaints, and a sweep afterwards
--- would be writing into a panel that had already been drawn from the old value.
---
--- ONE LOG LINE for the whole act (debug-logging-§10): the OnProfileReset
--- handler's `[Set] reset profile '<name>' to defaults`. Both halves run inside
--- Helpers.MuteSetLog, so the session sweep's own write logs no row, and no line
--- is added here. `reason` is the caller's audit tag and is no longer logged.
function KCM.ResetAllToDefaults(reason)
    if not (KCM.db and KCM.db.ResetProfile) then return false end
    local function act()
        restoreSessionRows()
        KCM.db:ResetProfile()
    end
    local H = KCM.Settings and KCM.Settings.Helpers
    if H and H.MuteSetLog then H.MuteSetLog(act) else act() end
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
    -- THE PENDING STAND-DOWN, FINISHED AND RELEASED (slash-commands-§7).
    -- A disable that landed mid-fight could not touch the bar's state driver or
    -- its anchors, so core/LifecycleSetup.lua parked the job and re-registered
    -- this one event to come back on. Finish the bar — its own show ladder
    -- already answers no — and then drop the registration, which is the last one
    -- a disabled addon holds. No macro flush: a pending macro write is a feature,
    -- and the incoming body is recomputed from current state on the way back up.
    if KCM.IsStoodDown and KCM.IsStoodDown() then
        if KCM.MacroBar and KCM.MacroBar.FlushPending then KCM.MacroBar.FlushPending() end
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
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
    -- No settings replay here: a category registration refused under lockdown
    -- is parked by LibKa0s-Options-1.0 and replayed on its own frame, whatever
    -- the stand-down state (settings/Panel.lua's registerPanel).
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

-- THE REGISTRATION LIST, and the one place it is written down. The latch's
-- `standUp` CALLS this rather than copying it, and `standDown` drops the lot
-- with UnregisterAllEvents, so the two can never name different sets.
--
-- IT REFUSES TO RUN WHILE A HOLD IS TAKEN, and that is not a draw gate: it is
-- the door, not a handler. AceAddon calls OnEnable after OnInitialize, which is
-- where the `disabled` hold is taken from the stored path, so a player who logs
-- in with the addon off registers NOTHING — rather than registering nine events
-- and having them torn down a frame later, which is a race the perf harness can
-- land in the middle of.
function KCM:OnEnable()
    if KCM.IsStoodDown and KCM.IsStoodDown() then return end
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
