# Summary (ConsumableMaster)

LibKa0s v1.65.0 -> v1.66.0 from the local tag (`e4c5ef7`, tag object `178ee0b`), base taken from the
CLAUDE.md provenance line and confirmed against the payload bytes. Widgets 11 -> 12 with the new
WidgetsReorder 1, DebugLog 18 -> 19, Slash 18 -> 19 with the new SlashParse 1, OptionsWidgets
33 -> 34, OptionsTabs 7 -> 8, Perf 13 -> 14 with the new PerfSampler 1 and PerfCommands 1; kit
revision 34 -> 35. No file removed, no floor raised, no blocker, no base correction. CLAUDE.md
provenance rolled in the same commit as both payloads.

Span bundle written beside this one: `2026-10-01-v1.64.0-v1.65.0/` (two tags carried by sweeps
with no bundle).

Delivered free (class A): the Widgets, Slash, Perf and DebugLog peels with no member moved, and
RenderGrid's no-space failed item. Adopted: nothing in this commit; B1 (the Slash resolver) is this
plan's GI-CM-01. B2-B4 left unreached for the census (GI-LK-13). Nothing declined, nothing filed.

Consumer fix in the same commit: `tests/test_libka0s.lua`'s MAJORS inventory names the three new
secondary files (`SlashParse`, `PerfSampler`, `PerfCommands`) with their pairing fields; without it
the stray-file case reads them as files registered under a major they do not belong to.

Kit 35 wiring: `{ name = "test_lizard_sighted", dir = "tests/_kit/" }` in `tests/run.lua`. The
green-gate and toolchain lines that quoted raw lizard (CLAUDE.md, DEPENDENCIES.md, docs/testing.md,
docs/automated-tests/README.md) now name the sighted suite.

Gate after the copy:

- tests: 1168 passed, 0 failed, 1 skipped, 1169 total (1160 / 0 / 1 / 1161 before; the eight new
  cases are the kit's `test_lizard_sighted`)
- luacheck: 0 warnings / 0 errors in 129 files
- both payloads `diff -r` clean against the tag after the copy
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity`): 3120 functions,
  maxCcn 18, warnings 2 (`mergePins` modules/Selector.lua 18, `renderSlotList` settings/MacroBar.lua
  16), blindFiles 0. The two warnings are GI-CM-02's.
