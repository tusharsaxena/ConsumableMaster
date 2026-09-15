-- tests/test_testmode.lua -- the macro bar's test mode (options-ui-§15, preview-mode).
--
-- A session-only `Test mode` checkbox on General > Master controls, composed by
-- LibKa0s' MasterControls from `testModePath` and bound to `state.testMode`. While
-- it is on, the bar is shown whatever General visibility and the bar's own Combat
-- visibility say, its drag handle and gold wash are up so its extent can be seen,
-- and a bar with every slot hidden lays out all of them. Dragging stays the lock's
-- business. It is refused in combat and with the bar off, it ends when combat
-- starts or the bar is turned off, and the global reset ends it.
--
-- Its own suite because tests/test_macrobar.lua is over the 1500-line cap.

local h = _G.KCM_TEST
local test = h.test

local PATH = "state.testMode"

--- Build the bar while watching CreateFrame, and record what the apply passes do to
--- it. The container and its slots are file-locals in modules/MacroBar.lua, so this
--- is the only way to reach the frames the player sees.
---
--- The SLOTS are caught at MacroBarButton.Create, not at CreateFrame:
--- modules/MacroBarButton.lua binds `local CreateFrame = CreateFrame` at load, so a
--- swap of the global never sees a button being made. The headless stub's IsShown
--- answers truthy forever, so every slot gets a Show/Hide/IsShown of its own.
local function buildBar(KCM)
    local mock = h.loader.mock
    local seen, frames, slots = {}, {}, {}
    local realCreate = _G.CreateFrame
    _G.CreateFrame = function(kind, name, parent, template)
        local f = realCreate(kind, name, parent, template)
        if name then frames[name] = f end
        if name == "KCMMacroBar" then
            -- The stub's CreateTexture hands the frame back, so the gold wash would
            -- BE the bar. A distinct object for this one frame.
            f.CreateTexture = function()
                local tex = mock.makeStub()
                tex.Show = function() seen.hintShown = true end
                tex.Hide = function() seen.hintShown = false end
                return tex
            end
        end
        return f
    end
    local realMake = KCM.MacroBarButton.Create
    KCM.MacroBarButton.Create = function(...)
        local f = realMake(...)
        if f then
            slots[#slots + 1] = f
            f.Show    = function(self) self.__up = true; return self end
            f.Hide    = function(self) self.__up = false; return self end
            f.IsShown = function(self) return self.__up == true end
        end
        return f
    end
    KCM.MacroBar.Update()
    _G.CreateFrame = realCreate
    KCM.MacroBarButton.Create = realMake

    local bar, handle = frames.KCMMacroBar, frames.KCMMacroBarHandle
    bar.EnableMouse = function(_, on) seen.mouseEnabled = on and true or false end
    bar.Show        = function() seen.barVisible = true end
    bar.Hide        = function() seen.barVisible = false end
    handle.SetShown = function(_, on) seen.handleShown = on and true or false end
    KCM.MacroBar.Update()      -- again, so `seen` starts from a whole apply pass
    return seen, bar, handle, slots
end

local function up(slots)
    local n = 0
    for _, s in ipairs(slots) do if s.__up then n = n + 1 end end
    return n
end

--- Every checkbox the General page draws, keyed by its label, recording the value
--- each one is told to display. Answers the boxes and a function that undoes the swap.
local function captureBoxes(KCM)
    local mock = h.loader.mock
    local H, UI = KCM.Settings.Helpers, KCM.Settings.Helpers.instance
    local boxes = {}
    local realAceGUI = UI.AceGUI
    UI.AceGUI = setmetatable({
        Create = function(_, kind)
            local w = mock.makeAceWidget()
            if kind == "CheckBox" then
                w.SetLabel = function(self, label) boxes[label] = self; return self end
                w.SetValue = function(self, v) self.__value = v; return self end
            end
            return w
        end,
        RegisterWidgetType = function() end,
        RegisterLayout     = function() end,
        GetWidgetVersion   = function() return 0 end,
    }, { __index = function() return function() end end })
    KCM.Settings.builders.general({})
    local ctx = UI.__panelFor("general")
    ctx.panel.IsShown = function() return true end
    H.RefreshAllPanels()
    return boxes, function() UI.AceGUI = realAceGUI end
end

local function masterRows(KCM)
    local rows = {}
    for _, r in ipairs(KCM.Settings.Schema) do
        if r.panel == "general" and r.group == "Master controls" then rows[#rows + 1] = r end
    end
    return rows
end

local function say(KCM, mock, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return table.concat(mock.output, "\n")
end

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------

-- red under: dropping `testModePath` from settings/General.lua's MasterControls
-- spec, dropping `testMode = false` from its defaults, or keeping the composer's
-- generic tooltip.
test("Test mode: the row is composed directly below Debug console, session-only, default off", function(t)
    local KCM = h.loader.loadFullAddon()
    local rows = masterRows(KCM)
    local at
    for i, r in ipairs(rows) do if r.path == PATH then at = i end end
    t.truthy(at, "Master controls carries a state.testMode row")
    if not at then return end
    t.eq(rows[at - 1] and rows[at - 1].path, "state.debugConsole", "the row right above it is Debug console")
    t.eq(at, #rows, "and it is the block's last row, ahead of the reset pair")
    local row = rows[at]
    t.eq(row.type, "bool", "a checkbox")
    t.eq(row.label, "Test mode", "under the collection's one label")
    t.eq(row.sessionOnly, true, "session-only")
    t.eq(row.startsLine, true, "on a line of its own")
    t.eq(row.default, false, "with a default, so every reset reaches it")
    local tip = tostring(row.tooltip or row.desc or "")
    t.truthy(tip:find("macro bar", 1, true),
        "the tooltip is this addon's, not the composer's generic one: " .. tip)
end)

-- red under: a SESSION_PATHS entry that stores into db.profile, or none at all.
test("Test mode: lives in the session, never in the profile", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    t.eq(H.Get(PATH), false, "off in a fresh session")
    t.eq((H.Resolve(PATH)), nil, "the profile has no home for it")
    t.truthy(H.SetAndRefresh(PATH, true), "ticking it is accepted")
    t.eq(H.Get(PATH), true, "and reads back on")
    t.eq(KCM.db.profile.state, nil, "nothing was written into the profile")
    t.eq(KCM.db.profile.testMode, nil, "under either name")
end)

-- ---------------------------------------------------------------------------
-- What it does to the bar
-- ---------------------------------------------------------------------------

-- red under: applyVisibility ignoring test mode, or leaving the secure driver
-- registered while it is on.
test("Test mode: ticking shows the bar through a visibility that hides it; unticking restores it",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local mock = h.loader.mock
        local H = KCM.Settings.Helpers
        local seen, bar = buildBar(KCM)

        KCM.db.profile.visibility = "never"
        KCM.MacroBar.Update()
        t.eq(seen.barVisible, false, "General visibility `never` hides the bar")
        H.SetAndRefresh(PATH, true)
        t.eq(seen.barVisible, true, "test mode shows it anyway")
        H.SetAndRefresh(PATH, false)
        t.eq(seen.barVisible, false, "and unticking hides it again")

        -- The bar's OWN combat visibility: a combat-conditional answer is the secure
        -- driver's, and test mode takes the driver off while it is on.
        KCM.db.profile.visibility = "always"
        KCM.db.profile.macroBar.combatMode = "ONLY_IN_COMBAT"
        KCM.MacroBar.Update()
        t.eq(mock.stateDrivers[bar].visibility, "[combat] show; hide",
            "only-in-combat hands the toggle to the driver")
        H.SetAndRefresh(PATH, true)
        t.eq(mock.stateDrivers[bar].visibility, nil, "test mode unregisters it")
        t.eq(seen.barVisible, true, "and shows the bar out of combat")
        H.SetAndRefresh(PATH, false)
        t.eq(mock.stateDrivers[bar].visibility, "[combat] show; hide", "unticking hands it back")
    end)

-- red under: applyLock ignoring test mode, or the handle's drag ignoring the lock.
test("Test mode: a locked bar shows its handle and wash, and still does not move", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local seen, bar, handle = buildBar(KCM)

    KCM.MacroBar.SetLocked(true)
    t.eq(seen.handleShown, false, "locked: no handle")
    H.SetAndRefresh(PATH, true)
    t.eq(seen.handleShown, true, "test mode puts the handle up")
    t.eq(seen.hintShown, true, "and the gold wash over the bar's extent")
    t.eq(seen.mouseEnabled, false, "the locked bar still lets clicks through")

    local moved = false
    bar.StartMoving = function() moved = true end
    handle:GetScript("OnDragStart")(handle)
    t.eq(moved, false, "dragging the handle does not move a locked bar")
    KCM.MacroBar.SetLocked(false)
    handle:GetScript("OnDragStart")(handle)
    t.eq(moved, true, "unlocked, the same drag moves it")

    KCM.MacroBar.SetLocked(true)
    H.SetAndRefresh(PATH, false)
    t.eq(seen.handleShown, false, "test mode off: the locked bar's handle goes")
    t.eq(seen.hintShown, false, "and so does the wash")
end)

-- red under: applyLayout laying out only the shown slots in test mode, or laying
-- out hidden slots beside shown ones.
test("Test mode: a bar with every slot hidden lays out every slot, and gives them back", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local _, _, _, slots = buildBar(KCM)
    local order = KCM.MacroBarModel.Order()

    local shown = {}
    for _, key in ipairs(order) do shown[key] = false end
    KCM.db.profile.macroBar.shown = shown
    KCM.MacroBar.Update()
    t.eq(up(slots), 0, "every slot hidden: an empty bar")
    H.SetAndRefresh(PATH, true)
    t.eq(up(slots), #order, "test mode lays out every slot")
    H.SetAndRefresh(PATH, false)
    t.eq(up(slots), 0, "and off, the bar is empty again")

    shown[order[1]] = true
    KCM.MacroBar.Update()
    H.SetAndRefresh(PATH, true)
    t.eq(up(slots), 1, "with one slot shown, test mode adds none of the hidden ones")
end)

-- ---------------------------------------------------------------------------
-- Refusals and endings
-- ---------------------------------------------------------------------------

-- red under: starting in combat, saying nothing or more than one line, or leaving
-- the panel un-synced after the refusal.
test("Test mode: refused in combat, in one gray line, and the panel re-syncs", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local H = KCM.Settings.Helpers
    buildBar(KCM)

    local scalars, realScalars = 0, H.RefreshScalars
    H.RefreshScalars = function(...) scalars = scalars + 1; return realScalars(...) end
    mock.setCombat(true)
    mock.output = {}
    local ok = H.SetAndRefresh(PATH, true)
    mock.setCombat(false)
    H.RefreshScalars = realScalars

    t.falsy(ok, "the tick is refused")
    t.eq(H.Get(PATH), false, "test mode stayed off")
    t.eq(#mock.output, 1, "one line says why")
    t.truthy((mock.output[1] or ""):find("|cff808080", 1, true), "in gray")
    t.truthy((mock.output[1] or ""):find("combat", 1, true), "naming combat")
    t.truthy(scalars >= 1, "and the panel re-synced, so the box the click ticked reads unticked")
end)

-- red under: starting on a bar that is turned off.
test("Test mode: refused with the bar off, in one line that says how to turn it on", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local H = KCM.Settings.Helpers
    buildBar(KCM)
    KCM.MacroBar.SetEnabled(false)

    mock.output = {}
    t.falsy(H.SetAndRefresh(PATH, true), "the tick is refused")
    t.eq(H.Get(PATH), false, "test mode stayed off")
    t.eq(#mock.output, 1, "one line says why")
    t.truthy((mock.output[1] or ""):find("/cm bar on", 1, true),
        "and it says how to turn the bar on: " .. tostring(mock.output[1]))
end)

-- red under: no PLAYER_REGEN_DISABLED listener, a listener left registered after
-- test mode ends, or an ending that leaves the bar force-shown.
test("Test mode: combat starting ends it, says so once, and restores the real visibility", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local base = mock.base
    local H = KCM.Settings.Helpers
    local seen = buildBar(KCM)

    t.eq(base.__fireEvent("PLAYER_REGEN_DISABLED"), 0, "off, nothing listens for combat")
    KCM.db.profile.visibility = "never"
    KCM.MacroBar.Update()
    H.SetAndRefresh(PATH, true)
    t.eq(seen.barVisible, true, "test mode is showing the bar")

    mock.output = {}
    t.eq(base.__fireEvent("PLAYER_REGEN_DISABLED"), 1, "on, it listens for combat starting")
    t.eq(H.Get(PATH), false, "and combat ended it")
    t.eq(seen.barVisible, false, "the bar is back under its real visibility")
    t.eq(#mock.output, 1, "one line")
    t.truthy((mock.output[1] or ""):find("Test mode off — combat started", 1, true),
        "saying why: " .. tostring(mock.output[1]))
    t.eq(base.__fireEvent("PLAYER_REGEN_DISABLED"), 0, "and it stopped listening")
end)

-- red under: MB.Update's disable path leaving test mode on.
test("Test mode: turning the bar off ends it", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local H = KCM.Settings.Helpers
    buildBar(KCM)
    H.SetAndRefresh(PATH, true)

    mock.output = {}
    KCM.MacroBar.SetEnabled(false)
    t.eq(H.Get(PATH), false, "test mode ended with the bar")
    t.truthy(table.concat(mock.output, "\n"):find("Test mode off", 1, true), "and said so")
    KCM.MacroBar.SetEnabled(true)
    t.eq(H.Get(PATH), false, "turning the bar back on does not restart it")
end)

-- red under: dropping `testMode = false` from the composer spec's defaults, or a
-- session sweep that skips the row.
test("Test mode: Reset all settings ends it", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    buildBar(KCM)
    H.SetAndRefresh(PATH, true)
    KCM.ResetAllToDefaults("test")
    t.eq(H.Get(PATH), false, "the global reset's session sweep reached it")
end)

-- ---------------------------------------------------------------------------
-- The two doors: the checkbox and `/cm bar test`
-- ---------------------------------------------------------------------------

-- red under: a start or stop that does not re-sync the open page, including the
-- refusal and the combat ending, or a slash door that bypasses the row.
test("Test mode: the Master controls box follows every start and stop", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local H = KCM.Settings.Helpers
    buildBar(KCM)
    local boxes, restore = captureBoxes(KCM)
    local box = boxes["Test mode"]
    t.truthy(box, "Master controls drew a Test mode checkbox")
    if not box then return restore() end

    t.eq(box.__value, false, "unticked in a fresh session")
    H.SetAndRefresh(PATH, true)
    t.eq(box.__value, true, "ticked while on")
    mock.base.__fireEvent("PLAYER_REGEN_DISABLED")
    t.eq(box.__value, false, "combat starting unticks it")

    KCM.MacroBar.SetEnabled(false)
    box.__value = true                 -- what the click itself drew
    H.SetAndRefresh(PATH, true)
    t.eq(box.__value, false, "a refused start leaves it unticked")
    KCM.MacroBar.SetEnabled(true)

    say(KCM, mock, "bar test")
    t.eq(box.__value, true, "/cm bar test ticks it")
    say(KCM, mock, "bar test off")
    t.eq(box.__value, false, "/cm bar test off unticks it")
    restore()
end)

-- red under: a `test` sub-verb missing from /cm bar, or one that ignores on / off.
test("Test mode: /cm bar test toggles it, and takes on and off", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local H = KCM.Settings.Helpers
    buildBar(KCM)

    say(KCM, mock, "bar test")
    t.eq(H.Get(PATH), true, "bare, it toggles on")
    say(KCM, mock, "bar test")
    t.eq(H.Get(PATH), false, "and off")
    say(KCM, mock, "bar test on")
    say(KCM, mock, "bar test on")
    t.eq(H.Get(PATH), true, "`on` turns it on and leaves it on")
    say(KCM, mock, "bar test off")
    t.eq(H.Get(PATH), false, "`off` turns it off")
    local out = say(KCM, mock, "bar test sideways")
    t.truthy(out:find("/cm bar test [on|off]", 1, true), "anything else prints the usage: " .. out)
    t.eq(H.Get(PATH), false, "and changes nothing")
end)
