-- test_database.lua — SavedVariables migration runner (KCM.Database).

local h = require("harness")
local test = h.test

test("Database.CURRENT_SCHEMA is the version the code understands", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.Database.CURRENT_SCHEMA, 1, "current schema is v1")
end)

test("Database.RunMigrations stamps a fresh account at the current schema", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global = {}                     -- fresh account: no schemaVersion yet
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, 1, "stamped to current schema")
end)

test("Database.RunMigrations is idempotent across repeated logins", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.global = { schemaVersion = 1 }
    KCM.Database.RunMigrations()
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, 1, "still current after repeated runs")
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
        "the version lives account-wide in global, never per profile (standard §2.2)")
end)

test("Database.RunMigrations is a safe no-op before the DB exists", function(t)
    local KCM = h.loader.loadPure()
    local saved = KCM.db
    KCM.db = nil
    KCM.Database.RunMigrations()
    t.truthy(true, "calling before AceDB:New does not raise")
    KCM.db = saved
end)
