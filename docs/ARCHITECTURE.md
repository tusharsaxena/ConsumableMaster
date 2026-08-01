# Architecture

Orient-yourself map for **Ka0s Consumable Master**. This file is the high-level index; topic detail lives alongside it in `docs/`. Ka0s WoW Addon Standard.

## What it does

Thirteen account-wide global macros (`KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`, `KCM_FLASK`, `KCM_CMBT_POT`, `KCM_STAT_FOOD`, `KCM_WPN_ENCH`, `KCM_AUG_RUNE`, `KCM_HP_AIO`, `KCM_MP_AIO`) whose bodies auto-rewrite to point at the best consumable currently in your bags. Eleven macros run a per-category scorer; two are composites that compose other categories' picks via combat conditionals. Identified by name, never by slot — coexists with every other macro in the user's account-wide pool.

Those macros are also hosted on a **CM-only macro bar** (on by default) — one secure slot per category, each with a hover flyout listing every currently-usable candidate in that category. It is the addon's only protected-frame surface; see [macro-bar.md](./macro-bar.md).

## Namespace & promotion

- **Private namespace, no globals.** Every file begins `local addonName, NS = ...` — WoW hands the same private table to each file. `core/Namespace.lua` loads first and names it (`NS.name`). There is **no `_G.KCM`**; the only shared handle is a per-file transition alias `local KCM = NS`, so the tree's internal `KCM.*` references resolve to the private namespace.
- **AceAddon promotion.** `core/ConsumableMaster.lua` calls `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceConsole-3.0")` and stores `NS.addon`. Event handlers are dispatched from `OnEnable`, so their bodies may reference modules that load later.

## Layout

| Folder | Holds |
|--------|-------|
| `core/` | Namespace, AceAddon entry (`ConsumableMaster.lua`) + recompute pipeline, Bus, Compat, Constants, State, Database, Debug, the pure engine (SpecHelper, TooltipCache, BagScanner, Classifier, WeaponSlots), the macro bar's pure halves (MacroDisplay, MacroBarModel, MacroBarLayout), the LSM widget fixup (LSMPatch), SlashCommands |
| `modules/` | Ranker, Selector, MacroManager, DebugLog console, PerfSetup (the A/B capture harness), the macro bar (MacroBar, MacroBarButton, MacroBarFlyout), the `KCM*` AceGUI widgets |
| `defaults/` | Seed itemID lists + the category table (data, not code) |
| `settings/` | Options panel + per-tab pages |
| `locales/` | `enUS.lua` (`KCM.L`) — English only |

`ConsumableMaster.toc` is the load-order source of truth (dependency order, not alphabetical).

## Subsystems at a glance

```
WoW events ─▶ KCM.bus (RECOMPUTE) ─▶ Core.Pipeline ─▶ Selector ─▶ Ranker     ─▶ candidate score
                                          │              │     ─▶ Classifier ─▶ auto-discovery match
                                          │              │
                                          │              ├─▶ pick (first owned id)
                                          │              └─▶ PickBestForSlot(16/17) ─▶ per-hand pick
                                          │                    (perHand cats; WeaponSlots affinity filter)
                                          │
                                          ├─▶ MacroManager.SetMacro / SetWeaponEnchantMacro
                                          │                 / SetCompositeMacro
                                          │     └─▶ CreateMacro / EditMacro   (the only protected-API caller)
                                          │
                                          ├─▶ KCM.bus (PANEL_REFRESH)    ─▶ Options panel
                                          └─▶ KCM.bus (MACROBAR_REFRESH) ─▶ Macro bar (on by default; can be switched off)

  AceDB (one account-wide profile)  ──  Options panel + /cm slash CLI
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-module APIs + roles | `core/*.lua`, `modules/*.lua`, `settings/*.lua` | [module-map.md](./module-map.md) |
| Recompute pipeline + score cache + events | `core/ConsumableMaster.lua` (`KCM.Pipeline`) | [pipeline.md](./pipeline.md) |
| AceDB schema + opaque IDs + discovered GC | `core/ConsumableMaster.lua` (`KCM.dbDefaults`, `KCM.ID`), `core/Database.lua`, `modules/Selector.lua` | [data-model.md](./data-model.md) |
| MacroManager (body builders, composite assembly, combat deferral, action-bar icons) | `modules/MacroManager.lua` | [macro-manager.md](./macro-manager.md) |
| Tooltip parsing + Midnight gotchas | `core/Classifier.lua`, `core/TooltipCache.lua` | [midnight-quirks.md](./midnight-quirks.md) |
| Settings panel + slash CLI + schema layer | `settings/*.lua`, `libs/LibKa0s/Options.lua`, `core/SlashCommands.lua` | [debug.md](./debug.md), [file-index.md](./file-index.md) |
| Message bus | `core/Bus.lua` | Catalog below |
| Compat seam (spec + spell APIs) | `core/Compat.lua` | [module-map.md](./module-map.md) |
| Debug console | `modules/DebugLog.lua`, `libs/LibKa0s/DebugLog.lua`, `core/State.lua` | [debug.md](./debug.md) |
| Perf A/B capture (`/cm perf`) | `modules/PerfSetup.lua`, `libs/LibKa0s/Perf.lua`, `libs/LibKa0s/PerfPanel.lua` | [debug.md](./debug.md) |
| Optional CM-only macro bar (secure slots, layout, visibility) | `core/MacroBar*.lua`, `core/MacroDisplay.lua`, `modules/MacroBar*.lua`, `settings/MacroBar.lua` | [macro-bar.md](./macro-bar.md) |
| Per-file responsibility map | — | [file-index.md](./file-index.md) |
| Routine recipes (add category, refresh seeds, fix misclassification) | — | [common-tasks.md](./common-tasks.md) |
| Headless gate (tests + luacheck, TDD policy, badge sync) | `tests/` | [testing.md](./testing.md) |
| Smoke-test playbook (quick + full + targeted) | — | [smoke-tests.md](./smoke-tests.md) |
| In/out scope + resolved design decisions | — | [scope.md](./scope.md) |

## Message-bus catalog

Cross-module control flow that crosses feature boundaries travels over the closed bus (`core/Bus.lua`), never by reaching into another module's tables. Pure-function queries (MacroManager asking Selector/Ranker/Classifier for data) stay direct synchronous calls — they are data reads, not control flow.

`KCM.bus` is an AceEvent-embed. **Every receiver owns its own target** via `KCM.NewBusTarget()`; two subscriptions never share one table. `KCM.MSG` names each message:

| `KCM.MSG.*` | Wire name | Direction | Purpose |
|-------------|-----------|-----------|---------|
| `RECOMPUTE` | `Ka0s_ConsumableMaster_Recompute` | event / UI layer → pipeline | Request a pick recompute. The pipeline owns the **only** subscription (registered at load in `Bus.lua`) and forwards to `Pipeline.RequestRecompute`, which coalesces to one pass per frame. Carries an optional `reason` string. |
| `PANEL_REFRESH` | `Ka0s_ConsumableMaster_PanelRefresh` | pipeline → options panel | The pipeline finished a pass; any open settings page does a debounced rebuild against the new picks. |
| `SPEC_CHANGED` | `Ka0s_ConsumableMaster_SpecChanged` | spec change → options panel | Active spec changed; the Stat Priority page retracks to the new spec when auto-tracking. |
| `MACROBAR_REFRESH` | `Ka0s_ConsumableMaster_MacroBarRefresh` | pipeline → macro bar | The pipeline finished a pass; the optional macro bar repaints slot icons + counts. Undebounced (unlike `PANEL_REFRESH`) because a live on-screen bar should track the macro it just rewrote. |

## Invariants worth not breaking

- **`MacroManager` is the only caller of `CreateMacro` / `EditMacro`.** Selector, Ranker, Classifier, BagScanner, TooltipCache, SpecHelper must all stay pure (no protected APIs) so the pipeline can run in combat without taint.
- **Macros are always identified by name**, never by slot index. `perCharacter=false` puts them in the account-wide pool. The addon never calls `DeleteMacro` on a `KCM_*` macro.
- **Seed lists are data, not code.** Updating a `defaults/Defaults_*.lua` is a zero-migration upgrade — `added`/`discovered`/`blocked` live in SavedVariables and union with the seed at runtime.
- **English-only — tracked deviation** (localization-§4 / anti-pattern #37; see [scope.md](./scope.md)). Classification keys on the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`), so category and weapon-affinity detection work on every client. The remaining English dependency is TooltipCache's tooltip-TEXT parsing (heal/mana/stat magnitudes, the `Augment Rune` marker, weapon-application effect). `locales/enUS.lua` is a shell, not localization plumbing; full tooltip localization is a planned future release.
- **Private-namespace publishing pattern:** every file does `local addonName, NS = ...; local KCM = NS; KCM.Foo = KCM.Foo or {}; local F = KCM.Foo`. Never shadow the local over the namespace.
- **Recompute is coalesced.** Callers fire `KCM.MSG.RECOMPUTE` on the bus (or call `Pipeline.RequestRecompute`), never `Pipeline.Recompute` directly — except the rare direct paths (`KCM.ResetAllToDefaults`, `/cm resync`, `/cm rewritemacros`) where the write should land this tick.
- **Priority-list IDs are opaque numbers with sign semantics.** Positive = itemID, negative = `KCM.ID.AsSpell(spellID)`. Only `MacroManager`, `Ranker.Score`'s spell shortcut, and the UI fork on the sign; every other layer treats them as plain table keys.
- **Score cache lives for one Recompute pass and no longer.** `scoreCache` is created fresh in `Pipeline.Recompute` and threaded through `PickBestForCategory` → `SortCandidates`. Tooltip / bag / spec state can shift between events — never cache across passes. Non-pipeline callers (Options panel, `/cm dump pick`) pass `nil`.
- **Composite categories never own item buckets.** No `added`/`blocked`/`pins`/`discovered` — composites compose picks from their referenced single categories at recompute time. Sub-categories are locked to their `inCombat` / `outOfCombat` section.
- **Per-hand categories resolve twice from one bucket.** `perHand = true` (today only `WPN_ENCH`) keeps the ordinary spec-aware `bySpec` bucket — there is no per-slot persisted state. The pipeline calls `Selector.PickBestForSlot(catKey, 16, …)` and `(…, 17, …)` against that one list, each filtered to entries whose `tt.weaponAffinity` matches `WeaponSlots.SlotAffinity(slot)`. A hand with no weapon, or with nothing matching, is dropped from the macro body rather than falling back to the other hand's pick.
- **Action-bar icon sentinel.** Active body stores `DYNAMIC_ICON = 134400` (`?` fileID); empty body omits `#showtooltip` and stores `DEFAULT_ICON = 7704166` (cooking pot). Storing `DEFAULT_ICON` on an active body shows the cooking pot on the bar instead of the picked item's icon.
- **The macro bar owns the only protected frames, and never pokes them in combat.** Slots and flyout entries are secure buttons, so creating, anchoring, showing or hiding them is combat-forbidden. Everything funnels through `MacroBar.Update()`, which defers to `PLAYER_REGEN_ENABLED`; combat-conditional visibility goes to `RegisterStateDriver`, flyout hover to `_onenter`/`_onleave` snippets, and combat state reaches those snippets via `RegisterAttributeDriver` — all of it running in the secure environment instead. A slot's `macro` attribute is stamped once at creation and never rewritten.
- **Debug flag is session-only.** `KCM.State.debug` (`core/State.lua`) is never persisted — a session left with debug on doesn't leak into the next login.

## Timers

`C_Timer` is used directly rather than AceTimer, in three places: the pipeline's frame-coalescing (`RequestRecompute`), the options panel's refresh debounce (`O.RequestRefresh`), and the flyout's idle auto-close (`MacroBarFlyout`). This is a **deliberate, documented choice** (CM-09): the addon needs only fire-once short delays, `C_Timer` is a first-party API with no extra embed, and AceTimer is not otherwise required. The standard treats the timer choice as a SHOULD, so this justification satisfies it.

Note the flyout timer's limit: there is no timer inside the *secure* environment, so it cannot close a flyout mid-combat and deliberately stands down instead ([macro-bar.md](./macro-bar.md#closing)).

## External dependencies

All vendored under `libs/`:

- LibStub
- CallbackHandler-1.0
- AceAddon-3.0
- AceEvent-3.0
- AceDB-3.0
- AceConsole-3.0
- AceGUI-3.0
- LibSharedMedia-3.0 (debug-console monospace font registration; also the media source behind the macro bar's border pickers)
- AceGUI-3.0-SharedMediaWidgets (the `LSM30_Border` preview dropdown used by those pickers; `core/LSMPatch.lua` fixes up its misaligned preview tile)

The libraries are listed directly in `ConsumableMaster.toc` under `# Libraries` (LibStub first, then CallbackHandler, LibSharedMedia, and the Ace3 sub-libraries in dependency order) — no `embeds.xml` wrapper (per the standard, toc-file-§4). The TOC's `## Interface:` line is `120007`.

## Load order

`ConsumableMaster.toc` is the source of truth. Order is dependency, not alphabetical:

1. `# Libraries` — LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, and the Ace3 sub-libraries (AceAddon/AceEvent/AceDB/AceConsole/AceGUI), listed directly in the TOC
2. `# Locales` — `locales/enUS.lua`
3. `# Core` — `Namespace.lua` (names `NS`) → `ConsumableMaster.lua` (AceAddon promotion + DB + pipeline) → `Bus.lua` → `Constants.lua` → `CoreSetup.lua` → `Compat.lua` → `State.lua` → `Database.lua` → `Debug.lua` → `SpecHelper` → `TooltipCache` → `WeaponSlots` → `BagScanner` → `Classifier` → `LSMPatch` → `MacroDisplay` → `MacroBarModel` → `MacroBarLayout` → `SlashCommands`
4. `# Defaults` — `Categories.lua` then `Defaults_*.lua`
5. `# Modules` — `Ranker` → `Selector` → `MacroManager` → `DebugLog` → `PerfSetup` (after DebugLog, whose ungated `AddLine` is where its run log goes) → the macro bar (`MacroBarFlyout` → `MacroBarButton` → `MacroBar`, in that order: the container builds slots that own flyouts) → AceGUI widgets (`KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`)
6. `# Settings` — `Panel.lua` (must come first — registers `KCM.Settings.Helpers` + `RegisterTab`, publishes the `KCM.Options` shim) → `General.lua` → `MacroBar.lua` → `StatPriority.lua` → `Category.lua`

Event handlers and `Pipeline` functions are *defined* while `core/ConsumableMaster.lua` loads but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.
