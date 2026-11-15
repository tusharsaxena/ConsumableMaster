# Seed validation — Consumable Master

The seed-validation contract `/dev-copilot:validate-seeds ConsumableMaster <flavor>` runs. The
command supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Consumable Master's procedure: the tool, the files it writes, the
precedent a ruling follows and the nuances of each client. The headings below are the interface the
command reads, so keep their names.

The tool is `tools/seeds/seeds.py` (Python 3.8+, standard library only; its docstring is the
reference), with its tests in `tools/seeds/test_seeds.py`. Each run ends in a frozen bundle under
`docs/seed-research/<date>-<flavor>/`: `raw/*.csv.gz` (the tables the run read), `SOURCES.md`,
`candidates.json`, `DIFF.md`, `RULINGS.md` and a hand-written `ANALYSIS.md`. The first runs are
`docs/seed-research/2026-11-15-retail/` and `docs/seed-research/2026-11-15-forever/` (issue #49).
The game rules behind it are `clients-§10` of the Ka0s WoW Addon Standard.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | the `retail` lists of `defaults/Defaults_*.lua`; the `HEALTHSTONE_IDS`, `VANTUS_IDS` and `REUSABLE_AUG_IDS` whitelists in `core/Classifier.lua` | `tools/seeds/seeds.py --flavor retail` |
| `forever` | wago.tools product `wowf` (WoW Forever) | the `forever` lists of `defaults/Defaults_*.lua` (empty by decision); `HEALTHSTONE_IDS` | `tools/seeds/seeds.py --flavor forever` |

`defaults/Categories.lua` holds no ids. The tool reads it only for each category's `clients`, which
decides whether a flavor reads a `core/Classifier.lua` whitelist (Forever has no Vantus Rune or
Augment Rune category, so it reads `HEALTHSTONE_IDS` alone).

## Rules

- **What the tool writes.** `seeds.py apply` is the only writer of an id it adds to or removes from
  a seed list. It inserts an accepted id at the end of its list's block, with the comment
  `-- <name>; added from the <date> wago.tools validation (<build>)`, and writes an accepted
  `VANTUS` id into `VANTUS_IDS` as well, because `Defaults_Vantus.lua`'s header moves the two
  together. It keeps each file's CRLF line endings. Hand edits stay allowed for everything else in
  these files (comments, headers, the stat priorities' orders), and a `renamed` flag is fixed by
  hand, in the comment.
- **Rulings are data.** Retail's live in `tools/seeds/retail_rulings.json` and Forever's in
  `tools/seeds/forever_rulings.json`, and `seeds.py rule` is the only writer of either. A candidate
  is keyed `<LIST>:<id>` and a flag `shipped:<kind>:<LIST>:<id>`, where a spell id reads
  `spell<id>` and a stat-priority key `<classID>_<specID>`; never by build. A ruling holds until the
  thing it ruled on stops being proposed.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the owner rulings recorded in the seed files and docs: WoW Forever's lists are **empty by
     decision** (step 2, owner ruling 2026-11-08), and every Forever candidate comes from the bag
     scan; Forever's stat priorities wait for its own spec ids;
  3. each seed file's header, and `defaults/README.md` → *Category scope decisions* and the
     refresh *Procedure*:
     - **FLASK:** combat flasks only; the Haranir profession phials stay out.
     - **CMBT_POT:** throughput potions with a short buff (60 s or less); no utility potion
       (invisibility, slow fall, swiftness, water breathing, free action) and no absorb potion.
     - **HP_POT / MP_POT:** a direct heal or a mana restore; no shield or absorb potion.
     - **STAT_FOOD:** cooked stat meals, the base tier only; no feast (single-serve or raid-wide)
       and no Hearty variant.
     - **FOOD / DRINK:** the Silvermoon innkeeper's stock, plus the mage's Conjured Mana Bun.
     - **WPN_ENCH:** Enchanting oils and Blacksmithing whetstones and weightstones of the last two
       expansions.
     - **AUG_RUNE:** Legion on; the Warlords garrison runes stay out.
     - **VANTUS:** one current rune per raid tier, added as the tier ships.
     - **HS:** a fixed two-entry whitelist.
     - **BLOODLUST / BATTLE_REZ:** seed plus user-added only, no Classifier matcher; the ids are
       pending in-game confirmation, and the older drums are added once confirmed with
       `/cm dump item`.
     - **Every list:** one crafting-quality tier per item, and auto-discovery takes the other
       tiers and the Fleeting (cauldron) copies (Procedure step 5).
- **What "accept" means here.** Accept an id the build's own data shows fits its list's header, which
  the seed would carry if it were refreshed by hand today, and which is either new since the last
  refresh or plainly meant (a comment that names it). Seed the tier the list's other entries carry.
- **What to reject.**
  - A quality twin or a Fleeting or Hearty copy of an id the list ships.
  - Anything a header above excludes.
  - Anything already present at the last refresh and left out without a recorded reason, and
    anything whose content may not be live (a Vantus rune whose raid is not in the journal): reject
    it with `needs owner review: <why>`, so the owner sees it in `RULINGS.md` and can flip it with
    `seeds.py rule`.
- **Evidence.** Read each candidate's notes in `candidates.json`: class, subclass, expansion,
  quality, crafting quality, the use spell's effects (heal, mana, absorb), its duration, the stat
  its description names, and the shipped id it twins. Read the raw tables when a note is not
  enough. DB2 says what an item does, not what a player uses, so a ruling still needs the header's
  rule behind it.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/seeds/seeds.py status --flavor retail
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`, comparing the
live `wow` build with the newest `*-retail` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date> --build <build>
```

It downloads the eleven Retail tables on a new build (about 200 MB, cached in `tools/seeds/.cache/`),
freezes them gzipped into the bundle's `raw/` (about 30 MB), and runs the coverage gate: a rule that
admits none of its own list's shipped in-window ids stops the run. **If the gate fails, stop**: the
pipeline needs fixing, not the rulings. Report the per-list counts it prints: shipped ids, flags,
candidates and the unruled total.

The candidate rules, one per list that has a mechanical one (`RULES` in the tool):

| List | Window | The rule |
| --- | --- | --- |
| `FLASK` | consumable subclass 3, current expansion | the subclass |
| `HP_POT`, `MP_POT`, `CMBT_POT` | consumable subclass 1, current expansion | a heal goes to `HP_POT`, a mana restore to `MP_POT` (both, for both), else a buff of 1 to 60 s with no absorb to `CMBT_POT`; the rest is listed in `DIFF.md` as unplaced and never ruled |
| `STAT_FOOD` | consumable subclass 5, current expansion | eaten from the bag (a seated regen aura, so a feast never qualifies) and Well Fed |
| `VANTUS` | consumable subclass 9, current expansion | a Vantus Rune; its notes say whether the raid it names is in `JournalInstance` |
| `WPN_ENCH` | consumable subclass 8, the last two expansions | a temporary enchant whose description says "your ... weapon" (a fishing lure or a profession-tool stone is not one) |
| `AUG_RUNE` | consumable subclass 8, any expansion | the "Augment Rune" marker in the description |
| `STAT_PRIORITY` | every `ChrSpecialization` row of a player class, order 0 to 3 | a spec the table has no `<classID>_<specID>` row for |

`FOOD`, `DRINK`, `HS`, `BLOODLUST`, `BATTLE_REZ` and `CLASS_GATE` have no mechanical rule (a
vendor's stock is not in DB2, and the others are fixed or pending in-game confirmation), so they get
flags only. `CURRENT_EXPANSION` in the tool is Midnight's `ExpansionID`, 11: when the next expansion
ships, raise it in the same change as the run.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-retail
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and exits 1 while any is left; it must print `OK` after `rule`.

- **Candidates** (`accept` or `reject`), by the precedent and the accept and reject rules above.
- **Flags** (`keep` or `remove`):
  - `unnamed`: the build has no row for the id. Remove it, unless the file says why it ships by hand.
  - `renamed`: the build's name disagrees with the comment. When the id is still the right item, keep
    it and fix the comment by hand; when the id was reused, remove it.
  - `misfiled`: the item's class or subclass (a stat-priority key's class) no longer fits its list.
    Remove it, unless the list's header says it belongs.
  - `unmatched`: the id sits in its list's window but the rule no longer admits it, as when a
    combat potion turns into a utility one. Read its effects before ruling.

An accepted `STAT_PRIORITY` candidate has no writer: its secondary order is archon.gg's, not DB2's
(`Defaults_StatPriority.lua`'s header), so `apply` refuses it. Reject it with `needs owner review`
and add the row by hand.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` comes before `apply`, because `RULINGS.md` has to be written while the candidates still
include the accepted ids. `apply` refuses while anything is unruled, and a second `apply` changes
nothing. Then fix each `renamed` flag ruled `keep` in its comment, by hand.

`derive --replay` re-derives a bundle from its own `raw/` with no network, and only verifies: it
writes nothing, and fails once the bundle's accepts are applied, because the seeds have moved. Replay
a bundle at the revision that froze it.

### After

- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape: what changed, what was
  accepted and rejected and why, and what a later run should re-check.
- Add a check to `docs/smoke-tests.md` → *Discovery* for every list that gained an id, with its
  *Pending sign-off* note, following DISC-9. A run that ships nothing new adds none.
- Update the `Source:` and `Last refresh:` header lines of each seed file that changed.

### Stage

The changed `defaults/Defaults_*.lua` files, `core/Classifier.lua` when `VANTUS_IDS` moved,
`tools/seeds/retail_rulings.json`, `docs/seed-research/<date>-retail/`, `docs/smoke-tests.md`, plus
any citation edits. Commit message: `Seeds (retail): re-validated against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 tools/seeds/seeds.py status --flavor forever
```

Prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`, comparing the live `wowf` build with the
newest `*-forever` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor forever --bundle docs/seed-research/<date>-forever --date <date> --build <build>
```

Forever reads three tables (`Item`, `ItemSparse`, `SpellName`; under 1 MB gzipped) and proposes **no
candidates**: its lists are empty by decision (owner ruling 2026-11-08), and every Forever candidate
comes from the bag scan. It flags every id a Forever list ships, which today is `HEALTHSTONE_IDS`
alone. When the owner lifts the ruling and a Forever list gains ids, they are flagged like Retail's;
Forever candidate rules would then be written against its own subclasses (Draught 13, temporary Item
Enhancement 15), never by filtering Retail's lists (`clients-§5`).

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-forever
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-forever
```

Flags only, ruled as on Retail. `HEALTHSTONE_IDS` is one table for both clients, so its Retail id
224464 is `unnamed` on Forever; it was kept on 2026-11-15, and that ruling stands.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

With no candidates, `apply` changes something only for a flag ruled `remove`.

### After

- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape.
- Add a FOREVER smoke check for any Forever list that changed, with its *Pending sign-off* note.

### Stage

`tools/seeds/forever_rulings.json`, `docs/seed-research/<date>-forever/`, plus any seed, smoke or
citation edits. Commit message: `Seeds (forever): re-validated against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. `tools/seeds/test_seeds.py`
needs no network, and its repo cases fail while the newest bundle of either flavor has a key unruled.

## Notes

- **Bundle size.** A Retail bundle's `raw/` is about 30 MB, most of it `ItemSparse`, `Spell`,
  `SpellEffect` and `SpellMisc`; a Forever bundle's is under 1 MB. One bundle per patch is
  acceptable.
- **What DB2 cannot say.** Which vendor sells an item (so `FOOD` and `DRINK` get no candidates),
  whether an augment rune is reusable (so `REUSABLE_AUG_IDS` is checked but never extended), and a
  spec's secondary order (archon.gg's). Those stay hand-curated.
- **Whether an item is new.** A bundle carries one build. To tell an item new since the last refresh
  from one the refresh left out, compare against the `Item` table of the build that was live on the
  refresh date, and say in `ANALYSIS.md` which build that was; the 2026-11-15 run used
  `12.0.5.67114`.
- **A shared helper.** The download, cache, bundle and rulings code is copied from AuraMaster's
  `tools/spell-research/`. Whether it becomes one shared helper is LibKa0s#91.
