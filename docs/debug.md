# Debug & diagnostics

The debug console, the dump targets, and the schema-driven slash CLI. All chat output is prefixed with the cyan `|cff00ffff[CM]|r` tag (`KCM.PREFIX`) — no raw `print(...)` calls.

## Toggle the debug console

`/cm debug on|off` drives `KCM.State.debug` (declared in `core/State.lua`) through the single `KCM.DebugLog.SetEnabled(on)` seam; **bare `/cm debug` toggles the console window only, leaving the flag untouched** (so capture can be armed independently of whether the window is open). The flag is **session-only** — default off, **never persisted**, and it resets to off on every login — so a session left with debug on doesn't leak into the next one. There is no `db.profile.debug`, no `debug` schema row, and no `Settings.Helpers.SetAndRefresh("debug")` path. Calls to `KCM.Debug(tag, fmt, ...)` early-return when the flag is off, so unconditional calls are safe.

`modules/DebugLog.lua` owns the on-screen console — a `ScrollingMessageFrame` inside `ConsumableMasterDebugWindow`, rendered in JetBrains Mono (registered through LibSharedMedia), styled like the addon's own frames (title bar + 1px divider, dark skin, flat text buttons). The title bar carries a left-aligned **Debug: ON/OFF** state toggle (green ON / red OFF) plus Copy / Clear / close; **Copy** opens a separate read-through window for `Ctrl+C`. `core/Debug.lua` routes diagnostics into it:

```lua
KCM.Debug.IsOn()      -- bool; reads KCM.State.debug
KCM.Debug.Toggle()    -- routes through DebugLog.Toggle -> SetEnabled (owns the ack)
KCM.Debug(tag, fmt, ...)        -- callable sink: gated, secret-safe line to the console

KCM.DebugLog.SetEnabled(on) / IsEnabled() / Toggle()   -- Toggle flips the flag
KCM.DebugLog.AddLine(tag, msg) / Show() / Hide() / Toggle_Window() / ShowCopy()
KCM.DebugLog.FormatPlain(ts, tag, msg) / FormatColored(ts, tag, msg)   -- pure formatters
```

`KCM.Debug` is gated on `KCM.State.debug` as its first, zero-alloc statement, and every vararg is passed through `KCM.SafeToString` before formatting — so it's safe to call unconditionally and format placeholders are always `%s` (never `%d`/`%f`, since a combat "secret" value must never hit a numeric formatter). It writes to the **console**; chat is a fallback only when the console frame is unavailable.

### Tags

Functional-area tags in use today:

- `Init` — session summary emitted on debug-**enable** (addon + version, schema version, active profile), written at the `DebugLog.SetEnabled` seam right after the `[Debug] logging enabled` bracket so a pasted log self-identifies (debug-logging-§5/§8)
- `DB` — schema migration, only logged when one actually runs
- `Scan` — auto-discovery pass summary (reason in content)
- `Calc` — recompute pass summary (reason + rewrote/total/skipped)
- `Macro` — exceptional macro events (combat-deferred, byte-limit, `EditMacro` failure, flush drop/apply)
- `GC` — stale-discovered sweep
- `Set` — settings write at `Helpers.Set`
- `Prio` — priority-list mutations (add/block/move) and category/all resets

Every settings change logs once as `[Set] <path> = <value>` at `Helpers.Set`; repeating passes (auto-discovery, recompute) coalesce to one `[Scan]` / `[Calc]` summary line per pass instead of one line per item.

The `DebugLog.SetEnabled` seam prints a **colour-coded** chat ack through `KCM.Say` — `debug logging |cff40ff40ON|r` (green) / `|cffff4040OFF|r` (red) — matching the title-bar `Debug: ON/OFF` toggle so the flag reads identically in chat and on the console (debug-logging-§5).

Don't introduce raw `print(...)` calls. Three sanctioned output paths:

- `say()` (in `core/SlashCommands.lua`, `= print(KCM.PREFIX .. " " .. s)`) — slash output, dump rows, help. Always prepends `[CM]`.
- `KCM.Debug(tag, ...)` — gated diagnostics into the console.
- Inline `KCM.PREFIX`-prefixed `print(...)` — only for one-shot warnings (oversized macro body, give-up notice on flush failure, etc.) where neither helper fits.

## Dump internals

`/cm dump <target>` — inspect runtime state. `DUMP_TARGETS` in `core/SlashCommands.lua` is the single source of truth; adding a row makes it appear in `/cm dump` help automatically.

| Target | What it shows |
|--------|---------------|
| `categories` | The full `KCM.Categories.LIST` with macro name, display name, spec-awareness flag. |
| `statpriority` | Current spec's stat priority (primary + ordered secondary), with classID / specID / specKey. |
| `bags` | `BagScanner.Scan()` output as `itemID = count`. |
| `item <id>` | Parsed tooltip fields for the item plus the raw tooltip lines (pattern-debugging view). Shows `pending: tooltip data not yet loaded` if the data hasn't hydrated yet. |
| `pick <catKey>` | The effective priority list with per-entry Ranker scores, an `[owned]` tag for entries you actually have, and a `<-- pick` marker on the winner. Composite catKeys (`hp_aio` / `mp_aio`) print the configured order, per-sub-cat picks, and the assembled macro body. |

`<catKey>` is case-insensitive (`flask`, `FLASK`, `hp_aio` all work).

## Force a resync

`/cm resync` — invalidates `TooltipCache`, re-runs auto-discovery against bags, then runs a direct (non-coalesced) `Pipeline.Recompute`. Use after editing a scorer / classifier / tooltip pattern to force a fresh evaluation.

`/cm rewritemacros` (alias `/cm rewrite`) — clears `macroState` + `pendingUpdates` + the oversized-warning gate via `MacroManager.InvalidateState()`, then runs `Pipeline.Recompute` so every macro is re-issued unconditionally. Use when an action-bar icon looks stale (some bar frameworks cache `GetActionTexture` results across an `EditMacro`; a `/reload` after the rewrite forces a re-query).

## Schema-driven slash UX (KickCD parity)

Scalar settings live as rows in `KCM.Settings.Schema` (declared in `settings/Panel.lua`). Each row drives both the General-panel widget (rendered by `Helpers.RenderField` in `settings/General.lua`) AND the slash CLI:

| Slash | Effect |
|-------|--------|
| `/cm list` | Every schema row, grouped by panel, with current value. |
| `/cm get <path>` | Single-row read (e.g. `/cm get enabled`). |
| `/cm set <path> <value>` | Type-validated write through `KCM.Schema:Set`; same code path as the panel widget. |

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

`Helpers.ValidateSchema()` lints rows at register-time and prints malformed entries to chat without blocking registration. Only one row is wired today: `general.enabled` (master toggle; `Pipeline.Recompute` skips its macro write loop when off but still fires the panel refresh so `[Loading]` rows hydrate, and the row's `onChange` kicks `RequestRecompute` on the off→on transition so macros refresh immediately). Debug is **not** a schema row — it is the session-only `KCM.State.debug` flag driven by `/cm debug`.

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
