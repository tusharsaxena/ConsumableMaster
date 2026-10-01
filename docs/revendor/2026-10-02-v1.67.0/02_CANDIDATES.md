# Candidates (ConsumableMaster, LibKa0s v1.66.0 -> v1.67.0)

Listed, not interviewed: the 2026-10-02 census adoption (`01_DESIGN.md` D1, D2) already decides
each new surface for every host. Sources: the CHANGELOG v1.67.0 block and the version documents
under `../LibKa0s/docs/api/` at the tag.

## A. Delivered on the re-vendor alone (not offered)

- **Core 10, every existing `MakeResizable` caller unchanged.** The debug console and perf panel
  grips (library-built) pass none of the new fields and behave as on v1.66.0.
- **OptionsIdList 3's loaded-addon guard.** Latent here: this addon builds no `O.IdList`, so no help
  mark is drawn and the new rung is never asked.

## B. Host change required (candidates)

| # | What | Evidence | Files here | Taken by | Blast radius |
|---|---|---|---|---|---|
| B1 | Pass `addonName = addonName` on the Options descriptor, with `local addonName, NS = ...` | CHANGELOG v1.67.0, "OptionsIdList minor 3 and Options minor 28"; `docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`; LibKa0s#42 | `settings/OptionsSetup.lua:27`, its descriptor | **CA-CM-NM** (census adoption, D2) | Two tokens; no visible change today (no id list) |
| B2 | `MakeResizable` `canResize` / `onResizeStop` / `gripParent` | CHANGELOG v1.67.0, "Core minor 10"; `docs/api/Core/version-10-docs.md`, "The resize grip"; LibKa0s#41 | none: this addon owns no resize grip | **none** (D1's adopters are BankLedger, LootHistory and MultiMeters) | n/a |

## C. Whole-module adoption

None: the payload's majors are unchanged, and every one except `Pool` is consumed, as at v1.66.0.
