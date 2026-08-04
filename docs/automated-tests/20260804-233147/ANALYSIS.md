# Analysis — 20260804-233147

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** 97c05b872ca0 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T23:31:47+05:30
- **Previous run:** [`20260804-215640`](../20260804-215640/) — the first `feat/fix-ccn` record

## Headline

This is the run that closes the CCN work, and it closes it by finally being able to *say* so. Both
gating suites are clean — 0 warnings / 0 errors over 54 files, 656 of 656 cases — and the complexity
footer reads **0 functions over CCN 15, with the maximum at exactly 15**. The previous run measured
the same code (its `complexity.txt` is byte-identical to this one) but recorded `maxCcn` as 0,
because the kit it ran under read that field out of `lizard`'s `!!!! Warnings` block and there was no
such block to read. Nothing regressed; the only thing that moved between these two runs is the
instrument.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260804-215640 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | no change — byte-identical artifact |
| tests | pass | 656 passed, 0 failed, 656 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | no change — byte-identical artifact |
| perf | skip | — (not run) | — (no artifact) | no change — still no `tests/perf.lua` |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | figures unmoved; `Max CCN` now reported as 15 instead of 0 |

### Complexity in full

Every field of `lizard`'s footer as `manifest.json` records it, plus the two derived file counts.
The totals and the averages are both here on purpose: a total that rose because the addon grew is a
different fact from an average that rose because it got denser, and only the second is a complexity
signal.

| Metric | Value |
|---|---|
| Total NLOC | 15257 |
| Functions | 1630 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.7 |
| Max CCN | 15 |
| Avg tokens / function | 63.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

`complexity.txt` ends with `No thresholds exceeded (cyclomatic_complexity > 15 …)` over the footer
line `15257  8.0  2.7  63.8  1630  0  0.00  0.00`. Seven functions sit **at** the cap of 15 and none
is above it. Named in full, because a count without its members is the claim that goes stale
silently:

| Function | CCN | Location |
|---|---|---|
| `Helpers.BuildAboutContent` | 15 | `settings/Panel.lua:699-760` |
| `S.SweepStaleDiscovered` | 15 | `modules/Selector.lua:545-571` |
| `availableForHands` | 15 | `modules/Selector.lua:344-363` |
| `S.PickBestForSlot` | 15 | `modules/Selector.lua:300-314` |
| `applyBackdrop` | 15 | `modules/MacroBar.lua:183-208` |
| `M.setItem` | 15 | `tests/wow_mock.lua:154-173` |
| `itemCooldown` | 15 | `core/MacroDisplay.lua:100-112` |

Fifteen is the cap, not a warning: `lizard` warns above 15, and the release gate in
`automated-tests-§3` is zero functions **over** 15. These seven are inside it. Read them with
performance-§10 in mind — `lizard` scores every `and`/`or` short-circuit as a decision, so a Lua
function that defaults or guards a lot of fields scores high with no tangled control flow at all,
and that is what most of these are.

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there.
That is a **skip, not a pass**, and it is recorded as one in `manifest.json`
(`"skipReason": "no tests/perf.lua — this addon ships no offline scenarios"`). This run therefore
says nothing about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence still
does not exist for this addon.

## What moved

- **lint** — unmoved. 0 warnings / 0 errors over 54 files; `lint.txt` is byte-identical to the
  previous run's.
- **tests** — unmoved. 656 passed, 0 failed, 656 total; `tests.txt` and `test-cases.md` are both
  byte-identical to the previous run's, so no case was added, removed or renamed between them.
- **perf** — unmoved, and permanently so until the addon ships scenarios.
- **complexity** — every measured figure is unmoved: 15257 NLOC, 1630 functions, avg NLOC 8.0, avg
  CCN 2.7, avg tokens 63.8, 0 warnings, `Fun Rt` / `nloc Rt` both 0.00, and `complexity.txt` is
  byte-identical to the previous run's. The one changed number is `manifest.json`'s `maxCcn`, 0 → 15,
  and it is an **instrument** change rather than a code change: before the LibKa0s v1.7.0 testkit
  (rev 6) re-vendor the runner scraped `CCN_MAX` from the `!!!! Warnings` block, which is empty the
  moment an addon reaches zero warnings, so it printed 0 for a clean tree. The rev-6 runner scans
  every function row instead. The true maximum for both runs was always 15, and both bundles'
  `complexity.txt` says so.
- **file bands** — unmoved: one file in the 1000–1500 band, none over the 1500 cap.

## Complexity watch list

### Functions `lizard` warned on

None.

`complexity.txt` ends with `No thresholds exceeded` and the footer's `Warning cnt` is 0. This is the
state the `feat/fix-ccn` branch was opened to reach, and this run is the first whose recorded
`Max CCN` proves it rather than merely failing to contradict it. The twenty functions the adoption
baseline listed do not appear here, and their old dispositions are not carried forward: an
"Accepted" is a decision about a function that exists, and none of the twenty exists in its warned
form any more.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1497 | **Accepted, but at the cap.** One case per behavior over the most in-client-coupled module; `complexity.txt`'s per-file row reads 1193 NLOC across 154 functions at avg CCN 1.3 — case count, not tangle. Its last function ends at line 1497, three under the 1500 cap: the next case added to it crosses. Split bar / button / flyout at that point, not before. Carried unchanged from the previous run. |

## Actions

1. `tests/test_macrobar.lua` is 3 lines from the `layout-§1` cap (1497 of 1500). The next case added
   to it must come with the bar / button / flyout split, or land in a new sibling file. Carried from
   the previous run's analysis; still new here — no deviation ID or review finding owns it yet.
2. Nothing else. No suite regressed, and the single figure that changed in this run is an instrument
   correction rather than a finding.
