# Bloodlust / Battle Rez — in-game verification checklist

Standalone checklist for the human to work through at the keyboard. Covers Steps 1–5 of
`docs/superpowers/sdd/2026-08-03-bloodlust-battle-rez/task-7-brief.md`, which an agent cannot
do (no running WoW client). Nothing here has been verified yet — the seed IDs below are
wiki-sourced guesses, not confirmed data. Work through it top to bottom; tick as you go.

You do NOT need to have read the plan or any other doc to use this file.

---

## -1. Highest-value check: confirm no existing consumable has become unpickable

`core/TooltipCache.lua`'s max-level-cap patterns (`maxLevelHigher` / `maxLevelAbove`) are
unanchored two-word substrings tested against **every tooltip line of every item in all 15
categories**, not just drums — the usability gate now runs for every category. A false
positive here is silent and severe: it deletes a working pick with no chat warning and no
visible cause, permanently, for as long as the character stays above the misread cap.

As of this fix wave, a match also requires a negation word on the same line (`Cannot` /
`Does not` / `can't` / `doesn't`), which rules out a floor phrased as "...above level N"
(e.g. "Usable by players above level 50.") inverting into a false ceiling. That closes the
known failure mode but only for phrasings we anticipated — do this check anyway.

**Steps:**
1. Log in on your highest-level character with a full bag/bank of consumables across every
   category (food, drink, pots, flasks, oils, runes, drums, etc.).
2. For each one, `/cm dump item <id>` and read the `usable:` line.
3. **What a false positive looks like:** an item you know works (you've used it, or it's a
   normal current-tier consumable) reports `usable: false` with a level-cap reason, or the
   item silently never appears as a pick / flyout entry despite being in bags. If you see
   this, capture the exact tooltip line — that phrasing needs to be excluded (e.g. it may
   need explicit exclusion, or the negation-word check may need to be tightened for that
   specific case) and this is a real code question, not something to patch around.

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

**While dumping 248486, also capture its exact `Use:` line verbatim.** The `hasParsedEffect`
guard in `core/TooltipCache.lua` (the `maxLevel` clause) currently assumes it reads
"restoring them to life with 35% health and 10% mana" — a screenshot capture, not a
`/cm dump` verified line — and that this phrasing matches none of the `PATTERNS` effect
forms (confirmed against the code, but not against a live client). If the live wording
differs, the reasoning in that comment needs rechecking — it may now parse an effect on its
own (fix is safe to reconsider) or the phrasing may need adding to `PATTERNS` (the "cleaner
long-term fix" the comment already names).

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

**Also carried by this fix wave:** a cap match now additionally requires a negation word
(`Cannot` / `Does not` / `can't` / `doesn't`) on the same line — see §-1 above. If a live
drums tooltip turns out to phrase its cap **without** one of those words, the cap will
silently stop being recognized (the item just won't be filtered — same as an uncapped item,
not a crash). That is a **code change** (extending the negation-word list or the cap
pattern in `core/TooltipCache.lua`, plus a `tests/test_tooltipcache.lua` case), not a data
change — flag it rather than working around it in the seed file.

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
- [ ] **BLOCKING — action-bar icon (Fix 3).** Drag `KCM_BATTLE_REZ` onto a **Blizzard action
      bar** (NOT the CM macro bar) and confirm it shows the spell/item icon, both with a
      friendly target selected and with none selected/moused-over. `[@mouseover,help]
      [@target,help]` is a non-exhaustive conditional set — with neither a friendly
      mouseover nor a friendly target (the resting state), nothing matches, and a bare
      `#showtooltip` would fall back to the `?` icon. The fix makes `#showtooltip` name the
      spell/item explicitly so this can't happen; this step confirms it in-game. **The CM
      macro bar cannot reveal this bug** — its buttons resolve their icon from the stored
      pick (`MD.Texture`), not from `#showtooltip`, so it will show the right icon either
      way. Only a real Blizzard action bar exercises the code path this fix touches.
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

## 6. Macro-bar UX changes (added after the review pass)

These two shipped on the same branch and have their own in-game checks. Neither is
covered by anything above.

### 6a. "Show GCD swipe" (default OFF)

The option lives on the Macro Bar settings page under **Button appearance**, or
`/cm get macroBar.showGCD` / `/cm set macroBar.showGCD true|false`.

- [ ] With it **off** (the default), cast any ability and watch the macro bar. The ~1.5s
      global-cooldown swipe should NOT paint across the buttons.
- [ ] Still off: use something with a real cooldown (a potion, or a spell slot like
      Bloodlust) and confirm the swipe AND the countdown numbers DO appear and animate.
- [ ] **Expected, not a bug:** the swipe fades out over the final ~1.6 seconds rather than
      running all the way to zero. The filter reads *remaining* time, and the total
      duration is a secret value in combat, so a 1.5s GCD and the last 1.5s of a 60s
      cooldown are indistinguishable. Accepted deliberately (same as KickCD).
- [ ] Turn it **on**. Confirm the GCD swipe comes back, and — importantly — that buttons
      which were mid-fade when you flipped it are at full opacity again, not stuck faded.
- [ ] Open a flyout (hover a button's top strip) during a GCD and confirm entries render
      the same way the bar slot does. Both go through `BB.ApplyCooldown`, so they must
      agree.
- [ ] **In combat.** Repeat the first two checks in an actual fight (a target dummy in a
      raid/M+ context if you can, since cooldown restriction keys off encounter state).
      This is the case the headless suite structurally cannot reach — out of combat the
      durations are plain numbers, in combat they are secret. A Lua error here means the
      curve path is comparing a secret somewhere.

### 6b. Buttons per row

- [ ] Macro Bar settings → **Layout** → confirm the "Buttons per row" slider now reaches
      **15**, and that a fresh profile defaults to 15 so all fifteen slots sit on one row.
- [ ] If you had previously set this to 13, expect it to read 15 now. AceDB does not store
      a value equal to the default, so a deliberate 13 chosen while 13 *was* the default
      was never saved. Set it back if you preferred it; it will stick this time.

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
  - The GCD swipe still paints with "Show GCD swipe" off, or a real cooldown's swipe never
    paints at all — means the curve/alpha path in `modules/MacroBarButton.lua` regressed.
  - Buttons stay faded after turning "Show GCD swipe" back on — means the `SetAlpha(1)`
    else-branch was lost.
  - Any Lua error during any of the above — always a code bug, report the full error text.
    In the GCD checks specifically, an error mentioning a secret or restricted value means
    something is comparing a duration in Lua instead of evaluating it through the curve.
