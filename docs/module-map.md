# Module map

Per-module roles + public APIs. Pair this with [pipeline.md](./pipeline.md) for how the modules talk to each other.

```
core/Namespace.lua ── Loads first. Names the private namespace (NS.name);
                   every other file picks it up via `local _, NS = ...`.

core/ConsumableMaster.lua ── AceAddon entry (AceAddon:NewAddon(NS, ...)).
                   OnInitialize creates the DB; Pipeline.Recompute /
                   RequestRecompute orchestrate every recompute; event
                   handlers publish RECOMPUTE onto the bus. Also houses
                   KCM.ID sentinel helpers (AsSpell / IsSpell / IsItem /
                   SpellID / ItemID), KCM.dbDefaults, and
                   KCM.ResetAllToDefaults.

core/Bus.lua ───── Closed message bus. KCM.bus (AceEvent embed),
                   KCM.NewBusTarget(), KCM.MSG.{RECOMPUTE, PANEL_REFRESH,
                   SPEC_CHANGED}. Each receiver owns its own target.

core/Constants.lua  KCM.PREFIX (cyan [CM] tag) + KCM.Say. Single source of
                   truth for chat output styling.

core/Compat.lua ── Spec + spell API seam. GetSpecialization /
                   GetSpecializationInfo / GetNumSpecializationsForClassID /
                   GetSpecializationInfoForClassID / GetSpellName wrap the
                   deprecated-global churn.

core/State.lua ─── Session-only runtime flags. KCM.State.debug (default off,
                   never persisted, resets each login).

core/Database.lua  RunMigrations() — runs right after AceDB:New; owns
                   db.global.schemaVersion.

core/Debug.lua ─── KCM.Debug.IsOn / Toggle / Print / Log — routes gated
                   diagnostics to the on-screen console (chat fallback only
                   if the console is absent).

defaults/         Seed data only. Evaluated at load; writes to
├── Categories.lua        KCM.Categories.LIST + KCM.Categories.BY_KEY
├── Defaults_StatPriority.lua    → KCM.SEED.STAT_PRIORITY
└── Defaults_*.lua         → KCM.SEED.<CATKEY>
                           Entries can be itemIDs or KCM.ID.AsSpell(sid)
                           sentinels (e.g. Recuperate in FOOD).

core/SpecHelper.lua  Class/spec identity. Spec keys are "<classID>_<specID>".
                   GetStatPriority merges user override → seed → class fallback.

core/TooltipCache.lua  C_TooltipInfo.GetItemByID(id) → parsed struct cached per
                   session. Invalidate(id) on GET_ITEM_INFO_RECEIVED.
                   Parser handles NBSP + |4singular:plural; grammar escapes,
                   captures healOverSec / manaOverSec so the Ranker can
                   tell immediate pots from heal-over-time pots.

core/BagScanner.lua  C_Container.GetContainerItemInfo sweep → { [id] = count }.
                   Stateless per-call.

core/Classifier.lua  (itemID) → which of the 8 single-pick categories. Reads
                   subType + parsed tooltip. FLASK is subType-only (tooltip-
                   free) so first-bag-scan discovery is deterministic for
                   already-cached flasks.

modules/Ranker.lua  Pure scorers per category. Spec-aware scorers weight stats
                   against { primary, secondary[] } from SpecHelper. Spell
                   entries short-circuit to a fixed SPELL_SCORE above any
                   item. HP_POT / MP_POT apply an immediate-pot bonus that
                   HOT candidates only earn when their amount beats the
                   best-immediate in the set by >20%.

modules/Selector.lua  Owns the candidate set ((seed ∪ added ∪ discovered) − blocked),
                   drives Ranker, merges pins (user overrides), returns the
                   effective priority list. PickBestForCategory returns the
                   first entry the player actually owns — bag-count for
                   items, IsPlayerSpell for spell sentinels.

modules/MacroManager.lua  The ONLY module that calls CreateMacro / EditMacro.
                   SetMacro for single picks, SetCompositeMacro for HP_AIO
                   and MP_AIO. Combat-deferral queue, fingerprint cache,
                   bounded flush retry, action-bar icon convention.
                   Detail in macro-manager.md.

modules/DebugLog.lua  On-screen debug console (ConsumableMasterDebugWindow,
                   ScrollingMessageFrame, JetBrains Mono via LibSharedMedia).
                   DL.SetEnabled / IsEnabled / Toggle / AddLine / Show / Hide
                   + pure DL.FormatPlain / FormatColored.

settings/         Settings UI framework + per-tab modules.
├── Panel.lua            Helpers.CreatePanel (gold title + atlas divider),
│                        always-visible scrollbar gutter, Section / Button /
│                        ButtonPair / Label / RenderField builders. Owns
│                        Settings.Schema + Helpers; publishes the KCM.Options
│                        shim. About content is rendered here on the parent
│                        canvas.
├── General.lua          Enable checkbox + Debug-console button + Maintenance section.
├── StatPriority.lua     Spec selector + paired Primary / Secondary 1-4.
└── Category.lua         One tab per Categories.LIST entry; dispatches to
                          single (Add-by-ID + Priority list) or composite
                          (In Combat / Out of Combat) rendering.

core/SlashCommands.lua  /cm (and /consumablemaster alias) dispatcher. Three
                   ordered tables: COMMANDS, DUMP_TARGETS, and the
                   *_COMMANDS verb namespaces. Local say() = print(KCM.PREFIX
                   .." "..s). Detail in debug.md.

modules/KCM*.lua  AceGUI custom widgets. Loaded before settings/ so that
                  AceGUI:Create("KCM…") works at panel render time.
                  Detail in file-index.md.
```

## Public APIs

### Core (`core/ConsumableMaster.lua`)

```lua
-- Lifecycle
KCM:OnInitialize()                           -- AceDB + slash registration; panel registration is driven by the bootstrap listener in settings/Panel.lua
KCM:OnEnable()                               -- event subscriptions

-- Pipeline (also see pipeline.md)
KCM.Pipeline.RequestRecompute(reason)        -- frame-coalesced entry point
KCM.Pipeline.Recompute(reason)               -- iterates categories, with pcall + score cache
KCM.Pipeline.RecomputeOne(catKey, scoreCache, reason)  -- single category
KCM.Pipeline.RunAutoDiscovery(reason) -> n   -- bag scan + classifier + MarkDiscovered
KCM.Pipeline.DiscoverOne(itemID, reason, nowUnix?)  -- one-id retry path

-- Sentinel helpers (also see data-model.md)
KCM.ID.AsSpell(spellID)  -> negative
KCM.ID.IsSpell(id)       -> bool
KCM.ID.IsItem(id)        -> bool
KCM.ID.SpellID(id)       -> spellID | nil
KCM.ID.ItemID(id)        -> itemID  | nil

-- Centralized reset
KCM.ResetAllToDefaults(reason) -> bool       -- wipes categories + statPriority, runs
                                             --   InvalidateAll → RunAutoDiscovery → Recompute
```

### Bus (`core/Bus.lua`)

```lua
KCM.bus                          -- AceEvent-3.0 embed (SendMessage / RegisterMessage)
KCM.NewBusTarget()   -> target   -- fresh AceEvent-embed table; one per receiver
KCM.MSG.RECOMPUTE                -- event/UI → pipeline (→ RequestRecompute, coalesced)
KCM.MSG.PANEL_REFRESH            -- pipeline → options panel (debounced rebuild)
KCM.MSG.SPEC_CHANGED             -- spec change → options panel (retracks Stat Priority)
```

Event handlers publish `RECOMPUTE`; the pipeline owns the only subscriber and forwards to `RequestRecompute`. `Pipeline.Recompute` publishes `PANEL_REFRESH`; `OnSpecChanged` publishes `SPEC_CHANGED`. Each receiver subscribes on its own `NewBusTarget()`.

### MacroManager — see [macro-manager.md](./macro-manager.md)

### Selector (`modules/Selector.lua`)

```lua
-- Read
KCM.Selector.GetBucket(catKey, specKey?)               -> { added, blocked, pins, discovered }
KCM.Selector.BuildCandidateSet(catKey, specKey?)       -> array of ids
KCM.Selector.GetEffectivePriority(catKey, specKey?, scoreCache?) -> array of ids (sorted + pinned)
KCM.Selector.PickBestForCategory(catKey, specKey?, scoreCache?)  -> id | nil

-- Write (mutators)
KCM.Selector.AddItem(catKey, id, specKey?)             -> changed:bool   -- accepts items + spells
KCM.Selector.Block(catKey, id, specKey?)               -> changed:bool
KCM.Selector.MoveUp(catKey, id, specKey?)              -> changed:bool
KCM.Selector.MoveDown(catKey, id, specKey?)            -> changed:bool
KCM.Selector.MarkDiscovered(catKey, id, specKey?, nowUnix) -> changed:bool   -- items only
KCM.Selector.SweepStaleDiscovered(nowUnix) -> droppedCount  -- 30-day TTL, PEW-only
```

`AddItem` also unblocks: if the id is in `blocked`, it's removed from there *and* added to `added`, so `changed = true` even when `added[id]` was already set. There is no `Unblock` verb — Block + AddItem cover the two transitions users actually take.

### Ranker (`modules/Ranker.lua`)

```lua
KCM.Ranker.Score(catKey, id, ctx, scoreCache?)         -> number
KCM.Ranker.SortCandidates(catKey, ids, ctx, scoreCache?) -> sorted ids
KCM.Ranker.BuildContext(catKey, itemIDs, existing, scoreCache?) -> ctx
KCM.Ranker.Explain(catKey, id, ctx) -> { {label, value, note?}, ... }
```

`ctx` carries spec priority for spec-aware scorers and per-set signals (e.g. `bestImmediateAmount` for HP_POT / MP_POT's 20% HOT rule).

### Classifier (`core/Classifier.lua`)

```lua
KCM.Classifier.Match(catKey, id, tt, subType) -> bool
KCM.Classifier.MatchAny(id) -> { catKeys }   -- used by auto-discovery
```

Per-category predicates are English-only against `subType` + parsed `tt`. The Midnight subtype renames live as `ST_*` constants at the top of the file.

### BagScanner (`core/BagScanner.lua`)

```lua
KCM.BagScanner.Scan() -> { [itemID] = count }     -- one pass; counts locked items
KCM.BagScanner.HasItem(itemID) -> bool, count     -- single C_Item.GetItemCount call
```

`HasItem` does not fall back to a full `Scan`. `C_Item.GetItemCount(id, false, false, true)` is trusted.

### TooltipCache (`core/TooltipCache.lua`)

```lua
KCM.TooltipCache.Get(itemID) -> { healValue, healValueAvg, healOverSec,
                                  manaValue, manaValueAvg, manaOverSec,
                                  isConjured, hasStatBuff, isFeast, buffDurationSec,
                                  statBuffs = { {stat, amount}, ... } }
KCM.TooltipCache.Invalidate(itemID)
KCM.TooltipCache.InvalidateAll()
KCM.TooltipCache.IsUsableByPlayer(itemID) -> bool
```

If `C_TooltipInfo.GetItemByID` returns nil or empty, the cache marks the id `pending`. The first `GET_ITEM_INFO_RECEIVED` for that id invalidates the entry and triggers a recompute (for bag items only — see [pipeline.md GIIR split](./pipeline.md#giir-bagnon-bag-split)).

### SpecHelper (`core/SpecHelper.lua`)

```lua
KCM.SpecHelper.GetCurrent() -> classID, specID, specKey, specName
KCM.SpecHelper.MakeKey(classID, specID) -> "<classID>_<specID>"
KCM.SpecHelper.AllSpecs() -> { { classID, specID, specKey, specName }, ... }
KCM.SpecHelper.GetStatPriority(specKey) -> { primary, secondary = { ... } }
```

`GetStatPriority` merges in this order: user override (`db.profile.statPriority[specKey]`) → seed default (`KCM.SEED.STAT_PRIORITY[specKey]`) → class-primary fallback. There is no setter — user-override writes go directly through `db.profile.statPriority[specKey] = { primary, secondary }` (Options panel via the local `writeStatPriority` helper, slash CLI via `/cm stat primary` / `/cm stat secondary`). Spec + spell lookups route through `KCM.Compat`.

### Settings panel (`settings/Panel.lua` + per-tab modules)

```lua
-- Lifecycle (preserved API; called by Core / Debug / SlashCommands / Pipeline)
KCM.Options.Register()       -- one-time; auto-runs from PLAYER_LOGIN / ADDON_LOADED bootstrap
KCM.Options.Open()           -- opens panel directly to General

-- Refresh
KCM.Options.Refresh()        -- immediate: re-render every shown panel
KCM.Options.RequestRefresh() -- trailing-edge debounced (1.0s quiet, 3.0s max wait)

-- Schema layer
KCM.Settings.Schema          -- ordered list of {panel, section, group, path, type, label, default, onChange?}
KCM.Settings.RegisterTab(key, builder)            -- per-tab module entry point
KCM.Settings.order           -- { "general", "statpriority", "food", ..., "mp_aio" }
KCM.Schema:Set(path, value) -> bool               -- unified validate → write → onChange → refresh seam
KCM.Settings.Helpers.Resolve(path) -> parent, key
KCM.Settings.Helpers.Get(path) -> value
KCM.Settings.Helpers.Set(path, value) -> bool
KCM.Settings.Helpers.FindSchema(path) -> row | nil
KCM.Settings.Helpers.ValidateSchema() -> errorCount
KCM.Settings.Helpers.RefreshAllPanels()

-- Panel-build helpers (called by per-tab modules)
KCM.Settings.Helpers.CreatePanel(name, title, opts) -> ctx
KCM.Settings.Helpers.SetRenderer(ctx, fn)
KCM.Settings.Helpers.ResetScroll(ctx)
KCM.Settings.Helpers.EnsureScroll(ctx) -> AceGUI ScrollFrame
KCM.Settings.Helpers.PatchAlwaysShowScrollbar(scrollWidget)
KCM.Settings.Helpers.Section(ctx, label)
KCM.Settings.Helpers.RenderField(ctx, def, parent?, relativeWidth?)
KCM.Settings.Helpers.Button(ctx, spec)
KCM.Settings.Helpers.ButtonPair(ctx, leftSpec, rightSpec)
KCM.Settings.Helpers.Label(ctx, text, fontSize?)
KCM.Settings.Helpers.AddSpacer(scroll, height)
KCM.Settings.Helpers.AttachTooltip(widget, label, tooltip)
KCM.Settings.Helpers.BuildAboutContent(ctx)             -- parent canvas content
```

`RequestRefresh` is the panel-side equivalent of pipeline coalescing — it collapses a burst of `GET_ITEM_INFO_RECEIVED`-driven `Pipeline.Recompute` runs into one panel rebuild. It is driven by the `PANEL_REFRESH` bus message. User-driven mutations (add / remove / move buttons) call `Refresh` directly via `afterMutation` for snappy click response. Detail in [pipeline.md GIIR split](./pipeline.md#giir-bagnon-bag-split).

`RefreshAllPanels` iterates every previously-shown panel ctx and re-runs its `_renderFn`. Renderers call `ResetScroll(ctx)` before re-adding children so a re-render after a mutation starts on a clean slate.

### Debug (`core/Debug.lua` + `modules/DebugLog.lua`)

```lua
KCM.Debug.IsOn() -> bool                      -- reads KCM.State.debug (session-only)
KCM.Debug.Toggle()                            -- routes through DebugLog:SetEnabled
KCM.Debug.Print(fmt, ...)                     -- conditional; early-returns when off
KCM.Debug.Log(fmt, ...)                       -- unconditional console line

KCM.DebugLog.SetEnabled(on) / IsEnabled() / Toggle()
KCM.DebugLog.AddLine(text) / Show() / Hide()
KCM.DebugLog.FormatPlain(...) / FormatColored(...)   -- pure formatters
```

Diagnostics route to the on-screen console (`ConsumableMasterDebugWindow`); chat is a fallback only when the console is unavailable. See [debug.md](./debug.md).

## Module publishing pattern

Every module uses the same idiom:

```lua
local _, NS = ...
local KCM = NS
KCM.Foo = KCM.Foo or {}
local F = KCM.Foo
```

- Every file receives the same private namespace table as its second vararg; `core/Namespace.lua` loads first and names it. There is **no `_G.KCM`** — `local KCM = NS` is a per-file transition alias.
- Never overwrite an existing `KCM.Foo` without `or {}` — another file may have reached it first.
- Never make the local shadow the namespace (`local KCM = {}` would break everything downstream).
- Expose the public API on `F` (or `KCM.Foo` directly). Keep helpers `local` to the file.

## Load order

`ConsumableMaster.toc` is the source of truth. It is sectioned `# Libraries / Locales / Core / Defaults / Modules / Settings`, and order within a section is dependency order, not alphabetical:

1. **Libraries** — `embeds.xml` (LibStub + every Ace3 sub-library + LibSharedMedia).
2. **Locales** — `locales/enUS.lua` (publishes `KCM.L`).
3. **Core** — `core/Namespace.lua` (names `NS`) → `core/ConsumableMaster.lua` (AceAddon promotion via `AceAddon:NewAddon(NS, addonName, ...)`, DB, pipeline) → `Bus` → `Constants` → `Compat` → `State` → `Database` → `Debug` → `SpecHelper` → `TooltipCache` → `BagScanner` → `Classifier` → `SlashCommands`. **Every other file assumes the private `NS` (aliased `KCM`) already exists** — `core/Namespace.lua` guarantees that.
4. **Defaults** — `defaults/Categories.lua` then each `defaults/Defaults_*.lua`.
5. **Modules** — `Ranker` → `Selector` → `MacroManager` → `DebugLog`, then the AceGUI widgets `KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`.
6. **Settings** — `settings/Panel.lua` → `settings/General.lua` → `settings/StatPriority.lua` → `settings/Category.lua`.

`settings/Panel.lua` must come first within `settings/` because it creates `KCM.Settings.Helpers` + `KCM.Settings.RegisterTab` which the per-tab modules call at file-bottom. Widgets load before `settings/` so `AceGUI:Create("KCM…")` works at panel-render time. Event handlers and `Pipeline` functions are *defined* in `core/ConsumableMaster.lua` but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.

If you add a new runtime file, put it in the right section of `ConsumableMaster.toc`.
</content>
</invoke>
