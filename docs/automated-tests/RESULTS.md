# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-182045`](20260804-182045/) | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

## Test suite

605 cases, five of them added this session for `SetCompositeMacro`'s write tail — a path that had **no** direct coverage before, because `test_pipeline.lua` only ever stubbed it. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 54 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-182045`](20260804-182045/) — not that run's diff. Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band, each with a one-line disposition.

| `run` | 62 | `core/SlashDump.lua` | **Accepted — the branch count *is* the diagnostic.** `/cm dump pick`; runs on a typed command, never a frame. |
| `run` | 32 | `core/SlashDump.lua` | **Accepted**, same grounds — `/cm dump <itemID>`. |
| `commitMacro` | 35 | `modules/MacroManager.lua` | **Accepted, and rising is the win.** F-006 collapsed `SetCompositeMacro` into it; 27 → 35 is the second copy being absorbed. |
| `buildCompositeBody` | 27 | `modules/MacroManager.lua` | **Peel next — now unblocked.** Its "peel with F-006" gate is discharged. |
| `validateSchemaValue` | 18 | `settings/Panel.lua` | **Peel next, with F-013** — that finding adds branches to this exact function. |

Sixteen further entries accepted with reasons recorded 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_macrobar.lua` (1129) — accepted, case count not tangle.
