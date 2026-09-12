# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Run non-interactively on the owner's bulk-logging instruction (2026-09-12), on branch
`fix/2026-09-12-triage`. The earlier `2026-09-12/` and `2026-09-12-v1.31.0/` bundles are frozen;
this folder is dated and suffixed with the tag so the three stay apart.

## Source

```sh
git -C ../LibKa0s rev-parse 'v1.32.0^{commit}'          # e18dd12 (tag object f5f41c9)
git -C ../LibKa0s archive v1.32.0 LibKa0s testkit | tar -x -C <scratch>/
```

Taken from the tag, which is local to `../LibKa0s` and not pushed, not from the working tree.

## Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.31.0 (MIT).
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
| Slash.lua | MINOR | 7 | **8** |
| Options.lua | MINOR | 15 | **16** |
| OptionsWidgets.lua | WIDGETS_MINOR | 15 | 15 |
| OptionsCompose.lua | COMPOSE_MINOR | 4 | 4 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | 3 |
| Perf.lua | MINOR | 11 | 11 |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

The claim (v1.31.0) and the bytes (v1.31.0's minors) agreed before the copy. No cross-major skew.

## Diffs before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua differ
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # empty
```

Byte diffs named the same two files, so this is a real content move with no line-ending drift. Nothing
was deleted upstream. After copying both payloads, all four diffs (content and bytes, both payloads)
are empty. The runner `tests/_kit/run-automated-tests.sh` keeps mode 100755.

## Consumption map

Unchanged from v1.31.0. Nine majors are consumed and `Pool` ships unused. The two files that moved are
both consumed: Options (`settings/OptionsSetup.lua`) and Slash (`settings/Slash.lua`).

## Kit revision

17 at the tag and 17 here. `testkit/` did not move in v1.32.0, so the pairing rule is met with no kit
change.

## Live references rolled

- `CLAUDE.md:58`, the provenance line, v1.31.0 → v1.32.0.
- `docs/smoke-tests.md:535` said kit revision 17 was "vendored with LibKa0s v1.31.0". It now reads
  "vendored since LibKa0s v1.31.0 and unchanged at v1.32.0".

## Gate after the copy

```
lua tests/run.lua   838 passed, 0 failed, 0 skipped, 838 total
luacheck .          0 warnings / 0 errors in 103 files
```

The suite total did not move. That matches the library's own measurement (CHANGELOG v1.32.0:
"nothing moves on re-vendor"). This addon's Options descriptor has only `get` / `set` and supplies
neither `bulkBegin` nor `bulkEnd`, so both walks run exactly as they did at v1.31.0.
