# 01 — Findings

**Review date:** 2026-09-07 · **Addon:** Ka0s Consumable Master v1.5.0 · **HEAD:** `69a4d56`
**Standard resolved:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)**, index + section files fetched
verbatim with `curl` from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`.
Six section files fetched (`anti-patterns`, `testing`, `options-ui`, `architecture`, `library-stack`,
plus the index); `performance.md` and the remaining sections **timed out** on this network and were
**not** re-read today. Where a fix direction below cites a rule I did not re-fetch, it is marked
*(rule not re-verified today)*.

---

## Verdict

**Minor issues.** The addon is green on every suite that can run outside the client, the vendored
payload matches its tag byte-for-byte, and the LibKa0s adoption is unusually careful — descriptors
are complete, degradation stubs are exercised by real degraded loads rather than hand-stubs, and both
declared perf buckets are reached by real gated brackets. One structural defect is worth fixing
before the next release (`CM-R-01`, the migration runner's version key sits at account scope while
the data it migrates sits at profile scope). Everything else is drift: unrouted display strings in two
custom widgets, a parity list that has fallen one member behind the seam it guards, and a set of
`file:line` comment citations that no longer resolve.

---

## Measurement run (Step 0 — all re-run today, 2026-09-07)

| Suite | Command (from repo root) | Result |
|---|---|---|
| **luacheck** | `luacheck .` | **PASS** — `Total: 0 warnings / 0 errors in 59 files` |
| **Headless tests** | `lua5.1 tests/run.lua` | **PASS** — `749 passed, 0 failed, 0 skipped, 749 total` |
| **`--list` inventory** | `lua5.1 tests/run.lua --list > <scratch>/list.md` | **PASS** — 902 lines; `diff` against `docs/test-cases.md` is **empty** |
| **Offline perf** | `lua5.1 tests/perf.lua` | **PASS** — 4 scenarios, exit 0, no assertion failures |
| **Complexity** | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **PASS** — `No thresholds exceeded`; 17632 NLOC, 1888 functions, avg CCN 2.7, **max CCN 15**, 0 warnings |
| **Makefile `test:`** | — | **SKIPPED** — no `Makefile` at the repo root |
| **Vendor sync — LibKa0s** | `diff -r --strip-trailing-cr libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **PASS** — no content difference (see note below) |
| **Vendor sync — testkit** | `diff -r tests/_kit/ ../LibKa0s/testkit/` | **PASS** — byte-identical |

**Scope of each count.** `luacheck` ran from the repo root over the whole tree minus `.luacheckrc`'s
four exclusions (`libs/`, `docs/audits/`, `docs/reviews/`, **`tests/`**) — so the 59 files are
`core/ defaults/ locales/ modules/ settings/` only, and **no suite file, `tests/run.lua` or
`tests/perf.lua` was linted**. The `lizard` run covered the whole tree *including* `tests/` and
excluding only `libs/` and `tests/_kit/`, which is why its NLOC (17632) is much larger than the lint
file count implies. The 749 test cases are every case the runner registered across the 35 suites
declared in `tests/run.lua`'s `SUITES`; the offline perf scenarios are correctly **not** among them.

**Offline perf, today's numbers** (orientation only, single run, this machine):

```
scenario                  iters      ms/iter     total ms   bytes/iter
recompute                   200      0.91893      183.786       7597.6
cooldownRefresh             200      0.01808        3.615       6000.0
probeOverheadOff            200      0.01811        3.622       6000.0
probeOverheadOn             200      0.01864        3.727       6001.3
```

The zero-overhead property holds exactly as `docs/performance.md` claims: the dormant arm allocates
**6000.0 bytes/iter**, byte-for-byte `cooldownRefresh`'s figure, against the 6144 ceiling
`tests/perf.lua` pins. The armed arm adds **1.3 bytes/iter**. `tests/perf.lua` also asserts the
brackets actually fire (`notedBefore == 2`), which is what stops both arms silently measuring a build
where `core/PerfSetup.lua` returned early.

**Vendor-sync note (not a defect in this repo).** `diff -rq` reports `libs/LibKa0s/DebugLog.lua` and
`libs/LibKa0s/Pool.lua` as differing from the sibling checkout; `diff --strip-trailing-cr` reports
nothing. The two files are **LF in `../LibKa0s`'s working tree and CRLF here** — a `line-endings-§2`
straggler in the *library* repo, not a content fork. The repo's own gate
(`tests/test_vendor_sync.lua`, both cases green today) compares against the tag's **blobs** and is
therefore right to pass.

### Committed artifacts that disagree with today's run

| Artifact | Committed says | Today says | Reading |
|---|---|---|---|
| `docs/test-cases.md` | 749 cases | 749 cases | **In sync** — the `--list` diff is empty |
| `README.md` `[Tests]` badge | `749/749 passing` | 749/749 | **In sync** |
| `docs/automated-tests/RESULTS.md` | newest row `20260825-103407`: 698 tests, 58 lint files, NLOC 15870, 1703 funcs | 749 tests, 59 lint files, NLOC 17632, 1888 funcs | **Stale** — see `CM-R-06`. `manifest.json` stamps that run at `2026-08-25T10:34:07+05:30`, SHA `e510ffc`, `"dirty": true` |
| `docs/performance.md` | dormant ceiling 6144 bytes/iter, four named scenarios | ceiling holds at 6000.0 | **In sync** — it quotes no per-run figures that could go stale |
| `docs/perf-analysis/20260807-132029/` | `cooldown` bucket: 352 calls, 42.72 ms total, 0.2397 ms max, over 24.0 s active | not re-measurable headlessly | **Cited as dated.** The `recompute` bucket recorded **nothing** in that capture, which is the designed outcome — recompute is an out-of-combat path and the capture window is combat-only |

In-client checks are deliberately absent from this block; they are in `03_SMOKE_TESTS.md`.

---

## High

### CM-R-01 — Migration version is account-wide; the data it migrates is per-profile `[design]` `[savedvariables]`

**Where:** `core/Database.lua:66-90` (`D.RunMigrations`), with `core/ConsumableMaster.lua:401-412`
(`KCM.RegisterProfileCallbacks`).

**Problem.** `RunMigrations` gates every step on `db.global.schemaVersion` — account-wide by design
and asserted as such — but each step then mutates `db.profile`: `D.MigrateMacroBarV2(db.profile)` at
`core/Database.lua:73` and `D.MigrateLabelFlagsV3(db.profile)` at `core/Database.lua:78`. The first
login after an upgrade migrates whichever profile happens to be active, stamps
`g.schemaVersion = D.CURRENT_SCHEMA` at `core/Database.lua:85`, and every other profile in the
account is then permanently past the gate without ever having been touched.

**Impact.** For v3 specifically: a non-active profile keeps `macroBar.labelOutline` (a boolean) and
never gets `macroBar.labelFlags`, so AceDB's shipped default `"OUTLINE"` (`defaults/Profile.lua:170`)
paints over a stored `labelOutline = false`. The player's "no outline" choice is silently replaced,
and the dead `labelOutline` key survives — both of which the v3 comment
(`core/Database.lua:40-53`) says the migration exists to prevent. The durable half is worse than the
symptom: **every future per-profile migration inherits the same silent skip**, and the
`OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` re-run wired at
`core/ConsumableMaster.lua:403-405` is structurally incapable of doing anything, because by the time
it runs the global version is already current.

**Reachability.** Any player with two or more AceDB profiles who upgrades across the schema v3 bump —
an ordinary configuration, the panel ships a Profiles page — loses the `labelOutline` choice on every
profile that was not active at that login, on the next login, with no notice.

**Coverage.** `docs/test-cases.md` lists 18 `test_database.lua` cases and **none** exercises a second
profile. Worse, `tests/test_database.lua:56-63` ("*Database.RunMigrations never writes into the
profile scope*") pins `db.profile.schemaVersion == nil` as correct — codifying the very scope split
that causes this. See `CM-R-14`.

**Fix direction.** Track the applied version **per profile** (e.g. `db.profile.schemaVersion`) for
steps that mutate profile data, keeping `db.global.schemaVersion` for anything account-wide, and let
the existing `OnProfileChanged` callback do the work it was already wired for. Do **not** "fix" this
by iterating `db.profiles` from the global runner — that reaches into AceDB's raw store behind its
own profile abstraction and would re-break on a profile created later.

---

## Medium

### CM-R-02 — Six user-facing strings in two custom widgets bypass `L[]` `[locale]`

**Where:** `modules/KCMMacroDragIcon.lua:74`, `:77`; `modules/KCMItemRow.lua:171`, `:173`, `:175`,
`:228`.

**Problem.** Every page file routes display text through `KCM.L` (224 distinct keys across
`core/ modules/ settings/ defaults/`, all resolving through `locales/enUS.lua`'s identity metatable —
0 missing, 0 unused). The two custom AceGUI widgets never adopted it: neither file takes an
`L` upvalue, and both write literals straight into a FontString —
`self.label:SetText("|cffffd100Drag to action bar|r")`,
`self.label:SetText("|cff999999Macro not created yet|r")`, `self.label:SetText("[Loading]")`, and the
three hand tags `"MH+OH"` / `"MH"` / `"OH"`.

**Impact.** Zero rendering impact today — the addon is enUS-only and `localization-§3` permits that —
but these six strings are invisible to a locale file that is dropped in later, and they are the only
display text in the addon a translator would have no way to find.

**Reachability.** Every player who opens the Macros page: the drag-icon label heads every category
tab and `[Loading]` is what an unhydrated priority row shows on first open.

**Fix direction.** Take `local L = KCM.L` in both files and wrap the six literals, English string as
the key, exactly as `settings/Category.lua` does. Do not add rows to `locales/enUS.lua` — the
identity metatable already answers them (`locales/enUS.lua:16`).

### CM-R-03 — The stub-parity list has fallen one member behind the seam it guards `[tests]`

**Where:** `tests/test_surface_parity.lua:44-52` (`CORE_SEAM` and the comment naming its derivation).

**Problem.** The case documents its member list as produced by
`grep -n '^KCM\.[A-Za-z0-9_]* =\|^function KCM\.' core/CoreSetup.lua`. Run today, that grep returns
**six** members — `LIBKA0S_MISSING` (:30), `IsConcatSafe` (:87), `SafeToString` (:88), `SwatchColor`
(:110), `Say` (:138), `MakeCloseButton` (:155). `CORE_SEAM` lists five: **`MakeCloseButton` is
absent**, and it is not on any `ignore` list either. The file's own doctrine
(`tests/test_surface_parity.lua:24-27`) is that "`ignore` encodes 'live-only, on purpose' as DATA"
precisely because "an intentional omission and a bug are otherwise indistinguishable" — and here the
omission is encoded by silence, which is the failure mode the file was written to end.

**Impact.** The parity case would not notice `MakeCloseButton` appearing on the degraded arm, nor a
future member added beside it. The deliberateness is recorded elsewhere
(`tests/test_coresetup.lua:200-207` asserts it stays absent degraded), so the shipped behaviour is
correct; what is broken is the guard.

**Reachability.** Test inventory only — the shipped code is correct. Capped at Medium by that
reachability line.

**Fix direction.** Add `"MakeCloseButton"` to `CORE_SEAM` and to a new `CORE_LIVE_ONLY` ignore list,
carrying the one-line argument that already lives in `tests/test_coresetup.lua`. While there, correct
the three stale line numbers in the same comment (see `CM-R-04`).

### CM-R-04 — Eight of fourteen `file:line` citations in comments no longer resolve `[docs]`

**Where:** swept across `core/ modules/ settings/ defaults/ tests/`; 14 `path.lua:N` citations appear
inside comments, and these resolve to something other than the cited code:

| Citation site | Points at | Line actually contains |
|---|---|---|
| `core/DebugLogSetup.lua:93` | `settings/General.lua:268` | `},` |
| `core/DebugLogSetup.lua:113` | `core/PerfSetup.lua:98` | `slash = "/cm",` |
| `modules/MacroBarButton.lua:115` | `core/MacroDisplay.lua:79` | `end` |
| `modules/MacroBarButton.lua:146` | `modules/MacroBarFlyout.lua:413` | `local edge` |
| `tests/test_defaults.lua:75` | `core/Classifier.lua:157` | `--` |
| `tests/test_surface_parity.lua:47-49` | `core/CoreSetup.lua:73/74/99` | comment / `else` / comment (real: 87, 88, 138) |
| `tests/test_surface_parity.lua:84` | `core/PerfSetup.lua:98` | `slash = "/cm",` |
| `tests/test_surface_parity.lua:126` | `settings/Slash.lua:305` | `printHelp = function() Sl:PrintHelp() end` (real: 303) |

Correct today: `core/DebugLogSetup.lua:101 → settings/Panel.lua:166`, `:109 → core/Debug.lua:39`,
`:114 → core/PerfSetup.lua:46`, `core/ConsumableMaster.lua:453 → libs/LibKa0s/Options.lua:620`,
`tests/test_macrobar.lua:100 → core/MacroBarLayout.lua:36`.

**Impact.** This addon's comments are unusually load-bearing — several of them are the only record of
*why* a TOC position or a withheld stub member is what it is — and a line number that lands on `end`
costs the next reader a full re-derivation. Roughly 57% of the citations are wrong.

**Reachability.** Comments only; no runtime effect. Capped at Medium.

**Fix direction.** Cite the **symbol**, not the line (`core/PerfSetup.lua`'s `log` thunk,
`settings/Slash.lua`'s `KCM.SlashCommands.instance`) wherever the name is unambiguous; keep a number
only where the citation is genuinely positional, and re-derive those in the same pass.

### CM-R-05 — Two `colorDecode` codecs over one storage shape disagree on the missing-channel default `[design]`

**Where:** `settings/OptionsSetup.lua:101-104` returns `c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1`
(white); `settings/Slash.lua:295-298` returns `c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1` (black).

**Problem.** Both describe the same stored positional `{ r, g, b, a }` and both are handed to a
LibKa0s major (`Options-1.0` and `Slash-1.0`) as *the* decoder for this addon's colors. For a stored
table that is nil or short a channel, the panel's swatch and `/cm get <path>` report different
colours for the same setting. Neither agrees with `core/CoreSetup.lua`'s `KCM.SwatchColor`
(`:110-113`), which is the third reader and the only one that takes a **per-surface** four-channel
fallback — the bar backdrop's is black at 50%, not white and not opaque black.

**Reachability.** Not reachable on a default profile: every shipped colour in `defaults/Profile.lua`
carries all four channels and `colorEncode` always writes four. It fires the first time a colour row
is added without a default, or a stored table is truncated by hand.

**Fix direction.** One decoder, defined once and passed to both descriptors. It must not invent a
colour of its own — hand back `nil` for an absent channel and let each surface apply its own default,
which is the split `KCM.SwatchColor` already implements correctly.

### CM-R-06 — `docs/automated-tests/RESULTS.md` is stale against today's run and against its own newest row `[tests]` `[docs]`

**Where:** `docs/automated-tests/RESULTS.md`.

**Problem.** Two distinct staleness layers. (a) Against today: the newest table row,
`20260825-103407` (`manifest.json`: stamped `2026-08-25T10:34:07+05:30`, SHA `e510ffc`,
`"dirty": true`), records 698 tests / 58 lint files / NLOC 15870 / 1703 functions; today's run reads
**749 / 59 / 17632 / 1888**. (b) Internally: the prose under `## Test suite` still opens *"675 cases,
the count `20260807-114612` records"* and the `## Lint` section still says *"Clean over **56
files**"*, two table rows behind the file's own newest entry.

**Impact.** The watch list and the narrative are the artifact a reviewer is told to cite for
structural findings. Read as current, they understate the tree by 51 cases, 1762 NLOC and 185
functions.

**Reachability.** Documentation only; no runtime effect. Stale, not non-compliant — regeneration
belongs to release (`/wow-addon:bump-version`), not to this pass.

**Fix direction.** Let the next release's regeneration prepend a fresh row, and move the `## Test
suite` / `## Lint` prose onto the newest row in the same change rather than leaving it anchored to
`20260807-114612`.

### CM-R-07 — Three `KCM.Debug` call sites use `%d`, which the addon's own contract forbids `[debug]`

**Where:** `settings/Category.lua:764`, `modules/Selector.lua:610`, `modules/Selector.lua:655`.

**Problem.** `docs/debug.md:30` states the invariant plainly: *"format placeholders are always `%s`
(never `%d`/`%f`, since a combat 'secret' value must never hit a numeric formatter)."* All three sites
pass `%d`. The seam (`core/Debug.lua:44-53`, and the library's `D.Debug` on the live path) runs every
vararg through `KCM.SafeToString` **first**, so what reaches `string.format` is always a string —
numeric-coercible today because the arguments are `#priority`, `curIdx`, `newIdx`, `from`, `to`, all
addon-internal integers. The moment any argument is a value `SafeToString` renders as `"<secret>"`,
`("%d"):format("<secret>")` raises.

**Reachability.** Only with `/cm debug on` (or the console's own toggle) armed and a priority-list
paint or reorder performed — and, today, it cannot actually raise, because none of the five arguments
can be secret. It is a latent hazard and a live contract violation, not a live bug.

**Fix direction.** Change the three placeholders to `%s`. `SafeToString` has already stringified the
argument, so the rendered line is identical.

### CM-R-08 — Seven tracked files sit LF in the working tree against a CRLF pin `[line-endings]`

**Where:** `git ls-files --eol` reports `w/lf` (or `w/mixed`) under `attr/text=auto eol=crlf` for:
`.pkgmeta`, `ConsumableMaster.toc`, `core/ItemSetup.lua`, `core/SlashCommands.lua`,
`docs/revendor/2026-08-25/01_DELTA.md` (`w/mixed`), `docs/revendor/2026-08-25/05_SUMMARY.md`,
`tests/test_itemsetup.lua`. `tests/_kit/run-automated-tests.sh` is correctly `w/lf` under its
`*.sh text eol=lf` carve-out and is **not** a straggler.

**Problem.** `.gitattributes` carries the client-bound pin (`* text=auto eol=crlf`, line 1-28), the
`*.sh` carve-out (line 34) and the binary markings, so the file itself is right and the **working
tree disagrees with it**. Two of the seven — `ConsumableMaster.toc` and `core/SlashCommands.lua` —
ship to the client.

**Reachability.** Recorded as a review **observation**; the authoritative roll-up with its commands
belongs to `/wow-addon:standards-audit`. No player-visible effect (the client tolerates LF), but the
index/worktree disagreement is what makes the next `git add` produce a whole-file diff.

**Fix direction.** `git add --renormalize .` fixes the **index** only; the working tree needs the
files rewritten (delete + `git checkout --`, or a targeted rewrite). Not this pass's job.

---

## Low

### CM-R-09 — `O.RequestRefresh` allocates a closure and a timer on every call `[perf]`

**Where:** `settings/Panel.lua:908-928`.

The debounce is token-based: every call increments `O._refreshToken`, builds a fresh closure and
schedules a `C_Timer.After`, and all but the last return immediately on the token compare. During the
`GET_ITEM_INFO_RECEIVED` burst the comment at `:900-905` describes (~150 items on first panel open),
that is ~150 closures and ~150 timers to perform one refresh.

**Reachability.** Any player opening the settings panel for the first time in a session, and again on
every bag-driven recompute burst. One-off cost, not a per-frame cost, and it does not touch either
declared perf bucket — nothing in `docs/perf-analysis/20260807-132029/dump.json` or today's
`tests/perf.lua` measures it, so the magnitude here is **unverified**.

**Fix direction.** Schedule only when nothing is pending, and re-derive the capped delay inside the
one live timer. Keep the `REFRESH_MAX_WAIT_SEC` cap — the token scheme is what currently implements
it, so the replacement has to carry it explicitly.

### CM-R-10 — `KCM.MakeCloseButton` has zero call sites `[dead-code]`

**Where:** `core/CoreSetup.lua:155-157`.

`grep -rn "MakeCloseButton" core modules settings defaults locales` returns the definition and
nothing else; every other hit is a comment or a test. The addon builds no standalone window of its
own — the debug console and the perf panel are the library's and get `addonName` through their own
descriptors — so the wrapper is preparatory. It is deliberate and documented
(`tests/test_coresetup.lua:200-207`), and `standalone-windows` wants exactly this shape when a window
*is* built, so this is a note rather than a removal request.

**Reachability.** Nobody: the function is never called in any shipping path.

**Fix direction.** Leave it, and keep it on `CORE_SEAM`'s ignore list per `CM-R-03` so its
deliberateness is data rather than silence.

### CM-R-11 — `Settings.RegisterAddOnCategory` is called with no combat guard `[taint]`

**Where:** `settings/Panel.lua:866-867`, reached from the `bootstrap` frame at `:984-990`.

`registerPanel` runs on `PLAYER_LOGIN` and on `ADDON_LOADED` for `Blizzard_Settings`. Neither can
normally fire mid-combat, and `O.Open` (`:963-966`) already gates the *open* path on
`InCombatLockdown()` with the canonical grey notice. The residual case is another addon calling
`C_AddOns.LoadAddOn("Blizzard_Settings")` during a fight.

**Reachability.** No shipping configuration of this addon reaches it; it needs a third-party addon to
force-load `Blizzard_Settings` in combat.

**Fix direction.** If it is touched at all, defer the body on `InCombatLockdown()` and retry from the
existing `PLAYER_REGEN_ENABLED` handler (`core/ConsumableMaster.lua:561`) rather than adding a second
event registration.

### CM-R-12 — Six functions sit at exactly CCN 15, the release gate's cap `[complexity]`

Today's `lizard` run: 0 warnings, max CCN **15**, reached by `itemCooldown@102-114@core/MacroDisplay.lua`,
`availableForHands@344-363@modules/Selector.lua`, `S.PickBestForSlot@300-314@modules/Selector.lua`,
`S.SweepStaleDiscovered@545-571@modules/Selector.lua`, `applyBackdrop@217-244@modules/MacroBar.lua`,
`Helpers.BuildAboutContent@763-824@settings/Panel.lua`. `automated-tests`' release gate is *zero CCN
> 15*, so any one added `and`/`or` in any of the six reddens the tag. Worth knowing that in Lua this
is dense defaulting rather than tangled control flow — `applyBackdrop` is six `~= false` guards and
four `tonumber(...) or` fallbacks, not four levels of nesting.

**Reachability.** A release-time gate, not a runtime path. Informational.

### CM-R-13 — A whole paragraph is duplicated in `tests/test_surface_parity.lua` `[docs]`

`tests/test_surface_parity.lua:169-174` and `:182-186` carry the same "*Live-only ON PURPOSE. With the
library absent the panel is not registered AT ALL…*" argument twice, the second copy interrupting the
list of what is deliberately **not** on `OPTIONS_LIVE_ONLY`. Delete the first.

### CM-R-14 — A test name asserts more than the case does `[tests]`

`tests/test_database.lua:56-63`, "*Database.RunMigrations never writes into the profile scope*", is
false as a statement about the code: `MigrateMacroBarV2` and `MigrateLabelFlagsV3` both write into
`db.profile` by design. What the case actually asserts is narrower — `db.profile.enabled` is
untouched, and `db.profile.schemaVersion` is nil. The name is the assumption behind `CM-R-01`, written
down as though it were tested.

Adjacent, and worth a glance in the same pass: `tests/test_database.lua:65-72` asserts
`t.truthy(true, "calling before AceDB:New does not raise")`. It is not vacuous — the kit's `pcall`
wrapper turns a raise into a failure — but the assertion carries none of that, and the shape is one a
reader has to reason about rather than read.

**Reachability.** Test inventory only.

**Fix direction.** Rename to what is asserted (*"…does not reset an unrelated profile setting, and
keeps the version out of the profile scope"*), and add the missing multi-profile case alongside the
`CM-R-01` fix.

---

## Upstream findings

**None.** Nothing in `libs/` or `tests/_kit/` misbehaved in this pass, and both vendored payloads are
byte-identical to LibKa0s **v1.25.0**, the tag `CLAUDE.md:58` names.

Two upstream items are already **recorded and open** in the code and are re-stated here only so they
are not mistaken for new findings — neither is proposed for a local fix:

- `settings/MacroBar.lua:108-124` — `OptionsCompose` minor 1 emits media rows as
  `values = function() return O.LSMValues("border") end`, but `O.LSMValues` already returns the
  deferred closure, so the row renders an empty dropdown. Worked around with `lsmValues()` locally,
  filed as **LibKa0s issue #15**, with the workaround's removal tied to the re-vendor that carries
  the fix.
- `settings/Slash.lua:246-254` — `ERR_BOOL` / `ERR_ALLOWED` / `ERR_COLOR` overrides are dead because
  the emitting parsers sit above `lib:New` and read `lib.STRINGS` directly, so an instance override
  cannot reach them. Filed as **LibKa0s issue #16**.

Both are correctly shaped: reported upstream, worked around in the addon's own code where a
workaround was needed, never patched under `libs/`.
