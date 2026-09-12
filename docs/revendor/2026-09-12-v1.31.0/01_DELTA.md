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

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`, as the Source
block above records). Before anything was pushed, a review of that release found defects in the kit-17
fakes, and LibKa0s re-cut the tag on the fixed tree: **`v1.31.0` now points at `e7e1962`**. Commit
**08d155c** re-vendored it, copying both payloads whole from the re-cut tag, and the vendor-sync cases
pass against it.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `libs/LibKa0s/` move in this release, not two: 08d155c touches `OptionsCompose.lua`,
`OptionsWidgets.lua` and `Perf.lua`, plus `tests/_kit/README.md` and `tests/_kit/mock_base.lua`. Any
"the ring trim is not traced" finding recorded above is resolved upstream by Perf minor 11.

Gate on the re-cut payload, at 08d155c (the suite had grown from 824 to 835 between the two cuts'
re-vendor commits, through the #38 harness migration and two unrelated commits):

```
lua tests/run.lua   835 passed, 0 failed, 0 skipped, 835 total
luacheck .          0 warnings / 0 errors in 103 files
```
