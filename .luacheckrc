-- Luacheck configuration for Ka0s Consumable Master.
-- Run:  luacheck .
-- Vendored libs, the frozen audit bundle, the review bundle, and the test
-- harness are excluded (libs are third-party; the audit/review bundles under
-- docs/ are docs; tests run under their own mock and set globals deliberately).

std = "lua51"
max_line_length = false
codes = true

exclude_files = {
    "libs/",
    "docs/audits/",
    "docs/reviews/",
    "tests/",
}

-- Conventional-in-Ace / intentional patterns, plus two pre-existing dead-code
-- smells tracked as follow-ups (not fixed in this compliance pass):
--   212 — unused arguments (self on widget methods, event/reason on handlers)
--   542 — intentional empty branch (CSV skip in /cm stat secondary)
--   241 — TooltipCache.pendingIDs set is populated but never read  [follow-up]
--   211/ROW_VSPACER — dead layout constant in settings/Panel.lua   [follow-up]
ignore = { "212", "542", "241", "211/ROW_VSPACER" }

-- The SavedVariables table is written by us. Frame-registry tables receive
-- field assignments (StaticPopupDialogs[...], tinsert(UISpecialFrames, ...)) so
-- they must be writable, not read_globals. State is threaded through the private
-- NS table (local KCM = NS), so there is no addon global to declare (standard §4.1),
-- and slash globals are registered dynamically by AceConsole, not by name here.
globals = {
    "ConsumableMasterDB",
    "StaticPopupDialogs",
    "UISpecialFrames",
}

-- WoW client API surface the addon reads. Kept flat and explicit so a typo'd
-- API name still surfaces as an undefined-global warning.
read_globals = {
    -- Lua/WoW shared helpers
    "wipe", "strsplit", "strtrim", "strjoin", "tContains", "Mixin", "CopyTable",
    "date", "time", "GetTime", "format", "tinsert", "tremove", "hooksecurefunc",
    "DevTools_Dump",
    -- Frames / UI
    "CreateFrame", "UIParent", "GameTooltip",
    "BackdropTemplateMixin", "ScrollingMessageFrame_OnMouseWheel",
    "StaticPopup_Show", "YES", "NO", "OKAY", "CANCEL",
    "GameFontNormal", "GameFontHighlight", "GameFontDisable", "NORMAL_FONT_COLOR",
    "Settings", "SettingsPanel", "HideUIPanel", "GetAddOnMetadata", "GetItemIcon",
    "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS", "GetNumClasses",
    -- Combat / unit
    "InCombatLockdown", "UnitClass", "UnitLevel", "UnitName", "UnitGUID",
    "IsPlayerSpell", "IsSpellKnown", "PlayerHasToy", "GetInventoryItemID",
    -- Spec APIs (wrapped by core/Compat.lua)
    "GetSpecialization", "GetSpecializationInfo", "GetNumSpecializations",
    "GetSpecializationInfoForClassID", "GetNumSpecializationsForClassID",
    "GetClassInfo", "C_SpecializationInfo",
    -- Spell / item (legacy globals wrapped by core/Compat.lua)
    "GetSpellInfo", "GetSpellCooldown", "GetItemInfo", "GetItemInfoInstant",
    "GetItemCount",
    -- Macro APIs. Only the PROTECTED writers (CreateMacro/EditMacro/DeleteMacro)
    -- are MacroManager's exclusive territory; the read-only lookups and
    -- PickupMacro are also used by the drag icon and the macro bar.
    "CreateMacro", "EditMacro", "DeleteMacro", "GetMacroInfo", "GetNumMacros",
    "GetMacroIndexByName", "PickupMacro",
    -- Cursor + secure visibility driver (modules/MacroBar*.lua). The state
    -- driver is how combat-conditional show/hide stays taint-free.
    "GetCursorInfo", "ClearCursor", "RegisterStateDriver", "UnregisterStateDriver",
    "GetItemCooldown",
    -- Namespaced client tables
    "C_Spell", "C_Item", "C_Container", "C_TooltipInfo", "C_Timer",
    "C_AddOns", "C_TradeSkillUI", "C_SettingsUtil", "C_CVar",
    -- Ace3 / vendored
    "LibStub",
}
