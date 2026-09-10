# Slash dispatch

`/cm` and `/consumablemaster` reach one dispatcher: the **LibKa0s-Slash-1.0** instance built in
`settings/Slash.lua`. The library owns the parse, the help renderer, the row and value formatters and
the schema CLI. This addon owns seventeen verbs, five sub-command tables with three different handler
arities, the dump targets and the codecs that keep a `/cm set` round-trip in this addon's own shape.

Both halves of `documentation-§3`'s trigger fire here — seventeen verbs is over eight, and four verbs
carry a subcommand tree — which is why this page exists rather than a table in `ARCHITECTURE.md`.

## Where the pieces live

Three files, and the split is deliberate:

| File | Owns |
|---|---|
| `settings/Slash.lua` | The **dispatch** — the ordered `COMMANDS` table, the library descriptor and instance, the degraded arm, and the two entry points the rest of the addon calls. |
| `core/SlashCommands.lua` | The **verb bodies** — the `priority`, `stat`, `aio` and `bar` namespaces and their sub-command tables. It publishes five entry points on `KCM.SlashCommands.Verbs` and knows nothing about how they are dispatched. |
| `core/SlashDump.lua` | The `dump` targets and their own dispatcher, published as `KCM.SlashDump.Dispatch`. |

`layout-§1` puts `settings/` after `core/`, so `KCM.SlashCommands.Verbs` is already populated when
`COMMANDS` is built. That is why `settings/Slash.lua:32` resolves it once at load rather than per
call: a missing key there would be a load-order bug worth failing loudly on, not a condition to
tiptoe around.

## The `COMMANDS` table

`COMMANDS` (`settings/Slash.lua:84`) is an ordered list of positional triples
`{name, description, fn(rest)}`, published as `KCM.COMMANDS` at `:196` so the verb set has one source
of truth (`slash-commands-§4`). Nothing reads that table directly to render anything — the About page
asks `KCM.SlashCommands.GetLandingRows()`, which delegates to the library instance built from the
same table — so `KCM.COMMANDS` is the identity handle the suite asserts against rather than a second
renderer's input.

The seventeen verbs, in declaration order, which is also the order `/cm help` and the About page
print them:

| Verb | Backed by | Behavior |
|---|---|---|
| `help` | library | Header plus one row per `COMMANDS` entry. |
| `config` | host | `KCM.Options.Open()`, and says so plainly when the panel is not registered. |
| `version` | host | `v<version>` from the TOC metadata through `core/EnvSetup.lua`. |
| `perf` | LibKa0s-Perf | Resolves `KCM.Perf` at **call** time, prints the lines it returns. |
| `debug` | host | Bare toggles the console window; `on`/`off` set logging through `DebugLog.SetEnabled`. |
| `resync` | host | Invalidate the tooltip cache, run auto-discovery, recompute every category. |
| `rewritemacros` (alias `rewrite`) | host | Invalidate macro state and rewrite every body and icon. |
| `reset <path>` | library | Reset **one** schema row to its default. |
| `resetall` | host | The confirm-gated global wipe, via `StaticPopup_Show("KCM_CONFIRM_RESET")`. |
| `list` | library | Every schema row and its value, grouped by the row's `panel`. |
| `get <path>` | library | One row's value. |
| `set <path> <value>` | library | Type-aware parse, then `Helpers.SetAndRefresh`. |
| `bar` | host | The macro-bar tree. |
| `priority` | host | The per-category priority tree. |
| `stat` | host | The per-spec stat tree. |
| `aio` | host | The composite-category tree. |
| `dump` | host | The dump targets. |

`config`, `resync` and `rewritemacros` all say something when they cannot do the thing: `resync` and
`rewritemacros` announce that picks are computed now and macro writes land when combat ends, rather
than appearing to have worked.

## `reset` takes a path; `resetall` is the wipe

A **breaking** change made 2026-08-01 ([LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)).
`reset` used to be the confirm-gated global wipe. It is now the library's path-scoped reset, matching
`/at reset <path>` and `/kcd reset <path>`, and the wipe moved down one row to `resetall` with its
popup intact.

A bare `/cm reset` must not silently do the smaller thing, so `USAGE_RESET` is overridden in
`SLASH_STRINGS` to name `resetall` explicitly. The library's stock line is a bare
`Usage: %s reset <path>`, which would let somebody with `/cm reset` in a macro watch a global wipe
quietly become a one-row reset and never learn the verb changed meaning.

`resetall` stays **host-owned** rather than binding `Sl:CliResetAll`, and that is not an oversight:
the library's `resetall` walks the schema rows, and this addon's global reset is
`KCM.ResetAllToDefaults`, which also wipes the priority lists and the stat overrides — data the
schema does not describe.

## The sub-command trees

Four verbs dispatch a sub-verb of their own, from five ordered tables in two files. Every one of them
is a table plus a `findCommand` lookup — never an `if` ladder — so the help output and the dispatch
read the same rows and cannot drift.

| Verb | Table | Shape | Sub-verbs |
|---|---|---|---|
| `priority` | `PRIORITY_COMMANDS` (`core/SlashCommands.lua:425`) | `<cat> <sub> [args]` | `list`, `add`, `remove`, `up`, `down`, `reset` |
| `stat` | `STAT_COMMANDS` (`:569`) | `<sub> [args]` | `list`, `primary`, `secondary`, `reset` |
| `aio` | `AIO_COMMANDS` (`:740`) | `<key> <sub> [args]` | `list`, `toggle`, `up`, `down`, `reset` |
| `bar` | `BAR_COMMANDS` (`:793`) | `<sub>` | `on`, `off`, `lock`, `unlock`, `reset` |
| `dump` | `DUMP_TARGETS` / `DUMP_ORDER` (`core/SlashDump.lua:24`, `:374`) | `<target> [args]` | `categories`, `statpriority`, `bags`, `item`, `pick` |

**Three handler arities, and each one is forced by its grammar.** `priority` and `aio` resolve a
category before dispatching, so their handlers take `(cat, rest)` — the resolve happens once, in the
verb, and a sub-verb never re-derives it. `stat` takes `(rest)`, because its optional `specKey`
trails the sub-verb rather than preceding it. `bar` takes `()`: its five sub-verbs are complete
sentences with nothing left to parse.

**A bare tree prints its own help, and each help is generated from the table it dispatches on** —
`priorityHelp` and `aioHelp` append the known category keys, `statHelp` explains the `specKey`
grammar, `barHelp` prints the bar's current on/off and locked state first. An unknown sub-verb prints
`unknown <verb> subcommand '<name>'` and then that same help, so a typo lands on the list of what was
meant.

**Two of them have a bare-form default rather than help.** `/cm priority <cat>` with no sub-verb
lists that category, and `/cm aio <key>` with no sub-verb lists that composite, because a naked
category name reads as "show me this one". `/cm bar` with no sub-verb **toggles**, matching how
`/cm debug` reads as a switch. `/cm dump <itemID>` is the same instinct spelled with a number: a
numeric head routes to the `item` target rather than failing as an unknown target name.

Adding a sub-verb is one row in the relevant table. Adding a dump target is one `DUMP_TARGETS` entry
plus one `DUMP_ORDER` name — the order table exists so help output is stable rather than hash-ordered.

## Case-preserving parse

The library lowercases the verb and leaves the remainder alone, and every tree below repeats the rule
through `lowerFirst`: the sub-verb folds, its arguments do not. Schema paths are case-sensitive
(`/cm set macroBar.iconSize 32`), a stat `specKey` may arrive as `SHAMAN:ENHANCEMENT`, and a color is
several tokens whose internal spacing has to survive.

## Help output convention

```
Ka0s Consumable Master v1.6.0 — slash commands (alias: /consumablemaster)
  /cm help — Show this help
  /cm config — Open the settings panel
```

The header, the alias clause and the two usage lines this addon overrides are `SLASH_STRINGS`
(`settings/Slash.lua:224`) — a **plain** table, deliberately not `KCM.L`. `Sl:Text` resolves an
override with `rawget` precisely so a key-echoing locale table falls through to the library's own
wording, which also means `KCM.L` could never supply these. Two of the overrides are there for a
reason worth keeping in view:

- `HELP_ALIAS` takes `(alias, slash)` from the library and this addon has only ever named the alias,
  so the second argument is dropped. Harmless — `string.format` ignores a surplus argument.
- `USAGE_GET` carries **one** `%s`, not two. `Sl:CliGet` formats it with `d.slash` alone, so a second
  placeholder is not an unused argument but a **missing** one, and `string.format` raises. A bare
  `/cm get` threw a Lua error in game for exactly as long as that line had two.

Every line goes out through `KCM.Say` (`core/CoreSetup.lua`, over `KCM.PREFIX` from `core/Constants.lua`), the secret-safe sink: the `[CM]` tag is
unconditional and a combat secret can never raise mid-line. The printer crosses to the library as a
thunk rather than bare, because the library snapshots it at `:New`.

## When the library is absent

LibKa0s is vendored, so a missing `LibKa0s-Slash-1.0` is a tampered install rather than a supported
state. It still has to behave.

`LIB_BACKED_VERBS` (`settings/Slash.lua:80`) names the six verbs that actually route through the
library — `help`, `list`, `get`, `set`, `reset` and `perf`. Everything else is the host's own and
keeps working. The degraded notice is **computed from `COMMANDS`** rather than hand-written, so a new
verb cannot silently fall out of the "these still work" list. The line the addon used to print said
`/cm is unavailable`, which was untrue of eleven of the seventeen verbs and told the player to stop
typing commands that worked.

The notice is not latched. A degraded install that explains itself once and then goes silent is worse
than one that answers every time — this line only ever fires because the user typed.

`degradedDispatch` (`settings/Slash.lua:392`) is deliberately **not** a second dispatcher: no help
renderer, no sub-command tables, no landing rows. It trims, splits, lowercases the verb, applies the
one alias and looks the verb up in `COMMANDS` — the same five steps the library's own `OnSlash`
takes, because doing fewer would change what the same typed line means depending on whether the
library loaded. The one alias, `rewrite` → `rewritemacros`, is a file local read by both arms, because
two alias tables for one addon is the drift the convergence collapsed.

`GetLandingRows` returns an **empty** list in that state rather than a host-formatted fallback: with
LibKa0s missing the settings panel is never registered, so there is no About page to render into, and
a second formatter kept alive just in case is the divergence coming straight back.

## Adding a verb

One row in `COMMANDS`. If it needs a body of any size, the body goes in `core/SlashCommands.lua` and
is published on `KCM.SlashCommands.Verbs`; `settings/Slash.lua` stays "how `/cm` is parsed" and never
grows a second opinion about it. If it is library-backed, add its name to `LIB_BACKED_VERBS` so the
degraded notice stays true.

## See also

- [ARCHITECTURE.md](./ARCHITECTURE.md#slash-commands) — the summary and the file split in context.
- [debug.md](./debug.md) — what `/cm debug` and `/cm dump` reach.
- [schema.md](./schema.md) — the rows `/cm list`, `/cm get` and `/cm set` walk.
- [settings-panel.md](./settings-panel.md) — the panel affordances these verbs share a seam with.
- [macro-bar.md](./macro-bar.md) — what `/cm bar` is driving.
