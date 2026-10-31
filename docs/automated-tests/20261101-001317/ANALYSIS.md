# Analysis — 20261101-001317

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** 7b56d4cde72939a59e8295f0cdf100d466418d1f (feat/2026-10-31-findings-remediation)
- **Previous run:** [`20261031-212150`](../20261031-212150/)

## Headline

The LibKa0s v1.84.0 adoption run, labelled `v1.84.0-adoption`. All four suites ran and passed on a
clean tree: lint 0/0 over 146 files, 1317 of 1318 cases passed with the one declared skip and none
failed, five perf scenarios, and no function above CCN 15 with `blindFiles` 0 and `crashedFiles` 0.
The only movement of note is one new test case, and nothing newly crossed a threshold.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20261031-212150` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 146 files | [`lint.txt`](lint.txt) | Unchanged in every figure |
| tests | pass | 1317 passed, 1 skipped, 0 failed, 1318 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1317 → 1318 total; 1316 → 1317 passed; skipped and failed unchanged |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; bytes/iter identical in all five |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 15 → 15; band files 3 → 3; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the footer of
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 30213 |
| Functions | 3548 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass, with one standing fact to name. The single skip in
[`tests.txt`](tests.txt) is the diagnostics-contract case for an addon that opts out of logging:
this addon keeps the default, so the opt-out path has nothing to run against here. It is not a
regression, it is counted in neither the passed nor the failed figure, and it was present in the
previous run.

## What moved

- **lint:** nothing. 146 files, 0 warnings, 0 errors, as in the previous run.
- **tests:** one case added, and [`test-cases.md`](test-cases.md) names it: `macrobar handle: a
  layout pass while unlocked refits the strip at the new scale and width`, in
  `test_macrobar_chrome.lua`, which goes from 29 to 30. The skip count holds at 1 and the failed
  count at 0.
- **perf:** the scenario set is unchanged and all five bytes/iter figures are identical to the
  previous run, including `recompute` at 247384.1, the baseline the previous run set. The ms/iter
  figures moved in both directions (`recompute` 1.09475 → 1.07467, `cooldownRefresh`
  0.01834 → 0.01891). Timings are for orientation only, and these do not read as a change.
- **complexity:** NLOC 30188 → 30213, functions 3541 → 3548. Avg NLOC 7.9 → 7.8 and avg tokens
  65.4 → 65.3 fell slightly, avg CCN holds at 2.5, and max CCN holds at 15. The addon grew and got
  no denser. Warnings, band files, over-cap, blind and crashed counts did not move.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1034 | Peeled under #43, stays on notice. Accepted — page breadth, not tangle; re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1151 | Accepted — case count, not tangle; re-check at 1300. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted — fake breadth, not tangle; re-check at 1300. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`, which the runner carried forward because
no entry changed. No file newly crossed, so no cell was owed. This is not a release run, so the
acceptance counts do not advance.

## Actions

1. Carried from [`20261031-212150`](../20261031-212150/ANALYSIS.md): GitHub issues #42
   (`settings/Panel.lua`) and #43 (`settings/Category.lua`) close when this branch merges.
