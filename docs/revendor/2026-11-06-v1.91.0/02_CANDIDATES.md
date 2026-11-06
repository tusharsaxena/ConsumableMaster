# Candidates, v1.90.0 -> v1.91.0

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the tag's `CHANGELOG.md` block v1.91.0, and the
`docs/api/` documents of every major whose minor moved (Core, Widgets, Skin). The 3g blocker (the `MAJORS`
inventory in `tests/test_libka0s.lua`) is a test fix landed in the copy commit, not a candidate.

## A. Delivered by the re-vendor alone

- **WidgetsLineChart minor 7** (CHANGELOG v1.91.0 *The line chart's lines in physical pixels*;
  `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md:33`, "What a host owes: nothing"): the chart's axis, grid,
  markers, crosshair and series draw in physical pixels. This addon draws no line chart, so it ships the code
  without exercising it.
- **The four peels** (Core 17 + CorePixel 1, Widgets 26 + WidgetsDropdown 1, SkinPaintExtras 19 + SkinPaintHud 1
  + SkinAceConfirm 1; `docs/api/Core/version-17.1-docs.md:25`, `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md:21`,
  `docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md:21`): pure moves, no member, option or behavior change.

## B. Host change required

None. No member, option, row type or seam is added in this range.

## C. Whole-module adoption

None new in this range. IconBrowser, Pool, Glow, Sim, Toast and Charts stay as the earlier bundles recorded;
nothing in this range changes that premise.
