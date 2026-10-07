# Summary (ConsumableMaster)

LibKa0s v1.70.0 -> v1.71.0 from the local annotated tag (`cb274a4`, tag object `3bf1b97`, via
`git archive`; not yet pushed). The base comes from the CLAUDE.md provenance line and matches the
payload bytes of `74bcda1`, so there is no base correction. Six library files move a minor (Env 2,
Slash 20 + SlashParse 2 for key 20.2, WidgetsLineChart 3, WidgetsAutocomplete 2, OptionsIdList 4),
no file is added or removed from the library and no floor rose. The kit moves from revision 37 to
38 and gains `secrets.lua`. No contract blocker.

The two tags vendored before this one without a bundle, v1.69.0 (`f8d2f3b`) and v1.70.0
(`74bcda1`), are recorded in the span bundle `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` (audit
finding `CM-A-01`).

In the same commit as both payloads:

- the CLAUDE.md provenance line rolls v1.70.0 -> v1.71.0;
- the kit revision this repo holds moves to 38 where prose names it: CLAUDE.md's Gate paragraph
  (it said 35), `docs/testing.md`'s layout-cap stamp (37, "vendored from LibKa0s v1.69.0") and the
  `tests/run.lua` kit-wiring comment (36, "as vendored from LibKa0s v1.68.1");
- `docs/testing.md`'s badge paragraph now says what revision 38 makes true: `<TOTAL>` is the
  inventory's Total, which counts only the cases that run, and a declared skip sits on its own
  `Skipped` row and in neither badge figure (`testing-§5`). It used to say the badge's two numbers
  differ by the declared skip;
- `docs/test-cases.md` is regenerated (Total 1202 -> 1201, `| Skipped | 1 |`; the
  `test_diagnostics_contract.lua` count row reads 8, its one declared skip excluded) and the README
  `[Tests]` badge moves 1201/1202 -> 1201/1201;
- one host test follows the kit: `tests/test_runner_list.lua`'s Totals case asserted Total equals
  the sum of the suite headings, which still count a declared skip, and went red on the copy. It
  now asserts Total plus Skipped equals that sum, and is renamed to say so. This is the only red the
  copy produced, and it is a mechanical consequence of revision 38.

Left alone: "kit revision 35" in `docs/testing.md`'s automated-test suite table and the
`test_lizard_sighted` row of the `tests/run.lua` gate list, which name the revision the sighted
complexity suite *arrived* in, not the one this repo holds.

- **Delivered free (class A):** kit 38 Totals, Slash 20.2's `nan` / `inf` refusal on schema rows,
  the library's dead bare-global rungs gone (Env 2, OptionsIdList 4).
- **Adoption candidates:** `Kit.secret` and its siblings, `ChartMath.ClipSegment`, the chart's
  hover re-sync and the autocomplete re-hook, all **not adopted in this run** (OWNER_SCOPE 5).
- **Adopted:** none. **Declined:** none, so no issue filed. **Owed by other items:** CM-04 (host
  parsing of `/cm priority`), CM-09 (`KCM.Meta`'s own bare-global rung).

Gate after the copy:

- tests (`ka0s-bounded lua5.1 tests/run.lua`): 1201 passed, 0 failed, 1 skipped, 1202 total. The
  vendor-sync gate is green on the rolled line for both payloads. `lua5.1 tests/run.lua --list`
  matches `docs/test-cases.md`.
- luacheck (`ka0s-bounded luacheck .`): 0 warnings / 0 errors in 130 files.
- complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`): pass, 0
  warnings, max CCN 15; the largest authored file is `settings/Panel.lua` at 1196 lines.
