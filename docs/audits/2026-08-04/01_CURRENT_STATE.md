# 01 — Current State

**Addon:** Ka0s Consumable Master · **Version:** 1.5.0 · **Repo HEAD:** `21e7db4` ("docs+i18n: adopt standard v2.17.1 — US English spelling throughout")
**Audit date:** 2026-08-04 · **Deviation prefix:** `CM-`
**Audited against:** **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)** — `standards/STANDARDS.md` plus **all 24** section files listed in its Sections map, plus `AUDIT.md` (playbook).

## Standard provenance

The standard was fetched **over the network from the canonical raw URLs** and every file verified
byte-identical against the local canonical checkout. No section was reconstructed from memory.

| Artifact | How obtained | Verification |
|---|---|---|
| `AUDIT.md` | `curl -fsSL --max-time 15 $RAW/AUDIT.md` | `diff` vs `WowAddonStandards/AUDIT.md` — **identical** |
| `standards/STANDARDS.md` | `curl -fsSL --max-time 15 $RAW/standards/STANDARDS.md` | `diff` vs local — **identical** |
| 24 section files under `standards/standards/` | `curl -fsSL --max-time 8` each, discovered by following the index's Sections links | `diff -r` of all 24 vs local — **ALL SECTIONS BYTE-IDENTICAL** |

Local canonical checkout used for the identity check: `/mnt/d/…/GIT/WowAddonStandards`, clean tree,
HEAD `2141122996c6c2db2e1c4a88a1f5d152dce2de928` — `v2.17.1`. That checkout was **read only**; nothing
was written to it. Sections read: `layout`, `toc-file`, `library-stack`, `architecture`,
`savedvariables`, `options-ui`, `standalone-windows`, `preview-mode`, `slash-commands`,
`localization`, `events-frames-taint`, `public-api`, `compat`, `debug-logging`, `packaging`, `lint`,
`testing`, `performance`, `documentation`, `audit-review-history`, `versioning-git`,
`naming-cheatsheet`, `anti-patterns`, `open-evolutions`. **No section was left unassessed.**

## Headline

Consumable Master is a **mature, largely compliant LibKa0s consumer**. All five LibKa0s majors are
vendored whole-folder and byte-identical to the source repo, four of them are wired through real
descriptors with real degradation stubs, the message bus is per-receiver-target correct, the chat
seam is secret-safe and single, lint is clean and 600 headless cases pass. The open gaps cluster in
three places: the **test harness is still hand-rolled** while the vendored kit sits unused; the
**performance surface is half-adopted** (harness wired, but no offline runner, no perf docs, no
lint global, and a bracket shape that pays an `NS` lookup per call); and several **LibKa0s setup
files and the defaults file sit in non-canonical locations**, one of which is what forces the
bracket-shape defect.

---

## Layout (`layout`)

Modular layout present: `core/ defaults/ settings/ locales/ modules/ media/ libs/ tests/ docs/`,
nothing loose at the repo root beyond `README.md`, `CLAUDE.md`, `LICENSE`, `CHANGELOG.md`,
`.luacheckrc`, `.pkgmeta`, `ConsumableMaster.toc`.

- Folder casing is correct throughout — `libs/` lowercase, Lua files PascalCase (`core/BagScanner.lua`,
  `modules/MacroBar.lua`).
- `media/` uses typed subfolders only: `media/fonts/` (JetBrainsMono-Regular.ttf + OFL.txt),
  `media/logos/` (`.tga` runtime + `.jpg` source), `media/screenshots/`. Nothing loose in `media/`.
- **File sizes:** largest source file is `core/SlashCommands.lua` at **1408 LOC** — under the 1500 cap,
  inside the 1000–1500 "on notice" band. `settings/Panel.lua` is 927 LOC. No file exceeds 1500.
- **Off-layout files:** `modules/DebugLog.lua` and `modules/PerfSetup.lua` are LibKa0s **setup** files
  living under `modules/` rather than `core/` (→ CM-44, CM-45). `defaults/Profile.lua` does not exist;
  profile defaults are declared inline at `core/ConsumableMaster.lua:25` (→ CM-48). `settings/Schema.lua`
  does not exist; schema rows are appended to `KCM.Settings.Schema` by each `settings/<page>.lua`
  (acceptable — architecture-§5's single source is satisfied).
- **Core load order** in the TOC begins `Namespace → ConsumableMaster → Bus → Constants → CoreSetup →
  Compat → State → Database → Debug → …`, not layout-§1's mandated `Compat → Constants → Namespace`
  (→ CM-49). Each position is commented with its reason in the TOC.

## TOC (`toc-file`)

`ConsumableMaster.toc`, single file, CRLF line endings, single trailing newline.

- Metadata block is in the **exact required order**: `Interface(120007) → Title → Notes → Author →
  Version(1.5.0) → IconTexture → SavedVariables → OptionalDeps → DefaultState → Category-enUS →
  X-License(MIT) → X-Standard → X-Curse-Project-ID(1522944)`. The 2026-07-18 finding **CM-31**
  (field order) is **remediated**.
- `X-Wago-ID` / `X-WoWI-ID` are absent — **correct** under v2.17.1, which makes both **MAY**
  (list only where actually published). The 2026-07-18 finding **CM-32** is **retired by a standard
  change**, not by a code change.
- Two SavedVariables globals, in order: `ConsumableMasterDB, ConsumableMasterPerfDB`. No third global.
- Single Interface line, no multi-flavor list, no `_Classic` splits, no `WOW_PROJECT_ID` anywhere in
  addon source.
- File listing uses `#` section headers in order **Libraries → Locales → Core → Defaults → Modules →
  Settings**, matching toc-file-§5. Libraries first, Settings last.
- `libs\LibKa0s\LibKa0s.xml` is listed **once**, as the single aggregate, after Ace3 — no individual
  LibKa0s module `.lua` lines. No addon-authored `embeds.xml`.

## Library stack (`library-stack`)

`libs/` holds: `LibStub`, `CallbackHandler-1.0`, `AceAddon-3.0`, `AceDB-3.0`, `AceEvent-3.0`,
`AceConsole-3.0`, `AceGUI-3.0`, `AceGUI-3.0-SharedMediaWidgets`, `LibSharedMedia-3.0`, `LibKa0s`.
All vendored and committed; `.pkgmeta` has no `externals:` block. AceTimer-3.0 is not vendored and
not used.

- **`libs/LibKa0s/` is the whole ship folder** — `Core.lua`, `DebugLog.lua`, `Slash.lua`,
  `Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, plus
  `LibKa0s.xml` and `LICENSE`. **Vendor-sync diff is empty** (see `03_EVIDENCE.md`). No `#48`.
- **`tests/_kit/` is the whole `testkit/` folder** — `framework.lua`, `loader.lua`, `mock_base.lua`,
  `README.md`. **Diff is empty.** It is under `tests/`, never `libs/`. Correct placement — but the
  addon does not actually *consume* it (→ CM-34).
- No lib forks; no suite dependencies (`ElvUI`/`DBM`/`WeakAuras` appear nowhere in source).
  `libs/` carries no local patches — the `diff -r` proves it.
- `LibStub("AceGUI-3.0")` is resolved **without** the silent flag at three separate file-load sites
  (`settings/Panel.lua:19`, `settings/StatPriority.lua:23`, `settings/Category.lua:29`) rather than
  once and stashed on the namespace (→ CM-51).

## Architecture (`architecture`)

- Every file opens `local _, NS = ...` / `local addonName, NS = ...`; no `_G[addonName]` table.
- AceAddon registration at `core/ConsumableMaster.lua`, with `NS` passed as the first arg.
- **AceConsole clobber is structurally impossible here**: the addon's printer is named `KCM.Say`, not
  `NS.Print`, so AceConsole's `:Print` mixin has nothing to collide with. Documented at
  `core/CoreSetup.lua:17-20`. Anti-pattern #36 — clear.
- Modules published idempotently (`KCM.<Module> = KCM.<Module> or {}`).
- **Message bus is correct.** `core/Bus.lua` embeds AceEvent on `KCM.bus` for sending, exposes
  `KCM.NewBusTarget()` for receivers, and **every receiver registers on its own target**
  (`core/Bus.lua:47`, `modules/MacroBar.lua:450`, `settings/Panel.lua:917,921`). Four messages, all
  `Ka0s_ConsumableMaster_`-prefixed, catalogued in `core/Bus.lua:8-19` and `docs/ARCHITECTURE.md`.
  One sender each. Anti-pattern #32 — clear.
- **Schema-as-single-source** present: `KCM.Settings.Schema`, one write seam
  `Helpers.SetAndRefresh` (`settings/Panel.lua:609`) shared by the panel widgets and the slash CLI
  descriptor's `set`/`applyDefault`. `Helpers.ValidateSchema` (`settings/Panel.lua:136`) walks every
  row at boot.

## SavedVariables (`savedvariables`)

- `ConsumableMasterDB` via AceDB; `ConsumableMasterPerfDB` as the single sanctioned diagnostics
  global, written directly by LibKa0s-Perf, outside the AceDB tree. TOC comment at the declaration
  explains why.
- `schemaVersion` declared (`core/ConsumableMaster.lua:34`) and a real migration runner ships at
  `core/Database.lua:41` (`D.RunMigrations`), with one live migration (`MigrateMacroBarV2`).
- **Profile defaults are not in `defaults/Profile.lua`** — they are inline at
  `core/ConsumableMaster.lua:25` (→ CM-48). `defaults/` holds the data tables
  (`Categories.lua`, `Defaults_*.lua`) instead.

## Options UI (`options-ui`)

`LibKa0s-Options-1.0` is resolved and instantiated at `settings/Panel.lua:186-193` from a descriptor
carrying `mainPanelName`, `parentTitle`, `print`, `colorDecode`/`colorEncode`, `sliderCommit`,
`getLSM`, `get`, `set`. The panel shell, header, breadcrumb, lazy Defaults button, scroll container
and always-shown-scrollbar patch are all the library's. Row widget makers, `RenderGrid`,
`SessionCheckbox`, `AddSpacer`, `Section`, `ClearScroll`, `SetRenderer`, `RefreshAllPanels` are bound
from the instance.

- Combat lockdown refusal is canonical and gray at `settings/Panel.lua:56-58`, funnelled from both
  the slash path and the sidebar `OnShow` guard. CM-29 **remediated**.
- Category registration is eager (`settings/Panel.lua:769-779`, driven by the file's own
  PLAYER_LOGIN/ADDON_LOADED bootstrap), bodies are lazy per-page.
- Subcategories registered with `Settings.RegisterCanvasLayoutSubcategory` from each page builder;
  no `InterfaceOptions_AddCategory`.
- `OnCommit`/`OnDefault`/`OnRefresh` are **not** set by the host — correct, the library stamps them.
- **Two MUST gaps:** the host member `KCM.Settings.Helpers` is a **fresh table that copies members
  across** from the instance rather than *being* the instance (→ CM-36); and two library layout
  constants are **restated as host locals** — `SECTION_HEADING_H = 26` and
  `BUTTON_PAIR_REL = 0.492` at `settings/Panel.lua:74-75` (→ CM-37).
- The Options seam has no file of its own; it lives inside the 927-line `settings/Panel.lua`
  (→ CM-46).
- Degradation is **load-completing**, as the standard's one documented exception requires:
  `Helpers.LSMValues` stays a real function even with the lib absent
  (`settings/Panel.lua:437`), so `settings/MacroBar.lua`'s schema-row literals finish loading; the
  panel-open says one honest line once (`settings/Panel.lua:167-175`). This is **correct** and is
  not flagged.

## Standalone windows / preview mode (`standalone-windows`, `preview-mode`)

The addon draws **no data-browser window of its own**. Its two windows — the debug console and the
perf step panel — are **the library's**, drawn and skinned by `LibKa0s-Core-1.0`'s shared `SKIN`;
`modules/DebugLog.lua:167-174` explicitly declines to pass a `skin` override and explains why, and
no `makeCloseButton` hook is passed. No host code calls `ApplySkin`/`MakeCloseButton`, and none
needs to. No hardcoded edge values anywhere. `standalone-windows` is therefore satisfied by
construction.

The optional **macro bar** (`modules/MacroBar.lua`) is a positionable bar, `SetClampedToScreen(true)`
at `modules/MacroBar.lua:94`, with position/geometry persisted in the profile. It renders **live
macro icons** at all times, including while unlocked for dragging, so the user positions it against
real content — the outcome preview-mode-§1 exists to produce. Recorded as **satisfied**, not as a gap.

## Slash commands (`slash-commands`)

`LibKa0s-Slash-1.0` resolved at `core/SlashCommands.lua:1302` and instantiated from a descriptor
(`slash`, `slashAliases`, `commands`, `aliases`, `version`, `print`, `L`, `get`, `set`, `findRow`,
`allRows`, `applyDefault`, `groupKey`, `colorDecode`/`colorEncode`).

- `KCM.COMMANDS` stays the host's, ordered, positional triples (`core/SlashCommands.lua:1130-1241`).
- Registered through AceConsole at `core/ConsumableMaster.lua:207-208` (`/cm`, `/consumablemaster`);
  no `SLASH_*` globals.
- Reserved verbs all present and correct: `help`, `config`, `version`, `perf`, `debug`, `reset`
  (**path** form), `resetall`, `list`, `get`, `set`. Host verbs: `resync`, `rewritemacros`, `bar`,
  `priority`, `stat`, `aio`, `dump`.
- The About/landing command rows and the chat help block render through **one** formatter — the
  library's — via `KCM.SlashCommands.GetLandingRows()`. CM-25…CM-28 **remediated**.
- Degradation stub names the missing library rather than re-implementing the dispatcher
  (`core/SlashCommands.lua:1363-1370`).
- The dispatcher is built in `core/SlashCommands.lua`, not `settings/Slash.lua` (→ CM-47).

## Localization (`localization`)

- `locales/enUS.lua` only; `NS.L` is a metatable-fallback table; no AceLocale strict mode.
- **US English throughout** — a sweep for `colour|grey|behaviour|centre|cancelled|-ise|-isation|
  analyse|catalogue|dialogue|defence|licence|favour|labelled|travelled|fulfil` across `core/`,
  `modules/`, `settings/`, `locales/`, `defaults/`, `README.md`, `CLAUDE.md` and `docs/*.md`
  returned **zero hits**. localization-§5 clean.
- Item and weapon **classification** keys on locale-independent `classID`/`subClassID`
  (`core/Classifier.lua`, `core/WeaponSlots.lua`) — correct.
- **Tooltip-TEXT parsing remains English-only** (`core/TooltipCache.lua:47-123`, `97-100`), a
  documented, tracked deviation recorded at `docs/scope.md:20` and carried forward as **CM-30**.

## Events / frames / taint (`events-frames-taint`)

- AceEvent used throughout; no per-module event frames.
- **Protected macro APIs are firewalled**: `CreateMacro` / `EditMacro` / `DeleteMacro` are called
  from exactly one module, `modules/MacroManager.lua:270-295`. Every other file only reads
  (`GetMacroInfo`, `GetMacroIndexByName`, `PickupMacro`).
- Combat-conditional visibility on the macro bar uses `RegisterStateDriver`, the taint-free route.
- **Secret-safe seam is single and correct.** `KCM.IsConcatSafe` / `KCM.SafeToString` are
  `LibKa0s-Core-1.0`'s own function values (`core/CoreSetup.lua:73-74`); `KCM.Say` is
  `printer.Format` off `lib:New{ prefix = fn, sink = fn }` (`core/CoreSetup.lua:76-99`). CM-24 and
  CM-25 **remediated**. The only guarded second copy is the sanctioned library-absent branch at
  `core/CoreSetup.lua:43-69`.
- The remaining bare `print(` occurrences are **inside macro body strings** the player's macro
  executes (`modules/MacroManager.lua:99,108,233,239`, `defaults/Categories.lua:39`) — not addon
  chat output. Not a deviation.

## Compat / public API (`compat`, `public-api`)

`core/Compat.lua` ships and is the sole route to the deprecated spec APIs — `core/SpecHelper.lua:41,44`
call `KCM.Compat.GetSpecialization()` / `.GetSpecializationInfo()`, never the globals. No
`WOW_PROJECT_ID` branching. The addon exposes no public API surface; `public-api` is N/A.

## Debug / logging (`debug-logging`)

`LibKa0s-DebugLog-1.0` resolved at `modules/DebugLog.lua:55` and instantiated from a descriptor with
all five required fields (`name`, `title`, `font`, `isEnabled`, `setEnabled`) plus `fontSize`,
`print` (a call-time thunk), `initSummary`, `onVisibilityChanged`, `slash`.

- Flag is session-only in `KCM.State.debug`, never persisted; `SetEnabled` is the single write path.
- The sink is `KCM.Debug` (`core/Debug.lua`), which **delegates to the library instance's gated
  `Debug`** when one exists and falls through to tagged chat during early boot or a degraded install
  — the probe is host-side and documented at `core/Debug.lua:30-36`.
- Shipped monospace font: `media/fonts/JetBrainsMono-Regular.ttf` + `OFL.txt`, registered with LSM,
  Blizzard `Fonts\ARIALN.TTF` fallback. **Sanctioned exception — not flagged.**
- The stub omits `AddLine` **deliberately, with the reason written down** at
  `modules/DebugLog.lua:97-103` (withholding it re-arms `core/Debug.lua`'s chat fallback). Per
  AUDIT.md that is a decision, not a gap — **not flagged**.
- File location is `modules/DebugLog.lua`, not `core/DebugLogSetup.lua` (→ CM-44).

## Performance (`performance`)

`LibKa0s-Perf-1.0` resolved at `modules/PerfSetup.lua:29`, instance published as `KCM.Perf`
(the instance itself, with the reason documented at lines 17-24). Buckets declared in report order:
`cooldown`, `recompute`. `suspend`/`resume` implemented at `modules/PerfSetup.lua:44-59`, enforcing
inertness at the source and restoring from current state by calling `KCM:OnEnable` rather than a
snapshot. `perf` verb dispatches through `KCM.COMMANDS` (`core/SlashCommands.lua:1141-1149`) and the
host prints the returned lines. `ConsumableMasterPerfDB` declared in the TOC, outside the AceDB tree.

Five gaps:

- Bracket sites do `local perf = KCM.Perf` **inside the function**, per call
  (`core/ConsumableMaster.lua:268`, `modules/MacroBar.lua:322`) rather than as a load-time upvalue
  (→ CM-39). This is a direct consequence of `modules/PerfSetup.lua` loading *after* both sites.
- No `tests/perf.lua` — the offline scenario runner and its **required** zero-overhead evidence are
  absent (→ CM-38).
- No test pins that each declared bucket is reached by a real bracket (→ CM-40).
- `ConsumableMasterPerfDB` is **not** in `.luacheckrc` `globals` (→ CM-41).
- `docs/performance.md` and `docs/perf-runs/README.md` are absent (→ CM-42, CM-43).

## Lint (`lint`)

`.luacheckrc` present. `std = "lua51"`, `max_line_length = false`, `codes = true`,
`exclude_files = { libs/, docs/audits/, docs/reviews/, tests/ }`, `debugprofilestop` in `read_globals`
with a comment. `globals` are commented. **`luacheck .` → 0 warnings / 0 errors in 52 files.**
Gaps: `ConsumableMasterPerfDB` missing from `globals` (CM-41); the `ignore` list is broader than the
template — `{ "212", "542", "241" }`, where `241` suppresses a known dead-code smell repo-wide
(advisory CM-52).

## Testing (`testing`)

`lua tests/run.lua` → **600 passed, 0 failed, 600 total**, exit 0. `--list` mode exists and
`docs/test-cases.md` is generated from it; the README `[tests]` badge reads `600/600 passing` — in
lockstep.

- `tests/_kit/` is vendored whole and byte-identical, and `tests/test_vendor_sync.lua:145` pins that
  identity from inside the suite — a genuine mechanical gate, not a remembered diff.
- **But the kit is not used.** `tests/run.lua` requires `tests/harness.lua`, a hand-written registry /
  assertion set / `--list` renderer, over `tests/loader.lua`, a hand-written sandboxed source loader,
  over `tests/wow_mock.lua` (623 LOC), a hand-written mock that does **not** extend
  `tests/_kit/mock_base.lua`. The only reference to `_kit` outside the sync test is a comment
  (`tests/harness.lua:133`). → **CM-34**, anti-pattern #47.
- The load list is partly derived (`L.tocFiles()` at `tests/loader.lua:213`, used by
  `loadFullAddon`) and partly hand-maintained — `L.PURE_LAYER` (`tests/loader.lua:79-94`) is a
  33-entry hand-copied list that nearly every suite loads through (→ CM-35). The vendored-library
  list *is* spelled out explicitly and pinned against the XML, which is correct.
- The degraded path is exercised **for real** — `loadFiles(..., omitLibs)` feeds the loader a
  deliberately partial file list and lets each setup file take its own fallback
  (`tests/loader.lua:99-104`). This is exactly what testing-§8 asks for.
- Suites cover schema, database, classifier, ranker, selector, macro manager, macro bar, slash,
  settings UI, widgets, pipeline, events, compat, and the three LibKa0s seams
  (`test_coresetup`, `test_debuglog`, `test_perfsetup`, `test_slashsetup`, `test_libka0s`).
- Mutation-verification of negative assertions (testing-§12) leaves no repo artifact and is
  recorded as **unverified**, not as a deviation.

## Packaging (`packaging`)

`.pkgmeta` present: `package-as: ConsumableMaster`, `enable-nolib-creation: no`, no `externals:`,
no `enable-toc-creation`. Ignores `docs`, `tests`, `.luacheckrc`, `.pkgmeta`, `.gitignore`,
`.gitattributes`, `*.bak`, `media/screenshots`. `_dev/` is not listed but does not exist.
`.claude/`, `.superpowers/` and `CHANGELOG.md` are not ignored (advisory CM-56).

## Documentation (`documentation`)

- Root ships `README.md`, `CLAUDE.md`, `LICENSE` (+ `CHANGELOG.md`).
- **README** follows the canonical order: H1 → five badges (correct templates, `_` not `%20` in the
  standard badge, `%2F` in the tests badge) → logo → description → `## What's new in 1.5.0` →
  `## Screenshots` → `## Usage` (`### Slash commands`, `### Settings panel`) →
  `## How picking & ranking works` → `## FAQ` → `## Troubleshooting` →
  `## Credits and bundled libraries` → `## Issues and feature requests` → `## Version History`.
  `## What's new` matches the top Version History row (1.5.0). No `## Testing` section. **No
  angle-bracket placeholders** — the only `<…>` in the README are deliberate `<code>` / `<strong>`
  in a table, which documentation-§1 explicitly protects. One extra non-canonical section
  (`## Credits and bundled libraries`) sits between Troubleshooting and Issues (advisory CM-55).
- **`CLAUDE.md`** is a stub with the verbatim-in-substance `## Standards compliance (read first)`
  section (CM-33 **remediated**), a "read the docs" pointer list, and the green-gate line. Its H1 is
  `# CLAUDE.md` rather than `# CLAUDE.md — Ka0s Consumable Master` (→ CM-50). It also carries an
  explicit `docs/agent-context.md` prohibition section.
- **`docs/` trio present**: `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`. Generated
  `test-cases.md` present. Topic-detail docs: `common-tasks`, `data-model`, `debug`, `file-index`,
  `macro-bar`, `macro-manager`, `midnight-quirks`, `module-map`, `pipeline`, `scope`.
  **Missing required topic-detail docs:** `docs/performance.md` (CM-42), `docs/perf-runs/README.md`
  (CM-43). `docs/complexity.md` absent (SHOULD, advisory).
- **No `docs/agent-context.md`** anywhere — anti-pattern #49 clear. **No `TODO.md`** anywhere —
  anti-pattern #27 clear. `docs/pending/LEDGER.md` is a LibKa0s-adoption deviation ledger that also
  reads as a second backlog (advisory CM-57).
- Three-place standards reference: TOC `X-Standard` ✔, README standard badge ✔,
  `CLAUDE.md → ## Standards compliance (read first)` ✔. Anti-pattern #34 clear.

## Audit / review history (`audit-review-history`)

`docs/audits/2026-07-12/`, `docs/audits/2026-07-18/`, `docs/reviews/2026-05-02/`,
`docs/reviews/2026-08-03/` — all retained, none edited by this run. This run writes only
`docs/audits/2026-08-04/`.

## Versioning & git (`versioning-git`)

Semver `1.5.0` in TOC, `KCM.VERSION`, README badge/inline and Version History table — consistent.
Interface `120007` matches the README `[wow]` badge (`Midnight_12.0.7`). Trunk-based on `master`;
working tree clean at audit start. `CLAUDE.md` carries an explicit never-auto-commit and
never-auto-bump rule.
