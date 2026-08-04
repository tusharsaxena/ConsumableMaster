# 04 — Technical Design (remediation)

**Audit:** 2026-08-04 · **Standard:** v2.17.1 · Keyed to the IDs in `02_DEVIATIONS.md`.

This is a design, not a change. Nothing here has been applied — the audit is read-only.

---

## Design themes

The 16 actionable MUSTs are not 16 independent edits. They fall into **five workstreams**, and the
ordering *between* them matters more than the ordering inside any one of them.

| # | Workstream | IDs | Shape |
|---|-----------|-----|-------|
| A | Adopt the vendored test kit | CM-34, CM-35 | Replace three addon-authored files with the kit; keep every suite file untouched |
| B | Relocate the LibKa0s setup files | CM-44, CM-45, CM-46, CM-47 | Four `git mv`s + TOC edits + two file splits |
| C | Close the performance surface | CM-38, CM-39, CM-40, CM-41, CM-42, CM-43 | One new runner, one new test, one lint line, two docs, one bracket rewrite |
| D | Finish the Options adoption | CM-36, CM-37 | Make the host member *be* the instance; delete two restated constants |
| E | Housekeeping | CM-48, CM-49, CM-50, CM-51 + advisories | Small, independent, low-risk |

**The one hard ordering constraint:** **B before C's CM-39.** The bracket can only take a load-time
upvalue once `PerfSetup` loads before its bracket sites, and that is exactly what CM-45 moves.
Landing CM-39 first would bind `nil` at file scope and silently disable both brackets — which is
precisely the class of failure `testing-§9` warns about, since the suite would stay green measuring
a harness that never arms.

**The one hard coupling:** **CM-36 and CM-46 are one change.** Both rewrite `settings/Panel.lua`
lines 41-193. Doing them separately means writing the seam twice.

---

## Workstream A — Adopt the vendored test kit (CM-34, CM-35)

### A.1 The current shape and why it must go

`tests/run.lua` → `require("harness")` → `require("loader")` → `require("wow_mock")`. Three
addon-authored files, ~1043 LOC, doing exactly what `tests/_kit/`'s 989 vendored, byte-identical
lines already do. The kit is present, proven current by `tests/test_vendor_sync.lua`, and **never
loaded**. Anti-pattern #47's failure mode is already latent: a mock-fidelity fix landing in the
LibKa0s kit reaches this repo's `tests/_kit/` on the next re-vendor and changes nothing, because
nothing reads it.

### A.2 Target shape

```
tests/
  _kit/              -- vendored, never edited  (unchanged)
  run.lua            -- dofiles framework.lua + loader.lua; TOC-derived load list; Kit.expose; Kit.run
  wow_mock.lua       -- local base = dofile("tests/_kit/mock_base.lua"); per-key overwrites
  test_*.lua         -- UNCHANGED
  perf.lua           -- new (CM-38, workstream C)
```

`tests/harness.lua` and `tests/loader.lua` are **deleted**.

### A.3 What makes this safe: `Kit.expose`

`testing-§1` designed for exactly this migration — *"`Kit.expose` merges `test` and the assertions
into the table you pass, so each repo keeps its own global name … Adopting the kit therefore
requires **no change to any existing suite file**."* This repo's suites take
`local h = require("harness")` and use `h.test` / `t.eq`. The migration must therefore either:

- **(preferred)** expose under the repo's existing shape so suite files are untouched — publish a
  `harness`-shaped table via `Kit.expose` and keep `package.path` resolving `require("harness")` to
  a two-line shim; or
- **(cleaner, larger)** convert suites to `local T = _G.KCM_TEST; local test, assertEqual = T.test,
  T.assertEqual`, which is a 30-file mechanical sweep.

Recommend **the first for the migration commit, the second as an optional follow-up** — it keeps the
diff reviewable and the 600 cases moving as one unit. The assertion vocabulary differs (`t.eq` vs
`assertEqual`), so the shim's job is a name map, nothing more.

### A.4 Load-list derivation (CM-35)

`L.PURE_LAYER` becomes a **filter over the TOC derivation**, not a second list:

```lua
-- conceptual
local all  = Loader.tocFiles("ConsumableMaster.toc")     -- kit's, skips libs\ and directives
local pure = filter(all, function(p)                      -- drop the UI tail
    return not p:match("^settings/") and not p:match("^modules/")
end)
```

Then pin the derivation, per `testing-§9`:

1. the runner fed the loader **exactly** the TOC's files in the TOC's order (publish what it loaded
   through `Kit.expose`, compare against a fresh derivation);
2. every derived path **exists on disk**;
3. **no `libs/` path leaked in**.

Note the derived pure layer will change composition once workstream B lands (`DebugLogSetup` and
`PerfSetup` move from `modules/` to `core/`). Landing A **after** B avoids writing the filter twice.

**Keep as-is:** the explicit eight-entry `L.LIB_FILES` list. `testing-§9` requires vendored library
files to be spelled out explicitly in XML order precisely because `tocFiles` cannot see inside
`LibKa0s.xml`, and `tests/test_load.lua` already pins it against the XML. That is compliant and
should not be "simplified".

### A.5 Risks

- **The mock is the risk, not the framework.** `tests/wow_mock.lua` is 623 LOC against
  `mock_base.lua`'s 537. The overlap is large but not total; the extender must re-express the
  genuinely addon-specific keys (macro APIs, container/bag APIs, tooltip data, spec APIs) as
  per-key overwrites and **drop** everything `mock_base` already provides. Expect a red-then-green
  cycle — that is the migration working, not failing.
- **Fidelity regressions are silent.** `mock_base` deliberately models awkward behavior (AceDB's
  in-place `copyDefaults`, AceConsole's `Embed` clobbering a same-named `Print`, recording
  `RegisterUnitEvent` rather than no-opping it). If the extender overwrites one of those with a
  friendlier stub, a real bug becomes invisible. Review every overwrite against
  `tests/_kit/README.md`'s five fidelity rules before accepting it.
- **Mitigation:** migrate with the 600-case count as the gate. Any case that goes red is a genuine
  behavioral difference between the two mocks and must be understood, never papered over.

---

## Workstream B — Relocate the LibKa0s setup files (CM-44, CM-45, CM-46, CM-47)

### B.1 Target file map

| From | To | ID |
|---|---|---|
| `modules/DebugLog.lua` | `core/DebugLogSetup.lua` | CM-44 |
| `modules/PerfSetup.lua` | `core/PerfSetup.lua` | CM-45 |
| (inside `settings/Panel.lua:186-193` + descriptor) | `settings/OptionsSetup.lua` | CM-46 |
| (inside `core/SlashCommands.lua:1130-1408`) | `settings/Slash.lua` | CM-47 |

### B.2 Target TOC `# Core` order

```
core\Namespace.lua
core\ConsumableMaster.lua        -- (see CM-49 note below)
core\Bus.lua
core\Constants.lua               -- KCM.PREFIX, FONT_MONO path
core\CoreSetup.lua               -- KCM.Say / SafeToString  (after Constants)
core\State.lua                   -- KCM.State.debug          (before DebugLogSetup)
core\DebugLogSetup.lua           -- MOVED: after Constants + State + CoreSetup,
                                 --        before every module calling the sink
core\PerfSetup.lua               -- MOVED: after DebugLogSetup (its log/showLog hooks),
                                 --        BEFORE any bracket site's file
core\Compat.lua
core\Database.lua
core\Debug.lua
… (engine files unchanged) …
core\SlashCommands.lua           -- host verb bodies only, post-CM-47
```

Two positioning facts that decide this:

- `core/DebugLogSetup.lua` resolves its font path **eagerly** (`fontPath()` at construction, and the
  file says why — `lib:New` type-checks `font` and raises), so it needs LibSharedMedia loaded, which
  it is (`# Libraries`).
- `core/PerfSetup.lua`'s `log` / `showLog` hooks reach `KCM.DebugLog.AddLine` / `.Show`, so it must
  follow the DebugLog setup. Its `print` hook reaches `KCM.Say`, so it must follow `CoreSetup`.
  Both are satisfied by the slot above, and both are **call-time closures** anyway, so the
  constraint is soft in practice and hard in principle — keep the order.

### B.3 CM-46 — peeling `settings/OptionsSetup.lua`

Move out of `settings/Panel.lua`: the `LibStub("LibKa0s-Options-1.0", true)` lookup, the whole
descriptor literal (lines ~193-243), `UI.AceGUI` publication, and the lib-absent load-completing
branch. Move **in** the `Helpers.LSMValues` definition, because it is the one member the stub must
publish at load time (`options-ui-§1`'s documented exception) and it belongs beside the branch that
owns that contract.

`settings/Panel.lua` keeps: the schema half (`Resolve`, `Get`, `Set`, `FindSchema`,
`ValidateSchema`, `SetAndRefresh`, `validateSchemaValue`), `CreatePanel`, the host widget helpers
(`Button`, `ButtonPair`, `Label`, `Section`), `BuildAboutContent`, and the registration bootstrap.
Estimated post-split size: ~700 LOC.

TOC `# Settings` becomes:
```
settings\OptionsSetup.lua        -- NEW: the seam; before every page file
settings\Panel.lua
settings\Slash.lua               -- NEW: CM-47
settings\General.lua
settings\MacroBar.lua
settings\StatPriority.lua
settings\Category.lua
```

**Ordering caveat.** `options-ui-§1` wants `OptionsSetup` *"after the schema/slash files it reads"*.
Here the descriptor's `get`/`set` reach `Helpers.Get` / `Helpers.SetAndRefresh`, which live in
`Panel.lua` — but they are **closures resolved at call time**, so `OptionsSetup` can precede
`Panel.lua` safely. Keep them as closures; do not "optimize" them into direct references.

### B.4 CM-47 — peeling `settings/Slash.lua`

Move out of `core/SlashCommands.lua`: `COMMANDS` (`:1130-1241`), the `LibKa0s-Slash-1.0` lookup and
descriptor (`:1302-1352`), the degradation branch (`:1363-1370`),
`KCM.SlashCommands.GetLandingRows` (`:1401`), and `KCM:OnSlashCommand` (`:1406`).

`core/SlashCommands.lua` keeps the host verb bodies — `priority`, `stat`, `aio`, `bar`, `dump`,
`resync`, `rewritemacros`, their sub-tables (`PRIORITY_COMMANDS`, `STAT_COMMANDS`, `AIO_COMMANDS`,
`BAR_COMMANDS`) and `findCommand`. It publishes them on `KCM.SlashCommands` so
`settings/Slash.lua`'s `COMMANDS` triples can reference them. Estimated split: ~1100 LOC in `core/`,
~300 in `settings/`.

**Load-order constraint that survives:** `core/ConsumableMaster.lua:207-208` calls
`self:RegisterChatCommand("cm", "OnSlashCommand")` in `OnEnable`, and `OnSlashCommand` will now be
defined in `settings/Slash.lua`, which loads much later. That is fine — AceConsole resolves the
method **by name at dispatch time**, not at registration. Verify this explicitly with a test rather
than assuming it.

### B.5 Ripples every move must carry

- `tests/loader.lua`'s `PURE_LAYER` / the post-A derivation.
- `tests/test_perfsetup.lua:85,160` — both read `ConsumableMaster.toc` line by line looking for the
  PerfSetup entry; they will need the new path.
- `tests/test_libka0s.lua:84` — reads the TOC.
- `docs/file-index.md`, `docs/module-map.md`, `docs/ARCHITECTURE.md`, `docs/scope.md`,
  `docs/debug.md` — all name `modules/DebugLog.lua` and/or `modules/PerfSetup.lua`.
- In-file comments that cite sibling paths (`core/Debug.lua:32-33` names
  "37 lines above modules/DebugLog.lua" — that comment becomes wrong and must move with the file).

### B.6 Risks

- **Load-order regressions are silent, not loud.** A setup file that runs before its dependency
  produces a `nil` lookup, the host takes its stub, and the suite passes against the stub. The
  mitigation is `testing-§9`'s derivation pinning (workstream A) plus a case per seam asserting the
  instance is the **library's** object (`KCM.DebugLog.instance`, `Helpers.instance`,
  `KCM.SlashCommands.instance`, `KCM.Perf`) and not a stub. Three of these identity hooks already
  exist and were added for exactly this reason — use them.
- **`git mv`, not copy-delete**, so history follows the file.

---

## Workstream C — Close the performance surface

### C.1 CM-45 → CM-39: the bracket rewrite

Only after `core/PerfSetup.lua` loads first. Then, in `core/ConsumableMaster.lua` and
`modules/MacroBar.lua`:

```lua
local Perf = KCM.Perf                     -- file scope, load-time upvalue

local function doWork()
    local t0 = Perf.on and debugprofilestop()
    -- … the work …
    if t0 then Perf.Note("cooldown", debugprofilestop() - t0) end
end
```

**A design decision this forces.** Today `modules/PerfSetup.lua:36` does `if not lib then return end`
— it publishes **nothing** when the library is absent, and the brackets' `(perf and perf.on)` guard
is what makes that survivable. A bare `Perf.on` upvalue would raise on a degraded install. So the
move to the mandated shape **requires** a minimal stub, which `performance-§1` mandates anyway:

```lua
-- core/PerfSetup.lua, library-absent branch
KCM.Perf = { on = false, run = nil, suspended = false, Note = function() end,
             OnCommand = nil }        -- OnCommand deliberately nil; the `perf` verb
                                      -- already checks for it and says so (SlashCommands)
```

This closes a latent gap the current file's comment argues away ("nothing in this addon reads
KCM.Perf") — which is true only because the brackets guard defensively, and the guard is the thing
the standard is removing. Grep every `KCM.Perf` reader before finalizing the stub's member list:
today that is `core/ConsumableMaster.lua:268`, `modules/MacroBar.lua:322`, and
`core/SlashCommands.lua:1146,1149` (`OnCommand`). The stub must answer all of them.

### C.2 CM-38 — `tests/perf.lua`

Outside the green gate; **not** run by `tests/run.lua`. Asserts only deterministic quantities
(`performance-§9`): API call counts and bytes allocated per iteration, isolated by a full
`collectgarbage("collect")` either side of the measured loop. No wall-clock assertions.

Required scenario — **zero-overhead**: run the cooldown repaint path with `Perf.on = false` and pin
that it allocates no more than the same path with the instrumentation removed entirely. This is the
committed number `performance-§2` demands in place of a comment.

Suggested second and third scenarios (SHOULD, per-addon): the recompute pipeline pass, and the
tooltip-cache parse, which is the addon's other real per-item cost.

Its load list is **also** subject to `testing-§9` and, being ungated, is pinned by *reading its
source* for the derivation call.

### C.3 CM-40 — bucket-reached cases

In `tests/test_perfsetup.lua`, iterate the descriptor's declared bucket list rather than naming
buckets inline, so a bucket added later fails until it is driven:

```
for each declared bucket:
    arm capture, drive that bucket's genuine entry point, assert it accrued
```

`recompute` → fire `KCM.Pipeline.Recompute`. `cooldown` → drive the macro-bar cooldown repaint
(`tests/test_macrobar.lua` already builds that environment; reuse its setup rather than duplicating).

Per `testing-§12`, verify the *negative* case that already exists (`no bucket accrued with the
harness idle`) can actually fail — mutate the gate to always-on, watch it redden, revert from a `cp`
backup — and leave a `-- red under: …` comment.

### C.4 CM-41 / CM-42 / CM-43 — one lint line, two docs

- `.luacheckrc` `globals`: add `"ConsumableMasterPerfDB",  -- the perf capture ring (savedvariables-§4, performance-§5)`.
- `docs/performance.md`: bracketed paths and why; `/cm perf` workflow; how to read the report; what
  the harness can and cannot resolve. Lift the framing already written at
  `modules/PerfSetup.lua:8-15` — that the addon's expensive paths are deliberately out of combat and
  will never appear in a capture — it is the single most useful thing this page can say, and it is
  currently buried in a source comment.
- `docs/perf-runs/README.md`: naming (`<YYYY-MM-DD>-<source>-<label>.json`), schema summary,
  pointer to the library's canonical field-by-field contract. Commit the first real capture with it
  so the directory is not born empty.

---

## Workstream D — Finish the Options adoption (CM-36, CM-37)

### D.1 CM-36 — the host member becomes the instance

In the new `settings/OptionsSetup.lua`:

```lua
local optionsLib = LibStub and LibStub("LibKa0s-Options-1.0", true)
local Helpers
if optionsLib then
    Helpers = optionsLib:New({ … descriptor … })   -- the instance IS the member
    Helpers.AceGUI = KCM.AceGUI                    -- (CM-51)
else
    Helpers = {}                                    -- load-completing stub, below
end
KCM.Settings.Helpers = Helpers
```

Then **decorate in place** rather than copy across. The copied bindings at
`settings/Panel.lua:149,151,155,279,351,361,384,458,519,527,571` all disappear — the members are
already on the instance under the library's own names. Two consequences to handle deliberately:

1. **Name differences the addon deliberately maintained** — `Helpers.Grid` ↔ `UI.RenderGrid`,
   `Helpers.ResetScroll` ↔ `UI.ClearScroll`, `Helpers.CustomCheckbox` ↔ `UI.SessionCheckbox`,
   `Helpers.EnsureScroll` ↔ `UI.EnsureScroll`. Either sweep the ~40 call sites in `settings/*.lua`
   onto the library's names (**preferred** — one vocabulary, and a Ka0s reader recognizes it), or
   add thin aliases **on the instance**. Do not keep the copy-across shape to preserve the names.
2. **`Helpers.Section` must stay a wrapper.** `settings/Panel.lua:392-395` adds
   `ctx.lastGroup = label`, which the library only sets inside its own flow engine — an engine this
   addon does not use, because its pages draw rows by hand. Bound bare, every section after the
   first silently loses its top spacer. Keep the wrapper; hang it on the instance
   (`Helpers.Section = function(ctx, label) … end`, shadowing the library's), and keep the comment
   explaining why, because it is exactly the kind of thing a later reader "simplifies".
3. **`Helpers.instance = UI` becomes redundant** and should be deleted — the whole point is that
   `Helpers` *is* the instance, so an identity test asserts on `Helpers` directly. Same for the
   sibling hooks in `modules/DebugLog.lua` and `core/SlashCommands.lua`? **No** — leave those.
   Those two publish deliberate *facades* (documented at `modules/DebugLog.lua:12-17` — the
   library's `Toggle` inverts the host's meaning), which is a different and legitimate shape.
   Only the Options member is required to *be* the instance.

### D.2 CM-37 — delete the two restated constants

Remove `local SECTION_HEADING_H = 26` and `local BUTTON_PAIR_REL = 0.492`
(`settings/Panel.lua:74-75`); read `Helpers.SECTION_HEADING_H` and `Helpers.BUTTON_PAIR_REL` off the
instance at `settings/Panel.lua:502-503,711`. If either is not exposed by the current
`LibKa0s-Options-1.0` minor, add it upstream as an **additive** descriptor/instance field and
re-vendor — never keep the local copy as the workaround. Add a case asserting the host reads the
library's value, so a future re-introduction of a literal reddens.

### D.3 Risk

Low, but **visual**. Any mistake here changes pixel geometry on the settings pages and the suite
cannot see it. Follow with an in-game pass against `docs/smoke-tests.md`'s settings-panel section,
specifically the 50/50 button pairs (right button not shaved at the scroll clip) and the section
heading spacing.

---

## Workstream E — Housekeeping

- **CM-48** — move `KCM.dbDefaults` from `core/ConsumableMaster.lua:25` to `defaults/Profile.lua`,
  TOC-listed first in `# Defaults`. **Check for file-load readers before moving**: `defaults/` loads
  *after* `core/`, so anything in `core/` that reads `KCM.dbDefaults` at file scope breaks.
  `settings/MacroBar.lua:21-22` reads it at file load but is in `# Settings`, after `# Defaults` —
  safe. Consider a `defaults/Global.lua` for the `global` sub-table (which carries `schemaVersion`)
  only if it reads better; `savedvariables-§1` calls that file "rare; only when needed".
- **CM-49** — **decide, do not guess.** Reordering `core/` to `Compat → Constants → Namespace`
  requires `Compat.lua` and `Constants.lua` to run before the file that establishes `NS`, which is
  not obviously satisfiable. The likelier correct outcome is **an upstream standard correction**
  (`layout-§1`'s first three entries, plus its `settings/* → modules/*` tail contradicting
  `toc-file-§5`). Raise both to the user per `CLAUDE.md`'s deviation rule; if the standard stands,
  reorder and prove it with a load test.
- **CM-50** — one line: `CLAUDE.md:1` → `# CLAUDE.md — Ka0s Consumable Master`.
- **CM-51** — resolve AceGUI once, silently, in `settings/OptionsSetup.lua`
  (`KCM.AceGUI = LibStub("AceGUI-3.0", true)`); `settings/Panel.lua:19`,
  `settings/StatPriority.lua:23`, `settings/Category.lua:29` read `KCM.AceGUI` and guard their
  render paths. Add a degraded-load case: with AceGUI absent the addon loads, the CLI answers, and
  the panel says one honest line.
- **CM-52** — narrow `.luacheckrc`'s `ignore` to `212/self`, `212/event`; inline-suppress `542`,
  and **fix** the `241` case (`TooltipCache.pendingIDs` populated but never read) rather than
  suppressing it repo-wide.
- **CM-53** — sweep retired `§N.M` refs to `filename-§N` (six known sites in `03_EVIDENCE.md`).
- **CM-54** — resolved incidentally by CM-46 + CM-47.
- **CM-55 / CM-56 / CM-57** — user's call; each is a one-line or one-decision change.

---

## Cross-cutting risks

1. **Green-but-wrong.** Every structural move in workstreams A and B can leave the suite green while
   testing a degradation stub. The single most valuable guard is the `testing-§9` derivation pinning
   in A.4 plus an "is this the library's object?" case per seam. **Land A's pinning before B's
   moves** if at all possible, even though A's mock migration is the larger job — the pinning cases
   are independent of the mock swap and can go first.
2. **Two write paths.** CM-36's rewrite touches the `get`/`set` descriptor seam. Re-assert after the
   change that a panel checkbox and `/cm set <path>` still take the same route through
   `Helpers.SetAndRefresh` — the tests at `tests/test_settingsui.lua` and `tests/test_slash.lua`
   cover this and must both stay green.
3. **Nothing here touches CM-30.** The English tooltip parsing is deliberately out of scope for
   remediation; it is a documented, tracked deviation and a planned feature, not a defect.
