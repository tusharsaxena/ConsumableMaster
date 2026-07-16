# Design — Weapon-aware, per-hand Weapon Enchant

**Date:** 2026-07-15
**Follows:** the `WPN_ENCH` category shipped in commit `8f7d238` (issue #2). Approved design; pending plan.

## Problem

`WPN_ENCH` today resolves **one** pick and applies it to both weapon slots, with two defects confirmed in-game:

1. **Attack Power is invisible to the scorer.** Whetstones/weightstones grant "Attack Power" (dumps: Refulgent Whetstone `237370` "Sharpens your bladed weapon, increasing Attack Power by 10"; Refulgent Weightstone `237369` "Balances your blunt weapon, increasing Attack Power by 15"). "Attack Power" isn't a parsed stat, so these score 0 and rank below secondary-stat oils — wrong for a physical spec. (Note: "Algari Mana Oil" `224107` is a misnomer — it grants Crit+Haste, not a caster stat. The only scoring bug is unparsed AP/SP.)
2. **No weapon-type awareness.** A whetstone only applies to a **bladed** weapon, a weightstone to a **blunt** one (tooltips say so literally). The macro blindly `/use`s the top pick on slots 16 and 17, so a whetstone on a mace silently fails, and there's no independent main/off-hand choice.

## Goal

Make `WPN_ENCH` score Attack Power / Spell Power by role, and pick the **best applicable enhancement independently for each equipped weapon**, building a per-slot macro. Recompute when weapons change.

## Design

### 1. Scoring — parse & weight AP / SP (`TooltipCache`, `Ranker`)

- **`TooltipCache`**: add `Attack Power → AP` and `Spell Power → SP` to `STAT_TOKENS` (place before single-word stats so they don't shadow). These flow into `statBuffs`/`hasStatBuff` like any stat.
- **`Ranker.statWeight`**: add role mapping ahead of the existing primary/secondary checks —
  ```lua
  if stat == "AP" then return (p == "STR" or p == "AGI") and PRIMARY_WEIGHT or 0 end
  if stat == "SP" then return (p == "INT") and PRIMARY_WEIGHT or 0 end
  ```
  So an AP enhancement ranks at **primary-throughput** level for STR/AGI specs (and 0 for casters); SP/Int for casters. `Int` already resolves correctly via the existing primary check. Users can still pin a secondary-stat oil above an AP stone.
  This lives in the shared `statWeight`; flask/food/combat-pot items never carry AP/SP buffs, so they're unaffected.

### 2. Weapon-type compatibility

- **Enhancement affinity (`TooltipCache`)**: while detecting `isWeaponEnhance`, also set `tt.weaponAffinity`: `"bladed"` if the line matches `your%s...bladed...weapon`, `"blunt"` if `blunt`, else `"any"` (oils). Reuse the same `"your [%a%s%-]-weapon"` region and inspect the adjective.
- **Equipped-weapon affinity (new `core/WeaponSlots.lua`)**: `WeaponSlots.SlotAffinity(slot)` (slot 16/17) → reads `GetInventoryItemID("player", slot)` → `GetItemInfoInstant` subType → maps to `"bladed"` / `"blunt"` / `nil`. Returns `nil` when the slot is empty, holds a non-enhanceable item (shield, off-hand frill, wand, ranged), or the weapon can't be classified.
  - **Subtype → affinity map** (English `itemSubType`):
    - **bladed**: One-/Two-Handed Swords, One-/Two-Handed Axes, Daggers, Polearms, Fist Weapons, Warglaives
    - **blunt**: One-/Two-Handed Maces, Staves
    - **none**: Wands, Bows, Crossbows, Guns, Shields, Held In Off-hand
  - ⚠️ Fist Weapons and Polearms are placed under **bladed** — flag for in-game confirmation (apply a whetstone to each and check it takes). One-line map change if wrong.
  - Isolated in its own module so it's mockable and has one responsibility (equipment inspection).
- **Compatibility rule**: an enhancement is eligible for a slot iff `slotAffinity ~= nil` **and** (`tt.weaponAffinity == "any"` or `tt.weaponAffinity == slotAffinity`).

### 3. Per-hand resolution (`Selector`)

- New `Selector.PickBestForSlot(catKey, slot, scoreCache)`: like `PickBestForCategory` but filters the effective-priority list to enhancements **eligible for `slot`'s weapon** (using affinity + `TooltipCache`), then returns the first eligible item the player owns. Returns `nil` if the slot has no enhanceable weapon or no owned eligible enhancement. Reuses `GetEffectivePriority` (spec-aware ranking) unchanged.
- `PickBestForCategory` stays as-is for every other category and for the settings list's overall ordering.

### 4. Per-hand macro (`Pipeline`, `MacroManager`)

- **`Pipeline.RecomputeOne`**: add a `cat.perHand` branch (a new flag on the `WPN_ENCH` category row), mirroring the existing `cat.composite` branch:
  ```lua
  if cat.perHand then
      local mh = KCM.Selector.PickBestForSlot(catKey, 16, scoreCache)
      local oh = KCM.Selector.PickBestForSlot(catKey, 17, scoreCache)
      return KCM.MacroManager.SetWeaponEnchantMacro(cat, mh, oh)
  end
  ```
- **`MacroManager.SetWeaponEnchantMacro(cat, mhPick, ohPick)`**: builds the body and routes through the same combat-defer / oversized-fallback / `doEdit` path `SetMacro` uses (factor the shared tail so both call it). Body:
  ```
  #showtooltip
  /use item:<mhPick>
  /use 16
  /use item:<ohPick>
  /use 17
  ```
  Each slot's two lines are emitted only when that slot has a pick; `#showtooltip` uses whichever pick exists (prefer MH). If neither slot has a pick, fall back to the category `emptyText` stub.
- The default two-slot `buildActiveBody(catKey=="WPN_ENCH")` shortcut from issue #2 is **removed** — the per-hand builder supersedes it (a single pick applied blindly to both slots is exactly the bug this fixes).

### 5. Recompute on weapon change (`Pipeline`, entry)

- Subscribe `PLAYER_EQUIPMENT_CHANGED` and, when the changed slot is 16 or 17, `RequestRecompute("equip")`. Debounced through the existing recompute-request seam. WPN_ENCH is the only weapon-dependent category, so a targeted `RecomputeOne("WPN_ENCH")` is acceptable if a full recompute is too heavy.

### 6. Settings UI (`settings/Category.lua`)

- Conservative first cut (avoid a full per-category-page rework):
  - The priority list still shows one ranked list (overall order from `GetEffectivePriority`).
  - Replace the single "picked in macro" star with **two markers** — a main-hand and an off-hand indicator — set on whichever rows `PickBestForSlot(16)` / `PickBestForSlot(17)` resolved.
  - Rows whose enhancement can't apply to **either** equipped weapon are dimmed / tagged "not usable with equipped weapon".
  - A one-line header note on the page shows the detected MH/OH weapon affinity (e.g. "Main hand: bladed · Off hand: (none)").
- Full per-hand editing (separate MH/OH priority lists) is **out of scope** for this pass — flagged as a possible follow-up.

### 7. Category metadata

- Add `perHand = true` to the `WPN_ENCH` row in `defaults/Categories.lua`. `RecomputeOne` routes on it; everything else keys off the existing `specAware` flag.

## Files touched

**Code**: `core/TooltipCache.lua` (AP/SP tokens, `weaponAffinity`), `modules/Ranker.lua` (`statWeight` AP/SP), `core/WeaponSlots.lua` (new), `modules/Selector.lua` (`PickBestForSlot`), `core/ConsumableMaster.lua` (`RecomputeOne` perHand branch, `PLAYER_EQUIPMENT_CHANGED`), `modules/MacroManager.lua` (`SetWeaponEnchantMacro`, drop the WPN_ENCH shortcut, factor shared tail), `defaults/Categories.lua` (`perHand`), `settings/Category.lua` (per-hand markers + affinity note), `ConsumableMaster.toc` (load `core/WeaponSlots.lua`).

**Tests**: TooltipCache (AP/SP parse; `weaponAffinity` from bladed/blunt/any), Ranker (AP→primary for STR/AGI, 0 for INT; SP mirror), WeaponSlots (subtype→affinity map incl. none cases; mockable equipment), Selector (`PickBestForSlot` filters by affinity + ownership), MacroManager (per-hand body: both/one/neither slot; empty fallback), Pipeline (perHand routing; equip-change recompute). Regenerate `docs/test-cases.md` + bump `[Tests]` badge.

**Docs**: README (weapon-enchant behavior + macro), `docs/ARCHITECTURE.md` (new module + event), `docs/agent-context.md`, `docs/data-model.md`, `docs/smoke-tests.md` (weapon-swap + per-hand cases).

## Open items to confirm in-game

1. Fist Weapons / Polearms bladed-vs-blunt (apply a whetstone; adjust the map).
2. Whether oils apply to ranged/wand slots (assumed no — those slots get no enhancement).
3. Exact `GetItemInfoInstant` subType strings for current weapons (the map keys on them; single-constant updates if Blizzard's wording differs).

## Non-goals

- Separate per-hand priority *editing* in the UI (this pass only marks the two picks + applicability).
- Enhancing thrown/ranged/wand weapons.
- Augment Rune category (tracked separately for later).
