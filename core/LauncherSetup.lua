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
-- THE RUNG: (b) LOCK / UNLOCK
-- ---------------------------------------------------------------------------
--
-- launcher-§2 orders the left click by what the player most likely wants, first
-- match wins: (a) toggle the addon's primary window, (b) else toggle its preview
-- switch, (c) else open the settings panel. This addon draws no standalone
-- window, and its preview switch is the macro bar's LOCK -- unlocking IS the
-- preview here, the options-ui-§15 exemption -- so it sits on rung (b), which is
-- what `ADDONS.md` records for it.
--
-- RIGHT-CLICK ALWAYS OPENS THE PANEL, on every addon on every rung, which is
-- what lets the left button be spent on something better. The library owns that
-- half; `openSettings` below is all it asks for.
--
-- WHILE THE ADDON IS DISABLED the left click is REFUSED and the right click is
-- unchanged (launcher-§2, slash-commands-§7). Rung (b) drives a preview switch
-- and a preview switch is a feature, so the left button prints the one refusal
-- line and does nothing else -- no SavedVariables write above all. The button
-- itself stays on the minimap: `minimap.hide` is a per-installation display
-- preference and says nothing about whether the addon is running.
--
-- THE LEFT CLICK DRIVES THE EXISTING SWITCH THROUGH THE EXISTING SEAM and holds
-- no copy of it. `MB.SetLocked` is the write path both `/cm bar lock|unlock` and
-- the Master-controls *Lock frame* checkbox already take (CM-R-05,
-- modules/MacroBar.lua's writeFlag): it routes `macroBar.locked` through
-- KCM.Schema:Set, so validation, the row's apply (MB.ApplyLock) and the open
-- page's in-place re-sync happen exactly once no matter who called. A launcher
-- that assigned `c.locked` here instead would be the second write path that
-- change removed, and the checkbox would show the old state until the page was
-- rebuilt.
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
-- invert -- and it is the `global.minimap.hide` row's own store that does it,
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

    -- RIGHT-click always, and left-click too on rung (c) -- which this addon is
    -- not on, but the library asks for it unconditionally and is right to.
    -- Resolved at call time: settings/OptionsShim.lua publishes KCM.Options.Open
    -- long after this file loads, and on a build with no panel at all the shim is absent
    -- and the say() below is the honest answer.
    openSettings = function()
        if not (KCM.Options and KCM.Options.Open and KCM.Options.Open()) then
            KCM.Say("Settings panel unavailable.")
        end
    end,

    -- REFUSED WHILE THE ADDON IS DISABLED (launcher-§2, slash-commands-§7), and
    -- refused by the LIBRARY: LibKa0s-Launcher-1.0 minor 2 gates the left click
    -- on these two fields, so a disabled addon's click never reaches onClick.
    -- This is a rung-(b) left click: it drives the preview switch, which is a
    -- FEATURE, so it prints the one refusal line and does nothing else -- in
    -- particular it writes no SavedVariables, which is the thing a minimap
    -- button with no disabled gate does every single time it is clicked.
    -- Unlocking a bar that is not drawn is not a coherent request anyway.
    --
    -- The DISABLED hold, not the latch as a whole: a perf capture's suspended
    -- arm is a diagnostic the player started, not a switch they threw.
    isEnabled = function()
        return not (KCM.IsAddonDisabled and KCM.IsAddonDisabled())
    end,
    -- THE LINE IS THE DISPATCHER'S, never re-spelled here: one wording,
    -- collection-wide, built once by cli:DisabledLine() (slash-commands-§7).
    -- The right click is UNCHANGED in either state -- the library never gates
    -- it: it opens the settings panel, which is setup rather than a feature, and
    -- it is one of the two routes a player uses to switch the addon back on.
    disabledLine = function()
        local Sl = KCM.SlashCommands and KCM.SlashCommands.instance
        return Sl and Sl:DisabledLine()
    end,

    -- THE LEFT CLICK, AND ITS PRESENCE IS THE RUNG (launcher-§2). Toggles the
    -- macro bar's lock by running `/cm lock` / `/cm unlock`'s own body
    -- (KCM.SlashCommands.Verbs.RunLock), so the write seam and the wording are
    -- one copy, not two. It reads the CURRENT value out of the profile rather
    -- than keeping one, so the surfaces cannot disagree.
    onClick = function()
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
