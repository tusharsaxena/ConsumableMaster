# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

| Run | Version | Lint w/e | Tests | Perf | CCN warn | Max CCN | Verdict |
|---|---|---|---|---|---|---|---|
| [`20260804-122513`](20260804-122513/) | 1.5.0 | 0/0 | 605/605 | skip | 20 | 62 | **green** |

## Complexity watch list

Current state as of [`20260804-122513`](20260804-122513/) — not that run's diff.
Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band,
each with a one-line disposition.

| `run` | 62 | `core/SlashDump.lua` | **Accepted — the branch count *is* the diagnostic.** `/cm dump pick`; runs on a typed command, never a frame. |
| `run` | 32 | `core/SlashDump.lua` | **Accepted**, same grounds — `/cm dump <itemID>`. |
| `commitMacro` | 35 | `modules/MacroManager.lua` | **Accepted, and rising is the win.** F-006 collapsed `SetCompositeMacro` into it; 27 → 35 is the second copy being absorbed. |
| `buildCompositeBody` | 27 | `modules/MacroManager.lua` | **Peel next — now unblocked.** Its "peel with F-006" gate is discharged. |
| `validateSchemaValue` | 18 | `settings/Panel.lua` | **Peel next, with F-013** — that finding adds branches to this exact function. |

Sixteen further entries accepted with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_macrobar.lua` (1129) — accepted, case count not tangle.
