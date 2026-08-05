# 01 — Current State

**Addon:** Ka0s Consumable Master (`ConsumableMaster`, v1.5.0, Interface 120007)
**Audit date:** 2026-08-05 · **Prefix:** `CM-`
**Audited against:** **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**
**Repo HEAD at audit:** `6b7d3d0` ("docs: write the missing ANALYSIS.md and re-anchor the RESULTS.md prose")
**Working tree:** clean except the untracked `docs/reviews/2026-08-05/` bundle written by the code review that ran immediately before this audit.

---

## 0. Standard provenance

Fetched over the network with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, then read from disk
(no summarizer in the path):

| File | Bytes | Status |
|---|---|---|
| `AUDIT.md` | 12333 | fetched |
| `standards/STANDARDS.md` | 91149 | fetched — front matter reads **v2.21.0 (2026-08-04)** |
| `standards/standards/anti-patterns.md` | 25253 | fetched |
| `standards/standards/architecture.md` | 8429 | fetched |
| `standards/standards/audit-review-history.md` | 1676 | fetched |
| `standards/standards/automated-tests.md` | 16249 | fetched |
| `standards/standards/compat.md` | 1387 | fetched |
| `standards/standards/debug-logging.md` | 26536 | fetched |
| `standards/standards/documentation.md` | 26623 | fetched |
| `standards/standards/events-frames-taint.md` | 10661 | fetched |
| `standards/standards/layout.md` | 4607 | fetched |
| `standards/standards/library-stack.md` | 20105 | fetched |
| `standards/standards/lint.md` | 1725 | fetched |
| `standards/standards/localization.md` | 8859 | fetched |
| `standards/standards/naming-cheatsheet.md` | 2401 | fetched |
| `standards/standards/open-evolutions.md` | 3779 | fetched |
| `standards/standards/options-ui.md` | 30650 | fetched |
| `standards/standards/packaging.md` | 1457 | fetched |
| `standards/standards/performance.md` | 27776 | fetched |
| `standards/standards/preview-mode.md` | 1390 | fetched |
| `standards/standards/public-api.md` | 802 | fetched |
| `standards/standards/savedvariables.md` | 4661 | fetched |
| `standards/standards/slash-commands.md` | 21078 | fetched |
| `standards/standards/standalone-windows.md` | 6306 | fetched |
| `standards/standards/testing.md` | 26202 | fetched |
| `standards/standards/toc-file.md` | 6497 | fetched |
| `standards/standards/versioning-git.md` | 1762 | fetched |
| `standards/ADDONS.md` | — | fetched |

**25 section files** were discovered by following the Sections list in `STANDARDS.md`; all 25
resolved. `standards/standards/tiered-layout.md` 404s and is correct to — the only reference to it in
`STANDARDS.md` is inside the **v2.0.0 changelog entry** recording its rename to `layout.md`
(`STANDARDS.md:122`), which is frozen history, not a Sections link. No section was left unassessed
and nothing was reconstructed from memory.

**Constraint on this run.** The invoking harness pinned this session to this repo alone, so the
sibling `../LibKa0s` checkout could **not** be read. Every vendor-drift `diff -r` is therefore
recorded as **not run**, with the path attempted, in `03_EVIDENCE.md`. It is reported as unverified,
never as a pass.

---

## 1. Layout (`layout`)

Modular layout, as mandated: `core/ defaults/ settings/ locales/ modules/`, plus `libs/`, `media/`,
`tests/`, `docs/`. No loose source at the repo root. Folder casing is lowercase throughout; Lua files
are PascalCase. `media/` has typed subfolders only — `media/logos/` (`consumemaster.logo.tga` runtime
+ `.jpg` source), `media/screenshots/` (7 PNGs), `media/fonts/` (`JetBrainsMono-Regular.ttf` + `OFL.txt`).

- **File sizes.** 136 `.lua` files. Largest addon files: `settings/Panel.lua` 950,
  `core/SlashCommands.lua` 836, `settings/Category.lua` 725. **No addon file is in the 1000–1500
  on-notice band and none is over the 1500 cap.** One **test** file is: `tests/test_macrobar.lua`
  at **1497** — 3 lines under the cap, already carried in `docs/automated-tests/RESULTS.md`'s band
  table with a disposition.
- **`core/` load order** is `Namespace → ConsumableMaster → Bus → Constants → CoreSetup → Compat →
  State → Database → Debug → SpecHelper → TooltipCache → WeaponSlots → BagScanner → Classifier →
  LSMPatch → MacroDisplay → MacroBarModel → MacroBarLayout → SlashDump → SlashCommands`
  (`ConsumableMaster.toc:41-77`). `layout-§1` mandates `Compat → Constants → Namespace → other core`.
  This is **CM-49**, carried unchanged from the 2026-08-04 run.
- Two setup files sit in `modules/` rather than `core/`: `modules/DebugLog.lua` (**CM-44**) and
  `modules/PerfSetup.lua` (**CM-45**). The Options seam has no file of its own at all (**CM-46**).
- `defaults/` holds the 14 data tables and a `README.md`, but **not** `Profile.lua` — the profile
  defaults are inline at `core/ConsumableMaster.lua:25` (**CM-48**).

## 2. TOC (`toc-file`)

`ConsumableMaster.toc` metadata block is in the exact `toc-file-§1` order: `Interface, Title, Notes,
Author, Version, IconTexture, SavedVariables, OptionalDeps, DefaultState, Category-enUS, X-License,
X-Standard, X-Curse-Project-ID`. `X-License: MIT` ✓. `X-Standard:` present ✓. `X-Curse-Project-ID:
1522944` ✓; `X-Wago-ID`/`X-WoWI-ID` correctly omitted (MAY, not published there). Two SavedVariables
globals in the mandated order — `ConsumableMasterDB, ConsumableMasterPerfDB` — with a comment
explaining why the perf ring is outside the AceDB tree.

File listing sections are `# Libraries → # Locales → # Core → # Defaults → # Modules → # Settings`,
matching `toc-file-§5`. `libs\LibKa0s\LibKa0s.xml` is listed **once**, as the packaged aggregate, in
`# Libraries` after Ace3 — no individual `LibKa0s` `.lua` file appears. No addon-authored
`embeds.xml`. Single `## Interface: 120007`, no flavor fan-out.

## 3. Library stack (`library-stack`)

Vendored under `libs/`: `LibStub`, `CallbackHandler-1.0`, `LibSharedMedia-3.0`, `AceAddon-3.0`,
`AceEvent-3.0`, `AceDB-3.0`, `AceConsole-3.0`, `AceGUI-3.0`, `AceGUI-3.0-SharedMediaWidgets`, and
`LibKa0s`. `.pkgmeta` declares no `externals:`; everything is committed.

`libs/LibKa0s/` holds ten files — `Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua`,
`OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, `LibKa0s.xml`, `LICENSE` —
and `libs/LibKa0s/LibKa0s.xml` lists all eight modules in dependency order. That is the shape of a
whole ship folder: no shell without its attach file, no dependent module without `Core.lua`. The
README records the pinned release (`README.md:277`, "Bundles [LibKa0s](…) v1.7.0 (MIT)."). The
harness is vendored to `tests/_kit/` (5 files) and **not** to `libs/`, which is correct.

Byte-identity against the source repo is **not verified this run** (see §0).

`AceGUI-3.0` is resolved **non-silently at file load** in three page files
(`settings/Panel.lua:19`, `settings/StatPriority.lua:23`, `settings/Category.lua:29`) — **CM-51**.

## 4. Shared-subsystem wiring (the descriptors, not a search for hand-built code)

The addon owns a descriptor plus a degradation branch per LibKa0s module. It carries **no** console
window, **no** widget makers or flow engine, **no** dispatcher/parser of its own, and its
`libs/LibKa0s/` is not locally patched. Anti-pattern #47 does **not** apply to the four shipped
subsystems; the one place it does apply is the test harness (§8).

| Module | Setup file | Lookup | Degradation |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `:33` `LibStub("LibKa0s-Core-1.0", true)` | `:35-71` — real fallback `IsConcatSafe`/`SafeToString`/`Say`, one honest line said once |
| `LibKa0s-DebugLog-1.0` | `modules/DebugLog.lua` | `:55` | `:57-104` — member-answering stub; **deliberately** publishes no `AddLine`, reason written at `:97-103` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` | `:237` | `:297-305` — stub answers `printHelp/cliList/cliGet/cliSet/cliReset`, but `KCM:OnSlashCommand` short-circuits **every** verb (**CM-65**) |
| `LibKa0s-Options-1.0` | `settings/Panel.lua:186-252` (no file of its own — **CM-46**) | `:186` | load-completing by design; but two runtime members are left `nil` (**CM-58**) |
| `LibKa0s-Perf-1.0` | `modules/PerfSetup.lua` | `:29` | `:36` `if not lib then return end` — no `KCM.Perf` at all; the `perf` verb answers "perf capture unavailable." (`settings/Slash.lua:81-83`) |

The `Core` and `DebugLog` stubs were walked against their call sites and answer every member the
addon reaches. The `Options` stub's *load-completing* shape is the standard's one documented
exception and is **not** flagged; what is flagged is that `RefreshAllPanels`/`RefreshScalars` are
bound to `UI and UI.<member>` (`settings/Panel.lua:571-572`) and then called **unconditionally** on
runtime paths (`:643`, `:833`) — a call-time crash, not a load-time concession.

## 5. Architecture, bus, SavedVariables

`core/Namespace.lua` names the private `NS`; `core/ConsumableMaster.lua:6` promotes it through
`AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceConsole-3.0")`. No `_G[addonName]` write. The
bus is closed — `KCM.NewBusTarget()` (`core/Bus.lua:31`) hands each receiver its own AceEvent target,
and the options layer's two receivers are registered on one dedicated target
(`settings/Panel.lua:934-948`). AceDB is created at `core/ConsumableMaster.lua:203` with
`KCM.dbDefaults`; `schemaVersion` is declared (`:34`) and `core/Database.lua:45-56` is a real
migration runner. `ConsumableMasterPerfDB` is handed to the perf library by name
(`modules/PerfSetup.lua:76`) and stays outside the AceDB tree. No third top-level SV global.

No `stored.k or D.k` defaulting was found over settings fields — every `or` in the sweep is a
namespace-table initializer (`KCM.X = KCM.X or {}`) or a container guard. `savedvariables-§5` /
anti-pattern #54: clean.

## 6. Options UI

The panel is built from a `LibKa0s-Options-1.0` descriptor with `mainPanelName`, `parentTitle`, a
thunked `print`, positional `colorDecode`/`colorEncode`, `sliderCommit = "change"`, a call-time
`getLSM`, and `get`/`set` routed through the addon's single write seam `Helpers.SetAndRefresh`
(`settings/Panel.lua:193-236`). The combat-open refusal is the canonical gray line at `:56-58`.
Eighteen pages are declared in `KCM.Settings.order` (`:33-38`).

Two long-standing shape deviations remain: `KCM.Settings.Helpers` is a **fresh table** that copies
~10 members across from the instance rather than *being* the instance (`:41-42`, `:571-572` and
peers) — **CM-36**; and two library layout constants are restated as host locals (`:74-75`) —
**CM-37**.

## 7. Slash commands

`settings/Slash.lua` now owns the dispatcher: the ordered positional-triple `COMMANDS` table
(`:65-172`, 17 verbs), the `LibKa0s-Slash-1.0` descriptor and instance (`:241-283`), `GetLandingRows`
(`:335`) and `KCM:OnSlashCommand` (`:340`). `core/SlashCommands.lua` keeps only the verb bodies and
publishes them on `KCM.SlashCommands.Verbs`. **CM-47 from the 2026-08-04 run is closed by this
split**, and `core/SlashCommands.lua` fell from 1408 to 836 LOC with it.

All reserved verbs are present and mean the standard's thing: `help, config, version, perf, debug,
reset` (path-scoped), `resetall`, `list, get, set`. Registration is via AceConsole (no `SLASH_*`
globals). `perf` is registered by the addon, not the library.

## 8. Tests

`tests/_kit/` carries the vendored kit (`framework.lua`, `loader.lua`, `mock_base.lua`, `README.md`,
`run-automated-tests.sh`). **Nothing loads it.** `tests/run.lua:21` does `require("harness")`, and
`tests/harness.lua` (registry + assertions + `--list` renderer), `tests/loader.lua` (sandboxed
loader) and `tests/wow_mock.lua` (623 LOC, a full base mock rather than a thin extender over
`mock_base.lua`) are addon-authored forks of exactly those three kit files — **CM-34**, the one live
anti-pattern #47 in this repo. `tests/loader.lua:79-113` carries `L.PURE_LAYER`, a hand-maintained
33-entry file list rather than a TOC derivation — **CM-35**.

The suite itself is healthy: **656 cases, 656 passing**, 31 suite files, `--list` inventory
regenerated into `docs/test-cases.md`, README badge in lockstep.

## 9. Performance

`modules/PerfSetup.lua` declares two buckets (`cooldown`, `recompute`), `suspend`/`resume`, `sv`,
`slash = "/cm"`, thunked `log`/`print`/`showLog`. Two brackets exist —
`core/ConsumableMaster.lua:332-349` and `modules/MacroBar.lua:322-330` — and both do a **per-call
`KCM.Perf` table lookup** instead of a load-time upvalue (**CM-39**, anti-pattern #43). There is no
`tests/perf.lua`, so the mandated zero-overhead scenario has never been produced (**CM-38**), and
`tests/test_perfsetup.lua:141-144` only asserts that *no* bucket accrues while idle — nothing pins
that each declared bucket is reached (**CM-40**). `ConsumableMasterPerfDB` is still missing from
`.luacheckrc` `globals` (**CM-41**).

## 10. Debug logging

`modules/DebugLog.lua` registers the shipped JetBrains Mono with LSM, builds the console from the
library descriptor, and publishes a flat dot-callable facade (`DL.AddLine … DL.instance`, `:181-211`)
over the library's method surface, with the inversion between `Toggle` (flag) and `Toggle_Window`
(window) documented at `:12-17`. `core/Debug.lua`'s metatable (`:37-55`) probes `DL.instance` and
falls through to chat when there is none. The file's own comment at `:97-99` says the probe is on
`KCM.DebugLog.AddLine`; the probe is on `.instance` — a stale comment, carried as advisory.

## 11. Documentation

**Root:** `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE` — **and `CHANGELOG.md`**, a fourth
doc the standard's root set does not name (**CM-59**).

**README** carries all five canonical badges in order with the correct templates, including the
underscore-spaced standard badge and `Tests-656%2F656_passing`. Section order is H1 → badges → logo →
description → `## What's new in 1.5.0` → `## Screenshots` → `## Usage` → `## How picking & ranking
works` → `## FAQ` → `## Troubleshooting` → `## Credits and bundled libraries` → `## Issues and
feature requests` → `## Version History`. Every required section present in the required relative
order; the Credits section is an addition the canonical structure does not name (**CM-55**,
advisory).

**`CLAUDE.md`** is a stub with the verbatim-in-substance `## Standards compliance (read first)`
section, the docs pointer list, the green-gate block, and an explicit "there is no agent-context.md"
section. Its H1 is `# CLAUDE.md`, not `# CLAUDE.md — Ka0s Consumable Master` (**CM-50**).

**Three-place standards reference:** TOC `## X-Standard:` ✓, README badge #4 ✓, `CLAUDE.md`
`## Standards compliance (read first)` ✓. **All three present** — anti-pattern #34 does not apply.

**`docs/` canonical trio:** `ARCHITECTURE.md` ✓, `testing.md` ✓, `smoke-tests.md` ✓. `ARCHITECTURE.md`
is 189 lines and covers Overview, Module Map, Message-bus catalog, Load order and dependencies, but
has **no** Settings Schema, Slash Commands (`NS.COMMANDS` table), Event Subscriptions, Taint Notes or
Known Limitations sections (**CM-60**).

**Five required topic-detail docs:** `test-cases.md` ✓ · `performance.md` **missing** (**CM-42**) ·
`perf-runs/README.md` **missing** (**CM-43**) · `automated-tests/README.md` ✓ ·
`automated-tests/RESULTS.md` ✓.

**Retired `docs/complexity.md`:** **absent**. Correctly deleted; `docs/testing.md:164-165` records the
retirement. No finding.

`docs/pending/LEDGER.md` still doubles as a second backlog (**CM-57**, advisory). The retired global
`§N.M` notation survives in ~30 code comments (**CM-53**, advisory).

## 12. Automated-test record

Three frozen bundles under `docs/automated-tests/` (`20260804-182045`, `20260804-215640`,
`20260804-233147`), each with `manifest.json`, `ANALYSIS.md`, `lint.txt`, `tests.txt`,
`test-cases.md`, `complexity.txt`. `RESULTS.md` is one overwritten file with a three-row table, a
standing section per suite, and a watch list as **two tables with header rows** — warned functions
("None.", with the seven at the CCN-15 ceiling named rather than counted) and files by `layout-§1`
band (one row, `tests/test_macrobar.lua`). The runner is the vendored
`tests/_kit/run-automated-tests.sh`; `.gitattributes` carries `*.sh   text eol=lf`. The runner is
committed at mode **100644** — not executable (**CM-62**).

The **release gate** introduced in standard v2.21.0 (all four suites at `pass` plus
`suites.complexity.warnings == 0` at the tag, and a `skip` blocking as NOT EVALUATED) is **stated
nowhere** in this addon's docs; `docs/testing.md:141-157`, `docs/automated-tests/README.md:19-33` and
`CLAUDE.md`'s "It is a **report, not a gate**" line all describe the pre-v2.21.0 position
(**CM-61**).

## 13. Other sections

- **`compat`** — `core/Compat.lua` wraps the spec APIs, `issecretvalue` and spell-name lookup. It does
  **not** wrap the legacy item APIs, and five files call `GetItemInfo` directly (**CM-63**).
- **`localization`** — `locales/enUS.lua` with metatable fallback; no British spelling anywhere in
  authored source or docs (the one hit is `CHANGELOG.md:19` describing a past US-English sweep).
  `core/TooltipCache.lua` still parses English tooltip text for magnitudes (**CM-30**, the tracked
  accepted deviation, documented at `docs/scope.md:20`).
- **`lint`** — `.luacheckrc` present, `std = "lua51"`, correct `exclude_files`. `ignore` is broader
  than the template (**CM-52**, advisory).
- **`packaging`** — `.pkgmeta`, no `externals:`, ignores `docs`, `tests`, `.luacheckrc`,
  `.gitignore`, `.gitattributes`, `*.bak`, `media/screenshots`. `.claude/`, `.superpowers/` and
  `CHANGELOG.md` are not ignored (**CM-56**, advisory).
- **`versioning-git`** — semver `1.5.0` consistent across TOC, README badge/history and
  `KCM.VERSION`; trunk-based history.
- **`public-api`** — nothing exported; N/A.
- **`preview-mode`** — the macro bar is positionable; unlock-time preview is not shipped. Advisory
  only (SHOULD), and the bar renders live macro state while unlocked, which is the same render path.
- **`standalone-windows`** — the debug console and the perf step panel are the library's; the addon
  ships no data-browser window of its own. N/A.
- **`events-frames-taint`** — `MacroManager` is the sole caller of the protected macro writers;
  secret values route through `Compat.IsSecret` and `KCM.SafeToString`; combat-conditional bar
  visibility uses `RegisterStateDriver`. No finding.
