# Analysis — 20261031-212150

- **Addon:** ConsumableMaster 1.8.0
- **Verdict:** green
- **Commit:** 0448f156dfcc64e4f4a174ed6e71f96754298b83 (feat/2026-10-31-findings-remediation)
- **Previous run:** [`20261031-202052`](../20261031-202052/)

## Headline

The post-remediation run for the findings remediation. All four suites ran and passed on a clean
tree: lint 0/0 over 146 files, 1316 of 1317 cases passed with the one declared skip and none failed,
five perf scenarios, and no function above CCN 15 with `blindFiles` 0 and `crashedFiles` 0. The file
band fell from 7 to 3, and nothing newly crossed. `recompute` bytes/iter reads about eight times
higher, and that is a change of measurement, not of the addon; see *What moved*.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20261031-202052` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 146 files | [`lint.txt`](lint.txt) | 140 → 146 files; 0/0 unchanged |
| tests | pass | 1316 passed, 1 skipped, 0 failed, 1317 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Unchanged in every figure |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` bytes/iter 29832.8 → 247384.1 on a new method; the other four identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 15 → 15; band files 7 → 3; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the footer of
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 30188 |
| Functions | 3541 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 65.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass. The one skip is at case level and is pre-existing: the diagnostics
contract's opt-out case, which does not apply because this addon keeps the default
`Kit.diagnostics.enablesLogging` ([`tests.txt`](tests.txt)). It counts in neither the passed nor the
failed figure. No suite was skipped.

## What moved

**Lint: six more files, still 0/0** ([`lint.txt`](lint.txt)). The six are the remediation's new
files: `settings/About.lua`, `settings/CategoryComposite.lua`, `settings/MacroBarSlots.lua`,
`settings/PanelRows.lua`, `tests/test_schema_tabs.lua` and `tests/test_selector_discovery.lua`. The
four excluded paths are unchanged.

**Tests: 1317 → 1317, and that is the expected reading.** The run split suite files without adding
or removing a case. [`test-cases.md`](test-cases.md) shows the moves: `test_schema.lua` 55 → 42 with
13 in `test_schema_tabs.lua`, and `test_selector.lua` 58 → 39 with 14 in `test_selector_discovery.lua`
and `test_selector_pins.lua` 9 → 14.

**Perf: `recompute` bytes/iter 29832.8 → 247384.1 is not new garbage, and the two figures are not
comparable.** Commit `3a6f47a` (FX-CM-PERF) changed `tests/perf.lua` to stop the collector across
each scenario, answering action 3 of the previous analysis. The previous figure was a residue with
collection running; this one is the first recorded figure of the actual allocation, so it is a new
baseline for this scenario. That commit changed no shipped code. The other four read the same
bytes/iter as the previous run: 6000.0, 6000.0, 6001.3 and 0.0 ([`perf.txt`](perf.txt)).
`failures` in [`perf.json`](perf.json) is empty. Timings are not compared across runs
([`perf.txt`](perf.txt) says so itself).

**Complexity: the code moved, its density did not.** NLOC 30106 → 30188, functions 3541 → 3541, avg
CCN stays 2.5, avg NLOC stays 7.9, and avg tokens stays 65.4. The small NLOC rise with an unchanged
function count fits whole blocks moving between files. Max CCN stays 15: `BB.ApplyCountFont`
(`modules/MacroBarButton.lua`) and `splitArgs` (`tests/test_skin_surfaces.lua`), both at the ceiling
and neither warned ([`complexity.txt`](complexity.txt)). The band falls 7 → 3: `settings/MacroBar.lua`,
`settings/Panel.lua`, `tests/test_schema.lua` and `tests/test_selector.lua` left it, which also
retires the acceptance count three of those carried. `settings/Category.lua` was peeled too and
remains in the band.

## Complexity watch list

### Functions the complexity tool warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1034 | Peeled under #43, stays on notice. Accepted — page breadth, not tangle; re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1151 | Accepted — case count, not tangle; re-check at 1300. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | Accepted — fake breadth, not tangle; re-check at 1300. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`. No file newly crossed, so no cell was
blank and none was edited. This is not a release run, so no acceptance count advanced.

## Actions

1. GitHub issues #42 (`settings/Panel.lua`) and #43 (`settings/Category.lua`) are still open though
   their peels landed on this branch. Close them when the branch merges.
2. `docs/automated-tests/RESULTS.md`: the `recompute` bytes/iter of this run is the baseline for that
   scenario. Compare later runs with this figure, never with the rows before it.
