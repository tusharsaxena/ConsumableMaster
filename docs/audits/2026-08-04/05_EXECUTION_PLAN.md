# 05 — Execution Plan

**Audit:** 2026-08-04 · **Standard:** v2.17.1 · Hand-off to the separate remediation engagement.

Every step is checkable and tied to its deviation ID. **Gate on every commit:** `lua tests/run.lua`
green **and** `luacheck .` clean (`testing-§4`, `versioning-git`). Trunk-based on `master`; no
branch unless the user asks. No version bump unless the user asks (`CLAUDE.md` hard rule).

**Ordering constraints that are not negotiable:**

- **S2 before S4.3** — the perf bracket cannot take a load-time upvalue until `PerfSetup` loads first.
- **S1.1 before S2** — the load-list pinning is what catches a mis-ordered move; it is cheap and
  independent of the mock swap, so it goes first even though the rest of S1 is the biggest job.
- **S3.1 and S3.2 are one commit** — both rewrite the same 150 lines of `settings/Panel.lua`.

---

## Sprint 0 — Decisions (no code)

| # | Step | IDs | Done when |
|---|------|-----|-----------|
| 0.1 | Re-affirm CM-30 as an accepted, documented deviation, or schedule tooltip-text localization. | CM-30 | User's answer recorded; `docs/scope.md:20` updated if the decision changed. |
| 0.2 | Raise the `layout-§1` conflict upstream: (a) `Compat → Constants → Namespace` may be unsatisfiable for any addon whose `Namespace.lua` bootstraps `NS`; (b) `layout-§1`'s `settings/* → modules/*` contradicts `toc-file-§5`'s `Modules → Settings`. | CM-49 | Issue/PR filed against `WowAddonStandards`, or a decision to reorder `core/` recorded here. |
| 0.3 | Decide the advisories: keep or fold `## Credits and bundled libraries`; extend `.pkgmeta` ignores; migrate `docs/pending/LEDGER.md` items to issues. | CM-55, CM-56, CM-57 | Three yes/no answers. |

---

## Sprint 1 — Adopt the vendored test kit

The largest and riskiest sprint. Do it first: every later sprint's safety net is the suite, and the
suite is what this sprint rebuilds.

| # | Step | IDs | Done when |
|---|------|-----|-----------|
| 1.1 | **Pin the load-list derivation, before changing anything.** Add cases: the runner fed the loader exactly the TOC's files in TOC order; every derived path exists on disk; no `libs/` path leaked in. These pass against the *current* hand-rolled loader too. | CM-35 | Three new cases green; count moves 600 → 603. |
| 1.2 | Rewrite `tests/wow_mock.lua` as a thin extender: `local base = dofile("tests/_kit/mock_base.lua")`, then per-key overwrites for the genuinely addon-specific surface (macro APIs, container/bag, tooltip data, spec APIs). Delete every key `mock_base` already provides. Review each surviving overwrite against `tests/_kit/README.md`'s five fidelity rules. | CM-34 | 600 cases still green; `tests/wow_mock.lua` no longer defines a base mock. |
| 1.3 | Rewrite `tests/run.lua` onto the kit: `dofile` `tests/_kit/framework.lua` + `tests/_kit/loader.lua`, publish via `Kit.expose`, hand the ordered suite list to `Kit.run{ dir = "tests/", suites = { … } }`. Keep a two-line `require("harness")` shim mapping the repo's assertion names so no suite file changes. | CM-34 | `lua tests/run.lua` green via the kit; `lua tests/run.lua --list` still renders the inventory. |
| 1.4 | Convert `PURE_LAYER` to a **filter over `Loader.tocFiles("ConsumableMaster.toc")`**. Keep the explicit eight-entry `LibKa0s` file list in XML order — that is required, not a shortcut. | CM-35 | 1.1's three cases still green against the derived list. |
| 1.5 | `git rm tests/harness.lua tests/loader.lua`. | CM-34 | Files gone; suite green; `grep -rn "require(\"harness\")"` resolves only through the shim (or nothing, if 1.3 chose the full sweep). |
| 1.6 | Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and update the README `[tests]` badge **in the same change**. | `testing-§5` | Badge X/Y matches the run and the inventory. |

**Commit shape:** 1.1 alone; 1.2 alone; 1.3+1.4+1.5 together (they are one migration); 1.6 folded
into whichever commit last moved the count.

---

## Sprint 2 — Relocate the LibKa0s setup files

| # | Step | IDs | Done when |
|---|------|-----|-----------|
| 2.1 | `git mv modules/DebugLog.lua core/DebugLogSetup.lua`; move its TOC line into `# Core` after `Constants` / `State` / `CoreSetup`, before every sink caller. Fix `core/Debug.lua:32-33`'s now-wrong path comment. | CM-44 | TOC lists it in `# Core`; suite green; `/cm debug on` opens the console in game. |
| 2.2 | `git mv modules/PerfSetup.lua core/PerfSetup.lua`; move its TOC line into `# Core` after `DebugLogSetup` and **before `core/ConsumableMaster.lua`**. Update `tests/test_perfsetup.lua:85,160` (both read the TOC for this entry). | CM-45 | TOC order verified; `tests/test_perfsetup.lua` green; `KCM.Perf` is the library instance, not nil, at `core/ConsumableMaster.lua` load. |
| 2.3 | Peel `settings/OptionsSetup.lua` out of `settings/Panel.lua` — lookup, descriptor, `AceGUI` publication, load-completing stub, `Helpers.LSMValues`. TOC-list it first in `# Settings`. **Do this together with 3.1/3.2.** | CM-46 | `settings/Panel.lua` under ~750 LOC; `settings/OptionsSetup.lua` exists; settings panel opens and renders identically. |
| 2.4 | Peel `settings/Slash.lua` out of `core/SlashCommands.lua` — `COMMANDS`, descriptor, instance, degradation branch, `GetLandingRows`, `OnSlashCommand`. Host verb bodies stay in `core/`, published on `KCM.SlashCommands`. | CM-47 | `core/SlashCommands.lua` under 1150 LOC; `/cm`, `/cm help`, `/cm list|get|set|reset`, and every host verb answer identically. |
| 2.5 | Add one identity case per seam: `KCM.DebugLog.instance`, `KCM.Perf`, `KCM.Settings.Helpers`, `KCM.SlashCommands.instance` are the **library's** objects, not stubs, on a full load. | `testing-§8` | Four cases green; each reddens if its setup file's TOC line is moved above its dependency. |
| 2.6 | Sweep docs naming the moved files: `docs/file-index.md`, `docs/module-map.md`, `docs/ARCHITECTURE.md`, `docs/scope.md`, `docs/debug.md`. | `documentation-§5` | `grep -rn "modules/DebugLog\|modules/PerfSetup" docs/ core/ modules/ settings/` returns nothing outside frozen `docs/audits/` and `docs/reviews/`. |

**Verify after 2.1/2.2, before moving on:** confirm AceConsole still resolves `OnSlashCommand` by
name at dispatch time once it lives in `settings/Slash.lua` (2.4) — add a case rather than assuming.

---

## Sprint 3 — Finish the Options adoption

| # | Step | IDs | Done when |
|---|------|-----|-----------|
| 3.1 | Make `KCM.Settings.Helpers` **be** `optionsLib:New(descriptor)`; delete the eleven copy-across bindings; decorate the instance in place with the host-only members. Keep `Helpers.Section` as a wrapper (it sets `ctx.lastGroup`) with its comment intact. Delete `Helpers.instance`. | CM-36 | No `Helpers.X = UI.Y` line remains in `settings/`; an identity case asserts `KCM.Settings.Helpers` is the library object. |
| 3.2 | Sweep the ~40 call sites in `settings/*.lua` onto the library's member names (`RenderGrid`, `ClearScroll`, `SessionCheckbox`, `RenderField`, `EnsureScroll`, `RefreshAllPanels`, `AttachTooltip`, `AddSpacer`, `SetRenderer`) — or add thin aliases on the instance if the rename is too large for one commit. | CM-36 | Suite green; no aliasing table anywhere. |
| 3.3 | Delete `local SECTION_HEADING_H = 26` and `local BUTTON_PAIR_REL = 0.492` (`settings/Panel.lua:74-75`); read them off the instance at `:502-503,711`. If a value is not exposed, add it upstream to `LibKa0s-Options-1.0` as an additive field and re-vendor — never keep the local. | CM-37 | Both literals gone; a case asserts the host reads the library's value. |
| 3.4 | Resolve AceGUI **once, silently** in `settings/OptionsSetup.lua` (`KCM.AceGUI = LibStub("AceGUI-3.0", true)`); `settings/Panel.lua:19`, `settings/StatPriority.lua:23`, `settings/Category.lua:29` read it and guard. Add a degraded case: AceGUI absent → addon loads, CLI answers, panel says one honest line. | CM-51 | `grep -n 'LibStub("AceGUI-3.0")' settings/` returns nothing (no non-silent call). |
| 3.5 | **In-game visual pass** against `docs/smoke-tests.md`'s settings-panel section: 50/50 button pairs not shaved at the scroll clip, section heading spacing unchanged, colour pickers keep their alpha slider, macro-bar sliders still commit live on drag. | CM-36, CM-37 | Smoke pass recorded. |

**Commit shape:** 2.3 + 3.1 + 3.2 + 3.3 as one commit — they are one rewrite of the same region.
3.4 separately. 3.5 is a verification, not a commit.

---

## Sprint 4 — Close the performance surface

| # | Step | IDs | Done when |
|---|------|-----|-----------|
| 4.1 | `.luacheckrc` `globals` += `"ConsumableMasterPerfDB",  -- the perf capture ring (savedvariables-§4, performance-§5)`. | CM-41 | `luacheck .` clean; `grep -n PerfDB .luacheckrc` hits. |
| 4.2 | Add the library-absent stub to `core/PerfSetup.lua` answering **every** member the addon reaches: `on`, `run`, `suspended`, `Note`, and `OnCommand` (deliberately nil, with the reason written down, since `core/SlashCommands.lua` already checks and says so). Grep the call sites first; the stub must answer all of them. | CM-39 (prereq) | Degraded-load case green: with `Perf.lua` omitted the addon loads and `/cm perf` says one honest line. |
| 4.3 | Rewrite both brackets to the mandated shape: file-scope `local Perf = KCM.Perf`, `local t0 = Perf.on and debugprofilestop()`, `if t0 then Perf.Note(key, debugprofilestop() - t0) end`. `core/ConsumableMaster.lua:268-269,321`; `modules/MacroBar.lua:322-323,330`. **Requires 2.2 and 4.2.** | CM-39 | No `local perf = KCM.Perf` inside a timed function remains; suite green; both brackets still record under capture. |
| 4.4 | Add bucket-reached cases in `tests/test_perfsetup.lua`, iterating the descriptor's declared bucket list rather than naming buckets inline. Drive `recompute` via the pipeline and `cooldown` via the macro-bar repaint. | CM-40 | Both buckets accrue under capture; adding an undriven bucket to the descriptor reddens the suite. |
| 4.5 | Verify the existing negative case (`no bucket accrued with the harness idle`) can fail: mutate the gate to always-on, watch it redden, restore from a `cp` backup (**never** `git checkout`). Leave a `-- red under: …` comment. | `testing-§12` | Comment present; case still green after restore. |
| 4.6 | Add `tests/perf.lua` — outside the gate, not run by `run.lua`, no wall-clock assertions. **Required:** the zero-overhead scenario over the cooldown repaint. **Recommended:** recompute pass, tooltip-cache parse. Derive its load list from the TOC and pin the derivation by reading its source. | CM-38 | `lua tests/perf.lua` runs and prints a committed allocation number for the capture-off path; `lua tests/run.lua` does **not** run it. |
| 4.7 | Write `docs/performance.md`. Lift the "the expensive paths are deliberately out of combat and will never appear in a capture" framing from `core/PerfSetup.lua`'s header — it is the most useful thing the page can say. Point at the library for the shared protocol/record contract. | CM-42 | File exists; linked from `docs/testing.md` and the `CLAUDE.md` pointer list. |
| 4.8 | Create `docs/perf-runs/README.md` (naming, schema summary, pointer to the library's contract) and commit a first real capture beside it. | CM-43 | Directory exists and is not empty. |

---

## Sprint 5 — Housekeeping

| # | Step | IDs | Done when |
|---|------|-----|-----------|
| 5.1 | Move `KCM.dbDefaults` from `core/ConsumableMaster.lua:25` to `defaults/Profile.lua`, TOC-listed first in `# Defaults`. Grep `core/` for file-load readers first — `defaults/` loads after `core/`. | CM-48 | `defaults/Profile.lua` exists; `core/ConsumableMaster.lua` no longer declares defaults; `tests/test_defaults.lua` green. |
| 5.2 | `CLAUDE.md:1` → `# CLAUDE.md — Ka0s Consumable Master`. | CM-50 | One line changed. |
| 5.3 | Act on 0.2's decision for the `core/` load order — reorder and prove with a load test, or record it as an accepted deviation with the upstream issue linked. | CM-49 | Either the TOC changed and the suite is green, or the deviation is recorded in `docs/scope.md`. |
| 5.4 | Narrow `.luacheckrc`'s `ignore` to `212/self` + `212/event`; inline-suppress `542`; **fix** the `241` case (`TooltipCache.pendingIDs` populated but never read) rather than suppressing it. | CM-52 | `luacheck .` clean with the narrowed list. |
| 5.5 | Sweep retired `§N.M` refs to `filename-§N` — `settings/Panel.lua:75,404,512`, `core/Debug.lua:5`, `core/Bus.lua:1`, `.luacheckrc:28`. | CM-53 | `grep -rnE 'standard §[0-9]+\.[0-9]+' core/ modules/ settings/ .luacheckrc` returns nothing. |
| 5.6 | Act on 0.3's answers: README `## Credits` section; `.pkgmeta` ignores for `.claude/`, `.superpowers/`, `CHANGELOG.md`; `docs/pending/LEDGER.md` migration. | CM-55, CM-56, CM-57 | Three decisions applied or explicitly declined. |
| 5.7 | Run `wow-addon:sync-docs`; refresh `docs/ARCHITECTURE.md`, `docs/file-index.md`, `docs/module-map.md`, `docs/testing.md` against the post-remediation tree. | `documentation-§5` | No doc names a moved or deleted file. |

---

## Definition of done

- [ ] `lua tests/run.lua` green; `luacheck .` 0 errors — on every commit, not just the last.
- [ ] `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` **empty**; `diff -r ../LibKa0s/testkit tests/_kit` **empty**.
- [ ] `tests/harness.lua` and `tests/loader.lua` gone; `tests/run.lua` and `tests/wow_mock.lua` sit on `tests/_kit/`.
- [ ] `core/DebugLogSetup.lua`, `core/PerfSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua` exist and are TOC-positioned per §4's map.
- [ ] `defaults/Profile.lua` exists and is the only place a default is hardcoded.
- [ ] `KCM.Settings.Helpers` **is** the `LibKa0s-Options-1.0` instance; no library layout constant is restated in the host.
- [ ] Both perf brackets use a file-scope upvalue; every declared bucket has a case proving it is reached.
- [ ] `tests/perf.lua`, `docs/performance.md`, `docs/perf-runs/README.md` exist; `ConsumableMasterPerfDB` is in `.luacheckrc`.
- [ ] `CLAUDE.md` H1 names the addon.
- [ ] In-game smoke pass recorded for the settings panel, the debug console, the macro bar, and one `/cm perf` run.
- [ ] `docs/test-cases.md` regenerated and the README `[tests]` badge in lockstep.
- [ ] CM-30 re-affirmed as a documented, tracked deviation (or scheduled).
- [ ] CM-49's standard conflict raised upstream and answered.
