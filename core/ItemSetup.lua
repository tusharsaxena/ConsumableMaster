-- core/ItemSetup.lua — the LibKa0s-Item-1.0 seam: where this addon turns a pasted item link into
-- an itemID (library-stack-§7).
--
-- ---------------------------------------------------------------------------
-- ONE PRIMITIVE, AND THAT IS THE WHOLE FILE
-- ---------------------------------------------------------------------------
--
-- This addon consumes two of the major's members: `ItemIDFromLink`, and `LoadItem` for the one
-- case the pipeline cannot reach (below). The rest are pointedly absent rather than forgotten:
--
--   QualityFromLink / QualityLabel — this addon has no rarity concept at all. Its "quality" is the
--     crafting-tier atlas out of C_TradeSkillUI; ITEM_QUALITY_COLORS and GetItemQualityColor
--     appear nowhere in core/, modules/ or settings/.
--   BonusIDsFromLink — nothing here reads a link's bonus ids.
--
-- ---------------------------------------------------------------------------
-- LoadItem, AND ONLY WHILE STOOD DOWN (#40)
-- ---------------------------------------------------------------------------
--
-- While the addon RUNS, hydration is implicit: GetItemInfo plus a GET_ITEM_INFO_RECEIVED handler
-- split deliberately for the ~150-item burst on first panel open (core/ConsumableMaster.lua). A
-- second request path beside that would duplicate a tuned one, so KCM.HydrateItem does nothing
-- then.
--
-- While it is STOOD DOWN the settings panel survives (setup, not a feature: slash-commands-§7)
-- but that path does not: UnregisterAllEvents drops GET_ITEM_INFO_RECEIVED, and PANEL_REFRESH's
-- subscription goes down with the options bus target. A panel opened in a fresh session would show
-- `[Loading]` for every uncached row until re-enable. The owner ruled (2026-11-27, #40) that the
-- panel hydrates its own rows then, through LoadItem: one RequestLoadItemDataByID and one
-- C_Timer one-shot per uncached id, whose callback asks the panel for its debounced repaint. It
-- registers NO event and subscribes to NO message, so the registration set stays empty and the
-- stand-down stays total (tests/test_disabled.lua). An id is asked for once per session: a
-- callback whose data still has not arrived does not re-ask, or a row the server never answers
-- would repaint the panel every 0.4 s for as long as it is open. The guard is IsStoodDown rather
-- than IsAddonDisabled, because the perf hold drops the same event and leaves the same panel.
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

local requested = {}

--- Ask the server for an uncached item a settings row is showing as `[Loading]`, and repaint the
--- panel once it should have arrived. Only while stood down; inert with no library.
---
--- @param itemID number
function KCM.HydrateItem(itemID)
    if type(itemID) ~= "number" or requested[itemID] then return end
    if not (KCM.IsStoodDown and KCM.IsStoodDown()) then return end
    if not (Item and Item.LoadItem) then return end
    requested[itemID] = true
    Item.LoadItem(itemID, function()
        local O = KCM.Options
        if O and O.RequestRefresh then O.RequestRefresh() end
    end)
end
