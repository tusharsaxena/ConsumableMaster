# Architecture

Orient-yourself map for **Ka0s Consumable Master**. This file is the high-level index; topic detail lives alongside it in `docs/`. Ka0s WoW Addon Standard.

## What it does

Fifteen account-wide global macros (`KCM_FOOD`, `KCM_DRINK`, `KCM_HP_POT`, `KCM_MP_POT`, `KCM_HS`, `KCM_VANTUS`, `KCM_FLASK`, `KCM_CMBT_POT`, `KCM_STAT_FOOD`, `KCM_WPN_ENCH`, `KCM_AUG_RUNE`, `KCM_BLOODLUST`, `KCM_BATTLE_REZ`, `KCM_HP_AIO`, `KCM_MP_AIO`) whose bodies auto-rewrite to point at the best consumable currently in your bags. Thirteen macros run a per-category scorer; two are composites that compose other categories' picks via combat conditionals. Identified by name, never by slot — coexists with every other macro in the user's account-wide pool.

Those macros are also hosted on a **CM-only macro bar** (on by default) — one secure slot per category, each with a hover flyout listing every currently-usable candidate in that category. It is the addon's only protected-frame surface; see [macro-bar.md](./macro-bar.md).

## Namespace & promotion

- **Private namespace, no globals.** Every file begins `local addonName, NS = ...` — WoW hands the same private table to each file. `core/Namespace.lua` loads first and names it (`NS.name`). There is **no `_G.KCM`**; the only shared handle is a per-file transition alias `local KCM = NS`, so the tree's internal `KCM.*` references resolve to the private namespace.
- **AceAddon promotion.** `core/ConsumableMaster.lua` calls `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceConsole-3.0")` and stores `NS.addon`. Event handlers are dispatched from `OnEnable`, so their bodies may reference modules that load later.

## Layout

| Folder | Holds |
|--------|-------|
| `core/` | Namespace, AceAddon entry (`ConsumableMaster.lua`) + recompute pipeline, Bus, Compat, Constants, State, Database, Debug, the pure engine (SpecHelper, TooltipCache, BagScanner, Classifier, WeaponSlots), the macro bar's pure halves (MacroDisplay, MacroBarModel, MacroBarLayout), the LSM widget fixup (LSMPatch), the `/cm dump` targets (SlashDump) and the slash **verb bodies** (SlashCommands) — the dispatcher itself is `settings/Slash.lua` |
| `modules/` | Ranker, Selector, MacroManager, DebugLog console, PerfSetup (the A/B capture harness), the macro bar (MacroBar, MacroBarButton, MacroBarFlyout), the `KCM*` AceGUI widgets |
| `defaults/` | Seed itemID lists + the category table (data, not code) |
| `settings/` | Options panel + per-tab pages |
| `locales/` | `enUS.lua` (`KCM.L`) — English only |

`ConsumableMaster.toc` is the load-order source of truth (dependency order, not alphabetical).

## Subsystems at a glance

```
WoW events ─▶ KCM.bus (RECOMPUTE) ─▶ Core.Pipeline ─▶ Selector ─▶ Ranker     ─▶ candidate score
                                          │              │     ─▶ Classifier ─▶ auto-discovery match
                                          │              │
                                          │              ├─▶ pick (first owned id)
                                          │              └─▶ PickBestForSlot(16/17) ─▶ per-hand pick
                                          │                    (perHand cats; WeaponSlots affinity filter)
                                          │
                                          ├─▶ MacroManager.SetMacro / SetWeaponEnchantMacro
                                          │                 / SetCompositeMacro
                                          │     └─▶ CreateMacro / EditMacro   (the only protected-API caller)
                                          │
                                          ├─▶ KCM.bus (PANEL_REFRESH)    ─▶ Options panel
                                          └─▶ KCM.bus (MACROBAR_REFRESH) ─▶ Macro bar (on by default; can be switched off)

  AceDB (one account-wide profile)  ──  Options panel + /cm slash CLI
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-module APIs + roles | `core/*.lua`, `modules/*.lua`, `settings/*.lua` | [module-map.md](./module-map.md) |
| Recompute pipeline + score cache + events | `core/ConsumableMaster.lua` (`KCM.Pipeline`) | [pipeline.md](./pipeline.md) |
| AceDB schema + opaque IDs + discovered GC | `core/ConsumableMaster.lua` (`KCM.dbDefaults`, `KCM.ID`), `core/Database.lua`, `modules/Selector.lua` | [data-model.md](./data-model.md) |
| MacroManager (body builders, composite assembly, combat deferral, action-bar icons) | `modules/MacroManager.lua` | [macro-manager.md](./macro-manager.md) |
| Tooltip parsing + Midnight gotchas | `core/Classifier.lua`, `core/TooltipCache.lua` | [midnight-quirks.md](./midnight-quirks.md) |
| Settings panel + slash CLI + schema layer | `settings/*.lua` (incl. `settings/Slash.lua`, the dispatcher), `libs/LibKa0s/Options.lua`, `core/SlashCommands.lua` + `core/SlashDump.lua` (verb bodies), `libs/LibKa0s/Slash.lua` | [debug.md](./debug.md), [file-index.md](./file-index.md) |
| Message bus | `core/Bus.lua` | Catalog below |
| Compat seam (spec + spell APIs) | `core/Compat.lua` | [module-map.md](./module-map.md) |
| Debug console | `modules/DebugLog.lua`, `libs/LibKa0s/DebugLog.lua`, `core/State.lua` | [debug.md](./debug.md) |
| Perf A/B capture (`/cm perf`) | `modules/PerfSetup.lua`, `libs/LibKa0s/Perf.lua`, `libs/LibKa0s/PerfPanel.lua` | [debug.md](./debug.md) |
| Optional CM-only macro bar (secure slots, layout, visibility) | `core/MacroBar*.lua`, `core/MacroDisplay.lua`, `modules/MacroBar*.lua`, `settings/MacroBar.lua` | [macro-bar.md](./macro-bar.md) |
| Per-file responsibility map | — | [file-index.md](./file-index.md) |
| Routine recipes (add category, refresh seeds, fix misclassification) | — | [common-tasks.md](./common-tasks.md) |
| Headless gate (tests + luacheck, the vendored-LibKa0s copy diff, TDD policy, badge sync) | `tests/` | [testing.md](./testing.md) |
| Contributor toolchain — what to install to build, run, test or release | — | [../DEPENDENCIES.md](../DEPENDENCIES.md) |
| Automated test records (produced at release — recorded, not a gate) | — | [automated-tests/](./automated-tests/) |
| Smoke-test playbook (quick + full + targeted) | — | [smoke-tests.md](./smoke-tests.md) |
| In/out scope + resolved design decisions | — | [scope.md](./scope.md) |
| Test-case inventory (generated — the authoritative pass count) | `tests/` | [test-cases.md](./test-cases.md) |
| Seed reference + patch-day refresh procedure | `defaults/` | [../defaults/README.md](../defaults/README.md) |
| Pending-item decision ledger (deferred / closed, with rationale) | — | [pending/LEDGER.md](./pending/LEDGER.md) |

## Message-bus catalog

Cross-module control flow that crosses feature boundaries travels over the closed bus (`core/Bus.lua`), never by reaching into another module's tables. Pure-function queries (MacroManager asking Selector/Ranker/Classifier for data) stay direct synchronous calls — they are data reads, not control flow.

`KCM.bus` is an AceEvent-embed. **Every receiver owns its own target** via `KCM.NewBusTarget()`; two subscriptions never share one table. `KCM.MSG` names each message:

| `KCM.MSG.*` | Wire name | Direction | Purpose |
|-------------|-----------|-----------|---------|
| `RECOMPUTE` | `Ka0s_ConsumableMaster_Recompute` | event / UI layer → pipeline | Request a pick recompute. The pipeline owns the **only** subscription (registered at load in `Bus.lua`) and forwards to `Pipeline.RequestRecompute`, which coalesces to one pass per frame. Carries an optional `reason` string. |
| `PANEL_REFRESH` | `Ka0s_ConsumableMaster_PanelRefresh` | pipeline → options panel | The pipeline finished a pass; any open settings page does a debounced rebuild against the new picks. |
| `SPEC_CHANGED` | `Ka0s_ConsumableMaster_SpecChanged` | spec change → options panel | Active spec changed; the Stat Priority page retracks to the new spec when auto-tracking. |
| `MACROBAR_REFRESH` | `Ka0s_ConsumableMaster_MacroBarRefresh` | pipeline → macro bar | The pipeline finished a pass; the optional macro bar repaints slot icons + counts. Undebounced (unlike `PANEL_REFRESH`) because a live on-screen bar should track the macro it just rewrote. |

## Invariants worth not breaking

- **`MacroManager` is the only caller of `CreateMacro` / `EditMacro`.** Selector, Ranker, Classifier, BagScanner, TooltipCache, SpecHelper must all stay pure (no protected APIs) so the pipeline can run in combat without taint.
- **Macros are always identified by name**, never by slot index. `perCharacter=false` puts them in the account-wide pool. The addon never calls `DeleteMacro` on a `KCM_*` macro.
- **Seed lists are data, not code.** Updating a `defaults/Defaults_*.lua` is a zero-migration upgrade — `added`/`discovered`/`blocked` live in SavedVariables and union with the seed at runtime.
- **English-only — tracked deviation** (localization-§4 / anti-pattern #37; see [scope.md](./scope.md)). Classification keys on the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`), so category and weapon-affinity detection work on every client. The remaining English dependency is TooltipCache's tooltip-TEXT parsing (heal/mana/stat magnitudes, the `Augment Rune` marker, weapon-application effect). `locales/enUS.lua` is a shell, not localization plumbing; full tooltip localization is a planned future release.
- **Private-namespace publishing pattern:** every file does `local addonName, NS = ...; local KCM = NS; KCM.Foo = KCM.Foo or {}; local F = KCM.Foo`. The `or {}` is load-bearing — another file may have reached `KCM.Foo` first, and overwriting it drops whatever it published. Never let the local shadow the namespace (`local KCM = {}` breaks everything downstream). Public API goes on `F`; helpers stay `local` to the file.
- **Blizzard API churn goes through `core/Compat.lua`.** `KCM.Compat` wraps the spec + spell APIs Blizzard keeps renaming (`GetSpecialization*`, `GetSpecializationInfoForClassID`, spell-name lookup) and the client's `issecretvalue` (`Compat.IsSecret`). SpecHelper, SlashCommands, MacroManager, MacroDisplay and the settings pages call through `Compat.*` and never the raw global, so a rename is one edit. Any gate over client data a combat restriction could turn secret must ask `IsSecret` *before* comparing ([midnight-quirks.md](./midnight-quirks.md#secret-values)).
- **Reset is centralized.** `KCM.ResetAllToDefaults(reason)` (`core/ConsumableMaster.lua`) is the only wipe-and-resync path; the Options panel's "Reset all priorities" button and `/cm resetall`'s StaticPopup both delegate to it. Don't add a third. `/cm reset path` is unrelated — the library's one-row schema reset (LIBKA0S-12), which never touches `categories` or `statPriority` ([data-model.md](./data-model.md)).
- **All addon chat carries the cyan `[CM]` prefix, and no layer calls `print` directly.** `KCM.PREFIX` (`core/Constants.lua`) is the single source of truth; one-shot chat routes through the secret-safe `KCM.Say(fmt, ...)` seam and gated verbose output through `KCM.Debug(tag, fmt, ...)`. The sole sanctioned raw `print` is the one embedded in generated macro-body `/run print(...)` strings ([scope.md](./scope.md)).
- **Recompute is coalesced.** Callers fire `KCM.MSG.RECOMPUTE` on the bus (or call `Pipeline.RequestRecompute`), never `Pipeline.Recompute` directly — except the rare direct paths (`KCM.ResetAllToDefaults`, `/cm resync`, `/cm rewritemacros`) where the write should land this tick.
- **Priority-list IDs are opaque numbers with sign semantics.** Positive = itemID, negative = `KCM.ID.AsSpell(spellID)`. Only `MacroManager`, `Ranker.Score`'s spell shortcut, and the UI fork on the sign; every other layer treats them as plain table keys.
- **Score cache lives for one Recompute pass and no longer.** `scoreCache` is created fresh in `Pipeline.Recompute` and threaded through `PickBestForCategory` → `SortCandidates`. Tooltip / bag / spec state can shift between events — never cache across passes. Non-pipeline callers (Options panel, `/cm dump pick`) pass `nil`.
- **Composite categories never own item buckets.** No `added`/`blocked`/`pins`/`discovered` — composites compose picks from their referenced single categories at recompute time. Sub-categories are locked to their `inCombat` / `outOfCombat` section.
- **Per-hand categories resolve twice from one bucket.** `perHand = true` (today only `WPN_ENCH`) keeps the ordinary spec-aware `bySpec` bucket — there is no per-slot persisted state. The pipeline calls `Selector.PickBestForSlot(catKey, 16, …)` and `(…, 17, …)` against that one list, each filtered to entries whose `tt.weaponAffinity` matches `WeaponSlots.SlotAffinity(slot)`. A hand with no weapon, or with nothing matching, is dropped from the macro body rather than falling back to the other hand's pick.
- **Action-bar icon sentinel.** Active body stores `DYNAMIC_ICON = 134400` (`?` fileID); empty body omits `#showtooltip` and stores `DEFAULT_ICON = 7704166` (cooking pot). Storing `DEFAULT_ICON` on an active body shows the cooking pot on the bar instead of the picked item's icon.
- **The macro bar owns the only protected frames, and never pokes them in combat.** Slots and flyout entries are secure buttons, so creating, anchoring, showing or hiding them is combat-forbidden. Everything funnels through `MacroBar.Update()`, which defers to `PLAYER_REGEN_ENABLED`; combat-conditional visibility goes to `RegisterStateDriver`, flyout hover to `_onenter`/`_onleave` snippets, and combat state reaches those snippets via `RegisterAttributeDriver` — all of it running in the secure environment instead. A slot's `macro` attribute is stamped once at creation and never rewritten.
- **Debug flag is session-only.** `KCM.State.debug` (`core/State.lua`) is never persisted — a session left with debug on doesn't leak into the next login.

## Timers

`C_Timer` is used directly rather than AceTimer, in three places: the pipeline's frame-coalescing (`RequestRecompute`), the options panel's refresh debounce (`O.RequestRefresh`), and the flyout's idle auto-close (`MacroBarFlyout`). This is a **deliberate, documented choice** (CM-09): the addon needs only fire-once short delays, `C_Timer` is a first-party API with no extra embed, and AceTimer is not otherwise required. The standard treats the timer choice as a SHOULD, so this justification satisfies it.

Note the flyout timer's limit: there is no timer inside the *secure* environment, so it cannot close a flyout mid-combat and deliberately stands down instead ([macro-bar.md](./macro-bar.md#closing)).

## External dependencies

These are the addon's **runtime** libraries. The **contributor toolchain** — what you install to
build, test or release — is a separate list in [../DEPENDENCIES.md](../DEPENDENCIES.md).

All vendored under `libs/`:

- LibStub
- CallbackHandler-1.0
- AceAddon-3.0
- AceEvent-3.0
- AceDB-3.0
- AceConsole-3.0
- AceGUI-3.0
- LibSharedMedia-3.0 (debug-console monospace font registration; also the media source behind the macro bar's border pickers)
- AceGUI-3.0-SharedMediaWidgets (the `LSM30_Border` preview dropdown used by those pickers; `core/LSMPatch.lua` fixes up its misaligned preview tile)
- LibKa0s — the Ka0s-owned shared modules, vendored whole-folder from [github.com/tusharsaxena/LibKa0s](https://github.com/tusharsaxena/LibKa0s) and loaded through the library's own packaged XML. All five majors are adopted: `Core-1.0` (chat printer), `DebugLog-1.0` (debug console), `Slash-1.0` (dispatcher, help rows and schema CLI), `Options-1.0` + its `OptionsWidgets` / `OptionsScroll` attachments (panel shell, row widgets, canvas contract), `Perf-1.0` + `PerfPanel` (A/B capture). Never patched in place — a fix goes upstream, then re-vendors whole-folder ([testing.md](./testing.md)).

### LibKa0s adoption

Each major is adopted by the same shape: one host **setup file** resolves what only the addon can
know, builds ONE instance via `lib:New(descriptor)`, publishes the addon's existing **flat,
dot-callable** names as thin forwarders onto that instance, publishes the instance itself as
`.instance` for identity assertions, and carries a degradation stub for a missing library.

| Major | Host half | What the addon keeps |
|---|---|---|
| `Core-1.0` | `core/CoreSetup.lua` | `KCM.PREFIX` (read live via a prefix *function*, never captured), the `print` sink the harness listens on |
| `DebugLog-1.0` | `modules/DebugLog.lua` | the shipped font, `KCM.State.debug` as the flag's single home, the `[Init]` content, the panel repaints |
| `Slash-1.0` | `settings/Slash.lua` | the `COMMANDS` table and the `STRINGS` overrides that keep this addon's shipped wording (both passed in, never owned). The verb bodies and their `*_COMMANDS` namespaces stay in `core/SlashCommands.lua`, the `/cm dump` targets in `core/SlashDump.lua`, and the `KCM_CONFIRM_RESET` popup with the verbs (CM-47). |
| `Options-1.0` | `settings/Panel.lua` | the schema itself, the `Resolve` → `SetAndRefresh` write seam, `Grid` / `Button` / `ButtonPair` / `Label`, `EnumValues` / `LSMValues`, the page order and the `KCM.Options` shim |
| `Perf-1.0` | `modules/PerfSetup.lua` | `/cm` as the taught command, `ConsumableMasterPerfDB` as the capture ring, the three sinks and the `suspend`/`resume` pair |

Three rules here are load-bearing rather than stylistic:

1. **Never bind a printer or a prefix by value.** Every `lib:New` snapshots its descriptor once, so a
   captured `KCM.Say` freezes the load-time function object and every later swap — including the
   suite's — goes unseen. Pass a thunk.
2. **A degradation stub's OMISSIONS are its contract.** `modules/DebugLog.lua` publishes no `AddLine`
   precisely because that absence re-arms `core/Debug.lua`'s chat fallback; a no-op would swallow
   every diagnostic while the addon looked healthy. `settings/Panel.lua` registers no Blizzard
   category at all, because one opening onto an empty canvas would leave the user unable to tell a
   broken install from a broken addon. `KCM.LIBKA0S_MISSING` (set in `core/CoreSetup.lua`) is the one
   shared cause clause; each seam appends only its own "so *what* is unavailable".
3. **Adoption is per-part, and declining is normal.** Where the library disagrees with the addon it is
   recorded in [pending/LEDGER.md](./pending/LEDGER.md) as a `LIBKA0S-*` row rather than worked around
   or silently taken. The three long-running declines — the slash dispatcher (LIBKA0S-01), the options
   row makers (LIBKA0S-04) and the options page registry (LIBKA0S-05) — have all since been adopted,
   two of them only after the blockers were fixed upstream and re-vendored; what is still declined is
   `Sl:CliResetAll` (LIBKA0S-12), because this addon's global reset also wipes `categories` and
   `statPriority`, which the schema does not describe. Never patch the vendored copy: a fix belongs
   upstream, then re-vendored (the `core/LSMPatch.lua` precedent — third-party fixups live in `core/`,
   not in `libs/`).

The libraries are listed directly in `ConsumableMaster.toc` under `# Libraries` (LibStub first, then CallbackHandler, LibSharedMedia, the Ace3 sub-libraries in dependency order, and LibKa0s last) — no `embeds.xml` wrapper (per the standard, toc-file-§4). The TOC's `## Interface:` line is `120007`.

## Load order

`ConsumableMaster.toc` is the source of truth. Order is dependency, not alphabetical:

1. `# Libraries` — LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, the Ace3 sub-libraries (AceAddon/AceEvent/AceDB/AceConsole/AceGUI), AceGUI-3.0-SharedMediaWidgets, then LibKa0s last, listed directly in the TOC
2. `# Locales` — `locales/enUS.lua`
3. `# Core` — `Namespace.lua` (names `NS`) → `ConsumableMaster.lua` (AceAddon promotion + DB + pipeline) → `Bus.lua` → `Constants.lua` → `CoreSetup.lua` → `Compat.lua` → `State.lua` → `Database.lua` → `Debug.lua` → `SpecHelper` → `TooltipCache` → `WeaponSlots` → `BagScanner` → `Classifier` → `LSMPatch` → `MacroDisplay` → `MacroBarModel` → `MacroBarLayout` → `SlashDump` → `SlashCommands`
4. `# Defaults` — `Categories.lua` then `Defaults_*.lua`
5. `# Modules` — `Ranker` → `Selector` → `MacroManager` → `DebugLog` → `PerfSetup` (after DebugLog, whose ungated `AddLine` is where its run log goes) → the macro bar (`MacroBarFlyout` → `MacroBarButton` → `MacroBar`, in that order: the container builds slots that own flyouts) → AceGUI widgets (`KCMIconButton` → `KCMScoreButton` → `KCMMacroDragIcon` → `KCMItemRow`)
6. `# Settings` — `Panel.lua` (must come first — registers `KCM.Settings.Helpers` + `RegisterTab`, publishes the `KCM.Options` shim) → `General.lua` → `MacroBar.lua` → `StatPriority.lua` → `Category.lua`

Event handlers and `Pipeline` functions are *defined* while `core/ConsumableMaster.lua` loads but only *called* from `OnEnable` / Ace event dispatch, which runs after every file has loaded — so the bodies can freely reference modules that load later.

## Repository

- **Dual-path WSL checkout.** `/home/tushar/GIT/ConsumableMaster/` and
  `/mnt/d/Profile/Users/Tushar/Documents/GIT/ConsumableMaster/` are the same repo via symlink; either
  path works for git and file tools.
- **Remote.** `origin` → `https://github.com/tusharsaxena/ConsumableMaster.git` (GitHub repo
  `tusharsaxena/ConsumableMaster`), `master` is the default branch, and the `gh` CLI is authenticated
  for issues.
- **Tracked vs ignored.** `libs/` is tracked (vendored Ace3 / LibSharedMedia / LibKa0s — standard WoW
  addon practice), as are `defaults/`, `docs/`, `tests/`, `locales/` and all `.lua` source.
  `.gitignore` covers `.claude/settings.local.json`, OS cruft and editor scratch files.

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`). A
decision may be reasoned at length elsewhere — `docs/scope.md`, an audit or review bundle — but a
deviation that is not in this table is not ratified, and an audit re-files it as an open failure.
The **Re-check trigger** is the condition that ends the deviation; a row without one is a permanent
opt-out wearing a table's clothes.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `localization-§4` | `core/TooltipCache.lua` parses English tooltip **text** — heal/mana/stat magnitudes, the `Augment Rune` marker, and the weapon-application effect | There is no stable-ID substitute for reading a numeric magnitude out of free text. The deviation is deliberately narrow: item and weapon **classification** already runs on the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua:167-170`, `core/WeaponSlots.lua`), so category and weapon-affinity detection work on every client. Reasoned at `docs/scope.md` → *Out of scope* → Localization; audit finding `CM-A-01` | 2026-08-05 | A client API that exposes those magnitudes as structured data, or the first non-enUS client this addon commits to supporting |
| `toc-file-§5` | The within-`core/` file sequence is `Namespace → ConsumableMaster → Bus → Constants → CoreSetup → Compat → State → Database`, not the section's illustrative `Compat → Constants → Namespace` | `core/Namespace.lua` bootstraps the private `KCM` table that Compat and Constants attach **to**, so it cannot come after them, and `core/CoreSetup.lua` builds `KCM.Say` from `KCM.PREFIX` and so must sit after `core/Constants.lua`. `toc-file-§5`'s only MUST is the **section-header** order — Libraries → Locales → Core → Defaults → Modules → Settings — which this TOC satisfies; the within-section sequence in its code block is illustrative. Rationale is also carried in the TOC's own comments (`ConsumableMaster.toc:42-47`, `:52-54`); audit finding `CM-A-16` (filed as `CM-49`) | 2026-08-05 | `toc-file-§5` making the within-section file sequence an ordered MUST |
