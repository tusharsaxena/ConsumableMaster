# Analysis — 20260910-234511

- **Addon:** ConsumableMaster 1.5.0 → 1.6.0
- **Verdict:** green
- **Commit:** 7bb3e06132d1 (master), clean
- **Previous run:** [`20260908-181304`](../20260908-181304/)

## Headline

The release run for **1.6.0**, green on all four suites with zero functions above CCN 15. This is the quietest diff of the nine: two new test cases, twelve more NLOC, and every average unchanged to the decimal. The two files over the 1500 cap are unchanged and both are owned by open issues.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260908-181304` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 102 files | [`lint.txt`](lint.txt) | see below |
| tests | pass | 788 passed, 0 skipped, 0 failed, 788 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | see below |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 18837 |
| Functions | 1960 |
| Avg NLOC / function | 8.1 |
| Avg CCN | 2.7 |
| Max CCN | 15 |
| Avg tokens / function | 63.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 2 |

## What moved

- **lint** — 102 files in both runs. Still 0 warnings / 0 errors.
- **tests** — 788 passed, up 2 from 786. No skips, no failures.
- **perf** — 5 scenarios, unchanged.
- **complexity** — NLOC 18825 → 18837 (+12) over 1957 → 1960 functions (+3). Avg NLOC 8.1, avg CCN 2.7, avg tokens 63.8 — all three identical to the previous run. Max CCN 15, zero warnings. Two band files and two over-cap files, the same four as before.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

2 file(s) in the 1000–1500 on-notice band, 2 over the 1500 cap. Each carries a disposition in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

## Actions

None new. The two over-cap suites remain owned: `tests/test_macrobar.lua` by [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32) and `tests/test_settingsui.lua` by [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33), each naming its cut. Neither moved this cycle.
