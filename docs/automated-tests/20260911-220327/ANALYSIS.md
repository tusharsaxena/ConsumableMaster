# Analysis — 20260911-220327

- **Addon:** ConsumableMaster 1.6.1 → 1.6.2
- **Verdict:** green
- **Commit:** e911907471af (master), clean
- **Previous run:** [`20260911-211045`](../20260911-211045/)

## Headline

The release run for **1.6.2**, green on all four suites with zero functions above CCN 15. The only change since the `1.6.1-release` tag is the AIO tooltip fix: four new test cases and 80 more NLOC, with every average unchanged to the decimal. One action is new and needs a decision: both files in the 1000–1500 band have now been carried as *Accepted* across three consecutive release runs.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260911-211045` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 102 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 796 passed, 0 skipped, 0 failed, 796 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +4 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 5 scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 18992 |
| Functions | 1977 |
| Avg NLOC / function | 8.1 |
| Avg CCN | 2.7 |
| Max CCN | 15 |
| Avg tokens / function | 64.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 2 |

## What moved

- **lint** — 102 files in both runs. Still 0 warnings / 0 errors.
- **tests** — 792 → 796 passed (+4), all four from the AIO tooltip fix: the out-of-combat spell step, the in-combat head of the sequence, a disabled or pickless step handing over, and the empty-side fallback. No skips, no failures.
- **perf** — the same 5 scenarios, all within a few hundredths of a millisecond of the previous run: `recompute` 0.91109 → 0.90213 ms/iter (2845.6 → 2947.8 bytes/iter), `cooldownRefresh` 0.02082 → 0.01917, `probeOverheadOff` 0.01898 → 0.01904, `probeOverheadOn` 0.02003 → 0.01905, `refreshBurst` 0.01844 → 0.01785. `perf.txt` itself says timings are for orientation only. The fix does not touch any measured path: the new lookup runs when a tooltip opens, and no scenario opens one.
- **complexity** — NLOC 18912 → 18992 (+80) over 1966 → 1977 functions (+11). Avg NLOC 8.1, avg CCN 2.7 and avg tokens 64.0, all three unchanged. Max CCN 15, zero warnings. The same two band files and the same two over-cap files as before.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1143 | Accepted — carried in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band); unchanged since the tag. Third consecutive release run on *Accepted*: see Actions. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1165 | Accepted — carried in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band); unchanged since the tag. Third consecutive release run on *Accepted*: see Actions. |
| > 1500 (over cap) | `tests/test_macrobar.lua` | 2011 | Owned by [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32). Grew 1957 → 2011 with the four AIO tooltip cases. |
| > 1500 (over cap) | `tests/test_settingsui.lua` | 1675 | Owned by [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33). Unchanged. |

The band is not part of the release gate.

## Actions

1. **`settings/Category.lua` and `settings/Panel.lua` are owed a fix or a tracked deviation ID** (anti-pattern #53). Both read *Accepted* at the 1.6.0 release run ([`20260910-234511`](../20260910-234511/)), the 1.6.1 one ([`20260911-211045`](../20260911-211045/)) and this one. That makes three consecutive release runs on a disposition that names no owner. New here: neither file has an issue or a row in `docs/ARCHITECTURE.md` → *Documented deviations*. The choice between a peel (the Category drag-reorder block is the seam its disposition names) and a ratified deviation belongs to the maintainer, not to this write-up.
2. `tests/test_macrobar.lua` grew again under [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32). No new action: the peel that issue names is still the fix, and it gets bigger with every case added first.
