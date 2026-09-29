# Smoke tests — Ka0s Consumable Master

These are the in-client checks the headless suite cannot make: event-driven behavior against the real Blizzard APIs, frame and UI rendering, taint, secure frames and action-bar icons. The headless half is `lua5.1 tests/run.lua` plus `luacheck .` ([testing.md](./testing.md#the-green-gate); case inventory in [test-cases.md](./test-cases.md)). Start each check from a clean `/reload` unless it says otherwise, and turn on `/cm debug on` where a step asks for it (logging is off after every reload). After a small change, run MACRO-1 plus the themes the [Index](#index) names for the code you touched; before a release, walk every theme. Record each check on its `Result:` line: pass, fail with what you saw, or skipped and why. IDs are `<THEME>-<n>` and stable: a new check takes the next free number in its theme, and a retired number is not reused.

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1 – INSTALL-6 | Install | Fresh install, re-login, the v2 and v3 SavedVariables upgrades, the TOC version and notes. Run for `core/Database.lua` migrations, TOC edits and `core/EnvSetup.lua`. |
| SLASH-1 – SLASH-14 | Slash commands | Every `/cm` verb, the schema CLI, `[Set]` logging, the disabled refusal and what still answers while disabled. Run for `settings/Slash.lua`, `core/SlashCommands.lua`, `core/SlashDump.lua`, schema rows and a new verb. |
| PANEL-1 – PANEL-31 | Settings panel | Landing page, sidebar, header, the General page and its resets, Defaults buttons, refresh behavior, the Macros tab strip. Run for `settings/Panel.lua`, `settings/General.lua`, `settings/OptionsSetup.lua`, `settings/OptionsShim.lua`, `reset` / `resetall` and the confirm popup. |
| PROFILE-1 – PROFILE-21 | Profiles | The Profiles page (new, switch, copy, reset, delete), per-profile migration, what stays out of a profile, and the `/cm profile` verb. Run for `settings/Profiles.lua`, the profile hooks in `core/ConsumableMaster.lua`, `PROFILE_CHANGED` receivers, `KCM.Settings.VetoedFromResetAll`, the vendored AceConfig / AceDBOptions; for the `/cm profile` verb (PROFILE-15 – PROFILE-21), its `profile` row in `settings/Slash.lua`'s `COMMANDS`, its `LIVE_VERBS` entry, the descriptor's `profiles` thunk and a LibKa0s `Slash.lua` re-vendor (`CliProfile`, `ProfileSwitch`). |
| STATE-1 – STATE-9 | State | Master enable and the stand-down, the lock and its four doors. Run for `core/LifecycleSetup.lua`, the enable row and `KCM.MacroBar.SetLocked`. |
| MACRO-1 – MACRO-23 | Macros | What each category's macro body picks and writes: single-pick, Weapon Enchant, Augment Rune, Bloodlust and Battle Rez, the AIO composites, spec changes, edge cases. Run for the Ranker, Selector, `core/WeaponSlots.lua`, MacroManager body builders, `TooltipCache.IsUsableByPlayer`, seed files. |
| DISC-1 – DISC-8 | Discovery | Auto-discovery, the stale sweep, numeric item-class classification, tooltip hydration. Run for the Classifier, BagScanner, TooltipCache patterns, `defaults/` seed refreshes. |
| PRIO-1 – PRIO-30 | Priority editors | The Macros page category tabs (Add by ID or name, suggestions, drag reorder, composite sections) and the Stat Priority page. Run for `settings/Category.lua`, `settings/CategoryAddByID.lua`, `settings/StatPriority.lua`, Selector mutators, `LibKa0s-Widgets-1.0`'s `ReorderList`. |
| BAR-1 – BAR-30 | Macro bar | The bar and its settings page: layout, appearance, labels, the Buttons tab, flyout, fade, slash parity, page Defaults, media dropdowns, the stored color codec. Run for `modules/MacroBar*.lua`, `core/MacroBar*.lua`, `core/MacroDisplay.lua`, `settings/MacroBar.lua`, a new `macroBar.*` row or `shortName`, `lib.__PatchLSM30Border()`, `KCM.ColorDecode`. |
| LAUNCH-1 – LAUNCH-9 | Launcher | The minimap button and broker plugin: clicks, menu, position, visibility, tooltip. Run for `core/LauncherSetup.lua`. |
| COMBAT-1 – COMBAT-17 | Combat | Macro-write deferral, the settings category's combat park, secure bar and flyout under lockdown, restricted cooldowns, the mid-key restriction lift. Run for MacroManager's queue, `registerPanel`, anything protected-frame or secure-template shaped, `KCM:OnRestrictionChanged`. |
| DIAG-1 – DIAG-27 | Diagnostics | Debug console, the diagnostics report, the shared window chrome and marks, the perf harness. Run for `core/DebugLogSetup.lua`, `core/Diagnostics.lua`, `core/PerfSetup.lua`. |
| DEGRADED-1 – DEGRADED-7 | Degraded install | The build with `libs/LibKa0s` missing. Run for any library-absent fallback. |
| LOC-1 | Non-English client | Classification on a localized client. |

Anything under `libs/LibKa0s/` or a seam file (`core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `core/EnvSetup.lua`, `settings/OptionsSetup.lua`, `settings/Panel.lua`, `settings/Slash.lua`, `core/PerfSetup.lua`): run INSTALL-6, SLASH-1, SLASH-2, PANEL, PROFILE-1, PROFILE-15 – PROFILE-21, DIAG, BAR-6, BAR-12 and BAR-26 – BAR-30. The swap is meant to be pixel-identical, so anything that looks different is the finding. A change to `.luacheckrc`, a headless-only gate or a doc needs no smoke run.

## Before you start

- Turn error display on (`/console scriptErrors 1`, or load BugSack). Several failures below are Lua errors that the default UI hides, and a hidden error reads as a pass.
- Pin the chat frame. Most regressions show up as a `KCM.Debug` line before they show in a macro body.
- Drag every `KCM_*` macro onto an action bar so icon changes are visible.
- Target dummies (every faction's training district) are the cheapest way into combat.
- A second client on stable settings is useful to compare against.
- Keep a spread of consumables in bags: two different foods, a drink, a healing potion, a mana potion, a flask, an augment rune, a whetstone and a weightstone.
- A check that edits, wipes or reads SavedVariables works on the live file, `WTF/Account/<account>/SavedVariables/ConsumableMaster.lua`, the one the client loads. Log out first (the client rewrites the file on logout), copy it aside as a backup, edit or read the live file, then log in. Put the backup back when the check is done.

## Install

**INSTALL-1. Fresh install creates the fifteen macros.** Quit the game, delete `WTF/Account/<account>/SavedVariables/ConsumableMaster.lua`, log in → no Lua errors and no `[CM]` warning beyond the one debug-state line when debug is on. The macro UI's **General Macros** tab holds exactly: `KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`, `KCM_FLASK`, `KCM_CMBT_POT`, `KCM_STAT_FOOD`, `KCM_WPN_ENCH`, `KCM_AUG_RUNE`, `KCM_BLOODLUST`, `KCM_BATTLE_REZ`, `KCM_HP_AIO`, `KCM_MP_AIO`. Each stored icon is the picked item's texture, or the cooking pot (`fileID 7704166`) when nothing is owned, never a static `?`. `/cm dump pick food` shows a pick, so the pipeline ran after the loading screen. Result:

**INSTALL-2. Fresh install shows the macro bar.** Same fresh login → the bar is present and unlocked (gold tint and handle), dead center, one row of fifteen buttons, each wearing its category's pick with stack counts on stackables. Hovering a button shows the item's or spell's real tooltip, AIO HP and AIO MP included: out of combat the out-of-combat step (food or drink, or a spell such as Recuperate), in combat the first in-combat step (healthstone, or the first potion when the healthstone is off or missing). Raw `#showtooltip` or `/castsequence` text on an AIO slot that has picks is the defect. Macro Bar → General shows **Enable macro bar** ticked; General → Master controls shows **Lock frame** unticked. Result:

**INSTALL-3. Re-login keeps what is there.** Log out and back in without touching SavedVariables → INSTALL-1's checks pass again, existing macros are reused and no duplicate `KCM_*` macro appears. Result:

**INSTALL-4. Upgrade from a build without the macro bar.** Log out, back up the SavedVariables file (Before you start), and in the live file set `global.schemaVersion = 1`, delete the active profile's own `schemaVersion` (the stamp the v2 step is gated on), set `profile.macroBar.enabled = false` and `locked = true`, log in → the bar comes up enabled and unlocked, and both stamps read 3 (the v2 step, then the v3 label-flags step). Turn the bar off and `/reload` → it stays off; the v2 step runs once per profile. Result:

**INSTALL-5. The v3 label-flags conversion keeps the player's choice.** Log out, back up the SavedVariables file, and in the live file give the active profile `macroBar.labelOutline = false`, no `macroBar.labelFlags` key, `macroBar.buttonLabel = true`, and `schemaVersion = 2` on that profile and on `global`. Log in, open Macro Bar → Labels → **Font flags** reads *None* and the labels carry no outline (*Outline* means AceDB's shipped default won over the migration). Repeat with `labelOutline = true` → *Outline*. `/reload` → both stick, and `labelOutline` is gone from the saved file. Result:

**INSTALL-6. Version and About notes come from the TOC.** `/cm version`, `/cm help`, then `/cm config` → About → both chat lines print the TOC's `## Version` (never a stale number or `?`), and the paragraph under the logo reads the TOC's `## Notes`. A wrong folder name fails silently, as a blank paragraph and a fallback version, so look at both. Result:

## Slash commands

**SLASH-1. Bare `/cm` opens the panel.** `/cm`, then `/cm` followed only by spaces → each opens the settings panel on About, as `/cm config` does. No help table prints. Result:

**SLASH-2. Every line is tagged.** `/cm help`, `/cm version`, `/cm list` → every chat line carries the cyan `[CM]` tag; nothing prints untagged. Result:

**SLASH-3. `/cm list` groups rows by page.** `/cm list` → under `Available settings`, in this order: `[general]` (`enabled` among its rows), `[macrobar]` (the `macroBar.*` set), `[statpriority]` (`statPriority`), then `[macros]` (each composite's flags and section orders, Battle Rez's mouseover). No row renders as `table: 0x…`, and `debug`, the logging flag, is absent (session state, not a schema row). Result:

**SLASH-4. `/cm get` and `/cm set` on one row.** With General open: `/cm get enabled`, `/cm get macroBar.orientation`, then `/cm set enabled false` → each get prints one row; the set turns the addon off and the **Enable** checkbox follows. `/cm set enabled banana` → two lines, `Invalid value for enabled` and `expected true/false/on/off/1/0/yes/no`, and nothing changes. `/cm set enabled true` afterward. Result:

**SLASH-5. `/cm reset` resets one row, never the profile.** Bare `/cm reset`, then `/cm reset macroBar.orientation` → the bare form prints the usage line naming `/cm resetall` and raises no popup; the path form echoes that row and nothing else moves. Result:

**SLASH-6. Whole-value rows.** `/cm get macroBar.order` → the slot keys in order. `/cm set macroBar.order DRINK,FOOD` → Drink and Food move to the front of the bar and every other slot keeps its place. Untick Drink on Macro Bar → Buttons, then `/cm set macroBar.shown FOOD=off` → Food hides, its Buttons row drops below the rule, dimmed, and Drink stays hidden. `/cm set categories.BATTLE_REZ.mouseover off` → **Cast on mouseover** unticks and the Battle Rez body drops `[@mouseover,help]`; `/cm reset categories.BATTLE_REZ.mouseover` puts it back. `/cm stat primary AGI`, then `/cm get statPriority` → `<spec>: AGI > …`; `/cm set statPriority x` is refused and names `/cm stat`. `/cm reset categories.HP_AIO.orderInCombat` → Healthstone is back above Healing Potion on AIO Health. Result:

**SLASH-7. One `[Set]` line per panel write.** `/cm debug on`, then use each panel control that writes a whole-value row → exactly one `[Set]` line each: the AIO Health Enabled checkbox, a drag between its rows, its Reset category (`[Set] reset category HP_AIO: N rows`, no `[Prio] reset` line beside it), the Stat Priority list and its Defaults, a drag on the Buttons tab (`[Set] macroBar.order = {…}`), a drag on the bar, and Reset all priorities. A tick on the Buttons tab writes two rows and logs two, `[Set] macroBar.shown = {…}` then `[Set] macroBar.order = {…}`. `/cm aio hp_aio reset` logs the same one line as the tab's Reset category. Result:

**SLASH-8. `/cm priority`.** `/cm priority hp_pot list` → the effective HP_POT order. `/cm priority hp_pot add 12345` → added (an unknown ID is rejected); `remove 12345` → removed and blocked; `up 12345` / `down 12345` → reordered; `/cm priority hp_pot reset` → the category's added, blocked and pinned items wiped. `/cm priority flask list s:1234` → the `s:<spellID>` spell sentinel round-trips. Result:

**SLASH-9. `/cm stat`.** `/cm stat list`, `/cm stat primary AGI`, `/cm stat secondary CRIT,HASTE,MASTERY,VERSATILITY`, `/cm stat reset`, `/cm stat list 7_264`, `/cm stat list SHAMAN:ENHANCEMENT` → each does what it names; the explicit spec key and the friendly form both resolve. Result:

**SLASH-10. `/cm aio`.** `/cm aio hp_aio list`, `/cm aio hp_aio toggle hs`, `/cm aio hp_aio up hp_pot`, `/cm aio hp_aio reset` → the assembled order prints, then the flip, the within-section move and the restore each land, and the AIO Health tab follows. Result:

**SLASH-11. `/cm dump`.** `/cm dump categories`, `/cm dump statpriority`, `/cm dump bags`, `/cm dump item <id>`, `/cm dump pick hp_aio`, `/cm dump pick mp_aio` → the category list with macro names and spec-awareness; the current spec's primary and secondaries; the bag scan; the parsed tooltip plus raw lines; each composite's assembled body. No Lua error. Result:

**SLASH-12. `/cm dump events`.** → ten client events, each `registered`, and `0 rejected` in the header. Then `/cm debug on` and `/reload` → the `[Init]` line carries no `rejected events:` clause. Result:

**SLASH-13. A disabled addon refuses a feature verb.** `/cm disable`, then `/cm resync` → one line, `Ka0s Consumable Master is disabled — enable it with /cm enable` with the command in gold, and nothing else (no *auto-discovery found N*, no *recomputed all categories*). Same for `/cm bar on` (no bar appears), `/cm priority hp_pot add 12345` (after `/cm enable`, `/cm priority hp_pot list` has no 12345), `/cm stat primary AGI` and `/cm aio hp_aio toggle hs`. A verb that prints the refusal and then acts anyway is the failure. Result:

**SLASH-14. The rest of the surface answers while disabled.** Still disabled: `/cm help`, `/cm config`, `/cm version`, `/cm debug`, `/cm perf`, `/cm diagnostics`, `/cm list`, `/cm get enabled`, `/cm set scale 1.1`, `/cm reset scale`, `/cm resetall`, `/cm dump categories`, `/cm profile`, bare `/cm`, and `/cm enable` → each answers normally; `/cm help` prints the full index with the refusal line under the header, not instead of it; bare `/cm` opens the panel; `/cm enable` never refuses. A typo (`/cm resyncc`) gets `Unknown command: resyncc` and the index, not the refusal. Result:

## Settings panel

**PANEL-1. Landing page and sidebar.** Close the Settings window, run `/cm config` → it lands on the **Ka0s Consumable Master** parent page (logo, tagline, command list), headed `Ka0s Consumable Master` alone with the atlas divider under it. The sidebar has the parent expanded with exactly five sub-pages in this order: **General**, **Macros**, **Stat Priority**, **Macro Bar**, **Profiles**. Result:

**PANEL-2. `/cm config` re-expands the sidebar.** Collapse the parent in the sidebar, run `/cm config` again → it re-expands. Result:

**PANEL-3. Breadcrumb.** Click into any sub-page → the header reads `Ka0s Consumable Master › <Page>` with the arrow glyph, and the sidebar's own label stays unprefixed. Result:

**PANEL-4. About's command list matches `/cm help`.** `/cm config` → About, then `/cm help` → every `COMMANDS` row reads the same in both, one space either side of the em dash, the command gold and the description white. A row in one and not the other, or different dash spacing, means the panel grew its own formatter. Result:

**PANEL-5. No raw locale key renders.** Walk every sub-page, the debug console and `/cm perf` → every label, tooltip title, heading, button and perf step name is English prose. One `SCREAMING_SNAKE_CASE` string on screen (`STEP_START`, `PANEL_TITLE_SUFFIX`, `LIST_HEADER`) means a descriptor was handed `KCM.L`, and it fails for every key in that module at once. Result:

**PANEL-6. The General page's two tabs.** Open General → a two-tab strip, **Master controls** first and **Maintenance** beside it. Master controls holds nine controls, two per line: `[Enable Consumable Master] [General visibility]`, `[Master scale] [Master alpha]`, `[Lock frame] [Debug console]`, `[Minimap button]` alone, then the `[Reset position | Reset all settings]` pair, and nothing else. Maintenance holds `[Force resync | Force rewrite macros]` and a full-width `[Reset all priorities]`, under no heading of its own. A **Defaults** button sits top-right in the page header. Result:

**PANEL-7. Nothing is declared twice.** Macro Bar → General → no Lock and no Reset position. `/cm set macroBar.locked true` → still works, and General's **Lock frame** ticks. Result:

**PANEL-8. The master rows compose with the bar's own.** **Master scale** 2.0 with **Bar scale** 1.0 → the bar doubles; Bar scale 0.5 → effective 1.0. Same for **Master alpha** against **Bar opacity**. **General visibility** *Only in combat* with the bar's **Combat visibility** *Always* → the bar shows on pull and goes on combat drop; set Combat visibility to *Hide in combat* too → the two never agree and the bar stays hidden. Result:

**PANEL-9. Force resync.** Maintenance → **Force resync** (or `/cm resync`) → the tooltip cache invalidates, auto-discovery re-runs and every category recomputes (`[Scan]` and `[Calc]` lines with debug on). In combat `/cm resync` is not refused: it prints `in combat — picks computed now; macro writes will apply when combat ends.`, still recomputes, and the writes land on regen (the button is under the combat cover then, COMBAT-8). Result:

**PANEL-10. Force rewrite macros.** Maintenance → **Force rewrite macros** (or `/cm rewritemacros`) → every `KCM_*` body and icon is re-issued unconditionally, which clears a stale action-bar texture. Result:

**PANEL-11. Reset all settings.** Hover **Reset all settings** → the tooltip reads *Reset the current profile to its defaults — the same thing Profiles -> Reset Profile does. Your other profiles are not affected.*, with a plain `->` rather than an arrow glyph (a tooltip without the Profiles clause, or *Restore every setting in this addon to its default.*, means the descriptor lost `profilesPage` or `resetProfile`). Click it → the collection's one confirm popup; Yes resets the whole active profile, items in bags are re-discovered, discovered items no longer in bags drop, and the open panel repaints. Raise the popup again, pull a dummy and press Yes in combat → *in combat — reset deferred until regen.* and nothing changes. Result:

**PANEL-12. `/cm resetall` raises the same popup.** `/cm resetall` → the same popup as PANEL-11 (one `KCM_CONFIRM_RESET` popup, no second one). Cancel → nothing is wiped (a custom added item survives). Run it again, Yes → the same effect as PANEL-11, and in combat the same refusal line with nothing changed. Result:

**PANEL-13. The reset closes the debug console too.** Tick **Debug console** so the window is open, change something profile-backed (drag the bar, or drop Button size), then Reset all settings → Yes → the console window is closed and the checkbox unticked, alongside everything else the reset took. With `/cm debug on`, the reset logs one `[Set] reset profile '<name>' to defaults: N rows` line and no `[Set] state.debugConsole` line. Repeat through `/cm resetall` → identical. Result:

**PANEL-14. Reset all priorities.** Set a non-default Button size, then Maintenance → **Reset all priorities** → a different popup naming the narrower act; Yes clears every category's added, blocked and pinned items and every spec's stat-priority override, and nothing else (Button size survives). Raise its popup again, pull a dummy and press Yes in combat → `in combat — reset deferred until regen.` and nothing is cleared. Result:

**PANEL-15. The General page's Defaults.** Disable the addon and move **Master scale** off 1.0, then press the top-right **Defaults** from the **Maintenance** tab → this page only resets, every tab of it: Enable ticks back on (no chat line), scale, alpha and visibility return to shipped values, and the debug console switches off. Category and stat-priority customizations survive (a custom added item is still there). With `/cm debug on` the console shows `[Set] reset General page: N rows`. Result:

**PANEL-16. Every Defaults button is the AceGUI one.** Visit General, Macros, Stat Priority and Macro Bar → each has a top-right **Defaults** rendered dark with gold text, not Blizzard's red stone button; About has none. Check again with a skinning addon loaded if you have one. Click one → its page reset still fires. Result:

**PANEL-17. Defaults cannot fire in combat.** With General open and a setting off its default, pull a dummy and click the top-right **Defaults** → it sits under the combat cover (COMBAT-8), so nothing happens; after combat the setting still holds your value. Result:

**PANEL-18. The Settings window's footer Defaults.** Blizzard's control at the bottom of the Settings frame: with General open → the page's defaults action fires, as the header button does; with About open → nothing happens and nothing errors. Result:

**PANEL-19. A mutation does not freeze the panel.** Visit General, two Macros tabs, Stat Priority and two Macro Bar tabs so several pages are built. On General toggle **Enable**, toggle **Debug console**, press **Force resync** → each responds at once with no half-second stall. Repeat on a Macros tab and on Stat Priority. (Force rewrite macros and Reset all priorities may hitch briefly; that is the synchronous macro rewrite.) Result:

**PANEL-20. An off-screen page refreshes when shown.** While viewing General, `/cm priority flask add 212283` (any valid flask ID), then open Macros → Flask → the new entry is there, with no stale state and no Lua error. Result:

**PANEL-21. Two-tier refresh.** Change a setting on one page, switch to another page showing the same value → it is current. Go back → the first page did not rebuild under you. Result:

**PANEL-22. The scrollbar gutter is always there.** A short page → the gutter shows with the thumb parked and inert. A long one (a Macros tab with a full priority list) → it scrolls and the wheel works. Result:

**PANEL-23. Section spacing.** Macro Bar (the most section-dense page) → the gap above each heading after the first is even; a missing 10px gap is the regression. Result:

**PANEL-24. The Macros tab strip.** Open **Macros** → a strip pinned above the scroll that stays put when the body scrolls. Fifteen tabs, left to right, wrapping as needed: **Food, Drink, Healing Potion, Mana Potion, Healthstone, AIO Health, AIO Mana, Flask, Combat Potion, Stat Food, Weapon Enchant, Augment Rune, Vantus Rune, Bloodlust, Battle Rez**. Full names, never the bar's short forms. Food is selected on open, and its body is: drag icon, Add item or spell by ID, Priority list, Reset category. Result:

**PANEL-25. A tab switch tears the body down.** Click **Battle Rez** → the **Cast on mouseover** checkbox appears (the only targeted category). Click **Bloodlust** → it is gone. Result:

**PANEL-26. Scroll position does not carry across a tab switch.** On a long list scroll to the bottom, click another tab → it opens at the top; switch back → also at the top. (Within one tab a drag keeps the scroll; that is PRIO-11.) Result:

**PANEL-27. The strip wraps with the window.** Drag the Settings window narrower and wider → the strip re-wraps onto more or fewer rows, the body follows it, and no tab is clipped or overlaps. Open the panel for the first time at a narrow width → the strip is wrapped correctly on that first draw, not a vertical stack that heals on the next click. Result:

**PANEL-28. A wrapped strip does not move when clicked.** Narrow the window until the Macros tabs wrap onto three rows. Select the first tab and note the content panel's top edge, then select the second → the rows and the panel stay put to the pixel. Repeat on Macro Bar (eight tabs on two rows). Result:

**PANEL-29. The tab strip survives being pooled and re-dressed.** On each of the four strips (General, Macro Bar, Stat Priority, Macros), cycle every tab three times and end on the first → each label is its own tab's, the selected tab is the one you pressed, the body is drawn under the right tab, and the band height never moves. A carried-over label, a wrong highlight or a moving band is the pool handing back a frame it did not finish dressing; no headless check can see it. Result:

**PANEL-30. The first-open item storm fills the list once.** Log in fresh (not `/reload`, so the item cache is cold), go straight to `/cm config` → Macros → a tab with many rows → rows start as `[Loading]`, then within about a second of the last item arriving the list fills in once, as a single hitch at most. A list that flickers row by row stopped debouncing; one still reading `[Loading]` ten seconds later, with the items known to `/cm get`, stopped firing. Result:

**PANEL-31. The refresh cap holds under constant traffic.** Leave the panel open on that page and keep bag traffic going for more than three seconds without pause (move stacks between bags, or sell and buy back) → the list updates during the traffic, about three seconds after the first request, not only once it stops, and each rebuild is a single hitch at most. Result:

## Profiles

**PROFILE-1. The Profiles page.** `/cm debug on` and keep the console open for this theme. `/cm config` → **Profiles**, last in the sidebar → AceDBOptions' controls (Reset Profile, the current profile, New, Existing Profiles, Copy From, Delete a Profile) sit inside the addon's canvas under the header and the `Ka0s Consumable Master › Profiles` breadcrumb, not in a floating window. No Defaults button top-right and no tab strip (Profiles and the landing page are the two pages without one). Result:

**PROFILE-2. A new profile is created, switched to and migrated.** Back up the SavedVariables file first (Before you start); keep two different foods in bags. Type `Alt` into New and press Enter → the console shows `[Profile] switched to 'Alt'`, then `[DB] migrated profile 'Alt' schema v1 -> v3`, then `[Macro] forced rewrite: cleared 0 macro fingerprint(s) and 0 queued write(s)`, then a `[Scan]` and a `[Calc]` line, and no `[Set]` line. The page names Alt as current. Silence where the migration line belongs is the defect. Result:

**PROFILE-3. A switch moves everything, without a reload.** In Alt: unlock the bar and drag it to another corner, set Macro Bar → Layout → Buttons per row to 5, hide one slot and move another to the front on Macro Bar → Buttons, and on Macros → Food block the food `KCM_FOOD` uses so it picks the other. Note `KCM_FOOD`'s item. Existing Profiles → Default → the bar jumps to Default's position, grid, shown slots, slot order and lock state, `KCM_FOOD` names Default's food again, and the console shows `[Profile] switched to 'Default'` and `[Macro] forced rewrite: cleared N macro fingerprint(s) …`. A bar still showing Alt's layout is the defect. Result:

**PROFILE-4. The round trip rewrites every macro.** Switch to Alt again → everything from PROFILE-3 comes back and `KCM_FOOD` names Alt's food. A macro that keeps the other profile's item means fingerprints were trusted across the switch. Result:

**PROFILE-5. Migration runs once per profile.** Switch back to Default → no migration line the second time, and nothing is lost: settings, bar position and geometry are as you left them. Log out and open the live SavedVariables file → every visited profile carries its own `schemaVersion = 3`, and `global.schemaVersion` reads 3. Log back in. Result:

**PROFILE-6. The v2 step's one-time cost.** A profile written before per-profile stamps meets the v2 step once on its first arrival, so a profile with a deliberate `macroBar.enabled = false` comes back on. Set it off again, switch away and back → it stays off. A bar that re-enables on every switch is the defect (the profile stamp not being written). Result:

**PROFILE-7. The bar off in one profile.** In Alt, untick Macro Bar → General → Enable macro bar. Switch to Default → the bar reappears; switch to Alt → it goes. No reload anywhere. Result:

**PROFILE-8. Copy.** On Default, Copy From → Alt → exactly one `[Set] copied profile 'Alt' → 'Default'` line, then the `[Macro]`, `[Scan]` and `[Calc]` lines, and no `[Profile]` line. Default is still current. The bar takes Alt's layout at once (off, if PROFILE-7 left it off; tick it on to see Alt's position and grid) and `KCM_FOOD` rewrites to Alt's food. Result:

**PROFILE-9. Reset Profile and Reset all settings are one act.** Reset Profile → confirm → exactly one `[Set] reset profile 'Default' to defaults` line; the bar is back at screen center, unlocked, one row of fifteen with every slot shown, and every page reads shipped values. Change one setting, then General → **Reset all settings** → Yes → again one line, `[Set] reset profile 'Default' to defaults: 1 rows` (only this path carries the count). Switch to Alt → its settings are untouched and the list still holds both. Result:

**PROFILE-10. Delete.** On Default, Delete a Profile → Alt → confirm → Alt leaves the list; nothing on the bar or in the macros changes, and no `[Set]` or `[Profile]` line appears. Result:

**PROFILE-11. An open page follows a switch made elsewhere.** Create `Alt` again and set Button size to 50 there. Switch to Default, open Macro Bar → Layout and leave it open. `/cm profile Alt` → the Button size slider reads 50 at once, not a second later, and moving it changes Alt. Profiles names Alt as current. Result:

**PROFILE-12. A switch in combat through AceDB.** Pull a dummy and run `/run LibStub("AceAddon-3.0"):GetAddon("ConsumableMaster").db:SetProfile("Default")` mid-fight → no Lua error; the bar keeps its layout until combat ends and then applies Default's, and the macro writes land on regen. Result:

**PROFILE-13. What stays out of a profile.** Across every switch above → the debug console's open state and `/cm perf`'s saved runs never change. (The minimap button's visibility is LAUNCH-6.) Result:

**PROFILE-14. A switch through the Profiles page brings a disabled addon back.** On Default, `/cm disable`; Alt stays enabled. Pick Alt under Existing Profiles → the addon comes back up; pick Default → it stands down again. The profile callbacks survive the disabled state on purpose. `/cm enable` afterward, so Default is running again for the checks that follow. Result:

**PROFILE-15. `/cm profile` lists the profiles.** With Default and Alt present, `/cm profile` → a `Profiles` header (no trailing colon), one row per profile sorted without regard to case, the active one suffixed `(current)`, then `/cm profile <name> switches profile`. Result:

**PROFILE-16. `/cm profile <name>` switches.** On Default, `/cm profile Alt` → `Switched to profile 'Alt'.`, the console's one `[Profile] switched to 'Alt'` line, and the bar and macros follow as in PROFILE-3. `/cm profile Default` switches back. Result:

**PROFILE-17. The current profile answers that it already is.** `/cm profile Default` while on Default → `Already on profile 'Default'.` and no `[Profile]` line. Result:

**PROFILE-18. An unknown name is refused and never created.** `/cm profile Nope` → `No profile named 'Nope'.` then the list, and no switch. `/cm profile alt` → `No profile named 'alt'.`, `Did you mean 'Alt'?`, then the list. Open Profiles → no `Nope` and no `alt` profile exists. Result:

**PROFILE-19. Quotes are stripped; case and spaces are kept.** Create `Main - Realm` on the Profiles page, switch to Default, then `/cm profile "Main - Realm"` → `Switched to profile 'Main - Realm'.` Then `/cm profile 'Default'` → switched back. Delete `Main - Realm` afterward. Result:

**PROFILE-20. The verb answers while disabled, and a switch can bring the addon back.** With Alt enabled, switch to Default and `/cm disable`. `/cm profile` → the list, no refusal line. `/cm profile Alt` → switched, and the addon stands up (bar back, macros updating). `/cm profile Default` → it stands down again. `/cm enable` afterward. Result:

**PROFILE-21. The verb refuses a switch in combat.** Pull a dummy. `/cm profile Alt` → `Can't switch profiles in combat.` and nothing changes. Bare `/cm profile` → the list still prints. Result:

## State

**STATE-1. Enable off stops the addon.** General → untick **Enable** → nothing prints (`/cm disable` answers `enabled = false`), and the macro bar leaves the screen at once. `/framestack` and the debug console confirm the rest: nothing repaints on a bag change, a spec change or a cooldown tick, and no macro is rewritten. The panel stays open and usable, and every `/cm` verb still answers (SLASH-13, SLASH-14). Result:

**STATE-2. Enable off in combat.** Pull a dummy and `/cm disable` mid-fight (the panel is under the combat cover, COMBAT-8) → the bar goes on the regen that follows. The addon holds exactly one registration until then, `PLAYER_REGEN_ENABLED`, and drops it when it fires. Result:

**STATE-3. Disabled through a `/reload`.** Disabled, `/reload` → the addon comes back still off and registers nothing (not ten events torn down a frame later). Result:

**STATE-4. Disabled through a relog.** Disabled, quit the client and log back in → still off (`db.profile.enabled = false`), and no macro write happens until it is ticked on. Result:

**STATE-5. Enable on.** Tick **Enable** → nothing prints (`/cm enable` answers `enabled = true`). Either way → every event re-registers, a recompute runs at once, and the bar comes back only if **Enable macro bar** is still ticked (untick the bar while the addon is off to check: the rebuild reads current settings). Result:

**STATE-6. The lock's four doors agree.** `/cm unlock` → the bar tints gold, its handle appears, and General's **Lock frame** unticks. `/cm lock` → all three revert. `/cm bar unlock` / `/cm bar lock` → identical effect and identical line. The minimap menu's **Locked** and the checkbox itself → the same again, and the menu's box follows. While unlocked, hover the handle's help mark → the footer names `/cm lock`, the short form, not `/cm bar lock`. Any two doors disagreeing is the defect. Result:

**STATE-7. Unlock is refused while disabled.** `/cm disable`, then `/cm unlock` → the one disabled line naming `/cm enable`, and the stored lock is unchanged. `/cm enable`. Result:

**STATE-8. Unlocking a switched-off bar says so.** `/cm bar off`, then `/cm unlock` → Lock frame unticks and the line reads `macro bar unlocked (the bar is off — /cm bar on to show it)`, never "drag it". `/cm lock`, then the minimap menu's **Locked** → the identical line. `/cm bar on` → the bar shows, already unlocked. Result:

**STATE-9. The flyout survives a stand-down.** With the bar on: `/cm disable` out of combat, `/cm enable`, then `/cm disable` in combat (the bar goes on regen), then `/cm enable`. Hover a slot in and out of combat → the flyout opens and closes, and the immediate close in combat (COMBAT-11) still holds. Result:

## Macros

**MACRO-1. Quick pass after a scoring or body change.** `/cm resync`, then `/cm dump pick <catKey>` for the category you touched → the priority list, per-entry scores and the owner-walk pick print. Open the macro UI → the `KCM_*` body names the dump's pick. For a spec-aware category, switch spec in the talents UI and repeat. Result:

**MACRO-2. Single-pick body and action-bar icon.** Drag `KCM_FOOD` onto an action slot → the slot shows the picked item's texture, not the cooking pot. The macro body is `#showtooltip` + `/use item:<id>` for an item, or `#showtooltip` + `/cast <Spell>` for a spell entry (Recuperate as a Food entry on a Rogue). Click the slot → the item is used or the spell starts casting. Result:

**MACRO-3. Blocking the pick moves to the next.** On the category's tab, press × on the current pick → within a frame the body points at the next-best owned candidate and the action-bar icon follows. Result:

**MACRO-4. An empty category writes the empty state.** On Food, remove or block every owned candidate → the body becomes `/run print('|cff00ffff[CM]|r no food in bags')` with the cooking-pot icon. The other bag categories read `no <category> in bags` the same way; the spec-aware four read `no <category> for this spec`, and Bloodlust and Battle Rez `no bloodlust available` and `no battle rez available` (`defaults/Categories.lua`). Result:

**MACRO-5. Weapon Enchant picks by the main hand's type.** Sword in the main hand → `/cm dump pick wpn_ench` shows a whetstone as the main-hand pick, a weightstone listed but excluded. The Weapon Enchant tab marks the whetstone row with the star and **MH**; weightstone rows are dimmed as not applicable. Result:

**MACRO-6. A weapon swap re-picks without a reload.** Swap the main hand to a mace → within a frame the body switches to the weightstone, the icon updates, and the tab's star and dimming flip. Result:

**MACRO-7. Dual wield picks per hand.** Sword main hand, mace off hand → the body is a `/use item:<whetstone>` + `/use 16` pair and a `/use item:<weightstone>` + `/use 17` pair; the tab marks the whetstone **MH** and the weightstone **OH**, not both on one row. Result:

**MACRO-8. A two-hander writes one hand.** Two-handed weapon, no off-hand item → the body references slot 16 only, no `/use 17`, and the tab shows only an **MH** marker. Result:

**MACRO-9. Weapon affinity comes from the subclass.** Swap main-hand weapons and read the Weapon Enchant tab's header line → sword, dagger, axe, polearm, fist and warglaive → bladed (whetstone); mace and staff → blunt (weightstone); bow, gun, crossbow and wand → no stone (oils only), and with an oil in bags that hand still gets a pick. Judge by the header and the body, not `/cm dump pick wpn_ench`, which asks the single-pick path and can name a pick for a hand the macro leaves bare. Result:

**MACRO-10. A shield is not a polearm.** Shield in the off hand → no off-hand enchant, and `/cm dump item <shieldID>` shows `classID=4` and `subClassID=6` on its `instant:` line, with `classified: (none)` (Armor subclass 6 against Weapon subclass 6; the class gate keeps them apart). Result:

**MACRO-11. Augment Rune body and order.** One augment rune in bags → the body is `#showtooltip` + `/use item:<id>`. `/cm dump pick aug_rune` → ordered by primary-stat amount, highest first (Void-Touched 25 above Ethereal 6 above Dreambound 5); a reusable rune outranks a consumable one only on an equal amount. Block the top rune on the Augment Rune tab → the pick falls to the next-highest within a frame. Result:

**MACRO-12. Bloodlust resolves the class spell first.** On a Shaman, Mage or Evoker → `KCM_BLOODLUST` resolves to that class's raid-haste spell (Bloodlust or Heroism, Time Warp, Fury of the Aspects) over any drums in bags. The seed IDs in `defaults/Defaults_Bloodlust.lua` and `defaults/Defaults_BattleRez.lua` are wiki-sourced and unverified in game, so read a wrong name or a missing pick as a data bug first; the seed-by-seed walk is [superpowers/plans/2026-08-03-bloodlust-battle-rez-VERIFY.md](./superpowers/plans/2026-08-03-bloodlust-battle-rez-VERIFY.md). Result:

**MACRO-13. Hunters reach the pet's lust through the class gate.** Marksmanship → Harrier's Cry resolves. Beast Mastery or Survival → Primal Rage resolves (the `KCM.SEED.CLASS_GATE` path; it lives in the pet's spellbook). A hunter with no pet out and no drums → the empty state, not a gate-invalid pick. Result:

**MACRO-14. Drums and the level-cap filter.** On a class with no lust ability, a drum in bags → it resolves. At max level with only a superseded, capped drum in bags → the empty state, not the dead drum (`TooltipCache.IsUsableByPlayer`). Result:

**MACRO-15. Battle Rez resolves the class spell first.** On a Druid, Death Knight, Paladin or Warlock → `KCM_BATTLE_REZ` resolves to Rebirth, Raise Ally, Intercession or Soulstone over Emergency Soul Link. On a class with no rez and Emergency Soul Link in bags → the item resolves. `/cm dump pick BLOODLUST` and `/cm dump pick BATTLE_REZ` → each body matches the dump's pick. Result:

**MACRO-16. Battle Rez's mouseover clause.** Battle Rez tab → **Cast on mouseover** is ticked by default and the body carries `[@mouseover,help][@target,help]`. Untick it → the body drops `[@mouseover,help]`, keeps `[@target,help]`, and the macro acts on your target instead of a moused-over frame. Result:

**MACRO-17. The AIO Health body.** Drag `KCM_HP_AIO` to a bar; out of combat, hovering it shows the FOOD pick's tooltip. `/cm dump pick hp_aio` → the per-section picks and the assembled body, which reads `#showtooltip`, `/castsequence [combat] reset=combat item:<HS>, item:<HP_POT>`, `/use [nocombat] item:<FOOD>`. Result:

**MACRO-18. An empty AIO side falls back.** Toggle off everything in Out of Combat → the body emits a `/run if not InCombatLockdown() then print(...) end` line for that side (`/run` takes no `[nocombat]`). Toggle off everything everywhere → the empty-state stub with the cooking pot. Result:

**MACRO-19. A spec change re-picks the spec-aware macros.** Note `KCM_FLASK`'s pick, switch spec in the talents UI → within a frame `KCM_FLASK`, `KCM_CMBT_POT`, `KCM_STAT_FOOD` and `KCM_WPN_ENCH` update to the new spec's stat priority, and `KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`, `KCM_AUG_RUNE`, `KCM_BLOODLUST` and `KCM_BATTLE_REZ` stay unchanged. `/cm dump pick flask` → the score breakdown weighs stats by the new spec. Result:

**MACRO-20. An oversized body falls back.** Force a pick whose body passes 255 bytes (a spell with a very long name, or a seed hand-edited to one) → the macro takes the empty-state stub and one chat warning names the category. Result:

**MACRO-21. A locked bag item does not flap.** Have a consumable in a locked state (being mailed or sold) → `BagScanner.Scan` still counts it and the macro does not flip back and forth. Result:

**MACRO-22. A renamed macro is left alone.** Rename `KCM_FOOD` to `MyFood` in the macro UI → on the next recompute a fresh `KCM_FOOD` is created in a free slot and `MyFood` is untouched; the addon never deletes a macro. Result:

**MACRO-23. A full account macro pool fails gracefully.** Fill the account pool to 120 macros → creating a missing `KCM_*` fails without a Lua error (the write returns `"error"`) and existing `KCM_*` macros still update. Result:

## Discovery

**DISC-1. A new item is discovered from bags.** Loot or buy an item the seed does not list (a new-tier flask not yet in `Defaults_Flask.lua`) → within a frame of `BAG_UPDATE_DELAYED`, `/cm dump pick flask` lists it with a score, and Macros → Flask shows it with the green-check owned glyph. Result:

**DISC-2. A discovered item persists out of bags.** Move that item to the bank, log out and back in → it stays in the priority list with the red-X not-owned glyph. Result:

**DISC-3. Stale discoveries are swept.** Hand-edit `discovered[id]` to a timestamp over 30 days old (or wait) → on the next login `Selector.SweepStaleDiscovered` removes it, and `/cm dump pick flask` no longer lists it. Result:

**DISC-4. The numeric item class drives classification.** For a few owned consumables, `/cm dump item <id>` → the `instant:` line's `classID` / `subClassID` and the `classified:` line agree: healing potion `classID=0`, `subClassID=1` → `HP_POT`; mana potion `0/1` → `MP_POT`; stat food `0/5` → `STAT_FOOD`; plain food `0/5` → `FOOD` or `DRINK`; flask or phial `0/3` → `FLASK`. Result:

**DISC-5. English picks are unchanged.** Food, a potion and a flask in bags, `/cm resync`, then `/cm dump pick hp_pot`, `flask`, `stat_food` → each picks the expected item and the `KCM_*` bodies target it. Result:

**DISC-6. An augment rune classifies from its Use line.** `/cm dump item 259085` → `classified:` lists `AUG_RUNE` (parsed from the "…Augment Rune." sentence). A rune not in the seed, once in bags, adds itself the same way. Result:

**DISC-7. The login tooltip race self-corrects.** Log in with augment runes in bags and open Macros → Augment Rune immediately, before tooltips hydrate → the order settles to amount-first within a moment with no `/cm resync`, and `/cm dump item <id>` shows `statBuffs` populated, never a stale empty parse. Result:

**DISC-8. Bloodlust and Battle Rez never auto-discover.** Put an unseeded, unadded item that would otherwise match (a different drum tier) in bags → it appears neither in `/cm dump pick` nor in the category's priority list. Result:

## Priority editors

**PRIO-1. The drag icon places the macro.** Macros → Healing Potion, drag the icon at the top onto an action bar → the macro lands there (Blizzard's `PlaceAction`, no taint). Result:

**PRIO-2. Add by ID, item.** Type Item, paste the ID of an item you do not own, press Enter → a row appears with the red-X glyph and the box empties. Result:

**PRIO-3. Add by ID, spell.** Type Spell, paste `1231411` (Recuperate) and click **Add** → on a Rogue the row appears with the spell's name and icon. On another class the add is still accepted: the row appears with the red-X glyph and chat prints `Recuperate is added, but you cannot cast it, so it will never be picked.` Paste `99999999` with Type Spell → the status line reads `No spell matches '99999999'.` plus the spellbook hint, nothing is added, and nothing reaches chat. Result:

**PRIO-4. Add by name.** Type Item, remove a potion you carry with × and type its exact name, Enter → it resolves to the same row. Type Spell, a class ability's name (`Recuperate` on a Rogue) → the row appears. After a `/reload`, the full name of an item the tab lists but you have not carried this session → it resolves from the list and the box empties. An item removed with × is blocked: it leaves the list and the name no longer resolves unless you carry it. An unknown name → `No item matches '<name>'. Names work for items you carry (or carried this session) and ones this list knows; otherwise use the ID or shift-click a link.` The first name in a session may read `Looking up items...` for up to about two seconds (an ID that never loads holds it for the whole wait, even for an item you carry). Result:

**PRIO-5. Suggestions while typing.** Hover the box → the tooltip says to type a name and pick it, ending with the name hint. On a tab listing several ranks of a crafted potion, type two letters → a list opens: icon, name in quality color, the crafted-quality tier icon, then the gray ID, one row per rank, told apart by tier icon. Up and Down move the highlight; Enter or a click adds that rank and clears box and list. Type the full shared name and press Enter without picking → nothing added, `Several items share the name '<name>': pick one from the list, or use the ID.`, and the list opens; Enter again → still nothing. Escape closes the list. Carry two ranks of a potion the tab does not list (two ranks of *Potion of the Hushed Zephyr*), type its full name, Enter → the same shared-name line and a list of the two carried ranks; tab-listed and carried ranks list together. Switch Type to Spell with text in the box → the page redraws, the text stays, and typing lists the tab's spells, a spell's subtext after its name; picking a spell with a subtext adds the spell. On a spec-aware tab with no active spec → no list opens, and the tooltip says a spec is missing with no name hint. Result:

**PRIO-6. A name submitted while items load.** Log in fresh (cold item cache), open a tab with many rows, paste the full name of a listed item and press Enter at once → it resolves (after `Looking up items...` if shown); repaints as names land do not wipe the text or drop the lookup. Type into the box and leave it → `[Loading]` rows stay while the box has focus or text; clear it and click away → they fill in within about a second. Result:

**PRIO-7. A refused add keeps the text.** Submit `99999999`, then an item link with Type Spell → each is refused on the status line and the text stays in the box. After a successful add, the legend and every section heading still carry their words. Result:

**PRIO-8. A drag shows where the row will land.** Drag a priority row by its handle → a copy of the row follows the cursor, the source row fades and a gold insertion line marks the drop. Drop → the pin takes effect at once and the body updates if the owned-item walk changed. Result:

**PRIO-9. A long drag is one move.** Drag a row several places → each passed row shifts by exactly one and keeps its order (a scrambled list means a run of swaps rather than one `Selector.MoveTo`). Drop a row back where it started → nothing is written and no macro is rebuilt. Result:

**PRIO-10. Only the handle drags.** Press the item name, the info button or the × → no drag starts. Result:

**PRIO-11. A drag keeps the scroll.** On a list long enough to scroll, scroll down and drag → the list stays put, at once and a second later when the pipeline repaints again. Result:

**PRIO-12. No stray handle or box after a repaint.** After a drag and after Defaults on a single-category tab; after toggling a composite's Enabled checkbox and switching tabs away and back twice; after changing spec twice on Stat Priority and scrolling → a handle appears only at the left edge of a priority row, never beside *Drag to action bar*, on the Add row, a dropdown, the banner or a reset button, and no stray row box sits on any of those or on the other composite section. With `/cm debug on`, `[Prio] paint <cat> rows=N` and `[Prio] released N handles` track each other. Result:

**PRIO-13. Every draggable row is boxed and matches MultiMeters.** On Flask, AIO Health and Stat Priority, each row wears the library's box across its whole width and consecutive rows do not touch. In one session, drag a row here and a block on MultiMeters' Columns tab → handle art, carried-copy alpha and offset, the gold line and the source fade all match. MultiMeters' divide stops its line; here the bottom row simply stays put. Dragging to the bottom of a long list lands where the line said, with no drift. Result:

**PRIO-14. The score tooltip.** Click a row's blue info button → the per-item score breakdown from `Ranker.Explain`, with numbers equal to `/cm dump pick <cat>`. Result:

**PRIO-15. × removes and blocks.** Press × on a row → it leaves the list and joins the blocked set, and auto-discovery does not add it back. Result:

**PRIO-16. Reset category and the per-tab Defaults.** **Reset category** → a confirm popup; Yes wipes the category's added, blocked and pinned items and keeps discovered ones. With Flask showing, the top-right Defaults → the same confirmation, naming Flask and "viewed spec"; on Food it names Food. It never offers the whole page. Result:

**PRIO-17. Spec-aware tabs edit the viewed spec.** On Flask, Combat Potion, Stat Food and Weapon Enchant, repeat PRIO-2 to PRIO-16 with the Stat Priority banner on a spec you are not playing → edits land in the viewed spec's bucket, not the current spec's. Result:

**PRIO-18. No active spec refuses a spec-aware add.** On a character under level 10, or with the banner on "(no active spec)", submit a valid ID on Flask → nothing added, the status line reads `No active spec, so this spec-aware category has nowhere to put '<ID>'.`, the ID stays in the box and nothing reaches chat. Result:

**PRIO-19. The composite tab.** Macros → AIO Health → In Combat lists HS then HP_POT, Out of Combat lists FOOD. Each row is drag handle, item row, Enabled checkbox, in the library's box: no up/down arrows, no remove button, no box or handle of the addon's own. Result:

**PRIO-20. The glyph key on composite tabs.** AIO Health and AIO Mana → a green tick reading *in bags* and a red cross reading *not in bags*, no star, spaced clear of the "Composite macro…" sentence above and *In Combat* below. Result:

**PRIO-21. A composite's Enabled toggle.** Untick HS on AIO Health → a recompute runs and the in-combat castsequence carries only HP_POT. Result:

**PRIO-22. A composite drag is one write.** Drag HP_POT above HS in In Combat → copy under cursor, gold line, the castsequence rewrites in the new order in one macro rebuild. Result:

**PRIO-23. A drag cannot cross sections.** Drag FOOD from Out of Combat up over In Combat → the line never enters the other section; `db.profile.categories.HP_AIO.orderInCombat` and `.orderOutOfCombat` are unchanged in membership. Result:

**PRIO-24. Composite Reset category.** **Reset category** on AIO Health → enabled flags and both section orders return to shipped defaults; the top-right Defaults raises the same confirmation. Result:

**PRIO-25. A cancel mid-drag leaves nothing.** On each of the four lists (Healing Potion's priority list, AIO Health's In Combat, Stat Priority's secondaries, Macro Bar → Buttons): the line is gold while dragging and a drop commits once (one `[Set]` or `[Prio]` line). Start a drag, press Escape with the button held to close Settings, reopen on that page → no line, no carried copy, no stray handle, the old order. Repeat with a tab switch or a sidebar page switch mid-drag. Result:

**PRIO-26. A row's own hover works after a drag.** After a drag on each of the four lists, hover the dragged row's own control (the info button on a Macros row, the tick on a Stat Priority or Buttons row) → its tooltip shows. Result:

**PRIO-27. Two lists, one line each.** Drag on Stat Priority, then on Macro Bar → Buttons, then Stat Priority again → each drag draws exactly one line under the list being dragged, and nothing stays painted on the page you left. Result:

**PRIO-28. The Stat Priority banner.** Open **Stat Priority** → the full-width **Viewing spec** dropdown sits in the page's own band above the scroll with a hairline rule under it, stays put while scrolling, lists specs with class and spec icons sorted by class name, and is not clipped (its label makes the band taller than 44px). There is no "Selection" section and no second spec picker anywhere; the Macros spec-aware tabs say "Spec-aware. Viewing: <spec>." as a sentence. Under the banner, a one-tab strip reading **Priority**, drawn even with no resolvable spec, where "No spec selected" sits inside the page under it. After a real spec switch in the talents UI the banner shows the new spec. Result:

**PRIO-29. Picking a spec repopulates both pages.** Pick another spec in the banner → Primary stat and the secondary list repopulate (override, then seed, then class fallback), and Macros → Flask (and Combat Potion, Stat Food, Weapon Enchant) reads "Spec-aware. Viewing: <picked spec>." with that spec's list. Result:

**PRIO-30. The stat editors.** **Primary stat** spans the full width; change it → it commits at once and `/cm stat list` agrees. The four secondaries are one list, each row `[handle] [tick] …… [Stat name]` with the name at the right edge; included stats carry handles in rank order, excluded ones sit dimmed below with none. Drag Haste to the top → `/cm stat list` shows it first, in one write. Dragging an included stat into the dimmed block → the line refuses. Hover a tick → the tooltip says what the click will do. Click it → a red cross, the row drops to the dimmed tail and the stored list compacts (no `""`); click the cross → it joins the end of the ranked run. Switch page and back twice, click a tick → it toggles its own row's stat. **Reset stat priority** and the top-right Defaults → the viewed spec's override drops back to seed, then class fallback. Result:

## Macro bar

**BAR-1. The Macro Bar page's tabs.** Open **Macro Bar** → eight tabs in this order: **General, Layout, Bar appearance, Button appearance, Labels, Flyout, Visibility, Buttons**; only the active tab's controls show, with no heading repeating the tab's name. Result:

**BAR-2. Row counts per tab.** Open Macro Bar and click through its eight tabs → General 1 (Enable macro bar) plus Reset slot order; Layout 8; Bar appearance 9; Button appearance 13; Labels 12; Flyout 16; Visibility 3; Buttons one draggable list of fifteen rows (handle, tick, name) under a one-line hint. No Lock position and no Reset position (they are on General). Result:

**BAR-3. Subsection headings.** **Bar opacity** is on Bar appearance, once, under an **Opacity** heading. The mixed tabs use centered headings, never colored labels: Bar appearance *Opacity* → *Background* → *Border*; Button appearance *Background* → *Border* → *Icon*; Labels *Text* → *Layout* → *Font*; Flyout *Layout* → *Background* → *Icon*. No heading repeats its tab's name or a word of it. Result:

**BAR-4. Border blocks and class-color boxes.** Each border block reads `[Show border] …`, `[Border style] [Border thickness (px)]`, `[Border color] [Use class color]`, with `Border offset (px)` after the four on Button appearance. Every color swatch, seven of them, has **Use class color** to its right on the same line; tick one → that surface takes your class color, the swatch's opacity still applies, the swatch is never grayed and its tooltip says so. On a class the client cannot resolve, the stored color paints. Result:

**BAR-5. A tab switch keeps the value.** Change a Layout slider, switch to Flyout and back → the value and the bar on screen both keep it. Result:

**BAR-6. Sliders preview live.** Drag Button size or Button spacing → the bar updates while you drag, not on release (`sliderCommit = "change"`). Result:

**BAR-7. Enable macro bar.** Untick **Enable macro bar** (or `/cm bar off`) → the bar goes; tick it → it returns with layout and position intact. Result:

**BAR-8. Clicking a slot.** Click a slot out of combat, then in combat → the consumable is used, with no taint or "Interface action failed" message. `/console ActionButtonUseKeyDown 1`, `/reload`, click a slot and a flyout entry → both fire; `/console ActionButtonUseKeyDown 0`, `/reload` → both fire again. A silent no-op under `1` means the `useOnKeyDown` pin is missing ([macro-bar.md](./macro-bar.md#buttons)). Result:

**BAR-9. Moving the bar.** Untick Lock frame → gold tint plus a **Consumable Master** handle centered above the bar. Drag the handle → the bar follows; `/reload` → it stays. Hover the handle → a one-line tooltip; hover the help mark at its right end (the collection's light glyph) → the full drag-gesture list. Buttons per row 1 → the mark does not crowd the label. Re-lock → tint and handle go and clicks pass through the gaps. Dragging a button (not the handle) picks up its macro. Result:

**BAR-10. The handle's close mark.** `/cm unlock` → an **X** just left of the help mark, the label still centered. Hover → titled **Hide the macro bar**, ending `/cm bar on brings it back.` Click → the bar goes, chat prints `Macro bar hidden. /cm bar on brings it back.`, Enable macro bar unticks, Lock frame stays unticked, the addon stays on (launcher tooltip `Enabled: Yes`, macros keep updating). `/cm bar on` → the bar returns in place, still unlocked. In combat, click the X → chat says it hides when combat ends, and it does, with no error. A drag started on the X moves the bar and hides nothing. Result:

**BAR-11. Layout.** Buttons per row 7 → two rows; Orientation Vertical → two columns; Horizontal growth Left and Vertical growth Up → the first slot moves to the opposite corner. Drag Button size, Button spacing, Bar padding and Bar scale → geometry follows live with no tearing. Result:

**BAR-12. Bar and button appearance.** Toggle each background and border box and change each color → backdrop, bar frame and button borders respond. Pick a different **Bar border style** and **Button border style** → the edge changes and the closed dropdown shows the new name, flush with no 42px gap. Border thickness 16 → thick edges; raise **Button border offset** → the border moves off the icon. Button border off → a flat icon grid. Icon zoom 40% → symmetric crop. Show stack count off → counts vanish (and a thick border never slices them when on). Show tooltips off → hovering shows nothing. This check loads ConsumableMaster alone and cannot see the defect BAR-28 exists for, so run BAR-28 too whenever the border dropdowns matter. Result:

**BAR-13. Labels.** Labels tab reads `[Show button labels] [Label text]` under *Text*, `[anchor] [placement]`, `[offset X] [offset Y]` under *Layout*, and under *Font* `[Font] [Font size (% of button)]`, `[Font color] [Use class color]`, `[Font flags] [Font shadow]`. Show labels → each button gets its category name inside its top edge. Walk the nine positions, Inside and Outside at each → the label lands where named and alignment follows. Label text *Always full* → long names overflow; *Auto* → long names shorten, short ones stay; *Always short* → all abbreviated. Drag Button size → the font scales. Offsets move the label. Pick a Font → on the first open after login every row draws in its own face (blank rows filling in on the second open mean the font preload is not running), and the labels redraw. Walk Font flags' five values (*None* removes the outline). Tick Font shadow → a soft shadow; untick → it clears. Font color with Use class color → class color, opacity still applied. Result:

**BAR-14. Cooldowns.** Use a potion → the swipe animates on that slot and every slot sharing the item; with "Show numbers for cooldowns" on, numbers appear. Result:

**BAR-15. Reorder on the bar.** Drag one slot onto another → they swap, and the swap survives `/reload`. **Reset slot order** → back to shipped order. Result:

**BAR-16. Reorder on the Buttons tab.** Macro Bar → Buttons → each row is handle, green tick, name, shown buttons first in bar order; hidden ones below a rule, dimmed, no handle. Drag a shown row two down → it lands there, passed rows shift up one, and the bar reorders at once. Drag past the rule → the line stops at the rule and the row lands last among shown. Drop in place → nothing written. (Its `[Set]` lines are SLASH-7.) Swap two buttons on the bar with the tab open → the list follows. `/reload` → both orders survive. Result:

**BAR-17. Drag out, and nothing drags in.** Drag a slot onto a Blizzard action bar → the macro lands there and the bar keeps its own. Drop an item, a spell and a non-KCM macro on the bar in turn → nothing happens and the cursor keeps holding it. Result:

**BAR-18. Which macros show.** Buttons tab, click a few ticks → each row drops below the rule at the top of the hidden group, the slots leave the bar and the rest close the gap. Click a hidden row's tick → it returns at the end of the shown group and the end of the bar. Untick all fifteen → the bar collapses to an empty backdrop with no error, and the list shows fifteen dimmed rows and no rule. Result:

**BAR-19. The flyout.** Each icon has a shaded band across its top with a small, unstretched arrow centered inside the artwork; clicking the band still fires the macro. Hover the band → a strip opens listing every owned item and known spell in the category, best nearest the button, the pick included. Click an entry → used. An unowned item is absent; a known spell on cooldown shows a swipe; moving from arrow into strip keeps it open and leaving either closes it; entries cannot be dragged to an action bar. Walk **Flyout side** through four values → arrow and growth move, the arrow points away from the button and is clearly visible, and a top or bottom label steps clear. **Reverse flyout order** → the best entry moves to the far end. **Maximum flyout entries** 2 → only the top two (debug logs the cap). Change **Flyout button size** and **Flyout spacing** → the entries resize and re-space live. At default **Gap from button** the first entry clears the border, and crossing the gap does not close the flyout. **Shaded band thickness** scales with Button size and is capped on small buttons; **Arrow size** and **Shaded band color** apply as you change them. Entries take every Button appearance setting, and **Flyout background**, its color and **Flyout padding** set the strip apart from a second bar row. Untick **Enable flyout** → bands vanish and hover does nothing. Result:

**BAR-20. The flyout closes on time.** **Auto-close after** 3, move off an open flyout → it stays about three seconds, then closes (instant close means the secure `_onleave` pre-empts the countdown). Return before it expires → it stays. Set 0 → closes on leave. Click the macro button, or an entry → it closes (the entry is used). No "Interface action failed" in any of these. Result:

**BAR-21. The flyout on special categories.** Hover AIO Health → entries from its enabled components (healthstone, healing potion, food), deduped; disable a component → its entries leave. Weapon Enchant with a sword → whetstones and any-weapon oils, never a weightstone; swap to a mace → the list flips. Unequip both weapons → the arrow disappears. Result:

**BAR-22. Fade unless hovered.** Turn it on with **Faded opacity** 0.1 → the bar sits faint until the mouse is over it (a button counts), then goes full; a faded button still clicks. Result:

**BAR-23. `/cm bar` and the bar's rows from chat.** `/cm bar` toggles; `/cm bar on|off|lock|unlock|reset` act directly; `/cm bar help` prints the current state. `/cm set macroBar.buttonSize 48` → the bar resizes and the slider tracks it. `/cm set macroBar.orientation SIDEWAYS` → rejected with the allowed values. Result:

**BAR-24. The Macro Bar page's Defaults.** Customize the bar heavily (reorder and hide on Buttons too), `/cm debug on`, press the page's Defaults → every bar setting, position, slot order and visibility return to shipped values (fifteen shown rows, shipped order, no rule), no other page changes, and General's Lock frame keeps its state. The console shows one `[Set] reset Macro Bar page: N rows` and no `[Set] macroBar.<field>` line; press again → `0 rows`. Result:

**BAR-25. A full macro pool on the bar.** With the bar on and the account pool full (MACRO-23) → slots whose macro does not exist yet show the fallback icon and do not error on click. Result:

**BAR-26. The three media dropdowns are populated.** Macro Bar → open **Bar border style**, **Button border style** and **Label font** → each lists real entries (Blizzard's own at least, plus anything a media addon registered). One empty dropdown is the finding; a populated neighbor proves nothing. Pick a new value in each → bar edge, button edges and label face change, and the closed dropdown names it. Then `/dump LibStub("LibKa0s-Options-1.0").MODULES.OptionsCompose` → at least the `COMPOSE_MINOR` in `libs/LibKa0s/OptionsCompose.lua` (7 at LibKa0s v1.63.0); a lower number means the client loaded an older payload than this build vendors, and the dropdown check above proved nothing. Result:

**BAR-27. A border style from chat is validated.** `/cm set macroBar.barBorderStyle Not A Border` → `Invalid value for macroBar.barBorderStyle` and an `allowed values:` line. `/cm set macroBar.barBorderStyle Blizzard Tooltip` → accepted and the panel tracks it. Type the value without quotes: the quotes become part of it and the set is refused. A validator that does not normalize the composed row's map stops rejecting anything. Result:

**BAR-28. The Border dropdown with five Ka0s addons loaded.** Enable KickCD, PanelMaster, AbsorbTracker, ConsumableMaster and MultiMeters, log in, open every addon's Border dropdown (here: Macro Bar → Bar border style and Button border style) → in all five the closed control is flush with the rows stacked with it, no ~42px gap, and the open list draws per-row previews. Change the load order (disable and re-enable addons), `/reload`, walk them again → nothing differs and no Lua error appears. One dropdown unlike the others, or one that changes with load order, is the finding. Result:

**BAR-29. A stored color round-trips through the picker and the CLI.** Macro Bar → **Bar backdrop color**, pick a color with an obvious non-default alpha, confirm → the bar repaints while you drag and keeps it. `/cm get macroBar.barBackdropColor` → four channels matching the picker; reopen the picker → it still shows them; `/reload` and check both again. Repeat for **Bar border color**, **Button backdrop color**, **Button border color** and the label **Font color**. Result:

**BAR-30. A color with missing channels still draws.** Log out, back up the SavedVariables file (Before you start), and in the live file delete the third and fourth entries of `barBackdropColor`. Log in, open Macro Bar → the page and the swatch draw with no Lua error, and `/cm get macroBar.barBackdropColor` prints the same four channels the swatch shows. Two answers for one stored value is the finding. Put the backup back (logged out) or re-pick the color before anything else. Result:

## Launcher

**LAUNCH-1. The button wears the addon's logo.** Log in → a round button with this addon's logo on the minimap ring, not a cooking icon and not a blank square (a blank square means `media/logos/consumablemaster.logo.128.tga` is missing or malformed). The AddOns list row wears the same art (`## IconTexture`). Result:

**LAUNCH-2. Left-click opens settings.** Left-click → the settings panel opens as `/cm config` does, and nothing else: the lock does not move. While disabled (`/cm disable`) → the same, with no refusal line. Result:

**LAUNCH-3. The right-click menu.** Right-click → the client's context menu titled `Ka0s Consumable Master` with exactly two checkboxes, in order: **Enabled** (ticked) and **Locked** (ticked while the bar is locked); no Test mode and no Show window. Click **Locked** → the menu closes, the bar unlocks (gold wash and handle), chat prints `/cm unlock`'s line, and General's Lock frame unticks; right-click again → Locked is unticked; click it → locked again. Click **Enabled** → the addon switches off with `/cm disable`'s line; click it again → it comes back up. Result:

**LAUNCH-4. The menu while disabled.** Disabled, right-click → **Enabled** unticked and live, **Locked (enable the addon first)** grayed. Click the grayed entry → nothing happens, the bar does not appear, nothing is written (Lock frame unchanged). The button stays on the minimap in both states. Result:

**LAUNCH-5. The position is saved.** Drag the button a third of the way around the ring, `/reload` → it stays where you left it (a snap back means the two registrations use different names). Result:

**LAUNCH-6. The Minimap button row.** Untick **Minimap button** on Master controls → the button goes at once; tick it → it returns at the saved angle. `/cm get global.minimap.shown` → `true` while visible; `/cm set global.minimap.shown false` → hidden, and still hidden after `/reload`. `/cm get global.minimap.hide` → *Setting not found*. With it hidden, switch profiles on the Profiles page and back → it stays hidden throughout. Result:

**LAUNCH-7. No reset brings it back.** With the button hidden: Reset all settings → Yes (or `/cm resetall`) → every profile setting resets and the button stays hidden. Press General's Defaults → Master scale, Master alpha, General visibility and Lock frame reset, and **Minimap button** stays unticked. Tick it → it returns at the saved angle, not the default one. Result:

**LAUNCH-8. The broker plugin.** Load a broker display (Titan Panel, ElvUI data texts, Bazooka), open its plugin list and click Ka0s Consumable Master → it is listed with the same logo, and the click does what clicking the minimap button does. There is no setting to hide it from a display. Result:

**LAUNCH-9. The status tooltip.** Hover → top to bottom: `Ka0s Consumable Master  v<TOC version>`, `Enabled: Yes` in green, `Locked: No` in red (or `Yes` in green), `Left-click: Open settings`, `Right-click: Options menu`; no Test mode line. Toggle Locked from the menu, hover again → the Locked line flips. `/cm disable`, hover → `Enabled: No` in red, Locked unchanged, the same two hints. `/cm enable`. Result:

## Combat

**COMBAT-1. A macro write in combat waits for regen.** Pull a dummy and loot (or trade for) new-tier potions mid-fight → `BAG_UPDATE_DELAYED` recomputes and the write is queued; `/cm dump pick hp_pot` shows the pending pick while still in combat. Drop combat → the write flushes, the body updates and the action bar takes the new icon. Result:

**COMBAT-2. Re-entering combat keeps the queued write.** Re-enter combat before the flush completes → the entry stays `"deferred"` rather than counting an attempt, and it flushes on the next regen. Result:

**COMBAT-3. A write that keeps failing gives up once.** Hand-set `pendingUpdates[macroName].attempts = 2` and trigger a recompute that re-queues → after regen the third attempt prints the one-time `[CM] gave up on <name>` warning. Result:

**COMBAT-4. A `/reload` drops the queue.** Queue a deferred write, `/reload` before regen → the entry is gone (the queue is not saved), and the next event recomputes and re-queues if still in combat. Result:

**COMBAT-5. The settings category registers after an in-combat reload.** Confirm the category is under Settings → AddOns out of combat (if not, stop). Pull a dummy, `/reload` mid-fight and keep fighting, watch chat and the error frame for ten seconds → ConsumableMaster is absent from the AddOns list while in combat and no "Interface action failed because of an AddOn" appears. Drop combat → the category is there, and `/cm config` opens it with the parent expanded. Result:

**COMBAT-6. The same, disabled.** `/cm disable`, pull, `/reload` in combat. Still in combat, `/cm config` → COMBAT-7's two lines, each once, and the panel does not open. Drop combat → the category and its **Enable Consumable Master** checkbox are listed, with no taint error. `/cm enable` afterward. Result:

**COMBAT-7. `/cm config` is refused in combat.** In combat, `/cm config` → two tagged lines, each once: the library's gray `[CM] cannot open settings during combat — Blizzard's category-switch is protected`, then `[CM] Settings panel unavailable.` (the `config` verb adds its own line whenever the open is refused). The panel does not open. Result:

**COMBAT-8. An open page is covered in combat.** Open the panel on Macros, pull a dummy → the whole page, tab strip and header included, dims under a cover reading `Settings are locked during combat.`; clicking a tab or a row does nothing. Click another of this addon's pages in the sidebar → it opens covered too, and chat prints, once and in gray, `settings are locked during combat — changes are refused until it ends`. Drop combat → the cover lifts and the page shows current values. Result:

**COMBAT-9. Dragging a macro icon is refused in combat.** In combat, drag a macro-bar slot (the Macros tab's drag icon is under the combat cover, COMBAT-8) → `[CM] in combat — drag a macro to an action bar once combat ends.` and no Lua error. Result:

**COMBAT-10. Restricted spell cooldowns draw without error.** With a spell pick (Healthstone, a class heal), pull, use the spell, watch its slot and its flyout entry → the swipe animates with no Lua error. Repeat inside a dungeon or raid, where the restriction lasts the whole instance. An idle slot stays unshaded; leaving combat, the swipe finishes cleanly. Result:

**COMBAT-11. The flyout in combat.** In combat, hover an arrow → the flyout opens and closes and an entry click uses it, with no "Interface action failed". Moving off closes it immediately, ignoring Auto-close after; a click does not close it. Use your last of an item → its entry stays until combat ends, then leaves on the next refresh. A cooldown started mid-fight swipes at once. Result:

**COMBAT-12. Combat visibility.** **Combat visibility** *Hide in combat* → the bar goes the instant a fight starts and returns when it ends, with no error; then *Only in combat* → the reverse. Both work mid-fight. Result:

**COMBAT-13. Bar changes in combat are deferred.** `/cm bar off`, then pull a dummy. In combat: `/cm bar on` → `in combat — the macro bar will appear when combat ends.`; `/cm set macroBar.buttonSize 48` → the value echoes and nothing moves yet. Drop combat → the bar appears at the new size, with no taint. Pull again and drag one slot onto another → the drag never starts (COMBAT-9's line) and the order is unchanged; on-screen buttons keep working. The Macro Bar page takes no drag or tick in combat: it is under the cover (COMBAT-8). Result:

**COMBAT-14. A mid-key reload does not blank the macros.** In a Mythic+ key, out of combat between pulls, `/reload`, then finish the key without typing any `/cm` command → within a second of completion every KCM macro on the action bar shows its item or spell icon again, with no Lua error. Result:

**COMBAT-15. The restriction trace through a key.** Same key, `/cm debug on` straight after the reload, play to the end → the console carries `[Event] ADDON_RESTRICTION_STATE_CHANGED lockdown=… type=<n> active=<0|1|2> rewrite=yes|no` lines and `[Event] PLAYER_REGEN_ENABLED lockdown=false flushed=<n>` at each kill; after a `rewrite=yes` line, one `[Macro] marked N macro(s) stale …`, a `[Calc] … reason=restriction_lifted` line and one `[Macro] KCM_… edited item=… icon=…` per macro. Note the `type=` values at the key's start, at a boss and at its end, and whether bar icons were placeholders during the key; copy the console into the bug thread. Result:

**COMBAT-16. The restriction trace at any boss.** A follower dungeon or LFR boss with `/cm debug on` → `… type=1 active=1 rewrite=no` at the pull; at the kill `… type=1 active=0 rewrite=yes`, then one `[Macro] … edited` line per macro (after combat if still in it). Action-bar icons stay unchanged; no Lua error. Result:

**COMBAT-17. Equipment and spec events trace.** Out of combat with debug on: swap the main hand → `[Event] PLAYER_EQUIPMENT_CHANGED lockdown=false slot=16`; change a ring → no `[Event]` line; change spec → `[Event] PLAYER_SPECIALIZATION_CHANGED lockdown=false`. Result:

## Diagnostics

**DIAG-1. `/cm debug on` and `off` turn logging on and off.** `/cm debug on` → the console opens, the header toggle reads green `Debug: ON`, chat acks `[CM] debug logging ON` in green, and the console shows `[Debug] logging enabled` then the `[Init]` summary (addon and version, schema, profile). Tagged lines start appearing. `/cm debug off` → red `OFF`, `[Debug] logging disabled`, lines stop. Click the console header's toggle → logging flips the same way, with the same chat ack, and the next `/cm debug on` or `off` agrees with it. Result:

**DIAG-2. Bare `/cm debug` toggles the window only.** With logging on, `/cm debug` → the window toggles and logging stays on. Reopen General → the **Debug console** box matches the window. Result:

**DIAG-3. The first open raises nothing.** `/reload`, `/cm debug on` → no `attempt to call a nil value` error, the `Debug: ON/OFF` label renders, and Escape closes the window. Result:

**DIAG-4. Line counter, Copy and Clear.** Generate activity (`/cm resync`, open and close bags) → the bottom-right `N / 3000 lines` climbs with every line. **Copy** → the copy box opens and Ctrl+C works. **Clear** → the log empties and the counter reads `0 / 3000 lines`. Result:

**DIAG-5. The scrollbar is always shown.** Few lines → the right-edge bar is visible but inert. Fill past one screen → it becomes active. Result:

**DIAG-6. Scroll and thumb stay in sync.** Mouse-wheel over the log → the thumb tracks; drag the thumb → the log scrolls; no flicker or runaway loop. Thumb at top shows the oldest lines, at bottom the newest. Result:

**DIAG-7. The log caps at 3000.** Push past 3000 lines (a few dozen `/cm resync` or several `/cm diagnostics`) → the counter holds at `3000 / 3000 lines`, the oldest lines drop off, and Copy opens without a hitch holding the newest 3000. A counter at `1500` means a stale `libs/LibKa0s/`. Result:

**DIAG-8. The checkbox follows the window.** Tick Debug console → the window opens. Close it with Escape, reopen General → unticked. Open it, close with the close mark → unticked again. Result:

**DIAG-9. The shared window edge.** Open the console and `/cm perf` side by side → both have a 1px black outer line, a 1px light-gray highlight inside it, a gold title and a gray divider under the console's title bar, never the soft 12px tooltip border. Put another Ka0s addon's console beside this one → identical edge and title tint. A difference is a library finding (this addon passes no `skin`). Result:

**DIAG-10. The collection's marks.** Console title bar → copy, clear and close are small light-gray square marks that brighten on hover, not the words Copy and Clear and a `×`. The copy window's close → the same mark. `/cm unlock` → the handle's help control is the collection's help mark, not Blizzard's `InformationIcon`, and its tooltip still lists every drag gesture. `/cm perf` beside the console → the same close mark on both. The settings panel keeps word buttons on purpose. Result:

**DIAG-11. `/cm diagnostics` appends below the trace.** `/cm debug on`, `/cm resync`, then `/cm diagnostics` → the report lands below the trace, from `[Diag] ==== Ka0s Consumable Master diagnostics begin ====` to `[Diag] ==== Ka0s Consumable Master diagnostics end: N line(s) ====`; one chat line gives the count and says to press Copy; nothing above the begin marker was cleared. Result:

**DIAG-12. The report's contents.** After DIAG-11, read the report between the markers → in order: the identity header (`[Init]`, client build, locale, logging flag, the two combat reads, the running LibKa0s files), then `state`, `settings`, `spec`, `tooltip cache`, `categories` (top five per category), `weapon enchant`, `macros`, `macro bar`, `bags`, `events`. `enabled`, `macroBar.enabled`, `macroBar.locked` and `global.minimap.shown` print even at defaults, and no line reads `section <name> failed`. Result:

**DIAG-13. The report is read-only.** Note a macro body and the bar's position, run the report → neither moved, no macro was rewritten, and the Macros page lists are unchanged. Result:

**DIAG-14. The report with logging off.** `/cm debug off`, `/cm diagnostics` → the full report lands, the header still reads red `Debug: OFF`, and the next `/cm resync` writes no `[Calc]` line. Result:

**DIAG-15. The report opens a hidden console.** Close the console, `/cm diagnostics` → it opens with the report at the bottom. Result:

**DIAG-16. The report's other spellings.** `/cm debug diagnostics`, `/cm DEBUG Diagnostics`, `/consumablemaster diagnostics`, `/consumablemaster debug diagnostics` → the same report each time. Result:

**DIAG-17. No short alias.** `/cm debug diag` and `/cm debug dump` → the window toggles, no report. `/cm diag` → `Unknown command: diag` and the index. Result:

**DIAG-18. The report while disabled.** `/cm disable`, then `/cm diagnostics` and `/cm debug diagnostics` → both write the full report with no refusal; `state` reads `enabled(stored)=no stood down=yes` and the bar section reads `bar hidden: the addon is stood down`. `/cm enable`. Result:

**DIAG-19. The report in combat.** Pull a dummy, `/cm diagnostics` → no Lua error, the header shows combat `true`, and a number the client withholds prints as `unreadable` or `<secret>`. Result:

**DIAG-20. Copy is clean.** After DIAG-11, Copy and paste into an editor → the trace, the begin marker and the branded end marker, with no `|c` escapes. Result:

**DIAG-21. The perf panel.** `/cm perf` → the seven-step panel opens, each row's right column showing a `/cm perf …` command. Result:

**DIAG-22. Arm A records a pull.** `start`, then `measure a`, pull a dummy and kill it → Blizzard's Stopwatch appears and runs during combat (the library drives it). Result:

**DIAG-23. Arm B suspends the addon.** `measure b` → the macro bar disappears and macros stop updating. Pull again. Result:

**DIAG-24. Finish restores and reports.** `finish` → the bar returns and macros resume. `report` → the figures; `dump` → one JSON line in the console. Result:

**DIAG-25. A capture reaches SavedVariables.** `/reload`, then check `ConsumableMasterPerfDB` → one record under `runs` with a non-zero `interface`. This is the only check that the TOC's `## SavedVariables` line is right. Result:

**DIAG-26. Cancel restores the addon.** `start`, `measure b`, then `cancel` → the addon comes back exactly as after `finish`. Result:

**DIAG-27. Perf strings read US English.** `/cm perf start mylabel`, then `finish` → the started line and the report header name the label. `/cm perf start` with no label, then `cancel` → the start line, the report header and the cancel line read `unlabeled` and `perf run CANCELED`, never a doubled L. Result:

## Degraded install

Rename `Interface/AddOns/ConsumableMaster/libs/LibKa0s` to `libs/LibKa0s_off` and `/reload` for these checks; rename it back and `/reload` afterward.

**DEGRADED-1. The addon still works.** `/cm list`, `/cm get enabled`, `/cm set enabled true` → it loads and macros update; each of the three verbs prints `The LibKa0s library is missing from this installation of Consumable Master (expected in libs/LibKa0s), so /cm help, list, get, set and reset are unavailable. These still work: …` and changes nothing, with no Lua error. Result:

**DEGRADED-2. No settings category.** → Ka0s Consumable Master is absent from the AddOns list, as intended. Result:

**DEGRADED-3. The panel notice is said once, at login.** During the `/reload` that starts this section, before you type anything, chat prints `The LibKa0s library is missing from this installation of Consumable Master (expected in libs/LibKa0s), so the settings panel is unavailable, and so are /cm list, /cm get and /cm set. …` once (the settings bootstrap tries to register the panel at login). Then run `/cm config` three times → each run prints only `Settings panel unavailable.`; the notice does not repeat, nothing opens, and no Lua error appears. Result:

**DEGRADED-4. Debug logging goes to chat.** `/cm debug on` → logging arms and diagnostics route to chat, with its own one-time notice. Result:

**DEGRADED-5. Library-backed verbs refuse.** `/cm enable`, `/cm lock`, `/cm bar lock` and `/cm profile Alt` → each prints one `/cm <verb> is unavailable: the LibKa0s library did not load.` line (`/cm profile is unavailable…` for the last) and changes nothing, with no Lua error. `/cm bar on` and `/cm bar off` still work and say so. Result:

**DEGRADED-6. Version and notes survive.** `/cm version` → the TOC version; the About paragraph is present (`core/EnvSetup.lua`'s own `C_AddOns` ladder). A `?` or a blank paragraph means that fallback was dropped. Result:

**DEGRADED-7. The chrome loses its art, not its controls.** → The icons and JetBrains Mono live in the renamed payload, so `KCM.Icon` and `KCM.MediaFont` answer nil: the bar handle's help control falls back to Blizzard's `InformationIcon` and is still drawn, and a console would fall back to word buttons and a `×`; a blank square there means a texture path was built by concatenation around the nil. Result:

## Non-English client

**LOC-1. Classification on a localized client.** On a deDE, frFR or other non-English client (a language pack on PTR or beta, or a non-English account), reload with the DISC-4 consumables in bags → `/cm dump item <id>` shows a localized `subType` (such as `"Tränke"`), `classified:` is still correct, and the `KCM_*` macros populate. Before the numeric-class change every consumable classified as `(none)` on such a client. Without one, the headless cases `classifier: keys on numeric subclass, not the localized subType` and its WeaponSlots equivalent, plus DISC-4, DISC-5, MACRO-9 and MACRO-10 on English, are the sign-off. Result:

## Pending sign-off

No client pass is recorded for these. They are the owner checks carried over from the previous layout that were never run or were left on an owed list (the 2026-09-12 triage batch, batch 5 of 2026-09-13, the owed checklist of the 2026-09-07 remediation, and Session CM of the 2026-09-23 remediation's in-client sessions), plus every check that is new in the 2026-09-29 rewrite or whose steps or expected result were corrected against the code in it. Sign one off on its own `Result:` line, then remove its row here.

| ID | Origin (old section and step) | Why it is owed |
|---|---|---|
| INSTALL-4, INSTALL-5 | §11a steps 1a, 1b | Corrected: the steps edit the live SavedVariables file, not a copy the client never loads |
| SLASH-3 | §11 step 7 | Corrected: `[statpriority]` prints before `[macros]` |
| SLASH-4 | §11 steps 8, 9 | Corrected: the refusal is two lines, and the accepted words end `/yes/no` |
| SLASH-6, SLASH-7 | §11 step 9b (#35) | Owed since the 2026-09-12 triage batch; SLASH-7 also carries its bulk-reset one-line rule |
| SLASH-12 | §11 step 19b | Never run: Session CM step CM.4 of the 2026-09-23 remediation (`CM-15`) |
| SLASH-14 | §11 step 14b | New: `/cm profile` answers while disabled. Corrected: the typo line reads `Unknown command: resyncc` |
| PANEL-1 | §7 steps 1, 2, seam step 2 | Never run: Session CM step CM.3, the About logo (`CM-21`) |
| PANEL-6 | §7 step 4, §7b tabs step 19 | Corrected: the Maintenance button reads `Force rewrite macros` |
| PANEL-9 | §7 step 8 | Corrected: `/cm resync` in combat recomputes with a notice rather than refusing |
| PANEL-10 | §7 step 9 | Never run: Session CM step CM.8, Maintenance's buttons (`CM-20`) |
| PANEL-11 | §7 step 10 | Corrected: the tooltip spells `->`; the combat Yes needs the popup raised first |
| PANEL-12 | §7 step 10a | Never run: Session CM step CM.10, `/cm resetall` in and out of combat (`CM-11`) |
| PANEL-13, PANEL-15 | §7 steps 10a, 11 | The bulk-reset one-line logging, owed since the 2026-09-12 triage batch |
| PANEL-14 | §7 step 10b | Corrected: the combat case goes through the popup, since the button is under the combat cover |
| PANEL-17 | Seam step 5 | Corrected: Defaults sits under the combat cover and cannot be clicked |
| PANEL-27, PANEL-28 | §7b tabs steps 5, 21 | Never run: Session CM step CM.8, the strips at the narrowest width (`CM-20`) |
| PANEL-29 | Seam step 18 | Never run: the pooled tab strip (`M4-01`, LibKa0s v1.27.0) |
| PANEL-30, PANEL-31 | §7a step 4 | Never run: the refresh burst and cap (`M4-22`) |
| PROFILE-2, PROFILE-5 | §13 steps 2-5, §13a step 2 | Corrected: the live SavedVariables file, not a copy |
| PROFILE-6 | §13 step 6 | Never run: step 5 of §5.2 on the 2026-09-07 checklist (`M2-07`), the bar that stays off after the one-time v2 step |
| PROFILE-8, PROFILE-9 | §13a steps 7, 8 | The bulk-reset one-line logging, owed since the 2026-09-12 triage batch |
| PROFILE-11 | §13a step 10 | New: the switch made elsewhere is now `/cm profile Alt` |
| PROFILE-15 – PROFILE-21 | New | The `/cm profile` verb (LibKa0s v1.63.0), never run in a client |
| STATE-2 | §7 step 5a | Corrected: `/cm disable` mid-fight, since the panel is covered in combat |
| STATE-6 | §11a step 4a | Corrected: the help mark's footer, hovered while unlocked, names `/cm lock` |
| STATE-8 | §11a step 4c | Never run: Session CM step CM.5 (`CM-09`), the unlock line for a switched-off bar. Its left-click half is gone: the launcher's left-click now opens settings (LAUNCH-2) |
| STATE-9 | §11a step 11e | Never run: Session CM step CM.12, the flyout drivers after a stand-down (`CM-06`) |
| MACRO-4 | §3 step 5 | Corrected: the empty-state text differs by category |
| PRIO-3 | §9 step 4 | Corrected: a spell your class cannot cast is added, with a chat line, not refused |
| PRIO-5, PRIO-6 | §9 steps 5a, 5b | Owed since batch 5 (2026-09-13) |
| PRIO-12 | §8 step 5a, §9 step 7, §10 step 5a | Corrected: the `[Prio]` lines need `/cm debug on` |
| PRIO-25 – PRIO-27 | §9a step 3 | Never run: the `ReorderList` ghost-frame poll and pooled line (LibKa0s v1.56.0) |
| BAR-16 | §11a step 8a | Never run: Session CM step CM.8, the Buttons-tab reorder (`CM-20`) |
| BAR-23 | §11a step 15 | Never run: Session CM step CM.6's enum refusal (`CM-17`), and the ConsumableMaster enum row of the 2026-09-23 step X1.3, whose record covers only `/bl` and `/mm` |
| BAR-24 | §11a step 16 (#36) | Owed since the 2026-09-12 triage batch |
| BAR-26, BAR-27 | Seam step 17 | Never run: the composed media dropdowns (LibKa0s v1.26.0). Corrected: BAR-26's minor, BAR-27's unquoted values |
| BAR-28 | Seam step 19 | Never run: `LSM30_Border` shared by five addons (`M4-03`) |
| BAR-29, BAR-30 | Seam step 20 | Never run: the stored color codec (`M4-18`). BAR-30 now edits the live file |
| LAUNCH-6 | §7c steps 5, 6 | Never run: Session CM steps CM.1 and CM.2, the row in its `shown` sense (`CM-19`) |
| COMBAT-5 | §6a steps 1-5 | Never run: §1.2 on the 2026-09-07 checklist (`M2-08`), and Session CM step CM.13's enabled run (`CM-05`) |
| COMBAT-6, COMBAT-7 | §6a steps 4, 6 | Corrected: the library's refusal is followed by the `config` verb's `Settings panel unavailable.`. COMBAT-7 is newly spelled out (old §6a step 4 only pointed at it) |
| COMBAT-8 | §7b tabs step 7 | Corrected: an open page is covered in combat (the Options combat lock); a tab click no longer switches |
| COMBAT-9 | §9 step 2, in-combat bullet | Corrected: only a bar slot can be dragged in combat |
| COMBAT-13 | §11a step 14 | Corrected: the in-combat changes are made from chat; the Macro Bar page is covered |
| COMBAT-14 – COMBAT-17 | Mid-key reload and the event trace (2026-09-29) | Never run |
| DIAG-1 | §7 step 7, §11 step 5, seam step 10 | Corrected: logging follows `/cm debug on`/`off` and the console header's toggle, not the Debug console box |
| DIAG-17 | §7d step 7 | Corrected: `/cm diag` answers `Unknown command: diag` |
| DIAG-27 | Perf harness step 7 | Never run: the US perf strings (`M4-01`) |
| DEGRADED-1, DEGRADED-3 | Degraded bullets 1, 3 | Corrected: `/cm list`, `/cm get` and `/cm set` are unavailable without the library; the panel notice prints at the reload, and `/cm config` prints only `Settings panel unavailable.` |
| DEGRADED-5 | Degraded bullet 5 | New: `/cm profile` refuses without the library |
| LOC-1 | §3c step 5 | Never run: the non-English session of the 2026-09-07 checklist (its §6.7) |
