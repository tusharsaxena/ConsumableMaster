Delta: LibKa0s v1.75.2 -> v1.76.0

Run non-interactively as item CM-RV of the 2026-10-23 "sim auto-run, QC preview selector, mode
strips, MM/KCD simulators" run, on branch `feat/2026-10-23-sim-preview-mode-strips`, following the
installed `/dev-copilot:wow-revendor-libka0s` 2.4.0 copy-and-prune contract and LibKa0s
`docs/releasing.md` "Re-vendoring consumers". The run assigns ConsumableMaster no adoption, so this
re-vendor is mechanical: copy both payloads whole, roll the provenance line, re-run the prune
against the unchanged declaration, write this bundle. No interview, no GitHub issue.

## Source

```sh
git -C ../LibKa0s cat-file -t v1.76.0                              # tag (annotated, object 546e284)
git -C ../LibKa0s rev-parse --short 'v1.76.0^{commit}'             # 9949368
git -C ../LibKa0s ls-remote --tags origin v1.76.0 | wc -l          # 0: local only, not pushed
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools | tar -x -C <scratch>
```

The payload is taken from the tag through `git archive`, never from the LibKa0s working tree, and
`tools/prune-icons.lua` is run from the same export. The tag is local; its push waits on the owner.

## Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# 485f52f Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)
git -C ../LibKa0s archive v1.75.2 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s | grep -v 'Only in .*media/icons'   # (empty)
diff -rq <scratch>/claimed/testkit tests/_kit                                       # (empty)
```

Base v1.75.2, agreed by the provenance line, the last payload commit and the bytes. Step 0: the
newest single-tag bundle `2026-10-22-v1.75.0` states base v1.71.0, which matches the provenance
before its re-vendor commit `4ad0b25`; no correction.

**Span bundle.** v1.75.1 (`ccb2bed`) and v1.75.2 (`485f52f`) were vendored here without a bundle
(3h listing). They are recorded in `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`, written with this one.

## Range

```sh
git -C ../LibKa0s log --oneline v1.75.2..v1.76.0 | wc -l           # 8 (LK-00, LK-01, LK-10, LK-25, LK-90 x3)
git -C ../LibKa0s diff --stat v1.75.2 v1.76.0 -- LibKa0s testkit
#  LibKa0s/SimPanel.lua    |  36 ++++++++------
#  LibKa0s/SimTimeline.lua | 122 +++++++++++++++++++++++++++++++++++++-----------
#  LibKa0s/Widgets.lua     |  43 ++++++++++++-----
#  3 files changed, 148 insertions(+), 53 deletions(-)
```

No file is added or removed. The test kit does not move.

## Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, printing only rows whose constant differs:

| File | Constant | v1.75.2 | v1.76.0 |
|---|---|---|---|
| `Widgets.lua` | `LibKa0s-Widgets-1.0` `MINOR` | 13 | **14** |
| `SimTimeline.lua` | `TIMELINE_MINOR` | 2 | **3** |
| `SimPanel.lua` | `SIM_PANEL_MINOR` | 4 | **5** |
| test kit `framework.lua` | `Kit.VERSION` | 41 | 41 |

Every other file prints the same constant old and new. No `NEEDS_*` floor rises. No consumer file
is behind (no cross-major skew).

## The copy, the declaration and the prune

```sh
rm -rf libs/LibKa0s tests/_kit && mkdir -p libs/LibKa0s tests/_kit
cp -r <scratch>/LibKa0s/. libs/LibKa0s/ && cp -r <scratch>/testkit/. tests/_kit/
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | wc -l    # 0
diff -r                     <scratch>/LibKa0s libs/LibKa0s | wc -l    # 0
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit   | wc -l    # 0
diff -r                     <scratch>/testkit tests/_kit   | wc -l    # 0
# CLAUDE.md: provenance line v1.75.2 -> v1.76.0; the declaration under it is kept:
#   LibKa0s icons: clear, close, copy, help, info, segment.
lua5.1 <scratch>/tools/prune-icons.lua .
# prune-icons: .: 6 icon(s) declared; kept 7 file(s), removed 5833
diff -r <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in .*/LibKa0s/media/icons' | wc -l   # 0
```

All four diffs ran before the prune and came back empty. After it, the only differences are the
undeclared icons. No file survived that the tag removed (no `Only in libs/LibKa0s` line). The
declaration is unchanged: v1.76.0 adds no library-drawn mark, and CM draws no new one.

## Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Fourteen majors consumed (CLAUDE.md), unchanged. Of the moved files:

| Touched surface | Consumed here? | Note |
|---|---|---|
| `Widgets` 14 | **yes**: `ReorderList`, `DragHandle` (`settings/Category.lua`, `settings/StatPriority.lua`, `settings/MacroBar.lua`, `modules/MacroBar.lua`) | the change is `TestStrip`'s `opts.kind`, which CM does not call; `WidgetsReorder` 1 and `WidgetsDragHandle` 4 only re-pair on the shell's new minor |
| `SimTimeline` 3 / `SimPanel` 5 | no | `Sim-1.0` ships unused |

## Kit revision

Kit revision 41 on both sides: the pairing rule (v1.9.0 or newer takes revision 11 or newer in the
same commit) holds by construction of the whole-folder copy.

## Contract delta (3g)

The majors that moved a minor and that CM looks up: `Widgets` only. `git -C ../LibKa0s diff v1.75.2
v1.76.0 -- LibKa0s/Widgets.lua` changes nothing but `TestStrip` (a `kind` option, a per-kind fill,
`strip.kind`) and the header prose. `ReorderList`, `DragHandle`, `ROW_BOX` and `DRAG_HANDLE` are in
other files, which did not change. CM passes no host member through an `__Attach*` seam that the
range touches. **No blocker.**

## Tests that assume the whole icon folder (3j)

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

The hits are the declaration-driven cases written at v1.75.0 (`tests/test_mediasetup.lua`,
`tests/test_settingsui.lua`); none walks the whole catalog. No change. `__releaseChrome` has no
mirror here (`grep -rn __releaseChrome . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
is empty).

## Gate note

The first test run after the copy was 1216 passed, 1 failed: `eol: every tracked file carries the
terminator .gitattributes declares for it` named `docs/smoke-tests.md` (575 bare LF on disk against
a declared CRLF). That file was not touched by this item; its index content was right and only the
working tree had been written around git's filter. Repaired with `rm docs/smoke-tests.md && git
checkout -- docs/smoke-tests.md` (no content change, nothing to commit), then the gate was green.
