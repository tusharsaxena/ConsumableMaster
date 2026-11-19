# 05 Summary

- Tag moved v1.106.0 -> v1.107.0, base taken from the CLAUDE.md provenance line (it agrees with the last payload
  commit, `7d57df4`). Kit revision 57, unchanged. Files that moved a minor: `WidgetsDragHandle.lua` (DRAG_MINOR
  14 -> 15) and `WidgetsDragHandleTip.lua` (DRAGTIP_MINOR 1 -> 2).
- Span bundle: `2026-11-19-v1.106.0-v1.106.0/` (one tag). Base correction: none.
- Delivered for free (class A): the strip's marks read ? · settings · close, at the tighter 14 px pitch, in the
  window header's tints (the "?" now lights under the pointer); the strip's tooltips always attach above it.
- Contract changes: none blocking (01_DELTA.md section 3g). One test re-pinned in the re-vendor commit:
  `tests/test_macrobar_chrome.lua`'s help-mark tint case, which pinned minor 14's "no hover light without a
  right-click" and now pins minor 15's hover light and resting gray on leave (renamed; `docs/test-cases.md`
  regenerated).
- LibKa0s icons: line kept as written (it already names `settings`). Prune removed every undeclared icon (5840 in
  the tag, 16 files kept: 15 marks and the Open Iconic license) and 362 sound files.
- README credits: unchanged (Open Iconic only). Dead stub mirrors: none.
- Standard reference refreshed to v2.115.0 in the same commit: the vendored quirks block in `docs/midnight-quirks.md`
  replaced whole (v2.103.1 -> v2.115.0: the Forever character-name entry, two sources renamed from DpsRace to Combat
  Trail). TOC `X-Standard`, README badge and CLAUDE.md's Standards compliance carry no version and were already
  current.
- Doc ripple: `docs/macro-bar.md` (the mark order), `docs/smoke-tests.md` (new BAR-43; BAR-10 and BAR-40 amended
  for the order).
- Adopted: the strip's settings opener and close tooltip, item AF-STRIP-CM, in its own commit. Declined: nothing.
- Gate after the copy: `ka0s-bounded lua5.1 tests/run.lua` 1501 passed, 0 failed, 1 skipped (1502) under both
  `KA0S_KIT_CLIENT=retail` (default) and `=forever`; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 157 files;
  nothing addon-owned over 1500 lines.
