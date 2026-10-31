-- settings/About.lua — the parent canvas: logo, addon notes, slash command list.
--
-- It was a block inside settings/Panel.lua until 2026-10-31 (issue #42), peeled
-- with settings/PanelRows.lua to take that file off layout-§1's on-notice band.
-- Every line moved WHOLE. Helpers.BuildAboutContent kept its name, so the
-- descriptor's buildMain (settings/OptionsSetup.lua) is unchanged and reaches it
-- at call time.

local _, NS = ...
local KCM = NS
local L = KCM.L
local Helpers = KCM.Settings.Helpers

-- Built from the folder name rather than typed, the same derivation
-- core/LauncherSetup.lua uses for the launcher icon (its ICON, built from
-- `addonName`): a texture path is absolute from `Interface\AddOns\`, so the
-- folder half has to be the name the client loaded, and layout-§4 lowercases
-- the file half. This is consistency with that file, not a layout-§4
-- deviation being corrected -- the literal spelled the same path. This file
-- opens `local _, NS = ...`, so the name is read off NS.name, which
-- core/Namespace.lua sets from the vararg.
local LOGO_TEXTURE = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga")
    :format(KCM.name, KCM.name:lower())
local LOGO_PIXELS  = 300

-- Through core/EnvSetup.lua rather than C_AddOns directly, which also retires
-- the hardcoded "ConsumableMaster" this used to pass: the seam hands the library
-- the first vararg, so a folder rename cannot leave this reading somebody else's
-- manifest -- or none -- and saying nothing about it.
local function readAddOnNotes()
    return KCM.Meta("Notes") or ""
end

-- The parent canvas, through the library's builder (options-ui-§5): logo, the
-- TOC notes line, then the Slash Commands heading and one row per command. It
-- replaced a private copy that drew the logo as a texture straight on a pooled
-- AceGUI SimpleGroup frame and never took it off: after a re-render the frame
-- came back as another SimpleGroup (the spacer under the heading) still
-- carrying the logo, so the page showed it twice. The builder keeps one
-- texture per frame and hides it in the group's OnRelease.
--
-- Convergence #2 (LIBKA0S-13): one row formatter for the whole addon. The
-- rows come back already rendered by lib.FormatRow, the same function /cm
-- help's rows go through -- so the panel and the chat cannot drift apart again
-- by an edit to one of them. `rows` is a function so a re-render picks up a
-- command registered since.
function Helpers.BuildAboutContent(ctx)
    Helpers.BuildLandingPage(ctx, {
        logo     = LOGO_TEXTURE,
        logoSize = LOGO_PIXELS,
        notes    = readAddOnNotes,
        sections = { {
            heading = L["Slash Commands"],
            rows    = function()
                return (KCM.SlashCommands and KCM.SlashCommands.GetLandingRows)
                    and KCM.SlashCommands.GetLandingRows() or {}
            end,
        } },
    })
end
