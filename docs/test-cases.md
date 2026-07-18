# Test Cases

The full inventory of every headless test case, grouped by suite. This file is the
**authoritative pass count** for the addon.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`
whenever the suite changes.

### test_bagscanner.lua (5)

- BagScanner.Scan is empty when bags are empty
- BagScanner.Scan aggregates distinct items to itemID -> count
- BagScanner.Scan sums separate stacks of the same item
- BagScanner.HasItem reports ownership and count
- BagScanner.HasItem is false for a nil id

### test_bus.lua (3)

- bus, NewBusTarget, and message catalogue are published
- a target hears a message, then goes silent after unregister
- RECOMPUTE routes to Pipeline.RequestRecompute

### test_categories.lua (2)

- Categories: VANTUS and WPN_ENCH registered with correct metadata and DB buckets
- Categories: AUG_RUNE registered with metadata, DB bucket, and seed

### test_classifier.lua (15)

- classifier: FOOD matches Food & Drink with heal and no stat buff
- classifier: DRINK matches Food & Drink with mana and no stat buff
- classifier: STAT_FOOD matches stat-buff food and excludes feast
- classifier: HP_POT matches healing potions without a stat buff
- classifier: MP_POT matches mana potions without a stat buff
- classifier: HS matches hard-coded healthstone IDs regardless of item data
- classifier: CMBT_POT matches buff potions with 1..60s duration and no heal/mana
- classifier: FLASK matches on subtype alone
- classifier: MatchAny never yields composite categories
- classifier: unrecognized subtype with empty tt matches nothing
- classifier: WPN_ENCH matches weapon enhancements by the isWeaponEnhance flag
- classifier: VANTUS matches whitelisted rune IDs regardless of item data
- classifier: guard and edge cases for nil/unknown inputs
- classifier: AUG_RUNE matches any augment-rune tooltip; reusable helper
- classifier: keys on numeric subclass, not the localized subType

### test_compat.lua (5)

- Compat.GetSpecialization returns the live spec index
- Compat.GetSpecializationInfo maps an index to specID + name
- Compat.GetNumSpecializationsForClassID delegates to the client
- Compat.GetSpecializationInfoForClassID maps (class,index) to a spec
- Compat.GetSpellName resolves known spells and nil otherwise

### test_database.lua (4)

- Database.CURRENT_SCHEMA is the version the code understands
- Database.RunMigrations stamps a fresh account at the current schema
- Database.RunMigrations is idempotent across repeated logins
- Database.RunMigrations is a safe no-op when the DB has no global scope

### test_debuglog.lua (9)

- DebugLog: FormatPlain renders the plain line shape with no colour codes
- DebugLog: FormatColored colours timestamp/tag and handles nil tag/msg
- DebugLog: SetEnabled/IsEnabled drive State.debug
- DebugLog: Toggle flips State.debug both directions
- DebugLog: SafeToString stringifies safely and catches concat-hostile values
- DebugLog: Debug sink is gated and routes tag/msg through AddLine
- DebugLog: Pipeline.CalcSummary formats reason + rewrite/skip tally
- DebugLog: enable emits [Debug]+[Init] brackets and coloured ON/OFF acks
- DebugLog: Show/Hide toggle the window without touching the enabled flag

### test_id.lua (6)

- ID.AsSpell negates the spellID into a sentinel
- ID.IsSpell is true for negatives, false otherwise
- ID.IsItem is true for positives, false for negatives
- ID.SpellID recovers magnitude for spells, nil for items
- ID.ItemID passes through items, nil for spells
- ID.AsSpell/SpellID round-trips

### test_load.lua (1)

- full addon loads in TOC order and publishes core handles

### test_macromanager.lua (11)

- MacroManager: BuildBody emits #showtooltip + /use item for an owned item pick
- MacroManager: BuildBody emits #showtooltip + /cast <Name> for a spell pick
- MacroManager: BuildBody with nil item falls back to category emptyText
- MacroManager: BuildCompositeBody HP_AIO happy path joins in- and out-of-combat picks
- MacroManager: BuildCompositeBody drops a disabled sub-category from the in-combat sequence
- MacroManager: BuildCompositeBody returns nil for no usable picks or invalid inputs
- MacroManager: BuildCompositeBody with only in-combat picks adds the out-of-combat /run fallback
- MacroManager: BuildCompositeBody with only out-of-combat pick adds the in-combat /run fallback
- MacroManager: BuildCompositeBody uses a spell pick's localized name in the /castsequence
- MacroManager: buildWeaponEnchantBody emits per-slot lines for MH+OH / one / neither
- MacroManager: BuildBody VANTUS uses the default single /use body

### test_pipeline.lua (6)

- Pipeline.RequestRecompute coalesces a burst into a single run
- Pipeline.RunAutoDiscovery adds a classifiable bag item to its category
- Pipeline.RunAutoDiscovery keeps a user-blocked item out of candidates
- Pipeline.Recompute writes a macro body pointing at the owned pick
- Pipeline.Recompute skips macro writes when the addon is disabled
- Pipeline.RecomputeOne routes a perHand category through SetWeaponEnchantMacro

### test_ranker.lua (18)

- Ranker: spell sentinel scores SPELL_SCORE for any category
- Ranker: nil/unknown guards score 0
- Ranker: FOOD conjured bonus beats higher flat-value non-conjured
- Ranker: FOOD healPct dominates and healValue+healValueAvg are additive
- Ranker: DRINK conjured bonus beats higher flat-value non-conjured
- Ranker: immediate HP pot outranks similar-amount HOT pot
- Ranker: HOT HP pot earns immediate bonus only past the 20% threshold
- Ranker: immediate MP pot outranks similar-amount HOT pot
- Ranker: HS preference table prefers modern stone and sorts it first
- Ranker: _statWeight ranks stats by spec priority
- Ranker: FLASK stat-aware primary buff outweighs equal-amount secondary
- Ranker: WPN_ENCH stat-aware primary buff outweighs equal-amount secondary
- Ranker: VANTUS prefers higher ilvl (current tier) then quality
- Ranker: SortCandidates orders by score desc, ties by id asc
- Ranker: spell sentinel sorts first and empty input is safe
- Ranker: AP weights as primary for STR/AGI specs, 0 for INT; SP mirrors
- Ranker: AUG_RUNE ranks by amount, reusable breaks ties, amount dominates
- Ranker: PRIMARY token does not change FLASK score (statWeight stays 0)

### test_runner_list.lua (4)

- formatInventory groups cases by suite file with counts
- formatInventory emits a Totals table summing all cases
- --list prints the inventory and runs no tests
- --list exits 0 without running the suite

### test_schema.lua (8)

- schema: Settings.Helpers and Settings.Schema tables exist
- schema: ValidateSchema reports zero errors and at least one row
- schema: 'enabled' row exists and is a bool
- schema: every row is findable by path and has a valid type
- schema: Get('enabled') mirrors db.profile.enabled
- schema: Set round-trips a bool setting through Helpers
- schema: unknown paths resolve to nil/false
- schema: [Set] logs exactly one line at the write seam, gated by debug

### test_selector.lua (11)

- Selector: BuildCandidateSet is seed-first; unknown category is empty
- Selector: AddItem adds to the set and is idempotent
- Selector: Block removes from set, is idempotent, and AddItem unblocks
- Selector: MarkDiscovered promotes once; blocked items are never discovered
- Selector: PickBestForCategory returns the one owned item, nil when nothing owned
- Selector: a known spell entry counts as owned and is picked
- Selector: MoveUp/MoveDown reorder via pins; moving past an edge is a no-op
- Selector: spec-aware FLASK category routes GetBucket/AddItem into the bySpec sub-table
- Selector: PickBestForSlot filters by weapon affinity + ownership
- Selector: PickBestForSlot excludes an affinity-eligible item that isn't owned
- Selector: PickBestForSlot on a blunt weapon excludes the bladed whetstone

### test_slash.lua (11)

- /cm set toggles a bool setting through the schema
- /cm priority add then remove edits the FOOD candidate set
- /cm priority add accepts a spell sentinel (s:ID)
- /cm stat primary sets the current spec's primary stat
- /cm stat primary resolves a CLASS:SPEC token
- /cm version prints the canonical v<version> line, not 'version <v>'
- /cm list colours the header, page group, and key=value rows (no trailing colon)
- /cm get echoes the same coloured key=value form as list
- /cm with an unknown command reports it and prints help
- /cm dump pick renders a category's effective priority and marks owned picks
- /cm rewrite is a back-compat alias for rewritemacros

### test_spechelper.lua (7)

- SpecHelper.MakeKey joins classID_specID, nil on missing parts
- SpecHelper.GetCurrent reads the live spec and re-reads on respec
- SpecHelper.GetCurrent returns classID-only when no spec is chosen
- SpecHelper.GetStatPriority honours a user override
- SpecHelper.GetStatPriority falls back to class primary, never nil
- SpecHelper.GetStatPriority returns a well-formed seed default for a real spec
- SpecHelper.AllSpecs enumerates specs including the current one

### test_tooltipcache.lua (12)

- TooltipCache: parses combined flat 'health and mana' into both values
- TooltipCache: parses health-only food with no manaValue
- TooltipCache: parses mana-only drink with no healValue
- TooltipCache: flags weapon enhancements via the 'your <weapon>' effect
- TooltipCache: parses combined percentage 'health and mana' form
- TooltipCache: parses Attack Power and Spell Power as AP/SP stats
- TooltipCache: weaponAffinity from bladed/blunt/plain phrasing
- TooltipCache: parses 'Primary Stat' as a PRIMARY stat buff
- TooltipCache: sets isAugmentRune from the category marker line
- TooltipCache: isAugmentRune fires on an inline 'Augment Rune' marker
- TooltipCache: partial consumable tooltip stays pending until body loads
- TooltipCache: effectless NON-consumable is cached, not pending

### test_weaponslots.lua (2)

- WeaponSlots: maps equipped weapon subtype to bladed/blunt/nil
- WeaponSlots: keys on weapon subClassID, not the localized subType

## Totals

| Suite | Cases |
|-------|------:|
| test_bagscanner.lua | 5 |
| test_bus.lua | 3 |
| test_categories.lua | 2 |
| test_classifier.lua | 15 |
| test_compat.lua | 5 |
| test_database.lua | 4 |
| test_debuglog.lua | 9 |
| test_id.lua | 6 |
| test_load.lua | 1 |
| test_macromanager.lua | 11 |
| test_pipeline.lua | 6 |
| test_ranker.lua | 18 |
| test_runner_list.lua | 4 |
| test_schema.lua | 8 |
| test_selector.lua | 11 |
| test_slash.lua | 11 |
| test_spechelper.lua | 7 |
| test_tooltipcache.lua | 12 |
| test_weaponslots.lua | 2 |
| **Total** | **140** |
