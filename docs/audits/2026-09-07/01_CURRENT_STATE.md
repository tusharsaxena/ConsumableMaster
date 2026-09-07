# 01 — Current state

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit:** 2026-09-07
**Audited against:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)** — `standards/STANDARDS.md`
plus all 26 section files under `standards/standards/`, fetched verbatim with `curl -fsSL`.
**Playbook:** `AUDIT.md` at the standards-repo root, fetched the same way.
**Rule set:** the **addon** rule set — the repo ships `ConsumableMaster.toc`, so `AUDIT.md` step 1's
switch to `library-stack-§7`'s applicability list does not apply.

Repo HEAD at audit time: `ce572a3` (`Merge branch 'feat/settings-revamp-v2'`, 2026-09-03), tree clean.

---

## Layout (`layout`)

`core/` (25 files), `defaults/` (17), `settings/` (7), `locales/` (1), `modules/` (10), plus
`libs/`, `media/`, `tests/`, `docs/`. No loose source at the root. Subfolders lowercase, Lua files
PascalCase (`naming-cheatsheet`).

Files at or above `layout-§1`'s bands today, measured with
`find . -name '*.lua' -not -path './libs/*' -not -path './tests/_kit/*' | xargs wc -l`:

| File | LOC | Band |
|---|---|---|
| `tests/test_macrobar.lua` | 1894 | **over the 1500 cap** |
| `tests/test_settingsui.lua` | 1394 | 1000–1500 on notice |
| `settings/Category.lua` | 1127 | 1000–1500 on notice |
| `settings/Panel.lua` | 1014 | 1000–1500 on notice |

`media/` holds only `logos/` and `screenshots/` — the addon's own identity art. Nothing under
`media/` duplicates `libs/LibKa0s/media/` (`layout-§3`, `library-stack-§8`, anti-pattern #63).

## TOC (`toc-file`)

`ConsumableMaster.toc`: `Interface: 120007`, `Title: Ka0s Consumable Master`, `Version: 1.5.0`,
`SavedVariables: ConsumableMasterDB, ConsumableMasterPerfDB` (two, harness wired — `toc-file-§2`),
`X-License: MIT`, `X-Standard:` present, `X-Curse-Project-ID: 1522944` (published).
Field order matches `toc-file-§1`. Sections `# Libraries → # Locales → # Core → # Defaults →
# Modules → # Settings` (`toc-file-§5`). `libs\LibKa0s\LibKa0s.xml` listed once, after Ace3.

Position annotations are unusually thorough: `core\PerfSetup.lua`, `core\MediaSetup.lua`,
`core\CoreSetup.lua`, `core\Namespace.lua`, `defaults\Profile.lua`, `settings\OptionsSetup.lua` and
`settings\Panel.lua` each carry a comment naming **what resolves at load**; `core\EnvSetup.lua` and
`core\ItemSetup.lua` are explicitly marked *conventional*. `toc-file-§5`'s MUST and its SHOULD are
both met.

## Libraries (`library-stack`)

Vendored Ace3 stack + `LibSharedMedia-3.0` + `AceGUI-3.0-SharedMediaWidgets` + `libs/LibKa0s/`.
Root `CLAUDE.md:58` carries the provenance line `Bundles [LibKa0s](…) v1.25.0 (MIT).`;
`README.md` carries none. Both `diff -r` comparisons against the sibling `../LibKa0s` at tag
`v1.25.0` are **empty** (see `03_EVIDENCE.md`).

Eight LibKa0s seams, one file each, all resolving in silent mode with a degradation branch:
`core/CoreSetup.lua:33`, `core/DebugLogSetup.lua:59`, `core/PerfSetup.lua:38`,
`core/MediaSetup.lua:61`, `core/EnvSetup.lua:57`, `core/ItemSetup.lua:34`,
`settings/OptionsSetup.lua:69`, `settings/Slash.lua:257`. `tests/test_surface_parity.lua` pins the
degraded stub against the live seam.

`core/CoreSetup.lua:155-157` is the one `MakeCloseButton` wrapper and it forwards `addonName`;
`core/PerfSetup.lua:91` passes `addonName` in the Perf descriptor. No decoration hook duplicates the
library's close control.

## Architecture (`architecture`)

`local addonName, KCM = ...` bootstrap in `core/Namespace.lua`; AceAddon promotion in
`core/ConsumableMaster.lua`. Message bus at `core/Bus.lua` with four `Ka0s_ConsumableMaster_*`
messages documented in `docs/ARCHITECTURE.md` → `## Message Bus`. Schema-as-single-source across
`settings/*.lua`, one write seam (`Helpers.SetAndRefresh`).

## Settings panel (`options-ui`)

Four pages registered through `KCM.Settings.RegisterTab`: `general`, `macrobar`, `statpriority`,
`macros`. Every page draws a strip through `H.TabStrip` — including the one-tab General page
(`settings/General.lua:355-363`) and the one-tab Stat Priority page
(`settings/StatPriority.lua:653-663`). General's first and only tab is exactly `Master controls`
(`settings/General.lua:334`), composed by `H.MasterControls` (`settings/General.lua:206`), so the
canonical row set and its order are the library's. Every color swatch is composed with its
class-color companion via `H.ColorPair` and carries `classColor = { source = "player" }`; the two
border blocks and the label font block are `H.BorderGroup` / `H.FontGroup`. No `disabledIf` on a
color row, no `LSM30_*` hand-wiring in `settings/`, no chat-scroll arrow art, and ordered lists use
`LibKa0s-Widgets-1.0`'s `ReorderList` with the controller cancelled at the top of the render
(`settings/StatPriority.lua:623`, `settings/Category.lua:567-580`).

## Slash (`slash-commands`)

`settings/Slash.lua:84` declares `COMMANDS` with **17** positional triples; the dispatcher is built
from `LibStub("LibKa0s-Slash-1.0", true)` at `:257` and registered through AceConsole. Five verbs
carry their own sub-verb tables in `core/SlashCommands.lua` — `PRIORITY_COMMANDS:418`,
`STAT_COMMANDS:558`, `AIO_COMMANDS:729`, `BAR_COMMANDS:782`, plus the `/cm dump` targets in
`core/SlashDump.lua`.

## Debug / performance

`core/DebugLogSetup.lua` builds the console from `LibKa0s-DebugLog-1.0` with `addonName` in the
descriptor. `core/PerfSetup.lua` builds the harness; brackets follow `performance-§2`'s gated idiom
at `core/ConsumableMaster.lua:175/191` and `modules/MacroBar.lua:361/368`, both reading a file-scope
`Perf` upvalue. `tests/perf.lua` ships the offline scenarios including the zero-overhead pair. One
in-game capture bundle exists: `docs/perf-analysis/20260807-132029/` with `report.md`, `dump.json`
and `ANALYSIS.md`. No `docs/perf-runs/` survives; `performance-§12` does not apply (the harness is
wired).

## Tests / lint

`luacheck .` — **0 warnings / 0 errors in 59 files**. `lua tests/run.lua` — **749 passed, 0 failed,
0 skipped, 749 total**. Harness is the vendored `tests/_kit/`; `tests/_kit/run-automated-tests.sh`
is recorded `100755` in the index.

## `.gitattributes` (`line-endings`)

Present at the root and **byte-identical** to `line-endings-§5`'s canonical client-bound body (diff
in `03_EVIDENCE.md`). Pin `* text=auto eol=crlf` at `:26`, `*.sh text eol=lf` at `:34`, 20 `binary`
markings. Seven tracked files disagree with the declared pin in the working tree.

## `.pkgmeta` (`packaging`)

`package-as: ConsumableMaster`, no `externals:`, no `enable-toc-creation` fan-out. Every root
dot-entry except `.git` is accounted for. `_dev` is not listed (and does not exist in the repo).

## Root docs

`README.md` — H1, the five badges in canonical order with the **bare** `![Standard](…)` form
(`README.md:6`), logo, description, `## What's new in 1.5.0`, `## Screenshots`, `## Usage`
(`### Slash commands` + `### Settings panel`), `## How picking & ranking works`, `## FAQ`,
`## Troubleshooting`, `## Issues and feature requests`, `## Version History`. No `## Credits`, no
library inventory, no angle-bracket placeholders. `[tests]` badge reads `749/749`, which matches
today's run. `CLAUDE.md` — stub with the correct H1, adherence line, `## Standards compliance (read
first)`, docs pointer list, green gate, provenance line. `DEPENDENCIES.md` — four sections,
runtime / development / release split, `pipx` instructions, verification commands.

## `docs/`

Trio present (`ARCHITECTURE.md` 318 lines, `testing.md`, `smoke-tests.md`). Tier 1 all six present.
Tier 2: `midnight-quirks.md`, `debug.md`, `perf-analysis/README.md` present; `message-bus.md`,
`compat-layer.md`, `profiles.md` correctly recorded *Not applicable* with their triggers;
`slash-dispatch.md` recorded *Not applicable* on a trigger that **has** fired. The five
verification-and-record docs all present. `## Documentation map` and `## Documented deviations` both
present in `ARCHITECTURE.md`; the map covers every `.md` under `docs/` with the six frozen
directories named once each. No mandated hub section exceeds ~60 lines. No `file-index.md`,
`conventions.md`, `complexity.md`, `agent-context.md`, `TODO.md`, `CHANGELOG.md` or
`docs/pending/LEDGER.md`.

## Decision registers read before filing (AUDIT.md step 4)

- `docs/ARCHITECTURE.md` → `## Documented deviations`: four ratified rows —
  `localization-§4`, `toc-file-§5`, `compat`, `preview-mode`, all dated 2026-08-05 and all carrying
  a re-check trigger.
- GitHub issues: 31 issues read with
  `gh issue list --state all --limit 200 --json number,title,state,labels`. 11 open
  (`state:triaged`), 20 closed (`state:done` / `state:will-not-do`). No `[status]` title prefix
  survives; every issue carries a `state:` and a `severity:` label.
- Root `CLAUDE.md` and `docs/scope.md` read for accepted-deviation notes.
