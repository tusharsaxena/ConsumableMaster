# Analysis — 20260916-094429

- **Addon:** ConsumableMaster 1.6.2
- **Verdict:** green
- **Commit:** c4e832d5e3b85f561ed8b2f9e95baa89d82fe631 (master), clean
- **Previous run:** [`20260911-220327`](../20260911-220327/) (1.6.1 → 1.6.2)

## Headline

All four suites ran and all four passed: lint 0/0 over 108 files, 901 headless cases with nothing
failed or skipped, five offline perf scenarios, and zero functions above CCN 15. The addon grew
substantially since the previous run — +3233 NLOC, +365 functions, +105 test cases — and got very
slightly *less* dense doing it (avg CCN 2.7 → 2.6, avg NLOC/function 8.1 → 8.0), which is the shape
a healthy growth run should have. Two things are owed a reader's attention and neither is a failure:
four files newly entered the `layout-§1` 1000–1500 band with no disposition on them, and the
`recompute` perf scenario's allocation per iteration went from 2947.8 to 11440.0 bytes.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260911-220327` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 108 files | [`lint.txt`](lint.txt) | files 102 → 108; warnings and errors both still 0 |
| tests | pass | 901 passed, 0 skipped, 0 failed, 901 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 796 → 901 (+105); failures and skips still 0 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | scenario count unchanged at 5; `recompute` bytes/iter 2947.8 → 11440.0, ms/iter 0.90213 → 0.97282 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings in both runs; totals up, averages down (table below) |

**Complexity in full** — every field of `lizard`'s footer as recorded in
[`manifest.json`](manifest.json)'s `suites.complexity`, totals *and* averages:

| Metric | Value |
|---|---|
| Total NLOC | 22225 |
| Functions | 2342 |
| Avg NLOC / function | 8.0 |
| Avg CCN | 2.6 |
| Max CCN | 15 |
| Avg tokens / function | 63.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 6 |
| Files over the 1500 cap | 2 |

Every suite was a clean pass. Nothing was skipped: `luacheck` 1.2.0, `lizard` 1.24.0 and Lua 5.1.5
were all present on the host (`manifest.json` → `host`), so no figure in this bundle stands in for
an unmeasured suite.

## What moved

- **lint** — 102 → 108 files in scope, still 0/0. The six extra files are new source the addon
  gained this cycle; the config's `exclude_files` (`libs/`, `docs/audits/`, `docs/reviews/`,
  `tests/_kit/`) did not change, so the wider scope is real coverage rather than a scope shift.
- **tests** — 796 → 901 cases, +105, the largest single-run jump in the recorded history of this
  table. Still 0 failed and 0 skipped, so passed and total agree and no case in the row claims
  coverage it did not exercise.
- **perf** — five scenarios in both runs. Four are flat inside the noise this harness can resolve
  (cooldownRefresh 0.01917 → 0.01995, probeOverheadOff 0.01904 → 0.02057, probeOverheadOn
  0.01905 → 0.02217, refreshBurst 0.01785 → 0.02806 ms/iter). `recompute` is the one that actually
  moved: **bytes/iter 2947.8 → 11440.0, a 3.9× rise**, with ms/iter up only 8% (0.90213 → 0.97282).
  Timings are cross-machine-meaningless by the harness's own note, but an allocation figure counted
  per iteration is not, so the byte movement is the signal and the millisecond movement is not.
  That is a garbage pressure question for `recompute`, not a latency one, and it is worth a look
  before the next tag.
- **complexity** — totals up with the addon (NLOC 18992 → 22225, functions 1977 → 2342); averages
  down (avg CCN 2.7 → 2.6, avg NLOC/function 8.1 → 8.0, avg tokens 64.0 → 63.8). Max CCN unchanged
  at 15 and warnings unchanged at 0, so nothing crossed the release gate's CCN line. Band files
  2 → 6; over-cap files unchanged at 2.

## Complexity watch list

### Functions `lizard` warned on

None. Eight functions sit at exactly CCN 15 — `D.RunMigrations` (`core/Database.lua:115`),
`itemCooldown` (`core/MacroDisplay.lua:102`), `applyBackdrop` (`modules/MacroBar.lua:229`),
`S.PickBestForSlot` / `availableForHands` / `S.SweepStaleDiscovered` (`modules/Selector.lua`),
`Helpers.BuildAboutContent` (`settings/Panel.lua:1050`) and `M.setItem` (`tests/wow_mock.lua:200`) —
none over it. All eight are dense **defaulting and guarding** rather than tangled control flow:
`lizard` scores every `and`/`or` short-circuit as a decision, and these are runs of field defaulting,
slot guards and migration branches with no nesting to speak of.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/Category.lua` | 1400 | **Accepted — third consecutive release run, and its shelf life is up.** 1143 → 1400 this cycle. Still 100 under the cap, avg CCN 4.4 over 97 functions, no warned function. Carried as Accepted at 1.6.0, 1.6.1 and 1.6.2; `automated-tests-§4` now asks for a fix or a tracked deviation ID with an owner rather than a fourth acceptance. Seam remains the self-contained drag-reorder block. |
| 1000–1500 (on notice) | `settings/MacroBar.lua` | 1166 | **Newly crossed — accepted for this run, re-check at 1300.** 763 → 1166 this cycle, the macro-bar settings page growing with the feature. 801 NLOC across 42 functions at avg CCN 3.2 and no warned function, so it is page breadth rather than tangle. |
| 1000–1500 (on notice) | `settings/Panel.lua` | 1426 | **Accepted — third consecutive release run, and its shelf life is up.** 1165 → 1426 this cycle, now the largest source file in the repo and 74 under the cap. It holds this addon's joint-highest-CCN function, `Helpers.BuildAboutContent` at exactly 15 (dense content assembly, not branching), so the two numbers on this file move together. Carried as Accepted at 1.6.0, 1.6.1 and 1.6.2; owed a peel or a tracked deviation ID rather than a fourth acceptance. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1012 | **Newly crossed — accepted, case count not tangle.** 788 → 1012. 744 NLOC across 71 functions at avg CCN 2.1. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_selector.lua` | 1011 | **Newly crossed — accepted, case count not tangle.** 829 → 1011. 713 NLOC across 66 functions at avg CCN 1.4. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1052 | **Newly crossed — accepted, case count not tangle.** 831 → 1052. 839 NLOC across 109 functions at avg CCN 1.3, the lowest density in the band. Re-check at 1300. |
| > 1500 (over cap) | `tests/test_macrobar.lua` | 2229 | **Owned: issue [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32)**, naming the two cuts a peel would follow. 2011 → 2229 this cycle. An open issue naming the seam is one of the three terminal states `layout-§1` allows a breach; the repo-wide census is `docs/ARCHITECTURE.md` § *Files over the 1500-line cap*, held to the tracked set by `tests/test_layout_cap.lua`. |
| > 1500 (over cap) | `tests/test_settingsui.lua` | 2028 | **Owned: issue [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33)**, naming the cut at `:981` — the three `options-ui` conformance blocks out to `test_settingsui_optionsui.lua`. 1675 → 2028 this cycle. Same terminal state and same census as the row above. |

## Actions

1. **`settings/Panel.lua` and `settings/Category.lua` have been Accepted across three consecutive
   release runs** (1.6.0, 1.6.1, 1.6.2) and are now the largest files in the repo at 1426 and 1400.
   `automated-tests-§4` / anti-pattern #53 make a fourth acceptance the wrong answer: either peel
   them, or add a ratified row with a re-check trigger to `docs/ARCHITECTURE.md` →
   *Documented deviations* and cite the ID from the disposition. New here — neither file has a
   deviation ID or an issue today.
2. **Investigate `recompute`'s allocation.** `perf.json` records 11440.0 bytes/iter against the
   previous run's 2947.8 for the same scenario at the same 200 iterations. Nothing gates on it, but
   a 3.9× per-iteration allocation rise with flat wall time usually means a new table or closure
   per pass in the recompute path. New here.
3. **`docs/ARCHITECTURE.md` § *Files over the 1500-line cap*** records `tests/test_macrobar.lua` at
   2210 lines measured 2026-09-14; this run measures 2229. The census tracks the right set and the
   disposition is unchanged, so this is a stale figure rather than a new breach — refresh it the
   next time that section is touched.
