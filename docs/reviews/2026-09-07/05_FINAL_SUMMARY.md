# 05 — Final summary

> **Written ahead of implementation.** This is the artifact to paste into the PR **once
> `03_SMOKE_TESTS.md` has been executed and its sign-off table is filled in**. Until then, treat the
> counts below as the plan's intent, not as a record of what shipped. Anything deferred at
> implementation time must be moved into *Known follow-ups* before this document is used.

---

## Headline

Ka0s Consumable Master's 2026-09-07 review found the addon green on every out-of-game suite and its
LibKa0s adoption in good order — both vendored payloads byte-identical to the v1.25.0 tag, both
declared perf buckets reached by real gated brackets, and the degraded-install paths exercised by
genuine library-absent loads rather than hand-stubs. One structural defect was worth fixing: the
SavedVariables migration runner gated per-profile work on an **account-wide** version key, so on an
account with more than one profile only the profile that happened to be active at the upgrade was ever
migrated — and every future migration inherited the same silent skip. That is now split by scope, and
the profile-switch callback that was already wired for the case finally does something. Alongside it:
six display strings in two custom widgets joined the localization seam every other file already uses,
the stub-parity guard was brought back level with the seam it guards, and a run of stale comment
citations and forbidden format verbs was cleaned up.

---

## Counts

`Critical fixed: 0, High fixed: 1, Medium fixed: 5, Low fixed: 2`

**Deliberately deferred, with reasons:**

| ID | Why deferred |
|---|---|
| `CM-R-06` | `docs/automated-tests/RESULTS.md` regenerates at **release**, not mid-cycle. `automated-tests` puts the checkpoint at the tag; a hand-edited report reads as measured and is worse than a stale one. |
| `CM-R-08` | Line-ending stragglers are `/wow-addon:standards-audit`'s roll-up, not a review's. Seven tracked files sit LF against `* text=auto eol=crlf`; `git add --renormalize .` fixes the index, not the working tree. |
| `CM-R-09` | No measurement behind it and no scenario that would demonstrate the fix. Taking it up starts with a `tests/perf.lua` scenario over the panel-refresh burst, not with an edit to `settings/Panel.lua`. |
| `CM-R-10` | `KCM.MakeCloseButton` is deliberately dead — the wrapper exists so a future window draws the shared mark, and `standalone-windows` wants exactly this shape. Kept, and now recorded as data on the parity ignore list. |
| `CM-R-11` | `Settings.RegisterAddOnCategory` runs on `PLAYER_LOGIN` / `ADDON_LOADED`; no shipping configuration reaches it in combat. |
| `CM-R-12` | Six functions at exactly CCN 15 — informational, a release-gate note, no change attached. |
| `CM-R-05` | **Conditional.** Shipped if T-7.0 cleared; if either vendored major rejects a nil channel from `colorDecode`, this was escalated upstream instead. *Fill in which happened before using this document.* |

---

## Changes by theme

### Theme A — The migration version now sits at the scope of the data it guards

**What changed.** `core/Database.lua`'s runner splits into an account pass and a profile pass. Steps
that write into `db.profile` gate on a new `db.profile.schemaVersion`; `db.global.schemaVersion` keeps
its account-wide job. A profile that has never been active migrates the moment the player switches to
it, through the `OnProfileChanged` callback that was already registered for exactly this.

**Why it mattered.** On any account with two or more profiles, the first login after the schema v3
bump migrated one profile and stamped the account. Every other profile kept `macroBar.labelOutline`
and never received `macroBar.labelFlags`, so AceDB's shipped `"OUTLINE"` default painted over a stored
`labelOutline = false` — the player's choice silently replaced, which is the exact outcome the v3
migration was written to prevent. The durable half was worse: the same skip would have swallowed every
future per-profile migration, and the profile callback at `core/ConsumableMaster.lua:401-412` was
structurally incapable of firing.

**Finding IDs:** `CM-R-01`, `CM-R-14`. **Change IDs:** C-01, C-05.

**Files touched:**
- `core/Database.lua`
- `tests/test_database.lua`
- `docs/test-cases.md` *(regenerated)*
- `README.md` *(badge)*

### Theme B — The last six display strings joined the localization seam

**What changed.** `modules/KCMMacroDragIcon.lua` and `modules/KCMItemRow.lua` take `local L = KCM.L`
and route their six literals through it. Colour escapes stay outside the key, so a translator is never
handed `|cffffd100` to preserve.

**Why it mattered.** 224 `L[...]` keys already resolved cleanly across the addon; these two widgets
were the only files that never adopted the seam, and their strings — the drag-icon label every Macros
tab heads with, the `[Loading]` placeholder, the weapon-enchant hand tags — would have been invisible
to any locale file dropped in later. No rendering changed; the gap closed.

**Finding IDs:** `CM-R-02`. **Change IDs:** C-02.

**Files touched:**
- `modules/KCMMacroDragIcon.lua`
- `modules/KCMItemRow.lua`

### Theme C — The seam guards say what they guard

**What changed.** `tests/test_surface_parity.lua`'s `CORE_SEAM` gained `MakeCloseButton` — a live
member its own documented grep returns — with a `CORE_LIVE_ONLY` ignore list carrying the argument for
why the degraded branch withholds it. Three stale line numbers in the same comment were re-derived, and
a paragraph that had been pasted twice was cut. *(If C-03 shipped:)* the two disagreeing `colorDecode`
codecs collapsed into one `KCM.ColorDecode` that answers `nil` for an absent channel, leaving the
per-surface fallback where it already belonged, in `KCM.SwatchColor`.

**Why it mattered.** The parity suite's stated doctrine is that a deliberate omission must be encoded
as **data**, because otherwise it is indistinguishable from a bug. `MakeCloseButton` was encoded by
silence. The two colour codecs would have disagreed the first time a colour row shipped without a
default — one rendering white, the other black, for the same stored setting.

**Finding IDs:** `CM-R-03`, `CM-R-05`, `CM-R-13`. **Change IDs:** C-03, C-04.

**Files touched:**
- `tests/test_surface_parity.lua`
- *(C-03, if shipped)* `core/CoreSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua`,
  `tests/test_coresetup.lua`, `tests/test_slashsetup.lua`

### Theme D — Comment and format hygiene

**What changed.** Eight `file:line` citations that no longer resolved were re-derived or replaced with
symbol references. Three `KCM.Debug` call sites moved from `%d` to `%s`.

**Why it mattered.** This addon's comments are load-bearing — several are the only record of why a TOC
position or a withheld stub member is what it is — and 57% of the numeric citations pointed at the
wrong line, in one case at a bare `end`. The `%d` sites violated `docs/debug.md:30`'s own rule: the
sink stringifies every argument through `KCM.SafeToString` first, so the day one of those arguments is
a value that renders as `"<secret>"`, `string.format` raises.

**Finding IDs:** `CM-R-04`, `CM-R-07`. **Change IDs:** C-06, C-07.

**Files touched:**
- `settings/Category.lua`
- `modules/Selector.lua`
- `core/DebugLogSetup.lua`
- `modules/MacroBarButton.lua`
- `tests/test_defaults.lua`
- `tests/test_surface_parity.lua`

---

## API / behaviour changes

- **No new, renamed or removed slash subcommands.** `COMMANDS` still carries the same seventeen verbs
  and `KCM.COMMANDS` is unchanged.
- **No new, removed or renamed settings paths.** Every `/cm get|set` path is what it was.
- **No new or removed shipped defaults.** `defaults/Profile.lua` is untouched.
- **No locale keys added to `locales/enUS.lua`.** Six new `L[...]` *lookups* appear in
  `modules/`, all answered by the identity metatable at `locales/enUS.lua:16`.
- **One behaviour change, and it is the point of the work:** switching to an AceDB profile that
  predates a migration now runs that migration. Previously the switch was silently inert.
- **One internal export added:** `KCM.ColorDecode` *(only if C-03 shipped)*.

---

## SavedVariable / migration notes

`D.CURRENT_SCHEMA` **stays at 3** — no stored shape changed. What moved is *where the applied marker
lives*.

| | Before | After |
|---|---|---|
| Account marker | `db.global.schemaVersion` (gated everything) | `db.global.schemaVersion` (gates account-wide steps only) |
| Profile marker | *none* | `db.profile.schemaVersion` (gates every step that writes into the profile) |

**Migration path.** Automatic, no player action. On the next login each profile is inspected: one
already matching current defaults is stamped at `D.CURRENT_SCHEMA` and left alone; one carrying
evidence of an older shape (`macroBar.labelOutline` present, or `macroBar` absent) is run through the
steps it missed. The inference is deliberately biased toward re-running, because the steps are
idempotent by construction and a false "already current" is the failure this change exists to remove.

**No `/cm resetall` is required**, and none should be recommended — it would discard the priority
lists and stat overrides this change is unrelated to.

---

## Deprecated-API migrations

**None.** No deprecated or removed API was found. The sweep confirmed the modern forms are already in
use and the seams are correct:

| Concern | Where it is handled |
|---|---|
| `GetSpecialization*` → `C_SpecializationInfo.*` | `core/Compat.lua:16-51`, modern-first with legacy fallback |
| `GetSpellInfo` → `C_Spell.GetSpellName` / `C_Spell.GetSpellInfo` | `core/Compat.lua:66-82` |
| `GetContainerNumSlots` / `GetContainerItemInfo` → `C_Container.*` | `core/BagScanner.lua:27-28` |
| `GetAddOnMetadata` → `C_AddOns.GetAddOnMetadata` | `core/EnvSetup.lua:68-77`, behind `LibKa0s-Env-1.0` |
| `SetBackdrop` requiring `BackdropTemplate` | every `SetBackdrop` target is created with the template (`modules/MacroBar.lua:126`, `:152`; `modules/MacroBarButton.lua:416`; `modules/MacroBarFlyout.lua:209`, `:249`) |
| `InterfaceOptions_AddCategory` | absent; `Settings.RegisterCanvasLayoutCategory` + `RegisterAddOnCategory` at `settings/Panel.lua:866-867`, and `Settings.OpenToCategory` is passed a numeric `categoryID` from `main:GetID()` (`:874`), not a frame |
| Combat "secret" values | `Compat.IsSecret` at `core/Compat.lua:60-63`; `core/MacroDisplay.lua:115-128` reads only the `NeverSecret` `isActive`/`isEnabled` fields and hands the opaque duration object straight back, and `modules/MacroBarButton.lua:185-188` prefers `SetCooldownFromDurationObject` over raw `SetCooldown` |

Bare `GetItemInfo` / `GetItemInfoInstant` / `GetItemCount` remain deliberately unwrapped; the decision
and its reasoning are recorded at `.luacheckrc:79-83` — they are live retail globals, not deprecated
ones.

---

## Performance impact

**None measured, and none claimed.** No change in this cycle touches a bracketed path, a declared perf
bucket or an `OnUpdate` handler, so neither `docs/performance.md` nor `docs/perf-analysis/` is expected
to move.

For the record, the offline runner's figures on the day of the review (2026-09-07, single run, one
machine — orientation only, never comparable across machines):

| Scenario | ms/iter | bytes/iter |
|---|---:|---:|
| `recompute` | 0.91893 | 7597.6 |
| `cooldownRefresh` | 0.01808 | 6000.0 |
| `probeOverheadOff` | 0.01811 | 6000.0 |
| `probeOverheadOn` | 0.01864 | 6001.3 |

The zero-overhead property holds: the dormant arm allocates exactly `cooldownRefresh`'s 6000.0
bytes/iter, against the 6144 ceiling `tests/perf.lua` pins, and the armed arm adds 1.3.

The one committed in-client capture, `docs/perf-analysis/20260807-132029/`, records the `cooldown`
bucket at **352 calls / 42.72 ms total / 0.2397 ms max over 24.0 s active** — cited as dated, and left
exactly as it was found.

---

## Test and complexity movement

| | Before | After |
|---|---:|---:|
| Test cases | **749** | **~752** *(C-05 adds three; C-04 adds none)* |
| Failing | 0 | 0 |
| `luacheck` | 0 warnings / 0 errors, 59 files | unchanged |
| `lizard` warnings | 0 | 0 |
| Max CCN | 15 | expected ≤ 15 |

`docs/test-cases.md` was regenerated with `lua tests/run.lua --list > docs/test-cases.md` and the
README `[Tests]` badge moved to the same number **in the same commit** as the case that moved it.
Neither was hand-edited.

**Watch-list movement for the next release's regeneration to confirm** (not run here): C-01 splits
`D.RunMigrations` into three smaller functions, which should move it **down**. None of the six
functions currently sitting at exactly CCN 15 — `itemCooldown` (`core/MacroDisplay.lua:102-114`),
`availableForHands` and `S.PickBestForSlot` and `S.SweepStaleDiscovered` (`modules/Selector.lua`),
`applyBackdrop` (`modules/MacroBar.lua:217-244`), `Helpers.BuildAboutContent`
(`settings/Panel.lua:763-824`) — is touched by any change in this cycle. They are worth knowing about
because `automated-tests`' release gate is *zero CCN > 15*, so any one added `and`/`or` in any of them
reddens the tag.

---

## Known follow-ups

| Item | Why it was left |
|---|---|
| `CM-R-06` — `RESULTS.md` stale by 51 cases, 1762 NLOC and 185 functions, and its prose two rows behind its own table | Regenerates at release. Move the `## Test suite` / `## Lint` narrative onto the newest row in the same change. |
| `CM-R-08` — seven tracked files LF against a CRLF pin, two of them client-shipped (`ConsumableMaster.toc`, `core/SlashCommands.lua`) | `/wow-addon:standards-audit`'s roll-up. `git add --renormalize .` fixes the index; the working tree needs rewriting separately. |
| `CM-R-09` — `O.RequestRefresh` allocates a closure and a timer per call (~150 during the first-open item burst) | Unmeasured. Add the scenario before the fix, not after. |
| `CM-R-12` — six functions at exactly CCN 15 | Informational. Worth a glance whenever any of the six is next edited. |
| **LibKa0s issue #15** — `OptionsCompose` double-wraps `LSMValues`, rendering an empty media dropdown | Upstream. Worked around at `settings/MacroBar.lua:108-124`; the workaround and its three `values = lsmValues(...)` overrides come out in the same commit as the re-vendor that carries the fix. |
| **LibKa0s issue #16** — parsers above `lib:New` read `lib.STRINGS` directly, so `ERR_BOOL` / `ERR_ALLOWED` / `ERR_COLOR` overrides cannot reach them | Upstream. The three dead overrides stay at `settings/Slash.lua:246-254` as a record of intended wording. |
| `CM-R-05` **if T-7.0 escalated** | If either vendored major rejects a nil channel from `colorDecode`, the compliant direction is an **additive** upstream change so every consumer benefits — never a local decoder and never a patch under `libs/`. |

---

## Verification evidence

- **In-client:** `docs/reviews/2026-09-07/03_SMOKE_TESTS.md`, sign-off table completed — M-01a/b/c,
  M-02, M-04, the twelve regression rows and the deDE localization pass. *(Attach the filled table or
  link the commit that fills it.)*
- **Out-of-game, re-run fresh on 2026-09-07 before any change:** `luacheck .` 0/0 over 59 files;
  `lua5.1 tests/run.lua` 749/749; `lua5.1 tests/run.lua --list` byte-identical to `docs/test-cases.md`;
  `lua5.1 tests/perf.lua` 4 scenarios, 0 assertion failures; `lizard -l lua -x "./libs/*"
  -x "./tests/_kit/*" .` 0 warnings, max CCN 15; `tests/test_vendor_sync.lua` green on both cases
  against LibKa0s v1.25.0.
- **Commit range / PR:** *(fill in)*

---

## Suggested commit message / PR description

```
fix(db): migrate profiles that were not active at the upgrade

The SavedVariables migration runner gated per-profile work on the
ACCOUNT-wide db.global.schemaVersion. The first login after a schema
bump migrated whichever profile happened to be active, stamped the
account, and left every other profile permanently past the gate.

For schema v3 that meant a non-active profile kept macroBar.labelOutline
and never received macroBar.labelFlags, so AceDB's shipped "OUTLINE"
default painted over a stored labelOutline = false — the player's choice
silently replaced, which is what the v3 step was written to prevent. It
also made the OnProfileChanged / OnProfileCopied / OnProfileReset re-run
in core/ConsumableMaster.lua structurally incapable of firing.

Steps that write into db.profile now gate on db.profile.schemaVersion;
db.global.schemaVersion keeps its account-wide job. Switching to a
profile that predates a migration runs it. D.CURRENT_SCHEMA stays 3 —
no stored shape changed, only where the applied marker lives.

Alongside:
  * route the last six display strings (modules/KCMMacroDragIcon.lua,
    modules/KCMItemRow.lua) through NS.L; no rendered text changes
  * add MakeCloseButton to test_surface_parity.lua's CORE_SEAM with an
    explicit live-only ignore entry, so the deliberate omission is data
    rather than silence
  * %d -> %s at three KCM.Debug sites (docs/debug.md: the sink
    stringifies every argument, so a numeric verb is a latent raise)
  * re-derive eight file:line comment citations that no longer resolved

Findings: CM-R-01, CM-R-02, CM-R-03, CM-R-04, CM-R-07, CM-R-13, CM-R-14
Review:   docs/reviews/2026-09-07/
Tests:    749 -> 752, 0 failed. luacheck 0/0. lizard 0 warnings.
```
