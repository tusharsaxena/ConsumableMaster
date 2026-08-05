# 03 — Evidence

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here. Mechanical checks were
**executed**, not reasoned about; each records the real command and its real output. A check that
could not run says so and names the path it looked for.

**Audited against standard v2.21.0 (2026-08-04).** Repo HEAD `6b7d3d0`.

---

## A. Mechanical checks

### A1. Lint — `luacheck .`

```
$ cd /mnt/d/Profile/Users/Tushar/Documents/GIT/ConsumableMaster && luacheck .
...
Checking settings/StatPriority.lua                 OK

Total: 0 warnings / 0 errors in 54 files
exit=0
```

Tool: `Luacheck 1.2.0` (Lua 5.1, LuaFileSystem 1.9.0). **Pass — 0/0 over 54 files.**

Scope caveat, for the record rather than as a finding: `.luacheckrc:11-16` excludes `libs/`,
`docs/audits/`, `docs/reviews/` and `tests/`, so the 54 files are `core/ defaults/ locales/ modules/
settings/` only. That is the config the standard's `lint` template prescribes, and
`docs/automated-tests/RESULTS.md:35-43` states the scope explicitly.

### A2. Harness — `lua5.1 tests/run.lua`

```
$ lua5.1 tests/run.lua
...
  PASS  Widgets: every widget name used by the settings pages is registered

  656 passed, 0 failed, 656 total
exit=0
```

Interpreter: `Lua 5.1.5`. **Pass — 656/656.** Matches the README badge
(`README.md:7`, `Tests-656%2F656_passing`) and the newest bundle
(`docs/automated-tests/20260804-233147/manifest.json`, `"passed": 656, "failed": 0, "total": 656`).

### A3. Complexity — the standard's **verbatim** invocation

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
...
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     15257       8.0     2.7       63.8     1630            0      0.00    0.00
exit=0
```

Tool: `lizard 1.23.0`. Run from the repo root, flags exactly as `AUDIT.md` and `performance-§10`
spell them — no extra flag, no narrowed path, no re-tuned threshold.

**Drift against the committed record: none.**

```
$ diff --strip-trailing-cr docs/automated-tests/20260804-233147/complexity.txt <fresh run>
exit=0        # zero lines of difference across all 1733 lines
```

(The `--strip-trailing-cr` is only because the committed artifact is CRLF per `.gitattributes:12`
while a fresh pipe is LF. Content is identical line for line, including the footer.)

- **No function crossed a `lizard` threshold since `20260804-233147`.** `Warning cnt` is 0 in both.
- **No file entered `layout-§1`'s 1000–1500 band since that run.** The one band member is unchanged:

```
$ wc -l  (addon + test .lua, ≥900 LOC)
    836 core/SlashCommands.lua
    950 settings/Panel.lua
   1497 tests/test_macrobar.lua
```

  `tests/test_macrobar.lua` at 1497 is the sole entry in `RESULTS.md`'s band table
  (`docs/automated-tests/RESULTS.md:96-98`) and is carried there unchanged, with the disposition
  naming the 3-line headroom and the split to make when it crosses.

- **Bundle staleness.** `docs/automated-tests/20260804-233147/manifest.json` stamps
  `"startedAt": "2026-08-04T23:31:47+05:30"` at git `97c05b872ca0ae8defda370c0dc91559cb66afdd`,
  `"branch": "feat/fix-ccn"`, `"dirty": true`. HEAD is now `6b7d3d0` — four commits later
  (`97c05b8 → e42a909 → b771fc4 → 595842f → 6b7d3d0`), which are the LibKa0s re-vendor and two
  documentation passes. The numbers still reproduce byte for byte, so the record is **stale in
  provenance but not in content**: nothing it reports has moved. That is a note about the release
  process (the checkpoint is release, not commit — `automated-tests-§6`), not a reason to flag the
  addon for failing to gate commits on complexity.

### A4. Watch list read as a decision record — `automated-tests-§4`, anti-pattern #53

`docs/automated-tests/RESULTS.md:73-102`.

- **Warned functions:** `None.` — written out, not left blank, per `performance-§10`. Below it, the
  **seven functions at the CCN-15 ceiling are named rather than counted** (`:86-89`):
  `Helpers.BuildAboutContent` (`settings/Panel.lua:699`), `S.SweepStaleDiscovered`,
  `availableForHands`, `S.PickBestForSlot` (`modules/Selector.lua:545,344,300`), `applyBackdrop`
  (`modules/MacroBar.lua:183`), `M.setItem` (`tests/wow_mock.lua:154`), `itemCooldown`
  (`core/MacroDisplay.lua:100`). None is a warning; none carries a disposition, correctly, because a
  disposition is a decision about a warned function.
- **Entries with disposition "Accepted": exactly one** — `tests/test_macrobar.lua`. Git history of
  the single `RESULTS.md` path shows it has carried that disposition across **two** consecutive
  runs (`20260804-215640`, `20260804-233147`); it entered the band on `feat/fix-ccn` rather than
  drifting in, and `RESULTS.md:100-102` says so. **Two is under the three-run shelf life**, so
  anti-pattern #53 does **not** fire. It fires at the next release run if the disposition is renewed
  unchanged — worth flagging to whoever cuts 1.6.0.
- The list is short enough to read in one pass, and not every entry reads "accepted" (the warned-
  function table is empty rather than full of renewals). No #53 finding.
- The `RESULTS.md` prose correctly reads the `62 → 0 → 15` Max-CCN column as one real drop plus one
  instrument change, and refuses to hand-correct the row (`:64-71`) — `performance-§10`'s "a
  hand-corrected record reads as measured and is worse than a wrong one". That is a compliance point,
  not a finding.

### A5. Vendored Ka0s-owned library drift — **NOT RUN**

```
$ diff -r ../LibKa0s/LibKa0s  ./libs/LibKa0s        # NOT RUN
$ diff -r ../LibKa0s/testkit  ./tests/_kit          # NOT RUN
```

**Reason:** this session was constrained to `/mnt/d/Profile/Users/Tushar/Documents/GIT/ConsumableMaster`
alone and may not read the sibling repository. The path that would have been used is
`/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` (ship folder `LibKa0s/`, harness `testkit/` at
the repo root beside it). **Both checks are unverified, not passed.**

What *was* verifiable without the sibling — and what it does and does not prove:

```
$ ls libs/LibKa0s
Core.lua  DebugLog.lua  LICENSE  LibKa0s.xml  Options.lua  OptionsScroll.lua
OptionsWidgets.lua  Perf.lua  PerfPanel.lua  Slash.lua

$ cat libs/LibKa0s/LibKa0s.xml
<Ui …>
  <Script file="Core.lua"/>       <Script file="DebugLog.lua"/>
  <Script file="Slash.lua"/>      <Script file="Options.lua"/>
  <Script file="OptionsWidgets.lua"/> <Script file="OptionsScroll.lua"/>
  <Script file="Perf.lua"/>       <Script file="PerfPanel.lua"/>
</Ui>

$ ls tests/_kit
README.md  framework.lua  loader.lua  mock_base.lua  run-automated-tests.sh
```

No shell arrives without its attach file (`Options.lua` + `OptionsWidgets.lua` + `OptionsScroll.lua`;
`Perf.lua` + `PerfPanel.lua`), `Core.lua` is present for the four majors that floor on it, and the
harness is under `tests/`, never `libs/`. That is the shape a whole ship folder has and it rules out
the obvious form of anti-pattern #48 — but a file present at the wrong **content** is exactly the
failure `diff -r` exists to catch and shape cannot. Recorded as unverified.

The addon's own gate for the same question is asleep — see §F, **CM-64**.

### A6. `make test` / other runners

No `Makefile` in the repo (`ls` of root shows none). Not applicable.

---

## B. Layout, TOC, libraries

| Claim | Evidence |
|---|---|
| Modular layout, no loose root source | `find . -type f -name '*.lua'` — every path is under `core/ defaults/ locales/ modules/ settings/ libs/ tests/` |
| Typed `media/` subfolders only | `media/logos/consumemaster.logo.tga`, `media/logos/consumemaster.logo.jpg`, `media/screenshots/kcm-01…07`, `media/fonts/JetBrainsMono-Regular.ttf`, `media/fonts/OFL.txt` — nothing loose in `media/` |
| No addon file over 1000 LOC | `wc -l` — max addon file `settings/Panel.lua` 950; `core/SlashCommands.lua` 836 |
| `tests/test_macrobar.lua` in the band (**CM-54**) | `wc -l tests/test_macrobar.lua` → 1497 |
| TOC metadata in `toc-file-§1` order | `ConsumableMaster.toc:1-16` |
| Two SV globals, mandated order | `ConsumableMaster.toc:11` `## SavedVariables: ConsumableMasterDB, ConsumableMasterPerfDB`, with the rationale comment at `:7-10` |
| `X-Standard` present (reference place 1 of 3) | `ConsumableMaster.toc:15` |
| `LibKa0s.xml` listed once, aggregate, after Ace3 | `ConsumableMaster.toc:35` — preceded by the eight Ace3/LSM lines at `:19-28`; **no individual `libs\LibKa0s\*.lua` line exists anywhere in the file** |
| TOC sections in mandated order | `# Libraries` `:18` → `# Locales` `:37` → `# Core` `:40` → `# Defaults` `:79` → `# Modules` `:96` → `# Settings` `:110` |
| `core/` load order deviates (**CM-49**) | `ConsumableMaster.toc:44-46,49-52` — `core\Namespace.lua`, `core\ConsumableMaster.lua`, `core\Bus.lua`, `core\Constants.lua`, `core\CoreSetup.lua`, `core\Compat.lua`, `core\State.lua` |
| DebugLog setup in `modules/` (**CM-44**) | `ConsumableMaster.toc:100` `modules\DebugLog.lua`; file header `modules/DebugLog.lua:1` |
| PerfSetup in `modules/`, after both bracket sites (**CM-45**) | `ConsumableMaster.toc:104` `modules\PerfSetup.lua` — vs `core\ConsumableMaster.lua` at `:45` and `modules\MacroBar.lua` at `:107`. `MacroBar.lua` loads **after** PerfSetup; `ConsumableMaster.lua` loads 59 lines before it |
| No `settings/OptionsSetup.lua` (**CM-46**) | `ls settings/` → `Category.lua General.lua MacroBar.lua Panel.lua Slash.lua StatPriority.lua`; the seam is at `settings/Panel.lua:186-252` |
| No `defaults/Profile.lua` (**CM-48**) | `ls defaults/` → 14 `Defaults_*.lua` + `Categories.lua` + `README.md`; `KCM.dbDefaults = {` at `core/ConsumableMaster.lua:25`, consumed at `:203`, `:541`, `core/SlashCommands.lua:713` |
| `.pkgmeta` has no `externals:` | `.pkgmeta:1-19` |
| `.pkgmeta` misses three dev-only paths (**CM-56**) | `.pkgmeta:10-18` ignores `docs, tests, .luacheckrc, .pkgmeta, .gitignore, .gitattributes, "*.bak", media/screenshots` — not `.claude/`, `.superpowers/`, `CHANGELOG.md`. `.superpowers/sdd/` alone is 60+ tracked files |

---

## C. Shared-subsystem wiring — the descriptors, and the stubs walked against their call sites

Per `AUDIT.md` step 6, the compliance claim for each subsystem cites the **descriptor**, never the
library's own source. `libs/LibKa0s/*` is not re-audited here; it is audited in its own repo.

### C1. `LibKa0s-Core-1.0` — compliant

- Lookup: `core/CoreSetup.lua:33` `local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)`.
- Descriptor: `:76-91` — `prefix` as a **function** (`:83`, so `KCM.PREFIX` stays live), `sink` as a
  thunk to global `print` (`:90`, which is where the headless harness listens).
- Publication: `:73-74` `KCM.IsConcatSafe = lib.IsConcatSafe` / `SafeToString`; `:99`
  `KCM.Say = printer.Format`.
- Stub: `:35-71`. Members the addon reaches on this seam are `KCM.Say`, `KCM.SafeToString`,
  `KCM.IsConcatSafe` (177 `KCM.Say` sites; `core/SlashCommands.lua` and `settings/Slash.lua:27` take
  it as a file-scope upvalue). **All three answered** (`:44`, `:45`, `:53`), with one honest line
  said once at `:63-67`. Coverage complete.
- The shared cause clause `KCM.LIBKA0S_MISSING` is set **outside** the branch at `:30-31` so both
  paths' readers have it — which is what the other three seams append to.

### C2. `LibKa0s-DebugLog-1.0` — compliant, including its deliberate omission

- Lookup `modules/DebugLog.lua:55`; descriptor `:107-…` (`name`, `title`, eager `font` + `fontSize`).
- Facade published `:181-211` — `AddLine, IsEnabled, Show, Hide, Clear, ShowCopy, RefreshHeader,
  UpdateScrollBar, UpdateStatus, Toggle_Window, IsWindowShown, SetEnabled, Toggle, FormatPlain,
  FormatColored, instance`. The `Toggle` (flag) vs `Toggle_Window` (window) inversion is documented
  at `:12-17` and is why this is a facade rather than an alias table.
- Members the addon reaches, grepped from the call sites:
  `core/Debug.lua:40` (`.instance`), `:` (`IsEnabled`, `SetEnabled`), `settings/General.lua`
  (`Hide`, `SetEnabled`), `settings/Slash.lua:94-104` (`SetEnabled`, `Show`, `Toggle_Window`),
  `modules/PerfSetup.lua:89,91` (`AddLine`, `Show`), `settings/Panel.lua` (`.instance`).
- Stub `:57-104` answers `IsEnabled` (`:72`), `SetEnabled` (`:74`), `Toggle` (`:85`), `Show` (`:92`),
  `Toggle_Window` (`:93`), `Hide` (`:94`), `IsWindowShown` (`:95`).
- **`AddLine` is deliberately withheld**, with the reason written down at `:97-103`: `core/Debug.lua`
  probes for a console and falls back to chat, so withholding the member re-arms the fallback and a
  no-op `AddLine` would swallow every diagnostic. **That is a decision, not a gap, and is not
  flagged.** The comment names the wrong member (`.AddLine` where the probe is `.instance`,
  `core/Debug.lua:40`) — recorded as advisory **CM-66**.
- `modules/PerfSetup.lua:89` calls `KCM.DebugLog.AddLine` — but that file returns at `:36` when
  `LibKa0s-Perf-1.0` is absent, and both majors ship in the same vendored folder, so the call site
  is unreachable in exactly the state where the member is missing. Consistent.

### C3. `LibKa0s-Slash-1.0` — descriptor compliant, stub coverage broken (**CM-65**)

- Lookup `settings/Slash.lua:237`; descriptor `:241-283` — `slash`, `slashAliases`, `commands`
  (passed in, not owned), `aliases`, `version`, thunked `print` (`:254`), `L` overrides, and the
  schema half (`get/set/findRow/allRows/applyDefault/groupKey`) all resolved at **call** time
  (`:260-272`) because `settings/Panel.lua` loads after this file.
- `COMMANDS` is host-owned, ordered, positional triples: `settings/Slash.lua:65-172`, published at
  `:176`. 17 verbs. Reserved set complete and correctly meaning: `help :66`, `config :68`,
  `version :74`, `perf :76`, `debug :86`, `reset` path-scoped `:146`, `resetall :148`, `list :156`,
  `get :158`, `set :160`.
- `perf` registered by the addon, not the library (`:76-85`) — `performance-§4`. ✓
- AceConsole registration, not `SLASH_*`: `core/ConsumableMaster.lua:6` embeds AceConsole;
  `KCM:OnSlashCommand` at `settings/Slash.lua:340` is resolved by name.
- **Stub failure.** `:297-305` binds `printHelp`/`cliList`/`cliGet`/`cliSet`/`cliReset` to one honest
  line, which is correct for the schema CLI. But `:340-343`:

  ```lua
  function KCM:OnSlashCommand(msg)
      if not Sl then return printHelp() end
      return Sl:OnSlash(msg)
  end
  ```

  short-circuits **every** verb, including the eleven that never went to the library
  (`bar :162 → V.RunBar`, `priority :164`, `stat :166`, `aio :168`, `dump :170`, `resync :110`,
  `rewritemacros :127`, `resetall :148`, `config :68`, `version :74`, `debug :86`). `slash-commands-§1`:
  *"The host verbs never went to the library, so they keep working."*
- The user-visible consequence is a contradiction between two seams:
  `settings/Panel.lua:265-269` — *"…so the settings panel is unavailable; every setting is still
  reachable with /cm list, /cm get and /cm set."*
  `settings/Slash.lua:300-303` — *"…so /cm is unavailable."*
  Both reproduced verbatim by the 2026-08-05 review (F-003).

### C4. `LibKa0s-Options-1.0` — descriptor compliant, two runtime members left nil (**CM-58**)

- Lookup `settings/Panel.lua:186`; instance `:193-236` with `mainPanelName` (`:197`, the one field
  the library validates), `parentTitle`, thunked `print` (`:208`), positional `colorDecode`/
  `colorEncode` (`:219-223`), `sliderCommit = "change"` (`:230`), call-time `getLSM` (`:233`), and
  `get`/`set` routed through the addon's **single write seam** (`:235-236` →
  `Helpers.SetAndRefresh`). Instance published for identity assertions at `:250`.
- **The load-completing shape is correct and is NOT flagged.** `options-ui-§1`'s documented
  exception covers members page files touch inside schema-row literals at file load
  (`Helpers.LSMValues`, `settings/Panel.lua:448`), and the addon publishes it real-enough
  (`:448` `UI and UI.LSMValues(mediaType)() or {}`).
- **What is flagged is call-time.** `:571-572`:

  ```lua
  Helpers.RefreshAllPanels = UI and UI.RefreshAllPanels
  Helpers.RefreshScalars   = UI and UI.RefreshScalars
  ```

  With `optionsLib` nil, `UI` is nil (`:187`, assigned only inside `if optionsLib then` at `:192`),
  so both are `nil`. They are then called **bare**:
  - `settings/Panel.lua:643` — inside `Helpers.SetAndRefresh`, *after* the write and `fireOnChange`.
    Reached by `/cm set` (`settings/Slash.lua:261-264`), by every panel widget (`:236`), and by
    `KCM.Schema:Set` (`:648-651`).
  - `settings/Panel.lua:833` — inside `O.Refresh`, reached from the bus receiver at `:940-943`,
    which `core/ConsumableMaster.lua:313` publishes on **every recompute**.

  Reproduced by the 2026-08-05 review as F-001 (`settings/Panel.lua:833: attempt to call field
  'RefreshAllPanels' (a nil value)`) and F-002.
- **Host member is a copy-across, not the instance (CM-36).** `:41-42`
  `local Helpers = KCM.Settings.Helpers or {}; KCM.Settings.Helpers = Helpers` — a plain table. The
  instance is the separate local `UI`. Members copied over: `PatchAlwaysShowScrollbar :245`,
  `EnsureScroll :247`, `AttachTooltip :278-279`, `SetRenderer :351`, `ResetScroll :361`,
  `AddSpacer :383`, `RenderField :458`, `Grid :519`, `CustomCheckbox :527`,
  `RefreshAllPanels`/`RefreshScalars` `:571-572`.
- **Host copies of library layout constants (CM-37).** `:74-75`
  `local SECTION_HEADING_H = 26` and `local BUTTON_PAIR_REL = 0.492`; used at `:507` and `:711`.
  The file's own comment two lines above (`:70-73`) records that the four spacers already moved to
  the library's `LAYOUT` table, which is what makes these two the leftovers.
- Combat-open refusal, canonical gray text, funnelled from both open paths: `:52-58`.

### C5. `LibKa0s-Perf-1.0` — descriptor compliant; brackets and coverage are not

- Lookup `modules/PerfSetup.lua:29`, guarded silent form; `if not lib then return end` at `:36` with
  the reason written at `:31-35` (nothing in the addon reads `KCM.Perf`, so an absent major is an
  absent feature and `/cm perf` says so — `settings/Slash.lua:81-83`).
- Descriptor `:63-102` — `name`, `title`, `slash = "/cm"` (`:71`), `sv = "ConsumableMasterPerfDB"`
  (`:78`), `version`, thunked `log`/`print`/`showLog` (`:89-91`), `suspend`/`resume` (`:44-60`,
  dropping every event and re-registering through `KCM:OnEnable` rather than a copied list), and
  `buckets = { cooldown, recompute }` (`:98-101`).
- `KCM.Perf = P` at `:104` — the instance itself, not a facade, with the reason at `:17-24` (three
  members are plain boolean **fields** the library writes, which a forwarder cannot mirror).
- **Bracket shape (CM-39).** Both sites do the lookup inside the timed function:
  - `core/ConsumableMaster.lua:332-333` `local perf = KCM.Perf` / `local perfT0 = (perf and perf.on) and debugprofilestop() or nil`; note at `:349`.
  - `modules/MacroBar.lua:322-323` same shape; note at `:330`. `MB.RefreshCooldowns` is the
    near-frame path (`:317-319` says so itself).
  Mandated form is a file-scope `local Perf = NS.Perf` (`performance-§2`, anti-pattern #43).
- **Bucket coverage (CM-40).** `tests/test_perfsetup.lua:141-144` is the whole of it:
  `local buckets = KCM.Perf.__buckets()` … `t.eq(n, 0, "no bucket accrued with the harness idle")`.
  Nothing drives either declared bucket.
- **Zero-overhead scenario (CM-38).** `ls tests/perf.lua` → does not exist. Every manifest records
  `"perf": { "status": "skip", "skipReason": "no tests/perf.lua — this addon ships no offline
  scenarios" }` (`docs/automated-tests/20260804-233147/manifest.json`), and
  `docs/automated-tests/RESULTS.md:45-56` states the consequence plainly and correctly.
- **`.luacheckrc` (CM-41).** `globals` at `:30-34` is `ConsumableMasterDB, StaticPopupDialogs,
  UISpecialFrames`. `ConsumableMasterPerfDB` absent. `debugprofilestop` **is** in `read_globals`
  (`.luacheckrc:43-45`), which is the other half of `performance-§2` and is satisfied.

---

## D. Architecture, bus, SavedVariables

| Claim | Evidence |
|---|---|
| Private `NS`, no global namespace | `core/Namespace.lua:6`; no `_G[addonName] =` anywhere (`grep`) |
| AceAddon promotion | `core/ConsumableMaster.lua:6` `LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceConsole-3.0")` |
| AceConsole `:Print` clobber not applicable (anti-pattern #36) | `core/CoreSetup.lua:17-20` — the printer is named `Say`, and the file records why there is no same-named clobber to reclaim |
| Closed bus, per-receiver targets (anti-pattern #32) | `core/Bus.lua:31` `KCM.NewBusTarget`; `settings/Panel.lua:934-948` registers PANEL_REFRESH and SPEC_CHANGED on one dedicated `optionsTarget`, each on its own `RegisterMessage` |
| AceDB + `schemaVersion` + migration runner | `core/ConsumableMaster.lua:203`; `:34` `schemaVersion = 1`; `core/Database.lua:45-56` |
| Perf ring outside the AceDB tree | `modules/PerfSetup.lua:73-78` and the TOC comment `ConsumableMaster.toc:7-10` |
| No third top-level SV global | `ConsumableMaster.toc:11` declares exactly two |
| `savedvariables-§5` / #54 clean | `grep -rnE '^\s*[a-zA-Z_.]+\.[a-zA-Z_]+\s*=\s*[a-zA-Z_.]+\.[a-zA-Z_]+\s+or\s+'` over `core/ modules/ settings/` returns only namespace-table initializers (`KCM.Database = KCM.Database or {}`) and container guards (`profile.macroBar = profile.macroBar or {}`, `cfg.enabled = cfg.enabled or {}`) — no stored scalar defaulted with `or` |

---

## E. Compat (**CM-63**)

`core/Compat.lua` is 83 lines and exposes six functions:

```
core/Compat.lua:17  Compat.GetSpecialization
core/Compat.lua:26  Compat.GetSpecializationInfo
core/Compat.lua:36  Compat.GetNumSpecializationsForClassID
core/Compat.lua:45  Compat.GetSpecializationInfoForClassID
core/Compat.lua:60  Compat.IsSecret
core/Compat.lua:68  Compat.GetSpellName
```

Direct calls to the legacy item globals, outside `Compat`:

| Site | Call | Guarded? |
|---|---|---|
| `core/TooltipCache.lua:459` | `local name, _, _, _, minLevel = GetItemInfo(itemID)` | **no** |
| `modules/Ranker.lua:88` | `local _, _, quality, ilvl, _, _, subType = GetItemInfo(itemID)` | **no** — and no `C_Item` preference at all |
| `core/Classifier.lua:169` | `GetItemInfo(itemID)` | yes — fallback after `C_Item.GetItemInfoInstant` at `:165-166` |
| `core/WeaponSlots.lua:36` | `GetItemInfo(itemID)` | yes — same shape, `:33-34` |
| `modules/KCMItemRow.lua:88-89, 131-132` | `_G.GetItemInfo(itemID)` | yes — `if _G.GetItemInfo then` |
| `modules/KCMItemRow.lua:216` | `_G.GetItemCount(self.itemID)` | yes |
| `core/MacroDisplay.lua:74, 101` | `(C_Item and C_Item.GetItemCount) or GetItemCount` / `GetItemCooldown` | yes — inline preference ladder |

`compat`: *"MUST route every deprecated-API call through `Compat`. Direct calls … scattered through
feature modules are a violation."* The addon's own lint config already asserts the opposite of what
the code does — `.luacheckrc:74` reads `-- Spell / item (legacy globals wrapped by core/Compat.lua)`
above the `GetItemInfo`/`GetItemCount` entries.

The two unguarded sites are the sharper half: `core/TooltipCache.lua:459` is the one the 2026-08-05
review logged as F-010, and it sits in a file whose siblings (`core/Classifier.lua:165-169`,
`core/WeaponSlots.lua:33-36`, `modules/KCMItemRow.lua:88-89`) all guard.

---

## F. Tests

| Claim | Evidence |
|---|---|
| Kit vendored to the right place | `ls tests/_kit` → `README.md framework.lua loader.lua mock_base.lua run-automated-tests.sh`; nothing kit-shaped under `libs/` |
| **Kit is not loaded (CM-34)** | `tests/run.lua:21` `local h = require("harness")`; `tests/harness.lua:1` "headless test framework shared by every suite"; `tests/harness.lua:19` `H.loader = require("loader")`. No `dofile` of `tests/_kit/framework.lua` or `loader.lua` anywhere in `tests/` except the sync test |
| `wow_mock.lua` is a replacement, not an extender | `wc -l tests/wow_mock.lua` → 623; `tests/wow_mock.lua:1-25` describes a full standalone environment builder; no `dofile("tests/_kit/mock_base.lua")` in the file. `tests/_kit/mock_base.lua` is 537 LOC and unreferenced |
| The fork has already been hand-patched back once | `tests/harness.lua:125-133` — "tests/_kit/framework.lua's own renderer carries the same note; this one had drifted from it" |
| **Hand-maintained load list (CM-35)** | `tests/loader.lua:79-113` `L.PURE_LAYER = { … }`, 33 entries, hand-written paths including `"core/CoreSetup.lua"`, `"defaults/Defaults_BattleRez.lua"`, `"core/MacroDisplay.lua"` |
| Inventory is generated and in lockstep | `docs/test-cases.md` regenerated by `lua tests/run.lua --list` (`tests/run.lua:8-10, 57-59`); fresh `--list` count matches the 656 in the README badge and the newest bundle |
| **Vendor-sync gate goes quiet (CM-64)** | `tests/test_vendor_sync.lua:141` and `:147` — `local tag = siblingTag(); if not tag then return end`. `siblingTag` (`:106-118`) returns nil when `gitShow("HEAD:LibKa0s/Core.lua")` fails, i.e. exactly when the sibling is absent. Both cases print PASS. The header at `:108-110` claims the skip "is said in the case name"; neither case name at `:140` or `:146` mentions it |
| **Vendor-sync gate normalizes line endings (CM-64)** | `tests/test_vendor_sync.lua:135` `t.eq((here or ""):gsub("\r\n", "\n"), blob, …)` vs `testing-§11`: "MUST compare raw bytes, read in binary mode, with no line-ending normalization" |

Both cases did in fact PASS in run A2 above, with the sibling absent — which is the finding.

---

## G. Documentation

### G1. Root doc set (`documentation-§1/§2/§7`)

```
$ ls *.md ; ls LICENSE
CHANGELOG.md  CLAUDE.md  DEPENDENCIES.md  README.md   LICENSE
```

`documentation` line 5: *"Root of the repo ships exactly three docs plus `LICENSE`, and never a
fourth doc."* `CHANGELOG.md` (2885 bytes) is the fourth — **CM-59**. Its content overlaps
`README.md:287` `## Version History`, which is where the standard puts it.

### G2. README

| Item | Evidence |
|---|---|
| H1 `# Ka0s Consumable Master` | `README.md:1` |
| Five badges, exact order and templates | `:3` WoW `Midnight_12.0.7` · `:4` CurseForge `v/1522944` · `:5` License MIT orange · `:6` **Standard, underscore-spaced, linked** · `:7` Tests `656%2F656_passing` green |
| `[wow]` badge tracks the TOC | `README.md:3` `Midnight_12.0.7` ↔ `ConsumableMaster.toc:1` `## Interface: 120007` |
| `[tests]` badge tracks the inventory | `README.md:7` `656` ↔ A2's 656 ↔ `docs/test-cases.md` |
| Logo | `:9` |
| `## What's new in 1.5.0` names the current version, above Screenshots | `:37`, `:45` |
| Required sections, required relative order | `:1, :3-7, :9, :11(desc), :37, :45, :75, :223, :241, :258, :283, :287` |
| Extra section (**CM-55**) | `:275` `## Credits and bundled libraries`, between Troubleshooting `:258` and Issues `:283`. Load-bearing: `:277` `Bundles [LibKa0s](…) v1.7.0 (MIT).` is what `tests/test_vendor_sync.lua:100-103` parses |
| No angle-bracket placeholders in shipped content | `grep -n '<[a-z]*>' README.md` returns only real HTML (`<code>`, `<strong>`, `<br>`) |

### G3. `CLAUDE.md`

| Item | Evidence |
|---|---|
| **H1 wrong (CM-50)** | `CLAUDE.md:1` `# CLAUDE.md` — `documentation-§2` item 1 pins `# CLAUDE.md — Ka0s <Name>` |
| Adherence line | `:3` |
| `## Standards compliance (read first)` verbatim in substance (**reference place 3 of 3**) | `:5-15` — names the standard + URL, "stop and flag it to the user", "Never silently diverge", and the two classifications (tracked deviation / change to the standard) |
| Docs pointer list | `:48-60` — `docs/ARCHITECTURE.md`, `docs/testing.md`, `DEPENDENCIES.md`, then topic detail |
| No `docs/agent-context.md` pointer; explicitly forbids one | `:17-32`; `ls docs/` confirms no such file — anti-pattern #49 clear |
| Green-gate line | `:62-70` |
| **Release-gate wording stale (CM-61)** | `:72-76` — "It is a **report, not a gate**: never block a commit on it" |

### G4. `docs/` canonical trio and the five required topic-detail docs

```
$ ls docs
ARCHITECTURE.md  audits  automated-tests  common-tasks.md  data-model.md  debug.md
file-index.md  macro-bar.md  macro-manager.md  midnight-quirks.md  module-map.md
pending  pipeline.md  reviews  scope.md  smoke-tests.md  superpowers  test-cases.md  testing.md
```

- Trio: `ARCHITECTURE.md` ✓ `testing.md` ✓ `smoke-tests.md` ✓
- **`docs/complexity.md`: absent.** The v2.19.0 retirement is complete, and `docs/testing.md:164-165`
  records it (*"was this addon's standalone complexity report through standard v2.18.0; it is
  **retired**"*). No finding.
- Five required topic-detail docs: `test-cases.md` ✓ · **`performance.md` ✗ (CM-42)** ·
  **`perf-runs/README.md` ✗ (CM-43)** · `automated-tests/README.md` ✓ ·
  `automated-tests/RESULTS.md` ✓
- `docs/automated-tests/README.md:42-45` already documents the `perf-runs/` gap in prose: *"That
  directory **does not exist in this** …"*
- No `TODO.md` anywhere ✓. `docs/pending/LEDGER.md` is the second-backlog advisory **CM-57**.

### G5. `docs/ARCHITECTURE.md` section coverage (**CM-60**)

`documentation-§3` mandates: Overview, Module Map, Settings Schema, Message Bus, Slash Commands
(table from `NS.COMMANDS`), Event Subscriptions, Taint Notes, Known Limitations.

```
$ grep -n '^#\{1,3\} ' docs/ARCHITECTURE.md
1:# Architecture            5:## What it does           11:## Namespace & promotion
16:## Layout                28:## Subsystems at a glance 72:## Message-bus catalog
85:## Invariants worth not breaking                     104:## Timers
110:## External dependencies 128:### LibKa0s adoption    166:## Load order
179:## Repository
```

Present: Overview (`:5`), Module Map (`:16` + `:28`), Message Bus (`:72`).
**Missing as sections:** Settings Schema, Slash Commands, Event Subscriptions, Taint Notes, Known
Limitations. Taint appears only as one bullet inside Invariants (`:87`, "must all stay pure (no
protected APIs) so the pipeline can run in combat without taint") plus a cross-reference at `:92`;
there is no event-subscription table anywhere in the file, and no `NS.COMMANDS` table (the file
points at `settings/Slash.lua` instead, `:20` and `:139`).

### G6. The three-place standards reference — all three present

1. `ConsumableMaster.toc:15` `## X-Standard: https://github.com/tusharsaxena/WowAddonStandards`
2. `README.md:6` `[![Standard](…/Ka0s-WoW_Addon_Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)`
3. `CLAUDE.md:5` `## Standards compliance (read first)`

**Anti-pattern #34 does not apply.** No fourth place is claimed (`docs/agent-context.md` absent).

### G7. Commit gate vs release gate (**CM-61**)

The rule, `automated-tests-§3` *The release gate*: **MUST NOT** cut a release unless the release run's
`manifest.json` shows all four suites at `pass` **and** `suites.complexity.warnings == 0`; a `skip`
is a gate that did **not** pass; the one narrow exception is `perf` skipped because the addon ships
no `tests/perf.lua`, which **MUST** be stated in the release notes. The runner's exit code is
unchanged and the gate is evaluated by the release command.

What the repo says today:

| File:line | Text | Verdict |
|---|---|---|
| `docs/testing.md:141-146` | table: `perf` "no — recorded only", `complexity` "no — recorded only" | correct about a **run**; silent about the tag |
| `docs/testing.md:148-150` | "**`perf` and `complexity` never fail a run.** … a threshold that fails a run teaches everyone to reach for `--no-verify`" | correct, verbatim from the standard |
| `docs/testing.md:156-157` | "**At release, not at commit.** A full bundle is produced as part of every version bump, before the tag… Commits are gated on lint + tests only." | correct as far as it goes — but stops at "produce a bundle" and never says the tag is **gated** on it |
| `docs/automated-tests/README.md:19-33` | same table, same "never used to fail a run" | same gap |
| `CLAUDE.md:74-76` | "It is a **report, not a gate**: never block a commit on it" | the second clause is right; the first is now wrong at the tag |
| `docs/automated-tests/RESULTS.md:9-11` | "**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** … A `skip` is a suite that did not run at all, which is never the same as a pass." | **correct as written** — it is scoped to a run, and it even carries the skip-is-not-a-pass rule. Generated file; no edit needed |

The addon is in the situation the exception exists for: `perf` is a permanent skip because it ships
no `tests/perf.lua` (CM-38), so once CM-61's wording lands, a 1.6.0 release note must state that
explicitly rather than let the skip read as a pass.

### G8. `automated-tests` artifact audit

| Requirement | Evidence |
|---|---|
| Runner vendored, not per-addon | `tests/_kit/run-automated-tests.sh` (23340 bytes), inside the vendored kit |
| **Runner executable** | `git ls-files -s tests/_kit/run-automated-tests.sh` → `100644 30da7c07… 0` — **not executable (CM-62)** |
| `.gitattributes` carries `*.sh text eol=lf` | `.gitattributes:36` (with the `bash\r` rationale at `:30-35`, naming this exact file) |
| `docs/automated-tests/README.md` exists | ✓ |
| `docs/automated-tests/RESULTS.md` exists, one path, overwritten | ✓ `:3-4` carries the "OVERWRITTEN IN PLACE" marker; three rows at `:15-17` |
| Bundles frozen, not pruned, one dir per run | `20260804-182045`, `20260804-215640`, `20260804-233147`, each with `manifest.json ANALYSIS.md lint.txt tests.txt test-cases.md complexity.txt` |
| Local-time stamps with UTC offset in the manifest | `"startedAt": "2026-08-04T23:31:47+05:30"` |
| `RESULTS.md` carries per-suite standing sections | `## Test suite :22`, `## Lint :33`, `## Perf :45`, `## Complexity watch list :58` — all four |
| Watch list is two tables, band as a column | `### Functions lizard warned on :73` (prose "None." + the seven at the ceiling named) and `### Files by layout-§1 band :94` with a **Band** column |
| Retired `docs/complexity.md` present? | **No** — correctly deleted |

---

## H. Miscellaneous section checks

| Section | Finding | Evidence |
|---|---|---|
| `localization` | Clean; `locales/enUS.lua` with metatable fallback. No British spelling in authored source or `docs/` — `grep -rniE '(colour\|grey\|behaviour\|centre\|cancelled\|initialise\|organis\|normalis\|recognis)'` over `core defaults modules settings locales docs/*.md *.md` returns one hit, `CHANGELOG.md:19`, which *describes* a past US-English sweep | anti-pattern #46 clear |
| `localization-§4` | **CM-30** — English tooltip parsing | `core/TooltipCache.lua` (heal/mana/stat magnitudes, duration tokens, max-level caps, `Augment Rune`); documented at `docs/scope.md:20` and `README.md:15` |
| `lint` | `.luacheckrc` present, `std = "lua51"` `:8`, correct `exclude_files` `:11-16`; `ignore = { "212", "542", "241" }` `:23` broader than the template (**CM-52**), with the reasons at `:19-22` | |
| `versioning-git` | semver `1.5.0` consistent — `ConsumableMaster.toc:5`, `README.md:37` `## What's new in 1.5.0`, `README.md:287` top row, `docs/automated-tests/*/manifest.json` `"addonVersion": "1.5.0"`. Trunk-based history | |
| `public-api` | Nothing exported (`grep '_G\[addonName\]'` → none); N/A | |
| `standalone-windows` | The debug console and perf step panel are the library's; the addon ships no data-browser window; N/A | |
| `preview-mode` | No explicit preview verb or unlock-time placeholder (**CM-67**, MAY) | `grep -n 'preview\|"test"' settings/Slash.lua` → no such verb in `COMMANDS` |
| `events-frames-taint` | Clean. `modules/MacroManager.lua` is the sole caller of `CreateMacro`/`EditMacro`/`DeleteMacro` (`docs/ARCHITECTURE.md:87` states the invariant; `grep` confirms it); secrets route through `Compat.IsSecret` (`core/Compat.lua:60`) and `KCM.SafeToString`; combat-conditional bar visibility uses `RegisterStateDriver` (`.luacheckrc:100-102` declares it, `modules/MacroBar*.lua` uses it) | |
| `architecture` | Clean apart from the load-order row already filed as CM-49 | see §D |
| `packaging` | `.pkgmeta` correct except the three unignored dev paths (**CM-56**) | `.pkgmeta:10-18` |
| `audit-review-history` | Compliant — `docs/audits/2026-07-12/`, `2026-07-18/`, `2026-08-04/` and `docs/reviews/2026-05-02/`, `2026-08-03/`, `2026-08-05/` all retained, none edited; this run writes a **new** dated folder | |
