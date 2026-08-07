# perf-analysis/

**In-game captures only.** A human runs `/cm perf` in a live client, plays a fight twice and copies
the result out of the game; no script can produce one of these, which is why the store exists at all.
**Offline** scenario runs (`lua tests/perf.lua`) are driven by the automated-tests runner and live in
the bundle for the run that produced them, under [`../automated-tests/`](../automated-tests/)
(`automated-tests-§7`). Nothing offline is ever filed here.

This directory is **standing and cumulative** — not tied to one investigation — so captures compare
across addon versions. Records are committed as **evidence**: the raw capture outlives the write-up
that interprets it, and an interpretation without its record is an assertion (`performance-§8`).

Background — the model, the declared buckets, what the numbers mean:
[../performance.md](../performance.md).

## Naming

One **frozen dated bundle per capture**:

```
docs/perf-analysis/<YYYYMMDD-HHMMSS>/
```

The stamp is **local time, derived from the record's own `timestamp` field** (epoch seconds) — when
the capture *happened*, not when it was written up, so a run analysed a week later still sorts
against its neighbours.

This replaced a flat pile of `<YYYY-MM-DD>-ingame-<label>.json` files. A bundle keeps a record and
its reading in one place, so neither can be moved or lost without the other, and the directory name
is derived from the record rather than from a label somebody might revise — so it never needs
re-naming to stay correct.

## The three artifacts

Each bundle carries exactly three files, and no others:

| File | What it is |
|---|---|
| `report.md` | what the client printed — the `[Perf]` summary block, plus the run's lifecycle log lines (`run started`, `armed`, `RECORDING`, `ENDED`, `SUSPENDED`, `RESUMED`) under their own heading |
| `dump.json` | the schema-2 record, **verbatim** |
| `ANALYSIS.md` | the write-up, following the uniform prompt in the standards repo's root `PERF_ANALYSIS.md` playbook |

The lifecycle log is kept because it is the capture's provenance: it is how a later reader confirms
both arms were combat-gated, that arm B really was suspended, and that no `/reload` landed between
the arms. The report itself records none of that.

`dump.json` is the emitted line **byte for byte** — one line, keys as sorted, figures as encoded. Not
pretty-printed, not re-keyed, not rounded, not stripped of a field that looks wrong. The library
emits sorted keys precisely so two records diff cleanly, and the encoder's quirks are part of the
record's identity. Read it with `jq`; never write it with one.

Bundles are **frozen once written** and are never pruned. If a reading turns out to be wrong, the
*next* capture's `ANALYSIS.md` says so — the old one is not edited.

## Schema

The shape is `LibKa0s-Perf-1.0`'s, defined and versioned in the library rather than here, so one
reader handles a record from any Ka0s addon. ConsumableMaster emits **schema 2**
(`libs/LibKa0s/Perf.lua`, `lib.SCHEMA`). The field-by-field contract is the authority:
[LibKa0s docs/record-schema.md](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/record-schema.md).
What follows is the orientation summary a reader needs before opening a file.

| Field | Meaning |
|---|---|
| `schema` | the record schema number — a bump means the shape changed |
| `addon` | `"ConsumableMaster"`; records are self-identifying so they can be pooled |
| `source` | `"ingame"` here, always; `"offline"` records belong to `../automated-tests/` |
| `version` | the addon version the run measured (`KCM.VERSION`) |
| `interface` | the client interface number — reads `0`, see the field notes |
| `timestamp` | epoch seconds; the bundle's directory name is stamped from this |
| `label` | the run label — what was measured, not what was concluded |
| `context` | character, realm, level, class, spec, zone, subZone, group, stamped once at the start of the run |
| `buckets` | `{ [name] = { calls, totalMs, maxMs, within? } }`, one entry per declared bracket |
| `fps` | `active` / `suspended` samples plus `deltaMsPerFrame` — the A/B answer |

The two declared buckets are `cooldown` and `recompute` (`core/PerfSetup.lua`). A bucket with no
`within` is a **top-level** total, safe to sum; buckets that nest are not — never sum a parent with
its children.

Object keys are emitted in sorted order so two records diff cleanly.

## Field notes

- **`fps.deltaMsPerFrame`** has a resolution floor. The run-to-run spread of a 60–80 s A/B sits at
  roughly **±0.3 ms/frame**, so treat anything below about **0.5 ms/frame** as *unresolved* rather
  than as zero. Below the floor, "no measurable impact" is a statement about the instrument wearing
  the clothes of a statement about the addon. The **buckets** measure this addon's own code directly
  and are the answer. A delta whose sign is backwards — the suspended arm reading *slower* — says the
  environment moved between the arms.
- **`fps.deltaMsPerFrame`** reads `0` unless **both** arms were sampled; with one arm empty a
  subtraction would report the whole frame time as the addon's cost.
- **`buckets[*].totalMs`** is Lua execution time only.
- **`interface`** stamps the addon's `## Interface` TOC field, and in the first committed capture it
  reads `120007` — matching the TOC. An earlier note here claimed it reads `0` in every record
  because `GetAddOnMetadata` does not expose the field; the record below disproves that, so treat a
  `0` as the exceptional case (an older client build, or a record from before the lookup worked)
  rather than the rule. It is still not the *client* version — it is what the addon declared it
  builds against.
- **Encoder wart:** Lua has a single table type, so an **empty** list and an empty map are
  indistinguishable to the encoder and both come out as `{}`. An empty `failures` therefore emits as
  `{}`, not `[]`. Non-empty lists encode as proper arrays.
- **Frame limiters are not recorded**, and a pinned client produces an unusable delta the record
  cannot flag. Judge that from the arms: two arms at the same frame time, or at a round one like
  8.33 ms, means the client was capped.

## How a capture is taken

```
/cm perf
```

opens the library's step panel, which offers only the next legal step of the A/B protocol: one fight
with the addon live, one with it suspended. At the end of the run:

```
/cm perf report      # the summary a human reads  -> report.md
/cm perf dump        # one line of JSON, the record -> dump.json
```

then the debug window's **Copy** button (`Ctrl+C`, `Esc`). One paste carries both, plus the
lifecycle lines. Both halves are required — a report without its dump is an interpretation with no
evidence, and a dump without its report is evidence nobody has read.

The same record is also on disk after a `/reload`, in the `ConsumableMasterPerfDB` ring (the last 10
runs) inside `_retail_/WTF/Account/<ACCOUNT>/SavedVariables/ConsumableMaster.lua`. WoW names that
file after the **addon**, not after the globals it declares, so `ConsumableMasterDB` and
`ConsumableMasterPerfDB` share it. The perf ring is a separate top-level global on purpose, so a
profile copy, reset or switch never touches it.

The write-up is produced by `/wow-addon:perf-analysis`, which splits the paste, validates the record
against the repo and the TOC, stamps the bundle and writes `ANALYSIS.md`.

## Capture index

One capture committed. Newest last.

| Stamp | Version | Label | What it measured |
|---|---|---|---|
| [`20260807-132029`](20260807-132029/) | 1.5.0 | `2026-08-07 13:17` | First in-game baseline — solo, Silvermoon City, two ~25 s combat arms. `cooldown` at **1.78 ms/s** (0.027 ms/frame, 0.18% of combat wall time); `recompute` never fired. Frame-time delta **unresolved** (−0.11 ms/frame, sign inverted — the player zoned between the arms). |

**Only `cooldown` has an in-game number.** The `recompute` bucket has not fired in any committed
capture, so no doc may cite an in-game figure for it until one does
([20260807-132029/ANALYSIS.md](20260807-132029/ANALYSIS.md), Actions).
