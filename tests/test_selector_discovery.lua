-- tests/test_selector_discovery.lua — Selector's discovery bookkeeping and the
-- 30-day TTL sweep. Split from tests/test_selector.lua on 2026-10-31.

local h = _G.KCM_TEST
local test = h.test


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
