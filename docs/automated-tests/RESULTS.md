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

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
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

**1112 cases** — 1112 passed, 0 failed, 0 skipped. The generated inventory
[`20260926-193121/test-cases.md`](20260926-193121/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Unchanged from the previous run at 1112 cases.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 126 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 4 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**5 scenarios** from `tests/perf.lua`; the measurements are in
[`20260926-193121/perf.json`](20260926-193121/perf.json).

| `scenario` | `iters` | `ms/iter` | `total` | `ms` |
|---|---|---|---|---|
| `recompute` | 200 | 0.89579 | 179.157 | 13407.6 |
| `cooldownRefresh` | 200 | 0.02721 | 5.442 | 6000.0 |
| `probeOverheadOff` | 200 | 0.01828 | 3.656 | 6000.0 |
| `probeOverheadOn` | 200 | 0.01882 | 3.765 | 6001.3 |
| `refreshBurst` | 200 | 0.01677 | 3.353 | 0.0 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260926-193121`](20260926-193121/) — **this run's measurement, not its diff.** Max CCN **14** across 2838
functions, **0** of them warned on; 5 file(s) in the 1000–1500 band and 0 over the 1500 cap
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
| 1000–1500 (on notice) | `settings/Category.lua` | 1142 | **Peel tracked as [#43](https://github.com/tusharsaxena/ConsumableMaster/issues/43)** — the composite (AIO) section editor (`renderComposite`, `renderCompositeSection`, `renderCompositeRow`, `renderCompositeLegend`) out to `settings/CategoryComposite.lua`, mirroring the `settings/CategoryAddByID.lua` peel. 1142, unchanged since [`20260926-160431`](20260926-160431/) (it came down from 1400 at [`20260924-120622`](20260924-120622/), almost all of it the Add-by-ID peel in `bfd48b2`); 673 NLOC across 66 functions at avg CCN 5.1, no warned function; `renderCompositeSection` (CCN 14) is one of the eleven functions at this run's max of 14 and leaves with the peel. Three release runs of acceptance (1.6.0, 1.6.1, 1.6.2) were the `automated-tests-§4` limit, so this cell is the tracked issue, not a renewal. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1169 | **Accepted — page breadth, not tangle; re-check at 1300.** 1169, unchanged since [`20260926-160431`](20260926-160431/). 798 NLOC across 42 functions at avg CCN 3.1, no warned function. First carried at [`20260916-094429`](20260916-094429/); no release run has carried it yet, so this is its first acceptance toward the three-release limit. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1166 | **Peel tracked as [#42](https://github.com/tusharsaxena/ConsumableMaster/issues/42)** — the About page renderer (`readAddOnNotes`, `aboutLogo`, `aboutNotes`, `aboutSlashCommands`, `Helpers.BuildAboutContent`) out to `settings/About.lua`; the issue names the row-rule block as the follow-on seam. 1166, unchanged since [`20260926-160431`](20260926-160431/) (it came down from 1488 at [`20260924-120622`](20260924-120622/): the `bfd48b2` peel, the Schema-1.0 write seam (`01a5c94`) and the CreateOptionsPanel hand-off (`da5fc69`)); 499 NLOC across 54 functions at avg CCN 3.4, no warned function; `Helpers.BuildAboutContent` reads CCN 1. Three release runs of acceptance (1.6.0, 1.6.1, 1.6.2) were the `automated-tests-§4` limit, so this cell is the tracked issue, not a renewal. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | **Accepted — case count, not tangle; re-check at 1300.** 1023, unchanged since [`20260926-160431`](20260926-160431/). 743 NLOC across 70 functions at avg CCN 2.1. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1009 | **Accepted — case count, not tangle; re-check at 1300.** 1009, unchanged since [`20260926-160431`](20260926-160431/). 711 NLOC across 66 functions at avg CCN 1.4. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

