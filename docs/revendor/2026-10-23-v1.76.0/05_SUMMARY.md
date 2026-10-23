# Summary (ConsumableMaster)

LibKa0s v1.75.2 -> v1.76.0 from the local annotated tag (`9949368`, tag object `546e284`, via
`git archive`; not yet pushed). The base comes from the CLAUDE.md provenance line and matches the
payload bytes of `485f52f`. Span bundle `docs/revendor/2026-10-23-v1.75.1-v1.75.2/` (two tags)
records the two patch re-vendors that had none.

Per-file minors: `Widgets.lua` 13 -> 14, `SimTimeline.lua` 2 -> 3, `SimPanel.lua` 4 -> 5; every
other file and the test kit (revision 41) unchanged.

In one commit, with both payloads:

- the CLAUDE.md provenance line rolls to v1.76.0; the `LibKa0s icons:` line under it is kept
  (`clear, close, copy, help, info, segment.`);
- `tools/prune-icons.lua` (from the tag export) cut `libs/LibKa0s/media/icons/` back to the six
  Open Iconic TGAs and `LICENSE-open-iconic.txt` (5,833 files removed, all from the copy; no set
  changes, so the README `## Credits` stays as it is);
- no contract blocker, no whole-catalog test, no dead stub mirror.

- **Delivered:** Widgets 14 (no surface CM calls moved); Sim 2.3.5 (not consumed here).
- **Adopted:** nothing (the run assigns CM no adoption).
- **Not adopted:** `W.TestStrip` `kind = "sim"` / `strip.kind` (`02_CANDIDATES.md`).
- **Declined / issues filed:** none.

The standard reference (TOC `X-Standard`, README badge, CLAUDE.md `## Standards compliance`) was
checked against the local standard v2.87.0 in the same item: all three present and canonical, no
retired `§N.M` notation outside frozen bundles, no out-of-range `filename-§N` citation. Nothing to
change; the reference carries no version by design.

Gate after the copy:

- tests (`ka0s-bounded lua5.1 tests/run.lua`): 1217 passed, 0 failed, 1 skipped, 1218 total,
  `test_vendor_sync` green against v1.76.0 with the declaration (after the `docs/smoke-tests.md`
  working-tree repair noted in `01_DELTA.md`).
- luacheck (`ka0s-bounded luacheck .`): 0 warnings / 0 errors in 130 files.
- 1500-line cap: largest authored file `settings/MacroBar.lua` at 1182 lines.

No version bump and no CHANGELOG entry (CLAUDE.md hard rule). No smoke check owed: no code path
CM runs changed.

## Addendum: the tag moved (CM-RV2)

The local tag v1.76.0 was moved from `9949368` to `7e81ff7` (tag object `2949c78`) for LK-91,
which bounds step-panel labels before the command column so a long label truncates with an
ellipsis instead of running under the slash command (owner report 2026-10-23, BankLedger
`/bl sim`). Both payloads were copied whole again from the moved tag through `git archive`, and
the tag's `tools/prune-icons.lua` cut `media/icons/` back to the same six declared TGAs and
`LICENSE-open-iconic.txt` (5,833 removed). The provenance line already read v1.76.0 and is kept.

Files that changed against the CM-RV copy:

- `libs/LibKa0s/PerfPanel.lua`: panel minor 7 -> 8 (Perf key 15.1.1.7 -> 15.1.1.8), label
  anchored on both sides with word wrap off. CM consumes Perf (`core/PerfSetup.lua`), so its
  `/cm perf` step panel gets the fix; no CM code or test changed.
- `libs/LibKa0s/SimPanel.lua`: same label bound, minor unchanged at 5 (already bumped in the
  unpublished v1.76.0). Not consumed here.
- Test kit unchanged (revision 41).

Gate after the second copy: luacheck 0 warnings / 0 errors in 130 files; `lua5.1 tests/run.lua`
1217 passed, 0 failed, 1 skipped (`test_vendor_sync` green against the moved tag); largest
authored file `settings/MacroBar.lua` at 1182 lines. No version bump, no CHANGELOG entry.
