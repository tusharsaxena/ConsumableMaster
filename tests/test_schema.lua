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
    assert(loadfile("core/DebugLogSetup.lua"))("ConsumableMaster", KCM)
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

-- ---------------------------------------------------------------------------
-- The page -> tab -> row partition
--
-- The settings panel is four pages now, two of them carrying a tab strip. These
-- three cases are what catch a row drifting into the wrong tab, a tab losing its
-- rows, and a category losing its tab -- none of which any other case would see,
-- because every one of them still renders something.
-- ---------------------------------------------------------------------------

test("schema: the page order lists four pages, each once", function(t)
    local KCM = h.loader.loadWithSchema()
    t.eqList(KCM.Settings.order, { "general", "macros", "statpriority", "macrobar" },
        "the sidebar reads General, Macros, Stat Priority, Macro Bar")
    local seen = {}
    for _, name in ipairs(KCM.Settings.order) do
        t.falsy(seen[name], "'" .. name .. "' appears once in the page order")
        seen[name] = true
    end
end)

test("schema: the Macros page carries one tab per category, in macroOrder", function(t)
    local KCM = h.loader.loadWithSchema()
    local seen = {}
    for _, key in ipairs(KCM.Settings.macroOrder) do
        t.falsy(seen[key], "'" .. key .. "' appears once in the tab order")
        seen[key] = true
        t.truthy(KCM.Categories.Get(key:upper()),
            "'" .. key .. "' names a real category")
    end
    for _, cat in ipairs(KCM.Categories.LIST) do
        t.truthy(seen[cat.key:lower()], cat.key .. " has a tab on the Macros page")
    end
    t.eq(#KCM.Settings.macroOrder, #KCM.Categories.LIST,
        "and the strip holds no tab that is not a category")
end)

-- The Macros strip, written out longhand: the designed tab order and the label
-- each tab shows. Derived from Categories.LIST it would agree with Categories.LIST
-- whatever that said, and the whole point of the case is that the strip a player
-- sees was DESIGNED -- basic consumables first, the two composites after the
-- categories they aggregate, the spec-aware set next, and the once-per-tier ones
-- last.
--
-- Row counts are not in the table because a category tab has no schema rows: its
-- body is a priority list, which is a collection and not a scalar. What is
-- countable is the strip, and "one tab per category, no more" is asserted by
-- "the Macros page carries one tab per category" above.
test("schema: the Macros strip is the designed run of tabs, in order", function(t)
    local KCM = h.loader.loadFullAddon()
    local want = {
        { "FOOD",       "Food"           },
        { "DRINK",      "Drink"          },
        { "HP_POT",     "Healing Potion" },
        { "MP_POT",     "Mana Potion"    },
        { "HS",         "Healthstone"    },
        { "HP_AIO",     "AIO Health"     },
        { "MP_AIO",     "AIO Mana"       },
        { "FLASK",      "Flask"          },
        { "CMBT_POT",   "Combat Potion"  },
        { "STAT_FOOD",  "Stat Food"      },
        { "WPN_ENCH",   "Weapon Enchant" },
        { "AUG_RUNE",   "Augment Rune"   },
        { "VANTUS",     "Vantus Rune"    },
        { "BLOODLUST",  "Bloodlust"      },
        { "BATTLE_REZ", "Battle Rez"     },
    }
    local tabs = KCM.Options.MacroTabs()
    t.eq(#tabs, #want, "the strip holds exactly the designed tabs")
    for i, entry in ipairs(want) do
        t.eq(tabs[i] and tabs[i].key, entry[1], "tab #" .. i .. " is " .. entry[1])
        t.eq(tabs[i] and tabs[i].label, entry[2],
            entry[1] .. " reads as '" .. entry[2] .. "'")
        t.truthy(tabs[i] and tabs[i].tooltip and tabs[i].tooltip ~= "",
            entry[1] .. " says what its tab is for")
    end
end)

-- The strip's labels are the categories' own displayName, never shortName --
-- shortName exists for the bar's 32px buttons, where "Rune" and "Brez" are all
-- that fit, and two tabs reading "Rune" and "Vantus" would say nothing about
-- which rune each meant.
test("schema: a Macros tab is labelled with the category's display name", function(t)
    local KCM = h.loader.loadFullAddon()
    for _, tab in ipairs(KCM.Options.MacroTabs()) do
        local cat = KCM.Categories.Get(tab.key)
        t.eq(tab.label, cat.displayName, tab.key .. " uses displayName")
    end
end)

-- The designed strip, tab by tab, with the row count each tab is supposed to
-- carry. The counts are the DESIGN's, written out longhand: derived from the
-- schema they would agree with the schema no matter what it said.
--
-- Contents is exempted BY NAME rather than by relaxing the rule, because its
-- controls are one checkbox per managed macro -- a length no schema knows -- and
-- it is the only tab on the page with no `path` behind it.
test("schema: the Macro Bar page partitions into its designed tabs", function(t)
    local KCM = h.loader.loadFullAddon()
    local want = {
        -- General lost `Lock position` to the General page's Master controls tab
        -- (options-ui-§15); the appearance tabs gained the class-color companion
        -- beside every swatch (§17) and Labels gained the font face, the font
        -- flags string and the font shadow the canonical font block mandates (§16).
        { "General",           1  },
        { "Layout",            8  },
        { "Bar appearance",    9  },
        { "Button appearance", 13 },
        { "Labels",            12 },
        { "Flyout",            16 },
        { "Visibility",        3  },
        { "Contents",          0  },
    }

    -- Partition by `group` in DECLARATION order, exactly as a tab strip does.
    local order, counts = {}, {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" then
            if counts[row.group] == nil then
                counts[row.group] = 0
                order[#order + 1] = row.group
            end
            counts[row.group] = counts[row.group] + 1
        end
    end

    local total = 0
    for i, entry in ipairs(want) do
        local group, n = entry[1], entry[2]
        total = total + n
        if n > 0 then
            t.eq(order[i], group, "tab #" .. i .. " is '" .. group .. "'")
            t.eq(counts[group], n, "'" .. group .. "' carries " .. n .. " rows")
        else
            t.eq(counts[group], nil,
                "'" .. group .. "' is bespoke and declares no schema row")
        end
    end
    t.eq(#order, 7, "seven of the eight tabs are schema-backed, and none repeats")

    local rows = 0
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" then rows = rows + 1 end
    end
    t.eq(rows, total, "every Macro Bar row lands in exactly one tab")
end)

-- A group is a TAB, so its rows have to be contiguous: a row filed under a group
-- the page has already left draws that tab a second time, further down.
test("schema: no page's rows leave a group and come back to it", function(t)
    local KCM = h.loader.loadFullAddon()
    local closed, current, page = {}, nil, nil
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel ~= page then
            closed, current, page = {}, nil, row.panel
        end
        if row.group ~= current then
            t.falsy(closed[row.group],
                "row '" .. row.path .. "' reopens the '" .. tostring(row.group)
                .. "' tab, which would draw it twice")
            if current then closed[current] = true end
            current = row.group
        end
    end
end)

test("schema: the tab strips name only groups their rows declare", function(t)
    local KCM = h.loader.loadFullAddon()
    local declared = {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" then declared[row.group] = true end
    end
    for _, tab in ipairs(KCM.Settings.MACROBAR_TABS) do
        if tab.group ~= "Contents" then
            t.truthy(declared[tab.group],
                "the '" .. tab.group .. "' tab has rows to draw")
        end
        t.truthy(tab.label and tab.label ~= "", tab.group .. " has a visible label")
        t.eq(type(tab.draw), "function", tab.group .. " knows how to draw itself")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§15 — the Master controls tab
-- ---------------------------------------------------------------------------
--
-- The one thing every player looks for first is in the same place, under the
-- same words, in every Ka0s addon: the General page's FIRST tab. Asserted over
-- the schema, because the schema IS the tab list — `group` is the partition key
-- and the tab label at once.

-- The canonical set (options-ui-§15) minus the two resets, which are the tab's
-- closing BUTTON PAIR rather than rows. Written out longhand and in order:
-- derived from the schema it would agree with the schema whatever that said.
--
-- `macroBar.locked` is `Lock frame`. The setting MOVED tabs and did not move
-- storage, which is the whole of "move, do not duplicate" — the Macro Bar page
-- must not also declare it, and the next case proves it does not.
local MASTER_ROWS = {
    { "enabled",            "bool"   },
    { "visibility",         "string" },
    { "scale",              "number" },
    { "alpha",              "number" },
    { "macroBar.locked",    "bool"   },
    { "state.debugConsole", "bool"   },
}

-- red under: renaming the group, declaring any other general-page group ahead of
-- it, or hand-writing a row into the block out of canonical order.
test("schema: the General page opens on Master controls, carrying the canonical rows", function(t)
    local KCM = h.loader.loadFullAddon()

    local groups, seen = {}, {}
    local rows = {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "general" then
            if not seen[row.group] then
                seen[row.group] = true
                groups[#groups + 1] = row.group
            end
            if row.group == "Master controls" then rows[#rows + 1] = row end
        end
    end

    t.eq(groups[1], "Master controls",
        "the FIRST group the General page declares is the canonical tab")
    t.eq(#rows, #MASTER_ROWS, "it holds exactly the rows this addon is entitled to")
    for i, want in ipairs(MASTER_ROWS) do
        t.eq(rows[i] and rows[i].path, want[1], "row #" .. i .. " is " .. want[1])
        t.eq(rows[i] and rows[i].type, want[2], want[1] .. " is a " .. want[2])
    end
    -- General visibility is a DROPDOWN, never a boolean: a boolean can only ever
    -- answer two of the four.
    local vis = KCM.Settings.Helpers.FindSchema("visibility")
    local values = KCM.Settings.Helpers.EnumValues(vis)
    t.truthy(type(values) == "table", "the visibility row offers a value list")
end)

-- A SESSION-ONLY ROW STILL NEEDS A DEFAULT. Three separate resets key on
-- `default ~= nil` before they will touch a row -- the global reset's session sweep
-- (core/ConsumableMaster.lua's restoreSessionRows), this page's Defaults button
-- (settings/General.lua's doResetGeneralPage) and `/cm reset` (settings/Slash.lua's
-- applyDefault) -- and OptionsCompose emits the debug-console row with no default of
-- its own, because it cannot know what a host's fresh session looks like. Declaring
-- it is the host's job and this is the case that says so.
--
-- red under: dropping `debugConsole = false` from the MasterControls spec's
-- `defaults`, or declaring a second session-only row without one.
test("schema: every session-only row declares a default, so a reset can reach it", function(t)
    local KCM = h.loader.loadFullAddon()
    local n = 0
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.sessionOnly then
            n = n + 1
            t.truthy(row.default ~= nil,
                "'" .. tostring(row.path) .. "' declares a default")
        end
    end
    t.eq(n, 1, "the debug console is this addon's one session-only row")
end)

-- red under: leaving the old declaration in place anywhere it used to live.
test("schema: every moved Master controls setting is declared exactly once", function(t)
    local KCM = h.loader.loadFullAddon()
    for _, want in ipairs(MASTER_ROWS) do
        local n = 0
        for _, row in ipairs(KCM.Settings.Schema) do
            if row.path == want[1] then n = n + 1 end
        end
        t.eq(n, 1, "'" .. want[1] .. "' is declared once, on one page")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§13 — every row carries a group
-- ---------------------------------------------------------------------------
--
-- A page whose rows declare none cannot draw a strip: the library reports it and
-- renders the page untabbed, which is the defect rather than the shape
-- (anti-patterns #69). Three lines, and the one that catches a row added without
-- a tab to live on.
--
-- red under: dropping `group` from any row literal, or from a composer spec.
test("schema: every row on every page carries a group", function(t)
    local KCM = h.loader.loadFullAddon()
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(row.group and row.group ~= "",
            "row '" .. tostring(row.path) .. "' declares the tab it belongs to")
    end
end)

-- ---------------------------------------------------------------------------
-- options-ui-§17 — the class-color companion
-- ---------------------------------------------------------------------------
--
-- Every color row is followed IMMEDIATELY by its companion, which is what puts
-- the two on one line; the swatch carries `startsLine`, which is what stops an
-- odd number of widgets above them splitting the pair across two; and no color
-- row is ever disabled, because its ALPHA is still read under class color.
--
-- red under: adding a color row without its companion, adding `disabledIf` to
-- one, dropping `startsLine` from a swatch, or declaring any of this addon's
-- swatches `classColor = { source = "unit" }` — every one of them is chrome on a
-- bar the player owns, and the row's declaration is what an audit reads.
test("schema: every color row is followed by its class-color companion", function(t)
    local KCM = h.loader.loadFullAddon()
    local schema = KCM.Settings.Schema
    local colors = 0
    for i, row in ipairs(schema) do
        if row.type == "color" then
            colors = colors + 1
            local companion = schema[i + 1]
            t.truthy(companion and companion.type == "bool",
                "'" .. row.path .. "' is followed by a bool")
            t.truthy(companion and tostring(companion.path):find("useClassColor", 1, true),
                "…and that bool is its useClassColor companion")
            t.eq(companion and companion.label, "Use class color",
                "…labelled with the collection's one wording")
            t.eq(companion and companion.group, row.group, "…in the same tab")
            t.eq(companion and companion.subgroup, row.subgroup, "…under the same heading")
            t.eq(row.startsLine, true,
                "'" .. row.path .. "' opens its line so the pair cannot be split")
            -- This addon paints one bar that belongs to the player and tracks no
            -- unit, so every swatch on it is player-scoped. The declaration is
            -- what an audit reads; the path prefix decides nothing.
            t.eq(row.classColorSource, "player",
                "'" .. row.path .. "' declares whose class it means")
            t.eq(companion and companion.classColorSource, "player",
                "…and its companion agrees")
        end
        t.eq(row.disabledIf, nil,
            "row '" .. tostring(row.path) .. "' carries no disabledIf (anti-patterns #74)")
    end
    t.truthy(colors >= 7, "the addon still declares its seven swatches (" .. colors .. ")")
end)

-- ---------------------------------------------------------------------------
-- options-ui-§7 — a tab that mixes control types carries subsection headings
-- ---------------------------------------------------------------------------
--
-- The four Macro Bar tabs that merge a background block, a border block, a font
-- block and an icon block are the ones this catches. A `subgroup` MUST NOT
-- repeat its tab's name, and every row of a subgrouped tab must carry one --
-- a single unlabelled row among labelled ones is a block with no heading.
--
-- "Repeat" is checked WORD BY WORD, not on the whole string. `Bar` under
-- `Bar appearance` is a repeat -- it names the tab back at the reader instead of
-- naming the kind of control under the heading -- and a whole-string comparison
-- waved it through, which is how it shipped.
--
-- red under: dropping `subgroup` from any row of a mixed tab, or naming a
-- subgroup after any word of the tab it sits in.
test("schema: every mixed tab breaks its blocks up with subsection headings", function(t)
    local KCM = h.loader.loadFullAddon()
    local MIXED = {
        ["Bar appearance"]    = { "Opacity", "Background", "Border" },
        ["Button appearance"] = { "Background", "Border", "Icon" },
        ["Labels"]            = { "Text", "Layout", "Font" },
        ["Flyout"]            = { "Layout", "Background", "Icon" },
    }
    local function repeatsTabName(subgroup, group)
        local sub = tostring(subgroup):lower()
        for word in tostring(group):gmatch("%a+") do
            if word:lower() == sub then return true end
        end
        return false
    end
    local seenOrder, seenSet = {}, {}
    for _, row in ipairs(KCM.Settings.Schema) do
        if row.panel == "macrobar" and MIXED[row.group] then
            t.truthy(row.subgroup and row.subgroup ~= "",
                "row '" .. row.path .. "' sits under a heading")
            t.falsy(repeatsTabName(row.subgroup, row.group),
                "'" .. tostring(row.subgroup) .. "' does not repeat a word of its tab's name")
            local key = row.group .. "/" .. tostring(row.subgroup)
            if not seenSet[key] then
                seenSet[key] = true
                seenOrder[row.group] = seenOrder[row.group] or {}
                local list = seenOrder[row.group]
                list[#list + 1] = row.subgroup
            end
        end
    end
    for group, want in pairs(MIXED) do
        t.eqList(seenOrder[group] or {}, want,
            "'" .. group .. "' declares its headings once each, in order")
    end
end)
