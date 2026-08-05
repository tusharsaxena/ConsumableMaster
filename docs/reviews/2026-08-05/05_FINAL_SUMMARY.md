# Review — 2026-08-05 — 05 Final Summary

> **Written ahead of implementation.** This document describes what the 2026-08-05 review cycle is
> intended to have shipped, on the assumption that every check in `03_SMOKE_TESTS.md` passes. Fill in
> the bracketed figures and the sign-off pointers as the milestones in `04_EXECUTION_PLAN.md` land;
> do not treat any number here as measured until it is.

---

## Headline

Consumable Master's headless evidence was already in excellent shape when this review started — 656
tests green, lint clean over 54 files, zero functions above CCN 15, and a committed automated-test
bundle that matched a fresh run byte for byte. What the review found was not in the healthy path at
all: the addon's carefully documented **degraded install** — the state where the vendored `LibKa0s`
folder is missing — did not work. It raised a Lua error on every recompute, raised another on its own
declared settings write path, and told the user at login to reach for a slash command that answers
"unavailable". This cycle makes that seam behave the way three files' worth of comments already
claimed it did, closes a settings-write bypass that let `/cm bar` and the settings page disagree,
retires a small pile of dead state and stale comments, and stops the test suite running a private
fork of the shared test kit it already vendors and byte-checks.

---

## Counts

`Critical fixed: 0` (none found) · `High fixed: 3` · `Medium fixed: 7` · `Low fixed: 3`

- **High:** F-001, F-002, F-003 — the degraded seam.
- **Medium:** F-004, F-005, F-006, F-007, F-008, F-009, F-010.
- **Low:** F-011, F-012, F-013.

**Deferred:** none from this review's finding list. Two standing items are noted under *Known
follow-ups* below and are **not** review findings — they are pre-existing compliance items already
tracked elsewhere.

---

## Changes by theme

### Theme A — Make the degraded seam actually degrade

**What changed.** With `libs/LibKa0s/` absent, the settings layer no longer publishes nil where it
used to publish a library function: the chrome-half helpers bind to explicit no-ops, so "refresh the
panel" is a no-op rather than a crash when there is no panel to refresh. The login notice was
rewritten to say what is actually true — that both the settings panel and `/cm` are unavailable and
the install is incomplete — instead of directing the user to `/cm list|get|set`, which the slash seam
answers with "unavailable". The contract comment in `settings/Panel.lua` was corrected to describe
the code rather than the intent.

**Why it mattered.** A degraded install is not a hypothetical: it is what a truncated download, a
partial copy or a hand-pruned `libs/` produces, and it is the state four setup files in this addon
were explicitly written to survive. Before this change it produced a Lua error roughly once per bag
change for the whole session, and the single piece of guidance the user received was guidance that
could not be followed. Both were reproduced headlessly through the addon's own degraded loader before
any code was touched.

**Findings covered:** F-001, F-002, F-003, F-004. **Changes implemented:** C-01, C-02, C-03.

**Files touched:**
- `settings/Panel.lua`
- `tests/test_settingsui.lua`

### Theme B — One write path for the macro-bar toggles

**What changed.** `/cm bar on|off|lock|unlock` now writes through `Helpers.SetAndRefresh`, the
addon's declared single mutation seam, instead of assigning `db.profile.macroBar.enabled` /
`.locked` in place. The frame work moved to the schema rows' `onChange`, which is the direction the
`macroBar.enabled` row already used.

**Why it mattered.** Both fields are declared schema rows with widgets on the Macro Bar page. Writing
them directly skipped `RefreshScalars`, so with that page open, `/cm bar off` hid the bar and left
its checkbox ticked. A single write path exists precisely so the notify side effect cannot be
skipped; two entry points to one field is how a UI and its state drift.

**Findings covered:** F-005. **Changes implemented:** C-04.

**Files touched:**
- `core/SlashCommands.lua`
- `settings/MacroBar.lua`
- `modules/MacroBar.lua`
- `tests/test_slash.lua` (or `tests/test_macrobar.lua` — record which)

### Theme C — Run the test kit that was already vendored

**What changed.** `tests/run.lua` now loads the vendored kit's `framework.lua` and `loader.lua`, and
`tests/wow_mock.lua` is a thin extender over `tests/_kit/mock_base.lua` instead of a standalone
623-line mock. `tests/harness.lua` was deleted. The two vendor-sync cases now report a visible,
distinct outcome when the sibling `LibKa0s` checkout is absent, rather than passing silently.

**Why it mattered.** The addon vendored the kit correctly and enforced byte identity on it — and then
ran a private fork of all three of its files, so a kit-level fix reached the bytes and changed
nothing about what the 656 cases actually ran against. The drift was not theoretical: a comment in
the deleted `tests/harness.lua` recorded one divergence already found and hand-patched. The
vendor-sync cases were the one check that would have caught a fork, and they were also the one check
that could not fail when its precondition was missing.

**Findings covered:** F-006, F-007. **Changes implemented:** C-05, C-06, C-07, C-10.

**Files touched:**
- `tests/run.lua`
- `tests/loader.lua`
- `tests/wow_mock.lua`
- `tests/test_vendor_sync.lua`
- `tests/harness.lua` (deleted)
- `docs/test-cases.md` (regenerated, if the kit's renderer changes the format)

**Nothing under `tests/_kit/` was edited.** It remains byte-identical to the tagged release.

### Theme D — Lint scope, dead state, API currency, comment truth

**What changed.** The write-only `pendingIDs` set was removed from `core/TooltipCache.lua`, and with
it the tree-wide `241` lint suppression that existed only to carry it. The addon's last bare
`GetItemInfo` call now goes through `core/Compat.lua`, matching every other item-info call site. The
unused `MB.IsShown` export was deleted, and four stale comments were corrected — one naming the wrong
member as a degradation probe, three quoting a category count that has been wrong since the list grew
from 13 to 15.

**Why it mattered.** A globally-suppressed lint code makes today's `0 warnings` narrower than it
reads: any *new* unused local anywhere in the addon would have linted clean. The comment naming
`AddLine` as the console probe is the comment a future author would read before adding a no-op
`AddLine` — which would swallow every diagnostic while the addon looked healthy.

**Findings covered:** F-008, F-009, F-010, F-011, F-012, F-013.
**Changes implemented:** C-08, C-09, C-11, C-12.

**Files touched:**
- `core/TooltipCache.lua`
- `core/Compat.lua`
- `core/ConsumableMaster.lua`
- `modules/DebugLog.lua`
- `modules/MacroBar.lua`
- `.luacheckrc`

---

## API / behavior changes

| Surface | Change |
|---|---|
| Slash commands | **No verb added, renamed or removed.** `/cm bar on\|off\|lock\|unlock` keeps its grammar and its chat acknowledgements; only its internal write path changed. |
| Degraded-install chat | The "settings panel is unavailable" notice **no longer names `/cm list`, `/cm get` or `/cm set` as working**. It names the incomplete install instead. Healthy installs are unaffected. |
| `KCM.Settings.Helpers` | Under an absent `LibKa0s-Options-1.0`, the chrome-half members are no-ops rather than nil. `Helpers.EnsureScroll` deliberately stays nil (its callers index the return; see `02_PROPOSED_CHANGES.md`, C-01 risk note). |
| `Helpers.SetAndRefresh` | Now refuses a `nil` value instead of writing it. Previously `SetAndRefresh(path, nil)` deleted the key past validation. |
| `KCM.MacroBar.IsShown` | **Removed.** Zero callers, including tests. |
| `KCM.Compat` | **Added** `Compat.GetItemNameAndMinLevel(itemID)`. |
| Locale keys | None added, renamed or removed — the degraded notice is a chat literal in `settings/Panel.lua`, not an `L[...]` key. |
| Defaults | Unchanged. |

---

## Saved-variable / migration notes

**No schema bump.** `Database.CURRENT_SCHEMA` stays at **2**. No stored shape changed, so existing
profiles carry forward untouched and no `/cm reset` is required. The one behavioural difference a
user could observe is `Helpers.SetAndRefresh` refusing a `nil` write, which no shipping caller made.

---

## Deprecated-API migrations

| Old API | New API | Files |
|---|---|---|
| `GetItemInfo(itemID)` (bare global, unguarded) | `KCM.Compat.GetItemNameAndMinLevel` → `C_Item.GetItemInfo`, falling back to the flat global behind a presence check | `core/TooltipCache.lua:459`, `core/Compat.lua` |

The rest of the addon was already current: `C_Item.GetItemInfoInstant`, `C_Item.GetItemCount`,
`C_Item.GetItemCooldown`, `C_Container.*`, `C_Spell.*`, `C_TooltipInfo.GetItemByID`,
`C_SpecializationInfo.*`, `C_AddOns.GetAddOnMetadata`, `Settings.RegisterCanvasLayoutCategory` +
`Settings.RegisterAddOnCategory`, and `C_DurationUtil` / `issecretvalue` for Midnight's restricted
cooldown values. This sweep found exactly one straggler.

---

## Performance impact

**Not applicable — no perf-tagged change was made in this cycle, and no measurement was taken.**

Two things are worth recording rather than estimating:

- The offline scenario runner `tests/perf.lua` **does not exist** in this repo, so
  `performance-§2`'s "a dormant bracket is free" claim is **unverified** for this addon. The two
  brackets (`modules/MacroBar.lua:322-330`, `core/ConsumableMaster.lua:332-349`) read correctly by
  inspection — a plain table lookup and a plain boolean field, nothing allocated while capture is
  off — but that is an inspection, not a number.
- `docs/perf-runs/` does not exist either. `03_SMOKE_TESTS.md` includes the two-arm `/cm perf` capture
  protocol as an in-client step; **if it was run, its committed record under `docs/perf-runs/` is the
  first perf evidence this addon has, and its bucket figures belong here.** Record the `cooldown` and
  `recompute` bucket figures and name the record. Never quote the frame-time delta between arms — it
  is unresolved below the harness's own run-to-run spread.

---

## Test and complexity movement

| | Before | After |
|---|---|---|
| Pass count | **656 / 656** (verified fresh, 2026-08-05) | `[fill in]` |
| `docs/test-cases.md` | in sync (fresh `--list` byte-identical) | must move in the **same commit** as any count change (`testing-§5`) |
| README `[Tests]` badge (`README.md:7`) | `656/656 passing` | must match the above |
| `lizard` CCN > 15 | **0** | expected **0** |
| Max CCN in tree | **15** (7 functions) | expected 15 or lower |

**Watch-list entries these changes are expected to move** — to be confirmed by the next release's
regeneration (`/wow-addon:bump-version`), **not** regenerated here:

- `TC.Get` — `core/TooltipCache.lua:433-490`, CCN 13 / 36 NLOC today. C-08 removes four write sites
  from it; expect it **down**.
- `settings/Panel.lua` file NLOC (950 today, well inside `layout-§1`'s band) — C-01 adds a small
  branch; expect a marginal rise, nowhere near the 1000-LOC on-notice threshold.
- `tests/wow_mock.lua` — 623 LOC today, and `M.setItem` is one of the seven CCN-15 functions. C-07
  replaces the file with a thin extender; expect both figures **down** substantially, and the
  CCN-15 count to drop from 7 to 6.

`docs/automated-tests/RESULTS.md`'s watch list currently reads *"Functions `lizard` warned on: None"*,
which the fresh run confirms. Nothing in this cycle is expected to change that.

---

## Known follow-ups

- **No offline perf scenarios (`tests/perf.lua`).** Deferred deliberately: writing scenarios is a
  design task of its own, not a review remediation, and the addon's genuinely expensive paths are
  out of combat by design (`modules/PerfSetup.lua:8-15`). Until it exists, the zero-overhead claim
  stays unverified and the `perf` column stays a permanent, honestly-recorded `skip`.
- **No `docs/perf-runs/` store.** Pre-existing, tracked as deviation **CM-43** in the audit bundle.
  The first in-client capture from `03_SMOKE_TESTS.md` creates it.
- **The `241` inline suppression, if `pendingIDs` turns out to have been intentional.** If the git
  history shows a retry sweep was planned rather than abandoned, C-08 wires the reader instead of
  deleting the set — in which case note here which branch was taken and why.
- **`DL.Clear` / `ShowCopy` / `RefreshHeader` / `UpdateScrollBar` / `UpdateStatus`** — five DebugLog
  forwarders with no caller in shipping code (only `tests/test_debuglog.lua` exercises them), while
  the degradation stub deliberately omits them. Left alone: they are a coherent published facade over
  the library instance and the asymmetry is documented at `modules/DebugLog.lua:100-103`. Worth a
  decision at the next options-UI pass, not worth churn now.

---

## Verification evidence

- Smoke-test sign-off: `docs/reviews/2026-08-05/03_SMOKE_TESTS.md` — sign-off table completed.
- Headless evidence at review time: `luacheck .` 0/0 over 54 files; `lua5.1 tests/run.lua` 656/656;
  `lua5.1 tests/run.lua --list` byte-identical to `docs/test-cases.md`;
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` 0 warnings, `No thresholds exceeded`.
- Commit range / PR: `[fill in]`.
- Release bundle (produced at the tag, not per-commit): `docs/automated-tests/<run>/` plus its
  `RESULTS.md` row.

---

## Suggested commit message / PR description

```
review 2026-08-05: fix the degraded-install seam, close a settings write bypass,
adopt the vendored test kit

The addon's headless evidence was already green -- 656/656 tests, clean lint over
54 files, zero functions above CCN 15, and a committed automated-test bundle that
matches a fresh run exactly. The defects were in the path that only shows up when
libs/LibKa0s is missing.

High:
  F-001  every recompute raised a Lua error in a degraded install:
         O.Refresh -> Helpers.RefreshAllPanels, nil under an absent options lib,
         reached from the bus receiver the pipeline publishes on every pass.
  F-002  the declared single write path raised the same way via RefreshScalars,
         after the value had already been written and onChange had already fired.
  F-003  the degraded login notice told the user to use /cm list|get|set, which
         the slash seam answers with "/cm is unavailable".

Medium:
  F-004  the degraded settings test claimed to cover the write path and asserted
         only that the schema rows resolve -- asleep over F-002.
  F-005  /cm bar on|off|lock|unlock wrote db.profile.macroBar.* directly, so the
         Macro Bar page's checkboxes went stale with the panel open.
  F-006  tests/_kit was vendored and byte-gated, then not used: the runner ran a
         private fork of framework.lua, loader.lua and mock_base.lua (testing-1).
  F-007  both vendor-sync cases passed when the sibling checkout was absent.
  F-008  .luacheckrc silenced warning 241 tree-wide to carry one known defect.
  F-009  TooltipCache.pendingIDs was a write-only set on the hottest cache path.
  F-010  one bare GetItemInfo left, unguarded and namespace-unaware.

Low: F-011 (a stub comment naming the wrong probe), F-012 (a dead export),
F-013 (three stale category counts).

No schema bump. No slash verb added, renamed or removed. Nothing under libs/ or
tests/_kit/ was edited.

Reviewed against Ka0s WoW Addon Standard v2.21.0.
Full bundle: docs/reviews/2026-08-05/
```
