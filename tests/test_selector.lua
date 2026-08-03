-- tests/test_selector.lua — Selector.lua candidate-set + priority + picking.

local h = require("harness")
local test = h.test

local function has(list, val)
    for _, v in ipairs(list) do if v == val then return true end end
    return false
end

-- ---------------------------------------------------------------
-- BuildCandidateSet = (seed ∪ added ∪ discovered) − blocked
-- ---------------------------------------------------------------
test("Selector: BuildCandidateSet is seed-first; unknown category is empty", function(t)
    local KCM = h.loader.loadPure()
    local seed = KCM.SEED.HP_POT
    t.truthy(seed and #seed > 0, "HP_POT has a seed list")

    local cand = KCM.Selector.BuildCandidateSet("HP_POT")
    for _, id in ipairs(seed) do
        t.truthy(has(cand, id), "seed item " .. id .. " in candidate set")
    end
    -- Order is seed-first, stable by seed order.
    t.eq(cand[1], seed[1], "candidate set is seed-first")

    -- Unknown category → empty.
    t.eqList(KCM.Selector.BuildCandidateSet("NOPE"), {}, "unknown category empty set")
end)

-- ---------------------------------------------------------------
-- AddItem: appears in set, idempotent return contract
-- ---------------------------------------------------------------
test("Selector: AddItem adds to the set and is idempotent", function(t)
    local KCM = h.loader.loadPure()
    local NEW = 900001

    t.falsy(has(KCM.Selector.BuildCandidateSet("HP_POT"), NEW), "new item absent before add")
    t.truthy(KCM.Selector.AddItem("HP_POT", NEW), "AddItem returns true first time")
    t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), NEW), "added item now in set")
    t.falsy(KCM.Selector.AddItem("HP_POT", NEW), "AddItem returns false when already added")
end)

-- ---------------------------------------------------------------
-- Block: removes from set, idempotent return contract, AddItem unblocks
-- ---------------------------------------------------------------
test("Selector: Block removes from set, is idempotent, and AddItem unblocks", function(t)
    local KCM = h.loader.loadPure()
    local victim = KCM.SEED.HP_POT[1]

    t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), victim), "seed item present pre-block")
    t.truthy(KCM.Selector.Block("HP_POT", victim), "Block returns true first time")
    t.falsy(has(KCM.Selector.BuildCandidateSet("HP_POT"), victim), "blocked item removed from set")
    t.falsy(KCM.Selector.Block("HP_POT", victim), "Block returns false when already blocked")

    -- AddItem unblocks (must return true even though it clears block).
    t.truthy(KCM.Selector.AddItem("HP_POT", victim), "AddItem unblocks previously-blocked item")
    t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), victim), "unblocked item back in set")
end)

-- ---------------------------------------------------------------
-- MarkDiscovered: true first sighting, false on later bump
-- ---------------------------------------------------------------
test("Selector: MarkDiscovered promotes once; blocked items are never discovered", function(t)
    local KCM = h.loader.loadPure()
    local DISC = 900050

    t.truthy(KCM.Selector.MarkDiscovered("HP_POT", DISC, nil, 1000), "MarkDiscovered true first time")
    t.falsy(KCM.Selector.MarkDiscovered("HP_POT", DISC, nil, 2000), "MarkDiscovered false on later bump")
    t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), DISC), "discovered item enters candidate set")

    -- Blocked items are never promoted to discovered.
    local B = 900051
    KCM.Selector.Block("HP_POT", B)
    t.falsy(KCM.Selector.MarkDiscovered("HP_POT", B, nil, 3000), "blocked item not discovered")
    t.falsy(has(KCM.Selector.BuildCandidateSet("HP_POT"), B), "blocked stays out despite discover attempt")
end)

-- ---------------------------------------------------------------
-- PickBestForCategory: first owned item, nil when nothing owned
-- ---------------------------------------------------------------
test("Selector: PickBestForCategory returns the one owned item, nil when nothing owned", function(t)
    local KCM = h.loader.loadPure()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT

    t.eq(KCM.Selector.PickBestForCategory("HP_POT"), nil, "nil when nothing owned")

    -- Own exactly one seed item (empty tt → all tie, deterministic pick).
    local owned = seed[2]
    mock.setBag(owned, 5)
    t.eq(KCM.Selector.PickBestForCategory("HP_POT"), owned, "returns the one owned item")
end)

-- ---------------------------------------------------------------
-- Spell entry counts as owned when IsPlayerSpell is true
-- ---------------------------------------------------------------
test("Selector: a known spell entry counts as owned and is picked", function(t)
    local KCM = h.loader.loadPure()
    local mock = h.loader.mock
    local SPELL_ID = 1231411
    local sentinel = KCM.ID.AsSpell(SPELL_ID)
    t.truthy(KCM.ID.IsSpell(sentinel), "AsSpell yields a spell sentinel")

    KCM.Selector.AddItem("HP_POT", sentinel)
    -- Not known yet → not owned (no items owned either) → nil.
    t.eq(KCM.Selector.PickBestForCategory("HP_POT"), nil, "unknown spell not owned")

    mock.setSpell(SPELL_ID, { known = true })
    t.eq(KCM.Selector.PickBestForCategory("HP_POT"), sentinel, "known spell is owned + picked")
end)

-- ---------------------------------------------------------------
-- MoveUp / MoveDown reorder via pins
-- ---------------------------------------------------------------
test("Selector: MoveUp/MoveDown reorder via pins; moving past an edge is a no-op", function(t)
    local KCM = h.loader.loadPure()
    local A, B = 900201, 900202  -- empty tt → tie → ascending id order
    KCM.Selector.AddItem("HP_POT", A)
    KCM.Selector.AddItem("HP_POT", B)

    -- Wipe seed so we reason about just A,B. (Test-only: seed is a plain table.)
    KCM.SEED.HP_POT = {}

    local before = KCM.Selector.GetEffectivePriority("HP_POT")
    t.eqList(before, { A, B }, "baseline effective order is ascending")

    t.truthy(KCM.Selector.MoveDown("HP_POT", A), "MoveDown returns true")
    local after = KCM.Selector.GetEffectivePriority("HP_POT")
    t.eqList(after, { B, A }, "MoveDown swaps A below B")

    t.truthy(KCM.Selector.MoveUp("HP_POT", A), "MoveUp returns true")
    t.eqList(KCM.Selector.GetEffectivePriority("HP_POT"), { A, B }, "MoveUp restores order")

    -- Moving past an edge is a no-op.
    t.falsy(KCM.Selector.MoveUp("HP_POT", A), "MoveUp at top is no-op")
    t.falsy(KCM.Selector.MoveDown("HP_POT", B), "MoveDown at bottom is no-op")
end)

-- ---------------------------------------------------------------
-- Spec-aware category (FLASK): GetBucket lands in bySpec sub-table
-- ---------------------------------------------------------------
test("Selector: spec-aware FLASK category routes GetBucket/AddItem into the bySpec sub-table", function(t)
    local KCM = h.loader.loadPure()
    -- Default mock spec: classID 7, specID 263 → key "7_263".
    local specKey = KCM.SpecHelper.MakeKey(7, 263)
    t.eq(specKey, "7_263", "spec key format")

    local bucket = KCM.Selector.GetBucket("FLASK")
    t.truthy(bucket, "FLASK bucket resolves for current spec")

    local root = KCM.db.profile.categories.FLASK
    t.truthy(root.bySpec, "FLASK root has bySpec")
    t.truthy(root.bySpec[specKey], "bySpec sub-table created under current spec key")
    t.eq(bucket, root.bySpec[specKey], "GetBucket returns the bySpec sub-table")

    -- A mutation lands inside the spec sub-table, not on root.
    local F = 900301
    KCM.Selector.AddItem("FLASK", F)
    t.truthy(root.bySpec[specKey].added[F], "AddItem writes into bySpec bucket")
    t.truthy(has(KCM.Selector.BuildCandidateSet("FLASK"), F), "added flask in spec candidate set")

    -- Explicit specKey argument routes to a different sub-table.
    local other = KCM.SpecHelper.MakeKey(8, 62)
    local ob = KCM.Selector.GetBucket("FLASK", other)
    t.truthy(ob, "explicit spec key resolves a bucket")
    t.ne(ob, bucket, "different spec key → different bucket")
end)

-- ---------------------------------------------------------------
-- PickBestForSlot: weapon-affinity-filtered pick per slot
-- ---------------------------------------------------------------
test("Selector: PickBestForSlot filters by weapon affinity + ownership", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector

    -- Candidates: a bladed whetstone, a blunt weightstone, an any oil.
    mock.setItem(6001, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    mock.setItem(6002, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "blunt",  statBuffs = { { stat = "AP", amount = 15 } } } })
    mock.setItem(6003, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "any",    statBuffs = { { stat = "CRIT", amount = 9 } } } })
    for _, id in ipairs({ 6001, 6002, 6003 }) do S.AddItem("WPN_ENCH", id) end
    mock.setBag(6001, 1); mock.setBag(6002, 1); mock.setBag(6003, 1)

    -- Main hand is a sword (bladed): whetstone or oil eligible, weightstone not.
    mock.setItem(6100, { subType = "Two-Handed Swords" }); mock.setEquipped(16, 6100)
    local mh = S.PickBestForSlot("WPN_ENCH", 16, nil)
    t.truthy(mh == 6001 or mh == 6003, "bladed slot picks whetstone or oil, never the weightstone")

    -- Empty off-hand -> nil.
    mock.setEquipped(17, nil)
    t.eq(S.PickBestForSlot("WPN_ENCH", 17, nil), nil, "no weapon in slot -> nil")
end)

-- ---------------------------------------------------------------
-- PickBestForSlot: negative-ownership exclusion
-- ---------------------------------------------------------------
test("Selector: PickBestForSlot excludes an affinity-eligible item that isn't owned", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector

    -- Bladed whetstone and any-oil are affinity-eligible, but neither is owned
    -- (no setBag call / count 0) — only the blunt weightstone is owned.
    mock.setItem(6001, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    mock.setItem(6002, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "blunt",  statBuffs = { { stat = "AP", amount = 15 } } } })
    mock.setItem(6003, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "any",    statBuffs = { { stat = "CRIT", amount = 9 } } } })
    for _, id in ipairs({ 6001, 6002, 6003 }) do S.AddItem("WPN_ENCH", id) end
    mock.setBag(6001, 0); mock.setBag(6003, 0)
    mock.setBag(6002, 1)

    -- Main hand is a sword (bladed): whetstone/oil would be eligible by
    -- affinity, but neither is owned, so the pick must be nil.
    mock.setItem(6100, { subType = "Two-Handed Swords" }); mock.setEquipped(16, 6100)
    t.eq(S.PickBestForSlot("WPN_ENCH", 16, nil), nil, "affinity-eligible but unowned items excluded")
end)

-- ---------------------------------------------------------------
-- PickBestForSlot: reverse affinity (blunt weapon in the slot)
-- ---------------------------------------------------------------
test("Selector: PickBestForSlot on a blunt weapon excludes the bladed whetstone", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector

    mock.setItem(6001, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    mock.setItem(6002, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "blunt",  statBuffs = { { stat = "AP", amount = 15 } } } })
    mock.setItem(6003, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "any",    statBuffs = { { stat = "CRIT", amount = 9 } } } })
    for _, id in ipairs({ 6001, 6002, 6003 }) do S.AddItem("WPN_ENCH", id) end
    mock.setBag(6001, 1); mock.setBag(6002, 1); mock.setBag(6003, 1)

    -- Main hand is a Two-Handed Mace (blunt): weightstone or oil eligible,
    -- the bladed whetstone must be excluded.
    mock.setItem(6101, { subType = "Two-Handed Maces" }); mock.setEquipped(16, 6101)
    local mh = S.PickBestForSlot("WPN_ENCH", 16, nil)
    t.truthy(mh == 6002 or mh == 6003, "blunt slot picks weightstone or oil, never the whetstone")
end)

-- ---------------------------------------------------------------------------
-- Discovery bookkeeping + the 30-day TTL sweep
-- ---------------------------------------------------------------------------

local DAY = 86400

test("Selector.MarkDiscovered reports 'new' only on the first sighting", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    t.eq(S.MarkDiscovered("FOOD", 930001, nil, 1000), true, "first sighting is new")
    t.eq(S.MarkDiscovered("FOOD", 930001, nil, 2000), false,
        "a re-sighting is not new — otherwise every bag scan would refresh the UI")
end)

test("Selector.MarkDiscovered bumps the stored timestamp on a re-sighting", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    S.MarkDiscovered("FOOD", 930002, nil, 1000)
    S.MarkDiscovered("FOOD", 930002, nil, 5000)
    t.eq(S.GetBucket("FOOD").discovered[930002], 5000, "the TTL clock restarts on each sighting")
end)

test("Selector.MarkDiscovered does not rewind a timestamp for an out-of-order scan", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    S.MarkDiscovered("FOOD", 930003, nil, 5000)
    S.MarkDiscovered("FOOD", 930003, nil, 1000)
    t.eq(S.GetBucket("FOOD").discovered[930003], 5000, "the newest sighting wins")
end)

test("Selector.MarkDiscovered upgrades a legacy boolean entry to a timestamp", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    S.GetBucket("FOOD").discovered[930004] = true        -- written by v1.0.0
    S.MarkDiscovered("FOOD", 930004, nil, 7000)
    t.eq(S.GetBucket("FOOD").discovered[930004], 7000, "the legacy value is migrated in place")
end)

test("Selector.MarkDiscovered refuses spell sentinels and unknown categories", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    t.eq(S.MarkDiscovered("FOOD", KCM.ID.AsSpell(5512), nil, 1000), false,
        "a spell cannot be found in a bag")
    t.eq(S.MarkDiscovered("NOPE", 930005, nil, 1000), false, "unknown category has no bucket")
    t.eq(S.MarkDiscovered("FOOD", nil, nil, 1000), false, "nil item is a no-op")
end)

test("Selector.SweepStaleDiscovered drops an entry past the 30-day TTL", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local now = 100 * DAY
    S.MarkDiscovered("FOOD", 931001, nil, now - 31 * DAY)
    local swept, cats = S.SweepStaleDiscovered(now)
    t.eq(S.GetBucket("FOOD").discovered[931001], nil, "the stale entry is gone")
    t.eq(swept, 1, "one entry swept")
    t.eq(cats, 1, "across one category")
end)

test("Selector.SweepStaleDiscovered keeps an entry that is still inside the TTL", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local now = 100 * DAY
    S.MarkDiscovered("FOOD", 931002, nil, now - 29 * DAY)
    S.SweepStaleDiscovered(now)
    t.truthy(S.GetBucket("FOOD").discovered[931002], "a recently-seen item survives")
end)

test("Selector.SweepStaleDiscovered refreshes an item that is still in bags", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local now  = 100 * DAY
    S.MarkDiscovered("FOOD", 931003, nil, now - 90 * DAY)   -- long past the TTL
    mock.setBag(931003, 1)                                   -- but the player still owns it
    local swept = S.SweepStaleDiscovered(now)
    t.eq(swept, 0, "nothing swept")
    t.eq(S.GetBucket("FOOD").discovered[931003], now, "an owned item's clock is reset instead")
end)

test("Selector.SweepStaleDiscovered treats a legacy boolean entry as ancient", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    S.GetBucket("FOOD").discovered[931004] = true
    S.SweepStaleDiscovered(100 * DAY)
    t.eq(S.GetBucket("FOOD").discovered[931004], nil,
        "an unowned legacy entry with no timestamp is collected")
end)

-- A recipe misfiled by the pre-classID-gate Classifier sits in `discovered`
-- forever: it IS in bags, so the TTL branch keeps bumping its timestamp. The
-- sweep evicts a discovered entry the class gate would no longer admit, so an
-- existing profile self-heals on the next PEW without a manual resetall.
test("Selector.SweepStaleDiscovered evicts a discovered non-consumable still in bags", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local now  = 100 * DAY
    mock.setItem(931007, { subType = "Enchanting", classID = 9, subClassID = 1 })
    mock.setBag(931007, 1)
    S.MarkDiscovered("WPN_ENCH", 931007, nil, now)
    local swept = S.SweepStaleDiscovered(now)
    t.eq(S.GetBucket("WPN_ENCH").discovered[931007], nil, "the misfiled recipe is evicted")
    t.eq(swept, 1, "counted as swept")
end)

-- The eviction needs a DEFINITE verdict. GetItemInfoInstant returns nil for an
-- item the client hasn't cached, and treating that as "not a consumable" would
-- delete good entries during the load race the sweep runs in.
test("Selector.SweepStaleDiscovered keeps a discovered item whose class is unresolvable", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local now  = 100 * DAY
    mock.setBag(931008, 1)                       -- in bags, but no item data at all
    S.MarkDiscovered("FOOD", 931008, nil, now)
    S.SweepStaleDiscovered(now)
    t.eq(S.GetBucket("FOOD").discovered[931008], now, "an unresolvable item is left alone")
end)

test("Selector.SweepStaleDiscovered never touches user-intentional entries", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    S.AddItem("FOOD", 931005)
    S.Block("FOOD", 931006)
    S.SweepStaleDiscovered(1000 * DAY)
    t.truthy(S.GetBucket("FOOD").added[931005], "an explicitly-added item is never swept")
    t.truthy(S.GetBucket("FOOD").blocked[931006], "nor is a block — it must keep suppressing")
end)

test("Selector.SweepStaleDiscovered reaches inside per-spec buckets", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local now = 100 * DAY
    S.MarkDiscovered("FLASK", 931007, "7_263", now - 60 * DAY)
    local swept = S.SweepStaleDiscovered(now)
    t.eq(swept, 1, "the spec-aware bucket is walked too")
    t.eq(S.GetBucket("FLASK", "7_263").discovered[931007], nil, "and its stale entry removed")
end)

test("Selector.SweepStaleDiscovered is a no-op before the DB exists", function(t)
    local KCM = h.loader.loadPure()
    local saved = KCM.db
    KCM.db = nil
    local swept, cats = KCM.Selector.SweepStaleDiscovered(1000)
    KCM.db = saved
    t.eq(swept, 0, "no entries swept")
    t.eq(cats, 0, "no categories touched")
end)

-- ---------------------------------------------------------------------------
-- Pin merge
-- ---------------------------------------------------------------------------

test("Selector: a pin at position 1 moves its item to the front", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local base = S.GetEffectivePriority("FOOD")
    t.truthy(#base >= 2, "FOOD ranks more than one candidate")

    local last = base[#base]
    S.GetBucket("FOOD").pins = { { itemID = last, position = 1 } }
    local pinned = S.GetEffectivePriority("FOOD")
    t.eq(pinned[1], last, "the pinned item outranks the auto-ranked order")
    t.eq(#pinned, #base, "and no candidate is lost in the merge")
end)

test("Selector: a pin for an item outside the candidate set is ignored", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local base = S.GetEffectivePriority("FOOD")
    S.GetBucket("FOOD").pins = { { itemID = 939999, position = 1 } }
    t.eqList(S.GetEffectivePriority("FOOD"), base,
        "a pin left behind by a removed item does not distort the list")
end)

test("Selector: a pin past the end of the list clamps to last place", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local base = S.GetEffectivePriority("FOOD")
    local first = base[1]
    S.GetBucket("FOOD").pins = { { itemID = first, position = #base + 50 } }
    local pinned = S.GetEffectivePriority("FOOD")
    t.eq(pinned[#pinned], first, "an overshooting position lands at the end, not out of bounds")
    t.eq(#pinned, #base, "the list length is unchanged")
end)

-- Colliding pins can't arise from the UI — MoveUp/MoveDown rewrite the whole
-- pins array as one contiguous 1..N run — so this pins the behavior of a
-- hand-edited or corrupted SavedVariables: first pin listed wins the slot, the
-- loser is displaced rather than silently dropped.
test("Selector: two pins on the same position keep both items in the list", function(t)
    local KCM = h.loader.loadPure()
    local S = KCM.Selector
    local base = S.GetEffectivePriority("FOOD")
    t.truthy(#base >= 3, "enough candidates to collide two pins")
    local a, b = base[#base], base[#base - 1]
    S.GetBucket("FOOD").pins = {
        { itemID = a, position = 1 },
        { itemID = b, position = 1 },
    }
    local pinned = S.GetEffectivePriority("FOOD")
    t.eq(pinned[1], a, "the pin listed first wins the contested slot")
    t.eq(#pinned, #base, "no candidate is lost to the collision")
    local hasB = false
    for _, id in ipairs(pinned) do if id == b then hasB = true end end
    t.truthy(hasB, "the displaced pin is still ranked, just not at its requested slot")
end)

test("Selector.GetEffectivePriority returns an empty list for an unknown category", function(t)
    local KCM = h.loader.loadPure()
    t.eqList(KCM.Selector.GetEffectivePriority("NOT_A_CATEGORY"), {},
        "callers can always ipairs() the result")
end)

-- ---------------------------------------------------------------
-- ListAvailable: every owned candidate, in effective-priority order
-- (the macro-bar flyout's source of truth)
-- ---------------------------------------------------------------
test("Selector: ListAvailable returns every owned candidate, not just the best", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local seed = KCM.SEED.HP_POT

    t.eq(#S.ListAvailable("HP_POT"), 0, "nothing owned -> empty list")

    mock.setBag(seed[1], 2)
    mock.setBag(seed[3], 1)
    local out = S.ListAvailable("HP_POT")
    t.eq(#out, 2, "both owned entries listed")
    -- The macro's own pick must be in the flyout, not excluded from it.
    t.contains(out, S.PickBestForCategory("HP_POT"), "includes the macro's current pick")
end)

test("Selector: ListAvailable preserves effective-priority order", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local seed = KCM.SEED.HP_POT
    for i = 1, 3 do mock.setBag(seed[i], 1) end

    -- Pin the third seed entry to the top; the flyout order must follow the
    -- same priority list the macro picks from, pins included.
    S.MoveUp("HP_POT", seed[3])
    S.MoveUp("HP_POT", seed[3])
    local priority = S.GetEffectivePriority("HP_POT", nil, nil)
    local out = S.ListAvailable("HP_POT")
    t.eq(out[1], priority[1], "first entry matches the priority list's head")
    t.eq(out[1], S.PickBestForCategory("HP_POT"), "and that head is the macro's pick")
end)

test("Selector: ListAvailable skips unknown spells and includes known ones", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local SPELL_ID = 1231411
    local sentinel = KCM.ID.AsSpell(SPELL_ID)
    S.AddItem("HP_POT", sentinel)

    t.eq(#S.ListAvailable("HP_POT"), 0, "unknown spell is not available")
    mock.setSpell(SPELL_ID, { known = true })
    local out = S.ListAvailable("HP_POT")
    t.eq(#out, 1, "known spell is available")
    t.eq(out[1], sentinel, "and it is the spell sentinel")
end)

test("Selector: ListAvailable on a per-hand category only offers what fits the weapons", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector

    mock.setItem(6001, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    mock.setItem(6002, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "blunt",  statBuffs = { { stat = "AP", amount = 15 } } } })
    mock.setItem(6003, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "any",    statBuffs = { { stat = "CRIT", amount = 9 } } } })
    for _, id in ipairs({ 6001, 6002, 6003 }) do S.AddItem("WPN_ENCH", id) end
    mock.setBag(6001, 1); mock.setBag(6002, 1); mock.setBag(6003, 1)

    -- A sword in the main hand, nothing in the off hand: bladed + any qualify,
    -- the blunt weightstone does not.
    mock.setItem(6100, { subType = "Two-Handed Swords" })
    mock.setEquipped(16, 6100)
    mock.setEquipped(17, nil)
    local out = S.ListAvailable("WPN_ENCH")
    t.contains(out, 6001, "bladed whetstone offered")
    t.contains(out, 6003, "any-weapon oil offered")
    for _, id in ipairs(out) do
        t.ne(id, 6002, "blunt weightstone never offered for a sword")
    end
end)

test("Selector: ListAvailable on a per-hand category is empty with no weapon equipped", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setItem(6003, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "any" } })
    S.AddItem("WPN_ENCH", 6003)
    mock.setBag(6003, 1)
    mock.setEquipped(16, nil); mock.setEquipped(17, nil)
    t.eq(#S.ListAvailable("WPN_ENCH"), 0, "nothing to enchant -> nothing offered")
end)

test("Selector: ListAvailable on a composite unions its components, deduped", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    -- FOOD's seed leads with a spell sentinel (Recuperate), so take its first
    -- real ITEM for the bag fixture.
    local hp, food = KCM.SEED.HP_POT[1], nil
    for _, id in ipairs(KCM.SEED.FOOD) do
        if KCM.ID.IsItem(id) then food = id; break end
    end
    t.truthy(food, "FOOD seed has at least one item entry")
    mock.setBag(hp, 1)
    mock.setBag(food, 1)

    -- HP_AIO composes HS + HP_POT (in combat) and FOOD (out of combat).
    local out = S.ListAvailable("HP_AIO")
    t.contains(out, hp, "in-combat component's pick is offered")
    t.contains(out, food, "out-of-combat component's pick is offered")

    -- Same item in two components must appear once.
    S.AddItem("FOOD", hp)
    local seen = 0
    for _, id in ipairs(S.ListAvailable("HP_AIO")) do
        if id == hp then seen = seen + 1 end
    end
    t.eq(seen, 1, "an item shared by two components is listed once")
end)

test("Selector: ListAvailable on a composite honors disabled components", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    local hp, food = KCM.SEED.HP_POT[1], nil
    for _, id in ipairs(KCM.SEED.FOOD) do
        if KCM.ID.IsItem(id) then food = id; break end
    end
    mock.setBag(hp, 1)
    mock.setBag(food, 1)

    KCM.db.profile.categories.HP_AIO.enabled.FOOD = false
    local out = S.ListAvailable("HP_AIO")
    t.contains(out, hp, "enabled component still offered")
    for _, id in ipairs(out) do
        t.ne(id, food, "a disabled component contributes nothing")
    end
end)

test("Selector: ListAvailable returns an empty list for an unknown category", function(t)
    local KCM = h.loader.loadPure()
    t.eq(#KCM.Selector.ListAvailable("NOPE"), 0, "no such category -> empty")
end)

-- ---------------------------------------------------------------
-- Level gate: IsUsableByPlayer must reach the pick path
-- ---------------------------------------------------------------
test("Selector.PickBestForCategory skips an item the player is over the cap for", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setPlayerLevel(80)
    mock.setItem(940001, { subType = "Other", tt = { maxLevel = 50 } })
    mock.setBag(940001, 1)
    S.AddItem("FOOD", 940001)
    -- Assert the capped item is not chosen, rather than asserting WHICH item
    -- is: FOOD has a seed roster and the winner depends on Ranker scores, so
    -- pinning an exact id here would make this test fail for unrelated reasons.
    t.truthy(S.PickBestForCategory("FOOD") ~= 940001, "the capped item is passed over")
end)

test("Selector.ListAvailable omits an item the player is over the cap for", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setPlayerLevel(80)
    mock.setItem(940003, { subType = "Other", tt = { maxLevel = 50 } })
    mock.setBag(940003, 1)
    S.AddItem("FOOD", 940003)
    t.eqList(S.ListAvailable("FOOD"), {}, "an unusable item is not offered in the flyout")
end)

-- The load race: during PEW most tooltips are still pending. "Don't know yet"
-- must not read as "unusable", or picks flap on every login.
test("Selector.PickBestForCategory keeps an item whose tooltip is still pending", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local S    = KCM.Selector
    mock.setItem(940004, { subType = "Other", pending = true })
    mock.setBag(940004, 1)
    S.AddItem("FOOD", 940004)
    t.eq(S.PickBestForCategory("FOOD"), 940004, "a pending item is still eligible")
end)
