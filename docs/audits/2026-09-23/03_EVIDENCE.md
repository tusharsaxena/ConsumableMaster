# 03 — Evidence

**Addon:** Ka0s Consumable Master · **Audit:** 2026-09-23 · **Commit:** `7adfea1` · **Standard:** v2.64.0

Every `file:line` below was re-read at `7adfea1` while this bundle was being written, and the text at
that line is quoted next to it. Every count comes from a command pasted here with its real output
and a statement of what it covered and what it left out. Commands were run from the repo root unless
a line says otherwise. `B` is `~/.claude/wow-addon/bin/ka0s-bounded`, invoked by full path because it
is not on this shell's `PATH`.

---

## E0 — Resolving the standard

```sh
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
curl -fsSL $RAW/AUDIT.md -o AUDIT.md                    # 990 lines
curl -fsSL $RAW/standards/STANDARDS.md -o STANDARDS.md  # 242 lines
grep -oE '\(standards/[A-Za-z0-9_-]+\.md\)' STANDARDS.md | sort -u   # 27 section links
# each fetched from $RAW/standards/standards/<file>.md — 0 failures; plus $RAW/standards/ADDONS.md
head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)
```

---

## E1 — Gates (lint, suite, complexity)

**Scope of all three:** `luacheck .` reads what `.luacheckrc` allows. Its `exclude_files` is
`{ "libs/", "docs/audits/", "docs/reviews/", "tests/_kit/" }` (`.luacheckrc:14-19`), so every authored
`.lua` is linted, `tests/` included. The suite runs `tests/run.lua`'s declared `SUITES` list: 49 repo
suites plus the kit's `test_eol`, `test_prose` and `test_layout_cap` (`tests/run.lua:444-509`).
`lizard` runs over `.` with only `./libs/*` and `./tests/_kit/*` excluded.

```sh
$B luacheck .
# Total: 0 warnings / 0 errors in 116 files        exit=0
$B lua tests/run.lua
# 998 passed, 0 failed, 0 skipped, 998 total        exit=0
$B lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
# No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
# Total nloc  Avg.NLOC  AvgCCN  Avg.token  Fun Cnt  Warning cnt
#      23258       7.9     2.6       63.2     2499            0        exit=0
```

Functions at CCN ≥ 15 today, taken from the same output (`awk '$2>=15'` on the detail rows):

```
15 KCM@623-657@./core/ConsumableMaster.lua        # KCM:OnRegenEnabled — the only one
```

The same filter on the newest bundle, `docs/automated-tests/20260916-184427/complexity.txt`, returns
eight functions at 15 (`D.RunMigrations`, `itemCooldown`, `applyBackdrop`, `S.PickBestForSlot`,
`availableForHands`, `S.SweepStaleDiscovered`, `Helpers.BuildAboutContent`, `M.setItem`). None of them
is at 15 today, and `KCM:OnRegenEnabled` is new at 15. The bundle's footer reads
`22707  8.0  2.6  63.7  2396  0`, and its `manifest.json` records `"git": { "sha": "da0b0f8…", "dirty": false }`
and `"release": null`.

```sh
git rev-list --count da0b0f8..HEAD     # 33
```

Relevant suite lines, verbatim from the run:

```
  PASS  Disabled 1: enabled, the addon registers a non-empty set
  PASS  Disabled 3: the registration set is EMPTY, by count and by name
  PASS  Disabled 4: no OnUpdate and no state driver is left armed
  … (18 Disabled cases, all PASS)
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release
  PASS  the automated-test runner is recorded executable (100755)
  PASS  eol: every tracked file carries the terminator .gitattributes declares for it
  PASS  eol: .gitattributes is line-endings-5's canonical body for this repo kind
  PASS  prose: no authored file carries a British spelling from localization-5's published list
  PASS  layoutcap: every authored file over the 1500-line cap is named in the census
  PASS  layoutcap: an empty census is written as a result rather than left standing empty
```

---

## E2 — Vendored payload (`library-stack-§7`, anti-patterns #45 / #48 / #59)

```sh
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
# CLAUDE.md:61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).
git -C ../LibKa0s rev-parse v1.55.0 HEAD
# bb161b730f2691be39a0dfbbe5c66fd7ca5e8db1      (tag object)
# 46ccaa6c5260e99cd0d1028ab0aee421329cfedf      (HEAD — ahead of the tag; NOT what is diffed)
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>
diff -r <scratch>/LibKa0s libs/LibKa0s ; echo "exit=$?"     # (no output) exit=0
diff -r <scratch>/testkit tests/_kit   ; echo "exit=$?"     # (no output) exit=0
ls <scratch>/LibKa0s | wc -l ; ls libs/LibKa0s | wc -l       # 24 / 24
grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml             # 21
```

`ConsumableMaster.toc:55` reads `libs\LibKa0s\LibKa0s.xml`, and that is the only LibKa0s line in the TOC.
README greps: the library-inventory headings return nothing, logo/`<img>` returns nothing, and the
badge is `README.md:6` `![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)`,
bare and not wrapped in a link.

---

## E3 — The disabled state (`slash-commands-§7`) — `CM-84`, `CM-85`, `CM-86`

**Registration census.** Scope: `git ls-files '*.lua' ':!libs' ':!tests/_kit'`, with `tests/` dropped
from the displayed hits. The census is about what the shipped addon registers. The output below is
**condensed**: the nine `KCM:OnEnable` lines and the three `OptionsShim` lines are each folded onto one
line. The command reproduces the full 19 lines.

```sh
git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent' | grep -v '^tests/'
core/Bus.lua:145:    t:RegisterMessage(KCM.MSG.RECOMPUTE, function(_, reason)
core/ConsumableMaster.lua:708-716:  self:RegisterEvent(...) ×9   (PLAYER_ENTERING_WORLD … BAG_UPDATE_COOLDOWN)
core/LifecycleSetup.lua:99:        KCM:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
modules/MacroBar.lua:589:        target:RegisterMessage(KCM.MSG.MACROBAR_REFRESH, function()
modules/MacroBar.lua:593:            target:RegisterMessage(KCM.MSG.PROFILE_CHANGED, function() MB.Update() end)
settings/OptionsShim.lua:264/268/271:  optionsTarget:RegisterMessage(PANEL_REFRESH / PROFILE_CHANGED / SPEC_CHANGED)
settings/Panel.lua:1304:bootstrap:RegisterEvent("PLAYER_LOGIN")
settings/Panel.lua:1305:bootstrap:RegisterEvent("ADDON_LOADED")
settings/Profiles.lua:120:        bus:RegisterMessage(KCM.MSG.PROFILE_CHANGED, function()
```

Where each is undone:

- The events come down through `core/LifecycleSetup.lua:92` `if KCM.UnregisterAllEvents then KCM:UnregisterAllEvents() end`.
- The seven message registrations are all on tracked targets handed out by `KCM.NewBusTarget`
  (`core/Bus.lua:94` `function KCM.NewBusTarget(subscribe)`), and `core/LifecycleSetup.lua:73`
  `if KCM.Bus and KCM.Bus.StandDown then KCM.Bus.StandDown() end` takes them down.
- The bootstrap frame is setup, and it unregisters itself at `settings/Panel.lua:1310`
  `self:UnregisterAllEvents()` once the category exists.

**Timers, OnUpdate and secure drivers.**

```sh
git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'RegisterAttributeDriver|UnregisterAttributeDriver|RegisterStateDriver|UnregisterStateDriver'
modules/MacroBar.lua:16:--     reason — it is handed to RegisterStateDriver, so Blizzard's secure
modules/MacroBar.lua:328:    if UnregisterStateDriver then UnregisterStateDriver(bar, "visibility") end
modules/MacroBar.lua:345:    elseif RegisterStateDriver then
modules/MacroBar.lua:346:        RegisterStateDriver(bar, "visibility", driver)
modules/MacroBar.lua:455:            if UnregisterStateDriver then UnregisterStateDriver(bar, "visibility") end
modules/MacroBarFlyout.lua:289:    if RegisterAttributeDriver then
modules/MacroBarFlyout.lua:290:        RegisterAttributeDriver(flyout, "kcmCombat", "[combat] 1; 0")
```

**`CM-84`.** There is exactly one `RegisterAttributeDriver` and **no** `UnregisterAttributeDriver`
anywhere in the authored tree.

- `modules/MacroBarFlyout.lua:289-290`: `if RegisterAttributeDriver then` /
  `RegisterAttributeDriver(flyout, "kcmCombat", "[combat] 1; 0")`, inside `function FO.Create(button,
  catKey, index)` (`:230`).
- That function is called once per slot from `modules/MacroBarButton.lua:463`:
  `if KCM.MacroBarFlyout then KCM.MacroBarFlyout.Create(btn, catKey, index) end`.
- The disable path is `modules/MacroBar.lua:453`
  `if not (KCM.MacroBarModel.IsEnabled and KCM.MacroBarModel.IsEnabled()) then`, then `:455`
  (the visibility state driver), `:459` `bar:SetScript("OnUpdate", nil)` and `:460` `bar:Hide()`. No
  flyout is touched.
- `slash-commands.md` (*What MUST stand down*) reads: *"Hooks and secure state drivers are stood down
  where they can be … `UnregisterStateDriver`, `UnregisterAttributeDriver` and any secure-attribute
  rewrite **MUST NOT** be attempted in combat; the addon holds the stand-down pending and completes
  it on `PLAYER_REGEN_ENABLED`."*

**`CM-85`.** `tests/test_disabled.lua:222-223` reads `local drivers = mock.stateDrivers[bar]` /
`t.falsy(drivers and drivers.visibility, "the secure visibility driver is unregistered")`.
`grep -n 'attributeDrivers' tests/test_disabled.lua` returns nothing. The repo's mock does record
attribute drivers: `tests/wow_mock.lua:823` `M.attributeDrivers = {}`, and
`:828` `_G.UnregisterAttributeDriver = function(frame, attribute)`.

**`CM-86`**, in order of execution:

- `core/ConsumableMaster.lua:54-55` takes the `disabled` hold at load:
  `if KCM.OnEnabledChanged then` / `KCM.OnEnabledChanged(not (self.db.profile and self.db.profile.enabled == false))`.
- `core/LifecycleSetup.lua:98-100` registers regen only when the stand-down happens in combat:
  `if inCombat() then` / `KCM:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")` / `end`.
- `settings/Panel.lua:1267-1269` parks the registration: `if InCombatLockdown and InCombatLockdown() then` /
  `KCM.Settings.registerPending = true` / `return`. The comment above it at `:1255-1256` reads
  *"but an in-combat /reload reaches it, and so does another addon calling
  C_AddOns.LoadAddOn("Blizzard_Settings") mid-pull"*.
- `core/ConsumableMaster.lua:631-634` is the stood-down branch of `KCM:OnRegenEnabled`:
  `if KCM.IsStoodDown and KCM.IsStoodDown() then` / `…FlushPending() end` /
  `self:UnregisterEvent("PLAYER_REGEN_ENABLED")` / `return`.
- `core/ConsumableMaster.lua:654` is the replay, below that return:
  `if KCM.Settings and KCM.Settings.registerPending and KCM.Settings.Register then`.
- `git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -n 'registerPending'` returns only
  `core/ConsumableMaster.lua:654`, `settings/Panel.lua:1268, 1271` and the two test lines at
  `tests/test_settingsui_optionsui.lua:775, 795`. Nothing else replays it.
- What the player sees: `settings/OptionsShim.lua:222` `local id = KCM._settingsCategoryID`, which is
  nil because `settings/Panel.lua:1286` `KCM._settingsCategoryID = main:GetID()` never ran. That falls
  through to `:233` `KCM.Say("settings panel unavailable on this client; use /cm help.")`.
- The tests `tests/test_settingsui_optionsui.lua:769` (*"registering the category in combat is
  refused and parked"*) and `:778` (*"leaving combat replays the parked registration, and only
  then"*) both run with the addon enabled.

**Compliant parts, for the record.**

- `core/LauncherSetup.lua:175-179`: `if KCM.IsAddonDisabled and KCM.IsAddonDisabled() then` …
  `if Sl then KCM.Say(Sl:DisabledLine()) end` / `return`.
- `core/ConsumableMaster.lua:707`: `if KCM.IsStoodDown and KCM.IsStoodDown() then return end`, the
  door, before the nine registrations.
- `libs/LibKa0s/Slash.lua:21`: `local MAJOR, MINOR = "LibKa0s-Slash-1.0", 14`, which is at the
  v1.42.0 floor or above it.

---

## E4 — Event registration (`events-frames-taint-§1`) — `CM-87`

`core/ConsumableMaster.lua:706` is `function KCM:OnEnable()`. `:707` is the stood-down guard. `:708`
through `:716` are nine bare `self:RegisterEvent("…", "…")` lines, from
`self:RegisterEvent("PLAYER_ENTERING_WORLD",         "OnPlayerEnteringWorld")` to
`self:RegisterEvent("BAG_UPDATE_COOLDOWN",           "OnCooldownUpdate")`. `:717` is `end`. There is
no `pcall` in the function and no rejected-name table anywhere in the authored tree
(`git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'IsEventValid\|badEvents'` returns nothing.
The only `rejected` hits are `core/Bus.lua:115-117`, which is the bus record's stand-up replay list
(`local replayed, rejected = KCM.busRecord:StandUp()`) and has nothing to do with client event names).

---

## E5 — Settings open and registration (`options-ui-§2`) — `CM-88`

```sh
git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory' | grep -v '^tests/'
settings/OptionsShim.lua:187:-- SettingsPanel:GetCategoryList():GetCategoryEntry(category). That path
settings/OptionsShim.lua:194:    if not (main and SettingsPanel) then return end
settings/OptionsShim.lua:196:        local list = SettingsPanel.GetCategoryList
settings/OptionsShim.lua:197:            and SettingsPanel:GetCategoryList()
settings/OptionsShim.lua:198:            or SettingsPanel.CategoryList
settings/OptionsShim.lua:224:    if Settings and Settings.OpenToCategory and id then
settings/OptionsShim.lua:225:        Settings.OpenToCategory(id)
settings/OptionsShim.lua:226:        -- Expand AFTER opening so SettingsPanel is realized and the
```

- Each hit is classified as follows. It is the host's own open, it is combat-gated at
  `settings/OptionsShim.lua:217` `if InCombatLockdown and InCombatLockdown() then`, and it is not
  anti-pattern #88. It is still a **second open**.
- The library's own members: `libs/LibKa0s/Options.lua:1351` `function O.CreateOptionsPanel()` and
  `:1411` `function O.OpenOptionsPanel()`.
- `git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -n 'CreateOptionsPanel\|OpenOptionsPanel\|RegisterOptionsPage'`
  returns only the comment at `settings/OptionsSetup.lua:287`: *"it only inside its own
  CreateOptionsPanel, which this addon never calls."*
- The host's registration: `settings/Panel.lua:1278-1279` `local main =
  Settings.RegisterCanvasLayoutCategory(mainCtx.panel, PANEL_TITLE)` / `Settings.RegisterAddOnCategory(main)`.
- The library's `registerMain` (`libs/LibKa0s/Options.lua:1322-1347`) has no `InCombatLockdown`
  check, so the host's parking has no library counterpart. That gap is why the fix direction is
  upstream first.
- The refusal wording is canonical: `settings/Panel.lua:120`
  `KCM.Say("|cff808080cannot open settings during combat — Blizzard's category-switch is protected|r")`.

---

## E6 — README (`documentation-§1`) — `CM-89`

`README.md:35` reads `## What's new in 1.6.2`. The body at `:37` is
`- Fixed the AIO Health and AIO Mana tooltips on the macro bar showing the macro's text instead of the item or spell it will use`,
and `README.md:137` has the same text in the `1.6.2` Version History row. Heading order, from
`grep -n '^#' README.md`: `1 # Ka0s Consumable Master`, `35 ## What's new in 1.6.2`,
`39 ## Screenshots`, `62 ## Usage`, `76 ## How picking & ranking works`, `94 ## FAQ`,
`111 ## Troubleshooting`, `129 ## Issues and feature requests`, `133 ## Version History`.

---

## E7 — Deviation register (`audit-review-history`) — `CM-90`, `CM-96`

`docs/ARCHITECTURE.md:404` `## Documented deviations`; rows at `:414`, `:415` and `:416`.

- **`localization-§4` (`:414`), accepted.** It cites `core/Classifier.lua:167-170`: `:167` reads
  `return classID, subClassID` inside `classOf`, the `C_Item.GetItemInfoInstant` path (`:165-166`).
  `CM-30` resolves to `docs/audits/2026-07-18/02_DEVIATIONS.md`. The trigger (*"A client API that
  exposes those magnitudes as structured data, or the first non-enUS client this addon commits to
  supporting"*) has not fired in the tree.
- **`compat` (`:415`), accepted.** It cites `core/TooltipCache.lua:459`
  `local name, _, _, _, minLevel = GetItemInfo(itemID)` and `modules/Ranker.lua:88`
  `local _, _, quality, ilvl, _, _, subType = GetItemInfo(itemID)`. Both resolve. `CM-63` resolves to
  `docs/audits/2026-08-05/03_EVIDENCE.md` and `CM-R-10` to `docs/reviews/2026-09-07/02_PROPOSED_CHANGES.md`.
  **`CM-96`:** `git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'GetItemInfo(' | grep -v Instant`
  also returns `modules/KCMItemRow.lua:96` `local n = _G.GetItemInfo(itemID)` and `:139`
  `local _, link = _G.GetItemInfo(itemID)`, which the row does not name. The trigger (Blizzard
  deprecating the globals) is a client fact the tree cannot show, so this run records it as
  *not evidenced as fired*.
- **`preview-mode` (`:416`), stale (`CM-90`).** The row's trigger text reads *"or a preview / test
  verb being added to `/cm` — either one re-arms the placeholder SHOULD"*. Evidence:
  - `git log --oneline -i --grep='test mode'` returns `87ed204 Add the macro bar's test mode: Master
    controls checkbox, /cm test` (2026-09-16) and `9c45eff Remove the Macro Bar's test mode: Lock
    frame is the switch (v2.49.0)` (2026-09-16).
  - The v2.49.0 changelog entry in the fetched `STANDARDS.md` reads: *"After adoption the collection
    owner found the Test mode checkbox and Lock frame doing the same thing in Ka0s Aura Master, Ka0s
    Consumable Master, Ka0s KickCD and Ka0s Panel Master … `options-ui-§15` now exempts such an
    addon"*.
  - `preview-mode.md`'s current MUST includes the **Exception**, *"when unlocking already shows the
    display with its placeholder content, the unlocked view is the test mode and *Lock frame* is its
    switch"*.
  - The row's Decided date is still `2026-08-05`.

**Issue store** (`gh issue list --state all --limit 200 --json number,title,state,labels`; no GraphQL):
39 issues, all carrying `state:` and `severity:` labels, none with a `[status]` title prefix. The
closed `state:will-not-do` issues are #17 through #26, #28, #30 and #31. `ls docs/pending` answers
*No such file or directory*.

---

## E8 — Re-vendor store (`audit-review-history`) — `CM-91`

This is `AUDIT.md`'s command run verbatim under `bash`. Scope: commits touching `libs/LibKa0s` since
the store's first bundle, compared against every bundle under `docs/revendor/`.

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-08-25
git log --since="$horizon" --format=%H -- libs/LibKa0s | while read -r c; do
  git show "$c:CLAUDE.md" 2>/dev/null | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
done | sort -uV > vendored.txt
for b in docs/revendor/*/; do
  t=$(basename "$b" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [ -n "$t" ] || t=$(head -1 "$b/01_DELTA.md" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
  [ -n "$t" ] && echo "$t"
done | sort -uV > recorded.txt
grep -vxF -f recorded.txt vendored.txt | wc -l                  # 27
```

```
vendored (33): v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.25.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0
               v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0
               v1.39.0 v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.48.0 v1.48.1 v1.50.0 v1.51.0
               v1.52.0 v1.53.0 v1.55.0
recorded (8):  v1.15.0 v1.25.0 v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.55.0
unrecorded (27): v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0
                 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.45.0
                 v1.46.1 v1.47.0 v1.48.0 v1.48.1 v1.50.0 v1.51.0 v1.52.0 v1.53.0
```

These are the first lines of the bare-dated bundles, all opened before counting:
- `docs/revendor/2026-08-25/01_DELTA.md:1` `# 01 — Delta: ConsumableMaster vs LibKa0s v1.15.0`
- `2026-09-03` → `… v1.24.0 → v1.25.0`
- `2026-09-12` → `… v1.29.0 → v1.30.0`

The newest bundle, `docs/revendor/2026-09-23-v1.55.0/01_DELTA.md:1`, reads
`# 01 — Delta: LibKa0s v1.54.2 → v1.55.0`, so it covers only its own tag. `## Documented deviations`
has no row keyed `audit-review-history`.

---

## E9 — Bus names (`architecture-§4`, `naming-cheatsheet`) — `CM-93`

```sh
git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE '(Send|Register)Message\("Ka0s_'
tests/test_harness.lua:73:    target:RegisterMessage("Ka0s_ConsumableMaster_HarnessPing", "OnHarnessPing")
tests/test_harness.lua:74:    KCM.bus:SendMessage("Ka0s_ConsumableMaster_HarnessPing", 5)
git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -noE '"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"' | sort -u -t: -k3
core/Bus.lua:128:"Ka0s_ConsumableMaster_Recompute"      :129 PanelRefresh   :130 SpecChanged
core/Bus.lua:131:"Ka0s_ConsumableMaster_MacroBarRefresh" :132 ProfileChanged
tests/test_harness.lua:73:"Ka0s_ConsumableMaster_HarnessPing"
```

Every tail is PascalCase. The only literal hits are the two test lines.

---

## E10 — Load-order drift (`documentation-§5`) — `CM-94`

- `ConsumableMaster.toc:68` `core\Namespace.lua`, `:75` `core\LifecycleSetup.lua`, `:83` `core\PerfSetup.lua`.
- `ConsumableMaster.toc:77` `# second, because performance-§1 requires it BEFORE any file that takes`.
  This line is inside the PerfSetup comment, which begins at `:76` `… It sits here,`.
- `docs/ARCHITECTURE.md:324`: `3. \`# Core\` — \`Namespace.lua\` (names \`NS\` and \`KCM.VERSION\`) → \`PerfSetup.lua\` …`.
  LifecycleSetup does not appear.
- `docs/module-map.md:598`: `3. **Core** — \`core/Namespace.lua\` (names \`NS\`, \`KCM.VERSION\`) → \`PerfSetup\` …`.
  Neither LifecycleSetup nor LauncherSetup appears.
- `docs/module-map.md:620` (LifecycleSetup row): *"Loaded **second** in `# Core`, ahead of `core/PerfSetup.lua`"*.
- `docs/module-map.md:642` (PerfSetup row): *"Loaded **second** in `# Core`, immediately after `core/Namespace.lua`"*.
- `docs/performance.md:46`: *"… which is why `core/PerfSetup.lua` sits second"*.
- `docs/ARCHITECTURE.md:418`: *"Those comments are at `ConsumableMaster.toc:51-57` and `:77-79`"*.
  Today `:51-55` is the LibKa0s library comment and XML line, `:56` is blank, `:57` is `# Locales`,
  and `:77-79` is the middle of the PerfSetup comment.

---

## E11 — US English (`localization-§5`) — `CM-79`, `CM-80`, `CM-81`

Scope: tracked `.md`, `.lua` and `.txt` files, minus `libs/`, `tests/_kit/` and the frozen stores
(`docs/audits|reviews|revendor|superpowers`). The two store `README.md` files and `RESULTS.md` are kept in.

```sh
git ls-files | grep -vE '^(libs/|tests/_kit/|docs/(audits|reviews|revendor|superpowers)/)' | grep -E '\.(md|lua|txt)$' \
  | xargs grep -niE 'synchronis|analysed|neighbour'
docs/perf-analysis/README.md:25:the capture *happened*, not when it was written up, so a run analysed a week later still sorts
docs/perf-analysis/README.md:26:against its neighbours.
docs/settings-panel.md:80:controls over one piece of session state is a synchronisation problem the design would have invented
```

The gate's exclusions, from `tests/_kit/test_prose.lua:209-213`: `local SKIPPED_DIRS = {` /
`"libs/", "Libs/", "tests/_kit/",` / `"docs/audits/", "docs/automated-tests/", "docs/perf-analysis/",` /
`"docs/reviews/", "docs/revendor/",` / `}`. The published `BRITISH` list in the fetched
`localization.md` contains `"neighbour"` and `"analys"`, and it does not contain `synchronis`.
`tests/run.lua:507` reads `{ name = "test_prose",      dir = "tests/_kit/" },`, and
`ls tests/test_prose.lua` answers *No such file*.

---

## E12 — Citation notation (`documentation-§6`) — `CM-75`

Scope: 141 tracked `.lua`, `.md` and `.toc` files, excluding `libs/`, `tests/_kit/`, the frozen stores
and the dated bundles under `docs/automated-tests/` and `docs/perf-analysis/`. `docs/smoke-tests.md`'s
own internal `§N` numbering is dropped from the bare count.

```sh
cat scope.txt | xargs grep -nE '§[0-9]+\.[0-9]'            | grep -v smoke-tests.md | wc -l   # 0  (retired dotted form)
cat scope.txt | xargs grep -nP '(?<![A-Za-z-])§[0-9]+'     | grep -v '^docs/smoke-tests.md' | wc -l   # 46 bare, in 22 files
cat scope.txt | xargs grep -noE '[a-z][a-z-]*-§[0-9]+' | wc -l                                     # 672 filename-§N
# range check: each name-§N against `grep -c '^### [0-9]' standards/standards/<name>.md` → 0 unknown, 0 out of range
```

A few of the 46 cite `docs/smoke-tests.md §N` from other files (`settings/MacroBar.lua:691`,
`settings/OptionsSetup.lua:185`, `tests/test_macrobar_buttons.lua:184`, `docs/profiles.md:184`) or
`TECHNICAL_DESIGN §4` (`modules/Selector.lua:5`). Those name other documents' numbering and are out
of the rule's scope. The rest are continuations of `options-ui`, `slash-commands`, `debug-logging` or
`savedvariables`.

---

## E13 — TOC conventional markers (`toc-file-§5`) — `CM-83`

`ConsumableMaster.toc:57` `# Locales` is followed directly by `:58` `locales\enUS.lua`. `:166`
`# Modules` is followed directly by `:167-176` (`modules\Ranker.lua` … `modules\KCMItemRow.lua`).
`:202-205` (`settings\General.lua` … `settings\Category.lua`) carry no comment. The load-bearing
positions do carry comments naming what resolves, and those are listed in `01_CURRENT_STATE.md`.

---

## E14 — Hub shape (`documentation-§3`) — `CM-92`

```sh
wc -l docs/ARCHITECTURE.md                                  # 504
grep -n '^## ' docs/ARCHITECTURE.md   # …:404 ## Documented deviations (last ## heading; file ends :504)
awk 'NR>=404 && NR<=504' docs/ARCHITECTURE.md | wc -l      # 101
```

`docs/ARCHITECTURE.md:455` begins **What the peel did**, and `:483`/`:494` are the Panel and Category
peel paragraphs.

---

## E15 — Documentation map (`documentation-§3`)

Scope: tracked `docs/*.md`, minus `docs/{audits,reviews,revendor,superpowers,investigations}/` and the
dated bundles under `docs/automated-tests/` and `docs/perf-analysis/`.

```sh
on disk: 20   in map: 22   orphans: (none)   map-not-disk: compat-layer.md, message-bus.md   duplicate rows: (none)
grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua    # 2
```

The two map-only rows are the *Not applicable* rows at `docs/ARCHITECTURE.md:381` (`message-bus.md`,
*"Five messages; threshold is more than ten"*) and `:382` (`compat-layer.md`, *"… answers 2; threshold
is three or more"*). Both triggers were re-measured: five wire names at `core/Bus.lua:128-132`, and the
grep above answers 2 (`core/Compat.lua:44`, `:53`).

---

## E16 — Line endings (`line-endings`)

```sh
test -f .gitattributes && echo present                        # present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes      # 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes           # 36:*.sh text eol=lf / 37:*.py text eol=lf
grep -c ' binary$' .gitattributes                             # 20
diff <(head -n 84 .gitattributes | tr -d '\r') <line-endings-§5 client-bound body, 84 lines>   # exit=0
tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .          # (nothing) exit=1
# (e), verbatim from AUDIT.md, whole tracked set, no exclusions:
git ls-files -z | xargs -0 -I{} sh -c '…' 2>/dev/null | wc -l   # 0
```

The CR is stripped from the repo side because the canonical body was extracted from the LF-stored
section file.

---

## E17 — Packaging (`packaging`)

This is `AUDIT.md`'s three-part check, run under `bash`. Under `zsh` the unquoted `$entries` does
not word-split, and the first attempt printed a false *NOT IGNORED* for the whole string.

```
(a) done                 # nothing printed
UNACCOUNTED — .git       # (b): only .git, which the packager never sees
(c) done                 # nothing printed
```

`.pkgmeta` ignores `docs`, `tests`, `_dev`, `.luacheckrc`, `.pkgmeta`, `.gitignore`, `.gitattributes`,
`.claude`, `.superpowers`, `"*.bak"`, `CLAUDE.md`, `DEPENDENCIES.md`, `media/screenshots`,
`media/logos/*.png` and `media/logos/*.jpg`.

---

## E18 — Logo (`toc-file-§1`, `layout-§4`)

```sh
od -A d -t u1 -N 18 media/logos/consumablemaster.logo.128.tga
# 0000000   0   0   2   0   0   0   0   0   0   0   0   0 128   0 128   0
# 0000016  32   8
```

That decodes to type 2 (uncompressed), 128 × 128, 32-bit.
