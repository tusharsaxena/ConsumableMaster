-- test_seedprobe.lua -- the seed probe (`/cm probe seed ...`, core/SeedProbe.lua and
-- core/SeedProbeStore.lua; docs/seed-probe.md).
--
-- Each case loads the whole addon, enables it, and then lays a small fake world
-- over the client: the hovered item, a merchant, a replicate list with cold and
-- warm items, and their tooltips. C_Timer.After is replaced by a queue, so a case
-- steps the probe one frame at a time and can count the frames a job took.
-- Every global the world sets is put back afterwards, pass or fail.

local h = _G.KCM_TEST
local test = h.test

-- The globals a world sets that mock.install does not rebuild on the next load.
local TOUCHED = {
    "C_Timer", "GameTooltip", "C_TooltipInfo", "C_AuctionHouse", "C_MerchantFrame", "C_Map",
    "GetMerchantNumItems", "GetMerchantItemID", "GetMerchantItemLink", "GetMerchantItemCostInfo",
    "GetMerchantItemCostItem", "GetRealZoneText", "UnitGUID", "UnitName", "issecretvalue",
    "ConsumableMasterProbeDB",
}

-- ---------------------------------------------------------------------------
-- The fake world
-- ---------------------------------------------------------------------------

local function newTimers()
    local T = { q = {} }
    _G.C_Timer = { After = function(delay, fn) T.q[#T.q + 1] = { d = delay, fn = fn } end }
    -- One frame: run the zero-delay callbacks queued before it. Answers how many ran.
    function T.frame()
        local due, keep = {}, {}
        for _, e in ipairs(T.q) do
            if e.d == 0 then due[#due + 1] = e else keep[#keep + 1] = e end
        end
        T.q = keep
        for _, e in ipairs(due) do e.fn() end
        return #due
    end
    -- Frames until nothing zero-delay is left. Answers the frame count.
    function T.drain()
        local frames = 0
        while T.frame() > 0 do
            frames = frames + 1
            assert(frames < 1000, "the probe never settled")
        end
        return frames
    end
    -- Let `seconds` pass: run every delayed callback due by then, then drain.
    function T.elapse(seconds)
        local due, keep = {}, {}
        for _, e in ipairs(T.q) do
            if e.d > 0 and e.d <= seconds then due[#due + 1] = e else keep[#keep + 1] = e end
        end
        T.q = keep
        for _, e in ipairs(due) do e.fn() end
        T.drain()
        return #due
    end
    function T.delayed()
        local n = 0
        for _, e in ipairs(T.q) do if e.d > 0 then n = n + 1 end end
        return n
    end
    return T
end

local function buildWorld(KCM, mock)
    local W = { items = {}, cold = {}, requested = {}, hover = nil, tipShown = true,
                merchant = nil, ah = {}, replicateCalls = 0 }
    W.timers = newTimers()

    -- Items: name, subType (drives classID), a Use: line, and the full GetItemInfo returns.
    function W.item(id, spec)
        spec = spec or {}
        mock.setItem(id, { name = spec.name or ("Item " .. id), subType = spec.subType or "Potion",
            classID = spec.classID, subClassID = spec.subClassID })
        W.items[id] = {
            name = spec.name or ("Item " .. id),
            lines = spec.lines or { { leftText = spec.name or ("Item " .. id) },
                                    { leftText = "Use: Restores 1000 health.", rightText = "" } },
            spellID = spec.spellID or (90000 + id % 1000),
        }
        if spec.cold then W.cold[id] = true end
    end

    local baseInfo = _G.C_Item.GetItemInfo
    local function itemInfo(id)
        if not W.items[id] then return baseInfo(id) end
        if W.cold[id] then return nil end
        local it = mock.items[id]
        return W.items[id].name, "|Hitem:" .. id .. "|h[" .. W.items[id].name .. "]|h", it.quality, 42, 10,
            "Consumable", it.subType, 20, "", "icon:" .. id, 25
    end
    _G.C_Item.GetItemInfo = itemInfo
    _G.C_Item.GetItemSpell = function(id)
        local it = W.items[id]
        if not it or W.cold[id] then return nil end
        return "Spell of " .. it.name, it.spellID
    end
    _G.C_Item.RequestLoadItemDataByID = function(id) W.requested[#W.requested + 1] = id end
    _G.C_Spell.GetSpellDescription = function(spellID) return "Heals you. (" .. spellID .. ")" end
    _G.C_TooltipInfo = {
        GetItemByID = function(id)
            local it = W.items[id]
            if not it or W.cold[id] then return nil end
            return { lines = it.lines }
        end,
    }

    -- Arrival of a cold item's data: it warms and the client says so.
    function W.arrive(id)
        W.cold[id] = nil
        mock.base.__fireEvent("GET_ITEM_INFO_RECEIVED", id, true)
    end

    _G.GameTooltip = {
        IsShown = function() return W.tipShown end,
        GetItem = function()
            local id = W.hover
            if not id then return nil end
            return W.items[id] and W.items[id].name, "|Hitem:" .. id .. "::::|h[x]|h", id
        end,
    }

    -- A merchant: { guid, name, rows = { { id, price, stack, avail, cost } } }.
    function W.openMerchant(m)
        W.merchant = m
        mock.base.__fireEvent("MERCHANT_SHOW")
    end
    function W.closeMerchant()
        mock.base.__fireEvent("MERCHANT_CLOSED")
        W.merchant = nil
    end
    local function row(i) return W.merchant and W.merchant.rows[i] end
    _G.GetMerchantNumItems = function() return W.merchant and #W.merchant.rows or 0 end
    _G.GetMerchantItemID = function(i) return row(i) and row(i).id end
    _G.GetMerchantItemLink = function(i) return row(i) and ("|Hitem:" .. row(i).id .. "|h[v]|h") end
    _G.GetMerchantItemCostInfo = function(i) return row(i) and row(i).cost and #row(i).cost or 0 end
    _G.GetMerchantItemCostItem = function(i, j)
        local c = row(i).cost[j]
        return "tex", c.value, c.link, c.name
    end
    _G.C_MerchantFrame = {
        GetItemInfo = function(i)
            local r = row(i)
            return { name = "v", texture = 1, price = r.price or 0, stackCount = r.stack or 1,
                     numAvailable = r.avail or -1, isPurchasable = true, isUsable = true,
                     hasExtendedCost = r.cost ~= nil, currencyID = nil }
        end,
    }
    _G.UnitGUID = function(unit) return unit == "npc" and W.merchant and W.merchant.guid or nil end
    local baseName = _G.UnitName
    _G.UnitName = function(unit)
        if unit == "npc" then return W.merchant and W.merchant.name end
        return baseName(unit)
    end
    _G.GetRealZoneText = function() return "Elwynn Forest" end
    _G.C_Map = { GetBestMapForUnit = function() return 37 end }

    -- The auction house: W.ah is the replicate list, 0-indexed by the client.
    _G.C_AuctionHouse = {
        ReplicateItems = function() W.replicateCalls = W.replicateCalls + 1 end,
        GetNumReplicateItems = function() return #W.ah end,
        GetReplicateItemInfo = function(index)
            local l = W.ah[index + 1]
            return "n", 1, l.count, 1, true, 1, nil, 0, 0, l.buyout, 0, nil, nil, "o", "o", 0, l.id,
                l.hasAllInfo ~= false
        end,
    }
    function W.openAH() mock.base.__fireEvent("AUCTION_HOUSE_SHOW") end
    function W.closeAH() mock.base.__fireEvent("AUCTION_HOUSE_CLOSED") end
    function W.listReady() mock.base.__fireEvent("REPLICATE_ITEM_LIST_UPDATE") end

    function W.run(line)
        mock.output = {}
        KCM:OnSlashCommand(line)
        return mock.output
    end
    function W.store() return _G.ConsumableMasterProbeDB end
    function W.rec(id) return _G.ConsumableMasterProbeDB.items[id] end
    function W.said(pattern)
        for _, l in ipairs(mock.output) do
            if tostring(l):find(pattern, 1, true) then return l end
        end
        return nil
    end
    return W
end

-- One case: a fresh addon, enabled, with the world laid over it; the touched
-- globals are restored afterwards whatever happened.
local function case(name, fn)
    test(name, function(t)
        local saved = {}
        for _, g in ipairs(TOUCHED) do saved[g] = { v = _G[g] } end
        _G.ConsumableMasterProbeDB = nil
        local ok, err = pcall(function()
            local KCM = h.loader.loadFullAddon()
            local mock = h.loader.mock
            KCM:OnEnable()
            fn(t, KCM, buildWorld(KCM, mock), mock)
        end)
        for _, g in ipairs(TOUCHED) do _G[g] = saved[g].v end
        if not ok then error(err, 0) end
    end)
end

-- ---------------------------------------------------------------------------
-- The store
-- ---------------------------------------------------------------------------

case("Probe store: its own global, built at initialize with schema 1, never inside AceDB", function(t, KCM, W)
    local db = W.store()
    t.truthy(type(db) == "table", "ConsumableMasterProbeDB exists after OnInitialize")
    t.eq(db.schemaVersion, 1, "schema version 1")
    t.eq(next(db.items), nil, "and no items")
    t.falsy(KCM.db.sv and KCM.db.sv.items, "AceDB's tree carries none of it")
end)

test("Probe store: the TOC declares ConsumableMasterProbeDB third", function(t)
    local root = _G.KCM_TEST_ROOT or "."
    local f = assert(io.open(root .. "/ConsumableMaster.toc", "r"))
    local line
    for l in f:lines() do
        if l:match("^## SavedVariables:") then line = l:gsub("\r$", "") end
    end
    f:close()
    t.eq(line, "## SavedVariables: ConsumableMasterDB, ConsumableMasterPerfDB, ConsumableMasterProbeDB",
        "the three globals, in order")
end)

case("Probe store: a broken store is rebuilt, not raised on", function(t, _, W)
    _G.ConsumableMasterProbeDB = { schemaVersion = 1, items = "oops" }
    W.item(171001, { name = "Mended Draught" })
    W.hover = 171001
    W.run("probe seed mouseover")
    t.truthy(W.rec(171001), "the item was recorded into a rebuilt items table")
end)

-- ---------------------------------------------------------------------------
-- mouseover
-- ---------------------------------------------------------------------------

case("Probe mouseover: records every field the item dump shows, and acks in chat", function(t, KCM, W, mock)
    W.item(171002, { name = "Mended Draught", spellID = 90123 })
    W.hover = 171002
    local out = W.run("probe seed mouseover")
    local rec = W.rec(171002)
    t.truthy(rec, "recorded")
    local hits = KCM.Classifier.MatchAny(171002)
    t.eq(#out, 1, "one chat line: " .. table.concat(out, " | "))
    t.truthy(out[1]:find(("probed Mended Draught (171002): %s"):format(
        #hits > 0 and table.concat(hits, ", ") or "(none)"), 1, true), "the ack names the item and its categories")
    -- identity
    t.eq(rec.id, 171002, "id")
    t.eq(rec.name, "Mended Draught", "name")
    t.truthy(tostring(rec.link):find("item:171002", 1, true), "link")
    t.eq(rec.client, KCM.Compat.ClientKey(), "client")
    t.truthy(rec.version ~= nil and rec.build ~= nil, "version and build from GetBuildInfo")
    t.eq(type(rec.interface), "number", "the interface number from GetBuildInfo")
    -- instant + item info
    t.eq(rec.classID, 0, "classID")
    t.eq(rec.subClassID, mock.items[171002].subClassID, "subClassID")
    t.eq(rec.type, "Consumable", "type")
    t.eq(rec.subType, "Potion", "subType")
    t.eq(rec.quality, 1, "quality")
    t.eq(rec.itemLevel, 42, "itemLevel")
    t.eq(rec.minLevel, 10, "minLevel")
    t.eq(rec.stackCount, 20, "stackCount")
    t.eq(rec.sellPrice, 25, "sellPrice")
    t.truthy(rec.icon ~= nil, "icon")
    -- use effect
    t.eq(rec.spellID, 90123, "spellID")
    t.eq(rec.spellName, "Spell of Mended Draught", "spellName")
    t.eq(rec.spellDescription, "Heals you. (90123)", "spell description")
    -- tooltip, parse, classifier, usability
    t.eq(#rec.tooltip, 2, "both raw tooltip lines")
    t.eq(rec.tooltip[2].left, "Use: Restores 1000 health.", "the raw Use: line")
    t.falsy(rec.tooltip[2].right, "an empty right side is not kept")
    t.eq(rec.parsed.healValue, 1000, "the parsed entry")
    t.truthy(rec.parsed ~= KCM.TooltipCache.Get(171002), "copied, not the cache's own table")
    t.eqList(rec.classified, hits, "what the Classifier makes of it")
    t.eq(rec.usable, true, "the usability verdict")
    -- who and when
    t.eq(rec.seenBy.level, 80, "the character's level")
    t.eq(rec.seenBy.classID, select(1, KCM.SpecHelper.GetCurrent()), "the character's class")
    t.eq(rec.seenBy.specKey, select(3, KCM.SpecHelper.GetCurrent()), "the spec key")
    t.eq(rec.sources.mouseover.count, 1, "the mouseover source")
    t.truthy(rec.firstSeen and rec.lastSeen, "firstSeen and lastSeen")
    t.falsy(rec.pending, "complete")
end)

case("Probe mouseover: any item class is recorded, because the player pointed at it", function(t, _, W)
    W.item(171003, { name = "Rusty Helm", subType = "Plate", classID = 4, subClassID = 4 })
    W.hover = 171003
    W.run("probe seed mouseover")
    t.eq(W.rec(171003).classID, 4, "an armor item is recorded")
end)

case("Probe mouseover: a second probe refreshes the record and counts, firstSeen kept", function(t, _, W)
    W.item(171004, { name = "Mended Draught" })
    W.hover = 171004
    W.run("probe seed mouseover")
    local first = W.rec(171004).firstSeen
    W.items[171004].name = "Mended Draught II"
    W.run("probe seed mouseover")
    local rec = W.rec(171004)
    t.eq(rec.sources.mouseover.count, 2, "the count")
    t.eq(rec.firstSeen, first, "firstSeen is kept")
    t.eq(rec.name, "Mended Draught II", "the identity is refreshed")
end)

case("Probe mouseover: nothing under the mouse is one refusal line and no record", function(t, _, W)
    W.item(171005)
    W.hover = nil
    local out = W.run("probe seed mouseover")
    t.eq(#out, 1, "one line")
    t.truthy(out[1]:find("no item under the mouse", 1, true), "the refusal")
    W.hover, W.tipShown = 171005, false
    out = W.run("probe seed mouseover")
    t.truthy(out[1]:find("no item under the mouse", 1, true), "a hidden tooltip is no item either")
    t.eq(next(W.store().items), nil, "nothing recorded")
end)

case("Probe mouseover: a secret value from the tooltip is never stored or concatenated", function(t, _, W, mock)
    W.item(171006)
    mock.setCooldownsRestricted(true)   -- turns issecretvalue on for mock.secret values
    _G.GameTooltip.GetItem = function() return mock.secret("n"), mock.secret("l"), mock.secret(171006) end
    local out = W.run("probe seed mouseover")
    t.truthy(out[1]:find("no item under the mouse", 1, true), "a secret id reads as no item")
    t.eq(next(W.store().items), nil, "nothing recorded")
end)

case("Probe mouseover: a cold item is requested and completes when its data arrives", function(t, _, W)
    W.item(171007, { name = "Cold Brew", cold = true })
    W.hover = 171007
    local out = W.run("probe seed mouseover")
    t.truthy(out[1]:find("(loading", 1, true), "the ack says it is loading: " .. out[1])
    t.truthy(W.rec(171007).pending, "the record is pending")
    t.eqList(W.requested, { 171007 }, "the item was requested once")
    W.arrive(171007)
    W.timers.drain()
    local rec = W.rec(171007)
    t.falsy(rec.pending, "complete after GET_ITEM_INFO_RECEIVED")
    t.eq(rec.name, "Cold Brew", "with its name")
    t.eq(#rec.tooltip, 2, "and its tooltip")
end)

case("Probe mouseover: a body that never arrives is re-read a bounded number of times", function(t, _, W)
    W.item(171008, { cold = true })
    W.hover = 171008
    W.run("probe seed mouseover")
    local sweeps = 0
    for _ = 1, 10 do
        if W.timers.elapse(2) == 0 then break end
        sweeps = sweeps + 1
    end
    t.eq(sweeps, 4, "three re-read sweeps and the one that gives up")
    t.eq(W.timers.delayed(), 0, "no timer is left armed")
    t.truthy(W.rec(171008).pending, "the record is left marked pending")
end)

-- ---------------------------------------------------------------------------
-- vendor
-- ---------------------------------------------------------------------------

local FARLEY = "Creature-0-3110-0-47-295-00001A2B3C"

case("Probe vendor: refused with no merchant open, before and after a visit", function(t, _, W)
    local out = W.run("probe seed vendor")
    t.eq(#out, 1, "one line")
    t.truthy(out[1]:find("no merchant open", 1, true), "the refusal")
    W.openMerchant({ guid = FARLEY, name = "Innkeeper Farley", rows = {} })
    W.closeMerchant()
    out = W.run("probe seed vendor")
    t.truthy(out[1]:find("no merchant open", 1, true), "refused again once the merchant closed")
end)

case("Probe vendor: every consumable with the vendor's NPC, name, zone, price and supply; the rest counted", function(t, _, W)
    W.item(4592, { name = "Longjaw Mud Snapper", subType = "Food & Drink" })
    W.item(4593, { name = "Bristle Whisker Catfish", subType = "Food & Drink" })
    W.item(4594, { name = "Rockscale Cod", subType = "Food & Drink" })
    W.item(2901, { name = "Mining Pick", subType = "Mining", classID = 7, subClassID = 7 })
    W.item(2902, { name = "Old Shirt", subType = "Cloth", classID = 4, subClassID = 1 })
    W.openMerchant({ guid = FARLEY, name = "Innkeeper Farley", rows = {
        { id = 4592, price = 25, stack = 5 },
        { id = 2901, price = 80 },
        { id = 4593, price = 50, stack = 1, avail = 3 },
        { id = 2902, price = 10 },
        { id = 4594, price = 0, cost = { { value = 2, link = "|Hcurrency:1|h", name = "Badge" } } },
    } })
    W.run("probe seed vendor")
    W.timers.drain()
    t.truthy(W.said("vendor Innkeeper Farley: 3 consumables recorded, 2 skipped"),
        "the ack: " .. table.concat(h.loader.mock.output, " | "))
    t.falsy(W.rec(2901) or W.rec(2902), "the non-consumables are not recorded")
    local v = W.rec(4592).sources.vendor[295]
    t.truthy(v, "the row is keyed by the NPC ID out of the GUID")
    t.eq(v.name, "Innkeeper Farley", "the vendor's name")
    t.eq(v.zone, "Elwynn Forest", "the zone")
    t.eq(v.mapID, 37, "the map")
    t.eq(v.price, 25, "the price")
    t.eq(v.stackCount, 5, "the stack size")
    t.falsy(v.limited, "unlimited supply")
    local limited = W.rec(4593).sources.vendor[295]
    t.eq(limited.numAvailable, 3, "limited supply's count")
    t.eq(limited.limited, true, "and the flag")
    local cost = W.rec(4594).sources.vendor[295].extendedCost
    t.eq(cost and cost[1].value, 2, "the extended cost")
    t.eq(cost and cost[1].name, "Badge", "names its currency")
end)

case("Probe vendor: the fill is time-sliced, FILL_BATCH records a frame", function(t, KCM, W)
    local rows = {}
    for i = 1, 60 do
        W.item(180000 + i, { subType = "Food & Drink" })
        rows[i] = { id = 180000 + i, price = 1 }
    end
    W.openMerchant({ guid = FARLEY, name = "Innkeeper Farley", rows = rows })
    W.run("probe seed vendor")
    t.eq(next(W.store().items), nil, "nothing captured in the command's own frame")
    W.timers.frame()
    local n = 0
    for _ in pairs(W.store().items) do n = n + 1 end
    t.eq(n, KCM.SeedProbe.FILL_BATCH, "one batch in the first frame")
    local frames = W.timers.drain()
    t.eq(frames, 2, "the other 35 take two more frames")
    t.truthy(W.said("60 consumables recorded, 0 skipped"), "and the ack comes at the end")
end)

-- ---------------------------------------------------------------------------
-- Merge across sources
-- ---------------------------------------------------------------------------

local function scanNow(W)
    W.openAH()
    W.run("probe seed auctionhouse")
    W.listReady()
    W.timers.drain()
end

case("Probe merge: one item seen by mouseover, two vendors and the auction house keeps every source", function(t, _, W)
    W.item(4592, { name = "Longjaw Mud Snapper", subType = "Food & Drink" })
    W.hover = 4592
    W.run("probe seed mouseover")
    W.openMerchant({ guid = FARLEY, name = "Innkeeper Farley", rows = { { id = 4592, price = 25 } } })
    W.run("probe seed vendor")
    W.timers.drain()
    W.closeMerchant()
    W.openMerchant({ guid = "Creature-0-3110-0-47-6740-0000", name = "Innkeeper Allison",
        rows = { { id = 4592, price = 30 } } })
    W.run("probe seed vendor")
    W.timers.drain()
    W.ah = { { id = 4592, count = 5, buyout = 500 } }
    scanNow(W)
    local s = W.rec(4592).sources
    t.eq(s.mouseover.count, 1, "mouseover")
    t.eq(s.vendor[295].price, 25, "the first vendor")
    t.eq(s.vendor[6740].price, 30, "the second vendor")
    t.eq(s.auctionhouse.listings, 1, "the auction house")
end)

-- ---------------------------------------------------------------------------
-- auctionhouse
-- ---------------------------------------------------------------------------

case("Probe AH: closed, the command arms a scan; opening starts it, the walk is time-sliced", function(t, KCM, W)
    W.item(5001, { subType = "Potion" })
    W.item(5002, { subType = "Potion", cold = true })
    W.item(5003, { subType = "Plate", classID = 4, subClassID = 4 })
    local list = {}
    for i = 1, 1200 do
        local pick = (i % 3 == 0) and 5003 or ((i % 3 == 1) and 5001 or 5002)
        list[i] = { id = pick, count = 2, buyout = 100 * i, hasAllInfo = pick ~= 5002 }
    end
    W.ah = list
    local out = W.run("probe seed auctionhouse")
    t.truthy(out[1]:find("armed", 1, true), "armed: " .. out[1])
    t.eq(W.replicateCalls, 0, "no scan with the auction house closed")
    W.openAH()
    t.eq(W.replicateCalls, 1, "opening it requests the one full scan")
    t.truthy(KCM.__events and KCM.__events.REPLICATE_ITEM_LIST_UPDATE, "the list event is registered while owed")
    W.listReady()
    t.falsy(KCM.__events.REPLICATE_ITEM_LIST_UPDATE, "and dropped the moment it fires")
    local walkFrames = 0
    while KCM.SeedProbe.__state.scan == "walking" do
        W.timers.frame()
        walkFrames = walkFrames + 1
    end
    t.eq(walkFrames, math.ceil(1200 / KCM.SeedProbe.WALK_BATCH), "one WALK_BATCH a frame")
    W.timers.drain()
    local warm = W.rec(5001).sources.auctionhouse
    t.eq(warm.listings, 400, "listings per item")
    t.eq(warm.quantity, 800, "quantity per item")
    t.eq(warm.minBuyout, 50, "the lowest unit buyout")
    t.falsy(W.rec(5003), "a non-consumable listing is not recorded")
    t.truthy(W.rec(5002).pending, "a cold listing is recorded pending")
    t.truthy(W.said("2 consumables recorded from 1200 listings, 1 still loading"),
        "the end line: " .. table.concat(h.loader.mock.output, " | "))
    W.arrive(5002)
    W.timers.drain()
    t.falsy(W.rec(5002).pending, "the cold item completes when it loads")
    t.eq(#W.rec(5002).tooltip, 2, "with its tooltip")
end)

case("Probe AH: open, the command scans now; a second command while it runs is refused", function(t, _, W)
    W.item(5001)
    W.ah = { { id = 5001, count = 1, buyout = 10 } }
    W.openAH()
    W.run("probe seed auctionhouse")
    t.eq(W.replicateCalls, 1, "scanned now")
    local out = W.run("probe seed auctionhouse")
    t.truthy(out[1]:find("already running", 1, true), "busy: " .. out[1])
    t.eq(W.replicateCalls, 1, "not asked twice")
end)

case("Probe AH: within 15 minutes of the last scan the command is refused and never retried", function(t, _, W)
    W.store().lastAuctionScan = time() - 5 * 60
    W.openAH()
    local out = W.run("probe seed auctionhouse")
    t.truthy(out[1]:find("throttled", 1, true), "the refusal: " .. out[1])
    t.eq(W.replicateCalls, 0, "ReplicateItems was not called")
    t.eq(W.timers.delayed(), 0, "and nothing was scheduled to retry")
    W.store().lastAuctionScan = time() - 16 * 60
    W.run("probe seed auctionhouse")
    t.eq(W.replicateCalls, 1, "after the window it scans")
end)

case("Probe AH: a scan whose list never arrives is reported once at the timeout", function(t, KCM, W)
    W.openAH()
    W.run("probe seed auctionhouse")
    W.timers.elapse(KCM.SeedProbe.SCAN_TIMEOUT)
    t.truthy(W.said("no listing arrived"), "the report")
    t.eq(W.replicateCalls, 1, "not retried")
    t.falsy(KCM.__events.REPLICATE_ITEM_LIST_UPDATE, "the list event is dropped")
    t.eq(KCM.SeedProbe.__state.scan, nil, "the scan is over")
    t.eq(W.timers.delayed(), 0, "and nothing is left armed")
end)

case("Probe AH: an empty list is reported, not retried", function(t, KCM, W)
    W.ah = {}
    W.openAH()
    W.run("probe seed auctionhouse")
    W.listReady()
    t.truthy(W.said("came back empty"), "the report")
    t.eq(W.replicateCalls, 1, "not retried")
    t.eq(KCM.SeedProbe.__state.scan, nil, "the scan is over")
end)

case("Probe AH: closing the auction house mid-walk keeps what was read", function(t, KCM, W)
    W.item(5001)
    local list = {}
    for i = 1, 1200 do list[i] = { id = 5001, count = 1, buyout = 10 } end
    W.ah = list
    W.openAH()
    W.run("probe seed auctionhouse")
    W.listReady()
    W.timers.frame()
    W.closeAH()
    W.timers.drain()
    t.truthy(W.said("partial: 500 of 1200 listings read"), "the partial read is named")
    t.eq(W.rec(5001).sources.auctionhouse.listings, 500, "and recorded")
    t.eq(KCM.SeedProbe.__state.scan, nil, "the scan is over")
end)

-- ---------------------------------------------------------------------------
-- status, clear, help
-- ---------------------------------------------------------------------------

case("Probe status: a report in the debug console and one pointer line in chat", function(t, KCM, W)
    W.item(5001)
    W.hover = 5001
    W.run("probe seed mouseover")
    local D = KCM.DebugLog.instance
    local from = #D.buffer
    local out = W.run("probe seed status")
    t.eq(#out, 1, "one chat line: " .. table.concat(out, " | "))
    t.truthy(out[1]:find("probe seed status", 1, true), "the pointer names the report")
    local text = {}
    for i = from + 1, #D.buffer do text[#text + 1] = D.buffer[i] end
    text = table.concat(text, "\n")
    t.truthy(text:find("ConsumableMasterProbeDB, schema 1, 1 items", 1, true), "the store's size")
    t.truthy(text:find("mouseover 1", 1, true), "the sources")
    t.truthy(text:find("auction house scan: idle", 1, true), "the scan state")
end)

case("Probe clear: empties the store, says how many, stops a running probe, keeps the throttle", function(t, KCM, W)
    W.item(5001)
    W.hover = 5001
    W.run("probe seed mouseover")
    W.openAH()
    W.run("probe seed auctionhouse")
    local last = W.store().lastAuctionScan
    local out = W.run("probe seed clear")
    t.truthy(out[1]:find("probe store cleared: 1 items removed; the running probe was stopped", 1, true),
        "the ack: " .. out[1])
    t.eq(next(W.store().items), nil, "empty")
    t.eq(KCM.SeedProbe.__state.scan, nil, "the scan stopped")
    t.eq(W.store().lastAuctionScan, last, "the throttle time survives")
    W.listReady()
    W.timers.drain()
    t.eq(next(W.store().items), nil, "a late list reaches nothing")
end)

case("Probe help: /cm probe and /cm probe seed list the five subcommands; an unknown one is named", function(t, _, W)
    for _, line in ipairs({ "probe", "probe seed", "probe seed help" }) do
        local out = table.concat(W.run(line), "\n")
        for _, sub in ipairs({ "mouseover", "vendor", "auctionhouse", "status", "clear" }) do
            t.truthy(out:find("/cm probe seed " .. sub, 1, true), "/cm " .. line .. " lists " .. sub)
        end
    end
    t.truthy(W.run("probe seed bogus")[1]:find("unknown probe seed subcommand 'bogus'", 1, true), "unknown subcommand")
    t.truthy(W.run("probe other")[1]:find("unknown probe 'other'", 1, true), "unknown probe")
end)

-- ---------------------------------------------------------------------------
-- The addon's state
-- ---------------------------------------------------------------------------

local function profileText(KCM)
    local parts = {}
    local function walk(v, pad)
        if type(v) ~= "table" then parts[#parts + 1] = pad .. tostring(v) return end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = pad .. k
            walk(v[k] ~= nil and v[k] or v[tonumber(k)], pad .. " ")
        end
    end
    walk(KCM.db.profile, "")
    return table.concat(parts, "\n")
end

case("Probe: never touches the profile or the macros", function(t, KCM, W, mock)
    W.item(4592, { subType = "Food & Drink" })
    local before, macros = profileText(KCM), next(mock.macros)
    W.hover = 4592
    W.run("probe seed mouseover")
    W.openMerchant({ guid = FARLEY, name = "Innkeeper Farley", rows = { { id = 4592, price = 25 } } })
    W.run("probe seed vendor")
    W.timers.drain()
    t.eq(profileText(KCM), before, "the profile is unchanged")
    t.eq(next(mock.macros), macros, "no macro was written")
end)

case("Probe: a disabled addon refuses the verb on the one line, and the stand-down stops an armed scan", function(t, KCM, W)
    W.item(5001)
    W.run("probe seed auctionhouse")
    t.eq(KCM.SeedProbe.__state.scan, "armed", "armed")
    W.run("disable")
    t.eq(KCM.SeedProbe.__state.scan, nil, "the stand-down dropped the armed scan")
    W.hover = 5001
    local out = W.run("probe seed mouseover")
    t.eq(#out, 1, "one line")
    t.truthy(out[1]:find(KCM.SlashCommands.instance:DisabledLine(), 1, true), "the dispatcher's refusal line")
    t.eq(next(W.store().items), nil, "nothing recorded")
    W.run("enable")
    W.openAH()
    t.eq(W.replicateCalls, 0, "re-enabled, opening the auction house scans nothing")
end)
