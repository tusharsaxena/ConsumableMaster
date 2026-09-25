# 05 — Final summary (written as if every change in 02 has landed and every test in 03 has passed)

## Headline

This cycle fixed a weapon-enchant macro that was being rewritten wrongly after combat. It stopped a color reset from quietly
corrupting the addon's built-in defaults when the player switches profiles. It also made sure a disabled addon never loses its
settings page and catches up on its bags when turned back on.

Around those fixes, it moved the two hot item reads onto the current `C_Item` API and made the reset, lock and enable wording
match what each action actually does. It gave the test harness the fidelity it needed to see these bugs, and removed stale
comments and one dead export. No LibKa0s change was needed.

## Counts

**Critical fixed: 0 · High fixed: 1 · Medium fixed: 5 · Low fixed: 11**

- **Fully addressed:** all 17 findings.
- **Addressed in part: F-004.** The false comment is corrected and the behavior is documented as a Known Limitation. Panel-owned
  hydration while disabled needs an owner ruling, because the standard records that question as open (see *Known follow-ups*).
- **Informational only: F-016's `O.SetMacroTab`.** It is kept as a deliberate test seam.

## Changes by theme

### T1 — A write deferred in combat is replayed as it was queued

- **What changed.** When combat ends, the macros that were waiting are written with exactly the body the addon computed. It no
  longer rebuilds a simplified one. Weapon-enchant macros keep both of their weapon-slot lines.
- **Why it mattered.** After `/cm rewritemacros` in combat, a weapon swap or an oil change mid-fight, `KCM_WPN_ENCH` became a
  bare `/use item:<oil>`. Clicking it put the oil on the cursor instead of applying it, until something else happened to trigger
  a recompute.
- **Findings / changes:** F-001 / C-01.
- **Files:** `modules/MacroManager.lua`, `tests/test_macromanager.lua`.

### T2 — The single write seam never stores a shared default

- **What changed.** Setting a color stores a copy. The test mock's profile switch now strips defaults the way the real AceDB
  does.
- **Why it mattered.** `/cm reset <color path>` followed by a profile switch emptied the shipped default color for the rest of
  the session. Swatches then read opaque black and `/cm get` reported fallbacks. The harness could not see it.
- **Findings / changes:** F-002, F-006 / C-02.
- **Files:** `settings/Panel.lua`, `tests/wow_mock.lua`, `tests/test_profiles.lua` (or `tests/test_schema.lua`).

### T3 — Setup survives the stand-down, and standing up rebuilds from the current state

- **What changed:**
  - A settings category that was refused in combat is registered at the end of combat, even while the addon is disabled.
  - Re-enabling the addon runs the same discovery and stale-sweep pass as a login.
  - The comment and the docs now say truthfully what the settings panel can hydrate while disabled.
- **Why it mattered:**
  - A disabled addon reloaded in combat vanished from Settings → AddOns for the session, and that is the page a player uses to
    turn it back on.
  - Items looted while disabled were not candidates until the next bag change.
- **Findings / changes:** F-003, F-004, F-007 / C-03, C-04, C-05.
- **Files:** `core/ConsumableMaster.lua`, `core/LifecycleSetup.lua`, `docs/ARCHITECTURE.md`, `tests/test_settingsui_optionsui.lua`,
  `tests/test_disabled.lua`.

### T4 — API currency on the hot item reads

- **What changed.** Ranking and tooltip parsing read item info through `KCM.Compat.GetItemInfo`, which prefers
  `C_Item.GetItemInfo`. An unread `subType` field left the per-pass score cache.
- **Why it mattered.** Both hot paths depended on a deprecated global, with no fallback.
- **Findings / changes:** F-005 / C-06.
- **Files:** `core/Compat.lua`, `modules/Ranker.lua`, `core/TooltipCache.lua`, `tests/test_compat.lua`, `tests/wow_mock.lua`.

### T5 — One act, one wording, and the truth on every surface

- **What changed:**
  - `/cm resetall` is described as the whole-profile reset it is, and both of its doors refuse in combat the same way.
  - The priorities tooltip names the right tab.
  - The bare `/cm bar` toggles the stored flag.
  - Unlocking a switched-off bar says so.
  - `/cm enable` and `/cm disable` print one canonical line.
- **Why it mattered.** Each surface told the player something different from what the addon did.
- **Findings / changes:** F-008 to F-012 / C-07 to C-11.
- **Files:** `settings/Slash.lua`, `core/SlashCommands.lua`, `core/ConsumableMaster.lua`, `settings/General.lua`,
  `core/LauncherSetup.lua`, `locales/enUS.lua` (if registered), `tests/test_slash.lua`, `tests/test_launcher.lua`,
  `tests/test_locale.lua`.

### T6 — Test integrity

- **What changed.** There are red-first cases under every fixed defect, and two assertions that could not fail were replaced.
- **Findings / changes:** F-006, F-013 / C-01 to C-03, C-12.
- **Files:** `tests/test_disabled.lua`, plus the files above.

### T7 — Comment, doc and dead-code hygiene

- **What changed:**
  - Twelve stale comments were corrected (the TOC in prose only).
  - The doc claim about `/cm set macroBar.point|x|y` was fixed.
  - The unread `KCM.Settings.GENERAL_TABS` was removed.
  - The About logo path is derived from `addonName`.
- **Findings / changes:** F-014 to F-017 / C-13 to C-15.
- **Files:** `modules/MacroBar.lua`, `docs/ARCHITECTURE.md`, `defaults/Profile.lua`, `core/ConsumableMaster.lua`,
  `settings/Slash.lua`, `modules/Selector.lua`, `ConsumableMaster.toc`, `settings/OptionsSetup.lua`, `settings/General.lua`,
  `settings/Panel.lua`.

## API and behavior changes

- **Slash:**
  - no new or renamed verbs;
  - `resetall`'s help line reworded;
  - `/cm resetall` now refuses in combat;
  - bare `/cm bar` toggles the stored `macroBar.enabled`;
  - `/cm enable` and `/cm disable` print one line (`enabled = true|false`); the extra "Master enable ON/OFF" line is gone;
  - `/cm lock`, `/cm unlock` and the minimap left-click mention when the bar is switched off.
- **Macros:** a per-hand macro deferred in combat keeps its `/use 16` and `/use 17` lines after the flush.
- **Settings:** a disabled addon's settings category is registered after an in-combat reload. The Maintenance tooltip wording
  changed.
- **Deprecated calls replaced:** see the table below.
- **Locale keys:** one changed (the "Reset all priorities" tooltip), and one chat string removed ("Master enable …").
- **Defaults:** none added or removed.

## Saved-variable and migration notes

**No schema bump.** `D.CURRENT_SCHEMA` stays 3.

One stored-shape consequence: a color row written through the seam is now always a fresh table. A profile that aliased the
defaults table in a session before this fix has nothing to repair, because AceDB strips an empty or default-equal color on
logout. Existing profiles need no `/cm resetall`.

## Deprecated-API migrations

| Old API | New API | Files |
|---|---|---|
| `GetItemInfo(itemID)` (global) | `KCM.Compat.GetItemInfo(itemID)` → `C_Item.GetItemInfo`, with the global as fallback | `modules/Ranker.lua`, `core/TooltipCache.lua` |

`core/Classifier.lua` and `core/WeaponSlots.lua` already prefer `C_Item.GetItemInfoInstant`. Their global fallbacks are unchanged.

## Performance impact

No number exists for these changes yet, so this section reports none rather than estimate one. The number to take is the
offline `recompute` scenario from `tests/perf.lua`, before and after C-06, in the same run: **2551.1 bytes/iter** on 2026-09-23,
before any change. If an in-client capture is taken per `03_SMOKE_TESTS.md`, its bundle under `docs/perf-analysis/` is the record
to cite. Read its bucket figures, not the frame-time delta.

## Test and complexity movement

- **Pass count:** 998 → about **1007** (+9 red-first and behavior cases). The exact figure is whatever `tests/run.lua --list`
  emits. `docs/test-cases.md` and the README `[Tests]` badge moved in the same commit as each suite change.
- **Complexity:** C-03 is expected to take `KCM:OnRegenEnabled` (`core/ConsumableMaster.lua`) from **CCN 15**, the one function
  at the tag gate's cap today, to about 12. Leave this to the next release's `/wow-addon:bump-version` regeneration of
  `docs/automated-tests/` to confirm. It was not regenerated in this cycle.
- **Stale record to refresh at that release:** `docs/automated-tests/RESULTS.md` still describes run `20260916-184427` (928 cases,
  eight functions at CCN 15).

## Known follow-ups

- **F-004, deferred half.** Hydrating priority-list rows while the addon is disabled (for example, via LibKa0s-Item `LoadItem`,
  which `core/ItemSetup.lua` declines today). This touches `slash-commands-§7`'s "Recorded, not ruled" question about a panel's
  own refresh subscription, so it waits for an owner ruling and then a tracked issue.
- **`settings/Panel.lua` (1312 LOC)** and **`settings/Category.lua` (1141)** are still in `layout-§1`'s on-notice band. The
  committed watch list says their acceptance shelf life is up. That is the release run's disposition to make, not this review's.
- **`O.SetMacroTab`.** It is a test-only public member, kept deliberately. Revisit it only if the Macros page's tab API changes.

## Verification evidence

- In-client: `docs/reviews/2026-09-23/03_SMOKE_TESTS.md`, with the sign-off table filled in.
- Headless: the gate re-run named in its pre-flight line.
- Commit range: `<first M0 commit>..<last M4 commit>` on `feat/2026-09-23-review-audit-remediation`. Fill this in when the work
  lands.

## Suggested commit message / PR description

```
ConsumableMaster: 2026-09-23 review remediation (F-001–F-017)

- Replay a deferred macro write exactly as queued, so a per-hand
  (weapon-enchant) macro keeps its /use 16 and /use 17 lines after combat (F-001).
- Store a copy when a color row is set; a reset plus a profile switch no
  longer empties the shipped default (F-002). The mock AceDB now models
  removeDefaults on switch so this class is caught headlessly (F-006).
- A settings category parked in combat is registered on regen even while
  the addon is disabled (F-003); standing back up runs the login
  discovery and sweep pass (F-007); the panel-while-disabled behavior is
  documented truthfully (F-004).
- Hot item reads go through KCM.Compat.GetItemInfo (C_Item first); the
  unread subType field is gone (F-005).
- Wording and predicates: /cm resetall help and one combat guard (F-008),
  tooltip tab name (F-009), bare /cm bar reads the stored flag (F-010),
  unlock-while-off message (F-011), a single echo for enable/disable (F-012).
- Tests: red-first cases for F-001..F-003; two unfalsifiable assertions
  replaced (F-013).
- Hygiene: stale comments and docs corrected (F-014, F-015), unread export
  removed (F-016), About logo path derived from addonName (F-017).

No schema bump. No LibKa0s change. Tests: 998 -> <N> (docs/test-cases.md
and README badge updated in the same commits).
```
