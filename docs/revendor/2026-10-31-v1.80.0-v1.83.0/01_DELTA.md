Delta: LibKa0s v1.77.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

Written by FX-CM-DOCS (2026-10-31 findings remediation). Four tags were carried by the skinning
rollout, the skin library follow-ups and the two skin font runs with no bundle of their own. The
store's newest bundle before this one is `2026-10-24-v1.77.0`, so the base of the span is
**v1.77.0**; that tag is already recorded and is not part of the span. v1.78.0 and v1.79.0 were never
vendored here: `f5d9d20` went straight to v1.80.0.

```sh
git log --oneline -- CLAUDE.md libs/LibKa0s tests/_kit | grep -E 'v1\.8[0-3]\.0'
# c7658c6 CM-RV3: Take the re-cut LibKa0s v1.83.0 (LK-A3, the skin picker's rows)
# 5b7f096 CM-RV3: Take the re-cut LibKa0s v1.83.0 (LK-A3, the skin picker's rows)
# f7dc226 CM-RV2: Take the re-cut LibKa0s v1.83.0 (LK-A1, LK-A2)
# 5e93c0a CM-F01: Re-vendor LibKa0s v1.83.0, move the outline default, drop the font text
# 0b9a1df CM-01: Re-vendor LibKa0s v1.82.0 from the local tag
# 46c76a5 CM-RV: Re-vendor LibKa0s v1.81.0
# f5d9d20 CM-RV: Re-vendor LibKa0s v1.80.0 from the local tag
```

- **v1.80.0** (`f5d9d20`; kit revision 44): the new `LibKa0s-Skin-1.0` major and its paired files.
  The Options degradation stub answers `AppearanceTab`, `AppearanceRows`, `SkinPicker` and
  `HideSkinPicker`. The icon declaration gained `settings` for the first-run picker's gear. This
  addon took `Skin` as its fifteenth consumed major.
- **v1.81.0** (`46c76a5`; kit unchanged): twenty-four library files moved. No host test pinned a
  moved minor or key.
- **v1.82.0** (`0b9a1df`; kit revision 45, `glyphs.lua`): `OptionsSwitch.lua` is new, and the shipped
  fonts changed. The degraded Skin facade gained `FontFlags` and `HudFontSize`, and the Options stub
  gained `SkinVerb`.
- **v1.83.0** (`5e93c0a`, then the re-cuts `f7dc226`, `5b7f096` and `c7658c6`; kit revision 46):
  `OptionsMedia` joined the Options registry. The local tag moved three times before the run merged,
  and each re-cut was taken whole with no addon code change. `skin.outline` defaults to `hud` from
  this tag's run.
