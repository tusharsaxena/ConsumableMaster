# 04 — Execution plan: the copy, then the tooltip

Two commits.

## Commit 1 — the re-vendor

1. Extract the tag into a scratch directory:
   `git -C ../LibKa0s archive v1.34.0 LibKa0s testkit | tar -x -C <scratch>/`.
2. Measure before touching anything: per-file minors (`01_DELTA.md`), and the content and byte diffs
   of both payloads.
3. Write the Slash minor 10 pin first (`tests/test_slashsetup.lua`) and run it on the v1.33.0
   payload: red, `Invalid value for macroBar.labelFont … (expected JetBrains Mono, got Friz Quadrata
   TT)`.
4. Change the harness's AceDB `fire` to pass exactly what each event was given, so a reset carries no
   key, and run the suite: 872 / 0 / 0, nothing moved.
5. Replace both payloads whole, so a file deleted upstream would be deleted here too:
   ```sh
   rsync -r --delete --checksum <scratch>/LibKa0s/ libs/LibKa0s/
   rsync -r --delete --checksum <scratch>/testkit/ tests/_kit/
   ```
6. Check all four diffs are empty, and `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s`
   too. Check the runner's index mode is still 100755 (`git ls-files -s`).
7. Roll the provenance line (`CLAUDE.md:58`) in the same commit as the bytes, and the geometry-flip
   note in `docs/smoke-tests.md:555` to revision 20.
8. Regenerate `docs/test-cases.md` and move the README badge to 873.
9. Gate: `lua tests/run.lua`, `luacheck .` and `lizard -C 15`, then CRLF verified on every text file
   the commit touches. `tests/_kit/` and `libs/` are byte copies, left exactly as extracted.

## Commit 2 — the Reset-all tooltip

1. Write the case first: the General page's *Reset all settings* button, hovered, shows the
   `RESET_ALL_TIP_PROFILES_PAGE` text, and the descriptor's `resetProfile` is `db:ResetProfile()`.
   Red on the descriptor as it stood.
2. Add `resetProfile = function() KCM.db:ResetProfile() end` and `profilesPage = true` to the
   descriptor in `settings/OptionsSetup.lua`.
3. Update `docs/settings-panel.md` and `docs/smoke-tests.md` where the button is described, and the
   `skipRestoreAll` notes that said the library never walks with it.
4. Regenerate `docs/test-cases.md`, move the badge, gate, CRLF.

## Not done, on purpose

- No file under `libs/LibKa0s/` or `tests/_kit/` was edited by hand. A fix belongs upstream.
- `KCM.ResetAllToDefaults` is not replaced by the library's `O.RestoreAllDefaults`. The descriptor
  carries no `allRows` or `applyDefault`, so that walk cannot run here, and the addon's own function
  already is the act §12 describes. Adopting the walk is a separate change nobody asked for.
