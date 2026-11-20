# 05 Summary

- Tag moved v1.107.0 -> v1.108.0, base taken from the CLAUDE.md provenance line (it agrees with the last payload
  commit, `a4330fd`). Kit revision 57 -> 58. Seventeen files moved a minor (01_DELTA.md 3c).
- Span bundle: none owed. Base correction: none.
- Contract changes: none blocking. Re-pinned in the re-vendor commit: `tests/test_macrobar_chrome.lua`'s three
  unreadable-strip cases (now above the bar, or hidden) and `tests/test_skin_flip.lua`'s Font shadow case (now grayed
  while its companion is on). New `Kit.skinValues` row for `KCM.SwatchColor`'s scratch table (`unreachable default`).
- LibKa0s icons: line kept as written. Prune: 16 icon files kept, 362 sound files removed. README credits unchanged
  (Open Iconic only). Dead stub mirrors: none.
- Standard reference refreshed to v2.116.0 from the local WowAddonStandards checkout on
  `feat/2026-11-20-libka0s-94-97-99-100`: `standards/standards/client-quirks.md` is unchanged since v2.115.0, so the
  vendored block in `docs/midnight-quirks.md` is byte-identical and only its stamp moves. TOC `X-Standard`, README badge
  and CLAUDE.md's Standards compliance carry no version. No section the repo cites moved.
- Doc ripple: `docs/ARCHITECTURE.md` and `docs/macro-bar.md` (the strip tooltip's fallback), `docs/settings-panel.md`
  (the composers' companions, Font shadow grayed), `settings/MacroBar.lua`'s `skinRow` comment, smoke BAR-45,
  `docs/test-cases.md` regenerated, the README badge.
- Gate after the copy: `ka0s-bounded lua5.1 tests/run.lua` 1504 passed, 0 failed, 1 skipped (1505) under both
  `KA0S_KIT_CLIENT=retail` (default) and `=forever`; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 157 files;
  nothing addon-owned over 1500 lines.
