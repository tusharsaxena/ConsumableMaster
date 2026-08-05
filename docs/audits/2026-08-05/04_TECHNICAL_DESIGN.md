# 04 — Technical Design

How to close the gaps catalogued in `02_DEVIATIONS.md`. Keyed to deviation IDs throughout. This is a
**design**, not an execution — the audit is read-only and changed no addon file.

**Standard:** v2.21.0 (2026-08-04).

---

## 0. Shape of the work

Twenty actionable MUSTs sort into five groups that barely interact, plus one that must go first.

| Group | IDs | Nature |
|---|---|---|
| **A — the degraded install** | CM-58, CM-65 | Two real crashes/blackouts on the LibKa0s-absent path. Small diffs, high value, testable |
| **B — file moves and the seams they unblock** | CM-44, CM-45, CM-46, CM-48, CM-36, CM-37, CM-39, CM-51 | Structural. Four `git mv`s and one peel, which between them unblock the upvalue hoist and the AceGUI consolidation |
| **C — the test harness** | CM-34, CM-35, CM-40, CM-64 | Migrate onto the vendored kit, then derive the load list, then add the coverage the migration makes cheap |
| **D — performance evidence** | CM-38, CM-41, CM-42, CM-43 | Additive: a runner, a lint line, two docs |
| **E — documentation and metadata** | CM-50, CM-59, CM-60, CM-61, CM-62, CM-63, CM-49 | Independent one-file edits, plus the one item that may resolve upstream |

**Ordering constraint that dominates everything:** group C changes how every suite loads the addon.
Any structural move in group B lands in `tests/loader.lua`'s hand-written `PURE_LAYER` today
(CM-35), so **either** do B before C and pay one edit per move, **or** do C first and the moves cost
nothing because the list derives from the TOC. The second is cheaper and is what `05_EXECUTION_PLAN.md`
orders. The single exception is group A, which is user-visible breakage and should not wait behind a
harness migration.

---

## A. The degraded install (CM-58, CM-65)

These are the only two findings that describe something a user can hit today. They are also the two
that produce the contradiction the code review reproduced verbatim: the panel promises the CLI still
works, and the CLI says it does not.

### A1. CM-58 — no-op the two runtime members in the Options lib-absent branch

`settings/Panel.lua:571-572` currently:

```lua
Helpers.RefreshAllPanels = UI and UI.RefreshAllPanels
Helpers.RefreshScalars   = UI and UI.RefreshScalars
```

Design: keep the bound-to-instance form when `UI` exists, and publish **no-ops** when it does not.
Not honest one-liners — the notice is already said once at `settings/Panel.lua:265-271` on the first
attempt to *reach* the panel, and stapling a line to every scalar write would bury it. There is no
panel to refresh in this state, so a no-op is the truthful behavior, not a swallow.

```lua
local function noop() end
Helpers.RefreshAllPanels = (UI and UI.RefreshAllPanels) or noop
Helpers.RefreshScalars   = (UI and UI.RefreshScalars)   or noop
```

**Why not guard at the call sites instead.** Two reasons. `settings/Panel.lua:643` sits inside
`Helpers.SetAndRefresh`, which is the addon's **single write seam** — `/cm set`, every panel widget
and `KCM.Schema:Set` all funnel through it — so a guard there is one guard; but `:833` is a second
site, and `options-ui-§1`'s stub rule is written about the *stub*, not about its callers. Fixing it
at the binding keeps the invariant "every member the addon reaches is answered" true for members
added later, which a pair of call-site guards does not.

**Do not** extend this to `AttachTooltip`, `SetRenderer`, `Grid`, `RenderField`, `AddSpacer`,
`CustomCheckbox`, `ResetScroll` or `PatchAlwaysShowScrollbar`. Those are reached only from the panel
build path, which `libAbsent` (`settings/Panel.lua:254`) already refuses at `:788` and `:893`. A
sweep that no-ops them all would be a change with no covering scenario. The two named here are
reached from **outside** the panel — the write seam and the bus receiver — which is precisely what
makes them different.

**Risk:** low. The behavior with the library present is byte-identical (`or noop` never fires).

### A2. CM-65 — keep host verbs alive when the slash library is absent

`settings/Slash.lua:340-343` routes *everything* through `Sl:OnSlash`, so `Sl == nil` blacks out all
17 verbs. Eleven of them never touched the library.

Design: split the **match** from the **render**. The `COMMANDS` table is already the host's ordered
positional-triple list (`:65-172`); walking it is four lines and does not duplicate anything the
library owns.

```lua
-- host-side fallback dispatch: verb match only. No row formatter, no value
-- parser, no `key = value` shape -- those are the library's and stay there
-- (slash-commands-§1).
local function hostDispatch(msg)
    local verb, rest = (msg or ""):match("^%s*(%S*)%s*(.*)$")
    verb = (verb or ""):lower()
    if verb == "" then return printHelp() end
    for _, entry in ipairs(COMMANDS) do
        if entry[1] == verb then return entry[3](rest) end
    end
    say(("Unknown command: |cffffff00%s|r"):format(verb))
end

function KCM:OnSlashCommand(msg)
    if not Sl then return hostDispatch(msg) end
    return Sl:OnSlash(msg)
end
```

The five schema verbs (`list`, `get`, `set`, `reset`, plus `help`) already resolve to the stub's
honest one-liner through `cliList`/`cliGet`/`cliSet`/`cliReset`/`printHelp` (`:300-304`), so routing
them through `hostDispatch` reaches the same place. `resetall`, `bar`, `priority`, `stat`, `aio`,
`dump`, `resync`, `rewritemacros`, `config`, `version` and `debug` start working again.

**The rule this must not violate:** `slash-commands-§1` — *"The stub **MUST NOT** re-implement the
library's rendering — no copied row formatter, no copied parser, no copied `key = value` shape."*
`hostDispatch` copies none of those. It matches a verb; it does not render. `printHelp` in the
degraded branch stays the plain line it already is.

**Then reconcile the two messages.** With CM-65 landed, `settings/Panel.lua:265-269`'s claim —
"every setting is still reachable with /cm list, /cm get and /cm set" — is still **false**, because
the schema CLI is exactly the half that is genuinely lost. Rewrite it to what will be true:

> `…, so the settings panel is unavailable and `/cm list`, `/cm get` and `/cm set` cannot answer.
> The rest of `/cm` still works.`

and drop the ", so /cm is unavailable" clause from `settings/Slash.lua:301-302` in favour of naming
the schema CLI. One absence, said the same way, with each seam appending only what *it* loses —
which is the shape `core/CoreSetup.lua:25-31` already established.

**Risk:** moderate — this is the only group-A change that alters behavior with the library present?
No: `hostDispatch` is unreachable when `Sl` exists. The risk is in the *messaging* rewrite touching
user-visible strings; cover it with the degraded-load case in A3.

### A3. The covering test — real, not hand-stubbed

`testing-§8` is explicit: *"**MUST** verify the degraded path by actually loading the addon with the
module missing, not by hand-stubbing the namespace member the code under test reads."*
`tests/test_settingsui.lua:243-246` today asserts only `FindSchema` and claims the write path "stays
writable", which is why F-002 slept.

Design one scenario, reused by both A1 and A2: feed the loader the addon's file list **with the
`libs/LibKa0s/*` entries omitted**, so every `LibStub("LibKa0s-…-1.0", true)` returns nil and each
setup file takes its own fallback. Then drive, end to end:

- `KCM.Schema:Set("<some bool path>", false)` → returns true, the value landed, **no error**;
- a `KCM.Pipeline.Recompute("test")` → the PANEL_REFRESH receiver runs, **no error**;
- `KCM:OnSlashCommand("bar")`, `("version")`, `("dump")` → each reaches its host verb;
- `KCM:OnSlashCommand("set foo bar")` → answers the honest schema-CLI line, does not silently no-op.

This is loadable as a real scenario precisely because four of LibKa0s's five majors return **before**
`LibStub:NewLibrary` when Core is missing — so the majors are *absent*, not half-wired
(`library-stack-§7`, anti-pattern #48). It becomes much cheaper once CM-35 derives the load list,
because "the TOC minus `libs/LibKa0s`" is then a filter rather than a second hand-written list.

---

## B. File moves and the seams they unblock

### B1. CM-44 — `modules/DebugLog.lua` → `core/DebugLogSetup.lua`

Pure move. The file's content is already correct — descriptor, forwarders, member-answering stub with
its documented omission. TOC line moves into `# Core`, positioned after `core/Constants.lua` (the
mono font path constant), `core/CoreSetup.lua` (the printer the stub's notice uses) and
`core/State.lua` (the debug flag the stub reads), and **before** every module that calls the sink.

Ripples: `tests/loader.lua`'s path list (free after CM-35), `docs/file-index.md`, `docs/scope.md`,
`docs/ARCHITECTURE.md:20`, and the three files whose comments name it by path
(`core/CoreSetup.lua:—`, `settings/Slash.lua:252`, `settings/Panel.lua:207` all say "modules/DebugLog.lua's
print"). Fold **CM-66**'s one-line comment correction (`.AddLine` → `.instance`) into the same commit
— it is a comment in the file being moved.

### B2. CM-45 then CM-39 — `modules/PerfSetup.lua` → `core/PerfSetup.lua`, then hoist the brackets

These are one change in two steps and **must** be done in this order.

Step 1 (CM-45): `git mv`, TOC line into `# Core` after the DebugLog setup (its `log`/`showLog` hooks
reach the console) and **before** `core/ConsumableMaster.lua`. The descriptor's `log`, `print` and
`showLog` are already call-time closures (`modules/PerfSetup.lua:89-91`), so they survive the move;
verify rather than assume. `suspend`/`resume` reach `KCM.UnregisterAllEvents`, `KCM.MacroBar.Update`,
`KCM.OnEnable` and `KCM.Pipeline.RequestRecompute` — all resolved at call time too.

Step 2 (CM-39): only now is a file-scope `local Perf = KCM.Perf` sound in
`core/ConsumableMaster.lua` and `modules/MacroBar.lua`. Rewrite both brackets to the mandated shape:

```lua
local Perf = KCM.Perf            -- file scope, load-time upvalue
…
local t0 = Perf.on and debugprofilestop()
…
if t0 then Perf.Note("cooldown", debugprofilestop() - t0) end
```

**One wrinkle the mandated shape does not cover.** `modules/PerfSetup.lua:36` returns without
publishing `KCM.Perf` at all when the major is absent, so `Perf` would be `nil` and `Perf.on` would
raise. `performance-§1` requires the setup file to *"degrade rather than error … the setup file falls
back to a stub carrying every member the addon actually calls."* The upvalue hoist therefore
**requires** turning that bare `return` into a two-member stub:

```lua
if not lib then
    KCM.Perf = { on = false, Note = function() end }
    return
end
```

That is one line of new surface, it is what the section asks for, and it is the difference between
"no capture" and "a nil index on the cooldown repaint". Do it in step 1, not step 2.

**Then CM-40** becomes cheap: with `Perf` an upvalue and a stub in place, a test can flip `Perf.on`
and drive each declared bucket's genuine entry point. Iterate
`modules/PerfSetup.lua`'s declared bucket list rather than naming `cooldown`/`recompute` inline, so a
third bucket added later fails until something drives it.

### B3. CM-46 + CM-36 + CM-37 + CM-51 — the Options peel

One change; splitting it produces two conflicting diffs over the same lines.

New file `settings/OptionsSetup.lua`, TOC-listed in `# Settings` immediately **before**
`settings/Panel.lua`, carrying:

1. the `LibStub("LibKa0s-Options-1.0", true)` lookup (from `settings/Panel.lua:186`);
2. the descriptor and `:New` (`:193-236`) — unchanged, including `mainPanelName`, the thunked
   `print`, the positional color codecs, `sliderCommit = "change"` and the call-time `getLSM`;
3. **`KCM.Settings.Helpers = optionsLib:New(descriptor)`** — the instance **is** the namespace
   member (CM-36), not a fresh table;
4. the lib-absent branch, keeping the **load-completing** shape verbatim (`LSMValues` real enough for
   the page files to finish) **plus** A1's two no-ops;
5. `KCM.AceGUI = LibStub("AceGUI-3.0", true)` (CM-51), published once, with `UI.AceGUI = KCM.AceGUI`
   replacing `settings/Panel.lua:247`.

`settings/Panel.lua` then keeps the schema half (`Resolve/Get/Set/FindSchema/ValidateSchema`, the
rows, `SetAndRefresh`), `CreatePanel`'s click handler and ctx fields, the host helpers, and the
registration bootstrap — and **decorates the instance in place** rather than copying onto a table:

```lua
local Helpers = KCM.Settings.Helpers      -- the instance
function Helpers.Resolve(path) … end      -- host-only pieces hung on it
```

The ten copy-across lines (`:245`, `:247`, `:278-279`, `:351`, `:361`, `:383`, `:458`, `:519`,
`:527`, `:571-572`) all **disappear** — they exist only because `Helpers` was a different table from
`UI`. That is the CM-36 fix and it removes the mechanism that produced CM-58, which is the reason
these two are designed together even though A1 ships first as a standalone hotfix.

CM-37: delete `local SECTION_HEADING_H = 26` and `local BUTTON_PAIR_REL = 0.492` (`:74-75`), read
`Helpers.SECTION_HEADING_H` at `:711` and `Helpers.BUTTON_PAIR_REL` at `:507`. If the library does
not expose either, add it upstream in LibKa0s as an **additive** field and re-vendor — never keep the
host copy (`options-ui-§1`, anti-pattern #47).

CM-51's three page files (`settings/Panel.lua:19`, `settings/StatPriority.lua:23`,
`settings/Category.lua:29`) change from `LibStub("AceGUI-3.0")` to `local AceGUI = KCM.AceGUI`, and
each render path guards on it. `modules/KCMIconButton.lua:11` and its four peers already use the
guarded form and are the pattern to copy.

**Risk:** this is the largest diff in the plan. It touches the file the settings suite exercises most
(`tests/test_settingsui.lua`, `tests/test_schema.lua`, `tests/test_widgets.lua` — 100+ cases). Run
the full suite between each of the four sub-steps rather than at the end.

### B4. CM-48 — `defaults/Profile.lua`

Move `KCM.dbDefaults` (`core/ConsumableMaster.lua:25-…`) into `defaults/Profile.lua`, TOC-listed
first in `# Defaults`. Optionally split the `global` sub-table into `defaults/Global.lua`.

The three readers (`core/ConsumableMaster.lua:203,541`, `core/SlashCommands.lua:713`,
`settings/MacroBar.lua:21-22`) all reach it off the namespace at call time, so the move is
mechanical — **but it changes load order**: `defaults/` loads after `core/`, so anything in `core/`
that reads `KCM.dbDefaults` **at file load** breaks. Grep for that specifically before moving; the
three known readers are all inside functions. `KCM.db` construction at `core/ConsumableMaster.lua:203`
happens in `InitDB`, not at load, which is what makes this safe.

---

## C. The test harness

### C1. CM-34 — migrate onto the vendored kit

`tests/run.lua` stops `require`ing the local `harness` and instead:

```lua
local Kit    = dofile("tests/_kit/framework.lua")
local Loader = dofile("tests/_kit/loader.lua")
…
Kit.expose(_G.KCM_TEST)          -- keeps the repo's existing global name
Kit.run{ dir = "tests/", suites = { … } }
```

`Kit.expose` merges `test` and the assertion set into whatever table you hand it, so **no suite file
changes** — that is what makes this one commit rather than a rewrite of 31 files. Confirm the
assertion **names** first: the local harness uses `t.eq` / `t.truthy` (see
`tests/test_vendor_sync.lua:118,124`), the kit publishes `assertEqual`/`assertTrue`/… If they differ,
publish thin aliases from `run.lua` at migration time and retire them in a follow-up — do **not**
edit `tests/_kit/` to add them (`testing-§1`: never edit the kit in a consumer; a kit gap is a
finding to fix upstream and re-vendor).

`tests/wow_mock.lua` becomes a thin extender:

```lua
local base = dofile("tests/_kit/mock_base.lua")
return function(...)
    local M = base(...)
    -- per-key overwrites only: the item/bag/spell/spec store, setEquipped,
    -- setPlayerLevel/Class, and whatever the base does not model
    return M
end
```

The base returns a fresh table per call, so there is no merge machinery. Expect the 623-LOC file to
land somewhere well under 200. `M.__stubFrame()` and `M.__libs` are the escape hatches for extra
frame-shaped objects and library fakes.

Delete `tests/harness.lua` and `tests/loader.lua`.

**Risk: this is the highest-risk item in the plan** and the reason it gets its own sprint. The mock
is 623 lines of behavior 656 cases depend on, and `mock_base.lua` is 537 lines that may model the
same things differently — AceDB's in-place `copyDefaults`, AceConsole's `Embed` clobber, and the
`TooltipCache` `pending=true` shape (`tests/wow_mock.lua:18-19`) are the three most likely to
diverge. Migrate in one commit with the full suite green, not incrementally.

Mitigation: `tests/_kit/README.md` (9174 bytes, vendored) carries the kit's fidelity rules and its
own vendoring instructions — read it first; it is the spec for what the base already does.

### C2. CM-35 — derive the load list from the TOC

Replace `tests/loader.lua:79-113`'s `L.PURE_LAYER` with a **filter over**
`Loader.tocFiles("ConsumableMaster.toc")` — drop the UI/settings tail rather than re-listing the
pure head. Vendored library files stay **explicit**, in `LibKa0s.xml` order, because `tocFiles`
cannot see inside an XML (`testing-§9`).

Pin the derivation with three cases, per the section: the runner fed the loader exactly the TOC's
files in the TOC's order; every derived path exists on disk; no `libs/` path leaked in.

This is what makes group B free: after it, a `git mv` plus a TOC edit is the whole of CM-44/45/46/48.

### C3. CM-64 — make the vendor-sync gate loud

Two edits to `tests/test_vendor_sync.lua`:

1. `:141,147` — replace `if not tag then return end` with either a **fail** naming the path it looked
   for (`testing-§11`: *"MUST fail, not pass, when the gate cannot run"*), or, if a green suite on a
   machine without the sibling is genuinely wanted, rename both cases to carry
   `(skipped: no sibling LibKa0s checkout)` so `--list` and `docs/test-cases.md` say so out loud.
   Prefer the fail: this audit could not run the `diff -r` **and** the addon's own gate stayed green,
   which is two silences over one question.
2. `:135` — drop the `:gsub("\r\n", "\n")`. Read both sides as raw bytes. If the CRLF working tree
   makes that awkward, compare `git show HEAD:<path>` on the **local** side too, so both operands
   come from git and neither is normalized.

Fix the header comment at `:108-110` in the same change — it currently asserts a behavior the code
does not have.

---

## D. Performance evidence

### D1. CM-38 — `tests/perf.lua`

A separate entry point, run as `lua tests/perf.lua`, **not** loaded by `tests/run.lua`
(`testing-§7`). Assert only on deterministic quantities — call counts, bytes per iteration measured
with a full `collectgarbage("collect")` either side — never on wall-clock time.

Minimum scenario set:

- **zero-overhead** (the required evidence for `performance-§2` / anti-pattern #43): with
  `Perf.on == false`, N iterations of `KCM.Pipeline.Recompute` and of `MB.RefreshCooldowns` allocate
  **zero** bytes attributable to the bracket and call `debugprofilestop` **zero** times. Instrument
  by counting calls to a swapped-in `debugprofilestop`, which is the only observable the bracket has
  when off. This scenario is *why* CM-39 must land first — the current per-call `KCM.Perf` lookup is
  exactly what the scenario would measure and fail.
- **bucket reachability** as a smoke scenario, complementing CM-40's gated cases.

Its load list derives from the TOC (`testing-§9`), pinned by reading its source, since the gate does
not run it.

Once it exists, `perf` stops being a permanent `skip` in every bundle and the release gate
(`automated-tests-§3`) can be satisfied without the narrow no-`tests/perf.lua` exception.

### D2. CM-41 — one lint line

`.luacheckrc` `globals`:

```lua
"ConsumableMasterPerfDB",  -- the perf capture ring (savedvariables-§4, performance-§5)
```

### D3. CM-42 / CM-43 — the two missing docs

`docs/performance.md`: which paths are bracketed (`recompute`, `cooldown`) and why, how to run
`/cm perf`, how to read the report, what the harness can and cannot resolve. Point at the library for
the shared protocol and the record contract rather than restating them. **Lift**
`modules/PerfSetup.lua:8-15` — it already explains the addon-specific part (the expensive paths are
deliberately out of combat and will never appear in a capture) better than a fresh draft would.

`docs/perf-runs/README.md`: naming convention `<YYYY-MM-DD>-<source>-<label>.json`, schema summary,
pointer to the library's canonical field-by-field contract, and the explicit note that this store is
the **in-game** half while offline runs live in `docs/automated-tests/`
(`performance-§8`, `automated-tests-§7`). Commit the first real capture beside it — a README for an
empty directory is the shape that quietly stays empty.

---

## E. Documentation and metadata

Each of these is independent and one file wide.

- **CM-50** — `CLAUDE.md:1` → `# CLAUDE.md — Ka0s Consumable Master`.
- **CM-59** — root `CHANGELOG.md` is the fourth root doc. Two options: `git mv CHANGELOG.md
  docs/CHANGELOG.md` (a topic-detail doc, which the standard permits any number of), or fold its
  player-facing rows into `README.md` `## Version History` and delete it. Prefer the move — the file
  carries engineering detail the README deliberately excludes. Add it to `.pkgmeta` ignore on the way
  past (CM-56).
- **CM-60** — add the five missing `docs/ARCHITECTURE.md` sections. Settings Schema and Slash Commands
  should be **tables generated from** `KCM.Settings.Schema` and `KCM.COMMANDS` rather than prose, so
  `wow-addon:sync-docs` can keep them honest. Event Subscriptions reads off `KCM:OnEnable`. Taint
  Notes absorbs the invariants bullet at `:87` plus a pointer to `docs/midnight-quirks.md`. Known
  Limitations names CM-30 (enUS tooltip parsing) so the one accepted deviation is visible where an
  engineer lands.
- **CM-61** — add the release gate beside the commit gate in `docs/testing.md:141-157`,
  `docs/automated-tests/README.md:19-33` and `CLAUDE.md:72-76`. **Keep every existing commit-gate
  sentence verbatim** — they are quoted correctly from the standard and the failure mode they name
  (a threshold on every commit teaches `--no-verify`) is still live. Add: the tag is gated on all
  four suites at `pass` plus `suites.complexity.warnings == 0`; the gate is evaluated by the release
  command from the run's `manifest.json`; the runner's exit code is unchanged because the same script
  is the commit gate; a `skip` blocks as NOT EVALUATED; and the one narrow exception — `perf` skipped
  because the addon ships no `tests/perf.lua` — **applies to this addon today** and must be stated in
  the release notes until CM-38 lands. Reword `CLAUDE.md`'s "report, not a gate" to "not a **commit**
  gate". `docs/automated-tests/RESULTS.md` is **generated** and is already correct — do not hand-edit
  it.
- **CM-62** — `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`. Add the `chmod +x` step
  to the re-vendor procedure in `docs/testing.md` so the next `cp` does not drop it again.
- **CM-63** — add `Compat.GetItemInfo(itemID)` and `Compat.GetItemCount(itemID)` to `core/Compat.lua`,
  preferring `C_Item.*` and falling back to the global, then route the five direct sites through
  them (`core/TooltipCache.lua:459`, `modules/Ranker.lua:88`, `core/Classifier.lua:169`,
  `core/WeaponSlots.lua:36`, `modules/KCMItemRow.lua:88-89,131-132,216`). This also closes the code
  review's F-010 — the unguarded `core/TooltipCache.lua:459` — as a side effect, and makes
  `.luacheckrc:74`'s comment true rather than aspirational. Note the two **guarded** sites are not
  broken today; they are moved for the same reason `Compat` exists at all: one edit when Blizzard
  renames the API.
- **CM-49** — decide, don't drift. Either reorder `core/` to `Compat → Constants → Namespace → …`
  (verifying that `Compat.lua` and `Constants.lua` tolerate running before `Namespace.lua` bootstraps
  `NS` — they currently do not, since both take `local _, NS = ...` and populate it), **or** raise it
  upstream as a standard correction: `layout-§1`'s order arguably cannot be satisfied by any addon
  whose `Namespace.lua` is the bootstrap, which is every addon in the collection. Record whichever
  outcome in the next audit as either closed or as an accepted deviation with the TOC's existing
  comments as its rationale. This is the one item where "no change" may be the right answer.

---

## Advisory items (MAY) — bundle with whatever touches the same file

- **CM-52** — narrow `.luacheckrc:23` to `212/self`, `212/event`; inline-suppress `542` and `241`.
  Better: delete `core/TooltipCache.lua`'s write-only `pendingIDs` (`:147,448,463,480,488`) and drop
  `241` entirely — then `RESULTS.md`'s lint section stops carrying the caveat.
- **CM-53** — mechanical sweep of ~30 retired `§N.M` comment references to `filename-§N`. Do it in the
  same commit as whatever else touches each file; a standalone sweep commit is 20 files of noise.
- **CM-54** — split `tests/test_macrobar.lua` (1497) into bar / button / flyout **at the next case
  added**, not before. `RESULTS.md`'s disposition already says this, and it will hit the three-run
  shelf life (anti-pattern #53) at the release after next if renewed unchanged.
- **CM-55** — keep `## Credits and bundled libraries`; it now has a machine consumer
  (`tests/test_vendor_sync.lua:100-103` parses `README.md:277`). If it is ever removed, move the
  `Bundles [LibKa0s](…) vX.Y.Z` provenance line first.
- **CM-56** — add `.claude/`, `.superpowers/` and `CHANGELOG.md` to `.pkgmeta` ignore.
- **CM-57** — migrate open `LIBKA0S-*` items from `docs/pending/LEDGER.md` to GitHub issues once the
  adoption closes out.
- **CM-66** — one-line comment fix at `modules/DebugLog.lua:97-99`. Fold into CM-44's move.
- **CM-67** — consider placeholder rows for empty categories while the macro bar is unlocked.

---

## Risk register

| Risk | Where | Mitigation |
|---|---|---|
| Mock divergence between `tests/wow_mock.lua` and `tests/_kit/mock_base.lua` | CM-34 | Read `tests/_kit/README.md` first; migrate in one commit; full suite green before and after. Do **not** edit the kit |
| Assertion-name mismatch (`t.eq` vs `assertEqual`) breaking all 31 suites | CM-34 | Publish aliases from `run.lua` at migration; retire in a follow-up. Never patch the kit |
| Options peel touching 100+ settings cases | CM-46/36/37/51 | Four sub-steps, suite green between each |
| Load-order break moving `KCM.dbDefaults` after `core/` | CM-48 | Grep for load-time reads specifically before the move |
| Perf upvalue hoist nil-indexing on a LibKa0s-less install | CM-39 | The two-member `KCM.Perf` stub in CM-45 step 1 is a **prerequisite**, not an optional extra |
| Messaging rewrite changing strings the suite asserts on | CM-65 | The degraded-load scenario (A3) is the covering test; write it first |
| A "fix" that re-implements library rendering in the slash stub | CM-65 | `slash-commands-§1` forbids it explicitly; `hostDispatch` matches a verb and renders nothing |
