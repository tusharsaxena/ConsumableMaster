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

-- SavedVariables and the (transitional) addon global are written by us.
-- Frame-registry tables receive field assignments (StaticPopupDialogs[...],
-- tinsert(UISpecialFrames, ...)) so they must be writable, not read_globals.
globals = {
    "ConsumableMasterDB",
    "KCM",
    "StaticPopupDialogs",
    "UISpecialFrames",
    "SLASH_CONSUMABLEMASTER1",
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
    "IsPlayerSpell", "IsSpellKnown", "PlayerHasToy",
    -- Spec APIs (wrapped by core/Compat.lua)
    "GetSpecialization", "GetSpecializationInfo", "GetNumSpecializations",
    "GetSpecializationInfoForClassID", "GetNumSpecializationsForClassID",
    "GetClassInfo", "C_SpecializationInfo",
    -- Spell / item (legacy globals wrapped by core/Compat.lua)
    "GetSpellInfo", "GetSpellCooldown", "GetItemInfo", "GetItemInfoInstant",
    "GetItemCount",
    -- Macro APIs (MacroManager only)
    "CreateMacro", "EditMacro", "DeleteMacro", "GetMacroInfo", "GetNumMacros",
    "GetMacroIndexByName", "PickupMacro",
    -- Namespaced client tables
    "C_Spell", "C_Item", "C_Container", "C_TooltipInfo", "C_Timer",
    "C_AddOns", "C_TradeSkillUI", "C_SettingsUtil", "C_CVar",
    "Settings", "LibStub",
    -- Ace3 / vendored
    "LibStub",
}
