# Weapon-aware Per-hand Weapon Enchant — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Score weapon enchants by Attack Power / Spell Power role, pick the best *applicable* enhancement independently per equipped weapon (main + off hand), build a per-slot macro, and recompute on weapon swaps.

**Architecture:** `WPN_ENCH` becomes a third special path in `Pipeline.RecomputeOne` (a new `perHand` category flag, mirroring the existing `composite` branch). A new `core/WeaponSlots.lua` owns equipment inspection; `TooltipCache` gains AP/SP stats + a `weaponAffinity` flag; `Ranker` weights AP/SP by spec role; `Selector.PickBestForSlot` filters by weapon compatibility; `MacroManager.SetWeaponEnchantMacro` builds the per-slot body via a factored `commitMacro` tail. Nothing about the other 11 categories changes.

**Tech Stack:** Lua 5.1, Ace3, headless harness (`tests/run.lua`), luacheck.

## Global Constraints

- **Lua 5.1 / Ace3 / English-only** tooltip + subtype matching (existing convention).
- **Green gate before every commit:** `lua5.1 tests/run.lua` all pass AND `luacheck .` 0 errors.
- **Static-badge Hard rule:** when the suite changes, regenerate `docs/test-cases.md` (`lua5.1 tests/run.lua --list > docs/test-cases.md`) and bump the README `[Tests]` badge count in the same change.
- **Never bump the addon version** (no `KCM.VERSION` / TOC Version / README version-history / `[WoW]` badge).
- **Git:** incremental commits are authorized for this session. The controller commits each task **after it passes review** (implementers leave work in the working tree; do NOT run `git add`/`commit` yourself). Stay on `master`.
- **AP weighting:** Attack Power = primary-throughput weight (`PRIMARY_WEIGHT`) for STR/AGI specs, 0 for INT; Spell Power = `PRIMARY_WEIGHT` for INT specs, 0 otherwise.
- **Weapon-affinity map:** bladed = One-/Two-Handed Swords, One-/Two-Handed Axes, Daggers, Polearms, Fist Weapons, Warglaives; blunt = One-/Two-Handed Maces, Staves; everything else (Wands, Bows, Crossbows, Guns, Shields, Held In Off-hand, empty) = not enhanceable.
- The headless runner has no per-case filter: "run the test" = `lua5.1 tests/run.lua` and read the `PASS`/`FAIL` line for the named case.

---

### Task 1: Score Attack Power / Spell Power by spec role

**Files:**
- Modify: `core/TooltipCache.lua` (STAT_TOKENS)
- Modify: `modules/Ranker.lua` (`statWeight`)
- Test: `tests/test_tooltipcache.lua`, `tests/test_ranker.lua`

**Interfaces:**
- Produces: tooltip `statBuffs` entries with `stat="AP"` / `stat="SP"`; `Ranker.statWeight("AP"/"SP", specPriority)` returns `PRIMARY_WEIGHT` or `0` by role.

- [ ] **Step 1: Write failing tests** — append to `tests/test_tooltipcache.lua`:

```lua
test("TooltipCache: parses Attack Power and Spell Power as AP/SP stats", function(t)
    local TC, mock = newTC()
    local stone = parse(TC, mock, 237370, {
        "Refulgent Whetstone",
        "Use: Sharpens your bladed weapon, increasing Attack Power by 10 for 2 hours.",
    })
    t.eq(#stone.statBuffs, 1, "one stat buff parsed")
    t.eq(stone.statBuffs[1].stat, "AP", "Attack Power -> AP")
    t.eq(stone.statBuffs[1].amount, 10, "AP amount")

    local sp = parse(TC, mock, 999001, { "X", "Use: increasing Spell Power by 42 for 1 hour." })
    t.eq(sp.statBuffs[1].stat, "SP", "Spell Power -> SP")
    t.eq(sp.statBuffs[1].amount, 42, "SP amount")
end)
```

Append to `tests/test_ranker.lua`:

```lua
test("Ranker: AP weights as primary for STR/AGI specs, 0 for INT; SP mirrors", function(t)
    local KCM = h.loader.loadPure()
    local W = KCM.Ranker._statWeight
    t.eq(W("AP", { primary = "STR" }), 1000, "AP -> primary for STR")
    t.eq(W("AP", { primary = "AGI" }), 1000, "AP -> primary for AGI")
    t.eq(W("AP", { primary = "INT" }), 0, "AP -> 0 for INT")
    t.eq(W("SP", { primary = "INT" }), 1000, "SP -> primary for INT")
    t.eq(W("SP", { primary = "STR" }), 0, "SP -> 0 for STR")
end)
```

- [ ] **Step 2: Run — expect FAIL**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "AP and Spell Power|AP weights as primary"`
Expected: both FAIL.

- [ ] **Step 3a:** In `core/TooltipCache.lua`, add to `STAT_TOKENS` (after the `Critical Strike` entry, keeping multi-word tokens early):

```lua
    { token = "Attack Power",    tag = "AP"          },
    { token = "Spell Power",     tag = "SP"          },
```

- [ ] **Step 3b:** In `modules/Ranker.lua` `statWeight`, immediately after `if not stat or not specPriority then return 0 end` add:

```lua
    local p = specPriority.primary
    if stat == "AP" then return (p == "STR" or p == "AGI") and PRIMARY_WEIGHT or 0 end
    if stat == "SP" then return (p == "INT") and PRIMARY_WEIGHT or 0 end
```

- [ ] **Step 4: Run — expect PASS** (`lua5.1 tests/run.lua 2>&1 | grep -E "AP and Spell Power|AP weights as primary"`)
- [ ] **Step 5: Gate** — `lua5.1 tests/run.lua && luacheck .` (green)
- [ ] **Step 6:** Report DONE; controller reviews + commits.

---

### Task 2: Weapon affinity — tooltip flag + equipped-weapon module

**Files:**
- Modify: `core/TooltipCache.lua` (`weaponAffinity`)
- Create: `core/WeaponSlots.lua`
- Modify: `ConsumableMaster.toc` (load `core\WeaponSlots.lua` after `core\TooltipCache.lua`)
- Modify: `tests/wow_mock.lua` (equipment stub), `tests/loader.lua` (PURE_LAYER)
- Test: `tests/test_tooltipcache.lua`, `tests/test_weaponslots.lua` (new)

**Interfaces:**
- Produces: `tt.weaponAffinity` ∈ {"bladed","blunt","any"}; `KCM.WeaponSlots.SlotAffinity(slot)` → "bladed"|"blunt"|nil; mock `M.setEquipped(slot, itemID)`.

- [ ] **Step 1: Write failing tests.** Append to `tests/test_tooltipcache.lua`:

```lua
test("TooltipCache: weaponAffinity from bladed/blunt/plain phrasing", function(t)
    local TC, mock = newTC()
    local wh = parse(TC, mock, 237370, { "W", "Use: Sharpens your bladed weapon, increasing Attack Power by 10 for 2 hours." })
    t.eq(wh.weaponAffinity, "bladed", "bladed -> bladed")
    local we = parse(TC, mock, 237369, { "W", "Use: Balances your blunt weapon, increasing Attack Power by 15 for 2 hours." })
    t.eq(we.weaponAffinity, "blunt", "blunt -> blunt")
    local oil = parse(TC, mock, 243733, { "O", "Use: Coat your weapon in oil, increasing your Critical Strike and Haste by 13 for 120 min." })
    t.eq(oil.weaponAffinity, "any", "plain 'your weapon' -> any")
end)
```

Create `tests/test_weaponslots.lua`:

```lua
-- tests/test_weaponslots.lua — equipped-weapon affinity mapping.

local h = require("harness")
local test = h.test

test("WeaponSlots: maps equipped weapon subtype to bladed/blunt/nil", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local W    = KCM.WeaponSlots

    mock.setItem(5001, { subType = "Two-Handed Swords" })
    mock.setEquipped(16, 5001)
    t.eq(W.SlotAffinity(16), "bladed", "2H sword -> bladed")

    mock.setItem(5002, { subType = "One-Handed Maces" })
    mock.setEquipped(17, 5002)
    t.eq(W.SlotAffinity(17), "blunt", "1H mace -> blunt")

    mock.setItem(5003, { subType = "Shields" })
    mock.setEquipped(17, 5003)
    t.eq(W.SlotAffinity(17), nil, "shield -> nil (not enhanceable)")

    mock.setEquipped(16, nil)
    t.eq(W.SlotAffinity(16), nil, "empty slot -> nil")
end)
```

- [ ] **Step 2: Run — expect FAIL** (`WeaponSlots` nil; affinity nil).

- [ ] **Step 3a:** In `core/TooltipCache.lua` `parseLines`, replace the `isWeaponEnhance` line with affinity-capturing logic:

```lua
            local wmid = txt:lower():match("your ([%a%s%-]-)weapon")
            if wmid then
                result.isWeaponEnhance = true
                if wmid:find("bladed", 1, true) then result.weaponAffinity = "bladed"
                elseif wmid:find("blunt", 1, true) then result.weaponAffinity = "blunt"
                elseif not result.weaponAffinity then result.weaponAffinity = "any" end
            end
```

Remove the now-unused `weaponEnhance` PATTERN entry (the inline `match` replaces it) and update the entry-fields doc comment to add `weaponAffinity`.

- [ ] **Step 3b:** Create `core/WeaponSlots.lua`:

```lua
-- core/WeaponSlots.lua — equipped-weapon affinity for the Weapon Enchant
-- category. Maps the main-hand (16) / off-hand (17) weapon's English subType to
-- "bladed" (whetstone) / "blunt" (weightstone) / nil (not enhanceable). English
-- subtype strings per project scope; update the maps if Blizzard renames them.

local _, NS = ...
local KCM = NS
KCM.WeaponSlots = KCM.WeaponSlots or {}
local W = KCM.WeaponSlots

local BLADED = {
    ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true,
    ["One-Handed Axes"]   = true, ["Two-Handed Axes"]   = true,
    ["Daggers"]           = true, ["Polearms"]          = true,
    ["Fist Weapons"]      = true, ["Warglaives"]        = true,
}
local BLUNT = {
    ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
    ["Staves"]           = true,
}

-- slot: 16 (main hand) or 17 (off hand). Returns "bladed" | "blunt" | nil.
function W.SlotAffinity(slot)
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not itemID then return nil end
    local subType
    if C_Item and C_Item.GetItemInfoInstant then
        local _; _, _, subType = C_Item.GetItemInfoInstant(itemID)
    else
        local _; _, _, _, _, _, _, subType = GetItemInfo(itemID)
    end
    if not subType then return nil end
    if BLADED[subType] then return "bladed" end
    if BLUNT[subType]  then return "blunt"  end
    return nil
end
```

- [ ] **Step 3c:** In `tests/wow_mock.lua`, add an equipment table + stub. Near the other `M.` state add `M.equipped = {}`, reset it wherever `M.bags`/items reset, add `function M.setEquipped(slot, id) M.equipped[slot] = id end`, and in the env table add `GetInventoryItemID = function(_, slot) return M.equipped[slot] end,`.

- [ ] **Step 3d:** In `ConsumableMaster.toc`, add `core\WeaponSlots.lua` immediately after `core\TooltipCache.lua`. In `tests/loader.lua` add `"core/WeaponSlots.lua"` to `PURE_LAYER` immediately after `"core/TooltipCache.lua"`.

- [ ] **Step 4: Run — expect PASS.** **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 3: Per-slot pick (`Selector.PickBestForSlot`)

**Files:**
- Modify: `modules/Selector.lua`
- Test: `tests/test_selector.lua`

**Interfaces:**
- Consumes: `WeaponSlots.SlotAffinity`, `TooltipCache.Get().weaponAffinity`, `GetEffectivePriority`.
- Produces: `Selector.PickBestForSlot(catKey, slot, scoreCache)` → itemID | nil.

- [ ] **Step 1: Write failing test.** Append to `tests/test_selector.lua`:

```lua
test("Selector: PickBestForSlot filters by weapon affinity + ownership", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector

    -- Candidates: a bladed whetstone, a blunt weightstone, an any oil.
    mock.setItem(6001, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    mock.setItem(6002, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "blunt",  statBuffs = { { stat = "AP", amount = 15 } } } })
    mock.setItem(6003, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "any",    statBuffs = { { stat = "CRIT", amount = 9 } } } })
    for _, id in ipairs({ 6001, 6002, 6003 }) do S.AddItem("WPN_ENCH", id) end
    mock.setBag(6001, 1); mock.setBag(6002, 1); mock.setBag(6003, 1)

    -- Main hand is a sword (bladed): whetstone or oil eligible, weightstone not.
    mock.setItem(6100, { subType = "Two-Handed Swords" }); mock.setEquipped(16, 6100)
    local mh = S.PickBestForSlot("WPN_ENCH", 16, nil)
    t.truthy(mh == 6001 or mh == 6003, "bladed slot picks whetstone or oil, never the weightstone")
    t.ne(mh, 6002, "weightstone not eligible on a bladed weapon")

    -- Empty off-hand -> nil.
    mock.setEquipped(17, nil)
    t.eq(S.PickBestForSlot("WPN_ENCH", 17, nil), nil, "no weapon in slot -> nil")
end)
```

> Note: `AddItem` for the spec-aware `WPN_ENCH` uses the current mock spec; if the mock has no active spec, set one as the other spec-aware Selector tests do, or assert via `GetEffectivePriority`. Follow the existing spec-aware test setup in this file.

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3:** In `modules/Selector.lua`, after `PickBestForCategory`, add:

```lua
-- Best owned enhancement for one weapon slot (16 main / 17 off). Filters the
-- effective priority list to enhancements whose weaponAffinity matches the
-- equipped weapon ("any" always matches); returns nil when the slot holds no
-- enhanceable weapon or the player owns no eligible enhancement.
function S.PickBestForSlot(catKey, slot, scoreCache)
    local affinity = KCM.WeaponSlots and KCM.WeaponSlots.SlotAffinity(slot)
    if not affinity then return nil end
    local hasItem = KCM.BagScanner and KCM.BagScanner.HasItem
    for _, id in ipairs(S.GetEffectivePriority(catKey, nil, scoreCache)) do
        if not (KCM.ID and KCM.ID.IsSpell(id)) then
            local tt  = KCM.TooltipCache and KCM.TooltipCache.Get(id)
            local aff = (tt and tt.weaponAffinity) or "any"
            if (aff == "any" or aff == affinity) and hasItem and hasItem(id) then
                return id
            end
        end
    end
    return nil
end
```

- [ ] **Step 4: Run — expect PASS.** **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 4: Per-hand macro body (`MacroManager`)

**Files:**
- Modify: `modules/MacroManager.lua`
- Test: `tests/test_macromanager.lua`

**Interfaces:**
- Produces: `MacroManager.SetWeaponEnchantMacro(cat, mhPick, ohPick)`; internal `buildWeaponEnchantBody(mh, oh)`.

- [ ] **Step 1: Write failing tests.** In `tests/test_macromanager.lua`, **replace** the issue-#2 test "BuildBody emits the two-slot weapon-enchant body for WPN_ENCH" with:

```lua
test("MacroManager: buildWeaponEnchantBody emits per-slot lines for MH+OH / one / neither", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M._buildWeaponEnchantBody(111, 222),
        "#showtooltip\n/use item:111\n/use 16\n/use item:222\n/use 17", "both hands")
    t.eq(M._buildWeaponEnchantBody(111, nil),
        "#showtooltip\n/use item:111\n/use 16", "main hand only")
    t.eq(M._buildWeaponEnchantBody(nil, 222),
        "#showtooltip\n/use item:222\n/use 17", "off hand only")
    t.eq(M._buildWeaponEnchantBody(nil, nil), nil, "neither -> nil")
end)
```

(Keep the "BuildBody VANTUS uses the default single /use body" test.)

- [ ] **Step 2: Run — expect FAIL** (`_buildWeaponEnchantBody` nil).

- [ ] **Step 3a:** In `modules/MacroManager.lua`, revert `buildActiveBody` to `buildActiveBody(id)` (drop the `catKey` param and the `WPN_ENCH` two-slot branch added in issue #2) and change its caller in `M.BuildBody` back to `buildActiveBody(itemID)`.

- [ ] **Step 3b:** Factor `SetMacro`'s tail into `commitMacro`. Extract everything from the oversize-check (`if #body > MACRO_BODY_LIMIT then …`) through the state store into:

```lua
-- Shared macro-write tail: oversize fallback, unchanged/pending coalescing,
-- combat deferral, doEdit, and macroState store. `iconItemID` drives the icon
-- (nil for empty-state). Callers pass an already-built body.
local function commitMacro(macroName, body, iconItemID, catKey)
    -- (moved verbatim from SetMacro: oversize check using `catKey`/`cat`,
    --  effectiveItemID := iconItemID, icon := iconFor(effectiveItemID),
    --  macroState unchanged/pending checks, InCombatLockdown defer, doEdit,
    --  and the macroState[macroName] = { lastItemID = iconItemID, ... } store)
end
```

Rewrite `SetMacro` to: resolve `catKey`, `local body = M.BuildBody(catKey, itemID)`, `return commitMacro(macroName, body, itemID, catKey)`.

- [ ] **Step 3c:** Add the per-hand builder + entry point:

```lua
local function buildWeaponEnchantBody(mhPick, ohPick)
    if not mhPick and not ohPick then return nil end
    local lines = { "#showtooltip" }
    if mhPick then lines[#lines + 1] = ("/use item:%d"):format(mhPick); lines[#lines + 1] = "/use 16" end
    if ohPick then lines[#lines + 1] = ("/use item:%d"):format(ohPick); lines[#lines + 1] = "/use 17" end
    return table.concat(lines, "\n")
end
M._buildWeaponEnchantBody = buildWeaponEnchantBody  -- test seam

-- Per-hand weapon-enchant macro: applies the best applicable enhancement to
-- each equipped weapon (16 main / 17 off). Falls back to the empty-state stub
-- when neither hand has a pick.
function M.SetWeaponEnchantMacro(cat, mhPick, ohPick)
    if not cat then return "error", "no category" end
    local body = buildWeaponEnchantBody(mhPick, ohPick)
    local iconItemID = mhPick or ohPick
    if not body then body = buildEmptyBody(cat); iconItemID = nil end
    return commitMacro(cat.macroName, body, iconItemID, cat.key)
end
```

- [ ] **Step 4: Run — expect PASS** (new body test + the untouched VANTUS/other macro tests).
- [ ] **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 5: Pipeline wiring + recompute on weapon swap

**Files:**
- Modify: `defaults/Categories.lua` (`perHand = true` on WPN_ENCH)
- Modify: `core/ConsumableMaster.lua` (`RecomputeOne` branch; `PLAYER_EQUIPMENT_CHANGED`)
- Test: `tests/test_pipeline.lua`

**Interfaces:**
- Consumes: `Selector.PickBestForSlot`, `MacroManager.SetWeaponEnchantMacro`.

- [ ] **Step 1: Write failing test.** Append to `tests/test_pipeline.lua` a case that sets up two equipped weapons + owned enhancements, runs `KCM.Pipeline.RecomputeOne("WPN_ENCH", nil, "test")`, and asserts the resulting macro body (read back from `KCM.db.profile.macroState["KCM_WPN_ENCH"].lastBody`) contains `/use 16` and the bladed pick. Model the setup on the existing pipeline tests in this file (spec + equipped weapons via `mock.setEquipped`, ownership via `mock.setBag`).

- [ ] **Step 2: Run — expect FAIL** (WPN_ENCH still routes through single-pick `SetMacro`).

- [ ] **Step 3a:** In `defaults/Categories.lua`, add `perHand = true,` to the `WPN_ENCH` row (beside `specAware = true`).

- [ ] **Step 3b:** In `core/ConsumableMaster.lua` `RecomputeOne`, add after the `cat.composite` block and before the single-pick line:

```lua
    if cat.perHand then
        local mh = KCM.Selector.PickBestForSlot(catKey, 16, scoreCache)
        local oh = KCM.Selector.PickBestForSlot(catKey, 17, scoreCache)
        return KCM.MacroManager.SetWeaponEnchantMacro(cat, mh, oh)
    end
```

- [ ] **Step 3c:** Register the equipment event. Beside the other `self:RegisterEvent(...)` calls add:

```lua
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEquipmentChanged")
```

and add the handler (mirroring the debounced `OnBagUpdateDelayed` style):

```lua
function addon:OnEquipmentChanged(_, slotID)
    if slotID == 16 or slotID == 17 then
        KCM.Pipeline.RequestRecompute("equip")
    end
end
```

(Use the module's actual event-handler receiver — match how `OnBagUpdateDelayed` is defined in this file.)

- [ ] **Step 4: Run — expect PASS.** **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 6: Settings UI — per-hand markers + affinity note

**Files:**
- Modify: `settings/Category.lua` (WPN_ENCH render path)
- Modify: `modules/KCMItemRow.lua` (MH/OH markers + dim)
- Test: none automated (AceGUI render); covered by `docs/smoke-tests.md` in Task 7.

**Interfaces:**
- `KCMItemRow:SetCustomData` gains `pickMH`, `pickOH`, `applicable` booleans.

- [ ] **Step 1:** In `modules/KCMItemRow.lua`: alongside the existing `pickTex`, add a small fontstring (e.g. `handTag`) anchored left of `pickTex`. Extend `SetCustomData` to store `self.pickMH`, `self.pickOH`, `self.applicable` (default true). In `RefreshDisplay`:
  - Show `pickTex` when `self.pickMH or self.pickOH`.
  - Set `handTag` text to `"MH"`, `"OH"`, or `"MH·OH"` per which are set (hidden otherwise).
  - Set frame alpha to `self.applicable and 1.0 or 0.4` so non-applicable enhancements are dimmed.
  Follow the existing `pickTex` show/hide pattern (`RefreshDisplay`, Constructor) for the new texture/fontstring.

- [ ] **Step 2:** In `settings/Category.lua`, in the single-category render path, when `cat.perHand`:
  - Compute `local mh = KCM.Selector.PickBestForSlot(cat.key, 16)` and `oh = ...17`.
  - Read `local mhAff = KCM.WeaponSlots.SlotAffinity(16)`, `ohAff = ...17`.
  - Per row, pass `pickMH = (rowID == mh)`, `pickOH = (rowID == oh)`, and `applicable = affinityMatches(rowID, mhAff, ohAff)` where a row is applicable if its `TooltipCache.Get(rowID).weaponAffinity` is `"any"` or equals `mhAff` or `ohAff`.
  - Replace the legend line (`Category.lua:339`) for perHand pages to read e.g. `… MH/OH picked in macro`, and add a header note: `("Main hand: %s · Off hand: %s"):format(mhAff or "(none)", ohAff or "(none)")`.
  - Non-perHand pages keep the existing single-`isPick` path unchanged.

- [ ] **Step 3:** In-game manual check (no headless test): open the Weapon Enchant page on a physical spec — the equipped weapon's compatible stone is starred for the correct hand(s), incompatible stones are dimmed, header shows the detected weapon types.

- [ ] **Step 4: Gate** (`lua5.1 tests/run.lua && luacheck .` — must stay green; UI is untested headlessly but must not break lint/load). **Step 5:** Report DONE.

---

### Task 7: Docs, smoke tests, inventory + badge

**Files:**
- Modify: `README.md`, `docs/ARCHITECTURE.md`, `docs/agent-context.md`, `docs/data-model.md`, `docs/smoke-tests.md`, `docs/test-cases.md`

- [ ] **Step 1:** README — update the Weapon Enchant description + the "How picking & ranking works" weapon-enchant bullet to describe per-hand, weapon-type-aware application and AP/SP scoring. Note the macro applies the best *applicable* enhancement to each equipped weapon.
- [ ] **Step 2:** `docs/ARCHITECTURE.md` — add `core/WeaponSlots.lua` to the module map and `PLAYER_EQUIPMENT_CHANGED` to Event Subscriptions; `docs/agent-context.md` + `docs/data-model.md` — note the per-hand `WPN_ENCH` model, `weaponAffinity`, and AP/SP stats.
- [ ] **Step 3:** `docs/smoke-tests.md` — add cases: (a) equip a bladed weapon → whetstone picked/starred, weightstone dimmed; (b) swap to a blunt weapon → macro + UI update without reload; (c) dual-wield mismatched types → each hand gets its own enhancement; (d) 2H weapon → only slot 16 in the macro.
- [ ] **Step 4:** Regenerate the inventory and bump the badge:
  Run `lua5.1 tests/run.lua --list > docs/test-cases.md`; read the total from `lua5.1 tests/run.lua 2>&1 | tail -1`; set the README `[Tests]` badge to `<N>%2F<N>`. Confirm `diff <(lua5.1 tests/run.lua --list) docs/test-cases.md` is empty.
- [ ] **Step 5: Gate.** **Step 6:** Report DONE.

---

## Post-implementation (in-game smoke, tracked separately)
1. Fist Weapons / Polearms bladed-vs-blunt — apply a whetstone; adjust `BLADED`/`BLUNT` if wrong.
2. Confirm current weapons' exact `GetItemInfoInstant` subType strings vs the affinity map.

## Self-review notes
- **Spec coverage:** scoring (T1), affinity parse + equipped map (T2), per-slot pick (T3), per-hand macro (T4), pipeline + equip event (T5), UI (T6), docs/badge (T7) — every spec section maps to a task.
- **Type consistency:** `weaponAffinity` values ("bladed"/"blunt"/"any"), `SlotAffinity` returns ("bladed"/"blunt"/nil), and `PickBestForSlot(catKey, slot, scoreCache)` / `SetWeaponEnchantMacro(cat, mh, oh)` signatures are used identically across tasks. The issue-#2 `buildActiveBody(catKey,…)` shortcut is reverted in T4 (single caller), and its macro test is replaced in the same task.
