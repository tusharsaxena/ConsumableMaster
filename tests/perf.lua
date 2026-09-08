-- tests/perf.lua — the offline performance runner (performance-§9).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- DELIBERATELY OUTSIDE THE GREEN GATE. `lua tests/run.lua` does not invoke this, and nothing about
-- a commit depends on it. Wall-clock numbers on a developer machine are not stable enough to fail
-- a build on, and a perf suite that fails spuriously gets disabled within a week. The
-- automated-tests runner records it and lets it gate the TAG, never the run.
--
-- What it DOES assert is the deterministic half — bytes allocated per pass, and the zero-overhead
-- property of the instrumentation itself. Those are machine-independent, so a real regression
-- (someone puts an allocation in the cooldown repaint, or un-gates a Perf bracket) fails here
-- loudly while a busy CPU never does. Exit code is non-zero on an assertion failure.
--
-- Timings are printed for orientation only. Read them as ratios between scenarios in one run,
-- never as absolute numbers to compare across machines.
--
-- WHAT IS WORTH MEASURING HERE, and what is not. core/PerfSetup.lua says it at length: this
-- addon's expensive paths are deliberately OUT of combat — the flyout rebuild is skipped in
-- combat, MB.Update defers wholesale, and macro writes wait for regen. The one path that runs at
-- near-frame frequency mid-fight is the cooldown repaint, which walks every bar button plus every
-- shown flyout row. That is why it is scenario 2 and why the zero-overhead pair is measured over
-- it rather than over the recompute.
--
-- Output is the shared record schema, encoded by the SAME KCM.Perf.EncodeJSON the in-game probe
-- uses, so an offline record and an in-game record are guaranteed to be the same shape.

local realprint = print   -- mock.install replaces _G.print with the chat capture

local Loader   = dofile("tests/_kit/loader.lua")
local mockBase = dofile("tests/_kit/mock_base.lua")
local mock     = dofile("tests/wow_mock.lua")(mockBase)

-- Each dofile of the kit loader returns a FRESH table, so this runner sets its own addonName
-- rather than inheriting one from tests/run.lua. Addon chunks are called as
-- ("ConsumableMaster", NS) to match the client's `local addonName, NS = ...` header.
Loader.addonName = "ConsumableMaster"

-- ── arguments ───────────────────────────────────────────────────────────────────────────────

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" then opts.label = arg[i + 1] or opts.label; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write("usage: lua tests/perf.lua [--out <path>] [--label <text>]\n")
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────

local NS = {}
mock.install(NS)
_G.KCM = nil

-- Both lists are DERIVED, never typed here. The library half comes from
-- libs/LibKa0s/LibKa0s.xml — the file the TOC actually reaches — and getting it wrong is silent:
-- a module whose dependency is absent returns BEFORE LibStub:NewLibrary, so the major never
-- registers, core/PerfSetup.lua returns early, KCM.Perf is nil, and the zero-overhead scenario
-- below would happily measure two identical arms with no probe in either.
Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS, {})
Loader.loadAll(Loader.tocFiles("ConsumableMaster.toc"), NS, {})

local KCM = NS
pcall(function() KCM:OnInitialize() end)

if not (KCM.db and KCM.Perf and KCM.Perf.Note) then
    io.stderr:write("perf: the addon did not load with a live db and a live KCM.Perf — "
        .. "run this from the repo root\n")
    os.exit(2)
end

-- Build the bar for real, so the cooldown walk below has buttons to walk. Every slot is created
-- (modules/MacroBar.lua creates them for ALL categories, not just the visible ones), which is the
-- worst realistic case and the one the user is running.
KCM.MacroBar.Update()

-- ── measurement helpers ─────────────────────────────────────────────────────────────────────

local results = {}
local failures = {}

local function assert_(cond, msg)
    if not cond then failures[#failures + 1] = msg end
    return cond
end

--- Run `fn` `iterations` times, reporting wall time and bytes allocated PER ITERATION.
---
--- The allocation figure is the load-bearing one. A full collect before and after isolates the
--- garbage this path actually produces, and garbage per repaint is what turns a cheap-looking
--- function into a frame-rate problem once it runs at near-frame frequency in combat.
local function measure(name, iterations, fn)
    collectgarbage("collect")
    collectgarbage("collect")
    local kbBefore = collectgarbage("count")
    local t0 = os.clock()
    for i = 1, iterations do fn(i) end
    local elapsed = os.clock() - t0
    local kbAfter = collectgarbage("count")

    local r = {
        name         = name,
        iterations   = iterations,
        totalMs      = elapsed * 1000,
        msPerIter    = (elapsed * 1000) / iterations,
        bytesPerIter = ((kbAfter - kbBefore) * 1024) / iterations,
    }
    results[#results + 1] = r
    return r
end

-- ── scenarios ───────────────────────────────────────────────────────────────────────────────

local BURST = 200

-- 1. The recompute pass — the 15-category walk, the composite re-picks and every macro write.
--    Coalesced to at most one per frame by RequestRecompute, and skipped outright in combat, so
--    this is an out-of-combat cost. Measured for orientation and for the record's trend line.
measure("recompute", BURST, function()
    KCM.Pipeline.Recompute("perf")
end)

-- 2. The cooldown repaint — SPELL_UPDATE_COOLDOWN and BAG_UPDATE_COOLDOWN both land here, and each
--    one walks every bar button plus every shown flyout row. THE near-frame-frequency path in
--    combat, and the bucket a capture attributes a delta to.
measure("cooldownRefresh", BURST, function()
    KCM.MacroBar.RefreshCooldowns()
end)

-- 3. ZERO OVERHEAD — the scenario this file exists for.
--
--    performance-§2's gating idiom is `local t0 = (Perf and Perf.on) and debugprofilestop() or nil`
--    over a load-time upvalue: with no capture open that is an upvalue read, a nil test and a field
--    read, and it must allocate NOTHING. If the instrumentation is not free when dormant then the
--    measurement tool is itself the regression, and every capture it produces is measuring itself.
--
--    Both arms run the SAME path (the cooldown walk), once with the brackets dormant and once with
--    them armed, so the only difference between the two figures is the probe.
local probeOff = measure("probeOverheadOff", BURST, function()
    KCM.MacroBar.RefreshCooldowns()
end)

KCM.Perf.on = true
local probeOn = measure("probeOverheadOn", BURST, function()
    KCM.MacroBar.RefreshCooldowns()
end)
KCM.Perf.on = false

-- The relation alone cannot go red the way it matters (testing-§12): if a regression adds
-- allocation to the cooldown path itself, BOTH arms rise together and `off <= on + 1` still holds.
-- The dormant arm therefore also carries an ABSOLUTE ceiling. Raise it only with a recorded
-- reason — a rise IS the finding, and the headroom below is deliberately thin.
--
-- RE-VERIFIED 2026-09-08, three consecutive runs, and left where it stands.
--
--   measured   6000.0 bytes/iter with the brackets dormant, identical to the tenth in all three
--              runs and EXACTLY cooldownRefresh's figure — which is the point: the probe
--              contributes none of it. The walk is deterministic under the mock (fifteen slots,
--              one duration object each).
--   ceiling    6144 = 6000 plus one 144-byte slot's worth of headroom, i.e. 2.4%.
--   margin     Measured rather than asserted: one empty table added to this scenario's body moves
--              the figure 6000.0 -> 6064.0, so a table costs 64 bytes/pass under this interpreter
--              and the 144-byte margin ADMITS TWO of them before it trips. Stated plainly because
--              it is the limit of what this line catches. It is not tightened to 6032 — the
--              sibling re-baselining in AbsorbTracker's tests/perf.lua could afford that because
--              its baseline is 48.0 and its loop never provokes the collector; this loop allocates
--              1.2 MB, `measure` reports what the collector has NOT reclaimed by the end of it,
--              and this file's own `recompute` line demonstrably moves with unrelated edits to
--              this file for exactly that reason. Half a percent of headroom on a figure taken
--              that way buys a gate that goes red on a good day, which is the failure the header
--              of this file is about. A regression that adds a table PER SLOT — the realistic
--              shape — costs fifteen of them and trips this immediately.
--
-- Raise it only by filling in those three lines again — a rise IS the finding.
local PROBE_OFF_BYTES_CEILING = 6144

assert_(probeOff.bytesPerIter <= PROBE_OFF_BYTES_CEILING,
    ("a dormant pass allocated %.1f bytes/iter, over the %d-byte ceiling — the cooldown path grew")
        :format(probeOff.bytesPerIter, PROBE_OFF_BYTES_CEILING))
assert_(probeOff.bytesPerIter <= probeOn.bytesPerIter + 1,
    ("a dormant bracket allocated %.1f bytes/iter against an armed %.1f — the gating idiom is wrong")
        :format(probeOff.bytesPerIter, probeOn.bytesPerIter))

-- 4. THE FIRST-OPEN REFRESH BURST — the panel-side debounce, which is a one-off cost and is here
--    for exactly that reason.
--
--    docs/data-flow.md's GIIR split: opening the settings panel for the first time in a session
--    hydrates roughly 150 priority-list items that are not in bags, and each arrival publishes
--    PANEL_REFRESH, which lands on KCM.Options.RequestRefresh. One player action, 150 calls, and
--    one panel rebuild is meant to come out the far end. Nothing else in this file and nothing in
--    any in-game capture attributes a byte to that path, so for as long as it went unmeasured
--    "the debounce is cheap" was an assertion rather than a reading — which is why the plan for
--    this item gates the fix on the scenario and not the other way round.
--
--    THE TWO STUBS BELOW ARE THE INSTRUMENT, not a convenience.
--
--    tests/wow_mock.lua's C_Timer.After runs its callback synchronously. Under it a trailing-edge
--    debounce refreshes on EVERY call, so a scenario driven through the mock as shipped would be
--    measuring RefreshAllPanels 150 times and would report the same figure whatever the debounce
--    did. The stub keeps the most recently scheduled callback and runs it once the burst has gone
--    quiet, which is what the client does; it is also the shape tests/_kit/mock_base.lua uses, and
--    the shape tests/test_pipeline.lua's coalescing case already borrows. It allocates nothing, so
--    the figure below is the ADDON's allocation alone — the client's per-timer ticker table sits on
--    top of it and is not counted here.
--
--    GetTime is the mock's os.clock(), which advances by microseconds across a 150-call loop. That
--    is a storm that never goes quiet, so every iteration would run into the next one and the
--    burst boundary the scenario is about would not exist. A virtual clock the body steps by hand
--    gives each iteration one clean burst: 150 calls a millisecond apart, then a second of silence.
local REFRESH_BURST_CALLS = 150
local timersScheduled = 0
local refreshBurst
do
    local dueFn
    local savedAfter   = _G.C_Timer.After
    local savedGetTime = _G.GetTime
    local vnow = 0
    _G.GetTime = function() return vnow end
    _G.C_Timer.After = function(_, fn) timersScheduled = timersScheduled + 1; dueFn = fn end

    refreshBurst = measure("refreshBurst", BURST, function()
        for _ = 1, REFRESH_BURST_CALLS do
            vnow = vnow + 0.001
            KCM.Options.RequestRefresh()
        end
        vnow = vnow + 1.0            -- the events stop; the debounce window closes
        local fn = dueFn
        dueFn = nil
        if fn then fn() end          -- the tail of the burst, where the one rebuild belongs
    end)

    _G.C_Timer.After = savedAfter
    _G.GetTime       = savedGetTime
end

-- The load-bearing assertion of this scenario is a COUNT. The number of timers a burst arms is a
-- property of the debounce itself: it is an integer, it is the same on every machine, and it is
-- the defect stated directly. Two per burst rather than one, because a burst that straddles the
-- REFRESH_MAX_WAIT_SEC cap legitimately re-arms once and pinning it at exactly one would forbid
-- the cap from working.
local TIMERS_PER_BURST_CEILING = 2
assert_(timersScheduled <= BURST * TIMERS_PER_BURST_CEILING,
    ("a %d-call burst armed %.1f timers, over the %d-per-burst ceiling — the debounce is scheduling "
     .. "per call rather than per burst"):format(REFRESH_BURST_CALLS,
        timersScheduled / BURST, TIMERS_PER_BURST_CEILING))

-- And a byte ceiling beside it, because the count alone does not forbid the closure: a shape that
-- armed one timer and still built a fresh callback per call would pass the line above.
--
-- BASELINED 2026-09-08, three consecutive runs.
--
--   measured   0.0 bytes/burst, identical in all three. The debounce writes numbers onto O and
--              nothing else, and numbers are not heap objects in 5.1, so the honest reading of
--              this path is zero rather than a small figure.
--   ceiling    1024 bytes/burst.
--   margin     DERIVED from the defect this line exists to catch, which is the one that was
--              actually here: the per-call closure measured 2251.2 bytes/burst over three runs
--              before it was removed, so 1024 trips at under half its return. The floor under the
--              ceiling is measured too — one empty table added to this scenario's body moves the
--              figure 0.0 -> 64.0, so 1024 is sixteen tables of room for the ONE tail rebuild a
--              burst legitimately performs, and that rebuild growing is not what this line is
--              about.
--
-- A byte figure taken this way is also worth reading with its limits in mind. `measure` reports
-- what the heap has NOT reclaimed by the end of the loop, so a scenario's byte column moves with
-- the live-heap size at the moment it runs and therefore with the rest of this file: adding this
-- scenario alone, changing nothing else, moved `recompute` from 4102.0 to 4179.0. That is why the
-- count above leads and this follows, and why the margin here is wide rather than tight.
local REFRESH_BURST_BYTES_CEILING = 1024
assert_(refreshBurst.bytesPerIter <= REFRESH_BURST_BYTES_CEILING,
    ("a %d-call burst allocated %.1f bytes, over the %d-byte ceiling — something in the debounce is "
     .. "allocating per call again"):format(REFRESH_BURST_CALLS, refreshBurst.bytesPerIter,
        REFRESH_BURST_BYTES_CEILING))

-- And the probe has to actually be there. Without this the two arms above could both be measuring
-- a build where core/PerfSetup.lua returned early, which reads as a perfect zero-overhead result.
KCM.Perf.on = true
local notedBefore = 0
local realNote = KCM.Perf.Note
KCM.Perf.Note = function(...) notedBefore = notedBefore + 1; return realNote(...) end
KCM.MacroBar.RefreshCooldowns()
KCM.Pipeline.Recompute("perf")
KCM.Perf.Note = realNote
KCM.Perf.on = false
assert_(notedBefore == 2,
    ("an armed capture recorded %d bucket notes over the two bracketed paths, expected 2 — "
     .. "a bracket is missing or is not gated on Perf.on"):format(notedBefore))

-- ── report ──────────────────────────────────────────────────────────────────────────────────

realprint(("Ka0s Consumable Master \226\128\148 offline perf  (v%s, label '%s')")
    :format(tostring(KCM.VERSION), opts.label))
realprint()
realprint(("%-20s %10s %12s %12s %12s")
    :format("scenario", "iters", "ms/iter", "total ms", "bytes/iter"))
for _, r in ipairs(results) do
    realprint(("%-20s %10d %12.5f %12.3f %12.1f")
        :format(r.name, r.iterations, r.msPerIter, r.totalMs, r.bytesPerIter))
end
realprint()
realprint("timings are for orientation only \226\128\148 compare scenarios within a run, "
    .. "never across machines")

if #failures > 0 then
    realprint()
    realprint(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
    for _, f in ipairs(failures) do realprint("  - " .. f) end
end

-- ── record ──────────────────────────────────────────────────────────────────────────────────

if opts.out then
    local buckets = {}
    for _, r in ipairs(results) do
        -- Map the scenario table onto the shared bucket shape: `calls` is the iteration count and
        -- `totalMs` / `maxMs` carry the same meaning as in-game, so one reader handles both
        -- sources. No `within`, deliberately: these scenarios are entry points driven one at a
        -- time, each timing only its own loop, so no scenario's total is contained in another's.
        buckets[r.name] = {
            calls        = r.iterations,
            totalMs      = r.totalMs,
            maxMs        = r.msPerIter,
            bytesPerIter = r.bytesPerIter,
        }
    end

    local record = {
        schema    = KCM.Perf.SCHEMA,
        addon     = "ConsumableMaster",
        source    = "offline",
        version   = KCM.VERSION,
        interface = 0,          -- no client involved
        timestamp = os.time(),
        label     = opts.label,
        buckets   = buckets,
        fps       = {           -- fixed shape; an offline run has no frames to sample
            active    = { seconds = 0, frames = 0, avgFps = 0, msPerFrame = 0 },
            suspended = { seconds = 0, frames = 0, avgFps = 0, msPerFrame = 0 },
            deltaMsPerFrame = 0,
        },
        failures  = failures,
    }

    local fh, err = io.open(opts.out, "w")
    if not fh then
        io.stderr:write("cannot write " .. opts.out .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(KCM.Perf.EncodeJSON(record), "\n")
    fh:close()
    realprint("wrote " .. opts.out)
end

os.exit(#failures == 0 and 0 or 1)
