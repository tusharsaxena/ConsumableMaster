-- core/ItemSetup.lua — the LibKa0s-Item-1.0 seam: where this addon turns a pasted item link into
-- an itemID (library-stack-§7).
--
-- ---------------------------------------------------------------------------
-- ONE PRIMITIVE, AND THAT IS THE WHOLE FILE
-- ---------------------------------------------------------------------------
--
-- This addon consumes exactly one of the major's four members, `ItemIDFromLink`. The other three
-- are pointedly absent rather than forgotten:
--
--   QualityFromLink / QualityLabel — this addon has no rarity concept at all. Its "quality" is the
--     crafting-tier atlas out of C_TradeSkillUI; ITEM_QUALITY_COLORS and GetItemQualityColor
--     appear nowhere in core/, modules/ or settings/.
--   LoadItem — hydration already runs implicitly through GetItemInfo plus a
--     GET_ITEM_INFO_RECEIVED handler split deliberately for the ~150-item burst on first panel
--     open (core/ConsumableMaster.lua). A second request path would duplicate a tuned one.
--
-- What pointedly did NOT move is core/TooltipCache.lua. The major carries no resolver and no cache
-- BY WRITTEN DESIGN — two addons in this collection disagree on purpose about what an uncached
-- item means, and a shared resolver would have had to overturn one of them. This addon's cache is
-- its own policy and stays exactly where it is.
--
-- ---------------------------------------------------------------------------
-- WHAT A DEGRADED INSTALL GETS
-- ---------------------------------------------------------------------------
--
-- The same primitive, locally, in three lines. A caller forced to branch on the library's presence
-- would be a caller that accepts a pasted link on one install and rejects it on another, for no
-- reason a player could ever see.

local _, NS = ...
local KCM = NS

local Item = LibStub and LibStub("LibKa0s-Item-1.0", true)

KCM.Item = Item or {
    -- Matches the link's own `item:<id>` segment, so it is locale-independent and works on both a
    -- full link and the bare itemString a saved variable is likely to hold. A non-string answers
    -- nil rather than being passed through, because a caller that cannot tell an id from a link
    -- has a bug the fallback should not hide.
    ItemIDFromLink = function(link)
        if type(link) ~= "string" then return nil end
        return tonumber(link:match("|?H?item:(%d+)"))
    end,
}
