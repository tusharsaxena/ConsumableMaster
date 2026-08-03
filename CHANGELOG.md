# Changelog

All notable user-visible changes to ConsumableMaster, newest first.

This file starts at the first change that needed one — a breaking change to a
slash command. Releases 1.0.0 through 1.5.0 predate it; their highlights are in
the README's Version History table, which stays the canonical per-release
summary. What lands here is the detail a release row is too short to carry.

## Unreleased

### Changed

- **All English text in this addon is now US English spelling**, per the Ka0s
  WoW Addon Standard v2.17.1 (`localization-§5`). Nothing a player reads
  changed — no locale key, no locale value, no chat line, no settings label
  and nothing in the `.toc` carried a British spelling to begin with. What
  moved was source comments, one test name, and the documentation under
  `docs/`: `colour`→`color`, `behaviour`→`behavior`, `grey`→`gray`,
  `neighbour`→`neighbor`, `levelling`→`leveling`, `-ise`/`-isation`→`-ize`/
  `-ization`. Blizzard item names (`Draught of Rampant Abandon`,
  `Braised Blood Hunter`) and the vendored `tests/_kit/` copy are reproduced
  verbatim and were left alone.

- **The slash-command list on the settings About page is spaced slightly
  differently.** The command and its description are now separated by a single
  space either side of the dash instead of two, the dash itself is no longer
  white, and the description is. Nothing was added or removed from the list.

  The reason is that the About page and `/cm help` were drawing the same list
  through two different bits of code, so a change to one of them silently
  stopped matching the other. They now share one, which is also what the other
  Ka0s addons' command lists look like. Recorded as LIBKA0S-13 in
  `docs/pending/LEDGER.md`.

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
