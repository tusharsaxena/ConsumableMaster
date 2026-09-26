# Analysis — 20260926-160431

- **Addon:** ConsumableMaster 1.6.2
- **Verdict:** green
- **Commit:** bc284a457d5710a0460bf738e69c0f8e00f8d6c6 (master)
- **Previous run:** [`20260924-120622`](../20260924-120622/), the row below this one in `RESULTS.md`

## Headline

All four suites ran and passed on a clean `master` tree: lint 0/0 over 122 files, 1112 cases green
with nothing skipped, five perf scenarios, and no function warned on (max CCN 14). The run lands 22
commits after the previous bundle, which measured `f8729fa`: the diagnostics rollout
(`/cm diagnostics`, LibKa0s v1.60.0) and the nav-rail re-vendor (LibKa0s v1.61.0). One figure moved
enough to read: the `recompute` perf scenario's allocation rose **6505.88 → 14740.12 bytes/iter**
(+126.6%). Perf gates neither the run nor the commit, but it does gate the tag, and nothing here says
which commit caused it. This is not a release run (`manifest.json` `release: null`).

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260924-120622` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 122 files | [`lint.txt`](lint.txt) | files 119 → **122** (+3); warnings and errors both still 0 |
| tests | pass | 1112 passed, 0 skipped, 0 failed, 1112 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1071 → **1112** (+41); skipped still 0 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` bytes/iter **+126.6%**, the other four byte-identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 14 → 14; band files 8 → 8; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the complexity
tool's own footer in [`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 25645 |
| Functions | 2835 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 14 |
| Avg tokens / function | 62.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |

Every suite passed, so there is no skip to explain and no failing output to read. Every tool was
present: `manifest.json`'s `host` block records Lua 5.1.5, Luacheck 1.2.0 and complexity tool 1.24.0.
`complexity.txt` reports "No thresholds exceeded" for CCN, length, NLOC and parameter count alike.

## What moved

**Lint: 119 → 122 files, still 0/0.** The `Checking` lines of the two bundles' `lint.txt` differ by
three additions and no removals: `core/Diagnostics.lua`, `tests/mock_menu.lua` and
`tests/test_diagnostics.lua`, all from the diagnostics rollout. The `.luacheckrc` exclusions are the
same four paths named in `RESULTS.md`'s *Lint* section.

**Tests: 1071 → 1112, +41.** The diagnostics report and its contract cases
(`tests/test_diagnostics.lua`), the read-only accessors behind it, and the macro bar's close mark.
[`test-cases.md`](test-cases.md) is the authority on which cases exist; it is identical to
`docs/test-cases.md` at this commit, and the README `[Tests]` badge reads 1112/1112.

**Perf: `recompute` allocation more than doubled; the rest held.** Reading [`perf.json`](perf.json)
against [the previous one](../20260924-120622/perf.json), bytes per iteration at the same 200
iterations: `recompute` **6505.88 → 14740.12** (+8234.24, +126.6%). The other four are
byte-identical to the previous run: `cooldownRefresh` 6000, `probeOverheadOff` 6000,
`probeOverheadOn` 6001.32, `refreshBurst` 0. The zero-overhead pair, `performance-§9`'s evidence,
did not move. `tests/perf.lua` itself did not change between `f8729fa` and `bc284a4`, so the scenario
measures the same thing and the rise is in the code under it. The runtime files that changed in that
range are `core/TooltipCache.lua`, `modules/MacroManager.lua`, `modules/MacroBar.lua`,
`core/Diagnostics.lua` and the launcher / lifecycle / slash setup, alongside two LibKa0s re-vendors.
Which of those did it is **not established** by this run. The previous analysis put this scenario at
6323.88 and then 6505.88 bytes/iter, so this is a step change rather than drift. Wall time
(226.763 → 246.408 ms total) is for orientation only and is not read as a signal.

**Complexity: the addon grew at the same density.** NLOC 24468 → 25645 (+1177) and functions
2685 → 2835 (+150). Avg NLOC per function held at 7.8, avg CCN at 2.5, and avg tokens moved
62.9 → 62.8. Max CCN is still 14, and eleven functions sit on it, the same count the previous
analysis gave. Three of them are in `settings/Category.lua`, including `renderCompositeSection`,
which the #43 peel moves out.

**Band: 8 → 8 files, one line moved.** `tests/test_slash.lua` 1425 → 1426. Every other band file's
LOC is unchanged. Nothing newly entered the band and nothing crossed the 1500 cap.

## Complexity watch list

**Functions warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. No function is above CCN 15.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1426 | Accepted on notice, case count not tangle; re-check at 1475 (carried) |
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1425 | Accepted on notice, case count not tangle; re-check at 1475 (carried) |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1419 | Accepted on notice, case count not tangle; re-check at 1475 (carried) |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1169 | Accepted, page breadth; re-check at 1300 (carried) |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1166 | Peel tracked as [#42](https://github.com/tusharsaxena/ConsumableMaster/issues/42) (carried) |
| 1000–1500 (on notice) | `settings/Category.lua` | 1142 | Peel tracked as [#43](https://github.com/tusharsaxena/ConsumableMaster/issues/43) (carried) |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | Accepted, case count; re-check at 1300 (carried) |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1009 | Accepted, case count; re-check at 1300 (carried) |

The runner left no Disposition cell in `RESULTS.md` blank, so nothing new was owed a ruling.
Shelf life: the three release runs (1.6.0, 1.6.1, 1.6.2) carried only `settings/Panel.lua` and
`settings/Category.lua` as Accepted, and both are now tracked peels. No other entry has been carried
as Accepted through a release run yet, so none has crossed the `automated-tests-§4` limit.

## Actions

1. `recompute` allocation (+126.6% bytes/iter): bisect `f8729fa..bc284a4` with `tests/perf.lua` to
   find the commit, then decide whether the new allocation is intended. This is new here: no issue or
   deviation tracks it, and perf gates the tag.
2. `settings/Panel.lua` and `settings/Category.lua`: the #42 and #43 peels are still open work,
   carried from the previous analysis.
3. `tests/test_slash.lua` (1426), `tests/test_macrobar.lua` (1425) and `tests/test_settingsui.lua`
   (1419) remain within 81 lines of the cap, carried from the previous analysis and still untracked.
