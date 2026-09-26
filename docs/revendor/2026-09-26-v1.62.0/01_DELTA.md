# LibKa0s v1.61.0 -> v1.62.0: the delta (ConsumableMaster)

Copied from the tag `v1.62.0` (`5dc9f5d`, local tag) with
`git -C ../LibKa0s archive v1.62.0 LibKa0s testkit`, never from a working tree. This is the
2026-09-26 automated-tests sweep's re-vendor item (CM-ATS-RV; ATS-20, ATS-21).

## Claimed and actual version, before the copy

`grep -n '[Bb]undles' CLAUDE.md` -> `Bundles [LibKa0s](...) v1.61.0 (MIT).` The Options minors
agree with it (Options 25, OptionsWidgets 31, OptionsTabs 5, OptionsCompose 7, OptionsScroll 4,
OptionsNav 1). No skew.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files <tag>/LibKa0s/Options.lua and libs/LibKa0s/Options.lua differ
Only in <tag>/LibKa0s: OptionsCombat.lua
Only in <tag>/LibKa0s: OptionsIdList.lua
Only in <tag>/LibKa0s: OptionsIds.lua
Only in <tag>/LibKa0s: OptionsRegistry.lua
Files <tag>/LibKa0s/OptionsTabs.lua and libs/LibKa0s/OptionsTabs.lua differ
Files <tag>/LibKa0s/OptionsWidgets.lua and libs/LibKa0s/OptionsWidgets.lua differ
```

The byte diff (`diff -rq`, no strip) lists the same files: no line-ending-only drift.

- `Options.lua`: minor 25 -> 26. The page registry and the registration park move out to
  `OptionsRegistry.lua`, attached by `lib.__AttachRegistry(O, d)`.
- `OptionsRegistry.lua`: new, minor 1 (`__registryMinor` / `__registryShellMinor`).
- `OptionsWidgets.lua`: minor 31 -> 32. The id surface moves out to two files.
- `OptionsIds.lua`: new, minor 1 (`__idsMinor` / `__idsShellMinor`): `O.ResolveId`,
  `O.UnnamedCandidates`, `O.ID_NAME_HINT`, `O.IdInput`.
- `OptionsIdList.lua`: new, minor 1 (`__idListMinor` / `__idListShellMinor`): `O.IdList`.
- `OptionsTabs.lua`: minor 5 -> 6. The combat lock's page chrome moves out.
- `OptionsCombat.lua`: new, minor 1 (`__combatMinor` / `__combatShellMinor`).
- `LibKa0s.xml`: loads the four new files in the order Options, OptionsRegistry, OptionsWidgets,
  OptionsIds, OptionsIdList, OptionsTabs, OptionsCombat, OptionsCompose, OptionsScroll, OptionsNav.
- The Options major key moves from `25.31.5.7.4.1` to `26.1.32.1.1.6.1.7.4.1`. Every other file is
  unchanged (CHANGELOG v1.62.0 version block). No `NEEDS_*` floor rises and no major is added.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/testkit/README.md and tests/_kit/README.md differ
Files <tag>/testkit/framework.lua and tests/_kit/framework.lua differ
Only in <tag>/testkit: inventory.lua
Only in <tag>/testkit: prose_coverage.lua
Only in <tag>/testkit: prose_selftests.lua
Files <tag>/testkit/run-automated-tests.sh and tests/_kit/run-automated-tests.sh differ
Files <tag>/testkit/test_layout_cap.lua and tests/_kit/test_layout_cap.lua differ
Files <tag>/testkit/test_prose.lua and tests/_kit/test_prose.lua differ
```

`grep -n 'Kit.VERSION'`: kit revision 27 -> 31. Revision 28 peels the suite inventory into
`inventory.lua`; 29 peels the prose gate into `prose_coverage.lua` and `prose_selftests.lua`; 30
prints `None.` under an empty watch-list table in `RESULTS.md` (ATS-20); 31 leaves
`Kit.layoutCap.exempt`'s generated files out of the band table (ATS-21). Both payloads move
together, whole, as the pairing rule requires.

## Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: Bus, Compat,
Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Perf, unchanged from v1.61.0. The Options
major is reached through the settings helpers (`tests/test_surface_parity.lua`'s `OPTIONS_SEAM`).

## Contract delta (blockers)

None. The Options member manifest is unchanged apart from its file list and version key:

```
diff <(git show v1.61.0:docs/api/Options/members-25.31.5.7.4.1.json | sed -n '/"members"/,$p') \
     <(git show v1.62.0:docs/api/Options/members-26.1.32.1.1.6.1.7.4.1.json | sed -n '/"members"/,$p')
# no output
```

The CHANGELOG states for every peel "No member, descriptor field or row field changes", and for
kit revisions 28 to 31 "A consumer re-vendors the whole folder and changes nothing else".
`grep -rn '__Attach'` outside `libs/` and `tests/_kit/` finds no host call site.
