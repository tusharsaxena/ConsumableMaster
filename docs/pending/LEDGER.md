# Pending-item decision ledger

This file is the record of every pending item that has been brought to the user
and decided. It is created and maintained by **`/wow-addon:pending-audit`**,
which sweeps the addon for unfinished work — TODO/FIXME markers, unexecuted
audit and review plan steps, doc open questions, open GitHub issues, and
recorded-but-unacted Claude memory — and interviews each one.

The ledger's job is to make a decision *stick*. Each row is matched on its **ID
plus its evidence hash** (the first 8 chars of `sha1` over the item's verbatim
evidence text). A closed item never resurfaces — unless its evidence text
itself changes, in which case the hash no longer matches and the item is
correctly raised again as something that has moved since you decided it.

## Notation

| Marker | Value | Meaning | Re-surfaces? |
|---|---|---|---|
| 🟢 | `done` | Implemented in the run named by the Date column | No — closed |
| 🔵 | `wont-do` | Deliberately closed; it will never be done | No — closed |
| 🟡 | `deferred` | Not now; still on the books | Yes, as a collapsed count |

Green is resolved, blue is a settled close (declining to do something is a
decision, not a failure), and yellow is the only state still asking for
attention — a column of yellow is this file telling you what is left. There is
deliberately no red: nothing here is an error state.

Both the marker and the word are always written. The word is the data — it is
what `grep wont-do` finds and what a screen reader announces; the marker is
only an affordance for scanning.

## Decisions

| ID | Evidence hash | Source | Decision | Date | Rationale |
|---|---|---|---|---|---|
| PLAN-02 | `9eae021a` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` — CM-33 | 🟢 done | 2026-07-31 | Applied the bundle's remediation as written: heading renamed in `CLAUDE.md`, by-name cross-reference added to the first Hard rule in `docs/agent-context.md`. |
| PLAN-03 | `572c9cbc` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` — CM-30 | 🟢 done | 2026-07-31 | Closed as confirmed, no change: `docs/scope.md:20`, `docs/agent-context.md:25` and `docs/ARCHITECTURE.md:84` all scope the deviation to TooltipCache text parsing, and classification still keys on numeric `classID`/`subClassID`. |
| PLAN-04 | `6cf64ad0` | `docs/reviews/2026-05-02` — T6.5 / F-021 / LLD-19 | 🟢 done | 2026-07-31 | Fixed ahead of the original trigger rather than waiting for the first numeric dropdown row — cheaper to remove the trap now than to debug it later. Implemented per LLD-19. |
| MEM-01 | `414d58c6` | `memory/MEMORY.md` — augment-rune index line | 🟢 done | 2026-07-31 | Refreshed the entry and closed the two in-game confirmations; user confirmed the behaviour was verified in game. Stale test count dropped in favour of the README badge as the single source. |
| PLAN-01 | `b60869ea` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` — CM-32 | 🔵 wont-do | 2026-07-31 | User declined both branches of CM-32 — no Wago ID is being added, and no tracked-deviation note is being recorded for it. (Reason not stated; inferred as "not worth documenting either way".) A future standards audit will still flag the missing field. |
| PLAN-06 | `51c75525` | `docs/reviews/2026-05-02` — out-of-scope follow-ups | 🔵 wont-do | 2026-07-31 | The premise is gone: `FireConfigChanged` was deleted by the same review's T3.1 and `core/Bus.lua` is now the addon's real message seam, so there is nothing left to wire up. |
| PLAN-09 | `b04454e7` | `docs/reviews/2026-05-02` — out-of-scope follow-ups | 🔵 wont-do | 2026-07-31 | Self-closing on the review's own terms: `formatNumber` is already O(n) one-pass and the "only revisit if a profile demands" trigger has never fired and is not being watched for. |
| PLAN-05 | `9f00b84c` | `docs/reviews/2026-05-02` — T6.4 / F-020 | 🟡 deferred | 2026-07-31 | Keeping the review's profiling trigger — no measurement has shown the per-render `craftingQualityAtlas` lookup to cost anything. Settled together with PLAN-08, which restates the same change. |
| PLAN-07 | `7b7d4f39` | `docs/reviews/2026-05-02` — out-of-scope follow-ups | 🟡 deferred | 2026-07-31 | `_viewedSpecAuto` already gives the right default silently; surfacing it as a checkbox is discoverability polish, not a fix. |
| PLAN-08 | `6476e9bc` | `docs/reviews/2026-05-02` — out-of-scope follow-ups | 🟡 deferred | 2026-07-31 | Duplicate of PLAN-05 (session-scoped memo for `craftingQualityAtlas`); decided in the same call and carries the same profiling trigger. |
| PLAN-10 | `d6320e6b` | `docs/reviews/2026-05-02` — out-of-scope follow-ups | 🟡 deferred | 2026-07-31 | The discovered-set sweep already runs on every `PLAYER_ENTERING_WORLD`, so a `/cm gc` verb is a debugging convenience rather than a user need. |
| ISS-03 | `f22d2fde` | GitHub issue #3 — Stat Weights | 🟡 deferred | 2026-07-31 | A design project, not a pending-audit call: the weight-sourcing question is unsolved and it changes the ranking model. Ordered priority ranks correctly for the common case today. |
| ISS-04 | `53efa51a` | GitHub issue #4 — Checkbox to enable | 🟡 deferred | 2026-07-31 | Not now. Stays tracked on GitHub; delete-and-re-add remains the workaround for excluding an item. |
| ISS-07 | `c7f1bc72` | GitHub issue #7 — per-slot keybindings | 🟡 deferred | 2026-07-31 | The issue's own two open questions (override bindings vs. `Bindings.xml`, conflict handling) want deciding first; users can bind on a Blizzard bar meanwhile. |
| ISS-08 | `d139aba2` | GitHub issue #8 — cooldown and count styling | 🟡 deferred | 2026-07-31 | Stock Blizzard rendering works and honours the system CVar; better to let the secret-value cooldown rework in `982411c` settle in game before layering styling on that path. |
| ISS-09 | `428b4f30` | GitHub issue #9 — styling for empty slots | 🟡 deferred | 2026-07-31 | Current behaviour is functional, just visually flat. Issue #9 already tracks it; no additional issue needed. |
| LIBKA0S-01 | `slash-cli` | LibKa0s adoption — `core/SlashCommands.lua` → `LibKa0s-Slash-1.0` | 🟡 deferred | 2026-07-31 | Adopting the dispatcher would make the file **bigger**: it replaces 19 lines (`printHelp` + `KCM:OnSlashCommand`) and costs ~50 back, because a missing library still needs a hand-written dispatcher — unlike the console, `/cm` is how a user reports the addon is broken, so it cannot simply degrade. The 116-line schema CLI is the part worth deleting, and it is blocked upstream (see LIBKA0S-02). Revisit when it is not. |
| LIBKA0S-02 | `slash-upstream` | `libs/LibKa0s/Slash.lua` — two shape mismatches vs the Ka0s options schema | 🟡 deferred | 2026-07-31 | Blocks the schema-CLI half of LIBKA0S-01; both need fixing in `github.com/tusharsaxena/LibKa0s`, not patched in the vendored copy. (1) `lib.FormatValue:92` reads a color as `v.r/v.g/v.b/v.a` while the standard's own color widget writes `{r, g, b, a}` **positionally** (`settings/Panel.lua:693`), and `kv()` at `Slash.lua:251` calls it directly with no descriptor hook — so all seven color rows would render `{0.00, 0.00, 0.00, 1.00}`, and green, since `tests/test_slash.lua:604` only checks the path appears. (2) `allowedValues:135` returns the `tostring`'d **keys** of `pairs(row.values)`, but enum rows are ordered arrays of `{value=, text=}` (`settings/Panel.lua:566-572`), so `macroBar.orientation` would offer "1, 2" — and `parseNumber:125` has no enum branch at all, regressing commit `6a92e63`. Both verified by reading the source. |
