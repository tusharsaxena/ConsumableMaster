# Summary (ConsumableMaster)

LibKa0s v1.68.0 -> v1.68.1 from the pushed annotated tag (`9000cbd`, tag object `9fb7956`, via
`git archive`). The base comes from the CLAUDE.md provenance line and matches the payload bytes, so
there is no base correction and no span bundle is owed. No library file moved: all 32 LibStub
constants print the same old and new, no file was added or removed and no floor rose. The kit moves
from revision 35 to 36 (`framework.lua`, `run-automated-tests.sh`, `test_eol.lua`). No contract
blocker (3g).

In the same commit as both payloads:

- the CLAUDE.md provenance line rolls v1.68.0 -> v1.68.1;
- the prose that names the kit revision this repo holds moves 35 -> 36, as
  `docs/api/testkit/version-36-docs.md:59-60` asks: `docs/testing.md`'s layout-cap stamp (and its
  "vendored from" tag, v1.68.0 -> v1.68.1) and the `tests/run.lua` kit-wiring comment (its
  "as vendored from" tag was stale at v1.66.0 and now reads v1.68.1);
- left alone, because each names the revision a feature *arrived* in, not the one this repo holds:
  "kit revision 35" for the sighted complexity suite in `CLAUDE.md:107`, `docs/testing.md:283` and
  `docs/automated-tests/README.md:26`, and the `test_lizard_sighted` row of the `tests/run.lua`
  gate list (beside `test_eol` at 15, `test_prose` at 24). Revision 36 adds nothing to that suite.

- **Delivered free (class A):** kit revision 36's renamed `RESULTS.md` lead-in, on the next
  automated-test run.
- **Adoption candidates:** zero (rename-only release; no surface added). Interview skipped.
- **Adopted:** none. **Declined:** none, so no issue filed. **Unreached:** none.

Gate after the copy:

- tests (`ka0s-bounded lua tests/run.lua`): 1201 passed, 0 failed, 1 skipped, 1202 total, unchanged
  from master. The vendor-sync gate is green on the rolled line ("tests/_kit is the test kit that
  shipped with that release"). `lua5.1 tests/run.lua --list` matches `docs/test-cases.md`, so the
  inventory and the README badge (1201/1202) stay.
- luacheck (`ka0s-bounded luacheck .`): 0 warnings / 0 errors in 130 files (`libs/` and
  `tests/_kit/` excluded by `.luacheckrc`; no host Lua changed beyond one comment in `tests/run.lua`).
- both payloads `diff -r` clean against the tag after the copy, with and without
  `--strip-trailing-cr`; `tests/_kit/run-automated-tests.sh` stays mode 100755.
