Delta: LibKa0s v1.65.0 -> v1.66.0

Run non-interactively as item GI-CM-RV of the 2026-10-01 GitHub issue pass
(`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`, spec S4), on branch
`feat/2026-10-01-github-issue-pass`. Steps 2-4 of `revendor-libka0s`: resolve the tag, read the
delta, copy both payloads whole, roll the provenance line. The adoption interview (Steps 5-6) is not
run this cycle and no issue is filed: candidates are listed in `02_CANDIDATES.md` for the
collection census (GI-LK-13). Written before the copy.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.66.0^{commit}'   # e4c5ef7 (annotated tag object 178ee0b)
git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/v166/
git -C ../LibKa0s archive v1.65.0 LibKa0s testkit | tar -x -C <scratch>/v165/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed yet (the plan pushes it with the owner's merge go-ahead).

## Base (3a, 3b)

```sh
grep -n '[Bb]undles' CLAUDE.md
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.65.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # 21cee68
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.65.0
diff -rq <scratch>/v165/LibKa0s libs/LibKa0s && diff -rq <scratch>/v165/testkit tests/_kit && echo payload-matches-base
# payload-matches-base
```

Base v1.65.0, agreed by the line, the last payload commit and the bytes. The newest earlier
single-tag bundle (`2026-09-29-v1.63.0`) states base v1.62.0 for its own run, which matches the
provenance before `7068c84`, so no correction is owed. v1.64.0 and v1.65.0 were vendored with no
bundle; see 3h.

## Range

```sh
git -C ../LibKa0s log --oneline v1.65.0..v1.66.0 | wc -l    # 24 commits
git -C ../LibKa0s diff --stat v1.65.0 v1.66.0 -- LibKa0s testkit
#  20 files changed, 2693 insertions(+), 1651 deletions(-)
```

## Per-file minor delta (3c)

Every file in the tag's `LibKa0s/LibKa0s.xml`, old against new by its own `[A-Z_]*MINOR` constant;
only the rows that moved (an empty Old is a file new in this range):

| File | Old | New |
|---|---|---|
| `Widgets.lua` | `LibKa0s-Widgets-1.0` 11 | `LibKa0s-Widgets-1.0` 12 |
| `WidgetsReorder.lua` | | `REORDER_MINOR` 1 |
| `DebugLog.lua` | `LibKa0s-DebugLog-1.0` 18 | `LibKa0s-DebugLog-1.0` 19 |
| `Slash.lua` | `LibKa0s-Slash-1.0` 18 | `LibKa0s-Slash-1.0` 19 |
| `SlashParse.lua` | | `PARSE_MINOR` 1 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` 33 | `WIDGETS_MINOR` 34 |
| `OptionsTabs.lua` | `TABS_MINOR` 7 | `TABS_MINOR` 8 |
| `Perf.lua` | `LibKa0s-Perf-1.0` 13 | `LibKa0s-Perf-1.0` 14 |
| `PerfSampler.lua` | | `SAMPLER_MINOR` 1 |
| `PerfCommands.lua` | | `COMMANDS_MINOR` 1 |

Four files are added, none removed; no `NEEDS_*` floor rises (CHANGELOG v1.66.0 version block). The
TOC loads the library through `libs\LibKa0s\LibKa0s.xml` alone and `tests/run.lua` derives its
load list from the same XML (`Loader.xmlFiles`), so the four new files need no TOC or harness row.

## Both diffs (3d), before the copy

```sh
diff -rq <scratch>/v166/LibKa0s libs/LibKa0s
# differ: DebugLog.lua LibKa0s.xml OptionsTabs.lua OptionsWidgets.lua Perf.lua Slash.lua Widgets.lua
# Only in <scratch>/v166/LibKa0s: PerfCommands.lua PerfSampler.lua SlashParse.lua WidgetsReorder.lua
diff -rq <scratch>/v166/testkit tests/_kit
# differ: README.md asserts.lua framework.lua inventory.lua mock_base.lua run-automated-tests.sh test_eol.lua
# Only in <scratch>/v166/testkit: lizard_sighted.lua test_lizard_sighted.lua
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing to delete.

## Consumption map (3e)

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: Bus, Compat,
Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Slash and
Widgets. The moved majors (Widgets, DebugLog, Slash, Options, Perf) are all consumed.

## Kit revision (3f)

```sh
grep -n 'Kit.VERSION =' <scratch>/v166/testkit/framework.lua tests/_kit/framework.lua
# new: Kit.VERSION = 35   old: Kit.VERSION = 34
```

Kit 35 adds `lizard_sighted.lua` and a fifth kit suite, `test_lizard_sighted.lua`, which
`Kit.assertSuiteInventory` fails the run on until it is wired in `tests/run.lua`. Both payloads are
copied whole, which is the pairing rule by construction.

## Contract delta (3g)

No blocker. Read against each moved, consumed major's version document at the tag:

- **Slash 19.1** (`docs/api/Slash/version-19.1-docs.md`, "What changed at this version"): the
  instance hands `Sl:Text` to the default parse and to a host's own `parse` as a third argument. This
  addon's descriptor `parse` (`settings/Slash.lua`, `parseValue`) takes two arguments and calls
  `slashLib.ParseValue(row, text)`, so the copy alone changes nothing it prints; the three host `L`
  overrides it marks dead (`ERR_BOOL`, `ERR_ALLOWED`, `ERR_COLOR`) stay unreached until the host
  passes the resolver on, which is GI-CM-01 (ConsumableMaster#16). A host `format` "replaces
  `lib.FormatValue` outright and is called exactly as before".
- **Widgets 12.1.3**: `ReorderList` moved unchanged to `WidgetsReorder.lua`; no member, `opts`
  field or controller method moves.
- **Options (OptionsWidgets 34, OptionsTabs 8)**: `RenderGrid(ctx, items, parent, opts)` keeps the
  two-argument behavior; a failed wide item and a `make` answering exactly `false` now take no
  space. This addon's grid rows (`settings/Panel.lua` `Helpers.Grid`) answer widgets or nil, never
  `false`. The three `RenderTabbedSchema` fields are opt-in.
- **Perf 14.1.1.6**: capture and command surface peeled to two secondary files, no member moves;
  `BuildRecord` now emits a declared ancestor that never fired (additive within schema 2); budgets
  are opt-in.
- **DebugLog 19.2.1**: `lib:New`'s refusals and defaults hoisted to file-level helpers, no member,
  field, default or string moves.

`grep -rn '__Attach'` outside `libs/` and `tests/_kit/` finds no host call site.

## Span back-fill (3h)

The audit's walk over `libs/LibKa0s`, `tests/_kit` and the `CLAUDE.md` provenance rolls since the
store's first bundle (2026-08-25), less the tags the store already records:

```
v1.64.0
v1.65.0
```

Both were carried by sweeps (`5100d9b` / `bf8afd9` DL-CM-01/03, and `21cee68` DG-CM-01) with no
bundle. The span bundle `docs/revendor/2026-10-01-v1.64.0-v1.65.0/` is written in this run.
