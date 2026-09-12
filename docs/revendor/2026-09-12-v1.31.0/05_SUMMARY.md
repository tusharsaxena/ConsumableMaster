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

The same branch then took two more commits outside this bundle's scope: a debug trace on
`MacroManager.InvalidateState` (9684962) and the perf ring named in the Settings Schema (cbdfdcc).
The suite ends at 835.
