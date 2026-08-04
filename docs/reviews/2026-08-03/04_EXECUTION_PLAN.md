# 04 — Execution plan

Implements `02_PROPOSED_CHANGES.md`. Trunk-based: work on `master` unless the user explicitly asks for a branch (`versioning-git`, anti-pattern #21). Every task ends with `lua tests/run.lua` green and `luacheck .` clean — that is the commit gate (anti-pattern #23), and every logic change ships with a covering test (`testing`, anti-pattern #24).

**No upstream milestone.** `tests/test_vendor_sync.lua` confirms `libs/LibKa0s/` and `tests/_kit/` are byte-identical to the LibKa0s v1.5.0 tag the README names, and no finding in this review lives under either path. Nothing is handed to another repo; no re-vendor commit is required.

---

## M0 — Verification gate (no code)

**Done when:** the F-008 answer is recorded in `03_SMOKE_TESTS.md`'s sign-off row for C-07.

| Task | Owner role | Finding/Change | Files |
|---|---|---|---|
| V-01 | qa-in-client | F-008 | none — run `03_SMOKE_TESTS.md` § C-07 "pre-fix, diagnostic" only |

**Why first.** C-07's shape (a guard plus a comment, or a comment alone) depends on the answer, and the answer is a five-minute in-client check. Doing it before M3 avoids writing a guard the client does not need or shipping a comment that lies.

---

## M1 — Correctness: the macro-write path

**Done when:** C-01 lands, the new tests pass, and `03_SMOKE_TESTS.md` § C-01 passes in-client.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-01 | lua-refactorer | C-01 (F-006 half): give `commitMacro` an `opts` tail, rewrite `SetCompositeMacro` to call it, delete the duplicated ladder | `modules/MacroManager.lua` |
| T-02 | lua-refactorer | C-01 (F-001 half): `kind`/`cat` on every pending entry, `FlushPending` three-way dispatch | `modules/MacroManager.lua` |
| T-03 | test-author | covering tests: (a) a per-hand macro deferred in combat flushes with `/use 16`+`/use 17`; (b) a composite deferred in combat flushes as a composite; (c) `commitMacro`'s icon override produces `DYNAMIC_ICON` for an active composite | `tests/test_macromanager.lua` |

**Serialization.** T-01 → T-02 → T-03, strictly. All three touch `modules/MacroManager.lua`; T-02's dispatch depends on T-01's `opts` plumbing, and T-03 asserts against both.

**Checkpoint CP-1 (human).** Review the unified `commitMacro`/`FlushPending` diff before anything else is built on it. This is the addon's only protected-API caller and its combat contract (`events-frames-taint-§4`) is the single most load-bearing invariant in the repo.

---

## M2 — Robustness: degraded and partial installs

**Done when:** C-02 and C-03 land and `03_SMOKE_TESTS.md` § C-02 and § C-03 both pass with zero Lua errors.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-04 | lua-refactorer | C-02: inert `RefreshAllPanels`/`RefreshScalars` fallbacks + corrected invariant comment | `settings/Panel.lua` |
| T-05 | lua-refactorer | C-03: guard the Perf `log` thunk | `modules/PerfSetup.lua` |
| T-06 | test-author | tests: with the Options major absent, `Helpers.SetAndRefresh` and `O.Refresh` are no-ops rather than errors; with the DebugLog major absent, the Perf descriptor's `log` is safe | `tests/test_settingsui.lua`, `tests/test_perfsetup.lua` |

**Concurrency.** T-04 and T-05 touch **disjoint** files → **parallelizable**. T-06 depends on both.

---

## M3 — Convention + UX

**Done when:** C-04, C-06, C-07 land; § C-04, § C-06, § C-07 pass in-client.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-07 | ux-cleanup | C-04: `/cm bar` verbs write through `KCM.Schema:Set`; de-duplicate the in-combat notice | `core/SlashCommands.lua` |
| T-08 | ux-cleanup | C-06: composite icon resolution (`MD.CompositePickID` + `MD.Texture` sentinel handling) | `core/MacroDisplay.lua` |
| T-09 | wow-api-migrator | C-07: combat guard on `OnDragStart` (only if V-01 confirmed) + comment correction (either way) | `modules/MacroBarButton.lua`, `modules/KCMMacroDragIcon.lua` |
| T-10 | test-author | tests: `/cm bar on` routes through the schema seam and fires the row's `onChange`; `MD.Texture` returns a component icon for a composite and never the `?` sentinel | `tests/test_slash.lua`, `tests/test_macrobar.lua` |

**Concurrency.** T-07, T-08, T-09 touch disjoint files → **all three parallelizable**. T-10 depends on T-07 and T-08.
**Serialization warning.** T-07 touches `core/SlashCommands.lua`, which **M5/T-15** (the `/cm stat` DB guard) also touches → those two must not run concurrently. Sequence T-07 before T-15.

---

## M4 — Performance

**Done when:** C-05 and C-09 land, § C-05 and § C-09 pass, and the two "before/after" numbers from the perf spot-checks are recorded.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-11 | perf-engineer | C-05: `isInitialLogin`/`isReload` gating; `runAutoDiscovery` returns its bag counts; corrected comment | `core/ConsumableMaster.lua` |
| T-12 | perf-engineer | C-05: `SweepStaleDiscovered(nowUnix, bagCounts)` optional second arg | `modules/Selector.lua` |
| T-13 | perf-engineer | C-09: bounded pending retry with an `unparsed` terminal state | `core/TooltipCache.lua` |
| T-14 | test-author | tests: the sweep is skipped on a non-login PEW; the sweep reuses supplied counts (assert `BagScanner.Scan` call count); a permanently-unparsable consumable stops re-parsing after the ceiling | `tests/test_events.lua`, `tests/test_selector.lua`, `tests/test_tooltipcache.lua` |

**Concurrency.** T-11 and T-12 are coupled by the new signature → serialize T-12 before T-11 (add the optional arg first, then pass it). T-13 is independent → **parallelizable** with both.

**Checkpoint CP-2 (human).** Confirm the perf numbers actually moved before accepting M4; C-05 is justified by a cost claim and an unmeasured "optimization" is not a fix.

---

## M5 — Hygiene

**Done when:** C-08 and C-10 land; § C-08 and § C-10 pass; the full regression suite (R-1…R-11) is green.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-15 | lua-refactorer | C-08a/b/d/f: delete the three unused exports, fix the two stale comments, hoist the `/cm stat` DB guards | `modules/DebugLog.lua`, `modules/MacroBar.lua`, `core/Bus.lua`, `core/SlashCommands.lua` |
| T-16 | lua-refactorer | C-08c: one `publishPanelRefresh()` helper + message-table update | `core/ConsumableMaster.lua`, `docs/ARCHITECTURE.md` |
| T-17 | lua-refactorer | C-08e: defaults-resolution pass in `ValidateSchema` | `settings/Panel.lua` |
| T-18 | wow-api-migrator | C-10: `ActionButtonUseKeyDown` honoured, re-registration deferred through the existing combat queue | `modules/MacroBarButton.lua`, `modules/MacroBarFlyout.lua`, `modules/MacroBar.lua` |
| T-19 | test-author | tests: `ValidateSchema` flags a row whose path does not resolve; `/cm stat primary` with no DB answers rather than errors | `tests/test_schema.lua`, `tests/test_slash.lua` |

**Concurrency / serialization map.**
- T-15 ∩ T-07 on `core/SlashCommands.lua` → **serialize** (T-07 first, M3 before M5).
- T-15 ∩ T-16 on nothing (different files) → parallel, but both touch M-milestone docs; land T-16's doc edit last.
- T-17 ∩ T-04 on `settings/Panel.lua` → **serialize** (T-04 in M2 lands first).
- T-18 ∩ T-09 on `modules/MacroBarButton.lua` → **serialize** (T-09 in M3 first).
- T-18 ∩ T-01/T-02 on nothing → parallel with M1.

---

## M6 — Documentation and release hygiene

**Done when:** the docs describe the shipped behaviour and the changelog carries the user-visible half.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-20 | docs-author | `CHANGELOG.md` "Unreleased" entries for every user-visible change (C-01, C-03, C-04, C-05, C-06, C-10) | `CHANGELOG.md` |
| T-21 | docs-author | If a version bump is cut: roll `README.md`'s `## What's new in <X.Y.Z>` forward **in the same commit** as the bump, and add the Version History row (anti-pattern #40, `versioning-git`) | `README.md`, `ConsumableMaster.toc`, `core/ConsumableMaster.lua` (`KCM.VERSION`) |
| T-22 | docs-author | Record F-008's verified answer in `docs/macro-bar.md` so the next reader does not re-litigate it | `docs/macro-bar.md` |

**Note on T-21.** `KCM.VERSION` (`core/ConsumableMaster.lua:9`), the TOC `## Version`, and `modules/PerfSetup.lua`'s `version = KCM.VERSION` must move together; `addonVersion()` reads the TOC first, so a mismatch shows up as a wrong `/cm version` only after packaging.

---

## Critical-path summary

```
M0 (V-01, 5 min)
      │
      ├─────────────► M1 (T-01 → T-02 → T-03) ──► CP-1 ──┐
      │                                                   │
      ├─ M2 (T-04 ∥ T-05 → T-06) ────────────────────────┤
      │                                                   ├──► M5 ──► M6
      ├─ M3 (T-07 ∥ T-08 ∥ T-09 → T-10) ─────────────────┤
      │                                                   │
      └─ M4 (T-12 → T-11 ∥ T-13 → T-14) ──► CP-2 ────────┘
```

M1–M4 are mutually independent by file set **except** the two serialization pairs called out in M5. The longest chain is M1 (three serialized tasks on one file) plus CP-1.

---

## Commit strategy

One commit per task, each self-contained and green. Suggested messages:

```
fix(macro): flush per-hand macros through their own builder (F-001)
refactor(macro): one write tail — SetCompositeMacro calls commitMacro (F-006)
test(macro): cover the combat-deferred per-hand and composite flushes

fix(settings): keep /cm set and /cm debug working without LibKa0s (F-002)
fix(perf): guard the DebugLog thunk against a partial LibKa0s vendor (F-007)

fix(slash): /cm bar writes through Schema:Set so the panel stays in sync (F-004)
fix(bar): resolve a real icon for composite slots instead of the ? sentinel (F-003)
fix(bar): combat-guard the drag pickup (F-008)

perf(events): run the discovered-set sweep on login/reload, not every zone (F-005)
perf(tooltip): bound the pending re-parse retry (F-015)

chore: drop three uncalled exports and correct two stale comments (F-009, F-010, F-012)
fix(schema): validate that every row's path resolves against the defaults (F-013)
fix(slash): guard /cm stat writes on a ready DB (F-014)
docs(architecture): document the event-layer PANEL_REFRESH publisher (F-011)
feat(bar): honour ActionButtonUseKeyDown (F-016)
```

Do **not** commit or push without the user's explicit request; approval for one commit does not carry to the next (`versioning-git`, repo `CLAUDE.md`).
