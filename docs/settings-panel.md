# Settings panel

The Blizzard-canvas options UI: how the pages are registered, what each one covers, and how a control
reaches the stored value. The persisted shape those controls write into is [schema.md](./schema.md);
the recompute they trigger is [data-flow.md](./data-flow.md).

## Shape

One `Settings.RegisterCanvasLayoutCategory` **parent** — the landing page — plus one
`RegisterCanvasLayoutSubcategory` **body per page**, of which there are four. There is no
AceConfigDialog anywhere in the addon:
pages are built from raw AceGUI widgets on a Blizzard canvas (`options-ui-§2`). The canvas shell, the
page registry, the widget makers, the two-column flow engine, the tab strip and the schema
**composers** are all **LibKa0s-Options-1.0's**, wired in `settings/OptionsSetup.lua`;
`settings/Panel.lua` owns registration and the shared header (title + atlas divider) built by
`Helpers.CreatePanel`.

Each page module hands a **builder** to `RegisterTab`; `settings/Panel.lua` iterates the builders once
`Blizzard_Settings` is ready, driven by its own `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap.

### Every page draws a strip

**All four pages** carry a **pinned tab strip** in the page's chrome band (`options-ui-§13`): only the
active tab's body draws, and the strip wraps onto as many rows as the canvas width needs. That is not
a size threshold and not a choice — a Ka0s page has a strip, so a player who has learned one page has
learned all of them. A page with exactly **one** section draws a **one-tab** strip; the tab that
cannot be clicked is that page's section label.

The only exemptions are pages the host does not render through the flow engine at all: the
AceConfig-drawn **Profiles** sub-page (which this addon does not ship — `AceDBOptions` is not
vendored, and the addon runs on a single AceDB profile) and the **landing page**, whose body is
`Helpers.BuildAboutContent`.

The **Macros** page is why the strip exists here at all. Every macro category used to be its own
`RegisterCanvasLayoutSubcategory` entry — fifteen rows in the AddOns sidebar for fifteen variations on
one surface, and eighteen sub-pages in all. They are one page with fifteen tabs now, and the sidebar
is down to four entries. The strip is **generated** from `KCM.Categories.LIST` in
`KCM.Settings.macroOrder`, exactly as the fifteen builders were: a sixteenth category is a row in
`Categories.LIST` plus a key in `macroOrder`, and it gets a tab for free. There is no hand-written tab
list, for the reason `options-ui-§13` gives against one — a list declared apart from the data goes
stale the first time a category is renamed and nothing says so.

The **Macro Bar** page's eight tabs are its schema rows' `group` values, partitioned in **declaration
order**. That is the same rule, one level down: the tab is the row's own field, so the strip cannot
name a section the rows do not have. It also means a group's rows must be **contiguous** — a row filed
under a group the page has already left draws that tab a second time — which `tests/test_schema.lua`
pins.

**The strip's geometry does not depend on which tab is selected** (`options-ui-§13`,
anti-patterns #70). Both hand-drawn strips here wrap — fifteen tabs on Macros, eight on Macro Bar —
and the reserved chrome band and every wrapped row's offset are the same numbers for every value of
the selection. The pitch is measured once, from the **unselected** tab art, which no click can
change. That is the library's to get right; `tests/test_settingsui.lua` pins it on both pages under a
mock that answers a *different* height for the selected-state atlas, because a harness that answers
one height for every atlas cannot fail the case.

**A page never loses its strip for some state.** The Stat Priority page used to return before drawing
anything when no spec could be resolved; the strip is drawn first now and the empty state is content
inside the page. The Macros page had the same shape one step further in — it returned before the strip
whenever the category list came back empty — and it is gone for the same reason: the guard was
unreachable in the shipped configuration (`Categories.LIST` is a constant of fifteen), but
*unreachable today* is not *cannot render strip-less*, and the second is the rule. With no tabs the
library's own `#spec.tabs > 0` guard declines to draw one, because a zero-tab strip is not a strip;
the decision is the library's on the same terms for all nine addons rather than a host branch that
also skipped the page's whole body.

### The page banner

**Stat Priority** carries a page **banner** *and* a strip: the viewed-spec picker, pinned above the
scroll, naming what the page is editing (`options-ui-§14`). It was a `Selection` section inside the
scroll before, which put the control that governs the dropdowns below it out of sight the moment you
scrolled to them.

It is the **only** picker for that state, which is `§14`'s rule — a banner replaces a picker, it never
mirrors one. The spec-aware tabs on the Macros page (Flask, Combat Potion, Stat Food, Weapon Enchant)
therefore **state** the viewed spec as a sentence and offer no second picker of their own; two
controls over one piece of session state is a synchronisation problem the design would have invented
and then owned forever.

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

With the library **absent** the panel is not registered at all, and the degradation stub publishes
exactly the members a page file touches *at file load*: `LSMValues`, plus the four composers
(`MasterControls`, `ColorPair`, `FontGroup`, `BorderGroup`) answering an empty row list. The composed
rows are therefore missing on that arm, deliberately — a host copy of a composer is precisely the
duplicate the library was extracted to end (`options-ui-§1`, anti-patterns #47) — and it costs nothing
reachable, because with no panel and no `/cm list|get|set` there is no surface left that could read
them. `tests/test_settingsui.lua` **measures** that gap on both arms rather than assuming it.

### Combat gate

Opening is refused in combat, not deferred (`options-ui-§2`). Both the `O.Open` slash path and the
Blizzard AddOns-sidebar `OnShow` guard funnel through one helper so the refusal emits a single
canonical gray notice through the shared secret-safe printer — never a protected category switch and
never a silent no-op. A **tab click** is not gated: redrawing widgets inside an already-open panel was
never a protected action (`options-ui-§13`).

## Page | Covers

Display order is `KCM.Settings.order` (`settings/Panel.lua`) — four pages, in the order a player meets
them: the addon-wide controls, the macros themselves, the ranking the spec-aware categories sort by,
and last the optional bar that displays the finished macros.

| Page | Strip | Covers |
|---|---|---|
| **General** | 1 tab | **Master controls** (the canonical eight, `options-ui-§15`), with a **Maintenance** subsection under it (Force resync, Force rewrite macros, Reset all priorities) |
| **Macros** | 15 tabs | One tab per macro category — the per-category priority list, add-by-ID, and the discovered/added/blocked/pinned sets. The whole subject of the addon |
| **Stat Priority** | 1 tab + banner | Per-spec stat ordering: the spec picker in the page banner, then the primary stat and the draggable secondary list |
| **Macro Bar** | 8 tabs | The optional on-screen macro bar — 62 of the addon's 68 schema rows live here |

### The General page's Master controls tab

The **first** tab on the page, named exactly `Master controls`, and its rows are **composed** by
`H.MasterControls` rather than typed out — nine addons emit the same eight from one declaration, so
they cannot drift into nine orders (`options-ui-§15`).

| | |
|---|---|
| Enable Consumable Master | General visibility |
| Master scale | Master alpha |
| Lock frame | Debug console |
| *Reset position* | *Reset all settings* |

The last row is the tab's closing **button pair**, not two schema rows: they are acts rather than
settings.

Three of the rows are **new addon-wide settings** and three moved:

| Row | Stored path | Where it came from |
|---|---|---|
| Enable Consumable Master | `enabled` | moved from `settings/Panel.lua`'s hand-written row |
| General visibility | `visibility` | **new** — `always` / `inCombat` / `outOfCombat` / `never` |
| Master scale | `scale` | **new**, addon-wide |
| Master alpha | `alpha` | **new**, addon-wide |
| Lock frame | `macroBar.locked` | moved from Macro Bar → General (the tab moved, the storage did not) |
| Debug console | `state.debugConsole` | replaces the bespoke `SessionCheckbox`; session-only, resolved by `settings/Panel.lua`'s `SESSION_PATHS` |
| *Reset position* | — | moved from Macro Bar → General |
| *Reset all settings* | — | `options-ui-§12`'s global reset, verbatim wording |

**The master rows are not the macro bar's.** `Master scale` / `Master alpha` / `General visibility`
govern the whole addon; the bar keeps its own `Bar scale`, `Bar opacity` and `Combat visibility`, and
the two **compose** — the scales and the opacities multiply, and the two visibilities are
**intersected** by `MacroBarModel.ResolveVisibility` so the bar shows only where both say show.
Conflating them would make one of the two sliders do nothing at one end of the other's range.

**The two resets are different acts.** *Reset all settings* is the profile reset — the same act
`Profiles → Reset Profile` performs, behind the collection's one wording. *Reset all priorities*, in
the **Maintenance** subsection below the canonical block, clears every category's added / blocked / pinned items and every spec's
stat-priority override and leaves everything else standing, behind its own, narrower confirmation.
The button that used to sit on this page said the second and did the first.

**The global reset is two halves, not one.** `KCM.ResetAllToDefaults` restores every **session-only**
schema row by hand *first*, then calls `db:ResetProfile()`. The sweep is a `§12` MUST and it is the
half a profile reset by construction cannot do: a session-only row's storage is its own `set()`
(`SESSION_PATHS`), not the db, so `Debug console` survived a reset that took everything around it.
It is written off the `sessionOnly` **flag** rather than off that one path, so a second such row is
covered the day it is declared — which is also why the composed row is given an explicit
`debugConsole = false` default in `settings/General.lua`: three separate resets key on
`default ~= nil` before they will touch a row, and `OptionsCompose` emits that row without one.
Both halves live behind the one function so the button and `/cm resetall` cannot drift.

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

Every single-category tab renders **Add item or spell by ID**, the **glyph legend**, then the
**Priority list**, which is a draggable list. The two composite tabs render the description, the
legend, then **In Combat** / **Out of Combat**, each of which is its **own** draggable list — see
*Reorder lists* below.

**The legend is on every tab, in the flavor that tab can draw.** A single-category tab keys three
glyphs — *in bags*, *not in bags*, *picked in macro* (and the per-hand tabs a fourth line naming the
MH/OH affinity). A composite tab keys **two**: its rows pass `isPick = false`, because every row on
it is a category whose pick goes into the macro and a star on all of them would say nothing, so a
key naming the star would name a glyph that cannot appear on the page it heads. The composite tabs
carried no key at all until this pass, which left a player who had not opened *Food* first looking
at a red cross beside *Healthstone* with nothing on the page explaining it.

### The Macro Bar strip, in tab order

`KCM.Settings.MACROBAR_TABS`, and each tab's name is the `group` its rows declare. Four of the eight
mix control types and therefore carry **subsection headings** (`options-ui-§7`), listed here as
*italics*.

| # | Tab | Rows | Subsections |
|---|---|---|---|
| 1 | **General** | 1 | — enable; plus the Reset slot order button |
| 2 | **Layout** | 8 | — per row, button size, spacing, padding, bar scale, orientation, both growth directions |
| 3 | **Bar appearance** | 9 | *Opacity* · *Background* (toggle + swatch + companion) · *Border* (the composed four, led by its Show border toggle) |
| 4 | **Button appearance** | 13 | *Background* · *Border* (the Show border toggle, the composed four, and border offset) · *Icon* (zoom, stack count, tooltips, GCD swipe) |
| 5 | **Labels** | 12 | *Text* (show, label text) · *Layout* (anchor, placement, both offsets) · *Font* (the composed six) |
| 6 | **Flyout** | 16 | *Layout* (nine) · *Background* (toggle + swatch + companion) · *Icon* (band, arrow, shade swatch + companion) |
| 7 | **Visibility** | 3 | — combat mode, fade unless hover, faded opacity |
| 8 | **Buttons** | 0 | one checkbox per managed macro, a length no schema knows |

`Lock position` and `Reset position` are **not** on this page any more — they moved to Master controls
and were deleted here. Two controls over one setting is exactly what `options-ui-§15` removes.

Two tabs were renamed in the earlier redesign. *Bar* became **General**: on a page called Macro Bar
the word carried nothing, and it collided with *Bar appearance* two tabs along. *Macros on the bar*
became **Contents**, for the same reason — every tab on the page is about the bar — and **Contents**
is now **Buttons**, which names the things on screen rather than the abstraction and is the word the
page already uses two tabs along (*Button appearance*). *Bar appearance*
and *Button appearance* **keep** their qualifiers, because two surfaces coexist on this page and each
has a backdrop and a border of its own; there the word is doing real work.

A `subgroup` names the **kind of control** under it and never a word of the tab it sits on. The first
heading on *Bar appearance* was `Bar`, which named the tab back at the reader; it is **Opacity**, over
the one row it covers. `tests/test_schema.lua` compares the two word by word now — the whole-string
comparison it used to make is what let `Bar` through.

### The Stat Priority page

One tab, **Priority**, under the spec banner.

- **Primary stat** — one dropdown spanning **both** columns. It used to be a half-cell paired with an
  invisible one, which is `wide` written out by hand.
- **The four secondary stats** — **one draggable list**, replacing the four `Secondary stat #N`
  dropdowns. Order is the setting, so dragging is how it is said (`options-ui-§18`).

  The semantics are **order-only**: dragging changes the order and nothing else, because
  `writeStatPriority` already compacts blanks and duplicates on every write. Whether a stat counts at
  all is the per-row **tick/cross glyph** — the affordance the old `(none)` dropdown value carried,
  and an `Include` checkbox before that — and an excluded stat drops to a **dimmed, undraggable tail**
  below the boundary, because its position among the others is not stored and offering a gesture that
  cannot be saved is worse than offering none.

  **The row is MultiMeters-shaped**, and that is the point of it (`options-ui-§8`, `§18`): every
  draggable list in the collection is meant to read the same, so a player learns one row once. The
  row is

  ```
  [handle gutter] [tick/cross] ............................... [Stat name]
  ```

  a **pooled raw frame**, not AceGUI widgets in a Flow group — the name is held against the row's
  right edge and the glyph is a `Button` with two textures, neither of which Flow can express. Three
  things this fixed, all of them visible side by side with MultiMeters' column list:

  1. **The box went round the gutter, not the row.** `spec.parent` was the handle's 30px slot, so the
     library painted its fill and 1px edge there and the row itself had no background at all. The
     spec's `parent` defaults to the registered frame; the fix was to stop overriding it.
  2. **Rows touched.** `stride` was the row height. It is `ROW_H + 4` now, and the 4 is the gap.
  3. **The glyph sat flush against the handle.** The gutter is the library's `ROW_BOX.HANDLE_W`; the
     12px after it is this page's, and it is what the contents start beyond.

  The two textures are the ones MultiMeters' blocks and the Macros page's *in bags* / *not in bags*
  swatches already wear — one glyph vocabulary across the collection. The rows are pooled and
  released on `cancelReorder` for the reason `settings/ColumnBlocks.lua` documents at length: a raw
  frame parented to an AceGUI container rides that container into the process-wide pool when
  `ResetScroll` releases it, and turns up on the next thing to ask for a `SimpleGroup`. Every script
  reads the stat off the frame at fire time, never off an upvalue captured when the row was built.

## Control groups and the class-colour companion

**Every colour swatch has a `Use class color` companion immediately to its right** (`options-ui-§17`),
default off. There are seven swatches and seven companions:

| Swatch | Companion | Scope |
|---|---|---|
| `macroBar.barBackdropColor` | `macroBar.useClassColorBarBackdrop` | player |
| `macroBar.barBorderColor` | `macroBar.useClassColorBarBorder` | player |
| `macroBar.buttonBackdropColor` | `macroBar.useClassColorButtonBackdrop` | player |
| `macroBar.buttonBorderColor` | `macroBar.useClassColorButtonBorder` | player |
| `macroBar.labelColor` | `macroBar.useClassColorLabel` | player |
| `macroBar.flyoutBackdropColor` | `macroBar.useClassColorFlyoutBackdrop` | player |
| `macroBar.flyoutShadeColor` | `macroBar.useClassColorFlyoutShade` | player |

Every one is `classColorSource = "player"`: this addon paints one bar that belongs to the player and
tracks no unit, so there is no other class any of them could mean. The declaration is what an audit
reads — the path prefix decides nothing.

- **The swatch is never disabled.** Its **alpha** is still read under class colour, so graying it
  would tell the player something untrue. `disabledIf` on a colour row is forbidden
  (anti-patterns #74); the swatch's tooltip says it in words instead.
- **One resolver.** `KCM.SwatchColor` (`core/CoreSetup.lua`) decodes the stored positional
  `{ r, g, b, a }` with that surface's own four-channel fallback and hands it to
  `LibKa0s-Core-1.0`'s `ResolveColor` with a `nil` unit. An unresolvable class falls through to the
  stored swatch — never to white, never to a substitute hue.

**The bar's chrome is a BACKGROUND group, not a bar group** (`options-ui-§16`). The macro bar is a
button container with a backdrop and no fill texture, so it takes a swatch and its companion and
nothing else; a texture picker there would be a control wired to nothing, which is why `H.BarGroup` is
not called anywhere in this addon.

The **border** blocks (bar and button) and the label **font** block are composed by `H.BorderGroup`
and `H.FontGroup`; `keys` and `defaults` keep the stored paths and values exactly what they were. The
font block is what gave the labels a **font face**, a real **font flags** string and a **font shadow**
— all three new, all three honoured in `modules/MacroBarButton.lua`'s `applyLabel`. `labelOutline`
(a boolean) became `labelFlags` (a string) in the same change, as schema **v3** in
`core/Database.lua`, because a stored value changing shape is a migration and not an edit to a
defaults table.

## Reorder lists

Three draggable lists, all through `LibKa0s-Widgets-1.0`'s `ReorderList` (`options-ui-§18`). The
handle, the gutter it sits in, the bounded row box, the carried copy, the insertion line and the
index arithmetic are all the widget's; the row **contents** are ours. The gutter's width is
`lib.ROW_BOX.HANDLE_W` (30 for this pass, up from 24), **read** at each call site and never restated:
no list here passes `handleSize`, so nothing but the library decides how wide a Ka0s drag handle is.
The three `slot:SetWidth(handleGutter())` calls take the same constant, so the cell Flow reserves and
the handle drawn into it cannot disagree.

| List | Controllers | Boundary | Move |
|---|---|---|---|
| Macros → a single category's **Priority list** | 1, flat | none | `Selector.MoveTo` |
| Macros → a composite's **In Combat** / **Out of Combat** | **2**, one per section | none on either | `Selector.MoveCompositeRef` |
| Stat Priority → the **secondary stats** | 1 | `#included` | splice + `writeStatPriority` |

**All three draw the same row**, which is the point of the shared widget (`options-ui-§8`): the
library's fill and 1px edge behind the WHOLE row, and a stride wider than the box so consecutive rows
do not touch. All three got that wrong the same way — `spec.parent` named the handle's 30px SLOT, so
the box was painted around the gutter and the row itself had no background at all, which is exactly
what made these lists look unlike MultiMeters' column list next to them. `parent` defaults to the
frame the row was registered with; the fix in each case was to stop overriding it. The gap is a
spacer drawn after each row rather than extra height on the row, because the box fills the frame it
is parented to — a taller row is a taller box, not a space between two of them.

The composite sections are **two separate stored arrays** and a sub-category is locked to its section,
so they are two flat controllers rather than one with a boundary — a drag cannot cross between them
because there is no array for it to cross into. The secondary-stat list is the other shape: one array
with a divide, so one controller with a `boundary`.

**Every controller is cancelled at the TOP of the render, before the first widget is created** —
`settings/Category.lua`'s `cancelReorder` and `settings/StatPriority.lua`'s. Handles and boxes are
pooled, and a controller released late leaves them attached to recycled widgets belonging to something
else. The Category seam holds a **list** of controllers for exactly this reason: a composite page
builds two, and a seam that held one would have leaked the first section's chrome.

**Paired up/down arrows are gone** from both the priority rows and the composite sections
(anti-patterns #75). Without the library there is no handle and no box and the list is not
reorderable; that is an accepted cosmetic degradation and no arrows come back as a fallback.

## How a control reaches the value

Two different paths, and the difference is what a row shape can express.

**Schema-backed controls** are rows in `KCM.Settings.Schema` — an ordered array published by
`settings/Panel.lua` and appended to by the page files. One row is simultaneously three things: the
widget on its page, the `/cm list|get|set|reset <path>` CLI entry (`settings/Slash.lua` hands the
whole array to LibKa0s-Slash-1.0 as `allRows`), and the validator applied on write by the `Resolve` →
`SetAndRefresh` seam. There are **68**: 62 `macroBar.*` rows on the Macro Bar page and 6 in the
General page's Master controls block. That count is no longer greppable — a composed block declares
its rows from one call — so read it off `#KCM.Settings.Schema`, which is what the suite does. Adding a
row gains all three surfaces at once — never write a parallel mutator for a path that already has one.

Composed rows are spliced in by `Helpers.RegisterRows`, which stamps the fields the composers cannot
know: `panel`, `section`, this addon's `onChange`, and the ordered `{ value =, text = }` media lists
it declares where the library declares a hash.

**Bespoke controls** are everything a `{ path, type }` row cannot describe, and they are deliberate,
not gaps:

- The **per-category priority lists** and the **per-spec stat priorities** are collections, not
  scalars. No row shape describes them, which is also why `/cm resetall` stays host-owned rather than
  adopting the library's `Sl:CliResetAll` (closed issue [LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)).
- The **Add-by-ID box** takes free text, not a scalar. `submitAddByID` (`settings/Category.lua`)
  tries digits first — a bare number is unambiguous and must never reach a link matcher — then the
  selected kind's own `fromLink` parser, so a **shift-clicked item or spell link** is accepted as
  readily as a typed ID. ITEM goes through the `KCM.Item` seam onto `LibKa0s-Item-1.0`'s
  `ItemIDFromLink`; SPELL parses the spell link it alone can receive. A link of the *wrong* kind is
  refused rather than cross-filed, because an item link parsed as a spell would store an itemID
  behind the opaque spell sentinel and collide with a real spell ID. Every rejection says why and
  keeps the typed text.
- The **Debug console** row is a schema row now, not a bespoke checkbox — the composer emits it and
  `settings/Panel.lua`'s `SESSION_PATHS` resolves its `state.debugConsole` path to the console
  window's show/hide. It never touches the session debug flag `KCM.State.debug`, exactly like a bare
  `/cm debug` (`debug-logging-§5`); logging is armed separately, via the in-window `Debug: ON/OFF`
  toggle or `/cm debug on|off`. `KCM.State.debug` is session-only and never persisted, so it still has
  no path to declare.

## Layout rules

- **Two-column paired grid** (`options-ui-§6`). Consecutive rows pair into left/right cells.
  `H.RenderRows(ctx, rows, afterGroup, pairWith, opts)` draws a block of schema rows and reads the
  pairing off the rows themselves: `startsLine` flushes the pending line before a row (which is what
  keeps a colour pair together), `wide` renders a row alone at full width, and `solo` renders it alone
  in the left half. `H.Grid(ctx, { … })` remains for lists whose length no schema knows.
- **Sections** are introduced by `H.Section(ctx, label)`, never a bare bold line. On a tabbed page the
  tab strip replaces the group heading it used to draw — a heading under a tab of the same name says
  the same thing twice — but a **`subgroup`** heading inside a mixed tab is *not* suppressed, because
  there is no tab left to name each block with (`options-ui-§7`).
- **Tab strips** come from `H.TabStrip(ctx, { tabs, value, onSelect })` (`options-ui-§13`) and the page
  banner from `H.PageBanner(ctx, { label, list, order, value, onSelect })` (`§14`). Both are the
  library's, both live in the page's chrome band above the scroll, and the banner is drawn first
  because it reserves the share of the band the strip then places itself under.
- **Action buttons** use `H.ButtonPair` / `H.Button`, and a destructive one is confirm-gated through a
  `StaticPopup` — *Reset all settings* raises `KCM_RESET_ALL` and *Reset all priorities* raises
  `KCM_RESET_PRIORITIES`, rather than either acting on click.
- Every user-visible string routes through `L[…]` (`localization-§1`). The composers' labels are the
  library's own English literals, which is what makes them identical across the collection.
