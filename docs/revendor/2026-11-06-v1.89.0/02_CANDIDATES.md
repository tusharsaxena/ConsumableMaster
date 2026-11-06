# Candidates, v1.85.0 -> v1.89.0

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`, the tag's `CHANGELOG.md` blocks v1.86.0 to
v1.89.0, and the `docs/api/` documents of every major whose minor moved (Widgets, Toast, DebugLog,
IconBrowser). No 3g blocker exists, so none is excluded here.

## A. Delivered by the re-vendor alone

- **Kit revision 51** (CHANGELOG v1.89.0, `docs/api/testkit/version-51-docs.md`): `mock_ace.lua`'s CallbackHandler
  registry clears a target's entry only where one exists, as CallbackHandler-1.0 does. A flake fix in this
  addon's headless suite, with no host change.
- **DebugLogDiagnostics minor 7** (CHANGELOG v1.86.0): the diagnostics report's module list names
  `IconBrowser`. The `/cm diagnostics` report (`core/Diagnostics.lua:3`) lists it with no host change.
- **Widgets minor 23, flat menus** (`docs/api/Widgets/version-23.5.12.6.7.5-docs.md:36`, "nothing for a flat
  menu"): every owned dropdown this addon draws through the library paints as it did at minor 22.

## B. Host change required

- **Widgets 23 cascading-menu fields** (`submenu`, `radio`, `selected`, `opts.check`;
  `docs/api/Widgets/version-23.5.12.6.7.5-docs.md:19-36`). Not applicable: this addon has no `W.ContextMenu`
  use site (`grep -rn ContextMenu` outside `libs/` and `tests/_kit/` finds only `tests/mock_menu.lua`'s
  comment on `MenuUtil`), and no hand-made nested menu. Recommendation: none to adopt.
- **Toast minor 4 stack** (`docs/api/Toast/version-4-docs.md`, CHANGELOG v1.88.0). This addon does not consume
  Toast (3e), so the stack has no host here. Not a candidate.

## C. Whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (new major, CHANGELOG v1.86.0, `docs/api/IconBrowser/version-1.1.1-docs.md`).
  The browser serves an addon whose UI lets the player choose an icon. This addon has no icon chooser: its
  macro icons come from the picked item (`tests/test_macromanager.lua:829`, "falls back to the default icon
  with no picks"). Settled by the owner's ruling (run plan, *Decisions*); additive, but nothing here would
  call it.
- **Pool, Glow, Sim, Toast, Charts** stay unconsumed, as `CLAUDE.md` records; nothing in this range changes
  that premise.
