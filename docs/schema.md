# Data model

AceDB schema, the opaque-numeric ID convention, the composite-bucket shape, and the discovered-set garbage collector.

## The AceDB tree (account-wide global, plus one tree per profile)

`KCM.dbDefaults` (declared in `defaults/Profile.lua`, the one declaration site for every shipped default). There are **two** `schemaVersion` stamps, one per scope, because a migration step belongs to whichever scope it writes: the account-wide **global** stamp is the marker `savedvariables-§1` asks for, and each profile carries its own, which is what gates the steps that write that profile. Only the global one is a shipped default, and it ships as `0`, the pre-migration floor, never a real version: AceDB's `removeDefaults` strips a stored value equal to its default at logout, and its defaults merge backfills a declared default onto a legacy account, so a real version there could erase a stamp or mask a migration (`savedvariables-§1`). A profile's is written by `RunMigrations` the first time it walks that profile. Everything else is in the profile bar one — the minimap button's visibility, which `launcher-§3` fixes in the **global** store and requires to survive **every** reset the addon ships — so a profile switch, *Reset all settings* and the General page's *Defaults* button all leave it alone (see [settings-panel.md](./settings-panel.md#the-minimap-button-row--shown-says-one-thing-the-store-says-the-other)) — so the Profiles page ([profiles.md](./profiles.md)) switches, copies and resets every other setting the addon has:

```
db.global
├── schemaVersion        3          -- migration marker; default 0, walked to 3 by
│                                   -- RunMigrations (core/Database.lua)
└── minimap                         -- LibDBIcon-1.0's OWN table, handed straight to
    ├── hide             boolean    -- :Register (launcher-§3). GLOBAL and not profile:
    │                                -- a minimap button belongs to the INSTALLATION, so a
    │                                -- profile switch must not move it, and NO reset may
    │                                -- un-hide it -- not *Reset all settings*, not the
    │                                -- General page's Defaults button, which is carved
    │                                -- out by the row's `neverReset` stamp
    │                                -- (settings/General.lua). The row says SHOWN and this
    │                                -- key says HIDDEN; the row's own get/set
    │                                -- (settings/General.lua) inverts, under the seam.
    └── minimapPos       number     -- the angle the player dragged the button to.
                                    -- LibDBIcon's own write; no schema row addresses
                                    -- it (architecture-§5).

db.profile
├── schemaVersion        3          -- THIS profile's migration marker; gates every
│                                   -- step that writes the profile scope. Not a
│                                   -- default: RunMigrations writes it on arrival.
├── enabled              boolean    -- master enable. It drives the LATCH
│                                   -- (core/LifecycleSetup.lua): writing it
│                                   -- false stands the WHOLE addon down --
│                                   -- every event and bus message
│                                   -- unregistered, the bar off the screen --
│                                   -- rather than gating one macro pass
│                                   -- the three ADDON-WIDE master controls
│                                   -- (options-ui-§15). NOT the macro bar's own
│                                   -- scale/alpha/combatMode -- the two compose.
├── visibility           "always" │ "inCombat" │ "outOfCombat" │ "never"
├── scale                number     -- multiplies macroBar.scale
├── alpha                number     -- multiplies macroBar.alpha
├── categories
│   ├── FOOD │ DRINK │ HP_POT │ MP_POT │ HS │ VANTUS │ AUG_RUNE │ BLOODLUST │ BATTLE_REZ ← single-pick, non-spec-aware
│   │   ├── added       { [id] = true }                  -- user-added items + spells
│   │   ├── blocked     { [id] = true }                  -- never enters candidate set
│   │   ├── pins        { { itemID = N, position = K }, ... } -- override Ranker order
│   │   └── discovered  { [id] = unixTimestamp }         -- last-seen-in-bags
│   ├── STAT_FOOD │ CMBT_POT │ FLASK │ WPN_ENCH  ← single-pick, spec-aware
│   │   └── bySpec
│   │       └── ["<classID>_<specID>"]
│   │           ├── added
│   │           ├── blocked
│   │           ├── pins
│   │           └── discovered
│   └── HP_AIO  │ MP_AIO                        ← composite (no item buckets)
│       ├── enabled            { [refKey] = boolean }         -- schema row (flag map)
│       ├── orderInCombat      { refKey, refKey, ... }         -- schema row (order)
│       └── orderOutOfCombat   { refKey, ... }                 -- schema row (order)
├── statPriority                                             -- ONE schema row (map)
│   └── ["<classID>_<specID>"] = { primary, secondary[] }   -- user overrides only
├── macroState
│   └── [macroName] = { lastItemID, lastBody, lastIcon, lastCat }   -- early-out cache;
│                                   -- no row: learned data, owner MacroManager
└── macroBar                        -- CM-only macro bar; enabled = true, locked = false
    ├── enabled │ locked            boolean
    ├── point │ relPoint │ x │ y    anchor against UIParent -- no row: drag-only
    │                               -- geometry, owner MacroBar (saved on drag-stop)
    ├── scale │ alpha               number
    ├── buttonSize │ spacing │ padding │ perRow      number   -- grid geometry
    ├── orientation                 "HORIZONTAL" │ "VERTICAL"
    ├── growthH │ growthV           "RIGHT"│"LEFT" │ "DOWN"│"UP"
    ├── barBackdrop │ barBorder │ buttonBackdrop │ buttonBorder   boolean
    ├── barBorderStyle │ buttonBorderStyle       LibSharedMedia border name
    ├── barBorderSize │ buttonBorderSize │ buttonBorderOffset      number (px)
    ├── barBackdropColor │ barBorderColor │ buttonBackdropColor
    │   │ buttonBorderColor         { r, g, b, a }
    ├── useClassColorBarBackdrop │ useClassColorBarBorder
    │   │ useClassColorButtonBackdrop │ useClassColorButtonBorder   boolean
    │                                        -- the options-ui-§17 companions
    ├── iconZoom                    number   -- % cropped off each icon edge
    ├── showCount │ tooltips        boolean
    ├── flyout                      boolean  -- per-slot hover flyout (default on)
    ├── flyoutPoint                 "TOP" │ "BOTTOM" │ "LEFT" │ "RIGHT"
    │                                        -- indicator edge AND growth direction
    ├── flyoutInvert                boolean  -- put the top rank furthest out
    ├── flyoutMax                   number   -- entries, capped by MAX_ENTRIES
    ├── flyoutScale                 number   -- % of buttonSize
    ├── flyoutSpacing               number (px)  -- between entries
    ├── flyoutGap                   number (px)  -- button to first entry
    ├── flyoutPadding               number (px)  -- entries to panel edge
    ├── flyoutBackdrop              boolean      -- the strip's own panel
    ├── flyoutBackdropColor         { r, g, b, a }
    ├── flyoutIndicatorScale        number   -- band thickness, % of the button
    │                                        -- (clamped to half of it)
    ├── flyoutArrowScale            number   -- arrow size, % of band thickness
    ├── flyoutShadeColor            { r, g, b, a }
    ├── useClassColorFlyoutBackdrop │ useClassColorFlyoutShade   boolean
    ├── flyoutAutoClose             number   -- idle seconds; 0 = never
    ├── buttonLabel                 boolean
    ├── labelText                   "AUTO" │ "FULL" │ "SHORT"
    ├── labelPoint                  9-way grid, e.g. "TOP_CENTER"
    ├── labelPlacement              "INSIDE" │ "OUTSIDE"
    ├── labelFont                   LibSharedMedia font name
    ├── labelScale                  number   -- % of button size (6-24pt clamp)
    ├── labelFlags                  "" │ "OUTLINE" │ "THICKOUTLINE"
    │                               │ "MONOCHROME" │ "OUTLINE, MONOCHROME"
    ├── labelShadow                 boolean
    ├── labelOffsetX │ labelOffsetY number (px)
    ├── labelColor                  { r, g, b, a }
    ├── useClassColorLabel          boolean
    ├── combatMode                  "ALWAYS" │ "HIDE_IN_COMBAT" │ "ONLY_IN_COMBAT"
    ├── fadeUnlessHover │ fadeAlpha boolean │ number
    ├── order                       { catKey, ... }   -- slot order, drag-to-swap; schema row (order)
    └── shown                       { [catKey] = false }  -- unset means VISIBLE; schema row (flag map)
```

### Field semantics

- **`added[id] = true`** — user-added entry (item or spell sentinel). Persists across bag changes.
- **`blocked[id] = true`** — user-blocked entry; subtracted from the candidate set. Auto-discovery cannot re-add a blocked id.
- **`pins`** — array of `{ itemID, position }` (the field is `itemID`, and it holds a spell sentinel just as happily as an itemID). Pinned entries land at their requested position; non-pinned entries fill the gaps in score order. Top-to-bottom ordering. `MoveUp` / `MoveDown` rewrite the whole array as one contiguous `1..N` run, so two pins never contend for a position in practice.
- **`discovered[id] = <unixTimestamp>`** — auto-discovered item, with last-sighting timestamp used by the GC sweep. Items only — bag discovery cannot find spells.
- **`statPriority[<spec>]`** — optional. Missing entries fall back to the seed default (`Defaults_StatPriority.lua`); if the seed is also missing, the class-primary default is used. The whole map is one whole-value schema row, `statPriority` (`settings/StatPriority.lua`). Every writer hands the whole map to `KCM.Schema:Set`, and the row's normalizer keeps a spec key, a real primary (`STR` / `AGI` / `INT`) and the secondaries deduplicated.
- **`BATTLE_REZ.mouseover`** — the one bucket-shape exception: an extra `boolean` field (default `true`) alongside `added` / `blocked` / `pins` / `discovered`. Read by `MacroManager` (`modules/MacroManager.lua:73`) to decide whether the macro body gets the `[@mouseover,help][@target,help]` targeting clause or falls back to `[@target,help]` alone; it is the schema row `categories.BATTLE_REZ.mouseover`, toggled from that category's tab on the Macros page (the "Cast on mouseover" checkbox) and reachable as `/cm get|set|reset categories.BATTLE_REZ.mouseover`.
- **`BLOODLUST` / `BATTLE_REZ` have no Classifier matcher.** Every other category in this tree gains candidates from the bag scan; these two are seed-plus-user-added only — `discovered` never populates on its own.
- **`KCM.SEED.CLASS_GATE`** — a general mechanism, not specific to any one category: `Selector.spellAvailable` (`modules/Selector.lua`) consults it for every spell-form candidate in every category, falling back to it when `IsPlayerSpell` says no (e.g. a pet-granted ability like Primal Rage, which lives in the hunter pet's spellbook, not the player's). Maps a spell id to the class file name allowed to use it. Declared and explained in `defaults/Defaults_Bloodlust.lua`, the only seed file that currently populates it.
- **`WPN_ENCH` is per-hand, not a single pick.** It still has one `bySpec` bucket like the other spec-aware categories, but the pipeline resolves it as two independent picks: `Selector.PickBestForSlot(catKey, slot, scoreCache)` filters the effective candidate set to entries whose tooltip-derived `tt.weaponAffinity` (`"bladed"` | `"blunt"` | `"any"`, from `TooltipCache`) matches `KCM.WeaponSlots.SlotAffinity(slot)` (`"bladed"` | `"blunt"` | `"other"` | `nil`) for the equipped main-hand (16) / off-hand (17) weapon, then ranks and picks within that filtered set. `AP` and `SP` are scored as spec-role stats — `AP` scores as the spec's primary throughput stat for STR/AGI specs, `SP` for INT specs (`Ranker.lua`'s primary-stat weight), so an Attack Power oil doesn't rank below a secondary-stat oil for a physical-damage spec. `MacroManager.SetWeaponEnchantMacro(cat, mhPick, ohPick)` builds the macro from the two picks, dropping a hand with no weapon or no matching enhancement.
- **`visibility` / `scale` / `alpha`** — the addon-wide master controls (`options-ui-§15`), and **not** the macro bar's `macroBar.scale` / `macroBar.alpha` / `macroBar.combatMode`. The two are different settings and they **compose**: `modules/MacroBar.lua` multiplies the master scale and alpha into the bar's own, and `MacroBarModel.ResolveVisibility(master, combatMode)` **intersects** the two combat-conditional visibilities so the bar shows only where both say show. `visibility` is a four-value dropdown and never a boolean, because a boolean can only ever answer two of the four.
- **`useClassColor*`** — one per color swatch, the companion `options-ui-§17` requires beside every picker, default `false`. All seven are player-scoped: the bar is chrome the player owns and tracks no unit. `KCM.SwatchColor` (`core/CoreSetup.lua`) resolves a stored swatch through its companion, and the stored **alpha** always applies — which is why the swatch is never disabled.
- **`labelFlags`** — the canonical font-flags string (`options-ui-§16`). It replaced the `labelOutline` boolean in schema **v3**; `""` is a real stored value and means no flags at all.
- **`macroState`** — fingerprint cache for `MacroManager`'s "unchanged" early-out. `lastIcon` was added in v1.2.0 to support the `DYNAMIC_ICON` migration; `lastCat` lets `MacroManager` reason about which category owns a slot. It is learned data, not a setting, and has no row. `MacroManager` owns it: `commitMacro` writes a macro's fingerprint after each successful edit, and `InvalidateState` clears the whole cache for `/cm rewritemacros` and **Force rewrite macros**. ARCHITECTURE.md names every writer ([Other state written outside the helper](./ARCHITECTURE.md#other-state-written-outside-the-helper)).

- **`macroBar`** — the optional macro bar's entire state. Every setting has a matching `KCM.Settings.Schema` row (registered by `settings/MacroBar.lua`, defaults sourced from `dbDefaults`), so each is both a panel setting and a `/cm set macroBar.<field>` path. The bar's anchor, `point` / `relPoint` / `x` / `y`, is not a setting and has no row. It is drag-only geometry that `MacroBar` owns: `savePosition` writes it when a drag stops, and `MacroBar.ResetPosition` puts back the default for **Reset position**, `/cm bar reset` and the page's Defaults. ARCHITECTURE.md names every writer ([Other state written outside the helper](./ARCHITECTURE.md#other-state-written-outside-the-helper)). Two of the settings are whole-value rows rather than scalars. **`order`** is the slot order (type `order`). Dropping one slot onto another on the bar writes it (`MacroBar.SwapSlots`), and so do a drag or a tick on the Macro Bar page's Buttons tab and the page's order and page resets (`settings/MacroBar.lua`), each through the schema helper. `MacroBarModel.Order()` repairs it on every read without writing it back: unknown keys are dropped and newly-shipped categories appended. **`shown[catKey] = false`** (type `map`) hides a slot, and an *unset* key means visible so a category shipped after the profile was written appears rather than vanishing. A profile that predates the bar needs no structural migration — AceDB merges the defaults in — but schema **v2** (`core/Database.lua`) does force `enabled = true` + `locked = false` once, so an upgrading user meets the bar exactly like a new one does. That step is deliberately one-shot **per profile**: the profile's own `schemaVersion` bump means a later, deliberate opt-out is never stomped on the next login or the next switch back. Schema **v3** converts `labelOutline` (boolean) to `labelFlags` (string) and removes the old key, because a stored value changing shape is a migration and never an edit to a defaults table. `locked` is still stored here and is still `macroBar.locked`; only the tab it is edited on moved (General → Master controls). Detail in [macro-bar.md](./macro-bar.md).

### Effective candidate set

Computed at recompute time in `Selector.BuildCandidateSet`:

```
candidates = (seed[cat] ∪ added[cat] ∪ discovered[cat]) − blocked[cat]
```

Seeds live in `KCM.SEED.<CATKEY>` Lua constants, **not** in SavedVariables — that's why updating a `defaults/Defaults_*.lua` file is a zero-migration upgrade for existing users.

### Migrations

Both stamps are at `3`. `core/Database.lua`'s `RunMigrations()` runs immediately after `AceDB:New` **and again on every profile switch, copy and reset** (the hooks in `core/ConsumableMaster.lua`), and is the one place version-gated migrations land; every step is guarded on the stored version for the scope it writes, so it runs at most once per store. The runner owns both stamps: no step writes `schemaVersion`, and each stamp line sits after its step call, so a step that raises leaves the stamp at the last completed version and the next load retries it. The same reaction then forgets the macro fingerprints on a switch or a copy, resyncs, and publishes `PROFILE_CHANGED` ([profiles.md](./profiles.md)).

Both steps below write `db.profile`, so both are gated on `db.profile.schemaVersion`. Gating them on the account-wide stamp — which is what this addon did until the profile stamp existed — meant that once *any* profile had been walked to the current version, every other profile in the file was skipped from then on, whatever build had written it; the `OnProfileChanged` hook that exists to catch exactly that re-ran a pass gated on a stamp that had already moved. The cost of the repair is paid once: no profile in an existing file carries a stamp, so each one meets the v2 step once on its first arrival under this build, and a deliberate opt-out has to be set again. The information needed to avoid that — which profile the old runner migrated — was never written down.

| Version | Step |
|---------|------|
| 1 | Original shape. |
| 2 | Macro bar introduced. `Database.MigrateMacroBarV2` sets `profile.macroBar.enabled = true` and `locked = false` so an upgrading profile gets the bar on and placeable, like a fresh install. One-shot by design — a later opt-out survives. |
| 3 | The label outline became a font-flags string (`options-ui-§16`). `Database.MigrateLabelFlagsV3` writes `macroBar.labelFlags` from the old `macroBar.labelOutline` — `true` → `"OUTLINE"`, `false` → `""` — and removes the boolean, so there is never a second copy for a later reader to guess between. **The presence of `labelOutline` is what gates it**, not the absence of `labelFlags`: AceDB has already merged the shipped `labelFlags = "OUTLINE"` into every live profile before `RunMigrations` looks, so a guard on `labelFlags == nil` could never fire and the step would delete the boolean while keeping the default — losing exactly the un-outlined choice it exists to carry across. A profile carrying no boolean has been through the step already and is left alone: it is a conversion, not a reset. |

The discovered-set format change in v1.1.0 (`true` → unix timestamp) is forward-compatible via lazy coercion (see [Discovered-set GC](#discovered-set-gc) below), so it needs no explicit migration step.

## Composite bucket shape

Composites (HP_AIO, MP_AIO) compose other categories' picks via `[combat]` / `[nocombat]` macro conditionals — they don't run their own ranker. The persisted state is just a per-ref enabled flag plus two ordered ref arrays:

```lua
HP_AIO = {
    enabled          = { HS = true, HP_POT = true, FOOD = true },
    orderInCombat    = { "HS", "HP_POT" },
    orderOutOfCombat = { "FOOD" },
}
```

- `enabled[ref] ~= false` defaults to true when the field is unset (e.g. for refs added later via Categories metadata that aren't yet in the saved bucket).
- `orderInCombat` and `orderOutOfCombat` are arrays of single-category keys. Sub-categories are **locked to their section** — HS / HP_POT / MP_POT only ever appear in `inCombat`; FOOD / DRINK only ever in `outOfCombat`. The Options panel enforces this, and so does each section's schema row, whose validator keeps a section to its own shipped members; `Pipeline.RecomputeOne` doesn't double-check.
- Composites have no `added` / `blocked` / `pins` / `discovered` buckets — picks come from the underlying single categories at recompute time.

The composite body is assembled by `MacroManager.SetCompositeMacro` (see [macro-manager.md](./macro-manager.md#composite-body-assembly)).

## Opaque-numeric ID convention

Priority-list entries are **opaque numeric IDs** that the pipeline treats uniformly. The sign encodes the kind:

- **Positive** → itemID.
- **Negative** → spell sentinel. The spell's ID is `math.abs(id)`.

Conversions and predicates live in `KCM.ID` (declared in `core/ConsumableMaster.lua`):

```lua
KCM.ID.AsSpell(spellID)  -- returns -spellID
KCM.ID.IsSpell(id)       -- id < 0
KCM.ID.IsItem(id)        -- id > 0
KCM.ID.SpellID(id)       -- -id when spell, else nil
```

Seed files compose spell entries via `KCM.ID.AsSpell(spellID)` for readability — e.g. `KCM.ID.AsSpell(1231411)` for Recuperate.

### Fork sites

The Selector, pins / added / blocked / discovered tables, Ranker context tables, and most of the pipeline treat these as opaque numeric keys — a negative key works identically to a positive one through every table. **Only three call sites fork on the sign:**

1. `MacroManager` body builders → `/use item:<id>` for items, `/cast <Spell>` for spells (single-pick); `item:<id>` token vs spell name for `/castsequence` (composite).
2. `Ranker.Score` → spell entries short-circuit to a fixed `SPELL_SCORE` above every item (no tooltip lookup).
3. UI widgets (`KCMItemRow`, `KCMMacroDragIcon`) → `GameTooltip:SetSpellByID` vs `:SetItemByID` for hover tooltips.

Keep it that way. No new side channels — every other layer should treat IDs as plain table keys.

### Discovery accepts items only

`Selector.MarkDiscovered` rejects spells (bag discovery can't find them). `Selector.AddItem` accepts both, so the Options panel's Item / Spell picker can seed either kind.

## Discovered-set GC

### The problem

In v1.0.0, `discovered[id] = true` accumulated forever. One-shot consumables looted months ago stayed in the priority list as "not in bags" rows.

### The fix

`discovered[id] = <unixTimestamp>` — the last time the id was seen in `BagScanner.Scan()`'s output. `Selector.MarkDiscovered(catKey, id, specKey, nowUnix)` writes / bumps the timestamp.

### Lazy migration of legacy `true` values

- Reader (`Selector.BuildCandidateSet`, GC sweep) treats `true` as "age unknown".
- `Selector.MarkDiscovered` is idempotent: writes `nowUnix` whether the entry was missing, `true`, or stale.
- Next bag scan that sees the id bumps the timestamp.
- Legacy `true` values that are **not** seen within the TTL get swept on the next sweep.

### Sweep trigger

`PLAYER_ENTERING_WORLD`, and the stand-up after a re-enable, each after auto-discovery and before the recompute (`Pipeline.DiscoverAndSweep`). Pseudo-code:

```
SweepStaleDiscovered(nowUnix):
    cutoff   = nowUnix - 30 * 86400        -- 30-day TTL
    bagCounts = BagScanner.Scan()
    for each category, for each bucket:
        for id, ts in pairs(bucket.discovered):
            if bagCounts[id] and bagCounts[id] > 0:
                bucket.discovered[id] = nowUnix       -- bump; never sweep owned items
            else:
                staleTs = (ts == true) and 0 or ts
                if staleTs < cutoff:
                    bucket.discovered[id] = nil        -- drop: stale
```

TTL is the only gate. A classifier re-check on stale entries was considered and dropped — if an item's classification ever changes across a patch, the stale entry times out on its own within 30 days of bag absence.

### What's never swept

- `added[id]` — user intent.
- `blocked[id]` — user intent.
- Only `discovered` is subject to GC.

### Manual trigger

There isn't one. `/cm resync` does a full rescan but **does not** include a GC sweep — the sweep runs only at login (`PLAYER_ENTERING_WORLD`) and on the stand-up after a re-enable, both through `Pipeline.DiscoverAndSweep`. If demand emerges, a `/cm gc` variant is trivial to add.

## The write seam

Every schema row is written through **one** seam (`architecture-§5`): `LibKa0s-Schema-1.0`'s
instance, built in `settings/Panel.lua` and published as `KCM.Settings.Helpers.schema`
([ConsumableMaster#39](https://github.com/tusharsaxena/ConsumableMaster/issues/39)). The
library owns the machinery (the path walk, the row index, the pipeline, the batch, the bulk
bracket and the reset count). The addon owns the rows, their type rules and what a write sets
off. Its doors are unchanged. `KCM.Schema:Set` / `:SetMany`, `Helpers.SetAndRefresh` /
`SetManyAndRefresh`, every panel widget and every host verb reach it.

**The pipeline, in order** (the library's contract, `docs/api/Schema/version-2-docs.md` in
LibKa0s):

1. A path no row declares is **refused** (`Setting not found`), never stored.
2. `validate(value)`: the row's type rule refuses a wrong type or an enum value outside the
   row's list (`allowed values: …`).
3. `normalize(value)` answers what is stored. A number is clamped to `min` / `max`. A color, an
   order and a map are rebuilt as a fresh table: an order is repaired to its member set, and a
   flag map keeps only its members' booleans. `nil, why` refuses. Stat priority's map carries its
   own `normalize`, which is kept.
4. The store is `db.profile` (the descriptor's `resolveRoot`), and a table value is **copied** in.
   A row with its own `get` / `set` stores there instead: `state.debugConsole` (session-only, the
   console window itself) and `global.minimap.shown` (in `db.global`, where the SHOWN ↔ HIDDEN
   inversion lives, `launcher-§3`: the path says *shown*, the stored key is still LibDBIcon's `hide`). Both stores are stamped on the row in `settings/General.lua`.
5. The `[Set] <path> = <value>` line, when debug is on, **before** any reaction.
6. `announce`: the row's **`apply`**, then the in-place `RefreshScalars`.

The type rules are `TYPE_RULES` in `settings/Panel.lua`, split `validate` / `normalize` by type.
`bool`, `string` and enum rows are validate-only. `Helpers.AddRows` / `AddRow` /
`RegisterRows` stamp them onto each row, closed over it, and index the row. A row added any
other way is not writable.

**`apply`, not `onChange`.** A row's reaction (the bar's re-apply, the recompute, the latch) is
the host field `apply`, and `announce` runs it through the `onChange for <path> failed: …`
reporter. A raising reaction is reported and never propagated, because the value has already
landed. Schema's own `row.onChange` would propagate, so no row declares one.

**`SetMany`, all or nothing.** `Helpers.SetManyAndRefresh(entries, opts)` is the library's
`SetMany`. Every entry is validated and normalized before the first store, so one bad value
writes none. The batch's `announceBatch` then runs, once, either the caller's `opts.onChange` or
each **distinct** row `apply` in first-seen order, followed by one refresh
(`RefreshAllPanels` when `opts.structural`, otherwise `RefreshScalars`). A sixty-row page reset
is still one `applyBar`. `opts.bulk = { act, scope }` makes the batch one bracket, so it logs one
`[Set] <act> <scope>: N rows` line (`debug-logging-§10`).

**The bracket and the reset count.** `Helpers.Bulk(act, scope, fn)` is the library's `BulkRun`.
`Helpers.MuteSetLog(fn)` is the same bracket marked as a profile reset, so it logs nothing. A
sweep inside a bracket never resets a row flagged `neverReset` (the minimap button,
`launcher-§3`), because such rows form the descriptor's `resetExempt`. `KCM.ResetAllToDefaults`
wraps `db:ResetProfile()` in `ResetCounted`, and the `OnProfileReset` handler's
`ConsumeResetCount` both silences any open bracket and hands the line its count.

**The degraded build.** With LibKa0s absent the seam is `settings/SchemaStub.lua`
(`KCM.SchemaStub`), the library's documented degradation stub. It is write-completing and
log-silent. Reads, writes, `normalize`, the reaction, the announce and the sweep veto all work,
so `/cm bar on|off`, `/cm enable` and the global reset keep writing. No `[Set]` line, bracket
line or reset count is written. `tests/test_surface_parity.lua` pins its instance surface against
a live instance and its library surface against the major by name.

## Reset path

`KCM.ResetAllToDefaults(reason)` in `core/ConsumableMaster.lua` is the one place that resets the whole active profile back to `dbDefaults`. Both the General page's **Reset all settings** button (Master controls' closing pair, `options-ui-§15`) and `/cm resetall` raise the one `KCM_CONFIRM_RESET` popup, which delegates to it, so semantics stay identical regardless of entry point. It refuses under combat lockdown before any write (`false, "combat"`) and repaints every open panel on success. The General page's **Reset all priorities** button is a narrower, separately-confirmed act (`KCM.ResetAllPriorities`, `settings/General.lua`): every category's `added` / `blocked` / `pins` — `bySpec` buckets included, through the registry writer's `Selector.ResetAllBuckets` — plus `statPriority`, and nothing else. `discovered` survives it, exactly as it survives a per-category reset. (`/cm reset <path>` is unrelated: it is `Sl:CliReset`, which applies one schema row's `default` and leaves both tables alone.)

After the DB wipe, the `OnProfileReset` handler (`KCM.RegisterProfileCallbacks`, `core/ConsumableMaster.lua`) drives a full resync: `TooltipCache.InvalidateAll` → `RunAutoDiscovery` → `Pipeline.Recompute`. It is the same reaction a switch or a copy gets, and it ends by publishing `PROFILE_CHANGED`, off which the macro bar re-applies itself whole and every open settings page rebuilds. Macro writes that land in combat would defer via the pending queue, so the wipe itself is combat-safe; the reset refuses in combat anyway, to match the General page's other Maintenance verbs rather than half-land mid-fight.

`db:ResetProfile()` empties `macroState` along with the rest of the profile. The resync puts it back: with no fingerprint left to match, `Recompute` re-issues every macro, so live macros stay valid and the cache is rebuilt. A **switch** or a **copy** brings another profile's `macroState` in instead, and that describes the bodies that profile last wrote rather than what the account's macros hold now. So the profile handler calls `MacroManager.InvalidateState()` before the resync on both, and every macro is rewritten ([profiles.md](./profiles.md#why-the-fingerprints-are-forgotten)). To re-issue the macros without resetting anything, use `/cm rewritemacros`, which calls `MacroManager.InvalidateState()` to clear `macroState` + `pendingUpdates` and then re-runs the pipeline.
