# 04 — Execution plan: the copy, and nothing else

There is no adoption work in this release (`02_CANDIDATES.md`), so the plan is the copy and the
references that move with it, all in one commit.

## Steps taken

1. Extract the tag into a scratch directory:
   `git -C ../LibKa0s archive v1.33.0 LibKa0s testkit | tar -x -C <scratch>/`.
2. Measure before touching anything: per-file minors (`01_DELTA.md`), and the content and byte diffs
   of both payloads.
3. Replace both payloads whole, so a file deleted upstream would be deleted here too:
   ```sh
   rsync -r --delete --checksum <scratch>/LibKa0s/ libs/LibKa0s/
   rsync -r --delete --checksum <scratch>/testkit/ tests/_kit/
   ```
4. Check all four diffs are empty, and `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s`
   too. Check the runner's index mode is still 100755 (`git ls-files -s`; `core.fileMode` is false
   on this mount, so a copy cannot flip it).
5. Roll the provenance line (`CLAUDE.md:58`) in the same commit as the bytes, which is the pairing
   `tests/test_vendor_sync.lua` enforces.
6. Roll every other live bundled-version reference. There was one: the kit-revision note in
   `docs/smoke-tests.md:555`. Also correct the `tests/wow_mock.lua:356` comment that revision 18
   made stale.
7. Add the in-game check the one player-visible change needs: `docs/smoke-tests.md` §11a step 6a,
   where a font dropdown's first open after a login draws every row.
8. Gate: `lua tests/run.lua`, `luacheck .` and `lizard -C 15`, then CRLF verified on every text file
   the commit touches. `tests/_kit/` and `libs/` are byte copies and are left exactly as extracted.

## Not done, on purpose

- No file under `libs/LibKa0s/` or `tests/_kit/` was edited by hand. A fix belongs upstream.
- The suite inventory and the README badge did not move, because no case changed.
