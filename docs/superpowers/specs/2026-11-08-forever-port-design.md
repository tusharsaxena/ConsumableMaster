# ConsumableMaster on WoW Forever, step 1: categories and discovery, no seed lists

Owner request, 2026-11-08: "make it compatible with Forever with no seed lists - this means find the relevant
macro categories that need to be created, show only those for forever. Once that works, and the default logic
is in play for the default categories, then we can start adding seed lists." Seed lists are step 2, a separate
spec.

## Facts this rests on

- WoW Forever is vanilla-era Azeroth, level cap 60, a Mainline game type (client 1.60.1, interface 16001).
  Detection is `LibKa0s-Compat-1.0`'s `ForClient` / `ClientKey` only (clients-§3).
- `Enum.ItemConsumableSubclass` uses Retail's numbers on Forever (Potion 1, Elixir 2, Flask 3, Scroll 4, Food &
  Drink 5, Item Enhancement 6, Bandage 7, Other 8) and adds **Draught 13, Device 14, ItemenhancementTemporary
  15** (Ketho/BlizzardInterfaceResources `forever` 1.60.1 (70532), `Resources/LuaEnum.lua`).
- Every API the addon calls exists on Forever: GetItemInfoInstant, the spec readers through Compat,
  GetSpecializationInfoForClassID, the macro API, C_Container and C_TooltipInfo.
- The Ranker already ranks without a stat-priority seed: `SpecHelper.GetStatPriority` falls back to the class's
  primary stat, and vanilla's class IDs are Retail's.

## The owner's rulings (2026-11-08)

| Category | Retail | Forever |
|---|---|---|
| FOOD, DRINK, HP_POT, MP_POT, HS, FLASK, CMBT_POT, STAT_FOOD, WPN_ENCH, HP_AIO, MP_AIO | yes | yes |
| VANTUS, AUG_RUNE, BLOODLUST, BATTLE_REZ | yes | **absent** |
| ELIXIR, BANDAGE, SCROLL, PROT_POT (protection potion) | no | **new, Forever only** |

Forever's three new subclasses are accepted wherever an item's tooltip fits a category. The owner will confirm
with an in-game `/cm dump bags` and the auction house.

## Design

1. **Categories declare their clients** (clients-§4). Each row in `defaults/Categories.lua` may carry
   `clients = { "retail" }` or `{ "forever" }`. `KCM.Categories.LIST` and `BY_KEY` hold only the rows
   `Compat.ForClient(row.clients)` admits, filtered once at load. Every reader of the list (pipeline, macro
   manager, settings pages, macro bar, slash and dump verbs, schema rows, profile defaults) therefore sees the
   client's set. An absent category has no macro, no settings page, no macro-bar slot, no slash name and no
   schema row. It is not created and then hidden. Code that names a Retail-only key directly (the Bloodlust class
   gate, Vantus, augment-rune reusability, the battle-rez targeting) is reached only through its category, or is
   guarded so nothing runs on Forever.
2. **Seed lists are per client, and Forever's are empty by decision** (clients-§5). `KCM.SEED.*` is chosen once,
   at load, by `ClientKey()`. Retail gets today's lists. Forever gets an empty table for every category, and an
   empty `STAT_PRIORITY`, each saying "empty by decision, step 2". No Retail item ID is a Forever candidate, so on
   Forever every candidate comes from the bag scan (the default logic).
3. **The four new categories** are single-pick macros (`KCM_ELIXIR`, `KCM_BANDAGE`, `KCM_SCROLL`, `KCM_PROT_POT`),
   Forever only, with Classifier matchers and Ranker scoring:
   - ELIXIR: consumable subclass 2. Spec-aware like FLASK, ranked by the stat-priority model, primary stat first.
   - SCROLL: subclass 4. Ranked like ELIXIR. A scroll with no stat (Protection, armor) ranks after stat scrolls,
     by its value.
   - BANDAGE: subclass 7. Ranked by heal amount (the tooltip's flat or over-time heal).
   - PROT_POT: subclass 1 or 13, with an absorb effect against one magic school ("Absorbs X to Y fire
     damage"). Ranked by absorb amount. CMBT_POT excludes these.
4. **Discovery on Forever's subclasses.** A Draught (13) is matched like a Potion (1) by the potion matchers
   (HP_POT, MP_POT, CMBT_POT, PROT_POT). A temporary item enhancement (15), or an item enhancement (6), is a
   weapon enchant even when its tooltip lacks Retail's "your … weapon" wording (vanilla's "Increase sharp weapon
   damage by 2 for 30 minutes"). The weapon affinity reads "sharp" or "bladed" as bladed and "blunt" as blunt;
   otherwise either hand. Devices (14) join nothing.
5. **Tooltip parsing** gains what the new categories need, in English like the rest of the parser: an absorb
   amount and school for PROT_POT, bandage heals over time, and vanilla stat wording ("Increases Agility by 25
   for 1 hr."), each with a test. Retail parsing is unchanged, and Retail's pinned tests stay green.
6. **The port shape**, wave 1's: the TOC's `## Interface: 120105, 16001`, LibKa0s v1.94.0 re-vendored, the default
   skin per client (`NS.DEFAULT_SKIN` style, skinning-§2), README, DEPENDENCIES, the per-client feature table in
   `docs/ARCHITECTURE.md` (the category table above, with each gate's file), both kit profiles in the gate,
   a WoW Forever smoke section, a regenerated inventory. The roster row flips in WowAddonStandards in the same
   change (clients-§2).

## Tests

Every category gate on both kit profiles: Forever's list is exactly its 15 keys, Retail's its 15, and an absent
key has no macro, schema row, settings page or slot. Forever's seeds are empty. The new matchers and rankers have
characterization tests on Forever-shaped items (subclass 2, 4, 7, 13 and 15 with vanilla tooltip text). Retail
behavior is pinned unchanged.

## Not in step 1

Seed lists for Forever (items, healthstone ranks, stat priorities keyed by Forever's spec IDs), feast or juju
categories, and any composite change. A Healthstone on Forever is found by its existing ID list (5512, Minor
Healthstone, is vanilla's), so the other vanilla ranks wait for step 2.
