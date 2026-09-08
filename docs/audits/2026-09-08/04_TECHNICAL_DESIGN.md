# 04 — Technical design

**Audit:** 2026-09-08 · **Standard:** v2.39.0 (2026-09-07) · keyed to `02_DEVIATIONS.md`.

Six roots and one dependent, all **Low**, none reachable by a user. Nothing here touches shipped
behavior: the whole remediation is one Lua test file, four Markdown files, two TOC comment lines, and
one amendment to the standard itself. No `.lua` under `core/`, `modules/`, `settings/` or `defaults/`
changes, so no smoke test is invalidated and no migration is owed.

**One constraint dominates the ordering:** `CM-81` is fixed **upstream first**. Editing
`docs/settings-panel.md:77` before `localization-§5`'s `BRITISH` list carries `synchronis` leaves the
collection with a word that is right in this repo and unguarded everywhere, which is the private-list
failure the section was rewritten to end.

---

## CM-79 + CM-80 — narrow the prose gate, then let it find the two words

**Files:** `tests/test_prose.lua`, `docs/perf-analysis/README.md`.
**Sections:** `localization-§5` (MUST), `testing-§12`.

### The shape of the change

`tests/test_prose.lua:101-109` skips two directories that are **partly** frozen. The section's four
categories are *vendored code*, *frozen dated bundles*, `locales/enGB.lua`, and *the document whose
subject is this rule* — and "frozen dated bundle" is a property of the `<stamp>/` subdirectory, not
of the store that holds it. The store's own `README.md` and `RESULTS.md` are authored and rewritten.

Replace the two directory entries with a stamp-shaped predicate, keeping every other entry as it is:

```lua
-- A dated bundle under a store is frozen; the store's own README.md / RESULTS.md are not.
-- localization-§5's "frozen dated bundles" carve-out is a property of the <stamp>/ directory.
local SKIPPED_DIRS = {
    "libs/",
    "tests/_kit/",
    "docs/audits/",
    "docs/reviews/",
    "docs/revendor/",
}

--- True for a path inside a dated bundle of a standing store (documentation-§3, performance-§8).
local function isFrozenBundle(path)
    return path:match("^docs/automated%-tests/%d+%-?%d*/")
        or path:match("^docs/perf%-analysis/%d+%-?%d*/")
end
```

and add `isFrozenBundle(path)` to the same rejection branch `SKIPPED_DIRS` already feeds. The two
`docs/audits/` and `docs/reviews/` entries stay directory-shaped because **every** file under them is
frozen; the two stores do not.

`docs/superpowers/` stays in scope, as the file's own comment already argues, and stays clean.

### Why this shape and not a wider one

An alternative is to enumerate the three files as *inclusions*. It is rejected: an inclusion list
goes stale the moment a fourth authored file lands in a store, and the failure is silent — exactly
what `localization-§5` says an exclusion list must not be able to do. The stamp predicate is closed
over the shape the stores actually have.

### Risk

The gate reddens immediately on `docs/perf-analysis/README.md:25-26`; that is the point, and `CM-80`
is fixed in the same commit (`analysed` → `analyzed`, `neighbours` → `neighbors`). Two words in one
sentence each; the surrounding prose is unaffected. Nothing else in the three newly-scanned files
hits the list — verified by running the sweep with those directories left in before the change.

**Ordering constraint:** land the gate change and the two-word fix **together**, or the suite is red
between them and `versioning-git`'s green-commit gate is breached.

---

## CM-81 — `synchronisation`, and the list that cannot see it

**Files:** `WowAddonStandards/standards/standards/localization.md` (upstream), then
`tests/test_prose.lua` and `docs/settings-panel.md`.
**Section:** `localization-§5` (MUST).

### Two changes, in this order

1. **Upstream.** Add `"synchronis"` to `localization-§5`'s published `BRITISH` block, in the
   `-ise / -isation` group, between `standardis` and `memois`. It passes the section's own
   admissibility test — *"A `BRITISH` entry MUST NOT be a substring of a correct US word unless that
   word is on `ALLOWED`"* — because no US word contains `synchronis` (`synchronize`,
   `synchronization`, `synchronous`, `synchrony` all fail the substring). No `ALLOWED` entry is
   needed. The published count moves from 91 to 92.
2. **Here.** Re-sync `tests/test_prose.lua`'s copy of both lists **whole** (the file's own comment at
   `:15-20` commits to that: *"BOTH LISTS ARE COPIED WHOLE, AND NOTHING IS ADDED … it is amended in
   the standard first and arrives here on the next sync; it does not get added locally."*), bump
   `PUBLISHED_BRITISH` at `:81` from `91` to `92`, and fix
   `docs/settings-panel.md:77` — *"a synchronisation problem"* → *"a synchronization problem"*.

### Why not fix the word alone

Because the next author writes it again and nothing stops them, in this repo or any of the other
ten. The section is explicit: *"A sweep or a review that finds a British form the list misses amends
this section, and the gates take it on their next sync."* A local entry is forbidden outright.

### Risk

The upstream edit ripples to every consumer's `tests/test_prose.lua` at its next
`/wow-addon:revendor-standards` sync, and a sibling repo carrying `synchronis` in its own prose goes
red at that moment. That is the intended blast radius, but it means the upstream change should be
made knowing a collection-wide sweep may follow. This repo has exactly one occurrence.

---

## CM-82 — the census's arithmetic

**File:** `docs/ARCHITECTURE.md` § *Files over the 1500-line cap*.
**Sections:** `documentation-§5` (MUST), anti-pattern #51.

### The minimal change

Four figures, from the command the section already publishes at `:41`:

| Line | Reads | Should read |
|---|---|---|
| `:48` | `` | `tests/test_settingsui.lua` | 1528 | `` | `1669` |
| `:53` | *"`settings/Panel.lua` at 1089"* | `1165` |
| `:73` | *"`settings/Panel.lua` (1089)"* | `1165` |
| `:45` | `| File | Lines (2026-09-08) | Disposition |` | date stays — it is correct once the figures are |

`tests/test_macrobar.lua` (1904) and `settings/Category.lua` (1127) are already right and must not be
touched.

### The change worth making beside it

The census and `docs/automated-tests/RESULTS.md`'s band table now hold the **same four numbers in two
places**, and this finding is what that costs. `RESULTS.md`'s table is **generated** — the runner
writes it, and `automated-tests-§4` makes the `Disposition` cell the only authored one — so it cannot
go stale. The census is hand-written and just did.

Rewrite the census's `Lines` column as a pointer rather than a copy: keep the table's *File* and
*Disposition* columns (the disposition is the thing `layout-§1` actually asks the hub to carry) and
replace the number with a sentence naming `RESULTS.md`'s band table as the measurement of record,
plus the command for a reader who wants to re-run it. `tests/test_layout_cap.lua` already asserts
membership in both directions, so nothing is lost and one of the two copies stops existing.

This is a **SHOULD-strength improvement**, not part of the MUST fix; if it is deferred, the four
figures still have to be corrected.

### Risk

None to code. `tests/test_layout_cap.lua` asserts membership only, so it stays green either way —
which is exactly why the figures drifted and why the pointer form is worth the edit.

---

## CM-75 — expand the continuation citations

**Files:** 12, listed in `03_EVIDENCE.md` § CM-75.
**Section:** `documentation-§6` (SHOULD).

Purely mechanical: expand each anchored `§N` to its full `filename-§N`.

- `options-ui-§8, §18` → `options-ui-§8, options-ui-§18` — `settings/Category.lua:669`,
  `settings/StatPriority.lua:33`, `tests/test_settingsui.lua:1167`.
- `debug-logging-§4/§5` → `debug-logging-§4 / debug-logging-§5` — `tests/test_debug.lua:7`.
- `debug-logging-§5/§8`, `debug-logging-§8/§9` — `core/ConsumableMaster.lua:58`, `:324`,
  `docs/debug.md:36`.
- `options-ui-§15 / §16 / §17` → each spelled out — `tests/test_macrobar.lua:1714`.
- The doc-side continuations in `docs/ARCHITECTURE.md:192, 239`, `docs/module-map.md:620-623`,
  `docs/settings-panel.md:74, 170, 258, 424`.

**Explicitly out of scope**, and the change must not touch them: `docs/smoke-tests.md`'s own `§N`
numbering (its sections, not the standard's), `settings/OptionsSetup.lua:114`'s reference to
*"docs/smoke-tests.md's §11a step 6"*, and `modules/Selector.lua:5`'s `TECHNICAL_DESIGN §4`.

### Risk

`tests/test_macrobar.lua:1714` and `tests/test_settingsui.lua:1167` are comments inside files that
are already over `layout-§1`'s cap. Expanding a citation adds characters, not lines, so neither file
grows — but the diff touches two files whose peel is tracked by issues #32 and #33, so take this
before either peel rather than after, or the same edit lands twice.

---

## CM-77 — record the two missing analyses, do not write them

**File:** `docs/automated-tests/RESULTS.md` **or** `docs/ARCHITECTURE.md` § *Documented deviations*.
**Section:** `automated-tests-§5` (SHOULD).

Backfilling is explicitly ruled out — an August bundle given a September analysis is a fabricated
record. Two options, and the second is stronger:

1. **A note in `RESULTS.md`.** One sentence naming `20260807-110619/` and `20260825-103407/`, that
   both are non-release runs, and that `automated-tests-§5`'s write-up is a SHOULD for those. The
   catch: `RESULTS.md` is **generated**, and `automated-tests-§4` makes the `Disposition` cell of the
   watch list the *only* authored cell in the file. A hand-added paragraph is exactly the boundary
   violation v2.39.0 drew. So this option means fixing the **kit** — teaching
   `tests/_kit/run-automated-tests.sh` to emit a "bundles without an analysis" line — which is a
   LibKa0s change plus a re-vendor across eleven repos for one sentence.
2. **A register row** (recommended). `docs/ARCHITECTURE.md` § *Documented deviations*:

   | Rule | What differs | Why | Decided | Re-check trigger |
   |---|---|---|---|---|
   | `automated-tests-§5` | Two non-release bundles carry no `ANALYSIS.md` | Writing one today into a bundle stamped in August fabricates a record. Both are `"release": null`, so §5's write-up is the SHOULD, not the MUST. Ruled fix-forward in the 2026-09-07 collection remediation (`01_CONSOLIDATED_FINDINGS.md` § `C08`); the next run, `20260908-181304`, carries one. Audit finding `CM-77` | 2026-09-08 | A **release** bundle shipping without an `ANALYSIS.md`, which is a MUST and is not this |

   This is the shape `documentation-§3` asks for: the reasoning may live in a plan or an issue, but
   the register is the single home, and a decision recorded only in a thirteenth repository is the
   inverse case `AUDIT.md` says to file.

### Risk

None. `tests/test_register.lua` already validates the register's row shape, so a malformed row fails
the suite rather than shipping.

---

## CM-83 — mark the conventional groups

**File:** `ConsumableMaster.toc`.
**Section:** `toc-file-§5` (SHOULD).

Two comment lines, plus one clause added to an existing comment. No file line moves — which matters,
because anti-pattern #66 is about moving a TOC line past its comment, and this change does the
opposite.

1. Above `ConsumableMaster.toc:134` (`modules\Ranker.lua`):

   ```
   # Conventional, the whole block: every module here reaches its seams through closures at call
   # time, so these ten lines are free to reorder. The one exception is modules\MacroBar.lua, whose
   # `local Perf = KCM.Perf` upvalue is already pinned by core\PerfSetup.lua's comment above.
   ```

2. Above `ConsumableMaster.toc:39` (`locales\enUS.lua`):

   ```
   # Conventional within the block. KCM.L is read at file scope by core\SlashCommands.lua and every
   # settings page, but the # Locales -> # Core section order (toc-file-§5) is what pins that, not
   # this line's position inside the block.
   ```

3. Extend `ConsumableMaster.toc:70` so CoreSetup's enumeration is complete:

   > *"…and before `core\SlashDump.lua` and `core\SlashCommands.lua`, both of which take the printer
   > as a file-scope upvalue."*

Item 3 is the one that is not strictly required (see `03_EVIDENCE.md` § CM-83 for why it is recorded
rather than filed) and is the cheapest guard against the enumeration going stale.

### Risk

None. Comments only; `tests/test_load.lua`'s TOC load-list assertions read file lines, not comments.

---

## What is deliberately not being done

- **No peel of `tests/test_macrobar.lua` or `tests/test_settingsui.lua`.** Both sit in `layout-§1`'s
  second terminal state with issues #32 and #33 naming their seams. `layout-§1` allows that state,
  and re-filing it would be re-filing a rule the census already answers.
- **No backfilled `ANALYSIS.md`.** See `CM-77`.
- **No change to the three ratified register rows.** All three cite rules the standard has not
  changed, none of their triggers has fired, and every evidence id resolves.
- **No `docs/ARCHITECTURE.md` self-row edit.** v2.39.0 makes the hub's own row a MAY and forbids an
  audit filing its presence *or* its absence.
- **No `.gitattributes`, `.pkgmeta` or `.luacheckrc` edit.** All three are on the v2.39.0 shape and
  the working tree agrees with the pin at 0 strays.
