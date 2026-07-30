# Macro bar

The CM-only action bar. On and unlocked out of the box — see
[Defaults & the v2 migration](#defaults--the-v2-migration) — with everything
about it living in `db.profile.macroBar`. User-facing description is in
[README.md](../README.md#settings-panel).

## Files

| File | Frames? | Role |
|------|---------|------|
| [`core/MacroBarLayout.lua`](../core/MacroBarLayout.lua) | no | grid math: slot index → TOPLEFT offset, container size |
| [`core/MacroBarModel.lua`](../core/MacroBarModel.lua) | no | slot order + visibility bookkeeping, order repair, swap |
| [`core/MacroDisplay.lua`](../core/MacroDisplay.lua) | no | what a macro currently resolves to: icon, count, cooldown, tooltip |
| [`modules/MacroBarButton.lua`](../modules/MacroBarButton.lua) | yes | one secure slot: attributes, chrome, drag handlers |
| [`modules/MacroBarFlyout.lua`](../modules/MacroBarFlyout.lua) | yes | per-slot hover flyout: indicator, secure hover snippets, entry pool |
| [`modules/MacroBar.lua`](../modules/MacroBar.lua) | yes | container, apply passes, combat deferral, bus receiver |
| [`settings/MacroBar.lua`](../settings/MacroBar.lua) | yes | the Macro Bar page + every `macroBar.*` schema row |
| [`core/LSMPatch.lua`](../core/LSMPatch.lua) | — | third-party fixup: collapses the `LSM30_Border` widget's 42px preview tile, which misaligns inside a canvas-layout panel |

The split is deliberate: all the logic worth testing is in the three `core/`
files, which `tests/test_macrobar.lua` exercises headlessly. The `modules/`
files are a thin apply pass whose behavior can only be validated in-game
(see [smoke-tests.md](./smoke-tests.md)).

`core/MacroDisplay.lua` is also used by `modules/KCMMacroDragIcon.lua` — the
per-category drag icon in the settings panel — so icon/tooltip resolution can't
drift between the two surfaces.

### Vendored library

The border-style pickers use `LSM30_Border` from
`libs/AceGUI-3.0-SharedMediaWidgets` (vendored, committed, loaded from the TOC
after AceGUI + LibSharedMedia — same as KickCD). Two things to know about those
widgets:

* their preview tile is pinned to the widget's TOPLEFT, which leaves a 42px hole
  next to the closed dropdown in a canvas panel — `core/LSMPatch.lua` re-anchors
  it at `PLAYER_LOGIN` (a verbatim copy of KickCD's fixup; keep them in step);
* they fire `OnValueChanged` **without** calling `SetValue` first, because they
  assume AceConfigDialog will re-render the widget afterwards. Our panel does
  not, so `makeDropdown` in `settings/Panel.lua` pushes the value back
  explicitly or the dropdown keeps showing the old name even though the DB write
  landed.

## Why the bar is CM-only

A slot's identity is a **category key**, not an arbitrary macro or item. The
secure `macro` attribute is stamped once in `MacroBarButton.Create` and never
rewritten, so:

* nothing outside `KCM.Categories.LIST` can occupy a slot — the drop handler
  resolves the cursor through `MacroBarModel.KeyForMacroName` and silently
  ignores anything that isn't a `KCM_*` macro, leaving the cursor untouched;
* reordering only moves **anchors**, never attributes, which is what keeps the
  combat story simple.

## Buttons

Each slot draws, from the bottom up:

| Layer | What | Frame level |
|-------|------|-------------|
| `backdropTex` | flat fill behind the icon (`buttonBackdrop*`) | button |
| `icon` | the pick's texture, cropped by `iconZoom` via `SetTexCoord` | button |
| `cooldown` | `CooldownFrameTemplate` swipe | +1 |
| `border` | `BackdropTemplate` child, `edgeFile` = an LSM border | +2 |
| `overlay` | holds the stack count + the label fontstrings | +3 |

Two details worth not re-deriving:

* **The border is its own frame, not a texture on the button.** That's what lets
  `buttonBorderOffset` anchor it *outside* the button's edges. The original
  implementation used the action-button slot art (`UI-Quickslot2`), a fixed 64px
  frame drawn around a 36px icon well — it bled across the icon at every button
  size, which is exactly the bug the offset + LSM border replaced.
* **Count and label live on the `overlay` child, not on the button.** A corner
  fontstring on the button itself renders *below* the border frame and gets
  sliced by a thick edge texture. Three explicit frame levels beat relying on
  draw layers, because `Cooldown` is a frame rather than a layer.

Labels are on by default, anchored just outside the bottom edge so they clear
both the icon and the flyout band on top. `MacroBarLayout.LabelAnchor` turns the 9-way
`labelPoint` + `labelPlacement` (inside / outside) into `point, relPoint, x, y,
justifyH`; `LabelFontSize` derives the point size from the button size so labels
stay proportional, clamped to 6–24pt. With `labelText = "AUTO"` the button sets
the full display name, measures `GetStringWidth()` against the button, and falls
back to the category's `shortName` (from `defaults/Categories.lua`) only if it
doesn't fit — measuring beats guessing a character budget, since the answer
depends on font, size and string. `OUTSIDE` labels skip the measurement: they
have the whole screen to overflow into.

## The flyout

A shaded band across one edge of each icon carries a small arrow. Hovering
anywhere on that band opens a strip of secure buttons, one per candidate in
that category the player can actually use right now — every owned item and known
spell, **including the one the macro currently points at** — with the top-ranked
entry closest to the button. On by default. This is a bar feature only: a `KCM_*`
macro dragged onto a Blizzard action bar is an ordinary macro with no flyout.

`Selector.ListAvailable(catKey, specKey, scoreCache)` is the source of truth, and
it has three shapes:

| Category | Rule |
|----------|------|
| single-pick | the effective priority list, filtered to what's owned / known |
| per-hand (`WPN_ENCH`) | filtered to enhancements matching an **equipped** weapon's affinity (union of slot 16 + 17, deduped, rank order kept), so nothing unusable on your current weapons is offered |
| composite (`*_AIO`) | concatenation of each **enabled** sub-category's own list, in the composite's configured order (in-combat sections first), deduped — an AIO flyout is the whole health / mana toolkit |

`MacroBarLayout.Flyout` places the entries. One subtlety worth not re-deriving:
`flyoutGap` (the standoff from the button, so a thick or offset button border
can't overlap the first entry) is applied as an inset **inside** the container,
while the container itself stays anchored flush to the button's edge. That keeps
the gap covered by the container's own mouse-enabled area. Anchoring the
container away from the button instead would make the gap dead space, and
crossing dead space fires the secure `_onleave` — the flyout would snap shut just
as the user reached into it.

`MacroBarFlyout.Candidates` then caps the list (`flyoutMax`, itself bounded by
`MacroBarFlyout.MAX_ENTRIES` because the pool can only grow out of combat) and
applies `flyoutInvert`. Truncation emits a debug line rather than silently
dropping entries.

Entries are **not** drag-registered: they launch one specific candidate, and
picking one up would just put a bare item on the cursor.

### The indicator band

The band is drawn **inside** the icon, hugging `flyoutPoint`'s edge and spanning
it fully — part of the artwork, not an ornament stuck to the outside. Three
details that were bugs the first time round:

* **The arrow is a square glyph centerd on the band**, sized at
  `flyoutArrowScale` percent of the band's thickness — over 100% (the default) it
  deliberately overflows onto the icon, which is what keeps it readable on a
  small button. Stretching a texture across the band's full width is what made
  the first attempt look smeared.
* **The arrow texture points RIGHT at rest.** `FLYOUT_EDGES.rotation` turns it to
  face away from the button, so TOP is a quarter turn, not zero. Swap the texture
  for one with a different rest orientation and that table is the thing to fix —
  getting it wrong renders an "up" arrow pointing sideways, which is exactly how
  it shipped the first time.
* **The band is motion-enabled but not click-enabled**
  (`SetMouseClickEnabled(false)` + `SetMouseMotionEnabled(true)`), so hovering it
  opens the flyout while a click passes straight through to the macro underneath.
  The whole icon stays clickable.
* **Frame level is button + 1** — above the icon, below the border (+2) and the
  count/label overlay (+3), so those still draw on top. Neither takes mouse
  input, so neither blocks the band's hover.

Thickness is clamped to half the button, so no combination of a big
`flyoutIndicatorSize` and a small `buttonSize` can swallow the icon.

### Why hover is a secure snippet

Flyout entries have to *use* items, so they're `SecureActionButton`s, so they're
protected frames — and showing a protected frame in combat is forbidden to addon
code. A Lua `OnEnter`/`OnLeave` pair would work on the training dummy and fail
silently the moment a combat potion mattered.

So the hover behavior is handed to the secure environment: the indicator and the
container are `SecureHandlerEnterLeaveTemplate` frames with `_onenter` /
`_onleave` snippets. Both frames hold refs to each other and run the same test —
`if flyout:IsUnderMouse(true) or indicator:IsUnderMouse(true) then keep open` —
so traveling from the arrow into the strip doesn't dismiss it. `MacroBarLayout.Flyout`
deliberately anchors the container flush to the button's edge for the same
reason: a gap would be dead space that closes the flyout mid-journey.

### Closing

Three ways out, and only one of them is compromised in combat:

| Trigger | Mechanism | Works in combat? |
|---------|-----------|------------------|
| mouse leaves the band and the strip | secure `_onleave` snippet | **yes** |
| clicking the macro, or any flyout entry | `PostClick` hook → `FO.Close` | **no** |
| `flyoutAutoClose` seconds of no interaction | our own `C_Timer` → `FO.Close` | **no** |

Hover-out is the only close path that survives combat, and both of the others
funnel through `FO.Close`, which declines to act while `InCombatLockdown()` is
true rather than attempting a hide the client may refuse.

That's a limit, not an oversight, and it's worth recording why each one is stuck:

* **Click** — `PostClick` runs as ordinary insecure Lua no matter that a hardware
  event fired it, so it has no more authority than a timer does. The obvious
  alternative, wiring a secure `_onclick` snippet, doesn't fit either: the slot
  and the entries are `SecureActionButton`s, not secure *handlers*, so they have
  no `SetFrameRef` and no snippet environment of their own — an earlier attempt
  to use `SecureHandlerWrapScript` here crashed on exactly that. Making them
  handlers as well would put a second owner on their `OnClick`, which is the one
  script Blizzard's action handling needs.
* **Timer** — there is no timer inside the secure environment at all: no
  `C_Timer`, and macro conditionals have no time predicate, so a state driver
  can't stand in.

In practice the gap is narrow, because clicking anything means the cursor is
about to move, and the moment it does the secure `_onleave` fires. The timer is
armed from the container's `OnShow` (the open itself happens in a snippet we
can't hook) and re-armed by any hover over the strip, with a token so the newest
open always wins. `flyoutAutoClose = 0` turns it off entirely.

### What is frozen in combat

Binding an entry writes a secure attribute, and creating one creates a protected
frame. Both are combat-forbidden, so flyout **content** is rebuilt out of combat
only — `MacroBar.Refresh` queues `pendingUpdate` instead when it's called during
a fight, and `FlushPending` picks it up at regen.

The consequence is deliberate: **a flyout's entries are frozen for the duration
of a fight.** Drink your last potion mid-combat and its entry stays listed until
combat ends, where clicking it simply fails — the same staleness any action bar
has. Cooldown swipes are the exception and do keep updating live, because
repainting a `Cooldown` frame is unprotected.

### Label clearance

`MacroBarLayout.IndicatorClearance` pushes a button label clear of the indicator
whenever the two share an edge, scaled to the arrow's thickness. It's automatic
rather than a setting because both the label position and the indicator edge are
user-configurable, and the clearance has to hold for every combination. An
`OUTSIDE` label is left alone — it's already past the button edge, where the
user's own offsets are the only sensible answer.

## The drag handle

A full bar has no bare container left to grab — every pixel inside it is a
button, and a button's `OnDragStart` runs `PickupMacro`. So unlocking the bar
shows a labeled strip above it (`KCMMacroBarHandle`, a child of the container)
whose drag scripts call `StartMoving` on the bar. It's sized to the wider of its
own text and the bar, and hidden again on lock. The gold wash over the bar stays
as the "this is unlocked" signal.

## Defaults & the v2 migration

The bar ships **enabled and unlocked**. The reasoning: a bar nobody sees is a bar
nobody configures, and unlocked means the drag handle is right there to place it
on first login. Switching it off hides the container and stops every refresh
path, and nothing is rebuilt until it's re-enabled, so opting out is cheap.

Upgrading profiles are brought to the same starting point by schema **v2**
(`Database.MigrateMacroBarV2`): it forces `enabled = true` + `locked = false`
once. New installs don't need it — AceDB injects the defaults — but a profile
carrying a partial `macroBar` table from an earlier build of this feature does.
The step is **one-shot**: `RunMigrations` bumps `schemaVersion` past it, so a
later deliberate "off" or "locked" is never stomped on the next login.

## Combat contract

Everything here follows from one rule: **buttons are protected frames.**

| Operation | How it's handled |
|-----------|------------------|
| create slots, anchor them, `Show`/`Hide` them, `SetSize`/`SetPoint` the bar | `MacroBar.Update()` early-outs when `InCombatLockdown()`, sets `pendingUpdate`, and `KCM:OnRegenEnabled` calls `MacroBar.FlushPending()` |
| combat-conditional visibility | `RegisterStateDriver(bar, "visibility", "[combat] hide; show")` — Blizzard's secure environment performs the toggle, so it works mid-fight, taint-free |
| hover fade | `SetAlpha`, unprotected and safe in combat. Faded buttons stay clickable by design |
| lock / unlock | `EnableMouse` + a texture toggle on the unprotected container — safe in combat |
| drag out to a Blizzard bar | `PickupMacro`, the same taint-free pattern the settings-panel drag icon uses |
| drag-to-swap | blocked in combat with a chat notice (the relayout that follows anchors protected frames) |

`MacroManager` remains the sole caller of `CreateMacro` / `EditMacro` /
`DeleteMacro`; nothing in the bar writes a macro.

## Config shape

`db.profile.macroBar`, seeded from `KCM.dbDefaults` in
[`core/ConsumableMaster.lua`](../core/ConsumableMaster.lua). AceDB merges the
defaults, so adding the table needed no schema migration.

Every scalar has a matching `KCM.Settings.Schema` row registered by
`settings/MacroBar.lua`, which is what gives each one both a widget on the page
and a `/cm get|set macroBar.<field>` path. `enum`s are `type = "string"` rows
with a `values` list; `Helpers.ValidateSchemaValue` rejects anything outside it,
so the dropdown and the CLI can't write a value the renderer can't display. The
two border-style rows add `lsm = "border"` and pass `values` as a **function**
(`H.LSMValues("border")`) so the list is re-queried at click time — another addon
can register a border after our schema is declared.

Two non-scalar fields are edited outside the schema:

* `order` — the slot order, changed by dragging one slot onto another
  (`MacroBar.SwapSlots` → `MacroBarModel.Swap`). `MacroBarModel.Order()` repairs
  a saved order on read: unknown keys dropped, newly-shipped categories
  appended. The default is the cosmetic panel order in `KCM.Settings.order`,
  duplicated as a literal in `dbDefaults` because `Panel.lua` loads much later —
  `tests/test_macrobar.lua` guards the two against drift.
* `shown` — `[catKey] = false` hides a slot. **Unset means visible**, so a
  category shipped after a profile was written appears rather than vanishing.

## Refresh paths

| Trigger | Path |
|---------|------|
| macro bodies rewritten | pipeline publishes `MSG.MACROBAR_REFRESH`; the bar owns the only receiver and repaints icons + counts |
| a cooldown starts | `SPELL_UPDATE_COOLDOWN` / `BAG_UPDATE_COOLDOWN` → `KCM:OnCooldownUpdate` → `MacroBar.RefreshCooldowns()`. The swipe animates itself after `SetCooldown`, so there is no `OnUpdate` loop |
| a setting changes | the schema row's `onChange` → `MacroBar.Update()` (idempotent, self-deferring) |
| login / reload | `KCM:OnPlayerEnteringWorld` → `MacroBar.Update()`, a no-op while disabled |

The only `OnUpdate` in the feature is the hover-fade poll, registered solely
while **Fade unless hovered** is on and throttled to 0.1s. It uses
`IsMouseOver()` rather than an `OnEnter`/`OnLeave` pair so hovering a *slot*
counts as hovering the bar.

## Deliberately not built

Tracked as GitHub issues rather than half-implemented:

* [#7](https://github.com/tusharsaxena/ConsumableMaster/issues/7) — per-slot keybindings,
* [#8](https://github.com/tusharsaxena/ConsumableMaster/issues/8) — configurable cooldown / count styling (currently stock Blizzard),
* [#9](https://github.com/tusharsaxena/ConsumableMaster/issues/9) — styling for a slot whose category has no current pick (currently the
  macro's own fallback icon shows, undimmed).

Flyout entries deliberately have no per-entry styling of their own beyond size
and spacing: they borrow the button border settings so the strip reads as part of
the same bar.
