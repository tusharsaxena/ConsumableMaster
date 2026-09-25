# 05 - Summary: LibKa0s v1.58.0 -> v1.60.0

Item DR-CM-01 of the 2026-09-25 diagnostics-command rollout, on `feat/2026-09-25-diagnostics-rollout`,
2026-09-26. One commit carries both payloads, the provenance line and the edits below.

## Moved

| File | Before | Tag |
|---|---|---|
| WidgetsDragHandle.lua (`DRAG_MINOR`) | 2 | 3 |
| DebugLog.lua (`MINOR`) | 13 | 14 |
| DebugLogDiagnostics.lua (`DIAG_MINOR`) | - | 1 (new) |
| Slash.lua (`MINOR`) | 15 | 16 |
| test kit (`Kit.VERSION`) | 26 | 27 |

Post-copy `diff -r` (bytes) of both payloads against the tag: empty. Nothing deleted.

## Delivered for free (class A)

The 3000-line console buffer (slack 128), the copy-timing switch, and the kit's shared diagnostics
contract suite (one declared skip until DR-CM-03 sets `Kit.diagnostics`).

## Contract blockers, resolved in the re-vendor commit

1. `lib.MAX_BUFFER` 1500 -> 3000 (`version-13-docs.md` vs `version-14.1-docs.md`, `lib.MAX_BUFFER`
   row): `tests/test_debuglog.lua` pin re-set to 3000; `docs/smoke-tests.md` counter lines
   (`N / 3000 lines`) moved with it.
2. Slash 16 `LIVE_VERBS` gains `diagnostics` (`version-16-docs.md`): the host's literal array in
   `settings/Slash.lua` gains it after `perf`; the comment, `docs/slash-dispatch.md` and
   `docs/ARCHITECTURE.md` now say thirteen reserved plus `dump`.
3. The DebugLog stub gains `RunDiagnostics` (CHANGELOG v1.60.0, "What a consumer owes"; standard
   STD-14): `core/DebugLogSetup.lua`'s degraded arm prints the one library-absent line naming
   `/cm diagnostics`, writes nothing and returns 0 (no chat flood); the live facade forwards to the
   instance. `tests/test_surface_parity.lua`'s `DEBUGLOG_SEAM` gains the member, and two new cases
   in `tests/test_debuglog.lua` pin both arms.

Also owed by the kit and the new file: `tests/run.lua` wires `test_diagnostics_contract`, and
`tests/test_libka0s.lua`'s `MAJORS` names `DebugLogDiagnostics` as a paired secondary of DebugLog.

## Adopted / declined / unreached

Nothing adopted in this run. The diagnostics report and the live verb are DR-CM-03; the macro-bar
close mark is DR-CM-06 (owner ruling DR-OW-03). No declines, no issues filed (the plan decided every
candidate). No `04_EXECUTION_PLAN.md`: there was nothing to implement beyond the re-vendor.

## Gates (each through `ka0s-bounded`)

| Gate | Before the copy | At the commit |
|---|---|---|
| headless suite (`tests/run.lua`) | 1078 passed, 0 failed, 0 skipped | 1080 passed, 0 failed, 1 skipped (1081) |
| lint (`.luacheckrc` scope) | - | 0 warnings / 0 errors in 120 files |
| complexity (libs and kit excluded, `-C 15 -w`) | - | no function above CCN 15 |
| `--list` output vs `docs/test-cases.md` | - | identical |

README `[Tests]` badge: 1078/1078 -> 1080/1081.
