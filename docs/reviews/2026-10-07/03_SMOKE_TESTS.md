# 03 — In-client smoke tests

These are for the owner to run in the client after the changes in `02_PROPOSED_CHANGES.md` land. The headless suites already ran
(see `01_FINDINGS.md` → Measurement run) and are not repeated here.

**Before you start (headless):** `lua5.1 tests/run.lua` (expect 0 failed) and `luacheck .` (expect 0/0).

## Pre-flight

- Client: retail Midnight, `## Interface: 120100`. The game loads `GIT/ConsumableMaster` through its symlink, so test the real
  checkout and not a side worktree.
- `/console scriptErrors 1`, then `/reload`.
- You need **two characters on the same account**. Give each its **own** profile: Options → AddOns → Ka0s Consumable Master →
  Profiles → *New profile* named after the character, so that `/cm profile` lists two names.
- For C-02 you need a Demon Hunter that can switch to **Devourer**. For C-04 you need any class with two specs.
- `/cm debug on` and leave the console open. The `[Macro]`, `[Calc]` and `[Scan]` lines are the evidence for several steps.

---

## C-01 — The live macro is trusted over the fingerprint (F-001)

**Setup.** Characters A and B, each on its own profile. Give them **different** food in their bags (A: food X, B: food Y), so that
`KCM_FOOD` resolves differently on each.

**Steps.**
1. Log in as B. Open the macro UI (`/macro`) → General Macros → `KCM_FOOD`. Note that the body reads `/use item:<Y>`.
2. Log out and log in as A. Confirm that `KCM_FOOD` reads `/use item:<X>`.
3. Log out and log in as B **without** changing B's bags.
4. Check the debug console and `/macro` → `KCM_FOOD`.
5. On B, run `/cm debug on`, then `/reload`, and watch one full minute idle in a city.
6. In `/macro`, delete `KCM_FOOD`. Then loot or move any bag item so the bags change.

**Expected.**
- Step 4: a `[Macro] KCM_FOOD edited item=<Y>` line, and the body reads `/use item:<Y>`.
- Step 5: **no** repeated `[Macro] … edited` lines for unchanged macros. One write per pass would mean the client normalizes the
  body (see the C-01 risk in 02).
- Step 6: `[Macro] KCM_FOOD created item=<Y>`, and the macro is back in the list.

**Pass / Fail.** All three expectations hold, and there are no Lua errors.

## C-02 — Devourer ranks Intellect consumables (F-002)

**Setup.** A Demon Hunter, switched to Devourer, with no Stat Priority override for Devourer. Check this on Options → Stat Priority:
the Devourer row shows the shipped order. Carry one Intellect item and one Agility item of the same kind (stat food or combat potion).

**Steps.**
1. `/cm dump pick STAT_FOOD` (or `CMBT_POT`).
2. Open Options → Macros → the same category and read the top rank.

**Expected.** The Intellect item ranks above the Agility item, and `KCM_STAT_FOOD` (or `KCM_CMBT_POT`) uses it.

**Pass / Fail.** The Intellect item is picked.

## C-03 — Flyouts rebuild from one shared cache (F-003)

**Setup.** A default profile with the bar and the flyout on, out of combat, and a full set of consumables in the bags.

**Steps.**
1. Hover each bar slot and confirm that its flyout lists the same items, in the same order, as before the change. The two AIO
   slots list their sub-categories' items.
2. Loot or move a bag item and re-hover.
3. Run the performance check below.

**Expected.** The flyout content and order are unchanged from before the fix. There are no Lua errors.

**Pass / Fail.** The content matches and there are no errors.

## C-04 — A spec change discovers bag items for the new spec (F-004)

**Setup.** Carry a flask (or stat food) that is **not** in the shipped seed list. A new-patch item works, or any flask that
`/cm dump pick FLASK` shows only under "discovered".

**Steps.**
1. In spec A, confirm that `KCM_FLASK` uses it.
2. Change to spec B **without** touching the bags.

**Expected.** A `[Scan] reason=spec_changed …` line appears, and `KCM_FLASK` (after combat, if you are in it) uses the same flask
under spec B. This assumes no higher-ranked candidate exists for B.

**Pass / Fail.** The flask is the pick in spec B with no bag change.

## C-05 — Composite resolver (F-005)

**Steps.**
1. Options → Macros → HP AIO. Turn off `FOOD` and reorder `HS` / `HP_POT`.
2. Hover the HP AIO bar slot.

**Expected.** The flyout reflects the same enable set and order as the `KCM_HP_AIO` macro body (`/macro`).

**Pass / Fail.** The flyout and the macro body agree.

## C-06 — Strict IDs in `/cm priority` (F-006)

**Steps.** Run `/cm priority FOOD add 0`, `/cm priority FOOD add 1.5`, `/cm priority FOOD add -5`, then
`/cm priority FOOD add s:5512` and `/cm priority FOOD add 113509`.

**Expected.** The first three print the usage line and change nothing. The last two add their entries.

**Pass / Fail.** The output is exactly as described.

## C-07 — A groupmate's respec does nothing here (F-007)

**Setup.** Be in a party with a second character or a friend, with `/cm debug on`.

**Steps.** Have the groupmate change spec.

**Expected.** No `[Event] PLAYER_SPECIALIZATION_CHANGED` line and no `[Calc] reason=spec_changed` line. Your own respec still produces
both.

**Pass / Fail.** As described. This step also verifies F-007's premise: if no line appeared *before* the fix, record that the event
does not fire for groupmates on this build.

---

## Regression suite

- `/reload` is clean. Login on a fresh profile populates the defaults. There are no errors through `ADDON_LOADED` →
  `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD`.
- Enter and leave combat with the bar visible. A potion used in combat shows its cooldown swipe on the bar and in the flyout.
- In combat, change the bags (drink or use a potion). A `held N write(s) for combat` line appears, and after combat the matching
  `[Macro] … edited` lines appear.
- Profile switch with `/cm profile <other>`: the macros rewrite and the bar re-applies.
- `/cm disable`, then loot, then `/cm enable`: the new item is discovered on stand-up.
- Settings panel: open every page and toggle one option on each.
- **Cross-addon (Step 0b's in-client half).** With all eleven Ka0s addons loaded:
  - Type each slash root (`/at /am /bl /cm /kcd /lh /mm /pm /pfe /pc /wg`) and confirm that it reaches its own addon.
  - Open Settings → AddOns and confirm that each addon appears exactly once, and each multi-page addon's pages once each.

## Performance spot-checks (F-003)

- **Offline, before and after (deterministic).** Run the scratch attribution described in `01_FINDINGS.md`, F-003: `tests/perf.lua`'s
  loader with the collector stopped, timing `MacroBar.Refresh` and counting `C_TooltipInfo.GetItemByID`. Expect a drop from
  **142727.7 B/refresh and 107 calls/refresh**. Do not compare timings across machines.
- **In-client.** Run `/cm perf` with the standard two-arm protocol (clean arm first, suspend as the second arm, no `/reload` between
  arms). Read the `recompute` bucket figures rather than the frame-time delta, and record the capture as a frozen
  `docs/perf-analysis/<stamp>/` bundle with `/dev-copilot:wow-perf-analysis`. Comparison is valid only against a capture taken the
  same way on the pre-fix build.

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
| Regression | | | |
| Perf (F-003) | | | |
