# 03 — Evidence

**Audit:** 2026-08-04 · **Standard:** v2.17.1 (2026-08-03) · **Repo HEAD:** `21e7db4`

Every claim below is either a `file:line` citation or the **recorded output of a command actually
run**. Nothing here is inferred from code "looking reasonable".

---

## Part A — Mechanical checks (run, not reasoned about)

### A.1 Standard provenance — fetch and byte-identity

```
$ cd <scratch> && curl -fsSL --max-time 15 \
    "https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/AUDIT.md" -o std/AUDIT.md
OK
126 std/AUDIT.md

$ curl -fsSL --max-time 15 ".../standards/STANDARDS.md" -o std/STANDARDS.md
$ diff std/AUDIT.md      /mnt/d/.../WowAddonStandards/AUDIT.md               && echo "AUDIT identical"
AUDIT identical
$ diff std/STANDARDS.md  /mnt/d/.../WowAddonStandards/standards/STANDARDS.md && echo "STANDARDS identical"
STANDARDS identical

$ RAW=.../standards/standards; for f in $(ls .../WowAddonStandards/standards/standards/); do \
      curl -fsSL --max-time 8 "$RAW/$f" -o "std/sections/$f" || echo "FAIL $f"; done
attempted 24
24
$ diff -r std/sections /mnt/d/.../WowAddonStandards/standards/standards && echo "ALL SECTIONS BYTE-IDENTICAL"
ALL SECTIONS BYTE-IDENTICAL
```

Canonical checkout state, recorded before use:

```
$ cd /mnt/d/.../WowAddonStandards && git status --porcelain && git log -1 --format='%H %s'
2141122996c6c2db2e1c4a88a1f5d152dce2de928 v2.17.1 — finish the v2.17.0 rollout: no fourth slot, no drop-in imperative
```

(`git status --porcelain` printed nothing — clean tree.) All 24 sections retrieved over the network
**and** proven identical to that checkout. The standards repo was read only; nothing was written to it.

### A.2 `luacheck .`

```
$ cd /mnt/d/.../ConsumableMaster && luacheck .
...
Checking settings/StatPriority.lua                 OK

Total: 0 warnings / 0 errors in 52 files
```

**Result: clean.** Satisfies `lint` and the `testing-§4` commit gate's lint half.

### A.3 Headless runner

```
$ lua tests/run.lua
...
  PASS  Widgets: every widget name used by the settings pages is registered

  600 passed, 0 failed, 600 total
runner exit=0
```

**Result: green, 600/600.** Matches the README badge `Tests-600%2F600_passing-green`
(`README.md:7`) and `docs/test-cases.md`. Satisfies the `testing-§4` gate and `testing-§5` lockstep.

### A.4 Vendored Ka0s-owned library drift (`library-stack-§7`, anti-patterns #45 / #48)

Sibling source repo located and confirmed:

```
$ ls /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s
CHANGELOG.md  LICENSE  LibKa0s  README.md  docs  testkit  tests
```

Both mandated diffs, over the **whole** folder:

```
$ diff -r /mnt/d/.../GIT/LibKa0s/LibKa0s  ./libs/LibKa0s
exit=0                                   # EMPTY

$ diff -r /mnt/d/.../GIT/LibKa0s/testkit  ./tests/_kit
exit=0                                   # EMPTY
```

**Both empty. No drift (#45 clear), no partial vendoring (#48 clear).** Vendored payload confirmed
complete — all eight module files plus the aggregate XML and LICENSE:

```
$ ls libs/LibKa0s/
Core.lua  DebugLog.lua  LICENSE  LibKa0s.xml  Options.lua  OptionsScroll.lua
OptionsWidgets.lua  Perf.lua  PerfPanel.lua  Slash.lua
```

The harness is under `tests/`, never `libs/`:

```
$ ls tests/_kit/
README.md  framework.lua  loader.lua  mock_base.lua
```

The suite carries its own byte-identity gate for both copies —
`tests/test_vendor_sync.lua:145` ("tests/_kit is the test kit that shipped with that release") and
the sibling case for `libs/LibKa0s` — both **PASS** in the run above.

### A.5 Other executed greps

```
$ grep -rniE '\b(colour|grey|behaviour|centre|cancelled|initialise|normalise|serialise|organise|
    optimise|capitalisation|analyse|catalogue|dialogue|defence|licence|favour|labelled|travelled|
    fulfil)\b' core/ modules/ settings/ locales/ defaults/ README.md CLAUDE.md docs/*.md
(no output)
```
→ `localization-§5` / anti-pattern #46 **clean**.

```
$ grep -rn "WOW_PROJECT_ID" core/ modules/ settings/
(no output)
```
→ `toc-file-§3` / anti-pattern #9 **clean**.

```
$ find . -iname 'TODO*' -not -path './.git/*' -not -path './libs/*'      # (no output)
$ find . -iname '*agent-context*' -not -path './.git/*'                  # (no output)
```
→ anti-patterns #27 and #49 **clear**.

```
$ grep -n '<[a-z][a-z0-9_]*>' README.md
19-33: <code>KCM_FOOD</code> … <strong>Yes</strong>   (deliberate HTML in a table)
```
→ No angle-bracket **placeholders**; only `<code>`/`<strong>`, which `documentation-§1` explicitly
protects from a sweep. **Clean.**

### A.6 Not run / unverifiable

- **`lua tests/perf.lua`** — **could not be run: the file does not exist.** This is the evidence for
  **CM-38**, not a skipped check.
- **`lizard` complexity report** (`performance-§10`, SHOULD) — `docs/complexity.md` absent; the tool
  is optional dev tooling, so this is recorded as *report absent*, not a compliance failure.
- **Mutation-verification of negative assertions** (`testing-§12`) — leaves no repo artifact and is
  explicitly **not mechanically auditable**. Recorded as **unverified**, never as a deviation. No
  suite case carries a `-- red under: …` comment, so the cheap re-check the section recommends is
  also unavailable.

---

## Part B — Evidence per deviation

### CM-30 — English tooltip-text parsing (`localization-§4`, #37)

- `core/TooltipCache.lua:47-50` — `healRange = "Restores ([%d,]+) to ([%d,]+) health"`,
  `healFlat`, `manaRange`, `manaFlat` — English literals.
- `core/TooltipCache.lua:97-100` — `STAT_TOKENS`: `{ token = "Critical Strike", … }`,
  `"Attack Power"`, `"Spell Power"`, `"Primary Stat"`.
- `core/TooltipCache.lua:120-123` — negation probe on `"[Cc]annot "`, `"[Dd]oes not "`,
  `"[Cc]an't "`, `"[Dd]oesn't "`.
- `core/TooltipCache.lua:186` — `line:match("([%d,]+)%s+of your highest secondary stat")`.
- **Documented as intentional:** `docs/scope.md:20` — "English-only, and this is a **documented,
  intentional deviation** from the Ka0s Standard's `localization-§4` (anti-pattern **#37**) … A
  standards audit *should* flag it — that is expected and recorded here."
- **Scope already narrowed:** classification is off the localized string — see
  `core/Classifier.lua` / `core/WeaponSlots.lua`, pinned by
  `tests/test_weaponslots.lua` case *"WeaponSlots: keys on weapon subClassID, not the localized subType"*
  (PASS in A.3).
- Corroborated independently by the 2026-08-03 review: `docs/reviews/2026-08-03/01_FINDINGS.md:152`.

### CM-34 — Hand-rolled test harness (`testing-§1`, #47)

- `tests/harness.lua:1` — "`tests/harness.lua` — headless test framework shared by every suite."
- `tests/harness.lua:15-27` — `local H = {}`, `H.loader = require("loader")`, `H._tests = {}`,
  `H._currentFile` — an addon-authored registry.
- `tests/run.lua:21` — `local h = require("harness")`. **No `dofile` of `tests/_kit/framework.lua`
  or `tests/_kit/loader.lua` anywhere in the repo.**
- `tests/run.lua:57-58` — `io.write(h.formatInventory(h._tests))` — an addon-authored `--list`
  renderer.
- `tests/loader.lua:1` — "loads addon source files under the headless mock" — an addon-authored
  sandboxed loader; `tests/loader.lua:9` `local mock = require("wow_mock")`.
- `tests/wow_mock.lua` — **623 LOC**, and `grep -rn "_kit" tests/*.lua` returns only:
  - `tests/harness.lua:133` (a comment),
  - `tests/test_vendor_sync.lua:4,17,145,150` (the sync test).
  There is **no** `dofile("tests/_kit/mock_base.lua")` — so `wow_mock.lua` is a replacement, not the
  mandated thin extender.
- The kit that *is* vendored and unused: `tests/_kit/framework.lua` (206 LOC),
  `tests/_kit/loader.lua` (246 LOC), `tests/_kit/mock_base.lua` (537 LOC), `tests/_kit/README.md`.

### CM-35 — Hand-maintained load list (`testing-§9`)

- `tests/loader.lua:79-94` — `L.PURE_LAYER = { "locales/enUS.lua", "Namespace.lua",
  "ConsumableMaster.lua", … }` — 33 hand-copied entries.
- `tests/loader.lua:178` — `return L.loadFiles(L.PURE_LAYER)`;
  `tests/loader.lua:184` — `return L.loadFiles(L.PURE_LAYER, true)`;
  `tests/loader.lua:196,237` — two more consumers.
- Suites reaching it directly: `tests/test_debug.lua:18`, `tests/test_settingsui.lua:282`.
- TOC derivation **does** exist but only for the full-load path:
  `tests/loader.lua:208` `return L.loadFiles(L.tocFiles(), omitLibs)`; `tests/loader.lua:213-214`
  `function L.tocFiles() local toc = ROOT .. "/ConsumableMaster.toc"`.
- **The library-file list is correct** and is *not* part of this finding —
  `tests/loader.lua:29-38` spells out all eight `libs/LibKa0s/*.lua` in XML order, with
  `tests/loader.lua:21-28` explaining exactly the silent failure `testing-§9` describes, and
  `tests/test_load.lua` pinning it against the XML.

### CM-36 — Host member is a copy-across table (`options-ui-§1`)

- `settings/Panel.lua:41-42` — `local Helpers = KCM.Settings.Helpers or {}` /
  `KCM.Settings.Helpers = Helpers`. A fresh table.
- `settings/Panel.lua:186` — `local optionsLib = LibStub and LibStub("LibKa0s-Options-1.0", true)`;
  `settings/Panel.lua:187` — `local UI` — the instance is a **separate local**.
- `settings/Panel.lua:193` — `UI = optionsLib:New({ … })`.
- The copy-across, member by member:
  - `settings/Panel.lua:149` `Helpers.PatchAlwaysShowScrollbar = UI.PatchAlwaysShowScrollbar`
  - `settings/Panel.lua:151` `Helpers.EnsureScroll = ensureScroll`
  - `settings/Panel.lua:155` `Helpers.instance = UI`
  - `settings/Panel.lua:279` `Helpers.AttachTooltip = attachTooltip` (`:278` `local attachTooltip = UI and UI.AttachTooltip`)
  - `settings/Panel.lua:351` `Helpers.SetRenderer = UI and UI.SetRenderer`
  - `settings/Panel.lua:361` `Helpers.ResetScroll = UI and UI.ClearScroll`
  - `settings/Panel.lua:384` `Helpers.AddSpacer = addSpacer` (`= UI and UI.AddSpacer`)
  - `settings/Panel.lua:458` `Helpers.RenderField = UI and UI.RenderField`
  - `settings/Panel.lua:519` `Helpers.Grid = UI and UI.RenderGrid`
  - `settings/Panel.lua:527` `Helpers.CustomCheckbox = UI and UI.SessionCheckbox`
  - `settings/Panel.lua:571` `Helpers.RefreshAllPanels = UI and UI.RefreshAllPanels`
- The rule violated, verbatim from `options-ui-§1`: *"The host member **MUST *be*** the library
  instance, decorated in place with the host's own non-generalizable pieces — never a fresh table
  that copies members across."*
- Note the addon already reaches for the property the rule protects — `Helpers.instance = UI`
  exists precisely so the suite can assert identity, which is a workaround for the shape rather
  than the shape.

### CM-37 — Library layout constants restated (`options-ui-§8`)

- `settings/Panel.lua:74` — `local SECTION_HEADING_H     = 26`
- `settings/Panel.lua:75` — `local BUTTON_PAIR_REL       = 0.492  -- paired action-button relative width (standard §6.8)`
- Used at `settings/Panel.lua:502-503` — `makeButton(row, leftSpec, BUTTON_PAIR_REL)` /
  `makeButton(row, rightSpec, BUTTON_PAIR_REL)`.
- Used at `settings/Panel.lua:711` — `heading:SetHeight(SECTION_HEADING_H)`, followed by
  `settings/Panel.lua:713-714` `heading.label:SetFontObject(_G.GameFontNormalLarge)`.
- The rule violated: *"Hosts **MUST NOT** copy these values into their own constants file … read it
  off the instance (`Helpers.ROW_VSPACER`, `Helpers.SECTION_HEADING_H`, `Helpers.BUTTON_PAIR_REL`)
  rather than restating the number."*
- **Not** a finding: `settings/Panel.lua:48-50` correctly records that `PADDING_X`, `HEADER_TOP`,
  `HEADER_HEIGHT`, `DEFAULTS_W` and the breadcrumb separator were removed in favour of the
  library's `LAYOUT`. Two constants were missed, not all of them.

### CM-38 — No offline scenario runner (`performance-§9`)

```
$ ls tests/perf.lua
ls: cannot access 'tests/perf.lua': No such file or directory
```
- The claim the missing scenario is supposed to substantiate is currently a **comment**:
  `core/ConsumableMaster.lua:269` / `modules/MacroBar.lua:323` gate on `perf.on` with no committed
  allocation measurement anywhere. `performance-§2` MUST: *"treat the offline runner's
  zero-overhead scenario (performance-§9) as the **required evidence** for this rule. The claim
  'instrumentation is free when off' is not a comment; it is a measured, committed number."*

### CM-39 — Bracket shape does an `NS` lookup per call (`performance-§2`, #43)

- `core/ConsumableMaster.lua:268` — `    local perf = KCM.Perf`  ← inside the function
- `core/ConsumableMaster.lua:269` — `    local perfT0 = (perf and perf.on) and debugprofilestop() or nil`
- `core/ConsumableMaster.lua:321` — `    if perfT0 then perf.Note("recompute", debugprofilestop() - perfT0) end`
- `modules/MacroBar.lua:322` — `    local perf = KCM.Perf`
- `modules/MacroBar.lua:323` — `    local t0 = (perf and perf.on) and debugprofilestop() or nil`
- `modules/MacroBar.lua:330` — `    if t0 then perf.Note("cooldown", debugprofilestop() - t0) end`
- Mandated shape (`performance-§2`): `local Perf = NS.Perf` at **file scope**, then
  `local t0 = Perf.on and debugprofilestop()` — *"one upvalue read, one field read and one boolean
  test when off — no call, no table lookup through `NS`."*
- **Root cause is load order**, which is why this is coupled to CM-45: `ConsumableMaster.toc`
  loads `core\ConsumableMaster.lua` in `# Core` and `modules\PerfSetup.lua` in `# Modules`, so
  `KCM.Perf` does not exist when either bracket site's file loads.
- The cost is paid on a genuinely hot path — `modules/PerfSetup.lua:11-15` documents the cooldown
  repaint as *"the one path that runs at near-frame frequency mid-fight."*

### CM-40 — No bucket-reached test (`performance-§3`, `testing-§8`)

- Buckets declared: `modules/PerfSetup.lua` descriptor — `{ key = "cooldown" }`, `{ key = "recompute" }`.
- The only bucket assertion in the suite:
  `tests/test_perfsetup.lua:141-144` —
  ```
  local buckets = KCM.Perf.__buckets()
  … t.eq(n, 0, "no bucket accrued with the harness idle")
  ```
  This pins the **negative** (nothing accrues when idle) and nothing else.
- `grep -rn` for a positive assertion on `"cooldown"` / `"recompute"` accrual across
  `tests/test_perfsetup.lua`, `tests/test_pipeline.lua`, `tests/test_macrobar.lua` returned **no
  match**.
- Rule violated: *"A bucket that no bracket ever reaches is a **lie in every report**. The addon's
  own test suite **MUST** pin that each declared bucket is actually reached."*

### CM-41 — `ConsumableMasterPerfDB` missing from lint globals (`performance-§5`, `lint`)

- `.luacheckrc:30-34`:
  ```
  globals = {
      "ConsumableMasterDB",
      "StaticPopupDialogs",
      "UISpecialFrames",
  }
  ```
- `grep -n "PerfDB" .luacheckrc` → **no output**.
- The global is real and declared: `ConsumableMaster.toc` `## SavedVariables: ConsumableMasterDB,
  ConsumableMasterPerfDB`.
- Rule: *"**MUST** be declared in `.luacheckrc`'s `globals` with a comment, like the addon's own SV
  global."*

### CM-42 / CM-43 — Missing required perf docs (`documentation-§3`, `performance-§8`)

```
$ ls docs/performance.md docs/perf-runs
ls: cannot access 'docs/performance.md': No such file or directory
ls: cannot access 'docs/perf-runs': No such file or directory
```
- `docs/` inventory as it stands: `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`,
  `test-cases.md`, `common-tasks.md`, `data-model.md`, `debug.md`, `file-index.md`, `macro-bar.md`,
  `macro-manager.md`, `midnight-quirks.md`, `module-map.md`, `pipeline.md`, `scope.md`,
  `pending/`, `superpowers/`, `audits/`, `reviews/`.
- `documentation-§3` names **three** required topic-detail docs: `docs/test-cases.md` (present),
  `docs/performance.md` (**absent**), `docs/perf-runs/README.md` (**absent**).

### CM-44 — DebugLog setup in the wrong file/folder (`debug-logging-§1`, `layout-§1`)

- File is `modules/DebugLog.lua`; `core/DebugLogSetup.lua` does not exist.
- TOC places it in `# Modules`, between `modules\MacroManager.lua` and `modules\PerfSetup.lua`.
- `debug-logging-§1` MUST: *"In its own core file (`core/DebugLogSetup.lua`), positioned in the TOC
  **after** the constants file that carries the mono font path, the state file that carries the
  flag, and the core printer, and **before** every module that calls the sink."*
- The **content** is correct and is explicitly recorded as compliant here: descriptor with all five
  required fields (`modules/DebugLog.lua:110-165`), call-time `print` thunk (`:138`), library
  `skin` deliberately not overridden (`:167-174`), stub with a documented omission
  (`:97-103`), formatters bound from the library not re-implemented (`:206`).

### CM-45 — Perf setup in the wrong file/folder, loading too late (`performance-§1`, `layout-§1`)

- File is `modules/PerfSetup.lua`; `core/PerfSetup.lua` does not exist.
- TOC `# Modules` section, listed after `modules\DebugLog.lua`, with a comment explaining that
  `core\SlashCommands.lua` "loads earlier but resolves KCM.Perf at call time".
- `performance-§1` MUST: *"In its own core file (`core/PerfSetup.lua`), positioned in the TOC
  **before** any module that takes `local Perf = NS.Perf` as a load-time upvalue."*
- Both bracket sites load first — `core\ConsumableMaster.lua` (`# Core`) and `modules\MacroBar.lua`
  (`# Modules`, above `PerfSetup` in file order? no — `MacroBar.lua` is listed **after**
  `PerfSetup.lua`, but `core\ConsumableMaster.lua` is not). This is the direct cause of CM-39.
- Content is otherwise correct: silent-then-guarded lookup (`modules/PerfSetup.lua:29,36`),
  real suspend/resume enforcing inertness at the source (`:44-59`), buckets declared in report
  order, `showLog`/`log`/`print` hooks wired to the console and the shared printer.

### CM-46 — Options seam has no file of its own (`options-ui-§1`, `layout-§1`)

- `settings/OptionsSetup.lua` does not exist; the seam is at `settings/Panel.lua:186-193`
  (lookup + `:New`), inside a **927-line** file that also owns the schema half, `CreatePanel`, the
  host widget helpers and the registration bootstrap.
- `options-ui-§1` MUST: *"**MUST** create one instance per addon at load, from a descriptor, and
  stash it on the namespace — **in its own file (`settings/OptionsSetup.lua`)**, positioned in the
  TOC after the schema/slash files it reads and before every `settings/<page>.lua`."*
- TOC currently lists `settings\Panel.lua` first in `# Settings`, then `General`, `MacroBar`,
  `StatPriority`, `Category` — so the *ordering* half is already right; only the file split is missing.

### CM-47 — Dispatcher in the wrong file (`slash-commands-§1`, `layout-§1`)

- `settings/Slash.lua` does not exist. The `COMMANDS` table is at `core/SlashCommands.lua:1130-1241`,
  the descriptor and instance at `core/SlashCommands.lua:1302-1352`, `GetLandingRows` at `:1401`,
  `OnSlashCommand` at `:1406`.
- `slash-commands-§1` MUST: *"**MUST** create one dispatcher per addon, from a descriptor, **in the
  addon's own `settings/Slash.lua`**."*
- File size: `core/SlashCommands.lua` = **1408 LOC** (`wc -l`), the largest source file in the repo.
- Everything about the wiring itself is correct — AceConsole registration at
  `core/ConsumableMaster.lua:207-208`, positional-triple `COMMANDS`, host printer thunk
  (`core/SlashCommands.lua:1319`), `reset` as a **path** verb, stub that names the library instead
  of re-implementing (`:1363-1370`).

### CM-48 — Profile defaults not in `defaults/Profile.lua` (`savedvariables-§2`)

- `ls defaults/Profile.lua` → *No such file or directory*.
- `core/ConsumableMaster.lua:25` — `KCM.dbDefaults = {`; `core/ConsumableMaster.lua:34` —
  `        schemaVersion = 1,`.
- `defaults/` contains only data tables: `Categories.lua`, `Defaults_StatPriority.lua`,
  `Defaults_Food.lua`, … `Defaults_BattleRez.lua`, plus a `README.md`.
- Consumers already read it off the namespace, so the move is mechanical:
  `settings/MacroBar.lua:21-22` — `local BAR_DEFAULTS = KCM.dbDefaults and KCM.dbDefaults.profile
  and KCM.dbDefaults.profile.macroBar or {}`.
- `savedvariables-§2` MUST: *"**MUST** declare in `defaults/Profile.lua`. **MUST** be the **only**
  place a default value is hardcoded."*

### CM-49 — `core/` load order (`layout-§1`)

- `ConsumableMaster.toc`, `# Core` section, in order:
  `core\Namespace.lua`, `core\ConsumableMaster.lua`, `core\Bus.lua`, `core\Constants.lua`,
  `core\CoreSetup.lua`, `core\Compat.lua`, `core\State.lua`, `core\Database.lua`, `core\Debug.lua`,
  `core\SpecHelper.lua`, `core\TooltipCache.lua`, `core\WeaponSlots.lua`, `core\BagScanner.lua`,
  `core\Classifier.lua`, `core\LSMPatch.lua`, `core\MacroDisplay.lua`, `core\MacroBarModel.lua`,
  `core\MacroBarLayout.lua`, `core\SlashCommands.lua`.
- `layout-§1` MUST: *"load order: `core/Compat.lua` → `core/Constants.lua` → `core/Namespace.lua`
  → other `core/*` → …"* — `Compat` is 6th and `Constants` 4th.
- **Recorded standard conflict:** the same `layout-§1` bullet ends `… → settings/* → modules/*`,
  while `toc-file-§5` mandates *"**Libraries → Locales → Core → Defaults → Modules → Settings**"*
  and *"settings **last**"*. The addon follows `toc-file-§5`. This row is therefore scoped to the
  within-`core/` ordering only, and the conflict is flagged for upstream resolution.
- The addon's ordering is deliberate and documented: TOC comment block above `core\Namespace.lua`
  ("Namespace.lua first: names the private addon table"), and above `core\CoreSetup.lua`
  ("has to sit after Constants.lua (KCM.PREFIX) and before core\SlashCommands.lua").

### CM-50 — `CLAUDE.md` H1 (`documentation-§2`)

- `CLAUDE.md:1` — `# CLAUDE.md`
- Required: `# CLAUDE.md — Ka0s <Name>` → `# CLAUDE.md — Ka0s Consumable Master`.
- Everything else in the stub is present and in order: adherence line `CLAUDE.md:3,7`;
  `## Standards compliance (read first)` `CLAUDE.md:5` with the stop-and-flag rule and the
  two-way classification at `:9-13`; docs pointer list `:46-55` (which correctly does **not**
  name `docs/agent-context.md`); green gate `:57-64`.

### CM-51 — AceGUI resolved non-silently, three times (`library-stack-§4`, `toc-file-§1`)

- `settings/Panel.lua:19` — `local AceGUI = LibStub("AceGUI-3.0")`
- `settings/StatPriority.lua:23` — `local AceGUI = LibStub("AceGUI-3.0")`
- `settings/Category.lua:29` — `local AceGUI = LibStub("AceGUI-3.0")`
- All three at file scope, all three without the `true` silent flag, so a missing AceGUI raises at
  load in three files.
- Contrast with every other lookup in the addon, which does it correctly:
  `core/CoreSetup.lua:33`, `modules/DebugLog.lua:37,55`, `modules/PerfSetup.lua:29`,
  `core/SlashCommands.lua:1302`, `settings/Panel.lua:186` — all `LibStub(..., true)`.
- `settings/Panel.lua:147` already re-publishes it (`UI.AceGUI = AceGUI`), showing the single-home
  pattern is one line away.
- `options-ui-§1`: *"AceGUI-3.0 is **survivable, not a dependency**."*

### Advisory evidence

- **CM-52** — `.luacheckrc:23` `ignore = { "212", "542", "241" }`, with `.luacheckrc:18-22`
  recording `241` as a pre-existing dead-code smell tracked as a follow-up.
- **CM-53** — retired `§N.M` refs: `settings/Panel.lua:75` ("standard §6.8"),
  `settings/Panel.lua:404` ("standard §4.5"), `settings/Panel.lua:512` region ("standard §6.6"),
  `core/Debug.lua:5` ("standard §12"), `core/Bus.lua:1` ("standard §4.4"),
  `.luacheckrc:28` ("standard §4.1"). Correct-form refs also exist and outnumber them
  (`modules/DebugLog.lua:21,45`, `core/Debug.lua:20,24`, `settings/Panel.lua:52`).
- **CM-54** — `wc -l`: `core/SlashCommands.lua` 1408, `settings/Panel.lua` 927,
  `settings/Category.lua` 653, `modules/Selector.lua` 595, `core/ConsumableMaster.lua` 590.
  All under 1500; the first two are in the 1000–1500 / near-band.
- **CM-55** — `README.md:275` `## Credits and bundled libraries`, sitting between
  `README.md:258` `## Troubleshooting` and `README.md:283` `## Issues and feature requests`.
- **CM-56** — `.pkgmeta` `ignore:` lists `docs`, `tests`, `.luacheckrc`, `.pkgmeta`, `.gitignore`,
  `.gitattributes`, `*.bak`, `media/screenshots`; repo also contains `.claude/`, `.superpowers/`,
  `CHANGELOG.md`.
- **CM-57** — `docs/pending/LEDGER.md`, 27386 bytes, referenced from
  `settings/Panel.lua:90` ("Recorded in docs/pending/LEDGER.md as LIBKA0S-04") and
  `settings/Panel.lua:351` region (LIBKA0S-05), `core/SlashCommands.lua:1373` (LIBKA0S-13).

---

## Part C — Positive compliance evidence (claims that the addon *passes*)

| Rule | Evidence |
|---|---|
| `library-stack-§7` whole-folder vendoring, no drift | A.4 — both `diff -r` empty; `tests/test_vendor_sync.lua:145` PASS |
| `toc-file-§4/§5` single aggregate XML, no `embeds.xml` | `ConsumableMaster.toc` `# Libraries`: `libs\LibKa0s\LibKa0s.xml`, listed once, after Ace3; no LibKa0s `.lua` lines |
| `toc-file-§1` field order (was CM-31) | `ConsumableMaster.toc:1-16` — Interface→Title→Notes→Author→Version→IconTexture→SavedVariables→OptionalDeps→DefaultState→Category-enUS→X-License→X-Standard→X-Curse-Project-ID |
| `toc-file-§2` exactly two SV globals | `## SavedVariables: ConsumableMasterDB, ConsumableMasterPerfDB` |
| `architecture-§1` private namespace | `core/Namespace.lua`, `core/CoreSetup.lua:22`, `core/Bus.lua:21-22` — `local _, NS = ...`; no `_G[addonName]` assignment anywhere |
| `architecture-§2` / #36 AceConsole clobber | `core/CoreSetup.lua:17-20` — printer is `KCM.Say`, not `NS.Print`; nothing to clobber |
| `architecture-§4` / #32 per-receiver bus targets | `core/Bus.lua:31-35` `KCM.NewBusTarget()`; receivers at `core/Bus.lua:47`, `modules/MacroBar.lua:450`, `settings/Panel.lua:917,921` — four distinct targets |
| `architecture-§4` message catalog | `core/Bus.lua:8-19` + `core/Bus.lua:37-42` `KCM.MSG`; senders only in `core/ConsumableMaster.lua:311,315,328,525,560` — one per message |
| `architecture-§5` single write seam | `settings/Panel.lua:609` `Helpers.SetAndRefresh`; reached by the options descriptor (`settings/Panel.lua:142`) and the slash descriptor (`core/SlashCommands.lua:1327-1329,1334-1336`) |
| `architecture-§5` boot-time schema validation | `settings/Panel.lua:136` `Helpers.ValidateSchema` |
| `savedvariables-§1` migration runner | `core/Database.lua:41` `D.RunMigrations`, `:45-56`, with a live migration `D.MigrateMacroBarV2` at `:31` |
| `savedvariables-§4` diagnostics global outside AceDB | TOC comment above `## SavedVariables` explains the separation; `modules/PerfSetup.lua` hands the **name** to the library |
| `options-ui-§2` combat refusal (was CM-29) | `settings/Panel.lua:56-58` — `\|cff808080cannot open settings during combat — Blizzard's category-switch is protected\|r`, funnelled from both open paths |
| `options-ui-§5/§9` eager category, lazy body | `settings/Panel.lua:769-779` registers on the file's own PLAYER_LOGIN/ADDON_LOADED bootstrap; per-page builders register subcategories (`settings/General.lua:164`, `StatPriority.lua:299`, `MacroBar.lua:515`, `Category.lua:645`) |
| `options-ui-§1` `OnCommit`/`OnDefault`/`OnRefresh` not host-set | no occurrence in `settings/*.lua` — correct; the library stamps them |
| `options-ui-§1` load-completing stub (the documented exception) | `settings/Panel.lua:437-449` — `Helpers.LSMValues` is real regardless of the library, so `settings/MacroBar.lua:141,172` schema-row literals finish loading; `settings/Panel.lua:167-175` says it once. **Not flagged.** |
| `options-ui-§5` Defaults button parked, not built at registration | `settings/Panel.lua:317-329` — `ctx.panel.defaultsOnClick = …`, with the comment "Parked on the PANEL, not on the button: the button does not exist yet" |
| `slash-commands-§1/§2/§3` | `core/SlashCommands.lua:1302,1306-1352`; AceConsole at `core/ConsumableMaster.lua:207-208`; positional triples at `:1130-1241`; `reset` is path-form |
| `slash-commands-§4` one row formatter, two surfaces (was CM-27/28) | `core/SlashCommands.lua:1401-1404` `GetLandingRows()` → `Sl:LandingRows()`; the About page reaches rows through this seam, not its own formatter |
| `events-frames-taint-§4` protected-macro firewall | `CreateMacro`/`EditMacro`/`DeleteMacro` appear as calls only at `modules/MacroManager.lua:270,284,286,295`; every other reference is a comment or a read-only API |
| `events-frames-taint-§8` single secret-safe seam (was CM-24/25) | `core/CoreSetup.lua:73-74` publishes the library's own `IsConcatSafe`/`SafeToString`; `:76-99` builds `KCM.Say` from `lib:New`; the only second copy is the sanctioned lib-absent branch `:43-69` |
| `compat` | `core/Compat.lua` exists; `core/SpecHelper.lua:41,44` route through `KCM.Compat.*`; no direct deprecated spec calls elsewhere |
| `debug-logging-§1/§5` | `modules/DebugLog.lua:55,107-175` — silent-then-guarded lookup, all five required descriptor fields, session-only flag in `KCM.State.debug`, single `SetEnabled` seam |
| `debug-logging-§2` sanctioned font | `media/fonts/JetBrainsMono-Regular.ttf` + `media/fonts/OFL.txt`; registered at `modules/DebugLog.lua:38-41`; fallback `Fonts\ARIALN.TTF` at `:44`. **Explicitly not flagged.** |
| `standalone-windows-§2` shared edge, library close control | `modules/DebugLog.lua:167-174` — `skin` deliberately **not** passed; no `makeCloseButton` hook; no `ApplySkin`/hardcoded edge values anywhere in `core/`, `modules/`, `settings/` |
| `layout-§3` typed media subfolders | `media/fonts/`, `media/logos/` (`.tga` + `.jpg`), `media/screenshots/` — nothing loose |
| `localization-§1/§3/§5` | `locales/enUS.lua` with metatable fallback; zero British spellings (A.5) |
| `packaging` | `.pkgmeta` — no `externals:`, no `enable-toc-creation`, ignores `docs`/`tests` |
| `documentation-§1` README structure & badges | `README.md:1-9` H1 + five badges in canonical templates (`_` in the standard badge, `%2F` in tests); `:37` `## What's new in 1.5.0` immediately above `:45` `## Screenshots`; `:287` Version History top row is 1.5.0 and matches |
| `documentation-§6` three-place standards reference / #34 | TOC `## X-Standard:`; `README.md:6` badge; `CLAUDE.md:5` `## Standards compliance (read first)` |
| `documentation-§3` / #49 no scaffolding pack | A.5 — no `agent-context` file of any name |
| `documentation-§4` / #27 no TODO | A.5 — no `TODO*` file |
| `audit-review-history` | `docs/audits/{2026-07-12,2026-07-18}`, `docs/reviews/{2026-05-02,2026-08-03}` all retained and untouched by this run |
| `testing-§8` degraded path loaded for real | `tests/loader.lua:99-104,184` — `omitLibs` feeds a deliberately partial file list and lets each setup file take its own fallback, rather than hand-stubbing |
| `versioning-git` | TOC `## Version: 1.5.0`, `KCM.VERSION`, README badge/inline and Version History all agree; Interface `120007` ↔ README `Midnight_12.0.7`; trunk-based on `master`, clean tree at audit start |
