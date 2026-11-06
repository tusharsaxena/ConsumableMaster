# Summary

- **Tag:** v1.90.0 -> v1.91.0 (a local tag, `55bfbb4`), base from the provenance line (`CLAUDE.md:61`). Moved:
  Core 16 -> 17, SkinPaintExtras 18 -> 19, Widgets 25 -> 26, WidgetsLineChart 6 -> 7; new CorePixel 1,
  SkinPaintHud 1, SkinAceConfirm 1, WidgetsDropdown 1. Kit 51, unchanged. Table in `01_DELTA.md`. No span bundle
  (67 vendored, 67 recorded), no base correction, no refresh. Step 0 skipped (the installed skill's roster regex
  matches nothing; fixed upstream in this run), checked by hand for this addon.
- **For free (class A):** the line chart's lines in physical pixels (not drawn by this addon), and the four peels,
  which change no member or behavior.
- **Blockers:** one, fixed in the copy commit: `tests/test_libka0s.lua`'s `MAJORS` inventory now names `CorePixel`
  (Core) and `SkinPaintHud`, `SkinAceConfirm` (Skin) in `LibKa0s.xml` order, each with its paired minor and shell.
  The harness load list is derived from `LibKa0s.xml` and needed no edit. No test pins an exact library minor; no
  host stub mirrors a moved member.
- **Icons:** `LibKa0s icons:` line kept as is (15 names, all Open Iconic). The prune kept 16 files (15 marks and
  the Open Iconic license) and removed 5824, every one an undeclared mark arriving with the whole-folder copy, so
  the shipped `media/icons/` is unchanged. No provenance split, README credits unchanged, no dead stub mirrors.
- **Adopted:** nothing. **Declined:** nothing filed.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 151 files; `ka0s-bounded lua tests/run.lua`
  1404 passed, 0 failed, 1 skipped, 1405 total; largest addon-owned Lua file 1114 lines (under the 1500 cap). The
  only addon Lua change is data in a test's inventory table (no function changed), so no CCN figure moves.
