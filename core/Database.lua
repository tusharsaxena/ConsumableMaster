-- Database.lua — SavedVariables migration runner.
--
-- Invoked from Core:OnInitialize right after AceDB:New. Migrations are keyed
-- off `db.global.schemaVersion` (account-wide — schema shape is not per
-- profile). The runner exists so schema changes have a single, ordered home
-- rather than ad-hoc guards scattered across modules (savedvariables-§1).
--
-- Version history:
--   1 — original shape.
--   2 — macro bar introduced. Sets it enabled + unlocked once (see below).
--   3 — the macro bar's label outline became a font-flags STRING.

local _, NS = ...
local KCM = NS
KCM.Database = KCM.Database or {}
local D = KCM.Database

-- Latest schema version the code understands. Bump when you add a migration
-- step below.
D.CURRENT_SCHEMA = 3

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

-- v3 — `macroBar.labelOutline` (a boolean) becomes `macroBar.labelFlags` (the
-- font-flags string every Ka0s font group declares, options-ui-§16).
--
-- A STORED VALUE CHANGED SHAPE, so it takes the full savedvariables treatment
-- rather than an edit to defaults/Profile.lua: a profile written before this
-- carries `labelOutline = true|false`, and a panel that meets a boolean where it
-- expects one of five strings loses the setting the player already made,
-- silently. `true` was the only outline the boolean could express, so it maps to
-- "OUTLINE" and `false` to "" (the stored value the "None" label names).
--
-- The old key is REMOVED in the same step. Left behind it is a second copy of a
-- setting that no longer has a control, and the next reader to guess which one
-- wins gets it wrong half the time.
function D.MigrateLabelFlagsV3(profile)
    local bar = type(profile) == "table" and profile.macroBar
    if type(bar) ~= "table" then return false end
    if bar.labelFlags == nil then
        bar.labelFlags = (bar.labelOutline ~= false) and "OUTLINE" or ""
    end
    bar.labelOutline = nil
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

    if g.schemaVersion < 3 then
        D.MigrateLabelFlagsV3(db.profile)
        g.schemaVersion = 3
    end

    -- Future migrations go here, e.g.:
    --   if g.schemaVersion < 3 then ... ; g.schemaVersion = 3 end

    g.schemaVersion = D.CURRENT_SCHEMA
    if KCM.State and KCM.State.debug and from ~= g.schemaVersion then
        KCM.Debug("DB", "migrated schema v%s -> v%s", from, g.schemaVersion)
    end
end
