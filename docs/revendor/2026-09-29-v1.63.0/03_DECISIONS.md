# Decisions (ConsumableMaster)

- **C1, the Slash minor 17 profile surface: adopted, by this item (SP-CM-02), and nothing else.**
  The adoption is decided upstream of this run, not by an interview here: owner decision D1 of the
  2026-09-29 plan (`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/00_OVERVIEW.md`)
  puts the verb's logic in LibKa0s and has every addon register its own `profile` row, and spec S3
  fixes the host's half. It lands as the item's second commit, "SP-CM-02: /cm profile via
  CliProfile": the `profiles` descriptor field, the COMMANDS row, `profile` added to this addon's
  `liveVerbs`, `CliProfile` and `ProfileSwitch` on the degraded arm (route (b), the library-absent
  line), the tests and the docs.
- No other surface is offered, because v1.63.0 has none (02_CANDIDATES.md), and no decline is filed
  as an issue.
- The re-vendor commit itself carries no host change: the gate is green on the copy alone (the Slash
  parity case is the four-argument form, which the new instance members do not reach).
