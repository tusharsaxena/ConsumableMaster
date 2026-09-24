-- tests/test_launcher.lua — core/LauncherSetup.lua, the LibKa0s-Launcher-1.0 seam:
-- the minimap button and the broker plugin as ONE object registered twice.
--
-- WHAT EARNS THIS FILE is that almost everything it can catch is silent in game.
-- A launcher whose icon path names a file that is not there draws NOTHING and
-- raises nothing. A menu entry wired to a second copy of the lock flag looks
-- right until somebody opens the settings panel beside it. A minimap row whose
-- get/set forget to invert shows a checked box over a hidden button, and the
-- first thing the player does about it makes it worse. None of that is an error
-- anybody sees.
--
-- So the cases assert on the WIRING and the STORE, never on pixels: which name
-- went into both registrations, which path the icon field carries and whether
-- that file is on disk in this build, which seam a click reached, and what
-- LibDBIcon was actually told.
--
-- THE TWO BROKER LIBRARIES ARE THE MOCK'S (tests/wow_mock.lua): they are
-- genuinely vendored under libs/ but they are not LibKa0s files, so the
-- harness's LibKa0s.xml-derived load list cannot reach them. Without the fakes
-- every case here would be measuring the library's own no-LibDataBroker branch
-- and reporting green (testing-§9).

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader
local mock = h.mock

-- The addon FOLDER name. It is used for BOTH registrations and LibDBIcon keys
-- the button's SAVED POSITION by it, so it is not cosmetic: a second spelling
-- loses the angle the player dragged the button to.
local FOLDER = "ConsumableMaster"
local ICON   = "Interface\\AddOns\\ConsumableMaster\\media\\logos\\consumablemaster.logo.128.tga"

local function libs()
    return LibStub("LibDataBroker-1.1"), LibStub("LibDBIcon-1.0")
end

-- ---------------------------------------------------------------------------
-- One object, registered twice
-- ---------------------------------------------------------------------------

test("Launcher: KCM:OnInitialize registers ONE object under the folder name", function(t)
    local KCM = loader.loadFullAddon()
    local ldb, icons = libs()

    t.truthy(KCM.Launcher, "the seam published an instance")
    t.truthy(KCM.Launcher:IsRegistered(), "and OnInitialize registered it")

    local object = KCM.Launcher:Object()
    t.truthy(object, "there is a broker object")
    -- The SAME object on both surfaces. A minimap button built from its own
    -- table beside a broker object is the same feature written twice, and it
    -- drifts on the next behavior change (anti-pattern #81).
    t.eq(ldb:GetDataObjectByName(FOLDER), object,
        "the broker registration and the button are one object")
    t.eq(icons.__buttons[FOLDER] and icons.__buttons[FOLDER].object, object,
        "LibDBIcon was handed that very object")
end)

test("Launcher: the object is a launcher, wearing this addon's own logo", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()

    -- `type = "launcher"` is the reason rather than a label: a display reads it
    -- to decide what to draw, and "data source" promises a `text` value that
    -- updates, which this object does not have.
    t.eq(object.type, "launcher", "type is launcher, not data source")
    t.eq(object.icon, ICON, "the icon is this addon's own 128 logo")
    t.eq(object.label, "Ka0s Consumable Master", "a display prints the brand name")
    t.eq(type(object.OnClick), "function", "there is exactly one click implementation")
end)

-- red under: `label` wired to the TOC `## Title`, set to the folder name, or
-- respelled ad hoc. None of the three raises, and none of them is visible from
-- inside this addon at all -- the damage is to the ROW BESIDE the other ten in a
-- broker display, which no case here can see and no player sees until they
-- install a second Ka0s addon.
test("Launcher: the broker label is the brand name in plain text", function(t)
    local KCM = loader.loadFullAddon()
    local label = KCM.Launcher:Object().label

    -- `Ka0s <Name>` verbatim (launcher-§1), so the eleven group together under K
    -- in a display that sorts its plugins.
    t.eq(label, "Ka0s Consumable Master", "the brand name, spelled the collection's way")
    t.eq(label:find("|c", 1, true), nil, "no color escape opens in it")
    t.eq(label:find("|r", 1, true), nil, "and none closes")
    t.truthy(label ~= FOLDER, "it is not the folder name -- that is the registration key")

    -- NOT THE TOC TITLE, AND NOT WIRED TO IT. The two happen to read the same
    -- here because this addon's Title carries no escapes; the collection's
    -- counter-example does, and an addon that derived one from the other would
    -- ship that addon's escapes into every broker row. What is checkable from
    -- outside is that the descriptor spells the label as a LITERAL rather than
    -- reaching for the manifest, since the manifest reach is the only shape that
    -- could grow an escape without anyone editing this field.
    local fh = io.open((_G.KCM_TEST_ROOT or ".") .. "/core/LauncherSetup.lua", "r")
    local src = fh and fh:read("*a") or ""
    if fh then fh:close() end
    t.truthy(src ~= "", "core/LauncherSetup.lua is readable, so this half really ran")
    t.truthy(src:find('label = "Ka0s Consumable Master"', 1, true) ~= nil,
        "the descriptor names the label as a literal, not as a manifest read")
end)

test("Launcher: the icon file the object names is on disk, at the TOC's path", function(t)
    -- The silent one. A wrong or missing path here draws nothing and raises
    -- nothing, so no other gate would report it — and launcher-§4 requires the
    -- object's icon and the TOC's `## IconTexture` be the SAME file.
    local fh = io.open((_G.KCM_TEST_ROOT or ".") .. "/media/logos/consumablemaster.logo.128.tga", "rb")
    t.truthy(fh, "media/logos/consumablemaster.logo.128.tga exists")
    local header = fh and fh:read(18) or ""
    if fh then fh:close() end
    -- Uncompressed 32-bit, which layout-§4 fixes because it is the one format
    -- PROVEN to render as an IconTexture. An RLE-compressed or 24-bit file
    -- would load nowhere and say nothing.
    t.eq(header:byte(3), 2, "TGA image type 2 (uncompressed true-color)")
    t.eq(header:byte(17), 32, "32 bits per pixel")

    local toc = io.open((_G.KCM_TEST_ROOT or ".") .. "/ConsumableMaster.toc", "r")
    local body = toc and toc:read("*a") or ""
    if toc then toc:close() end
    t.truthy(body:find("## IconTexture: " .. ICON, 1, true) ~= nil,
        "the TOC's ## IconTexture names the same file")
end)

test("Launcher: Register is idempotent — a second call builds no second button", function(t)
    local KCM = loader.loadFullAddon()
    local ldb = select(1, libs())

    -- A host may call this from OnInitialize and again from a login handler.
    -- LibDBIcon's own Register on a name it already holds would draw a second
    -- button over the first.
    local object = KCM.Launcher:Object()
    t.truthy(KCM.Launcher:Register(), "the second call answers true")
    t.eq(KCM.Launcher:Object(), object, "and it is still the same object")
    t.eq(ldb:GetDataObjectByName(FOLDER), object, "with one broker registration")
end)

-- ---------------------------------------------------------------------------
-- The two buttons (launcher-§2, LibKa0s-Launcher-1.0 minor 4)
-- ---------------------------------------------------------------------------
--
-- LEFT opens the settings panel, in either state. RIGHT opens the options menu:
-- the client's own context menu, which the library builds out of the pairs the
-- descriptor passes. This addon has two -- *Enabled* and *Locked* (the macro
-- bar), which is the row the standard's ADDONS.md records for it -- and no test
-- mode and no primary window, so no *Test mode* and no *Show window*.
--
-- THE MENU IS THE LIBRARY'S FAKE (tests/mock_menu.lua, copied from LibKa0s
-- v1.58.0). It goes into `_G`, where the loader's environment resolves client
-- globals, and comes back out after every case: mock.install() does not reset
-- `MenuUtil`, and a leftover would change the right click of every later case.

local MENU_FILE = (_G.KCM_TEST_ROOT or ".") .. "/tests/mock_menu.lua"

local function withMenu(body)
    local menu = dofile(MENU_FILE)(_G)
    local ok, err = pcall(body, menu)
    menu.remove()
    if not ok then error(err, 0) end
end

-- Right-click the button, as LibDBIcon dispatches it, and answer the menu that opened.
local function rightClick(object, menu)
    local before = menu.opens
    object.OnClick({}, "RightButton")
    return menu.opens > before and menu.last or nil
end

-- red under: a left click still wired to the retired rung (the lock), or one
-- that asks the addon's state before it opens the panel.
test("Launcher: left-click opens the settings panel, in either state, and nothing else", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()
    -- KCM.Options.Open is the addon's published panel seam and what the
    -- descriptor's openSettings calls. Answering true stands in for a panel the
    -- headless client cannot draw, so a stray line below is the click's own.
    local opens = 0
    KCM.Options.Open = function() opens = opens + 1; return true end

    KCM.Schema:Set("macroBar.locked", false)
    object.OnClick({}, "LeftButton")
    t.eq(opens, 1, "the panel was asked to open")
    t.falsy(KCM.db.profile.macroBar.locked, "and the lock was not touched")

    -- The panel is setup, not a feature, and it is where a disabled addon is
    -- switched back on: no refusal line, the same panel.
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)
    mock.output = {}
    object.OnClick({}, "LeftButton")
    t.eq(opens, 2, "a disabled addon's left click opens the panel too")
    t.eq(table.concat(mock.output, "\n"), "", "and prints no refusal")
end)

-- red under: a descriptor passing a toggle for a state this addon does not
-- have (test mode, a window), or one missing half of a pair it does have.
test("Launcher: right-click opens the options menu -- Enabled, then Locked, and no more", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local owner = {}
        KCM.Launcher:Object().OnClick(owner, "RightButton")
        local m = menu.last
        t.truthy(m, "the client's context menu opened")
        t.eq(m.owner, owner, "anchored to the clicked button")
        t.eqList(m.titles, { "Ka0s Consumable Master" }, "titled with the brand name")
        t.eqList(m:Texts(), { "Enabled", "Locked" },
            "the two toggles this addon has, in the standard's order (ADDONS.md)")
    end)
end)

-- red under: `isLocked` or `isEnabled` read once and cached by the host.
test("Launcher: each open reads the states afresh", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local object = KCM.Launcher:Object()

        KCM.Schema:Set("macroBar.locked", true)
        local m = rightClick(object, menu)
        t.truthy(m:Checked("Enabled"), "Enabled draws checked")
        t.truthy(m:Checked("Locked"), "Locked draws checked on a locked bar")

        -- Changed behind the menu's back, as `/cm unlock` or the checkbox would.
        KCM.Schema:Set("macroBar.locked", false)
        m = rightClick(object, menu)
        t.falsy(m:Checked("Locked"), "the next open reads the unlock")
    end)
end)

-- The Locked entry is `/cm lock` / `/cm unlock` with a mouse, so it runs THE
-- SAME body (KCM.SlashCommands.Verbs.RunLock), which writes through
-- KCM.MacroBar.SetLocked -> KCM.Schema:Set (CM-R-05). A second copy of the write
-- is what the old onClick was careful not to be, and the menu keeps that.
-- red under: `toggleLock` writing `macroBar.locked` itself.
test("Launcher: the Locked entry runs /cm lock's handler through the schema seam", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local object = KCM.Launcher:Object()
        local V = KCM.SlashCommands.Verbs
        local realRun, calls = V.RunLock, {}
        V.RunLock = function(locked, ...) calls[#calls + 1] = locked; return realRun(locked, ...) end
        local writes, realSet = {}, KCM.Schema.Set
        KCM.Schema.Set = function(self, path, value)
            writes[#writes + 1] = path .. "=" .. tostring(value)
            return realSet(self, path, value)
        end

        KCM.db.profile.macroBar.locked = false
        t.eq(rightClick(object, menu):Click("Locked"), menu.RESPONSE.Close, "a click closes the menu")
        t.truthy(KCM.db.profile.macroBar.locked, "an unlocked bar locks")
        rightClick(object, menu):Click("Locked")
        t.falsy(KCM.db.profile.macroBar.locked, "and a locked bar unlocks")

        t.eqList(calls, { true, false }, "both clicks ran the slash verb's body")
        t.eqList(writes, { "macroBar.locked=true", "macroBar.locked=false" },
            "through the single write seam, and wrote nothing else")
        KCM.Schema.Set, V.RunLock = realSet, realRun
    end)
end)

-- The wording is RunLock's too: a player whose bar is switched off is told so
-- rather than asked to "drag it" (ConsumableMaster-R-11).
test("Launcher: Locked on a switched-off bar says what /cm unlock says", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local object = KCM.Launcher:Object()
        local H = KCM.Settings.Helpers
        H.SetAndRefresh("macroBar.enabled", false)
        H.SetAndRefresh("macroBar.locked", true)

        mock.output = {}
        rightClick(object, menu):Click("Locked")
        local viaMenu = table.concat(mock.output, "\n")
        t.eq(KCM.db.profile.macroBar.locked, false, "the write landed")

        H.SetAndRefresh("macroBar.locked", true)
        mock.output = {}
        KCM:OnSlashCommand("unlock")
        t.eq(viaMenu, table.concat(mock.output, "\n"), "the menu and the verb said the same line")
        t.truthy(viaMenu:find("the bar is off", 1, true) ~= nil, "which says the bar is off: " .. viaMenu)
    end)
end)

-- The Enabled entry is `/cm enable` / `/cm disable` with a mouse: the SAME
-- handler (settings/Slash.lua's setEnabled, published as Verbs.SetEnabled),
-- which writes the `enabled` row through the seam and echoes it.
-- red under: `setEnabled` writing the row, or calling the Lifecycle latch, itself.
test("Launcher: the Enabled entry runs /cm disable's and /cm enable's handler", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local object = KCM.Launcher:Object()
        local V = KCM.SlashCommands.Verbs
        t.eq(type(V.SetEnabled), "function", "the verbs' handler is published")
        local realSet, calls = V.SetEnabled, {}
        V.SetEnabled = function(on) calls[#calls + 1] = on; return realSet(on) end

        mock.output = {}
        rightClick(object, menu):Click("Enabled")
        local viaMenu = table.concat(mock.output, "\n")
        t.eqList(calls, { false }, "an enabled addon's click asks for disabled")
        t.eq(KCM.db.profile.enabled, false, "and the addon is off")
        t.truthy(KCM.IsAddonDisabled(), "with the disabled hold taken")

        rightClick(object, menu):Click("Enabled")
        t.eqList(calls, { false, true }, "and the next click turns it back on")
        t.eq(KCM.db.profile.enabled, true)

        V.SetEnabled = realSet
        mock.output = {}
        KCM:OnSlashCommand("disable")
        t.eq(viaMenu, table.concat(mock.output, "\n"), "the menu and /cm disable said the same line")
    end)
end)

-- red under: `isEnabled` reading the whole latch (a perf capture's arm) rather
-- than the disabled hold, or a host gate of its own.
test("Launcher: while disabled, Locked is grayed and Enabled switches the addon back on", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local object = KCM.Launcher:Object()
        KCM.Settings.Helpers.SetAndRefresh("enabled", false)
        KCM.db.profile.macroBar.locked = true

        local m = rightClick(object, menu)
        t.eqList(m:Texts(), { "Enabled", "Locked (enable the addon first)" }, "the note is in the label")
        t.falsy(m:Checked("Enabled"), "Enabled draws unchecked")
        t.truthy(m:Find("Enabled").enabled, "and stays live")
        t.falsy(m:Find("Locked").enabled, "Locked is grayed")
        t.eq(m:Click("Locked"), nil, "a grayed entry cannot be clicked")
        m:ForceClick("Locked")
        t.truthy(KCM.db.profile.macroBar.locked, "and one forced through anyway writes nothing")

        m:Click("Enabled")
        t.eq(KCM.db.profile.enabled, true, "Enabled turned the addon back on")
        t.truthy(rightClick(object, menu):Find("Locked").enabled, "and the next open un-grays Locked")
    end)
end)

-- Where the client has no context-menu API, the right click falls back to the
-- panel, which holds every toggle the menu would have.
test("Launcher: with no MenuUtil, right-click opens the settings panel", function(t)
    local KCM = loader.loadFullAddon()
    t.eq(_G.MenuUtil, nil, "no menu API in this case's environment")
    local opens = 0
    local realOpen = KCM.Options.Open
    KCM.Options.Open = function(...) opens = opens + 1; return realOpen(...) end
    KCM.db.profile.macroBar.locked = false
    KCM.Launcher:Object().OnClick({}, "RightButton")
    t.eq(opens, 1, "the panel was asked to open")
    t.falsy(KCM.db.profile.macroBar.locked, "and no toggle ran")
end)

-- ---------------------------------------------------------------------------
-- The Minimap button row — stored globally, and inverted at the write seam
-- ---------------------------------------------------------------------------

test("Launcher: the Minimap button row stores LibDBIcon's own key, globally", function(t)
    local KCM = loader.loadFullAddon()
    local row = KCM.Settings.Helpers.FindSchema("global.minimap.shown")

    t.truthy(row, "the composer emitted the row")
    t.eq(row.label, "Minimap button", "under the canonical label")
    t.eq(row.default, true, "shipped shown")
    -- STORED, not session: `sessionOnly` is what settings/OptionsSetup.lua's
    -- vetoedFromResetAll keys on, and a session row would be swept back to
    -- `true` by the global reset — which is the exact thing launcher-§3 puts
    -- this table in the global store to prevent.
    t.falsy(row.sessionOnly, "and it is not a session row")
    t.eq(type(KCM.db.global.minimap), "table", "db.global.minimap is materialized")
    t.eq(KCM.db.global.minimap.hide, false, "and ships un-hidden")
    t.eq(KCM.db.profile.minimap, nil, "nothing lives under the profile")
end)

test("Launcher: the row's get/set invert, and the button follows the checkbox", function(t)
    local KCM = loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local icons = select(2, libs())

    t.eq(H.Get("global.minimap.shown"), true, "the row reads SHOWN while hide is false")

    H.SetAndRefresh("global.minimap.shown", false)
    t.eq(KCM.db.global.minimap.hide, true, "unchecking the row HIDES the button")
    t.falsy(icons.__buttons[FOLDER].shown, "and LibDBIcon was told to hide it now")
    t.eq(H.Get("global.minimap.shown"), false, "the row reads back unchecked")

    H.SetAndRefresh("global.minimap.shown", true)
    t.eq(KCM.db.global.minimap.hide, false, "checking it shows the button again")
    t.truthy(icons.__buttons[FOLDER].shown, "and LibDBIcon was told to show it")
    t.truthy(KCM.Launcher:IsShown(), "the launcher agrees with the store")
end)

test("Launcher: LibDBIcon writes into the same table the row reads", function(t)
    local KCM = loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local icons = select(2, libs())

    -- The library hides the button through its own menu and writes `hide`
    -- itself; the checkbox has to notice. A copy of the table on either side is
    -- two records of one state and they disagree the first time either is used.
    t.eq(icons.__buttons[FOLDER].db, KCM.db.global.minimap,
        "LibDBIcon holds the very table the schema row addresses")
    icons.__buttons[FOLDER].db.hide = true
    t.eq(H.Get("global.minimap.shown"), false, "the row reads the library's own write")
end)

-- ---------------------------------------------------------------------------
-- The CLI path reads in the row's own sense (WS-06): `global.minimap.shown`
-- ---------------------------------------------------------------------------
--
-- The path is the row's name and says SHOWN, like its label; the STORE is still
-- LibDBIcon's `hide` key, so no SavedVariables change rides with the rename. The
-- old `...minimap.hide` path is simply no row any more.

local function say(KCM, line)
    mock.output = {}
    KCM:OnSlashCommand(line)
    return table.concat(mock.output, "\n")
end

-- red under: MINIMAP_PATH spelled in the stored key's sense (`...minimap.hide`).
test("Launcher: /cm get global.minimap.shown answers true while hide is false", function(t)
    local KCM = loader.loadFullAddon()
    t.eq(KCM.db.global.minimap.hide, false, "a fresh install ships un-hidden")
    local text = say(KCM, "get global.minimap.shown")
    t.truthy(text:lower():find("global.minimap.shown|r = |cfffffffftrue", 1, true),
        "the shown path reads true: " .. text)
end)

-- red under: MINIMAP_PATH spelled in the stored key's sense (`...minimap.hide`).
test("Launcher: /cm set global.minimap.shown false writes hide = true", function(t)
    local KCM = loader.loadFullAddon()
    local icons = select(2, libs())
    say(KCM, "set global.minimap.shown false")
    t.eq(KCM.db.global.minimap.hide, true, "the store is still LibDBIcon's HIDDEN key")
    t.falsy(icons.__buttons[FOLDER].shown, "and the button went away")
end)

-- red under: a `shown` key written beside `hide`, or the stored key renamed.
test("Launcher: a legacy hide = true store reads as not shown and keeps its angle", function(t)
    local KCM = loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local icons = select(2, libs())
    -- The shape a pre-rename SavedVariables carries, written into the very
    -- table LibDBIcon holds: no migration, no `shown` key, the angle beside it.
    local store = KCM.db.global.minimap
    store.hide, store.minimapPos = true, 200

    t.eq(H.Get("global.minimap.shown"), false, "hide = true reads as not shown")
    t.truthy(say(KCM, "get global.minimap.shown"):lower():find("|cfffffffffalse", 1, true),
        "and /cm get says false")
    t.falsy(KCM.Launcher:IsShown(), "the button stays hidden")

    H.SetAndRefresh("global.minimap.shown", false)
    t.eq(store.hide, true, "setting it hidden again keeps hide = true")
    t.falsy(icons.__buttons[FOLDER].shown, "and the button hidden")
    t.eq(store.minimapPos, 200, "the dragged angle is untouched")
    t.eq(rawget(store, "shown"), nil, "and no `shown` key is ever written")
    H.SetAndRefresh("global.minimap.shown", true)
    t.eq(store.hide, false, "showing it flips the library's own key")
    t.eq(rawget(store, "shown"), nil, "still no `shown` key")
    t.eq(store.minimapPos, 200, "and still the same angle")
end)

-- ---------------------------------------------------------------------------
-- Reset survival (launcher-§3)
-- ---------------------------------------------------------------------------
--
-- A player's minimap-button choice is a PER-INSTALLATION DISPLAY PREFERENCE, in
-- the same class as the position LibDBIcon keeps in the very same table, so it
-- survives every reset the addon ships. That is a property of the setting rather
-- than a consequence of where it is stored, which matters here because this addon
-- runs TWO resets and the storage argument only ever covered one of them. Both
-- are driven for real below and both assert on the STORE -- a case that asserted
-- the row carries a veto flag would pass over a reset loop that never asked.

test("Launcher: the global reset leaves a hidden button hidden", function(t)
    local KCM = loader.loadFullAddon()
    local H = KCM.Settings.Helpers

    -- This reset never reached the row and still would not without the flag:
    -- KCM.ResetAllToDefaults is the session sweep plus db:ResetProfile(), the
    -- sweep writes only session-only rows and this one is stored, and ResetProfile
    -- empties db.profile while the table lives in db.global.
    H.SetAndRefresh("global.minimap.shown", false)
    KCM.ResetAllToDefaults("test")
    t.eq(KCM.db.global.minimap.hide, true, "the button the player hid is still hidden")
    t.eq(KCM.db.profile.enabled, true, "while the profile did come back to defaults")
end)

-- red under: dropping the row's `neverReset` stamp (settings/General.lua's
-- decorate map), or doResetGeneralPage walking `masterRows` on `default ~= nil`
-- alone, as it did through 1.6.2.
test("Launcher: the General page's Defaults button leaves a hidden button hidden", function(t)
    local KCM = loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local icons = select(2, libs())

    -- THE RESET THE STORAGE ARGUMENT NEVER COVERED. The page's Defaults button
    -- walks every Master-controls row carrying a `default`, and the composer emits
    -- the Minimap button row with `default = true` -- so a press un-hid a button
    -- the player had deliberately hidden, profile boundary or no profile boundary.
    KCM.Settings.builders["general"]({})
    local defaults = H.instance.__panelFor("general").panel.defaultsOnClick

    H.SetAndRefresh("global.minimap.shown", false)
    KCM.db.profile.scale = 1.75          -- a neighbor the press MUST reach
    defaults()

    t.eq(KCM.db.global.minimap.hide, true, "the button the player hid is still hidden")
    t.falsy(icons.__buttons[FOLDER].shown, "and LibDBIcon was never told to show it")
    t.eq(H.Get("global.minimap.shown"), false, "the checkbox still reads unchecked")
    -- The press has to have RUN, or nothing above it means anything: a Defaults
    -- button that did no work at all would satisfy every line before this one.
    t.eq(KCM.db.profile.scale, 1, "while the rest of the page did come back to defaults")
end)

-- ---------------------------------------------------------------------------
-- Degradation
-- ---------------------------------------------------------------------------

test("Launcher: a host with neither broker library does not raise", function(t)
    -- Both are resolved with LibStub(..., true) at REGISTER time and the
    -- library degrades BY NAME. Removed through the loader's `mutate` hook,
    -- which is the one window between the mock being installed and the addon
    -- reading anything — so this is a real load of the real files against a
    -- real absence rather than a hand-stubbed namespace (testing-§8).
    local KCM = loader.loadFiles(loader.tocFiles(), false, function()
        local registry = mock.base.__libs
        registry["LibDataBroker-1.1"] = nil
        registry["LibDBIcon-1.0"] = nil
    end)

    t.truthy(KCM.Launcher, "the seam is still published — LibKa0s is there")
    t.falsy(KCM.Launcher:IsRegistered(), "but nothing is registered")
    t.eq(KCM.Launcher:Object(), nil, "and there is no broker object")
    -- IsShown answers from the STORE, so the checkbox still reflects what the
    -- player chose rather than reading true because nothing contradicted it.
    KCM.db.global.minimap.hide = true
    t.falsy(KCM.Launcher:IsShown(), "IsShown still reads the stored key")
    -- The row's set must still land its write: the button is gone, the setting
    -- is not.
    t.truthy(KCM.Settings.Helpers.SetAndRefresh("global.minimap.shown", true))
    t.eq(KCM.db.global.minimap.hide, false, "the store followed the checkbox anyway")
end)

test("Launcher: the write seam owns the inversion, not the library", function(t)
    -- THE LAUNCHER IS TAKEN AWAY, and that is worth spelling out: Lb:SetShown
    -- writes `hide = not shown` a second time with the same value, deliberately,
    -- so a caller reaching the launcher from somewhere else need not know the
    -- inversion. Left in place it would mask a row store that forgot to invert --
    -- the key ends up right either way. The row's set calls it only when it is
    -- there, so without it the inversion is observable alone.
    --
    -- The live arm, not the degraded one: the row is composed (MasterControls),
    -- so a load without LibKa0s has no row, and the seam refuses a path no row
    -- declares -- which is also nothing a degraded build can reach, since the
    -- panel and `/cm set` are both absent there.
    local KCM = loader.loadFullAddon()
    KCM.Launcher = nil

    local H = KCM.Settings.Helpers
    KCM.db.global.minimap.hide = false
    t.truthy(H.Set("global.minimap.shown", false), "the row's set still lands")
    t.eq(KCM.db.global.minimap.hide, true, "unchecking SHOWN writes hide = true")
    t.truthy(H.Set("global.minimap.shown", true))
    t.eq(KCM.db.global.minimap.hide, false, "and checking it writes hide = false")
end)

test("Launcher: no LibKa0s means no launcher at all, and no stub", function(t)
    -- core/PerfSetup.lua's convention: an absent major is an absent feature. No
    -- stub can draw a minimap button, and both callers — KCM:OnInitialize's
    -- Register and the schema row's set — already branch on nil.
    local KCM = loader.loadFullAddon(true)
    t.eq(KCM.Launcher, nil, "KCM.Launcher is absent, not a facade")
end)

-- ---------------------------------------------------------------------------
-- The status tooltip (launcher-§1, LibKa0s-Launcher-1.0 minor 3)
-- ---------------------------------------------------------------------------
--
-- THE LIBRARY DRAWS IT; this addon only answers its questions. So the cases pin
-- the two halves separately: the DESCRIPTOR (captured by wrapping lib:New in the
-- loader's mutate window, after the vendored library and before the addon), and
-- the LINES the object's own OnTooltipShow draws into a recording tooltip. The
-- descriptor half is what catches a field passed for a state this addon does not
-- have -- there is no test mode here, so an `isTestMode` would draw a line about
-- a switch the player cannot find.

-- A tooltip that records what it is told, and the same lines with the status
-- colors taken off, so a case can read the words and check the colors apart.
local function recordingTooltip()
    local tt = { lines = {} }
    function tt:AddLine(s) self.lines[#self.lines + 1] = s end
    return tt
end

local function plain(lines)
    local out = {}
    for i, s in ipairs(lines) do
        out[i] = (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    return out
end

local function hover(KCM)
    local tt = recordingTooltip()
    KCM.Launcher:Object().OnTooltipShow(tt)
    return tt.lines, plain(tt.lines)
end

-- The TOC's `## Version`, read off disk: the one source the title must agree with.
local function tocVersion()
    local fh = io.open((_G.KCM_TEST_ROOT or ".") .. "/ConsumableMaster.toc", "r")
    local body = fh and fh:read("*a") or ""
    if fh then fh:close() end
    return body:match("## Version:%s*([^\r\n]+)")
end

-- red under: a descriptor with no `version`, a `version` that is a captured
-- constant rather than the TOC-first reader, an `isTestMode` / `toggleTestMode`
-- or window pair for a state this addon does not have, an `onTooltipShow`
-- drawing lines of its own, or a field minor 4 retired still being passed.
test("Launcher: the descriptor answers the tooltip's and the menu's questions and no others", function(t)
    local seen
    local KCM = loader.loadFiles(loader.tocFiles(), false, function()
        local lib = LibStub("LibKa0s-Launcher-1.0")
        local realNew = lib.New
        lib.New = function(self, d) seen = d; return realNew(self, d) end
    end)
    t.truthy(seen, "core/LauncherSetup.lua built its launcher through lib:New")
    t.truthy(KCM.Launcher, "and published it")

    t.eq(type(seen.version), "function", "version is asked on every show")
    t.eq(seen.version(), KCM.Version(), "through KCM.Version, the TOC-first reader")
    t.eq(type(seen.isEnabled), "function", "the disabled hold is asked on every show and open")
    t.eq(type(seen.setEnabled), "function", "and /cm enable|disable's handler switches it")
    t.eq(type(seen.isLocked), "function", "the macro bar's lock is this addon's lock")
    t.eq(type(seen.toggleLock), "function", "and /cm lock|unlock's handler toggles it")
    t.eq(seen.isTestMode, nil, "no test mode: the preview switch IS the lock (options-ui-§15)")
    t.eq(seen.toggleTestMode, nil, "so no Test mode entry either")
    t.eq(seen.isWindowShown, nil, "no primary window: the macro bar is the lock's, not a window")
    t.eq(seen.toggleWindow, nil, "so no Show window entry")
    t.eq(seen.onTooltipShow, nil, "no host lines: the library draws the whole block")
    -- Retired at minor 4 and ignored if passed: carrying them is dead
    -- configuration (launcher-§5).
    t.eq(seen.onClick, nil, "no onClick: the left button opens the panel on every addon")
    t.eq(seen.leftClickLabel, nil, "no leftClickLabel: the hint is fixed")
    t.eq(seen.disabledLine, nil, "no disabledLine: there is no refusal to print")
    t.eq(seen.slash, nil, "no slash: there is no disabled hint to name it in")
end)

test("Launcher: the tooltip, enabled and unlocked, in the collection's one shape", function(t)
    local KCM = loader.loadFullAddon()
    KCM.Schema:Set("macroBar.locked", false)
    local _, lines = hover(KCM)

    local v = tocVersion()
    t.truthy(v, "the TOC carries a ## Version")
    t.eqList(lines, {
        "Ka0s Consumable Master  v" .. v,
        "Enabled: Yes",
        "Locked: No",
        "Left-click: Open settings",
        "Right-click: Options menu",
    }, "title, status, the lock, then the two fixed click hints -- and no Test mode line")
end)

-- red under: `isLocked` reading a value captured at load.
test("Launcher: the tooltip reads the lock on every show, never a cached copy", function(t)
    withMenu(function(menu)
        local KCM = loader.loadFullAddon()
        local object = KCM.Launcher:Object()

        KCM.Schema:Set("macroBar.locked", true)
        local raw, lines = hover(KCM)
        t.eq(lines[3], "Locked: Yes", "locked through the schema seam reads Yes")
        t.truthy(raw[3]:find("|cFF00FF00", 1, true) ~= nil, "in green")

        -- The button's own menu, then a second hover of the SAME object.
        rightClick(object, menu):Click("Locked")
        t.falsy(KCM.db.profile.macroBar.locked, "the menu unlocked the bar")
        raw, lines = hover(KCM)
        t.eq(lines[3], "Locked: No", "and the very next hover says so")
        t.truthy(raw[3]:find("|cFFFF0000", 1, true) ~= nil, "in red")
    end)
end)

-- red under: a tooltip suppressed while disabled, or an `isEnabled` reading the
-- whole latch (the perf arm) instead of the disabled hold.
test("Launcher: the tooltip still draws while disabled, with the same two hints", function(t)
    local KCM = loader.loadFullAddon()
    KCM.Settings.Helpers.SetAndRefresh("enabled", false)
    local raw, lines = hover(KCM)

    t.eq(#lines, 5, "the whole block, not an empty tooltip")
    t.eq(lines[2], "Enabled: No", "Enabled reads No")
    t.truthy(raw[2]:find("|cFFFF0000", 1, true) ~= nil, "in red")
    t.eq(lines[3], "Locked: No", "the lock line is still there")
    t.eq(lines[4], "Left-click: Open settings", "the left button still opens the panel")
    t.eq(lines[5], "Right-click: Options menu", "and the right one the menu")

    KCM.Settings.Helpers.SetAndRefresh("enabled", true)
    lines = select(2, hover(KCM))
    t.eq(lines[2], "Enabled: Yes", "re-enabling is read on the next show")
end)
