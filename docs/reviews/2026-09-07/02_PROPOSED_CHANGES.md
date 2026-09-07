# 02 — Proposed changes (HLD + LLD)

**Standard resolved:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)**.
**Standards cross-check: PARTIAL.** The index and six section files (`anti-patterns`, `testing`,
`options-ui`, `architecture`, `library-stack`, and `STANDARDS.md` itself) were fetched verbatim with
`curl` and read. `performance.md` and the remaining section files **timed out** on this network and
were not re-read today; every rule cited from an un-fetched section is marked
*(rule not re-verified today)* at its point of use. No rule below is quoted from memory.

Every change targets this addon's own files. **Nothing in this document edits a path under `libs/` or
`tests/_kit/`.**

---

## HLD — themes

### Theme A — Put the migration version at the scope of the data it guards

*Covers `CM-R-01`, and the test work in `CM-R-14`.*

`core/Database.lua` is a well-shaped migration runner with one crossed wire: the **gate** is
account-wide (`db.global.schemaVersion`) and the **effect** is per-profile (`db.profile.macroBar`).
That single mismatch makes the first migrated profile the only migrated profile, forever, and it
makes the `OnProfileChanged` re-run at `core/ConsumableMaster.lua:401-412` — which somebody
deliberately wired for exactly this case — structurally incapable of firing.

The fix is to split the version, not the runner. Steps that touch `db.profile` gate on
`db.profile.schemaVersion`; steps that touch `db.global` keep the account-wide one. The existing
profile callback then does real work, and a profile the player has never activated migrates the
moment they switch to it.

**Alternatives considered and rejected.**

- *Iterate `db.profiles` from the global runner and migrate them all at once.* Rejected: it reaches
  past AceDB's own profile abstraction into its raw store, it cannot see a profile created after the
  upgrade, and `savedvariables` frames the migration runner as operating on the **live** db (rule not
  re-verified today). The callback-driven shape needs no such reach.
- *Fold the profile version into `db.profile` and drop `db.global.schemaVersion` entirely.*
  Rejected: `savedvariables` puts the schema version account-wide and `tests/test_database.lua:56-63`
  pins it there. Both keys are legitimate; what is wrong is one key doing two jobs.
- *Leave it and just re-map `labelOutline` in `defaults/Profile.lua`.* Rejected outright — that is a
  guard scattered outside the runner, which is the shape the runner's own header
  (`core/Database.lua:4-7`) says it exists to end.

**Trade-off.** A second version key is one more thing to remember when adding a migration. Mitigated
by making `RunMigrations` read both and by the multi-profile characterization test in Theme D, which
reddens the moment a new step is gated on the wrong one.

### Theme B — Finish routing display strings through `NS.L`

*Covers `CM-R-02`.*

224 distinct `L[...]` keys resolve cleanly today (0 missing, 0 unused). Six literals in the two custom
AceGUI widgets under `modules/` are the entire remaining gap, and they are there because those two
files were written before the page files adopted the seam, not because anyone decided against it.
`localization` requires the metatable-fallback `NS.L` with English-string keys, which is exactly what
`locales/enUS.lua:16` already provides (rule not re-verified today).

**Alternatives considered and rejected.** *Record an English-only deviation row instead of routing.*
`localization` offers two terminal states — strings routed, or an English-only decision recorded — but
this addon has already chosen the first everywhere else, and a deviation row covering six strings out
of 230 would document an inconsistency rather than a decision.

### Theme C — Make the seam guards say what they guard

*Covers `CM-R-03`, `CM-R-05`, `CM-R-13`.*

Three small divergences in the LibKa0s adoption's own half. `CORE_SEAM` has fallen one member behind
`core/CoreSetup.lua`; the two `colorDecode` codecs handed to two different majors disagree about a
missing channel; and a paragraph in the parity suite is pasted twice.

The colour one is the only behavioural item, and its fix direction is constrained: `options-ui`
requires the panel's colour controls to be built by the library from a descriptor, and
`anti-patterns` #47 forbids re-implementing a widget maker locally — so the remedy is **one shared
decoder passed to both descriptors**, never a second local colour renderer.

### Theme D — Close the coverage gap under the High finding, and stop the guards lying

*Covers `CM-R-14`, and the regression pressure from Theme A.*

`docs/test-cases.md` claims 18 `test_database.lua` cases; none of them involves a second profile, so
`CM-R-01` sits under coverage the inventory reads as complete. A characterization case pinning
today's (wrong) behaviour goes in **before** the Theme A change, per `testing`'s rule that a
behaviour-preserving refactor is preceded by a characterization test — here the behaviour is
deliberately *not* preserved, so the case is written red-first and flipped in the same change.

### Theme E — Comment hygiene

*Covers `CM-R-04`, `CM-R-07`, `CM-R-13`.*

Eight of fourteen `file:line` citations no longer resolve, and three `KCM.Debug` sites use a format
verb `docs/debug.md:30` forbids. Both are cheap, both are pure text, and both make the next reader's
pass slower for no return.

### Theme F — Deferred, recorded, not proposed

`CM-R-06` (stale `RESULTS.md`) regenerates at **release**, never here — `automated-tests` puts the
checkpoint at the tag. `CM-R-08` (line-ending stragglers) belongs to `/wow-addon:standards-audit`'s
roll-up. `CM-R-09` (`RequestRefresh` timer churn) has no measurement behind it and no scenario that
would show the improvement, so proposing it now would be an assertion; it is written up in
`04_EXECUTION_PLAN.md` as a milestone that starts with adding the scenario. `CM-R-10`, `CM-R-11` and
`CM-R-12` are notes with no change attached.

---

## Upstream change-set

**Empty for this review.** No defect was found in `libs/LibKa0s/` or `tests/_kit/`; both payloads are
byte-identical to LibKa0s v1.25.0, the tag `CLAUDE.md:58` names, and `tests/test_vendor_sync.lua`
confirms it on both cases today.

Two upstream items are **already filed and already worked around correctly**, and are listed only so
the cross-repo work is not lost:

| Item | Owning repo | File | Status |
|---|---|---|---|
| `OptionsCompose` media rows double-wrap `LSMValues`, rendering an empty dropdown | `LibKa0s` | `LibKa0s/OptionsCompose.lua` | Filed **issue #15**. Worked around at `settings/MacroBar.lua:108-124`; the workaround and its three `values = lsmValues(...)` overrides come out in the same commit as the re-vendor that carries the fix. |
| `ERR_BOOL` / `ERR_ALLOWED` / `ERR_COLOR` cannot be overridden — the emitting parsers sit above `lib:New` and read `lib.STRINGS` directly | `LibKa0s` | `LibKa0s/Slash.lua` | Filed **issue #16**. The three dead overrides are kept at `settings/Slash.lua:246-254` as a record of intended wording. |

Neither is to be patched in `libs/`. When either lands upstream: bump the file's LibStub minor, tag
LibKa0s, re-vendor the **whole** folder into this addon (and every other consumer) as its own commit,
and drop the local workaround in that same commit.

---

## LLD — change-set

### C-01 — Split the migration version by scope

**Findings:** `CM-R-01`. **Files:** `core/Database.lua`.

Before (`core/Database.lua:66-90`, abridged):

```lua
function D.RunMigrations()
    local db = KCM.db
    if not (db and db.global) then return end
    local g = db.global
    g.schemaVersion = g.schemaVersion or 1
    local from = g.schemaVersion

    if g.schemaVersion < 2 then D.MigrateMacroBarV2(db.profile);   g.schemaVersion = 2 end
    if g.schemaVersion < 3 then D.MigrateLabelFlagsV3(db.profile); g.schemaVersion = 3 end
    g.schemaVersion = D.CURRENT_SCHEMA
```

After (shape, not final text):

```lua
-- The ACCOUNT version stays: it is what savedvariables puts in db.global, and
-- what tests/test_database.lua pins. What is new is the PROFILE version, and the
-- reason is the whole of CM-R-01: every step below writes into db.profile, so a
-- gate read out of db.global migrates the profile that happened to be active and
-- leaves every other one past the gate forever.
function D.RunMigrations()
    local db = KCM.db
    if not (db and db.global) then return end
    D.RunAccountMigrations(db.global)
    if db.profile then D.RunProfileMigrations(db.profile, db.global) end
end

function D.RunProfileMigrations(profile, global)
    profile.schemaVersion = profile.schemaVersion or inferProfileVersion(profile, global)
    if profile.schemaVersion < 2 then D.MigrateMacroBarV2(profile);   profile.schemaVersion = 2 end
    if profile.schemaVersion < 3 then D.MigrateLabelFlagsV3(profile); profile.schemaVersion = 3 end
    profile.schemaVersion = D.CURRENT_SCHEMA
end
```

`inferProfileVersion` is the load-bearing piece and must be written with its reasoning inline: a
profile that carries no `schemaVersion` is either **brand new** (AceDB just injected the current
defaults — nothing to migrate) or **pre-split** (it was there before this change and may need every
step). The two are told apart by evidence in the profile itself — a `macroBar.labelOutline` key means
pre-v3; an absent `macroBar` table means pre-v2; neither means the profile matches current defaults
and starts at `D.CURRENT_SCHEMA`. Getting this wrong in the "brand new" direction is harmless
(idempotent steps re-run); getting it wrong in the "pre-split" direction is the bug this change
exists to remove, so the inference is deliberately biased toward re-running.

`D.CURRENT_SCHEMA` stays 3 — the shape of the stored data does not change, only where the applied
marker lives.

**Risk.** Medium. It touches the one path that runs before any other addon code reads the profile,
and it changes what happens on a profile switch (from nothing to a real pass). Mitigated by C-05's
characterization cases and by the migrations already being idempotent by construction
(`core/Database.lua:30-33`, `:56-58`).

**Standards conformance.** Keeps the single ordered migration home `savedvariables` asks for and adds
no second guard anywhere else (rule not re-verified today). It does **not** touch `defaults/Profile.lua`,
which stays the sole declaration site for shipped defaults. The rejected alternative — walking
`db.profiles` from the global runner — was rejected in part because it would put migration logic
outside the runner's own scope contract.

**Regression pressure.** Adds 3-4 cases to `tests/test_database.lua`. `docs/test-cases.md` and the
README `[Tests]` badge move from **749** in the same change (`testing`).

### C-02 — Route the six widget strings through `L`

**Findings:** `CM-R-02`. **Files:** `modules/KCMMacroDragIcon.lua`, `modules/KCMItemRow.lua`.

Add `local L = KCM.L` beside each file's existing `local _, NS = ...` / `local KCM = NS` header, then:

| Site | Before | After |
|---|---|---|
| `KCMMacroDragIcon.lua:74` | `SetText("\|cff999999Macro not created yet\|r")` | `SetText("\|cff999999" .. L["Macro not created yet"] .. "\|r")` |
| `KCMMacroDragIcon.lua:77` | `SetText("\|cffffd100Drag to action bar\|r")` | `SetText("\|cffffd100" .. L["Drag to action bar"] .. "\|r")` |
| `KCMItemRow.lua:171/173/175` | `SetText("MH+OH")` / `"MH"` / `"OH"` | `L["MH+OH"]` / `L["MH"]` / `L["OH"]` |
| `KCMItemRow.lua:228` | `SetText("[Loading]")` | `L["[Loading]"]` |

The colour escapes stay **outside** the key. A translator must never be handed `|cffffd100` to
preserve, and `localization` forbids concatenating translated *fragments* — a colour code is not a
fragment, it is markup, so this is the compliant split rather than a violation of it (rule not
re-verified today).

No rows are added to `locales/enUS.lua`: the identity metatable at `locales/enUS.lua:16` already
answers every one, and that file's own header says rows go in only when a display string must differ
from its key.

**Risk.** Low — the rendered English is byte-identical.

**Standards conformance.** Satisfies `localization`'s routing SHOULD without adding a
locale file or a deviation row.

### C-03 — One colour decoder, passed to both descriptors

**Findings:** `CM-R-05`. **Files:** `core/CoreSetup.lua` (new export), `settings/OptionsSetup.lua:101-104`,
`settings/Slash.lua:295-298`.

Publish the decoder beside `KCM.SwatchColor`, which is already the addon's one colour resolver, and
have it return `nil` for an absent channel rather than inventing a value:

```lua
-- ONE decoder for the positional { r, g, b, a } this addon stores. It answers
-- nil for a channel that is not there, deliberately: what a missing channel
-- should fall back to is a per-SURFACE question (the bar backdrop's is black at
-- 50%, not white), and KCM.SwatchColor is where that answer already lives. Two
-- decoders that each guessed a default is what CM-R-05 was.
function KCM.ColorDecode(c)
    if type(c) ~= "table" then return nil, nil, nil, nil end
    return c[1], c[2], c[3], c[4]
end
```

Both descriptors then pass `colorDecode = KCM.ColorDecode`. **Before merging, confirm against the
vendored `LibKa0s/Options.lua` and `LibKa0s/Slash.lua` that each major tolerates a nil channel from
`colorDecode`.** If either does not, the compliant direction is an **additive** upstream change to the
library so every consumer gets it — not a second local decoder, and not a patch under `libs/`
(`anti-patterns` #63). If that check fails, C-03 is deferred and re-filed as an upstream item.

**Risk.** Low-to-medium, entirely concentrated in the nil-tolerance question above. Unreachable on a
default profile either way (`CM-R-05`'s reachability line).

**Standards conformance.** Keeps both colour surfaces library-rendered. Explicitly does **not**
re-implement a widget maker locally, which `options-ui`'s seam rules and `anti-patterns` #47 forbid.

### C-04 — Complete and correct the parity guard

**Findings:** `CM-R-03`, `CM-R-13`. **Files:** `tests/test_surface_parity.lua`.

1. Add `"MakeCloseButton"` to `CORE_SEAM` (`:44-52`).
2. Add a `CORE_LIVE_ONLY = { "MakeCloseButton" }` list and pass it as the fourth argument to
   `assertSurfaceParity`, carrying the argument already written at `tests/test_coresetup.lua:200-207`
   — the wrapper only exists so a future modal draws the shared mark, and the degraded branch
   returns before publishing it.
3. Re-derive the three stale line numbers in the same comment: `IsConcatSafe` is `core/CoreSetup.lua:87`,
   `SafeToString` `:88`, `Say` `:138`.
4. Delete the duplicated paragraph at `:169-174`, keeping the copy at `:182-186` that leads into the
   "what is NOT on this list" argument.

**Risk.** None to shipped code. Case count is unchanged, so `docs/test-cases.md` does not move.

**Standards conformance.** This *is* `testing`'s stub-surface parity case; the change restores it to
covering the whole seam.

### C-05 — Characterization + regression cases for the migration scope

**Findings:** `CM-R-01`, `CM-R-14`. **Files:** `tests/test_database.lua`.

New cases, each written to go red under a named mutation:

1. *"Database: a profile that was not active when the account was stamped still migrates"* — stamp
   the account at 3, hand `RunMigrations` a profile carrying `macroBar.labelOutline = false` and no
   `labelFlags`, assert `labelFlags == ""` and `labelOutline == nil`.
   `-- red under: gating the v3 step on db.global.schemaVersion`.
2. *"Database: a profile already at the current schema is not re-migrated"* — the idempotence half,
   so case 1 cannot be satisfied by simply running every step unconditionally.
   `-- red under: dropping the profile-version guard`.
3. *"Database: OnProfileChanged migrates the profile switched to"* — drive the callback registered at
   `core/ConsumableMaster.lua:410` and assert the newly-active profile came forward.
   `-- red under: the account-wide gate, which makes that callback inert`.
4. Rename `tests/test_database.lua:56-63` to describe what it asserts — *"Database.RunMigrations
   leaves unrelated profile settings alone and keeps the ACCOUNT version out of the profile"* — and,
   with C-01 landed, extend it to assert `db.profile.schemaVersion` is now **set** rather than nil.

Case 4 changes an existing case name, so `docs/test-cases.md` and the README `[Tests]` badge move in
this same change, not as a follow-up.

**Risk.** None to shipped code.

**Standards conformance.** `testing` — characterization before a behaviour change, negative
assertions carrying their falsification, and the inventory moving with the count.

### C-06 — `%s` in the three `KCM.Debug` format strings

**Findings:** `CM-R-07`. **Files:** `settings/Category.lua:764`, `modules/Selector.lua:610`, `:655`.

`"paint %s rows=%d spec=%s"` → `"paint %s rows=%s spec=%s"`, and the two `"%d -> %d"` pairs likewise.
The seam already ran every argument through `KCM.SafeToString` (`core/Debug.lua:44-53` on the fallback
path, the library's `D.Debug` on the live one), so the rendered line is unchanged.

**Risk.** None. **Standards conformance.** Restores the invariant `docs/debug.md:30` states and
`debug-logging`'s secret-safe sink requires (rule not re-verified today).

### C-07 — Re-derive or de-number the stale comment citations

**Findings:** `CM-R-04`. **Files:** `core/DebugLogSetup.lua:93`, `:113`; `modules/MacroBarButton.lua:115`,
`:146`; `tests/test_defaults.lua:75`; `tests/test_surface_parity.lua:47-49`, `:84`, `:126`.

Prefer the **symbol** over the number wherever the name is unambiguous — "`core/PerfSetup.lua`'s `log`
thunk", "`settings/Slash.lua`'s `KCM.SlashCommands.instance`", "`settings/General.lua`'s Defaults
action". Keep a number only where the reference is genuinely positional, and re-derive it in this
pass. The five citations listed as correct in `01_FINDINGS.md` are left alone.

**Risk.** None — comments only.

**Standards conformance.** No rule compels a citation format; this is a maintainability change with no
standards surface.

---

## Standards conformance — summary

| Change | Introduces a new deviation? | Rules that shaped it |
|---|---|---|
| C-01 | No | `savedvariables` (single migration home, account-wide schema version) *(not re-verified today)* |
| C-02 | No | `localization` (metatable `NS.L`, English-string keys, no fragment concatenation) *(not re-verified today)* |
| C-03 | No | `options-ui` (library-rendered colour controls), `anti-patterns` #47 (no local widget maker), #63 (no patch under `libs/`) |
| C-04 | No | `testing` (stub-surface parity case) |
| C-05 | No | `testing` (characterization first; inventory + badge move in the same change) |
| C-06 | No | `debug-logging` / `docs/debug.md:30` *(not re-verified today)* |
| C-07 | No | none — maintainability only |

No change targets a path under `libs/` or `tests/_kit/`. No change proposes a local re-implementation
of anything LibKa0s provides. No change proposes editing or deleting a test to turn a suite green, or
hand-editing `docs/test-cases.md`, `docs/performance.md` or `docs/automated-tests/RESULTS.md`.

## Expected movement for the next release's regeneration

- **Test count:** 749 → ~752-753 (C-05 adds three cases; C-04 adds none; C-05's rename moves one
  line in the inventory without changing the count). `docs/test-cases.md` and the README badge move in
  the same commits.
- **Complexity:** C-01 splits `D.RunMigrations` into three smaller functions, which should move
  `RunMigrations` **down** from its current position and put nothing new near the cap. None of the six
  functions at CCN 15 (`CM-R-12`) is touched by any change here. A note for the next release's
  regeneration to confirm — **not** a reason to run `lizard` into the repo now.
- **Perf:** no change here touches a bracketed path or a declared bucket, so neither
  `docs/performance.md` nor `docs/perf-analysis/` is expected to move.
