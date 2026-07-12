-- tests/test_selector.lua — Selector.lua candidate-set + priority + picking.

local h = require("harness")

local function has(list, val)
    for _, v in ipairs(list) do if v == val then return true end end
    return false
end

h.suite("selector", function(t)
    -- ---------------------------------------------------------------
    -- BuildCandidateSet = (seed ∪ added ∪ discovered) − blocked
    -- ---------------------------------------------------------------
    do
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
    end

    -- ---------------------------------------------------------------
    -- AddItem: appears in set, idempotent return contract
    -- ---------------------------------------------------------------
    do
        local KCM = h.loader.loadPure()
        local NEW = 900001

        t.falsy(has(KCM.Selector.BuildCandidateSet("HP_POT"), NEW), "new item absent before add")
        t.truthy(KCM.Selector.AddItem("HP_POT", NEW), "AddItem returns true first time")
        t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), NEW), "added item now in set")
        t.falsy(KCM.Selector.AddItem("HP_POT", NEW), "AddItem returns false when already added")
    end

    -- ---------------------------------------------------------------
    -- Block: removes from set, idempotent return contract
    -- ---------------------------------------------------------------
    do
        local KCM = h.loader.loadPure()
        local victim = KCM.SEED.HP_POT[1]

        t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), victim), "seed item present pre-block")
        t.truthy(KCM.Selector.Block("HP_POT", victim), "Block returns true first time")
        t.falsy(has(KCM.Selector.BuildCandidateSet("HP_POT"), victim), "blocked item removed from set")
        t.falsy(KCM.Selector.Block("HP_POT", victim), "Block returns false when already blocked")

        -- AddItem unblocks (must return true even though it clears block).
        t.truthy(KCM.Selector.AddItem("HP_POT", victim), "AddItem unblocks previously-blocked item")
        t.truthy(has(KCM.Selector.BuildCandidateSet("HP_POT"), victim), "unblocked item back in set")
    end

    -- ---------------------------------------------------------------
    -- MarkDiscovered: true first sighting, false on later bump
    -- ---------------------------------------------------------------
    do
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
    end

    -- ---------------------------------------------------------------
    -- PickBestForCategory: first owned item, nil when nothing owned
    -- ---------------------------------------------------------------
    do
        local KCM = h.loader.loadPure()
        local mock = h.loader.mock
        local seed = KCM.SEED.HP_POT

        t.eq(KCM.Selector.PickBestForCategory("HP_POT"), nil, "nil when nothing owned")

        -- Own exactly one seed item (empty tt → all tie, deterministic pick).
        local owned = seed[2]
        mock.setBag(owned, 5)
        t.eq(KCM.Selector.PickBestForCategory("HP_POT"), owned, "returns the one owned item")
    end

    -- ---------------------------------------------------------------
    -- Spell entry counts as owned when IsPlayerSpell is true
    -- ---------------------------------------------------------------
    do
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
    end

    -- ---------------------------------------------------------------
    -- MoveUp / MoveDown reorder via pins
    -- ---------------------------------------------------------------
    do
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
    end

    -- ---------------------------------------------------------------
    -- Spec-aware category (FLASK): GetBucket lands in bySpec sub-table
    -- ---------------------------------------------------------------
    do
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
    end
end)
