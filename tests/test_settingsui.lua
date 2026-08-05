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
        -- `L` is lib.LAYOUT, which is also why LIBKA0S-05 had to accept the
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
        -- Loaded for real with libs/LibKa0s/ omitted, so settings/Panel.lua
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

test("Settings UI: with the library absent Helpers still reaches both refresh tiers",
    function(t)
        -- The gap the copy-across left. `Helpers.RefreshAllPanels = UI and
        -- UI.RefreshAllPanels` binds nil when UI is nil, and both call sites
        -- call the field BARE. Reproduced as
        -- "attempt to call field 'RefreshAllPanels' (a nil value)".
        --
        -- red under: rebinding either name to `UI and UI.<name>`, or dropping
        -- the degraded no-op arm at the optionsLib seam in settings/Panel.lua.
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
        H.Set("enabled", true)

        local ok, res = pcall(H.SetAndRefresh, "enabled", false)
        t.truthy(ok, "the write does not raise: " .. tostring(res))
        t.eq(res, true, "and it reports the success that actually happened")
        t.eq(KCM.db.profile.enabled, false, "the value landed in the profile")

        -- And the validation half degrades identically: no library, same answer.
        t.eq(H.SetAndRefresh("enabled", "yes please"), false,
            "a wrong-typed write is still rejected with the library absent")
        t.eq(H.SetAndRefresh("enabled", nil), false,
            "and an explicit nil still cannot delete the key")
        t.eq(KCM.db.profile.enabled, false, "neither rejected write moved the value")
    end)

test("Settings UI: Helpers reads the library's members off the instance, not off a copy",
    function(t)
        -- CM-A-04: Helpers used to re-export eleven members by hand, so any
        -- member the list forgot read back nil at the call site with no way to
        -- tell it apart from one the library never had. It delegates now, so
        -- EVERY member the instance publishes is reachable and is the same
        -- function object.
        --
        -- red under: deleting the setmetatable at the optionsLib seam, or
        -- reinstating a per-member copy that a library rename can outrun.
        local KCM = loader.loadWithSchema()
        local H   = KCM.Settings.Helpers
        local UI  = H.instance
        t.truthy(UI, "the instance is published")
        for _, name in ipairs({
            "AttachTooltip", "EnsureScroll", "PatchAlwaysShowScrollbar",
            "SetRenderer", "AddSpacer", "RenderField",
            "RefreshAllPanels", "RefreshScalars",
        }) do
            t.eq(rawget(H, name), nil, name .. " is not copied onto Helpers")
            t.eq(H[name], UI[name], name .. " resolves to the instance's own function")
        end

        -- The wrappers stay OWN keys and shadow the library's same-named member
        -- — which is the only reason each can call the instance's version
        -- without recursing into itself.
        for _, name in ipairs({ "CreatePanel", "Section", "LSMValues" }) do
            t.truthy(rawget(H, name), name .. " is the addon's own wrapper")
            t.falsy(rawget(H, name) == UI[name], name .. " shadows the library's")
        end
    end)

-- ── the Battle Rez mouseover toggle (settings/Category.lua) ────────────────
--
-- The mock's Blizzard `Settings` global answers every call with a no-op
-- returning nil (wow_mock.lua), so KCM.Settings.Register()'s registerPanel()
-- cannot run headlessly here — `Settings.RegisterCanvasLayoutCategory(...)`
-- would hand back nil and the next line's `main:GetID()` would raise. This
-- suite already has the workaround: skip straight to the per-tab builder
-- KCM.Settings.RegisterTab parked in KCM.Settings.builders, and pull the ctx
-- it built back out of the library's own registry via UI.__panelFor (the same
-- accessor "a panel comes from the library's registry" above relies on).
--
-- settings/Category.lua resolves `local AceGUI = LibStub("AceGUI-3.0")` ONCE
-- at module load, so a spy installed after loadWithSchema() would miss every
-- AceGUI:Create call the file makes — the swap has to bracket the file's own
-- load, mirroring tests/test_widgets.lua's loadWidgets().
test("Settings: a targeted category page offers the mouseover toggle, bound to bucket.mouseover",
    function(t)
        local mock = loader.mock

        local files = {}
        for _, f in ipairs(loader.PURE_LAYER) do files[#files + 1] = f end
        files[#files + 1] = "settings/Panel.lua"
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

        local battleRezBuilder = KCM.Settings.builders["battle_rez"]
        t.truthy(battleRezBuilder, "Battle Rez tab registered a builder")
        battleRezBuilder({})
        local ctx = UI.__panelFor("battle_rez")
        t.truthy(ctx, "the Battle Rez ctx landed in the library's registry")
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

        -- Stop the Battle Rez page from re-rendering into the reset list below.
        ctx.panel.IsShown = function() return false end

        checkboxes = {}
        local bloodlustBuilder = KCM.Settings.builders["bloodlust"]
        t.truthy(bloodlustBuilder, "Bloodlust tab registered a builder")
        bloodlustBuilder({})
        local blCtx = UI.__panelFor("bloodlust")
        t.truthy(blCtx, "the Bloodlust ctx landed in the library's registry")
        blCtx.panel.IsShown = function() return true end

        H.RefreshAllPanels()
        t.eq(#checkboxes, 0, "an untargeted category page renders no mouseover checkbox")
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
    files[#files + 1] = "settings/Panel.lua"
    files[#files + 1] = "settings/Category.lua"
    return loader.loadFiles(files)
end

-- Render one category page and hand back every EditBox the renderer built.
--
-- Create is patched on the mock's own AceGUI table rather than behind a LibStub
-- swap: settings/Panel.lua and settings/Category.lua both captured that table at
-- load, so patching it in place is what puts the library's Section/Label helpers
-- and the category renderer on the same stub. `label`/`editbox` are set to a
-- real `false` because the widget helpers probe those sub-frames before using
-- them, and the permissive stub would otherwise hand back a function to index.
local function renderCategoryEditBoxes(KCM, pageKey)
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
    KCM.Settings.builders[pageKey]({})
    local ctx = UI.__panelFor(pageKey)
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

    local eb = renderCategoryEditBoxes(KCM, "hp_pot")[1]
    t.truthy(eb and eb._callbacks.OnEnterPressed, "the add-by-ID field is wired to Enter")
    local submit = function(text) eb._callbacks.OnEnterPressed(eb, "OnEnterPressed", text) end

    local function lastSaid()
        return mock.output[#mock.output]
    end

    submit("abc")
    t.truthy(lastSaid():find("expected a positive numeric ID; got: abc", 1, true),
        "non-numeric input is named back to the user")
    submit("0")
    t.truthy(lastSaid():find("expected a positive numeric ID; got: 0", 1, true),
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
end)

test("Settings: add-by-ID refuses a spec-aware category with no resolvable spec", function(t)
    local KCM = loadCategorySettings()
    local mock = loader.mock
    mock.setItem(960011, { name = "Test Flask", subType = "Flasks & Phials" })

    -- settings/StatPriority.lua is not loaded here, so O.ResolveViewedSpec is
    -- absent and FLASK renders with no viewed spec — the same state a
    -- sub-level-10 character sees.
    t.falsy(KCM.Options.ResolveViewedSpec, "no viewed-spec resolver in this file set")

    local eb = renderCategoryEditBoxes(KCM, "flask")[1]
    t.truthy(eb and eb._callbacks.OnEnterPressed, "the add-by-ID field rendered anyway")
    eb._callbacks.OnEnterPressed(eb, "OnEnterPressed", "960011")

    t.truthy(mock.output[#mock.output]:find("spec-aware category: no active spec", 1, true),
        "the ID is valid, but there is nowhere to put it and the user is told")
end)
