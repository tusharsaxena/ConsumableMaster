# 05 — Final summary

> **Status: template, pending implementation.** This document is written on the assumption that every change in `02_PROPOSED_CHANGES.md` has been applied and every test in `03_SMOKE_TESTS.md` has passed. Fill the bracketed slots as the work lands; it is the artifact that becomes the PR description and the changelog source.

## Headline

This cycle hardened Consumable Master's two least-exercised paths and closed a set of small consistency gaps. The macro-write layer now has a single write tail and a self-describing deferral queue, so a weapon-enchant macro rewritten during a fight is restored correctly when the fight ends instead of losing its per-weapon slot lines. The addon's documented "LibKa0s missing → the panel is gone but the CLI still works" promise is now actually true — `/cm set` and `/cm debug` no longer raise on a degraded install. Beyond that: the macro bar's two all-in-one slots show a real icon instead of a question mark, `/cm bar` keeps an open settings page in sync, loading screens stopped paying login-sized bookkeeping costs, and a handful of stale comments, uncalled exports and missing guards were cleaned up. No user-facing feature changed shape and no saved data migrated.

## Counts

`Critical fixed: 0 (none found)`, `High fixed: [2]`, `Medium fixed: [6]`, `Low fixed: [8]`.

Deferred (fill in if any): `[F-0xx — reason]`. F-008 is conditional by design — if the in-client verification in `03_SMOKE_TESTS.md` § C-07 shows `PickupMacro` is unrestricted in combat on this client, only the comment correction ships and the guard is deliberately not added.

## Changes by theme

### Theme A — One macro-write tail, one self-describing deferral queue

- **What changed.** `MacroManager` now has a single write path: `commitMacro` handles the oversize fallback, the unchanged-body fingerprint, the combat deferral, the `EditMacro`/`CreateMacro` call and the `macroState` store for *every* macro shape, and `SetCompositeMacro` calls it instead of re-implementing it. Each queued write records what kind of macro it is, so the post-combat flush rebuilds the right body.
- **Why it mattered.** The composite path was a 60-line copy of the single path and had already drifted three ways. One of those drifts was a live bug: a weapon-enchant macro deferred during combat came back as a plain single-item `/use`, dropping the `/use 16` / `/use 17` lines that actually apply the enchant — so the macro silently stopped working until the next out-of-combat rewrite.
- **Findings covered:** F-001, F-006. **Changes implemented:** C-01.
- **Files touched:** `modules/MacroManager.lua`, `tests/test_macromanager.lua`.

### Theme B — The degraded install keeps its contract

- **What changed.** With `libs/LibKa0s/` absent, the two library-bound refresh helpers now degrade to no-ops instead of being nil, and the perf harness's log thunk checks for the debug console before calling it.
- **Why it mattered.** `settings/Panel.lua` documented, in as many words, that the schema half never touches the library so `/cm list|get|set` survives a missing LibKa0s. It didn't: the first `/cm set` or `/cm debug on` threw. The perf gap was the same class one step out — a partially re-vendored library folder would have surfaced as a nil-field error at report time, far from the commit that caused it.
- **Findings covered:** F-002, F-007. **Changes implemented:** C-02, C-03.
- **Files touched:** `settings/Panel.lua`, `modules/PerfSetup.lua`, `tests/test_settingsui.lua`, `tests/test_perfsetup.lua`.

### Theme C — One write path for schema-backed settings

- **What changed.** `/cm bar on|off|lock|unlock` (and the bare `/cm bar` toggle) now write through `KCM.Schema:Set` like every other setting, instead of poking `db.profile.macroBar` directly.
- **Why it mattered.** Both fields are schema rows, so the slash path was skipping validation, the row's `onChange`, and the in-place widget re-sync — which showed up as a Macro Bar settings page whose checkbox disagreed with the bar the user was looking at.
- **Findings covered:** F-004. **Changes implemented:** C-04.
- **Files touched:** `core/SlashCommands.lua`, `tests/test_slash.lua`.

### Theme D — Loading screens are cheap again

- **What changed.** The `PLAYER_ENTERING_WORLD` handler reads the event's own `isInitialLogin` / `isReload` flags and runs the discovered-set TTL sweep only at session start; the sweep reuses the bag counts the discovery pass already computed instead of scanning bags a second time. The bounded tooltip retry stops an unparsable consumable from being re-parsed on every candidate walk forever.
- **Why it mattered.** `PLAYER_ENTERING_WORLD` fires on every zone change and dungeon entry, not just at login as the code's comment claimed — so every loading screen paid two full bag scans plus a walk of every category bucket, for work that cannot produce a new answer twice in one session.
- **Findings covered:** F-005, F-015. **Changes implemented:** C-05, C-09.
- **Files touched:** `core/ConsumableMaster.lua`, `modules/Selector.lua`, `core/TooltipCache.lua`, `tests/test_events.lua`, `tests/test_selector.lua`, `tests/test_tooltipcache.lua`.

### Theme E — Correctness and hygiene

- **What changed.** The two all-in-one macro-bar slots resolve their icon from the first enabled sub-category's current pick instead of rendering the `?` sentinel; the drag pickup is combat-guarded (conditional on verification); three uncalled exports were removed; two stale comments and one undocumented bus publisher were corrected; schema validation now checks that every row's path resolves against the defaults; `/cm stat primary|secondary` gained the DB-ready guard their sibling already had; the bar honours `ActionButtonUseKeyDown`.
- **Why it mattered.** Individually small, collectively the difference between "documented behaviour" and "actual behaviour" in six places — and the `?` icon was the most visible unfixed defect on the addon's newest feature.
- **Findings covered:** F-003, F-008, F-009, F-010, F-011, F-012, F-013, F-014, F-016. **Changes implemented:** C-06, C-07, C-08, C-10.
- **Files touched:** `core/MacroDisplay.lua`, `modules/MacroBarButton.lua`, `modules/MacroBarFlyout.lua`, `modules/MacroBar.lua`, `modules/KCMMacroDragIcon.lua`, `modules/DebugLog.lua`, `core/Bus.lua`, `core/ConsumableMaster.lua`, `core/SlashCommands.lua`, `settings/Panel.lua`, `docs/ARCHITECTURE.md`, `docs/macro-bar.md`.

## API / behaviour changes

- **Slash commands.** No verb added, renamed or removed. `/cm bar on|off|lock|unlock` now routes through the schema seam — same output, same effect, plus an in-place refresh of an open Macro Bar page. Confirm exactly **one** in-combat notice is emitted (the row `onChange` and the slash handler must not both print).
- **Deprecated-API migrations.** **None.** No deprecated call was replaced this cycle; the addon was already on the modern surface (`C_Container.*`, `C_Item.*`, `C_Spell.*`, `C_AddOns.*`, `C_TooltipInfo.*`, `Settings.Register*`, `LEARNED_SPELL_IN_SKILL_LINE`), with every legacy global sitting behind `core/Compat.lua` as an explicit fallback. The table this section would normally carry is intentionally empty.
- **New behaviour visible to users.** AIO bar slots show a real item icon; bar slots fire on key-down when the client cvar says so; dragging a slot off the bar in combat is refused with a chat notice instead of failing (conditional on C-07).
- **Locale keys.** One key added if C-07 lands (`"in combat — dragging a macro off the bar is blocked until combat ends"`). No key renamed or removed. Every string is a `KCM.L[...]` lookup with the enUS metatable fallback, so no `locales/` file edit is required.
- **Internal API.** `commitMacro` gains an optional `opts` table; `SweepStaleDiscovered` gains an optional `bagCounts` second argument (both backward-compatible); `MD.CompositePickID` is new; `DL.RefreshHeader`, `DL.ShowCopy` and `MB.IsShown` were removed (verified zero callers, including tests).

## Saved-variable / migration notes

**No schema bump.** `KCM.Database.CURRENT_SCHEMA` stays at **2**; no change touches the stored shape of `ConsumableMasterDB` or `ConsumableMasterPerfDB`, and no new default key was added. Existing profiles carry forward untouched — no `/cm resetall` is required, and none should be advised in the release notes.

The only stored-data behaviour that changed is *when* the `discovered` TTL sweep runs (login/reload rather than every loading screen), which affects timing, not shape: an entry that would have been swept on a zone change is now swept at the next session start instead.

## Performance impact

Fill from `03_SMOKE_TESTS.md`'s perf spot-checks:

| Measurement | Before | After |
|---|---|---|
| `GetAddOnCPUUsage` delta across one dungeon zone-in + zone-out | `[ ]` | `[ ]` |
| `collectgarbage("count")` residual after paging five category tabs | `[ ]` | `[ ]` |
| `/cm perf` `cooldown` bucket (ms/frame, in combat) | `[ ]` | `[ ]` (expected unchanged) |

## Known follow-ups

- **English-only tooltip-text parsing** (`core/TooltipCache.lua`) remains a documented, tracked deviation in `docs/scope.md`. C-09 bounded its worst *consequence* (the unbounded re-parse loop) but did not localize the parsing. Deliberately out of scope for a code review — it is a `wow-addon:standards-audit` item and a planned feature, not a defect to fix opportunistically.
- **`docs/pending/LEDGER.md`'s LIBKA0S entries** (LIBKA0S-04/05/09 in particular — the widget-maker split, the panel-registry differences, and the lib-level parser strings that an instance override cannot reach) are unchanged by this cycle. LIBKA0S-09 is the one worth revisiting: three `SLASH_STRINGS` entries in `core/SlashCommands.lua:1291-1299` are documented as dead because the library's parsers read `lib.STRINGS` directly. They were left in place as a record, which is defensible, but they will read as live overrides to the next person.
- **`core/SlashCommands.lua` is 1408 LOC** — under the 1500 limit (anti-pattern #16) but close enough that the next verb namespace should split the file (the `priority` / `stat` / `aio` sub-dispatchers are the natural seam). Not done now: splitting it while C-04 and C-08f were editing it would have made both diffs unreviewable.
- **Composite tooltips** still fall back to name+body rather than resolving a component's tooltip (C-06 deliberately fixed only the icon). Revisit if users report the AIO tooltip as unhelpful; showing only the first component may be worse than showing the body.

## Verification evidence

- Completed sign-off table: `docs/reviews/2026-08-03/03_SMOKE_TESTS.md` (all rows filled, including the F-008 verification answer in the C-07 notes column).
- Headless gates at the final commit: `lua tests/run.lua` → `[N] passed, 0 failed` (baseline before this cycle: **600 passed, 0 failed**); `luacheck .` → `0 warnings / 0 errors in 52 files`.
- `tests/test_vendor_sync.lua` still green — `libs/LibKa0s/` and `tests/_kit/` remain byte-identical to LibKa0s v1.5.0. No vendored file was edited by any change in this cycle.
- Commit range / PR: `[fill in]`.

## Suggested commit message / PR description

```
fix: harden the macro-write and degraded-install paths (review 2026-08-03)

Closes the two High findings from docs/reviews/2026-08-03/01_FINDINGS.md plus
six Medium and eight Low items. No saved-variable migration, no schema bump,
no deprecated-API replacements, no vendored-library change.

High
- F-001 A weapon-enchant macro deferred during combat was flushed through the
  single-item builder, losing its /use 16 and /use 17 slot lines. Pending
  entries now carry their macro kind and FlushPending dispatches on it.
- F-002 With LibKa0s absent, Helpers.SetAndRefresh and Options.Refresh called
  two nil library bindings, so /cm set and /cm debug on threw — contradicting
  the degraded-install contract settings/Panel.lua documents. Both now degrade
  to no-ops.

Medium
- F-003 AIO macro-bar slots rendered the ? icon sentinel; they now resolve a
  component's real icon.
- F-004 /cm bar now writes through KCM.Schema:Set, so an open settings page
  stays in sync (architecture-§5).
- F-005 The discovered-set TTL sweep and its duplicate bag scan ran on every
  loading screen; they now run on login/reload only.
- F-006 SetCompositeMacro's duplicated write ladder collapsed into commitMacro.
- F-007 The perf harness's log thunk is guarded against a partial LibKa0s
  vendor (anti-pattern #48).
- F-008 The macro-bar drag pickup is combat-guarded [or: verified unrestricted;
  comment corrected].

Low: F-009…F-016 — three uncalled exports removed, two stale comments and one
undocumented bus publisher corrected, schema paths validated against the
defaults at boot, /cm stat DB guards hoisted, tooltip re-parse retry bounded,
ActionButtonUseKeyDown honoured.

Gates: lua tests/run.lua green, luacheck . clean, vendor-sync green.
Standard: Ka0s WoW Addon Standard v2.17.1.
```
