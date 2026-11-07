# Plan: ConsumableMaster on WoW Forever, step 1

Spec: `docs/superpowers/specs/2026-11-08-forever-port-design.md`. Branch `feat/2026-11-08-forever-port`. Each step
ends green under both kit profiles (`lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`, through
`ka0s-bounded`) and luacheck 0/0. This repo's `CLAUDE.md` forbids staging or committing outside a commit slash
command, so the work is committed by the lead with `/dev-copilot:commit`, with subjects naming the step ids
they carry (`CM-F1 + CM-F2: …`).

| Step | What | Done when |
|---|---|---|
| CM-F1 | Re-vendor LibKa0s v1.94.0; the default skin per client | vendor diff empty; default pinned per profile |
| CM-F2 | Per-client seed selection: Retail's lists, Forever's empty by decision | no Retail item ID is a Forever candidate (test) |
| CM-F3 | `clients` on category rows; LIST/BY_KEY filtered at load; every Retail-only path guarded | Forever's list is exactly 15 keys; absent keys have no macro, schema row, page, slot or verb (tests) |
| CM-F4 | ELIXIR, BANDAGE, SCROLL, PROT_POT: rows, matchers, rankers, tooltip parsing | characterization tests on Forever-shaped items |
| CM-F5 | Forever subclasses: Draught as Potion, temporary and item enhancement as weapon enchant, vanilla weapon wording | tests |
| CM-F6 | The port shape: TOC, README, DEPENDENCIES, ARCHITECTURE per-client table, gate docs, smoke, inventory | docs gate green |
| CM-F7 | Roster row flip (WowAddonStandards, its own commit) | `check-standard.sh` passes |

Smoke is the owner's. Claude marks nothing passed. Nothing is pushed, merged or version-bumped without the owner.
