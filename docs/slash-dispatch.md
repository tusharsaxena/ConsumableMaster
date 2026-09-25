# Slash dispatch

`/cm` and `/consumablemaster` reach one dispatcher: the **LibKa0s-Slash-1.0** instance built in
`settings/Slash.lua`. The library owns the parse, the help renderer, the row and value formatters and
the schema CLI. This addon owns twenty-one verbs, five sub-command tables with three different handler
arities, the dump targets and the codecs that keep a `/cm set` round-trip in this addon's own shape.

Both halves of `documentation-§3`'s trigger fire here — twenty-one verbs is over eight, and four verbs
carry a subcommand tree — which is why this page exists rather than a table in `ARCHITECTURE.md`.

## Where the pieces live

Three files, and the split is deliberate:

| File | Owns |
|---|---|
| `settings/Slash.lua` | The **dispatch** — the ordered `COMMANDS` table, the library descriptor and instance, the degraded arm, and the two entry points the rest of the addon calls. |
| `core/SlashCommands.lua` | The **verb bodies** — the `priority`, `stat`, `aio` and `bar` namespaces and their sub-command tables. It publishes six entry points on `KCM.SlashCommands.Verbs` and knows nothing about how they are dispatched. |
| `core/SlashDump.lua` | The `dump` targets and their own dispatcher, published as `KCM.SlashDump.Dispatch`. |

`layout-§1` puts `settings/` after `core/`, so `KCM.SlashCommands.Verbs` is already populated when
`COMMANDS` is built. That is why `settings/Slash.lua:40` resolves it once at load rather than per
call: a missing key there would be a load-order bug worth failing loudly on, not a condition to
tiptoe around.

## The `COMMANDS` table

`COMMANDS` (`settings/Slash.lua:163`) is an ordered list of positional triples
`{name, description, fn(rest)}`, published as `KCM.COMMANDS` at `:358` so the verb set has one source
of truth (`slash-commands-§4`). Nothing reads that table directly to render anything — the About page
asks `KCM.SlashCommands.GetLandingRows()`, which delegates to the library instance built from the
same table — so `KCM.COMMANDS` is the identity handle the suite asserts against rather than a second
renderer's input.

The twenty-one verbs, in declaration order, which is also the order `/cm help` and the About page
print them:

| Verb | Backed by | Behavior |
|---|---|---|
| `help` | library | Header plus one row per `COMMANDS` entry. |
| `config` | host | `KCM.Options.Open()`, and says so plainly when the panel is not registered. |
| `version` | host | `v<version>` from the TOC metadata through `core/EnvSetup.lua`. |
| `enable` | host | Writes `enabled = true` through `Helpers.SetAndRefresh` — the Master controls checkbox's own path and seam — then echoes the stored value through the library's shared `path = value` formatter. |
| `disable` | host | The same write with `false`. Neither verb holds state of its own (`slash-commands-§2`); with `libs/LibKa0s/` absent there is no `enabled` row to write and both say so rather than going inert. |
| `perf` | LibKa0s-Perf | Resolves `KCM.Perf` at **call** time, prints the lines it returns. |
| `debug` | host | Bare toggles the console window; `on`/`off` set logging through `DebugLog.SetEnabled`. |
| `resync` | host | Invalidate the tooltip cache, run auto-discovery, recompute every category. |
| `rewritemacros` (alias `rewrite`) | host | Invalidate macro state and rewrite every body and icon. |
| `reset <path>` | library | Reset **one** schema row to its default. |
| `resetall` | host | The confirm-gated whole-profile reset, via `StaticPopup_Show("KCM_CONFIRM_RESET")` — the same popup the General page's *Reset all settings* raises. |
| `list` | library | Every schema row and its value, grouped by the row's `panel`. |
| `get <path>` | library | One row's value. |
| `set <path> <value>` | library | Type-aware parse, then `Helpers.SetAndRefresh`. |
| `bar` | host | The macro-bar tree. |
| `lock` / `unlock` | host | The macro bar's lock, through `V.RunLock` — the canonical spelling of what `bar lock` / `bar unlock` also do. |
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

**One act, one popup, both doors.** `KCM_CONFIRM_RESET` (`core/SlashCommands.lua`) is the only
global-reset confirmation: `/cm resetall` and the General page's *Reset all settings* both raise it
by name. Everything a door used to add on its own is inside `KCM.ResetAllToDefaults` now — it refuses
under `InCombatLockdown` before any write (`false, "combat"`), answers `false, "db"` before the
database exists, and repaints every open panel on success. The popup's `OnAccept` switches on that
second return: *Reset complete — defaults restored.*, *in combat — reset deferred until regen.* (the
General page's own combat wording), or *Reset failed (DB not ready).*

## The sub-command trees

Four verbs dispatch a sub-verb of their own, from five ordered tables in two files. Every one of them
is a table plus a `findCommand` lookup — never an `if` ladder — so the help output and the dispatch
read the same rows and cannot drift.

| Verb | Table | Shape | Sub-verbs |
|---|---|---|---|
| `priority` | `PRIORITY_COMMANDS` (`core/SlashCommands.lua:451`) | `<cat> <sub> [args]` | `list`, `add`, `remove`, `up`, `down`, `reset` |
| `stat` | `STAT_COMMANDS` (`:602`) | `<sub> [args]` | `list`, `primary`, `secondary`, `reset` |
| `aio` | `AIO_COMMANDS` (`:807`) | `<key> <sub> [args]` | `list`, `toggle`, `up`, `down`, `reset` |
| `bar` | `BAR_COMMANDS` (`:930`) | `<sub>` | `on`, `off`, `lock`, `unlock`, `reset` |
| `dump` | `DUMP_TARGETS` / `DUMP_ORDER` (`core/SlashDump.lua:24`, `:392`) | `<target> [args]` | `categories`, `statpriority`, `bags`, `item`, `pick`, `events` |

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

**`lock` / `unlock` are top-level verbs, and `bar lock` / `bar unlock` are kept beside them**
(`slash-commands-§8`). Both are reserved verbs across the collection and both mean *lock the addon's
frames*; whether an addon registers them at all is a **MAY**, and this addon now takes it. All four
spellings share one body — `runLock` in `core/SlashCommands.lua`, published as `V.RunLock` — which
writes `macroBar.locked` through `KCM.MacroBar.SetLocked`, the same `KCM.Schema:Set` seam the *Lock
frame* checkbox and the launcher menu's *Locked* entry take. So there is one value, one `apply` and one
confirmation line, never a `KCM.locked` local beside them and never a second implementation hiding
behind the second spelling.

**This reverses an earlier decision, and the reasoning is worth keeping.** The top-level pair was
declined on the grounds that it bought the addon one fewer spelling of the same act at a cost of two
words to the player. That traded the wrong way round in practice. `/cm unlock` is what the rest of
the collection answers to (`/pfe lock`, `/pfe unlock`); it is what the bar's own tooltip sends a
player off to type; and `findCommand` matches EXACTLY, so the guess every other addon rewards landed
on `unknown command` here — a player who typed it got no bar movement and no clue why. The sub-tree
stays because it is the Macro Bar page's CLI parity and `/cm bar help` should still list everything
the bar can be told to do. A MAY taken is no more a deviation than a MAY declined, and neither owes
the register a row.

The top-level form is the **canonical** one: it is what the bar's tooltips (`modules/MacroBar.lua`),
the launcher's unlock reply and the README all name. Both are **feature verbs**, so they refuse while
the addon is disabled: unlocking a frame that is not drawn is not a coherent request, and the refusal
names the step the player actually needs.

Adding a sub-verb is one row in the relevant table. Adding a dump target is one `DUMP_TARGETS` entry
plus one `DUMP_ORDER` name — the order table exists so help output is stable rather than hash-ordered.

## Case-preserving parse

The library lowercases the verb and leaves the remainder alone, and every tree below repeats the rule
through `lowerFirst`: the sub-verb folds, its arguments do not. Schema paths are case-sensitive
(`/cm set macroBar.iconSize 32`), a stat `specKey` may arrive as `SHAMAN:ENHANCEMENT`, and a color is
several tokens whose internal spacing has to survive.

A bare `/cm`, empty or only whitespace, is not a verb. Since LibKa0s-Slash-1.0 minor 11 (LibKa0s
v1.38.0) the library runs the `config` row's body with an empty argument, so the settings panel opens
on its About landing page (`slash-commands-§4`). `/cm help` prints the index. Before minor 11 a bare
`/cm` printed the index, and a host with no `config` row still gets that.

## Help output convention

```
Ka0s Consumable Master v1.6.2 — slash commands (alias: /consumablemaster)
  /cm help — Show this help
  /cm config — Open the settings panel
```

The header, the alias clause and the two usage lines this addon overrides are `SLASH_STRINGS`
(`settings/Slash.lua:393`) — a **plain** table, deliberately not `KCM.L`. `Sl:Text` resolves an
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

## While the addon is disabled, the slash surface is UNCHANGED

The addon itself is not — it stands down completely, and what that means is
[the disabled state](./ARCHITECTURE.md#the-disabled-state-is-total). The command surface is a
separate question, and the answer is that it keeps working: **the dispatcher and the settings
registration are SETUP, not features** (`slash-commands-§7`), so keeping them live costs nothing the
stand-down was trying to reclaim. The addon is inert; its command surface is not the addon.

Every reserved verb answers, and **the bare `/cm` opens the settings panel** exactly as it does when
the addon is running. That last case is the one that settled it: the standard narrowed this surface
to `enable` and `help` at v2.56.0, the owner hit `/cm` on a disabled addon expecting the panel — the
one surface from which it can be switched back on by hand — got a refusal, and v2.57.0 reversed the
narrowing. A rule that makes the off switch harder to find has misunderstood which half of the pair
it protects.

**Only this addon's own FEATURE verbs refuse**, which is `slash-commands-§2`'s SHOULD and survived
the reversal unchanged: a verb that **drives the addon's features** answers, while `enabled` is
false, on **one** tagged line naming `/cm enable`, and does nothing else. Acting is the wrong answer
twice over — the player asked for something the addon is standing down from doing, and a silent
no-op leaves them no clue why nothing happened. This addon's no-op really was silent:
`macrosEnabled()` gated the macro write pass and nothing else, so `/cm resync` while disabled ran the
pipeline and then announced *recomputed all categories.* over a pass that wrote no macro at all.

**The gate is the dispatcher library's** (`LibKa0s-Slash-1.0` minor 13), not this addon's. The host's
half is three descriptor fields in `settings/Slash.lua` — `isEnabled`, `brandName` and `liveVerbs` —
and nothing else. `isEnabled` is asked at dispatch time and never cached, so the command after an
`/cm enable` works. The table-level wrap this addon carried before minor 12 is gone: a second gate
beside the library's would have to agree with it about which verbs are live and about how the
refusal is worded, which is the drift the shared dispatcher exists to end.

**The live set is `liveVerbs`, named once as data**, and it **WIDENS** the library's twelve by one —
it must never be used to narrow them. The twelve are `slash-commands-§2`'s, and the reasoning is that
a player must be able to read and repair settings, and to reach the panel, while the addon is off —
which is precisely when they are most likely to need to — and `enable` above all, or the pair is
one-way:

| Live while disabled | Refuses while disabled |
|---|---|
| `help`, `config`, `version`, `enable`, `disable`, `debug`, `perf`, `get`, `set`, `list`, `reset`, `resetall`, **`dump`** | `resync`, `rewritemacros`, `bar`, `lock`, `unlock`, `priority`, `stat`, `aio` |

`dump` is this addon's thirteenth and it is a judgment rather than a quote from the rule.
`core/SlashDump.lua`'s five targets print what they find and write nothing, recompute nothing and
invalidate nothing, so `dump` does not drive a feature — it reports on one, which is exactly what
`debug` and `perf` are live for. Refusing it would take the diagnostic away at the one moment
somebody is asking why the addon has gone quiet.

The refusal reads `Ka0s Consumable Master is disabled — enable it with /cm enable`, with the command
gold. **The wording is the collection's, not this addon's**: `slash-commands-§7` fixes one shape for
all eleven addons, `cli:DisabledLine()` builds it, and it MUST NOT be re-spelled per addon, per verb
or per call site — which is why it no longer goes through `KCM.L`. (The launcher no longer prints it
at all: since LibKa0s v1.58.0 its left click opens the panel in either state and its menu grays the
feature entries rather than refusing, `launcher-§2`.) It is **one line and nothing else**: no
partial work, no side effect, no second line. The rule stays a **SHOULD** in the standard — a
courtesy rather than a correctness property — and this addon takes it.

`/cm help` prints that same line immediately under its header and then the whole index. That is not
a refusal *of* `help`: the index answers in full, because the player has to be able to SEE `enable`
in the list. A **typo** is a different case again and gets `unknown command '<verb>'` plus the index
— the gate sits after the `COMMANDS` lookup, so a verb the addon ships and is standing down from is
refused, while a word it does not ship means the addon genuinely did not understand.

The cases (`tests/test_slash.lua`) assert **both halves**, that the verb said so *and* that it did
not act, because a case reading only the chat line passes over a verb that printed the refusal and
then did the thing anyway — which, given the silent no-op above, would look exactly like the bug. One
of them sweeps every entry in `KCM.COMMANDS`, so a verb added tomorrow is covered on the day it is
declared. `tests/test_disabled.lua` is where the surface as a whole is pinned — all twelve reserved
verbs, the bare `/cm`, and the shape of the refusal line itself.

## When the library is absent

LibKa0s is vendored, so a missing `LibKa0s-Slash-1.0` is a tampered install rather than a supported
state. It still has to behave.

`LIB_BACKED_VERBS` (`settings/Slash.lua:159`) names the six verbs that actually route through the
library — `help`, `list`, `get`, `set`, `reset` and `perf`. Everything else is the host's own and
keeps working. The degraded notice is **computed from `COMMANDS`** rather than hand-written, so a new
verb cannot silently fall out of the "these still work" list. The line the addon used to print said
`/cm is unavailable`, which was untrue of thirteen of the nineteen verbs and told the player to stop
typing commands that worked.

The notice is not latched. A degraded install that explains itself once and then goes silent is worse
than one that answers every time — this line only ever fires because the user typed.

`degradedDispatch` (`settings/Slash.lua:672`) is deliberately **not** a second dispatcher: no help
renderer, no sub-command tables, no landing rows. It trims, splits, lowercases the verb, applies the
one alias and looks the verb up in `COMMANDS` — the same five steps the library's own `OnSlash`
takes, because doing fewer would change what the same typed line means depending on whether the
library loaded. The one alias, `rewrite` → `rewritemacros`, is a file local read by both arms, because
two alias tables for one addon is the drift the convergence collapsed. A bare line runs `config` here
too, as the library's `OnSlash` does, and on this path `config` answers that the panel is unavailable.

**No feature verb refuses on this arm, and that is a decision rather than a gap.** The gate is the
library's from minor 13 and so is the refusal line; with `libs/LibKa0s/` absent there is no builder
to call and no format string to read, so the only way to refuse here would be to hand-copy the
sentence — which is precisely the one-place rule's whole subject, for a copy that would only ever run
on a tampered install. Nothing is owed: the feature-verb refusal is a **SHOULD**, an addon that
declines it is not deviating and owes no register row, and this build has already told the player on
its own line that half the surface is missing. The **stand-down** is a MUST and is not what is
skipped here — that arm has no `LibKa0s-Lifecycle-1.0` either, so a build with no library keeps the
old stored-flag behavior in full, which is the tampered install's problem and not a supported state.

**The composed-row verbs refuse on one library-absent line** (`options-ui-§1` route (b), CM-18).
`enable`, `disable`, `lock`, `unlock`, `bar lock` and `bar unlock` write rows the library's composers
build (`enabled`, `macroBar.locked`), and on this build those rows do not exist and there is no
stand-down latch to honor a stored switch. Each one prints
`/cm <verb> is unavailable: the LibKa0s library did not load.`, the standard's sentence through the
locale (`KCM.SlashCommands.SayLibraryAbsent`, `core/SlashCommands.lua`), writes nothing and raises
nothing. Taking route (b) for `enable`/`disable` is a recorded deviation
([ARCHITECTURE.md](./ARCHITECTURE.md#documented-deviations)). `bar`, `bar on` and `bar off` write the
hand-declared `macroBar.enabled` row, so they keep working here; like every macro-bar verb they print
their success line only when `KCM.MacroBar.SetEnabled` / `SetLocked` answered true, so no write the
seam refused is ever reported as done. `tests/test_slash_degraded.lua` pins all of it.

`GetLandingRows` returns an **empty** list in that state rather than a host-formatted fallback: with
LibKa0s missing the settings panel is never registered, so there is no About page to render into, and
a second formatter kept alive just in case is the divergence coming straight back.

## Adding a verb

One row in `COMMANDS`. If it needs a body of any size, the body goes in `core/SlashCommands.lua` and
is published on `KCM.SlashCommands.Verbs`; `settings/Slash.lua` stays "how `/cm` is parsed" and never
grows a second opinion about it. If it is library-backed, add its name to `LIB_BACKED_VERBS` so the
degraded notice stays true. It is **gated by default**: a new verb refuses while the addon is
disabled unless its name goes in `ALWAYS_LIVE` too, which is the safe direction for an omission and
is why the gate wraps the table rather than living in each body.

## See also

- [ARCHITECTURE.md](./ARCHITECTURE.md#slash-commands) — the summary and the file split in context.
- [debug.md](./debug.md) — what `/cm debug` and `/cm dump` reach.
- [schema.md](./schema.md) — the rows `/cm list`, `/cm get` and `/cm set` walk.
- [settings-panel.md](./settings-panel.md) — the panel affordances these verbs share a seam with.
- [macro-bar.md](./macro-bar.md) — what `/cm bar` is driving.
