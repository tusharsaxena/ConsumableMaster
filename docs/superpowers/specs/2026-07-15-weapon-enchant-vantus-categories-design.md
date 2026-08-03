# Design — Weapon Enchant & Vantus Rune macro categories

**Date:** 2026-07-15
**Issue:** [#2 — Add new macro categories](https://github.com/tusharsaxena/consumablemaster/issues/2) (scoped to Vantus Runes + weapon consumables)
**Status:** Approved design, pending implementation plan

## Goal

Add two new auto-managed macro categories to Consumable Master:

1. **Weapon Enchant** (`WPN_ENCH`) — temporary weapon enhancements (Enchanting oils,
   whetstones/weightstones). Spec-aware. Applies to main-hand **and** off-hand.
2. **Vantus Rune** (`VANTUS`) — the current raid's universal Versatility rune. Not
   spec-aware. Single-target `/use`.

These join the existing single-pick set (8 → 10 categories; 10 → 12 total macros,
composites unchanged). Neither participates in the AIO composites.

## Background (verified 2026-07-15)

- **Vantus Runes** exist in Midnight and were reworked into a single **universal**
  per-raid rune granting **Versatility** (e.g. *Vantus Rune: Radiant*, item `245880`),
  Inscription-crafted, weekly. Universal → not spec-specific. Applied with a plain
  `/use item:<id>`.
- **Weapon consumables** are Enchanting **oils** (item type *Consumable*, ~2h temporary
  weapon buff) mostly granting a **secondary stat**. Applied to the weapon, which
  requires a two-step "ready the item, then apply to slot" macro.

Consequence: a single spec-aware Weapon Enchant category is sufficient. The existing
stat-priority scorer already separates oils from stones by role — a warrior's
Crit/Str stone scores high, a caster's Int/Haste oil scores ~0 for that warrior — so no
manual oil-vs-stone split is needed.

## Category metadata (`defaults/Categories.lua`)

Two new rows, following the existing single-category schema
(`key / macroName / displayName / specAware / rankerKey / classifier / emptyText`):

| key | macroName | displayName | specAware | rankerKey | classifier | list position |
|-----|-----------|-------------|-----------|-----------|------------|---------------|
| `VANTUS` | `KCM_VANTUS` | Vantus Rune | `false` | `VANTUS` | `VANTUS` | after `HS` (non-spec group) |
| `WPN_ENCH` | `KCM_WPN_ENCH` | Weapon Enchant | `true` | `WPN_ENCH` | `WPN_ENCH` | after `STAT_FOOD` (spec-aware group) |

- Macro names: `KCM_VANTUS` (10 chars), `KCM_WPN_ENCH` (12 chars) — both ≤16.
- `emptyText`: `emptyMacro("no vantus rune in bags")`,
  `emptyMacro("no weapon enchant for this spec")`.
- Ordering keeps the spec-aware categories grouped and the AIO composites last.

## Classification (`core/Classifier.lua`)

### `WPN_ENCH`
Match temporary weapon enhancements by `GetItemInfoInstant` subType, mirroring the
existing `ST_FLASK_PHIAL` pattern:

```lua
local ST_WEAPON_OIL = "<confirm in-game>"   -- e.g. "Weapon Enchantments" / "Item Enhancement"

WPN_ENCH = function(_, tt, subType)
    return subType == ST_WEAPON_OIL
end
```

Oils and stones share the subType; the spec scorer decides which is useful. Like the
flask matcher, this can classify on subType alone (no tooltip gate) so discovery is
deterministic on the first bag scan — **pending** confirmation that the subType is
reliably returned by `GetItemInfoInstant` for these items. If a tooltip signal is needed
to disambiguate, fall back to the tooltip-gated path.

### `VANTUS`
Vantus runes carry a generic subType, so a subType match would over-match. Use an
**itemID whitelist + seed list**, exactly like Healthstones (O(1), pre-tooltip):

```lua
local VANTUS_IDS = {
    [245880] = true,   -- Vantus Rune: Radiant (confirm / extend per tier)
}

VANTUS = function(itemID)
    return VANTUS_IDS[itemID] == true
end
```

New tiers are added by extending `VANTUS_IDS` (and the seed list); users can always
add-by-ID.

> **Open item:** confirm the Midnight weapon-oil subType string and the current-tier
> Vantus itemID(s) in-game via `/cm dump item <id>`. Both are single-constant updates,
> consistent with the Classifier's existing "update the constant if Blizzard renames"
> note.

## Scoring (`modules/Ranker.lua`)

### `WPN_ENCH` — spec-aware
Identical shape to the `FLASK` scorer: reuse `scoreByStatPriority` plus ilvl + quality
tiebreak.

```lua
WPN_ENCH = function(itemID, ctx, scoreCache)
    local quality, ilvl, _, tt = itemFields(itemID, scoreCache)
    return scoreByStatPriority(tt, ctx and ctx.specPriority)
         + ilvl
         + quality * QUALITY_WEIGHT
end,
```

- Proc-only oils (no secondary stat) score on the tiebreak only; a user can pin one,
  matching how non-stat combat potions already behave.
- `R.Explain`: fold `WPN_ENCH` into the existing
  `STAT_FOOD/CMBT_POT/FLASK` breakdown branch (stat-priority summary).

### `VANTUS` — not spec-aware
Newest raid tier wins over an old leftover; ilvl + quality is enough.

```lua
VANTUS = function(itemID, ctx, scoreCache)
    local quality, ilvl = itemFields(itemID, scoreCache)
    return ilvl + quality * QUALITY_WEIGHT
end,
```

- `R.Explain`: new small branch — "current-tier rune preferred (ilvl + quality)".

## Macro bodies (`modules/MacroManager.lua`)

### `VANTUS`
No change — the default single-pick body:

```
#showtooltip
/use item:<id>
```

### `WPN_ENCH`
New two-slot body (main-hand slot 16, off-hand slot 17). The classic dual-apply pattern
executes in one click and harmlessly no-ops when the off-hand can't take an enhancement
(2H weapon, shield, or empty off-hand):

```
#showtooltip
/use item:<id>
/use 16
/use item:<id>
/use 17
```

Add a small per-category body-builder hook so only `WPN_ENCH` deviates from
`buildActiveBody`; all other categories keep the current path. Body length is well under
the 255-byte cap (~50 bytes with a 6-digit itemID). Combat-deferral and oversized-body
fallback behavior are unchanged.

## Spec-aware integration

`WPN_ENCH` is the **4th** spec-aware category (after Flask, Combat Potion, Stat Food).
It uses the same per-spec `bySpec` priority buckets and the shared Stat Priority page.

- Update `settings/StatPriority.lua` copy: "drives the three spec-aware categories" →
  four (Stat Food, Combat Potion, Flask, Weapon Enchant).
- **Verify** spec-awareness is driven by the `specAware` flag everywhere (Selector,
  settings page generation, slash `/cm priority`/`/cm stat`), not by a hardcoded count
  of three. Fix any hardcoded assumption found.

## Seed defaults

Two new files following the existing `defaults/Defaults_*.lua` shape, added to the TOC in
load order alongside the other `Defaults_*`:

- `defaults/Defaults_Vantus.lua` — seeded with the current-tier rune (`245880`, extend).
- `defaults/Defaults_WpnEnch.lua` — seeded with a few current Midnight oils (itemIDs
  gathered during implementation; may start minimal since auto-discovery fills the rest).

## Localization (`locales/enUS.lua`)

Add display strings for the two categories and any new settings copy, following the
existing `KCM.L` keys.

## Files touched

**Code**
- `defaults/Categories.lua` — two new rows
- `core/Classifier.lua` — `WPN_ENCH` subType matcher, `VANTUS` itemID whitelist
- `modules/Ranker.lua` — `WPN_ENCH` + `VANTUS` scorers, `Explain` branches
- `modules/MacroManager.lua` — per-category body hook for the `WPN_ENCH` two-slot body
- `defaults/Defaults_Vantus.lua`, `defaults/Defaults_WpnEnch.lua` — new seed files
- `settings/StatPriority.lua` — spec-aware-count copy
- `locales/enUS.lua` — new strings
- `ConsumableMaster.toc` — load-order entries for the two new defaults files

**Tests** (`tests/`)
- Classifier: oil → `WPN_ENCH`; rune → `VANTUS`; negatives (flask/food/potion not
  misclassified as either; a non-vantus item not matched by the whitelist)
- Ranker: spec-aware weapon pick honors stat priority; vantus prefers higher tier
- MacroManager: `WPN_ENCH` two-slot body is well-formed and under 255 bytes; `VANTUS`
  uses the default body
- Regenerate `docs/test-cases.md` (`--list`) and bump the README `[Tests]` badge in the
  same change (Hard rule)

**Docs**
- `README.md` — macro table (add 2 rows), "eight categories" phrasing → ten, category
  counts; keep it player-facing
- `docs/` category references — a `wow-addon:sync-docs`-style consistency pass
- `[WoW]`/`[Tests]` badges unchanged except the test count

## Open items to confirm during implementation

1. Midnight weapon-oil `GetItemInfoInstant` subType string (`ST_WEAPON_OIL`).
2. Current-tier Vantus rune itemID(s) beyond `245880`.
3. Any weapon oils that are proc-only (no secondary stat) and whether the pin fallback is
   acceptable for them (expected: yes).

## Non-goals

- Other categories from issue #2 (jumper cables, drums, invis pots) — separate work.
- Off-hand vs main-hand *selection* logic — the macro applies to both slots and lets the
  client no-op invalid ones; no dual-wield/2H detection in code.
- Applying weapon enhancements in combat — unchanged; only the macro *write* defers in
  combat, as today.
