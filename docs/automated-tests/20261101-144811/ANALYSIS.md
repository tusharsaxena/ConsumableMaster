# Analysis — 20261101-144811

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** d887ef4e8c0c304e68e6192b0d2c12a7ed86a541 (feat/2026-11-01-full-skinning)
- **Previous run:** [`20261101-025920`](../20261101-025920/)

## Headline

The first run on LibKa0s v1.85.0 (local tag), taken on a clean tree after the macro bar's colors and shadow moved onto the skin (FS-CM-FLIP) and the settings marks onto `S.Mark` (FS-CM-FIX). All four suites ran and passed: lint 0/0 over 147 files, 1345 of 1346 cases passed with the one declared skip and none failed, five perf scenarios, and no function above CCN 15 with `blindFiles` 0 and `crashedFiles` 0. Nothing newly crossed a threshold.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since 20261101-025920 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 147 files | [`lint.txt`](lint.txt) | 146 → 147 files |
| tests | pass | 1345 passed, 1 skipped, 0 failed, 1346 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1319 → 1346 cases |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see What moved |

| Metric | Value |
|---|---|
| Total NLOC | 30929 |
| Functions | 3630 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The single skip in [`tests.txt`](tests.txt) is the diagnostics-contract case for an addon that opts out of logging. This addon keeps the default, so that path has nothing to run against here; it was present in the previous run.

## What moved

- **lint:** one more file in scope, `tests/test_skin_flip.lua`. 0 warnings, 0 errors, as before.
- **tests:** 27 cases added, none removed: [`test-cases.md`](test-cases.md) names the 20 in `test_skin_flip.lua` and the 7 `Skin marks:` cases in `test_skin_surfaces.lua`. The skip count holds at 1 and the failed count at 0. Existing suites moved with the flip: the schema version, the row counts, the shipped face, and two earlier ladder cases that now seed `skin.fullSkinReset`.
- **perf:** all five bytes/iter figures are identical to the previous run in [`perf.json`](perf.json), including `recompute` at 247384.1. None of the five scenarios runs `MacroBarButton.ApplyStyle`, so this run says nothing about the bar's appearance pass, which gained one `S.HudFont` call per label and one `SetTextColor` per count; there is no pin in `tests/perf.lua` to move. `recompute` read 1.51397 ms/iter and `cooldownRefresh` 0.03620 against 1.42393 and 0.02816, on an unchanged byte count, and timings are for orientation only.
- **complexity:** NLOC 30199 → 30929, functions 3547 → 3630, the flip's and the marks' code and suites. Avg NLOC 7.8 → 7.9, avg tokens 65.3 → 65.6, avg CCN 2.5 and max CCN 15 hold. The addon grew and did not get denser. Warnings, band files, over-cap, blind and crashed counts did not move. Within the band, `settings/Category.lua` rose 1034 → 1049 with the legend's marks.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1049 | Peeled under #43, stays on notice. Accepted — page breadth, not tangle; re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1114 | Accepted — case count, not tangle; re-check at 1300. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted — fake breadth, not tangle; re-check at 1300. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`, which the runner carried forward. No file newly crossed and no cell was left blank, so none was owed. This is not a release run, so the acceptance counts do not advance.

## Actions

1. New: `tests/perf.lua` has no scenario for the bar's appearance pass, so the flip's cost there is unmeasured. Worth a scenario before the tag.
2. The owner's smoke of SKIN-31 to SKIN-36 and the thirteen re-opened checks is owed (`docs/smoke-tests.md`, *Pending sign-off*).
