# Midnight quirks — tooltip parsing, subtype renames, secret values

Catalog of WoW Midnight (Interface 12.0.x) behaviors that bite the addon. When something breaks at patch time, this is where to look first.

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

Don't reintroduce a numeric comparison or a raw `SetCooldown` on the spell path; both are silent out of combat and error the moment a fight starts. `tests/wow_mock.lua` models this (`mock.setCooldownsRestricted`, `mock.secret`, `mock.makeDuration`) so the regression is caught headlessly, and [smoke-tests.md](./smoke-tests.md) step 7a covers it in-game.

### Chat and debug output

The output path is hardened separately: `KCM.SafeToString` detects a secret by probing `table.concat` (the operation that actually raises on one — `tostring` and `..` silently propagate secretness), substituting `"<secret>"`. Both the `KCM.Say` chat seam and the `KCM.Debug` sink build every line through it, so a secret reaching an output line logs as `<secret>` instead of freezing a repeating timer mid-combat.

For a future field where neither a NeverSecret companion nor a duration object exists, the comparison has to happen C-side — `Frame:SetAlphaFromBoolean` / `C_CurveUtil.EvaluateColorValueFromBoolean` — never in Lua.

## Stored macro icon vs `#showtooltip`

WoW (and action-bar addons that render via `GetActionTexture` — ElvUI, Bartender) only let `#showtooltip` drive the action-bar button's icon when the macro's stored icon is the `?` sentinel (fileID `134400`, exposed as `DYNAMIC_ICON` in `modules/MacroManager.lua`). Any other stored icon overrides `#showtooltip` on the bar.

Consequence: active macro bodies must store `DYNAMIC_ICON`; empty-state bodies must drop `#showtooltip` entirely and store `DEFAULT_ICON = 7704166` (cooking pot). Storing `DEFAULT_ICON` on an active body shows the cooking pot on the bar instead of the picked item's icon.

The Options panel's `KCMMacroDragIcon` widget is exempt — it resolves to `GetItemIcon(lastItemID)` / `C_Spell.GetSpellTexture(spellID)` directly, since the `?` sentinel looks meaningless on a static UI widget.

See [macro-manager.md](./macro-manager.md#action-bar-icon-convention) for the full convention.

## `Settings.OpenToCategory` wants the numeric category ID, not a frame

`Settings.RegisterCanvasLayoutCategory` (parent) and `Settings.RegisterCanvasLayoutSubcategory` (sub-pages) both return a category object whose `:GetID()` is the numeric ID `Settings.OpenToCategory` accepts. Passing the frame produces a range error. Capture the ID at registration time:

```lua
local main = Settings.RegisterCanvasLayoutCategory(panel, PANEL_TITLE)
KCM._settingsCategoryID = main:GetID()
```

`/cm config` (in `settings/Slash.lua`'s `COMMANDS` table) uses the parent's ID stored in `KCM._settingsCategoryID` to land on the About splash.

## Forcing a parent category to render expanded in the AddOns sidebar

`SettingsCategoryMixin` does NOT expose a `SetExpanded` method — that lives on the visual list-entry element. To force the parent's sub-pages to render unfolded by default, reach into `SettingsPanel:GetCategoryList():GetCategoryEntry(category):SetExpanded(true)`. The whole walk is wrapped in `pcall` because every step (`SettingsPanel`, `GetCategoryList`, `GetCategoryEntry`) is private Blizzard API and could shift between patches; if any call goes missing the panel still opens, just without the parent unfolded.

```lua
local function expandMainCategory()
    local main = KCM.Settings.main
    if not (main and SettingsPanel) then return end
    pcall(function()
        local list = SettingsPanel.GetCategoryList
            and SettingsPanel:GetCategoryList()
            or SettingsPanel.CategoryList
        if not (list and list.GetCategoryEntry) then return end
        local entry = list:GetCategoryEntry(main)
        if entry and entry.SetExpanded then
            entry:SetExpanded(true)
        end
    end)
end
```

Call it AFTER `Settings.OpenToCategory` so `SettingsPanel` is realized and the entry element exists. Re-running on every `KCM.Options.Open` means a manual mid-session collapse doesn't stick across the next `/cm config`.

The Settings panel is protected during combat (`InCombatLockdown()` blocks `Settings.OpenToCategory`). Two guards cover both entry points: `KCM.Options.Open` early-returns with a chat notice (covers `/cm` and `/cm config`), and `Helpers.SetRenderer`'s panel `OnShow` callback closes `SettingsPanel` and prints the same notice when a panel is shown during combat (covers a direct ESC → AddOns sidebar click that bypasses `O.Open`).

## `LEARNED_SPELL_IN_TAB` removed in retail

Blizzard removed `LEARNED_SPELL_IN_TAB` from retail; AceEvent throws `Attempt to register unknown event` when registering it. The addon uses its modern replacement `LEARNED_SPELL_IN_SKILL_LINE` so newly-learned spell entries (e.g. Recuperate on level-up) hydrate their macro body without a reload.

If a future patch removes another event the addon listens for, the failure mode is the same: AceEvent throws on registration. Replace with whatever modern event covers the same trigger.
