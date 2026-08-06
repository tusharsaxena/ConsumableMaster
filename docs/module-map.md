# Module map

Per-module roles + public APIs. Pair this with [data-flow.md](./data-flow.md) for how the modules talk to each other.

```
core/Namespace.lua ── Loads first. Names the private namespace (NS.name) and
                   KCM.VERSION; every other file picks the table up via
                   `local _, NS = ...`.

core/PerfSetup.lua  The addon's half of LibKa0s-Perf-1.0 + its panel.
                   Publishes KCM.Perf — the instance ITSELF, not a facade,
                   because the brackets read .on / .run / .suspended as plain
                   boolean fields the library writes. Supplies /cm as the
                   taught command, ConsumableMasterPerfDB as the capture ring,
                   the run-log sink (DebugLog.AddLine, the UNGATED append) and
                   the suspend/resume pair. Two buckets instrumented:
                   `cooldown` (MacroBar.RefreshCooldowns) and `recompute`
                   (Pipeline.Recompute). Absent major -> absent feature and
                   no stub; the two bracket sites take their upvalue
                   nil-tolerantly. Loads SECOND in # Core (performance-§1:
                   ahead of every load-time `local Perf = NS.Perf`).

core/ConsumableMaster.lua ── AceAddon entry (AceAddon:NewAddon(NS, ...)).
                   OnInitialize creates the DB; Pipeline.Recompute /
                   RequestRecompute orchestrate every recompute; event
                   handlers publish RECOMPUTE onto the bus. Also houses
                   KCM.ID sentinel helpers (AsSpell / IsSpell / IsItem /
                   SpellID / ItemID) and KCM.ResetAllToDefaults.
                   KCM.dbDefaults is NOT here — it is defaults/Profile.lua's.

core/Bus.lua ───── Closed message bus. KCM.bus (AceEvent embed),
                   KCM.NewBusTarget(), KCM.MSG.{RECOMPUTE, PANEL_REFRESH,
                   SPEC_CHANGED, MACROBAR_REFRESH}. Each receiver owns its
                   own target.

core/Constants.lua  KCM.PREFIX (cyan [CM] tag). Single source of truth for
                   chat output styling; read live, never captured.

core/CoreSetup.lua  The addon's half of LibKa0s-Core-1.0. Binds
                   KCM.SafeToString / KCM.IsConcatSafe to the library
                   (secret-safe stringify backing both KCM.Say and the debug
                   sink; detection probes table.concat, not tostring/..) and
                   builds KCM.Say(fmt, ...) — the single secret-safe chat seam
                   (plain-string or format-string form) — over a prefix
                   function and a print sink. Degrades to short built-ins,
                   announced once, when the library is missing. Loads after
                   Constants.lua, before SlashCommands.lua.

core/Compat.lua ── Spec + spell API seam. GetSpecialization /
                   GetSpecializationInfo / GetNumSpecializationsForClassID /
                   GetSpecializationInfoForClassID / GetSpellName wrap the
                   deprecated-global churn. IsSecret(value) wraps the client's
                   own issecretvalue (false on a pre-Midnight client) so a gate
                   over client data can ask before it compares.

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

core/DebugLogSetup.lua  The addon's half of LibKa0s-DebugLog-1.0: registers
                   JetBrains Mono with LibSharedMedia, resolves the font path,
                   and builds ONE console instance (ConsumableMasterDebugWindow)
                   over the KCM.State.debug flag, the KCM.Say printer, the
                   [Init] summary and the options repaint. Publishes the flat
                   DL.SetEnabled / IsEnabled / Toggle / AddLine / Show / Hide /
                   Toggle_Window / ShowCopy forwarders + DL.FormatPlain /
                   FormatColored (the library's) + DL.instance. Windowless stub
                   when the library is absent.

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

settings/         Settings UI framework + per-tab modules.
├── Panel.lua            The addon's half of LibKa0s-Options-1.0. The chrome
│                        is the library's — panel factory + header/breadcrumb,
│                        the lazy Defaults button, the scroll container and the
│                        always-visible scrollbar gutter, plus tooltip / spacer
│                        / section / session-checkbox — reached through thin
│                        Helpers.* forwarders onto Helpers.instance. The schema
│                        half stays here: Settings.Schema, the Resolve →
│                        SetAndRefresh write seam, Grid / Button / ButtonPair /
│                        Label, EnumValues / LSMValues, the page order and the
│                        KCM.Options shim. RenderField, the four row widget
│                        MAKERS, SetRenderer and both refresh tiers are the
│                        library's, since [LIBKA0S-04](https://github.com/tusharsaxena/ConsumableMaster/issues/22)/-05 were fixed upstream
│                        and adopted. CreatePanel also stamps the Blizzard
│                        canvas callbacks (OnCommit / OnRefresh / OnDefault),
│                        which is what makes the Settings window's own FOOTER
│                        Defaults control work. About content is rendered here
│                        on the parent canvas, with the command rows coming
│                        back already formatted by the Slash major
│                        (LIBKA0S-13). With LibKa0s absent no panel is
│                        registered at all.
├── General.lua          Enable checkbox + Debug-console button + Maintenance section.
├── StatPriority.lua     Spec selector + paired Primary / Secondary 1-4.
└── Category.lua         One tab per Categories.LIST entry; dispatches to
                          single (Add-by-ID + Priority list) or composite
                          (In Combat / Out of Combat) rendering.

core/SlashDump.lua  The /cm dump <target> diagnostics namespace: DUMP_TARGETS,
                   DUMP_ORDER and the dump dispatcher. A leaf — it reads only
                   KCM.Say and addon state, no slash parsing helpers — so it
                   loads FIRST of the three. Published as KCM.SlashDump.

core/SlashCommands.lua  The slash VERB BODIES: the priority / stat / aio / bar
                   namespaces and their *_COMMANDS tables, the shared parsing
                   helpers, KCM.FormatSchemaValue, and the KCM_CONFIRM_RESET
                   popup raised by /cm resetall. Publishes five entry points on
                   KCM.SlashCommands.Verbs and knows nothing about how they are
                   dispatched. The file-local say is an alias of the shared seam
                   (local say = KCM.Say), so every slash line inherits the [CM]
                   tag and secret-safe stringification.

settings/Slash.lua  The DISPATCHER (CM-47 — slash-commands-§1 names this file).
                   The addon's half of LibKa0s-Slash-1.0: routing, the help
                   header and rows, the version verb and the schema CLI
                   (list / get / set / reset) are the library's, driven by this
                   file's ordered COMMANDS table, which is PASSED IN, not owned.
                   Holds the instance, addonVersion(), the schema helpers()
                   accessor, GetLandingRows() and KCM:OnSlashCommand.
                   GetLandingRows() hands the About panel the SAME rendered rows
                   /cm help prints, so the two cannot drift apart. Detail in
                   debug.md.

modules/KCM*.lua  AceGUI custom widgets. Loaded before settings/ so that
                  AceGUI:Create("KCM…") works at panel render time.
                  Detail in the File index section below.
```

## Public APIs

### Core (`core/ConsumableMaster.lua`)

```lua
-- Lifecycle
KCM:OnInitialize()                           -- AceDB + slash registration; panel registration is driven by the bootstrap listener in settings/Panel.lua
KCM:OnEnable()                               -- event subscriptions

-- Pipeline (also see data-flow.md)
KCM.Pipeline.RequestRecompute(reason)        -- frame-coalesced entry point
KCM.Pipeline.Recompute(reason)               -- iterates categories, with pcall + score cache
KCM.Pipeline.RecomputeOne(catKey, scoreCache, reason)  -- single category
KCM.Pipeline.RunAutoDiscovery(reason) -> n   -- bag scan + classifier + MarkDiscovered;
                                             --   one summary debug line per pass
                                             --   (per-id retry is the internal `discoverOne` local)

-- Pure debug-summary formatter (frame-free, unit-tested; see debug.md)
KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped) -> string -- [Calc] line

-- Sentinel helpers (also see schema.md)
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

If `C_TooltipInfo.GetItemByID` returns nil or empty, the cache marks the id `pending`. The first `GET_ITEM_INFO_RECEIVED` for that id invalidates the entry and triggers a recompute (for bag items only — see [data-flow.md GIIR split](./data-flow.md#giir-bagnon-bag-split)).

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

-- Panel-build helpers (called by per-tab modules). AttachTooltip / AddSpacer /
-- CustomCheckbox / EnsureScroll / PatchAlwaysShowScrollbar / ResetScroll /
-- RenderField / SetRenderer / RefreshAllPanels / RefreshScalars are
-- forwarders onto Helpers.instance, the LibKa0s-Options-1.0 instance; Section
-- and CreatePanel are wrappers that add what the library has no model for
-- (the section tracker, the ctx's render state, the Defaults combat guard).
-- RefreshAllPanels used to be a same-name-opposite-meaning trap; the library
-- grew the two-tier split in Options minor 3 ([LIBKA0S-05](https://github.com/tusharsaxena/ConsumableMaster/issues/24)) and the semantics
-- now match, which is why both are plain forwarders.
KCM.Settings.Helpers.instance                        -- the library instance
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

`RequestRefresh` is the panel-side equivalent of pipeline coalescing — it collapses a burst of `GET_ITEM_INFO_RECEIVED`-driven `Pipeline.Recompute` runs into one panel rebuild. It is driven by the `PANEL_REFRESH` bus message. User-driven mutations (add / remove / move buttons) call `Refresh` directly via `afterMutation` for snappy click response. Detail in [data-flow.md GIIR split](./data-flow.md#giir-bagnon-bag-split).

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
KCM.MacroBarLayout.IndicatorThickness(cfg) -> px (flyoutIndicatorScale % of button)
KCM.MacroBarLayout.IndicatorAnchor(cfg)  -> point, relPoint, x, y, rotation, w, h, glyph
KCM.MacroBarLayout.IndicatorClearance(cfg) -> dx, dy   (label vs indicator)
KCM.MacroDisplay.PickID / Texture / Count / Cooldown / SetTooltip / MacroIndex
KCM.MacroDisplay.TextureForID / CountForID / CooldownForID / SetTooltipForID
                                         -- same, keyed by opaque KCM ID (flyout)
KCM.MacroDisplay.Cooldown(macroName)     -> active, durationObject, start, duration
                                         -- start/duration withheld when secret

-- Frames
KCM.MacroBar.Update()                    -- the single apply seam; self-defers in combat
KCM.MacroBar.FlushPending()              -- called from KCM:OnRegenEnabled
KCM.MacroBar.SetEnabled(on) / SetLocked(locked) / ResetPosition()
KCM.MacroBar.SwapSlots(fromKey, toKey)   -- blocked in combat
KCM.MacroBar.Refresh() / RefreshCooldowns()
KCM.MacroBarButton.Create(parent, catKey, index) / Refresh / RefreshIcon
KCM.MacroBarButton.RefreshCooldown / ApplyStyle(btn, cfg)
KCM.MacroBarButton.ApplyCooldown(cd, active, durationObject, start, duration)
                                         -- shared with the flyout's entries;
                                         -- duration object first (combat-safe)
KCM.MacroBarButton.ApplyBorder(frame, anchorTo, cfg) / ApplyIconZoom(icon, cfg)
KCM.MacroBarButton.ApplyBackdropTex(tex, cfg)
                                         -- the chrome appliers ApplyStyle drives;
                                         -- the flyout's entries call the same three,
                                         -- and ApplyBorder owns the buttonBorder==false
                                         -- hide, so no caller repeats that test
KCM.MacroBarButton.BorderTexture(lsmName) -> edge texture (LSM, with fallback)
KCM.MacroBarFlyout.Create(button, catKey, index)   -- indicator + secure container
KCM.MacroBarFlyout.Apply(button, cfg)              -- content; no-op in combat
KCM.MacroBarFlyout.Candidates(catKey, cfg)         -- capped + inverted list
KCM.MacroBarFlyout.RefreshCooldowns(button) / RefreshCooldown(entry)
KCM.MacroBarFlyout.ApplyBackdrop(flyout, cfg)      -- paints flyout.bg, not the handler
KCM.MacroBarFlyout.Close(flyout)                   -- click path; declines in combat
KCM.MacroBarFlyout.IdleTick(flyout, elapsed, delay)-- hover-aware idle countdown
KCM.MacroBarFlyout.MAX_ENTRIES                     -- pool ceiling
```

On by default (and unlocked, so the drag handle shows) — schema v2 brings
upgrading profiles to the same state, once. Slots are
`SecureActionButtonTemplate` buttons whose `macro` attribute is stamped once and
never rewritten, so reordering moves anchors only. Full design + combat contract
in [macro-bar.md](./macro-bar.md).

### Debug (`core/Debug.lua` + `core/DebugLogSetup.lua`)

```lua
KCM.Debug.IsOn() -> bool                      -- reads the flag (DebugLog.IsEnabled, else State.debug)
KCM.Debug(tag, fmt, ...)                      -- callable sink; gated, secret-safe; early-returns when off
                                              --   Read side only — there is no KCM.Debug.Toggle;
                                              --   DebugLog.SetEnabled is the single write path (§5)

KCM.DebugLog.SetEnabled(on) / IsEnabled() / Toggle()   -- Toggle flips the flag
KCM.DebugLog.AddLine(tag, msg) / Clear()
KCM.DebugLog.Show() / Hide() / Toggle_Window() / IsWindowShown() / ShowCopy()
KCM.DebugLog.RefreshHeader() / UpdateScrollBar() / UpdateStatus()   -- header, scrollbar + line counter (§11)
KCM.DebugLog.FormatPlain(ts, tag, msg) / FormatColored(ts, tag, msg)   -- pure formatters (the library's)
KCM.DebugLog.instance                         -- the LibKa0s-DebugLog-1.0 instance itself
```

Every `KCM.DebugLog.*` above is a thin forwarder onto that instance. Two names are
host names on purpose: `Toggle` flips the **flag**, while the library spells its
**window** toggle `Toggle` — so ours is `Toggle_Window`, and aliasing them name for
name would invert `/cm debug`.

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
3. **Core** — `core/Namespace.lua` (names `NS`, `KCM.VERSION`) → `PerfSetup` (`performance-§1`: ahead of every load-time `local Perf = NS.Perf`) → `core/ConsumableMaster.lua` (AceAddon promotion via `AceAddon:NewAddon(NS, addonName, ...)`, DB, pipeline) → `Bus` → `Constants` → `CoreSetup` → `Compat` → `State` → `DebugLogSetup` → `Database` → `Debug` → `SpecHelper` → `TooltipCache` → `WeaponSlots` → `BagScanner` → `Classifier` → `LSMPatch` → `MacroDisplay` → `MacroBarModel` → `MacroBarLayout` → `SlashDump` → `SlashCommands`. **Every other file assumes the private `NS` (aliased `KCM`) already exists** — `core/Namespace.lua` guarantees that.
4. **Defaults** — `defaults/Profile.lua` (`KCM.dbDefaults`) → `defaults/Categories.lua` → each `defaults/Defaults_*.lua`.
5. **Modules** — `Ranker` → `Selector` → `MacroManager` → `MacroBarFlyout` → `MacroBarButton` → `MacroBar`, then the AceGUI widgets `KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`.
6. **Settings** — `settings/OptionsSetup.lua` → `settings/Panel.lua` → `settings/General.lua` → `settings/MacroBar.lua` → `settings/StatPriority.lua` → `settings/Category.lua` → `settings/Slash.lua` (last: it consumes `core/SlashCommands.lua`'s verb table and nothing in `settings/` reads it).

`settings/OptionsSetup.lua` must come first within `settings/` because it is the `LibKa0s-Options-1.0` seam: it creates `KCM.Settings.Helpers` and publishes the instance as `KCM.Settings.optionsUI`, which `settings/Panel.lua` takes as a file-scope local. `settings/Panel.lua` comes next because it publishes `KCM.Settings.RegisterTab`, which the per-tab modules call at file-bottom. Widgets load before `settings/` so `AceGUI:Create("KCM…")` works at panel-render time. Event handlers and `Pipeline` functions are *defined* in `core/ConsumableMaster.lua` but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.

If you add a new runtime file, put it in the right section of `ConsumableMaster.toc`.
</content>
</invoke>

## File index

Every non-vendored file, by directory. Folded in from the retired `module-map.md` (standard v2.23.0), which duplicated this map at a different granularity.

Where each responsibility lives in the source tree. Match this map to the actual files before editing — the TOC at `ConsumableMaster.toc` is the source of truth for load order. Layout is modular: `core/` + `modules/` + `defaults/` + `settings/` + `locales/`.

### core/

| File | Responsibility |
|------|----------------|
| `core/Namespace.lua` | Loads first. Names the private namespace (`NS.name`). Every other file picks the same table up via `local _, NS = ...`. There is **no `_G.KCM`** — `local KCM = NS` is a per-file transition alias. |
| `core/ConsumableMaster.lua` | AceAddon entry (`AceAddon:NewAddon(NS, addonName, ...)`, stores `NS.addon`). `OnInitialize` (DB + `Database.RunMigrations` + slash registration; panel registration is driven by the `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap in `settings/Panel.lua`), `OnEnable` (event subscriptions that publish `RECOMPUTE`). Houses `Pipeline.Recompute` / `RequestRecompute` / `RecomputeOne` / `RunAutoDiscovery` / `CalcSummary`, the event handlers, `KCM.ID` sentinel helpers (positive = item, negative = spell), and `KCM.ResetAllToDefaults`. `KCM.dbDefaults` is **not** here — it is `defaults/Profile.lua`'s. |
| `core/Bus.lua` | Closed message bus. `KCM.bus` (AceEvent embed), `KCM.NewBusTarget()`, `KCM.MSG.{RECOMPUTE, PANEL_REFRESH, SPEC_CHANGED, MACROBAR_REFRESH}`. Each receiver owns its own target. |
| `core/Constants.lua` | `KCM.PREFIX` (cyan `[CM]` tag) — the single source of truth for chat-output styling, read live by `core/CoreSetup.lua`, the category `emptyText` and the generated macro bodies. |
| `core/CoreSetup.lua` | The addon's half of `LibKa0s-Core-1.0`. Binds `KCM.SafeToString` / `KCM.IsConcatSafe` to the library (secret-safe stringifier; detection probes `table.concat`, not `tostring`/`..`) and builds `KCM.Say(fmt, ...)` — the single secret-safe chat seam, plain-string or format-string form — from `lib:New{ prefix = <function reading KCM.PREFIX>, sink = print }`. If the library is absent it installs short built-in fallbacks and says so once, on the first line printed (`KCM.LIBKA0S_MISSING`). Must load after `Constants.lua` and before `SlashCommands.lua`. |
| `core/Compat.lua` | Spec + spell API seam. `KCM.Compat.GetSpecialization / GetSpecializationInfo / GetNumSpecializationsForClassID / GetSpecializationInfoForClassID / GetSpellName` wrap the deprecated-global churn. `IsSecret(value)` wraps the client's `issecretvalue` (false on a pre-Midnight client) so a gate over client data can ask before it compares — see [midnight-quirks.md](./midnight-quirks.md#secret-values). SpecHelper / SlashCommands / MacroManager / MacroDisplay / settings / KCMItemRow all route through it. |
| `core/State.lua` | Session-only runtime flags. `KCM.State.debug` — default off, **never persisted**, resets each login. |
| `core/Database.lua` | `RunMigrations()` — runs immediately after `AceDB:New`; owns `db.global.schemaVersion`. |
| `core/Debug.lua` | `KCM.Debug.IsOn()` plus the callable sink `KCM.Debug(tag, fmt, ...)`. Read side only — it reads the session-only `KCM.State.debug` (via `DebugLog.IsEnabled` once the console has loaded) and deliberately publishes **no** toggle of its own, because `DebugLog.SetEnabled` is the flag's single write path (debug-logging-§5). Diagnostics go to the on-screen console (`LibKa0s-DebugLog-1.0`'s, via `core/DebugLogSetup.lua`); chat is a fallback only when the console is absent — including a whole install where LibKa0s is missing. |
| `core/DebugLogSetup.lua` | The addon's half of `LibKa0s-DebugLog-1.0`. Registers JetBrains Mono with LibSharedMedia, resolves the font path (Blizzard `Fonts\ARIALN.TTF` fallback — the library has none), and builds ONE console instance via `lib:New` — supplying the frame name (`ConsumableMasterDebugWindow`), the title, the `KCM.State.debug` read/write pair, the `KCM.Say` printer, the `[Init]` summary content and the `KCM.Options.Refresh` repaint on show/hide. Publishes the flat dot-callable surface the addon calls: `SetEnabled / IsEnabled / Toggle / AddLine / Clear / Show / Hide / Toggle_Window / IsWindowShown / ShowCopy / RefreshHeader / UpdateScrollBar / UpdateStatus` + `FormatPlain / FormatColored` (the library's function objects) + `instance`. `Toggle` flips the FLAG and is deliberately not the library's `Toggle`, which flips the window. Degrades to a windowless stub — publishing no `AddLine`, which is what re-arms `core/Debug.lua`'s chat fallback — when the library is absent. |
| `core/SpecHelper.lua` | Class/spec identity. `GetCurrent()` returns `(classID, specID, specKey, specName)`. `GetStatPriority(specKey)` merges user override → seed default → class fallback. `MakeKey(classID, specID)` produces the canonical `<classID>_<specID>` string. Spec/spell lookups route through `KCM.Compat`. |
| `core/TooltipCache.lua` | `C_TooltipInfo.GetItemByID(id)` parser + per-session cache. Captures heal/mana values (incl. HOT amounts), stat buffs, conjured/feast flags, durations. `Get(id) / Invalidate(id) / InvalidateAll() / IsUsableByPlayer(id)`. Handles NBSP and `\|4singular:plural;` escapes. |
| `core/WeaponSlots.lua` | Equipped-weapon affinity for the Weapon Enchant category. Maps the main-hand (16) / off-hand (17) weapon's numeric `subClassID` (gated on `classID == Weapon`, so it's locale-independent) to `bladed` (whetstone) / `blunt` (weightstone) / `nil` (not enhanceable). |
| `core/BagScanner.lua` | `Scan() -> {[itemID] = count}` (one pass over `C_Container`). `HasItem(itemID) -> ownsBool, count` via a single `C_Item.GetItemCount` call (no full-Scan fallback). Stateless. |
| `core/Classifier.lua` | `(itemID) → categories`. `Match(catKey, id)`, `MatchAny(id) -> { catKeys }`, and `IsReusableAugRune(id) -> bool` (the `REUSABLE_AUG_IDS` set the AUG_RUNE scorer uses as a stat tie-break). Keys on the locale-independent numeric `classID`/`subClassID` from `GetItemInfoInstant` (plus tooltip flags for weapon-enchant / augment-rune); no subType-string matching. Tooltip-TEXT parsing stays English (tracked deviation, see scope.md). |
| `core/LSMPatch.lua` | Third-party widget fixup, not addon logic: at `PLAYER_LOGIN` it re-registers `LSM30_Border` (from the vendored `AceGUI-3.0-SharedMediaWidgets`) wrapped so the 42px preview tile upstream pins to the widget's TOPLEFT is hidden and the label / dropdown bar re-anchor to the left edge — otherwise every border picker leaves a hole in a canvas-layout panel. Lives in `core/` so a lib refresh can't blow it away. Shared verbatim with Ka0s KickCD. |
| `core/MacroDisplay.lua` | Read-only display resolution. Keyed by macro name — `PickID / Texture / Count / Cooldown / SetTooltip / MacroIndex` — or by opaque KCM ID for the flyout's specific candidates — `TextureForID / CountForID / CooldownForID / SetTooltipForID` — plus `FALLBACK_ICON`. `Cooldown` / `CooldownForID` return `active, durationObject, start, duration` rather than a raw triple: mid-fight the spell cooldown API goes secret, so the boolean comes from the NeverSecret `isActive`/`isEnabled` and the raw pair is withheld unless the client says it's plain ([midnight-quirks.md](./midnight-quirks.md#secret-values)). Reads the pick MacroManager recorded in `db.profile.macroState`; calls no protected API. Shared by the macro bar's slots and `modules/KCMMacroDragIcon.lua` so icon/tooltip resolution can't drift between them. |
| `core/MacroBarModel.lua` | Pure slot bookkeeping for the macro bar. `AllKeys / NormalizeOrder / IndexOf / Swap / VisibleKeys` (data-in/data-out) plus the db-backed `Config / IsEnabled / Order / Visible / MacroName / KeyForMacroName`. `NormalizeOrder` is the repair seam for a saved order that predates a newly-shipped category. See [macro-bar.md](./macro-bar.md). |
| `core/MacroBarLayout.lua` | Pure geometry for the macro bar. `Grid(count, cfg) -> { positions, width, height, cols, rows }` (TOPLEFT offsets in WoW's coordinate space) + `Dimensions(count, cfg)`, handling `orientation` (which axis fills first) and `growthH` / `growthV` (which corner the first slot anchors to). Also the button-label geometry: `LabelAnchor(cfg) -> point, relPoint, x, y, justifyH` over the 9-way `LABEL_POINTS` grid × inside/outside placement, and `LabelFontSize(buttonSize, labelScale)` (percentage of button size, clamped to 6-24pt). No frames, no db reads. |
| `core/PerfSetup.lua` | The addon's half of `LibKa0s-Perf-1.0` + its panel. Builds one A/B capture harness and publishes it as `KCM.Perf` — the instance ITSELF, not a facade, because the brackets read `on` / `run` / `suspended` as plain boolean fields the library writes. Supplies the frame naming, `/cm` as the taught command, `ConsumableMasterPerfDB` as the capture ring's own SavedVariables global, the three sinks (run log → `DebugLog.AddLine`, which is the ungated append; chat → `KCM.Say`), and the `suspend`/`resume` pair — unregister every event + hide the bar, then re-run `KCM:OnEnable` and recompute. Absent major → absent feature and no stub: the two bracket sites take their upvalue nil-tolerantly, so nothing errors on that build. Loaded **second** in `# Core`, immediately after `core/Namespace.lua` — `performance-§1` puts it ahead of every file taking `local Perf = NS.Perf` as a load-time upvalue. |
| `core/SlashDump.lua` | The `/cm dump <target>` diagnostics namespace: `DUMP_TARGETS`, `DUMP_ORDER`, `printDumpLines`, `dumpHelp` and `dumpDispatch`. Peeled out of `SlashCommands.lua` for **CM-54** — it uses none of the slash parsing helpers, only `KCM.Say` and addon state, so it lifted whole. Loads **before** `SlashCommands.lua`, which is the dependency direction: the `priority` verb renders a composite category through the `pick` target, never the reverse. Published as `KCM.SlashDump` (`Dispatch` / `Help` / `TARGETS`). |
| `core/SlashCommands.lua` | The slash **verb bodies**, and nothing about dispatch (**CM-47**). Owns the `priority` / `stat` / `aio` / `bar` namespaces and their `PRIORITY_COMMANDS` / `STAT_COMMANDS` / `AIO_COMMANDS` tables, the shared parsing helpers (`trim`, `tokenize`, `findCommand`, `afterMutation`, the spec and priority-ID resolvers), and the `KCM_CONFIRM_RESET` StaticPopup raised by `/cm resetall`. `KCM.FormatSchemaValue` stays a published export here (the addon's own value renderer outside the CLI); the key=value formatter went to the library with the CLI. Publishes five entry points on `KCM.SlashCommands.Verbs` (`RunBar` / `RunPriority` / `RunStat` / `RunAIO` / `Dump`) for `settings/Slash.lua` to assemble. The file-local `say` is an alias of the shared `KCM.Say` seam, so every slash line inherits the cyan `[CM]` prefix and secret-safe stringification with no per-site tag. |
| `settings/Slash.lua` | The **dispatcher** — `slash-commands-§1` names this file, which is what **CM-47** was (`core/SlashCommands.lua` was also the repo's largest file at 1408 LOC, advisory **CM-54**). Holds the ordered `COMMANDS` table, the `SLASH_STRINGS` wording overrides, the `LibKa0s-Slash-1.0` descriptor and instance (`KCM.SlashCommands.instance`), `addonVersion()`, the schema `helpers()` accessor, `GetLandingRows()` and `KCM:OnSlashCommand`. Routing, the help header and rows, the version verb and the schema CLI (`Sl:CliList` / `CliGet` / `CliSet` / `CliReset`) are the library's; `Sl:CliResetAll` is deliberately declined, because this addon's global wipe also clears `categories` and `statPriority`, which the schema does not describe ([LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)). `COMMANDS` is **passed in**, never owned. `GetLandingRows()` returns the About panel's rows **already rendered** by `lib.FormatRow` — the same output `/cm help` prints, so the two lists cannot drift (LIBKA0S-13); the unrendered `GetCommandSummary()` went with that convergence. Loads last in `# Settings`: nothing else reads it at load, and AceConsole resolves `"OnSlashCommand"` by name when a command is typed. |

### modules/

| File | Responsibility |
|------|----------------|
| `modules/Ranker.lua` | Per-category scorers. `Score(catKey, id, ctx, scoreCache) / SortCandidates(catKey, ids, ctx, scoreCache) / BuildContext(catKey, itemIDs, existing, scoreCache) / Explain(catKey, id, ctx)`. Spell entries short-circuit to a fixed score above every item. HP_POT / MP_POT apply the immediate-vs-HOT 20% rule. Spec-aware scorers weight by `ctx.specPriority`. |
| `modules/Selector.lua` | Candidate set + pin merge + ownership walk. Public surface: `BuildCandidateSet / GetEffectivePriority / PickBestForCategory / PickBestForSlot / ListAvailable / GetBucket` (read), `AddItem / Block / MoveUp / MoveDown / MarkDiscovered / SweepStaleDiscovered` (write). `PickBestForSlot(catKey, slot, scoreCache?)` is the per-hand entry point (`perHand` cats; slot 16/17), affinity-filtered via `WeaponSlots`. Owns the `(seed ∪ added ∪ discovered) − blocked` math and the 30-day discovered GC. |
| `modules/MacroManager.lua` | The **only** module that calls `CreateMacro` / `EditMacro`. `SetMacro(macroName, id, catKey)` for single picks; `SetWeaponEnchantMacro(cat, mhPick, ohPick)` for the per-hand WPN_ENCH body; `SetCompositeMacro(cat, scoreCache)` for HP_AIO / MP_AIO. All three share the `commitMacro` tail (size limit → fingerprint early-out → combat deferral → `doEdit`). Combat-deferral queue (`pendingUpdates`), bounded retry on flush, DYNAMIC_ICON / DEFAULT_ICON convention, 255-byte body limit fallback. `InvalidateState()` clears caches for `/cm rewritemacros`. See [macro-manager.md](./macro-manager.md). |
| `modules/MacroBarButton.lua` | One macro-bar slot: a `SecureActionButtonTemplate` button whose `macro` attribute is stamped **once** at creation (a slot belongs to its category for life), plus icon / count / cooldown / tooltip refresh, the shared `ApplyCooldown(cd, active, durationObject, start, duration)` applier (prefers `SetCooldownFromDurationObject` — the only setter that survives a restricted cooldown — and falls back to the raw pair on a client without duration objects; the flyout's entries paint through the same seam), chrome (`ApplyStyle`, which is a sequencer over three exported appliers — `ApplyBorder(frame, anchorTo, cfg)` paints the LSM border on its own `BackdropTemplate` child so `buttonBorderOffset` can push it clear of the icon and owns the `buttonBorder == false` hide itself, `ApplyIconZoom(icon, cfg)` is the clamped `SetTexCoord` crop, `ApplyBackdropTex(tex, cfg)` is the fill — plus the auto-shortening label on a dedicated overlay child; the flyout's entries call the same three, so entry chrome cannot drift from slot chrome), the shared `BorderTexture(lsmName)` fetch, and the drag handlers — `PickupMacro` out to a Blizzard bar, swap-on-drop within our own bar, silent rejection of anything that isn't a `KCM_*` macro. |
| `modules/MacroBarFlyout.lua` | Per-slot hover flyout. `Create(button, catKey, index)` builds the indicator + container as `SecureHandlerEnterLeaveTemplate` frames whose `_onenter` / `_onleave` snippets open and close the strip **inside the secure environment** — the only way that works mid-combat, since flyout entries are `SecureActionButton`s and therefore protected. `Apply(button, cfg)` rebuilds content (out of combat only: binding an entry writes a secure attribute), `Candidates(catKey, cfg)` caps + inverts `Selector.ListAvailable`, `RefreshCooldowns(button)` repaints swipes (unprotected, so live in combat). `MAX_ENTRIES` bounds the pool. Closing has three paths, all funnelling through `Close(flyout)`: the secure `_onleave` (the only combat-safe one), a `PostClick` hook on the slot and on every entry, and an idle `C_Timer` (`flyoutAutoClose`). The last two are insecure Lua and stand down in combat. See [macro-bar.md](./macro-bar.md). |
| `modules/MacroBar.lua` | The optional CM-only bar container. `Update()` is the single apply seam (defers wholesale to `PLAYER_REGEN_ENABLED` via `FlushPending`, since slots are protected frames); `SetEnabled / SetLocked / ResetPosition / SwapSlots / Refresh / RefreshCooldowns / ApplyEnabled / ApplyLock / FlushPending`. Combat-conditional visibility goes to `RegisterStateDriver`, never `Show`/`Hide`. Owns the sole `MACROBAR_REFRESH` receiver. See [macro-bar.md](./macro-bar.md). |

### AceGUI custom widgets

Also under `modules/`. Loaded between `MacroManager` / `DebugLog` and `settings/`. Each file calls `AceGUI:RegisterWidgetType` at the bottom; the tab builders acquire instances via `AceGUI:Create("KCM…")` at render time.

| File | Purpose |
|------|---------|
| `modules/KCMItemRow.lua` | Priority-list row: status glyphs (green check / red / yellow star) + item icon + name + quality tier. Hover renders the real in-game item or spell tooltip (forks on `KCM.ID.IsSpell`). Spell name via `KCM.Compat`. |
| `modules/KCMIconButton.lua` | Gold-hover icon button used for ↑ / ↓ / ×. |
| `modules/KCMScoreButton.lua` | The blue "i" info button. Hover renders the per-item `Ranker.Explain` breakdown. No-op `SetLabel` so the caller can pass an arbitrary tooltip-title string without rendering a text label under the icon. |
| `modules/KCMMacroDragIcon.lua` | Pickable macro icon at the top of each category page. Icon + tooltip come from `core/MacroDisplay.lua` — pick-first, because the stored `?` sentinel is meaningless on a static UI widget. |

### settings/

Each tab module registers a builder via `KCM.Settings.RegisterTab(key, builder)`; `settings/Panel.lua`'s bootstrap iterates `KCM.Settings.order` and calls each builder once Blizzard_Settings is ready. Bodies are hand-built AceGUI widget trees inside a `Helpers.CreatePanel` canvas — no AceConfigDialog.

| File | Responsibility |
|------|----------------|
| `settings/OptionsSetup.lua` | The `LibKa0s-Options-1.0` seam, and the only place the library is constructed (`options-ui-§1`). Resolves the major in silent mode, builds the instance with this addon's conventions taught to it (positional `{r,g,b,a}` colour codec, `sliderCommit = "change"` for the Macro Bar's live drag preview, a call-time LibSharedMedia thunk, a `print` thunk onto `KCM.Say`, and `get`/`set` thunks onto `Helpers.Get` / `Helpers.SetAndRefresh`), installs it as `KCM.Settings.Helpers`' `__index` and publishes it as `Helpers.instance` + `KCM.Settings.optionsUI`. Creates `KCM.Settings.Helpers` and publishes `KCM.Settings.PANEL_TITLE`. With the major (or AceGUI) absent it builds nothing and installs the two unconditional refresh tiers, `RefreshAllPanels` / `RefreshScalars`, as real no-ops — both are called on paths a degraded install still reaches. |
| `settings/Panel.lua` | Framework, and the addon's half of `LibKa0s-Options-1.0`. The seam itself lives in `settings/OptionsSetup.lua`, which loads immediately before this file; what is read back here is `KCM.Settings.optionsUI`, `ensureScroll` and `libAbsent`. The chrome is the library's — the lazy AceGUI ScrollFrame and the always-visible scrollbar gutter (`Helpers.EnsureScroll` / `PatchAlwaysShowScrollbar` are forwarders onto `Helpers.instance`) — while the schema half stays here. `Helpers.CreatePanel` (gold title + atlas divider + body), `Section` / `Button` / `ButtonPair` / `Label` builders. The row widget makers, `RenderField`, `SetRenderer` and both refresh tiers are the library's too, once [LIBKA0S-04](https://github.com/tusharsaxena/ConsumableMaster/issues/22)/-05 were fixed upstream; what stays here is the schema itself, the `Resolve` → `SetAndRefresh` write seam, `Grid`, the buttons, `EnumValues` / `LSMValues`, the page registry order and the `KCM.Options` shim. `CreatePanel` also carries the Blizzard canvas contract the library stamps as of Options minor 5 — `OnCommit` / `OnRefresh` / `OnDefault`, which is what makes the Settings window's own **footer** Defaults control work (a different widget from this addon's header Defaults button, and not per-page). With LibKa0s absent no panel is registered at all and `KCM.Options.Open()` answers `false`; the schema half above the seam survives, but the CLI that reads it is the library's too, so `/cm list|get|set` is unavailable in that state as well. Owns the `KCM.Settings.Schema` array, `Helpers.SetAndRefresh` (the validate → write → onChange → refresh seam, published as `KCM.Schema:Set`), `Helpers.Resolve / Get / Set / FindSchema / ValidateSchema / ValidateSchemaValue`, and the two refresh paths — `RefreshAllPanels` (structural rebuild) and `RefreshScalars` (in-place widget re-sync, options-ui-§11). Hosts the parent (About) canvas via `BuildAboutContent`, whose command rows come back already rendered from `KCM.SlashCommands.GetLandingRows()` rather than being formatted here (LIBKA0S-13). Publishes the `KCM.Options.{Register,Refresh,RequestRefresh,Open}` shim that Core / Debug / `settings/Slash.lua` / Pipeline call. |
| `settings/General.lua` | General tab. Section "General" — the `[Enable]` schema-driven checkbox + a `[Debug console]` checkbox that shows/hides the on-screen console window only (never the session debug flag), mirroring a bare `/cm debug`. Section "Maintenance" — row 1 paired `[Force resync \| Force rewrite]` buttons, row 2 full-width `[Reset all priorities]` (StaticPopup-confirmed via `KCM_RESET_ALL`). |
| `settings/MacroBar.lua` | Macro Bar tab. Registers every `macroBar.*` schema row (defaults sourced from `KCM.dbDefaults`, so each is simultaneously a widget here and a `/cm set macroBar.<field>` path) across eight sections — Bar, Layout, Bar appearance, Button appearance, Labels, Flyout, Visibility, and a per-macro checkbox grid over `macroBar.shown`. The two border-style rows carry `lsm = "border"` so they render as `LSM30_Border` pickers. Buttons: Reset position, Reset slot order, and a page Defaults action that restores the whole `macroBar` table. |
| `settings/StatPriority.lua` | Stat Priority tab: full-width spec dropdown (class+spec icon markup), Primary alone in a half-row, Secondary 1\|2 + 3\|4 paired half-rows, inline Reset. Owns `KCM.Options._viewedSpec` + `O.ResolveViewedSpec` + `O.FormatSpec`. |
| `settings/Category.lua` | Per-category tabs (single + composite). One builder per row in `KCM.Categories.LIST`. Single dispatch: drag icon → Add-by-ID (Type \| ID input) → Priority list rows (KCMItemRow + KCMScoreButton + ↑/↓/× buttons) → inline Reset. Composite dispatch: drag icon → In Combat / Out of Combat sections (each row: KCMItemRow + Enabled checkbox + ↑/↓) → inline Reset. Shared `KCM_RESET_CATEGORY` StaticPopup. |

### defaults/

| File | Populates | Purpose |
|------|-----------|---------|
| `defaults/Profile.lua` | `KCM.dbDefaults` | The AceDB defaults tree, and THE declaration site for every shipped default value (`savedvariables-§2`): the `global.schemaVersion` seed, `profile.enabled`, the per-category buckets, `statPriority` / `macroState`, and the whole `macroBar` table. Schema rows, page fallbacks and migrations all read through it rather than restating a literal. First in the TOC's `# Defaults` block. |
| `defaults/Categories.lua` | `KCM.Categories.LIST` + `KCM.Categories.BY_KEY` + `Get(key)` | Category metadata: macro name, displayName, shortName (abbreviation for macro-bar button labels), specAware, classifier/ranker keys. Composite rows carry `composite=true` + `components = { inCombat={...}, outOfCombat={...} }`. |
| `defaults/Defaults_StatPriority.lua` | `KCM.SEED.STAT_PRIORITY` | Primary + ordered secondary stats per `<classID>_<specID>`. |
| `defaults/Defaults_<CAT>.lua` | `KCM.SEED.<CATKEY>` | Seed item / spell IDs per category. Spell entries use `KCM.ID.AsSpell(spellID)`. Composite categories have no seed file. |
| `defaults/README.md` | — | Seed file map + category scope decisions + refresh procedure. See [../defaults/README.md](../defaults/README.md). |

### locales/

| File | Responsibility |
|------|----------------|
| `locales/enUS.lua` | Publishes `KCM.L`, a key-returning metatable. User-facing strings (panel labels, slash descriptions, popup text) go through `L[...]`. English is the only shipped locale — this is a shell, not localization plumbing. |

### Shared infrastructure

- `libs/` — vendored Ace3 + LibStub + LibSharedMedia, tracked in git (standard WoW addon practice). Loaded before any addon source by the `# Libraries` block of `ConsumableMaster.toc`, which lists each library file directly (no `embeds.xml` wrapper — toc-file-§4).
- `ConsumableMaster.toc` — Interface line (`120007`), version, SavedVariables, file load order. Sectioned `# Libraries / Locales / Core / Defaults / Modules / Settings`; order within a section is dependency order, not alphabetical.
- `tests/` — headless harness (`lua5.1 tests/run.lua`; suite inventory in [test-cases.md](./test-cases.md)) over the addon's logic layer; `wow_mock.lua` stubs the WoW API + bus.

### Top-level docs

- `README.md` — user-facing. Its `## What's new` section and `## Version History` table are this addon's only release history (`documentation-§1` forbids a root `CHANGELOG.md`).
- `CLAUDE.md` — stub (standard link + hard rules + gate + pointer into `docs/`).
- `DEPENDENCIES.md` — what to install to build, run, test or release this addon, with a verification command per tool (`documentation-§7`). Answers *what to install*; `docs/testing.md` answers *how to verify*.
- `docs/ARCHITECTURE.md` — design overview + invariants + message-bus catalog + LibKa0s adoption + doc index.
- `docs/*.md` — topic chunks (this file is one of them). `docs/test-cases.md` and `docs/automated-tests/RESULTS.md` are **generated** — never hand-edit either.
</content>
