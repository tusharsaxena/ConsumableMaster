# Analysis — 20260804-114709

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** 8e84bc2e7367 (master), dirty
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
54 files and the headless harness passes 605 of 605 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Moved since previous run |
|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files (`lint.txt`) | — first run |
| tests | pass | 605 passed, 0 failed, 605 total (`tests.txt`) | — first run |
| perf | skip | skip | — first run |
| complexity | pass | 20 warnings, max CCN 62, 14339 NLOC / 1477 functions (`complexity.txt`) | — first run |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured here. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

| `run` | 62 | `core/SlashDump.lua` | **Accepted — the branch count *is* the diagnostic.** `/cm dump pick`; runs on a typed command, never a frame. |
| `run` | 32 | `core/SlashDump.lua` | **Accepted**, same grounds — `/cm dump <itemID>`. |
| `commitMacro` | 35 | `modules/MacroManager.lua` | **Accepted, and rising is the win.** F-006 collapsed `SetCompositeMacro` into it; 27 → 35 is the second copy being absorbed. |
| `buildCompositeBody` | 27 | `modules/MacroManager.lua` | **Peel next — now unblocked.** Its "peel with F-006" gate is discharged. |
| `validateSchemaValue` | 18 | `settings/Panel.lua` | **Peel next, with F-013** — that finding adds branches to this exact function. |

Sixteen further entries accepted with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_macrobar.lua` (1129) — accepted, case count not tangle.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
