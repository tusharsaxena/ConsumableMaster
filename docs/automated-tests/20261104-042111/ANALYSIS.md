# Analysis — 20261104-042111

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** 4c3280a (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** [`20261102-004443`](../20261102-004443/)

## Headline

This is the round 6 finish run (label `R6 finish`). It comes 24 commits after the previous run: rounds 3 to 6 of the full skinning run, five LibKa0s v1.85.0 re-cuts, the picker preview unlock (R6-PV) and the README rename (R6-NAME). All four suites ran and passed. Lint was 0/0 over 151 files, and 1403 of 1404 cases passed with the one declared skip. The five perf scenarios ran, no function measured above CCN 15, and `blindFiles` and `crashedFiles` were both 0. Nothing newly crossed a threshold, and nothing needs action.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-004443 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 151 files | [`lint.txt`](lint.txt) | files 149 → 151 |
| tests | pass | 1403 passed, 1 skipped, 0 failed, 1404 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1388 → 1404 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `recompute` 247384.1 → 247384.4 bytes/iter |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 31338 → 31776, functions 3716 → 3784 |

| Metric | Value |
|---|---|
| Total NLOC | 31776 |
| Functions | 3784 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value above is from `manifest.json`'s `suites`. The one skip is the same case the previous run skipped: the diagnostics-contract case for an addon that opts out of logging. As every skip is, it is counted in the total and not in `passed`.

## What moved

- **lint:** two more files are in scope, the new suites `tests/test_icon_rule.lua` and `tests/test_launcher_skin_entry.lua`. Lint is still 0/0, and `.luacheckrc` still excludes the same four paths.
- **tests:** 16 more cases (1388 → 1404). They come from the two new suites and from additions to the skin picker, skin flip, debug log and database suites for R5-ICON, SF-F2, SG-L3 and R6-PV. The single skip did not change.
- **perf:** the same five scenarios ran. `recompute` allocation is effectively unchanged (247384.1 → 247384.4 bytes/iter), and `refreshBurst` still allocates nothing. Timings are for orientation only.
- **complexity:** 438 more NLOC and 68 more functions. Avg NLOC (7.8), avg CCN (2.5) and max CCN (15) all held, so the code grew without getting denser. The three band files kept their LOC (1050, 1114, 1012), so the carried dispositions still hold.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1050 | Peeled under #43, stays on notice. Accepted: page breadth, not tangle; re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1114 | Accepted: case count, not tangle; re-check at 1300. Unchanged since the previous run. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted: fake breadth, not tangle; re-check at 1300. Unchanged since the previous run. |

## Actions

None.
