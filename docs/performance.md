# Performance

How ConsumableMaster is measured, what it brackets, and what the numbers mean. Two sources feed one
schema: an **in-game A/B capture** (`/cm perf`) and an **offline scenario run**
(`lua tests/perf.lua`). Captures are filed under [`perf-runs/`](./perf-runs/README.md).

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

`Perf` is a **load-time upvalue** (`performance-§2`), which is why `core/PerfSetup.lua` sits second
in the TOC — ahead of every file that takes `local Perf = NS.Perf`. With no capture open the gate
is an upvalue read, a nil test and a field read: no table lookup through `KCM`, no allocation. It
**must** be a gate rather than an unconditional call, because `Note()` records whether or not a
window is open — an ungated bracket would accumulate outside every window and poison the next
report.

## Suspend and resume

`suspend` drops every event the addon listens on (`KCM:UnregisterAllEvents()`) and re-runs
`MacroBar.Update`, which tears the bar down. That stops the recompute pipeline, auto-discovery and
the cooldown repaint in one move. `resume` calls `KCM:OnEnable` — the real list, called rather than
copied, so a tenth event added there cannot be forgotten here — rebuilds the bar and requests a
recompute.

Two rules the contract depends on: it works **without a reload** (reloading shifts shared-frame
ownership, the confound that makes Blizzard's own addon profiler useless for this question), and
visibility is enforced at the **source** rather than by hiding frames, or a combat transition would
re-show the bar behind suspend's back.

## Storage

Captures ride `ConsumableMasterPerfDB`, its **own** SavedVariable, declared alongside
`ConsumableMasterDB` at `ConsumableMaster.toc:11` and named in `.luacheckrc`. It is deliberately not
the AceDB tree: `LibKa0s-Perf` writes `_G[sv]` directly, so folding it into `ConsumableMasterDB`
would stamp `schema` and `runs` onto AceDB's root and trip AceDB's own discard branch on the next
load.

## In game

```
/cm perf
```

opens the library's step panel. It walks the A/B protocol, writes a record into the ring and can
print or export it. With `LibKa0s-Perf-1.0` absent the verb still dispatches and answers
`perf capture unavailable.` — it never silently does nothing (`settings/Slash.lua`).

## Offline

```
lua5.1 tests/perf.lua                       # print a scenario table
lua5.1 tests/perf.lua --out perf.json       # …and write the record
lua5.1 tests/perf.lua --label pre-release   # label it
```

Four scenarios, run against the whole addon loaded under the test mock:

| Scenario | What it drives |
|---|---|
| `recompute` | `Pipeline.Recompute` — the full out-of-combat pass |
| `cooldownRefresh` | `MacroBar.RefreshCooldowns` — the in-combat path |
| `probeOverheadOff` | the same cooldown walk with the brackets **dormant** |
| `probeOverheadOn` | the same cooldown walk with the brackets **armed** |

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
  which reads as a perfect zero-overhead result.

Timings are printed for orientation only. Read them as ratios between scenarios in one run, never
as absolute numbers to compare across machines.

## The exemption does not apply here

`performance-§12` lets an addon with no combat path decline the harness. ConsumableMaster does not
qualify and does not claim it: the cooldown repaint is an in-combat event handler doing real
per-frame work, so the full section binds. There is no deviation row for perf in
[ARCHITECTURE.md](./ARCHITECTURE.md#documented-deviations), and there should not be one.
