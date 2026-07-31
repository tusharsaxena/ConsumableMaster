# Agent context — working notes for future sessions

The full brief for Claude Code (and other LLM-assisted editors) working on **Ka0s Consumable Master**. Read this before touching code. The root [CLAUDE.md](../CLAUDE.md) is a stub that points here.

## What this addon is

Thirteen account-wide global macros whose bodies auto-rewrite to the best consumable in bags. Eleven are single-pick categories (food, drink, HP pot, MP pot, healthstone, vantus rune, flask, combat pot, stat food, weapon enchant, augment rune) and two are composites (`KCM_HP_AIO`, `KCM_MP_AIO`) that compose other categories' picks via `[combat]` / `[nocombat]` conditionals. Panel/tab order is FOOD → DRINK → HP_POT → MP_POT → HS → HP_AIO → MP_AIO → FLASK → CMBT_POT → STAT_FOOD → WPN_ENCH → AUG_RUNE → VANTUS. Retail Midnight only (Interface 120007). English only. Ace3 throughout. Ka0s WoW Addon Standard.

The same macros are also hosted on a CM-only **macro bar** (on and unlocked by default), one secure slot per category with a hover flyout of every currently-usable candidate — the addon's only protected-frame surface ([macro-bar.md](./macro-bar.md)).

User-facing reference: [README.md](../README.md). Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Namespace & structure

- **Private namespace, no globals.** Every file starts `local addonName, NS = ...`. `core/Namespace.lua` loads first and names the table (`NS.name`); `core/ConsumableMaster.lua` promotes it with `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceConsole-3.0")` and stores `NS.addon`. There is **no `_G.KCM`** — the only shared handle is a per-file transition alias `local KCM = NS`, so the tree's internal `KCM.*` references resolve to the private table.
- **Layout.** `core/` (namespace, AceAddon entry, Bus, Compat, Constants, CoreSetup, State, Database, Debug, pipeline in `ConsumableMaster.lua`, the pure engine: SpecHelper, TooltipCache, WeaponSlots, BagScanner, Classifier, the macro bar's pure halves: MacroDisplay, MacroBarModel, MacroBarLayout, the LSM widget fixup LSMPatch, and SlashCommands), `modules/` (Ranker, Selector, MacroManager, DebugLog, the macro bar's frame layer: MacroBarFlyout, MacroBarButton, MacroBar, and the `KCM*` AceGUI widgets), `defaults/`, `settings/`, `locales/`. `ConsumableMaster.toc` is the load-order source of truth.
- **Weapon Enchant is per-hand.** `WPN_ENCH` picks independently for main hand (slot 16) and off hand (slot 17) via `Selector.PickBestForSlot(catKey, slot, scoreCache)`, which filters the effective priority list to entries whose `tt.weaponAffinity` ("bladed" | "blunt" | "any") matches `WeaponSlots.SlotAffinity(slot)` for the currently equipped weapon. `MacroManager.SetWeaponEnchantMacro(cat, mhPick, ohPick)` assembles the body from per-slot line pairs — `/use item:<id>` + `/use 16` and/or `/use item:<id>` + `/use 17` (each on its own line) — dropping either hand that has no weapon or no valid match. AP/SP-scoring detail lives in [data-model.md](./data-model.md); recompute trigger is `PLAYER_EQUIPMENT_CHANGED` (see [pipeline.md](./pipeline.md)).

## Hard rules

- **Conform to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards).** That repo is the source of truth for structure, naming, packaging, and conventions. **If a change would deviate from the standard — or you spot existing code that already deviates — flag it to the user; never silently diverge.** The user decides whether it becomes a tracked deviation for this addon or a change upstreamed to the standard. The rule is stated in full under **Standards compliance (read first)** in [CLAUDE.md](../CLAUDE.md). Frozen audits live under `docs/audits/<date>/`.
- **`MacroManager` is the only module allowed to call protected macro APIs** (`CreateMacro`, `EditMacro`, `DeleteMacro`). Every other module — Classifier, Ranker, Selector, BagScanner, TooltipCache, SpecHelper — must stay pure so the recompute pipeline can run in combat without taint. If you need bag or tooltip data at macro-write time, call the pure module and pass the result into MacroManager; never the other direction.
- **The macro bar owns the only protected FRAMES; the same discipline applies.** `modules/MacroBar*.lua` creates `SecureActionButtonTemplate` slots, so creating, anchoring, showing or hiding them (or the container) is combat-forbidden. Everything funnels through `MacroBar.Update()`, which self-defers to `PLAYER_REGEN_ENABLED` (`MacroBar.FlushPending`). Combat-conditional visibility uses `RegisterStateDriver`, never `Show`/`Hide`. A slot's `macro` attribute is stamped **once** at creation and never rewritten — if you find yourself wanting to rewrite it, you're about to break the combat story. Alpha changes are unprotected and fine mid-combat. Detail: [macro-bar.md](./macro-bar.md).
- **Macros are identified by name, never slot.** `perCharacter=false` puts them in the account-wide pool (slots 1–120). The addon must never call `DeleteMacro` on a `KCM_*` macro — the slot is the user's.
- **English-only — tracked deviation** from `localization-§4` / anti-pattern #37 (recorded in `docs/scope.md`; a standards audit is *expected* to flag it). Classification keys on the locale-independent numeric `classID`/`subClassID` (`core/Classifier.lua`, `core/WeaponSlots.lua`), so category/affinity detection works on every client. The remaining English dependency is TooltipCache's tooltip-TEXT parsing — if a patch rewords a tooltip line, edit `PATTERNS` / `STAT_TOKENS` in `core/TooltipCache.lua`. Do not add localization plumbing beyond the `locales/enUS.lua` shell; full tooltip localization is a planned future release.
- **Seed data is data.** `defaults/Defaults_*.lua` files are just lists of itemIDs that become `KCM.SEED.<CATKEY>`. Updating a seed list is a zero-migration upgrade because the runtime candidate set is `(seed ∪ added ∪ discovered) − blocked` and the right-side sets live in SavedVariables.
- **Reset is centralized.** `KCM.ResetAllToDefaults(reason)` (in `core/ConsumableMaster.lua`) wipes + resyncs. Both the Options panel "Reset all priorities" button and `/cm reset`'s StaticPopup delegate to it. Don't add a third reset path.
- **Priority-list entries are opaque numeric IDs.** Positive = itemID, negative = `KCM.ID.AsSpell(spellID)` sentinel. Only `MacroManager`, `Ranker.Score`'s spell shortcut, and the UI fork on the sign — every other layer treats IDs as plain table keys. Keep it that way; no new side channels.
- **Composite categories don't pick items — they compose other categories' picks.** HP_AIO and MP_AIO carry `composite=true` + `components = { inCombat={...}, outOfCombat={...} }`. The pipeline branches on `cat.composite` and dispatches to `MacroManager.SetCompositeMacro`. Composites have no `added/blocked/pins/discovered` buckets.
- **Cyan `[CM]` chat prefix on all addon output.** `KCM.PREFIX` (`core/Constants.lua`) is the single source of truth; route one-shot chat through the secret-safe `KCM.Say(fmt, ...)` seam (pass a finished string, or a format string + args that each get secret-stringified). Gated verbose logging goes through `KCM.Debug(tag, fmt, ...)` into the on-screen console. **No raw `print(...)` calls** outside those seams (the sole exception is `KCM.PREFIX` embedded in generated macro-body `/run print(...)` strings).
- **Static README badges move with their source of truth, in the same change.** Both `[WoW]` and `[Tests]` are static shields.io badges that go stale silently. `[Tests]` ↔ `docs/test-cases.md`: when the suite changes (a case added/removed/renamed, or the pass count moves — i.e. whenever a failing test is resolved), regenerate the inventory via `lua5.1 tests/run.lua --list` and bump the `Tests-<X>%2F<Y>_passing` count. `[WoW]` ↔ TOC `## Interface:`: the badge and the TOC MUST show the same number and move together on every patch bump (via `wow-addon:bump-interface`). Never defer a badge update to a follow-up. See [Keeping the inventory & badge in sync](#keeping-the-inventory--badge-in-sync).

## Message bus

Cross-module control flow that crosses feature boundaries goes over the closed bus (`core/Bus.lua`), never by reaching into another module's tables. Pure-function queries (MacroManager asking Selector/Ranker/Classifier for data) stay direct calls.

- `KCM.bus` is an AceEvent-embed. **Every receiver owns its own target** via `KCM.NewBusTarget()` — never two subscriptions on one table.
- `KCM.MSG` names the four messages:
  - **`RECOMPUTE`** (`Ka0s_ConsumableMaster_Recompute`) — event/UI layer → pipeline. The pipeline owns the only subscription; it forwards to `RequestRecompute`, which coalesces to one pass per frame.
  - **`PANEL_REFRESH`** (`Ka0s_ConsumableMaster_PanelRefresh`) — pipeline → options panel. Debounced rebuild of any open page.
  - **`SPEC_CHANGED`** (`Ka0s_ConsumableMaster_SpecChanged`) — spec change → options panel. Retracks the Stat Priority page to the new spec.
  - **`MACROBAR_REFRESH`** (`Ka0s_ConsumableMaster_MacroBarRefresh`) — pipeline → macro bar. Undebounced icon/count repaint of the optional bar.

Full catalog lives in [ARCHITECTURE.md](./ARCHITECTURE.md).

## Compat seam

`core/Compat.lua` (`KCM.Compat`) wraps the spec + spell APIs that Blizzard churns (`GetSpecialization*`, `GetSpecializationInfoForClassID`, spell name lookup). Call through `Compat.*`; never hit the raw API from SpecHelper, SlashCommands, MacroManager, or the settings pages. A future rename is one edit here.

`Compat.IsSecret(value)` lives here too, wrapping the client's own `issecretvalue` (and reporting `false` on a client that predates it). Any gate over client data that a combat restriction could turn secret has to ask it *before* comparing — the live case is the macro bar's cooldowns, where the numbers go secret mid-fight and the swipe has to be painted from a duration object instead. See [midnight-quirks.md](./midnight-quirks.md#secret-values).

## Debug console

The on-screen `ScrollingMessageFrame` console is `LibKa0s-DebugLog-1.0`'s; `modules/DebugLog.lua` is the addon's half — the font, the flag's home, the `[Init]` content, the printer, the panel repaints, and the flat `KCM.DebugLog.*` forwarders every call site uses. The enabled flag is **session-only** — `KCM.State.debug` in `core/State.lua`, default off, never persisted — so a session left with debug on doesn't leak into the next login. `/cm debug on|off`, the panel checkbox, and the header `Debug: ON/OFF` toggle all route through the single `DebugLog.SetEnabled` seam (flag → header → chat ack → console line → panel refresh); **bare `/cm debug` toggles the window only**, leaving the flag untouched. Emit via the callable sink `KCM.Debug(tag, fmt, ...)` (zero-alloc gate when disabled, secret-safe via `KCM.SafeToString`).

## Locale

`locales/enUS.lua` exports `KCM.L`, a key-returning metatable. User-facing strings (panel labels, slash descriptions, popup text) go through `L[...]`. English is the only shipped locale — this is a shell, not localization plumbing.

## Testing & lint gate

Headless harness under `tests/` runs with **`lua5.1 tests/run.lua`** (a `wow_mock.lua` stubs the WoW API + a `(message,target)`-keyed bus so receivers are testable). Lint with **`luacheck .`**. Both must be green before committing. Manual in-game validation: [smoke-tests.md](./smoke-tests.md).

The **authoritative test count** lives in [test-cases.md](./test-cases.md) — a generated inventory of every suite and case, produced by the runner's non-executing `--list` mode (`lua5.1 tests/run.lua --list`). Don't hardcode counts in prose; link to that file instead.

### Keeping the inventory & badge in sync

When the suite changes — a case added, removed, or renamed, or the pass count moves (i.e. whenever a failing test is resolved) — regenerate the inventory and update the README `tests` badge **in the same change**, never as a follow-up:

```
lua5.1 tests/run.lua --list > docs/test-cases.md   # regenerate the inventory
```

then bump the `![Tests](…Tests-<PASS>%2F<TOTAL>_passing-green)` badge in [README.md](../README.md) to the new numbers. Verify sync with `diff <(lua5.1 tests/run.lua --list) docs/test-cases.md` (no output = in sync).

The `[WoW]` badge (`![WoW](…WoW-<Expansion>_<X.Y.Z>-purple)`) follows the same discipline against a different source: it MUST show the same number as the TOC `## Interface:` line and move with it on every patch bump (`wow-addon:bump-interface`).

## Module publishing pattern

Every module uses the same idiom:

```lua
local addonName, NS = ...
local KCM = NS
KCM.Foo = KCM.Foo or {}
local F = KCM.Foo
```

- Never overwrite an existing `KCM.Foo` without `or {}` — another file may have reached it first.
- Never make the local shadow the namespace (`local KCM = {}` would break everything downstream).
- Expose the public API on `F` (or `KCM.Foo` directly). Keep helpers `local` to the file.

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/ConsumableMaster/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/ConsumableMaster/` are the same repo via symlink. Either path works for git and file tools.
- **Git remote.** `origin` → `https://github.com/tusharsaxena/consumablemaster.git` (GitHub repo `tusharsaxena/ConsumableMaster`); `gh` CLI is authenticated for issues. `master` is the default branch.
- **`.gitignore`** covers `.claude/settings.local.json`, OS cruft, editor scratch files. `libs/` is tracked (vendored Ace3 + LibSharedMedia, standard WoW addon practice). `defaults/`, `docs/`, `tests/`, `locales/`, all `.lua` source are tracked.

## Response style for this repo

- **Terse.** State the change, not the deliberation.
- **Use `file_path:line_number` references** when pointing at code.
- **Don't write summaries** the user can read from the diff.
- **Ship functional, defer polish.** When core functionality lands, move on — don't stop to polish UX mid-milestone. Revisit polish later as a dedicated pass.
- **No comments explaining *what* well-named code does.** Only add a comment when the *why* is non-obvious (subtle invariant, workaround for a specific Blizzard quirk, hidden constraint).
- **Don't create docs or planning files unless asked.**
- **Never auto-stage, auto-commit, or auto-push.** The user chooses when to `git add`, `git commit`, and `git push`. This includes `git add <file>`, `git add -A`, `git add -p`, `git add --renormalize`, `git stash`, or any other index-mutating command. Editing files on disk is fine; touching the git index is not. Offering to stage/commit at the end of a turn is fine; doing it yourself is not. **Exception**: invoking a commit-purpose slash command (e.g. `/wow-addon:commit`) IS the explicit instruction. Proceed through the skill's confirmation flow and treat the user's `y` as authorization to run `git add` + `git commit` on the files the skill named. Pushing still requires a separate explicit ask.
- **Never bump the version without an explicit instruction.** Do not edit `KCM.VERSION` in `core/ConsumableMaster.lua`, `## Version:` in `ConsumableMaster.toc`, the version badge / inline version in `README.md`, or add a changelog entry, unless the user has explicitly asked. Releases are the user's call.

## Doc index

Topic-specific detail lives in `docs/`. Read on demand — these are not auto-loaded.

| Topic | File | When to read |
|-------|------|--------------|
| Scope boundaries (in / out / resolved decisions) | [scope.md](./scope.md) | Evaluating a feature request; deciding whether to add a category. |
| Per-file responsibility map | [file-index.md](./file-index.md) | "Which file owns X?" |
| Recipes (add category / composite, refresh seeds, fix misclassification) | [common-tasks.md](./common-tasks.md) | Routine modifications. |
| Debug toggle, dump targets, schema CLI | [debug.md](./debug.md) | Diagnosing in-game; building schema-driven settings. |
| Midnight quirks (subtype renames, NBSP, secret values, icon sentinel) | [midnight-quirks.md](./midnight-quirks.md) | Patch-day breakage, tooltip pattern issues. |
| Module map + public APIs | [module-map.md](./module-map.md) | Designing a cross-module change. |
| Recompute pipeline + score cache + events | [pipeline.md](./pipeline.md) | Touching event handling, performance. |
| AceDB schema + opaque IDs + composites + GC | [data-model.md](./data-model.md) | Adding a category, persistent state changes. |
| MacroManager — body builders, composite assembly, flush retry, icons | [macro-manager.md](./macro-manager.md) | Anything touching macro writes. |
| Headless gate — tests + luacheck, toolchain, TDD policy, badge sync | [testing.md](./testing.md) | Before every commit; setting up a fresh checkout. |
| Smoke tests (quick + full suite + targeted-by-change-area lookup) | [smoke-tests.md](./smoke-tests.md) | After any code change; before any release. |
| Test-case inventory (generated — authoritative count) | [test-cases.md](./test-cases.md) | Checking coverage; regenerate after any suite change. |
| Optional macro bar (secure slots, layout, combat contract) | [macro-bar.md](./macro-bar.md) | Touching the macro bar, its settings page, or anything protected-frame shaped. |
| Seed reference + refresh procedure | [../defaults/README.md](../defaults/README.md) | Patch-day seed updates. |
| Pending-item decision ledger (deferred / closed, with rationale) | [pending/LEDGER.md](./pending/LEDGER.md) | Before re-raising a TODO, audit step, or issue — a `wont-do` row means the question is settled. |
