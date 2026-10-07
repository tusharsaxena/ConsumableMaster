# 02 — Proposed changes

**Standard resolved:** Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. The index and 27 section files were fetched verbatim with
`curl -fsSL` into a scratch directory. Each change below was checked against it, and the rule that shaped it is cited as `filename-§N`.

**Test-count rule.** Every change below adds or renames headless cases. Per `testing-§5`, the same commit also does two things:

- it regenerates `docs/test-cases.md` with `lua5.1 tests/run.lua --list > docs/test-cases.md`, never by hand;
- it moves the README `[Tests]` badge, `Tests-<X>%2F<Y>_passing`.

The baseline today is **1201 passed / 1202 total**. No change touches `libs/` or `tests/_kit/`.

---

## HLD — themes

### T1. Trust the live macro over the fingerprint (F-001)

**What.** `macroState` is a cache of what this profile last wrote. The account-wide macro is the truth, and the cache has to be
checked against it before it can veto a write. `commitMacro` gains one unprotected read of the live macro body, at the moment the
fingerprint would otherwise short-circuit. The fingerprint is trusted only when the live macro exists **and** its body equals
`lastBody`.

**Alternatives considered.**
- **`MarkAllStale()` on every `PLAYER_ENTERING_WORLD` with `isLogin`.** Rejected as the whole fix. It covers the arrival case but
  not a macro deleted mid-session, and it adds 15 unconditional `EditMacro` calls to every login even on a single-profile account.
- **Move `macroState` to `db.global`.** Rejected. The fingerprint's `lastItemID` is what the macro bar draws per profile
  (`core/MacroDisplay.lua`). Making it global would make the bar of character B draw A's pick, which swaps one disagreement for
  another. It is also a SavedVariables schema change with a migration (`savedvariables-§1`), for no gain over a read.
- **Register `UPDATE_MACROS` and invalidate.** Rejected. `UPDATE_MACROS` fires on this addon's own `EditMacro` too, so every write
  would invalidate itself. The rest of the event list is also the lifecycle latch's business.

**Trade-off.** Each pass gains up to 15 `GetMacroIndexByName` and 15 `GetMacroInfo` calls, but only for macros whose fingerprint
matches. A mismatched or stale fingerprint goes straight to the write as today. These are client reads with no allocation beyond the
returned body string. The perf scenario's call count should show 15 more of each per pass, and nothing else should move.

### T2. Seed the Devourer spec, and make the seed test per spec (F-002, F-008)

**What.**
- Add `["12_1480"]` with `primary = "INT"` and the secondary order taken from the file's documented refresh procedure (archon.gg's
  Devourer page). It must not be guessed here.
- Replace the per-class coverage case with a per-spec one over a pinned list of every playable spec ID the client ships at Interface
  120100.
- Remove nothing.

**Alternatives considered.** Make `CLASS_PRIMARY_FALLBACK` spec-aware. Rejected. The seed table is the declared source
(`savedvariables-§2`'s one-declaration-site spirit), and a second per-spec table in `SpecHelper` would be a second copy that drifts.

### T3. One score cache per bar refresh (F-003)

**What.** `MacroBar.Refresh` builds one `scoreCache = { fields = {} }` per call and passes it through `MacroBarFlyout.Apply` to
`FO.Candidates` to `Selector.ListAvailable(catKey, nil, scoreCache)`. All 15 slots, including both composites' recursion into their
sub-categories, then share one memo of `GetItemInfo`, the tooltip parse and the per-category scores.

**Alternatives considered.**
- **Carry the pipeline's own `scoreCache` on the `MACROBAR_REFRESH` message.** Rejected. That couples the bar to the pipeline's
  internals across a feature boundary that `architecture-§4` puts behind the bus precisely so neither knows the other's data. It
  would also leave every other `MB.Refresh` caller (settings changes, profile switch) uncached.
- **Skip the flyout rebuild unless its inputs changed.** That is a bigger design with its own invalidation rules. Deferred, because
  the cache alone removes the duplicate ranking.

**Expected effect.** `ListAvailable` is still called 20 times per refresh, but with a shared memo. `GetItemByID` calls per refresh
should fall well below today's 107, and `MacroBar.Refresh` bytes should fall well below today's 142727.7. Both are to be confirmed by
the measurement in `03_SMOKE_TESTS.md` §Performance and the offline script. No figure is promised here.

### T4. Discover on a spec change (F-004)

**What.** `KCM:OnSpecChanged` runs `runAutoDiscovery("spec_changed")` before it requests the recompute, the same order
`PLAYER_ENTERING_WORLD` uses. The incoming spec's bucket then sees everything in the bags.

**Alternatives considered.** File every discovery under every spec. Rejected. It changes the per-spec data model the panel and the
reset verbs are built on (`architecture-§5` registry writers), for what is a missing trigger.

### T5. Small hygiene (F-005, F-006, F-007)

- **F-005.** One published resolver for a composite's `(enabled, orderIn, orderOut)`, `MacroManager.CompositeConfig`, which
  `Selector.compositeRefs` calls. A characterization test comes first (`testing-§13`). The existing `== nil` and `or` semantics must
  not be rewritten (`savedvariables-§5`, anti-pattern #54).
- **F-006.** `parsePriorityID` accepts only `^%d+$` (a positive integer item ID) or `^[sS]:%d+$`, and rejects everything else with the
  existing usage line.
- **F-007.** `OnSpecChanged(event, unit)` returns early when `unit` is present and is not `"player"`. This is an early return, not a
  private unit-filter frame. The `events-frames-taint-§1` carve-out is a MAY and is not warranted for one rare event.

---

## Upstream change-set

None. No finding lands in LibKa0s or the testkit.

---

## LLD — change-set per finding

### C-01 — Verify the live macro before the fingerprint early-out (F-001)

**Files:** `modules/MacroManager.lua` (`alreadyApplied`, `commitMacro`), `docs/macro-manager.md`, `docs/profiles.md` (the
"Why the fingerprints are forgotten" section), `tests/test_macromanager.lua`, `tests/test_profiles.lua`, `docs/test-cases.md`,
`README.md` (badge only).

```lua
-- before (modules/MacroManager.lua:442-445)
local function alreadyApplied(state, pending, body, icon)
    if not (state and state.lastBody == body and state.lastIcon == icon) then return false end
    return pending == nil or pending.body == body
end

-- after
-- The live macro the account actually holds. nil when it does not exist (the
-- player deleted it) or the client has no reader. Unprotected reads only, so
-- this module stays the sole WRITER (events-frames-taint-§4).
local function liveBody(macroName)
    if not (GetMacroIndexByName and GetMacroInfo) then return nil end
    local idx = GetMacroIndexByName(macroName)
    if not idx or idx == 0 then return nil end
    local _, _, body = GetMacroInfo(idx)
    return body
end

local function alreadyApplied(macroName, state, pending, body, icon)
    if not (state and state.lastBody == body and state.lastIcon == icon) then return false end
    if pending ~= nil and pending.body ~= body then return false end
    -- The fingerprint is per PROFILE, the macro per ACCOUNT: another character on
    -- another profile (or the player, by deleting it) can have changed it since.
    return liveBody(macroName) == body
end
```

The call site at `:516` passes `macroName`.

**Risk.**
- The client may normalize a macro body on store, for example by trimming trailing whitespace. If it does, `liveBody == body` would
  never hold and every pass would write. The bodies built here have no trailing whitespace, but **this must be confirmed in-client**
  (`03_SMOKE_TESTS.md` C-01, step 5). If normalization is observed, compare a normalized form on both sides instead.
- In combat the read is still safe, and a mismatch queues through `queueForCombat` exactly as today.

**Tests (new).**
- `MacroManager: a body another profile wrote is rewritten on arrival` (the scratch repro, made permanent).
- `MacroManager: a deleted KCM macro is recreated on the next pass with an unchanged pick`.
- `MacroManager: a matching live body still short-circuits with zero EditMacro calls` (keeps the existing no-op guarantee falsifiable).

**Docs.** Correct `docs/scope.md:24` and `README.md:127` only if their wording changes. After the fix their claim becomes true, so
they need no edit. Add one paragraph to `docs/macro-manager.md` saying the early-out is confirmed against the live macro.

### C-02 — Devourer seed row and a per-spec seed test (F-002, F-008)

**Files:** `defaults/Defaults_StatPriority.lua`, `tests/test_defaults.lua`, `docs/test-cases.md`, `README.md` (badge).

```lua
-- Demon Hunter
["12_577"]  = { primary = "AGI", secondary = { … } },   -- Havoc (unchanged)
["12_581"]  = { primary = "AGI", secondary = { … } },   -- Vengeance (unchanged)
["12_1480"] = { primary = "INT", secondary = { <from archon.gg, per the file header> } },  -- Devourer
```

**Test.** Rename "stat priority covers all thirteen classes" to "stat priority seeds every playable spec". It iterates a pinned list
of the 40 playable `classID_specID` keys and asserts each is present, so a new spec is a one-line red. The pinned list excludes
"Initial" specs such as DH 1456. The case has a `-- red under:` comment naming the removal of `12_1480`.

**Risk.** The secondary order is data from an external source, and a wrong order still ranks. It is fixed by the next refresh, and
the user can override it on the Stat Priority page.

### C-03 — Shared score cache across one bar refresh (F-003)

**Files:** `modules/MacroBar.lua` (`MB.Refresh`), `modules/MacroBarFlyout.lua` (`FO.Apply`, `FO.Candidates`),
`tests/test_macrobar_flyout.lua`, `tests/perf.lua` (one optional new scenario, `barRefresh`), `docs/performance.md`
(scenario table), `docs/test-cases.md`, `README.md` (badge).

```lua
-- MB.Refresh
local scoreCache = (not combat) and { fields = {} } or nil   -- built only when flyouts rebuild
...
KCM.MacroBarFlyout.Apply(btn, c, scoreCache)

-- FO.Apply(button, cfg, scoreCache) -> FO.Candidates(button.catKey, cfg, scoreCache)
local ids = KCM.Selector.ListAvailable(catKey, nil, scoreCache) or {}
```

The cache is one table per refresh. It is allocated only out of combat, and only when a flyout will actually rebuild, so the
in-combat path allocates nothing new (`performance-§2`).

**Test (new).** `Flyout: one bar refresh tooltip-parses each candidate at most once`. It counts `C_TooltipInfo.GetItemByID`
through a wrapper over one `MB.Refresh`, for an item that appears in both a single slot and its composite, and asserts 1.

**Perf scenario.** Optionally add `barRefresh` to `tests/perf.lua` (`MacroBar.Refresh` × 200) so the record's trend line carries this
path. It asserts nothing about time (`performance-§9`), and it is not a test case and does not move the badge (`testing-§7`).

### C-04 — Discovery on spec change (F-004)

**Files:** `core/ConsumableMaster.lua` (`KCM:OnSpecChanged`), `docs/data-flow.md` (the event table's
`PLAYER_SPECIALIZATION_CHANGED` row), `tests/test_pipeline.lua`, `docs/test-cases.md`, `README.md` (badge).

```lua
function KCM:OnSpecChanged(event, unit)
    if unit and unit ~= "player" then return end          -- C-07 (F-007)
    traceEvent(event or "PLAYER_SPECIALIZATION_CHANGED")
    runAutoDiscovery("spec_changed")                      -- C-04: file bag items under the NEW spec
    requestRecompute("spec_changed")
    ...
end
```

**Test (new).** `Pipeline: a spec change discovers bag items into the new spec's bucket`. This is the scratch repro, driven through
`KCM:OnSpecChanged` rather than `Recompute`.

**Risk.** One bag scan per spec change, which is rare. The `[Scan]` line uses reason `spec_changed`. That reason is not in
`REPEATING_REASON`, so it always logs, which is correct for an edge event.

### C-05 — One composite-config resolver (F-005)

**Files:** `modules/MacroManager.lua` (publish `M.CompositeConfig`), `modules/Selector.lua` (`compositeRefs` calls it),
`tests/test_selector.lua`.

**Order.** First land a characterization case pinning `ListAvailable("HP_AIO")` and `CompositeDisplayPick` on today's defaults and on a
reordered profile (`testing-§13`). Then refactor. The divergent missing-bucket branch keeps MacroManager's answer, nil, and the
flyout shows nothing, matching the empty body. This is a deliberate one-line behavior note in the commit, not a smuggled change.

**Expected complexity movement.** `compositeRefs` should drop below CCN 15. The next release regeneration of `RESULTS.md` confirms
this; it is not regenerated here.

### C-06 — Strict ID parsing in the slash editor (F-006)

**Files:** `core/SlashCommands.lua` (`parsePriorityID`), `tests/test_slash.lua`, `docs/test-cases.md`, `README.md` (badge).

```lua
local function parsePriorityID(token)
    if not token then return nil end
    local sid = token:match("^[sS]:(%d+)$")
    if sid then return KCM.ID.AsSpell(tonumber(sid)) end
    local iid = token:match("^(%d+)$")
    local n = iid and tonumber(iid)
    return (n and n > 0) and n or nil
end
```

**Test (new).** `0`, `-5`, `1.5`, `0x10` and `1e3` each print the usage line and write nothing.

### C-07 — Ignore other units' spec changes (F-007)

This is folded into C-04's handler edit (shown above), with one new test: `Events: a party member's spec change requests no recompute`.

---

## Standards conformance (per change)

| Change | Conformance |
|---|---|
| C-01 | `events-frames-taint-§4`: still one writer. The reads are unprotected. No SavedVariables shape change, so no migration (`savedvariables-§1`). |
| C-02 | Data lives in the seed file, its one declaration site. The test follows `testing-§12`: it carries a `-- red under:` mutation. |
| C-03 | No cross-feature payload on the bus (`architecture-§4`). Zero new allocation on the in-combat path (`performance-§2`). The scenario is not counted as a case (`testing-§7`). |
| C-04 | Registered events are unchanged, so the latch's `UnregisterAllEvents` still covers everything (`slash-commands-§7`). |
| C-05 | Characterization first (`testing-§13`). No `or`-defaulting rewrite (`savedvariables-§5`). Extraction justified by one shared semantics across two consumers, not by frequency (anti-pattern #55). |
| C-06 | Parsing stays the host's (`slash-commands-§6`). The usage wording is unchanged. |
| C-07 | An early return inside the AceEvent handler. No private event frame (`events-frames-taint-§1`). |

Every change moves `docs/test-cases.md` and the README `[Tests]` badge in the same commit (`testing-§5`). None touches the
`## Version:`, `KCM.VERSION` or the changelog (repo `CLAUDE.md` hard rule).
