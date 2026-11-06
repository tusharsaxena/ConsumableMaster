# Summary

- **Tag:** v1.85.0 -> v1.89.0, base from the provenance line (`CLAUDE.md:61`). Moved: Toast 3 -> 4, Widgets 22 -> 23,
  DebugLogDiagnostics 6 -> 7, and the new `LibKa0s-IconBrowser-1.0` (three files at 1). Kit 50 -> 51. Table in
  `01_DELTA.md`. No span bundle (65 vendored, 65 recorded), no base correction, no refresh.
- **For free (class A):** kit 51's CallbackHandler unregister guard; the diagnostics report naming IconBrowser;
  flat Widgets menus unchanged.
- **Blockers:** none. Widgets 23 is additive and this addon has no `W.ContextMenu` site; no Toast lookup, so no
  Toast stub owed.
- **Icons:** `LibKa0s icons:` line kept as is (15 names, all Open Iconic). The prune kept 16 files (15 marks and
  the Open Iconic license) and removed 5824, every one an undeclared mark arriving with the whole-folder copy, so
  the shipped `media/icons/` is unchanged from v1.85.0. No provenance split, README credits unchanged, no dead stub
  mirrors.
- **Adopted:** nothing (the plan names no adoption here). **Declined:** nothing filed. IconBrowser settled (no icon
  chooser), cascading-menu fields not applicable, both recorded in `03_DECISIONS.md` from the run plan.
- **Gate at the copy:** `ka0s-bounded luacheck .` 0 warnings / 0 errors in 151 files; `ka0s-bounded lua tests/run.lua`
  1403 passed, 0 failed, 1 skipped (the diagnostics opt-out case, which this addon does not take); largest
  addon-owned Lua file 1114 lines (under the 1500 cap).
