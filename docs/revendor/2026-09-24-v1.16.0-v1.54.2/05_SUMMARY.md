# 05 - Summary: LibKa0s span v1.16.0 -> v1.54.2 (base v1.15.0)

Plan item CM-28, 2026-09-24, branch `feat/2026-09-23-review-audit-remediation`. This bundle records
the 30 tags this addon vendored after its store's first bundle but never recorded (finding
ConsumableMaster-A-02). No code changes, nothing is re-vendored, and the addon version is not bumped.
The commit list, the base and how the span was derived are in `01_DELTA.md`.

## One line per tag

"Carried by sweep, nothing adopted" means the bytes arrived and this addon's own code took no new
surface from that tag. Anything the library fixed still reached the player through the carry.

- **v1.16.0**: carried by sweep, nothing adopted (`0dd978e`: Pool 2, Widgets 7, DebugLog 12, kit 13).
- **v1.18.0**: carried inside `f8cdd15` (options-ui-§12: the reset becomes `db:ResetProfile()` and the
  profile callbacks are wired). Those are host and AceDB changes, so nothing was adopted from the
  library.
- **v1.18.1**: carried by sweep, nothing adopted (OptionsWidgets 8's landing-logo texture fix arrives
  with the bytes).
- **v1.19.0**: `65e5a87` adopts **`Widgets.ReorderList`**: a priority row is dragged into place
  instead of stepped with arrows. `2013d96` and `0925734` follow up on it, and `55c1196` documents it.
  These rode a pre-release `Widgets.lua` under the v1.19.0 line, and `c2f369a` carried the released
  copy.
- **v1.23.0**: `a256a2e` adopts **`RenderTabbedSchema`** and **`PageBanner`**: eighteen sidebar
  entries become four tabbed pages, and the Stat Priority spec dropdown moves into the banner.
- **v1.24.0**: `ab4c564` adopts the settings-revamp-v2 contract in the copy's own commit: the
  composed Master controls tab, a tab strip on every page, the library's font, border and bar
  composers, and `ReorderList` on the AIO tabs and Stat Priority.
- **v1.26.0**: `ac37b2a`: the host-side `lsmValues` workaround in `settings/MacroBar.lua` comes out,
  because OptionsCompose 3 fixes LibKa0s issue #15.
- **v1.27.0**: `44f8757`: the kit's `test_eol.lua` gate is wired into `tests/run.lua`.
- **v1.28.0**: carried by sweep, nothing adopted (Perf 9's usage block fix arrives with the bytes).
- **v1.29.0**: carried by sweep, nothing adopted. `e496a9e` updates `tests/test_perfsetup.lua` for the
  retired `perf dump` verb.
- **v1.35.0**: `553b5d4` adopts **`O.IdInput`** (with `ResolveId`) for the Add-by-ID line, and
  `5944551` documents it. Four re-cuts of the tag followed (`d375596`, `f962fad`, `dcab736`,
  `5ecff5a`). Only `d375596` touched host code, to correct comments on the clear-before-onAdd order.
- **v1.36.0**: carried by sweep, nothing adopted.
- **v1.36.1**: carried by sweep, nothing adopted (the pooled CheckBox color fix arrives with the bytes).
- **v1.36.2**: carried by sweep, nothing adopted. `66fb9d8` updates one test assertion for the
  library's ASCII `->`.
- **v1.37.0**: carried by sweep, nothing adopted. The addon has no test mode that stays on, so it
  passes no `testModePath`.
- **v1.38.0**: `c4e832d`: a bare `/cm` opens the settings panel (Slash 11), together with the
  library-absent stub and the tests, in the re-vendor commit itself.
- **v1.39.0**: `2d7ab90` adopts **`LibKa0s-Launcher-1.0`** (launcher-§1): one object registered as the
  minimap button and the broker plugin, with the addon's own icon. `59d619b` documents it.
- **v1.42.0**: `a6e592e` adopts **`LibKa0s-Lifecycle-1.0`**: disabling the addon stands it down, and
  a perf run takes the same latch. The copy rode in this commit.
- **v1.43.0**: carried by sweep, nothing adopted (kit revision 23 only; the library bytes did not move).
- **v1.44.0**: carried by sweep, nothing adopted (`removeStyle = "icon"` belongs to `O.IdList`, which
  this addon does not call).
- **v1.45.0**: carried by sweep, nothing adopted (`shownWhen` is unused here).
- **v1.46.1**: carried by sweep, nothing adopted. The settings panel's combat lock arrives with the
  bytes and needs no host code.
- **v1.47.0**: carried by sweep, nothing adopted. `O.IdList` `columns` does not apply: the addon has
  no `O.IdList` call site, and `columns` is not an `IdInput` option.
- **v1.48.0**: `82e0dc0` adopts **`Widgets.DragHandle`**: `modules/MacroBar.lua` stops drawing its own
  drag strip, in the re-vendor commit itself.
- **v1.48.1**: `2794e3f`: tests cover the help-mark tooltip that DragHandle minor 2 fixed for this bar.
- **v1.50.0**: carried by sweep, nothing adopted.
- **v1.51.0**: carried by sweep, nothing adopted (the optional `O.IdList` help fields are unused here).
- **v1.52.0**: carried by sweep, nothing adopted.
- **v1.53.0**: carried by sweep, nothing adopted. The `O.IdInput` Add button height fix reaches the
  Add-by-ID line with the bytes.
- **v1.54.2**: carried in `1f86d4e`, nothing adopted in the span. The kit's US-English prose gate
  (`tests/_kit/test_prose.lua`, kit revision 24) arrived in that commit. Despite the commit's
  subject, it left the repo's own `tests/test_prose.lua` in place and did not wire the kit's gate.
  Both happened at the v1.55.0 re-vendor (`34813a4`), which the v1.55.0 bundle records.

## Adoptions outside the span

The plan's item text also names **Bus** and **Compat** as adoptions along the span. Both landed after
the span, under v1.55.0: `e3c13b7` (the `LibKa0s-Bus-1.0` stand-down record) and `c14db97` (the spec
pair, `IsSecret` and `GetSpellName` on `LibKa0s-Compat-1.0`). The v1.55.0 bundle
(`docs/revendor/2026-09-23-v1.55.0/`) records those, so they are not listed per tag here.

## Declined

No candidate from the span was put to a decision at the time, so nothing counts as declined and no
issue is filed. The v1.47.0 `columns` note above is "does not apply", not a decline.

## Open

- The frozen bundles are not edited. `docs/revendor/2026-09-03/` keeps its heading-style line 1. The
  audit reads only the last tag from it, which is why v1.24.0 is in this span.
- From here, every re-vendor writes its own `docs/revendor/<YYYY-MM-DD>-v<tag>/` bundle, as
  `2026-09-23-v1.55.0/` and `2026-09-23-v1.56.0/` already do.
