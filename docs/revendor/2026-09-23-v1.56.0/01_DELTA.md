Delta: LibKa0s v1.55.0 -> v1.56.0

Run non-interactively as item RV-CM of the 2026-09-23 review-and-audit remediation plan, on branch
`feat/2026-09-23-review-audit-remediation`, on 2026-09-24. The bundle is named for the plan's date.
Steps 0 and 2-4 of `revendor-libka0s` only (the local `../wow-addon/commands/revendor-libka0s.md`,
as amended by WA-01): resolve the tag, read the delta, copy both payloads whole, roll the
provenance line. Adoption (Steps 5-8) is not taken here: each candidate is its own M3 plan item for
this addon, named below. The span back-fill 3h asks for is plan item CM-28. Written before the
copy; the post-copy verification at the end was appended before the commit.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.56.0
git -C ../LibKa0s rev-parse --short 'v1.56.0^{commit}'   # 514fc0a (tag object 4622018)
git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/new/
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/old/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed; it was read with `git archive` and never checked out there.

## Step 0. The newest bundle's base

```sh
head -1 docs/revendor/2026-09-23-v1.55.0/01_DELTA.md   # # 01 — Delta: LibKa0s v1.54.2 → v1.55.0
# the commit that first carried v1.55.0 on the provenance line, and the line at its parent:
#   34813a4, parent v1.54.2
```

The bundle's base (v1.54.2) is the provenance tag before `34813a4`: **ok**. No base correction is
owed.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # 34813a4
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0
```

The line and the last payload commit agree: the base is **v1.55.0**. The vendored copy is
byte-identical to that tag (`diff -rq <scratch>/old/LibKa0s libs/LibKa0s` and
`diff -rq <scratch>/old/testkit tests/_kit`, both empty).

```sh
git -C ../LibKa0s log --oneline v1.55.0..v1.56.0 | wc -l            # 54
git -C ../LibKa0s diff --stat v1.55.0 v1.56.0 -- LibKa0s testkit | tail -1
# 26 files changed, 2349 insertions(+), 844 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

```sh
for f in $(git -C ../LibKa0s show v1.56.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do
  grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/"$f"
  git -C ../LibKa0s show v1.56.0:LibKa0s/"$f" | grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+'
done
```

In the tag's `LibKa0s.xml` load order:

| File | Constant | Before | Tag |
|---|---|---|---|
| Core.lua | MINOR | 7 | **8** |
| Env.lua | MINOR | 1 | 1 |
| Compat.lua | MINOR | 1 | 1 |
| Lifecycle.lua | MINOR | 1 | **2** |
| Bus.lua | MINOR | 1 | **2** |
| Schema.lua | MINOR | 1 | **2** |
| Pool.lua | MINOR | 3 | 3 |
| Item.lua | MINOR | 1 | **2** |
| Media.lua | MINOR | 3 | **4** |
| Widgets.lua | MINOR | 9 | **10** |
| WidgetsDragHandle.lua | DRAG_MINOR | 2 | 2 |
| DebugLog.lua | MINOR | 12 | **13** |
| Slash.lua | MINOR | 14 | **15** |
| Launcher.lua | MINOR | 1 | **2** |
| Options.lua | MINOR | 23 | **24** |
| OptionsWidgets.lua | WIDGETS_MINOR | 30 | **31** |
| OptionsTabs.lua | TABS_MINOR | 3 | **4** |
| OptionsCompose.lua | COMPOSE_MINOR | 7 | 7 |
| OptionsScroll.lua | SCROLL_MINOR | 3 | **4** |
| Perf.lua | MINOR | 12 | **13** |
| PerfPanel.lua | PANEL_MINOR | 5 | 5 |

No file is new and none is removed. The claim (v1.55.0) and the bytes agree before the copy, and
the whole-folder copy moves every file together, so there is **no cross-major skew** before or
after. No `NEEDS_*` floor rises and no major changes (LibKa0s `CHANGELOG.md`, the v1.56.0 block).

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/new/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
diff -rq                     <scratch>/new/testkit tests/_kit
```

Content and bytes report the same set, so nothing here is a line-ending disagreement:

- library: differs: `Bus.lua`, `Core.lua`, `DebugLog.lua`, `Item.lua`, `Launcher.lua`,
  `Lifecycle.lua`, `Media.lua`, `Options.lua`, `OptionsScroll.lua`, `OptionsTabs.lua`,
  `OptionsWidgets.lua`, `Perf.lua`, `Schema.lua`, `Slash.lua`, `Widgets.lua`. No `Only in` line on
  either side.
- kit: `Only in <tag>`: `asserts.lua`, `mock_events.lua`, `prose_lists.lua`; differs: `README.md`,
  `framework.lua`, `mock_base.lua`, `mock_record.lua`, `run-automated-tests.sh`, `test_eol.lua`,
  `test_layout_cap.lua`, `test_prose.lua`.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing was removed upstream, so the copy
  deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' \
  | grep -v '^./libs/' | grep -v '^./tests/'
```

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| Core | `core/CoreSetup.lua:64` | 7 -> 8 |
| Env | `core/EnvSetup.lua:57` | no |
| Compat | `core/Compat.lua:32` | no |
| Lifecycle | `core/LifecycleSetup.lua:49` | 1 -> 2 |
| Bus | `core/Bus.lua:53` | 1 -> 2 |
| Item | `core/ItemSetup.lua:34` | 1 -> 2 |
| Media | `core/MediaSetup.lua:61` | 3 -> 4 |
| DebugLog | `core/DebugLogSetup.lua:59` | 12 -> 13 |
| Launcher | `core/LauncherSetup.lua:93` | 1 -> 2 |
| Perf | `core/PerfSetup.lua:38` | 12 -> 13 |
| Options | `settings/OptionsSetup.lua:167` | key 23.30.3.7.3 -> 24.31.4.7.4 |
| Slash | `settings/Slash.lua:415` | 14 -> 15 |
| Widgets | `modules/MacroBar.lua:44`, `settings/Category.lua:79`, `settings/MacroBar.lua:723`, `settings/StatPriority.lua:122` | 9 -> 10 |

Thirteen majors consumed, as `CLAUDE.md` says. Unadopted in the payload: **Pool** (reached only
through the library itself) and **Schema** (declined at v1.55.0 as ConsumableMaster#39; Schema
minor 2 adds the `SetMany` and `row.normalize` that issue asked for, and adoption is plan item
CM-17).

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/new/testkit/framework.lua:20:Kit.VERSION = 26
# tests/_kit/framework.lua:20:Kit.VERSION = 25
```

Revision **25 -> 26**. A consumer taking LibKa0s v1.9.0 or newer takes kit revision 11 or newer in
the same commit; both payloads are copied whole in one commit, so the pairing holds by
construction, and `tests/test_vendor_sync.lua` compares both against the tag the provenance line
names, which is why they move together.

## 3g. Contract delta

Read against the LibKa0s v1.56.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.56.0") and the release bundle's dry run
(`git -C ../LibKa0s show v1.56.0:docs/automated-tests/20260924-040553/ANALYSIS.md`), for the majors
3c and 3e intersect.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit   # empty
```

### Blockers

**None.** No host-supplied member's call site moved under a surface this addon hands over:

- **Slash minor 15**: `CliSet` now prints a refusal when the host's `set` answers `false, reason`,
  and `CliReset` prints `NO_DEFAULT` when `applyDefault` answers exactly `false`. This addon's `set`
  and `applyDefault` (`settings/Slash.lua:524-533`) answer nothing, which still reads as success,
  so nothing prints twice and no echo is lost.
- **Options minor 24**: `CreateOptionsPanel` parks in combat. This addon never calls it
  (`settings/OptionsSetup.lua:287`) and keeps its own park, so the library's park is not reached.
  Adopting the library's and deleting the host's is plan item CM-05. `OpenOptionsPanel`'s new
  boolean answer is additive.
- **OptionsTabs minor 4 / OptionsWidgets minor 31**: `RenderTabbedSchema`'s fifth `opts` argument
  and `PageBanner`'s `action` are opt-ins (CM-20); the chrome-release fix and the throttle's own
  armed flag arrive for free with no host change.
- **Core minor 8**: the `SafeRegisterEvent` family is additive (adoption is CM-15). The dry run
  found no surface-parity red for this addon's Core stub.

### Kit flips (revision 26)

The dry run of this payload against `38f3901` reported one red for this addon, the prose gate
reading the store-root `docs/perf-analysis/README.md` and the newly listed *synchronis* stem. Plan
item CM-01 (`c95b4c6`) respelled those three words ahead of this commit, so the suite is expected
green; the result is below. The kit's case names now carry the section sign (`line-endings-§5`,
`layout-§1`, `localization-§5`), so `docs/test-cases.md` is out of step with the runner until plan
item CM-DOCS regenerates it; this commit does not touch it.

## 3h. Tags vendored and never recorded

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-08-25
# the audit's walk plus the provenance rolls, less every bundle's recorded tag (the procedure's script)
```

Output, 30 tags: v1.16.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0
v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1
v1.47.0 v1.48.0 v1.48.1 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2.

The consolidated span bundle is **not** written here: it is plan item CM-28, which the plan scopes
as 27 tags (v1.18.0-v1.53.0). The listing above names three more (v1.16.0, which the audit's walk
reaches through the store's first day, and v1.54.2, which the v1.55.0 bundle records only as its
base). CM-28 reconciles the count when it runs.

## After the copy (Step 4)

```sh
rm -rf libs/LibKa0s tests/_kit
cp -r <scratch>/new/LibKa0s/. libs/LibKa0s/
cp -r <scratch>/new/testkit/. tests/_kit/
chmod +x tests/_kit/run-automated-tests.sh
diff -r --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -r                     <scratch>/new/LibKa0s libs/LibKa0s    # empty
diff -r --strip-trailing-cr <scratch>/new/testkit tests/_kit      # empty
diff -r                     <scratch>/new/testkit tests/_kit      # empty
```

Content and bytes both clean in both payloads; nothing deleted inside `libs/` or `tests/_kit/`
beyond what the whole-folder replace put back. The provenance line in `CLAUDE.md` rolls v1.55.0 ->
v1.56.0 in the same commit; `README.md` carries no provenance line.

Gate, before and after (`ka0s-bounded luacheck .`, `ka0s-bounded lua5.1 tests/run.lua`,
`ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`, from the repo root):

| | Tests | Lint | Complexity |
|---|---|---|---|
| Before (v1.55.0, kit 25) | 998 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 116 files | not run |
| After (v1.56.0, kit 26) | 998 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 116 files | no function above CCN 15 |

The count does not move: revision 26 renames kit cases and tightens what they read, and adds no
case this runner wires. `tests/test_vendor_sync.lua`'s case (`libs/LibKa0s is the LibKa0s release
CLAUDE.md says this addon bundles`) passes against v1.56.0. `.luacheckrc` excludes `libs/` and
`tests/_kit/`, so lint does not see the payload either way.
