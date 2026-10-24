# Candidates (ConsumableMaster, LibKa0s v1.76.0 -> v1.77.0)

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0` (15 commits), the CHANGELOG `v1.77.0`
block at the tag, `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`,
`docs/api/Widgets/version-15.1.5.3.3-docs.md` and `docs/api/testkit/version-42-docs.md` at the tag.

The run's manifest (Ka0sAddonsCommonTasks `docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/plan-data/items.json`,
item CM-RV) pre-decides adoption: the adoptions ConsumableMaster takes from this tag are its CM-ZS
item; every other candidate is recorded here as **deferred (run 2026-10-24)**, without an interview.

## A. Delivered on the re-vendor alone

- **Toplevel tool windows** (Core 12, DebugLog 21, PerfPanel 9): the `/cm debug` console and the
  `/cm perf` step panel are toplevel and re-raise a shown confirmation (`Core.RaiseStaticPopups`)
  on show. CHANGELOG v1.77.0, "toplevel tool windows"; "What a consumer owes: nothing."
- **Clamped popups** (Widgets 15, WidgetsAutocomplete 3): the dropdown menu and the autocomplete
  list stay on screen near an edge. CHANGELOG v1.77.0, "popups clamped to screen".
- **The IdList / IdInput suggestion list closes at combat start** (OptionsIds 3, OptionsCombat 2):
  CM's Add-by-ID box gets it on the copy. CHANGELOG v1.77.0, "the suggestion list closes when
  combat starts".
- **Sim 2.3.6** (SimPanel 6): reaches no code path here; CM does not consume `Sim-1.0`.

## B. New surfaces (host change required)

| Surface | Evidence | Touches | Blast radius | Decision |
|---|---|---|---|---|
| `DragHandle` `spec.level`, `spec.ignoreParentAlpha`, `handle:ApplyLevel()` | CHANGELOG v1.77.0 "WidgetsDragHandle minor 5"; Widgets doc 15.1.5.3.3 | `settings/Category.lua`, `settings/StatPriority.lua`, `settings/MacroBar.lua`, `modules/MacroBar.lua` | additive | **for CM-ZS** (the run names CM among the adopters, CON-Z08); not adopted here |
| `O.StrataTooltip(values[, strings])` | CHANGELOG v1.77.0 "OptionsCompose minor 8"; Options doc 30.2.34.3.5.9.2.8.4.2.1.3 | none today (no settings row offers a strata); only a row CM-ZS's accepted list adds | additive | **for CM-ZS** to decide against `accepted.json`; not adopted here |
| `O.KeybindingsTab`, `O.KeybindRows`, `O.KEYBINDS_UNCHANGED` | CHANGELOG v1.77.0 "OptionsKeybinds minor 2" | settings General page | additive | **deferred (run 2026-10-24)**: the run plans no CM-KB item |
| `Core.RaiseStaticPopups()` called by the host | CHANGELOG v1.77.0 "A shown confirmation stays on top" | none planned | additive | **deferred (run 2026-10-24)**: CM owns no toplevel window of its own |
| Kit `mock_bindings.lua`, `T.assertBindingsXml`, `T.keybindThroughTab` | testkit doc version-42, CHANGELOG "Test kit revision 42" | tests | additive | **deferred (run 2026-10-24)**: CM ships no `Bindings.xml` |
| Kit `mock_layers.lua` | testkit doc version-42 | tests | additive | **for CM-ZS**; not adopted here |

## C. Whole-module adoption

None offered. `Pool`, `Glow` and `Sim` ship unused, as before (`docs/revendor/2026-10-22-v1.75.0/02_CANDIDATES.md`);
v1.77.0 changes no premise of that.
