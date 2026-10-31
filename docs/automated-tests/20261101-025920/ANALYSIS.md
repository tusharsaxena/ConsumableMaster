# Analysis — 20261101-025920

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** 63210848b04f3755400e153d3f8af84c09744dda (feat/2026-10-31-findings-remediation)
- **Previous run:** [`20261101-001317`](../20261101-001317/)

## Headline

The run labelled `final-pre-merge`, taken on the branch tip after the re-cut LibKa0s v1.84.0 re-vendor
and the change that makes the Ka0sMedia pickers the only media widgets. All four suites ran and passed
on a clean tree: lint 0/0 over 146 files, 1318 of 1319 cases passed with the one declared skip and none
failed, five perf scenarios, and no function above CCN 15 with `blindFiles` 0 and `crashedFiles` 0.
Nothing newly crossed a threshold. The one thing to read is that every perf timing rose while every
bytes/iter figure held; see What moved.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20261101-001317` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 146 files | [`lint.txt`](lint.txt) | Unchanged in every figure |
| tests | pass | 1318 passed, 1 skipped, 0 failed, 1319 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1318 → 1319 total; 1317 → 1318 passed; skipped and failed unchanged |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; bytes/iter identical in all five; ms/iter higher in all five |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 15 → 15; band files 3 → 3; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the footer of
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 30199 |
| Functions | 3547 |
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
[`tests.txt`](tests.txt) is the diagnostics-contract case for an addon that opts out of logging: this
addon keeps the default, so the opt-out path has nothing to run against here. It is not a regression,
it is counted in neither the passed nor the failed figure, and it was present in the previous run.

## What moved

- **lint:** nothing. 146 files, 0 warnings, 0 errors, as in the previous run.
- **tests:** one net case added. [`test-cases.md`](test-cases.md) names the change: `test_macrobar.lua`
  goes from 35 to 36 with `macrobar schema: the label font row names the Ka0sMedia picker`, and in the
  Settings UI suite `an LSM30_Border another addon registered changes no media row` replaces `the live
  wiring registers the Border fixup through the library`. The skip count holds at 1 and the failed
  count at 0.
- **perf:** the scenario set is unchanged and all five bytes/iter figures are identical to the previous
  run in [`perf.json`](perf.json), including `recompute` at 247384.1. All five ms/iter figures rose:
  `recompute` 1.07467 → 1.42393, `cooldownRefresh` 0.01891 → 0.02816, `probeOverheadOff` 0.01867 →
  0.02371, `probeOverheadOn` 0.01804 → 0.02615, `refreshBurst` 0.01678 → 0.01953. The manifest's suite
  durations rose in the same run for work with no perf relevance (tests 21699 → 28676 ms, complexity
  554 → 3070 ms), so the reading is a busier host rather than a slower addon, and identical allocation
  supports that. This is an inference from those figures, not a measurement of load. Timings are for
  orientation only and do not gate the run.
- **complexity:** NLOC 30213 → 30199, functions 3548 → 3547. Avg NLOC 7.8, avg CCN 2.5, avg tokens 65.3
  and max CCN 15 all hold. The addon shrank slightly and got no denser. Warnings, band files, over-cap,
  blind and crashed counts did not move. Within the band, `tests/test_settingsui.lua` fell 1151 → 1115.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1034 | Peeled under #43, stays on notice. Accepted — page breadth, not tangle; re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1115 | Accepted — case count, not tangle; re-check at 1300. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted — fake breadth, not tangle; re-check at 1300. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`, which the runner carried forward. No file
newly crossed and no cell was left blank, so none was owed. This is not a release run, so the acceptance
counts do not advance.

## Actions

1. Carried from [`20261101-001317`](../20261101-001317/ANALYSIS.md): GitHub issues #42
   (`settings/Panel.lua`) and #43 (`settings/Category.lua`) close when this branch merges.
