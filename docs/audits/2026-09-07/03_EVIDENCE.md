# 03 — Evidence

Every `file:line` below was re-read and quoted at the time this file was written. Every count is
produced by a recorded command with its scope stated. Nothing here is carried over from a prior
bundle.

---

## Mechanical checks

### Lint — `luacheck .`

```
$ cd /mnt/d/.../ConsumableMaster && luacheck .
…
Total: 0 warnings / 0 errors in 59 files
```

### Headless suite — `lua tests/run.lua`

```
$ lua tests/run.lua
…
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release
…
749 passed, 0 failed, 0 skipped, 749 total
```

The two `test_vendor_sync.lua` cases (`testing-§11`) **ran and passed**, so the consumer-side
vendored-payload gate is green rather than skipped.

### Vendored Ka0s-owned library drift — `library-stack-§7`

Sibling repo found at `../LibKa0s`. The tag to diff against is read from the addon's own provenance
line, not from the sibling's `HEAD`:

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT).

$ grep -n 'Bundles \[LibKa0s\]' README.md
(no output)
```

The sibling was exported at that tag and both payloads compared whole-folder:

```
$ git -C ../LibKa0s archive v1.25.0 LibKa0s testkit | tar -x -C $T
$ diff -r $T/LibKa0s   ConsumableMaster/libs/LibKa0s      ; echo rc=$?
rc=0
$ diff -r $T/testkit   ConsumableMaster/tests/_kit        ; echo rc=$?
rc=0
```

Both **empty**. Not anti-pattern #45 (drift), not #48 (partial vendoring). `v1.25.0` is also the
sibling's newest tag, so the addon is on the current release as well as correctly pinned.

The harness lives under `tests/_kit/`, never `libs/`, and its recorded mode is correct:

```
$ git ls-files -s tests/_kit/run-automated-tests.sh
100755 c35d423… 0  tests/_kit/run-automated-tests.sh
```

### README / `CLAUDE.md` one-line greps — `documentation-§1`/`§2`

```
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
(no output)

$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

`README.md:6` is the **bare** image form, not `[![Standard](…)](…)`. No bundled-library inventory,
under a heading or in the intro prose (`README.md:11` is a plain description paragraph). No
angle-bracket placeholders survive a sweep that excludes real HTML:

```
$ grep -nE '<[a-z][a-z0-9_ -]*>' README.md | grep -viE '<code>|</code>|<strong>|</strong>|<br>'
(no output)
```

### Line endings — `line-endings`

(a) `.gitattributes` present at the repo root.
(b) and (c):

```
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
20
```

The repo ships a `.toc`, so it is client-bound and the CRLF pin is the right one. (d) 20 binary
markings. The body is a **diff, not a reading** — compared against `line-endings-§5`'s canonical
client-bound block:

```
$ diff <(sed -n '148,229p' standards/standards/line-endings.md) <(tr -d '\r' < .gitattributes)
82d81
< ```
```

The only difference is the closing fence of the standard's code block. The body is
**byte-identical**.

(e) The working-tree check, run verbatim as `line-endings-§7` / `AUDIT.md` write it:

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
7
```

**Scope:** every tracked file in the repo, `binary`-marked files skipped by the `text=unset` test as
the rule requires. Frozen bundles under `docs/audits/` and `docs/reviews/` are tracked and **are**
included — they are files git checks out like any other. Evidence for **CM-70**. The number is
reported rolled up and the files are deliberately not listed: the fix is one
`git add --renormalize .`.

### Packaging — `packaging`

```
$ for e in .[!.]*; do [ -e "$e" ] || continue; grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git

$ for e in .luacheckrc .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — _dev
```

`.git` is the one entry the packager never sees. `_dev` is evidence for **CM-76**; the directory
does not exist in the repo, so nothing ships today.

### Complexity — `performance-§10`, `automated-tests`

Run verbatim from the repo root, the invocation the standard and `docs/testing.md:151` both name:

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
…
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     17632       8.0     2.7       63.4     1888            0      0.00    0.00
```

The newest committed bundle is `docs/automated-tests/20260825-103407/`. Its `complexity.txt` footer:

```
     15870       8.0     2.7       63.6     1703            0      0.00    0.00
```

**Drift:** +1762 NLOC, +185 functions, warning count unchanged at **0**, max CCN unchanged. No
function crossed a `lizard` threshold. The bundle's stamp is 2026-08-25 and the tree has moved since
(HEAD `ce572a3`, 2026-09-03, the settings-revamp merge), so the record is **11 days and one merge
stale**. `lizard 1.23.0` is installed; the check ran.

Files against `layout-§1`'s bands **today**:

```
$ find . -name '*.lua' -not -path './libs/*' -not -path './tests/_kit/*' -not -path './.git/*' -print0 \
    | xargs -0 wc -l | awk '$1>=1000 && $2!="total"'
   1127 ./settings/Category.lua
   1014 ./settings/Panel.lua
   1894 ./tests/test_macrobar.lua
   1394 ./tests/test_settingsui.lua
```

**Scope:** all non-vendored Lua, `libs/` and `tests/_kit/` excluded to match the `lizard`
invocation. Evidence for **CM-72** and **CM-73**.

### The watch list as a decision record — `automated-tests-§4`, anti-pattern #53

`docs/automated-tests/RESULTS.md:109`:

> `Current state as of [`20260807-114612`](20260807-114612/) — not that run's diff.`

`:155`:

> `| > 1500 (over cap) | `tests/test_macrobar.lua` | 1688 | **Owed a fix or a tracked deviation ID with an owner — still unowned.** …`

`:156`:

> `| 1000–1500 (on notice) | — | — | None. |`

Both rows are wrong against the current tree (1894, and three files in the on-notice band). Under
*Functions `lizard` warned on*, `:124` reads **None**, which today's run confirms. **Zero** entries
carry the disposition *Accepted*, so anti-pattern #53's three-consecutive-release clock has nothing
to run on; `RESULTS.md:165-167` says so itself and correctly notes that no run in the table is a
release run (`"release": null` in every manifest).

```
$ git log --oneline -- docs/automated-tests/RESULTS.md | head -3
731b1a3 perf(tests): memoise resolve() — the gate drops 25.59s to 3.85s
13c7402 docs(perf): move the in-game capture store to docs/perf-analysis/ bundles
4400bc5 automated-tests: record run 20260807-114612 — green
```

### The record artifact itself — `automated-tests-§1`/§2/§4/§5

`docs/automated-tests/README.md` and `RESULTS.md` both present. No retired `docs/complexity.md`
(`ls docs/complexity.md` → no such file). No `docs/perf-runs/` directory. Bundles missing
`ANALYSIS.md`:

```
$ for d in docs/automated-tests/2026*/; do [ -f "$d/ANALYSIS.md" ] || echo "$d"; done
docs/automated-tests/20260807-110619/
docs/automated-tests/20260825-103407/
```

Evidence for **CM-77**.

`RESULTS.md:9-11`, the generated lead-in, quoted in full:

> `**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —`
> `they are read and compared, not thresholded. A `skip` is a suite that did not run at all,`
> `which is never the same as a pass.`

No mention of the tag checkpoint. The vendored kit's compliant text is at
`tests/_kit/run-automated-tests.sh:425` and `:428`:

> `            printf '**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).\n'`
> `            printf '**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**\n'`

and it sits inside the `else` branch that only runs when `RESULTS.md` does not yet exist
(`:412`). Evidence for **CM-74**.

`RESULTS.md:15`, the newest row:

> `| [`20260825-103407`](20260825-103407/) | 1.5.0 | 0/0 | 58 | 698/698 | pass | 15870 | 1703 | 8.0 | 2.7 | 15 | 0 | **green** |`

`698/698` is passed/total with no skipped figure. The runner writes it that way at
`tests/_kit/run-automated-tests.sh:388` (`$(cell tests "$TESTS_PASS/$TESTS_TOTAL")`) and the manifest
at `:369` carries `passed`, `failed`, `total` and no `skipped`. Evidence for **CM-78**; the fix is
upstream in the kit, not here.

### Retired and malformed standards citations — `documentation-§5`/`§6`

Retired dotted global notation:

```
$ grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=libs --exclude-dir=_kit \
    --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests \
    --exclude-dir=.git --exclude-dir=.superpowers | wc -l
0
```

**Scope:** the whole repo including the live `docs/` pages and `tests/`; frozen bundles
(`docs/audits/`, `docs/reviews/`, `docs/automated-tests/`) excluded as `documentation-§6` requires,
and `libs/` + `tests/_kit/` excluded as vendored. **Zero hits.**

Bare `§N` references that do not parse as `filename-§N`:

```
$ grep -rEno '[A-Za-z0-9_-]*§[0-9]+' --include='*.md' --include='*.lua' --include='*.toc' . \
    --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews \
    --exclude-dir=automated-tests --exclude-dir=.git --exclude-dir=.superpowers \
  | grep -vE ':(anti-patterns|architecture|…|versioning-git)-§' | grep -v 'smoke-tests.md' \
  | awk -F: '{print $1}' | sort | uniq -c
      2 core/ConsumableMaster.lua
      3 docs/ARCHITECTURE.md
      1 docs/debug.md
      6 docs/module-map.md
      1 docs/revendor/2026-09-03/02_CANDIDATES.md
      4 docs/settings-panel.md
     30 docs/superpowers/plans/2026-07-15-debug-logging-conformance.md
     37 docs/superpowers/specs/2026-07-15-debug-logging-conformance-design.md
      1 modules/MacroManager.lua
      1 modules/Selector.lua
      2 settings/Category.lua
      1 settings/General.lua
      2 settings/Panel.lua
      1 settings/Slash.lua
      3 settings/StatPriority.lua
      1 tests/test_debug.lua
      2 tests/test_macrobar.lua
      1 tests/test_pipeline.lua
      2 tests/test_schema.lua
      1 tests/test_settingsui.lua
```

**Scope note, and the reason the finding is scoped narrower than the count.** `docs/smoke-tests.md`
is excluded because its `§2`/`§3c` are that document's **own** section numbers, not standards
citations. `docs/superpowers/` (67 of the hits) is frozen planning material from 2026-07-15 and
`docs/revendor/` likewise. Two more resolve to a bundle, not the standard —
`modules/Selector.lua:5` reads `-- Backing data model (see TECHNICAL_DESIGN §4):`.

What **CM-75** names is the live authored set. Each re-read and quoted:

- `settings/Category.lua:156` — `-- debug off — the standard §12 zero-alloc rule these paths are written to.`
- `settings/Category.lua:669` — `-- MultiMeters' Columns tab (options-ui-§8, §18: one row, learned once).`
- `settings/General.lua:20` — `-- settings rows with acts and §7 wants each kind named. Nothing here is a`
- `settings/Panel.lua:690` — `    -- Scalar write → in-place widget re-sync, never a page rebuild (§11).`
- `settings/Panel.lua:724` — `--- and §17 pin. What they cannot know is this addon's own row vocabulary:`
- `settings/Slash.lua:112` — `                -- console transition line, and the options-panel refresh (§5).`
- `settings/StatPriority.lua:6` — `--   inside the scroll until the redesign; §14 wants the thing a page is editing`
- `settings/StatPriority.lua:10` — `--   Enchant) read it on each render, and §14's rule that the banner REPLACES a`
- `settings/StatPriority.lua:33` — `-- list in the collection is meant to read the same (options-ui-§8, §18): the`
- `modules/MacroManager.lua:331` — `-- below) allocate even with debug off — the standard §12 zero-alloc rule these`
- `core/ConsumableMaster.lua:58` — `    -- lifecycle summary rides the DebugLog.SetEnabled seam instead, as the [Init]` … `(debug-logging-§5/§8).`
- `core/ConsumableMaster.lua:324` — `-- Pure recompute-summary formatter (debug-logging-§8/§9, unit-tested).`
- `docs/ARCHITECTURE.md:191`, `docs/module-map.md:623-626`, `docs/settings-panel.md:74, 163, 251, 407`,
  `docs/debug.md:36` — continuation shorthand of the same shape.

The `§18` / `§8` and `§5/§8` forms are continuations of an anchored citation in the same clause and
are the mildest instance; the `the standard §12` and `§7 wants` forms have no anchor at all. The
`§12` pair is also **out of range**: the zero-allocation rule they describe is `debug-logging-§4`
(*"it is zero-allocation when off: the gate is the first thing it does, before any `string.format`,
concat, or table build"*), restated at `debug-logging-§9`. No section §12 of any file states it.

### US English — `localization-§5`, anti-pattern #46

```
$ P='\b(colour|colours|coloured|colouring|behaviour|behaviours|initialis|organis|centre|grey|greyed|greying|analysed|analyse|analysing|licence|favourite|cancelled|normalis|serialis)'
$ grep -rniE "$P" --include='*.lua' --include='*.md' --include='*.toc' . \
    --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews \
    --exclude-dir=automated-tests --exclude-dir=.git --exclude-dir=.superpowers \
    --exclude-dir=superpowers --exclude-dir=revendor -c | grep -v ':0$'
CLAUDE.md:1
README.md:2
docs/schema.md:1
docs/settings-panel.md:6
docs/test-cases.md:1
docs/smoke-tests.md:6
docs/module-map.md:3
docs/perf-analysis/README.md:1
settings/Category.lua:1
settings/StatPriority.lua:1
tests/test_itemsetup.lua:1
tests/test_mediasetup.lua:1
tests/test_settingsui.lua:3

$ … | wc -l
28
```

**Scope:** live `.lua`, `.md` and `.toc` across the repo. Excluded: `libs/` and `tests/_kit/`
(vendored), the frozen `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`
and `docs/revendor/` directories, and `.superpowers/`. **28 sites in 13 files.** Sites re-read and
quoted:

- `README.md:138` — `… the stat drops to the greyed block at the bottom …` (player-facing)
- `README.md:165` — `Every colour here has a **Use class color** checkbox beside it: … takes your class's colour instead of the swatch.` (player-facing, and inconsistent with the label it describes)
- `CLAUDE.md:69` — `… the schema composers behind the Master controls tab and the font / border / colour blocks …`
- `tests/test_mediasetup.lua:138` — `test("MediaSetup: the vendored payload carries the face and its licence", function(t)`
- `docs/test-cases.md:455` — `- MediaSetup: the vendored payload carries the face and its licence` (the generated echo of the line above)
- `settings/StatPriority.lua:430` — `    -- Greyed rather than hidden: a name you cannot read is a row you cannot aim`
- `settings/Category.lua:720` — `-- draw. The one before it was cancelled at the top of the dispatch, before`
- `tests/test_settingsui.lua:415` — `-- behaviourally identical code and redden the suite; and the rawget half`
- `tests/test_itemsetup.lua:16` — `"the itemID out of a coloured, fully-qualified link")`

Evidence for **CM-69**.

---

## Documentation shape — `documentation-§3`

### Tier 1 — all six present

`ls docs/{scope,module-map,schema,settings-panel,data-flow,common-tasks}.md` → all six resolve.

### Tier 2 — triggers evaluated against the code

| Doc | Present? | Trigger evaluated against the code | Verdict |
|---|---|---|---|
| `perf-analysis/README.md` | yes | harness wired — `core/PerfSetup.lua:71` `local P = lib:New({` | correct |
| `slash-dispatch.md` | **no** | `settings/Slash.lua:84` `local COMMANDS = {` — **17** triples; sub-verb tables at `core/SlashCommands.lua:418` `local PRIORITY_COMMANDS = {`, `:558` `local STAT_COMMANDS = {`, `:729` `local AIO_COMMANDS = {`, `:782` `local BAR_COMMANDS = {`, dispatched at `:459` `local entry = findCommand(PRIORITY_COMMANDS, sub)` | **both halves of the trigger fired** → **CM-68** |
| `midnight-quirks.md` | yes | client workarounds of the addon's own | correct |
| `compat-layer.md` | no | `core/Compat.lua` normalizes spell/item APIs with nothing addon-specific | *Not applicable* row correct |
| `message-bus.md` | no | four messages, threshold is >10 | *Not applicable* row correct |
| `profiles.md` | no | no profile control ships in the options UI | *Not applicable* row correct |
| `debug.md` | yes | `/cm dump` targets in `core/SlashDump.lua` beyond the library console | correct |

The false row, re-read at `docs/ARCHITECTURE.md:279`:

> `| `slash-dispatch.md` | Not applicable | 17 verbs, but they are a flat set with no subcommand tree; the table lives in `ARCHITECTURE.md` → `## Slash Commands` |`

### `## Documentation map` — both directions

Present at `docs/ARCHITECTURE.md:258`, three tier tables plus a *Verification and record* table.
Every `.md` under `docs/` outside the six frozen directories has exactly one row, and every row
resolves to a file that exists. The frozen directories are named once each at `:260`:
`docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/perf-analysis/`,
`docs/revendor/`. No orphans, no dangling rows.

### Non-canonical filenames and retired docs

`docs/macro-bar.md` and `docs/macro-manager.md` are genuine **Tier 3** subjects (one addon's macro
bar, one addon's macro ownership protocol), correctly registered as such at `:302-303`, and neither
holds Tier 1/2 content. No `data-model.md`, `saved-variables.md`, `pipeline.md`,
`settings-system.md`, `wow-quirks.md`, `slash-commands.md` or `debug-console.md`. No retired
`file-index.md`, `conventions.md` or `complexity.md`. No `docs/agent-context.md`, no `TODO.md`, no
root or `docs/` `CHANGELOG.md`, no `docs/pending/LEDGER.md`.

### Hub shape

318 lines total. Per-section line counts, mandated sections only: Overview 5, Module Map 43,
Settings Schema 15, Message Bus 12, Slash Commands 7, Event Subscriptions 17, Taint Notes 8, Known
Limitations 10, Documentation map 46, Documented deviations 13. Nothing past ~60; nothing past ~400.
Compliant, and the arithmetic is not argued.

---

## The deviation register — read first, per `AUDIT.md` step 4

`docs/ARCHITECTURE.md:305` `## Documented deviations`, four rows, all shaped
`| Rule | What differs | Why | Decided | Re-check trigger |`:

| Row | Cited rule | Decided | Status this run |
|---|---|---|---|
| `:315` | `localization-§4` | 2026-08-05 | **Accepted.** Trigger — a structured-data API for tooltip magnitudes, or a committed non-enUS client — has not fired. Not re-filed. |
| `:316` | `toc-file-§5` | 2026-08-05 | **Stale.** `toc-file-§5` now states the within-section sequence is illustrative and that a TOC comment makes it compliant *with no register row*. → **CM-71** |
| `:317` | `compat` | 2026-08-05 | **Accepted.** `GetItemInfo`/`GetItemCount` are still live Retail globals; the trigger has not fired. |
| `:318` | `preview-mode` | 2026-08-05 | **Accepted.** The bar still draws a real button per enabled slot (`core/MacroDisplay.lua:26` `MD.FALLBACK_ICON`) and `/cm` still has no preview verb; the trigger has not fired. |

### The issue store — the inverse check

```
$ gh issue list --state all --limit 200 --json number,title,state,labels,url
```

31 issues. 11 open, all `state:triaged`; 20 closed, `state:done` or `state:will-not-do`. Every issue
carries a `severity:` label. **No `[status]` title prefix survives** (anti-pattern #62 clean). The
seven `state:will-not-do` issues were read individually for the missing-register-row case:

| # | Title | Does it decline a **standard rule**? |
|---|---|---|
| 17 | Add a Wago project ID or record its absence as a tracked deviation | No — `toc-file-§1` makes `X-Wago-ID` a **MAY** |
| 18 | Wire the remaining config consumers onto FireConfigChanged | No — internal design choice |
| 19 | Optimize `formatNumber` | No |
| 26 | Hoist the GCD-suppress curve into LibKa0s instead of duplicating KickCD's copy | No — `library-stack-§7` makes promotion a three-bar test and **SHOULD**s the rejection be recorded where the next author looks; the issue is that record |
| 28 | `LibKa0s-Widgets-1.0`: declined | No — `library-stack-§7`: *"Adoption is per module, on the addon's own schedule"* |
| 30 | `LibKa0s-Item-1.0`: declined | No — same (and superseded: `core/ItemSetup.lua` now wires it) |
| 31 | `LibKa0s-Pool-1.0`: declined | No — same |

**No missing register row is owed.** This is reported explicitly rather than left silent.

---

## Shared-subsystem wiring — evidence is the descriptor, not the behavior

Each seam's `LibStub` lookup, re-read:

| Seam | Line | Quoted |
|---|---|---|
| Core | `core/CoreSetup.lua:33` | `local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)` |
| DebugLog | `core/DebugLogSetup.lua:59` | `local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)` |
| Perf | `core/PerfSetup.lua:38` | `local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)` |
| Media | `core/MediaSetup.lua:61` | `local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)` |
| Env | `core/EnvSetup.lua:57` | `local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)` |
| Item | `core/ItemSetup.lua:34` | `local Item = LibStub and LibStub("LibKa0s-Item-1.0", true)` |
| Options | `settings/OptionsSetup.lua:69` | `local optionsLib = LibStub and LibStub("LibKa0s-Options-1.0", true)` |
| Slash | `settings/Slash.lua:257` | `local slashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)` |

The addon owns **no** console window, widget maker, flow engine, dispatcher or test framework of its
own — anti-pattern #47 does not apply, and the absence of those files is evidence of compliance
rather than a missing feature.

**Stub coverage.** `settings/OptionsSetup.lua:179-180` is the documented load-completing exception —
`Helpers.FontGroup = function() return {} end`, `Helpers.BorderGroup = function() return {} end` —
publishing real-enough load-time members because the page files call composers inside schema-row
literals at file load. Flagging that as inconsistent would be a false positive and it is not filed.
`tests/test_surface_parity.lua` (5 cases in today's run) pins each stub's member set against the
live seam mechanically, which is stronger than a grep and is why no stub-drift finding (anti-pattern
#56) is raised.

**Close button** — the grep is the check:

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/CoreSetup.lua:152:-- library's signature is `lib.MakeCloseButton(parent, onClick, addonName)`, and
core/CoreSetup.lua:156:    return lib.MakeCloseButton(parent, onClick, addonName)
core/PerfSetup.lua:82:    -- `core.MakeCloseButton(frame, P.HidePanel, d.addonName or d.name)`, so the
```

`:156` sits inside the one wrapper, re-read at `core/CoreSetup.lua:155-157`:

```lua
KCM.MakeCloseButton = function(parent, onClick)
    return lib.MakeCloseButton(parent, onClick, addonName)
end
```

`core/PerfSetup.lua:82` is a **comment**. The Perf panel gets the folder name through the descriptor
instead, at `core/PerfSetup.lua:91`: `    addonName = addonName,`. No direct
`lib.MakeCloseButton(...)`, no `NS.DebugLog.MakeCloseButton(...)`, no `decorate` hook whose body is a
close button. Anti-patterns #64 and #65 clean.

**Shared media** — `find media -type f` returns three logo files and seven screenshots. Nothing in
`media/fonts/`, `media/icons/` or `media/textures/`; the JetBrains Mono face and the 116-icon
catalog reach the addon only through `libs/LibKa0s/media/`. Anti-pattern #63 clean.

---

## Settings panel content — the nine `options-ui` checks

**(a) Every page draws a tab strip.** Four pages register through `KCM.Settings.RegisterTab`
(`settings/General.lua:386`, `settings/MacroBar.lua:782`, `settings/StatPriority.lua:693`,
`settings/Category.lua:1126`). Each calls `H.TabStrip` unconditionally:

- `settings/General.lua:355` `    H.TabStrip(ctx, {` — one tab, `Master controls`
- `settings/MacroBar.lua:754` `        tabs     = strip,` — eight tabs from the row `group` values
- `settings/StatPriority.lua:653` `    H.TabStrip(ctx, {` — one tab, with the comment at `:647-652`
  recording that it is drawn *before* the no-spec early return
- `settings/Category.lua:1069` `        tabs     = tabs,` — 15 tabs from `KCM.Settings.macroOrder`

No untabbed-renderer fallback and no early return that skips the strip. The landing page and the
Profiles sub-page are the two mandated exemptions and neither is a finding.

**(b) `Master controls` is the General page's first tab**, `settings/General.lua:334`:

```lua
    { group = "Master controls", label = L["Master controls"], draw = drawMaster },
```

Its rows are **composed**, not typed, at `settings/General.lua:206`
(`local masterRows, masterTail = H.MasterControls{`) with `enabled`, `visibility`, `scale`, `alpha`,
`locked = "macroBar.locked"` and `debugConsolePath = "state.debugConsole"` — the canonical set in the
library's order. The addon draws a positionable frame (`modules/MacroBar.lua:129` — `    frame:SetMovable(true)`), so the
frame rows apply and are present. `visibility` is the four-value dropdown, sourced from
`PROFILE_DEFAULTS.visibility` at `:217` — it was never a boolean in this addon, so no
`schemaVersion` bump or migration step is owed.

**(c) Every color row has its companion.** Every swatch is emitted by `H.ColorPair` or
`H.BorderGroup`/`H.FontGroup`, which pair it: `settings/MacroBar.lua:230`, `:248`, `:287`, `:307`,
`:427`, `:538`. Each carries `classColor = { source = "player" }` (e.g. `:242`), and the
declaration is checked against the render path — `docs/module-map.md:570` records
`KCM.SwatchColor` resolving with a **nil unit** because every swatch here is chrome the player owns.
`tests/test_schema.lua:726-728` asserts both the row and its companion read `player`.

**(d) No `disabledIf` on a color row.** `grep -rn 'disabledIf' settings/` → no output.

**(e) Ordering is a drag.** `grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/
modules/ core/` → no output. Both ordered lists use the shared widget:
`settings/StatPriority.lua:546` `local list = W and W.ReorderList({`, `settings/Category.lua:726`
`    return trackReorder(ctx, W.ReorderList({`. Both cancel the controller at the top of the render —
`settings/StatPriority.lua:623` `    cancelReorder(ctx)` under the comment at `:622`
(`-- BEFORE ResetScroll and before the first widget is created`), and
`settings/Category.lua:567` `local function cancelReorder(ctx)` holding a **list** of controllers.
Neither passes `handleSize`, so the library owns the gutter and the box
(`settings/StatPriority.lua:116`, `settings/Category.lua:73`).

**(f) No hand-written font, border or bar group.** `grep -rn 'LSM30_' settings/ modules/ core/`
returns only `settings/Panel.lua:447` (a comment) and `core/LSMPatch.lua` (a documented AceGUI
widget-registry patch, addon code by design so a lib refresh cannot revert it). Both border blocks
and the label font block are composed (`settings/MacroBar.lua:248`, `:307`, `:427`), with
`buttonBorderOffset` appended in `extra` **after** the mandated four — the comment at `:304-306`
says so explicitly. Mixed tabs carry `subgroup` headings (`settings/MacroBar.lua:220` onward). No
hand-rolled colored `Label` standing in for `Heading` (anti-pattern #71).

**(g) One chrome block, not boxed twice.** Stat Priority draws its spec picker as the page banner
(`settings/StatPriority.lua:634-646`) and nothing else into the band. Category's per-category acts
sit in the scroll but are per-tab, not page-wide. No `InlineGroup` or backdropped `SimpleGroup`
wraps a band's contents. Anti-pattern #72 clean.

**(h) Wrapped-strip geometry.** The strip is the library's (`LibKa0s-Options-1.0`); the addon has no
page that wraps today. The pitch is read from the unselected state in the vendored payload and the
addon does not override it. Re-auditing the library here is out of scope by `AUDIT.md`'s own rule.

**(i) Secondary strips / third levels.** None. Category's 15 tabs are one primary strip; no nested
strip and no `subgroup` faking one.

---

## Performance wiring — `performance`

`performance-§12` does not apply: the harness is wired. Both bracket sites re-read, and both use the
gated idiom over a **file-scope** upvalue:

- `core/ConsumableMaster.lua:175` — `    local perfT0 = (Perf and Perf.on) and debugprofilestop() or nil`
- `core/ConsumableMaster.lua:191` — `    if perfT0 then Perf.Note("recompute", debugprofilestop() - perfT0) end`
- `modules/MacroBar.lua:361` — `    local t0 = (Perf and Perf.on) and debugprofilestop() or nil`
- `modules/MacroBar.lua:368` — `    if t0 then Perf.Note("cooldown", debugprofilestop() - t0) end`

`tests/perf.lua:186` asserts a bracket is present and gated:
`     .. "a bracket is missing or is not gated on Perf.on"):format(notedBefore))`. Anti-pattern #43
clean.

`ConsumableMasterPerfDB` is declared in the TOC beside `ConsumableMasterDB`, with the reason in the
TOC comment above the line, and the descriptor names it at `core/PerfSetup.lua:104` — `    sv = "ConsumableMasterPerfDB",`. `docs/perf-analysis/20260807-132029/` carries `report.md`, `dump.json`
**and** `ANALYSIS.md` — anti-pattern #61 clean.

---

## `savedvariables` / combat-safety spot checks

`savedvariables-§5` (`or`-defaulting a falsy user choice): the only `or` writes over stored state are
container initializations —

```
$ grep -rnE 'db\.profile\.[A-Za-z_.]+ +or +' --include='*.lua' core/ modules/ settings/
core/SlashCommands.lua:497,533,548 …statPriority = KCM.db.profile.statPriority or {}
core/MacroBarModel.lua:132        …return KCM.db and KCM.db.profile and KCM.db.profile.macroBar or nil
modules/MacroManager.lua:426      …macroState = KCM.db.profile.macroState or {}
settings/StatPriority.lua:228,283 …statPriority = KCM.db.profile.statPriority or {}
```

None defaults a scalar whose stored `false` / `""` / empty set is a user choice. Anti-pattern #54
clean.

`events-frames-taint-§4`: the protected macro APIs are guarded —
`core/MacroDisplay.lua:220` `    if InCombatLockdown and InCombatLockdown() then`, and
`modules/MacroManager.lua:5` records the deferral contract for `CreateMacro`/`EditMacro`.

---

## Checks recorded as run, with their results

| Check | Result |
|---|---|
| `luacheck .` | 0/0 in 59 files |
| `lua tests/run.lua` | 749/749, 0 skipped |
| `lizard` (verbatim invocation) | ran; 0 warnings; drift recorded above |
| `diff -r` LibKa0s ship payload @ v1.25.0 | empty |
| `diff -r` testkit → `tests/_kit` @ v1.25.0 | empty |
| `.gitattributes` body vs `line-endings-§5` | byte-identical |
| working-tree pin agreement | 7 files disagree |
| `.pkgmeta` strong-form dot-entry sweep | only `.git` unaccounted |
| `gh issue list` register read | 31 issues read; no missing register row |
| retired `§N.M` notation sweep | 0 |

No check was skipped. No check was unverifiable: the sibling `../LibKa0s` repo is present on this
machine, `lizard 1.23.0` and `gh` are installed.
