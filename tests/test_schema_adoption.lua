-- tests/test_schema_adoption.lua — the settings write seam's observable behavior,
-- pinned through its PUBLIC doors (ConsumableMaster#39, CM-17).
--
-- Written BEFORE the seam moved onto LibKa0s-Schema-1.0, and green on the host's
-- own seam first: every case here is something a player or a page can see --
-- what a write stores, what a refusal prints, what a reset logs and how many
-- times the bar re-applies -- so the adoption has to keep it true rather than
-- merely keep compiling. A separate file because tests/test_schema.lua sits
-- near the 1500-line band and must not grow into it.
--
-- `REACTOR` is the one name the adoption changes on purpose: a row's host
-- reaction is the `apply` field, run by the seam's announce under the
-- `onChange for <path> failed` reporter, rather than Schema's own `onChange`,
-- which propagates.

local h = _G.KCM_TEST
local test = h.test

local REACTOR = "apply"

local function output()
    return table.concat(h.loader.mock.output or {}, "\n")
end

-- The bodies of the [Set] lines in the console buffer, in order.
local function setLines(D)
    local out = {}
    for _, line in ipairs(D.buffer) do
        local body = line:match("%[Set%] (.*)$")
        if body then out[#out + 1] = body end
    end
    return out
end

local function loadLogged()
    local KCM = h.loader.loadFullAddon()
    return KCM, KCM.Settings.Helpers, KCM.DebugLog.instance
end

local function arm(KCM, D)
    KCM.State.debug = true
    D:Clear()
end

-- The console's visibility on the addon's forwarder, keeping the real console
-- (and so its buffer): the headless frame stub cannot answer IsShown truthfully.
local function consoleDouble(KCM)
    local state = { shown = false }
    KCM.DebugLog.Show          = function() state.shown = true end
    KCM.DebugLog.Hide          = function() state.shown = false end
    KCM.DebugLog.IsWindowShown = function() return state.shown end
    return state
end

local function pageReset(KCM, H, key)
    KCM.Settings.builders[key]({})
    return H.instance.__panelFor(key).panel.defaultsOnClick
end

-- ---------------------------------------------------------------------------
-- A single write
-- ---------------------------------------------------------------------------

-- (a) red under: a number stored as given rather than clamped to the row's max.
test("adoption: SetAndRefresh stores a number clamped to its row's range", function(t)
    local KCM = h.loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    t.eq(H.SetAndRefresh("macroBar.buttonSize", 9999), true, "the write lands")
    t.eq(KCM.db.profile.macroBar.buttonSize, 64, "clamped to the row's max")
    t.eq(H.SetAndRefresh("macroBar.buttonSize", -5), true, "and below")
    t.eq(KCM.db.profile.macroBar.buttonSize, 16, "clamped to the row's min")
end)

-- (b) red under: an enum refusal worded any other way, or not printed.
test("adoption: an enum refusal prints the allowed values and stores nothing", function(t)
    local KCM = h.loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    local before = KCM.db.profile.macroBar.orientation
    h.loader.mock.output = {}
    t.eq(H.SetAndRefresh("macroBar.orientation", "DIAGONAL"), false, "refused")
    t.truthy(output():find("invalid value for macroBar.orientation: allowed values: HORIZONTAL, VERTICAL",
        1, true), "the refusal names the path and the allowed values")
    t.eq(KCM.db.profile.macroBar.orientation, before, "and nothing was stored")
end)

-- (c) red under: a write to a path no row declares landing in the profile.
test("adoption: an unknown path is refused and stores nothing", function(t)
    local KCM = h.loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    t.eq(H.SetAndRefresh("macroBar.bogus", 1), false, "SetAndRefresh refuses it")
    t.eq(KCM.Schema:Set("macroBar.bogus", 1), false, "and so does the published setter")
    t.eq(KCM.db.profile.macroBar.bogus, nil, "nothing was stored")
end)

-- (d) red under: a table value stored by reference, so the caller's table and
-- the profile alias.
test("adoption: a color, an order and a map are each stored as a copy", function(t)
    local KCM = h.loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    local cfg = KCM.db.profile.macroBar

    local color = { 0.1, 0.2, 0.3, 0.4 }
    t.eq(H.SetAndRefresh("macroBar.labelColor", color), true, "the color lands")
    t.ne(cfg.labelColor, color, "as a copy")
    color[1] = 0.9
    t.eq(cfg.labelColor[1], 0.1, "a later edit of the caller's table does not reach the store")

    local order = {}
    for i, k in ipairs(KCM.MacroBarModel.AllKeys()) do order[i] = k end
    order[1], order[2] = order[2], order[1]
    t.eq(H.SetAndRefresh("macroBar.order", order), true, "the order lands")
    t.ne(cfg.order, order, "as a copy")
    t.eq(cfg.order[1], order[1], "carrying the caller's first member")

    local first = order[1]
    local shown = { [first] = false }
    t.eq(H.SetAndRefresh("macroBar.shown", shown), true, "the map lands")
    t.ne(cfg.shown, shown, "as a copy")
    shown[first] = true
    t.eq(cfg.shown[first], false, "a later edit of the caller's map does not reach the store")
end)

-- ---------------------------------------------------------------------------
-- The page and category resets
-- ---------------------------------------------------------------------------

-- (e) red under: a page reset re-applying the bar once per row, or logging a
-- line per row.
test("adoption: the Macro Bar page's Defaults applies the bar once and logs one line of N rows",
    function(t)
        local KCM, H, D = loadLogged()
        local reset = pageReset(KCM, H, "macrobar")
        local applied = 0
        KCM.MacroBar.Update = function() applied = applied + 1 end
        KCM.MacroBar.ResetPosition = function() end
        KCM.db.profile.macroBar.buttonSize = 50
        KCM.db.profile.macroBar.spacing = 9

        arm(KCM, D)
        reset()
        KCM.State.debug = false

        t.eq(applied, 1, "one applyBar for the whole page")
        t.eqList(setLines(D), { "reset Macro Bar page: 2 rows" }, "one line, counting the rows it moved")
        t.eq(KCM.db.profile.macroBar.buttonSize, 36, "and the rows are back at their defaults")
    end)

-- (f) red under: a composite reset recomputing once per row.
test("adoption: a composite category reset logs one line and recomputes once", function(t)
    local KCM, _, D = loadLogged()
    local cfg = KCM.db.profile.categories.HP_AIO
    cfg.enabled, cfg.orderInCombat = { HP_POT = false }, {}
    local recomputes = 0
    KCM.Pipeline.RequestRecompute = function() recomputes = recomputes + 1 end

    arm(KCM, D)
    StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept(nil, { catKey = "HP_AIO", composite = true })
    KCM.State.debug = false

    t.eqList(setLines(D), { "reset category HP_AIO: 2 rows" }, "one line")
    t.eq(recomputes, 1, "one recompute for the batch")
end)

-- (g) red under: the session sweep or the bracket around the global reset
-- adding a line of its own beside the profile handler's.
test("adoption: /cm resetall logs the profile handler's line and nothing else", function(t)
    local KCM, _, D = loadLogged()
    consoleDouble(KCM)
    KCM.db.profile.macroBar.buttonSize = 99

    arm(KCM, D)
    KCM:OnSlashCommand("resetall")
    StaticPopupDialogs["KCM_CONFIRM_RESET"].OnAccept()
    KCM.State.debug = false

    t.eqList(setLines(D), { "reset profile 'Default' to defaults: 1 rows" },
        "exactly one [Set] line, the handler's, counting the row the reset moved")
    t.eq(KCM.db.profile.macroBar.buttonSize, 36, "the reset landed")
end)

-- ---------------------------------------------------------------------------
-- The two rows whose store is not the profile
-- ---------------------------------------------------------------------------

-- (h) red under: the console row stored in the profile, where a profile reset
-- would carry it, or not driving the window.
test("adoption: the debug console row shows and hides the window and lives outside the profile",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local H = KCM.Settings.Helpers
        local console = consoleDouble(KCM)

        t.eq(H.SetAndRefresh("state.debugConsole", true), true, "the write lands")
        t.eq(console.shown, true, "the window is shown")
        t.eq(H.Get("state.debugConsole"), true, "and the row reads it back")
        t.eq(H.SetAndRefresh("state.debugConsole", false), true, "the hide lands")
        t.eq(console.shown, false, "the window is hidden")
        t.eq(KCM.db.profile.state, nil, "and nothing was written into the profile")

        H.SetAndRefresh("state.debugConsole", true)
        KCM.ResetAllToDefaults("test")
        t.eq(console.shown, false, "the global reset's session sweep closes it, not the profile reset")
    end)

-- (i) red under: the inversion lost (the stored key is HIDDEN, the row says
-- SHOWN), or either reset reaching the row.
test("adoption: the minimap row inverts onto its global key and survives both resets", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers

    t.eq(H.SetAndRefresh("global.minimap.shown", false), true, "hiding lands")
    t.eq(KCM.db.global.minimap.hide, true, "stored as the library's HIDDEN key")
    t.eq(H.Get("global.minimap.shown"), false, "and read back as not shown")

    pageReset(KCM, H, "general")()
    t.eq(KCM.db.global.minimap.hide, true, "the General page's Defaults does not reach it")
    KCM.ResetAllToDefaults("test")
    t.eq(KCM.db.global.minimap.hide, true, "and neither does the global reset")
end)

-- ---------------------------------------------------------------------------
-- A raising reaction and the degraded build
-- ---------------------------------------------------------------------------

-- (j) red under: a raising reaction propagating out of the seam (the caller
-- sees a failure over a write that persisted) or being swallowed unreported.
test("adoption: a raising reaction is reported and the write persists", function(t)
    local KCM = h.loader.loadWithSchema()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.buttonSize")
    def[REACTOR] = function() error("kaboom", 0) end
    h.loader.mock.output = {}

    local ok, ret = pcall(H.SetAndRefresh, "macroBar.buttonSize", 40)
    t.eq(ok, true, "the seam does not raise")
    t.eq(ret, true, "and answers success")
    t.truthy(output():find("onChange for macroBar.buttonSize failed: kaboom", 1, true), "the failure is reported")
    t.eq(KCM.db.profile.macroBar.buttonSize, 40, "and the write persisted")
end)

-- (k) red under: a degraded build (libs/LibKa0s/ absent) whose seam refuses the
-- rows it still has, so a host verb or the global reset stops writing -- or
-- whose seam still logs, where the stub is log-silent by design.
test("adoption: the degraded build still writes through a host verb and the global reset", function(t)
    local KCM = h.loader.loadFullAddon(true)
    t.falsy(KCM.Settings.Helpers.instance, "the library is absent on this arm")
    t.eq(KCM.Settings.Helpers.schema.SetMany ~= nil, true, "the seam is the stub")
    KCM.State.debug = true
    h.loader.mock.output = {}

    KCM:OnSlashCommand("bar off")
    t.eq(KCM.db.profile.macroBar.enabled, false, "`/cm bar off` wrote its row")
    KCM:OnSlashCommand("bar on")
    t.eq(KCM.db.profile.macroBar.enabled, true, "and `/cm bar on` wrote it back")
    KCM.State.debug = false
    t.falsy(output():find("[Set]", 1, true), "and neither write printed a [Set] line")

    KCM.db.profile.macroBar.buttonSize = 99
    t.eq(KCM.ResetAllToDefaults("test"), true, "the global reset runs")
    t.eq(KCM.db.profile.macroBar.buttonSize, 36, "and lands")
end)

-- ---------------------------------------------------------------------------
-- What the adoption changed on purpose
-- ---------------------------------------------------------------------------

-- The library writes the [Set] line BEFORE the row reacts (LibKa0s-Schema-1.0's
-- pipeline, step 9 before 10), where the host seam logged after. A reaction that
-- itself logs now reads after the write it reacts to.
--
-- red under: a seam that reacts before it logs.
test("adoption: the [Set] line is written before the row's apply runs", function(t)
    local KCM, H, D = loadLogged()
    local seen
    H.FindSchema("macroBar.buttonSize")[REACTOR] = function()
        seen = D:FindLine("[Set] macroBar.buttonSize = 40") and true or false
    end
    arm(KCM, D)
    H.SetAndRefresh("macroBar.buttonSize", 40)
    KCM.State.debug = false
    t.eq(seen, true, "the line was already in the console when the apply ran")
end)

-- (l) A row's `normalize` refusal (`nil, why`) is the library's INVALID, and the
-- CLI prints it ONCE: settings/Slash.lua hands the Slash descriptor the seam's
-- own Set, whose `false, err, why` CliSet renders (Slash minor 15), rather than
-- SetAndRefresh, which printed a host line of its own and answered nothing.
--
-- red under: the descriptor's `set` bound to SetAndRefresh again -- two lines,
-- the second echoing a value that never landed.
test("adoption: a normalize refusal reaches /cm set as one INVALID line", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local row = H.FindSchema("macroBar.buttonSize")
    local before = KCM.db.profile.macroBar.buttonSize
    row.normalize = function() return nil, "not a size this bar can draw" end
    h.loader.mock.output = {}

    KCM:OnSlashCommand("set macroBar.buttonSize 30")
    local out = output()

    local n = 0
    for _ in out:gmatch("Invalid value for macroBar%.buttonSize") do n = n + 1 end
    t.eq(n, 1, "the library's INVALID line, once: " .. out)
    t.falsy(out:find("invalid value for macroBar.buttonSize", 1, true), "and no host line beside it")
    t.truthy(out:find("not a size this bar can draw", 1, true), "carrying the row's reason")
    t.eq(KCM.db.profile.macroBar.buttonSize, before, "and nothing was stored")
end)
