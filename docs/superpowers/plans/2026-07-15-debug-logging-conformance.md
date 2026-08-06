# Debug-logging Conformance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Consumable Master's debug logging into full conformance with the Ka0s WoW Addon Standard `debug-logging-§3`/`-§4`/`-§8`/`-§9`/`-§10` — a single callable, secret-safe, tagged sink; complete flow coverage; one coalesced line per pass; and `[Set]` logging at the schema write seam.

**Architecture:** Make `KCM.Debug` a callable sink (`KCM.Debug(tag, fmt, …)`) with a `__call` metamethod, routing every vararg through a new secret-safe `KCM.SafeToString`. Migrate all tagless `KCM.Debug.Print` sites to functional-area tags (`Boot`, `DB`, `Scan`, `Calc`, `Macro`, `GC`, `Set`, `Prio`). Add missing coverage (boot summary, recompute summary, settings + data-mutation logging) as one gated line per event, with per-pass summaries extracted as pure, unit-tested formatters.

**Tech Stack:** Lua 5.1, Ace3, headless test harness (`lua5.1 tests/run.lua`), luacheck.

**Spec:** `docs/superpowers/specs/2026-07-15-debug-logging-conformance-design.md`

## Global Constraints

- **Standard:** debug-logging-§3 line format `<HH:MM:SS> | [<Tag>] <content>` (already implemented in `DebugLog.FormatPlain/FormatColored` — do NOT change).
- **Zero-alloc gate (§4):** the enabled check is the FIRST statement in the sink; every ordinary call site is double-gated with `if KCM.State.debug then …`.
- **Secret-safe (§4):** all sink varargs pass through `KCM.SafeToString`; all format placeholders are `%s` (never `%d`/`%f`).
- **Coalescing (§9):** never one line per item/macro/slot on a repeating path — one summary line per pass.
- **Settings (§10):** log once at `Helpers.Set` as `[Set] <path> = <value>`; reactors MUST NOT re-echo.
- **Tags:** PascalCase, verbatim, single short word.
- **Gate:** `lua5.1 tests/run.lua` AND `luacheck .` both green before each commit.
- **Commits are USER-GATED** (project rule `feedback_git_workflow`): do NOT run `git add`/`git commit` automatically. At each "Commit" step, PAUSE and let the user run it; the shown message is the proposed message.
- **Versioning:** do NOT touch `KCM.VERSION`, TOC `## Version`, or README badges (project rule `feedback_versioning`).

---

### Task 1: Secret-safe stringifier `KCM.SafeToString`

**Files:**
- Modify: `core/Constants.lua` (after `KCM.Say`, ~line 18)
- Test: `tests/test_debuglog.lua`

**Interfaces:**
- Produces: `KCM.SafeToString(v) -> string` — `tostring(v)` under pcall; returns `"<secret>"` if that raises.

- [ ] **Step 1: Write the failing test** — append to `tests/test_debuglog.lua` inside its suite (a new sub-block; adapt the `local KCM = ...` bootstrap the suite already uses):

```lua
    -- KCM.SafeToString — secret-safe stringify
    t.eq(KCM.SafeToString(42), "42", "SafeToString number")
    t.eq(KCM.SafeToString("x"), "x", "SafeToString string")
    t.eq(KCM.SafeToString(nil), "nil", "SafeToString nil")
    local boom = setmetatable({}, { __tostring = function() error("secret") end })
    t.eq(KCM.SafeToString(boom), "<secret>", "SafeToString swallows a raising tostring")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua5.1 tests/run.lua`
Expected: FAIL — `SafeToString` is nil (attempt to call a nil value) or assertion mismatch.

- [ ] **Step 3: Write minimal implementation** — in `core/Constants.lua`, after the `KCM.Say` function:

```lua
-- Secret-safe stringifier (events-frames-taint-§8 / debug-logging-§4). A
-- combat-protected "secret" value errors on any Lua touch, so tostring it under
-- pcall — the debug sink then can never raise mid-combat when one reaches a line.
function KCM.SafeToString(v)
    local ok, s = pcall(tostring, v)
    return ok and s or "<secret>"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua5.1 tests/run.lua`
Expected: PASS (all suites). Also run `luacheck .` → 0 warnings/errors.

- [ ] **Step 5: Commit** (user-gated)

```
Add KCM.SafeToString secret-safe stringifier (debug-logging-§4)
```

---

### Task 2: Callable `KCM.Debug` sink (+ `.Log` alias, temporary `.Print` shim)

**Files:**
- Modify: `core/Debug.lua` (replace the `emit` / `Print` / `Log` block, lines ~38-59)
- Test: `tests/test_debuglog.lua`

**Interfaces:**
- Consumes: `KCM.SafeToString` (Task 1), `KCM.DebugLog.AddLine(tag, msg)` (existing).
- Produces:
  - Callable `KCM.Debug(tag, fmt, ...)` — gated, secret-safe, routes to `DebugLog.AddLine`.
  - `KCM.Debug.Log(tag, fmt, ...)` — alias of the callable (retained; 4 existing sites).
  - `KCM.Debug.Print(fmt, ...)` — TEMPORARY shim → `KCM.Debug("CM", fmt, ...)`; removed in Task 11.
  - `KCM.Debug.IsOn()` / `KCM.Debug.Toggle()` — unchanged.

- [ ] **Step 1: Write the failing test** — append to `tests/test_debuglog.lua`. Capture emitted lines by swapping `KCM.DebugLog.AddLine` for a recorder:

```lua
    -- Callable sink: gated + routes tag/msg through DebugLog.AddLine
    do
        local captured = {}
        local realAdd = KCM.DebugLog.AddLine
        KCM.DebugLog.AddLine = function(tag, msg) captured[#captured + 1] = { tag = tag, msg = msg } end

        KCM.State.debug = false
        KCM.Debug("Test", "should not fire %s", "x")
        t.eq(#captured, 0, "sink is gated off when State.debug is false")

        KCM.State.debug = true
        KCM.Debug("Test", "value=%s", 7)
        t.eq(#captured, 1, "sink fires when enabled")
        t.eq(captured[1].tag, "Test", "sink passes the tag verbatim")
        t.eq(captured[1].msg, "value=7", "sink formats with SafeToString args")

        KCM.Debug.Print("legacy %s", "msg")   -- temporary shim
        t.eq(captured[2].tag, "CM", "Print shim tags legacy lines CM")
        t.eq(captured[2].msg, "legacy msg", "Print shim formats content")

        KCM.DebugLog.AddLine = realAdd
        KCM.State.debug = false
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua5.1 tests/run.lua`
Expected: FAIL — `KCM.Debug` is a table, not callable (attempt to call a table value).

- [ ] **Step 3: Write minimal implementation** — in `core/Debug.lua`, replace the `emit` local and the `KCM.Debug.Print` / `KCM.Debug.Log` definitions (lines ~38-59) with:

```lua
-- Callable sink (debug-logging-§4): KCM.Debug("Tag", "%s -> %s", a, b).
-- Zero-alloc gate is the FIRST statement; every vararg is stringified through
-- the secret-safe KCM.SafeToString so a combat "secret" can't raise here, which
-- is why all call-site placeholders are %s (never %d/%f).
local mt = {
    __call = function(_, tag, fmt, ...)
        if not KCM.Debug.IsOn() then return end
        local n = select("#", ...)
        local msg = fmt
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = KCM.SafeToString((select(i, ...))) end
            msg = tostring(fmt):format(unpack(parts))
        end
        if KCM.DebugLog and KCM.DebugLog.AddLine then
            KCM.DebugLog.AddLine(tag, msg)
        else
            print(PREFIX .. "[" .. tostring(tag) .. "] " .. tostring(msg))
        end
    end,
}
setmetatable(KCM.Debug, mt)

-- Tag-first alias (retained for the already-tagged call sites and tests).
function KCM.Debug.Log(tag, fmt, ...)
    return KCM.Debug(tag, fmt, ...)
end

-- TEMPORARY back-compat shim for the legacy tagless call sites. Every caller is
-- migrated to a proper tag across Tasks 3-10; this shim is removed in Task 11.
function KCM.Debug.Print(fmt, ...)
    return KCM.Debug("CM", fmt, ...)
end
```

Update the file header comment's "Legacy tagless entry" / "Tag-first entry" lines to describe the callable sink + shim.

- [ ] **Step 4: Run test to verify it passes**

Run: `lua5.1 tests/run.lua` → PASS. `luacheck .` → clean (note: `unpack` is global in Lua 5.1; if luacheck flags it, use `(unpack or table.unpack)`).

- [ ] **Step 5: Commit** (user-gated)

```
Make KCM.Debug a callable secret-safe sink; keep Log alias + temp Print shim
```

---

### Task 3: MacroManager — coalesce happy path, tag exceptional events `[Macro]`

**Files:**
- Modify: `modules/MacroManager.lua` (lines ~287-289, 327-329, 335-337, 348-351, 383-385, 421-423, 430-431, 443-445, 478-480)

**Interfaces:**
- Consumes: callable `KCM.Debug` (Task 2).
- Produces: no signature change. `SetMacro` / `SetCompositeMacro` still return their result codes (`"unchanged"`, `"deferred"`, `"error"`, `"created"`/`"edited"`), which Task 5 tallies.

**Rationale:** the success/`unchanged` line fires ≤10×/pass — §9 spam. Remove it; its count folds into the `[Calc]` summary (Task 5). Keep the *exceptional* events as one `[Macro]` line each.

- [ ] **Step 1: Remove the happy-path per-macro line.** Delete the block at lines ~348-351:

```lua
    if KCM.Debug and KCM.Debug.Print then
        KCM.Debug.Print("MacroManager: %s %s (item=%s icon=%s)",
            macroName, result, tostring(itemID), tostring(icon))
    end
```

and the analogous composite success block (~443-445). Leave the `return result` / `return "created"` lines intact.

- [ ] **Step 2: Re-tag the exceptional events** to `[Macro]`, dropping the embedded `"MacroManager:"` prefix (the tag carries it) and switching to double-gated `%s`-only calls. Apply to each remaining site:

Byte-limit (single, ~287-290) and composite (~383-385):
```lua
        if KCM.State.debug then
            KCM.Debug("Macro", "%s body exceeds %s bytes: %s",
                tostring(catKey), MACRO_BODY_LIMIT, body)
        end
```
Combat deferral (single ~327-329, composite ~421-423):
```lua
        if KCM.State.debug then KCM.Debug("Macro", "deferred %s (combat)", macroName) end
```
doEdit failure (single ~335-337, composite ~430-431):
```lua
        if KCM.State.debug then KCM.Debug("Macro", "%s failed — %s", macroName, tostring(err)) end
```
FlushPending drop (~478-480):
```lua
                if KCM.State.debug then
                    KCM.Debug("Macro", "dropped %s after %s attempts (last err=%s)",
                        macroName, attempts, tostring(lastErr))
                end
```
(Keep the exact local variable names already in scope at each site — `attempts`, `lastErr`, `err`, `macroName`, `catKey`, `body`.)

- [ ] **Step 3: Run the gate**

Run: `lua5.1 tests/run.lua` → PASS (macromanager suite still green — it does not assert on debug output). `luacheck .` → clean.

- [ ] **Step 4: Manual read-back check.** Grep to confirm no `Debug.Print` remains in MacroManager:

Run: `grep -n "Debug.Print" modules/MacroManager.lua`
Expected: no output.

- [ ] **Step 5: Commit** (user-gated)

```
Coalesce MacroManager happy-path log into pass summary; tag exceptions [Macro]
```

---

### Task 4: Boot summary `[Boot]` + pure `Pipeline.BootSummary`

**Files:**
- Modify: `core/ConsumableMaster.lua` (add `P.BootSummary`; replace the init line ~79-82)
- Test: `tests/test_debuglog.lua`

**Interfaces:**
- Produces: `KCM.Pipeline.BootSummary(schemaVer, catCount, discCount) -> string` → `"schema=%s categories=%s discovered=%s"`.

- [ ] **Step 1: Write the failing test** — append to `tests/test_debuglog.lua`:

```lua
    t.eq(KCM.Pipeline.BootSummary(1, 8, 23), "schema=1 categories=8 discovered=23",
        "BootSummary formats schema/category/discovered counts")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua5.1 tests/run.lua`
Expected: FAIL — `BootSummary` is nil.

- [ ] **Step 3: Write minimal implementation.** In `core/ConsumableMaster.lua`, near the other `KCM.Pipeline.*` assignments (after `KCM.Pipeline.DiscoverOne`, ~line 280):

```lua
-- Pure boot-summary formatter (debug-logging-§8, unit-tested).
function KCM.Pipeline.BootSummary(schemaVer, catCount, discCount)
    return ("schema=%s categories=%s discovered=%s"):format(
        tostring(schemaVer), tostring(catCount), tostring(discCount))
end
```

Then replace the init line (~79-82) with the `[Boot]` line. Compute the counts from live state:

```lua
    if KCM.State.debug then
        local schemaVer = KCM.db and KCM.db.global and KCM.db.global.schemaVersion
        local catCount  = KCM.Categories and KCM.Categories.LIST and #KCM.Categories.LIST or 0
        local discCount = KCM.Selector and KCM.Selector.CountDiscovered
                          and KCM.Selector.CountDiscovered() or 0
        KCM.Debug("Boot", "%s", KCM.Pipeline.BootSummary(schemaVer, catCount, discCount))
    end
```

If `KCM.Selector.CountDiscovered` does not exist, add a small helper to `modules/Selector.lua` that sums `#bucket.discovered` across all category buckets and expose it as `S.CountDiscovered() -> number`; otherwise pass `0`. (Check with `grep -n "CountDiscovered\|discovered" modules/Selector.lua` before implementing; keep the helper pure and O(categories).)

- [ ] **Step 4: Run test to verify it passes**

Run: `lua5.1 tests/run.lua` → PASS. `luacheck .` → clean.

- [ ] **Step 5: Commit** (user-gated)

```
Add [Boot] one-line summary (schema/category/discovered counts) — §8
```

---

### Task 5: Recompute summary `[Calc]` + pure `Pipeline.CalcSummary` + tally

**Files:**
- Modify: `core/ConsumableMaster.lua` (`P.Recompute` ~127-155; `P.RecomputeOne` return)
- Test: `tests/test_debuglog.lua`

**Interfaces:**
- Consumes: `SetMacro`/`SetCompositeMacro` result codes.
- Produces: `KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped) -> string` → `"reason=%s rewrote %s/%s (skipped %s)"`.

- [ ] **Step 1: Write the failing test** — append to `tests/test_debuglog.lua`:

```lua
    t.eq(KCM.Pipeline.CalcSummary("bag_update_delayed", 3, 10, 7),
        "reason=bag_update_delayed rewrote 3/10 (skipped 7)",
        "CalcSummary formats reason + rewrite/skip tally")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua5.1 tests/run.lua`
Expected: FAIL — `CalcSummary` is nil.

- [ ] **Step 3: Write minimal implementation.**

(a) Add the pure formatter next to `BootSummary`:

```lua
-- Pure recompute-summary formatter (debug-logging-§8/§9, unit-tested).
function KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped)
    return ("reason=%s rewrote %s/%s (skipped %s)"):format(
        tostring(reason), tostring(rewrote), tostring(total), tostring(skipped))
end
```

(b) Make `P.RecomputeOne` return its write result so the pass can tally. At the end of `RecomputeOne`, return the code:
```lua
    if cat.composite then
        return KCM.MacroManager.SetCompositeMacro(cat, scoreCache)
    end
    local pick = KCM.Selector.PickBestForCategory(catKey, nil, scoreCache)
    return KCM.MacroManager.SetMacro(cat.macroName, pick, catKey)
```
(Remove the commented-out verbose per-item block ~lines 218-223.)

(c) In `P.Recompute`, tally results and emit ONE `[Calc]` line. Replace the `enabled` branch's loop + the two `Debug.Print` sites:
```lua
    if enabled then
        local scoreCache = { fields = {} }
        local rewrote, skipped, total = 0, 0, 0
        for _, cat in ipairs(KCM.Categories.LIST) do
            total = total + 1
            local ok, res = pcall(P.RecomputeOne, cat.key, scoreCache, reason)
            if not ok then
                if KCM.State.debug then KCM.Debug("Macro", "%s recompute failed: %s", cat.key, tostring(res)) end
            elseif res == "unchanged" then
                skipped = skipped + 1
            elseif res ~= nil then
                rewrote = rewrote + 1   -- created / edited / deferred
            end
        end
        if KCM.State.debug then
            KCM.Debug("Calc", "%s", KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped))
        end
    elseif KCM.State.debug then
        KCM.Debug("Calc", "skipped writes (disabled): reason=%s", tostring(reason))
    end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua5.1 tests/run.lua` → PASS (ranker/selector/macromanager suites still green — none assert on Recompute's return). `luacheck .` → clean.

- [ ] **Step 5: Commit** (user-gated)

```
Add [Calc] one-line recompute summary with rewrite/skip tally — §8/§9
```

---

### Task 6: Discovery `[Scan]` re-tag + FlushPending `[Macro]`

**Files:**
- Modify: `core/ConsumableMaster.lua` (`runAutoDiscovery` ~268-273; `discoverOne` retry ~243-245; `OnRegenEnabled` ~352-353)

**Interfaces:**
- Consumes: callable `KCM.Debug`. No new interface.

**Rationale:** today the pass summary tags with the event *reason* (`[manual_resync]`). §3 wants a functional-area tag; the reason moves into the content.

- [ ] **Step 1: Re-tag the discovery pass summary.** In `runAutoDiscovery`, replace the `KCM.Debug.Log(reason, …)` block (~268-273) with:

```lua
    if debugOn and KCM.Debug then
        table.sort(scanned)
        table.sort(newIds)
        KCM.Debug("Scan", "reason=%s scanned %s items, %s new. Scanned=[%s]. New=[%s]",
            reason, #scanned, #newIds, table.concat(scanned, ","), table.concat(newIds, ","))
    end
```

- [ ] **Step 2: Re-tag the per-item retry line** (`discoverOne`, ~243-245) — this is the standalone GET_ITEM_INFO_RECEIVED retry (not a pass), so one line is acceptable:

```lua
                elseif KCM.State.debug then
                    KCM.Debug("Scan", "discovered %s id=%s (reason=%s)",
                        catKey, itemID, tostring(reason))
```

- [ ] **Step 3: Re-tag FlushPending summary** (`OnRegenEnabled`, ~352-353):

```lua
        if n > 0 and KCM.State.debug then
            KCM.Debug("Macro", "flushed %s pending macro(s) on regen", n)
        end
```

- [ ] **Step 4: Run the gate**

Run: `lua5.1 tests/run.lua` → PASS. `luacheck .` → clean. Then `grep -n "Debug.Print\|Debug.Log(reason" core/ConsumableMaster.lua` → no output.

- [ ] **Step 5: Commit** (user-gated)

```
Re-tag discovery pass [Scan] (reason in content) + FlushPending [Macro]
```

---

### Task 7: Schema-migration `[DB]` line

**Files:**
- Modify: `core/Database.lua` (`D.RunMigrations`, ~20-31)

**Interfaces:**
- Consumes: callable `KCM.Debug`. No new interface.

**Rationale:** §8 — log migration ONLY when one actually runs (a version bump), never on the no-op common path.

- [ ] **Step 1: Emit `[DB]` only on an actual version change.** In `D.RunMigrations`, capture the starting version and log iff it changed:

```lua
    local g = db.global
    g.schemaVersion = g.schemaVersion or 1
    local from = g.schemaVersion

    -- Future migrations go here, e.g.:
    --   if g.schemaVersion < 2 then ... ; g.schemaVersion = 2 end

    g.schemaVersion = D.CURRENT_SCHEMA
    if KCM.State and KCM.State.debug and from ~= g.schemaVersion then
        KCM.Debug("DB", "migrated schema v%s -> v%s", from, g.schemaVersion)
    end
```

- [ ] **Step 2: Run the gate**

Run: `lua5.1 tests/run.lua` → PASS (schema suite green). `luacheck .` → clean.

- [ ] **Step 3: Commit** (user-gated)

```
Log [DB] schema migration only when a version bump runs — §8
```

---

### Task 8: GC sweep `[GC]` re-tag

**Files:**
- Modify: `modules/Selector.lua` (`SweepStaleDiscovered` log, ~385-386)

- [ ] **Step 1: Re-tag the sweep summary** (already one line per sweep — just the tag + `%s`):

```lua
    if totalSwept > 0 and KCM.State.debug then
        KCM.Debug("GC", "swept %s entries across %s categories", totalSwept, touchedCats)
    end
```
(Preserve the existing `totalSwept`/`touchedCats` locals and any `> 0` guard already present; if the current code logs unconditionally, add the `totalSwept > 0` guard so a no-op sweep stays silent — §9.)

- [ ] **Step 2: Run the gate**

Run: `lua5.1 tests/run.lua` → PASS (selector suite green). `luacheck .` → clean. `grep -n "Debug.Print" modules/Selector.lua` → no output.

- [ ] **Step 3: Commit** (user-gated)

```
Re-tag GC sweep summary [GC]
```

---

### Task 9: Settings-change `[Set]` at the write seam

**Files:**
- Modify: `settings/Panel.lua` (`Helpers.Set`, ~80-85)
- Test: `tests/test_schema.lua` (or `tests/test_debuglog.lua` if the schema suite lacks a live db)

**Interfaces:**
- Consumes: callable `KCM.Debug`. No signature change to `Helpers.Set`.

**Rationale:** §10 — every settings mutation logged once, here, as `[Set] <path> = <value>`.

- [ ] **Step 1: Write the failing test.** Add to whichever suite already builds a live `KCM.db.profile` (schema suite uses `loadWithSchema`). Capture via an `AddLine` recorder:

```lua
    do
        local captured = {}
        local realAdd = KCM.DebugLog and KCM.DebugLog.AddLine
        if KCM.DebugLog then KCM.DebugLog.AddLine = function(tag, msg) captured[#captured+1] = { tag = tag, msg = msg } end end
        KCM.State.debug = true
        KCM.Settings.Helpers.Set("enabled", false)
        local hit
        for _, c in ipairs(captured) do if c.tag == "Set" then hit = c end end
        t.truthy(hit, "Helpers.Set emits a [Set] line")
        t.eq(hit and hit.msg, "enabled = false", "[Set] line shows path = value")
        KCM.State.debug = false
        if KCM.DebugLog then KCM.DebugLog.AddLine = realAdd end
    end
```

(Confirm the path exists in the schema; `enabled` is a real profile key. If the suite's db layout differs, pick any existing boolean schema path via `grep -n "path =" settings/*.lua`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `lua5.1 tests/run.lua`
Expected: FAIL — no `[Set]` line captured.

- [ ] **Step 3: Write minimal implementation.** In `Helpers.Set` (Panel.lua ~80-85), log after a successful write:

```lua
function Helpers.Set(path, value)
    local parent, key = Helpers.Resolve(path)
    if not parent then return false end
    parent[key] = value
    if KCM.State and KCM.State.debug then
        KCM.Debug("Set", "%s = %s", tostring(path), tostring(value))
    end
    return true
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua5.1 tests/run.lua` → PASS. `luacheck .` → clean.

- [ ] **Step 5: Commit** (user-gated)

```
Log every settings change as [Set] <path> = <value> at Helpers.Set — §10
```

---

### Task 10: Data-mutation `[Prio]` logging in Selector

**Files:**
- Modify: `modules/Selector.lua` (`AddItem` ~282, `Block` ~300, `MoveUp`/`MoveDown` ~421-425)

**Interfaces:**
- Consumes: callable `KCM.Debug`. No signature change.

**Rationale:** §8 "all data mutations". These are user-initiated, one-at-a-time (not a repeating path), so one line each is correct. Covers both panel and `/cm priority …` routes (both call these mutators).

- [ ] **Step 1: Add a `[Prio]` line at the end of each successful mutation.** For `AddItem` (after the write succeeds, before `return true`):

```lua
    if KCM.State.debug then KCM.Debug("Prio", "add %s id=%s%s", catKey, itemID,
        specKey and (" spec=" .. tostring(specKey)) or "") end
```
For `Block`:
```lua
    if KCM.State.debug then KCM.Debug("Prio", "block %s id=%s%s", catKey, itemID,
        specKey and (" spec=" .. tostring(specKey)) or "") end
```
For `MoveUp` / `MoveDown` (use the direction word; both share `MoveEntry`-style bodies — add to each success path):
```lua
    if KCM.State.debug then KCM.Debug("Prio", "move-up %s id=%s", catKey, itemID) end
```
```lua
    if KCM.State.debug then KCM.Debug("Prio", "move-down %s id=%s", catKey, itemID) end
```
(Read each function first; place the line only on the success return, using the locals already in scope. Do NOT log on the `return false` / no-op paths — §9.)

- [ ] **Step 2: Run the gate**

Run: `lua5.1 tests/run.lua` → PASS (selector suite green). `luacheck .` → clean.

- [ ] **Step 3: Commit** (user-gated)

```
Log priority-list mutations as [Prio] (add/block/move) — §8
```

---

### Task 11: Remove `.Print` shim + docs sync + final gate

**Files:**
- Modify: `core/Debug.lua` (remove the `KCM.Debug.Print` shim)
- Modify: `docs/debug.md`, `docs/agent-context.md`, `docs/module-map.md` (as needed)
- Verify: whole tree

- [ ] **Step 1: Confirm no `Print` callers remain.**

Run: `grep -rn "Debug.Print" core/ modules/ settings/ defaults/`
Expected: only the definition in `core/Debug.lua`. If any call site remains, migrate it to a proper tag first (do not proceed until clean).

- [ ] **Step 2: Remove the shim** from `core/Debug.lua`:

```lua
-- (delete)
function KCM.Debug.Print(fmt, ...)
    return KCM.Debug("CM", fmt, ...)
end
```

- [ ] **Step 3: Update docs.** In `docs/debug.md` document the callable sink `KCM.Debug(tag, fmt, …)`, the tag set (`Boot`, `DB`, `Scan`, `Calc`, `Macro`, `GC`, `Set`, `Prio`), the `%s`-only + `SafeToString` rule, and the §8/§9/§10 coverage. Fix any `KCM.Debug.Print`/`KCM.Debug.Log` references in `docs/agent-context.md` and `docs/module-map.md` to the callable form. (Read each doc's current debug section first; surgical edits only. Preserve CRLF line endings.)

- [ ] **Step 4: Full gate.**

Run: `lua5.1 tests/run.lua` → all suites PASS.
Run: `luacheck .` → 0 warnings / 0 errors.
Run: `grep -rn "Debug.Print" core/ modules/ settings/` → no output.

- [ ] **Step 5: Commit** (user-gated)

```
Remove temporary Debug.Print shim; sync debug docs to the callable sink
```

---

## Self-review notes

- **Spec coverage:** §3 format (unchanged, preserved) ✓; §4 callable+secret-safe (Tasks 1-2) ✓; §8 lifecycle/boot (Task 4), migration (Task 7), recompute (Task 5), data mutations (Tasks 9-10), settings (Task 9) ✓; §9 coalescing — discovery already done, macro happy-path folded into `[Calc]` (Tasks 3, 5), GC/sweep guarded (Task 8) ✓; §10 `[Set]` single seam + no re-echo (Task 9; reactors were never logging, so nothing to remove) ✓.
- **Tag consistency:** `Boot`, `DB`, `Scan`, `Calc`, `Macro`, `GC`, `Set`, `Prio` used identically in the spec and every task.
- **Interface consistency:** `BootSummary(schemaVer, catCount, discCount)`, `CalcSummary(reason, rewrote, total, skipped)`, `SafeToString(v)`, callable `KCM.Debug(tag, fmt, ...)` — names/arity match across tasks.
- **Line numbers are approximate** (`~`) — each task says to read the site first; exact matches are via the quoted surrounding code.
