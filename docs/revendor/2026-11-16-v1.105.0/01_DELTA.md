Delta: LibKa0s v1.94.0 -> v1.105.0

Written 2026-11-16 by item RV-CM of Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/` (the LibKa0s
issues #75 and up). Payload taken from the tag, never the sibling tree:
`git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit `79b1d9c4`, a local tag, not on origin yet:
`git -C ../LibKa0s ls-remote --tags origin v1.105.0` prints nothing, which the run expects). Copy half only: the
adoption interview and its issue filing are phase [3] of that run (see 02_CANDIDATES.md).

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.94.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # 20f4c60 (CM-F1..CM-F6, the Forever port step 1)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.94.0
```

The two agree: the base is **v1.94.0**. Range: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0` lists 114 commits;
`git -C ../LibKa0s diff --stat v1.94.0 v1.105.0` reports 653 files changed.

Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-11-07-v1.93.0/`, states base v1.92.0, and the
provenance line before its re-vendor commit `ba8f2ec` was v1.92.0: **ok**, no correction owed.

## 3b. Claimed against actual

The payload on disk before the copy was the v1.94.0 payload exactly (icons apart, which the declaration prunes):

```sh
git -C ../LibKa0s archive v1.94.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s | grep -v 'Only in <scratch>/old/LibKa0s/media/icons'   # empty
diff -rq <scratch>/old/testkit tests/_kit                                                          # empty
```

## 3c. Per-file minor delta (files whose minor moved; every other file is unchanged)

| File | Constant | v1.94.0 | v1.105.0 |
|---|---|---|---|
| Core.lua | MINOR | 17 | 18 |
| Tooltip.lua | MINOR | (new) | 1 |
| Role.lua | MINOR | (new) | 1 |
| Callout.lua | MINOR | (new) | 4 |
| CalloutSettings.lua | SETTINGS_MINOR | (new) | 5 |
| WaypointArrow.lua | MINOR | (new) | 2 |
| WaypointArrowSettings.lua | SETTINGS_MINOR | (new) | 2 |
| Charts.lua | MINOR | 1 | 2 |
| Media.lua | MINOR | 12 | 13 |
| SkinDefs.lua | DEFS_MINOR | 27 | 28 |
| SkinDefsOthers.lua | OTHERS_MINOR | 8 | 10 |
| Widgets.lua | MINOR | 26 | 27 |
| WidgetsDropdown.lua | DROPDOWN_MINOR | 1 | 2 |
| WidgetsReorder.lua | REORDER_MINOR | 6 | 7 |
| WidgetsDragHandle.lua | DRAG_MINOR | 13 | 14 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR | (new) | 1 |
| WidgetsCopyWindow.lua | COPY_MINOR | 5 | 6 |
| WidgetsHeader.lua | HEADER_MINOR | (new) | 1 |
| WidgetsBar.lua | BAR_MINOR | (new) | 1 |
| DebugLog.lua | MINOR | 22 | 23 |
| DebugLogDiagnostics.lua | DIAG_MINOR | 7 | 11 |
| DebugLogWindow.lua | WINDOW_MINOR | 4 | 5 |
| Launcher.lua | MINOR | 9 | 11 |
| OptionsWidgets.lua | WIDGETS_MINOR | 45 | 46 |
| OptionsNav.lua | NAV_MINOR | 6 | 7 |
| OptionsSkinPicker.lua | PICKER_MINOR | 11 | 12 |
| OptionsSkinPickerQueue.lua | QUEUE_MINOR | (new) | 1 |
| IconBrowserWindow.lua | WINDOW_MINOR | 1 | 2 |
| IconBrowser.lua | BROWSER_MINOR | 1 | 2 |
| PerfPanel.lua | PANEL_MINOR | 13 | 14 |
| Sim.lua | MINOR | 2 | 3 |
| SimPanel.lua | SIM_PANEL_MINOR | 10 | 11 |
| SimPanelRender.lua | RENDER_MINOR | 3 | 4 |

Produced by the spec's loop over `grep -oE 'file="[^"]+\.lua"'` of the tag's `LibKa0s/LibKa0s.xml`. No cross-major
skew: no file was behind before the copy and none is after it.

## 3d. Diffs after the copy, before the prune

`diff -r --strip-trailing-cr` and `diff -r` of `<scratch>/LibKa0s` against `libs/LibKa0s` and of `<scratch>/testkit`
against `tests/_kit`: all four empty. After the prune the only differences are the `Only in <scratch>/LibKa0s/media/icons`
and `.../media/sounds` lines for the marks and voice packs this addon does not declare.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`:
Bus (`core/Bus.lua`), Compat (`core/Compat.lua`), Core (`core/CoreSetup.lua`), DebugLog (`core/DebugLogSetup.lua`),
Env, Item, Launcher, Lifecycle, Media, Perf, Skin (`core/SkinSetup.lua`, `core/Database.lua`), Widgets
(`modules/MacroBar.lua`, `settings/Category.lua`, `settings/MacroBarSlots.lua`, `settings/StatPriority.lua`), Schema,
Options and Slash. Not consumed: Tooltip (new), Role, Callout, WaypointArrow, Charts, Sim, Glow, Toast, Pool, IconBrowser.

## 3f. Kit revision

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua`: 53 -> **57**, copied whole in the same
commit as the library (the pairing rule: the two payloads move together).

## 3g. Contract changes under the majors this addon consumes

- **DebugLog minor 23: the buffer is plain text** (`docs/api/DebugLog/version-23.11.1.5-docs.md:34-36`). `D:Add` hands
  the view the message as given and stores `buffer` stripped of its escapes. Host code needs nothing: the addon's
  `DL.Report` (`core/DebugLogSetup.lua`) writes through `D:Add`, and its reports now Copy as plain text (the owner's
  ruling of 2026-11-08, delivered). Three suite cases in `tests/test_slash.lua` pinned colors by reading `D.buffer`
  and went red; they now read the view, through a recorder on the console's `AddMessage`, as the document says a
  host test should (line 36). Their assertions are unchanged.
- **WidgetsDragHandleTip minor 1 / WidgetsDragHandle minor 14: the strip tooltip is never at the cursor**
  (LibKa0s#92 part B, `LibKa0s/WidgetsDragHandleTip.lua:18-27`, `:115-148`). The macro bar strip's host hook
  (`MB.PlaceTooltipBeside`) still wins when it answers `true`; when it cannot read the strip the fallback was a
  re-own at `ANCHOR_CURSOR` and is now UIParent at `ANCHOR_NONE`, attached below the strip. The suite case
  `macrobar handle: an unreadable strip falls back to the cursor with the same tooltip` pinned the old fallback;
  it is re-pinned to the new one (owner UIParent, `ANCHOR_NONE`, never the cursor, `TOP` to the strip's `BOTTOM`,
  the same lines, shown) and renamed `... falls back below the strip ...`. The host hook itself is unchanged.
- **Options: `OptionsSkinPickerQueue.lua`, a new file of the Options major** registering its own `MODULES` row and a
  paired minor (`__pickerQueueMinor`, `__pickerQueueShellMinor`). `tests/test_libka0s.lua`'s Options inventory names
  it, or its stray check reads it as a file under a major it does not own (the same fix as OptionsHeader at v1.93.0).
- No `__Attach*` call in the addon (`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs
  --exclude-dir=_kit` is empty), so no host-supplied member's call site can have moved.
- The launcher's settings mark (#86) finds the addon by `d.owner or d.name`: `core/LauncherSetup.lua:120`,
  `core/DebugLogSetup.lua:184,193` and `core/PerfSetup.lua:81,98` all pass `addonName`, so the mark resolves.

**Blockers:** none that needed a decision. The three items above were fixed in the re-vendor commit.

Stub members (design section 5): the Options parity case is reached-member (`tests/test_surface_parity.lua`), so no
`SideTabs` is owed; there is no by-name DebugLog parity case (R9 C4), so no `Report`/`Serialize` stub members; no Sim
or Compat identity stub. Nothing went red there.

## 3h. Span

`2026-11-16-v1.94.0-v1.94.0/` beside this bundle records v1.94.0, vendored by `20f4c60` with no bundle.

## 3i. Icon declaration

Kept as written (`CLAUDE.md:62`), the next non-blank line under the provenance line:
`LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, segment, settings, star, volume-high.`
It already names `settings`, which kit revision 57's `LIBRARY_MARKS` now requires of every host. No icon was added
upstream that this addon draws. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's smoke is the backstop for a name the host forgot.

`lua <scratch>/tools/prune-icons.lua .`:

```
prune-icons: .: 15 icon(s) declared; kept 16 file(s), removed 5824
prune-icons: .: sounds none (no `LibKa0s sounds:` line); kept 0 file(s), removed 362
```

Removed by set: Open Iconic 209 undeclared marks, Phosphor 1435, Game-icons 4180 (each set re-arrived whole with the
copy); the eight Callout voice packs (362 files) since the addon declares no sounds.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/`: `tests/test_mediasetup.lua`
and `tests/test_settingsui.lua` read declared names only (narrowed at v1.75.0). Nothing to fix.
