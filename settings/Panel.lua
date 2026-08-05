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
-- spec-aware categories + Augment Rune, then Vantus Rune, Bloodlust, and
-- Battle Rez last. This table is the source of truth for that order.
KCM.Settings.order = KCM.Settings.order or {
    "general", "statpriority", "macrobar",
    "food", "drink", "hp_pot", "mp_pot", "hs",
    "hp_aio", "mp_aio",
    "flask", "cmbt_pot", "stat_food", "wpn_ench", "aug_rune", "vantus",
    "bloodlust", "battle_rez",
}

-- Helpers is the addon's own half of the settings framework AND the published
-- view of LibKa0s-Options-1.0's instance. Once the instance exists it is
-- installed as this table's __index (see the optionsLib block below), so every
-- library member resolves off the LIVE instance at call time rather than off a
-- snapshot taken at file load. That is the whole point: the copy-across this
-- replaced re-exported eleven members by hand, and any member the list forgot —
-- or any member bound while `UI` was still nil — read back nil at the call site
-- with no way to tell it apart from a member the library never had
-- (options-ui-§1). The addon's own wrappers stay as OWN keys and shadow the
-- library's same-named function, which is what keeps Section / CreatePanel /
-- LSMValues able to call the instance's version without recursing into
-- themselves.
local Helpers = KCM.Settings.Helpers or {}
KCM.Settings.Helpers = Helpers

KCM.Options = KCM.Options or {}
local O = KCM.Options

local PANEL_TITLE   = L["Ka0s Consumable Master"]
-- PADDING_X, HEADER_TOP, HEADER_HEIGHT, DEFAULTS_W and the breadcrumb
-- separator all live in LibKa0s-Options-1.0's LAYOUT table now, carrying the
-- same values they carried here.

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
-- All four spacers are LibKa0s-Options-1.0's now — its LAYOUT table carries the
-- same 10, 6 and 8, and nothing in this file emits one by hand any more. The
-- note above stays because the ARITHMETIC is still the reason the top gap looks
-- small, and that reasoning belongs with the rows it explains.
local SECTION_HEADING_H     = 26
local BUTTON_PAIR_REL       = 0.492  -- paired action-button relative width (options-ui-§8)

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
    bloodlust = true, battle_rez = true,
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

        -- The row makers are the library's now (LIBKA0S-04), so it needs the
        -- two things this addon's own makers knew and it could not guess.
        --
        -- Colors are stored POSITIONALLY — { r, g, b, a } — which is the shape
        -- the Ka0s options color widget has always written. The library's
        -- default codec is the named-key form, so without this every picker
        -- would read white and write a table nothing here can unpack.
        colorDecode = function(c)
            c = type(c) == "table" and c or {}
            return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
        end,
        colorEncode = function(r, g, b, a) return { r, g, b, a or 1 } end,

        -- Sliders commit on the drag, not just on release. The Macro Bar page's
        -- number rows drive the bar itself — button size, spacing, scale,
        -- alpha — so the live preview IS the feature. Release-only is the
        -- library's default and would have taken it away silently.
        sliderCommit = "change",

        -- Resolved at CALL time, never captured: LibSharedMedia is optional and
        -- other addons register media into it after this file loads, so a list
        -- read once at :New would freeze whatever happened to exist first.
        getLSM = function() return LibStub and LibStub("LibSharedMedia-3.0", true) end,

        get = function(path) return Helpers.Get(path) end,
        set = function(path, value) Helpers.SetAndRefresh(path, value) end,
    })

    -- Restated because the library resolves AceGUI once at :New and re-resolves
    -- it only inside its own CreateOptionsPanel, which this addon never calls.
    UI.AceGUI = AceGUI

    ensureScroll = UI.EnsureScroll

    -- THE binding, replacing the hand-written re-export list. Every member the
    -- library publishes — AttachTooltip, EnsureScroll, PatchAlwaysShowScrollbar,
    -- SetRenderer, AddSpacer, RenderField, RefreshAllPanels, RefreshScalars and
    -- the rest — is now reachable on Helpers without being copied, so the two
    -- tables cannot drift and no member can be silently absent.
    setmetatable(Helpers, { __index = UI })

    -- The instance, so the suite can assert IDENTITY against the library rather
    -- than lookalike behavior. Mirrors KCM.DebugLog.instance.
    Helpers.instance = UI
else
    -- Degraded install: there is no instance to delegate to, and every
    -- library-owned member stays absent — a page cannot be built without the
    -- library's chrome, so nothing that would draw one is reachable anyway.
    --
    -- The two refresh tiers are the exception, and they are supplied as real
    -- no-ops rather than left nil because they are called UNCONDITIONALLY on
    -- paths a degraded install still reaches: Helpers.SetAndRefresh calls
    -- RefreshScalars after every schema write, and O.Refresh calls
    -- RefreshAllPanels off the PANEL_REFRESH bus message that Pipeline fires on
    -- every recompute. Bound to `UI and UI.X` they read back nil and the bare
    -- call raised "attempt to call field 'RefreshAllPanels' (a nil value)" —
    -- in SetAndRefresh's case AFTER the write had already landed, so a pcall'ing
    -- caller saw a failure over a mutation that had persisted. With nothing on
    -- screen there is nothing to refresh, so doing nothing is the correct body.
    Helpers.RefreshAllPanels = function() end
    Helpers.RefreshScalars   = function() end
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
        -- This USED to end "every setting is still reachable with /cm list,
        -- /cm get and /cm set", which was the one thing it must not do: those
        -- three are the schema CLI, they route through LibKa0s-Slash-1.0, and
        -- with the library absent they are exactly the verbs that answer
        -- "unavailable". Sending the user at them was sending them at a second
        -- dead end. The verbs named here are the ones settings/Slash.lua's own
        -- degraded arm reports as still working (CM-R-03).
        KCM.Say(KCM.LIBKA0S_MISSING ..
            ", so the settings panel is unavailable, and so are /cm list, " ..
            "/cm get and /cm set. The rest of /cm still works — type /cm for " ..
            "the list.")
    end
end

-- ---------------------------------------------------------------------
-- Tooltip helper
-- ---------------------------------------------------------------------

-- Both the tooltip helper and the spacer/section pair below are
-- LibKa0s-Options-1.0's. Kept as file locals because the schema-row makers
-- further down call them directly; the PUBLISHED names come off the instance
-- through Helpers' __index, so there is nothing to re-export here.
local attachTooltip = UI and UI.AttachTooltip

-- ---------------------------------------------------------------------
-- CreatePanel — the canvas Frame, its header and its Defaults button
-- ---------------------------------------------------------------------
--
-- The header (title + atlas divider + breadcrumb), the panel factory and the
-- lazily-built Defaults button are all LibKa0s-Options-1.0's. The library
-- carries the same reasoning the deleted comment here did, and it is worth
-- keeping in mind before anyone "simplifies" it: the Defaults button is
-- DECLARED at build time and CREATED on the panel's first OnShow, because
-- AceGUI is a shared library and UI skinners restyle its widgets by hooking
-- RegisterAsWidget. A widget created during load keeps Blizzard's red stone
-- button for the rest of the session; first OnShow is after every addon has
-- loaded, so the race is gone.
--
-- What stays here is the click handler, because the combat guard and the
-- pcall-and-report around it have no library equivalent, and the ctx's three
-- render-state fields, which back this addon's two-tier refresh (structural
-- rebuild vs in-place re-sync) — a model the library does not have.

function Helpers.CreatePanel(name, title, opts)
    opts = opts or {}

    local ctx = UI.CreatePanel(name, title, {
        isMain         = opts.isMain,
        -- The library's own key for the same thing, so UI.__panelFor can find
        -- this ctx in its registry.
        pageKey        = opts.panelKey,
        defaultsButton = opts.defaultsAction and true or false,
    })

    ctx.panelKey  = opts.panelKey
    ctx._rendered = false
    ctx._dirty    = false
    ctx._renderFn = nil

    if opts.defaultsAction then
        -- Parked on the PANEL, not on the button: the button does not exist
        -- yet. EnsureDefaultsButton wires this up when it builds it.
        ctx.panel.defaultsOnClick = function()
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

    KCM.Settings._panels[#KCM.Settings._panels + 1] = ctx
    return ctx
end

-- A panel module calls SetRenderer(ctx, fn) to declare how to render its
-- body. The framework calls fn(ctx) on first show and after every Refresh.
-- The renderer is responsible for releasing existing children before
-- adding new ones (Helpers.ResetScroll handles that).
-- The library's, and it carries everything this addon's own copy did: the
-- Defaults button built on first show rather than at registration (the AceGUI
-- skinning load-order race), the combat guard that closes the Settings window
-- (the Blizzard AddOns sidebar bypasses KCM.Options.Open, so this is the only
-- thing covering a direct sidebar click mid-fight), first-show rendering, and
-- the dirty re-render for a page refreshed while hidden.
--
-- Two differences, both accepted and both recorded as LIBKA0S-05. The combat
-- notice is the library's |cffaaaaaa rather than this addon's |cff808080 —
-- same sentence, different gray, and Options.lua has no L seam to override it.
-- And a failing renderer is reported as "settings page '<key>' failed to
-- render" rather than "panel render failed".
--
-- Same name in both, so Helpers.SetRenderer resolves through __index.

-- Release scroll children + reset bookkeeping so a fresh render starts on
-- a clean slate. Panels with dynamic content (priority list rows that
-- change as items are added/removed) call this at the top of their
-- renderer; panels rendered once on first OnShow don't need it.
-- The library spells it ClearScroll. It REASSIGNS ctx.refreshers rather than
-- wiping it in place, which matters: every released widget's refresher closure
-- would otherwise survive forever, so every write and every profile change
-- would pcall an ever-growing pile of dead closures.
Helpers.ResetScroll = UI and UI.ClearScroll

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
-- seam (architecture-§5).
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- Schema-row widgets — all four makers are LibKa0s-Options-1.0's
-- ---------------------------------------------------------------------
--
-- bool -> CheckBox, number -> Slider, string -> Dropdown (or an LSM30_* widget
-- via `dialogControl`), color -> ColorPicker. Three upstream fixes are what
-- made these adoptable, all recorded as LIBKA0S-04:
--
--   * the dropdown reads `values` as the ordered { value =, text = } array this
--     addon declares, rather than as a key map;
--   * `hasAlpha` defaults to TRUE, which is what all seven color rows here
--     assume by declaring nothing;
--   * `sliderCommit` exists at all, so the Macro Bar page keeps its live drag
--     preview.
--
-- A fourth was never in the ledger: the makers read `row.desc` where every Ka0s
-- schema declares `tooltip`, which would have blanked every tooltip body while
-- leaving the label rendering — silently, and only in game.
--
-- Helpers.EnumValues and Helpers.LSMValues stay here: they are the addon's own
-- schema vocabulary, called from settings/MacroBar.lua's rows and pinned by
-- tests/test_macrobar.lua.

local function enumValues(def)
    return type(def.values) == "function" and def.values() or def.values or {}
end
Helpers.EnumValues = enumValues

function Helpers.LSMValues(mediaType)
    -- A shape adapter over the library's, which answers a deferred closure over
    -- a self-keyed HASH where this addon's schema declares an ordered
    -- { value =, text = } array. enumList reads both, so only the row literal
    -- differs — and the rows here are already written as functions.
    --
    -- What it gains is the guarantee: the library's never returns an empty
    -- list. A media type with nothing registered yields a single "None",
    -- because an empty one leaves the dropdown unopenable and makes
    -- ValidateSchemaValue reject even the value already stored. This addon had
    -- that placeholder first; the library has it now.
    local hash = UI and UI.LSMValues(mediaType)() or {}
    local keys = {}
    for k in pairs(hash) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for i2, k in ipairs(keys) do out[i2] = { value = k, text = k } end
    return out
end

-- The dispatch itself, by row type, is the library's under the same name, so
-- Helpers.RenderField resolves through __index. Every maker behind it is the
-- library's too.

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

-- Two-column paired grid (options-ui-§6), the library's. Each item is either a
-- schema def or a custom descriptor with a `make(ctx, parent, relWidth)`
-- function; items render two per row at 0.5 relative width, and `wide = true`
-- breaks one onto its own full-width row.
--
-- This addon had its own copy until LibKa0s-Options-1.0 grew RenderGrid. Its
-- RenderRows could never replace it: that one is SCHEMA-driven and
-- auto-sections by `group`, where these pages pair their rows by hand and —
-- the case that forced the issue — settings/MacroBar.lua's per-macro toggle
-- list has one checkbox per macro, a length no schema knows. That is what made
-- it a library gap rather than something to work around here. RenderGrid also
-- guards each item, so one raising `make` costs that cell and not the page.
Helpers.Grid = UI and UI.RenderGrid

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
-- The two refresh tiers — both the library's (options-ui-§11)
-- ---------------------------------------------------------------------
--
-- RefreshAllPanels is STRUCTURAL: it re-runs the page's renderer, so rows that
-- appeared or disappeared are drawn. RefreshScalars is IN PLACE: it re-syncs
-- each widget through the updater closures a renderer registers in
-- ctx.refreshers, with no AceGUI teardown. A scalar write — a checkbox, or
-- `/cm set` — must never rebuild the page, which is the whole reason the split
-- exists.
--
-- Either way, only the page actually on screen is touched; the rest are
-- flagged dirty and rebuilt on their next OnShow, so a background page still
-- reflects the change when the user returns to it.
--
-- This addon had both tiers first; the library grew them to match, which is
-- what made the registry adoptable at all (LIBKA0S-05). The names and
-- semantics are identical, so every caller here is unchanged.
--
-- Both resolve through __index when the library is present and are the no-ops
-- bound at the seam above when it is not, so the two bare calls below —
-- SetAndRefresh's RefreshScalars and O.Refresh's RefreshAllPanels — are
-- callable on BOTH paths.

-- One validator per declared schema type, built once at file load. Each returns
-- the coerced value, or nil + a reason the caller can put in front of the user.
-- A type with no entry here is not an error: see validateSchemaValue.
local VALIDATORS = {
    bool = function(_, value)
        if type(value) ~= "boolean" then return nil, "expected boolean" end
        return value
    end,

    -- min and max are independently optional, so the clamp is two separate
    -- one-sided tests rather than a range check.
    number = function(def, value)
        if type(value) ~= "number" then return nil, "expected number" end
        if def.min then value = math.max(def.min, value) end
        if def.max then value = math.min(def.max, value) end
        return value
    end,

    string = function(def, value)
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
        return value
    end,

    color = function(_, value)
        if type(value) ~= "table" then return nil, "expected color table" end
        return value
    end,
}

-- Validate a value against a schema row's declared type, clamping numbers to
-- min/max. Returns the coerced value, or nil + reason on a type mismatch.
--
-- An unrecognized (or absent) def.type passes the value through untouched —
-- that is the fall-through the elseif chain this replaced always had, and
-- rejecting instead would break every row that declares no type.
local function validateSchemaValue(def, value)
    local f = VALIDATORS[def.type]
    if not f then return value end
    return f(def, value)
end
Helpers.ValidateSchemaValue = validateSchemaValue

-- The single mutation seam for schema-backed settings: validate → write →
-- fire onChange → refresh panels. Both the panel widgets and /cm set route
-- through here (architecture-§5). Returns true on success.
function Helpers.SetAndRefresh(path, value)
    local def = Helpers.FindSchema(path)
    if not def then return false end
    local coerced, reason = validateSchemaValue(def, value)
    -- `coerced == nil` alone, with no `and value ~= nil` escape clause. Every
    -- validator rejects nil (nil is not a boolean, a number, a string or a
    -- table), so the old second half let an EXPLICIT nil skip the report and
    -- fall through to Helpers.Set(path, nil) — which does not "write nil", it
    -- DELETES the key out of the profile. The row then read back as absent
    -- rather than as its default, and SetAndRefresh returned true for it.
    -- A typeless row has no validator and passes its value through untouched,
    -- so it reaches here with coerced == value and is rejected on nil for the
    -- same reason and with the same message.
    if coerced == nil then
        KCM.Say("invalid value for " .. tostring(path) .. ": "
              .. tostring(reason or "value must not be nil"))
        return false
    end
    if not Helpers.Set(def.path, coerced) then return false end
    fireOnChange(def, coerced)
    -- Scalar write → in-place widget re-sync, never a page rebuild (§11).
    Helpers.RefreshScalars()
    return true
end

-- Published unified setter (architecture-§5): NS.Schema:Set(path, value).
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
    -- literal, so the schema and the seeded profile can never drift (architecture-§5).
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
-- debug-logging-§5).

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

    -- Convergence #2 (LIBKA0S-13): one row formatter for the whole addon. These
    -- lines come back already rendered by lib.FormatRow, the same function
    -- /cm help's rows go through -- so the panel and the chat cannot drift
    -- apart again by an edit to one of them. The visible cost is the one every
    -- other adopter paid: the spacing either side of the em dash halves, the
    -- dash loses its white color span, and the description gains one.
    local rows = (KCM.SlashCommands and KCM.SlashCommands.GetLandingRows)
        and KCM.SlashCommands.GetLandingRows() or {}
    for _, line in ipairs(rows) do
        local row = AceGUI:Create("Label")
        row:SetFullWidth(true)
        row:SetText(line)
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
-- Bus receivers (architecture-§4). The options layer owns the sole
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
