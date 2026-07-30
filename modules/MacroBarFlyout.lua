-- modules/MacroBarFlyout.lua — the per-slot hover flyout.
--
-- Hovering a slot's indicator opens a strip of secure buttons, one per available
-- candidate in that category (owned item / known spell), top-ranked closest to
-- the button. Clicking one uses it. This exists only on the macro bar — a KCM_*
-- macro dragged onto a Blizzard action bar is an ordinary macro with no flyout.
--
-- ---------------------------------------------------------------------------
-- Why the open/close logic is a secure snippet
-- ---------------------------------------------------------------------------
-- Flyout entries have to actually use items, so they are SecureActionButtons,
-- so they are PROTECTED frames — and showing a protected frame in combat is
-- forbidden to addon code. A Lua OnEnter/OnLeave pair would therefore work out
-- of combat and silently fail exactly when a combat potion matters most.
--
-- So the hover behavior is handed to Blizzard's secure environment instead:
-- the indicator and the container are SecureHandlerEnterLeaveTemplate frames
-- whose `_onenter` / `_onleave` snippets run inside the restricted environment,
-- where showing and hiding these frames IS allowed mid-combat. The snippets use
-- `IsUnderMouse(true)` on both frames so traveling from the indicator into the
-- flyout keeps it open, and leaving either one closes it.
--
-- Hover-out is therefore the one close path that survives combat; see "Closing"
-- below for the two that don't.
--
-- ---------------------------------------------------------------------------
-- What is NOT possible in combat
-- ---------------------------------------------------------------------------
-- Writing a secure attribute (which item a button uses) and creating a button
-- are both blocked in combat. So flyout CONTENT is rebuilt out of combat only:
-- `MacroBar.Update()` defers to PLAYER_REGEN_ENABLED like every other protected
-- operation on the bar. The consequence is deliberate and documented: a flyout's
-- entries are frozen for the duration of a fight. Drink your last potion
-- mid-combat and its entry stays listed until combat ends, where clicking it
-- simply fails — the same staleness a normal action bar has.

local _, NS = ...
local KCM = NS
KCM.MacroBarFlyout = KCM.MacroBarFlyout or {}
local FO = KCM.MacroBarFlyout

local CreateFrame = CreateFrame
-- A small clean triangle. Blizzard's Arrow-Up-Up carries its own glow/padding
-- and smeared badly when stretched across the band.
local ARROW_TEXTURE = [[Interface\ChatFrame\ChatFrameExpandArrow]]
local BACKDROP_TEX  = [[Interface\Buttons\WHITE8X8]]
local HIGHLIGHT_TEXTURE = [[Interface\Buttons\ButtonHilight-Square]]

-- Hard ceiling on entries per slot, independent of the user's flyoutMax. The
-- pool can only grow out of combat, so it is bounded rather than unbounded.
FO.MAX_ENTRIES = 16

-- Secure snippets. `_onenter` shows the flyout; `_onleave` closes it only when
-- the mouse has left BOTH the indicator and the flyout, so the gap-free travel
-- between them doesn't dismiss it. Attached to both frames — whichever the mouse
-- leaves, the same test runs.
local ONENTER = [=[
    local flyout = self:GetFrameRef("flyout")
    if flyout and self:GetAttribute("kcmEntries") ~= 0 then
        flyout:Show()
    end
]=]
-- Leaving does NOT necessarily close: when `flyoutAutoClose` is set, the mouse
-- leaving starts that countdown instead, and the Lua idle poll performs the hide.
-- Closing here as well would pre-empt the countdown entirely — which it did, and
-- made the setting look broken.
--
-- The exception is combat. The idle poll is insecure Lua and cannot hide a
-- protected frame mid-fight, so if we also declined here the strip would sit open
-- for the rest of the fight. `kcmCombat` is fed by an attribute driver so the
-- snippet can tell, and closes immediately in that case.
local ONLEAVE = [=[
    local flyout = self:GetFrameRef("flyout")
    local anchor = self:GetFrameRef("indicator")
    if not flyout then return end
    if flyout:IsUnderMouse(true) then return end
    if anchor and anchor:IsUnderMouse(true) then return end
    local grace = flyout:GetAttribute("kcmGrace")
    if grace and grace > 0 and flyout:GetAttribute("kcmCombat") ~= "1" then
        return      -- hand off to the idle countdown
    end
    flyout:Hide()
]=]
local function inCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

-- ---------------------------------------------------------------------------
-- Closing
-- ---------------------------------------------------------------------------
-- Three paths, and only ONE of them survives combat:
--
--   * mouse leaves the band and the strip — the secure `_onleave` snippet.
--     Runs inside the restricted environment, so it works mid-fight. This is the
--     reliable one.
--   * clicking the macro, or a flyout entry — a PostClick hook (below).
--   * `flyoutAutoClose` seconds of no interaction — our own C_Timer.
--
-- The last two are ordinary insecure Lua, so they decline to act while
-- InCombatLockdown() is true rather than attempting a hide the client may
-- refuse. There is no way around that for either: PostClick runs insecurely
-- whatever fired it, and there is NO timer inside the secure environment (no
-- C_Timer there, and macro conditionals have no time predicate, so a state
-- driver can't stand in). The gap is narrow in practice — hover-out closes the
-- flyout the instant the cursor moves, which after a click it invariably does.

-- Is the mouse still on the band or anywhere in the strip? The band is NOT a
-- child of the strip, so one IsMouseOver can't cover both — the pair has to be
-- tested. `flyout.kcmIndicator` is the handle Create hands over for this.
local function stillHovered(flyout)
    if flyout.IsMouseOver and flyout:IsMouseOver() then return true end
    local ind = flyout.kcmIndicator
    if ind and ind.IsMouseOver and ind:IsMouseOver() then return true end
    return false
end

-- Close now, unless we're mid-fight (see above).
function FO.Close(flyout)
    if not flyout then return end
    if inCombat() then return end
    flyout:Hide()
end

-- "Clicking me dismisses the flyout." PostClick rather than the OnClick script
-- itself: the slot and the entries are SecureActionButtons whose click handling
-- belongs to Blizzard, and PostClick is the sanctioned place to run afterwards
-- without touching it.
local function closeOnClick(button, flyout)
    if not (button and flyout and button.HookScript) then return end
    button:HookScript("PostClick", function() FO.Close(flyout) end)
end

-- Idle auto-close, as a poll rather than a one-shot timer.
--
-- `flyoutAutoClose` measures time the mouse has spent OFF the flyout, so any
-- hover resets the clock — pointing at the strip must never yank it away. A
-- one-shot C_Timer can't express that: it would have to re-arm itself on every
-- expiry-while-hovered, which is unbounded recursion (and was, briefly).
--
-- Polling costs an OnUpdate only while a flyout is open, which is a second or two
-- at a time. `awayFor` accumulates only when unhovered; reaching the delay closes
-- the strip, subject to the same combat rule as every other insecure close.
function FO.IdleTick(flyout, elapsed, delay)
    if not (flyout and delay and delay > 0) then return false end
    if stillHovered(flyout) then
        flyout.awayFor = 0
        return false
    end
    flyout.awayFor = (flyout.awayFor or 0) + (elapsed or 0)
    if flyout.awayFor < delay then return false end
    if inCombat() then return false end
    flyout:Hide()
    return true
end

local function idlePoll(flyout, elapsed)
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
    FO.IdleTick(flyout, elapsed, tonumber(cfg and cfg.flyoutAutoClose) or 0)
end

-- Start / stop the poll. Driven from the container's OnShow / OnHide, because the
-- open itself happens inside a secure snippet we can't hook.
local function startIdlePoll(flyout)
    flyout.awayFor = 0
    local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
    if (tonumber(cfg and cfg.flyoutAutoClose) or 0) <= 0 then
        flyout:SetScript("OnUpdate", nil)   -- 0 = stay open until hover-out or a click
        return
    end
    flyout:SetScript("OnUpdate", idlePoll)
end

local function stopIdlePoll(flyout)
    flyout:SetScript("OnUpdate", nil)
end

-- ---------------------------------------------------------------------------
-- Construction (out of combat only — secure templates + attributes)
-- ---------------------------------------------------------------------------

-- One flyout entry. Deliberately NOT drag-registered: these are launchers for a
-- specific candidate, not a rearrangeable slot, and picking one up would put a
-- bare item on the cursor.
local function createEntry(flyout, index)
    local btn = CreateFrame("Button", flyout:GetName() .. "Entry" .. index, flyout,
        "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyUp")
    btn:Hide()

    btn.backdropTex = btn:CreateTexture(nil, "BACKGROUND")
    btn.backdropTex:SetAllPoints(btn)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)

    btn:SetHighlightTexture(HIGHLIGHT_TEXTURE)
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)

    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints(btn)
    overlay:SetFrameLevel(btn:GetFrameLevel() + 2)
    btn.count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetFrameLevel(btn:GetFrameLevel() + 1)

    btn:SetScript("OnEnter", function(self)
        local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
        if cfg and cfg.tooltips == false then return end
        if KCM.MacroDisplay then KCM.MacroDisplay.SetTooltipForID(self, self.kcmID) end
    end)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Using an entry dismisses the strip.
    closeOnClick(btn, flyout)

    return btn
end

-- Build the indicator + container for one bar slot. Both are secure handlers so
-- the hover snippets above can run in combat.
function FO.Create(button, catKey, index)
    if inCombat() then return nil end
    local baseName = "KCMMacroBarFlyout" .. index

    -- ONE template. Combining "SecureHandlerEnterLeaveTemplate, BackdropTemplate"
    -- silently dropped the secure handler's method injection — SetFrameRef came
    -- back nil and Create blew up. The backdrop lives on a child frame instead
    -- (same pattern the button borders use), which keeps the two concerns apart.
    local flyout = CreateFrame("Frame", baseName, button,
        "SecureHandlerEnterLeaveTemplate")
    flyout:Hide()
    -- Mouse-enabled so the container gets its OWN enter/leave events. Without
    -- this the _onleave snippet below never fires and the flyout can't close.
    -- Its entries are children, so they still take clicks first, and moving onto
    -- one only looks like "leaving" the container — which is exactly why the
    -- snippet tests IsUnderMouse(true), recursively.
    flyout:EnableMouse(true)
    flyout.entries = {}
    flyout.catKey  = catKey

    -- Panel behind the entries. Pinned to the container's own frame level so the
    -- entries (children, one level up) always draw over it.
    flyout.bg = CreateFrame("Frame", nil, flyout, "BackdropTemplate")
    flyout.bg:SetAllPoints(flyout)
    flyout.bg:SetFrameLevel(flyout:GetFrameLevel())

    -- The indicator is a shaded band drawn INSIDE the icon along one edge, with
    -- a small arrow on it. It is motion-enabled but NOT click-enabled, so
    -- hovering anywhere on the shade opens the flyout while a click still passes
    -- straight through to the macro button underneath.
    local indicator = CreateFrame("Frame", baseName .. "Indicator", button,
        "SecureHandlerEnterLeaveTemplate")
    if indicator.SetMouseClickEnabled and indicator.SetMouseMotionEnabled then
        indicator:SetMouseClickEnabled(false)
        indicator:SetMouseMotionEnabled(true)
    else
        -- Fallback: hover works, but the band eats clicks over its own strip.
        indicator:EnableMouse(true)
    end

    -- Both handlers need refs to both frames so either one's _onleave can run
    -- the same "is the mouse still over the pair?" test.
    for _, frame in ipairs({ indicator, flyout }) do
        frame:SetFrameRef("flyout", flyout)
        frame:SetFrameRef("indicator", indicator)
        frame:SetAttribute("_onenter", ONENTER)
        frame:SetAttribute("_onleave", ONLEAVE)
    end

    -- Until Apply runs there is nothing to show; the snippet gates on this, so
    -- seed it rather than leaving the attribute nil.
    flyout:SetAttribute("kcmEntries", 0)
    indicator:SetAttribute("kcmEntries", 0)
    flyout:SetAttribute("kcmGrace", 0)

    -- Combat state, readable from inside the snippet. An attribute driver is the
    -- only way to get it there — the restricted environment has no
    -- InCombatLockdown — and it's the same mechanism as the bar's visibility
    -- driver, so it stays taint-free.
    if RegisterAttributeDriver then
        RegisterAttributeDriver(flyout, "kcmCombat", "[combat] 1; 0")
    end

    -- Shade first, arrow on top of it, both inside the band.
    indicator.shade = indicator:CreateTexture(nil, "ARTWORK")
    indicator.shade:SetAllPoints(indicator)

    indicator.arrow = indicator:CreateTexture(nil, "OVERLAY")
    indicator.arrow:SetTexture(ARROW_TEXTURE)
    indicator.arrow:SetPoint("CENTER")

    -- The flyout opens from a secure snippet we can't hook, so the idle poll is
    -- started from OnShow — which fires however the frame came to be shown. The
    -- poll is self-resetting on hover, so there's nothing to do on OnEnter.
    flyout:SetScript("OnShow", startIdlePoll)
    flyout:SetScript("OnHide", stopIdlePoll)

    -- Clicking the macro itself also dismisses the strip.
    closeOnClick(button, flyout)

    -- stillHovered() needs the pair, and the indicator is not a child of the
    -- flyout, so hand it over explicitly.
    flyout.kcmIndicator = indicator

    button.flyout    = flyout
    button.indicator = indicator
    return flyout
end

-- ---------------------------------------------------------------------------
-- Content + geometry (out of combat only)
-- ---------------------------------------------------------------------------

-- Point one entry at an opaque KCM ID: secure attributes for the click, then
-- icon / count / cooldown for the look. Items use `type="item"` with the
-- `item:<id>` form so a localized name can't break it; spells need the name,
-- which is what the secure spell attribute takes.
local function bindEntry(btn, id, cfg, size)
    local ID = KCM.ID
    btn.kcmID = id
    btn:SetSize(size, size)

    if ID and ID.IsSpell(id) then
        local name = KCM.Compat and KCM.Compat.GetSpellName
            and KCM.Compat.GetSpellName(ID.SpellID(id))
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", name or "")
    else
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", "item:" .. tostring(id))
    end

    local MD = KCM.MacroDisplay
    btn.icon:SetTexture(MD and MD.TextureForID(id) or nil)
    local zoom = tonumber(cfg.iconZoom) or 0
    if zoom < 0 then zoom = 0 elseif zoom > 40 then zoom = 40 end
    local z = zoom / 100
    btn.icon:SetTexCoord(z, 1 - z, z, 1 - z)

    local count = MD and MD.CountForID(id)
    if count and count > 0 and cfg.showCount ~= false then
        btn.count:SetText(count)
        btn.count:Show()
    else
        btn.count:SetText("")
        btn.count:Hide()
    end

    FO.RefreshCooldown(btn)

    -- Entries take the WHOLE button-appearance block, not just the border, so
    -- the strip is visibly the same kind of thing as the bar it hangs off.
    local bg = cfg.buttonBackdropColor or {}
    btn.backdropTex:SetColorTexture(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.6)
    if cfg.buttonBackdrop then btn.backdropTex:Show() else btn.backdropTex:Hide() end

    if cfg.buttonBorder ~= false and KCM.MacroBarButton then
        local off = tonumber(cfg.buttonBorderOffset) or 0
        btn.border:ClearAllPoints()
        btn.border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -off,  off)
        btn.border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  off, -off)
        btn.border:SetBackdrop({
            edgeFile = KCM.MacroBarButton.BorderTexture(cfg.buttonBorderStyle),
            edgeSize = math.max(1, tonumber(cfg.buttonBorderSize) or 4),
        })
        local c = cfg.buttonBorderColor or {}
        btn.border:SetBackdropBorderColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
        btn.border:Show()
    else
        btn.border:Hide()
    end
end

-- Backdrop behind the strip. Without one, a flyout opening over a second row of
-- bar buttons is nearly indistinguishable from them — same size, same border,
-- same icons. The panel of the container is what says "this is a popup". Border
-- style / thickness / color are shared with the BAR's own frame so the two read
-- as one design, with only the fill color separate.
function FO.ApplyBackdrop(flyout, cfg)
    local bg = flyout and flyout.bg
    if not (bg and bg.SetBackdrop and cfg) then return end
    if cfg.flyoutBackdrop == false then
        bg:SetBackdrop(nil)
        return
    end
    local edge
    if KCM.MacroBarButton and KCM.MacroBarButton.BorderTexture then
        edge = KCM.MacroBarButton.BorderTexture(cfg.barBorderStyle)
    end
    bg:SetBackdrop({
        bgFile   = BACKDROP_TEX,
        edgeFile = edge,
        edgeSize = math.max(1, tonumber(cfg.barBorderSize) or 4),
    })
    local fill = cfg.flyoutBackdropColor or {}
    bg:SetBackdropColor(fill[1] or 0, fill[2] or 0, fill[3] or 0, fill[4] or 0.85)
    local bc = cfg.barBorderColor or {}
    bg:SetBackdropBorderColor(bc[1] or 0.25, bc[2] or 0.25, bc[3] or 0.25, bc[4] or 1)
end

function FO.RefreshCooldown(btn)
    if not (btn and btn.cooldown and btn.kcmID) then return end
    local MD = KCM.MacroDisplay
    if not MD then return end
    local start, duration, enable = MD.CooldownForID(btn.kcmID)
    if start and duration and duration > 0 then
        btn.cooldown:SetCooldown(start, duration, enable)
    else
        btn.cooldown:Clear()
    end
end

-- Rebuild one slot's flyout: resolve the available candidates, grow the pool,
-- bind and position the entries, and record the count the secure snippet gates
-- on. No-op in combat — every step here is protected.
function FO.Apply(button, cfg)
    local flyout = button and button.flyout
    if not (flyout and cfg) then return false end
    if inCombat() then return false end

    if not cfg.flyout then
        button.indicator:Hide()
        flyout:Hide()
        for _, e in ipairs(flyout.entries) do e:Hide() end
        flyout:SetAttribute("kcmEntries", 0)
        button.indicator:SetAttribute("kcmEntries", 0)
        return true
    end

    local BL = KCM.MacroBarLayout

    -- Indicator: a shaded band hugging the chosen edge INSIDE the icon, with a
    -- square arrow centered on it pointing the way the flyout will open. Frame
    -- level sits just above the icon so the border and the count/label overlay
    -- still draw on top; neither of those takes mouse input, so they don't block
    -- the band's hover.
    local point, relPoint, dx, dy, rotation, w, h, glyph = BL.IndicatorAnchor(cfg)
    local ind = button.indicator
    ind:ClearAllPoints()
    ind:SetPoint(point, button, relPoint, dx, dy)
    ind:SetSize(w, h)
    ind:SetFrameLevel(button:GetFrameLevel() + 1)
    local shade = cfg.flyoutShadeColor or {}
    ind.shade:SetColorTexture(shade[1] or 0, shade[2] or 0, shade[3] or 0, shade[4] or 0.55)
    ind.arrow:SetSize(glyph, glyph)
    ind.arrow:SetRotation(rotation)
    ind:Show()

    local ids = FO.Candidates(button.catKey, cfg)
    local grid = BL.Flyout(#ids, cfg)

    flyout:ClearAllPoints()
    flyout:SetPoint(grid.point, button, grid.relPoint, 0, 0)
    flyout:SetSize(grid.width, grid.height)
    flyout:SetFrameStrata("DIALOG")     -- above the bar, and above other bars
    FO.ApplyBackdrop(flyout, cfg)

    for i, id in ipairs(ids) do
        local entry = flyout.entries[i]
        if not entry then
            entry = createEntry(flyout, i)
            flyout.entries[i] = entry
        end
        bindEntry(entry, id, cfg, grid.size)
        entry:ClearAllPoints()
        entry:SetPoint(grid.point, flyout, grid.point,
            grid.positions[i].x, grid.positions[i].y)
        entry:Show()
    end
    for i = #ids + 1, #flyout.entries do
        flyout.entries[i]:Hide()
    end

    -- The snippet reads these: kcmEntries to avoid opening an empty flyout, and
    -- kcmGrace to know whether leaving should close now or start the countdown.
    flyout:SetAttribute("kcmEntries", #ids)
    button.indicator:SetAttribute("kcmEntries", #ids)
    flyout:SetAttribute("kcmGrace", tonumber(cfg.flyoutAutoClose) or 0)
    if #ids == 0 then
        flyout:Hide()
        button.indicator:Hide()      -- nothing to show, so no arrow to tease with
    end
    return true
end

-- Ordered, capped candidate list for a slot. Order comes from the category's own
-- ranking (top-ranked first, i.e. closest to the button) and `flyoutInvert`
-- reverses it. Truncation is logged rather than silent.
function FO.Candidates(catKey, cfg)
    if not (KCM.Selector and KCM.Selector.ListAvailable) then return {} end
    local ids = KCM.Selector.ListAvailable(catKey, nil, nil) or {}
    local cap = math.min(FO.MAX_ENTRIES, math.max(1, tonumber(cfg.flyoutMax) or 12))
    if #ids > cap then
        if KCM.Debug and KCM.Debug.IsOn and KCM.Debug.IsOn() then
            KCM.Debug("Bar", "%s flyout capped at %s of %s available", catKey, cap, #ids)
        end
        local trimmed = {}
        for i = 1, cap do trimmed[i] = ids[i] end
        ids = trimmed
    end
    if cfg.flyoutInvert then
        local reversed = {}
        for i = #ids, 1, -1 do reversed[#reversed + 1] = ids[i] end
        ids = reversed
    end
    return ids
end

-- Repaint every entry's cooldown. Unprotected, so this is safe in combat — which
-- matters, since a potion's cooldown starting mid-fight is the common case.
function FO.RefreshCooldowns(button)
    local flyout = button and button.flyout
    if not flyout then return end
    for _, entry in ipairs(flyout.entries) do
        if entry:IsShown() then FO.RefreshCooldown(entry) end
    end
end
