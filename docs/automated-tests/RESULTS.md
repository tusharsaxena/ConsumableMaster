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
| [`20260916-184427`](20260916-184427/) | 1.6.2 | 0/0 | 114 | 928/0/928 | pass | 22707 | 2396 | 8.0 | 2.6 | 15 | 0 | **green** |
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

**928 cases** — 928 passed, 0 failed, 0 skipped. The generated inventory
[`20260916-184427/test-cases.md`](20260916-184427/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **901 → 928** since the previous run — **+27**, on a cycle that adopted the LibKa0s launcher
and added the `/cm enable` and `/cm disable` verbs. The count has moved on every run since
[`20260804-215640`](20260804-215640/) and is not stalling against a growing addon: the addon gained
482 NLOC and 54 functions this cycle and the suite gained cases alongside it.

Six files entered scope this run, five of them suites: `tests/test_launcher.lua` for the new
launcher, `tests/test_macrobar_chrome.lua`, `tests/test_macrobar_layout.lua` and
`tests/macrobar_support.lua` from the `tests/test_macrobar.lua` peel, and
`tests/test_settingsui_optionsui.lua` from the `tests/test_settingsui.lua` peel. The peels moved
cases rather than adding them — the +27 is the launcher and the two verbs.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised. What the harness cannot reach stays in `docs/smoke-tests.md`: anything
that needs a live client — real frame layout, taint under combat lockdown, the minimap button as
the player sees it — is covered there and not here, and this row is silent about it by design.

## Lint

**0 warnings / 0 errors over 114 files** (`luacheck .`).

Scope, because a `0/0` says nothing about what was never looked at. `.luacheckrc` sets
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/_kit/" }` — vendored
third-party code, two frozen evidence stores, and the byte copy of the LibKa0s `testkit/`, which is
linted **there** as source. Nothing authored and shipping is excluded, and the rest of `tests/` is
in scope as this repo's own code.

There is **no top-level `ignore`**: the file carried `ignore = { "212", "542" }` until `M4c-03` and
deliberately does not any more, so no diagnostic is silenced repo-wide. What replaced it is a set
of `files[...]` stanzas each naming one file and one variable — `212/self` on the AceGUI widget
stubs, `212/ctx` on `modules/Ranker.lua`'s scorer dispatch table, `212/catKey` on
`modules/MacroManager.lua`, and so on — plus a single inline `-- luacheck: ignore 542`.
`tests/test_lintconfig.lua` is what keeps the blanket from coming back.

The 108 → 114 file movement this run is the six new authored files named under *Test suite* above
entering scope. It is not a scope change; `exclude_files` is byte-identical to the previous run's.

## Perf

**5 scenarios** from `tests/perf.lua`; the measurements are in
[`20260916-184427/perf.json`](20260916-184427/perf.json). This addon **does** ship perf scenarios,
so the run is not silent about runtime cost and no `performance-§12` exemption is in play.

What the five pin: `recompute` covers the full recompute path, `cooldownRefresh` the cooldown
refresh, `probeOverheadOff` and `probeOverheadOn` are the pair that measures the perf probe's own
cost with the probe off and on — that pair is `performance-§9`'s zero-overhead evidence and is the
reason the file exists — and `refreshBurst` pins the timer count a refresh burst arms.

Read the **bytes per iteration** column, not the timings: wall time never compares across machines,
but an allocation counted per iteration does. This run, at the same 200 iterations throughout:
`recompute` **11439.96 → 6323.88**, reversing most of the 3.9× rise the previous run flagged,
though not back to the 2947.8 of the run before it. The other four are byte-identical to the
previous run — `cooldownRefresh` 6000.00, `probeOverheadOff` 6000.00, `probeOverheadOn` 6001.32,
`refreshBurst` 0.00 — so the zero-overhead pair is unmoved.

These are **offline** scenarios and are never a stand-in for an in-game capture; that lives under
`docs/perf-analysis/`. `perf` never fails a run and never blocks a commit — it is recorded, read
and compared, not thresholded (`performance-§9`). It does gate the **tag**
(`automated-tests-§3`).

## Complexity watch list

Current as of [`20260916-184427`](20260916-184427/) — **this run's measurement, not its diff.** Max CCN **15** across 2396
functions, **0** of them warned on; 8 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

**Nothing in this repository is over the cap.** `overCapFiles` goes **2 → 0** against the previous
run, the first clean reading in this table's history, and the band table grew 6 → 8 rows because
those same two files came *down* into the on-notice band rather than because two more crossed up.
The peels landed in `ec2d9c4` and were finished by `93f3aff`, which renamed the chrome half away
from a name one character from an unrelated suite; `da0b0f8`, this run's commit, fixed the two
header comments the rename left behind. `docs/ARCHITECTURE.md` § *Files over the 1500-line cap* is
the census that says so, and `tests/test_layout_cap.lua` holds it on every run.

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None. No function is above CCN 15.

Worth one line the table cannot carry: **eight functions sit at exactly 15**, the same eight as the
previous run and none of them moved — `D.RunMigrations` (`core/Database.lua:115`), `itemCooldown`
(`core/MacroDisplay.lua:102`), `applyBackdrop` (`modules/MacroBar.lua:229`), `S.PickBestForSlot`,
`availableForHands` and `S.SweepStaleDiscovered` (`modules/Selector.lua`),
`Helpers.BuildAboutContent` (`settings/Panel.lua:1112`) and `M.setItem` (`tests/wow_mock.lua:200`).
None warns and none is owed a disposition. But the **tag** gate is zero functions *above* 15
(`automated-tests-§3`), so any one of these taking on a single further `and`/`or` breaks a release
run, and it would do it at the tag rather than here.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1400 | **Owed a decision — the shelf life is up.** Unchanged at 1400 this run; 100 under `layout-§1`'s cap, 851 NLOC across 97 functions at avg CCN 4.4, no warned function. The seam if it needs one is still the self-contained drag-reorder block. Carried as **Accepted** at 1.6.0 ([`c856b35`](https://github.com/tusharsaxena/ConsumableMaster/commit/c856b35)), 1.6.1 ([`eb1829f`](https://github.com/tusharsaxena/ConsumableMaster/commit/eb1829f)) and 1.6.2 ([`1639fde`](https://github.com/tusharsaxena/ConsumableMaster/commit/1639fde)) — three consecutive release runs, which is exactly what `automated-tests-§4` caps an acceptance at. A fourth is what the rule refuses, so this is owed a peel or a tracked deviation ID with an owner. Checked against the issue store at this run: no open issue covers it. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1166 | **Accepted — re-check at 1300.** Unchanged at 1166 this run (it crossed at [`20260916-094429`](20260916-094429/), 763 before that, when the macro-bar settings page grew with the feature). 801 NLOC across 42 functions at avg CCN 3.2 and no warned function, so this is page breadth rather than tangle. First release run carrying it will be the next tag. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1488 | **Owed a decision — the shelf life is up, and this is the tightest file in the repo.** 1426 → **1488** this run: the largest file here and **12 lines** under the cap, so the next page addition breaches it. 686 NLOC across 60 functions at avg CCN 4.6, and it holds one of the eight joint-highest-CCN functions, `Helpers.BuildAboutContent` at exactly 15 — dense content assembly rather than branching — so both numbers on this file are read together. Carried as **Accepted** at 1.6.0, 1.6.1 and 1.6.2, so `automated-tests-§4` wants a peel or a tracked deviation ID rather than a fourth acceptance, and the LOC headroom argues for the peel. No open issue covers it. |
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1456 | **Descended out of the over-cap band — accepted on notice, re-check at 1500.** Not a new crossing: it was **2229** and in breach at [`20260916-094429`](20260916-094429/) and had been since [`20260807-022923`](20260807-022923/). Issue [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32) named two cuts and both landed in `ec2d9c4` — `tests/test_macrobar_layout.lua` (341 NLOC) took the pure-geometry sections, `tests/test_macrobar_chrome.lua` (276 NLOC) took the chrome appliers and the flyout's bind/apply pass, and `tests/macrobar_support.lua` holds the one fixture read on both sides of the seam. 1047 NLOC across 136 functions at avg CCN 1.3: case count, not tangle. It lands only 44 under the cap, so the next macro-bar suite growth needs a third cut rather than an argument. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | **Accepted: case count, not tangle.** 1012 → 1023 this run. 746 NLOC across 71 functions at avg CCN 2.1. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1011 | **Accepted: case count, not tangle.** Unchanged at 1011 this run. 713 NLOC across 66 functions at avg CCN 1.4. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1255 | **Descended out of the over-cap band — accepted on notice, re-check at 1400.** Not a new crossing: it was **2028** and in breach at [`20260916-094429`](20260916-094429/), having crossed unremarked during the 1.6.2 cycle. Issue [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33) named one cut and it landed in `ec2d9c4`: the three `options-ui` conformance blocks out to `tests/test_settingsui_optionsui.lua` (485 NLOC). 780 NLOC across 89 functions at avg CCN 1.5. Comfortable headroom, unlike its macro-bar sibling. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1249 | **Accepted: case count, not tangle — but moving fastest in the band.** 1052 → **1249** this run, +197, on the cycle that added `/cm enable` and `/cm disable`. 963 NLOC across 122 functions at avg CCN 1.3, still the lowest density here. Re-check moved down to **1350** from 1300: at this rate it is two verbs from the cap. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`). Read that way, every row above
is **dense defaulting and guarding** — the two settings pages at avg CCN 4.4 and 4.6, the six suite
files between 1.3 and 2.1, and not one warned function among them. None of these files is tangled
control flow, which is why every disposition here reaches for a **seam** rather than a rewrite
(`performance-§11`).
