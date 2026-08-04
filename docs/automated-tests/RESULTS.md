# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-233147`](20260804-233147/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-215640`](20260804-215640/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 0 | 0 | **green** |
| [`20260804-182045`](20260804-182045/) | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

**The `Max CCN` of 0 on [`20260804-215640`](20260804-215640/) is an instrument fault, not a
measurement** — see [Complexity watch list](#complexity-watch-list) for what it should read.

## Test suite

656 cases, the count the newest run [`20260804-233147`](20260804-233147/) records. The
`feat/fix-ccn` branch added 51: 48 characterization tests written **before** the function they cover
was split, and three regression tests from the review round on that branch — the write path's debug
gate is a predicate and not a logging wrapper, the composite macro body is assembled line-for-line
in one table, and a flyout entry's border follows `buttonBorder` through the bar's own applier on
both sides. The three are **inside** the 51, not on top of it: the case inventory went 605 → 656,
51 added and none removed. The generated inventory `test-cases.md` in each bundle is the authority
on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 54 files: 0 warnings, 0 errors, unmoved across all three runs recorded here — the file
count has not moved either, so the green is over the same scope each time. What that scope is
matters more than the zeros, so it is spelled out: `.luacheckrc` sets `std = "lua51"` and excludes
exactly four paths — `libs/` (third-party, not this repo's to fix), `docs/audits/` and
`docs/reviews/` (frozen bundles, not code), and **`tests/`**, which runs under its own mock and
sets globals deliberately. The test harness is therefore **not** linted; it is covered by being
executed instead, 656 cases per run. Three warning codes are also suppressed globally —
`212` (unused arguments), `542` (intentional empty branch) and `241`, which is the `TooltipCache`
`pendingIDs` set that is populated and never read, carried as a follow-up rather than fixed.

## Perf

Zero scenarios. This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip`
rather than a transient tooling gap, and every bundle records it as one
(`"skipReason": "no tests/perf.lua — this addon ships no offline scenarios"`). A skip is not a pass:
two things follow, and both are standing facts rather than any one run's news — the record says
**nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence, that
bracketed instrumentation is free when capture is off, does not exist for it. Adding scenarios is
the only thing that changes either. The in-game side is empty too: the standing capture store
`docs/perf-runs/` does not exist in this repo yet, tracked as deviation **CM-43**. So neither half of
`performance-§8` has evidence here, and neither one would fill the other's gap — an offline scenario
and a live capture are different measurements.

## Complexity watch list

Current state as of [`20260804-233147`](20260804-233147/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

**About the `Max CCN` of 0 in the table.** Runs recorded before the LibKa0s v1.7.0 testkit (rev 6)
re-vendor derived that field from `lizard`'s `!!!! Warnings` block, which is empty the moment an
addon reaches zero warnings — so the runner printed 0 for a clean tree. Exactly one row here is
affected, [`20260804-215640`](20260804-215640/); its true maximum was 15, and the figure is in that
bundle's own [`complexity.txt`](20260804-215640/complexity.txt), which is byte-identical to the next
run's. The generated row is left as the tool wrote it: a hand-corrected record reads as measured and
is worse than a wrong one (`performance-§10`). Read the `62 → 0 → 15` shape that column shows
from the bottom up as one real drop followed by an instrument change, not two code changes.

### Functions `lizard` warned on

None.

`lizard` warned on nothing: `complexity.txt` ends with `No thresholds exceeded` and the footer's
`Warning cnt` is 0. This is the result the `feat/fix-ccn` branch exists for — the adoption baseline
[`20260804-182045`](20260804-182045/) listed twenty functions over CCN 15, topping out at 62, and
every one of them was split into named file-locals. Those dispositions are **not** carried forward.
An "Accepted" is a decision about a function that exists, and none of the twenty exists in its
warned form any more; re-listing them as resolved would turn an empty list into a changelog.

Seven functions now sit **at** the cap of 15, which is inside the gate — `lizard` warns above 15 and
`automated-tests-§3` gates on zero functions over it. Named rather than counted, so the claim cannot
go stale silently: `Helpers.BuildAboutContent` (`settings/Panel.lua`), `S.SweepStaleDiscovered`,
`availableForHands` and `S.PickBestForSlot` (`modules/Selector.lua`), `applyBackdrop`
(`modules/MacroBar.lua`), `M.setItem` (`tests/wow_mock.lua`) and `itemCooldown`
(`core/MacroDisplay.lua`). None of the seven is a warning and none carries a disposition; they are
named here because the next default-heavy guard added to any of them crosses. Read the number with
`performance-§10` in mind — `lizard` counts every `and`/`or` short-circuit as a decision, so in Lua
a run of `t.k = rec.k or D.k` defaulting lines scores high with no branching a reader would see.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1497 | **Accepted, but now at the cap.** One case per behavior over the most in-client-coupled module; 1193 NLOC across 154 functions at avg CCN 1.3 — case count, not tangle. It gained 368 lines on `feat/fix-ccn` (the flyout and button characterization tests) and sits 3 lines under the 1500 cap: the next case added to it crosses. Split bar / button / flyout at that point, not before. |

No file is over the 1500 cap, and this one entered the band on `feat/fix-ccn` rather than drifting
into it — the disposition above is carried unchanged from [`20260804-215640`](20260804-215640/),
because nothing about it moved.
