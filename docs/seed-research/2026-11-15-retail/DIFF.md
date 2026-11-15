# Diff — retail, build 12.1.5.70783

Written by `tools/seeds/seeds.py derive`: what the build proposes against what the addon ships.

| List | Shipped ids | Flags | Candidates | Rule |
| --- | --- | --- | --- | --- |
| `AUG_RUNE` | 12 | 0 | 4 | window + rule |
| `BATTLE_REZ` | 5 | 0 | 0 | class spells plus one item, seed-plus-user-added only; ids pending in-game confirmation |
| `BLOODLUST` | 7 | 0 | 0 | class spells plus the drums, seed-plus-user-added only; ids pending in-game confirmation |
| `CLASS_GATE` | 1 | 0 | 0 | keyed by a BLOODLUST spell; follows that list |
| `CMBT_POT` | 4 | 0 | 27 | window + rule |
| `DRINK` | 5 | 0 | 0 | the Silvermoon innkeeper's stock; vendor stock is not in DB2 |
| `FLASK` | 5 | 0 | 18 | window + rule |
| `FOOD` | 9 | 0 | 0 | the Silvermoon innkeeper's stock; vendor stock is not in DB2 |
| `HP_POT` | 3 | 0 | 7 | window + rule |
| `HS` | 2 | 1 | 0 | a fixed two-entry whitelist (defaults/README.md, Procedure step 1) |
| `MP_POT` | 3 | 0 | 7 | window + rule |
| `STAT_FOOD` | 29 | 1 | 41 | window + rule |
| `STAT_PRIORITY` | 40 | 0 | 0 | window + rule |
| `VANTUS` | 1 | 0 | 3 | window + rule |
| `WPN_ENCH` | 9 | 0 | 17 | window + rule |
| `CLASSIFIER_HS` | 2 | 0 | 0 | flags only |
| `CLASSIFIER_VANTUS` | 1 | 0 | 0 | flags only |
| `CLASSIFIER_REUSABLE_AUG` | 5 | 0 | 0 | flags only |

## Current-expansion potions no rule places — 12

Reported, never ruled: an absorb, a utility buff longer than 60 s, or no use spell.

- `241286` Light's Preservation — expansion 11, quality 1, item level 295; crafting quality 14; effects: absorb
- `241287` Light's Preservation — expansion 11, quality 1, item level 278; crafting quality 13; effects: absorb
- `274774` Frost-Injected Vapor — expansion 11, quality 1, item level 7; effects: absorb; duration 3600s
- `274775` Void Hungerer's Vapor — expansion 11, quality 1, item level 7; duration 3600s; use: 1295336 Void Hungerer's Vapor: Your stare increases the cast time of spells that creatures in front of you cast by $1295575s1% for $1295336d. Additionally, $@spellname1294611 can no longer af
- `274780` Fungal Spore Vapor — expansion 11, quality 1, item level 7; duration 3600s; use: 1295335 Fungal Spore Vapor: [NYI] Slaying a fungal creature causes nearby Mushrooms, Sleeping Gas, Spores, and Vines to wither away for $1295335d.    You can only have one vapor active at
- `274782` Tether-Severing Vapor — expansion 11, quality 1, item level 7; duration 3600s; use: 1295332 Tether Sever Vapor: You deal $1295536s1% more damage to summoned creatures for $1295332d. When slain, their summoner takes Arcane damage equal to their max health.    You can only
- `274793` Mana Barrier Projector — expansion 11, quality 1, item level 7; effects: absorb; duration 3600s
- `274794` Shockwave Amplifier — expansion 11, quality 1, item level 7; duration 3600s; use: 1295338 Shockwave Amplifier: Your autoattacks have a chance to reverberate by building stacks of Distortion on your target. This effect lasts for $1295338d. When $1295381u stacks of Distort
- `278035` Ornate Healing Potion — expansion 11, quality 2, item level 1
- `279550` Potion of Venomous Return — expansion 11, quality 1, item level 1; use: 1307435 Potion of Venomous Return: Dissolve yourself with venom and reappear at the Amani Foothold.
- `280409` Potion of Liquid Undeath — expansion 11, quality 1, item level 90; use: 1308593 Potion of Liquid Undeath: Drink a lethal concoction, increasing your movement speed while dead by $1308590s1%. Only usable outdoors. Lasts $1308590d.
- `282427` Nalorakk's Ferocity — expansion 11, quality 4, item level 1; use: 1313875 Nalorakk's Ferocity: Permanently gain Nalorakk's Ferocity, granting you stacking $pri for every labyrinth chamber completed.
