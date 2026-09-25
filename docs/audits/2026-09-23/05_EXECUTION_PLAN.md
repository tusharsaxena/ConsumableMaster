# 05 — Execution plan

**Addon:** Ka0s Consumable Master · **Audit:** 2026-09-23 · **Standard:** v2.64.0 · **Commit:** `7adfea1`

This plan hands the work to a separate remediation engagement, which executes it. The steps are
ordered and each one can be checked off. Every step names its deviation ID(s) and its design section
in `04_TECHNICAL_DESIGN.md`.

**Upstream first.** Sprint 0 lands in `WowAddonStandards` and `LibKa0s`, and Sprint 1 re-vendors
LibKa0s whole. The addon's own sprints follow.

**What counts as done** is fixed and does not move between sprints:

- `$B luacheck .` reports 0/0.
- `$B lua tests/run.lua` reports every case passing and 0 skipped.
- Both `diff -r` runs against the tag in `CLAUDE.md` are empty.
- Where the step touches docs, the E8, E11, E12 and E15 commands in `03_EVIDENCE.md` return the
  expected results.

**The figures below** are the same ones used in `02_DEVIATIONS.md`: 16 roots and 18 in total;
1 High, 2 Medium, 11 Low and 2 Info among the roots; 11 MUST roots and 13 MUST failures including
dependents; 27 unrecorded tags; 46 bare `§N` citations in 22 files; a 504-line hub.

---

## Sprint 0 — Upstream (WowAddonStandards, LibKa0s)

- [ ] **S0-1** · `CM-81` · A2. In `WowAddonStandards`, add `"synchronis"` to `localization-§5`'s
  `BRITISH` list (91 → 92) and write a changelog entry. Check admissibility: no US word contains it.
- [ ] **S0-2** · `CM-79`, `CM-81` · A1, A2.
  - In `LibKa0s/testkit/test_prose.lua`, replace the whole-store skips of `docs/automated-tests/` and
    `docs/perf-analysis/` with dated-bundle skips, so the store root files are scanned.
  - Sync `BRITISH` from S0-1 and set `PUBLISHED_BRITISH` to 92.
  - Add a self-test that fails when a store-root README carries a British spelling.
- [ ] **S0-3** · `CM-88` (enables the post-A3 half of `CM-86`) · A3.
  - `LibKa0s-Options-1.0`: `O.CreateOptionsPanel()` refuses and parks under `InCombatLockdown()`.
  - Add `O.ReplayPending()`.
  - `O.OpenOptionsPanel()` returns a boolean.
  - Add library tests for park, replay and idempotence.
- [ ] **S0-4** · `CM-87` · A4 (**optional**, the owner's call). A `pcall`ed `SafeRegister` helper on
  `LibKa0s-Core-1.0` that records rejected names. If declined, B4 stays host-local.
- [ ] **S0-5** · `CM-91` (process) · A5. Raise upstream that `AUDIT.md` grades the re-vendor check
  High against step 5's impact table, and that the check cannot read a consolidated span bundle.
- [ ] **S0-6** · Tag the LibKa0s release that carries S0-2 and S0-3 (and S0-4 if taken). Its
  `CHANGELOG.md` names both kit and Options minors.

## Sprint 1 — Re-vendor LibKa0s whole

- [ ] **S1-1** · `CM-79`, `CM-80`, `CM-81`. Copy both payloads (`LibKa0s/LibKa0s` →
  `libs/LibKa0s/`, `LibKa0s/testkit` → `tests/_kit/`) at the new tag, whole-folder. Roll
  `CLAUDE.md:61` to the new tag **in the same commit**. Write
  `docs/revendor/<date>-v<tag>/01_DELTA.md` … `05_SUMMARY.md` (this keeps `CM-91` from reopening).
- [ ] **S1-2** · `CM-80`, `CM-81` · B11. The suite now fails on the three spellings. Fix
  `docs/perf-analysis/README.md:25` (`analysed` → `analyzed`), `:26` (`neighbours` → `neighbors`)
  and `docs/settings-panel.md:80` (`synchronisation` → `synchronization`) in the same commit. Check:
  the gate passes, and E11's grep returns nothing.
- [ ] **S1-3** · Run the E2 `diff -r` pair against the new tag. Both must be empty.

## Sprint 2 — The disabled state (the two Medium findings)

- [ ] **S2-1** · `CM-84` · B1.
  - Add `FO.StandDown` / `FO.StandUp` and a module-level `FLYOUT_COMBAT_DRIVER` to
    `modules/MacroBarFlyout.lua`.
  - Call `FO.StandDown` for every built flyout from `MB.Update`'s disable branch
    (`modules/MacroBar.lua:453-460`), and re-arm the flyouts on the enable path.
- [ ] **S2-2** · `CM-85` · B1. In `tests/test_disabled.lua`, step 4 asserts that `kcmCombat` is set
  before the disable and absent from every flyout after it, and step 9 asserts it is back. Add the
  falsification comment. Check: the case fails with S2-1 reverted and passes with it applied.
- [ ] **S2-3** · `CM-86` · B2.
  - Extract `replayParkedRegistration()` and call it before `KCM:OnRegenEnabled`'s stood-down
    return.
  - Add `KCM.EnsureRegenForParkedSettings()`, called from `registerPanel`'s park branch.
  - Check: `lizard` reports `KCM:OnRegenEnabled` at or below CCN 15.
- [ ] **S2-4** · `CM-86` · B2. Add two cases beside `tests/test_settingsui_optionsui.lua:778`: a
  disabled addon parks and replays, with the stand-down both out of combat and in combat. Add the
  falsification comment. Add one row to `docs/ARCHITECTURE.md` → *What SURVIVES*.
- [ ] **S2-5** · Smoke test: `docs/smoke-tests.md` §6a (in-combat `/reload`) with the addon
  **disabled**, and §11e (flyout closing) with it enabled.

## Sprint 3 — Registration robustness and the settings open

- [ ] **S3-1** · `CM-87` · B4.
  - Add a module-level `EVENTS` list, a `safeRegister` behind `pcall` (with `IsEventValid`
    front-gating) and `KCM.RejectedEvents`.
  - Surface the rejected names in `[Init]` and in `/cm dump events`.
  - Add a suite case using `mock.__badEvents`, and point `tests/test_disabled.lua` step 1 at
    `KCM.EVENTS`.
  - Add a note to `docs/midnight-quirks.md`.
- [ ] **S3-2** · `CM-88` · B3 (**requires S0-3 and S1-1**).
  - `KCM.Options.Open` → `UI.OpenOptionsPanel()`.
  - `registerPanel` → `UI.CreateOptionsPanel()` with `buildMain` and `RegisterOptionsPage`.
  - Delete `expandMainCategory` and `KCM._settingsCategoryID`.
  - Extend the Options stub and let `tests/test_surface_parity.lua` pin it.
  - Rewrite the two registration cases against `UI.ReplayPending()`.
  - Check with the full suite, then smoke tests §6a and `/cm config`, bare `/cm` and the launcher's
    right-click, all in and out of combat.
- [ ] **S3-2 (alt.)** · `CM-88`. If S0-3 is declined, add a `## Documented deviations` row keyed
  `options-ui-§2`, give its Why, today's date and the trigger "the options library parks
  registration in combat", and skip S3-2.

## Sprint 4 — Records and docs (all Low / Info; no code)

- [ ] **S4-1** · `CM-91` · B7. Write the consolidated re-vendor bundle for v1.18.0 → v1.53.0 (27
  tags). Re-run E8. If the check still lists the span, add the `audit-review-history` register row
  pointing at the bundle.
- [ ] **S4-2** · `CM-90` · B6. Retire the `preview-mode` register row (`docs/ARCHITECTURE.md:416`)
  and add the prose retirement line under the table. The owner may instead re-decide the row against
  v2.49.0's text.
- [ ] **S4-3** · `CM-89` · B5. Delete `README.md:35-38` (`## What's new in 1.6.2`) and run the de-AI
  pass over the edit.
- [ ] **S4-4** · `CM-94` · B8. Fix the six load-order statements:
  - `docs/ARCHITECTURE.md:324` and `:418`
  - `docs/module-map.md:598` and `:642`
  - `docs/performance.md:46`
  - the `ConsumableMaster.toc:77` comment (comment only, the line does not move)
- [ ] **S4-5** · `CM-83` · B10. Add conventional-group comments above `locales\enUS.lua`,
  `modules\Ranker.lua` and `settings\General.lua`.
- [ ] **S4-6** · `CM-92` · B8. Move the peel narrative (`docs/ARCHITECTURE.md:455-504`) out of the
  hub. Optionally move the `### LibKa0s adoption` table to `docs/module-map.md`. Keep the census
  table and the sentence at `:447` exactly as the kit's `test_layout_cap` reads them. Check: the hub
  is at or under ~420 lines and `layoutcap:` passes.
- [ ] **S4-7** · `CM-75` · B8. Expand the 46 bare `§N` continuations. Check: E12's bare count is 0
  outside the out-of-scope references it lists.
- [ ] **S4-8** · `CM-93` · B9. Replace the test literal in `tests/test_harness.lua:73-74` with a
  file-local constant, or rename it to a non-`Ka0s_` probe.
- [ ] **S4-9** · `CM-96` · B8. Add `modules/KCMItemRow.lua:96, :139` to the `compat` register row.
- [ ] **S4-10** · `test-cases.md` and the badge. Regenerate `docs/test-cases.md`
  (`lua5.1 tests/run.lua --list`) and update `README.md:7`'s `Tests-X/Y` in the same commit as any
  case count change from Sprints 2–4 (a `CLAUDE.md` hard rule).

## Sprint 5 — Release checkpoint (only when the owner cuts a release)

- [ ] **S5-1** · `CM-95`. Run the full automated-test bundle with the verbatim `lizard` invocation.
  `RESULTS.md` is regenerated, which clears the stale band rows and the reference to the deleted
  `tests/test_layout_cap.lua`. Write `ANALYSIS.md`, which is required at release. Check the tag
  gate: four suites `pass`, 0 functions above CCN 15.

---

## Traceability

| ID | Grade | Step(s) |
|---|---|---|
| CM-91 | High | S0-5, S1-1, S4-1 |
| CM-84 | Medium | S2-1, S2-5 |
| CM-85 | Low (derived from CM-84) | S2-2 |
| CM-86 | Medium | S2-3, S2-4, S2-5 (S3-2 follow-up) |
| CM-87 | Low | S0-4 (opt.), S3-1 |
| CM-88 | Low | S0-3, S3-2 / S3-2 alt. |
| CM-89 | Low | S4-3 |
| CM-90 | Low | S4-2 |
| CM-92 | Low | S4-6 |
| CM-93 | Low | S4-8 |
| CM-94 | Low | S4-4 |
| CM-75 | Low | S4-7 |
| CM-79 | Low | S0-2, S1-1 |
| CM-80 | Low (derived from CM-79) | S1-2 |
| CM-81 | Low | S0-1, S0-2, S1-2 |
| CM-83 | Low | S4-5 |
| CM-95 | Info | S5-1 |
| CM-96 | Info | S4-9 |
