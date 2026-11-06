# Candidates, v1.89.0 -> v1.90.0

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the tag's `CHANGELOG.md` block v1.90.0, and the
`docs/api/` documents of every major whose minor moved (Core, Widgets, Skin, Options). No 3g blocker exists,
so none is excluded here.

## A. Delivered by the re-vendor alone

- **Widgets minor 24, WidgetsAutocomplete minor 8** (CHANGELOG v1.90.0 *One physical pixel*;
  `docs/api/Widgets/version-24.5.12.6.8.5-docs.md:27`, "What a host owes: nothing"): `W.Dropdown`'s box,
  `W.SearchBox`, the shared menu and the autocomplete list draw a one-physical-pixel edge at any UI scale.
  This addon reaches the autocomplete list through its settings pages' *Add by ID or name* box.
- **Core minor 16** (`docs/api/Core/version-16-docs.md:14`): the internal pixel-edge mechanism behind the above.
- **SkinPaint minor 19, SkinPaintExtras minor 18**: `P.px` and the pixel watch moved onto Core's; no member moves.

## B. Host change required

- **`RegisterOwner(owner, { keepScope = true })`** (Skin minor 17, OptionsAppearance minor 7;
  `docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md:26`). For a host whose Scope is a
  documented deviation. This addon documents none (`core/SkinSetup.lua:769`), so not applicable.

## C. Whole-module adoption

None new in this range. IconBrowser, Pool, Glow, Sim, Toast and Charts stay unconsumed, as the v1.89.0 bundle
recorded; nothing in this range changes that premise.
