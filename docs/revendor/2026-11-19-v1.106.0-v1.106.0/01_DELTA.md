Delta: LibKa0s v1.106.0 -> v1.106.0 (span: v1.106.0)

Written 2026-11-19 by item AF-RV-CM of Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, beside
`../2026-11-19-v1.107.0/`. A records-only back-fill: the one tag this addon vendored without a bundle.

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
v1.106.0
```

v1.106.0 was vendored by `7d57df4` (Re-vendor LibKa0s v1.106.0), base v1.105.0, a one-file copy
(`libs/LibKa0s/Widgets.lua`, Widgets minor 28: the HUD dock guards its measurements, RangeMaster#17) made outside
any run, which kept no revendor bundle. Range: `git -C ../LibKa0s log --oneline v1.105.0..v1.106.0` (3 commits).
