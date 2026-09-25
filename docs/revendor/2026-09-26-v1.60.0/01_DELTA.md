# 01 - Delta: LibKa0s v1.58.0 -> v1.60.0

Run non-interactively as item DR-CM-01 of the 2026-09-25 diagnostics-command rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`, milestone M3), on branch
`feat/2026-09-25-diagnostics-rollout`, on 2026-09-26. Steps 1-4 of `revendor-libka0s` (resolve the
tag, read the delta, copy both payloads whole, roll the provenance line), plus the edits the plan puts
in the re-vendor commit so the suite stays green. The candidate interview is answered from the plan
(`03_EXECUTION_PLAN.md`, "M3: per addon"); see `03_DECISIONS.md`.

v1.59.0 was never vendored here. This run carries both releases at once.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.60.0
git -C ../LibKa0s rev-parse --short 'v1.60.0^{commit}'   # bed0eb1
git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.58.0 (MIT).
```

The line and the payload agree on v1.58.0 (below). Base suite before the copy:
`lua5.1 tests/run.lua` 1078 passed, 0 failed, 0 skipped.

```sh
git -C ../LibKa0s log --oneline v1.58.0..v1.60.0 | wc -l                    # 17
git -C ../LibKa0s diff --stat v1.58.0 v1.60.0 -- LibKa0s testkit | tail -1
# 8 files changed, 868 insertions(+), 39 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua | sort
# and the same over <scratch>/LibKa0s/*.lua, then diff
```

File list read from the tag's `LibKa0s/LibKa0s.xml` (twenty-two files).

| File | Constant | Before | Tag |
|---|---|---|---|
| WidgetsDragHandle.lua | DRAG_MINOR | 2 | **3** (v1.59.0) |
| DebugLog.lua | MINOR | 13 | **14** |
| DebugLogDiagnostics.lua | DIAG_MINOR | (absent) | **1** (new secondary file of the DebugLog major) |
| Slash.lua | MINOR | 15 | **16** |

Every other file is unchanged. No `NEEDS_*` floor rises and no major is added. The whole-folder copy
moves every file together, so there is no cross-major skew; the consumer was behind on nothing it
did not also lack the newer file for.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s
# differs: DebugLog.lua, LibKa0s.xml, Slash.lua, WidgetsDragHandle.lua
# Only in <scratch>/LibKa0s: DebugLogDiagnostics.lua
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same five lines
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
# differs: README.md, framework.lua
# Only in <scratch>/testkit: test_diagnostics_contract.lua
diff -rq                     <scratch>/testkit tests/_kit     # the same three lines
```

Content and bytes agree: a genuine version gap, not a line-ending disagreement. Nothing is
`Only in libs/LibKa0s` or `Only in tests/_kit`, so the copy deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '^libs/' | grep -v '^tests/'
```

Env (`core/EnvSetup.lua:57`), Core (`core/CoreSetup.lua:64`), Compat (`core/Compat.lua:33`), Item
(`core/ItemSetup.lua:34`), Bus (`core/Bus.lua:53`), DebugLog (`core/DebugLogSetup.lua:59`), Media
(`core/MediaSetup.lua:61`), Lifecycle (`core/LifecycleSetup.lua:49`), Perf (`core/PerfSetup.lua:39`),
Launcher (`core/LauncherSetup.lua:98`), Widgets (`modules/MacroBar.lua:44`, `settings/Category.lua:79`,
`settings/StatPriority.lua:122`, `settings/MacroBar.lua:720`), Schema (`settings/SchemaStub.lua:4`,
`settings/Panel.lua:166`), Options (`settings/OptionsSetup.lua:164`), Slash (`settings/Slash.lua:426`).
Fourteen majors consumed; `Pool` ships unused, as recorded in `CLAUDE.md`. Unchanged by this release.

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 27
# tests/_kit/framework.lua:20:Kit.VERSION = 26
```

Kit 26 -> 27 (the new shared suite `test_diagnostics_contract.lua`). The two payloads move together
in one commit, as the pairing rule requires (kit revision 11 or newer for LibKa0s v1.9.0+).

## 3g. Contract delta

Moved majors this addon consumes: DebugLog (13 -> 14.1), Slash (15 -> 16), Widgets (10.2 -> 10.3).

```sh
diff <(git -C ../LibKa0s show v1.58.0:docs/api/DebugLog/version-13-docs.md) \
     <(git -C ../LibKa0s show v1.60.0:docs/api/DebugLog/version-14.1-docs.md)
# likewise Slash/version-15 -> version-16 and Widgets/version-10.2 -> version-10.3
```

No `__Attach*` entry point is used by this addon
(`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty),
so no host-supplied callback member has a moved call site.

### Blockers (resolved in the re-vendor commit)

1. **`lib.MAX_BUFFER` 1500 -> 3000** (and `BUFFER_SLACK` 64 -> 128). DebugLog `version-13-docs.md`
   `lib.MAX_BUFFER` row ("1500 as of minor 11") against `version-14.1-docs.md` ("3000 as of minor 14;
   1500 from minor 11 through 13"). `tests/test_debuglog.lua:281` pins `t.eq(lib.MAX_BUFFER, 1500)`,
   which goes red on the copy. Re-pinned to 3000 in the same commit (plan DR-CM-01, BUF-07). The pin
   stays a literal on purpose: it asserts the addon's docs and the library agree on the one number.
2. **Slash `LIVE_VERBS` gains `diagnostics`.** `version-16-docs.md`: "A host that passes a literal
   `liveVerbs` array adds `"diagnostics"` to it". This addon passes a literal array
   (`settings/Slash.lua:325-329`, handed over at `:524`), and the library uses that array instead of
   its default (`Slash.lua:508`), so the verb would be refused while disabled. Added in the same commit
   (plan finding C1). No verb named `diagnostics` exists until DR-CM-03, so today the entry changes
   nothing a user can see.
3. **The DebugLog stub gains `RunDiagnostics`** (v1.60.0 changelog, "What a consumer owes"; standard
   STD-14). This addon's degraded arm falls back to chat, which a report would flood (plan finding C2),
   so the stub prints the one library-absent line (`L["%s is unavailable: the LibKa0s library did not
   load."]` naming `/cm diagnostics`), writes nothing and returns 0. The live facade forwards to the
   instance. `tests/test_surface_parity.lua`'s `DEBUGLOG_SEAM` gains the member.

Widgets 10.3 (DragHandle minor 3): "What a host must change: nothing, unless it wants an X". This
addon passes no `onClose`, so its strips draw exactly the minor-2 pixels. No blocker.

## The kit's new suite

`tests/run.lua`'s `SUITES` gains `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }`. With
`Kit.diagnostics` unset it registers one declared skip until DR-CM-03 wires the dispatcher.
