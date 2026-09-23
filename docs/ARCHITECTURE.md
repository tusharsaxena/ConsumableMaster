# Architecture

Orient-yourself map for **Ka0s Consumable Master**. This file is the high-level index; topic detail lives alongside it in `docs/`. Ka0s WoW Addon Standard.

## Overview

Fifteen account-wide global macros (`KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`, `KCM_FLASK`, `KCM_CMBT_POT`, `KCM_STAT_FOOD`, `KCM_WPN_ENCH`, `KCM_AUG_RUNE`, `KCM_BLOODLUST`, `KCM_BATTLE_REZ`, `KCM_HP_AIO`, `KCM_MP_AIO`) whose bodies auto-rewrite to point at the best consumable currently in your bags. Thirteen macros run a per-category scorer; two are composites that compose other categories' picks via combat conditionals. Identified by name, never by slot — coexists with every other macro in the user's account-wide pool.

Those macros are also hosted on a **CM-only macro bar** (on by default) — one secure slot per category, each with a hover flyout listing every currently-usable candidate in that category. It is the addon's only protected-frame surface; see [macro-bar.md](./macro-bar.md).

## Namespace & promotion

- **Private namespace, no globals.** Every file begins `local addonName, NS = ...` — WoW hands the same private table to each file. `core/Namespace.lua` loads first and names it (`NS.name`). There is **no `_G.KCM`**; the only shared handle is a per-file transition alias `local KCM = NS`, so the tree's internal `KCM.*` references resolve to the private namespace.
- **AceAddon promotion.** `core/ConsumableMaster.lua` calls `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceConsole-3.0")` and stores `NS.addon`. Event handlers are dispatched from `OnEnable`, so their bodies may reference modules that load later.

## Layout

| Folder | Holds |
|--------|-------|
| `core/` | Namespace, AceAddon entry (`ConsumableMaster.lua`) + recompute pipeline, Bus, Compat, Constants, State, Database, Debug, the pure engine (SpecHelper, TooltipCache, BagScanner, Classifier, WeaponSlots), the macro bar's pure halves (MacroDisplay, MacroBarModel, MacroBarLayout), the `/cm dump` targets (SlashDump) and the slash **verb bodies** (SlashCommands) — the dispatcher itself is `settings/Slash.lua` |
| `modules/` | Ranker, Selector, MacroManager, the macro bar (MacroBar, MacroBarButton, MacroBarFlyout), the `KCM*` AceGUI widgets |
| `defaults/` | Seed itemID lists + the category table (data, not code) |
| `settings/` | Options panel + its five pages (General, Macros, Stat Priority, Macro Bar, Profiles) |
| `locales/` | `enUS.lua` (`KCM.L`) — English only |

`ConsumableMaster.toc` is the load-order source of truth (dependency order, not alphabetical).

The over-cap census, *Files over the 1500-line cap*, sits under [Documented deviations](#documented-deviations),
the parent `layout-§1` fixes for it.

## Module Map

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

  AceDB (per profile: every setting)  ──  Options panel + /cm slash CLI + Profiles page
      │  OnProfileChanged / OnProfileCopied / OnProfileReset
      └─▶ profile handler ─▶ migrations ─▶ forget fingerprints (switch, copy) ─▶ resync (above)
                           └─▶ KCM.bus (PROFILE_CHANGED) ─▶ Macro bar (Update) + Options panel + Profiles page
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-module APIs + roles | `core/*.lua`, `modules/*.lua`, `settings/*.lua` | [module-map.md](./module-map.md) |
| Recompute pipeline + score cache + events | `core/ConsumableMaster.lua` (`KCM.Pipeline`) | [data-flow.md](./data-flow.md) |
| AceDB schema + opaque IDs + discovered GC | `defaults/Profile.lua` (`KCM.dbDefaults`), `core/ConsumableMaster.lua` (`KCM.ID`), `core/Database.lua`, `modules/Selector.lua` | [schema.md](./schema.md) |
| MacroManager (body builders, composite assembly, combat deferral, action-bar icons) | `modules/MacroManager.lua` | [macro-manager.md](./macro-manager.md) |
| Tooltip parsing + Midnight gotchas | `core/Classifier.lua`, `core/TooltipCache.lua` | [midnight-quirks.md](./midnight-quirks.md) |
| Settings panel + slash CLI + schema layer | `settings/*.lua` (incl. `settings/Slash.lua`, the dispatcher), `libs/LibKa0s/Options.lua`, `core/SlashCommands.lua` + `core/SlashDump.lua` (verb bodies), `libs/LibKa0s/Slash.lua` | [debug.md](./debug.md), [module-map.md](./module-map.md) |
| Message bus | `core/Bus.lua` | Catalog below |
| Compat seam (spec + spell APIs) | `core/Compat.lua` | [module-map.md](./module-map.md) |
| LibKa0s seams (media, TOC manifest, item-link primitive) | `core/MediaSetup.lua`, `core/EnvSetup.lua`, `core/ItemSetup.lua` | [module-map.md](./module-map.md) |
| Debug console | `core/DebugLogSetup.lua`, `libs/LibKa0s/DebugLog.lua`, `core/State.lua` | [debug.md](./debug.md) |
| Perf A/B capture (`/cm perf`) | `core/PerfSetup.lua`, `libs/LibKa0s/Perf.lua`, `libs/LibKa0s/PerfPanel.lua` | [debug.md](./debug.md) |
| Optional CM-only macro bar (secure slots, layout, visibility) | `core/MacroBar*.lua`, `core/MacroDisplay.lua`, `modules/MacroBar*.lua`, `settings/MacroBar.lua` | [macro-bar.md](./macro-bar.md) |
| Per-file responsibility map | — | [module-map.md](./module-map.md) |
| Routine recipes (add category, refresh seeds, fix misclassification) | — | [common-tasks.md](./common-tasks.md) |
| Headless gate (tests + luacheck, the vendored-LibKa0s copy diff, TDD policy, badge sync) | `tests/` | [testing.md](./testing.md) |
| Contributor toolchain — what to install to build, run, test or release | — | [../DEPENDENCIES.md](../DEPENDENCIES.md) |
| Automated test records (produced at release — recorded, not a gate) | — | [automated-tests/](./automated-tests/) |
| Smoke-test playbook (quick + full + targeted) | — | [smoke-tests.md](./smoke-tests.md) |
| In/out scope + resolved design decisions | — | [scope.md](./scope.md) |
| Test-case inventory (generated — the authoritative pass count) | `tests/` | [test-cases.md](./test-cases.md) |
| Seed reference + patch-day refresh procedure | `defaults/` | [../defaults/README.md](../defaults/README.md) |

## Settings Schema

Two layers, and it is worth keeping them apart.

**Persisted state** is an AceDB profile under the `ConsumableMasterDB` SavedVariable (declared with `ConsumableMasterPerfDB` at `ConsumableMaster.toc:11`), seeded from the `dbDefaults` tree in `defaults/Profile.lua`, which is the single declaration site for every shipped default (`savedvariables-§2`). `core/Database.lua` owns the version (`D.CURRENT_SCHEMA = 3`) and the migration steps. Field semantics, the composite bucket shape, the opaque-numeric ID convention and the discovered-set GC are documented in full in [schema.md](./schema.md) — this section does not duplicate them.

**Declared rows** are `KCM.Settings.Schema`, an ordered array published by `settings/Panel.lua` and appended to by the page files — **79** rows, counted by the page they sit on: 64 of them `macroBar.*` rows on the Macro Bar page, 7 the General page's composed Master controls block (`options-ui-§15`, which is where the 65th `macroBar.`-prefixed path, `macroBar.locked`, is counted), 7 on the Macros page and 1 on the Stat Priority page. Most are scalars. Nine whole-value rows of type `order` or `map`, plus one bool, `mouseover`, are described below. `settings/Panel.lua` itself declares none: a row is either written out in a page file or emitted by a LibKa0s composer and spliced in by `Helpers.RegisterRows`, which is also why the count is no longer greppable and is read off `#KCM.Settings.Schema`. Each row is `{ path = …, type = …, … }`, and one row is simultaneously three things: the widget on its settings page (its `group` is also the tab it lands on, so the array's order is the strip's order), the `/cm list|get|set|reset <path>` CLI entry (`settings/Slash.lua:529` hands the whole array to LibKa0s-Slash-1.0 as `allRows`), and the validator applied on write by the `Resolve` → `SetAndRefresh` seam.

```lua
#KCM.Settings.Schema
```

reports **79 rows**: 64 `macroBar.*` rows in `settings/MacroBar.lua`, the 7 composed Master controls rows in `settings/General.lua`, 7 generated by `settings/Category.lua` and 1 in `settings/StatPriority.lua`. It is read off the live array rather than grepped, because a composed block declares its rows from one call and `grep -c '^\s*path\s*='` now under-counts by every row a composer emits.

Two things are deliberately *not* schema rows. `KCM.State.debug` — the session LOGGING flag — is never persisted, so it has no path to declare; the Master controls tab's `Debug console` row is a different thing, the console WINDOW's visibility, and it declares the session path `state.debugConsole` that `settings/Panel.lua`'s `SESSION_PATHS` resolves. The per-category item lists are a collection no row shape describes: they are the structural registry (below), which is also why `/cm resetall` stays host-owned rather than adopting the library's `Sl:CliResetAll` (closed issue [LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)). The per-spec stat priorities used to be the same kind of exception, and `architecture-§5` treats them differently. They are a preference, and a preference with no row is a missing row. Since 2026-09-12 they are one whole-value row, `statPriority` (below).

### Structural registry: the per-category item lists

This addon holds **one** structural registry (`architecture-§5`). The player adds and removes its members at runtime, `dbDefaults` ships it empty (`defaults/Profile.lua:67-82`), and no schema row names a member.

The sets pass all three of the rule's tests, and "id sets" is one of the rule's own examples. The v2.43.0 changelog entry in `STANDARDS.md` agrees. It lists ConsumableMaster among the seven addons that hold a registry, with `Selector` as the writer and a migration runner that has no step touching these sets. It also named this addon as one of the two that v2.43.0 did not make compliant, because three resets cleared the buckets themselves. Since 2026-09-12 those resets go through `Selector` ([#34](https://github.com/tusharsaxena/ConsumableMaster/issues/34)). The registry is compliant and needs no register row.

- **Storage keys.** `profile.categories[catKey].added` and `.blocked` (sets of opaque ids), plus their order bookkeeping `.pins` (`{ itemID, position }`). These sit on the bucket itself for a single category, and under `profile.categories[catKey].bySpec[specKey]` for the four spec-aware ones (`STAT_FOOD`, `CMBT_POT`, `FLASK`, `WPN_ENCH`). `.discovered` (`[id] = unixTimestamp`) is in the same bucket. It is membership the addon adds from the bag scan, not membership the player chooses, and only the two `Selector` functions named below write it.
- **Writer.** `modules/Selector.lua`: `AddItem` (`:481`), `Block` (`:503`), and `MoveTo` / `MoveUp` / `MoveDown` over `moveBy` (`:692`) for membership and pins; the two registry reset verbs `ResetBucket` (`:538`, one category, or one spec's bucket) and `ResetAllBuckets` (`:564`, every bucket, spec buckets included), which clear `added` / `blocked` / `pins` and keep `.discovered`; plus `MarkDiscovered` (`:584`) and `SweepStaleDiscovered` (`:669`) for `.discovered`. The Macros pages (`settings/Category.lua`), the `/cm priority` verbs (`core/SlashCommands.lua`) and **Reset all priorities** (`settings/General.lua`) call these. `GetBucket` (`:69`) lazily creates an empty spec bucket on first read; that is a traversal accessor, not a writer.
- **Load pass.** `KCM.Database.RunMigrations` (`core/Database.lua:162`), called from `KCM:OnInitialize` (`core/ConsumableMaster.lua:41`) and from the three AceDB profile callbacks that `KCM.RegisterProfileCallbacks` installs (`core/ConsumableMaster.lua:455-514`). It has no `categories` step today: AceDB's merge of `dbDefaults` is what seeds the empty buckets.

**Selector is the only runtime writer.** `architecture-§5` makes a registry reset a writer operation, and all three reset doors call the writer: `/cm priority <cat> reset` calls `Selector.ResetBucket` (`core/SlashCommands.lua:436-437`), the Macros page's per-category reset popup calls it for the viewed spec (`settings/Category.lua:288-289`), and **Reset all priorities** calls `Selector.ResetAllBuckets` (`settings/General.lua:134-135`). Until 2026-09-12 each of the three cleared the buckets itself, which spread registry writes across three runtime modules. anti-patterns #78 names that as a code finding. It was tracked in [#34](https://github.com/tusharsaxena/ConsumableMaster/issues/34) and is closed. `tests/test_selector.lua` now fails if any file other than `modules/Selector.lua` assigns a bucket's `added`, `blocked` or `pins`. Reset all priorities also clears `statPriority`. That write is a setting, not registry membership, and it goes through the schema helper like the other `statPriority` writers (below).

### Whole-value rows: stat priority, the composite sections, the slot order and visibility

None of these is a registry, because the player never adds or removes a member. Each is a preference or a list over a fixed set of shipped keys, so `architecture-§5` wants each one as a row. Since 2026-09-12 each is one ([#35](https://github.com/tusharsaxena/ConsumableMaster/issues/35)). A writer builds the whole value and hands it to `KCM.Schema:Set`, or to `KCM.Schema:SetMany` for a batch. The helper validates it, normalizes it, stores it and logs it at one path.

- `statPriority` (type `map`, declared in `settings/StatPriority.lua`): every spec's override in one map keyed by spec. Its normalizer keeps a `<classID>_<specID>` key, a real primary and the secondaries deduplicated, which is exactly what `SpecHelper.GetStatPriority` reads. The writers are `/cm stat primary|secondary|reset`, the Stat Priority page's list, dropdown and Defaults, and Reset all priorities. Each builds the map with `SpecHelper.WithStatPriority`. `/cm get|list|reset` reach the row. `/cm set` refuses it and names `/cm stat`.
- `categories.<KEY>.enabled` (type `map`, a flag map over the composite's own sub-categories) and `.orderInCombat` / `.orderOutOfCombat` (type `order`, over each section's shipped members), for each composite. `settings/Category.lua` generates them from `KCM.Categories.LIST`. The writers are `/cm aio toggle|up|down|reset` and the composite tab's Enabled checkbox, drag and reset popup. The drag goes through `Selector.MoveCompositeRef`, which splices a copy with the pure `Selector.SpliceOrder` and writes it through the helper.
- `macroBar.order` (type `order`) and `macroBar.shown` (type `map`, a flag map), the Macro Bar page's Buttons tab. The writers are a drag on the bar (`MacroBar.SwapSlots`), the Buttons tab's draggable list (a drag there splices the shown group and writes the order; a tick writes the shown map and then the order, as one batch; both refused in combat, `settings/MacroBar.lua`), Reset slot order and the page's Defaults. `MacroBarModel.Order()` repairs a stored order on read and writes nothing.
- `categories.BATTLE_REZ.mouseover` (type `bool`), generated for every `targeted` category. The writer is the tab's Cast on mouseover checkbox.

An `order` validator drops unknown and repeated members and appends any missing ones. A flag map drops keys outside its member set and refuses a value that is not a real boolean. Both store a fresh table every time, so neither a caller's table nor a row's `default` (which is the `dbDefaults` table itself) ever lands in the profile. `/cm set` takes an order as comma-separated keys (the keys named lead, and every other key keeps its current stored order behind them) and a flag map as `KEY=on|off` pairs merged over the stored map, so a key the pairs do not name keeps its flag (`settings/Slash.lua`). `tests/test_schema.lua` fails if a runtime file writes one of these fields around the helper.

### Other state written outside the helper

Three pieces of persistent state are written outside the helper, and none of them is a setting. No control sets any of them and no row addresses any of their fields. Since v2.44.0, `architecture-§5` calls such state **named non-setting state**. It needs no row and no register row once this section names its storage key, its one owner module and every function that writes it, with the act that reaches each. The load pass (`KCM.Database.RunMigrations`) is not listed, because the rule lets it seed and backfill such state. Neither is the global reset's `db:ResetProfile()`, which replaces the whole store (`options-ui-§12`).

- **The macro fingerprint cache.** Storage key: `profile.macroState[macroName]` = `{ lastItemID, lastBody, lastIcon, lastCat }`, the fingerprint of the last edit `MacroManager` made to each macro, which its "unchanged" early-out compares against. It is learned data: every entry records an edit the addon made, and the player authors none of them. **Owner:** `MacroManager` (`modules/MacroManager.lua`). **Writers:**
  - `commitMacro` (`:451`) stores a macro's fingerprint (`:486`) after a successful `EditMacro`. It is the one write seam behind `SetMacro`, `SetWeaponEnchantMacro` and `SetCompositeMacro`. A pipeline recompute reaches it, and so does `FlushPending` when the combat queue drains on `PLAYER_REGEN_ENABLED`. Its `macroState = macroState or {}` (`:465`) only creates the empty table on first use, which the rule does not count as a writer.
  - `InvalidateState` (`:644`, write at `:651`) clears the whole cache so the next pass rewrites every macro. It is a forced rebuild, one of the owner's own operations. Three acts reach it: `/cm rewritemacros` (`settings/Slash.lua:210`), the General page's **Force rewrite macros** button (`doForceRewriteMacros`, `settings/General.lua:87`), and a profile switch or copy, through the profile handler (`KCM.RegisterProfileCallbacks`, `core/ConsumableMaster.lua:455`). The incoming profile's fingerprints describe bodies the account's macros may no longer hold, so the handler clears them before its resync ([profiles.md](./profiles.md#why-the-fingerprints-are-forgotten)).

  Nothing else writes the cache; `core/MacroDisplay.lua` only reads it. The global reset empties it with the rest of the profile, and the resync that follows re-issues every macro and rebuilds it. The combat queue `pendingUpdates` lives only in memory, so it is out of scope. `tests/test_macromanager.lua` fails if any file but `modules/MacroManager.lua` writes `macroState`. This was the open remainder of [#35](https://github.com/tusharsaxena/ConsumableMaster/issues/35) once that issue's settings became rows. Since 2026-09-12 it is named here.
- **The macro bar's position.** Storage key: `profile.macroBar.point` / `.relPoint` / `.x` / `.y`, the bar's anchor against `UIParent`. It is geometry only a drag determines. **Owner:** `MacroBar` (`modules/MacroBar.lua`). **Writers:**
  - `savePosition` (`:101`, write at `:107`) reads the anchor back off the frame when a drag stops, on the bar itself (`OnDragStop`, `:143-146`) or on its drag handle, which since LibKa0s v1.48.0 hands the same function to the widget as its `onDragStop` (`:191`).
  - `MB.ResetPosition` (`:534`, write at `:538`) puts back the shipped default from `KCM.dbDefaults`. Three acts reach it: the General page's **Reset position** button (`onResetPosition`, `settings/General.lua:236`), `/cm bar reset` (`core/SlashCommands.lua:882`) and the Macro Bar page's **Defaults** (`doResetPage`, `settings/MacroBar.lua:638`).

  Nothing else writes these fields. No control chooses a position: a drag captures what is on screen and a reset puts back the default, and neither chooses a value. `/cm set` cannot reach them because they have no row. Until 2026-09-12 the page's Defaults also wrote them as part of its whole-table write over `macroBar` ([#36](https://github.com/tusharsaxena/ConsumableMaster/issues/36)). Now it routes the position through `ResetPosition` and writes no geometry itself. `tests/test_macrobar.lua` fails if any file but `modules/MacroBar.lua` writes these fields, or replaces the whole `macroBar` table outside the load pass. Named here for [#37](https://github.com/tusharsaxena/ConsumableMaster/issues/37).
- **The perf capture ring.** Storage key: the `ConsumableMasterPerfDB` SavedVariable (`schema`, `runs`), a global of its own declared beside `ConsumableMasterDB` (`ConsumableMaster.toc:11`) and kept out of AceDB, so a profile copy, reset or switch never touches it. It is recorded data written by a vendored library: the addon hands LibKa0s-Perf the variable's name and never writes it. **Owner:** `core/PerfSetup.lua`, which passes `sv = "ConsumableMasterPerfDB"` to `lib:New`. **Writer:** the library's `P.Save` (`libs/LibKa0s/Perf.lua`), reached when the player ends a run with `/cm perf finish`. It appends the run's record, trims the ring to its maximum length, and discards a ring stored under an older schema.

  Nothing in the addon writes the ring, and `/cm set` cannot reach it. Named here in the 2026-09-12 v2.44.0 sweep.

The Macro Bar page's **Defaults** button (`doResetPage`, `settings/MacroBar.lua`) writes every row on that page back to its default through `Helpers.SetManyAndRefresh`, the helper's batch form (`settings/Panel.lua`, published as `KCM.Schema:SetMany`). Each row is validated and written through `Helpers.Set`. The batch passes `opts.bulk`, so the whole reset logs one `[Set] reset Macro Bar page: N rows` line and no row logs its own (`debug-logging-§10`). N is the rows whose value actually changed, so a page already at its defaults logs `0 rows`. The whole batch then re-applies the bar once and rebuilds the page once. `macroBar.locked` is the General page's row, so the button leaves it standing. Until 2026-09-12 the button replaced the whole `macroBar` table instead, which broke the schema-row MUST. That was [#36](https://github.com/tusharsaxena/ConsumableMaster/issues/36).

## Message Bus

Cross-module control flow that crosses feature boundaries travels over the closed bus (`core/Bus.lua`), never by reaching into another module's tables. Pure-function queries (MacroManager asking Selector/Ranker/Classifier for data) stay direct synchronous calls — they are data reads, not control flow.

`KCM.bus` is an AceEvent-embed. **Every receiver owns its own target** via `KCM.NewBusTarget()`; two subscriptions never share one table. `KCM.MSG` names each message:

| `KCM.MSG.*` | Wire name | Direction | Purpose |
|-------------|-----------|-----------|---------|
| `RECOMPUTE` | `Ka0s_ConsumableMaster_Recompute` | event / UI layer → pipeline | Request a pick recompute. The pipeline owns the **only** subscription (registered at load in `Bus.lua`) and forwards to `Pipeline.RequestRecompute`, which coalesces to one pass per frame. Carries an optional `reason` string. |
| `PANEL_REFRESH` | `Ka0s_ConsumableMaster_PanelRefresh` | pipeline → options panel | The pipeline finished a pass; any open settings page does a debounced rebuild against the new picks. Receiver: `settings/OptionsShim.lua`. |
| `SPEC_CHANGED` | `Ka0s_ConsumableMaster_SpecChanged` | spec change → options panel | Active spec changed; the Stat Priority page retracks to the new spec when auto-tracking. Receiver: `settings/OptionsShim.lua`. |
| `MACROBAR_REFRESH` | `Ka0s_ConsumableMaster_MacroBarRefresh` | pipeline → macro bar | The pipeline finished a pass; the optional macro bar repaints slot icons + counts. Undebounced (unlike `PANEL_REFRESH`) because a live on-screen bar should track the macro it just rewrote. |
| `PROFILE_CHANGED` | `Ka0s_ConsumableMaster_ProfileChanged` | profile handler → macro bar, options panel, Profiles page | AceDB switched, copied or reset the profile. Sender: the one reaction `KCM.RegisterProfileCallbacks` installs, after its resync. Payload: `reason` (`profile_changed` / `profile_copied` / `profile_reset`). Consumers: `modules/MacroBar.lua` runs `MacroBar.Update()`, the whole re-apply a repaint does not do; `settings/OptionsShim.lua` runs an immediate `KCM.Options.Refresh()`; `settings/Profiles.lua` redraws its AceConfigDialog tree. Each on its own target. [profiles.md](./profiles.md) |

## Slash Commands

`/cm` and `/consumablemaster` both reach one dispatcher: the LibKa0s-Slash-1.0 instance built in `settings/Slash.lua`. Its input is the `COMMANDS` table at `settings/Slash.lua:143-268`, published as `KCM.COMMANDS` at `:354` so there is one source of truth for the verb set (`slash-commands-§4`). Nothing in the addon reads that table directly — the About page renders its rows through `KCM.SlashCommands.GetLandingRows()` (`settings/Slash.lua:629-632`), which delegates to the library instance built from the same table — so `KCM.COMMANDS` is the identity handle the harness asserts against.

Twenty-one verbs are declared, in this order: `help`, `config`, `version`, `enable`, `disable`, `perf`, `debug`, `resync`, `rewritemacros`, `reset`, `resetall`, `list`, `get`, `set`, `bar`, `lock`, `unlock`, `priority`, `stat`, `aio`, `dump`. Four of them carry a subcommand tree of their own. The verb *bodies* live in `core/SlashCommands.lua`, and the `/cm dump` targets in `core/SlashDump.lua`; `settings/Slash.lua` holds only the table and the dispatcher wiring. The user-facing description of each verb is the help index `/cm help` prints, built from that same table. A bare `/cm` runs `config` instead and opens the settings panel on its About landing page (`slash-commands-§4`, LibKa0s-Slash-1.0 minor 11); the README deliberately no longer restates it (`documentation-§1` item 7).

**The slash surface is UNCHANGED while the addon is disabled** (`slash-commands-§2`, `§7`). Every reserved verb answers — `help`, `config`, `version`, `enable`, `disable`, `debug`, `perf`, `get`, `set`, `list`, `reset`, `resetall` — and the bare `/cm` opens the settings panel, because the dispatcher and the settings registration are **setup, not features**. **Eight of the twenty-one refuse**: `resync`, `rewritemacros`, `bar`, `lock`, `unlock`, `priority`, `stat` and `aio` answer on one tagged line naming `/cm enable` and do nothing else, which is `§2`'s SHOULD and the only refusal in the disabled state. The gate is the dispatcher library's (`LibKa0s-Slash-1.0` minor 13); the host's half is three descriptor fields — `isEnabled`, `brandName` and `liveVerbs`, the last of which **widens** the library's twelve by this addon's read-only `dump` and must never narrow them. The reasoning, the `dump` judgment call and what the degraded arm does are in [slash-dispatch.md](./slash-dispatch.md); the stand-down itself is [below](#the-disabled-state-is-total).

The verb table, the five sub-command tables and their three handler arities, the case-preserving parse, the overridden usage strings and the degraded arm are in [slash-dispatch.md](./slash-dispatch.md).

## Event Subscriptions

Every client event this addon listens to is registered in one place — `KCM:OnEnable` in `core/ConsumableMaster.lua` — through AceEvent. No module body subscribes on its own, so the whole surface is readable at a glance. That single list is also what the stand-down tears down and what the stand-up rebuilds: `standDown` drops the lot with `KCM:UnregisterAllEvents()` and `standUp` **calls** `OnEnable` rather than copying its list, so the two can never name different sets ([the disabled state](#the-disabled-state-is-total)). `OnEnable` itself refuses to run while a hold is taken, so a player who logs in with the addon off registers nothing at all.

| Event | Handler | Purpose |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `OnPlayerEnteringWorld` (`:582`) | Login and `/reload`: auto-discovery, then the discovered-set sweep, then the first recompute, then `MacroBar.Update()` — in that order, because each step feeds the next |
| `BAG_UPDATE_DELAYED` | `OnBagUpdateDelayed` (`:608`) | Bag contents moved; re-run discovery and request a coalesced recompute |
| `PLAYER_SPECIALIZATION_CHANGED` | `OnSpecChanged` (`:613`) | Recompute the spec-aware picks and publish `SPEC_CHANGED` for the Stat Priority page |
| `PLAYER_REGEN_ENABLED` | `OnRegenEnabled` (`:623`) | Combat ended: flush MacroManager's pending macro writes and the macro bar's deferred build / relayout / restyle, then replay a settings-category registration that `settings/Panel.lua` refused under lockdown |
| `GET_ITEM_INFO_RECEIVED` | `OnItemInfoReceived` (`:659`) | Item metadata arrived: invalidate that item's cache entry, then a full recompute only if it is a bag item — everything else takes the debounced `PANEL_REFRESH` path instead |
| `LEARNED_SPELL_IN_SKILL_LINE` | `OnLearnedSpell` (`:680`) | A spell-backed candidate became known after the spell book hydrated; recompute |
| `PLAYER_EQUIPMENT_CHANGED` | `OnEquipmentChanged` (`:688`) | Recompute on main-hand (16) / off-hand (17) swaps only — the per-hand `WPN_ENCH` pick; every other slot is a no-op |
| `SPELL_UPDATE_COOLDOWN` | `OnCooldownUpdate` (`:602`) | Repaint macro-bar and flyout cooldown swipes. Bar-only, with an early-out when the bar is disabled |
| `BAG_UPDATE_COOLDOWN` | `OnCooldownUpdate` (`:602`) | The same repaint, from the item-cooldown side |

Internal control flow that crosses a feature boundary does **not** ride a client event — it rides the closed bus above.

## The disabled state is total

**Disabled means the addon is not running** (`slash-commands-§7`). Not hidden, not quiet, not skipping a repaint — not running. A player who unticks *Enable Consumable Master* has asked for the same outcome they would get by unticking the addon in Blizzard's own AddOns list, minus the `/reload`.

**What it used to be, because the shape is worth naming.** Through 1.6.2 `db.profile.enabled` had exactly **one** consumer in the whole addon: `macrosEnabled()` in `core/ConsumableMaster.lua`, read once per recompute to skip the macro write pass. No bus message, no module teardown, no visibility publish. Nine game events stayed registered, four bus subscriptions stayed live, the macro bar stayed on screen with its fade tick running, and `/cm disable` did not take the bar down at all. That is a **draw gate**, and it is anti-pattern #85: the addon had not stopped watching, it had stopped reacting, and it went on paying the dispatch on every `BAG_UPDATE_COOLDOWN` in a fight.

**One latch, two named holds.** `core/LifecycleSetup.lua` builds the addon's single `LibKa0s-Lifecycle-1.0` instance, second in the TOC so `core/PerfSetup.lua` can take it as `descriptor.lifecycle`. The holds are `disabled`, taken from the stored `enabled` path, and `perf`, taken by the capture harness for Experiment B. The addon is **stood down whenever at least one hold is taken and stood up only when the last one is released** — there is no `StandUp()` to call, and releasing one hold cannot resurrect an addon the other still holds down. That is the case a boolean could not represent: a player can disable the addon *during* a suspended arm, and a `resume` that stood it up would bring it back to life under them.

**It is NOT a second teardown path.** `suspend` / `resume` used to live in `core/PerfSetup.lua` and are `standDown` / `standUp` now, in one place, reached by both arms. Two mechanisms that both mean "be inert" diverge on the first module added after the second was written.

| On the way DOWN | Where |
|---|---|
| Every message registration the addon owns, actually unregistered | `KCM.Bus.StandDown()` — each receiver hands `KCM.NewBusTarget` a **subscribe function** so the registrations can be dropped and replayed (`core/Bus.lua`) |
| Every client event, actually unregistered | `KCM:UnregisterAllEvents()` — `KCM:OnEnable`'s list is **called**, never copied |
| The coalescing recompute, disarmed | `KCM._recomputePending = false`; `C_Timer.After` hands back no handle, and a one-shot that fires at the end of this frame and finds nothing pending is not a survivor |
| The bar hidden **at the source**, its fade `OnUpdate` cleared and its secure visibility driver unregistered | `MacroBarModel.IsEnabled()` answers false while the latch is down, so `MB.Update` takes its own disable path. Hiding imperatively would last until the next combat transition or settings change re-showed it |
| Secure work held pending in combat | `standDown` re-registers **`PLAYER_REGEN_ENABLED`** — the one registration a disabled addon keeps — and `KCM:OnRegenEnabled` finishes the bar and drops it the moment it fires |

| What SURVIVES, because it is SETUP | |
|---|---|
| The chat command, the dispatcher and `KCM.COMMANDS` | Without them `/cm enable` does not exist and the switch only goes one way |
| The settings-category registration and the panel body | The *Enable Consumable Master* checkbox is live there in either state |
| The AceDB handle, the single write seam, and the `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callbacks | A profile switch can flip `enabled` with no verb and no checkbox touched, so the addon **re-evaluates** the latch in its one profile reaction before anything else in that handler runs |
| The launcher's registration | The button stays on the minimap; `minimap.hide` is a display preference and says nothing about whether the addon is running |

**Standing up rebuilds from current state**, never from a snapshot taken on the way down: the whole schema CLI answers while disabled, so a setting really can change in between.

**The launcher's click** follows `launcher-§2`: this addon is on **rung (b)** — its left click drives the macro bar's lock, which is its preview switch — so while disabled the left click prints the one refusal line, writes no SavedVariables and does nothing else, while the right click opens the settings panel unchanged, in either state.

`tests/test_disabled.lua` is the conformance suite `§7` requires. It asserts on the **registration set** through the kit's recording mock, never on a handler's return value — a suite that asserts "the handler returned early" certifies the draw gate it exists to catch.

## Taint Notes

The addon's protected surface is small and deliberately fenced.

- **`modules/MacroManager.lua` is the only caller of the protected macro writers.** `CreateMacro` (`:348`) and `EditMacro` (`:359`) appear nowhere else in the tree, and `DeleteMacro` is never called at all. Every engine module the pipeline calls — Selector, Ranker, Classifier, BagScanner, TooltipCache, SpecHelper — is pure, so a recompute can run mid-combat without touching a protected API.
- **The macro bar owns the only protected frames.** Slots and flyout entries are secure buttons: creating, anchoring, showing or hiding them is combat-forbidden. Everything funnels through `MacroBar.Update()`, which defers to `PLAYER_REGEN_ENABLED`. Combat-conditional visibility goes to `RegisterStateDriver`, flyout hover to `_onenter` / `_onleave` snippets, and combat state reaches those snippets via `RegisterAttributeDriver` — the decisions happen inside the secure environment rather than in tainted Lua. A slot's `macro` attribute is stamped once at creation and never rewritten.
- **Restricted (secret) values are tested before they are touched.** Midnight wraps combat-restricted data — cooldown start/duration among it — in opaque values that raise on comparison or arithmetic. Any gate over client data asks `KCM.Compat.IsSecret` first, and `core/MacroDisplay.lua` hands the opaque `C_DurationUtil` object straight back to the client rather than unpacking it ([midnight-quirks.md](./midnight-quirks.md#secret-values)).
- **Options registration is deferred in combat; opening is refused outright.** `Settings.RegisterAddOnCategory` is protected, and registering under lockdown taints the Settings window for the rest of the session — so `settings/Panel.lua:1267-1269` parks the bootstrap behind `KCM.Settings.registerPending` and the addon's existing `PLAYER_REGEN_ENABLED` handler replays it, rather than a second event registration of the panel's own. Nothing is lost by waiting, because the panel cannot be opened mid-fight anyway: the *open* path — `settings/OptionsShim.lua:217-220` — turns a mid-fight `/cm config` into a chat notice instead of a silent failure. That is `sayCombatOpenBlocked`'s **only** caller; the wording stays in `settings/Panel.lua` and is published on `KCM.Settings` for the shim, which is why it is published rather than copied. The panel's Defaults action (`settings/Panel.lua:547-550`) refuses separately and in its own words, because it is declining a reset rather than an open.

## Invariants worth not breaking

- **`MacroManager` is the only caller of `CreateMacro` / `EditMacro`.** Selector, Ranker, Classifier, BagScanner, TooltipCache, SpecHelper must all stay pure (no protected APIs) so the pipeline can run in combat without taint.
- **Macros are always identified by name**, never by slot index. `perCharacter=false` puts them in the account-wide pool. The addon never calls `DeleteMacro` on a `KCM_*` macro.
- **Seed lists are data, not code.** Updating a `defaults/Defaults_*.lua` is a zero-migration upgrade — `added`/`discovered`/`blocked` live in SavedVariables and union with the seed at runtime.
- **English-only — tracked deviation** (localization-§4 / anti-pattern #37; see [scope.md](./scope.md)). Classification keys on the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`), so category and weapon-affinity detection work on every client. The remaining English dependency is TooltipCache's tooltip-TEXT parsing (heal/mana/stat magnitudes, the `Augment Rune` marker, weapon-application effect). `locales/enUS.lua` is a shell, not localization plumbing; full tooltip localization is a planned future release.
- **Private-namespace publishing pattern:** every file does `local addonName, NS = ...; local KCM = NS; KCM.Foo = KCM.Foo or {}; local F = KCM.Foo`. The `or {}` is load-bearing — another file may have reached `KCM.Foo` first, and overwriting it drops whatever it published. Never let the local shadow the namespace (`local KCM = {}` breaks everything downstream). Public API goes on `F`; helpers stay `local` to the file.
- **Blizzard API churn goes through `core/Compat.lua`.** `KCM.Compat` wraps the spec + spell APIs Blizzard keeps renaming (`GetSpecialization*`, `GetSpecializationInfoForClassID`, spell-name lookup) and the client's `issecretvalue` (`Compat.IsSecret`). Four of those six are `LibKa0s-Compat-1.0`'s members bound onto the table; the seam is still the only thing callers name. SpecHelper, SlashCommands, MacroManager, MacroDisplay and the settings pages call through `Compat.*` and never the raw global, so a rename is one edit. Any gate over client data a combat restriction could turn secret must ask `IsSecret` *before* comparing ([midnight-quirks.md](./midnight-quirks.md#secret-values)).
- **Reset is centralized, and it is a PROFILE reset plus a session sweep.** `KCM.ResetAllToDefaults(reason)` (`core/ConsumableMaster.lua`) restores every `sessionOnly` schema row to its default and then runs one `db:ResetProfile()` — the same act as AceDBOptions' Reset Profile (`options-ui-§12`), with the row sweep `§12` also makes a MUST because a profile reset by construction cannot reach a row whose storage is its own `set()` (`state.debugConsole`, `settings/Panel.lua`'s `SESSION_PATHS`). It is the only PROFILE reset path; the General page's **Reset all settings** button (the Master controls tab's closing pair, `options-ui-§15`) and `/cm resetall`'s StaticPopup both delegate to it, behind the collection's one confirmation wording. Don't add a third. **Reset all priorities**, on the General page's **Maintenance** tab beside Master controls, is a different and narrower act — every category's added/blocked/pinned items and every spec's stat-priority override, and nothing else — behind its own confirmation (`KCM.ResetAllPriorities`, `settings/General.lua`); the button used to carry that name and run the profile reset. The resync (`afterReset`: invalidate → discover → recompute) is **not** called from there: `OnProfileReset` reaches it through the profile callbacks `KCM.RegisterProfileCallbacks` installs, so it runs on exactly one path — the one a profile *switch* takes too. The same handler logs the act, once: `[Set] reset profile '<name>' to defaults` (and `[Set] copied profile 'A' → 'B'` for a copy; a switch rewrites no rows and logs `[Profile] switched to '<name>'` instead of a `[Set]` line). On a switch or copy it also forgets the macro fingerprints before the resync, and on all three it ends by publishing `PROFILE_CHANGED`, off which the macro bar re-applies itself whole and every open settings page rebuilds ([profiles.md](./profiles.md)). `ResetAllToDefaults` runs both halves inside `Helpers.MuteSetLog`, so the session sweep's write logs no row and the whole reset is one line (`debug-logging-§10`). The handler also silences any `Helpers.Bulk` bracket open around it (`Helpers.SilenceOpenBulk`), so a reset or copy run inside one is still that one line. The line carries no row count: N means the rows the reset actually changed, which needs their values from before it, and AceDB has already replaced the profile when `OnProfileReset` fires; AceDBOptions' Reset Profile button gives no earlier hook. The hand-written `restoreProfileDefaults`, which named `categories`, `statPriority` and `enabled` and nothing else, is gone with it: a list of profile keys is the shape that quietly stops being true. `/cm reset path` is unrelated — the library's one-row schema reset ([LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)), which never touches `categories` or `statPriority` ([schema.md](./schema.md)).
- **All addon chat carries the cyan `[CM]` prefix, and no layer calls `print` directly.** `KCM.PREFIX` (`core/Constants.lua`) is the single source of truth; one-shot chat routes through the secret-safe `KCM.Say(fmt, ...)` seam and gated verbose output through `KCM.Debug(tag, fmt, ...)`. The sole sanctioned raw `print` is the one embedded in generated macro-body `/run print(...)` strings ([scope.md](./scope.md)).
- **Recompute is coalesced.** Callers fire `KCM.MSG.RECOMPUTE` on the bus (or call `Pipeline.RequestRecompute`), never `Pipeline.Recompute` directly — except the rare direct paths (the profile-callback resync, `/cm resync`, `/cm rewritemacros`) where the write should land this tick.
- **Priority-list IDs are opaque numbers with sign semantics.** Positive = itemID, negative = `KCM.ID.AsSpell(spellID)`. Only `MacroManager`, `Ranker.Score`'s spell shortcut, and the UI fork on the sign; every other layer treats them as plain table keys.
- **Score cache lives for one Recompute pass and no longer.** `scoreCache` is created fresh in `Pipeline.Recompute` and threaded through `PickBestForCategory` → `SortCandidates`. Tooltip / bag / spec state can shift between events — never cache across passes. Non-pipeline callers (Options panel, `/cm dump pick`) pass `nil`.
- **Composite categories never own item buckets.** No `added`/`blocked`/`pins`/`discovered` — composites compose picks from their referenced single categories at recompute time. Sub-categories are locked to their `inCombat` / `outOfCombat` section.
- **Per-hand categories resolve twice from one bucket.** `perHand = true` (today only `WPN_ENCH`) keeps the ordinary spec-aware `bySpec` bucket — there is no per-slot persisted state. The pipeline calls `Selector.PickBestForSlot(catKey, 16, …)` and `(…, 17, …)` against that one list, each filtered to entries whose `tt.weaponAffinity` matches `WeaponSlots.SlotAffinity(slot)` — where a slot answering `"other"` (a weapon that takes no stone) matches `"any"` oils and nothing else. A hand with no weapon, or with nothing matching, is dropped from the macro body rather than falling back to the other hand's pick.
- **Action-bar icon sentinel.** Active body stores `DYNAMIC_ICON = 134400` (`?` fileID); empty body omits `#showtooltip` and stores `DEFAULT_ICON = 7704166` (cooking pot). Storing `DEFAULT_ICON` on an active body shows the cooking pot on the bar instead of the picked item's icon.
- **The macro bar owns the only protected frames, and never pokes them in combat.** Slots and flyout entries are secure buttons, so creating, anchoring, showing or hiding them is combat-forbidden. Everything funnels through `MacroBar.Update()`, which defers to `PLAYER_REGEN_ENABLED`; combat-conditional visibility goes to `RegisterStateDriver`, flyout hover to `_onenter`/`_onleave` snippets, and combat state reaches those snippets via `RegisterAttributeDriver` — all of it running in the secure environment instead. A slot's `macro` attribute is stamped once at creation and never rewritten. Every slot and flyout entry registers for `"AnyUp"` **and** sets `useOnKeyDown = false`; drop the attribute and the `ActionButtonUseKeyDown` cvar (on by default) makes Blizzard's handler wait for a press the button never receives, so clicks silently do nothing ([macro-bar.md](./macro-bar.md#buttons)).
- **Debug flag is session-only.** `KCM.State.debug` (`core/State.lua`) is never persisted — a session left with debug on doesn't leak into the next login.

## Timers

`C_Timer` is used directly rather than AceTimer, in three places: the pipeline's frame-coalescing (`RequestRecompute`), the options panel's refresh debounce (`O.RequestRefresh`), and the flyout's idle auto-close (`MacroBarFlyout`). This is a **deliberate, documented choice** (CM-09): the addon needs only fire-once short delays, `C_Timer` is a first-party API with no extra embed, and AceTimer is not otherwise required. The standard treats the timer choice as a SHOULD, so this justification satisfies it.

Note the flyout timer's limit: there is no timer inside the *secure* environment, so it cannot close a flyout mid-combat and deliberately stands down instead ([macro-bar.md](./macro-bar.md#closing)).

**On the way down** (`slash-commands-§7`): the coalescer is disarmed by clearing `KCM._recomputePending`, which is the only lever `C_Timer.After` leaves — it hands back no handle, and a one-shot that fires at the end of *this* frame and finds nothing pending is not a survivor. The bar's fade `OnUpdate` is **cleared** on the disable path rather than left armed to wake up and find a hidden bar, and the flyout's idle poll only exists while a flyout is open, which a hidden bar's cannot be. The panel refresh debounce is the settings layer's and belongs to what SURVIVES; nothing arms it while the addon is down, because every publisher of `PANEL_REFRESH` is a stood-down path.

## External dependencies

These are the addon's **runtime** libraries. The **contributor toolchain** — what you install to
build, test or release — is a separate list in [../DEPENDENCIES.md](../DEPENDENCIES.md).

All vendored under `libs/`:

- LibStub
- CallbackHandler-1.0
- AceAddon-3.0
- AceEvent-3.0
- AceDB-3.0
- AceDBOptions-3.0 (the Profiles page's options table, `settings/Profiles.lua`)
- AceConsole-3.0
- AceGUI-3.0
- AceConfig-3.0, with its Registry, Cmd and Dialog sub-libraries (AceConfigDialog draws the Profiles page and nothing else, `options-ui-§3`). Byte-identical to MultiMeters' and KickCD's copies: AceConfig-3.0 minor 3, AceConfigRegistry-3.0 minor 22, AceConfigCmd-3.0 minor 14, AceConfigDialog-3.0 minor 92, AceDBOptions-3.0 minor 15
- LibSharedMedia-3.0 (debug-console monospace font registration; also the media source behind the macro bar's border pickers)
- LibDataBroker-1.1 and LibDBIcon-1.0 (the launcher — the broker plugin and the minimap button, `launcher-§1`). LibDataBroker is listed **first** and that is load-bearing: LibDBIcon resolves it with a non-silent `LibStub` at file load and calls `error()` when it answers nil. `LibKa0s-Launcher-1.0` resolves both with `LibStub(..., true)` at Register time instead, so it degrades by name rather than raising — no LibDataBroker means no launcher at all, no LibDBIcon means the broker plugin without the button
- AceGUI-3.0-SharedMediaWidgets (the `LSM30_Border` preview dropdown used by those pickers; its misaligned preview tile is fixed up by `lib.__PatchLSM30Border()`, a `LibKa0s-Options-1.0` member called from `settings/OptionsSetup.lua`. That used to be `core/LSMPatch.lua` here and in four sibling addons — AceGUI's widget registry is process-global, so five private registrations in one client meant whichever addon loaded last owned every addon's Border dropdown)
- LibKa0s — the Ka0s-owned shared modules, vendored whole-folder from [github.com/tusharsaxena/LibKa0s](https://github.com/tusharsaxena/LibKa0s) and loaded through the library's own packaged XML. Eleven majors are adopted: `Core-1.0` (chat printer), `DebugLog-1.0` (debug console), `Slash-1.0` (dispatcher, help rows and schema CLI), `Options-1.0` + its `OptionsWidgets` / `OptionsScroll` attachments (panel shell, row widgets, canvas contract), `Perf-1.0` + `PerfPanel` (A/B capture), `Media-1.0` (the shipped icon catalog and font), `Env-1.0` (the TOC-manifest reader behind `KCM.Meta` / `KCM.Version`), `Item-1.0` (one primitive, `ItemIDFromLink`), `Widgets-1.0` (two surfaces: `ReorderList`, behind the priority rows' drag handle, and `DragHandle`, the macro bar's unlocked strip, adopted at v1.48.0), `Launcher-1.0` (the minimap button and the broker plugin as one object, adopted at v1.39.0) and `Lifecycle-1.0` (the one latch the disabled state and the perf harness's suspended arm are two named holds on, adopted at v1.41.0). `Pool` is vendored with the payload but not consumed. Never patched in place — a fix goes upstream, then re-vendors whole-folder ([testing.md](./testing.md)).

### LibKa0s adoption

Each major is adopted by the same shape: one host **setup file** resolves what only the addon can
know, builds ONE instance via `lib:New(descriptor)`, publishes the addon's existing **flat,
dot-callable** names as thin forwarders onto that instance, publishes the instance itself as
`.instance` for identity assertions, and carries a degradation stub for a missing library.

| Major | Host half | What the addon keeps |
|---|---|---|
| `Core-1.0` | `core/CoreSetup.lua` | `KCM.PREFIX` (read live via a prefix *function*, never captured), the `print` sink the harness listens on, and `KCM.SwatchColor` — the one wrapper over `lib.RGBA` + `lib.ResolveColor` that teaches the library this addon's positional `{ r, g, b, a }` shape and each surface's own four-channel fallback (`options-ui-§17`) |
| `DebugLog-1.0` | `core/DebugLogSetup.lua` | the shipped font, `KCM.State.debug` as the flag's single home, the `[Init]` content, the panel repaints |
| `Slash-1.0` | `settings/Slash.lua` | the `COMMANDS` table and the `STRINGS` overrides that keep this addon's shipped wording (both passed in, never owned). The verb bodies and their `*_COMMANDS` namespaces stay in `core/SlashCommands.lua`, the `/cm dump` targets in `core/SlashDump.lua`, and the `KCM_CONFIRM_RESET` popup with the verbs (CM-47). |
| `Options-1.0` | `settings/OptionsSetup.lua` (the seam) + `settings/Panel.lua` (the addon's half) | the schema itself, the `Resolve` → `SetAndRefresh` write seam and its two diversion tables — `SESSION_PATHS` (`state.debugConsole`, whose store is the console itself) and `GLOBAL_PATHS` (`global.minimap.hide`, stored but in `db.global`, and where the row's SHOWN ↔ LibDBIcon's HIDDEN inversion lives, `launcher-§3`), `Grid` / `Button` / `ButtonPair` / `Label`, `EnumValues` (`LSMValues` was host-owned beside it until `M4-C1`; it is the library's outright now), `RegisterRows` (which stamps `panel`, `section` and this addon's `onChange` onto a composed block), the page order (`KCM.Settings.order`, five pages, Profiles last) and the Macros strip's tab order (`KCM.Settings.macroOrder`, fifteen categories), the `KCM.Options` shim — `Register` here, and the run-time `Refresh` / `RequestRefresh` / `Open` plus the refresh debounce in `settings/OptionsShim.lua`, peeled off at the 1500-line cap — and the two reset vetoes `KCM.Settings.VetoedFromResetAll` — which the seam publishes and hands to the library as its descriptor's `skipRestoreAll` (`options-ui-§3`) — and `KCM.Settings.VetoedFromEveryReset`, the one-row carve-out `launcher-§3` requires: it reads a row's `neverReset` stamp, the global veto asks it first, and `settings/General.lua`'s page `Defaults` walk asks it too, so a player's minimap-button choice survives **both** resets. The tab strip (`options-ui-§13`), the page banner (`§14`), the row engine `RenderRows`, the id line `IdInput` behind a category tab's Add-by-ID (minor 16; this addon hands it a host kind whose `resolve` calls the library's `ResolveId` for names, the category's `Selector.BuildCandidateSet` IDs, plus the items in the bags under Type=Item, as `candidates` for those names and the as-you-type suggestions, and names its ids' library kind as `base` — `"item"` or `"spell"` per Type — so the rows wear the tier icon, quality color or subtext while this addon's resolver still decides what is added; it keeps its own rows) and the four **composers** — `MasterControls`, `ColorPair`, `BorderGroup`, `FontGroup` (`options-ui-§15`–`§17`) — are the library's, called by the page files |
| `Lifecycle-1.0` | `core/LifecycleSetup.lua` | what "inert" MEANS for this addon — the `standDown` / `standUp` pair — and nothing else. The library owns no frames, no events, no settings and no storage; what it knows is whether the hold set is empty. The two holds are `disabled` (from the stored `enabled` path) and `perf` (taken by `Perf-1.0` itself, never by the host). There is no `:StandUp()` member and its absence is the point |
| `Perf-1.0` | `core/PerfSetup.lua` | `/cm` as the taught command, `ConsumableMasterPerfDB` as the capture ring, and the three sinks. The `suspend`/`resume` pair it used to carry moved to `Lifecycle-1.0`'s latch at Perf minor 12, which requires `descriptor.lifecycle` — a second teardown path beside the disable arm is the anti-pattern, not an implementation detail |
| `Media-1.0` | `core/MediaSetup.lua` | this addon's folder name (a vendored library cannot work out which folder it was copied into) and the one `Media.RegisterLSM` call, made at file load. Publishes `KCM.Icon` / `KCM.MediaFont`; its TOC position is load-bearing, because `core/DebugLogSetup.lua` resolves the console font eagerly |
| `Env-1.0` | `core/EnvSetup.lua` | `addonName` again, and the degradation path — an install without LibKa0s repeats the two `C_AddOns` ladders this seam replaced. Publishes `KCM.Meta(field)` and `KCM.Version()` (`/cm version`, the About page's notes) |
| `Compat-1.0` | `core/Compat.lua` | the call surface `KCM.Compat.X`, which did not move: four members are the library's (`GetSpecialization`, `GetSpecializationInfo`, `GetSpellName`, `IsSecret`) and two stay host code because this addon is their only consumer in the collection (`GetNumSpecializationsForClassID`, `GetSpecializationInfoForClassID`). No instance: the major is stateless. With it absent each wired reader answers `nil` (the API document's *reader arm*) and `IsSecret` re-implements its one-rung body (the *guard arm*, a commented, deliberate duplication, `options-ui-§1`). Adopted at v1.55.0 |
| `Widgets-1.0` | none — `settings/Category.lua` and `settings/StatPriority.lua` each resolve the major at the call site | exactly one member, `ReorderList`, behind **three** lists: a single category's priority rows, each of a composite's two combat-state sections, and the Stat Priority page's secondary stats. There is no setup file and no instance: the widget is a plain constructor with no addon-wide state to teach it, so a page asks `LibStub` in silent mode on each render. With the major absent no handle and no row box are drawn and the lists lose their in-panel reordering entirely — `/cm priority <cat> up\|down` is what still moves a priority row. Each page cancels every controller it built at the TOP of its render, before the first widget exists (`options-ui-§18`); the Category seam holds a LIST because a composite page builds two |
| `Item-1.0` | `core/ItemSetup.lua` | exactly one of the major's four members, `ItemIDFromLink`, behind the Add-by-ID line's pasted-link path (`settings/CategoryAddByID.lua:157`). `QualityFromLink` / `QualityLabel` / `LoadItem` are pointedly not taken, and `core/TooltipCache.lua` stays this addon's own policy. The degradation stub is the same primitive in three lines, so a pasted link never works on one install and not another |
| `Launcher-1.0` | `core/LauncherSetup.lua` | the addon's FOLDER name (used for BOTH registrations — LibDBIcon keys the button's saved position by it), the 128 logo path built from that name, the broker **label** — `Ka0s Consumable Master`, the brand name in plain text, deliberately neither the TOC `## Title` (a Title may carry color escapes and one in the collection does) nor the folder name, and wired to neither (`launcher-§1`) — a THUNK answering `db.global.minimap` (never the table itself — a table captured at file load is one AceDB later replaces), `openSettings` → `KCM.Options.Open`, and the RUNG: `onClick` toggles the macro bar's lock through `KCM.MacroBar.SetLocked`, i.e. the same `KCM.Schema:Set("macroBar.locked", …)` seam the Master controls checkbox and `/cm bar lock` take. The library owns the click dispatch, so right-click → settings panel is satisfied on both surfaces by construction. No degradation stub — `core/PerfSetup.lua`'s convention: an absent major is an absent feature, and both callers (`KCM:OnInitialize`'s `Register`, the schema row's `set`) branch on nil |

Three rules here are load-bearing rather than stylistic:

1. **Never bind a printer or a prefix by value.** Every `lib:New` snapshots its descriptor once, so a
   captured `KCM.Say` freezes the load-time function object and every later swap — including the
   suite's — goes unseen. Pass a thunk.
2. **A degradation stub's OMISSIONS are its contract.** `core/DebugLogSetup.lua` publishes no
   `instance` precisely because that absence re-arms `core/Debug.lua`'s chat fallback — the emitter
   at `core/Debug.lua:39-40` probes `DL and DL.instance`, not any named method. It publishes no
   `AddLine` either, so a stub can never silently swallow `core/PerfSetup.lua`'s ungated perf log. `settings/Panel.lua` registers no Blizzard
   category at all, because one opening onto an empty canvas would leave the user unable to tell a
   broken install from a broken addon. `KCM.LIBKA0S_MISSING` (set in `core/CoreSetup.lua`) is the one
   shared cause clause; each seam appends only its own "so *what* is unavailable".
3. **Adoption is per-part, and declining is normal.** Where the library disagrees with the addon it is
   recorded as a `LIBKA0S-*` issue in this repo's GitHub issues rather than worked around
   or silently taken. The three long-running declines — the slash dispatcher ([LIBKA0S-01](https://github.com/tusharsaxena/ConsumableMaster/issues/20)), the options
   row makers ([LIBKA0S-04](https://github.com/tusharsaxena/ConsumableMaster/issues/22)) and the options page registry ([LIBKA0S-05](https://github.com/tusharsaxena/ConsumableMaster/issues/24)) — have all since been adopted,
   two of them only after the blockers were fixed upstream and re-vendored; what is still declined is
   `Sl:CliResetAll` ([LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)), because this addon's global reset also wipes `categories`,
   the item-list registry, which no row describes. Never patch the vendored copy: a fix belongs
   upstream, then re-vendored. `core/LSMPatch.lua` used to be cited here as the precedent for
   third-party fixups living in `core/` rather than in `libs/`; it was the wrong precedent and it is
   gone. A fixup that writes to a **process-global** registry — AceGUI's widget types — is a LibKa0s
   concern, because a per-addon copy of it is one registration per addon and only the last one
   counts. It is `lib.__PatchLSM30Border()` now. A fixup with no reach beyond this addon would still
   belong in `core/`.

The libraries are listed directly in `ConsumableMaster.toc` under `# Libraries` (LibStub first, then CallbackHandler, LibSharedMedia, the Ace3 sub-libraries in dependency order, the two broker libraries, and LibKa0s last) — no `embeds.xml` wrapper (per the standard, toc-file-§4). The TOC's `## Interface:` line is `120100`.

## Load order

`ConsumableMaster.toc` is the source of truth. Order is dependency, not alphabetical:

1. `# Libraries` — LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, the Ace3 sub-libraries (AceAddon/AceEvent/AceDB/AceDBOptions/AceConsole/AceGUI/AceConfig), AceGUI-3.0-SharedMediaWidgets, LibDataBroker-1.1 then LibDBIcon-1.0 (that order is load-bearing — LibDBIcon `error()`s at load without LibDataBroker), then LibKa0s last, listed directly in the TOC. AceConfig sits **after** AceGUI, and that is load-bearing: AceConfigDialog resolves AceGUI with a non-silent `LibStub` at file load
2. `# Locales` — `locales/enUS.lua`
3. `# Core` — `Namespace.lua` (names `NS` and `KCM.VERSION`) → `PerfSetup.lua` (`performance-§1`: ahead of every file taking `local Perf = NS.Perf` as a load-time upvalue) → `MediaSetup.lua` (the `LibKa0s-Media-1.0` seam; **load-bearing position** — `DebugLogSetup.lua` resolves the console font eagerly at load, so the seam has to be published first) → `ConsumableMaster.lua` (AceAddon promotion + DB + pipeline) → `Bus.lua` → `Constants.lua` → `CoreSetup.lua` → `Compat.lua` → `EnvSetup.lua` (the `LibKa0s-Env-1.0` seam; position conventional — nothing resolves at load and both callers are in `settings/`) → `ItemSetup.lua` (the `LibKa0s-Item-1.0` seam; anywhere after the libs block and before `settings/Category.lua`, its only caller) → `LauncherSetup.lua` (the `LibKa0s-Launcher-1.0` seam; position conventional — it resolves the library at load and nothing else, and `Register()` runs from `KCM:OnInitialize` once AceDB has built `db.global.minimap`) → `State.lua` → `DebugLogSetup.lua` (`debug-logging-§1`: the console seam, after the printer and the flag, before every sink caller) → `Database.lua` → `Debug.lua` → `SpecHelper` → `TooltipCache` → `WeaponSlots` → `BagScanner` → `Classifier` → `MacroDisplay` → `MacroBarModel` → `MacroBarLayout` → `SlashDump` → `SlashCommands`
4. `# Defaults` — `Profile.lua` (`KCM.dbDefaults`), then `Categories.lua`, then `Defaults_*.lua`
5. `# Modules` — `Ranker` → `Selector` → `MacroManager` → the macro bar (`MacroBarFlyout` → `MacroBarButton` → `MacroBar`, in that order: the container builds slots that own flyouts) → AceGUI widgets (`KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`)
6. `# Settings` — `OptionsSetup.lua` (must come first — the `LibKa0s-Options-1.0` seam; creates `KCM.Settings.Helpers` and publishes `KCM.Settings.optionsUI`) → `Panel.lua` (the schema half, `RegisterTab`, the panel bootstrap and `KCM.Options.Register`) → `OptionsShim.lua` (the run-time `KCM.Options` surface: `Refresh` / `RequestRefresh` / `Open`, the refresh debounce and the bus receivers; after `Panel.lua`, whose `Helpers`, `optionsUI` and two notice functions it takes as file-scope locals) → `General.lua` → `MacroBar.lua` → `StatPriority.lua` → `Category.lua` → `CategoryAddByID.lua` (the Add-by-ID line; after Category.lua, whose `KCM.Settings.MacrosPage` helpers it takes as file-scope locals) → `Slash.lua` → `Profiles.lua` (last, as the Profiles page is last in the sidebar)

Event handlers and `Pipeline` functions are *defined* while `core/ConsumableMaster.lua` loads but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.

## Known Limitations

Things that are true today, understood, and not bugs. Each is either a ratified deviation with its own register row below, or a consequence of a client rule this addon cannot argue with.

- **English clients only, for tooltip magnitudes.** Category and weapon-affinity detection are locale-independent (numeric `classID` / `subClassID`), but `core/TooltipCache.lua` reads heal / mana / stat magnitudes, the `Augment Rune` marker and the weapon-application effect out of English tooltip text. Ratified below against `localization-§4`; reasoning in [scope.md](./scope.md).
- **A flyout cannot auto-close mid-combat.** The idle auto-close is a `C_Timer`, and there is no timer inside the secure environment, so a flyout opened as combat starts stays open until the hover state changes or combat ends. It deliberately stands down rather than attempting a hide the client would refuse ([macro-bar.md](./macro-bar.md#closing)).
- **Macro-bar changes made in combat land late.** Building, relayouting or restyling the bar anchors protected frames, so `MacroBar.Update()` defers the whole batch to `PLAYER_REGEN_ENABLED`. The same is true of macro writes, which queue in MacroManager and flush on regen.
- **A pick can be briefly wrong while item data hydrates.** `C_TooltipInfo` and `GetItemInfo` are asynchronous; an item whose body has not arrived is cached `pending` and re-parsed on the next `Get()`, but until then it scores on what was readable.
- **The perf harness measures in-combat cost only.** Recording opens at combat start and closes at combat end by design, so the addon's genuinely expensive paths — the flyout rebuild, `MacroBar.Update`, macro writes — never appear in a capture, because they are deliberately not in combat (`core/PerfSetup.lua:12-25`).
- **A build with no `LibKa0s-Widgets-1.0` draws no drag-handle strip.** Since v1.48.0 the unlocked strip above the macro bar is the library's `DragHandle`, and `modules/MacroBar.lua` keeps no hand-built copy to fall back to: a second copy of a widget is the drift the adoption removed. A vendored payload missing that major — or one older than v1.48.0, whose Widgets shell has no `DragHandle` — leaves `bar.handle` nil, and nothing raises, because `applyLock` guards on it. The bar is still positionable: its own frame still drags from any pixel the slots leave bare, and `/cm set macroBar.point|x|y` still writes the anchor outright.
- **A build with no `LibKa0s-Compat-1.0` reads no spec and no spell name.** Since v1.55.0 `KCM.Compat.GetSpecialization`, `GetSpecializationInfo` and `GetSpellName` are the library's, and a payload missing that major takes the reader arm its API document prescribes: each answers `nil` rather than a host copy of the ladder. The addon then behaves as for a character with no spec chosen (`SpecHelper.GetCurrent` answers the class alone) and labels spell rows with their placeholder. `IsSecret` keeps asking the client, so no secret reaches a comparison on that install. `core/CoreSetup.lua` already announces the missing payload.
- **The addon never deletes a `KCM_*` macro.** The account macro quota is 120; when it is full, `modules/MacroManager.lua:345-347` refuses the create and returns `"error", "account macro quota full (120)"`. It will not free a slot on the user's behalf.

## Repository

- **Dual-path WSL checkout.** `/home/tushar/GIT/ConsumableMaster/` and
  `/mnt/d/Profile/Users/Tushar/Documents/GIT/ConsumableMaster/` are the same repo via symlink; either
  path works for git and file tools.
- **Remote.** `origin` → `https://github.com/tusharsaxena/ConsumableMaster.git` (GitHub repo
  `tusharsaxena/ConsumableMaster`), `master` is the default branch, and the `gh` CLI is authenticated
  for issues.
- **Tracked vs ignored.** `libs/` is tracked (vendored Ace3 / LibSharedMedia / LibKa0s — standard WoW
  addon practice), as are `defaults/`, `docs/`, `tests/`, `locales/` and all `.lua` source.
  `.gitignore` covers `.claude/settings.local.json`, OS cruft and editor scratch files.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/perf-analysis/`, `docs/revendor/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file — the hub: overview, layout, module map, schema, bus, slash, events, invariants, and the ratified deviations |
| `scope.md` | What the manager picks and macros, and what it leaves to the player |
| `module-map.md` | Every non-vendored file, its responsibility, and load order |
| `schema.md` | The AceDB profile, the composite buckets, and the discovered-set GC |
| `settings-panel.md` | The panel tree, per-option behavior, and the write seam |
| `data-flow.md` | Bag scan → classify → rank → select → macro rewrite |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | Twenty-one verbs, over the eight-or-more threshold, and four of them carry a subcommand tree (`priority`, `stat`, `aio`, `bar`, plus the `dump` targets) |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon’s own |
| `debug.md` | Present | `/cm dump` targets in `core/SlashDump.lua` are the addon’s own beyond the library console |
| `message-bus.md` | Not applicable | Five messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message Bus` |
| `compat-layer.md` | Not applicable | `core/Compat.lua` publishes two addon-specific shims (`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` answers 2); threshold is three or more. The other four are `LibKa0s-Compat-1.0`'s, which the library documents (`### LibKa0s adoption`) |
| `profiles.md` | Present | A profile control ships: the Profiles page (`settings/Profiles.lua`, AceDBOptions), and every setting the addon stores is profile-resident |
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `macro-bar.md` | The optional on-screen macro bar — its model, slots and repaint path |
| `macro-manager.md` | Macro ownership, fingerprints, and the rewrite protocol |

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`). A
decision may be reasoned at length elsewhere — `docs/scope.md`, an audit or review bundle — but a
deviation that is not in this table is not ratified, and an audit re-files it as an open failure.
The **Re-check trigger** is the condition that ends the deviation; a row without one is a permanent
opt-out wearing a table's clothes.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `localization-§4` | `core/TooltipCache.lua` parses English tooltip **text** — heal/mana/stat magnitudes, the `Augment Rune` marker, and the weapon-application effect | There is no stable-ID substitute for reading a numeric magnitude out of free text. The deviation is deliberately narrow: item and weapon **classification** already runs on the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua:167-170`, `core/WeaponSlots.lua`), so category and weapon-affinity detection work on every client. Reasoned at `docs/scope.md` → *Out of scope* → Localization; audit finding `CM-30` | 2026-08-05 | A client API that exposes those magnitudes as structured data, or the first non-enUS client this addon commits to supporting |
| `compat` | `core/TooltipCache.lua:459` and `modules/Ranker.lua:88` call the `GetItemInfo` global directly, with none of the "namespaced first, legacy global as fallback" chain that `core/Classifier.lua:164-170` and `core/WeaponSlots.lua:45-46` use for the same item-info family | The neighbors' chain reaches for `C_Item.GetItemInfoInstant`, which is a **different** API: it returns itemID, type, subType, equip location, icon, `classID` and `subClassID`, and no name, quality, item level or required level. The two sites here need exactly those async fields, so `GetItemInfoInstant` has nothing to offer them and the chain would be a fallback with no first branch. `compat`'s routing MUST is scoped to **deprecated** APIs; `GetItemInfo` and `GetItemCount` are live retail globals, so routing them through `core/Compat.lua` would add a seam over an API that is not moving. The `.luacheckrc` comment that used to assert they were wrapped was false and is corrected in place. Review finding `CM-R-10`, audit finding `CM-63` | 2026-08-05 | Blizzard deprecating the `GetItemInfo` / `GetItemCount` globals, or a namespaced replacement becoming the only source of an item's name, quality and item level |
| `preview-mode` | The macro bar shows no synthetic **placeholder** while unlocked, and has no preview verb to toggle | The rule's placeholder clause is a SHOULD, and it exists so a positionable display is never an invisible frame the user cannot aim. This bar cannot be that: every enabled slot draws a real button on every pass, and `core/MacroDisplay.lua`'s `MD.Texture` degrades pick icon → stored macro icon → `MD.FALLBACK_ICON` (`:26`), so a slot always has something to draw even with an empty bag and unhydrated item data. Unlocked is also already unmistakable without fake data — `modules/MacroBar.lua`'s `applyLock` shows a translucent gold wash over the whole frame and a labeled drag handle above it. A placeholder here would have to *replace* live, correct icons and counts with invented ones, and the bar's footprint is a function of the real slot count, so a preview would move the very thing being positioned. Bullet 3's MUST — clear the preview on re-lock or on the verb going off — has nothing to clear, because nothing is ever previewed. Audit finding `CM-67` | 2026-08-05 | The bar gaining any state in which a slot renders blank or the frame renders empty (a slot that draws nothing when a category has no candidate, an unlocked bar with every slot hidden), **or** a preview / test verb being added to `/cm` — either one re-arms the placeholder SHOULD and bullet 3's clear-on-re-lock MUST with it |

**Retired on 2026-09-08.** The register carried a `toc-file-§5` row for the within-`core/` file sequence, filed as `CM-49` in `docs/audits/2026-08-04/`. The section has since said what its MUST binds: the **section-header** order is the rule, the file sequence inside a section is a reference implementation, and an addon whose bootstrap forces a different one states the reason in a comment in the TOC itself — at which point the ordering is *compliant* and "needs no deviation-register row" (`toc-file.md:129`). Those comments are at `ConsumableMaster.toc:51-57` and `:77-79` and have been since the row was written; the row was recording a departure from a rule that no longer exists to depart from, which is the graveyard `documentation-§3` forbids. `CM-71` in `docs/audits/2026-09-07/` is the finding that says so.

### Files over the 1500-line cap

`layout-§1` caps every **authored** `.lua` this repository tracks at 1500 lines — `tests/` included,
with vendored code (`libs/`, `tests/_kit/`) the only carve-out that reaches anything here; nothing in
this repo is generated non-shipping data, so the second carve-out has no instance. It gives a file
over the cap three terminal states: peeled, an open issue naming the seam a peel would follow, or a
ratified row in [Documented deviations](#documented-deviations) carrying a re-check trigger. What it
does not allow is a breach nothing anywhere remarks on — "the count sitting in a bundle manifest that
no document reads". This table is the remark, and it is why an audit **MUST NOT** re-file `layout-§1`
against any file in it.

**Nothing is over the cap today.** Both breaches this section was written for were peeled in
2026-09: `tests/test_macrobar.lua` (2229) on the two cuts issue
[#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32) named, and
`tests/test_settingsui.lua` (2028) on the one cut issue
[#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33) named. Measured 2026-09-16 with

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

and re-measured 2026-09-23 by the kit's gate, `tests/_kit/test_layout_cap.lua`, green on its five
`layoutcap:` cases; the largest authored file is `tests/test_macrobar.lua` at 1425 lines.

| File | Lines | Disposition |
|---|---|---|

**No authored file in this repository is over the cap.**

That sentence is load-bearing rather than decorative. `tests/_kit/test_layout_cap.lua` reads it: a census
with no rows and no such line is a failure, because an empty table and a table that has been quietly
emptied look identical on the page and are not the same claim. Rows alongside that line are a failure
too. The section itself stays whether or not there is a breach — it is where the rule is written
down, and it is what an audit reads before re-filing `layout-§1` against anything here.

**What the peel did**, for the next reader who wonders where a case went. Both were test suites, and
both moved cases WHOLE — not one assertion changed, and the harness registers exactly the same
cases it did before — the total did not move by one. (It has moved since, for unrelated reasons;
`docs/test-cases.md` is the live count.)

| Was | Is now |
|---|---|
| `tests/test_macrobar.lua` (2229) | `tests/test_macrobar.lua` (1425) — model, display, cooldowns, schema rows, click gating, the flyout's candidate list, master controls, the Defaults button |
| | `tests/test_macrobar_layout.lua` (432) — the four pure-geometry sections: grid, label geometry, flyout placement, indicator clearance |
| | `tests/test_macrobar_chrome.lua` (536) — the chrome appliers (`MacroBarButton.ApplyStyle`), the flyout's bind/apply pass, the `options-ui-§15/§16/§17` rows they honor, and the drag handle's two tooltips and mark tint |
| | `tests/macrobar_support.lua` — not a suite: the fixtures (`fcfg`, `buildBar`) read on both sides of a seam, SHARED through a `rawget` guard rather than copied |
| `tests/test_settingsui.lua` (2028) | `tests/test_settingsui.lua` (1255) — this addon's own settings wiring |
| | `tests/test_settingsui_optionsui.lua` (800) — the three `options-ui` conformance blocks (§13 strips, §18 reorder lists, §13 wrapped-strip geometry) |

Two of the cuts moved off the line numbers the issues recorded, because both files grew after the
issues were written. The macro bar's chrome block also had to take the three `options-ui-§15/§16/§17`
cases that arrived after it, which use its `styleButton`/`firstCall` fixtures; the settings suite's
cut is a middle slice rather than a tail, because two later blocks (the refresh debounce and the #35
characterization cases) now sit below the conformance blocks. The seams themselves are the ones the
issues named.

**The 1000–1500 band is on notice, not in breach** (measured 2026-09-22, after the two peels below):
`tests/test_macrobar.lua` (1425), `tests/test_slash.lua` (1322), `settings/Panel.lua` (1312),
`tests/test_settingsui.lua` (1259), `settings/MacroBar.lua` (1166), `settings/Category.lua` (1141),
`tests/test_schema.lua` (1023) and `tests/test_selector.lua` (1011). They are named here so a later
reader can tell the band was looked at rather than missed; none needs a disposition until it
crosses.

**`settings/Panel.lua` was peeled on 2026-09-16 at 1488 lines**, twelve under the cap — close enough
that the next ordinary edit would have breached it, and `docs/automated-tests/RESULTS.md` had carried
it as *Accepted* across three consecutive releases, which `automated-tests-§4` refuses a fourth time.
The cut is the seam the file's own section heading already drew: the schema-and-chrome half a page
module calls while it BUILDS stayed, and the run-time `KCM.Options` shim — `Refresh`,
`RequestRefresh`, `Open`, the refresh debounce and the three bus subscriptions that drive them — moved
whole to `settings/OptionsShim.lua` (266), which the TOC loads immediately after it. Panel.lua is 1308.
No behavior moved with it: not a comparison, a constant or a comment changed in the cut, and the two
notice functions the shim still needs are published on `KCM.Settings` rather than copied, because one
of them holds a said-once flag.

**`settings/Category.lua` was peeled on the same day, at 1400 lines**, and for the same reason: three
consecutive releases carrying it as *Accepted*, which `automated-tests-§4` refuses a fourth time. Its
seam is the one the page actually has — everything else on the Macros page draws a list the addon
already holds, and one block draws the control that puts something NEW into it. The Add-by-ID line,
whole (the Type dropdown, the two ID kinds, this addon's resolver over `LibKa0s-Options-1.0`'s
`IdInput`, the candidate set, the writer and `O.AddByIDBusy`), is `settings/CategoryAddByID.lua` (362)
now; Category.lua is 1121. `makeDropdown` and `spellNameByID` went with it because the block was their
only caller. The cut is two-way and deliberately thin: the new file takes exactly two of the page's
helpers — `newRow` and `afterMutation` — off `KCM.Settings.MacrosPage`, published at load by
Category.lua, and publishes one entry point back, `KCM.Settings.AddByID.Render`, which Category.lua
calls at RENDER time, so neither file has a load-time dependency in the other direction.
