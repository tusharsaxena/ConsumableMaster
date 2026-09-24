-- tests/test_profiles.lua -- the Profiles page, and what a profile switch, copy or
-- reset has to reach.
--
-- Every setting this addon stores lives in db.profile, so a profile act replaces
-- the whole of it at once and three things have to follow. Each has its own cases:
--
--   * the MACRO BAR, fully re-applied (anchor, grid, order, shown slots, enabled,
--     lock) rather than merely repainted -- a repaint re-reads icons and counts and
--     nothing else, which left the outgoing profile's bar on screen until /reload;
--   * the MACROS, rewritten even where the incoming profile's stored fingerprint
--     happens to match what it computes -- the macros are account-wide and the
--     fingerprints are per profile, so a match proves nothing about the live body;
--   * the PROFILES PAGE, redrawn when a profile event says so and not on every
--     pipeline refresh, which would tear AceConfigDialog's tree down under an open
--     dropdown.
--
-- options-ui-§12's testing MUST is here too: a global reset leaves the profile
-- list and the active profile alone and publishes the profile-changed message.

local h = _G.KCM_TEST
local test = h.test

local APP = "ConsumableMaster-Profiles"

local function lib(name) return h.loader.mock.libs[name] end

--- Build the Profiles page, mark it on screen and show it.
local function showProfiles(KCM)
    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders.profiles({})
    local ctx = UI.__panelFor("profiles")
    ctx.panel.IsShown = function() return true end
    ctx.panel:_run("OnShow")
    return ctx
end

local function consoleDouble(KCM)
    local state = { shown = false }
    KCM.DebugLog.Show          = function() state.shown = true end
    KCM.DebugLog.Hide          = function() state.shown = false end
    KCM.DebugLog.IsWindowShown = function() return state.shown end
    return state
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

-- red under: appending "profiles" anywhere but last, or loading the file before
-- the pages it follows.
test("Profiles: the page is the last in the sidebar and its file loads last", function(t)
    local KCM = h.loader.loadFullAddon()
    local order = KCM.Settings.order
    t.eq(order[#order], "profiles", "Profiles is the last page in the sidebar")
    t.eq(type(KCM.Settings.builders.profiles), "function", "and it registered a builder")
    local files = h.loader.tocFiles()
    t.eq(files[#files], "settings/Profiles.lua", "and its file is the last the TOC loads")
end)

-- red under: building the options table over anything but the live db, or giving
-- the page a Defaults action -- "restore defaults" here would mean deleting
-- profiles (options-ui-§3).
test("Profiles: the page hosts AceDBOptions' own table and carries no Defaults button", function(t)
    local KCM = h.loader.loadFullAddon()
    local ctx = showProfiles(KCM)

    local reg = lib("AceConfig-3.0").__registered[APP]
    t.truthy(reg, "the AceDBOptions table is registered under the page's app name")
    t.eq(reg and reg.__db, KCM.db, "built over the live db")
    t.eq(ctx.panel.defaultsOnClick, nil, "no Defaults action on this page")

    local ACD = lib("AceConfigDialog-3.0")
    t.eq(ACD.__opens, 1, "the first show draws the page")
    t.eq(ACD.__lastOpen and ACD.__lastOpen.name, APP, "from that table")
end)

-- AceGUI hands a POOLED SimpleGroup back with its frame still hidden -- Release
-- hid it, and neither Create, OnAcquire nor AceConfigDialog:Open shows it again.
-- The harness's AceGUI hands out fresh permissive widgets, so the pooled case is
-- staged here: the SimpleGroup the page asks for arrives hidden, exactly as the
-- pool would return it, and the page must show it itself.
--
-- red under: dropping the container's explicit Show() (a blank Profiles page
-- whenever any AceGUI page released a SimpleGroup first).
test("Profiles: a pooled, hidden SimpleGroup is shown before AceConfigDialog fills it", function(t)
    local KCM = h.loader.loadFullAddon()
    local AceGUI = LibStub("AceGUI-3.0")
    local realCreate = AceGUI.Create
    local pooled
    AceGUI.Create = function(self, kind, ...)
        local w = realCreate(self, kind, ...)
        if kind == "SimpleGroup" and not pooled then
            pooled = w
            local frame = w.frame
            frame.__shown = false                         -- as AceGUI:Release left it
            frame.Show    = function(f) f.__shown = true end
            frame.Hide    = function(f) f.__shown = false end
            frame.IsShown = function(f) return f.__shown end
        end
        return w
    end
    local ok, err = pcall(showProfiles, KCM)
    AceGUI.Create = realCreate
    if not ok then error(err, 0) end

    local ACD = lib("AceConfigDialog-3.0")
    t.truthy(pooled, "the page asked AceGUI for its SimpleGroup")
    t.eq(ACD.__lastOpen and ACD.__lastOpen.container, pooled, "and handed that container to AceConfigDialog")
    t.eq(pooled.frame:IsShown(), true, "the container's frame is shown, so what AceConfigDialog draws is visible")
end)

-- options-ui-§11: an open panel reflects live state after a profile switch. And
-- §11's re-render rule: only when the thing that invalidates the layout changed.
--
-- red under: no PROFILE_CHANGED listener on the page (the list goes stale), or a
-- renderer that re-Opens on every structural refresh (the pipeline's debounced
-- PANEL_REFRESH would rebuild the tree under an open dropdown every loot).
test("Profiles: a profile event redraws the page; a pipeline refresh does not", function(t)
    local KCM = h.loader.loadFullAddon()
    local ctx = showProfiles(KCM)
    local ACD = lib("AceConfigDialog-3.0")
    t.eq(ACD.__opens, 1, "drawn once on first show")

    KCM.Settings.Helpers.RefreshAllPanels()
    t.eq(ACD.__opens, 1, "a structural refresh with no profile change leaves the tree alone")

    KCM.db:SetProfile("Alt")
    t.eq(ACD.__opens, 2, "a switch made elsewhere redraws the open page")

    ctx.panel.IsShown = function() return false end
    KCM.db:SetProfile("Default")
    t.eq(ACD.__opens, 2, "a hidden page does not draw")
    ctx.panel.IsShown = function() return true end
    ctx.panel:_run("OnShow")
    t.eq(ACD.__opens, 3, "and redraws on its next show")

    KCM.db:CopyProfile("Alt")
    KCM.db:ResetProfile()
    t.eq(ACD.__opens, 5, "a copy and a reset each redraw it too")
end)

-- library-stack-§4: every LibStub lookup is silent, and a missing optional
-- library degrades to an absent page rather than a raise at login.
test("Profiles: with AceConfigDialog absent the page is simply not built", function(t)
    local KCM = h.loader.loadFiles(h.loader.tocFiles(), false, function()
        h.loader.mock.libs["AceConfigDialog-3.0"] = nil
    end)
    local ok, sub = pcall(KCM.Settings.builders.profiles, {})
    t.truthy(ok, "the builder does not raise: " .. tostring(sub))
    t.eq(sub, nil, "and registers no category")
    t.eq(KCM.Settings.Helpers.instance.__panelFor("profiles"), nil, "nor builds a panel")
end)

-- ---------------------------------------------------------------------------
-- The global-reset veto (options-ui-§3, options-ui-§12)
-- ---------------------------------------------------------------------------

-- red under: a second literal copy of the rule, or a descriptor that does not
-- carry it.
test("Profiles: the global-reset veto is named once and is the descriptor's skipRestoreAll", function(t)
    local captured
    local KCM = h.loader.loadFiles(h.loader.tocFiles(), false, function()
        local Options = LibStub("LibKa0s-Options-1.0")
        local realNew = Options.New
        Options.New = function(self, d) captured = d; return realNew(self, d) end
    end)
    local veto = KCM.Settings.VetoedFromResetAll
    t.eq(type(veto), "function", "published once, on KCM.Settings")
    t.eq(captured and captured.skipRestoreAll, veto,
        "and handed to the library as the descriptor's skipRestoreAll")
    t.truthy(veto({ panel = "profiles", sessionOnly = true }),
        "a Profiles row is vetoed even if it were session-only")
    t.truthy(veto({ path = "scale", panel = "general" }),
        "every profile-resident row is vetoed: the profile reset covers it")
    t.falsy(veto({ path = "state.debugConsole", panel = "general", sessionOnly = true }),
        "a session row is exactly what the walk keeps")
end)

-- The descriptor says what the global reset IS (LibKa0s-Options-1.0 minor 18):
-- `resetProfile` is the same db:ResetProfile() KCM.ResetAllToDefaults runs, and
-- `profilesPage` declares the AceDBOptions page this addon registers. Here the
-- library reads them for the Reset all settings tooltip and nothing else: its
-- RestoreAllDefaults, the only other reader of `resetProfile`, has no caller in
-- this addon.
--
-- red under: a descriptor without either field, or a resetProfile that does
-- anything but reset the active profile once.
test("Profiles: the Options descriptor declares the profile reset and the Profiles page", function(t)
    local captured
    local KCM = h.loader.loadFiles(h.loader.tocFiles(), false, function()
        local Options = LibStub("LibKa0s-Options-1.0")
        local realNew = Options.New
        Options.New = function(self, d) captured = d; return realNew(self, d) end
    end)
    t.eq(captured and captured.profilesPage, true, "the Profiles page is declared")
    t.eq(type(captured and captured.resetProfile), "function", "and so is the profile reset")

    local realDB, calls, receiver = KCM.db, 0, nil
    KCM.db = { ResetProfile = function(self) calls = calls + 1; receiver = self end }
    captured.resetProfile()
    local fake = KCM.db
    KCM.db = realDB
    t.eq(calls, 1, "which resets the profile, once")
    t.eq(receiver, fake, "on the live db, read when it is called rather than at load")
end)

-- The same predicate on the reset loop that actually runs: KCM.ResetAllToDefaults'
-- session sweep, which is also the degraded arm's only reset loop.
--
-- red under: restoreSessionRows testing `sessionOnly` itself instead of asking
-- the shared veto.
test("Profiles: the reset loop asks the same veto before it sweeps a row", function(t)
    local KCM = h.loader.loadFullAddon()
    local console = consoleDouble(KCM)
    local row = KCM.Settings.Helpers.FindSchema("state.debugConsole")
    local was = row.panel

    console.shown = true
    row.panel = "profiles"
    KCM.ResetAllToDefaults("test")
    t.eq(console.shown, true, "a vetoed row is left alone by the sweep")

    row.panel = was
    KCM.ResetAllToDefaults("test")
    t.eq(console.shown, false, "and swept once the veto lets it through")
end)

-- options-ui-§12's testing MUST, all four clauses: the profile list unchanged,
-- the active profile kept, the session rows swept, and the profile-changed
-- message published.
test("Profiles: a global reset empties the active profile only and publishes PROFILE_CHANGED", function(t)
    local KCM = h.loader.loadFullAddon()
    local console = consoleDouble(KCM)
    KCM.db:SetProfile("Alt");     KCM.db.profile.macroBar.buttonSize = 50
    KCM.db:SetProfile("Raid");    KCM.db.profile.scale = 1.5
    KCM.db:SetProfile("Default"); KCM.db.profile.macroBar.buttonSize = 20
    console.shown = true

    local heard = 0
    local listener = KCM.NewBusTarget()
    listener:RegisterMessage(KCM.MSG.PROFILE_CHANGED, function() heard = heard + 1 end)

    KCM.ResetAllToDefaults("test")

    local names = {}
    for name in pairs(KCM.db.profiles) do names[#names + 1] = name end
    table.sort(names)
    t.eqList(names, { "Alt", "Default", "Raid" }, "the profile list is unchanged")
    t.eq(KCM.db:GetCurrentProfile(), "Default", "the active profile is still the one you were on")
    t.eq(KCM.db.profile.macroBar.buttonSize, 36, "the active profile is back to its defaults")
    t.eq(KCM.db.profiles.Alt.macroBar.buttonSize, 50, "another profile is untouched")
    t.eq(KCM.db.profiles.Raid.scale, 1.5, "and so is every other one")
    t.eq(console.shown, false, "the session row was swept")
    t.eq(heard, 1, "and the profile-changed message went out once")
end)

-- ---------------------------------------------------------------------------
-- The macro bar is re-applied whole
-- ---------------------------------------------------------------------------

--- Build the bar and record what every apply pass does to it: the container's
--- anchor and visibility, and each button's visibility and x offset.
---
--- The container is caught on its way through CreateFrame; the buttons are not,
--- because modules/MacroBarButton.lua binds CreateFrame as a file-scope local at
--- load. They are caught at MacroBarButton.Create instead, which the bar's
--- `ensure` reaches through the table at call time.
local function watchBar(KCM)
    local frames, buttons = {}, {}
    local realCreate, realButton = _G.CreateFrame, KCM.MacroBarButton.Create
    _G.CreateFrame = function(kind, name, parent, template)
        local f = realCreate(kind, name, parent, template)
        if name then frames[name] = f end
        return f
    end
    KCM.MacroBarButton.Create = function(...)
        local btn = realButton(...)
        if btn then buttons[#buttons + 1] = btn end
        return btn
    end
    KCM.MacroBar.Update()
    _G.CreateFrame, KCM.MacroBarButton.Create = realCreate, realButton

    local seen = { buttons = {}, x = {} }
    local bar = frames.KCMMacroBar
    bar.SetPoint = function(_, point, _, relPoint, x, y) seen.anchor = { point, relPoint, x, y } end
    bar.Show     = function() seen.visible = true end
    bar.Hide     = function() seen.visible = false end
    for _, btn in ipairs(buttons) do
        btn.Show     = function(self) seen.buttons[self.catKey] = true end
        btn.Hide     = function(self) seen.buttons[self.catKey] = false end
        btn.SetPoint = function(self, _, _, _, x) seen.x[self.catKey] = x end
    end
    -- One pass with the recorders in place, so every case starts from a reading.
    KCM.MacroBar.Update()
    return seen
end

--- The slots on screen, left to right.
local function onScreen(seen)
    local keys = {}
    for key, on in pairs(seen.buttons) do
        if on then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return seen.x[a] < seen.x[b] end)
    return keys
end

--- A stored profile whose bar differs from the shipped one in every way a
--- repaint cannot see: another anchor, the slot order reversed, FOOD hidden.
--- Stamped at the current schema so no migration step touches it on arrival.
local function differentBar(KCM)
    local ship, order = KCM.dbDefaults.profile.macroBar.order, {}
    for i = #ship, 1, -1 do order[#order + 1] = ship[i] end
    local want = {}
    for _, key in ipairs(order) do
        if key ~= "FOOD" then want[#want + 1] = key end
    end
    return {
        schemaVersion = KCM.Database.CURRENT_SCHEMA,
        macroBar = {
            point = "TOP", relPoint = "TOP", x = 10, y = -20,
            order = order, shown = { FOOD = false },
        },
    }, want
end

local function shipped(KCM)
    return KCM.dbDefaults.profile.macroBar.order
end

-- red under: a profile reaction that repaints the bar (MACROBAR_REFRESH ->
-- MB.Refresh) without re-applying it (MB.Update).
test("Profiles: a switch re-applies the whole bar -- anchor, order, shown slots and enabled", function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.Database.CURRENT_SCHEMA, "the schema stamp the fixtures carry is published")
    local seen = watchBar(KCM)
    t.eqList(onScreen(seen), shipped(KCM), "precondition: the shipped bar is on screen")

    local alt, want = differentBar(KCM)
    KCM.db.profiles.Alt = alt
    KCM.db:SetProfile("Alt")
    t.eqList(seen.anchor, { "TOP", "TOP", 10, -20 }, "the bar moved to the incoming profile's anchor")
    t.eq(seen.buttons.FOOD, false, "the slot the incoming profile hides is hidden")
    t.eqList(onScreen(seen), want, "and the rest sit in its order")

    KCM.db.profiles.Off = {
        schemaVersion = KCM.Database.CURRENT_SCHEMA, macroBar = { enabled = false },
    }
    KCM.db:SetProfile("Off")
    t.eq(seen.visible, false, "a profile with the bar off takes it off screen")

    KCM.db:SetProfile("Default")
    t.eq(seen.visible, true, "switching back brings it back")
    t.eqList(seen.anchor, { "CENTER", "CENTER", 0, 0 }, "at the Default profile's anchor")
    t.eqList(onScreen(seen), shipped(KCM), "in the Default profile's order")
end)

test("Profiles: a copy re-applies the whole bar", function(t)
    local KCM = h.loader.loadFullAddon()
    local seen = watchBar(KCM)
    local alt, want = differentBar(KCM)
    KCM.db.profiles.Alt = alt

    KCM.db:CopyProfile("Alt")
    t.eq(KCM.db:GetCurrentProfile(), "Default", "a copy leaves the active profile where it was")
    t.eqList(seen.anchor, { "TOP", "TOP", 10, -20 }, "the bar took the copied anchor")
    t.eq(seen.buttons.FOOD, false, "the copied hidden slot")
    t.eqList(onScreen(seen), want, "and the copied order")
end)

test("Profiles: a reset re-applies the whole bar", function(t)
    local KCM = h.loader.loadFullAddon()
    local seen = watchBar(KCM)
    local c = KCM.db.profile.macroBar
    c.point, c.relPoint, c.x, c.y = "TOP", "TOP", 10, -20
    c.shown = { FOOD = false }
    KCM.MacroBar.Update()
    t.eqList(seen.anchor, { "TOP", "TOP", 10, -20 }, "precondition: the customized bar is on screen")

    KCM.db:ResetProfile()
    t.eqList(seen.anchor, { "CENTER", "CENTER", 0, 0 }, "the bar is back at the shipped anchor")
    t.eq(seen.buttons.FOOD, true, "the hidden slot is back")
    t.eqList(onScreen(seen), shipped(KCM), "in the shipped order")
end)

-- ---------------------------------------------------------------------------
-- The macros are rewritten
-- ---------------------------------------------------------------------------

local function ownFood(mock, id, heal)
    mock.setItem(id, { subType = "Food & Drink", tt = { healValue = heal } })
    mock.setBag(id, 1)
end

-- The account holds ONE KCM_FOOD; each profile holds its own fingerprint of the
-- body it last wrote there. Default writes the better food, Alt blocks it and
-- writes the other, and Default's fingerprint still names the better one -- which
-- is exactly what Default computes again on the way back. An early-out that
-- trusted that fingerprint would leave Alt's body live under Default's settings.
--
-- red under: a profile reaction that does not forget the incoming profile's
-- fingerprints before the resync rewrites.
test("Profiles: a switch or copy rewrites a macro whose incoming fingerprint matches a body no longer live",
    function(t)
        local KCM = h.loader.loadPure()
        local mock = h.loader.mock
        ownFood(mock, 900201, 900)
        ownFood(mock, 900202, 500)
        local function body() return mock.macros.KCM_FOOD and mock.macros.KCM_FOOD.body or "" end

        KCM.Pipeline.RunAutoDiscovery("test")
        KCM.Pipeline.Recompute("test")
        t.truthy(body():find("900201", 1, true), "precondition: Default's macro uses the better food")

        KCM.db:SetProfile("Alt")
        KCM.Selector.Block("FOOD", 900201)
        KCM.Pipeline.Recompute("test")
        t.truthy(body():find("900202", 1, true), "precondition: Alt blocks it, so the macro uses the other")

        KCM.db:SetProfile("Default")
        t.truthy(body():find("900201", 1, true), "switching back rewrites the macro for the incoming profile")

        KCM.db:CopyProfile("Alt")
        t.truthy(body():find("900202", 1, true), "and so does a copy that brings Alt's fingerprint with it")
    end)

-- ---------------------------------------------------------------------------
-- The log (debug-logging-§10)
-- ---------------------------------------------------------------------------

--- The [Set] and [Profile] lines in the console, tag included.
local function actLines(D)
    local out = {}
    for _, line in ipairs(D.buffer) do
        local set = line:match("%[Set%] (.*)$")
        local prof = line:match("%[Profile%] (.*)$")
        if set then out[#out + 1] = "[Set] " .. set end
        if prof then out[#out + 1] = "[Profile] " .. prof end
    end
    return out
end

-- red under: a switch left untraced, a reset or copy re-worded, or a switch
-- inside an open bulk bracket leaving the bracket's own line beside its own.
test("Profiles: each profile act logs its one handler line, a switch included", function(t)
    local KCM = h.loader.loadFullAddon()
    local H, D = KCM.Settings.Helpers, KCM.DebugLog.instance
    KCM.db:SetProfile("Alt")
    KCM.State.debug = true

    D:Clear(); KCM.db:SetProfile("Default")
    t.eqList(actLines(D), { "[Profile] switched to 'Default'" }, "a switch: one [Profile] line")

    D:Clear(); KCM.db:CopyProfile("Alt")
    t.eqList(actLines(D), { "[Set] copied profile 'Alt' → 'Default'" }, "a copy: one [Set] line")

    D:Clear(); KCM.db:ResetProfile()
    t.eqList(actLines(D), { "[Set] reset profile 'Default' to defaults" }, "a reset: one [Set] line")

    D:Clear()
    H.Bulk("reset", "outer", function()
        H.Set("scale", 1.5)
        KCM.db:SetProfile("Alt")
    end)
    KCM.State.debug = false
    t.eqList(actLines(D), { "[Profile] switched to 'Alt'" },
        "a switch inside an open bracket is still the act's one line")
end)

-- ---------------------------------------------------------------------------
-- The settings panel follows at once
-- ---------------------------------------------------------------------------

-- The pipeline's PANEL_REFRESH is debounced by a second or more, and a page drawn
-- from the outgoing profile is a page whose controls write into the wrong one.
--
-- red under: leaving every open page to the debounced refresh.
test("Profiles: the open settings pages rebuild on the switch itself, not after the debounce", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.Options.RequestRefresh = function() end      -- the debounced path, silenced
    local H = KCM.Settings.Helpers
    local n, real = 0, H.RefreshAllPanels
    H.RefreshAllPanels = function(...) n = n + 1; return real(...) end

    KCM.db:SetProfile("Alt")
    H.RefreshAllPanels = nil
    t.eq(n, 1, "one structural refresh, off the profile-changed message")
end)

-- ---------------------------------------------------------------------------
-- The AceDB fake itself (tests/wow_mock.lua)
-- ---------------------------------------------------------------------------

-- AceDB-3.0's SetProfile runs removeDefaults over the OUTGOING profile before it
-- switches (libs/AceDB-3.0/AceDB-3.0.lua:460-463). A fake that skips it cannot
-- show a bug that aliases a default table into the stored profile.
--
-- red under: a fake SetProfile that leaves at-default values in the outgoing profile.
test("AceDB fake: a profile switch strips at-default values from the outgoing profile", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.scale = KCM.dbDefaults.profile.scale
    KCM.db:SetProfile("Other")
    t.eq(KCM.db.profiles.Default.scale, nil, "a scalar equal to its default is removed")
end)

-- The guard CM-03 turns red: a switch must never write into the shipped defaults.
--
-- red under: a copyDefaults that aliases a default sub-table into a profile, which
-- the stripping switch then empties.
test("AceDB fake: the shipped default table survives a switch", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    t.eq(#KCM.dbDefaults.profile.macroBar.barBackdropColor, 4,
        "the default color keeps its four channels")
end)

-- AceDB-3.0.lua:581-587: a copy onto the active profile, or of a missing one
-- unless silent, raises -- a fake that no-ops lets a copy command pass here and
-- raise a raw Lua error in the client.
--
-- red under: a fake CopyProfile that returns silently on a bad name.
test("AceDB fake: CopyProfile onto the active profile raises AceDB's own message", function(t)
    local KCM = h.loader.loadFullAddon()
    h.assertErrorMatches(function() KCM.db:CopyProfile("Default") end,
        'Cannot have the same source and destination profiles ("Default").')
    h.assertErrorMatches(function() KCM.db:CopyProfile("Nope") end,
        'Cannot copy profile "Nope" as it does not exist.')
    KCM.db:CopyProfile("Nope", true)
    t.eq(KCM.db:GetCurrentProfile(), "Default", "a silent copy of a missing profile does not raise")
end)

-- AceDB-3.0.lua:531-537: the same for a delete.
--
-- red under: a fake with no DeleteProfile, or one that no-ops on a bad name.
test("AceDB fake: DeleteProfile of the active profile raises AceDB's own message", function(t)
    local KCM = h.loader.loadFullAddon()
    h.assertErrorMatches(function() KCM.db:DeleteProfile("Default") end,
        'Cannot delete the active profile ("Default") in an AceDBObject.')
    h.assertErrorMatches(function() KCM.db:DeleteProfile("Nope") end,
        'Cannot delete profile "Nope" as it does not exist.')
    KCM.db:DeleteProfile("Nope", true)
    KCM.db:SetProfile("Alt")
    KCM.db:SetProfile("Default")
    KCM.db:DeleteProfile("Alt")
    t.eq(KCM.db.profiles.Alt, nil, "an inactive profile is deleted")
end)

-- ---------------------------------------------------------------------------
-- /cm reset on a color row (ConsumableMaster-R-02)
-- ---------------------------------------------------------------------------

-- A color row's `default` IS the dbDefaults table, and the reset sends it through
-- SetAndRefresh. Storing it as-is aliases the shipped default into the profile.
--
-- red under: return value unchanged from TYPE_RULES.color's normalize
test("/cm reset: resetting a color row stores a copy, not the dbDefaults table", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM:OnSlashCommand("reset macroBar.barBackdropColor")
    local stored = KCM.db.profile.macroBar.barBackdropColor
    t.truthy(stored ~= KCM.dbDefaults.profile.macroBar.barBackdropColor,
        "the stored color is its own table")
    t.eq(#stored, 4, "and it carries all four channels")
end)

-- The aliased table is emptied in place when the switch strips the outgoing
-- profile, which blanks the shipped default for every profile after it.
--
-- red under: return value unchanged from TYPE_RULES.color's normalize
test("/cm reset: a profile switch after a color reset leaves the shipped default intact", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM:OnSlashCommand("reset macroBar.barBackdropColor")
    KCM.db:SetProfile("Other")
    t.eq(#KCM.dbDefaults.profile.macroBar.barBackdropColor, 4,
        "the default color keeps its four channels")
end)
