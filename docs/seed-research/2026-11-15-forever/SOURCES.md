# Sources — seed validation, 2026-11-15 (forever)

Written by `tools/seeds/seeds.py derive`. Frozen: never edited after the run.

| Field | Value |
| --- | --- |
| Client | `forever` (wago.tools product `wowf`) |
| Build | `1.60.1.70938` |
| Build created | 2026-11-13 01:36:09 |
| Run date | 2026-11-15 (the `--date` argument; the tool never reads the clock) |
| Builds API | <https://wago.tools/api/builds> |

## Tables

| Table | Why | URL |
| --- | --- | --- |
| `Item` | ClassID / SubclassID: the category fit | <https://wago.tools/db2/Item/csv?build=1.60.1.70938> |
| `ItemSparse` | Display_lang: the name | <https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70938> |
| `SpellName` | Name_lang: spell-seed names | <https://wago.tools/db2/SpellName/csv?build=1.60.1.70938> |

The gzipped exports are in `raw/`. `seeds.py derive --replay` re-derives this bundle
from them with no network and no cache.
