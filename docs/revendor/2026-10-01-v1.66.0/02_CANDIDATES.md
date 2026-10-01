# Candidates (ConsumableMaster, LibKa0s v1.65.0 -> v1.66.0)

Listed, not interviewed: the 2026-10-01 issue pass (spec S4) defers adoption decisions to the
collection census, GI-LK-13. Sources: the CHANGELOG v1.66.0 block and the version documents under
`../LibKa0s/docs/api/` at the tag.

## A. Delivered on the re-vendor alone (not offered)

- **Perf `BuildRecord` emits a declared ancestor that never fired** (CHANGELOG v1.66.0, "Perf minor
  14: a declared parent that never fired"). This addon's `core/PerfSetup.lua` declares two flat
  buckets (`cooldown`, `recompute`) with no `within`, so its record does not change.
- **Widgets, Slash, Perf and DebugLog peels** (`WidgetsReorder.lua`, `SlashParse.lua`,
  `PerfSampler.lua`, `PerfCommands.lua`, DebugLog's hoisted `lib:New` helpers): no member moves; the
  priority rows' drag, `/cm set`, `/cm perf` and the console behave as on v1.65.0.
- **`RenderGrid` releases a failed wide item with no spacer**: a render fault no longer leaves a blank
  row; this addon's grid pages change nothing on screen when every item draws.

## B. Host change required (candidates)

| # | What | Evidence | Files here | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | Pass Slash's resolver from the host `parse` to `lib.ParseValue`, so the three `L` overrides reach chat | `docs/api/Slash/version-19.1-docs.md`, "What changed at this version" | `settings/Slash.lua` (`parseValue`) | Adopt: it is this plan's own item **GI-CM-01** (ConsumableMaster#16), not a census candidate | Additive, one argument |
| B2 | Report-only per-bucket `budget = { msPerSec, maxMs }` on the Perf descriptor | CHANGELOG v1.66.0, "Perf minor 14: report-only per-bucket budgets"; `docs/api/Perf/version-14.1.1.6-docs.md` | `core/PerfSetup.lua`, `tests/test_perfsetup.lua` | For the census (GI-LK-13): declare from the committed captures under `docs/perf-analysis/` | Additive, report only |
| B3 | `RenderGrid(ctx, items, parent, opts)`: `parent` and `opts.gap` | CHANGELOG v1.66.0, "OptionsWidgets minor 34" | `settings/Panel.lua` (`Helpers.Grid` callers) | Not needed: every grid here draws into the page scroll with the default gap | Additive |
| B4 | `RenderTabbedSchema` `untabbedSkipRender`, `disabledReplaces`, `rerender` | CHANGELOG v1.66.0, "OptionsTabs minor 8" | settings pages | Not needed today; for the census | Additive |

## C. Whole-module adoption

None: every major in the payload except `Pool` is looked up outside `libs/` and `tests/`, unchanged
from v1.65.0.
