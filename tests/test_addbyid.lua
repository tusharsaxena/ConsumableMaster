-- test_addbyid.lua — the Add-by-ID line's suggestions, and names it can reach beyond the bags.
--
-- The client has no item-name search. C_Item.GetItemInfoInstant(name) answers only for an item
-- the player carries or carried this session, so the owner's "Potion of the Hushed Zephyr" (three
-- crafted-quality ranks, none in the bags) read "No item matches". LibKa0s v1.35.0's IdInput
-- takes `candidates` -- the ids the host already knows -- and resolves a name against them, and
-- it lists matching entries under the box as the player types, every rank its own row. Enter on a
-- name several ranks share, with no row picked, is still refused: never one rank added silently,
-- and never all of them.
--
-- A suite of its own rather than more cases in tests/test_settingsui.lua, which is over
-- layout-§1's cap. The render helper is that suite's, plus the dropdown: a frame of the library's
-- rather than an AceGUI widget, found among the frames CreateFrame hands out once the page is
-- drawn (the one carrying `rows`). This harness's frame stub answers every method, so Show, Hide
-- and IsShown are recorded on those frames to see what the player would.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader

local ZEPHYR = "Potion of the Hushed Zephyr"
local ZEPHYR_IDS = { 191393, 191394, 191395 }

local function loadCategorySettings()
    local files = {}
    for _, f in ipairs(loader.PURE_LAYER) do files[#files + 1] = f end
    for _, f in ipairs(loader.SETTINGS_SEAM) do files[#files + 1] = f end
    files[#files + 1] = "settings/Category.lua"
    return loader.loadFiles(files)
end

--- An AceGUI widget stub that records its text, its label and its callbacks.
local function recordingWidget(mock, kind)
    local w = mock.makeStub()
    w.label, w.editbox = false, false
    w._kind = kind
    local callbacks = {}
    w.SetCallback = function(self, event, fn) callbacks[event] = fn; return self end
    w._callbacks = callbacks
    w.SetText = function(self, v) self._text = v; return self end
    w.GetText = function(self) return self._text end
    w.SetLabel = function(self, v) self._label = v; return self end
    return w
end

--- From here on every frame CreateFrame hands out records whether it is shown.
local function recordFrames()
    local frames = {}
    local real = _G.CreateFrame
    _G.CreateFrame = function(...)
        local f = real(...)
        rawset(f, "Show", function(self) rawset(self, "_shown", true) end)
        rawset(f, "Hide", function(self) rawset(self, "_shown", false) end)
        rawset(f, "IsShown", function(self) return rawget(self, "_shown") == true end)
        frames[#frames + 1] = f
        return f
    end
    return frames
end

--- Render `catKey`'s tab and hand back its Add-by-ID line: the Type dropdown, the edit box, the
--- Add button and the status line, plus drivers for typing, submitting and picking.
local function renderLine(KCM, catKey)
    local mock = loader.mock
    local made = {}
    LibStub("AceGUI-3.0").Create = function(_, kind)
        local w = recordingWidget(mock, kind)
        made[#made + 1] = w
        return w
    end
    KCM.Settings.builders["macros"]({})
    local ctx = KCM.Settings.Helpers.instance.__panelFor("macros")
    KCM.Options.SetMacroTab(catKey)
    ctx.panel.IsShown = function() return true end
    KCM.Settings.Helpers.RefreshAllPanels()

    local line = { made = made, frames = recordFrames() }
    for i, w in ipairs(made) do
        if w._kind == "Dropdown" and not line.edit then line.type = w end
        if w._kind == "EditBox" then
            line.edit, line.add, line.status = w, made[i + 1], made[i + 2]
            break
        end
    end
    --- Type into the box as AceGUI reports it. This harness's C_Timer runs at once, so the
    --- debounce has already run when this returns.
    function line.typeText(text)
        line.edit._text = text
        line.edit._callbacks.OnTextChanged(line.edit, "OnTextChanged", text)
    end
    function line.submit(text)
        line.edit._text = text
        line.edit._callbacks.OnEnterPressed(line.edit, "OnEnterPressed", text)
    end
    function line.dropdown()
        for _, f in ipairs(line.frames) do
            if type(rawget(f, "rows")) == "table" then return f end
        end
    end
    --- The rows the dropdown shows, in order; none while it is hidden.
    function line.rows()
        local dd, out = line.dropdown(), {}
        if not (dd and dd:IsShown()) then return out end
        for _, row in ipairs(dd.rows) do
            if row:IsShown() and row.entry then out[#out + 1] = row end
        end
        return out
    end
    function line.shownIds()
        local ids = {}
        for _, row in ipairs(line.rows()) do ids[#ids + 1] = row.entry.id end
        return table.concat(ids, ",")
    end
    --- Click the row carrying `id`.
    function line.pick(id)
        for _, row in ipairs(line.rows()) do
            if row.entry.id == id then return row:GetScript("OnClick")(row) end
        end
        error("no suggestion row carries " .. tostring(id))
    end
    return line
end

--- Selector.AddItem replaced by a recorder of every call, in order.
local function recordAdds(KCM)
    local added = {}
    KCM.Selector.AddItem = function(_, id) added[#added + 1] = id; return true end
    return added
end

--- The client forgets the name `id` answers to: GetItemInfoInstant(name) no longer finds it, as
--- for an item the player has not carried this session. Its id still answers.
local function forgetName(kind, id)
    loader.mock.ids.__idRecords[kind][id] = nil
end

--- `ids` become this category's candidates, as auto-discovery would file them.
local function discover(KCM, catKey, ids)
    local bucket = KCM.Selector.GetBucket(catKey)
    for _, id in ipairs(ids) do bucket.discovered[id] = 1 end
end

--- The owner's case: three ranks of one name, none carried, all known to HP_POT.
local function seedZephyr(KCM)
    for _, id in ipairs(ZEPHYR_IDS) do
        loader.mock.setItem(id, { name = ZEPHYR, subType = "Potions" })
        forgetName("item", id)
    end
    discover(KCM, "HP_POT", ZEPHYR_IDS)
end

test("Add-by-ID: typing lists the category's candidates, every rank of a shared name its own row",
    function(t)
        -- red under: IdInput handed no candidates, or a host kind with no `info` (no list at all)
        local KCM = loadCategorySettings()
        seedZephyr(KCM)
        -- Known to the client but not to this category: a host kind lists its candidates alone.
        loader.mock.setItem(960030, { name = "Hushed Tea", subType = "Food & Drink" })
        local line = renderLine(KCM, "HP_POT")

        line.typeText("hushed")
        t.eq(line.shownIds(), "191393,191394,191395", "the three ranks, and nothing else")
        for _, row in ipairs(line.rows()) do
            local label = row.labelText or ""
            t.truthy(label:find(ZEPHYR, 1, true) and label:find("(" .. row.entry.id .. ")", 1, true),
                "each rank's row names it and tells it apart by its id ('" .. label .. "')")
        end
    end)

test("Add-by-ID: a name the client cannot look up resolves through the category's candidates",
    function(t)
        -- red under: resolveAddByID calling H.ResolveId with no candidates ("No item matches")
        local KCM = loadCategorySettings()
        loader.mock.setItem(960040, { name = "Elixir of Quiet Waters", subType = "Potions" })
        forgetName("item", 960040)
        discover(KCM, "HP_POT", { 960040 })
        loader.mock.setSpell(7745, { name = "Quiet Mending" })
        forgetName("spell", 7745)
        KCM.Selector.GetBucket("HP_POT").added[KCM.ID.AsSpell(7745)] = true
        local line = renderLine(KCM, "HP_POT")
        local added = recordAdds(KCM)

        line.submit("elixir of quiet waters")
        t.eq(added[1], 960040, "an item candidate resolves by its name, whatever the case")

        KCM.Options._addKind.HP_POT = "SPELL"
        line.submit("Quiet Mending")
        t.eq(added[2], KCM.ID.AsSpell(7745),
            "a spell candidate resolves too, and stores through the sentinel")
        t.eq(#added, 2, "and nothing else was added")
    end)

test("Add-by-ID: picking a suggestion stores through Selector.AddItem exactly once", function(t)
    -- red under: no dropdown to pick from; or a pick that skips onAdd's store (a spell stored raw)
    local KCM = loadCategorySettings()
    seedZephyr(KCM)
    local line = renderLine(KCM, "HP_POT")
    local added = recordAdds(KCM)

    line.typeText("hushed")
    line.pick(191395)
    t.eq(#added, 1, "one pick, one write")
    t.eq(added[1], 191395, "the rank that was picked, and no other")
    t.eq(line.edit._text, "", "the box is cleared for the next one")
    t.eq(#line.rows(), 0, "and the list is closed")

    -- A fresh load: the dropdown is one frame per library instance, built on its first show.
    KCM = loadCategorySettings()
    loader.mock.setSpell(7744, { name = "Will of the Forsaken" })
    KCM.Selector.GetBucket("HP_POT").added[KCM.ID.AsSpell(7744)] = true
    KCM.Options._addKind.HP_POT = "SPELL"
    line = renderLine(KCM, "HP_POT")
    added = recordAdds(KCM)
    line.typeText("will of")
    t.eq(line.shownIds(), "7744", "under Spell the rows are the category's spells, by spell id")
    line.pick(7744)
    t.eq(#added, 1, "one pick, one write")
    t.eq(added[1], KCM.ID.AsSpell(7744), "a picked spell goes in through the opaque sentinel")
end)

test("Add-by-ID: a shared name lists every rank, and Enter without a pick is refused", function(t)
    -- red under: a resolver that takes the client's hit (or the first candidate) for a shared name
    local KCM = loadCategorySettings()
    seedZephyr(KCM)
    local line = renderLine(KCM, "HP_POT")
    local added = recordAdds(KCM)

    line.submit(ZEPHYR)
    t.eq(#added, 0, "no rank is added for the player")
    local status = line.status._text or ""
    t.truthy(status:find("pick one from the list", 1, true) and status:find(ZEPHYR, 1, true),
        "the status line says the name is shared and to pick ('" .. status .. "')")
    t.eq(line.edit._text, ZEPHYR, "the typed name is kept")
    t.eq(line.shownIds(), "191393,191394,191395", "and every rank is listed to pick from")

    line.submit(ZEPHYR)
    t.eq(#added, 0, "a second Enter with nothing picked is refused again")

    -- One rank carried this session: the client answers that one for the name, and it is still
    -- one of three.
    loader.mock.ids.addIdRecord("item", 191395, ZEPHYR, "icon:191395")
    line.submit(ZEPHYR)
    t.eq(#added, 0, "the carried rank is not added on the client's word alone")
    t.truthy((line.status._text or ""):find("pick one from the list", 1, true), "it is refused too")
end)

test("Add-by-ID: the tooltip and the refusals say where a name can come from", function(t)
    -- red under: the old tooltip ("type the name of one the game already knows") and a notFound
    -- with no hint
    local KCM = loadCategorySettings()
    local line = renderLine(KCM, "HP_POT")
    local lines = {}
    rawset(_G.GameTooltip, "AddLine", function(_, text) lines[#lines + 1] = text end)
    line.edit._callbacks.OnEnter(line.edit, "OnEnter")
    local tip = table.concat(lines, "\n")
    t.falsy(tip:find("already knows", 1, true), "the old promise is gone ('" .. tip .. "')")
    t.truthy(tip:find("carry", 1, true) and tip:find("this list knows", 1, true),
        "the tooltip says a name works for items you carry and ones this list knows")
    t.truthy(tip:find("pick", 1, true), "and that a name is picked from the list")

    line.submit("Nonexistent Thing")
    local status = line.status._text or ""
    t.truthy(status:find("Nonexistent Thing", 1, true) and status:find("carry", 1, true),
        "an item name nothing knows is refused with the hint ('" .. status .. "')")

    KCM.Options._addKind.HP_POT = "SPELL"
    line.submit("Nonexistent Thing")
    status = line.status._text or ""
    t.truthy(status:find("spell", 1, true) and status:find("spellbook", 1, true),
        "a spell name gets the spell hint ('" .. status .. "')")
end)

test("Add-by-ID: a spec-aware tab with no spec suggests nothing", function(t)
    -- red under: suggestions on a tab whose resolver refuses every entry; a pick would skip it
    local KCM = loadCategorySettings()
    loader.mock.setItem(960011, { name = "Test Flask", subType = "Flasks & Phials" })
    t.falsy(KCM.Options.ResolveViewedSpec, "no viewed-spec resolver in this file set")
    local line = renderLine(KCM, "FLASK")
    line.typeText("test flask")
    t.eq(line.shownIds(), "", "no list goes up")
end)

test("Add-by-ID: changing Type redraws the line, so its list is the new kind's", function(t)
    -- red under: a Type dropdown that only stores the choice. The list is built once a render, so
    -- an item row left under Spell would be picked and filed as a spell.
    local KCM = loadCategorySettings()
    local line = renderLine(KCM, "HP_POT")
    t.truthy(line.type and line.type._callbacks.OnValueChanged, "the Type dropdown is wired")
    local redrawn = 0
    rawset(KCM.Settings.Helpers, "RefreshAllPanels", function() redrawn = redrawn + 1 end)
    line.type._callbacks.OnValueChanged(line.type, "OnValueChanged", "SPELL")
    t.eq(KCM.Options._addKind.HP_POT, "SPELL", "the choice is stored")
    t.eq(redrawn, 1, "and the page is drawn again")
end)
