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

local LOGO_TEXTURE = [[Interface\AddOns\ConsumableMaster\media\logos\consumablemaster.logo.tga]]
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

-- ---------------------------------------------------------------------
-- Session-only paths — settings whose store is NOT db.profile
-- ---------------------------------------------------------------------
--
-- One entry today: the debug console's visibility. options-ui-§15 puts a
-- `Debug console` row on the Master controls tab and debug-logging keeps it
-- SESSION-only -- a console left open is not a setting the next character
-- inherits -- so it has a schema `path` like every other row and no home in the
-- profile. The library's MasterControls composer names that path
-- `state.debugConsole` verbatim, which is why the key below is a literal rather
-- than something derived.
--
-- Resolved HERE rather than in Resolve() because Resolve's contract is "a
-- db.profile parent and a key", and answering a synthetic parent for a value
-- that lives in neither would make `/cm get` report a table nobody stores.
--
-- The console itself is untouched: this is the same show/hide a bare `/cm debug`
-- performs and it never arms LOGGING (KCM.State.debug), which stays the separate
-- flag it has always been (debug-logging-§5).
local SESSION_PATHS = {
    ["state.debugConsole"] = {
        get = function()
            local DL = KCM.DebugLog
            return (DL and DL.IsWindowShown and DL.IsWindowShown()) and true or false
        end,
        set = function(v)
            local DL = KCM.DebugLog
            if not DL then return false end
            if v then
                if DL.Show then DL.Show() end
            elseif DL.Hide then
                DL.Hide()
            end
            return true
        end,
    },
}
Helpers.SESSION_PATHS = SESSION_PATHS

-- ---------------------------------------------------------------------
-- Global-store paths -- STORED settings whose home is db.global, not db.profile
-- ---------------------------------------------------------------------
--
-- One entry today, and it is the minimap button's visibility. Unlike
-- SESSION_PATHS above these rows ARE persisted -- they simply persist somewhere
-- Helpers.Resolve cannot reach, because Resolve's contract is "a db.profile
-- parent and a key" and launcher-§3 fixes this table in the GLOBAL store: a
-- minimap button belongs to the installation, so a profile switch must not move
-- the player's buttons and options-ui-§12's *Reset all settings* -- a profile
-- reset by definition -- must not un-hide one they deliberately hid.
--
-- A SECOND TABLE RATHER THAN A WIDER SESSION_PATHS, because the two differ in
-- the one place it matters: settings/OptionsSetup.lua's `vetoedFromResetAll`
-- keys the global reset's sweep on `row.sessionOnly`, and this row is not
-- session-only. Folding it in beside the console would have been one table with
-- two meanings, and the reset would be reading the wrong one.
--
-- THE INVERSION LIVES HERE, in the single write seam, exactly as launcher-§3
-- says it should. The row's label says SHOWN; LibDBIcon's key says HIDDEN. That
-- is the whole cost of storing the library's own key rather than a second
-- boolean beside it -- LibDBIcon writes `hide` itself when the player uses the
-- button's own menu, and a parallel `show` would be free to disagree with it
-- (anti-pattern #81). The `set` calls the launcher afterwards so the button
-- follows the checkbox immediately rather than at the next reload; the launcher
-- writes `hide` a second time with the same value, which is deliberate on its
-- side so a caller reaching it from elsewhere need not know the inversion.
--
-- The path is `global.minimap.hide` VERBATIM and unprefixed, for the same
-- reason `state.debugConsole` is: the library's MasterControls composer takes
-- `minimapPath` as given because the table lives outside the block's profile
-- prefix.
local function minimapTable()
    return KCM.db and KCM.db.global and KCM.db.global.minimap
end

local GLOBAL_PATHS = {
    ["global.minimap.hide"] = {
        get = function()
            local t = minimapTable()
            -- Shown is the answer when there is no table yet: that is what a
            -- fresh profile ships as, and it is what the button does.
            return not (t and t.hide)
        end,
        set = function(v)
            local t = minimapTable()
            if not t then return false end
            t.hide = not v
            if KCM.Launcher then KCM.Launcher:SetShown(v and true or false) end
            return true
        end,
    },
}
Helpers.GLOBAL_PATHS = GLOBAL_PATHS

-- The one lookup both diversions answer to. Every seam below asks this rather
-- than indexing either table, so a third store can only ever be added in one
-- place.
local function divertedPath(path)
    return SESSION_PATHS[path] or GLOBAL_PATHS[path]
end

function Helpers.Get(path)
    local diverted = divertedPath(path)
    if diverted then return diverted.get() end
    local parent, key = Helpers.Resolve(path)
    if not parent then return nil end
    return parent[key]
end

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

-- The bulk bracket (debug-logging-§10). A bulk copy or reset is ONE
-- `[Set] <act> <scope>: N rows` line, never a line per row, and N is the rows
-- whose stored value the act actually CHANGED -- a row already at its default is
-- not counted. While a bracket is open, Helpers.Set tallies instead of logging.
--
-- `bulk` is the innermost open frame, `prev` the one it sits in, so the chain is
-- the depth counter: a frame that closes inside another folds its tally into it,
-- and only the outermost one logs. A MuteSetLog frame logs nothing and silences
-- every frame around it -- that is the global reset, whose one line is the
-- OnProfileReset handler's. SilenceOpenBulk does the same from outside a frame,
-- for a profile handler whose line lands while a bracket is open.
local bulk = nil

local function sameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not sameValue(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

function Helpers.Set(path, value)
    local diverted = divertedPath(path)
    -- Read BEFORE the write, and only inside a bracket: nothing else needs it.
    local before
    if bulk then before = Helpers.Get(path) end
    local ok
    if diverted then
        ok = diverted.set(value) and true or false
    else
        local parent, key = Helpers.Resolve(path)
        if not parent then return false end
        parent[key] = value
        ok = true
    end
    if not ok then return false end
    if bulk then
        if not sameValue(before, value) then bulk.count = bulk.count + 1 end
    elseif KCM.State and KCM.State.debug then
        KCM.Debug("Set", "%s = %s", tostring(path), logValue(value))
    end
    return true
end

-- Runs fn inside a frame. A raising fn still closes it, so a mute cannot stick.
-- Answers pcall's ok and error, the frame's tally, and whether it was nested.
local function runFrame(fn, silent)
    local frame = { count = 0, prev = bulk, silent = silent }
    bulk = frame
    local ok, err = pcall(fn)
    bulk = frame.prev
    local outer = frame.prev
    if outer then
        outer.count  = outer.count + frame.count
        outer.silent = outer.silent or frame.silent
    end
    return ok, err, frame, outer ~= nil
end

--- Run fn as ONE bulk act: every Helpers.Set inside it validates, writes and
--- reacts exactly as it would outside, but logs no row of its own. When fn
--- returns (or raises) the act logs `[Set] <act> <scope>: N rows`, N being the
--- rows it changed; a bracket nested in another logs nothing and its rows count
--- toward the outer line. An act that raises still logs its one line, ending
--- ` (stopped by an error)`, and the error is then re-raised unwrapped.
--- @return number  the rows changed
function Helpers.Bulk(act, scope, fn)
    local ok, err, frame, nested = runFrame(fn, false)
    if not (nested or frame.silent) and KCM.State and KCM.State.debug then
        KCM.Debug("Set", ok and "%s %s: %s rows" or "%s %s: %s rows (stopped by an error)",
            tostring(act), tostring(scope), tostring(frame.count))
    end
    if not ok then error(err, 0) end
    return frame.count
end

--- Run fn with the per-row line muted and NO line of its own, for an act another
--- seam logs once: the global reset, logged by the OnProfileReset handler. A
--- bracket around it logs nothing either (one line overall).
--- @return number  the rows changed
function Helpers.MuteSetLog(fn)
    local ok, err, frame = runFrame(fn, true)
    if not ok then error(err, 0) end
    return frame.count
end

--- Silence the bracket open right now, if there is one, because another seam has
--- just logged the whole act: a profile reset or copy, whose one line is the
--- profile handler's (core/ConsumableMaster.lua). Every frame around it goes
--- quiet as it closes; a bracket opened afterwards logs as usual.
function Helpers.SilenceOpenBulk()
    if bulk then bulk.silent = true end
end

function Helpers.FindSchema(path)
    for _, def in ipairs(KCM.Settings.Schema) do
        if def.path == path then return def end
    end
    return nil
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
-- fixed member set, and a keyed map. See VALIDATORS below.
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
-- Everything ABOVE this line is the schema half and stays the addon's: the
-- rows themselves, Resolve / Get / Set / FindSchema / ValidateSchema, and (far
-- below) the SetAndRefresh write seam. None of it touches the library, which is
-- what keeps `/cm list|get|set` working on an install where LibKa0s is missing.
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
-- validator's single reader. `validateSchemaValue` below calls it, and nothing
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
-- exactly as `enumList` (libs/LibKa0s/OptionsWidgets.lua:78-79) tells them apart;
-- nothing else a row declares can look like that.
--
-- WHY THIS IS NOT COSMETIC. `validateSchemaValue` below reads this list and
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

    -- Always a fresh table, for the same reason as `order` below: a color row's
    -- `default` IS the dbDefaults table, and the reset's applyDefault
    -- (settings/Slash.lua) sends it through SetAndRefresh. Stored as-is it aliases
    -- the shipped default, and AceDB's removeDefaults on a later SetProfile nils
    -- its channels in place -- every profile after that reads an empty color.
    color = function(_, value)
        if type(value) ~= "table" then return nil, "expected color table" end
        local out = {}
        for k, v in pairs(value) do out[k] = v end
        return out
    end,

    -- A WHOLE-VALUE list over a fixed member set (architecture-§5): the bar's slot
    -- order, a composite's section. NORMALIZED, not merely checked: unknown and
    -- repeated members are dropped and every missing one is appended in the member
    -- set's own order, so a stored order names each member exactly once. Always a
    -- fresh table, so neither a caller's list nor a row's `default` -- which IS the
    -- dbDefaults table -- is ever what gets stored.
    order = function(def, value)
        if type(value) ~= "table" then return nil, "expected a list" end
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

    -- A WHOLE-VALUE keyed map. A row with its own `normalize` (stat priority's) is
    -- handed the map; a row naming `members` is a flag map; anything else is
    -- copied. Every arm answers a fresh table.
    map = function(def, value)
        if type(value) ~= "table" then return nil, "expected a table" end
        if type(def.normalize) == "function" then return def.normalize(value) end
        if def.members then return normalizeFlagMap(def, value) end
        local out = {}
        for k, v in pairs(value) do out[k] = v end
        return out
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
    -- Scalar write → in-place widget re-sync, never a page rebuild (options-ui-§11).
    Helpers.RefreshScalars()
    return true
end

-- The reactors a batch runs: the caller's one `opts.onChange` when it names one,
-- otherwise each DISTINCT row onChange once, in first-seen order, handed the value
-- of the first row that carries it.
local function runBatchReactors(plan, opts)
    if opts and opts.onChange then
        -- Reported under the batch's first path, through the one reporter a row's
        -- own onChange uses, so a failure reads the same whichever reactor raised.
        fireOnChange({ path = plan[1] and plan[1].def.path, onChange = opts.onChange })
        return
    end
    local ran = {}
    for _, step in ipairs(plan) do
        local fn = step.def.onChange
        if fn and not ran[fn] then
            ran[fn] = true
            fireOnChange(step.def, step.value)
        end
    end
end

-- Several rows as ONE act. It is the seam SetAndRefresh is -- validate, write
-- through Helpers.Set, react, refresh -- taken once for the whole batch rather
-- than once per row. A page reset is what it exists for: sixty rows through
-- SetAndRefresh would be sixty onChanges and sixty refreshes for one click.
--
-- LOGGING (debug-logging-§10). A plain batch logs one [Set] line per row. A batch
-- that IS a bulk copy or reset passes `opts.bulk = { act = , scope = }`, and then
-- its writes and reactors run inside Helpers.Bulk: one `[Set] <act> <scope>: N rows`
-- line, no per-row line. The bracket opens only after validation, so a refused
-- batch logs nothing.
--
-- ALL OR NOTHING: every entry is resolved and validated before the first write,
-- so a batch holding one bad value writes none of them.
--
-- `opts.onChange` names the one apply pass a page's rows all share (the Macro
-- Bar page's MacroBar.Update), and then it runs instead of the rows' own.
-- `opts.structural` swaps the in-place re-sync for a page rebuild, for a batch
-- that changes what a page draws and not only the values it shows.
--
-- @param entries  array of { path = <schema path>, value = <new value> }
-- @return boolean  true when every entry was written
function Helpers.SetManyAndRefresh(entries, opts)
    local plan = {}
    for i, e in ipairs(entries or {}) do
        -- A path that is not a row is refused silently, exactly as SetAndRefresh
        -- refuses one: every caller is addon code naming its own rows.
        local def = Helpers.FindSchema(e.path)
        if not def then return false end
        local coerced, reason = validateSchemaValue(def, e.value)
        if coerced == nil then
            KCM.Say("invalid value for " .. tostring(e.path) .. ": "
                  .. tostring(reason or "value must not be nil"))
            return false
        end
        if not (divertedPath(def.path) or Helpers.Resolve(def.path)) then return false end
        plan[i] = { def = def, value = coerced }
    end
    local function apply()
        for _, step in ipairs(plan) do Helpers.Set(step.def.path, step.value) end
        runBatchReactors(plan, opts)
    end
    local b = opts and opts.bulk
    if b then Helpers.Bulk(b.act, b.scope, apply) else apply() end
    if opts and opts.structural then Helpers.RefreshAllPanels() else Helpers.RefreshScalars() end
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
--- `panel` and `section` (which ValidateSchema checks), the `onChange` that
--- applies the write, and the ordered `{ value =, text = }` media lists this
--- addon declares where the library declares a hash.
---
--- `decorate` is keyed by the row's stored PATH rather than by its position, so
--- a composer that gains a row cannot silently re-target somebody else's
--- onChange.
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
        KCM.Settings.Schema[#KCM.Settings.Schema + 1] = row
    end
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
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "Blizzard_Settings" then return end
    if registerPanel() then
        self:UnregisterAllEvents()
    end
end)
