-- settings/CategoryAddByID.lua — the Macros page's Add-by-ID line.
--
-- What this file owns: the "Add item or spell by ID" section of a single
-- category tab, whole. The Type dropdown (Item / Spell), the two ID KINDS
-- behind it -- which library kind looks a name up, the words its messages use,
-- how to prove an ID exists and how to store it -- this addon's own resolver
-- over LibKa0s-Options-1.0's IdInput line, the candidate set a name and the
-- as-you-type suggestions are matched against, the writer that hands a resolved
-- ID to Selector.AddItem, and O.AddByIDBusy, which is what holds the debounced
-- page rebuild while the box is in use (settings/OptionsShim.lua reads it).
--
-- WHY IT IS ITS OWN FILE. It was a block inside settings/Category.lua until
-- 2026-09-16. That file stood at 1400 lines against layout-§1's 1500-line cap
-- and had been carried as Accepted on docs/automated-tests/RESULTS.md's watch
-- list across three consecutive releases, which automated-tests-§4 refuses a
-- fourth time. This is the seam the page actually has: everything else in
-- Category.lua draws a LIST the addon already holds, and this draws the one
-- control that puts something new into it. Every line moved WHOLE -- no
-- comparison, constant or comment changed in the cut.
--
-- THE SEAM, both ways, because it is the thing to keep honest:
--   * Inward, this file takes exactly two of the page's own helpers --
--     `newRow` and `afterMutation` -- off KCM.Settings.MacrosPage, published by
--     settings/Category.lua, which the TOC loads immediately before this file.
--     Copies were the alternative and are the wrong one: `afterMutation` is the
--     page's single "something changed, resync" call and a second copy of it is
--     how two halves of one page start disagreeing about what a mutation costs.
--   * Outward, it publishes ONE entry point, KCM.Settings.AddByID.Render, which
--     settings/Category.lua's single-category renderer calls at RENDER time --
--     so nothing here has to exist when that file loads. O.AddByIDBusy is
--     published on KCM.Options as it always was; no caller of it changed.
--
-- `makeDropdown` and `spellNameByID` came across with the block rather than
-- being shared, because the block is their only caller -- the Type dropdown is
-- the page's one dropdown, and the spell-name lookup is read only by the SPELL
-- kind's `exists` / `info`.

local _, NS = ...
local KCM = NS
local L      = KCM.L
local H      = KCM.Settings.Helpers
-- Silent-mode (library-stack-§4), the same read settings/Category.lua makes and
-- for the same reason: AceGUI is an OptionalDep, nothing on this page is
-- reachable without the panel, and settings/OptionsSetup.lua already refuses to
-- build one when AceGUI is nil.
local AceGUI = LibStub("AceGUI-3.0", true)

KCM.Options = KCM.Options or {}
local O = KCM.Options
O._addKind = O._addKind or {}

-- The page's two helpers this file borrows -- see the seam note in the header.
-- Taken as file-scope locals because settings/Category.lua loads first and
-- publishes them at load; a call-time lookup would buy nothing and would hide a
-- load-order break instead of raising on one.
local MacrosPage    = KCM.Settings.MacrosPage
local newRow        = MacrosPage.NewRow
local afterMutation = MacrosPage.AfterMutation

-- The Type dropdown's two choices, and the order they are offered in.
local ADD_KIND_OPTIONS = { ITEM = L["Item"], SPELL = L["Spell"] }
local ADD_KIND_SORTING = { "ITEM", "SPELL" }

-- ---------------------------------------------------------------------
-- Lookup helper (Midnight C_Spell split) + the page's one dropdown
-- ---------------------------------------------------------------------

local function spellNameByID(id)
    return KCM.Compat and KCM.Compat.GetSpellName and KCM.Compat.GetSpellName(id) or nil
end

local function makeDropdown(parent, opts)
    local dd = AceGUI:Create("Dropdown")
    if opts.label then dd:SetLabel(opts.label) end
    dd:SetList(opts.values or {}, opts.sorting)
    if opts.relativeWidth then dd:SetRelativeWidth(opts.relativeWidth)
    elseif opts.width    then dd:SetWidth(opts.width)
    else                       dd:SetFullWidth(true) end
    dd:SetValue(opts.value)
    if opts.onChange then
        dd:SetCallback("OnValueChanged", function(_, _, v) opts.onChange(v) end)
    end
    if opts.tooltip then H.AttachTooltip(dd, opts.label, opts.tooltip) end
    parent:AddChild(dd)
    return dd
end

-- What the Type dropdown's two choices mean to the add-by-ID line: which of
-- LibKa0s-Options-1.0's kinds looks a name up, the words its messages use, how to
-- prove an ID exists, and how to store it. Module-level, so a third kind is one
-- table entry rather than another elseif arm.
local ID_KINDS = {
    SPELL = {
        lookup  = "spell",
        -- The library kind these ids are: its rows wear the spell's subtext. Its lookup and its
        -- spellbook do not come with it; the resolver below keeps what is added.
        base    = "spell",
        noun    = L["spell"],
        plural  = L["spells"],
        exists  = function(id) return spellNameByID(id) end,
        -- A suggestion row, and a name among the candidates, are read through this.
        info    = function(id)
            return spellNameByID(id),
                C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        end,
        nameHint = L["Names work for spells in your spellbook and ones this list knows; otherwise use the ID or shift-click a link."],
        -- Spell IDs go in through the opaque sentinel, never raw, or they
        -- collide with itemIDs.
        store   = function(id) return KCM.ID.AsSpell(id) end,
        -- The other way: a stored entry back to a spellID, or nil for an item.
        fromStored = function(id) return KCM.ID.SpellID(id) end,
        -- Shift-clicking a spell out of a spellbook pastes a spell link. Parsed
        -- here rather than in a shared helper because the two kinds' links are
        -- different strings, and this table is where a kind's differences live.
        fromLink = function(text)
            return tonumber(tostring(text):match("|?H?spell:(%d+)"))
        end,
    },
    ITEM = {
        lookup  = "item",
        -- The library kind these ids are: its rows wear the crafted-quality tier icon and the
        -- name its quality color. Its bags do not come with it, which is why `carried` stays.
        base    = "item",
        noun    = L["item"],
        plural  = L["items"],
        -- Classic/Midnight safety: reject only when the API is PRESENT and says
        -- it doesn't know the ID. An absent API passes the check.
        exists  = function(id)
            return not (C_Item and C_Item.GetItemInfoInstant)
                or C_Item.GetItemInfoInstant(id)
        end,
        -- GetItemNameByID needs the client's cache, which the library's pre-warm
        -- fills for the candidates (`loads`); the icon needs none.
        info    = function(id)
            if not C_Item then return nil end
            return C_Item.GetItemNameByID and C_Item.GetItemNameByID(id),
                C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        end,
        loads   = true,
        -- The items in the bags, which join this category's candidates. A host
        -- kind gets no client source from the library, so without these a rank
        -- the player carries but the tab does not list is neither suggested nor
        -- counted when two carried ranks share a name.
        carried = function()
            local ids = {}
            local BS = KCM.BagScanner
            for id in pairs(BS and BS.Scan and BS.Scan() or {}) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end,
        nameHint = L["Names work for items you carry (or carried this session) and ones this list knows; otherwise use the ID or shift-click a link."],
        store   = function(id) return id end,
        fromStored = function(id) return KCM.ID.IsItem(id) and id or nil end,
        -- The library's primitive, through the KCM.Item seam so a degraded install
        -- behaves the same. It matches the link's own `item:<id>` segment, so it is
        -- locale-independent and takes a bare itemString as happily as a full link.
        fromLink = function(text) return KCM.Item.ItemIDFromLink(text) end,
    },
}

-- The kind the Type dropdown names for this category right now.
local function addKindOf(cat)
    return ID_KINDS[O._addKind[cat.key] or "ITEM"] or ID_KINDS.ITEM
end

-- The line's words, through L. Handed to the library as VALUES, never as KCM.L
-- itself (LIBKA0S-05, "the L trap"). `{noun}`, `{plural}`, `{text}`, `{count}`
-- and `{hint}` are the library's tokens, filled from the kind below, from what
-- was typed, and from `nameHint`. notFound ends in the hint because the client
-- has no item-name search: a name reaches only what the player carries (or
-- carried this session) and the IDs this category already knows.
local ADD_BY_ID_STRINGS = {
    add       = L["Add"],
    empty     = L["Type an ID, a link or a name."],
    notFound  = L["No {noun} matches '{text}'. {hint}"],
    ambiguous = L["Several {plural} share the name '{text}': pick one from the list, or use the ID."],
    looking   = L["Looking up {plural}..."],
    more      = L["+{count} more"],
}

-- The words the library reads by key, with the hint read off whichever kind
-- the Type dropdown names when a refusal is written.
local function addByIDStrings(cat)
    return setmetatable({}, { __index = function(_, key)
        if key == "nameHint" then return addKindOf(cat).nameHint end
        return ADD_BY_ID_STRINGS[key]
    end })
end

-- The same line on a spec-aware tab with no spec to file under. The library
-- clamps a host resolver's reason to its own three, so the refusal is its
-- "notFound", reworded here to say what is actually missing.
local NO_SPEC_STRINGS = {
    add      = ADD_BY_ID_STRINGS.add,
    empty    = ADD_BY_ID_STRINGS.empty,
    notFound = L["No active spec, so this spec-aware category has nowhere to put '{text}'."],
}

-- Typed text to an ID of the kind the dropdown names, or nil and the library's
-- reason. With no spec to file under, every entry is refused here, before the
-- id line treats it as added: a refusal keeps the typed text, an add clears it.
-- Then digits -- a bare number is unambiguous and must never reach a
-- link matcher -- then the kind's own link parser, then a name, through
-- LibKa0s-Options-1.0's ResolveId: the client's lookup, and the category's own
-- candidates by name. A name several of them share is "ambiguous", so one
-- crafted-quality rank is never added for the player. Whatever is found must pass the kind's
-- existence check, so an ID the client does not know is refused however it was
-- typed, and a link of the other kind is never cross-filed: an item link read as
-- a spell would file an itemID behind the opaque sentinel.
local function resolveAddByID(cat, text, specless, candidates)
    if specless then return nil, "notFound" end
    local kind = addKindOf(cat)
    local id = tonumber(text:match("^%d+$")) or kind.fromLink(text)
    local name
    if not id then
        id, name = H.ResolveId(kind.lookup, text, candidates)
        if not id then return nil, name end
    end
    if id <= 0 or not kind.exists(id) then return nil, "notFound" end
    return id, name
end

-- The IdInput kind: this addon's resolver, with the noun, the `info` its
-- suggestion rows are named through, `loads` and `base` read off whichever kind
-- the dropdown names at the moment they are read. `base` is what dresses the rows
-- (tier icon, quality color, subtext), and it makes a picked row go through the
-- resolver before onAdd, so a pick is refused as a typed ID would be. A
-- spec-aware tab with no spec has no `info` (its own `false` beats the base's),
-- so no list goes up at all.
local function addByIDKind(cat, specless)
    local own = {
        resolve = function(text, candidates)
            return resolveAddByID(cat, text, specless, candidates)
        end,
    }
    if specless then own.info, own.loads = false, false end
    return setmetatable(own, { __index = function(_, key) return addKindOf(cat)[key] end })
end

-- The IDs this category already knows, as the dropdown's kind names them: the
-- seed, the added and the discovered, less the blocked (Selector.BuildCandidateSet),
-- each turned back from its stored shape; then, under Item, the items in the
-- bags. The client cannot search item names, so the first are what a name and
-- the suggestions reach beyond the bags: every rank of a crafted potion the
-- category knows, carried or not. The second make a name two CARRIED ranks
-- share ambiguous, and list those ranks to pick from, when the tab lists
-- neither: the library counts the bags only for its own item kind.
local function addByIDCandidates(cat, specKey)
    return function()
        local kind, out, seen = addKindOf(cat), {}, {}
        local function take(id)
            if id and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
        local Sel = KCM.Selector
        local stored = Sel and Sel.BuildCandidateSet and Sel.BuildCandidateSet(cat.key, specKey)
        for _, id in ipairs(stored or {}) do take(kind.fromStored(id)) end
        for _, id in ipairs(kind.carried and kind.carried() or {}) do take(id) end
        return out
    end
end

-- The resolved ID into the category, through Selector.AddItem as ever. The page
-- rebuild waits a frame. It was written for the IdInput that cleared its edit box
-- and status line AFTER onAdd returned, onto widgets a rebuild inside onAdd had
-- already released into AceGUI's pool. Since LibKa0s v1.35.0 IdInput clears both
-- BEFORE onAdd and touches neither after a clean one, so the wait is no longer
-- load-bearing; it is kept, and pinned by its test, as the shape that is safe
-- under either order. A spec-aware tab with no spec never gets here: its
-- resolver refuses first, and it draws no suggestions. A picked suggestion
-- arrives without the resolver, so the kind's existence check runs here too.
local function addResolvedID(cat, specKey, id)
    local kind = addKindOf(cat)
    if type(id) ~= "number" or id <= 0 or not kind.exists(id) then return end
    local changed = KCM.Selector and KCM.Selector.AddItem
        and KCM.Selector.AddItem(cat.key, kind.store(id), specKey)
    if changed then
        C_Timer.After(0, function() afterMutation("options_add_item") end)
    end
end

-- The edit box the last render drew, for O.AddByIDBusy; and the text a Type
-- change carries across its redraw, by category key, taken by the next render
-- of that tab.
local addByIDBox
local carriedText = {}

-- The line's tooltip. A spec-aware tab with no spec draws no list and resolves
-- no name, so it neither offers one nor ends in the name hint.
local function addByIDTooltip(cat, specless)
    if specless then
        return L["Enter an itemID or spellID, or shift-click an item or spell link into the box. Press Enter or click Add."]
            .. " " .. L["With no active spec, this spec-aware category has nowhere to put an entry."]
    end
    return L["Enter an itemID or spellID, shift-click an item or spell link into the box, or type a name and pick it from the list. Press Enter or click Add."]
        .. " " .. addKindOf(cat).nameHint
end

-- Whether the Add-by-ID box on screen is in use: it has the keys, or it holds
-- text -- a name being typed, a refused one kept for correcting, or a submitted
-- one whose lookup is still waiting on the client. settings/OptionsShim.lua holds
-- the debounced page rebuild while this answers true: a rebuild releases the box,
-- and the library's OnRelease drops the lookup and clears the text with no word
-- on the status line. A box that is not visible holds nothing.
function O.AddByIDBusy()
    local eb = addByIDBox
    local frame = eb and eb.frame
    if not (frame and frame.IsVisible and frame:IsVisible()) then return false end
    local box = eb.editbox
    if box and box.HasFocus and box:HasFocus() then return true end
    local text = eb.GetText and eb:GetText()
    return type(text) == "string" and text ~= ""
end

-- Add by ID: the Type dropdown, then LibKa0s-Options-1.0's IdInput line under it
-- -- an edit box taking an ID, a shift-clicked link or a name, an Add button, and
-- a status line that says why an entry was refused and keeps the text. As the
-- player types, the library lists the matching IDs this category knows or the
-- bags carry, every rank its own row; a pick goes through the same onAdd. The
-- line never writes a path; onAdd hands the ID to the Selector writer. Changing
-- Type redraws the page a frame later: the list is built once a render, so an
-- item row left under Spell would be filed as a spell. What was typed rides
-- across that redraw, which would otherwise hand back an empty box.
local function renderAddByID(ctx, scroll, cat, specKey)
    local specless = cat.specAware and not specKey
    local box
    H.Section(ctx, L["Add item or spell by ID"])
    local addRow = newRow(scroll)
    makeDropdown(addRow, {
        label         = L["Type"],
        tooltip       = L["Choose whether the ID belongs to an item (default — anything in bags) or a spell (class abilities like Recuperate). Auto-discovery already handles items in your bags; use this to seed something you don't currently carry, or any castable spell."],
        values        = ADD_KIND_OPTIONS,
        sorting       = ADD_KIND_SORTING,
        value         = O._addKind[cat.key] or "ITEM",
        relativeWidth = 0.4,
        onChange      = function(v)
            O._addKind[cat.key] = v
            local typed = box and box.GetText and box:GetText()
            carriedText[cat.key] = type(typed) == "string" and typed ~= "" and typed or nil
            C_Timer.After(0, function() H.RefreshAllPanels() end)
        end,
    })
    local _, eb = H.IdInput(ctx, scroll, {
        kind       = addByIDKind(cat, specless),
        candidates = not specless and addByIDCandidates(cat, specKey) or nil,
        label      = L["ID, link or name"],
        tooltip    = addByIDTooltip(cat, specless),
        strings    = specless and NO_SPEC_STRINGS or addByIDStrings(cat),
        onAdd      = function(id) addResolvedID(cat, specKey, id) end,
    })
    box, addByIDBox = eb, eb
    local carried = carriedText[cat.key]
    carriedText[cat.key] = nil
    if carried and eb and eb.SetText then eb:SetText(carried) end
end

-- The one entry point. settings/Category.lua's renderSingle calls it where the
-- block used to sit, between the category header and the priority list.
KCM.Settings.AddByID = KCM.Settings.AddByID or {}
KCM.Settings.AddByID.Render = renderAddByID
