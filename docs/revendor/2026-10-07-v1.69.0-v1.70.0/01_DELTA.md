Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

Written by RV-CM (2026-10-07 review and standards-audit remediation) with the v1.71.0 re-vendor
bundle beside it, because the 2026-10-07 standards audit (finding CM-91, verified as `CM-A-01`)
found two vendored tags with no bundle and no register row. The store's newest bundle before this
one was `2026-10-04-v1.68.1`, so the base of the span is **v1.68.1**; that tag is already recorded
and is not part of the span.

```sh
grep -vxF -f recorded.txt vendored.txt
# v1.69.0
# v1.70.0
```

The carrying commits:

```sh
git log --format='%h %s' -S'LibKa0s) v1.69.0' -- CLAUDE.md | tail -1
# f8d2f3b chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)
git log --format='%h %s' -S'LibKa0s) v1.70.0' -- CLAUDE.md | tail -1
# 74bcda1 chore: re-vendor LibKa0s v1.70.0
```

- **v1.69.0** (`f8d2f3b`, merged in `862151a`): adds `WidgetsLineChart.lua` (minor 1) to the
  `LibKa0s-Widgets-1.0` major and kit revision 37 (`mock_lines.lua`; `mock_base.lua` gains the
  line mock). The provenance line, and the kit-revision stamp in `docs/testing.md`, rolled in the
  same commit.
- **v1.70.0** (`74bcda1`): adds `WidgetsAutocomplete.lua` (minor 1) and moves `WidgetsLineChart` to
  minor 2 (`opts.pxPerPoint`). The kit stays at revision 37.

Neither added surface is called by this addon: no host code outside `libs/` and `tests/_kit/`
calls `LineChart`, `ChartMath` or `Autocomplete`. The `Widgets` major itself is consumed (the drag
handle behind the priority rows and the macro bar), and nothing it already used moved in the span.
No `NEEDS_*` floor rose and no major was added, so the fourteen consumed majors stand.
