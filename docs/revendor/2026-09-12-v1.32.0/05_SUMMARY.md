# 05 — Summary: LibKa0s v1.31.0 → v1.32.0

## The move

| | |
|---|---|
| From | v1.31.0 (e7e1962) |
| To | **v1.32.0** (tag object f5f41c9 on e18dd12, local to `../LibKa0s`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (MINOR 15 → 16), `Slash.lua` (MINOR 7 → 8) |
| Kit revision | 17 (unchanged) |
| Files removed upstream | none |
| Cross-major skew found | none |
| Provenance line | `CLAUDE.md:58` rolled to v1.32.0 in the same commit as the payload (a6be378) |

## What reached this addon for free

Nothing observable. Both brackets are optional descriptor fields, this addon supplies neither, and
the library never runs a reset walk here. The suite total stayed at 838.

## What was adopted

The bracket's shape, in the host: `Helpers.Bulk`, `Helpers.MuteSetLog` and `SetManyAndRefresh`'s
`opts.bulk` (`settings/Panel.lua`). Five acts now log one `[Set]` line each, and a profile copy gains
its handler line. Details and the per-act lines are in `04_EXECUTION_PLAN.md`.

## What was declined

Nothing. The two descriptor fields do not apply (`02_CANDIDATES.md`). No issue was filed, as
instructed for this run.

## Gates

| Gate | Before | After re-vendor | After adoption |
|---|---|---|---|
| `lua tests/run.lua` | 838 / 0 / 0 | 838 / 0 / 0 | **848 / 0 / 0** |
| `luacheck .` | 0 / 0 in 103 files | 0 / 0 in 103 files | **0 / 0 in 104 files** |
| copy diff (content and bytes, both payloads) | 2 files differ | empty | empty |
| `lizard -C 15` | — | — | no thresholds exceeded |
