# Decisions (ConsumableMaster, LibKa0s v1.76.0 -> v1.77.0)

Pre-decided by the run's manifest (Ka0sAddonsCommonTasks
`docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/plan-data/items.json`, item CM-RV: "Adoption interview: do
NOT interview; the adoptions this run needs are the CM-KB and CM-ZS items, so record every other
candidate as 'deferred (run 2026-10-24)' in the bundle and file nothing"). The run plans no CM-KB
item. The interview step did not run.

- `DragHandle` `level` / `ignoreParentAlpha` / `ApplyLevel`: **left to CM-ZS**.
- `O.StrataTooltip`: **left to CM-ZS** (CM has no strata row today; adopted there only if its accepted list adds one).
- Kit `mock_layers.lua`: **left to CM-ZS**.
- `O.KeybindingsTab` / `O.KeybindRows` / `O.KEYBINDS_UNCHANGED`: **deferred (run 2026-10-24)**.
- Host calls of `Core.RaiseStaticPopups()`: **deferred (run 2026-10-24)**.
- Kit `mock_bindings.lua` / `T.assertBindingsXml` / `T.keybindThroughTab`: **deferred (run 2026-10-24)**.
- No GitHub issue filed.
- The `LibKa0s icons:` declaration is kept as `clear, close, copy, help, info, segment.`
