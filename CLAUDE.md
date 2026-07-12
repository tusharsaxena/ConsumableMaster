# CLAUDE.md

**Ka0s Consumable Master** — an auto-managed consumable-macro addon for WoW: Midnight (Interface 120007, Ace3, Lua 5.1, English only).

Compliant with the **Ka0s WoW Addon Standard v1.0.0 (Tier 2)**.

## Layout

```
core/       namespace bootstrap, AceAddon entry, bus, compat, constants, state,
            DB, pipeline, and the pure engine modules (SpecHelper → Classifier)
modules/    Ranker, Selector, MacroManager, DebugLog, KCM* AceGUI widgets
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

## Full agent brief

The detailed working notes — hard rules, module-publishing pattern, response
style, and the topic doc index — live in **[docs/agent-context.md](./docs/agent-context.md)**.
Read it before touching code. Design overview: [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).
User-facing reference: [README.md](./README.md).
