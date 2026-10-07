Delta: LibKa0s v1.70.0 -> v1.71.0

Run non-interactively as item RV-CM of the 2026-10-07 review and standards-audit remediation, on
branch `feat/2026-10-07-review-audit-remediation`, following the `/dev-copilot:wow-revendor-libka0s`
conventions. The owner's scope ruling for the run (OWNER_SCOPE 5) makes the re-vendor mechanical:
copy both payloads whole, roll the provenance line, write this bundle, and list adoption candidates
the plan does not already require as "not adopted in this run", with no interview and no GitHub
issue.

## Source

```sh
git -C ../LibKa0s tag -l v1.71.0                                   # v1.71.0 (local only, not pushed)
git -C ../LibKa0s rev-parse --short 'v1.71.0^{commit}'             # cb274a4 (annotated tag object 3bf1b97)
git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C <scratch>/new
```

`v1.71.0` is an annotated tag on LibKa0s's `feat/2026-10-07-review-audit-remediation`, tagged
locally and not yet pushed; the push waits on the owner. The payload is taken from the tag through
`git archive`, never from the LibKa0s working tree. No worktree was added.

## Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# 74bcda1 chore: re-vendor LibKa0s v1.70.0
git archive 74bcda1 libs/LibKa0s tests/_kit | tar -x -C <scratch>/at74
diff -rq --strip-trailing-cr <scratch>/at74/libs/LibKa0s <scratch>/v1.70.0/LibKa0s     # (empty)
diff -rq --strip-trailing-cr <scratch>/at74/tests/_kit   <scratch>/v1.70.0/testkit     # (empty)
```

Base v1.70.0, agreed by the provenance line, the last payload commit and the bytes. v1.69.0 and
v1.70.0 themselves have no bundle; they are recorded in the span bundle beside this one,
`docs/revendor/2026-10-07-v1.69.0-v1.70.0/`.

## Range

```sh
git -C ../LibKa0s log --oneline v1.70.0..v1.71.0 | wc -l           # 20 (LK-01 .. LK-12 and the RA-00 record)
git -C ../LibKa0s diff --stat v1.70.0 v1.71.0 -- LibKa0s testkit
#  LibKa0s/Env.lua                 |  14 ++---
#  LibKa0s/OptionsIdList.lua       |  15 ++---
#  LibKa0s/Slash.lua               |   4 +-
#  LibKa0s/SlashParse.lua          |  10 +++-
#  LibKa0s/WidgetsAutocomplete.lua |  48 ++++++++++-----
#  LibKa0s/WidgetsLineChart.lua    |  83 +++++++++++++++++++++-----
#  testkit/README.md               |   7 ++-
#  testkit/framework.lua           |  91 +++--------------------------
#  testkit/inventory.lua           | 125 ++++++++++++++++++++++++++++++++++++++--
#  testkit/secrets.lua             | 112 +++++++++++++++++++++++++++++++++++
#  10 files changed, 369 insertions(+), 140 deletions(-)
```

## Per-file minor delta

| File | Major | v1.70.0 | v1.71.0 |
|---|---|---|---|
| `Env.lua` | `LibKa0s-Env-1.0` | 1 | **2** |
| `Slash.lua` | `LibKa0s-Slash-1.0` | 19 | **20** |
| `SlashParse.lua` | `LibKa0s-Slash-1.0` | 1 | **2** (Slash key 19.1 -> **20.2**) |
| `WidgetsLineChart.lua` | `LibKa0s-Widgets-1.0` | 2 | **3** |
| `WidgetsAutocomplete.lua` | `LibKa0s-Widgets-1.0` | 1 | **2** (Widgets key 12.1.4.2.1 -> 12.1.4.3.2) |
| `OptionsIdList.lua` | `LibKa0s-Options-1.0` | 3 | **4** (Options key ...3.8... -> ...4.8...) |
| test kit `framework.lua` | `Kit.VERSION` | 37 | **38** |

Every other library file prints the same constant old and new (34 files in both trees). No library
file is added or removed, no `NEEDS_*` floor rises, no major is added. The kit gains one file,
`testkit/secrets.lua`. The CHANGELOG `v1.71.0` block (`../LibKa0s/CHANGELOG.md`, tag) states the
same version set.

## Both diffs, before the copy

```sh
diff -rq <scratch>/new/LibKa0s libs/LibKa0s
# differ: Env.lua, OptionsIdList.lua, Slash.lua, SlashParse.lua, WidgetsAutocomplete.lua, WidgetsLineChart.lua
diff -rq <scratch>/new/testkit tests/_kit
# differ: README.md, framework.lua, inventory.lua; Only in new/testkit: secrets.lua
```

Exactly the files the range moved; no line-ending drift and nothing to delete. The copy is
delete-and-copy (`rm -rf libs/LibKa0s tests/_kit`, then both folders whole);
`tests/_kit/run-automated-tests.sh` stays executable.

## Consumption map (the touched majors)

| Touched surface | Consumed here? | Where |
|---|---|---|
| `Slash` 20 / `SlashParse` 2 | **yes** | `settings/Slash.lua:456` (the major), `settings/Slash.lua:509` (`slashLib.ParseValue` for every composed schema row) |
| `Options` / `OptionsIdList` 4 | **yes** | `settings/OptionsSetup.lua:164`; the id-list help mark's `addonName` route (`settings/OptionsSetup.lua:221`) |
| `Env` 2 | **yes** | `core/EnvSetup.lua:57`, behind `KCM.Meta` / `KCM.Version` |
| `WidgetsLineChart` 3 | no | the `Widgets` major is consumed (drag handle, macro bar), but no host code calls `LineChart` or `ChartMath` |
| `WidgetsAutocomplete` 2 | no | no host code calls `Autocomplete` |

`Fourteen` consumed majors in CLAUDE.md stands: v1.71.0 adds no major.

**Slash 20.2's `nan` / `inf` refusal covers composed schema rows only.** `lib.ParseValue` now
refuses `nan`, `inf`, `-inf` and `1e400` on a number row, so `/cm set <path> nan` on a schema row
is refused through `settings/Slash.lua:509` with no host change. Host-parsed input in
`core/SlashCommands.lua` (for example `/cm priority`'s id argument) does not go through
`ParseValue`; its validation is item CM-04's, not this re-vendor's.

**Env 2** drops the library's bare `GetAddOnMetadata` rung. `KCM.Meta` (`core/EnvSetup.lua:69-77`)
keeps its own library-absent fallback, bare global included; dropping that rung is item CM-09's.
On a live client the library answers first, so nothing changes.

## Kit revision

```sh
grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua   # 38 (vendored: 37)
```

Kit revision 37 -> 38. Both payloads move together in one commit (the pairing rule), by construction
of the whole-folder copy. Revision 38 changes the `--list` Totals: Total counts only the cases that
run, and a declared skip moves to a `| Skipped |` row (`docs/api/testkit/version-38-docs.md`, tag).
This repo has one declared skip (in `test_diagnostics_contract.lua`), so `docs/test-cases.md` is
regenerated (Total 1202 -> 1201, `Skipped | 1`) and the README badge becomes `1201/1201`.

## Contract delta

No blocker. The one host red the copy produced is a mechanical consequence of kit 38's Totals:
`tests/test_runner_list.lua` asserted Total equals the sum of the suite headings, which still count
a declared skip. The case now asserts Total plus Skipped equals that sum (renamed accordingly). See
`05_SUMMARY.md`.
