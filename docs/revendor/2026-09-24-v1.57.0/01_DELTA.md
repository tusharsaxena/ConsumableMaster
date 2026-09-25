# 01 - Delta: LibKa0s v1.56.0 -> v1.57.0

Run non-interactively as item M5-CM of the 2026-09-23 review-and-audit remediation plan (milestone
M5, the always-on launcher status tooltip), on branch `feat/2026-09-23-review-audit-remediation`, on
2026-09-24. Steps 0 and 2-4 of `revendor-libka0s` (resolve the tag, read the delta, copy both
payloads whole, roll the provenance line), then the one adoption M5 owes in the same item: the
Launcher minor-3 descriptor fields. No interview: the owner's M5 rulings decide the adoption.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.57.0
git -C ../LibKa0s rev-parse --short 'v1.57.0^{commit}'   # aa37bc9 (tag object d03e836)
git -C ../LibKa0s archive v1.57.0 LibKa0s tests/_kit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed; it was read with `git archive` and never checked out there.

## Step 0. The newest bundle's base

`docs/revendor/2026-09-23-v1.56.0/01_DELTA.md` records v1.55.0 -> v1.56.0, and the commit that first
carried v1.56.0 on the provenance line is `389e0f0` (RV-CM), parent v1.55.0: **ok**. No base
correction is owed.

## 3a. Claimed version, and the base

```sh
grep -n '^Bundles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.56.0 (MIT).
```

The line and the last payload commit (`389e0f0`) agree: the base is **v1.56.0**, and
`tests/test_vendor_sync.lua` was green against it before the copy.

```sh
git -C ../LibKa0s log --oneline v1.56.0..v1.57.0 | wc -l                      # 2
git -C ../LibKa0s diff --stat v1.56.0 v1.57.0 -- LibKa0s tests/_kit | tail -1
# 1 file changed, 109 insertions(+), 4 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

One file moves. Every other file is byte-identical to v1.56.0 (LibKa0s `CHANGELOG.md`, the v1.57.0
block, and the diff below).

| File | Constant | Before | Tag |
|---|---|---|---|
| Launcher.lua | MINOR | 2 | **3** |

No file is new and none is removed. No `NEEDS_*` floor rises (`NEEDS_CORE` stays 1) and no major is
added. The whole-folder copy moves every file together, so there is no cross-major skew.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s    libs/LibKa0s   # differs: Launcher.lua
diff -rq                     <scratch>/LibKa0s    libs/LibKa0s   # the same one file
diff -rq --strip-trailing-cr <scratch>/tests/_kit tests/_kit     # empty
diff -rq                     <scratch>/tests/_kit tests/_kit     # empty
```

No `Only in` line on either side: nothing added, nothing removed upstream.

## 3e. Consumption map

The only major that moved is consumed at `core/LauncherSetup.lua:93`
(`LibStub("LibKa0s-Launcher-1.0", true)`). The other thirteen consumed majors did not move.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION = 26` on both sides: the kit bytes are those of v1.56.0. Both payloads are still copied
whole in one commit, so the pairing holds by construction.

## 3g. Contract delta

Read against the LibKa0s v1.57.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.57.0") and `docs/api/Launcher/version-3-docs.md`.

### Blockers

**None.** The one repurposed field is `onTooltipShow`, which through minor 2 was handed to the LDB
object as the whole tooltip and from minor 3 is called inside the library's block. This addon never
passed it, so nothing draws twice. The library now always sets the object's `OnTooltipShow`; no host
test read it before this item.

### Arrives without being asked for

The button answers a hover with the library's status tooltip, enabled or disabled. With the copy
alone (before the descriptor change) the tooltip read `Ka0s Consumable Master`, `Enabled: Yes`,
`Left-click: Toggle`, `Right-click: Open settings`: no version, no lock line, the fallback label.

### Owed by launcher-§1, and adopted in this item

| Field | Passed | Why |
|---|---|---|
| `version` | `KCM.Version()` (a function) | The TOC's `## Version`, TOC first, the in-code constant only where the manifest is unreadable |
| `isLocked` | `MacroBarModel.Config().locked` | The macro bar's lock is this addon's lock; the same value the *Lock frame* row reads |
| `isTestMode` | **not passed** | This addon has no test mode: the unlocked bar is its preview (the `options-ui-§15` exemption) |
| `leftClickLabel` | `L["Lock frame"]` / `L["Unlock frame"]` (a function) | Rung (b), lock / unlock, per the standard's `ADDONS.md`; follows the lock so it names what the click will do |
| `slash` | **not passed** | The disabled hint reads `/cm` out of `disabledLine()`, the dispatcher's own line |
| `onTooltipShow` | **not passed** | No line of the addon's own to add; the library draws the whole block |

## After the copy (Step 4)

```sh
rm -rf libs/LibKa0s tests/_kit
cp -a <scratch>/LibKa0s    libs/LibKa0s
cp -a <scratch>/tests/_kit tests/_kit
diff -r <scratch>/LibKa0s    libs/LibKa0s   # empty
diff -r <scratch>/tests/_kit tests/_kit     # empty
```

Content and bytes clean in both payloads; `tests/_kit/run-automated-tests.sh` keeps its executable
bit. The provenance line in `CLAUDE.md` rolls v1.56.0 -> v1.57.0 in the same commit; `README.md`
carries no provenance line.

| | Tests | Lint | Complexity |
|---|---|---|---|
| Before (v1.56.0) | 1071 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 119 files | not run |
| After the copy alone (v1.57.0) | 1071 passed, 0 failed, 0 skipped | not run | not run |
| After the adoption | 1076 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 119 files | no function above CCN 15 |

The five new cases are `tests/test_launcher.lua`'s status-tooltip block.
