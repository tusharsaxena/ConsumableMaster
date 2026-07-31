# Testing & verification — Ka0s Consumable Master

How to verify the addon before you commit. This is the contributor-facing "how to
verify" doc; the player-facing [README](../README.md) deliberately keeps none of it
(per the Ka0s WoW Addon Standard, `documentation-§1`).

## The green gate

Two gates guard every change. **Both must be green before every commit** — a commit
with red tests or lint errors is not allowed.

| Gate | Command | What it does |
|------|---------|--------------|
| Headless tests | `lua5.1 tests/run.lua` | Runs every headless suite — classifier, ranker, selector (including the discovery TTL sweep and pin merge), ID sentinels, the settings schema and its mutation seam, macro writes (result codes, combat deferral, flush retries, oversize fallback), message bus, chat/debug output seams, the LibKa0s seams (chat printer, debug console, settings-panel shell) and their degraded paths, DebugLog formatters, tooltip parsing, spec/stat resolution, the spec/spell compat seam, bag scanning, SavedVariables migrations, the recompute pipeline, the client-event layer, shipped-data integrity (categories, seed lists, stat priorities), the AceGUI widget registrations, and the `/cm` dispatcher — plus a full TOC-order load check against a `wow_mock.lua` stub of the WoW API. No game client needed. Exits non-zero on any failure. |
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

## What the mock will and won't catch

`tests/wow_mock.lua`'s `CreateFrame` **models template capability**: methods a real
frame only gets from its template — `SetFrameRef` / `GetFrameRef` / `Execute` /
`WrapScript` from a `SecureHandler*Template`, `SetBackdrop*` from
`BackdropTemplate` — return nil unless the template list asks for them. That exists
because a fully permissive stub happily answered `SetFrameRef` on a plain
`SecureActionButton` and let two "attempt to call a nil value" crashes reach the
client. If new code needs one of those methods, pass the template that grants it.

The stub also stores **attributes** for real (`SetAttribute` / `GetAttribute`), so a
test can assert that the Lua side put the right values within a secure snippet's
reach — `kcmEntries`, `kcmGrace` — and records `RegisterStateDriver` /
`RegisterAttributeDriver` calls in `mock.stateDrivers` / `mock.attributeDrivers`.
Getters the addon does arithmetic or concatenation on (`GetFrameLevel`, `GetWidth`,
`GetName`, …) return numbers and strings rather than the stub itself.

It also models **secret values**. `mock.setCooldownsRestricted(true)` makes the
spell cooldown API return values that error on comparison or arithmetic — exactly
how a restricted cooldown behaves for tainted code mid-fight — and flags them
through `issecretvalue` so `KCM.Compat.IsSecret` sees them. `mock.secret(v)` builds
one directly, and `mock.makeDuration(start, duration)` stands in for a duration
object, recording what it was configured with so a test can assert the right span
arrived without exposing a comparison surface the addon isn't allowed to use. That
combination is what keeps the in-combat cooldown regression
([midnight-quirks.md](./midnight-quirks.md#secret-values)) headlessly testable.

Everything else about a frame is still a permissive stub, so the harness cannot see
client-only behavior: taint, secure-snippet execution, whether a template
*combination* works (it doesn't, for secure + Backdrop), or anything visual. Those
belong to [smoke-tests.md](./smoke-tests.md).

## Test-first (TDD)

Write or extend a **failing** test that pins the intended behavior first, then implement
until it passes. No logic change lands without a covering test. Pure, testable logic
(classification, ranking, selection, schema validation, migrations, formatting) is
exercised headlessly here; genuinely in-client behavior (frame rendering, taint) is
covered by the in-game smoke tests below.

## In-game smoke tests

The headless suite can't exercise real client behavior. The manual in-game playbook — a
quick post-change smoke plus the full section-by-section suite — lives at
[smoke-tests.md](./smoke-tests.md). Run it before a release.
