# Analysis — 20260807-132029

- **Addon:** ConsumableMaster 1.5.0 (record schema 2, client interface 120007)
- **Captured:** 2026-08-07 13:17 local, label `2026-08-07 13:17`
- **Who / where:** Lânfear-Frostmourne, level 90 Destruction Warlock · Silvermoon City — Falconwing Square · solo
- **Delta:** −0.11 ms/frame — **unresolved** (below the floor, and sign-inverted)
- **Previous capture:** none — this is the first

## Headline

This is ConsumableMaster's first committed in-game capture, and it is a baseline rather than a
comparison. The frame-time A/B resolved nothing: −0.11 ms/frame is well inside the instrument's
noise, and its sign is backwards — the *suspended* arm read slower than the active one, which is the
standard tell that the environment moved between the arms. The run log confirms it, with two
`player_entering_world` scans in the 80-second gap between arm A and arm B. The answer therefore
comes from the buckets, which measure the addon's own Lua directly: **1.78 ms per second of combat,
0.027 ms/frame — about 0.18% of wall time**, all of it in the cooldown repaint. Nothing to act on
for cost; the two things worth acting on are instrumentation coverage (`recompute` never fired) and a
stale field note in the store README.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 24.0110 | 1596 | 66.4695 | 15.0445 |
| suspended (addon inert) | 27.5930 | 1821 | 65.9950 | 15.1527 |
| **delta** | +3.582 (B longer) | +225 | −0.4745 | **−0.1082** |

The delta is **unresolved**. The run-to-run spread of a 60–80 s A/B sits near ±0.3 ms/frame, and
these arms are shorter than that — 24.0 s and 27.6 s — so the floor here is if anything worse than
the nominal 0.5 ms/frame threshold. −0.1082 is a fifth of it. This is a statement about the
instrument, not about the addon: reading it as "no measurable impact" would dress up the sampler's
blindness as a finding.

The sign compounds that. The suspended arm — the arm where the addon does nothing at all — read
**0.11 ms/frame slower** than the active arm. No addon can make the client faster by running, so the
whole magnitude, and more, is environment. The arms also differ in duration by 15% (24.0 s vs
27.6 s); combat gating equalizes *when* an arm runs, never *how long*, and never *where*.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
24.0110 s, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `cooldown` | 352 | 42.7227 | 1.7793 | 0.2397 | none declared — top-level, safe to read as a total |
| `recompute` | — | — | — | — | none declared; **absent from the record — never fired** |

**Total accounted cost: 1.78 ms per second of combat.** Against the active arm's 24.011 s that is
42.72 ms of Lua in 24 seconds — **0.178% of wall time**, or **0.027 ms/frame** across the arm's 1596
frames. That per-frame figure is the one to keep: it is roughly 4× below even the *optimistic* 0.11
ms/frame the frame-time delta reported as noise, which is exactly why the delta could not see it.

The ratios that survive a change of combat duration, for the next capture to diff against:

- **14.66 calls/s** — the cooldown repaint fires a little under once every four frames at 66 fps.
  That matches the path's design: it rides `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN`
  (`core/PerfSetup.lua:21-24`), not `OnUpdate`.
- **0.1214 ms/call** — the cost of one walk over every bar button plus every shown flyout row.
- **0.2397 ms worst call** — the tail is under 2× the mean, so there is no occasional expensive pass
  hiding inside the average. At 66 fps a frame is 15.04 ms, so the worst single repaint consumed
  1.6% of one frame.

Neither declared bucket carries a `within`, so there is **no declared nesting in this addon** and no
parent claim left unverified — the table is flat by construction (`core/PerfSetup.lua:107-110`).

`recompute` is **absent from the record, meaning it never fired during either arm**. That is a
result about what the run exercised, not a gap in the harness. It is consistent with the log: the
only `[Calc]` lines in the capture sit *outside* both arms (13:19:18, 13:19:44, and the
`perf_resume` one at 13:20:27), and all three read `rewrote 0/15 (skipped 15)` — nothing changed, so
nothing recomputed. A 24-second target-dummy pull with a stable bag does not move an item count, a
spec, or a category winner. To exercise it a capture would need bag churn or a spec/talent change
mid-arm. Until one does, the recompute path is **uninstrumented in practice**, and the addon's
in-game evidence covers only the cooldown repaint.

## What the capture did not hold constant

- **Two loading screens between the arms.** The log shows `reason=player_entering_world` scans at
  **13:19:18** and **13:19:43** — after arm A ended (13:18:35) and before arm B armed (13:19:50).
  `PLAYER_ENTERING_WORLD` fires on zone change, instance transition, and reload; two of them in a
  25-second window means the player moved. The `where:` line reads Silvermoon City — Falconwing
  Square for the whole run, but `context` is stamped **once at run start** (`docs/perf-analysis/README.md`,
  Schema), so it is evidence about arm A only and cannot testify that arm B ran in the same place.
  This is the most likely source of the inverted delta.
- **An 80-second gap between arms.** Arm A ended 13:18:35; arm B started recording 13:19:55. Not
  back-to-back at the same target.
- **Unequal durations** — 24.0 s vs 27.6 s, a 15% difference.
- **No reload landed inside the run.** The `[Init]` line at 13:18:04 is *not* a load: this addon
  emits its lifecycle summary on debug-enable rather than at login
  (`core/ConsumableMaster.lua:50-53`), and it sits one second after `[Debug] logging enabled`. Both
  arms ran under one continuous session.
- **Suspension is confirmed by the log**, not assumed: `addon SUSPENDED — inert` at 13:19:50 precedes
  arm B arming, and `addon RESUMED` at 13:20:27 follows arm B ending — and the resume genuinely took
  effect, since `[Calc] reason=perf_resume` fires immediately after it.
- **Solo, no group churn**, per `context.group`.
- **No frame limiter is visible.** The two arms sit at 15.04 and 15.15 ms/frame — close, but not
  identical and not on a round cap like 8.33 or 16.67 ms, so the client does not appear pinned.
  A ~66 fps ceiling on both arms is worth watching in the next capture: if it recurs exactly, a cap
  becomes the better explanation and the delta becomes uninterpretable by construction.

## What moved

**First capture — nothing to diff against; every figure above is a baseline reading.** The numbers
future captures should compare against, on ratios rather than raw totals: `cooldown` at
**1.78 ms/s**, **14.66 calls/s**, **0.1214 ms/call**, **0.2397 ms max**.

## Actions

1. **Take a capture that exercises `recompute`** — bag churn or a spec change inside an arm. Until
   one exists, the addon's only in-game evidence is the cooldown repaint, and `recompute`'s declared
   bucket (`core/PerfSetup.lua:109`) has never produced a number. New here; no existing issue or
   deviation covers it.
2. **Fix the stale `interface` field note** in `docs/perf-analysis/README.md`. It states that
   `interface` "reads `0` in every record, in-game ones included" because `GetAddOnMetadata` does not
   expose the TOC field. This record stamps **120007**, matching the TOC, so the lookup now works and
   the note is wrong in the direction that matters — it tells a reader to disregard a field that is
   correct. Corrected in the same change that filed this bundle.
3. **Repeat the A/B with the arms back-to-back at the same target**, no zoning between them, and
   with arm durations within a few seconds of each other. This capture's frame-time delta is
   unusable; a clean pair would at least establish where the floor sits for this machine. Note that
   even a clean pair is unlikely to resolve 0.027 ms/frame — the buckets remain the answer, and this
   is about characterising the instrument, not the addon.
4. **None on cost.** At 0.178% of combat wall time in the one path that runs at near-frame frequency,
   there is nothing here worth optimising.
