-- settings/StatPriority.lua — Stat Priority page.
--
-- Banner: the spec picker, pinned above the scroll in the page's chrome band
--   (options-ui-§14) -- class+spec icon markup, sorted by stripped class name so
--   the texture markup doesn't pollute the order. It was a "Selection" SECTION
--   inside the scroll until the redesign; §14 wants the thing a page is editing
--   named at the top of it, where it stays visible while you scroll the controls
--   it governs. It is still the SINGLE source of truth for KCM.Options._viewedSpec
--   -- the spec-aware category tabs (Stat Food, Combat Potion, Flask, Weapon
--   Enchant) read it on each render, and §14's rule that the banner REPLACES a
--   picker rather than mirroring one is why they show the viewed spec as a
--   sentence and offer no second picker of their own.
--
-- Strip: ONE tab, `Priority`, under the banner. A single-section page still draws
--   a strip (options-ui-§13) -- a player who has learned one Ka0s page has learned
--   all of them, and a page that skips the chrome for being small teaches the
--   opposite. It is drawn BEFORE the no-spec empty state, never instead of it:
--   the strip is chrome and must not depend on the data.
--
-- Priority:
--    Primary stat  -- one dropdown spanning BOTH columns (it was a half-cell
--      paired with an invisible one, which is `wide` written out by hand).
--    Secondary stats -- ONE draggable list over the four, replacing the four
--      `Secondary stat #N` dropdowns. ORDER-ONLY semantics: dragging changes the
--      order and nothing else, because writeStatPriority already compacts blanks
--      and duplicates on every write. Whether a stat counts at all is the per-row
--      tick/cross GLYPH you click -- the affordance the old `(none)` dropdown
--      value carried -- and an excluded stat drops to a dimmed, undraggable tail
--      below the boundary, because its position among the others is not stored
--      and a gesture that cannot be saved is worse than no gesture.
--
-- THE ROW IS MULTIMETERS-SHAPED, and that is the point of it. Every draggable
-- list in the collection is meant to read the same (options-ui-§8, §18): the
-- library draws a bounded box behind the whole row and a player learns one row
-- once. This page drew its rows as AceGUI widgets in a Flow group and named the
-- handle's 30px SLOT as the box's parent, so the library boxed the gutter and the
-- row itself had no background -- next to MultiMeters' column list it did not
-- look like the same control. The row is a raw frame now, like that one's blocks:
--
--    [handle gutter] [tick/cross] .......................... [Stat name]
--
-- with the stat's name RIGHT-aligned, the stride wider than the box so rows do
-- not touch, and the two glyph textures MultiMeters already wears, so a player
-- who runs both reads one vocabulary rather than two.
--
-- Reset: inline full-width "Reset stat priority" button at the bottom that
--   drops the user override for the viewed spec; Ranker falls back to the
--   seed default (Defaults_StatPriority.lua) or the class-primary fallback
--   if no seed exists.

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
O._viewedSpec = O._viewedSpec or nil
-- True while _viewedSpec is auto-tracking the player's current spec; flipped
-- false when the user manually picks a spec from the dropdown so an explicit
-- pin survives respec. Re-armed only by the auto-resolve path.
if O._viewedSpecAuto == nil then O._viewedSpecAuto = true end

-- The page's one tab. A literal, because the strip is hand-drawn: this page's
-- content is not schema rows, so there is no `group` for the library to partition
-- on and nothing to derive a tab list from.
local TAB_PRIORITY = "Priority"

local PRIMARY_OPTIONS   = { STR = L["Strength"], AGI = L["Agility"], INT = L["Intellect"] }
local PRIMARY_SORTING   = { "STR", "AGI", "INT" }
local SECONDARY_OPTIONS = {
    CRIT        = L["Critical Strike"],
    HASTE       = L["Haste"],
    MASTERY     = L["Mastery"],
    VERSATILITY = L["Versatility"],
}
-- The canonical order, and the order the EXCLUDED tail is offered in. The
-- included stats carry their own order in the profile; the excluded ones have
-- none to carry, so they take this one and it is stable across repaints.
local SECONDARY_SORTING = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" }

-- One secondary row's height, named because the drag needs it twice: as the
-- stride its arithmetic runs on, and as the height of the copy it carries under
-- the cursor. Uniform across the list, which options-ui-§18 requires -- the drop
-- is arithmetic on the stride, not a hit test.
-- ROW_H is the BOX's height; ROW_STRIDE is top-of-row to top-of-row, and the
-- difference between them is the gap between two rows. The library does its drop
-- arithmetic on the stride, so the two must be declared together or a drop lands
-- a row short. Same pair, same reason, as MultiMeters' BLOCK_HEIGHT / BLOCK_STRIDE.
local ROW_H       = 28
local ROW_STRIDE  = ROW_H + 4
local HANDLE_ICON = "segment"

-- The gap between the handle's gutter and the first thing after it. The gutter
-- itself is the library's (see handleGutter below); this is the breathing room,
-- and without it the glyph sat flush against the handle.
local GLYPH_GAP  = 12
local GLYPH_SIZE = 18

-- The same two textures MultiMeters' column blocks wear, and the same two the
-- Macros page's priority rows use for "in bags" / "not in bags". One glyph
-- vocabulary across the collection.
local INCLUDED_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
local EXCLUDED_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- How far the stat's name is held off the row's right edge.
local LABEL_INSET = 12

-- The handle's GUTTER IS THE LIBRARY'S (options-ui-§18): lib.ROW_BOX.HANDLE_W is the fixed width
-- every draggable list in the collection reads at, and it moved 24 -> 30 for this pass. Read, never
-- restated -- and `handleSize` is deliberately not passed to ReorderList, so the widget's own
-- default is the one thing that decides how wide the handle is. Same shape as
-- settings/Category.lua's.
local HANDLE_W_FALLBACK = 30

local function reorderWidgets()
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    return (W and W.ReorderList) and W or nil
end

local function handleGutter()
    local W = reorderWidgets()
    local box = W and W.ROW_BOX
    return (box and box.HANDLE_W) or HANDLE_W_FALLBACK
end

local function currentSpecKey()
    if KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
        local _, _, key = KCM.SpecHelper.GetCurrent()
        return key
    end
    return nil
end

local function resolveViewedSpec()
    -- When the user has pinned a spec manually, honor the pin even after respec.
    -- Otherwise, follow the player's current spec so the page tracks live state.
    if O._viewedSpec and not O._viewedSpecAuto then return O._viewedSpec end
    local cur = currentSpecKey()
    if cur then
        O._viewedSpec = cur
        O._viewedSpecAuto = true
    end
    return O._viewedSpec
end
O.ResolveViewedSpec = resolveViewedSpec

local specLabelCache = {}
local function formatSpec(specKey)
    if not specKey then return L["(no active spec)"] end
    local cached = specLabelCache[specKey]
    if cached then return cached end

    local classID, specID = specKey:match("^(%d+)_(%d+)$")
    classID, specID = tonumber(classID), tonumber(specID)
    if not (classID and specID) then return specKey end

    local className = tostring(classID)
    if GetClassInfo then
        local n = GetClassInfo(classID)
        if n then className = n end
    end

    local specName, specIcon
    if KCM.Compat.GetNumSpecializationsForClassID and KCM.Compat.GetSpecializationInfoForClassID then
        for i = 1, (KCM.Compat.GetNumSpecializationsForClassID(classID) or 0) do
            local sid, name, _, icon = KCM.Compat.GetSpecializationInfoForClassID(classID, i)
            if sid == specID then specName = name; specIcon = icon; break end
        end
    end

    local label = ("%s — %s"):format(className, specName or tostring(specID))
    if specIcon then label = ("|T%s:16|t %s"):format(specIcon, label) end
    specLabelCache[specKey] = label
    return label
end
O.FormatSpec = formatSpec

local function specSelectorValues()
    local values, sorting = {}, {}
    if not (KCM.SpecHelper and KCM.SpecHelper.AllSpecs) then
        return values, sorting
    end
    for _, row in ipairs(KCM.SpecHelper.AllSpecs()) do
        values[row.specKey] = formatSpec(row.specKey)
        table.insert(sorting, row.specKey)
    end
    -- Sort by the label with texture markup stripped so "|T...|t Shaman ..."
    -- sorts under "S" (Shaman), not under "|".
    local function strip(s) return (s:gsub("|T.-|t%s*", "")) end
    table.sort(sorting, function(a, b)
        return strip(values[a] or "") < strip(values[b] or "")
    end)
    return values, sorting
end

local function readStatPriority(specKey)
    if not (KCM.SpecHelper and KCM.SpecHelper.GetStatPriority) or not specKey then
        return { primary = "STR", secondary = { "", "", "", "" } }
    end
    local p = KCM.SpecHelper.GetStatPriority(specKey)
    local secondary = {}
    for i = 1, 4 do secondary[i] = (p.secondary and p.secondary[i]) or "" end
    return { primary = p.primary or "STR", secondary = secondary }
end

local function writeStatPriority(specKey, mutate)
    if not specKey or not (KCM.db and KCM.db.profile) then return false end
    local cur = readStatPriority(specKey)
    mutate(cur)
    -- Drop empties and duplicates while preserving first-seen order. A
    -- duplicate would otherwise weight the same stat twice in Ranker.Score.
    -- THIS is why the list's semantics are order-only: the compaction happens on
    -- every write regardless of what the UI offered, so a drag has nothing left
    -- to express beyond the order.
    local compacted, seen = {}, {}
    for _, s in ipairs(cur.secondary) do
        if s and s ~= "" and not seen[s] then
            seen[s] = true
            table.insert(compacted, s)
        end
    end
    KCM.db.profile.statPriority = KCM.db.profile.statPriority or {}
    KCM.db.profile.statPriority[specKey] = {
        primary   = cur.primary,
        secondary = compacted,
    }
    return true
end

--- The stored list, split into what is RANKED and what is not.
---
--- The included half is the stored order verbatim, minus blanks, duplicates and
--- anything that is not one of the four real stats -- the same three rules
--- writeStatPriority's compaction applies, restated here because the reader has
--- to agree with the writer or a row would appear that no write could produce.
--- The excluded half is everything else, in the canonical order: their position
--- among each other is not stored, so it is a display order rather than data.
---
--- Published for the suite, which can read a split back but cannot read a row
--- order off a mocked AceGUI container.
local function splitSecondaries(stored)
    local included, seen = {}, {}
    for _, stat in ipairs(stored or {}) do
        if SECONDARY_OPTIONS[stat] and not seen[stat] then
            seen[stat] = true
            included[#included + 1] = stat
        end
    end
    local excluded = {}
    for _, stat in ipairs(SECONDARY_SORTING) do
        if not seen[stat] then excluded[#excluded + 1] = stat end
    end
    return included, excluded
end
O.SplitSecondaries = splitSecondaries

--- Store one new secondary ORDER. Everything the list can do -- a drag and an
--- Include toggle alike -- ends here, as ONE write.
local function writeSecondaryOrder(specKey, order)
    return writeStatPriority(specKey, function(p) p.secondary = order end)
end

local function afterMutation(reason)
    if KCM.Pipeline and KCM.Pipeline.RequestRecompute then
        KCM.Pipeline.RequestRecompute(reason or "options_mutation")
    end
    H.RefreshAllPanels()
end

-- Drop the user override for the currently-viewed spec (resolved at call
-- time). Shared by the inline "Reset stat priority" button and the top-right
-- Defaults button (options-ui-§5) so both reset the same spec the user is
-- looking at.
local function doResetStatPriority()
    local specKey = resolveViewedSpec()
    if not (KCM.db and KCM.db.profile and specKey) then return end
    KCM.db.profile.statPriority = KCM.db.profile.statPriority or {}
    if KCM.db.profile.statPriority[specKey] then
        KCM.db.profile.statPriority[specKey] = nil
        afterMutation("options_stat_reset")
    end
end

-- ---------------------------------------------------------------------
-- Widget builders
-- ---------------------------------------------------------------------

local function makeDropdown(parent, opts)
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(opts.label or "")
    dd:SetList(opts.values or {}, opts.sorting)
    if opts.relativeWidth then dd:SetRelativeWidth(opts.relativeWidth)
    elseif opts.width    then dd:SetWidth(opts.width)
    else                       dd:SetFullWidth(true) end
    dd:SetValue(opts.value)
    if opts.onChange then
        dd:SetCallback("OnValueChanged", function(_, _, v) opts.onChange(v) end)
    end
    if opts.tooltip then
        H.AttachTooltip(dd, opts.label, opts.tooltip)
    end
    parent:AddChild(dd)
    return dd
end

local function newRow(scroll, height)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    if height then row:SetHeight(height) end
    scroll:AddChild(row)
    return row
end

-- ---------------------------------------------------------------------
-- The stat row's frame, and why this file pools it
-- ---------------------------------------------------------------------
--
-- A row is a raw frame, not AceGUI widgets in a Flow group, because what it draws
-- is a glyph the library boxes and a name held against the row's right edge --
-- neither of which Flow can express, and both of which MultiMeters' column blocks
-- already draw exactly this way.
--
-- THE ROWS ARE POOLED HERE, and the reason is a bug MultiMeters paid for first
-- (settings/ColumnBlocks.lua): H.ResetScroll hands every AceGUI container on the
-- page back to AceGUI's PROCESS-WIDE pool, keyed only by widget type. A raw frame
-- parented to one of those containers is not an AceGUI widget, so AceGUI neither
-- hides it nor knows it exists -- it rides the released container into whatever
-- asks for a SimpleGroup next, which on an options page is a spacer, a heading or
-- a grid row. So a row is taken from a free list here and RELEASED on the next
-- render: hidden, unanchored and reparented off the AceGUI frame in one step.
--
-- Every script reads the stat off the FRAME at fire time (`row.kcmStat`) rather
-- than off an upvalue captured when it was wired -- a closure over the stat made
-- a recycled row toggle whatever it used to be.

local rowPool, rowAttic = {}, nil

local function attic()
    if not rowAttic then
        rowAttic = CreateFrame("Frame", nil, UIParent)
        rowAttic:Hide()
    end
    return rowAttic
end

--- Give every row from the previous render back to the free list.
local function releaseRows(ctx)
    local live = ctx and ctx.kcmStatRows
    if not live then return 0 end
    local n = #live
    for i = n, 1, -1 do
        local row = live[i]
        live[i] = nil
        row.kcmStat   = nil
        row.kcmToggle = nil
        row:Hide()
        row:ClearAllPoints()
        row:SetParent(attic())
        rowPool[#rowPool + 1] = row
    end
    return n
end

--- One row frame, from the free list or newly built, filling `parent` horizontally.
local function acquireRow(parent)
    local row = table.remove(rowPool)
    if row then
        row:SetParent(parent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        return row
    end

    row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    row:SetHeight(ROW_H)

    -- The include toggle. A BUTTON with two textures rather than a checkbox with
    -- the word "Include" beside it: the tick already says it, and the word was
    -- spending a third of the row repeating the glyph.
    local glyph = CreateFrame("Button", nil, row)
    glyph:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    glyph:SetPoint("LEFT", row, "LEFT", handleGutter() + GLYPH_GAP, 0)
    glyph:EnableMouse(true)
    glyph:SetScript("OnClick", function()
        if row.kcmToggle then row.kcmToggle(row.kcmStat) end
    end)
    -- WHAT THE CLICK WILL DO, not what the glyph currently means -- the question a
    -- player has over a control is what happens if they press it. Read off the row
    -- at HOVER time, so a recycled row never offers the last render's promise.
    glyph:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(row.kcmIncluded and L["Click to stop ranking this stat"]
            or L["Click to rank this stat"], 1, 1, 1)
        GameTooltip:AddLine(L["An excluded stat is not weighed at all; its place in the order is only stored while it is included."],
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    glyph:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    row.kcmGlyph = glyph

    row.kcmLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.kcmLabel:SetPoint("RIGHT", row, "RIGHT", -LABEL_INSET, 0)
    row.kcmLabel:SetJustifyH("RIGHT")

    return row
end

--- Re-point one row at the stat it is serving THIS render.
local function applyRow(row, stat, included, onToggle)
    row.kcmStat     = stat
    row.kcmIncluded = included and true or false
    row.kcmToggle   = onToggle
    row.kcmGlyphTexture = included and INCLUDED_TEX or EXCLUDED_TEX
    row.kcmGlyph:SetNormalTexture(row.kcmGlyphTexture)

    row.kcmLabel:SetText(SECONDARY_OPTIONS[stat] or stat)
    -- Greyed rather than hidden: a name you cannot read is a row you cannot aim
    -- at, and aiming at it is how you rank the stat again.
    if included then
        row.kcmLabel:SetTextColor(1, 0.82, 0)
    else
        row.kcmLabel:SetTextColor(0.5, 0.5, 0.5)
    end

    row:SetHeight(ROW_H)
    row:Show()
end

-- Stop the previous render's drag and give its handles and row boxes back.
--
-- CALLED AT THE TOP OF THE RENDER, BEFORE THE FIRST WIDGET IS CREATED, and that
-- order is the whole of it. Releasing a handle is what takes it off the AceGUI
-- container it was parented to, and ResetScroll hands every container on this
-- page back to AceGUI's process-wide pool -- where the next thing to ask for a
-- SimpleGroup gets one with a live handle still sitting on it.
--
-- ONE controller, not a list: this page draws a single reorder list, where
-- settings/Category.lua's composite page draws two and its seam holds both.
--
-- The ROW FRAMES go back on the same seam and for the same reason -- they are raw
-- frames parented to AceGUI containers ResetScroll is about to pool, so a row not
-- released here reappears on whatever asks for a SimpleGroup next.
local function cancelReorder(ctx)
    releaseRows(ctx)
    local list = ctx and ctx.kcmReorder
    if not list then return end
    list:Cancel()
    ctx.kcmReorder = nil
end

-- ---------------------------------------------------------------------
-- The secondary-stat list
-- ---------------------------------------------------------------------

--- Flip one stat in or out of the ranking. Taken at file scope rather than
--- closed over per row, because the row frames are POOLED: a handler that
--- captured its stat would keep toggling the stat the row used to serve. The
--- stat comes in as an argument, read off the frame at click time.
local function toggleSecondary(specKey, stat)
    local cur   = readStatPriority(specKey)
    local order = splitSecondaries(cur.secondary)
    local wasIncluded = false
    local next_ = {}
    for _, s in ipairs(order) do
        if s == stat then wasIncluded = true else next_[#next_ + 1] = s end
    end
    -- Included joins the END of the order rather than a remembered slot: an
    -- excluded stat's position is not stored, so there is no slot to go back to
    -- and pretending otherwise would invent data.
    if not wasIncluded then next_[#next_ + 1] = stat end
    if writeSecondaryOrder(specKey, next_) then
        afterMutation("options_stat_include")
    end
end

--- One stat's row: the handle's gutter, the include glyph, and the stat's name
--- against the right edge.
---
--- `included` is the glyph's state and `draggable` is whether the drag applies;
--- they agree today and are passed separately because they answer different
--- questions -- one is the stored fact, the other is what this row offers.
---
--- The SLOT is an AceGUI SimpleGroup a stride tall; the row frame inside it is
--- ROW_H tall and anchored to its top, and the difference is the gap between two
--- rows. Going through AceGUI for the LAYOUT and no further is what keeps the rows
--- flowing with the rest of the page without asking AceGUI for a widget it does
--- not have.
local function renderSecondaryRow(ctx, scroll, specKey, stat, included, list, draggable)
    local slot = AceGUI:Create("SimpleGroup")
    slot:SetLayout(nil)
    slot:SetFullWidth(true)
    slot:SetHeight(ROW_STRIDE)
    scroll:AddChild(slot)

    local row = acquireRow(slot.frame or slot.content)
    applyRow(row, stat, included, function(which)
        toggleSecondary(specKey, which)
    end)
    ctx.kcmStatRows[#ctx.kcmStatRows + 1] = row

    if list then
        -- NO `parent`: the box and the handle both default to the frame registered
        -- here, which is the whole row. Naming the handle's slot -- which this used
        -- to do -- drew the library's fill and 1px edge around the 30px gutter and
        -- left the row itself bare, so this list looked unlike every other
        -- draggable list in the collection.
        list:AddRow(row, {
            ghostText      = SECONDARY_OPTIONS[stat] or stat,
            ghostIcon      = row.kcmGlyphTexture,
            ghostTextColor = included and { 1, 0.82, 0 } or { 0.5, 0.5, 0.5 },
            height         = ROW_H,
            draggable      = draggable,
            -- An excluded stat is present but inert, so its box takes the muted
            -- variant -- the library's, never a second one drawn here.
            dimmed         = not draggable,
        })
    end
end

-- The secondary list proper. ONE controller, over the four stats: the included
-- ones first and draggable, the excluded ones after and not. `boundary` is what
-- stops a drag crossing between the two, and it is the widget's rule rather than
-- a hope -- the excluded stats' order is not stored anywhere, so a drag that
-- could reach them would be a gesture with nothing to save.
local function renderSecondaries(ctx, scroll, specKey, cur)
    local included, excluded = splitSecondaries(cur.secondary)

    -- Parked on the ctx so the NEXT render can hand them back, and so a case can
    -- reach a row on a page whose ctx the toolkit otherwise keeps private.
    ctx.kcmStatRows = {}

    local W = reorderWidgets()
    local list = W and W.ReorderList({
        -- The STRIDE, not the row height: the library's drop arithmetic is
        -- top-of-row to top-of-row, so a stride equal to the box would put every
        -- drop one gap short by the bottom of the list.
        stride   = ROW_STRIDE,
        boundary = #included,
        handleIcon    = KCM.Icon and KCM.Icon(HANDLE_ICON) or nil,
        handleTooltip = L["Drag to reorder"],
        onMove   = function(from, to)
            -- A SPLICE TO INDEX, one write and one re-render. Saying a four-place
            -- move as a run of adjacent swaps would leave the rows it passed in an
            -- order nobody asked for and recompute the ranking once per step.
            local moved = table.remove(included, from)
            if not moved then return end
            table.insert(included, to, moved)
            if writeSecondaryOrder(specKey, included) then
                afterMutation("options_stat_reorder")
            end
        end,
        debug = (KCM.State and KCM.State.debug and KCM.Debug)
            and function(fmt, ...) KCM.Debug("Prio", fmt, ...) end or nil,
    })
    ctx.kcmReorder = list

    for _, stat in ipairs(included) do
        renderSecondaryRow(ctx, scroll, specKey, stat, true, list, true)
    end
    for _, stat in ipairs(excluded) do
        renderSecondaryRow(ctx, scroll, specKey, stat, false, list, false)
    end

    -- The insertion line lives on what every row shares as an ancestor.
    if list then list:Finish(scroll.content or scroll.frame) end
end

-- ---------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------

--- Everything below the strip, for a spec that resolved.
local function renderPriority(ctx, scroll, specKey)
    local cur = readStatPriority(specKey)

    -- WIDE: the primary stat spans both columns. It used to be a half-cell paired
    -- with an invisible one, which is what `wide` says in a schema and what
    -- SetFullWidth says here.
    local row1 = newRow(scroll)
    makeDropdown(row1, {
        label    = L["Primary stat"],
        tooltip  = L["Dominant stat for this spec. Primary-stat consumables always beat secondary-stat ones regardless of magnitude."],
        values   = PRIMARY_OPTIONS,
        sorting  = PRIMARY_SORTING,
        value    = cur.primary,
        onChange = function(v)
            if writeStatPriority(specKey, function(p) p.primary = v end) then
                afterMutation("options_stat_primary")
            end
        end,
    })

    H.Section(ctx, L["Secondary stats"])
    H.Label(ctx, L["Drag to rank. Position 1 weighs the most; an excluded stat is not weighed at all."], "medium")
    -- Room between the sentence and the first row. It was 4, which read as the
    -- text sitting on top of the list.
    H.AddSpacer(scroll, 8)
    renderSecondaries(ctx, scroll, specKey, cur)

    H.AddSpacer(scroll, 12)
    H.Button(ctx, {
        text    = L["Reset stat priority"],
        tooltip = L["Drop user override for this spec. The Ranker falls back to the seed default (Defaults_StatPriority.lua) or the class-primary fallback if no seed exists."],
        onClick = doResetStatPriority,
    })
end

local function render(ctx)
    -- BEFORE ResetScroll and before the first widget is created -- see cancelReorder.
    cancelReorder(ctx)
    H.ResetScroll(ctx)

    local specKey = resolveViewedSpec()

    -- The page banner (options-ui-§14), NOT a row in the scroll: the picker for
    -- what this page is editing belongs above the page, pinned, where it stays
    -- readable while you scroll the priorities it governs. Drawn BEFORE the strip,
    -- because it records its own share of the chrome band and the strip's
    -- reservation adds to it; the other way round the strip would not know.
    local values, sorting = specSelectorValues()
    H.PageBanner(ctx, {
        label   = L["Viewing spec"],
        tooltip = L["Select which spec's stat priority you want to edit. This also determines which spec's priority list is shown on the Macros page's Stat Food, Combat Potion, Flask and Weapon Enchant tabs."],
        list    = values,
        order   = sorting,
        value   = O._viewedSpec,
        onSelect = function(v)
            O._viewedSpec = v
            O._viewedSpecAuto = (v == currentSpecKey())
            H.RefreshAllPanels()
        end,
    })

    -- ONE TAB, AND IT IS STILL A STRIP (options-ui-§13). The page has a single
    -- section, and the rule is not a size threshold: a player who has learned one
    -- Ka0s page has learned all of them, and this page dropping the chrome for
    -- being small is what taught the opposite. Drawn UNCONDITIONALLY and before
    -- the no-spec empty state -- that early return used to sit above everything
    -- and take the strip with it.
    H.TabStrip(ctx, {
        tabs  = { {
            key     = TAB_PRIORITY,
            label   = L["Priority"],
            tooltip = L["The primary stat and the ranked secondary stats for the spec named above."],
        } },
        value = TAB_PRIORITY,
        -- One tab, so a click is already on the selection and there is nothing to
        -- switch to. Declared all the same: the strip is a real strip, not a label.
        onSelect = function() end,
    })

    local scroll = H.EnsureScroll(ctx)

    if not specKey then
        -- CONTENT INSIDE THE PAGE, under the strip, rather than a branch that
        -- skips it.
        H.Label(ctx, L["|cffff8800No spec selected.|r Pick one in the banner above to edit its stat priority."], "medium")
    else
        renderPriority(ctx, scroll, specKey)
    end

    if scroll.DoLayout then scroll:DoLayout() end
end

local function Build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end
    local ctx = H.CreatePanel("KCMStatPriorityPanel", L["Stat Priority"], {
        panelKey = "statpriority",
        -- Top-right Defaults button (options-ui-§5) → drops the viewed spec's
        -- override, same as this page's inline reset.
        defaultsAction = doResetStatPriority,
    })
    H.SetRenderer(ctx, render)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Stat Priority"])
end

if KCM.Settings and KCM.Settings.RegisterTab then
    KCM.Settings.RegisterTab("statpriority", Build)
end
