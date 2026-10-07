# 04 — Technical design: Ka0s Consumable Master (2026-10-07)

Every open finding is a doc, comment, TOC-comment or record fix. **No runtime Lua behavior changes.**
The only `.lua` edits are comments (`CM-75`, `CM-98`). The green gate (`lua5.1 tests/run.lua`,
`luacheck .`) needs to stay green and needs no new case. The kit's `test_prose` gate must still pass
over every edited `.md` file.

## Ordering constraints

1. **`CM-97` before `CM-99`.** Both edit `docs/ARCHITECTURE.md`. `CM-99` rewrites two register rows
   in the same file whose event table and writer citations `CM-97` re-points. Do them in one pass, or
   in this order, so that one diff carries both changes.
2. **`CM-98` and `CM-83` are one TOC edit.** Both touch only comment lines in `ConsumableMaster.toc`.
   Add no file line and move none: `layout-§1`/`toc-file-§5` forbid moving an annotated line without
   reading its comment, and nothing here needs a move.
3. **`CM-91` is independent.** It writes a new folder under `docs/revendor/`. It may land in the same
   commit as the next re-vendor, or alone.
4. **`CM-95` and `CM-101` need no local work.** `CM-95` clears itself at the next release run, and
   `CM-101` is an optional upstream proposal.

## CM-91 — re-vendor span bundle

Create `docs/revendor/2026-10-07-v1.68.1-v1.70.0/` in the store's existing shape, copying the
`01_DELTA.md` / `02_…` layout of the `2026-10-04-v1.68.1` bundle. Line 1 of `01_DELTA.md` **MUST**
read:

```
Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)
```

`AUDIT.md`'s span branch reads every tag on that line. The content records what each tag changed,
read from `git -C ../LibKa0s log v1.68.1..v1.70.0` and the payload diff:

- v1.69.0 adds `WidgetsLineChart.lua` and moves the kit to revision 37.
- v1.70.0 adds `WidgetsAutocomplete.lua`.

It also records that this addon calls neither new surface. Its `Widgets` use is `ReorderList` and
`DragHandle`, so the adoption verdict is "nothing to adopt". **Do not** back-fill a folder per tag.

**Verify:** re-run `AUDIT.md`'s re-vendor check. `UNRECORDED:` should print nothing.

## CM-97 — doc sync

Run `/dev-copilot:sync-docs`. The two changes it must make are below, and it should catch any others
of the same shape.

- **`docs/ARCHITECTURE.md` *Event Subscriptions* table (`:168-177`).** Either re-point the ten
  citations to the current handler lines (740, 762, 767, 778, 836, 857, 865, 756 twice, 824), or,
  preferably, **drop the line numbers**. Each row already names its handler (`OnRegenEnabled`), and
  `grep -n 'function KCM:OnRegenEnabled'` finds it. The line suffix is the part that drifts every
  time the file grows. The standard does not require line numbers in that table.
- **`docs/ARCHITECTURE.md` `:102`, `:122-124`.** Re-point the `RegisterProfileCallbacks` range to
  `:558-621` and the single reference to `:558`, and change `:814` to `:824`. Re-point the
  `macroState` writer citations: `commitMacro` to `:498` with its write at `:531`, the lazy create to
  `:512`, `InvalidateState` to `:737` with its write at `:744`, and `MarkAllStale` to `:760`. These
  stay cited by line, because `architecture-§5`'s naming sentence names each writer function and a
  line anchor is what an auditor resolves. Keep the function name in front of every number so that
  the next drift is still legible.
- **`docs/perf-analysis/README.md:133`.** Change `/wow-addon:perf-analysis` to
  `/dev-copilot:wow-perf-analysis`. Leave `docs/automated-tests/RESULTS.md:15` alone: it is
  generated, and the next run rewrites it (`CM-95`).

**Risk:** none at runtime. Re-run `test_prose` (it is part of `tests/run.lua`) after the edit.

## CM-98 — annotate SlashDump's load-bearing position

Change `ConsumableMaster.toc:97-99` (the CoreSetup comment) to name both file-scope consumers:

```
# CoreSetup builds KCM.Say / KCM.SafeToString from LibKa0s-Core-1.0. It has to
# sit after Constants.lua (KCM.PREFIX) and before core\SlashDump.lua and
# core\SlashCommands.lua, both of which take the printer as a file-scope upvalue.
```

Correct `core/SlashDump.lua:15` to `-- Same secret-safe seam as every other chat line (core/CoreSetup.lua).`
This is a comment-only change to a `.lua` file, so luacheck and the suite are unaffected.

Alternative, declined: make `say` a call-time thunk (`local function say(...) return KCM.Say(...) end`)
so that the position becomes conventional. It changes code to satisfy a comment rule, and
`core/SlashCommands.lua:34` has the same shape, so the two should stay alike.

## CM-99 — make the register's evidence ids resolve

Edit the *Why* cells only. The decisions, the Decided dates and the triggers do not change, because
`audit-review-history` treats a citation fix as a doc change, not a re-decision.

- `docs/ARCHITECTURE.md:376` (`compat`). Replace *"Review findings `CM-R-10` and `CM-R-05`"* with
  *"review findings F-010 (`docs/reviews/2026-08-05/`) and F-005 (`docs/reviews/2026-09-23/`)"*. Keep
  `CM-63` and `CM-96`, which resolve.
- `docs/ARCHITECTURE.md:377` (`options-ui-§1`). Replace *"(CM-18, WS-02 ruling)"* in the Decided cell
  with a pointer that resolves in this repo: the 2026-09-23 audit/review bundles, issue #39 (the
  Schema adoption whose library-absent build this row is about), or both. If the cross-repo plan item
  is worth keeping, cite it by its full path,
  `Ka0sAddonsCommonTasks/docs/2026-09-23-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/items.tsv` item
  `CM-18`, so that it cannot be mistaken for this repo's July `CM-18`.

**Prevention:** review findings in this repo use `F-NNN` and audit findings use `CM-NN`. A `CM-R-NN`
id was minted by a consolidation outside the repo. The register should cite only ids minted in this
repo.

## CM-100 — quote the sighted command in the gate table

In `docs/testing.md:283`, set the `complexity` row's *Command* cell to
`bash tests/_kit/run-automated-tests.sh --suite complexity`. Move the raw invocation into a sentence
under the table, for example: *"Inside the shadow the runner executes the fixed invocation
`lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .` (performance-§10). Never run it over the
tree by hand: `lizard` alone is blind in Lua (automated-tests-§3)."* This makes the table agree with
`CLAUDE.md:107` and `DEPENDENCIES.md:134`.

## CM-75 — three bare `§N`

- `modules/MacroManager.lua:709`: change `§9's` to `debug-logging-§9's`.
- `tests/run.lua:477`: change `debug-logging-§8/§9` to `debug-logging-§8/debug-logging-§9`.
- `tests/test_debugcoverage.lua:2`: change `§9's` to `debug-logging-§9's`.

These are comments only.

## CM-83 — mark `# Defaults`' conventional positions

Add one group note after the `Profile.lua` comment (`ConsumableMaster.toc:151-155`), above
`defaults\Categories.lua`:

```
# The seed files below are conventional: each reaches KCM.ID (core) and its own
# `KCM.SEED = KCM.SEED or {}` table, so their order within the group is free.
```

Confirm the claim before writing it. `defaults/Categories.lua` builds `KCM.Categories.LIST`, and
the `Defaults_*` files must not read it at file scope. A spot-check of `defaults/Defaults_Food.lua`
found only `KCM.SEED` and `KCM.ID`. If any seed file does read `KCM.Categories` at load, annotate
Categories.lua as load-bearing instead.

## CM-95 — nothing now

At the next release: run the full bundle (`bash tests/_kit/run-automated-tests.sh`). It is the first
sighted run. Read `manifest.json` → `suites.complexity.blindFiles` (it must be 0). Rule on any
function listed at the CCN 15 ceiling as *newly measured*. Disposition the two new band entrants
(`tests/wow_mock.lua`, `tests/test_settingsui.lua`).

## CM-101 — optional, upstream

If the collection wants it, file a LibKa0s issue proposing that `DebugChanged` take a summary key
separate from the logged line and return the count of held passes. `KCM.DebugQuiet` and its three
callers would then move onto it and the host gate would be deleted. No ConsumableMaster change is owed
until then.
