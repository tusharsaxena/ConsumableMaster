# Analysis — 20260807-022923

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** d69c4fa4c5c8cacb543ef95a5abb50545001e4f5 (master), dirty
- **Previous run:** [`20260804-233147`](../20260804-233147/)

## Headline

All four suites pass and the verdict is green: lint is clean over 56 files, 675 cases pass with none
failed and none skipped, and `lizard` warns on nothing. **This is the first run in which `perf`
actually ran** — the three rows above it are `skip`, recorded before `tests/perf.lua` existed, so
four scenarios replace a standing gap rather than improving a number. One thing needs acting on:
`tests/test_macrobar.lua` is now **1688 lines and over `layout-§1`'s 1500 cap**, having sat at 1497
inside the on-notice band at the previous run. The manifest records the crossing as
`overCapFiles: 1`; the disposition that carried it as "Accepted, but now at the cap" has expired.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured. Nothing was
skipped in this run.

| Suite | Status | Result | Artifact | Moved since `20260804-233147` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 56 files | [`lint.txt`](lint.txt) | scope 54 → 56 files; 0/0 unchanged |
| tests | pass | 675 passed, 0 skipped, 0 failed, 675 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 656 → 675 (+19) |
| perf | pass | 4 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `skip` → `pass`; 0 → 4 scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | 0 warnings held; one file crossed the LOC cap |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below comes from `manifest.json`'s `suites.complexity`, which records all eight of
`lizard`'s footer fields plus the two derived band counts.

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

The averages are the point. Total NLOC rose 379 and the function count rose 46, but **avg NLOC per
function held at 8.0 and avg CCN held at 2.7** — the addon got bigger, not denser, and only the
second would have been a complexity signal. `complexity.txt` ends with `No thresholds exceeded` and
a `Warning cnt` of 0.

Every suite is a clean pass, so there is no per-suite exception paragraph to write. The one item
that is not a pass/fail question is the file-size band, and it is below.

## What moved

- **lint** — the linted scope went 54 → 56 files while staying at 0 warnings / 0 errors. The green
  is therefore over a **different, larger** scope than the previous run, not the same one. Comparing
  the two `lint.txt` file lists: `core/DebugLogSetup.lua`, `core/PerfSetup.lua`, `defaults/Profile.lua`
  and `settings/OptionsSetup.lua` are newly in scope, and `modules/DebugLog.lua` and
  `modules/PerfSetup.lua` are gone — four added, two removed, net +2.
- **tests** — 656 → 675, +19 cases, none removed. Per the two bundles' `## Totals` tables the gain
  is `test_slashsetup.lua` +5, `test_macrobar.lua` +5, `test_surface_parity.lua` +4 (a suite that did
  not exist at the previous run), `test_settingsui.lua` +3, `test_schema.lua` +1 and
  `test_perfsetup.lua` +1. No suite lost a case.
- **perf** — `skip` → `pass`. The previous manifest's `skipReason` was `no tests/perf.lua — this
  addon ships no offline scenarios`; that is no longer true. Four scenarios ran: `recompute`
  (0.79117 ms/iter, 9071.5 bytes/iter), `cooldownRefresh` (0.01460 ms/iter, 6000.0 bytes/iter) and
  the `probeOverheadOff` / `probeOverheadOn` pair (6000.0 vs 6001.3 bytes/iter), all at 200
  iterations. This is a **baseline** — there is no previous perf reading to diff against, and the
  millisecond columns are orientation only.
- **complexity** — NLOC 15257 → 15636 (+379), functions 1630 → 1676 (+46), avg tokens/function
  63.8 → 63.7. Avg NLOC (8.0), avg CCN (2.7), max CCN (15) and warnings (0) all held exactly.
  `bandFiles` 1 → 0 and `overCapFiles` 0 → 1: that is not two files moving, it is **one file leaving
  the on-notice band by crossing the cap above it**.

## Complexity watch list

### Functions `lizard` warned on

None.

`Warning cnt` is 0 and `complexity.txt` ends with `No thresholds exceeded`. Max CCN is 15, which is
**at** the cap and inside the gate — `lizard` warns above 15, and `automated-tests-§3` gates a
release on zero functions over it. Nothing here carries a disposition, because a disposition is a
decision about a warned function and there are none.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| Over the 1500 cap | `tests/test_macrobar.lua` | 1688 | **Newly crossed — split it.** Was 1497 and inside the band at the previous run; `layout-§1` treats over-cap as a defect, not a state to accept. Split bar / button / flyout, which is exactly what the previous run's disposition said to do "at that point, not before". That point has arrived. |
| 1000–1500 (on notice) | — | — | None. |

The file identity and LOC are derived with the **runner's own** band expression rather than typed in:
`find . -name '*.lua' -not -path './libs/*' -not -path './tests/_kit/*' -exec wc -l {} +`, which is
the command `run-automated-tests.sh` uses to produce `bandFiles` / `overCapFiles`. `manifest.json`
records the counts (0 and 1); it does not record which file, so the identity is re-derived and the
count cross-checks against the manifest.

The crossing did **not** happen in this run's changes. `tests/test_macrobar.lua` was 1497 lines at
`97c05b8`, the commit the previous bundle recorded, and 1548 by `e5e3b22` — it went over the cap when
`tests/perf.lua` shipped and has grown to 1688 since. No run happened in between, so this is the
first bundle in a position to record it.

## Actions

1. **Split `tests/test_macrobar.lua`** (1688 LOC, over the `layout-§1` 1500 cap) along the bar /
   button / flyout seam the previous run already named. This is new here and has no deviation ID or
   review finding owning it yet, so it needs one or a fix.
2. **File the in-game perf capture.** `docs/perf-runs/` carries its README and the
   `<date>-ingame-<label>.json` naming convention, but no capture has been committed. The four
   offline scenarios recorded here do not substitute for it — an offline scenario and a live capture
   are different measurements.
