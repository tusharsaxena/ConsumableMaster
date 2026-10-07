# Candidates (ConsumableMaster, LibKa0s v1.70.0 -> v1.71.0)

Sources: `git -C ../LibKa0s log --oneline v1.70.0..v1.71.0` (20 commits), the CHANGELOG `v1.71.0`
block at the tag, and the API documents of every major whose minor moved (`docs/api/Widgets/`,
`docs/api/Slash/`, `docs/api/Env/`, `docs/api/Options/`, `docs/api/testkit/version-38-docs.md`).

Per OWNER_SCOPE 5 this run is mechanical: every new surface the remediation plan does not already
require of this addon is listed below as **not adopted in this run**. There is no interview, no
`03_DECISIONS.md` or `04_EXECUTION_PLAN.md`, and no GitHub issue is filed.

## A. Delivered on the re-vendor alone

- **Kit revision 38 Totals.** `--list` Total counts only the cases that run; the declared skip is on
  a `Skipped` row. Regenerated `docs/test-cases.md` and the README badge (1201/1201) in the same
  commit.
- **Slash key 20.2.** `/cm set <path> nan` (and `inf`, `-inf`, `1e400`) on a number schema row is
  refused with the existing not-a-number reason, through `settings/Slash.lua:509`.
- **Env 2, OptionsIdList 4.** The library no longer reads the bare `GetAddOnMetadata` or
  `IsAddOnLoaded` globals. A live client sees no difference.

## B. New surfaces (candidates)

- **`Kit.secret`, `Kit.isSecret`, `Kit.reveal`, `Kit.installSecretValue`, `Kit.SECRET_ERROR`**
  (kit 38, `testkit/secrets.lua`): a shared secret-value simulator. This addon's tests model the
  secret guard through stubs of `issecretvalue`; migrating them is optional and **not adopted in
  this run**.
- **`ChartMath.ClipSegment`** (WidgetsLineChart 3): this addon draws no chart. **Not adopted in this
  run.**
- **WidgetsLineChart 3's render-time hover re-sync** and **WidgetsAutocomplete 2's re-hook on
  re-call**: neither widget is called here. **Not adopted in this run.**

## C. Owed by other items of this plan (not this re-vendor)

- `KCM.Meta`'s own library-absent bare `GetAddOnMetadata` rung (`core/EnvSetup.lua:73-75`): item
  CM-09, the host side of the same cleanup Env 2 made in the library.
- `/cm priority` argument validation (`core/SlashCommands.lua`): item CM-04. Slash 20.2 covers
  composed schema rows only.

## D. Whole-module adoption

None. The payload's fifteen majors are unchanged; `Pool` is still looked up only inside the
library's own options shell.
