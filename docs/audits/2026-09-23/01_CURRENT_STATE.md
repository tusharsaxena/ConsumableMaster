# 01 — Current state

**Addon:** Ka0s Consumable Master · **Prefix:** `CM-` · **Audit:** 2026-09-23 · **Commit:** `7adfea1`
(branch `feat/2026-09-23-review-audit-remediation`, working tree clean at the start of the run)

**Audited against:** the Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. It was resolved live from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with `curl -fsSL`, and line 1
of `standards/STANDARDS.md` was read as `# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)` before any
measurement. The playbook is `AUDIT.md` at the same ref. All **27** section files linked from the
index's `## Sections` list were fetched: `anti-patterns`, `architecture`, `audit-review-history`,
`automated-tests`, `compat`, `debug-logging`, `documentation`, `events-frames-taint`, `launcher`,
`layout`, `library-stack`, `line-endings`, `lint`, `localization`, `naming-cheatsheet`,
`open-evolutions`, `options-ui`, `packaging`, `performance`, `preview-mode`, `public-api`,
`savedvariables`, `slash-commands`, `standalone-windows`, `testing`, `toc-file`, `versioning-git`. Also
fetched: `standards/ADDONS.md`. The collection's roster row for this addon reads
**(b) lock / unlock — the macro bar's lock** in the *Launcher left-click* column (`ADDONS.md:22`).

**Repo kind:** **Addon**. The repo ships `ConsumableMaster.toc`, so the addon rule set applies:
every section, plus the `anti-patterns` list. The library-stack-§7 and documentation-§8 lists do not
apply.

**Previous run:** `docs/audits/2026-09-08/` (standard v2.39.0, 6 root / 7 total). That bundle is
frozen and was not touched. Prefix and IDs are reused. New IDs start at **CM-84** (`CM-83` is the
highest ID used in any bundle under `docs/audits/`, `docs/reviews/` or `docs/revendor/`).

**Tooling note.** `ka0s-bounded` is not on `PATH` in this shell. It is installed at
`~/.claude/wow-addon/bin/ka0s-bounded`, and every `luacheck`, `lua tests/run.lua` and `lizard` run in
this bundle went through that full path. None exited 124 or 137.

---

## Layout (`layout`)

The folders are `libs/ locales/ core/ defaults/ modules/ settings/`, with `tests/`, `docs/` and `media/`
beside them. TOC section headers run Libraries → Locales → Core → Defaults → Modules → Settings
(`ConsumableMaster.toc:19, 57, 60, 143, 166, 178`).

**The 1500-line cap.** The default census, `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`,
covers **116** authored files and **38,525** lines. **None is over the cap.** The largest is
`tests/test_macrobar.lua` at 1425. Eight files sit in the 1000–1500 band: `tests/test_macrobar.lua`
1425, `tests/test_slash.lua` 1322, `settings/Panel.lua` 1312, `tests/test_settingsui.lua` 1259,
`settings/MacroBar.lua` 1166, `settings/Category.lua` 1141, `tests/test_schema.lua` 1023 and
`tests/test_selector.lua` 1011. The census heading `### Files over the 1500-line cap` sits at
`docs/ARCHITECTURE.md:420`, nested under `## Documented deviations` as documentation-§3 requires. It
reads *"No authored file in this repository is over the cap."* at `:447`, and its band list at `:476-481`
matches the tree to the line. The kit's gate is wired by path
(`tests/run.lua:508`, `{ name = "test_layout_cap", dir = "tests/_kit/" }`) and passes all five
`layoutcap:` cases. The repo declares no generated-data exemption, and none is needed.

**Generators (`layout-§1`, v2.61.0).** `git ls-files '*.py' '*.sh'` returns only
`tests/_kit/run-automated-tests.sh`, which is vendored. The candidate set is empty.

`media/` holds only `logos/` and `screenshots/`. There is no private `fonts/`, `icons/` or `textures/`
(`layout-§3`, `library-stack-§8`).

## TOC (`toc-file`)

The metadata block at `ConsumableMaster.toc:1-17` follows toc-file-§1's field order with no blank line
inside it: `## Interface: 120100`, `## Title: Ka0s Consumable Master`, Notes, Author,
`## Version: 1.6.2`, `## IconTexture: Interface\AddOns\ConsumableMaster\media\logos\consumablemaster.logo.128.tga`,
`## SavedVariables: ConsumableMasterDB, ConsumableMasterPerfDB` (with a comment at `:7-10`),
OptionalDeps (which adds LibDataBroker-1.1 and LibDBIcon-1.0 for the launcher), DefaultState,
Category-enUS, `## X-License: MIT`, `## X-Standard:` and `## X-Curse-Project-ID: 1522944` (the addon is
published). The logo named by `## IconTexture` exists. Its TGA header reads image type **2**,
**128 × 128**, **32**-bit, so it is not anti-pattern #82 and not the RLE variant.

**Position annotations (`toc-file-§5`).** I read the seam files (`*Setup.lua`, `core/Constants.lua`)
to find the load-bearing positions. Each one carries a comment naming what resolves at load:
`core\LifecycleSetup.lua` (`:75`, comment `:69-74`),
`core\PerfSetup.lua` (`:83`, comment `:76-82`), `core\MediaSetup.lua` (`:90`, comment `:84-89`),
`core\CoreSetup.lua` (`:97`, comment `:94-96`), `core\DebugLogSetup.lua` (`:122`, comment `:115-121`),
`defaults\Profile.lua` (comment `:144-148`), `settings\OptionsSetup.lua`, `settings\Panel.lua`,
`settings\OptionsShim.lua` and `settings\CategoryAddByID.lua` (lines `:184, 191, 201, 213`, comments in `:179-212`). The MUST holds.
Most **conventional** groups carry no conventional marker: `# Locales` (`:57-58`), `# Modules`
(`:166-176`) and the page files in `# Settings` (`:202-205`). That fails the SHOULD and carries forward
as `CM-83`. The PerfSetup comment at `:77` still says *"It sits here, second"*, but the file has been
**third** since `core\LifecycleSetup.lua` took the second line (`CM-94`).

Libraries are listed directly with no `embeds.xml`. LibKa0s appears once, as `libs\LibKa0s\LibKa0s.xml`
(`:55`), last in `# Libraries`. The file ends with one CRLF.

## Libraries (`library-stack`)

Everything is vendored and nothing is fetched through `externals:`. The Ace3 set is AceAddon, AceEvent,
AceDB, AceDBOptions, AceConsole, AceGUI, AceConfig and AceGUI-3.0-SharedMediaWidgets, with LibStub,
CallbackHandler-1.0 and LibSharedMedia-3.0. LibDataBroker-1.1 and LibDBIcon-1.0 are vendored for the
launcher. AceTimer is neither reached nor vendored, which is compliant under the *mandatory when used*
reading.

`libs/LibKa0s/` is the **whole** ship folder at **v1.55.0**: 21 `.lua` files publishing **15** majors
(Bus, Compat, Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Slash
and Widgets), plus `LibKa0s.xml`, `LICENSE` and `media/`. The provenance line is
`CLAUDE.md:61` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).` — and it
is absent from `README.md`. Both `diff -r` runs, taken against the sibling `../LibKa0s` **at tag
`v1.55.0`** (not at its `HEAD`, which is ahead of the tag), are **empty**. v1.55.0 is above the
v1.42.0 adoption floor that `slash-commands-§7` sets.

**Consumed majors: thirteen.** Core, DebugLog, Slash, Options, Perf, Media, Env, Item, Widgets,
Launcher, Lifecycle, Compat and Bus. Pool and Schema ship in the payload unused. Schema is deferred on
open issue #39 (`state:triaged`), and v2.64.0 requires neither. The addon owns descriptors and stubs,
not implementations: `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `core/MediaSetup.lua`,
`core/EnvSetup.lua`, `core/ItemSetup.lua`, `core/LauncherSetup.lua`, `core/LifecycleSetup.lua`,
`core/PerfSetup.lua`, `core/Compat.lua` (reader and guard arms), `core/Bus.lua` (untracked-target
stub), `settings/OptionsSetup.lua`, the slash descriptor in `settings/Slash.lua` (`:415`), and
`tests/_kit/`. `tests/test_surface_parity.lua` pins each stub's member set against the live seam,
covering Core, DebugLog, Slash, Options, Compat and Bus. No hand-built console, dispatcher, widget
maker or harness is present, so #45, #47 and #48 are clear.

**One exception to "descriptors, not implementations"** is the settings panel's **registration and
open**. `settings/Panel.lua:1233-1299` registers the main canvas category itself, and
`settings/OptionsShim.lua:192-236` hand-rolls the open and the tree-expand walk. The library's
`O.CreateOptionsPanel` / `O.OpenOptionsPanel` (`libs/LibKa0s/Options.lua:1351, 1411`) are never
called. That is `CM-88`.

## Media (`library-stack-§8`)

`core/MediaSetup.lua:58` takes the addon's own first vararg and makes a single `Media.RegisterLSM`
call. The console descriptor carries `addonName` (`core/DebugLogSetup.lua:136`). The one
close-button wrapper is `core/CoreSetup.lua:185-187`, and the mandated grep shows no bypassing call
site. The addon draws no window of its own, so the standalone-windows decline path is never engaged.
The Blizzard `ReadyCheck-*` and `FavoritesIcon` glyphs are all on the options surface
(`modules/KCMItemRow.lua:35-37`, `settings/MacroBar.lua:715-716`, `settings/StatPriority.lua:108-109`),
which `library-stack.md:367` puts out of scope.

## Architecture (`architecture`)

`core/Namespace.lua` bootstraps the namespace, and `core/ConsumableMaster.lua` promotes it to the
AceAddon object. The addon is above architecture-§4's threshold and runs a closed bus
(`core/Bus.lua`). The bus has **five** messages, declared once in a strict `Bus.Catalog`
(`core/Bus.lua:128-132`), all `Ka0s_ConsumableMaster_<PascalCase>`. Every receiver takes a
**tracked** target from `LibKa0s-Bus-1.0`. The only literal typed at a call site outside the catalog
is a test-only probe in `tests/test_harness.lua:73-74` (`CM-93`).

**Write paths (`architecture-§5`).** The per-category item sets are one structural registry, with
`modules/Selector.lua` as its only runtime writer. Every whole-value preference is a schema row. The
three pieces of named non-setting state are named at `docs/ARCHITECTURE.md:117-133`: the macro
fingerprint cache (`MacroManager`), the bar's drag geometry (`MacroBar`) and the perf ring (the
library). The load pass is `D.RunMigrations`. I grepped every stored-tree write outside the helper
and classified each hit. All fall into class (b) (inside `Selector`), (c) (inside `Database.lua`'s
runner) or (e) (inside a named owner). None is filed.

## SavedVariables (`savedvariables`)

The defaults tree is declared once, in `defaults/Profile.lua` (`schemaVersion = 1` at `:31`). The
runner is `core/Database.lua` (`D.CURRENT_SCHEMA = 3`), account-wide and per-profile.
`ConsumableMasterPerfDB` sits outside AceDB. No `t.k = stored.k or D.k` is written over a
user-choice falsy field.

## Options UI (`options-ui`)

Pages and tabs, read from the schema:

| Page | Tabs (declaration order) |
|---|---|
| General | `Master controls`, `Maintenance` (`settings/General.lua:380-381`) |
| Macro Bar | General, Layout, Bar appearance, Button appearance, Labels, Flyout, Visibility, Buttons (`settings/MacroBar.lua:1101-1108`) |
| Stat Priority | one strip, suite-pinned (`tests/test_settingsui_optionsui.lua:118`) |
| Macros | one tab per category, fifteen (`KCM.Settings.macroOrder`) |
| Profiles | AceConfig-drawn, which exempts it from the strip |

Here is how checks (a)–(i) came out. (a) Every page draws a strip, pinned at
`tests/test_settingsui_optionsui.lua:78`. (b) `Master controls` is the first tab on General, composed
by `H.MasterControls` (`settings/General.lua:201`), with the minimap row carrying `neverReset`
(`:286`). Because v2.49.0 names this addon's unlocked bar as its preview, Lock frame is the switch
and no Test mode row is owed. (c) Colors come through `H.ColorPair`. (d) `disabledIf` has 0 hits in
`settings/`. (e) The chat-scroll arrow grep has 0 hits in `settings/`. (f) The only `LSM30_*` hits are
comment lines (`settings/OptionsSetup.lua:174, 177`). (g) No `InlineGroup` is used in `settings/`.
(h) The wrapped-strip case is `tests/test_settingsui_optionsui.lua:554`. (i) No page has a secondary
strip.

**Combat (options-ui-§2).** Nothing closes Blizzard's settings window in combat. The only
`SettingsPanel` and `OpenToCategory` hits are in the host's own open (`settings/OptionsShim.lua:187-236`).
That open is combat-gated at `:217` and uses the canonical refusal wording (`settings/Panel.lua:120`).
It is still a **second open beside the library's** (`CM-88`).

## Launcher (`launcher`)

`core/LauncherSetup.lua` builds **one** object through `LibKa0s-Launcher-1.0` and registers it in
`KCM:OnInitialize` (`core/ConsumableMaster.lua:72`). The label is `Ka0s Consumable Master`. The icon
is the 128 logo, built from `addonName`. `minimap` is a thunk onto `db.global.minimap`. Left-click is
rung **(b)**, toggling the bar lock through `KCM.MacroBar.SetLocked`, which matches `ADDONS.md:22`.
While the addon is disabled, left-click prints the dispatcher's refusal line and writes nothing
(`core/LauncherSetup.lua:175-179`). Right-click opens the panel in either state. No reset reaches
`minimap.hide` (`settings/General.lua:286`, `settings/OptionsSetup.lua:115`).

## Slash (`slash-commands`)

`settings/Slash.lua` builds the dispatcher from `LibKa0s-Slash-1.0` (vendored Slash minor 14). The
`COMMANDS` table starts at `settings/Slash.lua:143`, is published as `KCM.COMMANDS` at `:354`, and
declares 21 verbs, including `enable`, `disable`, `lock` and `unlock`. The chat tag is the cyan `[CM]`.

**The disabled state (`slash-commands-§7`), in five parts.**

- **Teardown.** There is one latch, `core/LifecycleSetup.lua`, built on `LibKa0s-Lifecycle-1.0` with
  two named holds: `disabled` (persisted) and `perf` (session-only, taken by `Perf-1.0` itself). There
  is no second teardown path. `standDown` (`:71-101`) takes down the bus record, the coalescer,
  events and the bar at the source, and registers `PLAYER_REGEN_ENABLED` only when in combat.
  `standUp` (`:110-119`) calls `KCM:OnEnable` and does not copy its list.
- **Registration set.** Nine events are registered in `KCM:OnEnable` (`core/ConsumableMaster.lua:708-716`)
  and all are dropped by `UnregisterAllEvents`. Seven message registrations are made on tracked bus
  targets (`core/Bus.lua:145`, `modules/MacroBar.lua:589/593`, `settings/OptionsShim.lua:264/268/271`,
  `settings/Profiles.lua:120`), and all are dropped by `KCM.Bus.StandDown`. The settings bootstrap
  frame (`settings/Panel.lua:1302-1311`) is setup, and it unregisters itself once the category exists.
  The bar's visibility state driver is unregistered (`modules/MacroBar.lua:455`). **One survivor
  remains:** the per-flyout `RegisterAttributeDriver(flyout, "kcmCombat", …)`
  (`modules/MacroBarFlyout.lua:289-290`), one per slot, which nothing unregisters (`CM-84`).
- **Writes.** I found no SavedVariables write reachable from a game event while disabled.
- **Surfaces.** Every reserved verb, `config`, the bare `/cm` and the schema CLI answer normally.
  Eight feature verbs take §2's SHOULD with one refusal line. **But the settings category is not
  guaranteed to survive a disabled addon's combat login** (`CM-86`).
- **Conformance suite.** `tests/test_disabled.lua` is listed at `tests/run.lua:459` and all 18 of its
  cases pass. It asserts on the kit's recording registry and not on handler returns. Its step 4
  surveys only the bar's visibility driver (`:222-223`), so it is green over the `CM-84` survivor
  (`CM-85`).

**Event registration (`events-frames-taint-§1`).** `KCM:OnEnable` is nine bare `self:RegisterEvent`
calls. There is no per-event `pcall` and no record of rejected names (`CM-87`).

## Debug (`debug-logging`) and Performance (`performance`)

The console is built from `LibKa0s-DebugLog-1.0` with `name`, `addonName` and `font`. The perf
harness is built from `LibKa0s-Perf-1.0` with `sv = "ConsumableMasterPerfDB"` (`core/PerfSetup.lua:110`)
and `lifecycle = KCM.Lifecycle` (`:129`). `tests/perf.lua` ships five scenarios. The in-game store
`docs/perf-analysis/` holds two frozen bundles, each with all three artifacts, indexed at
`docs/perf-analysis/README.md:142-143`. The performance-§12 exemption is not claimed.

## Packaging (`packaging`)

`.pkgmeta` has no `externals:`. Check (a), the named entries, prints nothing. Check (b), every root
dot-entry, prints only `.git`. Check (c), false claims, prints nothing: `.claude` and `.superpowers`
both exist and both are ignored. This check is compliant.

## Line endings (`line-endings`)

`.gitattributes` exists and is 84 lines long. The pin `* text=auto eol=crlf` at `:26` is the right
kind for this repo. `*.sh text eol=lf` is at `:36` and `*.py text eol=lf` at `:37`. Twenty `binary`
marks are present. The body is byte-identical to the canonical client-bound body once CR is stripped,
and there is no tail. Check (e) returns **0**, and the kit gate `tests/_kit/test_eol.lua` passes on both
cases.

## Lint (`lint`)

`exclude_files` (`.luacheckrc:14-19`) lists `libs/`, `docs/audits/`, `docs/reviews/` and `tests/_kit/`,
so under `tests/` only `tests/_kit/` is excluded. The harness globals sit in a `files["tests/"]` stanza
(`:118-120`), and there is no top-level `ignore`. Result: **0 warnings / 0 errors in 116 files**.

## Testing (`testing`) and automated tests (`automated-tests`)

The headless suite passes **998 / 0 failed / 0 skipped**. The README badge (`README.md:7`) and
`docs/test-cases.md` both read 998. The vendored-payload gate passes three cases: the lib payload,
the kit and the runner mode. The runner `tests/_kit/run-automated-tests.sh` is recorded `100755`.
`docs/automated-tests/{README.md,RESULTS.md}` both exist, and there is no retired `complexity.md`.
The newest bundle is `20260916-184427` (`da0b0f8`, clean, not a release run), which is **33 commits**
behind `HEAD`.

Today's verbatim `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` reports **23258 NLOC, 2499
functions, avg NLOC 7.9, avg CCN 2.6, 0 warnings**. The bundle recorded 22707 NLOC and 2396
functions. One function now sits at CCN 15: `KCM:OnRegenEnabled` (`core/ConsumableMaster.lua:623-657`),
dense guarding with no tangle. The watch list's `Owed a decision` rows for `settings/Category.lua` and
`settings/Panel.lua` were answered with peels on 2026-09-16. The record has not been regenerated
since, and no release has been cut since 1.6.2 (`CM-95`, Info).

## Documentation (`documentation`)

**Root.** `README.md` is player-facing. Its five badges are in order, with the standard badge **bare**
(`:6`). It has no logo image, no library inventory, no `## Testing` and no angle-bracket
placeholders. It does carry a **`## What's new in 1.6.2`** section at `:35`, which v2.42.0 removed
(`CM-89`). `CLAUDE.md` has the H1, `## Standards compliance (read first)` at `:5`, the gate, and the
provenance line at `:61`. `DEPENDENCIES.md` is present. There is no root `CHANGELOG.md` and no
`TODO.md`.

**`docs/`.** The trio is present. **Tier 1** has all six files under their canonical names.
**Tier 2** was checked against the code:

- `slash-dispatch.md` is present (21 verbs, four subcommand trees).
- `midnight-quirks.md` is present.
- `debug.md` is present (the `/cm dump` targets).
- `profiles.md` is present (the Profiles page ships).
- `perf-analysis/README.md` is present (the harness is wired).
- `message-bus.md` is recorded *Not applicable*: 5 messages against a threshold above 10.
- `compat-layer.md` is recorded *Not applicable*: the section's own grep over `core/Compat.lua`
  answers **2**, against a threshold of 3.

**Tier 3** is `macro-bar.md` and `macro-manager.md`.

`## Documentation map` covers every one of the **20** `.md` files on disk exactly once, across four
tables. The *Verification and record* table carries exactly its six rows. There are no orphans and no
dangling rows; the two *Not applicable* rows are status rows. The frozen stores are named once
(`:360`). I found no non-canonical Tier 1/2 filename, no `file-index.md`, no `conventions.md`, no
`complexity.md` and no `docs/perf-runs/`.

**Hub shape.** `docs/ARCHITECTURE.md` is **504** lines, past the ~400 SHOULD (`CM-92`). The ten
mandated sections are all present. Three load-order descriptions and two line citations have drifted
from the TOC since `LifecycleSetup.lua` arrived (`CM-94`).

**Citation notation (`documentation-§6`).** Of **672** `filename-§N` citations in the authored scope,
every one is in range. There are 0 retired dotted forms. There are **46** bare `§N` continuations in
22 files (`CM-75`).

**US English (`localization-§5`).** The kit's prose gate passes, but it does not read
`docs/automated-tests/` or `docs/perf-analysis/` (`CM-79`). Three British spellings survive in
authored prose: two in `docs/perf-analysis/README.md` (`CM-80`) and one that the published list
misses (`CM-81`).

## Deviation register and issue store (`audit-review-history`)

`## Documented deviations` (`docs/ARCHITECTURE.md:404`) carries **three** rows, all Decided
2026-08-05:

- **`localization-§4`** is accepted. Its trigger has not fired, and its evidence `CM-30` resolves to
  `docs/audits/2026-07-18/`.
- **`compat`** is accepted. Its trigger is a client-side fact the tree cannot show. The row's evidence
  `CM-63` and `CM-R-10` resolve. It names two of the four direct `GetItemInfo` sites (`CM-96`, Info).
- **`preview-mode`** is **stale**. The rule it cites was raised to a MUST at v2.47.0, and v2.49.0 then
  exempted this addon by name. Its own re-check trigger (*"a preview / test verb being added to /cm"*)
  fired at `87ed204` and reversed at `9c45eff`, and the row was never re-decided (`CM-90`).

The retirement of the `toc-file-§5` row is recorded in prose at `:418`.

The issue store is **39** GitHub issues, read with
`gh issue list --state all --limit 200 --json …`. Every issue carries a `state:` and a `severity:`
label. None has a `[status]` title prefix, and there is no `docs/pending/`.

The closed `state:will-not-do` issues (#17–#26, #28, #30, #31) decline optional LibKa0s modules, a
MAY field and superseded pre-adoption states. None declines a standard rule, so no register row is
owed. Two of them, #28 (Widgets) and #30 (Item), have since been overtaken by adoption. That is
harmless in a working queue and is recorded here only.

**Re-vendor store.** `docs/revendor/` holds 8 bundles, with the horizon at 2026-08-25. **33** tags
were vendored after the horizon and **27** of them have no bundle and no register row (`CM-91`).

## Git and versioning (`versioning-git`)

This run is on branch `feat/2026-09-23-review-audit-remediation` at `7adfea1`, which is `master`'s
merge of the 2026-09-22 standards sweep. `## Version: 1.6.2` matches the top `## Version History` row
and the `## What's new` heading.
