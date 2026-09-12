# 05 — Summary: LibKa0s v1.32.0 → v1.33.0

## The move

| | |
|---|---|
| From | v1.32.0 (e18dd12) |
| To | **v1.33.0** (tag object 7d5e061 on 06ee368, local to `../LibKa0s`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (MINOR 16 → 17), `Slash.lua` (MINOR 8 → 9) |
| Files that moved in `tests/_kit/` | `mock_base.lua`, `framework.lua`, `README.md` |
| Kit revision | 17 → **18** |
| Files removed upstream | none |
| Cross-major skew found | none |
| Provenance line | `CLAUDE.md:58`, rolled to v1.33.0 in the same commit as the payload |

## What reached this addon for free

- **The Macro Bar page's Font dropdown draws every row on its first open.** Options minor 17 loads
  every LibSharedMedia face on the first panel show, after the combat refusal. The check is in
  `docs/smoke-tests.md` §11a step 6a.

Nothing else is observable. Slash minor 9 is docstrings only. Kit revision 18's AceDB change lands in
a fake this harness overrides with its own.

## What was adopted

Nothing needed adopting. The one comment revision 18 made stale was corrected
(`tests/wow_mock.lua:356`).

## What was declined

Nothing. No issue was filed, as instructed for this run.

## Gates

| Gate | Before | After re-vendor |
|---|---|---|
| `lua tests/run.lua` | 872 / 0 / 0 | **872 / 0 / 0** |
| `luacheck .` | 0 / 0 in 107 files | 0 / 0 in 107 files |
| copy diff (content and bytes, both payloads) | 5 files differ | empty |
| `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` | 2 files differ | empty |
| `lizard -C 15` | no thresholds exceeded | no thresholds exceeded |
