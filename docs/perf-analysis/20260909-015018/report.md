# Perf report — 2026-09-09 01:46

What the client printed, copied out of the debug-log window after `/cm perf report` — which since
`LibKa0s-Perf-1.0` MINOR 10 prints the summary and the JSON dump in one step, the summary first and
the JSON last (`libs/LibKa0s/Perf.lua:1147`). The `HH:MM:SS | [Tag] ` prefixes are kept: they are
timestamps, and the gaps between the lifecycle lines are facts about the capture.

## The report

```
01:50:17 | [Perf] capture: 2026-09-09 01:46  (ConsumableMaster, schema 2, v1.5.0)
01:50:17 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:50:17 | [Perf] where:     Silvermoon City — The Bazaar
01:50:17 | [Perf] group:     solo
01:50:17 | [Perf] active:       58.6s    4152 frames    70.9 fps   14.11 ms/frame
01:50:17 | [Perf] suspended:    54.6s    3929 frames    72.0 fps   13.88 ms/frame
01:50:17 | [Perf] delta:                                                   +0.22 ms/frame
01:50:17 | [Perf] 
01:50:17 | [Perf] bucket            calls   total ms       ms/s    max ms
01:50:17 | [Perf] cooldown           1774     168.30      2.873     0.285
```

The report block ends at the `cooldown` row: this client printed no `(buckets nest: … — do not sum)`
footer, because no declared bucket in this addon carries a `within` and the library omits the note
when there is no nesting to warn about.

## The run log

The capture's provenance — how a later reader confirms both arms were combat-gated, that arm B
really was suspended, and what happened between the arms.

```
01:46:51 | [Perf] run started — 2026-09-09 01:46
01:46:51 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:46:51 | [Perf] where:     Silvermoon City — The Bazaar
01:46:51 | [Perf] group:     solo
01:46:51 | [Perf] perf run STARTED — 2026-09-09 01:46
01:47:22 | [Perf] experiment A armed (addon active) — waiting for combat
01:47:28 | [Perf] Experiment A RECORDING — combat started
01:48:27 | [Perf] Experiment A ENDED — 58.6s, 4152 frames, 70.9 fps
01:49:10 | [Perf] addon SUSPENDED — inert
01:49:10 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
01:49:19 | [Perf] Experiment B RECORDING — combat started
01:50:14 | [Perf] Experiment B ENDED — 54.6s, 3929 frames, 72.0 fps
01:50:16 | [Perf] run finished — A 58.6s / 4152 frames, B 54.6s / 3929 frames
01:50:16 | [Perf] addon RESUMED — events and frames restored
01:50:16 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```

Only `[Perf]` lines appear. Debug logging was **off** for this run — the library's own sink is the
ungated `DebugLog.AddLine` (`core/PerfSetup.lua:116`), while `[Scan]`, `[Calc]` and `[Init]` go
through the gated `KCM.Debug` — so the absence of scan and recompute lines here is a fact about the
debug flag, not evidence that nothing happened between the arms.

## The dump line, as pasted

The record itself is [`dump.json`](dump.json), byte for byte. Reproduced here with its log prefix
only so the paste's ordering is preserved.

```
01:50:18 | [Perf] {"addon":"ConsumableMaster","buckets":{"cooldown":{"calls":1774,"maxMs":0.2845,"totalMs":168.3019}},"context":{"character":"Sacrìlege","class":"Paladin","group":"solo","level":90,"realm":"Frostmourne","spec":"Protection","subZone":"The Bazaar","zone":"Silvermoon City"},"fps":{"active":{"avgFps":70.8847,"frames":4152,"msPerFrame":14.1074,"seconds":58.5740},"deltaMsPerFrame":0.2230,"suspended":{"avgFps":72.0230,"frames":3929,"msPerFrame":13.8844,"seconds":54.5520}},"interface":120100,"label":"2026-09-09 01:46","schema":2,"source":"ingame","timestamp":1788898818,"version":"1.5.0"}
```
