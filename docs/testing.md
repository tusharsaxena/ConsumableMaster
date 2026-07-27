# Testing & verification — Ka0s Consumable Master

How to verify the addon before you commit. This is the contributor-facing "how to
verify" doc; the player-facing [README](../README.md) deliberately keeps none of it
(per the Ka0s WoW Addon Standard, `documentation-§1`).

## The green gate

Two gates guard every change. **Both must be green before every commit** — a commit
with red tests or lint errors is not allowed.

| Gate | Command | What it does |
|------|---------|--------------|
| Headless tests | `lua5.1 tests/run.lua` | Runs every headless suite — classifier, ranker, selector (including the discovery TTL sweep and pin merge), ID sentinels, the settings schema and its mutation seam, macro writes (result codes, combat deferral, flush retries, oversize fallback), message bus, chat/debug output seams, DebugLog formatters, tooltip parsing, spec/stat resolution, the spec/spell compat seam, bag scanning, SavedVariables migrations, the recompute pipeline, the client-event layer, shipped-data integrity (categories, seed lists, stat priorities), the AceGUI widget registrations, and the `/cm` dispatcher — plus a full TOC-order load check against a `wow_mock.lua` stub of the WoW API. No game client needed. Exits non-zero on any failure. |
| Lint | `luacheck .` | Static analysis across the addon (`libs/`, `docs/audits/`, `docs/reviews/`, `tests/` excluded). Must report **0 errors**. |

Syntax-check a single file with `luac -p path/to/file.lua`.

## Local toolchain

WoW runs Lua 5.1, so the harness targets 5.1. Install once:

```sh
sudo apt-get update && sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

## Test-case inventory & badge

The authoritative test count lives in [test-cases.md](./test-cases.md) — a **generated**
enumeration of every suite and case, produced by the runner's non-executing `--list` mode.
Never hand-author it.

```sh
lua5.1 tests/run.lua --list > docs/test-cases.md   # regenerate the inventory
```

Whenever the suite changes (a case added, removed, or renamed, or the pass count moves —
i.e. whenever a failing test is resolved), regenerate the inventory **and** bump the
`![Tests](…Tests-<PASS>%2F<TOTAL>_passing-green)` badge in the [README](../README.md) in
the same change. Confirm they match with:

```sh
diff <(lua5.1 tests/run.lua --list) docs/test-cases.md   # no output = in sync
```

## Test-first (TDD)

Write or extend a **failing** test that pins the intended behaviour first, then implement
until it passes. No logic change lands without a covering test. Pure, testable logic
(classification, ranking, selection, schema validation, migrations, formatting) is
exercised headlessly here; genuinely in-client behaviour (frame rendering, taint) is
covered by the in-game smoke tests below.

## In-game smoke tests

The headless suite can't exercise real client behaviour. The manual in-game playbook — a
quick post-change smoke plus the full section-by-section suite — lives at
[smoke-tests.md](./smoke-tests.md). Run it before a release.
