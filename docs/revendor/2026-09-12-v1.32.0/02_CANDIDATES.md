# 02 — Candidates: LibKa0s v1.32.0

Sources: `git -C ../LibKa0s log --oneline v1.31.0..v1.32.0` (five commits, f7d78cd..e18dd12), the
`## v1.32.0` block of the tag's `CHANGELOG.md`, `docs/api/Options/version-16.15.4.3-docs.md` and
`docs/api/Slash/version-8-docs.md`.

## Class A — reached this addon on the re-vendor alone

Nothing. Both new fields are optional, and a descriptor that supplies neither runs the v1.31.0 walk
unchanged (CHANGELOG v1.32.0: "A host that supplies neither new field runs the exact walk it ran at
v1.31.0"). The suite total did not move on the copy (838 before and after).

## Class B — host change required

1. **The `bulkBegin` / `bulkEnd` bracket on the Options descriptor** (Options minor 16, around
   `RestoreDefaults` and `RestoreAllDefaults`). It brackets only walks the library runs, and this addon
   reaches neither. Its descriptor (`settings/OptionsSetup.lua`) supplies only `get` / `set`, and every
   reset here is addon code: the Macro Bar and General page Defaults, the composite Reset category,
   `/cm aio <key> reset`, and `KCM.ResetAllToDefaults`. Recommendation: **not applicable as a
   descriptor field**. Adopt the same shape in the host instead, so the addon's own acts meet the
   same `debug-logging-§10` rule.
2. **The same bracket on the Slash descriptor** (Slash minor 8, around `Sl:CliResetAll`). This addon's
   `/cm resetall` is its own verb routed to `KCM.ResetAllToDefaults` (`settings/Slash.lua`), so
   `CliResetAll` never runs, and `/cm reset <path>` (`CliReset`) writes one row. Recommendation: **not
   applicable**.

## Class C — whole-module adoption

- **Pool** still ships unused. Nothing in v1.32.0 touches it (minor 3).
