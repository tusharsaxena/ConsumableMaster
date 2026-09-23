# 02 — Candidates: LibKa0s v1.54.2 → v1.55.0

Steps 5–8 of `revendor-libka0s`, run on 2026-09-23 on branch `suite/2026-09-22-standards-sweep`
after the re-vendor commit `34813a4`. The interview is replaced by the owner's delegation (CP-6):
each decision below is taken by the delegated rules and recorded in `03_DECISIONS.md` as it lands.

## Sources

```sh
git -C ../LibKa0s log --oneline v1.54.2..v1.55.0
```

- `../LibKa0s/CHANGELOG.md`, the `## v1.55.0 — 2026-09-23` block: the three new majors at `:52`
  (Compat), `:65` (Bus) and `:78` (Schema); everything else in the block is test-kit revision 25.
- The API documents for the three new majors (no existing major's minor moved, so no other API
  document has a `Since` delta to diff): `docs/api/Compat/version-1-docs.md`,
  `docs/api/Bus/version-1-docs.md`, `docs/api/Schema/version-1-docs.md`.
- The sweep's design specs, whose per-consumer adoption deltas name this repo with `file:line`:
  `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/3b-specs/compat.md` §8.0
  and §8.4, `.../bus.md` §12 (common block and **ConsumableMaster**), `.../schema.md` §11 (common
  block; no ConsumableMaster entry).
- Recorded declines: `gh issue list --search "LibKa0s" --state all` in this repo, and
  `git grep -i 'declin\|not adopt' -- docs/*.md`. Neither names Compat, Bus or Schema, so none of
  the three carries a settled refusal.

## Class A — delivered on the copy (not offered)

- **Test-kit revision 25** (`CHANGELOG.md` v1.55.0 block, sections *The declaration is the pair*,
  *`test_layout_cap.lua`*, *`test_prose.lua`*): the (basename, directory) suite key, the kit's cap
  gate, the prose gate's generated-data input, the `.gitattributes` body case in `test_eol`, the
  commit SHA in the automated-test record. Wired in `34813a4` (`01_DELTA.md` records the one kit
  blocker it resolved). Nothing here needs a host decision.

No contract blocker: no minor moved under a consumed major (`01_DELTA.md` §3g).

## Class B — host change under a consumed major

None. Every consumed major's minor is unchanged from v1.54.2.

## Class C — whole-module adoption of a major this addon does not consume

### C1. `LibKa0s-Compat-1.0` — the spec pair, `IsSecret` and `GetSpellName` onto the library

- **What.** `core/Compat.lua` resolves the major and wires five of its members; the call surface
  `KCM.Compat.X` is unchanged, so no call site moves.
- **Evidence.** `CHANGELOG.md:52`; `docs/api/Compat/version-1-docs.md:43-58` (surface),
  `:137-242` (*Degradation*: reader arm, guard arm, *How a host wires it*, the gate);
  `compat.md` §8.4 (this repo: `core/Compat.lua:17-33` spec pair, `:60-63` `IsSecret`, `:68-83`
  `GetSpellName` → library; `:36-51` the class-ID pair stays; "ConsumableMaster needs no runner
  edit", §8 preamble and API doc `:224-226`).
- **Touches.** `core/Compat.lua`, `tests/test_compat.lua`, `tests/test_surface_parity.lua`,
  `docs/ARCHITECTURE.md`, `docs/module-map.md`.
- **Fixes a live defect.** `core/Compat.lua:72, 76, 80` compare every rung's answer with `""`; a
  secret spell name there raises in combat (`compat.md` §2.2 row 5, J5). The library asks
  `IsSecret` first and returns a secret untouched.
- **Blast radius: replaces host code.** Five member bodies (about 40 lines) become one-line
  delegates with a reader arm (`nil`) and a guard arm (the one-rung `issecretvalue` body). Stated
  behavior changes: a secret name is returned rather than compared; a spell id that is neither a
  number nor a string answers `nil` without calling a rung (was: any truthy value reached the
  client); on a library-absent install the spec pair and `GetSpellName` answer `nil` (the reader
  arm) rather than reading the client.
- **Recommendation: adopt.** The spec prescribes it for this repo, and it removes a combat raise.

### C2. `LibKa0s-Bus-1.0` — the stand-down record and the catalog

- **What.** `core/Bus.lua` builds `KCM.busRecord = Bus:New{ name, isDown = KCM.IsStoodDown }`;
  `KCM.NewBusTarget(subscribe)` stays as a shim over `busRecord:NewTarget()`;
  `KCM.Bus.StandDown` / `StandUp` delegate; `KCM.MSG = Bus.Catalog(addonName, {...})`.
- **Evidence.** `CHANGELOG.md:65`; `docs/api/Bus/version-1-docs.md:69-75` (surface), `:102-170`
  (tracked target, while down, replay, retention), `:184-220` (`Catalog`), `:257-313` (worked
  example and the untracked-target stub); `bus.md` §12 common block and **ConsumableMaster**
  (`core/Bus.lua:50-76` shim, `:78-84` catalog, `isDown` → `core/LifecycleSetup.lua:135`,
  `:73` / `:111` unchanged, `tests/test_bus.lua:23, 65, 76, 87` closure-less targets now tracked);
  `options-ui-§1` names the untracked-target stub.
- **Touches.** `core/Bus.lua`, `tests/test_bus.lua`, `tests/test_surface_parity.lua`,
  `docs/ARCHITECTURE.md` (`## Message Bus`, `## The disabled state is total`, `## Known
  Limitations`), `docs/module-map.md`.
- **Closes a recorded gap.** `core/Bus.lua:45-49` records that a receiver which registers inline, or
  a target made without a subscribe function, is the one survivor of every stand-down. The record
  tracks every target, and a registration made while the bus is down is deferred to `StandUp`.
- **Blast radius: replaces host code.** The closure list and its two loops go; replay moves from
  re-running closures to replaying recorded registrations. The four production closures register
  unconditionally (`core/Bus.lua:95`, `modules/MacroBar.lua:587`, `settings/OptionsShim.lua:263`,
  `settings/Profiles.lua:119`), so the registration set is identical. `KCM.MSG` becomes strict: an
  undeclared key raises on read.
- **Recommendation: adopt.**

### C3. `LibKa0s-Schema-1.0` — the settings schema runtime

- **What.** The path primitives, row registry, the write seam `Set`, the bulk bracket, the profile
  reset count and `Validate`.
- **Evidence.** `CHANGELOG.md:78`; `docs/api/Schema/version-1-docs.md:360-373` (*A host that keeps
  its own seam*: "A partial adopter for which that trade is not worth two code paths MAY defer
  adoption until it adopts `Set`"), `:385-409` (*Adoption notes*: unknown path refused, table
  values copied, raising `onChange` propagates, `[Set]` before `onChange`). `schema.md` §11 has no
  ConsumableMaster entry; its survey (`schema.md:6-12`) read nine homes and not this one.
- **Touches (if adopted).** `settings/Panel.lua` (`Helpers.Resolve :155`, `Get :271`, `Set :321`,
  `Bulk :366`, `SetAndRefresh :974`, `SetManyAndRefresh :1040`, `KCM.Schema:Set/SetMany
  :1068-1072`), `settings/Slash.lua`, `settings/OptionsSetup.lua`, `tests/test_schema.lua` and every
  suite that pins the degraded write path.
- **Blast radius: replaces host code, the largest of the three.** This repo's seam carries
  whole-value `order` / `map` rows with a per-row `normalize` (`settings/Panel.lua:945-951`), the
  batch `SetMany` that logs one bracket line, and session-only paths — the same single-consumer
  write semantics that made AuraMaster and MultiMeters partial adopters (`schema.md` §1).
- **Recommendation: not now.** No per-consumer delta exists for this repo, and the API document
  lets a partial adopter defer until it adopts `Set`. Filed as a deferred duplication.

## Not candidates

- `LibKa0s-Pool-1.0` is also unconsumed, but its minor did not move in this range; it is outside
  this run's delta.
