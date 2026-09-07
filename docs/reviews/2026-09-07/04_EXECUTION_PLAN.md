# 04 — Execution plan

Ordered milestones for an agent team implementing `02_PROPOSED_CHANGES.md`. Every task lands on this
addon's own files; **no task touches `libs/` or `tests/_kit/`**.

Baseline to hold at every checkpoint: `luacheck .` → 0/0 over 59 files, `lua5.1 tests/run.lua` → all
green, `lizard` → 0 warnings.

---

## Milestone 1 — Zero-risk text (no behaviour change)

**Done when:** the suite is green at the same count (749), `luacheck` is 0/0, and no shipped string,
number or code path has moved.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| T-1.1 | `lua-refactorer` | `CM-R-07` / C-06 | `settings/Category.lua`, `modules/Selector.lua` |
| T-1.2 | `docs-hygiene` | `CM-R-04` / C-07 | `core/DebugLogSetup.lua`, `modules/MacroBarButton.lua`, `tests/test_defaults.lua`, `tests/test_surface_parity.lua` |
| T-1.3 | `docs-hygiene` | `CM-R-13` / C-04 item 4 | `tests/test_surface_parity.lua` |

**Concurrency.** T-1.1 is disjoint from both others → **parallelizable**. T-1.2 and T-1.3 both touch
`tests/test_surface_parity.lua` → **must serialize**, T-1.2 first (it fixes the numbers in the same
comment block T-1.3 deletes a copy of, so doing T-1.3 first would make T-1.2 re-read a moved file).

**Commit boundary.** One commit: `chore: correct stale comment citations and the debug format verbs`.

---

## Milestone 2 — Localization routing

**Done when:** `grep -rn 'SetText("' modules settings core | grep -v 'L\['` returns nothing that is
user-facing prose, the suite is green at 749, and M-02 in `03_SMOKE_TESTS.md` shows byte-identical
rendering.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| T-2.1 | `localization` | `CM-R-02` / C-02 | `modules/KCMMacroDragIcon.lua`, `modules/KCMItemRow.lua` |

**Concurrency.** Disjoint from every other milestone's file set → **parallelizable with Milestone 1
and Milestone 3** if the team has the capacity. Nothing in Milestone 4 or 5 touches `modules/KCMItemRow.lua`
or `modules/KCMMacroDragIcon.lua`.

**Note.** Do **not** add rows to `locales/enUS.lua`. The identity metatable answers them, and that
file's header restricts rows to strings whose display text must differ from the key.

**Commit boundary.** `feat(locale): route the two custom widgets' display strings through NS.L`.

---

## Milestone 3 — Complete the seam guards

**Done when:** `tests/test_surface_parity.lua`'s `CORE_SEAM` matches the grep it documents, the case
count is unchanged at 749, and `docs/test-cases.md` is byte-identical (verified with a `--list` diff
to a scratch path).

| Task | Role | Implements | Files touched |
|---|---|---|---|
| T-3.1 | `test-engineer` | `CM-R-03` / C-04 items 1-3 | `tests/test_surface_parity.lua` |

**Concurrency.** Touches `tests/test_surface_parity.lua`, which Milestone 1's T-1.2 and T-1.3 also
touch → **must serialize after Milestone 1**.

**Verification, in this order:** run the case and watch it stay green (`MakeCloseButton` is on the
ignore list, so parity holds); then temporarily remove it from the ignore list and confirm the case
goes **red** naming the member. A guard that cannot go red is `CM-R-03` in a new costume.

**Commit boundary.** `test: the Core parity list covers the whole seam again`.

---

## Milestone 4 — CHECKPOINT: human review before touching SavedVariables

**Not a task list.** A pause. Before Milestone 5 begins:

1. Confirm Milestones 1-3 are merged and the suite is green at 749.
2. A human reads `02_PROPOSED_CHANGES.md`'s C-01 sketch — specifically `inferProfileVersion`'s
   "brand new vs pre-split" inference — and signs off on the heuristic. This is the one change in the
   set that can lose a player's stored settings if it is wrong, and it is not something to discover
   at the smoke-test stage.
3. Confirm a SavedVariables backup exists (`03_SMOKE_TESTS.md` pre-flight step 6).

**Exit criterion.** Explicit human approval of the `inferProfileVersion` heuristic, recorded in the
milestone's commit message or PR thread.

---

## Milestone 5 — Profile-scoped migration

**Done when:** the three new `test_database.lua` cases are green, the renamed case is green,
`docs/test-cases.md` and the README `[Tests]` badge both read the new count, and M-01a/b/c in
`03_SMOKE_TESTS.md` pass in client.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| T-5.1 | `test-engineer` | `CM-R-01`, `CM-R-14` / C-05 cases 1-3 | `tests/test_database.lua` |
| T-5.2 | `savedvariables-engineer` | `CM-R-01` / C-01 | `core/Database.lua` |
| T-5.3 | `test-engineer` | `CM-R-14` / C-05 case 4 | `tests/test_database.lua` |
| T-5.4 | `docs-sync` | regeneration of the inventory + badge | `docs/test-cases.md`, `README.md` |

**Order is mandatory and is not a concurrency observation.** T-5.1 **before** T-5.2: the three cases
are written to fail against today's code, and watching them go red is the only evidence they can go
red at all. T-5.2 turns them green. T-5.3 then extends the renamed case to assert the *new* invariant
(`db.profile.schemaVersion` is set), which is only meaningful once T-5.2 has landed.

**Concurrency.** T-5.1, T-5.3 and T-5.4 all touch files T-5.2 does not, but every one of them depends
on T-5.2's state → **fully serialized**. Nothing in this milestone is parallelizable.

**T-5.4 specifics.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md` — never
hand-edit it — and move the README `[Tests]` badge to the same number in the same commit. Both move
with the change that moved the count; neither is a follow-up.

**Commit boundary.** Two commits, in this order:
1. `test(db): pin the migration runner's behaviour on a non-active profile` (T-5.1, red).
2. `fix(db): gate profile migrations on a profile-scoped schema version` (T-5.2 + T-5.3 + T-5.4, green).

The red commit is deliberate and is the record that the case can fail. If the project's gate forbids
committing red, squash the two and say in the message that T-5.1's cases were verified red against
the parent commit.

---

## Milestone 6 — CHECKPOINT: in-client smoke tests

Run `03_SMOKE_TESTS.md` end to end. **Exit criterion:** M-01a, M-01b, M-01c, M-02, M-04 and the
twelve regression rows all PASS, and SavedVariables has been restored from the pre-flight backup.

Nothing beyond this point starts until M-01 is green — it is the only change in the set with a data
consequence.

---

## Milestone 7 — Colour decoder (conditional)

**Gated on a pre-check, and may not run at all.**

| Task | Role | Implements | Files touched |
|---|---|---|---|
| T-7.0 | `library-liaison` | pre-check | *(read-only)* `libs/LibKa0s/Options.lua`, `libs/LibKa0s/Slash.lua` |
| T-7.1 | `lua-refactorer` | `CM-R-05` / C-03 | `core/CoreSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua` |
| T-7.2 | `test-engineer` | `CM-R-05` | `tests/test_coresetup.lua`, `tests/test_slashsetup.lua` |

**T-7.0 is a hard gate.** Read — do not edit — the two vendored files and establish whether each
major tolerates `colorDecode` returning `nil` for a channel.

- **If both tolerate nil:** proceed to T-7.1 and T-7.2.
- **If either does not:** **stop.** Do not write a local fallback and do not patch the vendored copy.
  File it as an upstream item on `LibKa0s` for an **additive** change so every consumer gets it, and
  record `CM-R-05` as deferred-pending-upstream in `05_FINAL_SUMMARY.md`'s known follow-ups.

**Concurrency.** T-7.1 touches `settings/Slash.lua`, which nothing else in this plan touches, and
`core/CoreSetup.lua`, which nothing else touches either → **parallelizable with Milestone 2** if
T-7.0 has already cleared. T-7.2 must follow T-7.1.

**Commit boundary.** `refactor(color): one decoder for the positional colour shape, passed to both majors`.

---

## Milestone 8 — Upstream handoff (cross-repo; exits in this repo with a re-vendor commit)

**No task in this milestone edits a file under `libs/` in this repo.** This milestone exists because
`02_PROPOSED_CHANGES.md` carries two already-filed upstream items, plus whatever T-7.0 may add.

| Task | Role | Repo | Work |
|---|---|---|---|
| T-8.1 | `library-maintainer` | `LibKa0s` | Fix issue #15 (`OptionsCompose` double-wraps `LSMValues`) in `LibKa0s/OptionsCompose.lua`; bump that file's LibStub **minor** |
| T-8.2 | `library-maintainer` | `LibKa0s` | Fix issue #16 (parsers above `lib:New` read `lib.STRINGS` directly, so instance overrides cannot reach them) in `LibKa0s/Slash.lua`; bump that file's LibStub **minor** |
| T-8.3 | `library-maintainer` | `LibKa0s` | If T-7.0 escalated: the additive nil-tolerant `colorDecode` contract; bump the affected file's minor |
| T-8.4 | `library-maintainer` | `LibKa0s` | Tag a release carrying T-8.1 - T-8.3 |
| T-8.5 | `vendor-sync` | **this repo** | Re-vendor the **whole** `libs/LibKa0s/` and `tests/_kit/` folders from that tag; update the provenance line at `CLAUDE.md:58`; as its **own commit** |
| T-8.6 | `lua-refactorer` | **this repo** | In a **separate** commit: delete the `lsmValues()` workaround and its three `values = lsmValues(...)` overrides (`settings/MacroBar.lua:108-124`), and the three dead `ERR_*` overrides (`settings/Slash.lua:246-254`) |

**Exit criterion for this repo:** the re-vendor commit (T-8.5) is in, `tests/test_vendor_sync.lua`'s
two cases are green against the new tag, and T-8.6's workaround removal is a distinct commit that
diffs cleanly against it.

**Concurrency.** T-8.5 must be its own commit and must precede T-8.6. Neither may be folded into a
commit that edits this addon's own files, which is why T-8.6 is separate from T-8.5.

---

## Critical-path / concurrency map

```
M1 (T-1.1 ∥ [T-1.2 → T-1.3])
      │
      ├──────────────► M3 (T-3.1)          [shares tests/test_surface_parity.lua with M1 → serialize]
      │
      └──────────────► M4 CHECKPOINT ──► M5 (T-5.1 → T-5.2 → T-5.3 → T-5.4)  [fully serial]
                                                  │
M2 (T-2.1)  ∥ anything                            └──► M6 CHECKPOINT (in-client)
                                                              │
M7 (T-7.0 gate → T-7.1 → T-7.2)  ∥ M2                        │
                                                              └──► M8 (cross-repo, then re-vendor here)
```

**Files touched by more than one task — must serialize:**

- `tests/test_surface_parity.lua` — T-1.2, T-1.3, T-3.1.
- `tests/test_database.lua` — T-5.1, T-5.3.
- `settings/Slash.lua` — T-7.1 and T-8.6. If Milestone 7 runs, it lands well before Milestone 8, so
  there is no real contention, but a T-8.6 that starts early must rebase onto T-7.1.
- `settings/MacroBar.lua` — T-8.6 only.

**Genuinely parallel:** T-1.1 with T-1.2/T-1.3; Milestone 2 with everything; Milestone 7 (post-gate)
with Milestone 2.

---

## Deliberately not planned

- `CM-R-06` — `docs/automated-tests/RESULTS.md` regenerates at **release**
  (`/wow-addon:bump-version`). No task here writes it, and no task runs `lizard` into the repo.
- `CM-R-08` — line-ending stragglers belong to `/wow-addon:standards-audit`'s roll-up.
- `CM-R-09` — no measurement backs it and no scenario would show the improvement. If it is ever
  taken up, the first task is adding a `tests/perf.lua` scenario over the refresh burst, not editing
  `settings/Panel.lua`.
- `CM-R-10`, `CM-R-11`, `CM-R-12` — notes, no change attached.
