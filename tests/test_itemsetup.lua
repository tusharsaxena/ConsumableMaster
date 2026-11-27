-- tests/test_itemsetup.lua — the LibKa0s-Item-1.0 seam (core/ItemSetup.lua).
--
-- This addon consumes exactly one primitive, ItemIDFromLink, so that is what is pinned here —
-- both arms of it. The degraded arm matters as much as the library one: it is what decides whether
-- a player who shift-clicks an item into the Add-by-ID box gets it accepted on a broken install
-- as well as a whole one, and a difference there is invisible until somebody has the broken one.

local h = _G.KCM_TEST
local test = h.test

test("ItemSetup: KCM.Item.ItemIDFromLink reads the id out of a full item link", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.Item, "the seam is published")
    t.eq(KCM.Item.ItemIDFromLink(
        "|cffa335ee|Hitem:211804::::::::80:253::::::|h[Vantus Rune]|h|r"), 211804,
        "the itemID out of a colored, fully-qualified link")
end)

test("ItemSetup: it reads a bare itemString too", function(t)
    -- The form a saved variable is likely to hold, and the form a macro pastes.
    local KCM = h.loader.loadPure()
    t.eq(KCM.Item.ItemIDFromLink("item:211804"), 211804)
end)

test("ItemSetup: a non-link string and a non-string both answer nil", function(t)
    -- nil rather than a pass-through on purpose. A caller that cannot tell an id from a link has
    -- a bug, and a fallback that quietly accepted the number would hide it.
    local KCM = h.loader.loadPure()
    t.eq(KCM.Item.ItemIDFromLink("not a link"), nil)
    t.eq(KCM.Item.ItemIDFromLink(211804), nil, "a number that already IS an id is not a link")
    t.eq(KCM.Item.ItemIDFromLink(nil), nil)
end)

test("ItemSetup: a SPELL link is not mistaken for an item", function(t)
    -- The two kinds share the Add-by-ID box, and crossing them would file a spell under an itemID
    -- where it collides with the real one.
    local KCM = h.loader.loadPure()
    t.eq(KCM.Item.ItemIDFromLink("|cff71d5ff|Hspell:212653|h[Shimmer]|h|r"), nil)
end)

test("ItemSetup: the degraded stub answers exactly what the library does", function(t)
    -- The whole point of the seam. If these two ever disagree, the Add-by-ID box accepts a pasted
    -- link on one install and rejects it on another for no reason a player could see.
    local KCM = h.loader.loadPureDegraded()
    t.truthy(KCM.Item, "the seam still exists with no library")
    t.eq(KCM.Item.ItemIDFromLink(
        "|cffa335ee|Hitem:211804::::::::80:253::::::|h[Vantus Rune]|h|r"), 211804)
    t.eq(KCM.Item.ItemIDFromLink("item:99"), 99)
    t.eq(KCM.Item.ItemIDFromLink("not a link"), nil)
    t.eq(KCM.Item.ItemIDFromLink(211804), nil)
end)

-- ---------------------------------------------------------------------------
-- The disabled-state hydration (#40)
-- ---------------------------------------------------------------------------
--
-- While the addon is stood down the panel survives but GET_ITEM_INFO_RECEIVED does not, so an
-- uncached row would stay `[Loading]` until re-enable. KCM.HydrateItem asks LibKa0s-Item's
-- LoadItem once per id and repaints the panel on the one-shot callback. It registers nothing,
-- which is what keeps the stand-down total; tests/test_disabled.lua holds that half.

--- The pure layer, stood down or not by fiat, with the request API and the panel refresh spied.
local function hydrateRig(stoodDown, degraded)
    local KCM = degraded and h.loader.loadPureDegraded() or h.loader.loadPure()
    KCM.IsStoodDown = function() return stoodDown end
    local rig = { requests = {}, refreshes = 0 }
    _G.C_Item.RequestLoadItemDataByID = function(id) rig.requests[#rig.requests + 1] = id end
    KCM.Options = KCM.Options or {}
    KCM.Options.RequestRefresh = function() rig.refreshes = rig.refreshes + 1 end
    return KCM, rig
end

-- red under: KCM.HydrateItem missing, or not calling LoadItem.
test("ItemSetup: stood down, an uncached id is requested and the panel repaints on the callback",
    function(t)
        local KCM, rig = hydrateRig(true)
        t.eq(type(KCM.HydrateItem), "function", "the seam publishes HydrateItem")
        KCM.HydrateItem(211804)
        t.eqList(rig.requests, { 211804 }, "one request through C_Item.RequestLoadItemDataByID")
        t.eq(rig.refreshes, 1, "the one-shot callback asked the panel for its debounced repaint")
    end)

-- red under: no per-id memory, so every repaint of a still-uncached row re-requests and the
-- callback's own repaint loops every 0.4 s for an id the server never answers.
test("ItemSetup: the request is one-shot per id", function(t)
    local KCM, rig = hydrateRig(true)
    KCM.HydrateItem(211804)
    KCM.HydrateItem(211804)
    KCM.HydrateItem(212241)
    t.eqList(rig.requests, { 211804, 212241 }, "a second ask for the same id requests nothing")
    t.eq(rig.refreshes, 2, "and arms no second callback")
end)

-- red under: dropping the stood-down guard, which would put a second request path beside the
-- tuned GET_ITEM_INFO_RECEIVED one while the addon runs.
test("ItemSetup: standing, HydrateItem requests nothing (GET_ITEM_INFO_RECEIVED owns it)", function(t)
    local KCM, rig = hydrateRig(false)
    KCM.HydrateItem(211804)
    t.eq(#rig.requests, 0, "no request while the pipeline is up")
    t.eq(rig.refreshes, 0)
end)

test("ItemSetup: HydrateItem ignores a nil or non-numeric id", function(t)
    local KCM, rig = hydrateRig(true)
    KCM.HydrateItem(nil)
    KCM.HydrateItem("item:1")
    t.eq(#rig.requests, 0)
end)

test("ItemSetup: with no library, HydrateItem is inert and does not raise", function(t)
    -- The degraded seam carries no LoadItem, and a row on that install shows `[Loading]` as it
    -- did before #40 rather than growing a host copy of the library's request.
    local KCM, rig = hydrateRig(true, true)
    t.eq(type(KCM.HydrateItem), "function", "the seam still publishes it")
    KCM.HydrateItem(211804)
    t.eq(#rig.requests, 0)
    t.eq(rig.refreshes, 0)
end)

-- red under: the item row's `[Loading]` fallback not asking for the hydration.
test("ItemSetup: an item row with an uncached name asks HydrateItem for it", function(t)
    local KCM = h.loader.wearKa0s(h.loader.loadPure())
    local asked = {}
    KCM.HydrateItem = function(id) asked[#asked + 1] = id end
    local buildWidget = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/skin_widget_support.lua")
    local w, _, cleanup = buildWidget(KCM, "modules/KCMItemRow.lua", "KCMItemRow")
    local ok, err = pcall(function()
        w:OnAcquire()
        w:SetCustomData({ itemID = 987654 })      -- in no mock table: uncached
        t.eqList(asked, { 987654 }, "the uncached row asked once")
        h.loader.mock.items[987655] = { name = "Cached Thing", classID = 0, subClassID = 1 }
        w:SetCustomData({ itemID = 987655 })
        t.eqList(asked, { 987654 }, "a cached row asks nothing")
    end)
    h.loader.mock.items[987655] = nil
    cleanup()
    t.truthy(ok, tostring(err))
end)
