# 02 — Deviations

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit:** 2026-07-12 · **Standard:** v1.0.0 (2026-07-12)

IDs are **stable** — reuse them in future audits for any deviation that persists. Evidence `file:line` for each is in `03_EVIDENCE.md`. Severity is the strongest marker the rule carries (**MUST** / **SHOULD**).

| ID | § | Sev | Deviation | Fix direction |
|----|----|----|-----------|---------------|
| **CM-01** | §4.1, #1 | MUST | Global namespace `_G.KCM`; every file does `local KCM = _G.KCM` instead of the private `local addonName, NS = ...` bootstrap. | Introduce a `Namespace`/bootstrap file; migrate all files to `local addonName, NS = ...`; alias `KCM = NS` during transition, then drop `_G.KCM`. |
| **CM-02** | §4.2 | MUST | `NewAddon` is passed a **string** name, not the `NS` table, so bootstrap and AceAddon are different objects. | `local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceConsole-3.0"); NS.addon = addon`. |
| **CM-03** | §4.4, #19 | MUST | No closed message bus; modules directly read/write each other's tables pervasively. | Stand up a `Ka0s_ConsumableMaster_*` bus (AceEvent embed); convert cross-module wiring (recompute, refresh, spec-change) to named messages; document each in ARCHITECTURE. |
| **CM-04** | §1.2 | MUST | Tier-2 addon in a flat root layout — no `core/`, `modules/`, `locales/`; tier undeclared. | Adopt Tier-2 tree: move engine modules to `core/`+`modules/`, widgets to `modules/`, keep `defaults/`/`settings/`; declare tier in the `CLAUDE.md` stub. |
| **CM-05** | §1.4, #25 | MUST | Logo (`consumemaster.logo.tga`/`.jpg`) filed under `media/screenshots/`, not `media/logos/`. | Move logo pair to `media/logos/`; update `LOGO_TEXTURE` path in `settings/Panel.lua`. |
| **CM-06** | §2.1, #28 | MUST | TOC metadata gaps: no `OptionalDeps`, `X-Standard`, `X-Curse-Project-ID`, `X-Wago-ID` (published); `Author` is `Ka0s` (should be `add1kted2ka0s`); `Category-enUS` = `Action Bars & Buttons` (not in allowed set). | Rewrite metadata block to the §2.1 exact field order and values. |
| **CM-07** | §2.5, #28 | MUST | TOC file listing has no `#`-section headers in `Libraries → Locales → Core → Defaults → Modules → Settings` order. | Add the required `#` section comments; order the listing to match load order. |
| **CM-08** | §2.2, §5.1 | MUST | `schemaVersion` lives in `profile` not `global`; no `Database.lua` migration runner. | Move `schemaVersion` to `global`; add `core/Database.lua` with `RunMigrations()` (empty body OK) called at init. |
| **CM-09** | §3.2, §3.3 | SHOULD | `AceConfig-3.0` vendored + loaded but never used (no Profiles page); `AceTimer-3.0` (mandatory lib) absent (uses `C_Timer`). | Prune AceConfig from `libs/` + `embeds.xml`, or add the Profiles sub-page that would justify it; decide AceTimer (vendor or document the `C_Timer` choice). |
| **CM-10** | §7.4 | MUST | No single shared prefix constant: `PREFIX` defined twice and `[CM]` hand-written inline at 37 call sites. | Define one `NS.PREFIX`; route all chat output through a shared `say()`/print seam; delete the inline literals. |
| **CM-11** | §8.3 | MUST | No `locales/` module, no `NS.L` metatable-fallback table; all strings inline English. | Add `locales/enUS.lua` exporting `NS.L` with key-returning metatable; wrap user-facing strings in `L[...]`. (English-only is fine; the module shell is still required.) |
| **CM-12** | §11, #10 | MUST | No `Compat.lua`; deprecated spec/spell APIs called directly across SpecHelper, SlashCommands, MacroManager, settings/*, KCMItemRow. | Add `core/Compat.lua` exposing `Compat.GetSpecialization*`/`GetSpellInfo`; replace every direct call site. |
| **CM-13** | §12, #18 | MUST | Debug output goes to the chat frame via `print()`; no on-screen debug console (addon has a Settings window → Tier-2 console required). | Add a `DebugLog` console (BackdropTemplate, `ScrollingMessageFrame`, monospace font, timestamp/tag formatters, Copy/Clear) per §12; route `Debug` through it. |
| **CM-14** | §12.5 | MUST | Debug flag persisted in SavedVariables (`profile.debug`), not session-only. | Move the flag to `NS.State.debug` (default off, never in SV); reset on reload/login; `/cm debug on|off` + header toggle set it. |
| **CM-15** | §13 | MUST | No `.pkgmeta` at root. | Add `.pkgmeta` (`package-as`, ignore `audit/`,`docs/`,`tests/`,`reviews/`,…, no `externals:`). |
| **CM-16** | §14 | MUST | No `.luacheckrc` at root. | Add `.luacheckrc` (std lua51, exclude `libs/`/`audit/`/`tests/`, `read_globals` incl. WoW APIs, `ConsumableMasterDB` write global). |
| **CM-17** | §14A, #24 | MUST | No `tests/` harness; not developed test-first. | Add `tests/` (run.lua + loader.lua + wow_mock.lua + `test_*.lua`); cover pure logic first (Classifier, Ranker, Selector, schema validate, ID sentinels, macro-body builders). |
| **CM-18** | §15.2, #26 | MUST | Root `CLAUDE.md` carries the full agent brief instead of a stub. | Reduce `CLAUDE.md` to a stub (tier + standard link + pointer into `docs/`); move the brief to `docs/`. |
| **CM-19** | §15.1, §15.3 | MUST | README missing the mandatory `## Testing` section; `ARCHITECTURE.md` at root, not `docs/`. | Add `## Testing` (harness + luacheck + smoke-tests link); move `ARCHITECTURE.md` under `docs/`. |
| **CM-20** | §6.5 | SHOULD | Subcategory headers omit the required top-right **Defaults** button. | Add the `DEFAULTS_W`-wide Defaults button per subcategory, wired to the panel's reset action. |
| **CM-21** | §6.6, §6.8 | MUST | Panel body renders single-column (AceGUI `List`), not the mandated two-column grid; `ButtonPair` uses `0.5` not `BUTTON_PAIR_REL` (0.492). | Convert the schema-driven body to the paired two-column grid; inset paired action buttons to 0.492. |
| **CM-22** | §4.5 | SHOULD | Schema does not drive AceDB defaults and lacks a unified `Schema:Set(path,value)` validate→write→onChange path. | Reference `default =` from the defaults constants; funnel all mutation through one `Set` helper that validates then fires `onChange`. |
| **CM-23** | §7.4 | SHOULD | `COMMANDS` is a file-local table (not `NS.COMMANDS`); help rows use space-padding, not the `—` white-desc format. | Publish `NS.COMMANDS`; render help rows as `|cffffff00/cm <name>|r — |cffffffff<desc>|r`. |

**Totals:** MUST = **19** (CM-01,02,03,04,05,06,07,08,10,11,12,13,14,15,16,17,18,19,21) · SHOULD = **4** (CM-09,20,22,23).

**Verdict:** major deviations — foundational infra (namespace, tests, lint, packaging, compat, debug console, locale) is absent, though the runtime feature layer and options-panel plumbing are strong and §9.4 is reference-grade.
