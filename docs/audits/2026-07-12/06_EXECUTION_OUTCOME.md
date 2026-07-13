# 06 — Execution Outcome (Remediation)

**Addon:** Ka0s Consumable Master · **Audit:** 2026-07-12 · **Standard:** v1.0.0

Outcome of executing `04_TECHNICAL_DESIGN.md` + `05_EXECUTION_PLAN.md`. **All 23 deviations (19 MUST + 4 SHOULD) are closed.** The full remediation lands in the working tree, uncommitted — staging and commits are left to you.

Final gate (all green):

```
$ lua5.1 tests/run.lua
  9 passed, 0 failed, 9 total
$ luacheck .
  0 warnings / 0 errors in 36 files
```

Cross-cutting gates also verified: `grep -rn '\[CM\]' --include='*.lua'` outside the one constant → **0**; `_G.KCM` real references in source → **0** (one doc-comment mention remains); every TOC-listed file exists; every source file `luac5.1 -p` parses.

---

## What changed, by deviation

| ID | Sev | Status | Landing |
|----|-----|--------|---------|
| CM-01 | MUST | ✅ | Private namespace: every file migrated to `local addonName, NS = ...` + `local KCM = NS` alias; `_G.KCM` deleted everywhere. New `core/Namespace.lua` bootstrap. |
| CM-02 | MUST | ✅ | `core/ConsumableMaster.lua` (was `Core.lua`) does `AceAddon:NewAddon(NS, addonName, …)` + `NS.addon = addon`. |
| CM-03 | MUST | ✅ | `core/Bus.lua`: `KCM.bus` (AceEvent embed) + `KCM.NewBusTarget()` + `KCM.MSG`. Event→pipeline (`RECOMPUTE`), pipeline→panel (`PANEL_REFRESH`), spec→panel (`SPEC_CHANGED`) converted to messages; each receiver on its own target. |
| CM-04 | MUST | ✅ | Tier-2 tree: `core/` (13), `modules/` (8), `defaults/` (10), `settings/` (4), `locales/` (1). Tier declared in the `CLAUDE.md` stub. |
| CM-05 | MUST | ✅ | Logo pair moved to `media/logos/`; `LOGO_TEXTURE` path updated. |
| CM-06 | MUST | ✅ | TOC metadata rewritten: `OptionalDeps`, `X-Standard`, `X-Curse-Project-ID: 1522944`, `Author: add1kted2ka0s`, `Category-enUS: Combat`. (`X-Wago-ID` omitted — not published on Wago.) |
| CM-07 | MUST | ✅ | TOC file listing sectioned `# Libraries / Locales / Core / Defaults / Modules / Settings` in load order. |
| CM-08 | MUST | ✅ | `schemaVersion` moved to `db.global`; `core/Database.lua` `RunMigrations()` invoked right after `AceDB:New`. |
| CM-09 | SHOULD | ✅ | AceConfig pruned from `libs/` + `embeds.xml`. AceTimer: `C_Timer` documented as the deliberate choice in `docs/ARCHITECTURE.md`. |
| CM-10 | MUST | ✅ | `KCM.PREFIX` + `KCM.Say` in `core/Constants.lua`; all 37 inline `[CM]` literals removed (chat sites → `KCM.PREFIX`; macro-body sites → format-injected, byte-identical). |
| CM-11 | MUST | ✅ | `locales/enUS.lua` publishes `KCM.L` (key-returning metatable); 78 user-facing strings across the settings surface wrapped in `L[...]`. |
| CM-12 | MUST | ✅ | `core/Compat.lua` seam over `GetSpecialization*` / `GetSpellInfo`; all direct call sites in SpecHelper, SlashCommands, MacroManager, settings/*, KCMItemRow routed through it. |
| CM-13 | MUST | ✅ | `modules/DebugLog.lua`: `BackdropTemplate` window (`ConsumableMasterDebugWindow`, DIALOG, 700×344, `UISpecialFrames`), `ScrollingMessageFrame` (`SetMaxLines(500)`), JetBrains Mono shipped under `media/fonts/` + registered with vendored LSM, pure `FormatPlain`/`FormatColored`, Copy/Clear/Toggle. |
| CM-14 | MUST | ✅ | Debug flag is session-only `KCM.State.debug` (`core/State.lua`, default off); dropped from `profile`; `/cm debug [on\|off]` + header toggle + a State-backed General checkbox all route through `DebugLog:SetEnabled`. |
| CM-15 | MUST | ✅ | `.pkgmeta` (`package-as: ConsumableMaster`, ignores `audit docs tests reviews …`). |
| CM-16 | MUST | ✅ | `.luacheckrc` (std lua51, WoW `read_globals`, `ConsumableMasterDB` write global). Clean run. |
| CM-17 | MUST | ✅ | `tests/` harness — runner + loader + `wow_mock.lua` (incl. `(message,target)`-keyed bus) + 9 suites. |
| CM-18 | MUST | ✅ | Root `CLAUDE.md` reduced to a stub; full brief relocated to `docs/agent-context.md` (stale facts corrected). |
| CM-19 | MUST | ✅ | README `## Testing` added; `ARCHITECTURE.md` → `docs/ARCHITECTURE.md` with a message-bus catalogue + tier layout. |
| CM-20 | SHOULD | ✅ | Top-right `DEFAULTS_W` (110) Defaults button in the panel header, wired per page. |
| CM-21 | MUST | ✅ | `Helpers.Grid` two-column paired renderer (§6.6); `ButtonPair` inset to `BUTTON_PAIR_REL` 0.492. |
| CM-22 | SHOULD | ✅ | Schema `default` sourced from the defaults constant; `KCM.Schema:Set(path,value)` (validate→write→onChange→refresh) is the single mutation seam for panel + slash. |
| CM-23 | SHOULD | ✅ | `KCM.COMMANDS` published; help rows render `\|cffffff00/cm <name>\|r — \|cffffffff<desc>\|r`. |

### Deliberate deviations from the plan

- **`X-Wago-ID`** omitted from the TOC — the addon is not published on Wago, so an empty field would be noise. Re-add if/when a Wago project exists.
- **Pipeline stayed inside `core/ConsumableMaster.lua`** rather than split into a separate `modules/Pipeline.lua`. CM-04 is "pure path move, no logic change"; splitting the pipeline is deferrable polish. The Tier-2 folder requirement is satisfied.
- **Two pre-existing dead-code smells** (`TooltipCache.pendingIDs` set never read; `ROW_VSPACER` unused) are `.luacheckrc`-ignored with a `[follow-up]` note rather than changed in a compliance pass.

---

## Test harness

A headless harness runs the addon's **pure** layer under a mock WoW client in plain `lua5.1` — no game required. It is the commit gate the standard assumes, and the safety net that made the namespace migration and folder move verifiable.

**Run it:**

```
lua5.1 tests/run.lua     # 9 suites — exits non-zero on any failure
luacheck .               # lint gate
```

**Layout (`tests/`):**

| File | Role |
|------|------|
| `run.lua` | Entry point. Discovers `test_*.lua`, runs each, prints PASS/FAIL, exits non-zero on failure. |
| `harness.lua` | Assertion + suite framework (`h.suite`, `t.eq/ne/truthy/falsy/near/eqList/contains`). Captures the real `print` before the mock clobbers it. |
| `loader.lua` | Loads addon source under the mock. `loadPure()` = the logic layer with a live `db.profile`; `loadFullAddon()` = every file **in TOC order** (the headless proxy for an in-game load). Threads one fresh `NS` to every chunk exactly as WoW does. |
| `wow_mock.lua` | The mock client: `LibStub` + Ace3 stubs, a permissive `CreateFrame`, the `C_*` namespaces, spec/spell/item/bag/macro globals, and a `(message,target)`-keyed AceEvent bus. Exposes an item-injection API (`setItem`, `setBag`, `setSpell`, `setSpec`, `setCombat`). |

**Suites (9, ~230 assertions):**

| Suite | Covers |
|-------|--------|
| `test_id` | Opaque ID sentinels (`AsSpell`/`IsSpell`/`SpellID`/`ItemID`). |
| `test_classifier` | All 8 matchers (positive + negative), `MatchAny` excludes composites. |
| `test_ranker` | Scoring, conjured/immediate/HOT bonuses, HS preference, `_statWeight` matrix, sort order + tiebreak. |
| `test_selector` | Candidate set (seed ∪ added ∪ discovered − blocked), Add/Block/MarkDiscovered, owner-walk pick, pin reorder, spec-aware buckets. |
| `test_schema` | `ValidateSchema()==0`, every row resolves, Get/Set round-trip. |
| `test_macromanager` | `BuildBody` (item/spell/empty) + `BuildCompositeBody` (castsequence, nocombat, disabled-ref drop, empty→nil). |
| `test_bus` | Publish/subscribe across targets, unregister isolation, RECOMPUTE→pipeline routing. |
| `test_debuglog` | `FormatPlain`/`FormatColored` (incl. nil tag/msg), `SetEnabled`/`IsEnabled`/`Toggle` drive `KCM.State.debug`. |
| `test_load` | **Full addon loads in TOC order without error** and publishes every subsystem — the load-order regression guard. |

**What the harness intentionally does *not* cover:** event-driven behaviour against live Blizzard APIs, frame/UI rendering, taint, action-bar icon adoption, and real tooltip parsing. Those remain manual (below and in `docs/smoke-tests.md`).

---

## Manual smoke tests

Run these in-game after loading the remediated build. They target the areas this remediation touched; `docs/smoke-tests.md` remains the full 12-section suite for a release pass.

### A. Load & namespace (CM-01/02/04/07)
1. Fresh `/reload`. **Expect:** no Lua errors, addon loads.
2. Type `/cm version` → prints the version line. Confirms the AceAddon promotion + slash registration survived the migration.
3. Macro UI → **General Macros**: the 10 `KCM_*` macros exist. Confirms the pipeline still writes.

### B. Chat prefix & commands (CM-10/23)
4. `/cm` (bare) → help index renders as `/cm <name> — <desc>` rows, all with the cyan `[CM]` prefix.
5. `/cm dump pick food` → output rows all carry the `[CM]` prefix (no un-prefixed lines).

### C. Debug console (CM-13/14)
6. `/cm debug on` → the **ConsumableMaster Debug** window opens; header shows `Debug: ON`. Drag it by the title; press **Escape** → closes.
7. Trigger events (loot something, swap a bag) → lines stream into the console with `HH:MM:SS` + optional `[tag]`. Click **Copy** → an edit box appears with the plain-text log (Ctrl-C works). **Clear** empties it.
8. `/reload` → reopen the console → header shows `Debug: OFF` (session-only flag reset). Confirm no `debug` key exists in `ConsumableMasterDB` (it's session-only now).
9. `/cm debug off` while open → header flips to `Debug: OFF`, streaming stops.

### D. Options panel (CM-20/21/22)
10. Open **Options → Ka0s Consumable Master → General**. **Expect:** a top-right **Defaults** button in the header; `[Enable]` and `[Debug console]` sit side-by-side (two-column grid); the Maintenance buttons are paired.
11. Toggle `[Debug console]` → the console opens and `KCM.State.debug` flips (verify with `/cm debug` state). Toggle `[Enable]` off/on → `/cm get enabled` reflects it (schema `Set` seam).
12. Click the header **Defaults** button → the "Reset all" confirmation popup appears.

### E. Compat & spec-aware (CM-12)
13. On a spec-aware category (Flask/Combat Potion/Stat Food): `/cm dump pick flask`, then switch specs in the talents UI, re-run. **Expect:** the pick and priority list retrack to the new spec (exercises `Compat.GetSpecialization*` + the `SPEC_CHANGED` bus message).

### F. Macro correctness (CM-10 macro-body strings)
14. Empty a category (no owned candidate) → its `KCM_*` body is the empty-state `/run print('|cff00ffff[CM]|r no … ')` line and clicking it prints the prefixed message. Confirms the format-injected prefix resolves byte-identically to the pre-remediation string.
15. Composite (`KCM_HP_AIO`) with picks → body has `#showtooltip`, a `/castsequence [combat] reset=combat item:…` line, and `/use [nocombat] item:…`.

### G. Packaging (CM-15/16)
16. From the repo root on your dev box: `lua5.1 tests/run.lua` → 9 passed; `luacheck .` → 0/0. (Not in-game, but the pre-commit gate.)

---

## Notes for the committer

- Nothing is staged or committed. `git status` shows the moves as delete+add (files relocated with plain `mv`, not `git mv`, to avoid touching the index) — a `git add -A` will reconcile the renames.
- New tracked assets: `libs/LibSharedMedia-3.0/` (vendored, LGPL), `media/fonts/JetBrainsMono-Regular.ttf` + `OFL.txt`.
- Version was **not** bumped (per project policy — releases are your call). Consider a bump when you cut the remediated release.
