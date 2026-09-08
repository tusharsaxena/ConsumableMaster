# 01 — Current state

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit:** 2026-09-08 · **Commit:** `5b01450`

**Audited against:** the Ka0s WoW Addon Standard **v2.39.0 (2026-09-07)** — resolved live from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, line 1 of
`standards/STANDARDS.md` read as `# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)` before any
measurement was taken. The playbook followed is that repo's `AUDIT.md` at the same ref. All **26**
section files linked from the index's `## Sections` list were fetched and read
(`anti-patterns`, `architecture`, `audit-review-history`, `automated-tests`, `compat`,
`debug-logging`, `documentation`, `events-frames-taint`, `layout`, `library-stack`, `line-endings`,
`lint`, `localization`, `naming-cheatsheet`, `open-evolutions`, `options-ui`, `packaging`,
`performance`, `preview-mode`, `public-api`, `savedvariables`, `slash-commands`,
`standalone-windows`, `testing`, `toc-file`, `versioning-git`), plus `standards/ADDONS.md`.

> `tiered-layout.md` appears in the index only inside the **v2.0.0 changelog entry**, which records
> its rename to `layout.md`. It is not a live section, it 404s at
> `standards/standards/tiered-layout.md`, and it is not part of this run's rule set.

**Rule set used:** the **addon** sections. This repo ships `ConsumableMaster.toc`, so `AUDIT.md`
step 1's switch to `library-stack-§7`'s applicability list does not apply.

**Previous run:** `docs/audits/2026-09-07/` (standard v2.38.0, 9 root / 11 total deviations). That
bundle is **frozen and untouched**. The remediation cycle it fed is
`Ka0sAddonsCommonTasks/docs/2026-09-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`, whose
`05_TRACEABILITY.md` maps this addon's 21 findings to work items `M1-LK-07` … `M5-05`.

---

## Layout (`layout`)

Modular, exactly as `layout-§1` states: `libs/ locales/ core/ defaults/ modules/ settings/`, with
`tests/`, `docs/` and `media/` beside them. The TOC's `#` section order is
Libraries → Locales → Core → Defaults → Modules → Settings (`ConsumableMaster.toc:19, 38, 41, 110,
133, 145`).

**The 1500-line cap.** Measured with the command the repo's own census publishes
(`docs/ARCHITECTURE.md:41`):

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

Two files are over the cap and both hold `layout-§1`'s **second** terminal state — an open issue
naming the seam a peel would follow: `tests/test_macrobar.lua` at **1904** (issue
[#32](https://github.com/tusharsaxena/ConsumableMaster/issues/32)) and `tests/test_settingsui.lua` at
**1669** (issue [#33](https://github.com/tusharsaxena/ConsumableMaster/issues/33)). Two files sit in
the 1000–1500 on-notice band: `settings/Panel.lua` (1165) and `settings/Category.lua` (1127). No
source file is in breach. `tests/test_layout_cap.lua` asserts the census's **membership** against the
tracked set on every suite run. The census's *figures* are stale for two of the four rows — see
`CM-82`.

`media/` holds only `logos/` and `screenshots/`. There is no `media/fonts/`, `media/icons/` or
`media/textures/`: the shared payload at `libs/LibKa0s/media/` is the only copy (`layout-§3`,
`library-stack-§8`).

## TOC (`toc-file`)

`ConsumableMaster.toc:1-17` carries the `toc-file-§1` field block in the exact mandated order,
with no blank line inside it. `## Interface: 120007`, `## X-License: MIT`,
`## X-Standard: https://github.com/tusharsaxena/WowAddonStandards`,
`## X-Curse-Project-ID: 1522944` — present, real, and the addon is published, so this is not
anti-pattern #67. `## SavedVariables: ConsumableMasterDB, ConsumableMasterPerfDB` with a four-line
comment above it (`:7-10`) saying why the perf ring is kept out of the AceDB tree.

The file listing is `#`-sectioned and heavily annotated. Load-bearing positions carry a comment at
the line naming what resolves: `core\PerfSetup.lua` (`:57`, comment `:50-56` — the `NS.Perf` load-time upvalue in
`core/ConsumableMaster.lua:16` and `modules/MacroBar.lua:35`), `core\MediaSetup.lua` (`:64`, comment `:58-63`,
marked `THE POSITION IS LOAD-BEARING` for `core/DebugLogSetup.lua`'s eager font-path resolve),
`core\CoreSetup.lua` (`:71`, comment `:68-70` — `KCM.PREFIX` before it and `core\SlashCommands.lua` after),
`core\DebugLogSetup.lua` (`:89`, comment `:81-88`), `defaults\Profile.lua` (`:116`, comment
`:111-115`), `settings\OptionsSetup.lua` (`:151`, comment `:146-150`) and `settings\Panel.lua`
(`:158`, comment `:152-157`). Two positions are annotated as **conventional**
(`core\EnvSetup.lua` at `:77`, comment `:73-76`; `core\ItemSetup.lua` at `:80`, comment `:78-79`).
The `# Modules` block (`:133-143`) and `# Locales` (`:38-39`) carry no conventional marker — the
`toc-file-§5` SHOULD, filed as `CM-83`.

Only `libs\LibKa0s\LibKa0s.xml` is listed for LibKa0s (`:36`), once, after Ace3 — never individual
module files.

## Libraries (`library-stack`)

Vendored, never `externals:`. Ace3 set reached: `AceAddon-3.0`, `AceConsole-3.0`, `AceDB-3.0`,
`AceEvent-3.0`, `AceGUI-3.0`, `AceGUI-3.0-SharedMediaWidgets`, plus `CallbackHandler-1.0`,
`LibSharedMedia-3.0`, `LibStub`. `AceTimer-3.0` is neither reached nor vendored, which under
v2.39.0's amended `library-stack-§1` (*mandatory **when used***, governed by §3's prune rule) is
compliant rather than a gap.

`libs/LibKa0s/` holds the **whole** ship folder: **14** `.lua` files publishing **10** majors —
`Core`, `DebugLog`, `Env`, `Item`, `Media`, `Options`, `Perf`, `Pool`, `Slash`, `Widgets` — plus
`LibKa0s.xml`, `LICENSE` and `media/`. `OptionsCompose.lua`, `OptionsScroll.lua`,
`OptionsWidgets.lua` and `PerfPanel.lua` are the four attach files. Provenance:
`CLAUDE.md:58` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).` Both
`diff -r` runs against the sibling repo at tag `v1.27.0` are **empty** (`03_EVIDENCE.md`).

The addon owns **descriptors and stubs**, not implementations: `core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `core/MediaSetup.lua`, `core/EnvSetup.lua`, `core/ItemSetup.lua`,
`core/PerfSetup.lua`, `settings/OptionsSetup.lua`, the slash descriptor at `settings/Slash.lua:257`,
and `tests/_kit/` for the harness. There is no `modules/DebugLog.lua`, no widget-maker file, no
private dispatcher and no local patch under `libs/` — anti-patterns #45, #47, #48 all clear.

`core/LSMPatch.lua` is **gone**. The AceGUI `LSM30_Border` re-registration now runs through the
library's `lib.__PatchLSM30Border` from `settings/OptionsSetup.lua:102-140`, which is
`library-stack-§9` / anti-pattern #76's required shape. A whole-repo grep for
`RegisterWidgetType` outside `libs/` returns nothing.

## Media (`library-stack-§8`)

`core/MediaSetup.lua:58` takes `local addonName, NS = ...` — the addon's own first vararg — and
passes it to `Media.Icon` (`:79`), `Media.Font` (`:89`) and the single `Media.RegisterLSM(addonName)`
call (`:104`). No hand-typed constant, no frame-name prefix. The file sits second in `# Core`, before
every consumer.

The console is told who it is: `core/DebugLogSetup.lua:136` carries `addonName = addonName` beside
`name` (`:127`). `core/PerfSetup.lua:82-92` documents the same field for the perf panel and does
**not** carry a `decorate` hook drawing a close button.

The one close-button wrapper is `core/CoreSetup.lua:185-187`. The mandated grep returns the wrapper
definition, its own explanatory comment, a cross-reference comment in `core/PerfSetup.lua:82`, and
one call from `tests/test_coresetup.lua:176`. The addon builds **no** window of its own — the console
and the perf panel are the library's — so there is nothing for a host factory to draw and no
`standalone-windows` decline to check against the four conditions.

The Blizzard `Interface\RaidFrame\ReadyCheck-*` and `Interface\COMMON\FavoritesIcon` glyphs at
`modules/KCMItemRow.lua:35-37`, `settings/Category.lua:82-84` and `settings/StatPriority.lua:108-109`
are **options-surface** marks, which `library-stack-§8` places explicitly out of scope
(*"The options surface is deliberately out of scope for now"*). Not a finding.

## Architecture (`architecture`)

`core/Namespace.lua` bootstraps `local addonName, NS = ...`; `core/ConsumableMaster.lua` promotes
`NS` to the AceAddon object. Ten feature modules and event registration put the addon **above**
`architecture-§4`'s threshold, and the closed bus exists at `core/Bus.lua:26-48` with per-receiver
targets (`KCM.NewBusTarget`). Four messages are declared (`core/Bus.lua:37-41`).
`settings/Panel.lua` is the single schema source (`architecture-§5`).

## SavedVariables (`savedvariables`)

`defaults/Profile.lua` is the sole declaration site of the AceDB defaults tree
(`defaults/Profile.lua:31` carries `schemaVersion = 1`). The migration runner is
`core/Database.lua:119-151`, account-wide and per-profile, with the account marker at `g.schemaVersion`
and each profile gated on `p.schemaVersion`. `ConsumableMasterPerfDB` is declared **outside** the
AceDB tree, per `savedvariables-§4`.

`savedvariables-§5` / anti-pattern #54: a sweep for `t.k = stored.k or D.k` over the settings tables
returns **nothing**; the addon defaults with `== nil` (`core/CoreSetup.lua:57-60`,
`core/State.lua:14`).

## Options UI (`options-ui`)

Built by `LibKa0s-Options-1.0` from a descriptor. `settings/OptionsSetup.lua:96` is the only
construction site; `settings/Panel.lua:83` takes `KCM.Settings.Helpers` as the addon's half.
All nine of `AUDIT.md` step 4's content checks were run against the schema:

| Check | Result |
|---|---|
| (a) every page draws a strip | Pass. Four pages, every one with a strip: General (1 tab, `settings/General.lua:333-335`), Macro Bar (8, `settings/MacroBar.lua:700-709`), Stat Priority (1), Macros (15). No untabbed fallback and no tab-count threshold in any renderer. |
| (b) `Master controls` first on General, canonical rows | Pass, and **composed** — `settings/General.lua:206` calls `H.MasterControls{…}` rather than typing the block. All eight canonical rows are present because the addon has the state for all eight (`modules/MacroBar.lua:129` proves the movable frame). `visibility` is the four-value dropdown, and the addon never shipped a *show only in combat* boolean at that path, so no migration is owed. |
| (c) class-color companion beside every color | Pass. Every swatch is emitted by `H.ColorPair` (`settings/MacroBar.lua:213, 271, 517, …`), which emits the companion as the next row. |
| (d) no `disabledIf` on a color row | Pass. `grep -rn 'disabledIf' settings/` → no hits. |
| (e) ordering is a drag | Pass. `grep -rn 'ScrollUp-Up\|ScrollDown-Up' settings/` → no hits. The lists use the shared `W.ReorderList` (`settings/Category.lua:726, 926`, `settings/StatPriority.lua:546`). `Selector.MoveUp`/`MoveDown` exist only as `/cm priority up|down` verbs. |
| (f) no hand-written font/border/bar group | Pass. `grep -rn 'LSM30_Font\|LSM30_Border\|LSM30_Statusbar' settings/` returns two **comment** lines in `settings/OptionsSetup.lua:103, 106` and no control. Groups come from `H.BorderGroup` / `H.FontGroup` / `H.ColorPair`. `subgroup` headings are declared on every mixed tab. |
| (g) one chrome block, not boxed twice | Pass. The banner and strip are drawn into the chrome band by the library (`H.PageBanner`, `H.TabStrip`); no page-wide control is declared inside a `group`, and no `InlineGroup` wraps the band. |
| (h) wrapped-strip geometry is selection-independent | Pass. The vendored library measures the pitch once from the **inactive** cap atlas on a throwaway texture (`libs/LibKa0s/OptionsWidgets.lua:403-455`), separate from `TAB_H` (`libs/LibKa0s/Options.lua:120`). The suite case is `tests/test_settingsui.lua:1303`. |
| (i) secondary strip in the scroll, no third level | Not applicable — no page carries a secondary strip. |

The **hollow composer** shape v2.39.0 settled is implemented exactly:
`settings/OptionsSetup.lua:250-253` answers `MasterControls`/`ColorPair`/`FontGroup`/`BorderGroup`
with empty row lists on a library-less load. There is no addon-wide **broadcast meta row**, so §16's
one exemption is not in play.

## Slash (`slash-commands`)

`settings/Slash.lua` owns dispatch; `core/SlashCommands.lua` and `core/SlashDump.lua` own the verb
bodies. `settings/Slash.lua:257` resolves `LibKa0s-Slash-1.0`. Seventeen top-level verbs with four
sub-verb namespaces plus the `dump` targets. Chat tag is the cyan `[CM]` from `KCM.Say`
(`core/CoreSetup.lua`, `core/Constants.lua`).

## Debug (`debug-logging`)

`core/DebugLogSetup.lua` builds the console from `LibKa0s-DebugLog-1.0` with `name`, `addonName`,
`font` (from the media seam, `:145`) and `fontSize`. `core/Debug.lua` is the addon's sink.
`docs/debug.md` documents the `/cm dump` surfaces beyond the library console.

## Performance (`performance`)

`core/PerfSetup.lua` builds the harness from `LibKa0s-Perf-1.0` with `sv = "ConsumableMasterPerfDB"`,
a `/cm perf` verb, and an explicit `suspend`/`resume` pair (`:61-69`). `tests/perf.lua` ships the
offline scenarios. `performance-§12`'s exemption does **not** apply and is not claimed. One frozen
capture bundle exists at `docs/perf-analysis/20260807-132029/` with all three artifacts, indexed at
`docs/perf-analysis/README.md:133-143`. There is no `docs/perf-runs/` directory and no flat JSON.

## Packaging (`packaging`)

`.pkgmeta` has no `externals:`. Both mechanical checks pass: the named enumeration
(`.luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev`) is complete,
including `.pkgmeta`'s v2.39.0 self-reference at `:13` and `_dev` at `:11`; and the strong form —
every root dot-entry the repo holds — leaves only `.git`, which the packager never sees.

## Line endings (`line-endings`)

`.gitattributes` present, 81 lines, and **byte-identical** to `line-endings-§5`'s canonical
client-bound body: `diff <(head -n 81 .gitattributes) <canonical>` is empty and there is no tail, so
no `line-endings-§5 appendix` is in play. Pin at `:26` is `* text=auto eol=crlf` (correct kind — the
repo ships Lua to the client). `*.sh text eol=lf` at `:34`. Twenty `binary` marks. The working-tree
agreement check returns **0**. The `line-endings-§7` gate is present and owned:
`tests/_kit/test_eol.lua` (kit revision 15, whole tracked set) reports
`PASS  eol: every tracked file carries the terminator .gitattributes declares for it`.

## Lint (`lint`)

`.luacheckrc` is already on the v2.39.0 shape. `exclude_files` at `:14-19` is
`{ "libs/", "docs/audits/", "docs/reviews/", "tests/_kit/" }` — **only** `tests/_kit/` under `tests/`,
never bare `tests/`. The harness globals sit in a `files["tests/"]` stanza at `:118-120`, not in
top-level `read_globals`, with the reasoning written at `:111-117`. There is **no** top-level
`ignore` (`:21-31` records its removal and `tests/test_lintconfig.lua` keeps it out); the narrow
per-file `212/<name>` stanzas at `:137-185` each name one file and one argument with a comment.
`luacheck .` reports **0 warnings / 0 errors in 102 files**.

## Testing (`testing`)

Headless Lua 5.1 harness on the vendored `tests/_kit/`, which is under `tests/` and never ships.
`lua tests/run.lua` → **786 passed, 0 failed, 0 skipped, 786 total**. Both vendored-payload gates run
green (`tests/test_vendor_sync.lua`, and the kit-side pair). `tests/test_surface_parity.lua` pins the
degradation-stub member set against the call sites. `docs/test-cases.md` holds 786 case lines and the
README badge reads `Tests-786%2F786_passing`.

## Automated tests (`automated-tests`)

Runner vendored and executable (`tests/_kit/run-automated-tests.sh`, mode `100755`).
`docs/automated-tests/README.md` and `RESULTS.md` both present. A fresh bundle for the post-cycle
tree exists — `docs/automated-tests/20260908-181304/` — and `RESULTS.md` is regenerated from it. The
lead-in now names **three** checkpoints including the tag gate (`RESULTS.md:14-16`), the `Tests` cell
reads `passed/skipped/total` (`:22`, row at `:26` reads `786/0/786`), and the watch list carries the
`Disposition` column as the one authored cell. There is no retired `docs/complexity.md`. Two older
bundles still carry no `ANALYSIS.md` — `CM-77`.

Today's `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` reproduces the newest bundle exactly:
18825 NLOC, 1957 functions, avg NLOC 8.1, avg CCN 2.7, **0** warnings. The record is not stale.

## Documentation (`documentation`)

Root: `README.md` (player-facing, canonical section order, five badges with the standard badge
**bare** at `:6`, no bundled-library inventory, no `## Testing`), `CLAUDE.md` (with
`## Standards compliance (read first)` at `:5` and the provenance line at `:58`), `DEPENDENCIES.md`,
`LICENSE`. No `CHANGELOG.md` at the root.

`docs/` trio present. **Tier 1** — all six under the canonical names. **Tier 2** — `slash-dispatch.md`,
`midnight-quirks.md`, `compat-layer.md`, `debug.md` and `perf-analysis/README.md` present;
`message-bus.md` and `profiles.md` carry *Not applicable* rows whose triggers are measured and
**false** (four messages against the >10 threshold; no profile control in the options UI).
**Tier 3** — `macro-bar.md`, `macro-manager.md`.

`## Documentation map` at `docs/ARCHITECTURE.md:310` carries **four** tables in v2.39.0's order:
`### Required` (`:315`), `### Conditional` (`:327`), `### Verification and record` (`:339`, the six
mandated rows) and `### Addon-specific` (`:350`). Every `.md` under `docs/` is covered exactly once,
with the frozen and generated directories named once each at `:313`. No dangling rows. The hub's own
self-row is present and, per v2.39.0, is a **MAY** this audit neither files for nor against. No
non-canonical Tier 1/2 filename survives; no `file-index.md`, `conventions.md`, `complexity.md` or
`docs/perf-runs/`. `ARCHITECTURE.md` is 371 lines, under the ~400 shape guide, and every mandated
section has spilled.

## Deviation register and issue store (`audit-review-history`)

`## Documented deviations` at `docs/ARCHITECTURE.md:357` carries **three** ratified rows —
`localization-§4`, `compat`, `preview-mode` — each with a Why, a Decided date (all 2026-08-05) and a
**Re-check trigger**. All three MUSTs of the amended section were run: the rows were read before
anything was filed; no row cites a rule the standard has since changed; and every trigger was
evaluated against the tree while every evidence id was resolved (`03_EVIDENCE.md`). None has fired.

The `toc-file-§5` row the 2026-09-07 run filed as `CM-71` has been **retired**, with the retirement
recorded in prose beneath the table (`docs/ARCHITECTURE.md:371`).

The issue store is GitHub issues on this repo — **33** issues, every one carrying a `state:` and a
`severity:` label, no `[status]` title prefix (anti-pattern #62 clear), no `docs/pending/` and no
`LEDGER.md` (#60 clear). Twelve closed `state:will-not-do` issues were read; none declines a
**standard rule**, so no missing register row is owed. Issues #32 and #33 are the two `layout-§1`
owners.

## Git and versioning (`versioning-git`)

`master` is the trunk and carries the whole 2026-09-07 remediation cycle, merged at `5b01450`. The
working tree is clean. `## Version: 1.5.0` in the TOC matches the top `## Version History` row and
`## What's new in 1.5.0`.
