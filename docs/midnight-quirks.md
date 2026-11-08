# Midnight quirks — tooltip parsing, subtype renames, secret values

Catalog of WoW Midnight (Interface 12.0.x–12.1.x) behaviors that bite the addon. When something breaks at patch time, this is where to look first. The first part of this file is the collection's client-quirks catalog, vendored whole from the Ka0s WoW Addon Standard (client-quirks-§1) and replaced wholesale by `/dev-copilot:wow-revendor-standards`; never edit inside its markers. A correction belongs in this addon's own section, which follows it.

<!-- BEGIN VENDORED: quirks catalog v2.103.1 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into every addon's `docs/midnight-quirks.md` (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Client quirks

The client behaviors the collection paid for more than once. Each entry here was discovered
**independently in two or more Ka0s repositories**, written up in each, and promoted by a harvest so the
next addon reads it instead of rediscovering it. A behavior one repo found stays in that repo's
`docs/midnight-quirks.md` until a second repo meets it.

*Why this section exists.* By 2026-11-06 eleven addons kept a private `docs/midnight-quirks.md`, 2,073
lines and about 133 entries between them, and about 81 of those entries were 21 behaviors written up
independently two to eight times. Nine of the eleven opened with their own restatement of the 12.0 secret
rules. Three write-ups contradicted this standard, and one contradiction was this standard's own error
(events-frames-taint-§2, *The combat-start edge*). A catalog was proposed and deferred twice, on
2026-08-25 and 2026-09-22, because an inventory rots; the build stamp per entry (§1) is the answer to that
objection (WowAddonStandards `harvests/2026-11-06/02_FINDINGS.md`, F3-01; every write-up quoted in
`harvests/2026-11-06/03_EVIDENCE.md`, Part A).

### 1. How an entry is written, and how it expires (MUST)

Every entry **MUST** carry:

- **The behavior**, stated as what the client does, not as advice.
- **Measured:** the client build or date it was observed on, where any write-up recorded one. An entry with
  no measurement says *not measured*; that is a weaker entry, not a missing field.
- **Cost:** what happened to an addon that did not know it.
- **Client:** the client it was measured on, `Retail` or `Forever` (clients-§1). An entry that names none is a Retail entry, which is every entry written before v2.103.0; a Forever behavior is written with `Forever` and its build, and it is not assumed to hold on Retail.
- **Do:** the workaround, as a rule an addon can follow.
- **Source:** the deepest write-up — the repo and document that probed furthest — and the harvest that
  promoted it. Every version is quoted in that harvest's `03_EVIDENCE.md`.

**Expiry.** An entry describes a client, and clients move. When the retail interface number moves past the
newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a standard
release — not worked around in the addon. An entry nobody can reproduce moves to §6 as an open probe rather
than being deleted, because the behavior may only have moved.

**What an addon does with this section (MUST): carry it as a vendored block.** This section is the one
part of the standard an addon carries a **copy** of, because it is reference data about the game client
that a working addon needs offline, next to the code that works around it — not a rule, which is only ever
pointed at. Every addon's `docs/midnight-quirks.md` (documentation-§3) is two parts: the vendored block,
opened by a `BEGIN VENDORED` HTML comment naming the catalog's version and source and closed by an
`END VENDORED` HTML comment, each spelled exactly as `/dev-copilot:wow-revendor-standards` writes it; then
the addon's own section. The markers are described here rather than shown, because this text travels
inside them: a literal marker in the vendored copy would give the file a second end marker for the next
re-vendor to cut at.

```markdown
[the BEGIN VENDORED comment, stamped quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own quirks: one no second repo has met, its per-event costs, its own probe tables …
```

- The block is **copied whole and replaced wholesale** by `/dev-copilot:wow-revendor-standards`, stamped with
  the standard version it came from, under the same discipline as `libs/LibKa0s/` (anti-pattern #45): never
  a subset, **never edited inside the markers**. A local edit inside them is reverted by the next revendor,
  and the behavior it fixed comes back with no cause in the addon's history; a correction belongs in the
  addon's own section, where the next harvest finds it.
- The addon's own section **MUST NOT** restate a behavior the block carries. When a harvest promotes an
  entry, the revendor prunes the addon's copy: the upstream entry is the deeper write-up, and two live
  copies of one finding is the shape that drifted three times into contradiction.
- An addon with no quirks of its own still carries the block, with an empty own section.

**Contested behaviors are not rules.** Where two repos recorded opposite behavior and nobody has probed
the difference, the entry goes in §6 with both sides and the probe that would settle it.

Behaviors this standard already states elsewhere are not repeated here: the unknown-event raise
(events-frames-taint-§1), `Settings.OpenToCategory`'s numeric ID and collapsed parent (options-ui-§2),
the protected category switch in combat (options-ui-§2, anti-pattern #88), a secret through `tostring` and
`..` (events-frames-taint-§8), lockdown at `PLAYER_REGEN_DISABLED` (events-frames-taint-§2), the spec
readers' move to `C_SpecializationInfo` (compat, `LibKa0s-Compat-1.0`) and `SendChatMessage`'s move to
`C_ChatInfo` (compat).

### 2. Secret values

**A secret boolean cannot be tested at all.** `if`, `not`, `==` and `and`/`or` on a secret boolean raise
("attempt to compare … (a secret boolean value)"); the value is unusable in Lua, not merely unprintable.
`DurationObject`'s `HasExpired`, `HasStarted`, `IsActive` and `IsZero` come back secret in combat, and an
engine button's `IsShown` has answered a secret boolean out of combat. *Measured:* 12.0.7 (probe table);
12.1 (`IsShown`). *Cost:* a raise on every refresh tick of the path that tests it. *Do:* check
`issecretvalue` before any test; route a secret boolean to a C-side consumer
(`C_CurveUtil.EvaluateColorValueFromBoolean`, `SetAlphaFromBoolean`), or treat it as the cautious answer
(a secret lockdown reads as locked, a secret restriction as active, a secret claim as no claim). Two repos
disagree on whether to gate before the C-side call; that disagreement is recorded in `LibKa0s`
`docs/api/Compat` and is not ruled here. *Source:* KickCD `docs/midnight-quirks.md`, "Secret booleans are
unusable"; seven repos (harvest 2026-11-06, Q6).

**A secret cannot be a table key.** Indexing or assigning with a secret key raises "attempted to perform
indexed assignment on a table that cannot be indexed with secret keys". `UnitGUID` on a follower-dungeon
pet (`party3pet`) answers a secret string. *Cost:* a raise on every refresh tick for a roster keyed by
GUID. *Do:* guard a key with `IsSafeKey` (`LibKa0s-Compat-1.0`) or `issecretvalue` before keying; a
secret GUID is never a handle. *Source:* MultiMeters `docs/midnight-quirks.md`, the follower-dungeon pet
GUID; seven repos (Q7).

**A secret never reaches SavedVariables, and one that does is written as `nil`.** A value captured as
secret stays secret after combat ends, and the client writes a secret to SavedVariables as `nil` — or,
where it was a key, loses the entry. *Measured:* a reload probe, 2026-10-25. *Cost:* silent data loss on
the next reload. *Do:* store a plain value or nothing; never store a captured secret to read later.
*Source:* DpsRace `docs/known-limitations.md`, the reload probe; three repos (Q21).

**A frame handed a secret has secret geometry, and so does everything anchored to it.** After
`StatusBar:SetValue(secret)` (or `SetAlphaFromBoolean`, or anchoring to an aura engine container) the
frame `HasSecretValues`: its width, points and frame level read secret, out of combat too, and the
taint runs down the anchor chain to every frame anchored to it; a tooltip showing hidden information has
secret geometry. A secret size's `type` is `"number"`, so a type check lets it through, and
`BackdropTemplate`'s own arithmetic on a secret size raises. *Cost:* a raise inside Blizzard code, or a
layout computed from a secret. *Do:* compute layout from configuration and never read geometry back from a
frame that was handed a value; keep a record of the alpha you set rather than calling `GetAlpha()`; read a
frame level under a restricted anchor through a secret-safe guard (frame-layering). *Source:* AuraMaster
`docs/midnight-quirks.md`, the aura engine container entries (measured and dated); six repos and
`LibKa0s` `docs/api/Widgets` (Q8).

**A restricted spell's cooldown: branch on `isActive`, paint with the duration object.** In a restricted
state `C_Spell.GetSpellCooldown`'s timings are secret while `isEnabled` and `isActive` stay plain
(documented NeverSecret). `GetSpellCooldownDuration` answers a **zeroed** object, not `nil`, when there is
no cooldown, and a fresh object per call. *Cost:* raw `SetCooldown` with a secret start or duration raises;
a nil check passes the zeroed object. *Do:* decide from `isActive`; paint with
`Cooldown:SetCooldownFromDurationObject`, which accepts the object from tainted code. *Source:* KickCD
`docs/midnight-quirks.md`, the cooldown probe table; four repos (Q9).

**`notInterruptible` is secret, and the interruptibility events make it plain.** The cast info's
`notInterruptible` is secret; `UNIT_SPELLCAST_INTERRUPTIBLE` / `_NOT_INTERRUPTIBLE` deliver it plain.
`CastingBarFrameTemplate`'s built-in `OnUpdate` compares `GetTime()` with a secret `maxValue` and raises
when the bar shows another unit. *Do:* split the gate — the color path takes the secret C-side, the logic
path takes the event's plain value; do not inherit `CastingBarFrameTemplate` for a unit other than the
player. *Source:* KickCD `docs/midnight-quirks.md`, "split the gate in two"; two repos (Q13).

**`InChatMessagingLockdown` can answer a secret.** *Do:* read it through a guard and treat a secret as
locked. *Source:* DropWatcher and QuickComms `core/Compat.lua` (byte-identical), DpsRace; three repos (Q27).

### 3. Events

**A valid event can register without complaint and never fire.** `GUILDBANKFRAME_OPENED` registers and
never fires (*Measured:* 12.0.7); `UNIT_SPELLCAST_SUCCEEDED` is suppressed for protected interrupts;
`UNIT_HEALTH` and `UNIT_NAME_UPDATE` never fire for compound tokens such as `party1target`;
`GET_ITEM_INFO_RECEIVED` does not fire for an item already cached. This is the inverse of the
unknown-event raise (events-frames-taint-§1) and it is silent: nothing errors. *Cost:* a feature that
never runs, with nothing in the log. *Do:* confirm a new event fires in game before building on it, and
prefer an edge with a second source (a frame's `OnShow`, a gated timer) where the event is known to be
silent. *Source:* BankLedger `docs/midnight-quirks.md`, `GUILDBANKFRAME_OPENED`; four repos (Q20).

**Client state can lag its own event, or change with no event at all.** `IsMounted()` has flipped by the
time `PLAYER_MOUNT_DISPLAY_CHANGED` arrives while `C_PlayerInfo.GetGlidingInfo`'s `canGlide` sometimes has
not; after `INSPECT_READY` some slots still answer an item id with no link; switching bank tabs fires no
event, and the live warband tab has taken over a second to catch up; chat lockdown clears with no event.
*Cost:* a read at the edge answers the old state, and the display stays wrong until the next unrelated
event. *Do:* answer at the edge **and once more after a short settle** (a fraction of a second, a bounded
retry), never a poll. *Source:* MultiMeters `docs/midnight-quirks.md`, "some client state lags its own
event"; six repos (Q19).

**An empowered cast fires `UNIT_SPELLCAST_EMPOWER_*`, not the channel events.** `UnitChannelInfo`
reports it, but `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` do not fire for it, and its release fires
`UNIT_SPELLCAST_SUCCEEDED` with the same cast GUID. *Do:* register the `EMPOWER_*` events wherever channels
are tracked. *Source:* KickCD `docs/midnight-quirks.md`, empowered casts; three repos (Q12).

**`ADDON_RESTRICTION_STATE_CHANGED` fires *before* enforcement.** The `Activating` state arrives before the
restriction begins, and access is still permitted during that dispatch; a dungeon restriction type has
gone active on entry and not cleared. Read the restriction type by its `Enum.AddOnRestrictionType` member
name — a member can be missing on some builds. *Measured:* 12.1.0, 2026-09-18. *Do:* treat `Activating`
as the last moment to read, not as the start of the restriction. The payload's second argument is
contested (§6). *Source:* AuraMaster `docs/midnight-quirks.md`, the restriction types; six repos (Q10).

### 4. Combat and secure frames

**Blizzard's aura buttons are forbidden to addon code, and `IsForbidden()` can say otherwise.** In
combat every call on a Blizzard aura button's objects raises "Attempt to access forbidden object from code
tainted by an AddOn"; in an instance (seen in Mythic+) the same buttons answer `IsForbidden()` `false` and
still refuse every read, `GetChildren` included. *Do:* never read Blizzard aura buttons; where a frame
must be inspected, `pcall` the read and treat a failure as forbidden. *Source:* PartyFrameEnhanced
`docs/midnight-quirks.md`, forbidden aura buttons; three repos (Q14).

**Escape runs a protected `Hide()` in combat.** A secure or protected frame listed in `UISpecialFrames` is
hidden by `CloseSpecialWindows`, which is a protected action in combat. *Do:* list a non-secure proxy in
`UISpecialFrames` and hide the protected frame from it out of combat, or keep protected frames out of the
list. *Source:* WhatGroup `docs/midnight-quirks.md`, the escape proxy; two repos (Q24).

### 5. Item, tooltip, enum and realm data

**Item data is nil until cached, and the load event has holes.** `GetItemInfo` answers nothing for an
uncached item; `GET_ITEM_INFO_RECEIVED` does not fire on an addon's first scan for an item the client
already holds; an uncached item's tooltip is not empty but a legible `RETRIEVING_ITEM_INFO` line; a failed
load drops its wait and nothing asks again. *Cost:* a blank or wrong row that never repairs. *Do:* load
through `LibKa0s-Item-1.0`'s cache-then-callback path (library-stack-§7), treat `RETRIEVING_ITEM_INFO` as
not-yet-loaded, and re-ask after a failed load. *Source:* ConsumableMaster `docs/midnight-quirks.md`, the
first-scan hole; seven repos (Q15).

**`C_TooltipInfo` returns raw templates.** Tooltip lines can carry the unexpanded plural grammar
`|4singular:plural;` (*Measured:* 12.1.5, "for the next 3 |4hour:hrs; 49 min") and a no-break space that
Lua's `%s` does not match. *Cost:* a parser that knew only the expanded words read no duration and called a
tradeable drop expired. *Do:* expand `|4…;` before matching, and match the no-break space explicitly.
*Source:* DropWatcher `docs/midnight-quirks.md`, the trade window; two repos (Q16).

**Tooltip line text can be secret** under an addon restriction, including through `TooltipDataProcessor`.
*Do:* guard each line before matching. *Source:* DropWatcher `docs/midnight-quirks.md`; two repos (Q17).

**Blizzard renumbers enums; resolve a member by name, never by number.** One build's
`Enum.TooltipDataLineType` and bank-tab values are not the next build's, and a member can be absent on a
build. *Cost:* a numeric guess for a member the build does not expose landed on an unrelated bank
container. *Do:* read `Enum.X.Member`, and handle its absence; localization-§4 already forbids the string
spelling. *Source:* DropWatcher `docs/midnight-quirks.md`, the research's enum values; five repos (Q18).

**`GetNormalizedRealmName` is nil early in login.** *Cost:* a stored `Name-` key with no realm. *Do:* never
build a `Name-Realm` key before the realm is known; defer, or fall back to `GetRealmName` with its spaces
and hyphens removed. *Source:* DropWatcher `docs/midnight-quirks.md`, realm names; four repos (Q25).

**A template-less `FontString` with no font raises on `SetText`.** "Font not set" from a `FontString`
created without a template or `SetFontObject` takes the addon down at load; a mock that does not enforce it
passes every test. *Do:* give every bare `FontString` a font object before its first `SetText`; the kit's
mock enforces it. *Source:* MultiMeters `tests/mock_frame.lua`, the font-not-set guard; three repos and
`LibKa0s` (Q22).

### 6. Open probes — contested behaviors (not rules)

Each needs an in-game probe, recorded with the build, before any section of this standard changes.

- **WoW Forever behaviors (none recorded yet).** The catalog was written on Retail. The Forever client (build 70790) has a missing-API surface, `SetDesaturation` among it, that LibKa0s tracks in LibKa0s#44, and no quirk entry yet meets this section's two-repo bar for it. Record a Forever behavior in the repo that meets it, with the build, and promote it by a harvest like any other.

- **`string.format` on a secret.** events-frames-taint-§8 says it raises, with three repos; two say it
  works, one with a mid-combat observation. The likely difference is the specifier (`%s` against `%d` and
  `%.1f`) or that the result is itself a secret string. Probe each specifier, in combat, on a damage-meter
  value and a `UnitHealth` value. Until then §8's rule stands.
- **`ADDON_RESTRICTION_STATE_CHANGED`'s second argument.** One repo documents an
  `Enum.AddOnRestrictionState` value; three (one measured) record a boolean as well. Handle both shapes.
  The 2026-09-22 harvest called this settled, and it is not.
- **`SetAllPoints(parent)` on a secure button at load.** One repo records "Cannot anchor protected frames
  to regions" and uses the implicit-parent form; another anchors its secure rows with `SetAllPoints(row)`
  at birth and treats it as working, with its in-game smoke check still owed.
<!-- END VENDORED -->

## ConsumableMaster-specific quirks

## Subtype renames — no longer a classification concern

Blizzard renamed several consumable subType **display strings** in Midnight (`"Potion"` → `"Potions"`; `"Flask"` / `"Phial"` → `"Flasks & Phials"`). This used to break the Classifier, which matched those strings. It no longer does: classification keys on the **numeric** `classID` / `subClassID` from `GetItemInfoInstant` (Consumable=0; subclass Potion=1, Flask/Phial=3, Food & Drink=5), which are locale-independent and unchanged across the renames (localization-§4 / anti-pattern #37 — see [scope.md](./scope.md)). A future display-string rename needs no code change.

`Classifier.MatchAny(id)` returns `{ catKeys }`, so a single item can classify into multiple categories (e.g. "Refreshing Serum" for both `HP_POT` and `MP_POT`). Weapon-affinity (`core/WeaponSlots.lua`) keys on the weapon `subClassID` the same way.

## Tooltip parsing — grammar escapes and NBSP

`C_TooltipInfo.GetItemByID` returns **raw template strings**, not the rendered text WoW shows in-game. Two specific issues:

- **`|4singular:plural;` grammar escapes.** Strings like `"for 1 |4hour:hrs;"` are not pre-substituted. `TooltipCache.normalizeTooltipText` strips them before the regex pass. Don't bypass `normalizeTooltipText`.
- **Non-breaking spaces (U+00A0) between numbers and units.** Tooltip lines like `"Restores 241,303 health"` use NBSP in the position you'd expect a regular space. Lua's `%s` pattern class does NOT match NBSP. Normalize first; the parser does this for you.
- **Combined "health and mana" on one line → item is both Food AND Drink.** Some food/drink restores both on a single line. Two phrasings exist and each needs its own combined pattern, because only the *first* restore clause is prefixed with "Restores" — the second is introduced by "and":
  - Flat: `"Restores 35,000 health and 30,000 mana over 20 sec"` (Chalcocite Lava Cake, 227326). `healFlat` catches the health side, but the mana side needs `manaCombinedFlat` (`"health and ([%d,]+) mana"`) — the plain `manaFlat` pattern is `"Restores"`-anchored and misses it.
  - Percentage: `"Restores X% of your maximum health and mana"` — handled by `pctCombined`, which sets both `healPct` and `manaPct`.

  Miss either and the item populates only `healValue`/`healPct`, so `Classifier` matches `FOOD` but not `DRINK` and it silently drops out of the Drink list. Both combined patterns live in the `PATTERNS` table at the top of `core/TooltipCache.lua`; this is the same dual-classification behavior as Refreshing Serum (`HP_POT`+`MP_POT`) above.

If a new tooltip line refuses to match a pattern that "obviously should work", run `/cm dump item <id>` and inspect the raw lines for unexpected characters. The dump command prints the parsed fields plus the raw tooltip lines underneath — pattern-debugging view.

## `GET_ITEM_INFO_RECEIVED` does not fire for already-cached items

If an item's data is already in WoW's client-side cache when the addon starts (because another addon or the loot UI hydrated it earlier), `GET_ITEM_INFO_RECEIVED` does **not** fire for it on the addon's first scan. The discovery retry path (`OnItemInfoReceived` → `discoverOne`) only helps the not-yet-cached case.

That's why **FLASK is classified from its `subClassID` alone** (no tooltip gate) — the class is already available from `GetItemInfoInstant` without a tooltip fetch, so flasks looted before login still get discovered on the first bag scan. Don't regress this: routing FLASK back through tooltip-gated classification breaks first-login discovery for already-cached flasks.

## Combat lockdown taints protected APIs

`CreateMacro` / `EditMacro` / `DeleteMacro` are protected and may taint or fail if called during combat. Any path that could reach `EditMacro` must check `InCombatLockdown()` first.

The only sanctioned path is `MacroManager.SetMacro` / `SetCompositeMacro`. Every other module — Selector, Ranker, Classifier, BagScanner, TooltipCache, SpecHelper — must stay pure so the recompute pipeline can run in combat without taint risk. Combat-deferred writes queue in `pendingUpdates` and flush on `PLAYER_REGEN_ENABLED`. See [macro-manager.md](./macro-manager.md#combat-deferral).

## Secret values

WoW Midnight wraps certain combat-restricted returns in opaque "secret" values. Tainted (addon) code may hand one straight back to a client API that accepts it, but **comparing it or doing arithmetic on it is a hard error**. `KCM.Compat.IsSecret(value)` wraps the client's own `issecretvalue` test and reports `false` on a client that predates it, so a gate over client data can ask before it compares.

Two places in CM meet secret values, and they answer them differently.

### Cooldowns — the load-bearing case

`C_Spell.GetSpellCooldown` carries the `SecretWhenCooldownsRestricted` predicate, so from the moment combat (or an encounter / M+ / PvP match) begins, its `startTime`, `duration` and `modRate` come back secret. That broke two things at once in the macro bar: the old `duration > 0` gate errored on the comparison, and every raw-number `Cooldown` setter refuses a secret from a tainted caller, so `SetCooldown(start, duration)` couldn't stand in for it either.

The way through is the split Blizzard left open, and it's the same one LibActionButton-1.0 uses (so Bartender4 and ElvUI's bars behave identically):

- **`isEnabled` and `isActive` are documented NeverSecret**, so those two fields survive the restriction and are the only ones a tainted caller may branch on. `core/MacroDisplay.lua` decides *whether* a cooldown is running from those alone.
- **`C_Spell.GetSpellCooldownDuration` returns an opaque duration object** that carries the secret internally. `Cooldown:SetCooldownFromDurationObject` accepts it from a tainted caller, which makes it the only way to paint a restricted cooldown.

So `MacroDisplay.CooldownForID` returns `active, durationObject, start, duration` — a boolean that's always safe to test, an object that's always safe to hand over, and the raw pair only when the client says it's plain. `MacroBarButton.ApplyCooldown` (shared with the flyout's entries) prefers the object setter and falls back to the raw pair for a client with no duration objects, where nothing is secret anyway.

Items are **not** cooldown-restricted — `C_Item.GetItemCooldown` declares no secret predicate — so their plain triple stays readable. It gets wrapped in a duration object regardless, so the frame layer has exactly one path.

Don't reintroduce a numeric comparison or a raw `SetCooldown` on the spell path; both are silent out of combat and error the moment a fight starts. `tests/wow_mock.lua` models this (`mock.setCooldownsRestricted`, `mock.secret`, `mock.makeDuration`) so the regression is caught headlessly, and [smoke-tests.md](./smoke-tests.md) COMBAT-10 covers it in-game.

### Chat and debug output

The output path is hardened separately: `KCM.SafeToString` detects a secret by probing `table.concat` (the operation that actually raises on one — `tostring` and `..` silently propagate secretness), substituting `"<secret>"`. Both the `KCM.Say` chat seam and the `KCM.Debug` sink build every line through it, so a secret reaching an output line logs as `<secret>` instead of freezing a repeating timer mid-combat.

For a future field where neither a NeverSecret companion nor a duration object exists, the comparison has to happen C-side — `Frame:SetAlphaFromBoolean` / `C_CurveUtil.EvaluateColorValueFromBoolean` — never in Lua.

## Stored macro icon vs `#showtooltip`

WoW (and action-bar addons that render via `GetActionTexture` — ElvUI, Bartender) only let `#showtooltip` drive the action-bar button's icon when the macro's stored icon is the `?` sentinel (fileID `134400`, exposed as `DYNAMIC_ICON` in `modules/MacroManager.lua`). Any other stored icon overrides `#showtooltip` on the bar.

Consequence: active macro bodies must store `DYNAMIC_ICON`; empty-state bodies must drop `#showtooltip` entirely and store `DEFAULT_ICON` (`7704166`, the cooking pot, on Retail; `134328` on Forever, `KCM.EMPTY_ICON`). Storing `DEFAULT_ICON` on an active body shows the cooking pot on the bar instead of the picked item's icon.

The Options panel's `KCMMacroDragIcon` widget is exempt — it resolves to `GetItemIcon(lastItemID)` / `C_Spell.GetSpellTexture(spellID)` directly, since the `?` sentinel looks meaningless on a static UI widget.

See [macro-manager.md](./macro-manager.md#action-bar-icon-convention) for the full convention.

## `Settings.OpenToCategory` wants the numeric category ID, not a frame

`Settings.RegisterCanvasLayoutCategory` (parent) and `Settings.RegisterCanvasLayoutSubcategory` (sub-pages) both return a category object whose `:GetID()` is the numeric ID `Settings.OpenToCategory` accepts. Passing the frame produces a range error. `LibKa0s-Options-1.0` captures the ID at registration time (`registerMain` in `libs/LibKa0s/Options.lua`), and `/cm config` reaches it through `KCM.Options.Open` → `UI.OpenOptionsPanel`, which lands on the About splash:

```lua
mainCategory   = Settings.RegisterCanvasLayoutCategory(mainCtx.panel, d.parentTitle)
Settings.RegisterAddOnCategory(mainCategory)
mainCategoryID = mainCategory:GetID()
```

## Forcing a parent category to render expanded in the AddOns sidebar

`SettingsCategoryMixin` does NOT expose a `SetExpanded` method — that lives on the visual list-entry element. To force the parent's sub-pages to render unfolded by default, reach into `SettingsPanel:GetCategoryList():GetCategoryEntry(category):SetExpanded(true)`. The walk is `LibKa0s-Options-1.0`'s (a private `expandMainCategory` beside `OpenOptionsPanel`); this addon carried its own copy until it adopted `OpenOptionsPanel`. The whole walk is wrapped in `pcall` because every step (`SettingsPanel`, `GetCategoryList`, `GetCategoryEntry`) is private Blizzard API and could shift between patches; if any call goes missing the panel still opens, just without the parent unfolded.

```lua
local function expandMainCategory()
    if not (mainCategory and SettingsPanel) then return end
    pcall(function()
        local list = SettingsPanel.GetCategoryList
            and SettingsPanel:GetCategoryList()
            or SettingsPanel.CategoryList
        if not (list and list.GetCategoryEntry) then return end
        local entry = list:GetCategoryEntry(mainCategory)
        if entry and entry.SetExpanded then
            entry:SetExpanded(true)
        end
    end)
end
```

Call it AFTER `Settings.OpenToCategory` so `SettingsPanel` is realized and the entry element exists. Re-running on every `OpenOptionsPanel` means a manual mid-session collapse doesn't stick across the next `/cm config`.

The Settings panel is protected during combat (`InCombatLockdown()` blocks `Settings.OpenToCategory`). Two guards cover both entry points: `OpenOptionsPanel`, which `KCM.Options.Open` calls, refuses with the library's chat notice (covers `/cm` and `/cm config`), and `Helpers.SetRenderer`'s panel `OnShow` callback closes `SettingsPanel` and prints the same notice when a panel is shown during combat (covers a direct ESC → AddOns sidebar click that bypasses `O.Open`).

## `LEARNED_SPELL_IN_TAB` removed in retail

Blizzard removed `LEARNED_SPELL_IN_TAB` from retail; AceEvent throws `Attempt to register unknown event` when registering it. The addon uses its modern replacement `LEARNED_SPELL_IN_SKILL_LINE` so newly-learned spell entries (e.g. Recuperate on level-up) hydrate their macro body without a reload.

If a future patch removes another event the addon listens for, AceEvent still throws on registration, but the throw no longer escapes. Every registration goes through `KCM.SafeRegisterEvent` (`LibKa0s-Core-1.0`, bound in `core/CoreSetup.lua`), which asks `C_EventUtils.IsEventValid` first (a private probe frame on a client without it), then `pcall`s the call, and appends a refused name once to `KCM.RejectedEvents` (events-frames-taint-§1). So one retired name costs only its own handler, and every other event in `KCM.EVENTS` stays bound. Before, a bare `self:RegisterEvent` raised out of `KCM:OnEnable` at that name and every event after it went unregistered.

**The trade.** A retired name is now recorded and skipped rather than raised, so it no longer shows up as a Lua error on login. It shows up in two places instead: `/cm dump events` marks it `rejected`, and the `[Init]` line of a `/cm debug on` session ends `, rejected events: <NAME>`. The fix is unchanged: replace the name with whatever modern event covers the same trigger. The degraded Core stub (no LibKa0s) keeps only the `pcall` rung, so on that path AceEvent reports an unknown name to its first registrant only.

## Interface line — track both clients' builds

`ConsumableMaster.toc` declares two build numbers, Retail's first and WoW Forever's second (toc-file-§3):

```
## Interface: 120105, 16001
```

Each value is `(major * 10000) + (minor * 100) + patch` for that client's Live patch: Retail Midnight 12.1.5 and Forever 1.60.1. Each client picks the number that matches it. **When either client ships a patch, replace that client's number** (`/dev-copilot:wow-bump-interface` bumps them per client) so the addon reads as up to date in that client's AddOn list, and move the README `[WoW]` badge in the same change.

## WoW Forever's consumable subclasses

`Enum.ItemConsumableSubclass` keeps Retail's numbers on Forever (Potion 1, Elixir 2, Flask 3, Scroll 4, Food & Drink 5, Item Enhancement 6, Bandage 7, Other 8) and adds **Draught 13, Device 14 and ItemenhancementTemporary 15** (Ketho/BlizzardInterfaceResources `forever` 1.60.1 (70532), `Resources/LuaEnum.lua`). `core/Classifier.lua` reads them through two per-client lists picked once at load: on Forever a Draught matches like a Potion, and a temporary Item Enhancement (15) is a weapon enchant on its subclass alone (Forever reports 6 as "Permanent": the Light Armor Kit, 2304, in the owner's dump of 2026-11-08, so 6 never is), because vanilla's wording ("Increase sharp weapon damage by 2 for 30 minutes") has no "your … weapon" for the tooltip flag. A Device joins nothing. On Retail both lists are what the Classifier matched before the port.

Vanilla tooltips also phrase effects their own way, and `core/TooltipCache.lua` reads four of them into fields only the Forever paths use: a bandage's "Heals N damage over X sec." (a flat heal), a protection potion's "Absorbs X to Y fire damage." (`absorbValue`, `absorbSchool`), an "Increases armor by N" value (`effectValue`) and the weapon words "sharp" / "blunt" (`weaponWordAffinity`). Stamina, Spirit, armor and spell damage are not stat tokens, so an item granting only those ranks by its value, not by the stat priority. Which items carry which subclass on Forever is unconfirmed in game; the owner's `/cm dump bags` settles it.
