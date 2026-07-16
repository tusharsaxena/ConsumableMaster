-- tests/test_categories.lua — new-category wiring: metadata, seeds, DB buckets.

local h = require("harness")
local test = h.test

test("Categories: VANTUS and WPN_ENCH registered with correct metadata and DB buckets", function(t)
    local KCM = h.loader.loadPure()

    local v = KCM.Categories.Get("VANTUS")
    t.truthy(v, "VANTUS category exists")
    t.eq(v.macroName, "KCM_VANTUS", "VANTUS macro name")
    t.eq(v.specAware, false, "VANTUS not spec-aware")

    local w = KCM.Categories.Get("WPN_ENCH")
    t.truthy(w, "WPN_ENCH category exists")
    t.eq(w.macroName, "KCM_WPN_ENCH", "WPN_ENCH macro name")
    t.eq(w.specAware, true, "WPN_ENCH spec-aware")

    -- DB default buckets must exist (Selector.GetBucket returns nil without them).
    t.truthy(KCM.db.profile.categories.VANTUS, "VANTUS profile bucket present")
    t.truthy(KCM.db.profile.categories.WPN_ENCH and KCM.db.profile.categories.WPN_ENCH.bySpec,
        "WPN_ENCH bySpec bucket present")

    -- VANTUS seed loaded and reaches the candidate set.
    local found = false
    for _, id in ipairs(KCM.Selector.BuildCandidateSet("VANTUS")) do
        if id == 245880 then found = true end
    end
    t.truthy(found, "VANTUS seed 245880 in candidate set")
end)

test("Categories: AUG_RUNE registered with metadata, DB bucket, and seed", function(t)
    local KCM = h.loader.loadPure()

    local a = KCM.Categories.Get("AUG_RUNE")
    t.truthy(a, "AUG_RUNE category exists")
    t.eq(a.macroName, "KCM_AUG_RUNE", "AUG_RUNE macro name")
    t.eq(a.specAware, false, "AUG_RUNE not spec-aware")
    t.falsy(a.composite, "AUG_RUNE not composite")
    t.falsy(a.perHand, "AUG_RUNE not per-hand")

    t.truthy(KCM.db.profile.categories.AUG_RUNE, "AUG_RUNE profile bucket present")

    local found = false
    for _, id in ipairs(KCM.Selector.BuildCandidateSet("AUG_RUNE")) do
        if id == 243191 then found = true end
    end
    t.truthy(found, "AUG_RUNE seed 243191 (Ethereal) in candidate set")
end)
