-- tests/test_macrobar_flyout.lua — the per-slot flyout's behavior: the
-- candidate list (MacroBarFlyout.Candidates, pure over Selector + config — cap,
-- invert, the shipped config), click gating on every secure button of the bar,
-- and the flyout's hover, idle-clock and combat hand-offs.
--
-- Peeled out of tests/test_macrobar.lua (1425) for layout-§1's 1000-1500 band
-- (CM-ATS-02, ATS-14), beside the #32 cuts. The flyout's bind/apply pass and
-- its chrome stay in tests/test_macrobar_chrome.lua; this file is the two
-- contiguous sections the parent carried under "Flyout candidate list" and
-- "Click gating". Every case moved whole: not one assertion changed. The
-- flyout's candidate SOURCE is covered in tests/test_selector.lua
-- (Selector.ListAvailable).

local h = _G.KCM_TEST
local test = h.test

-- `fcfg` is shared rather than copied — tests/macrobar_support.lua says why.
local support = dofile((_G.KCM_TEST_ROOT or ".") .. "/tests/macrobar_support.lua")
local fcfg = support.fcfg

-- ---------------------------------------------------------------------------
-- Flyout candidate list (modules/MacroBarFlyout.lua — cap + invert)
-- ---------------------------------------------------------------------------

test("macrobar flyout: candidates come back in rank order, best first", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    for i = 1, 3 do mock.setBag(seed[i], 1) end
    local out = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12 })
    t.eq(#out, 3, "all three owned entries")
    t.eq(out[1], KCM.Selector.PickBestForCategory("HP_POT"),
        "entry 1 is the macro's pick, so it renders closest to the button")
end)

test("macrobar flyout: invert reverses the order without dropping anything", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    for i = 1, 3 do mock.setBag(seed[i], 1) end
    local normal   = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12 })
    local inverted = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12, flyoutInvert = true })
    t.eq(#inverted, #normal, "same number of entries")
    t.eq(inverted[1], normal[#normal], "first becomes last")
    t.eq(inverted[#inverted], normal[1], "and last becomes first")
end)

test("macrobar flyout: the list is capped to flyoutMax, keeping the top ranks", function(t)
    local KCM = h.loader.loadFullAddon()
    local mock = h.loader.mock
    -- Own every seeded potion, whatever the seed's length happens to be.
    for _, id in ipairs(KCM.SEED.HP_POT) do mock.setBag(id, 1) end
    local full   = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 12 })
    local capped = KCM.MacroBarFlyout.Candidates("HP_POT", { flyoutMax = 2 })
    t.truthy(#full > 2, "more owned than the cap under test")
    t.eq(#capped, 2, "capped to flyoutMax")
    t.eq(capped[1], full[1], "keeps the top-ranked entry")
    t.eq(capped[2], full[2], "and the runner-up")
end)

test("macrobar flyout: the cap is bounded by the pool ceiling, not just the setting", function(t)
    local KCM = h.loader.loadFullAddon()
    t.truthy(KCM.MacroBarFlyout.MAX_ENTRIES >= 1, "a hard ceiling exists")
    -- The pool can only grow out of combat, so flyoutMax must never exceed it.
    local def = KCM.Settings.Helpers.FindSchema("macroBar.flyoutMax")
    t.truthy(def.max <= KCM.MacroBarFlyout.MAX_ENTRIES,
        "the slider cannot ask for more entries than the pool allows")
end)

test("macrobar flyout: it ships on, opening upward, closing after 3s", function(t)
    local KCM = h.loader.loadPure()
    local d = KCM.dbDefaults.profile.macroBar
    t.eq(d.flyout, true, "flyout enabled by default")
    t.eq(d.flyoutPoint, "TOP", "opens to the top by default")
    t.eq(d.flyoutInvert, false, "best-first by default")
    t.eq(d.labelText, "SHORT", "labels use the category short form by default")
    t.eq(d.labelScale, 25, "label text is a quarter of the button")
    t.eq(d.flyoutAutoClose, 1, "idles closed after a second")
    t.eq(d.flyoutIndicatorScale, 33, "band is a third of the icon")
    t.eq(d.flyoutBackdrop, true, "the strip gets a panel so it can't be mistaken for more bar")
    t.eq(d.flyoutShadeColor[4], 0.8, "the band is mostly opaque so the arrow reads clearly")
    t.eq(d.flyoutArrowScale, 100, "and the arrow fills the band")
end)

test("macrobar flyout: auto-close is configurable and 0 means never", function(t)
    local KCM = h.loader.loadFullAddon()
    local def = KCM.Settings.Helpers.FindSchema("macroBar.flyoutAutoClose")
    t.truthy(def, "auto-close is a schema row, so /cm set reaches it")
    t.eq(def.type, "number", "seconds")
    t.eq(def.min, 0, "0 is allowed, and means never auto-close")
    t.truthy(def.max >= 3, "and the default sits inside the range")
end)

test("macrobar flyout: Create wires the secure frames without erroring", function(t)
    local KCM = h.loader.loadFullAddon()
    -- Regression guard for two shipped crashes, both "attempt to call a nil
    -- value" on a frame whose template didn't grant the method: SetFrameRef on a
    -- plain SecureActionButton, and again on a container whose secure template
    -- was combined with BackdropTemplate (which dropped the injection). The mock
    -- now withholds template-gated methods, so this case fails if either returns.
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "FOOD"
    local flyout = KCM.MacroBarFlyout.Create(button, "FOOD", 1)
    t.truthy(flyout, "Create returns the container")
    t.truthy(flyout.SetFrameRef, "the container is a secure handler")
    t.truthy(flyout.bg and flyout.bg.SetBackdrop,
        "and its panel is a separate BackdropTemplate child, not the handler itself")
end)

-- ---------------------------------------------------------------------------
-- Click gating — every secure button on the bar fires on the release it hears
-- ---------------------------------------------------------------------------
-- Both the slot and the flyout entries register for "AnyUp" only. Blizzard's
-- SecureActionButton_OnClick acts on the DOWN half when the button's
-- `useOnKeyDown` attribute is unset and the ActionButtonUseKeyDown cvar is on
-- (the client default), so an up-only button handed a mouse click returned
-- false and did nothing: no Lua error, no UI error. That is how a friend's bar
-- was dead while the author's (cvar off) worked. `fires` below is the client's
-- own decision, lifted from SecureTemplates.lua, for a hardware mouse click
-- (isKeyPress and isSecureAction both nil) with the cvar forced ON.
local function firesOnUpWithKeyDownCvar(btn)
    local useOnKeyDown = btn:GetAttribute("useOnKeyDown")
    if useOnKeyDown == nil then useOnKeyDown = true end   -- GetCVarBool("ActionButtonUseKeyDown")
    local pressAndHold = btn:GetAttribute("pressAndHoldAction")
    useOnKeyDown = useOnKeyDown or pressAndHold
    local down = false                                     -- "AnyUp" hands us only the release
    return (down and useOnKeyDown) or (not down and not useOnKeyDown) or false
end

test("macrobar click: a bar slot fires on mouse-up even with ActionButtonUseKeyDown on", function(t)
    local KCM = h.loader.loadFullAddon()
    local parent = CreateFrame("Frame", "KCMMacroBarTest")
    local btn = KCM.MacroBarButton.Create(parent, "WPN_ENCH", 1)
    t.truthy(btn, "Create builds the slot")
    t.eq(btn:GetAttribute("type"), "macro", "the slot clicks through its macro")
    t.eq(btn:GetAttribute("useOnKeyDown"), false,
        "the slot pins itself to the release it is registered for")
    t.truthy(firesOnUpWithKeyDownCvar(btn),
        "so the client's gate acts on the click instead of silently returning")
end)

test("macrobar click: a flyout entry fires on mouse-up even with ActionButtonUseKeyDown on", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    mock.setItem(seed[1], { name = "Pot", subType = "Potions" })
    mock.setBag(seed[1], 1)

    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "HP_POT"
    local flyout = KCM.MacroBarFlyout.Create(button, "HP_POT", 1)
    button.flyout = flyout
    KCM.MacroBarFlyout.Apply(button, fcfg{ flyout = true })

    local e = flyout.entries and flyout.entries[1]
    t.truthy(e, "Apply grows the pool through the real create path")
    t.eq(e:GetAttribute("useOnKeyDown"), false,
        "the entry pins itself to the release it is registered for")
    t.truthy(firesOnUpWithKeyDownCvar(e),
        "so the client's gate acts on the click instead of silently returning")
end)

test("macrobar flyout: ApplyBackdrop paints the panel child, not the container", function(t)
    local KCM = h.loader.loadFullAddon()
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "FOOD"
    local flyout = KCM.MacroBarFlyout.Create(button, "FOOD", 1)
    -- The container has no SetBackdrop at all, so painting it would error.
    t.falsy(flyout.SetBackdrop, "container cannot take a backdrop")
    KCM.MacroBarFlyout.ApplyBackdrop(flyout, KCM.db.profile.macroBar)
    t.truthy(true, "ApplyBackdrop completes against the child")
end)

test("macrobar flyout: leaving hands off to the countdown, and says so securely", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local seed = KCM.SEED.HP_POT
    for _, id in ipairs(seed) do mock.setBag(id, 1) end

    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "HP_POT"
    local flyout = KCM.MacroBarFlyout.Create(button, "HP_POT", 1)

    -- The _onleave snippet cannot call InCombatLockdown, so the Lua side has to
    -- put the delay where the snippet can read it. Without kcmGrace the snippet
    -- closes on leave and the auto-close setting has no observable effect at all.
    KCM.db.profile.macroBar.flyoutAutoClose = 2
    KCM.MacroBarFlyout.Apply(button, KCM.db.profile.macroBar)
    t.eq(flyout:GetAttribute("kcmGrace"), 2, "the grace period reaches the snippet")

    KCM.db.profile.macroBar.flyoutAutoClose = 0
    KCM.MacroBarFlyout.Apply(button, KCM.db.profile.macroBar)
    t.eq(flyout:GetAttribute("kcmGrace"), 0, "zero means the snippet closes on leave")
end)

test("macrobar flyout: combat state is driven into the snippet, not polled", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "FOOD"
    local flyout = KCM.MacroBarFlyout.Create(button, "FOOD", 1)

    -- In combat the insecure idle poll can't hide anything, so the snippet must
    -- close on leave instead of waiting for a countdown that will never fire.
    -- It learns the combat state from an attribute driver.
    local drivers = mock.attributeDrivers[flyout] or {}
    t.truthy(drivers.kcmCombat, "an attribute driver feeds kcmCombat")
    t.truthy(tostring(drivers.kcmCombat):find("combat", 1, true),
        "and it is driven off the [combat] conditional")
end)

-- bindEntry paints an entry through the BAR's own appliers, so an entry is
-- chrome-identical to a bar slot. None of that is guarded on KCM.MacroBarButton
-- being present any more — it never could be, since FO.RefreshCooldown above it
-- has always called through that table bare — so the border branch is a plain
-- buttonBorder test. This pins both sides of it.
test("macrobar flyout: an entry's border follows buttonBorder through the bar's own applier", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    for _, id in ipairs(KCM.SEED.HP_POT) do mock.setBag(id, 1) end
    mock.setCombat(false)

    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button.catKey = "HP_POT"
    local flyout = KCM.MacroBarFlyout.Create(button, "HP_POT", 1)

    local barCfg = KCM.db.profile.macroBar
    barCfg.flyout = true
    barCfg.buttonBorder = true
    t.truthy(KCM.MacroBarFlyout.Apply(button, barCfg), "flyout applied")
    local entry = flyout.entries[1]
    t.truthy(entry, "at least one candidate bound an entry")

    -- The stub answers every unknown method truthily, so shown-ness is counted
    -- at the border rather than queried.
    local shows, hides = 0, 0
    entry.border.Show = function() shows = shows + 1 end
    entry.border.Hide = function() hides = hides + 1 end

    KCM.MacroBarFlyout.Apply(button, barCfg)
    t.eq(shows, 1, "buttonBorder on → the entry border is painted and shown")
    t.eq(hides, 0, "and never hidden on that pass")

    barCfg.buttonBorder = false
    KCM.MacroBarFlyout.Apply(button, barCfg)
    t.eq(hides, 1, "buttonBorder off → the entry border is hidden")
    t.eq(shows, 1, "and not re-shown")
end)

test("macrobar flyout: the idle clock resets while the mouse is on the strip", function(t)
    local KCM  = h.loader.loadFullAddon()
    h.loader.mock.setCombat(false)
    local hidden, hovered = false, true
    local flyout = {
        IsMouseOver = function() return hovered end,
        Hide        = function() hidden = true end,
    }
    -- flyoutAutoClose measures time spent OFF the flyout, so hovering must keep
    -- resetting it however long the flyout has been open.
    for _ = 1, 20 do KCM.MacroBarFlyout.IdleTick(flyout, 0.5, 1) end
    t.falsy(hidden, "never closes while hovered")
    t.eq(flyout.awayFor, 0, "and the clock stays at zero")

    hovered = false
    t.falsy(KCM.MacroBarFlyout.IdleTick(flyout, 0.4, 1), "0.4s away is not yet idle enough")
    t.truthy(KCM.MacroBarFlyout.IdleTick(flyout, 0.7, 1), "1.1s away closes it")
    t.truthy(hidden, "and the strip is hidden")
end)

test("macrobar flyout: hovering the band alone also holds the flyout open", function(t)
    local KCM = h.loader.loadFullAddon()
    h.loader.mock.setCombat(false)
    -- The band is not a child of the strip, so one IsMouseOver can't see both.
    local hidden = false
    local flyout = {
        IsMouseOver  = function() return false end,
        Hide         = function() hidden = true end,
        kcmIndicator = { IsMouseOver = function() return true end },
    }
    KCM.MacroBarFlyout.IdleTick(flyout, 5, 1)
    t.falsy(hidden, "still open while the band is hovered")
end)

test("macrobar flyout: the idle clock stands down in combat", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local hidden = false
    local flyout = { IsMouseOver = function() return false end,
                     Hide = function() hidden = true end }
    mock.setCombat(true)
    KCM.MacroBarFlyout.IdleTick(flyout, 5, 1)
    t.falsy(hidden, "no hide attempted mid-fight")
    mock.setCombat(false)
    KCM.MacroBarFlyout.IdleTick(flyout, 5, 1)
    t.truthy(hidden, "closes once combat ends")
end)

test("macrobar flyout: an auto-close of 0 never closes on idle", function(t)
    local KCM = h.loader.loadFullAddon()
    h.loader.mock.setCombat(false)
    local hidden = false
    local flyout = { IsMouseOver = function() return false end,
                     Hide = function() hidden = true end }
    KCM.MacroBarFlyout.IdleTick(flyout, 999, 0)
    t.falsy(hidden, "0 means stay open until hover-out or a click")
end)

test("macrobar flyout: Close hides the strip and stands down in combat", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    local hidden = false
    local flyout = { Hide = function() hidden = true end }

    -- Close is what the PostClick hooks on the slot and on every entry call.
    -- It is ordinary insecure Lua, so mid-fight it declines rather than
    -- attempting a hide the client may refuse; the secure _onleave covers that
    -- case the moment the cursor moves.
    mock.setCombat(true)
    KCM.MacroBarFlyout.Close(flyout)
    t.falsy(hidden, "no hide attempted in combat")

    mock.setCombat(false)
    KCM.MacroBarFlyout.Close(flyout)
    t.truthy(hidden, "closes out of combat")
end)

test("macrobar flyout: Close tolerates a nil flyout", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.MacroBarFlyout.Close(nil)
    t.truthy(true, "no error")
end)
