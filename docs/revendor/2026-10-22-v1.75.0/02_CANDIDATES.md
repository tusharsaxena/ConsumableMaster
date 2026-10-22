# Candidates (ConsumableMaster, LibKa0s v1.71.0 -> v1.75.0)

Sources: `git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` (56 commits), the CHANGELOG blocks
v1.72.0 to v1.75.0 at the tag, and the `docs/api/` documents of every major whose minor moved.

The run's owner scope assigns ConsumableMaster no adoption, so every new surface is decided
**not adopted**, each with its reason. No interview, no GitHub issue.

## A. Delivered on the re-vendor alone

- **The icon declaration and prune** (`library-stack-§7`, kit 40): the copy ships six marks instead
  of 5,836, and `tests/test_vendor_sync.lua` holds it to the line.
- **Kit 41's complexity rule**: a crashed or bounded lizard run is a complexity fail.
- **Library fixes inside consumed majors** (Core 11, DebugLog 20, DebugLogDiagnostics 3, Options 29,
  OptionsTabs 9, OptionsIdList 5, Perf 15, PerfPanel 7, Widgets 13, Item 3): no host change needed.

## B. New surfaces, not adopted

| Surface | Decision | Reason |
|---|---|---|
| `W.SearchBox` | not adopted | CM has no filter-bar window |
| `W.TestStrip` | not adopted | CM has no test mode |
| `W.StepPanel` | not adopted | not public at v1.75.0 (LK-11 outcome B, Sim-private); CM has no step panel beyond the PerfPanel |
| `Glow-1.0` | not adopted | CM draws no glow |
| `Sim-1.0` | not adopted | CM has no simulator |
| `Item.BonusIDsFromLink` | not adopted | CM reads no bonus IDs |
| `O.Drawer` (`OptionsDrawer`) | not adopted | no settings page needs a drawer; the Macros and Macro Bar pages lay out their own rows |
| `Perf.Note` `parentKey = false` | not adopted | CM's two notes (`core/ConsumableMaster.lua:326` `recompute`, `modules/MacroBar.lua:522` `cooldown`) state no parent; the nil "not stated" form is what they mean |
| `Kit.assertLatchHoldOrder` (kit 39) | not adopted | no item of this run asks for it; CM's stand-down and perf-arm cases (`tests/test_disabled.lua` and siblings) stay as written |
| `Media.ICON_SETS`, `Media.IconAuthor` | not adopted | CM ships no Phosphor or Game-icons mark, so it has no per-icon author to credit and no set chooser |

## C. Whole-module adoption

None. `Pool`, `Glow` and `Sim` ship unused.
