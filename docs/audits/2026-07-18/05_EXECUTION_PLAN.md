# 05 — Execution Plan

**Addon:** Ka0s Consumable Master · **Audit:** 2026-07-18 · **Standard:** v2.7.0
Ordered, checkable remediation steps for the follow-up engagement. Each step names its deviation ID(s). Gate after every sprint: `lua5.1 tests/run.lua` (all green) **and** `luacheck .` (0 errors). Commit only on green, trunk-based, and **do not bump version / badges** unless the user asks. This audit changed no code — every box below is unchecked.

---

## Sprint 1 — Chat-output seam (CM-24, CM-25, CM-26, CM-27, CM-28, CM-29)
The largest cluster and the highest-value fix; all live in `core/Constants.lua`, `core/SlashCommands.lua`, `core/Debug.lua`, `settings/Panel.lua`. Do CM-24 first.

- [ ] **CM-24** — In `core/Constants.lua`, replace the `pcall(tostring,…)` probe in `KCM.SafeToString` with a `table.concat`-based `KCM.IsConcatSafe`; return `"<secret>"` only when a real concat rejects the value. *(TDD: add a `test_debuglog.lua` case — concat-hostile stub → `"<secret>"`, plain values round-trip.)*
- [ ] **CM-25** — Make `KCM.Say` the single secret-safe chat seam (build lines via the fixed `KCM.SafeToString`; add a `KCM.Say(fmt, ...)` vararg form). Delete the file-local `say` in `core/SlashCommands.lua` (alias to `KCM.Say`); replace every `print(KCM.PREFIX .. …)` in `settings/Panel.lua` and `core/Debug.lua` with `KCM.Say(…)`. Leave the gated `KCM.Debug`→`DebugLog.AddLine` console path untouched.
- [ ] **CM-26** — Strip the trailing `:` from the help header, `Available settings`, `dump targets`, `priority/stat/aio subcommands`, and dump section labels in `core/SlashCommands.lua`.
- [ ] **CM-27** — Add shared `KCM.FormatSchemaValue(def, v)` and `FormatKV(path, valueStr)` (gold key `ffff00` / white value `ffffff`); colour `listSettings` header green `33ff99` and `[page]` azure `3399ff`; route `getSetting` and the `set` echo through `FormatKV`. *(TDD: `test_slash.lua` case for `FormatKV` output.)*
- [ ] **CM-28** — Rewrite the `version` verb to read `GetAddOnMetadata(…,"Version")` with `KCM.VERSION` fallback and print `[CM] v<version>` via `KCM.Say`.
- [ ] **CM-29** — Replace the two untinted combat notices (`O.Open`, `SetRenderer` OnShow guard in `settings/Panel.lua`) with the canonical **grey** notice "cannot open settings during combat — Blizzard's category-switch is protected" via `KCM.Say`.
- [ ] **Gate + commit** Sprint 1.

## Sprint 2 — TOC & docs housekeeping (CM-31, CM-32, CM-33)
Fast, mechanical, low-risk.

- [ ] **CM-31** — Reorder the `ConsumableMaster.toc` metadata block to the exact toc-file-§1 field order (`… IconTexture → SavedVariables → OptionalDeps → DefaultState → Category-enUS → X-License …`), no blank lines inside the block.
- [ ] **CM-32** — Add `## X-Wago-ID: <id>` after `X-Curse-Project-ID` **or** (if the addon is intentionally Curse-only) record it as a documented tracked deviation. **Needs a user decision.**
- [ ] **CM-33** — Rename the `CLAUDE.md` standards heading to `## Standards compliance (read first)`; confirm `docs/agent-context.md`'s first Hard rule references it by that name.
- [ ] **Gate + commit** Sprint 2.

## Sprint 3 — Accepted deviation review (CM-30)
No code change.

- [ ] **CM-30** — Confirm `docs/scope.md` + `docs/agent-context.md` still accurately scope the English tooltip-parsing deviation to `core/TooltipCache.lua`, and that classification stays `classID`/`subClassID`-based. Keep as a documented, intentional deviation; it closes only when full tooltip-text localization ships.

---

## Sequencing & decisions
- **Hard ordering:** CM-24 → CM-25 (the shared seam must be secret-safe from its first commit). CM-26/27/28 sit in the same file as CM-25 and are cleanest in that pass. Sprints 2 and 3 are independent and can be done in any order after Sprint 1.
- **Open decision (CM-32):** Wago ID vs. Curse-only tracked deviation — surface to the user before touching the TOC.
- **Definition of done:** all boxes checked (or CM-30/CM-32 explicitly recorded as accepted deviations), both gates green, and a fresh `standards-audit` run shows no MUST failures beyond the documented tracked deviation(s).
