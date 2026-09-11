# Analysis — 20260911-211045

- **Addon:** ConsumableMaster 1.6.0 → 1.6.1
- **Verdict:** green
- **Commit:** 0e050cbf38b5 (master), clean
- **Previous run:** [`20260910-234511`](../20260910-234511/)

## Headline

The release run for **1.6.1**, green on all four suites with zero functions above CCN 15. The only change since the `1.6.0-release` tag is the macro-bar click fix, and every average holds to the decimal apart from tokens per function, which moved 63.8 → 64.0. Nothing newly crossed a threshold; the two files over the 1500 cap are still owned by open issues.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260910-234511` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 102 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 792 passed, 0 skipped, 0 failed, 792 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +4 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 5 scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 18912 |
| Functions | 1966 |
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
- **tests** — 788 → 792 passed (+4). The previous run was taken at `7bb3e06`, before two later commits: the weapon-slot fix (790, per its own commit) and the macro-bar click fix (+2, one case for a bar slot and one for a flyout entry). No skips, no failures.
- **perf** — the same 5 scenarios. `recompute` read 1.03551 → 0.91109 ms/iter and 4418.8 → 2845.6 bytes/iter; the other four stayed within a few hundredths of a millisecond. `perf.txt` itself says timings are for orientation only, so this is recorded rather than claimed as an improvement — neither commit in the window touched the recompute path.
- **complexity** — NLOC 18837 → 18912 (+75) over 1960 → 1966 functions (+6). Avg NLOC 8.1 and avg CCN 2.7, both unchanged; avg tokens 63.8 → 64.0. Max CCN 15, zero warnings. The same two band files and the same two over-cap files as before.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1143 | Accepted — carried in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band); unchanged since the tag. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1165 | Accepted — carried in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band); unchanged since the tag. |
| > 1500 (over cap) | `tests/test_macrobar.lua` | 1957 | Owned by [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32). Grew this cycle by the two click-gating cases. |
| > 1500 (over cap) | `tests/test_settingsui.lua` | 1675 | Owned by [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33). Unchanged. |

The band is not part of the release gate. Both *Accepted* entries have now held that disposition across two release runs (1.6.0, 1.6.1); a third would owe a fix or a tracked deviation ID (anti-pattern #53).

## Actions

None new. `tests/test_macrobar.lua` grew under #32 rather than shrinking. The peel that issue names is still the fix, and every case added before it lands makes the peel bigger.
