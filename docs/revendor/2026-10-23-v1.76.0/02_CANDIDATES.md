# Candidates (ConsumableMaster, LibKa0s v1.75.2 -> v1.76.0)

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0` (8 commits), the CHANGELOG `v1.76.0`
block at the tag, and `docs/api/Widgets/version-14.1.4.3.2-docs.md` and
`docs/api/Sim/version-2.3.5-docs.md` at the tag.

The run assigns ConsumableMaster no adoption (its owner scope and `items.json` give CM only this
re-vendor), so every new surface is listed and decided **not adopted** here, without an interview.

## A. Delivered on the re-vendor alone

- **Widgets minor 14**: nothing CM calls changed; the attach files re-pair on the new shell minor.
- **Sim 2.3.5** (SimTimeline 3, SimPanel 5: a simulation plays on its own, Run all removed):
  reaches no code path here, because CM does not consume `Sim-1.0`.

## B. New surfaces, not adopted

| Surface | Evidence | Decision | Reason |
|---|---|---|---|
| `W.TestStrip` `opts.kind = "sim"` and `strip.kind` | CHANGELOG v1.76.0, "Widgets minor 14"; `LibKa0s/Widgets.lua` `lib.TestStrip` | not adopted | CM hosts no test strip and no simulator; additive, no blast radius |

## C. Whole-module adoption

None offered. `Pool`, `Glow` and `Sim` ship unused, as before (`docs/revendor/2026-10-22-v1.75.0/02_CANDIDATES.md`);
v1.76.0 changes no premise of that.
