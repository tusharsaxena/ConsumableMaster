-- tests/test_schema.lua — settings/Panel.lua schema + Helpers.ValidateSchema.
local h = _G.KCM_TEST
local test = h.test

test("schema: Settings.Helpers and Settings.Schema tables exist", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings and KCM.Settings.Helpers
    t.truthy(Helpers, "KCM.Settings.Helpers exists")
    t.truthy(KCM.Settings.Schema, "KCM.Settings.Schema exists")
end)

test("schema: ValidateSchema reports zero errors and at least one row", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    t.eq(Helpers.ValidateSchema(), 0, "ValidateSchema reports zero errors")
    t.truthy(#KCM.Settings.Schema >= 1, "schema has >= 1 row")
end)

test("schema: 'enabled' row exists and is a bool", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    local enabledDef = Helpers.FindSchema("enabled")
    t.truthy(enabledDef, "FindSchema('enabled') is non-nil")
    t.eq(enabledDef.type, "bool", "'enabled' row type is bool")
end)

test("schema: every row is findable by path and has a valid type", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    local validTypes = { bool = true, number = true, string = true, color = true }
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(Helpers.FindSchema(row.path), "FindSchema('" .. tostring(row.path) .. "') non-nil")
        t.truthy(validTypes[row.type], "row '" .. tostring(row.path) .. "' type '" .. tostring(row.type) .. "' is valid")
    end
end)

test("schema: Get('enabled') mirrors db.profile.enabled", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    t.truthy(KCM.db and KCM.db.profile, "db.profile exists")
    t.eq(Helpers.Get("enabled"), KCM.db.profile.enabled, "Get('enabled') mirrors db.profile.enabled")
end)

test("schema: Set round-trips a bool setting through Helpers", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    local orig = Helpers.Get("enabled")
    t.truthy(Helpers.Set("enabled", false), "Set('enabled', false) returns true")
    t.eq(Helpers.Get("enabled"), false, "Get('enabled') == false after Set")
    t.eq(KCM.db.profile.enabled, false, "db.profile.enabled == false after Set")

    t.truthy(Helpers.Set("enabled", true), "Set('enabled', true) returns true")
    t.eq(Helpers.Get("enabled"), true, "Get('enabled') == true after Set")

    -- Restore.
    Helpers.Set("enabled", orig)
end)

test("schema: unknown paths resolve to nil/false", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    t.falsy(Helpers.FindSchema("no_such_path"), "FindSchema on unknown path is nil")
    t.eq(Helpers.Get("does.not.exist"), nil, "Get on unresolvable path is nil")
    t.falsy(Helpers.Set("does.not.exist", 1), "Set on unresolvable path returns false")
end)

test("schema: [Set] logs exactly one line at the write seam, gated by debug", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers

    -- [Set] logging at the write seam (debug-logging-§10)
    if not KCM.State then assert(loadfile("core/State.lua"))("ConsumableMaster", KCM) end
    assert(loadfile("modules/DebugLog.lua"))("ConsumableMaster", KCM)
    assert(loadfile("core/Debug.lua"))("ConsumableMaster", KCM)

    -- The console's own buffer, not a stub on KCM.DebugLog.AddLine: the gated
    -- sink hands off to the library instance, which appends through its own
    -- Add and never touches the addon's forwarder.
    local D = KCM.DebugLog.instance

    local origEnabled = Helpers.Get("enabled")
    KCM.State.debug = true
    D:Clear()
    Helpers.Set("enabled", false)
    local setLines = 0
    for _, line in ipairs(D.buffer) do
        if line:find("[Set] ", 1, true) then setLines = setLines + 1 end
    end
    t.eq(setLines, 1, "exactly one [Set] line per settings write (no re-echo)")
    t.truthy(D:FindLine("[Set] enabled = false"), "[Set] line shows path = value")

    -- gated off: no [Set] line when debug is disabled
    KCM.State.debug = false
    D:Clear()
    Helpers.Set("enabled", true)
    t.eq(D:BufferSize(), 0, "no [Set] line captured when debug is off")

    Helpers.Set("enabled", origEnabled)
end)

-- ---------------------------------------------------------------------------
-- Path resolution
-- ---------------------------------------------------------------------------

test("schema: Resolve splits a dotted path into its parent table and key", function(t)
    local KCM = h.loader.loadWithSchema()
    local parent, key = KCM.Settings.Helpers.Resolve("enabled")
    t.eq(parent, KCM.db.profile, "a top-level path resolves against db.profile")
    t.eq(key, "enabled", "with the leaf as the key")
end)

test("schema: Resolve walks nested tables", function(t)
    local KCM = h.loader.loadWithSchema()
    local parent, key = KCM.Settings.Helpers.Resolve("categories.FOOD.added")
    t.eq(parent, KCM.db.profile.categories.FOOD, "the parent is the containing table")
    t.eq(key, "added", "and the key is the final segment")
end)

test("schema: Resolve refuses a path that runs through a non-table", function(t)
    local KCM = h.loader.loadWithSchema()
    local parent = KCM.Settings.Helpers.Resolve("enabled.deeper")
    t.eq(parent, nil, "a scalar cannot be indexed further")
end)

test("schema: Resolve returns nothing for an empty path or a missing DB", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    t.eq((Helpers.Resolve("")), nil, "empty path")
    t.eq((Helpers.Resolve(nil)), nil, "nil path")
    local saved = KCM.db
    KCM.db = nil
    local parent = Helpers.Resolve("enabled")
    KCM.db = saved
    t.eq(parent, nil, "no DB means nothing to resolve against")
end)

test("schema: Set can write a nested path, not just a top-level one", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    t.truthy(Helpers.Set("categories.FOOD.pins", { { itemID = 1, position = 1 } }), "write accepted")
    t.eq(#KCM.db.profile.categories.FOOD.pins, 1, "and landed in the nested table")
end)

-- ---------------------------------------------------------------------------
-- Row validation
-- ---------------------------------------------------------------------------

test("schema: every row declares a panel that exists in the tab order", function(t)
    local KCM = h.loader.loadWithSchema()
    local known = {}
    for _, name in ipairs(KCM.Settings.order) do known[name] = true end
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(known[row.panel],
            "row '" .. row.path .. "' targets panel '" .. tostring(row.panel) .. "', which is a real tab")
    end
end)

test("schema: every row carries a label and a tooltip for the panel to render", function(t)
    local KCM = h.loader.loadWithSchema()
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(row.label and row.label ~= "", "row '" .. row.path .. "' has a label")
        t.truthy(row.tooltip and row.tooltip ~= "", "row '" .. row.path .. "' has a tooltip")
    end
end)

test("schema: every row's default matches the seeded profile value", function(t)
    local KCM = h.loader.loadWithSchema()
    local defaults = KCM.dbDefaults.profile
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.default ~= nil and not row.path:find(".", 1, true) then
            t.eq(row.default, defaults[row.path],
                "row '" .. row.path .. "' default is sourced from dbDefaults, never a second literal")
        end
    end
end)

test("schema: ValidateSchema counts a row with a bad panel, section, and type", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    local schema = KCM.Settings.Schema
    schema[#schema + 1] = { path = "bogus", panel = "nope", section = "nope", type = "nope" }
    local errors = Helpers.ValidateSchema()
    schema[#schema] = nil
    t.eq(errors, 3, "one error each for panel, section, and type")
end)

test("schema: ValidateSchema flags a row with no path", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    local schema = KCM.Settings.Schema
    schema[#schema + 1] = { panel = "general", section = "general", type = "bool" }
    local errors = Helpers.ValidateSchema()
    schema[#schema] = nil
    t.eq(errors, 1, "the missing path is reported")
end)

-- ---------------------------------------------------------------------------
-- Value validation + the SetAndRefresh mutation seam
-- ---------------------------------------------------------------------------

test("schema: ValidateSchemaValue enforces each declared type", function(t)
    local KCM = h.loader.loadWithSchema()
    local V = KCM.Settings.Helpers.ValidateSchemaValue
    t.eq(V({ type = "bool" }, true), true, "a boolean passes for bool")
    t.eq(V({ type = "bool" }, "true"), nil, "a string does not")
    t.eq(V({ type = "number" }, 5), 5, "a number passes for number")
    t.eq(V({ type = "number" }, "5"), nil, "a numeric string does not")
    t.eq(V({ type = "string" }, "x"), "x", "a string passes for string")
    t.eq(V({ type = "string" }, 1), nil, "a number does not")
    t.truthy(V({ type = "color" }, { 1, 1, 1, 1 }), "a table passes for color")
    t.eq(V({ type = "color" }, "#fff"), nil, "a string does not")
end)

test("schema: ValidateSchemaValue passes a row with no recognized type straight through",
    function(t)
        local KCM = h.loader.loadWithSchema()
        local V = KCM.Settings.Helpers.ValidateSchemaValue
        -- The fall-through, and it is load-bearing: a row that declares no type
        -- (or one the validator does not cover) is not rejected, it is accepted
        -- unchanged. Rejecting instead would make SetAndRefresh refuse the row.
        t.eq(V({}, "anything"), "anything", "an absent type accepts the value as-is")
        t.eq(V({ type = "keybind" }, 7), 7, "so does a type with no validator")
    end)

test("schema: ValidateSchemaValue clamps a number to its declared range", function(t)
    local KCM = h.loader.loadWithSchema()
    local V = KCM.Settings.Helpers.ValidateSchemaValue
    local def = { type = "number", min = 1, max = 10 }
    t.eq(V(def, 0), 1, "below the floor clamps up")
    t.eq(V(def, 99), 10, "above the ceiling clamps down")
    t.eq(V(def, 5), 5, "in range passes through untouched")
end)

test("schema: SetAndRefresh writes the value and fires the row's onChange", function(t)
    local KCM = h.loader.loadWithSchema()
    local Helpers = KCM.Settings.Helpers
    local def = Helpers.FindSchema("enabled")
    local seen
    local realOnChange = def.onChange
    def.onChange = function(v) seen = v end
    local ok = Helpers.SetAndRefresh("enabled", false)
    def.onChange = realOnChange

    t.eq(ok, true, "the write succeeded")
    t.eq(KCM.db.profile.enabled, false, "the value landed in the profile")
    t.eq(seen, false, "and the row's side effect ran with the coerced value")
    Helpers.Set("enabled", true)
end)

test("schema: SetAndRefresh refuses a value of the wrong type", function(t)
    local KCM  = h.loader.loadWithSchema()
    local mock = h.loader.mock
    local Helpers = KCM.Settings.Helpers
    mock.output = {}
    local ok = Helpers.SetAndRefresh("enabled", "yes please")
    t.eq(ok, false, "the write is rejected")
    t.eq(KCM.db.profile.enabled, true, "the setting is untouched")
    t.truthy(#mock.output > 0, "and the user is told why")
end)

test("schema: SetAndRefresh refuses an explicit nil rather than deleting the key", function(t)
    -- The guard used to read `if coerced == nil and value ~= nil`, so a nil
    -- value skipped the report — every validator rejects nil, so `coerced` was
    -- nil too — and fell through to Helpers.Set(path, nil), which does not
    -- write nil but DELETES the key out of db.profile. The row then read back
    -- absent rather than as its default, and the seam returned true for it.
    --
    -- red under: restoring the `and value ~= nil` clause — the write returns
    -- true, db.profile.enabled becomes nil, and nothing is printed.
    local KCM  = h.loader.loadWithSchema()
    local mock = h.loader.mock
    local Helpers = KCM.Settings.Helpers
    Helpers.Set("enabled", true)
    mock.output = {}
    local ok = Helpers.SetAndRefresh("enabled", nil)
    t.eq(ok, false, "the write is rejected")
    t.eq(KCM.db.profile.enabled, true, "and the key still exists with its value")
    t.truthy(#mock.output > 0, "and the user is told why")
end)

test("schema: SetAndRefresh refuses a path that is not in the schema", function(t)
    local KCM = h.loader.loadWithSchema()
    t.eq(KCM.Settings.Helpers.SetAndRefresh("not.a.setting", true), false,
        "only declared rows are writable through the mutation seam")
end)

test("schema: the published Schema:Set is the same seam as SetAndRefresh", function(t)
    local KCM = h.loader.loadWithSchema()
    t.eq(KCM.Schema:Set("enabled", false), true, "architecture-§5 setter writes")
    t.eq(KCM.db.profile.enabled, false, "through the same validate-write-refresh path")
    t.eq(KCM.Schema:Set("enabled", 12345), false, "and inherits the same validation")
    KCM.Settings.Helpers.Set("enabled", true)
end)

-- ---------------------------------------------------------------------------
-- Value formatting (shared by /cm list, /cm get and /cm set). Defined in
-- core/SlashCommands.lua, so these cases need the full addon loaded.
-- ---------------------------------------------------------------------------

test("schema: FormatSchemaValue renders nil as 'nil'", function(t)
    local KCM = h.loader.loadFullAddon()
    t.eq(KCM.FormatSchemaValue({ type = "bool" }, nil), "nil", "an unset value renders explicitly")
end)

test("schema: FormatSchemaValue renders a color as a four-component table", function(t)
    local KCM = h.loader.loadFullAddon()
    t.eq(KCM.FormatSchemaValue({ type = "color" }, { 1, 0, 0.5, 1 }), "{1.00, 0.00, 0.50, 1.00}",
        "colors print at fixed precision so /cm get and /cm list agree")
end)

test("schema: FormatSchemaValue renders booleans and strings readably", function(t)
    local KCM = h.loader.loadFullAddon()
    t.eq(KCM.FormatSchemaValue({ type = "bool" }, true), "true", "boolean")
    t.eq(KCM.FormatSchemaValue({ type = "string" }, "hello"), "hello", "string")
end)

-- ---------------------------------------------------------------------------
-- Panel refresh plumbing
-- ---------------------------------------------------------------------------

-- Built through Helpers.CreatePanel and Helpers.SetRenderer rather than
-- hand-assembled and pushed onto KCM.Settings._panels. The registry is
-- LibKa0s-Options-1.0's now, and only its own factory puts a ctx in it — but
-- the honest reason to go through the factory is that these cases are about
-- the refresh CONTRACT, and a fabricated ctx could satisfy it while a real one
-- did not.
--
-- Visibility is the one thing the mock cannot express: its stub answers
-- IsShown with the frame itself, which is truthy. Overriding that one method
-- on a real panel is what makes "hidden" reachable.
local seq = 0
local function page(KCM, shown)
    seq = seq + 1
    local H = KCM.Settings.Helpers
    local ctx = H.CreatePanel("KCMRefreshPanel" .. seq, "R" .. seq, { panelKey = "r" .. seq })
    ctx.panel.IsShown = function() return shown and true or false end
    return ctx, H
end

test("schema: RefreshAllPanels flags an off-screen page dirty instead of rebuilding it", function(t)
    local KCM = h.loader.loadWithSchema()
    local rebuilt = 0
    local ctx, H = page(KCM, false)
    H.SetRenderer(ctx, function() rebuilt = rebuilt + 1 end)

    H.RefreshAllPanels()
    t.eq(rebuilt, 0, "an off-screen page is not rebuilt in place")
    t.truthy(ctx._dirty, "it is flagged so its next OnShow rebuilds it")
end)

test("schema: RefreshAllPanels rebuilds the page that is on screen", function(t)
    local KCM = h.loader.loadWithSchema()
    local rebuilt = 0
    local ctx, H = page(KCM, true)
    H.SetRenderer(ctx, function() rebuilt = rebuilt + 1 end)

    H.RefreshAllPanels()
    t.eq(rebuilt, 1, "the visible page is re-rendered")
    t.eq(ctx._dirty, false, "and is no longer dirty")
end)

test("schema: a render failure is reported instead of breaking the refresh loop", function(t)
    local KCM  = h.loader.loadWithSchema()
    local mock = h.loader.mock
    local healthy = 0
    local bad  = page(KCM, true)
    local good, H = page(KCM, true)
    H.SetRenderer(bad,  function() error("boom") end)
    H.SetRenderer(good, function() healthy = healthy + 1 end)

    mock.output = {}
    H.RefreshAllPanels()
    t.eq(healthy, 1, "one broken page does not stop the others from refreshing")
    local text = table.concat(mock.output, "\n")
    t.truthy(text:find("failed to render", 1, true), "and the failure is reported: " .. text)
end)

test("schema: RefreshScalars re-syncs widgets in place without a rebuild", function(t)
    local KCM = h.loader.loadWithSchema()
    local rebuilt, synced = 0, 0
    local ctx, H = page(KCM, true)
    H.SetRenderer(ctx, function() rebuilt = rebuilt + 1 end)
    ctx.refreshers[#ctx.refreshers + 1] = function() synced = synced + 1 end

    H.RefreshScalars()
    t.eq(synced, 1, "each registered widget updater ran")
    t.eq(rebuilt, 0, "and the page was not torn down and rebuilt")
end)

test("schema: RefreshScalars flags a hidden page dirty rather than syncing it", function(t)
    local KCM = h.loader.loadWithSchema()
    local synced = 0
    local ctx, H = page(KCM, false)
    H.SetRenderer(ctx, function() end)
    ctx.refreshers[#ctx.refreshers + 1] = function() synced = synced + 1 end

    H.RefreshScalars()
    t.eq(synced, 0, "an off-screen page is not re-synced")
    t.truthy(ctx._dirty, "the page rebuilds when the user next visits it")
end)

test("schema: the tab order lists each panel once and covers every category page", function(t)
    local KCM = h.loader.loadWithSchema()
    local seen = {}
    for _, name in ipairs(KCM.Settings.order) do
        t.falsy(seen[name], "'" .. name .. "' appears once in the tab order")
        seen[name] = true
    end
    for _, cat in ipairs(KCM.Categories.LIST) do
        t.truthy(seen[cat.key:lower()], cat.key .. " has a settings tab")
    end
    t.truthy(seen.general and seen.statpriority, "the two non-category pages lead the order")
end)
