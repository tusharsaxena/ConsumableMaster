# Sources — seed validation, 2026-11-27 (forever)

Written by `tools/seeds/seeds.py derive`. Frozen: never edited after the run.

| Field | Value |
| --- | --- |
| Client | `forever` (wago.tools product `wowf`) |
| Build | `1.60.1.71139` |
| Build created | 2026-11-25 19:13:07 |
| Run date | 2026-11-27 (the `--date` argument; the tool never reads the clock) |
| Builds API | <https://wago.tools/api/builds> |

## Tables

| Table | Why | URL |
| --- | --- | --- |
| `Item` | ClassID / SubclassID: the category fit | <https://wago.tools/db2/Item/csv?build=1.60.1.71139> |
| `ItemSparse` | Display_lang / RequiredLevel / ItemLevel: the name, the level band and the tier | <https://wago.tools/db2/ItemSparse/csv?build=1.60.1.71139> |
| `ItemXItemEffect` | ItemID -> ItemEffectID, step 1 of the item -> spell join | <https://wago.tools/db2/ItemXItemEffect/csv?build=1.60.1.71139> |
| `ItemEffect` | ItemEffectID -> SpellID, step 2: the spell the item casts | <https://wago.tools/db2/ItemEffect/csv?build=1.60.1.71139> |
| `SpellName` | Name_lang: spell-seed names, and the Well Fed buff a meal references | <https://wago.tools/db2/SpellName/csv?build=1.60.1.71139> |
| `Spell` | Description_lang: what the item's spell says it does (the stat, the school, the weapon) | <https://wago.tools/db2/Spell/csv?build=1.60.1.71139> |
| `SpellEffect` | Effect / EffectAura / EffectMiscValue_0 / EffectBasePointsF / EffectItemType: heal, mana, absorb school, temporary enchant, and which items a spell creates | <https://wago.tools/db2/SpellEffect/csv?build=1.60.1.71139> |
| `SpellMisc` | DurationIndex: a combat potion's buff duration | <https://wago.tools/db2/SpellMisc/csv?build=1.60.1.71139> |
| `SpellDuration` | Duration: DurationIndex -> milliseconds | <https://wago.tools/db2/SpellDuration/csv?build=1.60.1.71139> |

The gzipped exports are in `raw/`. `seeds.py derive --replay` re-derives this bundle
from them with no network and no cache.
## Evidence sources

Read by scratch scripts outside the repo (docs/validate-seeds.md -> Evidence); only the fact
"this id has a <kind> source" is frozen, in `evidence.json`, for the consumables of this build.

| Source | What it is | Consumable ids with a record |
| --- | --- | --- |
| `ah` | Auctionator price database (the largest account's SavedVariables, WoW Forever): item ids seen on the auction house | 812 |
| `fdb` | ForeverDB 2026-11-27 (the installed WoW Forever data addon, GPL-3.0): evidence only, no rows copied | 1146 |
| `probe` | ConsumableMasterProbeDB (the owner's in-game /cm probe seed store, WoW Forever) | 497 |
| `db2` | DB2's own SpellEffect: a spell creates the item (`crafted`); counts only for HS | 614 |

## Evidence per id

Every id the flavor ships, then every candidate.

| List | Id | Name | Evidence |
| --- | --- | --- | --- |
| FOOD (candidate) | `117` | Tough Jerky | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| HP_POT (candidate) | `118` | Minor Healing Potion | ForeverDB (drop, object, quest), AH, probe (ah), DB2 (crafted) |
| DRINK (candidate) | `159` | Refreshing Spring Water | ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor) |
| FOOD (candidate) | `414` | Dalaran Sharp | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `422` | Dwarven Mild | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah) |
| STAT_FOOD (candidate) | `724` | Goretusk Liver Pie | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `733` | Westfall Stew | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `787` | Slitherskin Mackerel | ForeverDB (drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `858` | Lesser Healing Potion | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `929` | Healing Potion | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah), DB2 (crafted) |
| SCROLL (candidate) | `954` | Scroll of Strength | ForeverDB (container, drop, vendor), AH, probe (ah) |
| SCROLL (candidate) | `955` | Scroll of Intellect | ForeverDB (container, drop, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `961` | Healing Herb | ForeverDB (quest), AH, probe (ah) |
| STAT_FOOD (candidate) | `1017` | Seasoned Wolf Kabob | ForeverDB (object, quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `1082` | Redridge Goulash | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| DRINK (candidate) | `1179` | Ice Cold Milk | ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor) |
| SCROLL (candidate) | `1180` | Scroll of Stamina | ForeverDB (container, drop, quest, vendor), AH, probe (ah) |
| SCROLL (candidate) | `1181` | Scroll of Spirit | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| DRINK (candidate) | `1205` | Melon Juice | ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor) |
| BANDAGE (candidate) | `1251` | Linen Bandage | AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `1326` | Sauteed Sunfish | ForeverDB (quest), AH, probe (ah) |
| DRINK (candidate) | `1401` | Green Tea Leaf | ForeverDB (drop), AH, probe (ah) |
| SCROLL (candidate) | `1477` | Scroll of Agility II | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `1478` | Scroll of Protection II | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| DRINK (candidate) | `1645` | Moonberry Juice | ForeverDB (container, drop, object, vendor), AH, probe (ah, vendor) |
| FOOD (candidate) | `1707` | Stormwind Brie | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| DRINK (candidate) | `1708` | Sweet Nectar | ForeverDB (container, drop, object, vendor), AH, probe (ah, vendor) |
| HP_POT (candidate) | `1710` | Greater Healing Potion | ForeverDB (container, drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| SCROLL (candidate) | `1711` | Scroll of Stamina II | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `1712` | Scroll of Spirit II | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `2070` | Darnassian Bleu | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `2287` | Haunch of Meat | ForeverDB (drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `2289` | Scroll of Strength II | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `2290` | Scroll of Intellect II | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| ELIXIR (candidate) | `2454` | Elixir of Minor Strength | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| MP_POT (candidate) | `2455` | Minor Mana Potion | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `2456` | Minor Rejuvenation Potion | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| MP_POT (candidate) | `2456` | Minor Rejuvenation Potion | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `2457` | Elixir of Minor Agility | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `2458` | Elixir of Minor Fortitude | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `2459` | Swiftness Potion | ForeverDB (drop, quest, recipe), AH, probe (ah), DB2 (crafted) |
| BANDAGE (candidate) | `2581` | Heavy Linen Bandage | AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `2679` | Charred Wolf Meat | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2680` | Spiced Wolf Meat | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2681` | Roasted Boar Meat | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2682` | Cooked Crab Claw | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2683` | Crab Cake | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2684` | Coyote Steak | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2685` | Succulent Pork Ribs | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2687` | Dry Pork Ribs | AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `2862` | Rough Sharpening Stone | AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `2863` | Coarse Sharpening Stone | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `2871` | Heavy Sharpening Stone | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `2888` | Beer Basted Boar Ribs | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| SCROLL (candidate) | `3012` | Scroll of Agility | ForeverDB (container, drop, vendor), AH, probe (ah) |
| SCROLL (candidate) | `3013` | Scroll of Protection | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| MP_POT (candidate) | `3087` | Mug of Shimmer Stout | ForeverDB (quest) |
| STAT_FOOD (candidate) | `3220` | Blood Sausage | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `3239` | Rough Weightstone | AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `3240` | Coarse Weightstone | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `3241` | Heavy Weightstone | AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3382` | Minor Troll's Blood Elixir | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3383` | Elixir of Wisdom | AH, probe (ah), DB2 (crafted) |
| MP_POT (candidate) | `3385` | Lesser Mana Potion | ForeverDB (container, drop, object, vendor), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `3387` | Limited Invulnerability Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `3388` | Lesser Troll's Blood Elixir | AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3389` | Elixir of Lesser Defense | AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3390` | Elixir of Lesser Agility | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3391` | Elixir of Ogre Strength | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `3448` | Senggin Root | ForeverDB (quest) |
| DRINK (candidate) | `3448` | Senggin Root | ForeverDB (quest) |
| BANDAGE (candidate) | `3530` | Wool Bandage | AH, probe (ah), DB2 (crafted) |
| BANDAGE (candidate) | `3531` | Heavy Wool Bandage | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3662` | Crocolisk Steak | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3663` | Murloc Fin Soup | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3664` | Crocolisk Gumbo | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3665` | Curiously Tasty Omelet | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3666` | Gooey Spider Cake | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3726` | Big Bear Steak | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3727` | Hot Lion Chops | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `3728` | Tasty Lion Steak | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `3729` | Soothing Turtle Bisque | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `3770` | Mutton Chop | ForeverDB (drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `3771` | Wild Hog Shank | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| CMBT_POT (candidate) | `3823` | Lesser Invisibility Potion | AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `3824` | Shadow Oil | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3825` | Elixir of Lesser Fortitude | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3826` | Troll's Blood Elixir | ForeverDB (recipe), AH, DB2 (crafted) |
| MP_POT (candidate) | `3827` | Mana Potion | ForeverDB (container, drop, object, vendor), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `3828` | Draught of Detect Lesser Invisibility | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `3829` | Frost Oil | ForeverDB (container, drop, recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `3927` | Fine Aged Cheddar | ForeverDB (container, drop, object, vendor), AH |
| HP_POT (candidate) | `3928` | Superior Healing Potion | ForeverDB (container, drop, object, quest, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| SCROLL (candidate) | `4419` | Scroll of Intellect III | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `4421` | Scroll of Protection III | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `4422` | Scroll of Stamina III | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `4424` | Scroll of Spirit III | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| SCROLL (candidate) | `4425` | Scroll of Agility III | ForeverDB (container, drop, object, vendor), AH |
| SCROLL (candidate) | `4426` | Scroll of Strength III | ForeverDB (container, drop, object, vendor), AH |
| STAT_FOOD (candidate) | `4457` | Barbecued Buzzard Wing | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `4536` | Shiny Red Apple | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `4537` | Tel'Abim Banana | ForeverDB (drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `4538` | Snapvine Watermelon | ForeverDB (drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `4539` | Goldenbark Apple | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `4540` | Tough Hunk of Bread | ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor) |
| FOOD (candidate) | `4541` | Freshly Baked Bread | ForeverDB (drop, object, quest, vendor), AH, probe (ah, vendor) |
| FOOD (candidate) | `4542` | Moist Cornbread | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah, vendor) |
| FOOD (candidate) | `4544` | Mulgore Spice Bread | ForeverDB (container, drop, object, vendor), AH, probe (ah, vendor) |
| STAT_FOOD (candidate) | `4592` | Longjaw Mud Snapper | ForeverDB (drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `4593` | Bristle Whisker Catfish | ForeverDB (drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `4594` | Rockscale Cod | ForeverDB (drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `4596` | Minor Discolored Healing Potion | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `4599` | Cured Ham Steak | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `4601` | Soft Banana Bread | ForeverDB (container, drop, object, vendor), AH, probe (ah, vendor) |
| FOOD (candidate) | `4602` | Moon Harvest Pumpkin | ForeverDB (container, drop, object, vendor), AH |
| FOOD (candidate) | `4604` | Forest Mushroom Cap | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `4605` | Red-speckled Mushroom | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `4606` | Spongy Morel | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `4607` | Delicious Cave Mold | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `4608` | Raw Black Truffle | ForeverDB (container, drop, object, vendor), AH |
| FOOD (candidate) | `4656` | Small Pumpkin | ForeverDB (drop, object, quest), AH, probe (ah) |
| DRINK (candidate) | `4791` | Enchanted Water | ForeverDB (drop), AH, probe (ah) |
| FOOD (candidate) | `5057` | Ripe Watermelon | ForeverDB (object, quest), AH, probe (ah) |
| FOOD (candidate) | `5066` | Fissure Plant | ForeverDB (drop, object), AH |
| STAT_FOOD (candidate) | `5095` | Rainbow Fin Albacore | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `5472` | Kaldorei Spider Kabob | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `5473` | Scorpid Surprise | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `5474` | Roasted Kodo Meat | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `5476` | Fillet of Frenzy | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `5477` | Strider Stew | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `5478` | Dig Rat Stew | ForeverDB (quest, recipe), DB2 (crafted) |
| STAT_FOOD (candidate) | `5479` | Crispy Lizard Tail | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `5480` | Lean Venison | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| HS (candidate) | `5509` | Healthstone | DB2 (crafted) |
| HS (candidate) | `5510` | Greater Healthstone | DB2 (crafted) |
| HS (candidate) | `5511` | Lesser Healthstone | DB2 (crafted) |
| HS (candidate) | `5512` | Minor Healthstone | DB2 (crafted) |
| STAT_FOOD (candidate) | `5525` | Boiled Clams | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `5526` | Clam Chowder | ForeverDB (drop, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `5527` | Goblin Deviled Clams | AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `5634` | Free Action Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `5996` | Draught of Water Breathing | ForeverDB (quest), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `5997` | Elixir of Minor Defense | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `6038` | Giant Clam Scorcho | ForeverDB (recipe), AH, DB2 (crafted) |
| PROT_POT (candidate) | `6048` | Shadow Protection Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| PROT_POT (candidate) | `6049` | Fire Protection Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| PROT_POT (candidate) | `6050` | Frost Protection Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| PROT_POT (candidate) | `6051` | Holy Protection Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| PROT_POT (candidate) | `6052` | Nature Protection Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| MP_POT (candidate) | `6149` | Greater Mana Potion | ForeverDB (container, drop, object, quest, vendor), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `6290` | Brilliant Smallfish | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `6299` | Sickly Looking Fish | ForeverDB (drop), AH, probe (ah) |
| STAT_FOOD (candidate) | `6316` | Loch Frenzy Delight | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `6372` | Swim Speed Potion | AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `6373` | Elixir of Fire Power | AH, probe (ah), DB2 (crafted) |
| BANDAGE (candidate) | `6450` | Silk Bandage | AH, probe (ah), DB2 (crafted) |
| BANDAGE (candidate) | `6451` | Heavy Silk Bandage | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `6662` | Elixir of Giant Growth | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `6807` | Frog Leg Stew | ForeverDB (quest), AH, probe (ah) |
| STAT_FOOD (candidate) | `6887` | Spotted Yellowtail | ForeverDB (drop, object, recipe, vendor), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `6888` | Herb Baked Egg | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `6890` | Smoked Bear Meat | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `7097` | Leg Meat | ForeverDB (drop), AH, probe (ah) |
| FOOD (candidate) | `7228` | Tigule's Strawberry Ice Cream | ForeverDB (drop, vendor), AH |
| STAT_FOOD (candidate) | `7806` | Lollipop | ForeverDB (object) |
| STAT_FOOD (candidate) | `7807` | Candy Bar | ForeverDB (object) |
| STAT_FOOD (candidate) | `7808` | Chocolate Square | ForeverDB (object) |
| WPN_ENCH (candidate) | `7964` | Solid Sharpening Stone | AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `7965` | Solid Weightstone | AH, probe (ah), DB2 (crafted) |
| DRINK (candidate) | `8079` | Conjured Crystal Water | ForeverDB (vendor), DB2 (crafted) |
| STAT_FOOD (candidate) | `8364` | Mithril Head Trout | ForeverDB (drop, object, recipe), AH, probe (ah), DB2 (crafted) |
| BANDAGE (candidate) | `8544` | Mageweave Bandage | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| BANDAGE (candidate) | `8545` | Heavy Mageweave Bandage | AH, DB2 (crafted) |
| DRINK (candidate) | `8766` | Morning Glory Dew | ForeverDB (container, drop, object, vendor), AH, probe (vendor) |
| ELIXIR (candidate) | `8827` | Draught of Water Walking | AH, DB2 (crafted) |
| FOOD (candidate) | `8932` | Alterac Swiss | ForeverDB (container, drop, object, vendor), AH, probe (ah) |
| FOOD (candidate) | `8948` | Dried King Bolete | ForeverDB (container, drop, object, vendor), AH |
| ELIXIR (candidate) | `8949` | Elixir of Agility | AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `8950` | Homemade Cherry Pie | ForeverDB (container, drop, object, vendor), AH, probe (vendor) |
| ELIXIR (candidate) | `8951` | Elixir of Defense | ForeverDB (container), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `8952` | Roasted Quail | ForeverDB (container, drop, object, vendor), AH |
| FOOD (candidate) | `8953` | Deep Fried Plantains | ForeverDB (container, drop, object, vendor), AH |
| STAT_FOOD (candidate) | `8957` | Spinefin Halibut | ForeverDB (drop, object, vendor), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `9030` | Restorative Potion | ForeverDB (container, drop, quest), DB2 (crafted) |
| ELIXIR (candidate) | `9088` | Gift of Arthas | ForeverDB (recipe), AH, DB2 (crafted) |
| HP_POT (candidate) | `9144` | Wildvine Potion | ForeverDB (container, drop, recipe), AH, probe (ah), DB2 (crafted) |
| MP_POT (candidate) | `9144` | Wildvine Potion | ForeverDB (container, drop, recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `9154` | Draught of Detect Undead | ForeverDB (container, drop), AH, DB2 (crafted) |
| ELIXIR (candidate) | `9155` | Arcane Elixir | ForeverDB (container, drop), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `9172` | Invisibility Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `9179` | Elixir of Greater Intellect | ForeverDB (container, drop), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `9187` | Elixir of Greater Agility | ForeverDB (container, drop), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `9197` | Draught of Dream Vision | ForeverDB (container, drop, recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `9206` | Elixir of Greater Strength | ForeverDB (container, drop, recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `9224` | Potion of Demon Slaying | ForeverDB (container, drop, quest, recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `9233` | Draught of Detect Demon | AH, DB2 (crafted) |
| ELIXIR (candidate) | `9264` | Elixir of Shadow Power | ForeverDB (container, recipe), AH, DB2 (crafted) |
| HS (candidate) | `9421` | Major Healthstone | DB2 (crafted) |
| DRINK (candidate) | `9451` | Bubbling Water | ForeverDB (drop), AH, probe (ah) |
| FOOD (candidate) | `9681` | Grilled King Crawler Legs | ForeverDB (quest) |
| SCROLL (candidate) | `10305` | Scroll of Protection IV | ForeverDB (container, drop, object, vendor), AH |
| SCROLL (candidate) | `10306` | Scroll of Spirit IV | ForeverDB (container, drop, object, vendor), AH |
| SCROLL (candidate) | `10307` | Scroll of Stamina IV | ForeverDB (container, drop, object, vendor), AH |
| SCROLL (candidate) | `10308` | Scroll of Intellect IV | ForeverDB (container, drop, object, vendor), AH |
| SCROLL (candidate) | `10309` | Scroll of Agility IV | ForeverDB (container, drop, object, vendor), AH |
| SCROLL (candidate) | `10310` | Scroll of Strength IV | ForeverDB (container, drop, object, vendor), AH |
| ELIXIR (candidate) | `10592` | Catseye Draught | ForeverDB (container, drop), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `10841` | Goldthorn Tea | AH, DB2 (crafted) |
| FOOD (candidate) | `11109` | Special Chicken Feed | ForeverDB (drop, vendor), AH, probe (ah) |
| FOOD (candidate) | `11415` | Mixed Berries | ForeverDB (drop), AH |
| FOOD (candidate) | `11444` | Grim Guzzler Boar | ForeverDB (drop, object, vendor), AH |
| STAT_FOOD (candidate) | `11584` | Cactus Apple Surprise | ForeverDB (quest) |
| HP_POT (candidate) | `12190` | Dreamless Sleep Potion | AH, probe (ah), DB2 (crafted) |
| MP_POT (candidate) | `12190` | Dreamless Sleep Potion | AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `12209` | Lean Wolf Steak | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `12210` | Roast Raptor | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `12212` | Jungle Stew | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `12213` | Carrion Surprise | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `12214` | Mystery Stew | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `12215` | Heavy Kodo Stew | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `12216` | Spiced Chili Crab | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `12218` | Monster Omelet | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `12224` | Crispy Bat Wing | ForeverDB (recipe), AH, DB2 (crafted) |
| FOOD (candidate) | `12238` | Darkshore Grouper | AH, probe (ah) |
| WPN_ENCH (candidate) | `12404` | Dense Sharpening Stone | ForeverDB (container), AH, DB2 (crafted) |
| WPN_ENCH (candidate) | `12643` | Dense Weightstone | AH, DB2 (crafted) |
| ELIXIR (candidate) | `12820` | Winterfall Firewater | ForeverDB (drop), AH |
| CMBT_POT (candidate) | `13442` | Mighty Rage Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| MP_POT (candidate) | `13443` | Superior Mana Potion | ForeverDB (container, drop, quest, recipe, vendor), AH, DB2 (crafted) |
| MP_POT (candidate) | `13444` | Major Mana Potion | ForeverDB (container, drop, object, quest, recipe, vendor), AH, DB2 (crafted) |
| ELIXIR (candidate) | `13445` | Elixir of Greater Defense | ForeverDB (recipe), AH, DB2 (crafted) |
| HP_POT (candidate) | `13446` | Major Healing Potion | ForeverDB (container, drop, object, quest, recipe, vendor), AH, DB2 (crafted) |
| ELIXIR (candidate) | `13447` | Elixir of the Sages | ForeverDB (container, quest, recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `13452` | Elixir of the Mongoose | ForeverDB (container, quest, recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `13453` | Elixir of Brute Force | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `13454` | Greater Arcane Elixir | ForeverDB (container, recipe), AH, DB2 (crafted) |
| PROT_POT (candidate) | `13456` | Greater Frost Protection Potion | ForeverDB (container, recipe), AH, DB2 (crafted) |
| PROT_POT (candidate) | `13457` | Greater Fire Protection Potion | ForeverDB (container, recipe), AH, DB2 (crafted) |
| PROT_POT (candidate) | `13458` | Greater Nature Protection Potion | ForeverDB (container, recipe), AH, DB2 (crafted) |
| PROT_POT (candidate) | `13459` | Greater Shadow Protection Potion | ForeverDB (container, recipe), AH, DB2 (crafted) |
| PROT_POT (candidate) | `13461` | Greater Arcane Protection Potion | ForeverDB (container, recipe), AH, DB2 (crafted) |
| FLASK (candidate) | `13506` | Flask of Petrification | ForeverDB (recipe), AH, DB2 (crafted) |
| FLASK (candidate) | `13510` | Flask of the Titans | ForeverDB (recipe), AH, DB2 (crafted) |
| FLASK (candidate) | `13511` | Flask of Distilled Wisdom | ForeverDB (recipe), AH, DB2 (crafted) |
| FLASK (candidate) | `13512` | Flask of Supreme Power | ForeverDB (recipe), AH, DB2 (crafted) |
| FLASK (candidate) | `13513` | Flask of Chromatic Resistance | ForeverDB (recipe), AH, DB2 (crafted) |
| FOOD (candidate) | `13546` | Bloodbelly Fish | ForeverDB (drop, quest) |
| FOOD (candidate) | `13724` | Enriched Manna Biscuit | ForeverDB (drop, vendor), AH |
| DRINK (candidate) | `13724` | Enriched Manna Biscuit | ForeverDB (drop, vendor), AH |
| FOOD (candidate) | `13755` | Raw Winter Squid | AH, probe (ah) |
| FOOD (candidate) | `13810` | Blessed Sunfruit | ForeverDB (drop, vendor) |
| STAT_FOOD (candidate) | `13851` | Hot Wolf Ribs | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `13893` | Large Raw Mightfish | AH |
| STAT_FOOD (candidate) | `13927` | Cooked Glossy Mightfish | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `13928` | Grilled Squid | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `13929` | Hot Smoked Bass | ForeverDB (recipe), DB2 (crafted) |
| STAT_FOOD (candidate) | `13930` | Filet of Redgill | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `13931` | Nightfin Soup | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `13932` | Poached Sunscale Salmon | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `13933` | Lobster Stew | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `13934` | Mightfish Steak | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `13935` | Baked Salmon | ForeverDB (recipe), AH, DB2 (crafted) |
| BANDAGE (candidate) | `14529` | Runecloth Bandage | AH, DB2 (crafted) |
| BANDAGE (candidate) | `14530` | Heavy Runecloth Bandage | ForeverDB (vendor), AH, DB2 (crafted) |
| FOOD (candidate) | `16166` | Bean Soup | ForeverDB (vendor), AH, probe (ah) |
| FOOD (candidate) | `16167` | Versicolor Treat | ForeverDB (vendor), AH, probe (ah) |
| FOOD (candidate) | `16168` | Heaven Peach | ForeverDB (vendor), AH |
| FOOD (candidate) | `16169` | Wild Ricecake | ForeverDB (vendor), AH |
| FOOD (candidate) | `16170` | Steamed Mandu | ForeverDB (vendor), AH, probe (ah) |
| FOOD (candidate) | `16171` | Shinsollo | ForeverDB (vendor) |
| STAT_FOOD (candidate) | `16766` | Undermine Clam Chowder | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `16971` | Clamlette Surprise | ForeverDB (quest), AH, probe (ah) |
| FOOD (candidate) | `17119` | Deeprun Rat Kabob | ForeverDB (drop, quest, vendor), AH, probe (ah) |
| STAT_FOOD (candidate) | `17197` | Gingerbread Cookie | ForeverDB (recipe), DB2 (crafted) |
| STAT_FOOD (candidate) | `17198` | Egg Nog | ForeverDB (recipe), DB2 (crafted) |
| STAT_FOOD (candidate) | `17222` | Spider Sausage | AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `17344` | Candy Cane | ForeverDB (container, drop, vendor) |
| DRINK (candidate) | `17404` | Blended Bean Brew | ForeverDB (container, vendor) |
| FOOD (candidate) | `17406` | Holiday Cheesewheel | ForeverDB (container, vendor) |
| FOOD (candidate) | `17407` | Graccu's Homemade Meat Pie | ForeverDB (container, vendor) |
| FOOD (candidate) | `17408` | Spicy Beefstick | ForeverDB (vendor) |
| ELIXIR (candidate) | `17708` | Elixir of Frost Power | ForeverDB (recipe), DB2 (crafted) |
| STAT_FOOD (candidate) | `18045` | Tender Wolf Steak | ForeverDB (recipe), AH, DB2 (crafted) |
| HP_POT (candidate) | `18253` | Major Rejuvenation Potion | ForeverDB (quest, recipe), AH, DB2 (crafted) |
| MP_POT (candidate) | `18253` | Major Rejuvenation Potion | ForeverDB (quest, recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `18254` | Runn Tum Tuber Surprise | ForeverDB (recipe), AH, DB2 (crafted) |
| FOOD (candidate) | `18255` | Runn Tum Tuber | ForeverDB (drop, object), AH |
| WPN_ENCH (candidate) | `18262` | Elemental Sharpening Stone | ForeverDB (recipe), DB2 (crafted) |
| ELIXIR (candidate) | `18294` | Draught of Greater Water Breathing | AH, DB2 (crafted) |
| DRINK (candidate) | `18300` | Hyjal Nectar | ForeverDB (object) |
| FOOD (candidate) | `18632` | Moonbrook Riot Taffy | ForeverDB (vendor) |
| FOOD (candidate) | `18633` | Styleen's Sour Suckerpop | ForeverDB (vendor) |
| FOOD (candidate) | `18635` | Bellara's Nutterbar | ForeverDB (vendor) |
| HS (candidate) | `19004` | Minor Healthstone | DB2 (crafted) |
| HS (candidate) | `19005` | Minor Healthstone | DB2 (crafted) |
| HS (candidate) | `19006` | Lesser Healthstone | DB2 (crafted) |
| HS (candidate) | `19007` | Lesser Healthstone | DB2 (crafted) |
| HS (candidate) | `19008` | Healthstone | DB2 (crafted) |
| HS (candidate) | `19009` | Healthstone | DB2 (crafted) |
| HS (candidate) | `19010` | Greater Healthstone | DB2 (crafted) |
| HS (candidate) | `19011` | Greater Healthstone | DB2 (crafted) |
| HS (candidate) | `19012` | Major Healthstone | DB2 (crafted) |
| HS (candidate) | `19013` | Major Healthstone | DB2 (crafted) |
| FOOD (candidate) | `19223` | Darkmoon Dog | ForeverDB (drop, vendor), AH |
| FOOD (candidate) | `19224` | Red Hot Wings | ForeverDB (drop, vendor), AH |
| FOOD (candidate) | `19225` | Deep Fried Candybar | ForeverDB (drop, vendor) |
| DRINK (candidate) | `19299` | Fizzy Faire Drink | ForeverDB (drop, vendor), AH |
| DRINK (candidate) | `19300` | Bottled Winterspring Water | ForeverDB (drop, vendor), AH |
| FOOD (candidate) | `19301` | Alterac Manna Biscuit | ForeverDB (drop, vendor) |
| DRINK (candidate) | `19301` | Alterac Manna Biscuit | ForeverDB (drop, vendor) |
| FOOD (candidate) | `19304` | Spiced Beef Jerky | ForeverDB (drop, vendor), AH |
| FOOD (candidate) | `19305` | Pickled Kodo Foot | ForeverDB (drop, vendor), AH |
| FOOD (candidate) | `19306` | Crunchy Frog | ForeverDB (drop, vendor), AH |
| BANDAGE (candidate) | `19307` | Alterac Heavy Runecloth Bandage | ForeverDB (drop, vendor) |
| FOOD (candidate) | `19994` | Harvest Fruit | ForeverDB (object) |
| FOOD (candidate) | `19995` | Harvest Boar | ForeverDB (object) |
| FOOD (candidate) | `19996` | Harvest Fish | ForeverDB (object) |
| ELIXIR (candidate) | `20004` | Major Troll's Blood Elixir | ForeverDB (recipe), DB2 (crafted) |
| ELIXIR (candidate) | `20007` | Mageblood Elixir | ForeverDB (recipe), DB2 (crafted) |
| CMBT_POT (candidate) | `20008` | Living Action Potion | ForeverDB (recipe), DB2 (crafted) |
| FOOD (candidate) | `20031` | Essence Mango | ForeverDB (quest) |
| DRINK (candidate) | `20031` | Essence Mango | ForeverDB (quest) |
| STAT_FOOD (candidate) | `20074` | Heavy Crocolisk Stew | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `20452` | Smoked Desert Dumplings | AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `20516` | Bobbing Apple | ForeverDB (object) |
| WPN_ENCH (candidate) | `20744` | Minor Wizard Oil | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `20745` | Minor Mana Oil | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| WPN_ENCH (candidate) | `20748` | Brilliant Mana Oil | ForeverDB (recipe), DB2 (crafted) |
| WPN_ENCH (candidate) | `20749` | Brilliant Wizard Oil | ForeverDB (recipe), DB2 (crafted) |
| WPN_ENCH (candidate) | `20750` | Wizard Oil | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `21023` | Dirge's Kickin' Chimaerok Chops | ForeverDB (quest, recipe), DB2 (crafted) |
| FOOD (candidate) | `21030` | Darnassus Kimchi Pie | ForeverDB (vendor), AH |
| FOOD (candidate) | `21031` | Cabbage Kimchi | ForeverDB (vendor), AH |
| FOOD (candidate) | `21033` | Radish Kimchi | ForeverDB (vendor) |
| STAT_FOOD (candidate) | `21072` | Smoked Sagefish | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `21215` | Graccu's Mince Meat Fruitcake | ForeverDB (container) |
| DRINK (candidate) | `21215` | Graccu's Mince Meat Fruitcake | ForeverDB (container) |
| STAT_FOOD (candidate) | `21217` | Sagefish Delight | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `21235` | Winter Veil Roast | ForeverDB (container, drop, quest) |
| STAT_FOOD (candidate) | `21254` | Winter Veil Cookie | ForeverDB (container, quest) |
| ELIXIR (candidate) | `21546` | Elixir of Holy Power | ForeverDB (recipe), AH, DB2 (crafted) |
| FOOD (candidate) | `21552` | Striped Yellowtail | ForeverDB (vendor) |
| FOOD (candidate) | `22324` | Winter Kimchi | ForeverDB (vendor), AH |
| FOOD (candidate) | `22895` | Conjured Cinnamon Roll | ForeverDB (vendor), DB2 (crafted) |
| WPN_ENCH (candidate) | `23122` | Consecrated Sharpening Stone | ForeverDB (quest) |
| WPN_ENCH (candidate) | `23123` | Blessed Wizard Oil | ForeverDB (quest) |
| FOOD (candidate) | `23160` | Friendship Bread | ForeverDB (vendor) |
| MP_POT (candidate) | `23578` | Diet McWeaksauce | ForeverDB (vendor) |
| HP_POT (candidate) | `23579` | The McWeaksauce Classic | ForeverDB (vendor) |
| BANDAGE (candidate) | `23684` | Crystal Infused Bandage | ForeverDB (recipe), DB2 (crafted) |
| SCROLL (candidate) | `213564` | Scroll of Minor Evocation | ForeverDB (container), AH, probe (ah) |
| SCROLL (candidate) | `215257` | Scroll of Comprehension | ForeverDB (container) |
| ELIXIR (candidate) | `217398` | Lesser Arcane Elixir | ForeverDB (recipe), DB2 (crafted) |
| WPN_ENCH (candidate) | `232611` | Magnificent Trollshine | ForeverDB (recipe), DB2 (crafted) |
| HP_POT (candidate) | `241650` | Major Discolored Healing Potion | AH, DB2 (crafted) |
| ELIXIR (candidate) | `246948` | Distilled Firewater | ForeverDB (recipe), AH, DB2 (crafted) |
| HP_POT (candidate) | `247239` | Lesser Discolored Healing Potion | AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `247240` | Discolored Healing Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `247241` | Greater Discolored Healing Potion | AH, probe (ah), DB2 (crafted) |
| HP_POT (candidate) | `247242` | Superior Discolored Healing Potion | AH, DB2 (crafted) |
| ELIXIR (candidate) | `247754` | Minor Arcane Elixir | AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `247755` | Elixir of Minor Force | AH, probe (ah), DB2 (crafted) |
| FOOD (candidate) | `248613` | Lightning in a Bottle | ForeverDB (drop, vendor), AH, probe (ah) |
| STAT_FOOD (candidate) | `249865` | Peace Tea | ForeverDB (drop, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `249866` | Royal Tea | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249867` | Root Tea | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `249868` | Triage Tea | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249869` | Sunny Tea | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249870` | Sage's Tea | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249871` | Venomous Smoothie | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249872` | Slimy Smoothie | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249873` | Mrrggl Smrrthle | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `249874` | Calcified Smoothie | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249875` | Spicy Smoothie | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `249876` | Wicked Smoothie | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250065` | Savory Stag Sliders | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250067` | Bat Hachee | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250068` | Savory Turtle Stew | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250069` | Flank au Poivre | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250070` | Bear Bruscitti | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250071` | Steaming Stag Steak | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250072` | Swiftstrike Steak | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250073` | Raging Raptor Ribs | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250074` | Bear Brisket | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `250075` | Prehistoric Pulled Raptor | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250076` | Raptor Rouladen | ForeverDB (recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250077` | Twice-Spiced Raptor Slice | ForeverDB (quest, recipe), AH, DB2 (crafted) |
| STAT_FOOD (candidate) | `250078` | Giant Scrambled Eggs | ForeverDB (recipe), DB2 (crafted) |
| STAT_FOOD (candidate) | `250079` | Tasty Raptor Bites | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `250080` | Breakfast Omelette | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `250081` | Clam Linguine | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250327` | Potion of Predatory Senses | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250328` | Elixir of Cunning | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250329` | Elixir of the Phalanx | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250330` | Minor Cleric's Elixir | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250331` | Lesser Cleric's Elixir | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250332` | Cleric's Elixir | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250333` | Greater Cleric's Elixir | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250334` | Elixir of Fortitude | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250335` | Elixir of Greater Fortitude | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250336` | Elixir of Wicked Regeneration | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250337` | Elixir of the Owl | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250338` | Elixir of Sages | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250339` | Minor Mageblood Elixir | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250340` | Lesser Mageblood Elixir | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250341` | Greater Mageblood Elixir | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250342` | Lesser Arcane Elixir | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250343` | Elixir of Nature Power | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250344` | Elixir of Minor Spirit | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250345` | Elixir of Lesser Spirit | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250346` | Elixir of Spirit | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250347` | Elixir of Greater Spirit | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250348` | Elixir of the Whale | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250349` | Elixir of Strength | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250350` | Elixir of Ferocity | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250351` | Elixir of the Grizzly | ForeverDB (recipe), AH, DB2 (crafted) |
| ELIXIR (candidate) | `250353` | Elixir of Lesser Intellect | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| ELIXIR (candidate) | `250354` | Elixir of Intellect | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250932` | Minor Spellblasting Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250933` | Lesser Spellblasting Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250934` | Spellblasting Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250935` | Greater Spellblasting Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250936` | Superior Spellblasting Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250937` | Major Spellblasting Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250938` | Minor Frenzy Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250939` | Lesser Frenzy Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250940` | Frenzy Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250941` | Greater Frenzy Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250942` | Superior Frenzy Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250943` | Major Frenzy Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250944` | Minor Mender's Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250945` | Lesser Mender's Potion | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250946` | Mender's Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250947` | Greater Mender's Potion | AH, probe (ah), DB2 (crafted) |
| CMBT_POT (candidate) | `250948` | Superior Mender's Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250949` | Major Mender's Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250950` | Potion of Venomous Blood | ForeverDB (recipe), AH, DB2 (crafted) |
| CMBT_POT (candidate) | `250953` | Dragonfire Potion | ForeverDB (recipe), AH, DB2 (crafted) |
| FOOD (candidate) | `252022` | Galestrider Jerky | ForeverDB (drop, object), AH, probe (ah) |
| FOOD (candidate) | `252023` | Zaalanarr Sharp | ForeverDB (object) |
| FOOD (candidate) | `252026` | Gustberry Pie | ForeverDB (drop, vendor) |
| DRINK (candidate) | `252027` | Gustberry Juice | ForeverDB (drop, vendor), AH, probe (ah) |
| FOOD (candidate) | `252028` | Fresh Gustberry Bread | ForeverDB (drop, object), AH, probe (ah) |
| FOOD (candidate) | `252029` | Hippogryph Flank | ForeverDB (drop, vendor) |
| FOOD (candidate) | `252030` | Pungent Skycheddar | ForeverDB (drop, object, vendor), AH, probe (ah) |
| DRINK (candidate) | `252031` | Crisp Spring Water | ForeverDB (drop, object), AH, probe (ah) |
| FOOD (candidate) | `252032` | Red Delicious Stormapple | ForeverDB (drop, object, quest, vendor), AH, probe (ah) |
| FOOD (candidate) | `262433` | Ketharas' Hyjal Stew | ForeverDB (quest) |
| DRINK (candidate) | `262433` | Ketharas' Hyjal Stew | ForeverDB (quest) |
| STAT_FOOD (candidate) | `263509` | Skywall Souffle | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `263512` | Pincer Bites | ForeverDB (quest, recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `267341` | Sweetpaw Jam | ForeverDB (recipe), AH, DB2 (crafted) |
| FOOD (candidate) | `267474` | Galeswept Forestshroom | ForeverDB (drop, object), AH, probe (ah) |
| STAT_FOOD (candidate) | `268912` | Expiring Crab Cake | ForeverDB (object) |
| STAT_FOOD (candidate) | `268913` | Expiring Crocolisk Steak | ForeverDB (object) |
| HP_POT (candidate) | `274935` | Tessa's Tonic | ForeverDB (quest) |
| MP_POT (candidate) | `274935` | Tessa's Tonic | ForeverDB (quest) |
| STAT_FOOD (candidate) | `274971` | Briny Seafood Stew | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| STAT_FOOD (candidate) | `274976` | Plain Ol' Paletusk | ForeverDB (recipe), AH, probe (ah), DB2 (crafted) |
| SCROLL (candidate) | `275069` | Scroll of Rat Familiar | ForeverDB (container), AH, probe (ah) |
| SCROLL (candidate) | `277483` | Scroll of Frog Familiar | AH, probe (ah) |
| SCROLL (candidate) | `277493` | Scroll of Cat Familiar | AH, probe (ah) |
| FOOD (candidate) | `278117` | Hard Boiled Eggs | ForeverDB (drop, vendor) |
| FOOD (candidate) | `278118` | Rich Broth | ForeverDB (drop) |
| FOOD (candidate) | `278119` | Bread with Butter | ForeverDB (drop, vendor) |
| FOOD (candidate) | `278120` | Fruit Platter | ForeverDB (drop) |
| FOOD (candidate) | `278121` | Smoked Sausage | ForeverDB (drop, vendor) |
| FOOD (candidate) | `278122` | Carrot Salad | ForeverDB (drop) |
| FOOD (candidate) | `278265` | Nutritious Slime Sludge | ForeverDB (drop, vendor) |
| STAT_FOOD (candidate) | `286152` | Plated Armorfish | ForeverDB (recipe), AH, DB2 (crafted) |
| HP_POT (candidate) | `288896` | Superior Healing Potion | ForeverDB (drop) |
| MP_POT (candidate) | `288897` | Superior Mana Potion | ForeverDB (drop) |
| CMBT_POT (candidate) | `288898` | Swiftness Potion | ForeverDB (drop) |
| ELIXIR (candidate) | `289082` | Elixir of Endless Intellect | ForeverDB (drop) |
| ELIXIR (candidate) | `289083` | Elixir of Endless Power | ForeverDB (drop) |
| ELIXIR (candidate) | `289084` | Elixir of Endless Healing | ForeverDB (drop) |
| ELIXIR (candidate) | `289086` | Elixir of Endless Rapidity | ForeverDB (drop) |
| ELIXIR (candidate) | `289087` | Elixir of Endless Opportunity | ForeverDB (drop) |
| SCROLL (candidate) | `289088` | Scroll of Endless Fortitude | ForeverDB (drop) |
| ELIXIR (candidate) | `289321` | Elixir of Endless Mana | ForeverDB (drop) |
| ELIXIR (candidate) | `289329` | Elixir of Endless Growth | ForeverDB (drop) |
| SCROLL (candidate) | `289330` | Scroll of Endless Speed | ForeverDB (drop) |
| ELIXIR (candidate) | `289334` | Elixir of Endless Experience | ForeverDB (drop) |
