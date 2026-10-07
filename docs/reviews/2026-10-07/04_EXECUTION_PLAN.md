# 04 — Execution plan

The plan has seven changes (C-01..C-07) covering eight findings (F-001..F-008). No upstream milestone is needed, because no finding lands
in LibKa0s or the testkit. The work stays on the collection branch `feat/2026-10-07-review-audit-remediation`.

**Gate for every commit.** The repo's `CLAUDE.md` gate must pass: `lua5.1 tests/run.lua` with 0 failed and `luacheck .` at 0/0. The
same commit also regenerates `docs/test-cases.md` (`--list`) and moves the README `[Tests]` badge, per `testing-§5`.

Do not touch `## Version:`, `KCM.VERSION` or the changelog. Do not touch `libs/` or `tests/_kit/`.

## Milestone M1 — the two High fixes (F-001, F-002, F-008)

**Done when:** C-01 and C-02 are committed, the gate is green, the 3 + 1 new cases are present in `docs/test-cases.md`, and the badge
has moved.

| Task | Role | Implements | Files |
|---|---|---|---|
| M1-T1 | lua-fixer + test-author | C-01 (F-001) | `modules/MacroManager.lua`, `tests/test_macromanager.lua`, `tests/test_profiles.lua`, `docs/macro-manager.md`, `docs/test-cases.md`, `README.md` |
| M1-T2 | data-maintainer + test-author | C-02 (F-002, F-008) | `defaults/Defaults_StatPriority.lua`, `tests/test_defaults.lua`, `docs/test-cases.md`, `README.md` |

**Concurrency.** T1 and T2 have disjoint source files, but both edit `docs/test-cases.md` and the README badge. They are
**parallelizable for authoring and serialized at commit**. Whichever commits second regenerates the inventory and the badge from its
own run.

**Checkpoint CP1 (human).**
- Run `03_SMOKE_TESTS.md` C-01, steps 1–5. Step 5 rules out client-side body normalization before anything builds on the
  live-body check.
- C-02 needs the Devourer secondary order sourced from archon.gg. The owner confirms that row before M1-T2 commits.

## Milestone M2 — correctness and performance (F-003, F-004, F-007)

**Done when:** C-03, C-04 and C-07 are committed, the gate is green, and the offline attribution shows `MacroBar.Refresh` below
142727.7 B and 107 `GetItemByID` calls per refresh.

| Task | Role | Implements | Files |
|---|---|---|---|
| M2-T1 | perf-fixer | C-03 (F-003) | `modules/MacroBar.lua`, `modules/MacroBarFlyout.lua`, `tests/test_macrobar_flyout.lua`, optionally `tests/perf.lua` and `docs/performance.md`, `docs/test-cases.md`, `README.md` |
| M2-T2 | lua-fixer | C-04 + C-07 (F-004, F-007) | `core/ConsumableMaster.lua`, `docs/data-flow.md`, `tests/test_pipeline.lua`, `tests/test_events.lua`, `docs/test-cases.md`, `README.md` |

**Concurrency.** The source files are disjoint, so the two are **parallelizable**. They serialize at commit on the inventory and badge,
as in M1.

**Checkpoint CP2.**
- Re-run the scratch attribution and record the before and after numbers in the commit body.
- Run in-client `03_SMOKE_TESTS.md` C-03, C-04 and C-07.

## Milestone M3 — hygiene (F-005, F-006)

**Done when:** C-05 and C-06 are committed and the gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| M3-T1 | lua-refactorer | C-05 (F-005): characterization case first, refactor second | `tests/test_selector.lua`, then `modules/MacroManager.lua` and `modules/Selector.lua` |
| M3-T2 | ux-cleanup | C-06 (F-006) | `core/SlashCommands.lua`, `tests/test_slash.lua` |

**Concurrency.**
- M3-T1 edits `modules/MacroManager.lua`, which **M1-T1 also touches**. M3-T1 must start after M1-T1 has landed.
- M3-T2 is independent of everything else in M3 and can start at any time after M1.

**Checkpoint CP3.** Run in-client C-05 and C-06, then the full regression suite in `03_SMOKE_TESTS.md`.

## Critical path

M1-T1 → M3-T1, because both touch `modules/MacroManager.lua`. Everything else is free to interleave, apart from the shared
`docs/test-cases.md` and README badge at commit time.

## Commit strategy (one commit per change)

```
F-001: confirm the live macro before the fingerprint early-out
F-002 + F-008: seed Devourer (12_1480) and test the stat seed per spec
F-003: one score cache per macro-bar refresh
F-004 + F-007: discover on a spec change; ignore other units' spec changes
F-005: one composite-config resolver (characterization first)
F-006: strict IDs in /cm priority
```

Each commit message ends with the session's attribution trailers. Push happens only at a milestone checkpoint, and only when the
owner authorizes it. No merge and no version bump.
