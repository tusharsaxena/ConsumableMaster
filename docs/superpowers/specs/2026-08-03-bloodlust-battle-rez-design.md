# Bloodlust & Battle Rez categories — design

**Issue:** [#10](https://github.com/tusharsaxena/ConsumableMaster/issues/10) — Add Bloodlust and Battle Rez macro categories
**Date:** 2026-08-03
**Status:** approved design, not yet planned

## Goal

Two new managed categories, `BLOODLUST` and `BATTLE_REZ`, each resolving to the character's own
ability when it has one and falling back to a usable item in bags when it doesn't — so one button
per effect works on every class, spec and faction.

## What already works

Most of the issue's "not purely bag-scanned" concern is already solved. Seed lists may mix item IDs
with spell sentinels (`KCM.ID.AsSpell`, precedent: Recuperate in `defaults/Defaults_Food.lua:23`),
`Selector.PickBestForCategory` filters spell entries through `IsPlayerSpell`
(`modules/Selector.lua:243`), `Ranker` sorts spells ahead of items via `SPELL_SCORE`
(`modules/Ranker.lua:300`), and `MacroManager.buildActiveBody` already emits `/cast <name>` for a
spell pick and `/use item:<id>` for an item pick (`modules/MacroManager.lua:58`). Spell-first with
item fallback is therefore the default behavior of the existing pipeline, not new machinery.

Four things are genuinely new: **max-level caps**, **Primal Rage living in the pet spellbook**, a
**targeting clause** on the generated body, and the fact that the usability gate is presently
diagnostic-only.

## Game data

### Bloodlust — spells

| Spell | ID | Source | Notes |
|---|---|---|---|
| Bloodlust | 2825 | Shaman (Horde) | 30% haste, 40 s |
| Heroism | 32182 | Shaman (Alliance) | identical to Bloodlust |
| Time Warp | 80353 | Mage | |
| Fury of the Aspects | 390386 | Evoker | |
| Harrier's Cry | 466904 | Hunter, Marksmanship only | ordinary player spell |
| Primal Rage | 272678 | Hunter BM / Survival, Ferocity pet | **pet spellbook — `IsPlayerSpell` is false** |

Ancient Hysteria and Netherwinds are excluded: they were folded into Primal Rage years ago and are
no longer distinct abilities.

### Bloodlust — items (drums)

All 15% haste (Drums of Battle 14%), 40 s, sharing the lust lockout. Each stops affecting players
above a cap, which is why an old drum in bags must not be picked at max level.

| Drum | Expansion | Affects up to |
|---|---|---|
| Void-Touched Drums (244639) | Midnight | current cap |
| Thunderous Drums | The War Within | 70 |
| Timeless Drums | Dragonflight | 70 |
| Feral Hide Drums | Dragonflight | 70 |
| Drums of Deathly Ferocity | Shadowlands | 60 |
| Drums of the Maelstrom | Battle for Azeroth | 60 |
| Drums of the Mountain | Legion | 50 |
| Drums of Fury | Warlords of Draenor | 50 |
| Drums of Rage | Mists of Pandaria | 50 |
| Drums of Battle | Burning Crusade | 50 |

The full line ships, not just the current one: with cap parsing in place the obsolete drums are
filtered out automatically at max level, and they remain genuinely useful while leveling or in
Timewalking.

### Battle Rez

| Spell | ID | Class |
|---|---|---|
| Rebirth | 20484 | Druid |
| Raise Ally | 61999 | Death Knight |
| Intercession | 391054 | Paladin |
| Soulstone | 20707 | Warlock — pre-cast on a **living** ally |

| Item | ID | Notes |
|---|---|---|
| Emergency Soul Link | 248486 | Midnight, Consumable / Explosives and Devices. 35% health, 10% mana, castable in combat, no profession required. Tooltip: "Cannot be used by players higher than level 90." |

The Gnomish Army Knife / Goblin Jumper Cables line is excluded — those are out-of-combat only, so
they would resolve to a button that cannot be pressed when it matters.

**Every ID above comes from wiki and database sources, not from a live client.** Each must be
confirmed with `/cm dump item <id>` (items) and an in-game spell check before the seeds are
considered final. That verification is a manual step the implementer cannot perform alone.

## Design

### 1. Category rows and seeds

Two rows appended to `KCM.Categories.LIST` in `defaults/Categories.lua`:

```lua
{ key="BLOODLUST",  macroName="KCM_BLOODLUST",  displayName="Bloodlust",  shortName="Lust",
  specAware=false, rankerKey="BLOODLUST",
  emptyText=emptyMacro("no bloodlust available") },

{ key="BATTLE_REZ", macroName="KCM_BATTLE_REZ", displayName="Battle Rez", shortName="Brez",
  specAware=false, rankerKey="BATTLE_REZ",
  targeted="[@mouseover,help][@target,help]",
  emptyText=emptyMacro("no battle rez available") },
```

Both macro names are inside the 16-character `GetMacroIndexByName` limit (13 and 14).

Neither is spec-aware. Nothing here varies per spec in a way a per-spec priority list would express:
Harrier's Cry versus Primal Rage is settled by spell availability, not by a user-ordered list.

Seeds are `defaults/Defaults_Bloodlust.lua` (`KCM.SEED.BLOODLUST`) and
`defaults/Defaults_BattleRez.lua` (`KCM.SEED.BATTLE_REZ`), spells first, then items newest-first.

### 2. Max-level caps — `core/TooltipCache.lua`

Two new `PATTERNS` entries feeding a parsed `maxLevel` field, mirroring the existing `minLevel`:

- the self-restriction phrasing — "Cannot be used by players higher than level N" (confirmed
  verbatim from the Emergency Soul Link tooltip);
- the drums' affects-allies-up-to phrasing.

The exact drums string must be read off a live tooltip with `/cm dump item <id>` before the pattern
is written; it is not reproduced reliably by the wiki. Both patterns go through
`normalizeTooltipText` like every other pattern, so non-breaking spaces and `|4` grammar escapes are
handled.

`TC.IsUsableByPlayer` grows the upper bound beside the existing lower one, returning a
`"level %d > %d"` reason string in the same shape `/cm dump item` already prints.

This is English tooltip-text parsing, and so falls under the addon's existing tracked
English-only deviation (`docs/scope.md`) rather than introducing a new one.

### 3. Usability gate reaches the pick path — `modules/Selector.lua`

`IsUsableByPlayer` is presently called from exactly one place, the `/cm dump item` diagnostic
(`core/SlashCommands.lua:342`). Nothing in the pick path consults it, so today neither the new
`maxLevel` nor the existing `minLevel` would affect what gets picked.

`PickBestForCategory` and `isAvailable` will consult it for **every** item candidate, in all
categories. This also closes the pre-existing hole where a leveling character can have an
unusable, too-high-level flask picked and written into a macro.

**Pending tooltips must not be treated as unusable.** `IsUsableByPlayer` returns `false, "pending"`
for an item whose tooltip has not hydrated, and dropping those would make picks flap during load.
The gate rejects a candidate only on a definite level verdict; a `"pending"` reason leaves the
candidate in place, matching how `Ranker` already tolerates pending entries.

### 4. Class-gated spells — Primal Rage

Primal Rage is a pet ability, so `IsPlayerSpell(272678)` is false for every character including
hunters. Rather than add a pet-spellbook seam and the `UNIT_PET` / `PET_SPECIALIZATION_CHANGED`
recompute triggers it would need, availability is decided from seed data:

```lua
KCM.SEED.CLASS_GATE = { [KCM.ID.AsSpell(272678)] = "HUNTER" }
```

`Selector`'s spell-availability path falls back to this table when `IsPlayerSpell` says no: the
entry is available if and only if the gate names the player's class. Roughly ten lines, no new API
seam, no new events, and a future pet-granted lust needs only a seed edit.

**Accepted cost, decided deliberately:** a hunter with no pet out, a non-Ferocity pet, or a Lone
Wolf build will still see Primal Rage as the Bloodlust pick, and pressing it does nothing. The
macro bar will show it as available. This was chosen over pet-spellbook detection to keep the
change small; if it proves annoying in play, the gate table is the single place that would grow a
pet check.

### 5. Targeting clause — `modules/MacroManager.lua`

A category row may carry a `targeted` conditional string. When present, `buildActiveBody` splices it
into both forms:

```
#showtooltip
/cast [@mouseover,help][@target,help] Rebirth

#showtooltip
/use [@mouseover,help][@target,help] item:248486
```

`/use` accepts `@unit` conditionals, so the item form needs no special case.

The clause deliberately omits `,dead`. Soulstone is cast on a **living** ally, and `help` already
matches dead friendly units, so a single clause serves both the rez spells and Soulstone. Adding
`,dead` would break Soulstone.

Composite bodies are unaffected — neither new category is a composite, and neither is referenced by
one.

### 6. Configurable targeting

The clause is on by default and switchable off, stored at
`db.profile.categories.BATTLE_REZ.mouseover` (default `true`), rendered as a checkbox on the Battle
Rez category tab in `settings/Category.lua`. When off, `buildActiveBody` emits today's plain body.
Toggling it fires a recompute so the macro rewrites immediately.

The setting is read in `MacroManager`, not baked into the category row, so the row's `targeted`
string stays the static default and the profile holds the user's choice.

### 7. Ranker

`BLOODLUST`: spells outrank items already via `SPELL_SCORE`. Among items, score on parsed
`maxLevel` so the most current drum the player owns wins — a single additive term, with a matching
`Ranker.Explain` branch.

`BATTLE_REZ`: one seeded item, so the scorer is a constant; the `Explain` branch reports that
plainly rather than inventing terms.

### 8. Plumbing

- `ConsumableMaster.toc` — both `Defaults_*.lua` in the `# Defaults` section, after `Categories.lua`.
- `dbDefaults.profile.categories` in `core/ConsumableMaster.lua` — non-spec buckets
  (`added` / `blocked` / `pins` / `discovered`) for both, plus `mouseover = true` on `BATTLE_REZ`.
- `settings/Panel.lua` — both keys into `KCM.Settings.order` and `_validPanels`.
- `dbDefaults.profile.macroBar.order` — appended in the same position as the tab order, or
  `tests/test_macrobar.lua` fails on the drift.
- `core/Classifier.lua` — matchers for both keys. Neither effect has a distinguishing consumable
  subclass (drums and Emergency Soul Link sit in broad buckets shared with bombs and toys), so the
  matchers return false: these categories are seed-plus-user-added, with no auto-discovery. This is
  a deliberate choice, recorded here so a future reader does not read it as an oversight.
- README category count and the docs that enumerate categories (`docs/ARCHITECTURE.md` opening
  paragraph, `docs/module-map.md`, `defaults/README.md`).

### 9. Tests

Headless coverage to add:

- `TooltipCache`: both cap phrasings parse into `maxLevel`; a tooltip with no cap yields no cap.
- `IsUsableByPlayer`: rejects above cap with the right reason, accepts at exactly the cap, still
  rejects below `minLevel`, and reports `"pending"` unchanged.
- `Selector`: an over-cap item is neither picked nor listed as available; a `"pending"` item is
  **not** dropped; the class gate admits Primal Rage for a hunter and rejects it for everyone else.
- `MacroManager`: the targeting clause appears in both the spell and item bodies, and disappears
  when `mouseover` is false.
- `Ranker`: drums order newest-cap-first; `Explain` returns rows for both new keys.
- `test_macrobar.lua`: the existing order-drift assertion covers the two new slots once
  `macroBar.order` is updated.

The `[Tests]` badge and `docs/test-cases.md` are regenerated in the same change, per the CLAUDE.md
hard rule.

### 10. Manual verification (cannot be done headlessly)

- `/cm dump item <id>` on every seeded item to confirm the ID, the cap phrasing and the parse.
- Confirm each spell ID resolves on a character of that class.
- Confirm the Battle Rez macro rezzes a mouseover'd raid-frame corpse, and that the Soulstone case
  works on a living ally with the same body.
- Confirm a hunter's Bloodlust slot shows Primal Rage, and a Marksmanship hunter's shows
  Harrier's Cry.
- Confirm an old drum in bags is not picked at max level, and is picked on a low-level character.

## Standards

No deviation from the Ka0s WoW Addon Standard is introduced. The new `targeted` category field and
the `CLASS_GATE` seed table are addon-internal data shapes in the same spirit as the existing
`perHand` and `composite` fields. The tooltip-text parsing extends the already-tracked English-only
deviation rather than creating a new one.

## Decisions taken

| Question | Decision |
|---|---|
| How to enforce the drums cap | Parse it from the tooltip |
| Battle Rez targeting | Mouseover-then-target, configurable off |
| Primal Rage | Class-gated seed entry, no pet-spellbook detection |
| Soulstone | Included |
| Legacy pet lusts (Ancient Hysteria, Netherwinds) | Excluded |
| Old level-capped drums | Included — the cap filter makes them safe |
| Out-of-combat rez items | Excluded |
| Usability-gate scope | All categories, not just the new two |
| Auto-discovery | Off for both — no reliable classifier signature |
