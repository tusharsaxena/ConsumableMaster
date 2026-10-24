# Summary (ConsumableMaster)

LibKa0s v1.76.0 -> v1.77.0 from the local annotated tag (`78240f7`, tag object `7380d36`, via
`git archive`; not yet pushed). The base comes from the CLAUDE.md provenance line and matches the
payload bytes of `e05733d`. No span bundle (every vendored tag has one).

Per-file minors: Core 11 -> 12, Widgets 14 -> 15, WidgetsDragHandle 4 -> 5, WidgetsAutocomplete
2 -> 3, DebugLog 20 -> 21, Options 29 -> 30, OptionsIds 2 -> 3, OptionsCombat 1 -> 2,
OptionsCompose 7 -> 8, OptionsKeybinds new at 3, PerfPanel 8 -> 9, SimPanel 5 -> 6; test kit
revision 41 -> 42. Every other file unchanged.

In one commit, with both payloads:

- the CLAUDE.md provenance line rolls to v1.77.0; the `LibKa0s icons:` line under it is kept
  (`clear, close, copy, help, info, segment.`);
- `tools/prune-icons.lua` (from the tag export) cut `libs/LibKa0s/media/icons/` back to the six
  Open Iconic TGAs and `LICENSE-open-iconic.txt` (5,833 files removed, all from the copy; no set
  changes, so the README `## Credits` stays as it is);
- `tests/test_libka0s.lua` names `OptionsKeybinds` in the Options major's file inventory and
  paired-minor list (the one case the new payload turned red; `01_DELTA.md`);
- the repo's statements of the vendored kit revision move 41 -> 42 (`CLAUDE.md`,
  `docs/testing.md`, a `tests/run.lua` comment);
- no contract blocker, no whole-catalog test, no dead stub mirror.

- **Delivered:** toplevel debug console and perf panel with the confirmation re-raise; clamped
  dropdown menu and suggestion list; the Add-by-ID suggestion list closing at combat start.
- **Adopted:** nothing here.
- **Left to CM-ZS:** DragHandle `level` / `ignoreParentAlpha` / `ApplyLevel`, `O.StrataTooltip`,
  the kit's `mock_layers.lua`.
- **Deferred (run 2026-10-24):** the Keybindings tab members, host calls of
  `Core.RaiseStaticPopups`, the kit's binding mock and checks.
- **Declined / issues filed:** none.

Standards reference, checked in the same item against the local standard v2.88.0
(`../WowAddonStandards` on `feat/2026-10-24-keybinds-layout-strata`, `897fbd3`, unpushed):
TOC `X-Standard`, README badge (bare image) and CLAUDE.md `## Standards compliance (read first)`
are present and canonical. The installed `/dev-copilot:wow-revendor-standards` procedure (Step 5)
and `documentation-§6` keep the reference version-free, so no `2.88.0` is written into the TOC,
README or CLAUDE.md. Notation sweep (`grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=.git
--exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews
--exclude-dir=automated-tests`): 6 hits, all inside the frozen bundle
`docs/revendor/2026-09-23-v1.55.0/` citing a Ka0sAddonsCommonTasks spec's own sections, left as
evidence. No `filename-§N` citation is out of range against v2.88.0. `.gitattributes` pin is
CRLF (client-bound) with zero worktree stragglers. No quirks catalog section exists upstream.

Gate after the copy:

- tests (`ka0s-bounded lua5.1 tests/run.lua`): 1217 passed, 0 failed, 1 skipped, 1218 total,
  `test_vendor_sync` green against v1.77.0 with the declaration; `docs/test-cases.md` unchanged
  (no case added or renamed).
- luacheck (`ka0s-bounded luacheck .`): 0 warnings / 0 errors in 130 files.
- 1500-line cap: largest authored file `settings/MacroBar.lua` at 1182 lines.

No version bump and no CHANGELOG entry (CLAUDE.md hard rule). No smoke check owed by this item:
the delivered changes are the library's own and are smoked library-side.
