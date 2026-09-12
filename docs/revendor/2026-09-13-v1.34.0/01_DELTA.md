# 01 — Delta: LibKa0s v1.33.0 → v1.34.0

Run non-interactively on the orchestrator's instruction (2026-09-13), on branch
`feat/2026-09-12-profiles-buttons`, on top of the v1.33.0 re-vendor (`5cebe6a`). The earlier bundles
are frozen, and this folder is dated and suffixed with the tag so they stay apart.

## Source

```sh
git -C ../LibKa0s rev-parse 'v1.34.0^{commit}'          # 33bae81 (tag object 9165044)
git -C ../LibKa0s archive v1.34.0 LibKa0s testkit | tar -x -C <scratch>/
```

The files come from the tag, not the working tree. The tag is local to `../LibKa0s` (branch
`feat/2026-09-13-v1.34.0`) and is not pushed. `../LibKa0s` HEAD was the tagged commit and its tree
was clean, so `tests/test_vendor_sync.lua` and the copy diff below compare against the same bytes the
copy came from.

## Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.33.0 (MIT).
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
| Slash.lua | MINOR | 9 | **10** |
| Options.lua | MINOR | 17 | **18** |
| OptionsWidgets.lua | WIDGETS_MINOR | 15 | 15 |
| OptionsCompose.lua | COMPOSE_MINOR | 4 | **5** |
| OptionsScroll.lua | SCROLL_MINOR | 3 | 3 |
| Perf.lua | MINOR | 11 | 11 |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

Before the copy, the claim (v1.33.0) and the bytes (v1.33.0's minors) agreed. There is no
cross-major skew.

## Diffs before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # Options.lua, OptionsCompose.lua, Slash.lua differ
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua differ
```

The byte diffs name the same six files, so this is a real content move with no line-ending drift.
Both payloads were replaced whole with `rsync -r --delete --checksum`. Nothing was deleted upstream
and nothing was removed here. After the copy, all four diffs (content and bytes, both payloads) are
empty, and so is the check the release guide names:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit     # empty
```

The runner `tests/_kit/run-automated-tests.sh` keeps mode 100755 and its LF line endings.

## Consumption map

This is unchanged from v1.33.0. Nine majors are consumed, and `Pool` ships unused. All three library
files that moved are consumed: Options and its composers (`settings/OptionsSetup.lua`,
`settings/General.lua`, `settings/MacroBar.lua`) and Slash (`settings/Slash.lua`).

## Kit revision

It was 18 here and is 19 at the tag, and both payloads came from the one tag, so the pairing rule is
met. Revision 19 makes the kit's AceDB fake fire `OnProfileReset` with no key, as AceDB-3.0 does. This
harness never used that fake: `tests/wow_mock.lua` registers its own `AceDB-3.0` over the kit's. That
fake still passed the live key on a reset, which real AceDB does not, so it was brought into line in
this commit (see below).

## The harness's own AceDB fake

`tests/wow_mock.lua`'s `fire(event, key)` handed every callback `key or current`, so a reset (fired
with no key) reached its handler with the active profile's name. It is now `fire(event, ...)` and
passes exactly what it was given: the new key for a switch, the source key for a copy, and nothing for
a reset. That is AceDB-3.0's `(event, db)` for `OnProfileReset`.

Nothing depended on the key. The one registrant is `KCM.RegisterProfileCallbacks`
(`core/ConsumableMaster.lua:418`–`:469`): its `trace` names a reset from `d:GetCurrentProfile()`
(`:438`–`:440`) and reads `key` for a copy only (`:442`), and `reload` passes `key` to nothing but
`trace`. No test registers a profile callback of its own, and no test asserts on a reset's key. The
suite measured 872 / 0 / 0 before and after the change, with the payload still at v1.33.0.

## Live references rolled

- `CLAUDE.md:58`, the provenance line: v1.33.0 → v1.34.0.
- `docs/smoke-tests.md:555` said the band-geometry flip ships "at kit revision 19 at the earliest".
  Revision 19 is vendored now and does not carry it, so it reads "revision 20 at the earliest". That
  matches the kit's own comment at `stubFrame` and the v1.34.0 CHANGELOG.
- `tests/wow_mock.lua`'s AceDB header comment gains the revision-19 half.

## Gate after the copy

```
lua tests/run.lua   873 passed, 0 failed, 0 skipped, 873 total
luacheck .          0 warnings / 0 errors in 107 files
lizard -C 15        0 warnings (no function above CCN 15)
```

The total moved 872 → 873 by one case added in this commit, the Slash minor 10 pin
(`02_CANDIDATES.md`). It was red on the v1.33.0 payload and green after the copy. Without it nothing
moved, which matches the library's own measurement (CHANGELOG v1.34.0: ConsumableMaster 872 → 872).
