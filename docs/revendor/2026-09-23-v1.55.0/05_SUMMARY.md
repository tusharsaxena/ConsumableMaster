# 05 — Summary: LibKa0s v1.54.2 → v1.55.0

## The move

Tag `v1.54.2` → `v1.55.0` (`6f9c5e0`), re-vendored in `34813a4` (`01_DELTA.md`). No existing file's
LibStub minor moved; three new majors arrived at minor 1: `Compat.lua`, `Bus.lua`, `Schema.lua`
(the per-file table is `01_DELTA.md` §3b/3c). Test kit revision 24 → 25.

## Delivered for free (class A)

Test-kit revision 25: the (basename, directory) suite key, the kit's `layout-§1` cap gate and
`localization-§5` prose gate (wired in `34813a4`), the `.gitattributes` body case in `test_eol`, and
the commit SHA in the automated-test record.

## Contract blockers

Library: none. Kit: one, the bare `test_prose` / `test_layout_cap` collision under revision 25,
resolved in the re-vendor commit (`01_DELTA.md` §3g).

## Adopted

| Candidate | Commit | Cases added | What moved |
|---|---|---|---|
| C1 `LibKa0s-Compat-1.0` | `c14db97` | 7 (3 characterization first, 4 with the code) | `GetSpecialization`, `GetSpecializationInfo`, `GetSpellName`, `IsSecret` bound to the major; reader and guard arms; by-name parity; `docs/compat-layer.md` retired (two host shims, under the threshold) |
| C2 `LibKa0s-Bus-1.0` | `e3c13b7` | 9 (3 characterization first, 6 with the code) | `KCM.busRecord` tracks every target; `NewBusTarget(subscribe)` shim; `KCM.Bus.StandDown` / `StandUp` delegate; `KCM.MSG` through `Catalog`; untracked-target stub; by-name parity |

## Declined

| Candidate | Issue | State | Severity | Why |
|---|---|---|---|---|
| C3 `LibKa0s-Schema-1.0` | [#39](https://github.com/tusharsaxena/ConsumableMaster/issues/39) | `state:triaged` | `severity:medium` | No per-consumer delta for this repo (`schema.md` §11); partial-adopter write semantics (row `normalize`, batch `SetMany`); the API document lets a partial adopter defer (`version-1-docs.md:360-373`) |

## Skipped or unreached

None.

## Suite results

Every run was from the repo root through `ka0s-bounded`. Tests are passed / failed / skipped; lint is
warnings / errors.

| Gate | Headless tests | Lint |
|---|---|---|
| Before this run (after `34813a4`) | 982 / 0 / 0 | 0 / 0 in 116 files |
| C1 characterization, on host code | 985 / 0 / 0 | not run |
| C1 commit `c14db97` | 989 / 0 / 0 | 0 / 0 in 116 files |
| C2 characterization, on host code | 992 / 0 / 0 | not run |
| C2 commit `e3c13b7` | 998 / 0 / 0 | 0 / 0 in 116 files |
| Bundle commit | 998 / 0 / 0 | 0 / 0 in 116 files |

Each new post-code case was also run once against the host code by restoring its pre-change file
and was red there: 4 of 4 for C1, 6 of 6 for C2.

## Findings

- **[upstream] The "ConsumableMaster needs no runner edit" claim is wrong.** It appears in LibKa0s
  `docs/api/Compat/version-1-docs.md:224-226` and in the sweep's `compat.md` §4 and §8. `Kit.expose`
  auto-wires `mock.LibStub`, but this repo's mock publishes its per-build LibStub only as
  `_G.LibStub` (`tests/wow_mock.lua:685-691`), so no surface source was registered. Fixed here with
  a callable source in `tests/run.lua`. The library document should drop the claim or say what the
  auto-wire needs.
- **`GetSpellName` can now return a secret name to its callers.** A secret name no longer raises
  inside `KCM.Compat`. `modules/MacroManager.lua:55` then feeds the name into macro-body
  composition. Whether a spell name is ever secret there is an in-game question, and this run could
  not answer it headlessly.
