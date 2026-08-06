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
| [`20260807-022923`](20260807-022923/) | 1.5.0 | 0/0 | 56 | 675/675 | pass | 15636 | 1676 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-233147`](20260804-233147/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 15 | 0 | **green** |
| [`20260804-215640`](20260804-215640/) | 1.5.0 | 0/0 | 54 | 656/656 | skip | 15257 | 1630 | 8.0 | 2.7 | 0 | 0 | **green** |
| [`20260804-182045`](20260804-182045/) | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

**The `Max CCN` of 0 on [`20260804-215640`](20260804-215640/) is an instrument fault, not a
measurement** — see [Complexity watch list](#complexity-watch-list) for what it should read.

## Test suite

675 cases, the count the newest run [`20260807-022923`](20260807-022923/) records — 675 passed,
0 failed, 0 skipped. The inventory went 656 → 675, **19 added and none removed**, and the count is
still tracking the addon: `test_slashsetup.lua` +5, `test_macrobar.lua` +5,
`test_surface_parity.lua` +4, `test_settingsui.lua` +3, `test_schema.lua` +1 and
`test_perfsetup.lua` +1. `test_surface_parity.lua` is a **new suite** rather than growth in an old
one; it pins the degraded LibKa0s stub against the live seam, which is the class of defect no other
case could see. The generated inventory `test-cases.md` in each bundle is the authority on what
exists at that point; the README badge tracks the same number.

The count has moved at every run recorded here (605 → 656 → 675), so the "suite stopped growing
while the addon did" gap does not apply. What the headless suite still cannot reach is the in-client
half — secure frames, real taint, the actual macro writers — which is covered by
[`../smoke-tests.md`](../smoke-tests.md) and not by any number in the table above.

## Lint

Clean over **56 files**: 0 warnings, 0 errors. The zeros have not moved across any run recorded
here, but the **scope has** — 54 → 56 at [`20260807-022923`](20260807-022923/), so this green is
over a larger surface than the row below it rather than a repeat of the same check.
`core/DebugLogSetup.lua`, `core/PerfSetup.lua`, `defaults/Profile.lua` and
`settings/OptionsSetup.lua` came into scope; `modules/DebugLog.lua` and `modules/PerfSetup.lua`
left it. Four in, two out, net +2 — comparing the two runs' `lint.txt` file lists.

What that scope is matters more than the zeros, so it is spelled out: `.luacheckrc` sets
`std = "lua51"` and excludes exactly four paths — `libs/` (third-party, not this repo's to fix),
`docs/audits/` and `docs/reviews/` (frozen bundles, not code), and **`tests/`**, which runs under
its own mock and sets globals deliberately. The test harness is therefore **not** linted; it is
covered by being executed instead, 675 cases per run.

**Two** warning codes are suppressed globally, not three: `212` (unused arguments — `self` on widget
methods, `event`/`reason` on handlers) and `542` (intentional empty branch, the CSV skip in
`/cm stat secondary`). The `241` suppression that earlier revisions of this section described — the
`TooltipCache` `pendingIDs` set that was populated and never read — is **gone from `.luacheckrc`**,
so nothing is parked behind it any more.

## Perf

**Four scenarios, and the column reads `pass` — for the first time.**
[`20260807-022923`](20260807-022923/) is the first run in which this suite actually executed. Every
`skip` in the table above predates `tests/perf.lua` and carried the sanctioned reason "no
`tests/perf.lua` — this addon ships no offline scenarios" (`automated-tests-§3`, the first of the
two permitted skips — this addon holds **no** `performance-§12` no-combat-path exemption). Those
rows are left as they were recorded, because a run record is what that run measured and not what a
later run would have.

The first readings, at 200 iterations each, from
[`20260807-022923/perf.txt`](20260807-022923/perf.txt): `recompute` 9071.5 bytes/iter,
`cooldownRefresh` 6000.0, `probeOverheadOff` 6000.0 and `probeOverheadOn` 6001.3. These are a
**baseline** — there is no earlier perf reading to compare them against, and the 1.3 bytes/iter
between the dormant and armed probe arms is the zero-overhead margin, not a trend.

The suite drives `recompute` and `cooldownRefresh` — the out-of-combat pass and the
near-frame-frequency in-combat path — plus the `probeOverheadOff` / `probeOverheadOn` pair that is
`performance-§9`'s zero-overhead evidence: the same cooldown walk with the brackets dormant and
armed. The dormant arm carries an **absolute** byte ceiling as well as the relation to the armed
one, because a relation alone cannot go red when an allocation is added to the measured path itself
— both arms rise together and the relation still holds. A third assertion counts the bucket notes an
armed capture records, so a build where `core/PerfSetup.lua` returned early cannot masquerade as a
perfect zero-overhead result.

**Recorded, never gating** for a run or a commit; `automated-tests-§3` has it gate the tag, where a
`skip` is not evaluated and a `pass` is.

Standing gaps, both real and neither one filled by the other — an offline scenario and a live
capture are different measurements:

- The in-game half has no committed capture yet. `docs/perf-runs/` exists now with its README and
  the naming convention (`performance-§8`), but no `<date>-ingame-<label>.json` has been filed.
- Offline timings are orientation only. The machine-independent figures are the per-iteration byte
  counts and the call counts; the millisecond columns say nothing across machines.

Background, the bucket list and the gate idiom: [../performance.md](../performance.md). Record shape
and naming: [../perf-runs/README.md](../perf-runs/README.md).

## Complexity watch list

Current state as of [`20260807-022923`](20260807-022923/) — not that run's diff.
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

The same seven functions still sit **at** the cap of 15, which is inside the gate — `lizard` warns
above 15 and `automated-tests-§3` gates on zero functions over it. Re-read from this run's
[`complexity.txt`](20260807-022923/complexity.txt) rather than carried over on trust, and named
rather than counted so the claim cannot go stale silently: `itemCooldown`
(`core/MacroDisplay.lua:102-114`), `applyBackdrop` (`modules/MacroBar.lua:190-215`),
`S.PickBestForSlot` (`modules/Selector.lua:300-314`), `availableForHands`
(`modules/Selector.lua:344-363`), `S.SweepStaleDiscovered` (`modules/Selector.lua:545-571`),
`Helpers.BuildAboutContent` (`settings/Panel.lua:671-732`) and `M.setItem`
(`tests/wow_mock.lua:166-185`). Seven at the previous run, seven now, and the same seven — the
+46 functions this run added all landed below the cap. None is a warning and none carries a
disposition; they are named because the next default-heavy guard added to any of them crosses.

Read the number with `performance-§10` in mind — `lizard` counts every `and`/`or` short-circuit as a
decision, so in Lua a run of `t.k = rec.k or D.k` defaulting lines scores high with no branching a
reader would see. Five of the seven are that shape: dense **defaulting and guarding**, not tangled
control flow. `S.SweepStaleDiscovered` and `availableForHands` are the two with real branching, and
they are the two to look at first if any of them ever needs splitting.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| **Over the 1500 cap** | `tests/test_macrobar.lua` | 1688 | **NEWLY CROSSED — no longer accepted; split it.** 1314 NLOC across 178 functions at avg CCN 1.3, so this is still case count and not tangle — but `layout-§1` treats over-cap as a defect rather than a state a disposition can hold. The previous run carried it as "Accepted, but now at the cap … split bar / button / flyout at that point, not before"; that point has arrived. Owed a fix or a tracked deviation ID with an owner. |
| 1000–1500 (on notice) | — | — | None. |

**This is the change to read in this run.** `manifest.json` went `bandFiles` 1 → 0 and
`overCapFiles` 0 → 1: not two files moving, but the one file leaving the on-notice band by crossing
the cap above it. The crossing did **not** happen in this run's changes — `tests/test_macrobar.lua`
was 1497 lines at `97c05b8` (the commit [`20260804-233147`](20260804-233147/) recorded) and was
already 1548 by `e5e3b22`, when `tests/perf.lua` shipped. No run happened in between, so this is
simply the first bundle in a position to see it, and it has since grown to 1688.

On the disposition's shelf life (`automated-tests-§4`): the "Accepted" was carried across three
recorded runs, but **none of the four runs in this table is a release run** — every
`manifest.json` has `"release": null` — so the three-consecutive-*release*-runs clock never started.
The disposition is being retired here because the file crossed a hard cap, not because it timed out.
Either way it does not survive this run, and re-accepting it would be the anti-pattern #53 shape:
a watch list where everything is accepted carries no signal.
