-- Database.lua — SavedVariables migration runner.
--
-- Invoked from Core:OnInitialize right after AceDB:New. Migrations are keyed
-- off `db.global.schemaVersion` (account-wide — schema shape is not per
-- profile). The runner exists so schema changes have a single, ordered home
-- rather than ad-hoc guards scattered across modules (standard §5.1).
--
-- Version history:
--   1 — original shape.
--   2 — macro bar introduced. Sets it enabled + unlocked once (see below).

local _, NS = ...
local KCM = NS
KCM.Database = KCM.Database or {}
local D = KCM.Database

-- Latest schema version the code understands. Bump when you add a migration
-- step below.
D.CURRENT_SCHEMA = 2

-- v2 — introduce the macro bar to a profile written before it existed.
--
-- New installs need nothing here: AceDB injects `dbDefaults.profile.macroBar`
-- (enabled + unlocked) into a fresh profile. This step exists for the upgrade
-- path, where the profile predates the feature and may carry a partial
-- macroBar table from an earlier build of it — force the bar on and unlocked so
-- an upgrading user meets it exactly like a new one does.
--
-- Deliberately one-shot: the schemaVersion bump below means a later, deliberate
-- "off" or "locked" is never stomped on the next login. Exposed for tests.
function D.MigrateMacroBarV2(profile)
    if type(profile) ~= "table" then return false end
    profile.macroBar = profile.macroBar or {}
    profile.macroBar.enabled = true
    profile.macroBar.locked  = false
    return true
end

-- Run any pending migrations in order. Safe to call every login; each step is
-- guarded on the stored version so it runs at most once.
function D.RunMigrations()
    local db = KCM.db
    if not (db and db.global) then return end
    local g = db.global
    g.schemaVersion = g.schemaVersion or 1
    local from = g.schemaVersion

    if g.schemaVersion < 2 then
        D.MigrateMacroBarV2(db.profile)
        g.schemaVersion = 2
    end

    -- Future migrations go here, e.g.:
    --   if g.schemaVersion < 3 then ... ; g.schemaVersion = 3 end

    g.schemaVersion = D.CURRENT_SCHEMA
    if KCM.State and KCM.State.debug and from ~= g.schemaVersion then
        KCM.Debug("DB", "migrated schema v%s -> v%s", from, g.schemaVersion)
    end
end
