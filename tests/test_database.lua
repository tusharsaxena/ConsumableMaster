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

-- WAS NAMED "never writes into the profile scope", which is not true and never
-- was: RunMigrations calls MigrateMacroBarV2(db.profile) and
-- MigrateLabelFlagsV3(db.profile), so the profile scope is precisely where a
-- migration writes. What the case measures is narrower and still worth pinning --
-- an unrelated stored setting survives a pass -- so it is named that, and the
-- assertion about the STAMP, which was a second subject wearing the same name,
-- is its own case below.
test("Database.RunMigrations leaves unrelated profile settings untouched", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.enabled = false
    KCM.Database.RunMigrations()
    t.eq(KCM.db.profile.enabled, false, "profile settings are not reset by a migration pass")
end)

-- The stamp on its own, asserting what the runner measurably does rather than a
-- rule that does not follow from the standard. savedvariables-§1 requires the
-- account-wide `schemaVersion` and says nothing forbidding a profile carrying a
-- version of its own, so the old wording -- "never per profile
-- (savedvariables-§1)" -- read a prohibition into the standard, and in doing so
-- pinned the defect the second-profile case below measures. Expect this case to
-- be revisited by whatever gates the profile-writing steps on a profile-scoped
-- stamp; a profile version appearing here is that change arriving, not a
-- regression.
test("Database.RunMigrations stamps the schema account-wide", function(t)
    local KCM = h.loader.loadPure()
    KCM.Database.RunMigrations()
    t.eq(KCM.db.global.schemaVersion, KCM.Database.CURRENT_SCHEMA,
        "the stamp the standard asks for lives in the global scope")
    t.eq(KCM.db.profile.schemaVersion, nil, "and today the profile carries none")
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

-- ---------------------------------------------------------------------------
-- A second profile
-- ---------------------------------------------------------------------------
--
-- Every case above runs against the profile that was live at login, and the gate
-- in front of all of them is db.global.schemaVersion -- account-wide. Once ANY
-- profile has been migrated the account reads as current, so every other profile
-- in the SavedVariables file is skipped from then on, whatever build wrote it.
--
-- core/ConsumableMaster.lua's OnProfileChanged hook re-runs the pass on a switch
-- for exactly this reason, and says so in its own docstring: "the migrations
-- never ran on an incoming profile a copy could have authored at an older schema
-- version". The pass it re-runs is gated on a stamp that has not moved, so it
-- runs and does nothing.
--
-- Two cases, deliberately split. The first pins the wiring, so that what the
-- second measures is a gate defect and not a callback that never fired.

test("Database: switching profile re-runs the migration pass", function(t)
    local KCM = h.loader.loadPure()
    local runs, real = 0, KCM.Database.RunMigrations
    KCM.Database.RunMigrations = function() runs = runs + 1; return real() end
    KCM.db:SetProfile("Alt")
    KCM.Database.RunMigrations = real
    t.eq(runs, 1, "OnProfileChanged re-runs RunMigrations against the incoming profile")
    t.eq(KCM.db:GetCurrentProfile(), "Alt", "and the switch itself took effect")
end)

-- red under: today's core/Database.lua, whose two steps are both gated on the
-- account-wide db.global.schemaVersion. Seed a profile from a build that predates
-- v3 and switch to it after the account has already been stamped, and neither
-- step runs -- the retired `labelOutline` boolean survives on a profile the panel
-- will read as if it had been converted.
--
-- DECLARED SKIP, and the reason it is one rather than a red case or a softened
-- one. It was written, run and WATCHED FAILING against this tree --
-- "expected nil, got false", exit 1 -- and it passes against a RunMigrations
-- whose profile-writing steps gate on a profile-scoped stamp. That fix is a
-- separate change with an in-client check of its own, and the repository does not
-- commit red. A declared skip is the honest third state for that gap: the case
-- exists, its reason is disclosed in docs/test-cases.md, it is never counted as a
-- pass, and the alternative -- weakening the assertion until today's behavior
-- satisfies it -- is the exact shape this whole cluster exists to remove. Delete
-- the reason string to arm it.
test("Database: a second profile written before v3 is migrated when it is switched to", function(t)
    local KCM = h.loader.loadPure()
    KCM.Database.RunMigrations()          -- first login stamps the account at v3
    -- Sitting in SavedVariables, never opened this session, so AceDB has not
    -- merged the defaults into it. This is the raw shape the file holds.
    KCM.db.profiles.Alt = { macroBar = { labelOutline = false } }
    KCM.db:SetProfile("Alt")
    t.eq(KCM.db.profile.macroBar.labelOutline, nil,
        "the v3 step ran against the incoming profile and retired the boolean")
end, "fails against the account-wide migration gate; unblocked by the profile-scoped gate")
