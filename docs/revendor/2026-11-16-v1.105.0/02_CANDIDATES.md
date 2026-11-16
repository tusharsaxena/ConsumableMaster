# 02 Candidates

Range v1.94.0..v1.105.0. Sources: the tag's `CHANGELOG.md` blocks v1.95.0 to v1.105.0 (*What a consumer owes*,
v1.105.0), and Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md` with research note R7
section 3 (site counts re-derived here by grep).

## Class A: delivered on the re-vendor alone

- Reports Copy as plain text (DebugLog minor 23, #79): every `DL.Report` verb (`dump`, `priority ... list`,
  `stat list`, `aio ... list`, `seed status`) keeps its colors on screen and pastes plain.
- The console's status line is a 24 px Widgets footer, its counter in `text.muted` (#90).
- Header marks on every library window this addon opens (the debug console, the copy window, the perf panel, the
  skin picker), with a settings mark that opens Consumable Master's settings through the launcher (#86).
- The library's own tooltips placed by `LibKa0s-Tooltip-1.0`, never at the cursor: the macro bar strip's fallback,
  dropdown and context-menu entries, the minimap button (#92 part B).
- Skin colors: Ka0s Default's list stripe, hover and selection, seven skins' `icon.hot`, Glass's and High
  Contrast's `icon.tint` (#82, #84).

## Class B: host change required. Owed in phase [3], not offered in this run

| Issue | Surface | Sites in this addon | Note |
|---|---|---|---|
| LibKa0s#79 | `D:Report` / `D:Serialize` | `core/DebugLogSetup.lua` `DL.Report` (its own comment names the lift: the body becomes `return D:Report(tag, title, fn)`); `core/SlashDump.lua:83` `serialize` (published as `Serialize`, `:575`) | One-line lift and delete the local serializer; the degraded arm in `core/DebugLogSetup.lua:124-129` goes. |
| LibKa0s#92 | Tooltip placers `PlaceBeside` / `PlaceAttached` | 5 own `SetOwner(..., "ANCHOR_RIGHT")`: `core/MacroDisplay.lua:155,234`, `modules/KCMItemRow.lua:398`, `settings/MacroBarSlots.lua:235`, `settings/StatPriority.lua:471`; plus the strip hook `modules/MacroBar.lua` `MB.PlaceTooltipBeside`, which `PlaceBeside` replaces | Settings-canvas sites may be out of scope (R7 open question 6); confirm per site. |
| LibKa0s#86 | `W.HeaderButtons`, drag-handle settings mark | No own windows; the macro bar's drag strip can turn on its settings mark | Per-addon opt-in at adoption. |
| LibKa0s#82 | Host owner tokens at the contrast floors | Check `core/SkinSetup.lua`'s own tokens for a `*.hot` alias | None found by grep; re-check at adoption. |

Not applicable here: #85 (Callout, not consumed), #87 (no test or sim mode, no sample characters), #88 (no
test/sim strip), #89 (no hand-built footer), #80 and #81 (Skill Master only).

## Class C: whole-module adoption

`LibKa0s-Tooltip-1.0` is unconsumed and is the #92 row above. Role, Callout, WaypointArrow, Charts and Sim stay
unconsumed with no use in this addon.
