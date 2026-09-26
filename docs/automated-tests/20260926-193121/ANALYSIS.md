# Analysis — 20260926-193121

- **Addon:** ConsumableMaster 1.6.2
- **Verdict:** green
- **Commit:** 76bdd69d0e6ab5784b5d70f79b7f07bbe15102d3 (feat/2026-09-26-automated-tests-sweep)
- **Previous run:** [`20260926-160431`](../20260926-160431/), the row below this one in `RESULTS.md`

## Headline

All four suites ran and passed on a clean tree: lint 0/0 over 126 files, 1112 cases green with
nothing skipped, five perf scenarios, and no function warned on (max CCN 14). This is the closing run
of the 2026-09-26 automated-tests sweep, six commits after the previous bundle measured `bc284a4`:
the LibKa0s v1.62.0 re-vendor (kit revision 31) and the CM-ATS-02 peel of three suite files. The
figure that moved is the file band, **8 → 5**: `tests/test_slash.lua`, `tests/test_macrobar.lua` and
`tests/test_settingsui.lua` left it and nothing new entered. Not a release run (`manifest.json`
`release: null`).

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260926-160431` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 126 files | [`lint.txt`](lint.txt) | files 122 → **126** (+4); warnings and errors both still 0 |
| tests | pass | 1112 passed, 0 skipped, 0 failed, 1112 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1112 → 1112, unchanged; skipped still 0 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` bytes/iter 14740.12 → **13407.56** (−9.0%), the other four byte-identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 14 → 14; band files 8 → **5**; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the complexity
tool's own footer in [`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 25689 |
| Functions | 2838 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 14 |
| Avg tokens / function | 62.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 5 |
| Files over the 1500 cap | 0 |

Every suite passed, so there is no skip to explain and no failing output to read. Every tool was
present: `manifest.json`'s `host` block records Lua 5.1.5, Luacheck 1.2.0 and complexity tool 1.24.0.

## What moved

**Lint: 122 → 126 files, still 0/0.** The `Checking` lines of the two bundles' `lint.txt` differ by
four additions and no removals: `tests/test_macrobar_display.lua`, `tests/test_macrobar_flyout.lua`,
`tests/test_settingsui_category.lua` and `tests/test_slash_store.lua`, the four files CM-ATS-02
peeled out. The `.luacheckrc` exclusions are the same four paths named in `RESULTS.md`'s *Lint*
section.

**Tests: 1112 → 1112, unchanged, and that is expected.** CM-ATS-02 moved cases between files without
adding or removing any. [`test-cases.md`](test-cases.md) shows the moves under new file headings
(`test_macrobar.lua` 85 → 35, for example), and it is identical to `docs/test-cases.md` at this
commit.

**Perf: 5 scenarios, `recompute` 14740.12 → 13407.56 bytes/iter (−9.0%).** The other four scenarios
allocate exactly as before (`cooldownRefresh` 6000, `probeOverheadOff` 6000, `probeOverheadOn`
6001.32, `refreshBurst` 0; [`perf.json`](perf.json)). CM-ATS-01 (`dffb7fe`) bisected the previous
run's +126.6% rise to `b19e9bb` and recorded it as collector residue: the loop's per-pass allocation
is flat, and the figure follows the collector's phase as the live heap grows. This run's drop is
consistent with that reading. No source on the recompute path changed in this range; the LibKa0s
re-vendor did change the live heap. Timings (`recompute` max 0.8958 ms) are host noise and are not
compared.

**Complexity: NLOC 25645 → 25689 (+44), functions 2835 → 2838 (+3); every average unchanged** (7.8
NLOC, 2.5 CCN, 62.8 tokens), max CCN 14 → 14 and still 0 warnings. The small growth is the peeled
files' own headers and fixtures. The same eleven functions sit at CCN 14 in both runs. The band
dropped 8 → 5: `tests/test_slash.lua` 1426 → 940, `tests/test_macrobar.lua` 1425 → 712 and
`tests/test_settingsui.lua` 1419 → 972 lines (NLOC in [`complexity.txt`](complexity.txt): 741, 453
and 553). The five files still in the band did not change at all: identical LOC, NLOC, function
count and average CCN.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1142 | Peel tracked as #43 (composite section editor out to `settings/CategoryComposite.lua`); unchanged since the previous run. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1169 | Accepted — page breadth, not tangle; re-check at 1300. Unchanged. No release run has carried it yet. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1166 | Peel tracked as #42 (About page renderer out to `settings/About.lua`); unchanged. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | Accepted — case count, not tangle; re-check at 1300. Unchanged. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1009 | Accepted — case count, not tangle; re-check at 1300. Unchanged. |

Nothing newly crossed. The dispositions of record are the cells in `RESULTS.md`; this run refreshed
their figures to today's and kept every ruling.

## Actions

1. `settings/Panel.lua` and `settings/Category.lua`: the #42 and #43 peels are still open work,
   carried from the previous analysis.
2. Action 1 of the previous analysis (the `recompute` bisect) is closed by CM-ATS-01 (`dffb7fe`).
   Action 3 (the three suite files within 81 lines of the cap) is closed by CM-ATS-02 (`1717d98`).
