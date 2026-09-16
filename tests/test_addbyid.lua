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
    -- And the Add-by-ID line, which is settings/CategoryAddByID.lua's since the
    -- 1500-line peel. It loads after Category.lua, in the TOC's order, because
    -- it takes that file's two published page helpers as file-scope locals.
    files[#files + 1] = "settings/CategoryAddByID.lua"
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
    -- red under: suggestions on a tab whose resolver refuses every entry (a pick would skip it and
    -- file the id with no spec), which takes BOTH guards going: no `info` there, and no candidates.
    local KCM = loadCategorySettings()
    loader.mock.setItem(960011, { name = "Test Flask", subType = "Flasks & Phials" })
    t.falsy(KCM.Options.ResolveViewedSpec, "no viewed-spec resolver in this file set")
    -- A candidate that WOULD match. BuildCandidateSet(FLASK, nil) falls back to the player's
    -- current spec, so this is the bucket the line would read if it were handed candidates.
    discover(KCM, "FLASK", { 960011 })
    local known = false
    for _, id in ipairs(KCM.Selector.BuildCandidateSet("FLASK", nil)) do
        if id == 960011 then known = true end
    end
    t.truthy(known, "the fixture is a candidate under the bucket the line would read")
    local line = renderLine(KCM, "FLASK")
    line.typeText("test flask")
    t.eq(line.shownIds(), "", "no list goes up")
end)

test("Add-by-ID: a spec-aware tab with no spec promises no list and no name hint", function(t)
    -- red under: the one tooltip for every tab ("pick it from the list", "this list knows")
    local KCM = loadCategorySettings()
    local line = renderLine(KCM, "FLASK")
    local lines = {}
    rawset(_G.GameTooltip, "AddLine", function(_, text) lines[#lines + 1] = text end)
    line.edit._callbacks.OnEnter(line.edit, "OnEnter")
    local tip = table.concat(lines, "\n")
    t.falsy(tip:find("from the list", 1, true), "no list to pick from ('" .. tip .. "')")
    t.falsy(tip:find("this list knows", 1, true), "and no hint about the list's names")
    t.truthy(tip:find("spec", 1, true), "it says a spec is what is missing")
end)

--- Wrap Helpers.IdInput so the spec the page hands it is kept: its onAdd and its candidates.
local function captureSpec(KCM)
    local H = KCM.Settings.Helpers
    local real, box = H.IdInput, {}
    rawset(H, "IdInput", function(ctx, parent, spec)
        box.spec = spec
        return real(ctx, parent, spec)
    end)
    return box
end

test("Add-by-ID: onAdd re-checks existence, since a pick skips the resolver", function(t)
    -- red under: an onAdd that stores whatever number it is handed
    local KCM = loadCategorySettings()
    loader.mock.setItem(960050, { name = "Real Draught", subType = "Potions" })
    local box = captureSpec(KCM)
    renderLine(KCM, "HP_POT")
    local added = recordAdds(KCM)

    box.spec.onAdd(0)
    box.spec.onAdd(-960050)
    box.spec.onAdd(99999991)
    t.eq(#added, 0, "a zero, a negative and an id the client does not know are refused")
    box.spec.onAdd(960050)
    t.eq(added[1], 960050, "a real item goes in")
    t.eq(#added, 1, "and only that one")
end)

test("Add-by-ID: the candidates are the Type's own kind, turned back from their stored shape",
    function(t)
        -- red under: an Item fromStored that keeps the negative spell sentinels, or a Spell one
        -- that keeps item ids
        local KCM = loadCategorySettings()
        loader.mock.setItem(960040, { name = "Elixir of Quiet Waters", subType = "Potions" })
        loader.mock.setSpell(7744, { name = "Will of the Forsaken" })
        discover(KCM, "HP_POT", { 960040 })
        KCM.Selector.GetBucket("HP_POT").added[KCM.ID.AsSpell(7744)] = true
        local box = captureSpec(KCM)
        renderLine(KCM, "HP_POT")

        local function has(list, want)
            for _, id in ipairs(list) do if id == want then return true end end
            return false
        end
        local items = box.spec.candidates()
        t.truthy(has(items, 960040), "an item candidate is listed under Item")
        for _, id in ipairs(items) do
            t.truthy(id > 0 and id ~= 7744, "and no spell, raw or behind its sentinel (" .. id .. ")")
        end
        KCM.Options._addKind.HP_POT = "SPELL"
        local spells = box.spec.candidates()
        t.eq(#spells, 1, "under Spell, the one spell and no item")
        t.eq(spells[1], 7744, "as its spell id")
    end)

--- The owner's case with the ranks in the bags: the player carries ranks 2 and 3, the client has
--- never seen rank 1 this session, and none of them is one of this tab's candidates.
local function carryZephyr()
    for _, id in ipairs(ZEPHYR_IDS) do
        loader.mock.setItem(id, { name = ZEPHYR, subType = "Potions" })
    end
    forgetName("item", 191393)
    loader.mock.setBag(191394, 1)
    loader.mock.setBag(191395, 1)
end

test("Add-by-ID: ranks the player carries are one shared name too, listed to pick from",
    function(t)
        -- red under: candidates that are the category's ids alone. The client answers one rank for
        -- the name, no candidate shares it, so that rank is added for the player.
        local KCM = loadCategorySettings()
        carryZephyr()
        local line = renderLine(KCM, "HP_POT")
        local added = recordAdds(KCM)

        line.submit(ZEPHYR)
        t.eq(#added, 0, "no carried rank is added on the client's word")
        t.truthy((line.status._text or ""):find("pick one from the list", 1, true),
            "the name is refused as shared ('" .. tostring(line.status._text) .. "')")
        t.eq(line.shownIds(), "191394,191395", "and the list the refusal promises opens, both ranks")
        line.pick(191395)
        t.eq(added[1], 191395, "a pick adds the carried rank that was picked")

        KCM = loadCategorySettings()
        carryZephyr()
        discover(KCM, "HP_POT", { 191393 })
        line = renderLine(KCM, "HP_POT")
        line.typeText("hushed")
        t.eq(line.shownIds(), "191393,191394,191395",
            "a rank the tab knows and the ranks in the bags list together")
    end)

test("Add-by-ID: changing Type keeps what was typed across the redraw", function(t)
    -- red under: the redraw releasing the box, whose OnAcquire clears it
    local KCM = loadCategorySettings()
    local line = renderLine(KCM, "HP_POT")
    line.typeText("will of")
    line.type._callbacks.OnValueChanged(line.type, "OnValueChanged", "SPELL")
    local last
    for _, w in ipairs(line.made) do
        if w._kind == "EditBox" then last = w end
    end
    t.truthy(last ~= line.edit, "the page was drawn again, with a new box")
    t.eq(last._text, "will of", "which holds the text typed before the switch")

    -- Carried once: the next redraw draws an empty box, as ever.
    KCM.Settings.Helpers.RefreshAllPanels()
    local again
    for _, w in ipairs(line.made) do
        if w._kind == "EditBox" then again = w end
    end
    t.truthy(again ~= last and not again._text, "a later redraw carries nothing")
end)

--- A clock and a timer queue the test advances, as tests/test_settingsui.lua's refresh cases use:
--- the harness's C_Timer runs callbacks inline, which cannot say "a second passed".
local function fakeSchedule(KCM)
    local s = { now = 0, rebuilds = 0, queue = {} }
    local savedGetTime, savedAfter = _G.GetTime, _G.C_Timer.After
    _G.GetTime = function() return s.now end
    _G.C_Timer.After = function(delay, fn) s.queue[#s.queue + 1] = { at = s.now + (delay or 0), fn = fn } end
    rawset(KCM.Settings.Helpers, "RefreshAllPanels", function() s.rebuilds = s.rebuilds + 1 end)
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
    function s.restore() _G.GetTime, _G.C_Timer.After = savedGetTime, savedAfter end
    return s
end

test("Add-by-ID: a debounced page rebuild waits while the box is in use", function(t)
    -- red under: a rebuild that releases the box mid-entry. The library's OnRelease drops a pending
    -- name lookup and the text, with no word on the status line.
    local KCM = loadCategorySettings()
    local line = renderLine(KCM, "HP_POT")
    local focused, visible = true, true
    line.edit.editbox = { HasFocus = function() return focused end }
    line.edit.frame = { IsVisible = function() return visible end }
    local s = fakeSchedule(KCM)

    KCM.Options.RequestRefresh()          -- an item landing: GET_ITEM_INFO_RECEIVED's PANEL_REFRESH
    s.advance(5)
    t.eq(s.rebuilds, 0, "no rebuild while the box has the keys")

    focused = false
    line.edit._text = "Potion of the Hushed Zephyr"
    s.advance(5)
    t.eq(s.rebuilds, 0, "nor while it holds text, a submitted name's lookup included")

    line.edit._text = ""
    s.advance(1.5)
    t.eq(s.rebuilds, 1, "once the box is idle, the held rebuild lands, once")

    line.edit._text = "left behind"
    visible = false
    KCM.Options.RequestRefresh()
    s.advance(1.5)
    t.eq(s.rebuilds, 2, "a box that is not on screen holds nothing")
    s.restore()
end)

-- ── what a row wears: the library's item and spell decorations, through `base` ──────────────
--
-- LibKa0s draws an item row's crafted-quality tier icon and quality color, and a spell row's
-- subtext, only for a kind whose decorations it knows. This addon's kind is its own (its existence
-- checks, its spell sentinels, its no-spec refusal), so it names the library kind its ids belong
-- to as `base`. This harness's C_Item carries no quality and there is no C_TradeSkillUI or
-- ITEM_QUALITY_COLORS, so a case stands them up after the load (mock.install rebuilds C_Item) and
-- puts the two globals back after, whatever the case did: KCMItemRow reads C_TradeSkillUI too.

local ZEPHYR_TIERS = { [191393] = 1, [191394] = 2, [191395] = 3 }
local RARE = "|cff0070dd"

local function withClientDecorations(body)
    local savedTiers, savedColors = rawget(_G, "C_TradeSkillUI"), rawget(_G, "ITEM_QUALITY_COLORS")
    local ok, err = pcall(body)
    rawset(_G, "C_TradeSkillUI", savedTiers)
    rawset(_G, "ITEM_QUALITY_COLORS", savedColors)
    if not ok then error(err, 0) end
end

--- The three Zephyr ranks as the client shows them: rare quality, crafted tiers 1 to 3.
local function decorateZephyr()
    for _, id in ipairs(ZEPHYR_IDS) do loader.mock.items[id].quality = 3 end
    rawset(_G, "ITEM_QUALITY_COLORS", { [3] = { hex = RARE } })
    rawset(_G, "C_TradeSkillUI", {
        GetItemCraftedQualityByItemInfo = function(id) return ZEPHYR_TIERS[id] end,
    })
    _G.C_Item.GetItemQualityByID = function(id)
        local it = loader.mock.items[id]
        return it and it.quality
    end
end

test("Add-by-ID: a crafted potion's rows show each rank's tier icon, its name in quality color",
    function(t)
        -- red under: an Item kind with no `base`. The library draws the tier and the color only for
        -- its own item kind, so the three rows read one plain name told apart by id alone.
        withClientDecorations(function()
            local KCM = loadCategorySettings()
            seedZephyr(KCM)
            decorateZephyr()
            local line = renderLine(KCM, "HP_POT")
            local added = recordAdds(KCM)

            line.typeText("hushed")
            t.eq(line.shownIds(), "191393,191394,191395", "the three ranks, each its own row")
            for _, row in ipairs(line.rows()) do
                local label = row.labelText or ""
                local tier = ZEPHYR_TIERS[row.entry.id]
                t.truthy(label:find("Professions-Icon-Quality-Tier" .. tier .. "-Small", 1, true),
                    "rank " .. tier .. "'s row shows its tier icon ('" .. label .. "')")
                t.truthy(label:find(RARE .. ZEPHYR .. "|r", 1, true),
                    "and its name in the item's quality color ('" .. label .. "')")
            end

            line.submit(ZEPHYR)
            t.eq(#added, 0, "Enter on the full name with no pick adds nothing")
            t.truthy((line.status._text or ""):find("pick one from the list", 1, true),
                "it is refused as shared ('" .. tostring(line.status._text) .. "')")
            line.pick(191395)
            t.eq(#added, 1, "picking tier 3 writes once")
            t.eq(added[1], 191395, "and writes tier 3")
        end)
    end)

test("Add-by-ID: a picked row is asked of this addon's resolver, which can refuse it", function(t)
    -- red under: an Item kind with no `base`, whose pick goes straight to onAdd: the existence
    -- check there drops it with nothing on the status line and the typed name cleared.
    local KCM = loadCategorySettings()
    seedZephyr(KCM)
    local line = renderLine(KCM, "HP_POT")
    local added = recordAdds(KCM)

    line.typeText("hushed")
    loader.mock.items[191395] = nil       -- the client stops knowing the id after the list went up
    line.pick(191395)
    t.eq(#added, 0, "an id the existence check refuses is not added")
    local status = line.status._text or ""
    t.truthy(status:find("191395", 1, true), "the status line says which ('" .. status .. "')")
    t.eq(line.edit._text, "hushed", "and what was typed is kept")
end)

test("Add-by-ID: under Spell the rows show the spell's subtext, and a pick stores the sentinel",
    function(t)
        -- red under: a Spell kind with no `base`: no rank label on its rows
        local KCM = loadCategorySettings()
        loader.mock.setSpell(7744, { name = "Will of the Forsaken" })
        KCM.Selector.GetBucket("HP_POT").added[KCM.ID.AsSpell(7744)] = true
        KCM.Options._addKind.HP_POT = "SPELL"
        _G.C_Spell.GetSpellSubtext = function(id) return id == 7744 and "Racial" or "" end
        local line = renderLine(KCM, "HP_POT")
        local added = recordAdds(KCM)

        line.typeText("will of")
        local row = line.rows()[1]
        local label = row and row.labelText or ""
        t.truthy(label:find("Will of the Forsaken Racial", 1, true),
            "the row names the spell and its subtext ('" .. label .. "')")
        line.pick(7744)
        t.eq(#added, 1, "one pick, one write")
        t.eq(added[1], KCM.ID.AsSpell(7744), "through the opaque sentinel, as ever")
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
