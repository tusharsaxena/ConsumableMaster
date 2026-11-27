# Diff — forever, build 1.60.1.71139

Written by `tools/seeds/seeds.py derive`: what the build proposes against what the addon ships.

| List | Shipped ids | Flags | Candidates | Rule |
| --- | --- | --- | --- | --- |
| `BANDAGE` | 0 | 0 | 12 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `CLASS_GATE` | 0 | 0 | 0 | flags only |
| `CMBT_POT` | 0 | 0 | 30 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `DRINK` | 0 | 0 | 22 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `ELIXIR` | 0 | 0 | 80 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `FLASK` | 0 | 0 | 5 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `FOOD` | 0 | 0 | 105 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `HP_POT` | 0 | 0 | 19 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `HS` | 0 | 0 | 15 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `MP_POT` | 0 | 0 | 14 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `PROT_POT` | 0 | 0 | 10 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `SCROLL` | 0 | 0 | 31 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `STAT_FOOD` | 0 | 0 | 119 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `STAT_PRIORITY` | 0 | 0 | 0 | flags only |
| `WPN_ENCH` | 0 | 0 | 21 | window + rule (Forever subclasses, sourced items, top tier per band) |
| `CLASSIFIER_HS` | 0 | 0 | 0 | flags only |

## In-window potions no rule places — 15

Reported, never ruled: an absorb, a utility buff longer than 60 s, or no use spell.

- `2633` Jungle Remedy — required level 22, quality 1, item level 26; evidence: ForeverDB (drop), AH, probe (ah); use: 3592 Cure Ailments: Cures diseases and neutralizes poisons up to level 35.
- `3384` Minor Magic Resistance Potion — required level 12, quality 1, item level 22; evidence: ForeverDB (drop, object, recipe), AH, probe (ah), DB2 (crafted); duration 180s
- `4623` Lesser Stoneshield Potion — required level 33, quality 1, item level 43; evidence: ForeverDB (container, drop, quest, recipe), AH, probe (ah), DB2 (crafted); duration 90s
- `5631` Rage Potion — required level 4, quality 1, item level 14; evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted); use: 6612 Rage: Increases Rage by 20 to 40.
- `5633` Great Rage Potion — required level 25, quality 1, item level 35; evidence: ForeverDB (recipe), AH, probe (ah), DB2 (crafted); use: 6613 Great Rage: Increases Rage by 30 to 60.
- `9036` Magic Resistance Potion — required level 32, quality 1, item level 42; evidence: ForeverDB (container, drop, recipe), AH, probe (ah), DB2 (crafted); duration 180s
- `9260` Volatile Rum — required level 0, quality 1, item level 1; evidence: ForeverDB (drop, vendor), AH, probe (ah); use: 11009 Strong Alcohol: A strong alcoholic beverage.
- `13455` Greater Stoneshield Potion — required level 46, quality 1, item level 56; evidence: ForeverDB (recipe), AH, DB2 (crafted); duration 120s
- `13462` Purification Potion — required level 47, quality 1, item level 57; evidence: ForeverDB (recipe), DB2 (crafted); use: 17550 Purification: Attempts to remove one Curse or Bane, one Disease and one Poison from the Imbiber.
- `23696` [PH] Potion of Heightened Senses [DEP] — required level 1, quality 1, item level 60; evidence: ForeverDB (quest); duration 1800s
- `23698` [PH] Nature Resist Potion [DEP] — required level 1, quality 1, item level 60; evidence: ForeverDB (quest)
- `250951` Caustic Smog Potion — required level 45, quality 1, item level 5; evidence: ForeverDB (recipe), AH, DB2 (crafted); use: 1252525 Caustic Smog Potion: Throw a fragile concoction at the target area, revealing a cloud of Caustic Smog for $1252526d. Enemies standing within the cloud suffer $1252543s1 Nature damag
- `250954` Potion of Elemental Purging — required level 40, quality 1, item level 55; evidence: ForeverDB (recipe), AH, DB2 (crafted); duration 300s
- `250955` Potion of Beast Slaying — required level 40, quality 1, item level 55; evidence: ForeverDB (quest, recipe), AH, DB2 (crafted); duration 300s
- `281234` Potion of Winterspring Shrouding — required level 1, quality 1, item level 1; evidence: ForeverDB (quest); duration 600s

## DB2-only items left out of the window — 59

The list's subclass and rule take them, but no evidence says a player can get them (no
vendor, auction house, drop, quest, container, recipe or probe record). Reported, never ruled.

- FOOD `1113` Conjured Bread (required level 5)
- FOOD `1114` Conjured Rye (required level 15)
- FOOD `1119` Bottled Spirits (required level 0)
- FOOD `1487` Conjured Pumpernickel (required level 25)
- FOOD `4418` Deprecated Creeper Cakes (required level 35)
- FOOD `5349` Conjured Muffin (required level 1)
- FOOD `8075` Conjured Sourdough (required level 35)
- FOOD `8076` Conjured Sweet Roll (required level 45)
- FOOD `8543` Underwater Mushroom Cap (required level 25)
- FOOD `12763` Un'Goro Etherfruit (required level 45)
- FOOD `19696` Harvest Bread (required level 0)
- FOOD `21236` UNUSED ITEM (required level 0)
- FOOD `21240` UNUSED ITEM (required level 0)
- FOOD `23172` Refreshing Red Apple (required level 0)
- FOOD `249796` Hyjal Berries (required level 45)
- FOOD `260623` Candied Fruit Sampler (required level 25)
- FOOD `260624` Pristine Peach (required level 35)
- FOOD `260625` Garnished Rice Cake (required level 35)
- FOOD `260627` Savory Shen'dralar Steak (required level 45)
- FOOD `260628` Stuffed Pumpkin (required level 45)
- FOOD `278569` Yesterday's Leftovers (required level 1)
- FOOD `282018` Restorative Bread (required level 1)
- FOOD `287963` Roasted Quail (required level 1)
- DRINK `2136` Conjured Purified Water (required level 15)
- DRINK `2288` Conjured Fresh Water (required level 5)
- DRINK `3772` Conjured Spring Water (required level 25)
- DRINK `5350` Conjured Water (required level 1)
- DRINK `8077` Conjured Mineral Water (required level 35)
- DRINK `8078` Conjured Sparkling Water (required level 45)
- DRINK `23172` Refreshing Red Apple (required level 0)
- DRINK `231778` Mountain Spring Water (required level 55)
- DRINK `282018` Restorative Bread (required level 1)
- DRINK `287964` Morning Glory Dew (required level 1)
- STAT_FOOD `238638` Filet o' Flank (required level 55)
- STAT_FOOD `250066` Soaring Pamplona (required level 45)
- STAT_FOOD `287973` Tender Wolf Steak (required level 1)
- STAT_FOOD `287974` Grilled Squid (required level 1)
- HP_POT `2462` Deprecated Potion of Lesser Invulnerability (Fix) (required level 1)
- HP_POT `20002` Greater Dreamless Sleep Potion (required level 55)
- HP_POT `268881` Perishable Minor Healing Potion (required level 1)
- HP_POT `268882` Perishable Lesser Healing Potion (required level 3)
- HP_POT `268883` Perishable Healing Potion (required level 12)
- HP_POT `287966` Minor Healing Potion (required level 1)
- HP_POT `287967` Lesser Healing Potion (required level 1)
- HP_POT `287977` Greater Healing Potion (required level 1)
- MP_POT `20002` Greater Dreamless Sleep Potion (required level 55)
- MP_POT `287968` Minor Mana Potion (required level 1)
- MP_POT `287969` Lesser Mana Potion (required level 1)
- CMBT_POT `1450` Potion of Fervor (required level 15)
- CMBT_POT `287975` Swiftness Potion (required level 1)
- CMBT_POT `287976` Free Action Potion (required level 1)
- PROT_POT `13460` Greater Holy Protection Potion (required level 48)
- FLASK `274273` Flask of Natural Accuracy (required level 55)
- FLASK `274274` Flask of Natural Aggression (required level 55)
- FLASK `274275` Flask of Natural Precision (required level 55)
- FLASK `274276` Flask of Natural Swiftness (required level 55)
- WPN_ENCH `228980` Conductive Shield Coating (required level 40)
- WPN_ENCH `287978` Rough Sharpening Stone (required level 1)
- WPN_ENCH `287980` Elemental Sharpening Stone (required level 1)

## Zone-restricted items left out of the window — 19

Their own text confines them to one zone or battleground. Reported, never ruled.

- HP_POT `17348` Major Healing Draught (required level 45)
- HP_POT `17349` Superior Healing Draught (required level 35)
- MP_POT `17351` Major Mana Draught (required level 45)
- MP_POT `17352` Superior Mana Draught (required level 35)
- BANDAGE `19066` Warsong Gulch Runecloth Bandage (required level 45)
- BANDAGE `19067` Warsong Gulch Mageweave Bandage (required level 35)
- BANDAGE `19068` Warsong Gulch Silk Bandage (required level 25)
- BANDAGE `20065` Arathi Basin Mageweave Bandage (required level 35)
- BANDAGE `20066` Arathi Basin Runecloth Bandage (required level 45)
- BANDAGE `20067` Arathi Basin Silk Bandage (required level 25)
- BANDAGE `20232` Defiler's Mageweave Bandage (required level 35)
- BANDAGE `20234` Defiler's Runecloth Bandage (required level 45)
- BANDAGE `20235` Defiler's Silk Bandage (required level 25)
- BANDAGE `20237` Highlander's Mageweave Bandage (required level 35)
- BANDAGE `20243` Highlander's Runecloth Bandage (required level 45)
- BANDAGE `20244` Highlander's Silk Bandage (required level 25)
- BANDAGE `272056` Darkspear Islands Silk Bandage (required level 25)
- BANDAGE `272057` Darkspear Islands Mageweave Bandage (required level 35)
- BANDAGE `272058` Darkspear Islands Runecloth Bandage (required level 45)
