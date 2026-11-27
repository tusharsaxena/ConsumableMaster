-- tests/test_poison.lua -- the rogue poison category (issue #47), on both clients.
--
-- One key, POISON, with a model per client (KCM.POISON_MODEL, defaults/Defaults_Poison.lua):
-- WoW Forever's poison ITEMS, a family per weapon hand; Retail's poison SPELLS, the first chosen
-- one whose buff is missing. Every case names its client and builds the namespace inside it
-- (h.loader.withClient), so both kit profiles prove both models (clients-§6).

local h = _G.KCM_TEST
local test = h.test

local function asForever(fn) return function(t) h.loader.withClient("forever", function() fn(t) end) end end
local function asRetail(fn) return function(t) h.loader.withClient("retail", function() fn(t) end) end end

local function body(mock)
    local m = mock.macros.KCM_POISON
    return m and m.body or nil
end

-- ---------------------------------------------------------------------------
-- The category (both clients)
-- ---------------------------------------------------------------------------

test("Poison: the category exists on both clients, with its own model on each", function(t)
    for _, client in ipairs({ "retail", "forever" }) do
        h.loader.withClient(client, function()
            local KCM = h.loader.loadPure()
            local cat = KCM.Categories.Get("POISON")
            t.truthy(cat, client .. ": POISON is registered")
            t.eq(cat and cat.macroName, "KCM_POISON", client .. ": its macro name")
            t.truthy(cat and cat.poison, client .. ": routed through modules/Poison.lua")
            t.falsy(cat and cat.perHand, client .. ": not Weapon Enchant's affinity path")
            t.eq(KCM.Poison.Model(), client == "forever" and "hands" or "spells", client .. ": its model")
            t.truthy(cat and cat.emptyText:find("no poison", 1, true), client .. ": an empty-state body")
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- WoW Forever: items, a family per hand
-- ---------------------------------------------------------------------------

local function poisonItem(mock, id, name, level, extra)
    local tt = { isVanillaPoison = true, poisonChance = 20, minLevel = level }
    for k, v in pairs(extra or {}) do tt[k] = v end
    mock.setItem(id, { name = name, classID = 0, subClassID = 8, ilvl = level, tt = tt })
end

local function armBothHands(mock)
    mock.setItem(9500, { subType = "Daggers" })
    mock.setItem(9501, { subType = "Daggers" })
    mock.setEquipped(16, 9500)
    mock.setEquipped(17, 9501)
end

local function seedRanks(mock)
    poisonItem(mock, 6947, "Instant Poison", 20)
    poisonItem(mock, 6949, "Instant Poison II", 28)
    poisonItem(mock, 6950, "Instant Poison III", 36)
    poisonItem(mock, 2892, "Deadly Poison", 30)
    poisonItem(mock, 3775, "Crippling Poison", 20)
end

test("Forever: every seeded rank has a family the dropdowns offer", asForever(function(t)
    local KCM = h.loader.loadPure()
    local families = {}
    for _, f in ipairs(KCM.POISON_MODEL.families) do families[f] = true end
    t.eq(#KCM.SEED.POISON, 20, "every rank of the five families")
    for _, id in ipairs(KCM.SEED.POISON) do
        local fam = KCM.SEED.POISON_FAMILY[id]
        t.truthy(fam and families[fam], tostring(id) .. " has a family the dropdown offers")
    end
    local d = KCM.dbDefaults.profile.categories.POISON
    t.eq(d.mainHand, "INSTANT", "Instant in the main hand by default")
    t.eq(d.offHand, "DEADLY", "Deadly in the off hand by default")
end))

test("Forever: a discovered rank the seed does not name takes its family from its name", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    poisonItem(mock, 99001, "Mind-numbing Poison IV", 60)
    poisonItem(mock, 99002, "Wound Poison V", 60)
    mock.setItem(99003, { name = "Strange Brew", classID = 0, subClassID = 8 })
    t.eq(KCM.Poison.FamilyOf(99001), "MINDNUMBING", "the hyphen in Mind-numbing is matched")
    t.eq(KCM.Poison.FamilyOf(99002), "WOUND", "Wound")
    t.eq(KCM.Poison.FamilyOf(99003), nil, "a name that is no poison family has none")
end))

test("Forever: the poison wording sets the Forever flag and the chance", function(t)
    local KCM = h.loader.loadFiles({ "Namespace.lua", "Compat.lua", "TooltipCache.lua" })
    local TC, mock = KCM.TooltipCache, h.loader.mock
    local function parse(id, lines)
        mock.setItem(id, { subType = "Consumable" })
        _G.C_TooltipInfo.GetItemByID = function(qid)
            if qid ~= id then return nil end
            local out = {}
            for i, txt in ipairs(lines) do out[i] = { leftText = txt } end
            return { lines = out }
        end
        TC.Invalidate(id)
        return TC.Get(id)
    end
    -- Verbatim from the owner's capture (build 70862): ONE line, the sentences joined by \r\n.
    local p = parse(6947, { "Instant Poison",
        "Use: Coats a weapon with poison that lasts for 30 minutes.\r\nEach strike has a 20% chance of "
        .. "poisoning the enemy which instantly inflicts 13 to 17 Nature damage.  60 charges." })
    t.eq(p.pending, nil, "a poison's tooltip is a parsed effect, never left pending")
    t.eq(p.isVanillaPoison, true, "the Forever flag")
    t.eq(p.poisonChance, 20, "and its chance")
    t.eq(p.isVanillaWeaponEnhance, nil, "never a WPN_ENCH stone or oil")
    local cure = parse(9601, { "Use: Cures diseases and neutralizes poisons up to level 35." })
    t.eq(cure.isVanillaPoison, nil, "a cure that names poisons is no poison")
end)

test("Forever: a poison classifies as POISON and never as a weapon enchant", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    poisonItem(mock, 6947, "Instant Poison", 20)
    t.eqList(KCM.Classifier.MatchAny(6947), { "POISON" }, "POISON only")
    mock.setItem(9602, { classID = 0, subClassID = 5, tt = { isVanillaPoison = true } })
    t.falsy(KCM.Classifier.Match("POISON", 9602), "the flag on another subclass is not enough")
end))

test("Retail: no item is ever a poison, whatever its tooltip says", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    poisonItem(mock, 6947, "Instant Poison", 20)
    t.falsy(KCM.Classifier.Match("POISON", 6947), "Retail's poisons are spells")
end))

test("Forever: the ranks of a family rank by required level", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    seedRanks(mock)
    local R = KCM.Ranker
    t.eqList(R.SortCandidates("POISON", { 6947, 6950, 6949 }, {}), { 6950, 6949, 6947 },
        "III over II over I")
    local ex = R.Explain("POISON", 6949, {})
    t.eq(ex.score, R.Score("POISON", 6949, {}), "the explanation adds up to the score")
end))

test("Forever: each hand takes the best owned, usable rank of its family", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local P = KCM.Poison
    seedRanks(mock)
    armBothHands(mock)
    for _, id in ipairs({ 6947, 6949, 6950, 2892, 3775 }) do mock.setBag(id, 5) end
    mock.setPlayerLevel(30)
    t.eq(P.PickForHand(16), 6949, "Instant Poison II: III is level 36, the rogue is 30")
    t.eq(P.PickForHand(17), 2892, "Deadly Poison in the off hand")

    KCM.db.profile.categories.POISON.offHand = "CRIPPLING"
    t.eq(P.PickForHand(17), 3775, "the off hand follows its family")
    KCM.db.profile.categories.POISON.offHand = "WOUND"
    t.eq(P.PickForHand(17), 2892, "a family with none owned falls back to the best owned poison (Deadly, level 30)")

    mock.setEquipped(17, nil)
    t.eq(P.PickForHand(17), nil, "a hand with no weapon takes nothing")
end))

test("Forever: the macro applies each hand's pick, in Weapon Enchant's shape", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    seedRanks(mock)
    armBothHands(mock)
    mock.setBag(6949, 5)
    mock.setBag(2892, 5)
    KCM.Pipeline.Recompute("test")
    t.eq(body(mock), "#showtooltip\n/use item:6949\n/use 16\n/use item:2892\n/use 17",
        "main hand Instant II, off hand Deadly")
    local list = KCM.Selector.ListAvailable("POISON")
    t.eqList(list, { 2892, 6949 }, "the flyout offers every owned poison, best rank first")
end))

test("Forever: a character with no poison gets the empty-state macro", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    armBothHands(mock)
    KCM.Pipeline.Recompute("test")
    t.truthy((body(mock) or ""):find("no poison available", 1, true), "the empty-state line")
end))

test("Forever: the bag scan files a poison it was never seeded", asForever(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    poisonItem(mock, 99010, "Deadly Poison VI", 60)
    mock.setBag(99010, 1)
    KCM.Pipeline.RunAutoDiscovery("test")
    t.truthy(KCM.db.profile.categories.POISON.discovered[99010], "discovered into POISON")
    t.eq(KCM.Poison.FamilyOf(99010), "DEADLY", "and read as a Deadly rank")
end))

-- ---------------------------------------------------------------------------
-- Retail: spells, the first missing poison
-- ---------------------------------------------------------------------------

local SPELLS = {
    { 315584, "Instant Poison" }, { 2823, "Deadly Poison" }, { 8679, "Wound Poison" },
    { 381664, "Amplifying Poison" }, { 3408, "Crippling Poison" }, { 5761, "Numbing Poison" },
    { 381637, "Atrophic Poison" },
}

-- `known`: the spell ids the rogue has. Answers the set of up buffs the aura stub reads, and the
-- read log.
local function retailRogue(mock, known)
    local set = {}
    for _, id in ipairs(known) do set[id] = true end
    for _, s in ipairs(SPELLS) do mock.setSpell(s[1], { name = s[2], known = set[s[1]] == true }) end
    mock.setPlayerClass("ROGUE")
    local up, reads = {}, {}
    _G.C_UnitAuras = {
        GetPlayerAuraBySpellID = function(id)
            reads[#reads + 1] = id
            return up[id] and { spellId = id } or nil
        end,
    }
    return up, reads
end

test("Retail: a non-rogue gets the empty-state macro", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    KCM.Pipeline.Recompute("test")
    t.truthy((body(mock) or ""):find("no poison available", 1, true), "present but empty")
    t.eqList(KCM.Poison.Wanted(), {}, "nothing is wanted")
end))

test("Retail: the macro casts the first missing poison, lethal first, then goes idle", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local up = retailRogue(mock, { 315584, 2823, 3408 })
    KCM.Pipeline.Recompute("test")
    t.eq(body(mock), "#showtooltip\n/cast Deadly Poison", "Deadly leads the shipped lethal order")

    up[2823] = true
    KCM.Pipeline.Recompute("test")
    t.eq(body(mock), "#showtooltip\n/cast Crippling Poison", "then the one known non-lethal")

    up[3408] = true
    KCM.Pipeline.Recompute("test")
    t.truthy((body(mock) or ""):find("all poisons applied", 1, true), "every wanted poison up: idle")
    t.eq(mock.macros.KCM_POISON.icon, KCM.EMPTY_ICON, "with the empty-state icon")
end))

test("Retail: Dragon-Tempered Blades keeps two of each kind", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    retailRogue(mock, { 315584, 2823, 3408, 381637, 381801 })
    mock.setSpell(381801, { name = "Dragon-Tempered Blades", known = true })
    local names = {}
    for i, id in ipairs(KCM.Poison.Wanted()) do names[i] = KCM.ID.SpellID(id) end
    t.eqList(names, { 2823, 315584, 381637, 3408 }, "two lethal, then two non-lethal, in list order")
end))

test("Retail: the order and the In macro flags decide what is wanted", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    retailRogue(mock, { 315584, 2823, 3408 })
    local b = KCM.db.profile.categories.POISON
    b.lethal = { "INSTANT", "DEADLY", "WOUND", "AMPLIFYING" }
    t.eq(KCM.ID.SpellID(KCM.Poison.Wanted()[1]), 315584, "Instant once it leads the list")
    b.enabled = { INSTANT = false }
    t.eq(KCM.ID.SpellID(KCM.Poison.Wanted()[1]), 2823, "an excluded poison is passed over")
    t.eqList(KCM.Selector.ListAvailable("POISON"),
        { KCM.ID.AsSpell(2823), KCM.ID.AsSpell(3408) }, "the flyout offers the known, included poisons")
end))

test("Retail: no aura is read in combat, and the macro keeps its last answer", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local up, reads = retailRogue(mock, { 2823 })
    KCM.Pipeline.Recompute("test")
    local before = body(mock)
    t.eq(before, "#showtooltip\n/cast Deadly Poison", "built out of combat")
    for i = #reads, 1, -1 do reads[i] = nil end
    mock.setCombat(true)
    up[2823] = true
    KCM.Pipeline.Recompute("bag_update_delayed")
    t.eq(#reads, 0, "a pass in combat reads no aura")
    t.falsy(KCM.Poison.AuraChanged(), "and the aura event asks for nothing in combat")
    t.eq(body(mock), before, "the macro is not rewritten")
    mock.setCombat(false)
    KCM:OnRegenEnabled("PLAYER_REGEN_ENABLED")
    t.truthy((body(mock) or ""):find("all poisons applied", 1, true), "the regen edge catches up")
end))

test("Retail: a secret or raising aura read leaves the macro as it is", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    retailRogue(mock, { 2823 })
    KCM.Pipeline.Recompute("test")
    local before = body(mock)
    _G.C_UnitAuras.GetPlayerAuraBySpellID = function() error("Auras cannot be accessed when secret") end
    t.eq(select(2, KCM.Poison.NextCast()), "unknown", "a raising read is unknown, not missing")
    KCM.MacroManager.MarkAllStale()
    KCM.Pipeline.Recompute("test")
    t.eq(body(mock), before, "and the macro is unchanged")
    mock.setCooldownsRestricted(true)
    local secret = mock.secret(1)
    _G.C_UnitAuras.GetPlayerAuraBySpellID = function() return secret end
    t.eq(select(2, KCM.Poison.NextCast()), "unknown", "a secret answer is unknown too")
    mock.setCooldownsRestricted(false)
end))

test("Retail: the player's aura event rebuilds the macro only when its next cast moved", asRetail(function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    local up = retailRogue(mock, { 2823 })
    KCM.Pipeline.Recompute("test")
    local asked = 0
    local real = KCM.Pipeline.RequestRecompute
    KCM.Pipeline.RequestRecompute = function(...) asked = asked + 1; return real(...) end
    KCM:OnUnitAura("UNIT_AURA", "party1")
    t.eq(asked, 0, "another unit's aura is ignored")
    KCM:OnUnitAura("UNIT_AURA", "player")
    t.eq(asked, 0, "nothing moved, so no pass")
    up[2823] = true
    KCM:OnUnitAura("UNIT_AURA", "player")
    t.eq(asked, 1, "Deadly went up: one pass")
    t.truthy((body(mock) or ""):find("all poisons applied", 1, true), "and the macro went idle")
    KCM.Pipeline.RequestRecompute = real
end))

test("Poison: the aura and talent events are Retail's alone", function(t)
    for _, client in ipairs({ "retail", "forever" }) do
        h.loader.withClient(client, function()
            local KCM = h.loader.loadPure()
            local names = {}
            for _, pair in ipairs(KCM.ClientEvents()) do names[pair[1]] = true end
            local want = client == "retail"
            t.eq(names.UNIT_AURA == true, want, client .. ": UNIT_AURA")
            t.eq(names.TRAIT_CONFIG_UPDATED == true, want, client .. ": TRAIT_CONFIG_UPDATED")
            t.falsy(KCM.Poison.AuraChanged() and client == "forever", client .. ": Forever never asks")
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- The schema rows, per model
-- ---------------------------------------------------------------------------

test("Poison: each client registers its own model's rows and none of the other's", function(t)
    for _, client in ipairs({ "retail", "forever" }) do
        h.loader.withClient(client, function()
            local KCM = h.loader.loadFullAddon()
            local F = KCM.Settings.Helpers.FindSchema
            local hands = client == "forever"
            for _, field in ipairs({ "mainHand", "offHand" }) do
                t.eq(F("categories.POISON." .. field) ~= nil, hands, client .. ": " .. field)
            end
            for _, field in ipairs({ "lethal", "nonLethal", "enabled" }) do
                t.eq(F("categories.POISON." .. field) ~= nil, not hands, client .. ": " .. field)
            end
        end)
    end
end)

test("Forever: a hand's family is written through its row, and an unknown one is refused", asForever(function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.Schema:Set("categories.POISON.offHand", "CRIPPLING"), "a family the dropdown offers")
    t.eq(KCM.db.profile.categories.POISON.offHand, "CRIPPLING", "is stored")
    t.falsy(KCM.Schema:Set("categories.POISON.offHand", "AMPLIFYING"), "Retail's token is no Forever family")
    t.eq(KCM.db.profile.categories.POISON.offHand, "CRIPPLING", "and nothing moved")
end))

test("Retail: a lethal order is normalized to its members", asRetail(function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.Schema:Set("categories.POISON.lethal", { "WOUND", "CRIPPLING" }), "written")
    t.eqList(KCM.db.profile.categories.POISON.lethal, { "WOUND", "INSTANT", "DEADLY", "AMPLIFYING" },
        "a non-lethal dropped, the missing lethals appended in member order")
end))

test("Poison: the tab draws on both clients", function(t)
    for _, client in ipairs({ "retail", "forever" }) do
        h.loader.withClient(client, function()
            local KCM = h.loader.loadFullAddon()
            local ok, err = pcall(function()
                KCM.Options.Open()
                KCM.Options.SetMacroTab("POISON")
                KCM.Settings.Helpers.RefreshAllPanels()
            end)
            t.truthy(ok, client .. ": the Poison tab renders (" .. tostring(err) .. ")")
        end)
    end
end)
