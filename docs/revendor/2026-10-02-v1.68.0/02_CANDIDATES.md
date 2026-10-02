# Candidates (ConsumableMaster, LibKa0s v1.67.0 -> v1.68.0)

Sources: `git -C ../LibKa0s log --oneline v1.67.0..v1.68.0`, the CHANGELOG `v1.68.0` block
(`../LibKa0s/CHANGELOG.md:13`) and `docs/api/Widgets/version-12.1.4-docs.md` against
`version-12.1.3-docs.md`, the one major whose minor moved.

## A. Delivered on the re-vendor alone (not offered)

- **WidgetsDragHandle 4 with no hook set.** The macro bar's strip (`modules/MacroBar.lua:203`) passes
  neither `tooltipPlace` nor a descriptor `place`, so its strip, help-mark and close-mark tooltips
  make minor 3's calls in minor 3's order (`version-12.1.4-docs.md:44-45`). Nothing visible moves.

## B. Host change required (candidates)

| # | What | Evidence | Files here | Blast radius |
|---|---|---|---|---|
| B1 | `tooltipPlace(tip, frame)` on the strip spec (or `place` on one descriptor), so the host places the strip tooltip beside the strip: right of it, left near the right screen edge | `docs/api/Widgets/version-12.1.4-docs.md:20-48`, `:692`; CHANGELOG v1.68.0; AuraMaster#22 | `modules/MacroBar.lua:203-269` (the strip spec), a test beside `tests/test_macrobar*.lua` | Additive. A placement that answers anything but `true` falls back to the cursor owner, which this addon does not use today |

Today's ownership, the premise of B1: the spec sets no `tooltipOwner`, so every tooltip is owned by
the frame hovered (`version-12.1.4-docs.md:690`). The strip's descriptor anchors `ANCHOR_TOP`
(`modules/MacroBar.lua:237`), the help and close marks' `ANCHOR_TOPRIGHT` (`:252`, `:225`). The strip
tooltip is therefore owned by the strip, not by the cursor.

## C. Whole-module adoption

None. The payload's majors are unchanged; `Pool` is still looked up only inside the library's own
options shell (`libs/LibKa0s/OptionsNav.lua:20`, `OptionsTabs.lua:38`, `OptionsWidgets.lua:37`).
