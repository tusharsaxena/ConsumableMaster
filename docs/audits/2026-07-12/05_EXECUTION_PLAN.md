# 05 — Execution Plan (Remediation)

**Addon:** Ka0s Consumable Master · **Audit:** 2026-07-12 · **Standard:** v1.0.0

Ordered, checkable remediation for the separate follow-up engagement. Sequenced so a **green commit gate exists before the risky refactors**, and coupled changes land together. Each step lists its deviation IDs. Commit only on green `lua tests/run.lua` + clean `luacheck .` (§14A) once those exist.

---

## Sprint 0 — Establish the commit gate (low risk, additive)

Land these first so every later sprint can prove itself green.

- [ ] **S0.1** Add `.luacheckrc` (std lua51; exclude `libs/ audit/ tests/ reviews/`; `read_globals` for the WoW APIs used; `globals = { ConsumableMasterDB }`). — **CM-16**
- [ ] **S0.2** Run `luacheck .`, triage the warnings it surfaces (fix trivial, note the rest as follow-ups). — **CM-16**
- [ ] **S0.3** Add `.pkgmeta` (`package-as: ConsumableMaster`, no `externals:`, ignore `audit/ docs/ tests/ reviews/`). — **CM-15**
- [ ] **S0.4** Scaffold `tests/` (`run.lua`, `loader.lua`, `wow_mock.lua` with a `(message,target)`-keyed bus mock). — **CM-17**
- [ ] **S0.5** Write first suites against the pure layer: `test_classifier`, `test_ranker`, `test_selector`, `test_id`, `test_schema`, `test_macromanager` (frame-free body builders). Get `lua tests/run.lua` green. — **CM-17**

## Sprint 1 — TOC, packaging, prefix, compat (mechanical, no arch change)

- [ ] **S1.1** Rewrite the TOC metadata block to §2.1 field order/values (add `OptionalDeps`, `X-Standard`, `X-Curse-Project-ID: 1522944`, `X-Wago-ID`; `Author: add1kted2ka0s`; fix `Category-enUS`). — **CM-06**
- [ ] **S1.2** Move `schemaVersion` to `global`; add `core/Database.lua` `RunMigrations()` called after `AceDB:New`. — **CM-08**
- [ ] **S1.3** Prune AceConfig from `libs/` + `embeds.xml`; decide/document AceTimer vs `C_Timer`. — **CM-09**
- [ ] **S1.4** Define one `NS.PREFIX` + `NS.Say`; replace both `local PREFIX` and all 37 inline `[CM]` literals. Gate: `grep -rn '\[CM\]' --include='*.lua'` outside the constant returns 0. — **CM-10**
- [ ] **S1.5** Add `core/Compat.lua`; replace direct `GetSpecialization*` / `GetSpellInfo` calls in SpecHelper, SlashCommands, MacroManager, settings/StatPriority, settings/Category, KCMItemRow. — **CM-12**
- [ ] **S1.6** Publish `NS.COMMANDS`; reformat help rows to the `—` white-desc form. — **CM-23**
- [ ] Extend suites for any logic touched; commit green.

## Sprint 2 — Namespace migration + Tier-2 layout (tectonic; single coordinated landing)

Coupled: the folder move and TOC re-listing must land together.

- [ ] **S2.1** Add `core/Namespace.lua` (`local addonName, NS = ...`) and `core/ConsumableMaster.lua` (`AceAddon:NewAddon(NS, addonName, …)`, `NS.addon = addon`). — **CM-01, CM-02**
- [ ] **S2.2** Migrate every file header to `local addonName, NS = ...` with a `local KCM = NS` transition alias; delete `_G.KCM = KCM`. — **CM-01**
- [ ] **S2.3** Move sources into `core/`, `modules/`, keep `defaults/`/`settings/`, add `locales/`; declare the tier in `CLAUDE.md`. — **CM-04**
- [ ] **S2.4** Rewrite the TOC file listing with `# Libraries / Locales / Core / Defaults / Modules / Settings` headers in load order. — **CM-07**
- [ ] **S2.5** In-game smoke test (`docs/smoke-tests.md` full suite) — load, macro rewrite, panel open, spec change; confirm no load-order break. Keep tests green.

## Sprint 3 — Schema, locale, options polish

- [ ] **S3.1** Add `locales/enUS.lua` (`NS.L` metatable-fallback); wrap user-facing strings. — **CM-11**
- [ ] **S3.2** Source schema `default =` from defaults constants; route all mutation through `NS.Schema:Set` (validate→write→onChange). — **CM-22**
- [ ] **S3.3** Add the top-right Defaults button per subcategory. — **CM-20**
- [ ] **S3.4** Convert the schema-driven General body to the two-column grid; inset paired buttons to 0.492. — **CM-21**
- [ ] **S3.5** (If pursued) bus-ify the event→pipeline and pipeline→panel edges via `Ka0s_ConsumableMaster_*` messages, each receiver on its own target; document in ARCHITECTURE. — **CM-03**

## Sprint 4 — Debug console (largest net-new; isolate)

- [ ] **S4.1** Move debug flag to `NS.State.debug` (session-only, default off); drop `profile.debug`. — **CM-14**
- [ ] **S4.2** Ship `media/fonts/` monospace TTF + license; add LSM to `libs/` + register at load. — **CM-13**
- [ ] **S4.3** Add `modules/DebugLog.lua` console (window, ScrollingMessageFrame, pure formatters, Copy/Clear, header toggle); route `NS.Debug(tag, …)` into it. — **CM-13**
- [ ] **S4.4** Unit-test `FormatPlain`/`FormatColored`. — **CM-13, CM-17**

## Sprint 5 — Docs

- [ ] **S5.1** Reduce `CLAUDE.md` to a stub; relocate the brief to `docs/`. — **CM-18**
- [ ] **S5.2** Add `## Testing` to README; move `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`; add the message-bus catalogue. — **CM-19**
- [ ] **S5.3** Final pass: `lua tests/run.lua` green, `luacheck .` clean, README `[wow]` badge ↔ TOC Interface lockstep, full in-game smoke suite.

---

### Sequencing rationale

1. **Sprint 0** buys the safety net (tests + lint) that the standard's commit gate assumes — nothing risky lands without it.
2. **Sprint 1** is all mechanical, orthogonal to architecture; clears the cheap MUSTs fast.
3. **Sprint 2** is the one high-blast-radius change, landed atomically behind green tests with the transition alias minimizing per-file churn.
4. **Sprints 3–5** layer feature-facing compliance (schema/locale/options), the console, and docs on the now-standard-shaped foundation.

### Suggested milestone cut

MUST-only compliance is reached at the end of **Sprint 4** (all 19 MUSTs closed). Sprint 3's SHOULDs (CM-22, CM-03) and Sprint 5's docs close the remaining SHOULDs and finish the bundle. CM-09/CM-20 (SHOULD) can slot opportunistically.
