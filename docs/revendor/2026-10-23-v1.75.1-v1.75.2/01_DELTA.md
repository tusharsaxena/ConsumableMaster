Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

Written by CM-RV (2026-10-23 "sim auto-run, QC preview selector, mode strips, MM/KCD simulators"
run) with the v1.76.0 re-vendor bundle beside it. Two patch tags were carried here by the
post-run fixes of the 2026-10-22 run with no bundle of their own. The store's newest bundle before
this one is `2026-10-22-v1.75.0`, so the base of the span is **v1.75.0**; that tag is already
recorded and is not part of the span.

```sh
grep -vxF -f recorded.txt vendored.txt     # the /dev-copilot:wow-revendor-libka0s 3h listing
# v1.75.1
# v1.75.2
```

The carrying commits:

```sh
git log --oneline -3 -- libs/LibKa0s tests/_kit CLAUDE.md
# 485f52f Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)
# ccb2bed Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)
# ddda153 CM-RV2: refresh LibKa0s v1.75.0 payload from the moved local tag
git show --stat --format= ccb2bed     # CLAUDE.md, libs/LibKa0s/SimPanel.lua
git show --stat --format= 485f52f     # CLAUDE.md, libs/LibKa0s/SimPanel.lua
```

- **v1.75.1** (`ccb2bed`; LibKa0s `39dfb98`): `SimPanel.lua` minor 3, a disabled row or control
  still shows its tip. The provenance line rolled in the same commit. Kit unchanged (revision 41).
- **v1.75.2** (`485f52f`; LibKa0s `154599c`): `SimPanel.lua` minor 4, the picker's scenario
  dropdown fits its label. The provenance line rolled in the same commit. Kit unchanged.

ConsumableMaster vendors `LibKa0s-Sim-1.0` but does not consume it (no `LibStub("LibKa0s-Sim-1.0"`
lookup outside `libs/`), so neither patch reaches any code path here. No `NEEDS_*` floor rose and no
major was added; the fourteen consumed majors stand.
