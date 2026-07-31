-- settings/Panel.lua — Settings UI framework.
--
-- Mirrors the KickCD pattern: every page (parent + sub-tabs) is registered as
-- a canvas-layout subcategory and shares one header (title + atlas divider)
-- built by Helpers.CreatePanel. Each tab module (settings/General.lua,
-- StatPriority.lua, Category.lua) hands a builder to RegisterTab; this file
-- iterates the builders once Blizzard_Settings is ready.
--
-- Public surface preserved for the rest of the addon:
--   KCM.Options.Refresh / RequestRefresh / Open  (Core, Debug, SlashCommands,
--      Pipeline). Registration itself is driven by this file's own
--      PLAYER_LOGIN / ADDON_LOADED bootstrap, which calls registerPanel
--      directly; KCM.Settings.Register is the named alias for it.
--   KCM.Settings.Helpers + KCM.Settings.Schema  (SlashCommands /cm list/get/set)

local _, NS = ...
local KCM = NS
local L = KCM.L
local AceGUI = LibStub("AceGUI-3.0")

KCM.Settings         = KCM.Settings         or {}
KCM.Settings.Schema  = KCM.Settings.Schema  or {}
KCM.Settings.builders= KCM.Settings.builders or {}
KCM.Settings.sub     = KCM.Settings.sub     or {}
KCM.Settings._panels = KCM.Settings._panels or {}
KCM.Settings.main    = nil

-- Canonical tab order (the explicit display order for the settings sub-pages;
-- independent of Categories.LIST and functionally cosmetic). General + Stat
-- Priority lead, then the basic consumables, the two AIO composites, the
-- spec-aware categories + Augment Rune, and Vantus Rune last. Kept in sync
-- with the panel/tab order in docs/agent-context.md.
KCM.Settings.order = KCM.Settings.order or {
    "general", "statpriority", "macrobar",
    "food", "drink", "hp_pot", "mp_pot", "hs",
    "hp_aio", "mp_aio",
    "flask", "cmbt_pot", "stat_food", "wpn_ench", "aug_rune", "vantus",
}

local Helpers = KCM.Settings.Helpers or {}
KCM.Settings.Helpers = Helpers

KCM.Options = KCM.Options or {}
local O = KCM.Options

local PANEL_TITLE   = L["Ka0s Consumable Master"]
local PADDING_X     = 16
local HEADER_TOP    = 20
local HEADER_HEIGHT = 54

-- Combat-lockdown open refusal (options-ui-§2): both the O.Open slash path and
-- the Blizzard AddOns-sidebar OnShow guard funnel through here so they emit the
-- one canonical gray notice via the shared secret-safe seam, never a protected
-- category-switch and never a silent no-op.
local function sayCombatOpenBlocked()
    KCM.Say("|cff808080cannot open settings during combat — Blizzard's category-switch is protected|r")
end

-- Vertical rhythm, matched to Ka0s KickCD's settings pages (the house
-- reference). The one that was missing here is ROW_VSPACER: KickCD emits it
-- after EVERY grid row, which is what stops stacked slider/dropdown pairs from
-- running together — without it the page reads as a compressed wall.
--
-- The section spacers stack on top of that trailing row spacer, so the real gap
-- above a heading is SECTION_TOP_SPACER + ROW_VSPACER = 18px. That's why the top
-- spacer looks small on its own; don't "fix" it by raising it without checking
-- what precedes the heading.
--
-- The two section spacers themselves are LibKa0s-Options-1.0's now (its
-- LAYOUT table carries the same 10 and 6), so only the ones this file still
-- emits are declared here. The note above stays because the ARITHMETIC is
-- still the reason the top gap looks small, and that reasoning lives with the
-- rows it explains rather than in the library.
local SECTION_HEADING_H     = 26
local ROW_VSPACER           = 8
local DEFAULTS_W            = 110    -- top-right per-page Defaults button (standard §6.5)
local BUTTON_PAIR_REL       = 0.492  -- paired action-button relative width (standard §6.8)

local LOGO_TEXTURE = [[Interface\AddOns\ConsumableMaster\media\logos\consumemaster.logo.tga]]
local LOGO_PIXELS  = 300

-- ---------------------------------------------------------------------
-- db.profile path helpers
-- ---------------------------------------------------------------------

function Helpers.Resolve(path)
    if not (KCM.db and KCM.db.profile) then return nil, nil end
    local segments = {}
    for part in string.gmatch(path or "", "[^.]+") do
        segments[#segments + 1] = part
    end
    if #segments == 0 then return nil, nil end
    local parent = KCM.db.profile
    for i = 1, #segments - 1 do
        parent = parent[segments[i]]
        if type(parent) ~= "table" then return nil, nil end
    end
    return parent, segments[#segments]
end

function Helpers.Get(path)
    local parent, key = Helpers.Resolve(path)
    if not parent then return nil end
    return parent[key]
end

function Helpers.Set(path, value)
    local parent, key = Helpers.Resolve(path)
    if not parent then return false end
    parent[key] = value
    if KCM.State and KCM.State.debug then
        KCM.Debug("Set", "%s = %s", tostring(path), tostring(value))
    end
    return true
end

function Helpers.FindSchema(path)
    for _, def in ipairs(KCM.Settings.Schema) do
        if def.path == path then return def end
    end
    return nil
end

local _validPanels = {
    general = true, statpriority = true, macrobar = true,
    food = true, drink = true, hp_pot = true, mp_pot = true, hs = true, vantus = true,
    flask = true, cmbt_pot = true, stat_food = true, wpn_ench = true, aug_rune = true,
    hp_aio = true, mp_aio = true,
}
local _validSections = { general = true, macrobar = true }
local _validTypes    = { bool = true, number = true, string = true, color = true }

local function _printSchemaError(prefix, msg)
    KCM.Say("|cffff0000schema error|r: " .. prefix .. ": " .. msg)
end

function Helpers.ValidateSchema()
    local errors = 0
    for i, def in ipairs(KCM.Settings.Schema) do
        local where = "row #" .. i .. " (" .. tostring(def.path or "<no path>") .. ")"
        if type(def) ~= "table" then
            _printSchemaError(where, "row is not a table"); errors = errors + 1
        else
            if type(def.path) ~= "string" or def.path == "" then
                _printSchemaError(where, "missing or empty `path`"); errors = errors + 1
            end
            if not _validPanels[def.panel] then
                _printSchemaError(where, "invalid `panel` = " .. tostring(def.panel)); errors = errors + 1
            end
            if not _validSections[def.section] then
                _printSchemaError(where, "invalid `section` = " .. tostring(def.section)); errors = errors + 1
            end
            if not _validTypes[def.type] then
                _printSchemaError(where, "invalid `type` = " .. tostring(def.type)); errors = errors + 1
            end
        end
    end
    return errors
end

-- ---------------------------------------------------------------------
-- LibKa0s-Options-1.0 — the panel shell's seam
-- ---------------------------------------------------------------------
--
-- Everything ABOVE this line is the schema half and stays the addon's: the
-- rows themselves, Resolve / Get / Set / FindSchema / ValidateSchema, and (far
-- below) the SetAndRefresh write seam. None of it touches the library, which is
-- what keeps `/cm list|get|set` working on an install where LibKa0s is missing.
--
-- What the library supplies is chrome: the panel factory, the lazy Defaults
-- button, the scroll container and the always-visible scrollbar patch. That
-- last block was hand-transcribed from KickCD — the comment above it said so
-- outright — and sits in the same shape in every Ka0s addon, which is the drift
-- the library exists to end. The metrics were compared constant by constant
-- before the swap (padding, header height, the three section spacers, the 0.492
-- button-pair inset, the scroll insets, the 20px gutter, the thumb tints, the
-- breadcrumb atlas) and they are identical, so nothing moves on screen.
--
-- Adopted in PARTS, deliberately. The schema-row widget makers further down are
-- NOT the library's: its dropdown reads `values` as a key map where ours is an
-- ordered array of { value =, text = }, its color picker defaults hasAlpha to
-- false where ours defaults it to true (all seven pickers would lose their
-- alpha slider), and its slider commits on mouse-up where ours commits live —
-- which is the whole point of the Macro Bar page's drag preview. Recorded in
-- docs/pending/LEDGER.md as LIBKA0S-04.

local optionsLib = LibStub and LibStub("LibKa0s-Options-1.0", true)
local UI

-- Forward-declared: Section, Grid and the makers below all call it as a local.
local ensureScroll

if optionsLib then
    UI = optionsLib:New({
        -- The one field lib:New validates, and it raises rather than warns: an
        -- anonymous canvas is one /framestack cannot attribute and two addons
        -- can collide on, with nothing visible in game. Reproduces the frame
        -- name this panel has always carried.
        mainPanelName = "KCMMainPanel",

        -- The breadcrumb's left half, so a sub-page reads "<brand> > <page>".
        parentTitle = PANEL_TITLE,

        -- A thunk, not `KCM.Say` bare: the library snapshots the printer at
        -- :New, so a captured value would freeze the load-time function object.
        -- Same note as core/CoreSetup.lua's sink and modules/DebugLog.lua's
        -- print. Inert in the adopted scope — both lines that reach it live in
        -- the panel-registry half we do not use — but passed so a later step
        -- cannot leak an untagged line.
        print = function(line) KCM.Say(line) end,
    })

    -- Restated because the library resolves AceGUI once at :New and re-resolves
    -- it only inside its own CreateOptionsPanel, which this addon never calls.
    UI.AceGUI = AceGUI

    Helpers.PatchAlwaysShowScrollbar = UI.PatchAlwaysShowScrollbar
    ensureScroll = function(ctx) return UI.EnsureScroll(ctx) end
    Helpers.EnsureScroll = ensureScroll

    -- The instance, so the suite can assert IDENTITY against the library rather
    -- than lookalike behavior. Mirrors KCM.DebugLog.instance.
    Helpers.instance = UI
end

-- Whether the panel can be built at all. Read by registerPanel and O.Open far
-- below; the schema half above neither reads it nor needs it.
local libAbsent = not optionsLib

-- Said once, on the first attempt to REACH the panel, never at load: a degraded
-- install still has a working addon and a working CLI, and stapling the notice
-- to every refresh would bury that. The cause clause is core/CoreSetup.lua's;
-- this seam appends only what is unavailable here.
local announcedMissing = false
local function sayPanelUnavailable()
    if announcedMissing then return end
    announcedMissing = true
    if KCM.Say then
        KCM.Say(KCM.LIBKA0S_MISSING ..
            ", so the settings panel is unavailable; every setting is still " ..
            "reachable with /cm list, /cm get and /cm set.")
    end
end

-- ---------------------------------------------------------------------
-- Tooltip helper
-- ---------------------------------------------------------------------

-- Both the tooltip helper and the spacer/section pair below are
-- LibKa0s-Options-1.0's. Kept as file locals as well as published names because
-- the schema-row makers further down call them directly.
local attachTooltip = UI and UI.AttachTooltip
Helpers.AttachTooltip = attachTooltip

-- ---------------------------------------------------------------------
-- Header (title + atlas divider, plus the intent for the top-right Defaults
-- button — the button itself is built lazily; see ensureDefaultsButton).
-- ---------------------------------------------------------------------

local function buildHeader(panel, title, opts)
    -- Sub-pages render with an addon-name breadcrumb prefix so the header
    -- reads as "Ka0s Consumable Master  ›  <Page>". The separator is an
    -- inline atlas (|A:...|a) rather than a font glyph, so it renders the
    -- same regardless of the FontString font or locale fallback. Parent
    -- (About) opts in to the unprefixed form via opts.isMain — the
    -- Blizzard left-tree label (panel.name) is never prefixed.
    local sep = " |A:common-icon-forwardarrow:16:16|a "
    local displayTitle = title
    if not opts.isMain then
        displayTitle = PANEL_TITLE .. sep .. title
    end

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING_X, -HEADER_TOP)
    titleFS:SetText(displayTitle)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PADDING_X, -HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_HEIGHT)
    divider:SetVertexColor(titleFS:GetTextColor())

    -- Top-right per-page Defaults button (standard §6.5). This records the
    -- INTENT only — the widget itself is built lazily by ensureDefaultsButton
    -- on the panel's first OnShow (see the note there for why). The click
    -- handler is known now but the button isn't, so park it on the panel.
    panel.wantsDefaultsButton = opts.defaultsAction and true or false
    if opts.defaultsAction then
        panel.defaultsOnClick = function()
            if InCombatLockdown and InCombatLockdown() then
                KCM.Say("in combat — Defaults is blocked until combat ends.")
                return
            end
            local ok, err = pcall(opts.defaultsAction)
            if not ok then
                KCM.Say("defaults action failed: " .. tostring(err))
            end
        end
    end

    return titleFS, divider
end

-- Build the header's Defaults button once, on the panel's FIRST OnShow.
--
-- It stays an AceGUI Button (standard §6.5) — a raw UIPanelButtonTemplate frame
-- parented straight onto the Blizzard Settings canvas comes out in the canvas's
-- red button skin. But *when* it is created matters just as much as *what*
-- creates it. AceGUI is a SHARED library: UI-skinning addons restyle its widgets
-- by hooking RegisterAsWidget, so a widget created before that hook is installed
-- keeps Blizzard's stock UI-Panel-Button-Up art (the red stone button) for the
-- rest of the session, while everything created afterwards comes out skinned.
--
-- Category registration runs off ADDON_LOADED / PLAYER_LOGIN — i.e. during load
-- — so building the button there is a race against every other addon's load
-- order, one CM wins only because it happens to load after the skinner. Rename
-- the folder or add a skin and the same code renders red. Deferring creation to
-- the first OnShow removes the race outright: by then every addon has loaded.
-- Do NOT "simplify" this back into buildHeader.
local function ensureDefaultsButton(panel)
    if not panel or panel.defaultsButton or not panel.wantsDefaultsButton then return end
    local btn = AceGUI:Create("Button")
    if not (btn and btn.frame) then return end
    btn:SetText(_G.DEFAULTS or L["Defaults"])
    btn:SetWidth(DEFAULTS_W)
    btn.frame:SetParent(panel)
    btn.frame:ClearAllPoints()
    btn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_TOP)
    btn.frame:Show()
    if panel.defaultsOnClick then
        btn:SetCallback("OnClick", panel.defaultsOnClick)
    end
    panel.defaultsButton = btn
end

-- ---------------------------------------------------------------------
-- CreatePanel — Frame compatible with RegisterCanvasLayoutSubcategory
-- with the unified header stamped on top. Returns a `ctx` table the
-- caller threads through Section / RenderField / Button / SetRenderer.
-- ---------------------------------------------------------------------

function Helpers.CreatePanel(name, title, opts)
    opts = opts or {}

    local panel = CreateFrame("Frame", name)
    panel.name = title
    panel:Hide()

    local titleFS, divider = buildHeader(panel, title, opts)
    panel.title   = titleFS
    panel.divider = divider

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -(HEADER_HEIGHT + 8))
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.body = body

    local ctx = {
        panel       = panel,
        body        = body,
        scroll      = nil,           -- lazy AceGUI ScrollFrame
        refreshers  = {},
        lastGroup   = nil,
        panelKey    = opts.panelKey,
        _rendered   = false,
        _dirty      = false,
        _renderFn   = nil,
    }
    KCM.Settings._panels[#KCM.Settings._panels + 1] = ctx
    return ctx
end

-- A panel module calls SetRenderer(ctx, fn) to declare how to render its
-- body. The framework calls fn(ctx) on first show and after every Refresh.
-- The renderer is responsible for releasing existing children before
-- adding new ones (Helpers.ResetScroll handles that).
function Helpers.SetRenderer(ctx, fn)
    ctx._renderFn = fn
    ctx.panel:SetScript("OnShow", function()
        -- Header Defaults button, built here rather than at registration time
        -- so it can't lose the AceGUI skinning load-order race.
        ensureDefaultsButton(ctx.panel)
        -- Block any KCM panel from opening during combat. The Blizzard
        -- AddOns sidebar bypasses O.Open's guard, so this catches both
        -- the slash path and a direct sidebar click.
        if InCombatLockdown and InCombatLockdown() then
            if SettingsPanel and SettingsPanel.Close then
                SettingsPanel:Close()
            elseif HideUIPanel and SettingsPanel then
                HideUIPanel(SettingsPanel)
            end
            sayCombatOpenBlocked()
            return
        end
        -- Render on first show, and re-render when a refresh marked this panel
        -- dirty while it was hidden (both RefreshAllPanels and RefreshScalars
        -- defer off-screen work here to keep mutations from stalling on every
        -- rendered sub-page).
        if ctx._rendered and not ctx._dirty then return end
        ctx._rendered = true
        ctx._dirty = false
        if ctx._renderFn then ctx._renderFn(ctx) end
    end)
end

-- Release scroll children + reset bookkeeping so a fresh render starts on
-- a clean slate. Panels with dynamic content (priority list rows that
-- change as items are added/removed) call this at the top of their
-- renderer; panels rendered once on first OnShow don't need it.
function Helpers.ResetScroll(ctx)
    if ctx.scroll then ctx.scroll:ReleaseChildren() end
    ctx.refreshers = {}
    ctx.lastGroup  = nil
end

-- The always-visible scrollbar patch and the lazy AceGUI scroll container
-- both live in LibKa0s-Options-1.0 now, and are bound at the seam above.
-- The patch's idempotency marker is deliberately shared across the collection
-- (`_ka0sAlwaysScrollbar`, not a per-addon one), so two Ka0s addons can no
-- longer stack two overrides on one pooled AceGUI ScrollFrame.

local function fireOnChange(def, value)
    if def.onChange then
        local ok, err = pcall(def.onChange, value)
        if not ok then
            KCM.Say("onChange for " .. tostring(def.path)
                  .. " failed: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------
-- Section heading (AceGUI Heading with side dividers) + spacers.
-- ---------------------------------------------------------------------

local addSpacer = UI and UI.AddSpacer
Helpers.AddSpacer = addSpacer

-- A wrapper rather than a bare binding, and the one line it adds is
-- load-bearing. The library sets ctx.lastGroup only inside its own two-column
-- flow engine, which this addon does not use — it draws its rows itself. Bound
-- bare, lastGroup would stay nil forever, the "only between sections, never
-- above the first" guard would never fire, and every section after the first
-- would silently lose its 10px top spacer.
function Helpers.Section(ctx, label)
    local h = UI.Section(ctx, label)
    ctx.lastGroup = label
    return h
end

-- ---------------------------------------------------------------------
-- Schema-driven widget creators — one per schema `type`:
--   bool   -> CheckBox
--   number -> Slider   (min / max / step, `isPercent` for 0-1 ratios)
--   string -> Dropdown (enum: def.values = { {value=,text=}, ... })
--   color  -> ColorPicker ({ r, g, b, a } array in the DB)
-- Every one routes its write through Helpers.SetAndRefresh so the widget path
-- and the `/cm set` path share a single validate → write → onChange → refresh
-- seam (standard §4.5).
-- ---------------------------------------------------------------------

local function applyWidth(widget, relativeWidth)
    if relativeWidth then widget:SetRelativeWidth(relativeWidth)
    else widget:SetFullWidth(true) end
end

local function makeCheckbox(ctx, def, parent, relativeWidth)
    parent = parent or ensureScroll(ctx)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(def.label or def.path)
    applyWidth(cb, relativeWidth)
    cb:SetValue(Helpers.Get(def.path) and true or false)

    local function refresh()
        cb:SetValue(Helpers.Get(def.path) and true or false)
    end

    cb:SetCallback("OnValueChanged", function(_, _, value)
        -- Route through the one validate→write→onChange→refresh seam so the
        -- widget path and the /cm set path share identical wiring (standard §4.5).
        Helpers.SetAndRefresh(def.path, value and true or false)
    end)

    attachTooltip(cb, def.label, def.tooltip)
    parent:AddChild(cb)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cb
end

-- Enum rows declare `values` as an ordered array of { value =, text = } so the
-- dropdown's display order is the schema's order (AceGUI's Dropdown needs the
-- key list separately from the key→text map).
local function enumValues(def)
    return type(def.values) == "function" and def.values() or def.values or {}
end
Helpers.EnumValues = enumValues

-- Option list for a LibSharedMedia media type, e.g. LSMValues("border").
-- Schema rows pass this as a FUNCTION, not a table, so the list is re-queried
-- at render / click time — other addons can register media after our schema is
-- declared.
function Helpers.LSMValues(mediaType)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local list = LSM and LSM.List and LSM:List(mediaType) or nil
    if not list or #list == 0 then
        return { { value = "None", text = "None" } }
    end
    local out = {}
    for i, key in ipairs(list) do
        out[i] = { value = key, text = key }
    end
    return out
end

-- Map a schema row's `lsm` media type to the AceGUI widget type registered by
-- libs/AceGUI-3.0-SharedMediaWidgets, which renders each row with a live
-- preview. Rows without `lsm` use the stock Dropdown.
local LSM_WIDGET = {
    border    = "LSM30_Border",
    font      = "LSM30_Font",
    statusbar = "LSM30_Statusbar",
    background = "LSM30_Background",
}

local function makeSlider(ctx, def, parent, relativeWidth)
    parent = parent or ensureScroll(ctx)
    local sl = AceGUI:Create("Slider")
    sl:SetLabel(def.label or def.path)
    sl:SetSliderValues(def.min or 0, def.max or 100, def.step or 1)
    if def.isPercent then sl:SetIsPercent(true) end
    applyWidth(sl, relativeWidth)
    sl:SetValue(tonumber(Helpers.Get(def.path)) or def.default or 0)

    local function refresh()
        sl:SetValue(tonumber(Helpers.Get(def.path)) or def.default or 0)
    end

    sl:SetCallback("OnValueChanged", function(_, _, value)
        Helpers.SetAndRefresh(def.path, tonumber(value))
    end)

    attachTooltip(sl, def.label, def.tooltip)
    parent:AddChild(sl)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return sl
end

local function makeDropdown(ctx, def, parent, relativeWidth)
    parent = parent or ensureScroll(ctx)
    local dd = AceGUI:Create(def.lsm and LSM_WIDGET[def.lsm] or "Dropdown")
    dd:SetLabel(def.label or def.path)
    applyWidth(dd, relativeWidth)

    local function applyList()
        local list, order = {}, {}
        for i, item in ipairs(enumValues(def)) do
            list[item.value] = item.text or tostring(item.value)
            order[i] = item.value
        end
        dd:SetList(list, order)
    end
    applyList()
    dd:SetValue(Helpers.Get(def.path))

    local function refresh()
        applyList()      -- an LSM list can grow as other addons register media
        dd:SetValue(Helpers.Get(def.path))
    end

    dd:SetCallback("OnValueChanged", function(_, _, key)
        Helpers.SetAndRefresh(def.path, key)
        -- The LSM30_* widgets fire OnValueChanged from their row click WITHOUT
        -- calling SetValue first — they assume AceConfigDialog will re-render
        -- the whole widget afterwards. Our canvas panel doesn't, so push the
        -- value back or the dropdown keeps displaying the old name even though
        -- the DB write landed. Idempotent for the stock Dropdown, which already
        -- set its own value before firing.
        dd:SetValue(key)
    end)

    attachTooltip(dd, def.label, def.tooltip)
    parent:AddChild(dd)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return dd
end

local function makeColorPicker(ctx, def, parent, relativeWidth)
    parent = parent or ensureScroll(ctx)
    local cp = AceGUI:Create("ColorPicker")
    cp:SetLabel(def.label or def.path)
    cp:SetHasAlpha(def.hasAlpha ~= false)
    applyWidth(cp, relativeWidth)

    local function current()
        local c = Helpers.Get(def.path) or def.default or {}
        return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
    end
    cp:SetColor(current())

    local function refresh()
        cp:SetColor(current())
    end

    -- BOTH events, deliberately. AceGUI's ColorPicker only fires
    -- OnValueConfirmed from its ALPHA callback, and only when that callback
    -- happens to land after ColorPickerFrame has closed:
    --
    --   if ColorPickerFrame:IsVisible() then Fire("OnValueChanged")
    --   elseif isAlpha then                  Fire("OnValueConfirmed") end
    --
    -- Modern Blizzard pickers don't guarantee that ordering, so listening to
    -- Confirmed alone meant NO color row ever reached the DB — while the widget
    -- still repainted its own swatch from OnValueChanged, so the panel looked
    -- like it had worked. Writing on Changed too costs one restyle per wheel
    -- movement, which is cheap and only lasts while the picker is open.
    local function write(_, _, r, g, b, a)
        Helpers.SetAndRefresh(def.path, { r, g, b, a or 1 })
    end
    cp:SetCallback("OnValueChanged", write)
    cp:SetCallback("OnValueConfirmed", write)

    attachTooltip(cp, def.label, def.tooltip)
    parent:AddChild(cp)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cp
end

function Helpers.RenderField(ctx, def, parent, relativeWidth)
    if def.type == "bool"   then return makeCheckbox(ctx, def, parent, relativeWidth) end
    if def.type == "number" then return makeSlider(ctx, def, parent, relativeWidth) end
    if def.type == "string" then return makeDropdown(ctx, def, parent, relativeWidth) end
    if def.type == "color"  then return makeColorPicker(ctx, def, parent, relativeWidth) end
    return nil
end

-- ---------------------------------------------------------------------
-- Inline action button helpers. `Button` produces a single full-width
-- button on its own row; `ButtonPair` puts two buttons side-by-side at
-- 50/50 width — used by the General page's Maintenance section.
-- ---------------------------------------------------------------------

local function makeButton(parent, spec, relativeWidth)
    local btn = AceGUI:Create("Button")
    btn:SetText(spec.text or "")
    if relativeWidth then btn:SetRelativeWidth(relativeWidth)
    elseif spec.width then btn:SetWidth(spec.width)
    else btn:SetFullWidth(true) end
    btn:SetCallback("OnClick", function()
        if not spec.onClick then return end
        local ok, err = pcall(spec.onClick)
        if not ok then
            KCM.Say("button onClick failed: " .. tostring(err))
        end
    end)
    if spec.disabled then btn:SetDisabled(true) end
    attachTooltip(btn, spec.text, spec.tooltip)
    parent:AddChild(btn)
    return btn
end

function Helpers.Button(ctx, spec)
    local scroll = ensureScroll(ctx)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(28)
    local btn = makeButton(row, spec)
    scroll:AddChild(row)
    return btn
end

function Helpers.ButtonPair(ctx, leftSpec, rightSpec)
    local scroll = ensureScroll(ctx)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(28)
    if leftSpec  then makeButton(row, leftSpec,  BUTTON_PAIR_REL) end
    if rightSpec then makeButton(row, rightSpec, BUTTON_PAIR_REL) end
    scroll:AddChild(row)
end

-- Two-column paired grid for the schema-driven body (standard §6.6). Each item
-- is either a schema def (rendered via RenderField) or a custom descriptor with
-- a `make(ctx, parent, relWidth)` function. Items render two-per-row at 0.5
-- relative width, flushing the SimpleGroup at two children; an item flagged
-- `wide = true` breaks onto its own full-width row.
function Helpers.Grid(ctx, items)
    local scroll = ensureScroll(ctx)
    local row, count = nil, 0
    local function newRow()
        local r = AceGUI:Create("SimpleGroup")
        r:SetLayout("Flow")
        r:SetFullWidth(true)
        return r
    end
    local function flush()
        if row then
            scroll:AddChild(row)
            addSpacer(scroll, ROW_VSPACER)
            row = nil
            count = 0
        end
    end
    local function renderInto(item, parent, relW)
        if item.make then item.make(ctx, parent, relW)
        else Helpers.RenderField(ctx, item, parent, relW) end
    end
    for _, item in ipairs(items) do
        if item.wide then
            flush()
            local r = newRow()
            renderInto(item, r, nil)
            scroll:AddChild(r)
            addSpacer(scroll, ROW_VSPACER)
        else
            if not row then row = newRow() end
            renderInto(item, row, 0.5)
            count = count + 1
            if count == 2 then flush() end
        end
    end
    flush()
end

-- A checkbox backed by an arbitrary get/set pair (e.g. session-only State
-- flags that aren't in the AceDB schema). Registered with the panel's
-- refreshers so a scalar refresh (RefreshScalars) re-syncs it in place.
-- The library spells it SessionCheckbox — a checkbox backed by a get/set pair
-- rather than by a schema row, which is what "custom" always meant here. Same
-- argument order, same return, same refresher registration.
Helpers.CustomCheckbox = UI and UI.SessionCheckbox

-- AceGUI Label with optional fontSize hint ("medium" maps to GameFontHighlight,
-- otherwise GameFontNormalSmall). Used for inline descriptions / legends.
function Helpers.Label(ctx, text, fontSize)
    local scroll = ensureScroll(ctx)
    local lbl = AceGUI:Create("Label")
    lbl:SetText(text or "")
    lbl:SetFullWidth(true)
    if lbl.label and lbl.label.SetFontObject then
        if fontSize == "medium" and _G.GameFontHighlight then
            lbl.label:SetFontObject(_G.GameFontHighlight)
        end
    end
    if lbl.label and lbl.label.SetJustifyH then
        lbl.label:SetJustifyH("LEFT")
    end
    scroll:AddChild(lbl)
    return lbl
end

-- ---------------------------------------------------------------------
-- Per-panel + global refresh. Each panel module sets ctx._renderFn via
-- Helpers.SetRenderer; Refresh re-runs every renderer that has been shown
-- at least once. Panels that have never been opened stay unrendered to
-- avoid wasted AceGUI widget allocation.
-- ---------------------------------------------------------------------

-- Rebuilding a panel re-runs its full renderer — a complete AceGUI teardown +
-- rebuild of the whole page. The Blizzard Settings window only ever shows one
-- subcategory at a time, so rebuilding *every* rendered panel on each mutation
-- is wasted work: with 15 sub-pages it stalls the client for a visible beat on
-- every checkbox toggle or button click. Rebuild only the panel that is on
-- screen; flag the rest dirty so they rebuild lazily the next time they are
-- shown (SetRenderer's OnShow honors the flag).
function Helpers.RefreshAllPanels()
    for _, ctx in ipairs(KCM.Settings._panels) do
        if ctx._rendered and ctx._renderFn then
            if ctx.panel and ctx.panel:IsShown() then
                local ok, err = pcall(ctx._renderFn, ctx)
                if not ok then
                    KCM.Say("panel render failed: " .. tostring(err))
                end
                ctx._dirty = false
            else
                ctx._dirty = true
            end
        end
    end
end

-- Scalar refresh (standard options-ui-§11). A scalar mutation (a checkbox
-- write or `/cm set`) must NOT rebuild the page: it re-syncs each widget in
-- place through the per-widget updater closures every renderer registers in
-- ctx.refreshers. Only the on-screen panel is re-synced live; off-screen
-- panels are flagged dirty and rebuilt lazily on their next OnShow, so a
-- background page still reflects the new value when the user returns to it
-- (SetRenderer's OnShow honors the flag). This is the cheap counterpart to
-- RefreshAllPanels — no AceGUI teardown, no structural rebuild.
function Helpers.RefreshScalars()
    for _, ctx in ipairs(KCM.Settings._panels) do
        if ctx._rendered then
            if ctx.panel and ctx.panel:IsShown() then
                for _, refresh in ipairs(ctx.refreshers) do
                    local ok, err = pcall(refresh)
                    if not ok then
                        KCM.Say("scalar refresh failed: " .. tostring(err))
                    end
                end
            else
                ctx._dirty = true
            end
        end
    end
end

-- Validate a value against a schema row's declared type, clamping numbers to
-- min/max. Returns the coerced value, or nil + reason on a type mismatch.
local function validateSchemaValue(def, value)
    local t = def.type
    if t == "bool" then
        if type(value) ~= "boolean" then return nil, "expected boolean" end
    elseif t == "number" then
        if type(value) ~= "number" then return nil, "expected number" end
        if def.min then value = math.max(def.min, value) end
        if def.max then value = math.min(def.max, value) end
    elseif t == "string" then
        if type(value) ~= "string" then return nil, "expected string" end
        -- Enum rows (a `values` list) reject anything outside the list, so the
        -- dropdown and `/cm set` can't write a value the renderer can't display.
        local allowed = Helpers.EnumValues and Helpers.EnumValues(def) or def.values
        if type(allowed) == "table" and #allowed > 0 then
            local names, ok = {}, false
            for i, item in ipairs(allowed) do
                names[i] = tostring(item.value)
                if item.value == value then ok = true end
            end
            if not ok then
                return nil, "allowed values: " .. table.concat(names, ", ")
            end
        end
    elseif t == "color" then
        if type(value) ~= "table" then return nil, "expected color table" end
    end
    return value
end
Helpers.ValidateSchemaValue = validateSchemaValue

-- The single mutation seam for schema-backed settings: validate → write →
-- fire onChange → refresh panels. Both the panel widgets and /cm set route
-- through here (standard §4.5). Returns true on success.
function Helpers.SetAndRefresh(path, value)
    local def = Helpers.FindSchema(path)
    if not def then return false end
    local coerced, reason = validateSchemaValue(def, value)
    if coerced == nil and value ~= nil then
        KCM.Say("invalid value for " .. tostring(path) .. ": " .. tostring(reason))
        return false
    end
    if not Helpers.Set(def.path, coerced) then return false end
    fireOnChange(def, coerced)
    -- Scalar write → in-place widget re-sync, never a page rebuild (§11).
    Helpers.RefreshScalars()
    return true
end

-- Published unified setter (standard §4.5): NS.Schema:Set(path, value).
KCM.Schema = KCM.Schema or {}
function KCM.Schema:Set(path, value)
    return Helpers.SetAndRefresh(path, value)
end

-- ---------------------------------------------------------------------
-- Schema rows. Each row defines a scalar setting that the General panel
-- renders as a widget AND that /cm list / get / set sees on the CLI.
-- Adding a new scalar = one row.
-- ---------------------------------------------------------------------

KCM.Settings.Schema[#KCM.Settings.Schema + 1] = {
    panel    = "general", section = "general", group = "General",
    path     = "enabled", type    = "bool",
    label    = L["Enable"],
    tooltip  = L["Master enable for the addon. When off, the recompute pipeline is a no-op — macros keep their last-written body and stop updating with bag / spec / combat events."],
    -- Default sourced from the AceDB defaults constant, not a duplicated
    -- literal, so the schema and the seeded profile can never drift (standard §4.5).
    default  = KCM.dbDefaults and KCM.dbDefaults.profile and KCM.dbDefaults.profile.enabled,
    onChange = function(v)
        local state = v and "|cff00ff00ON|r" or "|cffff5555OFF|r"
        KCM.Say("Master enable " .. state)
        -- Off→on: kick a recompute so macros refresh against the current
        -- bag / spec state immediately rather than waiting for the next
        -- event. Off→off is harmless (RequestRecompute schedules a run
        -- which the gate in Pipeline.Recompute then skips).
        if v and KCM.Pipeline and KCM.Pipeline.RequestRecompute then
            KCM.Pipeline.RequestRecompute("master_enable")
        end
    end,
}

-- The debug flag is deliberately NOT a schema row: it is session-only state
-- (KCM.State.debug, default off, never persisted) driven by DebugLog. The
-- General page renders it as a custom State-backed checkbox instead (CM-14 /
-- standard §12.5).

-- ---------------------------------------------------------------------
-- About content (parent canvas). Logo + addon notes + slash command list.
-- ---------------------------------------------------------------------

local function readAddOnNotes()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata("ConsumableMaster", "Notes") or ""
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata("ConsumableMaster", "Notes") or ""
    end
    return ""
end

function Helpers.BuildAboutContent(ctx)
    local scroll = ensureScroll(ctx)

    -- Logo: SimpleGroup is full-width so AceGUI's List layout gives it a
    -- known cell to live in; the texture inside is anchored TOPLEFT at
    -- native pixel size so it renders left-aligned regardless of panel
    -- width.
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(LOGO_PIXELS)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(LOGO_TEXTURE)
    logoTex:SetSize(LOGO_PIXELS, LOGO_PIXELS)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)

    addSpacer(scroll, 8)

    local desc = AceGUI:Create("Label")
    desc:SetFullWidth(true)
    desc:SetText(readAddOnNotes())
    if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
        desc.label:SetFontObject(_G.GameFontHighlight)
    end
    if desc.label and desc.label.SetJustifyH then
        desc.label:SetJustifyH("LEFT")
    end
    scroll:AddChild(desc)

    addSpacer(scroll, 12)

    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetHeight(SECTION_HEADING_H)
    heading:SetText(L["Slash Commands"])
    if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
        heading.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(heading)

    addSpacer(scroll, 6)

    local rows = (KCM.SlashCommands and KCM.SlashCommands.GetCommandSummary)
        and KCM.SlashCommands.GetCommandSummary() or {}
    for _, entry in ipairs(rows) do
        local row = AceGUI:Create("Label")
        row:SetFullWidth(true)
        row:SetText(("|cffffff00/cm %s|r  |cffffffff—|r  %s")
            :format(entry.name or entry[1] or "", entry.desc or entry[2] or ""))
        if row.label and row.label.SetJustifyH then
            row.label:SetJustifyH("LEFT")
        end
        scroll:AddChild(row)
    end
end

-- ---------------------------------------------------------------------
-- Tab + main-category registration
-- ---------------------------------------------------------------------

function KCM.Settings.RegisterTab(key, builder)
    if type(key) ~= "string" or type(builder) ~= "function" then return end
    KCM.Settings.builders[key] = builder
    if KCM.Settings.main and not KCM.Settings.sub[key] then
        local ok, sub = pcall(builder, KCM.Settings.main)
        if ok and sub then
            KCM.Settings.sub[key] = sub
        end
    end
end

local function registerPanel()
    if KCM.Settings.main then return end
    -- With LibKa0s absent the panel is not registered AT ALL, rather than
    -- registered onto an empty canvas. Every page body is built out of the
    -- library's chrome, so a category that opened onto nothing would leave the
    -- user unable to tell a broken install from a broken addon — and the
    -- alternative, keeping a verbatim copy of everything the library replaced,
    -- would defeat the adoption. The honest answer is no entry plus one line
    -- naming the missing library. Nothing renders before this point: every H.*
    -- call in the page files sits inside a render() or Build(), and both are
    -- only ever reached from here.
    if libAbsent then
        sayPanelUnavailable()
        return
    end
    if not (Settings and Settings.RegisterCanvasLayoutCategory
            and Settings.RegisterAddOnCategory) then
        return
    end

    Helpers.ValidateSchema()

    local mainCtx = Helpers.CreatePanel("KCMMainPanel", PANEL_TITLE, { isMain = true })
    Helpers.SetRenderer(mainCtx, Helpers.BuildAboutContent)

    local main = Settings.RegisterCanvasLayoutCategory(mainCtx.panel, PANEL_TITLE)
    Settings.RegisterAddOnCategory(main)
    KCM.Settings.main = main

    -- /cm config (and KCM.Options.Open) lands on the parent — the About
    -- splash with logo + tagline + slash help. Sub-pages are forced
    -- expanded in the AddOns sidebar (see O.Open) so all panels are one
    -- click away from the landing page.
    KCM._settingsCategoryID = main:GetID()

    for _, key in ipairs(KCM.Settings.order) do
        local fn = KCM.Settings.builders[key]
        if type(fn) == "function" and not KCM.Settings.sub[key] then
            local ok, sub = pcall(fn, main)
            if ok and sub then
                KCM.Settings.sub[key] = sub
            elseif not ok then
                KCM.Say("settings tab '" .. key .. "' failed: " .. tostring(sub))
            end
        end
    end
end
KCM.Settings.Register = registerPanel

-- ---------------------------------------------------------------------
-- KCM.Options shim — preserves the public API used by Core / Debug /
-- SlashCommands / Pipeline. Internals route through the new framework.
-- ---------------------------------------------------------------------

function O.Refresh()
    O._refreshPending = false
    Helpers.RefreshAllPanels()
end

-- Trailing-edge debounced refresh. Pipeline.Recompute fires this on every
-- recompute, which during a GET_ITEM_INFO_RECEIVED storm at first panel
-- open lands dozens of calls in quick succession. Debounce so the panel
-- rebuilds once at the tail of the burst, with a cap so the user always
-- sees the latest state within REFRESH_MAX_WAIT_SEC even if events never
-- fully stop.
local REFRESH_DEBOUNCE_SEC = 1.0
local REFRESH_MAX_WAIT_SEC = 3.0
function O.RequestRefresh()
    local now = GetTime()
    if not O._refreshFirstAt then O._refreshFirstAt = now end
    O._refreshPending = true
    O._refreshToken = (O._refreshToken or 0) + 1
    local myToken = O._refreshToken

    local waited = now - O._refreshFirstAt
    local delay = REFRESH_DEBOUNCE_SEC
    if waited + delay > REFRESH_MAX_WAIT_SEC then
        delay = math.max(0.05, REFRESH_MAX_WAIT_SEC - waited)
    end

    C_Timer.After(delay, function()
        if O._refreshToken ~= myToken then return end
        if O._refreshPending then
            O._refreshFirstAt = nil
            O.Refresh()
        end
    end)
end

-- Expand the parent in the AddOns left tree so every sub-page is visible.
-- The expansion lives on the visual list-entry element, NOT on the
-- SettingsCategory data object — so we have to reach into
-- SettingsPanel:GetCategoryList():GetCategoryEntry(category). That path
-- is private Blizzard API and could shift across patches; the pcall
-- degrades gracefully to "panel opens but parent isn't unfolded" if any
-- intermediate call goes missing. Method-or-field fallback on
-- GetCategoryList covers minor API drift between client builds.
local function expandMainCategory()
    local main = KCM.Settings and KCM.Settings.main
    if not (main and SettingsPanel) then return end
    pcall(function()
        local list = SettingsPanel.GetCategoryList
            and SettingsPanel:GetCategoryList()
            or SettingsPanel.CategoryList
        if not (list and list.GetCategoryEntry) then return end
        local entry = list:GetCategoryEntry(main)
        if entry and entry.SetExpanded then
            entry:SetExpanded(true)
        end
    end)
end

function O.Open()
    -- There is no panel to open on a degraded install. Answering false is the
    -- contract core/SlashCommands.lua already branches on, so `/cm config`
    -- explains itself instead of silently doing nothing.
    if libAbsent then
        sayPanelUnavailable()
        return false
    end
    -- Settings UI is protected during combat — opening will silently fail
    -- mid-fight. Surface a chat notice instead so the user knows why.
    if InCombatLockdown and InCombatLockdown() then
        sayCombatOpenBlocked()
        return false
    end

    local id = KCM._settingsCategoryID
    if type(id) ~= "number" then id = tonumber(id) end
    if Settings and Settings.OpenToCategory and id then
        Settings.OpenToCategory(id)
        -- Expand AFTER opening so SettingsPanel is realized and the
        -- category-entry element exists in the visual tree. Re-expanding
        -- on every open means a manual mid-session collapse doesn't stick
        -- across the next /cm config.
        expandMainCategory()
        return true
    end
    KCM.Say("settings panel unavailable on this client; use /cm.")
    return false
end

-- Bootstrap: defer until Blizzard_Settings is ready.
local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_Settings" then return end
    registerPanel()
    if KCM.Settings.main then
        self:UnregisterAllEvents()
    end
end)

-- ---------------------------------------------------------------------
-- Bus receivers (standard §4.4). The options layer owns the sole
-- subscriptions to PANEL_REFRESH (debounced rebuild of any open page) and
-- SPEC_CHANGED (retrack the Stat Priority page to the new spec when the page
-- is auto-tracking). Each is registered on its own target — never two on one.
-- ---------------------------------------------------------------------
if KCM.NewBusTarget and KCM.MSG then
    local optionsTarget = KCM.NewBusTarget()
    KCM._optionsBusTarget = optionsTarget
    optionsTarget:RegisterMessage(KCM.MSG.PANEL_REFRESH, function()
        if O.RequestRefresh then O.RequestRefresh()
        elseif O.Refresh then O.Refresh() end
    end)
    optionsTarget:RegisterMessage(KCM.MSG.SPEC_CHANGED, function()
        if O._viewedSpecAuto and KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
            local _, _, key = KCM.SpecHelper.GetCurrent()
            if key then O._viewedSpec = key end
        end
    end)
end
