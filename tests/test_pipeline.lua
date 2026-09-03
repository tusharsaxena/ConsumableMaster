-- test_pipeline.lua — the recompute pipeline: coalescing, auto-discovery, and
-- the macro-write loop (KCM.Pipeline in core/ConsumableMaster.lua).

local h = _G.KCM_TEST
local test = h.test

local function load()
    local KCM = h.loader.loadPure()
    return KCM, h.loader.mock
end

-- A Food & Drink heal item that is NOT in any shipped seed, so discovery has
-- something new to find.
local function ownFood(mock, id)
    mock.setItem(id, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(id, 1)
end

local function effectiveSet(KCM, catKey)
    local set = {}
    for _, id in ipairs(KCM.Selector.GetEffectivePriority(catKey)) do set[id] = true end
    return set
end

test("Pipeline.RequestRecompute coalesces a burst into a single run", function(t)
    local KCM = h.loader.loadPure()
    -- Capture the frame callback instead of firing it (the mock's C_Timer.After
    -- runs synchronously), so we can observe the coalescing gate.
    local scheduled = {}
    _G.C_Timer.After = function(_, fn) scheduled[#scheduled + 1] = fn end
    local runs = 0
    KCM.Pipeline.Recompute = function() runs = runs + 1 end

    KCM.Pipeline.RequestRecompute("a")
    KCM.Pipeline.RequestRecompute("b")
    KCM.Pipeline.RequestRecompute("c")
    t.eq(#scheduled, 1, "only one timer scheduled for the whole burst")
    t.eq(runs, 0, "nothing runs until the frame fires")

    scheduled[1]()   -- fire the end-of-frame callback
    t.eq(runs, 1, "the burst collapsed into a single recompute")
end)

test("Pipeline.RunAutoDiscovery adds a classifiable bag item to its category", function(t)
    local KCM, mock = load()
    ownFood(mock, 900001)
    local n = KCM.Pipeline.RunAutoDiscovery("test")
    t.truthy(n >= 1, "reported at least one discovery")
    t.truthy(effectiveSet(KCM, "FOOD")[900001], "discovered item joined FOOD candidates")
end)

test("Pipeline.RunAutoDiscovery keeps a user-blocked item out of candidates", function(t)
    local KCM, mock = load()
    ownFood(mock, 900002)
    KCM.Selector.Block("FOOD", 900002)   -- user blocked it before discovery ran
    KCM.Pipeline.RunAutoDiscovery("test")
    t.falsy(effectiveSet(KCM, "FOOD")[900002], "blocked item stays out of candidates")
end)

test("Pipeline.Recompute writes a macro body pointing at the owned pick", function(t)
    local KCM, mock = load()
    ownFood(mock, 900003)
    KCM.Pipeline.RunAutoDiscovery("test")
    KCM.Pipeline.Recompute("test")
    local m = mock.macros["KCM_FOOD"]
    t.truthy(m, "KCM_FOOD macro created")
    t.truthy(m.body and m.body:find("900003", 1, true), "body points at the owned item")
end)

test("Pipeline.Recompute skips macro writes when the addon is disabled", function(t)
    local KCM, mock = load()
    ownFood(mock, 900004)
    KCM.Pipeline.RunAutoDiscovery("test")
    KCM.db.profile.enabled = false
    KCM.Pipeline.Recompute("test")
    t.eq(mock.macros["KCM_FOOD"], nil, "no macro written while disabled")
end)

test("Pipeline.RecomputeOne routes a perHand category through SetWeaponEnchantMacro", function(t)
    local KCM, mock = load()
    local S = KCM.Selector

    -- A bladed whetstone the player owns; equipped weapons are both bladed
    -- so the main-hand pick resolves to this item.
    mock.setItem(6201, { subType = "Other", tt = { isWeaponEnhance = true, weaponAffinity = "bladed", statBuffs = { { stat = "AP", amount = 10 } } } })
    S.AddItem("WPN_ENCH", 6201)
    mock.setBag(6201, 1)

    mock.setItem(6300, { subType = "One-Handed Swords" }); mock.setEquipped(16, 6300)
    mock.setItem(6301, { subType = "One-Handed Swords" }); mock.setEquipped(17, 6301)

    KCM.Pipeline.RecomputeOne("WPN_ENCH", nil, "test")

    local state = KCM.db.profile.macroState["KCM_WPN_ENCH"]
    t.truthy(state and state.lastBody, "WPN_ENCH macro body was written")
    t.truthy(state.lastBody:find("/use 16", 1, true), "body applies the main-hand enchant")
    t.truthy(state.lastBody:find("6201", 1, true), "body references the bladed pick")
end)

test("Pipeline.RecomputeOne ignores a category that does not exist", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Pipeline.RecomputeOne("NOT_A_CATEGORY", nil, "test"), nil, "no write, no error")
end)

test("Pipeline.RecomputeOne routes a composite category to the composite writer", function(t)
    local KCM = h.loader.loadPure()
    local seen
    KCM.MacroManager.SetCompositeMacro = function(cat) seen = cat.key; return "created" end
    KCM.Pipeline.RecomputeOne("HP_AIO", nil, "test")
    t.eq(seen, "HP_AIO", "composites assemble from their parts, never from their own bag set")
end)

test("Pipeline.RecomputeOne asks for a pick per hand on a per-hand category", function(t)
    local KCM = h.loader.loadPure()
    local slots = {}
    KCM.Selector.PickBestForSlot = function(_, slot) slots[#slots + 1] = slot end
    KCM.MacroManager.SetWeaponEnchantMacro = function() return "created" end
    KCM.Pipeline.RecomputeOne("WPN_ENCH", nil, "test")
    t.eqList(slots, { 16, 17 }, "main hand then off hand")
end)

test("Pipeline.Recompute writes one macro per registered category", function(t)
    local KCM = h.loader.loadPure()
    local written = {}
    KCM.MacroManager.SetMacro = function(name) written[name] = true; return "created" end
    KCM.MacroManager.SetCompositeMacro = function(cat) written[cat.macroName] = true; return "created" end
    KCM.MacroManager.SetWeaponEnchantMacro = function(cat) written[cat.macroName] = true; return "created" end

    KCM.Pipeline.Recompute("test")
    for _, cat in ipairs(KCM.Categories.LIST) do
        t.truthy(written[cat.macroName], cat.key .. " was visited in the pass")
    end
end)

test("Pipeline.Recompute isolates a category whose write raises", function(t)
    local KCM = h.loader.loadPure()
    local written = 0
    local realSet = KCM.MacroManager.SetMacro
    KCM.MacroManager.SetMacro = function(name, itemID, catKey)
        if catKey == "FOOD" then error("scorer exploded") end
        written = written + 1
        return realSet(name, itemID, catKey)
    end
    KCM.Pipeline.Recompute("test")
    t.truthy(written >= 1, "one bad category does not abort the other macros (pcall per category)")
end)

test("Pipeline.Recompute refreshes the panel even while the addon is disabled", function(t)
    local KCM = h.loader.loadPure()
    local refreshes = 0
    local target = KCM.NewBusTarget()
    target:RegisterMessage(KCM.MSG.PANEL_REFRESH, function() refreshes = refreshes + 1 end)

    KCM.db.profile.enabled = false
    KCM.Pipeline.Recompute("test")
    t.eq(refreshes, 1,
        "priority rows still hydrate from item-info events while macro writes are off")
end)

test("Pipeline.Recompute is a no-op before the category table has loaded", function(t)
    local KCM = h.loader.loadPure()
    local saved = KCM.Categories
    KCM.Categories = nil
    KCM.Pipeline.Recompute("test")
    KCM.Categories = saved
    t.truthy(true, "a very early recompute does not raise")
end)

test("Pipeline.CalcSummary renders the reason and the rewrite/skip tally", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Pipeline.CalcSummary("equip", 2, 13, 11), "reason=equip rewrote 2/13 (skipped 11)",
        "the debug line shape the Calc tag emits")
    t.eq(KCM.Pipeline.CalcSummary(nil, 0, 0, 0), "reason=nil rewrote 0/0 (skipped 0)",
        "a missing reason still renders rather than raising")
end)

test("Pipeline.RunAutoDiscovery leaves a seeded item out of the discovered set", function(t)
    local KCM, mock = load()
    local seeded
    for _, id in ipairs(KCM.SEED.FOOD) do
        if KCM.ID.IsItem(id) then seeded = id; break end
    end
    mock.setItem(seeded, { subType = "Food & Drink", tt = { healValue = 100 } })
    mock.setBag(seeded, 1)
    KCM.Pipeline.RunAutoDiscovery("test")
    t.eq(KCM.Selector.GetBucket("FOOD").discovered[seeded], nil,
        "an item already in the shipped seed is not re-recorded as a discovery")
end)

test("Pipeline.RunAutoDiscovery reports zero when nothing new is in bags", function(t)
    local KCM = load()
    t.eq(KCM.Pipeline.RunAutoDiscovery("test"), 0, "empty bags discover nothing")
end)

-- Swap the callable KCM.Debug sink for a recorder. Debug is a table with a
-- __call metamethod plus an IsOn probe, and runAutoDiscovery reads both, so the
-- stand-in has to carry both.
local function recordDebug(KCM)
    local lines = {}
    -- loadPure stops short of the modules that create KCM.State, and the
    -- discovery log gate reads it directly.
    KCM.State = KCM.State or {}
    KCM.State.debug = true
    KCM.Debug = setmetatable({ IsOn = function() return true end }, {
        __call = function(_, tag, fmt) lines[#lines + 1] = tag .. "|" .. tostring(fmt) end,
    })
    return lines
end

local function findLine(lines, needle)
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then return true end
    end
    return false
end

test("discovery reports through the bulk summary, not per item, on a bag pass", function(t)
    local KCM, mock = load()
    ownFood(mock, 900011)
    local lines = recordDebug(KCM)
    KCM.Pipeline.RunAutoDiscovery("test")
    t.truthy(findLine(lines, "scanned %s items"),
        "the bulk pass emits one summary line")
    t.falsy(findLine(lines, "discovered %s id=%s"),
        "and collects into outNew instead of printing a line per item")
end)

test("discovery prints a per-item line for a standalone item-info retry", function(t)
    local KCM, mock = load()
    ownFood(mock, 900012)
    local lines = recordDebug(KCM)
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 900012, true)
    t.truthy(findLine(lines, "discovered %s id=%s"),
        "with no outNew accumulator the retry path reports the item itself")
end)

test("discovery stays silent for a bag item that matches no category", function(t)
    local KCM, mock = load()
    mock.setItem(900013, { subType = "Junk" })
    mock.setBag(900013, 1)
    local lines = recordDebug(KCM)
    KCM:OnItemInfoReceived("GET_ITEM_INFO_RECEIVED", 900013, true)
    t.falsy(findLine(lines, "discovered %s id=%s"),
        "zero-hit items are the common case and are never logged per item")
end)

-- ---------------------------------------------------------------------------
-- ResetAllToDefaults
-- ---------------------------------------------------------------------------

test("ResetAllToDefaults wipes category customizations back to the shipped state", function(t)
    local KCM = h.loader.loadPure()
    KCM.Selector.AddItem("FOOD", 950001)
    KCM.Selector.Block("FOOD", 950002)
    KCM.ResetAllToDefaults("test")
    local bucket = KCM.Selector.GetBucket("FOOD")
    t.eq(bucket.added[950001], nil, "added items are cleared")
    t.eq(bucket.blocked[950002], nil, "blocks are cleared")
end)

test("ResetAllToDefaults clears stat-priority overrides and re-enables the addon", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.statPriority["7_263"] = { primary = "STR" }
    KCM.db.profile.enabled = false
    KCM.ResetAllToDefaults("test")
    t.eq(next(KCM.db.profile.statPriority), nil, "overrides are gone, seeds take over again")
    t.eq(KCM.db.profile.enabled, true, "the master enable is a customization too")
end)

test("ResetAllToDefaults preserves macro state so live macros are not orphaned", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    mock.setItem(950003, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(950003, 1)
    KCM.MacroManager.SetMacro("KCM_FOOD", 950003, "FOOD")
    KCM.ResetAllToDefaults("test")
    t.truthy(KCM.db.profile.macroState["KCM_FOOD"], "the macro the user has on their bars is kept")
end)

test("ResetAllToDefaults rediscovers what is still in bags", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    mock.setItem(950004, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(950004, 1)
    KCM.ResetAllToDefaults("test")
    local found = false
    for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
        if id == 950004 then found = true end
    end
    t.truthy(found, "the wiped discovered set is refilled in the same pass, not left empty")
end)

test("ResetAllToDefaults reports whether it mutated anything", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.ResetAllToDefaults("test"), true, "a real reset reports true")
    local saved = KCM.db
    KCM.db = nil
    local result = KCM.ResetAllToDefaults("test")
    KCM.db = saved
    t.eq(result, false, "with no DB there is nothing to reset")
end)

test("ResetAllToDefaults keeps the addon on when the defaults have no enabled key", function(t)
    -- The fail-safe is the READER's, not the reset's: `macrosEnabled` is
    -- `not (... enabled == false)`, so nil means ON. That is the shape
    -- savedvariables asks for -- `== nil` rather than `or`, because the falsy
    -- state is a user choice -- and it is why the reset no longer has to write a
    -- `true` of its own. Since options-ui-§12 the reset is `db:ResetProfile()`,
    -- and what it stores is whatever the defaults table holds: nothing, here.
    --
    -- Asserted on the BEHAVIOR rather than on the stored byte, because the stored
    -- byte is what changed and the behavior is what the case was always about.
    -- red under: a reader that treats nil as off.
    local KCM = h.loader.loadPure()
    KCM.dbDefaults.profile.enabled = nil
    KCM.db.profile.enabled = false

    KCM.ResetAllToDefaults("test")

    t.eq(KCM.db.profile.enabled, nil, "the profile mirrors the defaults table exactly")
    -- Reached the way the macro write loop reaches it.
    t.eq(not (KCM.db.profile.enabled == false), true,
        "a missing defaults key is fail-safe (addon on), not fail-off")
end)

test("ResetAllToDefaults runs invalidate then discover then recompute, in that order", function(t)
    local KCM = h.loader.loadPure()
    local order = {}
    KCM.TooltipCache.InvalidateAll   = function() order[#order + 1] = "invalidate" end
    KCM.Pipeline.RunAutoDiscovery    = function() order[#order + 1] = "discover" end
    KCM.Pipeline.Recompute           = function() order[#order + 1] = "recompute" end
    KCM.ResetAllToDefaults("test")
    t.eqList(order, { "invalidate", "discover", "recompute" },
        "discovery must see a cleared cache and recompute the refreshed set")
end)

test("ResetAllToDefaults copies the defaults rather than aliasing them", function(t)
    local KCM = h.loader.loadPure()
    KCM.ResetAllToDefaults("test")
    t.ne(KCM.db.profile.categories, KCM.dbDefaults.profile.categories,
        "the live table is a copy, so a later edit cannot corrupt the defaults")
end)

test("ResetAllToDefaults leaves the category buckets structurally valid", function(t)
    local KCM = h.loader.loadPure()
    KCM.ResetAllToDefaults("test")
    for _, cat in ipairs(KCM.Categories.LIST) do
        t.truthy(KCM.db.profile.categories[cat.key],
            cat.key .. " still has its bucket after the wipe")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§12 — the global reset sweeps the SESSION-ONLY rows
-- ---------------------------------------------------------------------------
--
-- A profile reset by construction cannot reach a row whose storage is its own
-- `set()`. `state.debugConsole` is that row: settings/Panel.lua's SESSION_PATHS
-- answers it out of the console's own visibility, not out of db.profile, so
-- `db:ResetProfile()` leaves it exactly as it found it and a console the player
-- opened outlives a reset that took everything around it. §12 makes restoring
-- those rows by hand a MUST, and restoreSessionRows is where it happens.
--
-- Pinned on ResetAllToDefaults rather than on either door, because that is the
-- point of putting the sweep there: the Master controls tab's [Reset all
-- settings] and `/cm resetall` are the same act and cannot drift apart.
--
-- red under: deleting the restoreSessionRows() call from KCM.ResetAllToDefaults,
-- dropping `debugConsole = false` from settings/General.lua's composer spec (the
-- composer emits the row with no default of its own), or moving the sweep after
-- db:ResetProfile() -- the last one still passes here but is caught by the
-- ordering case below.
test("ResetAllToDefaults restores the session-only rows a profile reset cannot reach",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local H = KCM.Settings.Helpers

        -- A console DOUBLE, because the row's visibility is the one thing the
        -- headless frame stub cannot answer: its IsShown is a chaining no-op that
        -- reports truthy forever once a frame exists, so reading the row back
        -- through the real console would pass whatever the sweep did. The double
        -- is resolved by settings/Panel.lua's SESSION_PATHS at CALL time, so it is
        -- the same seam a live client takes. Unknown members answer a no-op, so a
        -- debug line emitted during the reset cannot raise through it.
        local shown = false
        local realDL = KCM.DebugLog
        KCM.DebugLog = setmetatable({
            Show          = function() shown = true end,
            Hide          = function() shown = false end,
            IsWindowShown = function() return shown end,
        }, { __index = function() return function() end end })

        H.Set("state.debugConsole", true)
        KCM.db.profile.macroBar.buttonSize = 99
        t.eq(shown, true, "the console is open going in")

        KCM.ResetAllToDefaults("test")
        KCM.DebugLog = realDL

        t.eq(shown, false,
            "the session-only row is restored row by row, not left standing")
        t.eq(KCM.db.profile.macroBar.buttonSize, 36,
            "and the profile half is still the AceDB reset it always was")
    end)

-- The sweep runs BEFORE db:ResetProfile, for the reason the library orders its own
-- RestoreAllDefaults the same way (libs/LibKa0s/Options.lua): ResetProfile fires
-- OnProfileReset, whose handler repaints every panel, and a sweep afterwards would
-- be writing into a panel already drawn from the pre-reset value.
--
-- red under: moving restoreSessionRows() below KCM.db:ResetProfile().
test("ResetAllToDefaults sweeps the session rows before it resets the profile", function(t)
    local KCM = h.loader.loadFullAddon()
    local order = {}

    local realSet = KCM.Settings.Helpers.Set
    KCM.Settings.Helpers.Set = function(path, value)
        if path == "state.debugConsole" then order[#order + 1] = "sweep" end
        return realSet(path, value)
    end
    local realReset = KCM.db.ResetProfile
    KCM.db.ResetProfile = function(...)
        order[#order + 1] = "resetProfile"
        return realReset(...)
    end

    KCM.ResetAllToDefaults("test")

    KCM.Settings.Helpers.Set = realSet
    KCM.db.ResetProfile      = realReset
    t.eqList(order, { "sweep", "resetProfile" },
        "the session rows are restored first, then the profile is wiped")
end)
