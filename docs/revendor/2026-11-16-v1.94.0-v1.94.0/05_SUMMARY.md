# 05 Summary: the consolidated span v1.94.0

Written 2026-11-16 by item RV-CM. A records-only back-fill: no file outside this folder moved because of it.

## Per tag

- v1.94.0: `20f4c60` (CM-F1..CM-F6) adopted Skin minor 18's `Skin:DefaultSkin()` as the profile's default skin
  (`core/SkinSetup.lua`, `KCM.DEFAULT_SKIN`), vendored by the same commit. Compat minor 4's character identity
  reached the addon unconsumed (`tests/test_surface_parity.lua` mirrors its members).
