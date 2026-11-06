Delta: LibKa0s v1.89.0 -> v1.90.0

Written before the copy. Run item `SF1-RV-CM` of the Ka0sAddonsCommonTasks bundle
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (its `SF1_SMOKE_FEEDBACK.md` holds the owner's rulings). Payload taken
from the tag v1.90.0 (`4485b8f`), which is **local** to the `../LibKa0s` checkout and not pushed, so
`git ls-remote --tags origin v1.90.0` prints nothing. That is expected: the provenance line names v1.89.0, so this
is a new re-vendor, not a refresh. Extract:
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/sf1-rv-cm/new`.

## Step 0 (pre-flight)

Newest single-tag bundle `2026-11-06-v1.89.0`, line 1 `Delta: LibKa0s v1.85.0 -> v1.89.0`; the re-vendor commit
`5c7ecfe` has parent provenance v1.85.0 (`git show 5c7ecfe^:CLAUDE.md`). `ok`. No base correction.

## 3a. Claimed version, and the base

`grep -n '[Bb]undles' CLAUDE.md` -> `61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).`

Last commit touching either payload: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `5c7ecfe`, whose
`CLAUDE.md` names v1.89.0; `git log 5c7ecfe..HEAD -- CLAUDE.md` is empty. Against a v1.89.0 extract,
`diff -rq` shows the kit identical and the library identical apart from undeclared icons. **Base v1.89.0.**

Range: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0` (7 commits: `4485b8f`, `4ac9f3c`, `b9f7651`, `7d42f4e`,
`e809ca3`, `72733ee`, `1ca12c6`); `git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 -- LibKa0s testkit tools`:
`Core.lua`, `OptionsAppearance.lua`, `Skin.lua`, `SkinPaint.lua`, `SkinPaintExtras.lua`, `Widgets.lua`,
`WidgetsAutocomplete.lua` (7 files, +209 -57). `testkit/` and `tools/` did not move.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` agrees with v1.89.0 on every
file. Line and bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s.xml` loop)

| File | Old | New |
|---|---|---|
| `Core.lua` | 15 | **16** |
| `Skin.lua` | 16 | **17** |
| `SkinPaint.lua` (`PAINT_MINOR`) | 18 | **19** |
| `SkinPaintExtras.lua` (`EXTRAS_MINOR`) | 17 | **18** |
| `Widgets.lua` | 23 | **24** |
| `WidgetsAutocomplete.lua` (`AUTOCOMPLETE_MINOR`) | 7 | **8** |
| `OptionsAppearance.lua` (`APPEARANCE_MINOR`) | 6 | **7** |

Every other file is unchanged; no new file. No consumer file sits behind its library at the base: no
cross-major skew.

## 3d. Diffs (pre-copy)

`diff -rq --strip-trailing-cr` and `diff -rq` agree (no line-ending drift): the seven files above differ. Every other
line is `Only in <scratch>/LibKa0s/media/icons…` for an undeclared icon. No `Only in libs/LibKa0s` line. The kit is
identical (`diff -rq <scratch>/testkit tests/_kit`).

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' --exclude-dir=libs --exclude-dir=tests`:
unchanged from the v1.89.0 bundle. Of the moved majors, **Core**, **Skin**, **Widgets** and **Options** are consumed.

## 3f. Kit revision, and the pairing rule

`grep -n 'Kit.VERSION'`: **51** on both sides. The kit-revision pairing rule (revision 11 or newer with LibKa0s
v1.9.0 or newer) is satisfied; both payloads are still copied whole in one commit.

## 3g. Contract delta

Read for Core, Skin, Widgets and Options in the tag's documents:

- `docs/api/Core/version-16-docs.md:14`: "the same members"; the new `__PixelSize`, `__WatchPixels`,
  `__OnPixelScale`, `__PixelBackdrop` are internal, so no member manifest moves.
- `docs/api/Widgets/version-24.5.12.6.8.5-docs.md:27`: "What a host owes: nothing. A host's own `edgeSize = 1`
  backdrops are its own".
- `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md:21,31`: no member added, removed or renamed, "a host's
  Skin facade owes nothing".
- `docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md:26`: "a host whose Scope is a
  documented deviation registers with `keepScope = true`; every other host owes nothing". This addon's
  `Skin:RegisterOwner` (`core/SkinSetup.lua:769`) documents no Scope deviation; the SF1 rulings give `keepScope`
  to the Skin Tester alone (`SF1-ST`).

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds nothing.

### Blockers

None found by reading. The gate after the copy is the check.

## 3h. Tags vendored and never recorded

The span listing (horizon 2026-08-25): 66 vendored tags, 66 recorded, the unrecorded set **empty**. No span bundle.

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
