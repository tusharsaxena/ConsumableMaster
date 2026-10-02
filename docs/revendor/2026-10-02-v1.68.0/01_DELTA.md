Delta: LibKa0s v1.67.0 -> v1.68.0

Run non-interactively as item TP-CM-01 of the 2026-10-02 LibKa0s tooltip-place re-vendor
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/00_PLAN.md`), on branch
`feat/2026-10-02-drag-attach`. The owner delegated every decision for this run; the reasoning for each
is recorded here and in `03_DECISIONS.md`. Written before the copy.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.68.0^{commit}'          # cc9f5eb (annotated tag object 6d83731)
git -C ../LibKa0s rev-parse --short HEAD                         # cc9f5eb
git -C ../LibKa0s diff --quiet v1.68.0 -- LibKa0s testkit && echo clean   # clean
git -C ../LibKa0s archive v1.68.0 LibKa0s testkit | tar -x -C <scratch>/new
```

The payload is taken from the tag through `git archive`. The tag is local to `../LibKa0s` and not
pushed yet (the plan pushes it with the owner's merge go-ahead).

## Pre-flight (Step 0, this addon)

```text
ConsumableMaster  2026-10-02-v1.67.0  base v1.66.0  vendored-before v1.66.0@326aa2e  ok
```

## Base (3a, 3b)

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.67.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# 326aa2e CA-CM-RV: re-vendor LibKa0s v1.67.0 (Core 10, Options 28, OptionsIdList 3; kit revision 35)
git show 326aa2e:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # ... v1.67.0
git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq --strip-trailing-cr <scratch>/claimed/LibKa0s libs/LibKa0s \
  && diff -rq --strip-trailing-cr <scratch>/claimed/testkit tests/_kit && echo payload-matches
# payload-matches
```

Base v1.67.0, agreed by the line, the last payload commit and the bytes; the minors on disk (3b) are
v1.67.0's. No base correction is owed.

## Range

```sh
git -C ../LibKa0s log --oneline v1.67.0..v1.68.0 | wc -l          # 8 commits (DA-LK-01 .. DA-LK-07R)
git -C ../LibKa0s diff --stat v1.67.0 v1.68.0 -- LibKa0s testkit
#  LibKa0s/WidgetsDragHandle.lua | 84 +++++++++++++++++++++++++++++++++++--------
#  1 file changed, 69 insertions(+), 15 deletions(-)
```

## Per-file minor delta (3c)

Only the row that moved (every other file in the tag's `LibKa0s.xml` prints the same minor old and new):

| File | Old | New |
|---|---|---|
| `WidgetsDragHandle.lua` | `DRAG_MINOR` 3 | `DRAG_MINOR` 4 |

The Widgets key moves 12.1.3 -> 12.1.4. No file added or removed, no floor rises, `LibKa0s.xml`
unchanged. No cross-major skew.

## Both diffs (3d), before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s   # differ: WidgetsDragHandle.lua
diff -rq                     <scratch>/new/LibKa0s libs/LibKa0s   # differ: WidgetsDragHandle.lua
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit     # (empty)
diff -rq                     <scratch>/new/testkit tests/_kit     # (empty)
```

Content and bytes agree: one genuinely changed file, no line-ending drift, no `Only in` line, so
nothing to delete.

## Consumption map (3e)

`LibKa0s-Widgets-1.0` is consumed by the host at `modules/MacroBar.lua:44` (the macro bar's drag
strip, `Widgets.DragHandle`, `modules/MacroBar.lua:203`), `settings/MacroBar.lua:720`,
`settings/StatPriority.lua:122` and `settings/Category.lua:79` (the reorder lists). The bar's strip
is the only `DragHandle` this addon builds. Every other consumed major is unchanged in this range.

## Kit revision (3f)

```sh
grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# both: Kit.VERSION = 35
```

Unchanged; `tests/_kit/` is byte-identical to the tag before and after the copy. Both payloads still
move together (the pairing rule), by construction.

## Contract delta (3g)

No blocker.

```sh
diff <(git -C ../LibKa0s show v1.67.0:docs/api/Widgets/version-12.1.3-docs.md) \
     <(git -C ../LibKa0s show v1.68.0:docs/api/Widgets/version-12.1.4-docs.md)
```

The diff is the header rows, the new "What changed at 12.1.4" section and the `tooltipPlace` /
`place` rows, both marked **Since 4** (`docs/api/Widgets/version-12.1.4-docs.md:20-48`, `:692`). The
document states "Without a hook nothing changes. A host that sets neither field gets minor 3's calls
in minor 3's order" (`:44-45`) and "What a host must change: nothing" (`:47`). No existing member,
field or callback moved its call site or return contract. This addon's strip spec passes no
`tooltipPlace` and no descriptor `place`, so its three tooltips keep minor 3's behavior.

`grep -rn '__Attach[A-Za-z]*'` outside `libs/` and `tests/_kit/` finds no host call site.

## Unrecorded tags (3h)

The audit walk (payload commits plus provenance rolls since the store's first bundle) against the
recorded bundles prints nothing: every vendored tag up to v1.67.0 has a bundle. No span bundle owed.
