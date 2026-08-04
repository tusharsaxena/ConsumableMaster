# 03 — Manual smoke tests

Run **after** the changes in `02_PROPOSED_CHANGES.md` are applied. Every step is literal: type what is quoted, click what is named, observe what is described.

## Pre-flight

1. **Build/install.** Copy the repo to `World of Warcraft/_retail_/Interface/AddOns/ConsumableMaster/`. Confirm `ConsumableMaster.toc` still reads `## Interface: 120007` and that `libs/LibKa0s/` is present and complete (all nine files: `Core.lua`, `DebugLog.lua`, `Options.lua`, `OptionsScroll.lua`, `OptionsWidgets.lua`, `Perf.lua`, `PerfPanel.lua`, `Slash.lua`, `LibKa0s.xml`).
2. **Headless gates before you log in.** From the repo root: `lua tests/run.lua` must print `0 failed`, and `luacheck .` must print `0 warnings / 0 errors`. A red gate stops the smoke run (anti-pattern #23).
3. **Client setup.** `/console scriptErrors 1` — Lua errors must be visible, not swallowed. Keep `/etrace` handy for C-07.
4. **Character.** Retail, max-level, **any class with a spec** (spec-aware categories need one). Carry in bags: at least one health potion, one flask, one food item, **and one weapon oil or whetstone** (WPN_ENCH is central to C-01), with a matching weapon equipped in the main hand.
5. **A dummy.** Stormwind (Valley of Heroes) or Orgrimmar (Valley of Honor) training dummies — several tests need real `InCombatLockdown()`.
6. **Backups.** Copy `WTF/Account/<ACCT>/SavedVariables/ConsumableMaster.lua` and `ConsumableMasterPerfDB.lua` aside; the degraded-install test (C-02) requires renaming a folder, and the reset tests wipe profile data.

---

## Per-change tests

### C-01 — Combat-deferred weapon-enchant flush (F-001, F-006)

**Setup.** WPN_ENCH enabled, an enhanceable weapon equipped, **two different** applicable enchant items in bags (e.g. two oils, or an oil and a whetstone matching your weapon). Out of combat, `/cm resync`.

**Steps.**
1. `/cm dump pick wpn_ench` — note the current pick.
2. Open the macro editor (`/macro`), find `KCM_WPN_ENCH`, and confirm the body contains `/use 16` (and `/use 17` if you dual-wield). Close it.
3. Attack a training dummy to enter combat and **stay in combat**.
4. While in combat, destroy/mail away the currently-picked enchant item (or move a different, higher-ranked one into bags) so the pick must change. Chat should show nothing; the write is deferred.
5. Leave combat (stop attacking, wait for the "leave combat" state).
6. `/macro` again and read `KCM_WPN_ENCH`'s body.

**Expected.** The body is the per-hand form:
```
#showtooltip
/use item:<newID>
/use 16
```
(plus the `/use item:<id>` + `/use 17` pair if an off-hand pick exists). It must **not** be the bare `#showtooltip` + single `/use item:<id>` form with no slot line.

**Pass/Fail.** PASS = `/use 16` present after the post-combat flush. FAIL = slot lines missing (the F-001 regression).

**Also verify (F-006 collapse).** Repeat steps 3–5 for a composite: enter combat, change your health-potion stock so `KCM_HP_AIO` must change, leave combat, and confirm `KCM_HP_AIO`'s body still starts `#showtooltip` and carries its `/castsequence [combat] reset=combat …` line. No chat error, no `[CM]` "gave up on …" message.

---

### C-02 — Degraded install keeps its CLI contract (F-002)

**Setup.** Log out. Rename `Interface/AddOns/ConsumableMaster/libs/LibKa0s` to `libs/LibKa0s_OFF`. Log back in.

**Steps.**
1. Observe the first `[CM]` chat line.
2. `/cm list` — read the output.
3. `/cm get macroBar.buttonSize`
4. `/cm set macroBar.buttonSize 40`
5. `/cm debug on`
6. `/cm config`
7. `/cm priority food list`, then `/cm priority food add 33443`

**Expected.**
- Step 1: one line naming the missing library (`… LibKa0s library is missing …`), not a Lua error.
- Steps 2–4: the schema list prints, `get` answers `36`, `set` answers with the new value and **no Lua error popup**. `/cm get macroBar.buttonSize` now answers `40`.
- Step 5: `[CM] debug logging ON` plus the "on-screen debug console is unavailable" notice. **No** `attempt to call a nil value` error.
- Step 6: one line saying the settings panel is unavailable and pointing at `/cm list|get|set`. Returns cleanly.
- Step 7: the priority list prints and the add is acknowledged, with no error.

**Pass/Fail.** PASS = zero Lua errors across all seven steps and every command answers. FAIL = any `attempt to call a nil value (field 'RefreshScalars'|'RefreshAllPanels')`.

**Teardown.** Log out, rename `libs/LibKa0s_OFF` back to `libs/LibKa0s`, log in, `/cm set macroBar.buttonSize 36`.

---

### C-03 — Perf harness survives a DebugLog-less library (F-007)

**Setup.** Log out. Rename **only** `libs/LibKa0s/DebugLog.lua` to `DebugLog.lua.off` (leave the rest of the folder). Log in.

**Steps.**
1. `/cm perf` — the step panel should open or the handler should answer.
2. Follow the panel's prompt far enough to produce one capture and a report (or `/cm perf report`).
3. `/cm debug` — the console should be unavailable, with a notice.

**Expected.** No `attempt to call field 'AddLine' (a nil value)`. The perf report prints to chat; the log line is simply dropped.

**Pass/Fail.** PASS = a report renders with no Lua error. FAIL = any nil-field error naming `AddLine`.

**Teardown.** Restore `DebugLog.lua`, log in, confirm `/cm debug` opens the console again.

---

### C-04 — `/cm bar` keeps the settings page in sync (F-004)

**Setup.** Fresh login, LibKa0s present.

**Steps.**
1. `/cm config` → click **Macro Bar** in the left tree. Leave the page open and visible.
2. In chat: `/cm bar off`
3. Look at the **Enable macro bar** checkbox **without** clicking anything or changing page.
4. `/cm bar on` — look again.
5. `/cm bar lock` — look at **Lock position**.
6. `/cm bar unlock`
7. Click the **Enable macro bar** checkbox off, then on, from the panel.

**Expected.** Steps 3/4: the checkbox tracks the slash command immediately, with **no page flicker** (in-place scalar refresh, not a rebuild). Step 5/6: same for **Lock position**, and the gold drag handle appears/disappears on the bar. Step 7: the bar hides and re-shows; exactly **one** chat acknowledgement per toggle, not two.

**Pass/Fail.** PASS = widget state matches the bar state after every slash command, and no duplicated chat notice. FAIL = a stale checkbox, or a visible full-page rebuild.

---

### C-05 — Loading screens are cheap again (F-005)

**Setup.** `/console scriptProfile 1` → `/reload` (needed for the perf spot-check below). Have `/cm debug on` so the `[Scan]` / `[GC]` lines are visible in the console.

**Steps.**
1. `/reload`. Read the debug console: note the `[Scan] reason=player_entering_world …` line and whether a `[GC] swept …` line appears.
2. Take a portal / fly to another zone / enter any dungeon. When the loading screen clears, read the console again.
3. Return through another loading screen.

**Expected.** Step 1 (reload = `isReload`): both the scan line and, if anything was stale, the `[GC]` sweep line. Steps 2–3 (plain zone change): the scan line still appears (bags may have changed), but **no** `[GC]` sweep line, and no second bag scan.

**Pass/Fail.** PASS = the sweep runs on login/reload only. FAIL = a `[GC]` line after an ordinary zone change.

---

### C-06 — AIO slots show a real icon (F-003)

**Setup.** Macro bar enabled and visible, `HP_AIO` and `MP_AIO` slots shown (they are by default). Health potions and/or a healthstone in bags.

**Steps.**
1. Look at the `HP_AIO` slot on the bar.
2. Hover it.
3. `/cm dump pick hp_aio` and compare.
4. Empty your bags of every HP_AIO component (no potions, no healthstone, no food) via the bank, then `/cm resync`, and look at the slot again.

**Expected.** Steps 1–3: the slot shows the icon of the first enabled sub-category's current pick (e.g. the healthstone or potion icon named by `dump pick`), **not** the grey `?` question mark. Step 4: with no components available the slot falls back to the cooking-pot default icon, not `?`.

**Pass/Fail.** PASS = no `?` icon in either state. FAIL = `?` in the populated state.

---

### C-07 — Drag pickup in combat (F-008) — **verification first**

**This test's first purpose is to answer the open question in F-008.** Run it once *before* applying C-07 to determine whether the guard is needed, then again after.

**Setup.** Macro bar visible and **unlocked**. `/console scriptErrors 1`. Stand at a training dummy.

**Steps (pre-fix, diagnostic).**
1. Out of combat: drag the `KCM_FOOD` slot off the bar onto an empty Blizzard action-bar slot. Confirm it lands.
2. Drag it back off the action bar to clear it.
3. Attack the dummy; **while in combat**, drag the `KCM_FOOD` slot off the bar toward an action-bar slot.
4. Watch for red `Interface action failed because of an AddOn` text, and check `/etrace` / the error frame.

**Expected (pre-fix).** Step 1 succeeds. Step 3 either (a) produces the red blocked-action message — F-008 is **confirmed**, apply C-07; or (b) does nothing at all with no error — F-008 is **not** reproducible on this build; record that in the sign-off notes and apply only the comment correction from C-07.

**Steps (post-fix, if C-07 applied).**
5. Repeat step 3. Expect a single gray `[CM] in combat — dragging a macro off the bar is blocked until combat ends` line and **no** red blocked-action text.
6. Leave combat and repeat step 1 — the drag must still work normally.

**Pass/Fail.** PASS = out-of-combat drag works, in-combat drag produces the addon's own notice and no Blizzard blocked-action error.

---

### C-08 — Hygiene bundle (F-009 – F-014)

**Steps.**
1. `/cm stat primary AGI` and `/cm stat secondary CRIT,HASTE` on your current spec; then `/cm stat list`.
2. `/cm stat reset`.
3. `/cm config` → open **every** subcategory in the left tree once (General, Stat Priority, Macro Bar, and each category page). Watch chat.
4. `/reload`, then re-open the settings panel.

**Expected.** Step 1: both writes acknowledged, `list` reflects them. Step 2: the override is dropped. Step 3: **no** `|cffff0000schema error|r:` lines — the new defaults-resolution validation (C-08e) must be silent for the shipped schema. Step 4: no errors, panel opens on the About page with the logo and the slash-command list.

**Pass/Fail.** PASS = no schema-error line, no Lua error, `/cm stat` round-trips.

---

### C-09 — Bounded tooltip retry (F-015)

**Setup.** `/cm debug on`, console open.

**Steps.**
1. Fresh login (or `/cm resync` after a `/reload`), then open **Food** in the settings panel and leave it open for 30 seconds.
2. `/cm dump item 33443` (or any seeded consumable) twice in a row.
3. Watch the console for repeated re-parse activity on the same itemID.

**Expected.** Items resolve and stop being reported `pending`. Any item that genuinely cannot be parsed settles (no endless re-parse); its row still renders with a name and a score derived from ilvl+quality.

**Pass/Fail.** PASS = no item is still `pending` after the panel has been open 30s, and no unbounded repetition in the console.

---

### C-10 — Click-on-down honours the cvar (F-016)

**Steps.**
1. `/console ActionButtonUseKeyDown 1` → `/reload`.
2. Click a macro-bar slot that has a usable item. Note whether it fires on press or release (compare against a Blizzard action-bar button holding the same macro).
3. `/console ActionButtonUseKeyDown 0` → `/reload`. Repeat.
4. Enter combat and toggle the cvar (`/console ActionButtonUseKeyDown 1`) **while in combat**.

**Expected.** Steps 2–3: the bar slot fires at the same moment a Blizzard action button does, in both cvar states. Step 4: no Lua error and no blocked-action text; the change applies after combat ends.

**Pass/Fail.** PASS = timing matches Blizzard bars in both states, and the in-combat cvar flip is silent and deferred.

---

## Regression suite

Not tied to a single change — these cover what the changes could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` three times in a row | No Lua error, macro bar re-appears in the same position at the same scale |
| R-2 | Delete `WTF/.../ConsumableMaster.lua`, log in fresh | Defaults populate; all 15 macros created; macro bar visible, unlocked, centered; no error |
| R-3 | Full login sequence with `scriptErrors 1` | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` produce no error frame |
| R-4 | Enter and leave combat with the settings panel **open** | Panel stays functional; `Defaults` button click in combat gives the gray notice, not an error |
| R-5 | `/cm config` from chat **and** Esc → Options → AddOns → Ka0s Consumable Master | Both land on the About page; the parent is expanded in the sidebar; in combat both refuse with the gray notice |
| R-6 | Change spec, then `/cm dump pick flask` | Pick re-resolves for the new spec; Stat Priority page retracks (if auto-tracking) |
| R-7 | Toggle every option on the Macro Bar page once (all ~45 rows) | Every slider previews live during the drag; every colour picker shows an alpha slider; no error; `/cm list` reflects each change |
| R-8 | `/cm resetall` → confirm | All priority lists and stat overrides reset; macros re-written; no error |
| R-9 | Drag one bar slot onto another (out of combat) | The two swap; the Macro Bar page's order reflects it after refresh |
| R-10 | Hover a bar slot's flyout indicator, in and out of combat | Flyout opens both times; hover-out closes it both times; auto-close honours the configured delay out of combat |
| R-11 | `lua tests/run.lua` and `luacheck .` after all changes | `0 failed`, `0 warnings / 0 errors` |

## Taint-specific tests

Required because this review raised a `[taint]` finding (F-008) and touches the protected-macro path (C-01).

| # | Check | Expected |
|---|---|---|
| T-1 | In combat at a dummy, click an action-bar slot holding `KCM_HP_AIO` | The macro fires normally; **no** red `Interface action failed because of an AddOn` |
| T-2 | In combat, force a macro rewrite (loot/destroy a potion so the pick changes) | Chat is silent; on leaving combat the macro body updates; no blocked-action text at any point |
| T-3 | In combat, `/cm rewritemacros` | The `[CM] in combat — picks computed now; macro writes will apply when combat ends.` notice; **no** protected-API error |
| T-4 | In combat with `combatMode = HIDE_IN_COMBAT` | The bar hides the instant combat starts (secure state driver), with no error |
| T-5 | C-07's step 3/5 above | See C-07 |

## Performance spot-checks

Required because F-005 and F-015 are perf-tagged.

1. **Loading-screen cost (C-05).** `/console scriptProfile 1` → `/reload`. `/run UpdateAddOnCPUUsage(); print(GetAddOnCPUUsage("ConsumableMaster"))` immediately after login; note the number. Zone into a dungeon and back, re-run the same line, and note the delta. **Expected:** the per-zone-change delta after C-05 is materially smaller than before (record both).
2. **Memory across a burst (C-09).** `/run collectgarbage("collect"); print(collectgarbage("count"))` → open the settings panel and page through five category tabs → wait 10s → run the same line. **Expected:** the residual growth settles rather than climbing on every subsequent pass.
3. **Cooldown repaint (C-01/C-10 touch the bar).** Use the built-in harness: `/cm perf`, follow the A/B protocol (capture with the addon live, capture with it suspended), and read the `cooldown` bucket. **Expected:** unchanged from the pre-change baseline — none of these changes should move it.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | **record the F-008 verification answer here** |
| C-08 | | | |
| C-09 | | | |
| C-10 | | | |
| R-1…R-11 | | | |
| T-1…T-5 | | | |
| Perf 1–3 | | | before/after numbers |
