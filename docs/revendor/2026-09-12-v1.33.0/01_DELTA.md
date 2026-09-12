# 01 — Delta: LibKa0s v1.32.0 → v1.33.0

Run non-interactively on the orchestrator's instruction (2026-09-12), as the last commit on branch
`feat/2026-09-12-profiles-buttons`, after the Profiles commit (`33da0af`) and the Buttons-tab commit
(`0add959`). The earlier bundles are frozen, and this folder is dated and suffixed with the tag so
they stay apart.

## Source

```sh
git -C ../LibKa0s rev-parse 'v1.33.0^{commit}'          # 06ee368 (tag object 7d5e061)
git -C ../LibKa0s archive v1.33.0 LibKa0s testkit | tar -x -C <scratch>/
```

The files come from the tag, not the working tree. The tag is local to `../LibKa0s` (branch
`feat/2026-09-12-v1.33.0`) and is not pushed. `../LibKa0s` HEAD was the tagged commit and its tree
was clean, so `tests/test_vendor_sync.lua` and the copy diff below compare against the same bytes the
copy came from.

## Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.32.0 (MIT).
```

## Per-file minors

| File | Constant | Before | Tag |
|---|---|---|---|
| Core.lua | MINOR | 7 | 7 |
| Env.lua | MINOR | 1 | 1 |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | 1 |
| Media.lua | MINOR | 3 | 3 |
| Widgets.lua | MINOR | 9 | 9 |
| DebugLog.lua | MINOR | 12 | 12 |
| Slash.lua | MINOR | 8 | **9** |
| Options.lua | MINOR | 16 | **17** |
| OptionsWidgets.lua | WIDGETS_MINOR | 15 | 15 |
| OptionsCompose.lua | COMPOSE_MINOR | 4 | 4 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | 3 |
| Perf.lua | MINOR | 11 | 11 |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

Before the copy, the claim (v1.32.0) and the bytes (v1.32.0's minors) agreed. There is no
cross-major skew.

## Diffs before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua differ
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua differ
```

The byte diffs name the same five files, so this is a real content move with no line-ending drift.
Both payloads were replaced whole with `rsync -r --delete`. Nothing was deleted upstream and nothing
was removed here. After the copy, all four diffs (content and bytes, both payloads) are empty, and so
is the check the release guide names:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit     # empty
```

The runner `tests/_kit/run-automated-tests.sh` keeps mode 100755 and its LF line endings.

## Consumption map

This is unchanged from v1.32.0. Nine majors are consumed, and `Pool` ships unused. Both library files
that moved are consumed: Options (`settings/OptionsSetup.lua`) and Slash (`settings/Slash.lua`).

## Kit revision

It was 17 here and is 18 at the tag, and both payloads came from the one tag, so the pairing rule is
met. Revision 18 makes the kit's AceDB fake hand `OnProfileCopied` the copy's **source** key, as
AceDB-3.0 does. This addon's harness never used that fake. `tests/wow_mock.lua` registers its own
`AceDB-3.0` over the kit's, and that fake has fired `OnProfileCopied` with the source key since the
v1.32.0 pass. Nothing in the suite moves.

## Live references rolled

- `CLAUDE.md:58`, the provenance line: v1.32.0 → v1.33.0.
- `docs/smoke-tests.md:555` said the band-geometry flip ships "at kit revision 18 at the earliest
  (revision 17 … does not carry it)". Revision 18 is vendored now and does not carry it either, so
  it reads "revision 19 at the earliest". That matches the kit's own comment at `stubFrame`.
- `tests/wow_mock.lua:356` gave "no … profile key" as a reason for keeping the local AceDB fake.
  Since revision 18 the kit passes each event its own key, so that half is corrected. The other
  reasons still hold: the kit calls every callback as a plain function, with no CallbackHandler
  string-method form, and it keeps the store as `sv.profiles` rather than `db.profiles`.

## Gate after the copy

```
lua tests/run.lua   872 passed, 0 failed, 0 skipped, 872 total
luacheck .          0 warnings / 0 errors in 107 files
lizard -C 15        no thresholds exceeded
```

The suite total did not move (872 before the copy and after it). That matches the library's own
measurement (CHANGELOG v1.33.0: "nothing moves in any consumer").
