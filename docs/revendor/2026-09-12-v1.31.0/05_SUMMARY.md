# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

## The move

| | |
|---|---|
| From | v1.30.0 |
| To | **v1.31.0** (tag object 7cb70a0 on 30db4ed) |
| Files that moved in `libs/LibKa0s/` | `OptionsWidgets.lua` (`WIDGETS_MINOR` 14 → 15), `OptionsCompose.lua` (`COMPOSE_MINOR` 3 → 4) |
| Kit revision | 16 → **17** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |
| Provenance line | `CLAUDE.md:58` rolled to v1.31.0 in the same commit as both payloads (34e1e6c) |

## What reached this addon for free

The Options bind arm is inert for path-keyed rows, and every row and composer call here is
path-keyed, so both library files arrived with no host change and the suite total stayed at 824.
Kit revision 17 arrived as bytes but reached nothing until the harness migration below.

## What was adopted

The kit's Ace fakes, through the harness migration for
[#38](https://github.com/tusharsaxena/ConsumableMaster/issues/38) option 1 (f23ef2b).
`tests/wow_mock.lua` now layers only what the testkit document lists as ConsumableMaster's own: the
`_G.KCM` publish, AceDB, the permissive widget as a wrap on `AceGUI:Create`, `GetWidgetVersion`
answering 0, the LibSharedMedia fake and a lenient `LibStub`. Plan and per-swap results are in
`04_EXECUTION_PLAN.md`.

The migration exposed a live defect in `core/Bus.lua`. The RECOMPUTE handler read the reason one
argument late, so in the client every bus-routed recompute logged its reason as "unknown". It is
fixed in the same commit.

## What was declined

Nothing. `spec.bind` does not apply: no composer here edits a registry record. No issue was filed,
as instructed for this run.

## Skipped

The interview (non-interactive run; the owner's triage instruction decided the one candidate),
issue filing, and push, all as instructed.

## Gates

| Gate | Before | After re-vendor | After #38 |
|---|---|---|---|
| `lua tests/run.lua` | 824 / 0 / 0 | 824 / 0 / 0 | **834 / 0 / 0** |
| `luacheck .` | 0 / 0 in 102 files | 0 / 0 in 102 files | **0 / 0 in 103 files** |
| copy diff (content and bytes, both payloads) | 5 files differ | empty | empty |

The same branch then took three more commits outside this bundle's scope: a debug trace on
`MacroManager.InvalidateState` (9684962), the perf ring named in the Settings Schema (cbdfdcc), and
the re-vendor of the re-cut v1.31.0 tag (08d155c, see the addendum below). The suite ends at 835.

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`). Before anything
was pushed, a review of that release found defects in the kit-17 fakes, and LibKa0s re-cut the tag on the
fixed tree: **`v1.31.0` now points at `e7e1962`**. Commit **08d155c** re-vendored it, copying both
payloads whole from the re-cut tag, and the vendor-sync cases pass against it.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `libs/LibKa0s/` move in this release, not two: 08d155c touches `OptionsCompose.lua`,
`OptionsWidgets.lua` and `Perf.lua`, plus `tests/_kit/README.md` and `tests/_kit/mock_base.lua`. Any
"the ring trim is not traced" finding recorded above is resolved upstream by Perf minor 11. The
**To** row above still names the first cut; read it as `e7e1962`.

Gate on the re-cut payload, at 08d155c:

```
lua tests/run.lua   835 passed, 0 failed, 0 skipped, 835 total
luacheck .          0 warnings / 0 errors in 103 files
```
