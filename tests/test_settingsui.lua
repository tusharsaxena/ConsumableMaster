-- test_settingsui.lua — the addon's half of LibKa0s-Options-1.0.
--
-- tests/test_schema.lua pins what the settings framework DOES — the rows, the
-- read/write seam, the two-tier refresh — and those cases are deliberately left
-- alone: they were written against the host implementation and they are the
-- oracle for the swap. What this suite adds is the part they cannot see. A
-- behavioral assertion about a scroll container passes just as happily against
-- a host copy left in place, which is exactly what "the swap silently no-opped"
-- looks like from the outside.

local h = require("harness")
local test = h.test
local loader = h.loader

test("Settings UI: the scrollbar patch IS the library's, not a lookalike", function(t)
    local KCM = loader.loadWithSchema()
    local lib = LibStub("LibKa0s-Options-1.0")
    t.truthy(lib, "LibKa0s-Options-1.0 registered")
    -- The strongest assertion available here: PatchAlwaysShowScrollbar is
    -- lib-level and stateless, so it compares by identity with no instance
    -- indirection. It is also the single largest block the swap deleted — 97
    -- lines the addon had hand-transcribed from another Ka0s addon.
    t.eq(KCM.Settings.Helpers.PatchAlwaysShowScrollbar, lib.PatchAlwaysShowScrollbar,
        "PatchAlwaysShowScrollbar is the library function object")
end)

test("Settings UI: the published instance carries all three of the major's files", function(t)
    local KCM = loader.loadWithSchema()
    local UI = KCM.Settings.Helpers.instance
    t.truthy(UI, "the instance is published for the suite to reach")
    -- One major, three files: the shell (Options.lua), the widget helpers
    -- (OptionsWidgets.lua) and the scroll patch (OptionsScroll.lua) all attach
    -- onto the same instance. A copy vendored without its siblings would build
    -- panels that lay out wrong, and this is where that shows up.
    t.truthy(UI.CreatePanel, "the shell attached")
    t.truthy(UI.AttachTooltip, "the widget helpers attached")
    t.truthy(UI.PatchAlwaysShowScrollbar, "the scroll patch attached")
end)

test("Settings UI: the scroll container comes from the library", function(t)
    local KCM = loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    local ctx = H.CreatePanel("KCMTestPanel", "T", { panelKey = "t" })
    local scroll = H.EnsureScroll(ctx)
    t.truthy(scroll, "a scroll container is built")
    t.eq(ctx.scroll, scroll, "…and cached on the ctx the addon threads around")
    -- The marker the host implementation never wrote. It is deliberately
    -- collection-wide rather than per-addon, so two Ka0s addons cannot stack
    -- two overrides on one pooled AceGUI ScrollFrame.
    t.truthy(scroll._ka0sAlwaysScrollbar, "the library's idempotency marker is set")
    t.eq(H.EnsureScroll(ctx), scroll, "a second call reuses it rather than rebuilding")
end)

test("Settings UI: the render helpers are the instance's, not host copies", function(t)
    local KCM = loader.loadWithSchema()
    local H, UI = KCM.Settings.Helpers, KCM.Settings.Helpers.instance
    t.eq(H.AttachTooltip, UI.AttachTooltip, "AttachTooltip is the instance's")
    t.eq(H.AddSpacer, UI.AddSpacer, "AddSpacer is the instance's")
    -- The library spells this one SessionCheckbox; the addon has always called
    -- it CustomCheckbox, and the ~4 page call sites keep that name.
    t.eq(H.CustomCheckbox, UI.SessionCheckbox, "CustomCheckbox is the instance's SessionCheckbox")
    -- Section is the one deliberate WRAPPER rather than a bare binding: the
    -- library sets ctx.lastGroup only inside its own flow engine, which this
    -- addon does not use, so a bare binding would drop the between-sections
    -- spacer forever.
    t.falsy(H.Section == UI.Section, "Section is wrapped, not bound bare")
    -- Driven with the library's own Section stubbed out: it builds a real
    -- AceGUI Heading, and the mock's widget stub answers `h.label` with a
    -- function, which the library's font-object guard cannot index. (The host
    -- implementation carried the identical guard — it was simply never called
    -- headlessly.) What is under test here is the wrapper's one added line.
    local ctx = H.CreatePanel("KCMSectionPanel", "S", { panelKey = "s" })
    local realSection = UI.Section
    UI.Section = function() return nil end
    H.Section(ctx, "First")
    UI.Section = realSection
    t.eq(ctx.lastGroup, "First", "…and the wrapper is what tracks the current section")
end)

test("Settings UI: with the library absent no panel is registered, and it says why once",
    function(t)
        -- Loaded for real with libs/LibKa0s/ omitted, so settings/Panel.lua
        -- takes its own degraded path rather than a hand-written stub.
        local KCM  = loader.loadWithSchemaDegraded()
        local mock = loader.mock
        t.falsy(LibStub("LibKa0s-Options-1.0", true), "the major really is absent")
        t.eq(KCM.Settings.Helpers.instance, nil, "no instance is published")

        -- The schema half is declared above the seam and does not touch it, so
        -- every setting stays readable and writable through /cm list|get|set.
        t.truthy(#KCM.Settings.Schema > 0, "the schema still loads")
        t.truthy(KCM.Settings.Helpers.FindSchema("enabled"), "rows are still resolvable")

        mock.output = {}
        KCM.Settings.Register()
        t.eq(KCM.Settings.main, nil, "no Blizzard category is registered")
        t.eq(KCM.Options.Open(), false, "/cm config answers false rather than doing nothing")

        local notices = 0
        for _, line in ipairs(mock.output) do
            if line:find("settings panel is unavailable", 1, true) then
                notices = notices + 1
            end
        end
        t.eq(notices, 1, "the missing-panel notice is said exactly once")
    end)
