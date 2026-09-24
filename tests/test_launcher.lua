-- tests/test_launcher.lua — core/LauncherSetup.lua, the LibKa0s-Launcher-1.0 seam:
-- the minimap button and the broker plugin as ONE object registered twice.
--
-- WHAT EARNS THIS FILE is that almost everything it can catch is silent in game.
-- A launcher whose icon path names a file that is not there draws NOTHING and
-- raises nothing. A left click wired to a second copy of the lock flag looks
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
-- The rung — (b) lock / unlock, driven through the EXISTING seam
-- ---------------------------------------------------------------------------

test("Launcher: left-click toggles the macro bar's lock through the schema seam", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()

    -- The proof that this is rung (b) and not a second copy of the flag: the
    -- click has to reach KCM.Schema:Set, which is the write path the Master
    -- controls checkbox and `/cm bar lock` already take (CM-R-05). Wrapped
    -- rather than replaced, so the real write still lands and the row's
    -- onChange still runs.
    local writes = {}
    local realSet = KCM.Schema.Set
    KCM.Schema.Set = function(self, path, value)
        writes[#writes + 1] = path .. "=" .. tostring(value)
        return realSet(self, path, value)
    end

    KCM.db.profile.macroBar.locked = false
    object.OnClick(nil, "LeftButton")
    t.truthy(KCM.db.profile.macroBar.locked, "an unlocked bar locks")
    object.OnClick(nil, "LeftButton")
    t.falsy(KCM.db.profile.macroBar.locked, "and a locked bar unlocks")

    t.eqList(writes, { "macroBar.locked=true", "macroBar.locked=false" },
        "both clicks went through the single write seam, and wrote nothing else")

    KCM.Schema.Set = realSet
end)

test("Launcher: the left click holds no state — it reads the profile each time", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()

    -- Changed behind the launcher's back, exactly as the checkbox or
    -- `/cm bar lock` would change it. A launcher caching the flag would answer
    -- from its own copy and the next click would go the wrong way.
    KCM.db.profile.macroBar.locked = false
    object.OnClick(nil, "LeftButton")
    t.truthy(KCM.db.profile.macroBar.locked)
    KCM.Schema:Set("macroBar.locked", false)
    object.OnClick(nil, "LeftButton")
    t.truthy(KCM.db.profile.macroBar.locked, "the click read the CURRENT value, not a cached one")
end)

-- The left click is `/cm lock` / `/cm unlock` with a mouse, so it runs THE SAME
-- body (KCM.SlashCommands.Verbs.RunLock) rather than a second copy of the write
-- and the wording. The copy it used to carry told a player whose bar was
-- switched off to "drag it" (ConsumableMaster-R-11).
test("Launcher: left-click unlock on a switched-off bar reuses RunLock's wording", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()
    local V = KCM.SlashCommands.Verbs
    local realRun, calls = V.RunLock, {}
    V.RunLock = function(locked) calls[#calls + 1] = locked; return realRun(locked) end

    KCM.Settings.Helpers.SetAndRefresh("macroBar.enabled", false)
    KCM.Settings.Helpers.SetAndRefresh("macroBar.locked", true)
    mock.output = {}
    object.OnClick(nil, "LeftButton")
    local out = table.concat(mock.output, "\n")

    t.eqList(calls, { false }, "the click ran the slash verb's body, asking for unlocked")
    t.eq(KCM.db.profile.macroBar.locked, false, "and the write landed")
    t.truthy(out:find("macro bar unlocked (the bar is off \226\128\148 /cm bar on to show it)",
        1, true) ~= nil, "the line says the bar is off: " .. out)
    t.truthy(out:find("drag it", 1, true) == nil, "and asks for no drag: " .. out)
    V.RunLock = realRun
end)

-- The disabled refusal is the LIBRARY'S gate now (LibKa0s-Launcher-1.0 minor 2,
-- descriptor isEnabled / disabledLine): a disabled addon's left click never
-- reaches the host's onClick, so it cannot reach RunLock either.
test("Launcher: a disabled left click never reaches RunLock", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()
    local V = KCM.SlashCommands.Verbs
    local realRun, calls = V.RunLock, 0
    V.RunLock = function(...) calls = calls + 1; return realRun(...) end

    KCM.Settings.Helpers.SetAndRefresh("enabled", false)
    mock.output = {}
    object.OnClick(nil, "LeftButton")
    local out = table.concat(mock.output, "\n")

    t.eq(calls, 0, "the gate stopped the click before the host's action")
    local line = KCM.SlashCommands.instance:DisabledLine()
    local _, n = out:gsub(line:gsub("%p", "%%%0"), "")
    t.eq(n, 1, "and the dispatcher's disabled line printed exactly once: " .. out)
    V.RunLock = realRun
end)

test("Launcher: right-click opens the settings panel, and never the rung", function(t)
    local KCM = loader.loadFullAddon()
    local object = KCM.Launcher:Object()

    -- KCM.Options.Open is the addon's published panel seam and what the
    -- descriptor's openSettings calls; wrapping it is how the case sees the
    -- call land without the headless client having a settings panel to open.
    local opens = 0
    local realOpen = KCM.Options.Open
    KCM.Options.Open = function(...) opens = opens + 1; return realOpen(...) end

    KCM.db.profile.macroBar.locked = false
    object.OnClick(nil, "RightButton")
    t.eq(opens, 1, "the panel was asked to open")
    t.falsy(KCM.db.profile.macroBar.locked, "and the lock was not touched")

    -- Left-click is the rung here, so it must NOT also open the panel: an addon
    -- on rung (a) or (b) whose left click opens settings has skipped the rule,
    -- since the panel is already on the right button (anti-pattern #81).
    object.OnClick(nil, "LeftButton")
    t.eq(opens, 1, "the left click spent itself on the lock instead")

    KCM.Options.Open = realOpen
end)

-- ---------------------------------------------------------------------------
-- The Minimap button row — stored globally, and inverted at the write seam
-- ---------------------------------------------------------------------------

test("Launcher: the Minimap button row stores LibDBIcon's own key, globally", function(t)
    local KCM = loader.loadFullAddon()
    local row = KCM.Settings.Helpers.FindSchema("global.minimap.hide")

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

    t.eq(H.Get("global.minimap.hide"), true, "the row reads SHOWN while hide is false")

    H.SetAndRefresh("global.minimap.hide", false)
    t.eq(KCM.db.global.minimap.hide, true, "unchecking the row HIDES the button")
    t.falsy(icons.__buttons[FOLDER].shown, "and LibDBIcon was told to hide it now")
    t.eq(H.Get("global.minimap.hide"), false, "the row reads back unchecked")

    H.SetAndRefresh("global.minimap.hide", true)
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
    t.eq(H.Get("global.minimap.hide"), false, "the row reads the library's own write")
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
    H.SetAndRefresh("global.minimap.hide", false)
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

    H.SetAndRefresh("global.minimap.hide", false)
    KCM.db.profile.scale = 1.75          -- a neighbor the press MUST reach
    defaults()

    t.eq(KCM.db.global.minimap.hide, true, "the button the player hid is still hidden")
    t.falsy(icons.__buttons[FOLDER].shown, "and LibDBIcon was never told to show it")
    t.eq(H.Get("global.minimap.hide"), false, "the checkbox still reads unchecked")
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
    t.truthy(KCM.Settings.Helpers.SetAndRefresh("global.minimap.hide", true))
    t.eq(KCM.db.global.minimap.hide, false, "the store followed the checkbox anyway")
end)

test("Launcher: the write seam owns the inversion, not the library", function(t)
    -- THE ONLY ARM ON WHICH THE HOST'S INVERSION IS OBSERVABLE ALONE, and that
    -- is worth spelling out: Lb:SetShown writes `hide = not shown` a second time
    -- with the same value, deliberately, so a caller reaching the launcher from
    -- somewhere else need not know the inversion. On the live arm that masks a
    -- seam that forgot to invert -- the store ends up right either way. With no
    -- LibKa0s there is no launcher to cover for it.
    local KCM = loader.loadFullAddon(true)
    t.eq(KCM.Launcher, nil, "no launcher to cover for the seam")

    -- Helpers.Set rather than SetAndRefresh: the composed row does not exist on
    -- this arm (the degradation stub emits no rows), so there is no schema entry
    -- to validate against. The diversion under test is the same one either way.
    local H = KCM.Settings.Helpers
    KCM.db.global.minimap.hide = false
    t.truthy(H.Set("global.minimap.hide", false), "the row's set still lands")
    t.eq(KCM.db.global.minimap.hide, true, "unchecking SHOWN writes hide = true")
    t.truthy(H.Set("global.minimap.hide", true))
    t.eq(KCM.db.global.minimap.hide, false, "and checking it writes hide = false")
end)

test("Launcher: no LibKa0s means no launcher at all, and no stub", function(t)
    -- core/PerfSetup.lua's convention: an absent major is an absent feature. No
    -- stub can draw a minimap button, and both callers — KCM:OnInitialize's
    -- Register and the schema row's set — already branch on nil.
    local KCM = loader.loadFullAddon(true)
    t.eq(KCM.Launcher, nil, "KCM.Launcher is absent, not a facade")
end)
