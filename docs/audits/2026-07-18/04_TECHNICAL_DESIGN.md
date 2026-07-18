# 04 — Technical Design (Remediation)

**Addon:** Ka0s Consumable Master · **Audit:** 2026-07-18 · **Standard:** v2.7.0
Read-only audit output — this design is the hand-off for a **separate** remediation engagement. Every change below is keyed to a deviation ID from `02_DEVIATIONS.md`. Nothing here has been applied.

Guiding constraints: keep the TDD gate green (`lua5.1 tests/run.lua` + `luacheck .`), do not bump `KCM.VERSION`/TOC/badges unless the user asks, and add/extend a covering test with each behavioural change.

---

## Theme A — the chat-output seam (CM-24, CM-25, CM-26, CM-27, CM-28, CM-29)

These five share one root: chat output has grown three printers and hand-written tags. The design collapses them onto **one secret-safe seam** and moves formatting into shared helpers. Do CM-24 first (it is the correctness foundation the seam depends on), then the rest ride the same file.

### CM-24 — fix the secret-safe stringifier (`core/Constants.lua`)
Replace the `pcall(tostring, …)` probe with a `table.concat` probe, matching the standard's reference:

```lua
local function probeConcat(v) return table.concat({ v }) end
function KCM.IsConcatSafe(v) return (pcall(probeConcat, v)) end
function KCM.SafeToString(v)
  if v == nil then return "nil" end
  if type(v) == "boolean" then return tostring(v) end
  if KCM.IsConcatSafe(v) then return tostring(v) end
  return "<secret>"
end
```

- **Risk:** low. `tests/test_debuglog.lua` / any suite asserting `SafeToString` behaviour must still pass; add a case that a table-concat-hostile stub yields `"<secret>"` and that plain values round-trip. No live combat-secret path exists in this addon today, so this is defence-in-depth, but the standard requires it and it is a pure-function change.

### CM-25 — one shared secret-safe printer
- Promote `KCM.Say` (Constants) to the **sole** chat seam and make it secret-safe: build the line from `KCM.SafeToString` per argument, prepend `KCM.PREFIX` once. Give it a vararg form (`KCM.Say(fmt, ...)`) so call sites stop pre-concatenating.
- In `core/SlashCommands.lua`, delete the file-local `say`; alias `local say = KCM.Say` (or route the existing `say(s)` body through `KCM.Say(s)`), so all ~40 `say(...)` sites keep working with zero call-site edits.
- In `settings/Panel.lua` and `core/Debug.lua`, replace every `print(KCM.PREFIX .. …)` with `KCM.Say(…)` (schema errors, onChange echo, button-failure, combat notice, tab-register failure, panel-refresh failure).
- **Risk:** medium-mechanical (many sites). The `%`-format lines already build their own strings; keep passing the finished string to `KCM.Say(str)` and reserve the vararg form for new code. Do not route the **debug console** sink through `KCM.Say` — it has its own gated `KCM.Debug` → `DebugLog.AddLine` path (correct per debug-logging-§4); this theme is chat-only.

### CM-26 — strip trailing colons
- Remove the trailing `:` from the help header (`printHelp`), `Available settings`, `dump targets`, `priority/stat/aio subcommands`, and dump section labels. Pure string edits in `core/SlashCommands.lua`.
- **Risk:** trivial. If any test asserts exact help text, update it in lockstep.

### CM-27 — coloured schema output + shared formatter (`core/SlashCommands.lua`)
- Add two shared helpers (co-located with `formatValue`):
  - `KCM.FormatSchemaValue(def, v)` — reuse the existing `formatValue` body (type-aware, `def.fmt` units).
  - `FormatKV(path, valueStr)` → `|cffffff00<path>|r = |cffffffff<valueStr>|r` (gold key, white value, uncoloured ` = `).
- `listSettings`: header `|cff33ff99Available settings|r`; group header `|cff3399ff[<page>]|r`; rows via `FormatKV`.
- `getSetting` / `applyFromText` (set echo): single-line `FormatKV(def.path, KCM.FormatSchemaValue(def, H.Get(def.path)))`.
- **Risk:** low. One schema row exists today (`enabled`), so output surface is small; the shared formatter future-proofs new rows.

### CM-28 — canonical `version` verb (`core/SlashCommands.lua`)
- Rewrite the verb `fn` to read the version from metadata with the constant as fallback and print the canonical form:

```lua
local function addonVersion()
  local m = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return (m and m("ConsumableMaster", "Version")) or KCM.VERSION or "?"
end
-- fn: KCM.Say("v" .. tostring(addonVersion()))   -- KCM.Say adds the [CM] tag
```

- **Risk:** low. Keep `KCM.VERSION` as the fallback so headless tests (no metadata mock) still resolve a value.

### CM-29 — grey canonical combat notice (`settings/Panel.lua`)
- Replace the two untinted messages (`O.Open`, `SetRenderer` OnShow guard) with one shared grey notice via `KCM.Say`:
  `KCM.Say("|cff808080cannot open settings during combat — Blizzard's category-switch is protected|r")`.
- Keep the existing early-return / panel-close behaviour unchanged (it already refuses correctly and does not defer-and-replay).
- **Risk:** low. Consider a tiny `KCM.Options` helper so both sites share the exact string.

---

## Theme B — TOC & docs housekeeping (CM-31, CM-32, CM-33)

### CM-31 — reorder TOC metadata (`ConsumableMaster.toc`)
Rewrite the metadata block (lines 1-13) to the exact toc-file-§1 order:
```
## Interface → Title → Notes → Author → Version → IconTexture →
## SavedVariables → OptionalDeps → DefaultState → Category-enUS →
## X-License → X-Standard → X-Curse-Project-ID → X-Wago-ID
```
- **Risk:** none functionally — WoW ignores metadata order; this is for cross-addon uniformity and the audit checklist. No blank lines inside the block.

### CM-32 — add `X-Wago-ID` (`ConsumableMaster.toc`)
- Add `## X-Wago-ID: <id>` after `X-Curse-Project-ID` (folded into the CM-31 rewrite). **Decision needed:** if the addon is intentionally Curse-only, the user should instead record this as a documented tracked deviation rather than add a placeholder ID.

### CM-33 — rename CLAUDE.md standards heading (`CLAUDE.md`)
- Change `## Standard — read first` → `## Standards compliance (read first)`. Body already carries the required substance; optionally align the closing to the standard's "when in doubt, treat conformance as a hard requirement and ask." Verify `docs/agent-context.md`'s first Hard rule points back to this section by its new name.
- **Risk:** none.

---

## Theme C — accepted deviation (CM-30)

### CM-30 — English tooltip parsing
- **No code change.** This is a pre-existing, documented, intentional deviation (`docs/scope.md`, `docs/agent-context.md`). Confirm the documentation still accurately scopes it to `core/TooltipCache.lua` text parsing and that classification remains ID-based. Full tooltip-text localization stays a planned future release; when it lands, this ID closes.

---

## Cross-cutting notes
- **Test coverage:** CM-24 and CM-27/CM-28 are pure-logic and belong in `tests/` (extend `test_debuglog.lua` for the stringifier; a small `test_slash.lua` case for `FormatKV`/version). CM-25/26/29 are largely mechanical string routing; smoke-test in-game per `docs/smoke-tests.md`.
- **Ordering constraint:** land **CM-24 before CM-25** (the shared seam should be secret-safe from the first commit). CM-26/27/28 sit in the same file as CM-25 and are cleanest done in that pass.
- **No version bump** unless the user requests one; none of these are user-visible feature changes (per project memory: don't touch `KCM.VERSION`/TOC Version/badges without instruction — the TOC edits here are metadata order/IDs, not the `## Version:` line).
