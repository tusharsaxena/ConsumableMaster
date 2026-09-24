-- tests/test_settingsui_optionsui.lua — the options-ui conformance half of the
-- settings suite: the three blocks that fail when a CLAUSE OF THE STANDARD stops
-- holding, rather than when this addon's own wiring breaks.
--
-- §13, EVERY page draws a strip. §18, the reorder lists. §13 again, a wrapped
-- strip's geometry MUST NOT depend on the selection.
--
-- Peeled out of tests/test_settingsui.lua at the seam issue #33 named, which the
-- cap census in docs/ARCHITECTURE.md carried. The partition is also the one a
-- reader wants: what stays in tests/test_settingsui.lua goes red when this
-- addon's settings wiring breaks, and this file goes red when a standard clause
-- does. Those are two different people's problems on two different days.
--
-- All four of the block's fixtures — renderEveryPage, recordControllers,
-- showMacroTab, withAtlasHeights — moved with it, because each is defined and
-- read only inside it. Every case moved whole: not one assertion changed.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

-- ---------------------------------------------------------------------------
-- options-ui-§13 — EVERY page draws a strip
-- ---------------------------------------------------------------------------
--
-- Not a size threshold and not a choice: a Ka0s page has a strip, so a player who
-- has learned one page has learned all of them. The only exemptions are pages the
-- host does not render through the flow engine at all, and there are two: the
-- AceConfig-drawn Profiles sub-page (settings/Profiles.lua), which AceConfigDialog
-- draws whole, and the landing page, whose body is Helpers.BuildAboutContent. The
-- landing page is not in KCM.Settings.order, so of the two only Profiles needs
-- naming below -- and it is asserted to draw NO strip, not merely skipped.
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
                -- Off screen again before the next page, or the next refresh re-renders
                -- this one too and records its strip under the next page's key -- which
                -- is what a page that draws NO strip would otherwise inherit.
                ctx.panel.IsShown = function() return false end
            end
        end
    end

    UI.TabStrip = realTabStrip
    return drawn
end

-- The §13 exemption, as it applies to KCM.Settings.order: the one page in it that
-- the host does not draw through the flow engine.
local STRIP_EXEMPT = { profiles = true }

-- red under: returning early from any page's render before the strip is drawn,
-- renaming the General page's first tab, or drawing a strip over the Profiles
-- page's AceConfigDialog tree.
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
            if STRIP_EXEMPT[key] then
                t.eq(spec, nil, "the '" .. key .. "' page is exempt and draws no strip")
            else
                t.truthy(spec and spec.tabs and #spec.tabs > 0,
                    "the '" .. key .. "' page drew a strip")
                t.eq(spec and spec.tabs[1] and spec.tabs[1].key, FIRST[key],
                    "…whose first tab is " .. FIRST[key])
            end
        end
        t.truthy(KCM.Settings.builders.profiles,
            "the exempt page is really in the order, so the exemption is exercised")

        t.eq(#drawn.general.tabs, 2,
            "General is Master controls plus Maintenance, one tab each")
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
--- many times each was canceled.
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
        -- The SPECS the host hands the library, kept verbatim. The row objects
        -- the controller builds do not carry `parent` back, and where the box is
        -- parented is a host decision -- so this is the only place a case can see
        -- it without reading the library's internals.
        local realAddRow = list.AddRow
        list.__specs = {}
        list.AddRow = function(self, frame, spec)
            self.__specs[#self.__specs + 1] = spec or {}
            return realAddRow(self, frame, spec)
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

-- Every Macros tab explains its own glyphs. The single-category tabs always
-- carried the key; the composite ones carried none, so a player who had not
-- opened Food first met a red cross beside Healthstone with nothing on the page
-- saying what it meant.
--
-- The composite key is the TWO swatches and not three: a composite row draws no
-- pick star (renderCompositeRow passes isPick = false), and a key naming a glyph
-- that cannot appear on the page it heads teaches the wrong thing.
--
-- red under: dropping the renderCompositeLegend call, or widening it to the
-- three-glyph single-category line.
test("Settings: an AIO tab explains its own in-bags / not-in-bags glyphs", function(t)
    local KCM = loader.loadFullAddon()
    local AceGUI = LibStub("AceGUI-3.0")
    local before = #AceGUI.__created
    showMacroTab(KCM, "HP_AIO")

    local body = {}
    for i = before + 1, #AceGUI.__created do
        local w = AceGUI.__created[i]
        if type(w.__text) == "string" then body[#body + 1] = w.__text end
    end
    body = table.concat(body, "\n")

    t.truthy(body:find("in bags", 1, true), "the composite tab draws the glyph key")
    t.truthy(body:find("not in bags", 1, true), "both swatches are named")
    t.falsy(body:find("picked", 1, true),
        "and the star is NOT named -- a composite row never draws one")
end)

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
                "controller #" .. i .. " from the previous render was canceled")
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
        KCM.Settings.builders.macrobar({})   -- the Macro Bar page's Buttons list
        local bar = UI.__panelFor("macrobar")
        bar.panel.IsShown = function() return true end
        bar.activeTab = "Buttons"
        KCM.Settings.Helpers.RefreshAllPanels()
    end)
    W.ReorderList = realReorder
    if not ok then error(err, 0) end

    t.eq(W.ROW_BOX.HANDLE_W, 30, "the collection's gutter, read from the library")
    t.truthy(#seen >= 5, "all five call sites were exercised (" .. #seen .. ")")
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

-- The secondary rows are MultiMeters-shaped (options-ui-§8, §18): a bounded box
-- behind the WHOLE row, and a stride wider than the box so consecutive rows do
-- not touch.
--
-- The box's parent was the 30px handle SLOT, so the library drew its fill and its
-- 1px edge around the handle alone and the row itself had no background at all --
-- which is what made this list look unlike every other draggable list in the
-- collection. `spec.parent` defaults to the frame the row was registered with, so
-- the fix is to stop overriding it.
--
-- red under: passing the handle slot as the box's parent again, or setting the
-- stride equal to the row height (which closes the gap between rows).
test("Settings: a secondary stat row is boxed full-width and spaced from the next",
    function(t)
        local KCM = loader.loadFullAddon()
        local UI  = KCM.Settings.Helpers.instance
        local specKey = "8_262"
        KCM.Options._viewedSpec     = specKey
        KCM.Options._viewedSpecAuto = false
        KCM.db.profile.statPriority = { [specKey] = { primary = "AGI", secondary = { "HASTE" } } }

        local made = recordControllers(function()
            KCM.Settings.builders.statpriority({})
            local ctx = UI.__panelFor("statpriority")
            ctx.panel.IsShown = function() return true end
            KCM.Settings.Helpers.RefreshAllPanels()
        end)

        local list = made[1]
        t.truthy(list, "the page built its controller")
        t.eq(#list.__specs, 4, "one registered row per secondary stat")
        for i, spec in ipairs(list.__specs) do
            t.eq(spec.parent, nil,
                "row " .. i .. " must let the box default to the ROW frame; naming the " ..
                "handle's slot draws the box around the gutter and leaves the row bare")
            t.truthy(spec.height and list.stride > spec.height,
                "row " .. i .. ": the stride must exceed the row height, or rows touch (" ..
                tostring(list.stride) .. " vs " .. tostring(spec.height) .. ")")
        end
    end)

-- The SAME row shape on the Macros page, both flavors of it: the per-category
-- priority list and the two composite sections. They had the identical defect the
-- Stat Priority list had -- the box parented to the handle's 30px slot, so the
-- library drew its fill and 1px edge around the gutter and the row itself was
-- bare -- and they are the same control, so they must read the same.
--
-- red under: restoring `parent = slot.frame` on either renderer, or setting
-- either stride back to the row height (which closes the gap between rows).
test("Settings: every draggable row on the Macros page is boxed full-width and spaced",
    function(t)
        local KCM = loader.loadFullAddon()

        for _, catKey in ipairs({ "FOOD", "HP_AIO" }) do
            local made = recordControllers(function() showMacroTab(KCM, catKey) end)
            local registered = 0
            for _, list in ipairs(made) do
                for i, spec in ipairs(list.__specs) do
                    registered = registered + 1
                    t.eq(spec.parent, nil, catKey .. " row " .. i ..
                        ": the box must default to the ROW frame, not the handle's gutter")
                    t.truthy(spec.height and list.stride > spec.height,
                        catKey .. " row " .. i .. ": the stride must exceed the row height (" ..
                        tostring(list.stride) .. " vs " .. tostring(spec.height) .. ")")
                end
            end
            t.truthy(registered > 0, catKey .. " registered no rows at all")
        end
    end)

-- The Include CHECKBOX became a tick/cross glyph you click, the same two textures
-- MultiMeters wears on its column blocks -- one glyph vocabulary for a player who
-- runs both. A checkbox labeled "Include" spent a third of the row saying what
-- the tick already says.
--
-- red under: wiring the glyph's OnClick to nothing (a control that looks like a
-- toggle and toggles nothing is the failure a texture assertion cannot see), or
-- reading the stat off an upvalue captured when the row was built rather than off
-- the row at fire time.
test("Settings: clicking a secondary stat's glyph toggles whether it is ranked",
    function(t)
        local KCM = loader.loadFullAddon()
        local UI  = KCM.Settings.Helpers.instance
        local specKey = "8_262"
        KCM.Options._viewedSpec     = specKey
        KCM.Options._viewedSpecAuto = false
        KCM.db.profile.statPriority = { [specKey] = { primary = "AGI", secondary = { "HASTE", "CRIT" } } }

        KCM.Settings.builders.statpriority({})
        local ctx = UI.__panelFor("statpriority")
        ctx.panel.IsShown = function() return true end
        KCM.Settings.Helpers.RefreshAllPanels()

        local rows = ctx.kcmStatRows
        t.truthy(rows and #rows == 4, "one row per secondary stat")
        t.eq(rows[1].kcmStat, "HASTE", "the included stats come first, in stored order")

        rows[1].kcmGlyph:_run("OnClick")
        t.eqList(KCM.db.profile.statPriority[specKey].secondary, { "CRIT" },
            "clicking a ranked stat's tick drops it out of the ranking")

        -- And back on. An excluded stat joins the END of the order, because its
        -- position while excluded is not stored and inventing one would be data
        -- nobody entered.
        rows = ctx.kcmStatRows
        local haste
        for _, row in ipairs(rows) do if row.kcmStat == "HASTE" then haste = row end end
        t.truthy(haste, "HASTE is still a row, in the excluded tail")
        haste.kcmGlyph:_run("OnClick")
        t.eqList(KCM.db.profile.statPriority[specKey].secondary, { "CRIT", "HASTE" },
            "and it comes back at the end of the order")
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
            local height = 0
            tex.SetAtlas = function(_, atlas)
                height = tostring(atlas):find("Active", 1, true) and 33 or 28
                return tex
            end
            tex.GetHeight = function() return height end
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
    -- The Maintenance subsection's three buttons are NOT visible from here, and
    -- that is a property of this harness rather than of the page: they are drawn
    -- by settings/Panel.lua's own Button / ButtonPair, which hold AceGUI as a
    -- file-local captured at load, so swapping UI.AceGUI cannot see them. The
    -- case below reads them off the mock factory instead.
end)

-- options-ui-§12's SHOULD: the Reset all settings tooltip names the equivalence,
-- "the same thing Profiles → Reset Profile does", rather than restating the popup.
-- The button is the library composer's, and since LibKa0s-Options-1.0 minor 18 its
-- tooltip follows the Options descriptor: `resetProfile` makes it a profile reset,
-- and `profilesPage` says this addon ships the page the text points at. Read off
-- the drawn button's OnEnter, which is the only place AttachTooltip puts it.
--
-- red under: a descriptor without `resetProfile` ("Restore every setting in this
-- addon to its default.") or without `profilesPage` (the Profiles page unnamed).
test("Settings: the Reset all settings tooltip names Profiles → Reset Profile", function(t)
    local KCM = loader.loadFullAddon()
    local UI  = KCM.Settings.Helpers.instance

    local buttons = {}
    local realAceGUI = UI.AceGUI
    UI.AceGUI = setmetatable({
        Create = function(_, kind)
            local w = loader.mock.makeAceWidget()
            if kind == "Button" then
                local callbacks = {}
                w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
                buttons[#buttons + 1] = { widget = w, callbacks = callbacks }
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

    local reset
    for _, b in ipairs(buttons) do
        if rawget(b.widget, "__text") == "Reset all settings" then reset = b end
    end
    t.truthy(reset and reset.callbacks.OnEnter, "the button is drawn, with a tooltip")

    local lines, tip = {}, _G.GameTooltip
    local saved = rawget(tip, "AddLine")
    rawset(tip, "AddLine", function(_, text) lines[#lines + 1] = text end)
    local ok, err = pcall(reset.callbacks.OnEnter)
    rawset(tip, "AddLine", saved)
    t.truthy(ok, tostring(err))
    t.eq(lines[1], "Reset the current profile to its defaults — the same thing "
        .. "Profiles -> Reset Profile does. Your other profiles are not affected.",
        "the tooltip names the equivalence and the blast radius")
end)

-- CM-11 (ConsumableMaster-R-08): one global reset act, one popup. The panel
-- door used to raise its own KCM_RESET_ALL, whose handler carried the combat
-- guard and the repaint the slash door's KCM_CONFIRM_RESET lacked. Both now live
-- in KCM.ResetAllToDefaults and both doors raise the same dialog.
--
-- red under: onResetAll raising any other popup, or KCM_RESET_ALL coming back.
test("Settings: the panel's Reset all settings raises the same popup as /cm resetall",
    function(t)
        local KCM = loader.loadFullAddon()
        local UI  = KCM.Settings.Helpers.instance

        local buttons = {}
        local realAceGUI = UI.AceGUI
        UI.AceGUI = setmetatable({
            Create = function(_, kind)
                local w = loader.mock.makeAceWidget()
                if kind == "Button" then
                    local callbacks = {}
                    w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
                    buttons[#buttons + 1] = { widget = w, callbacks = callbacks }
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

        local reset
        for _, b in ipairs(buttons) do
            if rawget(b.widget, "__text") == "Reset all settings" then reset = b end
        end
        t.truthy(reset and reset.callbacks.OnClick, "the button is drawn with a click handler")

        local shown
        local saved = _G.StaticPopup_Show
        _G.StaticPopup_Show = function(which) shown = which end
        local ok, err = pcall(reset.callbacks.OnClick)
        _G.StaticPopup_Show = saved
        t.truthy(ok, tostring(err))
        t.eq(shown, "KCM_CONFIRM_RESET", "the panel door raises the slash door's popup")
        t.eq(StaticPopupDialogs["KCM_RESET_ALL"], nil, "and the duplicate popup is gone")
    end)

-- The Maintenance TAB is back, by the owner's call on 2026-09-09. It was folded
-- into Master controls as a subsection on the reasoning that a whole tab over
-- three monthly buttons cost a click; from inside the panel the trade reads the
-- other way, because Master controls is the tab everybody opens and three
-- destructive-ish acts hanging off its bottom are three things a player did not
-- come for.
--
-- Permitted where the canonical set is not: §15 forbids reordering, renaming or
-- splitting THAT set across tabs, and these three were never in it. Master
-- controls stays first, which §15 does require.
--
-- Read off the mock AceGUI's creation log rather than a stub, because these
-- three are HOST-drawn — see the note above.
--
-- red under: folding the three back under Master controls, dropping the
-- Maintenance tab from TABS, or renaming a button.
test("Settings: the three maintenance verbs draw on their own tab", function(t)
    local KCM = loader.loadFullAddon()
    local AceGUI = LibStub("AceGUI-3.0")
    local before = #AceGUI.__created

    KCM.Settings.builders.general({})
    local ctx = KCM.Settings.Helpers.instance.__panelFor("general")
    ctx.panel.IsShown = function() return true end
    ctx.activeTab = "Maintenance"
    KCM.Settings.Helpers.RefreshAllPanels()

    local seen = {}
    for i = before + 1, #AceGUI.__created do
        local w = AceGUI.__created[i]
        if w.__text then seen[w.__text] = true end
    end
    t.truthy(seen[KCM.L["Force resync"]], "Force resync is on the Maintenance tab")
    t.truthy(seen[KCM.L["Force rewrite macros"]], "so is Force rewrite macros")
    t.truthy(seen[KCM.L["Reset all priorities"]], "and so is Reset all priorities")
end)

-- ── the combat gate on category registration (events-frames-taint) ─────────
--
-- `Settings.RegisterAddOnCategory` is protected. The bootstrap frame at the
-- foot of settings/Panel.lua fires registerPanel from PLAYER_LOGIN and from
-- ADDON_LOADED("Blizzard_Settings"), and neither normally lands mid-fight —
-- but another addon calling C_AddOns.LoadAddOn("Blizzard_Settings") during a
-- pull does, and so does an in-combat /reload. One tainted category poisons
-- the Settings window for the rest of the session.
--
-- The park and its replay are LibKa0s-Options-1.0's (minor 24): registerPanel
-- hands the request to UI.CreateOptionsPanel, which under lockdown registers
-- nothing and replays itself on a library-private PLAYER_REGEN_ENABLED frame.
-- These cases are the headless half. The taint itself is invisible here — no
-- mock raises "Interface action failed because of an AddOn" — so what is pinned
-- is the observable half: nothing registers under lockdown, the end of combat
-- registers it exactly once, and it does so whatever the addon's stand-down
-- state. docs/smoke-tests.md § 6a owns the in-client half.

--- A `Settings` whose category calls answer and are counted. The mock's own
--- answers nil from every member, which a real registration cannot get past.
local function countRegistrations()
    local seen = { addon = 0 }
    rawset(_G.Settings, "RegisterCanvasLayoutCategory", function()
        return { GetID = function() return 7 end }
    end)
    rawset(_G.Settings, "RegisterAddOnCategory", function() seen.addon = seen.addon + 1 end)
    return seen
end

--- Record which frames created from here on are registered for which events.
--- The repo's frame stub swallows RegisterEvent, so without this "fire the event
--- at every frame listening for it" has no listener set to read.
local function trackFrames()
    local tracked = {}
    local realCreate = _G.CreateFrame
    _G.CreateFrame = function(...)
        local f = realCreate(...)
        local events = {}
        rawset(f, "__events", events)
        rawset(f, "RegisterEvent", function(self, e) events[e] = true; return self end)
        rawset(f, "UnregisterEvent", function(self, e) events[e] = nil; return self end)
        rawset(f, "UnregisterAllEvents", function(self)
            for k in pairs(events) do events[k] = nil end
            return self
        end)
        tracked[#tracked + 1] = f
        return f
    end
    return tracked
end

--- PLAYER_REGEN_ENABLED, fired at every listener there is: the addon's own
--- AceEvent registrations (the kit's live set) and every tracked frame still
--- registered for it.
local function fireRegen(tracked)
    loader.mock.base.__fire("PLAYER_REGEN_ENABLED")
    for _, f in ipairs(tracked) do
        if f.__events.PLAYER_REGEN_ENABLED then f:_run("OnEvent", "PLAYER_REGEN_ENABLED") end
    end
end

--- An enabled addon (OnEnable run, as tests/test_disabled.lua's build does),
--- counting category registrations and tracking frames.
local function enabledAddon()
    local KCM = loader.loadFullAddon()
    KCM:OnEnable()
    local tracked = trackFrames()
    return KCM, countRegistrations(), tracked
end

-- red under: dropping the library's InCombatLockdown park, or a host that
-- re-parks (a second queued replay) on a second Register in the same combat.
test("Settings: registering the category in combat is refused and parked", function(t)
    local KCM, seen = enabledAddon()
    loader.mock.setCombat(true)
    KCM.Settings.Register()
    KCM.Settings.Register()
    loader.mock.setCombat(false)
    t.eq(seen.addon, 0, "no Blizzard category is registered under lockdown")
    local lib = LibStub("LibKa0s-Options-1.0")
    t.eq(#lib.__parkedPanels, 1, "one parked replay: a second Register while parked is a no-op")
end)

-- red under: a replay that re-arms itself, or a park that never listens for regen.
test("Settings: leaving combat replays the parked registration, and only then", function(t)
    local KCM, seen, tracked = enabledAddon()
    loader.mock.setCombat(true)
    KCM.Settings.Register()
    loader.mock.setCombat(false)
    t.eq(seen.addon, 0, "nothing before regen")

    fireRegen(tracked)
    t.eq(seen.addon, 1, "the end of combat registers the category once")

    fireRegen(tracked)
    t.eq(seen.addon, 1, "and a second regen does not re-enter registration")
end)

-- ConsumableMaster-R-03: slash-commands-§7 names the settings-category
-- registration as SETUP that survives a stand-down. The host's own replay lived
-- at the end of OnRegenEnabled, after the stood-down early return, so a park
-- taken while disabled was lost for the session, with the Enable checkbox in it.
--
-- red under: the replay living only in the host's OnRegenEnabled
test("Settings: a registration parked while the addon is stood down still registers on regen",
    function(t)
        local KCM, seen, tracked = enabledAddon()
        KCM.Settings.Helpers.SetAndRefresh("enabled", false)
        loader.mock.setCombat(true)
        KCM.Settings.Register()
        loader.mock.setCombat(false)
        fireRegen(tracked)
        t.eq(seen.addon, 1, "the category registers although the addon is disabled")
    end)

-- The same, with the stand-down itself taken IN combat: the addon then holds its
-- one sanctioned PLAYER_REGEN_ENABLED registration, and its handler returns on
-- the stood-down branch.
--
-- red under: the replay living only in the host's OnRegenEnabled
test("Settings: a registration parked by a stand-down in combat still registers on regen",
    function(t)
        local KCM, seen, tracked = enabledAddon()
        loader.mock.setCombat(true)
        KCM.Settings.Helpers.SetAndRefresh("enabled", false)
        KCM.Settings.Register()
        loader.mock.setCombat(false)
        fireRegen(tracked)
        t.eq(seen.addon, 1, "the category registers although the addon stood down mid-fight")
    end)

-- options-ui-§2: opening is refused outright in combat, in the library's words,
-- once. The gate is UI.OpenOptionsPanel's; KCM.Options.Open only reports it.
--
-- red under: a host notice printed beside the library's, or a host that
-- answers the refusal with 'settings panel unavailable'.
test("Settings: /cm config in combat answers false and prints the library's refusal once",
    function(t)
        local KCM = enabledAddon()
        KCM.Settings.Register()
        local refused = LibStub("LibKa0s-Options-1.0").STRINGS.COMBAT_REFUSED
        loader.mock.output = {}
        loader.mock.setCombat(true)
        local answer = KCM.Options.Open()
        loader.mock.setCombat(false)
        t.eq(answer, false, "the open is refused")
        local hits, other = 0, 0
        for _, line in ipairs(loader.mock.output) do
            if line:find(refused, 1, true) then hits = hits + 1 else other = other + 1 end
        end
        t.eq(hits, 1, "the library's COMBAT_REFUSED line, exactly once")
        t.eq(other, 0, "and nothing else is said")
    end)
