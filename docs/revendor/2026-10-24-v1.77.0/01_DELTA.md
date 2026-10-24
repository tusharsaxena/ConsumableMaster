Delta: LibKa0s v1.76.0 -> v1.77.0

Run non-interactively as item CM-RV of the 2026-10-24 "keybindings (015), settings layout (020),
frame strata (030)" run, on branch `feat/2026-10-24-keybinds-layout-strata`, following the
installed `/dev-copilot:wow-revendor-libka0s` 2.4.0 copy-and-prune contract and LibKa0s
`docs/releasing.md` "Re-vendoring consumers". The run's adoptions for ConsumableMaster are its
CM-ZS item (held for the owner), so this re-vendor is mechanical: copy both payloads whole, roll
the provenance line, re-run the prune against the unchanged declaration, fix the one test the new
payload turns red, write this bundle. No interview, no GitHub issue.

## Source

```sh
git -C ../LibKa0s cat-file -t v1.77.0                              # tag (annotated, object 7380d36)
git -C ../LibKa0s rev-parse --short 'v1.77.0^{commit}'             # 78240f7
git -C ../LibKa0s ls-remote --tags origin v1.77.0 | wc -l          # 0: local only, not pushed
git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C <scratch>
```

The payload is taken from the tag through `git archive`, never from the LibKa0s working tree, and
`tools/prune-icons.lua` is run from the same export. The tag is local; its push waits on the owner.

## Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# e05733d CM-RV2: re-vendor LibKa0s from the moved v1.76.0 tag (LK-91)
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s | grep -v 'Only in .*media/icons'   # (empty)
diff -rq <scratch>/claimed/testkit tests/_kit                                       # (empty)
```

Base v1.76.0, agreed by the provenance line, the last payload commit and the bytes. Step 0: the
newest single-tag bundle `2026-10-23-v1.76.0` states base v1.75.2, which matches the provenance
before its re-vendor; no correction. 3h listing (vendored tags without a bundle): empty, so no span
bundle.

## Range

```sh
git -C ../LibKa0s log --oneline v1.76.0..v1.77.0 | wc -l           # 15
git -C ../LibKa0s diff --stat v1.76.0 v1.77.0 -- LibKa0s testkit
#  LibKa0s/Core.lua                |  28 +-
#  LibKa0s/DebugLog.lua            |  13 +-
#  LibKa0s/LibKa0s.xml             |   1 +
#  LibKa0s/Options.lua             |  28 +-
#  LibKa0s/OptionsCombat.lua       |  20 +-
#  LibKa0s/OptionsCompose.lua      |  66 +++-
#  LibKa0s/OptionsIds.lua          |  18 +-
#  LibKa0s/OptionsKeybinds.lua     | 819 ++++++++++++++++++++++++++++++++++++++++
#  LibKa0s/PerfPanel.lua           |   9 +-
#  LibKa0s/SimPanel.lua            |   9 +-
#  LibKa0s/Widgets.lua             |   8 +-
#  LibKa0s/WidgetsAutocomplete.lua |   6 +-
#  LibKa0s/WidgetsDragHandle.lua   |  62 ++-
#  testkit/README.md               |   5 +-
#  testkit/bindings_xml.lua        | 230 +++++++++++
#  testkit/framework.lua           |   7 +-
#  testkit/mock_bindings.lua       | 230 +++++++++++
#  testkit/mock_layers.lua         | 147 ++++++++
#  18 files changed, 1672 insertions(+), 34 deletions(-)
```

One library file is added (`OptionsKeybinds.lua`, the twelfth Options file) and three kit files
(`bindings_xml.lua`, `mock_bindings.lua`, `mock_layers.lua`). Nothing is removed.

## Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, printing only rows whose constant differs:

| File | Constant | v1.76.0 | v1.77.0 |
|---|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0` `MINOR` | 11 | **12** |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` `MINOR` | 14 | **15** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 4 | **5** |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR` | 2 | **3** |
| `DebugLog.lua` | `LibKa0s-DebugLog-1.0` `MINOR` | 20 | **21** |
| `Options.lua` | `LibKa0s-Options-1.0` `MINOR` | 29 | **30** |
| `OptionsIds.lua` | `IDS_MINOR` | 2 | **3** |
| `OptionsCombat.lua` | `COMBAT_MINOR` | 1 | **2** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | **8** |
| `OptionsKeybinds.lua` | `KEYBINDS_MINOR` | (new) | **3** |
| `PerfPanel.lua` | `PANEL_MINOR` | 8 | **9** |
| `SimPanel.lua` | `SIM_PANEL_MINOR` | 5 | **6** |
| test kit `framework.lua` | `Kit.VERSION` | 41 | **42** |

Every other file prints the same constant old and new. No `NEEDS_*` floor rises ("No Core floor
moves", CHANGELOG v1.77.0). No consumer file is behind (no cross-major skew).

## The copy, the declaration and the prune

```sh
rm -rf libs/LibKa0s tests/_kit && mkdir -p libs/LibKa0s tests/_kit
cp -r <scratch>/LibKa0s/. libs/LibKa0s/ && cp -r <scratch>/testkit/. tests/_kit/
# CLAUDE.md: provenance line v1.76.0 -> v1.77.0; the declaration under it is kept:
#   LibKa0s icons: clear, close, copy, help, info, segment.
lua5.1 <scratch>/tools/prune-icons.lua .
# prune-icons: .: 6 icon(s) declared; kept 7 file(s), removed 5833
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in .*/LibKa0s/media/icons' | wc -l   # 0
diff -r                     <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in .*/LibKa0s/media/icons' | wc -l   # 0
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit   | wc -l    # 0
diff -r                     <scratch>/testkit tests/_kit   | wc -l    # 0
```

Departure from the procedure's order: the four pre-prune diffs were mistyped (a shell quoting
slip) and printed usage errors instead of output, so the diffs were taken after the prune. After
the prune the only differences are the undeclared icons, which is the stronger form of the
pre-prune check for every non-icon path, and the testkit diffs are identical either side of the
prune because the prune touches only `libs/LibKa0s/media/icons/`. No file survived that the tag
removed (no `Only in libs/LibKa0s` line). The declaration is unchanged: v1.77.0 adds no
library-drawn mark (the tag's `docs/releasing.md` closed set is still `close`, `copy`, `clear`,
`info`; `OptionsKeybinds.lua` draws no icon), and CM draws no new one. The new files arrive CRLF
as `.gitattributes` declares.

## Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Fourteen majors consumed (CLAUDE.md), unchanged. Of the moved files:

| Touched surface | Consumed here? | Note |
|---|---|---|
| `Core` 12 | yes | `Core.RaiseStaticPopups` is new and additive; the three tool windows call it |
| `DebugLog` 21 | yes (`/cm debug`) | the console is now toplevel and re-raises a shown confirmation |
| `Perf` 15.1.1.9 (PerfPanel 9) | yes (`/cm perf`) | the step panel is now toplevel, same re-raise |
| `Widgets` 15 / `WidgetsDragHandle` 5 / `WidgetsAutocomplete` 3 | yes: `DragHandle`, `ReorderList` | menu and suggestion list clamped; DragHandle's `level`, `ignoreParentAlpha`, `ApplyLevel` are opt-in, absent means minor 4's strip |
| `Options` 30, `OptionsIds` 3, `OptionsCombat` 2, `OptionsCompose` 8, `OptionsKeybinds` 3 | yes (settings panel) | the IdList suggestion list closes at combat start; `O.StrataTooltip` and the Keybindings tab are opt-in |
| `SimPanel` 6 | no | `Sim-1.0` ships unused |

## Kit revision

Kit revision 41 -> 42. The pairing rule (v1.9.0 or newer takes revision 11 or newer in the same
commit) holds by construction of the whole-folder copy. The repo's own statements of the vendored
revision (`CLAUDE.md` Gate paragraph, `docs/testing.md` three places, a `tests/run.lua` comment)
are rolled to 42 in the same commit.

## Contract delta (3g)

Majors that moved a minor and that CM looks up: Core, DebugLog, Perf, Widgets, Options. Read
against the tag's CHANGELOG v1.77.0 block ("What a consumer owes") and the new API documents
(`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`,
`docs/api/Widgets/version-15.1.5.3.3-docs.md`):

- **Options degradation stubs gain `KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED` and
  `StrataTooltip`** (`Kit.assertSurfaceParity`). Not a blocker here: CM's parity case
  (`tests/test_surface_parity.lua`, `OPTIONS_SEAM`) compares a named projection of the seam, and
  CM's degraded arm (`settings/OptionsSetup.lua`) deliberately leaves every library-owned member
  absent. None of the four is in the projection, so the gate stays green with no stub change. A
  later adoption (CM-ZS for `StrataTooltip`) adds its member to the seam and the stub together.
- CM passes no host member through an `__Attach*` seam (`grep -rn '__Attach[A-Za-z]*' . --include='*.lua'
  --exclude-dir=libs --exclude-dir=_kit` is empty), so no host-supplied member's call site moved.
- **No blocker.**

## Tests the new payload turned red (fixed in this commit)

First gate run after the copy: 1216 passed, 1 failed, 1 skipped.

```
FAIL  LibKa0s: no file registers under a major it does not belong to
  each MODULES registry holds only its own major's files
  (expected , got LibKa0s-Options-1.0 reports OptionsKeybinds)
```

`tests/test_libka0s.lua` keeps the Options major's file inventory and paired-minor list by hand;
the new twelfth file registers its own MODULES row, so the stray check read it as a file
registering under a major it does not own. Fix: `OptionsKeybinds` joins `files` and `paired`
(`__keybindsMinor` / `__keybindsShellMinor`, read from `libs/LibKa0s/OptionsKeybinds.lua:59-62`),
with a one-line history comment beside the v1.73.0 `OptionsDrawer` one. No assertion softened.

## Tests that assume the whole icon folder (3j)

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

The hits are the declaration-driven cases written at v1.75.0 (`tests/test_mediasetup.lua`,
`tests/test_settingsui.lua`); none walks the whole catalog. No change. `__releaseChrome` has no
mirror here (`grep -rn __releaseChrome . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
is empty).
