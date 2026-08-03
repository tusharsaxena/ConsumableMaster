# Augment Rune category — Design

**Date:** 2026-07-16
**Status:** Approved (brainstorm complete; implementation plan to follow)

## Goal

Add `AUG_RUNE`, a managed macro category for augment runes, seeded across
Dragonflight (10.x), The War Within (11.x) and Midnight (12.x), and
auto-discovering any rune not in the seed. Reusable ("permanent") runes such as
Ethereal and Dreambound outrank consumable ones whenever doing so costs no
primary stat.

This is the 13th category (11 single-pick + 2 composite). It was previously
listed as out of scope in `docs/scope.md`; that line moves as part of this work.

## Background — what "permanent" actually means

The community calls Ethereal and Dreambound "permanent augment runes", but the
buff is *not* permanent. Ethereal's tooltip reads:

> Increases Primary Stat by 733 for 1 hour. Augment Rune. (1 Min Cooldown)

The buff still lasts 1 hour and is still lost on death. What is special is that
**the item is not consumed on use** — it stays in your bags and can be reused
forever. That is the whole reason to prefer it: it costs no gold per application,
not that it lasts longer.

This distinction drives the ranking rule below. An unconditional "reusable always
wins" would keep a character on TWW's Ethereal (733) after Midnight's
Void-Touched lands with a strictly larger number — trading raid throughput for
gold. That is a real regression, not a preference.

## Ranking rule

**Rank by primary-stat amount; break ties toward reusable.**

```
score = amount * AUG_STAT_WEIGHT      -- 1e4, dominates everything
      + (reusable and REUSABLE_BONUS or 0)   -- 1e3, outranks quality/ilvl
      + ilvl
      + quality * QUALITY_WEIGHT      -- existing 100; max 5*100 = 500 < 1e3
```

The weight ladder is what makes the rule hold:

| Comparison | Winner | Why |
|---|---|---|
| Ethereal 733 vs Crystallized 733 | Ethereal | tie on amount → reusable bonus |
| Ethereal 733 vs Void-Touched (larger) | Void-Touched | amount dominates |
| Dreambound 87 vs Draconic 80 | Dreambound | wins on amount *and* reusable |

`REUSABLE_BONUS` (1e3) must exceed the maximum quality contribution
(5 × `QUALITY_WEIGHT` = 500) so reusable genuinely breaks ties rather than being
overridden by an epic-quality consumable. `AUG_STAT_WEIGHT` (1e4) must exceed
`REUSABLE_BONUS` + max quality + ilvl so a single point of primary stat outweighs
reusability.

**Pending-tooltip behavior:** if the tooltip has not hydrated, `amount` is 0 for
every candidate, so the pick degrades to reusable-first, then quality/ilvl. The
pipeline recomputes when the tooltip arrives. This is the same
tooltip-dependency the FLASK / STAT_FOOD categories already have, and the
degraded pick is a sensible default rather than a wrong one.

## Classification — generic, seed-independent

Vantus matches on an explicit itemID list. That is wrong here: the category must
work for *all* augment runes, including future Midnight ones. So `AUG_RUNE`
follows the `WPN_ENCH` pattern — seeds cover the known runes, and a tooltip flag
auto-discovers the rest.

- `core/TooltipCache.lua` gains an `isAugmentRune` flag, set when a tooltip line
  is the augment-rune category marker (`Augment Rune`). This is the game's own
  one-at-a-time marker and is present on every rune.
- `core/Classifier.lua` gains an `AUG_RUNE` matcher returning
  `tt and tt.isAugmentRune == true`.

Seeds do **not** depend on this signal — they enter the candidate set via
`KCM.SEED` through `Selector.BuildCandidateSet`. So if the tooltip marker turns
out to be worded differently in-game, the seeded runes still work and only
auto-discovery is affected. That bounds the risk of the one unverified
assumption.

## Reusable detection — explicit ID set

There is **no tooltip signal for "not consumed on use"**; the tooltip is silent
about it. Reusability is therefore an explicit ID set in `core/Classifier.lua`,
mirroring the existing `VANTUS_IDS` precedent, exposed for the Ranker:

```lua
local REUSABLE_AUG_IDS = {
    [211495] = true,  -- Dreambound Augment Rune (DF 10.2)
    [243191] = true,  -- Ethereal Augment Rune   (TWW 11.2)
}
```

Cost: one line per future reusable rune. Accepted — the alternatives (stack-size
or item-class heuristics) are fragile and would fail silently.

Pre-Dragonflight permanents (Eternal, Lightning-Forged, Lightforged, Empowered)
are deliberately excluded. Their stat amounts are low enough that they lose on
amount regardless, so the entries would be dead weight.

## Parser change and its blast radius

`STAT_TOKENS` in `core/TooltipCache.lua` gains:

```lua
{ token = "Primary Stat", tag = "PRIMARY" },
```

Without it, the modern phrasing ("Increases Primary Stat by 733") matches no
token and every current rune parses as having no stat buff at all. The older
Dragonflight phrasing ("Increases your Strength, Agility, and Intellect by 80")
already parses today, yielding three entries (STR 80, AGI 80, INT 80).

**`Ranker.statWeight` deliberately keeps returning 0 for the `PRIMARY` tag.**
Midnight stat food and flasks likely share the "Primary Stat" phrasing, so
weighting it would silently move `STAT_FOOD` / `FLASK` rankings — a change nobody
asked for, in categories this work does not otherwise touch. The `AUG_RUNE`
scorer reads the amount directly off `statBuffs` and bypasses `statWeight`, so no
existing category's ranking moves.

Whether flasks and food *should* weight PRIMARY is a legitimate question, tracked
as a non-goal below rather than smuggled in here.

Amount resolution in the scorer:

1. the `PRIMARY` entry's amount, if present (modern runes); else
2. `max(STR, AGI, INT)` across `statBuffs` (Dragonflight-era runes); else
3. 0 (tooltip pending — see pending behavior above).

## Category metadata

Plain single-pick — the simplest shape in the addon. Not `specAware` (runes buff
all primary stats universally, so there is nothing to rank per spec), not
`composite`, not `perHand`. **No new pipeline path**, and no `MacroManager`
change: `buildActiveBody` already emits `#showtooltip\n/use item:%d` for the
default path.

```lua
{
    key         = "AUG_RUNE",
    macroName   = "KCM_AUG_RUNE",
    displayName = "Augment Rune",
    specAware   = false,
    rankerKey   = "AUG_RUNE",
    classifier  = "AUG_RUNE",
    emptyText   = emptyMacro("no augment rune in bags"),
}
```

`macroName` is 12 characters, inside the 16-char macro-name limit.

## Seed data (`defaults/Defaults_AugRune.lua`)

Verified 2026-07-16 against Wowhead/Warcraft Wiki:

| Rune | itemID | Expansion | Reusable | Primary stat |
|---|---|---|---|---|
| Void-Touched Augment Rune | 259085 | Midnight 12.0 | no | unconfirmed |
| Soulgorged Augment Rune | 246492 | TWW 11.2 | no | unconfirmed |
| Ethereal Augment Rune | 243191 | TWW 11.2 | **yes** | 733 |
| Crystallized Augment Rune | 224572 | TWW 11.0 | no | 733 |
| Dreambound Augment Rune | 211495 | DF 10.2 | **yes** | 87 |
| Draconic Augment Rune | 201325 | DF 10.0 | no | 80 |

Seed order is newest-expansion-first, matching the other seed files. Ranking is
by score, not seed order, so order is cosmetic.

## Files touched

- Create: `defaults/Defaults_AugRune.lua` — the only new file.
- Modify: `core/TooltipCache.lua` (token + `isAugmentRune`), `core/Classifier.lua`
  (matcher + `REUSABLE_AUG_IDS`), `modules/Ranker.lua` (scorer + `Explain`),
  `defaults/Categories.lua` (row), `core/ConsumableMaster.lua` (profile bucket),
  `settings/Panel.lua` (tab order), `ConsumableMaster.toc` (one line, after
  `defaults\Defaults_WpnEnch.lua`)

No new settings file: `settings/Category.lua` renders every category tab
generically off the metadata row, so the entire UI cost is adding `"aug_rune"` to
`KCM.Settings.order` (after `"wpn_ench"`, before the composites) and updating that
table's "the ten single categories" comment to eleven.
- Docs: `README.md` (category count + table), `docs/scope.md` (move augment runes
  out of the declined list), `docs/ARCHITECTURE.md`, `docs/smoke-tests.md`,
  `docs/test-cases.md` + `[Tests]` badge

## Testing

Headless (`tests/run.lua`):

- TooltipCache parses "Increases Primary Stat by 733" → `PRIMARY` 733
- TooltipCache sets `isAugmentRune` from the category-marker line, and does not
  set it for a flask/food tooltip
- Classifier routes a seeded rune and an unseeded rune to `AUG_RUNE`
- Ranker: Ethereal 733 beats Crystallized 733 (reusable tiebreak)
- Ranker: Void-Touched at a higher amount beats Ethereal 733 (amount dominates)
- Ranker: an epic-quality consumable does **not** override the reusable bonus at
  equal amount (guards the weight ladder)
- Ranker: pending tooltip → reusable-first rather than an error
- Regression: FLASK / STAT_FOOD scores are unchanged by the new PRIMARY token

Manual (`docs/smoke-tests.md`): rune in bags → `KCM_AUG_RUNE` body targets it;
Ethereal + Crystallized both in bags → Ethereal picked; blocking Ethereal falls
back to Crystallized.

## Open items to confirm in-game

Same class of open item as the weapon-affinity map — neither blocks the build.

1. That the tooltip category line is literally `Augment Rune`. If Blizzard's
   wording differs, it is a single-constant fix; seeded runes are unaffected.
2. Void-Touched (259085) and Soulgorged (246492) primary-stat amounts — no source
   stated them. They affect only ranking between runes the user owns, and the
   amount is read from the tooltip at runtime, so no code change is implied.

## Non-goals

- Weighting the `PRIMARY` tag in `STAT_FOOD` / `FLASK` ranking (would move
  existing categories; separate design discussion).
- A user-facing "prefer reusable" toggle. The chosen rule never costs stat, so
  there is nothing to opt out of.
- Pre-Dragonflight augment runes in the seed or the reusable set.
- Tracking rune charges / stock, or warning when a consumable rune runs out.
