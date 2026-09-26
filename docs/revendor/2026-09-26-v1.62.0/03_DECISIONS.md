# Decisions (ConsumableMaster)

- No adoption in this item: the candidate-adoption interview is out of scope for the automated-tests
  sweep (`Ka0sAddonsCommonTasks/docs/2026-09-26-AUTOMATED_TESTS_SWEEP/01_EXECUTION_PLAN.md`, M2),
  and there is no candidate to offer (02_CANDIDATES.md).
- `tests/test_libka0s.lua`'s hand-typed Options inventory gains the four new files and their paired
  minors and shells (`__registryMinor` / `__registryShellMinor`, `__idsMinor` / `__idsShellMinor`,
  `__idListMinor` / `__idListShellMinor`, `__combatMinor` / `__combatShellMinor`). Without it the
  MODULES stray check reads the four as files registering under a major they do not own, which was
  the one red case after the copy (1111/1112).
- The library-absent stub gains nothing: `tests/test_surface_parity.lua`'s `OPTIONS_SEAM` projects
  named members, and no member was added or moved.
- `docs/testing.md` and `tests/run.lua` name the vendored kit revision; both roll from 27
  (v1.60.0) to 31 (v1.62.0).
