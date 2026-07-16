# Augment Rune category — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `AUG_RUNE`, a 13th managed macro category for augment runes, seeded across Dragonflight / The War Within / Midnight and auto-discovering the rest, with reusable ("permanent") runes breaking ties over consumable ones.

**Architecture:** `AUG_RUNE` is a plain single-pick category — the same shape as `VANTUS`, no new pipeline path and no `MacroManager` change (the default `#showtooltip\n/use item:%d` body already applies). Classification uses a new `TooltipCache.isAugmentRune` flag (auto-discovery, like `WPN_ENCH`) plus the seed list. Ranking is amount-first with a reusable tiebreak, driven by a new `Primary Stat` stat token and an explicit `REUSABLE_AUG_IDS` set that mirrors `VANTUS_IDS`.

**Tech Stack:** Lua 5.1, Ace3, headless harness (`tests/run.lua`), luacheck.

## Global Constraints

- **Lua 5.1 / Ace3 / English-only** tooltip + subtype matching (existing convention).
- **Green gate before every commit:** `lua5.1 tests/run.lua` all pass AND `luacheck .` 0 warnings / 0 errors.
- **Static-badge Hard rule:** when the suite changes, regenerate `docs/test-cases.md` (`lua5.1 tests/run.lua --list > docs/test-cases.md`) and bump the README `[Tests]` badge count in the same change. Current baseline: **125/125**.
- **Never bump the addon version** (no `KCM.VERSION` / TOC Version / README version-history / `[WoW]` badge).
- **Git:** incremental commits are authorized for this session. The controller commits each task **after it passes review** (implementers leave work in the working tree; do NOT run `git add`/`commit` yourself). Stay on `master`.
- **Weight ladder (exact values):** `AUG_STAT_WEIGHT = 1e4`, `REUSABLE_BONUS = 1e3`; existing `QUALITY_WEIGHT = 100` (max contribution 5 × 100 = 500 < `REUSABLE_BONUS`). `Ranker.statWeight` MUST keep returning 0 for the `PRIMARY` tag so `STAT_FOOD` / `FLASK` ranking cannot move.
- **Reusable ID set (exact):** `[211495]` Dreambound, `[243191]` Ethereal. No others.
- **Category is #13:** 12 categories today (10 single-pick + 2 composite). Inserted after `WPN_ENCH`, before the two composites, in every ordered list.
- The headless runner has no per-case filter: "run the test" = `lua5.1 tests/run.lua` and read the `PASS`/`FAIL` line for the named case.

---

### Task 1: Parse "Primary Stat" amount + augment-rune marker (`TooltipCache`)

**Files:**
- Modify: `core/TooltipCache.lua` (STAT_TOKENS + `parseLines`)
- Test: `tests/test_tooltipcache.lua`

**Interfaces:**
- Produces: tooltip `statBuffs` entries with `stat="PRIMARY"` for "Increases Primary Stat by N"; `result.isAugmentRune = true` when a tooltip line is exactly the `Augment Rune` category marker.

- [ ] **Step 1: Write failing tests** — append to `tests/test_tooltipcache.lua`:

```lua
test("TooltipCache: parses 'Primary Stat' as a PRIMARY stat buff", function(t)
    local TC, mock = newTC()
    local rune = parse(TC, mock, 243191, {
        "Ethereal Augment Rune",
        "Use: Increases Primary Stat by 733 for 1 hour.",
        "Augment Rune",
    })
    t.eq(#rune.statBuffs, 1, "one stat buff parsed")
    t.eq(rune.statBuffs[1].stat, "PRIMARY", "Primary Stat -> PRIMARY")
    t.eq(rune.statBuffs[1].amount, 733, "PRIMARY amount")
    t.truthy(rune.hasStatBuff, "hasStatBuff set")
end)

test("TooltipCache: sets isAugmentRune from the category marker line", function(t)
    local TC, mock = newTC()
    local rune = parse(TC, mock, 259085, {
        "Void-Touched Augment Rune",
        "Use: Increases Primary Stat by 900 for 1 hour.",
        "Augment Rune",
    })
    t.truthy(rune.isAugmentRune, "marker line -> isAugmentRune")

    -- Negative: a flask that merely NAMES a stat is not an augment rune.
    local flask = parse(TC, mock, 212283, {
        "Flask of Tempered Aggression",
        "Use: Increases your Strength by 1,000 for 1 hour.",
    })
    t.falsy(flask.isAugmentRune, "no marker line -> not an augment rune")
end)
```

- [ ] **Step 2: Run — expect FAIL**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "Primary Stat|isAugmentRune from"`
Expected: both FAIL (`PRIMARY` tag unknown; `isAugmentRune` nil).

- [ ] **Step 3a:** In `core/TooltipCache.lua`, add to the `STAT_TOKENS` table (near the other multi-word tokens, after the `Spell Power` entry):

```lua
    { token = "Primary Stat",    tag = "PRIMARY"     },
```

- [ ] **Step 3b:** In `core/TooltipCache.lua` `parseLines`, inside the `if txt ~= "" then` block, add the marker detection immediately after the `feastSubstr` line (`if txt:find(PATTERNS.feastSubstr, 1, true) then result.isFeast = true end`):

```lua
            -- Augment runes carry an "Augment Rune" category marker line
            -- (the game's own one-active-at-a-time tag). Match the line
            -- exactly (optional trailing period) so the item's NAME line —
            -- e.g. "Ethereal Augment Rune" — does not trip it.
            if txt:match("^Augment Rune%.?$") then result.isAugmentRune = true end
```

- [ ] **Step 3c:** In `core/TooltipCache.lua`, update the field-list header comment (around the `weaponAffinity` line) to document the new flag. After the `isConjured, isFeast, isWeaponEnhance` line add:

```lua
--   isAugmentRune                  -- true if tooltip carries the "Augment Rune" marker
```

- [ ] **Step 4: Run — expect PASS** (`lua5.1 tests/run.lua 2>&1 | grep -E "Primary Stat|isAugmentRune from"`)
- [ ] **Step 5: Gate** — `lua5.1 tests/run.lua && luacheck .` (green; confirm the pre-existing count rose by exactly 2 and nothing else changed)
- [ ] **Step 6:** Report DONE; controller reviews + commits.

---

### Task 2: Classify augment runes (`Classifier`)

**Files:**
- Modify: `core/Classifier.lua` (`REUSABLE_AUG_IDS`, `matchers.AUG_RUNE`, expose reusable helper)
- Test: `tests/test_classifier.lua`

**Interfaces:**
- Consumes: `tt.isAugmentRune` from Task 1.
- Produces: `Classifier.Match("AUG_RUNE", id)` true for any tooltip with `isAugmentRune`; `KCM.Classifier.IsReusableAugRune(itemID) -> boolean` for the Ranker (Task 3).

- [ ] **Step 1: Write failing tests** — append to `tests/test_classifier.lua`:

```lua
-- ---- AUG_RUNE: tooltip marker, plus reusable-ID helper --------------------
test("classifier: AUG_RUNE matches any augment-rune tooltip; reusable helper", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local C    = KCM.Classifier

    -- Seeded consumable rune.
    mock.setItem(224572, { subType = "Other", tt = { isAugmentRune = true } })
    t.truthy(C.Match("AUG_RUNE", 224572), "AUG_RUNE positive via marker")
    t.contains(C.MatchAny(224572), "AUG_RUNE", "MatchAny includes AUG_RUNE")

    -- Unseeded future rune — auto-discovered by the same marker.
    mock.setItem(999999, { subType = "Other", tt = { isAugmentRune = true } })
    t.truthy(C.Match("AUG_RUNE", 999999), "AUG_RUNE positive for unseeded rune")

    -- Negative: ordinary flask is not an augment rune.
    mock.setItem(1961, { subType = "Flasks & Phials", tt = {} })
    t.falsy(C.Match("AUG_RUNE", 1961), "AUG_RUNE negative for flask")

    -- Reusable helper: explicit set, not tooltip-driven.
    t.truthy(C.IsReusableAugRune(243191), "Ethereal is reusable")
    t.truthy(C.IsReusableAugRune(211495), "Dreambound is reusable")
    t.falsy(C.IsReusableAugRune(224572), "Crystallized is consumable")
    t.falsy(C.IsReusableAugRune(nil), "nil is not reusable")
end)
```

- [ ] **Step 2: Run — expect FAIL** (`lua5.1 tests/run.lua 2>&1 | grep "AUG_RUNE matches any"`) — matcher + helper undefined.

- [ ] **Step 3a:** In `core/Classifier.lua`, after the `VANTUS_IDS` block (line ~44), add:

```lua
-- Augment runes carry an "Augment Rune" tooltip marker (tt.isAugmentRune),
-- so match by tooltip like weapon enhancements — this auto-discovers future
-- runes. Reusable ("permanent") runes are NOT tooltip-distinguishable, so
-- they're an explicit set, mirroring VANTUS_IDS. Keep in sync with
-- Defaults_AugRune.lua.
local REUSABLE_AUG_IDS = {
    [211495] = true,  -- Dreambound Augment Rune (DF 10.2)
    [243191] = true,  -- Ethereal Augment Rune   (TWW 11.2)
}
```

- [ ] **Step 3b:** In `core/Classifier.lua`, add to the `matchers` table (after the `WPN_ENCH` matcher, before `VANTUS`):

```lua
    AUG_RUNE = function(_, tt)
        return tt and tt.isAugmentRune == true
    end,
```

- [ ] **Step 3c:** In `core/Classifier.lua`, expose the reusable helper on the public API (near the bottom, beside the other `C.` functions):

```lua
-- Reusable augment runes are not consumed on use. The Ranker uses this to
-- break score ties toward the reusable rune. Explicit set — no tooltip signal.
function C.IsReusableAugRune(itemID)
    return REUSABLE_AUG_IDS[itemID] == true
end
```

`AUG_RUNE` needs no early-return branch in `C.Match` (unlike HS / VANTUS): it flows through the tooltip-gated path exactly like `WPN_ENCH`, so seeded and unseeded runes both hydrate through the same retry seam.

- [ ] **Step 4: Run — expect PASS.** **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 3: Score augment runes (`Ranker`)

**Files:**
- Modify: `modules/Ranker.lua` (weights, `AUG_RUNE` scorer, `Explain` branch, `_augAmount` export)
- Test: `tests/test_ranker.lua`

**Interfaces:**
- Consumes: `Classifier.IsReusableAugRune` from Task 2; `tt.statBuffs` from Task 1.
- Produces: `Ranker.Score("AUG_RUNE", id, ctx, scoreCache)` returning `amount*1e4 + reusable*1e3 + ilvl + quality*100`.

- [ ] **Step 1: Write failing tests** — append to `tests/test_ranker.lua`:

```lua
test("Ranker: AUG_RUNE ranks by amount, reusable breaks ties, amount dominates", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker

    -- Ethereal (reusable) vs Crystallized (consumable), both 733 primary.
    mock.setItem(243191, { subType = "Other", quality = 4, ilvl = 1, tt = { statBuffs = { { stat = "PRIMARY", amount = 733 } } } })
    mock.setItem(224572, { subType = "Other", quality = 4, ilvl = 1, tt = { statBuffs = { { stat = "PRIMARY", amount = 733 } } } })
    local eth = R.Score("AUG_RUNE", 243191, nil, nil)
    local cry = R.Score("AUG_RUNE", 224572, nil, nil)
    t.eq(eth, 733 * 1e4 + 1e3 + 1 + 400, "Ethereal = amount + reusable + ilvl + quality")
    t.eq(cry, 733 * 1e4 + 0   + 1 + 400, "Crystallized = amount + ilvl + quality")
    t.truthy(eth > cry, "reusable breaks the 733 tie")

    -- Void-Touched (consumable, larger) beats Ethereal (reusable, 733).
    mock.setItem(259085, { subType = "Other", quality = 4, ilvl = 1, tt = { statBuffs = { { stat = "PRIMARY", amount = 900 } } } })
    t.truthy(R.Score("AUG_RUNE", 259085, nil, nil) > eth, "larger amount dominates reusable bonus")

    -- Quality can NOT override the reusable bonus at equal amount: the
    -- consumable epic (q4) 733 (Crystallized, cry above) must still lose to
    -- the reusable Ethereal. cry already carries the max quality contribution
    -- (q4 -> 400), so eth > cry proves REUSABLE_BONUS (1e3) outranks it.
    t.truthy(eth - cry == 1e3, "reusable bonus (1e3) is exactly the gap; outranks max quality (500)")

    -- Dragonflight phrasing: STR/AGI/INT triplet -> amount = max of them.
    mock.setItem(201325, { subType = "Other", quality = 3, ilvl = 1, tt = { statBuffs = {
        { stat = "STR", amount = 80 }, { stat = "AGI", amount = 80 }, { stat = "INT", amount = 80 } } } })
    t.eq(R.Score("AUG_RUNE", 201325, nil, nil), 80 * 1e4 + 0 + 1 + 300, "DF rune amount = max(STR,AGI,INT)")

    -- Pending tooltip (no statBuffs) -> amount 0, degrades to reusable-first.
    mock.setItem(800001, { subType = "Other", quality = 1, ilvl = 1, tt = { statBuffs = {} } })
    t.eq(R.Score("AUG_RUNE", 800001, nil, nil), 0 + 0 + 1 + 100, "no stat -> base score only")
end)
```

- [ ] **Step 2: Run — expect FAIL** (`lua5.1 tests/run.lua 2>&1 | grep "AUG_RUNE ranks by amount"`) — no `AUG_RUNE` scorer.

- [ ] **Step 3a:** In `modules/Ranker.lua`, add the weights next to `QUALITY_WEIGHT` (line ~38):

```lua
-- Augment runes rank by primary-stat amount first; a reusable rune breaks
-- ties (bonus > max quality contribution of 5*QUALITY_WEIGHT = 500) but is
-- always overridden by a strictly larger amount (amount weight >> bonus).
local AUG_STAT_WEIGHT = 1e4
local REUSABLE_BONUS  = 1e3
```

- [ ] **Step 3b:** In `modules/Ranker.lua`, add a private amount helper next to the other tooltip helpers (after `potAmount`, before the scorers block):

```lua
-- Primary-stat amount an augment rune grants. Modern runes report a single
-- "Primary Stat" line (stat="PRIMARY"); Dragonflight-era runes report the
-- STR/AGI/INT triplet, all equal, so the max is the per-stat value. 0 when
-- the tooltip has not hydrated.
local function augAmount(tt)
    local best = 0
    for _, sb in ipairs(tt and tt.statBuffs or {}) do
        if sb.stat == "PRIMARY" or sb.stat == "STR" or sb.stat == "AGI" or sb.stat == "INT" then
            if (sb.amount or 0) > best then best = sb.amount end
        end
    end
    return best
end
```

- [ ] **Step 3c:** In `modules/Ranker.lua`, add the scorer to the `scorers` table (after `VANTUS`):

```lua
    AUG_RUNE = function(itemID, ctx, scoreCache)
        local quality, ilvl, _, tt = itemFields(itemID, scoreCache)
        local reusable = KCM.Classifier and KCM.Classifier.IsReusableAugRune(itemID)
        return augAmount(tt) * AUG_STAT_WEIGHT
             + (reusable and REUSABLE_BONUS or 0)
             + ilvl
             + quality * QUALITY_WEIGHT
    end,
```

- [ ] **Step 3d:** In `modules/Ranker.lua` `Explain`, add an `AUG_RUNE` branch before the `STAT_FOOD/CMBT_POT/FLASK/WPN_ENCH` block (after the `VANTUS` branch, line ~439):

```lua
    if catKey == "AUG_RUNE" then
        local amount   = augAmount(tt)
        local reusable = KCM.Classifier and KCM.Classifier.IsReusableAugRune(itemID)
        table.insert(result.signals, { label = "primary stat", value = amount * AUG_STAT_WEIGHT, note = ("amount %d"):format(amount) })
        table.insert(result.signals, { label = "reusable bonus", value = reusable and REUSABLE_BONUS or 0, note = reusable and "not consumed on use" or "consumable" })
        pushBase()
        result.score   = amount * AUG_STAT_WEIGHT + (reusable and REUSABLE_BONUS or 0) + ilvl + qualityScore
        result.summary = "Highest primary-stat amount wins; reusable runes break ties."
        return result
    end
```

- [ ] **Step 3e:** In `modules/Ranker.lua`, export the helper for tests/debug next to the other `R._` exports (line ~476):

```lua
R._augAmount = augAmount
```

- [ ] **Step 4: Run — expect PASS.** **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 4: Category wiring — metadata, DB bucket, tab, seed, TOC

**Files:**
- Create: `defaults/Defaults_AugRune.lua`
- Modify: `defaults/Categories.lua` (row), `core/ConsumableMaster.lua` (profile bucket), `settings/Panel.lua` (tab order + comment), `ConsumableMaster.toc` (one line)
- Test: `tests/test_categories.lua`

**Interfaces:**
- Consumes: nothing from prior tasks (wiring only).
- Produces: `Categories.Get("AUG_RUNE")` row; `db.profile.categories.AUG_RUNE` bucket; `KCM.SEED.AUG_RUNE` seed reaching `Selector.BuildCandidateSet("AUG_RUNE")`.

- [ ] **Step 1: Write failing test** — append to `tests/test_categories.lua`:

```lua
test("Categories: AUG_RUNE registered with metadata, DB bucket, and seed", function(t)
    local KCM = h.loader.loadPure()

    local a = KCM.Categories.Get("AUG_RUNE")
    t.truthy(a, "AUG_RUNE category exists")
    t.eq(a.macroName, "KCM_AUG_RUNE", "AUG_RUNE macro name")
    t.eq(a.specAware, false, "AUG_RUNE not spec-aware")
    t.falsy(a.composite, "AUG_RUNE not composite")
    t.falsy(a.perHand, "AUG_RUNE not per-hand")

    t.truthy(KCM.db.profile.categories.AUG_RUNE, "AUG_RUNE profile bucket present")

    local found = false
    for _, id in ipairs(KCM.Selector.BuildCandidateSet("AUG_RUNE")) do
        if id == 243191 then found = true end
    end
    t.truthy(found, "AUG_RUNE seed 243191 (Ethereal) in candidate set")
end)
```

- [ ] **Step 2: Run — expect FAIL** (`lua5.1 tests/run.lua 2>&1 | grep "AUG_RUNE registered"`).

- [ ] **Step 3a:** Create `defaults/Defaults_AugRune.lua`:

```lua
-- defaults/Defaults_AugRune.lua — Seed list for KCM_AUG_RUNE.
--
-- Augment runes — a one-active-at-a-time primary-stat buff (1 hour, lost on
-- death). "Permanent" runes (Ethereal, Dreambound) are not permanently
-- buffed; they are simply NOT consumed on use, so they're reusable. The
-- Ranker ranks by primary-stat amount and breaks ties toward reusable runes
-- (see REUSABLE_AUG_IDS in core/Classifier.lua). Runes report a generic
-- subType, so the Classifier keys on the tooltip's "Augment Rune" marker
-- (tt.isAugmentRune) to auto-discover any not seeded here.
--
-- Seed spans Dragonflight (10.x), The War Within (11.x), Midnight (12.x).
-- Source: Wowhead / Warcraft Wiki, 2026-07.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.AUG_RUNE = {
    -- Midnight (12.x)
    259085,  -- Void-Touched Augment Rune
    -- The War Within (11.x)
    243191,  -- Ethereal Augment Rune      (reusable)
    246492,  -- Soulgorged Augment Rune
    224572,  -- Crystallized Augment Rune
    -- Dragonflight (10.x)
    211495,  -- Dreambound Augment Rune    (reusable)
    201325,  -- Draconic Augment Rune
}
```

- [ ] **Step 3b:** In `defaults/Categories.lua`, add the row to `KCM.Categories.LIST` immediately after the `WPN_ENCH` row and before the `HP_AIO` composite row:

```lua
    {
        key         = "AUG_RUNE",
        macroName   = "KCM_AUG_RUNE",
        displayName = "Augment Rune",
        specAware   = false,
        rankerKey   = "AUG_RUNE",
        classifier  = "AUG_RUNE",
        emptyText   = emptyMacro("no augment rune in bags"),
    },
```

- [ ] **Step 3c:** In `core/ConsumableMaster.lua`, add the profile bucket to the `categories = {` block, immediately after the `VANTUS` line (keep it grouped with the other non-spec single-pick buckets):

```lua
            AUG_RUNE  = { added = {}, blocked = {}, pins = {}, discovered = {} },
```

- [ ] **Step 3d:** In `settings/Panel.lua`, add `"aug_rune"` to `KCM.Settings.order`, after `"wpn_ench"` and before `"hp_aio"`:

```lua
    "flask", "cmbt_pot", "stat_food", "wpn_ench", "aug_rune",
```

Update that table's leading comment: change "then the ten single categories" to "then the eleven single categories".

- [ ] **Step 3e:** In `ConsumableMaster.toc`, add the seed file registration immediately after the `defaults\Defaults_WpnEnch.lua` line:

```
defaults\Defaults_AugRune.lua
```

- [ ] **Step 4: Run — expect PASS.** **Step 5: Gate.** **Step 6:** Report DONE.

---

### Task 5: Regression guard — new PRIMARY token leaves FLASK/STAT_FOOD unmoved

**Files:**
- Test: `tests/test_ranker.lua`

**Interfaces:**
- Consumes: everything from Tasks 1–4. No production change — this task is a pinned regression test proving the `PRIMARY` token did not move existing spec-aware rankings.

- [ ] **Step 1: Write the test** — append to `tests/test_ranker.lua`:

```lua
test("Ranker: PRIMARY token does not change FLASK score (statWeight stays 0)", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local R    = KCM.Ranker

    -- statWeight must return 0 for PRIMARY so aug-rune parsing never leaks
    -- into spec-aware categories.
    t.eq(R._statWeight("PRIMARY", { primary = "STR", secondary = { "CRIT" } }), 0,
        "PRIMARY weighted 0 regardless of spec primary")

    -- A flask whose tooltip (hypothetically) also mentions Primary Stat scores
    -- only from its secondary buff — the PRIMARY entry contributes nothing.
    local spec = { primary = "AGI", secondary = { "CRIT", "HASTE" } }
    mock.setItem(500001, { subType = "Flasks & Phials", quality = 4, ilvl = 1, tt = { statBuffs = {
        { stat = "CRIT", amount = 100 }, { stat = "PRIMARY", amount = 733 } } } })
    -- CRIT is secondary[1] of 2 -> weight 100*2 = 200; contrib 100*200 = 20000.
    t.eq(R.Score("FLASK", 500001, { specPriority = spec }, nil), 20000 + 1 + 400,
        "FLASK score = CRIT contribution + ilvl + quality; PRIMARY adds nothing")
end)
```

- [ ] **Step 2: Run — expect PASS** (`lua5.1 tests/run.lua 2>&1 | grep "PRIMARY token does not change"`). This is a characterization test: if it FAILS, Task 3 accidentally weighted PRIMARY — stop and fix `statWeight` rather than editing the test.
- [ ] **Step 3: Gate.** **Step 4:** Report DONE.

---

### Task 6: Docs, seed source-of-truth, test inventory + badge

**Files:**
- Modify: `README.md` (category table + `[Tests]` badge), `docs/scope.md` (move augment runes out of the declined list), `docs/ARCHITECTURE.md` (module/category map), `docs/smoke-tests.md` (new cases), `docs/test-cases.md` (regenerated)

**Interfaces:**
- Consumes: everything above. Documentation only; no code change.

- [ ] **Step 1: README category table.** In `README.md`, insert Augment Rune as row 11 (after Weapon Enchant), and renumber the two composites to 12 / 13:

```
| 11 |Augment rune (primary stat, reusable-aware)                  |<code>KCM_AUG_RUNE</code> |No          |
| 12 |All-in-one health (combat: HS → HP pot, out of combat: food) |<code>KCM_HP_AIO</code> |No          |
| 13 |All-in-one mana (combat: MP pot, out of combat: drink)       |<code>KCM_MP_AIO</code> |No          |
```

Add a short behaviour paragraph in the "How picking & ranking works" section (near the Weapon Enchant paragraph):

```
    *   **Augment Rune** — picks the augment rune granting the most primary stat. "Permanent" runes like Ethereal and Dreambound aren't a longer buff — they're just not used up — so they only win when they tie the best consumable on stat, never when a newer consumable rune grants more. Auto-discovers new runes from their tooltip, so future runes work without an update.
```

- [ ] **Step 2: `docs/scope.md`.** Remove augment runes from the out-of-scope "Cauldrons / phials / augment runes" line (leave cauldrons + phials), and add a resolved-decision note. Replace the current bullet:

```
- **Cauldrons / phials** as separate categories. Phials are absorbed into FLASK by subtype (`"Flasks & Phials"`). Cauldrons don't have a managed macro. Weapon oils and whetstones are the WPN_ENCH category; augment runes are the AUG_RUNE category (both matched by tooltip effect, not subtype).
```

- [ ] **Step 3: `docs/ARCHITECTURE.md`.** Add `defaults/Defaults_AugRune.lua` to the seed-file list and `AUG_RUNE` to the category enumeration wherever `VANTUS` / `WPN_ENCH` are listed. Grep first: `grep -n "WPN_ENCH\|Defaults_WpnEnch\|VANTUS" docs/ARCHITECTURE.md`, and mirror each hit for AUG_RUNE.

- [ ] **Step 4: `docs/smoke-tests.md`.** Add cases:
  - Put a single augment rune in bags → `KCM_AUG_RUNE` body is `#showtooltip\n/use item:<id>`.
  - Put Ethereal (243191) and Crystallized (224572) in bags → Ethereal is picked (reusable tiebreak at equal 733).
  - Block Ethereal on the Augment Rune page → pick falls back to Crystallized.
  - Confirm the in-game open items: tooltip marker line reads exactly `Augment Rune`; note Void-Touched (259085) / Soulgorged (246492) real stat amounts.

- [ ] **Step 5: Regenerate the inventory and bump the badge.**

Run:
```bash
lua5.1 tests/run.lua --list > docs/test-cases.md
lua5.1 tests/run.lua 2>&1 | tail -1   # read the new "<N> passed" total
```
Then in `README.md` bump the `[Tests]` badge from `Tests-125%2F125_passing` to `Tests-<N>%2F<N>_passing` using that total (expect 125 + 5 new cases = 130, but use the actual printed number).

- [ ] **Step 6: Gate** — `lua5.1 tests/run.lua && luacheck .` (green). **Step 7:** Report DONE; controller reviews + commits.

---

## Self-review notes

- **Spec coverage:** ranking rule → Task 3; generic classification → Tasks 1–2; reusable ID set → Task 2; parser change + statWeight-0 → Tasks 1, 5; category metadata / seed / no MacroManager change → Task 4; docs + scope move + open items → Task 6. All spec sections map to a task.
- **Type consistency:** `isAugmentRune` (Task 1) consumed in Tasks 2–3; `IsReusableAugRune` (Task 2) consumed in Task 3; `augAmount` internal to Task 3. Seed IDs identical across `Defaults_AugRune.lua`, `REUSABLE_AUG_IDS`, and tests.
- **Open items (in-game, non-blocking):** exact `Augment Rune` marker wording (Task 1 pattern is the single-constant fix point); Void-Touched / Soulgorged stat amounts (read from tooltip at runtime, so no code change). Both are recorded in the Task 6 smoke tests.
