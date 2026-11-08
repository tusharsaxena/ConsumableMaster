-- SeedProbe.lua -- `/cm probe seed mouseover|vendor|auctionhouse|status|clear`.
--
-- The probe records item data for building the seed lists, on Retail and on WoW
-- Forever, into ConsumableMasterProbeDB (core/SeedProbeStore.lua holds the store
-- and the record; docs/seed-probe.md is the player's and the maintainer's page).
-- Slash commands only, no settings panel (the owner's ruling of 2026-11-08).
--
-- WHEN THINGS RUN. Nothing captures until a command asks. Four cheap events are
-- registered with the rest (KCM.EVENTS, core/ConsumableMaster.lua): MERCHANT_SHOW,
-- MERCHANT_CLOSED, AUCTION_HOUSE_SHOW and AUCTION_HOUSE_CLOSED, because `vendor`
-- and `auctionhouse` have to know whether the window is open when they are typed,
-- and no client query answers that as reliably as the events do. Each handler
-- flips one flag, and AUCTION_HOUSE_SHOW starts a scan only when one is armed.
-- REPLICATE_ITEM_LIST_UPDATE is registered only while a scan waits for its list,
-- and dropped the moment it fires.
--
-- TIME-SLICED. The auction-house walk reads WALK_BATCH listings per frame and the
-- capture queue fills FILL_BATCH records per frame, each step scheduled with
-- C_Timer.After(0, ...). There is no OnUpdate. An item whose data has not loaded
-- is requested and re-captured when GET_ITEM_INFO_RECEIVED names it (the hook in
-- KCM:OnItemInfoReceived), with a bounded re-read sweep for a tooltip body that
-- arrives after the event, so a cold auction-house scan still ends with tooltips.
--
-- THE ADDON'S STATE. The probe writes its own store and nothing else. While the
-- addon is disabled `probe` is a feature verb the dispatcher refuses
-- (slash-commands-§2, settings/Slash.lua keeps it off LIVE_VERBS), and the
-- stand-down (core/LifecycleSetup.lua) calls SP.StandDown, which stops any probe
-- in flight. Every scheduled step carries the generation it was started under, so
-- a step left over from a stopped probe does nothing.

local _, NS = ...
local KCM = NS
KCM.SeedProbe = KCM.SeedProbe or {}
local SP = KCM.SeedProbe

-- The printer is a file-scope capture, so this file loads after core/CoreSetup.lua.
local say = KCM.Say

local FILL_BATCH    = 25       -- records captured per frame
local WALK_BATCH    = 500      -- auction-house listings read per frame
local RETRY_DELAY   = 2        -- seconds before a still-loading item is read again
local MAX_ATTEMPTS  = 3        -- re-read sweeps before an item is left pending
local SCAN_TIMEOUT  = 60       -- seconds to wait for the replicate list
local SCAN_THROTTLE = 15 * 60  -- Blizzard allows one full scan per 15 minutes
local REPLICATE_EVENT = "REPLICATE_ITEM_LIST_UPDATE"

SP.FILL_BATCH, SP.WALK_BATCH, SP.SCAN_TIMEOUT = FILL_BATCH, WALK_BATCH, SCAN_TIMEOUT

local clean = SP.Clean

-- Session state. `gen` is bumped by every reset, and a scheduled step that
-- carries an older one returns at once.
local st = {
    gen = 0,
    merchantOpen = false,
    ahOpen = false,
    scan = nil,          -- nil | "armed" | "waiting" | "walking" | "filling"
    walk = nil,
    queue = {}, head = 1, pumpGen = nil,
    pending = {},        -- itemID -> re-read sweeps spent
    sweepGen = nil,
    jobs = 0,
}

local function after(delay, gen, fn)
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(delay, function()
        if gen == st.gen then fn() end
    end)
end

local function classOf(id)
    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(id)
    return clean(classID)
end

local function requestLoad(id)
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

local function dropReplicateEvent()
    if KCM.UnregisterEvent then pcall(KCM.UnregisterEvent, KCM, REPLICATE_EVENT) end
end

-- ---------------------------------------------------------------------------
-- The capture queue
-- ---------------------------------------------------------------------------
--
-- An entry is { id, kind, key, data, job }: capture the item, merge the source
-- (kind/key/data, absent on a re-read), and count it off its job. A job is
-- { left, done }, and `done` runs once its last entry has been captured.

local pump

local function trackLoad(id, complete)
    if complete then
        st.pending[id] = nil
    elseif st.pending[id] == nil then
        st.pending[id] = 0
        requestLoad(id)
    end
end

local function processEntry(e)
    local rec, complete = SP.Capture(e.id, e.link)
    if e.kind then SP.MergeSource(rec, e.kind, e.key, e.data) end
    trackLoad(e.id, complete)
    local job = e.job
    if job then
        job.left = job.left - 1
        if job.left == 0 then
            st.jobs = st.jobs - 1
            job.done()
        end
    end
end

local function schedulePump()
    if st.pumpGen == st.gen then return end
    st.pumpGen = st.gen
    after(0, st.gen, pump)
end

-- The re-read sweep: one timer at a time, armed when the queue drains with items
-- still loading. Each item gets MAX_ATTEMPTS sweeps; after that its record keeps
-- `pending = true` and the probe stops asking.
local function sweep()
    st.sweepGen = nil
    local again = false
    for id, spent in pairs(st.pending) do
        if spent >= MAX_ATTEMPTS then
            st.pending[id] = nil
        else
            st.pending[id] = spent + 1
            st.queue[#st.queue + 1] = { id = id }
            again = true
        end
    end
    if again then schedulePump() end
end

local function armSweep()
    if st.sweepGen == st.gen or next(st.pending) == nil then return end
    st.sweepGen = st.gen
    after(RETRY_DELAY, st.gen, sweep)
end

pump = function()
    st.pumpGen = nil
    local n = 0
    while st.head <= #st.queue and n < FILL_BATCH do
        -- The slot is not cleared: a hole at the front would make #st.queue
        -- undefined. The whole array is dropped once the queue drains.
        local e = st.queue[st.head]
        st.head = st.head + 1
        processEntry(e)
        n = n + 1
    end
    if st.head <= #st.queue then
        schedulePump()
    else
        st.queue, st.head = {}, 1
        armSweep()
    end
end

local function enqueue(entries, done)
    if #entries == 0 then return done() end
    st.jobs = st.jobs + 1
    local job = { left = #entries, done = done }
    for _, e in ipairs(entries) do
        e.job = job
        st.queue[#st.queue + 1] = e
    end
    schedulePump()
end

local function countPending(entries)
    local items, n = SP.Store().items, 0
    for _, e in ipairs(entries) do
        local rec = items[e.id]
        if rec and rec.pending then n = n + 1 end
    end
    return n
end

local function loadingClause(n)
    return n > 0 and (", %d still loading"):format(n) or ""
end

--- GET_ITEM_INFO_RECEIVED, forwarded by KCM:OnItemInfoReceived after the tooltip
--- cache has dropped its entry: an item the probe is waiting on is captured again.
function SP.OnItemInfoReceived(itemID)
    if itemID and st.pending[itemID] ~= nil then
        st.queue[#st.queue + 1] = { id = itemID }
        schedulePump()
    end
end

-- ---------------------------------------------------------------------------
-- Stopping
-- ---------------------------------------------------------------------------

-- Drop every probe in flight. Answers whether anything was running.
local function stopAll()
    local running = st.scan ~= nil or st.jobs > 0 or st.head <= #st.queue
    st.gen = st.gen + 1
    st.scan, st.walk = nil, nil
    st.queue, st.head, st.pumpGen = {}, 1, nil
    st.pending, st.sweepGen, st.jobs = {}, nil, 0
    dropReplicateEvent()
    return running
end

--- The stand-down (core/LifecycleSetup.lua): the events are gone, so the open
--- flags can no longer be trusted, and nothing the probe started may keep running.
function SP.StandDown()
    stopAll()
    st.merchantOpen, st.ahOpen = false, false
end

-- ---------------------------------------------------------------------------
-- mouseover
-- ---------------------------------------------------------------------------

local function hoveredItem()
    local tip = GameTooltip
    if not (tip and tip.GetItem) then return nil end
    if tip.IsShown and not tip:IsShown() then return nil end
    local _, link, id = tip:GetItem()
    link, id = clean(link), clean(id)
    if not id and type(link) == "string" then id = tonumber(link:match("item:(%d+)")) end
    return id, link
end

local function classifiedText(rec)
    if rec.classified and #rec.classified > 0 then return table.concat(rec.classified, ", ") end
    return "(none)"
end

local function probeMouseover()
    local id, link = hoveredItem()
    if not id then
        return say("no item under the mouse: hover an item (bags, a vendor, the auction house or a link), then run /cm probe seed mouseover from a key-bound macro.")
    end
    local rec, complete = SP.Capture(id, link)
    SP.MergeSource(rec, "mouseover")
    trackLoad(id, complete)
    armSweep()
    local tail = complete and "" or " (loading: the record completes when the item data arrives)"
    say(("probed %s (%d): %s%s"):format(rec.name or "item", id, classifiedText(rec), tail))
end

-- ---------------------------------------------------------------------------
-- vendor
-- ---------------------------------------------------------------------------

-- The vendor's NPC ID is the sixth field of a Creature (or Vehicle) GUID.
local function npcIDFromGUID(guid)
    guid = clean(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

local function zoneText()
    local zone = GetRealZoneText and clean(GetRealZoneText())
    if zone == "" then zone = nil end
    local mapID = C_Map and C_Map.GetBestMapForUnit and clean(C_Map.GetBestMapForUnit("player"))
    return zone, mapID
end

local function vendorIdentity()
    local zone, mapID = zoneText()
    return {
        npcID = npcIDFromGUID(UnitGUID and UnitGUID("npc")) or 0,
        name  = (UnitName and clean(UnitName("npc"))) or "unknown vendor",
        zone  = zone,
        mapID = mapID,
    }
end

local function extendedCost(index)
    if not (GetMerchantItemCostInfo and GetMerchantItemCostItem) then return nil end
    local n = clean(GetMerchantItemCostInfo(index)) or 0
    if n == 0 then return nil end
    local costs = {}
    for i = 1, n do
        local _, value, link, currencyName = GetMerchantItemCostItem(index, i)
        costs[#costs + 1] = { value = clean(value), link = clean(link), name = clean(currencyName) }
    end
    return costs
end

local function vendorRow(index, vendor)
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(index) or {}
    local available = clean(info.numAvailable)
    return {
        name = vendor.name, zone = vendor.zone, mapID = vendor.mapID,
        price = clean(info.price), stackCount = clean(info.stackCount),
        numAvailable = available, limited = (available ~= nil and available >= 0) or nil,
        currencyID = clean(info.currencyID),
        extendedCost = clean(info.hasExtendedCost) and extendedCost(index) or nil,
    }
end

local function merchantItemID(index)
    local id = GetMerchantItemID and clean(GetMerchantItemID(index))
    if id then return id end
    local link = GetMerchantItemLink and clean(GetMerchantItemLink(index))
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function probeVendor()
    if not st.merchantOpen then
        return say("no merchant open: talk to a vendor, then run /cm probe seed vendor.")
    end
    local vendor = vendorIdentity()
    local n = GetMerchantNumItems and clean(GetMerchantNumItems()) or 0
    local entries, skipped = {}, 0
    for i = 1, n do
        local id = merchantItemID(i)
        if id and classOf(id) == 0 then
            local link = GetMerchantItemLink and clean(GetMerchantItemLink(i))
            entries[#entries + 1] = { id = id, link = link, kind = "vendor", key = vendor.npcID,
                data = vendorRow(i, vendor) }
        elseif id then
            skipped = skipped + 1
        end
    end
    enqueue(entries, function()
        say(("vendor %s: %d consumables recorded, %d skipped%s")
            :format(vendor.name, #entries, skipped, loadingClause(countPending(entries))))
    end)
end

-- ---------------------------------------------------------------------------
-- auctionhouse
-- ---------------------------------------------------------------------------

local function endScan()
    st.scan, st.walk = nil, nil
    dropReplicateEvent()
end

local function ahAvailable()
    local AH = C_AuctionHouse
    return AH and AH.ReplicateItems and AH.GetNumReplicateItems and AH.GetReplicateItemInfo and true or false
end

-- One listing into the walk's aggregate, by item ID; consumables only.
-- An entry with hasAllInfo == false still names its item; the capture after the
-- walk requests that item and re-reads it when it loads.
local function readListing(w, index)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID =
        C_AuctionHouse.GetReplicateItemInfo(index)
    itemID = clean(itemID)
    if not itemID then return end
    if classOf(itemID) ~= 0 then
        w.skipped = w.skipped + 1
        return
    end
    local a = w.agg[itemID]
    if not a then
        a = { listings = 0, quantity = 0 }
        w.agg[itemID] = a
        w.order[#w.order + 1] = itemID
    end
    count = clean(count) or 1
    a.listings = a.listings + 1
    a.quantity = a.quantity + count
    buyout = clean(buyout)
    if buyout and buyout > 0 and count > 0 then
        local unit = math.floor(buyout / count)
        if not a.minBuyout or unit < a.minBuyout then a.minBuyout = unit end
    end
end

local function finishWalk(partial)
    local w = st.walk
    st.scan = "filling"
    dropReplicateEvent()
    local entries = {}
    for _, id in ipairs(w.order) do
        local a = w.agg[id]
        entries[#entries + 1] = { id = id, kind = "auctionhouse",
            data = { listings = a.listings, quantity = a.quantity, minBuyout = a.minBuyout } }
    end
    local read = partial and (" (partial: %d of %d listings read)"):format(w.i, w.total) or ""
    say(("auction house: %d consumables in %d listings, filling their records%s")
        :format(#entries, w.i, read))
    enqueue(entries, function()
        say(("auction house: scan done, %d consumables recorded from %d listings%s")
            :format(#entries, w.i, loadingClause(countPending(entries))))
        endScan()
    end)
end

local walkStep

local function walkProgress(w, from)
    local quarter = math.floor(w.i * 4 / w.total)
    if quarter > math.floor(from * 4 / w.total) and quarter < 4 then
        say(("auction house: %d%% read (%d of %d listings)"):format(quarter * 25, w.i, w.total))
    end
end

walkStep = function()
    local w = st.walk
    if st.scan ~= "walking" or not w then return end
    local from = w.i
    local stop = math.min(w.i + WALK_BATCH, w.total)
    for index = w.i, stop - 1 do readListing(w, index) end
    w.i = stop
    if w.i < w.total then
        walkProgress(w, from)
        after(0, st.gen, walkStep)
    else
        finishWalk(false)
    end
end

-- The list is ready. Replicate indices run from 0.
local function onReplicateList()
    if st.scan ~= "waiting" then return end
    dropReplicateEvent()
    local total = clean(C_AuctionHouse.GetNumReplicateItems()) or 0
    if total == 0 then
        endScan()
        return say("auction house: the scan came back empty (Blizzard allows one full scan per 15 minutes). Not retried.")
    end
    st.scan = "walking"
    st.walk = { i = 0, total = total, agg = {}, order = {}, skipped = 0 }
    say(("auction house: reading %d listings"):format(total))
    after(0, st.gen, walkStep)
end

local function throttleLeft()
    local last = SP.Store().lastAuctionScan
    if type(last) ~= "number" then return 0 end
    return SCAN_THROTTLE - (SP.Now() - last)
end

local function startScan()
    if not ahAvailable() then
        st.scan = nil
        return say("auction house scan unavailable: this client has no C_AuctionHouse.ReplicateItems.")
    end
    local left = throttleLeft()
    if left > 0 then
        st.scan = nil
        return say(("auction house throttled: Blizzard allows one full scan per 15 minutes; try again in %d min.")
            :format(math.ceil(left / 60)))
    end
    if not KCM.SafeRegisterEvent(KCM, REPLICATE_EVENT, "OnProbeEvent", KCM.RejectedEvents) then
        st.scan = nil
        return say("auction house scan unavailable: the client refused " .. REPLICATE_EVENT .. ".")
    end
    st.scan = "waiting"
    SP.Store().lastAuctionScan = SP.Now()
    C_AuctionHouse.ReplicateItems()
    say("auction house: full scan requested, waiting for the listing.")
    after(SCAN_TIMEOUT, st.gen, function()
        if st.scan ~= "waiting" then return end
        endScan()
        say(("auction house: no listing arrived within %d s; the scan was refused or throttled. Not retried.")
            :format(SCAN_TIMEOUT))
    end)
end

local SCAN_BUSY = {
    armed   = "auction house scan already armed: it starts when you next open the auction house.",
    waiting = "auction house scan already running: waiting for the listing.",
    walking = "auction house scan already running: reading the listing.",
    filling = "auction house scan already running: filling the records.",
}

local function probeAuctionHouse()
    if st.scan then return say(SCAN_BUSY[st.scan]) end
    if not st.ahOpen then
        st.scan = "armed"
        return say("auction house scan armed: it starts when you next open the auction house.")
    end
    startScan()
end

-- ---------------------------------------------------------------------------
-- Events (KCM:OnProbeEvent, core/ConsumableMaster.lua)
-- ---------------------------------------------------------------------------

local function onAuctionHouseClosed()
    st.ahOpen = false
    if st.scan == "waiting" then
        endScan()
        say("auction house closed before the listing arrived: nothing recorded.")
    elseif st.scan == "walking" then
        finishWalk(true)
    end
end

local EVENTS = {
    MERCHANT_SHOW   = function() st.merchantOpen = true end,
    MERCHANT_CLOSED = function() st.merchantOpen = false end,
    AUCTION_HOUSE_SHOW = function()
        st.ahOpen = true
        if st.scan == "armed" then startScan() end
    end,
    AUCTION_HOUSE_CLOSED = onAuctionHouseClosed,
    [REPLICATE_EVENT] = onReplicateList,
}

function SP.OnEvent(event)
    local fn = EVENTS[event]
    if fn then fn() end
end

-- ---------------------------------------------------------------------------
-- status and clear
-- ---------------------------------------------------------------------------

local function sourceCounts(items)
    local c = { seen = { mouseover = 0, vendor = 0, auctionhouse = 0 }, pending = 0, vendors = {}, clients = {} }
    for _, rec in pairs(items) do
        local s = rec.sources or {}
        for kind, n in pairs(c.seen) do
            if s[kind] and next(s[kind]) then c.seen[kind] = n + 1 end
        end
        for npcID in pairs(s.vendor or {}) do c.vendors[npcID] = true end
        if rec.pending then c.pending = c.pending + 1 end
        local key = rec.client or "?"
        c.clients[key] = (c.clients[key] or 0) + 1
    end
    return c
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function clientText(clients)
    local parts = {}
    for key, n in pairs(clients) do parts[#parts + 1] = key .. " " .. n end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "none"
end

local function scanText()
    local left = throttleLeft()
    local when = left > 0 and ("next full scan in %d min"):format(math.ceil(left / 60)) or "a full scan is allowed now"
    return ("%s; %s"):format(st.scan or "idle", when)
end

local function writeStatus(out)
    local db = SP.Store()
    local c = sourceCounts(db.items)
    out(("store: ConsumableMasterProbeDB, schema %s, %d items (%s)")
        :format(tostring(db.schemaVersion), SP.Count(), clientText(c.clients)))
    out(("  sources: mouseover %d, vendor %d (from %d vendors), auction house %d")
        :format(c.seen.mouseover, c.seen.vendor, countKeys(c.vendors), c.seen.auctionhouse))
    out(("  records still marked pending: %d"):format(c.pending))
    out(("  in flight: %d queued captures, %d items loading, %d jobs")
        :format(#st.queue - st.head + 1, countKeys(st.pending), st.jobs))
    out(("  merchant open: %s; auction house open: %s")
        :format(st.merchantOpen and "yes" or "no", st.ahOpen and "yes" or "no"))
    out("  auction house scan: " .. scanText())
end

local function probeStatus()
    KCM.DebugLog.Report("Probe", "probe seed status", writeStatus)
end

local function probeClear()
    local n = SP.Count()
    local stopped = stopAll()
    SP.Store().items = {}
    say(("probe store cleared: %d items removed%s"):format(n, stopped and "; the running probe was stopped" or ""))
end

-- ---------------------------------------------------------------------------
-- The verb
-- ---------------------------------------------------------------------------

local SEED_COMMANDS = {
    {"mouseover",    "Record the item under the mouse (bags, a vendor, the auction house, a link); bind it to a key",
        probeMouseover},
    {"vendor",       "Record every consumable the open merchant sells", probeVendor},
    {"auctionhouse", "Scan the auction house for consumables; armed for the next visit when it is closed",
        probeAuctionHouse},
    {"status",       "Write the probe store's summary to the debug console", probeStatus},
    {"clear",        "Empty the probe store", probeClear},
}
SP.SEED_COMMANDS = SEED_COMMANDS

local function seedHelp()
    say("seed probe: records item data for the seed lists into ConsumableMasterProbeDB")
    for _, row in ipairs(KCM.SlashCommands.CommandRows("/cm probe seed", SEED_COMMANDS, "  ")) do say(row) end
end

--- `/cm probe <rest>`, bound by settings/Slash.lua.
function SP.Run(rest)
    local SC = KCM.SlashCommands
    local area, tail = SC.SplitVerb(rest)
    if area ~= "seed" then
        if area ~= "" and area ~= "help" then say("unknown probe '" .. area .. "'") end
        return seedHelp()
    end
    local sub = SC.SplitVerb(tail)
    if sub == "" or sub == "help" then return seedHelp() end
    local entry = SC.FindCommand(SEED_COMMANDS, sub)
    if entry then return entry[3]() end
    say("unknown probe seed subcommand '" .. sub .. "'")
    seedHelp()
end

-- For the suite: the session state, read-only by convention.
SP.__state = st
