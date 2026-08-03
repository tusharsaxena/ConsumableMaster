# Test Cases

The full inventory of every headless test case, grouped by suite. This file is the
**authoritative pass count** for the addon.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`
whenever the suite changes.

### test_bagscanner.lua (12)

- BagScanner.Scan is empty when bags are empty
- BagScanner.Scan aggregates distinct items to itemID -> count
- BagScanner.Scan sums separate stacks of the same item
- BagScanner.HasItem reports ownership and count
- BagScanner.HasItem is false for a nil id
- BagScanner.Scan treats a slot with no stackCount as a single item
- BagScanner.Scan skips empty slots without inventing entries
- BagScanner.Scan returns an empty table when the container API is absent
- BagScanner.Scan walks the reagent bag slot, not just the backpack
- BagScanner.HasItem answers from Blizzard's tally, not a full bag walk
- BagScanner.HasItem counts bank stacks in via the includeBank flag
- BagScanner.HasItem reports not-owned when the item count API is absent

### test_bus.lua (11)

- bus, NewBusTarget, and message catalog are published
- a target hears a message, then goes silent after unregister
- RECOMPUTE routes to Pipeline.RequestRecompute
- bus: every message name is namespaced and distinct
- bus: NewBusTarget hands out a fresh, independently-embedded table
- bus: one message fans out to every subscribed target
- bus: unregistering one target leaves the others subscribed
- bus: a message nobody subscribes to is a silent no-op
- bus: the pipeline subscribes on its own target, never on KCM.bus
- bus: RECOMPUTE with no reason still reaches the pipeline
- bus: RECOMPUTE is inert while the pipeline entry point is missing

### test_categories.lua (4)

- Categories: VANTUS and WPN_ENCH registered with correct metadata and DB buckets
- Categories: AUG_RUNE registered with metadata, DB bucket, and seed
- Categories: BLOODLUST and BATTLE_REZ registered with metadata, buckets and seeds
- Categories: the Bloodlust seed leads with spells and the class gate names Primal Rage

### test_classifier.lua (16)

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
- classifier: a recipe carrying its crafted item's tooltip never matches
- classifier: VANTUS matches whitelisted rune IDs regardless of item data
- classifier: guard and edge cases for nil/unknown inputs
- classifier: AUG_RUNE matches any augment-rune tooltip; reusable helper
- classifier: keys on numeric subclass, not the localized subType

### test_compat.lua (17)

- Compat.GetSpecialization returns the live spec index
- Compat.GetSpecializationInfo maps an index to specID + name
- Compat.GetNumSpecializationsForClassID delegates to the client
- Compat.GetSpecializationInfoForClassID maps (class,index) to a spec
- Compat.GetSpellName resolves known spells and nil otherwise
- Compat.IsSecret defers to the client's own issecretvalue
- Compat.IsSecret reports nothing secret on a pre-Midnight client
- Compat prefers C_SpecializationInfo over the legacy spec globals
- Compat falls back to the flat globals when the namespace is absent
- Compat.GetSpecializationInfo guards a nil index
- Compat.GetNumSpecializationsForClassID reports zero when no API answers
- Compat.GetSpecializationInfoForClassID returns nil for an unknown pair
- Compat.GetSpellName guards a nil spellID before touching the client
- Compat.GetSpellName treats an empty name as unresolved and keeps looking
- Compat.GetSpellName falls back to the C_Spell.GetSpellInfo shape
- Compat.GetSpellName falls back to the deprecated global last
- Compat.GetSpellName returns nil when nothing can resolve the id

### test_constants.lua (12)

- Constants: PREFIX is the cyan [CM] tag with no trailing space
- Constants: IsConcatSafe accepts strings and numbers
- Constants: IsConcatSafe rejects a value table.concat would raise on
- Constants: SafeToString renders nil as the literal 'nil'
- Constants: SafeToString passes booleans through, which concat itself rejects
- Constants: SafeToString passes strings and numbers through unchanged
- Constants: SafeToString substitutes <secret> for a concat-hostile value
- Constants: Say prints one prefixed line in the single-string form
- Constants: Say interpolates the format-string call form
- Constants: Say stringifies every format arg through the secret guard
- Constants: Say renders a nil format arg as 'nil' rather than dropping it
- Constants: Say guards the single-string form too

### test_coresetup.lua (8)

- CoreSetup: the addon's stringifier IS the library's, not a lookalike
- CoreSetup: the secret sentinel is the library's, so the docs cannot drift from it
- CoreSetup: the prefix is re-read on every line, not frozen at load
- CoreSetup: chat still lands in the global print, which is where the harness listens
- CoreSetup: with the library absent the addon still prints, and says why once
- CoreSetup: the degraded stringifier answers the same sentinel as the library
- CoreSetup: LibKa0s-Core-1.0 still has no user-visible strings to trap
- CoreSetup: the prefix is the only library-rendered fragment, and it is prose

### test_database.lua (14)

- Database.CURRENT_SCHEMA is the version the code understands
- Database.RunMigrations stamps a fresh account at the current schema
- Database.RunMigrations is idempotent across repeated logins
- Database.RunMigrations is a safe no-op when the DB has no global scope
- Database.RunMigrations seeds a missing schemaVersion instead of leaving it nil
- Database.RunMigrations upgrades an older stored version to current
- Database.RunMigrations leaves unrelated global keys untouched
- Database.RunMigrations never writes into the profile scope
- Database.RunMigrations is a safe no-op before the DB exists
- Database v2: a profile that predates the macro bar gets it on and unlocked
- Database v2: an off/locked bar from an earlier build of the feature is turned on
- Database v2: the step is one-shot — a later opt-out survives the next login
- Database v2: the migration leaves every other bar setting alone
- Database v2: MigrateMacroBarV2 tolerates a nil profile

### test_debug.lua (13)

- Debug: the sink is published and callable
- Debug: IsOn is false by default (State.debug is never persisted on)
- Debug: IsOn tracks State.debug when no console module has loaded
- Debug: IsOn defers to DebugLog.IsEnabled once the console owns the flag
- Debug: a call while gated off emits nothing
- Debug: a call while gated off never reaches the console either
- Debug: an enabled call is handed to the console instance's own sink
- Debug: with no console loaded an enabled call falls back to tagged chat
- Debug: a message with no format args is emitted verbatim
- Debug: every format arg goes through the secret guard
- Debug: a nil format arg renders as 'nil' rather than shifting later args
- Debug: the chat fallback stringifies a hostile tag safely
- Debug: the sink publishes no Toggle of its own

### test_debuglog.lua (15)

- DebugLog: FormatPlain renders the plain line shape with no color codes
- DebugLog: FormatColored colors timestamp/tag and handles nil tag/msg
- DebugLog: SetEnabled/IsEnabled drive State.debug
- DebugLog: Toggle flips State.debug both directions
- DebugLog: SafeToString stringifies safely and catches concat-hostile values
- DebugLog: the Debug sink is gated, and formats into the console buffer
- DebugLog: Pipeline.CalcSummary formats reason + rewrite/skip tally
- DebugLog: enable emits [Debug]+[Init] brackets and colored ON/OFF acks
- DebugLog: Show/Hide toggle the window without touching the enabled flag
- DebugLog: scrollbar + counter sync run headlessly without error
- DebugLog: the console IS the library's instance, not a host lookalike
- DebugLog: the descriptor reproduces the addon's window identity
- DebugLog: the console's own strings resolve to prose, not to their own keys
- DebugLog: the flag lives in KCM.State, not in the library
- DebugLog: with the library absent the console degrades and chat still answers

### test_defaults.lua (28)

- Categories: every row has a unique key and BY_KEY resolves it
- Categories: Get returns nil for a key that isn't registered
- Categories: every macro name is unique, KCM_-prefixed, and within 16 chars
- Categories: every row carries a display name and an empty-state body
- Categories: single-pick rows declare both a classifier and a ranker key
- Categories: composite rows carry components and no ranker/classifier hint
- Categories: every composite component names a real single-pick category
- Categories: only the Weapon Enchant row is per-hand, and it is spec-aware
- Defaults: every category has a profile bucket of the right shape
- Defaults: no profile bucket exists for a category that was removed
- Defaults: composite default order matches the category's declared components
- Defaults: every composite sub-category ships enabled
- Defaults: the addon ships enabled with an empty user-override state
- Defaults: every single-pick category ships a non-empty seed list
- Defaults: no seed list ships a duplicate entry
- Defaults: every seed entry is a non-zero integer ID
- Defaults: every seed entry classifies as either an item or a spell sentinel
- Defaults: no seed list is shared by reference between two categories
- Defaults: a seeded itemID is shared only across a health/mana sibling pair
- Defaults: the FOOD seed carries the conjured-food spell as a sentinel
- Defaults: the Healthstone seed is item-only
- Defaults: every reusable augment rune the Classifier knows is in the seed
- Defaults: a consumed augment rune is not flagged reusable
- Defaults: every stat-priority key is a well-formed classID_specID pair
- Defaults: stat priority covers all thirteen classes
- Defaults: every seeded spec names a primary stat the Ranker weights
- Defaults: every seeded secondary list is ordered, valid, and duplicate-free
- Defaults: a seeded spec resolves through SpecHelper without falling back

### test_events.lua (20)

- OnEnable registers every client event the addon reacts to
- OnEnable registers no event without a matching handler method
- PLAYER_ENTERING_WORLD discovers, sweeps, then recomputes in that order
- PLAYER_ENTERING_WORLD picks up a bag item that no seed ships
- BAG_UPDATE_DELAYED rediscovers and recomputes with the bag reason
- PLAYER_SPECIALIZATION_CHANGED recomputes and tells the panel to retrack
- LEARNED_SPELL_IN_SKILL_LINE recomputes so a late-known spell can be picked
- PLAYER_EQUIPMENT_CHANGED recomputes for a main-hand or off-hand swap
- PLAYER_EQUIPMENT_CHANGED ignores every non-weapon slot
- PLAYER_REGEN_ENABLED flushes the macro writes deferred during combat
- PLAYER_REGEN_ENABLED is safe before the macro layer has loaded
- GET_ITEM_INFO_RECEIVED ignores a failed or id-less delivery
- GET_ITEM_INFO_RECEIVED for a bag item invalidates its cached tooltip
- GET_ITEM_INFO_RECEIVED for a bag item discovers it and recomputes
- GET_ITEM_INFO_RECEIVED for a non-bag item refreshes the panel but never recomputes
- GET_ITEM_INFO_RECEIVED never discovers an item the player does not own
- RequestRecompute keeps the latest reason across a coalesced burst
- RequestRecompute falls back to a placeholder reason when given none
- RequestRecompute re-arms after its frame callback has fired
- RequestRecompute's frame callback is inert if the request was already served

### test_id.lua (8)

- ID.AsSpell negates the spellID into a sentinel
- ID.IsSpell is true for negatives, false otherwise
- ID.IsItem is true for positives, false for negatives
- ID.SpellID recovers magnitude for spells, nil for items
- ID.AsSpell/SpellID round-trips
- ID predicates reject non-numeric input rather than raising
- ID treats zero as neither an item nor a spell
- ID: item and spell ranges are disjoint for every real id

### test_libka0s.lua (8)

- LibKa0s: the harness load list matches libs/LibKa0s/LibKa0s.xml exactly
- LibKa0s: every vendored library file the loader names exists on disk
- LibKa0s: the TOC loads the library through its own packaged XML
- LibKa0s: every declared major registers, and reports the minor of every one of its files
- LibKa0s: no file registers under a major it does not belong to
- LibKa0s: each attach file is paired to the shell minor it actually attached to
- LibKa0s: library file basenames are unique across every vendored major
- LibKa0s: omitting the vendored files leaves every major absent, not half-wired

### test_load.lua (1)

- full addon loads in TOC order and publishes core handles

### test_macrobar.lua (94)

- macrobar layout: one row of 13 reports 13 columns and one row
- macrobar layout: first slot sits at the padding offset
- macrobar layout: slots step by size + spacing along the row
- macrobar layout: 13 slots at 7 per row wrap into two rows
- macrobar layout: growth LEFT mirrors the columns
- macrobar layout: growth UP mirrors the rows
- macrobar layout: VERTICAL orientation fills columns first
- macrobar layout: zero slots still reports a non-zero container
- macrobar layout: missing config falls back to shipped defaults
- macrobar layout: perRow below 1 is clamped rather than dividing by zero
- macrobar label: inside anchors the label's own corner to the button's
- macrobar label: outside flips the anchor across that edge
- macrobar label: offsets pass through and CENTER never flips
- macrobar label: an unknown position falls back to the shipped default
- macrobar label: every declared label position resolves to an anchor
- macrobar label: font size scales with the button and clamps to legible
- macrobar label: every category supplies both a full and a short label
- macrobar label: an unknown category degrades to its key
- macrobar flyout: entry 1 sits one gap off the button
- macrobar flyout: the gap is configurable and can be closed to zero
- macrobar flyout: entries step by size + spacing away from the button
- macrobar flyout: growing downward mirrors the offsets
- macrobar flyout: horizontal sides stack along x instead of y
- macrobar flyout: container is sized to the run of entries
- macrobar flyout: scale shrinks entries independently of the button
- macrobar flyout: an empty flyout still reports a usable frame size
- macrobar flyout: padding insets the strip inside its panel
- macrobar flyout: padding leaves entries centered on the cross axis
- macrobar flyout: the indicator band sits inside the icon's edge
- macrobar flyout: each side rotates the arrow to point away from the button
- macrobar flyout: arrow size scales off the band and never vanishes
- macrobar flyout: a side band swaps its span and thickness
- macrobar flyout: band thickness is a ratio of the button, capped at half
- macrobar flyout: every flyout side resolves geometry
- macrobar flyout: a label sharing the band's edge is pushed clear
- macrobar flyout: clearance follows the band to another edge
- macrobar flyout: a label on a different edge is left alone
- macrobar flyout: no clearance when the flyout is off or the label is outside
- macrobar flyout: clearance scales with the band thickness
- macrobar model: AllKeys covers every managed category
- macrobar model: NormalizeOrder leaves a complete order untouched
- macrobar model: NormalizeOrder drops unknown keys
- macrobar model: NormalizeOrder appends categories missing from a saved order
- macrobar model: NormalizeOrder de-duplicates a repeated key
- macrobar model: Swap exchanges two slots
- macrobar model: Swap refuses an absent or self-referential key
- macrobar model: VisibleKeys hides only slots explicitly set to false
- macrobar model: MacroName and KeyForMacroName round-trip
- macrobar model: the bar ships centered on screen at 36px buttons
- macrobar model: the GCD swipe is suppressed out of the box
- macrobar defaults: perRow tracks the number of managed categories
- macrobar schema: perRow's max slider value is derived from the category count
- macrobar model: the bar ships on and unlocked so it is discoverable
- macrobar model: the shipped default order needs no repair
- macrobar model: Order repairs and writes back a damaged saved order
- macrobar model: Visible reflects the shown map over the saved order
- macrodisplay: an unwritten macro falls back to the cooking-pot icon
- macrodisplay: an item pick resolves to the item's icon and count
- macrodisplay: a spell pick resolves to the spell icon and has no count
- macrodisplay: item and spell cooldowns both report active plus a span
- macrodisplay: an empty-state macro reports no pick, count or cooldown
- macrobar cooldowns: an active cooldown paints from the duration object
- macrobar cooldowns: an inactive cooldown clears the swipe
- macrobar cooldowns: a client without duration objects falls back to numbers
- macrobar cooldowns: restricted cooldowns are never compared or set as numbers
- macrobar cooldowns: a restricted spell still reports whether it is running
- macrobar cooldowns: showGCD false hides the swipe via the curve-evaluated duration
- macrobar cooldowns: showGCD true never suppresses and always shows the swipe
- macrobar cooldowns: no duration object skips suppression without erroring
- macrobar cooldowns: a missing C_CurveUtil degrades to full alpha without erroring
- macrobar cooldowns: the GCD-suppress curve is built once and reused
- macrobar schema: every macroBar row validates and resolves against the db
- macrobar schema: enum rows reject a value outside their list
- macrobar schema: number rows clamp to their declared range
- macrobar schema: the default slot order matches the settings tab order
- macrobar schema: border rows are populated from LibSharedMedia
- macrobar schema: LSMValues never hands back an empty list
- macrobar flyout: candidates come back in rank order, best first
- macrobar flyout: invert reverses the order without dropping anything
- macrobar flyout: the list is capped to flyoutMax, keeping the top ranks
- macrobar flyout: the cap is bounded by the pool ceiling, not just the setting
- macrobar flyout: it ships on, opening upward, closing after 3s
- macrobar flyout: auto-close is configurable and 0 means never
- macrobar flyout: Create wires the secure frames without erroring
- macrobar flyout: ApplyBackdrop paints the panel child, not the container
- macrobar flyout: leaving hands off to the countdown, and says so securely
- macrobar flyout: combat state is driven into the snippet, not polled
- macrobar flyout: the idle clock resets while the mouse is on the strip
- macrobar flyout: hovering the band alone also holds the flyout open
- macrobar flyout: the idle clock stands down in combat
- macrobar flyout: an auto-close of 0 never closes on idle
- macrobar flyout: Close hides the strip and stands down in combat
- macrobar flyout: Close tolerates a nil flyout
- macrobar schema: the bar publishes its own bus message

### test_macromanager.lua (37)

- MacroManager: BuildBody emits #showtooltip + /use item for an owned item pick
- MacroManager: BuildBody emits #showtooltip + /cast <Name> for a spell pick
- MacroManager: a targeted category's spell body carries the conditional
- MacroManager: a targeted category's item body carries the same conditional
- MacroManager: turning mouseover off drops the conditional
- MacroManager: an untargeted category is unaffected
- MacroManager: BuildBody with nil item falls back to category emptyText
- MacroManager: BuildCompositeBody HP_AIO happy path joins in- and out-of-combat picks
- MacroManager: BuildCompositeBody drops a disabled sub-category from the in-combat sequence
- MacroManager: BuildCompositeBody returns nil for no usable picks or invalid inputs
- MacroManager: BuildCompositeBody with only in-combat picks adds the out-of-combat /run fallback
- MacroManager: BuildCompositeBody with only out-of-combat pick adds the in-combat /run fallback
- MacroManager: BuildCompositeBody uses a spell pick's localized name in the /castsequence
- MacroManager: buildWeaponEnchantBody emits per-slot lines for MH+OH / one / neither
- MacroManager: BuildBody VANTUS uses the default single /use body
- MacroManager.SetMacro creates the macro on the first write
- MacroManager.SetMacro records the body and icon it wrote
- MacroManager.SetMacro reports 'unchanged' and makes no API call on a repeat
- MacroManager.SetMacro edits in place when the pick changes
- MacroManager.SetMacro falls back to the empty body when nothing is picked
- MacroManager.SetMacro resolves the category from the macro name if not told
- MacroManager.SetMacro rejects an empty macro name
- MacroManager.SetMacro refuses to write before the DB is ready
- MacroManager.SetMacro errors out when the account macro quota is full
- MacroManager.SetMacro surfaces a rejected edit as an error
- MacroManager.SetMacro defers instead of writing while in combat
- MacroManager.FlushPending applies a deferred write once combat ends
- MacroManager.FlushPending refuses to run while still in combat
- MacroManager.FlushPending gives up on a macro after three failed writes
- MacroManager.FlushPending re-queues a write if combat resumes mid-flush
- MacroManager.InvalidateState forces the next pass to rewrite every body
- MacroManager.InvalidateState drops queued combat writes
- MacroManager falls back to the empty body when a body exceeds 255 bytes
- MacroManager warns about an oversized body only once per category
- MacroManager.SetWeaponEnchantMacro writes the empty stub when neither hand has a pick
- MacroManager.SetWeaponEnchantMacro takes its icon from the main hand
- MacroManager.SetWeaponEnchantMacro guards a missing category or DB

### test_perfsetup.lua (10)

- Perf: the harness IS the library's instance, not a lookalike
- Perf: the panel half attached to the instance
- Perf: every panel step's label resolves to prose, not to its own key
- Perf: the descriptor answers the fields whose defaults are silently wrong
- Perf: the SavedVariables global the harness writes is actually declared
- Perf: /cm perf is a published verb and reaches the harness
- Perf: the capture flag is the library's alone, with no second home
- Perf: the instrumentation records nothing while no capture is running
- Perf: every Note call site sits in a file that gates on the capture flag
- Perf: with the library absent the feature is absent, and /cm perf says so

### test_pipeline.lua (22)

- Pipeline.RequestRecompute coalesces a burst into a single run
- Pipeline.RunAutoDiscovery adds a classifiable bag item to its category
- Pipeline.RunAutoDiscovery keeps a user-blocked item out of candidates
- Pipeline.Recompute writes a macro body pointing at the owned pick
- Pipeline.Recompute skips macro writes when the addon is disabled
- Pipeline.RecomputeOne routes a perHand category through SetWeaponEnchantMacro
- Pipeline.RecomputeOne ignores a category that does not exist
- Pipeline.RecomputeOne routes a composite category to the composite writer
- Pipeline.RecomputeOne asks for a pick per hand on a per-hand category
- Pipeline.Recompute writes one macro per registered category
- Pipeline.Recompute isolates a category whose write raises
- Pipeline.Recompute refreshes the panel even while the addon is disabled
- Pipeline.Recompute is a no-op before the category table has loaded
- Pipeline.CalcSummary renders the reason and the rewrite/skip tally
- Pipeline.RunAutoDiscovery leaves a seeded item out of the discovered set
- Pipeline.RunAutoDiscovery reports zero when nothing new is in bags
- ResetAllToDefaults wipes category customizations back to the shipped state
- ResetAllToDefaults clears stat-priority overrides and re-enables the addon
- ResetAllToDefaults preserves macro state so live macros are not orphaned
- ResetAllToDefaults rediscovers what is still in bags
- ResetAllToDefaults reports whether it mutated anything
- ResetAllToDefaults leaves the category buckets structurally valid

### test_ranker.lua (23)

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
- Ranker: BLOODLUST prefers a higher affect-cap, and an uncapped drum outranks every capped one
- Ranker: BLOODLUST's cap term is weighted above ilvl (a lower-ilvl higher-cap drum wins)
- Ranker: BLOODLUST Explain reports the actual cap and only notes 'no cap' when uncapped
- Ranker: BATTLE_REZ Explain reports ilvl and quality signals with the scorer's score
- Ranker: BATTLE_REZ ranks the lone seeded item by ilvl and quality
- Ranker: PRIMARY token does not change FLASK score (statWeight stays 0)

### test_runner_list.lua (4)

- formatInventory groups cases by suite file with counts
- formatInventory emits a Totals table summing all cases
- --list prints the inventory and runs no tests
- --list exits 0 without running the suite

### test_schema.lua (33)

- schema: Settings.Helpers and Settings.Schema tables exist
- schema: ValidateSchema reports zero errors and at least one row
- schema: 'enabled' row exists and is a bool
- schema: every row is findable by path and has a valid type
- schema: Get('enabled') mirrors db.profile.enabled
- schema: Set round-trips a bool setting through Helpers
- schema: unknown paths resolve to nil/false
- schema: [Set] logs exactly one line at the write seam, gated by debug
- schema: Resolve splits a dotted path into its parent table and key
- schema: Resolve walks nested tables
- schema: Resolve refuses a path that runs through a non-table
- schema: Resolve returns nothing for an empty path or a missing DB
- schema: Set can write a nested path, not just a top-level one
- schema: every row declares a panel that exists in the tab order
- schema: every row carries a label and a tooltip for the panel to render
- schema: every row's default matches the seeded profile value
- schema: ValidateSchema counts a row with a bad panel, section, and type
- schema: ValidateSchema flags a row with no path
- schema: ValidateSchemaValue enforces each declared type
- schema: ValidateSchemaValue clamps a number to its declared range
- schema: SetAndRefresh writes the value and fires the row's onChange
- schema: SetAndRefresh refuses a value of the wrong type
- schema: SetAndRefresh refuses a path that is not in the schema
- schema: the published Schema:Set is the same seam as SetAndRefresh
- schema: FormatSchemaValue renders nil as 'nil'
- schema: FormatSchemaValue renders a color as a four-component table
- schema: FormatSchemaValue renders booleans and strings readably
- schema: RefreshAllPanels flags an off-screen page dirty instead of rebuilding it
- schema: RefreshAllPanels rebuilds the page that is on screen
- schema: a render failure is reported instead of breaking the refresh loop
- schema: RefreshScalars re-syncs widgets in place without a rebuild
- schema: RefreshScalars flags a hidden page dirty rather than syncing it
- schema: the tab order lists each panel once and covers every category page

### test_selector.lua (44)

- Selector: BuildCandidateSet is seed-first; unknown category is empty
- Selector: AddItem adds to the set and is idempotent
- Selector: Block removes from set, is idempotent, and AddItem unblocks
- Selector: MarkDiscovered promotes once; blocked items are never discovered
- Selector: PickBestForCategory returns the one owned item, nil when nothing owned
- Selector: a known spell entry counts as owned and is picked
- Selector: a class-gated spell resolves for its class when IsPlayerSpell says no
- Selector: the class gate does not override a genuinely known spell
- Selector: MoveUp/MoveDown reorder via pins; moving past an edge is a no-op
- Selector: spec-aware FLASK category routes GetBucket/AddItem into the bySpec sub-table
- Selector: PickBestForSlot filters by weapon affinity + ownership
- Selector: PickBestForSlot excludes an affinity-eligible item that isn't owned
- Selector: PickBestForSlot on a blunt weapon excludes the bladed whetstone
- Selector: PickBestForSlot skips a level-blocked enhancement
- Selector.MarkDiscovered reports 'new' only on the first sighting
- Selector.MarkDiscovered bumps the stored timestamp on a re-sighting
- Selector.MarkDiscovered does not rewind a timestamp for an out-of-order scan
- Selector.MarkDiscovered upgrades a legacy boolean entry to a timestamp
- Selector.MarkDiscovered refuses spell sentinels and unknown categories
- Selector.SweepStaleDiscovered drops an entry past the 30-day TTL
- Selector.SweepStaleDiscovered keeps an entry that is still inside the TTL
- Selector.SweepStaleDiscovered refreshes an item that is still in bags
- Selector.SweepStaleDiscovered treats a legacy boolean entry as ancient
- Selector.SweepStaleDiscovered evicts a discovered non-consumable still in bags
- Selector.SweepStaleDiscovered keeps a discovered item whose class is unresolvable
- Selector.SweepStaleDiscovered never touches user-intentional entries
- Selector.SweepStaleDiscovered reaches inside per-spec buckets
- Selector.SweepStaleDiscovered is a no-op before the DB exists
- Selector: a pin at position 1 moves its item to the front
- Selector: a pin for an item outside the candidate set is ignored
- Selector: a pin past the end of the list clamps to last place
- Selector: two pins on the same position keep both items in the list
- Selector.GetEffectivePriority returns an empty list for an unknown category
- Selector: ListAvailable returns every owned candidate, not just the best
- Selector: ListAvailable preserves effective-priority order
- Selector: ListAvailable skips unknown spells and includes known ones
- Selector: ListAvailable on a per-hand category only offers what fits the weapons
- Selector: ListAvailable on a per-hand category is empty with no weapon equipped
- Selector: ListAvailable on a composite unions its components, deduped
- Selector: ListAvailable on a composite honors disabled components
- Selector: ListAvailable returns an empty list for an unknown category
- Selector.PickBestForCategory skips an item the player is over the cap for
- Selector.ListAvailable omits an item the player is over the cap for
- Selector.PickBestForCategory keeps an item whose tooltip is still pending

### test_settingsui.lua (13)

- Settings UI: the scrollbar patch IS the library's, not a lookalike
- Settings UI: the published instance carries all three of the major's files
- Settings UI: LibKa0s-Options tripwire — Options reads no descriptor L
- Settings UI: the canvas frame carries OnCommit, OnDefault and OnRefresh
- Settings UI: OnDefault reaches a defaultsOnClick parked after the panel is built
- Settings UI: a page with no defaults action still has a callable, inert OnDefault
- Settings UI: the scroll container comes from the library
- Settings UI: the render helpers are the instance's, not host copies
- Settings UI: a panel comes from the library's registry, breadcrumb and all
- Settings UI: the library's user-visible strings resolve to prose, not to their own keys
- Settings UI: ResetScroll reassigns the refresher list rather than wiping it
- Settings UI: with the library absent no panel is registered, and it says why once
- Settings: a targeted category page offers the mouseover toggle, bound to bucket.mouseover

### test_slash.lua (68)

- /cm set toggles a bool setting through the schema
- /cm priority add then remove edits the FOOD candidate set
- /cm priority add accepts a spell sentinel (s:ID)
- /cm stat primary sets the current spec's primary stat
- /cm stat primary resolves a CLASS:SPEC token
- /cm version prints the canonical v<version> line, not 'version <v>'
- /cm list colors the header, page group, and key=value rows (no trailing colon)
- /cm get echoes the same colored key=value form as list
- /cm with an unknown command reports it and prints help
- /cm dump pick renders a category's effective priority and marks owned picks
- /cm rewrite is a back-compat alias for rewritemacros
- /cm with no argument prints the help table
- /cm lower-cases only the verb, leaving arguments alone
- /cm tolerates surrounding whitespace
- /cm help and the About panel read the same command table
- /cm resetall asks for confirmation instead of wiping immediately
- /cm resetall's confirmation still performs the full wipe when accepted
- /cm reset <path> restores exactly that row and leaves its neighbours alone
- /cm config reports when the settings panel cannot be opened
- /cm priority with no category prints the sub-verbs and known categories
- /cm priority with an unknown category reports it and prints help
- /cm priority <cat> with no sub-verb defaults to the list
- /cm priority list marks ownership and the current pick
- /cm priority rejects an unparseable id with a usage line
- /cm priority reset clears the user's edits but keeps discoveries
- /cm priority up reorders the list by pinning
- /cm priority up on the top entry reports the edge instead of reordering
- /cm priority on a composite category points at the aio editor
- /cm priority with an unknown sub-verb reports it
- /cm stat with no sub-verb prints the stat help
- /cm stat list prints the resolved priority for the current spec
- /cm stat primary rejects a stat that is not a primary
- /cm stat secondary stores an ordered, deduplicated list
- /cm stat secondary rejects the whole list if any stat is unknown
- /cm stat secondary preserves the existing primary
- /cm stat reset drops the override and falls back to the seed
- /cm stat reset on a spec with no override says there is nothing to do
- /cm stat with an unknown sub-verb reports it
- /cm aio with no key prints the sub-verbs and the composite keys
- /cm aio on a single-pick category is rejected
- /cm aio list shows both sections with their on/off state
- /cm aio toggle flips a sub-category and back
- /cm aio toggle honors an explicit on/off argument
- /cm aio toggle rejects a ref that is not part of the composite
- /cm aio down reorders within a section
- /cm aio up at the top of a section reports the edge
- /cm aio reset restores both the enabled flags and the section order
- /cm aio with an unknown sub-verb reports it
- /cm dump with no target lists every dump target
- /cm dump with an unknown target reports it and lists the valid ones
- /cm dump <itemID> is a shortcut for the item target
- /cm dump bags lists each owned itemID and its count
- /cm dump pick on a composite renders the assembled macro body
- /cm dump statpriority prints the current spec's resolved stats
- /cm resync rediscovers, recomputes, and reports the count
- /cm resync warns that macro writes are deferred while in combat
- /cm resync drops cached tooltip parses first
- /cm rewritemacros clears the fingerprint cache before recomputing
- /cm debug on and off drive the logging flag through the DebugLog seam
- /cm debug with no argument toggles the window and leaves the flag alone
- /cm set reports an unknown setting path
- /cm get reports an unknown setting path
- /cm set rejects a non-boolean value for a bool setting
- /cm set on a numeric dropdown accepts a listed value as a number
- /cm set on a numeric dropdown rejects a value outside the list
- /cm set on a plain number row still clamps to min/max
- /cm set on a string dropdown still matches by text
- /cm list covers every row in the settings schema

### test_slashsetup.lua (10)

- Slash: the dispatcher IS the library's instance, not a host lookalike
- Slash: /cm routes through the instance rather than a parallel path
- Slash: the library reads the addon's live COMMANDS table, not a copy
- Slash: help rows are rendered by the library's own formatter
- Slash: the About panel's rows go through the SAME formatter, un-indented
- Slash: the addon's own shipped wording survives the library's strings
- Slash: every rendered string resolves to prose, not to its own key
- Slash: a bare /cm get answers with its usage line rather than raising
- Slash: a bare /cm reset points at /cm resetall rather than wiping
- Slash: the schema CLI reads the addon's shapes through the library

### test_spechelper.lua (16)

- SpecHelper.MakeKey joins classID_specID, nil on missing parts
- SpecHelper.GetCurrent reads the live spec and re-reads on respec
- SpecHelper.GetCurrent returns classID-only when no spec is chosen
- SpecHelper.GetStatPriority honors a user override
- SpecHelper.GetStatPriority falls back to class primary, never nil
- SpecHelper.GetStatPriority returns a well-formed seed default for a real spec
- SpecHelper.AllSpecs enumerates specs including the current one
- SpecHelper.MakeKey is stable regardless of numeric or string inputs
- SpecHelper.GetCurrent returns nothing when the client has no class yet
- SpecHelper.GetCurrent stops at the classID when the spec id is unresolvable
- SpecHelper.GetStatPriority ignores a user row that names no primary
- SpecHelper.GetStatPriority defaults a user override's secondary list to empty
- SpecHelper.GetStatPriority falls back on class primary for an unseeded spec
- SpecHelper.GetStatPriority never returns nil, even for a malformed key
- SpecHelper.AllSpecs yields fully-formed rows keyed the same way as GetCurrent
- SpecHelper.AllSpecs skips classes the client reports no specs for

### test_tooltipcache.lua (18)

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
- TooltipCache: parses a 'cannot be used by players higher than level' cap
- TooltipCache: parses a drums 'above level' affect cap
- TooltipCache: a floor phrasing without a negation does NOT produce a maxLevel
- TooltipCache: an item whose only recognized line is a max-level cap resolves final, not pending (Emergency Soul Link)
- TooltipCache: an uncapped item reports no maxLevel
- TooltipCache.IsUsableByPlayer rejects an over-cap item and accepts at the cap

### test_vendor_sync.lua (2)

- libs/LibKa0s is the LibKa0s release the README says this addon bundles
- tests/_kit is the test kit that shipped with that release

### test_weaponslots.lua (9)

- WeaponSlots: maps equipped weapon subtype to bladed/blunt/nil
- WeaponSlots: keys on weapon subClassID, not the localized subType
- WeaponSlots: every bladed weapon subclass reports bladed affinity
- WeaponSlots: every blunt weapon subclass reports blunt affinity
- WeaponSlots: ranged and wand subclasses take no stone at all
- WeaponSlots: main hand and off hand are read independently
- WeaponSlots: an off-hand holdable (armor) is not enhanceable
- WeaponSlots: an unknown item in the slot yields no affinity
- WeaponSlots: a slot the client cannot report is safe to query

### test_widgets.lua (6)

- Widgets: every custom widget registers itself with AceGUI
- Widgets: each registration supplies a constructor function
- Widgets: each registration declares a positive integer version
- Widgets: the version guard skips a widget already registered at that version
- Widgets: no two widgets claim the same type name
- Widgets: every widget name used by the settings pages is registered

## Totals

| Suite | Cases |
|-------|------:|
| test_bagscanner.lua | 12 |
| test_bus.lua | 11 |
| test_categories.lua | 4 |
| test_classifier.lua | 16 |
| test_compat.lua | 17 |
| test_constants.lua | 12 |
| test_coresetup.lua | 8 |
| test_database.lua | 14 |
| test_debug.lua | 13 |
| test_debuglog.lua | 15 |
| test_defaults.lua | 28 |
| test_events.lua | 20 |
| test_id.lua | 8 |
| test_libka0s.lua | 8 |
| test_load.lua | 1 |
| test_macrobar.lua | 94 |
| test_macromanager.lua | 37 |
| test_perfsetup.lua | 10 |
| test_pipeline.lua | 22 |
| test_ranker.lua | 23 |
| test_runner_list.lua | 4 |
| test_schema.lua | 33 |
| test_selector.lua | 44 |
| test_settingsui.lua | 13 |
| test_slash.lua | 68 |
| test_slashsetup.lua | 10 |
| test_spechelper.lua | 16 |
| test_tooltipcache.lua | 18 |
| test_vendor_sync.lua | 2 |
| test_weaponslots.lua | 9 |
| test_widgets.lua | 6 |
| **Total** | **596** |
