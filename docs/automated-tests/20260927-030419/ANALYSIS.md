# Analysis — 20260927-030419

- **Addon:** ConsumableMaster 1.6.2 → 1.7.0 (release run, `manifest.json` `release: "1.7.0"`)
- **Verdict:** green
- **Commit:** 86660dfd0c4073cf92f3a7361325aac8187fa747 (master)
- **Previous run:** [`20260926-193121`](../20260926-193121/), the row below this one in `RESULTS.md`

## Headline

The 1.7.0 release run. All four suites ran and passed on a clean tree: lint 0/0 over 126 files, 1112
cases green with nothing skipped, five perf scenarios, and no function above CCN 15 (max 14). That
clears all five release gates. Nothing measurable moved since the previous bundle: the six commits
between them are that run's own record, documentation and three comment-only source edits. There is
nothing new to act on; the two file-band peels (#42, #43) stay open.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260926-193121` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 126 files | [`lint.txt`](lint.txt) | unchanged: 126 files, 0/0; the checked file list is identical |
| tests | pass | 1112 passed, 0 skipped, 0 failed, 1112 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1112 → 1112, unchanged; skipped still 0 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; bytes/iter identical in all five scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → 0; max CCN 14 → 14; band files 5 → 5; over-cap 0 → 0 |

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

**Release gate** (evaluated by `/wow-addon:bump-version` from `manifest.json`): lint pass (0/0),
tests pass (0 failed of 1112), perf pass (5 scenarios, measured, not the no-`tests/perf.lua`
exception), complexity pass, count of functions above CCN 15 is 0. All five hold.

## What moved

**Lint: nothing.** 126 files, 0 warnings, 0 errors, and the `Checking` lines of both bundles'
`lint.txt` list the same files.

**Tests: 1112 → 1112, unchanged.** No test file changed between `76bdd69` and `86660df`.
[`test-cases.md`](test-cases.md) is identical to `docs/test-cases.md` at this commit. `RESULTS.md`
now notes the count has been flat at 1112 across the last three runs; that is expected, because
those runs span a peel of suite files and documentation work, not new behaviour.

**Perf: bytes/iter identical in all five scenarios** (`recompute` 13407.6, `cooldownRefresh` 6000.0,
`probeOverheadOff` 6000.0, `probeOverheadOn` 6001.3, `refreshBurst` 0.0; [`perf.json`](perf.json)).
The timings rose (`recompute` 0.8958 → 1.1108 ms/iter) but they are host noise and are not compared
across runs ([`perf.txt`](perf.txt) says so itself). No code on the recompute path changed.

**Complexity: every figure unchanged.** NLOC 25689, 2838 functions, averages 7.8 NLOC / 2.5 CCN /
62.8 tokens, max CCN 14, 0 warnings. The only `.lua` edits in the range are comments
(`modules/MacroManager.lua`, `settings/OptionsSetup.lua`, `settings/Panel.lua`, one line each), which
the complexity tool does not count. The five band files keep their LOC.

## Complexity watch list

### Functions the complexity tool warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. A release run that passed the gate has none by construction.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1142 | Peel tracked as #43 (composite section editor out to `settings/CategoryComposite.lua`); unchanged. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1169 | Accepted — page breadth, not tangle; re-check at 1300. Unchanged. 1.7.0 is the first release run to carry it (1 of 3). |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1166 | Peel tracked as #42 (About page renderer out to `settings/About.lua`); unchanged. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | Accepted — case count, not tangle; re-check at 1300. Unchanged. 1.7.0 is the first release run to carry it (1 of 3). |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1009 | Accepted — case count, not tangle; re-check at 1300. Unchanged. 1.7.0 is the first release run to carry it (1 of 3). |

Nothing newly crossed. The dispositions of record are the cells in `RESULTS.md`; this run recorded
the release count on the three accepted rows and kept every ruling.

## Actions

1. `settings/Panel.lua` and `settings/Category.lua`: the #42 and #43 peels are still open, carried
   from the previous analysis.
2. `settings/MacroBar.lua`, `tests/test_schema.lua` and `tests/test_selector.lua` are accepted for the
   first time at a release. Two more release runs of acceptance reach the `automated-tests-§4` limit,
   after which each needs a fix or a tracked issue.
