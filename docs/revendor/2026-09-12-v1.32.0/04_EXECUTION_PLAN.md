# 04 — Execution plan: the host bulk bracket (debug-logging-§10)

## The seam

`settings/Panel.lua`:

- `Helpers.Set` tallies rather than logs while a bracket is open, and counts a row only when its
  stored value changes (deep compare for tables, `Helpers.Get` read before the write). Outside a
  bracket it is unchanged.
- `Helpers.Bulk(act, scope, fn)` runs `fn` in a frame and logs `[Set] <act> <scope>: N rows` when it
  closes. A raising `fn` still closes the frame and logs, and the error is then re-raised unwrapped.
  A nested frame folds into its outer frame and logs nothing.
- `Helpers.MuteSetLog(fn)` works the same way but logs no line, and it silences any bracket around it.
- `Helpers.SetManyAndRefresh(entries, opts)` takes `opts.bulk = { act, scope }`. The bracket wraps the
  writes and the reactors, and opens only after validation, so a refused batch logs nothing.

## The acts

| Act | File | Line now |
|---|---|---|
| Macro Bar page Defaults (`doResetPage`) | `settings/MacroBar.lua` | `[Set] reset Macro Bar page: N rows` |
| General page Defaults (`doResetGeneralPage`) | `settings/General.lua` | `[Set] reset General page: N rows` |
| Composite Reset category (`resetCompositeCategory`) | `settings/Category.lua` | `[Set] reset category <KEY>: N rows`; the extra `[Prio] reset <KEY>` line is gone |
| `/cm aio <key> reset` (`aioReset`) | `core/SlashCommands.lua` | `[Set] reset category <KEY>: N rows` |
| `KCM.ResetAllToDefaults` | `core/ConsumableMaster.lua` | `[Set] reset profile '<name>' to defaults`, from the `OnProfileReset` handler. The sweep and `ResetProfile` run under `MuteSetLog`, and the `[Prio] reset all (reason=…)` line is gone |
| AceDB profile copy | `core/ConsumableMaster.lua` | `[Set] copied profile 'A' → 'B'`, from the `OnProfileCopied` handler |

Left alone as instructed: the single-row resets (`/cm reset <path>`, Reset slot order, Stat Priority
Defaults) and the registry acts (`Selector.ResetBucket`, `Selector.ResetAllBuckets`).

## Tests first

`tests/test_bulklog.lua` (new, 11 cases) and the flipped
`tests/test_macrobar.lua` case "macrobar Defaults: the page reset is one [Set] line, written into
the same table". The red run before the code: **837 passed, 11 failed** of 848, exactly the new and
flipped cases. `tests/wow_mock.lua` gains `db:CopyProfile` (in place, `OnProfileCopied` carrying the
source key), and `tests/test_locale.lua` gains the `DEBUG SCOPE` residue class for the two page
scopes handed to `Helpers.Bulk`.

`tests/test_pipeline.lua:372`, the session-row restore, still holds: the sweep runs under the mute
and still writes the row.

## Gate after

```
lua tests/run.lua   848 passed, 0 failed, 0 skipped, 848 total
luacheck .          0 warnings / 0 errors in 104 files
lizard -C 15        No thresholds exceeded
```
