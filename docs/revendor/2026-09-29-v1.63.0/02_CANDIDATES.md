# Candidates (ConsumableMaster)

| # | Surface | What it offers | Blocker? |
|---|---|---|---|
| C1 | Slash minor 17: descriptor field `profiles`, `Sl:CliProfile(rest)`, `Sl:ProfileSwitch(name)`, `lib.ProfileNames(store)`, nine `PROFILE_*` strings | The shared `profile` verb: bare lists the profiles with the current one marked; `profile <name>` switches to an existing profile only, never creates one, refuses in combat (`docs/api/Slash/version-17-docs.md`, The profile verb). | No: additive. The addon's Slash parity case is the four-argument form over `KCM.SlashCommands`, so the copy alone stays green. |

Delivered on the copy alone (class A, not offered): nothing that changes behavior. A host that passes
no `profiles` and registers no `profile` row sees no change in the client (version 17 document,
Compatibility), and `lib.LIVE_VERBS` is unchanged.
