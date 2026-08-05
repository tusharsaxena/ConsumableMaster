# 05 — Execution Plan

Ordered, checkable remediation steps for the deviations in `02_DEVIATIONS.md`, designed in
`04_TECHNICAL_DESIGN.md`. This is the hand-off to a **separate** remediation engagement — the audit
itself changed no addon file.

**Standard:** v2.21.0 (2026-08-04). **Starting HEAD:** `6b7d3d0`.

**Standing rules for every step below**

- Green gate before every commit: `lua5.1 tests/run.lua` (656/656 or better) **and** `luacheck .`
  (0/0). `testing-§4`.
- Test-first. A behavior change lands with the failing case that pins it (`testing-§4`); a
  behavior-*preserving* refactor lands **after** a characterization test that pins the prior
  behavior (`testing-§13`).
- Trunk-based unless the user asks otherwise (`versioning-git`). Sprint 3 is the one that plausibly
  warrants isolation — ask.
- Never edit `libs/LibKa0s/` or `tests/_kit/`. A gap there is a finding to fix upstream and
  re-vendor (`library-stack-§5`, `testing-§1`).
- Do not bump the version except in Sprint 7.

---

## Sprint 1 — Stop the degraded install from breaking (CM-58, CM-65)

Highest value per line in the whole plan, and the only findings a user can hit. Independent of every
other sprint; ship it first and alone.

| # | Step | IDs | Done when |
|---|---|---|---|
| 1.1 | Write the **degraded-load scenario** in `tests/test_settingsui.lua` (or a new `tests/test_degraded.lua`): feed the loader the addon's file list with `libs/LibKa0s/*` omitted so every major is genuinely absent. Assert it currently **fails** on `KCM.Schema:Set(...)` with `attempt to call field 'RefreshScalars'`. | CM-58 | The new case is **red**, reproducing review F-002 |
| 1.2 | Extend the scenario: a `KCM.Pipeline.Recompute("test")` through the PANEL_REFRESH receiver. Assert it currently fails on `RefreshAllPanels`. | CM-58 | Red, reproducing F-001 |
| 1.3 | Extend again: `KCM:OnSlashCommand("version")`, `("bar")`, `("dump")` each reach their host verb. Assert they currently do not. | CM-65 | Red |
| 1.4 | `settings/Panel.lua:571-572` — bind both members through `or noop`. **Do not** sweep the other eight copy-across members; they are panel-build-only and already gated by `libAbsent`. | CM-58 | 1.1 and 1.2 green |
| 1.5 | `settings/Slash.lua` — add the host-side `hostDispatch` verb matcher and route `KCM:OnSlashCommand` through it when `Sl` is nil. **No** copied row formatter, parser or `key = value` shape (`slash-commands-§1`). | CM-65 | 1.3 green |
| 1.6 | Reconcile the two degraded messages: `settings/Panel.lua:265-269` stops promising the schema CLI works; `settings/Slash.lua:301-302` names the schema CLI instead of all of `/cm`. One absence, said the same way, each seam appending only what it loses. | CM-65 | Both strings assert in the scenario; no test asserts the old wording |
| 1.7 | Regenerate `docs/test-cases.md` and update the README `[tests]` badge in the **same** commit (`testing-§5`). | — | Badge X/Y == `--list` count == run count |

**Exit:** `luacheck .` 0/0 · full suite green · the degraded scenario covers both crashes and the
verb blackout · `docs/test-cases.md` and `README.md:7` in lockstep.

---

## Sprint 2 — Free wins that unblock nothing and are blocked by nothing

Batch these; every one is a single file and none touches code paths under active change.

| # | Step | IDs | Done when |
|---|---|---|---|
| 2.1 | `CLAUDE.md:1` → `# CLAUDE.md — Ka0s Consumable Master`. | CM-50 | Matches `documentation-§2` item 1 |
| 2.2 | `.luacheckrc` `globals` += `"ConsumableMasterPerfDB",  -- the perf capture ring (savedvariables-§4, performance-§5)`. | CM-41 | `luacheck .` still 0/0 |
| 2.3 | `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`; add the `chmod +x` step to `docs/testing.md`'s re-vendor procedure. | CM-62 | `git ls-files -s` reports `100755` |
| 2.4 | Move root `CHANGELOG.md` → `docs/CHANGELOG.md` (or fold into `README.md` `## Version History` and delete). Add `.claude/`, `.superpowers/` and the changelog path to `.pkgmeta` ignore. | CM-59, CM-56 | `ls *.md` is exactly `README.md CLAUDE.md DEPENDENCIES.md` |
| 2.5 | State the **release gate** beside the commit gate in `docs/testing.md:141-157`, `docs/automated-tests/README.md:19-33` and `CLAUDE.md:72-76`. Keep every existing commit-gate sentence verbatim; add the tag gate (all four at `pass` + `warnings == 0`, evaluated by the release command from `manifest.json`, runner exit code unchanged, a `skip` blocks as NOT EVALUATED), and record that the **no-`tests/perf.lua` exception applies to this addon today**. Reword `CLAUDE.md`'s "report, not a gate" → "not a **commit** gate". **Do not touch the generated `RESULTS.md`.** | CM-61 | All three files describe both checkpoints and neither contradicts `automated-tests-§3` |
| 2.6 | Add the five missing `docs/ARCHITECTURE.md` sections: Settings Schema (table from `KCM.Settings.Schema`), Slash Commands (table from `KCM.COMMANDS`), Event Subscriptions (from `KCM:OnEnable`), Taint Notes (absorbing the `:87` invariant + `docs/midnight-quirks.md`), Known Limitations (naming CM-30). | CM-60 | All eight `documentation-§3` sections present |
| 2.7 | `core/Compat.lua` += `Compat.GetItemInfo` / `Compat.GetItemCount` preferring `C_Item.*`; route `core/TooltipCache.lua:459`, `modules/Ranker.lua:88`, `core/Classifier.lua:169`, `core/WeaponSlots.lua:36`, `modules/KCMItemRow.lua:88-89,131-132,216` through them. Add covering cases for both new wrappers. | CM-63 | No bare `GetItemInfo`/`GetItemCount` outside `core/Compat.lua`; review F-010 closed as a side effect |
| 2.8 | Fold in the comment fixes: `modules/DebugLog.lua:97-99` `.AddLine` → `.instance` (CM-66), and sweep retired `§N.M` refs to `filename-§N` **only in the files steps 2.1–2.7 already touch** (CM-53, partial). | CM-66, CM-53 | Touched files carry no `standard §N.M` |

**Exit:** green gate · root doc set is exactly three + LICENSE · the two gates are documented
correctly · `Compat` owns every legacy item call.

---

## Sprint 3 — The test harness (CM-34, CM-35, CM-64)

The riskiest sprint. Do it **before** the file moves in Sprint 4, because after CM-35 those moves
cost nothing. Consider asking the user for a branch.

| # | Step | IDs | Done when |
|---|---|---|---|
| 3.1 | Read `tests/_kit/README.md` end to end. Inventory the assertion names the kit publishes vs the local `t.eq`/`t.truthy` shape, and the mock behaviors `mock_base.lua` already models (AceDB in-place `copyDefaults`, AceConsole `Embed` clobber, `RegisterUnitEvent` recording). | CM-34 | A written delta list; **no** edit to `tests/_kit/` |
| 3.2 | Rewrite `tests/run.lua` to `dofile` the kit's `framework.lua` + `loader.lua`, publish through `Kit.expose(_G.KCM_TEST)` (aliasing assertion names from `run.lua` if 3.1 found a mismatch), and hand the suite list to `Kit.run{ dir = "tests/", suites = {…} }`. | CM-34 | `lua5.1 tests/run.lua` green at **≥656**; `--list` still renders `docs/test-cases.md` |
| 3.3 | Rewrite `tests/wow_mock.lua` as `local base = dofile("tests/_kit/mock_base.lua")` plus per-key overwrites (the item/bag/spell/spec store, `setEquipped`, `setPlayerLevel`/`setPlayerClass`, the `pending=true` tooltip shape). Use `M.__stubFrame()` and `M.__libs` rather than reaching through LibStub's closure. | CM-34 | Suite green; the file is a fraction of its 623 lines |
| 3.4 | Delete `tests/harness.lua` and `tests/loader.lua`. | CM-34 | Neither file exists; nothing `require`s `"harness"` or `"loader"` |
| 3.5 | Replace `L.PURE_LAYER` with a **filter over** `Loader.tocFiles("ConsumableMaster.toc")`; keep the vendored `LibKa0s` file list **explicit** in `LibKa0s.xml` order (`testing-§9`). | CM-35 | The list is derived, not transcribed |
| 3.6 | Pin the derivation with three cases: exactly the TOC's files in TOC order; every derived path exists on disk; no `libs/` path leaked in. | CM-35 | Three new cases, each demonstrably red under a mutation |
| 3.7 | `tests/test_vendor_sync.lua` — make the absent-sibling path **fail** with the path it looked for (or, if a green suite without the sibling is wanted, put "skipped: no sibling checkout" in the case **names**). Drop the `:gsub("\r\n","\n")` at `:135` and compare raw bytes. Fix the header claim at `:108-110`. | CM-64 | Running with no `../LibKa0s` no longer prints two silent PASSes |
| 3.8 | Regenerate `docs/test-cases.md`; update the README badge. | — | In lockstep |

**Exit:** `tests/_kit/` is the only harness · no hand-maintained load list · the vendor gate is loud ·
suite green at ≥656 · badge and inventory in lockstep.

**Rollback:** the whole sprint is one logical change. If 3.3 cannot be made green in a session,
revert to the pre-sprint commit rather than shipping a half-migrated `tests/`.

---

## Sprint 4 — File moves (CM-44, CM-45, CM-48) and the perf stub

Cheap now that Sprint 3 derives the load list. Each step is `git mv` + one TOC edit + doc ripples.

| # | Step | IDs | Done when |
|---|---|---|---|
| 4.1 | `git mv modules/DebugLog.lua core/DebugLogSetup.lua`; TOC line into `# Core` after `Constants` / `CoreSetup` / `State`, before every sink caller. Update `docs/file-index.md`, `docs/scope.md`, `docs/ARCHITECTURE.md:20`, and the three comments that name the old path (`settings/Slash.lua:252`, `settings/Panel.lua:207`, `modules/PerfSetup.lua:91`-area). | CM-44 | Suite green; no reference to `modules/DebugLog.lua` survives |
| 4.2 | `git mv modules/PerfSetup.lua core/PerfSetup.lua`; TOC line into `# Core` after the DebugLog setup and **before** `core/ConsumableMaster.lua`. Verify the `log`/`print`/`showLog` thunks and `suspend`/`resume` still resolve (they are call-time closures). | CM-45 | Suite green; `core/PerfSetup.lua` precedes both bracket sites in the TOC |
| 4.3 | **Prerequisite for 4.4** — replace `modules/PerfSetup.lua:36`'s bare `return` with a two-member stub: `KCM.Perf = { on = false, Note = function() end }`. Add a case asserting the addon loads and both brackets run with `LibKa0s-Perf-1.0` absent. | CM-45, `performance-§1` | The degraded scenario from Sprint 1 extends to cover it |
| 4.4 | Hoist both brackets to a file-scope `local Perf = KCM.Perf` and the mandated `local t0 = Perf.on and debugprofilestop()` / `if t0 then Perf.Note(key, …) end` shape — `core/ConsumableMaster.lua:332-349`, `modules/MacroBar.lua:322-330`. | CM-39 | No `KCM.Perf` lookup inside a timed function |
| 4.5 | Add one case **per declared bucket**, iterating `PerfSetup`'s bucket list rather than naming them inline: flip `Perf.on`, drive the genuine entry point (recompute pipeline; cooldown repaint), assert the bucket accrued. | CM-40 | A bucket added later fails until something drives it |
| 4.6 | `git mv` the `KCM.dbDefaults` table from `core/ConsumableMaster.lua:25` to `defaults/Profile.lua`, TOC-listed first in `# Defaults`. **Grep first** for any load-time read inside `core/`. | CM-48 | Suite green; `defaults/Profile.lua` is the only place a profile default is hardcoded |
| 4.7 | Regenerate `docs/test-cases.md`; update the badge. Sweep retired `§N.M` refs in the files touched. | CM-53 | In lockstep |

**Exit:** `core/DebugLogSetup.lua` and `core/PerfSetup.lua` exist and load in the right slots ·
`defaults/Profile.lua` owns the defaults · the brackets are upvalue-gated · every declared bucket is
pinned.

---

## Sprint 5 — The Options peel (CM-46, CM-36, CM-37, CM-51)

One logical change in four sub-steps. Run the full suite **between each**, not at the end —
`settings/Panel.lua` backs 100+ cases.

| # | Step | IDs | Done when |
|---|---|---|---|
| 5.1 | Characterization pass first (`testing-§13`): pin the current behavior of the ten copy-across members and the two host constants before moving them. | CM-36, CM-37 | Cases exist and pass against the pre-change code |
| 5.2 | Create `settings/OptionsSetup.lua` — the `LibStub` lookup, the descriptor, `:New`, the lib-absent branch (load-completing shape **verbatim**, plus Sprint 1's two no-ops), and `KCM.AceGUI = LibStub("AceGUI-3.0", true)`. TOC-listed immediately before `settings/Panel.lua`. | CM-46, CM-51 | Suite green |
| 5.3 | `KCM.Settings.Helpers = optionsLib:New(descriptor)` — the instance **is** the member. Delete the ten copy-across lines from `settings/Panel.lua` and decorate the instance in place with the host-only pieces. | CM-36 | `settings/Panel.lua:41-42`'s fresh table is gone; the identity assertions in `tests/test_schema.lua`/`test_settingsui.lua` still hold |
| 5.4 | Delete `SECTION_HEADING_H` / `BUTTON_PAIR_REL` (`settings/Panel.lua:74-75`); read `Helpers.SECTION_HEADING_H` at `:711` and `Helpers.BUTTON_PAIR_REL` at `:507`. If the library exposes neither, add them **upstream** in LibKa0s as additive fields and re-vendor whole-folder — never keep the host copy. | CM-37 | No host copy of a library constant remains |
| 5.5 | Point `settings/Panel.lua:19`, `settings/StatPriority.lua:23`, `settings/Category.lua:29` at `KCM.AceGUI` and guard their render paths, matching `modules/KCMIconButton.lua:11`'s shape. | CM-51 | No unguarded `LibStub("AceGUI-3.0")` in the repo |
| 5.6 | Regenerate `docs/test-cases.md`; update the badge; sweep `§N.M` in the touched files. | CM-53 | In lockstep |

**Exit:** the Options seam has its own file · the host member is the instance · no duplicated layout
constants · AceGUI resolved once, silently.

**Note:** if this sprint changes the shape of the degraded Options branch at all, re-run Sprint 1's
degraded scenario before committing — the two no-ops from 1.4 must survive the peel.

---

## Sprint 6 — Performance evidence (CM-38, CM-42, CM-43)

Depends on Sprint 4 (the upvalue hoist is what the zero-overhead scenario measures).

| # | Step | IDs | Done when |
|---|---|---|---|
| 6.1 | Write `tests/perf.lua` — separate entry point, **not** loaded by `tests/run.lua` (`testing-§7`), load list derived from the TOC and pinned by reading its source (`testing-§9`). | CM-38 | `lua tests/perf.lua` runs; `lua tests/run.lua` does not run it |
| 6.2 | Ship the **zero-overhead scenario**: with `Perf.on == false`, N iterations of `Pipeline.Recompute` and `MB.RefreshCooldowns` call a swapped-in `debugprofilestop` **zero** times and allocate zero attributable bytes (full `collectgarbage("collect")` either side). Deterministic quantities only — **never** wall-clock (`performance-§9`). | CM-38 | The required evidence for `performance-§2` exists as a committed number |
| 6.3 | Write `docs/performance.md` — bracketed paths and why, how to run `/cm perf`, how to read the report, what the harness cannot resolve. Lift `core/PerfSetup.lua:8-15`'s explanation of the deliberately-out-of-combat expensive paths. Point at the library for the shared protocol. | CM-42 | One of the five required topic-detail docs exists |
| 6.4 | Create `docs/perf-runs/README.md` — naming convention, schema summary, library pointer, and the explicit in-game/offline split (`performance-§8`, `automated-tests-§7`). Commit the first real in-game capture beside it. | CM-43 | The directory exists **and is not empty** |
| 6.5 | Update `docs/automated-tests/README.md:42-45`, which currently says `docs/perf-runs/` does not exist. | CM-43 | No doc claims a directory that now exists is missing |

**Exit:** all five required topic-detail docs present · `perf` stops being a permanent `skip` ·
CM-61's "no-`tests/perf.lua` exception applies here" caveat can be **removed** from the release-gate
wording.

---

## Sprint 7 — Verify, record, and release

| # | Step | IDs | Done when |
|---|---|---|---|
| 7.1 | Run the two vendor-drift diffs on a machine that has the sibling checkout: `diff -r ../LibKa0s/LibKa0s ./libs/LibKa0s` and `diff -r ../LibKa0s/testkit ./tests/_kit`. **Both MUST be empty.** This audit could not run them (single-repo constraint) and they remain the one unverified compliance claim. | — | Both empty, or a re-vendor commit lands |
| 7.2 | Resolve **CM-49**: either reorder `core/` to `Compat → Constants → Namespace → …` (verifying `Compat.lua` and `Constants.lua` tolerate preceding the `NS` bootstrap — today they do not), or raise it upstream as a standard correction and record it here as an accepted deviation with the TOC's existing comments as rationale. | CM-49 | A decision exists, in writing, either way |
| 7.3 | Re-affirm or schedule **CM-30** (enUS tooltip parsing). No code change expected; the audit is expected to surface it. | CM-30 | Recorded |
| 7.4 | Full four-suite bundle: `tests/_kit/run-automated-tests.sh` with an `ANALYSIS.md`. Check `RESULTS.md`'s watch list — `tests/test_macrobar.lua` will be at or near its **third** consecutive "Accepted" (anti-pattern #53), at which point it is owed a fix or a tracked deviation ID, not another renewal. | CM-54 | Bundle written; watch-list dispositions are decisions, not renewals |
| 7.5 | **Evaluate the release gate** (`automated-tests-§3`): the run's `manifest.json` must show all four suites at `pass` **and** `suites.complexity.warnings == 0`. After Sprint 6, `perf` is a real `pass` rather than the narrow no-scenarios skip — if Sprint 6 slipped, the skip **blocks** and must be stated in the release notes rather than read as clean. | — | Gate evaluated, every failure reported (not just the first), nothing bumped or tagged if it fails |
| 7.6 | Bump the version, roll `## What's new` and `## Version History` together, then tag (`versioning-git`, `documentation-§1`). | — | Bundle, docs and tag move in one change |

---

## Dependency graph

```
Sprint 1 (degraded install)  ──────────────────────────────► independent, ship first
Sprint 2 (doc/metadata wins) ──────────────────────────────► independent
Sprint 3 (harness: CM-34 → CM-35 → CM-64)
        └─► Sprint 4 (moves: 4.1, 4.2 → 4.3 → 4.4 → 4.5; 4.6)
                    └─► Sprint 6 (6.1 → 6.2 needs 4.4's upvalue)
        └─► Sprint 5 (Options peel; re-run Sprint 1's scenario at the end)
Sprints 4,5,6 ─────────────────────────────────────────────► Sprint 7
```

Hard ordering constraints, restated:

1. **CM-45 before CM-39.** The upvalue is only sound once `PerfSetup` loads before its bracket sites,
   **and** once the lib-absent branch publishes a `KCM.Perf` stub (4.3).
2. **CM-34/CM-35 before the Sprint 4 moves**, or every move pays an extra edit in a hand-written list.
3. **CM-36 with CM-46**, and **CM-37 after CM-36** — they touch the same lines, and CM-37's constants
   only become reachable once the host member is the instance.
4. **CM-39 before CM-38's zero-overhead scenario** — the scenario measures exactly the thing CM-39
   fixes; running it first just records the defect.
5. **Sprint 1's no-ops must survive Sprint 5's peel.** Re-run the degraded scenario at 5.6.

## Deviation → sprint index

| ID | Sprint | ID | Sprint |
|---|---|---|---|
| CM-30 | 7.3 | CM-50 | 2.1 |
| CM-34 | 3.2–3.4 | CM-51 | 5.2, 5.5 |
| CM-35 | 3.5–3.6 | CM-52 | advisory (2.x, opportunistic) |
| CM-36 | 5.3 | CM-53 | 2.8, 4.7, 5.6 |
| CM-37 | 5.4 | CM-54 | 7.4 |
| CM-38 | 6.1–6.2 | CM-55 | keep (no action) |
| CM-39 | 4.4 | CM-56 | 2.4 |
| CM-40 | 4.5 | CM-57 | advisory |
| CM-41 | 2.2 | CM-58 | 1.1–1.2, 1.4 |
| CM-42 | 6.3 | CM-59 | 2.4 |
| CM-43 | 6.4–6.5 | CM-60 | 2.6 |
| CM-44 | 4.1 | CM-61 | 2.5 |
| CM-45 | 4.2–4.3 | CM-62 | 2.3 |
| CM-46 | 5.2 | CM-63 | 2.7 |
| CM-48 | 4.6 | CM-64 | 3.7 |
| CM-49 | 7.2 | CM-65 | 1.3, 1.5–1.6 |
| | | CM-66 | 2.8 / 4.1 |
| | | CM-67 | advisory |
