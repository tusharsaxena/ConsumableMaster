-- tests/test_macrobar_display.lua — what a macro-bar slot shows: display
-- resolution and the slot tooltip (core/MacroDisplay.lua), Pickup's combat
-- refusal, and the cooldown application and GCD-swipe suppression
-- (modules/MacroBarButton.lua, secret-value safe).
--
-- Peeled out of tests/test_macrobar.lua (1425) for layout-§1's 1000-1500 band
-- (CM-ATS-02, ATS-14), beside the #32 cuts (tests/test_macrobar_layout.lua,
-- tests/test_macrobar_chrome.lua). The seam is the file's own four section
-- headings, contiguous and self-contained: each builds its own fixtures
-- (a recording tooltip, a fake cooldown frame) and reads nothing of the model,
-- schema or flyout sections around it. Every case moved whole: not one
-- assertion changed.

local h = _G.KCM_TEST
local test = h.test

-- ---------------------------------------------------------------------------
-- MacroDisplay
-- ---------------------------------------------------------------------------

test("macrodisplay: an unwritten macro falls back to the cooking-pot icon", function(t)
    local KCM = h.loader.loadPure()
    t.eq(KCM.MacroDisplay.Texture("KCM_FOOD"), KCM.MacroDisplay.FALLBACK_ICON,
        "no macroState, no macro -> fallback")
end)

test("macrodisplay: an item pick resolves to the item's icon and count", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setItem(1234, { name = "Bread", subType = "Food & Drink" })
    h.loader.mock.setBag(1234, 7)
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = 1234 }
    t.eq(KCM.MacroDisplay.PickID("KCM_FOOD"), 1234, "pick id")
    t.eq(KCM.MacroDisplay.Texture("KCM_FOOD"), "icon:1234", "item icon")
    t.eq(KCM.MacroDisplay.Count("KCM_FOOD"), 7, "owned count")
end)

test("macrodisplay: a spell pick resolves to the spell icon and has no count", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setSpell(999, { name = "Recuperate", known = true })
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = KCM.ID.AsSpell(999) }
    t.eq(KCM.MacroDisplay.Texture("KCM_FOOD"), "spellicon:999", "spell icon")
    t.falsy(KCM.MacroDisplay.Count("KCM_FOOD"), "spells have no stack count")
end)

test("macrodisplay: item and spell cooldowns both report active plus a span", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setItem(1234, { name = "Potion", subType = "Potions" })
    h.loader.mock.setCooldown(1234, 100, 300)
    KCM.db.profile.macroState["KCM_HP_POT"] = { lastItemID = 1234 }
    local active, obj, start, duration = KCM.MacroDisplay.Cooldown("KCM_HP_POT")
    t.eq(active, true, "item cooldown is running")
    t.eq(start, 100, "item cooldown start")
    t.eq(duration, 300, "item cooldown duration")
    t.eq(obj.duration, 300, "and the same span reaches the duration object")

    h.loader.mock.setSpell(999, { name = "Recuperate", known = true })
    h.loader.mock.setCooldown(KCM.ID.AsSpell(999), 50, 120)
    KCM.db.profile.macroState["KCM_HS"] = { lastItemID = KCM.ID.AsSpell(999) }
    local sActive, sObj, sStart, sDuration = KCM.MacroDisplay.Cooldown("KCM_HS")
    t.eq(sActive, true, "spell cooldown is running")
    t.eq(sStart, 50, "spell cooldown start")
    t.eq(sDuration, 120, "spell cooldown duration")
    t.eq(sObj.duration, 120, "the client's own duration object is passed through")
end)

test("macrodisplay: an empty-state macro reports no pick, count or cooldown", function(t)
    local KCM = h.loader.loadPure()
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = nil }
    t.falsy(KCM.MacroDisplay.PickID("KCM_FOOD"), "no pick")
    t.falsy(KCM.MacroDisplay.Count("KCM_FOOD"), "no count")
    t.falsy(KCM.MacroDisplay.Cooldown("KCM_FOOD"), "no cooldown")
end)

-- A GameTooltip that records which setter fired with which arguments. The real
-- stub answers every method with itself, so it cannot tell a spell tooltip from
-- an item one — and which setter runs IS the behavior SetTooltip owns.
local function recordingTooltip()
    local gt = { calls = {} }
    local function record(name)
        return function(_, ...) gt.calls[#gt.calls + 1] = { name, ... } end
    end
    gt.SetOwner     = record("SetOwner")
    gt.SetSpellByID = record("SetSpellByID")
    gt.SetItemByID  = record("SetItemByID")
    gt.SetText      = record("SetText")
    gt.AddLine      = record("AddLine")
    gt.Show         = record("Show")
    return gt
end

local function calledWith(gt, name)
    for _, c in ipairs(gt.calls) do
        if c[1] == name then return c end
    end
    return nil
end

test("macrodisplay: SetTooltip points at the spell a spell pick resolves to", function(t)
    local KCM = h.loader.loadPure()
    local gt = recordingTooltip()
    _G.GameTooltip = gt
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = KCM.ID.AsSpell(999) }
    KCM.MacroDisplay.SetTooltip(h.loader.mock.makeStub(), "KCM_FOOD")
    t.truthy(calledWith(gt, "SetOwner"), "the owner is set before any setter")
    t.eq(calledWith(gt, "SetSpellByID")[2], 999, "the spell sentinel resolves to its spellID")
    t.falsy(calledWith(gt, "SetItemByID"), "no item setter on the spell path")
    t.truthy(calledWith(gt, "Show"), "the tooltip is shown")
end)

test("macrodisplay: SetTooltip points at the item an item pick resolves to", function(t)
    local KCM = h.loader.loadPure()
    local gt = recordingTooltip()
    _G.GameTooltip = gt
    h.loader.mock.setItem(1234, { name = "Bread", subType = "Food & Drink" })
    KCM.db.profile.macroState["KCM_FOOD"] = { lastItemID = 1234 }
    KCM.MacroDisplay.SetTooltip(h.loader.mock.makeStub(), "KCM_FOOD")
    t.eq(calledWith(gt, "SetItemByID")[2], 1234, "the item tooltip is set from the pick")
    t.falsy(calledWith(gt, "SetSpellByID"), "no spell setter on the item path")
    t.truthy(calledWith(gt, "Show"), "the tooltip is shown")
end)

test("macrodisplay: SetTooltip falls back to the macro name and body when unresolved", function(t)
    local KCM = h.loader.loadPure()
    local gt = recordingTooltip()
    _G.GameTooltip = gt
    _G.CreateMacro("KCM_FOOD", 1, "#showtooltip\n/use Bread")
    KCM.MacroDisplay.SetTooltip(h.loader.mock.makeStub(), "KCM_FOOD")
    t.eq(calledWith(gt, "SetText")[2], "KCM_FOOD", "the name heads the fallback tooltip")
    t.eq(calledWith(gt, "AddLine")[2], "#showtooltip\n/use Bread", "the body follows it")
    t.truthy(calledWith(gt, "Show"), "the fallback still shows — never a stale tooltip")
end)

test("macrodisplay: SetTooltip with no such macro shows just the name", function(t)
    local KCM = h.loader.loadPure()
    local gt = recordingTooltip()
    _G.GameTooltip = gt
    KCM.MacroDisplay.SetTooltip(h.loader.mock.makeStub(), "KCM_NOPE")
    t.eq(calledWith(gt, "SetText")[2], "KCM_NOPE", "the name is still shown")
    t.falsy(calledWith(gt, "AddLine"), "index 0 means no such macro, so no body line")
    t.truthy(calledWith(gt, "Show"), "the tooltip is shown")
end)

test("macrodisplay: SetTooltip does nothing without an owner", function(t)
    local KCM = h.loader.loadPure()
    local gt = recordingTooltip()
    _G.GameTooltip = gt
    KCM.MacroDisplay.SetTooltip(nil, "KCM_FOOD")
    t.eq(#gt.calls, 0, "no owner, no tooltip work at all")
end)

-- An AIO macro stores no lastItemID (no single item is behind a composite), so
-- its tooltip used to fall through to the raw macro text. It now shows the step
-- `#showtooltip` shows: the first enabled in-combat pick while fighting, the
-- first enabled out-of-combat pick otherwise.
local function aioTooltip(KCM, picks, inCombat)
    local gt = recordingTooltip()
    _G.GameTooltip = gt
    h.loader.mock.setCombat(inCombat)
    KCM.Selector.PickBestForCategory = function(refKey) return picks[refKey] end
    _G.CreateMacro("KCM_HP_AIO", 134400, "#showtooltip\n/castsequence [combat] reset=combat item:5512")
    KCM.MacroDisplay.SetTooltip(h.loader.mock.makeStub(), "KCM_HP_AIO")
    return gt
end

test("macrodisplay: an AIO tooltip out of combat shows its out-of-combat spell, not the macro text", function(t)
    local KCM = h.loader.loadPure()
    h.loader.mock.setSpell(185311, { name = "Recuperate" })
    local gt = aioTooltip(KCM, { HS = 5512, HP_POT = 171267, FOOD = KCM.ID.AsSpell(185311) }, false)
    local c = calledWith(gt, "SetSpellByID")
    t.truthy(c, "the spell tooltip is set")
    t.eq(c and c[2], 185311, "for the out-of-combat step's spell")
    t.falsy(calledWith(gt, "SetText"), "the macro-text fallback never runs")
    t.truthy(calledWith(gt, "Show"), "the tooltip is shown")
end)

test("macrodisplay: an AIO tooltip in combat shows the first in-combat step", function(t)
    local KCM = h.loader.loadPure()
    local gt = aioTooltip(KCM, { HS = 5512, HP_POT = 171267, FOOD = 113509 }, true)
    local c = calledWith(gt, "SetItemByID")
    t.eq(c and c[2], 5512, "the healthstone heads the /castsequence, so it heads the tooltip")
    t.falsy(calledWith(gt, "SetText"), "the macro-text fallback never runs")
end)

test("macrodisplay: an AIO tooltip skips a disabled or pickless step, as the body does", function(t)
    local KCM = h.loader.loadPure()
    local aioCfg = KCM.db.profile.categories.HP_AIO
    aioCfg.enabled = aioCfg.enabled or {}
    aioCfg.enabled.HS = false
    local gt = aioTooltip(KCM, { HS = 5512, HP_POT = 171267 }, true)
    t.eq((calledWith(gt, "SetItemByID") or {})[2], 171267, "a disabled healthstone hands over to the potion")

    aioCfg.enabled.HS = nil
    gt = aioTooltip(KCM, { HP_POT = 171267 }, true)
    t.eq((calledWith(gt, "SetItemByID") or {})[2], 171267, "and so does a healthstone with no pick")
end)

test("macrodisplay: an AIO tooltip with nothing on the current side still falls back to the macro", function(t)
    local KCM = h.loader.loadPure()
    local gt = aioTooltip(KCM, { HS = 5512 }, false)
    t.eq((calledWith(gt, "SetText") or {})[2], "KCM_HP_AIO",
        "no out-of-combat pick: the name heads the fallback, as #showtooltip would show nothing")
    t.falsy(calledWith(gt, "SetItemByID"), "the in-combat pick is not borrowed for the wrong side")
end)

-- ---------------------------------------------------------------------------
-- Pickup (core/MacroDisplay.lua) — PickupMacro is protected in combat
-- ---------------------------------------------------------------------------

test("macrodisplay: Pickup puts the macro on the cursor out of combat", function(t)
    local KCM = h.loader.loadPure()
    _G.CreateMacro("KCM_FOOD", 1, "/use Bread")
    t.truthy(KCM.MacroDisplay.Pickup("KCM_FOOD"), "the pickup is reported as done")
    local kind, idx = _G.GetCursorInfo()
    t.eq(kind, "macro", "and the cursor holds a macro")
    t.eq(idx, _G.GetMacroIndexByName("KCM_FOOD"), "the one asked for")
end)

test("macrodisplay: Pickup refuses in combat instead of calling the protected API", function(t)
    local KCM = h.loader.loadPure()
    _G.CreateMacro("KCM_FOOD", 1, "/use Bread")
    h.loader.mock.setCombat(true)
    local ok = KCM.MacroDisplay.Pickup("KCM_FOOD")
    h.loader.mock.setCombat(false)
    t.falsy(ok, "PickupMacro would raise ADDON_ACTION_BLOCKED, so it is not called")
    t.falsy(_G.GetCursorInfo(), "and nothing lands on the cursor")
    local said = table.concat(h.loader.mock.output, "\n")
    t.truthy(said:find("in combat", 1, true), "the refusal is explained in chat")
end)

test("macrodisplay: Pickup on a macro that does not exist is a silent no-op", function(t)
    local KCM = h.loader.loadPure()
    t.falsy(KCM.MacroDisplay.Pickup("KCM_NOPE"), "index 0 means no such macro")
    t.falsy(_G.GetCursorInfo(), "so the cursor is left alone")
end)

-- ---------------------------------------------------------------------------
-- Cooldown application (modules/MacroBarButton.lua — secret-value safe)
-- ---------------------------------------------------------------------------

local function fakeCooldownFrame()
    local cd = {}
    function cd:SetCooldown(s, d) self.start, self.duration = s, d end
    function cd:SetCooldownFromDurationObject(obj) self.durationObject = obj end
    function cd:Clear() self.cleared = true end
    function cd:SetAlpha(a) self.alpha = a end
    function cd:SetAlphaFromBoolean(flag, whenTrue, whenFalse)
        self.alphaFromBoolean = { flag, whenTrue, whenFalse }
        self.alpha = flag and whenTrue or whenFalse
    end
    function cd:SetDrawBling(flag) self.drawBling = flag end
    return cd
end

test("macrobar cooldowns: an active cooldown paints from the duration object", function(t)
    local KCM = h.loader.loadFullAddon()
    local obj = h.loader.mock.makeDuration(100, 300)
    local cd  = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, true, obj, 100, 300)
    t.eq(cd.durationObject, obj, "the object setter wins over the raw-number one")
    t.falsy(cd.duration, "so SetCooldown is never reached")
    t.falsy(cd.cleared, "and the swipe is not cleared")
end)

test("macrobar cooldowns: an inactive cooldown clears the swipe", function(t)
    local KCM = h.loader.loadFullAddon()
    local cd  = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, false, h.loader.mock.makeDuration(0, 0), 0, 0)
    t.truthy(cd.cleared, "nothing running means an empty frame")
    t.falsy(cd.durationObject, "and no setter is called at all")
end)

test("macrobar cooldowns: a client without duration objects falls back to numbers", function(t)
    local KCM = h.loader.loadFullAddon()
    local cd  = fakeCooldownFrame()
    cd.SetCooldownFromDurationObject = nil
    KCM.MacroBarButton.ApplyCooldown(cd, true, h.loader.mock.makeDuration(100, 300), 100, 300)
    t.eq(cd.start, 100, "the raw pair drives the swipe instead")
    t.eq(cd.duration, 300, "duration too")
end)

test("macrobar cooldowns: restricted cooldowns are never compared or set as numbers", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    -- The shipped crash: mid-fight C_Spell.GetSpellCooldown returns SECRET
    -- numbers, so `duration > 0` errored — and once that was removed, so did
    -- SetCooldown, which refuses a secret from a tainted caller.
    mock.setSpell(999, { name = "Recuperate", known = true })
    mock.setCooldown(KCM.ID.AsSpell(999), 50, 120)
    KCM.db.profile.macroState["KCM_HS"] = { lastItemID = KCM.ID.AsSpell(999) }
    mock.setCooldownsRestricted(true)

    local btn = { catKey = "HS", cooldown = fakeCooldownFrame() }
    local ok, err = pcall(KCM.MacroBarButton.RefreshCooldown, btn)
    mock.setCooldownsRestricted(false)

    t.truthy(ok, "the in-combat refresh tick does not error: " .. tostring(err))
    t.truthy(btn.cooldown.durationObject, "the swipe still runs, via the duration object")
    t.falsy(btn.cooldown.duration, "and no secret number is handed to SetCooldown")
end)

test("macrobar cooldowns: a restricted spell still reports whether it is running", function(t)
    local KCM  = h.loader.loadFullAddon()
    local mock = h.loader.mock
    mock.setSpell(999, { name = "Recuperate", known = true })
    mock.setCooldown(KCM.ID.AsSpell(999), 50, 120)
    KCM.db.profile.macroState["KCM_HS"] = { lastItemID = KCM.ID.AsSpell(999) }
    mock.setCooldownsRestricted(true)

    local active, obj, start, duration = KCM.MacroDisplay.Cooldown("KCM_HS")
    mock.setCooldownsRestricted(false)

    t.eq(active, true, "isActive is NeverSecret, so it survives the restriction")
    t.truthy(obj, "and a duration object is still available")
    t.falsy(start, "but the secret start is withheld from callers")
    t.falsy(duration, "and so is the secret duration")
end)

-- ---------------------------------------------------------------------------
-- GCD-swipe suppression (modules/MacroBarButton.lua — copied from KickCD)
-- ---------------------------------------------------------------------------

test("macrobar cooldowns: showGCD false hides the swipe via the curve-evaluated duration", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    local cd = fakeCooldownFrame()
    -- Remaining well under KCM.GCD_UPPER (1.6s): just the GCD, should hide.
    local gcdObj = h.loader.mock.makeDuration(0, 0.5)
    KCM.MacroBarButton.ApplyCooldown(cd, true, gcdObj, 0, 0.5)
    t.truthy(cd.alphaFromBoolean, "SetAlphaFromBoolean was called")
    t.eq(cd.alphaFromBoolean[1], true, "flag argument is always true")
    t.eq(cd.alphaFromBoolean[2], 0, "curve evaluates to 0 (hidden) inside the GCD window")

    -- Remaining well over KCM.GCD_UPPER: a real cooldown, should stay visible.
    local realObj = h.loader.mock.makeDuration(0, 60)
    KCM.MacroBarButton.ApplyCooldown(cd, true, realObj, 0, 60)
    t.eq(cd.alphaFromBoolean[2], 1, "curve evaluates to 1 (visible) past the GCD window")
end)

test("macrobar cooldowns: showGCD true never suppresses and always shows the swipe", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = true
    local cd = fakeCooldownFrame()
    local gcdObj = h.loader.mock.makeDuration(0, 0.5)
    KCM.MacroBarButton.ApplyCooldown(cd, true, gcdObj, 0, 0.5)
    t.eq(cd.alpha, 1, "alpha stays fully visible")
    t.falsy(cd.alphaFromBoolean, "SetAlphaFromBoolean is never reached when showGCD is on")
end)

test("macrobar cooldowns: no duration object skips suppression without erroring", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    local cd = fakeCooldownFrame()
    local ok, err = pcall(KCM.MacroBarButton.ApplyCooldown, cd, true, nil, 100, 300)
    t.truthy(ok, "no error without a duration object: " .. tostring(err))
    t.eq(cd.alpha, 1, "falls back to fully visible")
    t.falsy(cd.alphaFromBoolean, "never reached without a duration object")
end)

test("macrobar cooldowns: a missing C_CurveUtil degrades to full alpha without erroring", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    _G.C_CurveUtil = nil
    local cd = fakeCooldownFrame()
    local obj = h.loader.mock.makeDuration(0, 0.5)
    local ok, err = pcall(KCM.MacroBarButton.ApplyCooldown, cd, true, obj, 0, 0.5)
    t.truthy(ok, "no error without C_CurveUtil: " .. tostring(err))
    t.eq(cd.alpha, 1, "falls back to fully visible")
end)

test("macrobar cooldowns: the GCD-suppress curve is built once and reused", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    local calls = 0
    local realCreate = _G.C_CurveUtil.CreateCurve
    _G.C_CurveUtil.CreateCurve = function(...)
        calls = calls + 1
        return realCreate(...)
    end
    for _ = 1, 3 do
        local cd = fakeCooldownFrame()
        KCM.MacroBarButton.ApplyCooldown(cd, true, h.loader.mock.makeDuration(0, 0.5), 0, 0.5)
    end
    t.eq(calls, 1, "CreateCurve is called exactly once across repeated ApplyCooldown calls")
end)

test("macrobar cooldowns: showGCD false disables the completion bling", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    local cd = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, true, h.loader.mock.makeDuration(0, 60), 0, 60)
    t.eq(cd.drawBling, false, "bling is off while GCD suppression is active")
end)

test("macrobar cooldowns: showGCD true enables the completion bling", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = true
    local cd = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, true, h.loader.mock.makeDuration(0, 60), 0, 60)
    t.eq(cd.drawBling, true, "bling is on when the user asked to see the GCD swipe")
end)

test("macrobar cooldowns: the inactive path still applies the correct bling state", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    local cd = fakeCooldownFrame()
    KCM.MacroBarButton.ApplyCooldown(cd, false, h.loader.mock.makeDuration(0, 0), 0, 0)
    t.truthy(cd.cleared, "still clears the swipe on the inactive path")
    t.eq(cd.drawBling, false, "bling reflects showGCD even though no cooldown is running")
end)

test("macrobar cooldowns: a frame lacking SetDrawBling degrades without error", function(t)
    local KCM = h.loader.loadFullAddon()
    KCM.db.profile.macroBar.showGCD = false
    local cd = fakeCooldownFrame()
    cd.SetDrawBling = nil
    local ok, err = pcall(KCM.MacroBarButton.ApplyCooldown, cd, true, h.loader.mock.makeDuration(0, 60), 0, 60)
    t.truthy(ok, "no error without SetDrawBling: " .. tostring(err))
end)
