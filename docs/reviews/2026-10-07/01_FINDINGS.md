# 01 — Findings

**Verdict: minor issues, with two High functional bugs and no blocking issue.** Every suite that runs outside the game is green.
The vendored payload is byte-identical to LibKa0s v1.70.0, and the collection-wide collision checks are clean. Two real
functional bugs reach ordinary players:

- **F-001.** The macro fingerprint is stored per profile, but the macros it describes are shared by the whole account. A
  character on its own profile can therefore leave another character's macro bodies live, and a deleted `KCM_*` macro is never
  recreated.
- **F-002.** The Devourer Demon Hunter spec has no stat-priority seed. It ranks spec-aware consumables as if it used Agility.

**Scope:** the whole repository (`all`). That covers the 130 tracked authored Lua files plus the docs, TOC and lint config at
`862151a` on `feat/2026-10-07-review-audit-remediation`, with a clean tree. Vendored `libs/` and `tests/_kit/` were only
diffed against their source and were not reviewed.

**Standard resolved:** Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. The index and all 27 section files it links were fetched
with `curl -fsSL` from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` into a scratch directory. The
guardrail below was checked against them.

---

## Measurement run (Step 0b, all re-run today, 2026-10-07)

Every command was run from the repo root and went through `~/.claude/dev-copilot/bin/ka0s-bounded`, writing its output to a scratch
path outside the repo. No run exited 124 or 137. Afterwards `git status --short` was empty, so no committed artifact was touched.

| Suite | Command | Result |
|---|---|---|
| **luacheck** | `ka0s-bounded luacheck .` | **PASS**: `0 warnings / 0 errors in 130 files` |
| **Headless tests** | `ka0s-bounded lua5.1 tests/run.lua` | **PASS**: `1201 passed, 0 failed, 1 skipped, 1202 total`. The one skip is the kit's own `diagnostics contract: an addon that opts out …` case, which is not applicable because this addon keeps the default. |
| **`--list` inventory** | `ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/test-cases.md` | **PASS**: the `diff` against `docs/test-cases.md` (CR-stripped) is **empty**, and both say `**Total** **1202**`. The README badge `Tests-1201%2F1202` agrees. |
| **Offline perf** | `ka0s-bounded lua5.1 tests/perf.lua` | **RAN**: 5 scenarios, exit 0, every deterministic assertion held. `recompute 15293.7 B/iter` (a GC residue per `docs/performance.md`), `cooldownRefresh 6000.0`, `probeOverheadOff 6000.0`, `probeOverheadOn 6001.3`, `refreshBurst 0.0` |
| **Offline perf, collector stopped** | a scratch copy of `tests/perf.lua` with `collectgarbage("stop")` around the measured loop | `recompute` **226657.8 B/pass**, which matches `docs/performance.md`'s "about 226.6 KB". The attribution is in F-003. |
| **Complexity (sighted)** | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | **PASS**: `0 warnings, 27244 NLOC / 3200 funcs, avg CCN 2.5 (max 15)`. No blind-file line was printed (kit revision 37, `Kit.VERSION = 37`), so `blindFiles` is 0. The max-CCN function, found through the runner's own shadow + fixed invocation, is `compositeRefs@423-436@./modules/Selector.lua` at **CCN 15**. That is at the threshold, not above it. |
| **Makefile `test:`** | none | **NOT APPLICABLE**: there is no root `Makefile` |
| **Vendor sync: LibKa0s** | `diff -rq libs/LibKa0s <scratch>/LibKa0s` (`git -C ../LibKa0s archive v1.70.0`) | **PASS**: empty. `CLAUDE.md:61` pins `v1.70.0`, and `../LibKa0s` describes as `v1.70.0`. |
| **Vendor sync: testkit** | `diff -rq tests/_kit <scratch>/testkit` (same archive) | **PASS**: empty |
| **Cross-addon (4 classes)** | the four commands in the review brief, run from `GIT/` over the 11 rows of `WowAddonStandards/standards/ADDONS.md`, TOC-derived load lists | **PASS**: clean. See below. |

**Cross-addon detail (measured non-finding, tag `v1.70.0`).**
- Class 1, slash tokens: **22** roots across 11 addons. `cut -f1 roots.txt | uniq -d` printed nothing, and there are zero raw `SLASH_*` assignments in loaded source.
- Class 2, minors: a **single line** for all eleven: `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12`.
- Class 3, payload bytes: `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s` printed nothing for every addon (AbsorbTracker is the reference).
- Class 4, Interface: `## Interface: 120100`, uniform.

All eleven `CLAUDE.md` provenance lines say v1.70.0. The brief's baseline table was recorded at v1.56.0. The tag has moved since,
so that table is **stale, not drift**.

**Census scope.** LOC uses the default scope: `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` gives **130 files**, with
`tests/` included. With `… | xargs -0 wc -l | awk '$2!="total" && $1>1500'`, **0** files are over the 1500-line cap. With
`$1>1000`, **7** are in the 1000–1500 band: `settings/Panel.lua` 1196, `settings/MacroBar.lua` 1182,
`settings/Category.lua` 1150, `tests/test_schema.lua` 1023, `tests/wow_mock.lua` 1012, `tests/test_selector.lua` 1009,
`tests/test_settingsui.lua` 1002.

### Committed artifacts that disagree with today's run

- **`docs/automated-tests/RESULTS.md`.** Its newest bundle, `20260927-030419`, measured `86660df`, and the runner says it is
  "59 commit(s) behind HEAD". It records `1112/0/1112` tests, `2838` funcs and max CCN `14`. Today's run gives `1201/1/1202`,
  `3200` and **`15`** (`compositeRefs`, which is newly at the threshold; see F-005). This is stale, not non-compliant. Regeneration
  belongs to the release.
- `docs/test-cases.md`, the README `[Tests]` badge and `docs/performance.md` all agree with today's run.

### Headless repros run for this review (scratch only, nothing written to the repo)

A scratch copy of `tests/run.lua` was pointed at three scratch suites through `Kit.run({ dir = <scratch> })`. Each uses the repo's
own loader and mock. All three cases **fail on today's code**, which confirms F-001 (two cases) and F-004:

```
FAIL  REPRO: a second profile's write is never undone by the first profile on arrival
      … (expected #showtooltip\n/use item:950001, got #showtooltip\n/use item:950002)
FAIL  REPRO: a KCM macro the player deleted is not recreated while the pick is unchanged
FAIL  REPRO: an unseeded flask found under spec A is not a candidate after switching to spec B
      … (expected 961701, got nil)
0 passed, 3 failed, 0 skipped, 3 total
```

### Convention sweep (what exists here, so nothing is flagged that this addon does not use)

- **Printer and prefix.** The chat printer is `KCM.Say` (CoreSetup, from LibKa0s-Core) and the prefix is `KCM.PREFIX` (`core/Constants.lua:18`). No raw `print(` appears in loaded source outside `/run` macro bodies, where it is deliberate.
- **Slash dispatch.** The dispatcher is the `COMMANDS` table in `settings/Slash.lua`, built on LibKa0s-Slash.
- **Single write seam.** Every schema row is written through LibKa0s-Schema (`KCM.Schema:Set` / `Helpers.SetAndRefresh`). The registry writers are in `modules/Selector.lua`, and `modules/MacroManager.lua` owns `macroState`.
- **Macro firewall.** `modules/MacroManager.lua` is the sole caller of `CreateMacro` / `EditMacro` (`events-frames-taint-§4`).
- **Vendored code.** LibKa0s (14 majors consumed) and the testkit at kit revision 37. Each adopted module has one `*Setup.lua` descriptor and stub.
- **Evidence present.** The repo carries `tests/run.lua`, `docs/test-cases.md`, `tests/perf.lua`, `docs/performance.md`, `docs/perf-analysis/` and `docs/automated-tests/`.

---

## High

### F-001 — A per-profile fingerprint skips writes to account-wide macros that hold another profile's body, or that no longer exist `[correctness]` `[savedvariables]`

- **Where.** In `modules/MacroManager.lua:516`, the write is skipped when `if not stale[macroName] and alreadyApplied(state, pending, body, icon) then … return "unchanged"`, and `alreadyApplied` (`:442-445`) compares only against `KCM.db.profile.macroState[macroName]`. It never reads the macro the client actually holds.
- **Problem.** `macroState` is per AceDB profile, while the `KCM_*` macros are per account. Nothing re-validates the fingerprint when a different character arrives. The profile handler's `InvalidateState` (`core/ConsumableMaster.lua:608-610`) fires only on a profile *switch* or *copy* inside one session. `PLAYER_ENTERING_WORLD` (`:740-751`) only discovers and recomputes.
- **What goes wrong.**
  - Character B, on profile B, logs in after character A, on profile A, has rewritten a macro. B's pick matches B's stale fingerprint, so B writes nothing, and B's action bar keeps running A's `/use item:<A's pick>`.
  - A macro the player deletes from the macro UI is never recreated while its pick is unchanged. It comes back only after `/cm rewritemacros`; `/cm resync` keeps the fingerprints, so it does not fix this.
  - The macro bar shows B's pick (`MacroDisplay.PickID` reads `macroState`) while the macro on B's action bar runs A's. The two surfaces disagree.
- **Impact.** On an ordinary login, a consumable macro uses an item the character may not carry or did not choose. For a combat potion or healthstone, a click mid-pull then does nothing useful.
- **Reachability.** This affects any player who uses per-character (or per-class or per-spec) profiles on more than one character, on login, whenever the arriving character's pick for a category has not changed since it last played. Per-character profiles are a documented feature (`README.md:127`, Profiles page). Separately, it affects any player who deletes a `KCM_*` macro.
- **Evidence.**
  - Two scratch repros fail today (Measurement run). The first case ends with `expected #showtooltip\n/use item:950001, got … item:950002`.
  - The docs promise the opposite. `docs/scope.md:24` says "two characters on different profiles share one set of macros and each rewrites it to its own profile's picks on arrival", and `README.md:127` says "two characters on different profiles take turns rewriting the same set".
- **Coverage.** `tests/test_profiles.lua` covers switch and copy within one session and nothing on arrival. No case covers a deleted macro.
- **Fix direction (standards-compliant).** Before trusting the fingerprint, confirm it against the live macro. `GetMacroIndexByName` and `GetMacroInfo` are unprotected reads, so `MacroManager` stays the sole writer (`events-frames-taint-§4`).

### F-002 — The Devourer Demon Hunter spec (`12_1480`) has no stat-priority seed, so it ranks Agility items first and every secondary stat at zero `[correctness]` `[data]`

- **Where.**
  - `defaults/Defaults_StatPriority.lua:126-128` seeds only `-- Demon Hunter` / `["12_577"]` (Havoc) / `["12_581"]` (Vengeance).
  - `core/SpecHelper.lua:26` falls back to `[12] = "AGI", -- Demon Hunter` with `secondary = {}`.
  - `SpecHelper.GetStatPriority` is the seed-or-fallback ladder.
- **Problem.** Midnight's third Demon Hunter spec is Devourer (spec ID **1480**, confirmed on warcraft.wiki.gg's `SpecializationID` page). The class infobox lists Demon Hunter primaries as "Agility or Intellect", and Devourer is the Intellect caster. With no seed row:
  - `statWeight` (`modules/Ranker.lua:131`) gives Agility the full `PRIMARY_WEIGHT` and Intellect 0.
  - `secondaryWeight` returns 0 for every secondary stat, because the list is empty.
- **Impact.** For a Devourer, the spec-aware categories `FLASK`, `STAT_FOOD` and `CMBT_POT` (and `WPN_ENCH`'s stat ranking) prefer Agility items and lose all secondary-stat preference. The macro then picks a consumable the spec gets no value from.
- **Reachability.** This affects any Devourer Demon Hunter on a default profile who has not set a Stat Priority override, on every recompute.
- **Coverage (asleep test, see F-008).** `tests/test_defaults.lua:343`, "stat priority covers all thirteen classes", checks one seeded spec per class, so a missing spec passes.
- **Unverified in-client.** The exact secondary order for Devourer is not given here. It must come from the file's own refresh procedure (archon.gg, `defaults/Defaults_StatPriority.lua` header).

## Medium

### F-003 — Each out-of-combat recompute re-ranks every category a second time with no score cache, to rebuild the macro-bar flyouts. That is 63% of the pass's allocation. `[perf]`

- **Where.** `modules/MacroBar.lua:492` (`KCM.MacroBarFlyout.Apply(btn, c)` for every shown slot on each `MACROBAR_REFRESH`) reaches `modules/MacroBarFlyout.lua:580`, which reads `local ids = KCM.Selector.ListAvailable(catKey, nil, nil) or {}`.
- **Problem.** `Pipeline.Recompute` ranks each category with a per-pass `scoreCache`, then publishes `MACROBAR_REFRESH`. The bar then rebuilds every flyout through `ListAvailable` with `scoreCache = nil`:
  - Every candidate is scored again.
  - Every item's `GetItemInfo` and tooltip is fetched again.
  - Composite slots (`HP_AIO`, `MP_AIO`) recurse into their sub-categories, which were just ranked for their own slots.
- **Measured (scratch attribution script, collector stopped, 100 iterations, same loader as `tests/perf.lua`):**

  | Path | bytes/iter | `ListAvailable` calls | `C_TooltipInfo.GetItemByID` calls |
  |---|---|---|---|
  | `Pipeline.Recompute`, bar and flyout on (default) | **226715.5** | 20 / pass | 184 / pass |
  | `MacroBar.Refresh` alone | **142727.7** | 20 / refresh | 107 / refresh |
  | `Pipeline.Recompute`, flyout off | 105509.3 | 0 | — |
  | `Pipeline.Recompute`, bar off | 83910.5 | 0 | — |

  The flyout rebuild accounts for about 121 KB of the 226.7 KB a pass allocates.
- **Impact.** Out of combat, a pass runs on every bag change, every item-info arrival for a bag item, every spec swap, equipment swap and learned spell. In combat the flyout rebuild is skipped (`MB.Refresh`'s `combat` gate), so this is open-world and between-pulls cost, not in-fight cost.
- **Reachability.** This affects any player on a default profile, because the bar and the flyout both ship on, on every out-of-combat recompute.
- **Not the frame-time delta.** The figures above are allocation and call counts, the deterministic half (`performance-§9`). No in-client capture backs a frame-time claim.

### F-004 — A spec change runs no discovery pass, so an unseeded consumable in the bags is not a candidate for the new spec until the bags change `[correctness]`

- **Where.**
  - `core/ConsumableMaster.lua:767-776`: `KCM:OnSpecChanged` only does `requestRecompute("spec_changed")` and publishes `SPEC_CHANGED`.
  - Discovery is filed per spec (`discoverySpecKey`, `:387-393`) and runs only on `PLAYER_ENTERING_WORLD`, `BAG_UPDATE_DELAYED`, a bag item's `GET_ITEM_INFO_RECEIVED`, the stand-up and `/cm resync`.
- **Problem.** For the spec-aware categories (`STAT_FOOD`, `CMBT_POT`, `FLASK`, `WPN_ENCH`), an item that is in the bags but in no seed list was discovered into the *old* spec's bucket only. The new spec's candidate set never contains it until a bag event.
- **Impact.** After a respec, for example right before a pull, a flask, potion or food the player carries is missing from the macro. The macro falls to a lower-ranked seeded item, or to the empty-state body. It self-heals on the next bag change.
- **Reachability.** This affects any player who changes spec while carrying a spec-aware consumable that is not in the shipped seeds. New-patch items are exactly the case auto-discovery exists for.
- **Evidence.** The scratch repro fails: `expected 961701, got nil` after `mock.setSpec(7, 2, 264, …)` and a `spec_changed` recompute. Before the switch, the same item was picked under the old spec.

## Low

### F-005 — Composite config resolution is written twice, and the flyout's copy is now the addon's maximum-CCN function `[design]` `[complexity]`

- **Where.**
  - `modules/Selector.lua:423-436`, `compositeRefs`, has the comment "same precedence MacroManager uses".
  - `modules/MacroManager.lua:177-184`, `compositeConfig`.
- **Problem.** Two copies of one rule: the `enabled` set, then `orderInCombat` / `orderOutOfCombat`, then the `Categories` component lists. They already differ when the saved bucket is missing. `compositeConfig` returns nil, so the body is empty, while `compositeRefs` falls back to every component, so the flyout lists everything.
- **Impact.** This is a maintainability hazard. Today's sighted run puts `compositeRefs` at **CCN 15**, the run's maximum and at the threshold. The record's maximum was 14. Lizard counts the `and`/`or` defaulting chain as decisions, so this is dense defaulting rather than tangled control flow.
- **Reachability.** Nobody, on a shipping profile: AceDB defaults always materialize the `HP_AIO` / `MP_AIO` buckets (`defaults/Profile.lua`), so the divergent branch is unreachable today.

### F-006 — `/cm priority … add|remove|…` accepts any token `tonumber` can read: zero, negative, fractional, hex `[ux]` `[validation]`

- **Where.** `core/SlashCommands.lua:205`, `return tonumber(token)`, in `parsePriorityID`.
- **Problem.** `0`, `1.5`, `0x10`, `1e3` and a raw `-20484` are all accepted and written into `added` or `blocked`. A raw negative becomes a spell sentinel without the documented `s:` prefix. The panel's Add-by-ID box validates through the library's IdInput, so the two doors disagree.
- **Impact.** Junk keys are stored in SavedVariables. A fractional ID builds `/use item:1` through `%d`. The registry gets entries the panel cannot render or remove cleanly.
- **Reachability.** Only a player who types a malformed ID into the slash editor.

### F-007 — `PLAYER_SPECIALIZATION_CHANGED`'s unit argument is ignored `[perf]` `[events]`

- **Where.** `core/ConsumableMaster.lua:767`, `function KCM:OnSpecChanged(event)`.
- **Problem.** The event's payload is `unitTarget`, and per the API documentation it fires for group members as well as the player. **This is unverified in-client.** The handler recomputes and publishes `SPEC_CHANGED` on any of them.
- **Impact.** Each groupmate's respec costs one coalesced recompute (226 KB of garbage out of combat, F-003). The panel's retrack is gated on `O._viewedSpecAuto`, so there is no UX change.
- **Reachability.** This affects any player in a group when a groupmate changes spec.

### F-008 — The stat-priority seed test checks that each class is covered, not each spec, so it cannot catch F-002 `[tests]`

- **Where.** `tests/test_defaults.lua:343`, `test("Defaults: stat priority covers all thirteen classes", …)`, which sets `byClass[classID] = true` for any one seeded spec.
- **Problem.** A class with one spec missing still passes. It is green today while Devourer is absent.
- **Reachability.** Only the test inventory is affected. The shipped defect is F-002.

---

## Upstream findings

None. No defect was found in `libs/` or `tests/_kit/`. Both are byte-identical to LibKa0s `v1.70.0`.

## Standards cross-check

The cross-check was performed against v2.76.1. No fix direction above introduces a new deviation. In particular:

- F-001's verification is a read (`GetMacroInfo`), so `MacroManager` stays the sole writer (`events-frames-taint-§4`).
- F-007's direction is an early return on the unit argument rather than a private event frame, which `events-frames-taint-§1` carves out narrowly.
