# 01 Delta: LibKa0s v1.107.0 -> v1.108.0

Written 2026-11-20 by item SD-RV-CM of Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/` (LibKa0s#94,
#97, #99, #100). Payload taken from the tag, never the sibling tree:
`git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit `56c20b76`, a local tag on the library's
`feat/2026-11-20-libka0s-94-97-99-100`, not on origin yet, which the run expects). The adoption interview and the
issue filing are skipped: the run's bundle decides this addon's work (items SD-RV-CM and SD-SK-CM).

## 3a. Base

`CLAUDE.md` read `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.107.0 (MIT).`, and the last payload
commit (`a4330fd`, AF-RV-CM, the re-cut v1.107.0) carries the same line: the base is **v1.107.0**. Range:
`git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` lists 15 commits; `git diff --stat v1.107.0 v1.108.0 -- LibKa0s
testkit` reports 23 files changed. The newest single-tag bundle, `2026-11-19-v1.107.0/`, states base v1.106.0, which
matches the line before its commit: no correction owed, and no unrecorded tag.

## 3b. Claimed against actual

`diff -rq` of the v1.107.0 archive against `libs/LibKa0s` (the pruned `media/` apart) and against `tests/_kit`: both
empty. The payload on disk before the copy was v1.107.0 exactly.

## 3c. Per-file minor delta (every other file is unchanged)

| File | Constant | v1.107.0 | v1.108.0 |
|---|---|---|---|
| Core.lua | MINOR | 18 | 19 |
| Widgets.lua | MINOR | 29 | 30 |
| WidgetsBar.lua | BAR_MINOR | 1 | 2 |
| WidgetsDragHandle.lua | DRAG_MINOR | 15 | 16 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR | 2 | 3 |
| WidgetsDropdown.lua | DROPDOWN_MINOR | 2 | 3 |
| WidgetsLineChart.lua | CHART_MINOR | 7 | 8 |
| OptionsCompose.lua | COMPOSE_MINOR | 19 | 20 |
| SkinPaint.lua | PAINT_MINOR | 19 | 20 |
| SkinPaintControls.lua | CONTROLS_MINOR | 18 | 19 |
| SkinPaintHud.lua | HUD_MINOR | 1 | 2 |
| Callout.lua | MINOR | 4 | 5 |
| CalloutSettings.lua | SETTINGS_MINOR | 5 | 6 |
| WaypointArrow.lua | MINOR | 2 | 3 |
| WaypointArrowSettings.lua | SETTINGS_MINOR | 2 | 3 |
| Charts.lua | MINOR | 2 | 3 |
| ChartsRender.lua | RENDER_MINOR | 1 | 2 |

No `NEEDS_*` floor rises and no file is added or removed. No cross-major skew before or after the copy.

## 3d. Diffs after the copy, before the prune

`diff -r` of the extract's `LibKa0s/` against `libs/LibKa0s/` and of `testkit/` against `tests/_kit/`: both empty.
After the prune the only differences are the undeclared marks and voice packs under `media/`.

## 3e. Consumption map

The moved majors this addon consumes: `LibKa0s-Widgets-1.0` (`DragHandle`, the macro bar's strip; `ReorderList`),
`LibKa0s-Options-1.0` (OptionsCompose: `ColorPair`, `BorderGroup` and `FontGroup` in `settings/MacroBar.lua`;
`MasterControls` in `settings/General.lua`), `LibKa0s-Skin-1.0` (the skin owner, `S.BarBorder`, `S.HudFont`, the
panel painters) and `LibKa0s-Core-1.0` (the printer). Not consumed: `Callout`, `WaypointArrow`, `Charts`, and the
`W.Bar`, `W.ContextMenu`, `Footer` and `S.ApplyBarFill` surfaces (no caller in `core/`, `modules/` or `settings/`).

## 3f. Kit revision

`Kit.VERSION` 57 -> **58** (SD-LK-GUARD). The two payloads travel together.

## 3g. Contract delta

- **OptionsCompose minor 20: the composers emit every companion by default.** Each of this addon's composed blocks
  already declares its color and shadow companions as host rows in `extra` at the composer's own paths
  (`<key>FromSkin`), and the composer skips a companion an `extra` row declares, so no row is drawn twice and no
  AceDB default is owed (every `macroBar.*FromSkin` already defaults `true`). Font shadow (`labelShadow`) is now
  grayed while `labelShadowFromSkin` is on: `tests/test_skin_flip.lua` pinned minor 19's live toggle and is
  re-pinned. Not a blocker.
- **WidgetsDragHandleTip minor 3 (LibKa0s#99, R-3).** A strip whose rect reads secret or nil places its tooltip above
  its nearest readable ancestor (the bar), and hides it when none reads. `tests/test_macrobar_chrome.lua` pinned
  minor 2's relative point on the strip; three cases re-pinned. Not a blocker.
- **Kit revision 58's typed-value scanner** reads four-number tables and found `core/CoreSetup.lua`'s
  `local swatch = { 1, 1, 1, 1 }` (`KCM.SwatchColor`'s scratch table). One `Kit.skinValues` row, category
  `"unreachable default"`. Not a blocker.
- **Kit revision 58's skin-switch families** (each family on its own, StatusBar fills, the colorless-face check):
  every declared surface passed unchanged. SD-SK-CM widens the declaration.
- `W.BarStyle`, Charts, `S.ApplyBarFill`, the dropdown menu, the Callout and the waypoint arrow: no caller here.

Blockers: none.

## 3h. Unrecorded tags

None.

## 3i. The icon declaration

Kept as written (15 marks). The prune kept 16 files (15 marks and the Open Iconic license) and removed every
undeclared icon and 362 sound files.

## 3j. Tests that assume the whole icon folder

None.
