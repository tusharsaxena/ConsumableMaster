# Analysis — WoW Forever seed validation, 2026-11-15 (build 1.60.1.70938)

GitHub issue #49. The first Forever run of `tools/seeds/seeds.py`, under the contract in
`docs/validate-seeds.md`, against the live WoW Forever build on wago.tools (product `wowf`,
1.60.1.70938). It reads three tables, `Item`, `ItemSparse` and `SpellName`.

## What there is to check

Every `forever` list in `defaults/Defaults_*.lua` is empty by decision (step 2, owner ruling
2026-11-08): every Forever candidate comes from the bag scan, and Forever's stat priorities wait for
its own spec ids. So the run proposes no candidates, and it checks the one Forever list that ships
ids, `core/Classifier.lua`'s `HEALTHSTONE_IDS`, which Forever reads because its `HS` category exists
there. `VANTUS_IDS` and `REUSABLE_AUG_IDS` are not read: Forever has no Vantus Rune or Augment Rune
category (`defaults/Categories.lua`).

| Check | Result |
| --- | --- |
| Shipped ids checked | 2 (`HEALTHSTONE_IDS`) |
| Candidates | 0, by the owner ruling above |
| Flags | 1 |

## The flag, kept

**`CLASSIFIER_HS` 224464** has no row on the Forever build: it is Retail's Demonic Healthstone.
`HEALTHSTONE_IDS` is one table that both clients read, so the Retail id simply matches nothing on
Forever. It is kept. 5512, the other entry, is *Minor Healthstone* on this build (on Retail it is
*Healthstone*), and it is the one Forever discovers, as `Defaults_Healthstone.lua`'s Forever note
says. The build also has the other vanilla ranks (Lesser 5511, Healthstone 5509, Greater 5510, Major
9421, and two more ids named Minor Healthstone, 19004 and 19005), which that note says wait for
step 2.

## What a later run should re-check

- When the owner lifts the 2026-11-08 ruling and a Forever list gains ids, they are flagged like
  Retail's; the candidate rules for Forever are then written against its own subclasses (Draught 13,
  temporary Item Enhancement 15) and its own tables, never by filtering Retail's lists.
- Whether `HEALTHSTONE_IDS` should split per client, as the seed lists are (a question for the
  owner, not a ruling).
