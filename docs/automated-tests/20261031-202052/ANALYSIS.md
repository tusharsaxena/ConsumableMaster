# Analysis — 20261031-202052

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** c7658c6f3457354b71f85b5a43e7635dced5ee09 (feat/2026-10-31-font-pickers-skin-faces)
- **Previous run:** [`20261009-191755`](../20261009-191755/), the 1.8.0 release run

## Headline

The pre-merge run for the font pickers and skin faces work. All four suites ran and passed on a
clean tree: lint 0/0 over 140 files, 1316 of 1317 cases passed with one declared skip and none
failed, five perf scenarios, and no function above CCN 15 with `blindFiles` 0 and `crashedFiles` 0.
Nothing crossed a threshold. Max CCN rose from 14 to 15, which sits at the ceiling and not over it,
and the `recompute` allocation figure doubled; see *What moved*, because that figure is not reading
what it appears to.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20261009-191755` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 140 files | [`lint.txt`](lint.txt) | 130 → 140 files; 0/0 unchanged |
| tests | pass | 1316 passed, 1 skipped, 0 failed, 1317 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1216 → 1317 total; skipped 1 → 1 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` bytes/iter 13741.2 → 29832.8, the other four identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 14 → 15; band files 7 → 7; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the footer of
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 30106 |
| Functions | 3541 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted and measured: `blindFiles` and `crashedFiles` are both 0.

**The one skipped case** ([`tests.txt`](tests.txt), line 1306) is the same declared skip as the
previous run: the kit's diagnostics-contract branch for an addon that opts out of turning logging
on, which this addon does not. It is counted in neither passed nor failed.

Perf and complexity record and do not gate this run or the commit. Both gate the tag, which
`/dev-copilot:bump-version` evaluates from a release run's manifest. This is not a release run.

## What moved

**Lint: ten more files, still 0/0** ([`lint.txt`](lint.txt)). The added files are listed in that
artifact; the scope exclusions in `.luacheckrc` did not change.

**Tests: 1216 → 1317.** 101 more cases, and the one skip is unchanged
([`test-cases.md`](test-cases.md)).

**Perf: `recompute` bytes/iter 13741.2 → 29832.8; do not read this as new garbage.**
`tests/perf.lua` takes `collectgarbage("count")` either side of the scenario with the collector
running, so a cycle that lands inside the loop subtracts from the figure, and the reading follows
heap size and collector pacing as well as the code path. A bisect outside this bundle moved the
figure at a LibKa0s re-vendor with no addon-source change, the figure went both down and up across
the range, and with the collector paused for the scenario the allocation did not meaningfully move
between the two runs' commits. Those probes are not evidence held here, so their numbers are not
quoted. The other four scenarios read the same bytes/iter as the previous run. Timings are not
compared across runs ([`perf.txt`](perf.txt) says so itself).

**Complexity: the addon grew, its density did not.** NLOC 27450 → 30106 and functions 3222 → 3541,
while avg CCN stays 2.5, avg NLOC stays 7.9 and avg tokens moves 65.2 → 65.4. Max CCN moves 14 → 15:
two functions sit at 15, `BB.ApplyCountFont` (`modules/MacroBarButton.lua`) and `splitArgs`
(`tests/test_skin_surfaces.lua`). Both are at the ceiling and neither warned
([`complexity.txt`](complexity.txt)).

## Complexity watch list

### Functions the complexity tool warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1186 | Peel tracked as #43; 1150 → 1186. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1231 | Accepted — page breadth, not tangle; re-check at 1300. 1182 → 1231. Acceptance 2 of 3. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1143 | Peel tracked as #42; 1196 → 1143. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1176 | Accepted — case count, not tangle; re-check at 1300. 1023 → 1176. Acceptance 2 of 3. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1049 | Accepted — case count, not tangle; re-check at 1300. Unchanged. Acceptance 2 of 3. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1151 | Accepted — case count, not tangle; re-check at 1300. 1002 → 1151. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted — fake breadth, not tangle; re-check at 1300. Unchanged. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`. No file newly crossed, so no cell was
blank and none was edited. This is not a release run, so no acceptance count advanced.

## Actions

1. `settings/Panel.lua` and `settings/Category.lua`: the #42 and #43 peels are still open.
2. `settings/MacroBar.lua`, `tests/test_schema.lua` and `tests/test_selector.lua` stay at acceptance
   2 of 3. The next release run owes each a fix or a tracked issue (`automated-tests-§4`,
   anti-pattern #53). No issue tracks them yet.
3. `tests/perf.lua`: pausing the collector across the scenario would make `recompute` bytes/iter
   stable and comparable. New here; no issue tracks it yet.
