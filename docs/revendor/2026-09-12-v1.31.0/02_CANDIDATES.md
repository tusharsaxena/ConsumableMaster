# 02 — Candidates: LibKa0s v1.31.0

Sources: `git -C ../LibKa0s log --oneline v1.30.0..v1.31.0` (five commits, 5193ebe..30db4ed), the
`## v1.31.0` block of the tag's `CHANGELOG.md`, `docs/api/Options/version-15.15.4.3-docs.md` and
`docs/api/testkit/version-17-docs.md`.

## Class A — reached this addon on the re-vendor alone

- **OptionsWidgets minor 15.** A row with no `path` reads and writes through its own `get` / `set`.
  The gate is `path == nil` (CHANGELOG v1.31.0, *`OptionsWidgets.lua` minor 15*), and every row this
  addon registers carries a path, so every maker and refresher behaves exactly as at minor 14. The
  suite total did not move on the copy (824 before and after).
- **OptionsCompose minor 4, for path-keyed callers.** CHANGELOG v1.31.0 says path-keyed callers are
  "byte-for-byte unaffected", pinned upstream by `tests/fixture_compose_golden.lua`. This addon's
  composer calls (the Master controls block, the font / border / color blocks) are all path-keyed.

## Class B — host change required

1. **Kit revision 17's Ace surfaces** (`version-17-docs.md`, *For the six migrations*, the
   ConsumableMaster paragraph). They reach nothing until `tests/wow_mock.lua` stops replacing the
   kit's AceAddon, AceEvent, AceConsole and AceGUI. Files: `tests/wow_mock.lua`, `tests/run.lua`, a new
   `tests/test_harness.lua`, and the test ports the document names (`M.busReg` becomes
   `M.__msgRegistry`; nothing in this suite read `busReg`). Blast radius: **replaces** harness code
   this repo owned. Recommendation: adopt. That is owner decision 3 in the triage brief and issue #38
   option 1.
2. **`spec.bind`, the record-backed composer arm** (`version-15.15.4.3-docs.md`; CHANGELOG
   *`OptionsCompose.lua` minor 4*). It exists for a page that edits registry records. Every block this
   addon composes edits profile rows by path, and none of its settings pages edits a registry record
   through a composer. Recommendation: not applicable. There is nothing to bind.

## Class C — whole-module adoption

- **Pool** ships unused, as at v1.30.0. Nothing in v1.31.0 touches Pool (its minor is still 3), so
  nothing about that premise moved.
