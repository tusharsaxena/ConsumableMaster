-- defaults/Defaults_StatPriority.lua — Seed stat priority per class/spec.
--
-- Keyed by "<classID>_<specID>" (see SpecHelper.MakeKey). `specID` is the
-- Blizzard-global spec identifier returned by GetSpecializationInfo, NOT a
-- 1..N index — e.g. Shaman Restoration is spec id 264, not 3. Using the
-- global id keeps the key stable across UI reorderings and matches what
-- SpecHelper.GetCurrent() produces at runtime.
--
-- Two lists, one per client (clients-§5), in two SHAPES (core/SpecHelper.lua
-- SpecHelper.STATS):
--
-- Retail values:
--   primary    : "STR" | "AGI" | "INT"            -- dominant stat
--   secondary  : ordered list of secondary stats the spec favors
--                ("HASTE" | "CRIT" | "MASTERY" | "VERSATILITY")
--
-- WoW Forever values (issue #48):
--   ranked     : ONE ordered list over Forever's stats, no primary. Position 1
--                weighs the most; a stat left out is excluded and weighs nothing.
--                (STR AGI INT STA SPI AP SP FIRE_SP FROST_SP SHADOW_SP HEAL HIT
--                CRIT ARMOR HEALTH MANA MANA_REGEN)
--
-- Forever has ONE spec per class (spec ids 1482-1491), so each order is the
-- class's general-purpose one, drafted from vanilla theorycraft norms for a
-- leveling and dungeon character; a player who tanks or heals drags the stats
-- their role wants to the top. Every class ranks at least eight stats, so nothing
-- starts all-excluded (the issue's original complaint). Per class:
--   Warrior  STR first (2 attack power each), then AP; AGI for crit and dodge;
--            hit before crit (the miss table); STA/ARMOR/HEALTH for tanking. No
--            caster stat: a warrior has no mana.
--   Paladin  STR and AP for Retribution-style leveling; CRIT/HIT; then INT and
--            the healing stats a Holy paladin drags up; STA/ARMOR last.
--   Hunter   AGI first (ranged AP, crit), AP, HIT, CRIT; INT and MANA_REGEN for
--            the mana bar; STA. STR is excluded: it gives a hunter no ranged AP.
--   Rogue    AGI, AP, HIT, CRIT, STR (1 AP each), STA. No caster stat.
--   Priest   Shadow-style leveling: SP, SHADOW_SP, INT, SPI (Spirit Tap and
--            regen), then HEAL and MANA_REGEN for a healer; STA last.
--   Shaman   Enhancement-style leveling: STR, AP, AGI, CRIT, HIT; then INT, SP,
--            HEAL and MANA_REGEN for the caster side; STA/ARMOR.
--   Mage     SP, then INT; FROST_SP before FIRE_SP (frost levels); HIT, CRIT;
--            SPI and MANA_REGEN for the mana bar; STA last. SHADOW_SP excluded.
--   Warlock  SP, SHADOW_SP, then STA (Life Tap and the pet's health feed off it),
--            INT, HIT, CRIT, FIRE_SP (Destruction's Immolate and Soul Fire), SPI.
--   Druid    Feral-style leveling: STR, AGI, AP, CRIT, HIT; then INT, SP, HEAL,
--            MANA_REGEN for the caster forms; STA/ARMOR (bear form).
--
-- Used by the Ranker to pick the best-fit stat food / flask / combat potion
-- when no user override is present.
--
-- Class IDs (Blizzard API): 1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue, 5 Priest,
-- 6 Death Knight, 7 Shaman, 8 Mage, 9 Warlock, 10 Monk, 11 Druid, 12 Demon
-- Hunter, 13 Evoker.
--
-- ---------------------------------------------------------------------------
-- HOW TO REFRESH THIS TABLE
-- ---------------------------------------------------------------------------
-- Source: https://www.archon.gg/wow — per-spec Mythic+ overview pages.
-- URL pattern (replace <spec> and <class> with the slug, keep the rest):
--
--   https://www.archon.gg/wow/builds/<spec>/<class>/mythic-plus/overview/10/all-dungeons/this-week
--
-- Examples:
--   .../builds/blood/death-knight/mythic-plus/overview/10/all-dungeons/this-week
--   .../builds/restoration/shaman/mythic-plus/overview/10/all-dungeons/this-week
--   .../builds/beast-mastery/hunter/mythic-plus/overview/10/all-dungeons/this-week
--
-- Each page has a "Stat Priority" block near the top — primary stat, then an
-- ordered list of secondary stats (Crit / Haste / Mastery / Versatility).
-- Copy that order into the `secondary` array below. The `primary` field is
-- fixed per spec (armor class determines it) and almost never changes
-- between patches.
--
-- Spec slugs archon.gg uses (for copy-paste when refreshing):
--   Warrior       : arms, fury, protection
--   Paladin       : holy, protection, retribution
--   Hunter        : beast-mastery, marksmanship, survival
--   Rogue         : assassination, outlaw, subtlety
--   Priest        : discipline, holy, shadow
--   Death-Knight  : blood, frost, unholy                (class slug: death-knight)
--   Shaman        : elemental, enhancement, restoration
--   Mage          : arcane, fire, frost
--   Warlock       : affliction, demonology, destruction
--   Monk          : brewmaster, windwalker, mistweaver
--   Druid         : balance, feral, guardian, restoration
--   Demon-Hunter  : havoc, vengeance, devourer           (class slug: demon-hunter)
--   Evoker        : devastation, preservation, augmentation
--
-- Refresh cadence: once per major patch (0.1, 0.2, 1.0, ...) is enough —
-- archon.gg re-ranks weekly but the top-to-bottom order only shuffles
-- significantly around balance patches. When refreshing:
--   1. Walk the 40 specs above.
--   2. Paste the new ordering into the relevant row.
--   3. Update the "Last refreshed" line directly below.
--   4. Bump defaults/README.md's snapshot date to match.
--
-- Last refreshed: 2026-04-21 from archon.gg (WoW Midnight 12.0).
-- Refresh attempted 2026-11-27 (issue #48): archon.gg answered HTTP 403 to every
-- fetch, so no page could be read and Retail's orders are unchanged.
-- Forever's orders: drafted 2026-11-27 (issue #48) from vanilla norms, above.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.STAT_PRIORITY = KCM.PerClient({
    retail = {
        -- Warrior
        ["1_71"] = { primary = "STR", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },        -- Arms
        ["1_72"] = { primary = "STR", secondary = { "HASTE", "MASTERY", "CRIT", "VERSATILITY" } },        -- Fury
        ["1_73"] = { primary = "STR", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },        -- Protection

        -- Paladin
        ["2_65"] = { primary = "INT", secondary = { "HASTE", "MASTERY", "CRIT", "VERSATILITY" } },        -- Holy
        ["2_66"] = { primary = "STR", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },        -- Protection
        ["2_70"] = { primary = "STR", secondary = { "MASTERY", "CRIT", "HASTE", "VERSATILITY" } },        -- Retribution

        -- Hunter
        ["3_253"] = { primary = "AGI", secondary = { "CRIT", "MASTERY", "HASTE", "VERSATILITY" } },       -- Beast Mastery
        ["3_254"] = { primary = "AGI", secondary = { "CRIT", "MASTERY", "HASTE", "VERSATILITY" } },       -- Marksmanship
        ["3_255"] = { primary = "AGI", secondary = { "MASTERY", "CRIT", "HASTE", "VERSATILITY" } },       -- Survival

        -- Rogue
        ["4_259"] = { primary = "AGI", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },       -- Assassination
        ["4_260"] = { primary = "AGI", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },       -- Outlaw
        ["4_261"] = { primary = "AGI", secondary = { "MASTERY", "CRIT", "HASTE", "VERSATILITY" } },       -- Subtlety

        -- Priest
        ["5_256"] = { primary = "INT", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },       -- Discipline
        ["5_257"] = { primary = "INT", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },       -- Holy
        ["5_258"] = { primary = "INT", secondary = { "HASTE", "MASTERY", "CRIT", "VERSATILITY" } },       -- Shadow

        -- Death Knight
        ["6_250"] = { primary = "STR", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },       -- Blood
        ["6_251"] = { primary = "STR", secondary = { "CRIT", "MASTERY", "HASTE", "VERSATILITY" } },       -- Frost
        ["6_252"] = { primary = "STR", secondary = { "MASTERY", "CRIT", "HASTE", "VERSATILITY" } },       -- Unholy

        -- Shaman
        ["7_262"] = { primary = "INT", secondary = { "MASTERY", "CRIT", "HASTE", "VERSATILITY" } },       -- Elemental
        ["7_263"] = { primary = "AGI", secondary = { "MASTERY", "HASTE", "CRIT", "VERSATILITY" } },       -- Enhancement
        ["7_264"] = { primary = "INT", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },       -- Restoration

        -- Mage
        ["8_62"] = { primary = "INT", secondary = { "MASTERY", "HASTE", "CRIT", "VERSATILITY" } },        -- Arcane
        ["8_63"] = { primary = "INT", secondary = { "HASTE", "MASTERY", "CRIT", "VERSATILITY" } },        -- Fire
        ["8_64"] = { primary = "INT", secondary = { "CRIT", "MASTERY", "HASTE", "VERSATILITY" } },        -- Frost

        -- Warlock
        ["9_265"] = { primary = "INT", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },       -- Affliction
        ["9_266"] = { primary = "INT", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },       -- Demonology
        ["9_267"] = { primary = "INT", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },       -- Destruction

        -- Monk
        ["10_268"] = { primary = "AGI", secondary = { "CRIT", "VERSATILITY", "MASTERY", "HASTE" } },      -- Brewmaster
        ["10_269"] = { primary = "AGI", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },      -- Windwalker
        ["10_270"] = { primary = "INT", secondary = { "HASTE", "CRIT", "VERSATILITY", "MASTERY" } },      -- Mistweaver

        -- Druid
        ["11_102"] = { primary = "INT", secondary = { "MASTERY", "HASTE", "CRIT", "VERSATILITY" } },      -- Balance
        ["11_103"] = { primary = "AGI", secondary = { "MASTERY", "HASTE", "CRIT", "VERSATILITY" } },      -- Feral
        ["11_104"] = { primary = "AGI", secondary = { "HASTE", "MASTERY", "VERSATILITY", "CRIT" } },      -- Guardian
        ["11_105"] = { primary = "INT", secondary = { "HASTE", "MASTERY", "CRIT", "VERSATILITY" } },      -- Restoration

        -- Demon Hunter
        ["12_577"] = { primary = "AGI", secondary = { "CRIT", "MASTERY", "HASTE", "VERSATILITY" } },      -- Havoc
        ["12_581"] = { primary = "AGI", secondary = { "HASTE", "CRIT", "MASTERY", "VERSATILITY" } },      -- Vengeance
        -- Devourer: secondary order UNSOURCED. On 2026-10-07 the archon.gg page
        -- (.../builds/devourer/demon-hunter/mythic-plus/overview/10/all-dungeons/this-week)
        -- answered HTTP 403 to every fetch, so no order could be read. Left empty
        -- rather than guessed; fill it in on the next refresh.
        ["12_1480"] = { primary = "INT", secondary = {} },                                              -- Devourer

        -- Evoker
        ["13_1467"] = { primary = "INT", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },     -- Devastation
        ["13_1468"] = { primary = "INT", secondary = { "MASTERY", "HASTE", "CRIT", "VERSATILITY" } },     -- Preservation
        ["13_1473"] = { primary = "INT", secondary = { "CRIT", "HASTE", "MASTERY", "VERSATILITY" } },     -- Augmentation
    },
    -- One spec per class; the rationale per class is in the header above.
    forever = {
        ["1_1491"]  = { ranked = { "STR", "AP", "AGI", "HIT", "CRIT", "STA", "ARMOR", "HEALTH" } },       -- Warrior
        ["2_1486"]  = { ranked = { "STR", "AP", "CRIT", "HIT", "AGI", "INT", "HEAL", "SP", "MANA_REGEN",
                                   "SPI", "MANA", "STA", "ARMOR", "HEALTH" } },                            -- Paladin
        ["3_1485"]  = { ranked = { "AGI", "AP", "HIT", "CRIT", "INT", "MANA_REGEN", "STA", "SPI", "MANA",
                                   "ARMOR", "HEALTH" } },                                                  -- Hunter
        ["4_1488"]  = { ranked = { "AGI", "AP", "HIT", "CRIT", "STR", "STA", "ARMOR", "HEALTH" } },       -- Rogue
        ["5_1487"]  = { ranked = { "SP", "SHADOW_SP", "INT", "SPI", "HEAL", "MANA_REGEN", "MANA", "HIT",
                                   "CRIT", "STA", "HEALTH", "ARMOR" } },                                   -- Priest
        ["7_1489"]  = { ranked = { "STR", "AP", "AGI", "CRIT", "HIT", "INT", "SP", "HEAL", "MANA_REGEN",
                                   "SPI", "MANA", "STA", "ARMOR", "HEALTH" } },                            -- Shaman
        ["8_1482"]  = { ranked = { "SP", "INT", "FROST_SP", "FIRE_SP", "HIT", "CRIT", "SPI", "MANA_REGEN",
                                   "MANA", "STA", "HEALTH", "ARMOR" } },                                   -- Mage
        ["9_1490"]  = { ranked = { "SP", "SHADOW_SP", "STA", "INT", "HIT", "CRIT", "FIRE_SP", "SPI",
                                   "MANA_REGEN", "MANA", "HEALTH", "ARMOR" } },                            -- Warlock
        ["11_1484"] = { ranked = { "STR", "AGI", "AP", "CRIT", "HIT", "INT", "SP", "HEAL", "MANA_REGEN",
                                   "SPI", "MANA", "STA", "ARMOR", "HEALTH" } },                            -- Druid
    },
})
