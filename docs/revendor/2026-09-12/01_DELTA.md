# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.30.0 LibKa0s testkit`. The tag is the newest
(`git -C ../LibKa0s tag --sort=-v:refname | head -1` → `v1.30.0`); it sits on the library's
`fix/kit-27-30` branch and is not yet on its `master`, which does not matter here, because
`tests/test_vendor_sync.lua` resolves the **tag** the provenance line names, not a branch.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> `CLAUDE.md:58` — Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.29.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9, DebugLog 12, Slash 7, Options 15,
`WIDGETS_MINOR` 14, `SCROLL_MINOR` 3, Perf 10, `PANEL_MINOR` 5 — exactly the v1.29.0 version
block. The line and the bytes **agreed**.

## 3c — Per-file minor delta

Read from the tag's `LibKa0s/LibKa0s.xml` (14 files: Core, Env, Pool, Item, Media, Widgets,
DebugLog, Slash, Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel).

| File | v1.29.0 | v1.30.0 |
|---|---|---|
| every shipped file | unchanged | unchanged |

The same grep over the tag's `LibKa0s/`, sorted, is identical to the one above. **No file in
`LibKa0s/` moved**; v1.30.0 is kit revision 16 alone. **No cross-major skew.**

## 3d — Both diffs, both directions

```
diff -r --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # empty
diff -r                     <tag>/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr <tag>/testkit tests/_kit     # 4 files: README.md, framework.lua, mock_base.lua, vendor_sync.lua
diff -r                     <tag>/testkit tests/_kit     # the same 4 files
```

Content-dirty in exactly the four kit files the release touched. **No `Only in` lines** in
either payload, so nothing was removed upstream and no deletion inside `libs/` or
`tests/_kit/` is warranted.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Unchanged by this release (no library file moved): Core, DebugLog, Env, Item, Media, Options,
Perf, Slash and Widgets are consumed; `Pool` is vendored and not consumed, as before.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

`Kit.VERSION` **15 → 16**. Both payloads are copied whole in the same commit — the rule since
revision 11, when `vendor_sync.lua` stopped reading `media` as a file and stopped normalising
line endings across binaries — so this repo never holds a kit that cannot compare the library it
ships.

Revision 16 is **not** the geometry flip v1.27.0's entry announced for it; that moved to 17 at
the earliest (`CHANGELOG.md` v1.30.0, "Revision 16 is not the geometry flip").
