# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260916-094429`](20260916-094429/) | 1.6.2 | 0/0 | 108 | 901/0/901 | pass | 22225 | 2342 | 8.0 | 2.6 | 15 | 0 | **green** |
| [`20260911-220327`](20260911-220327/) | 1.6.1 → 1.6.2 | 0/0 | 102 | 796/0/796 | pass | 18992 | 1977 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260911-211045`](20260911-211045/) | 1.6.0 → 1.6.1 | 0/0 | 102 | 792/0/792 | pass | 18912 | 1966 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260910-234511`](20260910-234511/) | 1.5.0 → 1.6.0 | 0/0 | 102 | 788/0/788 | pass | 18837 | 1960 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260908-181304`](20260908-181304/) | 1.5.0 | 0/0 | 102 | 786/0/786 | pass | 18825 | 1957 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260825-103407`](20260825-103407/) | 1.5.0 | 0/0 | 58 | 698/698 | pass | 15870 | 1703 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260807-114612`](20260807-114612/) | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260807-110619`](20260807-110619/) | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260807-022923`](20260807-022923/) | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-233147`](20260804-233147/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-215640`](20260804-215640/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 0 | 0 | **green** |
| [`20260804-182045`](20260804-182045/) | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

## Test suite

**901 cases** — 901 passed, 0 failed, 0 skipped. The generated inventory
[`20260916-094429/test-cases.md`](20260916-094429/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **796 → 901** since the previous run — **+105**, the largest single-run jump in this
table's recorded history, and it tracks a cycle in which the addon itself gained 3233 NLOC and
365 functions. The count is not stalling against a growing addon.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 108 files** (`luacheck .`).

Scope, because a `0/0` says nothing about what was never looked at: `.luacheckrc` excludes
`libs/`, `docs/audits/`, `docs/reviews/` and `tests/_kit/` — vendored code and frozen evidence
bundles, nothing authored and shipping. There is **no top-level `ignore`**: the file carried
`ignore = { "212", "542" }` until `M4c-03` and deliberately does not any more, so no diagnostic is
silenced repo-wide. The 102 → 108 file movement this run is new authored source entering scope,
not a scope change.

## Perf

**5 scenarios** from `tests/perf.lua`; the measurements are in
[`20260916-094429/perf.json`](20260916-094429/perf.json).

The five scenarios pin the recompute path, the cooldown refresh, the perf probe's own overhead
with the probe off and on (the pair is `performance-§9`'s zero-overhead evidence), and a refresh
burst. **`recompute` moved this run:** 2947.8 → 11440.0 bytes per iteration at the same 200
iterations, with wall time up only 8% (0.90213 → 0.97282 ms/iter). Timings here are for
orientation only and never compare across machines, but an allocation counted per iteration does,
so the byte figure is the one to read — a 3.9× rise usually means a new table or closure per pass.
The other four are flat inside this harness's resolution.

These are **offline** scenarios and are never a stand-in for an in-game capture; that lives under
`docs/perf-analysis/`. `perf` never fails a run and never blocks a commit — it is recorded, read
and compared, not thresholded (`performance-§9`). It does gate the **tag**
(`automated-tests-§3`).

## Complexity watch list

Current as of [`20260916-094429`](20260916-094429/) — **this run's measurement, not its diff.** Max CCN **15** across 2342
functions, **0** of them warned on; 6 file(s) in the 1000–1500 band and 2 over the 1500 cap
(`layout-§1`).

**Amended after the run, in the one cell that may be.** The two over-cap files were peeled on
2026-09-16, after this bundle was frozen (issues
[#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32) and
[#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33)). Only their **Disposition**
cells were rewritten — `automated-tests-§4` makes that the single authored cell in this file, and
leaves every other column the runner's own output. So the band and the LOC beside them still read
what `lizard` measured at this run's commit, 2229 and 2028, and the Disposition says what has
happened since. The rows are not deleted: a watch-list row that vanishes reads the same as one that
was never there. Nothing in this repository is over the cap now;
`docs/ARCHITECTURE.md` § *Files over the 1500-line cap* is the census that says so, and
`tests/test_layout_cap.lua` holds it to the tracked set on every run.

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1400 | **Accepted — but this is the third consecutive release run carrying it, and the shelf life is up.** 1143 → 1400 this cycle; 100 under `layout-§1`'s cap, 851 NLOC across 97 functions at avg CCN 4.4, no warned function. The seam if it needs one is still the self-contained drag-reorder block. Carried as Accepted at 1.6.0, 1.6.1 and 1.6.2, so `automated-tests-§4` now wants a peel or a tracked deviation ID with an owner rather than a fourth acceptance. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1166 | **Newly crossed at [`20260916-094429`](20260916-094429/) — accepted, re-check at 1300.** 763 lines at the previous run's commit, 1166 today: the macro-bar settings page grew with the feature. 801 NLOC across 42 functions at avg CCN 3.2 and no warned function, so this is page breadth rather than tangle. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1426 | **Accepted — but this is the third consecutive release run carrying it, and the shelf life is up.** 1165 → 1426 this cycle; now the largest file in the repo and 74 under the cap. 664 NLOC across 56 functions at avg CCN 4.7, and it holds this addon's joint-highest-CCN function, `Helpers.BuildAboutContent` at exactly 15 — dense content assembly rather than branching — so both numbers on this file are read together. Carried as Accepted at 1.6.0, 1.6.1 and 1.6.2; owed a peel or a tracked deviation ID rather than a fourth acceptance. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1012 | **Newly crossed at [`20260916-094429`](20260916-094429/) — accepted: case count, not tangle.** 788 → 1012 this cycle. 744 NLOC across 71 functions at avg CCN 2.1. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1011 | **Newly crossed at [`20260916-094429`](20260916-094429/) — accepted: case count, not tangle.** 829 → 1011 this cycle. 713 NLOC across 66 functions at avg CCN 1.4. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1052 | **Newly crossed at [`20260916-094429`](20260916-094429/) — accepted: case count, not tangle.** 831 → 1052 this cycle. 839 NLOC across 109 functions at avg CCN 1.3, the lowest density in the band. Re-check at 1300. |
| > 1500 (over cap) | `tests/test_macrobar.lua` | 2229 | **Peeled on 2026-09-16, after this run: now 1456 and no longer over the cap.** It had been in breach since [`20260807-022923`](20260807-022923/), carried across five bundles. Issue [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32) named two cuts and both landed: `tests/test_macrobar_layout.lua` (432) took the four pure-geometry sections, `tests/test_macrobar_chrome.lua` (380) took the chrome appliers plus the flyout's bind/apply pass, and `tests/macrobar_support.lua` holds the one fixture read on both sides of a seam. Every case moved whole — 137 macro-bar cases before, 137 after. Back on notice at 1456; the next run's own figures will say so. |
| > 1500 (over cap) | `tests/test_settingsui.lua` | 2028 | **Peeled on 2026-09-16, after this run: now 1255 and no longer over the cap.** It crossed unremarked during this cycle (656 at the previous run's commit, 1528 by `M4-06`). Issue [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33) named one cut and it landed: the three `options-ui` conformance blocks out to `tests/test_settingsui_optionsui.lua` (800). Every case moved whole — 54 settings-UI cases before, 54 after. Back on notice at 1255; the next run's own figures will say so. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

