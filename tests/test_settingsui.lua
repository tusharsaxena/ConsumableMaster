-- test_settingsui.lua — the addon's half of LibKa0s-Options-1.0.
--
-- tests/test_schema.lua pins what the settings framework DOES — the rows, the
-- read/write seam, the two-tier refresh — and those cases are deliberately left
-- alone: they were written against the host implementation and they are the
-- oracle for the swap. What this suite adds is the part they cannot see. A
-- behavioral assertion about a scroll container passes just as happily against
-- a host copy left in place, which is exactly what "the swap silently no-opped"
-- looks like from the outside.
--
-- The three options-ui CONFORMANCE blocks were peeled out to
-- tests/test_settingsui_optionsui.lua for layout-§1's 1500-line cap, on the seam
-- issue #33 named: §13's every-page-draws-a-strip, §18's reorder lists, and §13's
-- selection-independent wrapped-strip geometry. What is left here is the half
-- that goes red when THIS ADDON's settings wiring breaks. Every case moved
-- whole; the two files together register exactly the cases this one did.

local h = _G.KCM_TEST
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

-- The Border fixup, which this addon no longer owns.
--
-- core/LSMPatch.lua used to do this — a PLAYER_LOGIN frame that wrapped whatever
-- AceGUI held for "LSM30_Border" and re-registered it one version higher. Four
-- sibling addons shipped their own copy of the same file, and AceGUI's widget
-- registry is process-global, so in a client running all five the wrapper a
-- Border dropdown actually got belonged to whichever addon loaded last. The file
-- is gone; settings/OptionsSetup.lua's live arm calls the library member instead.
--
-- WHY THIS CASE COULD NOT HAVE BEEN WRITTEN BEFORE. The private copy armed a
-- PLAYER_LOGIN frame that never fires headlessly, so nothing in this suite ever
-- observed it — running this case against the old file gives exactly the same
-- red as running it against no fixup at all, which is how five copies of one
-- wrapper stayed invisible for as long as they did. What makes it observable is
-- the `mutate` hook in tests/run.lua: the registry is seeded between the library
-- files and the addon's own, which is the only window a real client's
-- already-registered widget can be modeled in.
test("Settings UI: the live wiring registers the Border fixup through the library", function(t)
    local seededCtor = function()
        local rec = { hidden = false, labelPoints = 0, capPoints = 0 }
        local function region(counter)
            return {
                ClearAllPoints = function() end,
                SetPoint       = function() rec[counter] = rec[counter] + 1 end,
            }
        end
        return {
            __rec  = rec,
            frame = {
                displayButton = { Hide = function() rec.hidden = true end },
                label = region("labelPoints"),
                DLeft = region("capPoints"),
            },
        }
    end

    local KCM = loader.loadWithSchema(false, function()
        LibStub("AceGUI-3.0"):RegisterWidgetType("LSM30_Border", seededCtor, 20)
    end)
    t.truthy(KCM.Settings.optionsUI, "the live arm built an instance")

    local AceGUI = LibStub("AceGUI-3.0")
    local installed = AceGUI.WidgetRegistry["LSM30_Border"]
    t.truthy(installed, "the slot still holds a constructor")
    t.ne(installed, seededCtor, "and it is no longer the one seeded before the addon loaded")
    t.eq(AceGUI:GetWidgetVersion("LSM30_Border"), 21,
        "registered exactly one version above what it found, which is what wins the slot")

    -- Identity is not enough on its own: any re-registration would pass it. This
    -- is the wrapper DOING the fixup — hiding upstream's 42x42 preview tile and
    -- re-anchoring the label and the dropdown bar's left cap — against the
    -- constructor that was in the slot when it ran.
    local widget = installed()
    t.truthy(widget and widget.__rec, "the wrapper returns the wrapped constructor's widget")
    t.truthy(widget.__rec.hidden, "the preview tile is hidden")
    t.eq(widget.__rec.labelPoints, 2, "the label is re-anchored to both top corners")
    t.eq(widget.__rec.capPoints, 1, "the dropdown bar's left cap is put back on the frame's edge")

    -- Idempotent, and this is the half that matters in a client: five vendored
    -- copies of the library are one table to LibStub, so the second caller must
    -- register nothing rather than wrap the first caller's wrapper.
    local lib = LibStub("LibKa0s-Options-1.0")
    t.falsy(lib.__PatchLSM30Border(), "a second call reports that it registered nothing")
    t.eq(AceGUI.WidgetRegistry["LSM30_Border"], installed, "and the slot is untouched")
    t.eq(AceGUI:GetWidgetVersion("LSM30_Border"), 21, "at the same version")
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

test("Settings UI: LibKa0s-Options tripwire — Options reads no descriptor L", function(t)
    -- The L trap, for the one adopted major that cannot express it in the way
    -- Core cannot. NOT Core's tripwire copied across: Options.lua ships a
    -- lib.STRINGS table of its own, so asserting that table is absent would
    -- fail against a module behaving exactly as designed. The half that
    -- transfers is the source half — Options resolves its user-visible strings
    -- from lib.STRINGS with no descriptor override path anywhere in the three
    -- files, so there is nothing for a key-echoing locale table to shadow.
    --
    -- `local L = lib.LAYOUT` at the top of Options.lua is GEOMETRY. The layout
    -- assertion below keeps that distinction pinned against a rename.
    --
    -- red under: adding a `d.L` read to any of the three files.
    loader.loadWithSchema()
    local lib = LibStub("LibKa0s-Options-1.0")
    t.truthy(lib, "the vendored Options major must be registered")
    t.eq(type(rawget(lib, "STRINGS")), "table",
        "Options owning its strings is why this tripwire is shaped unlike Core's")
    t.eq(type(rawget(lib, "LAYOUT")), "table",
        "and `L` inside Options.lua is this geometry table, not a locale one")

    for _, rel in ipairs({ "Options.lua", "OptionsWidgets.lua", "OptionsScroll.lua" }) do
        local fh = assert(io.open("libs/LibKa0s/" .. rel, "r"),
            "cannot open libs/LibKa0s/" .. rel .. " (tests run from the repo root)")
        local src = fh:read("*a")
        fh:close()
        t.falsy(src:find("d.L", 1, true),
            rel .. " now reads a descriptor L — this major can express the trap now, so every "
            .. "host descriptor needs a rendered assertion and this tripwire needs replacing")
    end
end)

-- ── the Blizzard canvas contract (Options minor 5) ─────────────────────────
--
-- Blizzard's Settings window calls OnCommit on apply, OnRefresh on re-show and
-- OnDefault from its own FOOTER defaults control — a different widget from the
-- header Defaults button this addon builds, and not per-page. LibKa0s stamps
-- all three in CreatePanel as of minor 5, so this addon gained a working footer
-- control from a re-vendor without a line of its own changing. Nothing here
-- would notice losing it again: the header button keeps working and looks
-- equivalent to the user.
--
-- rawget throughout, because the frame mock synthesizes a no-op for any
-- PascalCase key — `type(panel.OnDefault) == "function"` is true whether or not
-- anything ever set it.

test("Settings UI: the canvas frame carries OnCommit, OnDefault and OnRefresh", function(t)
    local KCM = loader.loadWithSchema()
    local ctx = KCM.Settings.Helpers.CreatePanel("KCMCanvasPanel1", "C1", { panelKey = "c1" })
    t.eq(type(rawget(ctx.panel, "OnCommit")),  "function", "OnCommit")
    t.eq(type(rawget(ctx.panel, "OnDefault")), "function", "OnDefault")
    t.eq(type(rawget(ctx.panel, "OnRefresh")), "function", "OnRefresh")
end)

test("Settings UI: OnDefault reaches a defaultsOnClick parked after the panel is built", function(t)
    -- settings/Panel.lua parks its handler after CreatePanel returns, because
    -- the Defaults button does not exist until first OnShow. A re-vendor that
    -- turned the library's forwarder back into an assignment would capture nil
    -- while looking correct, and only the footer control would show it — in
    -- game.
    local KCM = loader.loadWithSchema()
    local ctx = KCM.Settings.Helpers.CreatePanel("KCMCanvasPanel2", "C2", { panelKey = "c2" })
    local ran = 0
    ctx.panel.defaultsOnClick = function() ran = ran + 1 end
    rawget(ctx.panel, "OnDefault")()
    t.eq(ran, 1, "the footer control must reach the page's parked defaults action")
end)

test("Settings UI: a page with no defaults action still has a callable, inert OnDefault", function(t)
    -- The About page. The footer control is not per-page, so it can be clicked
    -- while a page that manages nothing is open.
    local KCM = loader.loadWithSchema()
    local ctx = KCM.Settings.Helpers.CreatePanel("KCMCanvasPanel3", "C3", { isMain = true })
    t.falsy(rawget(ctx.panel, "defaultsOnClick"))
    rawget(ctx.panel, "OnDefault")()   -- must not raise
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

test("Settings UI: a panel comes from the library's registry, breadcrumb and all", function(t)
    local KCM = loader.loadWithSchema()
    local H, UI = KCM.Settings.Helpers, KCM.Settings.Helpers.instance
    local ctx = H.CreatePanel("KCMRegistryPanel", "Macro Bar", { panelKey = "macrobar" })
    -- Only O.CreatePanel can put a ctx into the library's private registry, so
    -- this is the assertion a host-built lookalike could not satisfy.
    t.eq(UI.__panelFor("macrobar"), ctx, "the ctx is in the library's own registry")
    -- panel.titleText is the one thing about the composed breadcrumb a test can
    -- read back — a font string is write-only through the frame API. The host's
    -- header recorded nothing, so this is coverage the addon never had.
    t.eq(ctx.panel.titleText, "Ka0s Consumable Master |A:common-icon-forwardarrow:16:16|a Macro Bar",
        "a sub-page composes the brand breadcrumb")
    local main = H.CreatePanel("KCMAboutPanel", "Ka0s Consumable Master", { isMain = true })
    t.eq(main.panel.titleText, "Ka0s Consumable Master",
        "the About page opts out rather than reading the brand twice")
    -- The addon's own render-state fields ride along on the library's ctx: they
    -- back the two-tier refresh (structural rebuild vs in-place re-sync), which
    -- the library has no model for.
    t.eq(ctx._rendered, false, "the ctx still carries the addon's render state")
    t.truthy(ctx.panelKey == "macrobar", "…and the addon's own key alongside the library's")
end)

test("Settings UI: the library's user-visible strings resolve to prose, not to their own keys",
    function(t)
        local KCM  = loader.loadWithSchema()
        local mock = loader.mock
        local H = KCM.Settings.Helpers
        -- The L trap's shape, applied to the one adopted major that cannot
        -- take the trap: Options.lua has no locale seam at all -- its local
        -- `L` is lib.LAYOUT, which is also why LIBKA0S-05 (issue #24) had to accept the
        -- library's shade of gray for the sidebar combat notice rather than
        -- override it. There is no descriptor field here to get wrong, so
        -- what these pin is the other half of the same requirement: that the
        -- library's own STRINGS reach the user as English through the
        -- accessors this addon actually drives.
        --
        -- The media placeholder first, and it is the sharper of the two: the
        -- string is both the label shown in the dropdown AND the value stored
        -- in SavedVariables, so a key leaking here is written to disk.
        -- Read off the library's deferred hash reader directly. This used to go
        -- through the addon's own flattening wrapper, which M4-C1 retired once
        -- its last caller went; going straight at `Helpers.LSMValues` -- the
        -- library's, through __index -- is what this case wanted anyway, since
        -- the string under test is lib.STRINGS.LSM_NONE and a host wrapper
        -- between the assertion and the string could only hide a leak. The hash
        -- is self-keyed, so the key IS the label shown and stored.
        local values = H.LSMValues("kcm_no_such_media_type")()
        local keys = {}
        for k in pairs(values) do keys[#keys + 1] = k end
        t.eq(#keys, 1, "an unregistered media type still offers exactly one option")
        t.falsy(keys[1]:match("^[A-Z][A-Z0-9_]+$"),
            "the empty-media placeholder resolved to prose, not to its own key: "
            .. keys[1])

        -- The chat half: the per-page render failure, which reaches the user
        -- through KCM.Say. Read off the emitted line rather than off
        -- lib.STRINGS, and never guarded on `if text ~= "" then` -- a refresh
        -- that reported nothing has to fail here.
        local ctx = H.CreatePanel("KCMLTrapPanel", "L", { panelKey = "ltrap" })
        ctx.panel.IsShown = function() return true end
        H.SetRenderer(ctx, function() error("boom") end)
        mock.output = {}
        H.RefreshAllPanels()
        local notice = (mock.output[1] or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        notice = notice:gsub("^%[CM%]%s*", "")
        t.truthy(#notice > 0, "the failure was reported at all")
        t.falsy(notice:match("^[A-Z][A-Z0-9_]+$"),
            "the render-failure notice resolved to prose, not to its own key: " .. notice)
    end)

test("Settings UI: ResetScroll reassigns the refresher list rather than wiping it", function(t)
    local KCM = loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    local ctx = H.CreatePanel("KCMResetPanel", "R", { panelKey = "r" })
    local before = ctx.refreshers
    before[#before + 1] = function() end
    H.ResetScroll(ctx)
    -- Load-bearing, and only observable here: RefreshScalars walks
    -- ctx.refreshers THROUGH the ctx, so a wipe-in-place and a reassign are
    -- indistinguishable from the outside except by identity. Reassigning is
    -- what stops released widgets' closures piling up across re-renders.
    t.falsy(ctx.refreshers == before, "a fresh table is installed")
    t.eq(#ctx.refreshers, 0, "…and it starts empty")
    t.eq(ctx.lastGroup, nil, "the section tracker resets with it")
end)

test("Settings UI: with the library absent no panel is registered, and it says why once",
    function(t)
        -- Loaded for real with libs/LibKa0s/ omitted, so settings/OptionsSetup.lua
        -- takes its own degraded path rather than a hand-written stub.
        local KCM  = loader.loadWithSchemaDegraded()
        local mock = loader.mock
        t.falsy(LibStub("LibKa0s-Options-1.0", true), "the major really is absent")
        t.eq(KCM.Settings.Helpers.instance, nil, "no instance is published")

        -- The schema half is declared above the seam and does not touch it, so
        -- the rows still load and Helpers still reads and writes them. NOT via
        -- /cm list|get|set, though — those three are the schema CLI and they
        -- live in LibKa0s-Slash-1.0, so they degrade with it
        -- (tests/test_slashsetup.lua's degraded block).
        --
        -- CM-R-04: this claim used to be carried by two READS —
        -- `#Schema > 0` and `FindSchema(...)` — and a read cannot go red
        -- over a broken write. The write half is exercised here, through the
        -- settings path the panel itself uses (Resolve → Set), and the
        -- assertion is on what LANDED IN THE PROFILE rather than on what the
        -- call returned: a Set that reports true and stores nothing is exactly
        -- the failure the old pair could not see.
        --
        -- The row it drives is a HAND-DECLARED one. The COMPOSED rows are absent
        -- on this arm by construction — see the case below, which measures the
        -- gap rather than leaving it to be discovered.
        --
        -- red under: making Helpers.Set return true without writing, or having
        -- Helpers.Resolve hand back a throwaway table on the degraded arm.
        local H = KCM.Settings.Helpers
        t.truthy(#KCM.Settings.Schema > 0, "the schema still loads")
        local row = H.FindSchema("macroBar.buttonSize")
        t.truthy(row, "rows are still resolvable")

        local before = H.Get(row.path)
        t.eq(before, KCM.db.profile.macroBar.buttonSize,
            "the read agrees with the store to begin with")
        t.truthy(H.Set(row.path, before + 1),
            "the write through the settings path reports success")
        t.eq(KCM.db.profile.macroBar.buttonSize, before + 1,
            "…and the new value is what the profile now holds")
        t.eq(H.Get(row.path), before + 1,
            "…and what a read back through the same path returns")
        H.Set(row.path, before)

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

test("Settings UI: with the library absent Helpers still reaches both refresh tiers",
    function(t)
        -- The gap the copy-across left. `Helpers.RefreshAllPanels = UI and
        -- UI.RefreshAllPanels` binds nil when UI is nil, and both call sites
        -- call the field BARE. Reproduced as
        -- "attempt to call field 'RefreshAllPanels' (a nil value)".
        --
        -- red under: rebinding either name to `UI and UI.<name>`, or dropping
        -- the degraded no-op arm at the seam in settings/OptionsSetup.lua.
        local KCM = loader.loadWithSchemaDegraded()
        local H   = KCM.Settings.Helpers
        t.eq(type(H.RefreshAllPanels), "function", "the structural tier is callable")
        t.eq(type(H.RefreshScalars), "function", "the in-place tier is callable")

        -- O.Refresh is what the PANEL_REFRESH bus message reaches, and Pipeline
        -- fires that on every recompute — so this is a path a degraded install
        -- takes without the user going anywhere near the settings panel.
        local ok, err = pcall(KCM.Options.Refresh)
        t.truthy(ok, "O.Refresh does not raise on the degraded path: " .. tostring(err))
    end)

test("Settings UI: with the library absent a schema WRITE completes and reports success",
    function(t)
        -- The write half, which the read-only degraded case above cannot see.
        -- SetAndRefresh validated, wrote, fired onChange and THEN called
        -- Helpers.RefreshScalars() — so the raise landed after the mutation had
        -- already persisted, and a pcall'ing caller was told the write failed
        -- while the profile disagreed.
        --
        -- red under: the same two rebindings the case above names.
        local KCM = loader.loadWithSchemaDegraded()
        local H   = KCM.Settings.Helpers
        H.Set("macroBar.tooltips", true)

        local ok, res = pcall(H.SetAndRefresh, "macroBar.tooltips", false)
        t.truthy(ok, "the write does not raise: " .. tostring(res))
        t.eq(res, true, "and it reports the success that actually happened")
        t.eq(KCM.db.profile.macroBar.tooltips, false, "the value landed in the profile")

        -- And the validation half degrades identically: no library, same answer.
        t.eq(H.SetAndRefresh("macroBar.tooltips", "yes please"), false,
            "a wrong-typed write is still rejected with the library absent")
        t.eq(H.SetAndRefresh("macroBar.tooltips", nil), false,
            "and an explicit nil still cannot delete the key")
        t.eq(KCM.db.profile.macroBar.tooltips, false, "neither rejected write moved the value")
    end)

-- THE MEASUREMENT options-ui-§1 asks for, and it is a measurement rather than a
-- reading: the stub's member set is settled by loading the addon with the library
-- absent and comparing the resulting SCHEMA ROW COUNT against the fully-loaded
-- environment, not by anyone's idea of what a page file touches at load.
--
-- What it pins is a real and deliberate gap. The composers (OptionsCompose) are
-- called inside schema-row literals AT FILE LOAD, and options-ui-§1 forbids
-- carrying a copy of library code into the stub — so settings/OptionsSetup.lua's
-- degraded arm publishes them answering an EMPTY row list, the page files finish,
-- and every COMPOSED row is missing. That costs nothing reachable: with the
-- library absent no panel is registered and `/cm list|get|set` are
-- LibKa0s-Slash-1.0's, so there is no surface left that could read them.
--
-- red under: dropping any of the four composer stubs from the degraded arm (the
-- page file then RAISES and takes its whole page's rows with it, live count and
-- degraded count both collapsing), or hand-writing a composed block back into a
-- page file (the gap closes and this case says so).
test("Settings UI: the degraded stub completes every page-file load, composed rows aside",
    function(t)
        local live     = loader.loadWithSchema()
        local degraded = loader.loadWithSchemaDegraded()

        local function paths(KCM)
            local out, composed = {}, 0
            for _, r in ipairs(KCM.Settings.Schema) do
                out[r.path] = true
                if r.__composed then composed = composed + 1 end
            end
            return out, composed
        end

        local livePaths, liveComposed = paths(live)
        local degradedPaths           = paths(degraded)

        t.truthy(liveComposed > 0, "the live arm really does compose rows (" .. liveComposed .. ")")

        local missing, unexpected = {}, {}
        for path in pairs(livePaths) do
            if not degradedPaths[path] then missing[#missing + 1] = path end
        end
        for path in pairs(degradedPaths) do
            if not livePaths[path] then unexpected[#unexpected + 1] = path end
        end
        table.sort(missing)
        t.eq(#unexpected, 0, "the degraded arm declares nothing the live one does not")

        -- Every missing path is a composed one, and every composed one is missing:
        -- a HAND-WRITTEN row that vanished degraded would mean a page file raised.
        for _, path in ipairs(missing) do
            local row = live.Settings.Helpers.FindSchema(path)
            t.truthy(row and row.__composed,
                "'" .. path .. "' is absent degraded, and it is a composed row")
        end
        t.eq(#missing, liveComposed,
            "exactly the composed rows are missing — every hand-written row still loads")
    end)

test("Settings UI: Helpers reads the library's members off the instance, not off a copy",
    function(t)
        -- CM-A-04: Helpers used to re-export eleven members by hand, so any
        -- member the list forgot read back nil at the call site with no way to
        -- tell it apart from one the library never had. It delegates now, so
        -- EVERY member the instance publishes is reachable and is the same
        -- function object.
        --
        -- Walked EXHAUSTIVELY over what the instance publishes rather than over
        -- a hand-listed eight, because a hand-listed eight is the CM-A-04 defect
        -- in miniature: it can only catch a forgotten member that someone
        -- remembered to add to the list.
        --
        -- And reachability is all that is asserted. An earlier version of this
        -- case also demanded `rawget(H, name) == nil` for each of the eight —
        -- which forbids an addon-side wrapper for any of them, even though the
        -- second loop below shows a wrapper is a legitimate, currently-shipped
        -- pattern. A future author who needs to wrap RefreshScalars would ship
        -- behaviorally identical code and redden the suite; and the rawget half
        -- detected nothing the `H[name] == UI[name]` line beside it did not,
        -- since __index delegation is exactly what makes that line pass.
        --
        -- red under: deleting the setmetatable in settings/OptionsSetup.lua, or
        -- reinstating a per-member copy that a library rename can outrun.
        local KCM = loader.loadWithSchema()
        local H   = KCM.Settings.Helpers
        local UI  = H.instance
        t.truthy(UI, "the instance is published")

        -- The two the addon deliberately wraps. Each stays an OWN key that
        -- SHADOWS the library's same-named member — which is the only reason
        -- each can call the instance's version without recursing into itself.
        -- LSMValues was a third until M4-C1: its wrapper flattened the library's
        -- deferred hash into an ordered array for one caller, settings/MacroBar
        -- .lua's issue-#15 workaround, and when M3-04 deleted that the wrapper
        -- had nothing left to adapt for. Dropping it from this list is not a
        -- weakened assertion — the loop below now asserts the OPPOSITE for that
        -- name, that `Helpers.LSMValues` IS the instance's own function rather
        -- than a lookalike, which is the stronger of the two claims.
        local WRAPPED = { CreatePanel = true, Section = true }

        local walked = 0
        for name, member in pairs(UI) do
            if type(member) == "function" then
                walked = walked + 1
                if WRAPPED[name] then
                    t.truthy(rawget(H, name), name .. " is the addon's own wrapper")
                    t.falsy(rawget(H, name) == member, name .. " shadows the library's")
                else
                    t.eq(H[name], member,
                        name .. " resolves through Helpers to the instance's own function")
                end
            end
        end
        t.truthy(walked >= 20, "the whole published surface was walked (" .. walked .. ")")
        for name in pairs(WRAPPED) do
            t.eq(type(UI[name]), "function", name .. " is a member the library really publishes")
        end
    end)

-- ── the Battle Rez mouseover toggle (settings/Category.lua) ────────────────
--
-- The mock's Blizzard `Settings` global answers every call with a no-op
-- returning nil (wow_mock.lua), so KCM.Settings.Register()'s registerPanel()
-- cannot run headlessly here — `Settings.RegisterCanvasLayoutCategory(...)`
-- would hand back nil and the next line's `main:GetID()` would raise. This
-- suite already has the workaround: skip straight to the per-page builder
-- KCM.Settings.RegisterTab parked in KCM.Settings.builders, and pull the ctx
-- it built back out of the library's own registry via UI.__panelFor (the same
-- accessor "a panel comes from the library's registry" above relies on).
--
-- There is ONE category builder now, not fifteen: the categories are tabs on the
-- Macros page (options-ui-§13). So the page is built once and the tab is chosen
-- with KCM.Options.SetMacroTab before the render — which is a stricter test than
-- the old one, because it also proves the strip actually swaps the body rather
-- than drawing whichever category it was built with.
--
-- settings/Category.lua resolves `local AceGUI = LibStub("AceGUI-3.0")` ONCE
-- at module load, so a spy installed after loadWithSchema() would miss every
-- AceGUI:Create call the file makes — the swap has to bracket the file's own
-- load, mirroring tests/test_widgets.lua's loadWidgets().
test("Settings: a targeted category tab offers the mouseover toggle, bound to bucket.mouseover",
    function(t)
        local mock = loader.mock

        local files = {}
        for _, f in ipairs(loader.PURE_LAYER) do files[#files + 1] = f end
        for _, f in ipairs(loader.SETTINGS_SEAM) do files[#files + 1] = f end
        local KCM = loader.loadFiles(files)

        t.truthy(KCM.Categories.Get("BATTLE_REZ").targeted, "Battle Rez is targeted")
        t.falsy(KCM.Categories.Get("BLOODLUST").targeted, "Bloodlust is not targeted")
        t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, true, "and defaults on")

        local checkboxes = {}
        local AceGUISpy = setmetatable({
            Create = function(_, kind)
                if kind == "CheckBox" then
                    local w = mock.makeStub()
                    local callbacks = {}
                    w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
                    w._callbacks = callbacks
                    checkboxes[#checkboxes + 1] = w
                    return w
                end
                return mock.makeStub()
            end,
            RegisterWidgetType = function() end,
            RegisterLayout     = function() end,
            GetWidgetVersion   = function() return 0 end,
        }, { __index = function() return function() return mock.makeStub() end end })

        local realLibStub = _G.LibStub
        _G.LibStub = function(name, ...)
            if name == "AceGUI-3.0" then return AceGUISpy end
            return realLibStub(name, ...)
        end
        local root = _G.KCM_TEST_ROOT or "."
        local chunk = assert(loadfile(root .. "/settings/Category.lua"))
        chunk("ConsumableMaster", KCM)
        _G.LibStub = realLibStub

        local H, UI = KCM.Settings.Helpers, KCM.Settings.Helpers.instance

        local macrosBuilder = KCM.Settings.builders["macros"]
        t.truthy(macrosBuilder, "the Macros page registered a builder")
        macrosBuilder({})
        local ctx = UI.__panelFor("macros")
        t.truthy(ctx, "the Macros ctx landed in the library's registry")
        t.truthy(KCM.Options.SetMacroTab("BATTLE_REZ"), "the Battle Rez tab is selectable")
        t.eq(ctx.activeTab, "BATTLE_REZ", "and the page is showing it")
        ctx.panel.IsShown = function() return true end

        local recomputeCalls = {}
        local realRequestRecompute = KCM.Pipeline.RequestRecompute
        KCM.Pipeline.RequestRecompute = function(reason)
            recomputeCalls[#recomputeCalls + 1] = reason
            return realRequestRecompute(reason)
        end

        H.RefreshAllPanels()
        t.eq(#checkboxes, 1, "exactly one checkbox rendered on the Battle Rez page")

        local toggle = checkboxes[1]
        t.truthy(toggle._callbacks.OnValueChanged, "the checkbox is wired to a change handler")
        toggle._callbacks.OnValueChanged(toggle, "OnValueChanged", false)

        t.eq(KCM.db.profile.categories.BATTLE_REZ.mouseover, false,
            "unchecking writes a real boolean false, not nil")
        t.truthy(#recomputeCalls >= 1,
            "unchecking fires a recompute rather than waiting for the next bag event")

        -- Same page, different tab: switching to an untargeted category has to
        -- take the checkbox away with it.
        checkboxes = {}
        t.truthy(KCM.Options.SetMacroTab("BLOODLUST"), "the Bloodlust tab is selectable")

        H.RefreshAllPanels()
        t.eq(#checkboxes, 0, "an untargeted category tab renders no mouseover checkbox")

        t.falsy(KCM.Options.SetMacroTab("NO_SUCH_CATEGORY"),
            "a tab that names no category is refused")
        t.eq(ctx.activeTab, "BLOODLUST", "and the page is left on the tab it was on")
    end)

-- ---------------------------------------------------------------------
-- settings/Category.lua — the shared reset popup and the add-by-ID field.
--
-- Both are file-locals hanging off UI callbacks, and neither had a test. The
-- popup handler is reachable directly (StaticPopupDialogs is a plain global
-- table), so it is driven as-is. The add-by-ID line is LibKa0s-Options-1.0's
-- IdInput, reachable only through the widgets it builds, so these cases render
-- the page and fire OnEnterPressed (or the Add button's OnClick) the way a
-- keypress or a click would.
-- ---------------------------------------------------------------------

-- The pure layer plus BOTH settings files, so the popup table is populated and
-- the category builders are registered.
local function loadCategorySettings()
    local files = {}
    for _, f in ipairs(loader.PURE_LAYER) do files[#files + 1] = f end
    for _, f in ipairs(loader.SETTINGS_SEAM) do files[#files + 1] = f end
    files[#files + 1] = "settings/Category.lua"
    -- And the Add-by-ID line, which is settings/CategoryAddByID.lua's since the
    -- 1500-line peel. It loads after Category.lua, in the TOC's order, because
    -- it takes that file's two published page helpers as file-scope locals.
    files[#files + 1] = "settings/CategoryAddByID.lua"
    return loader.loadFiles(files)
end

test("Settings: the category reset popup restores a composite's AIO fields from defaults",
    function(t)
        local KCM = loadCategorySettings()
        local defaults = KCM.dbDefaults.profile.categories.HP_AIO
        local cfg      = KCM.db.profile.categories.HP_AIO
        t.truthy(#defaults.orderInCombat > 0, "HP_AIO ships an in-combat order to restore")

        cfg.enabled          = { HP_POT = false }
        cfg.orderInCombat    = {}
        cfg.orderOutOfCombat = {}

        local reasons = {}
        KCM.Pipeline.RequestRecompute = function(reason) reasons[#reasons + 1] = reason end

        StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept(nil,
            { catKey = "HP_AIO", composite = true })

        t.eqList(cfg.orderInCombat, defaults.orderInCombat, "in-combat order restored")
        t.eqList(cfg.orderOutOfCombat, defaults.orderOutOfCombat, "out-of-combat order restored")
        t.eq(cfg.enabled.HP_POT, defaults.enabled.HP_POT, "the enabled flags came back too")
        t.eq(reasons[1], "options_aio_reset_cat", "the composite arm's audit reason")

        -- CopyTable, not an alias: a later edit of the live config must not
        -- reach the defaults table for the rest of the session.
        cfg.orderInCombat[1] = "MUTATED"
        t.ne(defaults.orderInCombat[1], "MUTATED", "the restore is a copy")
    end)

test("Settings: the category reset popup clears added/blocked/pins but keeps discovered",
    function(t)
        local KCM = loadCategorySettings()
        local bucket = KCM.Selector.GetBucket("HP_POT")
        t.truthy(bucket, "HP_POT has a bucket")
        bucket.added      = { 111 }
        bucket.blocked    = { 222 }
        bucket.pins       = { 333 }
        bucket.discovered = { [444] = 1 }

        local reasons = {}
        KCM.Pipeline.RequestRecompute = function(reason) reasons[#reasons + 1] = reason end

        StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept(nil,
            { catKey = "HP_POT", composite = false })

        t.eq(#bucket.added, 0, "added cleared")
        t.eq(#bucket.blocked, 0, "blocked cleared")
        t.eq(#bucket.pins, 0, "pins cleared")
        t.eq(bucket.discovered[444], 1, "auto-discovery findings survive a category reset")
        t.eq(reasons[1], "options_reset_cat", "the single arm's reason differs from the composite one")
    end)

test("Settings: the category reset popup is inert with no payload and on an unknown category",
    function(t)
        local KCM = loadCategorySettings()
        local reasons = {}
        KCM.Pipeline.RequestRecompute = function(reason) reasons[#reasons + 1] = reason end

        local OnAccept = StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept
        OnAccept(nil, nil)
        OnAccept(nil, { catKey = "NO_SUCH_CATEGORY", composite = true })
        OnAccept(nil, { catKey = "NO_SUCH_CATEGORY", composite = false })

        t.eq(#reasons, 0, "no mutation is reported when there is nothing to reset")
    end)

-- Render one category tab and hand back its add-by-ID line, which is LibKa0s-Options-1.0's
-- IdInput: the edit box, the Add button beside it and the status line under both, built in that
-- order. Every widget records its text, so a case can read the reason a failed add shows and see
-- whether the typed text was kept. `made` is every widget the render built, in order.
--
-- Create is patched on the mock's own AceGUI table rather than behind a LibStub
-- swap: settings/Panel.lua and settings/Category.lua both captured that table at
-- load, so patching it in place is what puts the library's Section/Label helpers
-- and the category renderer on the same stub. `label`/`editbox` are set to a
-- real `false` because the widget helpers probe those sub-frames before using
-- them, and the permissive stub would otherwise hand back a function to index.
local function renderAddByIDLine(KCM, catKey)
    local mock = loader.mock
    local made = {}
    local AceGUI = LibStub("AceGUI-3.0")
    AceGUI.Create = function(_, kind)
        local w = mock.makeStub()
        w.label, w.editbox = false, false
        w._kind = kind
        local callbacks = {}
        w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
        w._callbacks = callbacks
        w.SetText = function(self, v) self._text = v; return self end
        w.GetText = function(self) return self._text end
        w.SetLabel = function(self, v) self._label = v; return self end
        made[#made + 1] = w
        return w
    end

    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders["macros"]({})
    local ctx = UI.__panelFor("macros")
    KCM.Options.SetMacroTab(catKey)
    ctx.panel.IsShown = function() return true end
    KCM.Settings.Helpers.RefreshAllPanels()

    local line = { made = made }
    for i, w in ipairs(made) do
        if w._kind == "EditBox" then
            local nxt, after = made[i + 1], made[i + 2]
            line.edit   = w
            line.add    = (nxt and nxt._kind == "Button") and nxt or nil
            line.status = (after and after._kind == "Label") and after or nil
            break
        end
    end
    -- Type into the box, then press Enter: the box holds the text either way, as AceGUI's does.
    function line.submit(text)
        line.edit._text = text
        line.edit._callbacks.OnEnterPressed(line.edit, "OnEnterPressed", text)
    end
    return line
end

-- Selector.AddItem replaced by a recorder of the ids it is handed, in call order.
local function recordAdds(KCM)
    local added = {}
    KCM.Selector.AddItem = function(_, id) added[#added + 1] = id; return true end
    return added
end

-- The two fixtures every add-by-ID case types at: one item, one spell. Seeded after the load,
-- because the install that load runs is what clears the stores.
local function seedAddables()
    loader.mock.setItem(960010, { name = "Test Potion", subType = "Potions" })
    loader.mock.setSpell(7744, { name = "Will of the Forsaken" })
end

test("Settings: add-by-ID is the library's id line — an edit box, an Add button, a status line",
    function(t)
        -- red under: renderAddByID drawing its own makeEditBox again (no Add button, no status
        -- line, and nothing but digits or a link could ever resolve)
        local KCM = loadCategorySettings()
        seedAddables()
        local line = renderAddByIDLine(KCM, "HP_POT")
        t.truthy(line.edit, "the tab draws an edit box")
        t.truthy(line.add and line.add._callbacks.OnClick, "with an Add button wired beside it")
        t.truthy(line.status, "and a status line under both")
        t.truthy(line.edit._label and line.edit._label:find("name", 1, true),
            "the box's label says a name is accepted, not only an ID")

        local added = recordAdds(KCM)
        line.edit._text = "960010"
        line.add._callbacks.OnClick(line.add, "OnClick")
        t.eq(added[1], 960010, "Add submits what the box holds")
    end)

test("Settings: add-by-ID takes an ID or a shift-clicked link, of the kind the Type dropdown names",
    function(t)
        -- red under: a resolver that ignores O._addKind (a spell ID stored raw, where it collides
        -- with an itemID). Dropping this addon's own link parsers is NOT caught here, and need
        -- not be: the library's ResolveId reads a link of the kind's own type as well
        local KCM = loadCategorySettings()
        seedAddables()
        local line = renderAddByIDLine(KCM, "HP_POT")
        local added = recordAdds(KCM)

        line.submit("960010")
        t.eq(added[1], 960010, "ITEM is the default kind, and an item ID is stored raw")
        -- Through KCM.Item.ItemIDFromLink, so a pasted link behaves the same on a degraded install.
        line.submit("|cffa335ee|Hitem:960010::::::::80:253::::::|h[Test Potion]|h|r")
        t.eq(added[2], 960010, "a pasted item link resolves to the same ID")

        KCM.Options._addKind.HP_POT = "SPELL"
        line.submit("7744")
        t.eq(added[3], KCM.ID.AsSpell(7744), "a spell ID goes in through the opaque sentinel")
        line.submit("|cff71d5ff|Hspell:7744|h[Will of the Forsaken]|h|r")
        t.eq(added[4], KCM.ID.AsSpell(7744), "and so does a pasted spell link")
        t.eq(line.edit._text, "", "each success clears the box for the next one")
    end)

test("Settings: add-by-ID takes a name, through the client's own lookup", function(t)
    -- red under: a resolver that stops at digits and links (no H.ResolveId name step), or one
    -- that asks the other kind's lookup
    local KCM = loadCategorySettings()
    seedAddables()
    local line = renderAddByIDLine(KCM, "HP_POT")
    local added = recordAdds(KCM)

    line.submit("Test Potion")
    t.eq(added[1], 960010, "an item's name resolves to its ID")

    KCM.Options._addKind.HP_POT = "SPELL"
    line.submit("Will of the Forsaken")
    t.eq(added[2], KCM.ID.AsSpell(7744), "a spell's name resolves, and stores through the sentinel")

    line.submit("Test Potion")
    t.eq(added[3], nil, "an item's name is not a spell's: nothing is added under SPELL")
end)

test("Settings: add-by-ID adds nothing it cannot resolve, says why on its line and keeps the text",
    function(t)
        -- red under: dropping the kind's existence check (an ID the client does not know would be
        -- added), or sending the reason to chat instead of the status line
        local KCM = loadCategorySettings()
        seedAddables()
        local mock = loader.mock
        local line = renderAddByIDLine(KCM, "HP_POT")
        local added = recordAdds(KCM)
        local said = #mock.output

        local function refused(kind, text, noun, why)
            KCM.Options._addKind.HP_POT = kind
            line.status._text = nil
            line.submit(text)
            t.eq(#added, 0, why .. ": nothing is added")
            local status = line.status._text or ""
            t.truthy(status:find(text, 1, true) and status:find(noun, 1, true),
                why .. ": the status line names the " .. noun .. " and what was typed ('"
                    .. status .. "')")
            t.eq(line.edit._text, text, why .. ": the typed text is kept for correcting")
        end

        refused("ITEM", "999999", "item", "an item ID the client does not know")
        refused("ITEM", "0", "item", "zero")
        refused("ITEM", "Nonexistent Thing", "item", "a name nothing answers to")
        refused("SPELL", "999999", "spell", "a spell ID the client does not know")
        -- A link of the WRONG kind is refused rather than cross-filed: an item link read as a spell
        -- would file an itemID behind the opaque sentinel, where it collides with a real spell.
        refused("SPELL", "|cffa335ee|Hitem:960010::::::::80:253::::::|h[Test Potion]|h|r", "spell",
            "an item link while Type says SPELL")
        t.eq(#mock.output, said, "no refusal went to chat")
    end)

test("Settings: add-by-ID stores through Selector.AddItem in the shape it always had", function(t)
    -- red under: the spell stored as its raw ID, or the bucket written some other way than
    -- through the Selector writer
    local KCM = loadCategorySettings()
    seedAddables()
    local reasons = {}
    KCM.Pipeline.RequestRecompute = function(reason) reasons[#reasons + 1] = reason end
    local line = renderAddByIDLine(KCM, "HP_POT")
    line.submit("Test Potion")
    KCM.Options._addKind.HP_POT = "SPELL"
    line.submit("7744")

    local bucket = KCM.Selector.GetBucket("HP_POT")
    t.eq(bucket.added[960010], true, "the item is an `added[id] = true` entry")
    t.truthy(KCM.ID.AsSpell(7744) < 0, "the spell sentinel is negative")
    t.eq(bucket.added[KCM.ID.AsSpell(7744)], true, "and the spell is keyed by it")
    t.eq(bucket.added[7744], nil, "never by its raw ID")
    t.eq(reasons[1], "options_add_item", "the pipeline hears the add under its audit reason")
end)

test("Settings: add-by-ID rebuilds the page only after the id line has finished with its widgets",
    function(t)
        -- red under: afterMutation called inline in onAdd. Through LibKa0s v1.34.0 the library
        -- cleared the edit box and the status label once onAdd returned, onto widgets the rebuild
        -- had already released to AceGUI's pool. v1.35.0 clears both before onAdd, so the box is
        -- already empty here either way; the deferral stays pinned as the order safe under both.
        local KCM = loadCategorySettings()
        seedAddables()
        local line = renderAddByIDLine(KCM, "HP_POT")
        KCM.Selector.AddItem = function() return true end
        KCM.Pipeline.RequestRecompute = function() end
        local queued = {}
        _G.C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
        local textAtRebuild
        rawset(KCM.Settings.Helpers, "RefreshAllPanels", function() textAtRebuild = line.edit._text end)

        line.submit("960010")
        t.eq(textAtRebuild, nil, "nothing was rebuilt while the line was mid-submit")
        t.eq(#queued, 1, "the rebuild waits for the next frame")
        queued[1]()
        t.eq(textAtRebuild, "", "by then the line had already cleared its own box")
    end)

test("Settings: a priority row's Remove button still calls Selector.Block", function(t)
    -- red under: the add-by-ID change reaching into the rows (renderRowButtons'
    -- selectorAction("Block", ...) is the writer the row has always used)
    local KCM = loadCategorySettings()
    seedAddables()
    KCM.Selector.AddItem("HP_POT", 960010)
    KCM.Pipeline.RequestRecompute = function() end
    local line = renderAddByIDLine(KCM, "HP_POT")
    local blocked = {}
    KCM.Selector.Block = function(catKey, id) blocked[#blocked + 1] = { catKey, id }; return true end

    local remove, seenRow
    for _, w in ipairs(line.made) do
        if w._kind == "KCMItemRow" then seenRow = true end
        if seenRow and w._kind == "KCMIconButton" and not remove then remove = w end
    end
    t.truthy(remove and remove._callbacks.OnClick, "the added item's row draws its Remove button")
    remove._callbacks.OnClick(remove, "OnClick")
    t.eq(blocked[1] and blocked[1][1], "HP_POT", "Remove blocks in the row's own category")
    t.eq(blocked[1] and blocked[1][2], 960010, "the row's own id")
end)

test("Settings: add-by-ID refuses a spec-aware category with no resolvable spec, on its line",
    function(t)
        -- red under: the spec check made in onAdd. onAdd returning normally is a success to the
        -- id line, which has already cleared the box and the status line, so a valid ID was wiped and
        -- the reason went to chat, the one place the line's own refusals never go.
        local KCM = loadCategorySettings()
        local mock = loader.mock
        mock.setItem(960011, { name = "Test Flask", subType = "Flasks & Phials" })

        -- settings/StatPriority.lua is not loaded here, so O.ResolveViewedSpec is
        -- absent and FLASK renders with no viewed spec — the same state a
        -- sub-level-10 character sees.
        t.falsy(KCM.Options.ResolveViewedSpec, "no viewed-spec resolver in this file set")

        local line = renderAddByIDLine(KCM, "FLASK")
        t.truthy(line.edit and line.edit._callbacks.OnEnterPressed, "the add-by-ID line rendered anyway")
        local added = recordAdds(KCM)
        local said = #mock.output
        line.submit("960011")

        t.eq(#added, 0, "the ID is valid, but there is nowhere to put it: nothing is added")
        t.eq(line.edit._text, "960011", "the typed text is kept, as on every other refusal")
        local status = line.status and line.status._text or ""
        t.truthy(status:lower():find("no active spec", 1, true) and status:find("960011", 1, true),
            "the status line says why, naming what was typed ('" .. status .. "')")
        t.eq(#mock.output, said, "and the refusal does not go to chat")
    end)

-- ---------------------------------------------------------------------------
-- The panel refresh debounce
-- ---------------------------------------------------------------------------
--
-- O.RequestRefresh is the panel-side twin of Pipeline.RequestRecompute, and
-- until now it had no case at all: tests/test_pipeline.lua pins the coalescing
-- of the recompute burst, nothing pinned the coalescing of the rebuild burst.
-- That is how a debounce that armed one timer PER CALL — 150 of them for the
-- one rebuild the first-open GET_ITEM_INFO_RECEIVED storm is supposed to
-- produce — stayed green for as long as it did. tests/perf.lua's `refreshBurst`
-- scenario carries the byte figure; these carry the behavior.
--
-- WHY THE CLOCK AND THE QUEUE ARE REPLACED. tests/wow_mock.lua's C_Timer.After
-- runs its callback inline and its GetTime is os.clock(), so the shipped pair
-- can say "the timer fired" but cannot say "a second passed and no call came".
-- The debounce is entirely about the second sentence. The stubs below are the
-- shape tests/test_pipeline.lua's coalescing case already uses, plus a clock;
-- `advance` honors the delays and fires each callback AT its due instant, so a
-- callback that re-arms is woken again inside the same advance exactly as the
-- client would wake it.
local function fakeSchedule(KCM)
    local s = { now = 0, armed = 0, rebuilds = 0, rebuiltAt = {}, queue = {} }
    local savedGetTime, savedAfter = _G.GetTime, _G.C_Timer.After

    _G.GetTime = function() return s.now end
    _G.C_Timer.After = function(delay, fn)
        s.armed = s.armed + 1
        s.queue[#s.queue + 1] = { at = s.now + (delay or 0), fn = fn }
    end
    -- Counted at the Helpers seam rather than at O.Refresh, so O.Refresh keeps
    -- running its own bookkeeping — clearing _refreshPending is what makes the
    -- NEXT burst a burst rather than a continuation of this one.
    KCM.Settings.Helpers.RefreshAllPanels = function()
        s.rebuilds = s.rebuilds + 1
        s.rebuiltAt[#s.rebuiltAt + 1] = s.now
    end

    function s.advance(seconds)
        local target = s.now + seconds
        while true do
            local idx
            for i, e in ipairs(s.queue) do
                if e.at <= target and (idx == nil or e.at < s.queue[idx].at) then idx = i end
            end
            if not idx then break end
            local e = table.remove(s.queue, idx)
            s.now = e.at
            e.fn()
        end
        s.now = target
    end

    function s.restore()
        _G.GetTime, _G.C_Timer.After = savedGetTime, savedAfter
    end

    return s
end

-- red under: the token-per-call debounce this replaced, which armed 150.
test("Settings UI: a first-open refresh burst arms one timer, not one per call", function(t)
    local KCM = loader.loadWithSchema()
    local s = fakeSchedule(KCM)

    -- The GIIR storm docs/data-flow.md describes: ~150 non-bag items hydrating
    -- a millisecond apart, each one publishing PANEL_REFRESH.
    for _ = 1, 150 do
        s.now = s.now + 0.001
        KCM.Options.RequestRefresh()
    end
    t.eq(s.armed, 1, "the whole burst is covered by the timer the first call armed")
    t.eq(s.rebuilds, 0, "and nothing rebuilds while the burst is still arriving")

    s.advance(1.0)
    t.eq(s.rebuilds, 1, "one rebuild for one burst, which is the point of the debounce")
    -- Two, not one: the first timer wakes a second after the FIRST call, by
    -- which time the burst had run on for 0.149s, so it re-arms for the quiet
    -- still owed rather than rebuilding early. That re-arm is why tests/perf.lua
    -- puts its ceiling at two timers per burst and not at one.
    t.eq(s.armed, 2, "one re-arm to serve out the quiet the burst consumed, and no more")

    s.restore()
end)

-- red under: rebuilding on the leading edge instead of the trailing one.
test("Settings UI: the rebuild waits out the quiet window before it lands", function(t)
    local KCM = loader.loadWithSchema()
    local s = fakeSchedule(KCM)

    KCM.Options.RequestRefresh()
    s.advance(0.9)
    t.eq(s.rebuilds, 0, "nine tenths of a second in, the window has not closed")

    s.advance(0.2)
    t.eq(s.rebuilds, 1, "and the rebuild lands once the full second of quiet is up")

    s.restore()
end)

-- red under: the token-per-call shape, which never rebuilt here at all. Every
-- arriving call invalidated the pending timer, so a storm whose calls land
-- closer together than the 0.05s floor deferred the rebuild for as long as it
-- ran — the old arithmetic capped the DELAY OF ONE TIMER, never the wait.
test("Settings UI: a storm that never goes quiet still rebuilds at the max wait", function(t)
    local KCM = loader.loadWithSchema()
    local s = fakeSchedule(KCM)

    -- Five seconds of calls ten milliseconds apart. The quiet window never
    -- opens, so only the cap can end the wait.
    for _ = 1, 500 do
        KCM.Options.RequestRefresh()
        s.advance(0.01)
    end

    t.eq(s.rebuilds, 1, "the cap fired exactly once across the five seconds")
    t.near(s.rebuiltAt[1], 3.0, 0.1,
        "and it fired at REFRESH_MAX_WAIT_SEC after the first call, not later")

    s.restore()
end)

-- red under: dropping the armedAt/armedFor compare in onRefreshDue. The red is
-- a stack overflow rather than a failed assertion — every re-arm is answered
-- inline, so onRefreshDue re-enters itself until the stack goes — and it is not
-- confined to this case: with the guard removed, 35 cases across this suite
-- fail on "stack overflow", because anything that reaches a recompute reaches
-- this function. That blast radius is the reason the guard sits in the addon
-- rather than in the mock.
test("Settings UI: a timer that fires early rebuilds instead of re-arming forever", function(t)
    local KCM = loader.loadWithSchema()
    local rebuilds = 0
    KCM.Settings.Helpers.RefreshAllPanels = function() rebuilds = rebuilds + 1 end

    -- The mock's C_Timer.After exactly as shipped: the callback runs inline,
    -- which is a timer that ignored its delay. No quiet period can be observed
    -- through it, so waiting for one is unanswerable and rebuilding is the only
    -- honest answer.
    KCM.Options.RequestRefresh()
    t.eq(rebuilds, 1, "the request was served rather than rescheduled against a clock that is not moving")
end)

-- ---------------------------------------------------------------------------
-- #35 characterization: the Stat Priority and composite panel writers
-- ---------------------------------------------------------------------------

local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

test("Settings: the Stat Priority Defaults button drops only the viewed spec's override", function(t)
    local KCM = loader.loadFullAddon()
    local UI  = KCM.Settings.Helpers.instance
    KCM.Options._viewedSpec, KCM.Options._viewedSpecAuto = "8_262", false
    KCM.db.profile.statPriority = {
        ["8_262"] = { primary = "AGI", secondary = { "HASTE" } },
        ["7_263"] = { primary = "STR", secondary = {} },
    }
    KCM.Settings.builders.statpriority({})
    UI.__panelFor("statpriority").panel.defaultsOnClick()
    t.eq(ser(KCM.db.profile.statPriority), ser({ ["7_263"] = { primary = "STR", secondary = {} } }),
        "the viewed spec's override is gone and the other stays")
end)

-- The Macros page captures AceGUI at file load, so the spy has to bracket the
-- load of settings/Category.lua -- the same shape the mouseover case uses.
local function categoryWithCheckboxSpy()
    local mock = loader.mock
    local files = {}
    for _, f in ipairs(loader.PURE_LAYER) do files[#files + 1] = f end
    for _, f in ipairs(loader.SETTINGS_SEAM) do files[#files + 1] = f end
    local KCM = loader.loadFiles(files)
    local boxes = {}
    local spy = setmetatable({
        Create = function(_, kind)
            local w = mock.makeStub()
            if kind == "CheckBox" then
                local callbacks = {}
                w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
                w._callbacks = callbacks
                boxes[#boxes + 1] = w
            end
            return w
        end,
        RegisterWidgetType = function() end,
        RegisterLayout     = function() end,
        GetWidgetVersion   = function() return 0 end,
    }, { __index = function() return function() return mock.makeStub() end end })
    local realLibStub = _G.LibStub
    _G.LibStub = function(name, ...)
        if name == "AceGUI-3.0" then return spy end
        return realLibStub(name, ...)
    end
    local chunk = assert(loadfile((_G.KCM_TEST_ROOT or ".") .. "/settings/Category.lua"))
    chunk("ConsumableMaster", KCM)
    _G.LibStub = realLibStub
    return KCM, boxes
end

test("Settings: a composite's Enabled checkbox stores a real boolean for its sub-category", function(t)
    local KCM, boxes = categoryWithCheckboxSpy()
    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders["macros"]({})
    local ctx = UI.__panelFor("macros")
    KCM.Options.SetMacroTab("HP_AIO")
    ctx.panel.IsShown = function() return true end
    KCM.Settings.Helpers.RefreshAllPanels()

    t.eq(#boxes, 3, "one Enabled checkbox per sub-category: HS, HP_POT, then FOOD")
    local hpPot = boxes[2]
    hpPot._callbacks.OnValueChanged(hpPot, "OnValueChanged", false)
    t.eq(ser(KCM.db.profile.categories.HP_AIO.enabled), ser({ HS = true, HP_POT = false, FOOD = true }),
        "unticking one sub-category writes its flag and no other")
end)

local function recordSets(KCM)
    local H = KCM.Settings.Helpers
    local paths, real = {}, H.Set
    H.Set = function(path, value) paths[#paths + 1] = path; return real(path, value) end
    return paths
end

-- red under: any of these controls writing its field directly again.
test("Settings: every Stat Priority, composite and mouseover control writes through the schema helper",
    function(t)
        local KCM = loader.loadFullAddon()
        local UI  = KCM.Settings.Helpers.instance
        KCM.Options._viewedSpec, KCM.Options._viewedSpecAuto = "8_262", false
        KCM.db.profile.statPriority = { ["8_262"] = { primary = "AGI", secondary = { "HASTE" } } }
        local paths = recordSets(KCM)
        KCM.Settings.builders.statpriority({})
        local ctx = UI.__panelFor("statpriority")
        ctx.panel.IsShown = function() return true end
        KCM.Settings.Helpers.RefreshAllPanels()
        ctx.kcmStatRows[1].kcmGlyph:_run("OnClick")
        ctx.panel.defaultsOnClick()
        KCM.ResetAllPriorities()
        t.eqList(paths, { "statPriority", "statPriority", "statPriority" },
            "the include glyph, the page Defaults and Reset all priorities")

        local K2, boxes = categoryWithCheckboxSpy()
        local paths2 = recordSets(K2)
        local UI2 = K2.Settings.Helpers.instance
        K2.Settings.builders["macros"]({})
        local ctx2 = UI2.__panelFor("macros")
        ctx2.panel.IsShown = function() return true end
        K2.Options.SetMacroTab("HP_AIO")
        K2.Settings.Helpers.RefreshAllPanels()
        boxes[1]._callbacks.OnValueChanged(boxes[1], "OnValueChanged", false)
        K2.Selector.MoveCompositeRef("HP_AIO", "orderInCombat", 1, 2)
        StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept(nil, { catKey = "HP_AIO", composite = true })
        local n = #boxes
        K2.Options.SetMacroTab("BATTLE_REZ")
        K2.Settings.Helpers.RefreshAllPanels()
        local mouseover = boxes[n + 1]
        mouseover._callbacks.OnValueChanged(mouseover, "OnValueChanged", false)
        t.eqList(paths2, {
            "categories.HP_AIO.enabled", "categories.HP_AIO.orderInCombat",
            "categories.HP_AIO.enabled", "categories.HP_AIO.orderInCombat",
            "categories.HP_AIO.orderOutOfCombat",
            "categories.BATTLE_REZ.mouseover",
        }, "the Enabled checkbox, the drag, the section reset and the mouseover toggle")
    end)
