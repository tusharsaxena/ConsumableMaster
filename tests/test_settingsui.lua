-- test_settingsui.lua — the addon's half of LibKa0s-Options-1.0.
--
-- tests/test_schema.lua pins what the settings framework DOES — the rows, the
-- read/write seam, the two-tier refresh — and those cases are deliberately left
-- alone: they were written against the host implementation and they are the
-- oracle for the swap. What this suite adds is the part they cannot see. A
-- behavioral assertion about a scroll container passes just as happily against
-- a host copy left in place, which is exactly what "the swap silently no-opped"
-- looks like from the outside.

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
        local values = H.LSMValues("kcm_no_such_media_type")
        t.eq(#values, 1, "an unregistered media type still offers exactly one option")
        t.falsy(values[1].text:match("^[A-Z][A-Z0-9_]+$"),
            "the empty-media placeholder resolved to prose, not to its own key: "
            .. values[1].text)

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
        -- behaviourally identical code and redden the suite; and the rawget half
        -- detected nothing the `H[name] == UI[name]` line beside it did not,
        -- since __index delegation is exactly what makes that line pass.
        --
        -- red under: deleting the setmetatable in settings/OptionsSetup.lua, or
        -- reinstating a per-member copy that a library rename can outrun.
        local KCM = loader.loadWithSchema()
        local H   = KCM.Settings.Helpers
        local UI  = H.instance
        t.truthy(UI, "the instance is published")

        -- The three the addon deliberately wraps. Each stays an OWN key that
        -- SHADOWS the library's same-named member — which is the only reason
        -- each can call the instance's version without recursing into itself.
        local WRAPPED = { CreatePanel = true, Section = true, LSMValues = true }

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
-- table), so it is driven as-is. The add-by-ID validator is only reachable
-- through the EditBox its renderer builds, so these cases render the page and
-- fire OnEnterPressed the way a keypress would.
-- ---------------------------------------------------------------------

-- The pure layer plus BOTH settings files, so the popup table is populated and
-- the category builders are registered.
local function loadCategorySettings()
    local files = {}
    for _, f in ipairs(loader.PURE_LAYER) do files[#files + 1] = f end
    for _, f in ipairs(loader.SETTINGS_SEAM) do files[#files + 1] = f end
    files[#files + 1] = "settings/Category.lua"
    return loader.loadFiles(files)
end

-- Select one category tab and hand back every EditBox the renderer built.
--
-- Create is patched on the mock's own AceGUI table rather than behind a LibStub
-- swap: settings/Panel.lua and settings/Category.lua both captured that table at
-- load, so patching it in place is what puts the library's Section/Label helpers
-- and the category renderer on the same stub. `label`/`editbox` are set to a
-- real `false` because the widget helpers probe those sub-frames before using
-- them, and the permissive stub would otherwise hand back a function to index.
local function renderCategoryEditBoxes(KCM, catKey)
    local mock = loader.mock
    local boxes = {}
    local AceGUI = LibStub("AceGUI-3.0")
    AceGUI.Create = function(_, kind)
        local w = mock.makeStub()
        w.label, w.editbox = false, false
        if kind == "EditBox" then
            local callbacks = {}
            w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
            w._callbacks = callbacks
            boxes[#boxes + 1] = w
        end
        return w
    end

    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders["macros"]({})
    local ctx = UI.__panelFor("macros")
    -- The category is a TAB on the one Macros page now, so it is selected rather
    -- than built: fifteen builders became one.
    KCM.Options.SetMacroTab(catKey)
    ctx.panel.IsShown = function() return true end
    KCM.Settings.Helpers.RefreshAllPanels()
    return boxes
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

test("Settings: add-by-ID rejects bad input by kind and says why", function(t)
    local KCM = loadCategorySettings()
    local mock = loader.mock
    mock.setItem(960010, { name = "Test Potion", subType = "Potions" })
    mock.setSpell(7744, { name = "Will of the Forsaken" })

    local eb = renderCategoryEditBoxes(KCM, "HP_POT")[1]
    t.truthy(eb and eb._callbacks.OnEnterPressed, "the add-by-ID field is wired to Enter")
    local submit = function(text) eb._callbacks.OnEnterPressed(eb, "OnEnterPressed", text) end

    local function lastSaid()
        return mock.output[#mock.output]
    end

    submit("abc")
    t.truthy(lastSaid():find("expected a positive numeric ID or a pasted link; got: abc", 1, true),
        "non-numeric input is named back to the user")
    submit("0")
    t.truthy(lastSaid():find("expected a positive numeric ID or a pasted link; got: 0", 1, true),
        "zero is rejected, not silently added")
    submit("999999")
    t.truthy(lastSaid():find("unknown itemID: 999999", 1, true),
        "ITEM is the default kind, and an ID the client doesn't know is refused")

    KCM.Options._addKind.HP_POT = "SPELL"
    submit("999999")
    t.truthy(lastSaid():find("unknown spellID: 999999", 1, true),
        "the kind selector switches which existence check runs")

    -- The success path, on both kinds: a resolvable ID reaches Selector.AddItem.
    local added = {}
    KCM.Selector.AddItem = function(catKey, id) added[#added + 1] = id; return true end
    submit("7744")
    t.eq(added[1], KCM.ID.AsSpell(7744), "a spell ID is stored through the opaque sentinel")
    KCM.Options._addKind.HP_POT = "ITEM"
    submit("960010")
    t.eq(added[2], 960010, "an item ID is stored raw")

    -- A SHIFT-CLICKED LINK, which is the natural gesture for "add this one" and used to be told
    -- "expected a positive numeric ID" — an answer that is true and useless. Parsed through
    -- KCM.Item.ItemIDFromLink, so it behaves identically on a degraded install.
    submit("|cffa335ee|Hitem:960010::::::::80:253::::::|h[Test Potion]|h|r")
    t.eq(added[3], 960010, "the link resolved to the same id the digits did")

    -- And the same on the spell side, through that kind's own parser.
    KCM.Options._addKind.HP_POT = "SPELL"
    submit("|cff71d5ff|Hspell:7744|h[Will of the Forsaken]|h|r")
    t.eq(added[4], KCM.ID.AsSpell(7744), "a pasted spell link stores through the sentinel too")

    -- A link of the WRONG kind is refused rather than cross-filed: an item link parsed as a spell
    -- would file an itemID under the opaque sentinel, where it collides with a real spell.
    submit("|cffa335ee|Hitem:960010::::::::80:253::::::|h[Test Potion]|h|r")
    t.truthy(lastSaid():find("expected a positive numeric ID or a pasted link", 1, true),
        "an item link is not accepted while the kind selector says SPELL")
    t.eq(added[5], nil, "and nothing was added")
end)

test("Settings: add-by-ID refuses a spec-aware category with no resolvable spec", function(t)
    local KCM = loadCategorySettings()
    local mock = loader.mock
    mock.setItem(960011, { name = "Test Flask", subType = "Flasks & Phials" })

    -- settings/StatPriority.lua is not loaded here, so O.ResolveViewedSpec is
    -- absent and FLASK renders with no viewed spec — the same state a
    -- sub-level-10 character sees.
    t.falsy(KCM.Options.ResolveViewedSpec, "no viewed-spec resolver in this file set")

    local eb = renderCategoryEditBoxes(KCM, "FLASK")[1]
    t.truthy(eb and eb._callbacks.OnEnterPressed, "the add-by-ID field rendered anyway")
    eb._callbacks.OnEnterPressed(eb, "OnEnterPressed", "960011")

    t.truthy(mock.output[#mock.output]:find("spec-aware category: no active spec", 1, true),
        "the ID is valid, but there is nowhere to put it and the user is told")
end)

-- ---------------------------------------------------------------------------
-- options-ui-§13 — EVERY page draws a strip
-- ---------------------------------------------------------------------------
--
-- Not a size threshold and not a choice: a Ka0s page has a strip, so a player who
-- has learned one page has learned all of them. The only exemptions are pages the
-- host does not render through the flow engine at all — the AceConfig-drawn
-- Profiles sub-page (which this addon does not ship) and the landing page, whose
-- body is buildMain.
--
-- Observed on the STRIP THE PAGE ACTUALLY DRAWS, through the library member every
-- page routes to, rather than on a tab table a page publishes: a published table
-- and a drawn strip are two facts and only one of them is what the player sees.

--- Build every page, mark it shown, render it, and hand back the tab specs each
--- one drew, keyed by page.
local function renderEveryPage(KCM)
    local UI = KCM.Settings.Helpers.instance
    local drawn = {}
    local current
    local realTabStrip = UI.TabStrip
    UI.TabStrip = function(ctx, spec)
        drawn[current] = spec
        return realTabStrip(ctx, spec)
    end

    for _, key in ipairs(KCM.Settings.order) do
        local builder = KCM.Settings.builders[key]
        if builder then
            builder({})
            local ctx = UI.__panelFor(key)
            if ctx then
                ctx.panel.IsShown = function() return true end
                current = key
                KCM.Settings.Helpers.RefreshAllPanels()
            end
        end
    end

    UI.TabStrip = realTabStrip
    return drawn
end

-- red under: returning early from any page's render before the strip is drawn,
-- or renaming the General page's first tab.
test("Settings: every page draws a tab strip, and General opens on Master controls",
    function(t)
        local KCM = loader.loadFullAddon()
        local drawn = renderEveryPage(KCM)

        local FIRST = {
            general      = "Master controls",
            macros       = "FOOD",
            statpriority = "Priority",
            macrobar     = "General",
        }
        for _, key in ipairs(KCM.Settings.order) do
            local spec = drawn[key]
            t.truthy(spec and spec.tabs and #spec.tabs > 0,
                "the '" .. key .. "' page drew a strip")
            t.eq(spec and spec.tabs[1] and spec.tabs[1].key, FIRST[key],
                "…whose first tab is " .. FIRST[key])
        end

        t.eq(#drawn.general.tabs, 2, "General is Master controls + Maintenance")
        t.eq(#drawn.macrobar.tabs, 8, "the Macro Bar page keeps its eight")
        t.eq(#drawn.macros.tabs, #KCM.Categories.LIST,
            "the Macros page carries one tab per category")
        t.eq(#drawn.statpriority.tabs, 1,
            "and a one-section page draws a ONE-TAB strip rather than none")
    end)

-- The conditional no-strip state options-ui-§13 forbids: the Stat Priority page
-- used to return before drawing anything when no spec could be resolved, and the
-- Macros page's spec-aware tabs do the same for their priority list. The strip is
-- chrome and must not depend on the data.
--
-- red under: moving the no-spec early return back above H.TabStrip.
test("Settings: the Stat Priority page draws its strip with no spec resolvable", function(t)
    local KCM = loader.loadFullAddon()
    local UI  = KCM.Settings.Helpers.instance

    -- No spec at all: SpecHelper answers nothing and no pin survives.
    KCM.Options._viewedSpec     = nil
    KCM.Options._viewedSpecAuto = true
    local realGetCurrent = KCM.SpecHelper.GetCurrent
    KCM.SpecHelper.GetCurrent = function() return nil, nil, nil end

    local drew = 0
    local realTabStrip = UI.TabStrip
    UI.TabStrip = function(ctx, spec) drew = drew + 1; return realTabStrip(ctx, spec) end

    KCM.Settings.builders.statpriority({})
    local ctx = UI.__panelFor("statpriority")
    ctx.panel.IsShown = function() return true end
    KCM.Settings.Helpers.RefreshAllPanels()

    UI.TabStrip = realTabStrip
    KCM.SpecHelper.GetCurrent = realGetCurrent

    t.eq(drew, 1, "the strip is drawn before the empty state, not instead of it")
end)

-- The Macros page had the same shape of defect one step further in: it returned
-- before H.TabStrip whenever the category list came back empty. Unreachable in the
-- shipped configuration -- Categories.LIST is a constant of fifteen -- but "cannot
-- happen today" is not "cannot render strip-less", and contract step 2.5's
-- done-when is the second one. The empty state is content inside the page now.
--
-- red under: restoring the `if not (cat and #tabs > 0) then return end` guard
-- above H.TabStrip.
test("Settings: the Macros page reaches its strip with no categories to tab", function(t)
    local KCM = loader.loadFullAddon()
    local UI  = KCM.Settings.Helpers.instance

    local realOrder = KCM.Settings.macroOrder
    KCM.Settings.macroOrder = {}

    local strips, labels = 0, 0
    local realTabStrip = UI.TabStrip
    local realLabel    = KCM.Settings.Helpers.Label
    UI.TabStrip = function(ctx, spec) strips = strips + 1; return realTabStrip(ctx, spec) end
    KCM.Settings.Helpers.Label = function(ctx, text, size)
        labels = labels + 1
        return realLabel(ctx, text, size)
    end

    local ok, err = pcall(function()
        KCM.Settings.builders.macros({})
        local ctx = UI.__panelFor("macros")
        ctx.panel.IsShown = function() return true end
        KCM.Settings.Helpers.RefreshAllPanels()
    end)

    UI.TabStrip                = realTabStrip
    KCM.Settings.Helpers.Label = realLabel
    KCM.Settings.macroOrder    = realOrder
    if not ok then error(err, 0) end

    t.eq(strips, 1, "the strip is asked for first, whatever the data says")
    t.truthy(labels >= 1, "and the empty state is drawn INSIDE the page, under it")
end)

-- ---------------------------------------------------------------------------
-- options-ui-§18 — the reorder lists
-- ---------------------------------------------------------------------------

--- Record every controller LibKa0s-Widgets hands out while `fn` runs, and how
--- many times each was cancelled.
local function recordControllers(fn)
    local W = LibStub("LibKa0s-Widgets-1.0")
    local made = {}
    local realReorder = W.ReorderList
    W.ReorderList = function(opts)
        local list = realReorder(opts)
        local realCancel = list.Cancel
        list.__cancels = 0
        list.Cancel = function(self, ...)
            self.__cancels = self.__cancels + 1
            return realCancel(self, ...)
        end
        made[#made + 1] = list
        return list
    end
    local ok, err = pcall(fn)
    W.ReorderList = realReorder
    if not ok then error(err, 0) end
    return made
end

--- Build the Macros page, select `catKey`, render, and hand back the ctx.
local function showMacroTab(KCM, catKey)
    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders.macros({})
    local ctx = UI.__panelFor("macros")
    ctx.panel.IsShown = function() return true end
    KCM.Options.SetMacroTab(catKey)
    KCM.Settings.Helpers.RefreshAllPanels()
    return ctx
end

-- The AIO tabs route to the composite renderer, which drew PAIRED ARROWS and
-- constructed no controller at all (anti-patterns #75). Each of its two sections
-- is a separate stored array, so it gets its OWN flat controller — two, not one
-- with a boundary — and the cancel seam has to hold both.
--
-- red under: building one controller for both sections, or reverting
-- cancelReorder to a single `ctx.kcmReorder` (the first section's handles and
-- boxes then leak onto whatever the next render pools).
test("Settings: a composite tab builds one reorder controller per combat section",
    function(t)
        local KCM = loader.loadFullAddon()
        local made = recordControllers(function() showMacroTab(KCM, "HP_AIO") end)

        t.eq(#made, 2, "In Combat and Out of Combat each got their own controller")
        for i, list in ipairs(made) do
            t.eq(list.boundary, nil,
                "controller #" .. i .. " is FLAT — the sections are separate arrays")
        end

        local ctx = KCM.Options._macrosCtx
        t.eq(type(ctx.kcmReorder), "table", "the cancel seam holds a LIST of controllers")
        t.eq(#ctx.kcmReorder, 2, "…with both of them in it")
    end)

-- The single most common way an adoption of this widget goes wrong: a controller
-- released late leaves pooled handles and boxes attached to recycled widgets
-- belonging to something else.
--
-- red under: moving cancelReorder below H.ResetScroll, or dropping either
-- controller from the list the seam holds.
test("Settings: re-rendering a composite tab cancels EVERY controller it built",
    function(t)
        local KCM = loader.loadFullAddon()
        local first = recordControllers(function() showMacroTab(KCM, "HP_AIO") end)
        t.eq(#first, 2, "the first render built two")

        recordControllers(function() KCM.Settings.Helpers.RefreshAllPanels() end)
        for i, list in ipairs(first) do
            t.truthy(list.__cancels >= 1,
                "controller #" .. i .. " from the previous render was cancelled")
        end
    end)

-- options-ui-§18 puts the drag handle and its fixed-width gutter under the
-- LIBRARY's ownership, "so every draggable list in the collection reads the same",
-- and the width moved 24 -> 30 for this pass. Every list here therefore takes
-- `lib.ROW_BOX.HANDLE_W` and declares no `handleSize` of its own: an override is
-- silent -- 2px is invisible in isolation -- so nothing but a case says it happened.
--
-- Observed on the OPTS each call site hands the widget, because the divergence
-- being pinned is the declaration, not the pixel.
--
-- red under: passing handleSize back to any of the three ReorderList calls (the
-- old value was ROW_BTN_W = 32, the width of the row's square ACTION buttons,
-- which was only ever the same number by coincidence).
test("Settings: every reorder list takes the library's handle gutter", function(t)
    local KCM = loader.loadFullAddon()
    local W   = LibStub("LibKa0s-Widgets-1.0")

    local seen = {}
    local realReorder = W.ReorderList
    W.ReorderList = function(opts)
        seen[#seen + 1] = opts
        return realReorder(opts)
    end

    local ok, err = pcall(function()
        showMacroTab(KCM, "FOOD")       -- the flat priority list
        showMacroTab(KCM, "HP_AIO")     -- the two composite sections
        local UI = KCM.Settings.Helpers.instance
        KCM.Settings.builders.statpriority({})
        local ctx = UI.__panelFor("statpriority")
        ctx.panel.IsShown = function() return true end
        KCM.Settings.Helpers.RefreshAllPanels()
    end)
    W.ReorderList = realReorder
    if not ok then error(err, 0) end

    t.eq(W.ROW_BOX.HANDLE_W, 30, "the collection's gutter, read from the library")
    t.truthy(#seen >= 4, "all four call sites were exercised (" .. #seen .. ")")
    for i, opts in ipairs(seen) do
        t.eq(opts.handleSize, nil,
            "list #" .. i .. " declares no handleSize, so the library's default decides")
    end
end)

-- The Stat Priority page's four "Secondary stat #N" dropdowns became ONE list.
--
-- red under: dropping the boundary (a drag could then land an included stat in
-- the excluded tail, where its position is not stored), or making the excluded
-- rows draggable.
test("Settings: the Stat Priority secondaries are one bounded reorder list", function(t)
    local KCM = loader.loadFullAddon()
    local UI  = KCM.Settings.Helpers.instance
    local specKey = "8_262"
    KCM.Options._viewedSpec     = specKey
    KCM.Options._viewedSpecAuto = false
    KCM.db.profile.statPriority = { [specKey] = { primary = "AGI", secondary = { "HASTE", "CRIT" } } }

    local made = recordControllers(function()
        KCM.Settings.builders.statpriority({})
        local ctx = UI.__panelFor("statpriority")
        ctx.panel.IsShown = function() return true end
        KCM.Settings.Helpers.RefreshAllPanels()
    end)

    t.eq(#made, 1, "one controller over the four secondary stats")
    t.eq(made[1].boundary, 2,
        "the boundary is the number INCLUDED, so a drag cannot reach the excluded tail")
    t.eq(#made[1].rows, 4, "all four stats are rows; two of them are inert")
end)

-- The split the list is built from, driven directly: it is what decides which
-- rows are draggable and what the boundary is.
--
-- red under: keeping a stat in the included list after it was excluded, or
-- letting a duplicate through (Ranker would then weigh the same stat twice).
test("Settings: the secondary split is stored order first, then the rest", function(t)
    local KCM = loader.loadFullAddon()
    local split = KCM.Options.SplitSecondaries

    local included, excluded = split({ "MASTERY", "CRIT" })
    t.eqList(included, { "MASTERY", "CRIT" }, "the stored order is preserved exactly")
    t.eqList(excluded, { "HASTE", "VERSATILITY" }, "the rest follow in the canonical order")

    included, excluded = split({ "CRIT", "CRIT", "", "NONSENSE" })
    t.eqList(included, { "CRIT" }, "duplicates, blanks and unknown stats are dropped")
    t.eqList(excluded, { "HASTE", "MASTERY", "VERSATILITY" }, "and the rest are excluded")

    included, excluded = split(nil)
    t.eqList(included, {}, "a spec with no override ranks nothing yet")
    t.eq(#excluded, 4, "so all four stats are offered")
end)

-- ---------------------------------------------------------------------------
-- options-ui-§13 — a wrapped strip's geometry MUST NOT depend on the selection
-- ---------------------------------------------------------------------------
--
-- R4c, reproduced on this addon's two hand-drawn strips: the Macros page wraps to
-- three rows at fifteen tabs and the Macro Bar page to two at eight. The strip
-- used to record its row pitch from the FIRST tab it drew, whichever that was —
-- and the selected tab is cut from `Options_Tab_Active_*` while the rest come
-- from `Options_Tab_*`, two atlas families the client does not draw at the same
-- height. So selecting tab 1 packed the rows by one number and selecting any
-- other packed them by another, and the content panel moved under the player.
--
-- THE HARNESS HAS TO BE ABLE TO SEE IT (testing-§12). A mock that answers one
-- height for every atlas cannot fail this case, so the probe texture below
-- answers a DIFFERENT height for the selected-state art — which is the only thing
-- that makes the assertion mean anything.
--
-- red under: reading the pitch back off a tab that was just drawn (whatever its
-- state), or measuring the label under the selected font before the width is
-- taken.
local function withAtlasHeights(fn)
    local realCreate = _G.CreateFrame
    _G.CreateFrame = function(kind, name, parent, template)
        local f = realCreate(kind, name, parent, template)
        f.CreateTexture = function()
            local tex = loader.mock.makeStub()
            local h = 0
            tex.SetAtlas = function(_, atlas)
                h = tostring(atlas):find("Active", 1, true) and 33 or 28
                return tex
            end
            tex.GetHeight = function() return h end
            return tex
        end
        return f
    end
    local ok, err = pcall(fn)
    _G.CreateFrame = realCreate
    if not ok then error(err, 0) end
end

test("Settings: a wrapped strip reserves the same band whichever tab is selected",
    function(t)
        local KCM = loader.loadFullAddon()
        local UI  = KCM.Settings.Helpers.instance
        local Widgets = LibStub("LibKa0s-Options-1.0")
        -- The measurement is cached for the session, and it must be taken under
        -- the mock that can tell the two atlas families apart.
        UI.__resetTabArtHeight()

        local bands = {}
        local realChrome = UI.SetChromeHeight
        UI.SetChromeHeight = function(ctx, height)
            bands[#bands + 1] = height
            return realChrome(ctx, height)
        end

        withAtlasHeights(function()
            -- THE HARNESS FIDELITY CHECK, and the case means nothing without it
            -- (testing-§12). The measurement has to come back as the INACTIVE
            -- art's 28 -- not the selected state's 33, and not the TAB_H fallback
            -- a mock that cannot measure anything would produce.
            t.eq(UI.__tabArtHeight(), 28,
                "the strip measured the unselected art, which no click can change")
            t.ne(UI.__tabArtHeight(), UI.TAB_H,
                "…and the harness really can tell the two atlas families apart")

            for _, page in ipairs({ "macros", "macrobar" }) do
                KCM.Settings.builders[page]({})
                local ctx = UI.__panelFor(page)
                ctx.panel.IsShown = function() return true end

                -- The FIRST tab, then the second: the two states the defect told
                -- apart. Each render records the band it reserved.
                bands = {}
                local tabs = (page == "macros") and KCM.Options.MacroTabs()
                    or KCM.Settings.MACROBAR_TABS
                local firstKey  = tabs[1].key or tabs[1].group
                local secondKey = tabs[2].key or tabs[2].group

                ctx.activeTab = firstKey
                KCM.Settings.Helpers.RefreshAllPanels()
                local bandFirst = bands[#bands]

                bands = {}
                ctx.activeTab = secondKey
                KCM.Settings.Helpers.RefreshAllPanels()
                local bandSecond = bands[#bands]

                t.truthy(type(bandFirst) == "number" and bandFirst > 0,
                    page .. " reserved a band for its strip")
                t.eq(bandSecond, bandFirst,
                    page .. ": the reserved band is identical for both selections")
            end
        end)

        UI.SetChromeHeight = realChrome
        UI.__resetTabArtHeight()
        t.truthy(Widgets, "the strip under test is the library's")
    end)

-- The Master controls tab's closing BUTTON PAIR is the composer's second return
-- value, wired as that group's `afterGroup`. The group name IS the hook key, so
-- renaming the group detaches the hook and NOTHING errors — which is exactly why
-- it is asserted on the drawn buttons rather than on the wiring.
--
-- red under: dropping the `{ ["Master controls"] = masterTail }` argument, or
-- renaming the group on either side of it.
test("Settings: the Master controls tab closes with the two reset buttons", function(t)
    local KCM = loader.loadFullAddon()
    local UI  = KCM.Settings.Helpers.instance

    local texts = {}
    local realAceGUI = UI.AceGUI
    UI.AceGUI = setmetatable({
        Create = function(_, kind)
            local w = loader.mock.makeAceWidget()
            if kind == "Button" then
                w.SetText = function(self, text) texts[#texts + 1] = text; return self end
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
    ctx.activeTab = "Master controls"
    KCM.Settings.Helpers.RefreshAllPanels()

    UI.AceGUI = realAceGUI

    local seen = {}
    for _, text in ipairs(texts) do seen[text] = true end
    t.truthy(seen["Reset position"], "the pair's left half is Reset position")
    t.truthy(seen["Reset all settings"], "and its right half is the global reset")
    -- The Maintenance tab's buttons are NOT drawn while Master controls is the
    -- active tab: only the active tab's body draws (options-ui-§13).
    t.falsy(seen[KCM.L["Force resync"]], "the other tab's buttons stay off screen")
end)
