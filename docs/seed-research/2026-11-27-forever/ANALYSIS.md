# Analysis — WoW Forever seed lists, 2026-11-27 (build 1.60.1.71139)

GitHub issue #46. The owner lifted the 2026-11-08 ruling that WoW Forever's seed lists are empty by
decision, and asked for them to be built from offline stores, because no more in-game probe runs were
possible. This is the first Forever run that proposes candidates. It reads nine tables of the live
Forever build on wago.tools (product `wowf`, 1.60.1.71139), and three evidence stores, frozen as
`evidence.json` (`SOURCES.md` lists them and every id's sources):

| Source | What it said | Consumables it records |
| --- | --- | --- |
| ForeverDB 2026-11-27 (installed data addon, GPL-3.0) | vendor, drop, container, object, quest and recipe sources | 1146 |
| Auctionator (the largest Forever account's SavedVariables) | ids seen on the auction house | 812 |
| `ConsumableMasterProbeDB` (the owner's 2026-11-08 probe runs) | the auction-house scan and the Stormwind innkeeper | 497 |

ForeverDB is cited as evidence and none of its rows are copied: only "this id has a `<kind>` source"
reaches the bundle. Every candidate and ruling is in `RULINGS.md`. Claude made the rulings under the
owner's 2026-11-27 rulings and each seed file's header; the owner has not reviewed them yet.

## The rules

Forever's own (`FOREVER_RULES` in `tools/seeds/seeds.py`), written against its subclasses (Potion 1,
Elixir 2, Flask 3, Scroll 4, Food & Drink 5, Bandage 7, Other 8, Draught 13, temporary Item
Enhancement 15) and tables, never by filtering Retail's lists (`clients-§5`). Two things the 2026-11-15
run did not need:

- **Vanilla food and drink** regenerate through auras 84 and 85, not Retail's 20 and 21, so the
  Forever food rules read both.
- **An item a player can get.** Forever's DB2 holds many items the game never hands out. A window
  takes only an item some evidence records (DB2's create-item effect counts for healthstones alone,
  which a warlock conjures), and never one whose text confines it to a zone or battleground. `DIFF.md`
  lists the 59 DB2-only items and the 19 zone-restricted ones it left out, and 15 in-window potions no
  rule places (stoneshield, resistance and rage potions, purification, `[PH]` placeholders).

Each candidate is then placed in its **band group**, a ~10-level band by required level (a bandage by
its First Aid skill over five; a level-0 item by its item level less ten), per stat for `STAT_FOOD`,
`ELIXIR`, `SCROLL`, `FLASK` and `CMBT_POT`, per school for `PROT_POT` and per weapon kind for
`WPN_ENCH`, and ranked: an item a vendor sells or the auction house trades first, then the higher item
level, the bigger effect and the better source.

## What was accepted

212 of 483 candidates, the top of each group once the header rules were applied:

| List | Candidates | Accepted | Rejected: header rule | Rejected: behind the band's pick |
| --- | --- | --- | --- | --- |
| `FOOD` | 105 | 6 | 0 | 99 |
| `DRINK` | 22 | 6 | 0 | 16 |
| `HP_POT` | 19 | 6 | 7 | 6 |
| `MP_POT` | 14 | 6 | 1 | 7 |
| `HS` | 15 | 15 | 0 | 0 |
| `BANDAGE` | 12 | 5 | 0 | 7 |
| `FLASK` | 5 | 4 | 1 | 0 |
| `ELIXIR` | 80 | 54 | 12 | 14 |
| `CMBT_POT` | 30 | 19 | 11 | 0 |
| `PROT_POT` | 10 | 10 | 0 | 0 |
| `STAT_FOOD` | 119 | 41 | 9 | 69 |
| `SCROLL` | 31 | 25 | 3 | 3 |
| `WPN_ENCH` | 21 | 15 | 2 | 4 |

- **Food and drink:** the vendor staples of each band (Dalaran Sharp, Dwarven Mild, Stormwind Brie,
  Fine Aged Cheddar; Ice Cold Milk, Melon Juice, Sweet Nectar, Moonberry Juice), with Enriched Manna
  Biscuit in both lists at 40-49 (it restores both) and the mage's Conjured Cinnamon Roll and Crystal
  Water at 50-60.
- **Potions:** the Healing and Mana Potion ladders, with the Rejuvenation Potions where they are the
  band's top (they restore both, so they sit in both lists, as Retail's Refreshing Serum does).
- **Healthstones:** every rank, Minor to Major, with both Improved Healthstone variants of each (15
  ids). HS matches on `HEALTHSTONE_IDS` alone, so a rank left out would never be discovered: the
  VANTUS precedent of 2026-11-15. `HEALTHSTONE_IDS` is now one list per client, and `apply` wrote the
  same 15 into its Forever block.
- **Combat potions:** Forever's own Frenzy (attack power), Spellblasting (spell damage) and Mender's
  (healing) ladders, one per band, and Mighty Rage Potion. Dragonfire Potion and Potion of Venomous
  Blood were accepted at first and rejected in review (below).
- **Elixirs, scrolls, stat food:** one per stat per band, which is why these lists are the long ones.
- **Protection potions:** all ten: Holy and Shadow at 10-19, Fire, Frost and Nature at 20-29, and the
  five Greater ones at 40-49.
- **Weapon enchants:** the sharpening stone and weightstone ladders, Minor and plain Wizard Oil, Minor
  and Brilliant Mana Oil, Shadow and Frost Oil, and Elemental Sharpening Stone at 50-60. No poison: the
  Rogue poison category owns those.

## What was rejected for a header rule: 44

- **Utility** (`CMBT_POT`, `ELIXIR`, `SCROLL`, `FLASK`): Swiftness, Swim Speed, Invisibility, Free and
  Living Action, Restorative and Limited Invulnerability Potions; water breathing, detection, Dream
  Vision, Catseye, size and experience elixirs; a mana-restore, run-speed and language scroll; Flask of
  Petrification.
- **A heal with a drawback** (`HP_POT`): Forever's Discolored Healing Potions hand part of the heal back
  as damage over time, so the band's plain potion is seeded. Dreamless Sleep Potion puts the drinker to
  sleep.
- **Situational:** Potion of Demon Slaying, Consecrated Sharpening Stone and Blessed Wizard Oil
  (against demons or undead only).
- **No combat stat** (`STAT_FOOD`): Well Fed foods whose buff is zone movement speed or a fishing skill.

## Worth a look

- **CMBT_POT is grouped per stat.** The owner's ruling named `STAT_FOOD`, `ELIXIR`, `SCROLL` and `FLASK`
  as the stat-keyed lists. `CMBT_POT` is spec-aware like them, and one potion per band would have handed
  every band to the Mender's (healing) potion, so Claude grouped it per stat too. Grouping it per band
  alone would keep six of its 19.
- **WPN_ENCH is grouped per weapon kind,** for the same reason: the per-hand picker needs a stone for a
  blade, a weightstone for a mace and an oil for a caster.
- **Eight picks rest on ForeverDB alone**, with no vendor, auction-house or probe sighting: Elixir of
  Frost Power, Major Troll's Blood Elixir, Mageblood Elixir, Elemental Sharpening Stone and Brilliant
  Mana Oil (a recipe ForeverDB records), and three "Endless" elixirs (Intellect, Rapidity, Opportunity;
  level 1, a drop). They were first kept, as a not-owned row costs nothing; the owner ruled on
  2026-11-27 to drop them (see Review fixes).
- **Mage conjured food and water** (Conjured Bread to Sweet Roll, Conjured Water to Sparkling Water) are
  among the DB2-only items: no store records them, because they are conjured and never traded, and DB2's
  create-item effect counts for healthstones alone. If the owner wants them seeded like Retail's Conjured
  Mana Bun, the rule to change is `Build.sourced` (count a class conjure as a source for FOOD and DRINK).
- **Forever's new items.** WoW Forever ships consumables vanilla never had (the Discolored potions, the
  Frenzy, Spellblasting and Mender's ladders, the Cleric's, Mageblood and Owl elixirs, the teas and
  smoothies, the familiar scrolls). Their item levels do not always follow vanilla's ladder (a Lesser
  Spellblasting Potion at item level 5), so within such a ladder the band does the work.

## What a later run should re-check

- The Forever probe runs issue #46 still lists (another day's AH and the other faction's, the capitals'
  innkeepers, the trade, alchemy, cooking and first-aid suppliers, faction quartermasters, mouseover on
  drops): each adds evidence, and a re-derive with it may move a band's pick.
- Whether ForeverDB's recipe and drop records hold for the eight picks above.
- The Flasks of Natural Accuracy, Aggression, Precision and Swiftness (level 55) have no source yet;
  once one is sold or traded they enter the `FLASK` window.
- This bundle replays only at the revision before its `apply`: once the accepts ship, a re-derivation
  differs by design.

## Review fixes (2026-11-27, before merge)

- **Two combat potions rejected.** Dragonfire Potion (250953, a fire-damage cone) and Potion of
  Venomous Blood (250950, spreads a bleed) buff no stat. The stat reader took their "Fire damage" and
  "Nature damage" for school spell power, so each topped a one-item SP_FIRE / SP_NATURE group and was
  accepted. `Defaults_CombatPot.lua` seeds no utility potion, so both are now rejected in
  `tools/seeds/forever_rulings.json` and dropped from the seed. `forever_stat` now reads a school
  only after an increase verb ("Increases spell fire damage"), with a test. `candidates.json` and
  `SOURCES.md` stay as derived: their group notes for these two show the misread.
- **Healthstone rank order.** Retail's Ranker preference table gives 5512 a +100 bonus, and on Forever
  5512 is the Minor rank, so a Minor stone would outrank a Major one. `modules/Ranker.lua` now picks
  that table per client; Forever has no preference, and its ranks sort by item level (10 to 58).
- **Two Endless elixirs rejected (integrated review C4).** Elixir of Endless Intellect (289082) and
  Elixir of Endless Rapidity (289086) grant a percent buff, and Rapidity's is haste, which is not in
  Forever's stat set. Forever's stat parser cannot weigh either (`core/TooltipCache.lua`), so both are
  rejected in `tools/seeds/forever_rulings.json` and dropped from `Defaults_Elixir.lua`; the bags
  still find them.
- **ForeverDB-only picks dropped (owner ruling 2026-11-27).** The six remaining picks whose only
  evidence is ForeverDB (no vendor, auction-house or probe sighting) are rejected in
  `tools/seeds/forever_rulings.json` and dropped from the seed: Elixir of Frost Power (17708), Major
  Troll's Blood Elixir (20004), Mageblood Elixir (20007) and Elixir of Endless Opportunity (289087)
  from `Defaults_Elixir.lua`, Elemental Sharpening Stone (18262) and Brilliant Mana Oil (20748) from
  `Defaults_WpnEnch.lua`. With 289082 and 289086 above, that is all eight. Conjured Crystal Water
  (8079) and Conjured Cinnamon Roll (22895) stay: ForeverDB records a vendor for them. The bags
  still find every dropped item.
