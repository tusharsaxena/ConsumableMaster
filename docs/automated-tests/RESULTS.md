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
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20261031-202052`](20261031-202052/) | `c7658c6` | clean | 1.8.0 | 0/0 | 140 | 1316/1/1317 | pass | 30106 | 3541 | 7.9 | 2.5 | 15 | 0 | **green** |
| [`20261009-191755`](20261009-191755/) | `944e16b` | clean | 1.7.0 → 1.8.0 | 0/0 | 130 | 1215/1/1216 | pass | 27450 | 3222 | 7.9 | 2.5 | 14 | 0 | **green** |
| [`20260927-030419`](20260927-030419/) | `86660df` | clean | 1.6.2 → 1.7.0 | 0/0 | 126 | 1112/0/1112 | pass | 25689 | 2838 | 7.8 | 2.5 | 14 | 0 | **green** |
| [`20260926-193121`](20260926-193121/) | `76bdd69` | clean | 1.6.2 | 0/0 | 126 | 1112/0/1112 | pass | 25689 | 2838 | 7.8 | 2.5 | 14 | 0 | **green** |
| [`20260926-160431`](20260926-160431/) | `bc284a4` | clean | 1.6.2 | 0/0 | 122 | 1112/0/1112 | pass | 25645 | 2835 | 7.8 | 2.5 | 14 | 0 | **green** |
| [`20260924-120622`](20260924-120622/) | `f8729fa` | clean | 1.6.2 | 0/0 | 119 | 1071/0/1071 | pass | 24468 | 2685 | 7.8 | 2.5 | 14 | 0 | **green** |
| [`20260916-184427`](20260916-184427/) | unknown | unknown | 1.6.2 | 0/0 | 114 | 928/0/928 | pass | 22707 | 2396 | 8.0 | 2.6 | 15 | 0 | **green** |
| [`20260916-094429`](20260916-094429/) | unknown | unknown | 1.6.2 | 0/0 | 108 | 901/0/901 | pass | 22225 | 2342 | 8.0 | 2.6 | 15 | 0 | **green** |
| [`20260911-220327`](20260911-220327/) | unknown | unknown | 1.6.1 → 1.6.2 | 0/0 | 102 | 796/0/796 | pass | 18992 | 1977 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260911-211045`](20260911-211045/) | unknown | unknown | 1.6.0 → 1.6.1 | 0/0 | 102 | 792/0/792 | pass | 18912 | 1966 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260910-234511`](20260910-234511/) | unknown | unknown | 1.5.0 → 1.6.0 | 0/0 | 102 | 788/0/788 | pass | 18837 | 1960 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260908-181304`](20260908-181304/) | unknown | unknown | 1.5.0 | 0/0 | 102 | 786/0/786 | pass | 18825 | 1957 | 8.1 | 2.7 | 15 | 0 | **green** |
| [`20260825-103407`](20260825-103407/) | unknown | unknown | 1.5.0 | 0/0 | 58 | 698/698 | pass | 15870 | 1703 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260807-114612`](20260807-114612/) | unknown | unknown | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260807-110619`](20260807-110619/) | unknown | unknown | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260807-022923`](20260807-022923/) | unknown | unknown | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-233147`](20260804-233147/) | unknown | unknown | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-215640`](20260804-215640/) | unknown | unknown | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 0 | 0 | **green** |
| [`20260804-182045`](20260804-182045/) | unknown | unknown | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

## Test suite

**1317 cases** — 1316 passed, 0 failed, 1 skipped. The generated inventory
[`20261031-202052/test-cases.md`](20261031-202052/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **1216 → 1317** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 140 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 4 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**5 scenarios** from `tests/perf.lua`; the measurements are in
[`20261031-202052/perf.json`](20261031-202052/perf.json).

| `scenario` | `iters` | `ms/iter` | `total` | `ms` |
|---|---|---|---|---|
| `recompute` | 200 | 1.38616 | 277.232 | 29832.8 |
| `cooldownRefresh` | 200 | 0.02249 | 4.498 | 6000.0 |
| `probeOverheadOff` | 200 | 0.02935 | 5.869 | 6000.0 |
| `probeOverheadOn` | 200 | 0.02125 | 4.249 | 6001.3 |
| `refreshBurst` | 200 | 0.01912 | 3.823 | 0.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261031-202052`](20261031-202052/) — **this run's measurement, not its diff.** Max CCN **15** across 3541
functions, **0** of them warned on; 7 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1186 | **Peeled 2026-10-31 ([#43](https://github.com/tusharsaxena/ConsumableMaster/issues/43)): 1186 → 1034.** The composite section editor moved whole to `settings/CategoryComposite.lua`, the seam the issue named. Its under-1000 estimate predated the file's growth, so it stays on notice by 34 lines; the shelf life this row spent is answered by that peel. Accepted — page breadth, not tangle; re-check at 1300. Next seam, if it has to leave: the reset popup block. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1231 | **Peeled 2026-10-31: 1231 → 845, leaves the band at the next run.** The Buttons tab's list moved whole to `settings/MacroBarSlots.lua`, answering the fix the next release run owed. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1143 | **Peeled 2026-10-31 ([#42](https://github.com/tusharsaxena/ConsumableMaster/issues/42)): 1143 → 929, leaves the band at the next run.** The About page moved whole to `settings/About.lua`, and the row rules, the follow-on seam the issue named, to `settings/PanelRows.lua`. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1176 | **Split 2026-10-31: 1176 → 768, leaves the band at the next run.** The tab and layout cases moved whole to `tests/test_schema_tabs.lua`, answering the fix the next release run owed. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1049 | **Split 2026-10-31: 1049 → 835, leaves the band at the next run.** Discovery moved whole to `tests/test_selector_discovery.lua`, and the pin merge cases to `tests/test_selector_pins.lua`, answering the fix the next release run owed. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1151 | **Newly crossed at [`20261009-191755`](20261009-191755/): accepted — case count, not tangle; re-check at 1300.** 972 at the 1.7.0 tag → 1002, then 1151 at [`20261031-202052`](20261031-202052/). 570 NLOC across 68 functions at avg CCN 1.9. A suite file just past the line; the 1.8.0 release run is acceptance 1 of 3. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1012 | **Newly crossed at [`20261009-191755`](20261009-191755/): accepted — fake breadth, not tangle; re-check at 1300.** 990 at the 1.7.0 tag → 1012, all 22 added lines being the AceDB `GetProfiles` fake that `/cm profile` needs. 605 NLOC across 134 functions at avg CCN 2.2; one small stub per API. The 1.8.0 release run is acceptance 1 of 3. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

