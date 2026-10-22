Delta: LibKa0s v1.71.0 -> v1.75.0

Run non-interactively as item CM-RV of the 2026-10-22 "LibKa0s issues #45-#58" run, on branch
`feat/2026-10-22-libka0s-issues-45-58`, following the `/dev-copilot:wow-revendor-libka0s` 2.4.0
conventions (icon declaration and prune) and LibKa0s `docs/releasing.md` "Re-vendoring consumers".
The run's owner scope assigns ConsumableMaster no adoption, so this re-vendor is mechanical: copy
both payloads whole, roll the provenance line, declare and prune the icons, fix the contract
blockers the copy raises, write this bundle. No interview, no GitHub issue.

## Source

```sh
git -C ../LibKa0s tag -l v1.75.0                                   # v1.75.0 (local only, not pushed)
git -C ../LibKa0s rev-parse --short 'v1.75.0^{}'                   # 265a89e (annotated tag object eae0ee5)
git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>
```

The payload is taken from the tag through `git archive`, never from the LibKa0s working tree, and
`tools/prune-icons.lua` is run from the same export. The tag is local; its push waits on the owner.

## Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# b4060c3 RV-CM: re-vendor LibKa0s v1.71.0; record v1.69.0-v1.70.0 span (CM-A-01)
git archive b4060c3 libs/LibKa0s tests/_kit | tar -x -C <scratch>/base
diff -rq --strip-trailing-cr <scratch>/base/libs/LibKa0s <scratch>/v1.71.0/LibKa0s   # (empty)
diff -rq --strip-trailing-cr <scratch>/base/tests/_kit   <scratch>/v1.71.0/testkit   # (empty)
```

Base v1.71.0, agreed by the provenance line, the last payload commit and the bytes. **No span
bundle:** v1.72.0, v1.73.0 and v1.74.0 were never vendored here, so there is no unrecorded vendored
tag to consolidate. This bundle covers the whole v1.71.0 -> v1.75.0 range.

## Range

```sh
git -C ../LibKa0s log --oneline v1.71.0..v1.75.0 | wc -l           # 56
git -C ../LibKa0s diff --stat v1.71.0 v1.75.0 -- LibKa0s testkit ':!LibKa0s/media/icons'
#  26 files changed, 4536 insertions(+), 121 deletions(-)
```

New library files: `OptionsDrawer.lua` (v1.73.0), `MediaIcons.lua` with the `phosphor/` and
`game-icons/` icon sets (v1.74.0), `Glow.lua`, `Sim.lua`, `SimPanel.lua`, `SimTimeline.lua`
(v1.75.0). `WidgetsStepPanel.lua` does **not** arrive: LibKa0s#53's step panel landed Sim-private
inside `SimPanel.lua` (LK-11 outcome B), so `W.StepPanel` is not a public surface. The kit gains
`latch.lua`. The library folder has 40 `.lua` files.

## Per-file minor delta

| File | Major | v1.71.0 | v1.75.0 |
|---|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0` | 10 | **11** |
| `DebugLog.lua` | `LibKa0s-DebugLog-1.0` | 19 | **20** |
| `DebugLogDiagnostics.lua` | `LibKa0s-DebugLog-1.0` | 2 | **3** |
| `Item.lua` | `LibKa0s-Item-1.0` | 2 | **3** |
| `Media.lua` | `LibKa0s-Media-1.0` | 4 | **5** |
| `MediaIcons.lua` | `LibKa0s-Media-1.0` | (new) | **1** |
| `Options.lua` | `LibKa0s-Options-1.0` | 28 | **29** |
| `OptionsTabs.lua` | `LibKa0s-Options-1.0` | 8 | **9** |
| `OptionsIdList.lua` | `LibKa0s-Options-1.0` | 4 | **5** |
| `OptionsDrawer.lua` | `LibKa0s-Options-1.0` | (new) | **1** |
| `Perf.lua` | `LibKa0s-Perf-1.0` | 14 | **15** |
| `PerfPanel.lua` | `LibKa0s-Perf-1.0` | 6 | **7** |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` | 12 | **13** |
| `Glow.lua` | `LibKa0s-Glow-1.0` | (new major) | **1** |
| `Sim.lua`, `SimPanel.lua`, `SimTimeline.lua` | `LibKa0s-Sim-1.0` | (new major) | **1** each |
| test kit `framework.lua` | `Kit.VERSION` | 38 | **41** |

Every other library file prints the same constant old and new. No `NEEDS_*` floor rises on an
existing file; `SimPanel.lua` is new with `NEEDS_CORE = 9` (Core is 11).

## The copy, the declaration and the prune

```sh
rm -rf libs/LibKa0s tests/_kit
cp -r <scratch>/LibKa0s/. libs/LibKa0s/ && cp -r <scratch>/testkit/. tests/_kit/
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s    # (empty)
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit      # (empty)
diff -r <scratch>/LibKa0s libs/LibKa0s                        # (empty)
diff -r <scratch>/testkit tests/_kit                          # (empty)
# CLAUDE.md: provenance line -> v1.75.0, and directly under it:
#   LibKa0s icons: clear, close, copy, help, info, segment.
lua5.1 <scratch>/tools/prune-icons.lua <this repo>
# prune-icons: ...: 6 icon(s) declared; kept 7 file(s), removed 5833
ls libs/LibKa0s/media/icons
# LICENSE-open-iconic.txt clear.tga close.tga copy.tga help.tga info.tga segment.tga
```

All four diffs ran before the prune and came back empty. `phosphor/` and `game-icons/` are gone.

The declaration comes from the real draw sites, all Open Iconic (unprefixed):

| Name | Drawn by | Where |
|---|---|---|
| `info` | host, `KCM.Icon` | the Macros score button, `settings/Category.lua:654`; also the library's id-list help mark through the Options descriptor's `addonName` (`settings/OptionsSetup.lua`), latent: CM draws no id list |
| `segment` | host, `KCM.Icon` | `HANDLE_ICON` in `settings/Category.lua:66` (used at :731, :950) and `settings/StatPriority.lua:97` (:620); `SLOT_HANDLE_ICON` in `settings/MacroBar.lua:708` (:1018) |
| `help` | host, `KCM.Icon` | the macro bar handle, `modules/MacroBar.lua:272` |
| `close` | host and library | the macro bar handle, `modules/MacroBar.lua:284`; the DebugLog console (`core/DebugLogSetup.lua:179` passes `addonName`), the PerfPanel (`core/PerfSetup.lua:98`), the Widgets copy window |
| `copy`, `clear` | library | the DebugLog console's title-bar buttons |

No other `KCM.Icon` or `Media.Icon` call exists in `core/`, `modules/` or `settings/`. The launcher
and panel logos are `media/logos/`, not LibKa0s icons. CM hosts no `W.TestStrip` or `W.SearchBox`.

## Consumption map

Fourteen majors consumed (CLAUDE.md), unchanged. `Pool`, `Glow` and `Sim` ship unused.

| Touched surface | Consumed here? | Note |
|---|---|---|
| `Media` 5 / `MediaIcons` 1 | **yes** | `core/MediaSetup.lua`; the icon catalog grew to 5,836 names and the copy now ships only the six declared |
| `Core` 11 | **yes** | `core/CoreSetup.lua` (`MakeCloseButton` with `addonName`) |
| `DebugLog` 20 / `DebugLogDiagnostics` 3 | **yes** | `core/DebugLogSetup.lua`, `core/Diagnostics.lua` |
| `Options` 29 / `OptionsTabs` 9 / `OptionsIdList` 5 / `OptionsDrawer` 1 | **yes** (shell), Drawer **no** | no page calls `O.Drawer` |
| `Perf` 15 / `PerfPanel` 7 | **yes** | `core/PerfSetup.lua`; `Perf.Note`'s `parentKey = false` is not used |
| `Widgets` 13 | **yes** (`ReorderList`, `DragHandle`) | `W.SearchBox`, `W.TestStrip` are not used |
| `Item` 3 | **yes** (`ItemIDFromLink` only) | `BonusIDsFromLink` is not used |
| `Glow` 1, `Sim` 1 | no | ship unused |

## Kit revision

Kit revision 38 -> 41: revision 39 adds `latch.lua` (`Kit.assertLatchHoldOrder`) and lets
`__fireUnconditional` also reach the method-name handler; revision 40 makes `vendor_sync.lua`
read the `LibKa0s icons:` declaration and hold `media/icons/` to it; revision 41 makes a crashed or
bounded lizard run a complexity **fail** (`crashedFiles`), never a pass. Both payloads move in one
commit, by construction of the whole-folder copy.

## Contract blockers, as found and fixed

The copy alone left two reds (1214 passed, 2 failed, 1 skipped); both fixed in the same commit.

- **(a) `tests/test_libka0s.lua`, MAJORS Options row.** Red: `LibKa0s-Options-1.0 reports
  OptionsDrawer`. `OptionsDrawer` added to `files`, and `{ file = "OptionsDrawer", minor =
  "__drawerMinor", shell = "__drawerShellMinor" }` to `paired`, with a comment line. The Perf row
  already lists `PerfPanel`; the tag's Perf `MODULES` (`Perf`, `PerfSampler`, `PerfCommands`,
  `PerfPanel`) matches it, so Perf needs nothing.
- **(b) Options degradation-stub parity.** Did not fire: CM's Options case is a projection over
  `OPTIONS_SEAM` (`tests/test_surface_parity.lua`), and no page calls `Drawer`. No stub, no
  `OPTIONS_LIVE_ONLY` row.
- **(c) Kit 39 `__fireUnconditional` reach.** `tests/test_disabled.lua` "Disabled 6b" stays green
  with `reached == 1`; no stand-down case reds. No change.
- **(d) Whole-catalog icon tests.** Red: `MediaSetup: every name the library ships has a file in
  the vendored copy` (every pruned name). Replaced by `MediaSetup: every declared icon has its file
  in the vendored copy, and no undeclared set ships`, which reads the declaration through
  `tests/_kit/vendor_sync.lua`'s `iconDeclaration`. `every mark this addon draws…` now lists the six
  declared names. New: `MediaSetup: every icon name the source draws is declared in CLAUDE.md`
  scans the TOC's `core/`, `modules/` and `settings/` files for `KCM.Icon("<name>")` and
  `KCM.Icon(<CONST>)` with `local <CONST> = "<name>"`, adds the library-drawn `close`, `copy`,
  `clear`, and asserts the set is declared (checked red by dropping `info, segment` from the line).
  `tests/test_settingsui.lua`'s `info` case now asserts `info` is declared and its file ships.
- **(e) Dead `O.__releaseChrome` stub mirror (LK-01).** `grep -rn __releaseChrome core modules
  settings tests/*.lua` is empty: nothing to delete.
- **(f) `Kit.__deviationRows` / `Kit.__declineFor` (LK-03).** `grep tests/*.lua` is empty: no caller.
- **(g) Stale kit-revision prose.** CLAUDE.md's Gate paragraph, `docs/testing.md` (Skipped-row note,
  layout-cap stamp, complexity row) and the `tests/run.lua` kit-wiring comment now name revision 41
  / v1.75.0. `tests/test_runner_list.lua:35` is a historical note about what revision 38 introduced
  and stays.
