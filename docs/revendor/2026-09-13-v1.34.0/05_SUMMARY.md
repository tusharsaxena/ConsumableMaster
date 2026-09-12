# 05 — Summary: LibKa0s v1.33.0 → v1.34.0

## The move

| | |
|---|---|
| From | v1.33.0 (tag object 7d5e061 on 06ee368) |
| To | **v1.34.0** (tag object 9165044 on 33bae81, local to `../LibKa0s`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (MINOR 17 → 18), `OptionsCompose.lua` (COMPOSE_MINOR 4 → 5), `Slash.lua` (MINOR 9 → 10) |
| Files that moved in `tests/_kit/` | `mock_base.lua`, `framework.lua`, `README.md` |
| Kit revision | 18 → **19** |
| Files removed upstream | none |
| Cross-major skew found | none |
| Provenance line | `CLAUDE.md:58`, rolled to v1.34.0 in the same commit as the payload |

## What reached this addon for free

- **`/cm set` accepts an LSM name with a space in it.** `macroBar.labelFont` and the two Border style
  rows could not be set to a multi-word face or border from the CLI under Slash minor 9. Pinned.

## What was adopted

- **The *Reset all settings* tooltip names the equivalence** (`options-ui-§12`'s SHOULD), through
  `resetProfile` and `profilesPage = true` on the Options descriptor. Its own commit.
- **The harness's AceDB fake fires `OnProfileReset` with no key**, matching AceDB-3.0 and the kit's
  revision 19.

## What was declined

Nothing. No issue was filed, as instructed for this run.

## Gates

| Gate | Before | After re-vendor |
|---|---|---|
| `lua tests/run.lua` | 872 / 0 / 0 | **873 / 0 / 0** (one case added) |
| `luacheck .` | 0 / 0 in 107 files | 0 / 0 in 107 files |
| copy diff (content and bytes, both payloads) | 6 files differ | empty |
| `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` | 3 files differ | empty |
| `lizard -C 15` | 0 warnings | 0 warnings |
