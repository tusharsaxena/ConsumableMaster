# 04 — Technical design

Remediation for the nine root deviations and two dependents in `02_DEVIATIONS.md`. Every item is
documentation, configuration or a mechanical text sweep; **no runtime code path changes**, so the
suite and lint stay the arbiter rather than the risk.

---

## CM-68 — write `docs/slash-dispatch.md`, correct the map row

**Files:** new `docs/slash-dispatch.md`; `docs/ARCHITECTURE.md:279`.

The trigger fired twice over. The doc is owed and its content already exists, scattered:
`settings/Slash.lua:84-192` is the top-level table, `core/SlashCommands.lua:418`, `:558`, `:729`,
`:782` are four sub-verb namespaces, `core/SlashDump.lua` is the fifth, and `settings/Slash.lua:257`
is the descriptor that binds them.

Shape:

1. **The dispatcher** — one instance from `LibStub("LibKa0s-Slash-1.0", true)`, the descriptor
   fields the addon supplies (`print`, `version`, `get`/`set`/`findRow`/`applyDefault`, `allRows`,
   `groupKey`, `aliases`, `STRINGS`), and the degradation stub.
2. **The verb table** — the 17 triples with their one-line descriptions, generated from
   `KCM.COMMANDS` so it cannot drift. `ARCHITECTURE.md` → `## Slash Commands` keeps its summary and
   gains **one** link here (the `documentation-§3` spill rule; that section is 7 lines today so
   nothing has to move).
3. **The five sub-verb trees** — `priority`, `stat`, `aio`, `bar`, `dump`: what each namespace holds,
   how `findCommand` resolves a sub-verb, and what an unknown sub-verb prints.
4. **The reserved verbs** — which of `help`/`get`/`set`/`list`/`reset`/`resetall`/`config`/`version`/
   `debug`/`perf` this addon registers, and that `reset` takes a **path**, not a page.

Then `docs/ARCHITECTURE.md:279` becomes:

```markdown
| `slash-dispatch.md` | Present | 17 verbs in `NS.COMMANDS`, and five subcommand trees |
```

**Risk:** none to runtime. The only trap is writing the verb table by hand and letting it drift —
derive it from `KCM.COMMANDS` in the same pass `wow-addon:sync-docs` uses for the README table.

## CM-69 — the US-English sweep

**Files:** the 13 named in `03_EVIDENCE.md`.

Mechanical, but **not** a blind `sed -i` over the tree, for two reasons the evidence already shows.
`docs/test-cases.md:455` is **generated** from `tests/test_mediasetup.lua:138`, so the source case
name is edited and the inventory regenerated — editing the doc directly would be undone by the next
run and would move the `[tests]` badge's provenance out of step. And the frozen directories
(`docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/revendor/`)
**MUST NOT** be swept: their spelling is part of what they recorded.

Substitutions: `colour→color`, `coloured→colored`, `greyed→grayed`, `cancelled→canceled`,
`licence→license`, `behaviourally→behaviorally`. `README.md:165` is the highest-value line — it
currently writes *colour* twice in a sentence describing a control literally labelled
**Use class color**.

**Risk:** a `colour` inside a shipped `L[...]` key would change the key. There is none — the sweep's
Lua hits are all comments and test-case names, confirmed by re-reading each in `03_EVIDENCE.md`.

## CM-70 — renormalize the working tree

**Files:** none authored; the index and the checkout.

```sh
git add .gitattributes        # already correct and byte-identical to line-endings-§5
git add --renormalize .
git status                    # review, then commit
```

`--renormalize` rewrites the **index**, not files already on disk, so any file still disagreeing is
deleted and re-checked-out (`rm <path> && git checkout -- <path>`), exactly as the repo's own
`.gitattributes:74-84` recipe says. Confirm with the `line-endings-§7` counter reading `0`.

**Risk:** a large diff touching many files with no content change. Land it as its **own commit** so
the next `git log -p` reader is not hunting for a real change inside it, and land it **after** CM-69
so the spelling sweep does not have to be re-normalized twice.

## CM-71 — retire the stale register row

**File:** `docs/ARCHITECTURE.md:316`.

Delete the `toc-file-§5` row. `toc-file-§5` at v2.38.0 makes the within-section sequence illustrative
and says explicitly that a TOC comment makes it *"compliant and needs no deviation-register row"*.
The TOC carries those comments (`ConsumableMaster.toc`, the block above `core\Namespace.lua` and the
one above `core\PerfSetup.lua`), so nothing is lost by deletion — the rationale stays where the rule
now puts it.

Nothing else in the register moves: the other three rows' triggers have not fired and they stay.

**Risk:** deleting a row reads as losing history. Mitigate by naming the retirement in the commit
message and in this bundle, which is where a reader looking for "what happened to that row" lands.

## CM-72 / CM-77 — refresh the automated-test record

**Files:** a new `docs/automated-tests/<stamp>/` bundle; `docs/automated-tests/RESULTS.md`.

```sh
tests/_kit/run-automated-tests.sh
```

The runner writes the bundle and prepends the row. Then, by hand (the watch list is prose the runner
does not own):

- re-anchor `RESULTS.md:109`'s *Current state as of* to the new stamp;
- rewrite the band table — `tests/test_macrobar.lua` at its real LOC in the over-cap row, and
  `settings/Category.lua`, `settings/Panel.lua`, `tests/test_settingsui.lua` in a real 1000–1500 row
  with a disposition each;
- write `ANALYSIS.md` for the new bundle, and back-fill the two bundles that have none
  (**CM-77**) — or state in `RESULTS.md` that those two are green non-release runs whose write-up
  was skipped under `automated-tests-§5`'s SHOULD, which is also an honest close.

**Ordering:** this **MUST** run last of everything in this plan, because CM-69 and CM-70 both change
line counts and file bytes. A bundle produced before them is stale on the day it is written.

## CM-73 — the over-cap test file

**File:** `tests/test_macrobar.lua` (1894 LOC).

Two acceptable outcomes; the first is cheaper.

**(a) Peel.** The file already has natural seams matching the modules it covers. Split into
`tests/test_macrobar.lua` (the bar frame, lock, visibility, repaint), `tests/test_macrobar_flyout.lua`
and `tests/test_macrobar_button.lua`, add the two new suites to `tests/run.lua`'s list, and confirm
the total case count is unchanged (749) so the split is provably behavior-preserving. Avg CCN is 1.3,
so this is case count and not tangle — there is no function to untangle and nothing to characterize
first (`testing-§13` does not bite).

**(b) Track it.** Open a `state:triaged` issue with `severity:low` and an owner, add a
`## Documented deviations` row citing `layout-§1` with the re-check trigger *"the file is peeled, or
`layout-§1` exempts test files from the cap"*, and cite the issue in the watch list's disposition.

**Risk in (a):** a suite list that silently drops a file. Guard it by asserting the total case count
before and after, and by `tests/test_runner_list.lua`, which already exists for this.

## CM-74 — restore the compliant `RESULTS.md` lead-in

**File:** `docs/automated-tests/RESULTS.md:9-11`.

Replace those three lines with the four paragraphs the vendored kit emits at
`tests/_kit/run-automated-tests.sh:425-433`, verbatim — the `lint`/`tests` sentence, the
`perf`/`complexity` sentence, the **tag** paragraph, and the `skip` / `—` paragraph. This is the one
place in the file a human may edit: the runner only writes the lead-in when it **creates** the file,
so leaving it alone means it is never fixed.

Do **not** hand-edit the table. `automated-tests-§4` makes the rows generated, and a hand-written row
reads as measured.

**Risk:** the header line must stay byte-identical or the runner's `grep -qF "$HEADER"` guard fails
and it prints *"older column set — not touching it"* and drops the next row silently. Only touch
lines above the table.

## CM-75 — expand the bare `§N` citations

**Files:** the eight code comments and five docs named in `03_EVIDENCE.md`.

Most are one-token edits whose anchor is in the same clause, but **resolve each against the standard
before expanding it** — one of them is already wrong. `settings/Category.lua:156` and
`modules/MacroManager.lua:331` both read *"the standard §12 zero-alloc rule these paths are written
to"*; the zero-allocation rule is **`debug-logging-§4`** (*"it is zero-allocation when off: the gate
is the first thing it does, before any `string.format`, concat, or table build"*), restated at
`debug-logging-§9`. There is no §12 that says it. So this pair is not a formatting fix — it is a
citation that sends the reader to the wrong place and looks current doing it, which is exactly why
`documentation-§6` grades a malformed reference above the retired dotted form.

An expansion to the wrong section is a worse defect than the bare number. Where a reference turns
out to name a section that no longer exists, delete the citation and describe the rule in words.

`docs/smoke-tests.md` is **out of scope**: its `§N` are its own section numbers.

**Risk:** exactly the one above. Budget reading time per site rather than treating this as a sweep.

## CM-76 — one line in `.pkgmeta`

**File:** `.pkgmeta`.

Add `  - _dev` beside `  - tests`. Nothing else in the file moves.

## CM-78 — upstream, not here

**Repo:** `LibKa0s`, `testkit/run-automated-tests.sh`.

`automated-tests-§4` requires the `tests` column to carry **passed / skipped / total** and the
manifest to record `skipped`. The runner emits `$TESTS_PASS/$TESTS_TOTAL` at `:388` and writes no
`skipped` field at `:369`. The parse at `:195` already matches
`'[0-9]+ passed, [0-9]+ failed(, [0-9]+ total)?'` and would need a third capture for the harness's
`0 skipped`.

This is a **libka0s-upstream** change plus a re-vendor in every consumer, and it is **not** in this
addon's remediation scope. File it as an issue on `LibKa0s`; note here that the column shape is a
known upstream gap so the next audit of this repo does not re-file it as an addon defect. Adding the
column changes `$HEADER`, which triggers the runner's *"older column set"* refusal — so the upstream
change must also carry a migration note telling consumers to rewrite the header row once.

---

## Ordering constraints

1. **CM-69 before CM-70.** The spelling sweep edits bytes; renormalize once, afterwards.
2. **CM-73(a) before CM-72.** A peel changes the LOC table the record is about.
3. **CM-72 last.** Every other item changes something the bundle measures.
4. **CM-68, CM-71, CM-74, CM-75, CM-76 are independent** of each other and of the above.
5. **CM-78 does not gate anything here** — it is another repo's work.

## Verification

After each step: `luacheck .` (0/0) and `lua tests/run.lua` (749/749, or the same total after a
CM-73(a) split). After CM-70, the `line-endings-§7` counter must read `0`. After CM-69, regenerate
`docs/test-cases.md` and check the README `[tests]` badge still matches. After everything, one full
`tests/_kit/run-automated-tests.sh` producing the CM-72 bundle.
