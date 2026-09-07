# 02 — Deviations

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit:** 2026-09-07 · **Standard:**
**v2.38.0 (2026-09-02)**

IDs are **stable**. Every ID up to `CM-67` has been used in a prior run or is cited in the deviation
register; new IDs therefore start at **CM-68** and retired IDs are never re-purposed. No deviation
from the 2026-08-05 run survives — all of them were closed by the LibKa0s adoption and
settings-revamp work, or ratified into the register.

**Grading is impact, not rule strength** (`AUDIT.md` step 5). A doc-only or config-only failure is
**Low** even where the rule it fails is a MUST, and each entry names that MUST anyway.

## Tally

| | Count |
|---|---|
| **Headline (root deviations only)** | **9** |
| **Total including `derived from` dependents** | **11** |
| High | 0 |
| Medium | 0 |
| Low | 9 roots (11 with dependents) |
| Info | 0 |
| **MUST failures — roots only** | **7** |
| **MUST failures — including dependents** | **8** |

Nothing in this run is reachable by a user, their SavedVariables or their session. There is no High
or Medium row, and that is a measurement rather than a courtesy: `luacheck .` is clean, the headless
suite is 749/749, both vendored-payload diffs are empty, every seam has a degradation branch pinned
by `tests/test_surface_parity.lua`, and the panel passes all nine `options-ui` content checks.

---

## Root deviations

| ID | Section (`filename-§N`) | Grade | Strength | Deviation | Fix direction |
|----|-------------------------|-------|----------|-----------|---------------|
| **CM-68** | `documentation-§3` (Tier 2) | Low | **MUST** | **`docs/slash-dispatch.md` is absent and the `## Documentation map` asserts a false *Not applicable*.** `docs/ARCHITECTURE.md:279` reads *"17 verbs, but they are a flat set with no subcommand tree"*. Both halves of the trigger have fired: `settings/Slash.lua:84` declares 17 commands (≥ 8), and five of them dispatch sub-verb tables (`core/SlashCommands.lua:418, 558, 729, 782` and `core/SlashDump.lua`). `AUDIT.md` step 4(b) grades a false *Not applicable* **above** a bare omission, because the row asserts something untrue. | Write `docs/slash-dispatch.md` — the verb table, the five sub-verb namespaces and how the descriptor reaches them — and change the map row to `Present` with the real trigger (*17 verbs and five subcommand trees*). |
| **CM-69** | `localization-§5`, anti-pattern #46 | Low | **MUST** | **British spelling in authored English text — 28 sites across 13 files**, including player-facing README prose (`README.md:138` *"greyed"*, `:165` *"colour"* ×2), a test-case **name** that propagates into the generated `docs/test-cases.md:455` (*"licence"*), and code comments (`settings/StatPriority.lua:430` *"Greyed"*, `settings/Category.lua:720` *"cancelled"*). Command and scope in `03_EVIDENCE.md`. | One sweep over the 13 files. `colour→color`, `greyed→grayed`, `cancelled→canceled`, `licence→license`, `behaviourally→behaviorally`. Renaming the `test_mediasetup.lua:138` case regenerates `docs/test-cases.md`, so re-run the inventory in the same change. |
| **CM-70** | `line-endings-§1`, `line-endings-§6` | Low | **MUST** | **7 tracked files disagree with the declared CRLF pin in the working tree.** `.gitattributes` itself is byte-identical to `line-endings-§5`'s canonical client-bound body, so this is the unrenormalized-tree half of the rule, not a config error. Reported as **one** finding with its command, never a file list — the fix is one action. | `git add --renormalize .`, review, commit; then `rm` + `git checkout --` any file still wrong on disk. Re-run the `line-endings-§7` counter to confirm `0`. |
| **CM-71** | `documentation-§3` (*MUST NOT be a graveyard*) | Low | **MUST** | **The `toc-file-§5` register row cites a rule the standard has since changed.** `docs/ARCHITECTURE.md:316` records the within-`core/` sequence as an accepted deviation. `toc-file-§5` at v2.38.0 states the within-section sequence is *illustrative, not normative*, and that with a TOC comment present *"the ordering is compliant and needs no deviation-register row."* The TOC carries those comments. The row now records compliance as deviation, which is the graveyard the register forbids. | Delete the row. The rationale it holds is already in the TOC comments, which is where `toc-file-§5` puts it. Note the retirement in the next run's `05_EXECUTION_PLAN.md` so the history is legible. |
| **CM-72** | `automated-tests-§4`, `performance-§10`, anti-pattern #51 | Low | SHOULD (record freshness) | **The complexity watch list is stale against both the newest bundle and the current tree.** `docs/automated-tests/RESULTS.md:109` says *"Current state as of `20260807-114612`"* while the newest bundle in the table is `20260825-103407`. Its band table (`:155`) records `tests/test_macrobar.lua` at **1688** LOC; the file is **1894** today. Its 1000–1500 row reads **None**; three files sit in that band today. Today's `lizard` reads 17632 NLOC / 1888 functions against the bundle's 15870 / 1703. | Run `tests/_kit/run-automated-tests.sh` to produce a bundle for the post-revamp tree and let the runner regenerate the row; then re-write the watch list's two tables and re-anchor the *Current state as of* line. The checkpoint is the **release**, so this is a release-process item, not a commit gate. |
| **CM-73** | `layout-§1` | Low | **MUST** | **`tests/test_macrobar.lua` is 1894 LOC, over the 1500 cap**, and has been over it across four recorded bundles. `RESULTS.md:155` already states it is *"owed a fix or a tracked deviation ID with an owner — still unowned"*, and a check of all 31 issues finds nothing tracking it. | Peel into 2–3 siblings in the same folder along the seams the file already has (`test_macrobar_layout.lua`, `test_macrobar_flyout.lua`, `test_macrobar_button.lua`) and add them to the runner's suite list — or open a `state:triaged` issue with an owner and a register row. Peeling is cheaper; the file is case count, not tangle (avg CCN 1.3). |
| **CM-74** | `automated-tests-§4` (*the generated lead-in MUST name the checkpoint*) | Low | **MUST** | **`docs/automated-tests/RESULTS.md`'s lead-in names two checkpoints, not three.** `:9-11` reads *"`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run"* and never mentions the **tag** gate — all four suites at `pass` plus zero functions above CCN 15. This is the exact half-truth `automated-tests-§4` was amended to end. The vendored kit emits the compliant lead-in **only when it creates the file**, so `RESULTS.md` will keep the old text forever unless it is replaced. | Replace the lead-in with the four paragraphs `tests/_kit/run-automated-tests.sh:425-433` emits, verbatim. Do not hand-edit the table; only the prose above it. |
| **CM-75** | `documentation-§5`, `documentation-§6` | Low | **MUST** (malformed reference) | **Bare `§N` citations that do not parse as `filename-§N`** in authored code comments and docs: `settings/Category.lua:156`, `settings/General.lua:20`, `settings/Panel.lua:690`, `:724`, `settings/Slash.lua:112`, `settings/StatPriority.lua:6`, `:10`, `modules/MacroManager.lua:331`, plus continuation shorthand in `docs/ARCHITECTURE.md:191`, `docs/module-map.md:623-626`, `docs/settings-panel.md:74, 163, 251, 407`, `docs/debug.md:36`. The retired dotted `§N.M` form is **absent** (0 hits) — this is the other half of the same rule. One of the hits is not merely unanchored but **wrong**: `settings/Category.lua:156` and `modules/MacroManager.lua:331` both cite *"the standard §12 zero-alloc rule"*, which is `debug-logging-§4`. | Expand each to its full `filename-§N`. `smoke-tests.md`'s own internal section numbers (`§2`, `§3c`, …) are **not** in scope — they name that document's sections, not the standard's. |
| **CM-76** | `packaging` | Low | **MUST** (weak-form list) | **`_dev` is not in `.pkgmeta`'s `ignore:` list.** The named enumeration in `packaging` includes it. The strong-form check — every root dot-entry present in the repo is accounted for — **passes**: only `.git` is unaccounted, and the packager never sees it. `_dev/` does not exist in this repo today, so nothing ships because of this. | Add `  - _dev` to the ignore list beside `- tests`. One line. |

---

## Derived dependents (excluded from the headline tally)

| ID | Derived from | Section | Grade | Observation |
|----|--------------|---------|-------|-------------|
| **CM-77** | `derived from CM-72` | `automated-tests-§5` | Low | **Two run bundles carry no `ANALYSIS.md`** — `docs/automated-tests/20260825-103407/` and `docs/automated-tests/20260807-110619/`. `automated-tests-§5` makes the write-up a MUST **at release** and a SHOULD otherwise; neither bundle's `manifest.json` carries a `release` value, and both are `green`, so this is the SHOULD. It sits under CM-72 because both are the same act — the record for the current tree has not been produced and read. |
| **CM-78** | `derived from CM-74` | `automated-tests-§4` | Low | **The `Tests` column carries no `skipped` figure.** `RESULTS.md:15` reads `698/698`, and `automated-tests-§4` requires passed **/ skipped /** total. This is not the addon's to fix: `tests/_kit/run-automated-tests.sh:388` emits `$TESTS_PASS/$TESTS_TOTAL` and `:369` writes no `skipped` field into `manifest.json`. Scope is **libka0s-upstream** and it will be identical in every consumer. Listed under CM-74 because both are defects in the same generated file's shape. |

---

## Checks run and found compliant (not deviations)

Recorded so a later run does not re-open them.

- **Vendored payload.** `diff -r ../LibKa0s@v1.25.0/LibKa0s libs/LibKa0s` and
  `diff -r ../LibKa0s@v1.25.0/testkit tests/_kit` are both **empty**. Not anti-pattern #45 and not
  #48. The provenance line is in `CLAUDE.md` and absent from `README.md` (not #59, not #58).
- **`X-Curse-Project-ID`.** Present and real (`1522944`); the addon is published. Not #67.
- **`preview-mode`, `compat`, `localization-§4`.** Three ratified register rows, all dated
  2026-08-05, all carrying a re-check trigger, none of whose triggers have fired. Recorded as
  **accepted**, not re-filed.
- **`localization-§3`.** State 1 (*Routed*) — user-facing strings go through `KCM.L`. No
  English-only register row is owed.
- **`performance-§12`.** Does not apply: the harness is wired, `tests/perf.lua` ships, and
  `ConsumableMasterPerfDB` is declared. The addon is inside the rule's scope and compliant with it.
- **`architecture-§4`.** Above the threshold (ten feature modules, event registration) and the bus
  exists at `core/Bus.lua` with per-receiver targets.
- **A `state:will-not-do` issue with no register row.** Seven closed declines were read
  (#17, #18, #19, #26, #28, #30, #31). None declines a **standard rule**: #28/#30/#31 decline
  optional LibKa0s modules, which `library-stack-§7` makes per-addon and per-schedule; #17 declines
  an `X-Wago-ID` that `toc-file-§1` makes a MAY; the rest are engineering choices. No missing
  register row is owed.
- **`options-ui` (a)–(i).** All nine content checks pass; see `03_EVIDENCE.md`.
- **`packaging` strong form, `.gitattributes` body, `MakeCloseButton` grep, media duplication,
  `or`-defaulting sweep, combat-lockdown guards on the macro APIs.** All clean.
