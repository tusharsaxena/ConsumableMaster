# 05 - Summary: LibKa0s v1.57.0 -> v1.58.0

## The move

Tag `v1.57.0` -> `v1.58.0` (`34931c9`), base taken from the `CLAUDE.md` provenance line and
confirmed against the last payload commit (`033a695`). Re-vendored in the M6-CM commit that carries
this bundle. One file moved a LibStub minor (`Launcher.lua` 3 -> 4), none was added or removed, and
no `NEEDS_*` floor rose. Test kit revision unchanged at 26.

## Delivered for free (class A)

- **Launcher minor 4**: left-click opens the settings panel on every host in either state, the
  tooltip's hints are fixed (`Open settings` / `Options menu`), and the right click opens the
  client's context menu built from the descriptor's pairs, grayed past *Enabled* while disabled,
  falling back to the panel where the client has no `MenuUtil`.

## Contract blockers

None (`01_DELTA.md` 3g). Four fields retired and are ignored if passed; the ten host cases that
pinned them were re-pinned in the same commit.

## Adopted

- **The minor-4 descriptor fields** in `core/LauncherSetup.lua`, as M6's owner ruling requires:
  `setEnabled` (`/cm enable|disable`'s body, published as `KCM.SlashCommands.Verbs.SetEnabled`) and
  `toggleLock` (`/cm lock|unlock`'s body, `Verbs.RunLock`), beside the existing `isEnabled` and
  `isLocked`. No test-mode or window pair: this addon has neither. `onClick`, `leftClickLabel` and
  `disabledLine` removed. The menu reads **Enabled · Locked**, matching `ADDONS.md`.
- Pinned through the library's own menu fake (`tests/mock_menu.lua`, copied): the entries and their
  order, read-at-open, each toggle routing to its slash handler (same body, same chat line), the
  gray while disabled, the no-`MenuUtil` fallback, left-click → panel in either state, and the
  descriptor carrying no retired or absent-state field. `Disabled 8` re-pinned to the new shape.

## Declined

None in this run.

## Skipped or unreached

- The interview (Step 6): the owner's M6 rulings decide the one adoption, and nothing else arrived.
- The in-client check: `docs/smoke-tests.md` 7c steps 2, 3 and 9, 14c, and the macro-bar 4a / 4c
  steps, for the owner's M6 re-check of the minimap buttons.

## Suite results

Every run from the repo root through `ka0s-bounded`. Tests are passed / failed / skipped; lint is
warnings / errors.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.57.0) | 1076 / 0 / 0 | 0 / 0 in 119 files | not run |
| After the copy and the adoption (v1.58.0) | 1078 / 0 / 0 | 0 / 0 in 120 files | no function above CCN 15 |
