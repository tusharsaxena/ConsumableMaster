# Analysis — 20260807-114612

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** 648e1421bcbf51e7ac4092fd93702effb29d24bc (master)
- **Previous run:** [`20260807-110619`](../20260807-110619/)

## Headline

Green on all four suites, and every figure is identical to the previous run — 0/0 lint over 56
files, 675/675 tests, 4 perf scenarios, 0 complexity warnings. Nothing in the addon changed
between the two runs; what changed is the **tree state**, and that is the point of this run.
[`20260807-110619`](../20260807-110619/) was recorded with `git.dirty: true` at `9cb3af8`, mid
re-vendor; this one is `dirty: false` at `648e142`, so it is the first bundle to measure the
LibKa0s v1.8.2 / testkit revision 10 payload as committed. The one thing still owed is unchanged
and now two runs old: `tests/test_macrobar.lua` sits over `layout-§1`'s 1500-line cap with no fix
and no tracked deviation ID.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260807-110619` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 56 files | [`lint.txt`](lint.txt) | No — `lint.txt` is byte-identical |
| tests | pass | 675 passed, 0 skipped, 0 failed, 675 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No — `test-cases.md` is byte-identical |
| perf | pass | 4 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | No — all four bytes/iter figures identical; only ms drifted |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | No — `complexity.txt` is byte-identical |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every field of `lizard`'s footer — totals *and* averages — plus the two derived counts. All
values from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of
[`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 15636 |
| Functions | 1676 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.7 |
| Max CCN | 15 |
| Avg tokens / function | 63.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 1 |

Every suite is a clean pass and no suite was skipped, so there is no unmeasured surface to declare.
The one non-clean reading is not a suite status at all: `overCapFiles` is 1, which
`automated-tests-§3` does not gate on and which the watch list below carries instead.

## What moved

Nothing measured moved. Stated per suite, because silence reads as "not checked":

- **lint** — 0 warnings / 0 errors over 56 files, both runs. `lint.txt` diffs clean, so the same 56
  files were in scope, not merely the same count.
- **tests** — 675 passed / 0 failed / 675 total, both runs. `test-cases.md` diffs clean, so the
  inventory is the same 675 cases and not a coincidental total. No case reported a skip.
- **perf** — 4 scenarios, pass, both runs. The machine-independent figures are unchanged to the
  decimal: `recompute` 9071.5 bytes/iter, `cooldownRefresh` 6000.0, `probeOverheadOff` 6000.0,
  `probeOverheadOn` 6001.3. The ms columns moved (`recompute` 0.86289 → 0.91346 ms/iter) and mean
  nothing — [`perf.txt`](perf.txt) says so in its own footer, and both runs share one machine.
  The 1.3 bytes/iter between the dormant and armed probe arms is `performance-§9`'s zero-overhead
  margin, unchanged.
- **complexity** — every footer field identical; `complexity.txt` diffs clean. Total NLOC did not
  move (15636) *and* neither did the averages (8.0 NLOC/function, 2.7 CCN), so this is not a case of
  a total masking a density change in either direction. Max CCN 15, warnings 0.

The delta that is real is metadata rather than measurement: `git.dirty` went `true` → `false` and
the sha went `9cb3af8` → `648e142`. The previous run was taken against an uncommitted re-vendor;
this one against the committed result of it, plus the `.gitattributes` re-sync at `648e142`.

## Complexity watch list

### Functions `lizard` warned on

None.

[`complexity.txt`](complexity.txt) ends with `No thresholds exceeded` and its footer records
`Warning cnt` 0. Seven functions sit **at** the cap of 15, which is inside the gate — `lizard`
warns strictly above 15 — and they are the same seven the previous run named, re-read from this
run's [`complexity.txt`](complexity.txt) rather than carried on trust: `itemCooldown`
(`core/MacroDisplay.lua:102-114`), `applyBackdrop` (`modules/MacroBar.lua:190-215`),
`S.PickBestForSlot` (`modules/Selector.lua:300-314`), `availableForHands`
(`modules/Selector.lua:344-363`), `S.SweepStaleDiscovered` (`modules/Selector.lua:545-571`),
`Helpers.BuildAboutContent` (`settings/Panel.lua:671-732`) and `M.setItem`
(`tests/wow_mock.lua:166-185`). None is a warning and none carries a disposition; they are named
because the next defaulting guard added to any of them crosses.

`lizard` counts every `and`/`or` short-circuit as a decision (`performance-§10`), so in Lua a run of
`t.k = rec.k or D.k` scores high with no branching a reader would see. Five of the seven are that
shape: dense **defaulting and guarding**. `S.SweepStaleDiscovered` and `availableForHands` are the
two with genuine control flow, and they are the two to split first if any ever needs it.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| > 1500 (over cap) | `tests/test_macrobar.lua` | 1688 | **Still owed a fix or a tracked deviation ID.** Not newly crossed — it crossed at [`20260807-022923`](../20260807-022923/) and this is the third bundle to record it. 1314 NLOC across 178 functions at avg CCN 1.3, so it remains case count rather than tangle, but `layout-§1` treats over-cap as a defect a disposition cannot hold. No issue on the repo tracks it (checked against the full issue list, open and closed). |
| 1000–1500 (on notice) | — | — | None. |

The band counts are unchanged from the previous run — `bandFiles` 0, `overCapFiles` 1 — so nothing
newly crossed and nothing came back under. On shelf life (`automated-tests-§4`): none of the six
runs recorded in `RESULTS.md` is a release run — every `manifest.json` carries `"release": null` —
so the three-consecutive-*release*-runs clock has never started and no entry has aged out by that
rule. This entry is owed a fix for the different reason that it is over a hard cap, and it has now
been carried unresolved across two runs since the previous analysis said the same thing.

## Actions

1. **Split `tests/test_macrobar.lua`** (1688 lines, over `layout-§1`'s 1500 cap) or open a tracked
   deviation with an ID and an owner. The natural seam is the one the earlier disposition named —
   bar / button / flyout. **New here in the sense that nothing owns it:** the repo's issue store has
   no entry for it, so this action has no tracker and will keep reappearing in every watch list
   until one exists. It does **not** block a commit and does **not** block the tag —
   `automated-tests-§3`'s release gate is all four suites plus zero functions over CCN 15, and file
   size is in neither.
2. **File an in-game perf capture.** `docs/perf-runs/` exists with its README and naming convention
   (`performance-§8`) but holds no `<date>-ingame-<label>.json`. The four offline scenarios in this
   bundle do not substitute for it — an offline scenario and a live capture measure different
   things.
