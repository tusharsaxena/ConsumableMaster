-- settings/PanelRows.lua — the schema's row rules, one per declared `type`.
--
-- What this file owns: TYPE_RULES (each type's `validate` and `normalize`), the
-- stamp that puts a rule on a row, and Helpers.AddRows / AddRow, the way a row
-- enters the schema.
--
-- WHY IT IS ITS OWN FILE. It was a block inside settings/Panel.lua until
-- 2026-10-31, the follow-on seam issue #42 named. It is the one part of that file
-- with no widget and no panel in it. Every line moved WHOLE.
--
-- THE SEAM. It loads immediately after Panel.lua and before every page file,
-- because a page declares its rows at load and those go through Helpers.AddRows.
-- From Panel.lua it reads Helpers.schema, Helpers.EnumValues and
-- KCM.Settings.ResetExempt, the sweep-exempt set that file's descriptor holds.

local _, NS = ...
local KCM = NS
local Helpers = KCM.Settings.Helpers
local S = Helpers.schema
local enumValues = Helpers.EnumValues
local resetExempt = KCM.Settings.ResetExempt

-- A whole-value row's member set: a list, or a function answering one (the bar's
-- slot keys are only known once the categories have loaded).
local function membersOf(def)
    local m = def.members
    if type(m) == "function" then m = m() end
    return type(m) == "table" and m or {}
end

-- A FLAG MAP (a composite's `enabled`, the bar's `shown`): keys outside the
-- member set are dropped, and every kept value must be a real boolean -- the
-- readers test `~= false`, so a string or a number would silently read as on.
local function normalizeFlagMap(def, value)
    local known, out = {}, {}
    for _, m in ipairs(membersOf(def)) do known[m] = true end
    for k, v in pairs(value) do
        if known[k] then
            if type(v) ~= "boolean" then
                return nil, "expected true or false for " .. tostring(k)
            end
            out[k] = v
        end
    end
    return out
end

local function copyShallow(value)
    local out = {}
    for k, v in pairs(value) do out[k] = v end
    return out
end

local function isType(want, why)
    return function(_, value)
        if type(value) ~= want then return false, why end
        return true
    end
end

-- Enum rows (a `values` list) reject anything outside the list, so the
-- dropdown and `/cm set` can't write a value the renderer can't display.
local function validateString(def, value)
    if type(value) ~= "string" then return false, "expected string" end
    local allowed = enumValues(def)
    if #allowed > 0 then
        local names = {}
        for i, item in ipairs(allowed) do
            if item.value == value then return true end
            names[i] = tostring(item.value)
        end
        return false, "allowed values: " .. table.concat(names, ", ")
    end
    return true
end

-- One rule per declared schema type, split the way LibKa0s-Schema-1.0's
-- pipeline splits it: `validate(def, value) -> ok, why` refuses, and
-- `normalize(def, value) -> value | nil, why` answers what is stored. bool,
-- string and enum are validate-only. A type with no entry here passes its value
-- through untouched, as the elseif chain this replaced always did.
local TYPE_RULES = {
    bool = { validate = isType("boolean", "expected boolean") },

    -- min and max are independently optional, so the clamp is two separate
    -- one-sided tests rather than a range check.
    number = {
        validate  = isType("number", "expected number"),
        normalize = function(def, value)
            if def.min then value = math.max(def.min, value) end
            if def.max then value = math.min(def.max, value) end
            return value
        end,
    },

    string = { validate = validateString },

    -- Always a fresh table: a color row's `default` IS the dbDefaults table, and
    -- a reset sends it through the seam. Stored as-is it would alias the shipped
    -- default, and AceDB's removeDefaults on a later SetProfile nils its channels
    -- in place -- every profile after that reads an empty color. The seam copies
    -- a table into the store as well; this copy is what `apply` and the log see.
    color = { validate = isType("table", "expected color table"),
              normalize = function(_, value) return copyShallow(value) end },

    -- A WHOLE-VALUE list over a fixed member set (architecture-§5): the bar's
    -- slot order, a composite's section. NORMALIZED, not merely checked: unknown
    -- and repeated members are dropped and every missing one is appended in the
    -- member set's own order, so a stored order names each member exactly once.
    order = {
        validate  = isType("table", "expected a list"),
        normalize = function(def, value)
            local members = membersOf(def)
            local known, seen, out = {}, {}, {}
            for _, m in ipairs(members) do known[m] = true end
            for _, m in ipairs(value) do
                if known[m] and not seen[m] then seen[m] = true; out[#out + 1] = m end
            end
            for _, m in ipairs(members) do
                if not seen[m] then seen[m] = true; out[#out + 1] = m end
            end
            return out
        end,
    },

    -- A WHOLE-VALUE keyed map. A row naming `members` is a flag map; anything
    -- else is copied. A row with its OWN `normalize` (stat priority's) keeps it,
    -- which is LibKa0s-Schema-1.0's row.normalize: see stampRow.
    map = {
        validate  = isType("table", "expected a table"),
        normalize = function(def, value)
            if def.members then return normalizeFlagMap(def, value) end
            return copyShallow(value)
        end,
    },
}

-- Put the row's type rule on the row, closed over it, where the library's
-- pipeline reads it: `validate` and `normalize`. A row that already carries
-- its own keeps it. Stamped once; `__typed` is the marker.
local function stampRow(row)
    if type(row) ~= "table" or row.__typed then return end
    row.__typed = true
    local rule = TYPE_RULES[row.type]
    if not rule then return end
    if row.validate == nil and rule.validate then
        row.validate = function(value) return rule.validate(row, value) end
    end
    if row.normalize == nil and rule.normalize then
        row.normalize = function(value) return rule.normalize(row, value) end
    end
end

local function registerRow(row)
    stampRow(row)
    if row.neverReset and type(row.path) == "string" then resetExempt[row.path] = true end
end

--- Append hand-written rows to the schema: stamped with their type rules and
--- indexed by the seam, which is what makes a row writable at all.
function Helpers.AddRows(list)
    for _, row in ipairs(list) do registerRow(row) end
    return S.AddRows(list)
end

function Helpers.AddRow(row)
    Helpers.AddRows({ row })
    return row
end

-- Validate and coerce a value against a row's declared type, the way the seam
-- would, without writing it. Returns the value that would be stored, or nil and
-- the reason. A thin read of TYPE_RULES kept for the suites that pin each rule;
-- the seam itself reads the stamped row fields.
local function validateSchemaValue(def, value)
    local rule = TYPE_RULES[def.type]
    if not rule then return value end
    local ok, why = rule.validate(def, value)
    if not ok then return nil, why end
    if type(def.normalize) == "function" then return def.normalize(value) end
    if rule.normalize then return rule.normalize(def, value) end
    return value
end
Helpers.ValidateSchemaValue = validateSchemaValue
