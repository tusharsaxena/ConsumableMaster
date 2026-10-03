# Summary (ConsumableMaster)

LibKa0s v1.67.0 -> v1.68.0 from the local annotated tag (`cc9f5eb`, tag object `6d83731`, via
`git archive`). The base comes from the CLAUDE.md provenance line and matches the payload bytes, so
there is no base correction and no span bundle is owed. WidgetsDragHandle 3 -> 4 (Widgets key 12.1.3
-> 12.1.4) is the only file that moved. Kit revision 35 is unchanged and `tests/_kit/` is
byte-identical. No file was added or removed, no floor raised and no contract blocker found (3g). The
CLAUDE.md provenance line and `docs/testing.md`'s layout-cap "vendored from" stamp roll in the same
commit as the payload.

- **Delivered free (class A):** minor 4 with no hook set. The macro bar strip's three tooltips are
  unchanged.
- **Adopted:** none.
- **Declined:** B1, the host-placed strip tooltip. The strip already owns its tooltip `ANCHOR_TOP`,
  not at the cursor. A full-bar-width strip suits above better than beside, and the strip and its
  marks would stop agreeing (`03_DECISIONS.md`). This is not a gap, so no issue was filed.
- **Unreached:** none.

Gate after the copy:

- tests (`ka0s-bounded lua5.1 tests/run.lua`): 1194 passed, 0 failed, 1 skipped, 1195 total,
  unchanged. `docs/test-cases.md` regenerates identical and the README badge stays 1194/1195. The
  vendor-sync gate is green on the rolled line.
- luacheck (`ka0s-bounded luacheck .`): 0 warnings / 0 errors in 130 files (`libs/` and `tests/_kit/`
  excluded by `.luacheckrc`, and no host file changed)
- both payloads `diff -r` clean against the tag after the copy, with and without
  `--strip-trailing-cr`
- sighted complexity (`ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity
  --no-bundle`): 3167 functions, max CCN 15, 0 warnings, verdict green (a report, not kept)
