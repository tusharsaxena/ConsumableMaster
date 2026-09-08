-- Luacheck configuration for Ka0s Consumable Master.
-- Run:  luacheck .
-- Vendored libs, the frozen audit bundle and the review bundle are excluded, and under tests/
-- only the vendored kit is: libs/ is third-party, and tests/_kit/ is a byte copy of the LibKa0s
-- repo's testkit/, which is linted THERE as source — linting the copy as well would report every
-- finding twice and would let the copy drift green while the original went red, the one state
-- tests/test_vendor_sync.lua exists to forbid. Everything else under tests/ is this repo's own
-- code and is linted (lint-§1).

std = "lua51"
max_line_length = false
codes = true

exclude_files = {
    "libs/",
    "docs/audits/",
    "docs/reviews/",
    "tests/_kit/",
}

-- Conventional-in-Ace / intentional patterns. Both are properties of code we
-- mean to keep, not known defects parked behind a suppression:
--   212 — unused arguments (self on widget methods, event/reason on handlers)
--   542 — intentional empty branch (CSV skip in /cm stat secondary)
ignore = { "212", "542" }

-- The SavedVariables table is written by us. Frame-registry tables receive
-- field assignments (StaticPopupDialogs[...], tinsert(UISpecialFrames, ...)) so
-- they must be writable, not read_globals. State is threaded through the private
-- NS table (local KCM = NS), so there is no addon global to declare (architecture-§1),
-- and slash globals are registered dynamically by AceConsole, not by name here.
globals = {
    "ConsumableMasterDB",
    -- The perf harness's own ring of captures, declared alongside
    -- ConsumableMasterDB at ConsumableMaster.toc:11 and kept separate from the
    -- AceDB tree on purpose (the TOC comment there says why). LibKa0s-Perf
    -- writes the global directly, so it is written by us in exactly the sense
    -- ConsumableMasterDB is — and a declared SavedVariable that this file does
    -- not name reads as a typo the moment anything here touches it
    -- (performance-§5).
    "ConsumableMasterPerfDB",
    "StaticPopupDialogs",
    "UISpecialFrames",
}

-- WoW client API surface the addon reads. Kept flat and explicit so a typo'd
-- API name still surfaces as an undefined-global warning.
read_globals = {
    -- Lua/WoW shared helpers
    "wipe", "strsplit", "strtrim", "strjoin", "tContains", "Mixin", "CopyTable",
    "date", "time", "GetTime", "format", "tinsert", "tremove", "hooksecurefunc",
    -- Millisecond profiling clock, read by the perf brackets in
    -- core/ConsumableMaster.lua and modules/MacroBar.lua.
    "debugprofilestop",
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
    -- Spec APIs. core/Compat.lua wraps exactly four of these — GetSpecialization,
    -- GetSpecializationInfo, GetNumSpecializationsForClassID and
    -- GetSpecializationInfoForClassID — each as the legacy fallback behind the
    -- C_SpecializationInfo namespace. GetClassInfo is read directly.
    "GetSpecialization", "GetSpecializationInfo", "GetNumSpecializations",
    "GetSpecializationInfoForClassID", "GetNumSpecializationsForClassID",
    "GetClassInfo", "C_SpecializationInfo",
    -- Secret values (Midnight). issecretvalue is wrapped by core/Compat.lua;
    -- C_DurationUtil builds the opaque duration objects that are the only way to
    -- paint a restricted cooldown from tainted code (core/MacroDisplay.lua).
    -- C_CurveUtil + Enum.LuaCurveType are the GCD-suppress step curve
    -- (modules/MacroBarButton.lua), same secret-safe pattern.
    "issecretvalue", "C_DurationUtil", "C_CurveUtil", "Enum",
    -- Spell / item. Of these, only GetSpellInfo goes through core/Compat.lua —
    -- it is the deprecated last fallback inside Compat.GetSpellName, behind
    -- C_Spell.GetSpellName and C_Spell.GetSpellInfo. The item globals are NOT
    -- wrapped: GetItemInfo, GetItemInfoInstant and GetItemCount are live retail
    -- globals, not deprecated ones, so `compat`'s routing rule does not reach
    -- them and callers read them directly (see docs/ARCHITECTURE.md's deviation
    -- register for the two direct GetItemInfo call sites).
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
    "RegisterAttributeDriver", "UnregisterAttributeDriver",
    "GetItemCooldown",
    -- Namespaced client tables
    "C_Spell", "C_Item", "C_Container", "C_TooltipInfo", "C_Timer",
    "C_AddOns", "C_TradeSkillUI", "C_SettingsUtil", "C_CVar",
    -- Ace3 / vendored
    "LibStub",
}

-- The test tree is linted. The harness publishes its exposed table under a per-repo global,
-- written at tests/run.lua:401 and read by every suite file. It is declared HERE and not in the
-- top-level read_globals above: a name granted at the top level is granted to core/, modules/ and
-- settings/ as much as to a suite, and a shipped file reaching for the test harness is precisely
-- what lint is here to refuse. `globals` rather than `read_globals` because tests/run.lua is the
-- writer. Every read in the tree today is _G.-qualified, a spelling luacheck does not check at
-- all, so this declaration is what keeps the bare spelling legal in tests/ and only in tests/.
files["tests/"] = {
    globals = { "KCM_TEST", "KCM_TEST_ROOT" },
}
