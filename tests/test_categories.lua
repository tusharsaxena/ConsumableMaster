-- tests/test_categories.lua — new-category wiring: metadata, seeds, DB buckets.

local h = _G.KCM_TEST
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

    -- Seed spans Legion..Midnight; spot-check the newest and oldest runes.
    local want = { [259085] = false, [243191] = false, [140587] = false }
    for _, id in ipairs(KCM.Selector.BuildCandidateSet("AUG_RUNE")) do
        if want[id] ~= nil then want[id] = true end
    end
    t.truthy(want[259085], "AUG_RUNE seed 259085 (Void-Touched, Midnight) in candidate set")
    t.truthy(want[243191], "AUG_RUNE seed 243191 (Ethereal, TWW) in candidate set")
    t.truthy(want[140587], "AUG_RUNE seed 140587 (Defiled, Legion) in candidate set")
end)

test("Categories: BLOODLUST and BATTLE_REZ registered with metadata, buckets and seeds", function(t)
    local KCM = h.loader.loadPure()
    for _, key in ipairs({ "BLOODLUST", "BATTLE_REZ" }) do
        local cat = KCM.Categories.Get(key)
        t.truthy(cat, key .. " is registered")
        t.falsy(cat.specAware, key .. " is not spec-aware")
        t.falsy(cat.composite, key .. " is not a composite")
        t.truthy(#cat.macroName <= 16, key .. " macro name fits the 16-char limit")
        t.truthy(KCM.db.profile.categories[key].discovered, key .. " has an item bucket")
        t.truthy(#KCM.SEED[key] > 0, key .. " has a seed roster")
    end
    t.eq(KCM.Categories.Get("BATTLE_REZ").targeted, "[@mouseover,help][@target,help]",
        "Battle Rez declares its targeting clause")
    t.eq(KCM.Categories.Get("BLOODLUST").targeted, nil, "Bloodlust targets the player")
    t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, true, "mouseover defaults on")
end)

test("Categories: the Bloodlust seed leads with spells and the class gate names Primal Rage", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.ID.IsSpell(KCM.SEED.BLOODLUST[1]), "the roster leads with a spell")
    t.eq(KCM.SEED.CLASS_GATE[KCM.ID.AsSpell(272678)], "HUNTER", "Primal Rage is hunter-gated")
end)
