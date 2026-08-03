# Bloodlust & Battle Rez Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `BLOODLUST` and `BATTLE_REZ` managed macro categories that resolve to the character's own ability when it has one and fall back to a usable item in bags when it doesn't.

**Architecture:** The existing pipeline already handles spell-or-item categories — seeds may mix itemIDs with `KCM.ID.AsSpell` sentinels, `Selector` filters spells through `IsPlayerSpell`, `Ranker` sorts spells ahead of items, and `MacroManager` emits `/cast <name>` or `/use item:<id>` accordingly. This plan adds the four things that pipeline can't do yet — parse and enforce a **maximum** level cap, gate a spell on the player's class, splice a **targeting conditional** into a macro body, and make the usability gate reach the pick path at all — then lands the two category rows and seeds on top.

**Tech Stack:** Lua 5.1, Ace3, WoW Midnight (Interface 120007). Headless test harness at `tests/run.lua`, lint via `luacheck`.

**Spec:** [docs/superpowers/specs/2026-08-03-bloodlust-battle-rez-design.md](../specs/2026-08-03-bloodlust-battle-rez-design.md)
**Issue:** [#10](https://github.com/tusharsaxena/ConsumableMaster/issues/10)

## Global Constraints

- **Commit scope is narrow and explicitly authorized.** CLAUDE.md's hard rule is that the agent never touches the git index. The user has granted one scoped exception for this plan: you may `git add` + `git commit` **only** the files your own task's Commit step names, **only** on the `feature/bloodlust-battle-rez` branch. Never `git add -A`, `-p`, `--renormalize`, never `git stash`, never `git push`, never touch `master`. If your task needs to change a file its Commit step doesn't list, say so in your report instead of widening the commit.
- **Commit trailers.** End every commit message with these two lines:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01LKa1UQTTKM1BBZ4WaFH2Vv
  ```
- **Never bump the version.** Not `KCM.VERSION`, not the TOC `## Version:`, not the README version badge, no CHANGELOG entry.
- **Gate before any commit:** `lua5.1 tests/run.lua` and `luacheck .` must both be green.
- **`[Tests]` badge sync is a hard rule.** When the suite's case count changes, regenerate `docs/test-cases.md` with `lua5.1 tests/run.lua --list > docs/test-cases.md` and bump the `Tests-<X>/<Y>_passing` count in `README.md` **in the same change**. Never defer it.
- **No new globals.** Every file starts `local addonName, NS = ...; local KCM = NS`, and publishes with the `KCM.Foo = KCM.Foo or {}` pattern — the `or {}` is load-bearing.
- **Locale-independence where the standard requires it.** Classification keys on numeric `classID`/`subClassID`. Tooltip *text* parsing lives only in `core/TooltipCache.lua`, which is the addon's tracked English-only deviation (`docs/scope.md`). Do not add English string matching anywhere else.
- **Purity invariant.** `Selector`, `Ranker`, `Classifier`, `TooltipCache` must never call a protected API. `MacroManager` is the only caller of `CreateMacro`/`EditMacro`.
- **Macro names are ≤16 characters** (`GetMacroIndexByName` limit). `KCM_BLOODLUST` is 13, `KCM_BATTLE_REZ` is 14.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `core/TooltipCache.lua` | Modify | Parse `maxLevel` from tooltip text; enforce it in `IsUsableByPlayer` |
| `modules/Selector.lua` | Modify | Consult the usability gate when picking/listing; honor the class gate for spells |
| `modules/MacroManager.lua` | Modify | Splice a category's targeting conditional into the body |
| `defaults/Categories.lua` | Modify | The two new category rows |
| `defaults/Defaults_Bloodlust.lua` | Create | `KCM.SEED.BLOODLUST` + `KCM.SEED.CLASS_GATE` |
| `defaults/Defaults_BattleRez.lua` | Create | `KCM.SEED.BATTLE_REZ` |
| `modules/Ranker.lua` | Modify | Scorers + `Explain` branches for both keys |
| `settings/Category.lua` | Modify | The mouseover checkbox on a targeted category page |
| `core/ConsumableMaster.lua` | Modify | DB buckets + macro-bar slot order |
| `settings/Panel.lua` | Modify | Tab order + `_validPanels` |
| `ConsumableMaster.toc` | Modify | Load the two new defaults files |

Tasks 1–3 are mechanics and land against the *existing* categories, so each is independently shippable. Task 4 lands the two categories and their data. Task 5 gives Battle Rez its targeting clause — it comes after Task 4 because its tests need the real `BATTLE_REZ` row. Task 6 is the settings surface, Task 7 the docs.

---

### Task 1: Parse and enforce a maximum level cap

**Files:**
- Modify: `core/TooltipCache.lua` — `PATTERNS` (line 43), `parseLines`, `TC.IsUsableByPlayer` (line 427)
- Test: `tests/test_tooltipcache.lua`

**Interfaces:**
- Produces: `tt.maxLevel` — number, or `nil` when the tooltip states no cap. `TC.IsUsableByPlayer(itemID) -> boolean, reason|nil` gains a `"level %d > %d"` reason for an over-cap item.

**Background the implementer needs:** `TooltipCache` reads `C_TooltipInfo.GetItemByID` line text and matches it against Lua patterns. All text goes through `normalizeTooltipText` first, which collapses the non-breaking space (U+00A0 — Lua `%s` does **not** match it) and `|4singular:plural;` grammar escapes. Never bypass it. `minLevel` already exists but comes from `GetItemInfo`, not from text (line 416).

Two real tooltip phrasings must match. The self-restriction, confirmed verbatim from Emergency Soul Link (248486): `Cannot be used by players higher than level 90.` The drums phrasing states a cap on who the effect *affects*; its exact wording must be read off a live client with `/cm dump item <id>` before finalizing (see Task 7's verification list). Until then, implement the confirmed pattern plus a lenient `higher than level (%d+)` / `above level (%d+)` pair, which covers both observed phrasings.

- [ ] **Step 1: Write the failing tests**

In `tests/test_tooltipcache.lua`:

```lua
test("TooltipCache: parses a 'cannot be used by players higher than level' cap", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setItem(2401, { subType = "Other", lines = {
        "Emergency Soul Link",
        "Use: Convince a dead ally that being alive is much more fun.",
        "Cannot be used by players higher than level 90.",
    } })
    t.eq(KCM.TooltipCache.Get(2401).maxLevel, 90, "the self-restriction cap is parsed")
end)

test("TooltipCache: parses a drums 'above level' affect cap", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setItem(2402, { subType = "Other", lines = {
        "Drums of Rage",
        "Use: Increases Haste by 15% for all party and raid members.",
        "Does not affect allies above level 50.",
    } })
    t.eq(KCM.TooltipCache.Get(2402).maxLevel, 50, "the affect cap is parsed")
end)

test("TooltipCache: an uncapped item reports no maxLevel", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setItem(2403, { subType = "Potions", tt = { healValue = 500 } })
    t.eq(KCM.TooltipCache.Get(2403).maxLevel, nil, "no cap line means no cap")
end)

test("TooltipCache.IsUsableByPlayer rejects an over-cap item and accepts at the cap", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    mock.setItem(2404, { subType = "Other", lines = {
        "Drums of Rage",
        "Use: Increases Haste by 15%.",
        "Does not affect allies above level 50.",
    } })
    mock.setPlayerLevel(80)
    local ok, why = KCM.TooltipCache.IsUsableByPlayer(2404)
    t.falsy(ok, "an 80 cannot use a level-50-capped drum")
    t.eq(why, "level 80 > 50", "the reason names both levels")

    mock.setPlayerLevel(50)
    t.truthy(KCM.TooltipCache.IsUsableByPlayer(2404), "usable at exactly the cap")
end)
```

If `tests/wow_mock.lua` has no `setPlayerLevel` or no raw `lines` support on `setItem`, add them alongside the existing `setItem`/`setBag` helpers: `lines` should feed `C_TooltipInfo.GetItemByID` directly, and `setPlayerLevel(n)` should back `UnitLevel("player")` (default 80).

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: four failures — `maxLevel` is nil, and `IsUsableByPlayer` returns true for the over-cap item.

- [ ] **Step 3: Add the patterns**

In `PATTERNS` (`core/TooltipCache.lua:43`), after the `Flags` block:

```lua
    -- Maximum-level caps. Two real phrasings: the self-restriction ("Cannot be
    -- used by players higher than level 90." — Emergency Soul Link) and the
    -- drums' affect cap ("...above level 50."). Both reduce to a bare number
    -- after a "higher than level" / "above level" lead-in, so match that much
    -- and stay indifferent to the surrounding sentence.
    maxLevelHigher = "higher than level (%d+)",
    maxLevelAbove  = "above level (%d+)",
```

- [ ] **Step 4: Populate `tt.maxLevel` in `parseLines`**

Follow whatever shape the neighboring flag parses use in `parseLines`; the value is the first match found, `nil` when neither pattern hits:

```lua
        local cap = text:match(PATTERNS.maxLevelHigher) or text:match(PATTERNS.maxLevelAbove)
        if cap then parsed.maxLevel = tonumber(cap) end
```

Leave `parsed.maxLevel` unset (not 0) when there is no cap — `IsUsableByPlayer` and the Ranker both distinguish "no cap" from "capped at 0".

- [ ] **Step 5: Enforce it in `IsUsableByPlayer`**

Replace the body at `core/TooltipCache.lua:427`:

```lua
function TC.IsUsableByPlayer(itemID)
    local entry = TC.Get(itemID)
    if not entry or entry.pending then return false, "pending" end
    local have = UnitLevel("player") or 0
    local need = entry.minLevel or 0
    if have < need then
        return false, ("level %d < %d"):format(have, need)
    end
    -- Upper bound. Old drums keep working as items but stop affecting anyone
    -- past their expansion's cap, so on a max-level character they are dead
    -- weight the picker must not choose.
    local cap = entry.maxLevel
    if cap and have > cap then
        return false, ("level %d > %d"):format(have, cap)
    end
    return true, nil
end
```

- [ ] **Step 6: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: all tests pass, 0 warnings / 0 errors.

- [ ] **Step 7: Regenerate the inventory and bump the badge**

```bash
lua5.1 tests/run.lua --list > docs/test-cases.md
```
Then set `README.md`'s `Tests-<X>/<X>_passing` to the new `**Total**` at the bottom of `docs/test-cases.md`.

- [ ] **Step 8: Commit**

The user has authorized you to run this. Only these files, only on this branch.

```bash
git add core/TooltipCache.lua tests/test_tooltipcache.lua tests/wow_mock.lua docs/test-cases.md README.md
git commit -m "feat(tooltip): parse maximum level caps and enforce them in IsUsableByPlayer"
```

---

### Task 2: Make the usability gate reach the pick path

**Files:**
- Modify: `modules/Selector.lua` — `S.PickBestForCategory` (line 232), `isAvailable` (line 292)
- Test: `tests/test_selector.lua`

**Interfaces:**
- Consumes: `TC.IsUsableByPlayer(itemID) -> boolean, reason|nil` from Task 1.
- Produces: no signature change. `PickBestForCategory` and `GetAvailable` simply stop returning unusable items.

**Background:** `IsUsableByPlayer` currently has exactly one caller — the `/cm dump item` diagnostic at `core/SlashCommands.lua:342`. Nothing in the pick path consults it, so today neither `minLevel` nor Task 1's `maxLevel` affects what gets picked. This task closes that, for **all** categories — which also fixes the pre-existing bug where a leveling character can have a too-high-level flask written into a macro.

**The trap:** `IsUsableByPlayer` returns `false, "pending"` for an item whose tooltip hasn't hydrated. Dropping those would make picks flap during load, when most items are pending. Reject only on a **definite** level verdict.

- [ ] **Step 1: Write the failing tests**

In `tests/test_selector.lua`:

```lua
test("Selector.PickBestForCategory skips an item the player is over the cap for", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setPlayerLevel(80)
    mock.setItem(940001, { subType = "Other", lines = {
        "Old Drums", "Use: Haste.", "Does not affect allies above level 50." } })
    mock.setBag(940001, 1)
    S.AddItem("FOOD", 940001)
    -- Assert the capped item is not chosen, rather than asserting WHICH item
    -- is: FOOD has a seed roster and the winner depends on Ranker scores, so
    -- pinning an exact id here would make this test fail for unrelated reasons.
    t.truthy(S.PickBestForCategory("FOOD") ~= 940001, "the capped item is passed over")
end)

test("Selector.GetAvailable omits an item the player is over the cap for", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setPlayerLevel(80)
    mock.setItem(940003, { subType = "Other", lines = {
        "Old Drums", "Use: Haste.", "Does not affect allies above level 50." } })
    mock.setBag(940003, 1)
    S.AddItem("FOOD", 940003)
    t.eqList(S.GetAvailable("FOOD"), {}, "an unusable item is not offered in the flyout")
end)

-- The load race: during PEW most tooltips are still pending. "Don't know yet"
-- must not read as "unusable", or picks flap on every login.
test("Selector.PickBestForCategory keeps an item whose tooltip is still pending", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setItem(940004, { subType = "Other", pending = true })
    mock.setBag(940004, 1)
    S.AddItem("FOOD", 940004)
    t.eq(S.PickBestForCategory("FOOD"), 940004, "a pending item is still eligible")
end)
```

Use whatever the real name of the flyout-listing function is (`S.GetAvailable` or equivalent — check around `modules/Selector.lua:292`, where `isAvailable` is the helper) and match it in the test.

If `tests/wow_mock.lua` has no way to force a pending tooltip, add a `pending = true` spec flag to `setItem` that makes `C_TooltipInfo.GetItemByID` return no lines.

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: the first two fail (the capped item is picked/offered); the third already passes, and is there to keep the fix honest.

- [ ] **Step 3: Add the shared gate helper**

Near the top of the pick section in `modules/Selector.lua`:

```lua
-- True when the player's level definitively rules this item out.
--
-- IsUsableByPlayer reports `false, "pending"` for an item whose tooltip hasn't
-- hydrated, and the discovery/recompute passes run during exactly that race —
-- so only a level verdict may drop a candidate. "Don't know yet" keeps it.
local function levelBlocked(id)
    local TC = KCM.TooltipCache
    if not (TC and TC.IsUsableByPlayer) then return false end
    local ok, reason = TC.IsUsableByPlayer(id)
    return (not ok) and reason ~= "pending"
end
```

- [ ] **Step 4: Consult it in both walks**

In `S.PickBestForCategory` (line 232), change the item branch:

```lua
        elseif hasItem and hasItem(id) and not levelBlocked(id) then
            return id
        end
```

In `isAvailable` (line 292), change the item return:

```lua
    local hasItem = KCM.BagScanner and KCM.BagScanner.HasItem
    return (hasItem and hasItem(id) and not levelBlocked(id)) and true or false
```

Leave `S.PickBestForSlot` alone unless its tests show the same hole — weapon enchants have no caps today, and the affinity filter there is a separate concern.

- [ ] **Step 5: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green. If an existing test breaks because a fixture item now reads as unusable, the fixture needs a level or a cap — do not weaken the gate to accommodate it.

- [ ] **Step 6: Regenerate the inventory and bump the badge** (same two commands as Task 1 Step 7)

- [ ] **Step 7: Commit**

```bash
git add modules/Selector.lua tests/test_selector.lua tests/wow_mock.lua docs/test-cases.md README.md
git commit -m "fix(selector): honor item usability when picking and listing candidates"
```

---

### Task 3: Class-gated spell entries

**Files:**
- Modify: `modules/Selector.lua` — the spell branch of `S.PickBestForCategory` (line 238) and of `isAvailable` (line 293)
- Test: `tests/test_selector.lua`

**Interfaces:**
- Produces: `KCM.SEED.CLASS_GATE` — an optional map `[spellSentinel] = classFile`, read by `Selector`. Task 4 populates it.

**Background:** Primal Rage (272678) is a hunter *pet* ability, so `IsPlayerSpell(272678)` is false for every character including hunters — the seed entry would never resolve. Rather than add a pet-spellbook seam and the `UNIT_PET` / `PET_SPECIALIZATION_CHANGED` recompute triggers it would need, availability falls back to a seed-declared class gate.

`classFile` is the locale-independent second return of `UnitClass("player")` (`"HUNTER"`, `"DRUID"`, …) — never the localized first return.

**Accepted cost, decided in the spec:** a hunter with no pet, a non-Ferocity pet, or a Lone Wolf build still sees Primal Rage as the pick and pressing it does nothing. This is deliberate; do not "improve" it with a pet check without asking.

- [ ] **Step 1: Write the failing tests**

```lua
test("Selector: a class-gated spell resolves for its class when IsPlayerSpell says no", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local pet  = KCM.ID.AsSpell(272678)

    mock.setSpell(272678, { name = "Primal Rage", known = false })  -- pet spellbook
    KCM.SEED.CLASS_GATE = { [pet] = "HUNTER" }
    S.AddItem("FOOD", pet)

    mock.setPlayerClass("HUNTER")
    t.eq(S.PickBestForCategory("FOOD"), pet, "a hunter gets the pet ability")

    mock.setPlayerClass("MAGE")
    t.eq(S.PickBestForCategory("FOOD"), nil, "nobody else does")
end)

-- The gate must be a FALLBACK, never an override. Set a gate entry naming a
-- class the player is NOT, on a spell they genuinely know: a gate-first
-- implementation rejects it, this one must not. Do NOT write this test with an
-- EMPTY CLASS_GATE — with no entry for the sentinel the gate branch never
-- executes, IsPlayerSpell short-circuits, and a gate-first implementation
-- passes identically. The conflicting entry is the whole point.
test("Selector: the class gate never overrides a genuinely known spell", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local sid  = KCM.ID.AsSpell(80353)

    mock.setSpell(80353, { name = "Time Warp", known = true })
    KCM.SEED.CLASS_GATE = { [sid] = "PALADIN" }   -- names a class the player is not
    S.AddItem("FOOD", sid)
    mock.setPlayerClass("MAGE")
    t.eq(S.PickBestForCategory("FOOD"), sid, "a known spell resolves despite a conflicting gate")
end)
```

Add `mock.setPlayerClass(classFile)` to `tests/wow_mock.lua` backing `UnitClass("player")`'s second return if it isn't there. Ensure `loadPure()` resets `KCM.SEED.CLASS_GATE` between tests, or set it explicitly in every test that reads it — as both tests above do.

- [ ] **Step 2: Run and confirm failure**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: the first test fails — the hunter gets `nil`, because `IsPlayerSpell` is the only check.

- [ ] **Step 3: Add the gate helper**

In `modules/Selector.lua`, beside `levelBlocked`:

```lua
-- Spell availability: the spellbook first, then a seed-declared class gate.
--
-- Some seeded abilities are not in the PLAYER's spellbook at all — Primal Rage
-- lives in the hunter pet's — so IsPlayerSpell reports false even for the class
-- that has it. The gate names the class that can cast it; the entry is then
-- available for that class and nobody else. Data, not code: a future
-- pet-granted ability needs only a seed edit.
--
-- UnitClass's SECOND return is the locale-independent class file ("HUNTER");
-- the first is the localized display name and must never be matched.
local function spellAvailable(id)
    local spellID = KCM.ID and KCM.ID.SpellID(id)
    if not spellID then return false end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    local gate = KCM.SEED and KCM.SEED.CLASS_GATE and KCM.SEED.CLASS_GATE[id]
    if not gate then return false end
    local _, classFile = UnitClass("player")
    return classFile == gate
end
```

- [ ] **Step 4: Route both spell branches through it**

In `S.PickBestForCategory`:

```lua
        if KCM.ID and KCM.ID.IsSpell(id) then
            if spellAvailable(id) then return id end
```

In `isAvailable`:

```lua
    if KCM.ID and KCM.ID.IsSpell(id) then
        return spellAvailable(id)
    end
```

Delete the now-duplicated `IsPlayerSpell` calls and their comments from both sites — `spellAvailable` carries the explanation.

- [ ] **Step 5: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green, including the pre-existing spell tests at `tests/test_selector.lua:101` and `:463`.

- [ ] **Step 6: Regenerate the inventory and bump the badge**

- [ ] **Step 7: Commit**

```bash
git add modules/Selector.lua tests/test_selector.lua tests/wow_mock.lua docs/test-cases.md README.md
git commit -m "feat(selector): resolve class-gated spells that live outside the player spellbook"
```

---

### Task 4: The two categories, their seeds and their plumbing

**Files:**
- Modify: `defaults/Categories.lua` — append to `KCM.Categories.LIST`
- Create: `defaults/Defaults_Bloodlust.lua`, `defaults/Defaults_BattleRez.lua`
- Modify: `ConsumableMaster.toc` (`# Defaults` section), `core/ConsumableMaster.lua` (DB buckets line 40-46, macro-bar order line 176-180), `settings/Panel.lua` (order line 33, `_validPanels` line 121), `modules/Ranker.lua` (`scorers` line 209, `Explain`)
- Test: `tests/test_categories.lua`, `tests/test_defaults.lua`, `tests/test_ranker.lua`, `tests/test_macrobar.lua`

**Interfaces:**
- Consumes: `tt.maxLevel` (Task 1), `KCM.SEED.CLASS_GATE` (Task 3).
- Produces: category keys `"BLOODLUST"` and `"BATTLE_REZ"`; seeds `KCM.SEED.BLOODLUST` and `KCM.SEED.BATTLE_REZ`.

**All item and spell IDs below come from wiki and database sources, not from a live client.** They are the best available and are internally consistent, but each must be confirmed in game (Task 7) before this is called done. Do not present them as verified.

- [ ] **Step 1: Write the failing tests**

In `tests/test_categories.lua`, following the existing `AUG_RUNE` registration test:

```lua
test("Categories: BLOODLUST and BATTLE_REZ registered with metadata, buckets and seeds", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs({ "BLOODLUST", "BATTLE_REZ" }) do
        local cat = KCM.Categories.Get(key)
        t.truthy(cat, key .. " is registered")
        t.falsy(cat.specAware, key .. " is not spec-aware")
        t.falsy(cat.composite, key .. " is not a composite")
        t.truthy(#cat.macroName <= 16, key .. " macro name fits the 16-char limit")
        t.truthy(KCM.db.profile.categories[key].discovered, key .. " has an item bucket")
        t.truthy(#KCM.SEED[key] > 0, key .. " has a seed roster")
    end
    t.eq(KCM.Categories.Get("BATTLE_REZ").targeted, "[@mouseover,help][@target,help]",
        "Battle Rez declares its targeting clause")
    t.eq(KCM.Categories.Get("BLOODLUST").targeted, nil, "Bloodlust targets the player")
    t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, true, "mouseover defaults on")
end)

test("Categories: the Bloodlust seed leads with spells and the class gate names Primal Rage", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.ID.IsSpell(KCM.SEED.BLOODLUST[1]), "the roster leads with a spell")
    t.eq(KCM.SEED.CLASS_GATE[KCM.ID.AsSpell(272678)], "HUNTER", "Primal Rage is hunter-gated")
end)
```

- [ ] **Step 2: Run and confirm failure**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: both fail — `Categories.Get("BLOODLUST")` is nil.

- [ ] **Step 3: Create `defaults/Defaults_Bloodlust.lua`**

```lua
-- defaults/Defaults_Bloodlust.lua — Seed list for KCM_BLOODLUST.
--
-- The raid haste effect, spell forms first. Every class reaches it by a
-- different name, so the roster is a union and Selector resolves whichever the
-- character actually has; the drums are the item fallback for classes that
-- bring none.
--
-- Drums stop AFFECTING players past their expansion's cap, so an old drum in
-- bags is dead weight at max level. The whole line ships anyway: TooltipCache
-- parses the cap and Selector filters on it, which leaves them usable while
-- leveling and in Timewalking. See docs/superpowers/specs/2026-08-03-*.
--
-- Sources: warcraft.wiki.gg "Bloodlust effect", 2026-08. IDs pending in-game
-- confirmation via /cm dump item.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.BLOODLUST = {
    KCM.ID.AsSpell(2825),    -- Bloodlust            (Shaman, Horde)
    KCM.ID.AsSpell(32182),   -- Heroism              (Shaman, Alliance)
    KCM.ID.AsSpell(80353),   -- Time Warp            (Mage)
    KCM.ID.AsSpell(390386),  -- Fury of the Aspects  (Evoker)
    KCM.ID.AsSpell(466904),  -- Harrier's Cry        (Hunter, Marksmanship)
    KCM.ID.AsSpell(272678),  -- Primal Rage          (Hunter, Ferocity pet — class-gated below)
    244639,                  -- Void-Touched Drums          (Midnight)
    -- Superseded drums, kept for leveling and Timewalking; the level-cap
    -- filter removes them at max level.
    -- (The War Within / Dragonflight / Shadowlands / BfA / Legion / WoD / MoP / TBC
    --  itemIDs go here, newest first, once confirmed with /cm dump item.)
}

-- Abilities that are NOT in the player's own spellbook, so IsPlayerSpell
-- reports false even for the class that has them. Primal Rage lives in the
-- hunter pet's book. Keyed by the same sentinel the roster uses; the value is
-- the locale-independent class file from UnitClass's second return.
KCM.SEED.CLASS_GATE = KCM.SEED.CLASS_GATE or {}
KCM.SEED.CLASS_GATE[KCM.ID.AsSpell(272678)] = "HUNTER"
```

The superseded-drums itemIDs are the one thing this plan cannot supply from a trustworthy source — Task 7 collects them in game. Ship the file with Void-Touched Drums alone if they aren't available yet; the seed is data, so adding them later is a zero-migration change.

- [ ] **Step 4: Create `defaults/Defaults_BattleRez.lua`**

```lua
-- defaults/Defaults_BattleRez.lua — Seed list for KCM_BATTLE_REZ.
--
-- Combat resurrection, spell forms first, then the item any class can carry.
--
-- Soulstone is included deliberately even though it is pre-cast on a LIVING
-- ally rather than pressed when someone dies — it is what a warlock brings, and
-- the category's targeting clause uses `help` without `dead` precisely so the
-- one body works for it as well as for the rezzes.
--
-- The Gnomish Army Knife / Goblin Jumper Cables line is deliberately absent:
-- those are out-of-combat only, so they would resolve to a button that cannot
-- be pressed when it matters.
--
-- Sources: warcraft.wiki.gg, 2026-08. IDs pending in-game confirmation.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.BATTLE_REZ = {
    KCM.ID.AsSpell(20484),   -- Rebirth       (Druid)
    KCM.ID.AsSpell(61999),   -- Raise Ally    (Death Knight)
    KCM.ID.AsSpell(391054),  -- Intercession  (Paladin)
    KCM.ID.AsSpell(20707),   -- Soulstone     (Warlock; pre-cast on a living ally)
    248486,                  -- Emergency Soul Link (Midnight; usable by anyone, in combat)
}
```

- [ ] **Step 5: Add the category rows**

Append to `KCM.Categories.LIST` in `defaults/Categories.lua`, **before** the two composite rows (composites read best last):

```lua
    {
        key         = "BLOODLUST",
        macroName   = "KCM_BLOODLUST",
        displayName = "Bloodlust",
        shortName   = "Lust",
        specAware   = false,
        rankerKey   = "BLOODLUST",
        emptyText   = emptyMacro("no bloodlust available"),
    },
    {
        key         = "BATTLE_REZ",
        macroName   = "KCM_BATTLE_REZ",
        displayName = "Battle Rez",
        shortName   = "Brez",
        specAware   = false,
        rankerKey   = "BATTLE_REZ",
        -- Acts on someone else, unlike every other category. `help` without
        -- `dead` so the one clause also serves Soulstone, which is cast on a
        -- LIVING ally. MacroManager reads db.profile…BATTLE_REZ.mouseover to
        -- let the user turn it off.
        targeted    = "[@mouseover,help][@target,help]",
        emptyText   = emptyMacro("no battle rez available"),
    },
```

Note the deliberate absence of a `classifier` field on both rows. `Classifier.Match` returns false for a category with no matcher (`core/Classifier.lua:157`), which is exactly right here: neither drums nor Emergency Soul Link has a distinguishing consumable subclass, so auto-discovery would sweep in unrelated bombs and toys. These two categories are seed-plus-user-added. Do not add matchers.

- [ ] **Step 6: Add the DB buckets**

In `core/ConsumableMaster.lua`, in the non-spec block around line 46:

```lua
            BLOODLUST  = { added = {}, blocked = {}, pins = {}, discovered = {} },
            -- `mouseover` drives the targeting clause MacroManager splices into
            -- the body; see defaults/Categories.lua's `targeted` field.
            BATTLE_REZ = { added = {}, blocked = {}, pins = {}, discovered = {}, mouseover = true },
```

- [ ] **Step 7: Add both to the two order lists**

`core/ConsumableMaster.lua` macro-bar order (line ~176) and `settings/Panel.lua` `KCM.Settings.order` (line 33) must stay in the same relative positions or `tests/test_macrobar.lua` fails on the drift. Append to both after `"VANTUS"` / `"vantus"`:

```lua
                "FLASK", "CMBT_POT", "STAT_FOOD", "WPN_ENCH", "AUG_RUNE", "VANTUS",
                "BLOODLUST", "BATTLE_REZ",
```

```lua
    "flask", "cmbt_pot", "stat_food", "wpn_ench", "aug_rune", "vantus",
    "bloodlust", "battle_rez",
```

And add `bloodlust = true, battle_rez = true` to `_validPanels` (`settings/Panel.lua:121`).

- [ ] **Step 8: Add the TOC entries**

In `ConsumableMaster.toc`'s `# Defaults` section, after `Categories.lua` and beside the other `Defaults_*.lua` lines:

```
defaults\Defaults_Bloodlust.lua
defaults\Defaults_BattleRez.lua
```

Match the path separator and ordering style the neighboring lines already use.

- [ ] **Step 9: Add the Ranker scorers**

In `modules/Ranker.lua`'s `scorers` table (line 209):

```lua
    -- Spells already outrank every item via SPELL_SCORE, so this only orders
    -- the drums against each other. A higher affect-cap means a more current
    -- drum; an uncapped item sorts above all of them.
    BLOODLUST = function(itemID, ctx, scoreCache)
        local quality, ilvl, _, tt = itemFields(itemID, scoreCache)
        return (tt.maxLevel or UNCAPPED_LEVEL)
             + ilvl
             + quality * QUALITY_WEIGHT
    end,
    -- One seeded item today, so there is nothing to discriminate; ilvl and
    -- quality keep a future second item ordered sensibly.
    BATTLE_REZ = function(itemID, ctx, scoreCache)
        local quality, ilvl = itemFields(itemID, scoreCache)
        return ilvl + quality * QUALITY_WEIGHT
    end,
```

Define the constant beside the other scoring constants:

```lua
-- An item with no stated cap affects everyone, so it outranks every capped one.
local UNCAPPED_LEVEL = 9999
```

- [ ] **Step 10: Add the `Explain` branches**

Find the per-category branches in `Ranker.Explain` and add two that mirror the scorers' additive terms exactly — the score-button tooltip is a lie if they drift:

```lua
    elseif catKey == "BLOODLUST" then
        local quality, ilvl, _, tt = itemFields(itemID, scoreCache)
        -- NOT `tt.maxLevel and nil or "no cap"` — with nil as the middle
        -- operand that collapses to "no cap" for EVERY item, capped or not.
        rows[#rows + 1] = { label = "Affects up to level",
                            value = tt.maxLevel or UNCAPPED_LEVEL,
                            note  = (not tt.maxLevel) and "no cap" or nil }
        rows[#rows + 1] = { label = "Item level", value = ilvl }
        rows[#rows + 1] = { label = "Quality",    value = quality * QUALITY_WEIGHT }
    elseif catKey == "BATTLE_REZ" then
        local quality, ilvl = itemFields(itemID, scoreCache)
        rows[#rows + 1] = { label = "Item level", value = ilvl }
        rows[#rows + 1] = { label = "Quality",    value = quality * QUALITY_WEIGHT }
```

Match the exact row-construction idiom the surrounding branches use — the shape above is illustrative of the fields, not necessarily of the local variable names in that function.

- [ ] **Step 11: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green. The `targeted` field and the `mouseover` bucket key land here as inert data — Task 5 is what reads them, so no macro body changes yet.

- [ ] **Step 12: Regenerate the inventory and bump the badge**

- [ ] **Step 13: Commit**

```bash
git add defaults/Categories.lua defaults/Defaults_Bloodlust.lua defaults/Defaults_BattleRez.lua \
        ConsumableMaster.toc core/ConsumableMaster.lua settings/Panel.lua modules/Ranker.lua \
        tests/test_categories.lua tests/test_ranker.lua docs/test-cases.md README.md
git commit -m "feat(categories): add Bloodlust and Battle Rez managed macros"
```

---

### Task 5: Targeting conditional in the macro body

**Files:**
- Modify: `modules/MacroManager.lua` — `buildActiveBody` (line 58), `M.BuildBody` (line 82)
- Test: `tests/test_macromanager.lua`

**Interfaces:**
- Consumes: the `targeted` row field and the `mouseover` bucket key, both landed by Task 4.
- Produces: `M.BuildBody(catKey, itemID)` unchanged in signature; the body gains the conditional when the category declares one and the profile has it enabled.

**Background:** every existing category's macro acts on the player, so `buildActiveBody` emits a bare `/cast <name>` or `/use item:<id>`. Battle Rez acts on someone else. `/use` accepts `@unit` conditionals exactly as `/cast` does, so both forms take the same clause.

**Why the clause has no `,dead`:** Soulstone is cast on a **living** ally, and `help` already matches dead friendly units — so `[@mouseover,help][@target,help]` serves the rez spells and Soulstone alike. Adding `,dead` would break Soulstone. Do not add it.

The clause is on by default and switchable off at `db.profile.categories.BATTLE_REZ.mouseover`. Read the profile in `MacroManager`, not in the category row — the row holds the static default, the profile holds the user's choice.

- [ ] **Step 1: Write the failing tests**

In `tests/test_macromanager.lua`:

```lua
test("MacroManager: a targeted category's spell body carries the conditional", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local mock = h.loader.mock
    mock.setSpell(20484, { name = "Rebirth", known = true })
    local body = M.BuildBody("BATTLE_REZ", KCM.ID.AsSpell(20484))
    t.eq(body, "#showtooltip\n/cast [@mouseover,help][@target,help] Rebirth",
        "the spell form is targeted")
end)

test("MacroManager: a targeted category's item body carries the same conditional", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local body = M.BuildBody("BATTLE_REZ", 248486)
    t.eq(body, "#showtooltip\n/use [@mouseover,help][@target,help] item:248486",
        "/use takes @unit conditionals too")
end)

test("MacroManager: turning mouseover off drops the conditional", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    KCM.db.profile.categories.BATTLE_REZ.mouseover = false
    t.eq(M.BuildBody("BATTLE_REZ", 248486), "#showtooltip\n/use item:248486",
        "the plain body comes back")
end)

test("MacroManager: an untargeted category is unaffected", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M.BuildBody("FOOD", 113509), "#showtooltip\n/use item:113509",
        "no conditional leaks into other categories")
end)
```

These run against the real `BATTLE_REZ` row and DB bucket that Task 4 landed, so they fail on a wrong body rather than erroring on a missing category. If any of them errors instead of failing, Task 4 is incomplete — stop and say so rather than adding the category here.

- [ ] **Step 2: Run and confirm failure**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: the first three fail; the fourth passes already.

- [ ] **Step 3: Resolve the clause**

In `modules/MacroManager.lua`, above `buildActiveBody`:

```lua
-- The targeting conditional for a category, or nil.
--
-- Only Battle Rez acts on someone other than the player. The category row holds
-- the static default; db.profile.categories[key].mouseover holds the user's
-- choice, defaulting on. `/use` accepts @unit conditionals exactly as `/cast`
-- does, so one clause covers both body forms.
--
-- The clause is deliberately `help` without `dead`: Soulstone is cast on a
-- LIVING ally, and `help` already matches dead friendly units, so one clause
-- serves the rez spells and Soulstone alike. Adding `dead` breaks Soulstone.
local function targetClauseFor(catKey)
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    if not (cat and cat.targeted) then return nil end
    local bucket = KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[catKey]
    if bucket and bucket.mouseover == false then return nil end
    return cat.targeted
end
```

- [ ] **Step 4: Thread it through the body builder**

`buildActiveBody` currently takes only `id`. Give it the clause:

```lua
local function buildActiveBody(id, clause)
    local prefix = clause and (clause .. " ") or ""
    if KCM.ID and KCM.ID.IsSpell(id) then
        local spellID = KCM.ID.SpellID(id)
        local name = spellNameFor(spellID)
        if name then return ("#showtooltip\n/cast %s%s"):format(prefix, name) end
        return ("#showtooltip\n/run print('%s spell %d name unavailable')"):format(KCM.PREFIX, spellID or 0)
    end
    return ("#showtooltip\n/use %sitem:%d"):format(prefix, id)
end
```

And in `M.BuildBody`:

```lua
function M.BuildBody(catKey, itemID)
    if itemID then return buildActiveBody(itemID, targetClauseFor(catKey)) end
    local cat = KCM.Categories and KCM.Categories.Get and KCM.Categories.Get(catKey)
    return buildEmptyBody(cat)
end
```

Leave the composite builders (`tokenForPick`, `actionLineForPick`) alone — neither new category is a composite or referenced by one.

- [ ] **Step 5: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green, with the existing body-shape tests at `tests/test_macromanager.lua:26` unchanged.

- [ ] **Step 6: Regenerate the inventory and bump the badge**

- [ ] **Step 7: Commit**

```bash
git add modules/MacroManager.lua tests/test_macromanager.lua docs/test-cases.md README.md
git commit -m "feat(macro): splice a category's targeting conditional into the body"
```

---

### Task 6: The mouseover toggle in the settings panel

**Files:**
- Modify: `settings/Category.lua` — `renderSingle` (line 296), reusing `makeCheckbox` (line 277)
- Test: `tests/test_settingsui.lua`

**Interfaces:**
- Consumes: `db.profile.categories.BATTLE_REZ.mouseover` and the `targeted` row field (both Task 4), read by `MacroManager` as of Task 5.

**Background:** `_validSections` in `settings/Panel.lua:127` is `{ general, macrobar }`, so the declarative schema cannot describe a per-category control. Category pages are built imperatively in `settings/Category.lua`; `makeCheckbox` at line 277 is the helper to use. `afterMutation(reason)` at line 102 is how the other controls fire a recompute so the macro rewrites immediately — use it, don't hand-roll a bus fire.

- [ ] **Step 1: Write the failing test**

Follow whatever introspection idiom `tests/test_settingsui.lua` already uses to assert a page's controls; the assertion to add is that a page for a category with a `targeted` field carries a checkbox bound to that category's `mouseover` key, and a page for one without it does not:

```lua
test("Settings: a targeted category page offers the mouseover toggle", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.Categories.Get("BATTLE_REZ").targeted, "Battle Rez is targeted")
    t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, true, "and defaults on")
    -- Assert the rendered page exposes the toggle, using this suite's existing
    -- page-introspection helper.
end)
```

- [ ] **Step 2: Run and confirm failure**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A2 FAIL`

- [ ] **Step 3: Render the checkbox**

In `renderSingle`, after the header block and before the priority list, guarded on the row field so it appears only for targeted categories:

```lua
    if cat.targeted then
        local bucket = KCM.db.profile.categories[cat.key]
        makeCheckbox(scroll, {
            label = "Cast on mouseover",
            desc  = "Rez whoever you are hovering (raid frame or corpse), "
                 .. "falling back to your target. Turn off to act on your target only.",
            value = bucket.mouseover ~= false,
            onChange = function(v)
                bucket.mouseover = v and true or false
                afterMutation("mouseover toggle")
            end,
        })
    end
```

Match `makeCheckbox`'s actual option names — read line 277 before writing this; the keys above are illustrative.

- [ ] **Step 4: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`

- [ ] **Step 5: Regenerate the inventory and bump the badge**

- [ ] **Step 6: Commit**

```bash
git add settings/Category.lua tests/test_settingsui.lua docs/test-cases.md README.md
git commit -m "feat(settings): expose the Battle Rez mouseover toggle"
```

---

### Task 7: In-game verification and docs

**Files:**
- Modify: `README.md` (category count and list), `docs/ARCHITECTURE.md` (the "What it does" paragraph naming every macro), `docs/module-map.md`, `defaults/README.md` (the seed-file table), `docs/smoke-tests.md`
- Possibly modify: `defaults/Defaults_Bloodlust.lua`, `defaults/Defaults_BattleRez.lua`, `core/TooltipCache.lua` (if the live drums phrasing doesn't match Task 1's patterns)

**This task cannot be completed by an agent alone.** Everything below needs a running client. If you cannot run WoW, do the doc edits, then hand the verification list to the user and say plainly that the IDs and the drums pattern are unverified — do not report the feature as done.

- [ ] **Step 1: Verify every seeded item in game**

For each itemID in both seed files:

```
/cm dump item <id>
```

Confirm the name matches the comment, and read the `usable:` line — it prints `minLevel` and the player's level, and after Task 1 should reflect the cap. For each drum, copy the **exact** cap sentence out of the tooltip.

- [ ] **Step 2: Reconcile the drums cap pattern**

If a drum's live wording is not matched by `maxLevelHigher` / `maxLevelAbove` from Task 1, add the real phrasing to `PATTERNS` and add a `tests/test_tooltipcache.lua` case using the exact captured line. Do not guess a third pattern speculatively — add only what a tooltip actually said.

- [ ] **Step 3: Collect the superseded drums itemIDs**

Task 4 shipped the seed with Void-Touched Drums and a placeholder comment. Collect the older drums' IDs (vendor, auction house, or `/cm dump item` on ones you own), confirm each, and fill them in newest-first.

- [ ] **Step 4: Verify the picks**

- Shaman: Bloodlust or Heroism resolves per faction. Mage: Time Warp. Evoker: Fury of the Aspects.
- Marksmanship hunter: Harrier's Cry. BM/Survival hunter: Primal Rage.
- A class with no lust and drums in bags: the drums resolve.
- The same character at max level with **only** an old capped drum: the Bloodlust slot shows the empty state, not the dead drum.
- Druid / DK / Paladin / Warlock: the correct rez spell resolves. Any class with Emergency Soul Link and no rez spell: the item resolves.

- [ ] **Step 5: Verify the macro bodies**

`/cm dump pick BLOODLUST` and `/cm dump pick BATTLE_REZ`, then open the macro and read the body. Rez a corpse by hovering its raid frame with no target selected. Toggle the mouseover checkbox off, confirm the body loses the clause, and confirm the macro then acts on your target.

- [ ] **Step 6: Update the docs**

- `README.md` — the category count and the category list. Check for any "thirteen"/"eleven" count claims.
- `docs/ARCHITECTURE.md` — the opening paragraph enumerates every macro name and counts them ("Thirteen account-wide global macros …", "Eleven macros run a per-category scorer"). Both numbers move.
- `docs/module-map.md` and `defaults/README.md` — add the two seed files to the table.
- `docs/smoke-tests.md` — add Step 4 and Step 5 above as a targeted section.

Grep for stale counts before finishing:

```bash
grep -rn "Thirteen\|thirteen\|Eleven\|eleven" README.md docs/ defaults/README.md
```

- [ ] **Step 7: Run the gate**

Run: `lua5.1 tests/run.lua && luacheck .`

- [ ] **Step 8: Commit**

```bash
git add README.md docs/ defaults/
git commit -m "docs: document the Bloodlust and Battle Rez categories"
```

---

## Verification the plan does not cover

The headless harness cannot see the vendored library, and this plan does not re-vendor `libs/LibKa0s/`, so the copy diff in [docs/testing.md](../../testing.md#verifying-the-vendored-libka0s-copies) is not needed.

Nothing in this plan touches the macro bar's secure frames, so the combat-lockdown paths are unaffected — but the two new slots do appear on the bar, so run the macro-bar section of [docs/smoke-tests.md](../../smoke-tests.md) once after Task 4.
