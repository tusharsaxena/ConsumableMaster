# CCN elimination — ConsumableMaster

Branch `feat/fix-ccn`. Design: `LibKa0s/docs/superpowers/specs/2026-08-04-ccn-elimination-design.md`.

**20 functions** with `lizard` CCN > 15. Target: every one at CCN <= 15, behavior unchanged.

## Exit criteria

1. `luacheck . --quiet` — 0 warnings, 0 errors.
2. `lua5.1 tests/run.lua` — all pass, count >= baseline.
3. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — no CCN > 15.
4. No behavior change. No version bump, no CHANGELOG, no merge, no tag.

## Rules

- Preferred shapes, in order: table-driven dispatch; a named file-local helper for a
  self-contained block; a data table + loop replacing repeated defaulting; splitting a
  builder into N small builders.
- No dumping a body into one helper to game the metric. Every resulting function must be a
  unit a reader can name.
- Dispatch/defaults tables are **module-level**, built once at file load — never per call.
- `lizard` counts `and`/`or` as decisions. Prefer `== nil` over `or` wherever a stored
  `false` must survive. (Only `false` and `nil` are falsy in Lua: `0` is truthy, so
  `(0 or 99)` is `0` and an `or` chain never swallowed a stored zero. An earlier draft of
  this rule said it did.)
- Hot paths must not gain a per-call allocation.
- Sixteen functions across the collection have no coverage; where this file says
  `Coverage: NONE`, write a characterization test pinning current behavior **before**
  refactoring.

## As shipped — where the code deviates from this plan

Four proposals below were **not** implemented, or were implemented and then reverted on
review. This section is the correction; the per-function paragraphs are left as written so
the reasoning behind each split stays legible. Read them against this list, not on their own.

1. **There is no `dbg(...)` logging wrapper anywhere in the addon.** The `P.Recompute`,
   `commitMacro`, `discoverOne`, `OnAccept` and `ResetAllToDefaults` items each propose
   routing debug sites through a shared `dbg(tag, fmt, ...)` wrapper. That shape shipped in
   `modules/MacroManager.lua`, failed review, and was reverted: Lua evaluates call arguments
   before the callee runs, so a wrapper makes `KCM.Debug`'s arguments (the `tostring` calls at
   those sites) allocate even with debug off. The shipped seam is a **predicate**,
   `local function isDebugOn()`, with the log call inside an `if` at each site —
   `core/ConsumableMaster.lua`, `modules/MacroManager.lua` and `settings/Category.lua` all
   carry the same one. `tests/test_macromanager.lua` pins it with a probe key that counts its
   own `__tostring` calls.
2. **There is no `KCM.OwnsID`, and `core/Constants.lua` was not touched.** The `priorityList`
   item proposes hoisting the spell-vs-item ownership predicate there and having both callers
   use it; the `DUMP_TARGETS.pick.run` item then tells `describeEntry` to share it. What
   shipped is `local function ownsID(id)` in `core/SlashCommands.lua` and
   `describeSpellEntry` / `describeItemEntry` in `core/SlashDump.lua`. The two callers want
   different return shapes (a boolean vs `displayID, name, owned`), and publishing a new
   cross-file helper was outside a behavior-identical refactor, so the duplication stands.
   Do not call `KCM.OwnsID` — it does not exist.
3. **`bindEntry` keeps no `KCM.MacroBarButton` presence guard**, contrary to the `bindEntry`
   item's "keeping the existing `KCM.MacroBarButton` presence guard at the call site". It was
   unreachable — `FO.RefreshCooldown` and the other two appliers in the same function already
   dereference that table bare — so it was dropped. `ApplyBorder` is also called
   unconditionally: it owns the `buttonBorder == false` arm itself, and a caller-side copy of
   that test is the drift the shared applier exists to prevent.
4. **`outOfCombatLines` does not exist and nothing returns an array of lines.** The
   `buildCompositeBody` item's (c) shipped as `appendOutOfCombatLines(lines, orderOut,
   enabled, pickFor)` — an out-param helper returning whether it emitted anything, the same
   shape as `appendEmptyStateNotice`. The array-returning version was reverted because it
   added a per-build table plus an O(n) copy that master did not have; the body is assembled
   in the one `lines` table throughout.

## Functions

### `DUMP_TARGETS.pick.run` — CCN 62 → target 8

`core/SlashDump.lua:155-282` · pattern `elseif-dispatch` · risk **medium**

**What it does.** The `/cm dump pick <catKey>` diagnostic — by far the largest function in the addon. Handles the no-arg usage listing, unknown-category rejection, then two completely different reports: for composites, the in-combat/out-of-combat ordered ref lists with each ref's resolved pick plus the assembled macro body; for single categories, the spec context, the effective priority with per-entry score, ownership and pick marker.

**Where the branches come from.** Two independent programs sharing a preamble. The composite half: a four-term db chain, a nested `describePick` closure defined per call (itself a 6-branch name resolver), a per-call `sections` table, a nested loop with an `#arr == 0` fork and an enabled/tag ternary, then the BuildCompositeBody block with a line-splitting gmatch loop. The single half: the spec-aware ctx block with its own three-way, then a render loop whose body forks spell-vs-item with 4-6 short-circuit terms per arm, a Ranker.Score `or 0` chain and two tag ternaries.

**Fix.** Lift everything to file-local functions and let `run` be a three-line dispatcher. Preamble: (a) `local function sayPickUsage()` — the usage line and the known-keys list (CCN 4); (b) `local function resolvePickCat(arg)` — trim, upper, Categories.Get, the Selector-loaded guard, returning cat, catKey or nil (CCN 6). Composite half: (c) hoist `describePick(refKey)` out of the closure to file scope (CCN 7); (d) module-level constant `local AIO_SECTIONS = { { label = "In Combat", orderField = "orderInCombat" }, { label = "Out of Combat", orderField = "orderOutOfCombat" } }` — it is rebuilt per call today for no reason; (e) `local function sayCompositeSections(cfg)` — the AIO_SECTIONS loop with the empty/tag forks (CCN 7); (f) `local function sayCompositeBody(cat)` — the BuildCompositeBody block and the gmatch line loop (CCN 6); (g) `local function dumpCompositePick(cat, catKey)` — the cfg lookup guard plus calls to (e) and (f) (CCN 5). Single half: (h) `local function sayPickSpecContext(cat, catKey)` returning ctx (CCN 6); (i) `local function describeEntry(id)` returning displayID, name, owned — this is the same spell-vs-item resolution as core/SlashCommands.lua's priorityList and should share the hoisted `KCM.OwnsID` from core/Constants.lua (CCN 7); (j) `local function sayPriorityRows(catKey, priority, pick, ctx)` (CCN 5). `run` becomes: empty-arg → sayPickUsage; resolvePickCat guard; `if cat.composite then return dumpCompositePick(cat, catKey) end`; ctx, priority, pick, BuildContext, sayPriorityRows, no-pick line — CCN ~7.

**Must not change.** The composite and single reports have different, test-asserted layouts and must not converge. `describePick` returning the literal string "(no pick)" and the `[on]`/`[off]` color-coded tags are asserted output. Ranker.BuildContext must still be given the spec ctx built by the spec block (ctx is threaded in, not rebuilt) — the score column is wrong otherwise. BuildCompositeBody is called with an injected pickFor closure; keep that injection so the dump reflects live picks. Every line goes through `say`. The nil-pick trailing line only prints for the single-category path.

**Coverage.** tests/test_slash.lua:100 covers the single-category render (owned marker), :513 covers the composite macro-body render, :521 covers a sibling target. The usage/no-arg path and the unknown-category path are covered at :484/:492 for the parent dump verb but not for this target's own arg. Coverage is decent but thin per-section — add assertions on the composite section headers and the spec-context line before splitting.

---

### `commitMacro` — CCN 35 → target 9

`modules/MacroManager.lua:325-404` · pattern `guard-stack` · risk **high**

**What it does.** The single write seam for every macro: enforces the 255-byte body limit (swapping to the empty-state body and warning once per category), resolves the icon, short-circuits when the stored body+icon already match, defers the write to PLAYER_REGEN_ENABLED when in combat (preserving the retry count across re-queues), otherwise calls doEdit and records the new macroState.

**Where the branches come from.** Five phases in one body. The opts/active defaulting; the oversize block with its `opts.cat or (KCM.Categories and ... and ...)` fallback, a debug guard and a once-per-catKey warn guard; `opts.resolveIcon and opts.resolveIcon(active) or iconFor(...)`; then TWO separate unchanged-state conditions of four and six terms each; the combat branch with `pending and pending.attempts or 0` and another debug guard; and the doEdit error fork with a third debug guard.

**Fix.** Four changes, largest win first. (a) Merge the two unchanged-state conditions — `local same = state and state.lastBody == body and state.lastIcon == icon; if same and (pending == nil or pending.body == body) then pendingUpdates[macroName] = nil; return "unchanged" end`. This is behavior-identical (the first arm cleared pending; in the second arm pending is nil so clearing is a no-op) and removes six branches on its own. (b) `local function applyBodyLimit(body, catKey, iconItemID, opts)` returning `body, effectiveItemID, active` — the whole oversize block including the warn-once bookkeeping (CCN 8). (c) `local function queueForCombat(macroName, body, iconItemID, catKey, opts, pending)` — the pendingUpdates write with the attempts carry-over (CCN 4). (d) Route the three debug sites through the self-guarding `dbg` seam described in the P.Recompute item (KCM.Debug already gates internally), dropping two branches each. commitMacro becomes: opts defaulting, applyBodyLimit, icon resolution, the merged unchanged test, `if InCombatLockdown and InCombatLockdown() then return queueForCombat(...) end`, doEdit + error fork, state record — CCN ~8-9.

**Must not change.** This is the only protected-API caller and the combat guard is the addon's taint contract — the InCombatLockdown check must stay in this function, before doEdit, on every path. The oversize path must ALSO null the stored icon item and set active=false, or a sentinel icon desyncs from an empty-state body. alreadyWarnedOversized is once-per-catKey-per-session, not per call. `attempts` must be preserved across re-queues within one combat window so a failing EditMacro does not reset its retry counter on every pipeline run. `opts.cat` must stay nil for single-category entries — FlushPending dispatches on its presence (F-001). The four return values "unchanged" / "deferred" / "error", err / doEdit's result are what P.Recompute's tally classifies on. macroState is written only after a successful doEdit.

**Coverage.** tests/test_macromanager.lua covers SetMacro / the commit path and tests/test_pipeline.lua covers the result classification. Verify before touching: the oversize→empty-state swap, the warn-once behavior, the deferred re-queue attempts carry-over, and BOTH unchanged-state cases (with and without a pending write) — the (a) merge is only safe if the second case is pinned.

---

### `DUMP_TARGETS.item.run` — CCN 32 → target 7

`core/SlashDump.lua:89-149` · pattern `options-builder` · risk **low**

**What it does.** The `/cm dump item <itemID>` diagnostic: prints the item's resolved name, its GetItemInfoInstant type/subtype/class data and the categories the Classifier matches it to, the parsed tooltip's pending/usable state, a DevTools_Dump of the cache entry, and every raw tooltip line with left/right text.

**Where the branches come from.** Five independent report sections concatenated into one function, each with its own presence guards: the arg/tonumber guard and the TooltipCache guard; a three-alternative `or` chain for the item name; the C_Item.GetItemInfoInstant block with a `#hits > 0` fork and its own three-term MatchAny guard; the pending/entry/usable three-way; the DevTools guard; and the C_TooltipInfo block with a nested loop and a `right ~= ""` fork.

**Fix.** Each section is already a coherent unit — lift all four into file-local printers above DUMP_TARGETS, so `run` is just an argument guard and four calls. (a) `local function sayItemHeader(id, entry)` — the name `or` chain and the header line (CCN 5). (b) `local function sayInstantInfo(id)` — the GetItemInfoInstant block including the classified/none fork (CCN 7). (c) `local function sayUsability(id, entry)` — the pending / usable / not-usable three-way (CCN 6). (d) `local function sayRawTooltipLines(id)` — the C_TooltipInfo loop with the left/right fork (CCN 6). `run` becomes: `local id = tonumber(arg or "")` guard, TooltipCache guard, `local entry = Get(id)`, the four calls with the DevTools_Dump guard in between — CCN ~5. All four are also individually reusable by future dump targets, which is the direction this file already leans (DUMP_TARGETS + DUMP_ORDER).

**Must not change.** Output ORDER is the contract: header, instant/classified, pending-or-usable, DevTools dump, raw lines. Every line goes through `say` (the secret-safe seam). The pending branch must suppress the usable check entirely — asking IsUsableByPlayer on a pending entry would report a wrong answer. The DevTools_Dump call is conditional on the global existing and must dump the raw entry, not a copy. C_Item / C_TooltipInfo presence guards protect non-Retail builds.

**Coverage.** tests/test_slash.lua covers `/cm dump 960010` (the bare-numeric shortcut into this target) but only asserts the ID appears. Section-level assertions are effectively NONE — add characterization tests for the pending branch and the raw-lines branch before splitting.

---

### `bindEntry` — CCN 30 → target 8

`modules/MacroBarFlyout.lua:324-378` · pattern `field-defaulting` · risk **medium**

**What it does.** Points one flyout entry button at an opaque KCM ID: sets the secure type/spell or type/item attributes for the click, the icon texture with the zoom crop, the stack count, the cooldown sweep, and the whole button-appearance block (backdrop fill plus the optional border) so the strip reads as the same kind of thing as the bar it hangs off.

**Where the branches come from.** Five concerns in one body, and the last two are a verbatim copy of MacroBarButton.ApplyStyle's chrome code: the spell-vs-item attribute fork with a three-term Compat guard; the zoom clamp; the count fork with a three-term condition; then the backdrop color defaulting (four `or`s) and show/hide, and the border block with its offset/edgeSize/style/color defaulting (another six-plus short-circuits).

**Fix.** Delete the duplicated chrome and extract the rest. (a) Replace lines 359-377 entirely with calls to the appliers exported from MacroBarButton in the ApplyStyle item — `KCM.MacroBarButton.ApplyBackdropTex(btn.backdropTex, cfg)` and, keeping the existing `KCM.MacroBarButton` presence guard at the call site, `KCM.MacroBarButton.ApplyBorder(btn.border, btn, cfg)`. That is roughly 14 branches removed and a real duplication killed, not a metric game — the two blocks are byte-identical today and have to stay in sync by hand. (b) `local function bindSecureAction(btn, id)` — the spell/item attribute fork (CCN 6). (c) `local function applyEntryCount(btn, id, cfg)` — the count fork (CCN 6). (d) Icon zoom goes through the shared `KCM.MacroBarButton.ApplyIconZoom` variant (the flyout sets the texture too, so keep `btn.icon:SetTexture(...)` local and call the shared clamp). bindEntry becomes: kcmID, SetSize, bindSecureAction, SetTexture + ApplyIconZoom, applyEntryCount, FO.RefreshCooldown, the two chrome calls — CCN ~4.

**Must not change.** Out-of-combat only — every attribute write here is a protected-frame operation and FO.Apply's inCombat() guard is what makes it legal; the helpers must not be called from anywhere that lacks that guard. Items use `type="item"` with the `item:<id>` form deliberately so a localized name cannot break the click; spells need the NAME (via Compat.GetSpellName), and a missing name must still write "" rather than nil. The zoom clamp bounds must match MacroBarButton's 0..40 exactly — sharing the applier is what guarantees that. Count hides on zero or when showCount is false.

**Coverage.** tests/test_macrobar.lua exercises the flyout (Candidates, layout) but not bindEntry's attribute writes. Effectively NONE for the binding itself. Add a characterization test asserting the secure attributes for a spell ID vs an item ID, and that the chrome calls land, before swapping in the shared appliers.

---

### `buildCompositeBody` — CCN 27 → target 8

`modules/MacroManager.lua:174-245` · pattern `options-builder` · risk **low**

**What it does.** Assembles the macro body for a composite (all-in-one) category: one /castsequence line for the enabled in-combat refs, one /use|/cast line per enabled out-of-combat ref, plus a /run print stub for whichever combat state produced no usable line, all under a #showtooltip header. Returns nil when nothing is usable so the caller falls back to the empty-state body.

**Where the branches come from.** Three multi-term guards up front, three `cfg.X or cat.components.Y or {}` defaulting chains, then two structurally identical loops (each with an `enabled[ref] ~= false` test and a nil-token test), and finally the two-way empty-state fork whose arms insert at different positions.

**Fix.** Split the assembly into its independent parts. (a) `local function compositeConfig(cat)` — the guards, the db lookup and the three defaulting chains, returning `enabled, orderIn, orderOut` or nil (CCN 8). (b) `local function inCombatLine(orderIn, enabled, pickFor)` — the seqTokens loop and the /castsequence format, returning the line or nil (CCN 5). (c) `local function outOfCombatLines(orderOut, enabled, pickFor)` — the loop returning an array of lines (CCN 5). (d) `local function appendEmptyStateNotice(lines, cat, hasIn, hasOut)` — the two-way fork with its position-sensitive inserts (CCN 4). buildCompositeBody becomes: compositeConfig guard, build the two parts, `if not (inLine or #outLines > 0) then return nil end`, assemble lines, appendEmptyStateNotice, insert #showtooltip at 1, concat — CCN ~6.

**Must not change.** `enabled[ref] ~= false` defaults an unset ref to ENABLED (refs added later via Categories metadata are not yet in the saved bucket) — never rewrite as a truthiness test. Line ORDER is the macro's semantics: #showtooltip first, then the /castsequence [combat] line, then the /use [nocombat] lines as a fallback chain. The out-of-combat-only empty-state /run must be inserted at position 1 (before the /use [nocombat] lines) while the in-combat-only one is appended — that asymmetry is deliberate and is what makes each print fire in the right combat state. /run cannot take [combat] conditionals, which is why the state test is in Lua. `pickFor` stays injected so the function is unit-testable and so /cm dump pick can reuse it. Returning nil (not an empty string) is what triggers the caller's buildEmptyBody fallback.

**Coverage.** tests/test_macromanager.lua covers BuildCompositeBody (it is exported at line 247 precisely for that) and tests/test_slash.lua:513 renders it through /cm dump pick. Good coverage — verify the two empty-state insert positions are pinned.

---

### `P.Recompute` — CCN 26 → target 8

`core/ConsumableMaster.lua:261-322` · pattern `guard-stack` · risk **medium**

**What it does.** The pipeline's single recompute pass: brackets the whole thing for Perf, checks the master enable, walks KCM.Categories.LIST calling P.RecomputeOne under pcall per category while tallying rewrote/skipped/total, logs a Calc summary, then publishes PANEL_REFRESH + MACROBAR_REFRESH on the bus (with two direct-call fallbacks).

**Where the branches come from.** Four separable concerns in one body: (1) the two-term LIST guard and the `(perf and perf.on) and debugprofilestop() or nil` bracket; (2) `not (KCM.db and KCM.db.profile and KCM.db.profile.enabled == false)`; (3) the category loop with pcall plus a three-way `if not ok / elseif res == "unchanged" / elseif res ~= nil` result classifier, each arm carrying its own `KCM.State and KCM.State.debug` guard; (4) the four-armed bus/Options.RequestRefresh/Options.Refresh publish chain, each arm a two-term `and`.

**Fix.** Split into three file-local helpers plus a shared debug seam. (a) `local function dbg(tag, fmt, ...)` that wraps `if KCM.Debug.IsOn() then KCM.Debug(tag, fmt, ...) end` — KCM.Debug already self-gates internally (core/Debug.lua:37-54), so every `if KCM.State and KCM.State.debug then KCM.Debug(...) end` site in this file collapses to one call and sheds 2 branches each (CCN 2). (b) `local function macrosEnabled() return not (KCM.db and KCM.db.profile and KCM.db.profile.enabled == false) end` (CCN 4). (c) `local function runMacroPass(scoreCache, reason)` holding the ipairs loop, the pcall and the three-way classifier, returning rewrote, skipped, total (CCN 8). (d) `local function publishRefresh()` holding the bus/Options fallback chain (CCN 6). P.Recompute is then: LIST guard, perf bracket, `if macrosEnabled() then ... runMacroPass ... dbg(Calc summary) else dbg(skipped) end`, publishRefresh(), perf Note — CCN ~7. Note on (a): args are evaluated unconditionally after the change (today they are only evaluated when debug is on). Every arg here is `tostring(x)` or a Pipeline.CalcSummary call on a once-per-frame path, so keep CalcSummary inside an explicit `if KCM.Debug.IsOn()` at that one site rather than passing it through dbg.

**Must not change.** The perf bracket must still be nil when Perf is off (no debugprofilestop call). The pcall isolation must stay one-per-category so a bad scorer cannot break the other macros. PANEL_REFRESH must fire even when the addon is disabled (comment at 270-275 — panel hydration depends on it), and MACROBAR_REFRESH must stay a separate, undebounced message. The bus→Options fallback order must not change.

**Coverage.** tests/test_pipeline.lua, tests/test_events.lua, tests/test_bus.lua (message publication), tests/test_perfsetup.lua (the perf bracket), tests/test_settingsui.lua and tests/test_slash.lua exercise it indirectly. Good coverage; the enabled==false branch and the Options.Refresh fallback arm should be checked before touching them.

---

### `S.GetBucket` — CCN 23 → target 6

`modules/Selector.lua:36-71` · pattern `field-defaulting` · risk **low**

**What it does.** Resolves the per-category saved-variables bucket holding added / blocked / pins / discovered. Non-spec-aware categories get the category root defensively field-filled; spec-aware ones resolve the current spec key (or the caller's), lazily create the bySpec sub-table, and field-fill that. Returns nil for an unknown category or when no spec can be resolved.

**Where the branches come from.** Two blocks of four `t.field = t.field or {}` lines — eight branches of identical defaulting — plus a three-term Categories.Get chain, a four-term db chain, the specAware fork, the spec-resolution fallback, and the exists-vs-create fork on the bySpec entry.

**Fix.** Kill the defaulting duplication with a data table and split the two resolution steps. (a) Module-level constant `local BUCKET_FIELDS = { "added", "blocked", "pins", "discovered" }` and `local function ensureBucketFields(t) for _, f in ipairs(BUCKET_FIELDS) do t[f] = t[f] or {} end return t end` (CCN 3) — replaces both four-line blocks and makes `emptyBucket()` derive from the same list, so adding a fifth field is a one-line edit instead of three. (b) `local function categoryRoot(catKey)` — the Categories.Get chain and the db chain, returning `cat, root` or nil (CCN 6). (c) `local function currentSpecKey(specKey)` — `if specKey then return specKey end` plus the SpecHelper fallback (CCN 4). S.GetBucket becomes: categoryRoot guard, `if not cat.specAware then return ensureBucketFields(root) end`, resolve spec key + guard, `root.bySpec = root.bySpec or {}`, `local b = root.bySpec[specKey]; if not b then b = emptyBucket(); root.bySpec[specKey] = b end`, `return ensureBucketFields(b)` — CCN ~6. Calling ensureBucketFields on a freshly-created emptyBucket is a harmless no-op and keeps one exit path.

**Must not change.** This returns the LIVE saved-variables table — every caller mutates it in place, so ensureBucketFields must fill fields on the existing table and never return a copy. Returning nil is meaningful and distinct: unknown category, missing db bucket, or a spec-aware category with no resolvable spec (a sub-level-10 character); callers branch on it. specKey is ignored entirely for non-spec-aware categories. The bySpec sub-table is created lazily on first access and must persist into the DB.

**Coverage.** Well covered: tests/test_selector.lua, tests/test_categories.lua, tests/test_pipeline.lua and tests/test_slash.lua all drive GetBucket, including the spec-aware path via AddItem. Safe to refactor.

---

### `BB.ApplyStyle` — CCN 21 → target 8

`modules/MacroBarButton.lua:254-302` · pattern `field-defaulting` · risk **low**

**What it does.** Applies the size and chrome settings from db.profile.macroBar to one bar button: button size, the optional BackdropTemplate border child with its offset/thickness/style/color, the icon's zoom crop, the backdrop fill color and its visibility, then the label and a RefreshIcon.

**Where the branches come from.** Almost every branch is a default: six `tonumber(cfg.x) or D` coercions, the border on/off fork, `math.max(1, ...)`, a two-sided zoom clamp (`if zoom < 0 ... elseif zoom > 40`), two four-element color-defaulting runs (`c[1] or 1, c[2] or 1, ...` — eight short-circuits between them), and the backdrop show/hide fork.

**Fix.** Extract three appliers and one shared color helper, and EXPORT the appliers on BB so MacroBarFlyout can stop duplicating them (see bindEntry). (a) `local function rgba(c, dr, dg, db, da)` returning four values — `c = c or EMPTY; return c[1] or dr, c[2] or dg, c[3] or db, c[4] or da` (CCN 5, one place instead of the four-per-site pattern repeated six times across two files; returns values, allocates nothing, with EMPTY a module-level constant). (b) `function BB.ApplyBorder(frame, anchorTo, cfg)` — the ClearAllPoints/SetPoint/SetBackdrop/SetBackdropBorderColor/Show-or-Hide block (CCN 8 today, CCN 4 once it uses rgba). (c) `function BB.ApplyIconZoom(icon, frame, cfg)` — SetAllPoints plus the clamp and SetTexCoord (CCN 4). (d) `function BB.ApplyBackdropTex(tex, cfg)` — the fill color and show/hide (CCN 3 with rgba). ApplyStyle becomes: guard, SetSize, ApplyBorder(btn.border, btn, cfg), ApplyIconZoom, ApplyBackdropTex, applyLabel, RefreshIcon — CCN 3.

**Must not change.** Called on every layout pass (a slider drag repaints without a rebuild), so no new per-call table allocations: rgba must return four values, not a table, and EMPTY must be a module-level constant. The border is deliberately a separate BackdropTemplate child, not a texture on the button, so `buttonBorderOffset` can push edges OUTWARD — keep the ClearAllPoints + two SetPoint with the sign flip (-off, off) / (off, -off). The zoom clamp bounds are 0..40 percent. Do NOT rebuild the flyout here (comment at 295-297 — Refresh owns it, and doing it in both places rebuilt every flyout twice per settings change). Count visibility stays owned by RefreshIcon.

**Coverage.** NONE — tests/test_macrobar.lua does not reference ApplyStyle. The border-style enum IS covered at tests/test_macrobar.lua:893 via ValidateSchemaValue, but no test drives the applier. Write a characterization test with a frame mock recording SetSize/SetBackdrop/SetTexCoord arguments across the border-on, border-off and zoom-clamp cases first.

---

### `StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept` — CCN 21 → target 7

`settings/Category.lua:124-148` · pattern `guard-stack` · risk **low**

**What it does.** The shared per-category reset confirmation handler. For a composite category it restores enabled / orderInCombat / orderOutOfCombat from dbDefaults; for a single category it clears the bucket's added / blocked / pins. Either way it logs and fires afterMutation with a path-specific reason.

**Where the branches come from.** Two unrelated programs inside one anonymous dialog callback: the composite arm carries a four-term dbDefaults chain, a four-term db chain, a combined presence guard and three `defaults.X or {}` CopyTable arguments; the single arm carries a three-term Selector chain and its own guard; and each arm repeats the `KCM.State and KCM.State.debug` log guard.

**Fix.** Lift each arm into a named file-local above the dialog table so OnAccept becomes a three-line dispatcher. (a) `local function resetCompositeCategory(catKey)` — the two chains, the guard, and the field restore driven by a module-level constant `local AIO_RESET_FIELDS = { "enabled", "orderInCombat", "orderOutOfCombat" }` with `for _, f in ipairs(AIO_RESET_FIELDS) do cfg[f] = CopyTable(defaults[f] or {}) end` — three explicit branches become one (CCN 6). (b) `local function resetSingleCategory(catKey, specKey)` — the GetBucket guard and the three clears (CCN 4). Route both log lines through the self-guarding `dbg` seam. OnAccept becomes: `if not data then return end; if data.composite then resetCompositeCategory(data.catKey) else resetSingleCategory(data.catKey, data.specKey) end` — CCN 3. The two named functions are also directly unit-testable, which the anonymous callback is not.

**Must not change.** CopyTable must stay a copy — aliasing dbDefaults would let a later edit corrupt the defaults for the session. The composite arm resets ONLY the three AIO fields; the single arm clears added/blocked/pins but must NOT clear `discovered` (auto-discovery findings survive a category reset). The two afterMutation reasons differ ("options_aio_reset_cat" vs "options_reset_cat") and are the audit trail. Both arms return early without mutating when their tables are missing. One popup is shared across all category panels with the active catKey parked in popup.data, so neither helper may capture a catKey at definition time.

**Coverage.** NONE — tests/test_settingsui.lua covers the panel scaffolding and the mouseover toggle but not this dialog. Add a characterization test calling the extracted helpers for both arms (asserting the discovered set survives and the reasons differ) before refactoring.

---

### `discoverOne` — CCN 20 → target 8

`core/ConsumableMaster.lua:369-407` · pattern `guard-stack` · risk **low**

**What it does.** Classifies one bag item into every matching category and, for each hit not already in the shipped seed, records it in that bucket's `discovered` set via Selector.MarkDiscovered. Shared by the bulk bag pass and the per-item GET_ITEM_INFO_RECEIVED retry; collects into `outNew` for the bulk summary or prints a per-item debug line when `outNew` is nil.

**Where the branches come from.** A four-term `not (itemID and Classifier and MatchAny and Selector and MarkDiscovered)` guard; the outer hits loop; `KCM.SEED and KCM.SEED[catKey] or {}` plus an inner linear seed scan with a break; a three-term `cat and cat.specAware and KCM.SpecHelper` spec resolution; then a nested `if MarkDiscovered(...)` containing an `if outNew / elseif State.debug` fork.

**Fix.** Three file-local extractions. (a) `local function isSeeded(catKey, itemID)` — the `KCM.SEED` lookup and the inner scan, returning boolean (CCN 4). (b) `local function discoverySpecKey(cat)` — `if cat and cat.specAware and KCM.SpecHelper then local _,_,k = KCM.SpecHelper.GetCurrent(); return k end` (CCN 4). (c) `local function recordDiscovery(catKey, itemID, reason, outNew)` — the MarkDiscovered call plus the outNew/dbg fork, returning 1 or 0 (CCN 4), using the shared `dbg` seam from the P.Recompute item. discoverOne becomes: guard, `hits = MatchAny(itemID)`, `nowUnix = nowUnix or time()`, loop `if not isSeeded then added = added + recordDiscovery(...) end` — CCN ~8. The guard itself can drop to `if not itemID then return 0 end` plus a single two-term module-presence check hoisted into a `local function discoveryReady()` (CCN 5) if more headroom is wanted.

**Must not change.** Zero-hit items must stay silent (no per-item log) — the bulk pass emits one summary instead. The specKey must be resolved per category (only spec-aware ones), not once for the whole item. `nowUnix` must default once, before the loop, so every bucket in one pass gets the same timestamp. The outNew-vs-debug fork decides bulk vs standalone reporting and must not merge.

**Coverage.** tests/test_pipeline.lua, tests/test_events.lua and tests/test_selector.lua cover MarkDiscovered and the discovery path; tests/test_classifier.lua covers MatchAny. No test names discoverOne directly — add a characterization test for the seeded-item-is-skipped and the outNew-vs-debug fork before refactoring.

---

### `priorityList` — CCN 19 → target 8

`core/SlashCommands.lua:294-319` · pattern `table-render-loop` · risk **low**

**What it does.** The `/cm priority <cat>` verb: delegates composites to the dump-pick target, resolves the effective priority list and the current best pick for a category, then prints one line per entry with an owned/not-owned tag and a marker on the pick.

**Where the branches come from.** Three stacked guards (composite delegation, Selector presence, spec-aware-without-spec), then a render loop whose body is dense with short-circuits: the spell-vs-item `owned` fork where each arm is a three-or-four-term `and`/`or` chain, plus two ternary tag expressions.

**Fix.** Extract the ownership test and the row formatter. (a) `local function ownsID(id)` — the spell (`IsPlayerSpell(KCM.ID.SpellID(id))`) vs item (`BagScanner.HasItem(id)`) fork with its presence guards, returning a boolean (CCN 6). This same predicate is duplicated in core/SlashDump.lua:258-273, so hoist it to core/Constants.lua (loads first) as `KCM.OwnsID(id)` and have both callers use it — that removes real duplication, not just complexity. (b) `local function priorityRow(i, id, pick)` — the two tag ternaries and the format call, returning the string (CCN 3). priorityList becomes: three guards, fetch priority + pick, header say, `for i, id in ipairs(priority) do say(priorityRow(i, id, pick)) end` — CCN ~7.

**Must not change.** Every line goes through `say` (KCM.Say), the secret-safe chat seam — never swap in print or string concatenation into a buffer. The exact format strings (`%2d`, `%-12s`, the |cff color codes and the trailing `<-- pick` marker) are what the slash tests assert on. Composite categories must still delegate to SlashDump.TARGETS.pick.run with a LOWERCASED key. The spec-aware-without-spec message is a user-facing early return, not a silent skip.

**Coverage.** tests/test_slash.lua covers the priority verb and the dump-pick delegation; tests/test_selector.lua covers GetEffectivePriority. Coverage is adequate for a behavior-preserving extraction.

---

### `aioToggle` — CCN 19 → target 6

`core/SlashCommands.lua:632-658` · pattern `elseif-dispatch` · risk **low**

**What it does.** The `/cm aio <key> toggle <ref> [on|off]` verb: validates that <ref> belongs to the composite category, then sets cfg.enabled[ref] to an explicit on/off value or flips the current one (defaulting unset to enabled), reports the new value and kicks a recompute.

**Where the branches come from.** Almost entirely literal-matching and defaulting: `args[1] and args[1]:upper() or nil`, three guards each with its own usage message, then a six-literal if/elseif chain (`on|true|1|yes` vs `off|false|0|no`), the nil-default fallback (`if cur == nil then cur = true end`), and a final `newVal and true or false` normalization.

**Fix.** Two changes. (a) Module-level constant lookup table replacing the literal chain: `local BOOL_WORDS = { on = true, ["true"] = true, ["1"] = true, yes = true, off = false, ["false"] = false, ["0"] = false, no = false }`, then `local newVal = BOOL_WORDS[(args[2] or ""):lower()]; if newVal == nil then local cur = cfg.enabled[ref]; if cur == nil then cur = true end; newVal = not cur end` — six branches become one lookup plus two. Because the table only ever holds booleans, `nil` unambiguously means "no explicit word", so the `and true or false` normalization at the end stays correct and can be dropped only if you keep the values strictly boolean. (b) `local function requireAIORef(cat, rest, usageVerb)` returning `cfg, ref` or nil after saying the right message — the tokenize + upper + usage + compositeCfg + locateAIORef preamble is byte-identical to the head of aioMove (660+), so extracting it removes duplication as well as branches (CCN 6). aioToggle becomes: requireAIORef guard, `cfg.enabled = cfg.enabled or {}`, resolve newVal, write, say, afterMutation — CCN ~4.

**Must not change.** cfg.enabled[ref] must be written as a real boolean (never nil, never a string) — the composite body builder tests `enabled[ref] ~= false`, so writing nil would silently re-enable. An unset ref must flip to false (treated as currently-on), not to true. Every rejection path returns after saying why. afterMutation must fire only on the success path.

**Coverage.** tests/test_slash.lua covers the aio verbs; tests/test_macromanager.lua covers how enabled[] feeds BuildCompositeBody. Check that a test pins the unset-ref flip direction before changing the default logic.

---

### `parseDuration` — CCN 19 → target 7

`core/TooltipCache.lua:209-256` · pattern `field-defaulting` · risk **medium**

**What it does.** Extracts a buff duration in seconds from one tooltip line: strips parenthesized cooldown notes, skips standalone cooldown lines, then matches hour/hr, minute and second forms in that order, keeping the longest duration seen. An "over N sec" phrasing is routed to pctOverDurationSec / healOverSec / manaOverSec instead of buffDurationSec so the Ranker can tell an immediate heal from a heal-over-time.

**Where the branches come from.** Three near-identical unit blocks, each pairing a pattern match with the same `if not result.buffDurationSec or n > result.buffDurationSec then` longest-wins test — six branches of pure duplication. Plus the `durHour or durHr` alternation and the "over" sub-block's three independent `result.a or result.b` pair tests.

**Fix.** Three changes, all allocation-free. (a) `local function noteLongestBuff(result, n) if not result.buffDurationSec or n > result.buffDurationSec then result.buffDurationSec = n end end` (CCN 3) — collapses the six duplicated branches into one place. (b) Module-level constant unit table beside PATTERNS: `local DUR_UNITS = { { pat = PATTERNS.durHour, mult = 3600 }, { pat = PATTERNS.durHr, mult = 3600 }, { pat = PATTERNS.durMin, mult = 60 }, { pat = PATTERNS.durSec, mult = 1, isSec = true } }` and a `local function matchDuration(cleaned)` that walks it in order and returns `n, isSec` on the first hit (CCN 4). Order in the array preserves today's hour → hr → min → sec precedence exactly. (c) `local function noteOverDuration(result, n)` — the three `pct/heal/mana` pair tests (CCN 7). parseDuration becomes: strip, bare-cooldown guard, `local n, isSec = matchDuration(cleaned)`, `if not n then return end`, `if isSec and cleaned:find("over ", 1, true) then return noteOverDuration(result, n) end`, `noteLongestBuff(result, n)` — CCN ~6. Both tables are module-level constants, so nothing is allocated per line.

**Must not change.** Unit precedence is load-bearing: hour/hr must win over min must win over sec on a line containing several ("1 hour ... 3 sec"). The longest-wins rule applies ACROSS lines of one tooltip, so it must keep reading result.buffDurationSec, not a local. The "over" check applies to the SECONDS form only — an "over 1 hour" line currently falls into buffDurationSec and must keep doing so. An "over N sec" line must never write buffDurationSec, and it can set two or three of the over-fields on one line (the three tests are independent, not elseif). stripCooldownNotes runs before everything, and a residual bare "cooldown" still aborts the line.

**Coverage.** tests/test_tooltipcache.lua has 18 parse tests but none named for duration — the healPct/HOT distinction is covered indirectly by tests/test_ranker.lua:77 and :118 (immediate vs HOT pot ranking, which depend on healOverSec). Direct duration coverage is effectively NONE. Add characterization tests for hour-beats-sec precedence, longest-wins across lines, and the three over-field writes before touching this.

---

### `validateSchemaValue` — CCN 18 → target 7

`settings/Panel.lua:576-603` · pattern `elseif-dispatch` · risk **low**

**What it does.** Validates a value against a schema row's declared type on the single mutation seam shared by the panel widgets and `/cm set`: type-checks bool/number/string/color, clamps numbers to the row's min/max, and rejects strings outside an enum row's allowed `values` list. Returns the coerced value, or nil plus a reason.

**Where the branches come from.** A textbook type-dispatch chain: four `t == "..."` arms, each with its own type check, plus the number arm's two independent clamp branches and the string arm's enum block (an EnumValues-or-values fallback, a table/length test, a scan loop with a match flag, and a rejection fork).

**Fix.** Table-driven dispatch on the declared type. Module-level constant `local VALIDATORS = { bool = function(def, v) ... end, number = function(def, v) ... end, string = function(def, v) ... end, color = function(def, v) ... end }`, each returning the coerced value or nil plus a reason. Then `local function validateSchemaValue(def, value) local f = VALIDATORS[def.type]; if not f then return value end; return f(def, value) end` — CCN 3. The largest validator is the string/enum one at CCN ~7 (fallback, table test, scan, reject); number is CCN 4, bool and color CCN 2 each. Critically, the `if not f then return value end` arm reproduces today's fall-through: an unrecognized or nil `def.type` currently passes every elseif and returns the value unchanged, and that must be preserved. This is also the cleanest LibKa0s upstream candidate in the repo — see sharedCandidates.

**Must not change.** An unknown or absent def.type must return the value unchanged (today's fall-through), not reject it. Clamping is one-sided-safe: min and max are independently optional. The enum check only applies when `allowed` is a non-empty array, and it reads `Helpers.EnumValues(def)` first (dynamic lists like registered LSM borders) falling back to `def.values` — that order matters, tests/test_macrobar.lua:893 depends on the dynamic path. Enum members are compared on `item.value` (not the label) and the rejection message lists every allowed value comma-separated. The function returns `nil, reason` on failure — a single-value return would read as a valid nil to SetAndRefresh.

**Coverage.** Well covered: tests/test_schema.lua:201 (each declared type), :214 (clamping), :223/:239/:250 (the SetAndRefresh seam including a wrong-type rejection), and tests/test_macrobar.lua:849/:857/:893 (enum accept/reject on both a static list and the dynamic border list). Safe to refactor against these.

---

### `FO.Apply` — CCN 17 → target 7

`modules/MacroBarFlyout.lua:429-497` · pattern `options-builder` · risk **medium**

**What it does.** Rebuilds one bar slot's flyout: tears it down when the feature is off, otherwise positions and paints the hover indicator band and arrow, resolves the candidate IDs, sizes and anchors the strip, grows the entry pool lazily, binds and places each entry, hides the surplus, and records the kcmEntries / kcmGrace attributes the secure snippet gates on.

**Where the branches come from.** Four sections sharing one body: the entry guards plus the inCombat gate; the `not cfg.flyout` teardown with its own hide loop; the indicator block with a four-element shade-color defaulting run; the entry loop with a lazy-create fork plus the surplus-hide loop; and the trailing `#ids == 0` special case.

**Fix.** Three file-local extractions. (a) `local function teardownFlyout(button, flyout)` — hide indicator, hide flyout, hide every entry, zero both kcmEntries attributes (CCN 3). (b) `local function applyIndicator(button, cfg)` — the IndicatorAnchor call and the band/arrow setup, using the shared `rgba` helper from the ApplyStyle item for the shade color (CCN 3). (c) `local function layoutEntries(flyout, ids, cfg, grid)` — the bind/place loop and the surplus-hide loop (CCN 5). FO.Apply becomes: guards, `if not cfg.flyout then teardownFlyout(...) return true end`, applyIndicator, Candidates + Flyout grid, frame geometry + ApplyBackdrop, layoutEntries, the three attribute writes, the `#ids == 0` hide — CCN ~7.

**Must not change.** Out of combat only — the inCombat() early return returning false (not true) is the signal callers use. Entry frames are POOLED and grown, never destroyed: creating a secure-template frame in combat is illegal, so the lazy `createEntry` must stay inside the out-of-combat path and surplus entries must be Hidden, not released. kcmEntries and kcmGrace are read by the secure snippet — both must be written on every non-teardown path, and the teardown path must zero kcmEntries on BOTH the flyout and the indicator. The indicator's frame level is deliberately button level + 1 (below border and count). Strata stays DIALOG. The `#ids == 0` case hides the indicator too, so there is no arrow teasing an empty popup.

**Coverage.** tests/test_macrobar.lua covers FO.Candidates and the layout grid, and references the flyout broadly, but the Apply orchestration and the teardown path are not directly asserted. Add characterization tests for the cfg.flyout-off teardown (both kcmEntries zeroed) and the zero-candidates hide before refactoring.

---

### `statWeight` — CCN 17 → target 6

`modules/Ranker.lua:105-123` · pattern `elseif-dispatch` · risk **low**

**What it does.** Returns the ranking weight of a single stat under the active spec's priority: PRIMARY_WEIGHT for the primary stat (with AP mapping to STR/AGI specs and SP to INT), 100*(N-k+1) for the k-th secondary so position 1 weighs most, secondary[1]'s weight for the TOP_SECONDARY wildcard, and 0 for anything unranked.

**Where the branches come from.** Six stacked early returns, four of which carry compound conditions: the two-term nil guard, `(p == "STR" or p == "AGI") and PRIMARY_WEIGHT or 0`, the SP mirror, the direct primary test, the sec-nil guard, the `n > 0 and 100 * n or 0` wildcard, and finally the linear secondary scan with its inner name test.

**Fix.** HOT PATH — called once per stat per candidate inside the ranking loop, so the refactor must be allocation-free. Two module-level constant tables plus one extraction. (a) `local PRIMARY_ALIAS = { AP = { STR = true, AGI = true }, SP = { INT = true } }` at module scope; then `local alias = PRIMARY_ALIAS[stat]; if alias then return alias[specPriority.primary] and PRIMARY_WEIGHT or 0 end` — four branches become two, and adding a future alias becomes a table edit. (b) `local function secondaryWeight(stat, sec)` — the nil guard, the TOP_SECONDARY wildcard and the linear scan (CCN 5). statWeight becomes: nil guard, alias lookup, `if stat == specPriority.primary then return PRIMARY_WEIGHT end`, `return secondaryWeight(stat, specPriority.secondary)` — CCN ~6. Optional further win, only if profiling asks for it: memoize the stat→index map per `secondary` table in a module-level weak-keyed cache to drop the linear scan. Do NOT do this without first confirming SpecHelper rebuilds the secondary table on spec change rather than mutating it in place — an in-place mutation would serve stale weights. The table-only version already clears the 15 bar comfortably.

**Must not change.** Hot path: no per-call table allocation, and PRIMARY_ALIAS must be a module-level constant. Exact weights are asserted: PRIMARY_WEIGHT for primary/AP/SP hits, 100*(N-k+1) for secondaries so first place weighs most, 100*N for TOP_SECONDARY (which equals secondary[1]'s weight — that identity must hold if N changes), 0 for unranked and for AP under an INT spec. The PRIMARY token is deliberately NOT a match (tests/test_ranker.lua:375 pins that statWeight stays 0 for it).

**Coverage.** tests/test_ranker.lua is strong here: :144 tests _statWeight against spec priority directly, :243 pins AP/SP aliasing including the 0 case, :375 pins the PRIMARY token, and :161/:178 cover primary-beats-secondary end to end. Safe to refactor against these.

---

### `KCM.ResetAllToDefaults` — CCN 16 → target 7

`core/ConsumableMaster.lua:465-486` · pattern `field-defaulting` · risk **low**

**What it does.** Restores db.profile.categories, db.profile.statPriority and db.profile.enabled from dbDefaults, then invalidates the tooltip cache and kicks a discovery + recompute so the panel and macros refresh immediately. Returns true when the DB was mutated.

**Where the branches come from.** Pure defaulting and optional-call plumbing: a two-term db guard, `KCM.dbDefaults and KCM.dbDefaults.profile or {}`, three `defaults.X or {}` CopyTable arguments, `defaults.enabled ~= false`, `reason or "reset_all"`, a `State.debug` guard, and three two-term `KCM.Mod and KCM.Mod.Fn` optional-call blocks.

**Fix.** Two file-local helpers plus the shared `dbg`. (a) `local function restoreProfileDefaults(profile, defaults)` — the three CopyTable writes and the `enabled ~= false` write (CCN 4). (b) `local function afterReset(reason)` — the TooltipCache.InvalidateAll / Pipeline.RunAutoDiscovery / Pipeline.Recompute optional-call block (CCN 7). Do NOT collapse (b) into a data-driven `{module, method}` loop: InvalidateAll takes no argument while the other two take `reason`, so a uniform loop would either pass a bogus arg or need an arity flag — three explicit guarded calls in one small named function is the readable shape. ResetAllToDefaults becomes: db guard, `local defaults = ...`, restoreProfileDefaults, `reason = reason or "reset_all"`, dbg, afterReset, return true — CCN ~5.

**Must not change.** `enabled = defaults.enabled ~= false` is deliberately fail-safe (missing defaults key leaves the addon ON) — do not rewrite as `defaults.enabled or true` or as a plain copy. CopyTable must stay a copy, not an alias to the defaults table. The order matters: invalidate cache → discover → recompute; discovery must see a cleared cache and recompute must see the refreshed discovered set.

**Coverage.** tests/test_pipeline.lua references ResetAllToDefaults. Verify it asserts the enabled fail-safe and the three post-reset calls; if not, add a characterization test for the `defaults.enabled == nil` case.

---

### `MD.SetTooltip` — CCN 16 → target 8

`core/MacroDisplay.lua:163-183` · pattern `guard-stack` · risk **low**

**What it does.** Points GameTooltip at whatever the named macro currently resolves to — SetSpellByID for a spell pick, SetItemByID for an item pick, otherwise the macro name plus its body text as a fallback so a button is never a mystery.

**Where the branches come from.** A two-term owner guard, then two four-term branch conditions (`ID and id and ID.IsSpell(id) and GameTooltip.SetSpellByID`, and the item mirror of it), and a fallback arm carrying `macroName or ""`, `idx ~= 0 and GetMacroInfo`, and `body and body ~= ""`.

**Fix.** Split the two arms into named file-locals. (a) `local function setTooltipForID(id)` — returns true if it set the tooltip from a spell or item ID, false otherwise (the two four-term branches, CCN 7). (b) `local function setTooltipFromMacro(macroName)` — the name + GetMacroInfo body fallback (CCN 7). MD.SetTooltip becomes: owner guard, SetOwner, `if not setTooltipForID(MD.PickID(macroName)) then setTooltipFromMacro(macroName) end`, Show — CCN 3. Warm path (fires on every button OnEnter, not per frame) and neither helper allocates, so this is allocation-neutral. Do not table-drive on ID kind here: the API-presence checks (`GameTooltip.SetSpellByID`) are part of each branch's condition and a dispatch table would have to re-test them anyway.

**Must not change.** GameTooltip:SetOwner must still run before any Set*, and Show() must run on every path including the fallback — an early return that skips Show leaves a stale tooltip anchored. The API-presence checks guard Classic/Midnight builds where SetSpellByID or GetMacroInfo may be absent; keep them in the conditions, not hoisted to load time. MacroIndex returning 0 means "no such macro" and must stay a skip, not an index-0 call.

**Coverage.** NONE for SetTooltip specifically. tests/test_macrobar.lua touches MacroDisplay but not the tooltip path. Write a characterization test with a GameTooltip mock recording which setter fired for a spell ID, an item ID and an unresolved macro name before refactoring.

---

### `parseLines` — CCN 16 → target 6

`core/TooltipCache.lua:306-363` · pattern `guard-stack` · risk **low**

**What it does.** Walks every tooltip line and accumulates one parsed result table: percent heal/mana first, flat heal/mana only if no percentage form matched, then the conjured/feast/augment-rune flags, the max-level cap (only when the line also carries a negation), the weapon-enhance marker with its bladed/blunt/any affinity, and finally duration and stat buffs.

**Where the branches come from.** Seven independent per-line concerns inlined in one loop body: the loop plus the non-empty guard, the pctHit fork, four standalone flag `if`s, the `cap and hasNegation(txt)` pair, and the weapon-enhance block's own three-armed affinity chain with its `not result.weaponAffinity` guard.

**Fix.** Three file-local per-concern extractions, matching the file's existing parseX(line, result) convention. (a) `local function parseFlags(txt, result)` — isConjured, isFeast and the two-pattern isAugmentRune test (CCN 5). (b) `local function parseMaxLevel(txt, result)` — the two cap patterns plus the hasNegation gate (CCN 4). (c) `local function parseWeaponEnhance(txt, result)` — the `your ([%a%s%-]-)weapon` match and the bladed/blunt/any chain (CCN 6). parseLines becomes: loop, non-empty guard, the pct/flat fork, then five uniform calls (parseFlags, parseMaxLevel, parseWeaponEnhance, parseDuration, parseStatBuffs) — CCN ~5. Deliberately NOT a parser-array loop: the pct/flat ordering is conditional (flat is only tried when pct missed), so a uniform array would have to encode that exception and would read worse than five named calls.

**Must not change.** The pct-then-flat ordering is a real rule — a line that matched a percentage form must not also be scanned for flat values. The affinity chain's `elseif not result.weaponAffinity` means the first non-bladed/blunt line sets "any" but a later line can still upgrade nothing — first-wins for "any", but bladed/blunt always overwrite; preserve that asymmetry exactly. maxLevel only lands when hasNegation is true on the SAME line. The result table starts as `{ statBuffs = {} }` and accumulates across all lines — no per-line reset.

**Coverage.** tests/test_tooltipcache.lua covers most of these directly: weapon enhance and affinity (:62, :106), augment rune (:129, :151), combined pct (:83), max-level cap and the negation rule (:227, :237, :247). isConjured/isFeast are covered indirectly via tests/test_ranker.lua:27 and :61. Coverage here is good.

---

### `submitAddByID` — CCN 16 → target 8

`settings/Category.lua:329-356` · pattern `elseif-dispatch` · risk **low**

**What it does.** Validates one typed ID from the category panel's add-by-ID field and seeds it into the category: rejects non-positive or non-numeric input, checks the ID actually exists as a spell or an item depending on the kind selector, refuses spec-aware categories with no active spec, then wraps a spell ID in the KCM.ID sentinel and calls Selector.AddItem.

**Where the branches come from.** A per-kind validation ladder: the `not id or id <= 0` guard, `O._addKind[cat.key] or "ITEM"`, an if/else on kind where each arm nests its own existence check and message, the spec-aware guard, `(kind == "SPELL") and KCM.ID.AsSpell(id) or id`, and a three-term AddItem chain.

**Fix.** Replace the kind ladder with a module-level constant descriptor table: `local ID_KINDS = { SPELL = { exists = function(id) return spellNameByID(id) ~= nil end, unknown = "unknown spellID: ", store = function(id) return KCM.ID.AsSpell(id) end }, ITEM = { exists = function(id) return not (C_Item and C_Item.GetItemInfoInstant) or C_Item.GetItemInfoInstant(id) ~= nil end, unknown = "unknown itemID: ", store = function(id) return id end } }`. Note the ITEM predicate must preserve today's semantics exactly: the current code only rejects when the API EXISTS and returns nothing, so an absent C_Item must pass. submitAddByID becomes: numeric guard, `local k = ID_KINDS[O._addKind[cat.key] or "ITEM"] or ID_KINDS.ITEM`, `if not k.exists(id) then KCM.Say(k.unknown .. id) return end`, the specAware guard, `local storedID = k.store(id)`, the AddItem call — CCN ~8. Adding a third ID kind then becomes one table entry rather than another elseif arm.

**Must not change.** Every rejection says why and stops — silent failures are the anti-pattern this function exists to avoid, and the message text is user-facing. Only a fully-resolved ID may reach Selector.AddItem. The ITEM existence check is conditional on the API being present (Classic/Midnight safety) — do not tighten it into an unconditional check. Spell IDs must be stored through KCM.ID.AsSpell (the opaque sentinel), never raw, or they collide with item IDs. afterMutation fires only when AddItem reports an actual change.

**Coverage.** tests/test_selector.lua and tests/test_pipeline.lua cover Selector.AddItem; tests/test_settingsui.lua covers the panel but not this validator. Effectively NONE for the rejection paths — add characterization tests for the non-numeric, unknown-spell, unknown-item and no-spec rejections before refactoring.

---
