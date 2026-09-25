# 04 — Technical design

**Addon:** Ka0s Consumable Master · **Audit:** 2026-09-23 · **Standard:** v2.64.0 · **Commit:** `7adfea1`

This document covers how to close each gap in `02_DEVIATIONS.md`, keyed to its ID. It is a design,
not an edit: this audit changes no code. Upstream work comes first. Four of the findings are fixed,
or are fixed properly, only in `LibKa0s` or `WowAddonStandards`, and the addon's side of each waits
for the re-vendor.

---

## Part A — Upstream (do these before the addon changes that depend on them)

### A1. LibKa0s testkit: narrow the prose gate's store skips — `CM-79` (→ `CM-80`)

`tests/_kit/test_prose.lua:209-213` skips `docs/automated-tests/` and `docs/perf-analysis/` whole.
`localization-§5` lets a gate skip frozen *dated bundles* and nothing wider, and the two `README.md`
files and `RESULTS.md` in those stores are authored or regenerated in place.

- **Change (in `LibKa0s/testkit/test_prose.lua`).** Replace both prefixes with a dated-bundle
  matcher, applied only to the two stores: skip `docs/automated-tests/<YYYYMMDD-HHMMSS>/` and
  `docs/perf-analysis/<YYYYMMDD-HHMMSS>/`, and scan the store root files. The section wants
  exclusions named rather than inferred from a pattern. The smallest compliant shape is to enumerate
  the two stores' **root files** as scanned and treat every subdirectory of those two stores as a
  frozen bundle. That rule is a directory listing, not a regex over prose.
- **Self-test.** Add a case that plants a British spelling in a store root `README.md` and asserts
  the gate turns red. Without it the gate would pass whether or not the change landed (`testing-§12`).
- **Ripple.** Every consumer that re-vendors will find any British spellings in those three files at
  once. The fix is the same in each repo.

### A2. WowAddonStandards: add `synchronis` to `localization-§5`'s `BRITISH` list — `CM-81`

It passes the admissibility test, since no US word contains `synchronis`. Bump the published count
(91 → 92) and the kit's `PUBLISHED_BRITISH` constant with it
(`tests/_kit/test_prose.lua:198`, `local PUBLISHED_BRITISH, PUBLISHED_ALLOWED = 91, 30`). Order:
standard first, then the kit, then re-vendor.

### A3. LibKa0s-Options-1.0: combat parking for registration, so the host open can go — `CM-88` (enables `CM-86`'s clean fix)

The host keeps its own registration and open because `O.CreateOptionsPanel`'s `registerMain`
(`libs/LibKa0s/Options.lua:1322-1347`) has no `InCombatLockdown()` check. Adopting it as it stands
would regress the in-combat `/reload` taint fix the host carries (`settings/Panel.lua:1253-1270`).
The upstream change:

1. `O.CreateOptionsPanel()` refuses under lockdown, records `pending = true` and returns.
2. A new member, `O.ReplayPending()`, re-runs `CreateOptionsPanel` if it was parked and otherwise
   does nothing. Hosts call it from their existing `PLAYER_REGEN_ENABLED` handler.
   `options-ui-§2` forbids defer-and-replay for the **open**, not for **registration**, which is
   taint-avoidance.
3. `O.OpenOptionsPanel()` returns a boolean so the host's `config` verb can keep branching on it
   (the host's `O.Open` contract, `settings/OptionsShim.lua:207-236`).
4. Library tests cover park, replay, and idempotence after a replay.

If the library owner declines, the addon's alternative is a `## Documented deviations` row keyed
`options-ui-§2` that states why the host open exists, with a re-check trigger of "the options library
parks registration in combat".

### A4. (Optional, collection-wide) a shared `pcall`ed event registrar — `CM-87`

`events-frames-taint-§1`'s two MUSTs (isolate each registration, record the rejected names) are the
same few lines in every addon. The addon can satisfy them alone (B4). If the owner prefers one copy,
put a `SafeRegister(target, event, handler, record)` helper on `LibKa0s-Core-1.0`, re-vendor, and
call it from `KCM:OnEnable`. This is a scheduling choice, not a blocker.

### A5. WowAddonStandards: reconcile AUDIT.md's two gradings of the re-vendor check — `CM-91` (process note)

`AUDIT.md`'s re-vendor check grades a missing bundle **High**, while step 5's impact table reserves
High for user- or session-reachable defects. That makes a record-keeping gap the addon's only High.
Propose that `AUDIT.md` either grade it through step 5 (Low, still a MUST) or state that this check
is an explicit exception. This changes nothing in the addon. It is listed so the collation step can
carry it upstream.

---

## Part B — The addon

### B1. Stand the flyout attribute drivers down — `CM-84`, `CM-85`

**Where.** `modules/MacroBar.lua` `MB.Update()`'s disable branch (`:453-460`). It is already
combat-gated at its top (`pendingUpdate`), so every protected call it makes is out of combat, and the
latch's pending `PLAYER_REGEN_ENABLED` finishes it when the stand-down lands mid-fight.

**Shape.**

- Add `FO.StandDown(flyout)` and `FO.StandUp(flyout)` to `modules/MacroBarFlyout.lua`.
  `StandDown` calls `UnregisterAttributeDriver(flyout, "kcmCombat")`. `StandUp` re-issues
  `RegisterAttributeDriver(flyout, "kcmCombat", "[combat] 1; 0")`. Keep the string in one module-level
  constant (`FLYOUT_COMBAT_DRIVER`) that `FO.Create` uses too, so the two can never diverge.
- In `MB.Update`'s disable branch, walk the existing `buttons` table and call `FO.StandDown` on each
  slot's flyout. On the enable path, `ensure()` → `applyVisibility()` re-arms them through
  `FO.StandUp`. Frames are kept, never rebuilt, so a disable/enable cycle leaks nothing (the same
  re-use rule `events-frames-taint-§1` gives the unit-filter frame).
- The bar's own `macroBar.enabled = false` path is the same branch, so a bar the player switched off
  also stops paying for its flyout drivers. That is a side benefit, not a behavior change a player
  can see.

**Test (`CM-85`).** Extend `tests/test_disabled.lua` step 4:

- Before disabling, assert that `mock.attributeDrivers[flyout].kcmCombat` is set for at least one
  built flyout. Otherwise the check passes over nothing, the non-empty-baseline rule of step 1.
- After disabling, assert that no flyout still holds `kcmCombat`.
- Add the falsification comment:
  `-- red under: drop FO.StandDown from MB.Update's disable branch`.
- Extend step 9 (re-enable) to assert the drivers come back.

**Risk.** A flyout opened while combat starts and the addon is disabled in the same frame. That
cannot happen: the disable path defers wholesale in combat, and the flyout's own combat-close
snippet reads `kcmCombat` only while its driver exists. Smoke test §11e (flyout closing) should be
re-run after the change.

### B2. Keep the settings registration alive through a disabled combat login — `CM-86`

**Where.** `core/ConsumableMaster.lua` `KCM:OnRegenEnabled` (`:623-657`) and
`core/LifecycleSetup.lua` `standDown` (`:98-100`).

**Shape, without adding CCN to `OnRegenEnabled`** (it sits at 15, the release ceiling).

1. Extract the replay into a named local, `replayParkedRegistration()`, holding exactly today's `:654-656` body.
2. Call it **first** in `OnRegenEnabled`, before the stood-down early return. Registration is setup,
   not a feature, so it must run in both states. Then keep the two branches as they are, minus the
   replay's old position at the bottom. The net CCN change is ≤ 0.
3. Park-time registration. When `registerPanel` parks (`settings/Panel.lua:1268`) while the addon
   is stood down, nothing is listening for regen. Have `registerPanel` call one seam,
   `KCM.EnsureRegenForParkedSettings()` (in `core/LifecycleSetup.lua`), which does
   `KCM:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")` if `KCM.IsStoodDown()`. Enabled
   addons are unaffected because `OnEnable` already registered it. The registration is released in
   the stood-down branch as today, which keeps `§7`'s *"released the moment it fires"* rule.
4. If A3 lands first, the same shape calls `UI.ReplayPending()` instead of the host's
   `KCM.Settings.Register`, and `registerPanel` goes away.

**Test.** A case beside `tests/test_settingsui_optionsui.lua:778`:

- Disable the addon out of combat, park the registration in combat, then leave combat.
- Assert `KCM.Settings.Register` was called once and `PLAYER_REGEN_ENABLED` is unregistered
  afterwards.
- Add the same case with the stand-down itself happening in combat.
- Add the falsification comment: `-- red under: move the replay back below the stood-down return`.

`docs/ARCHITECTURE.md` → *The disabled state is total* gains one line in the SURVIVES table: the
parked settings registration keeps the pending `PLAYER_REGEN_ENABLED` until it is replayed.

### B3. Adopt the library open — `CM-88`

This waits on A3. Then:

- `KCM.Options.Open` delegates to `UI.OpenOptionsPanel()`.
- `settings/Panel.lua`'s `registerPanel` delegates to `UI.CreateOptionsPanel()`, after moving the
  About renderer into the descriptor's `buildMain` and handing each page's builder to
  `O.RegisterOptionsPage`.
- Delete `expandMainCategory` (`settings/OptionsShim.lua:192-205`) and `KCM._settingsCategoryID`.
- `sayCombatOpenBlocked` becomes the library's `COMBAT_REFUSED` string, which already carries the
  canonical wording.
- The Options stub (`settings/OptionsSetup.lua`) gains `CreateOptionsPanel`, `OpenOptionsPanel` and
  `ReplayPending` as no-ops returning false. `tests/test_surface_parity.lua`'s Options case covers
  them.

This is the largest change in the plan, and the only one touching page registration. It lands behind
the full suite and the smoke test's §6a (the in-combat registration) and the `config` sections.

### B4. Isolate event registration — `CM-87`

In `core/ConsumableMaster.lua`, replace the nine bare calls with a module-level list and one loop
through a `pcall`ed helper:

```lua
local EVENTS = { {"PLAYER_ENTERING_WORLD","OnPlayerEnteringWorld"}, … }  -- module level, not per call (#43)
local rejected = {}                                                     -- KCM.RejectedEvents
local function safeRegister(self, ev, handler)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(ev) then
        rejected[#rejected + 1] = ev; return
    end
    local ok = pcall(self.RegisterEvent, self, ev, handler)
    if not ok then rejected[#rejected + 1] = ev end
end
```

- `KCM:OnEnable` keeps its door guard (`:707`) and loops `EVENTS`. The list is also what
  `tests/test_disabled.lua` step 1 names, so keep them in step by having the suite read `KCM.EVENTS`.
- Publish `KCM.RejectedEvents` and print it in the `[Init]` debug content (`core/DebugLogSetup.lua`)
  and in a `/cm dump events` target (`core/SlashDump.lua`), which makes it reachable through `debug`.
- Use the kit's `M.__badEvents` to add a case where one retired name still leaves the other eight
  bound, with `-- red under: remove the pcall in safeRegister`.
- Write the trade (a retired event's edge is lost, the block survives) into `docs/midnight-quirks.md`.

If A4 is taken, `safeRegister` is the library's and only the list and the record stay here.

### B5. README — `CM-89`

Delete `README.md:35-38` (`## What's new in 1.6.2` and its bullet). Run the de-AI pass over the
change (`documentation-§1`). No version bump: this is not a release.

### B6. Retire the stale `preview-mode` row — `CM-90`

Remove `docs/ARCHITECTURE.md:416`. Under the table, beside the `toc-file-§5` retirement note at
`:418`, add one prose line: *"Retired on <date>: `preview-mode` since v2.49.0 exempts an addon whose
unlocked view already is its preview, naming this one; Lock frame is the switch (`9c45eff`)."*
If the owner reads *"placeholder content"* as excluding a bar that draws live icons, the alternative
is to re-decide the row against the current text with today's Decided date and a new trigger. The
owner makes that call.

### B7. Consolidated re-vendor bundle — `CM-91`

Write `docs/revendor/<date>-v1.18.0..v1.53.0/`, or a bare date whose `01_DELTA.md` line 1 names the
span. `01_DELTA.md` records that tags v1.18.0 through v1.53.0 (27 tags, listed from
`03_EVIDENCE.md` E8) were vendored without a bundle, by which sweeps (read the subjects of the
`git log -- libs/LibKa0s` commits), and that no per-tag deliberation took place. `05_SUMMARY.md`
records what was adopted along the way: Launcher at v1.39.0, Lifecycle at v1.41–v1.42, the lock at
v1.46, DragHandle at v1.48.0, the kit gates at revision 24–25. Do **not** back-fill per-tag folders
(`audit-review-history`). Re-run E8 afterward: its output should be empty, provided the check reads
the span as covering the tags. If the check cannot read a span, add one `## Documented deviations`
row keyed `audit-review-history` pointing at the consolidated bundle, and raise the check's
span-blindness upstream (with A5).

### B8. Doc sync — `CM-94`, `CM-92`, `CM-75`, `CM-96`

- **`CM-94`.**
  - Fix `docs/ARCHITECTURE.md:324` and `docs/module-map.md:598` to list `LifecycleSetup` (and
    `LauncherSetup` in the module map).
  - Change `docs/module-map.md:642` and `docs/performance.md:46` to "after `core/LifecycleSetup.lua`".
  - Change the TOC comment at `ConsumableMaster.toc:76-77` from "second" to "after LifecycleSetup".
    This is a comment-only TOC edit, and the line itself does not move.
  - Replace `docs/ARCHITECTURE.md:418`'s line citations with a description of what the comments
    annotate.
- **`CM-92`.** Move `docs/ARCHITECTURE.md:455-504` (the peel narrative) out of the hub. It is
  history. Put one sentence per file in `docs/module-map.md`'s rows for the peeled files, or leave it
  in issues #32 and #33. Keep the census table, its load-bearing sentence (`:447`, which the kit's
  gate reads) and the band list. Optionally move the `### LibKa0s adoption` table (`:267-316`) to
  `docs/module-map.md` under a heading and leave a two-line summary plus one link. Target under ~420
  lines.
- **`CM-75`.** Expand the 46 bare `§N` continuations to `filename-§N`, using the E12 command to find
  them. Leave the `smoke-tests.md §N` and `TECHNICAL_DESIGN §4` references alone.
- **`CM-96`.** Add `modules/KCMItemRow.lua:96, :139` to the `compat` row's *What differs* cell.

### B9. Test-literal constant — `CM-93`

In `tests/test_harness.lua`, declare `local PING = "Ka0s_ConsumableMaster_HarnessPing"` once at the
top and use it at `:73-74`. Alternatively, rename the probe to a non-`Ka0s_` string, since the case
tests mock dispatch and not the namespace.

### B10. TOC conventional markers — `CM-83`

One comment line each above `locales\enUS.lua`, `modules\Ranker.lua`, and `settings\General.lua`
(covering the four page files). Comment-only, no line moves. Wording is in `02_DEVIATIONS.md`.

### B11. British spellings — `CM-80`, `CM-81`

- `docs/perf-analysis/README.md:25-26`: `analysed` → `analyzed`, `neighbours` → `neighbors`. This is
  the same change that re-vendors A1.
- `docs/settings-panel.md:80`: `synchronisation` → `synchronization`. This follows the re-vendor that
  carries A2.

---

## Ordering constraints

1. **A1 → B11 (`CM-80`)** and **A2 → B11 (`CM-81`)**. Re-vendor first so the gate turns red on the
   spellings, then fix them in the same commit.
2. **A3 → B3.** B3 cannot be done cleanly before the library parks registration. B2 does not wait,
   because its shape works with or without A3, and step 4 of B2 is the post-A3 follow-up.
3. **B1 before B2** in the same sprint. Both touch the disabled-state suite, and B1's re-enable
   assertion is a baseline B2's new case builds on.
4. **B4 after B1 and B2.** It reshapes `KCM:OnEnable`, which `standUp` calls. Change it after the
   disabled-state suite is extended, so the refactor lands under a test that would catch a missing
   registration.
5. **B7 is independent** and can land first. It is documentation only.
6. **Re-vendor LibKa0s whole** for A1, A2 and A3 (and A4 if taken), as one re-vendor commit with its
   own `docs/revendor/<date>-v<tag>/` bundle. That keeps `CM-91` from reopening.

## Risks

- **B3 touches page registration**, the most taint-sensitive path in the addon. Mitigation: the
  in-combat `/reload` smoke test (§6a), plus the two suite cases at
  `tests/test_settingsui_optionsui.lua:769, 778`, rewritten against the library seam.
- **`KCM:OnRegenEnabled` is at CCN 15.** B2 must extract rather than branch, or the next release
  run fails the tag gate (`automated-tests-§3`).
- **B1 adds protected calls to the disable path.** They are inside `MB.Update`'s existing combat
  gate, so this adds no new combat exposure.
