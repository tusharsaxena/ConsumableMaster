-- CoreSetup.lua — wires the addon into LibKa0s-Core-1.0.
--
-- The concat probe, the secret-safe stringifier and the prefixed chat printer
-- used to live in core/Constants.lua. They exist in every Ka0s addon and are
-- wrong in slightly different ways in several of them, so they now live in
-- libs/LibKa0s/Core.lua and this file is only the part that is ours: which tag
-- the lines carry, where they land, and what happens when the library is not
-- installed.
--
-- Sits immediately after core/Constants.lua, and the slot is pinned from both
-- sides. Below: core/SlashCommands.lua takes `local say = KCM.Say` as a
-- file-scope upvalue, so the printer has to exist before it loads or the swap
-- silently no-ops while appearing to work. Above: KCM.PREFIX is defined in
-- core/Constants.lua — though the function form of `prefix` below means that
-- one is a preference rather than a constraint.
--
-- Note what does NOT constrain the slot here, and does in most of the
-- collection: AceAddon:NewAddon embeds AceConsole's :Print onto the namespace
-- at core/ConsumableMaster.lua, which loads FIRST, and this addon's printer is
-- named Say. There is no same-named clobber to reclaim (anti-patterns #36).

local addonName, NS = ...
local KCM = NS

-- The one cause clause, shared by every seam that has to explain the same
-- absence. Each appends its own "so <what> is unavailable", so a degraded
-- install says the same thing about WHY and a different thing about WHAT.
-- Set outside the branch below because both paths' readers need it, and set
-- HERE because core/CoreSetup.lua is the first of the seams the TOC loads.
KCM.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of " ..
    "Consumable Master (expected in libs/LibKa0s)"

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- A missing vendored lib must degrade, not error at load. Silence is not an
    -- option: 177 call sites reach KCM.Say and core/SlashCommands.lua captures
    -- it at file scope, so a nil printer takes /cm down with it and a no-op one
    -- makes the addon answer nothing at all. So the fallbacks work — they are
    -- the pre-library implementations, kept short — and the honest "it is not
    -- installed" line is said ONCE, on the first line the addon prints, rather
    -- than stapled to every one of them.
    local function probeConcat(v) return table.concat({ v }) end
    function KCM.IsConcatSafe(v) return (pcall(probeConcat, v)) end
    function KCM.SafeToString(v)
        if v == nil then return "nil" end
        if type(v) == "boolean" then return tostring(v) end
        if KCM.IsConcatSafe(v) then return tostring(v) end
        return "<secret>"
    end

    -- The class color needs the library; the SWATCH does not. Degraded, the
    -- companion is simply not honored and the stored color is what paints -- which
    -- is the same answer options-ui-§17 gives for an unresolvable class, so the
    -- drawing code has one shape rather than a nil arm.
    function KCM.SwatchColor(stored, _, dr, dg, db, da)
        if type(stored) ~= "table" then return dr, dg, db, da end
        local r, g, b, a = stored[1], stored[2], stored[3], stored[4]
        if r == nil then r = dr end
        if g == nil then g = dg end
        if b == nil then b = db end
        if a == nil then a = da end
        return r, g, b, a
    end

    local announced = false
    function KCM.Say(fmt, ...)
        local n = select("#", ...)
        local line
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = KCM.SafeToString((select(i, ...))) end
            line = KCM.SafeToString(fmt):format(unpack(parts))
        else
            line = KCM.SafeToString(fmt)
        end
        if not announced then
            announced = true
            print(KCM.PREFIX .. " " .. KCM.LIBKA0S_MISSING ..
                "; running on reduced built-in fallbacks.")
        end
        print(KCM.PREFIX .. " " .. line)
    end
    return
end

KCM.IsConcatSafe = lib.IsConcatSafe
KCM.SafeToString = lib.SafeToString

-- ONE class-color resolver for the whole addon (options-ui-§17). Every color this
-- addon paints is chrome on a bar the PLAYER owns -- it tracks no unit and reads
-- no other unit's class -- so the unit token handed to the library is always nil,
-- and there is deliberately no per-call-site choice to get wrong.
--
-- Wrapped rather than bound bare for one reason: the stored shape here is the
-- POSITIONAL array `{ r, g, b, a }` (defaults/Profile.lua, and the codec at
-- settings/OptionsSetup.lua), and each swatch carries its OWN four-channel
-- fallback rather than white -- a bar backdrop that lost its stored value has
-- always fallen back to black at 50%, not to white. lib.RGBA takes those four
-- defaults; lib.ResolveColor does not, so the decode happens here and the
-- resolved swatch is handed on through a scratch table.
--
-- The scratch table is reused because this runs once per button per repaint and
-- the library never retains what it is handed (performance-§12).
local swatch = { 1, 1, 1, 1 }

--- @param stored table|nil   the profile's { r, g, b, a }
--- @param useClass boolean   the row's `useClassColor*` companion
--- @return number, number, number, number
function KCM.SwatchColor(stored, useClass, dr, dg, db, da)
    swatch[1], swatch[2], swatch[3], swatch[4] = lib.RGBA(stored, dr, dg, db, da)
    return lib.ResolveColor(swatch, useClass, nil)
end

local printer = lib:New({
    -- The tag as a FUNCTION, not as the value of KCM.PREFIX. It reads the same
    -- here, where core/Constants.lua has already run — but the printer is built
    -- once at load and a captured value would freeze it, whereas KCM.PREFIX is
    -- a live namespace field that defaults/Categories.lua and
    -- modules/MacroManager.lua also read when they build macro bodies. One
    -- source of truth, re-read on every line.
    prefix = function() return KCM.PREFIX end,

    -- Explicit, and mandatory here. The library's default sink is
    -- DEFAULT_CHAT_FRAME:AddMessage; this addon has always emitted through the
    -- global `print`, and that global is exactly where the headless harness
    -- listens. Without this line every chat assertion in the suite goes silent
    -- rather than red. Resolved at call time so the harness's swap lands.
    sink = function(line) print(line) end,
})

-- Format, not Print. KCM.Say has always been variadic-FORMAT — a lone string,
-- or a format string plus secret-safe args — and never print()'s space-joining
-- shape. printer.Format is that contract exactly, including the zero-vararg
-- branch that emits the string verbatim so a lone "100% done" is not run
-- through :format(). Bound bare rather than wrapped: it is a plain function so
-- that core/SlashCommands.lua's `local say = KCM.Say` keeps working unchanged.
KCM.Say = printer.Format

-- WRAPPED, TO SAY WHO IS ASKING. LibKa0s draws its own `close` mark when it is
-- told which addon FOLDER to build a texture path from, and a vendored library
-- cannot work that out for itself: every consumer has its own copy at its own
-- path. `addonName` is that answer and this file has it as its first vararg.
--
-- One wrapper rather than a remembered third argument at each call site: every
-- close control this addon builds for itself comes through here, so a future
-- modal or copy window draws the shared mark without anyone remembering to ask.
-- Without the name the library falls back to a multiplication sign, which is
-- what a degraded install should get.
--
-- ANTI-PATTERN #64: a forwarder carries EVERY argument its target takes. The
-- library's signature is `lib.MakeCloseButton(parent, onClick, addonName)`, and
-- a two-argument passthrough onto it is green in every suite and wrong on
-- screen, because a missing texture path draws nothing and raises nothing.
KCM.MakeCloseButton = function(parent, onClick)
    return lib.MakeCloseButton(parent, onClick, addonName)
end
