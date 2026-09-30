Delta: LibKa0s v1.62.0 -> v1.63.0

Run non-interactively as item SP-CM-02 of the 2026-09-29 smoke-rework and `profile` verb plan
(`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`, spec S3), on branch
`feat/2026-09-29-smoke-and-profile`. Steps 2-4 of `revendor-libka0s` only: resolve the tag, read the
delta, copy both payloads whole, roll the provenance line. The adoption interview (Steps 5-6) is not
run and no issue is filed: the one surface adopted, the Slash minor 17 profile verb, is the plan's
own item and lands in this item's second commit. Written before the copy.

## Source

```sh
git -C ../LibKa0s rev-parse --short 'v1.63.0^{commit}'   # dd7a774 (annotated tag object 527ea17)
git -C ../LibKa0s archive v1.63.0 LibKa0s testkit | tar -x -C <scratch>/new/
git -C ../LibKa0s archive v1.62.0 LibKa0s testkit | tar -x -C <scratch>/claimed/
```

The payload comes from the tag, never the working tree. The tag is local to `../LibKa0s` and not
pushed yet (the plan pushes it with the owner's merge go-ahead).

## Base (3a, 3b)

```sh
grep -n '[Bb]undles' CLAUDE.md
# 61:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.62.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # 9f3beb9
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.62.0
diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s && diff -rq <scratch>/claimed/testkit tests/_kit && echo payload-matches-base
# payload-matches-base
```

Base v1.62.0, agreed by the line, the last payload commit and the bytes. The newest earlier bundle
(`2026-09-26-v1.62.0`) states the same base for its own run, so no correction is owed.

## Range

```sh
git -C ../LibKa0s log --oneline v1.62.0..v1.63.0
git -C ../LibKa0s diff --stat v1.62.0 v1.63.0 -- LibKa0s testkit
#  LibKa0s/Slash.lua | 131 ++++++++++++++++++++++++++++++++++++++++++++++++++++++-
#  1 file changed, 130 insertions(+), 1 deletion(-)
```

## Per-file minor delta (3c)

Every file in the tag's `LibKa0s/LibKa0s.xml`, old against new by its own `[A-Z_]*MINOR` constant;
only the rows that moved:

| File | Old | New |
|---|---|---|
| `Slash.lua` | `LibKa0s-Slash-1.0` 16 | `LibKa0s-Slash-1.0` 17 |

No other file moves, no file is added or removed, and no `NEEDS_*` floor rises (CHANGELOG v1.63.0
version block).

## Both diffs (3d), before the copy

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
# Files <scratch>/new/LibKa0s/Slash.lua and libs/LibKa0s/Slash.lua differ
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
# (no output)
```

The byte diff (`diff -rq`, no strip) lists the same one file: no line-ending drift, and no
`Only in libs/LibKa0s` file to delete.

## Consumption map (3e)

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: Bus, Compat,
Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Perf, Schema, Slash
(`settings/Slash.lua:442`) and Widgets, unchanged from v1.62.0. Slash is the one moved major, and it
is consumed.

## Kit revision (3f)

```sh
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# both: Kit.VERSION = 31
```

`testkit/` is identical at v1.62.0 and v1.63.0. Both payloads are still copied whole, which is the
pairing rule by construction.

## Contract delta (3g)

None that is a blocker. The Slash member manifest gains one lib-level entry and nothing moves:

```sh
diff <(git -C ../LibKa0s show v1.62.0:docs/api/Slash/members-16.json | sed -n '/"members"/,$p') \
     <(git -C ../LibKa0s show v1.63.0:docs/api/Slash/members-17.json | sed -n '/"members"/,$p')
# > { "name": "ProfileNames", "kind": "function" },
```

`docs/api/Slash/version-17-docs.md` (Compatibility) states that no runtime behavior moves: a host
that passes no `profiles` and registers no `profile` row sees no change, and `lib.LIVE_VERBS` is
unchanged. The one thing that can go red on the copy alone is the kit's BY-NAME
`T.assertSurfaceParity(<stub>, "LibKa0s-Slash-1.0")` against the dispatcher instance, which gains
`CliProfile` and `ProfileSwitch`. This addon's Slash parity case
(`tests/test_surface_parity.lua`, "Parity: the LibKa0s-Slash stub carries the whole live seam") is
the four-argument form over the host's own `KCM.SlashCommands` table, so the copy alone does not
redden it; the document measured this addon green in that case. `grep -rn '__Attach'` outside `libs/`
and `tests/_kit/` finds no host call site.

## Span back-fill (3h)

The audit's walk over `libs/LibKa0s`, `tests/_kit` and the `CLAUDE.md` provenance rolls since the
store's first bundle (2026-08-25), less the tags the store already records: empty. No span bundle
is owed.
