# Bloodlust / Battle Rez — in-game verification checklist

Standalone checklist for the human to work through at the keyboard. Covers Steps 1–5 of
`docs/superpowers/sdd/2026-08-03-bloodlust-battle-rez/task-7-brief.md`, which an agent cannot
do (no running WoW client). Nothing here has been verified yet — the seed IDs below are
wiki-sourced guesses, not confirmed data. Work through it top to bottom; tick as you go.

You do NOT need to have read the plan or any other doc to use this file.

---

## 0. Setup

- Load characters that cover: Shaman, Mage, Evoker, Marksmanship Hunter, BM or Survival
  Hunter, Druid, Death Knight, Paladin, Warlock, plus at least one class with **no** lust
  ability and no rez spell (e.g. Rogue, Warrior).
- Enable chat errors so a bad ID or a Lua error doesn't pass silently: `/console scriptErrors 1`.
- Have `/cm debug on` running in a spare chat window.

---

## 1. Verify every seeded item/spell

For each row below, run the command in the **Check** column and tick when the **name**
matches the comment in the seed file and the ID resolves as expected. For items, also read
the `usable:` line the dump prints (shows `minLevel` and your level).

### `defaults/Defaults_Bloodlust.lua` — `KCM.SEED.BLOODLUST`

| ID | Kind | Expected name | Check | ✓ |
|----|------|----------------|-------|---|
| 2825 | Spell | Bloodlust (Shaman, Horde) | `/cast Bloodlust` on a Horde Shaman, or `/dump C_Spell.GetSpellName(2825)` | [ ] |
| 32182 | Spell | Heroism (Shaman, Alliance) | `/dump C_Spell.GetSpellName(32182)` | [ ] |
| 80353 | Spell | Time Warp (Mage) | `/dump C_Spell.GetSpellName(80353)` | [ ] |
| 390386 | Spell | Fury of the Aspects (Evoker) | `/dump C_Spell.GetSpellName(390386)` | [ ] |
| 466904 | Spell | Harrier's Cry (Hunter, Marksmanship) | `/dump C_Spell.GetSpellName(466904)` | [ ] |
| 272678 | Spell | Primal Rage (Hunter pet, Ferocity) | `/dump C_Spell.GetSpellName(272678)` — lives in the **pet's** spellbook, not the player's | [ ] |
| 244639 | Item | Void-Touched Drums (Midnight) | `/cm dump item 244639` | [ ] |

**Superseded drums** — currently a placeholder comment in the seed file, no IDs collected
yet. See Section 3 below to fill these in.

### `defaults/Defaults_BattleRez.lua` — `KCM.SEED.BATTLE_REZ`

| ID | Kind | Expected name | Check | ✓ |
|----|------|----------------|-------|---|
| 20484 | Spell | Rebirth (Druid) | `/dump C_Spell.GetSpellName(20484)` | [ ] |
| 61999 | Spell | Raise Ally (Death Knight) | `/dump C_Spell.GetSpellName(61999)` | [ ] |
| 391054 | Spell | Intercession (Paladin) | `/dump C_Spell.GetSpellName(391054)` | [ ] |
| 20707 | Spell | Soulstone (Warlock; pre-cast on a living ally, not a rez-on-death) | `/dump C_Spell.GetSpellName(20707)` | [ ] |
| 248486 | Item | Emergency Soul Link (Midnight; usable by anyone, in combat) | `/cm dump item 248486` | [ ] |

**If any name doesn't match:** the ID is wrong. Fix it directly in the relevant
`defaults/Defaults_*.lua` file (comment + numeric ID together) — this is a one-line data
change, not a code change. Do not touch `core/` or `modules/` for a wrong ID.

**If a spell ID resolves to nothing (`nil` / "Unknown"):** double check it isn't gated —
Primal Rage in particular will read as unknown unless queried while the hunter has a
Ferocity pet out, or via `C_Spell.GetSpellName` which should work regardless.

---

## 2. Reconcile the drums cap wording

`core/TooltipCache.lua`'s `PATTERNS` table currently matches exactly two max-level cap
phrasings (both anchored on a bare trailing number):

```lua
maxLevelHigher = "higher than level (%d+)",   -- e.g. "Cannot be used by players higher than level 90."
maxLevelAbove  = "above level (%d+)",         -- e.g. "Does not affect allies above level 50."
```

`maxLevelAbove` is the one written for drums — it was designed against the pattern
"Does not affect allies above level 50." (see `tests/test_tooltipcache.lua`, the case
`TooltipCache: parses a drums 'above level' affect cap`).

**Steps:**

1. `/cm dump item 244639` (Void-Touched Drums) and read the full tooltip block the dump
   prints, and the `usable:` line specifically.
2. Copy the **exact** cap sentence out of the tooltip, verbatim, punctuation included.
3. Compare it against `maxLevelAbove` above.
   - **Matches** (contains `"above level <N>"` somewhere in the sentence): nothing to do,
     tick and move on.
   - **Doesn't match**: this is a real code change, not just data. Do NOT guess a third
     pattern speculatively — add only the phrasing you actually captured.
     - Add a new named pattern to `PATTERNS` in `core/TooltipCache.lua`, next to
       `maxLevelHigher` / `maxLevelAbove`.
     - Wire it into the `or` chain at the call site (`core/TooltipCache.lua`, search for
       `PATTERNS.maxLevelHigher or ... PATTERNS.maxLevelAbove` — currently around line 310).
     - Add a new test case to **`tests/test_tooltipcache.lua`**, using the exact captured
       line as the test's tooltip text (follow the shape of the existing
       `TooltipCache: parses a drums 'above level' affect cap` case).
     - Run `lua5.1 tests/run.lua` — this bumps the passing count, so also update the
       `[Tests]` README badge and regenerate `docs/test-cases.md`
       (`lua5.1 tests/run.lua --list > docs/test-cases.md`) per `CLAUDE.md`'s Hard Rule on
       static badges.
4. Repeat step 1–3 for every superseded drum you collect in Section 3 — older drums may use
   older phrasing.

---

## 3. Collect the superseded drums itemIDs

`defaults/Defaults_Bloodlust.lua` currently ships only Void-Touched Drums (244639, Midnight)
plus a placeholder comment:

```lua
-- Superseded drums, kept for levelling and Timewalking; the level-cap
-- filter removes them at max level.
-- (The War Within / Dragonflight / Shadowlands / BfA / Legion / WoD / MoP / TBC
--  itemIDs go here, newest first, once confirmed with /cm dump item.)
```

Collect one drum itemID per expansion below (vendor, auction house, or an item already in
your bags/bank). Confirm each with `/cm dump item <id>` before adding it.

| Expansion | Drum name (expected) | ItemID | Confirmed via | ✓ |
|-----------|----------------------|--------|----------------|---|
| The War Within | (varies — check current AH/vendor) | | | [ ] |
| Dragonflight (drum #1, newer) | | | | [ ] |
| Dragonflight (drum #2, older) | | | | [ ] |
| Shadowlands | Drums of Deathly Ferocity | | | [ ] |
| Battle for Azeroth | Drums of Fury | | | [ ] |
| Legion | Drums of Fury (Legion tier, different ID) | | | [ ] |
| Warlords of Draenor | Drums of the Mountain | | | [ ] |
| Mists of Pandaria | Drums of Rage | | | [ ] |
| Burning Crusade | Drums of Forgotten Kings / Drums of the Wild (verify which grants haste) | | | [ ] |

**Once collected:** add them to `KCM.SEED.BLOODLUST` in `defaults/Defaults_Bloodlust.lua`,
**newest first**, replacing the placeholder comment, each with a `-- <Name> (<Expansion>)`
comment. This is a pure data change.

**Cross-check against Section 2:** as you add each drum, run its cap-wording check too — if
any expansion's drum phrases its cap differently from `"above level <N>"`, that's a second
data point for the pattern reconciliation, not a separate bug.

---

## 4. Verify the picks

Tick each independently — these are Selector / Ranker behavior checks, not data checks. A
failure here (wrong class picks the wrong thing, given correct seed data) is a **code**
issue in `modules/Selector.lua` or `modules/Ranker.lua`, not a seed fix.

- [ ] **Shaman**: Bloodlust resolves for Horde, Heroism for Alliance. (`KCM_BLOODLUST`)
- [ ] **Mage**: Time Warp resolves.
- [ ] **Evoker**: Fury of the Aspects resolves.
- [ ] **Marksmanship Hunter**: Harrier's Cry resolves.
- [ ] **BM or Survival Hunter**: Primal Rage resolves (needs a Ferocity pet summoned — this
      exercises `KCM.SEED.CLASS_GATE`, `modules/Selector.lua:258`). If Primal Rage does
      **not** resolve for these specs, first check whether a Ferocity pet is out; if it is
      and it still fails, that's a `CLASS_GATE` bug.
- [ ] **A class with no lust ability**, drums in bags, no lust spell available: the drums
      resolve.
- [ ] **The same character at max level, with ONLY an old capped drum in bags** (no
      Midnight drums, no lust spell): the `KCM_BLOODLUST` slot shows the **empty state**
      (cooking-pot icon / `emptyText`), not the dead drum. This is the level-cap filter
      (`TooltipCache.IsUsableByPlayer`) doing its job — if the dead drum resolves instead,
      that's a regression in the cap filter or in `Selector`'s usability gate, a code bug.
- [ ] **Druid**: Rebirth resolves. (`KCM_BATTLE_REZ`)
- [ ] **Death Knight**: Raise Ally resolves.
- [ ] **Paladin**: Intercession resolves.
- [ ] **Warlock**: Soulstone resolves (pre-cast on a living ally — confirm this doesn't
      require a corpse present, since Soulstone is deliberately not death-gated).
- [ ] **Any class with no rez spell**, Emergency Soul Link in bags: the item resolves.

---

## 5. Verify the macro bodies

- [ ] `/cm dump pick BLOODLUST` — read the priority list and the resolved pick. Open the
      `KCM_BLOODLUST` macro in the macro UI and confirm its body matches the dump.
- [ ] `/cm dump pick BATTLE_REZ` — same, for `KCM_BATTLE_REZ`.
- [ ] **Mouseover targeting.** With the "Cast on mouseover" checkbox checked (default) on
      the Battle Rez settings page, confirm the macro body contains
      `[@mouseover,help][@target,help]`. Hover a dead raid member's frame with **no** unit
      selected as your target, and confirm the macro rezzes that corpse (not your current
      target, since you have none).
- [ ] **Toggle off.** Uncheck "Cast on mouseover". Confirm the body loses the
      `[@mouseover,help]` clause (body should read `[@target,help]` alone, or equivalent).
      Select a valid target and confirm the macro now acts on your **target**, ignoring
      whatever your mouse is over.
- [ ] Re-check the toggle back on and confirm the clause returns.

**If the toggle doesn't change the body:** check `db.profile.categories.BATTLE_REZ.mouseover`
directly (`/cm get` doesn't cover it — it's not a schema row, see
`modules/MacroManager.lua:73` and `settings/Category.lua:319-325`) — a code bug in that
wiring, not a data issue.

---

## What's cheap vs. what's a real fix

- **Cheap (data only, no code change, no re-review needed):** a wrong itemID/spellID in
  either `Defaults_*.lua` file; missing superseded-drums entries; a name that doesn't match
  the seed comment.
- **Needs a code change (flag it, don't just patch and move on):**
  - A drum's live cap wording doesn't match `maxLevelHigher` / `maxLevelAbove` — see
    Section 2. Touches `core/TooltipCache.lua` and adds a `tests/test_tooltipcache.lua`
    case. This also moves the `[Tests]` badge count per `CLAUDE.md`.
  - A max-level character with only a dead drum shows the drum instead of the empty state —
    means the level-cap filter or `Selector`'s usability gate regressed.
  - Primal Rage doesn't resolve for BM/Survival with a pet out — means `CLASS_GATE`
    resolution broke.
  - The mouseover checkbox doesn't change the macro body — means the `mouseover` wiring in
    `MacroManager` / `settings/Category.lua` broke.
  - Any Lua error during any of the above — always a code bug, report the full error text.
