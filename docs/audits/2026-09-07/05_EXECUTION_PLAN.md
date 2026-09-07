# 05 — Execution plan

Hand-off to the remediation engagement. Nine root deviations and two dependents, **11 items total**,
**9 in the headline tally** — the basis is roots only, dependents excluded per `AUDIT.md` step 5.
Nothing here is High or Medium; nothing is user-reachable. This is a tidy-up sprint, not a repair.

The gate after every step is unchanged: `lua tests/run.lua` green and `luacheck .` clean, per
`testing-§4`. Commit on green units of work, trunk-based, no branch unless asked
(`versioning-git`).

---

## Sprint 1 — the documentation debt (CM-68, CM-71, CM-75)

Independent of each other; do them in whatever order suits. None touches runtime code.

| # | Step | ID | Done when |
|---|---|---|---|
| 1.1 | Write `docs/slash-dispatch.md`: the dispatcher and its descriptor, the 17-verb table derived from `KCM.COMMANDS`, the five sub-verb namespaces (`priority`, `stat`, `aio`, `bar`, `dump`), and which reserved verbs this addon registers. | CM-68 | The file exists and its verb table matches `settings/Slash.lua:84-192` row for row. |
| 1.2 | Change `docs/ARCHITECTURE.md:279` to `` | `slash-dispatch.md` | Present | 17 verbs in `NS.COMMANDS`, and five subcommand trees | ``. | CM-68 | The map row reads `Present`; no *Not applicable* row in the repo asserts something the code contradicts. |
| 1.3 | Add the one link from `ARCHITECTURE.md` → `## Slash Commands` to the new doc. The section is 7 lines, so nothing spills. | CM-68 | `documentation-§3`'s spill rule satisfied by summary + exactly one link. |
| 1.4 | Delete the `toc-file-§5` row at `docs/ARCHITECTURE.md:316`. Say why in the commit message: the standard changed at v2.38.0 and the TOC comments are now the sanctioned home. | CM-71 | The register holds three rows, all with unfired triggers. |
| 1.5 | Expand each bare `§N` in the eight code comments and five docs listed in `03_EVIDENCE.md`. **Resolve each against the standard before expanding** — the `§12` in `settings/Category.lua:156` and `modules/MacroManager.lua:331` in particular. Leave `docs/smoke-tests.md` alone. | CM-75 | `grep -rEno '[A-Za-z0-9_-]*§[0-9]+'` over live authored files returns only `filename-§N` forms (excluding `smoke-tests.md`'s own numbering and the frozen directories). |

**Gate:** `luacheck .` 0/0, `lua tests/run.lua` 749/749. Commit.

## Sprint 2 — configuration (CM-76, CM-74)

| # | Step | ID | Done when |
|---|---|---|---|
| 2.1 | Add `  - _dev` to `.pkgmeta`'s `ignore:` list beside `  - tests`. | CM-76 | The `AUDIT.md` packaging loop prints nothing for `_dev`. |
| 2.2 | Replace `docs/automated-tests/RESULTS.md:9-11` with the four paragraphs `tests/_kit/run-automated-tests.sh:425-433` emits, verbatim: the `lint`/`tests` sentence, the `perf`/`complexity` sentence, the **tag** paragraph, the `skip` / `—` paragraph. **Do not touch the table or its header row** — the runner's `grep -qF "$HEADER"` guard depends on it byte-for-byte. | CM-74 | The lead-in names three checkpoints (run, commit, tag) and the CCN-15 release condition. |

**Gate:** same. Commit.

## Sprint 3 — the US-English sweep (CM-69)

| # | Step | ID | Done when |
|---|---|---|---|
| 3.1 | Fix the two player-facing lines first: `README.md:138` (*greyed*) and `README.md:165` (*colour* ×2, in a sentence about a control labelled **Use class color**). | CM-69 | |
| 3.2 | Fix `CLAUDE.md:69`, `docs/schema.md`, `docs/settings-panel.md`, `docs/smoke-tests.md`, `docs/module-map.md`, `docs/perf-analysis/README.md`. | CM-69 | |
| 3.3 | Fix the code comments: `settings/Category.lua:720`, `settings/StatPriority.lua:430`, `tests/test_settingsui.lua:415`, `tests/test_itemsetup.lua:16`. | CM-69 | |
| 3.4 | Rename the case at `tests/test_mediasetup.lua:138` (*licence* → *license*) and **regenerate** `docs/test-cases.md`. Do not hand-edit `:455`. | CM-69 | `docs/test-cases.md` is regenerated, the case count is still 749, and the README `[tests]` badge still reads `749/749`. |
| 3.5 | Do **not** sweep `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/revendor/` or `libs/`. | CM-69 | The frozen record is byte-unchanged. |

**Done when:** the `03_EVIDENCE.md` British-spelling command, at the same scope, returns **0**.
**Gate:** same. Commit.

## Sprint 4 — line endings (CM-70)

Its **own commit**, after Sprint 3, so the renormalization diff carries nothing else.

| # | Step | ID | Done when |
|---|---|---|---|
| 4.1 | `git add .gitattributes && git add --renormalize . && git status` — review, then commit. | CM-70 | |
| 4.2 | For any file still disagreeing on disk: `rm <path> && git checkout -- <path>`, per `.gitattributes:74-84`. | CM-70 | |
| 4.3 | Re-run the `line-endings-§7` counter from `03_EVIDENCE.md`. | CM-70 | It prints **0**, down from **7**. |

**Gate:** same. Commit.

## Sprint 5 — the over-cap test file (CM-73)

Route (a) is recommended. Pick one and record which.

| # | Step | ID | Done when |
|---|---|---|---|
| 5.1a | Split `tests/test_macrobar.lua` (1894 LOC) into `test_macrobar.lua` + `test_macrobar_flyout.lua` + `test_macrobar_button.lua`, each under 1000. | CM-73 | Every new file is under the `layout-§1` cap. |
| 5.2a | Register the two new suites in `tests/run.lua`'s list. | CM-73 | `tests/test_runner_list.lua` passes. |
| 5.3a | Assert the split is behavior-preserving: the total case count is **unchanged**. | CM-73 | `lua tests/run.lua` reports the same total as before the split. |
| 5.1b | *(Alternative)* Open a `state:triaged` / `severity:low` issue with an owner, add a `## Documented deviations` row citing `layout-§1` with a re-check trigger, and cite the issue number in the `RESULTS.md` band-table disposition. | CM-73 | The watch-list entry names a tracker instead of reading *"still unowned"*. |

**Gate:** same. Commit.

## Sprint 6 — refresh the record (CM-72, CM-77)

**Runs last.** Every sprint above changes something this bundle measures.

| # | Step | ID | Done when |
|---|---|---|---|
| 6.1 | `tests/_kit/run-automated-tests.sh` — full four-suite run; the runner writes the bundle and prepends the row. | CM-72 | A new `docs/automated-tests/<stamp>/` exists with all seven artifacts and `RESULTS.md` has a new top row. |
| 6.2 | Re-anchor `RESULTS.md:109`'s *Current state as of* to the new stamp. | CM-72 | |
| 6.3 | Rewrite the band table: the real over-cap state after CM-73, and a real 1000–1500 row for `settings/Category.lua`, `settings/Panel.lua` and `tests/test_settingsui.lua`, each with a one-line disposition. Anything that **newly** crossed says so. | CM-72 | No row in the table disagrees with `wc -l` on the tree. |
| 6.4 | Write `ANALYSIS.md` for the new bundle, per `AUTOMATED_TESTS.md`'s prompt. | CM-77 | |
| 6.5 | Back-fill `ANALYSIS.md` for `20260825-103407` and `20260807-110619`, **or** record in `RESULTS.md` that both are green non-release runs whose write-up was skipped under `automated-tests-§5`'s SHOULD. Either closes it; do not leave it silent. | CM-77 | Every bundle either carries an `ANALYSIS.md` or is accounted for in one sentence. |

**Gate:** same. Commit.

## Out of scope for this engagement — CM-78

`automated-tests-§4`'s passed **/ skipped /** total column is a defect in the vendored runner
(`tests/_kit/run-automated-tests.sh:388`, `:369`), not in this addon. `library-stack-§7` makes
`libs/` and `tests/_kit/` read-only, so it **MUST NOT** be patched here.

Action: file an issue on `LibKa0s` describing the column and the manifest field, noting that the
change moves `$HEADER` and therefore needs a consumer-side migration note. Re-vendor every consumer
when it lands. Record here that the next audit of this repo should read the column as a known
upstream gap rather than an addon defect.

---

## Recap

| Sprint | IDs | Nature | Runtime risk |
|---|---|---|---|
| 1 | CM-68, CM-71, CM-75 | docs | none |
| 2 | CM-76, CM-74 | config / record prose | none |
| 3 | CM-69 | text sweep + one regenerated doc | none |
| 4 | CM-70 | line endings | none |
| 5 | CM-73 | test-file split | test-suite only |
| 6 | CM-72, CM-77 | record refresh | none |
| — | CM-78 | upstream `LibKa0s` | n/a |
