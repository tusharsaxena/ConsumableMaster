# Review — 2026-08-05 — 01 Findings

**Verdict: minor issues.** The addon is coherent, well-instrumented and green on every suite that
runs outside the client. The defects that matter are concentrated in one place: the **degraded
install seam** (LibKa0s absent). That seam is designed in three files, documented at length, and
**does not work** — two reproduced nil-call crashes and one piece of user-facing guidance that
contradicts what the addon actually does. Everything else is Medium or below.

Standards cross-check: performed against **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**, resolved
from `standards/STANDARDS.md` in the WowAddonStandards repo.

---

## Measurement run (Step 0 — all re-run from scratch today, 2026-08-05)

| Suite | Command (repo root) | Result |
|---|---|---|
| **luacheck** | `luacheck .` | **pass** — 0 warnings / 0 errors in **54 files**, exit 0 |
| **Headless tests** | `lua5.1 tests/run.lua` | **pass** — **656 passed, 0 failed, 656 total**, exit 0 |
| **Test-case inventory** | `lua5.1 tests/run.lua --list > <scratch>/list.md` | **pass** — 793 lines; **byte-identical** to the committed `docs/test-cases.md` after CR normalization (`diff` exit 0) |
| **Offline perf runner** | `lua5.1 tests/perf.lua` | **skipped — `tests/perf.lua` does not exist in this repo.** Not a tooling gap; the addon ships no offline scenarios. |
| **Complexity** | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **pass** — **0 warnings**, `No thresholds exceeded`; NLOC 15257, 1630 functions, avg CCN 2.7 |
| **`make test`** | — | **skipped — no `Makefile` at the repo root.** |
| **Vendor sync** | `diff -r libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **skipped — this review run is constrained to a single repo and may not read the sibling `LibKa0s` checkout.** See F-007: the in-suite equivalent (`tests/test_vendor_sync.lua`) passes whether or not the sibling exists, so its green does **not** substitute for this. |

### Functions with CCN > 15

**None.** The fresh `lizard` run flags nothing. The seven functions at the ceiling value of exactly
**CCN 15** — the highest in the tree — are, for the record:

| CCN | NLOC | Function |
|---:|---:|---|
| 15 | 13 | `itemCooldown` — `core/MacroDisplay.lua:100-112` |
| 15 | 24 | `applyBackdrop` — `modules/MacroBar.lua:183-208` |
| 15 | 15 | `S.PickBestForSlot` — `modules/Selector.lua:300-314` |
| 15 | 20 | `availableForHands` — `modules/Selector.lua:344-363` |
| 15 | 27 | `S.SweepStaleDiscovered` — `modules/Selector.lua:545-571` |
| 15 | 44 | `Helpers.BuildAboutContent` — `settings/Panel.lua:699-760` |
| 15 | 14 | `M.setItem` — `tests/wow_mock.lua:154-173` |

### Committed artifacts vs. today's run

| Artifact | Agreement |
|---|---|
| `docs/test-cases.md` | **Agrees.** Identical to the fresh `--list`. 656 cases. |
| `README.md` `[Tests]` badge (`656/656 passing`, README.md:7) | **Agrees** with the fresh run. |
| `docs/automated-tests/20260804-233147/complexity.txt` | **Agrees** — footer byte-identical to the fresh `lizard` footer (15257 / 8.0 / 2.7 / 63.8 / 1630 / 0). |
| `docs/automated-tests/20260804-233147/manifest.json` | **Agrees** — lint 0/0/54, tests 656/656, complexity 0 warnings, perf `skip` with the correct reason. Stamp: git `97c05b8`, branch `feat/fix-ccn`, `dirty: true`, addon v1.5.0. |
| `docs/automated-tests/RESULTS.md` watch list | **Agrees** — "Functions `lizard` warned on: None" matches the fresh run exactly. |
| `docs/performance.md`, `docs/perf-runs/` | **Do not exist.** No committed perf evidence to agree or disagree with. |

**No committed record disagrees with what was measured today.** The evidence bundle is current.

**One standing consequence of the perf skip, stated so no downstream claim reads as verified:**
the addon brackets two hot paths (`modules/MacroBar.lua:322-330`, `core/ConsumableMaster.lua:332-349`)
and ships **no** zero-overhead scenario and **no** committed capture. `performance-§2`'s "a dormant
bracket is free" is therefore **unverified** for this addon. Reading the brackets by eye they look
correct — a plain `KCM.Perf` table lookup plus a plain `.on` boolean field read, nothing allocated,
concatenated or called while capture is off — but that is an inspection, not a measurement, and it
is recorded here as such. (The absence of the runner itself is an audit matter, already tracked as
CM-43; it is not re-raised as a finding below.)

---

## Critical

None.

---

## High

### F-001 — Degraded install: every recompute throws a Lua error `[design]`

**Where:** `settings/Panel.lua:833` (`O.Refresh` → `Helpers.RefreshAllPanels()`), bound nil at
`settings/Panel.lua:571` (`Helpers.RefreshAllPanels = UI and UI.RefreshAllPanels`).

**Problem:** With `LibKa0s-Options-1.0` absent, `UI` is nil, so `Helpers.RefreshAllPanels` is nil —
but `O.Refresh` calls it unconditionally, and `O.Refresh` is reached from the bus receiver at
`settings/Panel.lua:940-943`, which `core/ConsumableMaster.lua:313` publishes on **every** pipeline
recompute.

**Impact:** In a degraded install the addon raises `attempt to call field 'RefreshAllPanels'
(a nil value)` roughly once per recompute burst (inside the `C_Timer` debounce, so with no useful
traceback), i.e. at login and on every bag/spec/equipment change — for the entire session.

**Measured:** reproduced headlessly with the addon's own degraded loader
(`tests/loader.lua:207 loadFullAddon(true)`), which loads with `libs/LibKa0s/` genuinely absent:

```
Helpers.RefreshAllPanels = nil
KCM.Options.Refresh()       ok=false err=settings/Panel.lua:833: attempt to call field 'RefreshAllPanels' (a nil value)
bus PANEL_REFRESH           ok=false err=settings/Panel.lua:833: attempt to call field 'RefreshAllPanels' (a nil value)
```

**Fix direction:** the boundary the file asserts in prose (`settings/Panel.lua:164-167`) has to be
enforced in code — the library-derived helpers must either be no-op shims when `libAbsent`, or every
caller outside the chrome half must be guarded. Do **not** hand-roll a local `RefreshAllPanels`; the
compliant direction is a shim over absence, never a second implementation of the library's
(`anti-patterns` #47).

### F-002 — Degraded install: the settings write seam is nil-call too `[design]`

**Where:** `settings/Panel.lua:643` (`Helpers.SetAndRefresh` → `Helpers.RefreshScalars()`), bound nil
at `settings/Panel.lua:572`.

**Problem:** Same root cause as F-001 on the addon's declared single-write path. Reached from
`KCM.Schema:Set` (`settings/Panel.lua:649-651`), from the library's `set` callback
(`settings/Panel.lua:236`) and from the slash schema seam (`settings/Slash.lua:263, 269`). The value
is written and the row's `onChange` fires **before** the raise, so a caller that pcalls it observes a
failure over a mutation that already landed.

**Impact:** The documented mutation seam is unusable in a degraded install; a partial write with a
raised error is worse than a refused one.

**Measured:** reproduced via `loader.loadWithSchemaDegraded()`:

```
SetAndRefresh("enabled", false) -> ok=false
  err=settings/Panel.lua:643: attempt to call field 'RefreshScalars' (a nil value)
```

**Compounding:** the file's own contract comment at `settings/Panel.lua:164-167` states that the
schema half "does not touch the library, which is what keeps `/cm list|get|set` working on an
install where LibKa0s is missing." That is false on this line — a comment that documents a
guarantee the code does not provide.

**Fix direction:** as F-001. Additionally, `Helpers.SetAndRefresh`'s guard at
`settings/Panel.lua:636` (`if coerced == nil and value ~= nil`) lets a `nil` value through
validation entirely and writes it, deleting the key; tighten while in the file.

### F-003 — Degraded install tells the user to use a command that answers "unavailable" `[ux]`

**Where:** `settings/Panel.lua:261-269` (`sayPanelUnavailable`) vs. `settings/Slash.lua:297-305`
(the `else` arm when `LibKa0s-Slash-1.0` is absent).

**Problem:** Both branches key off the *same* absence — LibKa0s missing — yet they say opposite
things. Panel.lua tells the user "every setting is still reachable with /cm list, /cm get and /cm
set"; Slash.lua makes `list`, `get`, `set` and `reset` all print "…so /cm is unavailable."

**Impact:** The only guidance a degraded user receives at login is guidance that cannot be followed.
This is the whole reason the degraded path was built, and it is the part that fails.

**Measured:** reproduced on the full addon loaded degraded, chat capture verbatim:

```
[CM] The LibKa0s library is missing … ; running on reduced built-in fallbacks.
[CM] The LibKa0s library is missing … , so the settings panel is unavailable;
     every setting is still reachable with /cm list, /cm get and /cm set.
/cm set enabled false ->
[CM] The LibKa0s library is missing … , so /cm is unavailable.
/cm list ->
[CM] The LibKa0s library is missing … , so /cm is unavailable.
```

**Fix direction:** pick one coherent degraded story across the three seams and make every notice
match it. Either the schema CLI genuinely survives (which requires F-001/F-002 fixed **and** a
host-side `list/get/set` that does not depend on `LibKa0s-Slash-1.0`), or Panel.lua's notice stops
promising it. The second is smaller and is what `settings/Slash.lua:298-299` already argues for
("LibKa0s is vendored, so this is a tampered install rather than a supported state"). Whichever is
chosen, `slash-commands-§1`'s single-dispatcher rule forbids a second dispatcher as the remedy.

---

## Medium

### F-004 — The degraded settings case is asleep over exactly the path that crashes `[tests]`

**Where:** `tests/test_settingsui.lua:243-246`.

**Problem:** The case "Settings UI: with the library absent no panel is registered, and it says why
once" carries the comment *"every setting stays readable and writable through /cm list|get|set"* and
then asserts only `#KCM.Settings.Schema > 0` and `FindSchema("enabled")` — i.e. it checks the rows
are *resolvable*, never that a write succeeds. One extra line calling
`Helpers.SetAndRefresh("enabled", false)` in that same case would have caught F-002 the day it
landed.

**Impact:** `docs/test-cases.md` and the `[Tests] 656/656` badge count this as coverage of the
degraded write path. It is not. This is the more valuable half of F-002.

**Fix direction:** extend the existing case (do not add a parallel one) to exercise the write and
assert the returned `true` and the stored value. `testing-§12` applies: whatever assertion is added,
record the mutation that reddens it.

### F-005 — `/cm bar` bypasses the single write path, leaving the settings page stale `[design]`

**Where:** `modules/MacroBar.lua:392` (`c.enabled = on and true or false`) and
`modules/MacroBar.lua:404` (`c.locked = locked and true or false`); the same two paths are declared
schema rows at `settings/MacroBar.lua:59` (`macroBar.enabled`) and `settings/MacroBar.lua:71`
(`macroBar.locked`).

**Problem:** `MB.SetEnabled` / `MB.SetLocked` write `db.profile.macroBar.*` in place. They are
called directly by `/cm bar on|off|lock|unlock` (`core/SlashCommands.lua:781-787`) and by
`core/SlashCommands.lua:811`, bypassing `Helpers.SetAndRefresh` — and therefore bypassing
`Helpers.RefreshScalars()`, the in-place widget re-sync.

**Impact:** With the Macro Bar settings page open, `/cm bar off` hides the bar but leaves the
"Enable macro bar" checkbox ticked; `/cm bar unlock` leaves "Lock position" ticked. The panel and
the world disagree until the page is re-rendered. `macroBar.enabled`'s `onChange`
(`settings/MacroBar.lua:62-68`) makes the *panel → bar* direction correct; only *slash → panel* is
broken, which is exactly what a single write path exists to prevent.

**Fix direction:** route the slash verbs through `Helpers.SetAndRefresh("macroBar.enabled", v)` and
let the existing `onChange` call `MB.SetEnabled`; give `macroBar.locked` the symmetric `onChange`.
Keep `MB.SetEnabled`/`MB.SetLocked` as the frame-side appliers and stop them writing the DB.

### F-006 — The vendored test kit is byte-gated and then not used `[tests]` `[design]`

**Where:** `tests/run.lua:21` (`require("harness")` — the addon's own), against `tests/_kit/`
holding `framework.lua` (206 lines), `loader.lua` (90) and `mock_base.lua` (537), none of which any
runner or suite loads.

**Problem:** The addon vendors the kit correctly, enforces byte identity on it
(`tests/test_vendor_sync.lua:145-151`) — and then runs a private fork of all three:
`tests/harness.lua` (174 lines: registry, assertions, `--list` renderer),
`tests/loader.lua` (246 lines: source loader plus its own `tocFiles`), and
`tests/wow_mock.lua` (623 lines, standalone — it never `dofile`s `tests/_kit/mock_base.lua`).
Only `tests/_kit/run-automated-tests.sh` is actually consumed.

**Impact:** A kit-level fix reaches this addon's `_kit/` bytes and changes nothing about what its
656 cases run against — the byte-identity gate stays green over a fork. The drift is not theoretical:
`tests/harness.lua:133-134` records it happening already — *"tests/\_kit/framework.lua's own renderer
carries the same note; this one had drifted from it"* — i.e. one divergence was found and hand-patched
rather than removed.

**Standard:** `testing-§1` is explicit — "Addons **MUST NOT** hand-roll their own registry, assertion
set, source loader, or base mock", and `anti-patterns` #47 names a hand-written `tests/` framework
directly.

**Fix direction:** adopt the kit — `Kit.expose` exists precisely so no suite file has to change
(`testing-§1`). `tests/wow_mock.lua` becomes a thin extender over `mock_base.lua`; `tests/loader.lua`'s
addon-specific parts (`PURE_LAYER`, the `TooltipCache.Get` swap, `loadPureDegraded`) stay, layered on
`Loader`. **Do not** edit anything under `tests/_kit/`. This is sizeable and is scheduled as its own
milestone in `04_EXECUTION_PLAN.md`.

### F-007 — Both vendor-sync cases pass when the thing they check is absent `[tests]`

**Where:** `tests/test_vendor_sync.lua:140-141` and `:146-147` — `local tag = siblingTag();
if not tag then return end`.

**Problem:** When the sibling `../LibKa0s` checkout is missing, `siblingTag()` returns nil and both
cases return having asserted nothing. They print `PASS`, count in `docs/test-cases.md`, and move the
`[Tests]` badge. The file's own header (`tests/test_vendor_sync.lua:108-110`) claims the skip
"is said in the case name rather than hidden" — the case names are
*"libs/LibKa0s is the LibKa0s release the README says this addon bundles"* and *"tests/\_kit is the
test kit that shipped with that release"*. Neither names a skip, and nothing in the runner's output
distinguishes the two outcomes.

**Impact:** The single check that would catch a vendored fork is the one check that cannot be
distinguished from a pass. This is `testing-§12`'s "a test that cannot fail" in its purest form, and
it is why the vendor-sync row in my measurement block above is recorded as **skipped**, not as
covered by the suite.

**Fix direction:** make the absent-sibling outcome visible — either fail the case, or have the
harness carry a genuine skip status that `--list` and the run output both render distinctly. Do not
delete the cases.

### F-008 — `.luacheckrc` silences warning code 241 tree-wide to hide one known defect `[lint]`

**Where:** `.luacheckrc:23` (`ignore = { "212", "542", "241" }`), documented at `.luacheckrc:22` as
*"241 — TooltipCache.pendingIDs set is populated but never read [follow-up]"*.

**Problem:** `241` (a local assigned a value that is never accessed) is suppressed across all 54
linted files to carry one acknowledged defect (F-009). Any *new* instance of the same mistake
anywhere in the addon now lints clean.

**Impact:** Today's `0 warnings / 0 errors` is over a scope narrower than it reads. This is the case
lint itself cannot report.

**Fix direction:** fix F-009 and drop `241` from the global `ignore`; if it must be carried, scope it
to the line with an inline `-- luacheck: ignore 241`, so the code stays live everywhere else. `lint`
allows suppression but the standard's shape for it is narrow, not global.

### F-009 — `TooltipCache.pendingIDs` is a write-only set `[design]`

**Where:** `core/TooltipCache.lua:147` (declaration), `:448`, `:463`, `:480` (writes), `:488` and
`:151` (deletes), `:156` (reset). No read anywhere in `core/`, `modules/`, `settings/` or `tests/`.

**Problem:** A retry set for items whose tooltip has not hydrated is maintained on the cache's
hottest path and never consulted. Either the retry mechanism it was built for was never wired, or it
was superseded by `GET_ITEM_INFO_RECEIVED` and this is residue.

**Impact:** Dead state maintained per `TC.Get` miss, plus the lint suppression in F-008 that exists
solely to hold it. If it *was* meant to drive a re-parse sweep, the feature is silently missing.

**Fix direction:** decide which. If residue, delete the table and the four write sites; if the retry
was intended, wire the reader and cover it. Either way F-008's global suppression comes off.

### F-010 — One bare `GetItemInfo` call with no `C_Item` preference and no guard `[deprecated-api]`

**Where:** `core/TooltipCache.lua:459` — `local name, _, _, _, minLevel = GetItemInfo(itemID)`.

**Problem:** Every other item-info call site in the addon prefers the `C_Item` namespace and falls
back to the flat global only behind a presence check — `core/Classifier.lua:165-169`,
`core/WeaponSlots.lua:33-36`, `modules/KCMItemRow.lua:88-89`, `core/MacroDisplay.lua:51`,
`core/MacroDisplay.lua:74`. This one call is unguarded and namespace-unaware, in the single hottest
cache path in the addon.

**Impact:** Inconsistent with the addon's own `core/Compat.lua` seam policy (`compat`), and a hard
nil-call the day the flat global goes away. The global is present on current retail, so this is a
currency and consistency defect rather than a live break — stated as such rather than overclaimed.

**Fix direction:** route it through the same shape the neighbours use, or better, add it to
`core/Compat.lua`, which is exactly what that file exists for (`core/Compat.lua:1-9`).

---

## Low

### F-011 — A degradation stub's rationale comment names the wrong probe `[naming]`

**Where:** `modules/DebugLog.lua:97-99` — *"Deliberately publishes NO AddLine. core/Debug.lua probes
`KCM.DebugLog.AddLine` to decide whether a console exists."*

**Problem:** `core/Debug.lua:40` probes `DL.instance`, not `DL.AddLine`. The stub's behaviour is
correct (it publishes neither), but the comment explaining *why* points at the wrong member — and
this is the comment a future author would read before deciding it is safe to add a no-op `AddLine`.

**Fix direction:** correct the member name to `instance`.

### F-012 — `MB.IsShown` has zero callers `[dead-code]`

**Where:** `modules/MacroBar.lua:288-290`. Grepped across `core/`, `modules/`, `settings/`,
`defaults/`, `locales/` and `tests/` — no call site, not even a test.

**Fix direction:** delete, or give it the caller it was written for.

### F-013 — Stale category counts in pipeline comments `[naming]`

**Where:** `core/ConsumableMaster.lua:328` ("the 13-category walk"),
`core/ConsumableMaster.lua:289-290` ("one bad scorer can't break the other seven macros… 8 per frame
at peak").

**Problem:** `KCM.Categories.LIST` now holds 15 entries (`core/ConsumableMaster.lua:189-194`;
`settings/MacroBar.lua:76-77` records the 13 → 15 move explicitly). Three numbers in two comments
describing the same loop are each wrong, and one of them ("8 per frame") is the cost argument for a
`pcall` per category — the figure a reader would use to judge whether that is still cheap.

**Fix direction:** state the count by reference (`#KCM.Categories.LIST`) rather than by literal, so
the next category cannot restale it.

---

## Upstream findings

**None.** No defect was found in code under `libs/` or `tests/_kit/`. F-006 concerns the addon's
*failure to use* the vendored kit, which is a change in this repo's own `tests/` files — it is
explicitly **not** an edit to `tests/_kit/`.

---

## Coverage cross-check on the High findings

| Finding | Does the inventory claim a case over it? |
|---|---|
| F-001 | No. `tests/test_settingsui.lua:234` exercises the degraded panel but never touches `O.Refresh` or the bus. Genuine gap. |
| F-002 | **Yes, and the case is asleep** — see F-004. |
| F-003 | No. `test_settingsui.lua:253-259` asserts the Panel.lua notice is said once; nothing asserts the *pair* of notices is consistent. |
