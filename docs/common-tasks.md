# Common tasks

Recipes for the routine modifications. For deeper context on any module, see [module-map.md](./module-map.md) and the per-topic docs.

## Add a new single-pick category

1. Append a row to `KCM.Categories.LIST` in `defaults/Categories.lua`:
   ```lua
   { key="NEW", macroName="KCM_NEW", displayName="New Thing",
     specAware=false, rankerKey="new", classifier="new",
     emptyText="/run print('|cff00ffff[CM]|r no new thing in bags')" },
   ```
   Set `specAware=true` if the category needs per-spec buckets.
2. Add a matcher in `core/Classifier.lua`'s `matchers` table — predicate against the consumable `sub` (subClassID) + parsed tooltip.
3. Add a scorer in `modules/Ranker.lua`'s `scorers` table — return a numeric score; higher wins.
4. Add a branch in `Ranker.Explain` for the score-button tooltip — produces `{ {label, value, note?}, ... }` rows that mirror the scorer's additive terms.
5. Create `defaults/Defaults_New.lua`:
   ```lua
   local _, NS = ...
   local KCM = NS
   KCM.SEED = KCM.SEED or {}
   KCM.SEED.NEW = { itemID1, itemID2, ... }
   ```
6. Add the file to `ConsumableMaster.toc` in the `# Defaults` section (after `Categories.lua`, before the `# Modules` section).
7. Update `dbDefaults.profile.categories` in `defaults/Profile.lua` so AceDB creates the bucket:
   ```lua
   NEW = { added = {}, blocked = {}, pins = {}, discovered = {} },   -- non-spec
   NEW = { bySpec = {} },                                              -- spec-aware
   ```
8. Options panel picks the category up automatically from `Categories.LIST` — its tab on the **Macros** page is generated, not written.
9. Add the lower-cased key to `KCM.Settings.macroOrder` (`settings/Panel.lua`) at the position you want its tab, then append the UPPER-cased key to `dbDefaults.profile.macroBar.order` in the same position — the macro bar's default slot order mirrors the tab order, and `tests/test_macrobar.lua` fails if the two drift. (An existing profile self-heals: `MacroBarModel.NormalizeOrder` appends any category its saved order has never seen.) `KCM.Settings.order` and `_validPanels` are the four PAGES and do not change: a category is a tab now, not a page.
10. Add the tab to the expected run in `tests/test_schema.lua` → "the Macros strip is the designed run of tabs, in order". It is written out longhand on purpose — derived from `Categories.LIST` it would agree with `Categories.LIST` whatever that said.

## Add a new composite category

Composites compose other categories' picks via `[combat]` / `[nocombat]` macro conditionals — they don't pick from their own bag set.

1. Append a row to `KCM.Categories.LIST` with `composite=true`:
   ```lua
   { key="NEW_AIO", macroName="KCM_NEW_AIO", displayName="AIO New",
     composite=true,
     components={ inCombat={"REF1","REF2"}, outOfCombat={"REF3"} },
     emptyText="/run print('|cff00ffff[CM]|r no AIO new option available')" },
   ```
   `inCombat` / `outOfCombat` ref keys must be existing single-category keys (e.g. `"HS"`, `"HP_POT"`, `"FOOD"`).
2. Add a bucket to `dbDefaults.profile.categories` in `defaults/Profile.lua`:
   ```lua
   NEW_AIO = {
       enabled          = { REF1=true, REF2=true, REF3=true },
       orderInCombat    = { "REF1", "REF2" },
       orderOutOfCombat = { "REF3" },
   },
   ```
3. **No** Classifier, Ranker, or `Defaults_*` file. **No** `added` / `blocked` / `pins` / `discovered` buckets — composites have no candidate set.
4. The pipeline already branches on `cat.composite` in `Pipeline.RecomputeOne` and dispatches to `MacroManager.SetCompositeMacro`. The Options panel routes `cat.composite` rows to `renderComposite` in `settings/Category.lua`. No code changes needed.

See [schema.md](./schema.md#composite-bucket-shape) for the composite bucket shape and [macro-manager.md](./macro-manager.md#composite-body-assembly) for the body-assembly detail.

## Refresh seed item IDs after a patch

The full procedure (sources, in-game `/run` snippet for batch ID dump, common pitfalls) lives in [defaults/README.md](../defaults/README.md). High-level summary: collect candidate IDs (in-game vendors first, then Method.gg / wiki cross-check), verify each in-game with `/cm dump item <id>`, update the relevant `defaults/Defaults_*.lua` file, then run the [auto-discovery section](./smoke-tests.md#2-auto-discovery) of the smoke suite.

Updating a defaults file is a zero-migration upgrade for existing users — the candidate set is `(seed ∪ added ∪ discovered) − blocked` at runtime, and the right-side sets live in SavedVariables independent of the seed.

## Fix a misclassification

1. Run `/cm dump item <id>` to see the live `classID`/`subClassID` (`instant:` line) + parsed tooltip.
2. **Wrong class?** Classification keys on the numeric `classID`/`subClassID` (Consumable=0; Potion=1, Flask/Phial=3, Food & Drink=5) — locale-independent, and unchanged across Blizzard's display-string renames, so a subtype rename needs no code change. Only a genuinely new consumable subclass would need a `core/Classifier.lua` edit (add its subclass constant + matcher).
3. **Tooltip parse missing a field?** Check `PATTERNS` in `core/TooltipCache.lua`. Watch for non-breaking spaces (U+00A0 — Lua `%s` does not match) and `|4singular:plural;` grammar escapes. Both are normalized in `normalizeTooltipText`; don't bypass it.
4. Re-run `/cm dump item <id>` to confirm the fix.
5. Run `/cm resync` to rebuild the candidate set, then `/cm dump pick <catKey>` to confirm the item now lands where expected.

For the Midnight-specific gotcha catalog see [midnight-quirks.md](./midnight-quirks.md).

## Verify a behavior change in-game

The pure layer is covered by a headless harness — run `lua5.1 tests/run.lua` (current suite inventory in [test-cases.md](./test-cases.md)) and `luacheck .` before committing. In-game behavior still needs manual validation: use the [Quick smoke](./smoke-tests.md#quick-smoke) recipe in [smoke-tests.md](./smoke-tests.md) for the post-change minimum, and the [targeted-by-change-area lookup](./smoke-tests.md#targeted-by-change-area) at the bottom of that file for which sections of the full suite map to your change.

If you can only reason about the change from code and cannot test it in WoW, say so explicitly — don't claim it works.
