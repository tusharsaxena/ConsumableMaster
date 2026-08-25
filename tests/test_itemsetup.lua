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
        "the itemID out of a coloured, fully-qualified link")
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
