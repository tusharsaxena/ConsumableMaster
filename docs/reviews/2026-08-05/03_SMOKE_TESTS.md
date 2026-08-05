# Review — 2026-08-05 — 03 Smoke Tests (in-client)

Everything that runs headless — `luacheck`, `lua5.1 tests/run.lua`, `lua5.1 tests/run.lua --list`,
`lizard` — already ran in Step 0 and is recorded in `01_FINDINGS.md`. **This document is only what
needs a login.**

**Pre-flight, one line:** from the repo root, `luacheck . && lua5.1 tests/run.lua` must be clean and
656/656 before you copy anything into the client.

---

## Pre-flight (in-client)

1. **Build:** copy the repo folder to `World of Warcraft/_retail_/Interface/AddOns/ConsumableMaster`.
   Confirm `ConsumableMaster.toc` line 1 reads `## Interface: 120007` and that `libs/LibKa0s/`
   contains all eight `.lua` files plus `LibKa0s.xml`.
2. **Errors visible:** `/console scriptErrors 1`, then `/reload`. Every step below assumes a red Lua
   error popup would be seen if one fired.
3. **Character:** any max-level retail character with (a) at least one specialization available,
   (b) food, a health potion and a healthstone or flask in bags, and (c) a weapon equipped in the
   main hand. A second spec is needed only for the regression block.
4. **Clean-SV runs:** where a test says "fresh SavedVariables", log out fully, delete
   `WTF/Account/<ACCT>/SavedVariables/ConsumableMaster.lua` **and**
   `ConsumableMasterPerfDB.lua` if present, then log back in.
5. **Target dummy:** the Stormwind / Orgrimmar training dummies are used for every combat step.

---

## C-01 / C-02 — Degraded install behaves and says so

**Change covered:** C-01 (no-op shims for the absent options library), C-02 (honest notice).

**Setup:** with the client closed, **rename** `Interface/AddOns/ConsumableMaster/libs/LibKa0s` to
`libs/LibKa0s_DISABLED`. Fresh SavedVariables not required. Log in.

**Steps:**
1. Observe the chat frame during login.
2. Type `/cm set enabled false`.
3. Type `/cm list`.
4. Type `/cm config`.
5. Open the bags and move one stack of food between bag slots (forces a `BAG_UPDATE_DELAYED` →
   recompute). Wait 5 seconds.
6. Enter combat on a training dummy, wait 10 seconds, leave combat. Wait 5 seconds.

**Expected:**
- Step 1: exactly **two** `[CM]` lines — the "running on reduced built-in fallbacks" line and a
  second naming the missing library and saying **both** the settings panel **and** `/cm` are
  unavailable. It must **not** tell you to use `/cm list`, `/cm get` or `/cm set`.
- Steps 2–4: each prints the "…so /cm is unavailable" line and nothing else.
- Steps 5–6: **no Lua error popup at any point**, and no error appearing 1–3 seconds after the bag
  change (the debounce window that F-001 fired in).

**Pass / Fail:** PASS only if no Lua error appears anywhere in the session **and** the login notice
does not name any `/cm` subcommand as still working. Restore `libs/LibKa0s` afterwards and
`/reload`.

---

## C-01 — Healthy install is unchanged

**Change covered:** C-01 (the shim must not fire when the library is present).

**Setup:** `libs/LibKa0s` restored. Fresh SavedVariables. Log in.

**Steps:**
1. `/cm config` — the panel opens on the About page.
2. Click through **every** sub-page in the left tree: General, Stat Priority, Macro Bar, Food, Drink,
   HP Potion, MP Potion, Healthstone, HP AIO, MP AIO, Flask, Combat Potion, Stat Food, Weapon
   Enchant, Augment Rune, Vantus Rune, Bloodlust, Battle Rez.
3. On **General**, toggle "Enable" off then on.
4. On **Macro Bar**, drag the "Button size" slider and watch the bar.
5. On **Macro Bar**, open the "Bar border style" dropdown (an `LSM30_Border` widget) and pick a
   different border.
6. On **Macro Bar**, open any color picker and confirm it has an **alpha** slider.

**Expected:** every page renders with its header and divider; no Lua errors; step 3 prints
`[CM] Master enable ON/OFF`; step 4's bar resizes **live during the drag**, not only on release;
step 5 redraws the border; step 6 shows the alpha slider.

**Pass / Fail:** PASS if all six hold with no errors. (Steps 4 and 6 specifically guard the
`sliderCommit = "change"` and `hasAlpha` descriptor fields at `settings/Panel.lua:218-228`, which
C-01 edits nearby.)

---

## C-04 — `/cm bar` and the settings page agree

**Change covered:** C-04 (single write path for `macroBar.enabled` / `macroBar.locked`).

**Setup:** fresh SavedVariables. `/cm config` → **Macro Bar** page, and **leave it open** on screen
for every step.

**Steps:**
1. Note the state of the "Enable macro bar" and "Lock position" checkboxes (expect ticked / unticked).
2. Without closing the panel, type `/cm bar off`.
3. Look at the "Enable macro bar" checkbox.
4. Type `/cm bar on`. Look at the checkbox again.
5. Type `/cm bar lock`. Look at "Lock position".
6. Type `/cm bar unlock`. Look at "Lock position".
7. Now drive it from the other direction: untick "Enable macro bar" in the panel.
8. Tick it again.
9. Type `/cm bar reset`, then drag the bar by its gold handle to a new spot and `/reload`.

**Expected:**
- Step 3: the bar disappears **and** the checkbox unticks in the same instant.
- Step 4: the bar reappears **and** the checkbox re-ticks.
- Steps 5–6: the drag handle disappears / reappears **and** "Lock position" ticks / unticks to match.
- Steps 7–8: the bar hides / shows (this direction already worked; it must not regress).
- Step 9: the bar is back where you dragged it after the reload.

**Pass / Fail:** PASS only if the checkbox state matches the bar state after **every** one of steps
3, 4, 5, 6. This is the exact defect F-005 describes; before the fix, steps 3–6 leave the checkbox
stale.

---

## C-09 — Item resolution still works on the hot path

**Change covered:** C-09 (`GetItemInfo` routed through `core/Compat.lua`).

**Setup:** fresh SavedVariables, so every tooltip is parsed cold. Log in with food, a health potion,
a healthstone and a flask in bags.

**Steps:**
1. Immediately after login, `/cm dump categories`.
2. `/cm config` → **Food** page. Read the priority list.
3. `/cm resync`.
4. Open the macro window (`/macro`) and read the body of `KCM_FOOD` and `KCM_HP_POT`.
5. Log out and back in (not `/reload`) and re-read the Food page.

**Expected:** step 1 lists real item names, not `[Loading]` placeholders (a few may be `[Loading]` in
the first second — re-run after 5 seconds); step 2 shows named rows with icons and a star on the
current pick; step 3 prints an auto-discovery count and "recomputed all categories."; step 4 shows
`/use item:<id>` bodies naming items you actually own; step 5 is identical to step 2.

**Pass / Fail:** PASS if no row is stuck on `[Loading]` after 10 seconds and every macro body names
an owned item. FAIL if any category resolves empty that previously resolved.

---

## C-08 — Tooltip cache still parses caps and durations

**Change covered:** C-08 (`pendingIDs` removal touches `TC.Get`).

**Setup:** a character carrying, if possible, at least one **level-capped** consumable (an old
expansion's Drums, or any item whose tooltip says it cannot be used above a level) alongside current
ones.

**Steps:**
1. `/cm dump categories` and find the capped item.
2. `/cm config` → the page owning that category.
3. `/cm resync` and re-read.

**Expected:** the capped item is present in the list but is **not** the pick on a max-level
character, and the addon does not stall on it. Current-content items rank above it.

**Pass / Fail:** PASS if the capped item is never chosen and no row is permanently `[Loading]`.

---

## C-05 / C-06 / C-07 — Test-kit adoption (in-client confirmation only)

**Change covered:** C-05, C-06, C-07. The suites themselves ran headless in Step 0; what the client
must confirm is that the kit adoption did not change any **shipping** file's behaviour.

**Setup:** fresh SavedVariables.

**Steps:** run the full **Regression suite** below, end to end.

**Pass / Fail:** PASS if the regression suite is clean. These three changes touch only `tests/`, so
any in-client difference is a signal that a shipping file was edited by mistake.

---

## Regression suite (run after every milestone)

1. **Cold login.** Delete SavedVariables, log in. No Lua errors during
   `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD`. `ConsumableMasterDB.lua` exists on next
   logout and contains a `macroBar` table and `global.schemaVersion = 2`.
2. **`/reload`.** Clean, no errors, bar returns to the same position.
3. **Combat transition.** Enter combat on a dummy with the macro bar visible and a flyout **open**.
   The flyout stays put (it may not close mid-fight by design). Leave combat — the bar re-lays out.
   No `Interface action failed because of an AddOn` red text at any point.
4. **Macro writes deferred in combat.** In combat, drink/eat until a category's best pick changes
   (or `/cm rewritemacros`). Expect the "in combat — picks computed now; macro writes will apply
   when combat ends." line, no error, and the macro body updated within a second of leaving combat.
5. **Spec switch.** Change specialization. The Stat Priority page (if open) retracks to the new spec;
   `KCM_FLASK` / `KCM_STAT_FOOD` bodies change. No errors.
6. **Every option toggled once.** With the panel open, toggle every checkbox, move every slider and
   change every dropdown on General, Stat Priority and Macro Bar. No errors; the bar reflects each
   change.
7. **Defaults button.** On any page with one, click Defaults out of combat (applies) and again in
   combat (must print "in combat — Defaults is blocked until combat ends." and change nothing).
8. **`/cm resetall`.** Confirms via popup, wipes priority lists and stat overrides, leaves the
   addon functional.
9. **Debug console.** `/cm debug on` → console appears with a monospace `<HH:MM:SS> | [tag]` line
   format and an `[Init]` summary naming the version and schema version. Press Escape — the console
   closes **and** the General page's "Debug console" checkbox unticks to match. `/cm debug off`.
10. **Settings entry from Blizzard's menu.** Escape → Options → AddOns → Ka0s Consumable Master.
    The category opens with its sub-pages expanded, same as `/cm config`.

---

## Taint-specific tests

Raised because the addon writes macros and drives `SecureActionButtonTemplate` frames.

1. **Secure buttons under combat.** In combat on a dummy, click each macro-bar slot that has a pick.
   Each must fire the item/spell. **No** `Interface action failed because of an AddOn` red text.
2. **Flyout in combat.** Hover a slot with candidates just before pulling, so the flyout is open when
   combat starts. Click a flyout entry mid-fight — it must use the item, with no red text.
   The flyout declining to close mid-fight is expected (`modules/MacroBarFlyout.lua:99-105`).
3. **Visibility driver.** Set "Combat visibility" to `HIDE_IN_COMBAT`, enter combat — the bar hides
   with no error and no red text (this is `RegisterStateDriver`, `modules/MacroBar.lua:253-256`).
   Set it back to `ALWAYS`.
4. **Settings panel in combat.** In combat, `/cm config` — must print the gray "cannot open settings
   during combat" notice and open nothing. Then click the addon's entry in the Escape → Options →
   AddOns sidebar while in combat — the Settings window must close itself rather than render a page.
5. **Combat-blocked bar toggle.** In combat, `/cm bar off` — prints "in combat — the macro bar will
   hide when combat ends.", hides nothing yet, and hides on `PLAYER_REGEN_ENABLED`. No red text.

**Pass / Fail:** PASS only if no `Interface action failed because of an AddOn` message appears in any
of the five.

---

## Performance spot-checks

Raised because the addon ships bracketed hot paths and the offline evidence for them does not exist
(see the measurement block in `01_FINDINGS.md`).

**This is the addon's own two-arm `/cm perf` capture protocol, run in-client.**

1. **Arm 1 (clean).** `/cm perf` opens the step panel. With the addon **live** and the macro bar
   visible, start a capture, pull the training dummy, fight for 60 seconds, stop. Do **not** `/reload`.
2. **Arm 2 (suspended).** In the same session, with no other addon set change, use the panel's
   suspend step and repeat the identical 60-second fight. Stop.
3. **Read the buckets, not the frame time.** Record the `cooldown` and `recompute` bucket figures
   from the report. The frame-time delta between arms is **unresolved** below the harness's own
   run-to-run spread and must not be quoted as a result.
4. **Commit the record** under `docs/perf-runs/<YYYY-MM-DD>-client-<label>.json`, creating the
   directory and its `README.md` if this is the first capture. That file is the evidence for any perf
   claim made afterwards.

**Pass / Fail:** PASS if both arms complete with no error, both declared buckets (`cooldown`,
`recompute`) appear in the report with non-zero counts — which is what proves both brackets are
actually reached — and the record is committed.

**Note:** the offline `tests/perf.lua` scenarios are **not** part of this checklist. They do not
exist in this repo (see `01_FINDINGS.md`), which is why `performance-§2`'s zero-overhead claim is
unverified here and why this capture is the only perf evidence available.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 (degraded) | | | |
| C-01 (healthy) | | | |
| C-02 | | | |
| C-03 | n/a (headless) | | covered by `lua5.1 tests/run.lua` |
| C-04 | | | |
| C-05 | | | via Regression suite |
| C-06 | | | via Regression suite |
| C-07 | | | via Regression suite |
| C-08 | | | |
| C-09 | | | |
| C-10 | n/a (headless) | | |
| C-11 | n/a (comments) | | |
| C-12 | | | via Regression suite |
| Regression suite | | | |
| Taint tests | | | |
| Perf capture | | | record committed to `docs/perf-runs/`? |
