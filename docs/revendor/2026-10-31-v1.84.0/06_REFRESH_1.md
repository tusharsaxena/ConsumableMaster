# Refresh 1: the v1.84.0 re-cut

The local tag moved before its release was pushed. `git -C ../LibKa0s ls-remote --tags origin v1.84.0`
prints nothing, so this is a refresh and `01_DELTA.md` line 1 stands.

- Old commit: `e917ccd`, as `01_DELTA.md` recorded it
- New commit: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` (`git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'`)
- Why it moved: `LK-M3`, the owner's ruling of 2026-11-01 that `Ka0sMedia_*` is the only media picker
  (LibKa0s#73).

## Per-file minors

| File | Constant | e917ccd | 7a8bc0f |
|---|---|---|---|
| `Options.lua` | `MINOR` | 35 | 36 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 40 | 41 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 1 | 2 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 15 | 16 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 9 | 10 |
| `SkinAce.lua` | `ACE_MINOR` | 5 | 6 |

`tests/_kit/` is unchanged at kit revision 47. Every other file is byte-identical.

## Copy and prune

Both payloads copied whole from `git archive v1.84.0 LibKa0s testkit tools`. Both content diffs were empty
before the prune. `prune-icons.lua` kept 8 files and removed 5832, all from the copy, so no tracked icon
changed. The `LibKa0s icons:` line and the credits are unchanged.

## Contract changes, fixed in this commit

The change the new changelog names as owed at the re-vendor: a test pinning `LSM30_*` on a composed row, or
expecting `__PatchLSM30Border` to wrap. Two tests here did both, and went red on the copy:

- `tests/test_macrobar.lua`, `macrobar schema: border rows are populated from LibSharedMedia`, now pins
  `Ka0sMedia_Border`;
- `tests/test_settingsui.lua`, the Border fixup case, is rewritten as
  `Settings UI: an LSM30_Border another addon registered changes no media row`.

No host-supplied member's call site moved. This addon never calls `AceGUI:Create("LSM30_*")`.

## Gate

Before the test fixes: luacheck 0 warnings / 0 errors in 146 files; `lua tests/run.lua` 1315 passed, 2 failed
(the two above), 1 skipped. After them: luacheck 0 / 0 in 146 files; 1317 passed, 0 failed, 1 skipped.
