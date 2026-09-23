# 01 — Delta: LibKa0s v1.54.2 → v1.55.0

Run non-interactively on the orchestrator's instruction (2026-09-23), on branch
`suite/2026-09-22-standards-sweep`, Steps 2–4 of `revendor-libka0s` only: resolve the tag, read the
delta, copy both payloads whole, roll the provenance line. Candidates and adoption (Steps 5–8) are a
later run's, so this bundle carries no `02`–`05` files. Written before the copy; the post-copy
verification at the end was appended before the commit.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.55.0
git -C ../LibKa0s rev-parse --short 'v1.55.0^{commit}'   # 6f9c5e0 (tag object bb161b7)
git -C ../LibKa0s status --short | wc -l                 # 0
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/new/
git -C ../LibKa0s archive v1.54.2 LibKa0s testkit | tar -x -C <scratch>/old/
```

The payload comes from the tag, not the working tree. The tag is local to `../LibKa0s` (not pushed),
whose HEAD is the tagged commit on a clean tree.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.54.2 (MIT).
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/<file>   # before
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' <scratch>/new/LibKa0s/<file>
```

The file list is the tag's `LibKa0s/LibKa0s.xml`, in its load order.

| File | Constant | Before | Tag |
|---|---|---|---|
| Core.lua | MINOR | 7 | 7 |
| Env.lua | MINOR | 1 | 1 |
| Compat.lua | MINOR | absent | **1 (new major `LibKa0s-Compat-1.0`)** |
| Lifecycle.lua | MINOR | 1 | 1 |
| Bus.lua | MINOR | absent | **1 (new major `LibKa0s-Bus-1.0`)** |
| Schema.lua | MINOR | absent | **1 (new major `LibKa0s-Schema-1.0`)** |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | 1 |
| Media.lua | MINOR | 3 | 3 |
| Widgets.lua | MINOR | 9 | 9 |
| WidgetsDragHandle.lua | DRAG_MINOR | 2 | 2 |
| DebugLog.lua | MINOR | 12 | 12 |
| Slash.lua | MINOR | 14 | 14 |
| Launcher.lua | MINOR | 1 | 1 |
| Options.lua | MINOR | 23 | 23 |
| OptionsWidgets.lua | WIDGETS_MINOR | 30 | 30 |
| OptionsTabs.lua | TABS_MINOR | 3 | 3 |
| OptionsCompose.lua | COMPOSE_MINOR | 7 | 7 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | 3 |
| Perf.lua | MINOR | 12 | 12 |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

The claim (v1.54.2) and the bytes agree: the vendored copy is byte-identical to the v1.54.2 tag
(`diff -rq <scratch>/old/LibKa0s libs/LibKa0s` and `diff -rq <scratch>/old/testkit tests/_kit`, both
empty). No existing file's minor moves, so there is **no cross-major skew** before or after.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/new/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
diff -rq                     <scratch>/new/testkit tests/_kit
```

Content and bytes report the same set, so nothing here is a line-ending disagreement:

- library: `Only in <tag>`: `Bus.lua`, `Compat.lua`, `Schema.lua`; differs: `LibKa0s.xml` (the three
  new `<Script>` rows).
- kit: `Only in <tag>`: `test_layout_cap.lua`; differs: `README.md`, `framework.lua`,
  `run-automated-tests.sh`, `test_eol.lua`, `test_prose.lua`.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing was removed upstream, so the copy
  deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' \
  | grep -v '^libs/' | grep -v '^tests/'
```

| Major | Lookup site |
|---|---|
| Core | `core/CoreSetup.lua:64` |
| Env | `core/EnvSetup.lua:57` |
| Lifecycle | `core/LifecycleSetup.lua:49` |
| Item | `core/ItemSetup.lua:34` |
| Media | `core/MediaSetup.lua:61` |
| DebugLog | `core/DebugLogSetup.lua:59` |
| Launcher | `core/LauncherSetup.lua:93` |
| Perf | `core/PerfSetup.lua:38` |
| Options | `settings/OptionsSetup.lua:167` |
| Slash | `settings/Slash.lua:415` |
| Widgets | `modules/MacroBar.lua:44`, `settings/Category.lua:79`, `settings/MacroBar.lua:723`, `settings/StatPriority.lua:122` |

Unadopted majors in the payload: **Pool** (reached only through the library itself), and the three
new ones — **Compat**, **Bus** and **Schema**. This addon carries its own `core/Compat.lua`,
`core/Bus.lua` and settings schema, so all three are whole-module (class C) candidates for the next
run's Step 5; nothing is adopted here.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/new/testkit/framework.lua:20:Kit.VERSION = 25
# tests/_kit/framework.lua:20:Kit.VERSION = 24
```

Revision 24 → 25. Both payloads move in one commit (the rule written for v1.9.0 / revision 11 is
satisfied by construction), because `tests/test_vendor_sync.lua` compares both against the tag the
provenance line names.

## 3g. Contract delta — Blockers

**Library: none.** 3c moves no minor under any major 3e says this addon looks up, so there is no
`docs/api/<Major>/` pair to diff and no host-supplied member whose call site could have moved. The
changelog states the same: "No existing `.lua` file in the library changes — every existing major's
version key and every existing file's LibStub minor are exactly v1.54.2's"
(`git -C ../LibKa0s show v1.55.0:CHANGELOG.md`, the v1.55.0 block). `__Attach*` sites in this addon:
none (`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is
empty).

**Kit: one contract tightened under a surface whose shape did not move, and it is a blocker.** The
suites list handed to `Kit.run` keeps its shape, but revision 25 keys a declaration by the pair
(basename, directory) instead of the bare basename (`framework.lua`, the new `suiteDeclarations` /
`collectKitHoles`; `testing-§9`). Against this runner that changes the meaning of two existing
entries without changing a byte of them:

- `"test_prose"` wires `tests/test_prose.lua`, the repo's own hand-written gate, and under revision
  24 also answered for `tests/_kit/test_prose.lua`, which therefore never ran. Under revision 25 that
  is a **collision**: a failure naming both paths.
- `"test_layout_cap"` wires `tests/test_layout_cap.lua`, the repo's own hand-written cap gate, and
  the kit now ships `tests/_kit/test_layout_cap.lua`. Same collision.

Resolved in the vendor commit, beside the payload and the provenance line, by the conforming reading
of both rules rather than by a decline:

- `layout-§1` (MUST, from revision 25): wire the kit's cap gate "rather than write its own". The
  hand-written `tests/test_layout_cap.lua` is deleted and `{ name = "test_layout_cap",
  dir = "tests/_kit/" }` declared.
- `localization-§5` (SHOULD): the gate should be the kit's, and a repo "wires one or the other,
  never both"; declining the kit's copy is a deviation that would need a register row. The
  hand-written `tests/test_prose.lua` is deleted and `{ name = "test_prose", dir = "tests/_kit/" }`
  declared. The kit carries the same published lists, and reads the tracked set from git as the
  local copy did.
- `test_eol` keeps its kit declaration, respelled to the literal `dir = "tests/_kit/"` form
  `testing-§9` prescribes so the three kit suites read alike.

The census obligation `layout-§1` attaches to the gate was prepared in its own commit ahead of this
one: `### Files over the 1500-line cap` moved under `## Documented deviations`.

## After the copy (Step 4)

```sh
cp -r <scratch>/new/LibKa0s/. libs/LibKa0s/
cp -r <scratch>/new/testkit/. tests/_kit/
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -rq                     <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit      # empty
diff -rq                     <scratch>/new/testkit tests/_kit      # empty
```

Content and bytes both clean in both payloads; nothing deleted inside `libs/` or `tests/_kit/`. The
provenance line in `CLAUDE.md` rolls v1.54.2 → v1.55.0 in the same commit; `README.md` carries no
provenance line to remove.

Gate, before and after (`ka0s-bounded lua tests/run.lua`, `ka0s-bounded luacheck .`, from the repo
root):

| | Tests | Lint |
|---|---|---|
| Before (v1.54.2, kit 24) | 958 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 118 files |
| After (v1.55.0, kit 25) | 982 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 116 files (the two deleted gates were two of the 118) |

The +24 is the swap, not new coverage of this addon: the two hand-written gates (3 + 2 cases) leave,
and the kit's `test_layout_cap` (13 cases, five of them over this tree, the rest self-tests) and
`test_prose` (15, two over this tree) arrive; `test_eol` gains its `.gitattributes` canonical-body
case, which passes on this repo's existing file. `.luacheckrc` excludes `libs/` and `tests/_kit/`, so
lint does not see the payload either way.
