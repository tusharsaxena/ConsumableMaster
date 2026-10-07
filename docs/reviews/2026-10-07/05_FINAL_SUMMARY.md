# 05 — Final summary (written as if `03_SMOKE_TESTS.md` passed)

## Headline

This cycle fixes two bugs that put the wrong item in a player's consumable macro, plus a set of smaller problems.

- **Different profiles on different characters.** The macros are shared by the whole account, but the addon remembered what it
  had written separately for each profile. A character arriving after another one could keep the other character's macros, and a
  macro the player deleted was never recreated. The addon now checks the macro it actually finds before deciding there is nothing
  to write.
- **Devourer Demon Hunters.** The Devourer spec had no stat priority, so the addon treated it as an Agility spec.

The smaller fixes:

- A respec now picks up consumables already in the bags.
- The macro bar no longer ranks every item a second time on each refresh.
- `/cm priority` now refuses malformed item IDs.
- The composite macros and their flyouts now read one shared definition of their settings.

## Counts

Critical fixed: 0, High fixed: 2, Medium fixed: 2, Low fixed: 4. Nothing was deferred.

## Changes by theme

### T1 — Trust the live macro over the fingerprint
- **What changed.** Before skipping a write as "unchanged", `MacroManager` now reads the account's actual macro body. It skips only
  when the macro exists and holds exactly the body it would write.
- **Why it mattered.** Per-character profiles left one character running another character's picks. A deleted macro stayed deleted.
- **Findings / changes.** F-001 / C-01.
- **Files.** `modules/MacroManager.lua`, `tests/test_macromanager.lua`, `tests/test_profiles.lua`, `docs/macro-manager.md`.

### T2 — Devourer stat priority
- **What changed.** A seed row for `12_1480` (Intellect, with an archon.gg secondary order). The seed test now checks every playable
  spec, not every class.
- **Why it mattered.** Devourer ranked Agility first and every secondary stat at zero.
- **Findings / changes.** F-002, F-008 / C-02.
- **Files.** `defaults/Defaults_StatPriority.lua`, `tests/test_defaults.lua`.

### T3 — One score cache per bar refresh
- **What changed.** The flyout rebuild shares one score cache across all 15 slots in a refresh.
- **Why it mattered.** The flyout rebuild was about 121 KB of the 226.7 KB each out-of-combat recompute allocated, and it re-parsed
  tooltips the pass had just parsed.
- **Findings / changes.** F-003 / C-03.
- **Files.** `modules/MacroBar.lua`, `modules/MacroBarFlyout.lua`, `tests/test_macrobar_flyout.lua`, optionally `tests/perf.lua` and
  `docs/performance.md`.

### T4 — Discover on a spec change
- **What changed.** A respec runs the bag discovery pass before recomputing. Other units' spec changes are ignored.
- **Why it mattered.** Unseeded spec-aware items were invisible to the new spec until the bags changed.
- **Findings / changes.** F-004, F-007 / C-04, C-07.
- **Files.** `core/ConsumableMaster.lua`, `docs/data-flow.md`, `tests/test_pipeline.lua`, `tests/test_events.lua`.

### T5 — Hygiene
- **What changed.** One published composite-config resolver, and strict ID parsing in the slash editor.
- **Findings / changes.** F-005, F-006 / C-05, C-06.
- **Files.** `modules/MacroManager.lua`, `modules/Selector.lua`, `core/SlashCommands.lua`, `tests/test_selector.lua`,
  `tests/test_slash.lua`.

## API / behavior changes

- `/cm priority <cat> add|remove|…` now rejects `0`, negative, fractional, hex and exponent tokens. Use `s:<spellID>` for spells.
- `MacroManager.CompositeConfig(cat)` is newly published (internal). With a missing composite bucket (unreachable on AceDB defaults),
  the flyout now lists nothing, which matches the empty macro body.
- No new slash verbs, settings rows, events or saved-variable keys.

## Saved-variable / migration notes

None. `macroState` keeps its shape. The added seed row is shipped data, not a stored value.

## Deprecated-API migrations

None. The review found no bare deprecated global outside a guarded fallback rung.

## Performance impact

The before figures come from today's offline attribution (collector stopped, `tests/perf.lua`'s loader):

- `MacroBar.Refresh`: 142727.7 B and 107 `GetItemByID` calls per refresh.
- `Pipeline.Recompute`: 226715.5 B per pass.

The after figures are **to be filled from CP2's re-run**. No estimate is written here.

## Test and complexity movement

- **Pass count.** 1201 / 1202 before. After: +3 (C-01), +0 net (C-02 renames one case), +1 (C-03), +1 (C-04), +1 (C-05), +1 (C-06),
  +1 (C-07). That is about 1209 / 1210, to be read off the final `--list`.
- `docs/test-cases.md` and the README `[Tests]` badge moved in each commit.
- **Expected watch-list movement.** `compositeRefs` (CCN 15 today) should drop. Confirm this at the next release's regeneration of
  `docs/automated-tests/RESULTS.md`, which is 59 commits stale today.

## Known follow-ups

- **Flyout rebuild only when its inputs changed.** A larger invalidation design. The cache in T3 removes the duplicate work first.
- **Devourer secondary order.** It comes from one archon.gg snapshot. Refresh it with the rest of the table each season.

## Verification evidence

- `03_SMOKE_TESTS.md` with its sign-off table filled.
- The commit range on `feat/2026-10-07-review-audit-remediation`, F-001 .. F-006.

## Suggested PR description

```
ConsumableMaster: review remediation (2026-10-07)

- F-001: confirm the live account macro before skipping a write; fixes per-character
  profiles keeping another character's macro bodies, and deleted KCM macros never
  being recreated
- F-002 + F-008: seed Devourer DH (12_1480, INT); stat seed test now per spec
- F-003: one score cache per macro-bar refresh (flyout rebuild was ~121 KB of a
  226.7 KB pass)
- F-004 + F-007: discovery on spec change; ignore groupmates' spec changes
- F-005: one composite-config resolver (characterization first)
- F-006: strict IDs in /cm priority

Tests: 1201/1202 -> <final>/<final>; docs/test-cases.md and the [Tests] badge moved per commit.
No version bump.
```
