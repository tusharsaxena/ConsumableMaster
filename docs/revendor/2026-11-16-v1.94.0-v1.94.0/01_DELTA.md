Delta: LibKa0s v1.94.0 -> v1.94.0 (span: v1.94.0)

Written 2026-11-16 by item RV-CM of Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, beside
`../2026-11-16-v1.105.0/`. A records-only back-fill: the one tag this addon vendored without a bundle.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-08-25
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
#   -> vendored.txt (every tag the provenance line named at those commits)
# every docs/revendor bundle's tag(s) -> recorded.txt
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.94.0
```

v1.94.0 was vendored by `20f4c60` (CM-F1 + ... + CM-F6: Port to Retail + Forever, step 1), base v1.93.0, under the
WoW Forever port, whose run kept no revendor bundle. Range: `git -C ../LibKa0s log --oneline v1.93.0..v1.94.0`
(3 commits): Compat minor 4 (character identity) and Skin minor 18 (`Skin:DefaultSkin()`).
