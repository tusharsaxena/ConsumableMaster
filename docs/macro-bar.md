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
| [`modules/MacroBar.lua`](../modules/MacroBar.lua) | yes | container, apply passes, combat deferral, bus receiver |
| [`settings/MacroBar.lua`](../settings/MacroBar.lua) | yes | the Macro Bar page + every `macroBar.*` schema row |
| [`core/LSMPatch.lua`](../core/LSMPatch.lua) | — | third-party fixup: collapses the `LSM30_Border` widget's 42px preview tile, which misaligns inside a canvas-layout panel |

The split is deliberate: all the logic worth testing is in the three `core/`
files, which `tests/test_macrobar.lua` exercises headlessly. The `modules/`
files are a thin apply pass whose behaviour can only be validated in-game
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

Labels are off by default. `MacroBarLayout.LabelAnchor` turns the 9-way
`labelPoint` + `labelPlacement` (inside / outside) into `point, relPoint, x, y,
justifyH`; `LabelFontSize` derives the point size from the button size so labels
stay proportional, clamped to 6–24pt. With `labelText = "AUTO"` the button sets
the full display name, measures `GetStringWidth()` against the button, and falls
back to the category's `shortName` (from `defaults/Categories.lua`) only if it
doesn't fit — measuring beats guessing a character budget, since the answer
depends on font, size and string. `OUTSIDE` labels skip the measurement: they
have the whole screen to overflow into.

## The drag handle

A full bar has no bare container left to grab — every pixel inside it is a
button, and a button's `OnDragStart` runs `PickupMacro`. So unlocking the bar
shows a labelled strip above it (`KCMMacroBarHandle`, a child of the container)
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
