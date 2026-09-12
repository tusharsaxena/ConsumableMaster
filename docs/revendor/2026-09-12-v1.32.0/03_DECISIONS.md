# 03 — Decisions

This run was non-interactive. The owner's bulk-logging instruction (2026-09-12) settled the outcome
in advance, and the orchestrator carried it, with a binding correction after the v1.32.0 review. No
interview was held. As instructed, no issue was filed and nothing was pushed.

| Candidate | Outcome | Basis | Record |
|---|---|---|---|
| Options `bulkBegin` / `bulkEnd` | **not applicable as a field; its shape adopted in the host** | The descriptor has only `get` / `set`, and every reset is addon code | `Helpers.Bulk`, `Helpers.MuteSetLog`, `SetManyAndRefresh`'s `opts.bulk`; see `04_EXECUTION_PLAN.md` |
| Slash `bulkBegin` / `bulkEnd` | **not applicable** | `CliResetAll` is never reached; `/cm resetall` is the addon's own verb | None. It is not a decline, so no issue is owed |
| Pool | settled, unused | Premise unchanged at Pool minor 3 | None |

## The correction after the v1.32.0 review

It is binding, and the host shape already met it when it arrived:

- **N is the rows whose value changed.** `bulkEnd`'s `count` counts rows `applyDefault` returned. The
  host's own tally counts only a write that changes the stored value, compared deep for tables.
- **Nested acts log once.** The chain of open frames is the depth counter: an inner frame folds its
  tally into the outer, and only the outermost logs. A `MuteSetLog` frame silences every frame around
  it, which gives the profile reset one line overall.
- **An all-default Defaults press** logs `...: 0 rows`, and never a per-row line. The addon **emits**
  the line at zero rather than suppressing it: the act ran, and the console says it changed nothing.
