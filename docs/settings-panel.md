# Settings panel

The Blizzard-canvas options UI: how the pages are registered, what each one covers, and how a control
reaches the stored value. The persisted shape those controls write into is [schema.md](./schema.md);
the recompute they trigger is [data-flow.md](./data-flow.md).

## Shape

One `Settings.RegisterCanvasLayoutCategory` **parent** — the landing page — plus one
`RegisterCanvasLayoutSubcategory` **body per page**, of which there are four. There is no
AceConfigDialog anywhere in the addon:
pages are built from raw AceGUI widgets on a Blizzard canvas (`options-ui-§2`). The canvas shell, the
page registry, the widget makers and the two-column flow engine are **LibKa0s-Options-1.0's**, wired
in `settings/OptionsSetup.lua`; `settings/Panel.lua` owns registration and the shared header (title +
atlas divider) built by `Helpers.CreatePanel`.

Each page module hands a **builder** to `RegisterTab`; `settings/Panel.lua` iterates the builders once
`Blizzard_Settings` is ready, driven by its own `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap.

### Tabs, not sub-pages

Two of the four pages carry a **pinned tab strip** in the page's chrome band (`options-ui-§13`):
only the active tab's body draws, and the strip wraps onto as many rows as the canvas width needs.

The **Macros** page is why. Every macro category used to be its own `RegisterCanvasLayoutSubcategory`
entry — fifteen rows in the AddOns sidebar for fifteen variations on one surface, and eighteen
sub-pages in all. They are one page with fifteen tabs now, and the sidebar is down to four entries.
The strip is **generated** from `KCM.Categories.LIST` in `KCM.Settings.macroOrder`, exactly as the
fifteen builders were: a sixteenth category is a row in `Categories.LIST` plus a key in `macroOrder`,
and it gets a tab for free. There is no hand-written tab list, for the reason `options-ui-§13` gives
against one — a list declared apart from the data goes stale the first time a category is renamed and
nothing says so.

The **Macro Bar** page's eight tabs are its schema rows' `group` values, partitioned in **declaration
order**. That is the same rule, one level down: the tab is the row's own field, so the strip cannot
name a section the rows do not have. It also means a group's rows must be **contiguous** — a row filed
under a group the page has already left draws that tab a second time — which `tests/test_schema.lua`
pins.

**General** draws no strip either, for the same reason Stat Priority does not: the master switch and
the maintenance buttons are one subject. And there is no Ace3 **Profiles** page here to leave alone —
this addon ships no profile control at all (`AceDBOptions` is not vendored; `libs/` holds AceAddon,
AceConsole, AceDB, AceEvent, AceGUI and the SharedMedia widgets), and it runs on a single AceDB
profile.

### The page banner

**Stat Priority** carries a page **banner** instead of a strip (`options-ui-§14`): the viewed-spec
picker, pinned above the scroll, naming what the page is editing. It was a `Selection` section inside
the scroll before, which put the control that governs the six dropdowns below it out of sight the
moment you scrolled to them.

It is the **only** picker for that state, which is `§14`'s rule — a banner replaces a picker, it never
mirrors one. The spec-aware tabs on the Macros page (Flask, Combat Potion, Stat Food, Weapon Enchant)
therefore **state** the viewed spec as a sentence and offer no second picker of their own; two
controls over one piece of session state is a synchronisation problem the design would have invented
and then owned forever.

With the picker in the banner the page has one subject left, so it draws no strip: a single tab is
chrome for its own sake and its band would push the page down for nothing.

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

## Page | Covers

Display order is `KCM.Settings.order` (`settings/Panel.lua`) — four pages, in the order a player meets
them: the master switch, the macros themselves, the ranking the spec-aware categories sort by, and
last the optional bar that displays the finished macros.

| Page | Strip | Covers |
|---|---|---|
| **General** | none | Master `enabled` toggle and the debug-console checkbox; the Maintenance actions — Force resync, Force rewrite macros, Reset all priorities. Two short sections on one scroll: a strip over two controls and three buttons would be chrome for its own sake |
| **Macros** | 15 tabs | One tab per macro category — the per-category priority list, add-by-ID, and the discovered/added/blocked/pinned sets. The whole subject of the addon |
| **Stat Priority** | banner | Per-spec stat ordering: the spec picker in the page banner, then Primary and Secondary #1-#4 |
| **Macro Bar** | 8 tabs | The optional on-screen macro bar — 54 of the addon's 55 schema rows live here |

### The Macros strip, in tab order

`KCM.Settings.macroOrder`. The basic consumables first, because they are what a player opens the page
for; the two AIO composites next, after the categories they aggregate; then the spec-aware set plus
Augment Rune; then the three that are set once per tier and left.

| # | Tab | |
|---|---|---|
| 1-5 | **Food** · **Drink** · **Healing Potion** · **Mana Potion** · **Healthstone** | Per-category priority list, add-by-ID, and the discovered/added/blocked/pinned sets |
| 6-7 | **AIO Health** · **AIO Mana** | The two composite buckets, which draw their members from the tabs above |
| 8-12 | **Flask** · **Combat Potion** · **Stat Food** · **Weapon Enchant** · **Augment Rune** | Spec-aware categories — the same per-category surface, resolved against the spec named in the Stat Priority banner |
| 13-15 | **Vantus Rune** · **Bloodlust** · **Battle Rez** | Remaining categories, same surface |

Tabs are labelled with each category's `displayName`, never its `shortName`: `shortName` exists for
the macro bar's 32px buttons, where "Brez" and "Rune" are the only thing that fits, and a tab reading
"Rune" two places from one reading "Vantus" would say nothing about which rune it meant.

Every category tab renders the same sections, built by `settings/Category.lua`: **Add item or spell by
ID**, **Priority list**, and the per-set sections — added, blocked, pinned, discovered. The two
composite tabs render **In Combat** / **Out of Combat** instead.

### The Macro Bar strip, in tab order

`KCM.Settings.MACROBAR_TABS`, and each tab's name is the `group` its rows declare.

| # | Tab | Rows |
|---|---|---|
| 1 | **General** | 2 — enable, lock; plus Reset position / Reset slot order |
| 2 | **Layout** | 8 — per row, button size, spacing, padding, scale, orientation, both growth directions |
| 3 | **Bar appearance** | 7 — backdrop, border, border style/size, both colors, bar opacity |
| 4 | **Button appearance** | 11 — the same three questions as Bar appearance, in the same order, plus border offset, icon zoom, stack count, tooltips, GCD swipe |
| 5 | **Labels** | 9 — show, text, anchor, placement, both offsets, scale, color, outline |
| 6 | **Flyout** | 14 |
| 7 | **Visibility** | 3 — combat mode, fade unless hover, faded opacity |
| 8 | **Contents** | 0 schema rows — one checkbox per managed macro, a length no schema knows |

Two tabs were renamed in the redesign. *Bar* became **General**: on a page called Macro Bar the word
carried nothing, and it collided with *Bar appearance* two tabs along. *Macros on the bar* became
**Contents**, for the same reason — every tab on the page is about the bar. *Bar appearance* and
*Button appearance* **keep** their qualifiers, because two surfaces coexist on this page and each has
a backdrop and a border of its own; there the word is doing real work.

## How a control reaches the value

Two different paths, and the difference is what a row shape can express.

**Schema-backed controls** are rows in `KCM.Settings.Schema` — an ordered array published by
`settings/Panel.lua` and appended to by the tab files. One row is simultaneously three things: the
widget on its page, the `/cm list|get|set|reset <path>` CLI entry (`settings/Slash.lua:283` hands the
whole array to LibKa0s-Slash-1.0 as `allRows`), and the validator applied on write by the `Resolve` →
`SetAndRefresh` seam. `grep -c '^\s*path\s*=' settings/*.lua` reports **55**: 54 `macroBar.*` rows in
`settings/MacroBar.lua`, plus the master `enabled` row in `settings/Panel.lua`. Adding a row gains all
three surfaces at once — never write a parallel mutator for a path that already has one.

**Bespoke controls** are everything a `{ path, type }` row cannot describe, and they are deliberate,
not gaps:

- The **per-category priority lists** and the **per-spec stat priorities** are collections, not
  scalars. No row shape describes them, which is also why `/cm resetall` stays host-owned rather than
  adopting the library's `Sl:CliResetAll` (closed issue [LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)).
- The **Add-by-ID box** takes free text, not a scalar. `submitAddByID` (`settings/Category.lua:414`)
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
- **Sections** are introduced by `H.Section(ctx, label)`, never a bare bold line. On a tabbed page the
  tab strip replaces the headings it used to draw — a heading under a tab of the same name says the
  same thing twice.
- **Tab strips** come from `H.TabStrip(ctx, { tabs, value, onSelect })` (`options-ui-§13`) and the page
  banner from `H.PageBanner(ctx, { label, list, order, value, onSelect })` (`§14`). Both are the
  library's, both live in the page's chrome band above the scroll, and the banner is drawn first
  because it reserves the share of the band the strip then places itself under.
- **Action buttons** use `H.ButtonPair` / `H.Button`, and a destructive one is confirm-gated through a
  `StaticPopup` — *Reset all priorities* raises `KCM_RESET_ALL` rather than acting on click.
- Every user-visible string routes through `L[…]` (`localization-§1`).
