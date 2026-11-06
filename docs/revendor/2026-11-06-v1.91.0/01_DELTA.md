Delta: LibKa0s v1.90.0 -> v1.91.0

Written before the copy. Run item `FU-RV-CM` of the Ka0sAddonsCommonTasks bundle
`docs/2026-11-06-FOLLOWUPS_V1_91/` (its `00_PLAN.md` holds the decisions). Payload taken from the tag v1.91.0
(`55bfbb4`), which is **local** to the `../LibKa0s` checkout and not pushed, so
`git ls-remote --tags origin v1.91.0` prints nothing. That is expected: the provenance line names v1.90.0, so this
is a new re-vendor, not a refresh. Extract:
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/fu-rv-cm/new`.

## Step 0 (pre-flight)

**Skipped.** The installed skill's Step 0 roster regex expects markdown links, while
`../WowAddonStandards/standards/ADDONS.md` writes `` `../../<Folder>/` ``, so it matches nothing; and its `tag_at`
helper arrives with `"$1"`/`"$2:"` substituted by the command's arguments. Both are the dev-copilot defects this run
fixes upstream (`FU-DC1`). Not a pass. Checked by hand for this addon alone: the newest single-tag bundle
`2026-11-06-v1.90.0` states base v1.89.0, and the commit that rolled the line to v1.90.0, `dc6d195`, has parent
provenance v1.89.0 (`git show dc6d195^:CLAUDE.md`). `ok`. No base correction.

## 3a. Claimed version, and the base

`grep -n '[Bb]undles' CLAUDE.md` -> `61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).`

Last commit touching either payload: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `53c5977` (the v1.90.0
refresh), whose `CLAUDE.md` names v1.90.0; `git log 53c5977..HEAD -- CLAUDE.md` -> `e2b190a` (a docs sync that leaves
the line alone). Against a v1.90.0 extract, `diff -rq` shows the kit identical and the library identical apart from
undeclared icons. **Base v1.90.0.**

Range: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` (7 commits: `55bfbb4`, `1938837`, `3f7be30`, `acc9640`,
`c1ed261`, `d72dc4a`, `55d3b0f`); `git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s testkit tools`:
`Core.lua`, `CorePixel.lua` (new), `LibKa0s.xml`, `SkinAceConfirm.lua` (new), `SkinPaintExtras.lua`,
`SkinPaintHud.lua` (new), `Widgets.lua`, `WidgetsDropdown.lua` (new), `WidgetsLineChart.lua` (9 files, +1414 -1203).
`testkit/` and `tools/` did not move.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua`, sorted, equals the same grep
over the v1.90.0 extract. Line and bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s.xml` loop)

| File | Old | New |
|---|---|---|
| `Core.lua` | 16 | **17** |
| `CorePixel.lua` (`PIXEL_MINOR`) | (new) | **1** |
| `SkinPaintExtras.lua` (`EXTRAS_MINOR`) | 18 | **19** |
| `SkinPaintHud.lua` (`HUD_MINOR`) | (new) | **1** |
| `SkinAceConfirm.lua` (`CONFIRM_MINOR`) | (new) | **1** |
| `Widgets.lua` | 25 | **26** |
| `WidgetsDropdown.lua` (`DROPDOWN_MINOR`) | (new) | **1** |
| `WidgetsLineChart.lua` (`CHART_MINOR`) | 6 | **7** |

Every other file is unchanged. The four new files load in the tag's `LibKa0s.xml` right after the file each was
peeled from: `CorePixel.lua` after `Core.lua`, `SkinPaintHud.lua` and `SkinAceConfirm.lua` after
`SkinPaintExtras.lua`, `WidgetsDropdown.lua` after `Widgets.lua`. No consumer file sits behind its library at the
base: no cross-major skew.

## 3d. Diffs (pre-copy)

`diff -rq --strip-trailing-cr` and `diff -rq` agree (no line-ending drift): the five changed files and `LibKa0s.xml`
differ, the four new files are `Only in <scratch>/LibKa0s`, and every other line is
`Only in <scratch>/LibKa0s/media/icons…` for an undeclared icon. No `Only in libs/LibKa0s` line. The kit is identical
(`diff -rq <scratch>/testkit tests/_kit`).

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`:
unchanged from the v1.90.0 bundle. Of the moved majors, **Core** (38 sites), **Skin** (41) and **Widgets** (14) are
consumed. This addon draws no `W.LineChart` (`grep -rn LineChart . --include='*.lua' --exclude-dir=libs
--exclude-dir=_kit` is empty).

## 3f. Kit revision, and the pairing rule

`grep -n 'Kit.VERSION'`: **51** on both sides. The kit-revision pairing rule (revision 11 or newer with LibKa0s
v1.9.0 or newer) is satisfied; both payloads are still copied whole in one commit.

## 3g. Contract delta

Read for Core, Skin and Widgets in the tag's documents:

- `docs/api/Core/version-17.1-docs.md:25`: "no public or internal member and no behavior changes, so
  `members-17.1.json` lists the same names as version 16".
- `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md:21` (the dropdown peel: "no public member, option or behavior
  changes") and `:33` (the LineChart: "What a host owes: nothing").
- `docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md:21`: "no member of the major or of a facade and no
  behavior changes, so the member manifest lists the same names and a host's Skin facade owes nothing".

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds nothing.
`grep -rn '__releaseChrome\|__Pixel\|__WatchPixels\|__OnPixelScale\|__dropdownKit' . --include='*.lua'
--exclude-dir=libs --exclude-dir=_kit` finds nothing: no host stub mirrors a moved member.

### Blockers

- **`tests/test_libka0s.lua`'s `MAJORS` inventory** names every file of each vendored major it checks, and its
  stray check fails a file that registers a `MODULES` row under a major the table does not own it under. The peels
  add `MODULES.CorePixel` (Core) and `MODULES.SkinPaintHud`, `MODULES.SkinAceConfirm` (Skin), each paired on the
  shell's minor (`__pixelMinor`/`__pixelShellMinor`, `__hudMinor`/`__hudShellMinor`,
  `__confirmMinor`/`__confirmShellMinor`; tag `LibKa0s/CorePixel.lua:23-29`, `SkinPaintHud.lua:22-28`,
  `SkinAceConfirm.lua:21-27`). Fixed in the copy commit: the three files join their majors' `files` and `paired`
  lists in `LibKa0s.xml` order. Widgets is not in that table, so `WidgetsDropdown.lua` needs no row there.
- The harness load list (`tests/run.lua:161`, `Loader.xmlFiles`) is derived from `LibKa0s.xml`, so it picks up the
  four new files in XML order with no edit. No test pins an exact library minor.

The gate after the copy is the final check.

## 3h. Tags vendored and never recorded

The span listing (horizon 2026-08-25): 67 vendored tags, 67 recorded, the unrecorded set **empty**. No span bundle.

## 3i. The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `62:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, segment, settings, star, volume-high.`
The next non-blank line under the provenance line, which ends its own line (no split owed). **Kept as is**
(decided by the run). No library-drawn icon was added in this range. Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the
backstop for a name the host forgot.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/`: `tests/test_mediasetup.lua:147`
reads `Media.ICONS` as the name catalog, `:160-173` open declared names only, `tests/test_settingsui.lua:338` opens
the declared `info.tga`. No blocker.

## Dead stub mirrors

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty. No `__` member was
removed in this range.
