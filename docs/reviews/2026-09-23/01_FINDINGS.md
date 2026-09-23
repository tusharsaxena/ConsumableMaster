# 01 — Findings

**Review date:** 2026-09-23 · **Addon:** Ka0s Consumable Master v1.6.2 (TOC `## Version: 1.6.2`, 108 commits past `1.6.2-release`) · **HEAD:** `7adfea1` on `feat/2026-09-23-review-audit-remediation`
**Standard resolved:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. The index was fetched verbatim with
`curl -fsSL https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
(its first line reads `# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)`). Fetching the section files over the network
was slow, so they were read from the sibling checkout `../WowAddonStandards` at `e68795f` (`origin/master`), which carries the
same v2.64.0 index. The sections this review leans on are `anti-patterns`, `slash-commands` (§2, §5, §7), `savedvariables`
(§2), `events-frames-taint` (§2, §4), `options-ui` (§1, §12), `testing` (§9, §12, §13), `performance` (§2, §6, §10) and
`architecture` (§5).

---

## Verdict

**There is one blocking issue.** Every suite that runs outside the game passes. The vendored payload is byte-identical to its source, and the
collection-wide collision checks are clean. There is still one real functional bug on a documented path, **F-001**: a
weapon-enchant macro that was deferred in combat gets rewritten after combat as the wrong macro. Three Medium defects
cluster around the new disabled/stand-down machinery and the single write seam.

---

## Measurement run (Step 0 — all re-run today, 2026-09-23)

All commands were run from the repo root. `ka0s-bounded` is not on `PATH` in this shell, but it exists at
`~/.claude/wow-addon/bin/ka0s-bounded`, and **every run below went through it by full path**. No run exited 124 or 137.
Fresh output was written to a scratch directory outside the repo, and no committed artifact was touched.

| Suite | Command | Result |
|---|---|---|
| **luacheck** | `ka0s-bounded luacheck .` | **PASS**: `Total: 0 warnings / 0 errors in 116 files` |
| **Headless tests** | `ka0s-bounded lua5.1 tests/run.lua` | **PASS**: `998 passed, 0 failed, 0 skipped, 998 total` |
| **`--list` inventory** | `ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/test-cases.md` | **PASS**: 1219 lines. `diff` against `docs/test-cases.md` is **empty** |
| **Offline perf** | `ka0s-bounded lua5.1 tests/perf.lua` | **RAN**: 5 scenarios, exit 0, no assertion failures (figures below) |
| **Complexity** | `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **PASS**: `No thresholds exceeded`. 23258 NLOC, 2499 functions, avg CCN 2.6, **max CCN 15** (one function) |
| **Makefile `test:`** | none | **SKIPPED**: there is no root `Makefile` |
| **Vendor sync: LibKa0s** | `diff -rq libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **PASS**: empty. The sibling is at `v1.55.0-3-g46ccaa6`, and `CLAUDE.md:61` pins `v1.55.0` |
| **Vendor sync: testkit** | `diff -rq tests/_kit/ ../LibKa0s/testkit/` | **PASS**: empty |
| **Cross-addon (4 classes)** | the four commands in the agent brief, run from the sibling directory | **PASS**: clean, with uniform drift from the recorded baseline (see below) |

**Scope of each count.**
- The lint count covers the whole tree minus `.luacheckrc`'s `exclude_files` (`libs/`, `docs/audits/`, `docs/reviews/`,
  `tests/_kit/`). That gives 116 files, `tests/` included.
- `lizard` and the LOC census use the default census scope:
  `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, which is **116 tracked authored Lua files**, `tests/` in.
- Band census under that scope, `… | xargs -0 wc -l | awk '$1>1000'`: **8 files in 1000–1500**
  (`tests/test_macrobar.lua` 1425, `tests/test_slash.lua` 1322, `settings/Panel.lua` 1312, `tests/test_settingsui.lua` 1259,
  `settings/MacroBar.lua` 1166, `settings/Category.lua` 1141, `tests/test_schema.lua` 1023, `tests/test_selector.lua` 1011),
  and **0 over 1500**.

**Offline perf, today's numbers** (for orientation only: one run on one machine):

```
scenario                  iters      ms/iter     total ms   bytes/iter
recompute                   200      1.02738      205.477       2551.1
cooldownRefresh             200      0.02136        4.273       6000.0
probeOverheadOff            200      0.01997        3.995       6000.0
probeOverheadOn             200      0.02210        4.419       6001.3
refreshBurst                200      0.01834        3.667          0.0
```

- The zero-overhead property holds. The dormant arm allocates 6000.0 bytes/iter, identical to `cooldownRefresh` and under
  the 6144 ceiling `tests/perf.lua:182` pins.
- Both declared buckets (`cooldown`, `recompute`; `core/PerfSetup.lua:133-136`) are reached by gated brackets:
  `modules/MacroBar.lua:408/415` and `core/ConsumableMaster.lua:212/228`.
- `tests/perf.lua:68` derives its load list from the TOC (`Loader.loadAll(Loader.tocFiles("ConsumableMaster.toc"), …)`), and it
  makes no wall-clock assertion.

**Cross-addon pass.** Run from `/mnt/d/Profile/Users/Tushar/Documents/GIT` over the **ten** Ka0s addons: the nine in the brief
plus AuraMaster, which the current roster includes. Each count is scoped to that addon's TOC-derived load list.

| Class | Result today | Against the 2026-09-07 baseline |
|---|---|---|
| Slash tokens | 20 roots across 10 addons, `uniq -d` empty, and zero raw `SLASH_*` in loaded source | +2 roots (`am`, `auramaster`) because AuraMaster was added. No collision |
| Vendored minors | **one line**, agreed by all ten: `Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9` | Uniform movement: five new majors, and Options/Perf/Slash bumped. No split |
| Payload bytes | `diff -rq ConsumableMaster/libs/LibKa0s <each>/libs/LibKa0s` gives **0 lines for all ten** (146 files, reference = ConsumableMaster) | Improved. PrettyChat's two CR stragglers are gone |
| `## Interface:` | `120100`, uniform across all ten | Uniform movement (120007 → 120100) |

That makes it a **measured non-finding**. The baseline table in the agent brief is out of date, but the departure is the same in
every repo and does not open a gap between any two.

### Committed artifacts that disagree with today's run

- **`docs/automated-tests/RESULTS.md`** is stale. Its newest row `20260916-184427` (git `da0b0f8`, manifest `startedAt 2026-09-16T18:44:27+05:30`)
  records **928** tests, **114** lint files, 22707 NLOC / 2396 functions, and **eight functions at exactly CCN 15**. Today's run
  shows **998** tests, **116** files, 23258 NLOC / 2499 functions, and **one** function at CCN 15:
  `KCM:OnRegenEnabled` (`core/ConsumableMaster.lua:623-657`). That function is **not on the committed watch list**, and the
  eight that are listed have all dropped below the ceiling. The band table's LOC has also moved:
  - `settings/Category.lua` 1400 → 1141
  - `settings/Panel.lua` 1488 → 1312
  - `tests/test_slash.lua` 1249 → 1322
  - `tests/test_macrobar.lua` 1456 → 1425
  - `tests/test_settingsui.lua` 1255 → 1259

  This is stale, not non-compliant. The record is regenerated at release.
- **`docs/test-cases.md`** agrees with the fresh `--list`. The README `[Tests]` badge reads `998/998`, which also agrees.
- **`docs/performance.md`**: the one figure it pins (6000.0 dormant bytes/iter against the 6144 ceiling, `:133`) matches today.

In-client checks are deliberately absent here. They live in `03_SMOKE_TESTS.md`.

### Convention sweep (what exists, so nothing is flagged that isn't used)

- **Chat prefix:** `KCM.PREFIX` (`core/Constants.lua:18`). The printer is `KCM.Say` (`core/CoreSetup.lua:169`). There is no stray
  `print(` in loaded source outside the degraded arm and macro bodies.
- **COMMANDS table:** `settings/Slash.lua:143-268`, dispatched by LibKa0s-Slash.
- **Single write path:** `Helpers.Set` → `Helpers.SetAndRefresh` / `KCM.Schema:Set` (`settings/Panel.lua:321`, `:974`, `:1069`).
- **Schema:** a flat-row schema in `KCM.Settings.Schema`, with rows declared by the page files.
- **Secret-values doc:** none (`docs/CLAUDE_SECRET_VALUES.md` is absent). `KCM.SafeToString` / `KCM.IsConcatSafe` exist.
- **Line endings:** `.gitattributes` carries `* text=auto eol=crlf`, `*.sh text eol=lf`, `*.py text eol=lf` and the binary list.
  `git ls-files --eol` shows 437 `w/crlf`, 131 `w/-text`, 1 `w/lf` (`tests/_kit/run-automated-tests.sh`, which is correct) and
  1 `w/none` (a single-line `dump.json`). The working tree agrees with the pin. This is an observation only; the audit owns it.
- **Marks:** the debug console and the perf panel get the library's close mark (`KCM.MakeCloseButton`, `core/CoreSetup.lua:186`).
  The drag handle's help mark comes from `KCM.Icon("help")`. No private copy of shipped media was found.
- **LibKa0s majors wired**, one setup file each: Lifecycle (`core/LifecycleSetup.lua`), Perf (`core/PerfSetup.lua`), Media
  (`core/MediaSetup.lua`), Bus (`core/Bus.lua`), Core (`core/CoreSetup.lua`), Env (`core/EnvSetup.lua`), Item
  (`core/ItemSetup.lua`), Launcher (`core/LauncherSetup.lua`), DebugLog (`core/DebugLogSetup.lua`), Options
  (`settings/OptionsSetup.lua`), Slash (`settings/Slash.lua`) and Widgets (`modules/MacroBar.lua:44`).
  - I checked each degradation stub against its call sites. The DebugLog stub omits `AddLine`, `Clear`, `ShowCopy` and the other
    window members, but the only host caller of `AddLine` is `core/PerfSetup.lua:122`, and Perf is absent on the same degraded
    payload. The Bus stub carries `NewTarget`/`StandDown`/`StandUp`/`Catalog`. No stub gap was found.
- **Test kit:** `tests/_kit/` is vendored and byte-identical to `../LibKa0s/testkit/`.

---

## High

### F-001 — A weapon-enchant macro deferred in combat is flushed as the wrong macro `[bug]` `[combat]`

- **Where:**
  - `modules/MacroManager.lua:531`: `return commitMacro(cat.macroName, body, iconItemID, cat.key)`, called with no `opts`.
  - `modules/MacroManager.lua:418`: `cat      = opts.cat,`, which stays nil for a per-hand entry.
  - `modules/MacroManager.lua:598-602`: `if entry.cat and entry.cat.composite then … else ok, result = pcall(M.SetMacro, name, entry.itemID, entry.catKey) end`
- **Problem:** A per-hand (`WPN_ENCH`) write that is queued in combat stores only `itemID = mhPick or ohPick`. On
  `PLAYER_REGEN_ENABLED`, `FlushPending` sends it through `M.SetMacro`, which rebuilds a **single-item** body.
- **Impact:** After combat the account-wide `KCM_WPN_ENCH` macro is rewritten as `#showtooltip\n/use item:<oil>`. The `/use 16`
  / `/use 17` slot targeting is gone and so is the off-hand line. Clicking the macro puts the oil on the cursor instead of applying
  it. The fingerprint stores the wrong body, so nothing corrects it until some later bag, equipment or spec event happens to
  trigger a recompute. `KCM:OnRegenEnabled` requests none.
- **Reproduced headlessly** with a scratch probe run through the addon's own harness. The probe was outside the repo and nothing
  was committed.
  - Out of combat: `#showtooltip / /use item:944001 / /use 16 / /use item:944002 / /use 17`.
  - Deferred in combat, then `FlushPending()`: `#showtooltip / /use item:944003`.
- **Reachability:** Any player whose weapon-enchant pick changes during combat reaches this. The most direct route is typing the
  documented `/cm rewritemacros` in combat. `settings/Slash.lua:210-222` explicitly allows it in combat ("macro writes will apply
  when combat ends"), and it clears every fingerprint, so `WPN_ENCH` is always deferred. Other routes are a weapon swap
  mid-fight (`PLAYER_EQUIPMENT_CHANGED` for slot 16/17) and looting or using up the ranked oil mid-fight.
- **Coverage:** The inventory claims `MacroManager.FlushPending applies a deferred write once combat ends`
  (`tests/test_macromanager.lua:330`), but that case covers `KCM_FOOD` only. No case flushes a per-hand entry. This is a
  coverage gap, not a case that is asleep.
- **Fix direction:** Make the flush replay what was queued, through the existing one write tail. Do not add a second
  macro-writing path, because `events-frames-taint-§4` requires the MacroManager firewall to stay the sole caller.

---

## Medium

### F-002 — Resetting a color to its default stores the shipped defaults table itself; a later profile switch empties it `[savedvariables]` `[design]`

- **Where:**
  - `settings/Panel.lua:920-923`: `color = function(_, value) if type(value) ~= "table" then … end return value end`.
    This is the only table validator that does **not** copy. The `order` and `map` arms do copy, and `:929` says why: a row's
    `default` "IS the dbDefaults table".
  - The composer sets `row.default = defaults[leaf]`, which is a reference (`libs/LibKa0s/OptionsCompose.lua:171`).
  - `Helpers.Set` stores the value as given (`settings/Panel.lua:321-335`).
- **Problem:** `/cm reset macroBar.barBackdropColor` (through `applyDefault`, `settings/Slash.lua:530-533`) writes
  `KCM.dbDefaults.profile.macroBar.barBackdropColor` **by reference** into the live profile. A scratch probe confirms it:
  `stored IS dbDefaults table = true`.
  - Real AceDB's `SetProfile` then runs `removeDefaults(oldProfile, defaults)` (`libs/AceDB-3.0/AceDB-3.0.lua:462`).
  - With `db[k]` and `defaults[k]` being the same table, `removeDefaults` nils every channel of the **shipped default**.
- **Impact:** For the rest of the session every profile switched to gets `{}` for that color.
  - The panel swatch decodes it as opaque black (`Helpers.ColorDecode` → `0,0,0,1`).
  - `/cm get` reports the library's fallbacks.
  - A later reset writes `{}` again.
  - It corrects itself at the next login, because the empty table is stripped on logout.
- **Reproduced with the real vendored AceDB** in a scratch script outside the repo. After `SetProfile`, the defaults color had
  **0** entries and so did the incoming profile's.
- **Reachability:** Any player who resets a color row by path with the documented `/cm reset <path>` and then switches profile on
  the Profiles page in the same session. The Macro Bar page's **Defaults** button is *not* affected, because it `CopyTable`s
  (`settings/MacroBar.lua:647`).
- **Coverage:** The suite cannot see this. See F-006.
- **Fix direction:** Copy in the color validator, the same way its `order` and `map` siblings already do (`savedvariables-§2`:
  the defaults tree is the one declaration and must never be mutated).

### F-003 — A settings category parked in combat is never registered while the addon is disabled `[ux]` `[disabled-state]`

- **Where:**
  - `settings/Panel.lua:1267-1269` parks the registration under lockdown (`KCM.Settings.registerPending = true`).
  - The only replay is at the **end** of `KCM:OnRegenEnabled` (`core/ConsumableMaster.lua:654-656`).
  - The stood-down branch returns before the replay (`:631-635`): `if KCM.IsStoodDown and KCM.IsStoodDown() then … self:UnregisterEvent("PLAYER_REGEN_ENABLED") return end`.
- **Problem:** A disabled addon that logs in or `/reload`s in combat gets through the whole sequence and never registers the
  category:
  - its `OnInitialize` stand-down registers `PLAYER_REGEN_ENABLED` (`core/LifecycleSetup.lua:98-100`);
  - the category is parked;
  - regen fires, and the stood-down branch drops the event without replaying.
- **Impact:** The addon is missing from Settings → AddOns for the whole session. `/cm` answers "settings panel unavailable on
  this client". `slash-commands-§7` ("What MUST survive") names the settings-category registration as **setup** that stays up
  while disabled. It is also the route a player not at a chat prompt uses to turn the addon back on.
  - A scratch probe confirms it: `stood down: true / parked: true / replays on regen while disabled: 0`.
- **Reachability:** Any player with the addon disabled who logs in or `/reload`s while in combat, or who types `/cm disable` in
  combat after an in-combat reload has parked the category. `/cm enable` recovers the panel at the next regen.
- **Severity note:** Medium rather than High. The trigger is narrow (an in-combat login or reload), and it recovers after
  `/cm enable`.
- **Coverage:** `tests/test_settingsui_optionsui.lua:777-797` pins the replay for an **enabled** addon only.
- **Fix direction:** Make the replay run on both branches. `core/ConsumableMaster.lua:623-657` is already at CCN 15, the release
  gate's cap, so the fix must **extract** the replay into a named helper and must not add a branch in place
  (`performance-§11`, anti-pattern #52).

### F-004 — The settings panel opened while disabled can no longer hydrate its item rows, and the comment says it can `[ux]` `[disabled-state]`

- **Where:**
  - `core/ConsumableMaster.lua:213-218`: "The panel refresh below still runs so that opening the panel while the addon is off
    hydrates priority-list rows from item-info events (otherwise rows whose data hadn't loaded sit on `[Loading]` until
    re-enable)". It also cites "the toggle's onChange in settings/Panel.lua", which no longer exists.
  - The stand-down unregisters `GET_ITEM_INFO_RECEIVED` (`core/LifecycleSetup.lua:92`) and drops the options target's
    `PANEL_REFRESH` subscription (a tracked bus target, `settings/OptionsShim.lua:263-264`).
- **Problem:** Row hydration's only trigger is `GET_ITEM_INFO_RECEIVED` → `PANEL_REFRESH` (`core/ConsumableMaster.lua:659-678`).
  While disabled there is neither, so rows opened in a fresh session sit on `[Loading]` (`modules/KCMItemRow.lua:84-99`) until
  something re-renders the page.
- **Impact:** The panel, which the standard keeps live while disabled, shows unnamed rows. The code comment documents the
  opposite behavior, which is the one the stand-down removed.
- **Reachability:** Any player who disables the addon and then opens the Macros page in a session where those items' info has
  not been cached yet.
- **Standard context:** Dropping the panel's own refresh subscription is explicitly **"Recorded, not ruled"** in
  `slash-commands-§7`, so this is not a compliance finding. The finding is the behavior regression and the false comment.

### F-005 — Two hot-path item reads call the bare global `GetItemInfo` with no `C_Item` ladder `[deprecated-api]` `[perf]`

- **Where:**
  - `modules/Ranker.lua:88`: `local _, _, quality, ilvl, _, _, subType = GetItemInfo(itemID)`.
  - `core/TooltipCache.lua:459`: `local name, _, _, _, minLevel = GetItemInfo(itemID)`.
  - Their siblings already prefer `C_Item.GetItemInfoInstant` with a guarded fallback (`core/Classifier.lua:165-169`,
    `core/WeaponSlots.lua:46-49`).
- **Problem:** The global `GetItemInfo` is deprecated in favor of `C_Item.GetItemInfo` (anti-pattern #10: "route through
  Compat"). These two sites are called on every recompute and every tooltip-cache fill, and neither has a fallback.
- **Unverified:** whether 12.0.x still ships the global. The addon works in the client today, so it currently does. If a patch
  removes it, both the ranking and the tooltip parse fail at once, which would make this High.
- **Dead field:** `itemFields` also fetches and caches `subType` (`:88-96`), and none of its 15 callers reads it. Every scorer
  discards the third return (`:235-322`).
- **Reachability:** Every player on every recompute. There is no runtime defect today; the risk is on the next API cull.

### F-006 — The harness cannot see F-001, F-002 or F-003 `[tests]`

- **Where:**
  - `tests/wow_mock.lua:491-499`. The mock's `db.SetProfile` merges defaults into the incoming profile but never runs AceDB's
    `removeDefaults` over the outgoing one (real AceDB does, at `libs/AceDB-3.0/AceDB-3.0.lua:462`). So a suite that resets a
    color and switches profile stays green on F-002. The addon's own probe against the mock showed the defaults intact (4
    entries), while the real library emptied them (0 entries).
  - F-001: no case flushes a per-hand entry (`tests/test_macromanager.lua:330-340` covers FOOD only).
  - F-003: no case parks a registration while stood down.
- **Impact:** Three real defects sit on paths the inventory reads as covered.
- **Reachability:** The test inventory only. Shipped behavior is covered by F-001 to F-003 themselves, which is why this is capped
  at Medium.
- **Fix direction:** The mock is the addon's own file (`tests/wow_mock.lua`, not `tests/_kit/`), so this is a local change. Model
  `removeDefaults` on switch, and add the three cases red-first (`testing-§12`, `testing-§13`).

---

## Low

### F-007 — Standing back up skips login's discovery pass and stale sweep `[logic]` `[disabled-state]`

- **Where:**
  - `core/LifecycleSetup.lua:110-119` (`standUp`) calls `KCM:OnEnable()`, `MacroBar.Update()` and
    `RequestRecompute("stand_up")`.
  - `runAutoDiscovery("player_entering_world")` and `Selector.SweepStaleDiscovered(time())` exist only in `OnPlayerEnteringWorld`
    (`core/ConsumableMaster.lua:587-590`), and `PLAYER_ENTERING_WORLD` does not fire again on re-enable.
- **Impact:** Non-seeded consumables looted while disabled, or present at a disabled login, are not candidates until the next
  `BAG_UPDATE_DELAYED`. That is contrary to `performance-§6`'s "rebuild from the current state".
- **Reachability:** A player who re-enables mid-session while holding a non-seeded consumable that entered their bags while the
  addon was off. The first bag change repairs it.

### F-008 — `/cm resetall`'s help text understates what it destroys, and its two doors diverge `[ux]`

- **Where:**
  - `settings/Slash.lua:231`: `{"resetall", "Reset every priority list and stat override to defaults (asks first)",`.
    The act is a whole-profile `db:ResetProfile()` (`core/ConsumableMaster.lua:571-580`).
  - Two popups define the same act: `core/SlashCommands.lua:41-61` (`KCM_CONFIRM_RESET`) and `settings/General.lua:146-159`
    (`KCM_RESET_ALL`).
  - Only the panel door combat-guards (`settings/General.lua:111`) and refreshes panels. The slash door prints
    "Reset complete".
  - `core/ConsumableMaster.lua:558-560` claims "the two doors cannot diverge".
- **Impact:** A player reading `/cm help` expects to keep the macro-bar layout and the master controls. The popup text is correct,
  and it is what saves them.
- **Reachability:** Any player who reads `/cm help`.

### F-009 — The "Reset all priorities" tooltip points to a button "above" that is on another tab `[ux]`

- **Where:** `settings/General.lua:367`: "…for the whole-profile reset, use Reset all settings above." The button lives on the
  Maintenance tab (`:353-370`), and **Reset all settings** is on Master controls (`:242`).
- **Reachability:** Any player hovering the button.

### F-010 — The bare `/cm bar` toggle reads the latch-inclusive predicate `[logic]`

- **Where:** `core/SlashCommands.lua:904`: `local on = not KCM.MacroBarModel.IsEnabled()`. `IsEnabled` answers false while *any*
  hold is taken (`core/MacroBarModel.lua:146-150`).
- **Impact:** During a perf capture's suspended arm, `/cm bar` writes `macroBar.enabled = true` (already true) and prints "ON"
  every time, while the bar stays hidden. It can never toggle the bar off.
- **Reachability:** Only a player mid-`/cm perf` capture, in the suspended arm. The dispatcher's gate only refuses on the stored
  `enabled`, so the verb runs.

### F-011 — The launcher's left click unlocks a bar that is switched off and says "drag it" `[ux]`

- **Where:** `core/LauncherSetup.lua:180-187` toggles `macroBar.locked` without looking at `macroBar.enabled`, then says
  "macro bar unlocked — drag it, then /cm lock". The same wording is at `core/SlashCommands.lua:869-870` (`runLock`).
- **Reachability:** Any player with the macro bar turned off who left-clicks the minimap button or types `/cm unlock`.

### F-012 — `/cm enable` and `/cm disable` print two lines in two vocabularies `[ux]`

- **Where:** The row's onChange says `Master enable ON|OFF` (`settings/General.lua:249`), and the verb then echoes the canonical
  `enabled = true|false` (`settings/Slash.lua:116-117`). A scratch probe of `/cm disable` printed both lines.
- **Impact:** The row's label is "Enable Consumable Master" (the composer, `libs/LibKa0s/OptionsCompose.lua:473`), so three
  surfaces name one switch three ways.
- **Reachability:** Any player typing either verb.

### F-013 — Two assertions in the disabled suite cannot fail `[tests]`

- **Where:**
  - `tests/test_disabled.lua:292`: `t.truthy((ran or 0) > 0 or true, "the unconditional dispatch is available")`. This is a
    tautology. The case's second assertion, `:296`, is what actually falsifies.
  - `tests/test_disabled.lua:378`: `t.truthy(true, "this addon refuses its feature verbs")` is padding after real assertions.
- **Impact:** Each counts as a passing assertion that verifies nothing (`testing-§12`).
- **Reachability:** The test inventory only.
- **Not in this finding:** the `t.truthy(true, "… does not raise")` idiom elsewhere (e.g. `tests/test_bus.lua:100`) is a
  legitimate did-not-raise check.

### F-014 — Two places claim `/cm set macroBar.point|x|y` repositions the bar; there is no such row `[docs]`

- **Where:** `modules/MacroBar.lua:175` ("`/cm set macroBar.point|x|y` still writes the position outright") and
  `docs/ARCHITECTURE.md:340` say it does. `docs/ARCHITECTURE.md:130` ("`/cm set` cannot reach them because they have no row")
  and the schema say it doesn't: `settings/MacroBar.lua` declares no position row.
- **Reachability:** A comment and a doc. No runtime effect, but the doc sends a degraded-install player to a verb that refuses.

### F-015 — Stale comments that now describe removed behavior `[naming]`

Each item below is a comment only, with no runtime effect. Each one misdescribes code a reader will trust.

- `defaults/Profile.lua:54`: "when false the recompute pipeline early-returns". Disable is now a stand-down.
- `defaults/Profile.lua:107`: "Turning it off tears the frames down". `MB.Update` hides; it does not tear down.
- `defaults/Profile.lua:112`: "Every scalar here has a matching KCM.Settings.Schema row". This is false for
  `point`/`relPoint`/`x`/`y`.
- `core/ConsumableMaster.lua:367-404`: an orphaned doc block for the removed `restoreProfileDefaults`. At `:371-373` it still
  says "Shared by the Options panel's "Reset all priorities" execute and the /cm reset StaticPopup", and both of those have
  changed meaning.
- `settings/Slash.lua:25`: "Same secret-safe seam as the verb file (core/Constants.lua)". `KCM.Say` is in `core/CoreSetup.lua`.
- `settings/Slash.lua:288-291`: the table-level gate "covers BOTH dispatch arms". The wrap is gone (`:332`), and the degraded arm
  has no gate.
- `modules/Selector.lua:5`: "see TECHNICAL_DESIGN §4". No such doc exists.
- `modules/Selector.lua:604`: "(see Core.lua)". No such file exists.
- `ConsumableMaster.toc:50`: lists five LibKa0s modules; the payload carries fifteen majors.
- `ConsumableMaster.toc:76`: "It sits here, second". It is third.
- `ConsumableMaster.toc:81`: "the suspend/resume pair". That was retired for the latch.
- `settings/OptionsSetup.lua:160` ("the schema-row widget makers … are NOT the library's") contradicts `:231` ("The row makers
  are the library's now").

### F-016 — A published member with no reader, and one read only by tests `[dead-code]`

- `settings/General.lua:383`: `KCM.Settings.GENERAL_TABS = TABS`. There are zero readers in `core/`, `modules/`, `settings/` or
  `tests/`.
- `settings/Category.lua:1106`: `O.SetMacroTab` is read only by tests.
- **Reachability:** Maintenance only.

### F-017 — The About page's logo path hard-codes the addon folder `[naming]`

- **Where:** `settings/Panel.lua:148`: `local LOGO_TEXTURE = [[Interface\AddOns\ConsumableMaster\media\logos\consumablemaster.logo.tga]]`.
  Every other media path is built from the `addonName` vararg (`core/LauncherSetup.lua:107-108`, `core/MediaSetup.lua`,
  `core/EnvSetup.lua`), and those files explain why at length.
- **Reachability:** Only a renamed install folder, where the logo draws nothing and raises nothing.

---

## Upstream findings

**None.** No defect was found in `libs/LibKa0s/`, the vendored Ace3/LibDBIcon/LibDataBroker copies, or `tests/_kit/`.

F-002's mechanism involves the library composer handing `row.default` by reference
(`libs/LibKa0s/OptionsCompose.lua:171`). That is a documented declaration, and copying before storing is the host seam's job, so
the fix is local. F-006's mock is the addon's own `tests/wow_mock.lua`, not the kit.
