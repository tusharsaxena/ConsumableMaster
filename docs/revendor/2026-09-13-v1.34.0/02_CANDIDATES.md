# 02 — Candidates: LibKa0s v1.34.0

Sources:
- `git -C ../LibKa0s log --oneline v1.33.0..v1.34.0`;
- the `## v1.34.0` block of the tag's `CHANGELOG.md`;
- `docs/api/Options/version-18.15.5.3-docs.md`;
- `docs/api/Slash/version-10-docs.md`;
- `docs/api/testkit/version-19-docs.md`;
- `docs/releasing.md`, "Re-vendoring consumers".

## Class A — reached this addon on the re-vendor alone

1. **Slash minor 10: a `string` row takes the whole value after the path, trimmed.** With `values`,
   the whole string must match. Every `string` row in this addon declares `values`, so no free-text
   row exists and nothing a player types was being cut short silently. What starts working is every
   LibSharedMedia name with a space in it, which minor 9 refused because the first word is not an
   allowed value: `/cm set macroBar.labelFont Friz Quadrata TT`, and the two Border style rows
   (`macroBar.barBorderStyle`, `macroBar.buttonBorderStyle`) with `Blizzard Dialog` and the like.
   The descriptor's `parse` (`settings/Slash.lua:302`) hands every non-`order`, non-`map` row to
   `slashLib.ParseValue`, so it needs no host change. One input is now refused that minor 9
   accepted: a valid enum value followed by more words, which minor 9 cut down to the valid first
   word and stored. Pinned by `tests/test_slashsetup.lua`, "Slash: /cm
   set keeps a multi-word font name whole", red on minor 9.

## Class B — host change required

1. **Options minor 18 / OptionsCompose minor 5: the Reset-all tooltip follows the descriptor.** This
   addon draws *Reset all settings* through the library's `MasterControls` (`settings/General.lua:190`),
   so the tooltip is the composer's, chosen from the Options descriptor. The descriptor
   (`settings/OptionsSetup.lua:166`–`:222`) passes no `resetProfile`, so on the re-vendor alone the
   tooltip keeps *"Restore every setting in this addon to its default."* That is the text
   `options-ui-§12` calls an overstatement for a profile reset, and it does not name the equivalence
   the section's SHOULD asks for. The addon ships a Profiles page, so the adoption is `resetProfile`
   plus `profilesPage = true`. Taken in the next commit (`04_EXECUTION_PLAN.md`).

2. **Kit revision 19: `OnProfileReset` carries no key.** The kit's fake is overridden here, so the
   change does not arrive by itself. The harness's own fake was brought into line in this commit
   (`01_DELTA.md`).

## Class C — whole-module adoption

- **Pool** still ships unused. Nothing in v1.34.0 touches it (minor 3).
