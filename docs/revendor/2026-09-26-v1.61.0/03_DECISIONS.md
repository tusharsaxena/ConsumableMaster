# Decisions (ConsumableMaster)

- **C1 `O.NavRail`:** Not adopted here. No ConsumableMaster page edits one instance out of many through sub-pages retargeted by one picker. The stub projects the named OPTIONS_SEAM list, which does not include NavRail, so the fix is tests/test_libka0s.lua's Options inventory (files + the paired __navMinor/__navShellMinor).
- The library-absent stub gains no `NavRail`: the surface-parity case checks the named OPTIONS_SEAM list, which does not include it (02_SPEC R18). The hand-typed Options inventory in `tests/test_libka0s.lua` gains `OptionsNav` instead.
- Plan: `Ka0sAddonsCommonTasks/docs/2026-09-26-NAVRAIL_ADOPTION/`.
