# Analysis — 20260916-184427

- **Addon:** ConsumableMaster 1.6.2
- **Verdict:** green
- **Commit:** da0b0f8823d8977724291c3aaf2eba9fac0bd7f3 (master), clean
- **Previous run:** [`20260916-094429`](../20260916-094429/) — the row above this one in `RESULTS.md`

## Headline

All four suites ran and all four passed: lint 0/0 over 114 files, 928 cases green with nothing
skipped, five perf scenarios, and `lizard` warning on nothing. The run that matters here is the
first one taken **after** the two over-cap peels landed, and it confirms them from the outside —
`overCapFiles` goes **2 → 0** in [`manifest.json`](manifest.json), so for the first time in this
table's history nothing in the repository breaches `layout-§1`'s 1500-line cap. Two things are
owed a decision rather than a reading: `settings/Category.lua` and `settings/Panel.lua` have now
been carried as *Accepted* across three consecutive release runs, which is the shelf life
`automated-tests-§4` sets, and no open issue tracks either.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260916-094429` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 114 files | [`lint.txt`](lint.txt) | files 108 → **114** (+6); warnings and errors both still 0 |
| tests | pass | 928 passed, 0 skipped, 0 failed, 928 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 901 → **928** (+27); skipped still 0 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 5; `recompute` allocation **down 45%** (see *What moved*) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings → **0**; over-cap files **2 → 0** |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is `manifest.json`'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 22707 |
| Functions | 2396 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.6 |
| Max CCN | 15 |
| Avg tokens / function | 63.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |

Every suite was a clean pass, so there is no skip to account for and no suite output that needs
reading as a regression. Nothing was left unmeasured: `manifest.json`'s `host` block records
Lua 5.1.5, Luacheck 1.2.0 and lizard 1.24.0, so all four tools were present.

## What moved

**Lint — 108 → 114 files, still 0/0.** The six are exactly the six files `lizard` sees for the
first time in [`complexity.txt`](complexity.txt): `core/LauncherSetup.lua`,
`tests/macrobar_support.lua`, `tests/test_launcher.lua`, `tests/test_macrobar_chrome.lua`,
`tests/test_macrobar_layout.lua` and `tests/test_settingsui_optionsui.lua`. That is new authored
source entering scope, not a scope change — `.luacheckrc`'s `exclude_files` is unchanged.

**Tests — 901 → 928, +27.** The cycle since the previous bundle adopted the LibKa0s launcher
(`2d7ab90`, `48e3fcf`) and added `/cm enable` and `/cm disable` (`d259f71`), and the new cases
follow those. The peels themselves moved cases rather than adding them, which is what the peel
commits claimed: `ec2d9c4` split the two over-cap suites and `93f3aff` renamed the chrome half.

**The chrome-file rename, which the task asked about.** `93f3aff` renamed
`tests/test_macrobar_button.lua` to `tests/test_macrobar_chrome.lua` because the singular sat one
character away from the pre-existing `tests/test_macrobar_buttons.lua` — the Macro Bar page's
Buttons tab, an unrelated subject. `da0b0f8`, this run's HEAD, is the follow-up: two header
comments in `tests/test_macrobar.lua` and `tests/test_macrobar_layout.lua` still carried the old
singular name. It is comment-only and touches two lines, so it moves no figure in this bundle;
its value is that the peeled suites now name the chrome file by the name it actually has.

**Perf — the previous run's flagged `recompute` allocation partly reversed.** Reading
[`perf.json`](perf.json) against [the previous one](../20260916-094429/perf.json), bytes per
iteration at the same 200 iterations: `recompute` **11439.96 → 6323.88**, a 45% fall. The
previous analysis called out a 3.9× rise on this scenario and said the byte column was the figure
to read; it has come most of the way back, though not to the 2947.8 of the run before that. The
other four are byte-identical across the two runs — `cooldownRefresh` 6000.00, `probeOverheadOff`
6000.00, `probeOverheadOn` 6001.32, `refreshBurst` 0.00 — so the zero-overhead pair
(`performance-§9`'s evidence) is unchanged. Wall time is for orientation only and never compares
across machines; `recompute`'s total went 194.564 → 224.025 ms and is not read here as a signal.

**Complexity — the addon grew and got no denser.** Total NLOC 22225 → 22707 (+482) and functions
2342 → 2396 (+54), which is growth. The averages did not follow it: avg NLOC/function stayed 8.0,
avg CCN stayed 2.6, avg tokens/function went 63.8 → **63.7**. Max CCN is 15 for the sixth
consecutive run and the warning count stayed 0. Growth without densification is the reading.

**Eight functions sit at exactly CCN 15 — the same eight as the previous run, unmoved.**
[`complexity.txt`](complexity.txt) puts `D.RunMigrations` (`core/Database.lua:115`),
`itemCooldown` (`core/MacroDisplay.lua:102`), `applyBackdrop` (`modules/MacroBar.lua:229`),
`S.PickBestForSlot`, `availableForHands` and `S.SweepStaleDiscovered` (`modules/Selector.lua`),
`Helpers.BuildAboutContent` (`settings/Panel.lua:1112`) and `M.setItem` (`tests/wow_mock.lua:200`)
all at 15 exactly. None of them warns, so none is on the watch list and none blocks anything
today. It is worth one line anyway: the **tag** gate is zero functions *above* CCN 15
(`automated-tests-§3`), so any one of these eight taking on one more `and`/`or` turns a green
release run amber-adjacent at the worst possible moment. This is a note, not an action.

**The band table went 6 → 8 rows while the cap breaches went 2 → 0.** Those are the same event,
not opposite ones: `tests/test_macrobar.lua` (2229 → 1456) and `tests/test_settingsui.lua`
(2028 → 1255) came *down* out of the over-cap band and landed in the on-notice band. The runner
has no way to know a row descended rather than crossed, so both arrive with a blank Disposition;
Step 3 of this run ruled on them, and `RESULTS.md` carries the ruling.

## Complexity watch list

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1400 | **Owed a decision — accepted across three consecutive release runs and the shelf life is up.** |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1166 | Accepted — page breadth, not tangle. Re-check at 1300. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1488 | **Owed a decision — accepted across three consecutive release runs and the shelf life is up.** |
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1456 | Descended from over-cap; accepted on notice. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1023 | Accepted: case count, not tangle. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1011 | Accepted: case count, not tangle. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_settingsui.lua` | 1255 | Descended from over-cap; accepted on notice. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1249 | Accepted: case count, not tangle. Re-check at 1300. |
| > 1500 (over cap) | — | — | None. Nothing in the repository is over the cap at this run. |

`RESULTS.md` carries each disposition in full; the table above is the summary. On reading the
numbers: `lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching. Every file in the
band above is **dense defaulting and guarding**, not tangled control flow — the two settings pages
sit at avg CCN 4.4 and 4.6 and the five suite files between 1.3 and 2.1, and not one of them holds
a warned function. That matters for what a fix would be: these want a **seam**, not a rewrite
(`performance-§11`).

## Actions

1. **Rule on `settings/Category.lua` (1400) and `settings/Panel.lua` (1488) — a peel, or a tracked
   deviation ID with an owner.** `automated-tests-§4` gives an *Accepted* disposition a shelf life
   of three consecutive release runs. Both files were carried as Accepted at 1.6.0 (`c856b35`),
   1.6.1 (`eb1829f`) and 1.6.2 (`1639fde`), which is the third, and a fourth acceptance is what the
   rule refuses. Checked against the repo's own issue store before writing this: **neither is
   tracked** — the two open cap issues, [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32)
   and [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33), were the suite peels and
   both are closed. So this is new here and has no owner. `Panel.lua` is the more urgent of the two:
   it grew 1426 → 1488 in this cycle alone and is now 12 lines under the cap.
2. **Nothing else.** No suite failed, no suite was skipped, no function warned, and no file is over
   the cap.
