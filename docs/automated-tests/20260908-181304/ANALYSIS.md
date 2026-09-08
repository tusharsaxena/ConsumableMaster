# Analysis — 20260908-181304

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** 48a31f5 (`feat/2026-09-07-audit-review-remediation`), clean
- **Previous run:** [`20260825-103407`](../20260825-103407/)

## Headline

All four suites pass. Lint 0/0 over 102 files, 786 cases with none failed and none skipped, five perf
scenarios, and `lizard` warns on nothing at max CCN 15 across 1957 functions.

Two things in this run are worth more than the verdict. The first is the record itself: this is the
first bundle written by test-kit revision 15, and the first whose `RESULTS.md` came out of the runner
end to end rather than being typed. The second is the perf suite, which gained a scenario and lost
half its allocation on the one that matters — `recompute` fell 6007.5 → 2945.3 bytes/iter, and the
new `refreshBurst` scenario allocates nothing at all.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260825-103407` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 102 files | [`lint.txt`](lint.txt) | 58 → 102 files; 0/0 unchanged |
| tests | pass | 786 passed, 0 skipped, 0 failed, 786 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 698 → 786 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 4 → 5 scenarios; `recompute` allocation halved |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | Totals up; averages flat; band 0 → 2, over-cap 1 → 2 |

**Complexity in full.**

| Metric | `20260825-103407` | This run |
|---|---|---|
| Total NLOC | 15870 | 18825 |
| Functions | 1703 | 1957 |
| Avg NLOC / function | 8.0 | 8.1 |
| Avg CCN | 2.7 | 2.7 |
| Max CCN | 15 | 15 |
| Avg tokens / function | 63.6 | 63.8 |
| Warnings (CCN > 15) | 0 | 0 |
| Files 1000–1500 | 0 | 2 |
| Files over 1500 | 1 | 2 |

Totals rose 19% and 15%; average NLOC per function moved 8.0 → 8.1, average CCN not at all, average
tokens 63.6 → 63.8. Growth without densification.

No suite was skipped: `lua 5.1.5`, `luacheck 1.2.0` and `lizard 1.24.0` all ran
([`manifest.json`](manifest.json), `host`).

## What moved

- **lint** — 58 → 102 files at 0/0, most of it `M4-11` bringing the test tree into lint scope.
- **tests** — 698 → 786. `docs/test-cases.md` and the README badge already read 786; the bundle's
  [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md` at HEAD, so no count
  claim moves in this commit.
- **perf** — 4 → 5 scenarios. `refreshBurst` is new and allocates **0 bytes/iter**, which is the
  point of the scenario: `M4-22` replaced a refresh that armed a hundred and fifty timers, and a
  scenario that allocates nothing is the shape of the fix rather than a description of it.
  `recompute` fell 6007.5 → 2945.3 bytes/iter, slightly more than halved. `cooldownRefresh`,
  `probeOverheadOff` and `probeOverheadOn` are unchanged at 6000.0 / 6000.0 / 6001.3, and the
  zero-overhead pair still sits within noise of each other, which is what `performance-§2` wants.
  Every `ms/iter` rose by roughly a quarter; timings are for orientation only and are not comparable
  across runs (`performance-§9`), so the allocation column is the one to read here.
- **complexity** — nothing warned. Four functions sit at exactly CCN 15 with no headroom:
  `Helpers.BuildAboutContent` (`settings/Panel.lua@818-879`), `D.RunMigrations`
  (`core/Database.lua@115-162`), `S.SweepStaleDiscovered` (`modules/Selector.lua@545-571`) and
  `applyBackdrop` (`modules/MacroBar.lua@217-244`).
- **Band, and this is the substantive movement** — from one file to four. `settings/Category.lua`
  (1127) and `settings/Panel.lua` (1165) entered the on-notice band, and `tests/test_settingsui.lua`
  went over the 1500 cap at 1669. All three were well clear at the previous run's commit — 729, 920
  and 656 respectively — so all of this is this cycle's own growth. `tests/test_macrobar.lua` moved
  1688 → 1904.

## On the two over-cap files

Both breaches are test suites and both are tracked, which is one of the three terminal states
`layout-§1` has allowed since its 2026-09-08 revision: peeled, an open issue naming the seam, or a
ratified deviation row with a re-check trigger. `tests/test_macrobar.lua` is issue **#32** and
`tests/test_settingsui.lua` is issue **#33**, each naming the cut a peel would follow. **No source
file here is over the cap** — the largest are the two that just entered the band — which is why both
get an issue rather than a register row.

The census that carries every breach in the repository, rather than only the ones this table
happened to measure, is `docs/ARCHITECTURE.md` § *Files over the 1500-line cap*, and
`tests/test_layout_cap.lua` holds it to the tracked set on every run: a file that crosses and is not
listed turns the suite red, and so does a row for a file that has fallen back under. That gate is
green here, which is how `tests/test_settingsui.lua`'s crossing was already accounted for before this
run measured it. Its figures in that table are dated measurements and say so; the live ones are in
this bundle. No peel lands this cycle — `03_SPEC.md` § C22 rules one out.

## The `ANALYSIS.md` gap, noted once

Three of eight bundles here carry no `ANALYSIS.md`: `20260807-110619`, `20260825-103407`, and until
this file, this one. The first two are not getting one. An analysis written today into a folder
stamped in August would date a reading to a day nobody took it, which is worse than a gap, because a
gap is legible. Fixed forward. Collection-wide the same gap stands at 37 of 95 bundles.

## Actions

None in this bundle. Two open issues (#32, #33) already carry the two cap breaches, and no
disposition is due for conversion — every manifest here carries `"release": null`, so the
three-consecutive-release-runs clock has not started.
