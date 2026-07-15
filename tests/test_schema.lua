-- tests/test_schema.lua — settings/Panel.lua schema + Helpers.ValidateSchema.
local h = require("harness")

h.suite("schema", function(t)
    local KCM = h.loader.loadWithSchema()

    local Helpers = KCM.Settings and KCM.Settings.Helpers
    t.truthy(Helpers, "KCM.Settings.Helpers exists")
    t.truthy(KCM.Settings.Schema, "KCM.Settings.Schema exists")

    -- Zero schema errors.
    t.eq(Helpers.ValidateSchema(), 0, "ValidateSchema reports zero errors")

    -- At least one row registered.
    t.truthy(#KCM.Settings.Schema >= 1, "schema has >= 1 row")

    -- The "enabled" row exists, is a bool.
    local enabledDef = Helpers.FindSchema("enabled")
    t.truthy(enabledDef, "FindSchema('enabled') is non-nil")
    t.eq(enabledDef.type, "bool", "'enabled' row type is bool")

    -- Every row is well-formed: findable by path, valid type.
    local validTypes = { bool = true, number = true, string = true, color = true }
    for _, row in ipairs(KCM.Settings.Schema) do
        t.truthy(Helpers.FindSchema(row.path), "FindSchema('" .. tostring(row.path) .. "') non-nil")
        t.truthy(validTypes[row.type], "row '" .. tostring(row.path) .. "' type '" .. tostring(row.type) .. "' is valid")
    end

    -- Helpers.Get('enabled') reflects db.profile.enabled.
    t.truthy(KCM.db and KCM.db.profile, "db.profile exists")
    t.eq(Helpers.Get("enabled"), KCM.db.profile.enabled, "Get('enabled') mirrors db.profile.enabled")

    -- Set round-trips.
    local orig = Helpers.Get("enabled")
    t.truthy(Helpers.Set("enabled", false), "Set('enabled', false) returns true")
    t.eq(Helpers.Get("enabled"), false, "Get('enabled') == false after Set")
    t.eq(KCM.db.profile.enabled, false, "db.profile.enabled == false after Set")

    t.truthy(Helpers.Set("enabled", true), "Set('enabled', true) returns true")
    t.eq(Helpers.Get("enabled"), true, "Get('enabled') == true after Set")

    -- Restore.
    Helpers.Set("enabled", orig)

    -- Unknown path: FindSchema nil, Get nil.
    t.falsy(Helpers.FindSchema("no_such_path"), "FindSchema on unknown path is nil")
    t.eq(Helpers.Get("does.not.exist"), nil, "Get on unresolvable path is nil")
    t.falsy(Helpers.Set("does.not.exist", 1), "Set on unresolvable path returns false")

    -- [Set] logging at the write seam (debug-logging-§10)
    do
        if not KCM.State then assert(loadfile("core/State.lua"))("ConsumableMaster", KCM) end
        assert(loadfile("modules/DebugLog.lua"))("ConsumableMaster", KCM)
        assert(loadfile("core/Debug.lua"))("ConsumableMaster", KCM)

        local captured = {}
        local realAdd = KCM.DebugLog.AddLine
        KCM.DebugLog.AddLine = function(tag, msg) captured[#captured + 1] = { tag = tag, msg = msg } end

        local origEnabled = Helpers.Get("enabled")
        KCM.State.debug = true
        for i = #captured, 1, -1 do captured[i] = nil end     -- clear before the single write
        Helpers.Set("enabled", false)
        local setLines = {}
        for _, c in ipairs(captured) do if c.tag == "Set" then setLines[#setLines + 1] = c end end
        t.eq(#setLines, 1, "exactly one [Set] line per settings write (no re-echo)")
        t.eq(setLines[1] and setLines[1].msg, "enabled = false", "[Set] line shows path = value")

        -- gated off: no [Set] line when debug is disabled
        KCM.State.debug = false
        local n0 = #captured
        Helpers.Set("enabled", true)
        t.eq(#captured, n0, "no [Set] line captured when debug is off")

        KCM.DebugLog.AddLine = realAdd
        Helpers.Set("enabled", origEnabled)
    end
end)
