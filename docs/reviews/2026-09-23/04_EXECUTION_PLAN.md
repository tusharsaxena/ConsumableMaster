# 04 — Execution plan

**Inputs:** `01_FINDINGS.md` (F-001 to F-017), `02_PROPOSED_CHANGES.md` (C-01 to C-15). Standard v2.64.0.

**Repo hard rules** (`CLAUDE.md`):
- No auto-staging, committing or pushing. Each commit below is made when the owner runs `/wow-addon:commit`, or on the owner's
  explicit go-ahead within the collection-wide plan.
- No version bump.
- The gate (`lua5.1 tests/run.lua` + `luacheck .`) is green before every commit.
- `docs/test-cases.md` and the README `[Tests]` badge move in the **same** commit as any suite change.

**Upstream milestone:** **none required.** This review raised no `[upstream]` finding, so no LibKa0s change or re-vendor gates
any task here. If the collection-wide plan re-vendors LibKa0s first, M0 below records that the re-vendor has landed and the gate
is still green. It is not a task of this review.

---

## Milestones

### M0 — Baseline and characterization

**Done when:**
- the gate is green on the starting SHA;
- the characterization cases for `FlushPending` exist and pass;
- the red-first cases for F-001, F-002 and F-003 exist and **fail** against unchanged code, with each failure recorded in the task
  notes.

| Task | Owner role | Findings / changes | Files |
|---|---|---|---|
| M0-T1 | test-author | F-006 (C-01 characterization) | `tests/test_macromanager.lua` |
| M0-T2 | test-author | F-006 (mock fidelity, C-02) | `tests/wow_mock.lua` |
| M0-T3 | test-author | F-006 (red-first cases for F-001, F-002, F-003) | `tests/test_macromanager.lua`, `tests/test_profiles.lua` (or `tests/test_schema.lua`), `tests/test_settingsui_optionsui.lua` |

- **M0-T2 comes before M0-T3's F-002 case.** That case can only go red once the mock models `removeDefaults`.
- **Checkpoint CP0.** A human confirms the three new cases fail for the stated reason (`testing-§12`) before any fix lands.
  Red cases **must not** be committed on their own, because the commit gate is green. Hold them in the working tree and commit
  each one with its fix (TDD within a task).

### M1 — Correctness fixes

**Done when:** C-01, C-02 and C-03 have landed, their M0 cases are green, the full gate is green, and the inventory and badge are
regenerated.

| Task | Owner role | Findings / changes | Files |
|---|---|---|---|
| M1-T1 | lua-refactorer | F-001 / C-01 | `modules/MacroManager.lua`, `tests/test_macromanager.lua` |
| M1-T2 | lua-refactorer | F-002 / C-02 | `settings/Panel.lua`, `tests/wow_mock.lua`, `tests/test_profiles.lua` / `tests/test_schema.lua` |
| M1-T3 | lua-refactorer | F-003 / C-03 | `core/ConsumableMaster.lua`, `tests/test_settingsui_optionsui.lua` |

**Checkpoint CP1** comes after M1, before any refactor or wording change. It has three parts:
- run `03_SMOKE_TESTS.md` C-01 to C-03 plus the taint checks in-client;
- confirm with the pre-flight run that `lizard` puts `KCM:OnRegenEnabled` under 15. This is a scratch run and is never written
  into the repo;
- the owner signs off.

### M2 — Disabled-state completeness and API currency

**Done when:** C-04, C-05 and C-06 have landed, the gate is green, and the inventory and badge are regenerated.

| Task | Owner role | Findings / changes | Files |
|---|---|---|---|
| M2-T1 | docs-editor | F-004 / C-04 | `core/ConsumableMaster.lua` (comment `:213-218`), `docs/ARCHITECTURE.md` (Known Limitations) |
| M2-T2 | lua-refactorer | F-007 / C-05 | `core/ConsumableMaster.lua`, `core/LifecycleSetup.lua`, `tests/test_disabled.lua` |
| M2-T3 | wow-api-migrator | F-005 / C-06 | `core/Compat.lua`, `modules/Ranker.lua`, `core/TooltipCache.lua`, `tests/test_compat.lua`, `tests/wow_mock.lua` (`C_Item.GetItemInfo`) |

**Checkpoint CP2** has three parts:
- the owner rules on the **deferred half of C-04**: panel-owned hydration through LibKa0s-Item `LoadItem` while disabled. Either
  open a tracked issue, or record an accepted behavior in `docs/ARCHITECTURE.md`;
- in-client C-05 and C-06;
- offline `tests/perf.lua`, where `recompute` bytes/iter must not rise. Compare before and after within one session.

### M3 — UX wording and predicates

**Done when:** C-07 to C-11 have landed, the gate is green, and the inventory and badge are regenerated.

| Task | Owner role | Findings / changes | Files |
|---|---|---|---|
| M3-T1 | ux-cleanup | F-008 / C-07 | `settings/Slash.lua`, `core/ConsumableMaster.lua` (`ResetAllToDefaults`), `core/SlashCommands.lua` (popup), `settings/General.lua` (`doResetAll`), tests |
| M3-T2 | ux-cleanup | F-009 / C-08 | `settings/General.lua` (`:367`), `locales/enUS.lua` if registered, `tests/test_locale.lua` if pinned |
| M3-T3 | ux-cleanup | F-010 / C-09 | `core/SlashCommands.lua` (`:904`), `tests/test_slash.lua` |
| M3-T4 | ux-cleanup | F-011 / C-10 | `core/SlashCommands.lua` (`runLock`), `core/LauncherSetup.lua`, `tests/test_launcher.lua` |
| M3-T5 | ux-cleanup | F-012 / C-11 | `settings/General.lua` (`:249`), `tests/test_locale.lua`, `tests/test_slash.lua` |

**Checkpoint CP3:** in-client C-07 to C-11.

### M4 — Test integrity, comment and doc hygiene, dead code

**Done when:** C-12 to C-15 have landed, the gate is green, and the inventory is regenerated. The case count is unchanged by
C-12, but the assertion lines change.

| Task | Owner role | Findings / changes | Files |
|---|---|---|---|
| M4-T1 | test-author | F-013 / C-12 | `tests/test_disabled.lua` |
| M4-T2 | docs-editor | F-014, F-015 / C-13 | `modules/MacroBar.lua`, `docs/ARCHITECTURE.md`, `defaults/Profile.lua`, `core/ConsumableMaster.lua`, `settings/Slash.lua`, `modules/Selector.lua`, `ConsumableMaster.toc` (prose only; anti-pattern #66), `settings/OptionsSetup.lua` |
| M4-T3 | lua-refactorer | F-016 / C-14 | `settings/General.lua` (`:383`) |
| M4-T4 | lua-refactorer | F-017 / C-15 | `settings/Panel.lua` (`:148`) |

**Checkpoint CP4:** the full regression suite in `03_SMOKE_TESTS.md`, plus the collection-wide cross-addon check if several
addons are being remediated in the same session.

---

## Critical path and concurrency map

**Critical path:** M0-T2 → M0-T3 → M1-T2. The rest of M1 depends on M0-T1 and M0-T3 only.

These tasks share files and **must be serialized**:

| File | Tasks, in order |
|---|---|
| `core/ConsumableMaster.lua` | M1-T3 → M2-T1 → M2-T2 → M3-T1 → M4-T2 |
| `settings/General.lua` | M3-T1 → M3-T2 → M3-T5 → M4-T3 |
| `core/SlashCommands.lua` | M3-T1 → M3-T3 → M3-T4 |
| `settings/Slash.lua` | M3-T1 → M4-T2 |
| `settings/Panel.lua` | M1-T2 → M4-T4 |
| `tests/wow_mock.lua` | M0-T2 → M2-T3 |
| `tests/test_macromanager.lua` | M0-T1 → M0-T3 → M1-T1 |
| `tests/test_disabled.lua` | M2-T2 → M4-T1 |
| `tests/test_locale.lua` | M3-T2 → M3-T5 |
| `docs/test-cases.md` and README badge | every commit that changes the suite. Always regenerate last in the commit, never in parallel |

**Parallelizable** (disjoint files):
- **M1-T1** (MacroManager), **M1-T2** (Panel.lua + mock + profile test) and **M1-T3** (ConsumableMaster.lua + optionsui test),
  once M0 is done. Each commit still regenerates `docs/test-cases.md`, so **merge them one after another** even if they are
  developed in parallel.
- **M2-T3** (Compat, Ranker, TooltipCache) runs in parallel with M2-T1 and M2-T2. The only shared file is `tests/wow_mock.lua`,
  which is already serialized after M0-T2.
- **M4-T4** runs in parallel with M4-T1 to M4-T3.

---

## Incremental commit strategy

One commit per task, in milestone order. Each commit has a green gate and includes the regenerated `docs/test-cases.md` plus the
README badge whenever the case count moves. Suggested messages:

- M0-T1 `Pin FlushPending's single-category replay before changing it`
- M0-T2 `Model AceDB's removeDefaults on profile switch in the mock`
- M1-T1 `Replay a deferred macro write as it was queued (F-001)`. This carries the per-hand red-first case.
- M1-T2 `Store a copy when a color row is set, never the shipped default (F-002)`
- M1-T3 `Replay a parked settings registration while the addon is stood down (F-003)`
- M2-T1 `Say what the panel does while disabled (F-004)`
- M2-T2 `Stand back up with login's discovery pass (F-007)`
- M2-T3 `Route the hot item reads through Compat, drop the unread subType (F-005)`
- M3-T1 `/cm resetall: say it resets the profile, one combat guard for both doors (F-008)`
- M3-T2 `Name the tab the whole-profile reset lives on (F-009)`
- M3-T3 `Bare /cm bar toggles the stored flag (F-010)`
- M3-T4 `Say when the bar being unlocked is switched off (F-011)`
- M3-T5 `One echo for /cm enable and /cm disable (F-012)`
- M4-T1 `Replace two assertions that cannot fail (F-013)`
- M4-T2 `Correct comments and docs that describe removed behavior (F-014, F-015)`
- M4-T3 `Drop the unread GENERAL_TABS export (F-016)`
- M4-T4 `Build the About logo path from the addon folder (F-017)`

End every commit with the attribution lines the session specifies.

**Pushing** happens after major milestones and only on the owner's instruction. **Merging** needs the owner's go-ahead.
