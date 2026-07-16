# Weapon Enchant & Vantus Rune Categories — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new auto-managed macro categories — a spec-aware **Weapon Enchant** (`WPN_ENCH`, main-hand + off-hand oils/stones) and a non-spec **Vantus Rune** (`VANTUS`) — to Consumable Master.

**Architecture:** Both follow the existing category pattern: a metadata row in `defaults/Categories.lua`, a matcher in `core/Classifier.lua`, a scorer in `modules/Ranker.lua`, a profile bucket in the AceDB defaults, and a settings tab (auto-registered from `Categories.LIST`, but the tab-order array is hardcoded and must be extended). `WPN_ENCH` reuses the existing stat-priority scorer (like `FLASK`) and needs one new macro-body shape; `VANTUS` reuses the default single-`/use` body.

**Tech Stack:** Lua 5.1, Ace3, headless test harness (`tests/run.lua`), `luacheck`.

## Global Constraints

- **Lua 5.1 / Ace3 / English-only.** subType and tooltip matching compare literal English strings.
- **Green gate (MUST, before every commit):** `lua5.1 tests/run.lua` all green **and** `luacheck .` 0 errors.
- **Static-badge Hard rule:** when the suite changes, regenerate `docs/test-cases.md` (`lua5.1 tests/run.lua --list > docs/test-cases.md`) and bump the README `![Tests]` badge count **in the same change**.
- **Never bump version.** Do NOT touch `KCM.VERSION`, the TOC `## Version:`, README badges other than `[Tests]` count, or add a Version History row. This feature ships in a future version chosen by the user.
- **Standard conformance:** conforms to the Ka0s WoW Addon Standard. If any step would deviate, STOP and flag it.
- **Git (project rule):** do NOT run `git add`/`commit` without the user's explicit go-ahead. The **Commit** steps below are checkpoints — pause for the user to commit (or confirm first). Commit commands are shown for reference.
- **Tab keys** are the category key lowercased (`VANTUS` → `vantus`, `WPN_ENCH` → `wpn_ench`).
- The headless runner has no per-case filter: "run the test" means `lua5.1 tests/run.lua` and read the `PASS`/`FAIL` line for the named case (pipe through `grep` on the case name if desired).

---

### Task 1: Category wiring (metadata, DB buckets, tab order, seeds, TOC)

Makes both categories exist end-to-end structurally: registered rows, profile buckets, settings tabs, seed lists. Without the DB buckets, `Selector.GetBucket` returns `nil` and the categories are inert; without the tab-order entries, their settings pages never render.

**Files:**
- Modify: `defaults/Categories.lua` (two new rows)
- Modify: `core/ConsumableMaster.lua:35-43` (two profile buckets)
- Modify: `settings/Panel.lua:26-32` (tab order + comment)
- Create: `defaults/Defaults_Vantus.lua`
- Create: `defaults/Defaults_WpnEnch.lua`
- Modify: `ConsumableMaster.toc` (two new defaults entries, after `defaults\Defaults_Flask.lua`)
- Test: `tests/test_categories.lua` (new suite)

**Interfaces:**
- Produces: category rows `KCM.Categories.Get("VANTUS")` and `KCM.Categories.Get("WPN_ENCH")`; seed lists `KCM.SEED.VANTUS` (= `{245880}`) and `KCM.SEED.WPN_ENCH` (= `{}`); profile buckets `KCM.db.profile.categories.VANTUS` and `.WPN_ENCH.bySpec`.

- [ ] **Step 1: Write the failing test** — create `tests/test_categories.lua`:

```lua
-- tests/test_categories.lua — new-category wiring: metadata, seeds, DB buckets.

local h = require("harness")
local test = h.test

test("Categories: VANTUS and WPN_ENCH registered with correct metadata and DB buckets", function(t)
    local KCM = h.loader.loadPure()

    local v = KCM.Categories.Get("VANTUS")
    t.truthy(v, "VANTUS category exists")
    t.eq(v.macroName, "KCM_VANTUS", "VANTUS macro name")
    t.eq(v.specAware, false, "VANTUS not spec-aware")

    local w = KCM.Categories.Get("WPN_ENCH")
    t.truthy(w, "WPN_ENCH category exists")
    t.eq(w.macroName, "KCM_WPN_ENCH", "WPN_ENCH macro name")
    t.eq(w.specAware, true, "WPN_ENCH spec-aware")

    -- DB default buckets must exist (Selector.GetBucket returns nil without them).
    t.truthy(KCM.db.profile.categories.VANTUS, "VANTUS profile bucket present")
    t.truthy(KCM.db.profile.categories.WPN_ENCH and KCM.db.profile.categories.WPN_ENCH.bySpec,
        "WPN_ENCH bySpec bucket present")

    -- VANTUS seed loaded and reaches the candidate set.
    local found = false
    for _, id in ipairs(KCM.Selector.BuildCandidateSet("VANTUS")) do
        if id == 245880 then found = true end
    end
    t.truthy(found, "VANTUS seed 245880 in candidate set")
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "VANTUS and WPN_ENCH registered"`
Expected: `FAIL` (VANTUS category is nil).

- [ ] **Step 3a: Add the two category rows** in `defaults/Categories.lua`.

Insert after the `HS` row (before `FLASK`):

```lua
    {
        key         = "VANTUS",
        macroName   = "KCM_VANTUS",
        displayName = "Vantus Rune",
        specAware   = false,
        rankerKey   = "VANTUS",
        classifier  = "VANTUS",
        emptyText   = emptyMacro("no vantus rune in bags"),
    },
```

Insert after the `STAT_FOOD` row (before `HP_AIO`):

```lua
    {
        key         = "WPN_ENCH",
        macroName   = "KCM_WPN_ENCH",
        displayName = "Weapon Enchant",
        specAware   = true,
        rankerKey   = "WPN_ENCH",
        classifier  = "WPN_ENCH",
        emptyText   = emptyMacro("no weapon enchant for this spec"),
    },
```

- [ ] **Step 3b: Add profile buckets** in `core/ConsumableMaster.lua`.

After the `HS = { added = {}, blocked = {}, pins = {}, discovered = {} },` line add:

```lua
            VANTUS    = { added = {}, blocked = {}, pins = {}, discovered = {} },
```

After the `FLASK     = { bySpec = {} },` line add:

```lua
            WPN_ENCH  = { bySpec = {} },
```

- [ ] **Step 3c: Extend the tab order** in `settings/Panel.lua`. Replace lines 26-32:

```lua
-- Canonical tab order. General + Stat Priority lead, then the ten single
-- categories, then the two composites — matches the CLAUDE.md panel order.
KCM.Settings.order = KCM.Settings.order or {
    "general", "statpriority",
    "food", "drink", "hp_pot", "mp_pot", "hs", "vantus",
    "flask", "cmbt_pot", "stat_food", "wpn_ench",
    "hp_aio", "mp_aio",
}
```

- [ ] **Step 3d: Create `defaults/Defaults_Vantus.lua`:**

```lua
-- defaults/Defaults_Vantus.lua — Seed list for KCM_VANTUS.
--
-- Universal per-raid Versatility rune (Inscription, weekly). One current rune
-- per raid tier; extend as new tiers ship. Confirm new itemIDs in-game via
-- `/cm dump item <id>` and add them to VANTUS_IDS in core/Classifier.lua too.
-- Source: Wowhead, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.VANTUS = {
    245880,  -- Vantus Rune: Radiant
}
```

- [ ] **Step 3e: Create `defaults/Defaults_WpnEnch.lua`:**

```lua
-- defaults/Defaults_WpnEnch.lua — Seed list for KCM_WPN_ENCH.
--
-- Temporary weapon enhancements (Enchanting oils; stones). Spec-aware: the
-- Ranker weights the enhancement's secondary stat against the active spec's
-- stat priority, so a caster's oil and a physical spec's stone sort correctly
-- from one list. Left empty by default — auto-discovery classifies weapon
-- enhancements from bags on the next scan. Add current-tier itemIDs here once
-- confirmed in-game via `/cm dump item <id>`.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.WPN_ENCH = {}
```

- [ ] **Step 3f: Register both defaults files** in `ConsumableMaster.toc`. After the `defaults\Defaults_Flask.lua` line add:

```
defaults\Defaults_Vantus.lua
defaults\Defaults_WpnEnch.lua
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "VANTUS and WPN_ENCH registered"`
Expected: `PASS`.

- [ ] **Step 5: Run the full gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: all cases pass; luacheck 0 errors.

- [ ] **Step 6: Commit** (pause for user go-ahead per the git rule)

```bash
git add defaults/Categories.lua core/ConsumableMaster.lua settings/Panel.lua \
        defaults/Defaults_Vantus.lua defaults/Defaults_WpnEnch.lua \
        ConsumableMaster.toc tests/test_categories.lua
git commit -m "Add VANTUS and WPN_ENCH category wiring (metadata, buckets, seeds, tabs)"
```

---

### Task 2: Classification (`core/Classifier.lua`)

`WPN_ENCH` matches temporary weapon enhancements by subType (like `FLASK`, subType-only, no tooltip gate). `VANTUS` matches by itemID whitelist (like `HS`, pre-tooltip).

**Files:**
- Modify: `core/Classifier.lua`
- Test: `tests/test_classifier.lua` (append cases)

**Interfaces:**
- Consumes: `KCM.Categories` rows from Task 1.
- Produces: `C.Match("WPN_ENCH", id)`, `C.Match("VANTUS", id)`; both appear in `C.MatchAny(id)`.

> **In-game confirmation (not a headless step):** the working subType literal is `"Weapon Enchantments"`. Verify the real Midnight value via `/cm dump item <id>` on an oil; if different, update the `ST_WEAPON_OIL` constant **and** the test literal together (single-constant change, same as `ST_FLASK_PHIAL`). The unit test pins the matcher logic, not the real-world string.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_classifier.lua`:

```lua
-- ---- WPN_ENCH: weapon-oil subType, subtype-only (empty tt ok) -------------
test("classifier: WPN_ENCH matches weapon-enhancement subtype on subtype alone", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    mock.setItem(1901, { subType = "Weapon Enchantments", tt = {} })
    t.truthy(C.Match("WPN_ENCH", 1901), "WPN_ENCH positive with empty tt")
    t.eqList(C.MatchAny(1901), { "WPN_ENCH" }, "MatchAny weapon oil -> {WPN_ENCH}")

    -- negative: a flask is not a weapon enchant
    mock.setItem(1902, { subType = "Flasks & Phials", tt = {} })
    t.falsy(C.Match("WPN_ENCH", 1902), "WPN_ENCH negative for flask subtype")
end)

-- ---- VANTUS: hard-coded itemIDs regardless of tt -------------------------
test("classifier: VANTUS matches whitelisted rune IDs regardless of item data", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    t.truthy(C.Match("VANTUS", 245880), "VANTUS positive 245880 (no item data)")
    t.contains(C.MatchAny(245880), "VANTUS", "MatchAny includes VANTUS for 245880")

    -- negative: an ordinary item id is not a vantus rune
    mock.setItem(1951, { subType = "Potions", tt = { healValue = 4000 } })
    t.falsy(C.Match("VANTUS", 1951), "VANTUS negative for ordinary potion")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "WPN_ENCH matches|VANTUS matches"`
Expected: both `FAIL` (matchers not defined).

- [ ] **Step 3a: Add constants** in `core/Classifier.lua`, in the Constants block. After `local ST_FLASK_PHIAL = "Flasks & Phials"` add:

```lua
-- Temporary weapon enhancements (oils / stones). Confirm the exact Midnight
-- subType in-game via /cm dump item; single-constant update if Blizzard differs.
local ST_WEAPON_OIL = "Weapon Enchantments"
```

After the `HEALTHSTONE_IDS` table add:

```lua
-- Vantus runes share a generic subType, so match by itemID like healthstones.
-- One universal rune per raid tier; keep in sync with Defaults_Vantus.lua.
local VANTUS_IDS = {
    [245880] = true,  -- Vantus Rune: Radiant
}
```

- [ ] **Step 3b: Add matchers** to the `matchers` table (after `FLASK`):

```lua
    WPN_ENCH = function(_, _, subType)
        return subType == ST_WEAPON_OIL
    end,
    VANTUS = function(itemID)
        return VANTUS_IDS[itemID] == true
    end,
```

- [ ] **Step 3c: Route both in `C.Match`.** After the existing `HS` early-return block:

```lua
    if catKey == "HS" then
        return isHealthstone(itemID)
    end
    if catKey == "VANTUS" then
        return VANTUS_IDS[itemID] == true
    end
```

And extend the subType-only block from `FLASK` to also cover `WPN_ENCH`:

```lua
    if catKey == "FLASK" or catKey == "WPN_ENCH" then
        return fn(itemID, nil, subType) == true
    end
```

- [ ] **Step 4: Run to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "WPN_ENCH matches|VANTUS matches"`
Expected: both `PASS`.

- [ ] **Step 5: Full gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green; 0 lint errors.

- [ ] **Step 6: Commit** (pause for user go-ahead)

```bash
git add core/Classifier.lua tests/test_classifier.lua
git commit -m "Classify weapon enchants (subType) and vantus runes (itemID whitelist)"
```

---

### Task 3: Scoring (`modules/Ranker.lua`)

`WPN_ENCH` reuses `scoreByStatPriority` + ilvl/quality (identical to `FLASK`). `VANTUS` scores on ilvl + quality (newest tier wins). Both get `Explain` coverage.

**Files:**
- Modify: `modules/Ranker.lua`
- Test: `tests/test_ranker.lua` (append cases)

**Interfaces:**
- Consumes: `ctx.specPriority = { primary = "...", secondary = { ... } }` for `WPN_ENCH`.
- Produces: `R.Score("WPN_ENCH", id, ctx)`, `R.Score("VANTUS", id)`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_ranker.lua`:

```lua
test("Ranker: WPN_ENCH stat-aware primary buff outweighs equal-amount secondary", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    local sp = { primary = "STR", secondary = { "CRIT", "HASTE", "MASTERY" } }  -- N = 3
    mock.setItem(4301, { subType = "Weapon Enchantments", quality = 4, ilvl = 30,
        tt = { statBuffs = { { stat = "STR",  amount = 5 } } } })
    mock.setItem(4302, { subType = "Weapon Enchantments", quality = 4, ilvl = 30,
        tt = { statBuffs = { { stat = "CRIT", amount = 5 } } } })
    local ctxSpec = { specPriority = sp }
    local prim = R.Score("WPN_ENCH", 4301, ctxSpec, nil)
    local sec  = R.Score("WPN_ENCH", 4302, ctxSpec, nil)
    t.eq(prim, 1000 * 5 + 30 + 400, "WPN_ENCH primary buff score")
    t.eq(sec,  300 * 5 + 30 + 400, "WPN_ENCH secondary buff score")
    t.truthy(prim > sec, "primary-stat weapon enchant beats equal-amount secondary")
end)

test("Ranker: VANTUS prefers higher ilvl (current tier) then quality", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker
    mock.setItem(4401, { subType = "Other", quality = 4, ilvl = 600, tt = {} })  -- current tier
    mock.setItem(4402, { subType = "Other", quality = 4, ilvl = 500, tt = {} })  -- old tier
    local cur = R.Score("VANTUS", 4401, nil, nil)
    local old = R.Score("VANTUS", 4402, nil, nil)
    t.eq(cur, 600 + 400, "VANTUS current-tier score = ilvl + quality*100")
    t.eq(old, 500 + 400, "VANTUS old-tier score")
    t.truthy(cur > old, "higher-ilvl vantus rune wins")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "WPN_ENCH stat-aware|VANTUS prefers"`
Expected: both `FAIL` (scorers return 0 → assertion mismatch).

- [ ] **Step 3a: Add scorers** in the `scorers` table (after `FLASK`):

```lua
    WPN_ENCH = function(itemID, ctx, scoreCache)
        local quality, ilvl, _, tt = itemFields(itemID, scoreCache)
        return scoreByStatPriority(tt, ctx and ctx.specPriority)
             + ilvl
             + quality * QUALITY_WEIGHT
    end,
    VANTUS = function(itemID, ctx, scoreCache)
        local quality, ilvl = itemFields(itemID, scoreCache)
        return ilvl + quality * QUALITY_WEIGHT
    end,
```

- [ ] **Step 3b: Extend `R.Explain`.** Add `WPN_ENCH` to the stat-aware branch condition:

```lua
    if catKey == "STAT_FOOD" or catKey == "CMBT_POT" or catKey == "FLASK" or catKey == "WPN_ENCH" then
```

And add a `VANTUS` branch immediately after the `HS` branch's `end`:

```lua
    if catKey == "VANTUS" then
        pushBase()
        result.score   = ilvl + qualityScore
        result.summary = "Current-tier rune preferred (ilvl + quality)."
        return result
    end
```

- [ ] **Step 4: Run to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "WPN_ENCH stat-aware|VANTUS prefers"`
Expected: both `PASS`.

- [ ] **Step 5: Full gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green; 0 lint errors.

- [ ] **Step 6: Commit** (pause for user go-ahead)

```bash
git add modules/Ranker.lua tests/test_ranker.lua
git commit -m "Score weapon enchants by spec stat priority; vantus runes by tier"
```

---

### Task 4: Macro body (`modules/MacroManager.lua`)

`WPN_ENCH` needs a two-slot body (main-hand 16 + off-hand 17). `VANTUS` uses the default single-`/use` body — verify it's unchanged. The `buildActiveBody` local gains a `catKey` parameter (single caller).

**Files:**
- Modify: `modules/MacroManager.lua`
- Test: `tests/test_macromanager.lua` (append cases)

**Interfaces:**
- Consumes: `M.BuildBody(catKey, itemID)`.
- Produces: `WPN_ENCH` item body `#showtooltip\n/use item:<id>\n/use 16\n/use item:<id>\n/use 17`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_macromanager.lua`:

```lua
test("MacroManager: BuildBody emits the two-slot weapon-enchant body for WPN_ENCH", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M.BuildBody("WPN_ENCH", 245678),
        "#showtooltip\n/use item:245678\n/use 16\n/use item:245678\n/use 17",
        "WPN_ENCH item pick → ready + apply to slots 16 and 17")
end)

test("MacroManager: BuildBody VANTUS uses the default single /use body", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M.BuildBody("VANTUS", 245880), "#showtooltip\n/use item:245880",
        "VANTUS item pick → default single /use item body")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "two-slot weapon-enchant|VANTUS uses the default"`
Expected: `two-slot weapon-enchant` = `FAIL`; `VANTUS uses the default` = `PASS` (VANTUS already works via the default path — that's the point; keep it as a regression guard).

- [ ] **Step 3a: Thread `catKey` into `buildActiveBody`.** Replace the whole `buildActiveBody` function (lines ~58-69):

```lua
local function buildActiveBody(catKey, id)
    if KCM.ID and KCM.ID.IsSpell(id) then
        local spellID = KCM.ID.SpellID(id)
        local name = spellNameFor(spellID)
        if name then return ("#showtooltip\n/cast %s"):format(name) end
        -- Spell name not yet resolvable (very rare — would imply the spell
        -- book hasn't hydrated). Emit a user-visible stub so the macro
        -- exists and the failure is observable rather than silent.
        return ("#showtooltip\n/run print('%s spell %d name unavailable')"):format(KCM.PREFIX, spellID or 0)
    end
    -- Weapon enchants apply to a weapon slot: ready the item, apply to main-hand
    -- (16), ready again, apply to off-hand (17). The off-hand line harmlessly
    -- no-ops when the off-hand can't take an enhancement (2H / shield / empty).
    if catKey == "WPN_ENCH" then
        return ("#showtooltip\n/use item:%d\n/use 16\n/use item:%d\n/use 17"):format(id, id)
    end
    return ("#showtooltip\n/use item:%d"):format(id)
end
```

- [ ] **Step 3b: Update the caller** in `M.BuildBody` (line ~83):

```lua
    if itemID then return buildActiveBody(catKey, itemID) end
```

- [ ] **Step 4: Run to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "two-slot weapon-enchant|VANTUS uses the default"`
Expected: both `PASS`.

- [ ] **Step 5: Full gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green; 0 lint errors.

- [ ] **Step 6: Commit** (pause for user go-ahead)

```bash
git add modules/MacroManager.lua tests/test_macromanager.lua
git commit -m "Build two-slot (main + off hand) macro body for weapon enchants"
```

---

### Task 5: Settings copy, docs, test inventory + badge

Player-facing and contributor docs reflect ten single categories and four spec-aware ones; regenerate the test inventory and bump the `[Tests]` badge (Hard rule).

**Files:**
- Modify: `settings/StatPriority.lua:6,203`
- Modify: `README.md` (macro table + counts)
- Modify: `docs/scope.md:7`, `docs/module-map.md:59`, `docs/smoke-tests.md:108`
- Modify: `docs/test-cases.md` (regenerated)
- Modify: `README.md` (`[Tests]` badge)

- [ ] **Step 1: Update `settings/StatPriority.lua`.**

Line 6 comment — replace `--   spec-aware category panels (Flask, Stat Food) read it on each render.` with:

```lua
--   spec-aware category panels (Stat Food, Combat Potion, Flask, Weapon Enchant)
--   read it on each render.
```

Line 203 tooltip — replace the string with:

```lua
        tooltip = L["Select which spec's stat priority you want to edit. This also determines which spec's priority list is shown on the Stat Food, Combat Potion, Flask, and Weapon Enchant tabs."],
```

> If `L[...]` requires the key to exist in `locales/enUS.lua`, add the new string there mirroring the old key's entry. Check with: `grep -n "shown on the Stat Food" locales/enUS.lua`. If the old string is a key in enUS, replace it there too (same new text).

- [ ] **Step 2: Update `README.md` counts and table.**

Line 11: `across eight categories` → `across ten categories`.
Line 92: `the three spec-aware categories (Stat Food, Combat Potion, Flask)` → `the four spec-aware categories (Stat Food, Combat Potion, Flask, Weapon Enchant)`.
Line 94: `shown on the three spec-aware category pages` → `shown on the four spec-aware category pages`.
Line 101: `Each of the eight single macros` → `Each of the ten single macros`.
Line 114: `Two combo pages (after Stat Food).` → `Two combo pages (after Weapon Enchant).`
(Leave line 176 — the 1.0.0 history entry — unchanged; it correctly describes the 1.0.0 release.)

Replace the macro table (the 10-row table at lines ~15-26) with this 12-row version:

```markdown
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
| 10 |Weapon enchant (oil / stone, main + off hand)                |<code>KCM_WPN_ENCH</code> |<strong>Yes</strong> |
| 11 |All-in-one health (combat: HS → HP pot, out of combat: food) |<code>KCM_HP_AIO</code> |No          |
| 12 |All-in-one mana (combat: MP pot, out of combat: drink)       |<code>KCM_MP_AIO</code> |No          |
```

- [ ] **Step 3: Update the other docs.**

`docs/scope.md:7` — `eight single-pick categories (FOOD, DRINK, HP_POT, MP_POT, HS, FLASK, CMBT_POT, STAT_FOOD)` → `ten single-pick categories (FOOD, DRINK, HP_POT, MP_POT, HS, VANTUS, FLASK, CMBT_POT, STAT_FOOD, WPN_ENCH)`.

`docs/module-map.md:59` — `which of the 8 single-pick categories` → `which of the 10 single-pick categories`.

`docs/smoke-tests.md:108` — `all 12 sub-pages visible (General, Stat Priority, 8 categories, 2 AIO)` → `all 14 sub-pages visible (General, Stat Priority, 10 categories, 2 AIO)`.

- [ ] **Step 4: Regenerate the test inventory and bump the badge.**

Run: `lua5.1 tests/run.lua --list > docs/test-cases.md`
Then read the pass total: `lua5.1 tests/run.lua 2>&1 | tail -1` → note `N passed, 0 failed, N total`.
Update the README `[Tests]` badge to the new total (was `109%2F109`): set line 7 to
`![Tests](https://img.shields.io/badge/Tests-<N>%2F<N>_passing-green)` with `<N>` = the reported total.

Confirm sync: `diff <(lua5.1 tests/run.lua --list) docs/test-cases.md` → no output.

- [ ] **Step 5: Full gate**

Run: `lua5.1 tests/run.lua && luacheck .`
Expected: green; 0 lint errors.

- [ ] **Step 6: Commit** (pause for user go-ahead)

```bash
git add settings/StatPriority.lua locales/enUS.lua README.md \
        docs/scope.md docs/module-map.md docs/smoke-tests.md docs/test-cases.md
git commit -m "Sync docs, settings copy, and test inventory for the two new categories"
```

---

## Post-implementation (in-game, tracked separately)

These need a live client and are **not** part of the headless gate — smoke-test items (see `docs/smoke-tests.md`):

1. Confirm the Midnight weapon-oil `GetItemInfoInstant` subType; if it isn't `"Weapon Enchantments"`, update `ST_WEAPON_OIL` + the classifier test literal together.
2. Confirm current-tier Vantus itemID(s) beyond `245880`; extend `VANTUS_IDS` + `Defaults_Vantus.lua`.
3. In-game: loot an oil → `KCM_WPN_ENCH` picks it per spec; the macro applies to both weapons; a proc-only oil can be pinned. Loot/craft the rune → `KCM_VANTUS` uses it.

## Self-review notes

- **Spec coverage:** category metadata (T1), classification (T2), scoring incl. Explain (T3), two-slot macro body (T4), spec-aware integration + docs + badge (T1 tab order / T5 copy) — all spec sections map to a task.
- **Type consistency:** `buildActiveBody(catKey, id)` signature change has exactly one caller (`M.BuildBody`), updated in T4. Category keys `VANTUS`/`WPN_ENCH` and macro names `KCM_VANTUS`/`KCM_WPN_ENCH` are used identically across all tasks.
- **DB-bucket dependency:** `Selector.GetBucket` returns nil without a profile bucket → the T1 buckets are load-bearing, asserted by the T1 test.
