-- modules/MacroBar.lua — the CM-only macro bar.
--
-- A movable container holding one SecureActionButtonTemplate slot per managed
-- category (modules/MacroBarButton.lua), each with an optional hover flyout
-- (modules/MacroBarFlyout.lua). On and unlocked by default; everything about it
-- lives in db.profile.macroBar and is edited from the Macro Bar settings tab,
-- `/cm bar`, or `/cm set macroBar.*`.
--
-- Combat contract (the reason this file is structured the way it is):
--   * Creating slots, anchoring them, and showing/hiding them are all
--     protected-frame operations. Every one of them funnels through Update(),
--     which defers to PLAYER_REGEN_ENABLED when InCombatLockdown() is true
--     (KCM:OnRegenEnabled -> FlushPending), so no addon code ever pokes a
--     protected frame mid-fight.
--   * Combat-conditional visibility is NOT done with Show/Hide for that exact
--     reason — it is handed to RegisterStateDriver, so Blizzard's secure
--     environment performs the toggle and the bar can appear/disappear mid-
--     fight with no taint.
--   * The hover fade uses SetAlpha, which is unprotected and safe in combat.
--     Faded slots stay clickable; that is intentional.
--
-- Slot -> category binding is fixed at creation, so nothing here ever writes a
-- secure attribute after the fact. Reordering only moves anchors.

local _, NS = ...
local KCM = NS
KCM.MacroBar = KCM.MacroBar or {}
local MB = KCM.MacroBar

-- The perf probe, a LOAD-TIME upvalue rather than a KCM lookup inside the
-- bracket (performance-§2). core/PerfSetup.lua sits near the top of the TOC's
-- # Core section, far ahead of this file. Nil-tolerant for the same reason it is
-- in core/ConsumableMaster.lua: a build without the vendored library publishes
-- no harness at all, and the bar must not care.
local Perf = KCM.Perf

local BAR_NAME       = "KCMMacroBar"
local FADE_THROTTLE  = 0.1    -- seconds between mouse-over polls in fade mode
local BACKDROP_TEX   = [[Interface\Buttons\WHITE8X8]]
local HANDLE_H       = 18     -- unlocked drag-handle strip height
local HANDLE_GAP     = 2      -- gap between the handle and the bar's top edge
local HANDLE_PAD     = 24     -- horizontal padding around the handle's label
local HANDLE_HELP    = 14     -- help-icon edge, inside the handle's right end
local HELP_TEXTURE   = [[Interface\FriendsFrame\InformationIcon]]

local bar                     -- container frame, nil until first build
local buttons = {}            -- catKey -> button frame
local pendingUpdate = false   -- an Update() was requested during combat

local function cfg()
    return KCM.MacroBarModel and KCM.MacroBarModel.Config() or nil
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

local function color(t, dr, dg, db, da)
    t = t or {}
    return t[1] or dr, t[2] or dg, t[3] or db, t[4] or da
end

-- ---------------------------------------------------------------------------
-- Container
-- ---------------------------------------------------------------------------

local function savePosition()
    if not bar then return end
    local c = cfg()
    if not c then return end
    local point, _, relPoint, x, y = bar:GetPoint(1)
    if not point then return end
    c.point, c.relPoint, c.x, c.y = point, relPoint, x, y
end

local function applyPosition()
    if not bar then return end
    local c = cfg() or {}
    bar:ClearAllPoints()
    bar:SetPoint(c.point or "CENTER", UIParent, c.relPoint or "CENTER",
        tonumber(c.x) or 0, tonumber(c.y) or 0)
end

-- Poll-based hover detection. IsMouseOver() works regardless of whether the
-- frame itself is mouse-enabled, so it reports hover over the slots too — which
-- an OnEnter/OnLeave pair on the container alone would not.
local function fadeTick(self, elapsed)
    self._fadeAccum = (self._fadeAccum or 0) + elapsed
    if self._fadeAccum < FADE_THROTTLE then return end
    self._fadeAccum = 0
    local c = cfg()
    if not c then return end
    local target = self:IsMouseOver() and (tonumber(c.alpha) or 1)
        or (tonumber(c.fadeAlpha) or 0.15)
    if self:GetAlpha() ~= target then self:SetAlpha(target) end
end

local function buildBar()
    local frame = CreateFrame("Frame", BAR_NAME, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local c = cfg()
        if not c or c.locked then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)

    -- Unlocked hint: a translucent gold wash over the whole bar so it is
    -- obvious which frame is grabbable.
    frame.moveHint = frame:CreateTexture(nil, "OVERLAY")
    frame.moveHint:SetAllPoints(frame)
    frame.moveHint:SetColorTexture(1, 0.82, 0, 0.15)
    frame.moveHint:Hide()

    -- Drag handle. A labeled strip centered above the bar, shown only while
    -- unlocked. It exists because a full bar leaves no bare container to grab —
    -- every pixel inside is a button, and a button swallows the drag to run
    -- PickupMacro. The handle is a sibling grab point with no such conflict.
    local handle = CreateFrame("Button", BAR_NAME .. "Handle", frame, "BackdropTemplate")
    handle:SetPoint("BOTTOM", frame, "TOP", 0, HANDLE_GAP)
    handle:SetHeight(HANDLE_H)
    handle:SetBackdrop({
        bgFile   = BACKDROP_TEX,
        edgeFile = BACKDROP_TEX,
        edgeSize = 1,
    })
    handle:SetBackdropColor(0, 0, 0, 0.75)
    handle:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() frame:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
    handle:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(KCM.L["Consumable Master"], 1, 0.82, 0)
        GameTooltip:AddLine(KCM.L["Drag to move the bar."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    handle.text:SetPoint("CENTER")
    handle.text:SetText(KCM.L["Consumable Master"])
    handle.text:SetTextColor(1, 0.82, 0)

    -- Help icon rather than a second line of hint text. The bar can be one
    -- button wide, so any prose long enough to explain both drag gestures would
    -- either clip or force the handle wider than the bar it belongs to; a fixed
    -- 14px icon costs the same at every width.
    local help = CreateFrame("Button", nil, handle)
    help:SetSize(HANDLE_HELP, HANDLE_HELP)
    help:SetPoint("RIGHT", handle, "RIGHT", -4, 0)
    help.icon = help:CreateTexture(nil, "OVERLAY")
    help.icon:SetAllPoints(help)
    help.icon:SetTexture(HELP_TEXTURE)
    help:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(KCM.L["Macro bar"], 1, 0.82, 0)
        GameTooltip:AddLine(KCM.L["Drag this handle to move the bar."], 1, 1, 1, true)
        GameTooltip:AddLine(KCM.L["Drag a button onto another to swap them."], 1, 1, 1, true)
        GameTooltip:AddLine(KCM.L["Drag a button off the bar to put its macro on an action bar."], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(KCM.L["Only Consumable Master macros can sit on this bar."], 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(KCM.L["Lock the bar to hide this handle — /cm bar lock."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    help:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    handle.help = help

    frame.handle = handle

    return frame
end

-- ---------------------------------------------------------------------------
-- Apply passes. Each is safe to call repeatedly; none of them may run in
-- combat except ApplyAlpha (see the combat contract at the top).
-- ---------------------------------------------------------------------------

local function applyBackdrop()
    if not (bar and bar.SetBackdrop) then return end
    local c = cfg() or {}
    if c.barBackdrop == false and c.barBorder == false then
        bar:SetBackdrop(nil)
        return
    end
    -- Border style comes from LibSharedMedia (same picker the buttons use), so
    -- the bar frame and its slots can be given a matching edge.
    local edgeFile
    if c.barBorder ~= false then
        edgeFile = KCM.MacroBarButton and KCM.MacroBarButton.BorderTexture
            and KCM.MacroBarButton.BorderTexture(c.barBorderStyle) or BACKDROP_TEX
    end
    bar:SetBackdrop({
        bgFile   = c.barBackdrop ~= false and BACKDROP_TEX or nil,
        edgeFile = edgeFile,
        edgeSize = math.max(1, tonumber(c.barBorderSize) or 4),
    })
    if c.barBackdrop ~= false then
        bar:SetBackdropColor(color(c.barBackdropColor, 0, 0, 0, 0.5))
    end
    if c.barBorder ~= false then
        bar:SetBackdropBorderColor(color(c.barBorderColor, 0.25, 0.25, 0.25, 1))
    end
end

local function applyAlpha()
    if not bar then return end
    local c = cfg() or {}
    if c.fadeUnlessHover then
        bar:SetScript("OnUpdate", fadeTick)
        bar:SetAlpha(bar:IsMouseOver() and (tonumber(c.alpha) or 1)
            or (tonumber(c.fadeAlpha) or 0.15))
    else
        bar:SetScript("OnUpdate", nil)
        bar:SetAlpha(tonumber(c.alpha) or 1)
    end
end

local function applyLock()
    if not bar then return end
    local c = cfg() or {}
    local unlocked = not c.locked
    bar:EnableMouse(unlocked)
    if unlocked then bar.moveHint:Show() else bar.moveHint:Hide() end
    -- Handle is at least as wide as its own label, and never narrower than the
    -- bar, so a one-button bar still gets a grabbable strip.
    local handle = bar.handle
    if handle then
        -- Label + padding + the help icon's own footprint, so a narrow bar's
        -- handle never crowds the two together.
        local textW = (handle.text:GetStringWidth() or 0) + HANDLE_PAD + HANDLE_HELP * 2
        handle:SetWidth(math.max(textW, bar:GetWidth() or textW))
        handle:SetShown(unlocked)
    end
end

-- Secure visibility driver. ALWAYS clears the driver entirely so a plain
-- Show()/Hide() governs; the two combat modes hand the toggle to Blizzard's
-- secure state manager so it also works mid-fight.
local function applyVisibility()
    if not bar then return end
    local c = cfg() or {}
    if UnregisterStateDriver then UnregisterStateDriver(bar, "visibility") end
    if not c.enabled then
        bar:Hide()
        return
    end
    local mode = c.combatMode
    if mode == "HIDE_IN_COMBAT" and RegisterStateDriver then
        RegisterStateDriver(bar, "visibility", "[combat] hide; show")
    elseif mode == "ONLY_IN_COMBAT" and RegisterStateDriver then
        RegisterStateDriver(bar, "visibility", "[combat] show; hide")
    else
        bar:Show()
    end
end

local function applyLayout()
    if not bar then return end
    local c = cfg() or {}
    local visible = KCM.MacroBarModel.Visible()
    local grid = KCM.MacroBarLayout.Grid(#visible, c)

    bar:SetScale(tonumber(c.scale) or 1)
    bar:SetSize(grid.width, grid.height)

    for _, btn in pairs(buttons) do btn:Hide() end
    for i, key in ipairs(visible) do
        local btn = buttons[key]
        local pos = grid.positions[i]
        if btn and pos then
            KCM.MacroBarButton.ApplyStyle(btn, c)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", bar, "TOPLEFT", pos.x, pos.y)
            btn:Show()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public surface
-- ---------------------------------------------------------------------------

function MB.Refresh()
    if not bar then return end
    local c = cfg() or {}
    -- Icons and counts are unprotected, so they track the macro rewrite even
    -- mid-fight. Flyout CONTENT can't: binding an entry writes a secure
    -- attribute. Queue it for regen instead, which is why a flyout's entries are
    -- frozen for the duration of a fight (see modules/MacroBarFlyout.lua).
    local combat = inCombat()
    for _, btn in pairs(buttons) do
        KCM.MacroBarButton.Refresh(btn)
        -- Hidden slots (macros toggled off the bar) have nothing to show, so
        -- skip the candidate walk for them entirely.
        if not combat and KCM.MacroBarFlyout and btn:IsShown() then
            KCM.MacroBarFlyout.Apply(btn, c)
        end
    end
    if combat and c.flyout then pendingUpdate = true end
end

-- The one path that runs at near-frame frequency in combat: SPELL_UPDATE_COOLDOWN
-- and BAG_UPDATE_COOLDOWN both land here, and each one walks every bar button
-- plus every shown flyout row. That makes it the bucket worth attributing when a
-- perf capture shows a delta.
--
-- The gate is an upvalue read, a nil test and a field read when no capture is
-- running — no table lookup through KCM at all — and it MUST be a gate:
-- Note() records unconditionally, so an ungated bracket would accumulate outside
-- any window and poison the next report.
function MB.RefreshCooldowns()
    if not bar then return end
    local t0 = (Perf and Perf.on) and debugprofilestop() or nil
    for _, btn in pairs(buttons) do
        KCM.MacroBarButton.RefreshCooldown(btn)
        -- Flyout cooldowns too: a potion's cooldown starting mid-fight is the
        -- common case, and repainting a Cooldown frame is unprotected.
        if KCM.MacroBarFlyout then KCM.MacroBarFlyout.RefreshCooldowns(btn) end
    end
    if t0 then Perf.Note("cooldown", debugprofilestop() - t0) end
end

-- Build (once) the container and every slot. Slots are created for ALL
-- categories, not just the visible ones, so toggling a macro on later is a
-- Show() rather than a mid-session secure-frame creation.
local function ensure()
    if not bar then
        bar = buildBar()
        applyPosition()
    end
    -- Frame names are keyed by the slot's ORDER INDEX at creation time, which
    -- is stable enough to be unique (every category is created in one pass) and
    -- gives /framestack a readable name.
    for i, key in ipairs(KCM.MacroBarModel.Order()) do
        if not buttons[key] then
            local btn = KCM.MacroBarButton.Create(bar, key, i)
            if btn then buttons[key] = btn end
        end
    end
end

-- The single seam every caller uses after mutating db.profile.macroBar.
-- Deferred wholesale when in combat: the frame work below is protected.
function MB.Update()
    if not KCM.MacroBarModel then return false end
    local c = cfg()
    if not c then return false end
    -- One combat gate for the whole function, including the disable path: both
    -- Hide() and the anchoring below touch protected frames.
    if inCombat() then
        pendingUpdate = true
        return false
    end
    if not c.enabled then
        if bar then
            if UnregisterStateDriver then UnregisterStateDriver(bar, "visibility") end
            bar:Hide()
        end
        return true
    end
    ensure()
    applyPosition()
    applyBackdrop()
    applyLayout()
    applyLock()
    applyVisibility()
    applyAlpha()
    MB.Refresh()
    return true
end

-- Called from KCM:OnRegenEnabled alongside MacroManager.FlushPending.
function MB.FlushPending()
    if not pendingUpdate then return false end
    pendingUpdate = false
    return MB.Update()
end

-- ---------------------------------------------------------------------
-- The two Bar-section flags: one write path, two apply halves
-- ---------------------------------------------------------------------
--
-- CM-R-05. `macroBar.enabled` and `macroBar.locked` are schema rows like every
-- other `macroBar.*` field, and options-ui-§1 wants one write seam per setting.
-- These two used to have two: the page's checkbox went through
-- Helpers.SetAndRefresh, while `/cm bar on|off|lock|unlock` assigned
-- `c.enabled` / `c.locked` here directly. The consequences were both real —
-- `/cm bar lock` with the Macro Bar page open left the checkbox showing the old
-- state until the page was rebuilt, and `macroBar.locked` had no `onChange`, so
-- `/cm set macroBar.locked true` wrote the flag and never applied it.
--
-- Now: `MB.Apply*` are apply-only and are what settings/MacroBar.lua's two rows
-- name as their `onChange`. `MB.Set*` are write-then-apply and route through
-- the schema seam, so validation, the onChange and the panel's in-place
-- re-sync all happen exactly once no matter who called.

-- Apply-only. The value is already in the profile; make the screen agree.
function MB.ApplyEnabled()
    local c = cfg()
    if not c then return false end
    local applied = MB.Update()
    if not applied and inCombat() then
        KCM.Say("in combat — the macro bar will %s when combat ends.",
            c.enabled and "appear" or "hide")
    end
    return true
end

-- Apply-only. EnableMouse and a texture toggle on the (unprotected) container
-- are safe mid-combat; only anchoring and visibility have to wait for regen.
function MB.ApplyLock()
    if not bar then return true end
    applyLock()
    return true
end

-- THE write path for both flags. Schema:Set is the published unified setter
-- (architecture-§5); it validates, writes through Helpers.Set, fires the row's
-- onChange — which is the matching MB.Apply* above — and re-syncs the open
-- page's widget in place.
local function writeFlag(field, value)
    if not cfg() then return false end
    local setter = KCM.Schema
    if not (setter and setter.Set) then return false end
    return setter:Set("macroBar." .. field, value and true or false) and true or false
end

function MB.SetEnabled(on)     return writeFlag("enabled", on) end
function MB.SetLocked(locked)  return writeFlag("locked", locked) end

function MB.ResetPosition()
    local c = cfg()
    if not c then return false end
    local d = KCM.dbDefaults and KCM.dbDefaults.profile and KCM.dbDefaults.profile.macroBar or {}
    c.point, c.relPoint, c.x, c.y = d.point or "CENTER", d.relPoint or "CENTER", d.x or 0, d.y or 0
    if not bar then return true end
    if inCombat() then
        pendingUpdate = true      -- re-anchoring moves protected children
    else
        applyPosition()
    end
    return true
end

-- Drag-drop reorder entry point (modules/MacroBarButton.lua). Blocked in
-- combat because the relayout that follows anchors protected frames.
function MB.SwapSlots(fromKey, toKey)
    local c = cfg()
    if not c then return false end
    if inCombat() then
        KCM.Say("in combat — macro bar reorder is blocked until combat ends.")
        return false
    end
    local order = KCM.MacroBarModel.Order()
    if not KCM.MacroBarModel.Swap(order, fromKey, toKey) then return false end
    c.order = order
    applyLayout()
    if KCM.Options and KCM.Options.RequestRefresh then KCM.Options.RequestRefresh() end
    return true
end

-- ---------------------------------------------------------------------------
-- Bus receiver (architecture-§4). The bar owns the sole MACROBAR_REFRESH
-- subscription, on its own target — the pipeline publishes it after every
-- recompute so icons and counts track the freshly-written macro bodies.
-- ---------------------------------------------------------------------------
if KCM.NewBusTarget and KCM.MSG and KCM.MSG.MACROBAR_REFRESH then
    local target = KCM.NewBusTarget()
    KCM._macroBarBusTarget = target
    target:RegisterMessage(KCM.MSG.MACROBAR_REFRESH, function()
        if KCM.MacroBarModel and KCM.MacroBarModel.IsEnabled() then MB.Refresh() end
    end)
end
