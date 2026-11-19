Delta: LibKa0s v1.106.0 -> v1.107.0

Written 2026-11-19 by item AF-RV-CM of Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/` (the owner's
feedback on the LibKa0s v1.105 adoption smoke). Payload taken from the tag, never the sibling tree:
`git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit `5e963659`, a local tag, not on origin yet:
`git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing, which the run expects). The adoption interview
is skipped: the run's bundle pre-decides this addon's adoption (item AF-STRIP-CM; see 03_DECISIONS.md).

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # 7d57df4 (Re-vendor LibKa0s v1.106.0)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0
```

The two agree: the base is **v1.106.0**. Range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` lists 7
commits; `git -C ../LibKa0s diff --stat v1.106.0 v1.107.0 -- LibKa0s testkit` reports 2 files changed
(`WidgetsDragHandle.lua`, `WidgetsDragHandleTip.lua`).

Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-11-16-v1.105.0/`, states base v1.94.0, and the
provenance line before its re-vendor commit was v1.94.0: **ok**, no correction owed. v1.106.0 was vendored without a
bundle; 3h below back-fills it.

## 3b. Claimed against actual

```sh
git -C ../LibKa0s archive v1.106.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s | grep -v 'Only in <scratch>/old/LibKa0s/media/'   # empty
diff -rq <scratch>/old/testkit tests/_kit                                                     # empty
```

The payload on disk before the copy was the v1.106.0 payload exactly (the declared icon and sound prune apart).

## 3c. Per-file minor delta (files whose minor moved; every other file is unchanged)

| File | Constant | v1.106.0 | v1.107.0 |
|---|---|---|---|
| WidgetsDragHandle.lua | DRAG_MINOR | 14 | 15 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR | 1 | 2 |

No cross-major skew: no file was behind before the copy and none is after it.

## 3d. Diffs after the copy, before the prune

`diff -r --strip-trailing-cr` and `diff -r` of `<scratch>/LibKa0s` against `libs/LibKa0s` and of `<scratch>/testkit`
against `tests/_kit`: all four empty. After the prune the only differences are the `Only in <scratch>/LibKa0s/media/icons`
and `.../media/sounds` lines for the marks and voice packs this addon does not declare.

## 3e. Consumption map

Unchanged from v1.105.0's bundle. The one moved major consumed here is `LibKa0s-Widgets-1.0`, whose `DragHandle`
draws the macro bar's strip (`modules/MacroBar.lua`, buildBar).

## 3f. Kit revision

`Kit.VERSION = 57` on both sides: the kit did not move. The two payloads still travel together.

## 3g. Contract delta

- **The settings mark is on by default (DragHandle minor 15).** A strip that passes no `settings` now draws the gear.
  This addon already passed `settings = true` (AD-86-CM), so the strip's mark set does not change. Not a blocker.
- **The marks read [?][settings][close] left to right**, the X in the corner where the "?" sat, at a 14 px pitch
  where it was 18 (`HELP_HIT`), in the window header's tints. Library-side; the reserve arithmetic this addon's test
  reads from `DRAG_HANDLE` constants (`tests/test_macrobar_chrome.lua`) follows on its own. Not a blocker.
- **`tooltipPlace` retired (DragHandleTip minor 2).** This addon passes none since AD-92-CM. Not a blocker.

Blockers: none.

## 3h. Unrecorded tags

v1.106.0 (vendored by `7d57df4` with no bundle): back-filled in `../2026-11-19-v1.106.0-v1.106.0/`.

## 3i. The icon declaration

Kept as written: `LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset,
segment, settings, star, volume-high.` It already names `settings`, which the strip's gear draws.

## 3j. Tests that assume the whole icon folder

None (unchanged since v1.105.0's bundle).
