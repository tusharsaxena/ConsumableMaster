# 02 — Deviations: Ka0s Consumable Master (2026-10-07)

Measured against standard **v2.76.1** at `862151a`. The prefix is `CM-`, and IDs from
`docs/audits/2026-09-23/` are reused where a finding recurs. Grades follow `AUDIT.md` step 5: they
measure impact, not rule strength. Evidence, commands and quoted lines are in `03_EVIDENCE.md`.

## Headline

**Verdict: minor deviations.** No finding is reachable by a user. Every open MUST failure is a
documentation or record-keeping gap, graded Low.

| Basis | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline tally (root deviations only)** | 0 | 0 | 7 | 2 | **9** |
| Total including `derived from` dependents (there are none) | 0 | 0 | 7 | 2 | **9** |
| **MUST failures, roots only** (all of them Low) | 0 | 0 | 5 | 0 | **5** |
| MUST failures, including dependents | 0 | 0 | 5 | 0 | **5** |

Two of the open Lows fail a SHOULD (`CM-75`, `CM-83`), and the two Info entries are notes. **Three
ratified register rows are recorded as accepted** and count toward no tally (*Recorded deviations*,
below). Fourteen prior findings are verified closed.

---

## Root deviations

| ID | Section (`filename-§N`) | Grade | Strength | Deviation | Fix direction |
|----|-------------------------|-------|----------|-----------|---------------|
| **CM-91** | `audit-review-history` (every re-vendor has its bundle) | Low | **MUST** | **Two LibKa0s tags vendored since the last bundle have no `docs/revendor/` bundle and no register row: v1.69.0 (`f8d2f3b`, 2026-10-06) and v1.70.0 (`74bcda1`, 2026-10-07).** The `AUDIT.md` comparison reads 53 tags off the payload and 51 off the store. The newest bundle is `2026-10-04-v1.68.1`. This is the 2026-09-23 finding again, much smaller: the 27-tag backlog was discharged by the span bundle `2026-09-24-v1.16.0-v1.54.2`, and the convention then held until these two commits. | Write one span bundle, `docs/revendor/2026-10-07-v1.68.1-v1.70.0/`, whose `01_DELTA.md` line 1 is `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)`. Both releases add Widgets files (`WidgetsLineChart.lua`, `WidgetsAutocomplete.lua`) that this addon does not call. |
| **CM-97** | `documentation-§5` ("**MUST** keep the doc set in sync with code") | Low | **MUST** | **19 `file:line` citations in `docs/ARCHITECTURE.md` point at the wrong lines, and one authored doc names a retired plugin command.** (a) The citations moved when `core/ConsumableMaster.lua` and `modules/MacroManager.lua` grew in the DL-CM/DG-CM debug passes (2026-09-30 to 10-01). The 2026-10-03 `SD-FIN-01` sync missed them. All ten handler citations in the *Event Subscriptions* table (`:168-177`) are 10 lines short; for example `OnRegenEnabled (:768)` is now at `:778`. `RegisterProfileCallbacks` is cited as `:548` / `:548-611` and is now at `:558-621` (`:102`, `:123`). `:814` is now `:824` (`:124`). The `macroState` writers are cited as `:466`, `:480`, `:501`, `:710`, `:717` and `:733`, and are now at `:498`, `:512`, `:531`, `:737`, `:744` and `:760` (`:122-124`). (b) `docs/perf-analysis/README.md:133` names `/wow-addon:perf-analysis`, which v2.76.0 renamed to `/dev-copilot:wow-perf-analysis`. **Scope:** every `file:line` in `docs/ARCHITECTURE.md` that points into those two files was re-read, and every `/wow-addon` reference in authored `.md`/`.lua`/`.toc` files was grepped. Other docs were spot-checked, not swept. | Run one `/dev-copilot:sync-docs` pass. Where possible, cite a handler by name rather than by line (the *Event Subscriptions* table already names each one), so the next growth does not move 10 cells. |
| **CM-98** | `toc-file-§5` ("A line whose position is load-bearing **MUST** carry a comment … naming what resolves at load") | Low | **MUST** | **`core\SlashDump.lua` (`ConsumableMaster.toc:143`) is load-bearing and is not annotated with what resolves.** `core/SlashDump.lua:16` takes `local say = KCM.Say` at file scope, so a SlashDump loaded above `core\CoreSetup.lua` would capture `nil`, and all 45 `say(` calls in the file would raise. The TOC comment on that line (`:139-142`) explains the order *relative to SlashCommands*, and CoreSetup's comment (`:97-99`) names only `core\SlashCommands.lua` as the printer's file-scope consumer. The file's own comment at `:15` attributes the seam to `core/Constants.lua`, which has not been true since `KCM.Say` moved to `core/CoreSetup.lua`. Latent: the current order is correct. | Extend the CoreSetup annotation to *"before core\SlashDump.lua and core\SlashCommands.lua, which take the printer as a file-scope upvalue"*. Correct `core/SlashDump.lua:15` to name `core/CoreSetup.lua`. |
| **CM-99** | `audit-review-history` ("**MUST** … resolve every evidence id the row cites … the finding id to one under `docs/reviews/`") | Low | **MUST** | **Two register rows cite evidence ids that resolve, in this repo, to nothing or to unrelated findings.** The `compat` row (`docs/ARCHITECTURE.md:376`) cites *review findings `CM-R-10` and `CM-R-05`*. The only `CM-R-NN` ids under `docs/reviews/` are in `2026-09-07/01_FINDINGS.md`, where `CM-R-05` is *"Two `colorDecode` codecs"* (`:206`) and `CM-R-10` is *"`KCM.MakeCloseButton` has zero call sites"* (`:309`). The findings the row means are `docs/reviews/2026-08-05/01_FINDINGS.md:289` (F-010) and `docs/reviews/2026-09-23/01_FINDINGS.md:226` (F-005), which reached `CM-R-*` ids only through the cross-repo consolidation. The `options-ui-§1` row (`:377`) cites *"CM-18, WS-02 ruling"*. In this repo, `CM-18` resolves to `docs/audits/2026-07-12/02_DEVIATIONS.md:26` (*"Root `CLAUDE.md` carries the full agent brief"*). The id meant is the remediation item in `../Ka0sAddonsCommonTasks/.../items.tsv:310`, and `WS-02` exists only in that sibling repo. The rows' reasoning stands; only the pointers are wrong. | Rewrite each citation to an id that resolves here: `docs/reviews/2026-08-05` F-010 and `docs/reviews/2026-09-23` F-005 for the `compat` row; the 2026-09-23 audit/review bundle (or issue #39) for the `options-ui-§1` row. Name a cross-repo plan item, if at all, by its full path. |
| **CM-100** | `automated-tests-§3` (*The complexity gate is sighted*: the runner command "is the one every gate line … quotes"; "the raw `lizard -l lua ...` line is the blind one") | Low | **MUST** | **`docs/testing.md:283`, the gate table's `complexity` row, puts the raw `lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .` in its *Command* column.** The same cell then qualifies it (*"run sighted over the kit's sanitized shadow … `--suite complexity`"*), but a reader who copies the Command cell runs the blind measurement. `CLAUDE.md:107` and `DEPENDENCIES.md` already quote the runner correctly. | Put `bash tests/_kit/run-automated-tests.sh --suite complexity` in the Command cell, and move the `lizard` invocation into a note naming it as the command the runner executes inside the shadow. |
| **CM-75** | `documentation-§6` (cite a subsection as `filename-§N`) | Low | SHOULD | **Three bare `§N` continuations remain in authored files**, down from 46 in 22 files on 2026-09-23: `modules/MacroManager.lua:709` (*"§9's quiet steady state"*), `tests/run.lua:477` (*"debug-logging-§8/§9"*) and `tests/test_debugcoverage.lua:2` (*"§9's quiet steady state"*). The range check over all **839** `filename-§N` citations in scope finds **0** out of range and **0** unknown files, so the MUST half is clean. `docs/smoke-tests.md`'s own `§N` numbering (51 hits) is out of scope. | Expand each to `debug-logging-§9`. |
| **CM-83** | `toc-file-§5` ("a merely conventional position **SHOULD** say that too, once per group") | Low | SHOULD | **The `# Defaults` group's conventional positions are unmarked** (`ConsumableMaster.toc:150-171`). `defaults\Profile.lua` carries its reason (`:151-155`). The fifteen lines after it, `Categories.lua` and the fourteen `Defaults_*.lua` seed files, carry no note, and they are free to move within the group: each reaches `KCM.ID` and `KCM.SEED`, which `# Core` or its own `or {}` already provides. The other three groups the 2026-09-23 run named are now marked (`:58`, `:174`, `:214`). One SHOULD row for the file, per the section's grading. | Add one line under the `Profile.lua` block, for example: *"The seed files below are conventional: each reaches `KCM.ID` (core) and its own `KCM.SEED` table, so their order is free."* |
| **CM-95** | `automated-tests-§4`, anti-pattern #51 | Info | — | **The record is 59 commits behind `HEAD`, and its newest run is unsighted.** `20260927-030419` measured `86660df` (the 1.7.0 release) with a kit older than revision 35, so its manifest carries no `suites.complexity.blindFiles`. That is a fact about the record, because v2.74.0 postdates the release. Today's sighted run (`--no-bundle`) reports 0 warnings, **max CCN 15** (the record says 14) and **3200** functions (the record says 2838; the extra functions are partly growth and partly ones `lizard` used to miss). Two files have entered the 1000–1500 band since the record: `tests/wow_mock.lua` (1012) and `tests/test_settingsui.lua` (1002). The generated header still names `/wow-addon:bump-version` (`docs/automated-tests/RESULTS.md:15`). The watch list has three *Accepted* entries, each carried for **one** release, so anti-pattern #53 does not fire. | Nothing now: the checkpoint is the release. The next release run is the first sighted one, and it regenerates the header. Record any function the sighted run lists at CCN 15 or above as *newly measured*, not *newly crossed*. |
| **CM-101** | `debug-logging-§9` (change gates use the console's `DebugChanged` / `DebugOnce`) | Info | SHOULD (noted) | **The host keeps one change gate of its own, `KCM.DebugQuiet` (`core/ConsumableMaster.lua:132-163`).** It holds the last summary per key and counts held passes, so a logged line can end with *"(after N unchanged pass(es))"*. Three callers use it: the `[Scan]` and no-write `[Calc]` summaries, and `modules/MacroManager.lua:392`'s oversize line. The reason is written at `:117-131`: the console's `DebugChanged` compares whole lines, so it cannot count. The gate is re-armed by the DebugLog descriptor's `onClear` (`core/DebugLogSetup.lua:258-259`) and on enable (`:81`, `:202`). `AUDIT.md` step 4 says to note such a gate, not file it. It is the shape `AUDIT.md` asks for (kept, reasoned, cleared on Clear). | Optional, upstream: offer `LibKa0s-DebugLog-1.0` a counting variant (`DebugChanged` returning the held-pass count, keyed separately from the line), then retire `KCM.DebugQuiet`. No local change is owed. |

---

## Derived dependents

None. No observation in this run follows from a single unadopted subsystem.

---

## Recorded deviations (accepted, not counted)

Each was checked against the current text of its rule, its re-check trigger was evaluated against
the tree, and its evidence ids were resolved. The id problem is `CM-99` and does not reopen any
decision.

| Register row | Decided | Trigger fired? | Verdict |
|---|---|---|---|
| `localization-§4` (`docs/ARCHITECTURE.md:375`): English tooltip-text parsing | 2026-08-05 | No: there is no structured-magnitude API and no non-enUS commitment | **Accepted.** `CM-30` resolves (`docs/audits/2026-08-05/02_DEVIATIONS.md`). |
| `compat` (`:376`): `GetItemCount` read directly at `modules/KCMItemRow.lua:230` and as a fallback at `core/MacroDisplay.lua:76` | 2026-08-05, narrowed 2026-09-24 | No: the global is not deprecated, and there is no third direct read (`core/BagScanner.lua:55` reads `C_Item.GetItemCount`, the namespaced API) | **Accepted.** Both cited sites re-read exactly. Review ids: see `CM-99`. |
| `options-ui-§1` (`:377`): library-absent `/cm enable|disable` take route (b) | 2026-09-24 | No: there is still no Lifecycle stub (`core/LifecycleSetup.lua:56` returns early), `enabled` has no new reader, and the row is still composed | **Accepted.** Evidence ids: see `CM-99`. |

---

## Closed since 2026-09-23

| Prior ID | Was | Verified closed by |
|---|---|---|
| `CM-84` | Flyout `kcmCombat` attribute drivers survived disable | `modules/MacroBarFlyout.lua:340-345` `FO.StandDown()` unregisters every built flyout's driver. It is called on the bar's disable path (`modules/MacroBar.lua:559`) and re-armed at `:576`. |
| `CM-85` | `test_disabled.lua` passed over `CM-84` | `tests/test_disabled.lua:215` reads `mock.attributeDrivers`. |
| `CM-86` | Combat-parked settings registration never replayed while disabled | Registration and replay are `LibKa0s-Options-1.0`'s (`settings/Panel.lua:1178` `UI.CreateOptionsPanel()`), on a library-private frame that ignores the stand-down. |
| `CM-87` | Bare event loop, with no rejected-name list | `core/ConsumableMaster.lua:912` `KCM.SafeRegisterEvent(...)` uses the library helper with the `IsEventValid` front gate. `KCM.RejectedEvents` is reachable through `/cm dump events`. |
| `CM-88` | Host-rolled panel open beside the library's | `settings/OptionsShim.lua:198` `UI.OpenOptionsPanel()`. No `OpenToCategory` call remains in the addon's own Lua. |
| `CM-89` | `## What's new` in the README | Gone (`grep -n "What's new" README.md` is empty). |
| `CM-90` | Stale `preview-mode` register row | Retired, with prose at `docs/ARCHITECTURE.md:381`. |
| `CM-92` | Hub at 504 lines | The hub is now **432** lines, and every mandated section is at or under ~60 lines. `AUDIT.md` step 4(f) says not to file a hub of roughly 412 lines whose sections have spilled, so this is not filed. |
| `CM-93` | Test bus literal typed at two call sites | `tests/test_harness.lua:69` `local PING = "Ka0s_ConsumableMaster_HarnessPing"`. |
| `CM-94` | Load-order statements omitted LifecycleSetup | `docs/ARCHITECTURE.md:284` lists `Namespace.lua → LifecycleSetup.lua → PerfSetup.lua`. No "second" claim about PerfSetup remains. |
| `CM-96` | `compat` row named two of four `GetItemInfo` sites | The row was narrowed on 2026-09-24: `GetItemInfo` is now `KCM.Compat.GetItemInfo` (`core/Compat.lua:93`). |
| `CM-79` / `CM-80` | The kit's prose gate skipped the stores whole, which hid two British spellings | The kit (revision 37) reads store-root files back through `SCAN_BACK` (`tests/_kit/test_prose.lua:171-175`). `analysed` and `neighbour` are gone from `docs/perf-analysis/README.md`, and `test_prose` passes. |
| `CM-81` | `synchronisation` could not be caught | `synchronis` is on the published list (`tests/_kit/prose_lists.lua:34`), and the word is gone from `docs/*.md`. |

---

## Checks run and found compliant (not deviations)

Each one has a command or citation in `03_EVIDENCE.md`.

- **Vendored payload**: both `diff -r` runs against `LibKa0s@v1.70.0` are empty, the folder is
  whole (15 majors), the TOC lists the aggregate XML once, and the provenance line is in `CLAUDE.md`
  only.
- **Disabled state**: one latch with two holds, and no second teardown. Every event, bus receiver,
  state driver and attribute driver comes down, and the `OnUpdate`s are cleared. No SavedVariables
  write reachable from a game event survives. The slash surface follows `slash-commands-§2`, and
  `diagnostics` is live. `tests/test_disabled.lua` asserts on the recording mock.
- **Launcher**: one object, the brand label, the descriptor rungs match `ADDONS.md`, the debug sinks
  are passed, and no reset reaches `minimap.hide`.
- **Diagnostics**: two forms, no alias, live while disabled, logging enabled by default.
- **Library debug lines**: all four descriptors pass `debug`, Launcher passes `debugAtEnable`, and
  the Options descriptor passes `addonName`.
- **Line endings**: the pin and body are canonical, and check (e) returns **0**.
- **Packaging**: checks (a), (b) and (c) are clean.
- **Lint**: 0/0 over 130 files, with correct scope.
- **Complexity**: sighted, wired at revision 37, 0 functions over CCN 15.
- **Over-cap census**: present, true, and gated.
- **Documentation tier model**: Tier 1 complete, every Tier 2 trigger measured, four tables, no
  orphan or dangling row, nothing retired.
- **Bus**: five messages, a strict catalog, PascalCase names, no call-site literal.
- **README**: bare badge, no logo, no inventory, no numbered list, `## Reporting a bug` in place.
- **Media**: the seam is fed `addonName`, the logo is canonical, and there is no private copy of the
  library's art. The Blizzard `ReadyCheck-*`/`FavoritesIcon` glyphs are on the options surface, which
  `library-stack-§8` places out of scope.
- **Issue store**: no `[status]` prefixes, and no unratified decline of a MUST or SHOULD.
