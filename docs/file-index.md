# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — the TOC at `ConsumableMaster.toc` is the source of truth for load order. Layout is modular: `core/` + `modules/` + `defaults/` + `settings/` + `locales/`.

## core/

| File | Responsibility |
|------|----------------|
| `core/Namespace.lua` | Loads first. Names the private namespace (`NS.name`). Every other file picks the same table up via `local _, NS = ...`. There is **no `_G.KCM`** — `local KCM = NS` is a per-file transition alias. |
| `core/ConsumableMaster.lua` | AceAddon entry (`AceAddon:NewAddon(NS, addonName, ...)`, stores `NS.addon`). `OnInitialize` (DB + `Database.RunMigrations` + slash registration; panel registration is driven by the `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap in `settings/Panel.lua`), `OnEnable` (event subscriptions that publish `RECOMPUTE`). Houses `Pipeline.Recompute` / `RequestRecompute` / `RecomputeOne`, the event handlers, `KCM.ID` sentinel helpers (positive = item, negative = spell), `KCM.dbDefaults` (the AceDB schema), and `KCM.ResetAllToDefaults`. |
| `core/Bus.lua` | Closed message bus. `KCM.bus` (AceEvent embed), `KCM.NewBusTarget()`, `KCM.MSG.{RECOMPUTE, PANEL_REFRESH, SPEC_CHANGED}`. Each receiver owns its own target. |
| `core/Constants.lua` | `KCM.PREFIX` (cyan `[CM]` tag) + `KCM.Say` + `KCM.SafeToString` (secret-safe stringifier). Single source of truth for chat-output styling. |
| `core/Compat.lua` | Spec + spell API seam. `KCM.Compat.GetSpecialization / GetSpecializationInfo / GetNumSpecializationsForClassID / GetSpecializationInfoForClassID / GetSpellName` wrap the deprecated-global churn. SpecHelper / SlashCommands / MacroManager / settings / KCMItemRow all route through it. |
| `core/State.lua` | Session-only runtime flags. `KCM.State.debug` — default off, **never persisted**, resets each login. |
| `core/Database.lua` | `RunMigrations()` — runs immediately after `AceDB:New`; owns `db.global.schemaVersion`. |
| `core/Debug.lua` | `KCM.Debug.IsOn() / Toggle()` plus the callable sink `KCM.Debug(tag, fmt, ...)`. Reads the session-only `KCM.State.debug`; `Toggle` routes through `KCM.DebugLog.Toggle` → `SetEnabled`. Diagnostics go to the on-screen console; chat is a fallback only when the console is absent. |
| `core/SpecHelper.lua` | Class/spec identity. `GetCurrent()` returns `(classID, specID, specKey, specName)`. `GetStatPriority(specKey)` merges user override → seed default → class fallback. `MakeKey(classID, specID)` produces the canonical `<classID>_<specID>` string. Spec/spell lookups route through `KCM.Compat`. |
| `core/TooltipCache.lua` | `C_TooltipInfo.GetItemByID(id)` parser + per-session cache. Captures heal/mana values (incl. HOT amounts), stat buffs, conjured/feast flags, durations. `Get(id) / Invalidate(id) / InvalidateAll() / IsUsableByPlayer(id)`. Handles NBSP and `\|4singular:plural;` escapes. |
| `core/WeaponSlots.lua` | Equipped-weapon affinity for the Weapon Enchant category. Maps the main-hand (16) / off-hand (17) weapon's English subType to `bladed` (whetstone) / `blunt` (weightstone) / `nil` (not enhanceable). |
| `core/BagScanner.lua` | `Scan() -> {[itemID] = count}` (one pass over `C_Container`). `HasItem(itemID) -> ownsBool, count` via a single `C_Item.GetItemCount` call (no full-Scan fallback). Stateless. |
| `core/Classifier.lua` | `(itemID) → categories`. `Match(catKey, id, tt, subType)` and `MatchAny(id) -> { catKeys }`. English-only subType + tooltip-pattern matching. `ST_*` constants at the top of the file absorb Midnight subType renames. |
| `core/SlashCommands.lua` | `/cm` (and `/consumablemaster` alias) dispatcher. Three ordered tables: `COMMANDS` (top-level verbs), `DUMP_TARGETS` (`/cm dump <target>`), and `PRIORITY_COMMANDS` / `STAT_COMMANDS` / `AIO_COMMANDS` (verb namespaces). The `say()` helper (`= print(KCM.PREFIX .. " " .. s)`) prepends the cyan `[CM]` prefix to every chat line. Owns the `KCM_CONFIRM_RESET` StaticPopup. |

## modules/

| File | Responsibility |
|------|----------------|
| `modules/Ranker.lua` | Per-category scorers. `Score(catKey, id, ctx, scoreCache) / SortCandidates(catKey, ids, ctx, scoreCache) / BuildContext(catKey, itemIDs, existing, scoreCache) / Explain(catKey, id, ctx)`. Spell entries short-circuit to a fixed score above every item. HP_POT / MP_POT apply the immediate-vs-HOT 20% rule. Spec-aware scorers weight by `ctx.specPriority`. |
| `modules/Selector.lua` | Candidate set + pin merge + ownership walk. Public surface: `BuildCandidateSet / GetEffectivePriority / PickBestForCategory / GetBucket` (read), `AddItem / Block / MoveUp / MoveDown / MarkDiscovered / SweepStaleDiscovered` (write). Owns the `(seed ∪ added ∪ discovered) − blocked` math and the 30-day discovered GC. |
| `modules/MacroManager.lua` | The **only** module that calls `CreateMacro` / `EditMacro`. `SetMacro(macroName, id, catKey)` for single picks; `SetCompositeMacro(cat, scoreCache)` for HP_AIO / MP_AIO. Combat-deferral queue (`pendingUpdates`), bounded retry on flush, DYNAMIC_ICON / DEFAULT_ICON convention, 255-byte body limit fallback. `InvalidateState()` clears caches for `/cm rewritemacros`. See [macro-manager.md](./macro-manager.md). |
| `modules/DebugLog.lua` | On-screen debug console — `ConsumableMasterDebugWindow` + `ScrollingMessageFrame`, JetBrains Mono via LibSharedMedia; title bar with a left `Debug: ON/OFF` toggle + Copy / Clear / close, and a separate Copy window for `Ctrl+C`. `SetEnabled / IsEnabled / Toggle / AddLine / Show / Hide / Toggle_Window / ShowCopy` + pure `FormatPlain / FormatColored`. |

## AceGUI custom widgets

Also under `modules/`. Loaded between `MacroManager` / `DebugLog` and `settings/`. Each file calls `AceGUI:RegisterWidgetType` at the bottom; the tab builders acquire instances via `AceGUI:Create("KCM…")` at render time.

| File | Purpose |
|------|---------|
| `modules/KCMItemRow.lua` | Priority-list row: status glyphs (green check / red / yellow star) + item icon + name + quality tier. Hover renders the real in-game item or spell tooltip (forks on `KCM.ID.IsSpell`). Spell name via `KCM.Compat`. |
| `modules/KCMIconButton.lua` | Gold-hover icon button used for ↑ / ↓ / ×. |
| `modules/KCMScoreButton.lua` | The blue "i" info button. Hover renders the per-item `Ranker.Explain` breakdown. No-op `SetLabel` so the caller can pass an arbitrary tooltip-title string without rendering a text label under the icon. |
| `modules/KCMMacroDragIcon.lua` | Pickable macro icon at the top of each category page. Resolves to `GetItemIcon(lastItemID)` / `C_Spell.GetSpellTexture(spellID)` directly (the `?` sentinel is meaningless on a static UI widget). |

## settings/

Each tab module registers a builder via `KCM.Settings.RegisterTab(key, builder)`; `settings/Panel.lua`'s bootstrap iterates `KCM.Settings.order` and calls each builder once Blizzard_Settings is ready. Bodies are hand-built AceGUI widget trees inside a `Helpers.CreatePanel` canvas — no AceConfigDialog.

| File | Responsibility |
|------|----------------|
| `settings/Panel.lua` | Framework. `Helpers.CreatePanel` (gold title + atlas divider + body), lazy AceGUI ScrollFrame with always-visible scrollbar gutter (`PatchAlwaysShowScrollbar`), `Section` / `Button` / `ButtonPair` / `Label` / `RenderField` builders. Owns the `KCM.Settings.Schema` array, `KCM.Schema:Set` (validate → write → onChange → refresh seam), `Helpers.Get / Set / FindSchema / ValidateSchema / RefreshAllPanels`. Hosts the parent (About) canvas via `BuildAboutContent`. Publishes the `KCM.Options.{Register,Refresh,RequestRefresh,Open}` shim that Core / Debug / SlashCommands / Pipeline call. |
| `settings/General.lua` | General tab. Section "General" — the `[Enable]` schema-driven checkbox + a `[Debug console]` button (opens the session-only on-screen console). Section "Maintenance" — row 1 paired `[Force resync \| Force rewrite]` buttons, row 2 full-width `[Reset all priorities]` (StaticPopup-confirmed via `KCM_RESET_ALL`). |
| `settings/StatPriority.lua` | Stat Priority tab: full-width spec dropdown (class+spec icon markup), Primary alone in a half-row, Secondary 1\|2 + 3\|4 paired half-rows, inline Reset. Owns `KCM.Options._viewedSpec` + `O.ResolveViewedSpec` + `O.FormatSpec`. |
| `settings/Category.lua` | Per-category tabs (single + composite). One builder per row in `KCM.Categories.LIST`. Single dispatch: drag icon → Add-by-ID (Type \| ID input) → Priority list rows (KCMItemRow + KCMScoreButton + ↑/↓/× buttons) → inline Reset. Composite dispatch: drag icon → In Combat / Out of Combat sections (each row: KCMItemRow + Enabled checkbox + ↑/↓) → inline Reset. Shared `KCM_RESET_CATEGORY` StaticPopup. |

## defaults/

| File | Populates | Purpose |
|------|-----------|---------|
| `defaults/Categories.lua` | `KCM.Categories.LIST` + `KCM.Categories.BY_KEY` | Category metadata: macro name, displayName, specAware, classifier/ranker keys. Composite rows carry `composite=true` + `components = { inCombat={...}, outOfCombat={...} }`. |
| `defaults/Defaults_StatPriority.lua` | `KCM.SEED.STAT_PRIORITY` | Primary + ordered secondary stats per `<classID>_<specID>`. |
| `defaults/Defaults_<CAT>.lua` | `KCM.SEED.<CATKEY>` | Seed item / spell IDs per category. Spell entries use `KCM.ID.AsSpell(spellID)`. Composite categories have no seed file. |
| `defaults/README.md` | — | Seed file map + category scope decisions + refresh procedure. See [../defaults/README.md](../defaults/README.md). |

## locales/

| File | Responsibility |
|------|----------------|
| `locales/enUS.lua` | Publishes `KCM.L`, a key-returning metatable. User-facing strings (panel labels, slash descriptions, popup text) go through `L[...]`. English is the only shipped locale — this is a shell, not localization plumbing. |

## Shared infrastructure

- `libs/` — vendored Ace3 + LibStub + LibSharedMedia, tracked in git (standard WoW addon practice). Loaded before any addon source by the `# Libraries` block of `ConsumableMaster.toc`, which lists each library file directly (no `embeds.xml` wrapper — toc-file-§4).
- `ConsumableMaster.toc` — Interface line (`120007`), version, SavedVariables, file load order. Sectioned `# Libraries / Locales / Core / Defaults / Modules / Settings`; order within a section is dependency order, not alphabetical.
- `tests/` — headless harness (`lua5.1 tests/run.lua`; suite inventory in [test-cases.md](./test-cases.md)) over the addon's logic layer; `wow_mock.lua` stubs the WoW API + bus.

## Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — stub (standard link + layout + gate + pointer into `docs/`).
- `docs/agent-context.md` — engineer working notes (hard rules + response style + doc index).
- `docs/ARCHITECTURE.md` — design overview + invariants + message-bus catalogue + doc index.
- `docs/*.md` — topic chunks (this file is one of them).
</content>
