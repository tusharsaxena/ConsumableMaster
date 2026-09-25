-- settings/OptionsShim.lua — the KCM.Options runtime surface.
--
-- What this file owns: the four functions the rest of the addon knows the
-- settings layer by — O.Refresh, O.RequestRefresh, O.Open — the trailing-edge
-- debounce that stands behind RequestRefresh, and the three bus subscriptions
-- that drive them. Nothing here declares a schema row, builds a widget or
-- registers a Blizzard category; that is settings/Panel.lua's, which loads
-- immediately before this file and still publishes KCM.Options.Register.
--
-- WHY IT IS ITS OWN FILE. It was the closing block of settings/Panel.lua until
-- 2026-09-16, when that file stood at 1488 lines against layout-§1's 1500-line
-- cap — twelve lines of headroom, so the next ordinary edit would have breached
-- it, and the watch list in docs/automated-tests/RESULTS.md had carried the file
-- as Accepted across three consecutive releases, which automated-tests-§4
-- refuses a fourth time. The seam is the one the file's own section heading
-- already drew: the schema and chrome half a page module calls at BUILD time,
-- against the shim the addon calls at RUN time. Every line below moved WHOLE —
-- not a comparison, a constant or a comment changed in the cut.
--
-- The two things it reads back from settings/Panel.lua rather than deciding
-- for itself:
--   * `libAbsent`, derived here the same way Panel.lua derives it — from the
--     instance, not from a second flag, so "the library answered" and "the panel
--     can be built" cannot disagree.
--   * `sayPanelUnavailable`, which holds a said-once flag. A second copy of that
--     function would be a second flag, and the degraded install would then get
--     the notice twice; tests/test_settingsui.lua counts it and expects one.
-- The combat refusal on open is not one of them: it is LibKa0s-Options-1.0's
-- OpenOptionsPanel, in the library's words (options-ui-§2).

local _, NS = ...
local KCM = NS

local Helpers = KCM.Settings.Helpers

KCM.Options = KCM.Options or {}
local O = KCM.Options

-- Same derivation as settings/Panel.lua's, off the instance settings/
-- OptionsSetup.lua published: with LibKa0s absent no panel was registered, so
-- O.Open has nothing to open and says so.
local UI = KCM.Settings.optionsUI
local libAbsent = not UI

-- Panel.lua's notice — see the file header above for why it is borrowed
-- rather than copied.
local sayPanelUnavailable = KCM.Settings.SayPanelUnavailable

-- ---------------------------------------------------------------------
-- KCM.Options shim — preserves the public API used by Core / Debug /
-- SlashCommands / Pipeline. Internals route through the new framework.
-- ---------------------------------------------------------------------

function O.Refresh()
    O._refreshPending = false
    Helpers.RefreshAllPanels()
end

-- Trailing-edge debounced refresh. Pipeline.Recompute fires this on every
-- recompute, which during a GET_ITEM_INFO_RECEIVED storm at first panel
-- open lands dozens of calls in quick succession. Debounce so the panel
-- rebuilds once at the tail of the burst, with a cap so the user always
-- sees the latest state within REFRESH_MAX_WAIT_SEC even if events never
-- fully stop.
--
-- ONE TIMER PER BURST, not one per call. The earlier shape scheduled a fresh
-- C_Timer.After with a fresh closure on every call and had all but the last
-- return immediately on a token compare, so the ~150-item first-open burst
-- (docs/data-flow.md's GIIR split) armed 150 timers and 150 closures to
-- perform one rebuild. tests/perf.lua's `refreshBurst` scenario measures it;
-- the count is the assertion there, and it went 150 -> 1.
--
-- The token is gone because the single armed timer is now what identifies the
-- live schedule: `_refreshArmed` is the whole of the mutual exclusion, and a
-- call that finds it set records its timestamp and returns. onRefreshDue then
-- does the work the discarded timers used to do — it wakes at the earliest
-- moment the burst COULD be over, finds it is not, and re-arms for the
-- remaining quiet time rather than being replaced by a successor.
--
-- REFRESH_MAX_WAIT_SEC is now a hard cap, which it was not. The old delay
-- arithmetic shrank the window as the burst aged but every arriving call still
-- invalidated the pending timer, so a storm whose calls landed closer together
-- than the 0.05s floor deferred the rebuild indefinitely — the cap bounded the
-- delay of one timer, never the wait as a whole. onRefreshDue refreshes
-- outright once REFRESH_MAX_WAIT_SEC has elapsed since the first call,
-- whatever the traffic, and armRefresh never schedules past that instant.
local REFRESH_DEBOUNCE_SEC = 1.0
local REFRESH_MAX_WAIT_SEC = 3.0

-- Forward-declared: onRefreshDue re-arms through it, and it schedules
-- onRefreshDue. One of the two has to be named before it exists.
local armRefresh

-- Held while the Macros page's Add-by-ID box is in use
-- (settings/CategoryAddByID.lua's O.AddByIDBusy: it has the keys or holds text). This path's rebuilds are the
-- GET_ITEM_INFO_RECEIVED swaps of "?" for a name and the pipeline's repaints;
-- the line's own pre-warm and name lookup produce exactly those events, and a
-- rebuild releases the box, dropping a pending lookup and the typed text with
-- no word on the status line. So the request waits, asking again a quiet
-- second later as a fresh window (the cap restarts, or it would poll at the
-- 0.05s floor), and lands once the box is idle. A stalled timer is not held:
-- nothing could ever observe the box going idle through it.
local function heldByEntry(now)
    if not (O.AddByIDBusy and O.AddByIDBusy()) then return false end
    O._refreshFirstAt, O._refreshLastAt = now, now
    armRefresh(now, REFRESH_DEBOUNCE_SEC)
    return true
end

-- The one scheduled callback, hoisted to file scope so it is constructed once
-- at load rather than once per call: the old shape built one of these per
-- request and discarded 149 of every 150. Its state lives on O, where the
-- previous shape kept it too, so nothing here is per-schedule.
local function onRefreshDue()
    local armedAt, armedFor = O._refreshArmedAt, O._refreshArmedFor
    O._refreshArmed, O._refreshArmedAt, O._refreshArmedFor = nil, nil, nil
    if not O._refreshPending then
        O._refreshFirstAt, O._refreshLastAt = nil, nil
        return
    end

    local now    = GetTime()
    local waited = now - (O._refreshFirstAt or now)
    local quiet  = now - (O._refreshLastAt or now)

    -- A timer that came back EARLY has not scheduled anything, and re-arming
    -- against one recurses: each level asks for another window, gets it back
    -- for free, and the only exits are a quiet second or the cap, neither of
    -- which a clock that is not moving can ever reach. The stack goes first.
    --
    -- A live client cannot produce it. C_Timer.After lands on a LATER frame and
    -- GetTime() is the frame clock, so a wake-up arrives a whole frame past the
    -- delay even when the delay is zero. tests/wow_mock.lua's C_Timer.After runs
    -- its callback INLINE, which is exactly a timer that ignored its delay, and
    -- the guard belongs here rather than in the mock: a re-arm loop whose only
    -- exit is a clock nobody in this function controls is worth refusing at the
    -- source, and the condition is a property of the schedule rather than of the
    -- harness. Refreshing is the honest answer when no quiet period can be
    -- observed — the caller asked for a rebuild and gets one.
    --
    -- HALF the delay, not the whole of it, because the arithmetic does not
    -- round-trip: a timer armed at 0.001 for 1.0 and woken at exactly 1.001
    -- computes an elapsed 0.9999999999999999 in doubles, so a `< armedFor`
    -- compare calls a punctual timer early. That is not hypothetical — it is
    -- what this line did on its first run, and it turned the burst case red.
    -- Half is clear of any rounding and still nowhere near a scheduler that ran
    -- at all: the thing it must catch returns in zero time, not in 0.4 seconds.
    local stalled = armedAt ~= nil and armedFor ~= nil
        and (now - armedAt) < armedFor * 0.5

    if not stalled and quiet < REFRESH_DEBOUNCE_SEC and waited < REFRESH_MAX_WAIT_SEC then
        armRefresh(now, REFRESH_DEBOUNCE_SEC - quiet)
        return
    end

    if not stalled and heldByEntry(now) then return end

    O._refreshFirstAt, O._refreshLastAt = nil, nil
    O.Refresh()
end

-- `want` is the quiet the caller would like; what gets scheduled is whatever
-- fits before the cap, floored at 0.05s so a burst that arrives at the cap
-- still wakes rather than scheduling a zero-delay timer. What was ASKED for is
-- recorded alongside the instant, because onRefreshDue can only tell a real
-- wake-up from a timer that ignored its delay by comparing the two.
armRefresh = function(now, want)
    local room = REFRESH_MAX_WAIT_SEC - (now - (O._refreshFirstAt or now))
    if want > room then want = math.max(0.05, room) end
    O._refreshArmed, O._refreshArmedAt, O._refreshArmedFor = true, now, want
    C_Timer.After(want, onRefreshDue)
end

function O.RequestRefresh()
    local now = GetTime()
    if not O._refreshFirstAt then O._refreshFirstAt = now end
    O._refreshLastAt  = now
    O._refreshPending = true
    if O._refreshArmed then return end
    armRefresh(now, REFRESH_DEBOUNCE_SEC)
end

-- The open is LibKa0s-Options-1.0's OpenOptionsPanel: it refuses in combat and
-- prints its own COMBAT_REFUSED line (options-ui-§2), opens the category the
-- library registered, and expands the parent in the AddOns tree so every
-- sub-page is one click away. It answers true when it opened, false when it
-- refused in combat, and nil when there is no category to open yet (none
-- registered, one still parked for the end of combat, or no
-- Settings.OpenToCategory on this client).
function O.Open()
    -- There is no panel to open on a degraded install. Answering false is the
    -- contract core/SlashCommands.lua already branches on, so `/cm config`
    -- explains itself instead of silently doing nothing.
    if libAbsent then
        sayPanelUnavailable()
        return false
    end
    local opened = UI.OpenOptionsPanel()
    if opened then return true end
    -- false: refused in combat, and the library has already said so.
    if opened == false then return false end
    KCM.Say("settings panel unavailable on this client; use /cm help.")
    return false
end

-- ---------------------------------------------------------------------
-- Bus receivers (architecture-§4). The options layer owns the sole
-- options-layer subscriptions to PANEL_REFRESH (debounced rebuild of any open
-- page), PROFILE_CHANGED (an immediate one) and SPEC_CHANGED (retrack the Stat
-- Priority page to the new spec when the page is auto-tracking). Three
-- different messages on one target, so none can clobber another.
--
-- PROFILE_CHANGED is NOT left to the debounced PANEL_REFRESH the resync also
-- publishes. A page drawn from the outgoing profile holds controls that read and
-- write it -- a table a switch has just swapped out -- so for the second or more
-- the debounce waits, a click on one would write the wrong profile. The rebuild
-- is structural and scoped to the page on screen (every other one is marked
-- dirty), so it costs one page, once (options-ui-§11).
-- ---------------------------------------------------------------------
--
-- THE THREE SIT ON A TRACKED BUS TARGET (core/Bus.lua, LibKa0s-Bus-1.0), because
-- the stand-down has to be able to drop them and put them back.
-- The PANEL and its category registration SURVIVE the disabled state -- they are
-- setup, not features (slash-commands-§7) -- but these three registrations are
-- not the panel: they are the pipeline's route into it, and the pipeline is what
-- stands down. Every one of their publishers (PANEL_REFRESH, PROFILE_CHANGED's
-- resync, SPEC_CHANGED) is a stood-down path, so keeping them registered would
-- leave three live subscriptions listening for messages that can no longer be
-- sent. A player's own write through the panel does not go near them: Helpers.
-- SetAndRefresh re-syncs the widgets directly.
if KCM.NewBusTarget and KCM.MSG then
    KCM._optionsBusTarget = KCM.NewBusTarget(function(optionsTarget)
        optionsTarget:RegisterMessage(KCM.MSG.PANEL_REFRESH, function()
            if O.RequestRefresh then O.RequestRefresh()
            elseif O.Refresh then O.Refresh() end
        end)
        optionsTarget:RegisterMessage(KCM.MSG.PROFILE_CHANGED, function()
            if O.Refresh then O.Refresh() end
        end)
        optionsTarget:RegisterMessage(KCM.MSG.SPEC_CHANGED, function()
            if O._viewedSpecAuto and KCM.SpecHelper and KCM.SpecHelper.GetCurrent then
                local _, _, key = KCM.SpecHelper.GetCurrent()
                if key then O._viewedSpec = key end
            end
        end)
    end)
end
