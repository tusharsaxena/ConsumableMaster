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
| [`20260804-233147`](20260804-233147/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-215640`](20260804-215640/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 0 | 0 | **green** |
| [`20260804-182045`](20260804-182045/) | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

## Test suite

656 cases. The `feat/fix-ccn` branch added 51, all of them characterization tests written **before**
the function they cover was split, plus three regression tests from the review round on that branch:
the write path's debug gate is a predicate and not a logging wrapper, the composite macro body is
assembled line-for-line in one table, and a flyout entry's border follows `buttonBorder` through the
bar's own applier on both sides. The generated inventory `test-cases.md` in each bundle is the
authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 54 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its
`tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this
repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a
transient tooling gap. Two things follow, and both are standing facts rather than this run's news:
the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead
evidence — that bracketed instrumentation is free when capture is off — does not exist for it.
Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-215640`](20260804-215640/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

None.

`lizard` warned on nothing: `complexity.txt` ends with `No thresholds exceeded`. This is the
result the `feat/fix-ccn` branch exists for — the previous run listed twenty functions over CCN 15,
topping out at 62, and every one of them was split into named file-locals. Those dispositions are
**not** carried forward. An "Accepted" is a decision about a function that exists, and none of the
twenty exists in its warned form any more; re-listing them as resolved would turn an empty list into
a changelog.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1497 | **Accepted, but now at the cap.** One case per behavior over the most in-client-coupled module, avg CCN 1.3 — case count, not tangle. It gained 368 lines on `feat/fix-ccn` (the flyout and button characterization tests) and sits 3 lines under the 1500 cap: the next case added to it crosses. Split bar / button / flyout at that point, not before. |
