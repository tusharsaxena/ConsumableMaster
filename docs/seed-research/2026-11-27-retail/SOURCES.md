# Sources — seed validation, 2026-11-27 (retail)

Written by `tools/seeds/seeds.py derive`. Frozen: never edited after the run.

| Field | Value |
| --- | --- |
| Client | `retail` (wago.tools product `wow`) |
| Build | `12.1.5.70961` |
| Build created | 2026-11-17 20:16:02 |
| Run date | 2026-11-27 (the `--date` argument; the tool never reads the clock) |
| Builds API | <https://wago.tools/api/builds> |

## Tables

| Table | Why | URL |
| --- | --- | --- |
| `Item` | ClassID / SubclassID / CraftingQualityID: the category fit and the quality tier | <https://wago.tools/db2/Item/csv?build=12.1.5.70961> |
| `ItemSparse` | Display_lang / ExpansionID / OverallQualityID / ItemLevel / Flags_0: the name and the window | <https://wago.tools/db2/ItemSparse/csv?build=12.1.5.70961> |
| `ItemXItemEffect` | ItemID -> ItemEffectID, step 1 of the item -> spell join | <https://wago.tools/db2/ItemXItemEffect/csv?build=12.1.5.70961> |
| `ItemEffect` | ItemEffectID -> SpellID, step 2: the spell the item casts | <https://wago.tools/db2/ItemEffect/csv?build=12.1.5.70961> |
| `SpellName` | Name_lang: spell-seed names, and the Well Fed buff a meal references | <https://wago.tools/db2/SpellName/csv?build=12.1.5.70961> |
| `Spell` | Description_lang: what the item's spell says it does (evidence, Well Fed, Augment Rune) | <https://wago.tools/db2/Spell/csv?build=12.1.5.70961> |
| `SpellEffect` | Effect / EffectAura / EffectMiscValue_0 / EffectTriggerSpell: heal, mana, absorb, temporary enchant | <https://wago.tools/db2/SpellEffect/csv?build=12.1.5.70961> |
| `SpellMisc` | DurationIndex: a combat potion's buff duration | <https://wago.tools/db2/SpellMisc/csv?build=12.1.5.70961> |
| `SpellDuration` | Duration: DurationIndex -> milliseconds | <https://wago.tools/db2/SpellDuration/csv?build=12.1.5.70961> |
| `ChrSpecialization` | ID / ClassID / Name_lang / OrderIndex: the stat-priority keys | <https://wago.tools/db2/ChrSpecialization/csv?build=12.1.5.70961> |
| `JournalInstance` | Name_lang: whether the raid a Vantus rune names is in the journal (Retail only) | <https://wago.tools/db2/JournalInstance/csv?build=12.1.5.70961> |

The gzipped exports are in `raw/`. `seeds.py derive --replay` re-derives this bundle
from them with no network and no cache.
## Evidence sources

Read by scratch scripts outside the repo (docs/validate-seeds.md -> Evidence); only the fact
"this id has a <kind> source" is frozen, in `evidence.json`, for the consumables of this build.

| Source | What it is | Consumable ids with a record |
| --- | --- | --- |
| `ah` | Auctionator price database (the largest account's SavedVariables, Retail): item ids seen on the auction house | 3671 |
| `db2` | DB2's own SpellEffect: a spell creates the item (`crafted`); counts only for HS | 1660 |

## Evidence per id

Every id the flavor ships, then every candidate.

| List | Id | Name | Evidence |
| --- | --- | --- | --- |
| AUG_RUNE | `259085` | Void-Touched Augment Rune | AH |
| AUG_RUNE | `243191` | Ethereal Augment Rune | none |
| AUG_RUNE | `246492` | Soulgorged Augment Rune | none |
| AUG_RUNE | `224572` | Crystallized Augment Rune | AH, DB2 (crafted) |
| AUG_RUNE | `211495` | Dreambound Augment Rune | none |
| AUG_RUNE | `201325` | Draconic Augment Rune | AH |
| AUG_RUNE | `190384` | Eternal Augment Rune | none |
| AUG_RUNE | `181468` | Veiled Augment Rune | AH |
| AUG_RUNE | `174906` | Lightning-Forged Augment Rune | none |
| AUG_RUNE | `160053` | Battle-Scarred Augment Rune | AH |
| AUG_RUNE | `153023` | Lightforged Augment Rune | none |
| AUG_RUNE | `140587` | Defiled Augment Rune | AH |
| BATTLE_REZ | `248486` | Emergency Soul Link | AH |
| BLOODLUST | `244639` | Void-Touched Drums | AH |
| CMBT_POT | `241308` | Light's Potential | AH |
| CMBT_POT | `241288` | Potion of Recklessness | AH |
| CMBT_POT | `241292` | Draught of Rampant Abandon | AH |
| CMBT_POT | `241296` | Potion of Zealotry | AH |
| CMBT_POT | `271887` | Liquid Luster | AH |
| CMBT_POT | `271890` | Alluring Nostrum | AH |
| DRINK | `113509` | Conjured Mana Bun | DB2 (crafted) |
| DRINK | `260261` | Bloom Nectar | AH |
| DRINK | `260260` | Springrunner Sparkling | AH |
| DRINK | `260259` | Everspring Water | AH |
| DRINK | `260258` | Purified Cordial | AH |
| FLASK | `241326` | Flask of the Shattered Sun | AH |
| FLASK | `241324` | Flask of the Blood Knights | AH |
| FLASK | `241322` | Flask of the Magisters | AH |
| FLASK | `241321` | Flask of Thalassian Resistance | AH |
| FLASK | `241334` | Vicious Thalassian Flask of Honor | AH |
| FOOD | `113509` | Conjured Mana Bun | DB2 (crafted) |
| FOOD | `260264` | Quel'Danas Rations | AH |
| FOOD | `260263` | Silvermoon Soiree Spread | AH |
| FOOD | `260262` | Fairbreeze Feast | AH |
| FOOD | `260257` | Ghostlands Pepper | AH |
| FOOD | `260256` | Luxurious Omelette | AH |
| FOOD | `260255` | Managi Roll | AH |
| FOOD | `260254` | Kale'thas Sunsalad | AH |
| HP_POT | `241304` | Silvermoon Health Potion | AH |
| HP_POT | `241298` | Amani Extract | AH |
| HP_POT | `241306` | Refreshing Serum | AH |
| HP_POT | `271884` | Concentrated Silvermoon Health Potion | AH |
| HS | `224464` | Demonic Healthstone | DB2 (crafted) |
| HS | `5512` | Healthstone | DB2 (crafted) |
| MP_POT | `241300` | Lightfused Mana Potion | AH |
| MP_POT | `241294` | Potion of Devoured Dreams | AH |
| MP_POT | `241306` | Refreshing Serum | AH |
| STAT_FOOD | `242275` | Royal Roast | AH |
| STAT_FOOD | `255847` | Impossibly Royal Roast | AH |
| STAT_FOOD | `242283` | Sun-Seared Lumifin | AH |
| STAT_FOOD | `242286` | Fel-Kissed Filet | AH |
| STAT_FOOD | `242278` | Tasty Smoked Tetra | AH |
| STAT_FOOD | `242277` | Crimson Calamari | AH |
| STAT_FOOD | `242282` | Null and Void Plate | AH |
| STAT_FOOD | `242281` | Glitter Skewers | AH |
| STAT_FOOD | `242285` | Warped Wise Wings | AH |
| STAT_FOOD | `242284` | Void-Kissed Fish Rolls | AH |
| STAT_FOOD | `242280` | Buttered Root Crab | AH |
| STAT_FOOD | `242276` | Braised Blood Hunter | AH |
| STAT_FOOD | `242294` | Felberry Figs | AH |
| STAT_FOOD | `242288` | Twilight Angler's Medley | AH |
| STAT_FOOD | `242289` | Spellfire Filet | AH |
| STAT_FOOD | `242302` | Bloom Skewers | AH |
| STAT_FOOD | `242303` | Mana-Infused Stew | AH |
| STAT_FOOD | `242290` | Wise Tails | AH |
| STAT_FOOD | `242291` | Fried Bloomtail | AH |
| STAT_FOOD | `242292` | Eversong Pudding | AH |
| STAT_FOOD | `242293` | Sunwell Delight | AH |
| STAT_FOOD | `242295` | Hearthflame Supper | AH |
| STAT_FOOD | `242296` | Bloodthistle-Wrapped Cutlets | AH |
| STAT_FOOD | `242304` | Spiced Biscuits | AH |
| STAT_FOOD | `242305` | Silvermoon Standard | AH |
| STAT_FOOD | `242306` | Forager's Medley | AH |
| STAT_FOOD | `242307` | Quick Sandwich | AH |
| STAT_FOOD | `242308` | Portable Snack | AH |
| STAT_FOOD | `242309` | Farstrider Rations | AH |
| STAT_FOOD | `242287` | Arcano Cutlets | AH |
| VANTUS | `245880` | Vantus Rune: Radiant | AH |
| WPN_ENCH | `243733` | Thalassian Phoenix Oil | AH |
| WPN_ENCH | `243735` | Oil of Dawn | AH |
| WPN_ENCH | `237370` | Refulgent Whetstone | AH |
| WPN_ENCH | `237369` | Refulgent Weightstone | AH |
| WPN_ENCH | `224107` | Algari Mana Oil | AH |
| WPN_ENCH | `224113` | Oil of Deep Toxins | AH |
| WPN_ENCH | `224110` | Oil of Beledar's Grace | AH |
| WPN_ENCH | `222504` | Ironclaw Whetstone | AH |
| WPN_ENCH | `222508` | Ironclaw Weightstone | AH |
| CLASSIFIER_HS | `5512` | Healthstone | DB2 (crafted) |
| CLASSIFIER_HS | `224464` | Demonic Healthstone | DB2 (crafted) |
| CLASSIFIER_VANTUS | `245880` | Vantus Rune: Radiant | AH |
| CLASSIFIER_REUSABLE_AUG | `243191` | Ethereal Augment Rune | none |
| CLASSIFIER_REUSABLE_AUG | `211495` | Dreambound Augment Rune | none |
| CLASSIFIER_REUSABLE_AUG | `190384` | Eternal Augment Rune | none |
| CLASSIFIER_REUSABLE_AUG | `174906` | Lightning-Forged Augment Rune | none |
| CLASSIFIER_REUSABLE_AUG | `153023` | Lightforged Augment Rune | none |
| AUG_RUNE (candidate) | `118630` | Hyper Augment Rune | AH |
| AUG_RUNE (candidate) | `118631` | Stout Augment Rune | AH |
| AUG_RUNE (candidate) | `118632` | Focus Augment Rune | AH |
| WPN_ENCH (candidate) | `220156` | Bubbling Wax | none |
| WPN_ENCH (candidate) | `222502` | Ironclaw Whetstone | AH |
| WPN_ENCH (candidate) | `222503` | Ironclaw Whetstone | AH |
| WPN_ENCH (candidate) | `222509` | Ironclaw Weightstone | AH |
| WPN_ENCH (candidate) | `222510` | Ironclaw Weightstone | AH |
| WPN_ENCH (candidate) | `224105` | Algari Mana Oil | AH |
| WPN_ENCH (candidate) | `224106` | Algari Mana Oil | AH |
| WPN_ENCH (candidate) | `224108` | Oil of Beledar's Grace | AH |
| WPN_ENCH (candidate) | `224109` | Oil of Beledar's Grace | AH |
| WPN_ENCH (candidate) | `224111` | Oil of Deep Toxins | AH |
| WPN_ENCH (candidate) | `224112` | Oil of Deep Toxins | AH |
| WPN_ENCH (candidate) | `237367` | Refulgent Weightstone | AH |
| WPN_ENCH (candidate) | `237371` | Refulgent Whetstone | AH |
| CMBT_POT (candidate) | `241289` | Potion of Recklessness | AH |
| CMBT_POT (candidate) | `241293` | Draught of Rampant Abandon | AH |
| MP_POT (candidate) | `241295` | Potion of Devoured Dreams | AH |
| CMBT_POT (candidate) | `241297` | Potion of Zealotry | AH |
| HP_POT (candidate) | `241299` | Amani Extract | AH |
| MP_POT (candidate) | `241301` | Lightfused Mana Potion | AH |
| CMBT_POT (candidate) | `241302` | Void-Shrouded Tincture | AH |
| CMBT_POT (candidate) | `241303` | Void-Shrouded Tincture | AH |
| HP_POT (candidate) | `241305` | Silvermoon Health Potion | AH |
| HP_POT (candidate) | `241307` | Refreshing Serum | AH |
| MP_POT (candidate) | `241307` | Refreshing Serum | AH |
| CMBT_POT (candidate) | `241309` | Light's Potential | AH |
| FLASK (candidate) | `241310` | Haranir Phial of Finesse | AH |
| FLASK (candidate) | `241311` | Haranir Phial of Finesse | AH |
| FLASK (candidate) | `241312` | Haranir Phial of Ingenuity | AH |
| FLASK (candidate) | `241313` | Haranir Phial of Ingenuity | AH |
| FLASK (candidate) | `241316` | Haranir Phial of Perception | AH |
| FLASK (candidate) | `241317` | Haranir Phial of Perception | AH |
| FLASK (candidate) | `241320` | Flask of Thalassian Resistance | AH |
| FLASK (candidate) | `241323` | Flask of the Magisters | AH |
| FLASK (candidate) | `241325` | Flask of the Blood Knights | AH |
| FLASK (candidate) | `241327` | Flask of the Shattered Sun | AH |
| CMBT_POT (candidate) | `241338` | Enlightenment Tonic | AH |
| CMBT_POT (candidate) | `241339` | Enlightenment Tonic | AH |
| STAT_FOOD (candidate) | `242274` | Champion's Bento | AH |
| STAT_FOOD (candidate) | `242746` | Hearty Champion's Bento | none |
| STAT_FOOD (candidate) | `242747` | Hearty Royal Roast | none |
| STAT_FOOD (candidate) | `242748` | Hearty Braised Blood Hunter | none |
| STAT_FOOD (candidate) | `242749` | Hearty Crimson Calamari | none |
| STAT_FOOD (candidate) | `242750` | Hearty Tasty Smoked Tetra | none |
| STAT_FOOD (candidate) | `242752` | Hearty Buttered Root Crab | none |
| STAT_FOOD (candidate) | `242753` | Hearty Glitter Skewers | none |
| STAT_FOOD (candidate) | `242754` | Hearty Null and Void Plate | none |
| STAT_FOOD (candidate) | `242755` | Hearty Sun-Seared Lumifin | none |
| STAT_FOOD (candidate) | `242756` | Hearty Void-Kissed Fish Rolls | none |
| STAT_FOOD (candidate) | `242757` | Hearty Warped Wise Wings | none |
| STAT_FOOD (candidate) | `242758` | Hearty Fel-Kissed Filet | none |
| STAT_FOOD (candidate) | `242759` | Hearty Arcano Cutlets | none |
| STAT_FOOD (candidate) | `242760` | Hearty Twilight Angler's Medley | none |
| STAT_FOOD (candidate) | `242761` | Hearty Spellfire Filet | none |
| STAT_FOOD (candidate) | `242762` | Hearty Wise Tails | none |
| STAT_FOOD (candidate) | `242763` | Hearty Fried Bloomtail | none |
| STAT_FOOD (candidate) | `242764` | Hearty Eversong Pudding | none |
| STAT_FOOD (candidate) | `242765` | Hearty Sunwell Delight | none |
| STAT_FOOD (candidate) | `242766` | Hearty Felberry Figs | none |
| STAT_FOOD (candidate) | `242767` | Hearty Hearthflame Supper | none |
| STAT_FOOD (candidate) | `242768` | Hearty Bloodthistle-Wrapped Cutlets | none |
| STAT_FOOD (candidate) | `242769` | Hearty Bloom Skewers | none |
| STAT_FOOD (candidate) | `242770` | Hearty Mana-Infused Stew | none |
| STAT_FOOD (candidate) | `242771` | Hearty Spiced Biscuits | none |
| STAT_FOOD (candidate) | `242772` | Hearty Silvermoon Standard | none |
| STAT_FOOD (candidate) | `242773` | Hearty Forager's Medley | none |
| STAT_FOOD (candidate) | `242774` | Hearty Quick Sandwich | none |
| STAT_FOOD (candidate) | `242775` | Hearty Portable Snack | none |
| STAT_FOOD (candidate) | `242776` | Hearty Farstrider Rations | none |
| WPN_ENCH (candidate) | `243734` | Thalassian Phoenix Oil | AH |
| WPN_ENCH (candidate) | `243736` | Oil of Dawn | AH |
| WPN_ENCH (candidate) | `243737` | Smuggler's Enchanted Edge | AH |
| WPN_ENCH (candidate) | `243738` | Smuggler's Enchanted Edge | AH |
| VANTUS (candidate) | `245879` | Vantus Rune: Radiant | AH |
| CMBT_POT (candidate) | `245897` | Fleeting Light's Potential | DB2 (crafted) |
| CMBT_POT (candidate) | `245898` | Fleeting Light's Potential | DB2 (crafted) |
| CMBT_POT (candidate) | `245900` | Fleeting Potion of Zealotry | DB2 (crafted) |
| CMBT_POT (candidate) | `245901` | Fleeting Potion of Zealotry | DB2 (crafted) |
| CMBT_POT (candidate) | `245902` | Fleeting Potion of Recklessness | DB2 (crafted) |
| CMBT_POT (candidate) | `245903` | Fleeting Potion of Recklessness | DB2 (crafted) |
| MP_POT (candidate) | `245904` | Fleeting Potion of Devoured Dreams | DB2 (crafted) |
| MP_POT (candidate) | `245905` | Fleeting Potion of Devoured Dreams | DB2 (crafted) |
| CMBT_POT (candidate) | `245910` | Fleeting Draught of Rampant Abandon | DB2 (crafted) |
| CMBT_POT (candidate) | `245911` | Fleeting Draught of Rampant Abandon | DB2 (crafted) |
| MP_POT (candidate) | `245916` | Fleeting Lightfused Mana Potion | DB2 (crafted) |
| MP_POT (candidate) | `245917` | Fleeting Lightfused Mana Potion | DB2 (crafted) |
| HP_POT (candidate) | `245918` | Fleeting Silvermoon Health Potion | none |
| HP_POT (candidate) | `245919` | Fleeting Silvermoon Health Potion | none |
| FLASK (candidate) | `245926` | Fleeting Flask of Thalassian Resistance | DB2 (crafted) |
| FLASK (candidate) | `245927` | Fleeting Flask of Thalassian Resistance | DB2 (crafted) |
| FLASK (candidate) | `245928` | Fleeting Flask of the Shattered Sun | DB2 (crafted) |
| FLASK (candidate) | `245929` | Fleeting Flask of the Shattered Sun | DB2 (crafted) |
| FLASK (candidate) | `245930` | Fleeting Flask of the Blood Knights | DB2 (crafted) |
| FLASK (candidate) | `245931` | Fleeting Flask of the Blood Knights | DB2 (crafted) |
| FLASK (candidate) | `245932` | Fleeting Flask of the Magisters | DB2 (crafted) |
| FLASK (candidate) | `245933` | Fleeting Flask of the Magisters | DB2 (crafted) |
| STAT_FOOD (candidate) | `255848` | Flora Frenzy | AH |
| CMBT_POT (candidate) | `259092` | Void-Tinged Free Action Potion | none |
| CMBT_POT (candidate) | `259245` | Void Phase Potion | none |
| STAT_FOOD (candidate) | `268679` | Hearty Impossibly Royal Roast | none |
| STAT_FOOD (candidate) | `268680` | Hearty Flora Frenzy | none |
| CMBT_POT (candidate) | `268954` | Entropic Extract | AH |
| CMBT_POT (candidate) | `268955` | Entropic Extract | AH |
| HP_POT (candidate) | `271883` | Concentrated Silvermoon Health Potion | AH |
| CMBT_POT (candidate) | `271886` | Liquid Luster | AH |
| CMBT_POT (candidate) | `271889` | Alluring Nostrum | AH |
| VANTUS (candidate) | `272194` | Vantus Rune: Tides | AH |
| VANTUS (candidate) | `272195` | Vantus Rune: Tides | AH |
| CMBT_POT (candidate) | `274763` | Fleeting Liquid Luster | DB2 (crafted) |
| CMBT_POT (candidate) | `274764` | Fleeting Liquid Luster | DB2 (crafted) |
| CMBT_POT (candidate) | `274765` | Fleeting Alluring Nostrum | DB2 (crafted) |
| AUG_RUNE (candidate) | `274797` | Tidesworn Augment Rune | DB2 (crafted) |
| STAT_FOOD (candidate) | `275258` | Venom-Spiced Cutlets | AH |
| STAT_FOOD (candidate) | `275259` | Hearty Venom-Spiced Cutlets | none |
| STAT_FOOD (candidate) | `275260` | Puffer Plate | AH |
| STAT_FOOD (candidate) | `275261` | Sweet-And-Sour Skewers | AH |
| STAT_FOOD (candidate) | `275262` | Hearty Puffer Plate | none |
| STAT_FOOD (candidate) | `275263` | Hearty Sweet-And-Sour Skewers | none |
