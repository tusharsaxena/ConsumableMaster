# Performance

How ConsumableMaster is measured, what it brackets, and what the numbers mean. Two sources feed one
schema: an **in-game A/B capture** (`/cm perf`) and an **offline scenario run**
(`lua tests/perf.lua`). In-game captures are filed as frozen dated bundles under
[`perf-analysis/`](./perf-analysis/README.md); offline runs live in the automated-test bundle that
produced them (`automated-tests-§7`).

## The model

`core/PerfSetup.lua` is the addon's half of `LibKa0s-Perf-1.0`. It is an **A/B capture harness, not
a profiler**. The protocol is: pull once with the addon live, pull again with it suspended, and
report the difference in ms-per-frame. Recording opens when combat starts and closes when it ends,
so what it measures is the addon's **in-combat** cost and nothing else.

That framing matters, because this addon's genuinely expensive paths are deliberately **out** of
combat:

* the macro bar's flyout rebuild is skipped in combat;
* `MacroBar.Update` defers wholesale until regen;
* macro writes queue and flush after combat.

None of those will ever appear in a capture. What does appear is the **cooldown repaint**, which
rides `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` and walks every bar button plus every shown
flyout row. It is the one path that runs at near-frame frequency mid-fight, and it is the reason
this wiring exists at all.

## The declared buckets

Two, both declared in `core/PerfSetup.lua`'s descriptor. Membership controls **printing** only —
`Note()` accepts any key, so an undeclared bracket records silently rather than raising.

| Bucket | Bracketed at | What it covers |
|---|---|---|
| `cooldown` | `modules/MacroBar.lua`, `MB.RefreshCooldowns` | every bar button's cooldown swipe plus every shown flyout row's — the near-frame-frequency path |
| `recompute` | `core/ConsumableMaster.lua`, `Pipeline.Recompute` | the whole pass: the 15-category walk, the composite re-picks and every macro write |

Both use the same gate, and the gate is not decoration:

```lua
local t0 = (Perf and Perf.on) and debugprofilestop() or nil
...
if t0 then Perf.Note("cooldown", debugprofilestop() - t0) end
```

`Perf` is a **load-time upvalue** (`performance-§2`), which is why `core/PerfSetup.lua` sits after
`core/LifecycleSetup.lua` in the TOC — ahead of every file that takes `local Perf = NS.Perf`. With no capture open the gate
is an upvalue read, a nil test and a field read: no table lookup through `KCM`, no allocation. It
**must** be a gate rather than an unconditional call, because `Note()` records whether or not a
window is open — an ungated bracket would accumulate outside every window and poison the next
report.

## Suspend and resume are two holds on ONE latch

`suspend` and `resume` are no longer this file's, and `LibKa0s-Perf-1.0` minor 12 no longer calls
them. `P.Suspend()` takes the **`perf` hold** on the addon's single `LibKa0s-Lifecycle-1.0` latch and
`P.Resume()` gives it back; the latch runs the teardown, and only if this is the first hold. The
teardown itself is `core/LifecycleSetup.lua`'s `standDown` / `standUp`, which is the very same code
the **disabled** state reaches — see
[ARCHITECTURE.md](./ARCHITECTURE.md#the-disabled-state-is-total).

That is the point of the move rather than a tidy-up. A second teardown path written beside this one
would give the addon two mechanisms that both mean "be inert", and they diverge on the first module
added after the second was written. It also fixes a case a boolean could not represent: a player can
disable the addon **mid-capture** and re-enable it there, so **releasing one hold must not resurrect
an addon the other is still holding down**. "Resume before saving or reporting" is unchanged in
force and sharpened in meaning — it requires the harness to **release its own hold**, not to stand
the addon up, and an addon the player left disabled at the end of a run stays disabled.

`P.suspended` keeps its name and its meaning and is now a **view** on the latch rather than a second
boolean beside it; assigning to it raises.

Two rules the contract depends on, unchanged: it works **without a reload** (reloading shifts
shared-frame ownership, the confound that makes Blizzard's own addon profiler useless for this
question), and visibility is enforced at the **source** — `MacroBarModel.IsEnabled()` — rather than by
hiding frames, or a combat transition would re-show the bar behind the stand-down's back.

Standing up rebuilds from the settings **as they are now**, never from a snapshot taken on the way
down.

## Storage

Captures ride `ConsumableMasterPerfDB`, its **own** SavedVariable, declared alongside
`ConsumableMasterDB` at `ConsumableMaster.toc:11` and named in `.luacheckrc`. It is deliberately not
the AceDB tree: `LibKa0s-Perf` writes `_G[sv]` directly, so folding it into `ConsumableMasterDB`
would stamp `schema` and `runs` onto AceDB's root and trip AceDB's own discard branch on the next
load.

The ring is a bounded diagnostics buffer, not the archive. A capture worth keeping is committed as a
frozen dated bundle under [`perf-analysis/`](./perf-analysis/README.md) — `report.md`, `dump.json`
and `ANALYSIS.md`, the directory stamped in local time from the record's own `timestamp`.

## In game

```
/cm perf
```

opens the library's step panel. It walks the A/B protocol, writes a record into the ring and can
print or export it. With `LibKa0s-Perf-1.0` absent the verb still dispatches and answers
`perf capture unavailable.` — it never silently does nothing (`settings/Slash.lua`).

At the end of a run, `/cm perf report` prints the summary a human reads and `/cm perf dump` prints
the record as one line of JSON; the debug window's **Copy** button carries both, plus the run's
lifecycle lines, out of the client in one paste. That paste is what `/wow-addon:perf-analysis` turns
into a bundle under [`perf-analysis/`](./perf-analysis/README.md).

## Offline

```
lua5.1 tests/perf.lua                       # print a scenario table
lua5.1 tests/perf.lua --out perf.json       # …and write the record
lua5.1 tests/perf.lua --label pre-release   # label it
```

Five scenarios, run against the whole addon loaded under the test mock:

| Scenario | What it drives |
|---|---|
| `recompute` | `Pipeline.Recompute` — the full out-of-combat pass |
| `cooldownRefresh` | `MacroBar.RefreshCooldowns` — the in-combat path |
| `probeOverheadOff` | the same cooldown walk with the brackets **dormant** |
| `probeOverheadOn` | the same cooldown walk with the brackets **armed** |
| `refreshBurst` | `Options.RequestRefresh` × 150 — the first-open item-info storm, one burst |

**`lua tests/run.lua` does not invoke this, and no commit depends on it.** Wall-clock numbers on a
developer machine are not stable enough to fail a build on, and a perf suite that fails spuriously
gets disabled within a week. The automated-tests runner records it, and `automated-tests-§3` lets
it gate the **tag**, never the run and never the commit.

What it *does* assert is the deterministic half, which is machine-independent:

* the dormant arm allocates no more than an **absolute ceiling** (6144 bytes/iter today, against a
  measured 6000.0 that repeats to the tenth of a byte because the walk is deterministic under the
  mock). The ceiling exists because the relation alone cannot go red the way it matters: an
  allocation added to the cooldown path itself lifts **both** arms and `off <= on + 1` still holds.
  Raise it only with a recorded reason — a rise **is** the finding;
* the dormant arm allocates no more than the armed one, which is the zero-overhead property itself;
* an armed capture records exactly **two** bucket notes over the two bracketed paths. Without this
  the two arms above could both be measuring a build where `core/PerfSetup.lua` returned early —
  which reads as a perfect zero-overhead result;
* a 150-call refresh burst arms **at most two timers** and allocates no more than **1024
  bytes** (measured 0.0, baselined 2026-09-08 over three runs). The count leads and the byte
  ceiling follows it: the count is an integer property of the debounce and is the same on every
  machine, while a byte figure taken this way reports what the collector has not reclaimed by the
  end of the loop and therefore moves with the live heap. Two timers rather than one because a
  burst that straddles the cap legitimately re-arms once.

Timings are printed for orientation only. Read them as ratios between scenarios in one run, never
as absolute numbers to compare across machines.

### The `recompute` byte figure is a residue, not an allocation

`recompute` has no ceiling and no assertion, and its byte column should not be read as what a pass
allocates. A pass allocates about **226.6 KB** under the mock, so the 200-iteration loop allocates
about 45 MB and the collector runs many cycles inside it. `measure` reports the heap growth between
the two `collectgarbage("count")` reads, which is the garbage the collector has *not* reclaimed when
the loop ends. That depends on where the loop stops in the collector's cycle, and the cycle's pacing
depends on the live heap the rest of the addon holds. Loading more code anywhere therefore moves the
figure, whatever the recompute itself does.

**The 2026-09-26 sweep (ATS-01) found this case.** Run `20260926-160431` recorded `recompute` at
**6505.88 → 14740.12** bytes/iter (+126.6%) over `f8729fa..bc284a4`. A per-commit bisect with
`tests/perf.lua` put the step at `b19e9bb` (DR-CM-03, the diagnostics report): 3031.9 → 16751.3.
That commit adds `core/Diagnostics.lua` and does not touch the recompute path. Two checks show the
step is a measurement effect:

* **The true allocation did not move.** With the collector stopped around the same 200-pass loop,
  a pass allocated 226614.5 bytes at `f8729fa`, 226614.5 at `986c51f`, 226613.8 at `b19e9bb` and
  226610.6 at `bc284a4`. Over those commits the live heap grew from 2408 KB to 2528 KB.
* **The step goes away without the file.** At `b19e9bb` with `core/Diagnostics.lua` removed from the
  TOC, `recompute` read 2619.9, on two runs out of two. The recompute never calls that file.

There was no avoidable allocation to remove. For a real change in what a recompute allocates, measure
with the collector stopped as above rather than reading this column.

## The exemption does not apply here

`performance-§12` lets an addon with no combat path decline the harness. ConsumableMaster does not
qualify and does not claim it: the cooldown repaint is an in-combat event handler doing real
per-frame work, so the full section binds. There is no deviation row for perf in
[ARCHITECTURE.md](./ARCHITECTURE.md#documented-deviations), and there should not be one.
