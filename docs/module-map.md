# Module map

Per-module roles + public APIs. Pair this with [data-flow.md](./data-flow.md) for how the modules talk to each other.

```
core/Namespace.lua ── Loads first. Names the private namespace (NS.name) and
                   KCM.VERSION; every other file picks the table up via
                   `local _, NS = ...`.

core/LifecycleSetup.lua ── The addon's half of LibKa0s-Lifecycle-1.0: ONE
                   latch, two named holds (`disabled` from the stored enable
                   path, `perf` from the capture harness), one standDown and
                   one standUp. Loads right after core/Namespace.lua in
                   # Core, ahead of PerfSetup,
                   which requires the instance as descriptor.lifecycle.
                   Publishes KCM.Lifecycle, KCM.IsStoodDown,
                   KCM.IsAddonDisabled, KCM.OnEnabledChanged and
                   KCM.ReevaluateEnabled. standDown unregisters every event
                   and every bus message the addon owns, disarms the
                   coalescer, and lets the bar's own show ladder hide it;
                   standUp re-runs KCM:OnEnable, runs login's discovery
                   pass and stale sweep (Pipeline.DiscoverAndSweep) and
                   rebuilds from the settings AS THEY ARE NOW. Absent major -> absent feature
                   and no stub. See ARCHITECTURE.md, "The disabled state is
                   total".

core/PerfSetup.lua  The addon's half of LibKa0s-Perf-1.0 + its panel.
                   Publishes KCM.Perf — the instance ITSELF, not a facade,
                   because the brackets read .on / .run / .suspended as plain
                   boolean fields the library writes. Supplies /cm as the
                   taught command, ConsumableMasterPerfDB as the capture ring,
                   the run-log sink (DebugLog.AddLine, the UNGATED append) and
                   the LATCH (descriptor.lifecycle; the suspend/resume pair it
                   used to carry is core/LifecycleSetup.lua's standDown /
                   standUp now, reached by the disabled arm too).
                   Two buckets instrumented:
                   `cooldown` (MacroBar.RefreshCooldowns) and `recompute`
                   (Pipeline.Recompute). Absent major -> absent feature and
                   no stub; the two bracket sites take their upvalue
                   nil-tolerantly. Loads in # Core after
                   core/LifecycleSetup.lua (performance-§1: ahead of every
                   load-time `local Perf = NS.Perf`).

core/ConsumableMaster.lua ── AceAddon entry (AceAddon:NewAddon(NS, ...)).
                   OnInitialize creates the DB; Pipeline.Recompute /
                   RequestRecompute orchestrate every recompute; event
                   handlers publish RECOMPUTE onto the bus. Also houses
                   KCM.ID sentinel helpers (AsSpell / IsSpell / IsItem /
                   SpellID / ItemID) and KCM.ResetAllToDefaults.
                   KCM.dbDefaults is NOT here — it is defaults/Profile.lua's.

core/Bus.lua ───── Closed message bus. KCM.bus (AceEvent embed),
                   KCM.NewBusTarget(), KCM.MSG.{RECOMPUTE, PANEL_REFRESH,
                   SPEC_CHANGED, MACROBAR_REFRESH, PROFILE_CHANGED}. Each
                   receiver owns its own target, tracked by the
                   LibKa0s-Bus-1.0 stand-down record (KCM.busRecord);
                   KCM.MSG is the major's strict Catalog.

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

core/Compat.lua ── Spec, spell and item API seam. GetSpecialization /
                   GetSpecializationInfo / GetSpellName / IsSecret are
                   LibKa0s-Compat-1.0's members, bound onto KCM.Compat;
                   GetNumSpecializationsForClassID /
                   GetSpecializationInfoForClassID / GetItemInfo stay host
                   code (see compat-layer.md). IsSecret
                   lets a gate over client data ask before it compares.

core/State.lua ─── Session-only runtime flags. KCM.State.debug (default off,
                   never persisted, resets each login).

core/Database.lua  RunMigrations() — runs right after AceDB:New and again on
                   every profile switch; owns both schemaVersion stamps
                   (db.global's, and each profile's own).

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
                   settings panel's drag icon. Writes no macro; its one
                   protected call is Pickup, which refuses in combat.

core/MacroBarModel.lua  Pure slot bookkeeping for the macro bar. AllKeys /
                   NormalizeOrder / ResolveVisibility / IndexOf / Swap /
                   VisibleKeys, plus the db-backed Config / IsEnabled / Order /
                   Visible / MacroName / KeyForMacroName wrappers.
                   ResolveVisibility intersects the addon-wide General
                   visibility with the bar's own Combat visibility.

core/MacroBarLayout.lua  Pure geometry. Grid(count, cfg) -> positions +
                   width/height/cols/rows; Dimensions(count, cfg);
                   LabelAnchor(cfg) -> point/relPoint/x/y/justifyH over the
                   LABEL_POINTS 9-way grid; LabelFontSize(size, scalePct).
                   No frames, no db reads.

core/SpecHelper.lua  Class/spec identity. Spec keys are "<classID>_<specID>".
                   GetStatPriority merges user override → seed → class fallback.

core/TooltipCache.lua  C_TooltipInfo.GetItemByID(id) → parsed struct cached per
                   session. Invalidate(id) on GET_ITEM_INFO_RECEIVED.
                   Parser handles NBSP + |4singular:plural; grammar escapes,
                   captures healOverSec / manaOverSec so the Ranker can
                   tell immediate pots from heal-over-time pots.

core/WeaponSlots.lua  equipped main-hand (16) / off-hand (17) weapon subClassID
                   (gated on classID == Weapon) → "bladed" (whetstone) /
                   "blunt" (weightstone) / "other" (a weapon that takes no
                   stone: bow, gun, wand — oils only) / nil (no weapon in
                   the slot). Numeric =
                   locale-independent. Drives the per-hand Weapon Enchant picks.

core/BagScanner.lua  C_Container.GetContainerItemInfo sweep → { [id] = count }.
                   Stateless per-call.

core/Classifier.lua  (itemID) → which of the 11 single-pick categories. Reads
                   the numeric classID/subClassID (locale-independent) + parsed
                   tooltip. FLASK is subclass-only (tooltip-free) so first-bag-
                   scan discovery is deterministic for already-cached flasks.

core/MediaSetup.lua  The LibKa0s-Media-1.0 seam. Publishes KCM.Icon and
                   KCM.MediaFont over the vendored payload's art and face, and
                   makes the one LibSharedMedia registration. TOC position is
                   load-bearing: DebugLogSetup resolves its font at load.

core/EnvSetup.lua  The LibKa0s-Env-1.0 seam. Publishes KCM.Meta(field) and
                   KCM.Version() over the addon's own TOC manifest, binding
                   addonName so no caller types the folder name again. TOC
                   position is conventional -- nothing resolves at load.

core/ItemSetup.lua  The LibKa0s-Item-1.0 seam. Publishes KCM.Item with the
                   one primitive this addon consumes, ItemIDFromLink, for the
                   Add-by-ID box's pasted-link path. Degrades to the same
                   primitive in three lines, so a link never resolves on one
                   install and not another.

core/DebugLogSetup.lua  The addon's half of LibKa0s-DebugLog-1.0: resolves the
                   console's font through KCM.MediaFont (Blizzard ARIALN
                   fallback), passes addonName so the title bars draw the
                   collection's marks, and builds ONE console instance
                   (ConsumableMasterDebugWindow)
                   over the KCM.State.debug flag, the KCM.Say printer, the
                   [Init] summary and the options repaint. Publishes the flat
                   DL.SetEnabled / IsEnabled / Toggle / AddLine / Show / Hide /
                   Toggle_Window / ShowCopy / RunDiagnostics forwarders +
                   DL.FormatPlain /
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
                   items, IsPlayerSpell for spell sentinels. MoveTo and
                   MoveCompositeRef are the two move-to mutators the panel's
                   drags call, each one splice and one re-render.

modules/MacroManager.lua  The ONLY module that calls CreateMacro / EditMacro.
                   SetMacro for single picks, SetWeaponEnchantMacro for the
                   per-hand WPN_ENCH body, SetCompositeMacro for HP_AIO and
                   MP_AIO. Combat-deferral queue, fingerprint cache,
                   bounded flush retry, action-bar icon convention.
                   Detail in macro-manager.md.

settings/         Settings UI framework + one module per page.
├── Panel.lua            The addon's half of LibKa0s-Options-1.0. The chrome
│                        is the library's — panel factory + header/breadcrumb,
│                        the lazy Defaults button, the scroll container and the
│                        always-visible scrollbar gutter, plus tooltip / spacer
│                        / section / session-checkbox — reached through thin
│                        Helpers.* forwarders onto Helpers.instance. The schema
│                        half stays here: Settings.Schema, the SetAndRefresh
│                        → Helpers.schema write seam, Grid / Button / ButtonPair /
│                        Label, EnumValues, the page order and
│                        KCM.Options.Register. RenderField, the four row widget
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
├── OptionsShim.lua      The RUN-time half of the KCM.Options shim, peeled off
│                        Panel.lua at the 1500-line cap: Refresh,
│                        RequestRefresh, Open, the trailing-edge refresh
│                        debounce behind RequestRefresh, and the three bus
│                        receivers (PANEL_REFRESH, PROFILE_CHANGED,
│                        SPEC_CHANGED) that drive them. Loads immediately after
│                        Panel.lua, whose Helpers, optionsUI instance and two
│                        notice functions it takes as file-scope locals.
├── General.lua          A 2-tab strip: Master controls (the canonical eight,
│                        COMPOSED, options-ui-§15) and Maintenance (resync,
│                        rewrite, reset-all-priorities).
├── MacroBar.lua         The Macro Bar page: an 8-tab strip over the 64
│                        macroBar.* schema rows; the Buttons tab draws its two
│                        whole-value rows (order, shown) as one draggable list.
│                        Its border, background and font blocks are composed.
├── StatPriority.lua     The viewed-spec picker as the page BANNER
│                        (options-ui-§14), then a ONE-TAB strip over the primary
│                        stat and the four secondaries as a draggable list.
├── Category.lua         The Macros page: a 15-tab strip GENERATED from
│                        Categories.LIST in KCM.Settings.macroOrder, one tab per
│                        category. Dispatches to single (Add-by-ID + Priority
│                        list) or composite (In Combat / Out of Combat)
│                        rendering. It was one sub-page per category until the
│                        strip replaced them.
├── CategoryAddByID.lua  The single tab's "Add item or spell by ID" section,
│                        peeled off Category.lua at the 1500-line cap: the Type
│                        dropdown, the two ID KINDS behind it, this addon's
│                        resolver over LibKa0s-Options-1.0's IdInput, the
│                        candidate set, the Selector.AddItem writer and
│                        O.AddByIDBusy. Borrows Category.lua's newRow and
│                        afterMutation off KCM.Settings.MacrosPage; publishes
│                        KCM.Settings.AddByID.Render, which Category.lua calls
│                        while it renders a tab.
└── Profiles.lua         The Profiles page: AceDBOptions' own table, drawn by
                         AceConfigDialog (the one AceConfig use, options-ui-§3).
                         No rows, no strip, no Defaults button; last in the
                         sidebar and the TOC. See profiles.md.

core/SlashDump.lua  The /cm dump <target> diagnostics namespace: DUMP_TARGETS,
                   DUMP_ORDER and the dump dispatcher. A leaf — it reads only
                   KCM.Say and addon state, no slash parsing helpers — so it
                   loads FIRST of the three. Published as KCM.SlashDump,
                   with EventStates() for the diagnostics report.

core/SlashCommands.lua  The slash VERB BODIES: the priority / stat / aio / bar
                   namespaces and their *_COMMANDS tables, the shared parsing
                   helpers, KCM.FormatSchemaValue, and the KCM_CONFIRM_RESET
                   popup raised by /cm resetall. Publishes five entry points on
                   KCM.SlashCommands.Verbs and knows nothing about how they are
                   dispatched. The file-local say is an alias of the shared seam
                   (local say = KCM.Say), so every slash line inherits the [CM]
                   tag and secret-safe stringification.

core/Diagnostics.lua  The diagnostics report's sections (debug-logging-§14,
                   DX-CM): state, settings, spec, categories, weapon enchant,
                   macros, macro bar, tooltip cache, bags, events. Read-only;
                   KCM.Diagnostics.Sections() is handed to LibKa0s-DebugLog-1.0
                   at run time by core/DebugLogSetup.lua's descriptor.

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
KCM.Pipeline.DiscoverAndSweep(reason)        -- RunAutoDiscovery, then Selector.SweepStaleDiscovered;
                                             --   login (PEW) and the stand-up both run it

-- Pure debug-summary formatter (frame-free, unit-tested; see debug.md)
KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped) -> string -- [Calc] line

-- Sentinel helpers (also see schema.md)
KCM.ID.AsSpell(spellID)  -> negative
KCM.ID.IsSpell(id)       -> bool
KCM.ID.IsItem(id)        -> bool
KCM.ID.SpellID(id)       -> spellID | nil

-- Centralized reset
KCM.ResetAllToDefaults(reason) -> true | false, "combat" | "db"
                                             -- session sweep + db:ResetProfile() + panel
                                             --   repaint; refused in combat before any write
```

### Bus (`core/Bus.lua`)

```lua
KCM.bus                          -- AceEvent-3.0 embed (SendMessage / RegisterMessage)
KCM.NewBusTarget([subscribe]) -> target -- a tracked AceEvent-embed table; one per receiver
KCM.Bus.StandDown() / StandUp()  -- the latch's bus half, delegating to KCM.busRecord (LibKa0s-Bus-1.0)
KCM.MSG.RECOMPUTE                -- event/UI → pipeline (→ RequestRecompute, coalesced)
KCM.MSG.PANEL_REFRESH            -- pipeline → options panel (debounced rebuild)
KCM.MSG.SPEC_CHANGED             -- spec change → options panel (retracks Stat Priority)
KCM.MSG.MACROBAR_REFRESH         -- pipeline → macro bar (undebounced icon/count repaint)
KCM.MSG.PROFILE_CHANGED          -- profile handler → macro bar (Update), options panel, Profiles page
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
KCM.Selector.ResetBucket(catKey, specKey?)             -> reset:bool     -- added/blocked/pins; keeps discovered
KCM.Selector.ResetAllBuckets()                         -> reset:bool     -- every bucket, bySpec included
KCM.Selector.MarkDiscovered(catKey, id, specKey?, nowUnix) -> changed:bool   -- items only
KCM.Selector.SweepStaleDiscovered(nowUnix) -> swept, touchedCats  -- 30-day TTL, PEW and stand-up only
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
KCM.TooltipCache.Snapshot() -> { total, pending, unsupported, pendingIds }  -- read-only, fetches nothing
```

`pending` also covers the partial-tooltip case: a Consumable whose parse yields no recognizable effect (no heal/mana/stat/duration, not a weapon enhance, not an augment rune) stays pending rather than caching as final, because `GET_ITEM_INFO_RECEIVED` does not re-fire for an item whose basic info was already cached. `unsupported` marks the build where `C_TooltipInfo.GetItemByID` is missing entirely.

If `C_TooltipInfo.GetItemByID` returns nil or empty, the cache marks the id `pending`. The first `GET_ITEM_INFO_RECEIVED` for that id invalidates the entry and triggers a recompute (for bag items only — see [data-flow.md GIIR split](./data-flow.md#giir-bagnon-bag-split)).

### WeaponSlots (`core/WeaponSlots.lua`)

```lua
KCM.WeaponSlots.SlotAffinity(slot) -> "bladed" | "blunt" | "other" | nil  -- slot 16 (main) / 17 (off)
                                   -- "other" = a weapon that takes no stone (bow, gun, wand):
                                   -- oils apply, stones do not. nil = no weapon in the slot.
```

Reads the equipped weapon's numeric `subClassID`, gated on `classID == Weapon` so a shield or an off-hand frill never reads as enhanceable. Numeric = locale-independent. **`nil` means one thing only: no weapon in that slot.** A weapon in neither stone table answers `"other"` — a bow, gun, crossbow or wand takes no whetstone and no weightstone, but an oil (`weaponAffinity == "any"`) applies to it exactly as it does to a sword. Until 2026-09-11 those two answers were the same `nil` and `PickBestForSlot` read it as the first, so every hunter got the empty-state macro while holding a picked oil. Consumed by `Selector.PickBestForSlot` and by `settings/Category.lua`'s WPN_ENCH page header.

### SpecHelper (`core/SpecHelper.lua`)

```lua
KCM.SpecHelper.GetCurrent() -> classID, specID, specKey, specName
KCM.SpecHelper.MakeKey(classID, specID) -> "<classID>_<specID>"
KCM.SpecHelper.AllSpecs() -> { { classID, specID, specKey, specName }, ... }
KCM.SpecHelper.GetStatPriority(specKey) -> { primary, secondary = { ... } }
KCM.SpecHelper.WithStatPriority(specKey, entry|nil) -> the whole statPriority map, one spec replaced (pure)
```

`GetStatPriority` merges in this order: user override (`db.profile.statPriority[specKey]`) → seed default (`KCM.SEED.STAT_PRIORITY[specKey]`) → class-primary fallback. `statPriority` is a whole-value schema row, so it is never written in place. `WithStatPriority(specKey, entry)` answers the whole map with one spec's override replaced (or dropped, for a nil entry) and writes nothing. Every writer hands that map to `KCM.Schema:Set("statPriority", …)`: the Stat Priority page's `writeStatPriority` and Defaults, `/cm stat primary|secondary|reset`, and Reset all priorities. Spec + spell lookups route through `KCM.Compat`.

### Settings panel (`settings/Panel.lua` + `settings/OptionsShim.lua` + per-page modules)

```lua
-- Lifecycle (preserved API; called by Core / Debug / SlashCommands / Pipeline)
KCM.Settings.Register()      -- = the file-local registerPanel; the PLAYER_LOGIN /
                             --   ADDON_LOADED bootstrap calls registerPanel directly,
                             --   so this is the named alias, not the live call path
-- Everything on KCM.Options below Register is settings/OptionsShim.lua's; the
-- schema, the chrome and Register itself are settings/Panel.lua's.
KCM.Options.Open()           -- UI.OpenOptionsPanel(): the parent About canvas, sub-pages
                             --   force-expanded; false in combat (the library refuses)
KCM.Options.MacroTabs()      -- the Macros strip: { { key, label, tooltip }, ... }
KCM.Options.SetMacroTab(key) -> bool  -- select a category tab from outside the strip

-- Refresh
KCM.Options.Refresh()        -- immediate: re-render every shown panel
KCM.Options.RequestRefresh() -- trailing-edge debounced (1.0s quiet, 3.0s hard cap; one timer per burst)

-- Schema layer
KCM.Settings.Schema          -- ordered list of {panel, section, group, path, type, label, default, apply?}
KCM.Settings.RegisterTab(key, builder)            -- per-page module entry point
KCM.Settings.order           -- { "general", "macros", "statpriority", "macrobar" }
KCM.Settings.macroOrder      -- the Macros strip's tab order: { "food", ..., "battle_rez" }
KCM.Settings.MACROBAR_TABS   -- the Macro Bar strip: { { group, label, draw }, ... }
KCM.Schema:Set(path, value) -> bool               -- unified validate → normalize → store → apply → refresh seam
KCM.Settings.Helpers.schema  -- the LibKa0s-Schema-1.0 instance (KCM.SchemaStub's when the library is absent)
KCM.Settings.Helpers.Get(path) -> value           -- schema.Get
KCM.Settings.Helpers.Set(path, value) -> true | false, err, why  -- schema.Set, prints nothing
KCM.Settings.Helpers.AddRows(list) / AddRow(row)  -- stamp the type rules and index the rows
KCM.Settings.Helpers.FindSchema(path) -> row | nil
KCM.Settings.Helpers.ValidateSchema() -> errorCount
KCM.Settings.Helpers.ValidateSchemaValue(def, value) -> coerced | nil, reason  -- a read of TYPE_RULES, no write
KCM.Settings.Helpers.SetAndRefresh(path, value) -> bool  -- the mutation seam KCM.Schema:Set wraps
KCM.Settings.Helpers.RefreshAllPanels()   -- structural: re-render the shown page, flag the rest dirty
KCM.Settings.Helpers.RefreshScalars()     -- scalar: re-sync widgets in place, no rebuild (options-ui-§11)

-- Panel-build helpers (called by per-page modules). AttachTooltip / AddSpacer /
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

It arms **one timer per burst**, not one per call: the first request schedules `onRefreshDue`, every request after it only stamps the clock, and the one live timer re-arms itself for whatever quiet is still owed. `REFRESH_MAX_WAIT_SEC` is a hard bound on the whole wait rather than on any single timer's delay, so a storm that never goes quiet still rebuilds at three seconds. `tests/perf.lua`'s `refreshBurst` scenario measures the 150-call burst — one timer, zero bytes — and `tests/test_settingsui.lua` pins the behavior.

While the Macros page's Add-by-ID box has focus or holds text (`O.AddByIDBusy`, `settings/CategoryAddByID.lua`), `onRefreshDue` holds the rebuild and asks again a quiet second later as a fresh window. The line's own pre-warm and name lookup produce the very `GET_ITEM_INFO_RECEIVED` events this path rebuilds on, and a rebuild releases the box: the library's `OnRelease` drops a pending name lookup and clears the text, with no word on the status line. A stalled timer (the harness's inline `C_Timer`) is not held. `tests/test_addbyid.lua` pins the hold.

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
KCM.MacroBarFlyout.StandDown() / StandUp()         -- kcmCombat drivers off / on (MB.Update)
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
                                              --   DebugLog.SetEnabled is the single write path (debug-logging-§5)

KCM.DebugLog.SetEnabled(on) / IsEnabled() / Toggle()   -- Toggle flips the flag
KCM.DebugLog.AddLine(tag, msg) / Clear()
KCM.DebugLog.Show() / Hide() / Toggle_Window() / IsWindowShown() / ShowCopy()
KCM.DebugLog.RefreshHeader() / UpdateScrollBar() / UpdateStatus()   -- header, scrollbar + line counter (debug-logging-§11)
KCM.DebugLog.RunDiagnostics(spec) -> n                -- the debug-logging-§14 report; the stub prints one line, returns 0
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

## LibKa0s adoption

Moved here from [ARCHITECTURE.md](./ARCHITECTURE.md#libka0s-adoption), which keeps the summary.

Each major is adopted by the same shape: one host **setup file** resolves what only the addon can
know, builds ONE instance via `lib:New(descriptor)`, publishes the addon's existing **flat,
dot-callable** names as thin forwarders onto that instance, publishes the instance itself as
`.instance` for identity assertions, and carries a degradation stub for a missing library.

| Major | Host half | What the addon keeps |
|---|---|---|
| `Core-1.0` | `core/CoreSetup.lua` | `KCM.PREFIX` (read live via a prefix *function*, never captured), the `print` sink the harness listens on, and `KCM.SwatchColor` — the one wrapper over `lib.RGBA` + `lib.ResolveColor` that teaches the library this addon's positional `{ r, g, b, a }` shape and each surface's own four-channel fallback (`options-ui-§17`) |
| `DebugLog-1.0` | `core/DebugLogSetup.lua` | the shipped font, `KCM.State.debug` as the flag's single home, the `[Init]` content, the panel repaints |
| `Slash-1.0` | `settings/Slash.lua` | the `COMMANDS` table and the `STRINGS` overrides that keep this addon's shipped wording (both passed in, never owned). The verb bodies and their `*_COMMANDS` namespaces stay in `core/SlashCommands.lua`, the `/cm dump` targets in `core/SlashDump.lua`, and the `KCM_CONFIRM_RESET` popup with the verbs (CM-47). |
| `Options-1.0` | `settings/OptionsSetup.lua` (the seam) + `settings/Panel.lua` (the addon's half) | the schema rows and the `SetAndRefresh` / `SetManyAndRefresh` doors (the write seam behind them is `Schema-1.0`'s, the next row), `Grid` / `Button` / `ButtonPair` / `Label`, `EnumValues` (`LSMValues` was host-owned beside it until `M4-C1`; it is the library's outright now), `RegisterRows` (which stamps `panel`, `section` and this addon's `apply` onto a composed block, then the type rules), the page order (`KCM.Settings.order`, five pages, Profiles last) and the Macros strip's tab order (`KCM.Settings.macroOrder`, fifteen categories), the `KCM.Options` shim — `Register` here, and the run-time `Refresh` / `RequestRefresh` / `Open` plus the refresh debounce in `settings/OptionsShim.lua`, peeled off at the 1500-line cap; `Register` and `Open` delegate to the library's `CreateOptionsPanel` (fed through `RegisterOptionsPage` in the page order, with the descriptor's `buildMain` and `validate`) and `OpenOptionsPanel`, which own the category, its combat park and replay, the open's combat refusal and the sidebar expand — and the two reset vetoes `KCM.Settings.VetoedFromResetAll` — which the seam publishes and hands to the library as its descriptor's `skipRestoreAll` (`options-ui-§3`) — and `KCM.Settings.VetoedFromEveryReset`, the one-row carve-out `launcher-§3` requires: it reads a row's `neverReset` stamp, the global veto asks it first, and `settings/General.lua`'s page `Defaults` walk asks it too, so a player's minimap-button choice survives **both** resets. The tab strip (`options-ui-§13`) and the tabbed page `RenderTabbedSchema` behind the General page (its descriptor `rowsForPage` answers the rows whose `panel` is the page key), the page banner (`options-ui-§14`), the row engine `RenderRows`, the id line `IdInput` behind a category tab's Add-by-ID (minor 16; this addon hands it a host kind whose `resolve` calls the library's `ResolveId` for names, the category's `Selector.BuildCandidateSet` IDs, plus the items in the bags under Type=Item, as `candidates` for those names and the as-you-type suggestions, and names its ids' library kind as `base` — `"item"` or `"spell"` per Type — so the rows wear the tier icon, quality color or subtext while this addon's resolver still decides what is added; it keeps its own rows) and the four **composers** — `MasterControls`, `ColorPair`, `BorderGroup`, `FontGroup` (`options-ui-§15`–`options-ui-§17`) — are the library's, called by the page files |
| `Schema-1.0` | `settings/Panel.lua` (the instance, published as `Helpers.schema`) + `settings/SchemaStub.lua` (the degradation stub, `KCM.SchemaStub`) | the rows and their `TYPE_RULES` (each type split into `validate` and `normalize`, stamped onto the row by `AddRows` / `RegisterRows`), the descriptor's `resolveRoot` (`db.profile`), `announce` / `announceBatch` (a row's host `apply` run through the `onChange for <path> failed` reporter, then one refresh; a batch runs the caller's reactor or each distinct `apply` once), the `[Set]` formatter, `resetExempt` built from the `neverReset` rows, and the two rows with a store of their own (`state.debugConsole`, `global.minimap.shown`, stamped in `settings/General.lua`; the minimap row's path says *shown* while its store key is still LibDBIcon's `db.global.minimap.hide`, which its get/set invert onto, anti-pattern #81). The library owns the path walk, the index, the pipeline, `SetMany`, the bulk bracket and the profile reset's count. Adopted at v1.56.0 ([#39](https://github.com/tusharsaxena/ConsumableMaster/issues/39)): an unknown path is refused rather than stored, a table value is copied into the store, and the `[Set]` line is written before the reaction ([schema.md](./schema.md#the-write-seam)) |
| `Lifecycle-1.0` | `core/LifecycleSetup.lua` | what "inert" MEANS for this addon — the `standDown` / `standUp` pair — and nothing else. The library owns no frames, no events, no settings and no storage; what it knows is whether the hold set is empty. The two holds are `disabled` (from the stored `enabled` path) and `perf` (taken by `Perf-1.0` itself, never by the host). There is no `:StandUp()` member and its absence is the point |
| `Perf-1.0` | `core/PerfSetup.lua` | `/cm` as the taught command, `ConsumableMasterPerfDB` as the capture ring, and the three sinks. The `suspend`/`resume` pair it used to carry moved to `Lifecycle-1.0`'s latch at Perf minor 12, which requires `descriptor.lifecycle` — a second teardown path beside the disable arm is the anti-pattern, not an implementation detail |
| `Media-1.0` | `core/MediaSetup.lua` | this addon's folder name (a vendored library cannot work out which folder it was copied into) and the one `Media.RegisterLSM` call, made at file load. Publishes `KCM.Icon` / `KCM.MediaFont`; its TOC position is load-bearing, because `core/DebugLogSetup.lua` resolves the console font eagerly |
| `Env-1.0` | `core/EnvSetup.lua` | `addonName` again, and the degradation path — an install without LibKa0s repeats the two `C_AddOns` ladders this seam replaced. Publishes `KCM.Meta(field)` and `KCM.Version()` (`/cm version`, the About page's notes) |
| `Compat-1.0` | `core/Compat.lua` | the call surface `KCM.Compat.X`, which did not move: four members are the library's (`GetSpecialization`, `GetSpecializationInfo`, `GetSpellName`, `IsSecret`) and three stay host code because the major does not carry them (`GetNumSpecializationsForClassID`, `GetSpecializationInfoForClassID`, `GetItemInfo`), documented in [compat-layer.md](./compat-layer.md). No instance: the major is stateless. With it absent each wired reader answers `nil` (the API document's *reader arm*) and `IsSecret` re-implements its one-rung body (the *guard arm*, a commented, deliberate duplication, `options-ui-§1`). Adopted at v1.55.0 |
| `Bus-1.0` | `core/Bus.lua` | the publisher `KCM.bus`, the seam names `KCM.NewBusTarget(subscribe)` / `KCM.Bus.StandDown` / `KCM.Bus.StandUp` / `KCM.MSG` (their bodies delegate to one record, `KCM.busRecord`, whose `isDown` asks `KCM.IsStoodDown` through a closure), the position of the bus in the latch's sequence (first on the way down, first on the way up, `core/LifecycleSetup.lua`), and the one debug line naming any registration the replay rejected. Degrades to the untracked-target stub (`options-ui-§1`). Adopted at v1.55.0 |
| `Widgets-1.0` | none — `settings/Category.lua` and `settings/StatPriority.lua` each resolve the major at the call site | exactly one member, `ReorderList`, behind **three** lists: a single category's priority rows, each of a composite's two combat-state sections, and the Stat Priority page's secondary stats. There is no setup file and no instance: the widget is a plain constructor with no addon-wide state to teach it, so a page asks `LibStub` in silent mode on each render. With the major absent no handle and no row box are drawn and the lists lose their in-panel reordering entirely — `/cm priority <cat> up\|down` is what still moves a priority row. Each page cancels every controller it built at the TOP of its render, before the first widget exists (`options-ui-§18`); the Category seam holds a LIST because a composite page builds two |
| `Item-1.0` | `core/ItemSetup.lua` | exactly one of the major's four members, `ItemIDFromLink`, behind the Add-by-ID line's pasted-link path (`settings/CategoryAddByID.lua:157`). `QualityFromLink` / `QualityLabel` / `LoadItem` are pointedly not taken, and `core/TooltipCache.lua` stays this addon's own policy. The degradation stub is the same primitive in three lines, so a pasted link never works on one install and not another |
| `Launcher-1.0` | `core/LauncherSetup.lua` | the addon's FOLDER name (used for BOTH registrations — LibDBIcon keys the button's saved position by it), the 128 logo path built from that name, the broker **label** — `Ka0s Consumable Master`, the brand name in plain text, deliberately neither the TOC `## Title` (a Title may carry color escapes and one in the collection does) nor the folder name, and wired to neither (`launcher-§1`) — a THUNK answering `db.global.minimap` (never the table itself — a table captured at file load is one AceDB later replaces), `openSettings` → `KCM.Options.Open` (the left click, always — minor 4), `version` (`KCM.Version()`, TOC first) for the minor-3 status tooltip, and the minor-4 options menu's two pairs: *Enabled* — `isEnabled` (the DISABLED hold only) + `setEnabled`, which runs `/cm enable` / `/cm disable`'s own body, `KCM.SlashCommands.Verbs.SetEnabled` (published by `settings/Slash.lua`) — and *Locked* — `isLocked` (`macroBar.locked`, the *Lock frame* row's value) + `toggleLock`, which runs `/cm lock` / `/cm unlock`'s own body, `KCM.SlashCommands.Verbs.RunLock(not cfg.locked)`, so the write goes through `KCM.MacroBar.SetLocked`, i.e. the same `KCM.Schema:Set("macroBar.locked", …)` seam the Master controls checkbox and `/cm bar lock` take, and the confirmation line is the verb's, including its "the bar is off" wording for a switched-off bar. Deliberately no `isTestMode` / `toggleTestMode` (no test mode: the unlocked bar is the preview), no `isWindowShown` / `toggleWindow` (no standalone window) and no `onTooltipShow` (the library draws the whole block); the minor-4 retirees `onClick`, `leftClickLabel`, `disabledLine` and `slash` are not passed. The library owns the click dispatch, the menu and its gray while disabled, so both buttons are satisfied on both surfaces by construction. No degradation stub — `core/PerfSetup.lua`'s convention: an absent major is an absent feature, and both callers (`KCM:OnInitialize`'s `Register`, the schema row's `set`) branch on nil |

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

## Peel history

Moved here from [ARCHITECTURE.md → Files over the 1500-line cap](./ARCHITECTURE.md#files-over-the-1500-line-cap), which keeps the census and the band on notice. The two test-suite peels are the cuts issues [#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32) and [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33) named. The line counts below are the figures on the day of each cut, not today's.

**What the peel did**, for the next reader who wonders where a case went. Both were test suites, and
both moved cases WHOLE — not one assertion changed, and the harness registers exactly the same
cases it did before — the total did not move by one. (It has moved since, for unrelated reasons;
`docs/test-cases.md` is the live count.)

| Was | Is now |
|---|---|
| `tests/test_macrobar.lua` (2229) | `tests/test_macrobar.lua` (1425) — model, display, cooldowns, schema rows, click gating, the flyout's candidate list, master controls, the Defaults button |
| | `tests/test_macrobar_layout.lua` (432) — the four pure-geometry sections: grid, label geometry, flyout placement, indicator clearance |
| | `tests/test_macrobar_chrome.lua` (536) — the chrome appliers (`MacroBarButton.ApplyStyle`), the flyout's bind/apply pass, the `options-ui-§15/options-ui-§16/options-ui-§17` rows they honor, and the drag handle's two tooltips and mark tint |
| | `tests/macrobar_support.lua` — not a suite: the fixtures (`fcfg`, `buildBar`) read on both sides of a seam, SHARED through a `rawget` guard rather than copied |
| `tests/test_settingsui.lua` (2028) | `tests/test_settingsui.lua` (1255) — this addon's own settings wiring |
| | `tests/test_settingsui_optionsui.lua` (800) — the three `options-ui` conformance blocks (options-ui-§13 strips, options-ui-§18 reorder lists, options-ui-§13 wrapped-strip geometry) |

Two of the cuts moved off the line numbers the issues recorded, because both files grew after the
issues were written. The macro bar's chrome block also had to take the three `options-ui-§15/options-ui-§16/options-ui-§17`
cases that arrived after it, which use its `styleButton`/`firstCall` fixtures; the settings suite's
cut is a middle slice rather than a tail, because two later blocks (the refresh debounce and the #35
characterization cases) now sit below the conformance blocks. The seams themselves are the ones the
issues named.

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

## Load order

`ConsumableMaster.toc` is the source of truth. It is sectioned `# Libraries / Locales / Core / Defaults / Modules / Settings`, and order within a section is dependency order, not alphabetical:

1. **Libraries** — LibStub + every Ace3 sub-library (AceDBOptions beside AceDB; AceConfig after AceGUI, because AceConfigDialog resolves AceGUI non-silently at load) + LibSharedMedia + `AceGUI-3.0-SharedMediaWidgets` (last, since its widgets need both AceGUI and LibSharedMedia), listed directly in the TOC (no `embeds.xml` wrapper).
2. **Locales** — `locales/enUS.lua` (publishes `KCM.L`).
3. **Core** — `core/Namespace.lua` (names `NS`, `KCM.VERSION`) → `LifecycleSetup` (load-bearing: `PerfSetup` takes the latch as `descriptor.lifecycle` at load) → `PerfSetup` (`performance-§1`: ahead of every load-time `local Perf = NS.Perf`) → `MediaSetup` (load-bearing: `DebugLogSetup` resolves the console font at load) → `core/ConsumableMaster.lua` (AceAddon promotion via `AceAddon:NewAddon(NS, addonName, ...)`, DB, pipeline) → `Bus` → `Constants` → `CoreSetup` → `Compat` → `EnvSetup` → `ItemSetup` → `LauncherSetup` → `State` → `DebugLogSetup` → `Database` → `Debug` → `SpecHelper` → `TooltipCache` → `WeaponSlots` → `BagScanner` → `Classifier` → `MacroDisplay` → `MacroBarModel` → `MacroBarLayout` → `SlashDump` → `SlashCommands`. **Every other file assumes the private `NS` (aliased `KCM`) already exists** — `core/Namespace.lua` guarantees that.
4. **Defaults** — `defaults/Profile.lua` (`KCM.dbDefaults`) → `defaults/Categories.lua` → each `defaults/Defaults_*.lua`.
5. **Modules** — `Ranker` → `Selector` → `MacroManager` → `MacroBarFlyout` → `MacroBarButton` → `MacroBar`, then the AceGUI widgets `KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`.
6. **Settings** — `settings/SchemaStub.lua` → `settings/OptionsSetup.lua` → `settings/Panel.lua` → `settings/OptionsShim.lua` → `settings/General.lua` → `settings/MacroBar.lua` → `settings/StatPriority.lua` → `settings/Category.lua` → `settings/CategoryAddByID.lua` → `settings/Slash.lua` (last: it consumes `core/SlashCommands.lua`'s verb table and nothing in `settings/` reads it).

`settings/SchemaStub.lua` (the `LibKa0s-Schema-1.0` degradation stub, `KCM.SchemaStub`) only has to precede `settings/Panel.lua`, which takes it at file load when the library is absent. `settings/OptionsSetup.lua` must come before `settings/Panel.lua` because it is the `LibKa0s-Options-1.0` seam: it creates `KCM.Settings.Helpers` and publishes the instance as `KCM.Settings.optionsUI`, which `settings/Panel.lua` takes as a file-scope local. `settings/Panel.lua` comes next because it publishes `KCM.Settings.RegisterTab`, which the per-page modules call at file-bottom. `settings/OptionsShim.lua` follows it and nothing else may come between the two: it takes `KCM.Settings.Helpers`, the `optionsUI` instance and Panel.lua's panel-unavailable notice as file-scope locals, which is the whole of its load-order constraint — every page file reaches `KCM.Options` through call-time thunks, so none of them cares where it sits. Widgets load before `settings/` so `AceGUI:Create("KCM…")` works at panel-render time. Event handlers and `Pipeline` functions are *defined* in `core/ConsumableMaster.lua` but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.

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
| `core/LifecycleSetup.lua` | The addon's half of `LibKa0s-Lifecycle-1.0` — **one latch, two named holds**, which is what makes the disabled state total rather than a draw gate (`slash-commands-§7`, anti-pattern #85). `disabled` is taken from the stored `enabled` path, `perf` by the capture harness; the addon is stood down whenever at least one is taken and stood up only when the last is released, so releasing one cannot resurrect an addon the other still holds down. `standDown` unregisters every client event (`KCM:UnregisterAllEvents`) and every bus message (`KCM.Bus.StandDown`), disarms the recompute coalescer, lets the bar's own show ladder hide it, and — in combat — keeps `PLAYER_REGEN_ENABLED` alone as the pending completion. `standUp` re-runs `KCM:OnEnable`, replays the bus subscriptions, runs login's discovery pass and stale sweep (`KCM.Pipeline.DiscoverAndSweep`) and rebuilds from the settings AS THEY ARE NOW. Publishes `KCM.Lifecycle`, `KCM.IsStoodDown`, `KCM.IsAddonDisabled`, `KCM.OnEnabledChanged`, `KCM.ReevaluateEnabled`. Loaded right after `core/Namespace.lua` in `# Core`, ahead of `core/PerfSetup.lua`, which takes the instance as `descriptor.lifecycle`. No degradation stub. |
| `core/ConsumableMaster.lua` | AceAddon entry (`AceAddon:NewAddon(NS, addonName, ...)`, stores `NS.addon`). `OnInitialize` (DB + `Database.RunMigrations` + slash registration; panel registration is driven by the `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap in `settings/Panel.lua`), `OnEnable` (walks `KCM.EVENTS`, the nine `{ event, handler }` pairs, through `KCM.SafeRegisterEvent` into `KCM.RejectedEvents`; the handlers publish `RECOMPUTE`). Houses `Pipeline.Recompute` / `RequestRecompute` / `RecomputeOne` / `RunAutoDiscovery` / `DiscoverAndSweep` / `CalcSummary`, the event handlers, `KCM.ID` sentinel helpers (positive = item, negative = spell), and `KCM.ResetAllToDefaults`. `KCM.dbDefaults` is **not** here — it is `defaults/Profile.lua`'s. |
| `core/Bus.lua` | Closed message bus, and the addon's half of `LibKa0s-Bus-1.0`. `KCM.bus` (AceEvent embed, the publisher), `KCM.NewBusTarget([subscribe])`, `KCM.Bus.StandDown` / `StandUp`, `KCM.MSG.{RECOMPUTE, PANEL_REFRESH, SPEC_CHANGED, MACROBAR_REFRESH, PROFILE_CHANGED}`. Each receiver owns its own target; every target is tracked by the one record `KCM.busRecord`, so a stand-down takes all of it down and a stand-up replays it as it is now. `KCM.MSG` comes from the major's `Catalog` and raises on an undeclared key. Library-absent: the untracked-target stub, published as `KCM._BusLib` for the parity suite. |
| `core/Constants.lua` | `KCM.PREFIX` (cyan `[CM]` tag) — the single source of truth for chat-output styling, read live by `core/CoreSetup.lua`, the category `emptyText` and the generated macro bodies. |
| `core/CoreSetup.lua` | The addon's half of `LibKa0s-Core-1.0`. Binds `KCM.SafeToString` / `KCM.IsConcatSafe` to the library (secret-safe stringifier; detection probes `table.concat`, not `tostring`/`..`) and builds `KCM.Say(fmt, ...)` — the single secret-safe chat seam, plain-string or format-string form — from `lib:New{ prefix = <function reading KCM.PREFIX>, sink = print }`. Also publishes `KCM.ColorDecode(stored, dr, dg, db, da)` — the addon's ONE reader of the stored positional `{ r, g, b, a }` shape, which answers **nil** for a channel the table does not carry and takes each fallback from its caller — and `KCM.SwatchColor(stored, useClass, dr, dg, db, da)`, the addon's ONE class-color resolver (`options-ui-§17`): it decodes with that surface's own fallback (`lib.RGBA` on the live arm, `KCM.ColorDecode` on the degraded one) and hands the result to the library's `ResolveColor` with a nil unit, because every swatch here is chrome the player owns. `ColorDecode` sits ABOVE the library branch — it is the addon's storage contract, not the library's — and the two settings surfaces plus `KCM.FormatSchemaValue` all read the stored shape through it, so a channel that is not stored cannot read white on one surface and black on another (`CONSUMABLEMASTER-R-05`). Binds `KCM.SafeRegisterEvent` to the library's (events-frames-taint-§1: `IsEventValid` front gate, `pcall`, a refused name appended once to the caller's list); the degraded stub keeps the one-rung `pcall` body. If the library is absent it installs short built-in fallbacks and says so once, on the first line printed (`KCM.LIBKA0S_MISSING`). Must load after `Constants.lua` and before `SlashCommands.lua`. |
| `core/Compat.lua` | Spec, spell and item API seam, and the addon's half of `LibKa0s-Compat-1.0`. `KCM.Compat.GetSpecialization / GetSpecializationInfo / GetSpellName / IsSecret` are the major's members bound onto the table (v1.55.0), so every caller still names `KCM.Compat.X`; `GetNumSpecializationsForClassID` (answers `0` when no API does, because its callers loop `1..n`) and `GetSpecializationInfoForClassID` stay host code, this addon being their only consumer, and so does `GetItemInfo` (`C_Item.GetItemInfo` first, the global as a guarded fallback, `nil` with neither), the one item-info read the Ranker, the tooltip cache, the Classifier and WeaponSlots fallbacks, and KCMItemRow make. The three are documented in [compat-layer.md](./compat-layer.md). `GetSpellName` answers `nil` on a miss so each call site picks its own placeholder: `modules/KCMItemRow.lua:85` shows `[Loading]`, and `modules/MacroBarFlyout.lua` writes `""` into a secure `spell` attribute, where `nil` would leave the previous binding in place. `IsSecret(value)` wraps the client's `issecretvalue` (false on a pre-Midnight client) so a gate over client data can ask before it compares — see [midnight-quirks.md](./midnight-quirks.md#secret-values). With the major absent the readers answer `nil` and `IsSecret` keeps its one-rung body (`options-ui-§1`). SpecHelper / SlashCommands / MacroManager / MacroDisplay / Ranker / TooltipCache / Classifier / WeaponSlots / settings / KCMItemRow all route through it. |
| `core/State.lua` | Session-only runtime flags. `KCM.State.debug` — default off, **never persisted**, resets each login. |
| `core/Database.lua` | `RunMigrations()` — runs immediately after `AceDB:New`, and again from the profile hooks in `core/ConsumableMaster.lua`; owns both `schemaVersion` stamps. Account-wide steps gate on `db.global.schemaVersion`; every step that writes the profile gates on `db.profile.schemaVersion`, so a profile switched to for the first time under this build is walked forward on arrival. |
| `core/Debug.lua` | `KCM.Debug.IsOn()` plus the callable sink `KCM.Debug(tag, fmt, ...)`. Read side only — it reads the session-only `KCM.State.debug` (via `DebugLog.IsEnabled` once the console has loaded) and deliberately publishes **no** toggle of its own, because `DebugLog.SetEnabled` is the flag's single write path (debug-logging-§5). Diagnostics go to the on-screen console (`LibKa0s-DebugLog-1.0`'s, via `core/DebugLogSetup.lua`); chat is a fallback only when the console is absent — including a whole install where LibKa0s is missing. |
| `core/MediaSetup.lua` | The addon's half of `LibKa0s-Media-1.0`, and the only place the library is told this addon's FOLDER name — a vendored library cannot work out which folder it was copied into, and a texture path is absolute from `Interface\AddOns\`. Publishes `KCM.Icon(name)` and `KCM.MediaFont(name)` over the payload's icon catalog and JetBrains Mono, both answering **nil** when the library is absent or the name is not one it ships, and makes the one `Media.RegisterLSM` call **at file load** rather than at `PLAYER_LOGIN`. Its TOC position is load-bearing rather than conventional: `core/DebugLogSetup.lua` resolves the console's font eagerly at load, so a `MediaSetup` loading after it would hand the library nil. |
| `core/EnvSetup.lua` | The addon's half of `LibKa0s-Env-1.0`, and the second place the library is told this addon's FOLDER name (`core/MediaSetup.lua` is the first) — `addonName`, the first vararg, because a vendored library cannot work out which folder it was copied into. Publishes `KCM.Meta(field)` — one TOC key, **nil** when the library is absent *and* the client exposes no reader, or when the manifest has no such key — and `KCM.Version()`, which prefers the TOC over `KCM.VERSION` and is never nil. It replaced two inline `C_AddOns` ladders that lived at their call sites rather than in `core/Compat.lua`: `settings/Slash.lua`'s version read (behind `/cm version` and the help header) and `settings/Panel.lua`'s About-page notes read, which asked for the folder as the hardcoded string `"ConsumableMaster"`. Its TOC position is conventional, not load-bearing: nothing resolves at load beyond the `LibStub` lookup and both callers are in `settings/`. Degrades by repeating each deleted ladder in full, so an install without LibKa0s reads its own TOC exactly as before. |
| `core/ItemSetup.lua` | The addon's half of `LibKa0s-Item-1.0`, and the whole of it: this addon consumes exactly one of the major's four members, `ItemIDFromLink`, behind the Add-by-ID line's pasted-link path (`settings/CategoryAddByID.lua:157`). The other three are pointedly declined rather than forgotten — `QualityFromLink` / `QualityLabel` because this addon has no rarity concept (its "quality" is the crafting-tier atlas out of `C_TradeSkillUI`), and `LoadItem` because hydration already runs through `GetItemInfo` plus a `GET_ITEM_INFO_RECEIVED` handler tuned for the ~150-item burst on first panel open. `core/TooltipCache.lua` deliberately did **not** move: the major carries no resolver and no cache by written design. Degrades to the same `item:<id>` match in three lines, so a pasted link never works on one install and not another. |
| `core/LauncherSetup.lua` | The addon's half of `LibKa0s-Launcher-1.0` — the minimap button and the broker plugin as ONE LibDataBroker object registered twice (`launcher-§1`). Supplies the four things only the addon knows: the FOLDER name (used for BOTH registrations — LibDBIcon keys the button's saved position by it, so it is not cosmetic), the 128 logo path built from that same name, a THUNK answering `db.global.minimap` (never the table — AceDB replaces it after this file loads), and the options menu's toggles. **Left-click opens the settings panel; right-click opens the options menu** (`launcher-§2`, minor 4) with two entries: *Enabled* (`isEnabled` + `setEnabled` → `KCM.SlashCommands.Verbs.SetEnabled`, `/cm enable` / `/cm disable`'s own body) and *Locked* (`isLocked` + `toggleLock` → `KCM.SlashCommands.Verbs.RunLock`, `/cm lock` / `/cm unlock`'s own body, so the write — `KCM.MacroBar.SetLocked`, the same `KCM.Schema:Set` seam the Master controls checkbox takes — and the wording are one copy). It holds no copy of either flag. While disabled the library grays *Locked* and a click on it reaches nothing; *Enabled* stays live. The hover tooltip is the library's too (minor 3, drawn while disabled as well); the host answers `version` and passes no test mode, no window and no lines of its own. `Register()` is called from `KCM:OnInitialize` after AceDB has built the db. No degradation stub (`core/PerfSetup.lua`'s convention): with LibKa0s absent `KCM.Launcher` is nil and both callers branch on it. |
| `core/DebugLogSetup.lua` | The addon's half of `LibKa0s-DebugLog-1.0`. Resolves the console's font through `KCM.MediaFont` (Blizzard `Fonts\ARIALN.TTF` fallback — a real client font, because `SetFont` on a missing file draws nothing and raises nothing; the library has no fallback of its own), and builds ONE console instance via `lib:New` — supplying the frame name (`ConsumableMasterDebugWindow`), `addonName` beside it so both console windows draw the shared copy / clear / close marks instead of two words and a `×`, the title, the `KCM.State.debug` read/write pair, the `KCM.Say` printer, the `[Init]` summary content, the `KCM.Options.Refresh` repaint on show/hide, and the diagnostics report's `brandName` (`Ka0s Consumable Master`) and `diagnostics` (the sections of `core/Diagnostics.lua`, asked for at run time). Publishes the flat dot-callable surface the addon calls: `SetEnabled / IsEnabled / Toggle / AddLine / Clear / Show / Hide / Toggle_Window / IsWindowShown / ShowCopy / RefreshHeader / UpdateScrollBar / UpdateStatus / RunDiagnostics` + `FormatPlain / FormatColored` (the library's function objects) + `instance`. `Toggle` flips the FLAG and is deliberately not the library's `Toggle`, which flips the window. Degrades to a windowless stub — publishing no `AddLine`, which is what re-arms `core/Debug.lua`'s chat fallback — when the library is absent. |
| `core/SpecHelper.lua` | Class/spec identity. `GetCurrent()` returns `(classID, specID, specKey, specName)`. `GetStatPriority(specKey)` merges user override → seed default → class fallback. `MakeKey(classID, specID)` produces the canonical `<classID>_<specID>` string. Spec/spell lookups route through `KCM.Compat`. |
| `core/TooltipCache.lua` | `C_TooltipInfo.GetItemByID(id)` parser + per-session cache. Captures heal/mana values (incl. HOT amounts), stat buffs, conjured/feast flags, durations. `Get(id) / Invalidate(id) / InvalidateAll() / IsUsableByPlayer(id)`, plus `Snapshot()`, the read-only counts and pending ids for the diagnostics report. Handles NBSP and `\|4singular:plural;` escapes. |
| `core/WeaponSlots.lua` | Equipped-weapon affinity for the Weapon Enchant category. Maps the main-hand (16) / off-hand (17) weapon's numeric `subClassID` (gated on `classID == Weapon`, so it's locale-independent) to `bladed` (whetstone) / `blunt` (weightstone) / `other` (a weapon that takes no stone — oils only) / `nil` (no weapon in the slot). |
| `core/BagScanner.lua` | `Scan() -> {[itemID] = count}` (one pass over `C_Container`). `HasItem(itemID) -> ownsBool, count` via a single `C_Item.GetItemCount` call (no full-Scan fallback). Stateless. |
| `core/Classifier.lua` | `(itemID) → categories`. `Match(catKey, id)`, `MatchAny(id) -> { catKeys }`, and `IsReusableAugRune(id) -> bool` (the `REUSABLE_AUG_IDS` set the AUG_RUNE scorer uses as a stat tie-break). Keys on the locale-independent numeric `classID`/`subClassID` from `GetItemInfoInstant` (plus tooltip flags for weapon-enchant / augment-rune); no subType-string matching. Tooltip-TEXT parsing stays English (tracked deviation, see scope.md). |
| `core/MacroDisplay.lua` | Read-only display resolution. Keyed by macro name — `PickID / Texture / Count / Cooldown / SetTooltip / MacroIndex` — or by opaque KCM ID for the flyout's specific candidates — `TextureForID / CountForID / CooldownForID / SetTooltipForID` — plus `FALLBACK_ICON` and `Pickup(macroName)`, the one combat-guarded protected call (`PickupMacro`), shared by both drag surfaces so neither can forget the guard. `Cooldown` / `CooldownForID` return `active, durationObject, start, duration` rather than a raw triple: mid-fight the spell cooldown API goes secret, so the boolean comes from the NeverSecret `isActive`/`isEnabled` and the raw pair is withheld unless the client says it's plain ([midnight-quirks.md](./midnight-quirks.md#secret-values)). Reads the pick MacroManager recorded in `db.profile.macroState`; writes no macro. A composite (AIO) macro records no pick, so `SetTooltip` alone asks `MacroManager.CompositeDisplayPick` for the step `#showtooltip` is showing (the first in-combat pick while fighting, the first out-of-combat one otherwise) instead of printing the macro text. That lookup ranks sub-categories, so it happens on hover only; `Count` and `Cooldown` still come back empty for an AIO slot. Shared by the macro bar's slots and `modules/KCMMacroDragIcon.lua` so icon/tooltip resolution can't drift between them. |
| `core/MacroBarModel.lua` | Pure slot bookkeeping for the macro bar. `AllKeys / NormalizeOrder / ResolveVisibility / IndexOf / Swap / VisibleKeys` (data-in/data-out) plus the db-backed `Config / IsEnabled / Order / Visible / MacroName / KeyForMacroName`. `ResolveVisibility(master, combatMode)` is the truth table that INTERSECTS the addon-wide General visibility with this bar's own Combat visibility and answers a secure-driver string, `"show"` or `"hide"`. `NormalizeOrder` is the repair seam for a saved order that predates a newly-shipped category. See [macro-bar.md](./macro-bar.md). |
| `core/MacroBarLayout.lua` | Pure geometry for the macro bar. `Grid(count, cfg) -> { positions, width, height, cols, rows }` (TOPLEFT offsets in WoW's coordinate space) + `Dimensions(count, cfg)`, handling `orientation` (which axis fills first) and `growthH` / `growthV` (which corner the first slot anchors to). Also the button-label geometry: `LabelAnchor(cfg) -> point, relPoint, x, y, justifyH` over the 9-way `LABEL_POINTS` grid × inside/outside placement, and `LabelFontSize(buttonSize, labelScale)` (percentage of button size, clamped to 6-24pt). No frames, no db reads. |
| `core/PerfSetup.lua` | The addon's half of `LibKa0s-Perf-1.0` + its panel. Builds one A/B capture harness and publishes it as `KCM.Perf` — the instance ITSELF, not a facade, because the brackets read `on` / `run` / `suspended` as plain boolean fields the library writes. Supplies the frame naming, `/cm` as the taught command, `ConsumableMasterPerfDB` as the capture ring's own SavedVariables global, the three sinks (run log → `DebugLog.AddLine`, which is the ungated append; chat → `KCM.Say`), and the **latch** (`descriptor.lifecycle`, required from Perf minor 12). The `suspend`/`resume` pair it used to carry is `core/LifecycleSetup.lua`'s `standDown` / `standUp` now, where the *disabled* arm reaches the same code: `P.Suspend()` takes the `perf` hold and `P.Resume()` gives it back, and the latch decides whether anything happens. Absent major → absent feature and no stub: the two bracket sites take their upvalue nil-tolerantly, so nothing errors on that build. Loaded in `# Core` after `core/LifecycleSetup.lua`, whose latch it takes at load — `performance-§1` puts it ahead of every file taking `local Perf = NS.Perf` as a load-time upvalue. |
| `core/SlashDump.lua` | The `/cm dump <target>` diagnostics namespace: `DUMP_TARGETS`, `DUMP_ORDER`, `printDumpLines`, `dumpHelp`, `dumpDispatch` and `eventStates`, the rows the `events` target and the diagnostics report both print. Peeled out of `SlashCommands.lua` for **CM-54** — it uses none of the slash parsing helpers, only `KCM.Say` and addon state, so it lifted whole. Loads **before** `SlashCommands.lua`, which is the dependency direction: the `priority` verb renders a composite category through the `pick` target, never the reverse. Published as `KCM.SlashDump` (`Dispatch` / `Help` / `TARGETS` / `EventStates`). |
| `core/Diagnostics.lua` | The diagnostics report's sections (`debug-logging-§14`, DX-CM), published as `KCM.Diagnostics.Sections()`: state (stored switch, stood down, holds, schema, perf), settings (`out:nonDefaults` over the schema rows, with `enabled`, `macroBar.enabled`, `macroBar.locked` and `global.minimap.shown` always printed), spec and stat priority, per category the stored edits, the top five of the effective priority with score and owned flag and the pick the macro carries, the weapon-enchant slots, every managed macro and the combat queue, the macro bar, the tooltip cache, the bags and the client events. Read-only: it never calls `Selector.PickBestForCategory` (whose level gate asks `IsUsableByPlayer` of pending entries) or `GetBucket` on a spec bucket that does not exist yet. `core/DebugLogSetup.lua`'s descriptor asks for the sections at run time, and the library writes the markers, the identity header, the per-section pcall and the cap. |
| `core/SlashCommands.lua` | The slash **verb bodies**, and nothing about dispatch (**CM-47**). Owns the `priority` / `stat` / `aio` / `bar` namespaces and their `PRIORITY_COMMANDS` / `STAT_COMMANDS` / `AIO_COMMANDS` tables, the shared parsing helpers (`trim`, `tokenize`, `findCommand`, `afterMutation`, the spec and priority-ID resolvers), and the `KCM_CONFIRM_RESET` StaticPopup raised by `/cm resetall`. `KCM.FormatSchemaValue` stays a published export here (the addon's own value renderer outside the CLI); the key=value formatter went to the library with the CLI. Publishes five entry points on `KCM.SlashCommands.Verbs` (`RunBar` / `RunPriority` / `RunStat` / `RunAIO` / `Dump`) for `settings/Slash.lua` to assemble. The file-local `say` is an alias of the shared `KCM.Say` seam, so every slash line inherits the cyan `[CM]` prefix and secret-safe stringification with no per-site tag. |
| `settings/Slash.lua` | The **dispatcher** — `slash-commands-§1` names this file, which is what **CM-47** was (`core/SlashCommands.lua` was also the repo's largest file at 1408 LOC, advisory **CM-54**). Holds the ordered `COMMANDS` table, the `SLASH_STRINGS` wording overrides, the `LibKa0s-Slash-1.0` descriptor and instance (`KCM.SlashCommands.instance`), `addonVersion()`, the schema `helpers()` accessor, `GetLandingRows()` and `KCM:OnSlashCommand`. Routing, the help header and rows, the version verb and the schema CLI (`Sl:CliList` / `CliGet` / `CliSet` / `CliReset`) are the library's; `Sl:CliResetAll` is deliberately declined, because this addon's global wipe also clears `categories` and `statPriority`, which the schema does not describe ([LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)). `COMMANDS` is **passed in**, never owned. `GetLandingRows()` returns the About panel's rows **already rendered** by `lib.FormatRow` — the same output `/cm help` prints, so the two lists cannot drift (LIBKA0S-13); the unrendered `GetCommandSummary()` went with that convergence. It publishes one verb body of its own, `setEnabled` (the `enable` / `disable` handler), as `KCM.SlashCommands.Verbs.SetEnabled`, for the launcher menu's *Enabled* entry (`core/LauncherSetup.lua`). Loads last in `# Settings`: nothing else reads it at load, and AceConsole resolves `"OnSlashCommand"` by name when a command is typed. |

### modules/

| File | Responsibility |
|------|----------------|
| `modules/Ranker.lua` | Per-category scorers. `Score(catKey, id, ctx, scoreCache) / SortCandidates(catKey, ids, ctx, scoreCache) / BuildContext(catKey, itemIDs, existing, scoreCache) / Explain(catKey, id, ctx)`. Spell entries short-circuit to a fixed score above every item. HP_POT / MP_POT apply the immediate-vs-HOT 20% rule. Spec-aware scorers weight by `ctx.specPriority`. |
| `modules/Selector.lua` | Candidate set + pin merge + ownership walk. Public surface: `BuildCandidateSet / GetEffectivePriority / PickBestForCategory / PickBestForSlot / ListAvailable / GetBucket / SpliceOrder` (read), `AddItem / Block / MoveTo / MoveUp / MoveDown / ResetBucket / ResetAllBuckets / MoveCompositeRef / MarkDiscovered / SweepStaleDiscovered` (write). It is the `architecture-§5` registry writer for the per-category item lists (named in [ARCHITECTURE.md → Settings Schema](./ARCHITECTURE.md#settings-schema)), and the only runtime one: `ResetBucket` and `ResetAllBuckets` are the registry reset verbs that `/cm priority <cat> reset`, the Macros page's per-category reset and Reset all priorities call; `MoveCompositeRef` moves a composite section, which is not a registry but a whole-value schema row, so it splices a copy with the pure `SpliceOrder` and writes it through `KCM.Schema:Set`. `MoveCompositeRef(catKey, orderField, from, to)` is the composite sections' move-to mutator — a splice to index, never a run of adjacent swaps — and it never moves a ref between the two sections. `PickBestForSlot(catKey, slot, scoreCache?)` is the per-hand entry point (`perHand` cats; slot 16/17), affinity-filtered via `WeaponSlots`. Owns the `(seed ∪ added ∪ discovered) − blocked` math and the 30-day discovered GC. |
| `modules/MacroManager.lua` | The **only** module that calls `CreateMacro` / `EditMacro`. `SetMacro(macroName, id, catKey)` for single picks; `SetWeaponEnchantMacro(cat, mhPick, ohPick)` for the per-hand WPN_ENCH body; `SetCompositeMacro(cat, scoreCache)` for HP_AIO / MP_AIO. All three share the `commitMacro` tail (size limit → fingerprint early-out → combat deferral → `doEdit`). Combat-deferral queue (`pendingUpdates`), bounded retry on flush, DYNAMIC_ICON / DEFAULT_ICON convention, 255-byte body limit fallback. `InvalidateState()` clears caches for `/cm rewritemacros`. `PendingSnapshot()` and `WriteTracking()` hand the diagnostics report read-only copies of the queue, the oversize gate and the give-up record. `CompositeDisplayPick(cat, inCombat, pickFor)` answers the step a composite's `#showtooltip` is showing, which is what the bar's AIO tooltip reads, since a composite stores no pick of its own. See [macro-manager.md](./macro-manager.md). |
| `modules/MacroBarButton.lua` | One macro-bar slot: a `SecureActionButtonTemplate` button whose `macro` attribute is stamped **once** at creation (a slot belongs to its category for life) and which registers for `"AnyUp"` with `useOnKeyDown = false` pinned beside it (without the pin, the `ActionButtonUseKeyDown` cvar drops every mouse click), plus icon / count / cooldown / tooltip refresh, the shared `ApplyCooldown(cd, active, durationObject, start, duration)` applier (prefers `SetCooldownFromDurationObject` — the only setter that survives a restricted cooldown — and falls back to the raw pair on a client without duration objects; the flyout's entries paint through the same seam), chrome (`ApplyStyle`, which is a sequencer over three exported appliers — `ApplyBorder(frame, anchorTo, cfg)` paints the LSM border on its own `BackdropTemplate` child so `buttonBorderOffset` can push it clear of the icon and owns the `buttonBorder == false` hide itself, `ApplyIconZoom(icon, cfg)` is the clamped `SetTexCoord` crop, `ApplyBackdropTex(tex, cfg)` is the fill — plus the auto-shortening label on a dedicated overlay child; the flyout's entries call the same three, so entry chrome cannot drift from slot chrome), the shared `BorderTexture(lsmName)` fetch, and the drag handlers — `MacroDisplay.Pickup` (combat-guarded) out to a Blizzard bar, swap-on-drop within our own bar, silent rejection of anything that isn't a `KCM_*` macro. |
| `modules/MacroBarFlyout.lua` | Per-slot hover flyout. `Create(button, catKey, index)` builds the indicator + container as `SecureHandlerEnterLeaveTemplate` frames whose `_onenter` / `_onleave` snippets open and close the strip **inside the secure environment** — the only way that works mid-combat, since flyout entries are `SecureActionButton`s and therefore protected. `Apply(button, cfg)` rebuilds content (out of combat only: binding an entry writes a secure attribute), `Candidates(catKey, cfg)` caps + inverts `Selector.ListAvailable`, `RefreshCooldowns(button)` repaints swipes (unprotected, so live in combat). `MAX_ENTRIES` bounds the pool, and every pooled entry carries the slot's `"AnyUp"` + `useOnKeyDown = false` pin. Closing has three paths, all funnelling through `Close(flyout)`: the secure `_onleave` (the only combat-safe one), a `PostClick` hook on the slot and on every entry, and an idle `C_Timer` (`flyoutAutoClose`). The last two are insecure Lua and stand down in combat. See [macro-bar.md](./macro-bar.md). |
| `modules/MacroBar.lua` | The optional CM-only bar container. `Update()` is the single apply seam (defers wholesale to `PLAYER_REGEN_ENABLED` via `FlushPending`, since slots are protected frames); `SetEnabled / SetLocked / ResetPosition / SwapSlots / Refresh / RefreshCooldowns / ApplyEnabled / ApplyLock / FlushPending`, and the read-only `IsUpdatePending()` for the diagnostics report. Combat-conditional visibility goes to `RegisterStateDriver`, never `Show`/`Hide`. Owns the sole `MACROBAR_REFRESH` receiver, and on the same target receives `PROFILE_CHANGED` to run `Update()` — the whole re-apply a profile switch, copy or reset needs, since a repaint re-reads icons and counts only. See [macro-bar.md](./macro-bar.md). |

### AceGUI custom widgets

Also under `modules/`. Loaded between `MacroManager` / `DebugLog` and `settings/`. Each file calls `AceGUI:RegisterWidgetType` at the bottom; the tab builders acquire instances via `AceGUI:Create("KCM…")` at render time.

| File | Purpose |
|------|---------|
| `modules/KCMItemRow.lua` | Priority-list row: status glyphs (green check / red / yellow star) + item icon + name + quality tier. Hover renders the real in-game item or spell tooltip (forks on `KCM.ID.IsSpell`). Spell name via `KCM.Compat`. |
| `modules/KCMIconButton.lua` | Gold-hover icon button used for ↑ / ↓ / ×. |
| `modules/KCMScoreButton.lua` | The blue "i" info button. Hover renders the per-item `Ranker.Explain` breakdown. No-op `SetLabel` so the caller can pass an arbitrary tooltip-title string without rendering a text label under the icon. |
| `modules/KCMMacroDragIcon.lua` | Pickable macro icon at the top of each category tab on the Macros page. Icon + tooltip come from `core/MacroDisplay.lua` — pick-first, because the stored `?` sentinel is meaningless on a static UI widget. |

### settings/

Each PAGE module registers a builder via `KCM.Settings.RegisterTab(key, builder)`; `settings/Panel.lua`'s bootstrap iterates `KCM.Settings.order` and calls each builder once Blizzard_Settings is ready. There are five: **General**, **Macros**, **Stat Priority**, **Macro Bar** and **Profiles**. **The first four each carry a pinned tab strip** (`options-ui-§13`) — General 2, Macros 15, Stat Priority 1 and Macro Bar 8 — and Stat Priority carries a page banner (`options-ui-§14`) above its strip. Their bodies are hand-built AceGUI widget trees inside a `Helpers.CreatePanel` canvas, except that General hands its strip and rows to the library's `RenderTabbedSchema` ([#41](https://github.com/tusharsaxena/ConsumableMaster/issues/41) records why the other three do not). AceConfigDialog draws only the fifth, **Profiles**, which carries no rows and is exempt from the strip.

| File | Responsibility |
|------|----------------|
| `settings/SchemaStub.lua` | The `LibKa0s-Schema-1.0` degradation stub (`KCM.SchemaStub`): the library's documented write-completing, log-silent stub, copied from LibKa0s' `tests/test_schema.lua` `referenceStub`. `settings/Panel.lua` builds the write seam from it when the library is absent, so `/cm bar on\|off`, `/cm enable` and the global reset keep writing. Carries the whole instance surface and the lib-level primitives; `tests/test_surface_parity.lua` pins both. |
| `settings/OptionsSetup.lua` | The `LibKa0s-Options-1.0` seam, and the only place the library is constructed (`options-ui-§1`). Resolves the major in silent mode, builds the instance with this addon's conventions taught to it (positional `{r,g,b,a}` color codec — `Helpers.ColorDecode`, which is `KCM.ColorDecode` plus the four numbers an AceGUI swatch has to be given because it cannot draw an absent channel, `sliderCommit = "change"` for the Macro Bar's live drag preview, a call-time LibSharedMedia thunk, a `print` thunk onto `KCM.Say`, `get`/`set` thunks onto `Helpers.Get` / `Helpers.SetAndRefresh`, and `rowsForPage`, which answers the schema rows whose `panel` is the page key, for the General page's `RenderTabbedSchema`), installs it as `KCM.Settings.Helpers`' `__index` and publishes it as `Helpers.instance` + `KCM.Settings.optionsUI`. Creates `KCM.Settings.Helpers` and publishes `KCM.Settings.PANEL_TITLE`. Names the global-reset veto `KCM.Settings.VetoedFromResetAll` once, above the library branch so both arms carry it, and passes it to the library as the descriptor's `skipRestoreAll` (`options-ui-§3`); `KCM.ResetAllToDefaults`' session sweep asks the same function. Declares `resetProfile` (the same `db:ResetProfile()`, read off `KCM.db` at call time) and `profilesPage = true`, which the library reads only to word the *Reset all settings* tooltip (`options-ui-§12`). With the major (or AceGUI) absent it builds nothing and installs the two unconditional refresh tiers, `RefreshAllPanels` / `RefreshScalars`, as real no-ops — both are called on paths a degraded install still reaches. |
| `settings/Panel.lua` | Framework, and the addon's half of `LibKa0s-Options-1.0`. The seam itself lives in `settings/OptionsSetup.lua`, which loads immediately before this file; what is read back here is `KCM.Settings.optionsUI`, `ensureScroll` and `libAbsent`. The chrome is the library's — the lazy AceGUI ScrollFrame and the always-visible scrollbar gutter (`Helpers.EnsureScroll` / `PatchAlwaysShowScrollbar` are forwarders onto `Helpers.instance`) — while the schema half stays here. `Helpers.CreatePanel` (gold title + atlas divider + body), `Section` / `Button` / `ButtonPair` / `Label` builders. The row widget makers, `RenderField`, `SetRenderer` and both refresh tiers are the library's too, once [LIBKA0S-04](https://github.com/tusharsaxena/ConsumableMaster/issues/22)/-05 were fixed upstream; what stays here is the schema itself, the `LibKa0s-Schema-1.0` write seam (`Helpers.schema`, or `settings/SchemaStub.lua`'s stub without the library) behind `SetAndRefresh`, the per-type `TYPE_RULES`, `Grid`, the buttons, `EnumValues` (the host `LSMValues` wrapper beside it came out at `M4-C1`, its last caller having gone with `M3-04`; the name resolves through `__index` to the library's deferred reader now), the page registry order and the `KCM.Options` shim. `CreatePanel` also carries the Blizzard canvas contract the library stamps as of Options minor 5 — `OnCommit` / `OnRefresh` / `OnDefault`, which is what makes the Settings window's own **footer** Defaults control work (a different widget from this addon's header Defaults button, and not per-page). With LibKa0s absent no panel is registered at all and `KCM.Options.Open()` answers `false`; the schema half above the seam survives, but the CLI that reads it is the library's too, so `/cm list|get|set` is unavailable in that state as well. Owns the `KCM.Settings.Schema` array, `Helpers.SetAndRefresh` (the seam's door that reports a refusal, published as `KCM.Schema:Set`), `Helpers.Get / Set / FindSchema / Bulk / MuteSetLog / AddRows / ValidateSchema / ValidateSchemaValue`, and the two refresh paths — `RefreshAllPanels` (structural rebuild) and `RefreshScalars` (in-place widget re-sync, options-ui-§11). Hosts the parent (About) canvas via `BuildAboutContent`, whose command rows come back already rendered from `KCM.SlashCommands.GetLandingRows()` rather than being formatted here (LIBKA0S-13). Publishes `KCM.Options.Register` and CREATES the `KCM.Options` table; `Refresh` / `RequestRefresh` / `Open` are filled in by `settings/OptionsShim.lua`, which was this file's closing block until the 2026-09-16 peel at the 1500-line cap. |
| `settings/OptionsShim.lua` | The run-time `KCM.Options` surface, peeled whole off `settings/Panel.lua` on 2026-09-16 (1488 lines, twelve under `layout-§1`'s cap, and *Accepted* on the watch list for three releases). `O.Refresh` (immediate, every shown panel), `O.RequestRefresh` (trailing-edge debounce: 1.0s quiet, 3.0s hard cap, one timer per burst, held while the Macros page's Add-by-ID box is in use) and `O.Open` (refuses on a degraded install, otherwise delegates to the library's `OpenOptionsPanel`, which refuses in combat and expands the parent in the AddOns tree after opening). Also the options layer's three bus receivers — `PANEL_REFRESH` (debounced), `PROFILE_CHANGED` (immediate, because a page drawn from the outgoing profile holds controls that write it) and `SPEC_CHANGED` (retracks the Stat Priority page). Borrows `sayPanelUnavailable` from `settings/Panel.lua` rather than copying it: it holds a said-once flag, and a second copy would be a second flag. |
| `settings/General.lua` | General page, TWO tabs on a pinned strip (`options-ui-§13`) drawn by the library's `RenderTabbedSchema`: the page's schema rows are one group, and Maintenance is a host tab in `opts.tabs`. **Master controls**, the canonical eight (`options-ui-§15`) COMPOSED by `H.MasterControls` — `enabled`, `visibility`, `scale`, `alpha`, `macroBar.locked`, `state.debugConsole`, closed by the `[Reset position \| Reset all settings]` button pair. `visibility` / `scale` / `alpha` are NEW addon-wide settings and compose with the bar's own; `macroBar.locked` and Reset position MOVED here from the Macro Bar page and were deleted there. Beside it, a **Maintenance** tab carries `[Force resync \| Force rewrite]` plus a full-width `[Reset all priorities]` — a targeted verb (`KCM.ResetAllPriorities`, confirmed by `KCM_RESET_PRIORITIES`) and NOT the profile reset *Reset all settings* runs through `KCM_CONFIRM_RESET`, the same popup `/cm resetall` raises. Those three were a subsection under the canonical block from 2026-09-03 until 2026-09-09, when 1.6.0 put the tab back; `options-ui-§15` permits it because it forbids splitting only the *canonical set*, which these three were never part of, and Master controls stays first. None of the three is a setting, so nothing moved in storage. |
| `settings/MacroBar.lua` | Macro Bar page. Registers every `macroBar.*` schema row (defaults sourced from `KCM.dbDefaults`, so each is simultaneously a widget here and a `/cm set macroBar.<field>` path) across eight TABS on a pinned strip — General (1), Layout (8), Bar appearance (9), Button appearance (13), Labels (12), Flyout (16), Visibility (3) and Buttons (2 whole-value rows, `macroBar.order` and `macroBar.shown`, drawn as ONE draggable list in MultiMeters' Columns shape. Shown slots come first with a drag handle, then a rule, then the hidden ones, dimmed and handle-less (`boundary` = the shown count). A drag splices `order` in one write. A tick moves the slot across the rule and writes `shown` then `order` as one batch. Both are refused in combat, and the rows are pooled raw frames released with the controller at the top of every render; it read *Contents* for one release, and *Buttons* names the things on screen). A tab IS a row `group`, so the strip cannot drift from the rows it partitions; `KCM.Settings.MACROBAR_TABS` publishes it. The two border blocks and the label font block are COMPOSED (`H.BorderGroup` / `H.FontGroup`, `options-ui-§16`) and every swatch is composed with its class-color companion (`H.ColorPair`, `options-ui-§17`); the bar chrome is a BACKGROUND group and takes no texture picker. The four mixed tabs carry `subgroup` headings (`options-ui-§7`), and each schema-backed tab draws through the library's `RenderRows`, so declaration order IS the layout. Buttons: Reset slot order, and a page Defaults action that writes every row on the page back to its default through `H.SetManyAndRefresh` (one batch: one bar re-apply, one page rebuild, and one `[Set] reset Macro Bar page: N rows` log line through its `opts.bulk`), puts the position back through `MacroBar.ResetPosition`, and leaves `locked` alone because it is the General page's row now. |
| `settings/StatPriority.lua` | Stat Priority page, and the declaration site of the `statPriority` whole-value row (one map keyed by spec, written only through `KCM.Schema:Set`): the spec picker as the page BANNER (`options-ui-§14`, class+spec icon markup, pinned above the scroll), then a ONE-TAB strip (`options-ui-§13` — a single section still draws one, and it is drawn before the no-spec empty state rather than skipped for it), the Primary stat spanning both columns, and the four secondary stats as ONE draggable list (order-only, with a dimmed undraggable tail for the excluded, `boundary = #included`). The row is a POOLED RAW FRAME, MultiMeters-shaped (`options-ui-§8`, `options-ui-§18`): `[handle gutter] [tick/cross] … [stat name, right-aligned]`, the library's bounded box behind the WHOLE row (no `spec.parent` override — naming the handle's slot boxed the 30px gutter and left the row bare) and a stride 4px wider than the box so rows do not touch. The tick/cross replaced an `Include` checkbox and wears the same two textures MultiMeters' column blocks do; it is pooled and released on `cancelReorder` for the same reason ColumnBlocks pools its blocks, and every script reads the stat off the frame at fire time. Owns `KCM.Options._viewedSpec` + `O.ResolveViewedSpec` + `O.FormatSpec` + `O.SplitSecondaries`. |
| `settings/Category.lua` | The **Macros** page (single + composite categories): ONE page, with one tab per row in `KCM.Categories.LIST`, generated in `KCM.Settings.macroOrder` — 15 tabs, each labeled with its category's `displayName`. It was one sub-page per category until the strip replaced them. **The Add-by-ID line below is `settings/CategoryAddByID.lua`'s** since the 2026-09-16 peel at `layout-§1`'s 1500-line cap; it is described here because it is still that page's, and the two files share exactly two helpers (`newRow`, `afterMutation`, off `KCM.Settings.MacrosPage`) in one direction and one entry point (`KCM.Settings.AddByID.Render`) in the other. Single dispatch: drag icon → Add-by-ID (the Type dropdown, then `LibKa0s-Options-1.0`'s `IdInput` line: an ID, a link or a name \| Add, over a status line; a host resolver keeps this addon's link parsers and existence checks; `candidates` are the category's `Selector.BuildCandidateSet` IDs plus, under Type=Item, the items in the bags, so a name resolves beyond the bags and the suggestions list every rank the tab knows or the bags carry (a rank that is neither is not listed); the kind declares `base = "item"` / `"spell"` per Type, so its rows wear the library kind's tier icon and quality color (or spell subtext) and a picked row goes through the host resolver first; `onAdd`, which a picked suggestion reaches too, re-checks existence, stores through `Selector.AddItem` and defers the rebuild a frame; a Type change redraws and carries the typed text across; `O.AddByIDBusy` answers whether the box on screen has focus or holds text, for `settings/OptionsShim.lua`'s refresh hold) → the glyph legend → Priority list rows (LibKa0s drag handle + KCMItemRow + KCMScoreButton + ×) → inline Reset. Composite dispatch: drag icon → the description → the glyph legend (two swatches, not three: a composite row draws no pick star) → In Combat / Out of Combat sections, EACH ITS OWN flat reorder controller (drag handle + KCMItemRow + Enabled checkbox; the ↑/↓ arrows are gone, anti-patterns #75) → inline Reset. **Both row flavors are boxed the way every other draggable row in the collection is** (`options-ui-§8`, `options-ui-§18`): no `spec.parent` override, so the library's fill and 1px edge sit behind the WHOLE row rather than around the handle's 30px gutter, and `ROW_STRIDE = ROW_H + ROW_GAP` with the gap drawn as a spacer after each row — a taller row would be a taller box, not a space between two. `cancelReorder` holds a LIST of controllers and runs before the first widget of a render exists. Shared `KCM_RESET_CATEGORY` StaticPopup. Declares, generated from `KCM.Categories.LIST`, the whole-value rows behind the composite controls (`categories.<KEY>.enabled`, `.orderInCombat`, `.orderOutOfCombat`) and a `mouseover` bool row for each targeted category. The Enabled checkbox, the drag, the composite reset (one `H.SetManyAndRefresh` batch, logged as one `[Set] reset category <KEY>: N rows` line) and the mouseover checkbox all write through the helper. |
| `settings/Profiles.lua` | The **Profiles** page ([profiles.md](./profiles.md)). AceDBOptions' options table over `KCM.db`, registered with AceConfig as `ConsumableMaster-Profiles` and drawn by AceConfigDialog into an AceGUI SimpleGroup parented to the page body. It is the one place AceConfig is used (`options-ui-§3`). The container's frame is shown explicitly, because a SimpleGroup AceGUI hands back from its pool arrives hidden. No `defaultsAction`, so no Defaults button; no schema rows; no tab strip (`options-ui-§13` exemption). Its SetRenderer body re-opens the dialog only after a `PROFILE_CHANGED` it counted on a private bus target, so the pipeline's debounced structural refresh never tears the tree down under an open dropdown. With any of its four libraries missing the builder answers nil and the page is absent. Last in `KCM.Settings.order` and last in the TOC. |

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
| `locales/enUS.lua` | Publishes `KCM.L`, a key-returning metatable, and carries the notes a first translator needs. The **settings surface** — `settings/` and the `modules/KCM*` widgets — routes its user-facing strings through `L[...]`, and `tests/test_locale.lua` gates that: a bare prose literal added there is red until it is wrapped or given a class in that file's residue register. Outside it, `/cm` command output (`core/SlashCommands.lua`, `core/SlashDump.lua`) and the seeded category display names (`defaults/Categories.lua`) are still bare English — a known gap, not a claim. English is the only shipped locale; this is a shell, not localization plumbing. |

### Shared infrastructure

- `libs/` — vendored Ace3 (including AceConfig-3.0 and AceDBOptions-3.0, for the Profiles page alone, and AceGUI-3.0-SharedMediaWidgets) + LibStub + CallbackHandler-1.0 + LibSharedMedia + LibKa0s, tracked in git (standard WoW addon practice). Loaded before any addon source by the `# Libraries` block of `ConsumableMaster.toc`, which lists each library file directly (no `embeds.xml` wrapper — toc-file-§4).
- `ConsumableMaster.toc` — Interface line (`120100`), version, SavedVariables, file load order. Sectioned `# Libraries / Locales / Core / Defaults / Modules / Settings`; order within a section is dependency order, not alphabetical.
- `tests/` — headless harness (`lua5.1 tests/run.lua`; suite inventory in [test-cases.md](./test-cases.md)) over the addon's logic layer; `wow_mock.lua` stubs the WoW API + bus; `mock_menu.lua` is LibKa0s v1.58.0's own context-menu fake (`MenuUtil`), copied for the launcher-menu cases because the kit does not ship one.

### Top-level docs

- `README.md` — user-facing. Its `## Version History` table is this addon's only release history (`documentation-§1` forbids a root `CHANGELOG.md`).
- `CLAUDE.md` — stub (standard link + hard rules + gate + pointer into `docs/`).
- `DEPENDENCIES.md` — what to install to build, run, test or release this addon, with a verification command per tool (`documentation-§7`). Answers *what to install*; `docs/testing.md` answers *how to verify*.
- `docs/ARCHITECTURE.md` — design overview + invariants + message-bus catalog + LibKa0s adoption summary + doc index + deviation register.
- `docs/*.md` — topic chunks (this file is one of them). `docs/test-cases.md` and `docs/automated-tests/RESULTS.md` are **generated** — never hand-edit either.
</content>
