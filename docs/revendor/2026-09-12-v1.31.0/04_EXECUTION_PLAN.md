# 04 — Execution plan: the harness migration (#38)

## Files

`tests/wow_mock.lua`, `tests/run.lua` (one SUITES entry), `tests/test_harness.lua` (new),
`tests/test_bus.lua`, `core/Bus.lua`, `docs/testing.md`, `docs/test-cases.md`, `README.md` (badge).

## Characterization first

Seven cases in `tests/test_harness.lua` were written against the old harness and passed there
(831/831). They pin what the migration had to keep:

- the addon object is `_G.KCM` and is the namespace;
- `AceGUI:Create` hands back the permissive widget (`label` / `text` FontStrings, `__text` /
  `__label` recorders) and logs it in `__created`;
- `GetWidgetVersion` answers 0 for an unregistered type;
- `LibStub` answers nil for an unknown major, silent flag or not;
- the LibSharedMedia fake's `List` / `HashTable` / `Fetch`;
- a string-method bus registration calls the target's method;
- `OnEnable` registers every game event without raising.

## Swaps, one library at a time, full suite after each

| Step | Change | Suite |
|---|---|---|
| 0 | Registry on the kit's `__libs`; `_G.LibStub` a lenient wrapper over the kit's | 831 / 831 |
| 1 | AceConsole: the kit's | 831 / 831 |
| 2 | AceGUI: the kit's, with `Create` and `GetWidgetVersion` wraps | 831 / 831 |
| 3 | AceEvent: the kit's; `M.busReg` / `embedMessaging` deleted | **823 / 831** |
| 3a | `core/Bus.lua` handler fixed to `fn(message, reason)`; `test_bus` handler likewise | 831 / 831 |
| 4 | AceAddon: the kit's, with a `NewAddon` wrap publishing `_G.KCM` | 831 / 831 |

Step 3's eight failures had one cause. CallbackHandler calls a function handler registered with no
arg as `fn(message, ...)` (`libs/CallbackHandler-1.0/CallbackHandler-1.0.lua:121`, `:54`). The old
harness called `fn(target, message, ...)`, and `core/Bus.lua`'s RECOMPUTE handler was written to that
shape. So in the client every bus-routed recompute lost its reason and ran as "unknown". The
migration caught it; the fix is one parameter.

## Assertions that prove the kit now arrives

Three cases, red on the old harness (verified by running this tree with `HEAD`'s `wow_mock.lua` and
`Bus.lua` restored):

- `KCM:Printf("%d left", 3)` renders `|cff33ff99ConsumableMaster|r: 3 left`, and `GetAddon` answers
  by name (kit 16's Printf, 17's AceConsole embed);
- after `KCM:OnEnable()`, `KCM.__events` records `OnBagUpdateDelayed`, `__fireEvent` reaches it, and
  `KCM.Perf.Suspend()` empties the registrations through `core/PerfSetup.lua:57`'s
  `UnregisterAllEvents` (kit 16's event half, 17's `__fireEvent`);
- `AceGUI:Release` marks and lists the widget, and a second release raises (kit 16's Release).

## Commit boundary

One commit for #38: f23ef2b. Suite 824 → 834; `luacheck .` 0 / 0 in 103 files.
