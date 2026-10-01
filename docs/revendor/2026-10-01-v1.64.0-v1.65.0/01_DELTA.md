Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)

Written by GI-CM-RV (2026-10-01 GitHub issue pass) with the v1.66.0 re-vendor bundle beside it,
because the store's walk found two vendored tags with no bundle.

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-08-25
# vendored: tags named by the CLAUDE.md provenance line at every commit since the horizon that
# touched libs/LibKa0s or tests/_kit, plus every CLAUDE.md commit that rolled the line
# recorded: the tag in each bundle's folder name, else line 1 of its 01_DELTA.md; span line tags
grep -vxF -f recorded.txt vendored.txt
# v1.64.0
# v1.65.0
```

The carrying commits:

```sh
git log --format='%h %s' -S'LibKa0s) v1.64.0' -- CLAUDE.md | tail -1
# 5100d9b DL-CM-01: re-vendor LibKa0s v1.64.0 (kit revision 33), resize smoke checks
git log --format='%h %s' -S'LibKa0s) v1.65.0' -- CLAUDE.md | tail -1
# 21cee68 DG-CM-01: re-vendor LibKa0s v1.65.0 (kit revision 34), DebugLogGates joins the DebugLog major
```

v1.64.0 was re-cut once and re-vendored at kit revision 34 in `bf8afd9` (DL-CM-03).
