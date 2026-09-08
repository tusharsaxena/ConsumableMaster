# Testing & verification — Ka0s Consumable Master

How to verify the addon before you commit. This is the contributor-facing "how to
verify" doc; the player-facing [README](../README.md) deliberately keeps none of it
(per the Ka0s WoW Addon Standard, `documentation-§1`).

## The green gate

Two gates guard every change. **Both must be green before every commit** — a commit
with red tests or lint errors is not allowed.

| Gate | Command | What it does |
|------|---------|--------------|
| Headless tests | `lua5.1 tests/run.lua` | Runs every headless suite — classifier, ranker, selector (including the discovery TTL sweep and pin merge), ID sentinels, the settings schema and its mutation seam, macro writes (result codes, combat deferral, flush retries, oversize fallback), message bus, chat/debug output seams, the LibKa0s seams (chat printer, debug console, slash dispatcher and schema CLI, settings-panel shell plus the Blizzard canvas callbacks it stamps, perf harness, and the media seam — which folder name crosses it, whether the path that comes back names art actually present in this build's vendored payload, and whether the close-button wrapper still carries that name as its third argument) and their degraded paths, DebugLog formatters, tooltip parsing, spec/stat resolution, the spec/spell compat seam, bag scanning, SavedVariables migrations, the recompute pipeline, the client-event layer, shipped-data integrity (categories, seed lists, stat priorities), the AceGUI widget registrations, the locale seam and the routing gate over the settings surface (`tests/test_locale.lua` lexes `settings/` and the `modules/KCM*` widgets for prose literals and fails on any that is neither wrapped in `L` nor classed in its residue register), and the `/cm` dispatcher — plus a full TOC-order load check against a `wow_mock.lua` stub of the WoW API. No game client needed. Exits non-zero on any failure. |
| Lint | `luacheck .` | Static analysis across the addon **including the test tree** (`libs/`, `docs/audits/`, `docs/reviews/` and `tests/_kit/` excluded — the kit is a byte copy linted in the LibKa0s repo as source). Must report **0 errors**. |

Syntax-check a single file with `luac -p path/to/file.lua`.

## Verifying the vendored LibKa0s copies

Neither gate above can see this, and that is the whole problem: the library's suite passes against
the library, and this addon's passes against a stale vendored copy that still works. Run after any
re-vendor, and before any release:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s    # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                        # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit       # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/testkit tests/_kit                           # bytes  — SHOULD be empty
```

### When these diffs are supposed to be non-empty

They compare against the sibling checkout's **working tree** — whatever `../LibKa0s` happens to have
checked out — which is a different question from *"is the vendored payload the release this addon
claims?"*. The two questions give the same answer only while the library has tagged nothing newer
than the tag this addon has taken.

Between a library release and the re-vendor that carries it they disagree, and that disagreement is
the normal state rather than a defect. It is the state as this is written: `../LibKa0s` sits on
**v1.27.0**, [`CLAUDE.md`](../CLAUDE.md) names **v1.26.0**, and the commands above report **306**
differing lines for the library and **947** for the test kit. Re-vendoring to quiet them would be
the actual mistake — it would pull an untested library release for the sake of a clean diff.

**The authoritative comparison is against the tag `CLAUDE.md` names**, and that one must be empty at
every commit:

```sh
tag=$(grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' CLAUDE.md \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
rm -rf "/tmp/libka0s-$tag" && mkdir -p "/tmp/libka0s-$tag"
git -C ../LibKa0s archive "$tag" | tar -x -C "/tmp/libka0s-$tag"
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/LibKa0s" libs/LibKa0s   # MUST be empty
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/testkit" tests/_kit     # MUST be empty
```

`tests/test_vendor_sync.lua` asks exactly this question inside the suite — it greps the tag out of
`CLAUDE.md` and reads that blob out of git — so **a green suite has already answered it**, and the
block above is only the by-eye version for when you want to see the hunks. Which leaves the
working-tree diffs above answering a real but different question: *how far behind the library is
this addon?* That is release planning, not a gate.


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

Re-vendoring is **whole-folder**, never file by file: nine of the payload's ten majors resolve
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

`<PASS>` and `<TOTAL>` are allowed to differ, and the gap is always a **declared skip**
— a case registered with a third argument giving its reason, which the runner never
executes, never folds into the pass count, and never lets change the exit code. The
inventory discloses each one inline as `(skipped: <reason>)`, so the two numbers together
say "N cases exist, N-k of them are being evaluated" rather than hiding the difference.
A skip is for a case that has been written and watched failing against a defect the fix
for which is a separate change; it is never a way to park a case whose assertion is
merely inconvenient, and softening the assertion instead is worse than either.

## The 1500-line cap gate

`tests/test_layout_cap.lua` compares two things: every authored `.lua` git tracks, and the
census under *Files over the 1500-line cap* in [ARCHITECTURE.md](./ARCHITECTURE.md). It reads
them in both directions, so a file that crosses the cap unremarked and a row left behind for a
file that has stopped breaching are each a red.

`layout-§1` binds **every authored file the repository tracks**, `tests/` included; vendored
code (`libs/`, `tests/_kit/`) is the only carve-out that reaches this repo. A red is cleared by
giving the file one of the three terminal states the rule allows — peel it, open an issue naming
the seam a peel would follow, or ratify a deviation row with a re-check trigger — and then adding
its row to the census. It is not cleared by raising `CAP`, and it must not be cleared by dropping
the suite from `SUITES`: `Kit.assertSuiteInventory` aborts the run on an undeclared suite file,
which is the point of having one.

The line figures in the census are dated measurements and nothing asserts them, so an ordinary
edit to a large file does not redden this gate. Membership is the invariant, not the numbers.

## The US-English prose gate

`tests/test_prose.lua` reads every authored file git tracks — `.lua`, `.md`, `.toc` and
`.luacheckrc` — and reddens on a British spelling from the `BRITISH` list `localization-§5`
publishes, after the `ALLOWED` US words that contain one of those substrings have been taken
out as whole words.

**Both lists are copied from the standard whole, and nothing is added locally.** A gate that
carries a private subset reads as coverage and provides none: LibKa0s shipped six substrings
for months and stayed green while a doubled-L `CANCELED` went out in chat text a player reads. If
a sweep here turns up a British form the published list misses, it is amended in `localization-§5`
first and arrives on the next standards sync.

Four exclusions, each named directory by directory or file by file inside the gate so the list
cannot grow by widening a pattern: vendored code (`libs/`, `tests/_kit/`); the frozen dated
bundles under `docs/audits/`, `docs/automated-tests/`, `docs/perf-analysis/`, `docs/reviews/`
and `docs/revendor/`; `locales/enGB.lua`, which is what a British locale file is for and which
this addon does not ship; and the gate's own copy of the lists. `docs/superpowers/` is dated but
is authored prose people still read, so it stays in scope.

The gate exists because the sweep alone did not hold. `M4-13` corrected 51 lines across 22 files
and left nothing watching; four commits later `M4-18`, `M4-21` and `M4-22` had put 26 back, in
files each had every reason to touch. A sweep is a measurement of one afternoon. Only a gate
makes it a property of the repository.

## The blanket-suppression gate

`tests/test_lintconfig.lua` reads `.luacheckrc` as Lua — under a sandboxed environment that
auto-creates a table on first index, exactly as luacheck's own config loader does, so what the
gate inspects is the table luacheck obeys rather than a text scan a different spelling would slip
past. It reddens on three things, which are one rule seen from three sides: a top-level `ignore`;
a warning class switched off wholesale at the top level (`unused_args = false` and its eight
relatives); and an `ignore` inside a `files[...]` stanza whose key names a directory rather than
one `.lua` file and whose entry does not narrow to a variable in luacheck's `<code>/<name>` form.
A fourth case walks every tracked `.lua` file for a bare `-- luacheck: ignore` with no code after
it, which is the same blanket wearing a different hat.

The gate exists because `.luacheckrc:25` carried `ignore = { "212", "542" }` for the whole of the
2026-09-07 cycle. Both codes were honest — unused `self` on AceGUI widget methods, one deliberately
empty CSV branch in `/cm stat secondary` — but the suppression reached all 99 files, so a genuinely
dead argument written into `core/BagScanner.lua` would have landed green under a 0/0 badge. That is
what `lint.md` means by a suppression that reads as coverage and provides none.

What replaced it is at the foot of `.luacheckrc`: eleven `files[...]` stanzas, each naming one file
and one argument name (`212/self`, `212/ctx`, `212/catKey`, `212/%.%.%.`), plus a single
`-- luacheck: ignore 542` on the line in `core/SlashCommands.lua` that needs it. The narrowing is
real and not cosmetic — add a fifth parameter named anything else to a `modules/Ranker.lua` scorer
and luacheck reports it, which the blanket did not.

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

`tests/perf.lua` runs the whole addon under the test mock and drives five scenarios: `recompute`,
`cooldownRefresh`, the `probeOverheadOff` / `probeOverheadOn` pair that is `performance-§9`'s
zero-overhead evidence, and `refreshBurst`, which drives the settings panel's 150-call first-open
refresh storm and asserts on the number of timers the debounce arms for it. It asserts only the deterministic half — per-iteration byte counts and the
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
