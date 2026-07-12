-- locales/enUS.lua — English strings + key-returning fallback.
--
-- English is the only shipped locale (standard §8.3 allows an English-only
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
