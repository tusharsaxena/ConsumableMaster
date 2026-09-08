# Analysis — 20260909-015018

- **Addon:** ConsumableMaster 1.5.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-09 01:46 local, label `2026-09-09 01:46`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Silvermoon City — The Bazaar · solo
- **Delta:** +0.2230 ms/frame — **unresolved below the floor**
- **Previous capture:** [`20260807-132029`](../20260807-132029/)

## Headline

Second in-game capture — a Protection Paladin, solo in Silvermoon City, two combat arms of 58.6 s
and 54.6 s — and the frame-time A/B again resolves nothing: +0.2230 ms/frame sits under the
±0.3 ms/frame floor, which is itself quoted for arms longer than either of these. The answer is the
buckets: `cooldown` cost **2.8733 ms per second of combat** against 1.7793 last time, a **+61%** rise
carried by drive rate — the repaint fired **30.29 times a second** against 14.66, while the cost of
one pass **fell 22%** to 0.09487 ms. At **0.29% of combat wall time** and **0.0405 ms/frame** there is
nothing to act on for cost, and `recompute` again never fired, which makes it two captures with no
in-game number.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 58.5740 | 4152 | 70.8847 | 14.1074 |
| suspended (addon inert) | 54.5520 | 3929 | 72.0230 | 13.8844 |
| **delta** | +4.022 (A longer) | +223 | −1.1383 | **+0.2230** |

The delta is **unresolved**. The ±0.3 ms/frame floor is quoted for a **60–80 s** A/B and the working
threshold is 0.5 ms/frame; +0.2230 is inside both. Note that **neither arm reaches that band** —
58.5740 s and 54.5520 s — and a shorter arm averages away less noise, so ±0.3 is a *lower bound* on
this run's resolution rather than its value; the unresolved verdict holds a fortiori. The only thing
worth saying about the sign is negative: the backwards-sign tell that flagged a moving environment in
`20260807-132029` — the suspended arm reading slower — is **absent here**. That is not evidence that
the number measures the addon. Writing "+0.22 ms/frame is what the addon costs"
would be wrong by a factor of 5.5: the buckets say the addon's own Lua ran **0.04054 ms/frame**
(168.3019 ms over 4152 frames). Whatever the other 0.18 ms/frame is, it is not this addon's Lua.

Arm durations differ by **4.02 s (7.4%)**, arm A being the longer. Combat gating equalises when an
arm opens, never how long it runs, and never what else is on screen. No frame limiter is visible:
14.11 and 13.88 ms/frame are neither identical nor on a round cap. The ~71 fps ceiling matches the
~66 fps of the first capture closely enough to look like the machine rather than a cap, but a third
capture landing on the same number would make a cap the better reading.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
58.5740 s, as [`report.md`](report.md) computes it. This addon declares no nesting, so the single
row **is** the total.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `cooldown` | 1774 | 168.3019 | 2.8733 | 0.2845 | none declared — top-level, safe to read as a total |
| `recompute` | — | — | — | — | none declared; **absent from the record — never fired** |

**Total accounted cost: 2.8733 ms per second of combat** — the single top-level bucket, nothing to
sum. Against the active arm that is 168.3019 ms of Lua in 58.574 s, **0.2873% of wall time**, or
**0.04054 ms/frame** across 4152 frames. The worst single pass, 0.2845 ms, is **2.0%** of one
14.11 ms frame; the tail sits at 3.0× the mean, so there is a spread but no pass that would drop a
frame.

The ratios that survive a change of combat duration:

- **30.29 calls/s** — 0.427 calls per frame, i.e. the repaint fires on about two frames in five.
- **0.09487 ms/call** — one walk over every bar button plus every shown flyout row.
- **0.2845 ms worst call.**

Neither declared bucket carries a `within` (`core/PerfSetup.lua:125-128`), so **this addon declares
no nesting** and there is no parent claim left unverified — the table is flat by construction, and
the client printed no "buckets nest" footer for that reason.

`recompute` is **absent from the record: it never fired in either arm.** That is now true of both
committed captures. It is consistent with the design — `P.Recompute` is driven by bag and item-info
churn (`core/ConsumableMaster.lua:168-191`), and a stationary solo pull in a capital city moves
nothing — but two for two means the declared bucket at `core/PerfSetup.lua:127` has still never
produced an in-game figure, and no document may cite one. This capture cannot even corroborate the
last one's inference from `[Calc]` lines, because debug logging was off and those lines are gated
(see [`report.md`](report.md), run log).

Why it costs what it costs: the bracket wraps `MB.RefreshCooldowns` whole
(`modules/MacroBar.lua:359-369`), and three facts set the number.

1. **What drives it.** `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` both land on
   `KCM:OnCooldownUpdate` (`core/ConsumableMaster.lua:575-576`), which forwards to the repaint
   whenever the bar is enabled (`core/ConsumableMaster.lua:485-489`). This is event-driven, not
   `OnUpdate`, so the call count is a property of *the player's rotation*, not of the addon. That is
   the whole story of the +107% rise in calls/s: the first capture was a Destruction Warlock, this
   one a Protection Paladin, a spec with far more short-cooldown and charge-based buttons ticking the
   event. The addon did not get chattier; the driver did.
2. **What one call does.** The loop walks every entry in `buttons` — created for **all 15 categories**
   (`defaults/Categories.lua:42`, `modules/MacroBar.lua:382-388`), not just the shown ones — and for
   each one calls `BB.RefreshCooldown` plus `FO.RefreshCooldowns` over that button's shown flyout rows
   (`modules/MacroBar.lua:361-368`). At 0.09487 ms per call over 15 slots that is about **6.3 µs per
   slot**, flyout rows included.
3. **What each slot pays.** `BB.RefreshCooldown` (`modules/MacroBarButton.lua:205-210`) resolves the
   pick through a table lookup — `MD.PickID` is a profile read, not a scan
   (`core/MacroDisplay.lua:35-40`) — then hits a client API per slot: `C_Item.GetItemCooldown` or
   `C_Spell.GetSpellCooldown` (`core/MacroDisplay.lua:102-128`). Every *active* item cooldown then
   allocates a fresh duration object via `C_DurationUtil.CreateDuration()`
   (`core/MacroDisplay.lua:108-112`), and `BB.ApplyCooldown` re-reads
   `KCM.MacroBarModel.Config()` and calls `SetDrawBling` on every frame it touches
   (`modules/MacroBarButton.lua:156-180`) before the alpha-curve evaluation. The GCD curve itself is
   built once and cached (`modules/MacroBarButton.lua:129-143`), so it is not in the per-call path.

**Is the work proportional to something that could grow?** Yes, in two directions, and both are
bounded today. Slot count is fixed at the 15 categories, so it cannot grow with the player's bags.
Flyout rows can: `FO.RefreshCooldowns` iterates the pooled entries and repaints every **shown** one
(`modules/MacroBarFlyout.lua:552-558`), so a player with a wide open flyout pays more per call than
this capture's did. Nothing in the record says how many rows were shown, which is the one thing a
future capture could usefully vary.

## What the capture did not hold constant

- **A 52-second gap between the arms.** Arm A ended 01:48:27; arm B began recording 01:49:19. Not
  back-to-back at the same target, though it is a third shorter than the first capture's 80 s gap.
- **Unequal arm durations** — 58.6 s vs 54.6 s, a 7.4% difference (down from 15% last time).
- **The environment between arms is unwitnessed.** Debug logging was off, so `[Scan]`, `[Calc]` and
  `[Init]` lines are gated out of the paste entirely. The first capture caught two zone changes
  between its arms only because those categories were printing. Here the log is `[Perf]`-only, so
  "nothing happened between the arms" is **not** something this run can claim — only that nothing the
  perf harness itself reports happened. If a future capture is meant to establish a clean pair, turn
  debug logging on first.
- **`context` is stamped once, at run start** (`docs/perf-analysis/README.md`, Schema), so
  "Silvermoon City — The Bazaar" is evidence about arm A. It cannot testify for arm B.
- **Suspension is confirmed by the log**, not assumed: `addon SUSPENDED — inert` at 01:49:10 precedes
  arm B arming, `addon RESUMED` at 01:50:16 follows arm B ending. A mid-run `/reload` **cannot be
  ruled out from this paste**: the one line that would have shown one is the `[Init]` lifecycle
  summary, which rides the `DebugLog.SetEnabled` seam (`core/ConsumableMaster.lua:55-58`,
  `core/DebugLogSetup.lua:9`) and is therefore gated off with debug off.
- **Solo throughout**, per `context.group`. A capital city means passers-by, which the record does not
  measure and which differ between two arms taken a minute apart.
- **Different character and spec from the previous capture** — Protection Paladin here, Destruction
  Warlock there. This is the dominant confound on every ratio in "What moved" below.

## What moved

Compared on `ms/s` and per-call ratios against [`20260807-132029/dump.json`](../20260807-132029/dump.json),
never on raw `totalMs` — that capture's arms were less than half as long.

| Figure | 20260807-132029 | this capture | change |
|---|---|---|---|
| `cooldown` ms/s | 1.7793 | 2.8733 | **+61.5%** |
| `cooldown` calls/s | 14.6599 | 30.2865 | **+106.6%** |
| `cooldown` ms/call | 0.12137 | 0.09487 | **−21.8%** |
| `cooldown` max ms | 0.2397 | 0.2845 | +18.7% |
| `cooldown` ms/frame | 0.02677 | 0.04054 | +51.4% |
| share of combat wall time | 0.178% | 0.287% | +0.109 pp |
| `recompute` | never fired | never fired | **unchanged — still no in-game figure** |
| frame-time delta | −0.1082 (inverted) | +0.2230 | **both unresolved**; the inverted-sign tell is absent this time |

The read: **the per-pass cost improved and the total got worse, because the event rate doubled.**
The **bracketed path** is byte-for-byte unchanged between the two captures — `git diff f304efa..HEAD`
leaves `MB.RefreshCooldowns` (`modules/MacroBar.lua:359-369`), `BB.RefreshCooldown`
(`modules/MacroBarButton.lua:205-210`), `BB.ApplyCooldown` (`modules/MacroBarButton.lua:156-203`),
`FO.RefreshCooldowns` (`modules/MacroBarFlyout.lua:552-558`) and the whole of `core/MacroDisplay.lua`
identical — so the +61% is the driver, not a regression **in the measured path**. The rest of the
addon is a different matter and the comparison does not cover it: 64 commits sit between f304efa (the
commit that recorded capture 1) and HEAD, touching `core/ConsumableMaster.lua`, all three MacroBar
modules, `core/MacroBarModel.lua` and the measuring instrument itself — `libs/LibKa0s/Perf.lua`,
re-vendored from `LibKa0s-Perf-1.0` MINOR 7 to MINOR 10. `version` reads 1.5.0 in both records only
because no bump ran, not because the code is identical. The −22% on ms/call is the figure that would
carry a change to the bracket if there were one; there isn't, so treat it as spec-to-spec variance
in how many slots hold an *active* cooldown (an active one allocates a duration object and runs the alpha curve; an inactive
one takes the `cd:Clear()` early return at `modules/MacroBarButton.lua:181-184`). A Protection
Paladin's consumable slots are likely more often idle than a Warlock's mid-pull.

The client interface stamped in the record moved from **120007 to 120100** — that field is
`GetBuildInfo`'s fourth return, i.e. the **client**, not the TOC (`libs/LibKa0s/Perf.lua:163-179`).
The TOC still declares `## Interface: 120007`. That is not a record mismatch; it is the addon
lagging the live client by one build.

## Actions

1. **Take a capture that exercises `recompute`.** Two captures, zero calls. Bag churn or a spec
   change inside an arm would do it. Until one exists the addon's in-game evidence covers exactly one
   path, and `core/PerfSetup.lua:127` declares a bucket nothing has ever measured. Carried forward
   from [`20260807-132029/ANALYSIS.md`](../20260807-132029/ANALYSIS.md) action 1, still open.
2. **Turn debug logging on before the next run.** This capture cannot say what happened between its
   arms, and that is the single cheapest thing to fix — the first capture's inverted delta was
   diagnosed only because `[Scan]` lines were in the paste. New here.
3. **Bump `## Interface` to 120100.** The record says the client is on 120100; the TOC declares
   120007 (`ConsumableMaster.toc:1`). `/wow-addon:bump-interface` owns this. New here — not a perf
   finding, but the capture is what surfaced it.
4. **Correct the `interface` field note in `docs/perf-analysis/README.md`.** It still says the field
   "stamps the addon's `## Interface` TOC field". The library reads `GetBuildInfo`
   (`libs/LibKa0s/Perf.lua:175-179`), so it is the *client's* number, and this record — 120100 against
   a TOC of 120007 — is the case that distinguishes them. Corrected in the same change that filed
   this bundle.
5. **None on cost.** 0.287% of combat wall time and 0.041 ms/frame in the one path that runs at
   near-frame frequency. If a future capture ever makes this worth touching, the two candidates are
   already visible and both are refactors, not fixes: hoist the per-slot
   `KCM.MacroBarModel.Config()` read out of `BB.ApplyCooldown` into a per-pass argument
   (`modules/MacroBarButton.lua:160` — saves 15+ table walks per call, risks a stale config if a
   settings change lands mid-pass), and skip `FO.RefreshCooldowns` for buttons whose flyout is not
   shown before entering the row loop (`modules/MacroBar.lua:366` — saves a function call and a
   `flyout.entries` walk per hidden slot, risks nothing but is worth roughly nothing at these
   numbers). Neither is justified by 0.09 ms per call; they are recorded so the next reader does not
   have to re-derive them.
