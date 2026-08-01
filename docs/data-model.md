# Data model

AceDB schema, the opaque-numeric ID convention, the composite-bucket shape, and the discovered-set garbage collector.

## AceDB profile (one profile, account-wide)

`KCM.dbDefaults` (declared in `core/ConsumableMaster.lua`). `schemaVersion` lives in the account-wide **global** tree; everything else is in the profile:

```
db.global
└── schemaVersion        1          -- migration marker; see core/Database.lua

db.profile
├── enabled              boolean    -- master enable; gates Pipeline.Recompute
├── categories
│   ├── FOOD │ DRINK │ HP_POT │ MP_POT │ HS │ VANTUS │ AUG_RUNE ← single-pick, non-spec-aware
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
│       ├── enabled            { [refKey] = boolean }
│       ├── orderInCombat      { refKey, refKey, ... }
│       └── orderOutOfCombat   { refKey, ... }
├── statPriority
│   └── ["<classID>_<specID>"] = { primary, secondary[] }   -- user overrides only
├── macroState
│   └── [macroName] = { lastItemID, lastBody, lastIcon, lastCat }   -- early-out cache
└── macroBar                        -- CM-only macro bar; enabled = true, locked = false
    ├── enabled │ locked            boolean
    ├── point │ relPoint │ x │ y    anchor against UIParent (saved after a drag)
    ├── scale │ alpha               number
    ├── buttonSize │ spacing │ padding │ perRow      number   -- grid geometry
    ├── orientation                 "HORIZONTAL" │ "VERTICAL"
    ├── growthH │ growthV           "RIGHT"│"LEFT" │ "DOWN"│"UP"
    ├── barBackdrop │ barBorder │ buttonBackdrop │ buttonBorder   boolean
    ├── barBorderStyle │ buttonBorderStyle       LibSharedMedia border name
    ├── barBorderSize │ buttonBorderSize │ buttonBorderOffset      number (px)
    ├── barBackdropColor │ barBorderColor │ buttonBackdropColor
    │   │ buttonBorderColor         { r, g, b, a }
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
    ├── flyoutAutoClose             number   -- idle seconds; 0 = never
    ├── buttonLabel │ labelOutline  boolean
    ├── labelText                   "AUTO" │ "FULL" │ "SHORT"
    ├── labelPoint                  9-way grid, e.g. "TOP_CENTER"
    ├── labelPlacement              "INSIDE" │ "OUTSIDE"
    ├── labelScale                  number   -- % of button size (6-24pt clamp)
    ├── labelOffsetX │ labelOffsetY number (px)
    ├── labelColor                  { r, g, b, a }
    ├── combatMode                  "ALWAYS" │ "HIDE_IN_COMBAT" │ "ONLY_IN_COMBAT"
    ├── fadeUnlessHover │ fadeAlpha boolean │ number
    ├── order                       { catKey, ... }   -- slot order, drag-to-swap
    └── shown                       { [catKey] = false }  -- unset means VISIBLE
```

### Field semantics

- **`added[id] = true`** — user-added entry (item or spell sentinel). Persists across bag changes.
- **`blocked[id] = true`** — user-blocked entry; subtracted from the candidate set. Auto-discovery cannot re-add a blocked id.
- **`pins`** — array of `{ itemID, position }` (the field is `itemID`, and it holds a spell sentinel just as happily as an itemID). Pinned entries land at their requested position; non-pinned entries fill the gaps in score order. Top-to-bottom ordering. `MoveUp` / `MoveDown` rewrite the whole array as one contiguous `1..N` run, so two pins never contend for a position in practice.
- **`discovered[id] = <unixTimestamp>`** — auto-discovered item, with last-sighting timestamp used by the GC sweep. Items only — bag discovery cannot find spells.
- **`statPriority[<spec>]`** — optional. Missing entries fall back to the seed default (`Defaults_StatPriority.lua`); if the seed is also missing, the class-primary default is used.
- **`WPN_ENCH` is per-hand, not a single pick.** It still has one `bySpec` bucket like the other spec-aware categories, but the pipeline resolves it as two independent picks: `Selector.PickBestForSlot(catKey, slot, scoreCache)` filters the effective candidate set to entries whose tooltip-derived `tt.weaponAffinity` (`"bladed"` | `"blunt"` | `"any"`, from `TooltipCache`) matches `KCM.WeaponSlots.SlotAffinity(slot)` for the equipped main-hand (16) / off-hand (17) weapon, then ranks and picks within that filtered set. `AP` and `SP` are scored as spec-role stats — `AP` scores as the spec's primary throughput stat for STR/AGI specs, `SP` for INT specs (`Ranker.lua`'s primary-stat weight), so an Attack Power oil doesn't rank below a secondary-stat oil for a physical-damage spec. `MacroManager.SetWeaponEnchantMacro(cat, mhPick, ohPick)` builds the macro from the two picks, dropping a hand with no weapon or no matching enhancement.
- **`macroState`** — fingerprint cache for `MacroManager`'s "unchanged" early-out. `lastIcon` was added in v1.2.0 to support the `DYNAMIC_ICON` migration; `lastCat` lets `MacroManager` reason about which category owns a slot.

- **`macroBar`** — the optional macro bar's entire state. Every scalar has a matching `KCM.Settings.Schema` row (registered by `settings/MacroBar.lua`, defaults sourced from `dbDefaults`), so each is both a panel widget and a `/cm set macroBar.<field>` path. Two fields are not scalars: **`order`** is the slot order, mutated only by dragging one slot onto another, and repaired on every read by `MacroBarModel.Order()` (unknown keys dropped, newly-shipped categories appended); **`shown[catKey] = false`** hides a slot, and an *unset* key means visible so a category shipped after the profile was written appears rather than vanishing. A profile that predates the bar needs no structural migration — AceDB merges the defaults in — but schema **v2** (`core/Database.lua`) does force `enabled = true` + `locked = false` once, so an upgrading user meets the bar exactly like a new one does. That step is deliberately one-shot: the `schemaVersion` bump means a later, deliberate opt-out is never stomped on the next login. Detail in [macro-bar.md](./macro-bar.md).

### Effective candidate set

Computed at recompute time in `Selector.BuildCandidateSet`:

```
candidates = (seed[cat] ∪ added[cat] ∪ discovered[cat]) − blocked[cat]
```

Seeds live in `KCM.SEED.<CATKEY>` Lua constants, **not** in SavedVariables — that's why updating a `defaults/Defaults_*.lua` file is a zero-migration upgrade for existing users.

### Migrations

`db.global.schemaVersion` is at `2`. `core/Database.lua`'s `RunMigrations()` runs immediately after `AceDB:New` and is the one place version-gated migrations land; every step is guarded on the stored version so it runs at most once.

| Version | Step |
|---------|------|
| 1 | Original shape. |
| 2 | Macro bar introduced. `Database.MigrateMacroBarV2` sets `profile.macroBar.enabled = true` and `locked = false` so an upgrading profile gets the bar on and placeable, like a fresh install. One-shot by design — a later opt-out survives. |

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
- `orderInCombat` and `orderOutOfCombat` are arrays of single-category keys. Sub-categories are **locked to their section** — HS / HP_POT / MP_POT only ever appear in `inCombat`; FOOD / DRINK only ever in `outOfCombat`. The Options panel enforces this; `Pipeline.RecomputeOne` doesn't double-check.
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

`PLAYER_ENTERING_WORLD`, after auto-discovery and before the first recompute. Pseudo-code:

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

There isn't one. `/cm resync` does a full rescan but **does not** include a GC sweep — that's an explicit PEW-only policy. If demand emerges, a `/cm gc` variant is trivial to add.

## Reset path

`KCM.ResetAllToDefaults(reason)` in `core/ConsumableMaster.lua` is the one place that wipes `categories` + `statPriority` back to `dbDefaults`. Both the Options "Reset all priorities" button and `/cm resetall`'s StaticPopup delegate to it so semantics stay identical regardless of entry point. (`/cm reset <path>` is unrelated: it is `Sl:CliReset`, which applies one schema row's `default` and leaves both tables alone.)

After the DB wipe, the function drives a full resync: `TooltipCache.InvalidateAll` → `RunAutoDiscovery` → `Pipeline.Recompute`. Macro writes that land in combat defer via the pending queue, so this is safe to run without a combat guard.

`macroState` is **not** wiped — live macros stay valid. If you need the macros re-issued unconditionally, use `/cm rewritemacros`, which calls `MacroManager.InvalidateState()` to clear `macroState` + `pendingUpdates` and then re-runs the pipeline.
