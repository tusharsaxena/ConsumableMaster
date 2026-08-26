-- settings/Category.lua — Per-category panels (single + composite).
--
-- One tab per row in KCM.Categories.LIST, in CLAUDE.md order. The render
-- function dispatches to single or composite layout based on cat.composite.
--
-- Single category layout:
--   1. KCMMacroDragIcon row.
--   2. Spec-aware subheader (FLASK / CMBT_POT / STAT_FOOD / WPN_ENCH): "Spec-aware. Viewing: <spec>."
--   3. Section "Add item or spell by ID" — Type dropdown | ID input (paired).
--   4. Section "Priority list" — legend label + one row per item:
--        KCMItemRow | KCMScoreButton | drag handle | X
--      The handle drags the row to a new priority. The gesture is
--      LibKa0s-Widgets-1.0's ReorderList, shared with MultiMeters' Columns page.
--   5. Inline "Reset category" button (StaticPopup-confirmed).
--
-- Composite layout (HP_AIO / MP_AIO):
--   1. KCMMacroDragIcon row.
--   2. Subheader description.
--   3. Section "In Combat"     — sub-cat rows (KCMItemRow | Enabled | up | down).
--   4. Section "Out of Combat" — same shape.
--   5. Inline "Reset category" button (StaticPopup-confirmed).
--
-- Reads from Selector / Categories / Ranker / BagScanner / SpecHelper; writes
-- via Selector mutators (AddItem / Block / MoveTo / MoveUp / MoveDown). Every mutation
-- calls afterMutation so the macro pipeline and panels stay in sync.

local _, NS = ...
local KCM = NS
local L      = KCM.L
local H      = KCM.Settings.Helpers
-- Silent-mode (library-stack-§4): AceGUI is an OptionalDep and the hard form
-- raises during load on an install that lacks it. Nothing on this page is
-- reachable without the panel, which settings/OptionsSetup.lua already refuses
-- to build when AceGUI is nil.
local AceGUI = LibStub("AceGUI-3.0", true)

KCM.Options = KCM.Options or {}
local O = KCM.Options
O._addKind = O._addKind or {}

-- Row-widget proportions. KCMItemRow takes the bulk of each row and the four
-- 32px square buttons cluster on the right. Tuned for the standard Settings
-- sub-panel content width (~540px); narrower windows still fit because the
-- buttons remain pixel-fixed and the item row is relative.
local ITEM_ROW_RW_SINGLE    = 0.76
local ITEM_ROW_RW_COMPOSITE = 0.72
local ROW_BTN_W             = 32
-- One priority row's height, named because the drag needs it twice: as the stride its arithmetic
-- runs on, and as the height of the copy it carries under the cursor.
local ROW_H                 = 28
local CHECK_W               = 78

-- The drag handle's art, and the library that owns the gesture behind it.
-- LibKa0s-Widgets-1.0 minor 8 shares this drag with MultiMeters' Columns page:
-- the handle, the copy carried under the cursor, the insertion line and the
-- index arithmetic are all its, and every row above is still entirely ours.
local HANDLE_ICON = "segment"

local function reorderWidgets()
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    return (W and W.ReorderList) and W or nil
end

local OWNED_ICON     = "|TInterface\\RaidFrame\\ReadyCheck-Ready:20|t"
local NOT_OWNED_ICON = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:20|t"
local PICK_ICON      = "|TInterface\\COMMON\\FavoritesIcon:20|t"

local ADD_KIND_OPTIONS = { ITEM = L["Item"], SPELL = L["Spell"] }
local ADD_KIND_SORTING = { "ITEM", "SPELL" }

-- ---------------------------------------------------------------------
-- Lookup helpers (Midnight C_Spell + multi-return GetItemInfo split)
-- ---------------------------------------------------------------------

local function spellNameByID(id)
    return KCM.Compat and KCM.Compat.GetSpellName and KCM.Compat.GetSpellName(id) or nil
end

local function isOwned(id)
    if not id then return false end
    if KCM.ID and KCM.ID.IsSpell(id) then
        local sid = KCM.ID.SpellID(id)
        return sid and IsPlayerSpell and IsPlayerSpell(sid) or false
    end
    return KCM.BagScanner and KCM.BagScanner.HasItem and KCM.BagScanner.HasItem(id) or false
end

local function formatNumber(n)
    if type(n) ~= "number" then return tostring(n) end
    local isWhole = (n == math.floor(n))
    local abs = math.abs(n)
    local body = isWhole and tostring(math.floor(abs)) or ("%.1f"):format(abs)
    local int, rest = body:match("^(%d+)(.*)$")
    if not int then return tostring(n) end
    -- Walk the integer part forward in 3-digit groups so we don't need to
    -- reverse the string. The first group is shorter when len % 3 ~= 0.
    local len = #int
    local first = ((len - 1) % 3) + 1
    local pieces = { int:sub(1, first) }
    for i = first + 1, len, 3 do
        pieces[#pieces + 1] = int:sub(i, i + 2)
    end
    local sepd = table.concat(pieces, ",") .. (rest or "")
    return (n < 0) and ("-" .. sepd) or sepd
end

local function formatScoreTooltipDesc(explain)
    if not explain then return "" end
    local lines = {}
    for _, s in ipairs(explain.signals or {}) do
        local note = s.note and ("  |cff888888(" .. s.note .. ")|r") or ""
        table.insert(lines, ("  %s: |cffffffff%s|r%s")
            :format(s.label or "?", formatNumber(s.value or 0), note))
    end
    if explain.summary and explain.summary ~= "" then
        table.insert(lines, "")
        table.insert(lines, "|cffaaaaaa" .. explain.summary .. "|r")
    end
    return table.concat(lines, "\n")
end

local function afterMutation(reason)
    if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute(reason or "options_mutation")
    end
    H.RefreshAllPanels()
end

-- ---------------------------------------------------------------------
-- StaticPopup for per-category reset. One popup, shared across all
-- category panels — the active catKey is parked in popup.data on show.
-- ---------------------------------------------------------------------

-- The session debug gate for this file's reset diagnostics, in one place
-- instead of once per log site. It stays a PREDICATE rather than a logging
-- wrapper on purpose: Lua evaluates call arguments before the callee runs, so a
-- `dbg(fmt, ...)` wrapper would make KCM.Debug's arguments allocate even with
-- debug off — the standard §12 zero-alloc rule these paths are written to.
-- Today's two call sites pass only a plain string, but the wrapper shape is
-- what makes the NEXT diagnostic (a tostring, a concat, a table) pay silently.
-- Same shape as core/ConsumableMaster.lua's and modules/MacroManager.lua's
-- isDebugOn, and it reads KCM.State directly exactly as the inline sites did.
local function isDebugOn()
    if KCM.State and KCM.State.debug then return true end
    return false
end

-- The composite arm resets exactly these three fields and nothing else.
local AIO_RESET_FIELDS = { "enabled", "orderInCombat", "orderOutOfCombat" }

-- Composite reset: restore the enabled flags and both section orders from the
-- shipped defaults. CopyTable, never an alias — aliasing dbDefaults would let a
-- later edit corrupt the defaults for the rest of the session.
local function resetCompositeCategory(catKey)
    local defaults = KCM.dbDefaults and KCM.dbDefaults.profile
        and KCM.dbDefaults.profile.categories
        and KCM.dbDefaults.profile.categories[catKey]
    local cfg = KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[catKey]
    if not (defaults and cfg) then return end
    for _, f in ipairs(AIO_RESET_FIELDS) do
        cfg[f] = CopyTable(defaults[f] or {})
    end
    if isDebugOn() then KCM.Debug("Prio", "reset %s", catKey) end
    afterMutation("options_aio_reset_cat")
end

-- Single-category reset: clear the user's own edits. `discovered` is
-- deliberately left alone — auto-discovery findings survive a category reset.
local function resetSingleCategory(catKey, specKey)
    local bucket = KCM.Selector and KCM.Selector.GetBucket
        and KCM.Selector.GetBucket(catKey, specKey)
    if not bucket then return end
    bucket.added   = {}
    bucket.blocked = {}
    bucket.pins    = {}
    if isDebugOn() then KCM.Debug("Prio", "reset %s", catKey) end
    afterMutation("options_reset_cat")
end

-- Shared between single + composite reset paths. Caller passes the prompt
-- as the second arg to StaticPopup_Show, which substitutes into %s, and
-- the catKey/specKey/composite payload as the fourth arg (popup.data).
StaticPopupDialogs["KCM_RESET_CATEGORY"] = {
    text         = "%s",
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept = function(self, data)
        if not data then return end
        if data.composite then
            resetCompositeCategory(data.catKey)
        else
            resetSingleCategory(data.catKey, data.specKey)
        end
    end,
}

-- Show the per-category reset confirmation. Shared by the inline "Reset
-- category" buttons and the top-right Defaults button (options-ui-§5) so both
-- entry points land on the same popup with identical scope. For spec-aware
-- single categories the viewed spec is resolved at call time, matching the
-- panel the user is looking at.
local function promptResetCategory(cat)
    if cat.composite then
        local prompt = (L["Reset %s to defaults?"]):format(cat.displayName)
        StaticPopup_Show("KCM_RESET_CATEGORY", prompt, nil, {
            catKey    = cat.key,
            composite = true,
        })
    else
        local specKey = cat.specAware and (O.ResolveViewedSpec and O.ResolveViewedSpec()) or nil
        local prompt = (L["Reset %s%s to defaults?"]):format(
            cat.displayName,
            cat.specAware and L[" (viewed spec)"] or "")
        StaticPopup_Show("KCM_RESET_CATEGORY", prompt, nil, {
            catKey    = cat.key,
            specKey   = specKey,
            composite = false,
        })
    end
end

-- ---------------------------------------------------------------------
-- Small AceGUI builders shared by single + composite renderers
-- ---------------------------------------------------------------------

local function newRow(scroll, height)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    if height then row:SetHeight(height) end
    scroll:AddChild(row)
    return row
end

local function makeIconBtn(parent, opts)
    local btn = AceGUI:Create("KCMIconButton")
    btn:SetImageSize(opts.size or 24, opts.size or 24)
    btn:SetImage(opts.image)
    btn:SetWidth(opts.width or ROW_BTN_W)
    if opts.disabled then btn:SetDisabled(true) end
    if opts.onClick then
        btn:SetCallback("OnClick", function()
            local ok, err = pcall(opts.onClick)
            if not ok then
                KCM.Say("icon-button onClick failed: " .. tostring(err))
            end
        end)
    end
    if opts.tooltip then H.AttachTooltip(btn, opts.label, opts.tooltip) end
    parent:AddChild(btn)
    return btn
end

local function makeScoreBtn(parent, opts)
    local btn = AceGUI:Create("KCMScoreButton")
    btn:SetImageSize(22, 22)
    btn:SetImage(opts.image)
    btn:SetWidth(ROW_BTN_W)
    if opts.tooltip or opts.label then
        H.AttachTooltip(btn, opts.label, opts.tooltip)
    end
    parent:AddChild(btn)
    return btn
end

local function makeItemRow(parent, data, rw)
    local row = AceGUI:Create("KCMItemRow")
    row:SetRelativeWidth(rw or ITEM_ROW_RW_SINGLE)
    row:SetCustomData(data)
    parent:AddChild(row)
    return row
end

local function makeMacroDragIcon(scroll, macroName)
    local w = AceGUI:Create("KCMMacroDragIcon")
    w:SetFullWidth(true)
    w:SetCustomData({ macroName = macroName })
    scroll:AddChild(w)
    return w
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

local function makeEditBox(parent, opts)
    local eb = AceGUI:Create("EditBox")
    if opts.label then eb:SetLabel(opts.label) end
    if opts.relativeWidth then eb:SetRelativeWidth(opts.relativeWidth)
    elseif opts.width    then eb:SetWidth(opts.width)
    else                       eb:SetFullWidth(true) end
    if opts.maxLetters and eb.editbox and eb.editbox.SetMaxLetters then
        eb.editbox:SetMaxLetters(opts.maxLetters)
    end
    if opts.onSubmit then
        -- A successful submit triggers afterMutation → RefreshAllPanels →
        -- ResetScroll, which releases this very widget. SetText after the
        -- handler would be a use-after-release. Skip it: the rebuilt
        -- panel's fresh EditBox starts empty, which is what we want.
        -- On validation failure (no rebuild), the typed text deliberately
        -- persists so the user can fix the typo without re-typing.
        eb:SetCallback("OnEnterPressed", function(_, _, v)
            opts.onSubmit(v)
        end)
    end
    if opts.tooltip then H.AttachTooltip(eb, opts.label, opts.tooltip) end
    parent:AddChild(eb)
    return eb
end

local function makeCheckbox(parent, opts)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(opts.label or "")
    if opts.width then cb:SetWidth(opts.width)
    elseif opts.relativeWidth then cb:SetRelativeWidth(opts.relativeWidth)
    else cb:SetFullWidth(true) end
    cb:SetValue(opts.value and true or false)
    if opts.onChange then
        cb:SetCallback("OnValueChanged", function(_, _, v) opts.onChange(v and true or false) end)
    end
    if opts.tooltip then H.AttachTooltip(cb, opts.label, opts.tooltip) end
    parent:AddChild(cb)
    return cb
end

-- ---------------------------------------------------------------------
-- Single-category render
-- ---------------------------------------------------------------------

-- Drag icon, spec banner and the mouseover toggle — everything above the first Section.
local function renderCategoryHeader(ctx, scroll, cat, specKey)
    makeMacroDragIcon(scroll, cat.macroName)
    H.AddSpacer(scroll, 6)

    if cat.specAware then
        H.Label(ctx,
            (L["Spec-aware. Viewing: %s."]):format(O.FormatSpec and O.FormatSpec(specKey) or tostring(specKey)),
            "medium")
    end

    -- Mouseover toggle — gated on the row field (cat.targeted), not on the
    -- category key, so any future targeted category gets the control for
    -- free. MacroManager.targetClauseFor treats only an explicit `false` as
    -- off, so the write below must always land a real boolean.
    if cat.targeted then
        local bucket = KCM.db.profile.categories[cat.key]
        makeCheckbox(scroll, {
            label = L["Cast on mouseover"],
            tooltip = L["Rez whoever you are hovering (raid frame or corpse), falling back to "
                .. "your target. Turn off to act on your target only."],
            value = bucket.mouseover ~= false,
            onChange = function(v)
                bucket.mouseover = v and true or false
                afterMutation("options_mouseover_toggle")
            end,
        })
        H.AddSpacer(scroll, 4)
    end
end

-- What the Type dropdown's two choices mean to the validator: how to prove the
-- ID exists, what to say when it doesn't, and how to store it. Module-level, so
-- a third kind is one table entry rather than another elseif arm.
local ID_KINDS = {
    SPELL = {
        exists  = function(id) return spellNameByID(id) end,
        unknown = "unknown spellID: ",
        -- Spell IDs go in through the opaque sentinel, never raw, or they
        -- collide with itemIDs.
        store   = function(id) return KCM.ID.AsSpell(id) end,
        -- Shift-clicking a spell out of a spellbook pastes a spell link. Parsed
        -- here rather than in a shared helper because the two kinds' links are
        -- different strings, and this table is where a kind's differences live.
        fromLink = function(text)
            return tonumber(tostring(text):match("|?H?spell:(%d+)"))
        end,
    },
    ITEM = {
        -- Classic/Midnight safety: reject only when the API is PRESENT and says
        -- it doesn't know the ID. An absent API passes the check.
        exists  = function(id)
            return not (C_Item and C_Item.GetItemInfoInstant)
                or C_Item.GetItemInfoInstant(id)
        end,
        unknown = "unknown itemID: ",
        store   = function(id) return id end,
        -- The library's primitive, through the KCM.Item seam so a degraded install
        -- behaves the same. It matches the link's own `item:<id>` segment, so it is
        -- locale-independent and takes a bare itemString as happily as a full link.
        fromLink = function(text) return KCM.Item.ItemIDFromLink(text) end,
    },
}

-- Validate one typed ID and seed it into the category. Every rejection path says why and
-- stops; only a fully-resolved ID reaches Selector.AddItem.
local function submitAddByID(cat, specKey, text)
    local kind = ID_KINDS[O._addKind[cat.key] or "ITEM"] or ID_KINDS.ITEM
    -- Digits first, then the kind's own link parser. Shift-clicking an item out of
    -- the bags is the natural gesture for "add this one" and it pastes a full link,
    -- which this box used to reject with "expected a positive numeric ID" — an
    -- answer that is true and useless. The order matters: a bare number is
    -- unambiguous and must never be run through a link matcher.
    local id = tonumber(text) or (kind.fromLink and kind.fromLink(text))
    if not id or id <= 0 then
        KCM.Say("expected a positive numeric ID or a pasted link; got: " .. tostring(text))
        return
    end
    if not kind.exists(id) then
        KCM.Say(kind.unknown .. id)
        return
    end
    if cat.specAware and not specKey then
        KCM.Say("spec-aware category: no active spec — can't add.")
        return
    end
    local storedID = kind.store(id)
    local changed = KCM.Selector and KCM.Selector.AddItem
        and KCM.Selector.AddItem(cat.key, storedID, specKey)
    if changed then afterMutation("options_add_item") end
end

-- Add by ID (kind selector | ID input, paired 50/50)
local function renderAddByID(ctx, scroll, cat, specKey)
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
        end,
    })
    makeEditBox(addRow, {
        label         = L["ID"],
        tooltip       = L["Enter an itemID or spellID to add to this category. Press Enter to add."],
        relativeWidth = 0.6,
        maxLetters    = 12,
        onSubmit      = function(text) submitAddByID(cat, specKey, text) end,
    })
end

-- Per-hand picks + affinity (Weapon Enchant only). Computed once up front so both the header
-- note and the per-row pickMH/pickOH/applicable flags use the same numbers.
local function computePerHand(cat)
    if not cat.perHand then return nil, nil, nil, nil end
    local Sel = KCM.Selector
    local WS  = KCM.WeaponSlots
    return (Sel and Sel.PickBestForSlot and Sel.PickBestForSlot(cat.key, 16)) or nil,
           (Sel and Sel.PickBestForSlot and Sel.PickBestForSlot(cat.key, 17)) or nil,
           (WS and WS.SlotAffinity and WS.SlotAffinity(16)) or nil,
           (WS and WS.SlotAffinity and WS.SlotAffinity(17)) or nil
end

-- The icon legend above the list, plus the main/off-hand affinity line when per-hand.
local function renderPriorityLegend(ctx, cat, mhAff, ohAff)
    if cat.perHand then
        H.Label(ctx,
            (L["Main hand: %s | Off hand: %s"]):format(mhAff or L["(none)"], ohAff or L["(none)"]),
            "medium")
        H.Label(ctx,
            (L["%s in bags    %s not in bags    %s picked (MH/OH) in macro"]):format(OWNED_ICON, NOT_OWNED_ICON, PICK_ICON),
            "medium")
    else
        H.Label(ctx,
            (L["%s in bags    %s not in bags    %s picked in macro"]):format(OWNED_ICON, NOT_OWNED_ICON, PICK_ICON),
            "medium")
    end
end

-- Per-hand pick/applicability flags for one row. Nil across the board for categories that are
-- not per-hand, which is what makeItemRow expects for "this axis does not apply".
local function perHandFlags(cat, rowID, p)
    if not cat.perHand then return nil, nil, nil end
    local tt  = KCM.TooltipCache and KCM.TooltipCache.Get(rowID)
    local aff = (tt and tt.weaponAffinity) or "any"
    return (p.mh and rowID == p.mh) and true or false,
           (p.oh and rowID == p.oh) and true or false,
           (aff == "any" or aff == p.mhAff or aff == p.ohAff)
end

-- The drag handle and Remove. Each guards the Selector call and only reports a mutation when the
-- Selector says something actually changed.
--
-- THE UP AND DOWN ARROWS ARE GONE, and what replaced them is one handle. Two buttons that each
-- moved a row one place meant reordering a ten-item list was nine clicks and nine macro rebuilds,
-- and the arrows could not express what a player actually wanted -- "put this one third" -- without
-- being clicked until it was. `Selector.MoveTo` says it in one call, and the drag is how a player
-- says it.
--
-- The handle is parented into a fixed-width Flow slot rather than anchored onto the row directly:
-- AceGUI's Flow layout places its own children left to right and knows nothing about a raw frame
-- dropped on top of one, so a handle anchored to the row would sit over the item cell. A slot is a
-- child Flow understands, and it lands exactly where the up arrow used to.
local function renderRowButtons(row, cat, specKey, rowID, list, ghostText)
    local function selectorAction(verb, reason)
        return function()
            local fn = KCM.Selector and KCM.Selector[verb]
            if fn and fn(cat.key, rowID, specKey) then afterMutation(reason) end
        end
    end

    if list then
        local slot = AceGUI:Create("SimpleGroup")
        slot:SetLayout(nil)
        slot:SetWidth(ROW_BTN_W)
        slot:SetHeight(ROW_H)
        row:AddChild(slot)
        list:AddRow(row.frame, {
            parent    = slot.frame or slot.content,
            ghostText = ghostText,
            height    = ROW_H,
        })
    end

    makeIconBtn(row, {
        image    = "atlas:transmog-icon-remove",
        size     = 22,
        label    = L["Remove"],
        tooltip  = L["Remove from this category. Blocks the item so auto-discovery won't re-add it."],
        onClick  = selectorAction("Block", "options_remove"),
    })
end

-- One priority row: the item cell, its score tooltip, and the move/remove buttons.
-- `p` carries the list-wide facts the row reads: rankerCtx, pick, mh, oh, mhAff, ohAff.
local function renderPriorityRow(scroll, cat, specKey, rowID, list, p)
    local explain = KCM.Ranker and KCM.Ranker.Explain
        and KCM.Ranker.Explain(cat.key, rowID, p.rankerCtx) or nil
    local scoreTitle = explain
        and (L["Rank score: %s"]):format(formatNumber(explain.score))
        or L["Rank score"]

    local rowPickMH, rowPickOH, applicableArg = perHandFlags(cat, rowID, p)

    local row = newRow(scroll, ROW_H)
    local itemRow = makeItemRow(row, {
        itemID     = rowID,
        owned      = isOwned(rowID),
        isPick     = (p.pick and rowID == p.pick) and true or false,
        pickMH     = rowPickMH,
        pickOH     = rowPickOH,
        applicable = applicableArg,
    }, ITEM_ROW_RW_SINGLE)
    makeScoreBtn(row, {
        image   = "Interface\\FriendsFrame\\InformationIcon",
        label   = scoreTitle,
        tooltip = formatScoreTooltipDesc(explain),
    })
    -- The name the carried copy reads, taken off the row that just resolved it rather than looked
    -- up a second time: a ghost naming a different string than the row it came from is worse than
    -- one naming nothing.
    local ghostText = itemRow and itemRow.label and itemRow.label:GetText() or nil
    renderRowButtons(row, cat, specKey, rowID, list, ghostText)
end

-- Ranker context shared across rows so every score tooltip uses the same numbers as the
-- effective sort.
local function buildRankerCtx(cat, specKey, priority)
    local rankerCtx
    if cat.specAware and specKey and KCM.SpecHelper and KCM.SpecHelper.GetStatPriority then
        rankerCtx = { specPriority = KCM.SpecHelper.GetStatPriority(specKey) }
    end
    if KCM.Ranker and KCM.Ranker.BuildContext then
        rankerCtx = KCM.Ranker.BuildContext(cat.key, priority, rankerCtx)
    end
    return rankerCtx
end

-- The priority list proper: the no-spec and empty states, or one row per candidate.
local function renderPriorityList(ctx, scroll, cat, specKey, mh, oh, mhAff, ohAff)
    if cat.specAware and not specKey then
        H.Label(ctx,
            L["|cffff8800No active spec.|r Spec-aware categories need a resolvable spec to display a priority list."],
            "medium")
        return
    end

    local priority = (KCM.Selector and KCM.Selector.GetEffectivePriority
        and KCM.Selector.GetEffectivePriority(cat.key, specKey)) or {}
    if #priority == 0 then
        H.Label(ctx,
            L["|cffff8800(empty)|r — no candidates yet. Add an itemID above or pick up a matching item to trigger auto-discovery."],
            "medium")
        return
    end

    local p = {
        rankerCtx = buildRankerCtx(cat, specKey, priority),
        pick = (not cat.perHand) and KCM.Selector and KCM.Selector.PickBestForCategory
            and KCM.Selector.PickBestForCategory(cat.key, specKey) or nil,
        mh = mh, oh = oh, mhAff = mhAff, ohAff = ohAff,
    }

    -- ONE CONTROLLER PER RENDER, and the one before it is told to stop. A drag must not outlive
    -- the list it was describing: the copy it leaves under the cursor names a row that may not be
    -- in the list any more, and every mutation here repaints.
    local W = reorderWidgets()
    if ctx.kcmReorder then ctx.kcmReorder:Cancel() end

    local list = W and W.ReorderList({
        stride     = ROW_H,
        -- No boundary. This list is flat -- every row is a priority and they are all one group --
        -- which is the common case the library defaults to. MultiMeters' Columns page is the one
        -- that divides, because a shown column may not be dragged among the hidden ones.
        handleIcon = KCM.Icon and KCM.Icon(HANDLE_ICON) or nil,
        handleSize = ROW_BTN_W,
        onMove     = function(from, to)
            local id = priority[from]
            if not id then return end
            -- MoveTo, not repeated MoveUp: a drag past several rows is one move, and saying it as
            -- a run of swaps would leave the rows it passed in an order nobody asked for -- and
            -- rebuild the macro once per step on the way.
            if KCM.Selector and KCM.Selector.MoveTo
                and KCM.Selector.MoveTo(cat.key, id, to, specKey) then
                afterMutation("options_move_drag")
            end
        end,
        debug      = (KCM.State and KCM.State.debug and KCM.Debug)
            and function(fmt, ...) KCM.Debug("Prio", fmt, ...) end or nil,
    })
    ctx.kcmReorder = list

    for _, id in ipairs(priority) do
        renderPriorityRow(scroll, cat, specKey, id, list, p)
    end

    -- The insertion line lives on what every row shares as an ancestor.
    if list then list:Finish(scroll.content or scroll.frame) end
end

local function renderSingle(ctx, cat)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    local specKey = cat.specAware and (O.ResolveViewedSpec and O.ResolveViewedSpec()) or nil

    renderCategoryHeader(ctx, scroll, cat, specKey)
    renderAddByID(ctx, scroll, cat, specKey)

    local mh, oh, mhAff, ohAff = computePerHand(cat)

    H.Section(ctx, L["Priority list"])
    renderPriorityLegend(ctx, cat, mhAff, ohAff)
    H.AddSpacer(scroll, 4)
    renderPriorityList(ctx, scroll, cat, specKey, mh, oh, mhAff, ohAff)

    -- Inline reset
    H.AddSpacer(scroll, 12)
    H.Button(ctx, {
        text    = L["Reset category"],
        tooltip = L["Clear added/blocked items and pin overrides for this category"]
                  .. (cat.specAware and L[" (viewed spec only)"] or "")
                  .. L[". Discovered items (from bag scans) are preserved."],
        onClick = function() promptResetCategory(cat) end,
    })

    if scroll.DoLayout then scroll:DoLayout() end
end

-- ---------------------------------------------------------------------
-- Composite render (HP_AIO / MP_AIO)
-- ---------------------------------------------------------------------

local function renderComposite(ctx, cat)
    H.ResetScroll(ctx)
    local scroll = H.EnsureScroll(ctx)

    local cfg = KCM.db and KCM.db.profile and KCM.db.profile.categories
        and KCM.db.profile.categories[cat.key]
    if not cfg then return end

    -- Drag icon
    makeMacroDragIcon(scroll, cat.macroName)
    H.AddSpacer(scroll, 6)

    H.Label(ctx,
        L["Composite macro. Toggle and order the contributing categories below — each category's own ranking and pick logic is edited on its individual panel."],
        "medium")

    local sections = {
        { key = "inCombat",    orderField = "orderInCombat",    label = L["In Combat"]     },
        { key = "outOfCombat", orderField = "orderOutOfCombat", label = L["Out of Combat"] },
    }

    for _, section in ipairs(sections) do
        H.Section(ctx, section.label)
        local orderArr = cfg[section.orderField] or {}

        if #orderArr == 0 then
            H.Label(ctx, L["|cffff8800(no sub-categories)|r"], "medium")
        else
            for i, ref in ipairs(orderArr) do
                local refCat = KCM.Categories.Get(ref)
                local pick   = (KCM.Selector and KCM.Selector.PickBestForCategory)
                    and KCM.Selector.PickBestForCategory(ref) or nil
                local rowIndex = i
                local rowSize  = #orderArr
                local rowRef   = ref
                local sectionOrderField = section.orderField
                local refLabel = refCat and refCat.displayName or rowRef

                local row = newRow(scroll, 28)
                makeItemRow(row, {
                    itemID       = pick,
                    owned        = isOwned(pick),
                    isPick       = false,
                    fallbackName = refLabel,
                }, ITEM_ROW_RW_COMPOSITE)
                makeCheckbox(row, {
                    label    = L["Enabled"],
                    tooltip  = (L["Include %s in the macro body."]):format(refLabel),
                    value    = (cfg.enabled == nil) or (cfg.enabled[rowRef] ~= false),
                    width    = CHECK_W,
                    onChange = function(v)
                        cfg.enabled = cfg.enabled or {}
                        cfg.enabled[rowRef] = v
                        afterMutation("options_aio_toggle")
                    end,
                })
                makeIconBtn(row, {
                    image    = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",
                    label    = L["Move up"],
                    tooltip  = L["Move higher in section order"],
                    disabled = (rowIndex == 1) or (rowSize <= 1),
                    onClick  = function()
                        local arr = cfg[sectionOrderField]
                        if not arr or rowIndex <= 1 then return end
                        arr[rowIndex], arr[rowIndex - 1] = arr[rowIndex - 1], arr[rowIndex]
                        afterMutation("options_aio_move_up")
                    end,
                })
                makeIconBtn(row, {
                    image    = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
                    label    = L["Move down"],
                    tooltip  = L["Move lower in section order"],
                    disabled = (rowIndex == rowSize) or (rowSize <= 1),
                    onClick  = function()
                        local arr = cfg[sectionOrderField]
                        if not arr or rowIndex >= #arr then return end
                        arr[rowIndex], arr[rowIndex + 1] = arr[rowIndex + 1], arr[rowIndex]
                        afterMutation("options_aio_move_down")
                    end,
                })
            end
        end
    end

    -- Inline reset
    H.AddSpacer(scroll, 12)
    H.Button(ctx, {
        text    = L["Reset category"],
        tooltip = L["Restore enabled flags and section order to defaults."],
        onClick = function() promptResetCategory(cat) end,
    })

    if scroll.DoLayout then scroll:DoLayout() end
end

-- ---------------------------------------------------------------------
-- Tab registration — one builder per category, in CLAUDE.md order.
-- ---------------------------------------------------------------------

local function buildCategory(cat)
    return function(mainCategory)
        if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
            return nil
        end
        local panelName = "KCMCatPanel_" .. cat.key
        local ctx = H.CreatePanel(panelName, cat.displayName, {
            panelKey = cat.key:lower(),
            -- Top-right Defaults button (options-ui-§5) → same per-category
            -- reset as this page's inline button.
            defaultsAction = function() promptResetCategory(cat) end,
        })
        H.SetRenderer(ctx, function(c)
            if cat.composite then renderComposite(c, cat)
            else                  renderSingle(c, cat) end
        end)
        return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, cat.displayName)
    end
end

if KCM.Settings and KCM.Settings.RegisterTab and KCM.Categories and KCM.Categories.LIST then
    for _, cat in ipairs(KCM.Categories.LIST) do
        KCM.Settings.RegisterTab(cat.key:lower(), buildCategory(cat))
    end
end
