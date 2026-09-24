# Settings panel

The Blizzard-canvas options UI: how the pages are registered, what each one covers, and how a control
reaches the stored value. The persisted shape those controls write into is [schema.md](./schema.md);
the recompute they trigger is [data-flow.md](./data-flow.md).

## Shape

One `Settings.RegisterCanvasLayoutCategory` **parent** — the landing page — plus one
`RegisterCanvasLayoutSubcategory` **body per page**, of which there are five. AceConfigDialog draws
exactly one of them, the **Profiles** page ([profiles.md](./profiles.md), `options-ui-§3`); the other
four are built from raw AceGUI widgets on a Blizzard canvas (`options-ui-§2`). The canvas shell, the
page registry, the widget makers, the two-column flow engine, the tab strip and the schema
**composers** are all **LibKa0s-Options-1.0's**, wired in `settings/OptionsSetup.lua`;
`settings/Panel.lua` owns registration and the shared header (title + atlas divider) built by
`Helpers.CreatePanel`. The run-time `KCM.Options` surface — `Refresh`, `RequestRefresh`, `Open`, the
refresh debounce and the options layer's three bus receivers — is `settings/OptionsShim.lua`'s, peeled
off `Panel.lua` on 2026-09-16 at `layout-§1`'s 1500-line cap and loaded immediately after it.

Each page module hands a **builder** to `RegisterTab`. Once `Blizzard_Settings` is ready, driven by
its own `PLAYER_LOGIN` / `ADDON_LOADED` bootstrap, `settings/Panel.lua`'s `registerPanel` queues
them with the library's `RegisterOptionsPage` in `KCM.Settings.order` and calls
`UI.CreateOptionsPanel()`, which registers the main canvas (the descriptor's `buildMain`, the About
page) after running the descriptor's `validate`, then builds every page. In combat the library
registers nothing: it parks the request and replays it once on its own `PLAYER_REGEN_ENABLED` frame,
whatever the addon's stand-down state, so a disabled addon still gets its category and its Enable
checkbox. The bootstrap lets go of its events as soon as the request is the library's.

### Every page draws a strip

**All four schema-drawn pages** carry a **pinned tab strip** in the page's chrome band (`options-ui-§13`): only the
active tab's body draws, and the strip wraps onto as many rows as the canvas width needs. That is not
a size threshold and not a choice — a Ka0s page has a strip, so a player who has learned one page has
learned all of them. A page with exactly **one** section draws a **one-tab** strip; the tab that
cannot be clicked is that page's section label.

The only exemptions are pages the host does not render through the flow engine at all, and there
are two: the AceConfig-drawn **Profiles** sub-page (`settings/Profiles.lua`), which AceConfigDialog
draws whole and which carries no schema rows, and the **landing page**, whose body is
`Helpers.BuildAboutContent` and which declares no sections. `tests/test_settingsui_optionsui.lua`
asserts the Profiles page draws **no** strip, rather than merely skipping it.

The **Macros** page is why the strip exists here at all. Every macro category used to be its own
`RegisterCanvasLayoutSubcategory` entry — fifteen rows in the AddOns sidebar for fifteen variations on
one surface, and eighteen sub-pages in all. They are one page with fifteen tabs now, and the sidebar
is down to five entries, the Profiles page among them. The strip is **generated** from `KCM.Categories.LIST` in
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
change. That is the library's to get right; `tests/test_settingsui_optionsui.lua` pins it on both pages under a
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
controls over one piece of session state is a synchronization problem the design would have invented
and then owned forever.

### `Helpers` is a live view, not a snapshot

`KCM.Settings.Helpers` is the addon's own half of the framework **and** the published view of the
LibKa0s-Options-1.0 instance: `settings/OptionsSetup.lua` creates the table and installs the instance
as its `__index`, so every library member resolves off the **live** instance at call time rather than
off a snapshot taken at file load. That is the whole point of the indirection. The copy-across this
replaced re-exported eleven members by hand, and any member the list forgot — or any member bound
while `UI` was still `nil` — read back `nil` at the call site with no way to tell it apart from a
member the library never had (`options-ui-§1`). The addon's own wrappers stay as **own** keys and
shadow the library's same-named function, which is what lets `Section` and `CreatePanel` call the
instance's version without recursing into themselves. `LSMValues` was a third wrapper until `M4-C1`
retired it: it flattened the library's deferred hash into an ordered array for one caller, and that
caller was the LibKa0s issue #15 workaround `M3-04` deleted. `Helpers.LSMValues` still resolves, but
straight through `__index` to the library's, so it hands back the **deferred closure over a hash**
the library documents; anything wanting an array puts it through `Helpers.EnumValues`.

With the library **absent** the panel is not registered at all, and the degradation stub publishes
exactly the members a page file touches *at file load*: the four composers (`MasterControls`,
`ColorPair`, `FontGroup`, `BorderGroup`), answering an empty row list. `LSMValues` was named here as
a fifth, and the stub never published it even then — `settings/Panel.lua` defined it
unconditionally, on both arms. `M4-C1` removed it outright, and no page file evaluates it at file
load any more, so the list above is complete as it stands. The composed
rows are therefore missing on that arm, deliberately — a host copy of a composer is precisely the
duplicate the library was extracted to end (`options-ui-§1`, anti-patterns #47) — and it costs nothing
reachable, because with no panel and no `/cm list|get|set` there is no surface left that could read
them. `tests/test_settingsui.lua` **measures** that gap on both arms rather than assuming it.

### Combat gate

Opening is refused in combat, not deferred (`options-ui-§2`). The `O.Open` slash path
(`settings/OptionsShim.lua`) calls the library's `OpenOptionsPanel`, which prints its one canonical
gray `COMBAT_REFUSED` line through the descriptor's printer and answers `false`, never a protected
category switch and never a silent no-op; `O.Open` answers `false` in turn and says nothing more. Out
of combat the library opens the category and expands the parent in the sidebar. A **tab click** is not gated: redrawing widgets inside an already-open panel was
never a protected action (`options-ui-§13`).

## Page | Covers

Display order is `KCM.Settings.order` (`settings/Panel.lua`) — five pages, in the order a player meets
them: the addon-wide controls, the macros themselves, the ranking the spec-aware categories sort by,
the optional bar that displays the finished macros, and last the Profiles page, which is AceDBOptions'
own UI and last in every Ka0s addon that ships one.

| Page | Strip | Covers |
|---|---|---|
| **General** | 2 tabs | **Master controls** (the canonical set, `options-ui-§15`) and **Maintenance** (Force resync, Force rewrite macros, Reset all priorities). Maintenance was a subsection under the canonical block until 2026-09-09; it is its own tab now, which `§15` permits because it forbids splitting only the *canonical set* and these three were never in it. Master controls stays first, which `§15` does require. |
| **Macros** | 15 tabs | One tab per macro category — the per-category priority list, add-by-ID, and the discovered/added/blocked/pinned sets. The whole subject of the addon |
| **Stat Priority** | 1 tab + banner | Per-spec stat ordering: the spec picker in the page banner, then the primary stat and the draggable secondary list |
| **Macro Bar** | 8 tabs | The optional on-screen macro bar — 64 of the addon's 79 schema rows live here |
| **Profiles** | none (`§13` exemption) | AceDBOptions' create / switch / copy / reset / delete and the scope choices, drawn by AceConfigDialog. No schema rows and no Defaults button. Every setting on the four pages above is in the profile, so a switch moves all of it ([profiles.md](./profiles.md)) |

### The General page's Master controls tab

The **first** tab on the page, named exactly `Master controls`, and its rows are **composed** by
`H.MasterControls` rather than typed out — nine addons emit the same set from one declaration, so
they cannot drift into nine orders (`options-ui-§15`).

| | |
|---|---|
| Enable Consumable Master | General visibility |
| Master scale | Master alpha |
| Lock frame | Debug console |
| Minimap button | |
| *Reset position* | *Reset all settings* |

**Minimap button** opens its own line rather than pairing. The composer's fourth line is
`[Minimap button] [Test mode]`, and the always-present row takes column 1 precisely so an addon
without a test mode does not draw a hole in the first column with a lone control beside it. This
addon has no test mode (see below), so column 2 is empty.

The last row is the tab's closing **button pair**, not two schema rows: they are acts rather than
settings.

There is **no Test mode row** and no `/cm test` verb. Unlocking the bar already shows everything a
preview would: the gold wash over its extent and the drag handle. The standard (v2.49.0,
`options-ui-§15`) exempts an addon whose unlocked view is its preview, so here **Lock frame** is the
switch.

Four of the rows are **new** and three moved:

| Row | Stored path | Where it came from |
|---|---|---|
| Enable Consumable Master | `enabled` | moved from `settings/Panel.lua`'s hand-written row |
| General visibility | `visibility` | **new** — `always` / `inCombat` / `outOfCombat` / `never` |
| Master scale | `scale` | **new**, addon-wide |
| Master alpha | `alpha` | **new**, addon-wide |
| Lock frame | `macroBar.locked` | moved from Macro Bar → General (the tab moved, the storage did not) |
| Debug console | `state.debugConsole` | replaces the bespoke `SessionCheckbox`; session-only, stored by the row's own `get` / `set` |
| Minimap button | `global.minimap.hide` | **new** at LibKa0s v1.39.0 (`launcher-§3`). See below — it is the one row in the block whose store is neither the profile nor the session |
| *Reset position* | — | moved from Macro Bar → General |
| *Reset all settings* | — | `options-ui-§12`'s global reset, verbatim wording. Its tooltip names the equivalence: *Reset the current profile to its defaults — the same thing Profiles → Reset Profile does. Your other profiles are not affected.* |

### The Minimap button row — shown says one thing, the store says the other

The row is `global.minimap.hide`, and four things about it are deliberate.

**Its store is LibDBIcon's OWN table, not a key beside it.** `db.global.minimap` is the table this
addon hands straight to `LibDBIcon:Register`, and `hide` is the boolean LibDBIcon writes itself when
the player uses the button's own right-click menu — `minimapPos` lands in the same table when they
drag it. A parallel `minimap.show` would be a second record of one state that a library also writes,
and the day they disagree the button and the checkbox disagree (anti-pattern #81).

**Its scope is GLOBAL, and that is the decision rather than where it landed.** A minimap button
belongs to the installation, not to a profile. Switching profiles must not move the player's
buttons, and the global store is where LibDBIcon's own `minimapPos` has to live for exactly the same
reason — which is why the two are one table.

**It SURVIVES EVERY RESET, and that is a property of the setting rather than a consequence of the
store.** Whether the button is shown is a per-installation display preference, in the same class as
the position the player dragged it to, which sits in the very same table and which no reset touches.
`launcher-§3` therefore requires it to survive **both** `options-ui-§12`'s *Reset all settings* **and**
a page-scoped **Defaults** button. This addon ships both, and only one of them was already safe:

- ***Reset all settings*** never reached it. `KCM.ResetAllToDefaults` is the session sweep plus
  `db:ResetProfile()`; `settings/OptionsSetup.lua`'s `vetoedFromResetAll` keys the sweep on
  `row.sessionOnly` and this row is **stored**, not session, so the sweep skips it — and
  `db:ResetProfile()` cannot reach `db.global` at all.
- **The General page's *Defaults* button did.** `settings/General.lua`'s `doResetGeneralPage` walks
  `masterRows` and rewrites every row carrying a `default`, and the composer emits this one with
  `default = true`. A player who had hidden the button got it back, at LibDBIcon's default angle,
  from a click about the master controls. Carved out since `launcher-§3` stated the property.

The exemption is one row flag, `neverReset`, stamped on the row by `settings/General.lua`'s
`decorate` map and read through `settings/OptionsSetup.lua`'s `VetoedFromEveryReset` — the same file
that names the global reset's veto, so there is one register rather than a second list per page.
`vetoedFromResetAll` reads it first, so both doors ask one question. What it deliberately does not
cover is `/cm reset global.minimap.hide`: that is the player naming the row out loud, which is the
checkbox by another door. Every arm is pinned by cases in `tests/test_launcher.lua` that run the
real reset and assert on the store.

**Its label says SHOWN and its stored key says HIDDEN, so the row inverts.** That inversion lives in
the row's own store and nowhere else — the `get` / `set` `settings/General.lua` stamps on the
row, which the single write seam calls. The `set` writes `hide = not value` and then calls
`KCM.Launcher:SetShown(value)`, so the button follows the checkbox immediately rather than at the
next reload.

The button itself, and the broker plugin that is the same object, are
[ARCHITECTURE.md → LibKa0s adoption](./ARCHITECTURE.md#libka0s-adoption)'s `Launcher-1.0` row. Its
**left click** toggles **Lock frame** — the same seam this checkbox drives — and its right click
opens this panel.

**The master rows are not the macro bar's.** `Master scale` / `Master alpha` / `General visibility`
govern the whole addon; the bar keeps its own `Bar scale`, `Bar opacity` and `Combat visibility`, and
the two **compose** — the scales and the opacities multiply, and the two visibilities are
**intersected** by `MacroBarModel.ResolveVisibility` so the bar shows only where both say show.
Conflating them would make one of the two sliders do nothing at one end of the other's range.

**The two resets are different acts.** *Reset all settings* is the profile reset — the same act
`Profiles → Reset Profile` performs, behind the collection's one wording. It raises
`KCM_CONFIRM_RESET` (`core/SlashCommands.lua`), the same popup `/cm resetall` raises; there is no
second global-reset popup, and the combat refusal and the repaint are `KCM.ResetAllToDefaults`' own,
so neither door adds anything the other lacks ([slash-dispatch.md](./slash-dispatch.md)). The
*Reset all priorities* tooltip points at it by tab: *use Reset all settings on the Master controls
tab*. *Reset all priorities*, in
the **Maintenance** tab, clears every category's added / blocked / pinned items and every spec's
stat-priority override and leaves everything else standing, behind its own, narrower confirmation.
The button that used to sit on this page said the second and did the first.

**The global reset is two halves, not one.** `KCM.ResetAllToDefaults` restores every **session-only**
schema row by hand *first*, then calls `db:ResetProfile()`. The sweep is a `§12` MUST and it is the
half a profile reset by construction cannot do: a session-only row's storage is its own `set()`
(stamped in `settings/General.lua`), not the db, so `Debug console` survived a reset that took everything around it.
It is written off the `sessionOnly` **flag** rather than off that one path, so a second such row is
covered the day it is declared — which is also why the composed row is given an explicit
`debugConsole = false` default in `settings/General.lua`: three separate resets key on
`default ~= nil` before they will touch a row, and `OptionsCompose` emits that row without one.
Both halves, the combat refusal ahead of them and the repaint after, live behind the one function
so the button and `/cm resetall` cannot drift.

Which rows the sweep writes is **one predicate's** call, `KCM.Settings.VetoedFromResetAll`
(`settings/OptionsSetup.lua`): it refuses the Profiles page's rows (`options-ui-§3`) and every
profile-resident row (`§12`), which leaves the session rows. The same function is the library
descriptor's `skipRestoreAll`, so the rule is named once and shared rather than restated.

**The tooltip comes from the descriptor, not from this page.** The button is the composer's, and
the composer is the only writer of its text (`options-ui-§15`). Since LibKa0s-Options-1.0 minor 18 it
picks the wording from the Options descriptor, so `settings/OptionsSetup.lua` declares what the reset
is: `resetProfile`, which is the same `db:ResetProfile()` `KCM.ResetAllToDefaults` calls, and
`profilesPage = true`, because the Profiles page is registered. Without `resetProfile` the tooltip
reads *Restore every setting in this addon to its default.*, which overstates a reset that leaves the
other profiles alone. The library's `RestoreAllDefaults` is the only other reader of `resetProfile`,
and nothing in this addon calls it, so the two fields change the tooltip and nothing else. The
button still raises `KCM_CONFIRM_RESET` and the popup still runs `KCM.ResetAllToDefaults`.

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

Tabs are labeled with each category's `displayName`, never its `shortName`: `shortName` exists for
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
| 8 | **Buttons** | 2 | `macroBar.order` and `macroBar.shown`, drawn as one draggable list (below), a length no schema knows |

`Lock position` and `Reset position` are **not** on this page any more — they moved to Master controls
and were deleted here. Two controls over one setting is exactly what `options-ui-§15` removes.

**The Buttons tab is one draggable list, in MultiMeters' Columns shape.** Each row is the library's
drag handle, a tick and the button's name. The shown buttons come first, in the bar's order, then a
rule, then the hidden ones, dimmed and with no handle. `boundary` is the shown count, so a drag cannot
cross the rule. The list is the stored `macroBar.order` partitioned into shown and hidden, each keeping
its stored order, so neither row changes shape.
- **A drag** within the shown group is a splice, not a swap. It writes `macroBar.order` once: the new
  shown order, followed by the hidden buttons in their existing order. That is one `[Set]` line.
- **A tick** is a move too. Unticking sends a button to the top of the hidden group, and ticking a
  hidden one sends it to the end of the shown group. It writes `macroBar.shown` and then
  `macroBar.order` as one batch through `KCM.Schema:SetMany`: two `[Set]` lines, one bar re-apply
  and one page rebuild.

Every button may be hidden, as the checkboxes this list replaced allowed. Both acts are refused in
combat, like the bar's own swap, and a refused act writes and repaints nothing. Dropping one button
onto another on the bar itself still swaps the two. The rows are pooled raw frames, released with
the controller at the top of every render (`options-ui-§18`).

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

## Control groups and the class-color companion

**Every color swatch has a `Use class color` companion immediately to its right** (`options-ui-§17`),
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

- **The swatch is never disabled.** Its **alpha** is still read under class color, so graying it
  would tell the player something untrue. `disabledIf` on a color row is forbidden
  (anti-patterns #74); the swatch's tooltip says it in words instead.
- **One resolver.** `KCM.SwatchColor` (`core/CoreSetup.lua`) decodes the stored positional
  `{ r, g, b, a }` with that surface's own four-channel fallback and hands it to
  `LibKa0s-Core-1.0`'s `ResolveColor` with a `nil` unit. An unresolvable class falls through to the
  stored swatch — never to white, never to a substitute hue.
- **One decoder, and it invents nothing.** `KCM.ColorDecode` (`core/CoreSetup.lua`) is the only
  reader of the stored `{ r, g, b, a }` shape. It answers `nil` for a channel the stored table does
  not carry and takes the fallback from its **caller**, which is why a per-surface default belongs
  in `KCM.SwatchColor` rather than in the codec. The panel (`settings/OptionsSetup.lua`'s
  `Helpers.ColorDecode`), the CLI (`settings/Slash.lua`'s `colorDecode`) and `KCM.FormatSchemaValue`
  all read through it. The panel is the one surface that supplies numbers — AceGUI's color picker
  hands `SetColor`'s arguments straight to `SetVertexColor`, which raises on a `nil` — and the four
  it supplies are `LibKa0s-Slash-1.0`'s own `COLOR_KEYS` values, so the swatch and `/cm get` cannot
  disagree about a color they both read. Before this the panel answered `or 1` and the CLI `or 0`:
  one stored value, white on one surface and black on the other.

**The bar's chrome is a BACKGROUND group, not a bar group** (`options-ui-§16`). The macro bar is a
button container with a backdrop and no fill texture, so it takes a swatch and its companion and
nothing else; a texture picker there would be a control wired to nothing, which is why `H.BarGroup` is
not called anywhere in this addon.

The **border** blocks (bar and button) and the label **font** block are composed by `H.BorderGroup`
and `H.FontGroup`; `keys` and `defaults` keep the stored paths and values exactly what they were. The
font block is what gave the labels a **font face**, a real **font flags** string and a **font shadow**
— all three new, all three honored in `modules/MacroBarButton.lua`'s `applyLabel`. `labelOutline`
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

**Every controller is canceled at the TOP of the render, before the first widget is created** —
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
whole array to LibKa0s-Slash-1.0 as `allRows`), and the validator applied on write by the
`SetAndRefresh` → LibKa0s-Schema-1.0 seam (`Helpers.schema`). There are **79**: 64 `macroBar.*` rows on the Macro Bar page, 7 in the
General page's Master controls block, 7 on the Macros page and 1 on the Stat Priority page. Ten
of them are drawn by bespoke controls rather than by the row engine: the whole-value `order` and
`map` rows (the bar's slot order and visibility, stat priority, each composite's flags and section
orders) and the Battle Rez mouseover bool. They are still rows, so those controls write through the
helper and `/cm get|list|reset` reach them. That count is no longer greppable — a composed block declares
its rows from one call — so read it off `#KCM.Settings.Schema`, which is what the suite does. Adding a
row gains all three surfaces at once — never write a parallel mutator for a path that already has one.

Composed rows are spliced in by `Helpers.RegisterRows`, which stamps the fields the composers cannot
know: `panel`, `section`, this addon's `apply`, and the ordered `{ value =, text = }` media lists
it declares where the library declares a hash.

**Bespoke controls** are everything a `{ path, type }` row cannot describe, and they are deliberate,
not gaps:

- The **per-category priority lists** are a collection, not a scalar. They are the addon's one
  structural registry, and `modules/Selector.lua` is their registry writer (`architecture-§5`, named
  in [ARCHITECTURE.md → Settings Schema](./ARCHITECTURE.md#settings-schema)). No row shape describes
  them, which is also why `/cm resetall` stays host-owned rather than adopting the library's
  `Sl:CliResetAll` (closed issue [LIBKA0S-12](https://github.com/tusharsaxena/ConsumableMaster/issues/27)).
  The **per-spec stat priorities** used to sit here too. They are a preference, not a registry, so
  since 2026-09-12 they are one whole-value row, `statPriority`, still edited by the page's own
  list and dropdown ([#35](https://github.com/tusharsaxena/ConsumableMaster/issues/35)).
- The **Add-by-ID line** takes free text, not a scalar. It is `LibKa0s-Options-1.0`'s `IdInput`
  (minor 16): an edit box, an **Add** button and a status line under both, drawn under the page's own
  **Type** dropdown (Item / Spell). The widget never writes a path. `settings/CategoryAddByID.lua` — the Macros page's
  Add-by-ID line, peeled off `settings/Category.lua` on 2026-09-16 at `layout-§1`'s 1500-line cap —
  hands it a host kind whose `resolve` is `resolveAddByID`, which reads the dropdown at the moment of the add
  and tries four things in order:
  1. digits (a bare number is unambiguous and must never reach a link matcher);
  2. the selected kind's own `fromLink` parser, so a **shift-clicked item or spell link** is
     accepted as readily as a typed ID. ITEM goes through the `KCM.Item` seam onto
     `LibKa0s-Item-1.0`'s `ItemIDFromLink`; SPELL parses the spell link it alone can receive;
  3. a **name**, through the library's `ResolveId` with this category's **candidates**. First the
     client's own lookup (`C_Spell.GetSpellInfo(name)` / `C_Item.GetItemInfoInstant(name)`), which
     knows an item only if the player carries it or carried it this session. Then a case-insensitive
     exact name over the IDs the category already knows: `Selector.BuildCandidateSet` (seed, added
     and discovered, less blocked), item IDs under Type=Item and spell IDs under Type=Spell; under
     Type=Item the items in the bags (`KCM.BagScanner.Scan`) join them. The client has no item-name
     search, so a name reaches nothing else. A name two of these IDs share, such as the three
     crafted-quality ranks of *Potion of the Hushed Zephyr* when the tab lists them or the player
     carries two, is refused as ambiguous (`Several items share the name '<text>': pick one from the
     list, or use the ID.`). One rank is never added for the player, and neither are all of them. A
     rank that is neither listed nor carried is outside the check: with one rank carried and the rest
     unknown, the client's answer is the only match, and that rank resolves;
  4. the kind's existence check, which every result must pass.

  **Suggestions.** As the player types, the library lists up to ten matching IDs from the same
  candidates under the box, every rank of a shared name its own row, told apart by its gray ID. The
  rows are the ranks the tab lists or the bags carry, so a refused shared name's list shows those
  and no others; the library adds no client source for a host kind, which is why the bags are
  candidates here. Each row is icon, name, rank, then the gray ID. The kind names the library kind
  its ids are as `base` (`"item"` under Type=Item, `"spell"` under Type=Spell, LibKa0s v1.35.0), so
  the rows wear that kind's decorations: an item's name in its quality color and its
  crafted-quality (or reagent) tier icon, so the three Zephyr ranks read tier 1, 2 and 3; a spell's
  subtext ("Racial"). `base` brings no name lookup and no bags or spellbook, so what is listed and
  what resolves stay this addon's candidates and resolver.
  A click, or Up/Down and Enter, picks a row. Because the kind is based, the library asks the
  resolver about the picked ID (as its digits) before `onAdd`: a refusal adds nothing, keeps the
  typed text and says why on the status line (`No item matches '<id>'.`). `onAdd` runs the
  existence check once more. Enter with no row picked submits the typed text, so a shared name is
  still refused. The host kind declares `info` (a
  row's name and icon) and, for items, `loads`, so drawing the line asks the client for up to 200
  uncached candidates and a typed name waits for them before it is refused (up to about two seconds
  when one never loads). A spec-aware tab with no spec gets no `info` and no candidates, so no list
  goes up, and its tooltip offers no list and no name hint: it says a spec is missing. Changing
  **Type** redraws the page a frame later: the list is built once per render, and an item row left
  under Spell would be filed as a spell. The typed text is carried across that redraw. While the box
  has focus or holds text (`O.AddByIDBusy`), the debounced page rebuild (`PANEL_REFRESH`) waits,
  because a rebuild releases the box and the library's `OnRelease` would drop a pending lookup and
  clear the text without a word. The tooltip and `notFound` end in the kind's hint, `Names work for items you carry
  (or carried this session) and ones this list knows; otherwise use the ID or shift-click a link.`
  (the spell hint names the spellbook).

  `onAdd` stores a spell through `KCM.ID.AsSpell` and hands the ID to `Selector.AddItem`, so the
  stored shape (`added[id] = true`, spells negative) is what it always was. A link of the *wrong*
  kind is refused rather than cross-filed, because an item link read as a spell would store an
  itemID behind the opaque spell sentinel and collide with a real spell ID. A refusal says why on the
  status line (`No item matches '<text>'.` followed by the kind's hint) and keeps the typed text. A spec-aware tab with no
  active spec refuses every entry the same way, in the resolver and before anything is looked up
  (`No active spec, so this spec-aware category has nowhere to put '<text>'.`), so the text stays
  there too. A check made in `onAdd` would come too late: the widget has already cleared the box
  before `onAdd` runs, and reads `onAdd` returning as a success. The page rebuild after an add
  waits a frame (`C_Timer.After(0, …)`). Through LibKa0s v1.34.0 the widget cleared its edit box and
  status line after `onAdd` returned, onto widgets a rebuild inside `onAdd` had already released to
  AceGUI's pool. Since v1.35.0 it clears both before `onAdd` and touches neither after a clean one,
  so the wait is no longer load-bearing. It is kept as the order that is safe under either behavior.
- The **Debug console** row is a schema row now, not a bespoke checkbox — the composer emits it and
  the row's own `get` / `set` (stamped in `settings/General.lua`) map its `state.debugConsole` path
  to the console window's show/hide. It never touches the session debug flag `KCM.State.debug`, exactly like a bare
  `/cm debug` (`debug-logging-§5`); logging is armed separately, via the in-window `Debug: ON/OFF`
  toggle or `/cm debug on|off`. `KCM.State.debug` is session-only and never persisted, so it still has
  no path to declare.

## Layout rules

- **Two-column paired grid** (`options-ui-§6`). Consecutive rows pair into left/right cells.
  `H.RenderRows(ctx, rows, afterGroup, pairWith, opts)` draws a block of schema rows and reads the
  pairing off the rows themselves: `startsLine` flushes the pending line before a row (which is what
  keeps a color pair together), `wide` renders a row alone at full width, and `solo` renders it alone
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
  `StaticPopup` — *Reset all settings* raises `KCM_CONFIRM_RESET` and *Reset all priorities* raises
  `KCM_RESET_PRIORITIES`, rather than either acting on click.
- User-visible strings route through `L[…]` (`localization-§1`), and `tests/test_locale.lua` is what
  holds that: it lexes `settings/` and the `modules/KCM*` widgets for prose literals and fails on any
  that is neither a subscript of `L` nor recorded, with a class, in its residue register. It is a gate
  on the surface GROWING a bare literal — the register is a complete inventory of the seventy this page
  and the settings CLI already carry, most of them chat diagnostics, degraded-install tails and the
  `/cm` verb list. Read that register before assuming a string here is translatable. The composers'
  labels are the library's own English literals, which is what makes them identical across the
  collection.
