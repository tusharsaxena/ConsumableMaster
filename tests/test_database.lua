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
