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

**796 cases** — 796 passed, 0 failed, 0 skipped. The generated inventory
[`20260911-220327/test-cases.md`](20260911-220327/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **792 → 796** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 102 files** (`luacheck .`).

`.luacheckrc` sets a multi-line `exclude_files`; read it there for the scope of the figure above.
A `0/0` says nothing about what was never looked at.

## Perf

**5 scenarios** from `tests/perf.lua`; the measurements are in
[`20260911-220327/perf.json`](20260911-220327/perf.json).

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260911-220327`](20260911-220327/) — **this run's measurement, not its diff.** Max CCN **15** across 1977
functions, **0** of them warned on; 2 file(s) in the 1000–1500 band and 2 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1143 | **Accepted, and it is now the largest source file here.** Newly in the band and the crossing is dated: 729 lines at the previous run's commit, 987 when eighteen sidebar entries became four, over the line at 1084 with the tabbed General page, 1127 today. Still 373 under `layout-§1`'s cap and no function in it is warned on. The seam if it needs one is the drag-reorder block, which is self-contained. Re-check at 1300, or the moment a third tab arrives. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1165 | **Accepted.** Newly in the band: 920 at the previous run's commit, over the line at 1014 with the tabbed General page, 1165 after `M4-22`'s refresh-burst fix and `M3-04`'s v1.26.0 adoption. It holds this addon's highest-CCN function, `Helpers.BuildAboutContent` at exactly 15, so both numbers on this file are worth watching together rather than separately. Re-check at 1300. |
| > 1500 (over cap) | `tests/test_macrobar.lua` | 2011 | **Owned: issue [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32), naming the two cuts a peel would follow.** It crossed at [`20260807-022923`](20260807-022923/) and four bundles have now recorded it. 1314 NLOC across 178 functions at avg CCN 1.3, so it is case count and not tangle. The claim above this cell used to be that `layout-§1` treats over-cap as a defect rather than a state a disposition can hold; that reading is no longer right — the section was revised on 2026-09-08 to give a breach three terminal states, an open issue among them. The census that carries every breach in this repo, not just the one this table happens to have measured, is `docs/ARCHITECTURE.md` § *Files over the 1500-line cap*, and `tests/test_layout_cap.lua` holds it to the tracked set on every run. |
| > 1500 (over cap) | `tests/test_settingsui.lua` | 1675 | **Owned: issue [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33), naming the cut** — the three `options-ui` conformance blocks out to `test_settingsui_optionsui.lua`. In breach, and a breach with an open issue naming its seam is one of the three terminal states `layout-§1` allows since its 2026-09-08 revision. It crossed the cap during this cycle: 656 at the previous run's commit, 1528 by `M4-06`, 1669 after `M4-22`. The census that carries every breach in this repo — not just the ones this table measured — is `docs/ARCHITECTURE.md` § *Files over the 1500-line cap*, and `tests/test_layout_cap.lua` holds it to the tracked set on every run. No peel lands this cycle; `03_SPEC.md` § C22 rules one out. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

