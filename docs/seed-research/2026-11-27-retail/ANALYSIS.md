# Analysis — Retail seed validation, 2026-11-27 (build 12.1.5.70961)

GitHub issue #46. A Retail pass beside the first Forever lists: every Retail list in
`defaults/Defaults_*.lua`, and the `HEALTHSTONE_IDS` (Retail's block), `VANTUS_IDS` and
`REUSABLE_AUG_IDS` whitelists, against the live Retail build on wago.tools (product `wow`,
12.1.5.70961), with one new input: the Retail auction house, read from the largest account's
Auctionator SavedVariables and frozen as `evidence.json` (3671 consumables seen; `SOURCES.md` has every
id's record). The run's rules are the 2026-11-15 run's; the AH data is a cross-check, not a rule.

## What changed since 2026-11-15

Nothing that needs a ruling. The build moved from 12.1.5.70783 to 12.1.5.70961, and the eleven tables
are the same size to within a few bytes.

| Check | Result |
| --- | --- |
| Flags (unnamed, renamed, misfiled, unmatched) | 0 |
| Candidates | 120, every one already ruled in `tools/seeds/retail_rulings.json` (none new) |
| Coverage gate | pass |
| Accepted, applied | 0 |

So the seed files' Retail lists do not change, and the run adds no Discovery smoke check.

## The auction house cross-check

- **Every shipped id is traded except the soulbound ones.** The 11 shipped ids the AH never saw are
  the six reusable augment runes in `AUG_RUNE` and the five in `REUSABLE_AUG_IDS`, which cannot be
  sold. Nothing argues for a removal.
- **The innkeeper food and drink** (`FOOD`, `DRINK`, no DB2 rule) are all seen on the AH, so the lists
  are at least current goods; DB2 still cannot say which vendor sells them, and they are left as they
  are.
- **The eleven `needs owner review` candidates of 2026-11-15 are all traded:** the five
  highest-secondary-stat meals (Champion's Bento 242274, Flora Frenzy 255848, Venom-Spiced Cutlets
  275258, Puffer Plate 275260, Sweet-And-Sour Skewers 275261), Smuggler's Enchanted Edge (243737,
  243738), Vantus Rune: Radiant's other tier (245879), Vantus Rune: Tides (272194, 272195) and Tidesworn
  Augment Rune (274797). The rulings stand (precedent is never re-litigated), but the AH evidence is a
  reason to look at them again: players buy them, so each is a live item. The owner can flip any with
  `seeds.py rule --bundle docs/seed-research/2026-11-27-retail --key <key> --ruling accept --reason "..."`
  then `report` and `apply`.
- 80 of the 120 candidates are traded; the 40 that are not are mostly Hearty meals and Fleeting
  copies, which the lists leave to auto-discovery anyway.

## What a later run should re-check

- The Retail probe runs issue #46 lists (a full AH scan, the capital's innkeepers and food vendors,
  profession vendors, mouseover on crafted and raid-only items): the probe store on Retail is empty, so
  vendor stock for `FOOD` and `DRINK` still has no machine-readable source.
- The eleven owner-review items above, with the AH evidence in hand.
