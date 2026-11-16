# 05 Summary

- Tag moved v1.94.0 -> v1.105.0, base taken from the CLAUDE.md provenance line (it agrees with the last payload
  commit, `20f4c60`). Kit revision 53 -> 57. Files that moved a minor: see 01_DELTA.md section 3c.
- Span bundle: `2026-11-16-v1.94.0-v1.94.0/` (one tag). Base correction: none.
- Delivered for free (class A): plain-text Copy, the console footer, header marks with a settings mark on the
  library's windows, placed library tooltips, the skin color floors (02_CANDIDATES.md).
- Contract changes, fixed in the re-vendor commit (01_DELTA.md section 3g):
  - `tests/test_slash.lua`: three color-pin cases read the view (a new `reportView` helper, a recorder on the
    console's `AddMessage`) instead of the now-plain `D.buffer`. Assertions unchanged.
  - `tests/test_macrobar_chrome.lua`: the unreadable-strip fallback is re-pinned from `ANCHOR_CURSOR` to the
    library's new fallback (UIParent, `ANCHOR_NONE`, attached below the strip) and renamed; two comments and
    `modules/MacroBar.lua`'s doc comment on `PlaceTooltipBeside` follow (comment only).
  - `tests/test_libka0s.lua`: `OptionsSkinPickerQueue` joins the Options inventory and its paired minor.
  - `core/DebugLogSetup.lua`: a comment that said Copy still carried colors (comment only).
- LibKa0s icons: line kept as written (it already names `settings`). Prune removed 5824 icon files (Open Iconic 209,
  Phosphor 1435, Game-icons 4180) and 362 sound files; kept 15 marks and the Open Iconic license.
- README credits: unchanged (Open Iconic only). Dead stub mirrors: none (`__releaseChrome` absent).
- `docs/test-cases.md` regenerated (one renamed case); README `[Tests]` badge unchanged at 1481/1481.
- Adopted: nothing. Declined: nothing. Owed in phase [3]: LibKa0s#79, #92, #86, #82 (02_CANDIDATES.md).
- Gate after the copy: `ka0s-bounded lua5.1 tests/run.lua` 1481 passed, 0 failed, 1 skipped (1482) under both
  `KA0S_KIT_CLIENT=retail` (default) and `=forever`; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 156 files;
  largest addon-owned file `settings/Category.lua` 1050 lines, nothing over 1500.
- Smoke owed (owner): the console's header marks and footer, Copy pasting plain text from `/cm dump`, the macro bar
  strip's tooltip position, the skin colors (Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/06_SMOKE_TESTS.md`).
