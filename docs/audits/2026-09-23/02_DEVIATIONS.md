# 02 — Deviations

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit:** 2026-09-23 · **Standard:**
**v2.64.0 (2026-09-23)** · **Commit:** `7adfea1`

IDs are **stable**. Every ID up to `CM-83` has been used in an earlier run. New IDs start at **CM-84**,
and retired IDs are never reused. `CM-75`, `CM-79`, `CM-80`, `CM-81` and `CM-83` carry forward from
`docs/audits/2026-09-08/` because the gaps they name still exist. `CM-77` and `CM-82` are closed (see
*Closed since 2026-09-08*).

**Grading is by impact, not rule strength** (`AUDIT.md` step 5). A doc-only or config-only failure is
**Low** even when the rule it fails is a MUST, and every entry still names that MUST. One exception
is stated where it applies: `CM-91` is graded **High** because `AUDIT.md`'s re-vendor check says so
explicitly (*"A tag vendored with no bundle naming it and no `## Documented deviations` row saying why
is a **High** finding"*). Step 5's impact table would put a missing record at Low. The two texts
disagree, and this run follows the check-specific one. The disagreement is reported upstream in
`04_TECHNICAL_DESIGN.md`.

## Tally

| | Count |
|---|---|
| **Headline (root deviations only)** | **16** |
| **Total including `derived from` dependents** | **18** |
| High | 1 root (1 with dependents) |
| Medium | 2 roots (2 with dependents) |
| Low | 11 roots (13 with dependents) |
| Info | 2 roots (2 with dependents) |
| **MUST failures — roots only** | **11** |
| **MUST failures — including dependents** | **13** |

**What the two numbers count.** The headline counts the 16 entries in *Root deviations*. The total
adds the two entries in *Derived dependents*: `CM-85` (from `CM-84`) and `CM-80` (from `CM-79`).

The MUST counts cover entries whose **Strength** column reads MUST or MUST NOT. The roots are
`CM-84`, `CM-86`, `CM-87`, `CM-88`, `CM-89`, `CM-90`, `CM-91`, `CM-93`, `CM-94`, `CM-79` and `CM-81`.
The dependents add `CM-85` and `CM-80`. Three roots are SHOULD failures (`CM-75`, `CM-83`, `CM-92`),
and the two Info rows carry no strength.

**Accepted and not counted.** Two register rows are recorded deviations, each citing its rule, Why
and Decided date: `localization-§4` (Decided 2026-08-05, evidence `CM-30`) and `compat` (Decided
2026-08-05, evidence `CM-63` / `CM-R-10`). They are excluded from every tally above.

**User reach.** Two code defects are reachable today, and both are **Medium**: a live registration
that survives the disabled state (`CM-84`), and a settings category a disabled addon can lose for a
whole session (`CM-86`). Nothing reaches a user's SavedVariables. The only High is the record-keeping
finding explained above.

---

## Root deviations

| ID | Section (`filename-§N`) | Grade | Strength | Deviation | Fix direction |
|----|-------------------------|-------|----------|-----------|---------------|
| **CM-91** | `audit-review-history` | **High** (the playbook grades this check High explicitly; the impact is record-keeping) | **MUST** | **27 of the 33 LibKa0s tags vendored since the re-vendor store's horizon (2026-08-25) have no `docs/revendor/` bundle and no `## Documented deviations` row.** Each tag is read from the payload with `AUDIT.md`'s command, off the `CLAUDE.md` provenance line at every commit that touched `libs/LibKa0s/`. On the recorded side, bare-dated bundles were read from their `01_DELTA.md` first line. The only bundle after v1.34.0 is `2026-09-23-v1.55.0`, whose delta is `v1.54.2 → v1.55.0`. The span v1.35.0 → v1.53.0 (18 tags), plus 9 earlier tags (v1.18.0–v1.29.0, excluding v1.25.0), went unrecorded. The command, both listings and the count are in `03_EVIDENCE.md`. | Write **one consolidated bundle** under `docs/revendor/` that names the span it covers, which `audit-review-history` says discharges a backlog (*"A consolidated bundle is a compliant answer to a backlog"*). Do not back-fill a folder per tag. |
| **CM-84** | `slash-commands-§7` (*What MUST stand down*: "Hooks and secure state drivers are stood down … `UnregisterAttributeDriver`") | **Medium** | **MUST** | **Each macro-bar slot's flyout keeps an attribute driver registered while the addon is disabled.** `modules/MacroBarFlyout.lua:289-290` calls `RegisterAttributeDriver(flyout, "kcmCombat", "[combat] 1; 0")` once per slot (up to 15, created from `modules/MacroBarButton.lua:463`). Nothing in the tree calls `UnregisterAttributeDriver`. The bar's disable path (`modules/MacroBar.lua:453-460`) unregisters the bar's visibility **state** driver and clears its `OnUpdate`, but it never reaches the flyouts. The client's secure state-driver manager keeps evaluating those conditions for an addon the player has switched off. That is dispatch the player asked to stop paying for, with nothing visible to show it. | Stand the drivers down on the same seam as the bar's: in `MB.Update`'s disable branch, which is already combat-deferred, call `UnregisterAttributeDriver(flyout, "kcmCombat")` for every flyout, and re-register on the enable path. Keep each flyout frame so a disable/enable cycle rebuilds nothing. Pin it in `tests/test_disabled.lua` (`CM-85`). |
| **CM-86** | `slash-commands-§7` (*What MUST survive*: "The settings-category registration and the panel body") | **Medium** | **MUST** | **A disabled addon that parks its settings registration in combat never replays it, so the panel and its Enable checkbox are gone for the session.** `settings/Panel.lua:1267-1269` parks the registration when `InCombatLockdown()` (the repo's own comment names the in-combat `/reload`). The replay lives only in `KCM:OnRegenEnabled` (`core/ConsumableMaster.lua:654-656`), which cannot reach it in either disabled state. If the latch went down in combat, the stood-down branch at `:631-634` flushes the bar, unregisters `PLAYER_REGEN_ENABLED` and **returns before the replay**. If the latch went down out of combat, `standDown` registers no `PLAYER_REGEN_ENABLED` at all (`core/LifecycleSetup.lua:98-100`). Either way, `/cm config`, the bare `/cm` and the launcher's right-click all fall through to *"settings panel unavailable on this client; use /cm help."* (`settings/OptionsShim.lua:233`), a message that misstates the cause, until the player types `/cm enable` and leaves combat once more. `tests/test_settingsui_optionsui.lua:769-799` tests the park and the replay only while the addon is enabled. | Make the replay setup rather than a feature. Run it before the stood-down early return, and keep the one sanctioned `PLAYER_REGEN_ENABLED` registration while `registerPending` is set, even when the stand-down finished out of combat. Extract the replay into a named helper rather than adding a branch, because `KCM:OnRegenEnabled` is already at CCN 15, the release gate's ceiling. Add a disabled-state case to the replay suite. |
| **CM-87** | `events-frames-taint-§1` (*An unknown event name raises*) | Low | **MUST** | **The addon's one event-registration block does not survive a bad name, and nothing records a rejected one.** `KCM:OnEnable` (`core/ConsumableMaster.lua:706-717`) makes nine bare `self:RegisterEvent(...)` calls, with no per-event `pcall` and no rejected-name list that `/cm debug` or the console can reach. All nine names are live on the current client, so this is latent. A patch that retires any one of them would, without an error, leave the addon deaf to every event registered after it, and `KCM:OnEnable` is also what `standUp` calls. | Register through one `pcall`ed helper that records rejected names (and SHOULD front-gate with `C_EventUtils.IsEventValid`). Surface the list in the `[Init]` debug content or a `/cm dump` target, and note the trade in `docs/midnight-quirks.md`. Fix upstream first if the collection wants a shared helper (see `04`). |
| **CM-88** | `options-ui-§2` ("a host **MUST NOT** wire its own panel-open beside it") | Low | **MUST NOT** | **The host hand-rolls the settings open, the category-ID capture and the tree-expand walk beside `LibKa0s-Options-1.0`'s.** `settings/OptionsShim.lua:207-236` (`O.Open`) calls `Settings.OpenToCategory(KCM._settingsCategoryID)`, and `:192-205` is a private copy of the `SetExpanded` walk. The ID is captured by the host's own `registerPanel` (`settings/Panel.lua:1286`). The library's `O.CreateOptionsPanel` / `O.OpenOptionsPanel` (`libs/LibKa0s/Options.lua:1351, 1411`) are never called (`settings/OptionsSetup.lua:287`: *"its own CreateOptionsPanel, which this addon never calls"*). This is not the page-jump carve-out, because the target is the main category rather than a subcategory. It works today: the gate is inside the open, and the wording is canonical. What it adds is a second place for the ID capture, the ordering constraint and the `pcall` to drift. The host copy is also the only one that parks registration in combat, which is why it cannot simply be deleted (`CM-86`). | **Upstream first.** Give `LibKa0s-Options-1.0` the combat parking the host has (refuse and park in `CreateOptionsPanel`, plus a replay seam), then adopt `CreateOptionsPanel` + `OpenOptionsPanel` and delete the host copy. If the owner declines, file a `## Documented deviations` row keyed `options-ui-§2`. |
| **CM-89** | `documentation-§1` (canonical section order; v2.42.0 removed `## What's new`) | Low | **MUST** | **`README.md:35` still carries `## What's new in 1.6.2`** between the description and `## Screenshots`. It is not one of the eleven canonical sections, and v2.42.0's changelog says *"Every addon is non-compliant until it deletes the section"*. Its single bullet repeats the top `## Version History` row (`README.md:137`) word for word. | Delete the section (a README-only edit), then run the de-AI pass `documentation-§1` requires on every README edit. |
| **CM-90** | `audit-review-history` (the register's second and third MUSTs), `documentation-§3` ("MUST NOT be a graveyard") | Low | **MUST** | **The `preview-mode` register row (`docs/ARCHITECTURE.md:416`, Decided 2026-08-05) is stale in both of the ways the register check tests.** (1) *Its cited rule has changed*: `preview-mode` became a test-mode MUST at v2.47.0, and at v2.49.0 it exempted an addon whose unlocked view already is its preview, naming *"Ka0s Consumable Master"*. Lock frame is now the compliant switch, so the rule the row defends against no longer requires what the row declines. (2) *Its own re-check trigger fired*: *"a preview / test verb being added to `/cm`"* happened at `87ed204` ("Add the macro bar's test mode: Master controls checkbox, /cm test") and was reversed at `9c45eff` ("Remove the Macro Bar's test mode: Lock frame is the switch (v2.49.0)"), with no change to the row. | Retire the row. v2.49.0's exception covers this addon, so the behavior is permitted outright, as the changelog says. Record the retirement in prose under the table, the same way the `toc-file-§5` retirement is recorded at `:418`. If the owner reads the exception's *"placeholder content"* as not matching a bar that draws live icons, re-decide the row against the current text with today's date instead. |
| **CM-93** | `architecture-§4` (declare every message name once; never type the literal at a call site) | Low | **MUST** | **A test-only bus literal is typed at two call sites**: `tests/test_harness.lua:73` `target:RegisterMessage("Ka0s_ConsumableMaster_HarnessPing", "OnHarnessPing")` and `:74` `KCM.bus:SendMessage("Ka0s_ConsumableMaster_HarnessPing", 5)`. The mandated grep includes `tests/`, and these are its only hits outside `core/Bus.lua`. The message is a mock-dispatch probe, not part of the addon's catalog, so no shipped code is affected. | Declare it once as a file-local constant at the top of the suite (`local PING = "Ka0s_ConsumableMaster_HarnessPing"`) and use the constant at both sites. Or probe with a name the rule does not bind (no `Ka0s_` prefix), since the case tests the mock's string-method dispatch and not the addon's namespace. |
| **CM-94** | `documentation-§5` ("**MUST** keep the doc set in sync with code") | Low | **MUST** | **Five load-order statements in the docs, and one in the TOC, have been wrong since `core\LifecycleSetup.lua` took the second line of `# Core`** (`ConsumableMaster.toc:75`). `docs/ARCHITECTURE.md:324` and `docs/module-map.md:598` list `# Core` as `Namespace → PerfSetup → …` with no LifecycleSetup, and `module-map.md:598` also omits `LauncherSetup`. `docs/module-map.md:642` says PerfSetup is *"Loaded **second** in `# Core`, immediately after `core/Namespace.lua`"*, which contradicts its own row at `:620`. `docs/performance.md:46` says PerfSetup *"sits second"*, and so does the TOC comment at `ConsumableMaster.toc:77` (*"It sits here, second"*). In addition, `docs/ARCHITECTURE.md:418` cites `ConsumableMaster.toc:51-57` and `:77-79` for the ordering comments; those lines now hold the LibKa0s library comment and the PerfSetup comment. | Fix the six statements. Say "after `core/LifecycleSetup.lua`" rather than restating an ordinal, and cite the TOC comments by what they annotate rather than by line. `wow-addon:sync-docs` is the command for this. |
| **CM-79** | `localization-§5` (a gate MUST skip only the four named exclusions; frozen **bundles**, not whole stores) | Low | **MUST** | **The prose gate is blind to three authored, rewritten documents.** Since the 2026-09-22 sweep this repo wires the **kit's** gate (`tests/run.lua:507`) and deleted its own. The kit's `SKIPPED_DIRS` (`tests/_kit/test_prose.lua:209-213`) excludes `docs/automated-tests/` and `docs/perf-analysis/` **whole**, even though `docs/automated-tests/README.md`, `RESULTS.md` and `docs/perf-analysis/README.md` are authored or regenerated in place and are not frozen bundles. The defect is the same one filed on 2026-09-08. It now lives in vendored code the repo MUST NOT patch (library-stack-§5), so the fix is upstream. The gate passes today over two real hits (`CM-80`). | **Upstream (LibKa0s testkit):** replace the two whole-directory skips with dated-bundle skips (`docs/automated-tests/<stamp>/`, `docs/perf-analysis/<stamp>/`) and re-vendor. Expect `CM-80` to turn red and fix it in the same change. |
| **CM-81** | `localization-§5` | Low | **MUST** | **`synchronisation` in authored prose, at `docs/settings-panel.md:80`** (*"… is a synchronisation problem the design would have invented"*). `synchronis` is not on the published `BRITISH` list, so no gate can catch it, and the section forbids a private addition. The finding was open on 2026-09-08 and is unchanged. | **Upstream first:** add `synchronis` to `localization-§5`'s `BRITISH` list in `WowAddonStandards`. It passes the admissibility test, since no US word contains it. Let the kit take it on its next sync, then fix the word here. |
| **CM-92** | `documentation-§3` (*`ARCHITECTURE.md` is a hub*: "The whole file **SHOULD** stay under roughly 400 lines") | Low | SHOULD | **`docs/ARCHITECTURE.md` is 504 lines.** The mandated sections do spill, but two long blocks are history rather than index: `## Documented deviations` runs `:404-504` (101 lines), of which `:455-504` is peel narrative (*What the peel did*, the Panel/Category peel paragraphs), and the `### LibKa0s adoption` table (`:267-316`) is a per-major reference. | Move the peel narrative to `module-map.md` or the relevant issues, keeping only the census and its one required sentence. Consider moving the adoption table to `module-map.md` and leaving a summary plus one link. |
| **CM-75** | `documentation-§6` | Low | SHOULD | **46 bare `§N` citations in 22 files** (up from 24 in 12 on 2026-09-08). Most continue a full `filename-§N` in the same clause (`options-ui-§8, §18`; `debug-logging-§5/§8`). Some rely on the file's subject rather than an adjacent anchor (`settings/General.lua:346, 377`; `tests/test_settingsui_optionsui.lua:5, 71, 721, 723`; `settings/Slash.lua:85`). A range check over all **672** `filename-§N` citations finds **0** out of range and **0** malformed, and there are **0** retired dotted forms, so none of the MUST half is present. Reported as one rolled-up finding with its command in `03_EVIDENCE.md`. | Expand each continuation to its full `filename-§N`. `docs/smoke-tests.md`'s own numbering and `modules/Selector.lua:5`'s `TECHNICAL_DESIGN §4` are out of scope. |
| **CM-83** | `toc-file-§5` | Low | SHOULD | **Conventional groups in the TOC are unmarked.** The load-bearing MUST holds (every load-bearing line names what resolves), but `# Locales` (`ConsumableMaster.toc:57-58`), `# Modules` (`:166-176`) and the four page files in `# Settings` (`:202-205`) carry no *conventional* note. The finding was open on 2026-09-08 and is unchanged. It is one SHOULD row for the file, never one per line. | Add one comment per group, for example above `# Modules`: *"Conventional — every module reaches the seams through closures at call time, except modules\MacroBar.lua, whose NS.Perf upvalue is pinned by core\PerfSetup.lua above."* |
| **CM-95** | `automated-tests-§4`, anti-pattern #51 | Info | — | **`docs/automated-tests/RESULTS.md` is 33 commits behind `HEAD`** (newest bundle `20260916-184427` at `da0b0f8`). Its band table still shows the pre-peel `settings/Category.lua` 1400 and `settings/Panel.lua` 1488 (now 1141 and 1312). Its generated narrative (`:117`) names `tests/test_layout_cap.lua`, which has been deleted in favor of the kit's. The checkpoint is **release, not commit**, no release has been cut since 1.6.2, and nothing is hand-edited, so this is a fact about the record rather than a finding against the addon. | Nothing now. The next release run regenerates the record. That run should keep `KCM:OnRegenEnabled` at or under CCN 15; it sits at exactly 15 today. |
| **CM-96** | `audit-review-history` (register rows are read and their contents checked) | Info | — | **The `compat` register row names two of the four direct `GetItemInfo` call sites.** The row (`docs/ARCHITECTURE.md:415`) cites `core/TooltipCache.lua:459` and `modules/Ranker.lua:88`. `modules/KCMItemRow.lua:96` (`_G.GetItemInfo(itemID)`) and `:139` (`local _, link = _G.GetItemInfo(itemID)`) make the same kind of call and are not named. The row's reasoning (a live retail API that needs async fields) covers them just as well. | Add the two sites to the row's *What differs* cell the next time the register is edited. No re-decision is owed. |

---

## Derived dependents (excluded from the headline tally)

| ID | Derived from | Section | Grade | Strength | Observation |
|----|--------------|---------|-------|----------|-------------|
| **CM-85** | `derived from CM-84` | `slash-commands-§7` (*The conformance test*), `testing-§12` | Low | **MUST** | **`tests/test_disabled.lua` passes over the `CM-84` survivor.** Step 4 (`:209-224`) checks the bar's `OnUpdate` and `mock.stateDrivers[bar].visibility` (`:222-223`) and never reads `mock.attributeDrivers`, even though the repo's own mock records them (`tests/wow_mock.lua:823-830`). It stays dependent because it is fixed in the same change as its root, is not user-reachable, and is not graded above it. |
| **CM-80** | `derived from CM-79` | `localization-§5`, anti-pattern #46 | Low | **MUST** | **Two British spellings in `docs/perf-analysis/README.md`**: `:25` *"a run **analysed** a week later"* and `:26` *"against its **neighbours**"*. Both `analys` and `neighbour` are on the published list, and the gate passes only because of `CM-79`'s exclusion. The finding was open on 2026-09-08 and is unchanged. |

---

## Closed since 2026-09-08

| Prior ID | Was | Verified closed by |
|---|---|---|
| `CM-77` | Two run bundles without `ANALYSIS.md`, and the gap never noted | `docs/automated-tests/20260908-181304/ANALYSIS.md:89-94`, *"The `ANALYSIS.md` gap, noted once"*, names both bundles and declines to back-fill, which is exactly the forward note `automated-tests-§5` asks for. |
| `CM-82` | The hub's over-cap census disagreed with its own command | The census at `docs/ARCHITECTURE.md:420-481` now reads *"No authored file in this repository is over the cap"*, and its band list (`:476-481`) matches today's `wc -l` line for line. The kit's `test_layout_cap` passes on five cases. |
| `CM-79` | *Changed shape, not closed.* | The repo's own `tests/test_prose.lua` was deleted and the kit's gate is wired instead (`tests/run.lua:507`). The same over-wide exclusion now sits in the kit (see `CM-79` above). |

---

## Checks run and found compliant (not deviations)

Each has a command or citation in `03_EVIDENCE.md`.

- **Vendored payload.** Both `diff -r` runs against `LibKa0s@v1.55.0` (the tag in `CLAUDE.md:61`) are
  empty. The folder is whole, with 21 files and 15 majors. The TOC lists the aggregate XML once. The
  provenance line is in `CLAUDE.md` only. The badge is bare. There is no logo in the README and no
  library inventory.
- **The disabled state, apart from `CM-84` and `CM-86`.** There is one latch with two holds on
  `LibKa0s-Lifecycle-1.0` and no second teardown. All nine events and all seven bus registrations
  come down. The bar is hidden at the source, its `OnUpdate` is cleared and its state driver is
  unregistered. I found no SavedVariables write from a game event while disabled. The slash surface
  follows `slash-commands-§2` (every reserved verb and the bare `/cm` answer, and eight feature verbs
  refuse on one line). The launcher refuses left-click without writing anything, and right-click
  still opens the panel. `tests/test_disabled.lua` exists, is listed and passes, and it asserts on
  the recording registry.
- **Line endings.** The pin is correct, the body is canonical with no tail, check (e) returns **0**,
  and the kit's gate passes.
- **Packaging.** Checks (a), (b) and (c) are all clean.
- **Lint scope.** Only `tests/_kit/` is excluded under `tests/`. The harness globals sit in
  `files["tests/"]` and there is no blanket `ignore`. The result is 0/0 over 116 files.
- **The documentation tier model.** Tier 1 is complete. Every Tier 2 trigger was measured against the
  code (21 verbs, 5 messages, 2 Compat shims) and each is answered. The map has four tables with no
  orphan or dangling row. No retired or non-canonical doc remains.
- **`options-ui` (a)–(i).** All pass. Nothing closes the settings window in combat.
- **Launcher.** It is one object. The rung matches `ADDONS.md`, the label is the brand name, no reset
  reaches `minimap.hide`, and there is no broker toggle.
- **Bus names.** All five are declared once in a strict `Catalog` and all use a PascalCase tail
  (the only exception is the test literal, `CM-93`).
- **Write paths (`architecture-§5`).** Every write outside the helper falls into class (b), (c) or (e)
  and is named in the hub.
- **Complexity.** 0 functions are above CCN 15. The watch list holds no entry that has read *Accepted*
  across three or more release runs: the two that reached three were peeled.
- **Register rows.** Two were accepted, as recorded above. The third is `CM-90`. No
  `state:will-not-do` issue declines a standard rule without a row.
