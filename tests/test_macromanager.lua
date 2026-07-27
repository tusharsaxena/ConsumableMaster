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

test("MacroManager: buildWeaponEnchantBody emits per-slot lines for MH+OH / one / neither", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M._buildWeaponEnchantBody(111, 222),
        "#showtooltip\n/use item:111\n/use 16\n/use item:222\n/use 17", "both hands")
    t.eq(M._buildWeaponEnchantBody(111, nil),
        "#showtooltip\n/use item:111\n/use 16", "main hand only")
    t.eq(M._buildWeaponEnchantBody(nil, 222),
        "#showtooltip\n/use item:222\n/use 17", "off hand only")
    t.eq(M._buildWeaponEnchantBody(nil, nil), nil, "neither -> nil")
end)

test("MacroManager: BuildBody VANTUS uses the default single /use body", function(t)
    local KCM = h.loader.loadPure()
    local M   = KCM.MacroManager
    t.eq(M.BuildBody("VANTUS", 245880), "#showtooltip\n/use item:245880",
        "VANTUS item pick → default single /use item body")
end)

-- ---------------------------------------------------------------------------
-- SetMacro — the write path, its result codes, and the fingerprint cache
-- ---------------------------------------------------------------------------

local function ownFood(mock, id)
    mock.setItem(id, { name = "Test Food", subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(id, 1)
    return id
end

test("MacroManager.SetMacro creates the macro on the first write", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940001)
    t.eq(KCM.MacroManager.SetMacro("KCM_FOOD", 940001, "FOOD"), "created", "first write creates")
    t.truthy(mock.macros["KCM_FOOD"], "the macro now exists in the client")
end)

test("MacroManager.SetMacro records the body and icon it wrote", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940002)
    KCM.MacroManager.SetMacro("KCM_FOOD", 940002, "FOOD")
    local state = KCM.db.profile.macroState["KCM_FOOD"]
    t.eq(state.lastItemID, 940002, "the picked item is remembered")
    t.eq(state.lastCat, "FOOD", "along with the category that drove it")
    t.truthy(state.lastBody:find("940002", 1, true), "and the exact body written")
    t.truthy(state.lastIcon, "and the icon, so an icon-only change still triggers a rewrite")
end)

test("MacroManager.SetMacro reports 'unchanged' and makes no API call on a repeat", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940003)
    KCM.MacroManager.SetMacro("KCM_FOOD", 940003, "FOOD")

    local edits = 0
    local realEdit = _G.EditMacro
    _G.EditMacro = function(...) edits = edits + 1; return realEdit(...) end
    local result = KCM.MacroManager.SetMacro("KCM_FOOD", 940003, "FOOD")
    _G.EditMacro = realEdit

    t.eq(result, "unchanged", "an identical body short-circuits")
    t.eq(edits, 0, "no protected API is touched for a no-op recompute")
end)

test("MacroManager.SetMacro edits in place when the pick changes", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940004)
    ownFood(mock, 940005)
    KCM.MacroManager.SetMacro("KCM_FOOD", 940004, "FOOD")
    t.eq(KCM.MacroManager.SetMacro("KCM_FOOD", 940005, "FOOD"), "edited", "a new pick edits")
    t.truthy(mock.macros["KCM_FOOD"].body:find("940005", 1, true), "the body follows the new pick")
end)

test("MacroManager.SetMacro falls back to the empty body when nothing is picked", function(t)
    local KCM = h.loader.loadPure()
    KCM.MacroManager.SetMacro("KCM_FOOD", nil, "FOOD")
    local body = KCM.db.profile.macroState["KCM_FOOD"].lastBody
    t.eq(body, KCM.Categories.Get("FOOD").emptyText, "the category's empty-state stub is written")
end)

test("MacroManager.SetMacro resolves the category from the macro name if not told", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940006)
    KCM.MacroManager.SetMacro("KCM_FOOD", 940006)
    t.eq(KCM.db.profile.macroState["KCM_FOOD"].lastCat, "FOOD",
        "the macroName -> category lookup keeps the empty-state fallback correct")
end)

test("MacroManager.SetMacro rejects an empty macro name", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroManager.SetMacro("", 940007, "FOOD"), "error", "empty name is an error")
    t.eq(KCM.MacroManager.SetMacro(nil, 940007, "FOOD"), "error", "nil name is an error")
end)

test("MacroManager.SetMacro refuses to write before the DB is ready", function(t)
    local KCM = h.loader.loadPure()
    local saved = KCM.db
    KCM.db = nil
    local result = KCM.MacroManager.SetMacro("KCM_FOOD", 940008, "FOOD")
    KCM.db = saved
    t.eq(result, "error", "no macro is written against a missing profile")
end)

test("MacroManager.SetMacro errors out when the account macro quota is full", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940009)
    local saved = _G.GetNumMacros
    _G.GetNumMacros = function() return 120 end
    local result = KCM.MacroManager.SetMacro("KCM_FOOD", 940009, "FOOD")
    _G.GetNumMacros = saved
    t.eq(result, "error", "creating past Blizzard's 120-macro cap fails cleanly")
    t.eq(KCM.db.profile.macroState["KCM_FOOD"], nil, "and leaves no state claiming it succeeded")
end)

test("MacroManager.SetMacro surfaces a rejected edit as an error", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 940010)
    ownFood(mock, 940011)
    KCM.MacroManager.SetMacro("KCM_FOOD", 940010, "FOOD")
    local saved = _G.EditMacro
    _G.EditMacro = function() return 0 end          -- client rejected the body
    local result = KCM.MacroManager.SetMacro("KCM_FOOD", 940011, "FOOD")
    _G.EditMacro = saved
    t.eq(result, "error", "a zero index from EditMacro is a failure, not a success")
    t.truthy(KCM.db.profile.macroState["KCM_FOOD"].lastBody:find("940010", 1, true),
        "the stored fingerprint still describes what is actually in the client")
end)

-- ---------------------------------------------------------------------------
-- Combat deferral and the flush queue
-- ---------------------------------------------------------------------------

test("MacroManager.SetMacro defers instead of writing while in combat", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 941001)
    mock.setCombat(true)
    local result = KCM.MacroManager.SetMacro("KCM_FOOD", 941001, "FOOD")
    t.eq(result, "deferred", "the write is queued, never attempted")
    t.eq(mock.macros["KCM_FOOD"], nil, "no protected API ran during combat")
end)

test("MacroManager.FlushPending applies a deferred write once combat ends", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 941002)
    mock.setCombat(true)
    KCM.MacroManager.SetMacro("KCM_FOOD", 941002, "FOOD")
    mock.setCombat(false)

    t.eq(KCM.MacroManager.FlushPending(), 1, "one queued write applied")
    t.truthy(mock.macros["KCM_FOOD"].body:find("941002", 1, true), "with the body queued in combat")
    t.eq(KCM.MacroManager.FlushPending(), 0, "and the queue is now empty")
end)

test("MacroManager.FlushPending refuses to run while still in combat", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 941003)
    mock.setCombat(true)
    KCM.MacroManager.SetMacro("KCM_FOOD", 941003, "FOOD")
    t.eq(KCM.MacroManager.FlushPending(), 0, "a mistimed flush cannot taint")
    t.eq(mock.macros["KCM_FOOD"], nil, "the queue is left intact for the real regen event")
end)

test("MacroManager.FlushPending gives up on a macro after three failed writes", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 941004)
    mock.setCombat(true)
    KCM.MacroManager.SetMacro("KCM_FOOD", 941004, "FOOD")
    mock.setCombat(false)

    -- Every write fails: CreateMacro produces no index.
    local savedCreate = _G.CreateMacro
    _G.CreateMacro = function() end
    mock.output = {}
    local applied = 0
    for _ = 1, 3 do applied = applied + KCM.MacroManager.FlushPending() end
    _G.CreateMacro = savedCreate

    t.eq(applied, 0, "nothing was ever written")
    local gaveUp = false
    for _, line in ipairs(mock.output) do
        if line:find("gave up on KCM_FOOD", 1, true) then gaveUp = true end
    end
    t.truthy(gaveUp, "the user is told once, rather than retrying forever every combat cycle")
    t.eq(KCM.MacroManager.FlushPending(), 0, "and the entry is dropped from the queue")
end)

test("MacroManager.FlushPending re-queues a write if combat resumes mid-flush", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 941005)
    mock.setCombat(true)
    KCM.MacroManager.SetMacro("KCM_FOOD", 941005, "FOOD")

    -- Out of combat for the flush guard, back in combat by the time the write
    -- is attempted — the shape of a flush racing the next pull.
    local calls = 0
    local saved = _G.InCombatLockdown
    _G.InCombatLockdown = function()
        calls = calls + 1
        return calls > 1
    end
    local applied = KCM.MacroManager.FlushPending()
    _G.InCombatLockdown = saved

    t.eq(applied, 0, "nothing counted as applied")
    mock.setCombat(false)
    t.eq(KCM.MacroManager.FlushPending(), 1, "the entry survived and flushes on the next regen")
end)

-- ---------------------------------------------------------------------------
-- InvalidateState
-- ---------------------------------------------------------------------------

test("MacroManager.InvalidateState forces the next pass to rewrite every body", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 942001)
    KCM.MacroManager.SetMacro("KCM_FOOD", 942001, "FOOD")
    t.eq(KCM.MacroManager.SetMacro("KCM_FOOD", 942001, "FOOD"), "unchanged", "cached first")

    KCM.MacroManager.InvalidateState()
    t.eq(next(KCM.db.profile.macroState), nil, "the fingerprint cache is emptied")
    t.eq(KCM.MacroManager.SetMacro("KCM_FOOD", 942001, "FOOD"), "edited",
        "so the same pick is written to the client again (/cm rewritemacros)")
end)

test("MacroManager.InvalidateState drops queued combat writes", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 942002)
    mock.setCombat(true)
    KCM.MacroManager.SetMacro("KCM_FOOD", 942002, "FOOD")
    KCM.MacroManager.InvalidateState()
    mock.setCombat(false)
    t.eq(KCM.MacroManager.FlushPending(), 0,
        "queued entries reference stale expectations, so they are discarded")
end)

-- ---------------------------------------------------------------------------
-- Oversized bodies
-- ---------------------------------------------------------------------------

test("MacroManager falls back to the empty body when a body exceeds 255 bytes", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 943001)
    local realBuild = KCM.MacroManager.BuildBody
    KCM.MacroManager.BuildBody = function() return string.rep("x", 300) end
    mock.output = {}
    KCM.MacroManager.SetMacro("KCM_FOOD", 943001, "FOOD")
    KCM.MacroManager.BuildBody = realBuild

    t.eq(KCM.db.profile.macroState["KCM_FOOD"].lastBody, KCM.Categories.Get("FOOD").emptyText,
        "a truncated body would corrupt the macro, so the empty stub is written instead")
    t.ne(KCM.db.profile.macroState["KCM_FOOD"].lastIcon, 134400,
        "and the stored icon drops the dynamic-icon sentinel, since the body has no #showtooltip")
end)

test("MacroManager warns about an oversized body only once per category", function(t)
    local KCM, mock = h.loader.loadPure(), h.loader.mock
    ownFood(mock, 943002)
    local realBuild = KCM.MacroManager.BuildBody
    KCM.MacroManager.BuildBody = function() return string.rep("x", 300) end
    mock.output = {}
    KCM.MacroManager.SetMacro("KCM_FOOD", 943002, "FOOD")
    KCM.MacroManager.SetMacro("KCM_FOOD", 943002, "FOOD")
    KCM.MacroManager.BuildBody = realBuild

    local warnings = 0
    for _, line in ipairs(mock.output) do
        if line:find("exceeds 255 bytes", 1, true) then warnings = warnings + 1 end
    end
    t.eq(warnings, 1, "one chat line per category per session, not one per recompute")
end)

-- ---------------------------------------------------------------------------
-- Weapon enchant macro
-- ---------------------------------------------------------------------------

test("MacroManager.SetWeaponEnchantMacro writes the empty stub when neither hand has a pick", function(t)
    local KCM = h.loader.loadPure()
    local cat = KCM.Categories.Get("WPN_ENCH")
    KCM.MacroManager.SetWeaponEnchantMacro(cat, nil, nil)
    t.eq(KCM.db.profile.macroState["KCM_WPN_ENCH"].lastBody, cat.emptyText,
        "an unenhanceable weapon set still leaves a valid macro on the bar")
end)

test("MacroManager.SetWeaponEnchantMacro takes its icon from the main hand", function(t)
    local KCM = h.loader.loadPure()
    KCM.MacroManager.SetWeaponEnchantMacro(KCM.Categories.Get("WPN_ENCH"), 944001, 944002)
    t.eq(KCM.db.profile.macroState["KCM_WPN_ENCH"].lastItemID, 944001,
        "the main-hand stone is what the action bar shows")
end)

test("MacroManager.SetWeaponEnchantMacro guards a missing category or DB", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroManager.SetWeaponEnchantMacro(nil, 1, 2), "error", "no category is an error")
    local saved = KCM.db
    KCM.db = nil
    local result = KCM.MacroManager.SetWeaponEnchantMacro(KCM.Categories.Get("WPN_ENCH"), 1, 2)
    KCM.db = saved
    t.eq(result, "error", "no DB is an error")
end)
