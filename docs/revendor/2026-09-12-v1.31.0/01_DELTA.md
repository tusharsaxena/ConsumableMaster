# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Run non-interactively on the owner's triage instruction (2026-09-12, wave B2), on branch
`fix/2026-09-12-triage`. The earlier `2026-09-12/` bundle is the v1.29.0 → v1.30.0 move from the
same day and is frozen; this folder is dated and suffixed with the tag so the two stay apart.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.31.0
git -C ../LibKa0s rev-parse 'v1.31.0^{commit}'          # 30db4ed
git -C ../LibKa0s archive v1.31.0 LibKa0s testkit | tar -x -C <scratch>/
```

Taken from the tag, not the working tree.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.30.0 (MIT).
```

## 3b/3c. Actual version, per-file minors (file list from the tag's `LibKa0s/LibKa0s.xml`)

```sh
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
grep -nE 'COMPOSE_MINOR *=' libs/LibKa0s/OptionsCompose.lua
```

| File | Constant | Before | Tag |
|---|---|---|---|
| Core.lua | MINOR | 7 | 7 |
| Env.lua | MINOR | 1 | 1 |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | 1 |
| Media.lua | MINOR | 3 | 3 |
| Widgets.lua | MINOR | 9 | 9 |
| DebugLog.lua | MINOR | 12 | 12 |
| Slash.lua | MINOR | 7 | 7 |
| Options.lua | MINOR | 15 | 15 |
| OptionsWidgets.lua | WIDGETS_MINOR | 14 | **15** |
| OptionsCompose.lua | COMPOSE_MINOR | 3 | **4** |
| OptionsScroll.lua | SCROLL_MINOR | 3 | 3 |
| Perf.lua | MINOR | 10 | 10 |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

The claim (v1.30.0) and the bytes (v1.30.0's minors) agreed before the copy. No cross-major skew.
`OptionsCompose.lua` carries `COMPOSE_MINOR`, which the skill's grep does not name; it was read
separately.

## 3d. Diffs before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua differ
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua differ
```

Byte diffs named the same files: a real content move, no line-ending-only drift. No
`Only in libs/LibKa0s` or `Only in tests/_kit` lines, so nothing was deleted.

After `cp -r` of both payloads, all four diffs (content and bytes, both payloads) are empty.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Item (`core/ItemSetup.lua:34`), Core (`core/CoreSetup.lua:64`), Env (`core/EnvSetup.lua:57`),
DebugLog (`core/DebugLogSetup.lua:59`), Perf (`core/PerfSetup.lua:38`), Media
(`core/MediaSetup.lua:61`), Widgets (`settings/Category.lua:78`, `settings/StatPriority.lua:122`),
Slash (`settings/Slash.lua:257`), Options (`settings/OptionsSetup.lua:96`). Nine majors consumed;
`Pool` ships unused, as before. Unchanged from v1.30.0.

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# 17 at the tag, 16 here
```

Kit revision 16 → **17**. Both payloads move in one commit, as the pairing rule (revision 11+ for
v1.9.0+) requires and as `tests/test_vendor_sync.lua` enforces.

## Live references rolled

- `CLAUDE.md:58`, the provenance line, v1.30.0 → v1.31.0.
- `docs/smoke-tests.md:535` said the geometry flip lands "at kit 16". v1.31.0's CHANGELOG moves it to
  revision 18 at the earliest; the sentence now says so.

No other live v1.30.0 reference exists outside the frozen bundles.

## Gate after the copy

```
lua tests/run.lua   824 passed, 0 failed, 0 skipped, 824 total
luacheck .          0 warnings / 0 errors in 102 files
```

The suite total did not move, matching the library's own measurement ("nothing moves",
CHANGELOG v1.31.0 → *Adoption*): this harness still replaces the kit's Ace fakes at this commit.
`luacheck` excludes `libs/` and `tests/_kit/`, so its 0/0 covers the addon and its own harness, not
the payload; `test_vendor_sync.lua` covers the payload.
