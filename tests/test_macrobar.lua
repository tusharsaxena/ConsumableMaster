-- tests/test_macrobar.lua — the macro bar's middle layer: slot bookkeeping
-- (core/MacroBarModel.lua), the Macro Bar page's schema rows, the addon-wide
-- master controls and the page's Defaults button.
--
-- Two siblings were peeled off this file for layout-§1's 1500-line cap, on the
-- seams issue #32 named: tests/test_macrobar_layout.lua took the pure geometry
-- (core/MacroBarLayout.lua's grid, labels, flyout placement and indicator
-- clearance) and tests/test_macrobar_chrome.lua took the chrome appliers and the
-- flyout's bind/apply pass. Every case moved whole; the three files together
-- register exactly the cases this one did.
--
-- Two more were peeled for layout-§1's 1000-1500 band (CM-ATS-02), on the
-- file's own section headings: tests/test_macrobar_display.lua took display
-- resolution (core/MacroDisplay.lua), Pickup and the cooldown application, and
-- tests/test_macrobar_flyout.lua took the flyout's candidate list
-- (MacroBarFlyout.Candidates, pure over Selector + config), click gating and
-- the flyout's hover and idle-clock behavior. Every case moved whole again.
--
-- The rest of the frame layer (modules/MacroBar*.lua) is deliberately not
-- exercised here — it is a thin apply pass over these, and secure-frame
-- behavior can only be validated in-game (docs/smoke-tests.md).

local h = _G.KCM_TEST
local test = h.test

-- The bar builder is shared rather than copied — tests/macrobar_support.lua says why.
local support = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua")

-- ---------------------------------------------------------------------------
-- Model
-- ---------------------------------------------------------------------------

test("macrobar model: AllKeys covers every managed category", function(t)
    local KCM = h.loader.loadPure()
    t.eq(#KCM.MacroBarModel.AllKeys(), #KCM.Categories.LIST, "one key per category")
end)

test("macrobar model: NormalizeOrder leaves a complete order untouched", function(t)
    local KCM = h.loader.loadPure()
    local all = KCM.MacroBarModel.AllKeys()
    local out, changed = KCM.MacroBarModel.NormalizeOrder(all)
    t.falsy(changed, "nothing changed")
    t.eqList(out, all, "order preserved")
end)

test("macrobar model: NormalizeOrder drops unknown keys", function(t)
    local KCM = h.loader.loadPure()
    local out, changed = KCM.MacroBarModel.NormalizeOrder({ "FOOD", "NOT_A_CATEGORY" })
    t.truthy(changed, "reports a change")
    t.eq(out[1], "FOOD", "known key kept first")
    for _, k in ipairs(out) do t.ne(k, "NOT_A_CATEGORY", "unknown key dropped") end
end)

test("macrobar model: NormalizeOrder appends categories missing from a saved order", function(t)
    local KCM = h.loader.loadPure()
    local out, changed = KCM.MacroBarModel.NormalizeOrder({ "VANTUS" })
    t.truthy(changed, "reports a change")
    t.eq(out[1], "VANTUS", "saved key keeps its position")
    t.eq(#out, #KCM.Categories.LIST, "every other category appended")
end)

test("macrobar model: NormalizeOrder de-duplicates a repeated key", function(t)
    local KCM = h.loader.loadPure()
    local out = KCM.MacroBarModel.NormalizeOrder({ "FOOD", "FOOD", "DRINK" })
    local seen = 0
    for _, k in ipairs(out) do if k == "FOOD" then seen = seen + 1 end end
    t.eq(seen, 1, "FOOD appears once")
end)

test("macrobar model: Swap exchanges two slots", function(t)
    local KCM = h.loader.loadPure()
    local order = { "FOOD", "DRINK", "HS" }
    t.truthy(KCM.MacroBarModel.Swap(order, "FOOD", "HS"), "swap succeeds")
    t.eqList(order, { "HS", "DRINK", "FOOD" }, "endpoints exchanged")
end)

test("macrobar model: Swap refuses an absent or self-referential key", function(t)
    local KCM = h.loader.loadPure()
    local order = { "FOOD", "DRINK" }
    t.falsy(KCM.MacroBarModel.Swap(order, "FOOD", "FLASK"), "absent key rejected")
    t.falsy(KCM.MacroBarModel.Swap(order, "FOOD", "FOOD"), "self-swap rejected")
    t.eqList(order, { "FOOD", "DRINK" }, "order untouched")
end)

test("macrobar model: VisibleKeys hides only slots explicitly set to false", function(t)
    local KCM = h.loader.loadPure()
    local order = { "FOOD", "DRINK", "HS" }
    local out = KCM.MacroBarModel.VisibleKeys(order, { DRINK = false, HS = true })
    t.eqList(out, { "FOOD", "HS" }, "unset stays visible, false is hidden")
end)

test("macrobar model: MacroName and KeyForMacroName round-trip", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroBarModel.MacroName("FOOD"), "KCM_FOOD", "key to macro name")
    t.eq(KCM.MacroBarModel.KeyForMacroName("KCM_FOOD"), "FOOD", "macro name to key")
    t.falsy(KCM.MacroBarModel.KeyForMacroName("SomeOtherMacro"), "foreign macro rejected")
    t.falsy(KCM.MacroBarModel.MacroName("NOPE"), "unknown key has no macro name")
end)

test("macrobar model: the bar ships centered on screen at 36px buttons", function(t)
    local KCM = h.loader.loadPure()
    local d = KCM.dbDefaults.profile.macroBar
    t.eq(d.point, "CENTER", "anchored by its center...")
    t.eq(d.relPoint, "CENTER", "...to the screen's center")
    t.eq(d.x, 0, "no horizontal offset")
    t.eq(d.y, 0, "no vertical offset either, so it lands dead center")
    t.eq(d.buttonSize, 36, "standard action-button size")
end)

test("macrobar model: the GCD swipe is suppressed out of the box", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.dbDefaults.profile.macroBar.showGCD, false,
        "showGCD defaults to false, i.e. suppression is ON by default")
end)

test("macrobar defaults: perRow tracks the number of managed categories", function(t)
    local KCM = h.loader.loadPure()
    -- core/ loads before defaults/ (ConsumableMaster.toc), so
    -- dbDefaults.profile.macroBar.perRow is a hand-maintained literal rather
    -- than a derived value. If this fails, BUMP core/ConsumableMaster.lua's
    -- default to match the category count -- do not weaken this assertion.
    t.eq(KCM.dbDefaults.profile.macroBar.perRow, #KCM.Categories.LIST,
        "perRow must equal the category count")

    -- core/MacroBarLayout.lua's `normalize()` has its OWN perRow fallback
    -- (a third hand-maintained copy of the same count), used only when a
    -- caller omits perRow from cfg entirely. It isn't exported, so observe it
    -- indirectly through Grid: every category should fit on one row under
    -- the fallback, same as the real default. If the fallback ever drifts
    -- BELOW the live category count, this wraps to a second row and fails.
    -- If this fails, BUMP core/MacroBarLayout.lua's `perRow = ... or N`
    -- fallback to match the category count -- do not weaken this assertion.
    local g = KCM.MacroBarLayout.Grid(#KCM.Categories.LIST, {})
    t.eq(g.cols, #KCM.Categories.LIST,
        "MacroBarLayout's own perRow fallback fits every category on one row")
    t.eq(g.rows, 1, "and doesn't wrap to a second row")
end)

test("macrobar schema: perRow's max slider value is derived from the category count", function(t)
    local KCM = h.loader.loadFullAddon()
    local def = KCM.Settings.Helpers.FindSchema("macroBar.perRow")
    t.truthy(def, "perRow row exists")
    t.eq(def.max, #KCM.Categories.LIST,
        "the max is re-derived at settings load, so it can't go stale the way a literal did")
end)

test("macrobar model: the bar ships on and unlocked so it is discoverable", function(t)
    local KCM = h.loader.loadPure()
    t.truthy(KCM.MacroBarModel.IsEnabled(), "macroBar.enabled defaults to true")
    t.eq(KCM.db.profile.macroBar.locked, false,
        "unlocked by default, so the drag handle is there to place it")
end)

test("macrobar model: the shipped default order needs no repair", function(t)
    local KCM = h.loader.loadPure()
    local _, changed = KCM.MacroBarModel.NormalizeOrder(
        KCM.dbDefaults.profile.macroBar.order)
    t.falsy(changed, "default order is complete, unique and all-known")
end)

-- The stored order is a whole-value schema row (architecture-§5), so its one
-- writer is the helper, which normalizes on the way in. A read that wrote its
-- repair back would be a second writer, sitting on a read path.
--
-- red under: reinstating the write-back in MacroBarModel.Order().
test("macrobar model: Order repairs a damaged saved order on read, and writes nothing", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.order = { "FOOD", "BOGUS" }
    local out = KCM.MacroBarModel.Order()
    t.eq(#out, #KCM.Categories.LIST, "returned order is complete")
    t.eqList(KCM.db.profile.macroBar.order, { "FOOD", "BOGUS" }, "and the read left the stored one alone")
end)

test("macrobar model: Visible reflects the shown map over the saved order", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroBar.shown = { FOOD = false }
    local out = KCM.MacroBarModel.Visible()
    t.eq(#out, #KCM.Categories.LIST - 1, "one slot hidden")
    for _, k in ipairs(out) do t.ne(k, "FOOD", "FOOD is not rendered") end
end)

-- ---------------------------------------------------------------------------
-- Schema rows (settings/MacroBar.lua — needs the full addon load)
-- ---------------------------------------------------------------------------

test("macrobar schema: every macroBar row validates and resolves against the db", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    t.eq(H.ValidateSchema(), 0, "no schema errors")
    local rows = 0
    for _, def in ipairs(KCM.Settings.Schema) do
        if def.path:match("^macroBar%.") then
            rows = rows + 1
            t.ne(H.Get(def.path), nil, def.path .. " resolves in db.profile")
            t.ne(def.default, nil, def.path .. " has a default sourced from dbDefaults")
        end
    end
    t.truthy(rows >= 20, "the Macro Bar page registered its rows (" .. rows .. ")")
end)

-- CM-R-05's two flags. `macroBar.enabled` and `macroBar.locked` used to have TWO
-- write paths: the page's checkbox went through Helpers.SetAndRefresh while
-- MB.SetEnabled / MB.SetLocked — which is every `/cm bar on|off|lock|unlock` —
-- assigned the profile field directly. Two user-visible consequences:
--   1. `/cm bar lock` with the Macro Bar page open left the checkbox stale.
--   2. `macroBar.locked` had no onChange at all, so `/cm set macroBar.locked true`
--      wrote a flag and NOTHING on screen changed — the bar stayed grabbable.
--
-- The two cases below observe those two symptoms directly, on the frame and on
-- the rendered widget. Asserting that the row "carries an onChange of type
-- function" would not: `function() end` satisfies it, and a build whose
-- ApplyLock is a no-op is exactly the bug.

-- The bar frame, its handle and the record of what the lock drives — built by
-- watching CreateFrame across the first MB.Update(). Shared with
-- tests/test_macrobar_chrome.lua, which hovers the handle's two tooltips, so
-- it lives in tests/macrobar_support.lua beside `fcfg` rather than here.
local buildMacroBar = support.buildBar

test("macrobar schema: locking and unlocking reaches the bar frame, whichever surface asked",
    function(t)
        -- Symptom 2. What the user is promised by `/cm bar lock` is a bar that
        -- has stopped eating clicks, with no drag handle and no gold wash — so
        -- that is what is observed, on the frame, rather than the flag's value
        -- or the shape of the row that carries the onChange.
        --
        -- red under: making MB.ApplyLock a no-op, dropping the `macroBar.locked`
        -- row's onChange, or reinstating a direct `c.locked = …` in MB.SetLocked.
        local KCM = h.loader.loadFullAddon()
        local H   = KCM.Settings.Helpers
        local seen = buildMacroBar(KCM)

        -- Supplementary, and deliberately not the load-bearing assertion: an
        -- exact call count would redden on a correct build that reached the page
        -- through RefreshAllPanels or refreshed twice harmlessly.
        local refreshes = 0
        local realRefresh = H.RefreshScalars
        H.RefreshScalars = function(...) refreshes = refreshes + 1; return realRefresh(...) end

        -- `/cm bar lock`
        t.eq(KCM.MacroBar.SetLocked(true), true, "the write reports success")
        t.eq(KCM.db.profile.macroBar.locked, true, "the flag landed")
        t.eq(seen.mouseEnabled, false, "the locked bar stops swallowing clicks")
        t.eq(seen.handleShown, false, "and the drag handle is gone")
        t.eq(seen.hintShown, false, "and the gold unlocked wash is cleared")

        -- `/cm bar unlock`
        KCM.MacroBar.SetLocked(false)
        t.eq(seen.mouseEnabled, true, "unlocking makes the bar grabbable again")
        t.eq(seen.handleShown, true, "the drag handle comes back")
        t.eq(seen.hintShown, true, "and the gold wash says which frame is grabbable")

        -- `/cm set macroBar.locked true` — the other caller of the same seam,
        -- which is the write that used to land and do nothing at all.
        KCM.Schema:Set("macroBar.locked", true)
        t.eq(seen.mouseEnabled, false, "a raw schema write applies to the frame too")
        t.eq(seen.handleShown, false, "…handle and all")

        -- `/cm bar off` / `/cm set macroBar.enabled true`
        KCM.MacroBar.SetEnabled(false)
        t.eq(KCM.db.profile.macroBar.enabled, false, "/cm bar off stored the flag")
        t.eq(seen.barVisible, false, "and the bar actually left the screen")
        KCM.Schema:Set("macroBar.enabled", true)
        t.eq(seen.barVisible, true, "and a schema write brings it back")

        t.truthy(refreshes >= 1, "the writes went through the page-refreshing seam")
        H.RefreshScalars = realRefresh
    end)

-- The bar's own OnDragStart has always asked the lock. The handle's did not, so
-- anything that reached the handle on a locked bar could still drag it.
--
-- red under: a handle OnDragStart that calls StartMoving without asking the lock.
test("macrobar: the drag handle does not move a locked bar", function(t)
    local KCM = h.loader.loadFullAddon()
    local _, bar, handle = buildMacroBar(KCM)
    local moved = 0
    bar.StartMoving = function() moved = moved + 1 end

    KCM.MacroBar.SetLocked(true)
    handle:GetScript("OnDragStart")(handle)
    t.eq(moved, 0, "a locked bar is not dragged by its handle")

    KCM.MacroBar.SetLocked(false)
    handle:GetScript("OnDragStart")(handle)
    t.eq(moved, 1, "unlocked, the same drag moves it")
end)

test("macrobar schema: a flag written from /cm re-syncs the open Macro Bar page in place",
    function(t)
        -- Symptom 1, observed on the rendered widget: the value the checkbox
        -- DISPLAYS, after a write that never went near the page.
        --
        -- red under: reinstating the direct `c.locked = …` / `c.enabled = …`
        -- writes in MB.SetLocked / MB.SetEnabled, or dropping the refresher
        -- registration the library makes for a bool row.
        local KCM  = h.loader.loadFullAddon()
        local mock = h.loader.mock
        local H, UI = KCM.Settings.Helpers, KCM.Settings.Helpers.instance
        buildMacroBar(KCM)   -- so the two onChanges have a frame to talk to

        -- Capture every checkbox the page draws, keyed by the label the user
        -- reads, and record what each one is told to display.
        local boxes = {}
        local realAceGUI = UI.AceGUI
        UI.AceGUI = setmetatable({
            Create = function(_, kind)
                local w = mock.makeAceWidget()
                if kind == "CheckBox" then
                    w.SetLabel = function(self, label) boxes[label] = self; return self end
                    w.SetValue = function(self, v) self.__value = v; return self end
                end
                return w
            end,
            RegisterWidgetType = function() end,
            RegisterLayout     = function() end,
            GetWidgetVersion   = function() return 0 end,
        }, { __index = function() return function() end end })

        KCM.MacroBar.SetLocked(false)

        -- BOTH PAGES, because the two flags now live on different ones: `Lock
        -- frame` MOVED to the General page's Master controls tab (options-ui-§15)
        -- while `Enable macro bar` stayed with the bar it enables. The in-place
        -- re-sync has to reach whichever page is on screen, so both are built and
        -- both are marked shown.
        for _, key in ipairs({ "general", "macrobar" }) do
            local builder = KCM.Settings.builders and KCM.Settings.builders[key]
            t.truthy(builder, "the " .. key .. " tab registered a builder")
            builder({})
            local ctx = UI.__panelFor(key)
            t.truthy(ctx, "…and its ctx landed in the library's registry")
            ctx.panel.IsShown = function() return true end
        end
        H.RefreshAllPanels()

        local lockBox   = boxes[KCM.L["Lock frame"]]
        local enableBox = boxes[KCM.L["Enable macro bar"]]
        t.truthy(lockBox, "the Master controls tab drew the lock checkbox")
        t.truthy(enableBox, "the Macro Bar page's General tab drew the enable checkbox")
        t.eq(lockBox.__value, false, "it opens showing the stored value")

        KCM.MacroBar.SetLocked(true)
        t.eq(lockBox.__value, true, "/cm bar lock re-syncs the open page, no rebuild needed")

        KCM.Schema:Set("macroBar.locked", false)
        t.eq(lockBox.__value, false, "and so does /cm set macroBar.locked false")

        KCM.MacroBar.SetEnabled(false)
        t.eq(enableBox.__value, false, "the enable checkbox tracks /cm bar off the same way")

        UI.AceGUI = realAceGUI
    end)

test("macrobar schema: enum rows reject a value outside their list", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.orientation")
    t.truthy(def, "orientation row exists")
    t.eq(H.ValidateSchemaValue(def, "VERTICAL"), "VERTICAL", "listed value accepted")
    t.falsy(H.ValidateSchemaValue(def, "SIDEWAYS"), "unlisted value rejected")
end)

test("macrobar schema: number rows clamp to their declared range", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.buttonSize")
    t.eq(H.ValidateSchemaValue(def, 9999), def.max, "clamped to max")
    t.eq(H.ValidateSchemaValue(def, -5), def.min, "clamped to min")
end)

test("macrobar schema: the default slot order matches the Macros tab order", function(t)
    local KCM = h.loader.loadFullAddon()
    -- The bar's default order is the cosmetic tab order of the Macros page.
    -- dbDefaults can't reference KCM.Settings.macroOrder (Panel.lua loads much
    -- later), so this case is the drift guard for the duplicated literal.
    --
    -- It reads macroOrder DIRECTLY now. It used to walk KCM.Settings.order and
    -- subtract the three non-category pages by name, which was a filter that
    -- would have silently widened every time a page was added -- and did not
    -- notice at all that the two lists were the same length only by accident.
    local want = {}
    for _, key in ipairs(KCM.Settings.macroOrder) do
        want[#want + 1] = key:upper()
    end
    t.eq(#want, #KCM.Categories.LIST,
        "every category has a tab, so the order covers all of them")
    t.eqList(KCM.dbDefaults.profile.macroBar.order, want,
        "macroBar.order mirrors KCM.Settings.macroOrder")
end)

test("macrobar schema: border rows are populated from LibSharedMedia", function(t)
    local KCM = h.loader.loadFullAddon()
    local H = KCM.Settings.Helpers
    local def = H.FindSchema("macroBar.buttonBorderStyle")
    t.truthy(def, "button border style row exists")
    -- `dialogControl` is the library's field name for "render this row with an
    -- in-tree widget type rather than a plain Dropdown". It used to be the
    -- addon's own `lsm = "border"` plus a local name map; the map went with the
    -- makers (LIBKA0S-04, issue #22) and the row names the widget directly.
    t.eq(def.dialogControl, "LSM30_Border",
        "declared as an LSM border row so it gets the preview widget")
    -- `values` must stay a FUNCTION: other addons register media after our
    -- schema is declared, so the list has to be re-queried at click time.
    t.eq(type(def.values), "function", "values is lazily evaluated")
    local names = {}
    for _, item in ipairs(H.EnumValues(def)) do names[#names + 1] = item.value end
    t.contains(names, "Blizzard Tooltip", "LSM's own borders are offered")
    t.eq(H.ValidateSchemaValue(def, "Blizzard Tooltip"), "Blizzard Tooltip", "registered border accepted")
    t.falsy(H.ValidateSchemaValue(def, "Not A Border"), "unregistered border rejected")
end)

test("macrobar schema: LSMValues never hands back an empty list", function(t)
    local KCM = h.loader.loadFullAddon()
    -- Same guarantee, different owner. `Helpers.LSMValues` was the addon's own
    -- flattening wrapper until M4-C1 retired it; it resolves through
    -- settings/OptionsSetup.lua's __index to the LIBRARY's now, which answers the
    -- DEFERRED closure over a self-keyed hash rather than an ordered array --
    -- hence the second call and the key walk. What is asserted is deliberately
    -- unchanged: a media type with nothing registered must still offer exactly
    -- one option, because an empty list leaves the dropdown unopenable AND makes
    -- ValidateSchemaValue reject the value already stored.
    local read = KCM.Settings.Helpers.LSMValues("nosuchmediatype")
    t.eq(type(read), "function", "the reader is deferred, not a load-time snapshot")
    local keys = {}
    for k in pairs(read()) do keys[#keys + 1] = k end
    t.eq(#keys, 1, "one placeholder row")
    t.eq(keys[1], "None", "placeholder is None")
end)

test("macrobar schema: the bar publishes its own bus message", function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.MSG.MACROBAR_REFRESH, "MACROBAR_REFRESH is in the catalog")
    t.truthy(KCM._macroBarBusTarget, "the bar registered a receiver on its own target")
end)

-- ---------------------------------------------------------------------------
-- The addon-wide master controls, honored by the one thing this addon draws
-- ---------------------------------------------------------------------------

test("macrobar master: Master scale and Master alpha MULTIPLY the bar's own", function(t)
    -- options-ui-§15: the master rows are the ADDON-WIDE ones and the bar's own
    -- `Bar scale` / `Bar opacity` are a different setting. Composing them is what
    -- stops either slider doing nothing at one end of the other's range.
    --
    -- red under: reading only one of the two anywhere in applyLayout / applyAlpha,
    -- or defaulting a missing master value to something other than 1.
    local KCM = h.loader.loadFullAddon()
    local _, bar = buildMacroBar(KCM)

    local scales, alphas = {}, {}
    bar.SetScale = function(_, v) scales[#scales + 1] = v end
    bar.SetAlpha = function(_, v) alphas[#alphas + 1] = v end

    KCM.db.profile.macroBar.scale = 1.5
    KCM.db.profile.macroBar.alpha = 0.8
    KCM.db.profile.macroBar.fadeUnlessHover = false
    KCM.db.profile.scale = 2.0
    KCM.db.profile.alpha = 0.5
    KCM.MacroBar.Update()

    t.near(scales[#scales], 3.0, 0.001, "1.5 bar scale under a 2.0 master reads 3.0")
    t.near(alphas[#alphas], 0.4, 0.001, "0.8 bar opacity under a 0.5 master reads 0.4")

    KCM.db.profile.scale = 1.0
    KCM.db.profile.alpha = 1.0
    KCM.MacroBar.Update()
    t.near(scales[#scales], 1.5, 0.001, "a neutral master leaves the bar's own value alone")
    t.near(alphas[#alphas], 0.8, 0.001, "…on both axes")
end)

-- The truth table, pinned directly on the pure resolver rather than through the
-- frame: what is under test is the INTERSECTION of two combat-conditional
-- settings, and a truth table is exactly what a headless suite can prove.
--
-- red under: returning the master's driver and ignoring the bar's (or the other
-- way round), or answering "show" for a pair that can never both be true.
test("macrobar master: General visibility is INTERSECTED with the bar's combat mode", function(t)
    local KCM = h.loader.loadFullAddon()
    local R = KCM.MacroBarModel.ResolveVisibility

    t.eq(R("always", "ALWAYS"), "show", "both permissive: always on screen")
    t.eq(R(nil, nil), "show", "an unset pair is the shipped 'always / always'")
    t.eq(R("never", "ALWAYS"), "hide", "never wins over anything")
    t.eq(R("never", "ONLY_IN_COMBAT"), "hide", "…including the bar's own combat mode")

    t.eq(R("inCombat", "ALWAYS"), "[combat] show; hide", "the master alone can drive it")
    t.eq(R("outOfCombat", "ALWAYS"), "[combat] hide; show", "…in either direction")
    t.eq(R("always", "HIDE_IN_COMBAT"), "[combat] hide; show", "so can the bar alone")
    t.eq(R("always", "ONLY_IN_COMBAT"), "[combat] show; hide", "…in either direction")

    t.eq(R("inCombat", "ONLY_IN_COMBAT"), "[combat] show; hide", "agreeing halves agree")
    t.eq(R("outOfCombat", "HIDE_IN_COMBAT"), "[combat] hide; show", "…on the other side too")

    -- The pairs that cancel. "Only in combat" over "hide in combat" leaves no
    -- moment at which both say show, and saying so out loud beats drawing a bar
    -- that flickers.
    t.eq(R("inCombat", "HIDE_IN_COMBAT"), "hide", "opposed halves leave nothing on screen")
    t.eq(R("outOfCombat", "ONLY_IN_COMBAT"), "hide", "…the other way round as well")
end)

test("macrobar master: General visibility = never takes the bar off screen", function(t)
    -- The resolver's answer reaching the FRAME, which is the half the truth table
    -- above cannot see.
    --
    -- red under: applyVisibility ignoring db.profile.visibility, or handing "hide"
    -- to RegisterStateDriver as if it were a driver string.
    local KCM = h.loader.loadFullAddon()
    local seen = buildMacroBar(KCM)

    KCM.db.profile.visibility = "never"
    KCM.MacroBar.Update()
    t.eq(seen.barVisible, false, "the addon-wide 'never' hides the bar")

    KCM.db.profile.visibility = "always"
    KCM.MacroBar.Update()
    t.eq(seen.barVisible, true, "and 'always' brings it back")
end)

-- ---------------------------------------------------------------------------
-- The Macro Bar page's Defaults button (issue #36)
-- ---------------------------------------------------------------------------
--
-- It used to replace the whole `macroBar` table with a copy of the defaults and
-- put `.locked` back, so no row's write went through the schema helper, nothing
-- was logged at the [Set] seam, and anything holding the old table kept reading
-- it. The characterization case pins what the button LEAVES, which must not
-- move; the second pins how it gets there.

local function macroBarDefaults(KCM)
    local UI = KCM.Settings.Helpers.instance
    KCM.Settings.builders["macrobar"]({})
    return UI.__panelFor("macrobar").panel.defaultsOnClick
end

-- Deterministic rendering, so two stored shapes compare as strings.
local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function customizeBar(KCM)
    local c = KCM.db.profile.macroBar
    c.enabled, c.locked, c.scale, c.buttonSize = false, true, 1.5, 50
    c.labelText, c.barBorderColor = "FULL", { 1, 0, 0, 1 }
    c.point, c.relPoint, c.x, c.y = "TOP", "TOP", 120, -40
    c.order = { "DRINK", "FOOD" }
    c.shown = { FOOD = false }
    return c
end

test("macrobar Defaults: every page setting back to its shipped value, the lock kept, one apply pass",
    function(t)
        local KCM = h.loader.loadFullAddon()
        local H   = KCM.Settings.Helpers
        local reset = macroBarDefaults(KCM)
        customizeBar(KCM)

        local updates, structural = 0, 0
        KCM.MacroBar.Update = function() updates = updates + 1 end
        local realAll = H.RefreshAllPanels
        H.RefreshAllPanels = function(...) structural = structural + 1; return realAll(...) end

        reset()

        local c, d = KCM.db.profile.macroBar, KCM.dbDefaults.profile.macroBar
        for k, v in pairs(d) do
            if k ~= "locked" then
                t.eq(ser(c[k]), ser(v), "macroBar." .. k .. " is back to its default")
            end
        end
        t.eq(c.locked, true, "the lock is the General page's setting and survives")
        t.falsy(c.barBorderColor == d.barBorderColor, "a color comes back as a copy, not the defaults' own table")
        t.falsy(c.order == d.order, "and so does the slot order")
        t.eq(updates, 1, "the bar is re-applied once, not once per row")
        t.eq(structural, 1, "and the page is rebuilt once")
        H.RefreshAllPanels = realAll
    end)

test("macrobar Defaults: the page reset is one [Set] line, written into the same table",
    function(t)
        -- A bulk reset logs ONE `[Set] <act> <scope>: N rows` line, never one per
        -- row, and N is the rows it actually changed (debug-logging-§10).
        --
        -- red under: dropping `bulk` from doResetPage's SetManyAndRefresh opts --
        -- every row logs its own [Set] line again -- or reinstating
        -- `KCM.db.profile.macroBar = CopyTable(BAR_DEFAULTS)`, which replaces the
        -- table and writes no row through the helper.
        local KCM = h.loader.loadFullAddon()
        local H   = KCM.Settings.Helpers
        local reset = macroBarDefaults(KCM)
        local c = customizeBar(KCM)
        KCM.MacroBar.Update = function() end

        -- N, measured before the reset: the page rows not already at their default.
        local rows, moved = 0, 0
        for _, def in ipairs(KCM.Settings.Schema) do
            if def.panel == "macrobar" and def.default ~= nil then
                rows = rows + 1
                if ser(H.Get(def.path)) ~= ser(def.default) then moved = moved + 1 end
            end
        end

        local D = KCM.DebugLog.instance
        KCM.State.debug = true
        D:Clear()
        reset()
        KCM.State.debug = false

        t.eq(KCM.db.profile.macroBar, c, "the macroBar table is the one every reader already holds")
        local set = {}
        for _, line in ipairs(D.buffer) do
            local body = line:match("%[Set%] (.*)$")
            if body then set[#set + 1] = body end
        end
        t.eqList(set, { ("reset Macro Bar page: %d rows"):format(moved) },
            "one [Set] line for the whole page, and no per-row line")
        t.eq(moved, 7, "customizeBar moved seven page rows; the lock and the position are not rows here")
        t.truthy(rows >= 60, "the whole page was in scope (" .. rows .. " rows)")
    end)

test("macrobar Defaults: a batch that fails leaves the position where it was, and says so",
    function(t)
        -- red under: ResetPosition running before the batch validates, so a refused
        -- batch still moves the bar back to center.
        local KCM = h.loader.loadFullAddon()
        local H   = KCM.Settings.Helpers
        local reset = macroBarDefaults(KCM)
        local c = customizeBar(KCM)
        KCM.MacroBar.Update = function() end

        local realMany, realSay, said = H.SetManyAndRefresh, KCM.Say, {}
        H.SetManyAndRefresh = function() return false end
        KCM.Say = function(msg) said[#said + 1] = tostring(msg) end
        reset()
        H.SetManyAndRefresh, KCM.Say = realMany, realSay

        t.eq(c.point, "TOP", "the anchor point is untouched")
        t.eq(c.x, 120, "and so is the offset")
        t.eq(#said, 1, "the failure is reported once")
        t.truthy((said[1] or ""):find("position", 1, true), "and names the position: " .. tostring(said[1]))

        reset()
        local d = KCM.dbDefaults.profile.macroBar
        t.eq(c.point, d.point, "a batch that succeeds resets the position with it")
        t.eq(c.x, d.x, "offset and all")
    end)

-- ---------------------------------------------------------------------------
-- #35 characterization: the slot order and per-macro visibility writers
-- ---------------------------------------------------------------------------

test("macrobar: dragging one slot onto another stores the swapped order", function(t)
    local KCM = h.loader.loadFullAddon()
    local want = CopyTable(KCM.dbDefaults.profile.macroBar.order)
    want[1], want[2] = want[2], want[1]
    t.eq(KCM.MacroBar.SwapSlots(want[2], want[1]), true, "the swap reports success")
    t.eq(ser(KCM.db.profile.macroBar.order), ser(want), "and the stored order is swapped")
    t.eq(KCM.MacroBar.SwapSlots("FOOD", "FOOD"), false, "a slot dropped on itself is no change")
end)

-- The Buttons tab's own writers -- its drag and its tick -- are pinned in
-- tests/test_macrobar_buttons.lua, which took the two checkbox cases that used to
-- sit here when the checkbox grid became a draggable list.

-- The architecture-§5 named-state claim ARCHITECTURE.md makes -- MacroBar owns the
-- bar's drag-only geometry, and savePosition and ResetPosition are its only
-- writers -- checked against the source rather than trusted. A write the naming
-- leaves out is a MUST failure, so a new writer in another file must fail here
-- until it is named. The load pass creates the empty `macroBar` table and nothing
-- else; a whole-table write over `macroBar` anywhere else is a schema-row write
-- (the Defaults button's, before #36) and is caught too.
--
-- red under: any file but modules/MacroBar.lua assigning `.point` / `.relPoint`,
-- `macroBar.x` / `.y`, or the whole `macroBar` table.
local function assignedLHS(code)
    local s = code:find("[^=~<>]=%f[^=]")
    return s and code:sub(1, s) or nil
end

test("Named state: modules/MacroBar.lua is the only runtime writer of the bar's geometry", function(t)
    local root = _G.KCM_TEST_ROOT or "."
    local PATTERNS = {
        "%.point%f[^%w_]", "%.relPoint%f[^%w_]", "macroBar%.[xy]%f[^%w_]", "%.macroBar%s*$",
    }
    local ALLOWED = { ["modules/MacroBar.lua"] = true, ["core/Database.lua"] = true }
    local offenders = {}
    for _, rel in ipairs(h.loader.tocFiles()) do
        if not ALLOWED[rel] and rel:match("^[cms][a-z]*/.+%.lua$") then
            local f = io.open(root .. "/" .. rel, "r")
            if f then
                local n = 0
                for line in f:lines() do
                    n = n + 1
                    local lhs = assignedLHS((line:gsub("%-%-.*$", "")))
                    if lhs then
                        for _, p in ipairs(PATTERNS) do
                            if lhs:find(p) then offenders[#offenders + 1] = rel .. ":" .. n end
                        end
                    end
                end
                f:close()
            end
        end
    end
    t.eq(#offenders, 0, "bar geometry written outside MacroBar: " .. table.concat(offenders, ", "))
end)
