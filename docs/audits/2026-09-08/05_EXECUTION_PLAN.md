# 05 — Execution plan

**Audit:** 2026-09-08 · **Standard:** v2.39.0 (2026-09-07) · keyed to `02_DEVIATIONS.md` and
`04_TECHNICAL_DESIGN.md`.

Read this file and `02_DEVIATIONS.md` as one document: the figures below are the same figures — **6**
root deviations and **7** including the one dependent, **24** continuation citations across **12**
files, **2** British spellings in `docs/perf-analysis/README.md`, **4** census figures of which **2**
are wrong, **2** bundles without an `ANALYSIS.md`.

This is a **read-only** audit. Nothing below has been executed. The whole plan is three commits in
this repo plus one upstream, touching no shipped Lua.

**Green gate.** `versioning-git` and `testing-§4`: every commit lands with `luacheck .` at 0/0 and
`lua tests/run.lua` fully green. Baselines to hold: **0 warnings / 0 errors in 102 files** and
**786 passed, 0 failed, 0 skipped, 786 total**.

---

## Sprint 0 — upstream (blocks Sprint 1 step 2)

Not in this repository.

### 0.1 — `CM-81` (part 1): publish `synchronis`

- [ ] In `WowAddonStandards/standards/standards/localization.md`, add `"synchronis"` to the
      `BRITISH` block's `-ise / -isation` group, between `standardis` and `memois`.
- [ ] Confirm the admissibility test in the same section: no correct US word contains the substring
      (`synchronize`, `synchronization`, `synchronous`, `synchrony` all fail it), so no `ALLOWED`
      entry is added.
- [ ] Note in the section's changelog that the published count moves **91 → 92**; the `ALLOWED`
      count stays at **30**.
- [ ] Bump `STANDARDS.md`'s version and date.

**Acceptance:** `grep -c '"' `'s count of the `BRITISH` block is 92, and `localization-§5`'s prose
count agrees.

**Blast radius, stated up front:** every consumer's `tests/test_prose.lua` takes the new entry at its
next `/wow-addon:revendor-standards` sync, and any sibling repo carrying `synchronis` in authored
prose reddens then. That is the rule working, but it should be a known consequence rather than a
surprise. This repo has exactly one occurrence.

---

## Sprint 1 — the two MUSTs the gate can hold (one commit each)

### 1.1 — `CM-79` + `CM-80`: narrow the prose gate and fix what it finds

**One commit.** Splitting it leaves the suite red between the two halves.

- [ ] `tests/test_prose.lua:101-109` — remove `"docs/automated-tests/"` and `"docs/perf-analysis/"`
      from `SKIPPED_DIRS`; add the `isFrozenBundle(path)` stamp predicate from
      `04_TECHNICAL_DESIGN.md` and wire it into the same rejection branch.
- [ ] Update the comment at `:87-100` so the code and the comment agree — the carve-out is the
      **dated bundle**, not the store.
- [ ] `docs/perf-analysis/README.md:25` — `analysed` → `analyzed`.
- [ ] `docs/perf-analysis/README.md:26` — `neighbours` → `neighbors`.
- [ ] `lua tests/run.lua` green; `luacheck .` 0/0.

**Acceptance:** the gate now scans `docs/automated-tests/README.md`,
`docs/automated-tests/RESULTS.md` and `docs/perf-analysis/README.md`, and still skips every
`docs/automated-tests/<stamp>/` and `docs/perf-analysis/<stamp>/` path — verified by reverting the
two word fixes locally and confirming the suite goes **red** on exactly two lines, then restoring
them.

### 1.2 — `CM-81` (part 2): sync the lists, fix the word

**Depends on Sprint 0.**

- [ ] Re-sync `tests/test_prose.lua`'s `BRITISH` and `ALLOWED` blocks **whole** from the amended
      `localization-§5`.
- [ ] `tests/test_prose.lua:81` — `PUBLISHED_BRITISH` `91` → `92`.
- [ ] `docs/settings-panel.md:77` — `synchronisation` → `synchronization`.
- [ ] `lua tests/run.lua` green.

**Acceptance:** the list-count tripwire at `tests/test_prose.lua:237` passes at 92 / 30, and a local
revert of the `docs/settings-panel.md` fix turns the suite red — which is the proof the new entry is
live rather than merely typed.

---

## Sprint 2 — the record (one commit)

### 2.1 — `CM-82`: correct the over-cap census

- [ ] Re-run the command `docs/ARCHITECTURE.md:41` publishes and take the figures from its output.
- [ ] `docs/ARCHITECTURE.md:48` — `1528` → `1669`.
- [ ] `docs/ARCHITECTURE.md:53` — *"`settings/Panel.lua` at 1089"* → `1165`.
- [ ] `docs/ARCHITECTURE.md:73` — *"`settings/Panel.lua` (1089)"* → `1165`.
- [ ] Leave `tests/test_macrobar.lua` (1904) and `settings/Category.lua` (1127) alone — both are
      already correct.
- [ ] *(SHOULD, same commit if taken)* Replace the census's `Lines` column with a pointer to
      `docs/automated-tests/RESULTS.md`'s generated band table plus the command, so the four numbers
      stop existing in two places.

**Acceptance:** every figure in the section matches the published command's output on the day the
section's own stamp names, and no figure in the section is contradicted by
`docs/automated-tests/RESULTS.md:80-83`.

### 2.2 — `CM-77`: record the two bundles without an analysis

- [ ] Add the `automated-tests-§5` row from `04_TECHNICAL_DESIGN.md` to `docs/ARCHITECTURE.md`
      § *Documented deviations*, with **Decided** `2026-09-08` and the re-check trigger *a release
      bundle shipping without an `ANALYSIS.md`*.
- [ ] Do **not** write an `ANALYSIS.md` into `20260807-110619/` or `20260825-103407/`.
- [ ] `lua tests/run.lua` green — `tests/test_register.lua` validates the row shape.

**Acceptance:** the register carries four rows; a `grep` for `automated-tests-§5` in
`docs/ARCHITECTURE.md` resolves; and the next audit records this as **accepted** rather than
re-filing it.

---

## Sprint 3 — the two SHOULDs (one commit)

### 3.1 — `CM-75`: expand the continuation citations

- [ ] Expand all 24 anchored `§N` to `filename-§N` across the 12 files listed in
      `03_EVIDENCE.md` § CM-75.
- [ ] Do **not** touch `docs/smoke-tests.md`, `settings/OptionsSetup.lua:114` or
      `modules/Selector.lua:5` — all three cite a repo document's own numbering, not the standard's.
- [ ] Take this **before** either `layout-§1` peel (issues #32, #33), so the same comment edits do
      not have to be reapplied to split files.

**Acceptance:** the sweep in `03_EVIDENCE.md` § CM-75, re-run with the same scope, returns the two
out-of-scope hits (`settings/OptionsSetup.lua:114`, `modules/Selector.lua:5`) and nothing else — 24
down to 2 — and `grep -nE '§[0-9]+\.[0-9]+'` over the same set still returns nothing.

### 3.2 — `CM-83`: mark the conventional TOC groups

- [ ] Insert the `# Modules` conventional comment above `ConsumableMaster.toc:134`.
- [ ] Insert the `# Locales` conventional comment above `ConsumableMaster.toc:39`.
- [ ] Extend `ConsumableMaster.toc:70` to name `core\SlashDump.lua` beside `core\SlashCommands.lua`.
- [ ] **Move no file line.** Anti-pattern #66 is about a line moving past its comment; this change
      adds comments and moves nothing.
- [ ] `lua tests/run.lua` green — `tests/test_load.lua` reads the TOC's file list.

**Acceptance:** every `#` group in `ConsumableMaster.toc` carries either a load-bearing annotation or
a conventional marker, and `tests/test_load.lua`'s load-list assertions are unchanged.

---

## Not scheduled, and why

| Item | Why not |
|---|---|
| Peel `tests/test_macrobar.lua` (1904) / `tests/test_settingsui.lua` (1669) | Both hold `layout-§1`'s **second** terminal state — an open issue naming the seam (#32, #33). The section allows it; the census records it; `tests/test_layout_cap.lua` holds membership. Not a deviation, so not a remediation step. |
| Backfill the two missing `ANALYSIS.md` files | Fabricates a record. `CM-77`'s cure is the register row, not the file. |
| Touch the three ratified register rows | All three cite rules v2.39.0 has not changed, no trigger has fired, and every evidence id resolves. |
| Add or remove `docs/ARCHITECTURE.md`'s self-row in its own map | v2.39.0 makes it a **MAY** and forbids an audit filing its presence *or* its absence. |
| Edit `.gitattributes`, `.pkgmeta`, `.luacheckrc` | All three are already on the v2.39.0 shape; the working tree agrees with the pin at **0** strays; lint covers 102 files with only `tests/_kit/` excluded under `tests/`. |
| Re-vendor LibKa0s | Both `diff -r` runs against the tag `CLAUDE.md:58` names are empty. Moving to a newer tag is a scheduling question, not a compliance one. |

---

## Ordering summary

```
Sprint 0  (upstream)  0.1  CM-81 part 1 — publish `synchronis`
                            │
Sprint 1  1.1  CM-79 + CM-80 — narrow the gate, fix the two words   (independent)
          1.2  CM-81 part 2 — sync the lists, fix the word          (needs 0.1)
Sprint 2  2.1  CM-82 — correct the census                           (independent)
          2.2  CM-77 — register row                                 (independent)
Sprint 3  3.1  CM-75 — expand the citations   (before issues #32/#33 peel)
          3.2  CM-83 — TOC conventional markers
```

Only one dependency is real: 1.2 cannot land before 0.1, because a local list entry is forbidden by
the very section being satisfied. Everything else can be taken in any order; the grouping above is
by file rather than by need.
