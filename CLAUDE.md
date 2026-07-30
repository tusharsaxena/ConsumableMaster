# CLAUDE.md

**Ka0s Consumable Master** — an auto-managed consumable-macro addon for WoW: Midnight (Interface 120007, Ace3, Lua 5.1, English only).

## Standard — read first

This addon conforms to the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards)** (declared as `X-Standard` in `ConsumableMaster.toc`). That repo is the source of truth for structure, naming, packaging, TOC layout, namespace/bus/compat patterns, and conventions. Frozen compliance audits live under `docs/audits/<date>/` (past code reviews under `docs/reviews/<date>/`).

**Deviation rule (MUST).** If a change you are about to make would deviate from the standard — or you notice existing code that already deviates — **stop and flag it to the user**. Never silently diverge. Let the user decide whether it should be:
1. a **tracked deviation** — a documented, intentional exception for this addon; or
2. a **change to the standard itself** — upstreamed to the [WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards) repo so every addon benefits.

This applies to both new work and anything you discover in passing.

## Layout

```
core/       namespace bootstrap, AceAddon entry, bus, compat, constants, state,
            DB, pipeline, the pure engine modules (SpecHelper → Classifier), and
            the macro bar's pure halves (MacroDisplay, MacroBarModel/Layout)
modules/    Ranker, Selector, MacroManager, DebugLog,
            MacroBar(+Button, +Flyout), KCM* AceGUI widgets
defaults/   seed itemID lists + category table (data, not code)
settings/   options panel + per-tab pages
locales/    enUS.lua (KCM.L)
```

`ConsumableMaster.toc` is the load-order source of truth.

## Gate

```
lua5.1 tests/run.lua    # headless test harness
luacheck .              # lint
```

Both must be green before committing. Manual in-game validation: [docs/smoke-tests.md](./docs/smoke-tests.md).

**Static badges (Hard rule).** The README `[WoW]` and `[Tests]` badges are static and go stale silently — update each in the same change that moves its source. `[Tests]` ↔ `docs/test-cases.md`: when the suite changes (a case added/removed/renamed, or the pass count moves — i.e. whenever a failing test is resolved), regenerate (`lua5.1 tests/run.lua --list > docs/test-cases.md`) and bump the `Tests-<X>/<Y>_passing` count. `[WoW]` ↔ TOC `## Interface:`: both MUST show the same number and move together on every patch bump. Never defer to a follow-up. Details: [docs/agent-context.md](./docs/agent-context.md#keeping-the-inventory--badge-in-sync).

## Full agent brief

The detailed working notes — hard rules, module-publishing pattern, response
style, and the topic doc index — live in **[docs/agent-context.md](./docs/agent-context.md)**.
Read it before touching code. Design overview: [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).
User-facing reference: [README.md](./README.md).
