# 05 - Summary: LibKa0s v1.56.0 -> v1.57.0

## The move

Tag `v1.56.0` -> `v1.57.0` (`aa37bc9`), base taken from the `CLAUDE.md` provenance line and
confirmed against the last payload commit (`389e0f0`). Re-vendored in the M5-CM commit that carries
this bundle. One file moved a LibStub minor (`Launcher.lua` 2 -> 3), none was added or removed, and
no `NEEDS_*` floor rose. Test kit revision unchanged at 26.

## Delivered for free (class A)

- **Launcher minor 3**: the library always draws the status tooltip on the minimap button and the
  broker plugin, including while the addon is disabled.

## Contract blockers

None (`01_DELTA.md` 3g). `onTooltipShow` changed meaning, and this addon never passed it.

## Adopted

- **The minor-3 descriptor fields** in `core/LauncherSetup.lua`, as M5's owner ruling requires:
  `version` (`KCM.Version()`), `isLocked` (the macro bar's `macroBar.locked`), and `leftClickLabel`
  (`L["Lock frame"]` / `L["Unlock frame"]`, following the lock). No `isTestMode` (this addon has
  none), no `slash` (read out of `disabledLine()`), no `onTooltipShow` (no lines of its own).
  Pinned by five new cases in `tests/test_launcher.lua`: the descriptor, the enabled shape, the lock
  read on every show, the disabled state, and the label through `KCM.L`.

## Declined

None in this run.

## Skipped or unreached

- The interview (Step 6): the owner's M5 rulings decide the one adoption, and nothing else arrived.
- The in-client check: `docs/smoke-tests.md` 7c step 9, for the owner's M5 smoke re-run.

## Suite results

Every run from the repo root through `ka0s-bounded`. Tests are passed / failed / skipped; lint is
warnings / errors.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.56.0) | 1071 / 0 / 0 | 0 / 0 in 119 files | not run |
| After the copy and the adoption (v1.57.0) | 1076 / 0 / 0 | 0 / 0 in 119 files | no function above CCN 15 |
