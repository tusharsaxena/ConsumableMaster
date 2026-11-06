# Summary

- **Tag:** v1.89.0 -> v1.90.0 (a local tag, `4485b8f`), base from the provenance line (`CLAUDE.md:61`). Moved:
  Core 15 -> 16, Skin 16 -> 17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18, Widgets 23 -> 24,
  WidgetsAutocomplete 7 -> 8, OptionsAppearance 6 -> 7. Kit 51, unchanged. Table in `01_DELTA.md`. No span
  bundle (66 vendored, 66 recorded), no base correction, no refresh.
- **For free (class A):** one-physical-pixel edges on the library's dropdown, search box, menus and autocomplete
  list (Widgets 24, Autocomplete 8, Core 16), with no host change.
- **Blockers:** none. No host stub or test needed a change.
- **Icons:** `LibKa0s icons:` line kept as is (15 names, all Open Iconic). The prune kept 16 files (15 marks and
  the Open Iconic license) and removed 5824, every one an undeclared mark arriving with the whole-folder copy, so
  the shipped `media/icons/` is unchanged. No provenance split, README credits unchanged, no dead stub mirrors.
- **Adopted:** nothing. **Declined:** nothing filed; `keepScope` not applicable (`03_DECISIONS.md`).
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 151 files; `ka0s-bounded lua tests/run.lua`
  1403 passed, 0 failed, 1 skipped; largest addon-owned Lua file 1114 lines (under the 1500 cap). No addon Lua
  changed in this commit, so the CCN figure is the one the previous commit carried.
