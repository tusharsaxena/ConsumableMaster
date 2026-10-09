# Analysis — 20261009-191755

- **Addon:** ConsumableMaster 1.7.0 → 1.8.0 (release run, `manifest.json` `release: "1.8.0"`)
- **Verdict:** green
- **Commit:** 944e16b06c342acaa1daf4b71a8f9b4f45088bd8 (master)
- **Previous run:** [`20260927-030419`](../20260927-030419/), the 1.7.0 release run and the row below this one in `RESULTS.md`

## Headline

The 1.8.0 release run. All four suites ran and passed on a clean tree: lint 0/0 over 130 files,
1215 of 1216 cases passed with one declared skip and none failed, five perf scenarios, and no
function above CCN 15 (max 14) with `blindFiles` 0. All six release gates hold. The 74 commits since
1.7.0 grew the suite by 104 cases and the measured code by 1761 NLOC at an unchanged average CCN of
2.5. Two suite files newly crossed into the 1000–1500 band, and three accepted band files reach
acceptance 2 of 3.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260927-030419` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 130 files | [`lint.txt`](lint.txt) | 126 → 130 files (four new suite files); 0/0 unchanged |
| tests | pass | 1215 passed, 1 skipped, 0 failed, 1216 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1112 → 1216 total; skipped 0 → 1 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` bytes/iter 13407.6 → 13741.2, the other four identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 14 → 14; band files 5 → 7; over-cap 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records the footer of
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 27450 |
| Functions | 3222 |
| Avg NLOC / function | 7.9 |
| Avg CCN | 2.5 |
| Max CCN | 14 |
| Avg tokens / function | 65.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

This is the first release run with a `blindFiles` figure: the 1.7.0 manifest has no such field, so
its complexity figures were unsighted. Part of the function-count growth (2838 → 3222) may be
functions the sighted suite now measures rather than new code. No function above CCN 15 appears
either way.

**The one skipped case** ([`tests.txt`](tests.txt), line 1205) is the kit's diagnostics-contract
branch for an addon that opts out of turning logging on. ConsumableMaster keeps the default
(`Kit.diagnostics.enablesLogging` is not false), so that branch does not apply, and the case beside
it covers the path this addon takes. It is a declared not-applicable skip, counted in neither passed
nor failed.

**Release gate** (evaluated by `/dev-copilot:bump-version` from `manifest.json`): lint pass (0/0),
tests pass (0 failed of 1216), perf pass (5 scenarios, measured, not the no-`tests/perf.lua`
exception), complexity pass, 0 functions above CCN 15, `blindFiles` 0. All six hold.

## What moved

**Lint: four more files, still 0/0.** The added files are `tests/test_debugcoverage.lua`,
`tests/test_librarylines.lua`, `tests/test_selector_pins.lua` and `tests/test_slash_profile.lua`
([`lint.txt`](lint.txt)).

**Tests: 1112 → 1216.** The four new suite files above account for part of it; the rest is cases
added to existing suites by the restriction-lift macro rewrite and the 2026-10-07 remediation items
(CM-01, CM-03 and CM-04 each landed red-first cases). `RESULTS.md` no longer reports the count as
flat. The one skip is described above.

**Perf: `recompute` allocates 333.6 more bytes per iteration** (13407.6 → 13741.2, about 2.5%;
[`perf.json`](perf.json)). The recompute path changed in this range: CM-01 added a live-body read to
the fingerprint check in `modules/MacroManager.lua`, and the restriction-lift work added stale
marking and debug lines. The other four scenarios are byte-identical. Timings are host noise and are
not compared across runs ([`perf.txt`](perf.txt) says so itself).

**Complexity: the addon grew, its density did not.** NLOC 25689 → 27450 and functions 2838 → 3222,
while avg CCN stays 2.5, avg NLOC moves 7.8 → 7.9 and avg tokens 62.8 → 65.2. Max CCN is 14 in both
runs. Thirteen functions sit at 14 against eleven before; the two additions are `M.FlushPending`
(`modules/MacroManager.lua`) and `moveBy` (`modules/Selector.lua`). Both are at the ceiling, not
over it.

## Complexity watch list

### Functions the complexity tool warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. A release run that passed the gate has none by construction.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1150 | Peel tracked as #43 (composite section editor out to `settings/CategoryComposite.lua`); 1142 → 1150. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1182 | Accepted — page breadth, not tangle; re-check at 1300. 1169 → 1182. Acceptance 2 of 3. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1196 | Peel tracked as #42 (About page renderer out to `settings/About.lua`); 1166 → 1196, the largest band move. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | Accepted — case count, not tangle; re-check at 1300. Unchanged. Acceptance 2 of 3. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1049 | Accepted — case count, not tangle; re-check at 1300. 1009 → 1049. Acceptance 2 of 3. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1002 | **Newly crossed.** Accepted — case count, not tangle; re-check at 1300. 972 → 1002. Acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | **Newly crossed.** Accepted — fake breadth, not tangle; re-check at 1300. 990 → 1012, all of it the AceDB `GetProfiles` fake. Acceptance 1 of 3. |

The dispositions of record are the cells in `RESULTS.md`; this run ruled on the two new entries and
moved the three accepted rows to their second release.

## Actions

1. `settings/Panel.lua` and `settings/Category.lua`: the #42 and #43 peels are still open. Panel
   gained 30 lines this release and is 304 lines under the cap.
2. `settings/MacroBar.lua`, `tests/test_schema.lua` and `tests/test_selector.lua` are at acceptance
   2 of 3. The next release run owes each a fix or a tracked issue (`automated-tests-§4`,
   anti-pattern #53). New here; no issue tracks them yet.
3. `tests/test_settingsui.lua` and `tests/wow_mock.lua` newly crossed and are accepted for the
   first time. New here.
