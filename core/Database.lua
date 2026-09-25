-- Database.lua — SavedVariables migration runner.
--
-- Invoked from Core:OnInitialize right after AceDB:New, and again from the
-- OnProfileChanged/Copied/Reset hooks in core/ConsumableMaster.lua. The runner
-- exists so schema changes have a single, ordered home rather than ad-hoc guards
-- scattered across modules (savedvariables-§1).
--
-- TWO STAMPS, one per scope, because a step belongs to whichever scope it writes.
-- `db.global.schemaVersion` is the account-wide marker savedvariables-§1 asks for
-- and gates anything that migrates account-wide storage. Its shipped default is
-- 0 (defaults/Profile.lua), the pre-migration floor and never a real version, so
-- AceDB's logout strip can never erase a stamp this runner wrote. Every step
-- below writes `db.profile`, so each is gated on `db.profile.schemaVersion` —
-- that profile's own record of how far it has been walked, which is not a
-- shipped default at all. See RunMigrations for why the account-wide gate alone
-- was wrong.
--
-- THE RUNNER OWNS BOTH STAMPS. No step writes `schemaVersion`; the runner
-- advances a stamp only on the line after the step call, so a step that raises
-- leaves the stamp at the last completed version and the next load retries it.
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
-- THE OLD KEY IS WHAT MARKS AN UNMIGRATED PROFILE, and getting that wrong is the
-- one way this step can look right and do the opposite. The guard used to read
-- `if bar.labelFlags == nil`, which cannot be true on a real client: AceDB's
-- copyDefaults rawsets every missing scalar from `dbDefaults` into the live
-- profile table before anything downstream of AceDB:New runs, and
-- defaults/Profile.lua ships `labelFlags = "OUTLINE"`. By the time RunMigrations
-- looks, `labelFlags` is always a string, so the conversion never fired and the
-- only line doing any work was the one that deleted `labelOutline` -- a player
-- who had unticked the outline lost that choice to the shipped default, which is
-- exactly the loss this step exists to prevent. It was invisible because every
-- case covering it set `labelFlags = nil` by hand first, a state AceDB does not
-- hand anyone.
--
-- So the guard tests `labelOutline`, the key a pre-v3 profile carries and no
-- other profile does. The two never coexist in a SavedVariables file -- the
-- boolean was retired in the same build that introduced the string -- so a
-- profile whose `labelFlags` is a deliberate choice has already been through
-- here, no longer carries the boolean, and is left alone.
--
-- The old key is REMOVED as it is converted. Left behind it is a second copy of a
-- setting that no longer has a control, and the next reader to guess which one
-- wins gets it wrong half the time.
function D.MigrateLabelFlagsV3(profile)
    local bar = type(profile) == "table" and profile.macroBar
    if type(bar) ~= "table" then return false end
    if bar.labelOutline ~= nil then
        bar.labelFlags = bar.labelOutline and "OUTLINE" or ""
        bar.labelOutline = nil
    end
    return true
end

-- Run any pending migrations in order. Safe to call every login AND on every
-- profile switch; each step is guarded on the stored version for the scope it
-- writes, so it runs at most once per store.
--
-- WHY THE ACCOUNT-WIDE GATE ALONE WAS WRONG, since the shape below is the whole
-- point of it. Both steps write `db.profile`, and both used to be gated on
-- `g.schemaVersion`, which is account-wide. The moment ANY profile in the file
-- had been walked to the current version the account read as current, so every
-- other profile was skipped from then on, whatever build had written it. The
-- OnProfileChanged hook in core/ConsumableMaster.lua exists to catch exactly that
-- and could not: it re-ran a pass gated on a stamp that had already moved, so it
-- ran and did nothing. Gating per profile is what makes that hook do real work —
-- a profile switched to for the first time under this build is walked forward on
-- arrival, which is the only moment it can be.
--
-- THE ONE-TIME COST, stated because it is real and a player will meet it. No
-- profile carries a stamp until this build writes one, so the first pass over
-- each existing profile starts at v1 and meets the v2 step once — the bar comes
-- back on and unlocked, and a deliberate off has to be set again. That is the
-- price of never having recorded WHICH profile the old runner migrated; the
-- information is not in the file to recover, and seeding the profile stamp from
-- the account's would simply reinstate the defect for every profile at once. It
-- is paid once per profile, and the stamp written on the way out is what makes it
-- once. The v3 step costs nothing on a re-run: it converts only where the retired
-- `labelOutline` boolean is still there, and the conversion is what removes it, so
-- a second pass finds nothing left to do.
-- The PROFILE-scoped steps, walked in order on whichever profile is live.
-- Answers the version the profile arrived at, which is what the report below
-- needs and what nothing else can recover once the stamp has been written: a
-- profile that was already current is indistinguishable from one this pass
-- walked forward the moment `p.schemaVersion` is set.
--
-- Each step is gated on the stamp rather than on the one `from` the function
-- entered with, so a profile that is several versions behind meets every step
-- between where it is and where this build stands, in order.
--
-- A profile with no stamp is a pre-stamp v1 profile, hence `or 1` rather than
-- the account's 0 floor: that is the one-time cost documented above.
--
-- THE INVARIANT: each stamp line sits AFTER its step call. A step that raises
-- never reaches its stamp, so the profile is left at the last completed version
-- and the error propagates out of RunMigrations before the account stamp moves.
--
-- These steps run on EVERY profile, not only the one live at the upgrade login:
-- the OnProfileChanged / Copied / Reset hooks in core/ConsumableMaster.lua call
-- RunMigrations on each profile as it arrives, and the per-profile stamp decides
-- what is left to do. They are never gated on the account stamp alone. That is
-- savedvariables-§1's second allowed shape for a profile-scoped step.
local function migrateProfile(p)
    p.schemaVersion = p.schemaVersion or 1
    local pFrom = p.schemaVersion

    if p.schemaVersion < 2 then
        D.MigrateMacroBarV2(p)
        p.schemaVersion = 2
    end

    if p.schemaVersion < 3 then
        D.MigrateLabelFlagsV3(p)
        p.schemaVersion = 3
    end

    -- Future PROFILE migrations go here, e.g.:
    --   if p.schemaVersion < 4 then ... ; p.schemaVersion = 4 end

    p.schemaVersion = D.CURRENT_SCHEMA
    return pFrom
end

-- What the run did, said once and only when a version actually moved: a login
-- that migrates nothing says nothing, which is what keeps the console readable
-- on every subsequent load. The profile line names the profile, because the
-- whole defect this file was repaired for was not knowing WHICH profile a
-- migration had touched.
local function reportMigrations(db, accountFrom, accountTo, profileFrom)
    if not (KCM.State and KCM.State.debug) then return end
    if accountFrom ~= accountTo then
        KCM.Debug("DB", "migrated account schema v%s -> v%s", accountFrom, accountTo)
    end
    if profileFrom and profileFrom ~= D.CURRENT_SCHEMA then
        local key = db.GetCurrentProfile and db:GetCurrentProfile() or "?"
        KCM.Debug("DB", "migrated profile '%s' schema v%s -> v%s",
            key, profileFrom, D.CURRENT_SCHEMA)
    end
end

function D.RunMigrations()
    local db = KCM.db
    if not (db and db.global) then return end
    local g = db.global
    g.schemaVersion = g.schemaVersion or 0
    local from = g.schemaVersion

    -- ACCOUNT-WIDE steps go here, gated on `g.schemaVersion`. There are none
    -- today; the marker stays so the next one written has an obvious home that
    -- is not the profile block below. Getting that wrong in either direction is
    -- the defect this file was repaired for.

    -- PROFILE-SCOPED steps. `p` is whichever profile is live right now — the one
    -- AceDB merged at login, or the one OnProfileChanged has just switched in.
    local p = db.profile
    local pFrom
    if type(p) == "table" then
        pFrom = migrateProfile(p)
    end

    g.schemaVersion = D.CURRENT_SCHEMA
    reportMigrations(db, from, g.schemaVersion, pFrom)
end
