# Smoke tests

A headless unit-test harness now covers the addon's logic — Classifier, Ranker, Selector, WeaponSlots, ID sentinels, schema validation, MacroManager body builders, the message bus, DebugLog formatters, TooltipCache parsing, SpecHelper resolution, the spec/spell Compat seam, BagScanner, SavedVariables migrations, the recompute pipeline, and the `/cm` slash dispatcher — plus a full-addon TOC-order load check — run it with `lua5.1 tests/run.lua` and lint with `luacheck .` (see [../README.md#testing](../README.md#testing), full case inventory in [test-cases.md](./test-cases.md)). Everything the harness can't reach — event-driven behaviour against Blizzard APIs, frame/UI rendering, taint, action-bar icons — is still validated **manually, in-game**. This file is the canonical playbook for that manual pass.

Two flavours:

- **[Quick smoke](#quick-smoke)** — the 30-second recipe to run after any change. Catches ~80% of regressions.
- **[Full suite](#full-suite)** — twelve sections covering every user-visible surface. Run after structural changes (module rewrite, schema migration, framework swap, pre-release).

Plus a [targeted lookup](#targeted-by-change-area) at the bottom: "I changed X, what do I run?"

## Working environment

- Two clients running side-by-side help: one with stable seeds (compare against), one with your changes.
- Pin the chat frame and enable `/cm debug` early — most regressions surface as a `KCM.Debug` line before they're visible in the macro body.
- Action bar slots: drag every `KCM_*` macro onto a bar before you start so icon changes are observable.
- Target dummies are the cheapest way to enter combat; they're behind every faction's training district.

## Quick smoke

After any change to a scorer / classifier / tooltip pattern / Selector / MacroManager body builder.

1. `/cm resync` — invalidates TooltipCache, re-runs auto-discovery, recomputes every category.
2. `/cm dump pick <catKey>` for the affected category — confirms the priority list, per-entry scores, and the owner-walk pick.
3. Open the macro UI — confirm the `KCM_*` body matches the dump's pick.
4. For UI changes: open the Options panel page and exercise the affected widgets.

If the change touched a spec-aware category, also: switch specs via the talents UI and re-run steps 2 and 3 against the new spec.

## Full suite

Twelve sections, each numbered so you can call out which one failed when reporting a regression. Run end-to-end before releases.

### 1. Cold boot

Tests: AceDB defaults populate, all 13 macros create, no errors at login.

1. **Fresh-install path:** quit the game; delete `WTF/Account/<acct>/SavedVariables/ConsumableMasterDB.lua`; log in.
2. Expect: no Lua errors, no `[CM]` chat warnings beyond the one-shot debug-state line if `debug=true`.
3. Open the macro UI → **General Macros** tab. Expect 13 macros named exactly: `KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`, `KCM_FLASK`, `KCM_CMBT_POT`, `KCM_STAT_FOOD`, `KCM_WPN_ENCH`, `KCM_AUG_RUNE`, `KCM_HP_AIO`, `KCM_MP_AIO`.
4. Each macro's stored icon should be either the picked item's texture (if you own a candidate) or the cooking-pot fallback (`fileID 7704166`). Never the `?` sentinel rendered as a static texture — that's the icon-convention bug.
5. `/cm dump pick food` (and any spec-aware key) — confirms the pipeline ran post-PEW.
6. Re-login (no SavedVariables wipe) — same checks. Existing buckets should be respected; no duplicate macros created.

### 2. Auto-discovery

Tests: bag scan classifies new items, GIIR retry hydrates uncached ones, discovered set persists.

1. Loot or vendor-buy an item the seed doesn't list (e.g. a new-tier flask not yet in `Defaults_Flask.lua`).
2. Within ~1 frame of `BAG_UPDATE_DELAYED`, expect: `/cm dump pick flask` lists the new item with its score.
3. Open the Flask category page; the new item appears in the priority list with the green-check "owned" glyph.
4. Move the item into the bank, log out, log back in. With the item not in bags but discovered within 30 days: it appears in the priority list with the red-X "not owned" glyph.
5. Wait 30+ days (or hand-edit `discovered[id]` to a stale timestamp): on the next PEW, `Selector.SweepStaleDiscovered` removes it. Confirm via `/cm dump pick flask` — entry gone.

### 3. Macro writes — single-pick

Tests: body builders produce correct `/use item:<id>` or `/cast <Spell>`; action bar adopts the picked icon.

1. Drag `KCM_FOOD` onto an action slot. Confirm the bar shows the picked item's texture (not cooking pot).
2. Open the macro UI — body should be `#showtooltip\n/use item:<id>` for an item pick or `#showtooltip\n/cast <Spell>` for a spell entry (e.g. Recuperate as a Food entry on a Rogue).
3. Click the bar slot — the consumable activates (or the spell starts casting).
4. Block the current pick via the priority-list × button. Within ~1 frame, the body re-points at the next-best owned candidate; the action-bar icon updates.
5. Empty the category (delete every owned candidate, block the rest): body switches to `/run print('|cff00ffff[CM]|r no <category> in bags')` with the cooking-pot icon.

### 3a. Macro writes — Weapon Enchant (per-hand, weapon-type aware)

Tests: `KCM_WPN_ENCH` picks and applies independently per hand, filtered by the equipped weapon's bladed/blunt/any affinity; recomputes on weapon swap without a reload.

1. Equip a bladed weapon (e.g. a sword) in the main hand. Confirm `/cm dump pick wpn_ench` shows a whetstone (bladed) as the main-hand pick; a weightstone (blunt) candidate is present in the dump but excluded from the pick. On the **Weapon Enchant** settings page, the whetstone row shows the yellow star + an "MH" affinity marker, and weightstone rows are dimmed as not-applicable to the current main hand.
2. Swap to a blunt weapon (e.g. a mace) in the same slot. Within ~1 frame of `PLAYER_EQUIPMENT_CHANGED`, expect: no `/reload` needed — the macro body switches to the weightstone, the action-bar icon updates, and the settings page's star/dim markers flip to match.
3. Dual-wield two weapons of different types (e.g. sword main hand, mace off hand). Confirm the macro body applies a whetstone to slot 16 and a weightstone to slot 17 (a `/use item:<id>` + `/use 16` line pair, then a `/use item:<id>` + `/use 17` pair), i.e. each hand gets its own independently-scored pick. The settings page marks the whetstone row "MH" and the weightstone row "OH" (not both on one row).
4. Equip a two-handed weapon (main hand only, no off-hand item). Confirm the macro body only references slot 16 — no `/use 17` line — and the settings page shows only an "MH" marker on the picked row, with no off-hand affinity shown.

### 3b. Macro writes — Augment Rune

Tests: `KCM_AUG_RUNE` body is a plain single-pick `/use`; reusable "permanent" runes only win a tie, never beat a stat-superior consumable rune.

1. Put a single augment rune in bags (any of the seeded IDs). Open the macro UI — body should be `#showtooltip` + `/use item:<id>`, matching the single-pick pattern of section 3.
2. `/cm dump pick aug_rune` — the priority order must be by primary-stat amount, highest first (e.g. Void-Touched 25 above Ethereal 6 above Dreambound 5). A reusable rune outranks a consumable one only when their amounts are equal.
3. Block the top rune via the priority-list × button on the **Augment Rune** settings page. Within ~1 frame, the pick falls back to the next-highest.
4. **Auto-discovery:** `/cm dump item 259085` — `classified:` must list `AUG_RUNE` (the marker is parsed from the inline "…Augment Rune." sentence on the Use line). A rune NOT in the seed, once in bags, should likewise self-add via discovery.
5. **Login freshness (regression — the partial-tooltip race):** log in with augment runes in bags and open the Augment Rune page *immediately*, before tooltips fully hydrate. The order must self-correct to amount-first within a moment, with **no** `/cm resync` needed. `/cm dump item <id>` should show `statBuffs` populated once loaded, never a stale empty parse.

### 3c. Classification by numeric item class (localization-§4 / #37)

Tests: the Classifier (`core/Classifier.lua`) and weapon-affinity (`core/WeaponSlots.lua`) key on the locale-independent numeric `classID`/`subClassID`, never the localized `subType` display string. `/cm dump item <id>` shows both on its `instant:` line.

1. **Mechanism — the number drives it.** For a few owned consumables, run `/cm dump item <id>` and confirm the `instant:` `classID`/`subClassID` and the `classified:` line agree:
   - healing potion → `classID=0 subClassID=1` → `HP_POT`
   - mana potion → `classID=0 subClassID=1` → `MP_POT`
   - stat food → `classID=0 subClassID=5` → `STAT_FOOD`; plain food → `subClassID=5` → `FOOD`/`DRINK`
   - flask/phial → `classID=0 subClassID=3` → `FLASK`
2. **No English regression.** With food + a potion + a flask in bags, `/cm resync`, then `/cm dump pick hp_pot` / `flask` / `stat_food` — each picks the expected item and the `KCM_*` bodies target them, identical to before the change.
3. **Weapon affinity by subclass.** Swap main-hand weapons and check the Weapon Enchant page (or `/cm dump pick wpn_ench`): sword/dagger/axe/polearm/fist/warglaive → bladed (whetstone); mace/staff → blunt (weightstone); bow/gun/wand → no pick.
4. **classID-gate guard — a Shield must not read as a Polearm.** Equip a **shield** in the off-hand: the off-hand shows **no** weapon enchant, and `/cm dump item <shieldID>` shows `classID=4 subClassID=6` with `classified: (none)`. (Shield = Armor subclass 6; Polearm = Weapon subclass 6 — same number, different class; the class gate keeps them apart.)
5. **Definitive locale test (needs a non-English client).** On a deDE/frFR/etc. client (language pack on PTR/beta, or a non-English account), reload with the same consumables in bags. `/cm dump item <id>` shows a **localized** `subType` (e.g. `"Tränke"`) but `classified:` must still be correct and the `KCM_*` macros must populate. *Before* this change every consumable classified as `(none)` and the macros sat empty on that client. If a non-English client isn't available, the headless suite already proves it (`classifier: keys on numeric subclass, not the localized subType` + the WeaponSlots equivalent), so steps 1–4 on English are sufficient sign-off.

### 4. Macro writes — composite (HP_AIO / MP_AIO)

Tests: `/castsequence [combat]` for in-combat, `/use [nocombat]` chain for out-of-combat, asymmetric-empty fallback.

1. Open the **AIO Health** page. Confirm In Combat lists `HS` and `HP_POT` (in that order by default), Out of Combat lists `FOOD`.
2. Drag `KCM_HP_AIO` onto a bar. Out of combat, hovering the bar slot should show the FOOD pick's tooltip.
3. `/cm dump pick hp_aio` — confirms the resolved per-section picks and the assembled body.
4. Macro body should look like:
   ```
   #showtooltip
   /castsequence [combat] reset=combat item:<HS>, item:<HP_POT>
   /use [nocombat] item:<FOOD>
   ```
5. Toggle off `HS` in the AIO panel. Body re-issues with only `HP_POT` in the in-combat castsequence.
6. Toggle off everything in Out of Combat. Body emits a `/run if not InCombatLockdown() then print(...) end` fallback line for the empty side. (`/run` doesn't accept `[nocombat]` — confirms the addon uses the Lua-conditional gate.)
7. Toggle off everything everywhere — body falls through to the empty-state stub with cooking-pot icon.

### 5. Spec changes

Tests: spec-aware macros update on `PLAYER_SPECIALIZATION_CHANGED`, score cache invalidates per pass.

1. Open `KCM_FLASK` body, note the picked flask.
2. Switch specs via the talents UI (loadout selector or the spec dropdown).
3. Within ~1 frame, expect: `KCM_FLASK` / `KCM_CMBT_POT` / `KCM_STAT_FOOD` / `KCM_WPN_ENCH` bodies update against the new spec's stat priority. Non-spec-aware macros (`KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`) stay unchanged.
4. Open the **Stat Priority** panel; viewing-spec dropdown shows the new spec's icon + name. Primary + secondary fields populate from the override / seed / class fallback in that order.
5. `/cm dump pick flask` — score breakdown should weight stats per the new spec's priority.

### 6. Combat deferral

Tests: macro writes that hit combat queue, flush on regen, retry counter respects the bound.

1. Pull a target dummy. Loot a stack of new-tier potions during combat (or use a pre-staged trade with a buddy).
2. `BAG_UPDATE_DELAYED` fires in combat → Pipeline.Recompute runs (pure modules) → MacroManager.SetMacro detects `InCombatLockdown()` and queues in `pendingUpdates`.
3. `/cm dump pick hp_pot` while still in combat: shows the pending pick.
4. Drop combat. On `PLAYER_REGEN_ENABLED`: queued macro writes flush. Body updates, action bar adopts new icon.
5. Edge case — re-enter combat before flush completes: `pendingUpdates` should preserve the entry as `"deferred"` rather than incrementing `attempts`.
6. Synthetic failure path: hand-poison `pendingUpdates[macroName].attempts = 2` then trigger a recompute that re-queues. After regen, the third flush attempt prints the one-shot `[CM] gave up on <name>` warning.

### 7. Settings panel — landing + General page

Tests: `/cm config` lands on About with sub-pages expanded; General-page checkboxes write through schema; resets fire StaticPopup.

1. Close the Settings panel. Run `/cm config`.
2. Expect: lands on the **Ka0s Consumable Master** parent page (logo + tagline + slash help). Left sidebar has the parent expanded with all 15 sub-pages visible (General, Stat Priority, 11 categories, 2 AIO).
3. Manually collapse the parent in the sidebar. Run `/cm config` again. Sidebar re-expands.
4. Open General. Layout: section "General" with paired `[Enable] | [Debug]`; section "Maintenance" with row 1 `[Force resync | Force rewrite]`, row 2 `[Reset all priorities]` full-width. A top-right **Defaults** button sits in the page header.
5. Toggle Enable off — `[CM] Master enable OFF` prints. `/cm dump pick food` shows the `Pipeline.Recompute skipped writes (disabled)` debug line if debug is on. The panel still refreshes (so `[Loading]` rows hydrate) but no macro is rewritten.
6. Toggle Enable on — `[CM] Master enable ON` prints. A recompute kicks immediately; macros refresh against current state.
7. Toggle Debug — colour-coded ack `[CM] debug logging ON` (green) / `OFF` (red), plus a `[Debug] logging enabled/disabled` line in the console; on enable, an `[Init]` session summary line (addon + version, schema, profile) follows the bracket. Tagged debug console lines start / stop appearing.
8. Click **Force resync** — TooltipCache invalidates, auto-discovery re-runs, pipeline recomputes. Blocked in combat with a chat notice.
9. Click **Force rewrite macros** — every `KCM_*` body + icon re-issued unconditionally. Useful when an action-bar framework is showing a stale texture.
10. Click **Reset all priorities** — StaticPopup confirms; on Yes, the entire `categories` + `statPriority` tree wipes back to seed defaults and the master enable flips back on. Items currently in bags are re-discovered (so `discovered[id]` for bag items survives); previously-discovered items no longer in bags are dropped. Blocked in combat with a chat notice.
11. Disable the addon (Enable off), then click the top-right **Defaults** button. It resets **this page only**: master enable flips back on (`[CM] Master enable ON`) and the debug console switches off. Category and stat-priority customizations are left untouched (verify a custom added item survives). Blocked in combat with a chat notice.

### 7a. Settings panel — refresh performance + Defaults button styling

Tests: a mutation refreshes without stalling; off-screen pages update lazily on next show; the Defaults button uses the standard AceGUI look. Guards options-ui-§5 / §11 and anti-pattern #39.

Setup: `/cm config`, then visit **General → two category pages → Stat Priority** so several sub-pages are rendered (the freeze only showed once multiple pages had been built).

1. **No freeze (options-ui-§11 / anti-pattern #39).** On General, toggle **Enable**, toggle **Debug console**, click **Force resync** — each responds **instantly**, no ~0.5s stall. Repeat on a category page and Stat Priority. Regression check: the old bug rebuilt *every* rendered sub-page's full renderer on each mutation; the fix rebuilds only the on-screen panel (`ctx.panel:IsShown()`) and defers the rest. (**Force rewrite macros** / **Reset all priorities** may still have a brief hitch — that's the synchronous macro rewrite, not the panel-refresh freeze.)
2. **Lazy off-screen refresh stays correct.** While viewing General, run `/cm priority flask add 212283` (any valid flask ID). Navigate to the **Flask** category page — the new entry is present (the hidden page was flagged dirty and rebuilt on show), with no stale state and no Lua error.
3. **Defaults button styling (options-ui-§5).** On every page that has one (General, Stat Priority, each category, AIO), the top-right **Defaults** button renders **dark with gold text** like the Absorb Tracker / KickCD panels — **not** red. It is an AceGUI `Button` (not a raw canvas-parented `UIPanelButtonTemplate`, which inherits the canvas red skin). Click it and confirm the page reset still fires (functionality preserved through the widget swap).

### 7b. Debug console — scrollbar + line counter

Tests: the on-screen debug console carries a working right-edge scrollbar and a bottom line counter (debug-logging-§11 / anti-pattern #41). Both are a **MUST**.

Setup: `/reload`, then `/cm debug on` (arms capture) and `/cm debug` (opens the console). Trigger some activity — e.g. `/cm resync` a few times, open/close bags — so the log fills past one screen.

1. **No first-open error (anti-pattern #41).** The very first time the console opens, there is **no** `attempt to call a nil value` Lua error, the title-bar **`Debug: ON/OFF`** header label renders (green ON / red OFF), and **Esc closes** the window — proof the initial scroll sync ran last and didn't abort the build. Regression trap: driving the log with the old C getters `GetNumLinesDisplayed()` / `GetCurrentScroll()` (nil on retail's Lua `ScrollingMessageFrameMixin`) throws here.
2. **Line counter.** The bottom-right label reads **`N / 500 lines`** and **N climbs on every appended line**. Click **Clear** — the log empties and the counter resets to **`0 / 500 lines`**.
3. **Scrollbar — always shown, inert when it fits.** With only a few lines (log not full), the thin right-edge scrollbar is **visible** but **inert** (thumb parked, no drag). Fill the log past one screen — the bar becomes **active**.
4. **Two-way sync.** Mouse-wheel up/down over the log — the **thumb tracks** the scroll. Drag the **thumb** — the **log scrolls** to match. No flicker or runaway loop (the `_syncing` guard).
5. **Thumb direction (the one thing to eyeball).** Thumb at **top = oldest** lines, thumb at **bottom = newest**. If it reads inverted, the `sliderValue ↔ offset` sign is flipped.

### 8. Settings panel — Stat Priority

Tests: spec selector drives the spec-aware editor and the spec-aware category pages; reset drops the override.

1. Open Stat Priority. Selection section shows a full-width spec dropdown with class+spec icon markup. Sorted alphabetically by class name with markup stripped.
2. Pick a different spec from the one you're playing. The Primary + Secondary 1–4 fields refresh against that spec's priority.
3. Open the **Flask** page (spec-aware) — the subheader reads "Spec-aware. Viewing: <picked spec>." The priority list reflects the picked spec.
4. Back on Stat Priority — change Primary stat. The field commits immediately; `/cm stat list` confirms the new value.
5. Change Secondary #2 to `(none)` — the persisted secondary list compacts (the empty slot is dropped, not stored as `""`).
6. Click **Reset stat priority** — drops the override for the viewed spec. Subsequent reads fall back to seed default → class-primary fallback. The top-right **Defaults** button does the same for the viewed spec.

### 9. Settings panel — per-category (single)

Tests: drag icon, Add by ID (item + spell), priority list (up / down / X), score tooltip.

1. Open any single-category page (e.g. **Healing Potion**).
2. Drag the macro icon at the top onto an action bar. Confirm placement worked (Blizzard PickupMacro path — taint-free).
3. Add by ID — Type=Item, paste an item ID you don't own (e.g. an old-tier potion). Press Enter. The row appears in the priority list with the red-X "not owned" glyph.
4. Add by ID — Type=Spell, paste a spell ID (e.g. `1231411` for Recuperate, only valid on Rogues). Press Enter. The row appears with the spell name and icon. On a non-Rogue: validation rejects with `[CM] unknown spellID`.
5. Submit an invalid ID (e.g. `99999999`). Validation rejects; the typed text persists in the EditBox so you can correct without re-typing.
6. Move a row up / down — pinning takes effect immediately; the macro body updates if the move changes the owned-item walk.
7. Click the blue info button — tooltip shows the per-item score breakdown from `Ranker.Explain`. Numbers should match `/cm dump pick <cat>` exactly.
8. Click X on a row — item removed from priority list AND added to the blocked set (auto-discovery won't re-add).
9. Click **Reset category** — StaticPopup confirms; on Yes, that category's added / blocked / pins wipe. Discovered items preserved. The top-right **Defaults** button opens the same confirmation.
10. For spec-aware categories (FLASK, CMBT_POT, STAT_FOOD, WPN_ENCH): all of the above but verify the bucket is the viewed spec's, not the player's current spec.

### 10. Settings panel — composite (HP_AIO / MP_AIO)

Tests: section-locked sub-cats, enabled toggle, reorder within section.

1. Open **AIO Health**.
2. Confirm In Combat shows HS + HP_POT (in that order by default), Out of Combat shows FOOD. Each row is `KCMItemRow + Enabled checkbox + ↑ + ↓` — no remove button (sub-cats are locked).
3. Toggle Enabled off on a row — recompute fires, body excludes that sub-cat.
4. Move HP_POT above HS in In Combat — castsequence rewrites in the new order.
5. Try to drag a Food sub-cat into In Combat — there's no UI for it; sections are locked. Confirm by inspecting `db.profile.categories.HP_AIO.orderInCombat` after manipulation.
6. Click **Reset category** — restores enabled flags + section orders to dbDefaults. The top-right **Defaults** button opens the same confirmation.

### 11. Slash CLI

Tests: every verb in `COMMANDS`, `DUMP_TARGETS`, `*_COMMANDS` works.

1. `/cm` (no args) — help table. Every entry should be in the `COMMANDS` ordered list.
2. `/cm help` — same as above.
3. `/cm config` — opens panel (covered in section 7).
4. `/cm version` — prints the version.
5. `/cm debug` — toggles debug; UI checkbox flips to match.
6. `/cm resync` / `/cm rewritemacros` / `/cm reset` — covered in section 7.
7. `/cm list` — schema rows grouped by panel. Today: `enabled` and `debug` under `[general]`.
8. `/cm get enabled` / `/cm get debug` — single-row read.
9. `/cm set enabled false` — toggles off via CLI; UI checkbox flips. Type validation: `/cm set enabled banana` should reject with "expected true/false/on/off/1/0".
10. `/cm priority hp_pot list` — prints the effective priority for HP_POT.
11. `/cm priority hp_pot add 12345` — adds itemID 12345 (rejects unknown). `/cm priority hp_pot remove 12345` — removes (and blocks). `/cm priority hp_pot up 12345` / `down` — reorders. `/cm priority hp_pot reset` — wipes added/blocked/pins for the category.
12. `/cm priority flask list s:1234` — spell sentinel via `s:<spellID>`. Confirms the opaque-numeric ID round-trips through the slash layer.
13. `/cm stat list` — current spec. `/cm stat primary AGI` — sets primary. `/cm stat secondary CRIT,HASTE,MASTERY,VERSATILITY` — replaces the secondary list. `/cm stat reset` — drops override. `/cm stat list 7_264` — explicit spec key. `/cm stat list SHAMAN:ENHANCEMENT` — friendly form.
14. `/cm aio hp_aio list` — assembled order. `/cm aio hp_aio toggle hs` — flip enabled. `/cm aio hp_aio up hp_pot` — within-section reorder. `/cm aio hp_aio reset` — restores defaults.
15. `/cm dump categories` — prints the category list with macro names + spec-awareness.
16. `/cm dump statpriority` — current spec's primary + secondary.
17. `/cm dump bags` — bag scanner output.
18. `/cm dump item 12345` — parsed tooltip + raw lines.
19. `/cm dump pick <catKey>` — covered above. Composite keys (`hp_aio`, `mp_aio`) print the assembled body.

### 12. Edge cases

Tests: oversized body fallback, locked-bag-item stability, empty-state coverage, master-enable persistence.

1. **Oversized body:** force a category's pick to produce a >255-byte body. Easiest path: add a spell with a very long English name (or hand-edit `Defaults_*.lua` to a synthetic test ID resolving to a long name). Expected: macro falls back to empty-state stub; one-shot chat warning naming the category.
2. **Locked items:** equip a locked-state-prone consumable (food being mailed, item being sold). `BagScanner.Scan` counts it; macro should NOT flap.
3. **Renaming a `KCM_*` macro:** rename `KCM_FOOD` to `MyFood` in the macro UI. On next recompute, the addon creates a fresh `KCM_FOOD` in a free slot and leaves `MyFood` alone (CLAUDE.md hard rule — addon never deletes).
4. **Account macro pool full (120):** create 120 user macros. Confirm `KCM_*` creation fails gracefully — `doEdit` returns `"error"`, existing macros still update.
5. **Master enable round-trip:** toggle Enable off → close client → log back in. State persists (`db.profile.enabled = false`). Pipeline.Recompute remains a no-op until toggled on.
6. **`/reload` mid-pending:** queue a combat-deferred macro write, then `/reload` before regen. The pending entry is lost (no SavedVariables for `pendingUpdates`); next event triggers a fresh recompute that re-queues if still in combat.

## Targeted by change area

| Change area | Run sections |
|-------------|--------------|
| Classifier item-class / tooltip matching | Quick smoke + §2 (auto-discovery) + §3c |
| Localization / class-based classification (`classID`/`subClassID`) | §3c |
| Ranker scorer | Quick smoke + §9 (score tooltip) |
| TooltipCache PATTERNS | Quick smoke; verify `/cm dump item <id>` parses fields |
| BagScanner | §2 |
| Selector mutators | §9 (priority list buttons), §11 (`/cm priority`) |
| MacroManager body builders | §3, §4 |
| Weapon Enchant (`core/WeaponSlots.lua`, per-hand pick) | §3a, §3c step 4, §9 step 10 |
| Augment Rune (`isAugmentRune` marker, reusable tiebreak) | §3b, §9 |
| Pipeline / events | §1 (boot), §5 (spec change), §6 (combat) |
| Schema rows | §7 (toggle in panel), §11 (`/cm list`/`get`/`set`) |
| Settings UI framework (`settings/Panel.lua`) | §7 + §7a + spot-check §8, §9, §10 |
| Panel refresh perf / Defaults button styling (options-ui-§5/§11, #39) | §7a |
| Per-tab settings module | the corresponding section (7 / 8 / 9 / 10) |
| Slash command (new verb) | §11 |
| Composite category change | §4 + §10 |
| Auto-discovery GC | §2 step 4–5 |
| Action-bar icon convention | §3 step 1, §4 step 2 |
| Combat-deferral retry / flush | §6 |
| AceDB schema migration | full §1 (cold boot) on a fresh-install path |
| Doc-only changes | nothing — docs don't ship to the client |

If you change something not on this list, walk the full suite. The targeted lookup is a shortcut, not a substitute for understanding the blast radius of your change.
