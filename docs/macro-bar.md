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

Entries take the **whole** button-appearance block — background, border style /
thickness / offset / color, icon zoom, stack count — so the strip is visibly the
same kind of thing as the bar. The container gets a backdrop (`flyoutBackdrop`, on by default) with the bar's
border style and its own fill color; without it a flyout opening over a second row
of bar buttons is nearly indistinguishable from more bar. That backdrop lives on a
**child frame** (`flyout.bg`), not on the container: combining
`"SecureHandlerEnterLeaveTemplate, BackdropTemplate"` silently dropped the secure
handler's method injection, so `SetFrameRef` came back nil and construction blew
up. **Never combine a secure template with another template** — give the second
concern its own frame, the way the button borders do. `flyoutPadding` insets the entries so that
backdrop reads as a frame rather than sitting flush.

### The indicator band

The band is drawn **inside** the icon, hugging `flyoutPoint`'s edge and spanning
it fully — part of the artwork, not an ornament stuck to the outside. Three
details that were bugs the first time round:

* **The arrow is a square glyph centered on the band**, sized at
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

`flyoutIndicatorScale` is a **percentage of the button**, not a pixel count, so
the band keeps its proportions when the bar is resized. `BL.IndicatorThickness`
resolves it and clamps to half the button, so no combination of a deep band and a
small button can swallow the icon.

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
| `flyoutAutoClose` seconds with the mouse off it | idle poll → `FO.IdleTick` | **no** |
| mouse leaves, with `flyoutAutoClose = 0` | secure `_onleave` snippet | **yes** |
| mouse leaves, **in combat**, any setting | secure `_onleave` snippet | **yes** |
| clicking the macro, or any flyout entry | `PostClick` hook → `FO.Close` | **no** |

The first two rows are one decision, and getting it wrong is what made the
setting look broken: `_onleave` used to hide unconditionally, which pre-empted the
countdown every time, so `flyoutAutoClose` had **no observable effect at all**.
Now leaving hands off to the countdown whenever one is configured.

The snippet needs two facts from the Lua side to make that call, both passed as
attributes because a restricted-environment snippet can read nothing else:

* **`kcmGrace`** — the configured delay, written by `Apply`. Zero means "close on
  leave" and the snippet hides immediately.
* **`kcmCombat`** — `"1"` while in combat, fed by
  `RegisterAttributeDriver(flyout, "kcmCombat", "[combat] 1; 0")`. The snippet has
  no `InCombatLockdown`, and it matters here: the idle poll is insecure and cannot
  hide mid-fight, so if the snippet also declined, the strip would sit open for the
  rest of the fight. In combat it therefore closes on leave regardless of the
  delay.

Everything that hides from Lua funnels through `FO.Close` / `FO.IdleTick`, which
decline while `InCombatLockdown()` is true rather than attempting a hide the client
may refuse.

That's a limit, not an oversight, and it's worth recording why each one is stuck:

* **Click** — `PostClick` runs as ordinary insecure Lua no matter that a hardware
  event fired it, so it has no more authority than a timer does. The obvious
  alternative, wiring a secure `_onclick` snippet, doesn't fit either: the slot
  and the entries are `SecureActionButton`s, not secure *handlers*, so they have
  no `SetFrameRef` and no snippet environment of their own — an earlier attempt
  to use `SecureHandlerWrapScript` here crashed on exactly that. Making them
  handlers as well would put a second owner on their `OnClick`, which is the one
  script Blizzard's action handling needs.
* **Idle close** — there is no timer inside the secure environment at all: no
  `C_Timer`, and macro conditionals have no time predicate, so a state driver
  can't stand in.

`flyoutAutoClose` measures time the mouse has spent **off** the flyout, so any
hover resets it — pointing at the strip must never yank it away. That's why it's
an `OnUpdate` poll (`FO.IdleTick`, started from the container's `OnShow`) and not
a one-shot `C_Timer`: a one-shot would have to re-arm itself on every
expiry-while-hovered, which is unbounded recursion. The poll runs only while a
flyout is open — a second or two at a time.

In practice the gap is narrow, because clicking anything means the cursor is
about to move, and the moment it does the secure `_onleave` fires. `flyoutAutoClose = 0` turns the idle close off entirely.

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

That exception only holds because of *how* the swipe is set. Once a fight
starts, `C_Spell.GetSpellCooldown` returns secret numbers, which a tainted
caller may neither compare nor pass to `SetCooldown`. Both the slots and the
flyout's entries go through `MacroBarButton.ApplyCooldown`, which branches on
the NeverSecret `isActive` and paints from a duration object — the one setter
the client accepts from us mid-combat. See
[midnight-quirks.md](./midnight-quirks.md#secret-values).

### GCD-swipe suppression

`macroBar.showGCD` (default `false`, i.e. suppression is ON out of the box)
hides the ~1.5s global-cooldown swipe that would otherwise flash across every
button on every cast — noise that tells the user nothing, since a REAL
cooldown's swipe is unaffected either way.

The same secret-value problem as above rules out the obvious fix
(`if duration <= 1.5 then hide`): once combat starts, comparing a cooldown's
duration in Lua is a hard error. `MacroBarButton.ApplyCooldown` instead builds
a step-shaped curve once, lazily (0 for remaining ≤ `KCM.GCD_UPPER` [1.6s,
`core/Constants.lua`], 1 above it), and hands it to the duration object's
`EvaluateRemainingDuration` — a C method that accepts a secret-tainted value
and runs the comparison C-side. The result feeds
`SetAlphaFromBoolean(true, value, 0)`, also a C method safe to call with a
secret-derived value. No secret ever reaches Lua.

The pattern (curve, threshold constant, and the lazy-build-once guard) is
copied verbatim from the user's KickCD addon
(`modules/IconGrid_Render.lua`'s `buildGcdSuppressCurve` /
`applyGcdSuppressionAlpha`, `core/Constants.lua`'s `Const.GCD_UPPER`) rather
than shared through LibKa0s — see closed issue [GCD-01](https://github.com/tusharsaxena/ConsumableMaster/issues/26) for why.

**Accepted tail-fade behavior.** The curve evaluates REMAINING duration, which
can't distinguish a lone 1.5s GCD from the last 1.5s of a 60s cooldown — that
would need the TOTAL duration, which is also secret. So a real cooldown's
swipe vanishes for its own final ~1.6s instead of visibly counting down to
zero. This is a deliberate, documented limitation (matching KickCD), not a bug
to engineer around.

`BB.ApplyCooldown` always resets to `SetAlpha(1)` when it isn't suppressing —
load-bearing, since without it a frame faded during a GCD would stay faded
forever the moment the user turns `showGCD` on.

**Bling.** The completion sparkle (`CooldownFrameTemplate`'s "bling") is not
covered by the frame's alpha the way the swipe and edge are — confirmed
in-game, fading the frame suppresses the swipe but the bling still fires — so
`ApplyCooldown` drives it separately via `cd:SetDrawBling(not suppress)`.
Unlike the curve-evaluated alpha, `SetDrawBling` takes a plain boolean, so it
keys off the non-secret `suppress` flag (derived from `cfg.showGCD`) rather
than the curve's secret-tainted output. It is applied even on the `not active`
early-return path, since the setting can change while a cooldown is idle.

**Accepted consequence.** With `showGCD` off, a REAL cooldown also loses its
completion sparkle, not just the GCD's — `SetDrawBling` has no way to tell
"this bling belongs to a GCD" from "this bling belongs to a real cooldown" any
more than the alpha curve above can, and distinguishing them would need the
secret total duration. This is arguably more coherent anyway: the tail-fade
above already makes a real cooldown's swipe vanish over its final ~1.6s, so a
sparkle at completion would appear with no swipe behind it. Deliberate, not a
gap.

### Label clearance

`MacroBarLayout.IndicatorClearance` pushes a button label clear of the indicator
whenever the two share an edge, scaled to the arrow's thickness. It's automatic
rather than a setting because both the label position and the indicator edge are
user-configurable, and the clearance has to hold for every combination. An
`OUTSIDE` label is left alone — it's already past the button edge, where the
user's own offsets are the only sensible answer.

## The drag handle

A full bar has no bare container left to grab — every pixel inside it is a
button, and a button's `OnDragStart` picks the macro up. So unlocking the bar
shows a labeled strip above it (`KCMMacroBarHandle`, a child of the container)
whose drag scripts call `StartMoving` on the bar. It's sized to the wider of its
own contents and the bar, and hidden again on lock. The gold wash over the bar
stays as the "this is unlocked" signal.

At its right end sits a **help icon** whose tooltip spells out the three drag
gestures (move the bar, swap two slots, drop a macro on an action bar) plus the
two constraints worth knowing (CM macros only; lock to hide the handle). An icon
rather than a second line of hint text, because the bar can be a single button
wide — prose long enough to explain both gestures would either clip or force the
handle wider than the bar it labels, while a 14px icon costs the same at every
width. The handle's own tooltip stays a single line, so hovering it to drag
doesn't dump a wall of text.

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
| drag out to a Blizzard bar | `MacroDisplay.Pickup`, shared with the settings-panel drag icon. `PickupMacro` is **protected**, so it is blocked in combat with a chat notice rather than an `ADDON_ACTION_BLOCKED` error; the drop itself is Blizzard's own taint-free `PlaceAction` flow |
| drag-to-swap | blocked in combat with a chat notice (the relayout that follows anchors protected frames) |

`MacroManager` remains the sole caller of `CreateMacro` / `EditMacro` /
`DeleteMacro`; nothing in the bar writes a macro.

## Config shape

`db.profile.macroBar`, seeded from `KCM.dbDefaults` in
[`defaults/Profile.lua`](../defaults/Profile.lua). AceDB merges the
defaults, so adding the table needed no schema migration.

Every scalar has a matching `KCM.Settings.Schema` row registered by
`settings/MacroBar.lua`, which is what gives each one both a widget on the page
and a `/cm get|set macroBar.<field>` path. `enum`s are `type = "string"` rows
with a `values` list; `Helpers.ValidateSchemaValue` rejects anything outside it,
so the dropdown and the CLI can't write a value the renderer can't display. The
two border-style rows add `lsm = "border"` and pass `values` as a **function**
(`H.LSMValues("border")`) so the list is re-queried at click time — another addon
can register a border after our schema is declared.

`macroBar.perRow` has THREE hand-maintained copies of "the managed category
count," and all three went stale (13 → 15) when this branch added two
categories: the `dbDefaults` default (`defaults/Profile.lua`), the
settings-page slider `max` (`settings/MacroBar.lua`), and
`core/MacroBarLayout.lua`'s own internal `perRow` fallback inside
`normalize()`, used only when `Grid`/`Dimensions` is called with no `perRow`
in `cfg` at all. Only the slider `max` is derived (`#KCM.Categories.LIST`) —
`settings/` loads after `defaults/` in `ConsumableMaster.toc`, so the table
already exists when the row is declared. The other two stay literals:
`defaults/Profile.lua` can't derive because it loads before
`defaults/Categories.lua`, and `core/MacroBarLayout.lua`'s fallback was kept a literal on
purpose since `normalize()` is a hot pure-math path and the fallback only
ever fires when a caller omits `perRow` entirely. All three are pinned
together by "macrobar defaults: perRow tracks the number of managed
categories" in `tests/test_macrobar.lua`, which fails if any one drifts from
`#KCM.Categories.LIST` — the layout fallback is observed indirectly, via
`Grid`'s reported column count, since `normalize` itself isn't exported.

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
| a cooldown starts | `SPELL_UPDATE_COOLDOWN` / `BAG_UPDATE_COOLDOWN` → `KCM:OnCooldownUpdate` → `MacroBar.RefreshCooldowns()`. The swipe animates itself once set, so there is no `OnUpdate` loop. In combat the spell cooldown API goes secret, so the setter is `SetCooldownFromDurationObject` via `MacroBarButton.ApplyCooldown` — see [midnight-quirks.md](./midnight-quirks.md#secret-values) |
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

Flyout entries have no styling of their own beyond size, spacing and padding —
everything else is inherited from the button-appearance block, deliberately, so
the two surfaces can't drift apart.
