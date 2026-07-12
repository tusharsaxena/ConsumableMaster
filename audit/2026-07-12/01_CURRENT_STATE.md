# 01 — Current State

**Addon:** Ka0s Consumable Master (`ConsumableMaster`)
**Audit date:** 2026-07-12
**Standard audited against:** Ka0s WoW Addon Standard **v1.0.0 (2026-07-12)** — `standards/01_STANDARD.md` @ `github.com/tusharsaxena/WowAddonStandards`, playbook `AUDIT.md` (same repo).
**Deviation-ID prefix:** `CM-` (first audit; establish and reuse).
**Version at audit:** `1.4.0` (`Core.lua:8`, `ConsumableMaster.toc:5`).

This is a **read-only** snapshot. No addon source was modified.

---

## Tier classification

**Effective tier: Tier 2 (modular).** The addon ships **~19 source `.lua` files** excluding `libs/`, `defaults/`, `settings/`, `docs/` (Core, Debug, SpecHelper, TooltipCache, BagScanner, Classifier, Ranker, Selector, MacroManager, KCMIconButton, KCMScoreButton, KCMMacroDragIcon, KCMItemRow, plus `settings/*` × 4 and `defaults/*` data). Well over the 8-file Tier-1 ceiling (§1.1), so Tier-2 rules apply. The tier is **not declared** in `CLAUDE.md` as §1 requires.

---

## Layout

- **Root-flat source, no Tier-2 folder split.** All engine/UI modules sit at repo root; only `defaults/` and `settings/` are foldered. There is **no `core/`, `modules/`, or `locales/`** (§1.2). `ARCHITECTURE.md` sits at **root**, not `docs/` (§15).
- **`libs/`** vendored and committed: LibStub, CallbackHandler-1.0, AceAddon/AceEvent/AceDB/AceConsole/AceGUI-3.0, AceConfig-3.0 (§3.3 satisfied for what is used; AceConfig is dead weight — see §3 below).
- **`media/`** holds `media/screenshots/` only; the **logo** (`consumemaster.logo.tga` + `.jpg`) is filed under `media/screenshots/`, not the required `media/logos/` (§1.4). No loose files directly in `media/`.
- **`reviews/2026-05-02/`** holds a prior `wow-addon:review` bundle (separate skill; not a standards audit). No prior `audit/` folder — this is the first.

## TOC (`ConsumableMaster.toc`)

- Single `## Interface: 120007` (§2.3 ✓), `## X-License: MIT` (§2.1 ✓), single `## SavedVariables: ConsumableMasterDB` (§2.2 ✓).
- **Field gaps (§2.1):** no `## OptionalDeps:`, no `## X-Standard:`, no `## X-Curse-Project-ID` / `## X-Wago-ID` (addon **is** published — CurseForge badge in README), `## Author: Ka0s` (standard specifies `add1kted2ka0s`), `## Category-enUS: Action Bars & Buttons` (not in the allowed `Combat|Group|Auction|Chat|UI|Misc` set).
- **File listing** loads `embeds.xml` then bare filenames with **no `#`-section headers** in the `Libraries → Locales → Core → Defaults → Modules → Settings` order (§2.5).

## Library stack

- Mandatory Ace3 libs vendored (§3.1). `AceTimer-3.0` is **not** vendored/used — the addon uses `C_Timer` directly (`Core.lua:166`).
- **AceConfig-3.0 is loaded (`embeds.xml`) but never `LibStub("AceConfig…")`d** in addon code — there is no Profiles sub-page, so it is prunable dead weight (§3.2/§3.3).
- No forked Ace libs (§3.5 ✓). Self-contained; no suite dependency (§3.6 ✓).

## Architecture / namespace

- **Global namespace.** `Core.lua:6` does `_G.KCM = KCM`; every file starts `local KCM = _G.KCM`. The standard mandates the private `local addonName, NS = ...` bootstrap and forbids `_G[addonName]` (§4.1, anti-pattern #1). `NewAddon` is called with a **string name**, not the `NS` table (`Core.lua:5`; §4.2).
- **No message bus.** Modules call each other's tables directly (`KCM.Selector.*`, `KCM.MacroManager.*`, `KCM.Options.*`, `KCM.Pipeline.*` throughout `Core.lua`). §4.4 mandates a closed `Ka0s_<Addon>_*` message bus for Tier 2 (anti-pattern #19).
- **Schema-as-single-source (§4.5): partially present.** `KCM.Settings.Schema` drives the General panel widgets and `/cm list|get|set`, with a boot-time `ValidateSchema()` (`settings/Panel.lua:103`). But the schema does **not** drive AceDB defaults (defaults live separately in `KCM.dbDefaults`, `Core.lua:25`) and mutations go through `Helpers.Set` **without** a unified validate→write→onChange path.
- **Protected-API firewall (§9.4): exemplary.** `MacroManager` is the sole caller of `CreateMacro`/`EditMacro`; every event handler routes through `Pipeline.RequestRecompute` and keeps Selector/Ranker/Classifier pure (`Core.lua:177-362`). This addon is the standard's own reference implementation for §9.4.

## SavedVariables / AceDB

- `AceDB:New("ConsumableMasterDB", …, true)` (`Core.lua:64`) — profile model ✓.
- `schemaVersion` is declared inside **`profile`** (`Core.lua:27`), not the **global** namespace (§5.1). There is **no `Database.lua` migration runner** (§2.2/§5.1 MUST, even if empty).

## Options UI (§6)

Strong compliance on the hard parts:
- Canvas category via `Settings.RegisterCanvasLayoutCategory` + `RegisterAddOnCategory`, **registered eagerly** from a `PLAYER_LOGIN`/`ADDON_LOADED(Blizzard_Settings)` bootstrap with a **lazy body** in `OnShow` (`settings/Panel.lua:695-833`; §6.1/§6.9 ✓).
- Landing "About" page with logo + notes + slash-command list generated from `GetCommandSummary()` (`settings/Panel.lua:622-678`; §6.5 ✓).
- Breadcrumb subcategory header with atlas chevron (`settings/Panel.lua:162-186`; §6.5 ✓).
- Always-visible/inert scrollbar rebind (`settings/Panel.lua:265-361`; §6.10 ✓).
- Combat-lockdown gate on panel open **and** on `OnShow` (`settings/Panel.lua:230-247`, `799-805`; §6.2 ✓).

Gaps: subcategory headers **omit the top-right Defaults button** (`settings/Panel.lua:157-159` explicitly "No Defaults button"; §6.5). Body uses AceGUI **List** (single column), not the mandated **two-column grid**; `ButtonPair` uses `0.5` rather than `BUTTON_PAIR_REL` 0.492 (`settings/Panel.lua:514-523`; §6.6/§6.8).

## Slash commands (§7)

- AceConsole `:RegisterChatCommand("cm", …)` + full-name alias (`Core.lua:65-66`; §7.1/§7.2 ✓).
- Ordered `COMMANDS` table drives dispatch, help is generated from it, unknown verb prints `Unknown command` + help (`SlashCommands.lua:1147-1256`; §7.3 ✓, no if/elseif chain).
- `/cm list|get|set` are schema-driven (§7.3 ✓).
- Gaps: the table is a **file-local `COMMANDS`**, not `NS.COMMANDS`; help rows use space-padding rather than the `|cffffff00/<slash> <name>|r — |cffffffff<desc>|r` em-dash form (`SlashCommands.lua:1222-1229`; §7.4).

## Chat tag / prefix (§7.4)

**No single shared prefix constant.** `PREFIX = "|cff00ffff[CM]|r "` is defined **twice** (`Debug.lua:6`, `SlashCommands.lua:19`) and the literal `[CM]` tag is **hand-written inline at 37 call sites** across `settings/Panel.lua`, `Core.lua`, and others. §7.4 mandates one shared `NS.PREFIX` and forbids per-call-site hand-writing.

## Localization (§8)

**None.** There is no `locales/` folder, no `NS.L`, no metatable-fallback locale table. All user strings are inline English. `CLAUDE.md` documents "English-only … do not introduce localization plumbing" as a scope decision, but §8.3 MUST ship at least an `enUS.lua` shell.

## Compat / deprecated APIs (§11)

**No `Compat.lua`.** Deprecated spec/spell APIs are called **directly across many modules**: `GetSpecialization`/`GetSpecializationInfo` (`SpecHelper.lua:40,43,57`), `GetSpecializationInfoForClassID` (`SlashCommands.lua:126-168`, `settings/StatPriority.lua:79-81`), `GetSpellInfo` (`MacroManager.lua:63-64`, `settings/Category.lua:63-64`). §11 requires all such calls routed through `Compat`. (The standard's §11 text explicitly flags "a current Tier-2 addon still calls `GetSpecialization`/`GetSpecializationInfo` directly in two modules" — this addon.)

## Debug / logging (§12)

`Debug.lua` routes debug output to **chat via `print()`** (`Debug.lua:37-42`), gated on `KCM.db.profile.debug`. The addon has a Settings window (Tier 2), so §12 requires a **dedicated on-screen debug console** (anti-pattern #18). Additionally the debug flag is **persisted in SavedVariables** (`Core.lua:29`, `Debug.lua:9`), whereas §12.5 mandates it be **session-only** (`NS.State.debug`, never in SV).

## Packaging / lint / tests

- **No `.pkgmeta`** (§13 MUST).
- **No `.luacheckrc`** (§14 MUST).
- **No `tests/` harness** — no headless suite, no TDD scaffolding (§14A MUST, anti-pattern #24). `docs/smoke-tests.md` covers in-game checks only.

## Docs (§15)

- Root ships `README.md`, `CLAUDE.md`, `LICENSE` — **plus** `ARCHITECTURE.md` (should be `docs/ARCHITECTURE.md`).
- **`CLAUDE.md` is a full agent brief** (~70 lines of working notes, hard rules, module publishing pattern, doc index), not the required **stub** (§15.2, anti-pattern #26).
- README follows the canonical order (H1 → badges → logo → description+table → Screenshots → Usage → How it works → FAQ → Troubleshooting → Issues → Version History) but is **missing the mandatory `## Testing` section** (§15.1 #11). Images reference remote forgecdn URLs rather than local `media/`.
- `docs/` is rich (module-map, pipeline, data-model, etc.). No `TODO.md` present (§15.4 ✓).

## Versioning (§17)

Semver `1.4.0` in TOC + `Core.lua` + README badge, dated Version History table (§17 ✓). Single Interface line kept in lockstep (§2.3 ✓).

---

## Compliance highlights (no deviation)

- §9.4 protected-macro firewall — **reference-grade**.
- §6.1/§6.9 eager category registration + lazy body; §6.10 always-show scrollbar; §6.2 combat gating.
- §7.1–§7.3 AceConsole + ordered-`COMMANDS` schema-driven dispatch, generated help, unknown-verb fallback.
- §2.3 single Retail Interface line; §2.1 `X-License: MIT`; §3.5 no forked Ace; §3.6 self-contained; §17 semver.
