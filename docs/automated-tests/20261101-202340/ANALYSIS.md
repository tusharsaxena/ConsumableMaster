# Analysis — 20261101-202340

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** 6e16ffe85c844416bd832035bdd3483bc6c5f88c (feat/2026-11-01-full-skinning)
- **Previous run:** [`20261101-144811`](../20261101-144811/)

## Headline

The first run on the re-cut LibKa0s v1.85.0 at kit revision 50, on a clean tree, with the kit's typed-value gate and skin-switch test adopted. All four suites ran and passed: lint 0/0 over 149 files, 1387 of 1388 cases passed with the one declared skip and none failed, five perf scenarios, and no function above CCN 15 with `blindFiles` 0 and `crashedFiles` 0. Nothing newly crossed a threshold; the flip's appearance pass is still unmeasured by perf.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since 20261101-144811 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 149 files | [`lint.txt`](lint.txt) | 147 → 149 files |
| tests | pass | 1387 passed, 1 skipped, 0 failed, 1388 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1346 → 1388 cases |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see What moved |

| Metric | Value |
|---|---|
| Total NLOC | 31334 |
| Functions | 3716 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The single skip in [`tests.txt`](tests.txt) is the diagnostics-contract case for an addon that opts out of logging. This addon keeps the default, so that path has nothing to run against here; it was present in the previous run. Both kit skin suites run for real here and neither is declared a skip.

## What moved

- **lint:** two more files in scope, `tests/skin_switch_facts.lua` and `tests/skin_widget_support.lua`. 0 warnings, 0 errors, as before.
- **tests:** 1346 → 1388, across this commit and the one before it, in [`test-cases.md`](test-cases.md): the kit's `test_skin_values` (3 cases) and `test_skin_switch` (31) are new, `test_skin_flip.lua` went 20 → 25 and `test_skin_surfaces.lua` 20 → 23, net of the three cases of the host's own literal gate, which the kit's replaced. The skip count holds at 1 and the failed count at 0. Pins moved with the release: the shipped `barBorderStyle`, and the bar family's `disabledIf`, now a function.
- **perf:** all five bytes/iter figures are identical to the previous run in [`perf.json`](perf.json), including `recompute` at 247384.08. None of the five scenarios runs `MacroBarButton.ApplyStyle`, so this run says nothing about the appearance pass, which gained one `S.HudFont` call per count. `recompute` read 1.18116 ms/iter against 1.51397 on an unchanged byte count, and timings are for orientation only.
- **complexity:** NLOC 30929 → 31334, functions 3630 → 3716. Avg NLOC 7.9 → 7.8, avg tokens 65.6 → 65.2, avg CCN 2.5 and max CCN 15 hold. The addon grew and did not get denser. Warnings, band files, over-cap, blind and crashed counts did not move. Within the band, `settings/Category.lua` rose 1049 → 1050.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1050 | Peeled under #43, stays on notice. Accepted — page breadth, not tangle; re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1114 | Accepted — case count, not tangle; re-check at 1300. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted — fake breadth, not tangle; re-check at 1300. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`, which the runner carried forward. No file newly crossed and no cell was left blank, so none was owed. This is not a release run, so the acceptance counts do not advance.

## Actions

1. Carried: `tests/perf.lua` has no scenario for the bar's appearance pass, so the flip's cost there is unmeasured. Worth a scenario before the tag.
2. The owner's smoke is owed: SKIN-31 to SKIN-38 and the re-opened checks (`docs/smoke-tests.md`, *Pending sign-off*), PROFILE-2 and PROFILE-5 now among them.
