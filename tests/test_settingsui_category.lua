-- test_settingsui_category.lua — the Macros page's own controls: the shared
-- category reset popup and the Add-by-ID line (settings/Category.lua,
-- settings/CategoryAddByID.lua), and the #35 characterization of the Stat
-- Priority and composite panel writers.
--
-- Peeled out of tests/test_settingsui.lua (1440) for layout-§1's 1000-1500 band
-- (CM-ATS-02, ATS-14), beside the #33 cut (tests/test_settingsui_optionsui.lua).
-- The seam is two of the parent's sections, each with its own fixtures
-- (`loadCategorySettings`, the add-by-ID renderers; `categoryWithCheckboxSpy`,
-- `recordSets`), neither reading the page-strip or refresh-debounce helpers
-- that stay behind. Every case moved whole: not one assertion changed.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

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

-- Every path the write seam is asked to write (tests/run.lua's spy).
local function recordSets(KCM)
    return (h.loader.spySeamWrites(KCM))
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
