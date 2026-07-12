-- Database.lua — SavedVariables migration runner.
--
-- Invoked from Core:OnInitialize right after AceDB:New. Migrations are keyed
-- off `db.global.schemaVersion` (account-wide — schema shape is not per
-- profile). The current schema is version 1; the runner exists so future
-- schema changes have a single, ordered home rather than ad-hoc guards
-- scattered across modules (standard §5.1).

local _, NS = ...
local KCM = NS
KCM.Database = KCM.Database or {}
local D = KCM.Database

-- Latest schema version the code understands. Bump when you add a migration
-- step below.
D.CURRENT_SCHEMA = 1

-- Run any pending migrations in order. Safe to call every login; each step is
-- guarded on the stored version so it runs at most once.
function D.RunMigrations()
    local db = KCM.db
    if not (db and db.global) then return end
    local g = db.global
    g.schemaVersion = g.schemaVersion or 1

    -- Future migrations go here, e.g.:
    --   if g.schemaVersion < 2 then ... ; g.schemaVersion = 2 end

    g.schemaVersion = D.CURRENT_SCHEMA
end
