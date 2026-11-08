# The seed probe

The seed probe records item data from the live client so the seed lists (`defaults/Defaults_*.lua`)
can be built from it, on Retail and on WoW Forever. It is a core part of the addon, driven by slash
commands only; there is no settings panel for it. The data goes to its own SavedVariables global,
`ConsumableMasterProbeDB`, which the owner later asks Claude to read. The owner's rulings are in
`docs/superpowers/specs/2026-11-08-seed-probe-design.md`.

Code: `core/SeedProbe.lua` (the commands, the events, the pacing) and `core/SeedProbeStore.lua`
(the store, the record and the merge). Tests: `tests/test_seedprobe.lua`.

## Commands

| Command | What it does |
|---|---|
| `/cm probe seed mouseover` | Records the item under the mouse: in your bags, at a vendor, in the auction house, or a chat link. Any item class is recorded, because you pointed at it. Bind it to a key through a macro, since typing it in chat moves the mouse away. No item under the mouse is a refusal in chat. |
| `/cm probe seed vendor` | With a merchant open, records every **consumable** (classID 0) the vendor sells, with the vendor's NPC ID, name and zone, and counts the items it skipped. With no merchant open it refuses. |
| `/cm probe seed auction` | With the auction house open, scans it now. With it closed, arms a scan for the next time you open it. Records every **consumable** listed, aggregated by item ID. |
| `/cm probe seed status` | Writes a summary of the store and of any probe in flight to the debug console (a report, with one pointer line in chat). |
| `/cm probe seed purge` | Purges the store: empties its items and stops any probe in flight. The time of the last auction-house scan is kept, because Blizzard's throttle does not reset with it, and a stamp purged with the items would let the next `auction` ask for a scan the server refuses. |

`/cm probe` and `/cm probe seed` on their own print this list. The verbs were `auctionhouse` and
`clear` until 2026-11-08; the owner renamed them, and the old words are not kept as aliases. The
record's source key is still `auctionhouse` (below): it is a data key, and a store already written
keeps reading the same way.

What each command says in chat:

- `probed Longjaw Mud Snapper (4592): STAT_FOOD`, with `(loading: ...)` added when the item's data
  has not arrived yet.
- `vendor Innkeeper Farley: 14 consumables recorded, 3 skipped`, with `, N still loading` when some
  items are still on their way.
- For the auction house: the request, `reading N listings`, progress at 25%, 50% and 75%, the
  consumables found, and `scan done, N consumables recorded from M listings`.
- Refusals: no item under the mouse, no merchant open, the auction house throttled, an empty or
  missing listing, and the auction house closed before the listing arrived.

## The store

```lua
ConsumableMasterProbeDB = {
    schemaVersion = 1,
    lastAuctionScan = 1762600000,   -- when this install last asked for a full scan (epoch seconds)
    items = { [itemID] = record, ... },
}
```

It is a third SavedVariables global, beside `ConsumableMasterDB` and `ConsumableMasterPerfDB`, and an
accepted deviation from `toc-file-§2` and `savedvariables-§4` (the row in
[ARCHITECTURE.md](./ARCHITECTURE.md#documented-deviations) says why). It is never AceDB's, so a
profile copy, reset or switch never reaches it, and the probe never writes `ConsumableMasterDB`, the
macros or the picks. WoW writes it into the same file as the other two,
`WTF/Account/<account>/SavedVariables/ConsumableMaster.lua`, on `/reload` or logout. Each install has
its own file, so a Retail client never sees Forever's data, and every record names its client and
build as well.

`KCM:OnInitialize` builds the store if the file had none, and `SP.Store` rebuilds a broken one rather
than raising.

## One record

A sample, as a mouseover on a potion leaves it:

```lua
[171002] = {
    id = 171002, name = "Mended Draught",
    link = "|cffffffff|Hitem:171002::::::::80:::::|h[Mended Draught]|h|r",
    client = "retail", version = "12.0.5", build = "70448", interface = 120005,
    classID = 0, subClassID = 1, type = "Consumable", subType = "Potion",
    quality = 1, itemLevel = 42, minLevel = 10, stackCount = 20, sellPrice = 25,
    equipLoc = "", icon = 134830,
    spellID = 90123, spellName = "Healing Potion", spellDescription = "Restores 1000 health.",
    tooltip = {
        { left = "Mended Draught" },
        { left = "Use: Restores 1000 health." },   -- `right` only when the line has one
    },
    parsed = { healValue = 1000, itemName = "Mended Draught", minLevel = 10, statBuffs = {} },
    usable = true,               -- with unusableReason when it is false
    classified = { "HP_POT" },
    seenBy = { classID = 7, specID = 263, specKey = "7_263", level = 80 },
    sources = {
        mouseover = { count = 2, last = 1762600100 },
        vendor = {
            [295] = { name = "Innkeeper Farley", zone = "Elwynn Forest", mapID = 37,
                      price = 25, stackCount = 5, numAvailable = -1,
                      currencyID = nil, extendedCost = nil, last = 1762600200 },
        },
        auctionhouse = { listings = 400, quantity = 800, minBuyout = 50, scans = 1,
                         lastScan = 1762600300 },
    },
    firstSeen = 1762600000, lastSeen = 1762600300,
    pending = nil,               -- true while the item's name or tooltip lines have not arrived
    noEffect = nil,              -- true when the tooltip loaded but parsed to no effect (parsed = nil)
}
```

The fields, by where they come from:

- **Identity:** `id`, `name`, `link`, `client` (`KCM.Compat.ClientKey()`), and `version`, `build` and
  `interface` from `GetBuildInfo`.
- **Instant data:** `type`, `subType`, `equipLoc`, `icon`, `classID` and `subClassID` from
  `C_Item.GetItemInfoInstant`, which answers even for an item the server has not sent; `quality`,
  `itemLevel`, `minLevel`, `stackCount` and `sellPrice` from `GetItemInfo` once the item has loaded.
- **The use effect:** `spellID` and `spellName` from `C_Item.GetItemSpell`, and `spellDescription`
  from `C_Spell.GetSpellDescription`.
- **The tooltip:** `tooltip`, the raw lines from `C_TooltipInfo.GetItemByID`; `parsed`, a copy of the
  addon's own parse (`TooltipCache.Get`), never a reference into the cache; `usable` and
  `unusableReason`, the verdict `/cm dump item` prints; and `classified`, what `Classifier.MatchAny`
  makes of it today. A tooltip that loaded but that the parser reads no effect from (a Craftsman's
  Writ, wrapping paper, an Iron Shield Spike) has no `parsed` and no `usable`, and carries
  `noEffect = true` instead. Together they hold at least everything `/cm dump item <id>` shows.
- **Who saw it:** `seenBy`, the character's class, spec and level at capture.
- **Sources,** merged across probes. `mouseover` counts the probes and keeps the last time.
  `vendor[npcID]` is one row per vendor (the NPC ID is the sixth field of the vendor's Creature GUID,
  `0` when the GUID cannot be read): name, zone, map, price, stack size, `numAvailable` (`-1` is
  unlimited), `limited` when the supply is, the currency, and `extendedCost` as a list of
  `{ value, link, name }`. A later visit to the same vendor replaces its row. `auctionhouse` keeps the
  latest scan's `listings`, total `quantity` and lowest unit buyout (`minBuyout`, in copper, the
  buyout divided by the stack), how many `scans` saw the item, and `lastScan`.
- **Times:** `firstSeen` and `lastSeen`.

A later probe of the same item refreshes the identity, instant, use-effect, tooltip and classifier
fields, keeps `firstSeen`, and merges its source. A field the client does not answer this time keeps
its earlier value, so a cold read never wipes a warm one.

## Pacing, loading and the auction house

**Nothing runs until a command asks.** Four cheap events are registered with the others
(`KCM.EVENTS`): `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `AUCTION_HOUSE_SHOW` and `AUCTION_HOUSE_CLOSED`.
Each one sets an open flag, because `vendor` and `auction` have to know whether the window is
open when they are typed. `AUCTION_HOUSE_SHOW` also starts an armed scan. `REPLICATE_ITEM_LIST_UPDATE`
is registered only while a scan waits for its list, and dropped as soon as the list arrives.

**Time-sliced.** The probe has no OnUpdate. Captures go through one queue that fills 25 records per
frame (`FILL_BATCH`), and the auction-house walk reads 500 listings per frame (`WALK_BATCH`), each step
scheduled with `C_Timer.After(0, ...)`. A vendor's whole list therefore takes a frame or a few, and a
full auction house of tens of thousands of listings spreads over a hundred frames or so instead of
one.

**Loading.** A record is complete when the item has loaded (`GetItemInfo` answers a name) and the
client has answered tooltip lines. An incomplete record carries `pending = true`. A tooltip that loaded
but parses to nothing is complete, not pending: the tooltip cache holds such an item pending for its
own reasons (its partial-tooltip guard, `core/TooltipCache.lua`), but the probe's job is to record
what the client says, and a full tooltip with no effect the parser knows is a finished read. Until
2026-11-08 the probe took the cache's word for it, and the owner's Forever store ended with 223 of
498 records stuck at `pending = true` with full tooltips.
The probe asks the client for the item (`C_Item.RequestLoadItemDataByID`), and when
`GET_ITEM_INFO_RECEIVED` names it, `KCM:OnItemInfoReceived` drops the tooltip cache's stale entry and
hands the item to the probe, which captures it again. The tooltip body can arrive after that event,
and the event does not fire twice for one item, so when the queue drains with items still loading
the probe arms one timer and reads them again two seconds later, up to three times. After that the
record stays `pending` and the probe stops asking. So a cold auction-house scan still ends with
tooltips for every item the client delivers.

An auction-house listing with `hasAllInfo == false` still names its item ID, which is all the walk
needs; the item itself is loaded through the same path.

**The throttle.** Blizzard allows one full scan (`C_AuctionHouse.ReplicateItems`) per 15 minutes. The
probe records when this install last asked (`lastAuctionScan`) and refuses a second request inside the
window, saying how long is left. A request the server ignores is reported after 60 seconds with no
listing (`SCAN_TIMEOUT`), and an empty listing is reported as it arrives. Neither is retried. Closing
the auction house while the probe waits for the listing ends the scan with nothing recorded; closing
it during the walk records what was read and says so.

## The addon's state, combat and secrets

- **Disabled:** `probe` is a feature verb, so while the addon is disabled the dispatcher refuses it
  on the one collection-wide line (`slash-commands-§2`; it is not on `LIVE_VERBS`). The stand-down stops any probe in flight,
  including an armed scan, and clears the open flags, since the events that keep them true are gone.
- **Combat:** `mouseover` only reads, so it works in combat. A vendor and the auction house are out of
  combat by nature. Nothing touches a protected frame.
- **Secrets:** every value read from the client goes through `KCM.Compat.IsSecret` first. A secret
  value is dropped rather than compared, concatenated or saved, so a restricted hovered item reads as
  no item under the mouse (`events-frames-taint-§8`).

## Reading the data

After a `/reload` or a logout, the probe's data is in
`WTF/Account/<account>/SavedVariables/ConsumableMaster.lua`, under `ConsumableMasterProbeDB`. Ask
Claude to read it from there. `/cm probe seed status` gives the counts in game, and `/cm dump item
<id>` still shows the live parse of one item.
