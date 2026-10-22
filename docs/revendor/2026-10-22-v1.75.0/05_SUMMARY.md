# Summary (ConsumableMaster)

LibKa0s v1.71.0 -> v1.75.0 from the local annotated tag (`265a89e`, tag object `eae0ee5`, via
`git archive`; not yet pushed). The base comes from the CLAUDE.md provenance line and matches the
payload bytes of `b4060c3`. No span bundle: v1.72.0 to v1.74.0 were never vendored here.

In one commit, with both payloads:

- the CLAUDE.md provenance line rolls to v1.75.0, and directly under it the new declaration
  `LibKa0s icons: clear, close, copy, help, info, segment.`; the prose under them says "Those two
  lines", the whole-folder sentence carves out `media/icons/`, and the Gate paragraph names kit
  revision 41 and the crashed-run rule;
- `tools/prune-icons.lua` (from the tag export) cut `libs/LibKa0s/media/icons/` to the six TGAs
  and `LICENSE-open-iconic.txt` (5,833 files removed); `phosphor/` and `game-icons/` are gone;
- the two reds the copy raised are fixed: the Options MAJORS row gains `OptionsDrawer`, and the
  whole-catalog icon test is replaced by declaration-driven ones, plus a new source scan that goes
  red when a drawn icon is not declared (`01_DELTA.md`, blockers a to g);
- README gains `## Credits` (Open Iconic, MIT) as its last section; DEPENDENCIES.md,
  docs/ARCHITECTURE.md, docs/scope.md, docs/module-map.md, docs/testing.md and the
  `core/MediaSetup.lua` comment describe the declared-marks copy;
- docs/smoke-tests.md gains DIAG-42 (every declared mark draws after the prune), Result: pending;
- docs/test-cases.md is regenerated (Total 1216 -> 1217) and the README `[Tests]` badge moves to
  1217/1217.

No version bump and no CHANGELOG entry (CLAUDE.md hard rule). No documented-deviations change.

- **Adopted:** the icon declaration and prune; the Open Iconic credit.
- **Not adopted:** `W.SearchBox`, `W.TestStrip`, `W.StepPanel`, `Glow-1.0`, `Sim-1.0`,
  `Item.BonusIDsFromLink`, `O.Drawer`, `Perf.Note` `parentKey = false`, `Kit.assertLatchHoldOrder`,
  `Media.ICON_SETS` / `IconAuthor` (`02_CANDIDATES.md`).
- **Declined / issues filed:** none.

Gate after the copy:

- tests (`ka0s-bounded lua5.1 tests/run.lua`): 1217 passed, 0 failed, 1 skipped, 1218 total,
  `test_vendor_sync` green against v1.75.0 with the declaration.
- luacheck (`ka0s-bounded luacheck .`): 0 warnings / 0 errors in 130 files.
- 1500-line cap: largest authored file `settings/MacroBar.lua` at 1182 lines.

Owner smoke owed: DIAG-42 (re-runs DIAG-10, DIAG-21, DIAG-31, BAR-9, BAR-10, BAR-16, PRIO-8,
PRIO-14).
