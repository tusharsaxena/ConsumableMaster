# Review — 2026-08-05 — 04 Execution Plan

Five milestones, ordered so the highest-value, lowest-risk work lands first and the one large
refactor (the test-kit adoption) sits behind a checkpoint. No milestone edits anything under
`libs/` or `tests/_kit/`.

**Standing gate for every task:** `luacheck .` clean and `lua5.1 tests/run.lua` at 656/656 before the
task is called done (`testing-§4`). The four-suite bundle is a **release** artifact and must not be
run as a commit gate (`automated-tests-§3/§6`).

---

## Milestone 1 — Fix the degraded seam

**Why first:** it holds all three High findings, it is the smallest diff of the five milestones, and
it is the only work in this review with a reproduced runtime crash behind it.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| **M1-T1** | lua-refactorer | C-01 (F-001, F-002) | `settings/Panel.lua` |
| **M1-T2** | ux-cleanup | C-02 (F-003) | `settings/Panel.lua` |
| **M1-T3** | test-author | C-03 (F-004) | `tests/test_settingsui.lua` |

**Concurrency:** M1-T1 and M1-T2 both touch `settings/Panel.lua` → **must serialize** (T1 then T2).
M1-T3 is a different file but depends on T1's behaviour, so it runs **after** T1 — write the
assertion first, watch it go red against the unfixed code, then apply T1 and watch it go green.
That ordering is `testing-§4`'s test-first rule and it is also the falsification evidence
`testing-§12` asks for.

**Done when:** `loader.loadWithSchemaDegraded()` can call `Helpers.SetAndRefresh` and
`KCM.Options.Refresh` without raising; the degraded login notice names no `/cm` subcommand as
working; suite still 656/656; the `03_SMOKE_TESTS.md` "C-01 / C-02 — Degraded install" section
passes in-client.

**Commit boundary:** one commit.
`fix(settings): make the degraded install seam actually degrade (F-001, F-002, F-003)`

---

## Milestone 2 — One write path for the macro-bar toggles

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| **M2-T1** | lua-refactorer | C-04 (F-005) — slash verbs write through the schema | `core/SlashCommands.lua` |
| **M2-T2** | lua-refactorer | C-04 — `macroBar.locked` gains its `onChange`; `MB.SetEnabled`/`SetLocked` stop writing the DB | `settings/MacroBar.lua`, `modules/MacroBar.lua` |
| **M2-T3** | test-author | Cover the slash→panel re-sync direction | `tests/test_slash.lua` **or** `tests/test_macrobar.lua` |

**Concurrency:** M2-T1 and M2-T2 touch disjoint files and could run in parallel, but the intermediate
state (slash writes through the schema while `MB.SetEnabled` still also writes) is a double write.
**Serialize T1 → T2**, or land them as one change. M2-T3 runs last.

**Note on the inventory:** if M2-T3 adds a case, `docs/test-cases.md` and the README `[Tests]` badge
move **in the same commit** (`testing-§5`). Regenerate with
`lua5.1 tests/run.lua --list > docs/test-cases.md` — never hand-edit.

**Done when:** `/cm bar on|off|lock|unlock` re-syncs the Macro Bar page's checkboxes with the panel
open; the `03_SMOKE_TESTS.md` C-04 section passes; suite green at its new count.

**Commit boundary:** one commit.
`fix(macrobar): route /cm bar through the schema write seam (F-005)`

---

## Milestone 3 — Small, independent cleanups

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| **M3-T1** | lua-refactorer | C-08 (F-009 then F-008) | `core/TooltipCache.lua`, `.luacheckrc` |
| **M3-T2** | wow-api-migrator | C-09 (F-010) | `core/Compat.lua`, `core/TooltipCache.lua` |
| **M3-T3** | lua-refactorer | C-12 (F-012) | `modules/MacroBar.lua` |
| **M3-T4** | doc-cleanup | C-11 (F-011, F-013) | `modules/DebugLog.lua`, `core/ConsumableMaster.lua` |

**Concurrency:** M3-T1 and M3-T2 **both touch `core/TooltipCache.lua` → must serialize** (T1 then
T2; T1 deletes lines above T2's edit site, so doing it in that order avoids a rebase).
M3-T3 and M3-T4 are **parallelizable** with each other and with the T1→T2 chain — disjoint files,
except that M3-T4 touches `core/ConsumableMaster.lua`, which nothing else in this milestone touches.

**Done when:** `luacheck .` is clean with `241` **removed** from the global ignore list; the suite is
green; the `03_SMOKE_TESTS.md` C-08 and C-09 sections pass in-client.

**Commit boundary:** three commits.
1. `refactor(tooltipcache): remove the write-only pendingIDs set and narrow the lint ignore (F-009, F-008)`
2. `refactor(compat): route the last bare GetItemInfo through the compat seam (F-010)`
3. `chore: remove a dead export and correct three stale comments (F-011, F-012, F-013)`

---

## CHECKPOINT 1 — before the refactor

**Human verification, mandatory.** Milestones 1–3 change shipping code and are the whole
user-visible value of this review. Milestone 4 changes only `tests/` and is large.

Before starting M4, confirm:
- `03_SMOKE_TESTS.md`'s C-01, C-02, C-04, C-08, C-09 sections, the full **Regression suite**, and the
  **Taint-specific tests** are signed off in-client.
- The perf capture in `03_SMOKE_TESTS.md` has been run and its record committed under
  `docs/perf-runs/`, so there is a baseline the kit adoption can be compared against if anything
  looks different afterwards.
- The suite is green and the inventory matches (`lua5.1 tests/run.lua --list | diff - docs/test-cases.md`).

**If the checkpoint is not clean, stop.** Milestone 4 must not begin over an unverified base — the
whole point of adopting the kit is that a suite failure afterwards is attributable to the adoption.

---

## Milestone 4 — Adopt the vendored test kit

**Why behind the checkpoint:** it is the largest change in the review (three files, ~1000 lines
replaced), it touches nothing that ships, and the mock swap in particular is expected to surface real
defects rather than to be clean.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| **M4-T1** | test-infra | C-05 — adopt `tests/_kit/framework.lua` | `tests/run.lua`, `tests/harness.lua` (deleted at end) |
| **M4-T2** | test-infra | C-06 — adopt `tests/_kit/loader.lua` | `tests/loader.lua` |
| **M4-T3** | test-infra | C-07 — `tests/wow_mock.lua` becomes a thin extender over `mock_base.lua` | `tests/wow_mock.lua` |
| **M4-T4** | test-infra | C-10 — make the vendor-sync skip visible | `tests/test_vendor_sync.lua` |

**Concurrency:** strictly serial, **T1 → T2 → T3 → T4**. Each of the first three is a dependency of
the next (the loader is reached through the framework; the mock is installed by the loader), and each
must end at 656/656 before the next begins. Running two in parallel makes any red unattributable,
which is the one thing this milestone cannot afford.

**Hard rules for this milestone:**
- **Never edit anything under `tests/_kit/`.** A kit defect is an upstream finding in the LibKa0s
  repo: fix there, bump the kit revision, re-vendor the whole folder here as its own commit
  (`testing-§1`, `testing-§11`).
- **A case that reddens under M4-T3 is a finding about the addon, not a reason to soften the mock.**
  The base mock is deliberately stricter (`testing-§1`, mock fidelity). Log it and stop; do not
  weaken the assertion and do not delete the case.
- If the kit's `--list` renderer produces a different inventory format, that is a real move:
  regenerate `docs/test-cases.md` in the same commit and check the README `[Tests]` badge
  (`testing-§5`).

**Done when:** `tests/harness.lua` no longer exists; `tests/run.lua` `dofile`s the kit's
`framework.lua` and `loader.lua`; `tests/wow_mock.lua` opens with
`local base = dofile("tests/_kit/mock_base.lua")`; the two vendor-sync cases report a distinct,
visible outcome when `../LibKa0s` is absent; suite green; `03_SMOKE_TESTS.md`'s Regression suite
re-run clean in-client (to prove no shipping file moved).

**Commit boundary:** four commits, one per task, each green.
1. `test: adopt the vendored kit framework (F-006)`
2. `test: adopt the vendored kit loader (F-006)`
3. `test: make wow_mock a thin extender over the kit's base mock (F-006)`
4. `test: make the vendor-sync skip visible rather than silent (F-007)`

---

## CHECKPOINT 2 — before release

Confirm before any version bump:
- All four out-of-game suites run via `tests/_kit/run-automated-tests.sh` (the release bundle, run
  **now** and not before — `automated-tests-§6`).
- The release gate holds: `lint` and `tests` pass, and `suites.complexity.warnings == 0`
  (`automated-tests-§3`). A `skip` on `complexity` blocks as NOT EVALUATED; it must be a genuine
  `pass`. `perf` will still record `skip` with its standing reason — that is expected and is not the
  complexity gate.
- `docs/test-cases.md` and the README `[Tests]` badge agree with the suite's actual output.
- `05_FINAL_SUMMARY.md` is filled in from what actually shipped, not from this plan.

---

## Critical path and parallelism map

```
M1-T1 ──► M1-T2 ──► M1-T3 ─────────────┐
                                        │
M2-T1 ──► M2-T2 ──► M2-T3 ─────────────┤
                                        ├──► CHECKPOINT 1 ──► M4-T1 ► M4-T2 ► M4-T3 ► M4-T4 ──► CHECKPOINT 2
M3-T1 ──► M3-T2 ────────────────────────┤
M3-T3 ──────────────────────────────────┤
M3-T4 ──────────────────────────────────┘
```

**Serialization callouts (shared files):**

| Shared file | Tasks | Order |
|---|---|---|
| `settings/Panel.lua` | M1-T1, M1-T2 | T1 → T2 |
| `core/TooltipCache.lua` | M3-T1, M3-T2 | T1 → T2 |
| `modules/MacroBar.lua` | M2-T2, M3-T3 | M2-T2 → M3-T3 (M2 is a behaviour change; M3-T3 is a deletion) |
| `core/ConsumableMaster.lua` | M3-T4 only | — |
| `tests/*` (kit adoption) | M4-T1..T4 | strictly serial |

**Parallelizable:** the three milestone chains M1, M2 and M3 touch disjoint file sets **except**
`modules/MacroBar.lua` (M2-T2 vs M3-T3). Run M1 and M3-T1/T2/T4 concurrently with M2 if you have the
agents; hold M3-T3 until M2-T2 has landed.
