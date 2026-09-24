-- core/PerfSetup.lua — the addon's half of LibKa0s-Perf-1.0.
--
-- It lives in core/ and sits right after core/LifecycleSetup.lua in the TOC.
-- performance-§1 names `core/PerfSetup.lua` and requires it be positioned
-- BEFORE any file taking `local Perf = NS.Perf` as a load-time upvalue —
-- core/ConsumableMaster.lua and modules/MacroBar.lua both do. It reads two
-- things at load: KCM.VERSION, which is why that constant lives in
-- core/Namespace.lua, and KCM.Lifecycle, which is why it loads after
-- core/LifecycleSetup.lua (see the guard below). Every other host member it
-- touches (KCM.DebugLog, KCM.Say, KCM.OnEnable, KCM.MacroBar) is reached
-- through a thunk, at call time, so loading this early costs nothing.
--
-- An A/B capture harness, not a profiler. The protocol is: pull once with the
-- addon live, pull again with it suspended, and report the difference in
-- ms-per-frame. Recording opens when combat starts and closes when it ends, so
-- what it measures is the addon's IN-COMBAT cost and nothing else.
--
-- That framing is worth stating plainly, because the addon's genuinely
-- expensive paths are deliberately out of combat — the macro bar's flyout
-- rebuild is skipped in combat, MB.Update defers wholesale, and macro writes
-- wait for regen. Those will never appear in a capture. What DOES appear is the
-- cooldown repaint, which rides SPELL_UPDATE_COOLDOWN and BAG_UPDATE_COOLDOWN
-- and walks every bar button plus every shown flyout row — the one path that
-- runs at near-frame frequency mid-fight, and the reason this is worth wiring
-- up at all.
--
-- Unlike the other three LibKa0s seams, KCM.Perf IS the library instance rather
-- than a facade over it. There is no prior KCM.Perf surface to preserve, the
-- instance is already a flat dot-callable table, and — decisively — three of
-- the members the instrumentation reads (`on`, `run`, `suspended`) are plain
-- boolean FIELDS the library writes directly. A forwarder cannot mirror a
-- field, so an IsOn() wrapper would be a second truth that goes stale the
-- moment a window opens. Identity against the library is asserted through the
-- function objects it mirrors onto every instance instead.

local addonName, NS = ...
local KCM = NS

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)

-- One probe covers both failure modes: Perf.lua absent, and Core absent or too
-- old (Perf.lua returns before NewLibrary in that case, so the major never
-- registers). No stub is published: an absent major means an absent feature,
-- the /cm perf handler says so, and the two bracket sites take their upvalue
-- nil-tolerantly (`(Perf and Perf.on)`) so neither errors on that build. There
-- is no separate PerfPanel major to probe; it attaches onto the instance.
-- The latch, built one file earlier. Perf.lua minor 12 REQUIRES it and raises at
-- :New without it, so a missing one is a probe that never builds rather than a
-- run that measures a fully live addon and reports a delta of about zero — a
-- wrong answer that looks exactly like a good one. Both majors ship in the same
-- whole-folder payload, so the only way to be here without it is a partial
-- vendor, which library-stack-§7 already forbids.
if not (lib and KCM.Lifecycle) then return end

-- WHAT "INERT" MEANS FOR THIS ADDON IS NOT THIS FILE'S ANSWER ANY MORE.
--
-- `suspend` and `resume` used to live here, and Perf.lua called them. From minor
-- 12 the descriptor takes a `lifecycle` instead: P.Suspend() takes the `perf`
-- HOLD on core/LifecycleSetup.lua's latch and P.Resume() gives it back, and the
-- latch decides whether anything actually happens. The two functions did not
-- vanish — they are `standDown` / `standUp` over there, where the DISABLED arm
-- reaches the very same code.
--
-- That is the point of the move rather than a tidy-up. Keeping a copy here would
-- give this addon two mechanisms that both mean "be inert", and they diverge on
-- the first module added after the second was written: the perf arm would
-- unregister nine events and the disable arm eight, and nothing would say so
-- (anti-pattern #85). It also fixes the case a boolean could not represent — a
-- player who disables the addon mid-capture, and a `resume` that would otherwise
-- bring it back to life under them.
--
-- The two rules the contract still depends on are unchanged and are enforced
-- over there: it works WITHOUT a reload (reloading shifts shared-frame
-- ownership, the confound that makes Blizzard's own addon profiler useless for
-- this question), and visibility is enforced at the SOURCE rather than by hiding
-- frames imperatively.

local P = lib:New({
    -- Seeds the sampler and panel frame globals, matching the debug console's
    -- ConsumableMasterDebugWindow so /framestack reads them the same way.
    name  = addonName,

    -- Beside `name`, never instead of it. `name` seeds the frame globals;
    -- `addonName` is the addon FOLDER LibKa0s-Core builds a texture path from.
    -- Same string here, two different questions everywhere.
    --
    -- THIS FIELD IS WHAT DRAWS THE PANEL'S CLOSE MARK. The vendored PerfPanel
    -- (panel minor 4, LibKa0s v1.10.2) builds its close with
    -- `core.MakeCloseButton(frame, P.HidePanel, d.addonName or d.name)`, so the
    -- folder name reaches the factory and `/cm perf` closes with the same mark
    -- the debug console closes with.
    --
    -- Panel minor 3 dropped that third argument and shipped a multiplication
    -- sign beside a console wearing the mark — anti-pattern #64 inside the
    -- library, the same one DebugLog was fixed for at minor 10. The cure was a
    -- library minor and a re-vendor, never a patch under libs/ (#63): this repo
    -- carried minor 3 for exactly one commit and now carries 4.
    addonName = addonName,

    title = "Consumable Master",   -- the library appends its own " — Perf Run"

    -- Mandatory, not optional. The default is "/" .. name:lower() — i.e.
    -- "/consumablemaster", which is a real alias but not the one anybody types,
    -- and every panel row and usage line would teach it.
    slash = "/cm",

    -- Its OWN SavedVariables global, declared alongside ConsumableMasterDB in
    -- the TOC. Not the AceDB tree: the library writes _G[sv] directly, so
    -- reusing ConsumableMasterDB would stamp `schema` and `runs` onto AceDB's
    -- root and trip its own discard branch on the next load.
    sv = "ConsumableMasterPerfDB",

    version = KCM.VERSION,

    -- Thunks, never bare: lib:New snapshots all three. Same note as
    -- core/CoreSetup.lua's sink and core/DebugLogSetup.lua's print.
    --
    -- log goes to DL.AddLine, NOT to KCM.Debug. AddLine is the ungated append —
    -- the library's own console documents that it is ungated precisely so a
    -- host's perf output lands whatever the debug flag says. Routing this
    -- through KCM.Debug would swallow the entire run whenever debug was off,
    -- which is most of the time.
    log     = function(line) KCM.DebugLog.AddLine("Perf", line) end,
    print   = function(line) KCM.Say(line) end,
    showLog = function() KCM.DebugLog.Show() end,

    -- THE LATCH, not a suspend/resume pair (Perf minor 12). `P.Suspend()` takes
    -- the `perf` hold and `P.Resume()` releases it; whether the addon comes back
    -- is the latch's decision, and it answers no while `disabled` is still held.
    lifecycle = KCM.Lifecycle,

    -- Presentation order for the report. Membership controls printing only —
    -- Note() accepts any key — so an undeclared bracket still records silently.
    buckets = {
        { key = "cooldown"  },
        { key = "recompute" },
    },
})

KCM.Perf = P
