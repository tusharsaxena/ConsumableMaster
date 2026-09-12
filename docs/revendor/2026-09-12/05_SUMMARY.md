# 05 — Summary: LibKa0s v1.29.0 → v1.30.0

## The move

| | |
|---|---|
| From | v1.29.0 |
| To | **v1.30.0** |
| Files that moved in `libs/LibKa0s/` | none — every LibStub minor is the one v1.29.0 shipped |
| Kit revision | 15 → **16** (`README.md`, `framework.lua`, `mock_base.lua`, `vendor_sync.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |
| Provenance line | `CLAUDE.md:58` rolled to v1.30.0 in the same commit as both payloads |

## What reached this addon for free

The runner-mode case `the automated-test runner is recorded executable (100755)` (LibKa0s #28).
`tests/test_vendor_sync.lua` needed no edit, and the case passes. The suite total moved **796 →
797**. `docs/test-cases.md` was regenerated and the README `[Tests]` badge rolled in the same
commit, per `CLAUDE.md`'s static-badge rule.

## What was adopted

Nothing, and no local shim was deleted: this repo never had one. There is no
`04_EXECUTION_PLAN.md` in this bundle because nothing was implemented.

## What was declined

`AceGUI:Release` (#27), the AceEvent event half on an Embed (#29) and `NewAddon`'s `Printf`
(#30). All three are inert here because `tests/wow_mock.lua` replaces the kit's AceAddon,
AceEvent, AceConsole and AceGUI wholesale (`:538-540`, `:568`). Adopting them is a harness
migration. The decline went back to the owner as one proposed issue, filed afterwards as
[#38](https://github.com/tusharsaxena/ConsumableMaster/issues/38) (see `03_DECISIONS.md`).

## Gates

| Gate | Before | After |
|---|---|---|
| `lua tests/run.lua` | 796 passed, 0 failed, 0 skipped | **797 passed, 0 failed, 0 skipped** |
| `luacheck .` | 0 warnings / 0 errors in 102 files | **0 warnings / 0 errors in 102 files** |
| `tests/_kit/test_eol.lua` | pass | pass |

`luacheck`'s figure is scoped by `.luacheckrc`'s `exclude_files`, which excludes `libs/` and
`tests/_kit/`. A clean run says the **host** is clean. The payload's own gate is upstream.

## Not pushed

Committed on `chore/libka0s-1.30.0-arch5` only. Pushing is `/wow-addon:finalize`'s.
