# 05 — Execution plan: Ka0s Consumable Master (2026-10-07)

This is the hand-off to the remediation engagement. Every step is keyed to a deviation ID in
`02_DEVIATIONS.md` and designed in `04_TECHNICAL_DESIGN.md`.

The work is one short sprint with no runtime change. In this repo nothing is staged, committed or
pushed without an explicit instruction (`CLAUDE.md` *Hard rules*), and the version is not bumped.

**Scope of the plan:** 7 actionable roots (5 MUST, 2 SHOULD, all Low), and 2 Info entries that need
no local work. The counts match `02_DEVIATIONS.md`: 9 roots, 0 dependents, and 9 in total.

## Sprint 1 — docs, comments and the record (one feature branch)

| # | Step | IDs | Files | Done when |
|---|---|---|---|---|
| 1 | Write the span re-vendor bundle `docs/revendor/2026-10-07-v1.68.1-v1.70.0/`, with line 1 of `01_DELTA.md` reading `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)` | `CM-91` | new folder only | `AUDIT.md`'s re-vendor check prints nothing under `UNRECORDED:` |
| 2 | Run `/dev-copilot:sync-docs`. Fix the 19 stale `file:line` citations in `docs/ARCHITECTURE.md` (`:102`, `:122-124`, `:168-177`), preferably dropping the line suffix from the *Event Subscriptions* table. Rename `/wow-addon:perf-analysis` at `docs/perf-analysis/README.md:133`. | `CM-97` | `docs/ARCHITECTURE.md`, `docs/perf-analysis/README.md` | every remaining `ConsumableMaster.lua:`/`MacroManager.lua:` citation in the hub re-reads to the named function, and `grep -n '/wow-addon' docs/perf-analysis/README.md` is empty |
| 3 | In the same `ARCHITECTURE.md` pass, rewrite the register rows' evidence ids so that they resolve in this repo. Change the *Why* and *Decided* cells only. | `CM-99` | `docs/ARCHITECTURE.md:376-377` | each id resolves to a heading under `docs/audits/`/`docs/reviews/`, or to an issue in this repo |
| 4 | Put the sighted runner command in the `complexity` row's Command cell, and move the raw `lizard` line into an explanatory note | `CM-100` | `docs/testing.md:283` | `grep -n 'lizard -l lua' docs/testing.md` hits only the note, never a Command cell |
| 5 | Extend the CoreSetup TOC comment to name `core\SlashDump.lua`. Correct `core/SlashDump.lua:15`'s seam attribution. | `CM-98` | `ConsumableMaster.toc:97-99`, `core/SlashDump.lua:15` | the comment names `KCM.Say` and both consumers, and `luacheck .` is still 0/0 |
| 6 | Add a conventional-group note for `# Defaults`, after first confirming that no seed file reads `KCM.Categories` at file scope | `CM-83` | `ConsumableMaster.toc` (comment lines only) | the note is present, and no file line moves |
| 7 | Expand the three bare `§9` continuations | `CM-75` | `modules/MacroManager.lua:709`, `tests/run.lua:477`, `tests/test_debugcoverage.lua:2` | the `(?<![A-Za-z0-9-])§[0-9]+` sweep from `03_EVIDENCE.md` E10 hits only `docs/smoke-tests.md` |
| 8 | Run the green gate | all | — | `ka0s-bounded lua5.1 tests/run.lua` shows 1201/0/1 (1202), `ka0s-bounded luacheck .` shows 0/0, and `test_prose`, `test_layout_cap` and `test_vendor_sync` are green. `docs/test-cases.md` and the `[Tests]` badge are unchanged, because no case moved. |

## Deferred, not in this sprint

| ID | When | Action |
|---|---|---|
| `CM-95` | at the next release | Produce the full automated-test bundle, which is the first sighted run. Check `blindFiles = 0`, rule on any function at CCN 15 as *newly measured*, and disposition `tests/wow_mock.lua` and `tests/test_settingsui.lua` in the band. This regenerates the `/wow-addon:bump-version` header line. |
| `CM-101` | optional | File a LibKa0s proposal for a counting `DebugChanged`. If it ships, move `KCM.DebugQuiet`'s three callers onto it and delete the host gate. |

## Already tracked elsewhere (no action from this audit)

- Peel `settings/Panel.lua` (#42) and `settings/Category.lua` (#43). These are the terminal states
  for the two band files that have been carried as Accepted for three releases, and they are not
  findings in this run.
- #40: hydrate the item rows of a panel opened while disabled. This is an owner decision, recorded
  under Known Limitations.
