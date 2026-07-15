-- tests/test_tooltipcache.lua — real TooltipCache parser coverage.
--
-- Unlike the classifier/ranker suites (which inject a `tt` table straight
-- through the loader's TooltipCache stub), this suite loads the REAL
-- TooltipCache.lua and feeds it structured C_TooltipInfo lines, so the Lua
-- pattern parsing itself is exercised. Guards the flat "Restores X health and
-- Y mana" combined phrasing used by Midnight food-and-drink items such as
-- Chalcocite Lava Cake (227326), which must populate BOTH healValue and
-- manaValue so it classifies as Food AND Drink.

local h = require("harness")

h.suite("tooltipcache", function(t)
    -- Load Namespace + the real parser onto a fresh mocked namespace.
    local KCM  = h.loader.loadFiles({ "Namespace.lua", "TooltipCache.lua" })
    local mock = h.loader.mock
    local TC   = KCM.TooltipCache

    -- Feed structured tooltip lines for `id`, give it a name (so GetItemInfo
    -- resolves and Get() doesn't mark the entry pending), then re-parse.
    local function parse(id, lines)
        mock.setItem(id, { subType = "Food & Drink" })
        _G.C_TooltipInfo.GetItemByID = function(qid)
            if qid ~= id then return nil end
            local out = {}
            for i, txt in ipairs(lines) do out[i] = { leftText = txt } end
            return { lines = out }
        end
        TC.Invalidate(id)
        return TC.Get(id)
    end

    -- ---- Combined flat "health and mana" — the reported bug ------------------
    local cake = parse(227326, {
        "Chalcocite Lava Cake",
        "Use: Restores 35,000 health and 30,000 mana over 20 sec. Must remain seated while eating.",
    })
    t.eq(cake.healValue, 35000, "combined flat: healValue parsed")
    t.eq(cake.manaValue, 30000, "combined flat: manaValue parsed")

    -- ---- Regression: plain health-only food ---------------------------------
    local food = parse(1001, { "Use: Restores 90,000 health over 20 sec." })
    t.eq(food.healValue, 90000, "health-only: healValue parsed")
    t.falsy(food.manaValue, "health-only: no manaValue")

    -- ---- Regression: plain mana-only drink ----------------------------------
    local drink = parse(1002, { "Use: Restores 90,000 mana over 20 sec." })
    t.eq(drink.manaValue, 90000, "mana-only: manaValue parsed")
    t.falsy(drink.healValue, "mana-only: no healValue")

    -- ---- Regression: combined percentage form (already worked) --------------
    local pct = parse(1003, { "Use: Restores 5% of your maximum health and mana every second." })
    t.eq(pct.healPct, 5, "combined pct: healPct parsed")
    t.eq(pct.manaPct, 5, "combined pct: manaPct parsed")
end)
