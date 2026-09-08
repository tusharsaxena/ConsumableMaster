-- locales/enUS.lua — English strings + key-returning fallback.
--
-- English is the only shipped locale (localization-§3 allows an English-only
-- addon, but the module shell is still required). KCM.L is a table with a
-- metatable that returns the key itself for any unset string, so wrapping a
-- user-facing literal in L["..."] is always safe — an untranslated string just
-- renders as its own key.
--
-- To add a translation later, drop a sibling locales/<locale>.lua that assigns
-- into the same KCM.L table guarded on GetLocale(); the fallback keeps every
-- unset key readable in the meantime.

local _, NS = ...
local KCM = NS

local L = setmetatable({}, { __index = function(_, key) return key end })
KCM.L = L

-- enUS entries are identity by default (the metatable handles them). Only add
-- rows here when a display string must differ from its lookup key.

-- ---------------------------------------------------------------------------
-- Notes for whoever writes the first non-English locale
-- ---------------------------------------------------------------------------
--
-- FONT COVERAGE BINDS THE TRANSLATION, NOT THE KEY. The priority row's hand tag
-- (`L["MH"]`, `L["OH"]`, `L["MH+OH"]` in modules/KCMItemRow.lua) is deliberately
-- ASCII: WoW's default face, Friz Quadrata TT, has narrow Unicode coverage and
-- draws an unsupported glyph as a tofu box. The three keys are translatable —
-- "main hand" and "off hand" abbreviate differently in other languages, and each
-- combination is one key so the pair can be reordered as well as renamed — but a
-- replacement has to stay inside the shipped face's coverage. That is a
-- constraint on the string a translator writes; it was never a reason to keep
-- the tag out of the seam.
--
-- WHAT IS NOT ROUTED, AND WHERE TO LOOK. tests/test_locale.lua gates the SETTINGS
-- surface — settings/ and the KCM* widgets — and lists, with a reason for each,
-- the strings there that stay in English. Outside that surface the `/cm` command
-- output (core/SlashCommands.lua, core/SlashDump.lua) and the seeded category
-- display names (defaults/Categories.lua) are still English literals; that is a
-- known gap rather than a decision, and it is recorded in that file's header and
-- in docs/settings-panel.md.
