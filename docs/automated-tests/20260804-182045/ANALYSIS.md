# Analysis — 20260804-182045

- **Addon:** ConsumableMaster 1.5.0
- **Verdict:** green
- **Commit:** 3a809822b68a (master), dirty
- **Started:** 2026-08-04T18:20:45+05:30
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
54 files and the headless harness passes 605 of 605 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | — first run |
| tests | pass | 605 passed, 0 failed, 605 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | — first run |
| perf | skip | — | — (not run) | — first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | — first run |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the next one across a change in size: a total that rises because the addon
grew is a different fact from an average that rises because it got denser, and only the second is a
complexity signal.

| Metric | Value |
|---|---|
| Total NLOC | 14339 |
| Functions | 1477 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 3.0 |
| Max CCN | 62 |
| Avg tokens / function | 66.3 |
| Warnings (CCN > 15) | 20 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.01 / 0.06 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `run` (`DUMP_TARGETS.pick`) | 62 | `core/SlashDump.lua` | **Accepted — the branch count *is* the diagnostic.** `/cm dump pick` walks every category and prints why each candidate won or lost. Runs on a typed command, never a frame. |
| `M.SetCompositeMacro` → `commitMacro` | 35 | `modules/MacroManager.lua` | **Accepted, and rising is the win.** F-006 collapsed the duplicate write ladder into this one; 27 → 35 is the second copy being absorbed. |
| `run` (`DUMP_TARGETS.item`) | 32 | `core/SlashDump.lua` | **Accepted**, same grounds — `/cm dump <itemID>`; one branch per printed field. |
| `bindEntry` | 30 | `modules/MacroBarFlyout.lua` | **Accepted for now.** Secure-frame binding; the branches are the combat/template/secret-value guards `events-frames-taint` requires. |
| `buildCompositeBody` | 27 | `modules/MacroManager.lua` | **Peel next — now unblocked.** Its "peel with F-006" gate is discharged; F-006 landed without touching it. |
| `P.Recompute` | 26 | `core/ConsumableMaster.lua` | **Accepted.** The recompute stage sequencer; branches are cheap early-outs on the instrumented hot path. |
| `S.GetBucket` | 23 | `modules/Selector.lua` | **Accepted.** The branch count *is* the spec/class/global fallback specification, and the suite pins each arm. |
| `BB.ApplyStyle` | 21 | `modules/MacroBarButton.lua` | **Accepted.** One branch per user-visible styling toggle, driven by the settings schema. |
| `OnAccept` | 21 | `settings/Category.lua` | **Accepted.** A `StaticPopupDialogs` handler validating free-text item input; branches are the validation cases. |
| `discoverOne` | 20 | `core/ConsumableMaster.lua` | **Accepted.** Auto-discovery's per-item classification decision. Re-read if review finding **F-005** changes the call pattern. |
| `parseDuration` | 19 | `core/TooltipCache.lua` | **Accepted, tied to `CM-30`.** The CCN is the English-phrasing ladder that deviation records as an accepted enUS-only limitation. |
| `validateSchemaValue` | 18 | `settings/Panel.lua` | **Peel next, with F-013** — that finding adds a defaults-resolution pass to this exact function. Restructure into a validator list as part of it, not before. |
| `statWeight` | 17 | `modules/Ranker.lua` | **Accepted.** Stat-to-weight mapping; would be a lookup table if the weights were constant, but several are spec-conditional. The only warning left in this file. |
| `FO.Apply` | 17 | `modules/MacroBarFlyout.lua` | **Accepted for now.** Flyout layout application, out-of-combat only and covered by `tests/test_macrobar.lua`. |
| `KCM.ResetAllToDefaults` | 16 | `core/ConsumableMaster.lua` | **Accepted.** One branch per resettable subtree; tracks the settings schema by construction. |
| `MD.SetTooltip` | 16 | `core/MacroDisplay.lua` | **Accepted.** Secret-value-safe tooltip assembly — the guards `events-frames-taint-§8` mandates. Simplifying it is how the restricted-cooldown regression returns. |
| `parseLines` | 16 | `core/TooltipCache.lua` | **Accepted, tied to `CM-30`**, same reasoning as `parseDuration`. |
| `onSubmit` | 16 | `settings/Category.lua` | **Accepted.** Category-page submit validation, sibling to `OnAccept`. |
| `submitAddByID` | 16 | `settings/Category.lua` | **Accepted.** Lifted out of `renderSingle` this session: one branch per way a typed ID can be rejected, each saying something different to the player. |
| `]` (anonymous) | 14 | `modules/KCMItemRow.lua` | **Resolved this session** — was CCN 26 and anonymous; now `refreshDisplay` over five named halves. Listed only to record that it left the list. |

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_macrobar.lua` | 1129 | **Accepted.** One suite per behaviour over the most in-client-coupled module, avg CCN 1.3 — case count, not tangle. Peel by module only past 1500. |

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
