# Refresh (ConsumableMaster): the moved local tag v1.75.0

After `05_SUMMARY.md` was written, the local annotated tag v1.75.0 moved twice in LibKa0s (OWNER_SCOPE
B): `265a89e` -> `6bf5f3e` (LK-26: Sim minor 2, SimTimeline minor 2) -> `9e5c4e2` (LK-27: SimPanel
minor 2). `9e5c4e2` (tag object `d0ad7d8`) is its final position. This file records the refresh;
`01_DELTA.md` to `05_SUMMARY.md` stay as written.

- **Old commit:** `265a89e` (tag object `eae0ee5`), vendored by CM-RV.
- **New commit:** `9e5c4e2` (tag object `d0ad7d8`).
- **Method:** the same copy CM-RV made: both payloads whole from
  `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit`, no stray files to delete, then the tag's
  `tools/prune-icons.lua` against the unchanged `LibKa0s icons:` line (6 declared, 7 files kept,
  5,833 removed). The provenance line stays v1.75.0.

## Files that changed

| File | Old minor | New minor |
|---|---|---|
| `libs/LibKa0s/Sim.lua` | `LibKa0s-Sim-1.0` 1 | 2 |
| `libs/LibKa0s/SimTimeline.lua` | `TIMELINE_MINOR` 1 | 2 |
| `libs/LibKa0s/SimPanel.lua` | `SIM_PANEL_MINOR` 1 | 2 |

Nothing else in `libs/LibKa0s/` or `tests/_kit/` moved; the kit revision is unchanged.

## Addon impact

None. ConsumableMaster vendors `Sim-1.0` but does not consume it (`05_SUMMARY.md`, Not adopted), and
no test or doc here pins a Sim, SimTimeline or SimPanel minor. `tests/test_vendor_sync.lua` now
compares against the moved tag.
