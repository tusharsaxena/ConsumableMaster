# Analysis — 20261102-004443

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** 911e438 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** [`20261101-202340`](../20261101-202340/)

## Headline

Recorded after SF-CM-1, which makes the bar draw one thin solid edge under every skin. All four suites ran and passed: lint 0/0 over 149 files, 1387 of 1388 cases passed with the one declared skip, five perf scenarios, no function above CCN 15, `blindFiles` 0 and `crashedFiles` 0. Nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-202340 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 149 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1387 passed, 1 skipped, 0 failed, 1388 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | count unchanged; two cases' expected edge changed |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `recompute` 247384.1 bytes/iter, as before |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 31334 → 31338 |

| Metric | Value |
|---|---|
| Total NLOC | 31338 |
| Functions | 3716 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.2 |
| Warnings (CCN > 15) | 0 |
| Blind files | 0 |
| Crashed files | 0 |

The single skip is the diagnostics-contract case for an addon that opts out of logging; it was present in the previous run.

## What moved

- **tests:** the case count holds. The skin-flip and skin-HUD cases that pinned "no edge under Ka0s Default" now pin the one-pixel solid edge.
- **perf:** the scenarios do not run the bar backdrop pass, so this run is silent about the change's cost. Timings are for orientation only.
- **complexity:** four more lines of code, same function count; averages and max CCN hold.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1050 | Peeled under #43, stays on notice. Accepted — page breadth, not tangle; re-check at 1300. |
