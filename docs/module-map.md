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
                   SPEC_CHANGED, MACROBAR_REFRESH}. Each receiver owns its
                   own target.

core/Constants.lua  KCM.PREFIX (cyan [CM] tag) + KCM.Say(fmt, ...) — the single
                   secret-safe chat seam (plain-string or format-string form) —
                   + KCM.SafeToString / KCM.IsConcatSafe (secret-safe stringify
                   backing both KCM.Say and the debug sink; detection probes
                   table.concat, not tostring/..). Single source of truth for
                   chat output styling.

core/Compat.lua ── Spec + spell API seam. GetSpecialization /
                   GetSpecializationInfo / GetNumSpecializationsForClassID /
                   GetSpecializationInfoForClassID / GetSpellName wrap the
                   deprecated-global churn.

core/State.lua ─── Session-only runtime flags. KCM.State.debug (default off,
                   never persisted, resets each login).

core/Database.lua  RunMigrations() — runs right after AceDB:New; owns
                   db.global.schemaVersion.

core/Debug.lua ─── KCM.Debug(tag, fmt, ...) callable sink + KCM.Debug.IsOn() —
                   routes gated diagnostics to the on-screen console (chat
                   fallback only if the console is absent). Read side only:
                   the flag's single write path is DebugLog.SetEnabled.

defaults/         Seed data only. Evaluated at load; writes to
├── Categories.lua        KCM.Categories.LIST + KCM.Categories.BY_KEY
│                         + Get(key) (the accessor everything uses; callers
│                         that want every row iterate LIST directly)
├── Defaults_StatPriority.lua    → KCM.SEED.STAT_PRIORITY
└── Defaults_*.lua         → KCM.SEED.<CATKEY>
                           Entries can be itemIDs or KCM.ID.AsSpell(sid)
                           sentinels (e.g. Recuperate in FOOD).

core/MacroDisplay.lua  Read-only "what does KCM_FOO resolve to right now":
                   PickID / Texture / Count / Cooldown / SetTooltip /
                   MacroIndex. Shared by the macro bar's slots and the
                   settings panel's drag icon. Touches no protected API.

core/MacroBarModel.lua  Pure slot bookkeeping for the macro bar. AllKeys /
                   NormalizeOrder / IndexOf / Swap / VisibleKeys, plus the
                   db-backed Config / IsEnabled / Order / Visible /
                   MacroName / KeyForMacroName wrappers.

core/MacroBarLayout.lua  Pure geometry. Grid(count, cfg) -> positions +
                   width/height/cols/rows; Dimensions(count, cfg);
                   LabelAnchor(cfg) -> point/relPoint/x/y/justifyH over the
                   LABEL_POINTS 9-way grid; LabelFontSize(size, scalePct).
                   No frames, no db reads.

core/LSMPatch.lua  Third-party fixup (not addon logic): re-registers the
                   vendored LSM30_Border widget at PLAYER_LOGIN with its
                   misaligned 42px preview tile collapsed, so border pickers
                   sit flush in a canvas-layout panel.

core/SpecHelper.lua  Class/spec identity. Spec keys are "<classID>_<specID>".
                   GetStatPriority merges user override → seed → class fallback.

core/TooltipCache.lua  C_TooltipInfo.GetItemByID(id) → parsed struct cached per
                   session. Invalidate(id) on GET_ITEM_INFO_RECEIVED.
                   Parser handles NBSP + |4singular:plural; grammar escapes,
                   captures healOverSec / manaOverSec so the Ranker can
                   tell immediate pots from heal-over-time pots.

core/WeaponSlots.lua  equipped main-hand (16) / off-hand (17) weapon subClassID
                   (gated on classID == Weapon) → "bladed" (whetstone) /
                   "blunt" (weightstone) / nil (not enhanceable). Numeric =
                   locale-independent. Drives the per-hand Weapon Enchant picks.

core/BagScanner.lua  C_Container.GetContainerItemInfo sweep → { [id] = count }.
                   Stateless per-call.

core/Classifier.lua  (itemID) → which of the 11 single-pick categories. Reads
                   the numeric classID/subClassID (locale-independent) + parsed
                   tooltip. FLASK is subclass-only (tooltip-free) so first-bag-
                   scan discovery is deterministic for already-cached flasks.

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
                   SetMacro for single picks, SetWeaponEnchantMacro for the
                   per-hand WPN_ENCH body, SetCompositeMacro for HP_AIO and
                   MP_AIO. Combat-deferral queue, fingerprint cache,
                   bounded flush retry, action-bar icon convention.
                   Detail in macro-manager.md.

modules/DebugLog.lua  On-screen debug console (ConsumableMasterDebugWindow,
                   ScrollingMessageFrame, JetBrains Mono via LibSharedMedia).
                   DL.SetEnabled / IsEnabled / Toggle / AddLine / Show / Hide /
                   Toggle_Window / ShowCopy + pure DL.FormatPlain / FormatColored.

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
                   *_COMMANDS verb namespaces. The file-local say is an alias
                   of the shared seam (local say = KCM.Say), so every slash
                   line inherits the [CM] tag and secret-safe stringification.
                   Detail in debug.md.

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
KCM.Pipeline.RunAutoDiscovery(reason) -> n   -- bag scan + classifier + MarkDiscovered;
                                             --   one summary debug line per pass
                                             --   (per-id retry is the internal `discoverOne` local)

-- Pure debug-summary formatter (frame-free, unit-tested; see debug.md)
KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped) -> string -- [Calc] line

-- Sentinel helpers (also see data-model.md)
KCM.ID.AsSpell(spellID)  -> negative
KCM.ID.IsSpell(id)       -> bool
KCM.ID.IsItem(id)        -> bool
KCM.ID.SpellID(id)       -> spellID | nil

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
KCM.MSG.MACROBAR_REFRESH         -- pipeline → macro bar (undebounced icon/count repaint)
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
KCM.Selector.PickBestForSlot(catKey, slot, scoreCache?)          -> id | nil   -- perHand cats; slot 16/17

-- Write (mutators)
KCM.Selector.AddItem(catKey, id, specKey?)             -> changed:bool   -- accepts items + spells
KCM.Selector.Block(catKey, id, specKey?)               -> changed:bool
KCM.Selector.MoveUp(catKey, id, specKey?)              -> changed:bool
KCM.Selector.MoveDown(catKey, id, specKey?)            -> changed:bool
KCM.Selector.MarkDiscovered(catKey, id, specKey?, nowUnix) -> changed:bool   -- items only
KCM.Selector.SweepStaleDiscovered(nowUnix) -> swept, touchedCats  -- 30-day TTL, PEW-only
```

`PickBestForSlot` is the per-hand entry point used for `perHand` categories (today only `WPN_ENCH`). It filters the effective priority list to entries whose parsed `tt.weaponAffinity` (`"bladed"` / `"blunt"` / `"any"`) matches `WeaponSlots.SlotAffinity(slot)` for the currently equipped weapon, then picks the first owned entry in that filtered set. Returns nil when the hand is empty or nothing matches.

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
KCM.Classifier.Match(catKey, id) -> bool
KCM.Classifier.MatchAny(id) -> { catKeys }   -- used by auto-discovery
KCM.Classifier.IsReusableAugRune(id) -> bool -- REUSABLE_AUG_IDS membership; Ranker tie-break
```

`IsReusableAugRune` backs the AUG_RUNE scorer's `REUSABLE_BONUS`: a reusable rune (Ethereal, Dreambound, Eternal, Lightning-Forged, Lightforged) only wins when it *ties* the best rune on primary-stat amount — the bonus is smaller than one stat step, so a higher-stat consumable rune still beats it. Keep the ID set in sync with the `(reusable)` annotations in `defaults/Defaults_AugRune.lua`.

Per-category predicates key on the numeric `classID`/`subClassID` (locale-independent — Consumable=0; Potion=1, Flask/Phial=3, Food & Drink=5) plus parsed `tt`, never the localized subType display string (localization-§4; see scope.md). Weapon-enchant / augment-rune predicates key on `tt` flags. The remaining English dependency is TooltipCache's tooltip-text parsing.

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
                                  healPct, manaPct, isPctPerSecond, pctOverDurationSec,
                                  isConjured, hasStatBuff, isFeast, buffDurationSec,
                                  isWeaponEnhance, weaponAffinity,   -- "bladed"|"blunt"|"any"
                                  isAugmentRune,
                                  statBuffs = { {stat, amount}, ... },
                                  minLevel, itemName, pending, unsupported }
KCM.TooltipCache.Invalidate(itemID)
KCM.TooltipCache.InvalidateAll()
KCM.TooltipCache.IsUsableByPlayer(itemID) -> bool
```

`pending` also covers the partial-tooltip case: a Consumable whose parse yields no recognizable effect (no heal/mana/stat/duration, not a weapon enhance, not an augment rune) stays pending rather than caching as final, because `GET_ITEM_INFO_RECEIVED` does not re-fire for an item whose basic info was already cached. `unsupported` marks the build where `C_TooltipInfo.GetItemByID` is missing entirely.

If `C_TooltipInfo.GetItemByID` returns nil or empty, the cache marks the id `pending`. The first `GET_ITEM_INFO_RECEIVED` for that id invalidates the entry and triggers a recompute (for bag items only — see [pipeline.md GIIR split](./pipeline.md#giir-bagnon-bag-split)).

### WeaponSlots (`core/WeaponSlots.lua`)

```lua
KCM.WeaponSlots.SlotAffinity(slot) -> "bladed" | "blunt" | nil   -- slot 16 (main) / 17 (off)
```

Reads the equipped weapon's numeric `subClassID`, gated on `classID == Weapon` so a shield or an off-hand frill never reads as enhanceable. Numeric = locale-independent. `nil` means "no weapon, or nothing a whetstone/weightstone applies to"; oils (`weaponAffinity == "any"`) still need a non-nil slot affinity to be considered for that hand. Consumed by `Selector.PickBestForSlot` and by `settings/Category.lua`'s WPN_ENCH page header.

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
KCM.Settings.Register()      -- = the file-local registerPanel; the PLAYER_LOGIN /
                             --   ADDON_LOADED bootstrap calls registerPanel directly,
                             --   so this is the named alias, not the live call path
KCM.Options.Open()           -- opens the parent About canvas, sub-pages force-expanded

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
KCM.Settings.Helpers.ValidateSchemaValue(def, value) -> coerced | nil, reason  -- type check + min/max clamp
KCM.Settings.Helpers.SetAndRefresh(path, value) -> bool  -- the mutation seam KCM.Schema:Set wraps
KCM.Settings.Helpers.RefreshAllPanels()   -- structural: re-render the shown page, flag the rest dirty
KCM.Settings.Helpers.RefreshScalars()     -- scalar: re-sync widgets in place, no rebuild (options-ui-§11)

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
KCM.Settings.Helpers.Grid(ctx, items)
KCM.Settings.Helpers.CustomCheckbox(ctx, parent, relWidth, spec)   -- non-schema-backed checkbox
KCM.Settings.Helpers.Label(ctx, text, fontSize?)
KCM.Settings.Helpers.AddSpacer(scroll, height)
KCM.Settings.Helpers.AttachTooltip(widget, label, tooltip)
KCM.Settings.Helpers.BuildAboutContent(ctx)             -- parent canvas content
```

`RequestRefresh` is the panel-side equivalent of pipeline coalescing — it collapses a burst of `GET_ITEM_INFO_RECEIVED`-driven `Pipeline.Recompute` runs into one panel rebuild. It is driven by the `PANEL_REFRESH` bus message. User-driven mutations (add / remove / move buttons) call `Refresh` directly via `afterMutation` for snappy click response. Detail in [pipeline.md GIIR split](./pipeline.md#giir-bagnon-bag-split).

`RefreshAllPanels` iterates every previously-shown panel ctx and re-runs its `_renderFn`. Renderers call `ResetScroll(ctx)` before re-adding children so a re-render after a mutation starts on a clean slate.

### Macro bar (`core/MacroBar*.lua`, `core/MacroDisplay.lua`, `modules/MacroBar*.lua`)

```lua
-- Pure (headless-tested)
KCM.MacroBarLayout.Grid(count, cfg)      -> { positions, width, height, cols, rows }
KCM.MacroBarLayout.Dimensions(count, cfg)-> cols, rows
KCM.MacroBarModel.NormalizeOrder(order, allKeys?) -> order, changed
KCM.MacroBarModel.Swap(order, a, b)      -> bool          -- drag-to-swap primitive
KCM.MacroBarModel.VisibleKeys(order, shown) -> array
KCM.MacroBarModel.Order() / Visible() / Config() / IsEnabled()
KCM.MacroBarModel.MacroName(catKey) / KeyForMacroName(name)
KCM.MacroBarModel.Labels(catKey)         -> fullName, shortName
KCM.MacroBarLayout.LabelAnchor(cfg)      -> point, relPoint, x, y, justifyH
KCM.MacroBarLayout.LabelFontSize(size, scalePct) -> points (6-24)
KCM.MacroBarLayout.Flyout(count, cfg)    -> { positions, size, width, height, point, relPoint, axis }
KCM.MacroBarLayout.IndicatorAnchor(cfg)  -> point, relPoint, x, y, rotation, w, h
KCM.MacroBarLayout.IndicatorClearance(cfg) -> dx, dy   (label vs indicator)
KCM.MacroDisplay.PickID / Texture / Count / Cooldown / SetTooltip / MacroIndex

-- Frames
KCM.MacroBar.Update()                    -- the single apply seam; self-defers in combat
KCM.MacroBar.FlushPending()              -- called from KCM:OnRegenEnabled
KCM.MacroBar.SetEnabled(on) / SetLocked(locked) / ResetPosition()
KCM.MacroBar.SwapSlots(fromKey, toKey)   -- blocked in combat
KCM.MacroBar.Refresh() / RefreshCooldowns() / ApplyAlpha() / IsShown()
KCM.MacroBarButton.Create(parent, catKey, index) / Refresh / RefreshIcon
KCM.MacroBarButton.RefreshCooldown / ApplyStyle(btn, cfg)
KCM.MacroBarButton.BorderTexture(lsmName) -> edge texture (LSM, with fallback)
KCM.MacroBarFlyout.Create(button, catKey, index)   -- indicator + secure container
KCM.MacroBarFlyout.Apply(button, cfg)              -- content; no-op in combat
KCM.MacroBarFlyout.Candidates(catKey, cfg)         -- capped + inverted list
KCM.MacroBarFlyout.RefreshCooldowns(button) / RefreshCooldown(entry)
KCM.MacroBarFlyout.MAX_ENTRIES                     -- pool ceiling
```

On by default (and unlocked, so the drag handle shows) — schema v2 brings
upgrading profiles to the same state, once. Slots are
`SecureActionButtonTemplate` buttons whose `macro` attribute is stamped once and
never rewritten, so reordering moves anchors only. Full design + combat contract
in [macro-bar.md](./macro-bar.md).

### Debug (`core/Debug.lua` + `modules/DebugLog.lua`)

```lua
KCM.Debug.IsOn() -> bool                      -- reads the flag (DebugLog.IsEnabled, else State.debug)
KCM.Debug(tag, fmt, ...)                      -- callable sink; gated, secret-safe; early-returns when off
                                              --   Read side only — there is no KCM.Debug.Toggle;
                                              --   DebugLog.SetEnabled is the single write path (§5)

KCM.DebugLog.SetEnabled(on) / IsEnabled() / Toggle()   -- Toggle flips the flag
KCM.DebugLog.AddLine(tag, msg) / Clear()
KCM.DebugLog.Show() / Hide() / Toggle_Window() / IsWindowShown() / ShowCopy()
KCM.DebugLog.RefreshHeader() / UpdateScrollBar() / UpdateStatus()   -- header, scrollbar + line counter (§11)
KCM.DebugLog.FormatPlain(ts, tag, msg) / FormatColored(ts, tag, msg)   -- pure formatters
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

1. **Libraries** — LibStub + every Ace3 sub-library + LibSharedMedia + `AceGUI-3.0-SharedMediaWidgets` (last, since its widgets need both AceGUI and LibSharedMedia), listed directly in the TOC (no `embeds.xml` wrapper).
2. **Locales** — `locales/enUS.lua` (publishes `KCM.L`).
3. **Core** — `core/Namespace.lua` (names `NS`) → `core/ConsumableMaster.lua` (AceAddon promotion via `AceAddon:NewAddon(NS, addonName, ...)`, DB, pipeline) → `Bus` → `Constants` → `Compat` → `State` → `Database` → `Debug` → `SpecHelper` → `TooltipCache` → `WeaponSlots` → `BagScanner` → `Classifier` → `LSMPatch` → `MacroDisplay` → `MacroBarModel` → `MacroBarLayout` → `SlashCommands`. **Every other file assumes the private `NS` (aliased `KCM`) already exists** — `core/Namespace.lua` guarantees that.
4. **Defaults** — `defaults/Categories.lua` then each `defaults/Defaults_*.lua`.
5. **Modules** — `Ranker` → `Selector` → `MacroManager` → `DebugLog` → `MacroBarFlyout` → `MacroBarButton` → `MacroBar`, then the AceGUI widgets `KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`.
6. **Settings** — `settings/Panel.lua` → `settings/General.lua` → `settings/MacroBar.lua` → `settings/StatPriority.lua` → `settings/Category.lua`.

`settings/Panel.lua` must come first within `settings/` because it creates `KCM.Settings.Helpers` + `KCM.Settings.RegisterTab` which the per-tab modules call at file-bottom. Widgets load before `settings/` so `AceGUI:Create("KCM…")` works at panel-render time. Event handlers and `Pipeline` functions are *defined* in `core/ConsumableMaster.lua` but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.

If you add a new runtime file, put it in the right section of `ConsumableMaster.toc`.
</content>
</invoke>
