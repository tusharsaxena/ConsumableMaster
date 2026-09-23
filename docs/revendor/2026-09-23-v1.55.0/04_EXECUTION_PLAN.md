# 04 — Execution plan

One commit per adopted candidate, each behind the green gate (`ka0s-bounded lua tests/run.lua` and
`ka0s-bounded luacheck .`, run from the repo root). The characterization cases land and pass
against the host code **before** the code changes; they then have to stay green across the change.
A candidate whose suites go red and cannot be made green without changing pinned or visible
behavior is rolled back to its commit boundary and declined.

## C1 — `LibKa0s-Compat-1.0`

**Files.** `core/Compat.lua`, `tests/test_compat.lua`, `tests/test_surface_parity.lua`,
`docs/ARCHITECTURE.md` (`### LibKa0s adoption`), `docs/module-map.md` (the `core/Compat.lua` row).

**Characterization first (green on the host code).**
- Return arity is exactly one for `GetSpellName` on each rung and on a miss (the host already
  truncates; the library must too).
- `GetSpecializationInfo` passes the rung's multi-return through unmodified (count and values).
- `IsSecret` answers exactly `true` / `false`, never the raw `issecretvalue` return.

**Then the code.** Resolve `LibStub("LibKa0s-Compat-1.0", true)` at the top; wire
`GetSpecialization`, `GetSpecializationInfo`, `GetSpellName` (reader arm: `nil`) and `IsSecret`
(guard arm: the one-rung body, commented as the deliberate duplication the API document's
*Degradation* section names). `GetNumSpecializationsForClassID` and
`GetSpecializationInfoForClassID` stay.

**Cases added with the code.**
- A secret name from the top rung is returned untouched and never compared with `""` (a fixture
  whose secret raises on `==`). Red on the host code, which is the defect.
- A non-number, non-string id answers `nil` without calling a rung.
- Degraded load (library files skipped, `L.loadFiles(..., omitLibs)`): every wired reader answers
  the absent table's value (`nil`), the guard follows `issecretvalue` under the same fixture, and
  the two host-only members still answer.
- `Kit.assertSurfaceParity(degradedCompat, "LibKa0s-Compat-1.0", ignore)` with `ignore` =
  `CanAccess`, `IsSafeKey`, `GetSpellInfo`, `GetSpellTexture`, `GetSpellCooldown` (not wired). The
  runner registers no surface source, so `Kit.expose` wires the mock's `LibStub` (no runner edit).

**Proving assertion.** The existing `tests/test_compat.lua` cases (the ladder, `""` fall-through,
`C_Spell.GetSpellInfo` middle rung, legacy global, nil guards, spec namespace preference) pass
unmodified against the library.

**Commit boundary.** One commit: code, tests, docs.

## C2 — `LibKa0s-Bus-1.0`

**Files.** `core/Bus.lua`, `tests/test_bus.lua`, `tests/test_surface_parity.lua`,
`docs/ARCHITECTURE.md` (`## Message Bus`, `## The disabled state is total`, `## Known
Limitations`, `### LibKa0s adoption`), `docs/module-map.md`.

**Characterization first (green on the host code).**
- Stand-down then stand-up through the latch (`H.SetAndRefresh("enabled", false/true)`) restores
  exactly the message registration set held before, by name (the registration set is the output).
- A subscribe function passed to `KCM.NewBusTarget` runs once at creation, and the target it
  returns is the one it registered on.
- The pipeline route (`RECOMPUTE` → `RequestRecompute(reason)`) still fires after a round trip.

**Then the code.** Resolve `LibStub("LibKa0s-Bus-1.0", true)`, else the untracked-target stub the
Bus API document's *Worked example* prints (`options-ui-§1`). Keep `KCM.bus` (the publisher),
`KCM.NewBusTarget(subscribe)` as a shim, `KCM.Bus.StandDown` / `StandUp` as delegates (the latter
logging `rejected` through `KCM.Debug`), `KCM.MSG` through `Bus.Catalog`.

**Cases added with the code.**
- A closure-less target is tracked: its registration is down after a stand-down and back after a
  stand-up (was: the survivor `core/Bus.lua:45-46` names).
- A registration made while down is not live until stand-up.
- `KCM.MSG` is strict: reading an undeclared key raises.
- Degraded load: `NewBusTarget` still hands out a private embedded target and its subscribe runs;
  `StandDown` / `StandUp` answer `0` and `0, {}`; `KCM.MSG` is the plain table.
- `Kit.assertSurfaceParity(stub, "LibKa0s-Bus-1.0")` against the stub published on the degraded load.

**Commit boundary.** One commit: code, tests, docs.

## C3 — `LibKa0s-Schema-1.0`

Declined (not now): no code. One `gh issue create` in this repo.

## Close-out

Regenerate `docs/test-cases.md` (`lua tests/run.lua --list`), move the README test badge if the
count moved, write `05_SUMMARY.md`, and commit the bundle behind the green gate.
