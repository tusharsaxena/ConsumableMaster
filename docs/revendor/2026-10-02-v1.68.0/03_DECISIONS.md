# Decisions (ConsumableMaster, LibKa0s v1.67.0 -> v1.68.0)

The owner delegated every decision for this run (TP-CM-01): decide, record the reasoning, and file
no GitHub issue for a decline unless the reason is a real gap.

## B1: host-placed strip tooltip (`tooltipPlace`): not adopted

The owner's request (AuraMaster#22 smoke feedback): the strip tooltip beside the strip instead of at
the cursor. Decided against here, for three reasons.

1. **The complaint does not occur here.** AuraMaster's anchor inherits
   `DisableUntrustedLayoutScriptsTemplate`, so its strip could only use a cursor-owned tooltip, and
   the hook exists to get it off the cursor (`version-12.1.4-docs.md:26-31`). This bar is a plain
   `BackdropTemplate` frame, so the strip owns its own tooltip (`tooltipOwner` unset,
   `version-12.1.4-docs.md:690`) and anchors it `ANCHOR_TOP` (`modules/MacroBar.lua:237`). The
   tooltip is already fixed to the strip and does not chase the cursor.
2. **Above suits this strip better than beside it.** The strip is as wide as the bar
   (`handle:ApplyWidth(bar:GetWidth())`, `modules/MacroBar.lua:356`), and a bar set to one row of
   every macro can span most of the screen. Placed beside the strip, the tooltip would sit at the
   bar's far end, away from the centered label the cursor is on. On a bar that wide, both the
   right-hand side and the left-hand fallback can run off screen. `ANCHOR_TOP` keeps the tooltip
   centered over the label, clear of the buttons below the strip, and the client clamps it.
3. **The strip's three tooltips agree today.** The strip, help mark and close mark tooltips each sit
   above the frame hovered (`ANCHOR_TOP`, `ANCHOR_TOPRIGHT` at `:252` and `:225`). A spec-wide
   `tooltipPlace` would move both marks' tooltips away from the small mark under the cursor. A
   descriptor-only `place` would split the strip from its marks.

**Not a gap, so no issue filed.** The library already provides the hook. If the owner wants the
collection's strips to place tooltips the same way, adoption is about 20 lines: a strip-only `place`
that reads `frame:GetRight()` / `tip:GetWidth()` against `UIParent:GetRight()` and returns `true`
only when it placed the tooltip. Nothing on this addon's side blocks it.

## Addendum (TP-CM-02, 2026-10-03): B1 reversed, `tooltipPlace` adopted

The owner overruled the decline above: every Ka0s drag strip places its tooltip the same way, so
this strip does too. Consistency across the collection outweighs the three local reasons. The
decline stays above as the record of what was decided first. AbsorbTracker's matching decline is
reversed in the same pass (TP-AT-02).

What changed:

- `MB.PlaceTooltipBeside(tip, frame)` in `modules/MacroBar.lua` is the strip's `tooltipPlace`. It
  mirrors KickCD's `NS.Util.PlaceTooltipBeside` (`core/Util.lua`) rule for rule. The tooltip is
  anchored `TOPLEFT` to the strip's `TOPRIGHT`, or `TOPRIGHT` to its `TOPLEFT` when the strip's right
  edge plus the gap and the tooltip's width would pass `UIParent`'s right edge. A hovered mark (the ?
  or the X) resolves to its parent strip, so all three tooltips share one position. Every read is
  scaled by the frame's effective scale and compared in screen pixels, because the bar takes the
  master scale. Each read is guarded (missing, nil, secret through `KCM.Compat.IsSecret`, or not a
  number), and any failed read returns nil with nothing anchored, so the widget falls back to the
  cursor. The function returns `true` only once it has anchored the tooltip.
- The descriptors give way to the hook: the `anchor` fields on `tooltip` (`ANCHOR_TOP`),
  `helpTooltip` and `closeTooltip` (`ANCHOR_TOPRIGHT`) are gone. No descriptor names an owner.
- Reason 2 above (a full-width strip puts the tooltip at the bar's far end) is accepted as the cost
  of one rule. The flip keeps the tooltip on screen when the right-hand side has no room. When the
  strip is wider than the screen less the tooltip, the tooltip goes left and the client clamps it.
- Tests (`tests/test_macrobar_chrome.lua`): six placement cases mirroring KickCD's (right, flip
  left, mark resolves to the strip for both marks, screen pixels, secret, nil), the strip, ? and X
  hovers now asserting a UIParent/`ANCHOR_NONE` owner placed beside the strip, and a hover whose
  strip cannot be read falling back to the cursor. Smoke: BAR-9 and BAR-10 in `docs/smoke-tests.md`.
