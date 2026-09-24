# Analysis — 20260924-120622

- **Addon:** ConsumableMaster 1.6.2
- **Verdict:** green
- **Commit:** f8729fa96e12016ad77e5adba4c4dd2766570542 (feat/2026-09-23-review-audit-remediation)
- **Previous run:** [`20260916-184427`](../20260916-184427/), the row below this one in `RESULTS.md`

## Headline

All four suites ran and passed on a clean tree: lint 0/0 over 119 files, 1071 cases green with
nothing skipped, five perf scenarios, and no function warned on. This is the first run on the
2026-09-23 remediation branch with LibKa0s v1.56.0 (kit revision 26) vendored. It lands 73 commits
after the previous bundle, which measured `da0b0f8`. Max CCN fell from **15 to 14**, so none of the
eight functions that sat on the ceiling last time is still there. Nothing is over the 1500-line cap.
The two settings pages whose acceptance had run out now carry filed peels (#42, #43) in the Disposition cells.
This is not a release run (`manifest.json` `release: null`): no version moved and nothing is tagged.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260916-184427` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 119 files | [`lint.txt`](lint.txt) | files 114 → **119** (+5); warnings and errors both still 0 |
| tests | pass | 1071 passed, 0 skipped, 0 failed, 1071 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 928 → **1071** (+143); skipped still 0 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` bytes/iter +2.9%, the other four byte-identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → **0**; max CCN 15 → **14**; over-cap files 0 → 0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from `manifest.json`'s `suites.complexity`, which records `lizard`'s own
footer in [`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 24468 |
| Functions | 2685 |
| Avg NLOC / function | 7.8 |
| Avg CCN | 2.5 |
| Max CCN | 14 |
| Avg tokens / function | 62.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly, so there is no skip to explain and no regression to read in any suite's
output. Every tool was present: `manifest.json`'s `host` block records Lua 5.1.5, Luacheck 1.2.0 and
`lizard` 1.24.0.

## What moved

**Lint: 114 → 119 files, still 0/0.** The file lists in the two bundles' `complexity.txt` show seven
authored files entering scope and two leaving. In: `core/LifecycleSetup.lua`,
`settings/CategoryAddByID.lua`, `settings/OptionsShim.lua`, `settings/SchemaStub.lua`,
`tests/test_disabled.lua`, `tests/test_schema_adoption.lua` and `tests/test_slash_degraded.lua`.
Out: the repo's own `tests/test_layout_cap.lua` and `tests/test_prose.lua`, which were replaced by
the kit's copies under `tests/_kit/`. That directory is excluded, as the *Lint* section of `RESULTS.md`
names. The scope did not change; the exclusions are the same four paths.

**Tests: 928 → 1071, +143.** Two things account for it. The pre-remediation cycle added the
stand-down latch and `/cm unlock`. The 2026-09-23 remediation then added cases for the Schema-1.0
write seam (`tests/test_schema_adoption.lua`), the degraded slash dispatcher
(`tests/test_slash_degraded.lua`), the disabled state (`tests/test_disabled.lua`), the one reset
act, SafeRegisterEvent's rejected list and `/cm dump events`, among others.
[`test-cases.md`](test-cases.md) is the authority on which cases exist, and it matches
`docs/test-cases.md` at this commit.

**Perf: `recompute` moved slightly and the rest held.** Reading [`perf.json`](perf.json) against
[the previous one](../20260916-184427/perf.json), bytes per iteration at the same 200 iterations:
`recompute` **6323.88 → 6505.88** (+182, +2.9%). The other four are byte-identical to the previous
run: `cooldownRefresh` 6000, `probeOverheadOff` 6000, `probeOverheadOn` 6001.32, `refreshBurst` 0.
So the zero-overhead pair, `performance-§9`'s evidence, did not move. The `recompute` rise is small
and stays inside the range this scenario has occupied since the rise and partial reversal two runs
back. It is noted rather than flagged. Wall time (224.025 → 226.763 ms total) is only for
orientation and is not read as a signal.

**Complexity: the addon grew and got less dense.** NLOC 22707 → 24468 and functions 2396 → 2685,
while avg NLOC per function fell 8.0 → 7.8, avg CCN 2.6 → 2.5 and avg tokens 63.7 → 62.9. The
ceiling came down: the previous analysis listed eight functions at exactly 15. In this run's
`complexity.txt` none of them is above 10. `D.RunMigrations` reads 5, `itemCooldown` 8,
`applyBackdrop` 8, `S.PickBestForSlot` 9, `availableForHands` 9, `S.SweepStaleDiscovered` 10,
`Helpers.BuildAboutContent` 1 and `M.setItem` 9. `KCM:OnRegenEnabled`, which the 2026-09-23 review
measured at 15, is the `KCM@640-667` entry at **12**. The new maximum, 14, is shared by eleven
functions, and three of them are in `settings/Category.lua`, including `renderCompositeSection`,
which the #43 peel moves.

**Band: 8 → 8 files, with the settings pages much smaller.** `settings/Panel.lua` 1488 → 1166 and
`settings/Category.lua` 1400 → 1142. Two suites grew past the re-check lines their last dispositions
set: `tests/test_slash.lua` 1249 → 1425 (re-check was 1350) and `tests/test_settingsui.lua`
1255 → 1419 (re-check was 1400). Both are re-ruled below.

**The record itself.** `RESULTS.md` widened once, adding the runner's new **Commit** and **Tree**
columns, and the thirteen earlier rows read `unknown` in both, as the kit prescribes. This run's row
is `f8729fa`, clean. It replaces a record that `ConsumableMaster-A-17` found stale: 928 cases,
eight functions at CCN 15 and the pre-peel line counts for both settings pages.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. No function is above CCN 15. The generated table in `RESULTS.md` prints its header with no
rows and no "None." line. That is the runner's output, left as generated.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1425 | Accepted on notice, case count not tangle (1074 NLOC, 135 functions, avg CCN 1.3); re-check at 1475 |
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1425 | Accepted on notice, case count not tangle (1022 NLOC, 127 functions, avg CCN 1.3); re-check at 1475 |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1419 | Accepted on notice, case count not tangle (899 NLOC, 104 functions, avg CCN 1.7); re-check at 1475 |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1169 | Accepted, page breadth (798 NLOC, 42 functions, avg CCN 3.1); re-check at 1300 |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1166 | Peel tracked as [#42](https://github.com/tusharsaxena/ConsumableMaster/issues/42) (About renderer → `settings/About.lua`) |
| 1000–1500 (on notice) | `settings/Category.lua` | 1142 | Peel tracked as [#43](https://github.com/tusharsaxena/ConsumableMaster/issues/43) (composite editor → `settings/CategoryComposite.lua`) |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | Accepted, case count (743 NLOC, 70 functions, avg CCN 2.1); re-check at 1300 |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1009 | Accepted, case count (711 NLOC, 66 functions, avg CCN 1.4); re-check at 1300 |

`settings/Panel.lua` and `settings/Category.lua` had been carried as accepted across three
release runs (1.6.0, 1.6.1, 1.6.2). `automated-tests-§4` allows no more than that, so their cells
now name a tracked peel rather than a fourth acceptance. The issues were filed by CM-30, and
`docs/ARCHITECTURE.md`'s band paragraph cites them too.

## Actions

1. `settings/Panel.lua`: peel the About page renderer into `settings/About.lua`
   ([#42](https://github.com/tusharsaxena/ConsumableMaster/issues/42), `state:triaged`).
2. `settings/Category.lua`: peel the composite (AIO) section editor into
   `settings/CategoryComposite.lua` ([#43](https://github.com/tusharsaxena/ConsumableMaster/issues/43),
   `state:triaged`). This also takes one of the eleven CCN-14 functions out of the file.
3. `tests/test_slash.lua` and `tests/test_macrobar.lua` (1425 each) and `tests/test_settingsui.lua`
   (1419) are within 81 lines of the cap. The next suite growth in any of them needs a cut along the
   seam its disposition names, not another re-check line. This is new here: no issue tracks it yet.
4. The tag gate is zero functions above 15, and eleven functions sit at 14. A change that adds two
   `and`/`or` decisions to any of them fails a release run. This is noted for the release, not
   owed now.
