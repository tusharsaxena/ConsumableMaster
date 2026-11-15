# Sources — seed validation, 2026-11-15 (retail)

Written by `tools/seeds/seeds.py derive`. Frozen: never edited after the run.

| Field | Value |
| --- | --- |
| Client | `retail` (wago.tools product `wow`) |
| Build | `12.1.5.70783` |
| Build created | 2026-11-04 00:38:01 |
| Run date | 2026-11-15 (the `--date` argument; the tool never reads the clock) |
| Builds API | <https://wago.tools/api/builds> |

## Tables

| Table | Why | URL |
| --- | --- | --- |
| `Item` | ClassID / SubclassID / CraftingQualityID: the category fit and the quality tier | <https://wago.tools/db2/Item/csv?build=12.1.5.70783> |
| `ItemSparse` | Display_lang / ExpansionID / OverallQualityID / ItemLevel / Flags_0: the name and the window | <https://wago.tools/db2/ItemSparse/csv?build=12.1.5.70783> |
| `ItemXItemEffect` | ItemID -> ItemEffectID, step 1 of the item -> spell join | <https://wago.tools/db2/ItemXItemEffect/csv?build=12.1.5.70783> |
| `ItemEffect` | ItemEffectID -> SpellID, step 2: the spell the item casts | <https://wago.tools/db2/ItemEffect/csv?build=12.1.5.70783> |
| `SpellName` | Name_lang: spell-seed names, and the Well Fed buff a meal references | <https://wago.tools/db2/SpellName/csv?build=12.1.5.70783> |
| `Spell` | Description_lang: what the item's spell says it does (evidence, Well Fed, Augment Rune) | <https://wago.tools/db2/Spell/csv?build=12.1.5.70783> |
| `SpellEffect` | Effect / EffectAura / EffectMiscValue_0 / EffectTriggerSpell: heal, mana, absorb, temporary enchant | <https://wago.tools/db2/SpellEffect/csv?build=12.1.5.70783> |
| `SpellMisc` | DurationIndex: a combat potion's buff duration | <https://wago.tools/db2/SpellMisc/csv?build=12.1.5.70783> |
| `SpellDuration` | Duration: DurationIndex -> milliseconds | <https://wago.tools/db2/SpellDuration/csv?build=12.1.5.70783> |
| `ChrSpecialization` | ID / ClassID / Name_lang / OrderIndex: the stat-priority keys | <https://wago.tools/db2/ChrSpecialization/csv?build=12.1.5.70783> |
| `JournalInstance` | Name_lang: whether the raid a Vantus rune names is in the journal (Retail only) | <https://wago.tools/db2/JournalInstance/csv?build=12.1.5.70783> |

The gzipped exports are in `raw/`. `seeds.py derive --replay` re-derives this bundle
from them with no network and no cache.
