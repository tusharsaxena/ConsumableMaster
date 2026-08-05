# perf-runs/

Committed performance captures. One file per run, **flat** — no per-date subdirectories, because a
directory per run is a directory listing nobody reads and a path that breaks every link the moment a
run is re-labelled.

## Naming

```
<YYYY-MM-DD>-ingame-<label>.json
<YYYY-MM-DD>-offline-<label>.json
```

`<label>` is whatever `--label` (offline) or the panel's label field (in game) carried — a release
number, a branch name, `baseline`. Keep it short and keep it lowercase-with-hyphens.

## What a record contains

The shape is `LibKa0s-Perf-1.0`'s, and both sources encode it with the **same**
`KCM.Perf.EncodeJSON`, so one reader handles both. The library's own contract is the authority; this
is the summary a reader needs before opening a file.

| Field | Meaning |
|---|---|
| `schema` | the record schema number (`KCM.Perf.SCHEMA`) — bump means shape change |
| `addon` | `"ConsumableMaster"`; records are self-identifying so they can be pooled |
| `source` | `"ingame"` or `"offline"` |
| `version` | the addon version the run measured (`KCM.VERSION`) |
| `interface` | the client interface number, or `0` for an offline run (no client involved) |
| `timestamp` | epoch seconds |
| `label` | the run label |
| `buckets` | `{ [name] = { calls, totalMs, maxMs, … } }`, one entry per bracket or scenario |
| `fps` | `active` / `suspended` samples plus `deltaMsPerFrame` — the A/B answer. All zeros offline: there are no frames to sample |
| `failures` | assertion failures from an offline run; empty on a clean one |

A bucket with no `within` is a **top-level** total, safe to sum. Offline scenarios never carry
`within` — each is an entry point driven one at a time, timing only its own loop, so no scenario's
total is contained in another's.

## Reading two runs against each other

Compare `fps.deltaMsPerFrame` between in-game records, and `buckets.<name>.totalMs` per iteration
count between offline ones. Never compare an offline `totalMs` from one machine against another's:
the offline runner says so on every run, and it means it. The machine-independent figures are
`buckets.<name>.bytesPerIter` and the bucket call counts.

## Where they come from

* In game — `/cm perf` walks the A/B protocol and writes into the `ConsumableMasterPerfDB` ring;
  export from the panel and commit the file here.
* Offline — `lua5.1 tests/perf.lua --out docs/perf-runs/<date>-offline-<label>.json --label <label>`.

The automated-tests runner writes its own `perf.json` into the frozen bundle under
`docs/automated-tests/<stamp>/`. That is a **run record**, not a capture — leave it where it is and
do not copy it here.

Background, the bucket list and what the numbers mean: [../performance.md](../performance.md).
