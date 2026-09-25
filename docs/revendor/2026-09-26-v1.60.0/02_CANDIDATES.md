# 02 - Candidates: LibKa0s v1.58.0 -> v1.60.0

Sources: `git -C ../LibKa0s log --oneline v1.58.0..v1.60.0` (17 commits), the v1.59.0 and v1.60.0
blocks of the library's `CHANGELOG.md` at the tag, and the `Since` markers in
`docs/api/DebugLog/version-14.1-docs.md`, `docs/api/Slash/version-16-docs.md` and
`docs/api/Widgets/version-10.3-docs.md`. The three contract changes in `01_DELTA.md` (Blockers) are
not candidates: they were resolved in the re-vendor commit.

## A. Delivered on the re-vendor alone

| What | Evidence |
|---|---|
| The console holds 3000 lines, not 1500 (`lib.MAX_BUFFER`, `BUFFER_SLACK` 128); the counter and the copy window follow | CHANGELOG v1.60.0, "DebugLog minor 14"; `version-14.1-docs.md`, `lib.MAX_BUFFER` row |
| `lib.TIME_COPY`, the hand-switched copy-timing line | CHANGELOG v1.60.0, "DebugLog minor 14" |
| Kit revision 27's `test_diagnostics_contract.lua`, wired in `tests/run.lua` and a declared skip until `Kit.diagnostics` is set | CHANGELOG v1.60.0, "Test kit revision 27" |

## B. Host change required (candidates)

| # | Candidate | Evidence | Touches | Blast radius | Plan's decision |
|---|---|---|---|---|---|
| B1 | `D:RunDiagnostics(spec?)` / `brandName` / `diagnostics` descriptor field: the diagnostics report, both slash forms, `Kit.diagnostics` | CHANGELOG v1.60.0, "DebugLogDiagnostics minor 1"; `version-14.1-docs.md` (`Since` D1) | `core/DebugLogSetup.lua`, `settings/Slash.lua`, a new sections module, `tests/run.lua`, locale | Additive | Adopt in **DR-CM-03** |
| B2 | Slash minor 16's `diagnostics` live verb, used by registering the verb | CHANGELOG v1.60.0, "Slash minor 16"; `version-16-docs.md` `lib.LIVE_VERBS` row | `settings/Slash.lua` | Additive | Live-set entry landed here (blocker 2); the verb in **DR-CM-03** |
| B3 | WidgetsDragHandle minor 3's close mark: `spec.onClose`, `closeIcon`, `closeTooltip`, `handle:Reserve()` | CHANGELOG v1.59.0, "WidgetsDragHandle minor 3"; `version-10.3-docs.md` | `modules/MacroBar.lua:177`, locale, tests | Additive | Adopt in **DR-CM-06** (owner ruling DR-OW-03: X sets `macroBar.enabled = false`) |

## C. Whole-module adoption

None. No major was added (fifteen majors, twenty-two files), and `Pool` stays shipped-unused as
recorded in `CLAUDE.md`.
