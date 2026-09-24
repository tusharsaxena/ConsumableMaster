# Compat layer

`core/Compat.lua` is the one seam between this addon and the client APIs Blizzard is moving from flat
globals into namespaces (`compat`). Feature modules call `KCM.Compat.X` and never the raw API, so a
rename is one edit in one file. Every rung is read at **call time**, never captured at load, so a
test can swap either rung and a client that lacks one falls through to the next.

Four members (`GetSpecialization`, `GetSpecializationInfo`, `GetSpellName`, `IsSecret`) are
`LibKa0s-Compat-1.0`'s, bound onto `KCM.Compat` by name. The library documents them, and so does
[ARCHITECTURE.md → LibKa0s adoption](./ARCHITECTURE.md#libka0s-adoption). This page covers only the three shims the
addon owns itself.

| Shim | Wraps | Answers | Callers |
|---|---|---|---|
| `GetNumSpecializationsForClassID(classID)` | `C_SpecializationInfo.GetNumSpecializationsForClassID`, then the global | the spec count, or `0` when neither exists, because every caller loops `1..n` | `core/SpecHelper.lua`, `core/SlashCommands.lua`, `settings/StatPriority.lua` |
| `GetSpecializationInfoForClassID(classID, index)` | `C_SpecializationInfo.GetSpecializationInfoForClassID`, then the global | `specID, specName, ...`, or `nil` | the same three |
| `GetItemInfo(item)` | `C_Item.GetItemInfo`, then the deprecated `GetItemInfo` global as a guarded fallback | every return the client gives, or `nil` with neither API or before the item's data streams in | `modules/Ranker.lua` (quality and item level, memoized per recompute pass), `core/TooltipCache.lua` (name and required level), `modules/KCMItemRow.lua` (the name fallback and the item link), and the fallback rungs of `core/Classifier.lua` and `core/WeaponSlots.lua` behind `C_Item.GetItemInfoInstant` |

The two class-ID readers stay host code because this addon is their only consumer in the collection,
and the library takes a member only when two addons agree on it. `GetItemInfo` is host code because
the library carries no item resolver (LibKa0s's Compat document, *What is not here*).

## What still reads a client global directly

`GetItemCount`, at `modules/KCMItemRow.lua:230` and as the fallback rung at `core/MacroDisplay.lua:76`.
That is a ratified deviation, and the `compat` row in
[ARCHITECTURE.md → Documented deviations](./ARCHITECTURE.md#documented-deviations) is its one home.

## Tests

`tests/test_compat.lua` covers each shim: the namespaced rung preferred, the global reached when the
namespaced call is absent, and the absent value when neither exists. `tests/test_ranker.lua` pins the
Ranker's use of the seam. It scores with the `GetItemInfo` global removed.
