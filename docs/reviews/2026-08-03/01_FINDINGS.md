# 01 — Findings (review of 2026-08-03)

**Addon:** Ka0s Consumable Master (`ConsumableMaster`), v1.5.0, Interface 120007
**Scope:** whole repo (`core/`, `modules/`, `settings/`, `defaults/`, `locales/`, `tests/`, TOC, docs). `libs/` and `tests/_kit/` are vendored and read-only — reviewed only for defects that would be routed upstream.
**Verdict:** **minor issues** — the addon is architecturally strong, well-tested and standards-aligned; two High findings are real functional/robustness bugs on paths the suite does not reach (combat-deferred weapon-enchant flush, and the LibKa0s-absent degradation path).

## Standards cross-check

Performed. Resolved standard version: **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**.
`STANDARDS.md` was fetched over the network from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`; the per-section fetch loop timed out, so the section files were read from the **local clone of the same repo** at `master` / commit `2141229` (clean working tree), whose `STANDARDS.md` is byte-identical to the fetched copy. Every section listed in the index's Sections map was read. No rule text was reconstructed from memory.

## What is clean

Called out because a review that only lists defects misrepresents this codebase:

- **Protected-API firewall holds.** `modules/MacroManager.lua` is the sole caller of `CreateMacro`/`EditMacro` (`grep` confirms zero other call sites), and every write is gated on `InCombatLockdown()` with a `PLAYER_REGEN_ENABLED` flush (`modules/MacroManager.lua:342`, `:469`, `:506`) — `events-frames-taint-§4`.
- **Secure-frame discipline on the macro bar is exemplary.** Slot→macro binding is stamped once at creation and never rewritten (`modules/MacroBarButton.lua:318-319`); combat-conditional visibility is a `RegisterStateDriver`, not `Show`/`Hide` (`modules/MacroBar.lua:244-260`); flyout open/close is a `SecureHandlerEnterLeaveTemplate` snippet with an attribute-driver combat probe (`modules/MacroBarFlyout.lua:57-83`, `:286-288`).
- **Secret-value handling is correct and current.** Cooldowns are read through `isActive`/`isEnabled` (NeverSecret) plus a duration object, never by comparing a secret (`core/MacroDisplay.lua:114-127`); the GCD-suppression step curve is evaluated C-side (`modules/MacroBarButton.lua:112-187`); every chat arg routes through `KCM.SafeToString` (`core/CoreSetup.lua`) — `events-frames-taint-§8`, anti-pattern #35.
- **No deprecated APIs on a live path.** Every legacy global (`GetSpellInfo`, `GetItemInfo`, `GetSpecialization*`) is either behind `core/Compat.lua` or is an explicit last-resort fallback after the `C_*` form. `C_Container.*`, `C_AddOns.*`, `C_TooltipInfo.*`, `Settings.RegisterCanvasLayoutCategory` are all the modern shapes. `LEARNED_SPELL_IN_SKILL_LINE` (not the removed `LEARNED_SPELL_IN_TAB`) is registered.
- **Bus receivers are correct.** Each receiver owns a private `KCM.NewBusTarget()` (`core/Bus.lua:38`, `settings/Panel.lua:915`, `modules/MacroBar.lua:448`); no two receivers share a target — anti-pattern #32 is not present.
- **LibKa0s adoption is a descriptor+stub seam, not a fork.** Five majors (Core, DebugLog, Slash, Options, Perf) are consumed via `core/CoreSetup.lua`, `modules/DebugLog.lua`, `core/SlashCommands.lua:1305`, `settings/Panel.lua:192`, `modules/PerfSetup.lua`. Thunked printers everywhere, colour codecs supplied, `skin` deliberately not overridden. No hand-rolled console / dispatcher / widget makers survive.
- **Gates are green.** `lua tests/run.lua` → **600 passed, 0 failed**. `luacheck .` → **0 warnings / 0 errors in 52 files**. `tests/test_vendor_sync.lua` confirms `libs/LibKa0s/` and `tests/_kit/` are byte-identical to the LibKa0s v1.5.0 tag the README claims (anti-pattern #45/#48 clear).
- **No upstream (`libs/`, `tests/_kit/`) defects found.** Nothing in this review lands outside this repo.

---

## High

### F-001 — A weapon-enchant macro deferred in combat is flushed with the wrong body `[logic]`

`modules/MacroManager.lua:402-409` (queue) → `modules/MacroManager.lua:506-521` (flush)

`SetWeaponEnchantMacro` builds a two-hand body (`/use item:N` + `/use 16`, `/use 17`) and hands it to `commitMacro`, which — in combat — queues `{ body, itemID = mhPick or ohPick, catKey }` **without the `cat` marker that composite entries carry** (`modules/MacroManager.lua:347-352` vs `:471-477`). `FlushPending` then branches on `entry.cat and entry.cat.composite` only, so the weapon-enchant entry falls to `M.SetMacro(name, entry.itemID, entry.catKey)`, which rebuilds the body through `M.BuildBody` → `buildActiveBody` and produces a plain single-item `#showtooltip\n/use item:N`.

**Impact:** after any combat during which the weapon-enchant pick changed, `KCM_WPN_ENCH` loses its `/use 16` / `/use 17` slot lines and the off-hand entirely — clicking it raises the "apply to which weapon" targeting cursor instead of enchanting, and the failure persists until the next out-of-combat recompute changes the body again. Not covered by the suite (no test flushes a per-hand queue entry).

**Fix direction:** make the pending entry self-describing — carry the already-built `body` (or the `cat` + a `kind` discriminator) through the flush instead of rebuilding from `itemID` alone. Keep the single write seam (`commitMacro`) rather than adding a third macro-write path; anti-pattern #47's "don't grow a parallel implementation" logic applies inside the addon too.

### F-002 — On a LibKa0s-absent install, `/cm set` and `/cm debug on` raise a Lua error `[logic]`

`settings/Panel.lua:571-572`, `:609-622`, `:808-811`

`Helpers.RefreshAllPanels` and `Helpers.RefreshScalars` are bound as `UI and UI.RefreshAllPanels` / `UI and UI.RefreshScalars`, so both are **nil** when `LibStub("LibKa0s-Options-1.0", true)` returns nil (`settings/Panel.lua:186`, `:254`). But they are then called unconditionally:

- `Helpers.SetAndRefresh` → `Helpers.RefreshScalars()` (`settings/Panel.lua:620`) — reached by every `/cm set <path> <value>` (`core/SlashCommands.lua:1328`) and every `/cm reset <path>` (`:1334`).
- `O.Refresh` → `Helpers.RefreshAllPanels()` (`settings/Panel.lua:810`) — reached by the DebugLog degradation stub's `SetEnabled` (`modules/DebugLog.lua:81`), i.e. by `/cm debug on|off`, and by `afterMutation` on every `/cm priority|stat|aio` mutation (`core/SlashCommands.lua:101-103`).

This directly contradicts the invariant the file states at `settings/Panel.lua:166-167`: *"None of it touches the library, which is what keeps `/cm list|get|set` working on an install where LibKa0s is missing."*

**Impact:** the documented degraded-install contract ("the panel is gone but every setting is still reachable from the CLI") is false — the first `/cm set` throws `attempt to call a nil value (field 'RefreshScalars')`, and `/cm debug on` throws on `RefreshAllPanels`. Invisible to the suite, which always builds the library instance.

**Fix direction:** give the two refresh bindings inert host-side fallbacks in the `libAbsent` branch (`Helpers.RefreshAllPanels = Helpers.RefreshAllPanels or function() end`), the same shape `core/CoreSetup.lua` and `modules/DebugLog.lua` already use for their absent-library paths. Do **not** re-implement the refresh tiers locally (anti-pattern #47) — a no-op is the correct degradation when there is no panel to refresh.

---

## Medium

### F-003 — Composite macro-bar slots always render the `?` question-mark icon `[ux]`

`modules/MacroManager.lua:488-493` (stores `lastItemID = nil`) → `core/MacroDisplay.lua:33-38`, `:57-66`

`SetCompositeMacro` deliberately stores `lastItemID = nil` for `HP_AIO` / `MP_AIO`, and stores `DYNAMIC_ICON` (`134400`, `INV_MISC_QUESTIONMARK`) as the macro icon so a Blizzard action bar lets `#showtooltip` resolve it. `MD.Texture` resolves pick-first, gets nil, then falls back to `GetMacroInfo(idx)`'s stored icon — which is that `?` sentinel. The custom macro-bar button draws the texture literally; there is no `#showtooltip` resolution on a non-action-bar frame.

**Impact:** the two AIO slots on the macro bar (both shipped visible by default) permanently display a question mark while every other slot shows its real item icon. Same for the settings panel's `KCMMacroDragIcon`.

**Fix direction:** have `MD.Texture` treat the `DYNAMIC_ICON` sentinel as "no icon" and fall through — for a composite, resolve the icon of the first enabled sub-category's current pick (the data `Selector.PickBestForCategory(ref)` already returns). Keep the resolution in `core/MacroDisplay.lua`, which is the single display-resolution seam, rather than teaching the button about composites.

### F-004 — `/cm bar on|off|lock|unlock` bypasses the single write path `[convention]`

`modules/MacroBar.lua:392`, `:404`; schema rows at `settings/MacroBar.lua:58-74`

`macroBar.enabled` and `macroBar.locked` are both declared schema rows, so `architecture-§5` makes `Helpers.SetAndRefresh` (`KCM.Schema:Set`) the single validate→write→onChange→refresh seam. `MB.SetEnabled` / `MB.SetLocked` instead write `c.enabled` / `c.locked` straight onto `db.profile.macroBar`. The panel→schema direction is fine (the row's `onChange` calls `SetEnabled`), but the slash direction skips `RefreshScalars`.

**Impact:** with the Macro Bar settings page open, `/cm bar off` hides the bar while the `[Enable macro bar]` checkbox stays checked until the page is rebuilt — the exact stale-widget class `options-ui-§11`'s two-tier refresh exists to prevent.

**Fix direction:** have `BAR_COMMANDS`' handlers call `KCM.Schema:Set("macroBar.enabled", …)` / `("macroBar.locked", …)` and let the row `onChange` reach `MB.SetEnabled`/`SetLocked` for the apply + in-combat notice, so both surfaces share one write path (`architecture-§5`). `MB.ResetPosition` / `savePosition` / `SwapSlots` are **not** in scope — `point`/`x`/`y`/`order` are deliberately not schema rows.

### F-005 — Full auto-discovery, a second bag scan and a TTL sweep run on every loading screen `[perf]`

`core/ConsumableMaster.lua:488-503`; second scan at `modules/Selector.lua:534`

`OnPlayerEnteringWorld` is commented *"Fires on login and /reload"*, which is wrong: `PLAYER_ENTERING_WORLD` also fires on every zone change, instance entry/exit and loading screen. Each firing runs `runAutoDiscovery` (a full `BagScanner.Scan` + `Classifier.MatchAny` over every bag item), then `SweepStaleDiscovered`, which does **another** full `BagScanner.Scan` (`modules/Selector.lua:534`) and walks every category bucket (including every `bySpec` sub-bucket) applying the 30-day TTL. The handler ignores the event's own `isInitialLogin` / `isReload` payload.

**Impact:** a measurable stall on every dungeon/raid/zone transition that scales with bag size and profile age, for work whose only necessary trigger is a session start — the TTL sweep in particular cannot produce a different answer twice in one session.

**Fix direction:** take `(event, isInitialLogin, isReload)` on the handler and gate `SweepStaleDiscovered` (and ideally the bulk discovery pass, leaving the `requestRecompute`) on `isInitialLogin or isReload`; have the sweep accept the `bagCounts` the discovery pass already computed rather than re-scanning. Correct the comment in the same change.

### F-006 — `SetCompositeMacro` duplicates `commitMacro`'s entire guard ladder, and has already drifted `[design]`

`modules/MacroManager.lua:438-495` vs `:305-371`

`commitMacro` exists precisely to be the shared write tail (oversize fallback → fingerprint compare → combat defer → `doEdit` → `macroState` store). `SetCompositeMacro` re-implements all five steps inline. The two copies have already diverged in three places: the oversize chat wording, the icon decision (`iconFor(effectiveItemID)` vs a local `effectiveActive and DYNAMIC_ICON or DEFAULT_ICON`), and the pending-entry shape (`cat` present in one, absent in the other — which is the mechanism behind **F-001**).

**Impact:** every future change to the write ladder must be made twice, and the last two macro-write bugs both came from the halves disagreeing.

**Fix direction:** extend `commitMacro` with the one thing composites need (an explicit icon override, or an `isActive` flag) and have `SetCompositeMacro` call it. Fixing F-001 inside a unified `commitMacro`/`FlushPending` pair resolves both findings with one change.

### F-007 — The Perf descriptor calls a DebugLog member the DebugLog stub deliberately withholds `[design]`

`modules/PerfSetup.lua:88` vs `modules/DebugLog.lua:97-104`

`PerfSetup`'s descriptor passes `log = function(line) KCM.DebugLog.AddLine("Perf", line) end` with no presence guard. `modules/DebugLog.lua`'s degradation stub publishes **no** `AddLine` — by design, because `core/Debug.lua` probes for it to decide whether a console exists. The two seams disagree.

The scenario is narrow but is exactly the one anti-pattern #48 names: a **partial** `libs/LibKa0s/` (e.g. `Perf.lua` + `PerfPanel.lua` + `Core.lua` present, `DebugLog.lua` missing) registers `LibKa0s-Perf-1.0` normally, so `PerfSetup` builds an instance whose `log` thunk will raise *"attempt to call field 'AddLine' (a nil value)"* on the first `/cm perf` run — far from the vendoring commit that caused it. Today's vendored folder is complete, so this is latent, not live.

**Fix direction:** guard the thunk (`local DL = KCM.DebugLog; if DL and DL.AddLine then DL.AddLine("Perf", line) end`) — one line, host-side, no library change. Do not add a no-op `AddLine` to the DebugLog stub: withholding it is load-bearing for `core/Debug.lua`'s chat fallback.

### F-008 — `PickupMacro` is called from a drag handler with no combat guard, under a comment asserting it is taint-free `[taint]`

`modules/MacroBarButton.lua:22-24` (the claim), `:367-370` (the call); same pattern at `modules/KCMMacroDragIcon.lua:113`

`OnDragStart` calls `PickupMacro(idx)` unconditionally. The file header states *"Taint-free at any time, exactly like the settings panel's KCMMacroDragIcon."*

**I could not verify that claim and am flagging it rather than guessing.** `PickupMacro` sits in the cursor-pickup family (`PickupAction`/`PickupSpell`/`PickupMacro`) whose members are combat-restricted in retail; the subsequent drop onto a Blizzard action bar runs `PlaceAction`, which is protected and which would inherit the taint of the tainted pickup. If that holds, dragging a bar slot mid-fight produces *"Interface action failed because of an AddOn"* rather than a silent no-op. Please confirm against the current client (`/etrace`, or the in-combat repro in `03_SMOKE_TESTS.md`) before treating this as fixed.

**Impact if confirmed:** a user-visible blocked-action error attributed to Consumable Master, on a gesture the bar's unlocked default invites.

**Fix direction:** add the same `inCombat()` early-return the rest of `modules/MacroBar.lua` uses (`modules/MacroBar.lua:430-433` is the pattern), with the standard gray chat notice, and correct the header comment either way. `events-frames-taint-§2` requires `InCombatLockdown()` — not `UnitAffectingCombat` — for this gate.

---

## Low

### F-009 — Three exported functions have zero callers `[dead-code]`

`modules/DebugLog.lua:187` (`DL.RefreshHeader`), `:186` (`DL.ShowCopy`), `modules/MacroBar.lua:288` (`MB.IsShown`). Verified by grep across `core/`, `modules/`, `settings/`, `defaults/`, `locales/` **and** `tests/` — the other facade members (`Clear`, `IsWindowShown`, `UpdateScrollBar`, `UpdateStatus`, the two formatters) are all exercised by `tests/test_debuglog.lua`. **Fix direction:** delete, or add the covering test if the facade is meant to be complete against the library instance.

### F-010 — Stale comment in the DebugLog degradation stub `[naming]`

`modules/DebugLog.lua:88-91` states *"settings/General.lua calls Hide on the Defaults action and IsWindowShown on every single panel refresh"*. `settings/General.lua` no longer calls `IsWindowShown` — since the `LIBKA0S-06` adoption it renders the console checkbox from `DL.instance:ConsoleCheckbox()` (`settings/General.lua:121-128`). The `Hide` half is still accurate (`settings/General.lua:79`). **Fix direction:** correct the second clause.

### F-011 — A second `PANEL_REFRESH` publisher that the message table does not document `[design]`

`core/ConsumableMaster.lua:559-561` publishes `KCM.MSG.PANEL_REFRESH` from the `GET_ITEM_INFO_RECEIVED` handler, while `docs/ARCHITECTURE.md:79` documents the sender as *"pipeline → options panel"*. Both send sites live in one module, so `architecture-§4`'s "MUST NOT have two senders" is not breached at module granularity — but the documented contract is now incomplete. **Fix direction:** document the event-layer publisher in the message table (`architecture-§4` requires sender + all consumers to be documented), or funnel both sites through one local `publishPanelRefresh()`.

### F-012 — `core/Bus.lua`'s header contradicts `docs/ARCHITECTURE.md` `[naming]`

`core/Bus.lua:3-5` asserts *"Modules never reach into each other's tables to trigger work"*, but five modules call `KCM.Pipeline.RequestRecompute` directly (`core/SlashCommands.lua:99`, `settings/Category.lua:104`, `settings/StatPriority.lua:147`, `settings/Panel.lua:652`, `modules/PerfSetup.lua:57`) — which `docs/ARCHITECTURE.md:93` explicitly sanctions. The code is fine; the two documents disagree. **Fix direction:** soften the Bus.lua header to match the documented invariant (bus for cross-*feature* notification; `RequestRecompute` is the pipeline's public entry point).

### F-013 — `ValidateSchema` does not check that each row's `path` resolves against the defaults `[design]`

`settings/Panel.lua:136-158` validates `path` presence, `panel`, `section` and `type`, but not that `path` resolves against `KCM.dbDefaults.profile` — which `architecture-§5` makes a **MUST** ("every schema row's `path` resolves against the defaults table; warn loudly on mismatch"). No row is currently broken, so this is latent: a typo'd new row would make `/cm get`/`set` silently answer `nil` and its widget render blank, with no boot warning. **Fix direction:** add a defaults-resolution pass to `ValidateSchema` (it already runs at `registerPanel`) and count it into the returned error total.

### F-014 — Two `/cm stat` subcommands lack the DB-ready guard their sibling has `[logic]`

`core/SlashCommands.lua:814` and `:850` write `KCM.db.profile.statPriority` with no guard, while `statReset` checks `if not (KCM.db and KCM.db.profile) then return say("DB not ready.") end` first (`:864`). **Impact:** an error instead of a message on the (narrow) pre-`OnInitialize` path. **Fix direction:** hoist the same guard into all three, or into `resolveSpecKey`'s callers.

### F-015 — An unparsed consumable tooltip is re-parsed on every `Get`, forever `[perf]`

`core/TooltipCache.lua:462-469`. When a Consumable's tooltip yields no recognized effect, the entry is cached as a `pending` stub and `TC.Get` re-fetches `C_TooltipInfo.GetItemByID` + re-runs `parseLines` on every subsequent call — by design, so a late-arriving body is picked up. There is no attempt ceiling, so an item whose phrasing the patterns simply do not match never converges: it is re-parsed once per candidate walk, per recompute, forever.

To be explicit about scope: the **English-only tooltip-text parsing itself is a documented, tracked deviation** (`docs/scope.md`, "Out of scope") and is the standards-audit's business, not this review's. What is in scope here is the unbounded retry that deviation makes permanent — on a deDE/frFR client *every* managed consumable lands in this loop. **Fix direction:** bound the retry (an attempt counter or a "give up after N `GET_ITEM_INFO_RECEIVED` cycles" mark) so a permanently-unparsable item settles into a final, cheap entry.

### F-016 — Bar slots fire on button-up regardless of the user's `ActionButtonUseKeyDown` setting `[ux]`

`modules/MacroBarButton.lua:320` and `modules/MacroBarFlyout.lua:187` both hardcode `RegisterForClicks("AnyUp")`. Blizzard's own action buttons honour the `ActionButtonUseKeyDown` cvar, so a player who has cast-on-down enabled gets a bar whose slots feel a frame slower than every other button on screen. **Fix direction:** read the cvar at build time and re-register on `CVAR_UPDATE`, mirroring what `LibActionButton`-based bars do; keep the registration out of combat like every other secure operation here.

---

## Not findings (checked, clear)

Recorded so a later reviewer does not re-open them: no `_G[addonName]` global; no AceLocale strict mode; no `SLASH_*` direct registration; no `if cmd == "x"` dispatcher; no `.pkgmeta` `externals:`; no Ace fork (the `LSM30_Border` fixup uses the sanctioned `RegisterWidgetType` extension, `core/LSMPatch.lua:39`); no flavor branching; no `## Dependencies:`; MIT licence; single `## Interface:` line; no file over 1500 LOC (largest is `core/SlashCommands.lua` at 1408); no `:Hide()` on Blizzard frames; no `AddMessage` replacement; no user-supplied Lua execution; no loose files in `media/`; root `CLAUDE.md` is a stub with a `## Standards compliance` section; no `TODO.md`; no `docs/agent-context.md`; no `embeds.xml`; no raw `UIPanelButtonTemplate` header button; no ungated hot-path instrumentation (both Perf brackets are `perf.on`-gated, `core/ConsumableMaster.lua:269`, `modules/MacroBar.lua:323`); no shared measurement frame (the Perf harness builds per-host); no British spelling; no `setmetatable` on a Blizzard widget; no un-throttled `OnUpdate` (the fade tick throttles at 0.1s, the flyout poll runs only while a flyout is open); no missing `ClearAllPoints` before re-anchoring; no `|T...|t`-in-`name` execute button.
