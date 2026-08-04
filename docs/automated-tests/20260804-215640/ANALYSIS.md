# Analysis — 20260804-215640

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** c24b7df90349 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T21:56:40+05:30
- **Previous run:** [`20260804-182045`](../20260804-182045/) — the adoption baseline, taken on `master`

## Headline

The `feat/fix-ccn` record. Both gating suites are clean — `luacheck` reports 0 warnings / 0 errors
across 54 files, and the headless harness passes 656 of 656 cases, up from 605 because the branch
wrote characterization tests before each split. The result the branch exists for is in the
complexity footer: **0 functions over CCN 15, down from 20, with the largest previously at 62**.
Nothing regressed. The perf column is still a skip, and still means this run says nothing about
runtime cost.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260804-182045 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | no change — same 0/0 over the same 54 files |
| tests | pass | 656 passed, 0 failed, 656 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +51 cases, still 0 failures |
| perf | skip | — | — (not run) | no change — still no `tests/perf.lua` |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 20 warnings → 0; max CCN 62 → none above 15 |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the previous one across a change in size: the addon gained roughly 900 NLOC
and 153 functions on this branch, so the totals rose while the density fell.

| Metric | Value |
|---|---|
| Total NLOC | 15257 |
| Functions | 1630 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.7 |
| Max CCN | 0 as recorded — no function reached the reporting threshold |
| Avg tokens / function | 63.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

The `Max CCN` of 0 is not a measurement of zero complexity. The runner derives that field from
`lizard`'s warning block, and this run has no warning block — so it states the same fact the
`Warnings` row does: nothing above 15. `complexity.txt` ends with `No thresholds exceeded`.

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there.
That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says
nothing about the addon's runtime cost, and that `performance-§9`'s zero-overhead evidence does not
exist for this addon.

## What moved

- **lint** — unmoved: 0 warnings / 0 errors over 54 files, the same file count as the baseline. The
  branch added no source files, only functions inside existing ones.
- **tests** — 605 → 656 (+51), 0 failures on both sides. The additions are characterization tests
  written before the splits (`test_macrobar.lua`, `test_slash.lua`, `test_settingsui.lua`,
  `test_macromanager.lua`, `test_tooltipcache.lua`, `test_pipeline.lua`, `test_schema.lua`) plus
  three regression tests from the review round: the predicate debug gate, the composite body's exact
  assembled order, and the flyout entry border on both sides of `buttonBorder`.
- **perf** — unmoved, and permanently so until the addon ships scenarios.
- **complexity** — the branch's whole point. Warnings 20 → 0, nothing above CCN 15 where the worst
  was 62, avg CCN 3.0 → 2.7, avg NLOC/function 8.3 → 8.0, avg tokens 66.3 → 63.8. Totals rose
  (14339 → 15257 NLOC, 1477 → 1630 functions) because splitting a function into named helpers adds
  signatures and comments. Averages falling while totals rise is the shape a real de-densification
  takes; the reverse would have meant the branch moved branches around rather than removing them.
- **file bands** — still exactly one file in the 1000–1500 band and none over the cap, but the file
  in it moved a long way: `tests/test_macrobar.lua` 1129 → 1497 LOC.

## Complexity watch list

### Functions `lizard` warned on

None.

Every function the baseline listed is gone from this table. The twenty warned functions were split
into named file-locals across `core/SlashDump.lua`, `modules/MacroManager.lua`,
`core/ConsumableMaster.lua`, `core/SlashCommands.lua`, `core/MacroDisplay.lua`,
`core/TooltipCache.lua`, `modules/MacroBarButton.lua`, `modules/MacroBarFlyout.lua`,
`modules/Ranker.lua`, `modules/Selector.lua`, `settings/Category.lua` and `settings/Panel.lua`.
Their old dispositions are not carried forward: an "Accepted" is a decision about a function that
exists, and none of these exists in its warned form any more.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1497 | **Accepted, but now at the cap.** One case per behavior over the most in-client-coupled module, avg CCN 1.3 — case count, not tangle. It gained 368 lines this branch (the flyout and button characterization tests) and sits 3 lines under the 1500 cap. Split it bar / button / flyout when the next case is added, not before. |

## Actions

1. `tests/test_macrobar.lua` is 3 lines from the `layout-§1` cap (1497 of 1500). The next case added
   to it must come with the bar / button / flyout split, or land in a new sibling file. New here —
   no deviation ID or review finding owns it yet.
