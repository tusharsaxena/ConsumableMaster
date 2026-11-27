# Diff — retail, build 12.1.5.70961

Written by `tools/seeds/seeds.py derive`: what the build proposes against what the addon ships.

| List | Shipped ids | Flags | Candidates | Rule |
| --- | --- | --- | --- | --- |
| `AUG_RUNE` | 12 | 0 | 4 | window + rule |
| `BATTLE_REZ` | 5 | 0 | 0 | class spells plus one item, seed-plus-user-added only; ids pending in-game confirmation |
| `BLOODLUST` | 7 | 0 | 0 | class spells plus the drums, seed-plus-user-added only; ids pending in-game confirmation |
| `CLASS_GATE` | 1 | 0 | 0 | keyed by a BLOODLUST spell; follows that list |
| `CMBT_POT` | 6 | 0 | 25 | window + rule |
| `DRINK` | 5 | 0 | 0 | the Silvermoon innkeeper's stock; vendor stock is not in DB2 |
| `FLASK` | 5 | 0 | 18 | window + rule |
| `FOOD` | 9 | 0 | 0 | the Silvermoon innkeeper's stock; vendor stock is not in DB2 |
| `HP_POT` | 4 | 0 | 6 | window + rule |
| `HS` | 2 | 0 | 0 | a fixed two-entry whitelist (defaults/README.md, Procedure step 1) |
| `MP_POT` | 3 | 0 | 7 | window + rule |
| `STAT_FOOD` | 30 | 0 | 40 | window + rule |
| `STAT_PRIORITY` | 40 | 0 | 0 | window + rule |
| `VANTUS` | 1 | 0 | 3 | window + rule |
| `WPN_ENCH` | 9 | 0 | 17 | window + rule |
| `CLASSIFIER_HS` | 2 | 0 | 0 | flags only |
| `CLASSIFIER_VANTUS` | 1 | 0 | 0 | flags only |
| `CLASSIFIER_REUSABLE_AUG` | 5 | 0 | 0 | flags only |

## In-window potions no rule places — 12

Reported, never ruled: an absorb, a utility buff longer than 60 s, or no use spell.

- `241286` Light's Preservation — expansion 11, quality 1, item level 295; evidence: AH; crafting quality 14
- `241287` Light's Preservation — expansion 11, quality 1, item level 278; evidence: AH; crafting quality 13
- `274774` Frost-Injected Vapor — expansion 11, quality 1, item level 7; evidence: AH; effects: absorb
- `274775` Void Hungerer's Vapor — expansion 11, quality 1, item level 7; evidence: AH; duration 3600s
- `274780` Fungal Spore Vapor — expansion 11, quality 1, item level 7; evidence: none; duration 3600s
- `274782` Tether-Severing Vapor — expansion 11, quality 1, item level 7; evidence: none; duration 3600s
- `274793` Mana Barrier Projector — expansion 11, quality 1, item level 7; evidence: AH; effects: absorb
- `274794` Shockwave Amplifier — expansion 11, quality 1, item level 7; evidence: AH; duration 3600s
- `278035` Ornate Healing Potion — expansion 11, quality 2, item level 1; evidence: none
- `279550` Potion of Venomous Return — expansion 11, quality 1, item level 1; evidence: none; use: 1307435 Potion of Venomous Return: Dissolve yourself with venom and reappear at the Amani Foothold.
- `280409` Potion of Liquid Undeath — expansion 11, quality 1, item level 90; evidence: AH; use: 1308593 Potion of Liquid Undeath: Drink a lethal concoction, increasing your movement speed while dead by $1308590s1%. Only usable outdoors. Lasts $1308590d.
- `282427` Nalorakk's Ferocity — expansion 11, quality 4, item level 1; evidence: none; use: 1313875 Nalorakk's Ferocity: Permanently gain Nalorakk's Ferocity, granting you stacking $pri for every labyrinth chamber completed.

## Shipped ids no evidence source records — 11

Not seen on the auction house, at a vendor or anywhere else the run's evidence covers.
Reported, never ruled: absence from one account's AH scans is no proof an item is gone.

- AUG_RUNE `243191` Ethereal Augment Rune
- AUG_RUNE `246492` Soulgorged Augment Rune
- AUG_RUNE `211495` Dreambound Augment Rune
- AUG_RUNE `190384` Eternal Augment Rune
- AUG_RUNE `174906` Lightning-Forged Augment Rune
- AUG_RUNE `153023` Lightforged Augment Rune
- CLASSIFIER_REUSABLE_AUG `243191` Ethereal Augment Rune
- CLASSIFIER_REUSABLE_AUG `211495` Dreambound Augment Rune
- CLASSIFIER_REUSABLE_AUG `190384` Eternal Augment Rune
- CLASSIFIER_REUSABLE_AUG `174906` Lightning-Forged Augment Rune
- CLASSIFIER_REUSABLE_AUG `153023` Lightforged Augment Rune
