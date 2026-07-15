-- tests/test_macromanager.lua — pure body builders in MacroManager.lua:
--   M.BuildBody(catKey, itemID) and M.BuildCompositeBody(cat, pickFor).

local h = require("harness")
local test = h.test

-- Shared HP_AIO composite picks: HS + HP_POT are in-combat refs, FOOD is the
-- out-of-combat ref.
local PICKS = { HS = 5512, HP_POT = 171267, FOOD = 113509 }
local function pickAll(ref) return PICKS[ref] end

test("MacroManager: BuildBody emits #showtooltip + /use item for an owned item pick", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M.BuildBody("FOOD", 12345), "#showtooltip\n/use item:12345",
        "item pick → #showtooltip + /use item:<id>")
    t.eq(M.BuildBody("HP_POT", 171267), "#showtooltip\n/use item:171267",
        "item pick uses the numeric id verbatim")
end)

test("MacroManager: BuildBody emits #showtooltip + /cast <Name> for a spell pick", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local M    = KCM.MacroManager
    mock.setSpell(1231411, { name = "Recuperate", known = true })
    local spellID = KCM.ID.AsSpell(1231411)   -- negative sentinel
    t.truthy(KCM.ID.IsSpell(spellID), "AsSpell yields a spell sentinel")
    t.eq(M.BuildBody("HP_POT", spellID), "#showtooltip\n/cast Recuperate",
        "spell pick → #showtooltip + /cast <Name>")
end)

test("MacroManager: BuildBody with nil item falls back to category emptyText", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M.BuildBody("FOOD", nil), KCM.Categories.Get("FOOD").emptyText,
        "nil item → FOOD emptyText")
    t.eq(M.BuildBody("HP_AIO", nil), KCM.Categories.Get("HP_AIO").emptyText,
        "nil item → HP_AIO emptyText")
    -- Unknown catKey still yields a generic empty body (never nil).
    t.truthy(M.BuildBody("NOPE", nil), "unknown cat still produces an empty body")
end)

test("MacroManager: BuildCompositeBody HP_AIO happy path joins in- and out-of-combat picks", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local aio = KCM.Categories.Get("HP_AIO")

    local body = M.BuildCompositeBody(aio, pickAll)
    t.truthy(body, "composite body built")
    t.truthy(body:find("^#showtooltip"), "composite body starts with #showtooltip")
    t.truthy(body:find("/castsequence [combat] reset=combat item:5512, item:171267", 1, true),
        "in-combat picks joined into one /castsequence line")
    t.truthy(body:find("/use [nocombat] item:113509", 1, true),
        "out-of-combat pick → /use [nocombat] line")
end)

test("MacroManager: BuildCompositeBody drops a disabled sub-category from the in-combat sequence", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local aio = KCM.Categories.Get("HP_AIO")

    local cfg = KCM.db.profile.categories.HP_AIO
    cfg.enabled.HS = false
    local body2 = M.BuildCompositeBody(aio, pickAll)
    t.truthy(body2, "composite body built with HS disabled")
    t.falsy(body2:find("item:5512", 1, true), "disabled HS pick is dropped")
    t.truthy(body2:find("/castsequence [combat] reset=combat item:171267", 1, true),
        "sequence now only carries the enabled in-combat pick")
    t.truthy(body2:find("/use [nocombat] item:113509", 1, true),
        "out-of-combat pick still present after disabling an in-combat ref")
end)

test("MacroManager: BuildCompositeBody returns nil for no usable picks or invalid inputs", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local aio = KCM.Categories.Get("HP_AIO")

    local emptyPick = function() return nil end
    t.eq(M.BuildCompositeBody(aio, emptyPick), nil,
        "no usable picks → BuildCompositeBody returns nil")
    t.eq(M.BuildCompositeBody(KCM.Categories.Get("FOOD"), pickAll), nil,
        "non-composite category → nil")
    t.eq(M.BuildCompositeBody(aio, nil), nil, "missing pickFor → nil")
end)

test("MacroManager: BuildCompositeBody with only in-combat picks adds the out-of-combat /run fallback", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local aio = KCM.Categories.Get("HP_AIO")

    local inOnly = function(ref) return (ref ~= "FOOD") and PICKS[ref] or nil end
    local body3 = M.BuildCompositeBody(aio, inOnly)
    t.truthy(body3, "in-combat-only composite body built")
    t.truthy(body3:find("/castsequence [combat] reset=combat item:5512, item:171267", 1, true),
        "in-combat line present when only in-combat picks exist")
    t.falsy(body3:find("[nocombat]", 1, true), "no /use [nocombat] line when out-of-combat pick missing")
    t.truthy(body3:find("no AIO Health option out of combat", 1, true),
        "in-combat-only body carries the out-of-combat empty-state /run fallback")
end)

test("MacroManager: BuildCompositeBody with only out-of-combat pick adds the in-combat /run fallback", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    local aio = KCM.Categories.Get("HP_AIO")

    local outOnly = function(ref) return (ref == "FOOD") and PICKS[ref] or nil end
    local body4 = M.BuildCompositeBody(aio, outOnly)
    t.truthy(body4, "out-of-combat-only composite body built")
    t.falsy(body4:find("/castsequence", 1, true), "no /castsequence line when in-combat picks missing")
    t.truthy(body4:find("/use [nocombat] item:113509", 1, true),
        "out-of-combat line present when only out-of-combat pick exists")
    t.truthy(body4:find("no AIO Health option in combat", 1, true),
        "out-of-combat-only body carries the in-combat empty-state /run fallback")
end)

test("MacroManager: BuildCompositeBody uses a spell pick's localized name in the /castsequence", function(t)
    local KCM  = h.loader.loadPure()
    local mock = h.loader.mock
    local M    = KCM.MacroManager
    local aio  = KCM.Categories.Get("HP_AIO")
    mock.setSpell(1231411, { name = "Recuperate", known = true })

    local spellPick = function(ref)
        if ref == "HS" then return KCM.ID.AsSpell(1231411) end
        if ref == "HP_POT" then return 171267 end
        return nil
    end
    local body5 = M.BuildCompositeBody(aio, spellPick)
    t.truthy(body5:find("/castsequence [combat] reset=combat Recuperate, item:171267", 1, true),
        "spell pick contributes its localized name to the /castsequence line")
end)
