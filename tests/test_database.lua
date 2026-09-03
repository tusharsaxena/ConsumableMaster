-- test_database.lua — SavedVariables migration runner (KCM.Database).

local h = _G.KCM_TEST
local test = h.test

test("Database.CURRENT_SCHEMA is the version the code understands", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Database.CURRENT_SCHEMA, 3, "current schema is v3")
end)

test("Database.RunMigrations stamps a fresh account at the current schema", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global = {}                     -- fresh account: no schemaVersion yet
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, KCM.Database.CURRENT_SCHEMA, "stamped to current schema")
end)

test("Database.RunMigrations is idempotent across repeated logins", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global = { schemaVersion = KCM.Database.CURRENT_SCHEMA }
    KCM.Database.RunMigrations()
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, KCM.Database.CURRENT_SCHEMA,
        "still current after repeated runs")
end)

test("Database.RunMigrations is a safe no-op when the DB has no global scope", function(t)
    local KCM = h.loader.loadPure()
    KCM.db = { profile = {} }              -- no .global — must not error
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global, nil, "no global fabricated, no crash")
end)

test("Database.RunMigrations seeds a missing schemaVersion instead of leaving it nil", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global.schemaVersion = nil
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, KCM.Database.CURRENT_SCHEMA,
        "an account that predates the field is stamped, not left unversioned")
end)

test("Database.RunMigrations upgrades an older stored version to current", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global.schemaVersion = 0
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, KCM.Database.CURRENT_SCHEMA, "stamped forward to current")
end)

test("Database.RunMigrations leaves unrelated global keys untouched", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global.somethingElse = "keep me"
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.somethingElse, "keep me", "migration only owns schemaVersion")
end)

test("Database.RunMigrations never writes into the profile scope", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.enabled = false
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.enabled, false, "profile settings are not reset by a migration pass")
    t.eq(KCM.db.profile.schemaVersion, nil,
        "the version lives account-wide in global, never per profile (savedvariables-§1)")
end)

test("Database.RunMigrations is a safe no-op before the DB exists", function(t)
    local KCM = h.loader.loadPure()
    local saved = KCM.db
    KCM.db = nil
    KCM.Database.RunMigrations()
    t.truthy(true, "calling before AceDB:New does not raise")
    KCM.db = saved
end)

-- ---------------------------------------------------------------------------
-- v2 — macro bar introduction
-- ---------------------------------------------------------------------------

test("Database v2: a profile that predates the macro bar gets it on and unlocked", function(t)
    local KCM = h.loader.loadPure()
    -- Model the real upgrade shape: SavedVariables from a build with no macro
    -- bar at all, so the profile has no macroBar table.
    KCM.db.profile.macroBar = nil
    KCM.db.global = { schemaVersion = 1 }
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.macroBar.enabled, true, "bar enabled")
    t.eq(KCM.db.profile.macroBar.locked, false, "bar unlocked so the drag handle shows")
    t.eq(KCM.db.global.schemaVersion, KCM.Database.CURRENT_SCHEMA,
        "stamped past the v2 step and on to the current version")
end)

test("Database v2: an off/locked bar from an earlier build of the feature is turned on", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.enabled = false
    KCM.db.profile.macroBar.locked  = true
    KCM.db.global = { schemaVersion = 1 }
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.macroBar.enabled, true, "forced on once")
    t.eq(KCM.db.profile.macroBar.locked, false, "forced unlocked once")
end)

test("Database v2: the step is one-shot — a later opt-out survives the next login", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global = { schemaVersion = 1 }
    KCM.Database.RunMigrations()          -- upgrade happens
    KCM.db.profile.macroBar.enabled = false   -- user then turns it off
    KCM.db.profile.macroBar.locked  = true
    KCM.Database.RunMigrations()          -- next login
    t.eq(KCM.db.profile.macroBar.enabled, false, "opt-out respected")
    t.eq(KCM.db.profile.macroBar.locked, true, "lock respected")
end)

test("Database v2: the migration leaves every other bar setting alone", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.buttonSize = 52
    KCM.db.profile.macroBar.order = { "FOOD" }
    KCM.db.global = { schemaVersion = 1 }
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.macroBar.buttonSize, 52, "geometry untouched")
    t.eqList(KCM.db.profile.macroBar.order, { "FOOD" }, "saved order untouched")
end)

test("Database v2: MigrateMacroBarV2 tolerates a nil profile", function(t)
    local KCM = h.loader.loadPure()
    t.falsy(KCM.Database.MigrateMacroBarV2(nil), "returns false rather than erroring")
end)

-- ---------------------------------------------------------------------------
-- v3 — the label outline boolean becomes a font-flags string
-- ---------------------------------------------------------------------------
--
-- A STORED VALUE CHANGED SHAPE (options-ui-§16's font block), so it takes a
-- migration rather than an edit to defaults/Profile.lua. Without the step the
-- panel meets a boolean where it expects one of five strings and the player
-- silently loses a setting they had already made.
--
-- red under: dropping the `if g.schemaVersion < 3` arm from RunMigrations, or
-- mapping `false` to "OUTLINE" (which is the shape the whole conversion exists
-- to get right).

test("Database v3: an outlined label from an older profile reads back as OUTLINE", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.labelFlags = nil
    KCM.db.profile.macroBar.labelOutline = true
    KCM.db.global = { schemaVersion = 2 }
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.macroBar.labelFlags, "OUTLINE", "true becomes the OUTLINE flag")
    t.eq(KCM.db.profile.macroBar.labelOutline, nil,
        "and the boolean is removed rather than left as a second copy")
end)

test("Database v3: an un-outlined label from an older profile reads back as no flags", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.labelFlags = nil
    KCM.db.profile.macroBar.labelOutline = false
    KCM.db.global = { schemaVersion = 2 }
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.macroBar.labelFlags, "",
        "false becomes the empty string, which is the stored value 'None' names")
end)

test("Database v3: a profile that already carries labelFlags is left alone", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.labelFlags   = "THICKOUTLINE"
    KCM.db.profile.macroBar.labelOutline = true
    KCM.db.global = { schemaVersion = 2 }
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.macroBar.labelFlags, "THICKOUTLINE",
        "the deliberate choice survives; the step is a conversion, not a reset")
end)

test("Database v3: MigrateLabelFlagsV3 tolerates a nil profile and a bar-less one", function(t)
    local KCM = h.loader.loadPure()
    t.falsy(KCM.Database.MigrateLabelFlagsV3(nil), "nil profile returns false")
    t.falsy(KCM.Database.MigrateLabelFlagsV3({}), "a profile with no macroBar returns false")
end)
