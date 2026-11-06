Delta: LibKa0s v1.85.0 -> v1.89.0

Written before the copy. Run item `V89-CM` of the Ka0sAddonsCommonTasks bundle
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (its `00_PLAN.md` holds the owner's decisions). Payload taken from
the pushed tag v1.89.0 (`0bd4839`): `git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-cm/new`.

## Step 0 (pre-flight)

The run's pre-flight (`inputs/step0-preflight.txt` in that bundle) reads for this addon:
`ConsumableMaster  2026-11-01-v1.85.0  base v1.84.0  vendored-before v1.84.0@88cbaf4  ok`. No base correction.

## 3a. Claimed version, and the base

`grep -n '[Bb]undles' CLAUDE.md` -> `61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).`

Last commit touching either payload: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `1714fc6`, whose
`CLAUDE.md` names v1.85.0. `git log "1714fc6..HEAD" -- CLAUDE.md` is empty. The kit matches the v1.85.0 extract
byte for byte (`diff -rq`), and the library matches apart from the undeclared icons. **Base v1.85.0.**

Range: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0` (27 commits); `git diff --stat v1.85.0 v1.89.0 -- LibKa0s testkit`:
`DebugLogDiagnostics.lua`, `IconBrowser.lua` (new), `IconBrowserSources.lua` (new), `IconBrowserWindow.lua` (new),
`LibKa0s.xml`, `Toast.lua`, `Widgets.lua`, `testkit/README.md`, `testkit/framework.lua`, `testkit/mock_ace.lua`.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` agrees with v1.85.0 on every
file (Toast 3, Widgets 22, DebugLogDiagnostics 6, no IconBrowser). Line and bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s.xml` loop)

| File | Old | New |
|---|---|---|
| `Toast.lua` | 3 | **4** |
| `Widgets.lua` | 22 | **23** |
| `DebugLogDiagnostics.lua` | 6 | **7** |
| `IconBrowserSources.lua` (`LibKa0s-IconBrowser-1.0`) | absent | **1** (new) |
| `IconBrowserWindow.lua` | absent | **1** (new) |
| `IconBrowser.lua` | absent | **1** (new) |

Every other file is unchanged. No consumer file sits behind its library at the base: no cross-major skew.

## 3d. Diffs (pre-copy)

`diff -r --strip-trailing-cr` and `diff -r` agree (no line-ending drift): the six files above differ or are new,
plus `LibKa0s.xml`; the kit differs in `README.md`, `framework.lua`, `mock_ace.lua`. Every other line is
`Only in <scratch>/LibKa0s/media/icons…` for an undeclared icon. No `Only in libs/LibKa0s` line.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`:
Core, Env, Compat, Lifecycle, Bus, Schema, Item, Media, Skin, Widgets (`modules/MacroBar.lua:44`,
`settings/Category.lua:80`, `settings/MacroBarSlots.lua:85`, `settings/StatPriority.lua:122`), DebugLog, Slash,
Launcher, Options, Perf. Not looked up: Pool, Glow, Sim, Toast, Charts, and the new IconBrowser.

Of the moved majors only **Widgets** is consumed, through `ReorderList` and `DragHandle`. `grep -rn ContextMenu`
outside `libs/` and `tests/_kit/` finds no use site (only `tests/mock_menu.lua`'s note on `MenuUtil`).

## 3f. Kit revision, and the pairing rule

`grep -n 'Kit.VERSION'`: the tag's kit is **51**, the addon's 50. Both payloads move together in one commit, as
the kit-revision pairing rule (revision 11 or newer with LibKa0s v1.9.0 or newer) requires; satisfied by the copy.

## 3g. Contract delta

Read for Widgets, the one moved major this addon consumes. `diff` of
`docs/api/Widgets/version-22.5.12.6.7.5-docs.md` (v1.85.0) and `version-23.5.12.6.7.5-docs.md` (v1.89.0): every
change is additive to `W.ContextMenu` (`submenu`, `radio`, `selected`, `opts.check`, Since 23) and `CloseMenu`
closing every level. Line 36: "What a consumer owes: nothing for a flat menu; a re-vendor." `WidgetsReorder.lua`
(5) and `WidgetsDragHandle.lua` (12) did not move. `grep -rn '__Attach[A-Za-z]*'` outside `libs/` and `_kit/`
finds nothing. Toast 4's owed stub members (`SetStack`, `Visible`, `FrameFor`, CHANGELOG v1.88.0) apply to a
host with a Toast stub; this addon has no Toast lookup and no stub (`grep -rn Toast --include='*.lua'` outside
`libs/` is empty).

### Blockers

None.

## 3h. Tags vendored and never recorded

The span listing (horizon 2026-08-25): 65 vendored tags, 65 recorded, the unrecorded set **empty**. No span bundle.

## 3i. The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `62:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, segment, settings, star, volume-high.`
It is the next non-blank line under the provenance line, which ends its own line (no split owed). **Kept as is**
(decided by the run's plan). The tag's library-drawn table (`docs/releasing.md`, *Library-drawn icons are the
host's to declare*) adds `confirm` for a `W.ContextMenu` `radio` / `selected` tick and `search` / `close` for the
icon browser; this addon wires neither, and `confirm` and `close` are already declared. Hand lists have drifted
before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client
smoke is the backstop for a name the host forgot.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/`: `tests/test_mediasetup.lua:147`
reads `Media.ICONS` as the name catalog (not files), `:160-173` open declared names only, and
`tests/test_settingsui.lua:338` opens `info.tga`, which is declared. All already pass against a pruned folder at
v1.85.0. No blocker.

## Dead stub mirrors

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty. No `__` member
was removed in this range.
