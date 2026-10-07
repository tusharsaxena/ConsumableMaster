# 01 — Current state: Ka0s Consumable Master (2026-10-07)

**Audited against:** the Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. The run fetched
`AUDIT.md`, `standards/STANDARDS.md`, `standards/ADDONS.md` and all 28 section files linked under
`STANDARDS.md` → *Sections* from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`
with `curl -fsSL`. The fetched copies were compared byte for byte with the sibling working tree
`../WowAddonStandards` (HEAD `f472389`), and none of them differed. The only `standards/<file>.md`
name in `STANDARDS.md` that returned 404 was `tiered-layout.md`, and it appears only inside a frozen
changelog entry (v2.0.0 renamed it to `layout.md`). It is not in the Sections list.

**Repo kind:** **Addon**. `dev-copilot-profile` reported `profile=wow kind=addon` (`reason=toc:## Interface`),
and `standards/ADDONS.md:22` lists *Ka0s Consumable Master* in the addon table with the launcher
menu entries `Enabled · Locked (the macro bar)`. The full addon rule set applies, along with the
whole `AUDIT.md` playbook.

**Tree measured:** branch `feat/2026-10-07-review-audit-remediation` at `862151a` (Merge branch
`feat/2026-10-06-revendor-libka0s-v1.69.0`) with a clean working tree. That is 132 commits after the
previous audit's record commit, `38f3901`.

**Previous run:** `docs/audits/2026-09-23/`, against standard v2.64.0. It had 13 roots and 15 total.
This run reuses that bundle's `CM-` prefix and keeps its IDs for the findings that recur.

---

## Layout (`layout`)

The addon uses the single modular layout: `core/ defaults/ settings/ locales/ modules/`, plus
`libs/`, `media/` and `tests/`. The default census scope has **130** authored Lua files
(`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`). The largest is `settings/Panel.lua`,
at 1196 lines. **Nothing is over the 1500-line cap.** Seven files sit in the 1000–1500 on-notice
band: `settings/Panel.lua` 1196, `settings/MacroBar.lua` 1182, `settings/Category.lua` 1150,
`tests/test_schema.lua` 1023, `tests/wow_mock.lua` 1012, `tests/test_selector.lua` 1009 and
`tests/test_settingsui.lua` 1002. The hub's census (`docs/ARCHITECTURE.md:383-432`) carries the
heading, the load-bearing *"No authored file in this repository is over the cap."* sentence, and a
band list (`:416-420`) that matches the measured numbers line for line. The kit's
`test_layout_cap` is declared by path at `tests/run.lua:549`. No authored generator exists:
`git ls-files '*.py' '*.sh'` outside `libs/` and `tests/_kit/` returns nothing.

## TOC (`toc-file`)

- `ConsumableMaster.toc:1` `## Interface: 120100`, and `:5` `## Version: 1.7.0`.
- `:6` `## IconTexture` names `Interface\AddOns\ConsumableMaster\media\logos\consumablemaster.logo.128.tga`.
  The TGA header reads type **2** (uncompressed), **128×128**, **32** bpp.
- `:16` `## X-Standard`, and `:17` `## X-Curse-Project-ID: 1522944`. `X-Wago-ID` is absent, which is
  a MAY. Closed issue #17 records that decision, and it owes no register row.
- `# Libraries` (`:19-55`) runs LibStub, then the Ace3 subset, then LibDataBroker before LibDBIcon,
  then `libs\LibKa0s\LibKa0s.xml`, once and last. Each load-bearing position in that block is annotated.
- In `# Core` (`:61-148`), the load-bearing lines that are annotated are LifecycleSetup, PerfSetup,
  MediaSetup and CoreSetup. **One load-bearing position is not annotated with what resolves:**
  `core\SlashDump.lua` (`:143`), which takes `local say = KCM.Say` at file scope (`CM-98`).
- `# Locales` (`:58`), `# Modules` (`:174`) and the four page files in `# Settings` (`:214`) carry a
  *conventional* note. `# Defaults` (`:150-171`) annotates `Profile.lua` only, and its other fifteen
  lines are unmarked (`CM-83`).

## Libraries and the vendored payload (`library-stack`)

- Provenance: `CLAUDE.md:61` reads `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`
  The line appears there once and nowhere in `README.md`.
- At the `v1.70.0` tag of `../LibKa0s`, `diff -r` of `LibKa0s/` against `libs/LibKa0s/` is
  **empty**, and so is `diff -r` of `testkit/` against `tests/_kit/`. The payload has 34 `.lua` files
  and **15 majors**, the kit is at revision **37** (`tests/_kit/framework.lua:20`), and the TOC lists
  the aggregate XML once.
- The addon consumes **fourteen** majors: Bus, Compat, Core, DebugLog, Env, Item, Launcher,
  Lifecycle, Media, Options, Perf, Schema, Slash and Widgets. Each has its own `LibStub(..., true)`
  lookup in a setup file. **Pool** ships unused (closed issue #31). The count of 15 in
  `ConsumableMaster.toc:50` and the count of 14 in `CLAUDE.md:77` and `docs/ARCHITECTURE.md:267`
  agree with the tree.
- Re-vendor store: `docs/revendor/` holds 21 bundles. Two tags vendored since the last bundle have no
  bundle: v1.69.0 and v1.70.0 (`CM-91`).

## Shared subsystems: descriptors and stubs (`library-stack-§7`, `options-ui-§1`)

| Major | Setup file | Library-absent arm |
|---|---|---|
| Core | `core/CoreSetup.lua:64` | `IsConcatSafe`, `SafeToString`, `SwatchColor`, `Say`, `SafeRegisterEvent` (`:66-131`). `KCM.MakeCloseButton` has no twin, but no shipped file calls it (the decision recorded at review `CM-R-10`, 2026-09-07). |
| DebugLog | `core/DebugLogSetup.lua` | stub `DL.*`, including `RunDiagnostics` (`:114`) |
| Slash | `settings/Slash.lua:456` | the degraded arm (`slash-dispatch.md`) |
| Options | `settings/OptionsSetup.lua:164` | load-completing, which is the documented exception |
| Schema | `settings/SchemaStub.lua` | runtime-completing |
| Lifecycle | `core/LifecycleSetup.lua:49` | none; the file returns early at `:56`, with the reason given at `:51-55`. The register's `options-ui-§1` row covers this. |
| Launcher, Perf | `core/LauncherSetup.lua:98`, `core/PerfSetup.lua` | none (an absent feature) |
| Compat, Bus | `core/Compat.lua`, `core/Bus.lua` | the reader arm and the untracked-target stub |

`tests/test_surface_parity.lua` is in the green suite. No hand-rolled console, widget maker,
dispatcher or test framework exists (anti-pattern #47).

## Settings (`options-ui`, `savedvariables`, `architecture-§5`)

The General page's first tab is the composed `Master controls` (`settings/General.lua:182`,
`H.MasterControls{…}`). The minimap row's path is `global.minimap.shown` (`settings/General.lua:61`),
and its store, `db.global.minimap.hide`, is LibDBIcon's. The bar is the one positionable display
(`modules/MacroBar.lua:224`, `SetMovable(true)`). Unlocking it shows its live slots, so there is no
Test mode row, which is the `options-ui-§15` exemption. The four page tab strips are the library's
`H.TabStrip` (`settings/Category.lua:1090`, `settings/MacroBar.lua:1152`,
`settings/StatPriority.lua:721`) and `H.RenderTabbedSchema` (`settings/General.lua:421`). The
Options descriptor passes `addonName` (`settings/OptionsSetup.lua:224`). `SCHEMA_VERSION` is
`D.CURRENT_SCHEMA = 3` (`core/Database.lua:34`). Every write outside the seam is named in the hub
(`docs/ARCHITECTURE.md:94-136`). No `SettingsPanel` / `HideUIPanel` / `OpenToCategory` call exists in
the addon's own Lua. The open and the combat-parked registration are the library's
(`settings/OptionsShim.lua:198` `UI.OpenOptionsPanel()`, `settings/Panel.lua:1178`
`UI.CreateOptionsPanel()`).

## Slash (`slash-commands`)

The dispatcher has 23 verbs (`settings/Slash.lua:164-308`). `KCM.COMMANDS` is published at `:396`.
`liveVerbs` (`:356-360`) lists all 13 reserved verbs plus `dump` and `profile`, and the library
widens its own set with them. Eight feature verbs refuse while the addon is disabled. `diagnostics`
has exactly one `COMMANDS` row (`:224`), and the `debug` handler tests `diagnostics` first (`:198`).

## The disabled state (`slash-commands-§7`)

There is one latch with two holds, built on `LibKa0s-Lifecycle-1.0` (`core/LifecycleSetup.lua:141`).
`standDown` (`:83-115`) takes these actions:

- it runs `KCM.Bus.StandDown()`, which unregisters all seven bus receivers;
- it disarms the recompute flag;
- it runs `MacroBar.Update()`, which unregisters the bar's state driver, clears its `OnUpdate`
  (`modules/MacroBar.lua:556-563`) and calls `MacroBarFlyout.StandDown()` (`:559`), which unregisters
  every flyout's `kcmCombat` driver (`modules/MacroBarFlyout.lua:340-345`);
- it runs `KCM:UnregisterAllEvents()`;
- it keeps `PLAYER_REGEN_ENABLED` only when combat holds the teardown.

That registration is dropped at `core/ConsumableMaster.lua:791`. `KCM:OnEnable` refuses while
stood down (`:910`). The settings registration parked in combat is replayed by the library, whatever
the stand-down state. `tests/test_disabled.lua` asserts on the recording mock's
`attributeDrivers` (`:215`) and `stateDrivers` (`:244`), and it dispatches both diagnostics forms
while disabled (`:420-440`). **The rotation's expected failure does not fire here: the addon
genuinely stands down.**

## Launcher (`launcher`)

There is one object (`core/LauncherSetup.lua`), with the label `"Ka0s Consumable Master"` (`:141`).
The descriptor provides `isEnabled`/`setEnabled` (`:166-172`), `isLocked`/`toggleLock` (`:193`), and
no `isTestMode` or `isWindowShown`, which matches `ADDONS.md`. It passes `debug` (`:215`) and
`debugAtEnable` (`:225`). No host `OnTooltipShow`, `MenuUtil` or `EasyMenu` call exists. The
`minimap` table lives in `db.global`, so neither reset reaches it.

## Debug and diagnostics (`debug-logging`)

The four descriptors that take `debug` are given it: Slash `:596`, Options `:241`, Launcher `:215`
and Lifecycle `:152`. The diagnostics report has two forms and no alias, it is live while disabled,
and it is built on `RunDiagnostics`. The host keeps one change gate of its own, `KCM.DebugQuiet`
(`core/ConsumableMaster.lua:132`), with the reason written at `:117-131` and re-armed by the console's
`onClear` (`core/DebugLogSetup.lua:258-259`). `CM-101` notes it.

## Events (`events-frames-taint-§1`)

`KCM.EVENTS` is registered through `KCM.SafeRegisterEvent` (`core/ConsumableMaster.lua:912`), which
is the library's helper with the `C_EventUtils.IsEventValid` front gate (`core/CoreSetup.lua:140`).
Rejected names are visible through `/cm dump events`.

## Bus (`architecture-§4`)

There are five messages, declared once in a strict `Catalog` (`core/Bus.lua:128-132`), all of the
form `Ka0s_ConsumableMaster_<PascalCase>`. No literal is typed at a call site. The test probe is a
file-local constant (`tests/test_harness.lua:69`).

## Tests, lint and complexity (`testing`, `lint`, `automated-tests`)

All three were run through `ka0s-bounded`:

- `lua5.1 tests/run.lua`: **1201 passed, 0 failed, 1 skipped, 1202 total**. The skip is the
  diagnostics opt-out case, which does not apply to this addon.
- `luacheck .`: **0 warnings / 0 errors in 130 files**. `exclude_files` reaches only `tests/_kit/`
  inside `tests/`, and there is no top-level `ignore`.
- Complexity, measured sighted with `--suite complexity --no-bundle`: **pass**, 0 warnings, 3200
  functions, max CCN **15**, 27244 NLOC.

The newest recorded run is `20260927-030419` at `86660df`, **59 commits behind HEAD**. It was
recorded before kit revision 35, so it is unsighted, and its manifest has no `blindFiles` (`CM-95`).
The watch list has three *Accepted* entries, each carried for one release.

## Packaging and line endings (`packaging`, `line-endings`)

`.pkgmeta` checks (a), (b) and (c) are clean; the only unaccounted entry is `.git`, which is exempt.
`.gitattributes` pins `* text=auto eol=crlf` (`:26`) and carries `*.sh`/`*.py text eol=lf`
(`:36-37`). Its 84-line body is byte-identical to the client-bound canonical body in
`line-endings-§5`, with no tail. Working-tree disagreement, check (e): **0**.

## Root docs (`documentation-§1/§2/§7`)

- `README.md:6` carries the bare `![Standard](…)` badge.
- The README has no logo image, no library inventory and no numbered list outside a fence.
- `## Reporting a bug` (`:130`) sits between Troubleshooting and Issues.
- The `[Tests]` badge, 1201/1202, matches `docs/test-cases.md`.
- `CLAUDE.md` is the stub plus the provenance line.

## `docs/` (`documentation-§3`)

- Tier 1 is all present.
- The Tier 2 triggers were measured as follows:
  - **slash-dispatch:** 23 verbs, so the doc is present.
  - **message-bus:** 5 messages, so the row reads *Not applicable*, and that is correct.
  - **compat-layer:** the documentation-§3 grep counts 3 shims, so the doc is present.
  - **midnight-quirks, profiles, debug and perf-analysis:** present.
- The map's four tables register all 21 authored `.md` files exactly once, and no row dangles. No
  non-canonical or retired doc remains. `docs/pending/` is absent.
- The hub is **432 lines**, and every mandated section is at or under ~60 lines. Settings Schema runs
  `:78-137`, and its registry naming is mandated to live there.

## The register (`audit-review-history`)

`docs/ARCHITECTURE.md:365-381` has three rows (`localization-§4`, `compat`, `options-ui-§1`) and two
retirement notes. None of the three triggers has fired. **Two rows cite evidence ids that do not
resolve in this repo** (`CM-99`). The `gh` CLI issue store has 44 issues (`gh issue list --state all`).
None has a `[status]` prefix. Of the will-not-do issues, none declines a standard MUST or SHOULD that
would owe a row: #41 (`RenderTabbedSchema`) concerns library adoption, and every page still draws the
library's strip.
