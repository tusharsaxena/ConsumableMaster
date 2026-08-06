# Testing & verification — Ka0s Consumable Master

How to verify the addon before you commit. This is the contributor-facing "how to
verify" doc; the player-facing [README](../README.md) deliberately keeps none of it
(per the Ka0s WoW Addon Standard, `documentation-§1`).

## The green gate

Two gates guard every change. **Both must be green before every commit** — a commit
with red tests or lint errors is not allowed.

| Gate | Command | What it does |
|------|---------|--------------|
| Headless tests | `lua5.1 tests/run.lua` | Runs every headless suite — classifier, ranker, selector (including the discovery TTL sweep and pin merge), ID sentinels, the settings schema and its mutation seam, macro writes (result codes, combat deferral, flush retries, oversize fallback), message bus, chat/debug output seams, the LibKa0s seams (chat printer, debug console, slash dispatcher and schema CLI, settings-panel shell plus the Blizzard canvas callbacks it stamps, perf harness) and their degraded paths, DebugLog formatters, tooltip parsing, spec/stat resolution, the spec/spell compat seam, bag scanning, SavedVariables migrations, the recompute pipeline, the client-event layer, shipped-data integrity (categories, seed lists, stat priorities), the AceGUI widget registrations, and the `/cm` dispatcher — plus a full TOC-order load check against a `wow_mock.lua` stub of the WoW API. No game client needed. Exits non-zero on any failure. |
| Lint | `luacheck .` | Static analysis across the addon (`libs/`, `docs/audits/`, `docs/reviews/`, `tests/` excluded). Must report **0 errors**. |

Syntax-check a single file with `luac -p path/to/file.lua`.

## Verifying the vendored LibKa0s copies

Neither gate above can see this, and that is the whole problem: the library's suite passes against
the library, and this addon's passes against a stale vendored copy that still works. Run after any
re-vendor, and before any release:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s    # content — MUST be empty
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                        # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit       # content — MUST be empty
diff -r ../LibKa0s/testkit tests/_kit                           # bytes  — SHOULD be empty
```

Both halves, because the two answers are different findings.

`tests/test_vendor_sync.lua` runs the same comparison inside the suite, and the tag it compares
against is **not hardcoded** — it is the `Bundles [LibKa0s](…) vX.Y.Z (MIT).` line in the root
[`CLAUDE.md`](../CLAUDE.md), so that line moves in the same commit as the bytes. (It lived in
`README.md` until test-kit revision 9 / LibKa0s v1.8.1; there is deliberately no fallback to the
old location, so a repo that re-vendors without moving its line goes red.)

**Content differs** → a real fork in `libs/`, which is the forbidden state. Name every hunk.

**Bytes differ but content matches** → a line-ending divergence, not a fork. Both repos pin
`* text=auto eol=crlf` over LF blobs, so a working tree holding *either* ending reads clean to
`git status` and neither side's cleanliness proves anything. Find which side drifted (`file -b
<path>`, and `git cat-file -p HEAD:<path> | file -b -` for what git stores) and renormalize it.
**Re-vendoring will not converge it, and the fix is never an edit to `libs/`** — that makes a fork
nobody knows about, which the next re-vendor reverts silently, and the revert reads as a regression
with no cause anywhere in this repo's history.

This addon has a specific stake in that second case. The 2026-08-01 adoption report ran the bare
single-diff form and it accused **this repo** of drift while clearing the other two — the accusation
was backwards, because ConsumableMaster's checkout was the correct one and the library's own ship
folder had the LF files. Content was byte-identical throughout.

Re-vendoring is **whole-folder**, never file by file: four of the five majors resolve
`LibKa0s-Core-1.0` before registering, and `Options` and `Perf` are each split across files with
paired attach guards, so a per-file copy is how cross-major skew gets manufactured.

## Local toolchain

WoW runs Lua 5.1, so the harness targets 5.1 — and the binary has to be named `lua5.1` on `PATH`,
because two cases in `tests/test_runner_list.lua` shell out to that literal name.

The full toolchain, with install commands, versions and a verification command per tool, lives in
[../DEPENDENCIES.md](../DEPENDENCIES.md) (the standard's `documentation-§7`). It answers *what to
install*; this page answers *how to verify*. The short form:

```sh
sudo apt update && sudo apt install -y lua5.1 luarocks git
sudo luarocks install luacheck
sudo apt install -y pipx && pipx ensurepath && pipx install lizard
```

`pipx`, not `pip` — Ubuntu 24.04 marks its Python externally managed (PEP 668) and
`pip install lizard` fails. See DEPENDENCIES.md for the alternative.

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

## Automated test records — the consolidated run

All four out-of-game suites go through one vendored runner, and every run is recorded
(`automated-tests`):

```sh
tests/_kit/run-automated-tests.sh                            # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity          # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
```

| Suite | Command | Gates the run and the commit? | Gates the tag? |
|---|---|---|---|
| `lint` | `luacheck .` | **yes** | **yes** |
| `tests` | `lua tests/run.lua` | **yes** | **yes** |
| `perf` | `lua tests/perf.lua` | no — recorded only | **yes** |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded only | **yes**, plus zero functions above CCN 15 |

**`perf` and `complexity` never fail a run and never gate a commit.** They are measured, recorded and
diffed — a threshold that fails a run teaches everyone to reach for `--no-verify`, after which the
gate protects nothing and the habit remains. They contribute `amber`, which is a signal rather than a
stop. **A missing tool is a skip recorded with its reason**, never a pass.

**At the tag they do gate**, and that is a different checkpoint evaluated by a different actor:
`/wow-addon:bump-version` reads the release run's `manifest.json` and refuses the bump unless all
**four** suites read `pass` and `suites.complexity.warnings` is `0`. A `skip` is **not evaluated** —
it is a gate that did not pass, never a pass. `automated-tests-§3` sanctions one exception — `perf`
skipped because the addon ships no `tests/perf.lua`, stated out loud in the release notes — and it
**does not apply here**: this addon ships `tests/perf.lua` and its `perf` column reads `pass`.

`tests/perf.lua` runs the whole addon under the test mock and drives four scenarios: `recompute`,
`cooldownRefresh`, and the `probeOverheadOff` / `probeOverheadOn` pair that is `performance-§9`'s
zero-overhead evidence. It asserts only the deterministic half — per-iteration byte counts and the
bucket-note count — because wall-clock numbers on a developer machine are not stable enough to fail
anything on. `lua tests/run.lua` does not invoke it. Detail in
[performance.md](./performance.md).

The runner is **vendored** from `LibKa0s`'s `testkit/`; never edit `tests/_kit/`. A kit fix goes
upstream and is re-vendored.

**At release, not at commit.** A full bundle is produced as part of every version bump, before the
tag, with an `ANALYSIS.md` write-up. Commits are gated on lint + tests only; the tag is gated on all
four.

Results live in [`automated-tests/`](./automated-tests/): `RESULTS.md` is one row per run across all
four suites plus the current complexity watch list — **one file, overwritten in place**, so its git
history is the trend line — and each `<YYYYMMDD-HHMMSS>/` is a frozen bundle of that run's raw
output. Bundles are never edited and never pruned.

`docs/complexity.md` was this addon's standalone complexity report through standard v2.18.0; it is
**retired** — its raw output is each bundle's `complexity.txt` and its trend line is `RESULTS.md`.

## In-game smoke tests

The headless suite can't exercise real client behavior. The manual in-game playbook — a
quick post-change smoke plus the full section-by-section suite — lives at
[smoke-tests.md](./smoke-tests.md). Run it before a release.
