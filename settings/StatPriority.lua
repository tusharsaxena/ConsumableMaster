-- settings/StatPriority.lua — Stat Priority page.
--
-- Selection: full-width spec dropdown (class+spec icon markup, sorted by
--   stripped class name so the texture markup doesn't pollute the order).
--   The selector is the single source of truth for KCM.Options._viewedSpec —
--   spec-aware category panels (Stat Food, Combat Potion, Flask, Weapon Enchant)
--   read it on each render.
--
-- Priority: paired 50/50 layout —
--    Primary stat   | (empty)
--    Secondary #1   | Secondary #2
--    Secondary #3   | Secondary #4
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

local PRIMARY_OPTIONS   = { STR = L["Strength"], AGI = L["Agility"], INT = L["Intellect"] }
local PRIMARY_SORTING   = { "STR", "AGI", "INT" }
local SECONDARY_OPTIONS = {
    [""]        = L["(none)"],
    CRIT        = L["Critical Strike"],
    HASTE       = L["Haste"],
    MASTERY     = L["Mastery"],
    VERSATILITY = L["Versatility"],
}
local SECONDARY_SORTING = { "", "CRIT", "HASTE", "MASTERY", "VERSATILITY" }

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

local function newPairRow(scroll)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    scroll:AddChild(row)
    return row
end

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

local function emptyHalfCell(parent)
    local g = AceGUI:Create("SimpleGroup")
    g:SetLayout(nil)
    g:SetRelativeWidth(0.5)
    g:SetHeight(20)
    parent:AddChild(g)
    return g
end

-- ---------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------

local function render(ctx)
    H.ResetScroll(ctx)
    local scroll  = H.EnsureScroll(ctx)
    local specKey = resolveViewedSpec()

    H.Section(ctx, L["Selection"])
    local values, sorting = specSelectorValues()
    makeDropdown(scroll, {
        label   = L["Viewing spec"],
        tooltip = L["Select which spec's stat priority you want to edit. This also determines which spec's priority list is shown on the Stat Food, Combat Potion, Flask, and Weapon Enchant tabs."],
        values  = values,
        sorting = sorting,
        value   = O._viewedSpec,
        onChange = function(v)
            O._viewedSpec = v
            O._viewedSpecAuto = (v == currentSpecKey())
            H.RefreshAllPanels()
        end,
    })

    H.Section(ctx, L["Priority"])
    if not specKey then
        H.Label(ctx, L["|cffff8800No spec selected.|r Pick one above to edit its stat priority."], "medium")
        return
    end

    local cur = readStatPriority(specKey)

    -- Primary alone on its row, paired with an empty half-cell so the
    -- dropdown column lines up with the secondary rows below.
    local row1 = newPairRow(scroll)
    makeDropdown(row1, {
        label         = L["Primary stat"],
        tooltip       = L["Dominant stat for this spec. Primary-stat consumables always beat secondary-stat ones regardless of magnitude."],
        values        = PRIMARY_OPTIONS,
        sorting       = PRIMARY_SORTING,
        value         = cur.primary,
        relativeWidth = 0.5,
        onChange      = function(v)
            if writeStatPriority(specKey, function(p) p.primary = v end) then
                afterMutation("options_stat_primary")
            end
        end,
    })
    emptyHalfCell(row1)

    -- Secondary #1 | Secondary #2
    local row2 = newPairRow(scroll)
    -- Secondary #3 | Secondary #4
    local row3 = newPairRow(scroll)
    local rows = { row2, row2, row3, row3 }
    for i = 1, 4 do
        makeDropdown(rows[i], {
            label         = (L["Secondary stat #%d"]):format(i),
            tooltip       = L["Secondary stat ranked at position "] .. i
                            .. L[". Position 1 weighs the most; leave as (none) to truncate the list."],
            values        = SECONDARY_OPTIONS,
            sorting       = SECONDARY_SORTING,
            value         = cur.secondary[i],
            relativeWidth = 0.5,
            onChange      = function(v)
                local changed = writeStatPriority(specKey, function(p)
                    p.secondary[i] = v or ""
                end)
                if changed then afterMutation("options_stat_secondary") end
            end,
        })
    end

    H.AddSpacer(scroll, 8)
    H.Button(ctx, {
        text    = L["Reset stat priority"],
        tooltip = L["Drop user override for this spec. The Ranker falls back to the seed default (Defaults_StatPriority.lua) or the class-primary fallback if no seed exists."],
        onClick = doResetStatPriority,
    })

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
