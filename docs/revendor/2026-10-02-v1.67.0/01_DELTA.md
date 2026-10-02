Delta: LibKa0s v1.66.0 -> v1.67.0

Run non-interactively as item CA-CM-RV of the 2026-10-02 LibKa0s census adoption
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`), on branch
`feat/2026-10-02-libka0s-census-adoption`. Steps 2-4 of `revendor-libka0s`: resolve the tag, read the
delta, copy both payloads whole, roll the provenance line. The adoption interview (Steps 5-6) is not
run: the adoption bundle already assigns each new surface to an item, recorded in `02_CANDIDATES.md`.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.67.0^{commit}'   # 0bccf4c (annotated tag object 749c42e)
git -C ../LibKa0s rev-parse --short HEAD                 # 0bccf4c, working tree clean
```

`../LibKa0s` was checked out at the tag's commit with a clean tree, so the payload was copied from
the checkout (`rsync -a --delete`), which is the tag's bytes. The tag is local to `../LibKa0s` and
not pushed yet (the plan pushes it with the owner's merge go-ahead).

## Base (3a, 3b)

```sh
grep -n '[Bb]undles' CLAUDE.md
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.66.0 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit          # e7dd55f (GI-CM-RV, v1.66.0)
git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/v166/
git archive HEAD libs/LibKa0s tests/_kit | tar -x -C <scratch>/head/
diff -rq --strip-trailing-cr <scratch>/v166/LibKa0s <scratch>/head/libs/LibKa0s \
  && diff -rq --strip-trailing-cr <scratch>/v166/testkit <scratch>/head/tests/_kit && echo payload-matches-base
# payload-matches-base
```

Base v1.66.0, agreed by the line, the last payload commit and the bytes. The previous bundle
(`2026-10-01-v1.66.0`) is the newest tag recorded; no tag in between went unrecorded, so no span
bundle is owed.

## Range

```sh
git -C ../LibKa0s log --oneline v1.66.0..v1.67.0 | wc -l    # 6 commits
git -C ../LibKa0s diff --stat v1.66.0 v1.67.0 -- LibKa0s testkit
#  3 files changed, 125 insertions(+), 36 deletions(-)
```

## Per-file minor delta (3c)

Only the rows that moved:

| File | Old | New |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0` 9 | `LibKa0s-Core-1.0` 10 |
| `Options.lua` | `LibKa0s-Options-1.0` 27 | `LibKa0s-Options-1.0` 28 |
| `OptionsIdList.lua` | `IDLIST_MINOR` 2 | `IDLIST_MINOR` 3 |

The Options key moves 27.2.34.2.2.8.1.7.4.2 -> 28.2.34.2.3.8.1.7.4.2. No file added or removed, no
`NEEDS_*` floor rises, no major added (CHANGELOG v1.67.0 version block). `LibKa0s.xml` is unchanged,
so neither the TOC nor the harness load list moves.

## Both diffs (3d), before the copy

```sh
diff -rq ../LibKa0s/LibKa0s libs/LibKa0s
# differ: Core.lua Options.lua OptionsIdList.lua
diff -rq ../LibKa0s/testkit tests/_kit
# (empty)
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing to delete. Line endings follow the
previous re-vendor: both payloads are CRLF on disk and LF in the index under the repo's
`* text=auto eol=crlf`, the same as the library's checkout, so the copy needs no conversion.

## Consumption map (3e)

`Core` (`core/CoreSetup.lua:64`) and `Options` (`settings/OptionsSetup.lua:164`) are both consumed.
This addon calls no `MakeResizable` itself; the library's own console and perf panel do
(`libs/LibKa0s/DebugLog.lua:690`, `libs/LibKa0s/PerfPanel.lua:162`) and pass none of the three new
fields. It builds no `O.IdList`, so OptionsIdList's new rung is never reached here.

## Kit revision (3f)

```sh
grep -n 'Kit.VERSION =' ../LibKa0s/testkit/framework.lua tests/_kit/framework.lua
# both: Kit.VERSION = 35
```

Kit revision unchanged at 35; `tests/_kit/` is byte-identical before and after the copy.

## Contract delta (3g)

No blocker.

- **Core 10** (`docs/api/Core/version-10-docs.md`, "The resize grip"): `canResize`, `onResizeStop`
  and `gripParent` are optional; a caller that passes none behaves exactly as on v1.66.0. No member
  added.
- **Options 28 / OptionsIdList 3** (`docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`): the
  help-mark art takes the descriptor's `addonName` only when that addon is loaded, else the client
  glyph plus one `Cfg` line per instance. Options 28 is a docblock correction. No member, field,
  string or floor moves.

`grep -rn '__Attach'` outside `libs/` and `tests/_kit/` finds no host call site.
