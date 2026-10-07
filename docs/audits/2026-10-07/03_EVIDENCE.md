# 03 — Evidence: Ka0s Consumable Master (2026-10-07)

All commands were run from the repo root at `862151a` with a clean tree. Before this file was
written, each `file:line` below was re-read and its text is quoted beside it. Each count gives the
command that produced it and the scope that command covered.

---

## E0 — Standard resolution

```
curl -fsSL $RAW/AUDIT.md ; curl -fsSL $RAW/standards/STANDARDS.md ; curl -fsSL $RAW/standards/ADDONS.md
for f in $(grep -oE 'standards/[a-z0-9-]+\.md' standards/STANDARDS.md | sort -u); do curl -fsSL $RAW/standards/$f; done
```

- `STANDARDS.md:1`: `# Ka0s WoW Addon Standard (v2.76.1, 2026-10-07)`.
- Fetches: 28 section files fetched. The only failure was `standards/tiered-layout.md` (404). It
  appears only at `STANDARDS.md:236`/`:246`/`:249`, the v2.0.0/v1.5.0/v1.2.0 changelog entries
  (*"`tiered-layout` is renamed to `layout`"*), and not in the Sections list.
- `cmp` of each fetched file against `../WowAddonStandards` (HEAD `f472389`) printed no `DIFF`
  line.
- `dev-copilot-profile` printed `profile=wow`, `kind=addon` and `reason=toc:## Interface`.
- `ADDONS.md:22`: `| Ka0s Consumable Master | … | Enabled · Locked (the macro bar) |`.

## E1 — Headless suite, lint, complexity (all through `ka0s-bounded`)

```
~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/run.lua
  1201 passed, 0 failed, 1 skipped, 1202 total        EXIT 0
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
  Total: 0 warnings / 0 errors in 130 files          EXIT 0
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
  complexity  pass  — 0 warnings (fun rate 0.00), 27244 NLOC / 3200 funcs, avg NLOC 7.9, avg CCN 2.5 (max 15)
  record:  newest bundle 20260927-030419 measured 86660df, 59 commit(s) behind HEAD
```

- The one skip: `SKIP diagnostics contract: an addon that opts out … this addon keeps the default`.
- `docs/test-cases.md` ends `| **Total** | **1202** |`, and `README.md:7` reads
  `![Tests](…Tests-1201%2F1202_passing-green)`, which agrees.
- The `.luacheckrc` `exclude_files` list is `"libs/", "docs/audits/", "docs/reviews/", "tests/_kit/"`,
  so the only exclusion under `tests/` is the kit. The comment at `:21` reads
  `-- NO TOP-LEVEL \`ignore\`, and none is coming back`.
- `tests/_kit/framework.lua:20`: `Kit.VERSION = 37`.
- `tests/run.lua:551`: `{ name = "test_lizard_sighted",       dir = "tests/_kit/" },`.
- `tests/run.lua:549`: `{ name = "test_layout_cap",           dir = "tests/_kit/" },`.

## E2 — Census: authored Lua (`layout-§1`)

Scope: the default denominator, `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, which
covers 130 files. It includes `tests/` and excludes the vendored `libs/` and `tests/_kit/`.

```
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -n | tail
   1002 tests/test_settingsui.lua   1009 tests/test_selector.lua   1012 tests/wow_mock.lua
   1023 tests/test_schema.lua       1150 settings/Category.lua     1182 settings/MacroBar.lua
   1196 settings/Panel.lua         44691 total
```

There are 0 files over 1500 and 7 in the band. `docs/ARCHITECTURE.md:408` reads
`**No authored file in this repository is over the cap.**`, and `:417-420` lists the same seven at
the same counts. No generator: `git ls-files '*.py' '*.sh' | grep -vE '^(libs/|tests/_kit/)'`
printed nothing.

## E3 — Vendored payload (`library-stack-§7`, #45/#48/#59)

```
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md      -> 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).
grep -n 'Bundles \[LibKa0s\]' README.md      -> (none)
grep -nE '^## (Libraries|Bundled libraries|…)' README.md -> (none)
grep -n 'WoW_Addon_Standard' README.md       -> 6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
git -C ../LibKa0s archive v1.70.0 LibKa0s testkit | tar -x -C $T
diff -r $T/LibKa0s libs/LibKa0s   -> empty (SHIP-EMPTY)
diff -r $T/testkit tests/_kit     -> empty (KIT-EMPTY)
grep -hE '^local (MAJOR|MAJOR_NAME)[^=]*= *"LibKa0s' libs/LibKa0s/*.lua | sort -u | wc -l  -> 15
```

The 15 majors are Bus 2, Compat 1, Core 10, DebugLog 19, Env 1, Item 2, Launcher 5, Lifecycle 3,
Media 4, Options 28, Perf 14, Pool 3, Schema 2, Slash 19 and Widgets 12. The 14 consumed majors
were counted with
`grep -rhoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0"' core settings modules`, which finds all of them
except Pool.

## E4 — Re-vendor store (`CM-91`)

This is `AUDIT.md`'s command, run verbatim under `bash`. Its horizon is `2026-08-25`, the store's
first bundle.

```
vendored: 53 recorded: 51
UNRECORDED:
v1.69.0
v1.70.0
```

- `git show --stat f8d2f3b`: `chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)`.
  The non-payload paths it touched were `CLAUDE.md` and `docs/testing.md`, and no `docs/revendor/`
  path appears.
- `git show --stat 74bcda1`: `chore: re-vendor LibKa0s v1.70.0`. The only non-payload path it
  touched was `CLAUDE.md`.
- `ls docs/revendor | tail -1`: `2026-10-04-v1.68.1`.

## E5 — Doc sync drift (`CM-97`)

Scope: every `file:line` in `docs/ARCHITECTURE.md` that points into `core/ConsumableMaster.lua` or
`modules/MacroManager.lua`, each re-read, plus a grep for `/wow-addon` over the tracked
`.md`/`.lua`/`.toc` files. Excluded from that grep: `libs/`, `tests/_kit/`, `docs/audits/`,
`docs/reviews/`, `docs/superpowers/`, `docs/revendor/`, and the dated `automated-tests` and
`perf-analysis` bundles.

The handlers as they stand:

```
grep -nE '^function KCM:(On[A-Za-z]+)|^function KCM\.RegisterProfileCallbacks' core/ConsumableMaster.lua
558:function KCM.RegisterProfileCallbacks(target)   740:OnPlayerEnteringWorld  756:OnCooldownUpdate
762:OnBagUpdateDelayed  767:OnSpecChanged  778:OnRegenEnabled  824:OnRestrictionChanged
836:OnItemInfoReceived  857:OnLearnedSpell  865:OnEquipmentChanged  909:OnEnable
```

`RegisterProfileCallbacks` ends at `:621`. The table below gives each stale citation, what it cites,
what is actually at that line today, and where the target is now.

| `ARCHITECTURE.md` | Cites | Line today reads | Target is at |
|---|---|---|---|
| `:168` | `OnPlayerEnteringWorld` (`:730`) | `-- raw, and the event's fields come last …` | `:740` |
| `:169` | `OnBagUpdateDelayed` (`:752`) | (blank) | `:762` |
| `:170` | `OnSpecChanged` (`:757`) | `if KCM.MacroBar and KCM.MacroBarModel …` | `:767` |
| `:171` | `OnRegenEnabled` (`:768`) | `traceEvent(event or "PLAYER_SPECIALIZATION_CHANGED")` | `:778` |
| `:172` | `OnItemInfoReceived` (`:826`) | `local rewrite = lifted and restrictionType ~= 0` | `:836` |
| `:173` | `OnLearnedSpell` (`:847`) | `-- pipeline; everything else just triggers …` | `:857` |
| `:174` | `OnEquipmentChanged` (`:855`) | `end` | `:865` |
| `:175`, `:176` | `OnCooldownUpdate` (`:746`) ×2 | `-- Build / re-show the optional macro bar. …` | `:756` |
| `:177` | `OnRestrictionChanged` (`:814`) | `-- is true in Lua; the first cut read it …` | `:824` |
| `:124` | `core/ConsumableMaster.lua:814` | same as above | `:824` |
| `:123` | `core/ConsumableMaster.lua:548` | `---      happen to agree, MacroManager's …` | `:558` |
| `:102` | `core/ConsumableMaster.lua:548-611` | `:611` reads `afterReset(reason)` | `:558-621` |
| `:122` | `commitMacro` (`:466`) | `-- No line per macro here (debug-logging-§9) …` | `:498` |
| `:122` | write (`:501`) | `local active = opts.active` | `:531` `KCM.db.profile.macroState[macroName] = {` |
| `:122` | `macroState = macroState or {}` (`:480`) | `-- behind F-001. …` | `:512` |
| `:123` | `InvalidateState` (`:710`) | `--- behind the caller's debug gate; …` | `:737` |
| `:123` | write (`:717`) | `KCM.DebugForget("macro.held")` | `:744` `KCM.db.profile.macroState = {}` |
| `:124` | `MarkAllStale` (`:733`) | `-- v2.44.0), so it leaves one [Macro] line …` | `:760` |

That is **19** stale citations: 10 in the table at `:168-177` and 9 at `:102`/`:122-124`. Citations
that still resolve: `:102`'s `core/ConsumableMaster.lua:41` (`KCM.Database.RunMigrations()`),
`:304`'s `modules/MacroManager.lua:352-354` (the quota refusal), `:216`'s `:355`/`:366`
(`CreateMacro(…)` / `EditMacro(…)`), every `modules/Selector.lua` citation at `:101`, every
`modules/MacroBar.lua` citation at `:128-129`, and `schema.md:125`'s `modules/MacroManager.lua:73`.

`git log -3 -- core/ConsumableMaster.lua` lists `16a9422` (DG-CM-01, 2026-10-01), `a98d3bb` and
`c528b87` (DL-CM, 2026-09-30). The doc was last touched at `d9c788a`, 2026-10-03.

The plugin rename:

```
… | xargs grep -n 'wow-addon:\|/wow-addon'
docs/automated-tests/RESULTS.md:15:(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
docs/perf-analysis/README.md:133:The write-up is produced by `/wow-addon:perf-analysis`, which splits the paste, validates the record
```

`RESULTS.md` is generated (`:2`: `<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->`),
so its line belongs to `CM-95`. `perf-analysis/README.md` is authored. `STANDARDS.md` (v2.76.0)
names the command `/dev-copilot:wow-perf-analysis`.

## E6 — TOC annotations (`CM-98`, `CM-83`)

- `core/SlashDump.lua:15`: `-- Same secret-safe seam as every other chat line (core/Constants.lua).`
- `core/SlashDump.lua:16`: `local say = KCM.Say`. `grep -c 'say(' core/SlashDump.lua` returns 45.
- `ConsumableMaster.toc:97-99`: `# CoreSetup builds KCM.Say / KCM.SafeToString from LibKa0s-Core-1.0. It has to`
  `# sit after Constants.lua (KCM.PREFIX) and before core\SlashCommands.lua, which`
  `# takes the printer as a file-scope upvalue.`
- `ConsumableMaster.toc:139-143`: `# SlashDump before SlashCommands: the \`/cm dump\` targets are a leaf that only`
  `# reads addon state, …` and then `core\SlashDump.lua`.
- `core/CoreSetup.lua:190`: `KCM.Say = printer.Format`. `KCM.Say` is defined in CoreSetup, not
  Constants.
- File-scope upvalues on the namespace were found with
  `grep -nE '^local [A-Za-z_, ]+ *= *(KCM|NS)\.[A-Za-z_]+…$' core/*.lua defaults/*.lua modules/*.lua`.
  The hits outside a file's own table were `core/ConsumableMaster.lua:16 local Perf = KCM.Perf`
  (annotated at TOC `:77-85`), `core/SlashCommands.lua:34 local say = KCM.Say` (annotated at `:97-99`),
  `core/SlashDump.lua:16 local say = KCM.Say` (**not** named), and
  `modules/MacroBar.lua:35 local Perf = KCM.Perf` (annotated at `:77-85`).
- `# Defaults`: `ConsumableMaster.toc:151-155` carries Profile.lua's reason. Lines `:157-171`
  (`defaults\Categories.lua` … `defaults\Defaults_BattleRez.lua`) carry none.
  `defaults/Defaults_Food.lua:20` reads `KCM.SEED = KCM.SEED or {}`.
- The groups that are now marked: `:58` `# Position within this group is conventional, not load-bearing.`
  (Locales), `:174` (Modules), and `:214` `# The four page files: position within this group is conventional, not load-bearing.`

## E7 — Register rows and evidence ids (`CM-99`, accepted rows)

- `docs/ARCHITECTURE.md:376` (`compat`) ends `… Review findings \`CM-R-10\` and \`CM-R-05\`, audit findings \`CM-63\` and \`CM-96\` | 2026-08-05; narrowed 2026-09-24 | …`.
- `docs/ARCHITECTURE.md:377` (`options-ui-§1`): `| 2026-09-24 (CM-18, WS-02 ruling) | …`.
- `grep -rln 'R-10' docs/reviews/` returns only `2026-08-03/03_SMOKE_TESTS.md` (a smoke step `R-10`)
  and `2026-09-07/*`.
- `docs/reviews/2026-09-07/01_FINDINGS.md:206`: `### CM-R-05 — Two \`colorDecode\` codecs over one storage shape disagree …`.
- `docs/reviews/2026-09-07/01_FINDINGS.md:309`: `### CM-R-10 — \`KCM.MakeCloseButton\` has zero call sites \`[dead-code]\``.
- The findings the row means:
  - `docs/reviews/2026-08-05/01_FINDINGS.md:289`: `### F-010 — One bare \`GetItemInfo\` call with no \`C_Item\` preference and no guard`.
  - `docs/reviews/2026-09-23/01_FINDINGS.md:226`: `### F-005 — Two hot-path item reads call the bare global \`GetItemInfo\` …`.
- `git show f99e47c -- docs/ARCHITECTURE.md` (2026-08-05) introduced the `CM-R-10` citation for the
  `GetItemInfo` row.
- `docs/audits/2026-07-12/02_DEVIATIONS.md:26`: `| **CM-18** | §15.2, #26 | MUST | Root \`CLAUDE.md\` carries the full agent brief …`.
- `../Ka0sAddonsCommonTasks/docs/2026-09-23-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/items.tsv:310`:
  `CM-18	M3	ConsumableMaster	Degraded (library-absent) composed-row verbs …`. `WS-02` appears only in
  that sibling bundle (`00_OVERVIEW.md:99`).
- The ids that resolve correctly:
  - `CM-30`: `docs/audits/2026-08-05/02_DEVIATIONS.md`, `| **CM-30** | \`localization-§4\` …`.
  - `CM-63`: the same file, `| **CM-63** | \`compat\` | MUST | **The legacy item APIs …`.
  - `CM-96`: `docs/audits/2026-09-23/02_DEVIATIONS.md`.
- Trigger evaluation:
  - `git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'GetItemCount'` finds three hits.
    `core/BagScanner.lua:55` reads `C_Item.GetItemCount(itemID, false, false, true)`.
    `core/MacroDisplay.lua:76` reads `local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount`.
    `modules/KCMItemRow.lua:230` reads `local count = (self.itemID and _G.GetItemCount) and _G.GetItemCount(self.itemID) or 0`.
    The only global reads are the two the row names.
  - `core/LifecycleSetup.lua:56`: `if not lib then return end` (still no Lifecycle stub).
- The issue store came from
  `gh issue list --state all --limit 200 --json number,title,state,labels`, which returned 44
  issues. None carries a `[status]` prefix. The will-not-do issues are #14, 17-26, 28, 30, 31 and 41.
  `gh issue view 41` shows the decline of `O.RenderTabbedSchema` on three pages. Those pages still
  draw the library's `H.TabStrip` (`settings/Category.lua:1090`, `settings/MacroBar.lua:1152`,
  `settings/StatPriority.lua:721`), so the decline is about adopting a library member and owes no
  register row. `ls docs/pending` reports `No such file or directory`.

## E8 — Complexity record (`CM-100`, `CM-95`)

- `docs/testing.md:283`: ``| `complexity` | `lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .`, run sighted over the kit's sanitized shadow with function-count parity (kit revision 35; `--suite complexity`) | no — recorded only | **yes**, plus zero functions above CCN 15 |``.
- `CLAUDE.md:107`: ``bash tests/_kit/run-automated-tests.sh --suite complexity`, the sighted lizard run …``.
  `DEPENDENCIES.md:134`: `bash tests/_kit/run-automated-tests.sh --suite complexity   # sighted complexity report`.
  `grep -n 'lizard -l' CLAUDE.md DEPENDENCIES.md` returns nothing.
- `docs/automated-tests/20260927-030419/manifest.json:10`: `"git": { "sha": "86660dfd…", "branch": "master", "dirty": false }`.
  At `:16`, `"complexity": { "status": "pass", … "maxCcn": 14, … "functions": 2838, … "bandFiles": 5, "overCapFiles": 0, …}`
  has no `blindFiles` key.
- `docs/automated-tests/RESULTS.md:113`, `:115` and `:116` hold the three *Accepted* rows
  (`settings/MacroBar.lua`, `tests/test_schema.lua`, `tests/test_selector.lua`). Each reads
  *"… is the first release to carry it, so this is acceptance 1 of 3 toward the three-release limit."*
- Drift since the record (band): Panel 1166→1196, MacroBar 1169→1182, Category 1142→1150. New in
  the band are `tests/wow_mock.lua` 1012 and `tests/test_settingsui.lua` 1002.

## E9 — `KCM.DebugQuiet` (`CM-101`)

- `core/ConsumableMaster.lua:132`: `KCM.DebugQuiet = KCM.DebugQuiet or {}`.
- `:119-120`: `-- … What stays here is the one thing those gates cannot do: COUNT the passes a change-gated line held back`.
- `core/DebugLogSetup.lua:258-259`: `onClear = function()` / `if KCM.DebugQuiet and KCM.DebugQuiet.Reset then KCM.DebugQuiet.Reset() end`.
- `modules/MacroManager.lua:392`: `local Q = KCM.DebugQuiet`.

## E10 — Bare `§N` (`CM-75`)

Scope: the tracked `.lua`, `.md` and `.toc` files, 156 of them, after excluding `libs/`,
`tests/_kit/`, `docs/{audits,reviews,superpowers,revendor}/` and the dated `automated-tests` and
`perf-analysis` bundles.

```
xargs grep -noP '(?<![A-Za-z0-9-])§[0-9]+' | cut -d: -f1 | sort | uniq -c
  51 docs/smoke-tests.md   1 modules/MacroManager.lua   1 tests/run.lua   1 tests/test_debugcoverage.lua
xargs grep -noP '\b[a-z]+(-[a-z]+)*-§[0-9]+' | wc -l        -> 839
range check against each section file's highest numbered heading -> 0 OUT, 0 UNKNOWN
```

- `modules/MacroManager.lua:709`: `--- deferred work, §9's quiet steady state). Called after each pipeline pass`.
- `tests/run.lua:477`: `-- What the log carries and what it holds back (debug-logging-§8/§9, DL-CM-02).`
- `tests/test_debugcoverage.lua:2`: `-- (debug-logging-§8's diagnosis list, §9's quiet steady state).`
- The three dotted hits are all `docs/smoke-tests.md` (`:595`, `:615` and `:634`), which use that
  document's own numbering of the 2026-09-07 checklist.

## E11 — Disabled state (compliant)

These greps cover the shipped Lua, `git ls-files '*.lua' ':!libs' ':!tests'`.

- **Registrations:**
  - `core/Bus.lua:145`: `t:RegisterMessage(KCM.MSG.RECOMPUTE, …)`.
  - `modules/MacroBar.lua:705` and `:709`, `settings/OptionsShim.lua:235-242`, and
    `settings/Profiles.lua:120`. All five are on targets from `KCM.NewBusTarget`, which the
    `LibKa0s-Bus-1.0` record tracks.
  - `core/ConsumableMaster.lua:912`: `KCM.SafeRegisterEvent(self, e[1], e[2], KCM.RejectedEvents)`.
  - `core/LifecycleSetup.lua:112`: `PLAYER_REGEN_ENABLED`, only when the teardown is held.
  - `settings/Panel.lua:1189-1190`: `PLAYER_LOGIN` and `ADDON_LOADED` on the bootstrap frame, which
    are unregistered at `:1194`.
  - `modules/MacroBar.lua:447`: `RegisterStateDriver`.
  - `modules/MacroBarFlyout.lua:300` and `:351`: `RegisterAttributeDriver`.
  - `modules/MacroBarFlyout.lua:140`: `HookScript("PostClick", …)` on the addon's own secure button,
    which closes its flyout. No un-hook exists for a script hook, and the body touches only the
    addon's own frame.
- **Unregistrations:**
  - `core/LifecycleSetup.lua:104`: `if KCM.UnregisterAllEvents then KCM:UnregisterAllEvents() end`.
  - `:85`: `KCM.Bus.StandDown()`.
  - `modules/MacroBar.lua:556`: `UnregisterStateDriver(bar, "visibility")`, and `:563`:
    `bar:SetScript("OnUpdate", nil)`.
  - `modules/MacroBarFlyout.lua:343`: `UnregisterAttributeDriver(flyout, "kcmCombat")`.
  - `core/ConsumableMaster.lua:791`: `self:UnregisterEvent("PLAYER_REGEN_ENABLED")`.
- **Timers:** `C_Timer.After` one-shots at `core/ConsumableMaster.lua:347` (the coalescer, disarmed
  by `KCM._recomputePending = false` at `core/LifecycleSetup.lua:92`), and at
  `settings/OptionsShim.lua:171` and `settings/CategoryAddByID.lua:309`/`:371`, which belong to the
  surviving settings layer.
- **Slash surface:** `settings/Slash.lua:356-360` reads `local LIVE_VERBS = { "help", "config", "version", "enable", "disable", "debug", "perf", "diagnostics", "get", "set", "list", "reset", "resetall", "dump", "profile", }`.
- **Suite:** `tests/test_disabled.lua:215` (`for frame, attrs in pairs(mock.attributeDrivers) do`),
  `:244` (`local drivers = mock.stateDrivers[bar]`), and `:437-439` (both diagnostics forms
  dispatched while disabled).

## E12 — Launcher, diagnostics, library lines (compliant)

- `core/LauncherSetup.lua:141`: `label = "Ka0s Consumable Master",`. `:166`: `isEnabled = function()`.
  `:172`: `setEnabled = function(on)`. `:193`: `isLocked = function()`.
  `:215`: `debug = function(tag, message)`. `:225`: `debugAtEnable = function(tag, message)`.
- `settings/General.lua:61`: `local MINIMAP_PATH = "global.minimap.shown"`.
- `settings/Slash.lua:224`: `{"diagnostics",   "Write a diagnostics report to the debug console, for a bug report",`.
  `:198`: `if arg == "diagnostics" then`. `:596`: `debug        = function(tag, message)`.
- `settings/OptionsSetup.lua:224`: `addonName = addonName,`. `:241`: `debug = function(tag, message)`.
- `core/LifecycleSetup.lua:152`: `debug     = function(tag, message)`.
- `grep -n 'diagnosticsEnablesLogging' core/*.lua` returns nothing (the default).
- `git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'OnTooltipShow\|MenuUtil\|EasyMenu'`
  returns nothing outside comments.

## E13 — Line endings and packaging (compliant)

```
test -f .gitattributes                                    -> present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes  -> 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes       -> 36:*.sh text eol=lf   37:*.py text eol=lf
grep -c ' binary$' .gitattributes                         -> 20
diff <(head -n 84 .gitattributes | tr -d '\r') <line-endings-§5 client-bound body, 84 lines>  -> empty
(e) git ls-files -z | xargs -0 … (AUDIT.md's command, verbatim)                               -> 0
.pkgmeta (a)(b)(c) under bash -> only "UNACCOUNTED — .git"
```

The kit's `test_eol` is wired at `tests/run.lua:547` and passes.

## E14 — Media, TOC fields, README (compliant)

- `ConsumableMaster.toc:6`: `## IconTexture: Interface\AddOns\ConsumableMaster\media\logos\consumablemaster.logo.128.tga`.
- Logo header, read with `od`: byte 2 = `2`, width/height = `128 128`, depth = `32`.
- `git ls-files media`: `media/logos` (4 files) and `media/screenshots` (6 files). There is no
  `fonts/`, `icons/` or `textures/`.
- `core/MediaSetup.lua:58`: `local addonName, NS = ...`, and `:79`: `return Media.Icon(addonName, name)`.
- Close-button grep (`MakeCloseButton(` outside `libs/` and `tests/`): `core/CoreSetup.lua:207-208`
  (the wrapper) and comments only.
- README: no numbered list outside a fence (the `awk` scan printed nothing). `:130` is
  `## Reporting a bug`, placed before `:138` `## Issues and feature requests`.

## E15 — Documentation map (compliant)

```
git ls-files 'docs/*.md' | grep -vE '^docs/(audits|reviews|superpowers|revendor)/' \
  | grep -vE '^docs/(automated-tests|perf-analysis)/[0-9]'      -> 21 files
```

Every one of the 21 appears once in `docs/ARCHITECTURE.md:323-363`: Required (7), Conditional
(7 rows, 6 present and `message-bus.md` *Not applicable*), Verification and record (6) and
Addon-specific (2). The Tier 2 triggers:

- `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` returns 3.
- The verb list from `settings/Slash.lua:164-308` has 23 entries.
- `core/Bus.lua:128-132` declares 5 messages.

`wc -l docs/ARCHITECTURE.md` returns 432.
