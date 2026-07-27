# Ka0s Consumable Master

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1522944)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-399%2F399_passing-green)

![Logo](https://media.forgecdn.net/attachments/1646/103/consumemaster-logo-jpg.jpg)

An auto-managed consumable-macro addon for **World of Warcraft: Midnight**. It keeps a fixed set of account-wide macros always pointed at the best consumable in your bags — across eleven categories, plus two combo macros that switch depending on whether you're in combat. Set up your food, flask, and potion macros once and never rebuild them again.

Whenever you loot something better, change spec, reload, or drop out of combat, Consumable Master updates each macro to use your best current pick — the right item, or the right spell for class abilities like Recuperate. The macros are account-wide, so one set is shared by all your characters. They're matched by name rather than by slot, so you can move them around your macro list freely and they'll keep working alongside your own macros.

> **English game clients only, for now.** To read how much a consumable heals or which stats it grants, the addon parses item tooltips in **English text**, so it isn't fully supported on non-English clients yet. (Item and weapon *type* detection already works on any client.) Full localization is planned for a later release.

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
| 12 |All-in-one health (combat: HS → HP pot, out of combat: food) |<code>KCM_HP_AIO</code> |No          |
| 13 |All-in-one mana (combat: MP pot, out of combat: drink)       |<code>KCM_MP_AIO</code> |No          |

If a better pick comes up while you're in combat, the macro updates the moment you leave — WoW doesn't allow macro changes mid-fight.

## What's new in 1.5.0

- **Weapon enchant macro (`KCM_WPN_ENCH`).** Keeps the best oil or sharpening stone on each weapon hand, matched to your weapon type and your spec.
- **Augment rune macro (`KCM_AUG_RUNE`).** Points at your best primary-stat augment rune, preferring reusable ones so you don't burn charges.
- **Vantus rune macro (`KCM_VANTUS`).** Keeps a macro on your raid Versatility rune.
- **New on-screen debug console.** A movable window with Copy and Clear, opened by `/cm debug` or the General → Debug console toggle (`/cm debug on/off`); the log now clears on each login.
- **Updated for World of Warcraft: Midnight (12.0.7).**

## Screenshots

**_Settings Panel_**

![Settings Panel](https://media.forgecdn.net/attachments/1806/219/kcm-01-general-png.png)

**_Stat Priority Selector (Per Spec)_**

![Stat Priority Selector (Per Spec)](https://media.forgecdn.net/attachments/1806/220/kcm-02-statpriority-png.png)

**_Food Category Priority Selector (Not Spec Aware)_**

![Food Category Priority Selector (Not Spec Aware)](https://media.forgecdn.net/attachments/1806/221/kcm-03-food-png.png)

**_All-in-One Health Category Priority Selector_**

![All-in-One Health Category Priority Selector](https://media.forgecdn.net/attachments/1806/222/kcm-04-aio-health-png.png)

**_Flask Category Priority Selector (Spec Aware)_**

![Flask Category Priority Selector (Spec Aware)](https://media.forgecdn.net/attachments/1806/223/kcm-05-flask-png.png)

**_Weapon Enchant Priority Selector (Spec and Weapon Type Aware)_**

![Weapon Enchant Priority Selector (Spec and Weapon Type Aware)](https://media.forgecdn.net/attachments/1806/226/kcm-06-weapon-enchant-png.png)

**_Ranking Explainer_**

![Ranking Explainer](https://media.forgecdn.net/attachments/1806/224/kcm-06-ranking-png.png)

## Usage

Install it with your addon manager (or drop the folder into `Interface/AddOns`) and log in. On login, Consumable Master scans your bags, finds your consumables, and writes all its macros. Drag any macro onto your action bars from the macro window, or from the draggable icon at the top of each category page in the settings.

### Slash commands

`/cm` is the short command; `/consumablemaster` does the same thing. Everything the addon prints to chat is tagged with a cyan `[CM]` so it's easy to spot.

| Command | What it does |
|---------|--------------|
| `/cm` | Show the list of commands. |
| `/cm config` | Open the settings panel. |
| `/cm resync` | Rescan your bags and update any macro whose best pick changed. |
| `/cm rewritemacros` | Rewrite every macro and its icon. Use this if an action-bar icon looks stale. |
| `/cm reset` | Reset every priority list and stat choice back to defaults (asks first). |
| `/cm debug` | Open or close the debug window; add `on` or `off` to turn logging on or off. |
| `/cm version` | Show the addon version. |
| `/cm list` | List every setting and its current value. |
| `/cm get <path>` | Show one setting's value (e.g. `/cm get enabled`). |
| `/cm set <path> <value>` | Change a setting from chat. |
| `/cm priority <cat> list\|add\|remove\|up\|down\|reset [<id>]` | Edit a category's priority list from chat. `<id>` is an item ID like `12345` or a spell like `s:5512`. |
| `/cm stat list\|primary\|secondary\|reset [<specKey>]` | Edit a spec's stat priority from chat. Defaults to your current spec. |
| `/cm aio <key> list\|toggle\|up\|down\|reset` | Edit the combo macros (`HP_AIO` / `MP_AIO`). |
| `/cm dump <target>` | Show internal details for troubleshooting (`categories`, `bags`, `item <id>`, `pick <catKey>`, …). |

### Settings panel

Settings live at **Escape → Options → AddOns → Consumable Master** (or type `/cm config`).

**General**

*General*

*   **Enable** — the master on/off switch. When it's off, your macros stop updating and keep whatever they last had. Turn it back on and they refresh right away. Remembered between sessions.
*   **Debug console** — show or hide the on-screen debug window (same as a bare `/cm debug`). This does *not* turn logging on or off — use the window's **Debug: ON/OFF** toggle or `/cm debug on/off` for that. The window is hidden again each login.

*Maintenance*

*   **Force resync** — rescan your bags and recheck every category's best pick. Macros only change if the pick actually changed. Same as `/cm resync`. Not available in combat.
*   **Force rewrite macros** — rewrite every macro and its icon, even ones that didn't change. Use this when an action-bar icon looks stale (some bar addons hold the old icon across an upgrade). Same as `/cm rewritemacros`. Not available in combat. A `/reload` afterwards makes sure your bars redraw.
*   **Reset all priorities** — wipe every added, blocked, and pinned item and every stat choice, restoring the defaults. Asks first.

**Stat Priority**

One page that controls the four spec-aware categories (Stat Food, Combat Potion, Flask, Weapon Enchant).

*   **Viewing spec** — pick which spec you're editing. This also sets which spec is shown on the four spec-aware category pages. Specs show their class icon and name (e.g. "Shaman — Enhancement").
*   **Primary stat** — your spec's main stat. Consumables with your primary stat always beat secondary-stat ones.
*   **Secondary stat #1 … #4** — your preferred secondary stats in order (Crit, Haste, Mastery, Versatility). #1 counts the most. Leave a slot as `(none)` to stop there; anything not listed counts as zero.
*   **Reset stat priority** — drop your changes for the viewed spec and go back to its default.

**Per-category pages**

Each of the eleven single macros has its own page. Spec-aware pages show the viewed spec at the top.

*   **Draggable macro icon** — the small icon under the title. Drag it onto a bar to place the macro.
*   **Add item or spell by ID** — choose **Item** or **Spell**, paste the ID, press Enter. A bad ID gives a chat error and keeps your text so you can fix the typo.
*   **Priority list** — one row per candidate, in ranked order:
    *   Icons show status: green check (you own it / know the spell), red (you don't), yellow star (currently used by the macro).
    *   **Blue info button** — hover to see why an item scored where it did.
    *   **↑ / ↓** — reorder. Moving an item pins it above the automatic ranking.
    *   **×** — remove and block it, so it won't get auto-added again.
*   **Reset category** — clear this category's added, blocked, and pinned items (for spec-aware pages, just the viewed spec). Auto-found items stay.

**AIO Health / AIO Mana**

Two combo pages (right after Healthstone). `KCM_HP_AIO` uses your Healthstone then Healing Potion in combat, and your Food pick out of combat. `KCM_MP_AIO` uses your Mana Potion in combat and your Drink out of combat. Each page has an *In Combat* and an *Out of Combat* section; you can turn each sub-category on or off and reorder it within its section. Each row shows the current pick on the left and its controls on the right. The actual ranking is set on each category's own page.

## How picking & ranking works

Each macro is built in four steps:

1.  **Gather the candidates** — everything in the built-in default list, anything you added by hand, and anything found in your bags, minus anything you blocked with **×**.
2.  **Score each candidate** — higher is better:
    *   **Food / Drink** — how much it heals or restores, with a bonus for conjured items and percentage-based ones (so Midnight's %-based food beats older flat food).
    *   **HP / MP potions** — how much they restore. An instant potion beats a heal-over-time one unless the heal-over-time total is more than 20% bigger, so a slightly larger slow heal won't win in an emergency.
    *   **Stat Food / Combat Potion / Flask** — how well it matches your spec's stat priority. Primary stat always beats secondary; among secondary stats, earlier choices count more.
    *   **Weapon Enchant** — checks each equipped weapon separately. Attack Power oils/stones score highest for Strength/Agility specs and Spell Power ones score highest for Intellect specs, since that's each spec's real throughput stat; other oils still rank by your stat priority. Each enhancement is also tagged bladed (whetstone), blunt (weightstone), or any (oil) from its tooltip, and only ones that match your main-hand or off-hand weapon's type are considered for that hand. The macro applies the best matching enhancement to each hand independently — dual-wielding a sword and a mace can end up with a whetstone on one hand and a weightstone on the other — and drops a hand entirely if it's empty or has nothing valid to apply. Swapping weapons updates the macro right away, no reload needed.
    *   **Augment Rune** — picks the augment rune granting the most primary stat. "Permanent" runes like Ethereal and Dreambound aren't a longer buff — they're just not used up — so they only win when they tie the best consumable on stat, never when a newer consumable rune grants more. Auto-discovers new runes from their tooltip, so future runes work without an update.
    *   **Healthstone** — a small preference for modern auto-leveling stones over old ones.
    *   **Spell entries** — class abilities (like Recuperate as a Food entry) score above every item, so they sit at the top by default. You can pin items above them if you prefer.
3.  **Apply your pins** — any rows you reordered with ↑ / ↓ override the score.
4.  **Pick the first one you have** — the first item you own or spell you know. If you have none, clicking the macro prints a friendly `[CM] no <category>` note.

Hover the **blue info button** on any row to see exactly why it landed where it did.

## FAQ

| Question | Answer |
|----------|--------|
| Will this delete or overwrite my existing macros? | No. Its macros are matched by **name**, never by slot, and it only ever touches its own. Your macros are never read, moved, or deleted. If you delete one of its macros by hand, it's recreated on the next update. |
| Do the macros work across all my characters? | Yes. They're **account-wide**, so one set is shared by every character. Your priority lists and stat choices are shared account-wide too. |
| Why are some categories per-spec and others aren't? | Flask, Combat Potion, Stat Food, and Weapon Enchant depend on your stat priority, which changes with your spec, so they're spec-aware (Weapon Enchant is weapon-type-aware on top of that). Food, Drink, HP Potion, MP Potion, Healthstone, Augment Rune, and Vantus rank the same for every spec, so they share one list. |
| How does it pick weapon enchants when I'm dual-wielding? | It checks each hand on its own. A whetstone only goes on a bladed weapon, a weightstone only on a blunt one, and oils fit either — so a sword-and-mace pair can end up with a different enhancement on each hand. A hand with nothing valid equipped is simply left out of the macro. Swapping weapons updates it right away, no reload needed. |
| Why isn't it using my reusable (permanent) augment rune? | By design. A reusable rune like Ethereal or Dreambound isn't a longer buff — it just isn't consumed — so it only wins when it ties the best rune on primary stat. If a single-use rune grants more stat, that one is picked. Pin the reusable rune with **↑** if you'd rather never spend charges. |
| How do I add an item or spell the addon doesn't know about? | Open the category's page and use **Add item or spell by ID** at the top. Choose **Item** or **Spell**, paste the ID, press Enter. |
| How do I force a specific item to always win? | Use **↑ / ↓** on its row to move it where you want. A moved (pinned) item overrides the automatic ranking. |
| How do I permanently remove an item? | Use **×** on its row. That blocks it so it won't get auto-added again. **Reset category** or **Reset all priorities** clears the block. |
| Does it work with ElvUI / Bartender / other bar addons? | Yes — the macros are plain WoW macros. If a picked item's icon doesn't show on the bar, see Troubleshooting; a one-time **Force rewrite macros** + `/reload` occasionally sorts it out after an upgrade. |
| Can I use this in a non-English client? | Not fully yet — **English only for now**. Item and weapon *type* detection works on any client, but it still reads tooltip **text** in English to get heal/mana/stat amounts, so other languages aren't fully supported. Full localization is planned for a later release. |
| Will new patch flasks / potions work automatically? | Usually yes. It scans your bags and recognizes anything that matches by type and tooltip, so a freshly-looted new flask joins the list on the next bag update. If a patch renames something, please file an issue. |
| Why does a smaller instant HP potion beat a bigger heal-over-time one? | By design — an instant restore is usually what you want in an emergency. It only loses if the heal-over-time total is more than 20% bigger. You can override this by pinning the heal-over-time potion above the instant one. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Action bar shows a cooking-pot icon instead of the picked item's icon. | Run **Settings → General → Force rewrite macros** (or `/cm rewritemacros`), then `/reload`. Some bar addons hold the old icon until the button redraws. |
| The macro shows the cooking pot but I _do_ own the item. | Run `/cm dump pick <catKey>` (e.g. `/cm dump pick FLASK`) to list every candidate with its score and owned status. If your item isn't there, it's blocked or its tooltip hasn't loaded yet. |
| I just looted a better food / flask but the macro didn't update. | Give it a second — bag updates are batched. If nothing changes, run `/cm resync`. If it happened in combat, the macro updates when you leave combat. |
| My macro changed but my action bar didn't. | `/reload`. Some bar addons cache icons and don't redraw on every macro change. |
| Swapped specs but the flask / combat-potion / stat-food / weapon-enchant macro didn't update. | Run `/cm resync`, and check the viewed spec on the **Stat Priority** page matches your current spec. |
| Only one weapon got an enchant, or a hand was left bare. | That hand either has nothing equipped or nothing that matches its weapon type — whetstones need a bladed weapon, weightstones a blunt one, oils fit either. Run `/cm dump pick WPN_ENCH` to see what was considered for each hand. |
| I opened the debug console but nothing shows up in it. | The window and logging are two separate switches. A bare `/cm debug` only shows or hides the window — run `/cm debug on` (or click the window's **Debug: ON/OFF** toggle) to actually capture output. The log also clears on every login. |
| `/cm dump item <id>` shows a type the addon doesn't recognize. | A patch probably renamed that item type. Please file an issue with the type shown in the dump. |
| Chat says "macro body exceeds 255 bytes" once on login. | WoW limits macros to 255 characters. Rather than write a broken macro, the addon leaves that category on its empty note. Please report it with the category name. |
| Chat says it "gave up on a macro after 3 failed writes". | Something is repeatedly blocking the macro write — usually another addon interfering. Run `/cm debug`, reproduce it, and file an issue with the log. |
| `/cm reset` or "Reset all priorities" says it didn't work. | The addon's saved data hasn't finished loading — reload and try again. |
| I want to restore a default list after removing items by hand. | **Reset category** on the page clears that one category; **Reset all priorities** (General) clears everything. |

## Issues and feature requests

Bugs, feature requests, and planned work are all tracked on GitHub: [github.com/tusharsaxena/consumablemaster/issues](https://github.com/tusharsaxena/consumablemaster/issues). Please file reports there rather than in comments — the issue tracker is where the project's to-do list lives.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.5.0 | 2026-07-13 | Three new macros: weapon enchant (`KCM_WPN_ENCH`, best oil/stone per hand, weapon- and spec-aware), augment rune (`KCM_AUG_RUNE`, best primary-stat rune, reusable-aware), and Vantus rune (`KCM_VANTUS`). New on-screen debug console — a movable window with Copy and Clear, opened by `/cm debug` or the General → Debug console toggle (`/cm debug on/off`); logging now resets each login. Updated for World of Warcraft: Midnight (12.0.7). |
| 1.4.0 | 2026-05-03 | Redesigned settings panel with Blizzard sub-categories and an About page; slash commands moved to `/cm` with a cyan `[CM]` chat tag; new `/cm list`, `/cm get`, and `/cm set` commands; master enable toggle; Stat Priority now follows your active spec automatically. |
| 1.3.0 | 2026-04-25 | New combo macros `KCM_HP_AIO` and `KCM_MP_AIO` that switch picks based on whether you're in combat, with AIO Health and AIO Mana settings pages to toggle and reorder each side. |
| 1.2.1 | 2026-04-25 | Fixed a Lua error on login. |
| 1.2.0 | 2026-04-24 | Action-bar icons now show correctly on ElvUI, Bartender, and other bar addons; new `/cm rewritemacros` command (and Settings → General → Force rewrite macros); category drag icons now show the picked item's texture. |
| 1.1.0 | 2026-04-24 | Stability fixes: pinned items no longer cause macros to flip back and forth, over-long macros fall back cleanly instead of breaking, and spell names appear without a reload. Category tabs can be reordered, and empty categories show a fallback icon. |
| 1.0.0 | 2026-04-24 | Initial release: auto-updating account-wide macros across eight categories, spell entries in priority lists, an item/spell picker, and a per-row score tooltip that explains each ranking. |
