-- core/LauncherSetup.lua — the addon's half of LibKa0s-Launcher-1.0: the minimap
-- button and the broker plugin, as ONE object registered twice (launcher-§1).
--
-- ---------------------------------------------------------------------------
-- ONE OBJECT, TWO REGISTRATIONS, ONE CLICK
-- ---------------------------------------------------------------------------
--
-- There is exactly one LibDataBroker-1.1 object of `type = "launcher"`, and
-- LibDBIcon-1.0 draws the minimap button FROM it while any broker display the
-- player has (Titan Panel, ElvUI data texts, Bazooka) draws its own row from
-- the same object. One OnClick, one icon, one label, one identity. Writing the
-- button and the broker row as two features with two click handlers is
-- anti-pattern #81, and the whole reason the click lives inside the library
-- rather than here.
--
-- ---------------------------------------------------------------------------
-- THE BUTTONS: LEFT OPENS SETTINGS, RIGHT OPENS THE OPTIONS MENU
-- ---------------------------------------------------------------------------
--
-- launcher-§2 as of the standard's v2.67.0, drawn by LibKa0s-Launcher-1.0
-- minor 4. The LEFT click opens the settings panel on every addon, in either
-- state; `openSettings` below is all it asks for. The RIGHT click opens the
-- client's own context menu, which the library builds out of the
-- accessor-and-toggle pairs passed here, one checkbox per state the addon
-- really has. This addon has two, and `ADDONS.md` records exactly those:
--
--   Enabled   isEnabled + setEnabled   -- /cm enable | /cm disable
--   Locked    isLocked  + toggleLock   -- /cm lock   | /cm unlock (the macro bar)
--
-- NO *Test mode*: the unlocked bar IS the preview here (the options-ui-§15
-- exemption). NO *Show window*: this addon draws no standalone window; the
-- macro bar is a HUD element whose visibility is `/cm bar`, not a primary
-- window, and its lock is already the Locked entry.
--
-- WHILE THE ADDON IS DISABLED the library grays *Locked* with "enable the addon
-- first" and a click on it reaches nothing (slash-commands-§7); *Enabled* stays
-- live, since the menu is one of the routes back on. The button itself stays on
-- the minimap: `minimap.hide` is a per-installation display preference and says
-- nothing about whether the addon is running.
--
-- EVERY TOGGLE IS THE SLASH VERB'S OWN BODY, never a copy. *Locked* runs
-- KCM.SlashCommands.Verbs.RunLock, the body behind `/cm lock|unlock` and
-- `/cm bar lock|unlock`, which writes through `MB.SetLocked` -> KCM.Schema:Set
-- (CM-R-05, modules/MacroBar.lua's writeFlag) -- so validation, the row's apply
-- (MB.ApplyLock) and the open page's in-place re-sync happen exactly once no
-- matter who called, and the chat line is the verb's. *Enabled* runs
-- Verbs.SetEnabled, the body behind `/cm enable|disable` (settings/Slash.lua),
-- which writes the `enabled` row through the seam and echoes it. A launcher
-- assigning `c.locked` or `profile.enabled` here would be the second write path
-- those seams exist to remove, and the checkbox would show the old state until
-- the page was rebuilt.
--
-- ---------------------------------------------------------------------------
-- WHY `minimap` IS A FUNCTION AND NOT A TABLE
-- ---------------------------------------------------------------------------
--
-- `db.global.minimap` does not exist when this file runs: KCM.db is built in
-- KCM:OnInitialize at PLAYER_LOGIN, and AceDB hands back a table this file has
-- never seen. A table captured here at load would be a table AceDB later
-- replaces -- the object LibDBIcon holds and the table the settings row writes
-- would be two different tables, and the button and the checkbox would disagree
-- the first time either was used. The library resolves the thunk at Register
-- time, which is after the db exists.
--
-- ---------------------------------------------------------------------------
-- THE INVERSION IS NOT HERE
-- ---------------------------------------------------------------------------
--
-- The row says SHOWN and LibDBIcon's key says HIDDEN, so something has to
-- invert -- and it is the `global.minimap.shown` row's own store that does it,
-- the get/set settings/General.lua stamps on the row, which the single write
-- seam calls (options-ui-§1). It calls `KCM.Launcher:SetShown(value)` afterwards so the
-- button follows the checkbox immediately rather than at the next reload. This
-- file offers the verb and knows nothing about the row.
--
-- ---------------------------------------------------------------------------
-- WHAT A DEGRADED INSTALL GETS
-- ---------------------------------------------------------------------------
--
-- No LibKa0s means no KCM.Launcher at all -- core/PerfSetup.lua's convention,
-- and for the same reason: an absent major is an absent feature, no stub can
-- draw a minimap button, and both callers (KCM:OnInitialize's Register and the
-- schema row's set) already branch on nil. Publishing a do-nothing facade would
-- buy a caller nothing and cost a reader the ability to tell "the library is
-- missing" from "the button is hidden".
--
-- The two BROKER libraries are a separate question and the library answers it:
-- it resolves LibDataBroker-1.1 and LibDBIcon-1.0 with `LibStub(..., true)` at
-- Register time and degrades BY NAME -- no LibDataBroker means no launcher at
-- all, no LibDBIcon means the broker plugin without the minimap button -- so a
-- host holding neither gets a printed line rather than an error. Both are
-- vendored under libs/ here and listed in the TOC's `# Libraries` block, so the
-- degraded path is a tampered install rather than a supported state.

local addonName, NS = ...
local KCM = NS

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)
if not lib then return end

-- The addon's OWN logo, and the SAME file the TOC's `## IconTexture` names
-- (launcher-§4): one face in the AddOns list, on the minimap and in a broker
-- display. Never a Blizzard icon path and never a numeric file id -- a borrowed
-- icon makes this addon look like something else in the one list where the
-- player is choosing what to turn off (anti-pattern #82).
--
-- Built from `addonName` rather than typed, exactly as core/MediaSetup.lua
-- builds its media paths: a texture path is absolute from `Interface\AddOns\`
-- and the folder name is the one string this file cannot get wrong. layout-§4
-- fixes both halves of the spelling -- the folder name cased as the client
-- loads it, the file name lowercased -- so both sides are derivable.
local ICON = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga")
    :format(addonName, addonName:lower())

KCM.Launcher = lib:New({
    -- The addon's FOLDER name, used for BOTH registrations. NOT cosmetic:
    -- LibDBIcon keys the button's SAVED POSITION by it, so a second spelling
    -- drops the angle the player dragged the button to and labels the broker
    -- plugin with the other name (launcher-§1).
    name  = addonName,
    -- THE ADDON'S BRAND NAME IN PLAIN TEXT, `Ka0s <Name>` (launcher-§1). This is
    -- the string a broker display prints in its own row, and it prints it BESIDE
    -- THE OTHER TEN, so it is the single field that decides whether the
    -- collection reads as one collection in Titan Panel or as eleven unrelated
    -- addons that happen to be installed together. Across the eleven adoptions it
    -- came out three ways -- `Absorb Tracker`, `Ka0s KickCD`, `Ka0s Pretty Chat`
    -- -- because nothing said what it was, and a display sorting alphabetically
    -- filed one of them under A while the rest sat together under K.
    --
    -- DELIBERATELY NOT THE TOC'S `## Title`, and not wired to it. A Title MAY
    -- carry color escapes and one in the collection does: Ka0s Pretty Chat's is
    -- `Ka0s |cffff0000P|cffff9900r|cffffff00e|...`. Handed to a display that draws
    -- the string raw, that row splatters across a list in which every other row is
    -- plain text; handed to one that strips escapes, it arrives mangled instead.
    -- So: no escape sequence of any kind, ever.
    --
    -- AND NOT THE FOLDER NAME EITHER, which is the `name` above -- the key
    -- LibDBIcon stores the button's position under, and a string a player reads
    -- nowhere as prose. `ConsumableMaster` is an identifier; `Ka0s Consumable
    -- Master` is a name. Two fields, two jobs (anti-pattern #84).
    label = "Ka0s Consumable Master",
    icon  = ICON,

    -- A thunk, never the table (see the note above).
    minimap = function()
        return KCM.db and KCM.db.global and KCM.db.global.minimap
    end,

    -- LEFT-click, always and in either state (launcher-§2, minor 4); and the
    -- RIGHT click too on a client with no context-menu API. Resolved at call
    -- time: settings/OptionsShim.lua publishes KCM.Options.Open long after this
    -- file loads, and on a build with no panel at all the shim is absent and the
    -- say() below is the honest answer.
    openSettings = function()
        if not (KCM.Options and KCM.Options.Open and KCM.Options.Open()) then
            KCM.Say("Settings panel unavailable.")
        end
    end,

    -- THE *Enabled* PAIR. `isEnabled` is asked on every hover and every menu
    -- open, never cached: the tooltip's `Enabled` line, the entry's check, and
    -- -- while it answers false -- the gray on *Locked*.
    --
    -- The DISABLED hold, not the latch as a whole: a perf capture's suspended
    -- arm is a diagnostic the player started, not a switch they threw.
    isEnabled = function()
        return not (KCM.IsAddonDisabled and KCM.IsAddonDisabled())
    end,
    -- `/cm enable` / `/cm disable`'s own body (settings/Slash.lua, published as
    -- Verbs.SetEnabled), handed the state the addon is moving TO. Resolved at
    -- call time: settings/ loads after this file.
    setEnabled = function(on)
        KCM.SlashCommands.Verbs.SetEnabled(on)
    end,

    -- THE STATUS TOOLTIP (launcher-§1, LibKa0s-Launcher-1.0 minor 3). The
    -- LIBRARY draws it, on every hover and while the addon is disabled too, in
    -- the collection's one shape: `<label>  v<version>`, `Enabled`, the states
    -- passed below, then the two fixed click hints. These fields only answer its
    -- questions, each asked on every show and never cached. There is no
    -- `onTooltipShow`: this addon has no line of its own to add, and a title or
    -- a click hint drawn here would be a second copy (anti-pattern #89).
    --
    -- The version is the TOC's `## Version` (KCM.Version: TOC first, the
    -- in-code constant only where the manifest cannot be read).
    version = function() return KCM.Version and KCM.Version() end,
    -- THE LOCK IS THE ONLY STATE PASSED BESIDE `Enabled`, because it is the only
    -- other one this addon has: the macro bar's `macroBar.locked`, the very value the Master-controls
    -- *Lock frame* row reads, out of the live profile. There is NO `isTestMode`:
    -- the unlocked bar IS the preview here (the options-ui-§15 exemption the
    -- General page's composer notes), so a *Test mode* line would describe a
    -- switch the player cannot find; and no `isWindowShown`, for want of a window.
    isLocked = function()
        local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
        return cfg and cfg.locked and true or false
    end,
    -- THE *Locked* TOGGLE: `/cm lock` / `/cm unlock`'s own body
    -- (KCM.SlashCommands.Verbs.RunLock), so the write seam and the wording are
    -- one copy, not two. It reads the CURRENT value out of the profile rather
    -- than keeping one, so the surfaces cannot disagree.
    toggleLock = function()
        local cfg = KCM.MacroBarModel and KCM.MacroBarModel.Config()
        if not cfg then return KCM.Say("macro bar unavailable.") end
        KCM.SlashCommands.Verbs.RunLock(not cfg.locked)
    end,

    -- Thunks, never bare: lib:New snapshots both. Same note as
    -- core/CoreSetup.lua's sink and core/PerfSetup.lua's printer.
    print = function(line) KCM.Say(line) end,
    -- Guarded, unlike the printer: core/Debug.lua sits BELOW this file in the
    -- TOC and is left out of the harness's pure layer outright, so the sink can
    -- genuinely be absent when Register runs. `%s` rather than the message as a
    -- format string -- a library line carrying a literal `%` would otherwise
    -- raise inside string.format.
    debug = function(tag, message)
        if KCM.Debug then KCM.Debug(tag, "%s", tostring(message)) end
    end,
})
