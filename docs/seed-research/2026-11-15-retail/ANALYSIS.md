# Analysis — Retail seed validation, 2026-11-15 (build 12.1.5.70783)

GitHub issue #49. The first run of `tools/seeds/seeds.py`, under the contract in
`docs/validate-seeds.md`. It checks every Retail list in `defaults/Defaults_*.lua`, and the
`HEALTHSTONE_IDS`, `VANTUS_IDS` and `REUSABLE_AUG_IDS` whitelists in `core/Classifier.lua`, against
the live Retail build on wago.tools (product `wow`, 12.1.5.70783, created 2026-11-04). The lists were
last put together by hand on 2026-04-22 (Method.gg and the Silvermoon innkeeper) and in 2026-07
(Wowhead), so this is also the first check of them against the game's own data. Every candidate and
flag is ruled in `tools/seeds/retail_rulings.json`, and `RULINGS.md` beside this file lists each
ruling with its reason. Claude made the rulings under the contract's precedent; the owner has not
reviewed them yet.

## What the shipped lists looked like on the build

| Check | Result |
| --- | --- |
| Shipped ids checked | 143, in 18 lists: 13 seed lists, `CLASS_GATE`, `STAT_PRIORITY`'s 40 spec keys and the 3 Classifier whitelists |
| Ids the build does not have | 0 |
| Items whose class or subclass no longer fits their list | 0 |
| In-window items the list's own rule no longer admits | 0 |
| Stat-priority keys whose spec is gone or sits under another class | 0, and no player spec is missing (Devourer, `12_1480`, is there) |
| Names that disagree with the comment | 2 (below) |
| Coverage gate (each rule admits its own list's shipped ids) | pass, all 8 rules |

### The two flags, both kept with the comment fixed

- **`HS` 224464** is *Demonic Healthstone* on the build, not *Healthstone*. It is still a warlock
  healthstone of the same item class as 5512, so it stays, and the comment now names it. The file's
  header still calls 224464 "the modern ranked healthstone" that "auto-upgrades with warlock level".
  DB2 alone cannot confirm or refute that, so the header is left for the owner (below).
- **`STAT_FOOD` 242286** is *Fel-Kissed Filet* (Well Fed: Haste), not *Arcano Cutlets* (CRIT), as its
  comment said. Arcano Cutlets is 242287. Fel-Kissed Filet is itself a Midnight single-stat meal the
  list's rule admits, so the id stays with its comment corrected to `Fel-Kissed Filet (HASTE)`, and
  242287 is accepted beside it: the comment shows which meal the seed meant to carry.

## What the run proposed

124 candidates: 4 accepted and 120 rejected, 11 of those with `needs owner review`.

| List | Candidates | Accepted | Rejected for a header rule | Needs owner review |
| --- | --- | --- | --- | --- |
| `CMBT_POT` | 27 | 2 | 25 | 0 |
| `FLASK` | 18 | 0 | 18 | 0 |
| `HP_POT` | 7 | 1 | 6 | 0 |
| `MP_POT` | 7 | 0 | 7 | 0 |
| `STAT_FOOD` | 41 | 1 | 35 | 5 |
| `WPN_ENCH` | 17 | 0 | 15 | 2 |
| `VANTUS` | 3 | 0 | 0 | 3 |
| `AUG_RUNE` | 4 | 0 | 3 | 1 |
| `STAT_PRIORITY` | 0 | 0 | 0 | 0 |

To tell an item new since the 2026-04-22 refresh from one the refresh left out, each candidate was
looked up in the `Item` table of 12.0.5.67114, the Retail build live on that date. That table is not
frozen in this bundle; fetch <https://wago.tools/db2/Item/csv?build=12.0.5.67114> to repeat the
check. 18 candidates are new since that build, and every other one was already there.

### Accepted: 4

| List | Id | Item | Why |
| --- | --- | --- | --- |
| `HP_POT` | 271884 | Concentrated Silvermoon Health Potion | A direct heal (`Restores $s1 health`), Potion subclass, no absorb. New since 12.0.5.67114. Crafting quality 14, the tier the shipped 241304 carries. |
| `CMBT_POT` | 271887 | Liquid Luster | A 30 s Versatility potion: throughput, not utility. New since 12.0.5.67114. Crafting quality 14, the tier the shipped combat potions carry. |
| `CMBT_POT` | 271890 | Alluring Nostrum | A 30 s Shadow-damage proc potion, the shape of the shipped Potion of Zealotry 241296. New since 12.0.5.67114. Crafting quality 14. |
| `STAT_FOOD` | 242287 | Arcano Cutlets | Well Fed: Critical Strike. The meal the shipped comment at 242286 names (above). |

`apply` appended each at the end of its list with the provenance comment, and the headers of the four
seed files that changed now say they were validated on this build.

### Rejected for a header rule: 109

- **85 tier twins and copies of shipped items.** 28 are the other crafting-quality tier of a shipped
  potion, flask, oil, stone or rune; 35 are Hearty meals; 22 are Fleeting (cauldron) copies of the
  potions and flasks. Each list seeds one tier, and auto-discovery takes the rest (`defaults/README.md`,
  Procedure step 5; `Defaults_StatFood.lua`'s header for Hearty).
- **6 tier twins and Fleeting copies of this run's accepts** (271883, 271886, 271889, 274763, 274764,
  274765).
- **6 Haranir profession phials** (`Defaults_Flask.lua`'s header keeps them out).
- **8 utility or no-benefit potions:** Void-Shrouded Tincture (invisibility), Enlightenment Tonic
  (slow fall), Entropic Extract (cosmetic), each with its twin, then Void-Tinged Free Action Potion
  and Void Phase Potion (zone-bound).
- **3 Warlords garrison augment runes** (Hyper, Stout, Focus; `Defaults_AugRune.lua`'s header).
- **1 weapon wax outside `WPN_ENCH`'s scope** (Bubbling Wax, 220156: neither an Enchanting oil nor a
  Blacksmithing stone).

### Needs owner review: 11

- **Five highest-secondary-stat meals** (`STAT_FOOD`). Champion's Bento 242274 and Flora Frenzy 255848
  were already on 12.0.5.67114 and were not seeded; Venom-Spiced Cutlets 275258, Puffer Plate 275260
  and Sweet-And-Sour Skewers 275261 are new since. The seed ships no meal of this shape, and nothing
  records whether that is deliberate. The Ranker already scores "highest secondary stat" for Potion
  of Recklessness.
- **Smuggler's Enchanted Edge** 243737 and 243738 (`WPN_ENCH`): a Midnight Enchanting oil that was on
  the build before the 2026-07 refresh and is not seeded.
- **Vantus Rune: Tides** 272194 and 272195 (`VANTUS`): new since 12.0.5.67114. It targets Ula'tek
  Temple, which is not a `JournalInstance` on this build, so its raid tier may not be live yet.
  `Defaults_Vantus.lua` adds a rune as its tier ships.
- **Vantus Rune: Radiant** 245879 (`VANTUS`): the crafting-quality 13 twin of the shipped 245880.
  Every other list's twins are rejected because auto-discovery takes them, but `VANTUS` matches on
  the `VANTUS_IDS` whitelist alone, so this tier is never discovered from bags.
- **Tidesworn Augment Rune** 274797 (`AUG_RUNE`): new since 12.0.5.67114, with `ExpansionID` -3, which
  is no Retail expansion (an event or special-mode item, by the look of it). DB2 does not say whether
  it is reusable.

## What the tool cannot see

`DIFF.md` lists 12 current-expansion potions no rule places, and they are never ruled: both tiers of
Light's Preservation (an absorb, which `Defaults_HPPot.lua` keeps out), the six Naigtal and Val vapors
and projectors (zone-bound, an hour long), Ornate Healing Potion (no use spell on the build), and
three utility potions (Venomous Return, Liquid Undeath, Nalorakk's Ferocity).

`FOOD` and `DRINK` get no candidates, because they are a vendor's stock and DB2 holds no vendor
stock. Midnight does carry new conjured food and drink (Conjured Souffle 265096, Conjured Cinnamon
Roll 265097, Conjured Croissant 265098, Conjured Tea 265099), and no create-item effect on the build
names them, so it is unclear what makes them. The seed's Conjured Mana Bun 113509 is still what the
build's `Conjure Refreshment` creates.

## For the owner

1. The 11 `needs owner review` rulings above. Flip any with `seeds.py rule --bundle
   docs/seed-research/2026-11-15-retail --key <key> --ruling accept --reason "..."`, then run
   `report` and `apply` on a fresh bundle.
2. `FLASK` ships Flask of Thalassian Resistance as 241321, its crafting-quality 13 tier, while the
   other three combat flasks ship their quality 14 tier. Whether that is deliberate is not recorded.
3. `Defaults_Healthstone.lua`'s header calls 224464 the modern ranked healthstone; the build calls it
   Demonic Healthstone and gives 5512 the name Healthstone.
4. `HEALTHSTONE_IDS` is one table for both clients (see the Forever bundle), where every seed list is
   per client.

## What a later run should re-check

- Ula'tek Temple in `JournalInstance`, and Vantus Rune: Tides with it.
- The highest-secondary meals, once the owner has ruled on them.
- `CURRENT_EXPANSION` in the tool when the next expansion ships: every list's window reads it.
- The drums and older ids `Defaults_Bloodlust.lua` waits on. DB2 can name them, but the list is
  seed-plus-user-added and its header asks for in-game confirmation first.
