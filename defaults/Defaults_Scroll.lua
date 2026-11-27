-- defaults/Defaults_Scroll.lua — Seed list for KCM_SCROLL (WoW Forever only).
--
-- Vanilla scrolls, consumable subclass 4 (core/Classifier.lua matches the
-- subclass alone). Spec-aware like ELIXIR: the Ranker weights each scroll's
-- stat against the active spec's stat priority, and a scroll with no stat
-- (Protection, armor) ranks after the stat scrolls. One scroll per stat per
-- ~10-level band, the top rank of each; auto-discovery takes the rest.
--
-- Source: wago.tools DB2 (wowf), ForeverDB (evidence only, no rows copied),
-- the owner's Auctionator and /cm probe seed stores (issue #46).
-- Last refresh: 2026-11-27 against WoW Forever 1.60.1.71139
-- (tools/seeds/seeds.py, docs/seed-research/2026-11-27-forever/).

local _, NS = ...
local KCM = NS
KCM.SEED = KCM.SEED or {}

KCM.SEED.SCROLL = KCM.PerClient({
    -- The category is WoW Forever's alone (defaults/Categories.lua, clients-§4).
    retail = {},
    forever = {
        954,  -- Scroll of Strength; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, vendor), AH, probe (ah)
        955,  -- Scroll of Intellect; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, quest, vendor), AH, probe (ah)
        1180,  -- Scroll of Stamina; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, quest, vendor), AH, probe (ah)
        1181,  -- Scroll of Spirit; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        1477,  -- Scroll of Agility II; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        1478,  -- Scroll of Protection II; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        1711,  -- Scroll of Stamina II; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        1712,  -- Scroll of Spirit II; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        2289,  -- Scroll of Strength II; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        3012,  -- Scroll of Agility; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, vendor), AH, probe (ah)
        3013,  -- Scroll of Protection; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        4419,  -- Scroll of Intellect III; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        4421,  -- Scroll of Protection III; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        4422,  -- Scroll of Stamina III; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        4424,  -- Scroll of Spirit III; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH, probe (ah)
        4425,  -- Scroll of Agility III; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        4426,  -- Scroll of Strength III; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        10305,  -- Scroll of Protection IV; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        10306,  -- Scroll of Spirit IV; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        10307,  -- Scroll of Stamina IV; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        10308,  -- Scroll of Intellect IV; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        10309,  -- Scroll of Agility IV; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        10310,  -- Scroll of Strength IV; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: ForeverDB (container, drop, object, vendor), AH
        277483,  -- Scroll of Frog Familiar; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah)
        277493,  -- Scroll of Cat Familiar; added from the 2026-11-27 wago.tools validation (1.60.1.71139); Evidence: AH, probe (ah)
    },
})
