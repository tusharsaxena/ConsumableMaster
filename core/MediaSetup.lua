-- core/MediaSetup.lua — the LibKa0s-Media-1.0 seam: where this addon's art and
-- its monospace face come from.
--
-- ---------------------------------------------------------------------------
-- THE FONT USED TO BE OURS, AND THAT WAS THE PROBLEM
-- ---------------------------------------------------------------------------
--
-- This addon shipped its own copy of JetBrains Mono under `media/fonts/`, with
-- its own OFL text beside it, and registered it with LibSharedMedia from
-- core/DebugLogSetup.lua against a hardcoded
-- `Interface\AddOns\ConsumableMaster\media\fonts\…` path. Every other Ka0s addon
-- shipped the same bytes under its own folder and registered the same LSM key
-- against a different path — and two registrations of one name against two paths
-- is a collision whose winner is load order.
--
-- The face ships inside LibKa0s now (v1.9.0, `LibKa0s-Media-1.0`) and arrives
-- with the payload this repo already vendors, so `media/fonts/` here is gone and
-- the library owns both the bytes and the registration. The icon catalog rides
-- along in the same payload, and this addon reaches it in two places: the macro
-- bar's handle help button asks for `help` directly, and the debug console's
-- title bars get copy / clear / close because core/DebugLogSetup.lua tells the
-- library our folder name. Everything else here is still Blizzard art by design
-- (docs/scope.md) — including the whole settings panel, whose widgets belong to
-- LibKa0s-Options-1.0 and are deliberately left unmarked.
--
-- ---------------------------------------------------------------------------
-- WHY THE LIBRARY HAS TO BE TOLD OUR NAME
-- ---------------------------------------------------------------------------
--
-- A texture path is absolute from `Interface\AddOns\`, and LibKa0s is VENDORED:
-- every consumer has its own copy at its own path, and a copy cannot know which
-- addon folder it was copied into. So the library asks, and this file is where
-- the answer lives — `addonName`, the first vararg every TOC-loaded file gets.
-- Never the frame-name prefix, never the ## Title, never a hand-typed literal: a
-- wrong texture path draws nothing and raises nothing.
--
-- ---------------------------------------------------------------------------
-- WHY THIS LOADS BEFORE core/DebugLogSetup.lua
-- ---------------------------------------------------------------------------
--
-- The console's font is resolved EAGERLY, at load, in core/DebugLogSetup.lua —
-- `lib:New` type-checks the field and raises at construction, so the path cannot
-- be handed over lazily. That file therefore needs `KCM.MediaFont` to already
-- exist, which makes this file's TOC position load-bearing rather than
-- conventional. Nothing else in core/ reads the seam at load.
--
-- ---------------------------------------------------------------------------
-- WHAT A DEGRADED INSTALL GETS
-- ---------------------------------------------------------------------------
--
-- No LibKa0s means no art and no face — they are inside the payload that is
-- missing. `KCM.Icon` answers nil, which is a value a caller can branch on, and
-- `KCM.MediaFont` answers nil, which core/DebugLogSetup.lua turns into the
-- client's own STANDARD_TEXT_FONT. Neither is an error: the console loses its
-- fixed-width columns and keeps every line on screen.

local addonName, NS = ...
local KCM = NS

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent, and the name may
--- not be one the library ships. Both are the same thing to a caller — draw
--- something else — and both are far better than the alternative the library
--- exists to remove, which is a plausible path to a texture that does not load,
--- draws nothing, and raises nothing.
---
--- EXTENSIONLESS by contract. The library answers `…\media\icons\close`, never
--- `close.tga`; the client appends the extension itself and a path carrying one
--- is a recorded spelling that draws nothing.
---
--- @param name string  an entry of the library's `ICONS` catalog, e.g. "close"
--- @return string|nil
function KCM.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil when the library is absent or the
--- face is not one it carries.
---
--- @param name string  a key of the library's `FONTS`, e.g. "JetBrains Mono"
--- @return string|nil
function KCM.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

-- REGISTERED AT FILE LOAD, not at PLAYER_LOGIN. LibSharedMedia is vendored under
-- libs/ and has therefore already run by the time the TOC reaches core/, while
-- the console resolves its face at load in core/DebugLogSetup.lua and the macro
-- bar's border picker reads LSM's registry as soon as a page is built. Deferring
-- would open a window in which a name nothing had registered resolved to nothing.
--
-- What registration buys over the bare path is the rest of the UI: a registered
-- face appears in an LSM dropdown beside every other font the player has, and
-- anything that stores media stores the NAME — portable across installs — rather
-- than a path naming one addon's folder. The library's call is idempotent and
-- points every consumer at one set of bytes under one key, which is what makes
-- two Ka0s addons registering "JetBrains Mono" agree rather than collide.
if Media then Media.RegisterLSM(addonName) end
