# 02 — Candidates: LibKa0s v1.30.0 (kit revision 16)

Sources, in order: `git -C ../LibKa0s log --oneline v1.29.0..v1.30.0`, the `CHANGELOG.md`
v1.30.0 block, and `docs/api/testkit/version-16-docs.md`. No `LibKa0s/` minor moved, so there
is no `docs/api/<Major>/` document to diff; every item below is a **kit** change.

## Class A — reached this addon on the re-vendor alone

| Item | Evidence | What happened here |
|---|---|---|
| `vendor_sync.lua` runner-mode case (LibKa0s #28) | `CHANGELOG.md` v1.30.0, "Kit revision 16, `vendor_sync.lua`" | `VendorSync.register` now adds `the automated-test runner is recorded executable (100755)`. `tests/test_vendor_sync.lua` calls `register` unchanged, so the case arrived with the copy and **passes**: `git ls-files -s tests/_kit/run-automated-tests.sh` reports `100755`. The suite moves **796 → 797**, the +1 the changelog measured for this repo. |

## Class B — would need a host change, but not a host-code one

The other three kit fixes land on the kit's own Ace fakes in `tests/_kit/mock_base.lua`. This
repo's harness does not use those fakes. `tests/wow_mock.lua`'s `M.install` puts its own
libraries in the `LibStub` table: `makeAceAddon(NS)` (`tests/wow_mock.lua:352`, installed at
`:538`), `makeAceEvent()` (`:395`, installed at `:539`), `makeStub()` for AceConsole (`:540`) and
its own AceGUI table (`:568`). The kit fixes therefore **cannot reach this suite**, and there was
never a local shim for any of them to replace.

| Item | Evidence | Why it is inert here | Recommendation |
|---|---|---|---|
| `AceGUI:Release` + `widget:Release` (#27) | `CHANGELOG.md` v1.30.0, "`AceGUI:Release` (#27)" | wow_mock's AceGUI has no `Release`; its catch-all `__index` turns `AceGUI:Release(w)` into a silent no-op. No addon source calls `Release(` today | **Decline — harness migration** |
| AceEvent event half on an Embed, recorded and validated `RegisterEvent` / `UnregisterEvent` / `UnregisterAllEvents` (#29) | `CHANGELOG.md` v1.30.0, "AceEvent's event half on an embed (#29)" | wow_mock's `NewAddon` stamps a no-op `RegisterEvent` (`tests/wow_mock.lua:358`) and no `UnregisterAllEvents`; its Embed (`embedMessaging`, `:375`) has the message half only. So `core/PerfSetup.lua:57`'s guarded `KCM:UnregisterAllEvents()` is silently skipped headlessly, and a misspelled handler name would not raise | **Decline — harness migration** |
| `NewAddon` stamps `Printf` beside `Print` (#30) | `CHANGELOG.md` v1.30.0, "`Printf` beside `Print` (#30)" | AceConsole is `makeStub()`; nothing stamps `Print` or `Printf`. The addon calls neither (chat goes through `KCM.Say`), so there is nothing to clobber today | **Decline — harness migration** |

**Blast radius, if taken:** replacing, not additive. Moving onto the kit's `NewAddon`, AceEvent
and AceGUI means deleting wow_mock's three builders and rewiring what reads their shapes:
`tests/test_settingsui.lua:1039-1045` and `:1467-1478` read each widget's `__text`, which is
wow_mock's field (the kit stores `.text`), and wow_mock's bus registry `M.busReg` dispatches
string-method handlers that the kit's private bus shapes differently. That is a harness
migration with its own characterization pass, not a re-vendor step.

## Class C — whole-module adoption

None new. `Pool` stays vendored and unconsumed; this release did not touch it.
