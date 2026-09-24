# Profiles

ConsumableMaster stores **every setting per profile**, and surfaces AceDB's own profile management as
a settings page. That makes profiles part of the addon's user-visible behavior rather than an AceDB
implementation detail, which is why they have a page here (`documentation-§3`).

The stored shape inside a profile is [schema.md](schema.md); the pages around this one are
[settings-panel.md](settings-panel.md).

## Where profiles sit

`core/ConsumableMaster.lua` opens the store with `AceDB:New("ConsumableMasterDB", KCM.dbDefaults, true)`
— the `true` naming a shared **Default** profile, so every character starts on the same working
setup rather than an empty one. `defaults/Profile.lua` is the **only** place a profile default is
declared (`savedvariables-§2`).

Everything the player can set lives in `db.profile`, so a profile carries all of it:

| In the profile | What it is |
|---|---|
| `enabled`, `visibility`, `scale`, `alpha` | The General page's Master controls |
| `categories` | Every category's added / blocked / pinned / discovered sets (per spec for the four spec-aware ones), each composite's enabled flags and two section orders, and Battle Rez's mouseover flag |
| `statPriority` | Every spec's stat order |
| `macroBar` | Every Macro Bar setting, the slot order and shown set, and the drag-set position |
| `macroState` | The macro fingerprint cache — learned data, not a setting, but per profile all the same |

Three things are deliberately **not** in a profile, and none of them moves when one does:

- `global.schemaVersion`, the account-wide migration marker. Its shipped default is `0`, never a
  real version: AceDB strips a stored value equal to its default at logout, and backfills a declared
  default onto a legacy account that stored none, so a real version there could erase the stamp or
  make a pre-runner account read as migrated (`savedvariables-§1`). `RunMigrations` walks it to the
  current version.
- `ConsumableMasterPerfDB`, the perf capture ring. It is a SavedVariable of its own, outside AceDB
  entirely (`ConsumableMaster.toc:11`).
- The debug console's visibility and the session logging flag. Both are session state.

**The macros themselves are account-wide.** WoW has one `KCM_FOOD` per account, not one per profile.
Two characters on different profiles take turns rewriting the same set of macros, each to its own
profile's picks, which is why a profile act always ends in a full rewrite (below).

## The Profiles page

`settings/Profiles.lua` registers a canvas subcategory whose body hosts an AceGUI `SimpleGroup`, into
which `AceConfigDialog` renders **AceDBOptions'** own options table: create, switch, copy, reset and
delete, plus the per-character / per-class / per-realm / per-faction / default scope choices.

Five decisions in that file are deliberate:

- **It is the one place AceConfig is used** (`options-ui-§3`, `library-stack-§2`). Every other page
  is drawn by this addon from `KCM.Settings.Schema`. The options table here is Ace's, not the addon's,
  and re-expressing it as schema rows would mean keeping a copy of AceDB's profile model that goes
  stale the first time AceDB adds a scope.
- **No Defaults button.** The panel is created with no `defaultsAction`, so `Helpers.CreatePanel`
  asks the library for `defaultsButton = false`. "Restore defaults" here would mean deleting the
  player's profiles, and the page already carries its own destructive controls.
- **Rendered into our container, not its own window.** `AceConfigDialog:Open` accepts any AceGUI
  container as its target, so the widgets land inside the canvas, under the addon's header and
  breadcrumb, instead of in a floating dialog over the Settings panel.
- **Redrawn on a profile event, and on nothing else.** The draw is the page's `Helpers.SetRenderer`
  body, so the library's combat refusal covers the Blizzard AddOns sidebar path too. SetRenderer also
  puts the page on the library's structural refresh, and the pipeline publishes a debounced
  `PANEL_REFRESH` after every recompute, on every loot and bag change. A renderer that re-opened on
  each of those would tear AceConfigDialog's tree down under an open dropdown (`options-ui-§11`), so
  the renderer draws once per `PROFILE_CHANGED`, counted: at once if the page is on screen, on its
  next show if not (`Helpers.RefreshPanel`). A change made *on* the page needs nothing, because
  AceConfigDialog re-opens its container after every control it activates.
- **No tab strip, and last in the sidebar.** It carries no schema rows, so there is nothing for a
  strip to partition. It is one of the two pages `options-ui-§13` exempts, the landing page being the
  other. `KCM.Settings.order` names it last, and the TOC loads its file last.

The page is built from four silently-resolved libraries: `AceDBOptions-3.0`, `AceConfig-3.0`,
`AceConfigDialog-3.0` and `AceGUI-3.0`. With any of them missing, the builder answers `nil` and the
page is simply absent. Everything else in the panel is unaffected (`library-stack-§4`).

## Reacting to a profile change

A profile act is not a settings change: every stored value is different afterwards, and every surface
has to follow. `KCM.RegisterProfileCallbacks` (`core/ConsumableMaster.lua`) installs **one** reaction
for all three AceDB callbacks:

```lua
db.RegisterCallback(target, "OnProfileChanged", reload("profile_changed"))
db.RegisterCallback(target, "OnProfileCopied",  reload("profile_copied"))
db.RegisterCallback(target, "OnProfileReset",   reload("profile_reset"))
```

It runs five steps, in this order:

1. **The act's one log line** (below).
2. **The migrations** (`KCM.Database.RunMigrations`), for an incoming profile an older build wrote.
   Each profile carries its own `schemaVersion`, so a profile arriving for the first time under this
   build is walked forward on arrival ([schema.md](schema.md#migrations)). That is how the
   profile-scoped steps reach every profile rather than only the one live at the upgrade login.
3. **On a switch or a copy, the macro fingerprints are forgotten** (`MacroManager.InvalidateState`).
4. **The resync** (`afterReset`): tooltip cache invalidated, the bags re-read, and every category
   recomputed and its macro rewritten against the incoming profile.
5. **`PROFILE_CHANGED` on the bus.** It is the message this addon's surfaces rebuild off
   (`options-ui-§12`), and it is sent after the resync so the bar re-applies itself against macros
   that already carry the incoming profile's bodies.

The three signatures differ, and the handler does not trust the third argument to name the active
profile. AceDB hands `(event, db, newKey)` for *Changed* and `(event, db, sourceKey)` for *Copied*,
and `(event, db)` for *Reset*. The handler reads the active profile off `db:GetCurrentProfile()`
instead, and uses the third argument only as a copy's source.

### Why the fingerprints are forgotten

`MacroManager` skips a write when a macro's stored fingerprint (`profile.macroState[name]`) already
matches the body and icon it is about to write. That early-out is sound within one profile and wrong
across two. The fingerprints are per profile and the macros are per account, so the incoming
profile's fingerprint describes the body **it** last wrote, not what the account's macro holds now.
The live macro holds the outgoing profile's body.

The case that matters is the round trip. Default writes item A into `KCM_FOOD`. Alt blocks A and
writes item B. Back on Default, Default computes A again and finds its own stored fingerprint saying
A. The early-out skips the write, and B stays live under Default's settings. A copy has the same
shape, because it brings the source profile's fingerprints in with everything else.

So a switch and a copy both clear the cache before the resync, and every macro is rewritten. A reset
needs no call: it has already emptied `macroState` with the rest of the profile.

### Who listens to `PROFILE_CHANGED`

One sender, the reaction above (`architecture-§4`). Three receivers, each on its own bus target:

| Receiver | What it does |
|---|---|
| `modules/MacroBar.lua` | `MacroBar.Update()`, the bar's whole re-apply: anchor, backdrop, grid, slot order, shown slots, lock, visibility and alpha. The pipeline's `MACROBAR_REFRESH` only repaints icons and counts, so without this the outgoing profile's bar stayed on screen until `/reload`. Update takes its disable path when the incoming profile has the bar off, and defers itself wholesale to regen in combat. |
| `settings/OptionsShim.lua` | `KCM.Options.Refresh()`, an immediate structural refresh of the settings page on screen, with every other page marked dirty. The debounced `PANEL_REFRESH` is a second or more late, and a page drawn from the outgoing profile holds controls that read and write it. |
| `settings/Profiles.lua` | Counts the event and asks for the page's own redraw (above). |

### The log line (`debug-logging-§10`)

A profile act is not a batch through the schema helper: AceDB replaces the whole profile. So the
handler logs it once, worded by the event, and silences any `Helpers.Bulk` bracket open around it
(the write seam's `ConsumeResetCount` marks the open bracket as a profile reset). The result is one line in total, never the handler's line plus an
`outer: N rows` line.

| Event | Line |
|---|---|
| *Reset* | `[Set] reset profile '<name>' to defaults: N rows` (N only when `KCM.ResetAllToDefaults` drove it, counted before the reset) |
| *Copied* | `[Set] copied profile '<source>' → '<active>'` |
| *Changed* | `[Profile] switched to '<name>'` |

A reset and a copy replace the profile's rows, so they carry the `[Set]` tag. A switch rewrites no
rows and takes the `[Profile]` trace MultiMeters and KickCD carry. The reset line has no row count.
N would be the rows the reset actually changed, which needs their values from before it. AceDB has
already replaced the profile when `OnProfileReset` fires, and AceDBOptions' Reset Profile button
gives no earlier hook. A switch or copy is followed by the forced rewrite's own
`[Macro] forced rewrite: cleared …` line and the resync's `[Scan]` and `[Calc]` lines, which
report what the act caused rather than restating the act.

## The global reset is a profile reset

**Reset all settings** (General → Master controls) and `/cm resetall` run `KCM.ResetAllToDefaults`.
That function sweeps the session-only rows and then calls `db:ResetProfile()`, which is the same act
as this page's **Reset Profile** (`options-ui-§12`). Its blast radius is the active profile: the
profile list, the active profile's name and every other profile are untouched.

The sweep asks one veto which rows it may write: `KCM.Settings.VetoedFromResetAll`
(`settings/OptionsSetup.lua`). The veto refuses any row on the Profiles page (`options-ui-§3`) and
every profile-resident row (`options-ui-§12`, since the profile reset covers them). That leaves the
session rows. The same function is the library descriptor's `skipRestoreAll`, so the rule is named
once and enforced on both paths. The addon's global reset does not use the library's
`RestoreAllDefaults` today, so the descriptor field is declarative. It is there so a later adoption
of the library's walk inherits the veto rather than rediscovering it.

The descriptor also carries `resetProfile` (the same `db:ResetProfile()`) and `profilesPage = true`.
The library reads them to word the **Reset all settings** tooltip, which names this page's **Reset
Profile** as the same act. Supplying `resetProfile` does not make `skipRestoreAll` live: the only
reader of either is `RestoreAllDefaults`, and nothing calls it. If a later change did adopt the walk,
the library would narrow it to the `sessionOnly` rows itself before asking the veto, and the veto
would agree, since it keeps exactly those rows.

## Testing

`tests/test_profiles.lua` pins every claim on this page against the harness's AceDB and AceConfig
fakes:
- the page's placement, contents and redraw rule;
- the veto and its sharing;
- the global reset's blast radius and its `PROFILE_CHANGED`;
- the bar's full re-apply after a switch, a copy and a reset;
- the macro rewrite on the round trip and on a copy;
- each act's one log line;
- the immediate panel refresh.

The in-game half, meaning AceDBOptions' real controls driving the real AceDB with the real bar and
macros following, is [smoke-tests.md](smoke-tests.md) §13 and §13a.
