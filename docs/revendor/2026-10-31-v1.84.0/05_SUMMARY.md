# Summary (ConsumableMaster)

LibKa0s v1.83.0 -> v1.84.0 from the local tag (`e917ccd`, via `git archive`; not pushed). The base
comes from the CLAUDE.md provenance line and matches the payload. No span bundle and no base
correction. Test kit revision 46 -> 47. Per-file minors are in `01_DELTA.md`.

In one commit, with both payloads:

- the CLAUDE.md provenance line rolls to v1.84.0; the `LibKa0s icons:` line is kept;
- `tools/prune-icons.lua` from the tag cut `media/icons/` back to the declared marks (kept 8 files,
  removed 5,832, all from the copy, all from sets this addon does not ship; no credit change);
- `settings/OptionsSetup.lua`'s degraded arm publishes `Helpers.PositionBlock`, and
  `tests/test_surface_parity.lua` holds it in the seam;
- `tests/test_libka0s.lua` names the four new Options files and two new Skin files;
- `docs/testing.md` names the new kit revision.

Delivered free: the drag strip's fit (WidgetsDragHandle minor 10), which `modules/MacroBar.lua`
takes with no host change; the rest of class A is in `02_CANDIDATES.md`.

Blockers: the two above, fixed in this commit. No contract tightened under a member this addon
supplies. No dead stub mirror. No file removed upstream survived.

Adopted beyond the copy: nothing. Declined: every candidate in `03_DECISIONS.md`; no issue filed, by
the run's brief.

Gate: `ka0s-bounded luacheck .` 0 warnings / 0 errors in 146 files; `ka0s-bounded lua tests/run.lua`
1316 passed, 0 failed, 1 skipped, 1317 total. Before the fix the copy showed one failure, the
inventory case; `docs/test-cases.md` is unchanged.
