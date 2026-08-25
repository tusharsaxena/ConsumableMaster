# Settings panel

The Blizzard-canvas options UI: how the pages are registered, what each one covers, and how a control
reaches the stored value. The persisted shape those controls write into is [schema.md](./schema.md);
the recompute they trigger is [data-flow.md](./data-flow.md).

## Shape

One `Settings.RegisterCanvasLayoutCategory` **parent** — the landing page — plus one
`RegisterCanvasLayoutSubcategory` **body per tab**. There is no AceConfigDialog anywhere in the addon:
pages are built from raw AceGUI widgets on a Blizzard canvas (`options-ui-§2`). The canvas shell, the
page registry, the widget makers and the two-column flow engine are **LibKa0s-Options-1.0's**, wired
in `settings/OptionsSetup.lua`; `settings/Panel.lua` owns registration and the shared header (title +
atlas divider) built by `Helpers.CreatePanel`.

Each tab module hands a **builder** to `RegisterTab`; `settings/Panel.lua` iterates the builders once
`Blizzard_Settings` is ready, driven by its own `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap.

### `Helpers` is a live view, not a snapshot

`KCM.Settings.Helpers` is the addon's own half of the framework **and** the published view of the
LibKa0s-Options-1.0 instance: `settings/OptionsSetup.lua` creates the table and installs the instance
as its `__index`, so every library member resolves off the **live** instance at call time rather than
off a snapshot taken at file load. That is the whole point of the indirection. The copy-across this
replaced re-exported eleven members by hand, and any member the list forgot — or any member bound
while `UI` was still `nil` — read back `nil` at the call site with no way to tell it apart from a
member the library never had (`options-ui-§1`). The addon's own wrappers stay as **own** keys and
shadow the library's same-named function, which is what lets `Section` / `CreatePanel` / `LSMValues`
call the instance's version without recursing into themselves.

### Combat gate

Opening is refused in combat, not deferred (`options-ui-§2`). Both the `O.Open` slash path and the
Blizzard AddOns-sidebar `OnShow` guard funnel through one helper so the refusal emits a single
canonical gray notice through the shared secret-safe printer — never a protected category switch and
never a silent no-op.

## Tab | Covers

Display order is `KCM.Settings.order` (`settings/Panel.lua:36`) — the source of truth for the sub-page
sequence, deliberately independent of `Categories.LIST` and functionally cosmetic. General and Stat
Priority lead, then the basic consumables, the two AIO composites, the spec-aware categories plus
Augment Rune, then Vantus Rune, Bloodlust and Battle Rez last.

| Tab | Covers |
|---|---|
| **General** | Master `enabled` toggle and the debug-console checkbox; the Maintenance actions — Force resync, Force rewrite macros, Reset all priorities |
| **Stat Priority** | Per-spec stat ordering: the spec Selection control (auto-track or pin a spec) and the Priority list |
| **Macro Bar** | The optional on-screen macro bar — 54 of the addon's 55 schema rows live here |
| **Food** · **Drink** · **Healing Potion** · **Mana Potion** · **Healthstone** | Per-category priority list, add-by-ID, and the discovered/added/blocked/pinned sets |
| **AIO Health** · **AIO Mana** | The two composite buckets, which draw their members from the categories above |
| **Flask** · **Combat Potion** · **Stat Food** · **Weapon Enchant** · **Augment Rune** | Spec-aware categories — the same per-category surface, resolved against the tracked spec |
| **Vantus Rune** · **Bloodlust** · **Battle Rez** | Remaining categories, same surface |

Every category tab renders the same three sections, built by `settings/Category.lua`: **Add item or
spell by ID** (`:423`), **Priority list** (`:599`), and the per-set sections (`:643`) — added, blocked,
pinned, discovered. The Stat Priority page renders **Selection** (`:218`) and **Priority** (`:233`).

## How a control reaches the value

Two different paths, and the difference is what a row shape can express.

**Schema-backed controls** are rows in `KCM.Settings.Schema` — an ordered array published by
`settings/Panel.lua` and appended to by the tab files. One row is simultaneously three things: the
widget on its tab, the `/cm list|get|set|reset <path>` CLI entry (`settings/Slash.lua:283` hands the
whole array to LibKa0s-Slash-1.0 as `allRows`), and the validator applied on write by the `Resolve` →
`SetAndRefresh` seam. `grep -c '^\s*path\s*=' settings/*.lua` reports **55**: 54 `macroBar.*` rows in
`settings/MacroBar.lua`, plus the master `enabled` row in `settings/Panel.lua`. Adding a row gains all
three surfaces at once — never write a parallel mutator for a path that already has one.

**Bespoke controls** are everything a `{ path, type }` row cannot describe, and they are deliberate,
not gaps:

- The **per-category priority lists** and the **per-spec stat priorities** are collections, not
  scalars. No row shape describes them, which is also why `/cm resetall` stays host-owned rather than
  adopting the library's `Sl:CliResetAll` (closed issue [LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)).
- The **Add-by-ID box** takes free text, not a scalar. `submitAddByID` (`settings/Category.lua:397`)
  tries digits first — a bare number is unambiguous and must never reach a link matcher — then the
  selected kind's own `fromLink` parser, so a **shift-clicked item or spell link** is accepted as
  readily as a typed ID. ITEM goes through the `KCM.Item` seam onto `LibKa0s-Item-1.0`'s
  `ItemIDFromLink`; SPELL parses the spell link it alone can receive. A link of the *wrong* kind is
  refused rather than cross-filed, because an item link parsed as a spell would store an itemID
  behind the opaque spell sentinel and collide with a real spell ID. Every rejection says why and
  keeps the typed text.
- The **debug-console checkbox** shows and hides the console *window* only — it never touches the
  session debug flag `KCM.State.debug`, exactly like a bare `/cm debug` (`debug-logging-§5`). Logging
  is armed separately, via the in-window `Debug: ON/OFF` toggle or `/cm debug on|off`. Its spec comes
  from the **library** — `DL.instance:ConsoleCheckbox()` returns the `{ label, tooltip, get, set }`
  shape `CustomCheckbox` already consumes — so the wording and the visibility semantics cannot drift
  from the window they describe (`LIBKA0S-06`: one description of the console, owned by the console).
  `KCM.State.debug` is session-only and never persisted, so it has no path to declare.

## Layout rules

- **Two-column paired grid** (`options-ui-§6`). Consecutive rows pair into left/right cells;
  `H.Grid(ctx, { … })` takes the item list, and a row marked wide takes the full width.
- **Sections** are introduced by `H.Section(ctx, label)`, never a bare bold line.
- **Action buttons** use `H.ButtonPair` / `H.Button`, and a destructive one is confirm-gated through a
  `StaticPopup` — *Reset all priorities* raises `KCM_RESET_ALL` rather than acting on click.
- Every user-visible string routes through `L[…]` (`localization-§1`).
