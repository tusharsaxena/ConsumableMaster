# 04 — Technical Design (Remediation)

**Addon:** Ka0s Consumable Master · **Audit:** 2026-07-12 · **Standard:** v1.0.0

How to close each deviation. This is a **design**, not an edit — execution is the separate engagement scoped by `05_EXECUTION_PLAN.md`. Deviation IDs are the shared key. Ordering constraints: the **namespace migration (CM-01/02)** is the tectonic change everything else rides on; the **infra files (CM-15/16/17)** are cheap, independent, and should land first so a green commit gate exists before the risky refactors.

---

## Theme A — Namespace & architecture (CM-01, CM-02, CM-03, CM-04, CM-22)

The addon's biggest gap from the standard is architectural: a `_G.KCM` global with direct cross-module calls, versus the standard's private `NS` + message bus. The feature logic is sound; this is a **mechanical re-hosting**, not a rewrite.

- **CM-01 / CM-02 — private namespace.** Add a bootstrap (`core/Namespace.lua`) that does `local addonName, NS = ...` and seeds shared upvalues. Promote to AceAddon in `core/ConsumableMaster.lua` with `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceConsole-3.0")` and `NS.addon = addon`. Migrate every file's header from `local KCM = _G.KCM` to `local addonName, NS = ...`. **Transition seam:** keep `local KCM = NS` at the top of each file so the ~1000 internal `KCM.*` references need no touch in the same pass; delete `_G.KCM = KCM` and the alias once the tree is green. **Risk:** load-order — `NS` must exist before any consumer; the TOC listing (CM-07) enforces this.
- **CM-03 — message bus.** Introduce `NS.bus` (AceEvent embed) and `NS.NewBusTarget()` per §4.4. Convert the hot cross-module edges to messages: `Ka0s_ConsumableMaster_Recompute`, `…_PanelRefresh`, `…_SpecChanged`. Each **receiver** owns its own target (never register two on `NS.bus`) — anti-pattern #32. Because this addon has few modules and a deliberately pure pipeline, a **pragmatic scope**: bus-ify the event→pipeline and pipeline→panel edges (the ones that cross feature boundaries); leave pure-function calls (Selector/Ranker/Classifier queried synchronously by MacroManager) as direct calls — they are data queries, not cross-module control flow. Document every message in `docs/ARCHITECTURE.md`.
- **CM-04 — Tier-2 tree.** Move sources into `core/` (Compat, Constants, Namespace, State, ConsumableMaster, Database, SpecHelper, TooltipCache, BagScanner, Classifier), `modules/` (Ranker, Selector, MacroManager, KCM* widgets, Pipeline), keep `defaults/` and `settings/`, add `locales/`. Declare the tier in the `CLAUDE.md` stub. Pure path move + TOC re-point; no logic change.
- **CM-22 — schema drives defaults + one Set.** Source schema `default =` from the defaults constants; add `NS.Schema:Set(path, value)` that validates → writes → fires `onChange`, and route both panel and slash through it. Low risk; the schema is only 2 rows today.

## Theme B — Missing infrastructure (CM-15, CM-16, CM-17)

Independent, additive, no runtime impact — land first to establish the commit gate (§14A).

- **CM-16 `.luacheckrc`** — std lua51, `exclude_files = { "libs/", "audit/", "tests/", "reviews/" }`, `read_globals` for the WoW APIs the code touches (`C_Spell`, `C_AddOns`, `GetSpecialization*`, `CreateMacro`/`EditMacro`, `StaticPopup*`, `Settings`, `C_Timer`, …), `globals = { "ConsumableMasterDB" }`. Expect first run to surface real warnings — triage separately.
- **CM-15 `.pkgmeta`** — `package-as: ConsumableMaster`, no `externals:`, ignore `audit/ docs/ tests/ reviews/ .luacheckrc .gitignore *.bak`.
- **CM-17 `tests/`** — runner + loader + `wow_mock.lua` per §14A. Seed suites against the **pure** layer first (highest value, easiest): `test_classifier.lua` (subType matching), `test_ranker.lua` (scoring/ordering), `test_selector.lua` (pick + discovered set), `test_id.lua` (`AsSpell`/`IsSpell` sentinels), `test_schema.lua` (`ValidateSchema` count), `test_macromanager.lua` (body-string builders, composite assembly — frame-free). The mock must include a `(message,target)`-keyed bus (anti-pattern #33) so future CM-03 receivers are testable.

## Theme C — TOC & packaging (CM-06, CM-07, CM-08, CM-09)

- **CM-06** — rewrite metadata to §2.1 field order: add `OptionalDeps: Ace3, LibStub, CallbackHandler-1.0`, `X-Standard`, `X-Curse-Project-ID` (1522944 from the README badge), `X-Wago-ID`; set `Author: add1kted2ka0s`; change `Category-enUS` to an allowed value (`UI` or `Combat`).
- **CM-07** — after the metadata block + one blank line, emit `# Libraries` / `# Locales` / `# Core` / `# Defaults` / `# Modules` / `# Settings` sections in load order. Reconciles with the CM-04 folder move. `embeds.xml` may stay (Tier-2 `MAY`) under `# Libraries`, or inline the lib list.
- **CM-08** — move `schemaVersion` to `NS.defaults.global`; add `core/Database.lua` with `RunMigrations()` (guard `g.schemaVersion = g.schemaVersion or 1`) invoked right after `AceDB:New`.
- **CM-09** — remove AceConfig from `libs/` + `embeds.xml` (no Profiles page uses it). Decide AceTimer: either vendor it and use `NS:ScheduleTimer`, or add a one-line `.luacheckrc`/ARCHITECTURE note that `C_Timer` is the deliberate choice (SHOULD, so a documented justification satisfies it).

## Theme D — Chat, locale, compat (CM-10, CM-11, CM-12, CM-23)

- **CM-10** — define `NS.PREFIX = "|cff00ffff[CM]|r"` once (Constants); replace the two `local PREFIX` and all 37 inline `[CM]` literals with a shared `NS.Say(msg)` seam. Mechanical find/replace; verify with a grep gate in the plan.
- **CM-11** — add `locales/enUS.lua` exporting `NS.L` with the key-returning metatable; wrap user-facing strings (panel labels, slash descriptions, popup text) in `L[...]`. English stays the only shipped locale.
- **CM-12** — add `core/Compat.lua` exposing `Compat.GetSpecialization`, `Compat.GetSpecializationInfo(ForClassID)`, `Compat.GetSpellInfo`; replace the direct calls in SpecHelper, SlashCommands, MacroManager, settings/StatPriority, settings/Category, KCMItemRow. `Compat` loads first (§1.2 order).
- **CM-23** — publish `NS.COMMANDS`; render help rows as `|cffffff00/cm <name>|r — |cffffffff<desc>|r`.

## Theme E — Debug console (CM-13, CM-14)

The most involved net-new work. §12 mandates a full on-screen console.

- **CM-13** — add `modules/DebugLog.lua`: a `BackdropTemplate` window on `DIALOG` strata (`ConsumableMasterDebugWindow`), 700×344, `UISpecialFrames`, `ScrollingMessageFrame` (`SetMaxLines(500)`), monospace font shipped under `media/fonts/` (JetBrains Mono + license) registered with LSM, the two pure formatters (`FormatPlain`/`FormatColored`), Copy/Clear, and a header `Debug: ON/OFF` toggle. Route `NS.Debug(tag, fmt, ...)` (tag-first, zero-alloc gate) into it. Note: adding LSM is a new mandatory-when-media lib (§3.2). Unit-test the formatters (feeds CM-17).
- **CM-14** — hold the enabled flag in `NS.State.debug` (session-only, default off); drop `debug` from `profile` defaults; `/cm debug on|off` + header toggle route through one `DebugLog:SetEnabled`.

## Theme F — Options polish (CM-20, CM-21)

- **CM-20** — add the top-right Defaults button (`DEFAULTS_W` 110) to each subcategory header, wired to that page's reset. Low risk.
- **CM-21** — convert the body renderer to the two-column paired grid (§6.6): pair consecutive schema rows at `SetRelativeWidth(0.5)`, flush at two children, `wide=true` breaks full-width; inset paired action buttons to `BUTTON_PAIR_REL` 0.492. Medium risk — the priority-list pages are custom-rendered and may legitimately stay `wide` full-width rows; only the schema-driven General page must adopt the grid.

## Theme G — Docs (CM-18, CM-19)

- **CM-18** — shrink `CLAUDE.md` to a stub (tier, standard link, `docs/` pointer); relocate the current brief to `docs/` (e.g. `docs/agent-context.md`).
- **CM-19** — add `## Testing` to README (harness + `luacheck .` + `docs/smoke-tests.md`); move `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`; ensure it carries the §15.3 sections incl. the message-bus catalogue from CM-03.

---

## Cross-cutting risks

- **CM-01 blast radius:** touches every file. Mitigate with the `local KCM = NS` alias so the migration is header-only per file, and land it as one atomic commit behind green tests (CM-17 must exist first).
- **CM-04 + CM-07 are coupled:** the folder move and the TOC re-listing must land together or the addon won't load.
- **CM-13 ships new media + a new lib (LSM):** largest single unit; isolate it after the infra/namespace work is stable.
- **Read-only invariant:** none of the above is applied by this audit; all are proposals for the remediation engagement.
