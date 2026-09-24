-- tests/test_disabled.lua — the conformance suite slash-commands-§7 requires:
-- DISABLED MEANS THE ADDON IS NOT RUNNING.
--
-- WHAT THIS FILE ASSERTS ON, AND WHY IT IS NOT THE OBVIOUS THING.
--
-- Every assertion below reads the mock's REGISTRATION SET. None of them calls a
-- handler and checks that it returned early, and that is the whole reason the
-- file exists. Eleven addons in this collection shipped "disabled" as a DRAW
-- GATE — a stored boolean read as one rung of a show ladder, handlers that
-- early-return on it while every event they own is still registered — and from
-- outside that is indistinguishable from an addon that genuinely stood down. The
-- client still walks the registration list on every BAG_UPDATE_COOLDOWN, still
-- builds the argument frame, still enters Lua, still runs the comparison that
-- decides to leave. A suite written against an early return CANNOT tell the two
-- apart, because an early return is what a draw gate does: such a suite does not
-- catch the anti-pattern, it CERTIFIES it (anti-pattern #85, testing-§12).
--
-- THIS ADDON'S OWN VERSION OF THE BUG, for the record, because it is what these
-- cases were written against. Through 1.6.2 `db.profile.enabled` had exactly ONE
-- consumer in the entire addon: `macrosEnabled()` in core/ConsumableMaster.lua,
-- read once per recompute to skip the macro write pass. No bus message, no module
-- teardown, no visibility publish. Nine game events stayed registered, four bus
-- subscriptions stayed live, and `/cm disable` did not take the macro bar off the
-- screen at all — which is the form the owner reported it in.
--
-- WHAT THE MOCK CAN AND CANNOT SEE HERE. The kit's recording registry
-- (tests/_kit/mock_record.lua) is fed by the kit's AceEvent, which this addon
-- uses untouched, so every RegisterEvent and RegisterMessage the addon makes is
-- in `mock.base.__registrations()` and LEAVES it on the matching unregister.
-- FRAMES are this repo's own stub (tests/wow_mock.lua) rather than the kit's, so
-- the kit's `__shownFrames` cannot see them: the frame cases below instrument the
-- bar's own Show / Hide instead, which is the same question asked of the object
-- that would answer it in game.
--
-- `__fire` DISPATCHES AT THE LIVE SET ONLY, which is the honest half of the pair
-- and also a trap: over an empty registry it runs nothing, so "no write, no line"
-- would be true of a correctly stood-down addon AND of a harness that had lost
-- the ability to dispatch at all. `__fireUnconditional` is the falsification
-- half, and step 6 below uses both.

local h = _G.KCM_TEST
local test = h.test
local loader = h.loader
local mock = h.mock

local DISABLED, PERF = "disabled", "perf"

-- ---------------------------------------------------------------------------
-- Surveys
-- ---------------------------------------------------------------------------

--- Every live registration, as sorted `kind:name` strings.
---
--- Names rather than handles, because what a rebuild has to produce is the same
--- SET — the targets are new tables on the way back up only if something went
--- wrong, and comparing identities would make the case fail for the right answer.
local function registrations()
    local out = {}
    for _, r in ipairs(mock.base.__registrations()) do
        out[#out + 1] = r.kind .. ":" .. tostring(r.event) .. (r.unit and ("@" .. r.unit) or "")
    end
    table.sort(out)
    return out
end

local function count(list) return #list end

--- A stable, comparable dump of a stored tree, so "nothing was written" is a
--- string equality rather than a walk written twice.
local function dump(v, out)
    out = out or {}
    if type(v) ~= "table" then
        out[#out + 1] = tostring(v)
        return table.concat(out, "\1")
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
        out[#out + 1] = k .. "="
        dump(rawget(v, k) == nil and v[k] or v[k], out)
    end
    out[#out + 1] = "}"
    return table.concat(out, "\1")
end

local function storedState(KCM)
    return dump({ profile = KCM.db.profile, global = KCM.db.global })
end

--- Everything the addon has said to the player since the last reset.
local function printed()
    return table.concat(mock.output, "\n")
end

local function resetPrinted() mock.output = {} end

-- ---------------------------------------------------------------------------
-- The build
-- ---------------------------------------------------------------------------

--- The whole addon, enabled, with the macro bar ON and its frames captured.
---
--- The bar is switched on deliberately: it is the only thing this addon DRAWS,
--- so with it off the "every frame is hidden" step would pass over an addon that
--- never had a frame to hide.
local function build()
    local KCM = loader.loadFullAddon()
    local H = KCM.Settings.Helpers

    -- The recorder goes on BEFORE the row is written, not after: the row's own
    -- onChange builds the bar, so a wrapper installed afterwards would watch a
    -- second Update that has nothing left to create and hand back no frame.
    local frames = {}
    local realCreate = _G.CreateFrame
    _G.CreateFrame = function(kind, name, parent, template)
        local f = realCreate(kind, name, parent, template)
        if name then frames[name] = f end
        return f
    end
    H.SetAndRefresh("macroBar.enabled", true)
    KCM.MacroBar.Update()
    _G.CreateFrame = realCreate

    -- The lifecycle tests/run.lua already runs: AceAddon calls OnInitialize at
    -- load and OnEnable a moment later. loadFullAddon does the first; this is the
    -- second, and it is the call that puts the nine game events on.
    KCM:OnEnable()
    return KCM, H, frames
end

--- Instrument the bar so a Show or a Hide is a fact rather than a no-op. The
--- repo's frame stub swallows both by default (every capitalized method chains).
local function watchBar(frames)
    local seen = { shows = 0, hides = 0 }
    local bar = frames.KCMMacroBar
    if not bar then return seen end
    bar.Show = function() seen.shows = seen.shows + 1; seen.visible = true end
    bar.Hide = function() seen.hides = seen.hides + 1; seen.visible = false end
    return seen
end

-- ---------------------------------------------------------------------------
-- 1. Baseline
-- ---------------------------------------------------------------------------

test("Disabled 1: enabled, the addon registers a non-empty set", function(t)
    local KCM = build()
    local R_on = registrations()

    -- Without this the whole suite is unfalsifiable: an addon that registers
    -- nothing when it is ON passes every later assertion trivially.
    t.truthy(count(R_on) > 0, "the enabled addon is registered for something")

    local names = {}
    for _, r in ipairs(R_on) do names[r] = true end
    -- Every name KCM.EVENTS declares, derived from the list OnEnable walks, so a
    -- pair added there is checked here unasked. The count is pinned too, so a
    -- list that quietly shrinks is a failure here rather than a smaller set
    -- silently passing step 3.
    t.eq(#KCM.EVENTS, 9, "KCM.EVENTS declares the nine client events")
    for _, pair in ipairs(KCM.EVENTS) do
        local e = "event:" .. pair[1]
        t.truthy(names[e], e .. " is registered while enabled")
    end
    -- And the bus, which is the half a teardown built only on UnregisterAllEvents
    -- would leave behind.
    t.truthy(names["message:Ka0s_ConsumableMaster_Recompute"], "the pipeline is subscribed")
    t.truthy(names["message:Ka0s_ConsumableMaster_MacroBarRefresh"], "the macro bar is subscribed")
    t.truthy(KCM.Lifecycle, "and the latch exists")
    t.falsy(KCM.IsStoodDown(), "with no hold taken")
end)

-- ---------------------------------------------------------------------------
-- 3. The registration set is EMPTY
-- ---------------------------------------------------------------------------
--
-- red under: drop the `KCM:UnregisterAllEvents()` from standDown in
-- core/LifecycleSetup.lua, or drop the `KCM.Bus.StandDown()` beside it, or put
-- the old `macrosEnabled()` draw gate back and nothing else. Each of those leaves
-- a handler that early-returns, which is the shape this case exists to fail on.

test("Disabled 3: the registration set is EMPTY, by count and by name", function(t)
    local _, H = build()
    local R_on = registrations()

    -- THROUGH THE SINGLE WRITE SEAM, never by calling standDown directly: the
    -- test has to exercise the route the checkbox and `/cm disable` take.
    H.SetAndRefresh("enabled", false)

    local R_off = registrations()
    t.eq(count(R_off), 0,
        "nothing the addon registered is still registered (was " .. count(R_on)
        .. ", left " .. table.concat(R_off, ", ") .. ")")
end)

test("Disabled 3b: /cm disable takes the same route as the checkbox", function(t)
    local KCM, H = build()
    KCM:OnSlashCommand("disable")
    t.eq(H.Get("enabled"), false, "the verb wrote the same stored path")
    t.eq(count(registrations()), 0, "and the addon stood down for it")
end)

-- ---------------------------------------------------------------------------
-- 4. Nothing is still going to wake up
-- ---------------------------------------------------------------------------

--- Every frame the mock still holds a `kcmCombat` attribute driver on, as a
--- set. These are the flyout containers: modules/MacroBarFlyout.lua registers
--- one per slot so its secure snippets can read combat state, and the secure
--- driver manager keeps evaluating it for as long as it is registered.
local function combatDriverFrames()
    local out, n = {}, 0
    for frame, attrs in pairs(mock.attributeDrivers) do
        if attrs.kcmCombat ~= nil then
            out[frame] = attrs.kcmCombat
            n = n + 1
        end
    end
    return out, n
end

test("Disabled 4: no OnUpdate and no state driver is left armed", function(t)
    local _, H, frames = build()
    -- The fade tick is this addon's OnUpdate, and it only exists while the bar
    -- fades — arm it, or the assertion below passes over a script that was never
    -- set.
    H.SetAndRefresh("macroBar.fadeUnlessHover", true)
    local bar = frames.KCMMacroBar
    t.truthy(bar, "the bar frame was built")
    t.truthy(bar:GetScript("OnUpdate") ~= nil, "and its fade tick is armed while enabled")
    -- A non-empty baseline, or the "none left" assertion below passes over a
    -- bar whose flyouts were never built.
    local armed, n_on = combatDriverFrames()
    t.truthy(n_on > 0, "the flyouts' kcmCombat attribute drivers are armed while enabled")
    for _, value in pairs(armed) do
        t.eq(value, "[combat] 1; 0", "each flyout driver carries the combat conditional")
    end

    H.SetAndRefresh("enabled", false)

    t.eq(bar:GetScript("OnUpdate"), nil, "the fade tick is cleared, not left to find a hidden bar")
    local drivers = mock.stateDrivers[bar]
    t.falsy(drivers and drivers.visibility, "the secure visibility driver is unregistered")
    -- red under: drop FO.StandDown from MB.Update's disable branch
    local _, n_off = combatDriverFrames()
    t.eq(n_off, 0, "no flyout attribute driver is left registered (was " .. n_on .. ")")
end)

-- ---------------------------------------------------------------------------
-- 5. Every frame is hidden, AT THE SOURCE
-- ---------------------------------------------------------------------------

test("Disabled 5: the bar is hidden, and its show ladder answers no", function(t)
    local KCM, H, frames = build()
    local seen = watchBar(frames)
    H.SetAndRefresh("enabled", false)

    t.truthy(seen.hides > 0, "the bar was hidden")
    t.falsy(seen.visible, "and not shown again on the way")
    -- AT THE SOURCE (performance-§6). An imperative hide lasts until the next
    -- combat transition, target swap or settings change re-shows the bar behind
    -- the switch's back, so what is pinned is the LADDER's answer.
    t.falsy(KCM.MacroBarModel.IsEnabled(), "the show ladder itself answers no")
    -- A repaint asked for while disabled must not put it back.
    seen.shows = 0
    KCM.MacroBar.Update()
    t.eq(seen.shows, 0, "and a later Update does not re-show it")
end)

-- ---------------------------------------------------------------------------
-- 6. Fire every event anyway: nothing writes, nothing prints, nothing shows
-- ---------------------------------------------------------------------------
--
-- red under: any survivor at all. Put one RegisterEvent back — the cooldown pair
-- is the cheapest to forget, since it is the only path that runs at near-frame
-- frequency mid-fight — and the repaint it drives makes this case fail.

test("Disabled 6: firing every event it used to watch reaches nothing", function(t)
    local KCM, H, frames = build()
    local R_on = mock.base.__registrations()
    local events = {}
    for _, r in ipairs(R_on) do
        if r.kind == "event" then events[#events + 1] = r.event end
    end
    t.truthy(#events >= 9, "there are events to fire")

    local seen = watchBar(frames)
    H.SetAndRefresh("enabled", false)
    local before = storedState(KCM)
    resetPrinted()
    seen.shows = 0

    local ran = 0
    for _, e in ipairs(events) do ran = ran + (mock.base.__fire(e) or 0) end
    -- Combat entry by name, which is the event one addon in the collection writes
    -- `locked = true` and prints a chat line on while disabled.
    ran = ran + (mock.base.__fire("PLAYER_REGEN_DISABLED") or 0)
    mock.__fireTimers = mock.__fireTimers or mock.base.__fireTimers
    mock.base.__fireTimers()

    t.eq(ran, 0, "no handler ran")
    t.eq(storedState(KCM), before, "no SavedVariables write originated from a game event")
    t.eq(printed(), "", "nothing was said to the player")
    t.eq(seen.shows, 0, "and nothing was shown")
end)

test("Disabled 6b: the harness WOULD have caught a survivor", function(t)
    -- The falsification half. `__fire` over an empty registry runs nothing, so
    -- the case above is also true of a harness that had lost the ability to
    -- dispatch at all. Firing UNCONDITIONALLY at the addon proves it had not.
    local KCM, H = build()
    -- The kit reaches a handler whose registration is gone through `__events`,
    -- or failing that through the method NAMED for the event (AceEvent's
    -- default). KCM names its own ("OnPlayerEnteringWorld"), and unregister
    -- clears that name from `__events`, so a bare fire at KCM answers 0. The
    -- handler map is therefore taken while the addon is up and fired at a view
    -- of KCM that still holds it: the handler is KCM's own, only the
    -- registration is gone, which is exactly what a survivor would look like.
    local registered = {}
    for e, handler in pairs(rawget(KCM, "__events")) do registered[e] = handler end
    t.eq(registered.PLAYER_ENTERING_WORLD, "OnPlayerEnteringWorld", "the handler KCM registered")
    H.SetAndRefresh("enabled", false)
    resetPrinted()
    local reached, real = 0, KCM.OnPlayerEnteringWorld
    KCM.OnPlayerEnteringWorld = function(...) reached = reached + 1; return real(...) end
    local view = setmetatable({ __events = registered }, { __index = KCM })
    local ran = mock.base.__fireUnconditional(view, "PLAYER_ENTERING_WORLD")
    KCM.OnPlayerEnteringWorld = real
    t.truthy((ran or 0) > 0, "the unconditional dispatch reaches OnPlayerEnteringWorld")
    t.eq(reached, 1, "and it was KCM's own handler that ran")
    -- And the live set really is the thing __fire reads: with the addon back up,
    -- the same call reaches a handler.
    H.SetAndRefresh("enabled", true)
    t.truthy(mock.base.__fire("BAG_UPDATE_DELAYED") > 0, "an enabled addon is reached")
end)

-- ---------------------------------------------------------------------------
-- 7. The slash surface — UNCHANGED, and that is the ruling
-- ---------------------------------------------------------------------------
--
-- NOT the stand-down. Steps 1-6 are. A green step 7 says nothing about whether
-- the addon is inert; it says the player can still reach the switch.
--
-- The standard narrowed this surface to `enable` and `help` at v2.56.0 and
-- REVERSED it at v2.57.0, because `/cm` on a disabled addon answered with a
-- refusal instead of opening the settings panel — the one surface a player uses
-- to switch it back on by hand. Every reserved verb answers.

local RESERVED = {
    "help", "config", "version", "enable", "disable", "debug",
    "perf", "get", "set", "list", "reset", "resetall",
}

-- The verbs whose answer is a WINDOW rather than a line: `debug` toggles the
-- console, `perf` opens the step panel, `config` opens the settings panel and
-- `resetall` raises the confirm popup. All four are on the live list and none of
-- them prints on success, so "it said something" is the wrong question for them.
local SILENT = { debug = true, perf = true, config = true, resetall = true }

local function dispatch(KCM, line)
    resetPrinted()
    KCM:OnSlashCommand(line)
    return printed()
end

test("Disabled 7: every reserved verb still answers normally", function(t)
    local KCM, H = build()
    local refusal = KCM.SlashCommands.instance:DisabledLine()
    H.SetAndRefresh("enabled", false)

    for _, verb in ipairs(RESERVED) do
        local out = dispatch(KCM, verb)
        -- What is asked of every one of the twelve is the thing the standard
        -- actually fixes: that it was NOT refused.
        if not SILENT[verb] then
            t.truthy(out ~= "", "'" .. verb .. "' answered something")
        end
        -- The one-line refusal, and nothing else, is what a REFUSED verb looks
        -- like. `help` prints the same sentence under its header and then the
        -- whole index, which is not a refusal of help — the player has to be able
        -- to SEE `enable` in the list.
        local onlyRefusal = out:find(refusal, 1, true) ~= nil
            and select(2, out:gsub("\n", "")) == 0
        t.falsy(onlyRefusal, "'" .. verb .. "' was not refused: " .. out)
        H.SetAndRefresh("enabled", false)
    end
end)

test("Disabled 7b: the bare /cm opens the settings panel", function(t)
    local KCM, H = build()
    local opened = 0
    KCM.Options.Open = function() opened = opened + 1; return true end
    H.SetAndRefresh("enabled", false)

    dispatch(KCM, "")
    -- THE CASE THAT SETTLED THE ROUND TRIP. A rule that makes the off switch
    -- harder to find has misunderstood which half of the pair it is protecting.
    t.eq(opened, 1, "the bare verb opened the panel while disabled")
    dispatch(KCM, "config")
    t.eq(opened, 2, "and so did config")
end)

test("Disabled 7c: a feature verb refuses on exactly one line, and reaches no seam", function(t)
    local KCM, H = build()
    local refusal = KCM.SlashCommands.instance:DisabledLine()
    H.SetAndRefresh("enabled", false)

    local before = storedState(KCM)
    local out = dispatch(KCM, "bar on")
    t.truthy(out:find(refusal, 1, true) ~= nil, "it is the collection's line: " .. out)
    t.eq(select(2, out:gsub("\n", "")), 0, "exactly one line")
    -- The addon takes §2's SHOULD, so this suite PINS that choice: an addon that
    -- declined it would assert its feature verbs act normally instead, and either
    -- is conformant. What must not happen is the choice drifting in silence.
    t.eq(storedState(KCM), before, "and no write seam was reached")
end)

test("Disabled 7d: the refusal line is the collection's shape, not a re-spelling", function(t)
    local KCM = build()
    local Sl = KCM.SlashCommands.instance
    local line = Sl:DisabledLine()
    -- Matched against the library's exported FORMAT rather than against the words,
    -- so this case pins the shape and the library owns the sentence.
    local want = LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT
        :format("Ka0s Consumable Master", "/cm enable")
    t.eq(line, want, "one wording, built once, collection-wide")
    -- The brand name is the SAME string the LDB object carries as `label`
    -- (launcher-§1), spelled as a literal in both files. Pinned here because
    -- nothing else would notice the day one of the two is edited.
    t.eq(KCM.Launcher:Object().label, "Ka0s Consumable Master", "one brand spelling")
    t.truthy(line:find("Ka0s Consumable Master", 1, true) ~= nil, "and the line carries it")
end)

-- ---------------------------------------------------------------------------
-- 8. The launcher
-- ---------------------------------------------------------------------------

test("Disabled 8: left-click is refused and writes nothing; right-click opens the panel",
    function(t)
        local KCM, H = build()
        local refusal = KCM.SlashCommands.instance:DisabledLine()
        local opened = 0
        KCM.Options.Open = function() opened = opened + 1; return true end
        H.SetAndRefresh("enabled", false)

        local object = KCM.Launcher:Object()
        local before = storedState(KCM)
        resetPrinted()
        object.OnClick(object, "LeftButton")

        -- Rung (b): the left click drives the macro bar's lock, which IS this
        -- addon's preview switch, and a preview switch is a feature (launcher-§2).
        t.eq(storedState(KCM), before, "the click wrote no SavedVariables")
        local out = printed()
        t.truthy(out:find(refusal, 1, true) ~= nil, "one refusal line: " .. out)
        t.eq(select(2, out:gsub("\n", "")), 0, "and exactly one")
        t.eq(opened, 0, "the left button did not open the panel either")

        -- Right-click is UNCHANGED in either state: the panel is setup, not a
        -- feature, and it is the route that replaces what the left button lost.
        object.OnClick(object, "RightButton")
        t.eq(opened, 1, "right-click opened the settings panel")
    end)

-- ---------------------------------------------------------------------------
-- 9. Re-enable, and restoration FROM CURRENT STATE
-- ---------------------------------------------------------------------------

test("Disabled 9: re-enabling rebuilds exactly the set it took down", function(t)
    local _, H = build()
    local R_on = registrations()
    local armed, n_on = combatDriverFrames()
    t.truthy(n_on > 0, "the flyout attribute drivers are armed before the disable")
    H.SetAndRefresh("enabled", false)
    t.eq(count(registrations()), 0, "down")
    t.eq(select(2, combatDriverFrames()), 0, "and the flyout attribute drivers with it")
    H.SetAndRefresh("enabled", true)
    t.eqList(registrations(), R_on, "and back up with the same registration set")
    -- The same frames, re-armed: the flyouts are kept across the stand-down,
    -- not rebuilt, so identity is the right comparison here.
    local rearmed, n_back = combatDriverFrames()
    t.eq(n_back, n_on, "every flyout attribute driver is re-armed")
    for frame, value in pairs(armed) do
        t.eq(rearmed[frame], value, "on the same flyout frame, with the same conditional")
    end
end)

test("Disabled 9b: a setting changed while disabled is honored on the way back up", function(t)
    local KCM, H, frames = build()
    local seen = watchBar(frames)
    H.SetAndRefresh("enabled", false)

    -- The whole schema CLI answers while disabled, so this is a thing a player
    -- really can do — and a stand-up that replayed a SNAPSHOT taken on the way
    -- down would bring the bar back anyway (performance-§6).
    KCM:OnSlashCommand("set macroBar.enabled false")
    t.eq(H.Get("macroBar.enabled"), false, "the write landed while disabled")

    seen.shows = 0
    H.SetAndRefresh("enabled", true)
    t.eq(seen.shows, 0, "the bar stayed off, because the rebuild read the setting as it is NOW")
    t.falsy(KCM.MacroBarModel.IsEnabled(), "and the ladder agrees")
end)

-- red under: standUp without DiscoverAndSweep. The stand-down took
-- BAG_UPDATE_DELAYED off, and PLAYER_ENTERING_WORLD does not fire again on a
-- re-enable, so without the stand-up's own discovery pass an item looted while
-- disabled is no candidate until the next bag update happens to arrive.
test("Disabled 9c: an item looted while disabled is discovered on the way back up", function(t)
    local KCM, H = build()
    local LOOTED = 910090
    local function isCandidate()
        for _, id in ipairs(KCM.Selector.GetEffectivePriority("FOOD")) do
            if id == LOOTED then return true end
        end
        return false
    end
    H.SetAndRefresh("enabled", false)

    mock.setItem(LOOTED, { subType = "Food & Drink", tt = { healValue = 500 } })
    mock.setBag(LOOTED, 1)
    -- The full addon runs the real tooltip parser, which the mock feeds no
    -- lines; answer for this one item from its `tt`, as the pure layer's
    -- TooltipCache stub (tests/run.lua) does for every item.
    local realGet = KCM.TooltipCache.Get
    KCM.TooltipCache.Get = function(id)
        if id ~= LOOTED then return realGet(id) end
        return { healValue = 500, itemName = mock.items[id].name }
    end
    t.falsy(isCandidate(), "not a FOOD candidate while disabled")

    H.SetAndRefresh("enabled", true)   -- and no BAG_UPDATE_DELAYED is fired
    t.truthy(isCandidate(), "the stand-up's discovery pass made it a FOOD candidate")
end)

-- ---------------------------------------------------------------------------
-- 10. The latch — two holds, and releasing one must not resurrect the addon
-- ---------------------------------------------------------------------------
--
-- red under: give `P.Suspend` / `P.Resume` a boolean of their own again, or have
-- either release call a bare stand-up. Both bring the addon back to life under a
-- player who switched it off, and the perf arm's own cases would stay green.

test("Disabled 10: releasing perf does not stand up an addon disable still holds", function(t)
    local KCM, H = build()
    local lc = KCM.Lifecycle

    lc:Hold(PERF)
    t.eq(count(registrations()), 0, "the perf hold stood it down")
    H.SetAndRefresh("enabled", false)
    t.truthy(lc:IsHeld(DISABLED) and lc:IsHeld(PERF), "both holds are taken")

    lc:Release(PERF)
    t.eq(count(registrations()), 0, "and it is STILL down, because disable still holds it")

    H.SetAndRefresh("enabled", true)
    t.truthy(count(registrations()) > 0, "the last release stands it up")
end)

test("Disabled 10b: the same, with the holds taken in the other order", function(t)
    local KCM, H = build()
    local lc = KCM.Lifecycle
    local R_on = registrations()

    H.SetAndRefresh("enabled", false)
    lc:Hold(PERF)
    t.eq(count(registrations()), 0, "down")

    H.SetAndRefresh("enabled", true)
    t.eq(count(registrations()), 0, "re-enabling mid-capture does NOT resurrect it")
    t.truthy(lc:IsHeld(PERF), "the perf hold is what is holding it")

    lc:Release(PERF)
    t.eqList(registrations(), R_on, "and the capture's own release brings it back")
end)

test("Disabled 10c: the perf harness takes its hold on this very latch", function(t)
    local KCM = build()
    t.truthy(KCM.Perf, "the probe was built")
    KCM.Perf.Suspend()
    t.truthy(KCM.Lifecycle:IsHeld(PERF), "P.Suspend took the named hold")
    t.eq(count(registrations()), 0, "and the addon is inert for it")
    KCM.Perf.Resume()
    t.falsy(KCM.Lifecycle:IsHeld(PERF), "P.Resume gave it back")
    t.truthy(count(registrations()) > 0, "and the addon came up")
end)

test("Disabled 10d: a profile that arrives disabled stands the addon down", function(t)
    local KCM, H = build()
    t.truthy(count(registrations()) > 0, "up on the outgoing profile")

    KCM.db:SetProfile("off-profile")
    KCM.Settings.Helpers.Set("enabled", false)
    -- The AceDB callbacks SURVIVE the disabled state precisely so this works: a
    -- profile switch can flip the stored path with no verb and no checkbox being
    -- touched (slash-commands-§7).
    KCM.db:SetProfile("Default")
    KCM.db:SetProfile("off-profile")
    t.eq(count(registrations()), 0, "the incoming profile's enabled=false stood it down")

    KCM.db:SetProfile("Default")
    t.truthy(count(registrations()) > 0, "and switching back stood it up")
    t.falsy(H.Get("enabled") == false, "on a profile that is enabled")
end)
