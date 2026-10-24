-- Constants.lua — shared literals.
--
-- Loaded early so KCM.PREFIX exists before any module (or category emptyText)
-- references it, and immediately before core/CoreSetup.lua, which builds the
-- chat printer this tag goes on.
--
-- The secret-safe stringifier and the KCM.Say chat seam used to live here.
-- They are LibKa0s-Core-1.0 now (libs/LibKa0s/Core.lua), wired up in
-- core/CoreSetup.lua — see that file for why the tag is handed over as a
-- function rather than as a value.

local _, NS = ...
local KCM = NS

-- Cyan [CM] chat prefix — the single source of truth (slash-commands-§4). Every
-- chat line and every macro-body `/run print(...)` references this instead of
-- a hand-written literal. No trailing space; KCM.Say adds the separator.
KCM.PREFIX = "|cff00ffff[CM]|r"

-- Upper bound on the global cooldown, in seconds. Same value and reasoning as
-- KickCD's Const.GCD_UPPER (its core/Constants.lua) — WoW's GCD is
-- haste-modified (typically 1.0-1.5s), so 1.6s comfortably covers the
-- unhasted case plus a small floating-point epsilon.
--
-- modules/MacroBarButton.lua's GCD-suppress curve treats any REMAINING
-- cooldown <= this as "just the GCD -- hide the swipe" and anything above it
-- as a real cooldown worth showing. Sub-second precision doesn't matter
-- because the curve is a step, not a gradient.
KCM.GCD_UPPER = 1.6

-- THE LAYERS TABLE (frame-layering-§5) -- the one place this addon names a
-- strata or a frame level. Every SetFrameStrata and SetFrameLevel in core/,
-- modules/ and settings/ reads it, and every level is an offset over the frame
-- that owns the band, never an absolute number (frame-layering-§3);
-- tests/test_macrobar_layers.lua pins both.
--
-- The whole stack, bottom to top:
--   MEDIUM  (HUD)          the macro bar root (KCMMacroBar), clamped. Its slots
--                          and drag handle are bar + 1 (the default child level).
--                          Inside each slot:  icon/backdrop regions  +0
--                                             cooldown swipe         + FILL
--                                             flyout indicator       + INDICATOR
--                                             border                 + BORDER
--                                             count/label overlay    + OVERLAY
--                          The unlock wash is bar + WASH, a mouse-off child frame
--                          over every slot band. The drag handle (LibKa0s
--                          DragHandle) keeps bar + 1 and ignores the bar's alpha.
--   HIGH                   the Blizzard Settings panel and its AceGUI canvases.
--   DIALOG  (HUD_POPUP)    the per-slot flyout, set once at construction and
--                          clamped: container + PANEL for its backdrop, entries
--                          at container + 1 with the slot's ladder (no
--                          indicator). Shares DIALOG with Blizzard's StaticPopups
--                          (the reset confirmations) and the library's debug
--                          console and perf panel, which are toplevel and win.
--   FULLSCREEN             the library's copy window (opened from the console).
--   FULLSCREEN_DIALOG      library menus, the Add-by-ID suggestion list, AceGUI
--                          pullouts.
--   TOOLTIP                GameTooltip, the reorder carried copy (library).
-- Library bands inside the settings lists: the reorder box (row - 1) and drop
-- line (+20) are LibKa0s's own (WidgetsReorder.lua).
KCM.Constants = KCM.Constants or {}
KCM.Constants.LAYERS = {
    STRATA = {
        HUD       = "MEDIUM",
        HUD_POPUP = "DIALOG",
    },
    LEVEL = {
        PANEL     = 0,   -- flyout backdrop at the container's own level
        FILL      = 1,   -- cooldown swipe, explicit (never the implicit default)
        INDICATOR = 2,   -- flyout indicator: above the swipe, below the border
        BORDER    = 3,   -- slot / entry border
        OVERLAY   = 4,   -- count and label text
        WASH      = 30,  -- unlock wash over the bar (the HUD outline band)
    },
}
