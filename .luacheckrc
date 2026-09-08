-- Luacheck configuration for Ka0s Consumable Master.
-- Run:  luacheck .
-- Vendored libs, the frozen audit bundle and the review bundle are excluded, and under tests/
-- only the vendored kit is: libs/ is third-party, and tests/_kit/ is a byte copy of the LibKa0s
-- repo's testkit/, which is linted THERE as source — linting the copy as well would report every
-- finding twice and would let the copy drift green while the original went red, the one state
-- tests/test_vendor_sync.lua exists to forbid. Everything else under tests/ is this repo's own
-- code and is linted (lint.md).

std = "lua51"
max_line_length = false
codes = true

exclude_files = {
    "libs/",
    "docs/audits/",
    "docs/reviews/",
    "tests/_kit/",
}

-- NO TOP-LEVEL `ignore`, and none is coming back (lint.md, `M4-11`). This file carried
-- `ignore = { "212", "542" }` until `M4c-03`. Both codes were honest — unused `self` on widget
-- methods, one deliberately empty CSV branch — but a top-level ignore reaches all 99 files, so it
-- silenced those two codes in every file that has no business producing them too, and a genuinely
-- dead argument written into core/BagScanner.lua tomorrow would have landed green under a 0/0
-- badge. That is the state the rule calls "reads as coverage and provides none".
--
-- What replaced it: the `files[...]` stanzas at the foot of this file, each naming the file that
-- earns the code and the variable name that earns it, plus one `-- luacheck: ignore 542` beside
-- the single line in core/SlashCommands.lua that needs it. tests/test_lintconfig.lua is what keeps
-- the blanket from re-entering.

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

-- ---------------------------------------------------------------------------
-- The narrowed 212s (lint.md, `M4c-03`)
-- ---------------------------------------------------------------------------
--
-- Every stanza below names ONE file and ONE argument name, in luacheck's `<code>/<variable>`
-- form. That is the whole difference from the blanket this replaced: a newly-unused argument
-- under any other name, in any of these files or in any of the other 89, still reports. Each is
-- an argument a signature is obliged to accept and this body has no use for — not a defect parked
-- behind a suppression — and the comment says which obligation.

-- AceEvent hands a handler the event name first and calls it as a method, and AceAddon calls
-- OnEnable / OnPlayerEnteringWorld the same way, so `self` and `event` arrive whether the body
-- reads them or not. `reason` is the label that threads the whole recompute chain — P.Recompute
-- logs it at :185 and :188 — and P.RecomputeOne (:87) takes it so the per-category entry point has
-- the same shape as runMacroPass, which passes it straight through at :135.
files["core/ConsumableMaster.lua"] = {
    ignore = { "212/self", "212/event", "212/reason" },
}

-- AceGUI calls every widget method as `widget:Method(...)`, and each of these three carries no-op
-- setters that exist precisely so the widget tolerates a consumer calling them: SetText and
-- SetFontObject on the two row widgets, which build their own labels, and SetLabel on
-- KCMScoreButton, whose caller passes a tooltip title rather than a caption. A stub that stores
-- nothing still has to accept the receiver.
files["modules/KCMItemRow.lua"]       = { ignore = { "212/self" } }
files["modules/KCMMacroDragIcon.lua"] = { ignore = { "212/self" } }
files["modules/KCMScoreButton.lua"]   = { ignore = { "212/self" } }

-- doEdit takes `catKey` because every other function in the create/edit/delete trio needs it for
-- its chat line, and a trio whose signatures disagree is worse than one unused parameter.
files["modules/MacroManager.lua"] = {
    ignore = { "212/catKey" },
}

-- The per-category scorers are a dispatch table: every entry is called as
-- `scorer(itemID, ctx, scoreCache)`, and the seven that score on item fields alone never look at
-- the spec context. Dropping `ctx` from those seven would mean seven signatures that cannot be
-- called through the table.
files["modules/Ranker.lua"] = {
    ignore = { "212/ctx" },
}

-- Three more receivers that arrive because the caller decides the calling convention: the
-- StaticPopupDialogs OnAccept at settings/Category.lua:209, which reads only the `data` payload
-- Blizzard hands it; KCM.Schema:Set (settings/Panel.lua:752), published with method sugar per
-- architecture-§5 and forwarding straight to Helpers.SetAndRefresh; and KCM:OnSlashCommand
-- (settings/Slash.lua:411), which AceConsole invokes on the addon object.
files["settings/Category.lua"] = { ignore = { "212/self" } }
files["settings/Panel.lua"]    = { ignore = { "212/self" } }
files["settings/Slash.lua"]    = { ignore = { "212/self" } }

-- The mock stands in for client and library APIs, so its stubs copy the real signatures whether
-- the stub body uses them or not — a mock that quietly narrows a signature is a mock that lets a
-- caller pass tests it would fail in the client. `212/%.%.%.` is the same rule for the vararg on
-- those stubs; the escapes are there because luacheck matches an ignore name as a Lua pattern.
files["tests/wow_mock.lua"] = {
    ignore = { "212/self", "212/%.%.%." },
}

-- The Selector.AddItem this suite substitutes at :789 has to take the same two arguments the real
-- one does; the assertion it is written for only records the second.
files["tests/test_settingsui.lua"] = {
    ignore = { "212/catKey" },
}
