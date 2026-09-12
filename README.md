# Ka0s Consumable Master

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1522944)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-835%2F835_passing-green)

Ka0s Consumable Master is an auto-managed consumable-macro addon which keeps a fixed set of account-wide macros pointed at the best consumable in your bags: thirteen categories, plus two combo macros that switch on whether you are fighting. Set your food, flask and potion macros up once. Then stop rebuilding them.

Loot something better, change spec, reload, or drop out of combat, and each macro re-points at your current best pick — the right item, or the right spell where a class ability does the job (Recuperate, for one). The macros are account-wide, so one set covers every character you have. They are matched by name rather than by slot, which means you can shuffle them around your macro list and they will keep working next to macros of your own.

> **English game clients only, for now.** Reading how much a consumable heals, or which stats it grants, means parsing the item's tooltip in **English text**, so other clients aren't fully supported yet. (Item and weapon *type* detection already works anywhere.) Full localization is planned for a later release.

| #  |Category                                                     |Macro         |Spec-aware? |
| -- |------------------------------------------------------------ |------------- |----------- |
| 1  |Basic / conjured food                                        |<code>KCM_FOOD</code> |No          |
| 2  |Drink (mana regen)                                           |<code>KCM_DRINK</code> |No          |
| 3  |Healing potion                                               |<code>KCM_HP_POT</code> |No          |
| 4  |Mana potion                                                  |<code>KCM_MP_POT</code> |No          |
| 5  |Warlock healthstone                                          |<code>KCM_HS</code> |No          |
| 6  |Vantus rune (raid Versatility)                               |<code>KCM_VANTUS</code> |No          |
| 7  |Flask                                                        |<code>KCM_FLASK</code> |<strong>Yes</strong> |
| 8  |Combat potion (throughput)                                   |<code>KCM_CMBT_POT</code> |<strong>Yes</strong> |
| 9  |Stat food                                                    |<code>KCM_STAT_FOOD</code> |<strong>Yes</strong> |
| 10 |Weapon enchant (oil / stone, per hand, weapon-type aware)    |<code>KCM_WPN_ENCH</code> |<strong>Yes</strong> |
| 11 |Augment rune (primary stat, reusable-aware)                  |<code>KCM_AUG_RUNE</code> |No          |
| 12 |Bloodlust / Heroism / Time Warp (raid haste, incl. drums)     |<code>KCM_BLOODLUST</code> |No          |
| 13 |Battle resurrection                                          |<code>KCM_BATTLE_REZ</code> |No          |
| 14 |All-in-one health (combat: HS → HP pot, out of combat: food) |<code>KCM_HP_AIO</code> |No          |
| 15 |All-in-one mana (combat: MP pot, out of combat: drink)       |<code>KCM_MP_AIO</code> |No          |

If a better pick turns up while you are in combat, the macro updates the moment you leave. WoW does not allow macro changes mid-fight.

## What's new in 1.6.2

- Fixed the AIO Health and AIO Mana tooltips on the macro bar showing the macro's text instead of the item or spell it will use

## Screenshots

**_Stat Priority Selector (Per Spec)_**

![Stat Priority Selector (Per Spec)](https://media.forgecdn.net/attachments/1936/512/kcm-02-statpriority-png.png)

**_Food category macro selector_**

![Food category macro selector](https://media.forgecdn.net/attachments/1936/513/kcm-03-food-png.png)

**_All-in-One health category macro selector_**

![All-in-One health category macro selector](https://media.forgecdn.net/attachments/1936/514/kcm-04-aio-health-png.png)

**_Ranking explainer_**

![Ranking explainer](https://media.forgecdn.net/attachments/1936/515/kcm-05-ranking-png.png)

**_Macro bar_**

![Macro bar](https://media.forgecdn.net/attachments/1936/516/kcm-06-macro-bar-png.png)


## Usage

Install it with your addon manager, or drop the folder into `Interface/AddOns`, and log in. The macros are written for you on the way in: Consumable Master reads your bags, scores what it finds, and fills all fifteen. Drag them onto your action bars from the macro window, or from the small draggable icon under the title on any category tab in the settings, which is nearer to hand while you're already in there.

You don't have to give up bar space for any of this. Consumable Master ships a bar of its own that holds its macros and nothing else, and it arrives unlocked so you can put it where you want before locking it down with `/cm bar lock`. Every button on that bar wears a shaded strip along one edge with a small arrow on it. Hover the strip and a flyout opens listing what you can use in that category right now, best-ranked nearest the button, so the second-best flask is a hover away rather than a bag dive. Long categories are trimmed to whatever you set Maximum flyout entries to. If none of that appeals, `/cm bar off`.

You can overrule the ranking anywhere it gets something wrong. Each category has a tab on the Macros page showing its candidates in order: a green check on the ones you own, a yellow star on the one the macro is currently using. Grab a row by its drag handle and drop it higher to pin it above the score, or press × to block it so a later bag scan won't put it back. Every row carries a blue info button that explains why the item landed where it did, and the first time a ranking surprises you that button is the fastest way to find out you had pinned something two patches ago. Anything the addon has never heard of goes in through the add-by-ID box at the top of the tab: pick Item or Spell, then type the ID or shift-click the thing straight into the box.

Four categories move with your spec. Flask, Combat Potion, Stat Food and Weapon Enchant all read the stat order you set on the Stat Priority page, where Crit, Haste, Mastery and Versatility are one list you drag into the order you want; click a stat's green tick and it drops to the bottom block and counts as nothing at all. The spec you're editing is pinned in that page's banner, and it governs the four spec-aware tabs as well, which is worth remembering when a flask macro looks wrong right after a spec swap. Day to day, though, the macros keep themselves current. `/cm resync` rechecks the picks if you're impatient, and `/cm rewritemacros` redraws every icon for the bar addons that hang on to a stale one.

Everything else is configuration, and it lives in two places: the addon's own page under Settings → AddOns in game, and `/cm` (or `/consumablemaster`), which prints the full command list.

## How picking & ranking works

Each macro is built in four steps:

1.  **Gather the candidates** — everything in the built-in default list, anything you added by hand, and anything found in your bags, minus anything you blocked with **×**.
2.  **Score each candidate** — higher is better:
    *   **Food / Drink** — how much it heals or restores, with a bonus for conjured items and percentage-based ones, so Midnight's %-based food beats older flat food.
    *   **HP / MP potions** — how much they restore. An instant potion beats a heal-over-time one unless the heal-over-time total is more than 20% bigger, so a slightly larger slow heal will not win an emergency.
    *   **Stat Food / Combat Potion / Flask** — how well it matches your spec's stat priority. Primary stat always beats secondary; among secondary stats, earlier choices count more.
    *   **Weapon Enchant** — each equipped weapon is checked on its own. Attack Power oils and stones score highest for Strength and Agility specs, Spell Power ones for Intellect specs, since that is each spec's real throughput stat; other oils rank by your stat priority. Every enhancement is also tagged from its tooltip as bladed (whetstone), blunt (weightstone) or any (oil), and only the ones matching that hand's weapon are considered for it. So dual-wielding a sword and a mace can end up with a whetstone on one hand and a weightstone on the other. A hand that is empty, or has nothing valid to apply, is dropped from the macro. Swap weapons and the macro follows immediately, no reload.
    *   **Augment Rune** — the rune granting the most primary stat wins. "Permanent" runes like Ethereal and Dreambound are not a longer buff, only an unconsumed one, so they win ties and nothing else. New runes are discovered from their tooltip, which means a future one works without an addon update.
    *   **Healthstone** — a small preference for modern auto-leveling stones over old ones.
    *   **Spell entries** — class abilities (Recuperate as a Food entry, say) score above every item, so they sit at the top by default. Pin items above them if you prefer.
3.  **Apply your pins** — any rows you dragged into place override the score.
4.  **Pick the first one you have** — the first item you own or spell you know. If you have none of them, clicking the macro prints a friendly `[CM] no category` note.

Hover the **blue info button** on any row to see exactly why it landed where it did.

## FAQ

| Question | Answer |
|----------|--------|
| Will this delete or overwrite my existing macros? | No. Its macros are matched by **name**, never by slot, and it only ever touches its own. Yours are never read, moved, or deleted. Delete one of its macros by hand and it comes back on the next update. |
| Do the macros work across all my characters? | Yes. They are **account-wide**, so one set is shared by every character, and your priority lists and stat choices are shared too. |
| Why are some categories per-spec and others aren't? | Flask, Combat Potion, Stat Food and Weapon Enchant depend on your stat priority, which changes with your spec (and Weapon Enchant is weapon-type-aware on top of that). Food, Drink, HP Potion, MP Potion, Healthstone, Augment Rune, Vantus, Bloodlust and Battle Rez rank the same for every spec, so they share one list. |
| How does it pick weapon enchants when I'm dual-wielding? | Each hand on its own. A whetstone only goes on a bladed weapon, a weightstone only on a blunt one, and oils fit any weapon at all — including a bow, gun or wand, which take no stone. So a sword-and-mace pair can end up with a different enhancement on each hand. A hand with nothing equipped is left out of the macro. Swapping weapons updates it right away, no reload needed. |
| Why isn't it using my reusable (permanent) augment rune? | By design. A reusable rune like Ethereal or Dreambound is not a longer buff, it just is not consumed, so it only wins when it ties the best rune on primary stat. A single-use rune granting more stat is picked instead. Drag the reusable one to the top of its list if you would rather never spend charges. |
| How do I add an item or spell the addon doesn't know about? | Open the category's page and use **Add item or spell by ID** at the top. Choose **Item** or **Spell**, then either type the ID or shift-click the item (or spell) into the box, and press Enter. |
| How do I force a specific item to always win? | Grab its row by the **drag handle** and drop it where you want it. A pinned item overrides the automatic ranking. |
| How do I permanently remove an item? | Use **×** on its row. That blocks it, so it will not get auto-added again. **Reset category** or **Reset all priorities** clears the block. |
| Does it work with ElvUI / Bartender / other bar addons? | Yes. The macros are plain WoW macros. If a picked item's icon doesn't show on the bar, see Troubleshooting; a one-time **Force rewrite macros** plus `/reload` usually sorts it out after an upgrade. |
| Can I use this in a non-English client? | Not fully yet. Item and weapon *type* detection works on any client, but heal, mana and stat amounts are read out of the tooltip **text** in English. Full localization is planned for a later release. |
| Will new patch flasks / potions work automatically? | Usually. It scans your bags and recognizes anything matching by type and tooltip, so a freshly-looted new flask joins the list on the next bag update. If a patch renames something, please file an issue. |
| Why does a smaller instant HP potion beat a bigger heal-over-time one? | Because an instant restore is usually what you want when you're about to die. The heal-over-time potion only wins if its total is more than 20% bigger. Pin the heal-over-time potion above the instant one to override that. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Action bar shows a cooking-pot icon instead of the picked item's icon. | Run **Settings → General → Force rewrite macros** (or `/cm rewritemacros`), then `/reload`. Some bar addons hold the old icon until the button redraws. |
| The macro shows the cooking pot but I _do_ own the item. | Run `/cm dump pick catKey` (e.g. `/cm dump pick FLASK`) to list every candidate with its score and owned status. If your item isn't there, it is blocked or its tooltip hasn't loaded yet. |
| I just looted a better food / flask but the macro didn't update. | Give it a second, bag updates are batched. If nothing changes, run `/cm resync`. If it happened in combat, the macro updates when you leave combat. |
| My macro changed but my action bar didn't. | `/reload`. Some bar addons cache icons and don't redraw on every macro change. |
| Swapped specs but the flask / combat-potion / stat-food / weapon-enchant macro didn't update. | Run `/cm resync`, and check that the viewed spec on the **Stat Priority** page matches the spec you are actually playing. |
| Only one weapon got an enchant, or a hand was left bare. | That hand either has nothing equipped, or you own nothing that fits it: whetstones need a bladed weapon, weightstones a blunt one, and oils fit anything. The Weapon Enchant tab names each hand's weapon type above the list, so a hand reading **no stone (oils only)** wants an oil. |
| I opened the debug console but nothing shows up in it. | The window and the logging are two separate switches, which is the one people trip over. A bare `/cm debug` only shows or hides the window; `/cm debug on` (or the window's **Debug: ON/OFF** toggle) is what captures output. The log also clears on every login. |
| `/cm dump item id` shows a type the addon doesn't recognize. | A patch probably renamed that item type. Please file an issue with the type shown in the dump. |
| Chat says "macro body exceeds 255 bytes" once on login. | WoW limits macros to 255 characters. Rather than write a broken macro, the addon leaves that category on its empty note. Please report it with the category name. |
| Chat says it "gave up on a macro after 3 failed writes". | Something is repeatedly blocking the macro write, usually another addon interfering. Run `/cm debug`, reproduce it, and file an issue with the log. |
| `/cm resetall` or "Reset all settings" says it didn't work. | The addon's saved data hasn't finished loading. Reload and try again. |
| I want to restore a default list after removing items by hand. | **Reset category** clears that one category. **Reset all priorities** clears every category and every stat choice. **Reset all settings** puts the whole profile back the way it shipped. |

## Issues and feature requests

Bugs, feature requests and planned work all live on GitHub: [github.com/tusharsaxena/consumablemaster/issues](https://github.com/tusharsaxena/consumablemaster/issues). Please file there rather than in comments. The tracker is the project's to-do list, and a comment is not.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.6.2 | 2026-09-11 | Fixed the AIO Health and AIO Mana tooltips on the macro bar showing the macro's text instead of the item or spell it will use |
| 1.6.1 | 2026-09-11 | Fixed the macro bar and its flyouts doing nothing when clicked while WoW's "cast on key down" setting is on (the game's default) |
| 1.6.0 | 2026-09-10 | **Maintenance** has its own tab on the General page again<br>Fixed a refresh burst arming about a hundred and fifty timers to perform one rebuild<br>Category registration is now refused in combat and replayed when combat ends, instead of tainting<br>Fixed the info glyph lighting up a whole panel; it now matches Loot History's<br>Updated for game patch 12.1.0 |
| 1.5.0 | 2026-07-13 | Three new macros: weapon enchant (`KCM_WPN_ENCH`, best oil/stone per hand, weapon- and spec-aware), augment rune (`KCM_AUG_RUNE`, best primary-stat rune, reusable-aware), and Vantus rune (`KCM_VANTUS`). New on-screen debug console — a movable window with Copy and Clear, opened by `/cm debug` or the General → Debug console toggle (`/cm debug on/off`); logging now resets each login. Updated for World of Warcraft: Midnight (12.0.7). |
| 1.4.0 | 2026-05-03 | Redesigned settings panel with Blizzard sub-categories and an About page; slash commands moved to `/cm` with a cyan `[CM]` chat tag; new `/cm list`, `/cm get`, and `/cm set` commands; master enable toggle; Stat Priority now follows your active spec automatically. |
| 1.3.0 | 2026-04-25 | New combo macros `KCM_HP_AIO` and `KCM_MP_AIO` that switch picks based on whether you're in combat, with AIO Health and AIO Mana settings pages to toggle and reorder each side. |
| 1.2.1 | 2026-04-25 | Fixed a Lua error on login. |
| 1.2.0 | 2026-04-24 | Action-bar icons now show correctly on ElvUI, Bartender, and other bar addons; new `/cm rewritemacros` command (and Settings → General → Force rewrite macros); category drag icons now show the picked item's texture. |
| 1.1.0 | 2026-04-24 | Stability fixes: pinned items no longer cause macros to flip back and forth, over-long macros fall back cleanly instead of breaking, and spell names appear without a reload. Category tabs can be reordered, and empty categories show a fallback icon. |
| 1.0.0 | 2026-04-24 | Initial release: auto-updating account-wide macros across eight categories, spell entries in priority lists, an item/spell picker, and a per-row score tooltip that explains each ranking. |
