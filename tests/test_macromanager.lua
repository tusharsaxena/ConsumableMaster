-- tests/test_macromanager.lua — pure body builders in MacroManager.lua:
--   M.BuildBody(catKey, itemID) and M.BuildCompositeBody(cat, pickFor).

local h = require("harness")

h.suite("macromanager", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local M    = KCM.MacroManager

    -- ---- BuildBody: item pick ----
    t.eq(M.BuildBody("FOOD", 12345), "#showtooltip\n/use item:12345",
        "item pick → #showtooltip + /use item:<id>")
    t.eq(M.BuildBody("HP_POT", 171267), "#showtooltip\n/use item:171267",
        "item pick uses the numeric id verbatim")

    -- ---- BuildBody: spell pick (negative sentinel + mock spell name) ----
    mock.setSpell(1231411, { name = "Recuperate", known = true })
    local spellID = KCM.ID.AsSpell(1231411)   -- negative sentinel
    t.truthy(KCM.ID.IsSpell(spellID), "AsSpell yields a spell sentinel")
    t.eq(M.BuildBody("HP_POT", spellID), "#showtooltip\n/cast Recuperate",
        "spell pick → #showtooltip + /cast <Name>")

    -- ---- BuildBody: nil item → category emptyText ----
    t.eq(M.BuildBody("FOOD", nil), KCM.Categories.Get("FOOD").emptyText,
        "nil item → FOOD emptyText")
    t.eq(M.BuildBody("HP_AIO", nil), KCM.Categories.Get("HP_AIO").emptyText,
        "nil item → HP_AIO emptyText")
    -- Unknown catKey still yields a generic empty body (never nil).
    t.truthy(M.BuildBody("NOPE", nil), "unknown cat still produces an empty body")

    -- ---- BuildCompositeBody: HP_AIO happy path ----
    local aio = KCM.Categories.Get("HP_AIO")
    local picks = { HS = 5512, HP_POT = 171267, FOOD = 113509 }
    local pickFor = function(ref) return picks[ref] end

    local body = M.BuildCompositeBody(aio, pickFor)
    t.truthy(body, "composite body built")
    t.truthy(body:find("^#showtooltip"), "composite body starts with #showtooltip")
    t.truthy(body:find("/castsequence [combat] reset=combat item:5512, item:171267", 1, true),
        "in-combat picks joined into one /castsequence line")
    t.truthy(body:find("/use [nocombat] item:113509", 1, true),
        "out-of-combat pick → /use [nocombat] line")

    -- ---- disabled sub-category is dropped from the in-combat sequence ----
    local cfg = KCM.db.profile.categories.HP_AIO
    cfg.enabled.HS = false
    local body2 = M.BuildCompositeBody(aio, pickFor)
    t.truthy(body2, "composite body built with HS disabled")
    t.falsy(body2:find("item:5512", 1, true), "disabled HS pick is dropped")
    t.truthy(body2:find("/castsequence [combat] reset=combat item:171267", 1, true),
        "sequence now only carries the enabled in-combat pick")
    t.truthy(body2:find("/use [nocombat] item:113509", 1, true),
        "out-of-combat pick still present after disabling an in-combat ref")
    cfg.enabled.HS = true   -- restore

    -- ---- pickFor returns nil for everything → nil ----
    local emptyPick = function() return nil end
    t.eq(M.BuildCompositeBody(aio, emptyPick), nil,
        "no usable picks → BuildCompositeBody returns nil")

    -- ---- in-combat only (out-of-combat pick missing) → per-section /run fallback ----
    local inOnly = function(ref) return (ref ~= "FOOD") and picks[ref] or nil end
    local body3 = M.BuildCompositeBody(aio, inOnly)
    t.truthy(body3, "in-combat-only composite body built")
    t.truthy(body3:find("/castsequence [combat] reset=combat item:5512, item:171267", 1, true),
        "in-combat line present when only in-combat picks exist")
    t.falsy(body3:find("[nocombat]", 1, true), "no /use [nocombat] line when out-of-combat pick missing")
    t.truthy(body3:find("no AIO Health option out of combat", 1, true),
        "in-combat-only body carries the out-of-combat empty-state /run fallback")

    -- ---- out-of-combat only (in-combat picks missing) → per-section /run fallback ----
    local outOnly = function(ref) return (ref == "FOOD") and picks[ref] or nil end
    local body4 = M.BuildCompositeBody(aio, outOnly)
    t.truthy(body4, "out-of-combat-only composite body built")
    t.falsy(body4:find("/castsequence", 1, true), "no /castsequence line when in-combat picks missing")
    t.truthy(body4:find("/use [nocombat] item:113509", 1, true),
        "out-of-combat line present when only out-of-combat pick exists")
    t.truthy(body4:find("no AIO Health option in combat", 1, true),
        "out-of-combat-only body carries the in-combat empty-state /run fallback")

    -- ---- guard: non-composite / missing pickFor → nil ----
    t.eq(M.BuildCompositeBody(KCM.Categories.Get("FOOD"), pickFor), nil,
        "non-composite category → nil")
    t.eq(M.BuildCompositeBody(aio, nil), nil, "missing pickFor → nil")

    -- ---- composite spell token uses localized name ----
    local spellPick = function(ref)
        if ref == "HS" then return KCM.ID.AsSpell(1231411) end
        if ref == "HP_POT" then return 171267 end
        return nil
    end
    local body5 = M.BuildCompositeBody(aio, spellPick)
    t.truthy(body5:find("/castsequence [combat] reset=combat Recuperate, item:171267", 1, true),
        "spell pick contributes its localized name to the /castsequence line")
end)
