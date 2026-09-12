-- test_bulklog.lua — a bulk reset is ONE [Set] line (debug-logging-§10).
--
-- A reset of a page or a section rewrites a set of rows wholesale, and the rule
-- logs it as one `[Set] <act> <scope>: N rows` line, N being the rows the act
-- actually changed. No row it writes logs its own `[Set]` line. Validation and
-- each row's onChange still run. A profile reset is not a batch through the
-- helper at all: the OnProfileReset handler logs it once, and the session rows
-- the global reset sweeps first stay muted.
--
-- The seam is settings/Panel.lua's Helpers.Bulk (and SetManyAndRefresh's
-- `opts.bulk`, which is the same bracket), plus Helpers.MuteSetLog for the global
-- reset, whose one line is the profile handler's.

local h = _G.KCM_TEST
local test = h.test

-- The bodies of the [Set] lines in the console buffer, in order.
local function setLines(D)
    local out = {}
    for _, line in ipairs(D.buffer) do
        local body = line:match("%[Set%] (.*)$")
        if body then out[#out + 1] = body end
    end
    return out
end

local function hasLine(D, needle)
    for _, line in ipairs(D.buffer) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

-- Load the whole addon with the console armed and empty.
local function loadLogged()
    local KCM = h.loader.loadFullAddon()
    local D = KCM.DebugLog.instance
    return KCM, KCM.Settings.Helpers, D
end

local function arm(KCM, D)
    KCM.State.debug = true
    D:Clear()
end

-- Swap each named row's onChange for a recorder; answers the log and a restorer.
local function recordOnChange(H, paths)
    local fired, saved = {}, {}
    for i, p in ipairs(paths) do
        local def = H.FindSchema(p)
        saved[i] = { def = def, fn = def.onChange }
        def.onChange = function() fired[#fired + 1] = p end
    end
    return fired, function()
        for _, s in ipairs(saved) do s.def.onChange = s.fn end
    end
end

-- A console-visibility double on the addon's forwarder, keeping the real
-- console instance (and so its buffer). The headless frame stub cannot answer
-- IsShown truthfully, and the session row reads it through this forwarder.
local function consoleDouble(KCM)
    local state = { shown = false }
    KCM.DebugLog.Show          = function() state.shown = true end
    KCM.DebugLog.Hide          = function() state.shown = false end
    KCM.DebugLog.IsWindowShown = function() return state.shown end
    return state
end

-- ---------------------------------------------------------------------------
-- The bracket itself
-- ---------------------------------------------------------------------------

-- red under: Helpers.Set logging its per-row line while a bracket is open, or
-- counting a row that was already at the value written.
test("bulk: Helpers.Bulk logs one [Set] line counting the rows it changed, and every onChange runs",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.db.profile.scale, KCM.db.profile.alpha = 1.5, 0.5
        local fired, restore = recordOnChange(H, { "scale", "alpha" })
        arm(KCM, D)

        local n = H.Bulk("reset", "test rows", function()
            H.SetAndRefresh("scale", 1.25)
            H.SetAndRefresh("alpha", 0.5)
        end)
        KCM.State.debug = false
        restore()

        t.eq(n, 1, "Bulk answers the rows it changed")
        t.eqList(setLines(D), { "reset test rows: 1 rows" },
            "one [Set] line, and alpha, already at 0.5, is not counted")
        t.eq(KCM.db.profile.scale, 1.25, "the row was written")
        t.eqList(fired, { "scale", "alpha" }, "each row's onChange still ran, the unchanged one too")
    end)

-- red under: a bracket whose close is skipped when the act raises -- the mute
-- would stick and every later write would go unlogged -- or a line that reads
-- as a finished act when the act was cut short.
test("bulk: a raising act still logs its line with the rows so far, marked stopped, re-raises, and unmutes",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.db.profile.scale = 1.5
        arm(KCM, D)

        local ok, err = pcall(H.Bulk, "reset", "boom", function()
            H.Set("scale", 1.25)
            error("boom", 0)
        end)
        t.eq(ok, false, "the error escapes")
        t.eq(err, "boom", "unwrapped")
        t.eqList(setLines(D), { "reset boom: 1 rows (stopped by an error)" },
            "the line still names the rows written, and says the act did not finish")

        D:Clear()
        H.Set("alpha", 0.75)
        KCM.State.debug = false
        t.eqList(setLines(D), { "alpha = 0.75" }, "and the per-row line is back afterwards")
    end)

test("bulk: a bracket inside a bracket folds into it, with one line for the outer act",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.db.profile.scale, KCM.db.profile.alpha = 1.5, 0.5
        arm(KCM, D)
        H.Bulk("reset", "outer", function()
            H.Set("scale", 1.25)
            H.Bulk("reset", "inner", function() H.Set("alpha", 0.75) end)
        end)
        KCM.State.debug = false
        t.eqList(setLines(D), { "reset outer: 2 rows" }, "the inner act's row counts toward the outer line")
    end)

-- red under: SetManyAndRefresh ignoring opts.bulk, or opening the bracket
-- before validation so a refused batch still logs a line.
test("bulk: SetManyAndRefresh's opts.bulk is the same one line, and a refused batch logs nothing",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.db.profile.scale, KCM.db.profile.alpha = 1.5, 0.5
        local mock = h.loader.mock
        arm(KCM, D)

        mock.output = {}
        local refused = H.SetManyAndRefresh({
            { path = "scale",   value = 1.25 },
            { path = "enabled", value = "yes please" },
        }, { bulk = { act = "reset", scope = "x" } })
        t.eq(refused, false, "validation still refuses the batch")
        t.eqList(setLines(D), {}, "and nothing was written, so nothing is logged")

        local ok = H.SetManyAndRefresh({
            { path = "scale", value = 1.25 },
            { path = "alpha", value = 0.5 },
        }, { bulk = { act = "reset", scope = "x" } })
        KCM.State.debug = false
        t.eq(ok, true, "the valid batch lands")
        t.eqList(setLines(D), { "reset x: 1 rows" }, "as one line counting the one row it changed")
    end)

-- ---------------------------------------------------------------------------
-- The acts
-- ---------------------------------------------------------------------------

-- A Defaults press on a page already at its defaults still logs its one line,
-- with N = 0: the act ran and wrote nothing new, and the console says so rather
-- than going quiet.
--
-- red under: Helpers.Set counting every write rather than every change, or a
-- bracket that skips its line at zero.
test("bulk: the Macro Bar page's Defaults on a page already at defaults logs 0 rows",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.Settings.builders["macrobar"]({})
        local reset = H.instance.__panelFor("macrobar").panel.defaultsOnClick
        KCM.MacroBar.Update = function() end

        arm(KCM, D)
        reset()
        KCM.State.debug = false
        t.eqList(setLines(D), { "reset Macro Bar page: 0 rows" }, "one line, no row counted, no per-row line")
    end)

-- red under: doResetGeneralPage walking its rows outside H.Bulk (six [Set]
-- lines), or logging after DebugLog.SetEnabled(false) has disarmed the console.
test("bulk: the General page's Defaults is one [Set] line and runs each row's onChange",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.Settings.builders["general"]({})
        local reset = H.instance.__panelFor("general").panel.defaultsOnClick
        local console = consoleDouble(KCM)
        KCM.DebugLog.SetEnabled = function(on) KCM.State.debug = on and true or false end

        local paths = {}
        for _, def in ipairs(KCM.Settings.Schema) do
            if def.panel == "general" and def.default ~= nil and def.onChange then
                paths[#paths + 1] = def.path
            end
        end
        local fired, restore = recordOnChange(H, paths)

        KCM.db.profile.scale, KCM.db.profile.alpha = 1.5, 0.5
        console.shown = true
        arm(KCM, D)
        reset()
        restore()

        t.eqList(setLines(D), { "reset General page: 3 rows" },
            "scale, alpha and the open console: three rows changed, one line")
        t.eq(console.shown, false, "the session row was written with the rest")
        t.eqList(fired, paths, "every row's onChange ran once, in row order")
    end)

-- red under: resetCompositeCategory without opts.bulk, or keeping its extra
-- `[Prio] reset <cat>` line.
test("bulk: the composite category reset is one [Set] line, and its reactor runs",
    function(t)
        local KCM, _, D = loadLogged()
        local cfg = KCM.db.profile.categories.HP_AIO
        cfg.enabled       = { HP_POT = false }
        cfg.orderInCombat = {}
        local reasons = {}
        KCM.Pipeline.RequestRecompute = function(reason) reasons[#reasons + 1] = reason end

        arm(KCM, D)
        StaticPopupDialogs["KCM_RESET_CATEGORY"].OnAccept(nil, { catKey = "HP_AIO", composite = true })
        KCM.State.debug = false

        t.eqList(setLines(D), { "reset category HP_AIO: 2 rows" },
            "the flags and the in-combat order changed; the out-of-combat order did not")
        t.falsy(hasLine(D, "[Prio] reset"), "and no second line restates the reset")
        t.eq(reasons[1], "options_aio_reset_cat", "the batch's reactor still ran")
    end)

-- red under: aioReset calling SetMany without opts.bulk.
test("bulk: /cm aio <key> reset is one [Set] line, and the rows' shared onChange runs",
    function(t)
        local KCM, H, D = loadLogged()
        local cfg = KCM.db.profile.categories.HP_AIO
        cfg.enabled       = { HS = false }
        cfg.orderInCombat = {}
        -- The three rows share ONE onChange, and the batch runs each distinct one
        -- once, so the recorder must be one function too.
        local defs = {
            H.FindSchema("categories.HP_AIO.enabled"),
            H.FindSchema("categories.HP_AIO.orderInCombat"),
            H.FindSchema("categories.HP_AIO.orderOutOfCombat"),
        }
        local shared = defs[1].onChange
        t.truthy(shared and defs[2].onChange == shared and defs[3].onChange == shared,
            "the three rows share one onChange")
        local fired = 0
        local recorder = function(...) fired = fired + 1; return shared(...) end
        for _, def in ipairs(defs) do def.onChange = recorder end

        arm(KCM, D)
        KCM:OnSlashCommand("aio hp_aio reset")
        KCM.State.debug = false
        for _, def in ipairs(defs) do def.onChange = shared end

        t.eqList(setLines(D), { "reset category HP_AIO: 2 rows" }, "one line, counting the two rows it changed")
        t.eq(fired, 1, "and the shared onChange still ran, once for the batch")
    end)

-- red under: restoreSessionRows writing outside the mute (a
-- `[Set] state.debugConsole = false` line), the OnProfileReset handler not
-- logging, or keeping the old `[Prio] reset all` line beside it.
test("bulk: the global reset is one [Set] line from the profile handler, the session row muted",
    function(t)
        local KCM, H, D = loadLogged()
        local console = consoleDouble(KCM)
        H.Set("state.debugConsole", true)
        KCM.db.profile.macroBar.buttonSize = 99

        arm(KCM, D)
        KCM.ResetAllToDefaults("test")
        KCM.State.debug = false

        t.eqList(setLines(D), { "reset profile 'Default' to defaults" }, "exactly one [Set] line")
        t.falsy(hasLine(D, "[Prio] reset all"), "and no second line for the same act")
        t.eq(console.shown, false, "the session row was still restored")
        t.eq(KCM.db.profile.macroBar.buttonSize, 36, "and the profile reset")
    end)

-- debug-logging-§10's handler wording for a copy; a switch rewrites no rows
-- and this addon has no switch trace, so it logs no [Set] line.
--
-- red under: the OnProfileCopied handler not logging, or the OnProfileChanged
-- one taking the copy's wording.
test("bulk: a profile copy is one [Set] line from the handler, and a switch is none",
    function(t)
        local KCM, _, D = loadLogged()
        KCM.db:SetProfile("Alt")
        KCM.db.profile.macroBar.buttonSize = 50
        KCM.db:SetProfile("Default")

        arm(KCM, D)
        KCM.db:CopyProfile("Alt")
        t.eqList(setLines(D), { "copied profile 'Alt' → 'Default'" }, "the copy logs once, worded by the event")
        t.eq(KCM.db.profile.macroBar.buttonSize, 50, "and the copy landed")

        D:Clear()
        KCM.db:SetProfile("Alt")
        KCM.State.debug = false
        t.eqList(setLines(D), {}, "a switch logs no [Set] line")
    end)

-- ---------------------------------------------------------------------------
-- Errors, mutes and profile events inside a bracket
-- ---------------------------------------------------------------------------

-- red under: a MuteSetLog frame whose close is skipped when its act raises.
test("bulk: MuteSetLog re-raises a raising act, logs no line, and unmutes", function(t)
    local KCM, H, D = loadLogged()
    KCM.db.profile.scale = 1.5
    arm(KCM, D)

    local ok, err = pcall(H.MuteSetLog, function()
        H.Set("scale", 1.25)
        error("boom", 0)
    end)
    t.eq(ok, false, "the error escapes")
    t.eq(err, "boom", "unwrapped")
    t.eqList(setLines(D), {}, "the muted act logs nothing, not even on the way out")
    t.eq(KCM.db.profile.scale, 1.25, "the write before the raise landed")

    H.Set("alpha", 0.75)
    KCM.State.debug = false
    t.eqList(setLines(D), { "alpha = 0.75" }, "and the per-row line is back afterwards")
end)

-- A concrete act, not the bracket alone: a Macro Bar Defaults whose walk is cut
-- short by a raising row write. The row's reactors are pcall-guarded, so a write
-- is what can raise; the trap makes one later row's assignment raise.
--
-- red under: Helpers.Bulk logging the line unmarked, or not re-raising, so the
-- act would carry on and move the position after a batch that did not land.
test("bulk: a Macro Bar Defaults that raises mid-walk logs its one line marked stopped, and re-raises",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.Settings.builders["macrobar"]({})
        local reset = H.instance.__panelFor("macrobar").panel.defaultsOnClick
        KCM.MacroBar.Update = function() end
        local moved = false
        KCM.MacroBar.ResetPosition = function() moved = true end

        local cfg = KCM.db.profile.macroBar
        cfg.buttonSize = 50
        -- alpha comes later in the walk than buttonSize. With its key absent, the
        -- write reaches __newindex, which raises.
        cfg.alpha = nil
        setmetatable(cfg, { __newindex = function() error("boom", 0) end })

        h.loader.mock.output = {}
        arm(KCM, D)
        reset()
        KCM.State.debug = false
        setmetatable(cfg, nil)

        t.eqList(setLines(D), { "reset Macro Bar page: 1 rows (stopped by an error)" },
            "one line, counting the row changed before the raise, and marked")
        t.truthy(table.concat(h.loader.mock.output, "\n"):find("defaults action failed: boom", 1, true),
            "the error left the act and reached the Defaults wrapper")
        t.falsy(moved, "and the position, which moves only after the batch lands, did not")
    end)

-- The global reset already runs under MuteSetLog; an open bracket around it
-- must not add its own line to the handler's.
test("bulk: the global reset inside an open bracket is still one line in all", function(t)
    local KCM, H, D = loadLogged()
    consoleDouble(KCM)
    H.Set("state.debugConsole", true)
    arm(KCM, D)

    H.Bulk("reset", "outer", function()
        H.Set("scale", 1.5)
        KCM.ResetAllToDefaults("test")
    end)
    KCM.State.debug = false
    t.eqList(setLines(D), { "reset profile 'Default' to defaults" }, "the handler's line and nothing else")
end)

-- A profile reset or copy that AceDB runs inside an open bracket, not through
-- ResetAllToDefaults: the handler's line is the act's one line, so the bracket
-- it sits in logs none.
--
-- red under: the profile handler logging without silencing the open frame,
-- which leaves an `outer: N rows` line beside it.
test("bulk: a profile handler's line inside an open bracket is the one line, for a reset and a copy",
    function(t)
        local KCM, H, D = loadLogged()
        KCM.db:SetProfile("Alt")
        KCM.db.profile.macroBar.buttonSize = 50
        KCM.db:SetProfile("Default")
        arm(KCM, D)

        H.Bulk("reset", "outer", function()
            H.Set("scale", 1.5)
            KCM.db:ResetProfile()
        end)
        t.eqList(setLines(D), { "reset profile 'Default' to defaults" }, "the reset: the handler's line only")

        D:Clear()
        H.Bulk("copy", "outer", function()
            H.Set("scale", 1.5)
            KCM.db:CopyProfile("Alt")
        end)
        t.eqList(setLines(D), { "copied profile 'Alt' → 'Default'" }, "the copy: the handler's line only")

        D:Clear()
        H.Bulk("reset", "after", function() H.Set("scale", 1.5) end)
        KCM.State.debug = false
        t.eqList(setLines(D), { "reset after: 1 rows" }, "the silence ended with the frame it was put on")
    end)
