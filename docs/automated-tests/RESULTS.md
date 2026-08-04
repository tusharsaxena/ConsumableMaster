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
| [`20260804-182045`](20260804-182045/) | 1.5.0 | 0/0 | 54 | 605/605 | skip | 14339 | 1477 | 8.3 | 3.0 | 62 | 20 | **green** |

## Test suite

605 cases, five of them added this session for `SetCompositeMacro`'s write tail — a path that had **no** direct coverage before, because `test_pipeline.lua` only ever stubbed it. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 54 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-182045`](20260804-182045/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

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
