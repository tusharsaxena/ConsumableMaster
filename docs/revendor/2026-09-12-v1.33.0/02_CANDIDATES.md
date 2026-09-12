# 02 — Candidates: LibKa0s v1.33.0

Sources:
- `git -C ../LibKa0s log --oneline v1.32.0..v1.33.0`;
- the `## v1.33.0` block of the tag's `CHANGELOG.md`;
- `docs/api/Options/version-17.15.4.3-docs.md`;
- `docs/api/Slash/version-9-docs.md`;
- `docs/api/testkit/version-18-docs.md`.

## Class A — reached this addon on the re-vendor alone

1. **Options minor 17: every LibSharedMedia font is loaded on the first panel show.** A font
   dropdown no longer opens on blank rows. This addon has one such dropdown: the Macro Bar page's
   Labels tab → *Font* (`macroBar.labelFont`), which `H.FontGroup` composes with the `LSM30_Font`
   `dialogControl`. Every page here draws through `H.SetRenderer`, so the preload runs from the
   renderer's OnShow, after the library's combat refusal. It needs no host change, and no descriptor
   field or instance member was added. It is visible only in game, so `docs/smoke-tests.md` §11a
   step 6a now carries a first-open check.

## Class B — host change required

Nothing. The release removes and renames nothing and adds no member or descriptor field.

- **Slash minor 9** corrects docstrings only (the bulk bracket's `count`). This addon supplies no
  `bulkBegin` / `bulkEnd` on either descriptor (see the v1.32.0 bundle), so even the corrected text
  describes a path it does not take.
- **Kit revision 18** changes the kit's AceDB fake, which this harness overrides with its own
  (`tests/wow_mock.lua`). The one consequence is the stale comment corrected in `01_DELTA.md`.

## Class C — whole-module adoption

- **Pool** still ships unused. Nothing in v1.33.0 touches it (minor 3).
