# 01 — Current State

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit date:** 2026-07-18
**Standard audited against:** **v2.7.0 (2026-07-17)** — `standards/STANDARDS.md` and every section file it links, fetched from `https://github.com/tusharsaxena/WowAddonStandards` at run time.
**Mode:** read-only compliance snapshot. No addon code, TOC, or config was modified.

This is the second audit of this addon. The first (`docs/audits/2026-07-12/`, against v1.0.0) catalogued 23 deviations (CM-01…CM-23) covering absent foundational infra (namespace, tests, lint, packaging, compat, debug console, locales). **All 23 are remediated** — the addon has since been rebuilt onto the modular layout with the full Ace3 substrate. This run measures the current tree against the much-evolved v2.7.0 standard, several of whose rules (options-ui-§5 Defaults button, options-ui-§11 panel refresh, toc-file-§4 `embeds.xml` ban, debug-logging-§2 shipped font) were themselves drawn from Consumable Master passes.

## Snapshot by standard section

### layout
Modular tree present and correct: `core/` (Namespace, ConsumableMaster, Bus, Constants, Compat, State, Database, Debug, SpecHelper, TooltipCache, WeaponSlots, BagScanner, Classifier, SlashCommands), `defaults/` (Categories + 12 seed files), `settings/` (Panel, General, StatPriority, Category), `locales/enUS.lua`, `modules/` (Ranker, Selector, MacroManager, DebugLog, 4× KCM* widgets), `libs/`, `tests/`, `docs/`, `media/`. Subfolders lowercase; Lua files PascalCase. No file exceeds 1500 LOC (`core/SlashCommands.lua` is the largest at 1279). Media is typed: `media/fonts/`, `media/logos/`, `media/screenshots/`. Compliant.

### toc-file
`ConsumableMaster.toc`: single `## Interface: 120007`, `## Title: Ka0s Consumable Master`, `X-License: MIT`, `X-Standard:` present, `X-Curse-Project-ID: 1522944`. File listing is `#`-sectioned Libraries → Locales → Core → Defaults → Modules → Settings, in dependency order; libraries listed directly (no `embeds.xml`). **Gaps:** the metadata **field order** departs from toc-file-§1 (`Category-enUS` precedes `SavedVariables`/`OptionalDeps`; `DefaultState` precedes `OptionalDeps`), and `X-Wago-ID` is absent though the addon is published (has a Curse project ID).

### library-stack
Vendored under `libs/`, committed: LibStub, CallbackHandler-1.0, AceAddon/AceDB/AceEvent/AceConsole/AceGUI-3.0, LibSharedMedia-3.0. No `externals:`, no lib forks, no suite dependencies. AceTimer is not vendored (the addon uses `C_Timer` directly); AceConfig/AceDBOptions absent (no Profiles page). Compliant.

### architecture
Private `local addonName, NS = ...` bootstrap in every file with a `local KCM = NS` alias; no `_G.KCM`. `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceConsole-3.0")` passes the NS table (`core/ConsumableMaster.lua:6`). Modules published idempotently. Closed bus `KCM.bus` with `Ka0s_ConsumableMaster_*` messages, each receiver on its own `KCM.NewBusTarget()` embed (`core/Bus.lua`). Schema-as-single-source with a `Helpers.SetAndRefresh` validate→write→onChange→refresh seam and `KCM.Schema:Set` (`settings/Panel.lua:724`). Compliant. Note: the custom chat printer is `KCM.Say` (not `NS.Print`), so it does not collide with AceConsole's `:Print` embed.

### savedvariables
`ConsumableMasterDB`; `schemaVersion` in `global`; `core/Database.lua` ships a `RunMigrations()` runner called from `OnInitialize`. Defaults centralised in `KCM.dbDefaults`. Compliant.

### options-ui
`Settings.RegisterCanvasLayoutCategory` parent (About/landing page) + subcategories, registered eagerly from a `PLAYER_LOGIN`/`ADDON_LOADED` bootstrap; bodies build lazily on `OnShow`. Landing page renders logo + tagline (`GameFontHighlight`) + "Slash Commands" heading + one row per `COMMANDS` entry. Two-column grid (`Helpers.Grid`), `BUTTON_PAIR_REL = 0.492`, always-visible scrollbar patch, exact layout constants. **Defaults button is an AceGUI `Button`** (options-ui-§5, `settings/Panel.lua:205`). **Panel refresh is in-place / on-screen-only** (options-ui-§11): `RefreshScalars` runs per-widget updater closures, `RefreshAllPanels` rebuilds only `IsShown()` panels and flags the rest dirty (`settings/Panel.lua:661,685`). The v2.7.0 items are remediated. **Gap:** the combat-lockdown open notice is neither grey nor the canonical wording (options-ui-§2).

### standalone-windows / preview-mode
No standalone data-browser window (the addon's surfaces are the Settings panel and the debug console). Preview-mode: N/A — the addon writes macros, it has no positionable on-screen display.

### slash-commands
AceConsole `/cm` + `/consumablemaster`; schema-driven `list`/`get`/`set`; ordered `COMMANDS` table published as `KCM.COMMANDS`; help generated from it; unknown verb prints notice + help. `version` verb present. **Gaps:** many printed lines carry a **trailing colon** (§4); `list`/`get`/`set` output has **no mandated colour scheme** (§5); the `version` verb prints `version <v>` rather than `<tag> v<version>` and reads only the in-code constant (§3); and chat output is **not funnelled through one shared secret-safe printer** — the `[CM]` tag is hand-written at ~32 direct `print()` sites (§4, events-frames-taint-§8).

### localization
`locales/enUS.lua` exports `KCM.L` with a key-returning metatable; English-only shell is compliant. **Tracked deviation (documented):** `core/TooltipCache.lua` parses English tooltip *text* for heal/mana/stat magnitudes (localization-§4 / anti-pattern #37). Item/weapon *classification* keys on locale-independent `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`). The deviation is recorded in `docs/scope.md:19` and `docs/agent-context.md` as intentional, with full tooltip localization planned later.

### events-frames-taint
AceEvent throughout; `MacroManager` is the sole caller of `CreateMacro`/`EditMacro`, guarded on `InCombatLockdown()` with a `PLAYER_REGEN_ENABLED` flush (`core/ConsumableMaster.lua:372`). Recompute coalesced via `C_Timer.After(0,…)`. **Gap:** the secret-safe stringifier `KCM.SafeToString` probes `tostring` under `pcall` — but a combat "secret" *survives* `tostring`, so the probe is ineffective; the standard requires probing `table.concat` (events-frames-taint-§8).

### public-api
No public API surface exposed. N/A.

### compat
`core/Compat.lua` is the single seam over spec/spell APIs (`GetSpecialization*`, `GetSpellName`), modern-first with legacy fallback. No `WOW_PROJECT_ID` branching. Compliant.

### debug-logging
On-screen console `modules/DebugLog.lua`: `BackdropTemplate` on DIALOG strata, 700×344, `UISpecialFrames`, `ScrollingMessageFrame` `SetMaxLines(500)`, shipped **JetBrains Mono** (registered with LSM, `OFL.txt` vendored) at 10pt, pure `FormatPlain`/`FormatColored` formatters, Copy/Clear. `SetEnabled` seam: colour-coded chat ack (`40ff40`/`ff4040`), `[Debug] logging enabled/disabled` at both transitions via raw append, `[Init]` session summary on enable. Session-only flag in `KCM.State.debug`. Coverage traces lifecycle/scan/calc/set; scan pass coalesced to one summary line behind the gate; `[Set]` logged once at the write seam. Compliant.

### packaging / lint / testing
`.pkgmeta` with `package-as`, ignore lists (`docs`, `tests`, `_dev`), no `externals:`. `.luacheckrc` std lua51. `tests/` headless harness with `--list` mode; `docs/test-cases.md` generated; README `[tests]` badge `137/137`. **Both gates green at audit time:** `lua5.1 tests/run.lua` → 137 passed / 0 failed; `luacheck .` → 0 warnings / 0 errors in 40 files. Compliant.

### documentation
Root `README.md` (player-facing, five-badge row in canonical order, logo, description, Screenshots, Usage, `## How picking & ranking works`, FAQ, Troubleshooting, Issues, Version History), stub `CLAUDE.md`, `LICENSE`. `docs/` quartet present: `agent-context.md`, `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`, plus `test-cases.md` and topic docs. **Gap:** the CLAUDE.md standards section is titled `## Standard — read first` rather than the canonical `## Standards compliance (read first)` (documentation-§2/§6, anti-pattern #34).

### audit-review-history / versioning-git / naming-cheatsheet
Frozen dated bundles under `docs/audits/` and `docs/reviews/`. Semver `1.5.0` consistent across TOC and `KCM.VERSION`. Naming conventions followed. Compliant.

## Headline

The addon is **broadly compliant** and structurally reference-grade — every v1.0.0 gap is closed and the two v2.7.0 options-panel rules it inspired are correctly implemented. The residual deviations are concentrated in the **chat-output seam** (single secret-safe printer, colour scheme, trailing colons, secret detection) and a handful of **contained edits** (TOC field order, combat notice wording, CLAUDE.md heading), plus the one **documented tracked deviation** (English tooltip parsing).
