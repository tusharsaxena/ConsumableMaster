# Review — 2026-08-05 — 02 Proposed Changes (HLD + LLD)

Standard resolved: **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**, fetched from
`standards/STANDARDS.md` and its linked section files. The standards cross-check was **performed**;
every change below is vetted against it and cites the rule where one shaped or constrained the fix.

**No change in this document targets a path under `libs/` or `tests/_kit/`.** There are no upstream
findings in this review, so there is no upstream change-set section.

---

## HLD — themes

### Theme A — Make the degraded seam actually degrade (F-001, F-002, F-003, F-004)

**Rationale.** The addon invests heavily in a degraded install: four setup files each carry an
explicit stub, three carry a shared cause clause, and `settings/Panel.lua:164-176` argues at length
about which half of the file survives the library's absence. The investment is sound and the
direction is right (`anti-patterns` #47 — consume the library, ship a descriptor and a stub). What is
wrong is that the seam is drawn **in prose in a comment** and not **in code**: nine helpers are
published as `UI and UI.X`, which is nil when `UI` is nil, and two of them are then called
unconditionally from code the comment places on the surviving side. The result is two reproduced
crashes and a login notice that instructs the user to type a command that answers "unavailable".

**Chosen approach — a no-op shim table, plus one honest notice.** When `optionsLib` is absent, bind
the library-derived names to explicit no-ops rather than to nil, so the *schema* half really is
independent of the chrome half as claimed; and change `sayPanelUnavailable`'s wording to match what
`settings/Slash.lua` actually does.

**Alternatives considered and rejected:**

- *Guard every call site* (`if Helpers.RefreshScalars then …`). Rejected: it distributes the seam
  across ~12 sites, so the next helper added reintroduces the bug, and it reads as defensive noise
  in the healthy path that is 99.99% of executions.
- *Implement `RefreshAllPanels` / `RefreshScalars` locally for the degraded case.* **Rejected on the
  standard** — `anti-patterns` #47 names a per-addon options toolkit as the defect this whole
  adoption exists to remove, and the compliant direction for a genuine library gap is an additive
  descriptor field pushed upstream (`library-stack-§7`). There is no gap here: a no-op is the correct
  degraded behaviour, since with no panel there is nothing to refresh.
- *Keep the "use /cm set" promise and build a host-side schema CLI.* **Rejected** — that is a second
  slash dispatcher, which `slash-commands-§1` rules out and `settings/Slash.lua:330-334` already
  argues against in the file itself.

**Trade-off accepted.** After this change, a degraded install has a working addon, a working macro
pipeline, a working macro bar, and **no** settings access of any kind. That is honest and it is what
`settings/Slash.lua:298-299` already concluded ("a tampered install rather than a supported state").
The notice will say so.

### Theme B — One write path for `macroBar.enabled` and `macroBar.locked` (F-005)

**Rationale.** The addon declares `Helpers.SetAndRefresh` the single mutation seam for schema-backed
settings (`settings/Panel.lua:629-631`, and `KCM.Schema:Set` at `:649`). Two schema-backed paths are
written directly from the frame layer, so the slash→panel direction never re-syncs the widget.
`savedvariables` and `options-ui-§11` both turn on the write seam owning the notify side effect.

**Chosen approach.** Invert the dependency: the slash verbs write through the schema, and the row's
`onChange` calls the frame applier. `macroBar.enabled` already has that `onChange`
(`settings/MacroBar.lua:62-68`); `macroBar.locked` needs the symmetric one.

**Alternative rejected.** *Call `Helpers.RefreshScalars()` from `MB.SetEnabled`.* Rejected: it
couples the frame module to the options layer and leaves two write paths, which is the shape the
seam exists to collapse.

### Theme C — Run the test kit that is already vendored (F-006, F-007)

**Rationale.** `testing-§1` is a MUST on the wiring: vendor the kit, extend the base mock rather than
replace it, derive the load list from the TOC. This repo does the first and neither of the others,
and `tests/harness.lua:133-134` already records one drift found and hand-patched — the exact failure
mode `anti-patterns` #47 describes ("no repo went red to say so, because each addon's suite tested
its own copy and passed").

**Chosen approach.** Adopt in the order the kit's own README lays out, so the pass count never moves
for a reason other than the change under test: framework first (`Kit.expose` means no suite file
changes), then loader, then the mock. Each step ends green at 656.

**Alternative rejected.** *Delete `tests/_kit/` since it is unused.* Rejected outright — `testing-§1`
and `testing-§11` require the vendored kit and its byte-identity gate; the fix direction is to use
it, not to remove the evidence that it is not being used.

### Theme D — Lint scope, dead state, API currency, comment truth (F-008, F-009, F-010, F-011, F-012, F-013)

**Rationale.** Small, independent, low-risk. They are grouped only because they share a milestone,
not because they share a cause. Each is a one-file edit. F-008 and F-009 are a pair — the
suppression exists only to carry the defect, so the defect must go first.

---

## LLD — change-set

### C-01 — Bind the options helpers to no-ops when the library is absent

**Covers:** F-001, F-002.
**Files:** `settings/Panel.lua`.

Today, `settings/Panel.lua:243-245, 278, 351, 361, 458, 519, 527, 571-572` each read
`Helpers.X = UI and UI.Y`, producing nil under `libAbsent`.

Introduce one explicit degraded binding block immediately after the `if optionsLib then … end` at
`settings/Panel.lua:250`:

```lua
-- Before (scattered, each one nil under libAbsent):
Helpers.RefreshAllPanels = UI and UI.RefreshAllPanels
Helpers.RefreshScalars   = UI and UI.RefreshScalars
-- …seven more of the same shape

-- After: the chrome half is nil-free by construction. A degraded install has no
-- panel, so "refresh the panel" is genuinely a no-op rather than an omission —
-- which is what makes a shim correct here and a local re-implementation wrong
-- (anti-patterns #47).
local function noop() end
local function noopFalse() return false end
if not UI then
    Helpers.RefreshAllPanels = noop
    Helpers.RefreshScalars   = noop
    Helpers.SetRenderer      = noop
    Helpers.ResetScroll      = noop
    Helpers.AttachTooltip    = noop
    Helpers.EnsureScroll     = noopFalse   -- callers index the return; see risk
    Helpers.Grid             = noop
    Helpers.RenderField      = noop
    Helpers.CustomCheckbox   = noop
    Helpers.PatchAlwaysShowScrollbar = noop
end
```

Also fix the guard at `settings/Panel.lua:636` so a `nil` value cannot slip past validation into
`Helpers.Set`:

```lua
-- Before
if coerced == nil and value ~= nil then … end
-- After
if coerced == nil then
    KCM.Say("invalid value for " .. tostring(path) .. ": " .. tostring(reason or "expected a value"))
    return false
end
```

**Risk notes.** `Helpers.EnsureScroll`'s callers (`Helpers.Button:486`, `Helpers.ButtonPair:497`,
`Helpers.Label:532`, `Helpers.BuildAboutContent:700`) call `scroll:AddChild(...)` on the return, so a
plain `noop` returning nil relocates the crash. Those four are all unreachable under `libAbsent`
(nothing renders — `settings/Panel.lua:785-787`), so the honest shim is to leave them nil **or** give
`ensureScroll` a degraded early-return guard in each of the four. Prefer the latter and keep
`EnsureScroll` nil, so the file never pretends a scroll container exists. The two that **are**
reachable — `RefreshAllPanels` and `RefreshScalars` — are the ones that must become no-ops.

Update the contract comment at `settings/Panel.lua:164-167` so it describes the code after this
change rather than before it.

**Standards conformance.** Compliant: no new local implementation of anything the library provides
(`anti-patterns` #47), the descriptor and stub shape of `options-ui` is unchanged, and the single
write seam (`options-ui-§11`, `savedvariables`) keeps its validate → write → onChange → refresh
order.

### C-02 — Make the degraded notice match the degraded behaviour

**Covers:** F-003.
**Files:** `settings/Panel.lua` (`sayPanelUnavailable`, `:261-269`).

```lua
-- Before
", so the settings panel is unavailable; every setting is still reachable with " ..
"/cm list, /cm get and /cm set."

-- After
", so the settings panel and /cm are both unavailable. Reinstall Consumable Master " ..
"from a complete package (libs/LibKa0s is part of the addon, not a separate download)."
```

**Risk notes.** `tests/test_settingsui.lua:255` matches the literal `"settings panel is unavailable"`;
the replacement wording keeps that substring, so the case does not need editing — verify, do not
assume.

**Standards conformance.** Compliant. `slash-commands-§1`'s one-dispatcher rule is what rules out the
alternative (building a host-side CLI); this change chooses the compliant side.

### C-03 — Give the degraded settings case a real write assertion

**Covers:** F-004.
**Files:** `tests/test_settingsui.lua` (extend the existing case at `:234-260`).

```lua
-- inside the existing "with the library absent…" case, after FindSchema:
-- red under: revert C-01's no-op binding of Helpers.RefreshScalars
local wrote = KCM.Settings.Helpers.SetAndRefresh("enabled", false)
t.eq(wrote, true, "the schema write seam still works with no panel")
t.eq(KCM.Settings.Helpers.Get("enabled"), false, "…and the value actually lands")
```

**Regression pressure on the inventory.** This is an extension of an existing case, not a new one, so
**the pass count does not move** and `docs/test-cases.md` / the README `[Tests]` badge stay at 656.
Confirm with `lua5.1 tests/run.lua --list | diff - docs/test-cases.md` before committing; if the
count *does* move, `testing-§5` requires the inventory and the badge to move in the same change.

**Standards conformance.** `testing-§12` — the case carries a `-- red under:` comment naming the
mutation that reddens it.

### C-04 — Route the macro-bar toggles through the schema

**Covers:** F-005.
**Files:** `core/SlashCommands.lua`, `settings/MacroBar.lua`, `modules/MacroBar.lua`.

```lua
-- core/SlashCommands.lua:781-787 — before
function() KCM.MacroBar.SetEnabled(true);  say("macro bar |cff00ff00ON|r") end
function() KCM.MacroBar.SetLocked(true);   say("macro bar locked") end

-- after: the schema owns the write; onChange owns the frame work.
function() setBar("macroBar.enabled", true);  say("macro bar |cff00ff00ON|r") end
function() setBar("macroBar.locked",  true);  say("macro bar locked") end
-- where setBar resolves KCM.Settings.Helpers at call time and falls back to the
-- direct applier only when the schema half is genuinely absent.
```

```lua
-- settings/MacroBar.lua:70-74 — add the symmetric onChange the enabled row already has
row{
    path = "macroBar.locked", type = "bool", group = "Bar",
    …,
    onChange = function(v)
        if KCM.MacroBar and KCM.MacroBar.ApplyLock then KCM.MacroBar.ApplyLock(v) end
    end,
}
```

```lua
-- modules/MacroBar.lua:389-409 — SetEnabled/SetLocked stop writing the DB.
-- They keep the in-combat notice and the frame work, and read the flag they are
-- told about rather than the one they just wrote.
```

**Risk notes.** `core/SlashCommands.lua:811` (`KCM.MacroBar.SetEnabled(on)`) is the third caller —
migrate it in the same change or the bypass survives. `tests/test_macrobar.lua` and
`tests/test_slash.lua` both exercise these verbs; expect assertions that read `cfg().enabled` after
a slash call to keep passing (the value still lands, just through the seam), and expect any assertion
that spies on `MB.SetEnabled` directly to need re-pointing. If a case is added, the inventory and
badge move together (`testing-§5`).

**Standards conformance.** This is the rule the change restores: `savedvariables` / `options-ui-§11`
single write path with its refresh side effect. No new deviation.

### C-05 — Adopt `tests/_kit/framework.lua`

**Covers:** F-006 (part 1 of 3).
**Files:** `tests/run.lua`, `tests/harness.lua` (deleted at the end of the step).

`Kit.expose` merges `test` and the assertions into a table of the repo's choosing
(`testing-§1`), so the 34 suite files keep `local h = require("harness"); local test = h.test`
working through a one-line compatibility shim during the step, and the shim goes away at the end.
The `--list` renderer comes from the kit, which removes the drift `tests/harness.lua:133-134` records.

**Exit criterion:** `lua5.1 tests/run.lua` → 656/656, and `lua5.1 tests/run.lua --list` diffs clean
against `docs/test-cases.md`. If the inventory *format* changes because the kit renders it
differently, that is a real inventory move and `docs/test-cases.md` is regenerated **in the same
commit** (`testing-§5`) — never hand-edited (`tests/harness.lua:151` says so too).

### C-06 — Adopt `tests/_kit/loader.lua`

**Covers:** F-006 (part 2).
**Files:** `tests/loader.lua`.

Keep what is genuinely this addon's — `PURE_LAYER`, `L.LIB_FILES` (the explicit LibKa0s XML order,
which `testing-§9` requires to be spelled out because the TOC names only the aggregate XML), the
`TooltipCache.Get` swap at `:156-172`, and the `omitLibs` degraded mode — and layer them on
`Loader.tocFiles` / `Loader.loadAll`. `L.tocFiles()` at `:213-227` is already TOC-derived and is
replaced by the kit's, not by a hand list.

### C-07 — Make `tests/wow_mock.lua` a thin extender over `mock_base.lua`

**Covers:** F-006 (part 3).
**Files:** `tests/wow_mock.lua`.

`local base = dofile("tests/_kit/mock_base.lua")`, then overwrite the addon-specific keys
(`M.setItem`, `M.setBag`, `M.setSpell`, `M.setSpec`, `M.setCombat`, the tooltip store). This is the
largest of the three (623 lines today) and the one most likely to move the pass count, because the
base mock is deliberately less friendly than a hand-rolled one (`testing-§1`, mock fidelity). **Any
case that reddens here is a finding about the addon, not a reason to soften the mock** — and never a
reason to edit `tests/_kit/`.

### C-08 — Resolve `pendingIDs`, then narrow the lint suppression

**Covers:** F-009, F-008 (in that order — the suppression cannot come off first).
**Files:** `core/TooltipCache.lua`, `.luacheckrc`.

Decide from the git history of `core/TooltipCache.lua` whether `pendingIDs` had a reader. If not,
delete `:147`, `:151`, `:156`, `:448`, `:463`, `:480`, `:488`. If a retry sweep was intended, wire
the reader and add a suite case for it (inventory + badge move together, `testing-§5`).

Then `.luacheckrc:23` → `ignore = { "212", "542" }`, and update the comment block at `:18-22`.

**Risk notes.** Deleting the writes touches `TC.Get`, which the fresh `lizard` run puts at CCN 13 /
36 NLOC — the change moves it **down**, not up. Note for the next release's regeneration, per
`automated-tests-§3`; do not run the tool into the repo as part of this work.

### C-09 — Route the last bare `GetItemInfo` through `core/Compat.lua`

**Covers:** F-010.
**Files:** `core/Compat.lua`, `core/TooltipCache.lua`.

```lua
-- core/Compat.lua — new, matching the shape of GetSpellName above it
function Compat.GetItemNameAndMinLevel(itemID)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil, 0 end
    local name, _, _, _, minLevel = get(itemID)
    return name, minLevel or 0
end

-- core/TooltipCache.lua:459 — before
local name, _, _, _, minLevel = GetItemInfo(itemID)
-- after
local name, minLevel = KCM.Compat.GetItemNameAndMinLevel(itemID)
```

**Risk notes.** `core/Compat.lua` loads before `core/TooltipCache.lua` in the TOC
(`ConsumableMaster.toc`, core block) so the call-time resolution is safe. `tests/wow_mock.lua`
provides the flat global; confirm it also provides `C_Item.GetItemInfo` or that the fallback arm is
taken — `tests/test_tooltipcache.lua` (29 cases) is the guard.

**Standards conformance.** This is exactly the seam `compat` prescribes and `core/Compat.lua:1-9`
already documents; the fix removes a deviation rather than adding one.

### C-10 — Make the vendor-sync skip visible

**Covers:** F-007.
**Files:** `tests/test_vendor_sync.lua`, plus whatever skip affordance the kit provides after C-05.

Preferred: after C-05, use the kit's skip reporting if `framework.lua` has one, so the runner prints
a distinct status and `--list` renders it distinctly. If it does not, the compliant direction is an
**additive** kit feature pushed upstream to LibKa0s and re-vendored — not a local edit to
`tests/_kit/` (`testing-§1`). In the interim, rename both cases so the name itself carries the
condition, e.g. *"libs/LibKa0s matches the tagged release (skipped when ../LibKa0s is absent)"*,
which is what the file's header at `:108-110` already claims is true.

**Note:** renaming a case changes `docs/test-cases.md`. Regenerate it in the same commit
(`testing-§5`); the count stays 656.

### C-11 — Comment truth

**Covers:** F-011, F-013. **Files:** `modules/DebugLog.lua`, `core/ConsumableMaster.lua`.

`modules/DebugLog.lua:98` — `AddLine` → `instance`.
`core/ConsumableMaster.lua:328` — "the 13-category walk" → "the per-category walk".
`core/ConsumableMaster.lua:289-290` — "the other seven macros" → "the other categories"; "8 per frame
at peak" → "one per category per recompute".

### C-12 — Delete `MB.IsShown`

**Covers:** F-012. **Files:** `modules/MacroBar.lua:288-290`.

Zero callers including tests, verified by grep. `public-api` treats an exported function with no
consumer as surface the next author will build on by mistake.

---

## Standards conformance summary

| Change | Rules that shaped it | New deviation introduced? |
|---|---|---|
| C-01 | `anti-patterns` #47, `library-stack-§7`, `options-ui-§11` | No |
| C-02 | `slash-commands-§1` (ruled out the rejected alternative) | No |
| C-03 | `testing-§12`, `testing-§5` | No |
| C-04 | `savedvariables`, `options-ui-§11`, `testing-§5` | No — removes one |
| C-05..C-07 | `testing-§1` (MUST), `testing-§9`, `testing-§11`, `anti-patterns` #47 | No — removes one |
| C-08 | `lint`, `automated-tests-§3` (regeneration is a release step) | No |
| C-09 | `compat` | No — removes one |
| C-10 | `testing-§12`, `testing-§1` (no local `_kit` edit) | No |
| C-11, C-12 | `public-api` | No |

**Complexity movement to confirm at the next release regeneration** (not to be run now,
`automated-tests-§3`): C-08 lowers `TC.Get` (`core/TooltipCache.lua:433-490`, CCN 13 today); C-01
raises `settings/Panel.lua`'s file NLOC slightly and adds one small branch; nothing here is expected
to cross CCN 15, and the release gate's `suites.complexity.warnings == 0` should hold.
