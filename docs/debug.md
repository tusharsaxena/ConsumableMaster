# Debug & diagnostics

The debug console, the dump targets, and the schema-driven slash CLI. All chat output is prefixed with the cyan `|cff00ffff[CM]|r` tag (`KCM.PREFIX`) — no raw `print(...)` calls.

## Toggle the debug console

`/cm debug on|off` drives `KCM.State.debug` (declared in `core/State.lua`) through the single `KCM.DebugLog.SetEnabled(on)` seam; **bare `/cm debug` toggles the console window only, leaving the flag untouched** (so capture can be armed independently of whether the window is open). The flag is **session-only** — default off, **never persisted**, and it resets to off on every login — so a session left with debug on doesn't leak into the next one. There is no `db.profile.debug`, no `debug` schema row, and no `Settings.Helpers.SetAndRefresh("debug")` path. Calls to `KCM.Debug(tag, fmt, ...)` early-return when the flag is off, so unconditional calls are safe.

The console window is drawn by **`LibKa0s-DebugLog-1.0`** (`libs/LibKa0s/DebugLog.lua`); `core/DebugLogSetup.lua` is the addon's half of it, supplying the font, the flag's home, the `[Init]` content, the printer and the panel repaints, and publishing the flat `KCM.DebugLog.*` surface. What lands on screen is a `ScrollingMessageFrame` inside `ConsumableMasterDebugWindow`, rendered in JetBrains Mono (registered through LibSharedMedia), wearing the shared **Ka0s window edge** the library owns (`Core.SKIN`, applied through `Core.ApplySkin`): a flat 1px black outer border with a 1px light-gray highlight synthesized just inside it, a gold title, a gray divider under the title bar, a near-black fill and flat text buttons. That edge is **not** this addon's own look and is not overridden here — `core/DebugLogSetup.lua` deliberately passes no `skin`, so the console draws whatever the vendored library draws, which is what makes two Ka0s consoles sitting side by side read as one suite of addons rather than two. The Ka0s Standard specifies those values normatively (`standalone-windows`), so a change to them is a re-vendor, never an edit here. The bundled JetBrains Mono default is **standard-compliant, not a deviation**: the Ka0s Standard's `debug-logging-§2` *requires* a shipped monospace font for the debug console and names JetBrains Mono (Regular, OFL) as the reference font — a fixed-width font is needed for the aligned `<HH:MM:SS> | [tag] …` columns and Blizzard ships no monospace font object, so the standard marks the shipped console font a **sanctioned styling exception** an audit MUST NOT flag. It is not user-configurable and there is intentionally no LSM picker; the fallback on an LSM fetch failure is Blizzard's `Fonts\ARIALN.TTF`. See [scope.md → Resolved decisions](./scope.md#resolved-decisions). The title bar carries a left-aligned **Debug: ON/OFF** state toggle (green ON / red OFF) plus Copy / Clear / close; **Copy** opens a separate read-through window for `Ctrl+C`. `core/Debug.lua` routes diagnostics into it:

```lua
KCM.Debug.IsOn()      -- bool; reads the flag (DebugLog.IsEnabled, else State.debug)
KCM.Debug(tag, fmt, ...)        -- callable sink: gated, secret-safe line to the console
                                -- read side only: core/Debug.lua publishes no Toggle,
                                -- because SetEnabled below is the single write path (§5)

KCM.DebugLog.SetEnabled(on) / IsEnabled() / Toggle()   -- Toggle flips the flag
KCM.DebugLog.AddLine(tag, msg) / Clear()
KCM.DebugLog.Show() / Hide() / Toggle_Window() / IsWindowShown() / ShowCopy()
KCM.DebugLog.RefreshHeader() / UpdateScrollBar() / UpdateStatus()   -- header + scrollbar + line counter (§11)
KCM.DebugLog.FormatPlain(ts, tag, msg) / FormatColored(ts, tag, msg)   -- pure formatters (the library's)
KCM.DebugLog.instance                                                  -- the library instance itself
```

Every `KCM.DebugLog.*` name above is a thin forwarder onto that instance. The copy
window's frame globals are the library's — `ConsumableMasterDebugCopyWindow` and
`ConsumableMasterDebugCopyScroll` (they used to be `…DebugWindowCopy` /
`…DebugWindowCopyScroll`); the main window's global is unchanged.

`KCM.Debug` is gated on `KCM.State.debug` as its first, zero-alloc statement, and every vararg is passed through `KCM.SafeToString` before formatting — so it's safe to call unconditionally and format placeholders are always `%s` (never `%d`/`%f`, since a combat "secret" value must never hit a numeric formatter). It writes to the **console**; chat is a fallback only when the console frame is unavailable.

### Tags

Functional-area tags in use today:

- `Init` — session summary emitted on debug-**enable** (addon + version, schema version, active profile), right after the `[Debug] logging enabled` bracket so a pasted log self-identifies (debug-logging-§5/§8). The addon supplies the line's content (`initSummary`); the library owns when it is emitted
- `DB` — schema migration, only logged when one actually runs
- `Scan` — auto-discovery pass summary (reason in content)
- `Calc` — recompute pass summary (reason + rewrote/total/skipped)
- `Macro` — exceptional macro events (combat-deferred, byte-limit, `EditMacro` failure, flush drop/apply)
- `GC` — stale-discovered sweep
- `Set` — settings write at `Helpers.Set`
- `Prio` — priority-list mutations (add/block/move) and category/all resets
- `Bar` — macro-bar events worth noticing, today just a flyout truncated by `macroBar.flyoutMax` (never a silent cap)

Every settings change logs once as `[Set] <path> = <value>` at `Helpers.Set`; repeating passes (auto-discovery, recompute) coalesce to one `[Scan]` / `[Calc]` summary line per pass instead of one line per item.

The `DebugLog.SetEnabled` seam prints a **color-coded** chat ack through `KCM.Say` — `debug logging |cff40ff40ON|r` (green) / `|cffff4040OFF|r` (red) — matching the title-bar `Debug: ON/OFF` toggle so the flag reads identically in chat and on the console (debug-logging-§5).

Don't introduce raw `print(...)` calls. Three sanctioned output paths:

- `KCM.Say(fmt, ...)` (`core/CoreSetup.lua`, built on `LibKa0s-Core-1.0`) — the single secret-safe chat seam for all one-shot output: slash lines, dump rows, help, and one-shot warnings (oversized macro body, give-up notice on flush failure, etc.). Always prepends `[CM]`; pass a finished string or a format string + args that each get secret-stringified. `core/SlashCommands.lua`'s `say` is just `local say = KCM.Say`.
- `KCM.Debug(tag, ...)` — gated diagnostics into the console.
- The only literal `print(...)` in the addon is `KCM.PREFIX` embedded in generated macro-body `/run print(...)` strings (`modules/MacroManager.lua`, `defaults/Categories.lua`) — that runs in the player's macro, not the addon.

## Dump internals

`/cm dump <target>` — inspect runtime state. `DUMP_TARGETS` in `core/SlashDump.lua` is the single source of truth; adding a row (plus its `DUMP_ORDER` name) makes it appear in `/cm dump` help automatically.

| Target | What it shows |
|--------|---------------|
| `categories` | The full `KCM.Categories.LIST` with macro name, display name, spec-awareness flag. |
| `statpriority` | Current spec's stat priority (primary + ordered secondary), with classID / specID / specKey. |
| `bags` | `BagScanner.Scan()` output as `itemID = count`. |
| `item <id>` | Parsed tooltip fields for the item plus the raw tooltip lines (pattern-debugging view). Shows `pending: tooltip data not yet loaded` if the data hasn't hydrated yet. |
| `pick <catKey>` | The effective priority list with per-entry Ranker scores, an `[owned]` tag for entries you actually have, and a `<-- pick` marker on the winner. Composite catKeys (`hp_aio` / `mp_aio`) print the configured order, per-sub-cat picks, and the assembled macro body. |

`<catKey>` is case-insensitive (`flask`, `FLASK`, `hp_aio` all work).

## Measure what the addon costs (`/cm perf`)

`/cm perf` opens a seven-step panel driving `LibKa0s-Perf-1.0` (`core/PerfSetup.lua`). It is an **A/B capture**, not a profiler: you pull once with the addon live and once with it suspended, and it reports the difference in ms-per-frame.

The protocol, in order: **start** → **measure A** → pull → **measure B** → pull → **finish** → **report** (or **dump** for one line of JSON to paste into an issue). Recording opens automatically when combat starts and closes when it ends; Blizzard's own Stopwatch is driven as the on-screen indicator, so it will appear during a run.

Two things worth knowing before you run one:

- **During arm B the addon is deliberately inert** — every event is unregistered and the macro bar is hidden. `finish` and `cancel` both restore it; nothing else does. If you walk away mid-run the addon stays quiet until you run one of them or `/reload` (the state is session-only).
- **What it can and cannot see.** Recording only accrues in combat, and this addon's most expensive work is deliberately *out* of combat — the flyout rebuild is skipped in combat, `MB.Update` defers wholesale, and macro writes wait for regen. What the capture does catch is the cooldown repaint, which rides `SPELL_UPDATE_COOLDOWN` / `BAG_UPDATE_COOLDOWN` and walks every bar button plus every shown flyout row. That is the `cooldown` bucket, and it is the reason the harness is worth having.

Two buckets are instrumented: `cooldown` (`modules/MacroBar.lua`, `MB.RefreshCooldowns`) and `recompute` (`core/ConsumableMaster.lua`, `Pipeline.Recompute`). Both gate on `KCM.Perf.on` and cost two table lookups when idle. `Note()` records unconditionally, so an ungated bracket would accumulate outside any window and poison the next report — `tests/test_perfsetup.lua` pins the gates.

`recompute` is usually **absent** from a report, and that is correct rather than broken: nothing triggers a recompute in a plain dummy fight. To make it appear, loot something during arm A.

### The buckets and the delta answer different questions

`deltaMsPerFrame` is **not** the sum of the buckets, and it is not meant to be. Reconcile them before drawing a conclusion from either.

The **buckets measure Lua**, bracketed at named call sites. The **delta measures everything** — because `suspend()` unregisters every event *and* hides the macro bar, so arm B is missing the addon's Lua **and its fifteen rendered buttons**. Frame drawing is not Lua, so no bucket can ever see it, yet it lands squarely in the delta. That is a real cost of running the addon; it is just not one you can optimize in code, and it is not attributable to any bracket.

A gap between the two is therefore expected. A *large* gap usually means the environment, not the addon. The first in-game capture (2026-08-01, v1.5.0) is the worked example:

| | |
|---|---|
| reported delta | +0.41 ms/frame (≈ 56 ms/s) |
| `cooldown` bucket | 0.80 ms/s — 0.0059 ms/frame, 502 calls, 0.065 ms mean |
| ratio | ~70× |

Two 40-second fights minutes apart in Silvermoon City, with frame counts 40 apart per second (5529 vs 5951). City population and ambient draw load swing more than the 6% fps difference on their own, so almost all of that delta is venue, not addon.

**So: trust the buckets for "what does this addon's code cost" — the answer is ~0.08% of wall time — and treat the delta as an upper bound that includes rendering and noise.** For a delta worth quoting, capture in an empty zone, back to back, and repeat it; if the number does not fall toward the buckets, the bar's draw cost is the remainder.

Captures persist in their own SavedVariables global, `ConsumableMasterPerfDB` (a ring of the last 10), separate from `ConsumableMasterDB`. They flush on `/reload` or logout like any SavedVariables.

## Force a resync

`/cm resync` — invalidates `TooltipCache`, re-runs auto-discovery against bags, then runs a direct (non-coalesced) `Pipeline.Recompute`. Use after editing a scorer / classifier / tooltip pattern to force a fresh evaluation.

`/cm rewritemacros` (alias `/cm rewrite`) — clears `macroState` + `pendingUpdates` + the oversized-warning gate via `MacroManager.InvalidateState()`, then runs `Pipeline.Recompute` so every macro is re-issued unconditionally. Use when an action-bar icon looks stale (some bar frameworks cache `GetActionTexture` results across an `EditMacro`; a `/reload` after the rewrite forces a re-query).

## Schema-driven slash UX (KickCD parity)

Scalar settings live as rows in `KCM.Settings.Schema` (the array is created in `settings/Panel.lua`; the page files append to it). Each row drives both its panel widget (rendered by `Helpers.RenderField`) AND the slash CLI. The four verbs are `LibKa0s-Slash-1.0`'s, reading this addon's rows through the descriptor's `get` / `set` / `findRow` / `allRows` hooks:

| Slash | Effect |
|-------|--------|
| `/cm list` | Every schema row, grouped by panel, with current value. |
| `/cm get <path>` | Single-row read (e.g. `/cm get enabled`). |
| `/cm set <path> <value>` | Type-validated write through `KCM.Schema:Set`; same code path as the panel widget. |
| `/cm reset <path>` | ONE row back to its `default`. Not the global wipe — that is `/cm resetall`, which keeps the host body and its confirm popup ([LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)). |

`KCM.Schema:Set(path, value)` is the unified validate → write → onChange → refresh seam — panel widgets and `/cm set` both route through it. Adding a new scalar = one schema row. Row shape:

```lua
Schema[#Schema + 1] = {
    panel    = "general", section = "general", group = "General",
    path     = "enabled", type    = "bool",
    label    = "Enable",
    tooltip  = "Master toggle. When off, the recompute pipeline is a no-op.",
    default  = KCM.dbDefaults.profile.enabled,   -- default sourced from dbDefaults
    onChange = function(v) ... end,    -- optional
}
```

`Helpers.ValidateSchema()` lints rows at register-time and prints malformed entries to chat without blocking registration. Fifty-four rows are wired today: the fifty-three `macroBar.*` rows registered by `settings/MacroBar.lua`, and `general.enabled` (master toggle; `Pipeline.Recompute` skips its macro write loop when off but still fires the panel refresh so `[Loading]` rows hydrate, and the row's `onChange` kicks `RequestRecompute` on the off→on transition so macros refresh immediately). Debug is **not** a schema row — it is the session-only `KCM.State.debug` flag driven by `/cm debug`.

## List-shaped state — verb namespaces

CM's panel state is mostly list-shaped (priority lists, AIO order, per-spec stats), which doesn't fit a flat scalar schema. Those operations live behind dedicated CLI verbs that follow the same write+notify+refresh contract:

| Verb namespace | Verbs | Notes |
|----------------|-------|-------|
| `/cm priority <cat>` | `list / add / remove / up / down / reset` | `<id>` accepts `12345` (item) or `s:5512` (spell sentinel via `KCM.ID.AsSpell`). Composite categories rejected — use `/cm aio`. |
| `/cm stat` | `list / primary / secondary / reset [<specKey>]` | `<specKey>` is canonical `<classID>_<specID>` or friendly `CLASS:SPEC` (e.g. `SHAMAN:ENHANCEMENT`); defaults to current spec. |
| `/cm aio <key>` | `list / toggle / up / down / reset` | Sub-categories are locked to their section, so `up` / `down` infer the section from where the ref appears. |

All three namespaces dispatch through `findCommand` against an ordered `*_COMMANDS` table; help is generated from the same table. Adding a verb = one row.

## Per-category recompute log

Recompute no longer logs per-category — the old per-category `Pipeline.RecomputeOne` block (which fired `N × M` times during login: N categories × M `GET_ITEM_INFO_RECEIVED` events) was deleted. Each recompute pass now emits exactly one `[Calc]` summary line (reason + rewrote/total/skipped counts), gated on `KCM.State.debug`.

## Smoke testing

The full validation playbook lives in [smoke-tests.md](./smoke-tests.md): a [Quick smoke](./smoke-tests.md#quick-smoke) recipe for post-change validation, a [12-section full suite](./smoke-tests.md#full-suite) for releases, and a [targeted-by-change-area lookup](./smoke-tests.md#targeted-by-change-area) at the bottom that maps "I changed X" to "run sections Y, Z".
