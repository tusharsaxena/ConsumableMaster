# 03 — Evidence

`file:line` citations backing every deviation in `02_DEVIATIONS.md` and the key compliance claims in `01_CURRENT_STATE.md`. All paths are relative to the repo root.

---

## CM-01 — global namespace `_G.KCM` (§4.1, #1)

- `Core.lua:5` — `local KCM = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")`
- `Core.lua:6` — `_G.KCM = KCM`
- `local KCM = _G.KCM` at file heads: `Debug.lua:3`, `Classifier.lua:20`, `BagScanner.lua:13`, `SlashCommands.lua:16`, `settings/Panel.lua:14`, and the remaining modules (SpecHelper, TooltipCache, Ranker, Selector, MacroManager, KCM* widgets, settings/*).
- No `local addonName, NS = ...` header exists in any source file (grep for `NS = ...` returns nothing outside libs).

## CM-02 — NewAddon passed a string, not NS (§4.2)

- `Core.lua:5` — first arg is the string `ADDON_NAME` (`= "ConsumableMaster"`, `Core.lua:3`), not a namespace table.

## CM-03 — no message bus; direct cross-module calls (§4.4, #19)

- `Core.lua:91` — `if not KCM.Categories or not KCM.Selector or not KCM.MacroManager then`
- `Core.lua:103,106,107` — direct `KCM.MacroManager.SetCompositeMacro(...)`, `KCM.Selector.PickBestForCategory(...)`, `KCM.MacroManager.SetMacro(...)`.
- `Core.lua:151-155` — direct `KCM.Options.RequestRefresh()` / `KCM.Options.Refresh()`.
- No `SendMessage`/`RegisterMessage` for a `Ka0s_ConsumableMaster_*` bus anywhere (grep).

## CM-04 — flat Tier-2 layout, tier undeclared (§1.2, §1)

- Root `.lua` files (non-lib): Core, Debug, SpecHelper, TooltipCache, BagScanner, Classifier, Ranker, Selector, MacroManager, KCMIconButton, KCMScoreButton, KCMMacroDragIcon, KCMItemRow (13) + `settings/*`×4 + `defaults/*` — >8 source files, Tier-2 threshold (§1.1).
- No `core/` or `modules/` directory (repo `ls`). `CLAUDE.md` states "Ace3 throughout" but does not declare Tier 1/2.

## CM-05 — logo mis-filed (§1.4, #25)

- `media/screenshots/consumemaster.logo.tga` and `media/screenshots/consumemaster.logo.jpg` — logo assets under `screenshots/`, not `media/logos/`.
- `settings/Panel.lua:48` — `LOGO_TEXTURE = [[Interface\AddOns\ConsumableMaster\media\screenshots\consumemaster.logo.tga]]`.

## CM-06 — TOC metadata gaps (§2.1, #28)

- `ConsumableMaster.toc:1-10` — the entire metadata block:
  - `:4` `## Author: Ka0s` (should be `add1kted2ka0s`).
  - `:9` `## Category-enUS: Action Bars & Buttons` (not in `Combat|Group|Auction|Chat|UI|Misc`).
  - No `## OptionalDeps:`, `## X-Standard:`, `## X-Curse-Project-ID:`, `## X-Wago-ID:` lines present.
- Published-status evidence: `README.md:4` — `![CurseForge Version](https://img.shields.io/curseforge/v/1522944)` → `X-Curse-Project-ID` is mandatory (§2.1).

## CM-07 — TOC file listing structure (§2.5, #28)

- `ConsumableMaster.toc:12-55` — listing loads `embeds.xml` then bare filenames grouped by prose comments, with **no** `# Libraries` / `# Locales` / `# Core` / `# Defaults` / `# Modules` / `# Settings` section headers.

## CM-08 — schemaVersion placement + no migration runner (§2.2, §5.1)

- `Core.lua:27` — `schemaVersion = 1` sits inside `profile = { ... }`, not `global`.
- No `Database.lua` / `core/Database.lua` file exists; no `RunMigrations` function (grep).

## CM-09 — AceConfig dead weight / AceTimer absent (§3.2, §3.3)

- `embeds.xml:11` (approx) — `<Include file="libs\AceConfig-3.0\AceConfig-3.0.xml"/>` loaded.
- No addon-code `LibStub("AceConfig-3.0")` / `AceConfigDialog` / `AceDBOptions` call (grep shows only lib-internal references).
- `Core.lua:166` — `C_Timer.After(0, ...)` used instead of AceTimer; AceTimer not in `libs/` or `embeds.xml`.

## CM-10 — no shared prefix constant (§7.4)

- `Debug.lua:6` — `local PREFIX = "|cff00ffff[CM]|r "`.
- `SlashCommands.lua:19` — `local PREFIX = "|cff00ffff[CM]|r "` (duplicate).
- Inline `[CM]` literals (37 occurrences), e.g. `settings/Panel.lua:100,240,399,494,556,585,603,724,803,818`, `Core.lua` warning path, etc.

## CM-11 — no locale module (§8.3)

- No `locales/` directory; no `NS.L` / metatable-fallback table (grep for `NS.L` returns nothing outside libs).
- `CLAUDE.md` documents English-only scope ("do not introduce localization plumbing") — the §8.3 `enUS.lua` shell is still required.

## CM-12 — no Compat; direct deprecated API calls (§11, #10)

- `SpecHelper.lua:40` — `GetSpecialization and GetSpecialization()`; `:43` `GetSpecializationInfo(specIndex)`; `:57` `GetSpecializationInfoForClassID(...)`.
- `SlashCommands.lua:126,131,166,168` — `GetSpecializationInfoForClassID(...)`.
- `settings/StatPriority.lua:79,81` — `GetSpecializationInfoForClassID(...)`.
- `MacroManager.lua:63,64` — `GetSpellInfo(spellID)` fallback.
- `settings/Category.lua:63,64` — `GetSpellInfo(id)` fallback.
- No `Compat.lua` exists.

## CM-13 — debug to chat, no console (§12, #18)

- `Debug.lua:37-42` — `function KCM.Debug.Print(fmt, ...)` → `print(PREFIX .. msg)`.
- No `DebugLog` module, `ScrollingMessageFrame`, or `<Addon>DebugWindow` frame (grep).
- Addon has a Settings window (`settings/Panel.lua`), so the Tier-2 console is mandatory (§12; §12.7 fallback is Tier-1-only).

## CM-14 — debug flag persisted (§12.5)

- `Core.lua:29` — `debug = false` declared in `profile` (SavedVariables).
- `Debug.lua:9` — `return KCM.db and KCM.db.profile and KCM.db.profile.debug == true`.
- `Debug.lua:28` — `KCM.db.profile.debug = nextValue` (writes SV). §12.5 requires session-only `NS.State.debug`.

## CM-15 — no `.pkgmeta` (§13)

- Repo root listing shows no `.pkgmeta` (missing-infra check confirmed absent).

## CM-16 — no `.luacheckrc` (§14)

- Repo root listing shows no `.luacheckrc` (missing-infra check confirmed absent).

## CM-17 — no tests harness (§14A, #24)

- No `tests/` directory (missing-infra check confirmed absent). `docs/smoke-tests.md` is in-game only.

## CM-18 — CLAUDE.md is a full brief (§15.2, #26)

- `CLAUDE.md` (~70 lines) contains "What this addon is", "Hard rules", "Module publishing pattern", "Working environment", "Response style", and a "Doc index" table — the full agent brief, not a stub pointer.

## CM-19 — README missing Testing; ARCHITECTURE at root (§15.1, §15.3)

- `README.md` section headers (grep `^## `): Screenshots, Usage, How picking & ranking works, FAQ, Troubleshooting, Issues and feature requests, Version History — **no `## Testing`**.
- `ARCHITECTURE.md` present at repo root; `docs/ARCHITECTURE.md` does **not** exist (`ls` error).

## CM-20 — no Defaults button on subcategories (§6.5)

- `settings/Panel.lua:157-159` — comment "No Defaults button — every panel keeps its reset action inline"; `buildHeader` (`:162-186`) renders only title + divider, no top-right button.

## CM-21 — single-column body / ButtonPair 0.5 (§6.6, §6.8)

- `settings/Panel.lua:369` — `scroll:SetLayout("List")` (single-column).
- `settings/Panel.lua:520-521` — `makeButton(row, leftSpec, 0.5)` / `makeButton(row, rightSpec, 0.5)` (should be `BUTTON_PAIR_REL` 0.492).
- `settings/Panel.lua:449-470,472-476` — `RenderField` adds one widget full-width/relative, no paired-row flushing.

## CM-22 — schema not driving defaults / no unified Set (§4.5)

- `Core.lua:25-61` — defaults hardcoded in `KCM.dbDefaults`, independent of the schema.
- `settings/Panel.lua:577-606` — schema rows carry `default =` locally but are not sourced from the defaults table.
- `settings/Panel.lua:76-81` — `Helpers.Set` writes directly with no validate step; `onChange` fired separately by callers.

## CM-23 — COMMANDS file-local; help format (§7.4)

- `SlashCommands.lua:1147` — `local COMMANDS = { ... }` (file-local, not `NS.COMMANDS`).
- `SlashCommands.lua:1222-1229` — `printHelp` renders rows with `string.rep(" ", ...)` padding, not the `—` em-dash white-desc format.

---

## Compliance evidence (claims in 01)

- §9.4 firewall: `Core.lua:177-184` (routing note), `Core.lua:355-362` (event registration all via handlers → `RequestRecompute`); `MacroManager` is sole `CreateMacro`/`EditMacro` caller (`docs/macro-manager.md`, `CLAUDE.md` hard rule).
- §6.1/§6.9 eager register + lazy body: `settings/Panel.lua:695-729` (`registerPanel`), `:822-833` (bootstrap on `PLAYER_LOGIN`/`ADDON_LOADED`), `:228-247` (`SetRenderer` lazy `OnShow`).
- §6.10 always-show scrollbar: `settings/Panel.lua:265-361`.
- §6.2 combat gate: `settings/Panel.lua:234-242`, `:799-805`.
- §7.1/§7.2 AceConsole: `Core.lua:65-66`.
- §7.3 dispatch + unknown-verb: `SlashCommands.lua:1246-1256`.
- §2.3 single Interface / §2.1 MIT: `ConsumableMaster.toc:1`, `:10`.
- §17 semver + lockstep: `Core.lua:8`, `ConsumableMaster.toc:5`, `README.md:3` (`[wow]` badge), `README.md` Version History table.
