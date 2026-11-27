-- defaults/Defaults_Poison.lua — Seed lists for KCM_POISON (issue #47).
--
-- One category on both clients, with a different model on each (owner ruling 2026-11-27), and
-- the model is DATA picked once here, like the seed lists, so modules/Poison.lua never asks which
-- client it is on (clients-§3, clients-§5):
--
--   * WoW Forever: vanilla's poison ITEMS, applied per hand. Every rank of the five families the
--     owner named (Instant, Deadly, Crippling, Mind-numbing, Wound) is seeded; the player picks a
--     family per hand and the best owned rank of it is used. Consumable subclass 8, worded "Coats
--     a weapon with poison ..." (core/TooltipCache.lua's isVanillaPoison), so a rank not seeded
--     here is still found by the bag scan.
--   * Retail: since Legion a poison is a rogue CLASS SPELL that coats both weapons. Four lethal
--     and three non-lethal; Dragon-Tempered Blades lets a rogue keep two of each.
--
-- A non-rogue has none of these, so the category is present and its macro is the empty-state
-- line, as Healthstone is for a non-warlock (owner ruling 2026-11-27).
--
-- Sources: WoW Forever -- wago.tools ItemSparse + Item for product wowf (the ranks, their
-- required levels and their class 0 / subclass 8), the owner's ConsumableMasterProbeDB capture
-- (6947, 6949, 2892, 3775, 5237 and their tooltip wording) and the ForeverDB data addon, read as
-- evidence only (GPL; no row copied). Retail -- wago.tools SpellName for product wow, build
-- 12.1.5.70961 (2026-11-17). 2026-11-27.

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

-- The candidate set. Forever: every rank, lowest first within a family (the Ranker orders them by
-- required level, so the order here is only for reading). Retail: the seven poison spells.
KCM.SEED.POISON = KCM.PerClient({
    retail = {
        KCM.ID.AsSpell(315584),  -- Instant Poison
        KCM.ID.AsSpell(2823),    -- Deadly Poison
        KCM.ID.AsSpell(8679),    -- Wound Poison
        KCM.ID.AsSpell(381664),  -- Amplifying Poison
        KCM.ID.AsSpell(3408),    -- Crippling Poison
        KCM.ID.AsSpell(5761),    -- Numbing Poison
        KCM.ID.AsSpell(381637),  -- Atrophic Poison
    },
    forever = {
        6947,   -- Instant Poison
        6949,   -- Instant Poison II
        6950,   -- Instant Poison III
        8926,   -- Instant Poison IV
        8927,   -- Instant Poison V
        8928,   -- Instant Poison VI
        2892,   -- Deadly Poison
        2893,   -- Deadly Poison II
        8984,   -- Deadly Poison III
        8985,   -- Deadly Poison IV
        20844,  -- Deadly Poison V
        3775,   -- Crippling Poison
        3776,   -- Crippling Poison II
        5237,   -- Mind-numbing Poison
        6951,   -- Mind-numbing Poison II
        9186,   -- Mind-numbing Poison III
        10918,  -- Wound Poison
        10920,  -- Wound Poison II
        10921,  -- Wound Poison III
        10922,  -- Wound Poison IV
    },
})

-- Each seeded entry's family token: the Forever dropdown's value for an item, the Retail order
-- rows' member for a spell. A discovered Forever rank that is not here takes its family from its
-- name (modules/Poison.lua, FamilyOf).
KCM.SEED.POISON_FAMILY = KCM.PerClient({
    retail = {
        [KCM.ID.AsSpell(315584)] = "INSTANT",      -- Instant Poison
        [KCM.ID.AsSpell(2823)]   = "DEADLY",       -- Deadly Poison
        [KCM.ID.AsSpell(8679)]   = "WOUND",        -- Wound Poison
        [KCM.ID.AsSpell(381664)] = "AMPLIFYING",   -- Amplifying Poison
        [KCM.ID.AsSpell(3408)]   = "CRIPPLING",    -- Crippling Poison
        [KCM.ID.AsSpell(5761)]   = "NUMBING",      -- Numbing Poison
        [KCM.ID.AsSpell(381637)] = "ATROPHIC",     -- Atrophic Poison
    },
    forever = {
        [6947]  = "INSTANT",      -- Instant Poison
        [6949]  = "INSTANT",      -- Instant Poison II
        [6950]  = "INSTANT",      -- Instant Poison III
        [8926]  = "INSTANT",      -- Instant Poison IV
        [8927]  = "INSTANT",      -- Instant Poison V
        [8928]  = "INSTANT",      -- Instant Poison VI
        [2892]  = "DEADLY",       -- Deadly Poison
        [2893]  = "DEADLY",       -- Deadly Poison II
        [8984]  = "DEADLY",       -- Deadly Poison III
        [8985]  = "DEADLY",       -- Deadly Poison IV
        [20844] = "DEADLY",       -- Deadly Poison V
        [3775]  = "CRIPPLING",    -- Crippling Poison
        [3776]  = "CRIPPLING",    -- Crippling Poison II
        [5237]  = "MINDNUMBING",  -- Mind-numbing Poison
        [6951]  = "MINDNUMBING",  -- Mind-numbing Poison II
        [9186]  = "MINDNUMBING",  -- Mind-numbing Poison III
        [10918] = "WOUND",        -- Wound Poison
        [10920] = "WOUND",        -- Wound Poison II
        [10921] = "WOUND",        -- Wound Poison III
        [10922] = "WOUND",        -- Wound Poison IV
    },
})

-- The model, picked once like the lists above (not a KCM.SEED list: tools/seeds/seeds.py reads
-- only those). `hands`: a family dropdown per weapon hand over `families`, in dropdown order.
-- `spells`: an ordered Lethal and Non-lethal list over the tokens below, and the talent that
-- doubles how many of each a rogue may keep (Dragon-Tempered Blades, 381801).
KCM.POISON_MODEL = KCM.PerClient({
    retail = {
        kind         = "spells",
        lethal       = { "INSTANT", "DEADLY", "WOUND", "AMPLIFYING" },
        nonLethal    = { "CRIPPLING", "NUMBING", "ATROPHIC" },
        doubleTalent = 381801,
    },
    forever = {
        kind     = "hands",
        families = { "INSTANT", "DEADLY", "CRIPPLING", "MINDNUMBING", "WOUND" },
    },
})
