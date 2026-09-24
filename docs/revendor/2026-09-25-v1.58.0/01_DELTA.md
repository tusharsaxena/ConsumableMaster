# 01 - Delta: LibKa0s v1.57.0 -> v1.58.0

Run non-interactively as item M6-CM of the 2026-09-23 review-and-audit remediation plan (milestone
M6, the launcher's left-click-settings / right-click-menu ruling), on branch
`feat/2026-09-23-review-audit-remediation`, on 2026-09-25. Steps 0 and 2-4 of `revendor-libka0s`
(resolve the tag, read the delta, copy both payloads whole, roll the provenance line), then the one
adoption M6 owes in the same item: the Launcher minor-4 descriptor fields. No interview: the owner's
M6 rulings decide the adoption.

## Source

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1        # v1.58.0
git -C ../LibKa0s rev-parse --short 'v1.58.0^{commit}'   # 34931c9 (tag object 93cf3ad)
git -C ../LibKa0s archive v1.58.0 LibKa0s tests/_kit | tar -x -C <scratch>/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed; it was read with `git archive` and never checked out there.

## Step 0. The newest bundle's base

`docs/revendor/2026-09-24-v1.57.0/01_DELTA.md` records v1.56.0 -> v1.57.0, and the commit that first
carried v1.57.0 on the provenance line is `033a695` (M5-CM), parent v1.56.0: **ok**. No base
correction is owed.

## 3a. Claimed version, and the base

```sh
grep -n '^Bundles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.57.0 (MIT).
```

The line and the last payload commit (`033a695`) agree: the base is **v1.57.0**, and
`tests/test_vendor_sync.lua` was green against it before the copy (1076 / 0 / 0).

```sh
git -C ../LibKa0s log --oneline v1.57.0..v1.58.0 | wc -l                      # 2
git -C ../LibKa0s diff --stat v1.57.0 v1.58.0 -- LibKa0s tests/_kit | tail -1
# 1 file changed, 163 insertions(+), 94 deletions(-)
```

## 3b/3c. Actual version, and the per-file minor delta

One file moves. Every other file is byte-identical to v1.57.0 (LibKa0s `CHANGELOG.md`, the v1.58.0
block, and the diff below).

| File | Constant | Before | Tag |
|---|---|---|---|
| Launcher.lua | MINOR | 3 | **4** |

No file is new and none is removed. No `NEEDS_*` floor rises (`NEEDS_CORE` stays 1) and no major is
added. The whole-folder copy moves every file together, so there is no cross-major skew.

## 3d. Both diffs, before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s    libs/LibKa0s   # differs: Launcher.lua
diff -rq                     <scratch>/LibKa0s    libs/LibKa0s   # the same one file
diff -rq                     <scratch>/tests/_kit tests/_kit     # empty
```

No `Only in` line on either side: nothing added, nothing removed upstream.

## 3e. Consumption map

The only major that moved is consumed at `core/LauncherSetup.lua` (`LibStub("LibKa0s-Launcher-1.0",
true)`, the file's one library resolve). The other thirteen consumed majors did not move.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION = 26` on both sides: the kit bytes are those of v1.56.0. Both payloads are still copied
whole in one commit, so the pairing holds by construction. The library's menu fake,
`tests/mock_menu.lua`, is repo-local upstream and **not** in the kit; this addon carries its own copy
(below).

## 3g. Contract delta

Read against the LibKa0s v1.58.0 `CHANGELOG.md` block ("What a consumer owes on re-vendoring
v1.58.0") and `docs/api/Launcher/version-4-docs.md`.

### Blockers

**None.** Four descriptor fields retire (`onClick`, `leftClickLabel`, `disabledLine`, `slash`) and
are ignored if passed, so the copy alone raises nothing. It does change behavior before the host
edit, which is why both land in one commit.

### Arrives without being asked for

With the copy alone the left click opens the settings panel (the rung-(b) `onClick`, the lock
toggle, stops running), the disabled left-click refusal is gone, and the hints read
`Left-click: Open settings` / `Right-click: Options menu`. Until the host passes a pair, the right
click still opens the panel. Ten host cases failed on the copy alone, every one of them a case that
pinned a contract this release retires (the rung, the refusal, the rung's hint and its locale
label): 1066 / 10 / 0.

### Owed by launcher-§2, and adopted in this item

| Field | Passed | Why |
|---|---|---|
| `isEnabled` | kept | The DISABLED hold only (not the perf arm); now also the menu's gray |
| `setEnabled` | `KCM.SlashCommands.Verbs.SetEnabled(on)` | `/cm enable` / `/cm disable`'s own body (`settings/Slash.lua`'s `setEnabled`, newly published on `Verbs` for this caller) |
| `isLocked` | kept | `macroBar.locked`, the *Lock frame* row's value |
| `toggleLock` | `Verbs.RunLock(not cfg.locked)` | `/cm lock` / `/cm unlock`'s own body; the old `onClick`'s body, moved |
| `isTestMode` / `toggleTestMode` | **not passed** | No test mode: the unlocked bar is the preview (`options-ui-§15`) |
| `isWindowShown` / `toggleWindow` | **not passed** | No primary window: the macro bar is a HUD element; its visibility is `/cm bar`, its lock is the *Locked* entry |
| `version` | kept | M5's `KCM.Version()` |
| `onClick`, `leftClickLabel`, `disabledLine` | **removed** | Retired at minor 4 (dead configuration otherwise, `launcher-§5`) |

The menu this draws is **Enabled · Locked**, which is the row the standard's `ADDONS.md` (v2.67.0,
WS-11) records for this addon: code and record agree.

### The menu fake

`tests/mock_menu.lua` is the library's v1.58.0 fake with its body copied unchanged and a header
saying why. It is installed into `_G` (this harness's loader resolves client globals there) and
removed after each case. `.luacheckrc` names its two receiver warnings (`212/self`, `432/self`) in a
file-scoped stanza, which the library's config covers with its top-level ignore.

## After the copy (Step 4)

```sh
rm -rf libs/LibKa0s tests/_kit
cp -a <scratch>/LibKa0s    libs/LibKa0s
cp -a <scratch>/tests/_kit tests/_kit
diff -r <scratch>/LibKa0s    libs/LibKa0s   # empty
diff -r <scratch>/tests/_kit tests/_kit     # empty
```

Content and bytes clean in both payloads; the kit's shell runner keeps its executable bit. The
provenance line in `CLAUDE.md` rolls v1.57.0 -> v1.58.0 in the same commit; `README.md` carries no
provenance line.

| | Tests | Lint | Complexity |
|---|---|---|---|
| Before (v1.57.0) | 1076 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 119 files | not run |
| After the copy alone (v1.58.0) | 1066 passed, 10 failed, 0 skipped | not run | not run |
| After the adoption | 1078 passed, 0 failed, 0 skipped | 0 warnings / 0 errors in 120 files | no function above CCN 15 |
