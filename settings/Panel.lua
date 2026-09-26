-- settings/Panel.lua — Settings UI framework.
--
-- Mirrors the KickCD pattern: every page (parent + sub-pages) is registered as
-- a canvas-layout subcategory and shares one header (title + atlas divider)
-- built by Helpers.CreatePanel. Each page module (settings/General.lua,
-- MacroBar.lua, StatPriority.lua, Category.lua) hands a builder to RegisterTab;
-- this file iterates the builders once Blizzard_Settings is ready.
--
-- FOUR pages, not eighteen. Every macro category used to be its own sub-page;
-- they are tabs on the one Macros page now (options-ui-§13), which is why the
-- order table below split into KCM.Settings.order (the pages) and
-- KCM.Settings.macroOrder (that page's strip).
--
-- Public surface preserved for the rest of the addon:
--   KCM.Options.Register  — the named alias for registerPanel, fired by this
--      file's own PLAYER_LOGIN / ADDON_LOADED bootstrap at the foot.
--      KCM.Options.Refresh / RequestRefresh / Open are the RUN-time half of
--      that shim and are settings/OptionsShim.lua's, which the TOC loads
--      immediately after this file: the schema-and-chrome half a page module
--      calls while it BUILDS is this file, the shim the addon calls afterwards
--      is that one. The cut is layout-§1's 1500-line cap; nothing else moved
--      with it, and the one notice it still needs is published on
--      KCM.Settings below rather than copied.
--   KCM.Settings.Helpers + KCM.Settings.Schema  (SlashCommands /cm list/get/set)

local _, NS = ...
local KCM = NS
local L = KCM.L
-- Silent-mode (library-stack-§4): AceGUI is an OptionalDep, and the hard form
-- raises during load on an install that lacks it. See settings/OptionsSetup.lua,
-- which treats a nil AceGUI as a degraded load.
local AceGUI = LibStub("AceGUI-3.0", true)

KCM.Settings         = KCM.Settings         or {}
KCM.Settings.Schema  = KCM.Settings.Schema  or {}
KCM.Settings.builders= KCM.Settings.builders or {}
KCM.Settings._panels = KCM.Settings._panels or {}

-- Canonical PAGE order — the five sub-pages in the AddOns sidebar, in the order
-- a player meets them: the master switch and the maintenance actions, the macro
-- categories themselves (the addon's whole subject), the stat ranking the
-- spec-aware categories sort by, the optional on-screen bar that displays the
-- finished macros, and last the Profiles page (settings/Profiles.lua), which is
-- AceDBOptions' own UI and the same page in every Ka0s addon that ships one --
-- last there too.
--
-- It used to carry eighteen entries because every macro category was its own
-- sub-page. The categories are one page with a tab strip now (options-ui-§13),
-- so the category run moved to KCM.Settings.macroOrder below and this table is
-- back to being what its name says.
KCM.Settings.order = KCM.Settings.order or {
    "general", "macros", "statpriority", "macrobar", "profiles",
}

-- Canonical TAB order for the Macros page: the strip settings/Category.lua
-- generates, one tab per category. Deliberately independent of Categories.LIST
-- and functionally cosmetic — the basic consumables first because they are what
-- a player opens the page for, then the two AIO composites (which aggregate the
-- categories above them, so they read after them), then the spec-aware set plus
-- Augment Rune, then Vantus Rune, Bloodlust and Battle Rez, which are set once
-- per tier and left.
--
-- This is the same run, in the same order, that the eighteen-entry
-- KCM.Settings.order carried before the pages were collapsed: the ordering
-- argument was about the categories and survived the reorganization intact.
-- Keys are the lower-cased category keys, matching the sub-page keys the strip
-- replaced, so defaults/Profile.lua's macroBar.order — which mirrors this list
-- upper-cased — did not have to move either.
KCM.Settings.macroOrder = KCM.Settings.macroOrder or {
    "food", "drink", "hp_pot", "mp_pot", "hs",
    "hp_aio", "mp_aio",
    "flask", "cmbt_pot", "stat_food", "wpn_ench", "aug_rune", "vantus",
    "bloodlust", "battle_rez",
}

-- Helpers is the addon's own half of the settings framework AND the published
-- view of LibKa0s-Options-1.0's instance. settings/OptionsSetup.lua creates this
-- table and installs the instance as its __index, so every library member
-- resolves off the LIVE instance at call time rather than off a snapshot taken
-- at file load. That is the whole point: the copy-across this replaced
-- re-exported eleven members by hand, and any member the list forgot — or any
-- member bound while `UI` was still nil — read back nil at the call site with no
-- way to tell it apart from a member the library never had (options-ui-§1). The
-- addon's own wrappers below stay as OWN keys and shadow the library's
-- same-named function, which is what keeps Section and CreatePanel able to call
-- the instance's version without recursing into themselves. LSMValues was the
-- third of those until M4-C1; it is the library's outright now.
local Helpers = KCM.Settings.Helpers or {}
KCM.Settings.Helpers = Helpers

-- The shim TABLE is created here and filled in settings/OptionsShim.lua, which
-- loads next. It is created on this side of the peel because Core, Debug and
-- Pipeline all reach for KCM.Options, and a build that stopped after this file
-- should answer them with an empty shim rather than a nil index. The `or {}`
-- on both sides is what makes the order between the two harmless.
KCM.Options = KCM.Options or {}

-- The panel title (KCM.Settings.PANEL_TITLE) is the library descriptor's
-- parentTitle now, settings/OptionsSetup.lua. PADDING_X, HEADER_TOP, HEADER_HEIGHT, DEFAULTS_W and the breadcrumb
-- separator all live in LibKa0s-Options-1.0's LAYOUT table now, carrying the
-- same values they carried here.

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
--
-- SECTION_HEADING_H (26) and BUTTON_PAIR_REL (0.492) used to be host copies
-- here. They are not any more: options-ui-§8 says a host copy is the copy that
-- goes stale, and the whole point of the library owning these is that five
-- addons cannot drift apart. Both are published on the Options instance, which
-- `Helpers` delegates to through its `__index`, so the two draw sites below read
-- `Helpers.SECTION_HEADING_H` and `Helpers.BUTTON_PAIR_REL` directly. Neither
-- site is reachable on a build without the library — nothing registers a panel
-- there — so there is no nil arm to guard.

-- Built from the folder name rather than typed, the same derivation
-- core/LauncherSetup.lua uses for the launcher icon (its ICON, built from
-- `addonName`): a texture path is absolute from `Interface\AddOns\`, so the
-- folder half has to be the name the client loaded, and layout-§4 lowercases
-- the file half. This is consistency with that file, not a layout-§4
-- deviation being corrected -- the literal spelled the same path. This file
-- opens `local _, NS = ...`, so the name is read off NS.name, which
-- core/Namespace.lua sets from the vararg.
local LOGO_TEXTURE = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga")
    :format(KCM.name, KCM.name:lower())
local LOGO_PIXELS  = 300

-- ---------------------------------------------------------------------
-- The write seam -- LibKa0s-Schema-1.0 (ConsumableMaster#39)
-- ---------------------------------------------------------------------
--
-- The machinery around the rows is the library's: the path walk, the row
-- index, the validate -> normalize -> store -> log -> announce pipeline, the
-- all-or-nothing batch, the bulk bracket that makes a sweep one `[Set]` line
-- (debug-logging-§10) and the profile reset's changed-row count. What stays
-- here is what only this addon knows: the rows themselves, their type rules
-- (further down), and what a write sets off -- a row's `apply`, run by
-- `announce` below, then the panel re-sync.
--
-- With the library absent the seam is settings/SchemaStub.lua's
-- write-completing, log-silent stub, so `/cm bar on|off`, `/cm enable` and the
-- global reset keep writing on a degraded load (slash-commands-§1).
--
-- THREE THINGS CHANGED ON PURPOSE WITH THE ADOPTION. A path no row declares is
-- refused rather than stored; a table value is copied into the store rather
-- than stored by reference; and the `[Set]` line is written before the row's
-- reaction rather than after it. tests/test_schema_adoption.lua pins each.
--
-- THE STORES THAT ARE NOT THE PROFILE are rows now, each carrying its own
-- get/set, both stamped in settings/General.lua's decorate map: the debug
-- console's visibility (`state.debugConsole`, sessionOnly) and the minimap
-- button's (`global.minimap.shown`, the SHOWN/HIDDEN inversion in its get/set
-- onto LibDBIcon's `db.global.minimap.hide`, which is still the stored key).
-- `resolveRoot` therefore only ever answers the profile.
local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or KCM.SchemaStub

-- A table value logs as its contents, not as an address: the whole-value rows
-- are tables, and a color is one too. One level deep -- a stat-priority entry
-- nested inside its map renders as {...}.
local function logValue(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    if #v > 0 then
        for i, x in ipairs(v) do parts[i] = tostring(x) end
    else
        for k, x in pairs(v) do
            parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and "{...}" or tostring(x))
        end
        table.sort(parts)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- The one reporter every host reaction runs through. A raising reaction is
-- REPORTED, never propagated: the value has already landed, and a caller that
-- saw an error over a write that persisted would retry or give up on a write
-- that worked. That is why the reactions are the host field `apply` and not
-- Schema's own `onChange`, which propagates.
local function fireApply(path, fn, value)
    local ok, err = pcall(fn, value)
    if not ok then
        KCM.Say("onChange for " .. tostring(path) .. " failed: " .. tostring(err))
    end
end

-- Set by Helpers.SetManyAndRefresh for the length of its batch: the caller's
-- one reactor and whether the batch changes what a page draws.
local batchCtx

-- One write's tail: the row's reaction, then the in-place re-sync (a scalar
-- write never rebuilds a page, options-ui-§11). Resolved off Helpers at call
-- time, because the refresh tiers are the Options instance's and a suite may
-- swap them.
local function announce(row, path, value)
    if type(row.apply) == "function" then fireApply(path, row.apply, value) end
    Helpers.RefreshScalars()
end

-- A batch's tail, once: the caller's reactor when it named one, otherwise each
-- DISTINCT row reaction once, in first-seen order -- so a sixty-row page reset
-- is still one applyBar -- then one refresh.
local function announceBatch(writes)
    local ctx = batchCtx
    if ctx and ctx.onChange then
        fireApply(writes[1] and writes[1].path, ctx.onChange)
    else
        local ran = {}
        for _, w in ipairs(writes) do
            local fn = w.row.apply
            if type(fn) == "function" and not ran[fn] then
                ran[fn] = true
                fireApply(w.path, fn, w.value)
            end
        end
    end
    if ctx and ctx.structural then Helpers.RefreshAllPanels() else Helpers.RefreshScalars() end
end

-- The rows no SWEEP may reset (launcher-§3): filled as rows carrying
-- `neverReset` register. The library reads it at call time and honors it only
-- inside a bracket, so `/cm reset global.minimap.shown` still works by name.
local resetExempt = {}

local S = SchemaLib:New({
    rows          = KCM.Settings.Schema,
    resolveRoot   = function() return KCM.db and KCM.db.profile, 1 end,
    announce      = announce,
    announceBatch = announceBatch,
    debug         = function(tag, fmt, ...) if KCM.Debug then KCM.Debug(tag, fmt, ...) end end,
    debugEnabled  = function() return KCM.State and KCM.State.debug end,
    format        = function(_, v) return logValue(v) end,
    resetExempt   = resetExempt,
})
Helpers.schema = S

-- Read and write one row by path. Get reads any path under the profile, a row
-- or not; Set refuses a path no row declares. Set answers the library's
-- `true | false, err, why` and prints nothing -- SetAndRefresh below is the
-- door that tells the player why.
Helpers.Get        = S.Get
Helpers.Set        = S.Set
Helpers.FindSchema = S.FindRow

--- Run fn as ONE bulk act (debug-logging-§10): every write inside it validates,
--- stores and reacts as it would outside, but logs no line of its own. When fn
--- returns (or raises) the act logs `[Set] <act> <scope>: N rows`, N being the
--- rows it changed; a bracket nested in another folds into it. An act that
--- raises still logs its line, ending ` (stopped by an error)`, and the error is
--- re-raised unwrapped.
function Helpers.Bulk(act, scope, fn)
    S.BulkRun(act, scope, function() fn() end)
end

--- Run fn with the per-row line muted and NO line of its own, for an act another
--- seam logs once: the global reset, logged by the OnProfileReset handler. A
--- bracket around it logs nothing either (one line overall).
function Helpers.MuteSetLog(fn)
    S.BulkRun("reset", "profile", function(info)
        info.profileReset = true
        fn()
    end)
end

-- The four pages a schema row may target. It used to list the fifteen category
-- keys as well, from when each was its own sub-page; no row ever declared one —
-- a category's priority list is a collection, not a scalar, so it has no `path`
-- to declare — and the Macros page they collapsed into is one entry.
local _validPanels = {
    general = true, macros = true, statpriority = true, macrobar = true,
}
-- A row's `section` is the page that declares it. The Macros and Stat Priority
-- pages declare the whole-value rows behind their own controls (architecture-§5).
local _validSections = { general = true, macrobar = true, macros = true, statpriority = true }
-- `order` and `map` are the WHOLE-VALUE rows (architecture-§5): a list over a
-- fixed member set, and a keyed map. See TYPE_RULES below.
local _validTypes    = { bool = true, number = true, string = true, color = true,
                         order = true, map = true }

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
-- LibKa0s-Options-1.0 — the panel shell's seam, read back
-- ---------------------------------------------------------------------
--
-- Everything ABOVE this line is the schema half: the write seam over
-- LibKa0s-Schema-1.0 (or settings/SchemaStub.lua when the library is absent),
-- Get / Set / FindSchema / Bulk / ValidateSchema, and (far below) the type rules
-- and the SetAndRefresh door. None of it touches the Options instance, which is
-- what keeps the host verbs writing on an install where LibKa0s is missing.
--
-- The seam ITSELF — the :New call, its codecs and thunks, the __index binding
-- and the degraded no-op arm — lives in settings/OptionsSetup.lua now
-- (options-ui-§1, CM-A-14), which the TOC loads immediately before this file.
-- What is left here is three file-scope reads of what it published.

local UI = KCM.Settings.optionsUI

-- Section, Grid and the schema-row makers below all call it as a local.
local ensureScroll = UI and UI.EnsureScroll

-- Whether the panel can be built at all. Read by registerPanel and O.Open far
-- below; the schema half above neither reads it nor needs it. Derived from the
-- instance rather than from a second flag, so "the library answered" and "the
-- panel can be built" cannot disagree.
local libAbsent = not UI

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
            "/cm get and /cm set. The rest of /cm still works — type /cm help for " ..
            "the list.")
    end
end
-- Published for settings/OptionsShim.lua's O.Open, which is the other seam that
-- reaches for the panel on a degraded install. It takes THIS function rather
-- than a copy because `announcedMissing` is the said-once flag: two copies would
-- be two flags, and the notice would then be said once per seam instead of once
-- per session.
KCM.Settings.SayPanelUnavailable = sayPanelUnavailable

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
-- Two differences, both accepted and both recorded as LIBKA0S-05 (issue #24). The combat
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
-- and the `/cm set` path share a single validate → write → apply → refresh
-- seam (architecture-§5).
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- Schema-row widgets — all four makers are LibKa0s-Options-1.0's
-- ---------------------------------------------------------------------
--
-- bool -> CheckBox, number -> Slider, string -> Dropdown (or an LSM30_* widget
-- via `dialogControl`), color -> ColorPicker. Three upstream fixes are what
-- made these adoptable, all recorded in closed issue #22 (LIBKA0S-04):
--
--   * the dropdown reads `values` as the ordered { value =, text = } array this
--     addon declares, rather than as a key map;
--   * `hasAlpha` defaults to TRUE, which is what all seven color rows here
--     assume by declaring nothing;
--   * `sliderCommit` exists at all, so the Macro Bar page keeps its live drag
--     preview.
--
-- A fourth was never recorded there: the makers read `row.desc` where every Ka0s
-- schema declares `tooltip`, which would have blanked every tooltip body while
-- leaving the label rendering — silently, and only in game.
--
-- Helpers.EnumValues stays here, and it is not vocabulary any more -- it is the
-- string rule's single reader. `validateString` below calls it, and nothing
-- else in core/, modules/ or settings/ does. It used to be settings/MacroBar.lua's
-- too; that stopped being true when M3-04 deleted the three `values` overrides,
-- and the export survived because the job it does moved INTO this file rather
-- than out of it. tests/test_macrobar.lua and tests/test_schema.lua still pin it.
--
-- `Helpers.LSMValues` used to be named here beside it. It is gone -- see the note
-- below, where it used to be defined, for why the shape it adapted is no longer
-- a shape anything asks for.

-- BOTH enum shapes a row here can carry, normalized to the ordered
-- `{ value =, text = }` array every caller of this function reads:
--
--   ordered array  { { value = "TOP", text = "Top" }, ... }        settings/MacroBar.lua's `enum`
--   key map        { ITEM = "Item", SPELL = "Spell" }              settings/CategoryAddByID.lua:61,
--                                                                  settings/StatPriority.lua:74,
--                                                                  and every composed row whose
--                                                                  list is the library's, media
--                                                                  rows included as of v1.26.0
--
-- The array is told apart by its first element being a table carrying `value`,
-- exactly as `enumList` (libs/LibKa0s/OptionsWidgets.lua:105-109) tells them apart;
-- nothing else a row declares can look like that.
--
-- WHY THIS IS NOT COSMETIC. `validateString` below reads this list and
-- guards on `#allowed > 0`. A key map measures 0, so an un-normalized one does
-- not raise -- it walks straight past the membership test, and `/cm set` starts
-- accepting any string at all for a row whose dropdown offers three. It fails
-- open and silently, which is why the normalization lives here, at the single
-- reader, rather than at each caller.
--
-- `sorting` is honored for the same reason the library honors it: the CLI's
-- allowed-values message and the dropdown must list the same things in the same
-- order, or a player reads one order and types against another.
local function enumValues(def)
    local v = type(def.values) == "function" and def.values() or def.values
    if type(v) ~= "table" then return {} end
    if next(v) == nil then return v end
    if type(v[1]) == "table" and v[1].value ~= nil then return v end

    local keys = {}
    if type(def.sorting) == "table" then
        for i, k in ipairs(def.sorting) do keys[i] = k end
    else
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return tostring(a) < tostring(b)
        end)
    end

    local out = {}
    for i, k in ipairs(keys) do
        local text = v[k]
        out[i] = { value = k, text = type(text) == "string" and text or tostring(k) }
    end
    return out
end
Helpers.EnumValues = enumValues

-- THE HOST `LSMValues` SHADOW IS GONE, and its absence is the point. It was a
-- shape adapter: the library's O.LSMValues answers a deferred closure over a
-- self-keyed HASH, and this addon's media rows used to declare the ordered
-- { value =, text = } array instead, so the wrapper flattened one into the other.
-- Its only caller in core/, modules/ or settings/ was settings/MacroBar.lua's
-- `lsmValues`, the LibKa0s issue #15 workaround -- and M3-04 deleted that with
-- the re-vendor carrying the upstream fix, leaving the adapter nothing to adapt.
--
-- Both halves of what it added are elsewhere now, and better placed. The
-- non-empty guarantee -- "None" when a media type has nothing registered, so the
-- dropdown can be opened AND ValidateSchemaValue does not reject the value
-- already stored -- is the library's own, in `O.LSMValues` (libs/LibKa0s/Options.lua).
-- This addon had it first and upstream took it. The hash-to-array conversion is
-- `enumValues` above, which reads BOTH shapes at the one place needing an array.
-- So the wrapper was not merely uncalled: it was two pieces of code that had
-- each moved somewhere better, kept alive by tests that existed to test it.
--
-- What removing it changes for a caller: `Helpers.LSMValues` still resolves,
-- through settings/OptionsSetup.lua's `__index`, but to the LIBRARY's -- a
-- function returning a function over a hash, not an array. Anything wanting an
-- array puts it through `Helpers.EnumValues`, exactly as every composed row does.

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
    if leftSpec  then makeButton(row, leftSpec,  Helpers.BUTTON_PAIR_REL) end
    if rightSpec then makeButton(row, rightSpec, Helpers.BUTTON_PAIR_REL) end
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
-- what made the registry adoptable at all (LIBKA0S-05, issue #24). The names and
-- semantics are identical, so every caller here is unchanged.
--
-- Both resolve through __index when the library is present and are the no-ops
-- bound at the seam above when it is not, so the two bare calls below —
-- SetAndRefresh's RefreshScalars and O.Refresh's RefreshAllPanels — are
-- callable on BOTH paths.

-- A whole-value row's member set: a list, or a function answering one (the bar's
-- slot keys are only known once the categories have loaded).
local function membersOf(def)
    local m = def.members
    if type(m) == "function" then m = m() end
    return type(m) == "table" and m or {}
end

-- A FLAG MAP (a composite's `enabled`, the bar's `shown`): keys outside the
-- member set are dropped, and every kept value must be a real boolean -- the
-- readers test `~= false`, so a string or a number would silently read as on.
local function normalizeFlagMap(def, value)
    local known, out = {}, {}
    for _, m in ipairs(membersOf(def)) do known[m] = true end
    for k, v in pairs(value) do
        if known[k] then
            if type(v) ~= "boolean" then
                return nil, "expected true or false for " .. tostring(k)
            end
            out[k] = v
        end
    end
    return out
end

local function copyShallow(value)
    local out = {}
    for k, v in pairs(value) do out[k] = v end
    return out
end

local function isType(want, why)
    return function(_, value)
        if type(value) ~= want then return false, why end
        return true
    end
end

-- Enum rows (a `values` list) reject anything outside the list, so the
-- dropdown and `/cm set` can't write a value the renderer can't display.
local function validateString(def, value)
    if type(value) ~= "string" then return false, "expected string" end
    local allowed = enumValues(def)
    if #allowed > 0 then
        local names = {}
        for i, item in ipairs(allowed) do
            if item.value == value then return true end
            names[i] = tostring(item.value)
        end
        return false, "allowed values: " .. table.concat(names, ", ")
    end
    return true
end

-- One rule per declared schema type, split the way LibKa0s-Schema-1.0's
-- pipeline splits it: `validate(def, value) -> ok, why` refuses, and
-- `normalize(def, value) -> value | nil, why` answers what is stored. bool,
-- string and enum are validate-only. A type with no entry here passes its value
-- through untouched, as the elseif chain this replaced always did.
local TYPE_RULES = {
    bool = { validate = isType("boolean", "expected boolean") },

    -- min and max are independently optional, so the clamp is two separate
    -- one-sided tests rather than a range check.
    number = {
        validate  = isType("number", "expected number"),
        normalize = function(def, value)
            if def.min then value = math.max(def.min, value) end
            if def.max then value = math.min(def.max, value) end
            return value
        end,
    },

    string = { validate = validateString },

    -- Always a fresh table: a color row's `default` IS the dbDefaults table, and
    -- a reset sends it through the seam. Stored as-is it would alias the shipped
    -- default, and AceDB's removeDefaults on a later SetProfile nils its channels
    -- in place -- every profile after that reads an empty color. The seam copies
    -- a table into the store as well; this copy is what `apply` and the log see.
    color = { validate = isType("table", "expected color table"),
              normalize = function(_, value) return copyShallow(value) end },

    -- A WHOLE-VALUE list over a fixed member set (architecture-§5): the bar's
    -- slot order, a composite's section. NORMALIZED, not merely checked: unknown
    -- and repeated members are dropped and every missing one is appended in the
    -- member set's own order, so a stored order names each member exactly once.
    order = {
        validate  = isType("table", "expected a list"),
        normalize = function(def, value)
            local members = membersOf(def)
            local known, seen, out = {}, {}, {}
            for _, m in ipairs(members) do known[m] = true end
            for _, m in ipairs(value) do
                if known[m] and not seen[m] then seen[m] = true; out[#out + 1] = m end
            end
            for _, m in ipairs(members) do
                if not seen[m] then seen[m] = true; out[#out + 1] = m end
            end
            return out
        end,
    },

    -- A WHOLE-VALUE keyed map. A row naming `members` is a flag map; anything
    -- else is copied. A row with its OWN `normalize` (stat priority's) keeps it,
    -- which is LibKa0s-Schema-1.0's row.normalize: see stampRow.
    map = {
        validate  = isType("table", "expected a table"),
        normalize = function(def, value)
            if def.members then return normalizeFlagMap(def, value) end
            return copyShallow(value)
        end,
    },
}

-- Put the row's type rule on the row, closed over it, where the library's
-- pipeline reads it: `validate` and `normalize`. A row that already carries
-- its own keeps it. Stamped once; `__typed` is the marker.
local function stampRow(row)
    if type(row) ~= "table" or row.__typed then return end
    row.__typed = true
    local rule = TYPE_RULES[row.type]
    if not rule then return end
    if row.validate == nil and rule.validate then
        row.validate = function(value) return rule.validate(row, value) end
    end
    if row.normalize == nil and rule.normalize then
        row.normalize = function(value) return rule.normalize(row, value) end
    end
end

local function registerRow(row)
    stampRow(row)
    if row.neverReset and type(row.path) == "string" then resetExempt[row.path] = true end
end

--- Append hand-written rows to the schema: stamped with their type rules and
--- indexed by the seam, which is what makes a row writable at all.
function Helpers.AddRows(list)
    for _, row in ipairs(list) do registerRow(row) end
    return S.AddRows(list)
end

function Helpers.AddRow(row)
    Helpers.AddRows({ row })
    return row
end

-- Validate and coerce a value against a row's declared type, the way the seam
-- would, without writing it. Returns the value that would be stored, or nil and
-- the reason. A thin read of TYPE_RULES kept for the suites that pin each rule;
-- the seam itself reads the stamped row fields.
local function validateSchemaValue(def, value)
    local rule = TYPE_RULES[def.type]
    if not rule then return value end
    local ok, why = rule.validate(def, value)
    if not ok then return nil, why end
    if type(def.normalize) == "function" then return def.normalize(value) end
    if rule.normalize then return rule.normalize(def, value) end
    return value
end
Helpers.ValidateSchemaValue = validateSchemaValue

-- The door a player's write takes -- a widget, `/cm enable`, a page button:
-- the seam, and on a refusal one line saying why. Returns true on success.
function Helpers.SetAndRefresh(path, value)
    local ok, err, why = S.Set(path, value)
    if not ok then
        -- An unknown path or a missing db is refused silently, as it always was
        -- here: every caller is addon code naming its own rows. A refused VALUE
        -- is the player's, and its rule always says why, so it is reported.
        if why ~= nil then
            KCM.Say("invalid value for " .. tostring(path) .. ": " .. tostring(why or err))
        end
        return false
    end
    return true
end

-- Several rows as ONE act, all or nothing: the library's SetMany prepares every
-- entry before the first store, so a batch holding one bad value writes none.
-- A page reset is what it exists for: sixty rows through SetAndRefresh would be
-- sixty reactions and sixty refreshes for one click.
--
-- `opts.onChange` names the one apply pass a page's rows all share (the Macro
-- Bar page's MacroBar.Update), and then it runs instead of the rows' own.
-- `opts.structural` swaps the in-place re-sync for a page rebuild.
-- `opts.bulk = { act =, scope = }` makes the batch ONE bracket: one
-- `[Set] <act> <scope>: N rows` line and no per-row line (debug-logging-§10).
--
-- @param entries  array of { path = <schema path>, value = <new value> }
-- @return boolean  true when every entry was written
function Helpers.SetManyAndRefresh(entries, opts)
    opts = opts or {}
    local b = opts.bulk
    local prev = batchCtx
    batchCtx = { onChange = opts.onChange, structural = opts.structural }
    local ran, ok, err, why, at = pcall(S.SetMany, entries or {},
        { act = b and b.act, scope = b and b.scope })
    batchCtx = prev
    if not ran then error(ok, 0) end
    if not ok then
        if why ~= nil then
            local e = entries and entries[at]
            KCM.Say("invalid value for " .. tostring(e and e.path) .. ": " .. tostring(why or err))
        end
        return false
    end
    return true
end

-- Published unified setter (architecture-§5): NS.Schema:Set(path, value), and
-- its batch form NS.Schema:SetMany(entries, opts).
KCM.Schema = KCM.Schema or {}
function KCM.Schema:Set(path, value)
    return Helpers.SetAndRefresh(path, value)
end
function KCM.Schema:SetMany(entries, opts)
    return Helpers.SetManyAndRefresh(entries, opts)
end

-- ---------------------------------------------------------------------
-- Schema rows. Each row defines a scalar setting that the General panel
-- renders as a widget AND that /cm list / get / set sees on the CLI.
-- Adding a new scalar = one row.
-- ---------------------------------------------------------------------
--
-- NO ROWS ARE DECLARED IN THIS FILE ANY MORE. The `enabled` master toggle used
-- to be here, hand-written; it is one of the eight rows the library's
-- MasterControls composer emits now, and it lives with the rest of its block in
-- settings/General.lua (options-ui-§15). Two declarations of one setting is the
-- failure that whole rule exists to remove, so the old one is gone rather than
-- kept "for the CLI".
--
-- The session DEBUG FLAG (KCM.State.debug) is still not a row: it is armed by
-- `/cm debug on|off` and by the console's own toggle, never persisted, and never
-- what the Master controls tab's `Debug console` row writes -- that row shows and
-- hides the WINDOW, which is what a bare `/cm debug` does (debug-logging-§5).

--- Append a COMPOSED block to the schema, stamping the fields the composers do
--- not know about.
---
--- The composers (OptionsCompose) emit `path`, `page`, `group`, `subgroup`,
--- `order`, `type`, `label`, `tooltip` and `default` -- everything options-ui-§16
--- and options-ui-§17 pin. What they cannot know is this addon's own row vocabulary:
--- `panel` and `section` (which ValidateSchema checks), the `apply` that reacts
--- to the write, a store of its own (`get`/`set`), and the ordered
--- `{ value =, text = }` media lists this addon declares where the library
--- declares a hash. The type rules are stamped after the decoration, so a
--- decorated `validate` or `normalize` wins.
---
--- `decorate` is keyed by the row's stored PATH rather than by its position, so
--- a composer that gains a row cannot silently re-target somebody else's
--- reaction.
function Helpers.RegisterRows(rows, panel, section, decorate)
    for _, row in ipairs(rows) do
        row.panel   = panel
        row.section = section
        -- Provenance, and the one thing a test cannot derive: a composed row and
        -- a hand-written one are deliberately indistinguishable to every reader
        -- EXCEPT the degraded-parity case, which has to know which rows are
        -- expected to be absent when the composers are stubbed out
        -- (tests/test_settingsui.lua's measurement).
        row.__composed = true
        local extra = decorate and decorate[row.path]
        if extra then
            for k, v in pairs(extra) do row[k] = v end
        end
    end
    Helpers.AddRows(rows)
    return rows
end

-- ---------------------------------------------------------------------
-- About content (parent canvas). Logo + addon notes + slash command list.
-- ---------------------------------------------------------------------

-- Through core/EnvSetup.lua rather than C_AddOns directly, which also retires
-- the hardcoded "ConsumableMaster" this used to pass: the seam hands the library
-- the first vararg, so a folder rename cannot leave this reading somebody else's
-- manifest -- or none -- and saying nothing about it.
local function readAddOnNotes()
    return KCM.Meta("Notes") or ""
end

-- The logo block. SimpleGroup is full-width so AceGUI's List layout gives it a
-- known cell to live in; the texture inside is anchored TOPLEFT at native pixel
-- size so it renders left-aligned regardless of panel width.
local function aboutLogo(scroll)
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(LOGO_PIXELS)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(LOGO_TEXTURE)
    logoTex:SetSize(LOGO_PIXELS, LOGO_PIXELS)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)
end

-- The addon's own Notes line, in the body font. Every `and` in the two font
-- guards is a guard over an AceGUI internal: `label` is the widget's own
-- fontstring and a widget skin is allowed not to have one, so a missing field
-- leaves the default font rather than raising inside a settings page.
local function aboutNotes(scroll)
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
end

-- The slash listing, heading and all.
--
-- Convergence #2 (LIBKA0S-13): one row formatter for the whole addon. These
-- lines come back already rendered by lib.FormatRow, the same function
-- /cm help's rows go through -- so the panel and the chat cannot drift
-- apart again by an edit to one of them. The visible cost is the one every
-- other adopter paid: the spacing either side of the em dash halves, the
-- dash loses its white color span, and the description gains one.
local function aboutSlashCommands(scroll)
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetHeight(Helpers.SECTION_HEADING_H)
    heading:SetText(L["Slash Commands"])
    if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
        heading.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(heading)

    addSpacer(scroll, 6)

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

-- The parent canvas, in the order the page reads: logo, notes, slash listing.
-- The three draw steps are named above rather than written out here, which is
-- what keeps this function the page's TABLE OF CONTENTS -- and what took it off
-- the complexity watch list: every guard below moved with the block it guards,
-- and not one of them was dropped.
function Helpers.BuildAboutContent(ctx)
    local scroll = ensureScroll(ctx)
    aboutLogo(scroll)
    addSpacer(scroll, 8)
    aboutNotes(scroll)
    addSpacer(scroll, 12)
    aboutSlashCommands(scroll)
end

-- ---------------------------------------------------------------------
-- Tab + main-category registration
-- ---------------------------------------------------------------------

-- The library's page registry, fed in KCM.Settings.order, once. Guarded by a
-- flag because registerPanel is reached more than once (PLAYER_LOGIN, then
-- ADDON_LOADED("Blizzard_Settings"), or a second bootstrap event before the
-- Settings API exists), and a page queued twice would be built twice.
local pagesQueued = false

function KCM.Settings.RegisterTab(key, builder)
    if type(key) ~= "string" or type(builder) ~= "function" then return end
    KCM.Settings.builders[key] = builder
    -- A page registered after the queue was fed goes straight to the library,
    -- which builds it at once if the panel already exists.
    if pagesQueued and UI then UI.RegisterOptionsPage(key, key, builder) end
end

-- Hand the whole options surface to LibKa0s-Options-1.0's CreateOptionsPanel:
-- the main canvas (the descriptor's buildMain, settings/OptionsSetup.lua), the
-- schema validation (its validate) and every page builder, in sidebar order.
--
-- Settings.RegisterAddOnCategory is protected, and an in-combat /reload or a
-- mid-pull force-load of Blizzard_Settings reaches this. The library parks the
-- registration under lockdown and replays it on its own PLAYER_REGEN_ENABLED
-- frame, whatever this addon's stand-down state: the category and its Enable
-- checkbox are setup that survives a disable (slash-commands-§7). The host
-- park this replaced replayed from OnRegenEnabled, after its stood-down
-- return, and lost the category for the session (ConsumableMaster-R-03).
--
-- Answers true once the request is the library's, which is what lets the
-- bootstrap below let go of its events.
local function registerPanel()
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
        return false
    end
    if not (Settings and Settings.RegisterCanvasLayoutCategory
            and Settings.RegisterAddOnCategory) then
        return false
    end

    if not pagesQueued then
        pagesQueued = true
        for _, key in ipairs(KCM.Settings.order) do
            local fn = KCM.Settings.builders[key]
            if type(fn) == "function" then UI.RegisterOptionsPage(key, key, fn) end
        end
    end
    -- Idempotent, and parks itself in combat: a second call is a no-op.
    UI.CreateOptionsPanel()
    return true
end
KCM.Settings.Register = registerPanel

-- Bootstrap: defer until Blizzard_Settings is ready. Once registerPanel has
-- handed the request over, the library owns the park and the replay, so this
-- frame has nothing left to listen for.
local bootstrap = CreateFrame("Frame")
-- Through KCM.SafeRegisterEvent like every other registration here
-- (events-frames-taint-§1); a frame ignores the nil handler.
KCM.SafeRegisterEvent(bootstrap, "PLAYER_LOGIN", nil, KCM.RejectedEvents)
KCM.SafeRegisterEvent(bootstrap, "ADDON_LOADED", nil, KCM.RejectedEvents)
bootstrap:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_Settings" then return end
    if registerPanel() then
        self:UnregisterAllEvents()
    end
end)
