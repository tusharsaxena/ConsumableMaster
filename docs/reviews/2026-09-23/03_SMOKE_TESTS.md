# 03 — In-client smoke tests

This checklist covers only what the game client can verify. Everything headless (lint, the 998-case suite, the offline perf
scenarios, `lizard`) was already run in Step 0 (`01_FINDINGS.md`, *Measurement run*).

**Pre-flight headless re-run** (one line, after the changes land, from the repo root):
`~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua && ~/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Both must be green, and `docs/test-cases.md` plus the README `[Tests]` badge must already show the new count.

---

## Pre-flight (client)

1. **Build.** Retail client, `## Interface: 120100` (WoW: Midnight). Copy the working tree to
   `World of Warcraft/_retail_/Interface/AddOns/ConsumableMaster/`, keeping the folder name exactly `ConsumableMaster`.
2. **Character.** Level-capped, with a spec that uses weapon oils or whetstones, and with a main-hand and off-hand weapon
   (dual-wield). In bags: at least two different ranked weapon enhancements, one food, one health potion and one healthstone.
3. **Error visibility.** `/console scriptErrors 1`. Keep `/etrace` available for the taint cases.
4. **Combat source.** A target dummy (any capital's training area), for deterministic combat enter and leave.
5. **Profiles.** Two AceDB profiles, `Default` and `B`, created on the Profiles page.
6. **Addon set.** Consumable Master only, unless a step says otherwise. The last section loads the whole collection.

---

## Per-change tests

### C-01 — A weapon-enchant write deferred in combat is flushed with its slot lines (F-001)

- **Setup:** Dual-wield. Two different weapon enhancements in bags. `KCM_WPN_ENCH` is on an action bar or the macro bar.
  Out of combat, `/cm dump pick WPN_ENCH` shows a main-hand and an off-hand pick.
- **Steps:**
  1. Out of combat, open the macro UI (`/macro`, Account tab) and read `KCM_WPN_ENCH`. Note that it has
     `/use item:<a>`, `/use 16`, `/use item:<b>`, `/use 17`.
  2. Hit the dummy until you are in combat.
  3. Type `/cm rewritemacros`. Expect the chat line "in combat — picks computed now; macro writes will apply when combat ends."
  4. Stop attacking and wait for combat to end.
  5. Re-open `/macro` and read `KCM_WPN_ENCH`.
- **Expected:** The body still carries **both** `/use 16` and `/use 17` lines, with the item ids matching the picks. There is no
  Lua error.
- **Pass / Fail:** PASS if the post-combat body has the same four `/use` lines as step 1. FAIL if it reads `#showtooltip` +
  `/use item:<id>` alone.
- **Variant (weapon swap):** Repeat with step 3 replaced by swapping main-hand weapons in combat, from bladed to blunt. The
  expected post-combat body uses the blunt-affinity pick and keeps `/use 16`.

### C-02 — A color reset does not corrupt the shipped default (F-002)

- **Setup:** Profile `Default` is active, and the macro bar is visible.
- **Steps:**
  1. Macro Bar page → set **Bar background color** to bright red. Close the panel.
  2. Type `/cm reset macroBar.barBackdropColor`. Expect the echo `macroBar.barBackdropColor = {0.00, 0.00, 0.00, 0.50}`.
  3. Profiles page → switch to profile `B`.
  4. Macro Bar page → look at the **Bar background color** swatch.
  5. `/cm get macroBar.barBackdropColor`.
  6. Switch back to `Default` and repeat steps 4 and 5.
- **Expected:** In both profiles the swatch shows black at 50% alpha (not opaque black), and `/cm get` prints
  `{0.00, 0.00, 0.00, 0.50}`. The bar's backdrop looks identical in both profiles.
- **Pass / Fail:** PASS if steps 4 to 6 show the shipped default in both profiles. FAIL if either swatch reads opaque black
  (`0,0,0,1`) or `/cm get` prints the library fallback.

### C-03 — A disabled addon's settings category survives an in-combat reload (F-003)

- **Setup:** `/cm disable`. Expect `enabled = false` (after C-11 there is only one line).
- **Steps:**
  1. Enter combat on the dummy.
  2. While still in combat, type `/reload`.
  3. After the loading screen, keep attacking briefly, then leave combat.
  4. Open Esc → Options → AddOns.
  5. Type `/cm`.
- **Expected:** **Ka0s Consumable Master** is listed in the AddOns tree once, with its sub-pages. `/cm` opens the About page.
  There is no "settings panel unavailable" line and no taint message (`Interface action failed because of an AddOn`).
- **Pass / Fail:** PASS if the category is present after combat ends, without `/cm enable`. FAIL if it is missing until the
  addon is re-enabled.
- **Cleanup:** `/cm enable`.

### C-04 — The Known Limitation is accurate (F-004)

- **Setup:** Fresh login, so the item cache is cold. `/cm disable`.
- **Steps:**
  1. `/cm config` → Macros page → open a category with many seeded items (e.g. Flask).
  2. Note any rows reading `[Loading]`.
  3. Switch to another category tab and back.
- **Expected:** Some rows may read `[Loading]` on first open. After a re-render they show names. The text in
  `docs/ARCHITECTURE.md` → *Known Limitations* matches what you saw.
- **Pass / Fail:** PASS if the doc describes the observed behavior. FAIL if the doc still claims rows hydrate while disabled, or
  if rows stay `[Loading]` after the re-render.

### C-05 — Standing up discovers what was looted while disabled (F-007)

- **Setup:** A non-seeded food item that is not yet discovered (check with `/cm dump pick FOOD`), obtainable from a vendor.
  `/cm disable`.
- **Steps:**
  1. Buy the food while disabled.
  2. `/cm enable`.
  3. Without touching the bags, run `/cm dump pick FOOD`.
- **Expected:** The new item appears as a discovered candidate immediately after `/cm enable`.
- **Pass / Fail:** PASS if it appears without any further bag change. FAIL if it appears only after moving an item.

### C-06 — Item reads route through the Compat ladder (F-005)

- **Setup:** Any character with consumables.
- **Steps:**
  1. `/reload`.
  2. `/cm debug on`, then `/cm resync`.
  3. `/cm dump pick FLASK` and `/cm dump pick CMBT_POT`.
- **Expected:** Scores, item levels and quality columns are populated, as before. There are no Lua errors, and the debug console
  shows the `[Calc]` line.
- **Pass / Fail:** PASS if the picks match the pre-change picks you noted (record them before applying the change). FAIL on any
  error or any zeroed score.

### C-07 — `/cm resetall` says what it does, and both doors behave the same in combat (F-008)

- **Steps:**
  1. `/cm help`. Read the `resetall` line.
  2. Enter combat, then run `/cm resetall` and accept.
  3. The panel cannot be opened in combat, so open it first: out of combat, open General → Master controls, then enter combat
     with the panel still open and click **Reset all settings** → Yes.
  4. Out of combat, `/cm resetall` → Yes.
- **Expected:**
  - Step 1 describes a whole-profile reset.
  - Steps 2 and 3 both refuse with the same in-combat line and change nothing.
  - Step 4 resets the profile, prints one confirmation line, and the macro bar returns to defaults.
- **Pass / Fail:** PASS if both combat doors refuse identically and the help text matches the popup text's scope.

### C-08 — The tooltip names the right tab (F-009)

- **Steps:** General → Maintenance → hover **Reset all priorities**.
- **Expected:** The tooltip says to use Reset all settings "on the Master controls tab".
- **Pass / Fail:** PASS on the exact wording.

### C-09 — Bare `/cm bar` toggles the stored flag during a perf capture (F-010)

- **Steps:**
  1. `/cm perf` → start a capture and proceed to the suspended arm (the step panel's second arm).
  2. `/cm bar`, then `/cm get macroBar.enabled`.
  3. `/cm bar` again, then `/cm get macroBar.enabled`.
  4. Finish or abort the capture.
- **Expected:** Step 2 prints OFF and `false`. Step 3 prints ON and `true`. After the capture, the bar shows or hides according
  to the stored value.
- **Pass / Fail:** PASS if the two toggles alternate the stored value.

### C-10 — The lock confirmation when the bar is off (F-011)

- **Steps:**
  1. `/cm bar off`.
  2. Left-click the minimap button.
  3. `/cm unlock`.
- **Expected:** Each prints that the bar is unlocked **and** that it is off, naming `/cm bar on`. No hidden bar appears.
- **Pass / Fail:** PASS on the wording from both doors.

### C-11 — One echo for enable and disable (F-012)

- **Steps:** `/cm disable`, then `/cm enable`, then tick and untick **Enable Consumable Master** in the panel.
- **Expected:**
  - Each verb prints exactly one line: `enabled = false` or `enabled = true`.
  - The checkbox prints nothing extra.
  - The addon stands down on disable (the bar hides) and back up on enable.
- **Pass / Fail:** PASS on one line per verb and correct stand-down and stand-up.

### C-12 to C-15 — Tests, comments, dead export, logo path (F-013 to F-017)

- **C-15 steps:** `/cm config` → the About page.
- **Expected:** The addon logo renders. That is the only in-client observable here. The rest is covered by the headless
  pre-flight.
- **Pass / Fail:** PASS if the logo draws.

---

## Regression suite

1. **Clean load.** `/reload` gives no Lua error. The chat is silent at login, since no boot summary is expected.
2. **First-time defaults.** Delete `WTF/Account/<acct>/SavedVariables/ConsumableMaster.lua` with the client closed, then log in.
   - The macro bar appears centered and unlocked.
   - `/cm list` shows defaults.
   - The account macros `KCM_*` are created (15 of them).
3. **Event order.** `/etrace` across login shows ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD with no error. The settings
   category is registered once.
4. **Combat cycle.** With the bar visible, enter and leave combat three times. Cooldown swipes animate, there is no taint red
   text, and deferred macro writes apply on regen.
5. **Disable / enable cycle** (`slash-commands-§7`):
   - `/cm disable` → the bar hides.
   - `/cm dump` still answers, `/cm` opens the panel, and a left-click on the minimap button prints the one refusal line.
   - Entering combat prints nothing.
   - `/cm enable` → the bar returns, and macros resync.
6. **Profile switch.** Switch `Default` → `B` → `Default`. Macros rewrite to each profile's picks, and the bar re-applies its
   layout.
7. **Settings panel.** Open every page. On the Macro Bar page toggle each checkbox once, drag each slider, change one color,
   press **Defaults**, and confirm the bar follows each change live.
8. **Macro-bar drag and lock.** Unlock, drag the handle, lock, then `/reload`. The position persists.

## Taint-specific checks (because F-001 and F-003 touch combat paths)

1. After C-01's combat steps, click `KCM_WPN_ENCH` and one other KCM macro on an action bar in combat. There should be no
   `Interface action failed because of an AddOn`.
2. After C-03, open the panel from `/cm config` **and** from Esc → Options → AddOns. Both routes work, and there is no taint
   report in `/etrace` or chat.

## Performance spot-check (C-02 and C-06 carry `[perf]` notes)

- **Offline (headless, before and after in the same run):** `tests/perf.lua`'s `recompute` bytes/iter (2551.1 today) should not
  rise after C-06.
- **In client:** follow the `/cm perf` two-arm capture protocol (`performance-§7`):
  1. Clean arm first, with the suspend arm second.
  2. Windows open on the player's combat *state*.
  3. No `/reload` between arms, and the same addon set in both arms.

  Read the `cooldown` and `recompute` **bucket figures**, not the frame-time delta. Record the capture as a frozen
  `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` bundle via `/wow-addon:perf-analysis`.

## Collection-wide check (cross-addon, in client)

- **Setup:** Load all ten Ka0s addons together.
- **Steps:**
  1. Type each root and confirm it reaches its own addon: `/at /am /bl /cm /kcd /lh /mm /pm /pc /wg`.
  2. Type each long form too.
  3. Open Settings → AddOns and confirm each addon appears **exactly once**, and each multi-page addon's pages appear once each.
- **Pass / Fail:** PASS if every root answers its own addon and there are no duplicate categories.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| C-08 | | | |
| C-09 | | | |
| C-10 | | | |
| C-11 | | | |
| C-12 to C-15 | | | |
| Regression 1–8 | | | |
| Taint 1–2 | | | |
| Perf spot-check | | | |
| Cross-addon | | | |
