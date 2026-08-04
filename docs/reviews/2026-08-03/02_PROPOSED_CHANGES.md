# 02 — Proposed changes (HLD + LLD)

**Standard resolved:** Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**. `STANDARDS.md` fetched from the canonical raw URL; section files read from the local clone of the same repo at `master` / `2141229` (byte-identical index). Every proposed change below was checked against `anti-patterns`, `architecture`, `events-frames-taint`, `options-ui`, `slash-commands`, `debug-logging`, `library-stack`, `performance`, `localization` and `testing`.

**Upstream change-set: none.** No defect in this review lives under `libs/` or `tests/_kit/`. `tests/test_vendor_sync.lua` confirms both vendored payloads are byte-identical to the LibKa0s v1.5.0 tag the README names, so there is nothing to route to the library repo and nothing in this document targets a vendored path.

---

## HLD — themes

### Theme A — Make the combat-deferral queue self-describing (F-001, F-006)

**Rationale.** `commitMacro` was extracted to be the one macro-write tail, but `SetCompositeMacro` re-implements it and the two copies now disagree on the pending-entry shape. That disagreement is not cosmetic: it is the direct cause of F-001, because `FlushPending` can only re-dispatch what the entry told it. The fix is to collapse the second copy back into the first and to make the queued entry carry enough information to replay itself — which removes the whole class of "flush rebuilt the wrong body" bug rather than patching the weapon-enchant instance of it.

**Alternative rejected — special-case `perHand` in `FlushPending`.** Adds a third branch beside `composite`/`plain` and leaves the duplicated ladder in place, so the next category shape (there have been four in two releases) reopens the bug. Also grows a second macro-write path, which is the in-repo form of what anti-pattern #47 forbids across repos.

**Alternative rejected — replay `entry.body` verbatim without recomputing.** Simplest, but wrong: picks can change between the deferral and the regen (the player drinks the potion mid-fight), and the fingerprint/`macroState` bookkeeping in `commitMacro` assumes a freshly-derived body. Keep the recompute, fix the dispatch.

**Trade-off.** `commitMacro` grows one optional parameter. Accepted — one seam with a parameter beats two seams that drift.

### Theme B — Make the degraded (LibKa0s-absent) install keep its documented contract (F-002, F-007)

**Rationale.** The addon's degradation story is explicit and good: chat still works, the CLI still works, only the chrome is gone. Two seams break it — `settings/Panel.lua` calls two library-bound refresh functions unconditionally, and `modules/PerfSetup.lua` calls a DebugLog member the DebugLog stub withholds on purpose. Both fixes are inert host-side guards, which is exactly the shape `library-stack-§5` prescribes for the addon's half of a seam.

**Alternative rejected — implement local refresh tiers when the library is absent.** That is anti-pattern #47 verbatim ("just implement it locally"). With no panel registered (`settings/Panel.lua:765-768`) there is nothing to refresh, so a no-op is not a degradation, it is the correct answer.

**Alternative rejected — publish a no-op `AddLine` on the DebugLog stub.** Also anti-pattern #47's failure mode in the other direction, and specifically harmful here: `core/Debug.lua:40-45` probes `KCM.DebugLog.AddLine` to decide whether a console exists, so a no-op stub member would swallow every diagnostic while the addon looked healthy. The stub's omission is load-bearing and stays.

### Theme C — Route the last two schema-backed writes through the single write path (F-004)

**Rationale.** `architecture-§5` makes `NS.Schema:Set` the one mutation seam for every schema row, and this addon implements it correctly (`settings/Panel.lua:609-628`) — `/cm bar` is the one surface that reaches around it, and the visible cost is a stale checkbox on an open page, precisely what `options-ui-§11`'s in-place tier exists to prevent.

**Alternative rejected — have `MB.SetEnabled` call `RefreshScalars` itself.** Restores the widget sync but leaves two write paths for one row (validation and `onChange` still bypassed), which is the drift `architecture-§5` legislates against.

### Theme D — Stop paying login-cost work on every loading screen (F-005)

**Rationale.** `PLAYER_ENTERING_WORLD` is a per-loading-screen event, not a per-session one, and the handler's own comment says otherwise. The TTL sweep is idempotent within a session, and it re-scans bags the discovery pass just scanned. `performance` (hot-path/init-cost) and the event's own `isInitialLogin`/`isReload` payload give the compliant fix for free.

### Theme E — Correctness and hygiene follow-ups (F-003, F-008, F-009 – F-016)

Independent, small, individually shippable. Grouped so they can be parallelised against the themes above.

---

## LLD — change-set

Each change lists target file(s), the before→after shape, risk, and the finding IDs it closes. Every change ends with its **standards conformance** note.

---

### C-01 — Self-describing pending entries + one macro-write tail
**Covers:** F-001, F-006 · **Files:** `modules/MacroManager.lua` · **Risk:** medium (touches the only protected-API caller)

1. Extend `commitMacro` with an explicit icon override so a composite can use it:

```lua
-- before
local function commitMacro(macroName, body, iconItemID, catKey)
    ...
    local icon = iconFor(effectiveItemID)

-- after
-- `opts` is optional: { icon = <fileID>, cat = <category row>, replay = <fn> }
local function commitMacro(macroName, body, iconItemID, catKey, opts)
    ...
    local icon = (opts and opts.icon) or iconFor(effectiveItemID)
```

2. Store the replay discriminator on the queued entry, for **every** shape:

```lua
pendingUpdates[macroName] = {
    body     = body,
    itemID   = iconItemID,
    catKey   = catKey,
    cat      = opts and opts.cat,      -- composite AND per-hand now set this
    kind     = opts and opts.kind or "single",   -- "single" | "composite" | "perHand"
    attempts = attempts,
}
```

3. `SetWeaponEnchantMacro` passes `{ cat = cat, kind = "perHand" }`; `SetCompositeMacro` is rewritten to *build its body and call `commitMacro`* with `{ cat = cat, kind = "composite", icon = effectiveActive and DYNAMIC_ICON or DEFAULT_ICON }`, deleting lines `438-495`.

4. `FlushPending` dispatches on `entry.kind`:

```lua
if entry.kind == "composite" then
    ok, result = pcall(M.SetCompositeMacro, entry.cat, nil)
elseif entry.kind == "perHand" then
    local mh = KCM.Selector.PickBestForSlot(entry.catKey, 16)
    local oh = KCM.Selector.PickBestForSlot(entry.catKey, 17)
    ok, result = pcall(M.SetWeaponEnchantMacro, entry.cat, mh, oh)
else
    ok, result = pcall(M.SetMacro, name, entry.itemID, entry.catKey)
end
```

**Risk notes.** `FlushPending` mutates `pendingUpdates` while iterating it; the existing code is safe only because every write targets a key that already exists. Preserve that — do not introduce a new key inside the loop. Keep the `MAX_FLUSH_ATTEMPTS` bound and the `"deferred"` re-queue branch untouched.

**Standards conformance.** Keeps `events-frames-taint-§4`'s single-caller firewall (still one module, still one `doEdit`) and its "MUST NOT call protected APIs from handlers that can fire in combat" (the `InCombatLockdown()` gate and the `PLAYER_REGEN_ENABLED` replay are unchanged). Rejected alternative "add a third write path in `FlushPending`" was dropped for the reason anti-pattern #47 gives for parallel implementations. `testing` requires a covering test — see T-01/T-02 in `04_EXECUTION_PLAN.md`.

---

### C-02 — Inert refresh fallbacks on the LibKa0s-absent path
**Covers:** F-002 · **Files:** `settings/Panel.lua` · **Risk:** low

```lua
-- settings/Panel.lua, replacing lines 571-572
Helpers.RefreshAllPanels = UI and UI.RefreshAllPanels or function() end
Helpers.RefreshScalars   = UI and UI.RefreshScalars   or function() end
```

Apply the same treatment to the other library-bound `Helpers.*` members that are called from paths reachable without a panel — audit list: `Helpers.SetRenderer` (`:351`), `Helpers.ResetScroll` (`:361`), `Helpers.Grid` (`:519`), `Helpers.CustomCheckbox` (`:527`), `Helpers.RenderField` (`:458`), `Helpers.AttachTooltip` (`:278`). All of those are reached **only** from inside a page renderer, which never runs when `libAbsent` (`settings/Panel.lua:765-768`) — so leave them nil and add a one-line comment recording *why* only the two refresh binders needed guarding. That distinction is the point of the change; blanket-stubbing everything would hide a real future break.

Then correct the invariant comment at `settings/Panel.lua:166-167` to say what is now true.

**Risk notes.** Zero behaviour change on a healthy install (`UI` is truthy, so the `or` never fires).

**Standards conformance.** `library-stack-§5`/anti-pattern #47: the fix is a host-side stub, not a local re-implementation of the library's refresh tiers, and not an edit under `libs/`. `options-ui-§11`'s two-tier model is untouched on the live path.

---

### C-03 — Guard the Perf descriptor's DebugLog thunk
**Covers:** F-007 · **Files:** `modules/PerfSetup.lua` · **Risk:** low

```lua
-- before
log     = function(line) KCM.DebugLog.AddLine("Perf", line) end,
-- after
log     = function(line)
    local DL = KCM.DebugLog
    if DL and DL.AddLine then DL.AddLine("Perf", line) end
end,
```

Add a comment naming the partial-vendor scenario (anti-pattern #48) so the guard is not "simplified" away later. `showLog` needs no change — the DebugLog stub does publish `Show`.

**Standards conformance.** `library-stack-§7` / anti-pattern #48 is the motivating rule; the remedy is entirely in the addon's own setup file. No stub member is added (see Theme B's rejected alternative).

---

### C-04 — `/cm bar` writes through `KCM.Schema:Set`
**Covers:** F-004 · **Files:** `core/SlashCommands.lua` (BAR_COMMANDS, `runBar`) · **Risk:** low

```lua
-- before
{"on",  "Show the macro bar",
    function() KCM.MacroBar.SetEnabled(true); say("macro bar |cff00ff00ON|r") end},
-- after
{"on",  "Show the macro bar",
    function() KCM.Schema:Set("macroBar.enabled", true); say("macro bar |cff00ff00ON|r") end},
```

Same for `off`, `lock`, `unlock` and the bare-`/cm bar` toggle in `runBar` (`core/SlashCommands.lua:1112-1116`). `MB.SetEnabled` / `MB.SetLocked` stay — they are what `settings/MacroBar.lua`'s row `onChange` calls, and they keep the in-combat notice. `reset` (position) is unchanged: `macroBar.point/x/y` are deliberately not schema rows.

**Risk notes.** `KCM.Schema:Set` returns false for an unknown path; the schema rows exist (`settings/MacroBar.lua:58`, `:70`) and `settings/` loads before any slash invocation, so this cannot regress. Watch for double-notice: the row's `onChange` → `SetEnabled` may emit the in-combat line the slash handler used to own; keep exactly one.

**Standards conformance.** `architecture-§5` ("MUST route every mutation through one helper … Panel and slash both call this"); `slash-commands` keeps the verb grammar unchanged; `options-ui-§11` gets its in-place widget re-sync for free via `SetAndRefresh` → `RefreshScalars`.

---

### C-05 — Gate session-scoped work on `isInitialLogin` / `isReload`
**Covers:** F-005 · **Files:** `core/ConsumableMaster.lua`, `modules/Selector.lua` · **Risk:** low

```lua
-- before
function KCM:OnPlayerEnteringWorld()
    -- Fires on login and /reload. Discover + recompute everything.
    runAutoDiscovery("player_entering_world")
    if KCM.Selector and KCM.Selector.SweepStaleDiscovered then
        KCM.Selector.SweepStaleDiscovered(time())
    end
    requestRecompute("player_entering_world")

-- after
-- Fires on login, /reload AND every loading screen (zone change, instance
-- entry). Only the first two need the session-scoped passes.
function KCM:OnPlayerEnteringWorld(event, isInitialLogin, isReload)
    local sessionStart = isInitialLogin or isReload
    local counts = runAutoDiscovery("player_entering_world")   -- returns bag counts too
    if sessionStart and KCM.Selector and KCM.Selector.SweepStaleDiscovered then
        KCM.Selector.SweepStaleDiscovered(time(), counts)
    end
    requestRecompute("player_entering_world")
```

`SweepStaleDiscovered(nowUnix, bagCounts)` takes the counts as an optional second argument and only calls `BagScanner.Scan()` when they are absent, keeping every existing caller and test working.

**Risk notes.** Keep `runAutoDiscovery` on every PEW — a zone change can follow a mail/vendor pickup — it is the double-scan and the sweep that are being removed from the hot path. `modules/PerfSetup.lua`'s `resume()` does not touch this handler.

**Standards conformance.** `performance` (do not repeat init-cost work per event); `events-frames-taint-§1` unchanged (still AceEvent, still one registration in `OnEnable`).

---

### C-06 — Resolve a real icon for composite macro-bar slots
**Covers:** F-003 · **Files:** `core/MacroDisplay.lua` · **Risk:** low

Treat the `?` sentinel as "unresolved" in the display seam, and resolve composites from their first enabled sub-category's pick:

```lua
-- core/MacroDisplay.lua
local DYNAMIC_ICON = 134400   -- MacroManager's "let #showtooltip decide" sentinel

function MD.Texture(macroName)
    local tex = MD.TextureForID(MD.PickID(macroName))
    if tex then return tex end
    -- Composite macros store no lastItemID and carry the ? sentinel as their
    -- macro icon, which only means something on a Blizzard action bar. Resolve
    -- from the composite's own current picks instead.
    local sub = MD.CompositePickID(macroName)      -- new, nil for non-composites
    if sub then
        local subTex = MD.TextureForID(sub)
        if subTex then return subTex end
    end
    local idx = MD.MacroIndex(macroName)
    if idx ~= 0 and GetMacroInfo then
        local _, icon = GetMacroInfo(idx)
        if icon and icon ~= DYNAMIC_ICON then return icon end
    end
    return MD.FALLBACK_ICON
end
```

`MD.CompositePickID` maps the macro name back to its category (`KCM.MacroBarModel.KeyForMacroName`), reads `cat.composite`, and returns the first `Selector.PickBestForCategory(ref)` over the configured `orderInCombat` then `orderOutOfCombat` refs — the same precedence `MacroManager.buildCompositeBody` uses.

**Risk notes.** Called from the bar's per-refresh path, so keep it allocation-free and early-return for non-composites. `MD.SetTooltip` gets the same benefit for free if it reuses `CompositePickID`; decide deliberately — a composite tooltip showing only its first component may be more confusing than the current name+body fallback. Recommendation: icon yes, tooltip no.

**Standards conformance.** Stays inside the existing display-resolution seam (`architecture-§3` module boundaries); no protected API is touched, so the combat contract is unaffected.

---

### C-07 — Combat-guard the drag pickup (pending verification)
**Covers:** F-008 · **Files:** `modules/MacroBarButton.lua`, `modules/KCMMacroDragIcon.lua` · **Risk:** low

**Do the verification first** (`03_SMOKE_TESTS.md` § C-07). If the in-combat drag produces a blocked-action error:

```lua
btn:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then
        KCM.Say("|cff808080in combat — dragging a macro off the bar is blocked until combat ends|r")
        return
    end
    local idx = KCM.MacroDisplay and KCM.MacroDisplay.MacroIndex(macroName(self.catKey)) or 0
    if idx ~= 0 and PickupMacro then PickupMacro(idx) end
end)
```

Either way, correct the header comment at `modules/MacroBarButton.lua:22-24` to state the verified answer rather than an assertion.

**Standards conformance.** `events-frames-taint-§2` mandates `InCombatLockdown()` (not `UnitAffectingCombat`) for a gate on a protected operation, and the gray one-line chat notice matches the pattern already used at `settings/Panel.lua:56-58` and `modules/MacroBar.lua:431`.

---

### C-08 — Hygiene bundle
**Covers:** F-009, F-010, F-011, F-012, F-013, F-014 · **Files:** as listed · **Risk:** low

| # | Change | File |
|---|---|---|
| a | Delete `DL.RefreshHeader`, `DL.ShowCopy`, `MB.IsShown` (or add covering tests if the facade is meant to be complete) | `modules/DebugLog.lua:186-187`, `modules/MacroBar.lua:288` |
| b | Correct the stale `IsWindowShown` clause | `modules/DebugLog.lua:88-91` |
| c | Funnel both `PANEL_REFRESH` publishes through one local `publishPanelRefresh()`; document the event-layer sender in the message table | `core/ConsumableMaster.lua:310`, `:559`; `docs/ARCHITECTURE.md:79` |
| d | Soften the Bus.lua header to match `docs/ARCHITECTURE.md:93` | `core/Bus.lua:3-5` |
| e | `ValidateSchema` also resolves each row's `path` against `KCM.dbDefaults.profile` and counts mismatches as errors | `settings/Panel.lua:136-158` |
| f | Hoist the `KCM.db` guard into `statPrimary` / `statSecondary` | `core/SlashCommands.lua:814`, `:850` |

**Standards conformance.** (c) satisfies `architecture-§4`'s "document each message with … sender (one), all consumers"; (e) satisfies `architecture-§5`'s boot-validation MUST; (a) keeps `public-api` honest — an export with no caller is an unowned surface. None of these introduce a new deviation.

---

### C-09 — Bound the TooltipCache pending retry
**Covers:** F-015 · **Files:** `core/TooltipCache.lua` · **Risk:** medium (touches the ranking substrate)

Add an attempt counter to the pending stub; after N unproductive re-parses (suggest 5, or "no change after the second `GET_ITEM_INFO_RECEIVED` for that ID"), cache the parse as **final** with a `unparsed = true` marker instead of `pending = true`. `TC.IsUsableByPlayer` keeps returning its level verdict; the Ranker keeps scoring the item on `ilvl`+`quality` alone, which is what it does today anyway for an unparsed item.

**Risk notes.** The retry exists to catch a genuinely late tooltip body (`core/TooltipCache.lua:455-469` documents the augment-rune mis-ranking it fixed). Set the ceiling generously and keep `TC.Invalidate(itemID)` clearing the counter, so a real `GET_ITEM_INFO_RECEIVED` still re-arms a full parse.

**Standards conformance.** This is a bounded-retry fix, **not** a change to the English-only parsing decision — that deviation is documented in `docs/scope.md` and is the standards-audit's territory, not this review's. `performance`'s "no unbounded per-event work" is the rule being satisfied.

---

### C-10 — Honour `ActionButtonUseKeyDown`
**Covers:** F-016 · **Files:** `modules/MacroBarButton.lua`, `modules/MacroBarFlyout.lua` · **Risk:** low-medium (secure re-registration)

Read `GetCVarBool("ActionButtonUseKeyDown")` at button build and register `"AnyDown"` or `"AnyUp"` accordingly; re-register from the existing `MB.Update` path on `CVAR_UPDATE` for that cvar, **out of combat only** (re-registering clicks on a secure button is a protected operation — route it through the existing `pendingUpdate` deferral rather than adding a second combat gate).

**Standards conformance.** `events-frames-taint-§2` — the re-registration is a secure write and takes the existing `InCombatLockdown()` + `PLAYER_REGEN_ENABLED` replay path (`modules/MacroBar.lua:354-387`), not a new one.
