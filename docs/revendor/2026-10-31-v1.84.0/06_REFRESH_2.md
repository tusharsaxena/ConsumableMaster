# Refresh 2: the second v1.84.0 re-cut

The local tag moved again before its release was pushed. `git -C ../LibKa0s ls-remote --tags origin v1.84.0`
prints nothing, so this is a refresh and `01_DELTA.md` line 1 stands.

- Old commit: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5`, as `06_REFRESH_1.md` recorded it
- New commit: `b5229b876e803768322fb4d8c66be69f01c8e4a1` (`git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'`)
- Why it moved: `LK-M4`, the owner's ruling of 2026-11-01 to delete `lib.__PatchLSM30Border` with no stub.

## Per-file minors

| File | Constant | 7a8bc0f | b5229b8 |
|---|---|---|---|
| `Options.lua` | `MINOR` | 36 | 37 |
| `OptionsDrawer.lua` | `DRAWER_MINOR` | 3 | 4 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 2 | 3 |

`tests/_kit/` is unchanged. Every other file is byte-identical.

## Copy and prune

Both payloads copied whole from `git archive v1.84.0 LibKa0s testkit tools`. Both content diffs were empty
before the prune. `prune-icons.lua` kept 8 files and removed 5832, all from the copy, so no tracked icon
changed. The `LibKa0s icons:` line and the credits are unchanged.

## Contract change, fixed in this commit

This addon's code never called `__PatchLSM30Border`. One test did: `tests/test_settingsui.lua`, in
`Settings UI: an LSM30_Border another addon registered changes no media row`, asserted the no-op returned
nothing. That assertion is gone. The test stays, because the rest of it pins that the seeded slot is left
alone. No stub or guard was added.

The one remaining mention outside frozen docs is `libs/LibKa0s/Options.lua:46`, a history comment in the
vendored copy.

## Gate

luacheck 0 warnings / 0 errors in 146 files; `lua tests/run.lua` 1318 passed, 0 failed, 1 skipped.
