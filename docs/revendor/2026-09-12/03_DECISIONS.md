# 03 — Decisions

Taken by the owner on 2026-09-12 for the collection-wide v1.30.0 rollout, and applied here
non-interactively.

| Candidate | Decision | Reason |
|---|---|---|
| #28 runner-mode case | **Delivered** (class A) | Arrived with the copy; passes |
| #27 `AceGUI:Release` | **Declined — not now** | Harness migration: `tests/wow_mock.lua` replaces the kit's AceGUI wholesale, so the kit fix cannot reach this suite |
| #29 AceEvent event half | **Declined — not now** | Harness migration: `tests/wow_mock.lua` replaces the kit's AceAddon and AceEvent wholesale |
| #30 `NewAddon` `Printf` | **Declined — not now** | Harness migration: `tests/wow_mock.lua` replaces the kit's AceAddon and stubs AceConsole |

**No shim was deleted**, because none existed: nothing in `tests/wow_mock.lua` patches a kit
gap. It replaces the libraries outright.

**The three declines are one issue, not yet filed.** This run was told not to file GitHub
issues. The decline is returned to the owner as a proposed issue: migrate `tests/wow_mock.lua`
off its own AceAddon, AceEvent, AceConsole and AceGUI onto the kit's, so kit revisions reach this
suite. It is `state:triaged` in substance (worth doing, not today), severity low.
