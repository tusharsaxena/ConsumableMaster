-- defaults/Defaults_Flask.lua — Seed list for KCM_FLASK.
--
-- Combat flasks only. Midnight merged the legacy "Flask" and "Phial"
-- subtypes into a single "Flasks & Phials" subType string, so Haranir
-- profession phials (241310, 241312, 241316) ALSO classify as FLASK when
-- auto-discovered. They score 0 against combat stat priorities and sort
-- last, so they don't displace a combat flask — but they're intentionally
-- NOT seeded here to keep the default priority list clean.
--
-- Stat-per-spec is resolved by Ranker via Defaults_StatPriority + parsed
-- tooltip stat buffs. Vicious Thalassian Flask of Honor grants +15% honor,
-- not a combat stat, but it remains in the seed as a combat-usable flask
-- for PvP contexts.
--
-- Source: Method.gg Midnight consumables list, 2026-04-22.
-- See defaults/README.md to re-run the refresh.
-- WoW Forever Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied), the owner's
-- Auctionator and /cm probe seed stores (issue #46, which lifted the 2026-11-08 "empty by decision"
-- ruling). Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139 (tools/seeds/seeds.py,
-- docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.FLASK = KCM.PerClient({
    retail = {
        241326,  -- Flask of the Shattered Sun      (CRIT)
        241324,  -- Flask of the Blood Knights      (HASTE)
        241322,  -- Flask of the Magisters          (MASTERY)
        241321,  -- Flask of Thalassian Resistance  (VERSATILITY)
        241334,  -- Vicious Thalassian Flask of Honor (PvP honor-gain flask)
    },
    -- WoW Forever: the top tier per ~10-level band (per stat, for a stat-keyed list), built from
    -- offline stores on 2026-11-27 (issue #46; the owner lifted the 2026-11-08 "empty by decision"
    -- ruling that day). Forever's own subclasses and tables chose them, never Retail's list
    -- (clients-§5); each comment names its evidence. The bag scan finds every other tier.
    forever = {
        13510,  -- Flask of the Titans; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13511,  -- Flask of Distilled Wisdom; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13512,  -- Flask of Supreme Power; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
        13513,  -- Flask of Chromatic Resistance; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (recipe), AH, DB2 (crafted)
    },
})
