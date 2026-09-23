# 03 — Decisions

Delegated by the owner (CP-6): no interview. Each decision is taken by the delegated rules — adopt
what the sweep's spec prescribes for this repo; decline as *not now* where the spec or the API
document lets the repo defer, or where the adoption cannot land green without changing pinned or
visible behavior after one honest attempt; decline as *never* only for a structural misfit a spec
or this repo's docs record. A decline is filed as a public GitHub issue in this repo.

Order: fixes a live defect → closes a recorded gap → new capability, smallest blast radius first.

| # | Candidate | Class | Order key | Decision |
|---|---|---|---|---|
| C1 | `LibKa0s-Compat-1.0` | C | fixes a live defect (secret `""` compare) | see below |
| C2 | `LibKa0s-Bus-1.0` | C | closes a recorded gap (`core/Bus.lua:45-49`) | see below |
| C3 | `LibKa0s-Schema-1.0` | C | new capability | see below |

## C1 — `LibKa0s-Compat-1.0`: adopt

Decided 2026-09-23. `compat.md` §8.4 prescribes it for this repo, member by member, and it fixes
the in-combat raise on a secret spell name (`core/Compat.lua:72, 76, 80`). The class-ID spec pair
stays host code (§8.4, single consumer, `compat.md` §5.3).

**Landed** in `c14db97`. Characterization first (3 cases, green on the host code at 985/0/0):
`GetSpellName` arity on every rung and on a miss, the `GetSpecializationInfo` multi-return passed
through, `IsSecret` normalized to a boolean. Then the code, with 4 cases red on the host code and
green after: the secret name returned untouched, the out-of-domain id asking no rung, the degraded
load (readers `nil`, guard following `issecretvalue`, host-only members unaffected), and the
by-name parity case. Two findings on the way:

- **The spec's "ConsumableMaster needs no runner edit" is wrong.** `Kit.expose` auto-wires
  `mock.LibStub`, and this repo's mock carries no such field (`tests/wow_mock.lua:685-691` publishes
  the per-build LibStub as `_G.LibStub` only), so no surface source was registered and the by-name
  call raised `no surface source is registered`. Fixed host-side in `tests/run.lua` with a callable
  source that reads the current `_G.LibStub`. The same claim sits in LibKa0s
  `docs/api/Compat/version-1-docs.md:224-226` and `compat.md` §4 / §8: an **[upstream]** doc finding.
- **`docs/compat-layer.md` retired.** With four members on the library, `core/Compat.lua` publishes
  two shims of its own (`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` answers
  2), under `documentation-§3`'s threshold of three, which says such a file "owes a *Not applicable*
  row ... rather than a page", and library shims MUST NOT be re-documented there. The map row reads
  *Not applicable*; the page's two host facts (`GetNumSpecializationsForClassID` answers `0`; each
  `GetSpellName` caller picks its own placeholder) moved into `docs/module-map.md`'s row.

## C2 — `LibKa0s-Bus-1.0`: adopt

Decided 2026-09-23. `bus.md` §12 prescribes it for this repo (record half and catalog), and it closes
the gap `core/Bus.lua:45-49` records: a target made without a subscribe function, or a receiver that
registers inline, survives every stand-down. The host's seam names (`KCM.NewBusTarget`,
`KCM.Bus.StandDown`, `KCM.Bus.StandUp`, `KCM.MSG`) stay.

**Landed** in `e3c13b7`. Characterization first (3 cases, green on the host code at 992/0/0): the
message registration set restored by name across `KCM.Bus.StandDown` / `StandUp`, a subscribe
function run once on the returned target, and the `RECOMPUTE` route silent while down and live
after. Then the code, with 6 cases red on the host code and green after: a closure-less target taken
down and replayed, a registration made while down deferred to the stand-up, a bare `StandUp` refused
while the latch holds the addon down, `KCM.MSG` strict, the degraded load (untracked targets still
subscribe; `StandDown` / `StandUp` answer `0`), and the by-name parity case against
`LibKa0s-Bus-1.0`. `tests/test_disabled.lua` (the full `slash-commands-§7` suite) stayed green
unmodified. Three production comments that described the old closure mechanism
(`modules/MacroBar.lua`, `settings/OptionsShim.lua`, `settings/Profiles.lua`) were corrected, with
comment changes only.

## C3 — `LibKa0s-Schema-1.0`: not now

Decided 2026-09-23. Filed as
[#39](https://github.com/tusharsaxena/ConsumableMaster/issues/39), `state:triaged`,
`severity:medium` (a deferred duplication). Reasons:

- The sweep's `schema.md` §11 gives this repo no delta, and its survey (`schema.md:6-12`) never read
  this repo's seam.
- The seam's write semantics are the partial-adopter kind: a row `normalize` on whole-value `order` /
  `map` rows (`settings/Panel.lua:945-951`), a batch `SetMany` with one bracket line
  (`:1040`, `:1068-1072`), and session and global path diversions.
- The API document lets a partial adopter defer until it adopts `Set`
  (`docs/api/Schema/version-1-docs.md:360-373`).

Not *never*: no spec or doc here records a structural misfit, and a later Schema minor could fit.
