# 03 — Evidence

**Audit:** 2026-09-08 · **Standard:** v2.39.0 (2026-09-07) · **Commit:** `5b01450` · working tree
clean.

Every `file:line` below was **re-read at the time this file was written** and the cited text is
quoted beside it. Every count below is the output of a **recorded command whose scope is stated**;
no figure is re-typed from an earlier bundle. Figures that appear in more than one artifact of this
run (`02_DEVIATIONS.md`, `05_EXECUTION_PLAN.md`) are the same figures — 24 continuation citations,
2 British spellings in `perf-analysis/README.md`, 4 census figures of which 2 are wrong, 12 files.

---

## 0. Resolving the standard

```
$ curl -fsSL https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md -o STANDARDS.md
$ head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)
```

`AUDIT.md` and all 26 section files linked from `## Sections` were fetched from the same ref with
`curl -fsSL` and read from disk. `standards/standards/tiered-layout.md` **404s** — it appears in the
index only inside the v2.0.0 changelog entry that records its rename to `layout.md`, and is not a
live section.

---

## 1. Mechanical checks

### 1.1 Lint (`lint`, `testing-§4`)

**Scope: the whole repo minus `.luacheckrc`'s four exclusions — `libs/`, `docs/audits/`,
`docs/reviews/`, `tests/_kit/`. The test tree is IN scope.**

```
$ luacheck .
Total: 0 warnings / 0 errors in 102 files
```

The figure means something only against the config, so the config was read first
(`AUDIT.md` step 6):

- `.luacheckrc:14-19` — `exclude_files = {` / `"libs/",` / `"docs/audits/",` / `"docs/reviews/",` /
  `"tests/_kit/",` / `}`. **Only `tests/_kit/` under `tests/`**, which is what v2.39.0's `lint`
  narrowed the template to. No bare `tests/`.
- `.luacheckrc:118-120` — `files["tests/"] = {` / `globals = { "KCM_TEST", "KCM_TEST_ROOT" },` / `}`.
  The harness globals are in the stanza, **not** in top-level `read_globals`, and the reasoning is
  written at `:111-117`: *"a name granted at the top level is granted to core/, modules/ and
  settings/ as much as to a suite"*.
- `.luacheckrc:21` — `-- NO TOP-LEVEL 'ignore', and none is coming back (lint-§1, 'M4-11').` No
  blanket ignore exists; the per-file stanzas at `:137-185` each name one file and one argument.

The 102 files are the denominator that matters: `git ls-files '*.lua' | grep -v '^libs/' | grep -v
'^tests/_kit/' | wc -l` returns **102**, so the `0/0` covers every authored Lua file the repo
tracks.

### 1.2 Headless suite (`testing`)

**Scope: `tests/run.lua`'s pinned suite list — every `tests/test_*.lua`, harness excluded.**

```
$ lua tests/run.lua
…
786 passed, 0 failed, 0 skipped, 786 total
```

Two gates inside that run are load-bearing for this audit and were read in the output:

```
PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
PASS  tests/_kit is the test kit that shipped with that release
PASS  eol: every tracked file carries the terminator .gitattributes declares for it
```

### 1.3 Vendored Ka0s-owned library drift (`library-stack-§7`, anti-patterns #45 / #48)

Source repo found at the sibling path `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`. Diffed
against the **tag the addon says it vendored**, not the sibling's `HEAD`:

- `CLAUDE.md:58` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).`

```
$ git -C ../LibKa0s archive v1.27.0 LibKa0s testkit | tar -x -C /tmp/lk
$ diff -r /tmp/lk/LibKa0s  libs/LibKa0s     # → no output
$ diff -r /tmp/lk/testkit  tests/_kit       # → no output
```

Both empty. Not #45. The ship folder is whole — **14** `.lua` files:

```
$ ls libs/LibKa0s/*.lua | wc -l
14
$ grep -ho 'LibKa0s-[A-Za-z]*-1\.0' libs/LibKa0s/*.lua | sort -u
LibKa0s-Core-1.0  LibKa0s-DebugLog-1.0  LibKa0s-Env-1.0  LibKa0s-Item-1.0  LibKa0s-Media-1.0
LibKa0s-Options-1.0  LibKa0s-Perf-1.0  LibKa0s-Pool-1.0  LibKa0s-Slash-1.0  LibKa0s-Widgets-1.0
```

Ten majors across fourteen files, which is v2.39.0's corrected inventory (`OptionsCompose.lua`
present). Not #48. The TOC names the aggregate once and no module individually —
`ConsumableMaster.toc:36`: `libs\LibKa0s\LibKa0s.xml`.

Provenance placement (`documentation-§2` item 6, anti-patterns #58 / #59):

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
58:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).
$ grep -n 'Bundles \[LibKa0s\]' README.md                                   # → no hits
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   # → no hits
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

`README.md:6` is the **bare** image form. Not the linked form `documentation-§1` #2 forbids.

### 1.4 Line endings (`line-endings`)

**Scope: (a)–(d) read `.gitattributes` itself; (e) sweeps every path `git ls-files` returns, the
whole tracked set, `libs/` and frozen bundles included, skipping only paths git marks `text unset`
(binaries).**

```
$ test -f .gitattributes && echo present
present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
20
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
0
```

The pin is **crlf**, which is the correct kind: the repo ships Lua to the client (it has a `.toc`).
`(e)` returns **0**. The 2026-09-07 bundle reported **7** for the same property; that bundle is
frozen and is not edited — the difference is `M4-10`'s renormalization, not a change of command.

§5 body check, run as the section specifies:

```
$ n=81                                                    # client-bound canonical
$ diff <(head -n 81 .gitattributes) <canonical>           # → no output
$ tail -n +82 .gitattributes | tr -d '\r' | grep -m1 .     # → no output (exit 1)
$ wc -l < .gitattributes
81
```

Body byte-identical, nothing below it, so there is no `line-endings-§5 appendix` and no §5 finding.

§7's gate has an owner in the repo, which is the half that v2.39.0 added:
`tests/_kit/test_eol.lua:14` — *"IT READS THE WHOLE TRACKED SET, and did not until revision 15."*
It reports green and this audit's independent (e) also returns 0, so there is no gate finding.

### 1.5 Packaging (`packaging`)

**Scope: `.pkgmeta`'s `ignore:` list against (a) the named enumeration and (b) every root dot-entry
the repo actually holds.**

```
$ for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
                                                            # → no output
$ for e in .[!.]*; do [ -e "$e" ] || continue
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
```

`.git` is the one entry the packager never sees. Both forms pass. The v2.39.0 self-reference is
present — `.pkgmeta:13`: `  - .pkgmeta` — as is `.pkgmeta:11`: `  - _dev        # the scratch dir
packaging reserves; ignored whether or not it exists today`, which closes `CM-76`.

### 1.6 Complexity (`performance-§10`, `automated-tests-§1/§4`)

**Scope: the standard's verbatim invocation from the repo root, `libs/` and `tests/_kit/` excluded.
No extra flag, no narrowed path, no re-tuned threshold.**

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
…
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     18825       8.1     2.7       63.8     1957            0      0.00    0.00
```

Compared against the newest bundle, `docs/automated-tests/20260908-181304/`, and the watch list:

| | `RESULTS.md:26` (run `20260908-181304`) | Today |
|---|---|---|
| NLOC | 18825 | 18825 |
| Functions | 1957 | 1957 |
| Avg CCN | 2.7 | 2.7 |
| Max CCN | 15 | 15 (`Helpers.BuildAboutContent`) |
| CCN warn | 0 | 0 |

**Zero drift.** The record is not stale (not anti-pattern #51) and it is not hand-edited — the run
stamp `20260908-181304` is today's. `docs/complexity.md` does not exist. `docs/automated-tests/`
holds `README.md` and `RESULTS.md`, and `tests/_kit/run-automated-tests.sh` is vendored and
executable (`git ls-files -s` reports mode `100755`).

The one CCN-15 function is dense **defaulting and guarding**, not tangled control flow:
`RESULTS.md:81` records it as *"this addon's highest-CCN function, `Helpers.BuildAboutContent` at
exactly 15"* on a file whose average CCN is 2.7, which is the shape `performance-§10` describes for
Lua — `lizard` scoring each `and`/`or` short-circuit as a decision.

### 1.7 Watch list as a decision record (anti-pattern #53)

**Scope: the four rows of `docs/automated-tests/RESULTS.md`'s `### Files by layout-§1 band` table
(rows at `:80-83`, header `:78`), plus `git log --follow docs/automated-tests/RESULTS.md` for how long each disposition
has been carried.**

| Row | Disposition reads | Consecutive runs carrying it |
|---|---|---|
| `settings/Category.lua` (1127) | **Accepted** | 1 — *"Newly in the band"* (`:80`) |
| `settings/Panel.lua` (1165) | **Accepted** | 1 — *"Newly in the band"* (`:81`) |
| `tests/test_macrobar.lua` (1904) | **Owned: issue #32** | not an acceptance |
| `tests/test_settingsui.lua` (1669) | **Owned: issue #33** | not an acceptance |

```
$ git log -S'settings/Category.lua` | 1127' --oneline -- docs/automated-tests/RESULTS.md
cdb1ec3 M5-01: the record is regenerated, and the band table stops being empty
```

Both band rows entered the file in **one** commit, `cdb1ec3`, which is this cycle's `M5-01`. The
band table did not exist before it (`git log --follow` shows the preceding touch is `0457b44`,
*"M4-14: the two files over the cap stop being unremarked"*).

Two acceptances, each one run old, against #53's threshold of **three or more**. Not every entry
reads *accepted*, and the list is four rows — readable in one pass. Not a finding.

### 1.8 Complexity refactors since the last audit (`performance-§11`)

The cycle's watch-list-driven work was `M4c-01` (*"the locale lexer answers one question per
function"*). Checked against the four forbidden shapes:

- No `part2` / `doTheRest` / `handleEverythingElse` helper — a grep for those names over `core/`,
  `modules/`, `settings/` returns nothing (not #52).
- No dispatch or defaults table built inside a function on a per-frame path (not #43).
- No `t.k = stored.k or D.k` introduced: a sweep for
  `= <expr> or (D|DEF|DEFAULTS|dbDefaults|PROFILE_DEFAULTS|BAR_DEFAULTS)[.\[]` over `core/`,
  `modules/`, `settings/`, `defaults/` returns **no hits**, and the addon defaults with `== nil` —
  `core/CoreSetup.lua:57` *"if r == nil then r = dr end"*, `core/State.lua:14` *"if KCM.State.debug
  == nil then KCM.State.debug = false end"* (not #54, `savedvariables-§5`).

---

## 2. The deviation register, all three `audit-review-history` MUSTs

`docs/ARCHITECTURE.md:357` — `## Documented deviations`, read **before** anything was filed. Three
ratified rows. Each row's cited rule was checked against v2.39.0, each **re-check trigger** was
evaluated against this tree, and each **evidence id** was resolved.

| Row | Rule changed since? | Trigger fired? | Evidence ids resolve? |
|---|---|---|---|
| `localization-§4` (English tooltip-text parsing in `core/TooltipCache.lua`) | No — §4 still forbids matching localized display strings, and §5's v2.39.0 amendment is about spelling, not matching | **No.** Trigger is *"a client API that exposes those magnitudes as structured data, or the first non-enUS client this addon commits to supporting"*. `locales/` holds `enUS.lua` only; no structured-magnitude API is reached. | `docs/scope.md:21` present; `CM-30` → `docs/audits/2026-07-18/02_DEVIATIONS.md` and `docs/audits/2026-08-04/` |
| `compat` (direct `GetItemInfo` at two sites) | No | **No.** Trigger is Blizzard deprecating `GetItemInfo`/`GetItemCount`. Both cited sites still read exactly as the row says: `core/TooltipCache.lua:459` — `local name, _, _, _, minLevel = GetItemInfo(itemID)`; `modules/Ranker.lua:88` — `local _, _, quality, ilvl, _, _, subType = GetItemInfo(itemID)`. The neighbours the row contrasts them with also resolve: `core/Classifier.lua:165-170` and `core/WeaponSlots.lua:33-37` both branch `C_Item.GetItemInfoInstant` first. | `CM-63` → `docs/audits/2026-08-05/02_DEVIATIONS.md`; `CM-R-10` → `docs/reviews/2026-09-07/01_FINDINGS.md` |
| `preview-mode` (no synthetic placeholder on the macro bar) | No | **No.** Trigger is *"the bar gaining any state in which a slot renders blank … or a preview / test verb being added to `/cm`"*. `core/MacroDisplay.lua:26` still reads `MD.FALLBACK_ICON = 7704166`, so a slot always draws something; `settings/Slash.lua`'s `COMMANDS` carries no preview or test verb. | `CM-67` → `docs/audits/2026-08-05/02_DEVIATIONS.md` |

The retirement note beneath the table (`docs/ARCHITECTURE.md:371`) closes `CM-71` and cites
`CM-49` → `docs/audits/2026-08-04/02_DEVIATIONS.md`, which resolves.

> **One recorded imprecision, not filed.** That note says the TOC comments justifying the
> within-`core/` sequence *"are at `ConsumableMaster.toc:41-47` and `:66-69`"*. `:41-47` is the
> `# Core` header block and is right; `:66-69` covers `core\Bus.lua`, `core\Constants.lua` and the
> first two lines of the `CoreSetup` comment, which actually runs `:68-70`. The note is prose in a
> retirement record rather than a register row, the comments it points at exist, and the
> off-by-two misleads nobody — recorded here so a later run does not rediscover it as new.

### 2.1 The issue store (`audit-review-history`)

```
$ gh issue list --state all --limit 200 --json number,title,state,labels,url
33 issues
```

Every issue carries a `state:` label and a `severity:` label. No `[status]` title prefix survives
(anti-pattern #62 clear). No `docs/pending/` directory and no `LEDGER.md` (#60 clear).

Twelve closed `state:will-not-do` issues were read — #17, #18, #19, #20, #21, #22, #23, #24, #25,
#26, #28, #30, #31. **None declines a standard rule**, so no missing register row is owed:

- #28 / #30 / #31 decline the optional `LibKa0s-Widgets-1.0` / `-Item-1.0` / `-Pool-1.0` majors,
  which `library-stack-§7` makes per-addon and per-schedule.
- #17 declines an `X-Wago-ID`, which `toc-file-§1` makes a **MAY**.
- #20–#25 are **superseded pre-adoption records**. #21's own title reads *"(pre-adoption state,
  later superseded)"* and its body *"This row records the unblocked-but-not-yet-adopted state; it was
  later struck through when the makers were adopted."* The library **is** adopted today —
  `settings/OptionsSetup.lua:96` resolves `LibKa0s-Options-1.0`, `settings/General.lua:206` composes
  the master block with `H.MasterControls`, and `settings/Slash.lua:257` resolves
  `LibKa0s-Slash-1.0`.
- #18, #19, #26, #27 are engineering choices, not rule declines.

Issues **#32** and **#33** (`state:triaged`, `bug`) are `layout-§1`'s two owners — the evidence that
`CM-73` is closed by the section's second terminal state rather than left open.

---

## 3. Evidence for each open deviation

### CM-79 — the prose gate's exclusion list is wider than `localization-§5` allows

`tests/test_prose.lua:87` states the rule the file is written to:

> `-- Named directory by directory and file by file, as localization-§5 requires, so the exclusion list`

and `:90-99` enumerates the four sanctioned categories correctly, including
`-- * frozen dated bundles, which are the record of what a tool said on the day rather than authored`
`-- prose, and are not rewritten.`

The code is wider than that comment. `tests/test_prose.lua:101-109`:

```lua
local SKIPPED_DIRS = {
    "libs/",
    "tests/_kit/",
    "docs/audits/",
    "docs/automated-tests/",
    "docs/perf-analysis/",
    "docs/reviews/",
    "docs/revendor/",
}
```

`docs/automated-tests/` and `docs/perf-analysis/` are **not** wholly frozen. Three authored,
rewritten documents live directly inside them and are skipped:

- `docs/automated-tests/README.md` — authored prose about the record.
- `docs/automated-tests/RESULTS.md` — regenerated in place; `RESULTS.md:3` says so verbatim:
  `<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->`
- `docs/perf-analysis/README.md` — which `documentation-§3` calls *"the one file in the store that is
  rewritten — the bundles are frozen"*.

### CM-80 — two British spellings inside that blind spot

**Command and scope.** `localization-§5`'s published `BRITISH` (91 substrings) and `ALLOWED` (30
whole words) lists, copied whole from the section, run over `git ls-files` filtered to
`*.lua`/`*.md`/`*.toc`/`.luacheckrc`, with **only** the section's four sanctioned exclusions applied
— `libs/`, `tests/_kit/` (vendored); `docs/audits/`, `docs/reviews/`, `docs/revendor/` (frozen dated
bundles); `locales/enGB.lua` (absent here); `tests/test_prose.lua` (the gate's own copy of the
lists). `docs/automated-tests/` and `docs/perf-analysis/` were deliberately **left in**, which is the
difference from the repo's own gate.

```
$ lua sweep.lua -dlibs/ -dtests/_kit/ -ddocs/audits/ -ddocs/reviews/ -ddocs/revendor/ \
      -flocales/enGB.lua -ftests/test_prose.lua
BRITISH=91 ALLOWED=30
docs/automated-tests/20260804-182045/ANALYSIS.md:84: [behaviour] …
docs/automated-tests/20260825-103407/test-cases.md:437: [licence] …
docs/perf-analysis/20260807-132029/ANALYSIS.md:128: [optimis] …
docs/perf-analysis/README.md:25: [analys] the capture *happened*, not when it was written up, so a run analysed a week later still sorts
docs/perf-analysis/README.md:26: [neighbour] against its neighbours.
HITS=5
```

Three of the five sit inside **frozen dated bundles** (`20260804-182045/`, `20260825-103407/`,
`20260807-132029/`) and are correctly out of scope — they are the record and are not rewritten. The
list counts 91 / 30, matching the section's published block exactly.

The two that count:

- `docs/perf-analysis/README.md:25` — *"the capture *happened*, not when it was written up, so a run
  **analysed** a week later still sorts"*. US: `analyzed`.
- `docs/perf-analysis/README.md:26` — *"against its **neighbours**."* US: `neighbors`.

Both `analys` and `neighbour` are on the published `BRITISH` list, so the gate would catch them the
moment `CM-79` is fixed.

### CM-81 — a British form the published list cannot catch

`docs/settings-panel.md:77`:

> *"two controls over one piece of session state is a **synchronisation** problem the design would
> have invented and then owned forever."*

**Command and scope.** Whole-repo `-ise`/`-ised`/`-ising`/`-isation` sweep over the same authored set
as CM-80, `libs/`, `tests/_kit/` and frozen bundles excluded:

```
$ git ls-files | grep -Ev '^(libs/|tests/_kit/|docs/audits/|docs/reviews/|docs/revendor/|…)' \
  | xargs grep -noiE '[a-z]+(isation|isations|ised|ises|ising|ise)\b' | awk -F: '{print $3}' \
  | sort | uniq -c | sort -rn
     45 raises      41 otherwise     30 raise      23 raising    14 Raise
     13 exercised    8 raised         6 exercise    5 noise       5 exercises
      …              1 synchronisation           1 revised      1 revise      …
```

One real hit. `synchronis` is **not** an entry in `localization-§5`'s published `BRITISH` list — the
`-ise/-isation` group there runs `initialis normalis generalis specialis optimis customis serialis
summaris utilis organis authoris prioritis alphabetis categoris sanitis visualis minimis maximis
itemis randomis tokenis capitalis localis modularis standardis memois recognis analys paralys
synthesis emphasis` and stops. The section forbids a repo adding its own entry:
*"A private addition MUST NOT outlive the change that discovered it."* So neither this repo's gate
nor any sibling's can catch it until the list is amended upstream. `synchronis` passes the section's
admissibility test — no correct US word contains it.

### CM-82 — the over-cap census disagrees with the command it publishes

`docs/ARCHITECTURE.md:39` — *"Two files, measured 2026-09-08 with"* — and `:41`:

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

**Scope: exactly that command, run from the repo root today.** Output, top five:

```
   1904 tests/test_macrobar.lua
   1669 tests/test_settingsui.lua
   1165 settings/Panel.lua
   1127 settings/Category.lua
    865 tests/wow_mock.lua
```

Against what the census records:

| File | Census says | Command says | At |
|---|---|---|---|
| `tests/test_macrobar.lua` | 1904 | 1904 | `docs/ARCHITECTURE.md:47` — correct |
| `tests/test_settingsui.lua` | **1528** | **1669** | `docs/ARCHITECTURE.md:48` — *"| `tests/test_settingsui.lua` | 1528 | Issue [#33]…"* |
| `settings/Category.lua` | 1127 | 1127 | `docs/ARCHITECTURE.md:53`, `:72` — correct |
| `settings/Panel.lua` | **1089** | **1165** | `docs/ARCHITECTURE.md:53` — *"The largest are `settings/Category.lua` at 1127 and `settings/Panel.lua` at 1089"*; repeated at `:73` — *"`settings/Panel.lua` (1089) are the only two files in it"* |

The runner-generated record beside it has the right numbers on the same day:
`docs/automated-tests/RESULTS.md:81` — *"| 1000–1500 (on notice) | `settings/Panel.lua` | 1165 |"* —
and `:83` — *"| > 1500 (over cap) | `tests/test_settingsui.lua` | 1669 |"*, whose own prose narrates
the drift: *"656 at the previous run's commit, 1528 by `M4-06`, 1669 after `M4-22`."* So 1528 is a
real number from mid-cycle that was never refreshed.

The suite cannot catch it. `docs/ARCHITECTURE.md:62-65` says why: *"What
`tests/test_layout_cap.lua` asserts is the *membership* of this table, in both directions: a file that
crosses 1500 and is not listed here turns the suite red, and so does a row for a file that has fallen
back under the cap or been deleted. A figure in this column is a measurement, not a claim about
today."* Membership is correct; the figures are
not, and the section header claims today's date.

### CM-75 — bare `§N` continuation citations

**Command and scope.** Every tracked `*.lua` / `*.md` / `*.toc` / `.luacheckrc`, **excluding**
`libs/`, `tests/_kit/`, the frozen `docs/audits/`, `docs/reviews/`, `docs/revendor/`,
`docs/automated-tests/`, `docs/perf-analysis/2026*` bundles and `docs/superpowers/`, and excluding
`docs/smoke-tests.md`, whose `§N` are that document's own section numbers and not the standard's:

```
$ … | xargs grep -noE '[A-Za-z-]*§[0-9]+[a-z]?' | grep -vE ':[a-z][a-z-]+§' | wc -l
24
$ … | cut -d: -f1 | sort | uniq -c
      2 core/ConsumableMaster.lua      3 docs/ARCHITECTURE.md         1 docs/debug.md
      6 docs/module-map.md             4 docs/settings-panel.md       1 modules/Selector.lua
      1 settings/Category.lua          1 settings/OptionsSetup.lua    1 settings/StatPriority.lua
      1 tests/test_debug.lua           2 tests/test_macrobar.lua      1 tests/test_settingsui.lua
```

**24 sites in 12 files.** The retired dotted form is absent:

```
$ … | xargs grep -nE '§[0-9]+\.[0-9]+'      # → no hits
```

Every one of the 24 is an **anchored continuation**, re-read and quoted:

- `settings/Category.lua:669` — *"MultiMeters' Columns tab (options-ui-§8, §18: one row, learned
  once)."*
- `settings/StatPriority.lua:33` — *"list in the collection is meant to read the same (options-ui-§8,
  §18): the"*
- `tests/test_settingsui.lua:1167` — *"The secondary rows are MultiMeters-shaped (options-ui-§8,
  §18): a bounded box"*
- `tests/test_debug.lua:7` — *"(debug-logging-§4/§5)."*
- `tests/test_macrobar.lua:1714` — *"options-ui-§15 / §16 / §17 — the settings that were ADDED, and
  the code that"*
- `core/ConsumableMaster.lua:58` — *"line emitted on debug-enable (debug-logging-§5/§8)."*
- `core/ConsumableMaster.lua:324` — *"Pure recompute-summary formatter (debug-logging-§8/§9,
  unit-tested)."*
- `docs/debug.md:36` — *"…so a pasted log self-identifies (debug-logging-§5/§8)."*
- `docs/settings-panel.md:74` — *"It is the **only** picker for that state, which is `§14`'s rule"*,
  anchored by `:70`'s *"pinned above the scroll, naming what the page is editing
  (`options-ui-§14`)"*.
- `docs/settings-panel.md:423-424` — *"**Tab strips** come from `H.TabStrip(ctx, { tabs, value,
  onSelect })` (`options-ui-§13`) and the page banner from `H.PageBanner(ctx, { label, list, order,
  value, onSelect })` (`§14`)."* — anchor and continuation in one sentence.
- the remaining sites in `docs/ARCHITECTURE.md:192, 239`, `docs/module-map.md:620-623` and
  `docs/settings-panel.md:170, 258` follow the same shape.

Two sites are **out of scope** and are not in the 24: `settings/OptionsSetup.lua:114` cites
*"docs/smoke-tests.md's §11a step 6"* — a repo document's own numbering — and
`modules/Selector.lua:5` cites *"TECHNICAL_DESIGN §4"*, likewise. (These two are inside the 24 the
command returns; deducting them leaves **22** standard citations. The finding is filed at the
command's number, 24, with the two named, so the figure can be reproduced.)

### CM-77 — two bundles with no `ANALYSIS.md`

```
$ for d in docs/automated-tests/2026*/; do [ -f "$d/ANALYSIS.md" ] || echo "MISSING $d"; done
MISSING docs/automated-tests/20260807-110619/
MISSING docs/automated-tests/20260825-103407/
$ grep -o '"release"[^,]*' docs/automated-tests/20260807-110619/manifest.json | head -1
"release": null
$ grep -o '"release"[^,]*' docs/automated-tests/20260825-103407/manifest.json | head -1
"release": null
```

Both non-release, so `automated-tests-§5`'s **SHOULD**, not its MUST. The newest bundle
`20260908-181304/` **does** carry one, which is the fix-forward half done. The note is not written:

```
$ grep -rn 'ANALYSIS' docs/automated-tests/RESULTS.md docs/automated-tests/README.md
docs/automated-tests/RESULTS.md:8:the analysis of a given run is its `ANALYSIS.md`.
docs/automated-tests/README.md:47:  `ANALYSIS.md` (the write-up). Bundles are **never edited** once written and **never pruned**.
```

Neither line names the two bundles or the decision. And the decision itself lives outside this repo —
`Ka0sAddonsCommonTasks/docs/2026-09-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/01_CONSOLIDATED_FINDINGS.md`
§ `C08`: *"These are frozen, dated records. Writing an analysis today into a bundle stamped in August
is fabricating a record. Fix forward: make the next run write one, and note the gap once."*
`documentation-§3` makes `docs/ARCHITECTURE.md`'s register the **single home** of a ratified
decision, and there is no row for this one.

### CM-83 — conventional groups unmarked in the TOC

**Denominator first**, as `toc-file-§5` requires: the load-bearing positions were established by
reading the seam files, not by counting TOC lines. Every file taking something at **file scope** from
an earlier seam:

| Site (re-read) | Resolves from | Annotated at |
|---|---|---|
| `core/ConsumableMaster.lua:16` — `local Perf = KCM.Perf` | `core/PerfSetup.lua` | `ConsumableMaster.toc:50-56`, naming both consumers |
| `modules/MacroBar.lua:35` — `local Perf = KCM.Perf` | `core/PerfSetup.lua` | same comment |
| `core/DebugLogSetup.lua:145` — `font = fontPath()` | `core/MediaSetup.lua` | `ConsumableMaster.toc:58-63`, marked *"THE POSITION IS LOAD-BEARING"* |
| `core/SlashCommands.lua:26` — `local say = KCM.Say` | `core/CoreSetup.lua` | `ConsumableMaster.toc:68-70` |
| `core/SlashDump.lua:16` — `local say = KCM.Say` | `core/CoreSetup.lua` | **enumerated nowhere** — see below |
| `settings/Panel.lua:83` — `local Helpers = KCM.Settings.Helpers or {}` | `settings/OptionsSetup.lua` | `ConsumableMaster.toc:146-150` |
| `settings/{General,MacroBar,StatPriority,Category}.lua` — `local H = KCM.Settings.Helpers` | `settings/OptionsSetup.lua` | pinned transitively by the annotated `settings\Panel.lua` above them |
| `settings/MacroBar.lua:41` — `local BAR_DEFAULTS = KCM.dbDefaults…` | `defaults/Profile.lua` | pinned by the `# Defaults` → `# Settings` section order, which is the MUST |

**The MUST is met.** Every load-bearing position is annotated or pinned by an annotated line
immediately above it, which is the shape `toc-file-§5`'s worked example calls compliant for
`core\Constants.lua`.

**The SHOULD is not.** `toc-file-§5`: *"A position that is merely **conventional SHOULD** say that
too, once per group."* Two of the six groups say nothing:

- `ConsumableMaster.toc:133-143` — `# Modules` followed by ten bare `modules\*.lua` lines and no
  comment of any kind.
- `ConsumableMaster.toc:38-39` — `# Locales` / `locales\enUS.lua`, likewise.

Per the section's grading this is **one SHOULD row for the file**, never one per line.

> **Recorded, not filed.** `ConsumableMaster.toc:68-70` reads *"CoreSetup builds KCM.Say /
> KCM.SafeToString from LibKa0s-Core-1.0. It has to sit after Constants.lua (KCM.PREFIX) and before
> core\SlashCommands.lua, which takes the printer as a file-scope upvalue."* It names **one** of the
> two files that do — `core/SlashDump.lua:16` reads `local say = KCM.Say` too, and
> `core\SlashDump.lua`'s own comment (`ConsumableMaster.toc:103-106`) names the SlashDump →
> SlashCommands direction rather than this one. That is an enumeration one file short, and
> enumerations go stale. It is **not** filed as a `toc-file-§5` MUST row for two reasons: SlashDump
> sits below the annotated `core\CoreSetup.lua` line, so its position is pinned the way
> `core\Constants.lua` is in the section's worked example; and v2.39.0's own measurement of this rule
> across the collection named the eight unannotated load-bearing positions by file and line
> (`KickCD.toc:55, :73`, `PrettyChat.toc:40, :57`, `WhatGroup.toc:44, :47, :53-56`) and did **not**
> include `ConsumableMaster.toc`. Re-filing it here would contradict a measurement taken against the
> same rule text days ago. The one-clause fix rides along with `CM-83`.

---

## 4. Compliance evidence for the checks that passed

Cited so a later run does not re-derive them.

- **Shared subsystems are consumed, not hand-rolled** (`library-stack-§7`, anti-pattern #47). The
  descriptor-and-stub pairs, each re-read: `core/CoreSetup.lua:185-187` —
  `KCM.MakeCloseButton = function(parent, onClick)` / `return lib.MakeCloseButton(parent, onClick,
  addonName)` / `end`; `core/DebugLogSetup.lua:127` — `name  = addonName,` and `:136` —
  `addonName = addonName,`; `core/MediaSetup.lua:61` — `local Media = LibStub and
  LibStub("LibKa0s-Media-1.0", true)` and `:104` — `if Media then Media.RegisterLSM(addonName) end`;
  `core/PerfSetup.lua:71` — `local P = lib:New({`; `settings/OptionsSetup.lua:96` — `local optionsLib
  = LibStub and LibStub("LibKa0s-Options-1.0", true)`; `settings/Slash.lua:257` — `local slashLib =
  LibStub and LibStub("LibKa0s-Slash-1.0", true)`. There is no `modules/DebugLog.lua`, no
  widget-maker file, no private dispatcher.
- **The Options stub is load-completing, which is correct and not a gap.**
  `settings/OptionsSetup.lua:250-253` — `Helpers.MasterControls = function() return {}, function()
  end end` / `Helpers.ColorPair      = function() return {} end` / `Helpers.FontGroup      =
  function() return {} end` / `Helpers.BorderGroup    = function() return {} end`. That empty row
  list is precisely v2.39.0's **hollow composer**: the compliant answer on a library-less load, not a
  licence to hand-write the block back. `tests/test_surface_parity.lua` pins the stub's member set
  against the call sites and is green.
- **The AceGUI widget registry** (`library-stack-§9`, anti-pattern #76).
  `settings/OptionsSetup.lua:102` — `if optionsLib and AceGUI then` — and `:140` —
  `optionsLib.__PatchLSM30Border()`. `core/LSMPatch.lua` does not exist, and
  `grep -rn 'RegisterWidgetType' --include='*.lua' .` outside `libs/` returns nothing.
- **`MakeCloseButton`** (`standalone-windows`, anti-pattern #65). The mandated grep:
  ```
  $ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
  core/CoreSetup.lua:183:-- library's signature is `lib.MakeCloseButton(parent, onClick, addonName)`, and
  core/CoreSetup.lua:187:    return lib.MakeCloseButton(parent, onClick, addonName)
  core/PerfSetup.lua:82:    -- `core.MakeCloseButton(frame, P.HidePanel, d.addonName or d.name)`, so the
  ```
  One wrapper definition, two comments. No call site bypasses it because the addon builds no window
  of its own — `grep -rn 'UISpecialFrames' core modules settings` returns nothing. `SetMovable`
  appears once, at `modules/MacroBar.lua:129` — `frame:SetMovable(true)` — which is the positionable
  bar, governed by `preview-mode` and covered by a register row.
- **`options-ui` (d), (e), (f)** — three greps, all empty over `settings/`:
  `disabledIf`; `ScrollUp-Up\|ScrollDown-Up`; `LSM30_Font\|LSM30_Border\|LSM30_Statusbar` returns
  only two comment lines at `settings/OptionsSetup.lua:103` and `:106` and no control. The reorder
  lists are the library's — `settings/Category.lua:726` and `:926`, `settings/StatPriority.lua:546`,
  all `W.ReorderList({`.
- **`options-ui` (b)** — `settings/General.lua:206` — `local masterRows, masterTail =
  H.MasterControls{` — the composer, not a typed-out block. `settings/General.lua:333-335` declares
  `local TABS = {` / `{ group = "Master controls", label = L["Master controls"], draw = drawMaster
  },` / `}`, and `:355-363` draws the strip unconditionally for that one tab — `H.TabStrip(ctx, {` with the
  `strip` array built at `:351-354`, no tab-count threshold and no early return above it.
- **`options-ui` (h)** — `libs/LibKa0s/OptionsWidgets.lua:403` — *"IT WAS BROKEN EXACTLY THERE.
  TabStrip recorded the pitch from the FIRST tab it drew, whichever"* — and `:411` — *"So the pitch
  is measured ONCE, from the INACTIVE cap atlas, on a throwaway texture"*. `libs/LibKa0s/Options.lua:120`
  keeps `TAB_H = 37` as the separate quantity. The suite case is at
  `tests/test_settingsui.lua:1303` — *"options-ui-§13 — a wrapped strip's geometry MUST NOT depend on
  the selection"*.
- **Tier 2 triggers, measured against the code.** `message-bus.md` — `core/Bus.lua:37-41` declares
  **four** messages (`RECOMPUTE`, `PANEL_REFRESH`, `SPEC_CHANGED`, `MACROBAR_REFRESH`) against the
  *more than ten* threshold, and `docs/ARCHITECTURE.md:334` records exactly that. `profiles.md` — no
  profile control ships; `options-ui-§3` makes the Profiles sub-page a **MAY**, and
  `docs/ARCHITECTURE.md:336` records it. `compat-layer.md` — the doc is present, so v2.39.0's new
  three-shim count needs no adjudication.
- **`documentation-§3`'s four tables.** `docs/ARCHITECTURE.md:310` — `## Documentation map`; `:315`
  `### Required (documentation-§3, Tier 1)`; `:327` `### Conditional (documentation-§3, Tier 2)`;
  `:339` `### Verification and record`; `:350` `### Addon-specific (documentation-§3, Tier 3)`. The
  third holds exactly the six mandated rows (`testing.md`, `smoke-tests.md`, `test-cases.md`,
  `performance.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md`) and
  `perf-analysis/README.md` correctly registers in `### Conditional` at `:337` instead. Every `.md`
  under `docs/` is covered once; the frozen and generated directories are named once each at `:313`.
- **Combat lockdown** (`events-frames-taint`). `modules/MacroManager.lua:309` — `CreateMacro(macroName,
  icon, body, false)` and `:320` — `local editedIdx = EditMacro(idx, nil, icon, body)`, both behind
  the guards at `:435` and `:549` (`if InCombatLockdown and InCombatLockdown() then`).
  `core/MacroDisplay.lua:220` guards `PickupMacro` the same way.
- **README** (`documentation-§1`). `README.md:3-7` is the five-badge row in the mandated order, the
  standard badge bare at `:6`, `[wow]` reading `Midnight_12.0.7` against `ConsumableMaster.toc:1`'s
  `## Interface: 120007`, and `[tests]` reading `786%2F786` against today's `786 passed … 786 total`
  and `docs/test-cases.md`'s 786 case lines. `## What's new in 1.5.0` at `:37` matches the top
  `## Version History` row at `:298`. No angle-bracket placeholder survives a sweep. No
  `## Libraries`, no `## Testing`, no `CHANGELOG.md` at the root.
