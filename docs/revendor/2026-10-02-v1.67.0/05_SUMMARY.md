# Summary (ConsumableMaster)

LibKa0s v1.66.0 -> v1.67.0 from the local tag (`0bccf4c`, tag object `749c42e`), base taken from the
CLAUDE.md provenance line and confirmed against the payload bytes. Core 9 -> 10, Options 27 -> 28,
OptionsIdList 2 -> 3; kit revision 35 unchanged. No file added or removed, no floor raised, no
blocker, no base correction, no span owed. CLAUDE.md provenance rolled in the same commit as the
payload; the live vendor stamp in `docs/testing.md` (the layout-cap gate's "vendored from") rolls with
it.

Delivered free (class A): Core 10 leaves every existing grip unchanged, and OptionsIdList 3's guard
is latent here. B1 (`addonName` on the Options descriptor) is the census adoption's CA-CM-NM. B2 (the
resize-grip options) has no consumer here: none. Nothing declined, nothing filed.

No consumer test needed a fix: the only red case after the copy was the vendor-sync gate, which the
provenance roll turns green.

Gate after the copy:

- tests: 1186 passed, 0 failed, 1 skipped, 1187 total (unchanged; `docs/test-cases.md` regenerates
  byte-identical, README badge stays 1186/1187)
- luacheck: 0 warnings / 0 errors in 130 files
- both payloads `diff -r --strip-trailing-cr` clean against the tag after the copy
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity`): 3156 functions,
  maxCcn 15, warnings 0, blindFiles 0 (run as a report; its bundle was not kept)
