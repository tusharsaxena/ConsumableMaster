# Perf report — 2026-08-07 13:17

What the client printed, copied out of the debug-log window after `/cm perf report` and
`/cm perf dump`. The `HH:MM:SS | [Tag] ` prefixes are kept: they are timestamps, and the gaps
between the lifecycle lines are facts about the capture.

## The report

```
13:20:28 | [Perf] capture: 2026-08-07 13:17  (ConsumableMaster, schema 2, v1.5.0)
13:20:28 | [Perf] who:       Lânfear-Frostmourne, level 90 Destruction Warlock
13:20:28 | [Perf] where:     Silvermoon City — Falconwing Square
13:20:28 | [Perf] group:     solo
13:20:28 | [Perf] active:       24.0s    1596 frames    66.5 fps   15.04 ms/frame
13:20:28 | [Perf] suspended:    27.6s    1821 frames    66.0 fps   15.15 ms/frame
13:20:28 | [Perf] delta:                                                   -0.11 ms/frame
13:20:28 | [Perf] 
13:20:28 | [Perf] bucket            calls   total ms       ms/s    max ms
13:20:28 | [Perf] cooldown            352      42.72      1.779     0.240
```

## The run log

The capture's provenance — how a later reader confirms both arms were combat-gated, that arm B
really was suspended, and what happened between the arms.

```
13:17:25 | [Perf] run started — 2026-08-07 13:17
13:17:25 | [Perf] who:       Lânfear-Frostmourne, level 90 Destruction Warlock
13:17:25 | [Perf] where:     Silvermoon City — Falconwing Square
13:17:25 | [Perf] group:     solo
13:17:25 | [Perf] perf run STARTED — 2026-08-07 13:17
13:18:04 | [Debug] logging enabled
13:18:04 | [Init] Consumable Master v1.5.0, schema v2, profile 'Default'
13:18:05 | [Perf] experiment A armed (addon active) — waiting for combat
13:18:11 | [Perf] Experiment A RECORDING — combat started
13:18:35 | [Perf] Experiment A ENDED — 24.0s, 1596 frames, 66.5 fps
13:19:18 | [Scan] reason=player_entering_world scanned 15 items, 0 new. Scanned=[6948,50259,63206,64399,109253,180653,224464,241305,241327,243733,244639,246951,264507,267051,268650]. New=[]
13:19:18 | [Scan] reason=bag_update_delayed scanned 15 items, 0 new. Scanned=[6948,50259,63206,64399,109253,180653,224464,241305,241327,243733,244639,246951,264507,267051,268650]. New=[]
13:19:18 | [Calc] reason=unknown rewrote 0/15 (skipped 15)
13:19:43 | [Scan] reason=player_entering_world scanned 15 items, 0 new. Scanned=[6948,50259,63206,64399,109253,180653,224464,241305,241327,243733,244639,246951,264507,267051,268650]. New=[]
13:19:43 | [Scan] reason=bag_update_delayed scanned 15 items, 0 new. Scanned=[6948,50259,63206,64399,109253,180653,224464,241305,241327,243733,244639,246951,264507,267051,268650]. New=[]
13:19:44 | [Calc] reason=unknown rewrote 0/15 (skipped 15)
13:19:50 | [Perf] addon SUSPENDED — inert
13:19:50 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
13:19:55 | [Perf] Experiment B RECORDING — combat started
13:20:23 | [Perf] Experiment B ENDED — 27.6s, 1821 frames, 66.0 fps
13:20:27 | [Perf] run finished — A 24.0s / 1596 frames, B 27.6s / 1821 frames
13:20:27 | [Perf] addon RESUMED — events and frames restored
13:20:27 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
13:20:27 | [Calc] reason=perf_resume rewrote 0/15 (skipped 15)
```

## The dump line, as pasted

The record itself is [`dump.json`](dump.json), byte for byte. Reproduced here with its log prefix
only so the paste's ordering is preserved.

```
13:20:29 | [Perf] {"addon":"ConsumableMaster","buckets":{"cooldown":{"calls":352,"maxMs":0.2397,"totalMs":42.7227}},"context":{"character":"Lânfear","class":"Warlock","group":"solo","level":90,"realm":"Frostmourne","spec":"Destruction","subZone":"Falconwing Square","zone":"Silvermoon City"},"fps":{"active":{"avgFps":66.4695,"frames":1596,"msPerFrame":15.0445,"seconds":24.0110},"deltaMsPerFrame":-0.1082,"suspended":{"avgFps":65.9950,"frames":1821,"msPerFrame":15.1527,"seconds":27.5930}},"interface":120007,"label":"2026-08-07 13:17","schema":2,"source":"ingame","timestamp":1786089029,"version":"1.5.0"}
```
