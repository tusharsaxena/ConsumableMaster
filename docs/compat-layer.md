# Compat layer

`core/Compat.lua` is the one file in this addon allowed to call a client API that has moved, or that
may not exist on the build the player is running. Everything else calls `KCM.Compat.X` and never the
raw global, so a rename is one edit here rather than a sweep across `core/SpecHelper.lua`,
`core/SlashCommands.lua`, `core/MacroDisplay.lua`, `modules/MacroManager.lua`,
`modules/MacroBarFlyout.lua`, `modules/KCMItemRow.lua` and `settings/`.

It loads immediately after `core/Constants.lua`, before anything that could want it.

**Six shims, in two groups.** The trigger `documentation-§3` states is three or more, counted over
this file alone.

| Group | Export | Ladder | Answers with, when nothing works |
|---|---|---|---|
| Specialization | `GetSpecialization()` | `C_SpecializationInfo.GetSpecialization` → `GetSpecialization` | `nil` |
| | `GetSpecializationInfo(index)` | `C_SpecializationInfo.GetSpecializationInfo` → `GetSpecializationInfo` | `nil` |
| | `GetNumSpecializationsForClassID(classID)` | `C_SpecializationInfo.GetNumSpecializationsForClassID` → `GetNumSpecializationsForClassID` | `0` |
| | `GetSpecializationInfoForClassID(classID, index)` | `C_SpecializationInfo.GetSpecializationInfoForClassID` → `GetSpecializationInfoForClassID` | `nil` |
| Spell | `GetSpellName(spellID)` | `C_Spell.GetSpellName` → `C_Spell.GetSpellInfo().name` → `GetSpellInfo` | `nil` |
| Secret values | `IsSecret(value)` | `issecretvalue` | `false` |

## The shape every accessor has

Modern namespace first, deprecated global second, an honest empty answer third:

```lua
function Compat.GetSpecialization()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    if GetSpecialization then return GetSpecialization() end
    return nil
end
```

Three properties are load-bearing, and each of them is a rule rather than a habit:

**Capability is probed by presence, never by asking which client this is.** There is no
`WOW_PROJECT_ID` branch anywhere in this file, and there must not be one. Midnight is mid-migration
from the flat `GetSpecialization*` and `GetSpellInfo` globals to the `C_SpecializationInfo` and
`C_Spell` namespaces, and the migration lands one API at a time — a build check would be right about
the build and wrong about the function.

**Each rung is guarded on the table AND the member.** `C_SpecializationInfo` existing does not mean
the member does; a namespace that ships half-populated is exactly the state a mid-migration client is
in, and `if C_SpecializationInfo.GetSpecialization()` without the `and` is a nil-index error at the
one moment the fallback was supposed to save you.

**The floor is a value the caller can act on, not a guess.** `GetSpellName` returns `nil` rather than
`"Unknown"` or the spell ID as a string, because the call sites want different placeholders and one
of them is not a placeholder at all: `modules/KCMItemRow.lua:85` substitutes `[Loading]` for a row
label, and `modules/MacroBarFlyout.lua:329` must write `""` into a secure `spell` attribute, because
`nil` there leaves the previous binding in place. A shared default would be wrong in one of the two. `GetNumSpecializationsForClassID` is the one that
answers `0`, because its callers loop `1..n` and `nil` would be an arithmetic error where zero is a
correct, terminating answer: a class whose spec count cannot be read has no per-spec editors to draw.

`GetSpellName` also treats the empty string as a miss at every rung, not just an absent value. The
client returns `""` for a spell it knows about but has not yet cached, and a row labeled with an
empty string is a blank line the player cannot tell from a bug.

## `IsSecret` is not like the others

The five API shims stand in for something that moved. `IsSecret` stands in for something that
**arrived**: Midnight wraps combat-restricted returns — cooldown durations among them — in opaque
secret values. Addon code may hand one straight back to a client API that accepts it, but comparing
it or doing arithmetic on it is a hard error, so a gate over client data has to ask first.

`issecretvalue` is the client's own test. On a client that predates it, nothing is ever secret, which
is why the fallback is `false` rather than `nil`: the caller is writing `if IsSecret(x) then` and a
three-valued answer would only make it write the same `false` itself. Its single call site is
`core/MacroDisplay.lua:127`, which bails out of the cooldown comparison rather than raising. The
behavior it protects against is cataloged in [midnight-quirks.md](./midnight-quirks.md).

## What is deliberately not here

Shims that `LibKa0s` supplies are **not** counted against this file's trigger and are not
re-documented on this page — the library documents its own substrate once, and an addon page
restating it is a copy going stale in eight places:

- **TOC metadata** — `KCM.Meta` and `KCM.Version` are `LibKa0s-Env-1.0`'s, reached through
  `core/EnvSetup.lua`.
- **The item-link primitive** — `ItemIDFromLink` is `LibKa0s-Item-1.0`'s, reached through
  `core/ItemSetup.lua`, which also records why the major's other three members are pointedly unused.

And one thing that is this addon's but is not a compat shim: `core/TooltipCache.lua`. Its tooltip
normalization looks like patch-proofing and is not — it is this addon's classification policy, and it
stays where it is precisely because two addons in this collection disagree on purpose about what an
uncached item means. The grammar escapes, the non-breaking spaces and the subtype renames it deals
with are in [midnight-quirks.md](./midnight-quirks.md).

## Adding a shim

One `function Compat.X(...)` in `core/Compat.lua`, modern rung first, and one case in
`tests/test_compat.lua` per rung. The mock publishes the legacy globals only, so the spec ladders are
exercised at their bottom rung by construction; `GetSpellName`'s three rungs are walked explicitly, by
nil'ing `C_Spell.GetSpellName` and restoring it. A shim with no fallback case is a shim whose fallback
has never run.

## See also

- [midnight-quirks.md](./midnight-quirks.md) — the client behaviors these shims exist under.
- [module-map.md](./module-map.md) — where `core/Compat.lua` sits in the load order.
- [ARCHITECTURE.md](./ARCHITECTURE.md#external-dependencies) — the LibKa0s majors this addon adopts.
