# Changelog

All notable user-visible changes to ConsumableMaster, newest first.

This file starts at the first change that needed one — a breaking change to a
slash command. Releases 1.0.0 through 1.5.0 predate it; their highlights are in
the README's Version History table, which stays the canonical per-release
summary. What lands here is the detail a release row is too short to carry.

## Unreleased

### Breaking

- **`/cm reset` no longer wipes everything. It now resets ONE setting, and the
  global wipe moved to `/cm resetall`.**

  `/cm reset <path>` puts a single settings row back to its default, e.g.
  `/cm reset macroBar.orientation`. It touches nothing else — your priority
  lists, pins and stat overrides are not in its scope at all.

  `/cm resetall` is the old command under a new name, unchanged in every other
  respect: same wording, same confirmation dialog, same wipe. The **Reset all
  priorities** button on the General settings page is unaffected and always
  was the other way to reach it.

  **If you have `/cm reset` in a macro or a keybind, change it to
  `/cm resetall`.** A bare `/cm reset` prints a usage line that says so rather
  than doing either thing, so nothing is destroyed by the change — the risk
  runs the safe way. This brings `/cm` in line with `/at reset <path>` and
  `/kcd reset <path>` across the Ka0s addons, where `reset` has always taken a
  settings path.

  Recorded as LIBKA0S-12 in `docs/pending/LEDGER.md`.
