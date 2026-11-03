-- test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker, LibKa0s#64; CM-04 of the 2026-10-29 skinning rollout, O3 and X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the General page's key and the Skin tab's, the unlock
-- preview, the close); WHEN it shows (a profile whose `skin.pickerSeen` is false, once per session after the
-- first PLAYER_ENTERING_WORLD and after every profile event, never while the addon stands down,
-- held through combat); that only the player's close marks it seen; and the preview (R6-PV): the
-- bar unlocked at show, the eye's toggle, every close's restore. The trigger cases spy on the
-- instance's SkinPicker; the last cases drive the library's real window.

local h = _G.KCM_TEST
local test = h.test

local OWNER = "ConsumableMaster"
local PATH = "skin.pickerSeen"

--- Run `fn(calls)` with the Options instance's SkinPicker replaced by a recorder: each call's
--- spec, in order. The instance is what KCM.Settings.Helpers reads through, so the swap is on it.
local function spying(KCM, fn)
    local UI = KCM.Settings.Helpers.instance
    local real = UI.SkinPicker
    local calls = {}
    UI.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    -- The client's C_Timer.After is asynchronous; the mock's runs at once, which would loop the
    -- notice's combat retry (SG-L3) for as long as combat lasts. A queue stands in for it.
    local realAfter = _G.C_Timer.After
    calls.timers = {}
    _G.C_Timer.After = function(delay, f) calls.timers[#calls.timers + 1] = { delay = delay, fn = f } end
    local ok, err = pcall(fn, calls)
    _G.C_Timer.After = realAfter
    UI.SkinPicker = real
    if not ok then error(err, 0) end
end

local function load()
    local KCM = h.loader.loadFullAddon()
    KCM.HideSkinPicker()
    return KCM
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────

-- red under: a default of true (no profile would ever show it), or a row that draws itself.
test("Skin picker: skin.pickerSeen defaults to false, a skip-render row no page reset reaches", function(t)
    local KCM = load()
    t.eq(KCM.dbDefaults.profile.skin.pickerSeen, false, "every profile, old and new, shows it once (O3)")
    local row = KCM.Settings.Helpers.FindSchema(PATH)
    t.truthy(row, PATH .. " is a schema row")
    t.eq(row and row.type, "bool", "a bool")
    t.eq(row and row.skipRender, true, "nothing draws it")
end)

-- red under: a set that is not the write seam (a pick would never reach the profile), a page or
-- tab key O.SelectTab does not know (the gear would open the wrong page), or the old one-shot
-- onPreview beside spec.preview (R6-PV: the eye is the unlock mode's toggle).
test("Skin picker: the spec names this owner, its seams, the General page's Skin tab and the unlock eye", function(t)
    local KCM = load()
    local spec = KCM.SkinPickerSpec()
    t.eq(spec.owner, OWNER, "the owner core/SkinSetup.lua registered")
    t.truthy(rawequal(spec.get, KCM.SkinChoice), "get is the read seam")
    t.truthy(rawequal(spec.set, KCM.WriteSkinChoice), "set is the write seam")
    t.eq(spec.page, "general", "the General page's panel key")
    t.eq(spec.tab, "Appearance", "the Skin tab's key")
    KCM.Settings.builders.general({})
    t.truthy(KCM.Settings.Helpers.instance.__panelFor(spec.page), "the page O.SelectTab finds")
    t.eq(spec.onPreview, nil, "no one-shot eye: spec.preview is the eye (R6-PV)")
    local pv = spec.preview
    t.eq(type(pv), "table", "spec.preview, the library's preview contract (OptionsSkinPicker 11)")
    t.eq(pv and pv.mode, "unlock", "the unlocked macro bar is this addon's preview (00_PLAN call 2)")
    for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
        t.eq(type(pv and pv[k]), "function", "preview." .. k)
    end
    t.eq(type(spec.onClose), "function", "the close marks it seen")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("Skin picker: an unseen profile shows it; a seen one does not", function(t)
    local KCM = load()
    spying(KCM, function(calls)
        KCM.MaybeShowSkinPicker()
        t.eq(#calls, 1, "pickerSeen false: the picker shows")
        t.eq(calls[1] and calls[1].owner, OWNER, "for this owner")
        KCM.Schema:Set(PATH, true)
        KCM.MaybeShowSkinPicker()
        t.eq(#calls, 1, "pickerSeen true: it does not show again")
    end)
end)

-- red under: dropping the call from OnPlayerEnteringWorld, or lighting it on every loading screen.
test("Skin picker: it is offered once per session, two seconds after the first entering-world", function(t)
    local KCM = load()
    local after = _G.C_Timer.After
    local fuses = {}
    _G.C_Timer.After = function(delay, fn) fuses[#fuses + 1] = { delay = delay, fn = fn } end
    local ok, err = pcall(function()
        KCM:OnPlayerEnteringWorld("PLAYER_ENTERING_WORLD", true, false)
        KCM:OnPlayerEnteringWorld("PLAYER_ENTERING_WORLD", false, false)
        local twos = {}
        for _, f in ipairs(fuses) do if f.delay == 2 then twos[#twos + 1] = f end end
        t.eq(#twos, 1, "one two-second fuse for two loading screens")
        spying(KCM, function(calls)
            if twos[1] then twos[1].fn() end
            t.eq(#calls, 1, "the fuse shows the picker")
        end)
    end)
    _G.C_Timer.After = after
    if not ok then error(err, 0) end
end)

test("Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", function(t)
    local KCM = load()
    local mock = h.loader.mock
    mock.setCombat(true)
    local ok, err = pcall(function()
        spying(KCM, function(calls)
            KCM.MaybeShowSkinPicker()
            KCM.MaybeShowSkinPicker()
            t.eq(#calls, 0, "nothing shows in combat")
            mock.setCombat(false)
            mock.base.__fireEvent("PLAYER_REGEN_ENABLED")
            t.eq(#calls, 1, "combat's end shows it, once for two held starts")
            mock.base.__fireEvent("PLAYER_REGEN_ENABLED")
            t.eq(#calls, 1, "and the one-shot target is gone")
        end)
    end)
    mock.setCombat(false)
    if not ok then error(err, 0) end
end)

-- red under: noticeWaiting still set while the retry runs, so a combat that outlasts one retry loses the notice (SG-L3).
test("Skin picker: the notice's combat retry repeats until combat ends", function(t)
    local KCM = load()
    local mock = h.loader.mock
    mock.setCombat(true)
    local ok, err = pcall(function()
        spying(KCM, function(calls)
            local _, why = KCM.MaybeShowSkinNotice()
            t.eq(why, "combat")
            t.eq(#calls.timers, 1, "one retry armed")
            calls.timers[1].fn()
            t.eq(#calls.timers, 2, "still in combat: it asks again")
            mock.setCombat(false)
            calls.timers[2].fn()
            t.eq(#calls, 1, "combat over: the notice shows")
        end)
    end)
    mock.setCombat(false)
    if not ok then error(err, 0) end
end)

-- red under: a picker shown, or a held start kept, while the addon is off.
test("Skin picker: a stood-down addon shows nothing and drops a held start", function(t)
    local KCM = load()
    local mock = h.loader.mock
    local ok, err = pcall(function()
        spying(KCM, function(calls)
            mock.setCombat(true)
            KCM.MaybeShowSkinPicker()
            mock.setCombat(false)
            KCM.OnEnabledChanged(false)
            mock.base.__fireEvent("PLAYER_REGEN_ENABLED")
            KCM.MaybeShowSkinPicker()
            t.eq(#calls, 0, "disabled: no picker, from the held start or a fresh one")
            KCM.OnEnabledChanged(true)
            KCM.MaybeShowSkinPicker()
            t.eq(#calls, 1, "enabled again: it shows")
        end)
    end)
    mock.setCombat(false)
    if not ok then error(err, 0) end
end)

-- red under: dropping the call from the profile handler, or showing before the take-down.
test("Skin picker: a profile event takes it down first and shows it for a profile that has not seen it",
    function(t)
        local KCM = load()
        KCM.Schema:Set(PATH, true)
        local order = {}
        local hide = KCM.HideSkinPicker
        KCM.HideSkinPicker = function() order[#order + 1] = "hide"; return hide() end
        local ok, err = pcall(function()
            spying(KCM, function(calls)
                KCM.db:SetProfile("Fresh")
                t.eq(#calls, 1, "a new profile starts unseen, so it shows")
                t.eq(order[1], "hide", "the old showing went down first")
                KCM.Schema:Set(PATH, true)
                KCM.db:SetProfile("Default")
                t.eq(#calls, 1, "a profile that has seen it stays down")
            end)
        end)
        KCM.HideSkinPicker = hide
        if not ok then error(err, 0) end
    end)

-- ── the library's real window ────────────────────────────────────────────────────────────────

-- red under: an onClose that does not write the key, or a quiet take-down that does.
test("Skin picker: the player's close marks it seen; this addon's own take-down does not", function(t)
    local KCM = load()
    local f = KCM.MaybeShowSkinPicker()
    t.truthy(f, "the library's picker window")
    KCM.HideSkinPicker()
    t.eq(KCM.db.profile.skin.pickerSeen, false, "a take-down this addon makes is not the player's close")
    f = KCM.MaybeShowSkinPicker()
    t.truthy(f and f.close, "shown again, with its close control")
    local click = f.close.__fire or f.close._run
    click(f.close, "OnClick")
    t.eq(KCM.db.profile.skin.pickerSeen, true, "the player's close is the one write, through the seam")
    t.eq(KCM.MaybeShowSkinPicker(), nil, "and it does not come back on this profile")
end)

-- red under: a stand-down that leaves a shown picker on screen, or one that marks it seen.
test("Skin picker: the stand-down takes a shown picker down, unseen", function(t)
    local KCM = load()
    local UI = KCM.Settings.Helpers.instance
    -- The library's one queue across every Ka0s addon: `current` is the picker up on screen.
    local function upHere()
        local q = LibStub("LibKa0s-Options-1.0").__pickerQueue
        return (q and q.current and q.current.inst == UI) and true or false
    end
    t.truthy(KCM.MaybeShowSkinPicker(), "the library's picker window")
    t.truthy(upHere(), "it is the picker up")
    KCM.OnEnabledChanged(false)
    t.falsy(upHere(), "the stand-down took it down")
    t.eq(KCM.db.profile.skin.pickerSeen, false, "unseen, so it comes back at the next stand-up login")
    KCM.OnEnabledChanged(true)
end)

-- ── the preview: unlock mode (R6-PV; Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6) ────────

local function locked(KCM) return KCM.MacroBarModel.Config().locked end
local function click(btn) (btn.__fire or btn._run)(btn, "OnClick") end

--- A locked bar and the picker shown by `/cm skin`'s act, then `fn(f)`; the picker always goes.
local function withPicker(KCM, startLocked, fn)
    KCM.MacroBar.SetLocked(startLocked)
    local f = KCM.RunSkinVerb()
    local ok, err = pcall(fn, f)
    KCM.HideSkinPicker()
    if not ok then error(err, 0) end
end

-- red under: no spec.preview (nothing enters at show), or an enter that bypasses the write seam.
test("Skin picker preview: a locked bar unlocks when the picker shows, through the lock seam", function(t)
    local KCM = load()
    local real, writes = KCM.MacroBar.SetLocked, {}
    KCM.MacroBar.SetLocked(true)
    KCM.MacroBar.SetLocked = function(v) writes[#writes + 1] = v; return real(v) end
    local ok, err = pcall(function()
        local f = KCM.RunSkinVerb()
        t.truthy(f, "the picker is up")
        t.eq(locked(KCM), false, "the bar is unlocked: the mode entered at show")
        t.eq(writes[1], false, "through KCM.MacroBar.SetLocked, the seam /cm unlock and the panel use")
        t.eq(KCM.Settings.Helpers.Get("macroBar.locked"), false, "the Lock frame row reads the same value")
        t.truthy(f.preview and f.preview:IsShown(), "the eye shows")
        t.truthy(f.preview.lit, "lit: the mode is on")
    end)
    KCM.MacroBar.SetLocked = real
    KCM.HideSkinPicker()
    if not ok then error(err, 0) end
end)

-- red under: an enter-only eye (PFE's old previewSkin), or a close that leaves the bar unlocked.
test("Skin picker preview: the eye toggles the lock and the close control puts it back", function(t)
    local KCM = load()
    withPicker(KCM, true, function(f)
        click(f.preview)
        t.eq(locked(KCM), true, "the eye locks it again")
        t.falsy(f.preview.lit, "dimmed")
        click(f.preview)
        t.eq(locked(KCM), false, "the eye unlocks it")
        click(f.close)
        t.eq(locked(KCM), true, "the close control restores the locked bar")
    end)
end)

-- red under: a restore on only one of the close routes.
test("Skin picker preview: Apply, Escape, the gear and the take-down each restore the lock", function(t)
    local KCM = load()
    withPicker(KCM, true, function(f)
        t.eq(locked(KCM), false, "entered")
        click(f.apply)
        t.eq(locked(KCM), true, "Apply restores")
    end)
    withPicker(KCM, true, function(f)
        t.eq(locked(KCM), false, "entered")
        -- What UISpecialFrames does on Escape: the window hidden, then its OnHide. The mock frame
        -- answers IsShown with its chaining no-op, so the hidden state is stubbed for the fire.
        f:Hide()
        f.IsShown = function() return false end
        local fire = f.__fire or f._run
        fire(f, "OnHide")
        f.IsShown = nil
        t.eq(locked(KCM), true, "Escape (the window hidden) restores")
    end)
    KCM.Settings.builders.general({})
    withPicker(KCM, true, function(f)
        t.eq(locked(KCM), false, "entered")
        click(f.settings)
        t.eq(locked(KCM), true, "the gear restores")
    end)
    withPicker(KCM, true, function()
        t.eq(locked(KCM), false, "entered")
        KCM.HideSkinPicker()
        t.eq(locked(KCM), true, "KCM.HideSkinPicker (the stand-down's take-down) restores")
    end)
end)

-- red under: a picker that records or enters on an unlocked bar, or a restore that locks it.
test("Skin picker preview: an unlocked bar is left alone, and the eye's lock is undone on close", function(t)
    local KCM = load()
    withPicker(KCM, false, function(f)
        t.eq(locked(KCM), false, "already unlocked: nothing entered")
        click(f.close)
        t.eq(locked(KCM), false, "and the close leaves it unlocked")
    end)
    withPicker(KCM, false, function(f)
        click(f.preview)
        t.eq(locked(KCM), true, "the eye locks it")
        click(f.close)
        t.eq(locked(KCM), false, "the close puts back the unlocked bar it opened with")
    end)
end)

-- red under: a restore that writes the opening profile's lock into the profile switched to.
test("Skin picker preview: a profile switch while the picker is up leaves the new profile's lock alone", function(t)
    local KCM = load()
    KCM.Schema:Set(PATH, true)
    KCM.db:SetProfile("Other")
    KCM.MacroBar.SetLocked(false)
    KCM.Schema:Set(PATH, true)
    KCM.db:SetProfile("Default")
    KCM.MacroBar.SetLocked(true)
    local f = KCM.RunSkinVerb()
    t.truthy(f, "the picker is up")
    t.eq(locked(KCM), false, "entered on Default")
    KCM.db:SetProfile("Other")
    t.eq(locked(KCM), false, "Other keeps its own unlocked bar: the restore did not lock it")
    KCM.db:SetProfile("Default")
    KCM.MacroBar.SetLocked(true)
end)

-- red under: a profile guard cleared by the close, so the library's end-of-combat retry of a
-- refused restore (OptionsSkinPicker minor 11 parks one asked under InCombatLockdown) lands in the
-- profile switched to and locks its bar.
test("Skin picker preview: a profile switch in combat stays refused when combat ends", function(t)
    local KCM = load()
    local mock = h.loader.mock
    KCM.Schema:Set(PATH, true)
    KCM.db:SetProfile("Other")
    KCM.MacroBar.SetLocked(false)
    KCM.Schema:Set(PATH, true)
    KCM.db:SetProfile("Default")
    KCM.MacroBar.SetLocked(true)
    local ok, err = pcall(function()
        t.truthy(KCM.RunSkinVerb(), "the picker is up")
        t.eq(locked(KCM), false, "entered on Default")
        mock.setCombat(true)
        KCM.db:SetProfile("Other")
        t.eq(locked(KCM), false, "Other keeps its own unlocked bar in combat")
        local O = LibStub("LibKa0s-Options-1.0")
        t.truthy(#O.__parkedPanels > 0, "the refused restore was parked for combat's end")
        mock.setCombat(false)
        O.__OnParkEvent("PLAYER_REGEN_ENABLED")
        t.eq(locked(KCM), false, "and after combat: the parked retry is refused too")
    end)
    mock.setCombat(false)
    KCM.HideSkinPicker()
    KCM.db:SetProfile("Default")
    KCM.MacroBar.SetLocked(true)
    if not ok then error(err, 0) end
end)

test("Skin picker: degraded, every member answers and nothing shows", function(t)
    local KCM = h.loader.loadWithSchemaDegraded()
    t.eq(type(KCM.MaybeShowSkinPicker), "function", "MaybeShowSkinPicker on the degraded arm")
    t.eq(KCM.MaybeShowSkinPicker(), nil, "nothing to show without the library")
    KCM.HideSkinPicker()
    t.eq(KCM.SkinPickerSpec().owner, OWNER, "the spec still names the owner")
end)
