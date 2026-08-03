# Design — Debug-logging conformance (§3/§4/§8/§9/§10)

**Date:** 2026-07-15
**Status:** approved (design), pending spec review
**Standard:** [Ka0s WoW Addon Standard — `debug-logging`](https://github.com/tusharsaxena/WowAddonStandards) v1.11.0, §1–§10
**Reference implementation:** LootHistory `modules/DebugLog.lua` + `core/Util.lua` (`NS.Debug` / `NS.SafeToString`)

## 1. Goal

Bring Consumable Master's debug output into full conformance with the `debug-logging`
standard, whose §8 (Coverage), §9 (Coalescing) and §10 (Settings changes) were added in
v1.11.0. After this change a debug capture read back after a repro tells the *story* of what
the addon did — lifecycle, discovery, recompute, macro writes, and every settings change —
with **one gated, tagged, coalesced line per flow event** and **zero per-item spam**.

Non-goals: the console window shape, the format strings, the session-only flag, and the
`SetEnabled` seam already conform (§1–§7) and are **not** touched except where noted.

## 2. Current state & gaps

| Area | Today | Required |
|---|---|---|
| Sink | `KCM.Debug.Log(tag,…)` **and** tagless `KCM.Debug.Print(…)` (34 call sites) | Single callable `KCM.Debug(tag, fmt, …)`; every line tagged (§3/§4) |
| Tag semantics | Discovery summary tags with the **event reason** → `[manual_resync]` | Tag = functional area; reason in content |
| Embedded prefixes | `"MacroManager: KCM_FOOD set…"` in message text | Area lives in the tag → `[Macro] KCM_FOOD set…` |
| Secret safety | `pcall(string.format, fmt, …)`, mixed `%d/%s` | Args via `SafeToString`, all `%s` (§4) |
| Boot coverage | Tagless `"Initialized (version …)"` | `[Boot]` one-line summary w/ schema ver + counts (§8) |
| Migration | none (commented seam) | `[DB]` line **only when a migration runs** (§8) |
| Recompute | commented-out per-item line | `[Calc]` one summary line per pass (§8/§9) |
| Settings | **nothing** | `[Set] <path> = <value>` at the single write seam (§10) |
| Data mutations | **nothing** | `[Prio]` per priority-list mutation (§8) |

Already-conformant and preserved: `DebugLog.FormatPlain/FormatColored`, the console window,
`KCM.State.debug` (session-only, default off), the `DebugLog.SetEnabled` seam, and the
discovery pass already coalesced to one `[Scan]`-style summary (commit `eab4d50`).

## 3. Decisions (locked)

1. **Callable sink (conform).** `KCM.Debug` becomes callable — `KCM.Debug(tag, fmt, …)` —
   matching the reference `NS.Debug`. `.IsOn` / `.Toggle` remain fields on the same table via a
   `__call` metamethod. Tagless `KCM.Debug.Print` is **removed**; all 34 sites migrate to a tag.
   `KCM.Debug.Log` is retained as a thin alias of the callable (back-compat for the 4 existing
   tagged sites and any tests) — or migrated; either way `.Print` is gone.
2. **Secret-safe now (conform).** Add `KCM.SafeToString(v)` (pcall-`tostring`, returns
   `"<secret>"` on error). The sink stringifies every vararg through it before `fmt:format`, so
   **all placeholders become `%s`**. No tracked deviations remain.

## 4. Architecture

### 4.1 `KCM.SafeToString` (core/Constants.lua)

```lua
-- Secret-safe stringifier (events-frames-taint-§8 / debug-logging-§4). A combat-
-- protected "secret" value errors on any Lua touch; tostring it under pcall so the
-- debug sink can never raise mid-combat.
function KCM.SafeToString(v)
    local ok, s = pcall(tostring, v)
    return ok and s or "<secret>"
end
```

Placed in Constants.lua beside `KCM.Say` so it loads before any module call site.

### 4.2 The sink (core/Debug.lua)

```lua
local mt = {
    __call = function(_, tag, fmt, ...)
        if not KCM.Debug.IsOn() then return end          -- zero-alloc gate, first line
        local n = select("#", ...)
        local msg = fmt
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = KCM.SafeToString((select(i, ...))) end
            msg = tostring(fmt):format(unpack(parts))
        end
        if KCM.DebugLog and KCM.DebugLog.AddLine then
            KCM.DebugLog.AddLine(tag, msg)
        else
            print(PREFIX .. "[" .. tostring(tag) .. "] " .. msg)   -- pre-console fallback
        end
    end,
}
setmetatable(KCM.Debug, mt)
KCM.Debug.Log = function(tag, fmt, ...) return KCM.Debug(tag, fmt, ...) end  -- alias
```

`.IsOn` / `.Toggle` unchanged. The gate stays the first statement (zero-alloc when off).
Every ordinary call site is **double-gated**: `if KCM.State.debug then KCM.Debug("Tag", …) end`
so nothing allocates the arg list when debug is off (§4/§9).

### 4.3 Pure summary formatters (unit-tested, frame-free)

Mirroring LootHistory's `BootSummary` / `RenderSummary`, extract per-pass summaries as pure
functions so the content is headlessly testable and the colored/plain lines can't drift:

- `KCM.Pipeline.BootSummary(schemaVer, catCount, discCount) -> string`
  → `"schema=%s categories=%s discovered=%s"`
- `KCM.Pipeline.CalcSummary(reason, rewrote, total, skipped) -> string`
  → `"reason=%s rewrote %s/%s (skipped %s)"`

The `[Scan]` summary already exists inline in `runAutoDiscovery`; it is re-tagged (see §5) but
its shape is unchanged.

## 5. Tag taxonomy & coverage

PascalCase, one short word per functional area (§3 open set). Every line is one gated call.

| Tag | Site | When | Cadence |
|---|---|---|---|
| `Boot` | `OnEnable` (ConsumableMaster.lua) | addon enabled | once per session |
| `DB` | migration seam (Database.lua) | **only when a migration actually runs** | rare |
| `Scan` | `runAutoDiscovery` | each discovery pass (PEW / bag update / resync) | **1 line / pass** (already coalesced) |
| `Calc` | `Pipeline.Recompute` | each recompute pass | **1 line / pass** |
| `Macro` | MacroManager set/composite/flush | **only exceptional events** — combat-deferred, byte-limit exceeded, `EditMacro` failure, flush applied/dropped | per event (not per happy-path write) |
| `GC` | `Selector.SweepStaleDiscovered` | sweep with ≥1 eviction | 1 line / sweep (already coalesced) |
| `Set` | `Helpers.Set` (Panel.lua) | every schema setting write | 1 line / change |
| `Prio` | `Selector.AddItem/Block/MoveUp/MoveDown` + category/all reset | user data mutation | 1 line / mutation |

**§9 balance for macro writes:** the happy path (a macro body rewritten during a normal
recompute) is **not** logged per-macro — its count is folded into the one `[Calc]` pass summary
(`rewrote 3/10`). Only *notable* macro events (deferral, truncation, API failure, flush
outcome) emit an individual `[Macro]` line. This keeps §8 coverage of failures/no-ops without
the ≤10-lines-per-pass spam §9 forbids.

**§10 no re-echo:** `[Set]` is emitted once at `Helpers.Set`. Downstream reactors (the
settings-changed → `RequestRefresh`/`Recompute` path) MUST NOT restate the value; the `[Calc]`
line they cause already carries the material effect (which macros changed). Window geometry and
other non-schema view state are not logged per-change (§10).

**Zero-hit discovery** stays unlogged per-item (the common "not a consumable" case) — the
`[Scan]` summary covers it (§9). This is already correct and is preserved.

## 6. Testing

Extend the existing headless suite (`tests/`):

- `tests/test_debuglog.lua` — already locks `FormatPlain`/`FormatColored`. Add:
  - callable `KCM.Debug("Tag", "%s", x)` routes through `DebugLog.AddLine` and is gated off when
    `State.debug` is false (no append).
  - `KCM.SafeToString` returns `tostring` for normal values and `"<secret>"` for a value whose
    `tostring` raises (a metatable `__tostring` that errors, simulating a secret).
- New pure-formatter assertions for `Pipeline.BootSummary` and `Pipeline.CalcSummary`.
- A `[Set]`-seam test: calling `Helpers.Set(path, v)` with `State.debug = true` produces exactly
  one captured line matching `[Set] <path> = <value>`; with debug off, none.

Gate: `lua5.1 tests/run.lua` and `luacheck .` both green (project rule).

## 7. Out of scope

- Console window layout, colors, fonts, Copy/Clear (already conform §1/§2/§6).
- Persisting the debug flag (forbidden by §5).
- New slash verbs / structured dump topics (§4 "MAY"; not requested).
- Localization of debug strings (debug is developer-facing, English-only per project scope).

## 8. Deviations flagged

None outstanding. Both potential deviations (sink name, secret safety) were resolved toward
**conformance** — see §3. No tracked-deviation entries or upstream standard changes needed.
