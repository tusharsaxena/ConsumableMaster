# 03 — Evidence

**Addon:** Ka0s Consumable Master · **Audit:** 2026-07-18 · **Standard:** v2.7.0
Every deviation is backed by `file:line`. Key compliance claims are cited too, so a re-auditor can confirm what is already correct without re-deriving it.

## Deviation evidence

### CM-24 — secret detection probes `tostring`, not `table.concat`
- `core/Constants.lua:23-26` — `function KCM.SafeToString(v) local ok, s = pcall(tostring, v) return ok and s or "<secret>" end`. The standard (events-frames-taint-§8) states a secret **survives `tostring()`** and only raises in `table.concat`/`string.format`; so this `pcall(tostring,…)` returns `ok = true` with a secret string and never substitutes `"<secret>"`.
- `core/Debug.lua:51` — the debug sink feeds each stringified part into `tostring(fmt):format(unpack(parts))`, i.e. a `string.format` that would raise if `parts[i]` were still a secret that `SafeToString` failed to catch.
- Reference detector the standard prescribes: `local function probeConcat(v) return table.concat({ v }) end; function NS.IsConcatSafe(v) return (pcall(probeConcat, v)) end`.

### CM-25 — no single shared secret-safe chat printer; tag hand-written
- `core/Constants.lua:16-18` — `function KCM.Say(msg) print(KCM.PREFIX .. " " .. tostring(msg)) end` — the "shared" seam itself uses raw `..`/`tostring` (not secret-safe) and calls the global `print`.
- `core/SlashCommands.lua:25-27` — a **second** printer: `local function say(s) print(PREFIX .. s) end`, bypassing `KCM.Say`.
- Direct `print(KCM.PREFIX .. …)` sites hand-writing the tag: `settings/Panel.lua:111, 214, 219, 281, 445, 540, 667, 692, 729, 761, 893, 972, 987`; `core/Debug.lua:33, 57`. `grep -c 'print(KCM.PREFIX' core modules settings` → 20 direct tag-writing sites; 32 total `print(` sites across the source (excluding spell-name lookups).
- Rule: events-frames-taint-§8 — "funnel **every** chat and debug line through a **single shared secret-safe printer**"; slash-commands-§4 — call sites "**MUST NOT** … hand-write the `NS.PREFIX` tag per line."

### CM-26 — trailing colons on chat lines
- `core/SlashCommands.lua:1250` — help header ends `…is an alias for |cffffff00/consumablemaster|r):` (trailing `:`).
- `core/SlashCommands.lua:619` — `say("Available settings:")`.
- `core/SlashCommands.lua:506` — `say("dump targets:")`.
- `core/SlashCommands.lua:821` — `say("priority subcommands:")`; `:957` — `say("stat subcommands:")`; `:1113` — `say("aio subcommands:")`.
- `core/SlashCommands.lua:427` — `say("  macro body:")`; and dump section labels at `:410-411, 443, 460` (`In Combat:` / `Out of Combat:` / `effective priority (…):`).
- Rule: slash-commands-§4 — "No chat line the addon prints … MUST end in a trailing `:`."

### CM-27 — list/get/set missing mandated colour scheme + shared formatter
- `core/SlashCommands.lua:619` — `say("Available settings:")` (should be green `33ff99`, no colon).
- `core/SlashCommands.lua:633` — `say("  [" .. key .. "]")` (page header should be azure `3399ff`).
- `core/SlashCommands.lua:635` — `say(("    %s = %s"):format(def.path, formatValue(def, H.Get(def.path))))` — key should be gold `ffff00`, value white `ffffff`.
- `core/SlashCommands.lua:651` (`getSetting`) and `:607` (`applyFromText`/set echo) — same uncoloured `%s = %s`.
- `formatValue` (`:544-554`) is a value formatter but there is no shared **coloured** `FormatKV`; `list` and `get`/`set` each build the line inline.
- Rule: slash-commands-§5 colour table (MUST) + single shared `FormatKV`/value formatter.

### CM-28 — `version` verb form + source
- `core/SlashCommands.lua:1158-1159` — `{"version", "Print addon version", function() say(("version %s"):format(tostring(KCM.VERSION or "?"))) end}` → prints `[CM] version 1.5.0`, not `[CM] v1.5.0`, and reads the in-code constant only.
- `KCM.VERSION` set at `core/ConsumableMaster.lua:9`. `C_AddOns.GetAddOnMetadata` is available (used for Notes at `settings/Panel.lua:782-786`) but not for Version.
- Rule: slash-commands-§3 — `/<slash> version` prints `<tag> v<version>`, read from TOC metadata with the constant as fallback.

### CM-29 — combat-lockdown notice not grey / non-canonical
- `settings/Panel.lua:971-974` (`O.Open`) — `print(KCM.PREFIX .. " cannot open settings during combat. Try again after combat ends.")` — untinted, non-canonical wording; correctly returns without calling `OpenToCategory`.
- `settings/Panel.lua:275-283` (`SetRenderer` OnShow guard) — same untinted message on the sidebar path.
- Rule: options-ui-§2 — grey `NS.PREFIX`-tagged notice, canonical text "cannot open settings during combat — Blizzard's category-switch is protected".

### CM-30 — English tooltip-text parsing (tracked deviation)
- `core/TooltipCache.lua:43` (`PATTERNS`), `:84-90` (`STAT_TOKENS`, e.g. `{ token = "Versatility", … }`), `:141-272` — heal/mana/stat magnitudes and effect markers parsed from English tooltip strings via `line:match(…)` / `line:find(…)`.
- Documented as intentional: `docs/scope.md:19` ("Localization — tracked deviation from the standard … A standards audit *should* flag it — that is expected and recorded here"); `docs/agent-context.md` Hard rules bullet.
- Compliant counterpart: classification keys on `classID`/`subClassID` in `core/Classifier.lua` and `core/WeaponSlots.lua` (locale-independent), confirmed by `tests/test_classifier.lua` / `test_weaponslots.lua` ("keys on weapon subClassID, not the localized subType").
- Rule: localization-§4 / anti-pattern #37.

### CM-31 — TOC field order
- `ConsumableMaster.toc:1-13` — actual order: `Interface, Title, Notes, Author, Version, IconTexture, Category-enUS(:7), SavedVariables(:8), DefaultState(:9), OptionalDeps(:10), X-License, X-Standard, X-Curse-Project-ID`.
- Required order (toc-file-§1): `… IconTexture → SavedVariables → OptionalDeps → DefaultState → Category-enUS → X-License → …`. `Category-enUS` (line 7) precedes `SavedVariables` (8) and `OptionalDeps` (10); `DefaultState` (9) precedes `OptionalDeps` (10).

### CM-32 — missing X-Wago-ID
- `ConsumableMaster.toc:13` — `## X-Curse-Project-ID: 1522944` present (published), but no `## X-Wago-ID:` line anywhere in the metadata block (`:1-13`).
- Rule: toc-file-§1 — "MUST have `X-Curse-Project-ID` and `X-Wago-ID` once an addon is published anywhere."

### CM-33 — CLAUDE.md standards heading
- `CLAUDE.md:5` — section heading is `## Standard — read first` (body at `:7-13` carries the stop-and-flag rule and the deviation-vs-standard-change choice).
- Rule: documentation-§2 #3 / documentation-§6 / anti-pattern #34 — the section MUST be titled `## Standards compliance (read first)`.

## Compliance evidence (already-correct, spot-checked)

- **Namespace / AceAddon:** `core/Namespace.lua:12-13`; `core/ConsumableMaster.lua:6` (`NewAddon(NS, addonName, …)`). No `_G.KCM` (`grep` finds only comments + a `defaults/README.md` copy-macro snippet).
- **Closed bus, per-receiver targets:** `core/Bus.lua:26-30` (`NewBusTarget`), `:41-47` (pipeline target); options receivers on their own target `settings/Panel.lua:1009-1022`.
- **Schema-as-single-source:** `settings/Panel.lua:724-743` (`SetAndRefresh` + `KCM.Schema:Set`), default sourced from `dbDefaults` `:758`.
- **Options-ui-§5 Defaults button = AceGUI Button:** `settings/Panel.lua:205-222`.
- **Options-ui-§11 in-place / on-screen refresh:** `RefreshScalars` `settings/Panel.lua:685-700`, `RefreshAllPanels` scoped to `IsShown()` `:661-675`, dirty-rebuild on OnShow `:288-292`.
- **Always-visible scrollbar:** `settings/Panel.lua:311-407`.
- **Debug console:** `modules/DebugLog.lua` — DIALOG strata + 700×344 `:217-219`, `UISpecialFrames` `:300-302`, JetBrains Mono LSM register `:36-39`, pure formatters `:74-88`, SetEnabled ack `40ff40`/`ff4040` `:118-123`, `[Init]` summary `:136-141`.
- **Session-only debug flag:** `core/State.lua:14`.
- **Compat seam:** `core/Compat.lua:17-71`. **Macro firewall:** `MacroManager` sole CreateMacro/EditMacro caller; combat flush `core/ConsumableMaster.lua:372-379`.
- **TOC file listing sectioned + libs inline (no embeds.xml):** `ConsumableMaster.toc:15-83`.
- **Green gates at audit time:** `lua5.1 tests/run.lua` → `137 passed, 0 failed, 137 total`; `luacheck .` → `0 warnings / 0 errors in 40 files`. README `[tests]` badge `137/137` (`README.md:7`) in sync with `docs/test-cases.md`.
- **README structure + badge row:** `README.md:1-9` (H1 + five badges in canonical order), headings at `:35, 53, 57, 78, 121, 139, 154, 169, 173`.
- **docs/ quartet:** `docs/agent-context.md`, `docs/ARCHITECTURE.md`, `docs/testing.md`, `docs/smoke-tests.md`, `docs/test-cases.md` all present.
