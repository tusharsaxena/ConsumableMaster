-- test_skin_settings.lua — this addon's own AceGUI acquisitions and its tool surfaces on the skin
-- (core/SkinSetup.lua's KCM.SkinAcquire / KCM.SkinPaintAce / KCM.SkinPaintAceTree over
-- LibKa0s-Skin-1.0's SkinAce, skinning-§3; CM-04 of the 2026-10-29 skinning rollout).
--
-- What this pins:
--   * every AceGUI widget a settings file acquires itself goes through KCM.SkinAcquire, which
--     paints it for this owner EVEN THROUGH THE RAW AceGUI HANDLE the files hold (not the Options
--     instance's owner proxy), and a release hands it back stock, the shared pool clean;
--   * nothing is painted while the Scope's Ignore settings panel is on (its default), so a
--     player who never touched the Scope sees the stock widgets as before;
--   * the Profiles page paints the tree AceConfigDialog drew, and a skin change redraws it (AceGUI
--     rows are never repainted in place);
--   * the tool surfaces (debug console, perf panel) are handed the folder as their owner, with no
--     host `skin` or `applySkin` that would opt them out;
--   * degraded, nothing is painted and a host release still runs.
--
-- The mock's widgets carry none of AceGUI's regions, so "painted" is read where the library keeps
-- it: `Skin.__ace[widget].owner` (SkinAce.lua's weak state table), set while owned and cleared by
-- the restore.

local h = _G.KCM_TEST
local test = h.test

local ROOT = _G.KCM_TEST_ROOT or "."
local OWNER = "ConsumableMaster"

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

local function skinLib() return LibStub("LibKa0s-Skin-1.0", true) end

local function ownerOf(w)
    local st = skinLib().__ace and skinLib().__ace[w]
    return st and st.owner or nil
end

--- The harness's AceGUI hands back a permissive stub with no `type` and no `frame`, which the
--- library's PaintAce rightly refuses. Patched in place (every settings file captured this very
--- table at load), each widget carries its type, a frame, and AceGUI's one-callback-per-event
--- SetCallback / Fire, so a paint and a release run as they do in the client.
local function typedAce()
    local mock = h.loader.mock
    local AceGUI = LibStub("AceGUI-3.0")
    AceGUI.Create = function(self, wtype)
        local w = mock.makeAceWidget()
        local callbacks = {}
        rawset(w, "type", wtype)
        rawset(w, "frame", mock.makeStub())
        rawset(w, "SetCallback", function(_, event, fn) callbacks[event] = fn end)
        rawset(w, "__fire", function(me, event, ...) if callbacks[event] then callbacks[event](me, event, ...) end end)
        self.__created[#self.__created + 1] = w
        return w
    end
    return AceGUI
end

--- The addon loaded, on `skin`, with the Scope's Ignore settings panel set to `ignorePanel`.
local function loadOn(skin, ignorePanel)
    local KCM = h.loader.loadFullAddon()
    typedAce()
    KCM.Schema:Set("skin.ignorePanel", ignorePanel and true or false)
    KCM.Schema:Set("skin.skin", skin)
    return KCM
end

-- ── the acquisitions ─────────────────────────────────────────────────────────────────────────

-- red under: a settings file that acquires straight from AceGUI again (past the seam's paint).
test("Skin settings: every AceGUI widget a settings file acquires goes through KCM.SkinAcquire", function(t)
    local raw, routed = {}, 0
    for _, rel in ipairs(h.loader.tocFiles()) do
        if rel:match("^settings/") then
            local src = readFile(ROOT .. "/" .. rel) or ""
            local n = 0
            for line in src:gmatch("[^\n]+") do
                local code = line:gsub("%-%-.*$", "")
                if code:find("AceGUI:Create(", 1, true) then n = n + 1 end
                if code:find("KCM.SkinAcquire(", 1, true) then routed = routed + 1 end
            end
            if n > 0 then raw[#raw + 1] = rel .. " (" .. n .. ")" end
        end
    end
    t.eq(table.concat(raw, ", "), "", "no raw AceGUI:Create in settings/")
    t.eq(routed, 18, "the eighteen acquisitions are routed")
end)

-- red under: KCM.SkinAcquire losing its KCM.SkinPaintAce (the raw handle paints nothing itself).
test("Skin settings: under a non-default skin an acquired widget is painted, past the proxy", function(t)
    local KCM = loadOn("obsidian", false)
    local AceGUI = LibStub("AceGUI-3.0")
    for _, wtype in ipairs({ "Button", "Label", "CheckBox", "Dropdown", "Heading" }) do
        local w = KCM.SkinAcquire(AceGUI, wtype)
        t.eq(ownerOf(w), OWNER, wtype .. " is painted for this owner")
        t.eq(type(rawget(w, "OnRelease")), "function", wtype .. ": its release is wrapped")
        AceGUI:Release(w)
        t.eq(ownerOf(w), nil, wtype .. ": the release hands it back stock")
    end
    local g = KCM.SkinAcquire(AceGUI, "SimpleGroup")
    t.eq(ownerOf(g), nil, "a SimpleGroup has no painter and is never owned")
    AceGUI:Release(g)
end)

test("Skin settings: under Ka0s Default the acquired widgets paint like every skin's", function(t)
    local KCM = loadOn("ka0s", false)
    local AceGUI = LibStub("AceGUI-3.0")
    local w = KCM.SkinAcquire(AceGUI, "Button")
    t.eq(ownerOf(w), OWNER, "Ka0s Default is a skin like the others")
    AceGUI:Release(w)
end)

-- red under: a paint that ignores the Scope (the stock look the default promises would be lost).
test("Skin settings: with Ignore settings panel on, the default, nothing is painted", function(t)
    local KCM = h.loader.loadFullAddon()
    typedAce()
    t.eq(KCM.db.profile.skin.ignorePanel, true, "the Scope's panel half is on by default")
    KCM.Schema:Set("skin.skin", "obsidian")
    local AceGUI = LibStub("AceGUI-3.0")
    local w = KCM.SkinAcquire(AceGUI, "Button")
    t.eq(ownerOf(w), nil, "the widget stays stock")
    AceGUI:Release(w)
end)

-- red under: dropping the paint from a page render (a page's own widgets left stock).
test("Skin settings: a rendered page's own widgets are painted for this owner", function(t)
    local KCM = loadOn("obsidian", false)
    -- Two slots hidden, so the Buttons tab draws the rule between the groups.
    KCM.db.profile.macroBar.shown = { DRINK = false, HS = false }
    local painted = {}
    local paint = KCM.SkinPaintAce
    KCM.SkinPaintAce = function(w)
        local ok = paint(w)
        if ok and ownerOf(w) == OWNER then painted[w.type or "?"] = true end
        return ok
    end
    local ok, err = pcall(function()
        local UI = KCM.Settings.Helpers.instance
        for _, key in ipairs({ "general", "macrobar" }) do
            KCM.Settings.builders[key]({})
            local ctx = UI.__panelFor(key)
            ctx.panel.IsShown = function() return true end
        end
        UI.__panelFor("general").activeTab = "Maintenance"
        UI.__panelFor("macrobar").activeTab = "Buttons"
        KCM.Settings.Helpers.RefreshAllPanels()
    end)
    KCM.SkinPaintAce = paint
    if not ok then error(err, 0) end
    t.truthy(painted.Button, "the Maintenance tab's buttons are painted")
    t.truthy(painted.Heading, "the Macro Bar page's boundary rule is painted")
end)

-- ── the Profiles page ────────────────────────────────────────────────────────────────────────

-- red under: dropping KCM.SkinPaintAceTree from the Profiles renderer, or a renderer that does not
-- redraw on a skin change (the tree would keep the old skin's paint).
test("Skin settings: the Profiles page paints the tree AceConfigDialog drew, and redraws on a skin change",
    function(t)
        local KCM = loadOn("obsidian", false)
        local trees = 0
        local paintTree = KCM.SkinPaintAceTree
        KCM.SkinPaintAceTree = function(c) trees = trees + 1; return paintTree(c) end
        local ok, err = pcall(function()
            local UI = KCM.Settings.Helpers.instance
            local ACD = h.loader.mock.libs["AceConfigDialog-3.0"]
            KCM.Settings.builders.profiles({})
            local ctx = UI.__panelFor("profiles")
            ctx.panel.IsShown = function() return true end
            ctx.panel:_run("OnShow")
            t.eq(trees, 1, "the first draw is painted")
            local opens = ACD.__opens
            KCM.Settings.Helpers.RefreshAllPanels()
            t.eq(ACD.__opens, opens, "a refresh with nothing changed leaves the tree alone")
            KCM.Schema:Set("skin.skin", "ember")
            KCM.Settings.Helpers.RefreshAllPanels()
            t.eq(ACD.__opens, opens + 1, "a skin change redraws it")
            t.eq(trees, 2, "and paints the fresh tree")
        end)
        KCM.SkinPaintAceTree = paintTree
        if not ok then error(err, 0) end
    end)

-- ── the tool surfaces ────────────────────────────────────────────────────────────────────────

-- red under: a descriptor that drops the folder, or a host `skin` / `applySkin` that owns the whole
-- job and keeps the library from painting the surface for this owner.
test("Skin settings: the debug console and the perf panel are handed the folder as their owner", function(t)
    for _, rel in ipairs({ "core/DebugLogSetup.lua", "core/PerfSetup.lua" }) do
        local src = readFile(ROOT .. "/" .. rel) or ""
        local body = src:match("lib:New%(%{(.-)\n%}%)") or ""
        local code = body:gsub("%-%-[^\n]*", "")
        t.truthy(code:find("addonName%s*=%s*addonName"), rel .. " passes addonName = addonName")
        t.falsy(code:find("applySkin%s*="), rel .. " passes no applySkin")
        t.falsy(code:find("[^%w_]skin%s*="), rel .. " passes no skin table")
    end
end)

test("Skin settings: the live debug console is painted for this owner", function(t)
    local KCM = h.loader.loadFullAddon()
    local DL = KCM.DebugLog
    DL.Show()
    local f = DL.instance._frameForTest
    t.truthy(f, "the console frame")
    local rec = skinLib().painted[f]
    t.eq(rec and rec.owner, OWNER, "the console window is recorded for this owner")
    DL.Hide()
end)

-- ── the degraded seam ────────────────────────────────────────────────────────────────────────

test("Skin settings: degraded, SkinAcquire paints nothing and a host release still runs", function(t)
    local KCM = h.loader.loadPureDegraded()
    local AceGUI = typedAce()
    local w = KCM.SkinAcquire(AceGUI, "SimpleGroup")
    t.truthy(w, "the widget is still acquired")
    t.eq(KCM.SkinPaintAce(w), false, "PaintAce is a no-op")
    t.eq(KCM.SkinPaintAceTree(w), 0, "PaintAceTree paints nothing")
    local ran
    KCM.SkinOnRelease(w, function(released) ran = released end)
    AceGUI:Release(w)
    t.truthy(ran == w, "the host's release work runs without the library")
end)
