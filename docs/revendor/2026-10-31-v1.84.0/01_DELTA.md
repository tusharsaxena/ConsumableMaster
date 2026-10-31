Delta: LibKa0s v1.83.0 -> v1.84.0

Run: the findings remediation's M2 library release (Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`), multi-repo with nobody to interview.
The tag is local (`e917ccd`), extracted with `git archive v1.84.0 LibKa0s testkit tools`.

## 3a. Claimed version

`grep -n '[Bb]undles' CLAUDE.md` gives line 61, v1.83.0. The last payload commit is `c7658c6`
(`git log -1 --format=%H -- libs/LibKa0s tests/_kit`), and its line also names v1.83.0, so the base
is v1.83.0. Step 0: the newest single-tag bundle, `2026-10-24-v1.77.0`, states base v1.76.0 and the
provenance before `1373242` was v1.76.0, so no correction is owed.

## 3b. Actual version

The payload matches v1.83.0: `diff -rq --strip-trailing-cr` of the v1.83.0 extract against
`libs/LibKa0s` and `tests/_kit` shows only the undeclared icons. No skew.

## 3c. Per-file minors that moved

`git show v1.84.0:LibKa0s/LibKa0s.xml` for the list, old against tag with the spec's grep. Every
other file is unchanged; `new` in the old column is a file new in this range.

| File | Old | New |
|---|---|---|
| `Schema.lua` | 2 | 3 |
| `Charts.lua` | new | 1 |
| `ChartsRender.lua` | new | 1 |
| `Skin.lua` | 10 | 11 |
| `SkinOwnerTokens.lua` | new | 1 |
| `SkinDefs.lua` | 18 | 19 |
| `SkinDefsOthers.lua` | new | 1 |
| `WidgetsDragHandle.lua` | 8 | 10 |
| `DebugLogDiagnostics.lua` | 5 | 6 |
| `Slash.lua` | 20 | 21 |
| `Options.lua` | 34 | 35 |
| `OptionsWidgets.lua` | 38 | 40 |
| `OptionsFlow.lua` | new | 2 |
| `OptionsIds.lua` | 5 | 6 |
| `OptionsIdSuggest.lua` | new | 1 |
| `OptionsTabs.lua` | 11 | 13 |
| `OptionsTabbed.lua` | new | 2 |
| `OptionsCompose.lua` | 14 | 15 |
| `OptionsSkinPicker.lua` | 4 | 5 |
| `OptionsSkinPickerRows.lua` | new | 1 |
| `SimPanel.lua` | 8 | 9 |
| `SimPanelRender.lua` | new | 1 |

## 3d. Diffs

Run again after the copy; see `05_SUMMARY.md`. Before the copy, the only content differences to the
tag are the release's own.

## 3e. Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside libs and tests: Skin, Bus, Core,
Compat, Env, DebugLog, Item, Perf, Media, Launcher, Lifecycle, Widgets, Options, Schema, Slash.
`LibKa0s-Charts-1.0` (new) has no lookup here and this addon draws no chart. Toast, Glow, Pool and
Sim are unchanged from the last record.

## 3f. Kit revision

46 -> 47 (`grep -n 'Kit.VERSION'`). The two payloads move together in one commit, the pairing rule.

## 3g. Contract delta

Moved majors intersected with lookups: Options, Widgets, Schema, Slash, Skin, DebugLog. Read:
`docs/api/<Major>` at the old and the new key, diffed for sentences under existing surfaces.

No tightened contract under a member this addon supplies. Host hook sites are unchanged.
WidgetsDragHandle minor 10 repeats the host's last `ApplyWidth` when a fitted strip shows
(`docs/api/Widgets/version-17.3.10.5.5.2-docs.md`, *What a consumer owes*). That is intended, and it
is delivered free to `modules/MacroBar.lua`.

### Blockers, all fixed in the re-vendor commit

- The library-absent Options arm owes `O.PositionBlock`, a new public member
  (`docs/api/Options/version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1-docs.md`, *a new public
  member*). `settings/OptionsSetup.lua` publishes it, answering no rows and a no-op hook.
- `tests/test_libka0s.lua` types the Options and Skin majors' files and paired minors. The four new
  Options files and the two new Skin files are named there. It lists no Sim or Charts entry, so
  `SimPanelRender` and the Charts pair need none.

## 3h. Tags vendored and not recorded

The listing is empty. The audit's walk gives v1.15.0, v1.25.0 and v1.30.0 only when the undated
folders are skipped; those are `2026-08-25`, `2026-09-03` and `2026-09-12`, whose line 1 records them.

## 3i. Icon declaration

Kept: `clear, close, copy, help, info, segment, settings.` No library-drawn name was added in this
range. All Open Iconic, so the README's credits are unchanged. Hand lists have drifted before; the
owner's smoke is the backstop, since a pruned icon resolves to a path and draws blank.

## 3j. Tests that assume the whole folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua'` (outside `_kit`):
`tests/test_mediasetup.lua` and `tests/test_settingsui.lua` already hold to declared names. None
blocks.
