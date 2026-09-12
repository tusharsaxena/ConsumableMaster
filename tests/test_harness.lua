-- test_harness.lua — what tests/wow_mock.lua layers over the kit, pinned (#38).
--
-- tests/wow_mock.lua used to replace the kit's AceAddon, AceEvent, AceConsole
-- and AceGUI fakes wholesale, so no kit revision to those fakes ever reached
-- this suite. It now builds on the kit's objects and keeps only what is this
-- addon's own. The first block below was written BEFORE that migration and
-- passed on the old harness: it pins the addon-specific behavior the migration
-- had to keep. The second block pins that kit revisions now arrive, and is red
-- on the old harness by construction.

local h = _G.KCM_TEST
local test = h.test

-- ---------------------------------------------------------------------------
-- Kept local: the addon-specific extensions
-- ---------------------------------------------------------------------------

test("Harness: the addon object is published as _G.KCM and is the namespace", function(t)
    local KCM = h.loader.loadPure()
    t.eq(_G.KCM, KCM, "the AceAddon object is the shared NS table, published globally")
    t.eq(KCM.addon, KCM, "and core/ConsumableMaster.lua's NS.addon points back at it")
end)

test("Harness: AceGUI:Create hands back the permissive widget, logged in creation order", function(t)
    h.loader.loadPure()
    local AceGUI = LibStub("AceGUI-3.0")
    local before = #AceGUI.__created
    local w = AceGUI:Create("Button")
    t.eq(AceGUI.__created[before + 1], w, "the widget is appended to the creation log")
    t.eq(type(w.label and w.label.SetFontObject), "function",
        "label is a FontString object, so a guarded font bump calls through")
    t.eq(type(w.text and w.text.SetFontObject), "function", "and so is text")
    w:SetText("Go")
    w:SetLabel("Name")
    t.eq(rawget(w, "__text"), "Go", "SetText is recorded beside the FontString")
    t.eq(rawget(w, "__label"), "Name", "SetLabel is recorded too")
    t.eq(w:SetWidth(10), w, "any other widget method is a chaining no-op")
end)

test("Harness: GetWidgetVersion answers 0 for an unregistered type", function(t)
    h.loader.loadPure()
    local AceGUI = LibStub("AceGUI-3.0")
    t.eq(AceGUI:GetWidgetVersion("KCMHarnessProbe"), 0,
        "a number, so a widget file's version guard compares and registers")
    local ctor = function() end
    AceGUI:RegisterWidgetType("KCMHarnessProbe", ctor, 7)
    t.eq(AceGUI:GetWidgetVersion("KCMHarnessProbe"), 7, "then the registered version")
    t.eq(AceGUI.WidgetRegistry["KCMHarnessProbe"], ctor, "in the real registry table")
end)

test("Harness: LibStub answers nil for an unknown major, silent flag or not", function(t)
    h.loader.loadPure()
    t.eq(LibStub("KCMHarnessNoSuchLib-1.0"), nil, "no raise without the silent flag")
    t.eq(LibStub("KCMHarnessNoSuchLib-1.0", true), nil, "and nil with it")
    t.truthy(LibStub("LibKa0s-Core-1.0", true), "a vendored major still registers for real")
end)

test("Harness: LibSharedMedia serves the fonts and borders the settings pages read", function(t)
    h.loader.loadPure()
    local LSM = LibStub("LibSharedMedia-3.0")
    local fonts = LSM:List("font")
    t.contains(fonts, "Friz Quadrata TT", "the default font is listed")
    t.eq(LSM:HashTable("border")["None"], "None", "HashTable is the self-keyed map")
    t.eq(LSM:Fetch("border", "None"), "border:None", "Fetch resolves a registered key")
    t.eq(LSM:Fetch("border", "Nope"), nil, "and nil for an unregistered one")
end)

test("Harness: a string-method bus registration calls the target's method", function(t)
    local KCM = h.loader.loadPure()
    local target = KCM.NewBusTarget()
    local got
    function target:OnHarnessPing(message, arg) got = { self, message, arg } end
    target:RegisterMessage("Ka0s_ConsumableMaster_HarnessPing", "OnHarnessPing")
    KCM.bus:SendMessage("Ka0s_ConsumableMaster_HarnessPing", 5)
    t.truthy(got, "the method ran")
    t.eq(got[1], target, "as a method on its own target")
    t.eq(got[2], "Ka0s_ConsumableMaster_HarnessPing", "with the message first")
    t.eq(got[3], 5, "then the payload")
end)

test("Harness: OnEnable registers every game event without raising", function(t)
    local KCM = h.loader.loadPure()
    local ok, err = pcall(function() KCM:OnEnable() end)
    t.truthy(ok, "OnEnable ran: " .. tostring(err))
end)

-- ---------------------------------------------------------------------------
-- Kit revisions now reach this suite (red on the old harness by construction)
-- ---------------------------------------------------------------------------

-- Kit revision 16's Printf (LibKa0s #30), through revision 17's AceConsole embed.
-- The old harness stamped no Printf, because it never embedded AceConsole.
test("Harness: AceConsole's Printf reaches the addon object, as in the client", function(t)
    local KCM = h.loader.loadPure()
    t.eq(type(KCM.Printf), "function", "NewAddon embedded AceConsole's Printf")
    local lines = {}
    local realFrame = _G.DEFAULT_CHAT_FRAME
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) lines[#lines + 1] = msg end }
    KCM:Printf("%d left", 3)
    _G.DEFAULT_CHAT_FRAME = realFrame
    t.eq(lines[1], "|cff33ff99ConsumableMaster|r: 3 left",
        "green addon-name prefix, the format applied to what follows it")
    t.eq(LibStub("AceAddon-3.0"):GetAddon("ConsumableMaster"), KCM, "GetAddon answers by name")
end)

-- Kit revision 16's recorded event half (LibKa0s #29) and revision 17's
-- __fireEvent. The old harness stamped a no-op RegisterEvent and no
-- UnregisterAllEvents, so core/PerfSetup.lua's suspend skipped its guarded
-- UnregisterAllEvents and that path had no coverage.
test("Harness: perf suspend drops every game event, through the recorded event half", function(t)
    local KCM = h.loader.loadFullAddon()
    local base = h.loader.mock.base
    KCM:OnEnable()
    t.eq(KCM.__events["BAG_UPDATE_DELAYED"], "OnBagUpdateDelayed",
        "the registration is recorded with its handler name")
    local seen = 0
    local realHandler = KCM.OnBagUpdateDelayed
    KCM.OnBagUpdateDelayed = function() seen = seen + 1 end
    t.eq(base.__fireEvent("BAG_UPDATE_DELAYED"), 1, "a fired event reaches its one handler")
    t.eq(seen, 1, "which is the addon's method")

    t.truthy(KCM.Perf and KCM.Perf.Suspend, "the perf harness is loaded")
    KCM.Perf.Suspend()
    t.eq(next(KCM.__events), nil, "suspend's UnregisterAllEvents emptied the registrations")
    t.eq(base.__fireEvent("BAG_UPDATE_DELAYED"), 0, "and the event reaches nobody")
    KCM.OnBagUpdateDelayed = realHandler
end)

-- Kit revision 16's AceGUI:Release (LibKa0s #27). The old harness's catch-all
-- index answered Release with a no-op, so a double release passed silently.
test("Harness: AceGUI:Release takes a widget back, and raises on a second release", function(t)
    h.loader.loadPure()
    local AceGUI = LibStub("AceGUI-3.0")
    local w = AceGUI:Create("Button")
    AceGUI:Release(w)
    t.truthy(rawget(w, "__released"), "the widget is marked released")
    t.eq(AceGUI.__released[#AceGUI.__released], w, "and listed in release order")
    local ok, err = pcall(AceGUI.Release, AceGUI, w)
    t.falsy(ok, "a second release raises, as in the client")
    t.truthy(tostring(err):find("already released", 1, true), "with the client's message")
end)
