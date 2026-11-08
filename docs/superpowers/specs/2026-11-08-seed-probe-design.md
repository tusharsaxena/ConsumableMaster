# The seed probe: capturing item data for the seed lists

Owner request, 2026-11-08: a probe that captures every piece of data needed to build seed lists, on Retail and
WoW Forever, as a core part of the addon rather than a throwaway. Slash commands only, no settings panel. The data
goes to its own store, which the owner later asks Claude to read.

```
/cm probe seed mouseover      the item under the mouse (bags, vendor, AH, a link): bind it to a key
/cm probe seed vendor         every item the open merchant sells
/cm probe seed auctionhouse   a full auction-house scan
```

## The owner's rulings (2026-11-08)

- **The store is its own SavedVariables global, `ConsumableMasterProbeDB`.** It is declared third in the TOC, after
  `ConsumableMasterDB` and `ConsumableMasterPerfDB`. That is an **accepted deviation** from toc-file-§2 and
  savedvariables-§4, which allow two globals. It gets a row in `docs/ARCHITECTURE.md`'s Documented deviations,
  and the standard is unchanged. WoW still writes it into the same file, `SavedVariables/ConsumableMaster.lua`.
- **The auction-house scan is armed by the command.** With the auction house open, `auctionhouse` scans now.
  Closed, it arms a scan for the next `AUCTION_HOUSE_SHOW`. Blizzard allows one full scan
  (`C_AuctionHouse.ReplicateItems`) per 15 minutes, so a refused or empty scan is reported, never retried in a
  loop.

## The APIs, the same on both clients

Ketho/BlizzardInterfaceResources `forever` 1.60.1 (70532) and `live` 12.1.5 (70448) both carry:
- `C_AuctionHouse.ReplicateItems`, `GetNumReplicateItems`, `GetReplicateItemInfo` and `GetReplicateItemLink`, with
  the events `AUCTION_HOUSE_SHOW` and `REPLICATE_ITEM_LIST_UPDATE`;
- `C_MerchantFrame.GetItemInfo`, `GetMerchantNumItems`, `GetMerchantItemID`, `GetMerchantItemLink` and
  `MERCHANT_SHOW`;
- `C_TooltipInfo.GetItemByID` and `GetHyperlink`, `C_Item.GetItemSpell`, `C_Spell.GetSpellDescription` and
  `C_Item.RequestLoadItemDataByID`.

So one code path serves both clients. A missing API is tolerated at its call site (feature detection inside a
feature both clients support, clients-§3), and it is reported, never raised.

## What one record holds

`ConsumableMasterProbeDB = { schemaVersion = 1, items = { [itemID] = record } }`. Each install has its own
SavedVariables, so a client never sees the other's data, and each record also names its client and build.

A record holds:
- **Identity:** `id`, `name`, `link`, `client` (`ClientKey()`), `build` and `interface` (from `GetBuildInfo`).
- **Instant data** (`GetItemInfoInstant` / `GetItemInfo`): `classID`, `subClassID`, `type`, `subType`, `quality`,
  `itemLevel`, `minLevel`, `stackCount`, `sellPrice`, `equipLoc`, `icon`.
- **The use effect:** `spellID`, `spellName` (`GetItemSpell`) and the spell description.
- **The tooltip:** its raw lines (`C_TooltipInfo`, after the item loads), the addon's parsed entry
  (`TooltipCache.Get`, copied, not referenced), and what the Classifier makes of it today (`MatchAny`).
- **Who saw it:** the character's `classID`, spec key and level at capture.
- **Sources,** merged across probes:
  - `mouseover` (a count and the last time);
  - `vendor[npcID]`: the vendor's name, zone, price, stack size, extended cost and limited supply;
  - `auctionhouse`: listings seen, the lowest buyout, and the last scan time.
- **Times:** `firstSeen` and `lastSeen`.

A later probe of the same item refreshes the identity, instant, tooltip and classifier fields, and merges its
source.

## Scope per command

- **mouseover:** reads the hovered item through `GameTooltip:GetItem()`. Any item class is recorded, because the
  owner pointed at it. No item under the mouse is a refusal in chat.
- **vendor:** needs an open merchant (`MERCHANT_SHOW` / `MERCHANT_CLOSED`). It records every **consumable**
  (classID 0) the vendor sells, plus the vendor's NPC ID, name and zone, and counts the items it skipped.
- **auctionhouse:** records every **consumable** (classID 0) listed, aggregated by item ID.
- **status** (a report, to the console) and **clear** (an acknowledgment) are added for practical use.

## Behavior and standards

- **Output** follows the owner's report ruling of 2026-11-08:
  - one-line acknowledgments in chat, for example `probed Longjaw Mud Snapper (4592): STAT_FOOD`,
    `vendor Innkeeper Farley: 14 consumables recorded, 3 skipped`, and the auction house's start, progress and
    end;
  - refusals in chat (no item under the mouse, no merchant open, auction house throttled);
  - `status` as a report, through `KCM.DebugLog.Report`.
- **Loading:** an item whose data is not cached yet is requested, and its record is completed when it arrives
  (the addon's existing `GET_ITEM_INFO_RECEIVED` / TooltipCache retry seam), so a cold auction-house scan still
  ends with tooltips.
- **Performance:** nothing runs until a command asks. The auction-house walk and the tooltip fill are
  time-sliced (a bounded batch per frame through `C_Timer`), never one frame over thousands of listings. There is
  no OnUpdate.
- **Combat:** mouseover reads only, so it works in combat. Vendor and auction house are out of combat by nature.
  Nothing touches protected frames.
- **Secrets:** values from the client go through the addon's existing secret-safe paths before any comparison or
  concatenation (events-frames-taint-§8).
- **The addon's state:** the probe never touches macros, picks or `ConsumableMasterDB`. While the addon is
  disabled, `probe` follows the standard's rule for feature verbs.
- **Tests:** headless, on both kit profiles. They mock the hovered item, a merchant, a replicate list (cold and
  warm items) and tooltips, and check the record shape, the merge across sources, time-slicing, throttle
  handling, the refusals and `clear`.
- **Docs:** the deviation row; a topic doc for the probe's commands and record shape (documentation-§3); the slash
  docs; `docs/module-map.md` and the load order; smoke checks on both clients (Result: owed); and README's
  command list, if it carries one.
