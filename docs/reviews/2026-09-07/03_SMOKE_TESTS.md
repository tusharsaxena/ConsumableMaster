# 03 — In-client smoke tests

Run **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Everything that runs in a
shell already ran in Step 0 and is recorded in `01_FINDINGS.md`'s measurement block; this document is
only for what needs a login.

## Pre-flight

1. **Headless pre-flight, once, before you log in** — two commands, from the repo root:
   `luacheck .` (expect `0 warnings / 0 errors`) and `lua5.1 tests/run.lua` (expect
   `~752 passed, 0 failed`; it was **749** before this work — C-05 adds three). If either is red,
   stop; nothing below is meaningful.
2. **Client.** Retail only. `ConsumableMaster.toc` pins `## Interface: 120007`; confirm the client
   build matches or the addon will load out-of-date.
3. **Install.** Copy the working tree to `Interface/AddOns/ConsumableMaster/`. Do **not** symlink
   `libs/` — the vendored payload must be the bytes under test.
4. **Make failures visible.** `/console scriptErrors 1`, then `/reload`. Keep the chat frame where
   `[CM]` lines are readable.
5. **Character requirements.** One max-level character with at least one specialization, some
   consumables in bags (a flask, a health potion, a food item — enough that a macro body is non-empty),
   and a weapon equipped so the Weapon Enchant category has something to rank.
6. **CRITICAL for M-01: back up `SavedVariables` first.** Copy
   `WTF/Account/<ACCOUNT>/SavedVariables/ConsumableMaster.lua` somewhere safe. Several checks below
   deliberately hand-edit it, and you will want the original back.

---

## M-01 — C-01: profile-scoped migration

**Change covered:** C-01 — the migration version is split, so a profile that was not active at the
upgrade still migrates. **Findings:** `CM-R-01`.

### M-01a — a stale non-active profile comes forward on switch

**Setup.**

1. Log out fully (the client only flushes SavedVariables on logout).
2. Open `WTF/Account/<ACCOUNT>/SavedVariables/ConsumableMaster.lua` in a text editor.
3. Ensure there are **two** profiles. If there is only one, log in, open `/cm config` → Profiles, create
   a second named `SmokeB`, switch back to the first, log out.
4. In `SmokeB`'s `macroBar` table, hand-edit it into the pre-v3 shape: **delete** any `labelFlags`
   line and **add** `labelOutline = false,`.
5. Confirm `["schemaVersion"] = 3` is present in the **global** section and that `SmokeB` carries no
   `schemaVersion` of its own.
6. Save the file.

**Steps.**

1. Log in on a character using the *other* profile.
2. `/cm config` → **Profiles** → switch to `SmokeB`.
3. `/cm get macroBar.labelFlags`.
4. Log out, and re-open the SavedVariables file.

**Expected.**

- Step 3 prints `[CM] macroBar.labelFlags = ` — i.e. the **empty string**, the stored value the
  "None" outline option names. It must **not** print `OUTLINE`.
- In step 4, `SmokeB` carries `["labelFlags"] = ""`, no `labelOutline` key at all, and its own
  `["schemaVersion"] = 3`.

**Pass / Fail.** PASS if and only if `labelFlags` is the empty string **and** `labelOutline` is gone
**and** `SmokeB.schemaVersion == 3`. Any one of the three missing is a FAIL. (Before this change,
step 3 printed `OUTLINE` and `labelOutline = false` survived in the file — that is the bug.)

### M-01b — an already-current profile is not re-migrated

**Setup.** From M-01a's end state, log out.

**Steps.**

1. In the SavedVariables file, set `SmokeB`'s `macroBar.labelFlags` to `"THICKOUTLINE"`.
2. Log in, switch to `SmokeB`, `/cm get macroBar.labelFlags`.
3. `/reload`, `/cm get macroBar.labelFlags` again.

**Expected.** Both reads print `THICKOUTLINE`.

**Pass / Fail.** PASS if the deliberate setting survives both the switch and the reload. FAIL if
either read comes back `""` or `OUTLINE` — that means a step is running unconditionally rather than
behind the profile version.

### M-01c — a brand-new profile is not damaged

**Steps.**

1. `/cm config` → Profiles → create a new profile `SmokeC`. Switch to it.
2. `/cm get macroBar.labelFlags`, `/cm get macroBar.enabled`.
3. `/reload`, repeat step 2.

**Expected.** `OUTLINE` and `true` both times — the shipped defaults from `defaults/Profile.lua`. No
Lua error, no `[CM] schema error` line.

**Pass / Fail.** PASS if a fresh profile lands on shipped defaults and stays there across a reload.

---

## M-02 — C-02: routed widget strings

**Change covered:** C-02. **Findings:** `CM-R-02`.

**Setup.** Any character with bags containing at least one item in a managed category.

**Steps.**

1. `/cm config` → **Macros**.
2. Read the row at the top of the tab, beside the draggable macro icon.
3. Switch to a category whose macro has never been written (e.g. a category with nothing in bags).
4. Scroll the priority list until a row is still hydrating on first open.
5. Open the **Weapon Enchant** tab and read the hand tags on its rows.

**Expected.** Verbatim, unchanged from before the change:

- Step 2: gold `Drag to action bar`.
- Step 3: grey `Macro not created yet`.
- Step 4: `[Loading]` on an unhydrated row (may need a fast eye — it resolves within a second or two).
- Step 5: `MH`, `OH` or `MH+OH` on the weapon-enchant rows.

**Pass / Fail.** PASS if every string renders **identically to before** and no row shows a bare
key, an empty label or a `nil`. FAIL on any visible text change — the point of C-02 is that nothing
a player sees moves.

---

## M-03 — C-03: one colour decoder

**Change covered:** C-03. **Findings:** `CM-R-05`. **Skip this section entirely if C-03 was
deferred** for the nil-tolerance reason recorded in `02_PROPOSED_CHANGES.md`.

**Setup.** `/cm config` → **Macro Bar** → **Bar appearance**.

**Steps.**

1. Note the current bar background swatch colour.
2. `/cm get macroBar.barBackdropColor` — record the four numbers printed.
3. Set a distinctive colour through the picker: full red, alpha ~0.5.
4. `/cm get macroBar.barBackdropColor` again.
5. `/cm set macroBar.barBackdropColor 0 1 0 0.25`.
6. Re-open the page and read the swatch.
7. Repeat 1-6 for `macroBar.flyoutShadeColor` and `macroBar.labelColor`.

**Expected.**

- Step 2 and step 4 report the same four numbers the swatch is showing, to two decimals.
- After step 5 the swatch is green at quarter alpha, and the bar on screen repaints to match
  immediately.
- The alpha slider is present on every picker (this is the `hasAlpha` default the descriptor
  deliberately overrides — a picker that lost it is a regression, not a colour bug).

**Pass / Fail.** PASS if the panel and `/cm get` agree on every colour, on every one of the three
paths, in both directions. FAIL on any disagreement, or on any picker missing its alpha slider.

---

## M-04 — C-06: `%d` → `%s` in the debug sink

**Change covered:** C-06. **Findings:** `CM-R-07`.

**Steps.**

1. `/cm debug on` — the console opens and the `[Init]` summary line appears.
2. `/cm config` → **Macros** → any category tab (this drives `settings/Category.lua`'s `Prio` paint).
3. Drag a priority row to a new position (this drives both `modules/Selector.lua` `Prio` move lines).
4. Read the three lines in the console.
5. `/cm debug off`.

**Expected.** The console shows lines of the shape `<HH:MM:SS> | [Prio] paint food rows=7 spec=…` and
`[Prio] move food id=… 3 -> 1`, with the numbers rendered exactly as before. No `bad argument #… to
'format'` error, no missing line.

**Pass / Fail.** PASS if all three lines render with their numbers intact and no Lua error fires.

---

## Regression suite

Not tied to any one change — these cover what the proposed changes could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-01 | `/reload` from a fresh login | No Lua error popup; `[CM]` prints nothing unprompted |
| R-02 | First-ever login (SavedVariables deleted) | Defaults populate; `/cm get macroBar.enabled` → `true`; bar appears |
| R-03 | Full login sequence with `/etrace` filtered to `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` | All three fire, no error between them |
| R-04 | Enter combat with the macro bar visible, leave combat | Bar stays visible; no `Interface action failed because of an AddOn`; cooldown swipes still animate on bar buttons **and** on an open flyout |
| R-05 | `/cm config` **during combat** | Grey line: `cannot open settings during combat — Blizzard's category-switch is protected`. Panel does not open, no error |
| R-06 | Profile switch via `/cm config` → Profiles, three times back and forth | Macros rewrite each time; no error; the Macro Bar page reflects the new profile's settings |
| R-07 | Open every settings page and toggle every control on it at least once | No error; no `[CM] schema error` line; every toggle round-trips through `/cm get` |
| R-08 | `/cm resetall` → confirm the popup | Every priority list and stat override back to shipped values; macros rewrite |
| R-09 | `/cm list`, `/cm help`, `/cm version`, `/cm dump` | All answer; `/cm version` matches the TOC's `## Version`, never `?` |
| R-10 | `/cm reset macroBar.perRow` | Resets **one** setting and prints the deprecation line naming `/cm resetall` |
| R-11 | Escape-close the debug console with `/cm config` → Master controls open | The `Debug console` row unchecks itself without being clicked |
| R-12 | About page command list vs `/cm help` | Identical rows, identical em-dash spacing (one formatter, LIBKA0S-13) |

---

## Localization sanity

Required because C-02 touched user-facing strings.

1. Set the client to **deDE** (Battle.net → game settings → language) and restart.
2. Re-run **M-02** in full.
3. **Expected:** the six strings render in **English**, unchanged — this addon ships enUS only and
   `locales/enUS.lua`'s metatable returns the key. What must **not** happen is a blank label, a `nil`,
   or a visibly different string.
4. While in deDE, open a category tab and confirm the priority rows still classify items correctly.
   `core/Classifier.lua` keys on `subClassID` from `GetItemInfoInstant`, never on the localized
   subtype (`core/Classifier.lua:30`), so a deDE client must produce the same categorization as enUS.
   A row that vanishes or lands in the wrong category here is a locale-matching regression.
5. Switch back to enUS and restart.

---

## Performance spot-check

**Not required** — no change in `02_PROPOSED_CHANGES.md` touches a bracketed path, a declared bucket
or an `OnUpdate` handler. Run this only if C-01's migration work is extended in a way that touches the
recompute pipeline.

If it is needed, use the addon's own harness rather than an ad-hoc measurement, following the
two-arm protocol:

1. `/cm perf` opens the step panel. Run the **clean arm first** — the addon live, capture armed —
   with combat windows opened on the player's own combat state.
2. Run the **second arm suspended**, from the same panel. **No `/reload` between arms** (a reload
   shifts shared-frame ownership, which is the confound the harness exists to avoid), and no change
   to the loaded addon set.
3. Read the **bucket figures** — `cooldown` and `recompute` — never the frame-time delta. The delta in
   the one committed capture (`docs/perf-analysis/20260807-132029/dump.json`) is `-0.1082 ms/frame`,
   which is below the harness's own run-to-run spread and therefore unresolved; do not build a claim
   on it.
4. Compare against that capture's `cooldown` bucket: **352 calls, 42.72 ms total, 0.2397 ms max over
   24.0 s active**. Expect `recompute` to record **nothing** — it is an out-of-combat path and the
   window is combat-only, which is the designed behaviour, not a missing bracket.
5. Record the result as a frozen `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` bundle via
   `/wow-addon:perf-analysis`. Never edit an existing bundle.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| M-01a | | | |
| M-01b | | | |
| M-01c | | | |
| M-02 | | | |
| M-03 | | | (skip if C-03 deferred) |
| M-04 | | | |
| R-01 … R-12 | | | |
| Localization (deDE) | | | |
| Perf spot-check | | | (skip unless C-01 grew) |

**SavedVariables restored from the pre-flight backup after M-01?**  ☐
